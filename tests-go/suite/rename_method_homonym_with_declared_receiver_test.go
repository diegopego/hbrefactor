package suite

import "testing"

// `MyClass1` and `MyClass2` both answer `Print`. Until now that alone made the
// rename refuse: "'Print' is also a member of: MYCLASS2 - a send is dynamic
// dispatch, the rename is ambiguous".
//
// But in the same project, in the same run, `usages MyClass1:Print` already
// answers `confirmed send (receiver declared AS CLASS MYCLASS1)` for one line
// and `excluded send within the declared class graph (dispatches to
// MYCLASS2:PRINT)` for the next. The fact was there; the rename never asked
// for it.
//
// So it asks now, site by site, through the same functions the query uses -
// and homonymy stops being, by itself, ambiguity. What the rename still
// refuses is a send it cannot place: that is real ambiguity, and it stays.
//
// The three sites that move are MyClass1's declaration, its implementation and
// the one send whose receiver is declared to be a MyClass1. `c2:Print()` and
// everything MyClass2 owns must come out byte-identical.
func init() {
	registra("rename-method-homonym-with-declared-receiver", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:14:8", "Show")

		if env.Status != "ok" {
			t.Fatalf("status = %q (%s), want ok", env.Status, env.Detail)
		}
		if env.Result.EditCount != 3 {
			t.Errorf("editCount = %d, want 3 (declaration, implementation, one send)",
				env.Result.EditCount)
		}
		if env.Result.Proof != "symbols-renamed-in-class" {
			t.Errorf("proof = %q, want symbols-renamed-in-class - the whole-project "+
				"symbol rename is NOT what was proven here", env.Result.Proof)
		}
		// the send that was left behind is the point of the case: no edit may
		// land on line 39 (1-based), where `c2:Print()` is written
		for _, loc := range env.Result.Locations {
			if loc.Range.Start.Line == 38 {
				t.Errorf("an edit landed on c2:Print() - the excluded send was touched")
			}
		}
	})
}
