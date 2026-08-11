package suite

import "testing"

// The other half of the homonym rename. Its twin case
// (rename-method-homonym-with-declared-receiver) renames one of two classes
// that answer `Print`, because a fact places every send. Here nothing does:
// the class function has no declared return type, so `MyClass1():New()` says
// nothing about what it hands back and each send is `possible send (dynamic
// dispatch, receiver unknown)`.
//
// Homonymy is not, by itself, ambiguity - but THIS is ambiguity, and the
// refusal has to survive the capability that removed the other one. The
// refusal also has to say where it stopped: an agent that only reads "the
// rename is ambiguous" goes back to editing the text by hand.
func init() {
	registra("refuse-rename-method-homonym-receiver-unknown", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:14:8", "Show")

		if env.Status != "refused" {
			t.Fatalf("status = %q (%s), want refused", env.Status, env.Detail)
		}
		reason, action := env.Recusa()
		if reason != "send-receiver-not-a-fact" {
			t.Errorf("reason = %q - the refusal must name the missing fact, not the shape",
				reason)
		}
		if action != "stop-and-report" {
			t.Errorf("action = %q, want stop-and-report - no flag buys this, a "+
				"declared receiver does", action)
		}
	})
}
