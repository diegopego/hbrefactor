package suite

import "testing"

// Two PRIVATE creators of the same name whose dynamic reaches are DISJOINT:
// ProcA's private lives through UsaUm (a.prg + c.prg), ProcB's lives only in
// b.prg, and Main sits above both, reached by neither. The tool used to
// refuse this with "bindings depend on the execution path" - which is false
// here: no function ever runs under both creators, so every use binds to
// exactly one of them, at compile time (P29; the refusal survives where the
// reaches CROSS - the pre-existing two-creators case pins that half).
//
// The cursor names the chain: pointing at ProcA's creator renames ProcA's
// chain - the PRIVATE, its uses, and the MEMVAR declarations of the chain's
// modules, REPLACED (not appended) so each edited module is a one-symbol
// substitution the existing proof already covers. b.prg and main.prg are
// byte-for-byte intact in expected/. And the program has the final word:
// built and run before and after, stdout identical.
func init() {
	registra("rename-private-with-disjoint-creators", func(t *testing.T, p *Projeto) {
		p.Cria("app", "app2")
		antes := executa(t, p, "app")

		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")
		if env.Exit != 0 {
			t.Fatalf("exit = %d, want 0 (detail: %s)", env.Exit, env.Detail)
		}
		if env.Result.Proof != "pcode-identical" {
			t.Errorf("proof = %q, want pcode-identical", env.Result.Proof)
		}
		if env.Result.EditCount != 4 {
			t.Errorf("editCount = %d, want 4 (MEMVAR + creator in a.prg, MEMVAR + use in c.prg)",
				env.Result.EditCount)
		}

		if depois := executa(t, p, "app2"); depois != antes {
			t.Errorf("program output changed across the rename:\nbefore: %q\nafter:  %q",
				antes, depois)
		}
	})
}
