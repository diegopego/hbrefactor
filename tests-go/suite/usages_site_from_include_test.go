package suite

import "testing"

// The name the programmer did NOT write in their own file - it lives in a
// `.ch` and reaches the module through a directive. Measured on the core's
// corpus: 40% of the sites in real Harbour code are like this, because Harbour
// is written on top of DSL.
//
// What the code below cannot say by itself, and is therefore here: a zero-width
// site is the honest signal for "I know this use exists, I do not know where to
// point". Spending it where the position DOES exist loses the only signal that
// tells the two cases apart - and that is what happened before P24.
func init() {
	registra("usages-site-from-include", func(t *testing.T, p *Projeto) {
		env := p.Roda("usages", "k.hbp", "nAcc", "--func", "Main")

		var noModulo, noHeader *Local
		for i := range env.Result.Locations {
			switch l := &env.Result.Locations[i]; {
			case l.URI == "file://<CWD>/k.ch":
				noHeader = l
			case l.Kind == "use (local)":
				noModulo = l
			}
		}

		// THE USE. `nAcc` does not appear on the line the programmer wrote - the
		// directive is what brings it - so the place to point at is its
		// application.
		if noModulo == nil {
			t.Fatal("no `use (local)`: the use the directive brings vanished from the report")
		}
		noModulo.Aponta(t, p.Linha("k.prg", noModulo.Range.Start.Line), "CMD_SOMA")

		// THE WRITTEN NAME. Whoever renames `nAcc` has to know it is also
		// written in the header - otherwise they edit half of it and break the
		// build.
		if noHeader == nil {
			t.Fatal("no site in k.ch: the name is written there and the report does not say so")
		}
		noHeader.Aponta(t, p.Linha("k.ch", noHeader.Range.Start.Line), "nAcc")
		if noHeader.Text == "" {
			t.Error("the header site has no preview: the IDE and the agent decide " +
				"by it without reopening the file")
		}
	})
}
