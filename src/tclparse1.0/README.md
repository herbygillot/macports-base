# tclparse

*A lossless Tcl CST — parse without evaluating.*

`tclparse` turns Tcl source text into a concrete syntax tree (CST) that
preserves every byte of the input. It is not a Tcl interpreter: it does
not substitute variables, run command substitutions, or evaluate
anything. It only recognises where commands and words begin and end.

The package is pure Tcl. It ships with MacPorts base, is loaded by
`portparse`, and is suitable for any tool that needs to read Portfiles
or other Tcl scripts structurally — linters, formatters, bulk-edit
tooling, future PortGroup analysers.

## Getting started

```tcl
package require tclparse 1.0

set text "foreach x {1 2 3} { puts \$x }"
set cst  [tclparse::parse $text]
set cst  [tclparse::descend $cst [tclparse::default_policy]]
puts [expr {[tclparse::emit $cst] eq $text}]   ;# 1
```

## Guarantees

- **Byte-identical round-trip.** `emit(parse(x)) == x` for every input.
  `emit(descend(parse(x), policy)) == emit(parse(x))` for every policy.
- **`emit` never normalizes.** No whitespace collapsing, no quote
  style conversion, no comment rewriting.
- **Globally unique node IDs.** Every node in the tree (top-level,
  command bodies, descended `inner` CSTs at every depth) carries an id
  that is unique across the tree. Existing IDs never change across
  `descend`; new nodes introduced by descent get fresh IDs.
- **Content is authoritative.** Words carry exactly one of `text` or
  `inner`. No denormalized fields, no `raw` offsets, no `leading`
  slots.
- **Shape uniformity across depths.** Every CST — top-level or inner —
  has the same shape (`{nodes <list>}`). Every public proc accepts any
  CST directly; inner CSTs are first-class.

## Data model

A CST is a dict: `{nodes <list>}`. The top-level `nodes` list is in
source order. Leaf nodes (`word`, `comment`, `whitespace`,
`terminator`, `unknown`) account for every character of input exactly
once; `command` is a structural wrapper over a body list, not a source
token.

Common fields on every node: `id` (integer), `kind`, `line`, `col`.
`line`/`col` are 1-indexed character coordinates relative to the CST
the node belongs to.

| kind         | extra fields                                          |
|--------------|-------------------------------------------------------|
| `command`    | `body` — flat list of `word`/`whitespace`/`unknown`   |
| `word`       | `word_kind` (`bare`/`braced`/`quoted`/`composite`); exactly one of `text` or `inner` |
| `comment`    | `text` — `#`-prefixed content, no trailing newline    |
| `whitespace` | `text` — spaces, tabs, newlines, `\<nl>` continuations|
| `terminator` | (no extra fields; represents `;`)                     |
| `unknown`    | `text` — characters that could not be classified      |

Positional rules: `command`, `comment`, `terminator` appear at CST top
level only (including top level of inner CSTs). `word` appears only
inside a command's body. `whitespace` and `unknown` may appear in
either position.

### Descent

`tclparse::descend <cst> <policy>` walks the CST and, for each command
whose name appears in `policy`, rewrites declared braced-word arguments
so their brace interior becomes a nested CST stored on the word as
`inner`. The word's `text` is removed — `inner` is authoritative.

An un-descended braced word is still well-formed: it has `text` and no
`inner`. **Opaque ≠ malformed.** Consumers should treat un-descended
braced words as first-class data, not as errors. The `unknown` node
kind is reserved strictly for lexically broken spans (unbalanced braces
or quotes).

## Public API

Parse, descend, emit:

- `tclparse::parse <text>` → cst.
- `tclparse::descend <cst> <policy>` → cst. Recursive; preserves prior
  inners. Immutable over input.
- `tclparse::emit <cst>` → text. Byte-identical reconstruction.

Walk / find:

- `tclparse::walk <cst> <visitor>` — visitor: `proc visitor {node}`.
  Recurses into command bodies and inner CSTs. Visits a descended
  braced word *both* as the `word` node and as each command inside its
  `inner`; branch on `kind` in your visitor to skip one.
- `tclparse::walk_with_path <cst> <visitor>` — visitor:
  `proc visitor {node ancestors}`, where `ancestors` is the outer-to-inner
  list of enclosing `command` nodes.
- `tclparse::find <cst> -name <name>` — every command with that first
  word, at every depth.
- `tclparse::command_of <node>` → first-word text, or empty.

Per-node helpers (narrow filters):

- `tclparse::structural <cst>` — top-level nodes minus `whitespace`.
  Comments and terminators are kept; only whitespace is filtered.
- `tclparse::words_of <command-node>` — `word`-kind nodes only.
  Throws `{TCLPARSE NOT_COMMAND}` on non-command input.
- `tclparse::blank_line_count <ws-node>` → `max(0, N-1)` where N is
  the newline count in the whitespace's text. Throws
  `{TCLPARSE NOT_WHITESPACE}` on the wrong kind.

Positions:

- `tclparse::position_of <cst> <id>` → `{line col}` relative to `<cst>`'s
  text. Throws `{TCLPARSE NOT_FOUND}` if the id is unreachable.
  O(n) per call.
- `tclparse::positions_of <cst>` → dict `id → {line col}` for every
  reachable id. One walk; amortises `position_of` cost.

Accessor procs for static data (return a fresh copy on every call, so
`dict merge` and `lappend` are safe):

- `tclparse::default_policy` — descent policy for Tcl control-flow.
- `tclparse::node_kinds` → `{command comment terminator whitespace unknown word}`.
- `tclparse::word_kinds` → `{bare braced quoted composite}`.

## Default policy

`[tclparse::default_policy]` covers Tcl control-flow:

| command   | entry                                   |
|-----------|-----------------------------------------|
| `foreach` | `{positions last}`                      |
| `while`   | `{positions 2}`                         |
| `for`     | `{positions {1 3 4}}` (init/incr/body; arg 2 is cond, not script) |
| `if`      | `{handler tclparse::cst::if_bodies}`    |
| `switch`  | `{handler tclparse::cst::switch_bodies}` |

`switch_bodies` descends the **individual pattern/body args** form only
(`switch $x a { ... } b { ... }`). The **list form**
(`switch $x { a {...} b {...} }`) leaves the single braced arg opaque
— see NOTES.md for rationale.

Policy entry shapes:

```
{positions <list>}   values are 1-based arg indices (positive integers)
                     or the literal "last". Arg 1 is the word after the
                     command name.
{handler <proc>}     called as `$handler <command-node> <policy>`;
                     returns a list of {arg-index inner-cst} pairs. The
                     handler parses and recursively descends each inner
                     itself — typically via `tclparse::parse` followed
                     by `tclparse::descend <cst> <policy>`, threading
                     the policy argument through so a richer composed
                     policy reaches nested commands.
```

### Shape mismatch silently skips

This rule applies to the **descent pass only**.

If a policy says “argument N is a script body” but that argument is
missing, or present but not a braced word, `tclparse::descend` does not
throw. It simply leaves that word opaque — no `inner`, no rewrite.

Examples:

- too few args: `foreach x {1 2 3}`
- non-braced body: `if {$x} body`

This keeps descent robust over incomplete or non-canonical input.

This does **not** mean broken Tcl is invisible. Lexically broken input
(such as unbalanced braces or quotes) is still represented with
`unknown` nodes during `parse`. A missing `inner` only means “this word
was not descended,” not “this command is valid.”

### Composing a custom policy

```tcl
set mine [dict merge [tclparse::default_policy] {
    mycmd  {positions last}
    yours  {handler my::handler}
}]
set cst [tclparse::descend [tclparse::parse $text] $mine]
```

Because `default_policy` is an accessor proc, you can merge onto it
freely — the shipped policy is not mutated.

## Consumer notes

- **Opaque ≠ malformed.** A braced word with `text` and no `inner` is
  well-formed; it was simply not reached by the policy you passed.
  Only `unknown` indicates broken input.
- **BOM column off-by-one.** When a file starts with a UTF-8 BOM,
  `position_of` reports the character after the BOM as `{1 2}`. Editors
  that hide the BOM render that character as column 1. Consumers that
  produce user-facing error messages may subtract 1 from the column when
  the source begins with a BOM.
- **Strict UTF-8 on read and write.** tclparse reads with
  `-encoding utf-8 -profile strict`. Consumers writing `emit` output
  back to disk should configure their output channel the same way —
  encoding corruption should surface at the write, not silently.

## What tclparse does not do (v1)

- It is not a Tcl interpreter. No `$var` substitution, no `[...]`
  evaluation.
- No `switch` list-form descent. Deferred until a consumer needs it.
- No `serialize`/`deserialize`. `emit` is the lossless contract.
- No CST mutation API. The schema supports one (stable IDs, immutable
  returns); it arrives with its first concrete consumer.
- No public id allocator. IDs are globally unique, but `parse` has no
  `-start-id` and the CST has no `next_id`.

## Versioning

v1 has no public schema-version integer. Breaking CST-shape changes
ship under a new `package provide tclparse 1.x`; consumers use
`package require tclparse 1`. Additive changes land silently.

## File layout

```
tclparse.tcl    package entry; sources siblings
lex.tcl         tokenizer (internal tclparse::lex::)
cst.tcl         CST construction; node_kinds / word_kinds accessors
descend.tcl     descent mechanism (language-neutral)
policy.tcl      default Tcl control-flow policy + if/switch handlers
traversal.tcl   emit / walk / find / positions / words_of / ...
tests/          per-concern .test files + fixture corpus
```

## Running tests

```
make -C src/tclparse1.0 test
```

The harness loads the package via `package require tclparse 1.0` — the
same way any consumer would. `make test` reaches the in-tree package by
setting `TCLLIBPATH` in [`tests/test-tclsh`](../../tests/test-tclsh).
To run a single `.test` file directly without `make`, set
`TCLLIBPATH` yourself:

```
TCLLIBPATH="$(pwd)/src/tclparse1.0" \
    vendor/tcl/unix/tclsh src/tclparse1.0/tests/lex.test
```

Requires Tcl 9. All fixtures round-trip byte-identically and all public
procs have declared shape and return form pinned by tests.

## See also

- [`portparse1.0`](../portparse1.0/README.md) — Portfile semantic layer
  on top of tclparse.
- [Tcl Dodekalogue](https://www.tcl.tk/man/tcl/TclCmd/Tcl.htm) — the
  12-rule spec the lexer is keyed to.
- [NOTES.md](NOTES.md) — maintainer context and design-decision log.
