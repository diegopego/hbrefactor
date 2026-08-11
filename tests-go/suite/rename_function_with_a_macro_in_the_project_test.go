package suite

import "testing"

// A macro evaluation lives in the same function being edited (line 6 assembles
// a name and calls it), and the rename goes through anyway.
//
// That is a decision, not an omission (Diego, 2026-07-27): macro evaluation is
// run time, a refactoring tool does not control it, and refusing every rename
// in every project that contains a `&` would refuse most Harbour code. The
// proof the tool does give is exact and unchanged - two edits, pcode
// byte-identical - and it never claimed to cover what runs.
//
// This case also pins the SILENCE that Diego chose on 2026-08-11. For two days
// the result carried a `reach` field listing every site in the project that
// resolves a name at run time. It came out: nothing connects those sites to
// THIS rename - a `Do( cNome )` in another module appeared in every rename of
// the project alike - and a line that always prints stops being read. That is
// a property of the project, and its home is the audit you run when you want
// (roadmap P37). The whole-envelope comparison is what keeps it out: if the
// field ever comes back, every rename case fails at once.
func init() {
	registra("rename-function-with-a-macro-in-the-project", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:10:10", "Duplica")

		if env.Status != "ok" {
			t.Fatalf("status = %q (%s), want ok - a macro does not veto a function rename", env.Status, env.Detail)
		}
		if env.Result.Proof != "pcode-identical" {
			t.Errorf("proof = %q, want pcode-identical", env.Result.Proof)
		}
		if env.Result.EditCount != 2 {
			t.Errorf("editCount = %d, want 2 (the call and the definition)", env.Result.EditCount)
		}
	})
}
