# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portparse.tcl
#
# Copyright (c) 2026 The MacPorts Project
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# portparse: a MacPorts semantic layer over tclparse. Ships one semantic
# entry point (portparse::parse), semantic queries (classify, resolve,
# directives_in_category, field_setters), and the body-descent policy
# for MacPorts directives. All other CST operations are called at
# tclparse:: directly — the namespace prefix tells the reader which
# layer a line is using. See README.md for the public contract and
# NOTES.md for maintainer context.
#
# Reach for these tclparse accessors directly — portparse does not mirror them:
#   [tclparse::node_kinds]     when a visitor dispatches on node kind.
#   [tclparse::word_kinds]     when reasoning about bare/braced/quoted/composite.
#   [tclparse::default_policy] when composing a custom descent policy; merge
#                              onto it if you want portparse's body descent
#                              plus your own Tcl-control extensions.

package provide portparse 1.0
package require tclparse 1.0

namespace eval portparse {
    namespace eval classify {}
}

set _portparse_dir [file dirname [info script]]
source [file join $_portparse_dir directives.tcl]
source [file join $_portparse_dir classify.tcl]
source [file join $_portparse_dir body_policy.tcl]
unset _portparse_dir

# --------------------------------------------------------------------------
# portparse::parse — the single semantic entry point.
#
# Composition: tclparse::parse $text, then tclparse::descend against
# portparse's body policy. The returned CST is a tclparse CST — every
# tclparse public proc accepts it directly.
# --------------------------------------------------------------------------

proc portparse::parse {text} {
    set cst [tclparse::parse $text]
    return [tclparse::descend $cst [portparse::body_policy]]
}
