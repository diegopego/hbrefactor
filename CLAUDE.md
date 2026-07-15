# hbrefactor

Refatoração automatizada para Harbour sobre a AST do compilador
(dump `.ast.json` do branch feature/compiler-ast-dump). Fontes de verdade:
docs/roadmap.md, docs/ast-schema.md e o Makefile — LER antes de codar.

**Este arquivo é a lei; `docs/cicatrizes.md` é a jurisprudência** — cada regra aqui é
um imperativo curto com uma linha de porquê, e o erro concreto que a comprou está lá,
datado (as referências `[cic §N]` apontam para a seção). Antes de achar que uma regra é
excesso de zelo, leia a cicatriz dela. Regra nova entra AQUI; a narrativa dela, lá.

---

## 1. A REGRA DO FATO — o princípio central

**Meta: ZERO INFERÊNCIA.** O hbrefactor age só sobre FATO produzido por compilação.
Nada de heurística, nada de réplica de gramática, nada de TRIAGEM (ajuda probabilística
para conferência manual não é produto). Quando o fato não existe, o caminho é
(a) **estender o core** para o fato passar a existir, ou (b) **usar ferramenta do core**
como oráculo (compilador-biblioteca, hbmk2, `.ppt`, tabelas DECLARE) — **nunca**
construir inferência. *(Diego, 2026-07-08.)*

- **CORE = qualquer coisa oficial do projeto Harbour**, não só o compilador: hbrun,
  hbmk2, hbpp, RTL/VM, utilitários, a árvore inteira. Estender ou usar qualquer um deles
  vence qualquer esperteza na ferramenta.
- **O princípio vale para TODO construto** (função, local, var, método, marker, palavra
  de DSL) — **classes são só um caso**. O Harbour se apoia em diretivas para criar açúcar
  sintático: DSLs e comandos novos, do core ou inventados pelo programador no próprio
  aplicativo. O hbrefactor refatora QUALQUER código, com ou sem açúcar, **sem ajustes**
  quando diretivas criam açúcar novo. Fato faltante → fato de compilação ou relato honesto
  (`possible`/recusa com rollback); nunca ajeito, nunca árvore quebrada.
- **Prova executável**: casos 64 e 72-74 (régua: nenhuma palavra de DSL de fixture em
  `src/hbrefactor.prg`). Capacidade entregue sobre hbclass só conta como genérica com
  prova adversarial em DSL inventada NÃO-espelho — régua de `docs/revisao-generalidade.md`
  (revisão concluída em 2026-07-07; o doc segue como régua para trabalho futuro).
- **Nunca editar o não-verificável**: a ferramenta só aplica o que o oráculo prova e a
  recompilação verifica. Conteúdo sem verificação (strings, dados, comentários) recebe
  detecção e relato preciso, **jamais** edição automática — nem com opt-in.
- **Genérico > específico**: comando dedicado só com razão forte (o `usages-dsl` foi
  absorvido pelo `usages`); ao consumir fatos de pp, operar sobre o genérico
  (cabeça/kind/marker), nunca por DSL/família conhecida.

### 1.1 O PORTÃO DE AUTORIZAÇÃO — a ordem não se pula

Heurística e réplica são **PROIBIDAS por padrão**, e a exploração do core vem **ANTES**
de projetar a solução. *(Diego, 2026-07-12; a regra já existia e eu a quebrava assim
mesmo — o que faltava não era regra, era PORTÃO. [cic §1.1])*

1. **Explore primeiro se o core pode dar o fato.** Projetar a solução na ferramenta e só
   depois perguntar isso é ordem invertida: quando a solução já está desenhada, a
   heurística já venceu.
2. **Se o core pode → o core faz.**
3. **Se o core NÃO pode → isso é uma RECUSA**, e recusa exige varredura registrada (§1.3).
4. **Só então, e SÓ COM AUTORIZAÇÃO EXPLÍCITA DO DIEGO PARA AQUELE CASO**, pode existir
   heurística no hbrefactor. Portão por-caso, igual ao de commit: aprovar um não aprova o
   próximo.

**Como pedir:** (a) o fato que falta, (b) a varredura feita no core, (c) por que o core
não pode dar, (d) a heurística proposta e **onde ela erra**.
**É PROIBIDO** implementar "provisoriamente" e pedir depois — o código provisório é o que
fica.
**O portão é executável:** o hook `.claude/hooks/anti-heuristica.sh` (PreToolUse/Bash)
intercepta o `git commit` e recusa o diff staged de `src/hbrefactor.prg` que cheire a
gatilho. Autorizado, sela-se a linha com
`// FATO-OK(diego,AAAA-MM-DD): <por que o core não pode dar este fato>` — e o selo só se
escreve **depois** do "ok" dele. Auditoria periódica: `docs/prompt-revisao-anti-heuristica.md`.

### 1.2 GATILHOS — os cheiros que obrigam a parar e ir ao core

Ao escrever QUALQUER uma destas linhas, **PARE** e pergunte "o core sabe isto e não me
conta?". *(Catálogo de erros, 2026-07-12 — cada gatilho tem um cadáver embaixo: [cic §1.3])*

1. **Comparação de TEXTO para decidir PAPEL/IDENTIDADE** (`Upper(a) == Upper(b)`, prefixo,
   `Left()`, `$`) quando o dump já tem número/id/índice.
2. **Constante mágica de gramática** (`>= 4`, `Len() > N`) — é réplica de regra do
   compilador.
3. **"se não é X, então é Y"** sem um fato que SEPARE X de Y.
4. **Re-implementar resolução/busca que o core faz** (achar include, casar nome, expandir).
5. **Casar arquivo por BASENAME** em vez de caminho canônico.
6. **Escolher o canal MAIS BARATO**: *"tem que usar o canal CORRETO, não apenas o mais
   barato"* (Diego). Barato ≠ correto.
7. **OBSERVAR o core em vez de PERGUNTAR a ele** — raspar log, saída de trace, efeito
   colateral de build. O que se observa é o que a ferramenta do core **estava fazendo**;
   o que se pergunta é o **fato**. Se não há canal de pergunta, **crie-o no core**.
   *(Custou o `LoadProject` inteiro: [cic §1.3c])*

**Falta de informação → VÁ AO CORE, IMEDIATAMENTE.** A missão é fazer o core gerar o
MÁXIMO de informação necessária. **"Zero mudança no core" NÃO é virtude — é sinal de
alerta**: se um conserto precisou de esperteza na ferramenta, quase sempre o fato faltava
no core e a esperteza é o sintoma. *(Diego, 2026-07-12. [cic §1.2])*

**ESTENDER O CORE É O CAMINHO PADRÃO, NÃO A EXCEÇÃO** *(Diego, 2026-07-13)*: identificada
uma necessidade, a pergunta certa é *"como o core passa a responder isto?"* — e não *"como
eu me viro com o que ele já dá?"*. **É isto que temos que fazer ao máximo possível.**
- **Para PROJETO, o hbmk2 é SEMPRE a fonte de verdade** — build, quais arquivos compõem o
  projeto, includes, flags. Ele é core. Nada de parse nosso, nada de inferência.
- **Ao estender: NUNCA mude a saída de um comando existente — crie um comando NOVO**
  *(Diego, 2026-07-13)*. Quebrar quem já consome o core é inaceitável, e o PR morre.
  *(Foi assim que nasceu o `hbmk2 --hbproject`: o `--hbinfo` ficou byte-idêntico.)*

### 1.3 Nunca declare IMPOSSÍVEL sem VARRER a superfície do core

Toda recusa ("o pp não consegue X") é uma **afirmação sobre o CORE** e exige varredura
ANTES, com o que foi varrido **registrado na spec**: (a) `harbour`/`hbmk2` `--help`
inteiro (flags existem e são esquecidas: `-gd`, `-sm`, `-u`, `-p`/`-p+`); (b) a **API
pública** (`include/hbpp.h` e afins); (c) **`tests/` do core** — é lá que a API viva
aparece; (d) ChangeLog.
**Silêncio de busca minha NÃO é evidência de ausência**; "não achei" quase sempre é "não
procurei". *(Custou um veredito errado publicado: [cic §1.4])*

### 1.4 Editar o harbour-core não é permissão — é DEVER

A ferramenta age só sobre fato da AST; a AST é produzida pelo core; logo **moldar a AST**
— estendendo o core para o fato existir — faz parte da definição da ferramenta. Uma
ferramenta que não pode construir a AST de que precisa está amputada do próprio princípio.
*(Diego, 2026-07-09.)*

Permissão **total e esperada** de editar `~/devel/harbour-core/harbour` (branch
`feature/compiler-ast-dump`, acesso no `.claude/settings.json`). O único freio é o de
sempre: **commit no core continua sob autorização por-commit do Diego** — não editar ≠
não commitar.

### 1.5 Não existe compatibilidade para trás — a ferramenta está sendo INVENTADA

O dump é gerado **na hora**, a cada comando, pelo `harbour` do `HB_BIN`. Logo **não existe
"dump antigo"**: existe **toolchain fora de passo**, que é erro de build — e erro de build
se **BERRA**, nunca se degrada. *(Diego, 2026-07-13. [cic §2.1])*

- O schema é **EXATO** (`AstSchema()`, um só lugar), não piso e jamais lista enumerada —
  divergiu, recusa alta nomeando as duas versões.
- **Nenhum portão de degradação por versão** ("dump sem o canal X degrada para possible"):
  degradar rebaixaria o **VEREDITO** por causa de um build velho, **calado**.
- A suíte **sempre roda no schema corrente**; o **caso 122** fica vermelho no instante em
  que core e ferramenta divergirem.

### 1.6 A IA é CONSUMIDORA de fato — jamais FONTE de fato

*(Diego, 2026-07-13. Fase A no roadmap; spec: `docs/spec-a-oraculo-para-agentes.md`.)*

**O agente propõe a INTENÇÃO; a ferramenta decide o que é PROVÁVEL, executa verificando, e
recusa com MOTIVO.** LLM é máquina de **heurística**; o hbrefactor é máquina
**anti-heurística**. Não é contradição — é **complementaridade**, e é ela que dá sentido ao
produto: o programador vai pedir a um LLM *"renomeie este método no projeto inteiro"*, o LLM
vai fazer isso por **substituição de texto** — com confiança, e errado —, e **esse é
exatamente o modo de falha que esta ferramenta existe para eliminar**. O agente não é "mais um
consumidor": é o que **mais precisa** de um oráculo de fato.

- **NÃO-OBJETIVO:** a ferramenta **não tem modelo, não tem chave de API, não fala com rede, e
  NUNCA pergunta nada a um LLM**.
- **Tratar IA como cidadã de primeira classe muda a SUPERFÍCIE, jamais o motor** — saída
  estruturada, código de motivo na recusa, o verificador exposto. Nenhum princípio desta seção
  cede em nome de "ser AI-first"; se ceder, o rótulo virou **cavalo de Troia da heurística**.
- **A recusa tem de ser legível para o agente RELATAR, não para CONTORNAR.** Recusa que o
  agente não entende não protege ninguém — ele volta a **editar o texto na mão**. Todo código
  de recusa diz o que FAZER: *"pare e conte ao humano"* × *"repita com a flag"* × *"seu projeto
  não compila"*.
- **Corolário do lado da CRIAÇÃO:** contra o modo de falha de um contribuidor heurístico (que é
  o que eu sou), o que funciona neste repo é **portão EXECUTÁVEL**, não documento — o hook
  `anti-heuristica.sh`, a régua-grep do caso 64, o schema que berra. **Regra nova sem portão
  novo é regra que eu vou violar de novo.**

---

## 2. Core e toolchain

- **Buildar o core após editar — 3 armadilhas** *(Diego, 2026-07-11. [cic §5.1])*:
  (a) mudança no compilador exige rebuildar `harbour` **E** `hbmk2` (o hbmk2 EMBUTE o
  compilador); (b) o `make` mente "up to date" e não relinca → apagar os binários
  (`rm bin/linux/gcc/harbour bin/linux/gcc/hbmk2`) e refazer; (c) `HB_REBUILD_PARSER=yes`
  regenera o `obj/<plat>/harboury.c`, **não** os `harbour.yyc`/`.yyh` commitados — copiar
  à mão e commitar os três juntos (`.y` + `.yyc` + `.yyh`), conferindo que um rebuild
  default carrega a feature.
- **Exportar `HB_BIN` ao invocar a ferramenta fora do Makefile**: sem ele o `HbMk2Bin()`
  cai no hbmk2 do sistema e o sintoma é o enganoso "o projeto não compila". *([cic §5.2])*
- **Ferramenta do core: PROBE, nunca memória**: antes de consumir a saída de um utilitário,
  sonde ONDE ele escreve e O QUE reporta — com fonte em **subdiretório** (o caso que
  quebra). Não se adivinha o destino: manda-se (`-o<tmp>`). **Depois de qualquer comando
  que rode o compilador ao lado dos fontes, conferir `git status`** — `.d`/`.ppo`/`.c`
  vazam para o repo. *([cic §1.5])*
- **Chave OPCIONAL do dump: sempre `hb_HGetDef`** — campo que só existe em ALGUNS papéis
  (`marker`, `ruletok`, `from`, `generates`, `col`) acessado direto é BASE/1132 em
  produção, e a suíte não pega. Ler o contrato no ast-schema.md ANTES. *([cic §1.6])*
- **Reutilizar o hbmk2** (builder oficial) para projeto/flags/build: entende `.hbp`/`.hbc`,
  resolve `-I`/`-D` (`hbmk2 -trace` expõe a linha do harbour), repassa `-prgflag=`. Todo
  parsing paralelo é cópia degradada que diverge.
- Fluxos definidos vivem no **Makefile**; hbmk2 direto é só experimentação.

---

## 3. Testes, suíte e corpus

- **Contrato executável: `make test`** — deve permanecer verde.
- **Compile todo `.prg` (fixture, exemplo, teste) ANTES de usá-lo** —
  `$HB_BIN/harbour arquivo.prg -n -q0` ou o projeto via hbmk2. Fixture que não compila
  gera diagnóstico enganoso.
- **`make test JOBS=1` só ao mexer no RUNNER** *(Diego, 2026-07-10)*: o contrato "paralelo
  × JOBS=1 byte-idêntico" é propriedade da INFRA (bin/parrun, `--unit` do run.sh, join),
  não do conteúdo dos testes. Rodar JOBS=1 apenas quando a mudança tocar o runner ou
  introduzir saída potencialmente não-determinística (ex.: imprimir na ordem de iteração
  de um hash).
- **Drift em teste PRÉ-EXISTENTE → consultar o Diego** *(2026-07-10)*: o projeto é um
  experimento VIVO — há motivos legítimos tanto para adaptar o código aos testes quanto
  para **re-baselinar** os testes (contrato que evoluiu). **A premissa errada pode ser a do
  teste, e quem decide qual lado cede é o Diego**: apresentar o drift site a site (o que
  mudou, por quê, qual contrato está em jogo) ANTES de escolher o lado. Teste novo da
  própria entrega não precisa de consulta; re-rotular expectativa antiga, sim.
- **CORPUS DE MATURAÇÃO = código do CORE do Harbour** *(Diego, 2026-07-10)*: a ferramenta
  amadurece em código bem escrito e testado (`work/` = cópias de pastas do core; copiar
  mais pastas quando a fase pedir). O código do Diego (`~/devel/bravo-experimento*`) é
  bagunçado e pré-melhores-práticas — serve para exploração pontual e SÓ isso, **nunca**
  como régua de valor de fase nem alvo de entrega. *(Nuance da **xhb**: braço xHarbour,
  não-mantido — vale como corpus de MEDIÇÃO, mas número vindo só dela não justifica
  capacidade sozinho.)*
- **ESTUDAR CLASSE: os dois pontos de partida** *(Diego, 2026-07-13)* — vale para qualquer
  frente que toque OOP (tipo de receiver, rename de DATA/método, dispatch, herança):
  - `~/devel/harbour-core/harbour/include/hbclass.ch` — a **DSL inteira** (`CREATE CLASS`,
    `METHOD`, `DATA`, `VAR`, `INLINE`, `DELEGATE`, escopos): é o açúcar que a ferramenta
    tem de atravessar, escrito em `#command`/`#translate` de verdade.
  - `~/devel/harbour-core/harbour/utils/hbtest/rt_class.prg` — o **exercício** dela pelo
    core: as formas todas em uso, compilando, com oráculo executável.

  Continua valendo a régua do corpus: espécime é fonte do core, nunca exemplo que eu
  invento (§ acima) — e o que eu **entender** aqui não vira gatilho em `src/hbrefactor.prg`
  (§1: capacidade sobre hbclass só conta como genérica com prova adversarial em DSL
  inventada).

---

## 4. Medição e anúncio

- **O número que se ANUNCIA é o do PRODUTO rodando como o usuário roda** (comando
  completo, projeto real do corpus), nunca o do microbenchmark. O stress serve para achar
  a **curva** (quadrática × linear), não para dimensionar a notícia. *(Diego, 2026-07-13.
  [cic §3.1])*
- **"Tamanho típico de aplicação real" é uma afirmação sobre o mundo** — ou se mede no
  corpus, ou não se escreve. Afirmar sem medir é a heurística vestida de manchete.
- **O projeto do benchmark tem de PASSAR**: conferir o **exit** E que ele **leu/analisou**
  de fato. Cronometrar processo não é medir trabalho — **comando que morre também gasta
  segundos**. *([cic §3.2])*
- **NÃO PUBLIQUE TABELA DE BENCHMARK**: ela não serve ao leitor (não é a máquina dele, nem
  o projeto dele) — serve ao autor, como defesa. No anúncio vai a **afirmação** + o
  **comando** para o leitor medir no projeto dele. *([cic §3.3])*
- **NENHUM NÚMERO NAS PÁGINAS — todo indicador vira COMANDO** *(Diego, 2026-07-13)*: nenhum
  tamanho de suíte, contagem de casos ou de schemas nas `site/index.html` (dos DOIS
  repositórios). O leitor recebe o comando que ele roda (`make test`,
  `tools/pcode-identity.sh`, `git diff --stat`) — e comando não envelhece. **Automatizar um
  número frágil é pior que não tê-lo.** *([cic §3.4])*
- **EXEMPLO NA PÁGINA: só o que se EXECUTA sozinho** *(Diego, 2026-07-12)*: nenhum bloco de
  fonte e nenhuma saída de terminal da `site/index.html` se escreve à mão. Os exemplos
  vivem em `tests/site/` (contrato em `tests/site/README.md`), `make site-examples`
  re-executa e regrava os blocos, e **`make site-check` FALHA** se a página divergir.
  Quatro portas por exemplo: o fonte ANTES compila limpo, o comando sai com o exit
  esperado, o fonte DEPOIS compila limpo, e recusa/relatório deixam o fonte **byte a byte
  intacto**. *([cic §3.5])*
  **Dívida aberta**: as seções profundas da página (rename de DATA, genealogia de regra,
  tempo de vida de diretiva, sequestro por abreviação) ainda têm transcript colado à mão —
  corretos hoje, mas FORA do portão; migrá-los para `tests/site/`.
- **Números em `docs/roadmap.md`, specs e mensagem de commit CONTINUAM** — lá são registro
  datado da entrega, não promessa viva ao leitor.
- **VERIFICAR A BASE antes de concluir dela**: antes de comparar contra qualquer ref,
  `git fetch` e conferir a que altura ela está — **o fato do diff é tão bom quanto a base
  dele**. Base do branch do core = `upstream/master`, nunca o `master` local. *(O `push` do
  `upstream` está **DISABLE** de propósito. [cic §3.6])*

---

## 5. Documentação, idioma e anúncio ao usuário

- **O PRODUTO É EM INGLÊS; a CONVERSA é em português** *(Diego, 2026-07-13)*. A régua não é
  o repositório, é **quem lê**:
  - **Inglês** (lido pelo usuário): mensagens da CLI, `docs/manual.md`, `site/index.html`,
    `CHANGELOG.md` e **toda string que a extensão VSCode mostra** (modais, placeholders,
    erros).
  - **Português** (nossa conversa e nosso raciocínio): `CLAUDE.md`, `docs/roadmap.md`,
    specs, `tests/*/README.md`, comentários do fonte, e a mensagem de commit **do
    hbrefactor**. *([cic §4.1])*
- **TUDO no harbour-core é em INGLÊS**: código, comentário, documentação **e mensagem de
  commit** — o projeto é internacional e este branch é upstreamável (fase B6). *(Diego,
  2026-07-12. [cic §4.2])*
- **DOIS changelogs de USUÁRIO, um por repositório** — `CHANGELOG.md` aqui, **`NEWS.md`** no
  core *(a assimetria é deliberada e **não se re-litiga**: [cic §4.4])*. **Cada repositório
  com commit novo ganha a sua entrada.**
  - **O público é o PROGRAMADOR HARBOUR FINAL, nunca o contribuidor**: o problema de todo
    dia, o que muda na prática (antes/depois quando couber), o que a ferramenta NUNCA faz,
    e os limites honestos. **O changelog do contribuidor já existe e é o git.** A entrada só
    se justifica ao responder o que o git NÃO responde: *"o que eu passo a poder fazer, e
    onde isso me morde?"*
  - **Reprova o CORPO da entrada que contiver**: nome de função C / arquivo de
    implementação, nome de struct, jargão de build, número de caso da suíte, sigla de fase.
    *(Ponteiro para docs internos no FIM da entrada é permitido; citar a saída REAL da
    ferramenta é sempre permitido.)*
  - **Ponteiro de delta** no topo (`<!-- changelog-baseline: <repo>@<sha> -->`): o último
    commit já descrito. É o que torna o serviço **retomável** (`git log <baseline>..HEAD`
    diz o que falta). Fluxo e régua na skill `/update-manual`. *([cic §4.3])*
- **PIPELINE DO CORE: `commit → NEWS.md → landing page`** *(Diego, 2026-07-12)*. A
  `harbour-core/site/index.html` é uma **proposta aos MANTENEDORES** — é ela que decide se o
  PR (fase B6) é sequer avaliado. **Não é um log**: não ganha seção por commit nem lista
  schema; carrega o **conceito consolidado** (argumento central, forma do diff, os quatro
  canais, os bugs do stock que o branch conserta, o pedido ao mantenedor, e o que ainda não
  sabemos). Muda **só quando o conceito muda** — "não mudou" é resposta legítima. **Nenhum
  número nela sem medição na hora.** Checklist na skill `/update-manual` (§ 0.4b).
- **`docs/roadmap.md` é minha responsabilidade e vive preenchido**: fases futuras com escopo
  + critério de pronto ANTES de executá-las; concluída uma fase, atualizar o status na mesma
  sessão; trabalho novo entra como fase/item.
  **Plano ≠ spec** *(ordem do Diego)*: o **plano** (plan mode) decide *como* e *quais
  requisitos* — é o documento de análise/design/racional. A **spec executável** mora no
  `docs/roadmap.md`, no formato das fases existentes (`### Fase X — Título`, `**Escopo**`,
  `**Critério de pronto (mecânico)**`). Ao terminar um plano de código, transforme-o em
  spec e adicione ao roadmap — **não implemente no mesmo passo**, salvo pedido explícito.
- **Extensão VSCode sempre com os últimos recursos**: todo comando/capacidade nova do CLI
  tem que chegar à `extension.js` — expô-la é escopo da fase que a entrega, não fase
  adiável (é o consumidor de uso diário do Diego).

---

## 6. Processo

- **Commits só com autorização explícita do Diego PARA AQUELE commit** — concluir/aprovar o
  trabalho não autoriza o commit. Um pedido por commit, não encadear. **Sem push salvo
  pedido.**
- **GitHub é pelo `gh`** *(Diego, 2026-07-13)*: autenticação e operações via `gh` CLI
  (logado como `diegopego`, ssh), nunca o credential-manager do Windows. *([cic §5.4])*
- **Revisão externa via Codex (`/codex:rescue`)**: o brief é instrumento versionado em
  `docs/` e **não se contamina com o juízo do Claude**; achado externo é **HIPÓTESE** até
  verificação no fonte com arquivo:linha — nunca agir direto sobre o relato. **Tarefa Codex
  pode morrer em silêncio**: antes de esperar conclusão, conferir `ps -p <pid>`; morto =
  cancelar e re-executar com `--model` explícito. *([cic §5.5])*
- **`smoketest/hbrefactor-occ.prg` é a primeira encarnação, arquivada**: só leitura, nunca
  editar.
- **Regra/preferência durável deste repo vai AQUI** (versionado), não na memória privada do
  Claude (que não viaja com o repo); a memória fica para o que não pertence a um repo.

---

## 7. Harbour (linguagem) — armadilhas ao escrever fixtures/.prg

Os fixtures da suíte são `.prg` idiomático (o "caso 0" exige saída limpa sob `-w3 -es2`).

- **Código NOVO nosso usa `#xcommand`/`#xtranslate`, nunca `#command`/`#translate`**
  *(Diego, 2026-07-12)*: provado no dispatch do core (`ppcore.c`) que o `x` significa
  **exatamente e somente** "comparação EXATA" em vez do **dBase** (que casa a palavra
  abreviada a partir de 4 letras). Nenhuma capacidade se perde — e a família dBase é a
  origem de uma CLASSE INTEIRA de ambiguidade (sequestro de regra, recusa falsa, cabeças
  disputando prefixo); na família `x` esses bugs são **impossíveis**. Vale para fixture,
  exemplo, doc e sonda que EU escrever. *(Existe ainda a família `y` — exata E
  case-sensitive.)*
  **DUAS exceções, ambas obrigatórias:** (a) fixture cujo **assunto** é a abreviação dBase
  (`fixabr`/caso 115, `fixseq`/caso 116, o par de cabeças do `fixdsl`) — trocar para `x`
  faria o teste passar por **vacuidade**; (b) a **ferramenta** jamais pode abandonar
  `#command`/`#translate`: ela refatora o código dos OUTROS, e o `std.ch`, o `hbclass.ch` e
  toda a herança Clipper são dBase. **A política é sobre o que escrevemos, nunca sobre o
  que suportamos.**
- **Não nomear variável formando keyword em uppercase**: Harbour é case-insensitive e lê
  identificadores em uppercase — `LOCAL nIL` vira a reservada `NIL` (`E0030`). Evitar
  `nIL`, `cFor`, etc.
- **MEMVAR antes de PRIVATE/PUBLIC**: sem a declaração compile-time, W0002 na criação e
  W0001 em cada uso — com `-es2` o build falha. Idioma: `MEMVAR xCfg` / `PRIVATE xCfg := 7`.
- **`LOCAL x := 0` seguido de `x := <valor>` é DEAD STORE → W0032 → quebra sob `-es2`**: o
  Harbour avisa que o **inicializador** nunca é lido, mesmo que a variável seja lida depois.
  Idioma: declarar **sem** inicializador (`LOCAL nEdits`), ou usar `+=` (que LÊ). *(A
  mensagem "assigned but not used" engana. [cic §6.1])*
- **Comentário de linha `//` em .prg** (não `/* */`): um `*/` que apareça no conteúdo (ex.:
  `assert_*/`) fecha o bloco antes da hora. Aplicar em código novo/editado, sem conversão em
  massa.
- **A régua do caso 64 vale para COMENTÁRIO também**: ela é textual — citar a DSL de uma
  fixture num comentário de `src/hbrefactor.prg` QUEBRA a suíte, e está **certa** em
  quebrar. Ilustre o formato genericamente ("keyword secundária prefixo da cabeça"), nunca
  com as palavras da fixture. *([cic §6.2])*
- **Coluna de probe/teste: COMPUTAR, nunca contar na cabeça** — extrair sempre do arquivo no
  estado **corrente** (`python3 -c "...l.index('<n>')+1"`). Dump é 0-based, CLI é 1-based; o
  `col` de um marker aponta o **NOME**, não o `<`. *([cic §6.3])*
- **Verificar comportamento no fonte do Harbour ANTES de afirmar** (não teorizar): ler/grep
  o `src/` relevante. Ex.: `Empty(" ")` é `.T.` — usar `Len(c) == 0` para "vazia".
- **Diagnóstico do IDE ≠ veredito**: o lint do VSCode usa o harbour do **sistema**, sem os
  patches do branch. A régua é sempre o toolchain de `HB_BIN`. *([cic §5.3])*
