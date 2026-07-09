# Spec B9 — FATIA 2: materialização de anotações provadas (`annotate`)

Status: **RASCUNHO NO PORTÃO DO DIEGO (2026-07-09).** Não executar nada
antes do portão. Esta spec fecha o escopo e o critério executável da
fatia 2 da B9 (o comando que escreve `AS CLASS`/`DECLARE ... AS CLASS`
provados); a fatia 1 (core `-kt` + consumo) está entregue e commitada
(harbour-core `c1927dfcac`, hbrefactor `6584aa8`), corrigida pelo RE.2
(`B7KtCovered`, caso 88). Documentos-mãe:
[spec-b9-anotacoes-impostas.md](spec-b9-anotacoes-impostas.md) (a fatia
2 estava esboçada em "Materialização", linhas 123-144),
[spec-re-reescopo-pos-revisao.md](spec-re-reescopo-pos-revisao.md)
(RE.3 pôs a máquina B7/B7b DORMENTE e definiu o materializador como seu
ÚNICO consumidor) e
[testes-suspensos-re3.md](testes-suspensos-re3.md) (os itens `[FATIA-2]`
são a **semente obrigatória** do critério de aceite — decisão do Diego,
2026-07-09).

## O que esta fatia É (e o que a REGRA DO FATO exige dela)

O ciclo virtuoso que a REGRA DO FATO autoriza como destino da inferência
(CLAUDE.md; O NORTE do roadmap): **a análise B7/B7b prova o tipo de um
receptor → o comando escreve a anotação `AS CLASS` no fonte → o `-kt`
impõe a anotação como INVARIANTE → o site volta a decidir por FATO
(`guaranteed`/`confirmed declared`)**. A inferência NUNCA volta a ser
veredito do `usages` (RE.3, forma "a"); ela é insumo de SUGESTÃO que
produz uma edição verificada, e a verificação — não a inferência — é o
que torna a anotação confiável. Uma anotação provada por engano (o
veneno do forjador da Q4: vínculo escrito que não é pai, num caminho que
em runtime é código morto) é barrada pela verificação padrão-ouro ou,
se sobreviver a ela, passa a ser fail-fast sob `-kt` dali em diante — o
risco residual é do site que a execução de verificação não exercita, e
essa fronteira fica DECLARADA (§ "Limite honesto da verificação").

Este comando é o **único chamador** da máquina dormente. Ele a revive
por `B7Ctx` (hbrefactor.prg:6288) e, ao fazê-lo, **mata o W0034 do
build** (`B7Ctx` sem chamador é o marcador honesto do estado desde o
RE.3 — hbrefactor.prg:6279-6284). O `usages` de produto continua sem
construir `hInter`: nada nesta fatia re-liga a inferência ao veredito do
`usages`.

## Fatos verificados (fonte, 2026-07-09)

1. **A anotação é INERTE sem `-kt`** (canal morre na compilação —
   ast-schema §"Canal de tipos", fato 2 do doc-mãe): escrever `x AS
   CLASS Foo` num `LOCAL` não muda o pcode enquanto a flag não estiver
   ligada. É o que torna a verificação "byte-idêntico sem `-kt`"
   aplicável (a mesma prova de zero-impacto da fatia 1).
2. **A cobertura do `-kt` que vira `guaranteed` é a matriz do RE.1**
   (`B7KtCovered`, hbrefactor.prg:6435; ast-schema §"Camada
   guaranteed"): local anotado SÓ vira invariante se nenhuma occurrence
   do símbolo tem `access:"ref"` nem `access:"write"`+`block:true`. Um
   sítio que o materializador anota mas que o `-kt` não cobre sai
   `confirmed send (receiver declared AS CLASS X)` SEM selo — honesto,
   mas não é `guaranteed`. O materializador tem que SABER dessa matriz
   para não prometer selo onde não há.
3. **`declarations[]` NÃO tem posição byte-exata** — só `declLine`
   (ast-schema:291). A âncora de escrita vem do `tokens[]` (`prov 's'`,
   byte-exato — ast-schema:58-67): o token identificador do nome na
   `declLine`. **Sítio nascido de expansão de pp (`prov != 's'`) é
   RECUSA** (não há byte-exato para editar — mesma disciplina das
   edições textuais das outras fatias).
4. **O canal de retorno é o `DECLARE`** (ast-schema §`declared`;
   doc-mãe fato 1): a DEFINIÇÃO da função não carrega `AS`; quem tipa o
   retorno é `DECLARE F(...) AS CLASS X`. O `-kt` embrulha o valor de
   RETURN de F em `__HB_CHKTYPE` (fatia 1). Para o `usages` decidir o
   send encadeado por fato, o `DECLARE` precisa estar VISÍVEL no módulo
   onde F é definida (o cheque é emitido no corpo de F) e o
   `declared.functions` transporta o tipo ao consumidor.
5. **A máquina sugeridora entrega o tipo com/sem ressalva**: `TypeOf`/
   `SendReceiverType` devolvem um hash de tipo; traço de mundo fechado
   vem marcado (`via`) e conjuntos finitos >1 já degradam a `possible`
   NOMEADO na máquina (não decidem). Um tipo com `clsset`/`via` é
   proveniência de mundo fechado, não fato incondicional (RE.3 degradou
   isso no `usages`; aqui é insumo de sugestão, com política própria —
   § "Definição de PROVADO").

## Escopo da fatia (rotas de FATO; nada mais)

Semente obrigatória: os itens `[FATIA-2]` de
[testes-suspensos-re3.md](testes-suspensos-re3.md).

**DENTRO:**

- **Rota A — anotação em LOCAL/parâmetro** (`[FATIA-2]`, testes-suspensos
  §"Rota A"): a sugeridora prova a classe do símbolo; o comando escreve
  `AS CLASS X` no sítio da declaração (`LOCAL x` → `LOCAL x AS CLASS X`);
  `-kt` impõe (se coberto — fato 2); o send do símbolo volta a decidir
  por fato. Sementes: casos 39/61/63/66(parte de tipagem)/84/85.
- **Rota B — retorno por `DECLARE ... AS CLASS`** (`[FATIA-2]`,
  testes-suspensos §"Rota B"): a sugeridora prova o retorno de uma
  função do projeto (pushes `ret`, identidade `QSelf()`); o comando
  materializa o `DECLARE F() AS CLASS X`; o `-kt` já impõe o RETURN
  (embrulho `__HB_CHKTYPE`); o send encadeado decide por fato. Sementes:
  casos 85 (fábrica `Cria()`), 86 (`oC:Pega():Soma`, cadeia
  `oM:Soma(1):Soma(2)`).
- **Extensão VSCode**: o comando novo chega à `vscode/extension.js` NESTA
  fatia (regra do CLAUDE.md: capacidade nova do CLI é escopo da fase que
  a entrega, não fase adiável). Comando `hbrefactor.annotate` com o
  fluxo de report/preview dos demais.

**FORA (com razão de fato, não adiamento preguiçoso):**

- **Rota C — exclusão de homônimo em SEND** (testes-suspensos §"Rota C":
  `[SEM-ROTA hoje]`): **NÃO tem rota e NÃO se promete.** A exclusão
  ("este send NUNCA é da classe consultada") exigia mundo fechado sobre
  parents as-written; nenhum canal do core dá parentesco imposto/provado
  hoje. Candidata futura: RE.6 ou canal novo no core — não esta fatia. O
  furo dos homônimos nos SENDS (caso 66, o caso original do Diego)
  **permanece degradado** após esta fatia; as declarações homônimas
  seguem `excluded` por fato (nunca saíram).
- **Rota D — sites de codeblock** (testes-suspensos §"Rota D":
  `[RE.5 + A6]`): a anotação `AS CLASS` em parâmetro de bloco é
  INESCREVÍVEL (A6 — segfault do compilador quando o módulo conhece
  classes; a gramática descarta o nome da classe no caminho de bloco) e
  o `-kt` fatia 1 não cobre blocos (matriz do RE.1). Bloqueada por A6 +
  RE.5 — gaveta separada. Materializar em bloco só depois de A6
  consertado e RE.5 estender a emissão.
- **Rota E — `possible` nomeado** (testes-suspensos §"Rota E":
  `[RE.6 ou aceitar o degrade]`): conjunto finito >1 nunca decidiu — era
  contexto. Degrade pleno é o estado final salvo RE.6. O materializador
  RECUSA conjunto >1 (não há tipo único para escrever).
- FIELD/MEMVAR/variável-de-macro anotados (canal existe; fora da fatia,
  como no doc-mãe).

## Decisões de portão (para o Diego decidir ANTES de executar)

**[PORTÃO Diego — P1] Política de `via` (proveniência de mundo
fechado).** O doc-mãe (linhas 135-137) dizia: tipo com ressalva de mundo
fechado (`via`) NÃO materializa sem `--force` — "a anotação imposta é
quem fecha o mundo dali em diante, mas a PRIMEIRA escrita tem que ser
fato, não aposta". PORÉM as sementes `[FATIA-2]` (todas por CADEIA DE
CONSTRUÇÃO — `oMenu := UWMenu():New()`) carregam `via`. Duas leituras
honestas:

- **P1-a (recomendada): tratar cadeia-de-construção de VÍNCULO ÚNICO como
  fato-suficiente para o default.** O `via` da máquina marca a travessia
  do grafo as-written, mas quando o símbolo tem UM único write e ele é
  `ClassName():New()` (ou fábrica com retorno provado), o TIPO do
  receptor é sólido — o risco do forjador Q4 é de DISPATCH (qual método),
  não de tipo do receptor. Materializa por default; a verificação
  padrão-ouro é a rede. Custo honesto: o forjador Q4 (vínculo escrito que
  não é pai, em código morto) poderia materializar um `AS CLASS` que a
  execução não exercita — mitigado por P3 (§ "Limite honesto").
- **P1-b (conservadora): `via` sempre exige `--force`.** Fiel à letra do
  doc-mãe. Custo: as sementes `[FATIA-2]` todas rodam com `--force`, e o
  fluxo diário (extensão) pede confirmação sempre. Mais atrito, menos
  surpresa.

Recomendo **P1-a** com a salvaguarda de que **vínculo NÃO-único** (ou
com `@ref`, ou tipo com `clsset`/conjunto) SEMPRE recusa ou exige
`--force`, e a distinção fica no relato. O critério executável abaixo
assume P1-a; se o Diego escolher P1-b, os casos de aceite ganham
`--force` e o resto é idêntico.

**[PORTÃO Diego — P2] Onde vive o `DECLARE` sintetizado (Rota B).** O
`DECLARE F() AS CLASS X` precisa estar no ESCOPO da definição de F (o
`-kt` emite o cheque no corpo de F) e o `declared.functions` tem que
transportá-lo. Opções de estilo (decisão sua):
- **P2-a: linha nova imediatamente antes do `FUNCTION F`** no módulo de
  F (local, visível, byte-exato trivial). Recomendada.
- **P2-b: bloco `DECLARE` agrupado no topo do módulo** (estilo "header").
- **P2-c: `.ch` compartilhado** (rejeitada para esta fatia — edição de
  include foge do byte-exato por módulo; fica para fricção real).
Recomendo **P2-a**. Independente da escolha, a síntese de linha nova é
edição textual e a verificação padrão-ouro se aplica igual.

**[PORTÃO Diego — P3] Nome do comando.** O doc-mãe propôs
`annotate <projeto> [<arq[:função]>] [--dry-run]`. Mantenho `annotate`
(verbo de AÇÃO, alinhado ao princípio "genérico > específico" e ao
espírito da fase U — o KIND do alvo, LOCAL vs retorno, é consequência do
fato no sítio, não sufixo do comando). Alternativa a considerar no
portão: um sub-modo do futuro verbo unificado da fase U. Recomendo
seguir com `annotate` autônomo agora (a fase U está sob portão próprio).

## Desenho

`annotate <projeto> [<arq[:função]>] [--dry-run] [--force] [--json]`

1. **Carrega os dumps** do projeto (via hbmk2, como todos os comandos) e
   **revive a máquina** com `B7Ctx( hAsts, hDecl )` — este é o único
   chamador; o W0034 morre aqui.
2. **Enumera candidatos** no escopo pedido (projeto inteiro, arquivo, ou
   `arq:função`):
   - **Rota A**: cada `declarations[]` `scope:"local"|"static"` do
     escopo SEM tipo declarado (`type` ausente) e SEM `dim`; roda
     `TypeOf`/`SendReceiverType` sobre o símbolo. Candidato = tipo único
     de CLASSE (`cls` presente) que satisfaz a política P1.
   - **Rota B**: cada função do projeto sem `DECLARE ... AS` e sem tipo
     de retorno declarado, cujo retorno a máquina prova como classe única
     (pushes `ret`/identidade `QSelf`). Candidato = par (função, classe).
3. **Filtra por FATO** (recusas, § abaixo).
4. **Ancora byte-exato**:
   - Rota A: token identificador do nome na `declLine` (`tokens[]`,
     `prov 's'`); insere ` AS CLASS X` após o token. `prov != 's'`
     (nascido de pp) → recusa.
   - Rota B: insere a linha `DECLARE F() AS CLASS X` conforme P2.
5. **Edita numa cópia atômica** (`WorkDir`, como rename/extract) e
   **verifica padrão-ouro** (§ abaixo); rollback em qualquer falha.
6. `--dry-run`: mostra o diff/relato e NÃO grava. `--json`: relato
   estruturado (sítio, símbolo, classe, coberto-por-kt sim/não,
   veredito-alvo).

### Definição de PROVADO (o que materializa)

Um candidato materializa quando **todos**:
- O tipo do TypeOf é uma CLASSE única (`cls` presente, sem `clsset`,
  sem conjunto >1).
- A classe está REGISTRADA no projeto (o nome resolve em
  `declared.classes`/`ClassFuncMap`) — classe fora do projeto degrada o
  canal (caveat do ast-schema) e RECUSA (não há como o `-kt` provar por
  is-a uma classe que a análise não conhece; a anotação até compilaria,
  mas o produto não a materializa sem fato de registro).
- Política P1 satisfeita (vínculo único para default; `via`/não-único →
  conforme P1-a/P1-b + `--force`).
- Sítio byte-exato (`prov 's'`).

### Verificação padrão-ouro (a rede; idêntica ao espírito da fatia 1)

Toda materialização passa por, na cópia de trabalho:
1. **Sem `-kt`: `.hrb` byte-idêntico pós-edição** (fato 1 — a anotação é
   inerte; se mudou o pcode, algo saiu do canal → rollback).
2. **Compila limpo `-w3 -es2`** (a anotação é gramática válida; se
   quebrou, rollback — pega o A6 e afins).
3. **Com `-kt` o programa RODA e os cheques PASSAM** — rollback se o
   `-kt` fizer o programa falhar (a anotação contradiz o runtime).
Rollback em qualquer falha, relato nomeando a causa (idioma `Refuse`/
`RollbackAll` das outras fatias).

### Limite honesto da verificação (declarado, não varrido)

O passo 3 é NECESSÁRIO, não SUFICIENTE: um `AS CLASS` materializado num
símbolo cujo caminho a execução de verificação NÃO exercita não dispara
o cheque `-kt` — a anotação sobrevive à verificação sem prova de runtime.
É exatamente o risco do forjador Q4 (P1). Mitigações e postura:
- P1-a restringe o default a vínculo único de construção — o balde onde o
  tipo do receptor é mais sólido.
- A anotação, uma vez escrita, é **fail-fast dali em diante**: se estiver
  errada, o primeiro caminho real que a exercitar sob `-kt` estoura
  nomeando — o erro não fica silencioso, vira fato na próxima execução.
- `--dry-run` + relato deixam o Diego ver ANTES de gravar.
Este limite fica registrado no roadmap e no `limites-e-alavancas.md`.

### Recusas fato-based (relato honesto, nunca ajeito)

Multi-write com tipos discordantes (⊤); conjunto >1 (Rota E — degrade);
`clsset`/`via` sob P1-b sem `--force`; memvar/field/param-de-bloco;
sítio sem byte-exato (`prov != 's'`, linha de expansão); classe fora do
projeto; símbolo com `@ref` quando a política pedir cobertura;
codeblock (Rota D — A6). Cada recusa nomeia o sítio e o motivo.

## Critério de pronto (executável) — semente `[FATIA-2]`

Regra (testes-suspensos, "Como usar"): **um caso de suíte NOVO por item
`[FATIA-2]`**, assertando o rótulo de FATO no MESMO sítio do fixture,
depois do ciclo `annotate → recompila → usages`. Os **fixtures
continuam intocados** na suíte; o caso novo copia o fixture para um
WorkDir, roda `annotate`, roda `usages` na cópia anotada e asserta.
Nenhum assert antigo volta verbatim (RE.3 regra 1): o rótulo novo é
`guaranteed`/`confirmed ... declared`, nunca `via construction chain`.

**Rota A (LOCAL/param):**

| Caso novo | Fixture:sítio | Rótulo-alvo pós-materialização |
|---|---|---|
| 39/61 | fixcls w2.prg:7 `oMenu:Paint()` | `guaranteed send (receiver AS CLASS UWMENU imposed by -kt checks)` (local vínculo único, coberto) |
| 61 | fixmth c2.prg:28 `oC:Soma(5)` | `guaranteed ... AS CLASS CAIXA ...` |
| 63 | fixrcv r2.prg:28 `s:Zap()` (em USA) | `guaranteed ... AS CLASS SEMCTOR ...` |
| 66 | fixdis d1.prg:87/88 `oNm:`/`oNs:Paint()` | `guaranteed ... AS CLASS NCMAIN/NCSECONDARY ...` (SÓ a tipagem; a EXCLUSÃO do homônimo é Rota C — NÃO promete) |
| 84 | fixext e1.prg:71/73/74 `oC:`/`oV:Deposita` | `guaranteed ... AS CLASS CONTA/CONTAVIP ...` (consulta da própria classe) |
| 85 | fixb7 b1.prg:53 `p:Gira()` | `guaranteed ... AS CLASS PECA ...` |

**Rota B (retorno por DECLARE):**

| Caso novo | Fixture:sítio | Rótulo-alvo pós-materialização |
|---|---|---|
| 85 | fixb7 b1.prg (fábrica `Cria()`) | send do retorno vira `guaranteed`/`confirmed ... declared` via `DECLARE Cria() AS CLASS PECA` |
| 86 | fixb7b q1.prg:73 `oC:Pega():Soma(5)` | `... AS CLASS MOEDA ...` (retorno de método pela cadeia) |
| 86 | fixb7b q1.prg:75 `oM:Soma(1):Soma(2)` (2 sends) | `... AS CLASS MOEDA ...` ×2 (identidade RETURN Self em cadeia) |

**Cobertura/qualidade obrigatória:**
- (a) **round-trip byte-exato** (critério (f) do doc-mãe): análise prova
  → `annotate` escreve → recompila limpo → `usages` confirma na âncora,
  no MESMO sítio.
- (b) **verificação padrão-ouro provada**: um caso mostra rollback quando
  a anotação contradiz o runtime sob `-kt` (anotação errada plantada de
  propósito num fixture-veneno → `annotate --force` recusa com rollback).
- (c) **recusas provadas**: conjunto >1 (Rota E), sítio de pp
  (`prov != 's'`), classe fora do projeto, codeblock (Rota D) — cada uma
  num assert de RECUSA nomeada.
- (d) **cobertura-kt honesta**: um sítio Rota A com escrita coberta sai
  `guaranteed`; um com escrita SÓ em codeblock/`@ref` (se materializável
  por outra via) sai `confirmed ... declared` SEM selo (matriz RE.1) —
  o comando NÃO promete selo onde `B7KtCovered` diz não.
- (e) **W0034 morto**: o build da ferramenta para de emitir o W0034 de
  `B7Ctx` sem chamador (o materializador é o chamador). Guarda no
  harness/lexdiff.
- (f) **extensão**: `hbrefactor.annotate` registrado e funcional
  (report/preview), na mesma fatia; guarda no caso 71 (harness da
  extensão) e bump de versão da extensão.
- (g) **zero regressão**: suíte inteira verde e byte-idêntica paralelo ×
  `JOBS=1` (protocolo padrão).

## Fora do escopo (registrado)

- Rota C (exclusão de homônimo em send) — SEM ROTA, não se promete.
- Rota D (codeblock) — bloqueada por A6 + RE.5.
- Rota E (`possible` nomeado) — degrade pleno é o estado final salvo RE.6.
- Cobertura completa do `-kt` (`PARAMETERS`, params de bloco, detached) —
  RE.5, portão próprio.
- FIELD/MEMVAR/variável-de-macro anotados — fatia futura por fricção.
- Reativar `B7Ctx` no `usages` — proibido (RE.3, forma "a").
