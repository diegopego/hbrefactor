package suite

import (
	"strings"
	"testing"
)

// The memvar half of the same slice, and it is here because it is a SECOND call
// site, not a second idea.
//
// A PRIVATE fails differently from a STATIC - the name lives in the pcode symbol
// table, so the tool reports "the number of symbols/functions changed" instead
// of a byte difference. Different verb, different proof, and until now the same
// silence: no `diagnostics[]`, so the programmer could not tell that a header
// spelling the same name is what made it fail.
//
// One helper feeds both refusals, because both change for the same reason: if
// the fact "a directive applied here writes this name" ever changes shape, it
// changes in one place. That is the only kind of sharing this bought - the
// verbs themselves stay as different as they are.
//
// The sibling case covers STATIC. Neither would catch the other going silent,
// which is why both exist.
func init() {
	registra("refuse-rename-memvar-written-by-directive", func(t *testing.T, p *Projeto) {
		linha := p.Linha("cmdlog.ch", 0)
		env := p.Roda("rename", "app.hbp", "app.prg:7:12", "nTotal")

		reason, _ := env.Recusa()
		if reason != "verification-failed-rolled-back" {
			t.Errorf("reason = %q, want verification-failed-rolled-back", reason)
		}
		// the memvar proof is about SYMBOLS, not bytes - if this ever reads like
		// the static one, the two verbs have been quietly merged
		if !strings.Contains(env.Detail, "symbols/functions") {
			t.Errorf("detail = %q: a memvar's name is in the symbol table, and the "+
				"refusal should say so - it is not a byte comparison", env.Detail)
		}

		var aviso *Diagnostico
		for i := range env.Diagnostics {
			if env.Diagnostics[i].Code == "name-also-written-by-directive" {
				aviso = &env.Diagnostics[i]
			}
		}
		if aviso == nil {
			t.Fatal("no diagnostic naming the directive: this path used to refuse in " +
				"total silence, and the header is the reason it failed")
		}
		if aviso.Location == nil {
			t.Fatal("the diagnostic has no location")
		}
		aviso.Location.Aponta(t, linha, "nLinhas")
	})
}
