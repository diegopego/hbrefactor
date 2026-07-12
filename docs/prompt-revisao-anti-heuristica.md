# Prompt: sessão de REVISÃO ANTI-HEURÍSTICA do hbrefactor

Sessão dedicada (ordem do Diego, 2026-07-12). Rodar numa sessão **limpa**, não
como apêndice de uma entrega — quem acabou de escrever o código é o pior juiz dele.

O texto abaixo é o prompt: **colar inteiro**.

---

Você vai auditar o `src/hbrefactor.prg` inteiro procurando **um único tipo de
defeito**: código que decide por **heurística, inferência ou réplica de lógica do
core**, em vez de agir sobre FATO da AST do compilador.

**Leia antes de começar, nesta ordem:** `CLAUDE.md` (§ PORTÃO DE AUTORIZAÇÃO e
§ GATILHOS da REGRA DO FATO), `docs/ast-schema.md` (o que o dump JÁ dá — metade dos
achados morre aqui: o fato existia e a ferramenta não o usou), e
`docs/pp-corpus/ROADMAP.md` (a narrativa dos erros REAIS já cometidos: `ast-14`,
`ast-15`, `ast-16` — nos três o core sabia e não contava, e eu ia remendar na
ferramenta).

## O que você procura (os gatilhos)

1. **Comparação de TEXTO para decidir PAPEL ou IDENTIDADE** — `Upper(a) == Upper(b)`,
   prefixo, `Left()`, `$` — quando o dump já tem número/id/índice.
2. **Constante mágica de gramática** (`>= 4`, `Len() > N`): é réplica de regra do
   compilador, e diverge no dia em que o Harbour mudar.
3. **"Se não é X, então é Y"** sem um fato que SEPARE X de Y.
4. **Re-implementar resolução/busca que o core já faz** (achar include, casar nome,
   expandir macro).
5. **Casar arquivo por BASENAME** em vez de caminho canônico.
6. **Ter escolhido o canal mais BARATO** em vez do CORRETO (o dump quando o
   `harbour -gd` responde melhor; texto quando há id).

## O método (não negociável)

- **Nada de achado por leitura só.** Todo achado vira **prova executável**: um
  fixture `.prg` mínimo que COMPILA limpo (`-w3 -es2`) e faz a ferramenta errar —
  ou o achado é descartado. Foi assim que o sequestro de regra e o vazamento de
  escopo saíram do "parece frágil" para "está quebrado, olha aqui".
- Para cada achado sobrevivente, responda **a pergunta de controle**: *"o core SABE
  isto e não me conta?"*
  - **Sabe** → o conserto é **estender o core**. Diga QUAL fato falta e ONDE ele
    nasce no `ppcore.c`/`compast.c`. Não implemente sem falar com o Diego.
  - **Não sabe** → então é uma **RECUSA sobre o core**, e recusa exige **varredura
    REGISTRADA**: `harbour`/`hbmk2 --help` inteiro, a API pública (`include/hbpp.h`),
    os **`tests/` do core** (é lá que a API viva aparece) e o `ChangeLog.txt`.
    *"Não achei" quase sempre é "não procurei".*
- **NÃO conserte nada sem autorização.** A saída é um RELATÓRIO. Heurística no
  hbrefactor exige autorização explícita do Diego, por caso.

## Alvos já nomeados (comece por eles, não pare neles)

- `ResolveInclude` — re-implementa a busca de include do compilador. Hoje inofensivo
  (o dump traz o caminho resolvido), mas é cópia degradada por design: ou morre, ou
  passa a consumir `harbour -gd`.
- `HeadClashWitness` — varre TODOS os prefixos do nome novo apoiado numa propriedade
  lida do core ("toda grafia que casa uma cabeça é prefixo dela"). Não tem limiar e
  quem julga cada candidato é o pp — mas a **completude do conjunto de candidatos** é
  raciocínio sobre o core. Julgue se isso passa ou se o core deve responder direto.
- O `#un…` **órfão** (`undoes: null`, `ast-16`): fato disponível, **sem consumidor**.
- Todo `hb_HGetDef` ausente em chave OPCIONAL do dump (`marker`, `ruletok`, `from`,
  `col`, `undoes`) — acesso direto é `BASE/1132` em produção, e a suíte não pega.

## Saída esperada

Uma lista, do mais grave ao menos, cada item com:

| campo | conteúdo |
|---|---|
| **onde** | `src/hbrefactor.prg:<linha>` |
| **gatilho** | qual dos 6 |
| **prova** | o fixture que faz a ferramenta errar (ou: "não consegui quebrar" — e aí é hipótese, diga isso) |
| **veredito** | fato JÁ disponível no dump · fato a CRIAR no core (qual, e onde nasce) · recusa honesta (com a varredura registrada) |

E, no fim, o que você procurou e **não** achou — silêncio de busca não é evidência
de ausência, mas silêncio de busca **registrado** vale para a próxima sessão.
