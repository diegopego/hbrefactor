# hbrefactor

Refatoração automatizada para Harbour sobre a AST do compilador
(dump `.ast.json` do branch feature/compiler-ast-dump). Fontes de verdade:
docs/roadmap.md, docs/ast-schema.md e o Makefile — LER antes de codar.

## Regras de trabalho

- **PORTÃO DE AUTORIZAÇÃO — heurística e réplica são PROIBIDAS por padrão, e a
  exploração do core vem ANTES de projetar a solução (Diego, 2026-07-12; a regra
  existia e vinha sendo quebrada "de tempos em tempos" — o que faltava não era
  regra, era PORTÃO)**. A ordem é OBRIGATÓRIA e não se pula:
  1. **Explorar PRIMEIRO se o core pode dar o fato.** Antes de desenhar qualquer
     solução no hbrefactor, a pergunta é *"dá para o Harbour gerar essa
     informação?"*. Projetar a solução na ferramenta e só depois perguntar isso é
     ordem invertida — quando a solução já está desenhada, a heurística já venceu.
  2. **Se o core pode → o core faz.** Estender/usar o core é o caminho, sempre.
  3. **Se você concluir que o core NÃO pode → isso é uma RECUSA, e recusa exige
     varredura registrada** (a regra abaixo: `--help`, API pública, `tests/` do
     core, ChangeLog). "Não achei" quase sempre é "não procurei".
  4. **Só então, e SÓ COM AUTORIZAÇÃO EXPLÍCITA DO DIEGO PARA AQUELE CASO**, pode
     existir heurística/inferência/réplica de gramática no hbrefactor. É um portão
     por-caso, igual ao de commit: aprovar um não aprova o próximo.
  **Como pedir:** apresentar (a) o fato que falta, (b) a varredura feita no core,
  (c) por que o core não pode dar, (d) a heurística proposta e **onde ela erra**.
  **É PROIBIDO** implementar a heurística "provisoriamente" e pedir depois — o
  código provisório é o que fica. Na dúvida sobre se algo É heurística, veja os
  **GATILHOS** abaixo; se bater um gatilho, PARE e pergunte.
  **O portão é EXECUTÁVEL, não só escrito:** o hook
  `.claude/hooks/anti-heuristica.sh` (PreToolUse/Bash) intercepta o `git commit` e
  **recusa** quando o diff staged de `src/hbrefactor.prg` adiciona linhas com os
  cheiros dos gatilhos. Autorizado pelo Diego, sela-se a linha com
  `// FATO-OK(diego,AAAA-MM-DD): <por que o core não pode dar este fato>` — e o selo
  só se escreve DEPOIS do "ok" dele. Auditoria periódica do fonte inteiro: o prompt
  de sessão dedicada está em `docs/prompt-revisao-anti-heuristica.md`.
  *(Histórico do custo: `ast-14`, `ast-15` e `ast-16` foram os três casos em que o
  fato faltava no core e eu remendei/ia remendar na ferramenta. Nos três, o core
  sabia e não exportava.)*
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
- **FALTA DE INFORMAÇÃO → VÁ AO CORE, IMEDIATAMENTE (Diego, 2026-07-12)**:
  a missão é fazer o core do Harbour **gerar o MÁXIMO de informação
  necessária**. Ao detectar QUALQUER falta de fato, a primeira reação é
  ir ao core estendê-lo — **nunca** remendar na ferramenta com
  heurística, inferência ou comparação de texto. **"Zero mudança no core"
  NÃO é virtude — é sinal de alerta**: se um conserto precisou de
  esperteza na ferramenta, quase sempre o fato faltava no core e a
  esperteza é o sintoma. Anti-padrão FLAGRADO pelo Diego (P5, 2026-07-12,
  o erro que gerou esta regra): o recheio de um marker de match
  NÃO-NUMERADO (casado mas não usado no result) chega ao dump com
  `marker=0`, colidindo com "palavra literal da regra" — o pp SABE a
  diferença (ele casou!) e não exportava. Em vez de estender o
  rastreador, inferi por COMPARAÇÃO DE TEXTO ("se não é palavra da regra,
  é recheio") — furo provado em 1 linha: conteúdo do usuário igual a uma
  keyword da regra classifica errado. Fato que o core sabe e não exporta
  é lacuna DO CORE, não problema a contornar.
- **GATILHOS da REGRA DO FATO — os CHEIROS que obrigam a parar e ir ao core
  (catálogo de erros, 2026-07-12; o Diego me pegou 3× no MESMO dia)**. A
  regra acima já existia e eu a violei assim mesmo — logo o que faltava não
  era regra, era **gatilho**. Ao escrever QUALQUER uma destas linhas, PARE e
  pergunte "o core sabe isto e não me conta?" antes de continuar:
  1. **Comparação de TEXTO para decidir PAPEL/IDENTIDADE** (`Upper(a) == Upper(b)`,
     prefixo, `Left()`, `$`) quando o dump já tem número/id/índice. *(P5: recheio
     de marker vs palavra da regra → `ast-14`.)*
  2. **Constante mágica de gramática** (`>= 4`, `Len() > N`) — é réplica de regra
     do compilador. *(P-AUDIT: `AbbrevClash` reescrevia `ppcore.c:2533` → RECUSA
     FALSA, cabeça de DSL irrenomeável → `ast-15`.)*
  3. **"se não é X, então é Y"** sem um fato que SEPARE X de Y. *(A guarda de
     órfão do P6: "grafia manual = token sem `from`" — cega para todo site
     dentro de um comando.)*
  4. **Re-implementar resolução/busca que o core faz** (achar include, casar
     nome, expandir): `ResolveInclude` varre os `-i` à mão. Cópia degradada.
  5. **Casar arquivo por BASENAME** em vez de caminho canônico. *(Diego pegou:
     dois `.ch` homônimos colidem.)*
  6. **Escolher o canal MAIS BARATO** (Diego, 2026-07-12): *"tem que usar o canal
     CORRETO, não apenas o mais barato"*. Eu ia responder posse de include pelo
     dump porque era barato; o canal certo (`harbour -gd`, lista de dependências
     oficial, com caminho RESOLVIDO e fecho transitivo) já existia e eu não tinha
     procurado. **Barato ≠ correto; e "não achei" quase sempre = "não procurei".**
- **NÃO declare IMPOSSÍVEL/RECUSA sem VARRER a superfície do core (2026-07-12)**:
  toda recusa ("o pp não consegue X") é uma afirmação sobre o CORE e exige
  varredura ANTES, com o que foi varrido REGISTRADO na spec: (a) `harbour`/`hbmk2`
  `--help` inteiro (flags existem e são esquecidas: `-gd` deps, `-sm`, `-u`,
  `-p`/`-p+`); (b) a **API pública** (`include/hbpp.h` e afins); (c) **`tests/` do
  core** — é lá que a API viva aparece; (d) ChangeLog. Custou um VEREDITO ERRADO
  publicado: recusei "pp como motor de reescrita" (P7) olhando só o `.ppo`
  destrutivo; o Diego apontou `tests/hbpp/hbpptest.prg` → `__pp_init()` +
  `__pp_process()` (pp vivo, in-process, LINHA A LINHA) derrubam a premissa.
  Ecoa o P4 ("não tem uso nenhum" com base num `grep` quebrado): **silêncio de
  busca minha NÃO é evidência de ausência.**
- **Ferramenta do core: PROBE, nunca memória (2026-07-12)**: antes de consumir a
  saída de um utilitário do core, sonde ONDE ele escreve e O QUE reporta — com
  fonte em SUBDIRETÓRIO (o caso que quebra). Assumi que `harbour -gd` grava o
  `.d` ao lado do fonte (como o `.ppo`); ele grava no **CWD** → deixei **lixo no
  repo** (`hbrefactor.d`) e a função devolvia vazio para fonte em subdir. Conserto:
  `-o<tmp>` (não se adivinha o destino: manda-se). **Depois de qualquer comando que
  rode o compilador ao lado dos fontes, conferir `git status`** — `.d`/`.ppo`/`.c`
  vazam para o repo.
- **Chave OPCIONAL do dump: sempre `hb_HGetDef` (2026-07-12)**: campo que só existe
  em ALGUNS papéis (`marker` não vem em token literal; `ruletok` só em `marker: 0`;
  `from`, `generates`, `col`) acessado direto é `BASE/1132` em produção — e a suíte
  não pega (custou um crash no `rename` dentro de `.ch`). Ler o contrato no
  ast-schema.md ANTES; na dúvida, `hb_HGetDef`.
- **Buildar o core após editar — 3 armadilhas que custam diagnóstico
  (Diego, 2026-07-11; consolida notas espalhadas em specs)**: (a) mudança
  no COMPILADOR (harbour.y, hbmain.c, compast.c, complex.c…) exige
  rebuildar `harbour` **E** `hbmk2` — o hbmk2 EMBUTE o compilador
  (libhbcplr); o built-in velho rejeita gramática/canal novo com erro
  enganoso. (b) O `make` costuma reportar `harbour`/`hbmk2` "up to date" e
  NÃO relincar mesmo após reconstruir a `libhbcplr.a` (dependência
  quebrada) → binário STALE com o compilador antigo; conserto: apagar os
  binários (`rm bin/linux/gcc/harbour bin/linux/gcc/hbmk2`) e refazer o
  make. (c) `HB_REBUILD_PARSER=yes` regenera o `obj/<plat>/harboury.c`
  (artefato de build), **NÃO** o `harbour.yyc`/`.yyh` COMMITADOS — é
  preciso COPIAR à mão `obj/harboury.c`→`src/compiler/harbour.yyc` e o
  `.h`→`harbour.yyh`, senão um checkout limpo (build default, SEM a flag)
  usa a gramática VELHA; commitar os três juntos (.y + .yyc + .yyh) e
  conferir que um rebuild default (binários apagados) carrega a feature.
  Provado na RD (`_HB_INLINESELF`, core `da61c647cb`).
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
- **`make test JOBS=1` só ao mexer no RUNNER (Diego, 2026-07-10)**: o
  contrato "paralelo × JOBS=1 byte-idêntico" é propriedade da INFRA de
  paralelização (bin/parrun, modo `--unit` do run.sh, join), não do
  conteúdo dos testes nem da ferramenta — re-rodá-lo a cada entrega é
  desperdício. Rodar JOBS=1 apenas quando a mudança tocar o runner ou
  introduzir saída potencialmente não-determinística na ferramenta
  (ex.: imprimir na ordem de iteração de um hash). Para mudança de
  conteúdo/lógica, o run paralelo verde basta.
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
- **DOIS changelogs de USUÁRIO, um por repositório — e o público é o PROGRAMADOR
  HARBOUR, nunca o contribuidor (Diego, 2026-07-12)**. Aqui é o `CHANGELOG.md`; no
  core é o **`NEWS.md`** — nome diferente de propósito: o Harbour já tem um
  `ChangeLog.txt`, e a convenção GNU que ele segue é exatamente esta divisão
  (**`ChangeLog` = desenvolvedor; `NEWS` = usuário**), então `CHANGELOG.md` ao lado
  de `ChangeLog.txt` só criaria confusão (diferem por caixa e extensão). **No
  hbrefactor fica `CHANGELOG.md` — decisão do Diego (2026-07-12), NÃO re-litigar**:
  a convenção GNU é uma DESAMBIGUAÇÃO, e aqui não há o que desambiguar (não existe
  `ChangeLog.txt`); `CHANGELOG.md` é o nome que o GitHub reconhece e destaca, então
  adotar `NEWS.md` por simetria trocaria DESCOBERTA por uma elegância que não serve
  a leitor nenhum. **A assimetria é deliberada.**
  Tudo que se faz no core é feito
  para esta ferramenta, e o programador Harbour merece saber o que o compilador
  passou a lhe dar (`-x`, `-kt`, os fixes). **Regra: cada repositório com commit
  novo ganha a sua entrada** — commitou no core, o changelog do core ganha entrada;
  commitou nos dois, os dois ganham. **O changelog do contribuidor JÁ EXISTE e é o
  git** (completo, preciso, datado): duplicá-lo em markdown não agrega e cria uma
  segunda fonte de verdade que envelhece pior. O CHANGELOG só se justifica ao
  responder o que o git NÃO responde: *"o que eu passo a poder fazer, e onde isso
  me morde?"* **Reprova o CORPO da entrada que contiver**: nome de função C /
  arquivo de implementação, nome de struct, jargão de build (`lexdiff`, `pcode`,
  `gated`), número de caso da suíte, sigla de fase. *(Ponteiro para os docs
  internos no FIM da entrada continua permitido — é a regra de 2026-07-09 abaixo;
  e citar a saída REAL da ferramenta é sempre permitido, mesmo que ela mencione uma
  fase: é o que o usuário vê no terminal.)* **Cada CHANGELOG carrega um PONTEIRO DE
  DELTA** no topo (`<!-- changelog-baseline: <repo>@<sha> -->`) — o último commit já
  descrito ali; é o que torna o serviço **retomável** se o fluxo não rodar
  (`git log <baseline>..HEAD` diz o que falta). Fluxo e régua anti-buraco na skill
  `/update-manual`. *(O buraco que gerou a regra: `extract-function`, `inline-local`,
  `call-graph`, `unused-locals`, `find-dynamic-calls` e `reorder-params` — seis
  comandos VIVOS — ficaram sem uma linha de changelog porque a regra nasceu depois
  deles.)*
- **PIPELINE DO CORE: `commit → NEWS.md → landing page` (Diego, 2026-07-12)**. O
  core tem uma **proposta aos MANTENEDORES** em `harbour-core/site/index.html` — é
  ela que decide se o PR (fase B6) é sequer avaliado, então é trabalho sério, não
  enfeite. **Ela NÃO é um log**: não ganha seção por commit e não lista schema; ela
  carrega o **conceito consolidado** (o argumento central, a forma do diff, os quatro
  canais, os bugs do stock que o branch conserta, o que se pede ao mantenedor, e o
  que ainda não sabemos). Muda **só quando o conceito muda** — e "não mudou" é
  resposta legítima. **Nenhum número nela sem medição na hora**: o público é
  mantenedor, e um número inflado ou um comando que não roda queima o PR inteiro.
  Fluxo e checklist na skill `/update-manual` (§ 0.4b). Artifact de endereço fixo
  para distribuir: republicar o mesmo `file_path` mantém a URL.
- **TUDO no harbour-core é em INGLÊS (Diego, 2026-07-12)**: código, comentário,
  documentação **e mensagem de commit**. É o projeto Harbour internacional e este
  branch é upstreamável (fase B6) — um contribuidor de qualquer lugar tem de
  conseguir ler. A língua de trabalho com o Diego é o português; o que ATERRISSA
  naquela árvore, não. *(Custou um rewrite de histórico: 10 mensagens em português
  foram traduzidas com `filter-branch` + force-push, e os SHAs citados nos docs do
  hbrefactor tiveram de ser corrigidos.)*
- **CHANGELOG.md para o programador final (Diego, 2026-07-09)**: toda
  capacidade/entrega ganha entrada no CHANGELOG.md escrita para o
  programador Harbour FINAL — o problema de todo dia, o que muda na
  prática (exemplo antes/depois quando couber), o que a ferramenta
  NUNCA faz, e os limites honestos da entrega. Sem jargão interno de
  fase (B9/F2.x ficam nos docs; a entrada só aponta para eles no fim).
  Atualizar na mesma sessão da entrega, como o roadmap.
- **Código NOVO nosso usa `#xcommand`/`#xtranslate`, nunca `#command`/`#translate`
  (Diego, 2026-07-12)**: provado no dispatch do core (`ppcore.c`, o `#[x]command` é a
  MESMA chamada com um único argumento diferente) que o `x` significa **exatamente e
  somente** "modo de comparação EXATO" em vez do **dBase** (que casa a palavra
  abreviada a partir de 4 letras). Nada mais muda — nenhuma capacidade se perde. A
  família dBase é a origem de uma CLASSE INTEIRA de ambiguidade (o sequestro de
  regra do P11, a recusa falsa do P5, `MENUITEM` vs `MENUBOX` disputando `MENU`);
  na família `x` esses bugs são **impossíveis**. Vale para fixture, exemplo, doc e
  sonda que EU escrever. *(Existe ainda a família `y` — `#ycommand`/`#ytranslate` —
  que é exata E case-sensitive.)*
  **DUAS exceções, ambas obrigatórias:** (a) fixture cujo ASSUNTO é a abreviação
  dBase (hoje `fixabr`/caso 115, `fixseq`/caso 116, o `MENUITEM`/`MENUBOX` do
  `fixdsl`) — trocar para `x` faria o teste passar por VACUIDADE, provando nada;
  (b) a FERRAMENTA jamais pode abandonar `#command`/`#translate`: ela refatora o
  código dos OUTROS, e o `std.ch`, o `hbclass.ch` e toda a herança Clipper são
  dBase. A política é sobre o que escrevemos, nunca sobre o que suportamos.
- **NENHUM número digitado à mão nas páginas — indicador é MEDIDO (Diego,
  2026-07-12)**: *"se realmente importa colocar estes indicadores, eles devem ser
  atualizados de forma determinística"*. Cada indicador é um elemento marcado
  (`<span data-metric="suite-checks">`), e o `bin/site-numbers.sh` o **recalcula**:
  `make site-numbers` escreve, **`make site-check` FALHA** se algo estiver defasado
  (no core: `make -C site numbers|check`). **Corolário duro: indicador que não se
  consegue GERAR não entra na página** — a prova de impacto zero exige buildar DOIS
  compiladores, não cabe num alvo de rotina, então a página traz o **comando** que o
  mantenedor roda (`tests/pcode-identity.sh`), não um número. *(O estrago que gerou a
  regra: a proposta afirmava `1085/1085` e `112/112` módulos com pcode idêntico, a
  página do hbrefactor dizia `105 cases / 825 checks`, e o texto falava em "thirteen
  schema steps". Os QUATRO estavam errados e ninguém tinha notado — número mantido à
  mão envelhece calado, e na porta de entrada de um PR isso queima a credibilidade
  inteira.)* Rodar o `site-check` ao mexer em página/manual (a `/update-manual` o faz).
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
- **`LOCAL x := 0` seguido de `x := <valor>` é DEAD STORE → W0032 → quebra
  sob `-es2`** (2026-07-12): o Harbour avisa que o INICIALIZADOR nunca é lido,
  mesmo que a variável seja lida depois. Reproduz em 4 linhas. Idioma: declarar
  **sem** inicializador (`LOCAL nEdits`), ou usar `+=` (que LÊ). *(A mensagem
  "assigned but not used" engana — parece que a variável é inútil, e não é.)*
- **Régua do caso 64 vale para COMENTÁRIO também** (2026-07-12): a régua
  (`! grep -qiwE "palavras|da|dsl" src/hbrefactor.prg`) é textual — citar a DSL
  de uma fixture num comentário do fonte QUEBRA a suíte, e está certa em quebrar:
  o fonte da ferramenta não deve conter vocabulário de DSL nenhuma, nem de
  exemplo. Ilustre o formato genericamente ("keyword secundária prefixo da
  cabeça"), nunca com as palavras da fixture.
- **Coluna de probe/teste: COMPUTAR, nunca contar na cabeça** (2026-07-12): errei
  4× nesta sessão (inclusive fazendo a suíte falhar), e uma delas por ler a coluna
  de um arquivo que o rename ANTERIOR já tinha mudado. Extrair sempre do arquivo
  no estado CORRENTE (`python3 -c "...l.index('<n>')+1"`). Lembrar: dump é 0-based,
  CLI é 1-based; o `col` de um marker aponta o NOME, não o `<`.
- **Diagnóstico do IDE ≠ veredito**: o lint do VSCode usa o harbour do
  SISTEMA (`/usr/local/bin`, sem os patches do branch — ex.: acusa
  W0019 em `_HB_MEMBER` que completa tipo, silenciado pelo candidato
  (g) no core do projeto). A régua é sempre o toolchain de `HB_BIN`
  (2026-07-10: quase derrubou a fixture fixrbk por falso positivo).
