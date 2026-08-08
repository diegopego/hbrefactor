package suite

import "testing"

// The other STATIC scope, and it is a different scope, not a variation.
//
// The sibling case renames a file-wide STATIC - declared before any function,
// so the collector has to sweep the whole module. This one is declared INSIDE
// Main, and its reach is that function's span. Same verb, opposite half of the
// same branch, and nothing about the file-wide case would notice if this one
// broke.
//
// The negative half is what makes it worth the fixture: `Outra()` declares a
// `LOCAL nLinhas` and never uses the command. It is a different variable, and
// renaming it would compile perfectly - a consistent rename of a local is
// invisible in pcode, so the oracle would bless the damage. It is left alone
// because the tool follows what the directive BINDS, and `Outra()` has no site
// the directive wrote. `expected/` keeps the old name on lines 16 and 18 on
// purpose.
func init() {
	registra("rename-static-of-function-written-by-directive", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:5:11", "nTotal")

		if env.Exit != 0 {
			t.Fatalf("exit = %d, want 0 (detail: %s)", env.Exit, env.Detail)
		}
		if env.Result.Kind != "rule-written" || env.Result.Proof != "pcode-identical" {
			t.Errorf("kind/proof = %q/%q, want rule-written/pcode-identical",
				env.Result.Kind, env.Result.Proof)
		}
		// two sites, not four: the homonym in Outra() is a different variable
		if env.Result.ApplicationSites != 2 {
			t.Errorf("applicationSites = %d, want 2 - a homonym in a function that "+
				"never uses the command is NOT this variable, and editing it would "+
				"still compile", env.Result.ApplicationSites)
		}
	})
}
