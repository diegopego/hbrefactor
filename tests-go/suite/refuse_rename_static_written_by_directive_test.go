package suite

import (
	"strings"
	"testing"
)

// A refusal outside the LOCAL path also has to say WHERE ELSE the name lives.
//
// The P27 renames a name a directive writes when it binds to a LOCAL. Bound to
// a STATIC it still refuses - and it used to refuse with nothing at all in
// `diagnostics[]`, which is the exact gap the P25 closed for locals and left
// open everywhere else. The programmer gets "the pcode changed" and no way to
// guess that a header is the reason.
//
// Here the header IS the reason, and the case can say so without hand-waving:
// the same rename succeeds when no directive writes the name (measured on the
// same shape of fixture), so the directive is what makes the difference.
//
// The verdict is deliberately NOT part of what this case changes. It stays
// `verification-failed-rolled-back`, the sources come back byte for byte, and
// only the telling improves. Making it succeed is the next slice (P28), and
// pinning the refusal here is what will make that slice visible when it lands.
func init() {
	registra("refuse-rename-static-written-by-directive", func(t *testing.T, p *Projeto) {
		linha := p.Linha("cmdlog.ch", 0)
		env := p.Roda("rename", "app.hbp", "app.prg:3:8", "nTotal")

		reason, _ := env.Recusa()
		if reason != "verification-failed-rolled-back" {
			t.Errorf("reason = %q, want verification-failed-rolled-back", reason)
		}

		var aviso *Diagnostico
		for i := range env.Diagnostics {
			if env.Diagnostics[i].Code == "name-also-written-by-directive" {
				aviso = &env.Diagnostics[i]
			}
		}
		if aviso == nil {
			t.Fatal("no diagnostic naming the directive: the tool KNOWS the header " +
				"writes this name and refuses without saying so - the programmer is " +
				"left with \"the pcode changed\"")
		}
		if !strings.Contains(aviso.Detail, "cmdlog.ch") {
			t.Errorf("the diagnostic does not name the file: %q", aviso.Detail)
		}
		if aviso.Location == nil {
			t.Fatal("the diagnostic has no location: naming a file without the position " +
				"makes the reader search for it")
		}
		// points at the word in the header, computed from the file - so the
		// assertion reads as "at nLinhas", never as a column number
		aviso.Location.Aponta(t, linha, "nLinhas")
	})
}
