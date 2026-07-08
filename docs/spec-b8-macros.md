# Spec B8 — Macros: pipe hbmk2, contexto do site (ast-7) + complemento por probe

Status: **PORTÃO ABERTO (2026-07-08, decisões E1-E4 do Diego +
dialética do pipe fechada em 2026-07-08). Execução APÓS o rito D4 da
B7** (o rastreio de string reusa a máquina de ponto fixo da B7 fatia 2).
Motivação (requisito do Diego, 2026-07-08): macros são o caso difícil —
código que o compilador principal NÃO compila (adia para runtime) e que
hoje é ponto cego do usages; a meta-programação do Harbour
(`hb_compileFromBuf()`) abre a porta para análise aprimorada; o smoke
test deve também colher insights que generalizem além das macros.

## Veredito (análise de valor, 2026-07-08 — evita trabalho desnecessário)

**Vale explorar, mas não inteiro de uma vez:**

- **Fatia 1 (ast-7) vale por si** — risco baixo, melhora a honestidade
  em TODO site de macro, rastreável ou não. Fazer incondicionalmente.
- **Fatia 2 (probe + complemento) depende de um número não medido**:
  quantos sites `&` do corpus têm conteúdo rastreável? O padrão
  dominante em código real é `&cVar` de config/DBF/usuário —
  irrastreável (⊤), onde o probe não ajuda. Daí o **portão M0**
  (medição antes de construir, ver abaixo) dimensionar a fatia 2.
- **Por que o experimento merece existir mesmo assim**: macro é O
  buraco clássico de refatoração silenciosa em xBase (avanço com
  fidelidade de compilador = capacidade que nenhuma ferramenta do
  ecossistema tem); a primitiva probe+complemento é reutilizável além
  das macros; e tudo degrada honesto.
- **Plugin hbmk2: ADIADO** — a orquestração pedida é implementável
  (fatos abaixo), mas não acrescenta informação ao smoke (o corpus
  builda via Makefile); implementar só no dogfooding em projeto real.
- **Maior risco**: fidelidade probe×runtime (harbour.y+sem-pp ≠
  macro.y) — mitigada por medição obrigatória e rótulos condicionais,
  com critério de matar (ver Fidelidade).

## Arquitetura: pipe orquestrado (dialética com o Diego, 2026-07-08)

O requisito evoluiu para um **pipe**:

```
[pré: slot vazio, documentado] | compilador -x (ast-7) | pós: seleção por análise + sondagem 100% core → <projeto>.astc.json
```

- **Estágio pré NÃO alimenta o core durante a compilação** — decisão
  técnica, não de gosto: o compilador só tem três bocas de entrada
  (fonte, switches, defines); os fatos das macros só nascem DA
  compilação; e a pré-alimentação óbvia (pp externo entregando fonte
  expandido) **destruiria o canal de derivação** `from`/`ppRules`
  (ast-2/3/5), que existe porque o pp roda DENTRO da compilação. O
  slot fica documentado (gancho `pre_prg` do hbmk2 +
  `hbmk_Register_Input_File_Extension`) para o caso legítimo futuro:
  código gerado por metaprogramação entrando como fonte.
- **Estágio pós = "AST completa" honesta**: dump + complemento,
  epistemicamente SEPARADOS. A sub-árvore de uma macro obtida por
  probe é verdade **condicional** ("SE `cExpr` valer o literal
  rastreado, ENTÃO a árvore é esta") — fundi-la no dump apagaria a
  condição. Cada entrada do complemento aponta o site no dump e
  carrega proveniência + switches do probe.
- **Divisão do estágio pós**: a SELEÇÃO das strings (rastreio E3) é
  análise do hbrefactor sobre fatos do core — não é duplicação, o core
  não tem rastreio de valor interprocedural para duplicar; a SONDAGEM
  de cada fato é 100% ferramenta do core (`hb_compileFromBuf`).
- **Encanamento**: Makefile encadeia os estágios nos fluxos definidos
  (regra: fluxo definido mora no Makefile). O gatilho hbmk2-nativo
  (plugin fino `post_build` que só invoca o estágio pós) fica
  REGISTRADO como ponto de acoplamento designado, sem implementação
  no smoke (veredito).

## Fatos verificados no fonte (2026-07-08)

1. **O `&` não é compilado em compile-time**: o compilador principal
   cria nó `HB_ET_MACRO` e emite pcodes `HB_P_MACRO*`; o conteúdo é
   inconhecível estaticamente. Quem compila em runtime é o
   sub-compilador `src/macro/macro.y` — gramática reduzida (só
   expressões e codeblocks), **SEM preprocessador**, resolução
   memvar/field em runtime.
2. **O nó guarda mais do que o dump exporta**: `include/hbcompdf.h:163-170`
   define o `SubType` do site — `VAR` (&x), `SYMBOL` (&f()),
   `ALIASED` (&alias->&campo), `EXPR` (&(e)), `LIST`, `PARE`,
   `REFER` (@&x por referência), `ASSIGN` (`o:&msg := v`) — mais
   `cMacroOp`. O dump ast-6 exporta só `val`+`expr`
   (`compast.c:736-745`); **SubType e cMacroOp são descartados**.
3. **`hb_compileFromBuf()` é o compilador completo como biblioteca**
   (`src/compiler/hbcmplib.c:230`): switches passados como argumentos
   string; o primeiro argumento não-switch vira o pseudo-nome do módulo
   (default `{SOURCE}`, `hbmain.c:118-132`); **`-x<arquivo>` funciona**
   (`cmdcheck.c` case 'X' → `pAstFileName`; `compast.c:1215-1245` honra
   path/extensão) — dá para dirigir o dump do probe a um caminho
   controlado.
4. **`-u` sem argumento exclui as regras padrão do pp**
   (`cmdcheck.c` case 'U' → `szStdCh = ""`; `ppcomp.c:408-413` →
   "Standard command definitions excluded") — aproxima o ambiente
   sem-pp do macro-compilador de runtime. Resíduo: `hb_pp_initDynDefines`
   ainda roda (`__HARBOUR__` etc.) — medir (ver Fidelidade).
5. **hbmk2 tem os encaixes do pipe prontos** (`utils/hbmk2/hbmk2.prg`):
   API de plugins `-plugin=<arq.hb>` (`:3388-3395`); o plugin é
   compilado em runtime PELO hbmk2 via `hb_compileFromBuf`
   (`:9722-9725`) e roda NA VM do hbmk2 — que linka o compilador
   (`hbcplr`/`hbpp`/`hbmacro`, `:1745-1746`) — logo pode chamar
   `hb_compileFromBuf`/`__pp_*` nativamente. Estágios: `init`,
   `pre_all` (`:5869`), `pre_prg` (`:6040`), `pre_res`, `pre_c`,
   `pre_link`, `pre_lib`, `pre_cleanup`, `post_build` (`:7776`),
   `post_all` (`:7779`). Parâmetros do usuário via `-pflag=`/`-pi=`.
   Limites: sem callback por-arquivo; a lista dos módulos de fato
   recompilados no `-inc` (`l_aPRG_TO_DO`) NÃO é exposta ao plugin.
6. **O hbrefactor não replica resolução de projeto**: fontes e
   switches vêm do trace `hbmk2 -traceonly -rebuild`
   (`src/hbrefactor.prg:107-168`) e tudo reusa
   `hProj["files"]/["inc"]/["flags"]`. **Precedente do idioma do
   probe**: `NameAccepted` (`:1568-1592`) já chama `hb_compileFromBuf`
   herdando os flags de dialeto `-k*` do trace.

## Decisões do portão (Diego, 2026-07-08)

- **E1 — duas fatias**: transporte ast-7 no core + probe na ferramenta.
- **E2 — sequência**: execução após o rito D4 da B7 (fase B8).
- **E3 — rastreio interprocedural**: a string entra no ponto fixo da
  B7 como "tipo": reticulado análogo com **conjuntos finitos de strings
  literais** por símbolo (⊥ → conjunto com proveniência → ⊤); mesmos
  venenos → ⊤ (@ref, escrita por macro, captura com escrita, array/
  hash, FIELD/alias, pontos cegos auditados). **Profundidade
  condicionada ao M0** (decisão E3 tomada antes da análise de custo;
  o M0 a honra sem apostar às cegas).
- **E4 — `HB_MACROBLOCK()` entra no smoke**: mesmo pipeline de probe,
  embrulho de codeblock.
- **Dialética do pipe (2026-07-08)**: pré não alimenta o core durante
  a compilação (slot vazio documentado); complemento por PROJETO,
  separado do dump; plugin fino adiado.

## Portão M0 — medição antes de construir (fatia 2)

Com os dumps que já existem (leitor pronto): contar sites
`&`/`HB_MACROBLOCK` no corpus (fixtures da suíte + work/hbhttpd) e
classificar cada um — literal local / cadeia local / interprocedural /
⊤. Custo ~zero. Resultado apresentado ao Diego COM os números:

- Corpus com casos rastreáveis → fatia 2 como especificada.
- Corpus só-⊤ → fatia 2 encolhe para probe literal-local provado em
  fixture (prova a primitiva e os insights, sem a máquina E3
  completa); o resto espera fricção real.

## Fatia 1 — transporte ast-7 (core)

Exportar no nó macro do dump: `ctx` (SubType decomposto em nomes:
`var/symbol/aliased/expr/list/pare/refer/assign`) e `op` (cMacroOp,
quando ≠ 0). Mudança **só em compast.c** (o campo já existe no nó;
nenhum gancho novo em harbour.y) + bump `HB_AST_SCHEMA` → ast-7.

- Item de execução: **verificar por probe** que o SubType já está
  estável no momento da serialização (é setado nas reduções de uso);
  se algum contexto chegar zerado, relatar o fato, não inventar.
- Protocolo completo de zero impacto (o mesmo do ast-6): 224/224 .hrb
  byte-idênticos com/sem `-x`, em `-w0` E `-w3`; relink duplo
  harbour+hbmk2 conferido por `strings ... | grep ast-`.

## Fatia 2 — complemento por probe (ferramenta; dimensionada pelo M0)

**Artefato**: `<projeto>.astc.json` — UM por projeto (a análise é
interprocedural; a string de um site pode nascer noutro módulo).
Schema próprio **`astc-1`** (nunca confundido com `ast-N`: o dump é
verdade do compilador, o complemento é derivado). Cada entrada:

- site no dump (módulo + posição + `ctx` do ast-7);
- conteúdo rastreado + **proveniência** (cadeia de fato: quem semeou o
  literal, por onde propagou);
- sub-árvore do probe + switches usados;
- ou, sem fato: a classificação honesta (⊤/conjunto>1) com motivo.

**Primitiva `ProbeCompile( cCode, tipo, hProj )`** → AST do trecho:

- Embrulho: expressão → `FUNCTION __HBR_PROBE()` + `RETURN <expr>`;
  codeblock (HB_MACROBLOCK) → `RETURN <bloco>`.
- Switches: dialeto **`-k*` herdado do trace** (idioma do
  `NameAccepted`, fato 6) + `-n -q0 -w0 -u -x<caminho-tmp>` +
  pseudo-nome; **sem** include paths e sem regras do projeto
  (fidelidade: o macro-compilador de runtime não roda pp).
- Cache por hash(string+switches) em `~/.cache/hbrefactor` (mesmo
  lugar do oráculo D3).
- Falha do probe = "probe recusou: <motivo>" — nunca afirmação sobre o
  runtime (macro.y aceita/recusa por régua própria).

**Rastreio (E3, profundidade pelo M0)**: sementes = literais de
string; propagação = assign/return/chamada/parâmetro (união de TODOS
os call sites, mundo fechado auditado — máquina da B7); fold de
concatenação de literais SE a máquina já fizer, senão degrada nomeado;
venenos → ⊤.

**Geração e consumo**: novo subcomando do hbrefactor (nome sugerido:
`complement`) gera o artefato lendo os dumps; o Makefile encadeia nos
fluxos definidos; o usages consome o complemento quando presente —
site `&` com conteúdo sondado alimenta as camadas com rótulo nomeando
a cadeia E a condição (ex.: `macro site (content traced from literal
at arq:linha, probe ast, conditional)`); conjunto finito >1 → probe de
cada candidato, rótulo nomeia todos; ⊤ → possible como hoje; `ctx` do
ast-7 rotula o site mesmo sem conteúdo (ex.: `o:&msg := v` é
send-lvalue dinâmico — hoje invisível).

## Fidelidade probe × runtime (medição obrigatória do smoke)

O probe usa harbour.y + pp; o runtime usará macro.y sem pp. O probe
informa **ESTRUTURA** (que nomes/aplicações aparecem na string), nunca
semântica de resolução (memvar/field é runtime) — todo rótulo carrega
isso. Medir e registrar no fechamento:

1. `#define` no módulo hospedeiro NÃO pode vazar para o probe (runtime
   não aplica) — caso executável na fixture.
2. Expressão que harbour.y aceita e macro.y recusaria (ou vice-versa):
   registrar as divergências achadas; se nenhuma no corpus, dizer isso.
3. Dyn defines (`__HARBOUR__`) presentes no probe (fato 4): medir se
   algum caso real morde; se morder, decidir no fechamento.

**Critério de matar**: se as divergências medidas forem grandes, o
probe degrada para "estrutura provável" (rótulo enfraquecido) ou a
fatia 2 morre com o relato — registrado no fechamento, sem ajeito.

## Venenos mínimos da fixture

1. String vinda de fora (parâmetro sem call site conhecido / input) →
   ⊤ possible.
2. `cExpr` reatribuída entre literais distintos → conjunto >1, rótulo
   nomeia candidatos.
3. `o:&msg := v` sem conteúdo rastreável → possible nomeado pelo `ctx`.
4. `&alias->campo` (aliased).
5. Passagem da string por `@ref` depois de semeada → veneno B7 → ⊤.
6. `HB_MACROBLOCK` com local capturada: o probe dá estrutura; o rótulo
   NÃO promete semântica de captura.
7. `#define` no hospedeiro (item 1 da fidelidade).

## Critério de pronto (executável)

Fixture nova `fixmac` (**compilada limpa ANTES de usar** — regra do
CLAUDE.md do core), cobrindo rastreio local, interprocedural SE o M0
mantiver (via parâmetro e via fábrica de strings), HB_MACROBLOCK e os
venenos:

- (a) ast-7: dump do fixmac carrega `ctx` em pelo menos
  var/symbol/expr/refer/assign/aliased; zero impacto 224/224 + relink
  duplo (protocolo da fatia 1).
- (M0) medição registrada com os números do corpus e a decisão de
  profundidade apresentada ao Diego.
- (b) usages de função `F` chamada SÓ dentro de string de macro
  rastreável: o site aparece com rótulo de fato lido do
  **`.astc.json`** (não estado em memória; hoje: invisível).
- (c) interprocedural (se mantido pelo M0): todos os call sites
  literais → fato; UM call site veneno → degrada nomeado.
- (d) HB_MACROBLOCK análogo a (b).
- (e) venenos 1-6 permanecem possible/⊤ com motivo nomeado no
  artefato.
- (f) fidelidade item 1 provado por execução (o `#define` do hospedeiro
  não altera o probe); critério de matar avaliado e registrado.
- (g) suíte inteira verde, byte-idêntica nos modos paralelo/`JOBS=1`;
  zero regressão.
- (h) **Seção de insights no fechamento** (parte do requisito): o que
  generaliza — strings-código além do `&` (`OrdCreate`, `SET FILTER`,
  código gerado via slot pré), probe como validador barato de
  reescritas (backlog 0), ponte com evidência de execução (backlog 2:
  gancho futuro gated no próprio macro.y = terceiro nível epistêmico,
  nunca misturado ao estático), e se o plugin fino merece sair do
  adiamento.

## Fora do escopo

- Gancho no macro.y de runtime (fica no backlog 2).
- **Canal de entrada novo no compilador para fatos pré-computados**
  (não-objetivo nomeado: o pré não alimenta o core; se um dia precisar,
  é decisão de core com portão próprio).
- Plugin fino hbmk2 `post_build` (adiado pelo veredito; a API está
  documentada no fato 5 como ponto de acoplamento designado).
- EDITAR conteúdo de string de macro em renames — primeiro só
  análise/relato (o aviso de "site em string" já é consumo natural do
  probe); edição automática em string é fase própria, se a fricção
  pedir e com portão do Diego.
