package suite

import (
	"os/exec"
	"path/filepath"
	"reflect"
	"testing"
)

// A FUNCTION name in a directive's result, with module-scoped homonyms: three
// modules define `STATIC FUNCTION Remessa`, two include the header whose
// command calls it, one does not. Each application binds to ITS module's
// static - the same result text, a different function per module.
//
// This case used to be `refuse-...`, pinning a rollback that blamed f1 - the
// one module that never includes the header. P32 inverted it consciously: the
// bound set is a FACT (the modules whose ppApplications carry a rule writing
// the name, each defining its own static), so the rename drags all of them
// plus the header, and the proof is per module - edited modules must show the
// one-symbol swap, untouched modules must be byte-identical. f1 keeps its
// legitimate stranger, byte for byte (expected/ pins that half).
//
// The two entry points are one operation: the preview FROM THE HEADER's
// result previews exactly the set the definition-side rename applies. And the
// PROGRAM has the final word: built and run before and after the drag, its
// stdout must be byte-identical.
func init() {
	registra("rename-static-function-cited-by-directive", func(t *testing.T, p *Projeto) {
		p.Cria("app", "app2")
		antes := executa(t, p, "app")

		preview := p.Roda("rename", "p.hbp", "fn.ch:1:23", "RemessaB", "--dry-run")
		if preview.Exit != 0 || preview.Result.Verdict != "preview" {
			t.Fatalf("preview from the result side: exit %d verdict %q (detail: %s)",
				preview.Exit, preview.Result.Verdict, preview.Detail)
		}
		if len(preview.Edits) != 3 {
			t.Errorf("preview edits = %d, want 3 (two static definitions + the header)",
				len(preview.Edits))
		}

		applied := p.Roda("rename", "p.hbp", "f2.prg:9:17", "RemessaB")
		if applied.Exit != 0 {
			t.Fatalf("applied from f2's definition: exit %d (detail: %s)",
				applied.Exit, applied.Detail)
		}
		if applied.Result.Proof != "pcode-identical" {
			t.Errorf("proof = %q, want pcode-identical", applied.Result.Proof)
		}

		// the symmetry claim, stated as code: both entry points name the same places
		if !reflect.DeepEqual(preview.Result.Locations, applied.Result.Locations) {
			t.Errorf("the two entry points disagree on the edit set:\npreview: %v\napplied: %v",
				preview.Result.Locations, applied.Result.Locations)
		}

		// execution identity: the drag renamed three files, and the program
		// neither noticed nor could - same bytes on stdout
		if depois := executa(t, p, "app2"); depois != antes {
			t.Errorf("program output changed across the rename:\nbefore: %q\nafter:  %q",
				antes, depois)
		}
	})
}

// executa builds the fixture's program with hbmk2 (the official builder, same
// toolchain as everything else) and returns its stdout. The binary name is
// per call so before/after do not overwrite each other - both are declared
// with Cria, since the tool did not create them, this test did.
func executa(t *testing.T, p *Projeto, nome string) string {
	t.Helper()

	build := exec.Command(filepath.Join(hbBin(t), "hbmk2"),
		"p.hbp", "-o"+nome, "-gtcgi", "-q0")
	build.Dir = p.dir
	if saida, err := build.CombinedOutput(); err != nil {
		t.Fatalf("hbmk2 failed:\n%s", saida)
	}
	run := exec.Command(filepath.Join(p.dir, nome))
	run.Dir = p.dir
	saida, err := run.Output()
	if err != nil {
		t.Fatalf("the program did not run: %v", err)
	}
	return string(saida)
}
