package suite

import (
	"strings"
	"testing"
)

// Two creators whose reaches cross - but every USE of this program has a
// determined binding, and the program proves it (run it: main:7 antes:7
// depois:9). The PRIVATE line CUTS Usa in two: the use before it sees the
// caller's variable, the use after it sees Usa's own. Statement order plus
// the single call path decide everything; nothing here depends on runtime
// data.
//
// This refusal is POLICY, permanent (Diego, 2026-08-08): re-creating a name
// the function already read is fragile code, and bad practice gets an honest
// refusal and no engineering beyond it - the statement-level analysis that
// could serve this pattern was designed, measured and consciously NOT built
// (roadmap P33, closed the day it opened; zero conditional PRIVATEs in the
// whole measurement corpus). If this case ever stops refusing, someone
// reopened that gate without revoking the policy - the tests' job is to make
// that impossible to do silently.
func init() {
	registra("refuse-rename-private-use-before-second-creator", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "p.hbp", "a.prg:5:12", "xNovo")

		reason, _ := env.Recusa()
		if reason != "memvar-has-more-than-one-creator" {
			t.Errorf("reason = %q, want memvar-has-more-than-one-creator", reason)
		}
		if !strings.Contains(env.Detail, "MAIN") || !strings.Contains(env.Detail, "USA") {
			t.Errorf("the refusal does not name both creators: %q", env.Detail)
		}
	})
}
