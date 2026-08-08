package suite

import (
	"strings"
	"testing"
)

// A work-area field of the same name in another module is not this memvar, and
// the rename goes through.
//
// This case was written asserting a REFUSAL, hours before the fix, because the
// tool rolled a correct rename back. The cause was in the proof, not the edit. A
// memvar rename is proved by comparing symbol tables and allowing exactly one
// substitution: every symbol under the old name must come out under the new one.
// That is right for a module that WAS edited. It was being applied to every
// module - and a module declaring a field of the same name keeps that symbol on
// purpose, so a correct program failed the check.
//
// The proof is now chosen by whether the module was edited:
//
//	edited     -> one symbol substituted, everything else identical
//	not edited -> pcode byte for byte identical
//
// The second is STRICTER, not looser. An untouched module has no business
// changing, so a difference there is a side effect and refusing is right.
//
// `expected/` states both halves: a.prg carries the new name, b.prg is byte for
// byte what it was.
func init() {
	registra("rename-private-with-homonym-field", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")

		if env.Exit != 0 {
			t.Fatalf("exit = %d, want 0 (detail: %s) - a field of the same name "+
				"belongs to a work area and has nothing to do with this memvar",
				env.Exit, env.Detail)
		}
		if env.Result.EditCount != 3 {
			t.Errorf("editCount = %d, want 3 (declaration + creation + use, a.prg only)",
				env.Result.EditCount)
		}
		for _, loc := range env.Result.Locations {
			if strings.HasSuffix(loc.URI, "b.prg") {
				t.Errorf("edited b.prg: the field there is not this variable")
			}
		}
	})
}
