package suite

import "testing"

// Line 20 prints the label `"Mostra"`. Line 22 sends a message whose name was
// assembled at run time. Exactly one of them could reach the method being
// renamed, and until P36b the tool reported the OTHER one: it demanded
// `--force` because of the label, and never mentioned the send.
//
// Now the label raises nothing - a string is data, and its spelling is not a
// fact - and the rename goes through. Whether that `__objSendMsg` names THIS
// message is unknowable, so refusing would be inventing an answer.
//
// Where the send is reported instead: the audit (roadmap P37), which is a
// command you run when you want, not a line repeated on every rename.
func init() {
	registra("rename-method-beside-a-send-by-name", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:5:11", "Exibe")

		if env.Status != "ok" {
			t.Fatalf("status = %q (%s), want ok", env.Status, env.Detail)
		}
		if len(env.Diagnostics) != 0 {
			t.Errorf("the label string should raise nothing: %+v", env.Diagnostics)
		}
		if env.Result.Proof != "symbols-renamed" {
			t.Errorf("proof = %q, want symbols-renamed", env.Result.Proof)
		}
	})
}
