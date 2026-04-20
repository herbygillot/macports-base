# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# cst.tcl
#
# CST construction. Public entry: tclparse::parse. Static-data accessors:
# tclparse::node_kinds, tclparse::word_kinds. Internal builders live in
# tclparse::cst::. See NOTES.md for the grouping rules used here.

namespace eval tclparse::cst {
    # Proto-token id allocator used only inside parse. Each top-level parse
    # starts fresh; descent allocates a new one per inner.
    variable _next_id 0
}

# Public API --------------------------------------------------------------

# Static-data accessors (procs returning fresh copies so consumers can
# mutate the returned list without affecting subsequent callers).
proc tclparse::node_kinds {} {
    return [list command comment terminator whitespace unknown word]
}

proc tclparse::word_kinds {} {
    return [list bare braced quoted composite]
}

# Parse Tcl source text into a CST. Returns a dict with one key, nodes.
# Every braced word is opaque (text only; no inner). Descent is a separate
# pass (tclparse::descend).
proc tclparse::parse {text} {
    set protos [tclparse::lex::scan $text]
    return [tclparse::cst::_build $protos]
}

# Internal: build a CST from a flat proto-token stream -------------------

# _allocate_id returns the next unique node id. Callers are within a single
# parse invocation; the allocator is reset at the start of parse.
proc tclparse::cst::_allocate_id {} {
    variable _next_id
    return [incr _next_id]
}

# Group the flat proto-token stream into a CST per the positional rules
# described in NOTES.md "CST construction":
#   command: one or more words with interior whitespace/unknown, closed by
#            a newline-bearing whitespace run, a terminator, or EOF.
#   comment: top-level only (lexer only emits at command start).
#   whitespace: top level if it closes or separates commands; inside a
#               command body if it sits between words without a newline.
#   terminator: top level; always closes the enclosing command.
#   unknown: inside a command body if a command is currently open;
#            top level otherwise.
proc tclparse::cst::_build {protos} {
    variable _next_id
    set _next_id 0
    set top [list]
    # The current command's body buffer. Empty means no command is open.
    set body [list]
    foreach tok $protos {
        set kind [dict get $tok kind]
        switch -- $kind {
            word {
                lappend body [_make_token_node $tok]
            }
            whitespace {
                set text [dict get $tok text]
                # A whitespace run closes the current command iff it
                # contains an unescaped newline. The lexer consumes
                # backslash-newline continuations as part of the
                # whitespace text; those do NOT terminate commands.
                if {[_ws_has_cmd_newline $text]} {
                    if {[llength $body] > 0} {
                        lappend top [_finalize_command $body]
                        set body [list]
                    }
                    lappend top [_make_token_node $tok]
                } else {
                    if {[llength $body] > 0} {
                        lappend body [_make_token_node $tok]
                    } else {
                        lappend top [_make_token_node $tok]
                    }
                }
            }
            terminator {
                if {[llength $body] > 0} {
                    lappend top [_finalize_command $body]
                    set body [list]
                }
                lappend top [_make_token_node $tok]
            }
            comment {
                # Comments only appear at command start per the lexer
                # contract; body is already empty here.
                lappend top [_make_token_node $tok]
            }
            unknown {
                # An unknown token inside a command body stays in the body;
                # otherwise it sits at the top level. An unknown that spans
                # newlines internally does not, by itself, close the
                # command: the following newline-bearing whitespace will.
                if {[llength $body] > 0} {
                    lappend body [_make_token_node $tok]
                } else {
                    lappend top [_make_token_node $tok]
                }
            }
            default {
                # Defensive: if the lexer ever grows a new kind, surface it
                # rather than silently drop it.
                throw [list TCLPARSE UNKNOWN_KIND] \
                    "unexpected proto-token kind: $kind"
            }
        }
    }
    if {[llength $body] > 0} {
        lappend top [_finalize_command $body]
    }
    return [dict create nodes $top]
}

# Turn a proto-token dict into a CST node by attaching an id and dropping
# fields that do not belong on the node kind.
proc tclparse::cst::_make_token_node {tok} {
    set id [_allocate_id]
    set kind [dict get $tok kind]
    set line [dict get $tok line]
    set col [dict get $tok col]
    switch -- $kind {
        word {
            set wk [dict get $tok word_kind]
            set text [dict get $tok text]
            return [dict create \
                id $id kind word word_kind $wk \
                text $text line $line col $col]
        }
        terminator {
            # No text on terminator nodes — emit writes ";" at render time.
            return [dict create \
                id $id kind terminator \
                line $line col $col]
        }
        default {
            return [dict create \
                id $id kind $kind \
                text [dict get $tok text] \
                line $line col $col]
        }
    }
}

# Wrap a list of body token nodes into a command node. The command's
# line/col come from its first body token.
proc tclparse::cst::_finalize_command {body} {
    set first [lindex $body 0]
    return [dict create \
        id [_allocate_id] kind command \
        body $body \
        line [dict get $first line] \
        col [dict get $first col]]
}

# Return 1 iff a whitespace run contains a command-terminating newline,
# i.e. a \n not immediately preceded by a backslash (backslash-newline
# continuations do NOT terminate commands).
proc tclparse::cst::_ws_has_cmd_newline {text} {
    set len [string length $text]
    for {set i 0} {$i < $len} {incr i} {
        set c [string index $text $i]
        if {$c eq "\\" && $i + 1 < $len && [string index $text [expr {$i + 1}]] eq "\n"} {
            incr i
            continue
        }
        if {$c eq "\n"} {
            return 1
        }
    }
    return 0
}
