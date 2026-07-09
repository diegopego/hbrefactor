# Spec B9 — Tipos declarados impostos: cheque de runtime para `AS <tipo>` (flag `-kt`)

Status: **FATIA 1 (core `-kt` + consumo) ENTREGUE em 2026-07-08 e
COMMITADA em 2026-07-09 (harbour-core `c1927dfcac`, hbrefactor
`6584aa8`); FATIA 2 (materialização + extensão VSCode) SOB GUARDA DA
FASE RE** — a auditoria externa alegou overclaim do `guaranteed`
(achados A1/A2: sites que o cheque não cobre saem com o selo);
verificação e conserto do consumo em RE.1/RE.2, e a fatia 2 só abre
depois do RE.3 (forma da camada sugeridora):
[spec-re-reescopo-pos-revisao.md](spec-re-reescopo-pos-revisao.md).
Fatia 1: flag `-kt` com emissão nos três pontos do T4 (prólogo de
params, pós-atribuição a local anotado, RETURN via DECLARE embrulhado
em `__HB_CHKTYPE`), helper de runtime em classes.c (is-a no objeto
VIVO — classe montada em runtime passa por NOME), gates do DECLARE
abertos sob `-kt`, distinção da forma DIMENSIONADA (`LOCAL a[n]` não é
anotação — flag interno `HB_VSCOMP_DIMMED`), schema **ast-7** (`kt` no
cabeçalho + `dim` nas declarations), camada `guaranteed` no usages e
correção do DeclType (dim não é promessa — send que roda saía excluded
errado). Parser regenerado com bison 3.8.2 (patch manual do yynerrs
re-aplicado; o skeleton novo provou pcode idêntico no protocolo).
Critérios (a)-(e) e (g) FECHADOS: zero impacto 224/224 (-w0 E -w3,
relink duplo conferido); fixture fixkt executável (caso 87, 17
checks); suíte 616/0 byte-idêntica paralelo × JOBS=1; flag por linha
de `.hbp` E `-prgflag=` com execução byte-idêntica. Semântica
registrada: cheque de local é PÓS-armazenamento (quem RECOVERa segue
com o valor gravado — a âncora vale nos caminhos sem violação);
atribuição em corpo de codeblock fora da fatia (índice relativo).
Critério (f) (materialização round-trip) é a fatia 2.

Portão: confirmado pelo Diego em 2026-07-08, pela REGRA DO FATO — meta
zero inferência: fato ausente → estender o core para o fato EXISTIR;
esta fase é o caminho canônico. A B7b fechou o que a inferência
alcança; o que sobra (parâmetros estruturalmente abertos, classes
montadas em runtime, objetos nascidos na VM) só vira FATO por
invariante imposta. Decisões T1-T5 do Diego mantidas como decididas.
Análise de origem e números: seções M-cov, M-cov 2 (com delta da B7b)
e Alavanca G do [limites-e-alavancas.md](limites-e-alavancas.md).

Histórico: esteve NA GAVETA entre o portão da B7b e a REGRA DO FATO
(mesmo dia) — a escada "inferência antes de linguagem" foi revogada
pelo Diego ao recusar triagem como produto.

**Enquadramento (correção do Diego, 2026-07-08 — O NORTE)**: a fase
impõe o **sistema de TIPOS declarados da linguagem inteiro** —
`AS NUMERIC/CHARACTER/DATE/LOGICAL/BLOCK/ARRAY/OBJECT` e as formas
array-de, além de `AS CLASS <nome>`. **Classe é SÓ UM CASO** (o código
'S' do canal); o cheque genérico é de kind (`ValType`), e o de classe
é o ramo extra do 'S'. A refatoração genérica consome os DOIS: fato de
kind já alimenta camadas hoje (`excluded send (receiver holds a value
of kind array)`, B4f fatia 1); fato de classe alimenta o dispatch.

Motivação (M-cov, 2026-07-08): em código real, 68% dos sends ficam
"possible" e os baldes dominantes — parâmetros cuja união é
estruturalmente aberta e valores que só existem em runtime — são
inalcançáveis por QUALQUER inferência estática. Esta fase cria a fonte
nova de fato: **tipo declarado imposto pela linguagem** (invariante
fail-fast) — terceira classe epistêmica, distinta do fato estático
(incondicional) e da evidência de execução (presença).

## Fatos verificados no fonte (2026-07-08)

1. **A sintaxe já existe no idioma inteiro** (`harbour.y`): parâmetros
   formais `:371-372`; locals `:1145`; FIELDs `:1213`; MEMVARs
   `:1224`; parâmetros de codeblock `:1019-1020`; até variável de
   macro `:1132`; **retorno** via `DECLARE fun(...) AS <tipo>` `:1228`
   (a DEFINIÇÃO de função não carrega AS — o canal de retorno é o
   DECLARE). Tipos: `StrongType` `:349-356` ('N','C','D','L','B','O',
   'S'+nome) + `AsArray` `:360-368`. Fontes anotados compilam em
   QUALQUER Harbour hoje.
2. **O canal morre na compilação**: warnings -w3 + transporte ast-4;
   nada chega ao pcode/VM.
3. **Flag flui pelo hbmk2 sem tocar no hbmk2**: mesmo mecanismo do
   `-x` — linha no `.hbp` (fixtures já carregam `-w3`/`-es2` assim),
   `-prgflag=` na CLI, `HB_USER_PRGFLAGS` no ambiente.
4. **Switch**: todas as 26 letras têm dono (`cmdcheck.c`); família
   `-k` (comportamento da linguagem, flui ao macro-compilador via
   `HB_SM_*`) com sub-letras livres — **`-kt` decidido (T5)**.

## Decisões do portão

- **T1 (Diego, 2026-07-08): compatibilidade.** Opt-in por flag; sem a
  flag, saída **byte-idêntica** (protocolo padrão de zero impacto);
  a flag flui através do hbmk2 (fato 3, zero mudança nele). Fontes
  anotados continuam compilando em Harbour de fábrica — extensão
  semântica, nunca sintática.
- **T2 (Diego, 2026-07-08): NIL FALHA.** Anotado = obrigatório E do
  tipo. Consequência registrada (trade-off apresentado e escolhido):
  parâmetro anotado deixa de ser opcional sob `-kt` — quem quer
  opcional NÃO anota (ou não liga a flag). Coerente com T1: a rigidez
  é duplo opt-in (anotar + flag). Ganho: a âncora de fato fica
  incondicional — símbolo anotado sob `-kt` é garantido não-NIL e do
  tipo, sem ressalva "quando há valor".
- **T3 (Diego, 2026-07-08): is-a satisfaz.** Instância de subclasse
  passa no cheque da classe declarada — grafo de herança do objeto
  VIVO em runtime; polimorfismo preservado.
- **T4 (Diego, 2026-07-08): escopo = params + locals + retorno.**
  Cheque na entrada da função (parâmetros), na atribuição a local
  anotado, e no RETURN de função com `DECLARE ... AS <tipo>`.
  FIELDs/MEMVARs/blocos/variável-de-macro ficam REGISTRADOS para
  fatias futuras (canal existe, fato 1).
- **T5 (Diego, 2026-07-08): switch `-kt`.**

## Desenho

Sob `-kt`, o compilador emite cheques como **pcode chamando um helper
de runtime** (nome a definir, ex. `__hb_chkType( xVal, cTypeSpec,
cSite )`) — **VM intocada**; helper novo em src/vm ou src/rtl. Cheque
genérico: kind por `ValType` (todos os tipos); ramo 'S': classe por
is-a (T3). Violação = erro de runtime padrão (catchável por BEGIN
SEQUENCE) nomeando função, símbolo, tipo declarado e recebido.

Pontos de emissão (T4): prólogo da função (um por parâmetro anotado);
pós-atribuição a local anotado; pré-RETURN quando houver DECLARE com
tipo para a função.

**Interação com o hbrefactor**: símbolo anotado em módulo compilado
com `-kt` vira **âncora de fato** — camada nova no usages
(`guaranteed by checked annotation`), condicional fail-fast e rotulada
como tal; nunca confundida com confirmed estático. O dump já transporta
os tipos (ast-4); falta transportar **a flag ativa** (campo no
cabeçalho do módulo; bump de schema na fase).

**Materialização (fatia da fase — escopo detalhado no portão aberto,
2026-07-08)**: comando `annotate <projeto> [<arq[:função]>] [--dry-run]`
que escreve `AS <tipo>`/`AS CLASS` onde a análise PROVOU o tipo. Sob a
REGRA DO FATO, a inferência B7/B7b passa a servir a ISTO: sugerir a
anotação que transforma a propagação em fato imposto.

- **Alvo da fatia**: LOCALs com tipo provado (site da declaração
  `LOCAL x` — edição textual mínima, `x` → `x AS CLASS Foo`). Params
  entram quando a união fecha em conjunto unitário; retorno via
  `DECLARE` fica para fatia seguinte (síntese de linha nova, decisão
  de estilo do Diego).
- **"Provado" =** tipo único do TypeOf com fato de compilação; o que
  carrega ressalva de mundo fechado (`via`) NÃO materializa sem
  `--force` (a anotação imposta é quem fecha o mundo dali em diante —
  mas a PRIMEIRA escrita tem que ser fato, não aposta).
- **Recusas fato-based**: multi-write/⊤, conjunto >1, memvar/field,
  posição sem byte-exato (linha de expansão), nome de classe fora do
  projeto (anotação com classe não registrada degrada o canal — caveat
  do ast-schema).
- **Verificação padrão-ouro**: anotação não muda pcode SEM `-kt`
  (.hrb byte-idêntico pós-edição) + compila limpa `-w3 -es2` + com
  `-kt` o programa RODA (cheques passam) — rollback em qualquer falha.

## Zero impacto e compatibilidade (prova)

- Sem `-kt`: .hrb byte-idênticos na árvore inteira de fixtures (-w0 E
  -w3); relink duplo harbour+hbmk2.
- Com `-kt` e fonte SEM anotações: byte-idêntico também (nenhum cheque
  emitido) — cheque explícito no critério.
- Fonte anotado compila em Harbour de fábrica (fato 1 — gramática
  padrão).

## Venenos / casos de borda (mínimos da fixture)

1. NIL em parâmetro anotado → FALHA nomeando (T2); parâmetro NÃO
   anotado ao lado segue aceitando NIL (opcional preservado onde não
   se anotou).
2. Subclasse passada (T3: passa) e classe NÃO relacionada (falha
   nomeando).
3. Classe montada em runtime (`__clsNew`) com o nome declarado — o
   cheque no objeto vivo DEVE passar (é o alcance novo; nada keyed a
   hbclass).
4. Local anotado recebendo kind errado (`nIdade AS NUMERIC := "x"`).
5. Parâmetro por referência `@` + anotação (a gramática de DECLARE já
   modela byref: `:1361`).
6. RETURN violando o DECLARE da própria função.
7. Função chamada por macro/`hb_ExecFromArray` — o prólogo roda igual
   (o cheque é da FUNÇÃO, não do call site): assert de que vale.
8. Codeblock param anotado: FORA da fatia (registrado, T4).

## Critério de pronto (executável)

Fixture nova `fixkt` (compilada limpa antes de usar), com tipos
VARIADOS (numeric/character/array/block/classe — classe como um caso
entre os kinds, régua do caso 64):

- (a) zero impacto: sem flag byte-idêntico (árvore inteira); com flag
  e fonte sem anotação byte-idêntico; relink duplo.
- (b) violações de kind e de classe erram em runtime nomeando
  função/símbolo/declarado/recebido; BEGIN SEQUENCE captura.
- (c) T2/T3 assertados: NIL falha nomeando; is-a passa; classe
  não-relacionada falha; parâmetro não-anotado segue aceitando NIL.
- (d) alcance novo provado: classe registrada em runtime passa no
  cheque por nome (veneno 3).
- (e) flag no dump (schema bump) + camada nova no usages com rótulo
  condicional; suíte inteira verde e byte-idêntica nos dois modos.
- (f) materialização: round-trip — análise prova tipo → comando
  escreve a anotação → recompila limpo → usages confirma na âncora.
- (g) fluxo hbmk2 provado por execução: flag via linha de `.hbp` E via
  `-prgflag=` produzem o mesmo binário com cheques.

## Fora do escopo

- Sintaxe nova de anotação (canal existente não saturou).
- FIELDs/MEMVARs/blocos/variável-de-macro anotados (canal existe;
  fatias futuras por fricção).
- Semântica de despacho/early binding (porta futura, alavanca G).
- Alavanca D (funil `hb_vmSend` + gêmeo macro.y) — fase própria
  posterior.
