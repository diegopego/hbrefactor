package suite

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
}

type Diagnostico struct {
	Code     string `json:"code"`
	Severity string `json:"severity"`
	Location *Local `json:"location"`
	Detail   string `json:"detail"`
}

// A forma do result é POR COMANDO — um rename não tem os campos de um usages.
type Resultado struct {
	Verdict   string  `json:"verdict,omitempty"`
	Kind      string  `json:"kind,omitempty"`
	Old       string  `json:"old,omitempty"`
	New       string  `json:"new,omitempty"`
	EditCount int     `json:"editCount,omitempty"`
	Proof     string  `json:"proof,omitempty"`
	Locations []Local `json:"locations,omitempty"`
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
