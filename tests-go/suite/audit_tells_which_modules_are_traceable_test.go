package suite

import "testing"

// The audit, and it answers one question per file: can this module be
// refactored on proof, or does it reach names that only exist while the
// program runs?
//
// Three modules on purpose, because two of them are the easy mistakes:
//
//	puro.prg     plain functions - traceable, and most code is this. Measured
//	             on Harbour's own source: 647 of 692 modules (93%) are clean.
//	classe.prg   a class, a method and a send. ALSO traceable: a message is
//	             dynamic dispatch by definition, it is in 41% of the core's
//	             modules, and the tool has handled it since B4f. Calling that
//	             "unfit for refactoring" would call OOP unfit and make the
//	             report worthless.
//	dinamico.prg `__mvGet( cNome )` and `&cExpr` - the two real ones, and each
//	             site is named with its line so you can go look.
//
// What the report is FOR (Diego, 2026-08-10): it is not a veto and it never
// changes what a rename does. It exists so a programmer can see where the
// dynamic code is and, if they want, move it into modules of its own - the way
// one runs a formatter. Everything it says comes from facts the compiler
// states: `dyn` on a call (ast-25/26) and a `&` the programmer wrote.
func init() {
	registra("audit-tells-which-modules-are-traceable", func(t *testing.T, p *Projeto) {
		env := p.Roda("find-dynamic-calls", "app.hbp")

		if env.Status != "ok" {
			t.Fatalf("status = %q (%s), want ok", env.Status, env.Detail)
		}
		if env.Result.Total != 3 || env.Result.Traceable != 2 {
			t.Errorf("summary = %d/%d, want 3 modules with 2 traceable",
				env.Result.Traceable, env.Result.Total)
		}
		for _, m := range env.Result.Modules {
			switch m.File {
			case "classe.prg":
				if !m.Traceable {
					t.Error("a class with a send is NOT unfit for refactoring")
				}
			case "puro.prg":
				if !m.Traceable {
					t.Error("puro.prg has nothing dynamic in it")
				}
			case "dinamico.prg":
				if m.Traceable || len(m.Sites) != 2 {
					t.Errorf("dinamico.prg: traceable=%v, %d site(s); want false and 2",
						m.Traceable, len(m.Sites))
				}
			}
		}
	})
}
