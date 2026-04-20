# tclparse — maintainer notes

Context for maintainers. Read this before making non-trivial changes.
The consumer-facing contract lives in [README.md](README.md); this file
captures the invariants, rejected designs, and gotchas behind the
contract.

## Design principles (invariants)

- **CST, not AST.** Every lexical token maps to exactly one node.
  Trivia (whitespace, comments) are sibling nodes, never slots on other
  nodes.
- **No editorializing at parse time.** The lexer does not normalize
  quoting or whitespace. `emit` never mutates.
- **Content is authoritative.** A word carries exactly one of `text`
  or `inner`. No `raw` offsets, no `leading` slots, no `tail_trivia`.
- **Global ID uniqueness.** Every node across the entire tree
  (top-level + every inner at every depth) has a unique id. Existing
  IDs never change across `descend`; new inner nodes get fresh IDs from
  an internal allocator. No public allocator surface — `parse` takes no
  `-start-id`, CSTs carry no `next_id`.
- **Shape uniformity across depths.** `parse` always returns `{nodes <list>}`;
  inner CSTs are structurally identical. Every public proc accepts any
  CST directly.
- **Parse and descend are separate passes.** This is a hard boundary.
  A refactor merging them into a single policy-driven parse is rejected
  by this invariant — see rejected designs below.
- **Public data is accessor procs, not variables.** `default_policy`,
  `node_kinds`, `word_kinds` return fresh copies every call.
  Tcl has no first-class read-only variables; don't rely on convention.

## Design decisions — considered and rejected

- **Slots for leading whitespace / trailing trivia on commands.**
  Rejected: a CST, not an AST. Trivia are sibling nodes.
- **`raw` offset spans on every node.** Rejected: compute via
  `position_of` / `positions_of`.
- **`name` / `class` caches on command nodes.** Rejected: derive via
  `command_of` or (for Portfiles) `portparse::classify`.
- **Separate `blank` node kind vs `whitespace`.** Rejected: no
  behavioural difference at the lex level; consumers derive via
  `blank_line_count`.
- **Body knowledge in the lexer or parser.** Rejected: lives in descent
  + policy. The lexer has zero command awareness.
- **Parse-takes-policy-callback (single-pass).** Rejected: two
  explicit passes is conceptually cleaner, easier to test, and lets a
  consumer compose partial descent.
- **`serialize` / `deserialize` in v1.** Rejected: no current consumer.
  `emit` is the lossless contract. `cst_version` is deferred with it —
  an in-memory version integer without a cross-process contract is
  ceremony without a consumer.
- **Public allocator surface (`-start-id`, `next_id`).** Rejected in
  v1: mutation is not in scope, so the allocator stays internal.
  Global uniqueness is still guaranteed. When a mutation or
  serialization API lands, the allocator becomes public at that time.
- **Descending `switch` list form.** Rejected in v1: would require a
  schema flag distinguishing script-inner from list-of-pattern-body
  inner, or would produce phantom commands whose head word is a
  pattern — polluting generic operations for non-switch-aware
  consumers. Consumer who needs switch-list bodies today parses the
  opaque `text` themselves.
- **Public variables for `default_policy` / enums.** Rejected:
  in-process mutation risk. Accessor procs return fresh copies.

## Lexing gotchas

- `#` starts a comment only when it is the first non-whitespace token
  of a command. Inside bare/quoted/braced words, `#` is literal.
- `# ... \<nl>` at command start continues the comment onto the next
  physical line. The comment token includes the backslash-newline and
  the continuation line's text; the terminating newline is still
  tokenized separately as following whitespace.
- A `#` is only recognised as a comment when it sits at command start
  (beginning of input, just after `\n`, or just after `;`). A `#` later
  in the command — `puts a # trailing` — is tokenised as bare-word
  text, *not* as a comment. A true end-of-line comment only appears
  when the preceding command is actually terminated, e.g.
  `puts a ;# trailing` (the `;` resets `at_cmd_start`), in which case
  the comment is a separate top-level sibling, not a slot on the
  command.
- `\<nl>` is a line continuation: the command does not terminate; the
  backslash-newline is part of the surrounding whitespace run. The
  pair is consumed as one continuation newline — the line counter
  advances once, the column resets to 1.
- A stray `\r` is a column char, not a line break. Columns advance;
  lines do not.
- BOM (U+FEFF) at file position 0 is its own `unknown` node at
  line 1 col 1 width 1. The character immediately after it is at
  line 1 col 2. BOM elsewhere in the file is a literal bare-word char.
  **Known off-by-one vs editor display** when the editor hides the BOM
  — documented in README for consumers.
- Braced words `{...}` track nesting. The only things that suppress
  nest-counting are backslash-escaped braces (`\{`, `\}`) and the
  `\<nl>` continuation — `"..."` is *not* recognised inside a braced
  word, so a `{` sitting inside a string literal inside braces still
  increments depth. This matches Tcl's own brace-counter in
  [Dodekalogue §6](https://www.tcl.tk/man/tcl/TclCmd/Tcl.htm).
- Recovery / `unknown` nodes have three sources, not just one:
  - Unbalanced `{...}` or `"..."` — `_recover_unknown` emits a span
    from the point of unbalance to the next blank-line separator
    (`\n\s*\n`) or EOF.
  - Unbalanced `[...]` inside a bare word — same recovery path.
  - An uncategorisable first char in a bare-word position (e.g. a
    stray `}` at command start) — `_scan_bare` emits a one-char
    `unknown` and continues.
  Character-exact round-trip is preserved through every path — no
  input is ever dropped.
- All columns are character columns, not byte columns.

## Descent gotchas

- **Shape mismatch silently no-ops.** A declared position that is
  missing or not a braced word produces no `inner`, no error. This
  extends to handler output: a handler pair whose target word is not a
  braced word is silently skipped.
- **Empty braced body `{}`** descends to an `inner` with an empty
  `nodes` list; `emit` reproduces `{}`.
- **`if` and `switch` handlers are hand-written** for their variable
  arity. `if_bodies` handles optional `then`, arbitrary `elseif`
  chains, and optional `else`. `switch_bodies` skips leading options
  (single `-*` args and `--`), identifies the value arg, then descends
  body positions of the individual-args form only. Options that
  consume a following operand (`-matchvar`, `-indexvar`) are listed
  explicitly in the handler; a future Tcl release adding a new
  operand-taking switch option requires updating that list alongside
  a descend.test case.
- **`switch` list form is intentionally not descended.** The single
  braced arg stays opaque. See rejected designs above.
- **Re-descent preserves prior work.** Walking a CST that already has
  `inner`s under a richer policy keeps the existing inners intact; the
  mechanism descends deeper under the new policy.

## Walk gotchas

`walk` intentionally double-visits when traversing descended braced
words: once as the `word` node (so visitors that care about word-level
context see it) and again as each `command` inside its `inner` (so
visitors that want to see every command at every depth also see them).
Visitors branch on `kind` if they want to skip one.

`walk_with_path` preserves the same double-visit. The ancestor chain
is the enclosing-`command` chain; it does not include the word nodes
themselves — so a visitor can ask "am I inside a `variant` body?"
without caring about the word-vs-command granularity.

## Internal ID allocator

Two acceptable shapes both satisfy the public contract:

1. Thread an internal counter through `descend` into each nested `parse`
   call.
2. Parse each inner with a fresh counter starting at 1, then renumber
   the returned subtree to continue the outer's id-space before
   splicing.

v1 uses shape 2 (parse-then-renumber). Tests pin only the observable
contract (global uniqueness, existing IDs preserved across `descend`),
not the allocator shape. A future refactor between the two is free.

Do not re-expose the allocator publicly without a concrete consumer
pinning its shape.

## Helper-filter semantics are narrow

- `structural` drops `whitespace` only. `comment` and `terminator` are
  kept.
- `words_of` returns `word` kind only. Drops both `whitespace` and
  `unknown`.
- `blank_line_count` treats a run with N newlines as `max(0, N-1)`
  blank lines.

A future refactor must not broaden these silently. If consumers want
different filters, add new procs — don't reinterpret existing ones.

## Extending

- **Add a tokenizer rule.** Edit `lex.tcl`, add a `lex.test` case.
- **Add a default policy entry.** Edit `policy.tcl`, add a
  `descend.test` case. The mechanism in `descend.tcl` is
  language-neutral and almost never needs to change when adding policy
  entries.
- **Add a new concern file.** Add its source line to `tclparse.tcl`
  once, ship it as a stub, then grow it. `package require tclparse`
  stays green throughout.
- **Change the CST schema.** Additive optional field: no version bump
  (no public version exists in v1). Removal / rename / type-change /
  required-field / kind-semantic-change: ship under a new
  `package provide tclparse 1.x` and document in the CHANGELOG.

## Tcl 9 footguns

- `expr` always braced: `expr {$a + 1}`.
- `variable <name>` declared in every proc that touches a
  namespace-scoped variable (`registry2.0: Fix variable with Tcl 9` and
  `d3013e0a1` tightened exactly this).
- `{*}$list` for expansion; `eval` avoided entirely.
- No `interp alias {} ...` across namespaces for public-API exposure;
  pass-through procs with real implementations (Tcl 9's stricter
  resolution breaks some alias contexts).
- Structured errors: `throw {TCLPARSE <KIND>} $msg`. Error codes are
  2-element lists so callers can dispatch on `$errorCode`.
- Dict access via `dict` commands. `dict getwithdefault` preferred
  over `[info exists] && ...` patterns.
- Channel encoding explicit: `chan configure $f -encoding utf-8 -profile strict`
  on both read and write paths.

## Relationship to other packages

- No dependency on `macports1.0`. tclparse is pure string code.
- Consumed by `portparse` (the Portfile semantic layer).
- Future consumers layer alongside portparse, never force changes back
  into tclparse.

## Forward-compatibility flex points

Safe to add:

- Additive optional fields on node / word dicts.
- Additional default-policy entries.
- New public procs in `tclparse::`.
- New sub-namespaces for internal use.

**Not** flex points — these require a package-version bump:

- Adding values to node-kind or word-kind enums (consumers switch on
  them).
- Removing or renaming public procs.
- Changing the return shape of an existing public proc.

## Known future work

- `serialize` / `deserialize` + `cst_version` — add together when a
  cache consumer lands.
- CST mutation API — id-based, immutable returns; promotes the
  internal allocator to public surface.
- `switch` list-form descent — add a word-kind flag or a structured
  "switch_arms" payload when a real consumer needs it.
- Composite-word expansion — child CST under composite words, if a
  consumer needs to reason about `$var` / `[subcmd]` spans
  structurally.

## Glossary

- **CST** — concrete syntax tree. Every input character maps to exactly
  one node; reconstruction is byte-exact.
- **Trivia** — whitespace and comments. Sibling nodes in this schema,
  never slots.
- **Descent** — the act of re-parsing the interior of a braced word and
  attaching the result as `inner`.
- **Policy** — the dict passed to `descend` naming which commands'
  arguments to re-parse and how.
- **Inner** — the nested CST attached to a descended braced word. Full
  CST shape; accepted by every public proc.
- **Structural** — the top-level node list with whitespace removed.
  Not "commands only" — comments and terminators are kept.
- **Composite word** — a bare word that contains `$var`, `${name}`, or
  `[...]`. `word_kind composite`; still one word, not split.
- **Terminator** — a `;` between commands on the same line; its own
  node kind.
