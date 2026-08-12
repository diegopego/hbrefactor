package suite

import (
	"path/filepath"
	"strings"
	"testing"
)

// `Lantern` and `Compass` both hold a `VAR cInscription` and both answer
// `Engrave`. What moves here is the VAR, and it holds a STRING - which is the
// first thing this case pins: a VAR holding a primitive value NEVER needs a
// type annotation. The content of a primitive does not participate in
// dispatch, so there is nothing about it for a declaration to say.
//
// Second: `AS CLASS` never goes on the VAR being renamed. When a type
// annotation is needed at all, it goes on the OBJECT variables along the path
// to the member - never on the member that is the target of the rename.
//
// Third: here the path is proven by the CONSTRUCTOR/Self declared channel -
// `LOCAL oLantern := Lantern():New()` in Main, and `Self:`/`::` inside each
// method body - so the whole project carries ZERO annotations, and the rename
// of a homonym string VAR still edits only the class it was asked about and
// proves the other class's sends dispatch elsewhere (`excluded`).
//
// Four sites move, all of them Lantern's: the declaration, the read through
// `Self:`, and in Main the write and the read through the constructor-typed
// local. Compass's declaration and its two sends must come out byte-identical
// - and they are not skipped for lack of a fact, they are skipped because a
// fact places them somewhere else. On this same project `usages
// Lantern:cInscription` says it in words: `excluded send within the declared
// class graph (dispatches to COMPASS:CINSCRIPTION)` for those two, against
// `confirmed send (receiver class LANTERN via declared types)` for the ones
// that move. Note what "declared" means there - the channel, not any text in
// the file, because there is none.
func init() {
	registra("rename-data-string-homonym-zero-annotations", func(t *testing.T, p *Projeto) {
		// the premise of the case, held before and after the rename
		noAnnotationsAnywhere(t, p)

		env := p.Roda("rename", "app.hbp", "app.prg:8:8", "cEpigraph")

		if env.Status != "ok" {
			t.Fatalf("status = %q (%s), want ok", env.Status, env.Detail)
		}
		if env.Result.Kind != "data" {
			t.Errorf("kind = %q, want data - the target is a VAR, not a method", env.Result.Kind)
		}
		if env.Result.EditCount != 4 {
			t.Errorf("editCount = %d, want 4 (the declaration, the `Self:` read, "+
				"and the write and the read in Main)", env.Result.EditCount)
		}
		if env.Result.Proof != "symbols-renamed-in-class" {
			t.Errorf("proof = %q, want symbols-renamed-in-class - Compass goes on "+
				"answering the old message, so this is NOT a whole-project rename",
				env.Result.Proof)
		}
		// the count of what was left alone is the other half of the claim: two
		// sends were placed elsewhere, not two sends the tool gave up on
		if !strings.Contains(env.Detail, "2 sends proven to dispatch elsewhere") {
			t.Errorf("detail = %q, want it to report the 2 sends left untouched", env.Detail)
		}

		// Compass's three lines are the point of the case (0-based, as a range is)
		theirs := map[int]string{
			20: "the `VAR cInscription` of Compass",
			29: "the `::cInscription` inside Compass:Engrave",
			38: "the `oCompass:cInscription :=` in Main",
		}
		for _, loc := range env.Result.Locations {
			if what, ok := theirs[loc.Range.Start.Line]; ok {
				t.Errorf("an edit landed on %s - a send proven to dispatch elsewhere was touched", what)
			}
		}
		if l := p.Linha("app.prg", 20); !strings.Contains(l, "cInscription") {
			t.Errorf("Compass's own member was renamed too: %q", l)
		}
	})
}

// The premise of the case, and its durable guard: not one line of this project
// - before the rename or after it - declares a type. Should a later edit ever
// "help" the fixture by annotating it, the case would stop proving what its
// name says, so it fails here instead.
func noAnnotationsAnywhere(t *testing.T, p *Projeto) {
	t.Helper()

	for _, sub := range []string{"source", "expected"} {
		for name, text := range arvore(t, filepath.Join(p.art, sub)) {
			for _, annotation := range []string{"AS CLASS", "_HB_MEMBER"} {
				if strings.Contains(strings.ToUpper(text), annotation) {
					t.Errorf("%s/%s carries %q - this case exists to prove the rename "+
						"needs none of it", sub, name, annotation)
				}
			}
		}
	}
}
