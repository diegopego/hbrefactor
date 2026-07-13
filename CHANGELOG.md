<!-- changelog-baseline: hbrefactor@63be8f0 -->
<!-- Delta pointer. Everything AFTER this commit is NOT yet described here.
     To resume:  git log 63be8f0..HEAD   (see § Maintaining this file, at the end).

# Changelog

**Audience: the Harbour programmer.** What each release changes in your day-to-day
work, with an example and an honest limit.

**This is NOT a changelog for contributors — for that, the changelog is git itself.**
The commit history is already complete, precise and dated; that is where the *how*
lives (which function, which channel, which structure). This file answers the other
question, the one git does not: *what can I now do, and where does it bite me?* If you
find an implementation detail here, that is a bug in this file — the internal "how"
(phases, specs, decisions) lives in [docs/roadmap.md](docs/roadmap.md) and in the specs
under `docs/`.

The compiler that makes all of this possible has its own:
**[harbour-core/NEWS.md](../harbour-core/harbour/NEWS.md)** (branch
`feature/compiler-ast-dump`). There it is called `NEWS` by GNU convention — Harbour
already has a `ChangeLog.txt`, which is the *developer's* log; `NEWS` is the *user's*.

## 2026-07-12 — a rule you switched off no longer blocks your rename (and dead switch-offs get named)

Two limits this file declared open are now closed.

**1. A switched-off rule stops reserving its name.** A pp command lives from the
`#xcommand` to the `#xuncommand`. If you turned `VERIFY` off in a module, its word is
ordinary code there — yet renaming another command to `VERIFY` was refused anyway
(*"'VERIFY' is already a rule head"*). Now it goes through:

```
rename-dsl: ASSERT -> VERIFY
  app.prg:8:4
  lib.ch:1:11
verified: 1 application site(s) + 1 directive occurrence(s); .ppo and .hrb byte-identical
```

**But "switched off" is not a free pass — and this is the part worth knowing.** A
`#uncommand` removes by **pattern**, not by head. So if the rule you switched off has
the *same shape* as the one you are renaming, that very `#uncommand` will now switch off
**the rule you just renamed** — and your call sites silently start expanding through the
*other* rule. It compiles clean. You would find out in production.

The tool asks the preprocessor before touching a byte, and refuses:

```
hbrefactor: 'VERIFY' would be turned off by the #xuncommand VERIFY at app.prg:4 -
after the rename that directive removes the renamed rule (it matches by pattern),
and the sites would expand through #xcommand VERIFY (lib.ch:1)
```

**2. An orphan switch-off is now named.** A `#uncommand` whose pattern matches no rule
removes nothing — Harbour accepts it in silence, and you walk away believing the command
is off when it is still live. `usages` points at it:

```
lib.ch:1: directive (#xcommand ASSERT, 1 marker(s))
app.prg:4: directive (#xuncommand ASSERT, 2 marker(s)) - ORPHAN: removes no rule (dead directive)
app.prg:8:4: application (#xcommand ASSERT, lib.ch:1)  | ASSERT .T.
```

It is a **report, never an edit** — the tool does not rewrite a directive whose intent it
cannot verify.

**The honest limit (unchanged):** the name is only freed when the switch-off comes
**before any line of code in the module**. With code above it, the rule was alive over
that code, and the refusal stays.

*Internal details: [docs/roadmap.md](docs/roadmap.md) § P-AUDIT/A4.*

## 2026-07-12 — rename stops touching an include that isn't yours (and stops refusing the ones that are)

Three fixes that came out of an audit of the tool's own code. The first two change what
it **does**; the third, what it **tells you**.

**1. The SHARED include is really out of bounds now.** When you rename the word of a pp
command, the tool also edits the directive that defines it. It always promised to refuse
touching a *system* include — but it measured that by the directory **you happened to
run the tool from**, not by the project. The effect, measured:

```
# the .ch lives OUTSIDE the project (shared between projects), but inside your cwd
$ cd ~/work
$ hbrefactor rename app/app.hbp app/main.prg:5:4 FIXA
  app/main.prg:5:4
  ../common/lib.ch:2:11         <-- it edited an include belonging to OTHER projects
verified: .ppo and .hrb byte-identical
```

And it said `verified` because, from **this** project's point of view, everything was
fine: a consistent rename does not change the expansion. The damage showed up in the
neighbouring project. With your cwd at `$HOME`, this could reach as far as the
`hbclass.ch` of your Harbour installation. The boundary is now the **directory of the
`.hbp`**, and a `.ch` outside it is refused by name:

```
hbrefactor: directive in '../common/lib.ch' is outside the project's directory -
            refusing to edit a system/shared include
```

**The other side of the same coin:** running the tool from any directory now works.
Before, `hbrefactor rename /path/app.hbp ...` called from outside the project's folder
refused to edit the `.ch` **of that very project**, claiming it was a "system" one.

**2. A rule switched off by `#uncommand` no longer blocks your name.** A pp command is
alive from the `#xcommand` until the `#xuncommand` — after that its word is ordinary
code again. The tool ignored that switch-off and treated the word as reserved forever:

```harbour
#include "lib.ch"                       // defines  #xcommand TRAVA <x> => ...
#xuncommand TRAVA <x> => Cinta( <x> )   // ...and here it dies

PROCEDURE Dead()
   LOCAL nVal                           // rename it to TRAVA:
   ...                                  // before: "collides with a preprocessor rule"
```

The name was legitimate — nothing there captures `TRAVA` — and it was
**un-renameable**. The tool now reads the switch-off. **The honest limit:** it only
frees the name when the `#un...` comes **before any line of code in the module**. If
there is code above it, the rule was alive over that code and the refusal stays — the
tool does not guess where your name will turn up.

**3. Renaming a FUNCTION to a command's word now refuses on the spot.** If the new name
is the head of a live rule, writing `MyFunc( 2 )` as `TRAVA( 2 )` makes the pp
**capture the call** — your function is never called. The verification net already
caught this (the program was restored, nothing was lost), but the message was a generic
verification error. Now you get the fact, before any edit:

```
hbrefactor: new name 'TRAVA' collides with a preprocessor rule (#xcommand TRAVA, lib.ch:1)
```

The other five rename verbs already asked this question; the one for functions was the
one missing.

**If you used an earlier version, it is worth a check.** Item 1 only writes to a `.ch`
when the rename touches a directive — that is, when you renamed the word of a pp
command, a rule marker, or used `--edit-rules`. If you did that **with the terminal
outside the project's folder**, run a `git status` in your other projects and in the
Harbour tree: there may be a `.ch` edited that you never asked for. Renaming a variable,
a function or a method never touched an include at all.

*(Both "still open" limits this entry used to list — the DSL word not reading the
switch-off in its own collisions, and the un-diagnosed orphan `#uncommand` — are closed;
see the entry at the top of this file.)*

*Internal details and the rest of the audit: [docs/roadmap.md](docs/roadmap.md) § P.*

## 2026-07-12 — the tool now speaks ENGLISH

**This changes what you read in the terminal.** Every `hbrefactor` message — warnings,
refusals, the `verified:` at the end — moved from Portuguese to English.

```
before:  hbrefactor: 'nSaldo' também é membro de: POUPANCA (c2.prg) - recuso
now:     hbrefactor: 'nSaldo' is also a member of: POUPANCA (c2.prg) - refusing
```

The reason is simple: the tool exists to be used by Harbour programmers anywhere, and
Harbour is an international project. A message half the world cannot read is not a
message.

**Where this bites you:** if you have a script, a `Makefile` or an editor that
**matches text** in `hbrefactor`'s output to decide something (a `grep "recuso"`, an
`if` on "não compila"), **it stops working**. The *exit code* did not change — `0` is
success, anything else is a refusal or an error — so a script that only looks at the
exit code is unaffected. If you match text, now is the time to switch to the exit code.

The VSCode extension speaks English too; there is nothing for you to do there.

**Correction (2026-07-12):** one line escaped the sweep — the `--dry-run` footer still
printed `dry run - nada foi escrito`. It now reads `dry run - nothing was written`. Same
advice as above: match the exit code, not the text.

## 2026-07-12 — fixed: extracting a block containing a `SWITCH` was refused for no reason

`extract-function` **refused** any range that contained a `SWITCH`, with an explanation
that sounded reasonable and was wrong:

```
$ hbrefactor extract-function app.hbp core.prg 1382-1420 MimeTypeOf
hbrefactor: EXIT on line 1384 would jump outside the selection
```

The `EXIT` it saw was the `EXIT` of a `CASE` — the end of one branch of the `SWITCH`,
which began and ended **inside** the range itself. The tool confused it with the `EXIT`
that abandons a loop and, believing it would jump outside the selection, refused. It was
a **false refusal**: the extraction was perfectly safe.

This knocked out exactly the most common extract-function case in real Harbour code —
that thirty-branch `SWITCH` buried in the middle of a large function, the one everybody
wanted to pull out. Now:

```
extract-function: lines 1382-1420 of UPROCFILES -> MimeTypeOf( cFileName ) returning cI
  LOCAL nI (line 1356) is used only in the selection - moves to MimeTypeOf
verified: symbols preserved (+MimeTypeOf); run your test suite to confirm behaviour
```

**What is still refused, and rightly so:** a `LOOP` inside a `SWITCH`. It does not
belong to the `SWITCH` — it goes back to the enclosing loop. If that loop is outside
your selection, the jump really does cross the boundary, and the extraction would change
your program's behaviour. There the tool still stops.

## 2026-07-12 — `dump`: the compiler's facts, for you to look at with your own eyes

A **retroactive** entry: the command has existed from the start and never had a line here.

```
$ hbrefactor dump myproject.hbp
```

It compiles your project and records, for each `.prg`, what the **compiler knows** —
every name with the line and column where you wrote it, every declaration with its real
scope, every call, every message sent to an object, and the preprocessor rules your code
uses. It is the same information every other command consumes; `dump` just puts it in a
file and tells you where.

It is there so you can **check the tool instead of believing it**: if a `rename` refused
and you want to know why, or if you want to build your own analysis on top of the facts,
the material is right there. It edits nothing.

**Honest limit:** the format is versioned (`"schema"`) and **still changes** — it is a
channel for people who want to investigate, not a stable API.

## 2026-07-12 — fixed: renaming a directive could make it LEAK out of scope

If you **switch off** one of your directives in the middle of a file — and Harbour lets
you; that is what `#xuncommand` and `#xuntranslate` are for — renaming the directive
broke the switch-off.

```harbour
#xcommand LACRA <x> => uu_( <x>, 1 )

PROCEDURE Main()
   LACRA 1
   RETURN

#xuncommand LACRA <x> => uu_( <x>, 1 )    // from here on, LACRA is ordinary code
```

Renaming `LACRA` to `CIFRA`, the tool changed only the line at the top. The
`#xuncommand LACRA` **was left behind**, trying to switch off a directive that no longer
had that name — that is, it switched off **nothing**. The directive stayed alive to the
end of the file, and code that was meant to be ordinary was expanded again. No error, no
warning.

**Now the rename carries both together:**

```
$ hbrefactor rename un.hbp un.prg:4:4 CIFRA
rename-dsl: LACRA -> CIFRA
  un.prg:4:4
  un.ch:6:11
  un.prg:8:13          <- the #xuncommand, coming along
verified: 1 application site(s) + 2 directive occurrence(s); .ppo and .hrb byte-identical
```

**What the compiler started telling us.** This was information the preprocessor had and
handed to nobody: it *knows* a directive was removed — it is the one doing it — but it
never said so. Now it does, and with it came a second fix: Harbour has **three** families
of directive (the one that accepts an abbreviated word, the `x` one that demands the
whole word, and the `y` one that also distinguishes upper from lower case), and the
information reaching us **did not distinguish the third** — a `y` directive was described
as if it accepted abbreviation, which is false. *(Requires the branch compiler with the
AST dump.)*

**Honest limit:** an `#xuncommand` that switches nothing off — because nobody defined
that directive — is still silently accepted by Harbour, and the tool still **does not
warn** about it. The data already exists; the command that shows it does not.

## 2026-07-12 — fixed: renaming a directive could HIJACK another one, silently

This is the worst one we have fixed: the rename **passed**, said `verified`, and left
your project broken — except the breakage lay **dormant**.

You have two directives, and one of them is not used anywhere yet:

```harbour
#command ROTULA <t> => qq_( <t>, 0 )     // it exists, but nothing uses it yet
#command PAUTAR <x> => qq_( <x>, 1 )
```

You rename `PAUTAR` to `ROTULAGEM`. The tool accepted it:

```
$ hbrefactor rename app.hbp seq.prg:4:4 ROTULAGEM
rename-dsl: PAUTAR -> ROTULAGEM
verified: 1 application site(s) + 1 directive occurrence(s); .ppo and .hrb byte-identical
```

**And from that point on, your `ROTULA` had been hijacked.** Because `#command` accepts
the abbreviated word from 4 letters on, `ROTULAGEM` now matched `ROTU`, `ROTUL` — and
even `ROTULA` **spelled out in full**:

```harbour
ROTULA 9      // you write this, expecting  qq_( 9, 0 )
              // and you get                qq_( 9, 1 )   <- the body of the OTHER one
```

No error, no warning. And the tool's own verification did not catch it: since `ROTULA`
**had no uses at all**, nothing moved — the program compiled identically. The bomb only
went off the day someone wrote the first `ROTULA`, probably months later.

**Now the tool refuses, and shows you the exact spelling that would become ambiguous:**

```
$ hbrefactor rename app.hbp seq.prg:4:4 ROTULAGEM
hbrefactor: 'ROTULAGEM' collides by abbreviation with rule #command ROTULA (seq.ch:1)
            - after the rename, writing 'ROTU' would match BOTH rules
```

**What changed underneath, and why it matters to you:** the tool used to keep its own
copy of Harbour's abbreviation rule — and a copy ages and drifts. It now **asks the
preprocessor itself** whether the two words would collide, instead of redoing the
arithmetic. If Harbour changes the rule tomorrow, the answer stays right.

**Honest limit:** it only refuses the ambiguity **the rename creates**. If your project
already has two directives in conflict (two heads sharing the same first 4 letters are
already fighting **today**, with no rename involved), the tool **stays out of it** — that
is your choice, and it was not the one that created it.

### And the advice that is worth more than the fix: use `#xcommand`/`#xtranslate`

All of this — the hijack above, the confusing warning in the next entry, the `MENU` that
matches two directives — comes from **one** property of `#command` and `#translate`: they
accept the word **abbreviated** from 4 letters on (a dBase/Clipper inheritance).

`#xcommand` and `#xtranslate` are **identical in every way** except that: they demand the
**whole** word. You lose no capability — this is not a "limited" version, it is the same
thing without the trap.

```harbour
#command  ROTULA <t> => qq_( <t>, 0 )   // ROTU, ROTUL, ROTULA... all match
#xcommand ROTULA <t> => qq_( <t>, 0 )   // only ROTULA matches. Ambiguity impossible.
```

**For a new directive, always prefer the `x` forms.** The non-`x` forms exist for
compatibility with old Clipper code — and that is exactly why the tool keeps
understanding both (Harbour's own `std.ch` and `hbclass.ch` are full of them). But in the
code **you** write today, there is no reason to pay the price.

## 2026-07-12 — fixed: a directive could end up with an UN-RENAMEABLE head

If your directive has a secondary word that starts like the main word, renaming the main
one **failed** — with a message that made no sense:

```harbour
#command GRAVAR <x> GRAV <y> => zz_( <x>, <y> )   // GRAV starts like GRAVAR
...
   GRAVAR 1 GRAV 2
```
```
$ hbrefactor rename app.hbp a.prg:5:4 SALVAR
hbrefactor: abbreviated use 'GRAV' ... - normalize to 'GRAVAR' before the rename
```

It told you to "normalize" something that **was already normalized**. In practice: that
directive's head simply could not be renamed, full stop.

**Why it happened.** In `#command`/`#translate` (the families without `x`), Harbour
accepts the word **abbreviated** from 4 letters on — so `GRAV` *could* be an abbreviation
of `GRAVAR`. Except that here it was not: it was the rule's own `GRAV` word, spelled out
in full. The tool had no way to know and **guessed from the text**.

Now it **does not guess**: the preprocessor started reporting which word of the rule each
piece of your code actually matched. Renaming the head works, the secondary word is left
alone, and the warning about a **genuinely abbreviated** use still exists (there it is
legitimate). *(Requires the branch compiler with the AST dump.)*

## 2026-07-12 — renaming a directive's `<marker>`, and the `.ch` finally reachable

You have a directive of yours with a badly named marker:

```harbour
#xcommand VULK <n> [ KRAN <cMat> ] => ;
          FUNCTION vk_<n>() ;; RETURN { <"n">, <cMat> }
```

Swapping `<n>` for `<nome>` is tedious and dangerous by hand: the name appears in the
**match** and in every use in the **result** (including pasted, `vk_<n>`, and inside a
string, `<"n">`), and missing one breaks the directive. It is now an ordinary `rename`,
with the cursor on the marker — **inside the `.ch` itself**:

```
$ hbrefactor rename app.hbp rules.ch:13:17 nome
rename-rule-marker: <n> -> <nome> in #xcommand VULK (rules.ch:14)
  rules.ch:13:17
  rules.ch:14:24
  rules.ch:14:43
verified: 3 marker occurrence(s) in the directive; .ppo and .hrb byte-identical (alpha-rename)
```

A marker's name is a **local variable of the directive** — it appears in no use and is
not a symbol of the program. Therefore: **your uses do not change** (`VULK Lamina ...`
stays as it is), and the `<n>` marker of **another** directive is a different variable and
is not touched. And since the swap cannot change ANYTHING in the program, the tool demands
the strongest proof it has: **the whole project's expansion and pcode must come out
byte-identical** — if anything changes, it undoes. Renaming to a name that is already
another marker of the same directive is refused before the file is touched.

**Bonus, and perhaps the most useful part day to day:** your `.ch` files stopped being
invisible. Before, with a `.ch` open in the editor, the tool said *"not a source of the
project"* — because an include really is not in the `.hbp`'s source list. Now it **asks
the compiler** which includes the project uses (`harbour -gd`, the official dependency
list — it catches includes of includes too) and finds the owner. In practice: **rename and
find-references work with the cursor inside the `.ch`**, including from VSCode.

## 2026-07-12 — `--dry-run` stops approving a rename that the apply undoes

If one of your directives GENERATES a function and you call that function by its generated
name, renaming the generator would orphan the call:

```harbour
#xcommand VULK <n> [ ... ] => FUNCTION vk_<n>() ;; RETURN ...

VULK Escudo          // generates FUNCTION vk_Escudo()
...
? vk_Escudo()        // you wrote the GENERATED name, by hand
```

The tool already knew how to refuse this — but it went **blind when the hand-written
spelling was inside a command**. And `? ...` *is* a command (`#command`), like almost
everything in Harbour. The symptom was ugly: `--dry-run` said it would work, and the real
apply edited, recompiled, hit an error and undid everything with a message that explained
nothing (*"the symbol/function count changed - rollback"*). In other words: the dry-run
**lied**.

It now refuses **before touching the file**, pointing at the exact site:

```
$ hbrefactor rename app.hbp a.prg:19:6 Pavesado
hbrefactor: the source spells out the generated name 'vk_Escudo' (a.prg:14)
            - renaming 'Escudo' would orphan it; refusing
```
And `--dry-run` and the real apply now **agree** — what the dry-run says is what happens.

**Also in this release** (two corners of the preprocessor that now have proof):

- **Headless rule** — a directive that starts with a marker instead of a word
  (`#xtranslate <x> ZORBADO => ( <x> * 2 )`) is resolved, listed and renamed normally. It
  always worked; now it is proven.
- **Optional groups out of order** — the pp matches `[ COM ... ] [ PESO ... ]` in any
  order, and the rename finds every site in both orders.
- **Honest limit:** a DSL word that **another directive emits** (a rule expanding into
  another) has no position in your source — there is nothing to edit. The tool refuses
  saying so, instead of editing half of it.

## 2026-07-12 — `usages --at` stops mixing a preprocessor marker with a homonymous symbol of your code

Imagine your project has a real function, `FUNCTION Vendas()`, and also uses a third-party
directive that has nothing to do with it:

```harbour
#xtranslate LABEL <n> => RegLabel( <"n"> )   // becomes a STRING, "Vendas"

LABEL Vendas          // just a screen label - text, not a reference to the function
? Vendas()             // THIS one calls the function
```

Before, clicking `Vendas` inside `LABEL Vendas` and asking "where is this used"
(`usages --at`) gave you the definition and the call of the function `Vendas()` **together**
with the label — as if they were the same thing. And the reverse happened too: clicking the
real function threw in the `LABEL Vendas` for free (and any other unrelated directive that
happened to use the same text). `--at` computed correctly **what** was under the cursor
(`resolve-at` already got it right — it is the same fact `rename` was already using), but it
threw that information away and fell back on a blind text search for "Vendas" across the
whole project.

Now `usages --at` **uses** that fact to pick only what belongs to the site you clicked:

```
$ hbrefactor usages app.hbp --at a.prg:5:10        # cursor on LABEL Vendas
a.prg:5:10: Vendas - marker name (no identifiable owner)
a.prg:5:10: name through pp rule (#xtranslate LABEL, ...)
1 result(s) for 'Vendas'

$ hbrefactor usages app.hbp --at a.prg:11:10       # cursor on the real FUNCTION
a.prg:6: call in MAIN
a.prg:11: definition (function)
2 result(s) for 'Vendas'
```

**What does NOT change:** `usages Vendas` typed without `--at` behaves as before — a broad
search across every occurrence of the text "Vendas", since without a position there is no way
to know which of the two you mean. And a value that merely **passes through** a directive
without becoming a new artifact (e.g. `? nTotal`, where `?` is also a directive but `nTotal`
is your real LOCAL going through it) still counts as the real symbol — the same distinction
`rename` has used since the previous release.

Investigation + proof: [docs/spec-p-pp-refatoracao.md § P3](docs/spec-p-pp-refatoracao.md).

## 2026-07-12 — the tool understands ALL of the preprocessor's marker types

A directive's `<x>` is not one single thing. The pp has **15 marker types**, and all of them
now have a verdict: 13 the tool uses, 2 it refuses while saying why. Three things change in
your day-to-day work:

**1. A restricted value is validated BEFORE the file is touched.**

```harbour
#xcommand SET MODO <x: RAPIDO, LENTO> => ...
```

If you try to rename `RAPIDO` to something that is **not one of the alternatives**, the rule
would stop matching. Before, the tool edited, recompiled, hit a `syntax error` and undid
everything (rollback) — leaving you baffled. Now:

```
$ hbrefactor rename app.hbp a.prg:6:10 zzz
hbrefactor: 'zzz' is not one of the alternatives of the rule's RESTRICTED marker
            (RAPIDO, LENTO) - the rule would stop matching; refusing
```
It refuses **before touching the file**, and tells you which values are accepted.

**2. What the directive swallows and throws away is not confused with a word of the rule.**

```harbour
#xcommand ANOTA <*x*> => QOut( "nota" )   // the <*x*> swallows everything and DISCARDS it

ANOTA ANOTA        // the 2nd 'ANOTA' is YOUR content; the 1st is the directive's word
```
Both are the same text on the same line — and the tool now **tells them apart by a compiler
fact**, not by guesswork. Clicking the second one says: *"content consumed and DISCARDED by
the directive"*, and the rename refuses (there is nothing to rename — that never reaches the
compiler).

**3. Renaming a variable warns you when a directive discards one of its occurrences.**

Markers such as `<.x.>` (emits `.T.`/`.F.`) and `<-x->` (emits nothing) **consume the value
and throw it away**. If you rename a variable and it appears in one of those places, the tool
**does not edit** (there is no fact linking that text to your variable — editing it would be
by coincidence of name) but it **warns**:

```
warning: a.prg:12:10: 'n' is consumed and DISCARDED by directive (#xcommand R_LOG)
         - never reaches the compiler; NOT renamed
```

**A curiosity you may never have seen:** the `<@>` marker exists to solve **circular rules** —
a directive whose result begins with the very word it matches (like hbfoxpro's `PUBLIC`). It
marks the output so the pp does not re-apply the rule to it, and it disappears before the
compiler. The tool **preserves it intact** when editing the rule.

**Honest limit:** two marker types do not exist inside a rule, and the tool says so: `%s` only
lives in `TEXT…ENDTEXT` (stream machinery), and the `__FILE__`/`__LINE__` channel is internal
to the preprocessor — you cannot write it.

## 2026-07-11 — renaming a class DATA/VAR member

Before, if you tried to rename a class's data (`VAR`/`DATA`), the tool refused ("it's a
VAR/DATA, not a method"). It works now: renaming the member updates the **declaration**, every
**read** (`::nSaldo`, `oConta:nSaldo`) AND every **write** (`::nSaldo := x`) at once, plus the
class's internal registration.

```harbour
CLASS Conta
   VAR nSaldo INIT 0
   METHOD Mostra()
ENDCLASS
METHOD Mostra() CLASS Conta
   ::nSaldo := ::nSaldo + 1
   RETURN ::nSaldo
```

Put the cursor on `nSaldo` (in the `VAR nSaldo` declaration) and rename it to `nTotal`: the
declaration, the `::nSaldo := ::nSaldo + 1` (write AND read) and the `RETURN ::nSaldo` all
become `nTotal`, and the class starts registering `"nTotal"` — all verified by recompilation
(if anything does not add up, it undoes with a rollback).

**Safeguard:** if TWO classes in the project have a member with the SAME name
(`Conta:nSaldo` and `Poupanca:nSaldo`), the tool **refuses** and names the other class —
because the access `:nSaldo` is dynamic dispatch and the rename would be ambiguous. It is the
same rule that already applies to homonymous methods.

**Honest limits (slice 1):** it covers plain `VAR`/`DATA`. A `VAR` with `ACCESS`/`ASSIGN`
(a getter/setter you write as a method) and DATA inherited from a superclass are left for a
future slice. A CLASS name is still out of scope.

## 2026-07-11 — the right rename with a repeated name; a DSL that creates a DSL now renames

Two situations that used to go wrong (one refused confusingly, the other did not exist at all)
now simply work.

### 1. Your marker's value coincides with the name of a real function

```harbour
#xtranslate LABEL <n> => RegLabel( <"n"> )

PROCEDURE Main()
   LABEL Vendas        // 'Vendas' here is a label (becomes the string "Vendas")
   ? Vendas()          // 'Vendas' here is the real, homonymous FUNCTION
   RETURN

FUNCTION Vendas()
   RETURN 42
```

Renaming the label (`rename app.hbp a.prg:5:10 Receita`) now edits **only the LABEL line** and
predicts the derived string — the call `? Vendas()` and the function are left intact. Before,
the tool dragged the homonymous function's call along, the verification noticed the damage and
undid everything with a confusing message; now it knows, from a compiler fact, **which owner
each occurrence belongs to**. The reverse holds too: renaming the FUNCTION (from the call or
from the definition) does not touch homonymous DSL sites.

### 2. Your DSL defines ANOTHER DSL — and the name in the middle now renames

```harbour
#xcommand DEFREGRA <n> => #xcommand USA <n> => ? Marca( <"n"> )

PROCEDURE Main()
   DEFREGRA Ponto      // creates, at pp time, the rule `USA Ponto`
   USA Ponto           // uses the rule that was just created
   RETURN
```

Renaming `Ponto` — in EITHER of the two positions — now edits both sites together and predicts
the derived string:

```
$ hbrefactor rename app.hbp a.prg:5:13 Marco
rename-pp-marker: Ponto -> Marco
  a.prg:5:13
  a.prg:6:8
  predicted string: "Ponto" -> "Marco" (a.prg)
verified: 2 edit(s); derived artifacts renamed as predicted
```

Before, the `DEFREGRA` position refused ("cannot classify"). What unlocked it: the branch
compiler now records the **genealogy** — when a pp rule is created by the expansion of another,
the dump says which application it was born from — and the tool consumes that fact. It works for
the real hbclass (that is how `METHOD` works under the hood) and for any DSL of yours, existing
or invented.

### 3. Renaming a DSL word that BUILDS and REFERENCES at the same time

A marker's word sometimes does two things in the same rule: it **builds** a new name (pasting
`w_<n>`, or becoming the string `"<n>"`) AND it **references** something that already exists (a
call, a variable). For example:

```harbour
#xcommand WRAP <n> => FUNCTION w_<n>() ;; RETURN <n>()

WRAP Soma           // generates FUNCTION w_Soma() which calls the real Soma()

FUNCTION Soma()
   RETURN 42
```

When you rename `Soma` in `WRAP Soma`, the tool re-derives EVERYTHING that comes from that word
— the pasted name, the string, the reference. And you are safe on both sides, with no silent
surprise:

- if the new name **does not exist** (`WRAP Soma → WRAP Multiplica`, and there is no
  `Multiplica` function), the recompilation notices the broken reference and **undoes
  everything** (rollback) — no crooked code;
- if the new name **does exist**, it compiles and the directive now operates on it — which is
  what "renaming the directive's argument" means.

This holds no matter how complex the directive is: the same word can be pasted **several times**
and the pp sets no limit — the tool predicts every artifact and, if it got one wrong, the
verification undoes it. **The guarantee does not depend on the tool "understanding" your DSL** —
it checks the COMPILED result: either it matches the prediction (correct rename), or it undoes
(rollback). It never leaves a rename half done.

### What the tool still NEVER does

- Edit by coincidence of name: every edit needs a compiler fact linking the occurrence to the
  target.
- Leave a broken tree: every application recompiles and verifies; any divergence undoes
  everything (byte-exact rollback).

### Honest limits

- Requires the updated toolchain from the `feature/compiler-ast-dump` branch (schema `ast-13`)
  — harbour AND hbmk2 rebuilt.
- If ONE symbol in the module mixes both roles in a way the symbol count cannot separate (the
  marker's raw name becomes a symbol AND a homonymous function exists), the tool still refuses
  with a rollback — real ambiguity does not become guesswork.

## 2026-07-11 — the eight `rename-*` commands were REMOVED (only `rename` remains)

In the previous release the unified `rename` arrived and the eight old commands
(`rename-local`, `rename-param`, `rename-static`, `rename-memvar`, `rename-function`,
`rename-method`, `rename-dsl`, `rename-pp-marker`) were **deprecated**. Now they are **gone**.

### What changes for you

- Use **`rename <project> <file:line:col> <new>`** (in the extension, **Rename Symbol**, F2).
  One command; the kind comes from the fact under the cursor.
- If you type an old command, the tool **warns and redirects** instead of doing something wrong:
  ```
  $ hbrefactor rename-local app.hbp a.prg Main x y
  hbrefactor: 'rename-local' was removed - use `rename <project> <file:line:col> <new>`
  ```
- **No capability is lost.** Each rename engine is still there underneath (the `rename` delegates
  to it); only the per-kind command was taken out of the command line and out of the VSCode
  palette.

### If you have scripts

Replace `rename-<kind> <project> ... <old> <new>` with `rename <project> <file:line:col> <new>`,
pointing at the symbol's position. It is the same verified edit, with the same report.

## 2026-07-11 — one single `rename`: you point, the tool works out what it is

### The everyday problem

To rename something you had to know BEFOREHAND what kind of thing the target was and pick the
right command: `rename-local`, `rename-param`, `rename-static`, `rename-memvar`,
`rename-function`, `rename-method`, `rename-dsl` or `rename-pp-marker`. Eight commands — and the
question "is this a local or a static? a method or a function?" is exactly what the compiler
already knows.

### What changed

There is now **one verb**, and it takes the cursor's POSITION:

```
hbrefactor rename <project> <file:line:col> <new> [--force] [--edit-rules] [--dry-run]
```

You put the cursor on the name and say the new name. The tool looks at the FACT in the tree at
that point and works out for itself what to rename — local, parameter, STATIC, memvar
(PRIVATE/PUBLIC), function, method, directive word or pp marker name — and does exactly what the
specific command would have done (same edit, same verification by recompilation, same rollback).
In the VSCode extension this becomes a single **"Rename Symbol"** (the usual F2).

```
# before: you had to know it was a method, and the class:
hbrefactor rename-method app.hbp Caixa:Info Mostra
# now: cursor on Info, at any use or at the implementation:
hbrefactor rename app.hbp c1.prg:17:8 Mostra
```

### What the tool NEVER does here

- **It does not guess.** A cursor on a spot with no compile-time symbol (a comment, whitespace, a
  crooked column), or on a genuinely ambiguous case, gets a **refusal naming the reason** — it
  never renames the wrong thing silently. It resolves by what the compiler *binds* at that point:
  a variable used inside a command (`? x`, `@..SAY`) is still that variable; a call `Foo(...)` is
  the function even if a homonymous local `Foo` exists; an RDD field (`FIELD`) — which no verb
  covers — is refused, not confused with a function of the same name; and a name your directive
  **turns into code** (pasted into a function name, or turned into a string) is treated as the
  command/marker it is — renaming it carries the artifacts it generates — without being confused
  with a local that the expansion itself happens to create with the same name. (These corners were
  closed by **two** rounds of cross external review before the release — and the criterion
  "generates code × merely passes it along" became an explicit compiler fact.)
- **It loses no capability** from the old commands: `--edit-rules` (the name is cited inside a
  directive) and `--force` (strings/`HB_FUNC` equal to the name) still apply, now asked for at a
  single point.
- **It does not rename a class** (the name in a `CREATE CLASS`) and does not collapse
  `extract`/`reorder` — one position is not enough to state a range to extract or a new parameter
  order; those keep their own arguments.

### Deprecation notice

The eight specific `rename-*` commands still work in this version, but are **deprecated** —
`--help` already marks them. Switch to `rename <file:line:col>`; a future version removes the old
ones. The extension already ships the unified command as the main one.

### Internal detail

Unified verbs (phase U, slice 1) — [docs/roadmap.md](docs/roadmap.md) § U,
[docs/spec-u-verbos-unificados.md](docs/spec-u-verbos-unificados.md),
[docs/adr-002-rename-unificado.md](docs/adr-002-rename-unificado.md).

## 2026-07-11 — `usages`/find-references sees the receiver INSIDE delegated properties (`VAR ... IS/IN`)

### The everyday problem

The Class(y) dialect has a shortcut for creating a property that **forwards** to another one — an
alias, or a delegation to an inner member/object:

```
CREATE CLASS Gizmo
   VAR nRaw  INIT 0
   VAR oPart INIT NIL
   VAR nEcho AS Numeric IS nRaw              // alias: reading nEcho reads nRaw
   VAR nVia  AS Numeric IS nCount TO oPart   // delegates to the member oPart
END CLASS
```

Each `VAR ... IS`/`IN` generates, hidden, **two** mini-functions: one to read (`Self:nRaw`) and
one to write (`Self:nRaw := value`). When you asked for the references of `Gizmo:nRaw` (or of
`Gizmo:oPart`), the uses INSIDE those mini-functions came out as **`possible` (receiver
unknown)** — noise, because the `Self` there is generated by the directive and both blocks land
on the same line of your source, which the tool could not tell apart.

### What changed

Those uses now come out **`confirmed`**. It works for all four Class(y) forms — `VAR x IN Super`,
`VAR x IS y`, `VAR x IS y IN Super`, `VAR x IS y TO oObj` — and for the **getter AND the setter**
of each:

```
usages Gizmo:nRaw
// BEFORE: g1.prg:15: possible send (... receiver unknown, codeblock)   (x2)
// NOW:    g1.prg:15: confirmed send (receiver declared AS CLASS GIZMO, codeblock)  (x2)
```

It closes the sibling hole that the previous release (`INLINE` methods) solved: there it was one
block per line; here there are two (read + write), and the compiler now attaches to each block the
list of **its own parameters** — so the tool types the receiver by the exact block, without mixing
the two up.

### What the tool NEVER does here

- It does not alter anything generated: this remains **detection and reporting**; no automatic edit
  inside those mini-functions.
- **Zero cost**: the compiled `.c` (even with `-kt`) stays byte-identical — the new fact lives only
  in the analysis dump, not in your executable.
- It only confirms the block's `Self`: a send chained after it (`Self:oPart:nCount` → the
  `:nCount`) still needs the fact of the next link; what becomes `confirmed` is the send anchored
  on `Self`.

### Internal detail

Directive route / M-B completeness — [docs/roadmap.md](docs/roadmap.md) § RD-c; the `"params"`
channel on the block node in [docs/ast-schema.md](docs/ast-schema.md) (schema `ast-11`).

## 2026-07-10 — `usages`/find-references sees the receiver INSIDE an `INLINE` method

### The everyday problem

You use `INLINE`, `OPERATOR`, `ACCESS ... INLINE`, `ASSIGN ... INLINE` in your classes (or a DSL
of yours that generates similar codeblocks):

```
CREATE CLASS Moeda
   METHOD Total INLINE ::Soma( 0 ):nCents
   OPERATOR "+" ARG nQ INLINE ::Soma( nQ )
END CLASS
```

That `::Soma()` INSIDE the `INLINE` is a real call to `Moeda`'s `Soma` method. But when you asked
for the references of `Moeda:Soma` (the `usages` command or the extension's "find all references"),
that site came out as **`possible` (receiver unknown)** — noise, because the block's receiver is
**generated by the directive** and has no token written in your source for the tool to anchor on.

### What changed

That send now comes out **`confirmed`**. The compiler started recording the class of the `INLINE`
block's receiver as a **FACT** (a new `hbclass.ch` channel). With it the tool resolves `::Soma()`
by the language's own rule, with no guessing:

```
oJ:Total()              // confirmed - already worked (receiver oJ typed)
// and now, INSIDE the INLINE itself:
METHOD Total INLINE ::Soma( 0 ):nCents
//                     ^^^^ BEFORE: possible (receiver unknown)
//                          NOW:    confirmed (receiver declared AS CLASS MOEDA, codeblock)
```

It works for **any** construct that generates that kind of block — not just `hbclass`. A DSL of
YOURS that registers behaviour as a codeblock with a typed receiver gets the same treatment, with
no adjustment inside the tool.

### What the tool NEVER does here

- **It never becomes `guaranteed`, not even under `-kt`**: an `INLINE`'s receiver is always of the
  class itself (Harbour guarantees the dispatch), so imposing a runtime check on it would be
  redundant cost. The tool delivers the declared type's promise (`confirmed`) and **stops there** —
  **zero `-kt` overhead** added to your build (proven byte for byte).
- **It does not guess**: if the block is not generated by a construct that declares the receiver's
  class (an ordinary codeblock with an untyped parameter), the send stays **`possible`** (honest).
- **It edits nothing**: this is analysis only; your source is untouched.

The internal "how" (the RD "directive route", the `_HB_INLINESELF` channel) lives in the
[roadmap](docs/roadmap.md) § RD.

## 2026-07-10 — `usages Class:Method` stops showing homonyms from other classes

### The everyday problem

Two classes in your project have a method with the same name — `Paint()` in `Janela` and `Paint()`
in `Relatorio`, `Soma()` in `Conta` and in `Outra`. You ask for the references of `Janela:Paint`
(from the command or from the extension's "find all references") and, among the legitimate hits,
up come `oRel:Paint()`, `oOutra:Soma()` — calls that are **never** of the class you asked about,
they just share the name. Noise in every search, and dangerous in a rename.

### What changed

Now, when the tool **proves** that the send goes to ANOTHER class's method, it **excludes** it from
the result — and the proof is a FACT, not a guess. The compiler started recording in the dump **who
inherits from whom** (a new parentage channel). With that fact, the tool resolves the dispatch by
Harbour's own rule (an own method beats an inherited one; with multiple inheritance, the first
parent in the clause wins) and seals the exclusion:

```
// Janela and Relatorio, both with their own Paint(), unrelated
oJ := Janela():New()
oR := Relatorio():New()
oJ:Paint()   // a reference of Janela:Paint
oR:Paint()   // BEFORE: showed up as "possible"; NOW: EXCLUDED by fact
```

The report names the reason: `excluded send within the declared class graph (dispatches to
RELATORIO:PAINT)`. In the extension, "find all references" simply **stops listing** those sites.

It still tells real uses apart: if `oFilho:Paint()` and `Filho` **inherits** `Paint` from `Janela`
(without overriding it), that send IS a reference of `Janela:Paint` — it stays in the result. Only
what overrides, or belongs to a class unrelated to the one you asked about, drops out.

### What the tool NEVER does here

- **It does not exclude by guess**: only when the receiver's type is known (declared, or imposed by
  `-kt`) AND the whole inheritance chain is in the project. An untyped receiver, a parent outside
  the project, or a class assembled at runtime → it stays **`possible`** (honest), never excluded.
- **It does not confuse inheritance with homonymy**: a child that inherits the method from the class
  you asked about is still a reference of it.
- Those already using `-kt` get the exclusion backed by the runtime check; without `-kt`, the
  declared type's promise applies (as always).

The internal "how" (RE.6, the `_HB_SUPER` channel, schema `ast-10`) lives in the
[spec](docs/spec-re6-parentesco-declarado.md).

## 2026-07-10 — a complex `.hbp` (container, sub-projects) recognised in full

### The everyday problem

Your `.hbp` is not a simple single-target project. It is a **container** (`-hbcontainer`) that
gathers several sub-projects, or it references another `.hbp`, or it uses `-target=` to produce more
than one binary. You open a `.prg` belonging to the **second** (or third) of those targets, run a
command in the extension, and the tool behaves as if that `.hbp` were not the owner of your file — or
the picker does not even offer the right project.

For example:

```
# app.hbp
-hbcontainer
gui/gui.hbp      <- 1st target
srv/srv.hbp      <- 2nd target
```

Opening a `.prg` from `srv/`, the `app.hbp` was ignored as the owner.

### What changed

The tool now reads **every target** your `.hbp` produces, not just the first. It still does not parse
the `.hbp` by hand: it asks **hbmk2** (the official builder) what the compile line of **each** target
is and merges the sources of them all. The result: a `.prg` belonging to any target of the project is
recognised as a source of that `.hbp`.

As a bonus, everything hbmk2 already resolved underneath keeps working for free, because the tool
reads the **already-resolved** command:

- `.hbm` (a collection of options included in the project),
- `.hbc` (package/lib),
- `-i<path>` includes, `${hb_name}`/`${hb_targetname}` variables,
- platform filters `{win}` / `{!win}`.

Before: only the first target of the `.hbp` was seen; the rest vanished.
After: every target counts; the `.hbp` is recognised as the owner of any source of yours.

### What the tool NEVER does here

It does not interpret the `.hbp`/`.hbm`/`.hbc` on its own and does not guess flags: macros, filters,
includes and sub-projects are resolved by hbmk2. The tool only uses what the official builder
reported.

### Honest limit

If two targets of the same `.hbp` compile modules with the **same file name** in different folders
(e.g. `gui/util.prg` and `srv/util.prg`), ownership works, but fine analysis (usages/rename) may
confuse the two when matching the dump — this only happens under `-hbcontainer` with repeated names.
If it turns up in your use, let us know. Internal detail: B5.1 in
[docs/roadmap.md](docs/roadmap.md).

## 2026-07-10 — the picker finds the right `.hbp` on its own (nearest first)

### The everyday problem

You open a `.prg`, run **Find usages** (or any command) in the extension and land in a list of several
`.hbp` files — sometimes the same one repeated — and, worse, the `.hbp` sitting in **your file's own
directory** is not even there. In a large project (hbrefactor has 158 `.hbp`/`.hbc` files) that was
the rule, not the exception.

### What changed

Now, with a file in focus, the extension **discovers the project on its own**: it asks the CLI, which
**walks up from your file's directory** (a project's `.hbp` lists its sources by relative path, so the
owner is almost always right there or just above), asks **hbmk2** which project actually compiles your
file, and answers with the owner.

- **A single owner → it goes straight in, without asking.** That was always the picker's goal; the
  32-result cap was what sabotaged it (it cut off the right `.hbp` before deciding). The cap is gone.
- **Did it have to ask? The nearest one comes first.** When a file is a source of more than one
  project (a shared source), or when it is not yet in any, the list comes out **ordered by
  proximity**, with a readable `.hbp` name + directory — no more raw absolute paths repeated.
- **No duplicates.**

Before: a list of 32 `.hbp` files out of order, with the one in your directory missing.
After: it enters the right project without asking — or, at most, you choose among the real owners with
the nearest one first.

### What the tool NEVER does here

- **It does not guess the owner by proximity.** Deciding "this project compiles this file" is hbmk2's
  job, by fact. Proximity only **orders** the list and the search order; the `.hbp` nearest your file
  is **not** picked automatically unless hbmk2 confirms it is the owner (a neighbouring `.hbp` that
  does not list your file appears in the list, but is not auto-selected).
- **It does not read the `.hbp`'s contents.** It only lists the names of project files in the
  directories; expanding and resolving is hbmk2's job.
- **A `.ch` is not a target.** A header is an `#include`-d dependency, controlled by the
  `.prg`/`.hbp`/`.hbc` — not a project a file "belongs" to.

### Honest limits

- If your file is not owned by any ancestor project, the tool widens the search by scanning the
  workspace root (a rare case; a safety cap warns in the log if the tree is enormous).
- If you pinned `hbrefactor.project` in the settings, none of this runs — your choice wins.

### Technical details

`projects-of` DISCOVERY mode (ancestor walk-up + `RankByProximity`, proximity used only for
presentation) — [docs/roadmap.md](docs/roadmap.md), section B5; proofs in suite case 102 and in the
case 71 harness.

## 2026-07-10 — `exec-registry`: a snapshot of the classes that only exist at runtime

### The everyday problem

If your system assembles classes at runtime — a DSL of your own on top of `__clsNew`, computed class
names, registration inside an INIT — no source analysis can see them. And even in ordinary hbclass
classes, the VM creates messages that are written nowhere: the superclass *casts*
(`o:MyBase:Field`). To the tool, all of that was "receiver unknown".

### What changed

```
hbrefactor exec-registry project.hbp
```

compiles your project with a minimal driver (never your `Main`), RUNS only the class-registration
functions — found by fact: whoever calls `__clsNew`/`__cls*` in the compiled code, plus the INITs, plus
whatever you point at with `--run F1,F2` — and records a snapshot of the live class table in an
`.astr.json`: each class with its name, selectors (with their kind — method, inline, cast), ancestors,
and the PROVENANCE ("registered by running F()").

- **Nothing is edited**: the command only observes and records the snapshot.
- **Every call is protected**: a registration function that requires an argument fails in isolation and
  shows up in the report as "failed" — the rest of the harvest carries on. Arguments are never invented.
- **A sandbox with the same containment `--apply` already uses**: a separate process, a timeout, an
  isolated working directory. (Honestly: any I/O YOUR registration code performs is not blocked — that is
  exactly why the command is opt-in, and why the VSCode extension asks for confirmation.)
- **It works in a library** (`-hblib`): the driver becomes the executable. A useful side effect: linking
  an executable exposes a method that is declared and never implemented — in hbhttpd itself it found one.
- **A deterministic snapshot**: two runs produce the same file, byte for byte.

### What the tool NEVER does

- Run your `Main` or the whole program — only registrars.
- Treat the snapshot as static truth: what ran along those paths is CONDITIONAL evidence. The snapshot
  SUGGESTS; what seals it is the `-kt` check in a real run (a wrong snapshot → an error naming the site
  and the types).
- Edit source from the snapshot — automatic writing was MEASURED and dropped for now: in the core's
  well-written code, casting is 0-1% of sends and a class invisible to the source is an initialisation
  niche; the snapshot is worth having as an inventory/diagnostic, and writing only comes back if real use
  asks for it.

### Honest limits

- A class registered only along a conditional path (config, environment) may not appear in the snapshot —
  and an absence never becomes a verdict.
- A `STATIC` registration function has no symbol callable from outside: it is left out WITH a report (move
  the registration into a public function, or use an INIT).
- Measurements on real corpora (details in docs/): the gain is in the CAST selectors (38% of the sends in
  the casting torture corpus use them); in code with neither casting nor dynamic registration, the
  snapshot adds no site at all.

(Internal: B9 slice 4, F4.1+F4.2 —
[docs/spec-b9-fatia4-execucao-controlada.md](docs/spec-b9-fatia4-execucao-controlada.md).)

## 2026-07-10 — `annotate` learned to annotate a codeblock parameter

### The everyday problem

The previous release made `-kt` check codeblock parameters — but the one WRITING the annotation was you,
by hand. And the most valuable place for it is precisely the least obvious to annotate:

```harbour
bPar := {| oPar | oPar:Soma( 2 ) }     // what class is oPar?
Eval( bPar, Moeda():New() )
```

### What changed

`annotate --apply` now writes `AS CLASS` on a block parameter too, at the exact position of the name:

```harbour
bPar := {| oPar AS CLASS MOEDA | oPar:Soma( 2 ) }
```

- **Where it can prove it, it writes it**: a block registered as an inline member of a class (the first
  parameter is the receiver — this holds for hbclass and for ANY DSL of yours) and a block whose visible
  `Eval`s agree on the class. The verification is the same triple as always: the edit is inert without
  `-kt` (identical bytecode), it compiles clean, and the project RUNS under `-kt` with the checks passing
  — any failure undoes everything byte for byte.
- **A class created at runtime is no obstacle**: if your DSL's class does not exist at compile time,
  `annotate` also inserts a one-line pure registration (`_HB_CLASS MyClass`) that makes it known to the
  module — without promising any member.
- **The write hits the target even in the treacherous cases**: a parameter name repeated on the same line
  (declaration + use), a statement continued with `;`, a variable with the same name as the class. This is
  because the compiler now reports in the dump the exact position of the written token of EACH
  declaration — the tool does not guess a position, it reads it.
- Once annotated, `usages` decides by fact: the sends inside the block come out `confirmed`/`guaranteed`
  instead of "possible (receiver unknown)".

### What the tool NEVER does

- Annotate without proof: a block that leaves the function, a parameter rewritten in the body, `Eval`s
  that disagree on the class, a second parameter with no dispatch fact — none of those get an annotation;
  the honest report stays.
- Edit what you did not write: the body a directive generates (e.g. hbclass's `METHOD x INLINE ...`, whose
  `Self` is created by the rule) has nowhere in YOUR source to receive an annotation — the tool recognises
  that and leaves it alone.

### Honest limits

- The suggestion comes from analysis; the TRUTH belongs to the imposed check: if the picture is wrong, the
  program aborts naming the point (`BASE/3012`) — and `--apply` has undone edits that way in the past (that
  is the designed behaviour, not an accident).
- The block-parameter check runs on every `Eval` — in a very hot loop that has a cost; `-kt` remains opt-in
  per project.

## 2026-07-10 — `-kt` reaches codeblocks (and a 20-year-old segfault dies on the way)

### The everyday problem

Codeblocks are where Harbour lives — callbacks, `AEval`, `dbEval`, filters. And that is exactly where
`-kt`'s fail-fast stopped:

```harbour
LOCAL oConta AS CLASS Conta := Conta():New()
LOCAL bPaga  := {|| oConta := GetItFromSomewhere() }   // a lie here PASSED
Eval( bPaga )
```

The write inside the block was not checked — the annotation promised, the runtime did not verify. And
worse: annotating the block's *parameter* (`{| oX AS CLASS Conta | ... }`) **brought the compiler down** —
a segfault that is in stock Harbour to this day (upstream crashes the same way). In other words: the most
idiomatic form in the language was a blind spot for the check.

### What changed

- **`{| oX AS CLASS Conta | ... }` now compiles** (the segfault is dead) and the annotation holds: on every
  `Eval`, the received value is checked — a wrong class, a wrong kind or a NIL aborts on the spot, naming
  the function and the parameter (`MAIN:OX`). A subclass passes (is-a); a class assembled at runtime passes
  by name.
- **A write inside a block to an annotated local is checked** — the example above aborts at the point of the
  lie (`expected S:CONTA, got C: MAIN:OCONTA`) instead of blowing up three screens later.
- **`usages`' `guaranteed` seal now comes from a compiler FACT**: the compiler itself marks in the dump every
  write it checked and every parameter whose prologue it emitted. The tool stopped deducing coverage by a rule
  of its own — it reads the mark. Block sites that used to be "confirmed (a promise)" become `guaranteed`
  because they ARE.

### What is still out (measured, not guessed)

- Pass-by-reference (`F( @x )`): the check does not cover it — and measuring a real corpus showed **zero**
  object-variables passed by `@` (all strings/numbers/arrays). It stays out, on the record; the label never
  says `guaranteed` at those sites.
- `PARAMETERS x AS ...` (the legacy style): still a promise, not enforced.
- A check inside a block runs on every `Eval` — in a very hot loop that is a cost; `-kt` remains opt-in.

## 2026-07-10 — `annotate --apply`: the rollback guarantee now has a trial by fire

### The everyday problem

Every tool that edits your source promises "if it goes wrong, I'll undo it". The question that matters: **what
if the lie is in your declarations, not in your code?** An `_HB_MEMBER Acha() AS CLASS Moeda` written years ago
promises the method returns a `Moeda` — but the implementation returns a number. That compiles clean, runs
clean, and no static analysis in the world can tell the promise from the fact. If `annotate` trusts it (and it
should — a declaration IS the language's fact channel), the annotation it writes will be wrong.

### What changed

The suite now contains exactly that scenario, fabricated on purpose (a new fixture): the declaration lies,
`annotate --apply` writes the annotation the lie justifies, and the **run under `-kt`** — the only oracle able
to catch it — blows up at the right place. What you see:

```
hbrefactor: gold standard FAILED after annotating locals: declared-type check FAILED
while running under -kt: Error BASE/3012  declared type check failed:
expected S:MOEDA, got N: MAIN:X
```

And your sources go back **byte for byte** to what they were — proven by binary comparison in the test, not
promised. The refusal names the variable, the expected type and the received type, taken from the runtime error
itself: you find out for free that that old declaration lies.

A reading clarification this work produced (and it applies to your code): in `_HB_MEMBER Acha() AS CLASS Moeda`,
the method's *ownership* comes from the line's POSITION (it attaches to the last class declared above); the
`AS CLASS` is the method's **RETURN type** — the same `AS <type>` you would write in `METHOD Acha() AS ...`
inside the class.

### Also in this release

- **Every class topology proven in the suite** (one per fixture): a class in another module, a class in the same
  module, a multi-class module (each declaration attaching to the right class), a factory with a `DECLARE`
  before the definition, and a DSL that assembles a class only at runtime. In all of them, the site that was a
  "maybe" ends up `guaranteed` when the project compiles with `-kt`.
- **Pure class registration**: when all that is missing is *registering* the class in the module (so the
  `AS CLASS` does not degrade), the tool now writes `_HB_CLASS <Class>` — registering without promising any
  method. Before it would have written a `DECLARE <Class> New() ...` that promises a `New` which may not exist.
- **Your failure does not become the edit's fault**: if your project ALREADY breaks at runtime (or is a server
  that never terminates), `--apply` detects that BEFORE editing and skips the run step, reporting "execution
  already failed WITHOUT the edit" — instead of refusing the work and blaming its own annotation. The other
  verifications (identical binary, clean compile) still apply.
- On a real project (hbhttpd, 14 classes): `--apply` wrote **31 declarations + 7 annotations**, verified, in
  ~3 seconds, and the re-report comes back empty — everything declarable was declared; what is left is what
  only inference could reach, and that the tool does not write.
- **A project that already compiles with `-kt` can now be annotated** (it was the last blocker for anyone who
  had adopted the fail-fast): the "identical binary" proof now compares compilations *without* the flag — with
  it, the annotation changes the binary *on purpose*, since it is the annotation emitting the checks. A bonus
  for those already on `-kt`: the freshly written annotation comes out `guaranteed` in `usages` right away, with
  no extra step.

### Limits that remain (honest, declared)

- Function parameters are still not annotated — only locals. And when they are, most will still only be
  REPORTED: a parameter's type almost never follows from a declaration (it is the union of the callers = a
  guess, and the tool does not write guesses).
- In a chained send (`oM:Soma( 1 ):Soma( 2 )`), the label stays `confirmed via declared types` even when `oM` is
  annotated in a `-kt` project — chained resolution prefers to under-declare rather than overreach.
  `guaranteed` shows up at direct-receiver sites.

Internal details: [docs/spec-b9-fatia2-materializacao.md](docs/spec-b9-fatia2-materializacao.md)
§ "Entregue (F2.4-complemento + F2.5)".

## 2026-07-09 — `annotate`: your untyped code becomes typed code, with proof

### The everyday problem

Typical Harbour code says the type of nothing:

```harbour
LOCAL oMenu := UWMenu():New()
oMenu:AddItem( "Sair" )
```

You know `oMenu` is a `UWMenu`. The compiler does not — it records it and moves on. The consequence shows up in
the tools: any reference search or rename over `AddItem` has no way to state *which class* that send belongs to.
Either the tool guesses (and one day renames the wrong method on a homonym), or it is honest and gives you a
"maybe" — which is what hbrefactor does: with no fact, the site comes out `possible`, and the manual check is on
you.

The detail almost nobody uses: **the language already has a way to say the types.** `DECLARE`, `_HB_MEMBER` and
`AS CLASS` have always existed, cost **zero** in the compiled program (not one extra pcode) and feed exactly the
channel the tools read. Nobody writes them because it is tedious, verbose and easy to get wrong.

### What the command does

`hbrefactor annotate <project>` analyses the whole project and classifies every variable and every return on a
ladder of certainty:

- **level 1** — the type already follows from what is declared; all that is missing is writing the `AS CLASS`.
- **level 2** — *one declaration line* is missing in the right place (e.g. the inherited `New` that no class
  declares). The tool tells you exactly which line and where.
- **level 3** — the tool can even *conclude* the type by looking at the project (every caller passes a `Peca`),
  but no declaration exists that would turn that into a fact. **There it writes nothing** — it reports, and the
  decision is yours.

With `--apply`, it writes for you — in the right order and with verification at each step:

1. it writes the missing declarations (`DECLARE`, `_HB_MEMBER`);
2. **it proves nothing changed in the program**: it recompiles and demands a binary byte-identical to the
   previous one (a declaration is pure compile-time — if a single byte differed, it is an automatic rollback);
3. it proves the project still compiles clean under `-w3 -es2`;
4. it recompiles with `-kt` and **runs** it — the runtime checks confirm the annotations tell the truth;
5. only then does it annotate the variables (`LOCAL oMenu AS CLASS UWMENU := ...`), and verify everything again.

Any failure at any step: your sources go back byte for byte to what they were, with the reason named.

### What you get

**Before** (the chained send is the classic example):

```
q1.prg:75: possible send (dynamic dispatch, receiver unknown)  | oM:Soma( 1 ):Soma( 2 )
```

**After** `annotate --apply`:

```
q1.prg:79: confirmed send (receiver class MOEDA via declared types)  | oM:Soma( 1 ):Soma( 2 )
```

In practice:

- **Trustworthy rename and usages** — sites that were a "maybe" become fact; homonyms stop polluting your
  searches.
- **Free documentation** — `LOCAL oMenu AS CLASS UWMenu` tells the next programmer (and you, six months from
  now) what the variable is, at no runtime cost.
- **Optional fail-fast** — if you compile with `-kt`, every annotation becomes a checked invariant: assigning the
  wrong thing blows up on the spot, naming the variable, the expected and the received — instead of a
  method-not-found error three screens later.
- **Your code is still the same program** — proven byte for byte, not promised.

In VSCode: `hbrefactor: Annotate report` (report only) and `hbrefactor: Annotate apply` (asks for confirmation
before writing).

### The change in the compiler (why it was necessary)

There was a dead-end case: a method **already declared** that only needed to gain its return type — the
`METHOD Soma( n )` inside the `CREATE CLASS` declares the method, but without a type. The line that completes it
(`_HB_MEMBER SOMA( n ) AS CLASS MOEDA` after the class) always worked — the compiler was *designed* for the last
declaration to prevail — but it emitted the warning **W0019 "Duplicate declaration of method"**, and anyone
compiling with warnings-as-errors (`-es2`) saw the build fail because of a line that changes nothing.

The change (branch `feature/compiler-ast-dump`, commit `b758cf376a`) is a five-line condition: **completing a type
that did not exist yet is not a duplicate** — it stays silent. It still warns about what it should: re-declaring a
method whose type *was already known* (a real conflict), a duplicate class, a duplicate function. On a real corpus
(hbhttpd), 18 methods were held back by this warning alone — it was the biggest blocker in the whole project, and
it fell to that one condition.

### What the command *never* does

- It does not write a guess: level 3 (inference only) goes into the report with its reason, never into your source.
- It does not touch a string, a comment or data — only declarations and annotations that recompilation verifies.
- It does not edit anything without `--apply` (and the VSCode extension still asks for confirmation first).
- It does not leave damage: any verification fails, the rollback restores everything.

### Limits of this release (honest, declared)

- Function parameters are still not annotated — only locals (the signature needs its own idiom; a future slice).
- A project that **already** compiles with `-kt` is left for the baseline-strip slice (the byte-identical proof
  requires compiling without `-kt`).
- The rollback is exercised by a real build failure, but the deliberately provoked case ("an annotation that lies
  and `-kt` catches it") still becomes its own fixture — **delivered on 2026-07-10 (the entry above)**.

Internal details: [docs/spec-b9-fatia2-materializacao.md](docs/spec-b9-fatia2-materializacao.md)
§ "Entregue (F2.4)" and [docs/plano-b9-fatia2-escada.md](docs/plano-b9-fatia2-escada.md).

---

## 2026-07-04 → 07-08 — the FOUNDATION *(retroactive entry, written on 2026-07-12)*

> **Why this entry exists.** The CHANGELOG rule was born on 2026-07-09 — so everything delivered **before** it
> never got an entry, and six commands you use today were **documented nowhere** for the end user. The hole was
> found in an audit (`git log` × CHANGELOG) and is closed here. This is not a new release: it is a debt being paid.

In this window everything that holds up the rest was born — first on a prototype, then **refounded on the
compiler's AST** (the `.ast.json` of the `feature/compiler-ast-dump` branch), which is what the tool uses to this
day.

### Renaming with verification (the base)

Renaming a **local**, a **param**, a **static**, a **memvar**, a **function**, a **method**, a **DSL word** and a
**directive marker** — each one by a compiler FACT, not by a text search. On 2026-07-11 the eight became **a single
`rename`** (you point, the tool works out what) — but the machinery underneath is from this foundation.

The contract that has held from day one: **the tool recompiles the project and compares the result.** If the
pcode/symbols do not add up, it **undoes everything**. A rename that "almost worked" does not exist.

### Reading the code without touching it (three reports)

```
$ hbrefactor unused-locals app.hbp
b.prg:12: local 'NNADA' declared but not used in COMSOBRAS
b.prg:13: local 'NSOBRA' is assigned but not used in COMSOBRAS
```
It tells **never used** apart from **assigned and never read** — they are different problems.

```
$ hbrefactor call-graph app.hbp
a.prg: MAIN -> DUPLA  [b.prg]
a.prg: MAIN -> QOUT   [external]
```
Who calls whom, **across modules**, with the origin of each target.

```
$ hbrefactor find-dynamic-calls app.hbp
a.prg:34: string 'Dupla' names a project function [b.prg]
a.prg:38: function DINAMICA uses & macros
```
**Every refactoring tool's blind spot**: names that become a call at runtime (a string that matches the name of one
of your functions; a zone of `&macro`). The tool **does not edit** those sites — it **shows** them, for you to
decide. That is the golden rule: *what cannot be verified is not edited.*

### Changing the structure

- **`extract-function`** — a range of lines becomes a new function; the variables that cross the boundary become
  parameters/return by data-flow analysis, not by guesswork. Inside a method, it extracts into a **method**.
- **`inline-local`** — the reverse: a local variable that merely wraps an expression disappears, and the expression
  goes back to its uses.
- **`reorder-params`** — swaps the order of a function's parameters **and of every call to it**, across all
  modules.

### And the rest of the base

`usages`/find-references (with `--json` in the LSP format), the **VSCode extension**, real `.hbp`/`.hbc` support via
**hbmk2** (no parallel project parser), and the string policy that still holds today: **detect and report, never
edit**.

**The honest limit, ever since:** the tool only edits what the compiler proves. A macro (`&var`), a name assembled at
runtime, a string that happens to match a symbol — all of that it **reports**. This is not a limitation to be fixed:
it is the line that separates refactoring from damage.

---

## Maintaining this file

One entry per release, written for the Harbour programmer. The HTML comment at the top is the **delta pointer**: it
names the last commit already described here. If one day the flow does not run, nobody has to guess what was left
behind — `git log <baseline>..HEAD` says exactly what is missing. After writing, advance the pointer.

The same goes for the [compiler's NEWS.md](../harbour-core/harbour/NEWS.md), which has its own pointer. Both are
maintained together by the `/update-manual` skill — **every repository with a new commit gets its own entry**.
