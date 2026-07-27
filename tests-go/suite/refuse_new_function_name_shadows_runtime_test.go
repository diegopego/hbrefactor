package suite

import (
	"strings"
	"testing"
)

// MULTI-COMANDO, e os três são recusa: dar a uma função do projeto o nome de
// uma função do runtime Harbour sombreia a nativa em TODA chamada — inclusive
// nas que a ferramenta não vê. A recusa é `ask-human-then-retry`: é possível,
// falta consentimento (o `--force` é o portão).
//
// Os três comandos rodam sobre o MESMO projeto, em ordem. Como nenhum edita,
// cada um encontra o projeto no estado original — e é o `expected/`, igual ao
// `source/`, que prova isso ao final dos três.
func init() {
	registra("refuse-new-function-name-shadows-runtime", func(t *testing.T, p *Projeto) {
		// `hb_MilliSeconds` é o terceiro de propósito: ele NÃO está linkado no
		// binário da ferramenta, então reconhecê-lo prova que a fonte do fato é
		// o `harbour.hbx` do PROJETO — e não o que o hbrefactor por acaso
		// carrega dentro de si.
		for _, novo := range []string{"Len", "hb_ntos", "hb_MilliSeconds"} {
			env := p.Roda("rename", "fix01.hbp", "b.prg:19:10", novo)

			if r, a := env.Recusa(); r != "textual-refs-require-force" || a != "ask-human-then-retry" {
				t.Errorf("%s: recusa = %q/%q, quero textual-refs-require-force/ask-human-then-retry",
					novo, r, a)
			}
			// o aviso tem de NOMEAR a função pedida: uma recusa que não diz
			// qual nome colidiu não é acionável por quem a lê.
			if len(env.Diagnostics) != 1 || !strings.Contains(env.Diagnostics[0].Detail, novo) {
				t.Errorf("%s: o diagnóstico não nomeia a função pedida: %+v", novo, env.Diagnostics)
			}
		}
	})
}
