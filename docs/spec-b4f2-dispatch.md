# Spec B4f-2 — resolução de DISPATCH (backlog 5, parte 2: o furo dos homônimos)

Spec-driven: ORDEM DE SERVIÇO escrita ANTES do código. Aberta em
2026-07-06 por autorização do Diego, na sessão que entregou a B4f.
Ler antes: [spec-b4f-receiver-type.md](spec-b4f-receiver-type.md) (o canal
de tipos e os dois portões), [ast-schema.md](ast-schema.md) (ast-4),
[roadmap.md](roadmap.md).

## O problema (reportado pelo Diego, 2026-07-06)

Duas classes com métodos homônimos (`UWMain`/`UWSecondary`, ambas com
`Add`/`Paint`): o find-references de `UWMain:Paint` lista `oS:Paint()`
mesmo com `oS` classificado como `UWSECONDARY`. Reproduzido: a B4f para na
classificação do RECEPTOR — `possible (receiver class UWSECONDARY,
relation to UWMAIN unknown)` — quando os fatos do projeto JÁ respondem a
pergunta: `Paint` despachado sobre `UWSECONDARY` resolve em
`UWSecondary:Paint`, nunca em `UWMain:Paint`. Sem receptor classificado
(classes sem `CONSTRUCTOR` declarado), ambos os sends ficam `possible` e
os dois entram no editor.

**Veredito da análise (registrado no portão): a B4f não é ajeito — é
INCOMPLETA.** Nenhum fato novo falta; falta CONSUMIR fatos já
transportados (classe do receptor, grafo de herança, posse de método) com
a regra de resolução da LINGUAGEM. Resolução de método é semântica do VM
(classes.c), não convenção de biblioteca — codificá-la na ferramenta é
como codificar o que `::` significa: dentro do princípio da B4f.

## Fatos já verificados (2026-07-06, com evidência — não re-sondar)

| # | Fato | Fonte |
|---|------|-------|
| 1 | **Regra de resolução (provada em runtime)**: método PRÓPRIO vence herdado; em conflito entre pais, vence o PRIMEIRO da cláusula `FROM` (`FROM Alfa, Beta` → Ping de Alfa; `FROM Beta, Alfa` → Ping de Beta; override próprio vence ambos). | probe mi.prg (scratchpad/mi), executado |
| 2 | A herança do hbclass é FLATTENING em runtime: `__clsNew( cName, nDatas, ahSuper, ... )` copia as mensagens dos pais para a classe nova no Create. A ordem/uiSprClass registram a origem. | tclass.prg:213; classes.c:128, 2852, 3300 |
| 3 | A ferramenta JÁ extrai pais de classe dos fatos de expansão: `ClassParentsOf( hAst, ... )` → `{ noProjeto[], foraDoProjeto[] }`, com limites honestos documentados (declaração continuada por `;` = não-detecção conservadora; pai fora do projeto = nomeado). Usada pela B4e (caso 60: cadeia de ancestrais andada; aviso de pai não-verificável). | hbrefactor.prg:2669-2707 |
| 4 | O `DECLARE` da gramática NÃO carrega superclasse (o 2º IdentName do `DECLARE_CLASS` é a função-classe) — ancestralidade NÃO vem pelo canal de tipos; vem dos fatos de EXPANSÃO (o registro `HBClass():new( <nome>, { @Pai1(), @Pai2() }, ... )` está em statements[]/rastro). | harbour.y:1245-1247; inventário B4f; hbclass.ch:236-247 |
| 5 | Posse de método por classe: já temos por DUAS vias — `declared.classes` (ast-4) e o registro/rastro (`GenNameParts`/`MethodImplOf`, funções `<CLASSE>_<MÉTODO>`). | B4d/B4f entregues |
| 6 | Cadeia de ctor (`X():New()` com `RETURN Self`) produz instância EXATA de X — para esses receptores a resolução de dispatch é decidível sem ressalva de subclasse. Receptor `AS CLASS` é PROMESSA: pode carregar DESCENDENTE em runtime. | hbclass.ch (oInstance := oClass:Instance()); semântica provada na B4f |

## Fatos a sondar ANTES do volume (executor)

- **Ordem transitiva da resolução**: conflito avô × segundo pai
  (`C FROM A, B` onde só o pai de A tem o método, e B também tem) —
  estender o probe mi.prg (diamante incluso). A regra do fato 1 cobre o
  caso direto; a transitiva precisa de prova própria.
- `ClassParentsOf` preserva a ORDEM textual dos pais? (a resolução
  depende dela — fato 1). Sondar com `FROM B, A` e conferir `aIn`.
- ACCESS/ASSIGN (`_Nome`) e HIDDEN/PROTECTED no dispatch: escopo muda a
  resolução? (provavelmente não para o find-references; registrar).
- Classe de pai FORA do projeto no meio da cadeia: a resolução é
  indecidível a partir dali — camada honesta (fato 3 já nomeia o pai).

## Desenho proposto (para o portão do Diego)

Tudo na FERRAMENTA — nenhuma mudança de core/schema (os fatos já estão no
ast-4 + rastro):

1. **Grafo de classes do projeto**: agregado por módulo — classe →
   { pais na ordem (ClassParentsOf), métodos próprios (declared/registro),
   pais fora do projeto }. Função nova `ClassGraph( hAsts, hDecl )`.
2. **`ResolveDispatch( cClasse, cMsg, hGraph )`** → a CLASSE dona da
   implementação que o dispatch alcança, pela regra do fato 1 (próprio >
   pais na ordem, transitivo conforme probe), ou NIL quando a cadeia
   atravessa pai fora do projeto/desconhecido (indecidível → honesto).
3. **Camadas novas no `usages Classe:Método`** (e no --json):
   - receptor de classe EXATA (cadeia de ctor): `ResolveDispatch` ≠
     classe consultada → **`excluded (dispatches to UWSECONDARY:PAINT)`**
     — fora do --json; == → **`confirmed (dispatch resolved)`**.
   - receptor DECLARADO (promessa): == → confirmed como hoje; ≠ →
     exclusão só vale no MUNDO FECHADO do projeto: varrer o grafo por
     descendentes da classe do receptor que herdem a consultada ANTES na
     ordem (fato 1) — sem nenhum: **`excluded within the project's class
     graph`** (fora do --json, rótulo com a ressalva); com algum:
     `possible` nomeando o descendente.
   - cadeia indecidível (pai fora do projeto, classe desconhecida):
     `possible` como hoje.
4. **Fronteiras honestas (nomeadas no ast-schema/rótulos)**: classes
   criadas/alteradas em RUNTIME (`__clsNew`/`__clsModify` diretos),
   código linkado fora do projeto, classes escalares — nada estático
   cruza; ficam `possible`. É o teto da linguagem, não da ferramenta.
5. **Consumidores**: find-references (--json) é o alvo desta fatia;
   call-graph estreitado e relaxamento de unicidade P1b/P2b (rename com
   receptor resolvido age no confirmed e recusa/avisa no possible —
   política B4e) ficam anotados para a fatia seguinte, sobre o MESMO
   `ResolveDispatch`.

## Casos previstos (66+)

- 66: o caso do Diego — duas classes homônimas COM ctor declarado:
  `oS:Paint()` excluded (dispatches to UWSECONDARY:PAINT) e fora do
  --json; `oM:Paint()` confirmed (dispatch resolved). Variante SEM ctor:
  ambos possible (e o caso documenta o idioma: declarar).
- 67: herança simples — `FROM UWMain` sem override: send no filho
  confirmed para `UWMain:Paint` (dispatch alcança o pai); com override no
  filho: excluded para a consulta do pai.
- 68: herança múltipla — ordem da cláusula decide (fato 1); descendente
  `FROM UWMain, UWSecondary` no projeto impede o excluded-de-promessa
  (possible nomeando o descendente); mundo fechado sem descendente →
  excluded within the project's class graph.
- 69: cadeia com pai fora do projeto → possible honesto (nunca excluded).
- Suíte inteira verde; nenhum caso anterior regride (as camadas B4f
  continuam para receptor não-resolvível).

## Portão

Apresentar ao Diego ANTES do volume: resultados dos probes pendentes
(ordem transitiva, ordem em ClassParentsOf) + confirmação das camadas e
rótulos acima — em particular a semântica do "excluded within the
project's class graph" para receptor declarado (promessa × mundo fechado).

## Regras operacionais

Compilar fixture antes de usar (-w3 -es2); probes via hbmk2 no
scratchpad; make test é o contrato (403/0 na abertura desta spec);
commits um a um com autorização explícita do Diego; roadmap/ast-schema no
mesmo commit que mudar comportamento; sem mudança de core prevista (se
surgir necessidade, prova de zero impacto como sempre).
