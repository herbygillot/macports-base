# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# policy.tcl
#
# Default Tcl control-flow descent policy. Defines tclparse::default_policy
# (accessor) and the if_bodies / switch_bodies callback handlers used by it.
# This file is the only place in tclparse that names specific Tcl commands;
# the mechanism in descend.tcl is language-neutral.

namespace eval tclparse {
    namespace eval cst {}
}

# --------------------------------------------------------------------------
# Accessor — returns a fresh dict every call so consumers can
# `dict merge [tclparse::default_policy] {...}` without affecting the
# shipped policy.
# --------------------------------------------------------------------------

proc tclparse::default_policy {} {
    return [dict create \
        foreach {positions last} \
        while   {positions 2} \
        for     {positions {1 3 4}} \
        if      {handler tclparse::cst::if_bodies} \
        switch  {handler tclparse::cst::switch_bodies}]
}

# --------------------------------------------------------------------------
# if handler. Grammar:
#   if expr1 ?then? body1 elseif expr2 ?then? body2 ... ?else? bodyN
# Returns {arg-index inner-cst} pairs for every body position. Unknown or
# malformed shapes silently skip — the mechanism tolerates shape mismatch.
#
# Receives the caller's policy so recursive descent into the body uses the
# full policy (e.g. portparse's body_policy), not just the default.
# --------------------------------------------------------------------------

proc tclparse::cst::if_bodies {cmd policy} {
    set words [tclparse::words_of $cmd]
    # words[0] is "if"; args start at arg-index 1.
    set n [llength $words]
    set pairs [list]
    set i 1
    set state expect-cond
    while {$i < $n} {
        set w [lindex $words $i]
        # After a prior descend pass, a body word has `inner` and no
        # `text`. Such a word is definitely not a keyword — treat text
        # as empty for keyword-matching purposes.
        if {[dict exists $w text]} {
            set text [dict get $w text]
        } else {
            set text ""
        }
        switch -- $state {
            expect-cond {
                # Condition can be any word shape; skip it.
                incr i
                set state expect-body
            }
            expect-body {
                # Optional "then" keyword before the body.
                if {$text eq "then"} {
                    incr i
                    continue
                }
                lappend pairs [list $i [tclparse::cst::_policy_inner_of $w $policy]]
                incr i
                set state expect-tail
            }
            expect-tail {
                if {$text eq "elseif"} {
                    incr i
                    set state expect-cond
                } elseif {$text eq "else"} {
                    incr i
                    set state expect-else-body
                } else {
                    # Malformed — stop.
                    break
                }
            }
            expect-else-body {
                lappend pairs [list $i [tclparse::cst::_policy_inner_of $w $policy]]
                incr i
                set state done
            }
            done {
                break
            }
        }
    }
    # Drop skip-pairs (non-braced words produce empty sentinel).
    set real [list]
    foreach p $pairs {
        lassign $p idx inner
        if {$inner ne ""} { lappend real $p }
    }
    return $real
}

# --------------------------------------------------------------------------
# switch handler. Grammar:
#   switch ?options? value pattern body ?pattern body ...?   (individual form)
#   switch ?options? value {pattern body ?pattern body ...?} (list form)
# We descend only individual-args form. List-form stays opaque — the
# single remaining braced arg is not a Tcl script; descending it would
# either require a schema flag or produce phantom "commands" whose head
# word is a pattern. Deferred in v1.
# --------------------------------------------------------------------------

proc tclparse::cst::switch_bodies {cmd policy} {
    set words [tclparse::words_of $cmd]
    set n [llength $words]
    # Options that consume a following operand. Closed set in Tcl 9; if
    # a future Tcl grows a new operand-taking option, add it here and
    # pin it with a descend.test case.
    set operand_opts {-matchvar -indexvar}
    # Skip options: args starting with '-'. Stop at '--' (consumed) or
    # at the first non-option arg. Options are only recognised in bare
    # or quoted words with literal text — a braced option would be
    # unusual but harmless to treat as the value. An inner-only word
    # (no text, only inner from a prior descend pass) is never an
    # option either.
    set i 1
    while {$i < $n} {
        set w [lindex $words $i]
        set wk [dict get $w word_kind]
        if {$wk ne "bare" && $wk ne "quoted"} { break }
        if {![dict exists $w text]} { break }
        set text [dict get $w text]
        if {$wk eq "quoted"} {
            set text [string range $text 1 end-1]
        }
        if {![string match "-*" $text]} { break }
        incr i
        if {$text eq "--"} { break }
        if {$text in $operand_opts} { incr i }
    }
    # i now points to the value arg (pattern/value). Skip it.
    if {$i >= $n} { return [list] }
    incr i
    # Remaining args: if exactly one, it's list form → opaque.
    set remaining [expr {$n - $i}]
    if {$remaining <= 1} { return [list] }
    set pairs [list]
    set offset 0
    while {$i < $n} {
        # Even offset = pattern, odd = body.
        if {$offset % 2 == 1} {
            set w [lindex $words $i]
            set inner [tclparse::cst::_policy_inner_of $w $policy]
            if {$inner ne ""} {
                lappend pairs [list $i $inner]
            }
        }
        incr i
        incr offset
    }
    return $pairs
}

# --------------------------------------------------------------------------
# Helper: given a word node, if it is a braced word, parse the interior
# and recursively descend under the caller's policy; return the inner
# CST. Non-braced words return the empty string — the handler treats
# that as "shape mismatch, skip this position."
# --------------------------------------------------------------------------

proc tclparse::cst::_policy_inner_of {word policy} {
    if {[dict get $word word_kind] ne "braced"} {
        return ""
    }
    if {[dict exists $word inner]} {
        return [dict get $word inner]
    }
    set text [dict get $word text]
    set interior [string range $text 1 end-1]
    set inner [tclparse::parse $interior]
    return [tclparse::descend $inner $policy]
}
