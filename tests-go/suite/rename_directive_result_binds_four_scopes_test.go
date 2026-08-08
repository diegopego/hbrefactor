package suite

import (
	"reflect"
	"testing"
)

// The right side of a directive is not ONE symbol - it is a template hole
// filled at each application site. This fixture makes the same `nReg` in the
// result bind to FOUR distinct variables: a local, a parameter, a
// function-scoped static, and a file-wide static in another module.
//
// The case pins two things at once, and they answer Diego's chain of
// 2026-08-08 ("if we have usages with scope, we have rename"):
//
//  1. the rename STARTING AT THE RIGHT SIDE (first command, dry-run) previews
//     exactly the same edit set as the rename starting at one of the bound
//     declarations (second command, applied). The two entry points are one
//     operation - measured, not asserted;
//  2. the drag is TOTAL and it is FORCED: the `.ch` text is shared, so all
//     four variables rename together or the build breaks. What does NOT move
//     is as important - the module that never includes the header, and the
//     homonym in a function that never uses the command, are byte for byte
//     intact in `expected/`.
func init() {
	registra("rename-directive-result-binds-four-scopes", func(t *testing.T, p *Projeto) {
		preview := p.Roda("rename", "p.hbp", "log.ch:1:29", "nNovo", "--dry-run")
		if preview.Exit != 0 || preview.Result.Verdict != "preview" {
			t.Fatalf("preview from the right side: exit %d verdict %q (detail: %s)",
				preview.Exit, preview.Result.Verdict, preview.Detail)
		}
		if len(preview.Edits) != 9 {
			t.Errorf("preview edits = %d, want 9 (8 binding sites + the header)", len(preview.Edits))
		}

		applied := p.Roda("rename", "p.hbp", "usa.prg:5:10", "nNovo")
		if applied.Exit != 0 {
			t.Fatalf("applied from the declaration: exit %d (detail: %s)", applied.Exit, applied.Detail)
		}
		if applied.Result.ApplicationSites != 8 || applied.Result.DirectiveOccurrences != 1 {
			t.Errorf("sites = %d + %d, want 8 + 1: local, param, function static and "+
				"file-wide static, all dragged by the shared header",
				applied.Result.ApplicationSites, applied.Result.DirectiveOccurrences)
		}

		// the symmetry claim, stated as code: both entry points name the same places
		if !reflect.DeepEqual(preview.Result.Locations, applied.Result.Locations) {
			t.Errorf("the two entry points disagree on the edit set:\npreview: %v\napplied: %v",
				preview.Result.Locations, applied.Result.Locations)
		}
	})
}
