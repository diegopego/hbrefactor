# Plano — B9 Fatia 2 v2: a escada de declarações

> **Status (Diego, 2026-07-09): PLANO APROVADO; EXECUÇÃO SOB PORTÃO.**
> Nenhuma etapa F2.x executa antes de o Diego abrir. Das decisões
> originalmente no portão, **duas são reais** (nível 3 e portão do
> meio — defaults adotados na aprovação, trocáveis na abertura ou no
> portão do meio); P1/P2/P3 da
> [spec-b9-fatia2-materializacao.md](spec-b9-fatia2-materializacao.md)
> foram DISSOLVIDAS por fato/doutrina (P1 → escada; P2 → posição
> ditada por fato; P3 → forma e nome ditados por doutrina já escrita —
> ver "Esclarecimentos pós-aprovação"); a reescrita da spec (F2.2)
> incorpora isso quando a execução abrir.

## Contexto — por que este plano existe

A spec da fatia 2 da B9 (comando de materialização) estava no portão
com três decisões abertas (P1/P2/P3). Na discussão caso a caso do P1,
o Diego argumentou: *"em algum momento da compilação o Harbour já
compreende que `t := UWMenu():New()` é uma instância de UWMenu e
poderia gravar isso — como as linguagens com inferência de `var`"*.

A investigação (probes executáveis + leitura do fonte, sessão de
2026-07-09) mostrou que a premissa literal é falsa — o compilador
registra mas **nunca conclui** (o subsistema de cheque de tipos é
vestigial) — porém a direção está certa e é mais forte do que a spec
supunha: **os fatos declarados são mais ricos do que assumíamos, e a
cadeia de tipos quebra em elos que UMA LINHA de `DECLARE` fecha**.
Isso dissolve o dilema do P1 ("confiar na inferência `via` ou travar
tudo com `--force`") numa **escada**: em vez de confiar em palpite, a
ferramenta *escreve a declaração que falta* e o caso vira fato.

Objetivo declarado pelo Diego: **"vermos o que conseguimos"** — o
relatório da primeira metade (F2.3) é a resposta medida a isso.

## Esclarecimentos pós-aprovação (rodada Diego↔Claude, 2026-07-09)

Registrados após a aprovação, na conferência das impressões do Diego:

- **P2 dissolvida — confirmado.** A posição do DECLARE não é escolha de
  estilo: é ditada por fato (função = antes do `FUNCTION` no módulo
  definidor, exigência do embrulho `-kt`/ordem de parse; membro =
  módulo do site, senão W0019). E há um degrau a mais na direção do
  Diego: **candidato de core** — declarar por default o `New` herdado
  (`_HB_MEMBER New() AS CLASS <própria>` implícito em classe
  `_HB_CLASS`, no compilador, não no pp — o pp não vê se o usuário
  declara New explícito). Eliminaria a materialização de membro no
  padrão mais comum de quebra; só alcança DSLs que emitem `_HB_CLASS`;
  fábricas continuam precisando de DECLARE. Vira o probe (f) da F2.1;
  adoção decidida no portão do meio.
- **O `-kt` NÃO desaparece (correção ao Diego).** Três papéis
  insubstituíveis: (1) sem ele, anotação é promessa inerte — o teto do
  produto cai de `guaranteed` (invariante imposta) para
  `confirmed declared` (promessa registrada), exatamente a distinção
  que a revisão externa cobrou (A1/RE.2); (2) é o **oráculo de
  verificação do materializador** — anotação errada é indetectável sem
  ele (zero pcode, compilação limpa, checker vestigial), e a regra
  "nunca editar o não-verificável" torna isso inegociável: o passo
  "roda com `-kt`" é o que permite o `annotate` existir; (3) cobre os
  baldes que nenhuma análise alcança (M-cov: classes de runtime,
  parâmetros abertos — cheque por nome no objeto VIVO). Grão de
  verdade: sempre foi opt-in duplo (T1) e a camada declared funciona
  sem ele — ele não é obrigatório; é o degrau que transforma promessa
  em fato.
- **P3 dissolvida — confirmado** (ver a seção "(ex-Decisão 3)"
  abaixo): forma ditada por doutrina já escrita (genérico > específico
  + princípio da fase U), nome já dado pela spec-mãe da B9.

## As decisões (explicação; defaults adotados na aprovação)

Das três originais, **duas são decisões reais do Diego** (abaixo); a
terceira está dissolvida (seção própria no fim deste bloco).

### Decisão 1 — O que fazer quando a ferramenta *acha*, mas não *sabe*

Quando o comando analisa uma variável para descobrir a classe dela,
existem três níveis de certeza:

- **Nível 1 — certeza por leitura.** Tudo que é preciso já está
  declarado no código; a ferramenta só lê. Anotar aqui é seguro e
  incontroverso.
- **Nível 2 — vira certeza com uma linha.** Falta *uma declaração* no
  código (ex.: o construtor `New` herdado que ninguém declarou). A
  ferramenta pode **escrever essa linha** (`DECLARE UWMenu New() AS
  CLASS UWMenu`) e o caso sobe para o nível 1. Foi a descoberta da
  investigação: a linha existe na linguagem, custa zero no programa
  compilado (provado byte a byte) e fecha três lacunas de uma vez.
- **Nível 3 — palpite bem fundamentado.** A ferramenta olhou o projeto
  inteiro e concluiu a classe (ex.: "todos os chamadores desta função
  passam um objeto Peca"), mas **não existe linha que transforme isso
  em declaração**. Continua sendo conclusão da ferramenta — inferência
  de mundo fechado, exatamente o que o RE.3 tirou do veredito.

A pergunta é só sobre o nível 3: editar sob `--force` (verificado, mas
a primeira escrita é aposta) ou só relatar?
**Default adotado: NÃO edita, só relata.** Ainda não sabemos *quantos*
casos caem no nível 3; o relatório do F2.3 mede, e a decisão pode ser
revista no portão do meio com números na mão.

### Decisão 2 — Parar para ver os números antes de ligar a edição

O trabalho tem duas metades: a primeira é segura (docs, probes, spec
v2, comando em modo **só-relatório**) e produz a tabela de alcance; a
segunda edita de verdade (DECLAREs + `AS CLASS`, verificação e
rollback, casos de suíte, extensão VSCode).
**Default adotado: portão do Diego entre as metades** — ele examina a
tabela ("o que conseguimos") antes de abrir a edição.

### (ex-Decisão 3) O nome do comando — DISSOLVIDA por doutrina (Diego, 2026-07-09)

Não era decisão: a doutrina já escrita no repo dita a resposta.
"Genérico > específico" (CLAUDE.md) + o princípio da fase U (verbo =
AÇÃO; espécie do alvo = consequência do FATO, nunca classificação do
usuário) eliminam sufixos de espécie (`annotate-local`,
`declare-types`), a divisão em dois comandos e a classificação prévia
pelo usuário; e eliminam o "adiar para a fase U" — o `annotate` já
nasce no formato-alvo dela, então nenhum desfecho da fase U muda a
forma dele. O próprio NOME o projeto já tinha dado: a spec-mãe da B9
(§ Materialização, portão de 2026-07-08) já escrevia
`annotate <projeto> [--dry-run]`. Resíduo honesto: entre sinônimos
(`annotate`/`materialize`) não há fato que decida — é léxico, e a
convenção de não renomear sem causa mantém o que a spec usa. O comando
dedicado se justifica sob "razão forte": é AÇÃO nova (escrever
anotações), não espécie de ação existente — por isso não se dobra no
`usages` (só-leitura por contrato).

## Fatos estabelecidos pela investigação (com evidência)

Probes da sessão de 2026-07-09 (smoke1-4 em scratchpad/p1, compilados
e com dumps inspecionados); fonte lido no harbour-core.

1. **O cheque de tipos do compilador é vestigial.** A tabela de
   warnings tem a família inteira pronta (hbgenerr.c:114-150 —
   "Incompatible type in assignment", "Message not known in class"...)
   mas com **zero emissores** (`MESSAGE_NOT_FOUND` etc. só existem como
   `#define` em hberrors.h:161). Probe: `-w3` cala até no controle
   positivo (`u AS CLASS UWMenu; u:Bogus()`). Vivos: W0019 (dup),
   W0025 (classe desconhecida, só em sítio de declaração),
   PARAM_COUNT/PARAM_TYPE. **Não há inferência var-like no core** — o
   compilador registra e nunca conclui.
2. **hbclass declara mais do que a spec supunha.** Emissão de
   `_HB_CLASS`/`_HB_MEMBER` é default (hbclass.ch:84) e **método
   `CONSTRUCTOR` ganha retorno `AS CLASS`** (hbclass.ch:282). Dump do
   probe: `NEW {type S, class UWMENU}`.
3. **Uma linha fecha a cadeia no módulo consumidor.** `DECLARE UWMenu
   New() AS CLASS UWMenu` registra a classe no módulo + declara o
   membro + auto-declara a função-classe (probe smoke3, dump
   conferido) — compile-time puro, zero pcode, compila limpo `-w3`.
4. **`AS CLASS X` com X desconhecida no módulo DEGRADA** para 'O' com
   W0025 (hbmain.c:471-481) — a anotação perde a classe. Regra
   mecânica: o materializador garante a classe conhecida no módulo do
   site (a linha DECLARE faz isso de graça).
5. **Re-declarar classe já existente no módulo dá W0019** (probe
   smoke4) — sob `-es2` falha. Sites no MESMO módulo da classe (fixrcv
   r2, fixext e1) precisam da rota `_HB_MEMBER` avulsa (a provar —
   etapa F2.1).
6. **O `-kt` impõe DECLARE de FUNÇÃO** (embrulho do RETURN,
   harbour.y:433) — o DECLARE de fábrica materializado vira invariante
   checada. **DECLARE de MEMBRO não é imposto** (promessa; a impl de
   `New` herdado vive na RTL) — papel dele é só justificar *qual*
   classe escrever; a invariante que o produto reporta é a da local
   anotada (essa sim imposta e coberta, RE.2).
7. **`DeclTables` é projeto-wide** (hbrefactor.prg:5891-5914) — um
   DECLARE escrito no módulo do site alimenta o veredito em qualquer
   módulo.
8. **Topologia das sementes [FATIA-2]** (levantada fixture a fixture):
   fixcls = hbclass com `New` herdado, site cross-módulo (rota da
   linha DECLARE); fixrcv r2 = hbclass `Semctor` sem ctor, site no
   MESMO módulo (rota `_HB_MEMBER`, F2.1); fixext e1 = hbclass
   MULTI-classe no módulo (posicionamento importa, F2.1); fixmth/
   fixdis/fixb7 = DSLs sem classe compile-time (a linha DECLARE
   registra tudo); fixb7 b1 = fábrica `Cria()` (DECLARE de função —
   **imposto** pelo `-kt`); fixb7b q1 = retornos de método
   (`Pega`/`Soma`); q2 = DSL runtime-pura (Rota D/codeblock — fora,
   A6).

## A escada (o desenho que substitui P1-a/P1-b)

Pipeline bottom-up do `annotate`:

1. Análise com a máquina dormente (`B7Ctx` — único consumidor; mata o
   W0034 do build).
2. Para cada candidato: classifica **nível 1** (fato declarado puro) /
   **nível 2** (fecha com one-liners DECLARE/`_HB_MEMBER` — quais,
   exatamente, e onde) / **nível 3** (só inferência `via` — recusa
   nomeada, sem edição [Decisão 1]).
3. Edição (segunda metade): escreve primeiro os DECLAREs do nível 2,
   verifica, **re-analisa**, e então escreve os `AS CLASS` das locals
   já justificadas por fato declarado — **nunca por `via`**.
4. Verificação padrão-ouro por edição: `.hrb` byte-idêntico sem `-kt`
   → compila limpo `-w3 -es2` → roda com `-kt` (cheques passam) →
   rollback em qualquer falha.

P2 fica **resolvido por fato**: DECLARE de função = linha antes do
`FUNCTION`, no módulo DEFINIDOR (exigência do embrulho `-kt`, ordem de
parse); declaração de membro = módulo do SITE (cross-módulo) ou
`_HB_MEMBER` in-module (F2.1 prova).

## Etapas

### F2.0 — Registro dos fatos nos docs
`docs/ast-schema.md` (§ canal de tipos) e a spec ganham os fatos 1-7
com arquivo:linha e referência aos probes (idioma do RE.1: evidência
colada no doc, probes no scratchpad). `docs/roadmap.md` § B9 passa a
apontar este plano e os estágios com portões.
**Critério**: docs atualizados na mesma sessão; nenhum código tocado.

### F2.1 — Matriz de probes mecânicos (zero mudança na ferramenta)
Probes executáveis que fecham as mecânicas pendentes:
(a) `_HB_MEMBER` avulso após classe hbclass no mesmo módulo — sem
W0019? posicionamento em módulo multi-classe (fixext e1)?
(b) ordem DECLARE→FUNCTION para o embrulho `-kt` (fábrica: violação
dispara?); (c) DECLARE para classe runtime-pura (por nome);
(d) DECLARE cujo `AS CLASS` cita classe não registrada no módulo
(W0025 no próprio DECLARE — harbour.y:1244 — precisa de
`DECLARE_CLASS` antes?); (e) execução `-kt` real com DECLARE de
fábrica materializado; (f) **candidato de core** (esclarecimentos
pós-aprovação): `New` herdado declarado por default no compilador
(`_HB_CLASS` ⇒ membro implícito `NEW AS CLASS <própria>`, sobreposto
por declaração explícita) — protótipo + zero impacto; ADOÇÃO só no
portão do meio.
**Critério**: tabela "topologia do site → one-liner que fecha", cada
linha com probe compilado E executado.

### F2.2 — Spec v2
Reescrever `docs/spec-b9-fatia2-materializacao.md`: escada no lugar de
P1-a/P1-b; pipeline bottom-up; P2 por fato; recusas mecânicas
(W0019/W0025, `prov != 's'`, conjunto >1, A6/codeblock, memvar/field);
critério de aceite por semente [FATIA-2] com a rota que cada uma toma
(fato 8). Rota C continua sem promessa; Rotas D/E continuam fora.
**Critério**: spec no repo; roadmap apontando; testes-suspensos-re3
referenciado como semente obrigatória (inalterado).

### F2.3 — `annotate` estágio 1: relatório (zero edição)
Implementar o comando só com `--dry-run`/`--json` (o caminho de edição
nem existe ainda). Revive `B7Ctx` (W0034 morre). Classifica todo
candidato nos níveis 1/2/3 com os one-liners exatos do nível 2 e o
motivo nomeado do nível 3. Rodar em: sementes [FATIA-2], suíte inteira
de fixtures, work/hbhttpd.
**Critério**: tabela de alcance reproduzível registrada no roadmap
(e delta no limites-e-alavancas.md); suíte 622/0 byte-idêntica (o
comando novo não muda nada existente); build sem W0034.

### == PORTÃO DIEGO ==
O Diego examina a tabela ("o que conseguimos"), reavalia a Decisão 1
com números, e abre a segunda metade.

### F2.4 — `annotate` estágio 2: edição
Caminho de edição com a verificação padrão-ouro e rollback (reuso:
`WorkDir`/`RollbackAll`/`Refuse`); casos de suíte novos por semente
(cópia do fixture em WorkDir → annotate → recompila → usages asserta o
rótulo de FATO no MESMO site; fixtures originais intocados); recusas
assertadas (nível 3, W0019, W0025, pp, codeblock); extensão VSCode
`hbrefactor.annotate` + guardas no harness do caso 71 + bump de
versão.
**Critério**: round-trip por semente; caso de rollback provocado;
suíte verde byte-idêntica paralelo × `JOBS=1`; lexdiff limpo.

### F2.5 — Fechamento
Roadmap: fase fechada com uma linha + narrativa no arquivo;
testes-suspensos-re3: itens reconquistados marcados (SÓ os que a
escada fechou de fato — honestidade sobre o resíduo); M-cov re-rodada
com delta registrado.
**Critério**: regra de arquivamento do roadmap cumprida na mesma
sessão.

## Arquivos a tocar

- `docs/ast-schema.md`, `docs/spec-b9-fatia2-materializacao.md`,
  `docs/roadmap.md`, `docs/limites-e-alavancas.md`,
  `docs/testes-suspensos-re3.md` (F2.5)
- `src/hbrefactor.prg` (comando novo; reuso da máquina dormente
  `B7Ctx`/`TypeOf`/`SendReceiverType` hbrefactor.prg:6288/5972/6204,
  `DeclTables`/`DeclType` :5891/:5921, idioma WorkDir/rollback)
- `vscode/extension.js` (F2.4)
- `tests/run.sh` + fixtures/casos novos (F2.4)
- harbour-core: **nada** (nenhuma mudança no core nesta fatia; os
  probes só compilam/executam)

## Verificação (fim a fim)

Cada etapa tem critério executável próprio (acima). Fechamento:
`make test` verde e byte-idêntico paralelo × `JOBS=1`; `make lexdiff`
limpo; build da ferramenta sem W0034; fixtures anotados EXECUTADOS sob
`-kt` (cheques disparando em violação provocada — não só compilação);
extensão validada pelas guardas do caso 71.

## Riscos e honestidades declaradas

- DECLARE de membro é promessa não-imposta (fato 6) — a spec v2
  declara a assimetria; a invariante reportável é a da local anotada.
- `_HB_MEMBER` avulso é sensível à ordem (`pLastClass`) — F2.1 prova
  antes de qualquer uso; módulo multi-classe exige posicionamento.
- Os números do corpus podem ser modestos — o relatório é o retrato
  honesto, não uma promessa.
- Rota C (exclusão de homônimo) segue SEM ROTA; Rota D (codeblock)
  segue bloqueada por A6+RE.5; nada aqui as promete.
- Commits: um por pedido do Diego, com autorização explícita (regra do
  repo).
