package suite

import "testing"

// Line 20 prints the label `"Mostra"`. Line 22 sends a message whose name was
// assembled at run time. Exactly one of them can reach the method being
// renamed, and until P36b the tool reported the OTHER one - it demanded
// `--force` because of the label, and never mentioned the send.
//
// Now the label raises nothing (a string is data; its spelling is not a fact)
// and the send is stated, with its line, because the compiler is the one
// saying that `__objSendMsg` resolves a message name at run time. The rename
// still goes through: whether that call names THIS message is unknowable, and
// a refusal would be inventing an answer. Declaring is the honest half.
//
// Two functions of that family were measured and deliberately left unmarked,
// and this fixture is why the second one was caught: `__objHasMsg` is emitted
// by hbclass.ch inside the class-creation sequence, so marking it reported a
// run-time door at the `ENDCLASS` line of every class ever written.
func init() {
	registra("rename-method-declares-a-send-by-name", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:5:11", "Exibe")

		if env.Status != "ok" {
			t.Fatalf("status = %q (%s), want ok", env.Status, env.Detail)
		}
		if len(env.Diagnostics) != 0 {
			t.Errorf("the label string should raise nothing: %+v", env.Diagnostics)
		}
		if env.Result.Reach == nil || env.Result.Reach.Complete {
			t.Fatalf("reach does not declare the send by name: %+v", env.Result.Reach)
		}
		if len(env.Result.Reach.Runtime) != 1 {
			t.Fatalf("want exactly the send site, got %+v", env.Result.Reach.Runtime)
		}
		if s := env.Result.Reach.Runtime[0]; s.Line != 22 && s.Line != 21 {
			t.Errorf("reach points at line %d, want the __objSendMsg call", s.Line)
		}
	})
}
