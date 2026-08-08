package suite

import "testing"

// No directive anywhere - just two modules, each with its own STATIC FUNCTION
// Remessa. Renaming g2's used to roll back blaming g1: the old verification
// demanded the symbol swap in EVERY module, and g1's legitimate stranger kept
// the old name. The per-module proof (P32) states what is actually true:
// the edited module shows the one-symbol swap, the untouched module is
// byte-for-byte identical - which expected/ pins.
func init() {
	registra("rename-static-function-beside-module-homonym", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "g2.prg:7:17", "RemessaB")

		if env.Exit != 0 {
			t.Fatalf("exit %d (detail: %s)", env.Exit, env.Detail)
		}
		if env.Result.Proof != "pcode-identical" {
			t.Errorf("proof = %q, want pcode-identical", env.Result.Proof)
		}
		if env.Result.EditCount != 2 {
			t.Errorf("editCount = %d, want 2 (call + definition, g2 only)", env.Result.EditCount)
		}
	})
}
