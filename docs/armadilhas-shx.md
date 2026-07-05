# Armadilhas da linguagem Harbour: tabela de decisão S/H/X

Classificação de cada construção problemática do Harbour para refatoração automatizada:

- **(S)** — refatorável de forma *sound* (a análise garante que a semântica não muda);
- **(H)** — refatorável com heurística + **confirmação obrigatória do usuário**;
- **(X)** — fora de escopo: a ferramenta detecta e **recusa** (ou exige fluxo dedicado).

Método: afirmações marcadas **[testado]** foram verificadas executando código em 2026-07-04 (era do smoke test — inventário completo em [smoketest/inventario-ecossistema.md](smoketest/inventario-ecossistema.md)); referências de fonte apontam para o harbour-core (`$HB_ROOT`).

Premissa de leitura (ATUALIZADA 2026-07-05): o desenho "compilador como oráculo" virou realidade e foi além — a fonte dos fatos hoje é a AST emitida pelos ganchos do compilador ([ast-schema.md](ast-schema.md), [arquitetura.md](arquitetura.md)). A classificação S/H/X abaixo continua sendo a régua de risco por CONSTRUÇÃO DE LINGUAGEM e orienta as fases B4/B4b do [roadmap.md](roadmap.md); menções a mecanismos da era anterior (diff .prg×.ppo etc.) descrevem COMO se provava na época, não como a ferramenta atual opera.

---

## 1. Macros de runtime (`&var`, `&(expr)`)

| Alvo do rename | Classe | Por quê |
|---|---|---|
| `LOCAL` / parâmetro / local *detached* em codeblock | **S** | O macro de runtime **não enxerga variáveis lexicais**. **[testado]** com a local `nCount` viva no escopo: `Type("nCount")` → `"U"` e `&("nCount")` → erro de runtime. Locals são slots de pilha sem nome em runtime; o compilador de macros resolve identificadores como memvar/field/função via dynsyms. |
| `STATIC` (variável) | **S** | Mesma razão: slot por módulo, sem nome em runtime, invisível ao macro. |
| `STATIC FUNCTION` | **S** | **[testado]** no mesmo módulo: `&("SFoo()")` e `Do("SFOO")` falham com erro de runtime; só a chamada direta funciona. Símbolo estático não é alcançável por nome. |
| `PRIVATE` / `PUBLIC` / memvar implícito / `FIELD` / função pública / método | **H** | O nome pode estar em qualquer string que vire macro. Heurística dupla: (i) o gravador de ocorrências marca **funções que usam opcodes `HB_P_MACRO*`** — nelas, qualquer rename desses alvos pede confirmação; (ii) varredura de literais string contendo o nome (case-insensitive) em todo o projeto. |
| Nome construído por concatenação dinâmica (`&( "n" + cSufixo )`) | **X residual** | Indetectável estaticamente por definição. A ferramenta declara o risco no relatório final e aponta a suíte de testes do projeto como única rede. |

## 2. Chamadas indiretas por string (`Do()`, `hb_ExecFromArray()`, `Eval` de bloco macro-compilado, dispatch por `ProcName()`…)

| Alvo | Classe | Estratégia |
|---|---|---|
| `STATIC FUNCTION` | **S** | Inalcançável por nome em runtime **[testado]** (ver §1). O rename só precisa cobrir as chamadas diretas do módulo — que o compilador enumera. |
| Função pública / procedure | **H** | Varredura de literais string com o nome (case-insensitive; atenção a `"FOO"` vs `"foo()"` vs listas separadas por vírgula) + confirmação site a site. Inclui `.hbx`/`DYNAMIC` e `REQUEST`. |
| Método (send via string, `__objSendMsg`) | **H** | Mesma varredura; mensagens OOP são strings com frequência ainda maior. |

## 3. Codeblocks e escopo de variáveis

| Construção | Classe | Por quê |
|---|---|---|
| `LOCAL` (incl. parâmetros) | **S** | O compilador resolve exatamente — `hb_compVariableFind()` distingue local, parâmetro e local *detached* referenciada por codeblock (`pDetached`, `hbcompdf.h:508`). É o caso-base da Fase 0. |
| `STATIC` (escopo de módulo/função) | **S** | Listas `pStatics` por função + módulo; resolução exata pelo mesmo oráculo. |
| Codeblock `{|x| ...}` | **S** | Variáveis do bloco (`HB_CBVAR`) e capturas *detached* são resolvidas pelo compilador. Exceção: bloco **gerado por macro** (`&cBloco`) cai na regra §1. |
| `PRIVATE` / `PUBLIC` / `MEMVAR` / memvar implícito (`-v`/`#pragma -v+`) | **H** | Escopo **dinâmico**: uma PRIVATE do chamador é visível nos chamados em runtime; o vínculo declaração↔uso atravessa o call graph e depende de execução. Rename = operação global no projeto, com lista de todos os sites e confirmação; funções com `HB_P_MACRO*` agravam (macros criam/leem memvars). |
| `FIELD` / campo com alias (`ALIAS->campo`) | **X** (fluxo dedicado) | Renomear campo não é refatoração de código: é **mudança de schema** (DBF, índices, SQL embutido, relatórios). A ferramenta detecta e recusa no fluxo normal; um eventual fluxo "rename de campo" (código + `dbfield`) é projeto à parte. |

## 4. Pré-processador (`#define`, `#[x]translate`, `#[x]command`)

| Situação | Classe | Estratégia |
|---|---|---|
| Ocorrência em linha **não transformada** pelo pp | **S** | Detectável mecanicamente: diff linha-a-linha `.prg` × `.ppo` (§4 do inventário). Linha intacta ⇒ o token do fonte é o token que o compilador viu. |
| Ocorrência em linha **transformada** por regra/define | **H** | O compilador viu tokens pós-expansão; o mapeamento de volta não é confiável. Se o identificador aparece *verbatim* na linha original (passou por um marker), propor a edição com confirmação; se foi **gerado** pela regra, apontar a regra/`#define` de origem e perguntar se o alvo do rename é ela. |
| Renomear o próprio símbolo de `#define`/`#command`/`#translate` | **H** | Usos encontrados por replay com a biblioteca do pp (`__pp_AddRule`/`__pp_Process`) + tokenização. Complicadores que exigem confirmação: case-insensitivity, **abreviação dBase em `#command`** (≥4 chars casam) e regras que geram regras. |
| Rename cujo novo nome **colide** com define/regra existente | **S (bloqueio)** | A ferramenta carrega as regras do projeto via biblioteca do pp e recusa nomes que casariam com um define/command ativo — checagem barata e sound. |

Rede de segurança em todos os casos: a verificação por recompilação (`-gh -l`, §5 do inventário) roda **depois** do pp real — expansão errada quebra o byte-compare ou o build.

## 5. C embutido (`#pragma BEGINDUMP/ENDDUMP`) e fronteira `.prg`↔C

| Situação | Classe | Estratégia |
|---|---|---|
| Função Harbour definida como `HB_FUNC(NOME)` em dump / chamada do C (`hb_itemDo`, strings de símbolo) | **H** | O C é opaco à análise Harbour. Varredura textual dos blocos dump (o pp os delimita com precisão — `HB_PP_STREAM_DUMP_C`) procurando `HB_FUNC( NOME )`, `HB_FUNC_EXTERN`, e o nome como string; edição proposta com confirmação. |
| Identificadores internos do C (variáveis C, macros C) | **X** | Fora do domínio da ferramenta; o dump inteiro é intocável exceto pelos padrões acima. |

**Restrição de verificação (achado importante):** `harbour -gh -l` **não compila os dumps C**. Arquivo com `BEGINDUMP` exige verificação pelo build completo (Makefile/hbmk2 do projeto) — o critério de pronto da fase precisa distinguir os dois caminhos.

## 6. Case-insensitivity e significância de identificadores

| Situação | Classe | Por quê |
|---|---|---|
| Matching case-insensitive | **S** | Resolvido por construção: o lexer do pp e o oráculo do compilador comparam como a linguagem compara. A ferramenta preserva o *casing* de cada ocorrência ao reescrever (ou normaliza, por opção). |
| "Regra dos 10 caracteres" | **S** (não existe no default) | **Verificado no fonte**: a significância no Harbour é `HB_SYMBOL_NAME_LEN = 63` (`$HB_ROOT/include/hbvmpub.h:55`), com truncação em `hb_dynsymGetCase`/`hb_dynsymFind` (`src/vm/dynsym.c:378-407`). A regra de 10 é Clipper. Lint: avisar se o novo nome exceder 63 ou colidir após truncação; modo opcional de lint "10 chars" para bases que ainda compilam em Clipper real. |
| Novo nome vira palavra reservada em uppercase (ex.: `nIL`) | **S (bloqueio)** | Checagem de lista de reservadas antes de aplicar (caso já vivido no projeto: `nIL` lê como `NIL`). |

---

## O que o desenho compilador-oráculo elimina

- **Elimina por completo (vira S):** §3 escopo léxico (LOCAL/STATIC/codeblocks/detached) — a parte que parser externo nenhum acerta por aproximação; §6 inteiro.
- **Elimina parcialmente:** §1/§2 — a fronteira sound/unsound fica **precisa** (locals, statics e static functions provadamente fora do alcance de macros — sem o oráculo, teríamos que tratar tudo como H); §4 — a detecção de linha transformada é mecânica via `.ppo`.
- **Permanece H/X por natureza da linguagem, com qualquer fundação:** nomes em strings (§1/§2), linhas reescritas pelo pp (§4), C embutido (§5), schema de dados (§3-FIELD).

Consequência para o roadmap: a Fase 0 (rename de LOCAL) opera 100% dentro do território S — é o smoke test certo. A primeira fronteira H aparece na Fase 1 (funções públicas × strings/macros), onde o mecanismo de confirmação precisa nascer.
