# Spec B7b — Inferência fatia 3: retorno de método, Self em INLINE, blocos

Status: **ENTREGUE (2026-07-08)** — registro integral no
[roadmap-fases-entregues.md](roadmap-fases-entregues.md); regras de
consumo na seção TypeOf do [ast-schema.md](ast-schema.md); delta da
M-cov 2 na seção própria do
[limites-e-alavancas.md](limites-e-alavancas.md). Critério de pronto
fechado: caso 86 (fixture fixb7b — 3 alvos + venenos, hbclass E DSL
não-espelho, executável), suíte 600/0 byte-idêntica paralelo ×
`JOBS=1`, zero mudança no core (schema ast-6 inalterado). Nota do
percurso: o fato que liga o bloco INLINE à classe se materializou como
registro como-escrito (par STRING+CODEBLOCK na função-classe, que a
co-derivação já liga à classe) + fato do VM (classes.c:4554: o
receptor entra como 1º argumento do bloco); o alvo 2 do desenho
original (co-derivação direta da regra) foi realizado por essa via,
com o portão de generalidade provado por execução.

Portão original (2026-07-08 — decisão do Diego após a M-cov 2:
mais inferência sobre os fatos que JÁ temos, antes de qualquer extensão
de linguagem). Zero mudança no core — 100% ferramenta.
Origem e números: seção M-cov 2 do
[limites-e-alavancas.md](limites-e-alavancas.md).

Motivação: a M-cov 2 (76 programas fechados dos tests do core em
`work/tests`, 5.686 sites) mostrou que os maiores baldes do "possible"
são **lacunas de inferência**, não fatos ausentes: send encadeado 697,
Self em corpo INLINE/OPERATOR (o padrão money, dentro dos 915 "local
sem cadeia" + parte dos de bloco), parâmetro de bloco 320, local
detached em bloco 1.284. A B9 (tipos impostos) foi para a gaveta —
anotação não ajuda onde a inferência ainda nem tentou.

## Alvos (em ordem de valor medido)

1. **Retorno de MÉTODO (send encadeado, 697 sites).** A B7 infere
   retorno de função (`B7FunRet`, pushes rotulados `ret` do ast-6) mas
   não de método. Extensão: dado receptor com classe/conjunto conhecido
   e método RESOLVIDO (máquina B4f-2/B7 existente — acerto próprio
   decide), inferir o tipo do retorno pelos pushes `ret` do corpo do
   método resolvido; união com acordo; memo por classe:método. Venenos
   habituais valem (Self envenenado no corpo, multi-write, ciclo →
   memo com ⊥ provisório).
2. **Self em corpo INLINE/OPERATOR (padrão money).** O corpo INLINE
   compila como codeblock dentro da função-classe; `Self` ali não tem
   canal declarado. O FATO existe por CO-DERIVAÇÃO (B4d): o bloco
   deriva da regra que o ligou ao canal de classe. **Portão de
   generalidade (O NORTE, régua da Q6/GenMsgPart)**: o fato é a
   co-derivação da regra que LIGOU o bloco à classe — NADA keyed a
   hbclass; DSL própria com INLINE-equivalente ganha o mesmo fato ou
   degrada honesto.
3. **Blocos**: (a) local detached de binding único lida DENTRO do
   bloco (hoje o contexto de bloco degrada cedo — revisar a regra
   `lBlock` do TypeOf: leitura de detached com binding único fora é
   fato); (b) parâmetro de bloco via união dos sites de `Eval`/
   iteradores QUANDO os fatos alcançarem (bloco rastreável até o Eval;
   pontos cegos auditados) — degradar honesto onde não alcançar.
   Multi-write real continua ⊤ (regra sem ordem, mantida).

## Fatos já em mãos

- `ret` labels (ast-6) em TODOS os corpos, inclusive métodos.
- Dumps carregam statements de bloco (`block:true`) e as árvores dos
  corpos INLINE dentro da função-classe.
- Canal de derivação `from` (ast-3/B4d) liga tokens de bloco à regra.
- Máquina existente: `TypeOf`/`B7FunRet`/`B7SendRet`/`B7Merge`/
  `ResolveDispatch`; memos em `hInter`.
- Corpus de medição: `work/tests` (cópia 2026-07-08 dos tests do core;
  `work/` é git-ignorado — recopiar se ausente:
  `cp -r ~/devel/harbour-core/harbour/tests ~/devel/hbrefactor/work/tests`).

## Critério de pronto (executável)

- Fixture(s) novas cobrindo os 3 alvos + venenos (método com retorno
  não-Self, cadeia `o:M():N()`, INLINE/OPERATOR em hbclass E em DSL
  própria não-espelho, bloco com detached de binding único, bloco com
  multi-write permanecendo ⊤, Eval rastreável e não-rastreável).
- **Re-rodar a M-cov 2 no MESMO corpus e registrar o delta no mapa**
  (alvo: send encadeado e Self-INLINE fecham onde há fato; conjuntos
  nomeados aparecem; os cls*cast de tortura PERMANECEM honestos).
- Suíte inteira verde (hoje 582/0), byte-idêntica nos dois modos.
- Zero mudança no core (fase 100% ferramenta; schema inalterado).

## Fora do escopo

- B9/alavanca G (NA GAVETA — decisões T1-T5 preservadas na spec-b9;
  revive se o dogfooding provar fricção que a inferência não fecha).
- Alavanca D (funil `hb_vmSend` + gêmeo macro.y) — candidata a fase
  seguinte; os cls*cast RODAM, são alvo natural dela.
- Flow-sensitivity / análise de ordem (não-fazer mantido).
- B8 (NA GAVETA, como está).
