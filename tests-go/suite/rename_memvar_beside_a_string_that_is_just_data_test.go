package suite

import "testing"

// The cost of the heuristic, charged to the honest program. `"xCfg"` here is
// DATA - it labels the number being printed - and it happens to spell the
// memvar beside it. The dead string rule saw a literal equal to the name and
// demanded `--force` for a rename that touches nothing dynamic; the user's only
// way forward was a flag that means "I accept a proven risk", spent on no risk
// at all. Spend that flag often enough and it stops being read.
//
// So the case proves BOTH halves of the same change: the rename goes through
// with no diagnostics, and the string is still there afterwards, byte for byte.
// A string is data and the tool never edits it - not before, not now, and not
// under `--force` either.
func init() {
	registra("rename-memvar-beside-a-string-that-is-just-data", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:5:12", "xConf")

		if env.Status != "ok" {
			t.Fatalf("status = %q (%s), want ok", env.Status, env.Detail)
		}
		if len(env.Diagnostics) != 0 {
			t.Errorf("a data string should raise nothing: %+v", env.Diagnostics)
		}
		if env.Result.EditCount != 3 {
			t.Errorf("editCount = %d, want 3 (the MEMVAR, the PRIVATE and the read)", env.Result.EditCount)
		}
		if env.Result.Proof != "pcode-identical" {
			t.Errorf("proof = %q, want pcode-identical", env.Result.Proof)
		}
	})
}
