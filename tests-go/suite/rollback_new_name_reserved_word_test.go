package suite

import (
	"strings"
	"testing"
)

// ROLLBACK: o nome novo é uma reservada lida em UPPERCASE (`nIL` → `NIL`, e o
// Harbour é case-insensitive). A ferramenta EDITA, o compilador DO PROJETO
// recusa no fim do ciclo, e o fonte volta byte a byte — é o `expected/` igual
// ao `source/` que prova a volta.
//
// Este é o caso que justifica a morte do `NameAccepted`: quem diz que um nome
// não serve é o compilador do projeto, não uma lista nossa. O preço é que a
// recusa chega DEPOIS da edição; o ganho é que ela nunca é falso-negativo.
func init() {
	registra("rollback-new-name-reserved-word", func(t *testing.T, p *Projeto) {
		env := p.Roda("rename", "fix01.hbp", "a.prg:5:10", "nIL")

		if r, a := env.Recusa(); r != "compile-failed-rolled-back" || a != "stop-and-report" {
			t.Errorf("recusa = %q/%q, quero compile-failed-rolled-back/stop-and-report", r, a)
		}
		// os erros do compilador vêm em `diagnostics[]`, e não em prosa no
		// stderr: é o que o agente lê para RELATAR ao humano o motivo real.
		if len(env.Diagnostics) == 0 {
			t.Fatal("o rollback não trouxe os erros do compilador em diagnostics[]")
		}
		for _, d := range env.Diagnostics {
			if d.Code != "compiler-error" {
				t.Errorf("diagnóstico %q, quero compiler-error", d.Code)
			}
			if !strings.Contains(d.Detail, "a.prg") {
				t.Errorf("o diagnóstico não aponta o arquivo: %q", d.Detail)
			}
		}
	})
}
