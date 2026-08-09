package suite

import (
	"strings"
	"testing"
)

// The one mix the joint rename does not cover: the directive's result also
// binds a MEMVAR somewhere in the project.
//
// It is not an unfounded refusal and it is not a missing core fact - the
// binding IS known. What splits the memvar off is the proof: a memvar's name
// lives in the compiled program, so its rename is proved by symbol
// substitution, while locals and statics are proved by byte identity. One
// edit set cannot carry two proofs today.
//
// P31 item 2: the refusal carries the WHOLE map - every binding the scan
// found, module by module, both sides - instead of naming only the first
// memvar it tripped on. The reader learns the shape of the problem from the
// message alone.
func init() {
	registra("refuse-rename-when-directive-also-binds-a-memvar", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "u.prg:5:10", "nNovo")

		reason, action := env.Recusa()
		if reason != "directive-also-binds-a-memvar" || action != "stop-and-report" {
			t.Errorf("refusal = %q/%q, want directive-also-binds-a-memvar/stop-and-report",
				reason, action)
		}
		// the map names BOTH sides: the local the cursor meant, and the memvar
		// that splits off. A partial map sends the reader hunting through
		// modules; a blind refusal is worse.
		for _, lado := range []string{"local in COMLOCAL", "u.prg:5", "memvar in COMPRIVADA", "mv.prg:9"} {
			if !strings.Contains(env.Detail, lado) {
				t.Errorf("the map is missing %q: %q", lado, env.Detail)
			}
		}
	})
}
