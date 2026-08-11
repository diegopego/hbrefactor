package suite

import (
	"strings"
	"testing"
)

// O envelope da CLI (schema cli-2) como TIPO, para o caso afirmar sobre ele com
// o compilador junto: `env.Result.EditCoutn` não compila, e um campo que o
// contrato não tem não chega a virar teste verde.
//
// A COMPARAÇÃO não passa por aqui de propósito (ver Projeto.relatado): tipo
// descarta o campo que não conhece, e campo novo não previsto é exatamente o
// que a comparação com outputs.json existe para pegar.

type Posicao struct {
	Line      int `json:"line"`
	Character int `json:"character"`
}

type Intervalo struct {
	Start Posicao `json:"start"`
	End   Posicao `json:"end"`
}

type Local struct {
	URI   string    `json:"uri"`
	Range Intervalo `json:"range"`
	Kind  string    `json:"kind,omitempty"`
	Owner string    `json:"owner,omitempty"`
	// `certainty` é o que separa esta ferramenta de um grep: um sítio
	// `confirmed` veio da compilação; qualquer outro valor é a ferramenta
	// dizendo que NÃO provou, e é o que o caso de `usages` precisa afirmar.
	Certainty string `json:"certainty,omitempty"`
	Text      string `json:"text,omitempty"`
}

type Diagnostico struct {
	Code     string `json:"code"`
	Severity string `json:"severity"`
	Location *Local `json:"location"`
	Detail   string `json:"detail"`
}

// Escopo é o que o veredito de uma palavra de DSL diz sobre o que ele NÃO viu:
// o pp não é o compilador, e um sítio dentro de um ramo que a compilação pulou
// não foi visto por ninguém. `complete: false` com `unseen` cheio é a ferramenta
// dizendo até onde a prova alcança, em vez de afirmar sobre a árvore inteira.
type Escopo struct {
	Complete bool     `json:"complete"`
	Unseen   []string `json:"unseen"`
}

// [REMOVIDO 2026-08-11, decisão do Diego] Aqui viveram `Alcance`/`SitioRuntime`,
// o tipo do campo `reach` do result. O campo saiu do produto: ele listava
// sítios do PROJETO que resolvem nome em run time, sem fato nenhum que os
// ligasse ao rename pedido, e por isso saía igual em toda invocação. Essa
// informação é da auditoria (roadmap P37), que se roda quando se quer.
// O tipo sai junto de propósito: com ele fora, um `reach` que volte não
// compila num caso, em vez de passar despercebido.

// A forma do result é POR COMANDO — um rename não tem os campos de um usages,
// e o rename de palavra de DSL tem os seus.
type Resultado struct {
	Verdict   string  `json:"verdict,omitempty"`
	Kind      string  `json:"kind,omitempty"`
	Old       string  `json:"old,omitempty"`
	New       string  `json:"new,omitempty"`
	EditCount int     `json:"editCount,omitempty"`
	Proof     string  `json:"proof,omitempty"`
	Locations []Local `json:"locations,omitempty"`

	// só no rename de palavra de DSL
	Scope                *Escopo `json:"scope,omitempty"`
	ApplicationSites     int     `json:"applicationSites,omitempty"`
	DirectiveOccurrences int     `json:"directiveOccurrences,omitempty"`

	// só na auditoria (find-dynamic-calls): o veredito POR ARQUIVO. `total` e
	// `traceable` são o número que o programador acompanha ao longo do tempo -
	// é a forma de ele ver o próprio código melhorando.
	Modules   []Modulo `json:"modules,omitempty"`
	Total     int      `json:"total,omitempty"`
	Traceable int      `json:"traceable,omitempty"`

	// só no usages. `total` × `returned` + `truncated` existem porque a
	// resposta pode ser cortada, e um consumidor que leia só `locations`
	// concluiria "são estes" quando são "estes, dos N".
	Query     string `json:"query,omitempty"`
	Returned  int    `json:"returned,omitempty"`
	Truncated bool   `json:"truncated,omitempty"`
}

// Modulo é o veredito de um arquivo: rastreável, ou com os sítios que o tiram
// do alcance da prova. `sites` vazio é a afirmação positiva, não a ausência.
type Modulo struct {
	File      string       `json:"file"`
	Traceable bool         `json:"traceable"`
	Sites     []SitioDinam `json:"sites"`
}

type SitioDinam struct {
	Line int     `json:"line"`
	Kind string  `json:"kind"`
	Sym  *string `json:"sym"`
}

type Edicao struct {
	URI     string    `json:"uri"`
	Range   Intervalo `json:"range"`
	NewText string    `json:"newText"`
}

type Envelope struct {
	Schema      string        `json:"schema"`
	Command     string        `json:"command"`
	Argv        []string      `json:"argv"`
	Status      string        `json:"status"`
	Exit        int           `json:"exit"`
	Reason      *string       `json:"reason"`
	Action      *string       `json:"action"`
	Detail      string        `json:"detail"`
	Diagnostics []Diagnostico `json:"diagnostics"`
	Result      Resultado     `json:"result"`
	Edits       []Edicao      `json:"edits"`
}

// Recusa devolve o par (código, ação) de uma recusa, e ("", "") quando o
// envelope não é recusa nenhuma. Os dois campos são PONTEIRO por contrato
// (`null` quando não há recusa), e um `*env.Reason` cru dentro de um caso é um
// panic esperando o dia em que a ferramenta parar de recusar — que é
// exatamente o dia em que se quer ler uma falha, não um stack trace.
//
// Achatar em "" é de propósito: um caso que pede recusa e recebe sucesso falha
// mostrando `""/""`, e não some por comparar dois ponteiros nulos.
// Aponta fails unless the site covers EXACTLY the given word inside `linha` -
// the line of the FILE, which is where a site's `range` is measured.
//
// It exists so a case needs no magic number: the expected column comes out of
// the text itself, so the reader sees "points at the word CMD_SOMA" instead of
// "column 3..11". And on failure it shows what the site ACTUALLY sliced - a
// site with no position slices "" and the reader gets it at once.
func (l *Local) Aponta(t *testing.T, linha, palavra string) {
	t.Helper()

	quero := strings.Index(linha, palavra)
	if quero < 0 {
		t.Errorf("%s: a linha %q não contém %q", l.Kind, linha, palavra)
		return
	}
	ini, fim := l.Range.Start.Character, l.Range.End.Character
	if ini == quero && fim == quero+len(palavra) {
		return
	}
	recorte := "<fora da linha>"
	if ini >= 0 && fim <= len(linha) && ini <= fim {
		recorte = linha[ini:fim]
	}
	t.Errorf("%s: aponta %q (col %d..%d), quero %q (col %d..%d)\n  linha: %s",
		l.Kind, recorte, ini, fim, palavra, quero, quero+len(palavra), linha)
}

func (e Envelope) Recusa() (reason, action string) {
	if e.Status != "refused" {
		return "", ""
	}
	if e.Reason != nil {
		reason = *e.Reason
	}
	if e.Action != nil {
		action = *e.Action
	}
	return reason, action
}
