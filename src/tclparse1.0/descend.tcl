# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# descend.tcl
#
# Descent mechanism (language-neutral). Defines tclparse::descend, which
# walks a CST and, for each command matching a policy entry, rewrites
# braced-word arguments at the declared positions so their text becomes a
# nested CST stored in `inner`. Tcl-specific knowledge (default_policy,
# if_bodies, switch_bodies) lives in policy.tcl.
#
# ID uniqueness. Every inner parse starts with its own id 1; descend
# renumbers the freshly-parsed subtree by offsetting all ids by the
# current outer max, then records the new max. This keeps the public
# contract — globally unique ids across the tree, existing ids unchanged —
# without exposing an allocator parameter on parse.
#
# Policy entry forms:
#   {positions <list>}   values are positive integers (1-based arg index,
#                        not word index — arg 1 is the word after the
#                        command name) or the literal "last". The
#                        mechanism parses and recursively descends each
#                        braced arg at those positions itself.
#   {handler <proc>}     the handler is called as
#                        `$handler <command> <policy>` and must return a
#                        list of {arg-index inner-cst} pairs. The handler
#                        is responsible for parsing and recursive descent
#                        (typically via tclparse::parse + tclparse::descend
#                        with the passed-in policy). The mechanism
#                        renumbers the returned inner ids to keep the
#                        global-uniqueness invariant.
#                        Policy-threading matters: if a caller composes a
#                        richer policy on top of default_policy (as
#                        portparse::body_policy does), handlers must
#                        descend with that composed policy, not the
#                        default, or MacPorts bodies nested inside if/
#                        switch would be missed.

namespace eval tclparse {}

# --------------------------------------------------------------------------
# Public entry
# --------------------------------------------------------------------------

proc tclparse::descend {cst policy} {
    set max_id [tclparse::_descend_max_id $cst]
    return [tclparse::_descend_cst $cst $policy max_id]
}

# --------------------------------------------------------------------------
# Max-id scan (upfront + on every spliced subtree)
# --------------------------------------------------------------------------

proc tclparse::_descend_max_id {cst} {
    set m 0
    foreach n [dict get $cst nodes] {
        set m [tclparse::_descend_max_id_node $n $m]
    }
    return $m
}

proc tclparse::_descend_max_id_node {n current_max} {
    set m $current_max
    set id [dict get $n id]
    if {$id > $m} { set m $id }
    set kind [dict get $n kind]
    if {$kind eq "command"} {
        foreach bn [dict get $n body] {
            set m [tclparse::_descend_max_id_node $bn $m]
        }
    } elseif {$kind eq "word" && [dict exists $n inner]} {
        foreach innern [dict get [dict get $n inner] nodes] {
            set m [tclparse::_descend_max_id_node $innern $m]
        }
    }
    return $m
}

# --------------------------------------------------------------------------
# Main walk
# --------------------------------------------------------------------------

proc tclparse::_descend_cst {cst policy max_id_var} {
    upvar 1 $max_id_var max_id
    set new_nodes [list]
    foreach n [dict get $cst nodes] {
        lappend new_nodes [tclparse::_descend_node $n $policy max_id]
    }
    return [dict create nodes $new_nodes]
}

proc tclparse::_descend_node {n policy max_id_var} {
    upvar 1 $max_id_var max_id
    set kind [dict get $n kind]
    if {$kind ne "command"} { return $n }
    set name [tclparse::command_of $n]
    if {![dict exists $policy $name]} {
        return [tclparse::_recurse_into_body $n $policy max_id]
    }
    set entry [dict get $policy $name]
    if {[dict exists $entry positions]} {
        return [tclparse::_apply_positions $n $entry $policy max_id]
    }
    if {[dict exists $entry handler]} {
        return [tclparse::_apply_handler $n $entry $policy max_id]
    }
    # Unrecognised entry shape — behave as if absent.
    return [tclparse::_recurse_into_body $n $policy max_id]
}

# Walk body, pass policy down into any already-descended inner CSTs so a
# re-run of descend with a richer policy can keep going without losing
# previously-done work.
proc tclparse::_recurse_into_body {cmd policy max_id_var} {
    upvar 1 $max_id_var max_id
    set new_body [list]
    foreach bn [dict get $cmd body] {
        if {[dict get $bn kind] eq "word" && [dict exists $bn inner]} {
            dict set bn inner [tclparse::_descend_cst [dict get $bn inner] \
                                   $policy max_id]
        }
        lappend new_body $bn
    }
    dict set cmd body $new_body
    return $cmd
}

# --------------------------------------------------------------------------
# Declarative positions
# --------------------------------------------------------------------------

proc tclparse::_apply_positions {cmd entry policy max_id_var} {
    upvar 1 $max_id_var max_id
    set words [tclparse::words_of $cmd]
    set argc [expr {[llength $words] - 1}]
    if {$argc <= 0} {
        return [tclparse::_recurse_into_body $cmd $policy max_id]
    }
    set positions [list]
    foreach p [dict get $entry positions] {
        if {$p eq "last"} {
            lappend positions $argc
        } elseif {[string is integer -strict $p] && $p >= 1 && $p <= $argc} {
            lappend positions $p
        }
    }
    if {[llength $positions] == 0} {
        return [tclparse::_recurse_into_body $cmd $policy max_id]
    }
    # Translate arg-index (1-based) to index into the full words list.
    # words[0] is the command name, so arg i == words[i].
    set new_body [list]
    set word_counter 0
    foreach bn [dict get $cmd body] {
        if {[dict get $bn kind] eq "word"} {
            if {[lsearch -exact -integer $positions $word_counter] >= 0} {
                set bn [tclparse::_descend_word_inline $bn $policy max_id]
            } elseif {[dict exists $bn inner]} {
                dict set bn inner [tclparse::_descend_cst [dict get $bn inner] \
                                       $policy max_id]
            }
            incr word_counter
        }
        lappend new_body $bn
    }
    dict set cmd body $new_body
    return $cmd
}

# Parse the braced word's interior, renumber against the running max_id,
# then recursively descend the result under the same policy. Shape
# mismatch (non-braced arg, or one that already has an inner) is a silent
# no-op.
proc tclparse::_descend_word_inline {word policy max_id_var} {
    upvar 1 $max_id_var max_id
    if {[dict get $word word_kind] ne "braced"} { return $word }
    if {[dict exists $word inner]} {
        dict set word inner [tclparse::_descend_cst [dict get $word inner] \
                                 $policy max_id]
        return $word
    }
    set text [dict get $word text]
    set interior [string range $text 1 end-1]
    set inner [tclparse::parse $interior]
    set inner [tclparse::_renumber_cst $inner $max_id]
    set max_id [tclparse::_descend_max_id $inner]
    set inner [tclparse::_descend_cst $inner $policy max_id]
    dict set word inner $inner
    dict unset word text
    return $word
}

# --------------------------------------------------------------------------
# Handler callback
# --------------------------------------------------------------------------

# Call the handler, splice each returned {arg-index inner-cst} pair onto
# the right word, renumbering to preserve global id uniqueness. Handlers
# that return garbage for a given pair are silently skipped — "shape
# mismatch silently no-ops" extends to handler output.
proc tclparse::_apply_handler {cmd entry policy max_id_var} {
    upvar 1 $max_id_var max_id
    set handler [dict get $entry handler]
    set pairs [$handler $cmd $policy]
    # Build a map: arg-index → inner-cst (last pair wins on duplicate).
    set by_arg [dict create]
    foreach pair $pairs {
        if {[llength $pair] != 2} continue
        lassign $pair arg_index inner_cst
        if {![string is integer -strict $arg_index] || $arg_index < 1} continue
        dict set by_arg $arg_index $inner_cst
    }
    set new_body [list]
    set word_counter 0
    foreach bn [dict get $cmd body] {
        if {[dict get $bn kind] eq "word"} {
            if {[dict exists $bn inner]} {
                # Already descended on a prior pass. Re-descend under
                # the current policy so a richer policy can reach
                # commands that a narrower earlier policy left
                # un-descended. The handler's returned inner for this
                # position is discarded — the existing inner is
                # authoritative and already has stable ids.
                dict set bn inner [tclparse::_descend_cst [dict get $bn inner] \
                                       $policy max_id]
            } elseif {[dict exists $by_arg $word_counter]} {
                set inner_cst [dict get $by_arg $word_counter]
                if {[dict get $bn word_kind] eq "braced"} {
                    set inner_cst [tclparse::_renumber_cst $inner_cst $max_id]
                    set max_id [tclparse::_descend_max_id $inner_cst]
                    dict set bn inner $inner_cst
                    dict unset bn text
                }
            }
            incr word_counter
        }
        lappend new_body $bn
    }
    dict set cmd body $new_body
    return $cmd
}

# --------------------------------------------------------------------------
# Renumber
# --------------------------------------------------------------------------

# Shift every id in a cst by offset; preserves all other fields.
proc tclparse::_renumber_cst {cst offset} {
    set new_nodes [list]
    foreach n [dict get $cst nodes] {
        lappend new_nodes [tclparse::_renumber_node $n $offset]
    }
    return [dict create nodes $new_nodes]
}

proc tclparse::_renumber_node {n offset} {
    dict set n id [expr {[dict get $n id] + $offset}]
    set kind [dict get $n kind]
    if {$kind eq "command"} {
        set new_body [list]
        foreach bn [dict get $n body] {
            lappend new_body [tclparse::_renumber_node $bn $offset]
        }
        dict set n body $new_body
    } elseif {$kind eq "word" && [dict exists $n inner]} {
        dict set n inner [tclparse::_renumber_cst [dict get $n inner] $offset]
    }
    return $n
}
