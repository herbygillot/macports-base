# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# lex.tcl
#
# Tokenizer. Internal namespace tclparse::lex::. Not part of the public API.
# See NOTES.md "Lexing gotchas" for the rules this module enforces.
#
# Output: a flat list of proto-token dicts in source order. Each has fields:
#   kind      — one of: whitespace comment terminator word unknown
#   text      — literal source characters (terminator has none; implicit ";")
#   line, col — 1-indexed start position, character columns
#   word_kind — for kind=word only: bare | braced | quoted | composite
#
# Proto-tokens carry no id — id allocation happens during CST construction.

namespace eval tclparse::lex {}

# Public (to the package) entry. Input is the full source text; output is the
# flat proto-token stream.
proc tclparse::lex::scan {text} {
    set tokens [list]
    set pos 0
    set line 1
    set col 1
    set len [string length $text]

    # UTF-8 BOM at position 0 is its own unknown token, width 1 at {1 1}.
    # Anywhere else U+FEFF is a literal character (handled by word scanning).
    if {$len > 0 && [string index $text 0] eq "\uFEFF"} {
        lappend tokens [dict create \
            kind unknown \
            text "\uFEFF" \
            line 1 col 1]
        set pos 1
        set col 2
    }

    # at_cmd_start: 1 when the next non-trivia token would begin a new command.
    # True at start of file and right after a command terminator.
    set at_cmd_start 1

    while {$pos < $len} {
        # Whitespace run: spaces, tabs, \r, \f, \v, \n, and \<nl> continuations.
        # Empty runs are not emitted. A run containing an unescaped newline
        # resets at_cmd_start to 1.
        set ws_start $pos
        set ws_start_line $line
        set ws_start_col $col
        set had_newline 0
        while {$pos < $len} {
            set c [string index $text $pos]
            if {$c eq "\\" && $pos + 1 < $len && [string index $text [expr {$pos + 1}]] eq "\n"} {
                incr pos 2
                incr line
                set col 1
            } elseif {$c eq "\n"} {
                set had_newline 1
                incr pos
                incr line
                set col 1
            } elseif {$c eq " " || $c eq "\t" || $c eq "\r" || $c eq "\f" || $c eq "\v"} {
                incr pos
                incr col
            } else {
                break
            }
        }
        if {$pos > $ws_start} {
            lappend tokens [dict create \
                kind whitespace \
                text [string range $text $ws_start [expr {$pos - 1}]] \
                line $ws_start_line col $ws_start_col]
            if {$had_newline} {
                set at_cmd_start 1
            }
            continue
        }

        if {$pos >= $len} break
        set c [string index $text $pos]

        # Command terminator.
        if {$c eq ";"} {
            lappend tokens [dict create \
                kind terminator \
                text ";" \
                line $line col $col]
            incr pos
            incr col
            set at_cmd_start 1
            continue
        }

        # Comment: only at command start. Runs to the next newline that is
        # not escaped as a backslash-newline continuation. A comment ending
        # with backslash-newline continues onto the next physical line.
        if {$c eq "#" && $at_cmd_start} {
            set c_start $pos
            set c_line $line
            set c_col $col
            while {$pos < $len} {
                set cc [string index $text $pos]
                if {$cc eq "\\" && $pos + 1 < $len && [string index $text [expr {$pos + 1}]] eq "\n"} {
                    incr pos 2
                    incr line
                    set col 1
                } elseif {$cc eq "\n"} {
                    break
                } else {
                    incr pos
                    incr col
                }
            }
            lappend tokens [dict create \
                kind comment \
                text [string range $text $c_start [expr {$pos - 1}]] \
                line $c_line col $c_col]
            # The trailing \n is consumed by the whitespace loop next iteration;
            # at_cmd_start flips there.
            continue
        }

        # Word.
        set result [_scan_word $text $pos $line $col]
        lassign $result tok pos line col
        lappend tokens $tok
        set at_cmd_start 0
    }

    return $tokens
}

# Dispatch a word scan based on the first character.
proc tclparse::lex::_scan_word {text pos line col} {
    set c [string index $text $pos]
    if {$c eq "\{"} {
        return [_scan_braced $text $pos $line $col]
    } elseif {$c eq "\""} {
        return [_scan_quoted $text $pos $line $col]
    } else {
        return [_scan_bare $text $pos $line $col]
    }
}

# Braced word: tracks {} nesting. \{ and \} inside are literal (the escape
# pair is consumed whole and doesn't affect nesting). Unbalanced → recovery.
proc tclparse::lex::_scan_braced {text pos line col} {
    set len [string length $text]
    set start $pos
    set start_line $line
    set start_col $col
    set depth 1
    incr pos
    incr col
    while {$pos < $len && $depth > 0} {
        set c [string index $text $pos]
        if {$c eq "\\" && $pos + 1 < $len} {
            set next [string index $text [expr {$pos + 1}]]
            if {$next eq "\n"} {
                incr pos 2
                incr line
                set col 1
            } else {
                incr pos 2
                incr col 2
            }
        } elseif {$c eq "\{"} {
            incr depth
            incr pos
            incr col
        } elseif {$c eq "\}"} {
            incr depth -1
            incr pos
            incr col
        } elseif {$c eq "\n"} {
            incr pos
            incr line
            set col 1
        } else {
            incr pos
            incr col
        }
    }
    if {$depth > 0} {
        return [_recover_unknown $text $start $start_line $start_col]
    }
    set tok [dict create \
        kind word word_kind braced \
        text [string range $text $start [expr {$pos - 1}]] \
        line $start_line col $start_col]
    return [list $tok $pos $line $col]
}

# Quoted word: honors \" and other backslash escapes. Unclosed → recovery.
proc tclparse::lex::_scan_quoted {text pos line col} {
    set len [string length $text]
    set start $pos
    set start_line $line
    set start_col $col
    incr pos
    incr col
    set closed 0
    while {$pos < $len} {
        set c [string index $text $pos]
        if {$c eq "\\" && $pos + 1 < $len} {
            set next [string index $text [expr {$pos + 1}]]
            if {$next eq "\n"} {
                incr pos 2
                incr line
                set col 1
            } else {
                incr pos 2
                incr col 2
            }
        } elseif {$c eq "\""} {
            incr pos
            incr col
            set closed 1
            break
        } elseif {$c eq "\n"} {
            incr pos
            incr line
            set col 1
        } else {
            incr pos
            incr col
        }
    }
    if {!$closed} {
        return [_recover_unknown $text $start $start_line $start_col]
    }
    set tok [dict create \
        kind word word_kind quoted \
        text [string range $text $start [expr {$pos - 1}]] \
        line $start_line col $start_col]
    return [list $tok $pos $line $col]
}

# Bare word: ends at whitespace, ;, or \<nl>. $var, ${var}, and [subcmd]
# upgrade word_kind to composite but do not end the word. \x escapes (where
# x is not newline) consume the pair. Unbalanced [ triggers recovery.
proc tclparse::lex::_scan_bare {text pos line col} {
    set len [string length $text]
    set start $pos
    set start_line $line
    set start_col $col
    set composite 0
    while {$pos < $len} {
        set c [string index $text $pos]
        if {$c eq "\\"} {
            if {$pos + 1 < $len} {
                set next [string index $text [expr {$pos + 1}]]
                if {$next eq "\n"} {
                    break
                }
                incr pos 2
                incr col 2
            } else {
                incr pos
                incr col
            }
        } elseif {$c eq "\$"} {
            set composite 1
            incr pos
            incr col
            if {$pos < $len && [string index $text $pos] eq "\{"} {
                # Dollar-brace form: consume to the closing brace.
                incr pos
                incr col
                while {$pos < $len && [string index $text $pos] ne "\}"} {
                    if {[string index $text $pos] eq "\n"} {
                        incr line
                        set col 1
                    } else {
                        incr col
                    }
                    incr pos
                }
                if {$pos < $len} {
                    incr pos
                    incr col
                }
            } else {
                # $name: [A-Za-z0-9_] with optional :: separators.
                while {$pos < $len} {
                    set nc [string index $text $pos]
                    if {[string match {[A-Za-z0-9_]} $nc]} {
                        incr pos
                        incr col
                    } elseif {$nc eq ":" && $pos + 1 < $len && [string index $text [expr {$pos + 1}]] eq ":"} {
                        incr pos 2
                        incr col 2
                    } else {
                        break
                    }
                }
            }
        } elseif {$c eq "\["} {
            set composite 1
            incr pos
            incr col
            set depth 1
            while {$pos < $len && $depth > 0} {
                set cc [string index $text $pos]
                if {$cc eq "\\" && $pos + 1 < $len} {
                    if {[string index $text [expr {$pos + 1}]] eq "\n"} {
                        incr pos 2
                        incr line
                        set col 1
                    } else {
                        incr pos 2
                        incr col 2
                    }
                } elseif {$cc eq "\["} {
                    incr depth
                    incr pos
                    incr col
                } elseif {$cc eq "\]"} {
                    incr depth -1
                    incr pos
                    incr col
                } elseif {$cc eq "\n"} {
                    incr pos
                    incr line
                    set col 1
                } else {
                    incr pos
                    incr col
                }
            }
            if {$depth > 0} {
                return [_recover_unknown $text $start $start_line $start_col]
            }
        } elseif {$c eq " " || $c eq "\t" || $c eq "\n" || $c eq "\r" \
                  || $c eq "\f" || $c eq "\v" || $c eq ";"} {
            break
        } else {
            incr pos
            incr col
        }
    }
    if {$pos == $start} {
        # Defensive: first char was something strange (e.g. a bare close
        # brace that we can't categorize). Emit as unknown, one char wide.
        set tok [dict create \
            kind unknown \
            text [string index $text $start] \
            line $start_line col $start_col]
        incr pos
        incr col
        return [list $tok $pos $line $col]
    }
    set wk [expr {$composite ? "composite" : "bare"}]
    set tok [dict create \
        kind word word_kind $wk \
        text [string range $text $start [expr {$pos - 1}]] \
        line $start_line col $start_col]
    return [list $tok $pos $line $col]
}

# Recovery: from the point of unbalance to the next blank-line separator
# (\n followed by optional horizontal whitespace followed by another \n),
# or to EOF if no blank line follows. The unknown token stops at (but does
# not include) the first \n of the blank-line pattern, so the separator
# itself tokenizes normally as whitespace after recovery.
proc tclparse::lex::_recover_unknown {text start start_line start_col} {
    set len [string length $text]
    set search [string range $text $start end]
    if {[regexp -indices -- {\n[ \t\r\f\v]*\n} $search m]} {
        lassign $m m_start _m_end
        set end_pos [expr {$start + $m_start}]
    } else {
        set end_pos $len
    }
    lassign [_advance_pos $text $start $end_pos $start_line $start_col] new_line new_col
    set tok [dict create \
        kind unknown \
        text [string range $text $start [expr {$end_pos - 1}]] \
        line $start_line col $start_col]
    return [list $tok $end_pos $new_line $new_col]
}

# Advance (line, col) over the range [from, to) in text.
proc tclparse::lex::_advance_pos {text from to from_line from_col} {
    set line $from_line
    set col $from_col
    for {set i $from} {$i < $to} {incr i} {
        if {[string index $text $i] eq "\n"} {
            incr line
            set col 1
        } else {
            incr col
        }
    }
    return [list $line $col]
}
