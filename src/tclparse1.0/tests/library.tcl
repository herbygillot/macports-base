# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# Shared test helpers for tclparse. Each .test file sources this for
# the fixture loader and strict-UTF-8 channel setup. No macports1.0
# dependency — tclparse is pure string code.
#
# Package loading is NOT handled here. Tests reach tclparse the way a
# normal consumer would: `package require tclparse 1.0`, with the
# package located on auto_path via TCLLIBPATH. `make test` sets
# TCLLIBPATH to the package directory; for manual runs, export it
# yourself:
#
#     TCLLIBPATH="$(pwd)/src/tclparse1.0" vendor/tcl/unix/tclsh \
#         src/tclparse1.0/tests/lex.test

# Strict UTF-8 for all file I/O — the parser assumes character data.
encoding system utf-8
chan configure stdout -encoding utf-8 -profile strict
chan configure stderr -encoding utf-8 -profile strict

set _tclparse_test_dir [file dirname [file normalize [info script]]]

# Fixture loader. Reads a file from tests/fixtures/ with strict UTF-8 and
# returns the decoded character string — tclparse is documented to operate
# on character data (see NOTES.md "Tcl 9 compliance"). Fixtures that rely
# on specific byte content (BOM, CRLF) are marked -text in .gitattributes
# so git does not rewrite them on checkout.
proc load_fixture {name} {
    variable ::_tclparse_test_dir
    set path [file join $::_tclparse_test_dir fixtures $name]
    set f [open $path rb]
    try {
        set bytes [read $f]
    } finally {
        close $f
    }
    # Read as bytes to preserve CRLF/BOM exactly, then decode strict UTF-8
    # so the parser sees character data (single-codepoint BOM, diacritics
    # as one char each, etc.). strict profile surfaces malformed UTF-8 as
    # an error rather than a silent substitution.
    return [encoding convertfrom -profile strict utf-8 $bytes]
}
