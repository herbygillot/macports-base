# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# traversal.tcl
#
# Query and render procs: emit, walk, walk_with_path, find, command_of,
# structural, words_of, blank_line_count, position_of, positions_of.

namespace eval tclparse {}

# --------------------------------------------------------------------------
# emit — byte-identical source reconstruction
# --------------------------------------------------------------------------

# Render a CST back to source text. Byte-identical for unmodified CSTs,
# including after descent (descent rewrites text/inner on braced words
# but never changes the bytes emit produces).
proc tclparse::emit {cst} {
    set out ""
    foreach n [dict get $cst nodes] {
        append out [tclparse::_emit_node $n]
    }
    return $out
}

proc tclparse::_emit_node {n} {
    set kind [dict get $n kind]
    switch -- $kind {
        terminator {
            return ";"
        }
        command {
            set out ""
            foreach bn [dict get $n body] {
                append out [tclparse::_emit_node $bn]
            }
            return $out
        }
        word {
            if {[dict exists $n inner]} {
                return "\{[tclparse::emit [dict get $n inner]]\}"
            }
            return [dict get $n text]
        }
        default {
            return [dict get $n text]
        }
    }
}

# --------------------------------------------------------------------------
# walk, walk_with_path
# --------------------------------------------------------------------------

# Visit every node in source order, recursing into command bodies and
# inner CSTs. Visitor signature: {node}. See NOTES.md "Walk gotchas" —
# descended braced words are visited both as the `word` node and as each
# command inside their `inner`; this is intentional.
proc tclparse::walk {cst visitor} {
    foreach n [dict get $cst nodes] {
        tclparse::_walk_node $n $visitor
    }
    return
}

proc tclparse::_walk_node {n visitor} {
    uplevel 2 [list $visitor $n]
    set kind [dict get $n kind]
    if {$kind eq "command"} {
        foreach bn [dict get $n body] {
            tclparse::_walk_node $bn $visitor
        }
    } elseif {$kind eq "word" && [dict exists $n inner]} {
        foreach innern [dict get [dict get $n inner] nodes] {
            tclparse::_walk_node $innern $visitor
        }
    }
}

# Same as walk but the visitor also receives the enclosing-command chain
# (outer-to-inner); the chain does not include the current node.
proc tclparse::walk_with_path {cst visitor} {
    foreach n [dict get $cst nodes] {
        tclparse::_walk_node_path $n $visitor [list]
    }
    return
}

proc tclparse::_walk_node_path {n visitor ancestors} {
    uplevel 2 [list $visitor $n $ancestors]
    set kind [dict get $n kind]
    if {$kind eq "command"} {
        set new_anc [linsert $ancestors end $n]
        foreach bn [dict get $n body] {
            tclparse::_walk_node_path $bn $visitor $new_anc
        }
    } elseif {$kind eq "word" && [dict exists $n inner]} {
        foreach innern [dict get [dict get $n inner] nodes] {
            tclparse::_walk_node_path $innern $visitor $ancestors
        }
    }
}

# --------------------------------------------------------------------------
# find, command_of
# --------------------------------------------------------------------------

# Return every command whose first word has the given text, across all
# depths. Signature: find <cst> -name <value>.
proc tclparse::find {cst args} {
    if {[llength $args] != 2 || [lindex $args 0] ne "-name"} {
        throw [list TCLPARSE BADARGS] \
            "find: expected -name <value>"
    }
    set name [lindex $args 1]
    set matches [list]
    tclparse::_find_into $cst $name matches
    return $matches
}

proc tclparse::_find_into {cst name matchesName} {
    upvar 1 $matchesName matches
    foreach n [dict get $cst nodes] {
        set kind [dict get $n kind]
        if {$kind eq "command"} {
            if {[tclparse::command_of $n] eq $name} {
                lappend matches $n
            }
            foreach bn [dict get $n body] {
                if {[dict get $bn kind] eq "word" && [dict exists $bn inner]} {
                    tclparse::_find_into [dict get $bn inner] $name matches
                }
            }
        } elseif {$kind eq "word" && [dict exists $n inner]} {
            tclparse::_find_into [dict get $n inner] $name matches
        }
    }
}

# Return the text of a command's first word. Empty string if not a
# command or if the command has no leading word.
proc tclparse::command_of {node} {
    if {[dict get $node kind] ne "command"} {
        return ""
    }
    foreach bn [dict get $node body] {
        if {[dict get $bn kind] eq "word"} {
            return [dict get $bn text]
        }
    }
    return ""
}

# --------------------------------------------------------------------------
# structural, words_of, blank_line_count
# --------------------------------------------------------------------------

# Top-level nodes with whitespace filtered out. Comment and terminator are
# kept — the filter is "structural tokens minus whitespace trivia," not
# "commands only."
proc tclparse::structural {cst} {
    set out [list]
    foreach n [dict get $cst nodes] {
        if {[dict get $n kind] ne "whitespace"} {
            lappend out $n
        }
    }
    return $out
}

# Return the word-kind nodes from a command's body (drops whitespace and
# unknown). Throws if the argument is not a command node.
proc tclparse::words_of {command_node} {
    if {[dict get $command_node kind] ne "command"} {
        throw [list TCLPARSE NOT_COMMAND] \
            "words_of: node kind is [dict get $command_node kind], not command"
    }
    set out [list]
    foreach bn [dict get $command_node body] {
        if {[dict get $bn kind] eq "word"} {
            lappend out $bn
        }
    }
    return $out
}

# Number of blank lines in a whitespace node's content. A run containing
# N newlines represents max(0, N - 1) blank lines — a single newline
# separates two non-blank lines and counts as zero blank lines.
proc tclparse::blank_line_count {ws_node} {
    if {[dict get $ws_node kind] ne "whitespace"} {
        throw [list TCLPARSE NOT_WHITESPACE] \
            "blank_line_count: node kind is [dict get $ws_node kind]"
    }
    set n [regexp -all -- {\n} [dict get $ws_node text]]
    if {$n < 2} { return 0 }
    return [expr {$n - 1}]
}

# --------------------------------------------------------------------------
# position_of, positions_of
# --------------------------------------------------------------------------

# Return {line col} for the node with the given id, coordinates relative
# to the text that <cst> was parsed from. Throws {TCLPARSE NOT_FOUND} if
# the id isn't reachable. O(n) per call — callers who need many positions
# should use positions_of.
proc tclparse::position_of {cst id} {
    set found [tclparse::_pos_search [dict get $cst nodes] $id 0 0]
    if {[lindex $found 0]} {
        return [lrange $found 1 2]
    }
    throw [list TCLPARSE NOT_FOUND] \
        "position_of: id $id not reachable from this cst"
}

# Translate the inner-local (line, col) recorded on a node into the outer
# coordinates used by the enclosing CST. The anchor (anchor_line,
# anchor_col) is the outer (line, col) corresponding to the inner's (1, 1).
# An anchor of (0, 0) means "no translation" (root CST).
proc tclparse::_pos_translate {line col anchor_line anchor_col} {
    if {$anchor_line == 0 && $anchor_col == 0} {
        return [list $line $col]
    }
    if {$line == 1} {
        return [list $anchor_line [expr {$anchor_col + $col - 1}]]
    }
    return [list [expr {$anchor_line + $line - 1}] $col]
}

proc tclparse::_pos_search {nodes id anchor_line anchor_col} {
    foreach n $nodes {
        lassign [tclparse::_pos_translate [dict get $n line] [dict get $n col] \
                     $anchor_line $anchor_col] out_line out_col
        if {[dict get $n id] == $id} {
            return [list 1 $out_line $out_col]
        }
        set kind [dict get $n kind]
        if {$kind eq "command"} {
            set r [tclparse::_pos_search [dict get $n body] $id \
                       $anchor_line $anchor_col]
            if {[lindex $r 0]} { return $r }
        } elseif {$kind eq "word" && [dict exists $n inner]} {
            # The braced word's outer position is (out_line, out_col). The
            # opening brace sits at out_col; the first interior character
            # is at out_col + 1, so the inner's (1, 1) anchors to
            # (out_line, out_col + 1).
            set r [tclparse::_pos_search [dict get [dict get $n inner] nodes] \
                       $id $out_line [expr {$out_col + 1}]]
            if {[lindex $r 0]} { return $r }
        }
    }
    return [list 0 0 0]
}

# Return a dict mapping every reachable node id to {line col}, coordinates
# relative to <cst>'s text. One walk.
proc tclparse::positions_of {cst} {
    set d [dict create]
    tclparse::_pos_collect [dict get $cst nodes] 0 0 d
    return $d
}

proc tclparse::_pos_collect {nodes anchor_line anchor_col dictName} {
    upvar 1 $dictName d
    foreach n $nodes {
        lassign [tclparse::_pos_translate [dict get $n line] [dict get $n col] \
                     $anchor_line $anchor_col] out_line out_col
        dict set d [dict get $n id] [list $out_line $out_col]
        set kind [dict get $n kind]
        if {$kind eq "command"} {
            tclparse::_pos_collect [dict get $n body] $anchor_line $anchor_col d
        } elseif {$kind eq "word" && [dict exists $n inner]} {
            tclparse::_pos_collect [dict get [dict get $n inner] nodes] \
                $out_line [expr {$out_col + 1}] d
        }
    }
}
