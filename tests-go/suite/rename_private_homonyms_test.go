package suite

import (
	"strings"
	"testing"
)

// The homonym matrix for a dynamically scoped memvar, WITHOUT a directive.
//
// A PRIVATE is not lexical: it is created at runtime and every function the
// creator calls can see it - across modules. So "the same name" can mean five
// different things in one project, and the tool has to separate them by fact,
// never by spelling. These cases exist because the phase that came before them
// was all about preprocessor directives, and a matrix proved only there proves
// only there.
//
// Each case is a different way for a homonym to be NOT this variable, and none
// of them would catch another failing: the shadow is lexical in one, positional
// in another, module-scoped in a third, and in the last two the name is a real
// memvar that simply is not the same one.
//
// The tool renames the creator's module and leaves the homonym alone. What
// makes it non-trivial is that touching the homonym would still COMPILE - a
// consistent rename of a local or a param is invisible in pcode, so the oracle
// would bless the damage. The only thing standing between the user and a silent
// wrong edit is the tool asking the compiler what each name is bound to.
func init() {
	// (1) a LOCAL of the same name inside the creator's dynamic reach. It
	// SHADOWS the memvar: uses there are the local, not this variable.
	registra("rename-private-with-shadowing-local", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")
		exigeMemvarRenomeado(t, env, 3)
		semTocarOutroModulo(t, env)
	})

	// (2) a PARAMETER of the same name. Same conclusion, different mechanism -
	// the binding is positional, and nothing in the callee's text says "memvar".
	registra("rename-private-with-homonym-param", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")
		exigeMemvarRenomeado(t, env, 3)
		semTocarOutroModulo(t, env)
	})

	// (3) a STATIC of the same name in the other module. A static belongs to its
	// .prg, so it is a third distinct variable - and it is the one a rename by
	// name would most easily swallow, because it looks like a plain identifier.
	registra("rename-private-with-homonym-static-in-another-module", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")
		exigeMemvarRenomeado(t, env, 3)
		semTocarOutroModulo(t, env)
	})

	// (4) two creators. Which one a use sees depends on the EXECUTION PATH, and
	// that is not a compile-time fact - renaming "the" symbol would merge two
	// variables that only the runtime tells apart.
	registra("refuse-rename-private-with-two-creators", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")
		reason, action := env.Recusa()
		if reason != "memvar-has-more-than-one-creator" || action != "stop-and-report" {
			t.Errorf("refusal = %q/%q, want memvar-has-more-than-one-creator/stop-and-report",
				reason, action)
		}
		// the refusal names BOTH creators: without them the reader cannot check
		if !strings.Contains(env.Detail, "MAIN") || !strings.Contains(env.Detail, "USA") {
			t.Errorf("the refusal does not name both creators: %q", env.Detail)
		}
	})

	// (5) a use in a function the creator never reaches. It is a real memvar of
	// the same name, and a different one - editing it would be editing by
	// coincidence of spelling.
	registra("refuse-rename-private-used-outside-the-creator-scope", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")
		reason, _ := env.Recusa()
		if reason != "memvar-use-outside-creator-scope" {
			t.Errorf("reason = %q, want memvar-use-outside-creator-scope", reason)
		}
		if !strings.Contains(env.Detail, "SOLTA") {
			t.Errorf("the refusal does not name the function that made it refuse: %q",
				env.Detail)
		}
	})
}

func exigeMemvarRenomeado(t *testing.T, env Envelope, edits int) {
	t.Helper()
	if env.Exit != 0 {
		t.Fatalf("exit = %d, want 0 (detail: %s)", env.Exit, env.Detail)
	}
	if env.Result.Kind != "memvar" {
		t.Errorf("kind = %q, want memvar", env.Result.Kind)
	}
	if env.Result.EditCount != edits {
		t.Errorf("editCount = %d, want %d (MEMVAR + creation + use, creator's module only)",
			env.Result.EditCount, edits)
	}
}

// the homonym lives in b.prg, and b.prg must not appear in the edit set at all.
// `expected/` already proves the bytes; this proves the tool KNEW, rather than
// having edited and been lucky.
func semTocarOutroModulo(t *testing.T, env Envelope) {
	t.Helper()
	for _, loc := range env.Result.Locations {
		if strings.HasSuffix(loc.URI, "b.prg") {
			t.Errorf("edited b.prg (%s): the homonym there is a DIFFERENT variable, "+
				"and renaming it would still compile - which is exactly why nothing "+
				"but the compiler's binding can decide this", loc.URI)
		}
	}
}
