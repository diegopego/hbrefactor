package suite

import (
	"strings"
	"testing"
)

// The one mix the joint rename does not cover: the directive's result also
// binds a MEMVAR somewhere in the project.
//
// It is not an unfounded refusal and it is not a missing core fact - the
// binding IS known (this very message proves it, naming function, module and
// line). What splits the memvar off is the proof: a memvar's name lives in the
// compiled program, so its rename is proved by symbol substitution, while
// locals and statics are proved by byte identity. One edit set cannot carry
// two proofs today. P31 keeps this as a work item; until then the refusal has
// a code of its own, because `unclassified` is indistinguishable from a code
// nobody thought about.
func init() {
	registra("refuse-rename-when-directive-also-binds-a-memvar", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "u.prg:5:10", "nNovo")

		reason, action := env.Recusa()
		if reason != "directive-also-binds-a-memvar" || action != "stop-and-report" {
			t.Errorf("refusal = %q/%q, want directive-also-binds-a-memvar/stop-and-report",
				reason, action)
		}
		// the refusal must carry the map's first entry: WHERE the memvar binds.
		// A blind refusal here would send the reader hunting through modules.
		if !strings.Contains(env.Detail, "COMPRIVADA") || !strings.Contains(env.Detail, "mv.prg") {
			t.Errorf("the refusal does not name the memvar binding: %q", env.Detail)
		}
	})
}
