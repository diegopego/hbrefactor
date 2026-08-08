package suite

import (
	"testing"
)

// Indirect directives - Harbour's own doc/pp.txt: a rule whose RESULT defines
// another rule, the `EOC` trick included, plus a three-level chain
// (rule -> rule -> rule) in the same fixture.
//
// What makes them renameable is position genealogy: the generated rule is
// registered where it was BORN (the application line), but its tokens keep the
// line and column of the text the programmer TYPED inside the generating
// rule's result. So renaming the head of a generated rule edits the generating
// line - the only place that name exists in source - plus the use, and the
// `.ppo`/`.hrb` proof closes it.
//
// Both renames here go through the ordinary dsl path. No special casing for
// nesting depth: the third level works because each level's clone carries the
// positions of the one above, all the way to the line the user can see.
func init() {
	registra("rename-indirect-directive-heads", func(t *testing.T, p *Projeto) {
		// level 2: the head defined inside CREATECMD's result (pp.txt example)
		env := p.Roda("rename", "p.hbp", "ind.prg:9:4", "CMDNOVO")
		if env.Exit != 0 {
			t.Fatalf("level-2 rename: exit %d (detail: %s)", env.Exit, env.Detail)
		}
		exigeEdicaoNaLinha(t, env, 3, "the generating rule's line - the only "+
			"source the generated head has")

		// level 3: the deepest head of rule -> rule -> rule
		env = p.Roda("rename", "p.hbp", "ind.prg:12:4", "FUNDO")
		if env.Exit != 0 {
			t.Fatalf("level-3 rename: exit %d (detail: %s)", env.Exit, env.Detail)
		}
		exigeEdicaoNaLinha(t, env, 4, "the top of the three-level chain")
	})
}

func exigeEdicaoNaLinha(t *testing.T, env Envelope, linha1 int, motivo string) {
	t.Helper()
	for _, l := range env.Result.Locations {
		if l.Range.Start.Line == linha1-1 {
			return
		}
	}
	t.Errorf("no edit on line %d (%s); locations: %v", linha1, motivo, env.Result.Locations)
}
