# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# classify.tcl
#
# Semantic queries over the directives table defined in directives.tcl.
# Accessor procs return fresh copies; classify / resolve return the
# classification for a specific name or node. classify additionally
# distinguishes Tcl control-flow (which is descended but not a MacPorts
# directive) and unknown commands.

namespace eval portparse {}
namespace eval portparse::classify {}

# --------------------------------------------------------------------------
# Internal: names recognised as Tcl control-flow. Sourced from
# [tclparse::default_policy] so adding a new default-policy entry in
# tclparse is automatically reflected here.
# --------------------------------------------------------------------------

proc portparse::classify::_tcl_control_names {} {
    return [dict keys [tclparse::default_policy]]
}

# --------------------------------------------------------------------------
# Public: directives — return a fresh copy of the classification table.
# --------------------------------------------------------------------------

proc portparse::directives {} {
    variable _directives
    # Shallow-copy the outer dict. Inner values are small static dicts of
    # literal strings and lists — handing the caller a dup of the outer
    # is enough to prevent in-process mutation of the shipped table.
    set out [dict create]
    dict for {k v} $_directives {
        dict set out $k $v
    }
    return $out
}

# --------------------------------------------------------------------------
# Public: classify a command node.
#   Returns dict with `kind` discriminator:
#     {kind port-directive sets <list> category <cat>}
#     {kind tcl-control}
#     {kind unknown}
#   Empty dict for a non-command node (mirrors command_of's non-throwing
#   contract).
# --------------------------------------------------------------------------

proc portparse::classify {node} {
    if {[dict get $node kind] ne "command"} {
        return [dict create]
    }
    set name [tclparse::command_of $node]
    return [portparse::resolve $name]
}

# --------------------------------------------------------------------------
# Public: resolve a name to its classification, without a node. Same
# return shape as classify (minus the non-command case).
# --------------------------------------------------------------------------

proc portparse::resolve {name} {
    variable _directives
    if {[dict exists $_directives $name]} {
        set entry [dict get $_directives $name]
        return [dict create \
            kind     port-directive \
            sets     [dict get $entry sets] \
            category [dict get $entry category]]
    }
    # options-registered directives gain five suffix variants via aliases
    # in portutil.tcl's `options` proc (-append, -prepend, -delete,
    # -strsed, -replace). All five set the same base; surface them as the
    # base directive's classification rather than duplicating the table.
    #
    # The alias mechanism applies only to names registered via `options`
    # (directly or transitively through `options_export` and `commands`).
    # Names registered via `target_provides` — every `phase`-category
    # entry: phase bodies, pre-/post- hooks, variant/subport/platform —
    # are plain procs, not options, so `pre-configure-append` etc. are
    # not real directives. PortSystem/PortGroup are also procs, not
    # options; they live in metadata but are named-excluded here.
    set non_aliasable {PortSystem PortGroup}
    foreach suffix {-append -prepend -delete -strsed -replace} {
        if {[string length $name] <= [string length $suffix]} continue
        if {[string range $name end-[expr {[string length $suffix] - 1}] end] ne $suffix} continue
        set base [string range $name 0 end-[string length $suffix]]
        if {![dict exists $_directives $base]} continue
        set entry [dict get $_directives $base]
        if {[dict get $entry category] eq "phase"} continue
        if {$base in $non_aliasable} continue
        return [dict create \
            kind     port-directive \
            sets     [dict get $entry sets] \
            category [dict get $entry category]]
    }
    if {$name in [portparse::classify::_tcl_control_names]} {
        return [dict create kind tcl-control]
    }
    return [dict create kind unknown]
}

# --------------------------------------------------------------------------
# Public: directives_in_category — list of directive names in the given
# category. Empty list for an unknown category (not an error — callers
# can probe categories).
# --------------------------------------------------------------------------

proc portparse::directives_in_category {category} {
    variable _directives
    set out [list]
    dict for {name entry} $_directives {
        if {[dict get $entry category] eq $category} {
            lappend out $name
        }
    }
    return [lsort $out]
}

# --------------------------------------------------------------------------
# Public: field_setters — list of directive names that declare
# `sets <field> ...`.
# --------------------------------------------------------------------------

proc portparse::field_setters {field} {
    variable _directives
    set out [list]
    dict for {name entry} $_directives {
        if {$field in [dict get $entry sets]} {
            lappend out $name
        }
    }
    return [lsort $out]
}
