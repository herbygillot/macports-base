# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# Shared test helpers for portparse. Each .test file sources this for
# the fixture loader and strict-UTF-8 channel setup. No macports1.0
# dependency — portparse is pure string code layered on tclparse.
#
# Package loading is NOT handled here. Tests reach portparse (and
# tclparse) the way a normal consumer would: `package require
# portparse 1.0`, with both packages located on auto_path via
# TCLLIBPATH. `make test` sets TCLLIBPATH to both package directories;
# for manual runs, export it yourself:
#
#     TCLLIBPATH="$(pwd)/src/tclparse1.0 $(pwd)/src/portparse1.0" \
#         vendor/tcl/unix/tclsh src/portparse1.0/tests/classify.test

encoding system utf-8
chan configure stdout -encoding utf-8 -profile strict
chan configure stderr -encoding utf-8 -profile strict

set _portparse_test_dir [file dirname [file normalize [info script]]]

# Fixture loader — bytes on disk, chars in parser (matches tclparse's
# library.tcl). Fixtures needing byte-exact round-trip are marked
# -text in .gitattributes.
proc load_fixture {name} {
    variable ::_portparse_test_dir
    set path [file join $::_portparse_test_dir fixtures $name]
    set f [open $path rb]
    try {
        set bytes [read $f]
    } finally {
        close $f
    }
    return [encoding convertfrom -profile strict utf-8 $bytes]
}
