# hbrefactor

Refatoração automatizada para Harbour sobre a AST do compilador
(dump `.ast.json` do branch feature/compiler-ast-dump). Fontes de verdade:
docs/roadmap.md, docs/ast-schema.md e o Makefile — LER antes de codar.

## Regras de trabalho

- **O hbrefactor CONSTRÓI a AST de que precisa — editar o harbour-core
  não é só permitido, é DEVER (Diego, 2026-07-09)**: o preceito fundador
  é que a ferramenta age só sobre FATO da AST do compilador; a AST é
  produzida pelo core; logo *ser capaz de moldar a AST* — estendendo o
  core para o fato passar a existir — é parte da definição da ferramenta,
  não uma exceção tolerada. Uma ferramenta que não pode construir a AST
  de que precisa está amputada do próprio princípio. Permissão TOTAL e
  esperada de EDITAR a árvore do core em
  `~/devel/harbour-core/harbour` (branch `feature/compiler-ast-dump`;
  acesso concedido no `.claude/settings.json`) sempre que a REGRA DO FATO
  pedir. O único freio é o de sempre: **commit no core continua sob
  autorização por-commit do Diego** (não editar ≠ não commitar). É a
  perna concreta da REGRA DO FATO ("estender o core para o fato existir").
- **CORPUS DE MATURAÇÃO = código do CORE do Harbour; o código do Diego
  NÃO é régua (Diego, 2026-07-10)**: a ferramenta amadurece resolvendo
  problemas em código BEM ESCRITO E TESTADO do core (work/ = cópias de
  pastas extraídas de `~/devel/harbour-core/harbour` — tests, hbhttpd;
  copiar MAIS pastas pertinentes do core quando a fase pedir). O código
  do Diego (`~/devel/bravo-experimento*`) é bagunçado e
  pré-melhores-práticas (ex.: PRIVATE em massa, que o próprio Harbour
  desaconselha) — serve para EXPERIMENTAÇÃO/EXPLORAÇÃO pontual e SÓ
  isso; nunca como régua de valor de fase, nunca como alvo de entrega.
  Só viramos para o bravo quando hbrefactor + branch do core estiverem
  funcionando bem no código do core. REVOGA o "a régua final é o
  dogfooding no código do Diego" que os docs repetiam (notas datadas em
  limites-e-alavancas.md; não propor dogfooding no bravo como critério
  de decisão). Nuance da **xhb** (Diego, 2026-07-10): é do braço
  xHarbour, marcada como NÃO-mantida pelos mantenedores do core —
  funcional e cheia de ideias interessantes, vale como corpus de
  MEDIÇÃO, mas código novo não deve usá-la; número vindo só dela não
  justifica capacidade sozinho.
- **Compile todo .prg (fixture, exemplo, teste) ANTES de usá-lo em
  qualquer teste** — `$HB_BIN/harbour arquivo.prg -n -q0` ou o projeto
  via hbmk2. Fixture que não compila gera diagnóstico enganoso.
- Fluxos definidos vivem no Makefile; hbmk2 direto é só experimentação.
- **Exportar `HB_BIN` ao invocar a ferramenta fora do Makefile**: sem ele o
  `HbMk2Bin()` cai no hbmk2 do SISTEMA (`/usr/local/bin`, sem `-x`) e o
  sintoma é o enganoso "o projeto não compila" (custou um diagnóstico na
  P2a; a suíte exporta, invocação manual esquece).
- Nenhuma réplica de gramática na ferramenta: fatos vêm do compilador
  (dump ast, hb_compileFromBuf, harbour.hbx).
- Reutilizar o **hbmk2** (builder oficial) para projeto/flags/build: entende
  `.hbp`/`.hbc`, resolve `-I`/`-D` (`hbmk2 -trace` expõe a linha do harbour),
  repassa `-prgflag=`. Todo parsing paralelo é cópia degradada que diverge —
  reescrever só o estritamente necessário.
- Contrato executável: `make test` (deve permanecer verde).
- **Drift em teste PRÉ-EXISTENTE → consultar o Diego (2026-07-10)**: o
  projeto é um experimento VIVO — quando uma mudança faz testes que já
  existiam divergirem, há motivos legítimos tanto para adaptar o código
  aos testes quanto para RE-BASELINAR os testes (contrato que evoluiu,
  ex.: caso 88 no RE.5). A decisão de qual lado cede é do Diego:
  apresentar o drift site a site (o que mudou, por quê, qual contrato
  está em jogo) ANTES de escolher o lado. Teste novo da própria entrega
  não precisa de consulta; re-rotular/mover expectativa antiga, sim.
- **roadmap.md é minha responsabilidade e vive preenchido**: fases futuras com
  escopo + critério de pronto ANTES de executá-las; concluída uma fase,
  atualizar o status na mesma sessão; trabalho novo entra como fase/item.
  Decisões de produto e autorizações continuam com o Diego.
- **CHANGELOG.md para o programador final (Diego, 2026-07-09)**: toda
  capacidade/entrega ganha entrada no CHANGELOG.md escrita para o
  programador Harbour FINAL — o problema de todo dia, o que muda na
  prática (exemplo antes/depois quando couber), o que a ferramenta
  NUNCA faz, e os limites honestos da entrega. Sem jargão interno de
  fase (B9/F2.x ficam nos docs; a entrada só aponta para eles no fim).
  Atualizar na mesma sessão da entrega, como o roadmap.
- **Genérico > específico**: comando dedicado só com razão forte (o
  `usages-dsl` foi absorvido pelo `usages`); ao consumir fatos de pp, operar
  sobre o genérico (cabeça/kind/marker), nunca por DSL/família conhecida.
- **A REGRA DO FATO — META: ZERO INFERÊNCIA (Diego, 2026-07-08; revoga a
  escada "inferência antes de linguagem" do mesmo dia)**: o hbrefactor
  lida com FATOS. Nada de heurística e nada de TRIAGEM (ajuda
  probabilística para conferência manual não é produto). Quando o fato
  não existe em compilação, o caminho é (a) **ESTENDER O CORE** para o
  fato passar a existir (novo canal/invariante — ex.: tipos declarados
  IMPOSTOS, spec-b9) ou (b) **usar ferramenta do core** como oráculo
  (compilador-biblioteca, hbmk2, `.ppt`, tabelas DECLARE) — **nunca
  construir inferência**. A inferência existente (B7/B7b) fica como
  está e converge para SUGERIDORA de anotações (o ciclo virtuoso do
  mapa: a análise materializa `AS CLASS` provados → o core os impõe →
  o veredito vira fato), não como fonte de veredito de longo prazo.
  **Definição de CORE (Diego, 2026-07-08)**: core = QUALQUER coisa que
  exista oficialmente no projeto Harbour — não só o compilador. hbrun,
  hbmk2, hbpp, RTL/VM, utilitários e o resto da árvore oficial contam;
  estender ou usar qualquer um deles é o caminho preferido sobre
  qualquer inferência na ferramenta.
  apoia em diretivas para criar açúcar sintático — DSLs e comandos novos,
  já existentes no core ou criados pelo desenvolvedor no PRÓPRIO aplicativo.
  O hbrefactor refatora QUALQUER código, com ou sem açúcar, SEM ajustes
  quando diretivas criam açúcar novo. **Classes são SÓ UM CASO** — o
  princípio vale para todo construto (função, local, var, método, marker,
  palavra de DSL). Fato faltante → fato de compilação ou relato honesto
  (`possible`/recusa com rollback); nunca ajeito, nunca árvore quebrada.
  Provas executáveis na suíte: casos 64 e 72-74 (régua: nenhuma palavra de
  DSL de fixture em `src/hbrefactor.prg`). Fatos da linguagem que a análise
  consome estão no ast-schema.md (escrita `o:x := v` = mensagem `_NOME`;
  par de dados do VAR; `_HB_MEMBER { }`; strings de registro sem posição;
  sufixo `$` de INIT PROCEDURE; classes de runtime = teto da linguagem).
  **REVISÃO EM CURSO (ordem do Diego, 2026-07-07)**: eras B4e/B4f-2/
  extensão derraparam para enquadramento hbclass-cêntrico — achados e
  checklist executável em docs/revisao-generalidade.md; capacidade
  entregue sobre hbclass só conta como genérica com prova adversarial em
  DSL inventada NÃO-espelho.
- **Nunca editar o não-verificável**: a ferramenta só aplica o que o oráculo
  prova e a recompilação verifica; conteúdo sem verificação (strings, dados,
  comentários) recebe detecção e relato preciso, jamais edição automática (nem
  com opt-in) — editar string por coincidência de nome é "ajeito".
- **Extensão VSCode sempre com os últimos recursos**: todo comando/capacidade
  nova do CLI tem que chegar à `extension.js` — expô-la é escopo da fase que a
  entrega, não fase adiável (é o consumidor de uso diário do Diego).
- smoketest/hbrefactor-occ.prg é a primeira encarnação, arquivada:
  só leitura, nunca editar.
- **Revisão externa via Codex (`/codex:rescue`)**: o brief é instrumento
  versionado em docs/ e NÃO se contamina com o juízo do Claude; em conta
  ChatGPT valem só os modelos do models_cache do CLI (2026-07-09:
  `gpt-5.4`, `gpt-5.4-mini`, `gpt-5.5`; `gpt-5-codex` e `spark` falham
  com invalid_request_error — custou 3 tentativas); achado externo é
  HIPÓTESE até verificação no fonte com arquivo:linha (idioma da fase
  RE) — nunca agir direto sobre o relato. **Tarefa Codex pode morrer em
  SILÊNCIO** (2026-07-09: log congelado + PID sumido com status
  "running" órfão no broker — custou 13 min de espera morta): antes de
  esperar conclusão, conferir `ps -p <pid>` do task; morto = cancelar
  (`codex-companion.mjs cancel <id>`) e re-executar com modelo
  explícito (`--model gpt-5.5`).
- Commits só com autorização explícita do Diego **para AQUELE commit**;
  concluir/aprovar o trabalho não autoriza o commit. Um pedido por commit —
  não encadear. Sem push salvo pedido.
- **Só Fable** (instrução do Diego, 2026-07-07, revoga a regra anterior de
  delegação): não usar subagentes opus/sonnet — capacidade de solução vale
  mais que economia de tokens; todo o trabalho fica no Fable.
- Regra/preferência durável deste repo vai AQUI (versionado), não na memória
  privada do Claude (que não viaja com o repo); a memória fica para o que não
  pertence a um repo.

## Harbour (linguagem) — armadilhas ao escrever fixtures/.prg

Os fixtures da suíte são `.prg` idiomático (o "caso 0" exige saída limpa sob
`-w3 -es2`). Armadilhas que já morderam:

- **Não nomear variável formando keyword em uppercase**: Harbour é
  case-insensitive e lê identificadores em uppercase — `LOCAL nIL` vira a
  reservada `NIL` (`E0030 syntax error`). Evitar `nIL`, `cFor`, etc.
- **MEMVAR antes de PRIVATE/PUBLIC**: referenciar `PRIVATE`/`PUBLIC` sem uma
  declaração `MEMVAR` compile-time gera W0002 na criação e W0001 em cada uso —
  com `-es2` o build falha. Idioma: `MEMVAR xCfg` / `PRIVATE xCfg := 7`.
- **Comentário de linha `//` em .prg** (não `/* */`): um `*/` que apareça no
  conteúdo (ex.: `assert_*/`) fecha o bloco antes da hora e o resto vira
  código. Aplicar em código novo/editado, sem conversão em massa.
- **Verificar comportamento no fonte do Harbour ANTES de afirmar** (não
  teorizar): ler/grep o `src/` relevante. `Empty(" ")` é `.T.` — usar
  `Len(c) == 0` para "vazia".
- **Diagnóstico do IDE ≠ veredito**: o lint do VSCode usa o harbour do
  SISTEMA (`/usr/local/bin`, sem os patches do branch — ex.: acusa
  W0019 em `_HB_MEMBER` que completa tipo, silenciado pelo candidato
  (g) no core do projeto). A régua é sempre o toolchain de `HB_BIN`
  (2026-07-10: quase derrubou a fixture fixrbk por falso positivo).
