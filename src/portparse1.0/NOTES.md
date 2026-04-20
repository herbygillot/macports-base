# portparse — maintainer notes

*Context for maintainers. Read this before making non-trivial
changes.*

## The layer boundary is load-bearing

`portparse` is intentionally narrow. Any future addition at
`portparse::` that duplicates a tclparse operation ties the
namespaces back together and erases the value of the split. Before
adding a public proc here, answer: **"Does this require
MacPorts-specific knowledge?"** If no, it lives in `tclparse`.

## Design principles

- **One-way dependency on tclparse.** tclparse has zero knowledge of
  portparse. Portparse composes onto tclparse, never the other way
  around.
- **Two registries, not one.** `directives` and `body_policy` answer
  different questions and change independently. Not every
  descent-worthy command is a classifiable MacPorts directive
  (`foreach` has a body but isn't a Portfile concept); not every
  classifiable directive has a body (`version`, `depends_lib`).
- **`classify` is the single semantic query** with a `kind`
  discriminator (`port-directive` / `tcl-control` / `unknown`).
  Callers need the enum to distinguish MacPorts directives from Tcl
  control-flow from unrecognised.
- **One semantic entry point (`parse`), no pass-through layer.**
  Every CST operation is called at `tclparse::` directly.
- **Public data is exposed as accessor procs**, not public
  variables. Fresh copies each call — no in-process mutation risk.
  Matches tclparse's style.

## Cross-namespace usage idiom

`portparse::parse` for entry, `tclparse::*` for every CST
operation, `portparse::*` for every semantic query. Every worked
example in the README — and the integration test — deliberately
uses both namespaces.

If a maintainer spots a usage pattern drifting toward "everything
from portparse," treat it as a signal that the idiom is unclear in
the docs, **not** as a reason to widen the portparse surface.

## Design decisions — considered and rejected

- **Merging `directives` and `body_policy` into one table.**
  Rejected: different jobs. Merging forces every classifiable
  directive to declare a body policy (or an explicit "none")
  every time — noise for the 90% that have no body.
- **Auto-generating `classify.tcl` from port1.0 at build time.**
  Deferred: the drift test is enough for v1. The data-vs-query
  split (pure-data `directives.tcl`, queries in `classify.tcl`)
  makes this a straightforward future refactor: regenerate the
  data file, leave queries untouched.
- **Shipping Tcl control-flow body knowledge in portparse rather
  than tclparse.** Rejected: control-flow is Tcl semantics, not
  Portfile semantics. It belongs one layer down.
- **Making `portparse::parse` diverge from `tclparse::parse +
  descend`.** Rejected: simplicity. If you need different descent,
  call `tclparse::descend` directly with your own policy.
- **`classify` returning `resolve`'s old shape (no `kind`
  discriminator).** Rejected: the kind enum is what makes the
  proc useful at a call site.
- **Re-exporting the bulk of tclparse's proc surface at
  `portparse::`.** Rejected: ties the namespaces together, makes
  every tclparse tweak a portparse compat concern, hides the
  layer boundary. Only `portparse::parse` is re-exposed, and only
  because it's a *semantic* entry point, not a structural
  pass-through.
- **Mirroring tclparse's accessor data (`default_policy`,
  `node_kinds`, `word_kinds`) at `portparse::`.** Rejected: one
  source of truth. Point consumers at `tclparse::` instead.
- **`portparse::api_version`.** Rejected for v1: no cache,
  serialize, or interchange consumer. Breaking changes ship under
  a new `package provide portparse 1.x`.
- **First-class entries for `-append` / `-prepend` / `-delete` /
  `-strsed` / `-replace` suffix variants in the classification
  table.** Rejected: 6× table size for no new information.
  `resolve` strips the known suffix and returns the base
  directive's entry. The `sets` list still correctly names the
  base field. Suffix-stripping is *gated*: only `options`- and
  `commands`-backed bases resolve through it. Phase-category
  entries (target bodies, pre-/post- hooks, variant/subport/
  platform) and explicit non-option procs (PortSystem, PortGroup)
  are excluded, because portutil.tcl does not generate the aliases
  for those at runtime. A spurious `pre-configure-append` therefore
  correctly classifies as `unknown`.

## Extending

### Adding a directive

1. New entry in [`directives.tcl`](directives.tcl): one-line
   `dict set portparse::_directives NAME {sets {NAME} category
   <cat>}  ;# source.tcl`, sorted-order, trailing comment naming
   the source file.
2. Optional: if the directive has a Tcl-code body, add a line to
   [`body_policy.tcl`](body_policy.tcl). The drift test will tell
   you if you're missing coverage.
3. Query procs in [`classify.tcl`](classify.tcl) are almost never
   touched — they read the table generically.

### Boundary check when extending

A new entry goes in `directives.tcl` if it names a Portfile
directive, or in `body_policy.tcl` if it declares where to
descend. **Generic Tcl control-flow additions belong in
`tclparse::policy.tcl`, not here** — portparse composes onto
`tclparse::default_policy`, it does not override it.

### Adding a new public proc at `portparse::`

Justify it with MacPorts-specific semantics. If the proc would
accept a CST and return structural data without consulting the
classification table or body policy, it belongs at `tclparse::`
instead.

## Drift test

### How it works

`classify_drift.test` scans `src/port1.0/*.tcl` with
`tclparse::parse`, then runs `tclparse::descend` with the default
policy so registrations inside `foreach`/`if`/`switch` bodies are
visible, and walks each CST matching commands by first word
against five registration forms:

- `options NAME...` — all literal names are directives.
- `options_export NAME...` — same.
- `option_proc NAME PROC` — **first arg only** is the directive;
  the second is a callback proc name.
- `commands NAME...` — each literal name fans out to nine
  suffixed directives: `use_NAME`, `NAME.dir`, `NAME.pre_args`,
  `NAME.args`, `NAME.post_args`, `NAME.env`, `NAME.nice`,
  `NAME.type`, `NAME.cmd`.
- `target_provides DITEM NAME1 NAME2 ...` — first arg (ditem) is
  skipped. Each literal target name fans out to three directives:
  `NAME` (target-override body), `pre-NAME`, and `post-NAME`.

Extracted literal names must appear in `portparse::directives` OR
`portparse::body_policy`. If any are missing, the test emits a
precise "add an entry to directives.tcl" failure.

The nine-suffix list is maintained in one place in the test file.
If `commands` grows a new suffix in [portutil.tcl:320](../port1.0/portutil.tcl),
update the test's `DRIFT_COMMANDS_SUFFIXES` alongside the
directive additions.

### Adding a new option-registration form

If a future portutil.tcl commit registers directives via a new
form (say `options_deprecated NAME`), extend the drift-test
scanner with a matching `DRIFT_*_FORMS` entry. Keep the scanner
minimally clever: lexical matching, no evaluation.

## Drift test is partial by design

The test enforces coverage for **string-literal** registrations.
Dynamic constructions fall into three buckets:

1. **New call site, composite name argument** → produces a new
   warning in the `classify_drift_warnings` block. Informational,
   does not fail CI, but surfaces the file/line for a maintainer
   to reconcile.
2. **New member of an already-known dynamic family** (same call
   site, different list contents) → **NOT surfaced by the test.**
   The warning keys off call sites, not list contents. Mitigated
   by the dynamic-families comment block at the top of
   [`directives.tcl`](directives.tcl), which enumerates each
   known dynamic family with the source file + line of both the
   registration call and the list/loop that supplies names. When
   a maintainer edits one of those listed source locations,
   reconciling `directives.tcl` is their responsibility; CI
   cannot catch this gap.
3. **Literal-name registration missing from the table** → hard
   failure.

The known dynamic families today (per the
[`directives.tcl`](directives.tcl) header):

- `portextract::all_use_options` → `use_7z`, `use_bzip2`,
  `use_dmg`, `use_lzip`, `use_lzma`, `use_tar`, `use_xz`,
  `use_zip`, registered via `{*}$list` expansion at
  [portextract.tcl:51](../port1.0/portextract.tcl:51).
- `_portconfigure_tool` foreach → `configure.cc_archflags`,
  `configure.objc_archflags`, `configure.cxx_archflags`,
  `configure.objcxx_archflags`, `configure.f77_archflags`,
  `configure.f90_archflags`, `configure.fc_archflags`,
  `configure.ld_archflags`, registered inside a `foreach` at
  [portconfigure.tcl:310](../port1.0/portconfigure.tcl:310).

## Glossary

- **Directive** — a Portfile-level command recognised by
  portparse (registered in port1.0 via `options` /
  `options_export` / `option_proc` / `commands`, or hand-added
  for the non-`options` forms like `PortSystem`, `variant`,
  `subport`, phase-override names).
- **Body policy** — the descent dict used by
  `portparse::parse`. Maps command name → policy entry form
  (declarative `{positions <list>}` or callback
  `{handler <proc>}`). Inherited from
  `[tclparse::default_policy]` plus MacPorts additions.
- **Drift test** — `classify_drift.test`. Scans port1.0 sources
  for registration calls and asserts coverage in the portparse
  table.
- **Semantic entry point** — `portparse::parse`. The only
  `portparse::` proc that takes raw text; everything else takes
  a CST or a name.
- **Accessor proc** — a proc named after a piece of data that
  returns a fresh copy (`[portparse::directives]`,
  `[portparse::body_policy]`). Never a public variable.
- **Two-namespace idiom** — `portparse::` for entry and
  semantic queries, `tclparse::` for every structural
  operation.
- **Layer boundary** — the wall that separates
  Tcl-language knowledge (tclparse) from MacPorts-specific
  knowledge (portparse). Preserved by refusing to re-export
  tclparse's structural API at `portparse::`.
