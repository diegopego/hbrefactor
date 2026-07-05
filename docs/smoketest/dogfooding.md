# Fase 4 — Dogfooding (relatório vivo)

## Rodada 1: a ferramenta sobre si mesma (2026-07-04)

Projeto: `hbrefactor.hbp` (o próprio fonte, ~2.300 linhas em 1 módulo).

### Relatórios read-only

| Comando | Resultado | Observação |
|---|---|---|
| `usages ... TokenScan` | 12 resultados (1 definição + 11 chamadas) em **0,12s** | performance ok para fonte grande |
| `unused-locals` | 0 findings | esperado: o fonte compila `-w3 -es2` limpo |
| `call-graph ... TokenScan` | todos os chamadores corretos | — |
| `find-dynamic-calls` | 1 finding: string `"usages"` casa com a função `USAGES` | **falso positivo por design** — é o nome do subcomando CLI, não chamada dinâmica; confirma que o relatório é para julgamento humano |

### Fricção real encontrada (e corrigida): statements continuados por `;`

`rename-local ... RenameFunction hHit aHit` **recusava** com "line 370 is
rewritten by the preprocessor". Diagnóstico com evidência (`cont.prg` de
laboratório): num statement continuado, o oráculo e o `.ppo` apontam a
**última linha física** (o `currLine` do codegen), mas os tokens estão nas
linhas anteriores — o pp-check via a linha final "diferente" do ppo (que ali
está vazio) e recusava. A rede de segurança funcionou (recusa, não edição
errada), mas recusar todo statement multi-linha seria inviável em código real.

**Correção**: `StmtEdits()` — resolve a linha do oráculo para o statement
inteiro (anda para trás enquanto a linha anterior termina em `;`), junta o
texto limpo, compara com o ppo da linha final e coleta os tokens de todas as
linhas físicas. Compartilhado por `rename-local`, `rename-function` e
`rename-static`; a varredura fora-do-oráculo do `rename-function` também
ficou continuation-aware (`LineCovered`). Regressão: caso 24 (token na linha
do meio da continuação, verificação byte-idêntica).

### Auto-refatoração aplicada (a ferramenta editando o próprio fonte)

`hHit` (prefixo húngaro de hash) iterava **arrays** de hits/edições em quatro
funções — renomeado para `aHit` pela própria ferramenta, com verificação
byte-idêntica em cada uma: `RenameLocal`, `ReorderParams`, `RenameStatic` e —
após a correção acima — `RenameFunction` (que era exatamente o caso
continuado). Suíte 85/85 verde com o fonte auto-editado.

### Pendências desta rodada

- `reorder-params` mantém a recusa para chamadas multi-linha (o
  `ParseParenSpan` é por linha) — avaliar extensão para statements
  continuados se o uso real pedir.
- ~~Rodada 2 (pendente): projeto de produção do Diego~~ → feita abaixo.

## Rodada 2: projeto de produção — contrib/hbhttpd (2026-07-04)

Projeto apontado pelo Diego: `contrib/hbhttpd` do harbour-core (servidor
HTTP, ~2.400 linhas em 3 módulos, **classes** via `hbclass.ch`, `.hbx` de
exports, dependência `hbssl.hbc`, multithread). Cópia de experimento em
`work/hbhttpd` (gitignorada); régua de sanidade externa: `diff -r` contra o
original após cada ida-e-volta.

### Fricções encontradas (todas corrigidas; casos 29-30)

1. **Include de sistema ausente** — a ferramenta invoca `harbour` direto e
   nada fornecia o diretório de `hbclass.ch`: **nenhum** fonte do hbhttpd
   compilava. Fix: `SysIncFlag()` — `HB_INC` quando setado, senão derivado
   de `HB_BIN` (layout fonte `bin/<plat>/<comp>` → `../../../include`;
   layout instalado → `../include`).
2. **`-q2` engolia o erro do compilador** — o `usages` recusava com
   "project does not compile" sem dizer o quê. Fix: `-q` + filtro
   `CompileErrLines()` (só linhas Error/Warning, com o módulo no cabeçalho).
3. **`unused-locals` silencioso em build quebrado** — reportava
   "0 finding(s)" num projeto que nem compilava (ele só grepa warnings; erro
   fatal = zero warnings). Fix: checa o exit code e recusa mostrando o erro.
   Caso 30 congela: **build quebrado nunca é silencioso**.
4. **`-inc` lido como include path** — o parser tratava todo prefixo `-i`;
   `-inc` (build incremental do hbmk2) virava include path `nc`. Fix: caso
   explícito ignorando `-inc`/`-inc-`.
5. **Macros `${hb_name}`/`${hb_targetname}` não expandidas** — a linha
   `${hb_name}.hbx` do hbhttpd.hbp virava caminho literal. Fix: expansão
   para o nome-base do `.hbp` (o que o hbmk2 resolve nesse contexto).
6. **`.hbc` referenciado era ignorado** — `hbssl.hbc` fornece o
   `incpaths=` que localiza `hbssl.ch`. Fix: `LoadHbc()` seguindo a
   resolução do hbmk2 (`HBC_Find`, hbmk2.prg): caminho como dado →
   `contrib/<nome>/<nome>.hbc` na árvore do `HB_BIN` → varredura dos
   subdiretórios de contrib; importa os `incpaths=` relativos ao `.hbc`.
7. **Métodos invisíveis** — `usages Stop` dava 0: a definição vive na
   função `UHTTPD_STOP` (convenção do hbclass.ch) e o nome do método viaja
   como **string** de `__clsAddMsg` (nunca passa pelo oráculo). Fix em duas
   frentes, ambas rotuladas como convenção (não dado do oráculo):
   `usages` reporta "possible method definition (`<Classe>_<Método>`, name
   convention)"; `PickFunc()` aceita `Run`, `UHttpd:Run` e `UHTTPD_RUN`
   (sufixo único → resolve; ambíguo → recusa).

### Operações reais executadas (verificação verde em todas)

| Operação | Alvo | Resultado |
|---|---|---|
| `rename-local` | `hSocket`→`hConn` no método `Run` | byte-idêntico nos 3 módulos; A→B→A byte-exato |
| `rename-function --force` | `UUrlDecode`→`UUrlDec` (10 edições, 2 módulos) | símbolos renomeados, pcode idêntico; `.hbx` protegido (warning, nunca editado — é gerado pelo hbmk2); A→B→A byte-exato |
| `rename-param` | `cFilter`→`cRules` em `ParseFirewallFilter` | byte-idêntico; ida-e-volta ok |
| `reorder-params` | `MY_SSL_READ` (6 params, call sites com `@ref`) | 3 sites reordenados; A→B→A byte-exato |
| `extract-function` | bloco dentro do método `New` (log.prg) | símbolos preservados; recusa correta no trecho com 2 variáveis de saída |
| read-only | `usages`/`unused-locals`/`call-graph`/`find-dynamic-calls` | `find-dynamic-calls` achou string `'UErrorHandler'` que nomeia função do projeto — acerto legítimo em produção |

### Anotado para depois (não corrigido nesta rodada)

- **Declaração** `METHOD Stop()` no corpo da classe continua invisível (o
  send registrado é `ADDMETHOD`; o nome vai como string) — candidato a dump
  v4: gravar os nomes de mensagem de `__clsAddMsg`/`ADDMETHOD`. Habilitaria
  também um futuro `rename-method` (hoje é território H: strings).
- Corpo extraído pelo `extract-function` mantém o recuo original da seleção
  (cosmético; `hbformat` pós-edição resolve).
- `usages` de método só vê **sends + convenção de nome**: chamada dentro de
  string/macro segue com a cobertura do `find-dynamic-calls`.

**Critério de pronto da Fase 4 cumprido**: ≥1 rename e ≥1 relatório em
projeto de produção com verificação verde; fricções viraram correções
(1-7) e itens de backlog (dump v4). Suíte: **108/108**.

> **Nota (mesmo dia, após feedback do Diego)**: as correções 1, 4, 5 e 6
> acima eram reimplementações de coisas que o hbmk2 já resolve — foram
> **substituídas** pela delegação ao hbmk2 descrita na Rodada 3. A régua
> ficou registrada como princípio do projeto: *reutilizar o builder oficial;
> reescrever só o que for necessário*.

## Rodada 3: ERP monolítico legado — staff500 (2026-07-04)

Projeto apontado pelo Diego: `work/bravo-experimento` (ERP em produção,
repo git próprio, ~750 `.prg` no total). O alvo de build é `staff500.hbc`
(**sem `.hbp`**): 101 módulos via `sources=`, `.hbc` aninhado via
`libs=lib/staff500.hbc` (má prática que o hbmk2 tolera), `prgflags=-Dhrb`,
diretiva inválida (`output=`) que o hbmk2 apenas avisa. Ponto de partida
commitado no git do projeto (autorizado): `cf56f1d`.

### Mudança estrutural: hbmk2 é o resolvedor de projeto

O parser textual de `.hbp`/`.hbc` do hbrefactor foi **apagado** e
substituído por uma chamada a `hbmk2 <alvos> -traceonly`: a linha "Harbour
compiler command" traz a lista de fontes e os flags resolvidos (`-i`
includes da cadeia de `.hbc`, `-D` defines, `-u+` headers auto-incluídos,
`-n` modo). Ganhos imediatos e reais:

- `prgflags=-Dhrb` do staff500 chega ao compilador — o parser manual
  ignorava defines, ou seja, **compilava um programa diferente do real**;
- `sources=` (o staff500 inteiro é declarado assim) funciona sem código novo;
- o spec de projeto do CLI virou "qualquer alvo que o hbmk2 aceite":
  `.hbp`, `.hbc`, lista de `.prg`;
- `-w3 -es2` declarados pelo projeto agora valem na verificação — o que
  expôs um bug real do `extract-function` (abaixo).

Armadilha de Harbour registrada: `FOR EACH x IN a; x := f(x)` **escreve de
volta no array** (enumerador por referência) — corrompeu a lista de fontes
na primeira versão; usar variável separada.

### Fricções do monólito (e correções; casos 29-31)

1. **Headers de contrib fora do include path** — `hbzebra.ch` etc. vêm de
   `libs=hbzebra`, que só linka. No ambiente real o Harbour instalado tem
   esses headers em `include/`; na árvore de fontes não. Solução sem tocar
   na ferramenta: env **`INCLUDE`** do próprio compilador (a extensão ganhou
   a config `hbrefactor.includePaths` para isso).
2. **Módulo que não compila não pode travar o projeto inteiro** —
   `hb_lib/hb_aud_dbedit.prg` quebra porque o `include/hbcompat.ch` do
   projeto define `#translate ( <x> & <y> ) => HB_BITAND(...)` (compat
   xHarbour) que **sequestra o operador de macro** em
   `!&( dbFilter() )` — legado autêntico, 4 erros. Resposta da ferramenta:
   - comandos **read-only** (`usages`, `call-graph`, `find-dynamic-calls`,
     `unused-locals`): **cobertura parcial** — compilam o que dá, avisam
     módulo a módulo, resumem ("partial coverage - 1 of 101") e saem com
     exit ≠ 0;
   - renames de **módulo único** (`rename-local`/`param`/`static`): exigem
     que o **alvo** compile; módulos quebrados não tocados só encolhem o
     conjunto de verificação (aviso explícito);
   - comandos de **projeto inteiro** (`rename-function`, `reorder-params`,
     `extract-function`): continuam exigindo projeto são (um call site pode
     morar no módulo quebrado).
3. **`extract-function` deixava a declaração para trás** — variável usada
   só dentro da seleção continuava declarada no chamador → `W0033` → sob
   `-es2` o build do projeto quebrava **depois** de um "verified". Com os
   flags reais na verificação o caso 16 pegou isso; correção: local
   exclusiva da seleção **migra com a declaração** para a função extraída
   (linha inteira removida ou nome retirado da lista; fallback conservador
   = vira parâmetro quando a declaração tem inicializador/comentário/`;`).

### Operações reais no staff500

| Operação | Resultado |
|---|---|
| `usages staff500.hbc GerCodV` | 101 módulos processados em ~13 s; definição achada; cobertura parcial anunciada (1 módulo quebrado) |
| `rename-local staff500.hbc bancos.prg AtuSalBan mOldDbf mDbfAnterior` | 100 módulos byte-idênticos verificados em ~21 s; ida-e-volta `git diff` limpa |
| `unused-locals` (fixture) | continua reportando e **nunca** silencia build quebrado |

Suíte: **118/118** (casos 29-31 novos).

### Anotado para depois

- **Velocidade no monólito**: renames de módulo único recompilam os 101
  módulos duas vezes (~21 s); como só um arquivo muda, dá para verificar
  apenas o alvo (+ quem o inclui) — candidato de maior valor para uso
  diário (meta: ~1-2 s).
- `hb_aud_dbedit.prg` como estudo de caso do futuro `rename-define`/replay
  de pp: a regra do `hbcompat.ch` que colide com `&` é exatamente o tipo de
  coisa que a ferramenta deve detectar e explicar.
- No modo lista-de-`.prg` o hbmk2 escolhe `-n2` (vs `-n1` com `.hbp`) — os
  flags da trace são preservados por isso; não impor `-n` próprio.
