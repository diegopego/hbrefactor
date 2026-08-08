package suite

import (
	"strings"
	"testing"
)

// Two STATICs of the same name in one file, and NO directive anywhere.
//
// Harbour is happy with a file-wide `STATIC nTotal` and a `STATIC nTotal` inside
// one function of the same `.prg`. They are two ordinary, distinct variables,
// and Diego's point when this was found is that the shape is common - what is
// rare, and bad practice, is a directive being involved.
//
// The tool refused BOTH directions, saying they were different variables. True,
// and beside the point: your cursor already says which one you mean. The
// compiler reports them apart too - a file-wide static is declared in the
// module's own pseudo-function, a function static in that function, each with
// its own line and column. The fact was there; the dispatch dropped it and sent
// only the function NAME onwards, which cannot express "the file-wide one".
//
// The pair is what makes it a test. Renaming the function-scoped one must leave
// the file-wide alone, and renaming the file-wide one must leave the
// function-scoped alone - and each direction would pass while the other is
// broken, because they take different branches of the dispatch. `expected/`
// states the halves that must NOT move.
func init() {
	registra("rename-static-of-function-beside-a-file-wide-homonym", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "a.hbp", "a.prg:13:11", "nParcial")
		exigeStatic(t, env, 3)
		// the file-wide declaration is on line 1: it must not be in the edit set
		for _, l := range env.Result.Locations {
			if l.Range.Start.Line == 0 {
				t.Errorf("edited line 1 - that is the file-wide static, a different variable")
			}
		}
	})

	registra("rename-file-wide-static-beside-a-function-homonym", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "a.hbp", "a.prg:1:8", "nGeral")
		exigeStatic(t, env, 3)
		// the function-scoped declaration is on line 13
		for _, l := range env.Result.Locations {
			if l.Range.Start.Line == 12 {
				t.Errorf("edited line 13 - that is Outra's own static, a different variable")
			}
		}
	})
}

func exigeStatic(t *testing.T, env Envelope, edits int) {
	t.Helper()
	if env.Exit != 0 {
		t.Fatalf("exit = %d, want 0 (detail: %s) - two STATICs of the same name in one "+
			"file are ordinary Harbour, and the cursor says which one", env.Exit, env.Detail)
	}
	if env.Result.Kind != "static" {
		t.Errorf("kind = %q, want static", env.Result.Kind)
	}
	if env.Result.EditCount != edits {
		t.Errorf("editCount = %d, want %d (declaration + its two uses)", env.Result.EditCount, edits)
	}
	if strings.Contains(env.Detail, "more than one place") {
		t.Errorf("still refusing as ambiguous: %q", env.Detail)
	}
}
