# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# body_policy.tcl
#
# Descent policy for MacPorts directives. Composed from
# [tclparse::default_policy] (so if/foreach/while/for/switch descent comes
# free) + MacPorts body directives. Consumed by portparse::parse to build
# a Portfile-aware CST.
#
# Directives with braced-list args (depends_*, master_sites, distfiles,
# checksums, patchfiles, license, categories, etc.) deliberately have NO
# entry here: their braced contents are data literals, not Tcl code.
# Parsing `{sha256 abc... rmd160 def...}` as commands would produce
# nonsense. See NOTES.md "Two registries, not one" for the split between
# the classify table and body policy.

namespace eval portparse {}

# --------------------------------------------------------------------------
# portparse::body_policy
#
# Returns a fresh dict each call — merges with tclparse::default_policy
# at the top so callers get a consistent snapshot.
# --------------------------------------------------------------------------

proc portparse::body_policy {} {
    set p [tclparse::default_policy]

    # Body containers: value is a script.
    foreach cmd {variant subport platform} {
        dict set p $cmd {positions last}
    }

    # Target-override bodies. Every target registered via target_provides
    # in src/port1.0/*.tcl (23 total). `distfiles` is intentionally
    # excluded: its primary usage is the data form (`distfiles file1
    # file2 ...`), and its classification lives in the `source` category.
    # Descending a braced distfiles arg as Tcl would mis-parse a distfile
    # list as commands. Portfiles that need to override the distfiles
    # target body are outside v1 scope — pre-distfiles/post-distfiles
    # hooks below cover the common case.
    foreach cmd {activate bump build checksum clean configure deactivate
                 destroot distcheck extract fetch install lint livecheck
                 load main mirror patch reload test uninstall unload} {
        dict set p $cmd {positions last}
    }

    # pre-<target> / post-<target> hooks for every registered target
    # (23 targets × 2 = 46 entries). pre-distfiles/post-distfiles are
    # included because hook bodies are always Tcl code, even when the
    # target itself is a data directive.
    foreach target {activate bump build checksum clean configure deactivate
                    destroot distcheck distfiles extract fetch install lint
                    livecheck load main mirror patch reload test uninstall
                    unload} {
        dict set p "pre-$target"  {positions last}
        dict set p "post-$target" {positions last}
    }

    return $p
}
