package suite

import (
	"strings"
	"testing"
)

// A STATIC a directive writes renames like a LOCAL does - both sides, one step.
//
// The P27 delivered this for LOCAL only, and the refusal for anything else said
// "only a LOCAL binding can be proved byte-identical". That sentence was wrong,
// and a positive control is what showed it: the same STATIC renames fine when
// no directive is involved, with the same `pcode-identical` proof. What was
// missing was never the proof - it was the engine reaching the verb that
// already knew how to do it.
//
// So this case is the correction, and the reason it is worth a case of its own
// is that a STATIC is not scoped like a LOCAL. It is file-wide here, declared
// before the first function, and the site the directive binds lives inside
// Main. A per-function collector would find nothing; the engine has to ask the
// STATIC's own verb, which scopes by module.
//
// This case used to assert a refusal (P28 slice 1, delivered hours earlier).
// The verdict flipping from `refused` to `ok` is the slice landing. What keeps
// slice 1 covered is the memvar sibling, which still refuses - and still has to
// name the header while it does.
func init() {
	registra("rename-static-written-by-directive", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:3:8", "nTotal")

		if env.Exit != 0 {
			t.Fatalf("exit = %d, want 0 (detail: %s)", env.Exit, env.Detail)
		}
		if env.Result.Kind != "rule-written" {
			t.Errorf("kind = %q, want rule-written", env.Result.Kind)
		}
		if env.Result.Proof != "pcode-identical" {
			t.Errorf("proof = %q, want pcode-identical", env.Result.Proof)
		}

		var tocouCh, tocouPrg bool
		for _, loc := range env.Result.Locations {
			if strings.HasSuffix(loc.URI, "cmdlog.ch") {
				tocouCh = true
			}
			if strings.HasSuffix(loc.URI, "app.prg") {
				tocouPrg = true
			}
		}
		if !tocouCh || !tocouPrg {
			t.Errorf("edited .ch = %v, edited .prg = %v: both sides of the same "+
				"variable have to change together", tocouCh, tocouPrg)
		}

		// the declaration is OUTSIDE any function (file-wide static) and the use
		// the directive binds is INSIDE Main. Both are in the set, which is what
		// says the engine scoped by module and not by function.
		if env.Result.ApplicationSites != 2 || env.Result.DirectiveOccurrences != 1 {
			t.Errorf("sites = %d binding + %d directive, want 2 + 1",
				env.Result.ApplicationSites, env.Result.DirectiveOccurrences)
		}
	})
}
