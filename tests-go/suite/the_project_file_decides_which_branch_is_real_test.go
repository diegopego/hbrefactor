package suite

import "testing"

// One source, two project files, two different programs. `#ifdef MODO_NOVO`
// gives `Calcula` two bodies, and which one exists is decided by the `.hbp` -
// `-DMODO_NOVO` or not.
//
// The tool follows the project file, and that is the whole specification of
// this limit (Diego, 2026-08-11): "o .hbp, .hbc, .hbm já devem conter as flags
// de compilação, portanto o refactor vai operar em cima disso (...) pois é isto
// que o compilador processa e o compilador é a fonte da ast". A programmer who
// builds several configurations from one source is an exception and knows it;
// what the tool owes them is not silence but a statement.
//
// So the rename edits the branch this configuration compiles, and `scope` says
// the other one exists, where it is, and what defines it:
//
//	"scope": { "complete": false,
//	           "unseen": [ { "file": "app.prg", "line": 9, "cond": "MODO_NOVO" } ] }
//
// Both commands are dry runs on purpose: `expected/` equal to `source/` proves
// the second sees the same file the first did, so the two verdicts are about
// the configuration and nothing else.
func init() {
	registra("the-project-file-decides-which-branch-is-real", func(t *testing.T, p *Projeto) {
		sem := p.Roda("rename", "sem.hbp", "app.prg:15:10", "Computa", "--dry-run")
		com := p.Roda("rename", "com.hbp", "app.prg:9:10", "Computa", "--dry-run")

		for nome, env := range map[string]Envelope{"sem.hbp": sem, "com.hbp": com} {
			if env.Status != "ok" {
				t.Fatalf("%s: status = %q (%s)", nome, env.Status, env.Detail)
			}
			if env.Result.Scope == nil || env.Result.Scope.Complete {
				t.Errorf("%s: scope does not declare the branch left out: %+v", nome, env.Result.Scope)
			}
		}
		// the second edit is the definition, and it is a DIFFERENT line in each
		// configuration - which is the point
		if l := sem.Result.Locations[1].Range.Start.Line; l != 14 {
			t.Errorf("without the flag the definition is on line 15 (0-based 14), got %d", l)
		}
		if l := com.Result.Locations[1].Range.Start.Line; l != 8 {
			t.Errorf("with -DMODO_NOVO the definition is on line 9 (0-based 8), got %d", l)
		}
	})
}
