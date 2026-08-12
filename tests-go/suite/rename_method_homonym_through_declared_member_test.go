package suite

import "testing"

// The consolidated model separates TWO facts, and this case is where the
// second one is written down.
//
// MEMBERSHIP - "oPrincipal is a member of Composicao" - is free: `CREATE CLASS`
// already emits it, which is also why a `CONSTRUCTOR` costs no text at all
// (the type it declares IS the class of the block, whose name is right there).
// `LOCAL oCli := Composicao():New()` needs not one annotation.
//
// CONTENT - "oPrincipal HOLDS a Trilho" - is not free. `Trilho` is a THIRD
// class whose name is nowhere inside the `CREATE CLASS Composicao` block: it
// exists only in the assignments, which are method bodies. Nothing in the
// preprocessor can emit a fact that is not in its input, so someone has to
// write the content type. Here it is written in Form B.
//
// FORM B is the `_HB_MEMBER <name>() AS CLASS <Cls>` line placed AFTER the
// `ENDCLASS`. It compiles TODAY, with zero change to the core, and it leaves
// the whole `CREATE CLASS ... ENDCLASS` byte-identical to what it was.
//   - the PARENTHESES are mandatory: a member getter is a message, and the
//     grammar reaches this line through the method rule. Without them the
//     compiler stops with a syntax error at `AS`.
//   - the GROUP form (`_HB_MEMBER { AS CLASS Trilho oPrincipal }`) must NOT be
//     used: the group carries the type but the per-item lookup finds no class
//     name, so the class is LOST and the compiler warns "Class '(null)' not
//     known in declaration of 'OPRINCIPAL'" - which under `-es2` is a project
//     that no longer builds.
//
// THE TYPE OF THE PATH is what the rename then buys. `oCli:oPrincipal:Mostra()`
// is resolved by walking the declared CONTENT type of each member of the chain,
// so the rename traverses it and edits the send. The textually identical
// `oCli:oReserva:Mostra()` walks the same kind of chain to the OTHER class, is
// proven to dispatch to VAGAO:MOSTRA, and comes out byte-for-byte untouched -
// `excluded`, not "skipped for safety".
//
// Three sites move: Trilho's declaration, Trilho's implementation, and the one
// send whose path is declared to end in a Trilho. Everything Vagao owns, and
// the send that reaches it, must survive unchanged.
//
// Take the two `_HB_MEMBER` lines away and the same rename REFUSES - "the send
// at app.prg:51 does not resolve to a receiver". The declared content type is
// what carries this case; it is not decoration.
func init() {
	registra("rename-method-homonym-through-declared-member", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "app.hbp", "app.prg:17:8", "Exibe")

		if env.Status != "ok" {
			t.Fatalf("status = %q (%s), want ok", env.Status, env.Detail)
		}
		if env.Result.EditCount != 3 {
			t.Errorf("editCount = %d, want 3 (declaration, implementation, the send "+
				"through oPrincipal)", env.Result.EditCount)
		}
		if env.Result.Proof != "symbols-renamed-in-class" {
			t.Errorf("proof = %q, want symbols-renamed-in-class - what was proven is a "+
				"rename INSIDE one class, not a whole-project symbol rename", env.Result.Proof)
		}
		// the send reached through the other member is the point of the case:
		// no edit may land on line 54 (1-based), where `oCli:oReserva:Mostra()`
		// is written
		for _, loc := range env.Result.Locations {
			if loc.Range.Start.Line == 53 {
				t.Errorf("an edit landed on oCli:oReserva:Mostra() - the excluded send was touched")
			}
		}
		if linha := p.Linha("app.prg", 53); linha != "   oCli:oReserva:Mostra()" {
			t.Errorf("the excluded send reads %q - it had to stay byte-for-byte", linha)
		}
	})
}
