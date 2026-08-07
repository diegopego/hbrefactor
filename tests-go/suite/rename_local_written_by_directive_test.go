package suite

import (
	"strings"
	"testing"
)

// Renaming a LOCAL that a directive also WRITES edits both sides, in one step.
//
// A `#xcommand CMD_LOG` spells `nLinhas` in its result, so the header writes
// that name into every module that uses the command, and the compiler binds it
// to the LOCAL of whoever used it. Two sides of one variable. The programmer
// sees only the `LOCAL nLinhas` in his own `.prg` and renames it - the most
// natural refactoring there is, and nothing in his file warns about the header.
//
// This case used to prove a REFUSAL. The tool edited the module, recompiled,
// the pcode changed, and it rolled back (correct), and the P25 taught it to at
// least NAME the header in `diagnostics[]` instead of only saying "the pcode
// changed". The P27 makes the refusal unnecessary: the header is one more file
// of what this project compiles, so it is edited with the module and the whole
// thing is proved byte-identical. The verdict flipping from `refused` to `ok`
// IS the phase.
//
// What holds it honest is the negative half, which lives in the sibling case:
// a homonymous local in a function that never uses the command is NOT touched.
// The tool does not rename by name - it renames what the directive BINDS, and
// the binding is a fact the compiler stamped on the site (`occurrences[].app`).
func init() {
	registra("rename-local-written-by-directive", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:5:10", "nTotalLinhas")

		if env.Exit != 0 {
			t.Fatalf("exit = %d, want 0 - the rename has to succeed now, not explain "+
				"why it cannot", env.Exit)
		}
		res := env.Result
		if res.Kind != "rule-written" {
			t.Errorf("kind = %q, want rule-written", res.Kind)
		}
		if res.Proof != "pcode-identical" {
			t.Errorf("proof = %q, want pcode-identical - the whole point is that the "+
				"two sides changed TOGETHER and the compiler saw no difference", res.Proof)
		}

		// the edit set spans BOTH files: the module and the header. Named in
		// code, not by counting - the header is the side that used to be
		// unreachable, and a passing count could hide it missing.
		var tocouCh, tocouPrg bool
		for _, loc := range res.Locations {
			if strings.HasSuffix(loc.URI, "cmdlog.ch") {
				tocouCh = true
			}
			if strings.HasSuffix(loc.URI, "app.prg") {
				tocouPrg = true
			}
		}
		if !tocouCh || !tocouPrg {
			t.Errorf("edited .ch = %v, edited .prg = %v: the rename has to cover both "+
				"sides of the same variable", tocouCh, tocouPrg)
		}

		// no CONSENT flag was needed. The directive is edited because the
		// project compiles it; asking permission for that would be a rule about
		// the file's EXTENSION - renaming a declaration used across several
		// modules of the same project never asks either (case 74b). `--json` is
		// the harness's, not the case's (spec § 4).
		for _, a := range env.Argv {
			if strings.HasPrefix(a, "--") && a != "--json" {
				t.Errorf("argv carries the flag %q - this case exists to state that "+
					"no consent flag is needed: %v", a, env.Argv)
			}
		}

		// and `expected/` (hand-written) is what proves the RESULT: both files
		// carry the new name, the .hbp is untouched. The harness compares it.
	})
}
