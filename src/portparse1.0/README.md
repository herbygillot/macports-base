# portparse

*A Portfile CST on top of `tclparse` — classification, body descent,
drift-checked.*

`portparse` layers MacPorts semantics on top of `tclparse`. It exposes
one semantic entry point that parses and descends a Portfile in one
call, plus a classification API for directives recognised by the base
port1.0 package. Everything structural — emit, walk, find, positions —
is called at `tclparse::` directly. See *The two-namespace idiom* below.

Motivated by [Trac #73863](https://trac.macports.org/ticket/73863)
(`port fmt`), but the parser is infrastructure: any Portfile-reading
tool (linter, bulk-edit tooling) can consume it.

## Getting started

```tcl
package require portparse 1.0  ;# also loads tclparse

set f [open Portfile r]
chan configure $f -encoding utf-8 -profile strict
set text [read $f]; close $f

set cst [portparse::parse $text]

# Structural queries at tclparse::
foreach n [tclparse::find $cst -name depends_lib] {
    set pos [tclparse::position_of $cst [dict get $n id]]
    # Semantic queries at portparse::
    set info [portparse::classify $n]
    puts "$pos: [dict get $info category]"
}

# Byte-identical round-trip via tclparse::emit.
puts [expr {[tclparse::emit $cst] eq $text}]  ;# 1
```

## Guarantees

- **A portparse CST is a tclparse CST.** Every `tclparse::` proc
  (`emit`, `walk`, `walk_with_path`, `find`, `command_of`,
  `position_of`, …) accepts it directly.
- **Byte-identical round-trip.** `tclparse::emit [portparse::parse $x]
  == $x` for every Portfile.
- **Body descent covers MacPorts directives AND Tcl control-flow.**
  `variant`, `subport`, `platform`, every target-override body
  registered via `target_provides` in `src/port1.0/*.tcl`
  (`configure`, `build`, `destroot`, `test`, plus `activate`,
  `checksum`, `clean`, `deactivate`, `extract`, `fetch`, `install`,
  `livecheck`, `load`, `main`, `mirror`, `patch`, `reload`,
  `uninstall`, `unload`, `bump`, `distcheck`, `lint` — 22 targets;
  `distfiles` is excluded because its primary form is a data
  directive), and every `pre-<target>`/`post-<target>` hook for all
  23 targets (including `pre-distfiles`/`post-distfiles`) are
  descended automatically, as is `if`/`foreach`/`while`/`for`/`switch`
  (inherited from `[tclparse::default_policy]`).
- **Classification is kept in sync with port1.0** for string-literal
  registrations via the drift test. Dynamically-constructed directive
  names have a documented carve-out — see *Classification coverage*
  below.

## The two-namespace idiom

The split is load-bearing. The namespace prefix at a call site tells
the reader which layer that line is using.

- `portparse::` — the one entry point (`parse`) and semantic queries
  (`classify`, `resolve`, `directives_in_category`, `field_setters`)
  and semantic accessor data (`directives`, `categories`,
  `body_policy`).
- `tclparse::` — everything structural: `emit`, `walk`,
  `walk_with_path`, `find`, `command_of`, `structural`, `words_of`,
  `blank_line_count`, `position_of`, `positions_of`, plus the generic
  accessors (`node_kinds`, `word_kinds`, `default_policy`).

`portparse` deliberately does **not** re-export tclparse's surface. A
pass-through layer would tie the namespaces back together and erase
the clarity the prefix was supposed to give.

## Public API

### Entry point

- `portparse::parse <text>` — parse and descend in one call.
  Equivalent to `tclparse::parse $text` followed by `tclparse::descend
  $cst [portparse::body_policy]`. Returns a tclparse CST.

### Semantic queries

- `portparse::classify <command-node>` — returns
  `{kind port-directive sets <list> category <cat>}`,
  `{kind tcl-control}`, or `{kind unknown}`. Returns an empty dict for
  a non-command node (mirrors `tclparse::command_of`'s non-throwing
  contract).
- `portparse::resolve <name>` — classification by name, no node
  required. Same return shape (minus the non-command case). Suffix
  aliases (`-append`, `-prepend`, `-delete`, `-strsed`, `-replace`)
  resolve to the base directive's entry, but only for bases registered
  via `options` or `commands` (i.e. where the alias mechanism actually
  fires in portutil.tcl). Names like `pre-configure-append` or
  `variant-append` resolve to `{kind unknown}` — the base is a target
  hook or proc, not an option, so no `-append` alias is generated at
  runtime either.
- `portparse::directives_in_category <category>` — list of directive
  names in the category; empty list for an unknown category.
- `portparse::field_setters <field>` — list of directive names whose
  `sets` list contains the given field.

### Semantic accessor data

Exposed as accessor procs; each call returns a fresh copy.

- `portparse::directives` — classification table. Keyed by directive
  name; values are `{sets <list> category <cat>}`. Excludes
  `tcl-control` names (those live in `[tclparse::default_policy]`).
- `portparse::categories` — ordered list: `identity metadata source
  dependency build-config phase`.
- `portparse::body_policy` — descent policy used by
  `portparse::parse`. Composed from `[tclparse::default_policy]` +
  MacPorts body-directive entries.

### Pointers to tclparse accessors

Reach for these directly at `tclparse::`; portparse does not mirror
them.

- `[tclparse::node_kinds]` — switch on this when your visitor
  dispatches by kind (`command` / `word` / `comment` / `whitespace`
  / `terminator` / `unknown`).
- `[tclparse::word_kinds]` — when inspecting a word's kind
  (`bare` / `braced` / `quoted` / `composite`).
- `[tclparse::default_policy]` — the generic Tcl-control-flow policy;
  merge onto it if you want portparse's body descent *plus* a custom
  Tcl-control rule of your own.

## Consumer notes

Inherited from tclparse — see its README's *Consumer notes* section
for detail. In brief:

- **Opaque ≠ malformed.** A braced word with `text` populated and no
  `inner` is well-formed; it was simply not descended by the policy.
  Only `unknown` nodes indicate lexically broken input.
- **BOM column off-by-one.** `position_of` reports the char after a
  BOM as `{1 2}`. Editors that hide the BOM render it as column 1.
  Consumer producing user-facing error messages may choose to
  subtract 1 when the file starts with a BOM.
- **Strict UTF-8 on read and write.** tclparse reads with
  `-encoding utf-8 -profile strict`. A consumer writing `emit` output
  back to disk should configure its output channel the same way.

## Worked examples

Every example deliberately uses both namespaces. If all your lines
start with `portparse::`, that's a signal the semantic surface has
drifted.

### Find every `replaced_by` in a Portfile

```tcl
package require portparse 1.0
set cst [portparse::parse [read [open Portfile r]]]
foreach n [tclparse::find $cst -name replaced_by] {
    set pos [tclparse::position_of $cst [dict get $n id]]
    set words [tclparse::words_of $n]
    puts "$pos: [dict get [lindex $words 1] text]"
}
```

### Flag misspelled directives

```tcl
set cst [portparse::parse $text]
tclparse::walk $cst flag_unknown
proc flag_unknown {n} {
    if {[dict get $n kind] ne "command"} return
    if {[dict get [portparse::classify $n] kind] eq "unknown"} {
        puts "unknown directive: [tclparse::command_of $n]"
    }
}
```

### Collect every `depends_lib` including inside `variant`/`if`

```tcl
set cst [portparse::parse $text]
foreach n [tclparse::find $cst -name depends_lib] {
    # tclparse::find crosses every inner CST; this picks up
    # depends_lib nested inside variant bodies and if arms.
}
foreach n [tclparse::find $cst -name depends_lib-append] {
    # -append resolves to the same base classification.
}
```

### Detect directives nested inside unexpected control-flow

```tcl
proc report {n anc} {
    if {[dict get $n kind] ne "command"} return
    if {[tclparse::command_of $n] ne "checksums"} return
    set chain [list]
    foreach a $anc { lappend chain [tclparse::command_of $a] }
    if {"if" in $chain || "foreach" in $chain} {
        puts "checksums inside [lindex $chain end]: suspicious"
    }
}
tclparse::walk_with_path $cst report
```

## Classification coverage and drift test

`classify_drift.test` scans `src/port1.0/*.tcl` with tclparse,
extracts every directive name registered via `options`,
`options_export`, `option_proc`, and `commands` (with its nine-suffix
fan-out: `use_NAME`, `NAME.dir`, `NAME.pre_args`, `NAME.args`,
`NAME.post_args`, `NAME.env`, `NAME.nice`, `NAME.type`, `NAME.cmd`),
and asserts every extracted name is present in
`portparse::directives` OR `portparse::body_policy`. Failure produces
a precise message naming the file/line where the registration lives.

### Adding a directive

1. Add a `dict set portparse::_directives NAME {sets {NAME} category
   <cat>}` line to [`directives.tcl`](directives.tcl), in sorted
   order, with a trailing `;# source.tcl` comment naming the base
   .tcl file the registration lives in.
2. If the new directive has a Tcl-code body (like `variant`, a phase
   override, or a hook), add a `dict set p NAME {positions last}`
   line to [`body_policy.tcl`](body_policy.tcl).
3. Re-run the drift test.

### Known gap: dynamic families

The drift test keys off **string-literal** registrations. If a
port1.0 file constructs directive names dynamically
(variable-bearing, `{*}$list` expansion), the test surfaces the call
site as a warning (not a failure). A new **call site** with a
composite name argument produces a new warning that requires a
one-line directives.tcl update. But **new members added to an
already-known dynamic family** (same call site, new list contents)
are *not* surfaced — the warning keys off call sites, not list
contents. The authoritative pointer for known dynamic families is
the comment block at the top of
[`directives.tcl`](directives.tcl); keeping the table synced with
the *contents* of listed dynamic families is a manual responsibility
when touching those source locations.

## What portparse does not do

- **No CST mutation API.** The schema supports one; defer until a
  concrete consumer lands.
- **No serialize/deserialize.** `tclparse::emit` is the v1 lossless
  contract.
- **No PortGroup static analysis** beyond what tclparse lexes
  syntactically. A future analyser layers alongside, never forces
  changes into this package.
- **No pass-through re-exports of tclparse.** Intentional — see
  *The two-namespace idiom*.

## Versioning

v1 has no public `api_version` integer; with no cache, wire format,
or interchange story it would be ceremony without a consumer.
Additive changes land silently; breaking changes ship under a new
`package provide portparse 1.x`.

## File layout

```
src/portparse1.0/
  portparse.tcl       package entry, sources siblings, defines parse
  directives.tcl      classification table (pure data)
  classify.tcl        query procs over the table
  body_policy.tcl     body-descent policy
  README.md
  NOTES.md
  tests/
```

Depends on `tclparse 1.0` at a sibling path under `src/`. The
dependency is strictly one-way.

## Tcl compatibility

Tcl 9 only (macports-base master vendors `tcl9.0.3`). No 8.x shims.

## Running tests

```
make -C src/portparse1.0 test
```

Runs every `*.test` file under `src/portparse1.0/tests/` via the
vendored `tclsh`. `classify_drift.test` additionally scans
`src/port1.0/*.tcl` to keep the classification table honest.

The harness loads the package via `package require portparse 1.0` —
the same way any consumer would. `make test` reaches the in-tree
packages by setting `TCLLIBPATH` in
[`tests/test-tclsh`](../../tests/test-tclsh), which includes both
`tclparse1.0` and `portparse1.0`. To run a single `.test` file
directly without `make`, set `TCLLIBPATH` yourself so both packages
are reachable:

```
TCLLIBPATH="$(pwd)/src/tclparse1.0 $(pwd)/src/portparse1.0" \
    vendor/tcl/unix/tclsh src/portparse1.0/tests/classify.test
```

## See also

- [`src/tclparse1.0/README.md`](../tclparse1.0/README.md) — the
  syntactic layer this package depends on.
- [Trac #73863](https://trac.macports.org/ticket/73863) — the
  originating motivation.
