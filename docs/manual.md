<!--
  hbrefactor — LIVING MANUAL (source of truth for the public presentation)

  baseline: hbrefactor@8893796 · harbour-core@a465e85bd1 (feature/compiler-ast-dump)
    — this round the CORE moved three schema steps (ast-14, ast-15, ast-16), and two of
      them changed what the tool can promise the user:
      * NEW SECTION "A directive can be switched off — and the rename follows it there"
        (ast-16, case 117). A `#undef` / `#xuncommand` ends a directive's life. Renaming
        the directive used to leave that switch-off behind, pointing at a name that no
        longer existed — so it turned off NOTHING and the directive LEAKED past the line
        where the programmer ended it, silently, with the compiled output byte-identical
        either way. The removal directive is now renamed along with the rule it ends.
      * NEW SECTION '"Would this new name collide?" — it asks the preprocessor instead of
        guessing' (phase P/P11). `#command` matches its keywords abbreviated, so a rename
        can hijack another rule. The tool used to REIMPLEMENT that matching rule and
        therefore refused safe renames; it now starts a live preprocessor and lets the
        real authority answer.
      CORRECTED, and worth stating plainly: this file claimed "1085 of 1085 modules
      byte-identical" as the zero-impact proof. That figure is NOT reproducible — it was
      measured by hand, once, with no script. Re-measured 2026-07-12 with
      tools/pcode-identity.sh: 889/889 identical, ZERO divergences. The claim holds; the
      count was fantasy. The body now points at the measurement, not at a number.
  suite at baseline: 116 cases, 961 checks green
  updated: 2026-07-12

  This file is the single, current-state, user-facing description of hbrefactor.
  The landing page (site/) is GENERATED FROM this content — iterate the words here,
  then rebuild the page. It is NOT a changelog (that is CHANGELOG.md, chronological);
  this is "what the tool is and does, right now."

  Maintenance: the /update-manual skill analyzes commits made after the baseline pair
  above, translates user-visible changes into edits to this file (propose → Diego
  approves → apply), and advances the baseline hashes. Keep section headings stable —
  the skill and the page build target them.

  Provenance discipline: every section carries a `prov:` comment naming its sources —
  suite case numbers (tests/run.sh), commits, live runs, or docs. Every claim must
  trace to tested behavior; do not add a claim the tool cannot back. When in doubt,
  say "I don't know" — that is the product's own rule.

  Anti-overclaim vaccine (behaviors REMOVED from the product verdict — never state as
  current): construction-chain typing (RE.3; cases 61/63/84 document the ABSENCE);
  as-written graph walk / descendant naming (RE.3; cases 66–69 pre-RE.6 form); ALL of
  B7/B7b interprocedural inference (cases 85/86 — it survives only as the future
  suggester); extension methodQuery regex (dead; cases 71/81). Parentage exclusion IS
  current, but only in its RE.6 form: declared facts, whole chain in project.

  Language: English (the public page is English). Audience: Harbour APPLICATION
  developers — many from the Clipper era, many who have never used a refactoring tool.
-->

# hbrefactor

**Verified refactoring for Harbour.** It reads your code the way the compiler does,
renames exactly what you *mean*, never guesses, and **proves** every edit before it
keeps it.

Available as a **command-line tool** and a **VSCode extension**.

---

## Start here — if you've never used a refactoring tool

*This part assumes you only know Find & Replace, maybe a regex. If you came up on
Clipper, you're exactly who this is for. No jargon.*

<!-- prov: framing; the pains are the ones the suite refuses/handles: cases 2,5,7,11 -->

### Have you ever done this?

You needed to rename a variable — say `nTotal` — so you opened **Find & Replace**
and hit *Replace All*. It worked… mostly. It also changed the word inside a **string**
your user sees on screen. And inside a **comment**. And it renamed a *different*
`nTotal` in another function that had nothing to do with yours. And it **missed** the
calls in the other file, because the code around them looked a little different. You
found out three weeks later — when the client called.

It's not your fault. **Find & Replace works on text.** It has no idea what a variable
is, what a function is, or what a comment is. Every run of characters that matches, it
changes — the right ones and the wrong ones, blindly. Regular expressions? Smarter
matching, still text. Still blind to what your code *means*.

### So what is refactoring?

<!-- prov: cases 1 (rename local verified), 10 (rename function round-trip),
     14 (reorder preserves behavior), 16 (extract preserves behavior) -->

Refactoring means changing the **shape** of your code without changing **what it
does**. Rename a variable, pull a block of lines into its own function, reorder a
function's parameters — before and after, the program behaves *exactly* the same.

A refactoring *tool* does those changes for you. The key word is **understands**:
hbrefactor doesn't see text — it sees variables, functions, calls, and scopes, the
same things the Harbour compiler sees when it builds your program.

So when you say "rename *this* `Total`," it knows which one you mean:

| The same six letters… | …with different meaning | hbrefactor |
|---|---|---|
| `Total` | a variable | **renamed** |
| `"Total: 42"` | a string | left alone |
| `// fix Total` | a comment | left alone |
| `Total()` | a function | left alone |

A text tool can't tell them apart. hbrefactor can — because it asks the compiler.

### How do I know it didn't break anything?

<!-- prov: cases 7 (stringify rollback), 10 ("pcode byte-identical"), 90 (provoked
     rollback, byte-for-byte restore proven by binary comparison) -->

Fair question — especially if you've been burned before. This is what sets hbrefactor
apart from every "trust me" tool: **it doesn't trust its own edit.**

After it changes your source, it **recompiles** your project and compares the result
against the original program. If anything is different — if the program the machine
would run is not identical — it **throws the edit away**, puts your files back exactly
as they were, and tells you why.

And when it *can't* be sure about something, it doesn't guess. It says **"I don't
know"** out loud, instead of quietly doing the wrong thing.

> **The Fact Rule:** when we can't prove it, we won't claim it.

### It's still 100% Harbour — we don't change the syntax

<!-- prov: design rule (roadmap NORTE); the words annotate writes are stock language
     (DECLARE/_HB_MEMBER/AS CLASS, zero pcode — case 89 "inerte sem -kt") -->

A worry worth naming out loud: *does this turn my code into some weird dialect?*

**No.** hbrefactor never invents new syntax and never adds a language of its own. Your
`.prg` stays plain Harbour — the same code the normal Harbour compiler builds, the
same code any Harbour programmer can read. It **reshapes** your code; it never replaces
your language. Even when it adds type information (below), it uses words Harbour has
understood forever.

**…and it doesn't change your build either. Not one byte.** For the tool to work on *facts*,
Harbour's compiler had to start handing them over — so we extended it. Which raises the fair
question: *what did you do to my compiler?* Nothing, unless you ask. The new information is
emitted only behind a switch; with that switch off — the state every existing project is in —
the patched compiler produces the **same bytes** as the one you use today. Measured, not
asserted — and you can re-run the measurement yourself: every `.prg` in the Harbour tree is
compiled by **both** compilers with the switches off and compared byte for byte, with **zero
divergences**. That work lives on a branch of Harbour itself and has
**its own page**, written for the Harbour maintainers:
**[extending the compiler without breaking anything](https://diegopego.github.io/harbour-core/)**
(source: `harbour-core/site/index.html`; user-facing log: `harbour-core/NEWS.md`).

---

## Spotlight: `annotate` — materialize the facts your code already implies

<!-- prov: cases 89 (report vs apply, gold standard), 90 (rollback), 91–100
     (topologies, block params, DSL generality); live-run 2026-07-10 on the Payment
     example: report "nível 2" ×2 → apply "1 declaração + 2 anotações; verificado:
     .hrb byte-idêntico sem -kt; compila limpo -w3 -es2; roda sob -kt" → usages
     upgraded possible→confirmed. Exact fixcls line asserted by case 91. -->

*The flagship. Not "the tool types your code" — it makes facts your code already
**implies** explicit, so the compiler can carry and check them.*

Most Harbour code never states what things *are*:

```harbour
LOCAL oMenu := UWMenu():New()
oMenu:AddItem( "Sair" )
```

You know `oMenu` is a `UWMenu`. The compiler doesn't — so any find-references or rename
over `AddItem` can't tell *which* class the call is on, and hbrefactor honestly labels
it `possible (receiver unknown)`. It will not guess.

But the type isn't really unknown — it's **implied**: a class's constructor returns that
class. `annotate` **materializes** that implied fact into a declaration Harbour has
understood forever:

```harbour
LOCAL oMenu AS CLASS UWMENU := UWMenu():New()
```

*(That exact line is what the test suite asserts `annotate --apply` produces — verified
behavior, not a mock-up.)*

### Why write it into my code at all?

Because a fact the *tool* worked out is not a fact the *compiler* carries. Writing the
declaration is what turns the implication into something checkable:

- the compiler now knows `oMenu` is a `UWMENU`, so `usages` and rename go from
  `possible` to `confirmed`;
- with `-kt` (below), that fact is **enforced** at runtime;
- the next programmer — and you in six months — can read it;
- it costs **zero pcode**: not one extra instruction in the compiled program.

An earlier version resolved this by *inferring* the type with nothing written. That was
removed on purpose: an inferred verdict is a guess wearing a fact's clothes, and this
tool doesn't ship guesses. So `annotate` isn't the tool typing your code — it's the tool
making a latent fact **explicit and enforceable**. It only writes what a declaration can
back; a type it could merely guess goes in the report, never into your source.

### What `annotate` verifies before it keeps a single line

With `--apply`, it works in order and checks at every step:

1. writes the missing declarations (`DECLARE`, `_HB_MEMBER`, `_HB_CLASS`);
2. **proves nothing changed in the program** — recompiles and requires the binary to
   be byte-identical to before (declarations are pure compile-time; one differing byte
   → automatic rollback);
3. proves the project still compiles clean under `-w3 -es2`;
4. recompiles with `-kt` and **runs** it — runtime checks confirm the annotations tell
   the truth;
5. only then annotates the variables (including code-block parameters), and
   re-verifies everything.

Any failure at any step: your sources return byte-for-byte to what they were, with the
reason named. The suite *provokes* this on purpose — a fixture where an old declaration
lies — and proves the sources come back byte-identical.

**Real result:** on Harbour's own `hbhttpd` (14 classes), `--apply` wrote **31
declarations + 7 annotations**, all verified, in about 3 seconds; the re-report drains
to zero — everything declarable was declared, and what remains is what only inference
could reach, which it does not write.

In VSCode: **Annotate report** (read-only) and **Annotate apply** (asks to confirm
before writing).

---

## Going deeper

### See it work — a method is more than its name

<!-- prov: live-run 2026-07-10 (Payment/Logger scratch project, rebuilt CLI at
     4dbe8c1): usages separation + parentage exclusion + reorder-params dry-run +
     ambiguity refusal, all outputs below verbatim (translated labels stay verbatim).
     Parentage exclusion: commit 6df5c50 (F6.2), case 104 (DSL generality),
     CHANGELOG 2026-07-10 "usages Classe:Método deixa de mostrar homônimos". -->

Say you decide `Payment:Send( fone, mail )` should take its two arguments in the other
order. By hand you'd hunt down every call and hope you found them all. Here:

```
hbrefactor reorder-params  billing.hbp  Payment:Send  cMail,cFone
```

rewrites **every call site — all instances of `Payment` — plus the declaration and the
definition**, then recompiles to prove nothing else moved. Two `Payment` objects,
`customerPayment` and `supplierPayment`? Both calls are fixed; you don't chase them.

Now the part search-and-replace can't do. Suppose a `Logger` class *also* has a `Send`
method — same name, unrelated. Ask for the usages of `Payment:Send`:

```
confirmed send (receiver declared AS CLASS PAYMENT)                     | oPay:Send( "fone", "mail" )
excluded send within the declared class graph (dispatches to LOGGER:SEND) | oLog:Send( "hello" )
method definition Send (class Payment)
excluded method definition (implements LOGGER:SEND)
```

The look-alike isn't just flagged — it's **excluded, with the proof named**: the
compiler now records **who inherits from whom** (a declared parentage channel), so the
tool resolves the dispatch by Harbour's own rule and *proves* `oLog:Send()` goes to
`LOGGER:SEND`, never to `Payment`. In VSCode, "find all references" simply doesn't list
it. And it never confuses inheritance with noise: if `Child` *inherits* `Send` from
`Payment` (without overriding), `oChild:Send()` **is** a reference of `Payment:Send`
and stays in the result.

And if you ask it to `reorder-params Payment:Send` while the name is shared across
classes, it **refuses** rather than risk mangling a look-alike:

> `'Payment:Send': the message belongs to more than one class (PAYMENT, LOGGER) — a send`
> `is dynamic dispatch; reordering the arguments would be ambiguous. Refused.`

That refusal *is* the product: it would rather stop and tell you than guess wrong. Find &
Replace on "Send" would have rewritten both classes without a word.

**What we're building toward (honest):** today the tool resolves each call's *class*. It
does **not** yet resolve which *instance* — `customerPayment` and `supplierPayment` both
count as `Payment:Send`. Narrowing "find usages" to the calls on a **single instance** is
a goal, not a current capability.

### It reaches inside your `INLINE` methods

<!-- prov: RD "rota da diretiva" (roadmap §RD, CHANGELOG 2026-07-11); case 105 (invented
     non-hbclass DSL fixself); completude M-B / RD-c (roadmap §RD-c, CHANGELOG 2026-07-11):
     case 106 (fixdel, hbclass VAR..IS/IN delegated properties, getter+setter on one line,
     ast-11 "params" on the block node); live-run 2026-07-10: usages on the Moeda class →
     "q1.prg:13: confirmed send (receiver declared AS CLASS MOEDA, codeblock) in MOEDA".
     Core channel _HB_INLINESELF, fact-only (never -kt-imposed); zero-impact proven
     byte-identical under -kt. Does NOT revive B7b inference (vaccine): it is
     a compiled FACT. -->

Harbour classes lean on `INLINE` — one-line methods, `OPERATOR` overloads,
`ACCESS`/`ASSIGN`:

```harbour
METHOD Total INLINE ::Soma( 0 ):nCents
```

That `::Soma()` is a real call to `Soma` on the same object — a reference you'd want
"find all references" to catch. But the receiver of an `INLINE` body is **generated by
the directive**: it has no token in your source to anchor on, so the tool used to shrug
it off as `possible (receiver unknown)`. Now the compiler records that receiver's class
as a **fact**, and the call comes back `confirmed`:

```
confirmed send (receiver declared AS CLASS MOEDA, codeblock)  | METHOD Total INLINE ::Soma( 0 ):nCents
```

And it costs your program nothing: that fact is **never** turned into a runtime check —
not even under `-kt` — because an `INLINE`'s receiver is always its own class anyway. So
the label is `confirmed`, never `guaranteed`, and a `-kt` build gains **zero** extra
instructions (proven byte-for-byte). As always, it isn't an hbclass trick — a DSL of
your own that generates a typed-receiver block gets exactly the same, with the tool's
source never naming your directive.

The same now holds for **delegated properties** — the Class(y) shorthand where one
`VAR` forwards to another field or object:

```harbour
VAR nEcho AS Numeric IS nRaw          // reading nEcho reads nRaw
VAR nVia  AS Numeric IS nCount TO oPart
```

Each of these generates a hidden read *and* write block on the same source line, and
`find all references` for `nRaw` (or `oPart`) now returns `confirmed` inside both —
where it used to shrug `possible`. The compiler attaches each block's own parameters to
that block, so the tool types the receiver by the exact block it sits in, never
confusing the two.

### A class's data, not just its methods

<!-- prov: commit 437a6a6 (rename-DATA, slice 1) + docs/spec-rename-data.md; case 110
     (fixture fixdata: homonym refused, unique member renamed incl. external uses) and
     case 48 re-baselined (the old v1 refusal became a verified rename); live-run
     2026-07-12 (fixdata scratchpad, both outputs below verbatim). -->

A class is data plus behavior — and renaming the *data* used to be the gap: the tool
would stop and say "that's a `VAR`/`DATA`, not a method". Now it does it. Take a balance
you want to call something else:

```harbour
CLASS Conta
   VAR nSaldo INIT 0
   METHOD Mostra()
ENDCLASS

METHOD Mostra() CLASS Conta
   ::nSaldo := ::nSaldo + 1     // a write…
   RETURN ::nSaldo              // …and a read
```

Point at the member and rename. The declaration, every **read**, every **write**, and
the class's own internal registration of the member all move together:

```
$ hbrefactor rename app.hbp c1.prg:16:8 nTeto
rename-data: CONTA:nLimite -> nTeto
  c1.prg:16:8
  c1.prg:10:7
  c1.prg:11:20
  predicted: _NLIMITE -> _NTETO
  predicted string: "nLimite" -> "nTeto" (c1.prg)
verified: 3 edit(s); DATA member getter+setter renamed, registration re-derived, other modules byte-identical
```

Reading a member and writing to it are two *different* messages as far as the compiler is
concerned (`nSaldo` and `_nSaldo`) — the tool renames **both**, and proves it against the
symbol table before keeping a single edit.

And the guard. If **two classes** in your project happen to have a member of the same
name, the rename is genuinely ambiguous — `:nSaldo` is dynamic dispatch, and no fact says
which class you meant. So it refuses, and names the other class:

```
$ hbrefactor rename app.hbp c1.prg:15:8 nX
hbrefactor: 'nSaldo' is also a member of: POUPANCA (c2.prg) - a send is dynamic dispatch, the rename is ambiguous; refusing
```

That's the same rule that has always governed homonymous *methods* — data members simply
inherit it.

### Same name, different owner — it only edits yours

<!-- prov: case 108 (14 checks, fixture fixgen — invented non-mirror DSL, plus the
     hbclass METHOD rules as the real-world proof); live-run 2026-07-11 (scratchpad
     probes, both outputs below verbatim); hbrefactor 5d8f108 + harbour-core
     0da1ee6277 (ast-13 rule genealogy + derivation surviving clones). -->

Real code reuses names. Say your DSL labels something `Vendas` — and a function named
`Vendas()` already exists, unrelated:

```harbour
#xtranslate LABEL <n> => RegLabel( <"n"> )

PROCEDURE Main()
   LABEL Vendas        // 'Vendas' here is a label your DSL turns into a string
   ? Vendas()          // 'Vendas' HERE is the real function — a different owner
   RETURN

FUNCTION Vendas()
   RETURN 42
```

Rename the label, and only the label changes:

```
$ hbrefactor rename app.hbp a.prg:4:10 Receita
rename-pp-marker: Vendas -> Receita
  a.prg:4:10
  predicted string: "Vendas" -> "Receita" (a.prg)
verified: 1 edit(s); derived artifacts renamed as predicted
```

The call `? Vendas()` and the function are untouched — and the other direction holds
too: renaming the *function* leaves the DSL sites alone. An occurrence is edited only
when a compiler fact ties it to the thing you pointed at; a matching spelling is never
enough.

It goes one level deeper. A directive can *define another directive* — that's how
Harbour's own class system works inside, and your DSLs can do it too:

```harbour
#xcommand DEFREGRA <n> => #xcommand USA <n> => ? Marca( <"n"> )

PROCEDURE Main()
   DEFREGRA Ponto      // creates, at preprocess time, the rule `USA Ponto`
   USA Ponto           // uses the rule that was just created
   RETURN
```

Renaming `Ponto` — at either position — edits both lines together and predicts the
derived string:

```
$ hbrefactor rename app.hbp a.prg:4:13 Marco
rename-pp-marker: Ponto -> Marco
  a.prg:4:13
  a.prg:5:8
  predicted string: "Ponto" -> "Marco" (a.prg)
verified: 2 edit(s); derived artifacts renamed as predicted
```

Behind both: the compiler now records the **genealogy** of preprocessor rules — when a
rule is created by another rule's expansion, the dump says which application created
it — and the tool only edits an occurrence whose owner is proven. Honest limit: if one
module mixes the two roles so tightly that even the symbol table can't separate them,
the tool still refuses and rolls back rather than guess.

### A directive can be switched off — and the rename follows it there

<!-- prov: case 117 (fixture fixun, invented non-mirror DSL); harbour-core 611e0c45cc
     (ast-16: the removal directive enters the rule table with its pattern POSITIONED,
     and carries `undoes` = the id of the rule it removed, or null when it removed
     nothing); live-run 2026-07-12 (scratchpad, output below verbatim). -->

A `#define` does not have to live to the end of the file. You can turn it off:

```harbour
#define RETRY_LIMIT 3

PROCEDURE Main()
   LOCAL nTries := RETRY_LIMIT
   ? nTries
   RETURN

#undef RETRY_LIMIT      // from here on, RETRY_LIMIT means nothing again
```

That is an ordinary hygiene idiom — and it is a **trap for every refactoring tool**,
because renaming the constant is only half the job. Rename `RETRY_LIMIT` and forget the
`#undef`, and the switch-off is left pointing at a name that no longer exists. It then
turns off **nothing**, and the definition **leaks** past the line where you ended it —
silently changing the meaning of code the rename never touched. Worse, nothing catches
it: if no site after the switch-off uses the word, the compiled output is byte-identical
either way, so a "verified" check happily passes.

hbrefactor follows the directive to where it dies:

```
$ hbrefactor rename app.hbp app.prg:4:22 MAX_RETRIES
rename-dsl: RETRY_LIMIT -> MAX_RETRIES
  app.prg:4:20
  app.prg:1:9
  app.prg:8:8
verified: 1 application site(s) + 2 directive occurrence(s); .ppo and .hrb byte-identical
```

The `#undef` on line 8 was renamed with the rest, so the constant still ends exactly
where you said it ends. The same holds for `#xuncommand` and `#xuntranslate` — a
command or translate rule has a lifetime too.

This works because the compiler now **says** that a directive was removed, and *which*
one it removed. Before, the preprocessor performed the removal and reported nothing; the
tool could only have gone looking for the text `#undef` in your source — which would be
blind to the abbreviated spellings, to the six forms the removal takes, and to a
directive that arrives from an included header. The fact was the whole problem.

And it reads that lifetime in the **other direction** too. Once a rule has been switched
off, its word is an ordinary word again — so a name that word had made *un-renameable*
becomes free:

```harbour
#include "lib.ch"                       // defines  #xcommand TRAVA <x> => ...
#xuncommand TRAVA <x> => Cinta( <x> )   // ...and here it dies

PROCEDURE Dead()
   LOCAL nVal                           // rename it to TRAVA:
   ...                                  // before: "collides with a preprocessor rule"
                                        // now:    it just works — nothing here captures TRAVA
```

**The honest limit:** it only frees the name when the switch-off comes **before any line
of code in that module**. If there is code above it, the rule was alive over that code,
and the refusal stays — a rule switched off on line 100 still captures on line 50, and
the tool will not pretend to know where your name will land.

That freed name is available to a **command**, too — and here the lifetime hides a trap
that costs a subtle bug. **A `#uncommand` removes by pattern, not by head.** So switching
`VERIFY` off does not simply "free the word": if the rule you now rename to `VERIFY` has
the *same shape* as the one you switched off, that same `#uncommand` removes **the rule
you just renamed**, and your call sites quietly start expanding through the *other* rule.
It compiles clean. Nothing warns you.

The tool does not reason about this — it **asks the preprocessor**, before touching a
byte. Different shapes, so the switch-off cannot bite: the rename goes through.

```
$ hbrefactor rename app.hbp lib.ch:1:11 VERIFY
rename-dsl: ASSERT -> VERIFY
  app.prg:8:4
  lib.ch:1:11
verified: 1 application site(s) + 1 directive occurrence(s); .ppo and .hrb byte-identical
```

Same shape, and it refuses — naming the directive that would do the damage:

```
$ hbrefactor rename app.hbp lib.ch:2:11 VERIFY
hbrefactor: 'VERIFY' would be turned off by the #xuncommand VERIFY at app.prg:4 -
after the rename that directive removes the renamed rule (it matches by pattern),
and the sites would expand through #xcommand VERIFY (lib.ch:1)
```

### A switch-off that switches nothing off

<!-- prov: phase P-AUDIT/A4, case 121 (fixture tests/fixa4); live-run 2026-07-12
     (scratchpad, output below verbatim). -->

A `#uncommand` whose pattern matches no rule **removes nothing**. Harbour accepts it in
silence: no warning, no error. You read the file, see the switch-off, and believe the
command is off — while it is still live, still capturing.

`usages` names it:

```
$ hbrefactor usages app.hbp ASSERT
lib.ch:1: directive (#xcommand ASSERT, 1 marker(s))
app.prg:4: directive (#xuncommand ASSERT, 2 marker(s)) - ORPHAN: removes no rule (dead directive)
app.prg:8:4: application (#xcommand ASSERT, lib.ch:1)  | ASSERT .T.
```

A **report, never an edit.** The tool will not rewrite a directive whose intent it cannot
verify — it can prove the switch-off is dead, but not what you meant it to say.

### "Would this new name collide?" — it asks the preprocessor instead of guessing

<!-- prov: phase P/P11, hbrefactor c391408 (the live pp as an oracle: __pp_init +
     __pp_process, from the core's own tests/hbpp/hbpptest.prg); live-run 2026-07-12
     (scratchpad, both outputs below verbatim). -->

A `#command` matches its keywords **abbreviated**. `#command LISTAR` is also matched by
`LIST`, `LISTA`, `LISTAR` — from four letters on. So renaming one directive can quietly
**hijack** another: give a rule a new head that happens to be an abbreviation of a rule
that already exists, and the preprocessor will start routing your calls to the wrong
one.

The tool refuses, and names the rule you would have collided with:

```
$ hbrefactor rename app.hbp app.prg:4:4 LIST
hbrefactor: 'LIST' collides by abbreviation with rule #command LISTAR (c.ch:2)
```

What matters is **who decided that**. hbrefactor does not reimplement Harbour's matching
rule — it starts a **live preprocessor**, feeds it the name you want, and watches whether
the rule fires. The authority on "does this collide" is the same preprocessor that will
compile your code tomorrow; when Harbour's rule changes, the answer changes with it, and
nothing here has to be kept in sync.

The difference is not academic. The earlier version *did* reimplement the rule — and it
refused renames that were perfectly safe, because a hand-written copy of a compiler's
logic is always a worse copy.

### The certainty ladder

<!-- prov: labels from src SendVerdict; layers exercised by cases 61–63, 66, 70, 87,
     88, 104. Exclusion conditions: commit 6df5c50 (concrete owner ≠ queried AND no
     escaping descendant; else possible). "guaranteed" read from compiler chk fact
     (ast-8, case 88). -->

hbrefactor deals in **facts, not guesses**. Every claim it makes comes from the
official Harbour toolchain — the **compiler**, the builder (**hbmk2**), the **virtual
machine** — or it is honestly reported as unknown. That honesty is visible in how it
labels each method call:

| Label | Means | Example |
|---|---|---|
| `possible` | dynamic dispatch — no fact decides; the honest "I don't know" | `possible send (receiver unknown)` |
| `confirmed` | receiver's class known from declared types | `confirmed send (receiver declared AS CLASS PAYMENT)` |
| `excluded` | provably **not** the queried class — dispatch resolved in the declared class graph, or a value kind that can't receive it | `excluded send ... (dispatches to LOGGER:SEND)` |
| `guaranteed` | the strongest — the *compiler itself* marked this site as checked under `-kt`; the tool reads the mark, it doesn't deduce coverage | `guaranteed send (receiver AS CLASS CONTA imposed by -kt checks)` |

It never labels a call more certain than the facts allow: a receiver with no declared
type stays `possible`; an exclusion requires the whole inheritance chain to be declared
inside your project — a parent from outside, or a class built at runtime, keeps the
honest `possible`.

### Why "no new syntax" actually holds

<!-- prov: CHANGELOG 2026-07-09 (zero pcode, "existem desde sempre"); case 89 asserts
     the annotation is inert without -kt (byte-identical .hrb). -->

The type information `annotate` writes — `DECLARE`, `_HB_MEMBER`, `AS CLASS` — isn't new.
These have been in the language **forever**, they cost **zero pcode**, and they feed the
*exact* channel tools already read. So `annotate` doesn't extend the language; it fills
in blanks the language always had room for. When a needed fact genuinely doesn't exist,
hbrefactor **extends the core** (the compiler emits a new fact) — never the syntax you
write.

### Opt-in fail-fast: `-kt`

<!-- prov: case 87 (NIL/is-a/unrelated/runtime-class/RETURN via DECLARE), case 88
     (coverage decided by chk fact; @ref and PARAMETERS AS honestly out), CHANGELOG
     2026-07-10 (codeblocks + the 20-year segfault). -->

Compile with `-kt` and every `AS CLASS` becomes a runtime invariant, checked by name on
the live object. Assign the wrong thing and your program stops **exactly there** —
naming the variable, what it expected, and what it got — instead of blowing up three
screens later with a cryptic "method does not exist":

```
Error BASE/3012  expected S:CONTA, got C: MAIN:OCONTA
```

It even reaches **code blocks** — the callbacks and filters where Harbour really lives —
and on the way there, a 20-year-old compiler crash had to be fixed so it could. A
subclass passes (is-a); a class built at runtime passes by name — the check works on the
live object, where static analysis can't reach. `-kt` is opt-in, per project (the
per-call check has a cost in very hot loops).

### What it does — the command set

<!-- prov: Usage() in src/hbrefactor.prg; per-command cases: renames 1–7/10–13/21/24/
     27/32/37/45–49/74/77/110 (110 = class data member, commit 437a6a6);
     usages 8–9/18/23/25–26/29/39/61–63/66/70/104/105; extract 16–17/
     33/43/59–60/79; inline 35–36; reorder 14–15/31/34/56/76; unused-locals 19;
     call-graph 20/57/78; find-dynamic-calls 22/58; dsl/pp 38/40–41/50–53/82;
     annotate 89–100; exec-registry 101; projects-of 83/102/103. -->

Every classic refactoring, re-seated on the compiler's facts; each one verified
(recompile, compare, roll back):

| Command | What it does |
|---|---|
| `rename` | Point the cursor at a name; it renames the *symbol* — local, parameter, static, memvar, function, method, a class's data member (`VAR`/`DATA`), even a preprocessor directive word or match-marker. **You don't classify the target**: the kind comes from the compiler's fact at that position, not from picking one of eight commands. It renames the symbol, never the text. |
| `usages` | Every reference to a symbol, scope-aware, with honest certainty labels; homonyms of other classes excluded by fact. Peek them right inside VSCode. |
| `extract-function` | Pull a range of lines into a new function — or a new METHOD when you're inside one; the locals it needs move with it. |
| `inline-local` | Fold a variable back into its uses — purity judged by the compiler's own tree. |
| `reorder-params` | Change a function's or method's parameter order and fix every call site to match. |
| `unused-locals` | Find variables never used, or assigned but never read, across the project. |
| `call-graph` | See who calls what — across modules, out to external functions; method sends shown as dynamic edges, honestly distinct from static calls. |
| `find-dynamic-calls` | Surface strings and macros that might be dynamic function calls — an honest audit that filters out the class system's own internals. |
| `annotate` | Materialize implied types (`DECLARE` / `AS CLASS`), verified, with automatic rollback. |
| `exec-registry` | Snapshot classes that only exist at runtime, by running just the registration code in a sandbox. |

And the trait that makes it different in kind: all of this works on **any construct a
preprocessor directive creates** — Harbour's own class system is *just one case*. Write
your own DSL (`#xcommand` sugar of your invention) and rename/usages/reorder work on it
with **zero configuration**; the suite proves it on invented DSLs the tool's source
never mentions by name.

### From the terminal, or inside your editor

<!-- prov: Usage() forms + tests/run.sh invocations; extension: vscode/package.json
     (14 commands, 4 settings), projects-of auto-discovery cases 83/102/103. -->

Everything lives in the **command-line tool** — fully usable on its own:

```
hbrefactor rename   vendas.hbp vendas.prg:42:8 Dobrar   # kind resolved by fact at the cursor
hbrefactor usages   vendas.hbp nTotal --func Main
hbrefactor annotate vendas.hbp --apply
```

One `rename` covers every kind — you give it the position, it finds out whether that's
a local, a static, a method, a directive word… and does exactly what the dedicated
command would (same edit, same verified rollback). The eight old `rename-*` commands
are **gone**: typing one gets an honest redirect to the unified form — never a wrong
action.

A "project" is anything `hbmk2` accepts: a `.hbp`, a `.hbc`, or just a list of `.prg`
files — including **container/multi-target `.hbp`** (`-hbcontainer`, sub-projects,
`-target=`): sources of *all* targets count.

The **VSCode extension** is a thin layer on top: it finds the symbol under your cursor
and calls the same CLI — and it finds the right `.hbp` for you by asking hbmk2 which
project actually compiles your file (nearest first when it must ask; never guessed by
proximity). Command Palette entries include *Usages*, a single **Rename Symbol** (the
familiar F2 — it figures out the kind from the cursor), *Extract selection to new
function*, *Annotate apply*, *Unused locals*, *Call graph*, and more.

---

## Under the hood

### How the facts are produced

<!-- prov: architecture (docs/arquitetura.md, ast-schema.md); byte proof cases 10/21/
     89–90; hbmk2 resolution cases 29/83/103; -kt by-name check case 87; exec-registry
     case 101. -->

hbrefactor never re-implements Harbour's grammar (a re-parse is a degraded copy that
drifts). It asks the official tools and reads the answer:

- the **compiler dumps a full AST** — tokens, scopes, every call site, with exact
  positions; that dump is the source of truth;
- **hbmk2** resolves the project — flags, includes, `.hbc` packages, containers and
  multi-target builds; the tool uses the *already-resolved* command, so it never
  guesses a flag;
- every edit is **proven** — recompile, compare the binary byte-for-byte, roll back on
  any difference;
- under `-kt`, the runtime **checks types by name** on the live object — reaching
  classes built at runtime that no static analysis could see;
- **exec-registry** compiles a minimal driver (never your `Main`), runs only the
  class-registration functions in a sandbox, and snapshots the live class table.

### What we changed in Harbour's core

<!-- prov: git log 0d3b4395..b07fef4060 on feature/compiler-ast-dump (25 commits, ~16
     substantive); schema ladder cross-checked with docs/ast-schema.md; W0019 commit
     b758cf376a; segfault fix in 29eb2aa940 (ast-8); parentage c2c26e5aa3 + b07fef4060;
     ast-14 c7100f8cdb, ast-15 4d6deca13d, ast-16 611e0c45cc.
     ZERO-IMPACT: this section used to cite "1085/1085 and 112/112 byte-identical",
     taken on faith from the core commits. Neither figure is reproducible - they were
     measured by hand, once, with no script, and they aged in silence. RE-MEASURED
     2026-07-12 with tools/pcode-identity.sh (which now exists precisely so that
     re-measuring is cheap): every .prg both compilers accept, built to portable pcode
     with the new switches OFF, compared byte for byte -> 889/889 identical, ZERO
     divergences. The CLAIM holds; the counts were fantasy. The maintainer-facing page
     no longer prints a count at all - it prints the command. -->

For those facts to exist, the compiler had to *emit* them. That work lives on a branch
of Harbour itself — `feature/compiler-ast-dump` — and grew as a ladder of dump schemas,
one fact at a time:

| Schema | The fact it added |
|---|---|
| `ast-1` | the `-x` switch: full token stream + functions dumped as `.ast.json` |
| `ast-2` | preprocessor rules and each application (the DSL channel) |
| `ast-3` | derivation trail on synthesized tokens (who created what) |
| `ast-4` | the language's declared-type channel |
| `ast-5` | the rule *inside* (match/result markers) |
| `ast-6` | which push carries a RETURN value |
| `ast-7` | `-kt`: declared types **enforced** as runtime invariants |
| `ast-8` | the compiler's own mark of what `-kt` actually checked (no deduced coverage) |
| `ast-9` | exact written position of every declared name (the editor's anchor) |
| `ast-10` | **declared class parentage** (`_HB_SUPER`) — who inherits from whom, as fact |
| `ast-11` | each codeblock carries its **own parameters** — types a send's receiver by the exact block (delegated getters/setters on one line stop colliding) |
| `ast-12` | a directive marker is stamped **`generates`** when the name you wrote gets pasted/stringified into an artifact — so "rename a name that becomes code" is told apart from "rename a symbol that just flows into a command" |
| `ast-13` | **rule genealogy**: a rule created by another rule's expansion records which application created it — and derivation now survives token clones, so a generated rule's artifacts stay traceable through its uses |
| `ast-14` | a marker a rule *matches but never uses* is no longer indistinguishable from a word of the rule itself — the preprocessor stopped throwing the binding away |
| `ast-15` | **which** word of the rule a token matched. `#command` accepts its keywords **abbreviated** (from 4 letters), so `GRAV` may be the rule's own keyword *or* `GRAVAR` cut short — only the preprocessor knows, and now it says so |
| `ast-16` | a directive has a **lifetime**. `#undef` and `#xuncommand` switch one off partway through a file — the preprocessor did that and told nobody, so a tool renaming the directive left the switch-off behind, pointing at a name that no longer existed, and the directive silently **leaked** past the point where you turned it off |

Along the way: a **20-year-old segfault fixed** (annotating a code-block parameter with
`AS CLASS` used to crash the compiler — stock Harbour still does), and a false
`W0019 "duplicate declaration"` warning silenced when a re-declaration merely completes
a missing type (it had blocked 18 methods in `hbhttpd`).

### Extending the compiler without breaking a single byte

That is the whole bet, and it is the part both Harbour programmers and Harbour **maintainers**
care about most: **the compiler gives more information, and your build does not change.**
With `-x` and `-kt` off — the state every existing project is in — the patched compiler emits
the **same bytes** as the one you have today. Measured, not asserted — and the measurement is a
script you can run: every `.prg` the two compilers both accept is built to pcode by each and
compared byte for byte, with **zero divergences**.

The core branch has **its own page**, written for the Harbour maintainers — the consolidated
case, the honest shape of the diff, the two bugs it fixes in *stock* Harbour, and what we still
don't have good answers for:
**[the core proposal](https://diegopego.github.io/harbour-core/)**
(source: `harbour-core/site/index.html`; the user-facing log is `harbour-core/NEWS.md`).

The founding principle in action: when a fact doesn't exist, **extend the core so it
does** — never build a guess inside the tool.

---

## Where it stands — honest status

<!-- prov: roadmap.md (delivered table, RE.6/RD-c entregues, U slices 1-2 delivered,
     phase P/P1 delivered, gates B6/B8/D), CLI 0.5.0 / extension 0.13.0, suite 796/0
     (this commit, phase P/P1 - ast-13 rule genealogy consumed, case 108); rough
     edges: cases 88 (@ref, PARAMETERS AS), commit c127b1f (same-basename limit),
     CHANGELOG 2026-07-10/11; limits doc (limites-e-alavancas.md: irreducible maybe,
     library openness). -->

hbrefactor is an **active, living experiment** — pre-1.0 (CLI `0.5.0`, VSCode extension
`0.13.0`; they version independently). The behavior contract is a suite of **116 cases /
961 checks**, all green, byte-identical in parallel and sequential runs. Being honest
about the rough edges is part of the product.

The big caveat: it needs a **custom branch of Harbour** (the AST-dump fork), not the
stock compiler.

**Still rough**

- Renaming a class **data member** covers plain `VAR`/`DATA`; members with explicit
  `ACCESS`/`ASSIGN` accessors, or inherited from a superclass, aren't covered yet.
- Function *parameters* aren't annotated yet — only local variables and code-block
  parameters.
- Some "maybe" is irreducible: a receiver whose class depends on runtime input (config,
  deserialization, macros) honestly stays `possible` — that's the nature of the
  problem, not a bug. Library code keeps more `possible` than a closed program (its
  callers live outside the project).
- In a chained call (`oM:Soma(1):Soma(2)`) the label stays `confirmed`, not
  `guaranteed`, even under `-kt`.
- Two modules with the same filename under a multi-target `.hbp` can get confused in
  fine analysis (ownership works).
- A switch-off only frees a name when it sits **in the module's own file**. If the
  `#uncommand` arrives from an included header, the tool does not decide — it cannot see
  from the compiler in what order your headers reached that module — and the refusal
  stays. Fail-closed, on purpose.
- The per-call `-kt` check has a cost in very hot loops (so it's opt-in), and it doesn't
  cover pass-by-reference (`@x`) or legacy `PARAMETERS x AS ...` — those sites are never
  labeled `guaranteed`.

**What's next, if it all goes well**

- Inference reborn as a *suggester*, never a verdict: it proposes an `AS CLASS`, the
  tool only writes it if a declaration can make it a fact, and the core then enforces
  it. The machine suggests; the compiler proves.
- Per-instance usages (see "what we're building toward" above).
- More maturation across real Harbour code — then real applications.

---

## Help wanted: review the Harbour branch

<!-- prov: Diego's explicit ask (2026-07-10); branch inventory from git log. -->

I built the `harbour-core` branch that makes these compiler facts exist — the AST dump
(sixteen schema steps), the `-kt` enforcement, the parentage channel, the segfault and
warning fixes. But I'm a Harbour **application** developer, **not a compiler/VM
specialist**. I would genuinely value people who know Harbour's core taking a look.

If you know the compiler, the VM, or the class system — issues, corrections, and second
opinions are all welcome:

**→ `feature/compiler-ast-dump`** — https://github.com/diegopego/harbour-core/tree/feature/compiler-ast-dump

---

## Install

<!-- prov: Makefile (build/test, HB_BIN default), vscode/hbrefactor-0.13.0.vsix,
     CLAUDE.md HB_BIN rule. -->

**Requirement, stated honestly:** hbrefactor drives a special build of Harbour — the
`feature/compiler-ast-dump` branch — via `HB_BIN`. Its verification won't run against
stock Harbour.

1. **Build that Harbour branch** and note its `bin` directory (that's your `HB_BIN`).
2. **Clone and build the tool:**
   ```
   git clone https://github.com/diegopego/hbrefactor
   cd hbrefactor
   make build        # produces bin/hbrefactor
   make test         # optional: the behavior suite (116 cases)
   ```
3. **VSCode (optional):** install `vscode/hbrefactor-0.13.0.vsix` and point
   `hbrefactor.hbBin` at your `HB_BIN`.

---

## What it never does

<!-- prov: refusal/rollback cases 2/5/7/11/15/17/36/43/46/48/53/56/90; exec-registry
     sandbox case 101; exclusion honesty commit 6df5c50 + CHANGELOG 2026-07-10. -->

- **Never touches strings, comments, or data** — only code the compiler can verify.
- **Never edits an include that is not yours** — the boundary is the directory of your
  `.hbp`, not the directory you happen to have run the command from. A shared `.ch` that
  lives outside your project is refused by name.
- **Never guesses:** no fact → it reports `possible` or refuses, and rolls back.
- **Never excludes by guess:** a homonym is only excluded when the receiver's type is
  known *and* the whole inheritance chain is declared in your project — otherwise it
  stays an honest `possible`.
- **Never keeps an edit that changes your program** — proven byte-for-byte, or undone.
- **Never edits without you asking** — `annotate` needs `--apply`, and the extension
  confirms first.
- **Never runs your whole program** — `exec-registry` runs only registration functions,
  sandboxed.
- **Never claims more certainty than the facts allow.**

---

*hbrefactor — and this page — were written with the help of **Claude Code**, under
Diego's supervision. MIT © 2026 Diego Oliveira Pego. Independent project, built on
[Harbour](https://harbour.github.io/). Colors: the [Nord](https://www.nordtheme.com/)
palette.*

<!-- Links: project https://github.com/diegopego/hbrefactor · branch https://github.com/diegopego/harbour-core/tree/feature/compiler-ast-dump -->
