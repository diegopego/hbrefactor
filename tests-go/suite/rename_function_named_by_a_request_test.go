package suite

import "testing"

// `REQUEST Alvo` names the function in text, on a line the rename never
// touched. The verifier caught it every time - the module still declared the
// old symbol, so the pcode comparison failed and everything rolled back - but
// what reached the user was `the number of symbols/functions changed`, which
// says nothing about a REQUEST on line 1. Safe and unreadable.
//
// The site is a fact like any other site: the parser knows which token spells
// that name, exactly as it knows the token of a call or of an assignment
// (ast-21's location stack). Published, it is edited, and the rename that used
// to be impossible becomes ordinary - three edits, pcode byte-identical.
func init() {
	registra("rename-function-named-by-a-request", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:9:10", "Destino")

		if env.Status != "ok" {
			t.Fatalf("status = %q (%s), want ok", env.Status, env.Detail)
		}
		if env.Result.EditCount != 3 {
			t.Errorf("editCount = %d, want 3 (the REQUEST, the call, the definition)", env.Result.EditCount)
		}
		if env.Result.Proof != "pcode-identical" {
			t.Errorf("proof = %q, want pcode-identical", env.Result.Proof)
		}
		// the REQUEST line is the one that used to be left behind. The range of
		// an EDIT covers the old name where it stood, so it is the line that is
		// asserted here - Aponta compares against the file as it is now, which
		// is the right tool for a reported site and the wrong one for an edited
		// one.
		if l := env.Result.Locations[0].Range.Start.Line; l != 0 {
			t.Errorf("the first edited site is on line %d, want the REQUEST on line 0", l)
		}
	})
}
