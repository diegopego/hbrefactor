# Spec B4d — Refatoração GENÉRICA sobre diretivas de pp (rastro de derivação)

Spec-driven development: este documento é a ORDEM DE SERVIÇO para uma
sessão futura do Claude. Escopo e critério de pronto estão escritos ANTES
de qualquer código (regra do roadmap). Ler antes de começar:
[roadmap.md](roadmap.md) (B0/B4/B4c), [ast-schema.md](ast-schema.md)
(seções ppRules/ppApplications e receitas B4c), `CLAUDE.md` dos dois
repositórios (regras de trabalho; commits só com autorização do Diego).

## Ordem do Diego (2026-07-06, origem desta spec)

> Resolver isso de forma GENÉRICA, que venha a funcionar com qualquer
> tipo de diretiva — e isso inclui classes ou qualquer outra diretiva
> que já existe ou que venha a ser criada.

Classes (hbclass.ch) são o caso canônico, não o alvo. Nenhuma solução
por-DSL-conhecida é aceitável: nem palavra-chave (morta na revisão da
B4c), nem âncora por forma específica de uma família.

## O problema, enunciado uma vez

Um nome que o programador escreve (`Paint`, `nTot`, `evtClick`...)
atravessa diretivas de pp por match marker e vira ARTEFATOS na expansão:

| operação do pp        | exemplo hbclass                     | artefato                    |
|-----------------------|-------------------------------------|-----------------------------|
| clone de marker       | `<act>` → `AbreCoisa( nTotal )`     | token com posição PRESERVADA (B0 ✔) |
| colagem (paste)       | `<Class>_<Method>` → `UWMENU_PAINT` | símbolo/função NOVO, sem proveniência |
| stringify             | `<"Method">` → `"Paint"`            | string NOVA, posição instável (B4c) |
| literal da regra      | `MenuAdd(` no resultado             | não deriva de nome do usuário |

Hoje o dump só preserva a proveniência do CLONE. Colagem e stringify
nascem órfãs — e é exatamente essa lacuna que obrigou a B4c a usar
âncoras por FORMA (`MethodLift` casa `<A>_<B>` por tentativa;
`ClassRegs` reconhece a função de classe pela STRING igual ao próprio
nome; `StmtStrings`/`DeclHits` idem). As âncoras são fato-based e
conservadoras, mas são HEURÍSTICAS SOBRE O RESULTADO da expansão:
cobrem a colagem com `_` e o stringify do hbclass, não a colagem
`on_<n>` de uma DSL de handlers, nem o que alguém inventar amanhã.

**Princípio da solução**: o único lugar que SABE a derivação, para
qualquer diretiva existente ou futura, é o pp NO INSTANTE em que
sintetiza o token do resultado. O fato certo é registrado lá — uma vez,
genérico por construção — e as heurísticas morrem.

## Fase 1 — core (schema ast-3): rastro de derivação no pp

**Escopo**: no(s) ponto(s) de `ppcore.c` onde o resultado de uma regra é
materializado (síntese de token por colagem/`HB_PP_TOKEN` paste e por
stringify; o clone já carrega posição), registrar para cada token
sintetizado a ORIGEM: `{ aplicação, marker N, operação clone|paste|
stringify, offset e comprimento dentro do token composto }`. Mesmo
padrão B0/B4: lógica no pp, ganchos de 1 linha gated por `fTrackPos`,
tabelas por módulo limpas em `hb_pp_reset`, accessors em `hbpp.h`,
emissão em `compast.c`.

**Formato**: campo `from` nos tokens sintetizados de `tokens[]` e nos
tokens de `ppApplications[].tokens` que participem de derivação:

```jsonc
{ "line": 0, "col": null, "type": 21, "prov": "n", "text": "UWMENU_PAINT",
  "from": [ { "app": 12, "marker": 2, "op": "paste", "at": 0, "len": 6 },
            { "app": 12, "marker": 1, "op": "paste", "at": 7, "len": 5 } ] }
```

(`at`/`len` em bytes dentro de `text`; o `_` literal entre as partes não
tem `from`. String de stringify: um único item `op: "stringify"`.)
Schema → `"ast-3"`; leitor da ferramenta aceita ast-2|ast-3; comandos
que exigirem `from` recusam dump antigo com mensagem clara.

**Critério de pronto (mecânico)**:
1. Fixture hbclass: o token `UWMENU_PAINT` (nome da função gerada) traz
   `from` apontando os markers `UWMenu` (linha/col do CREATE CLASS) e
   `Paint` (linha/col da declaração); a string `"Paint"` do registro
   traz `from` stringify — campo a campo, byte-exato.
2. Fixture de DSL inventada com colagem por PREFIXO
   (`#xcommand HANDLER <n> => FUNCTION on_<n>`) — `from` correto sem
   nada específico no core além do gancho genérico.
3. Zero impacto: árvore inteira de src/ compilada com/sem `-x` →
   `.hrb` todos byte-idênticos; binário sem `-x` byte-idêntico; macro
   build no-op. Relink conferido em `harbour` E `hbmk2`
   (`strings ... | grep ast-`).
4. `ppApplications` continua casando 1:1 com o `.ppt` (caso 42 verde).

## Fase 2 — ferramenta: modelo de ENTIDADE (as heurísticas morrem)

**Entidade** = nome escrito no fonte que atravessa diretivas por marker.
**Artefatos da entidade** = fecho dos tokens/símbolos/strings cujo
`from` alcança os markers daquele nome (transitivo: multi-passe já
carrega proveniência por clone-de-clone).

1. **Lifting generalizado**: `usages <nome>` responde, para QUALQUER
   entidade, "escrito em `arq:lin:col`; deriva: função `F` (colagem,
   regra R), mensagem/string (stringify, regra R), ..." — no vocabulário
   do fonte. `MethodLift`, `ClassRegs`, `StmtStrings` e `DeclHits`
   são REMOVIDOS (grep no fonte: nenhuma colagem `"_"` tentada, nenhum
   `STRING == nome da função`).
2. **`rename-method` reimplementado sobre `from`** com o MESMO contrato
   externo (casos 47–49 intocados): sites = tokens fonte cuja derivação
   alcança a entidade; a política de unicidade de mensagem PERMANECE
   (send continua despacho dinâmico — isso é semântica da linguagem,
   não lacuna de fato).
3. **Verificação exata**: cada artefato derivado muda DETERMINISTICAMENTE
   no rename — o mapa de símbolos esperado (`HrbSymbolsRenamed`) passa a
   ser COMPUTADO do rastro (não declarado à mão), incluindo strings
   previstas. Execução idêntica continua contrato da suíte.
4. **Genérico de verdade**: nenhum comando novo por família; avaliar na
   implementação se `rename-method` vira açúcar de um `rename-entity`
   interno (decisão: genérico > específico, ver memória do projeto).

## Specs executáveis (fixtures da suíte)

- **G1 — canônico**: classes hbclass (fixture fixmth) sobre `from`:
  casos 47–49 verdes SEM alteração dos asserts; dogfooding hbhttpd
  (`UHttpdLog:IsOpen` A→B→A byte-exato; `Paint` recusado com as donas).
- **G2 — colagem que a B4c NÃO cobria**: dado
  `#xcommand HANDLER <n> => FUNCTION on_<n>()` (prefixo, sem `_` de
  sufixo) e usos `HANDLER Click`, quando `usages Click` roda, então a
  função `ON_CLICK` aparece LIFTADA ("handler Click"), e o rename de
  `Click` edita o fonte e prevê `ON_CLICK → ON_NOVO` — sem nenhuma
  linha nova na ferramenta.
- **G3 — stringify puro**: `#xcommand EVENTO <n> => Registra( <"n">, {|| <n>() } )`
  — rename edita o identificador; a string derivada muda e a
  verificação a PREVIU (não é warning, é fato).
- **G4 — derivação múltipla**: o mesmo nome clonado + colado +
  stringificado na MESMA regra; todos os artefatos no fecho.
- **G5 — recusa por co-derivação**: artefato colado de DOIS nomes
  (`<a>_<b>`): renomear `a` prevê `b` intacto; se o símbolo previsto
  colidir com função existente → recusa nomeando o artefato.
- **G6 — prova de futuro**: uma diretiva INVENTADA na fixture, sem
  nenhuma ocorrência em include do core e sem NENHUMA menção na
  ferramenta, passa por usages+rename completos.
- **G7 — regressão total**: suíte inteira verde; `make lexdiff` sem
  divergência nova; varredura src/ com/sem `-x` byte-idêntica.

## Não-objetivos

- Reflection em runtime (executar código do usuário para perguntar ao
  class system) — descartado na B4c.
- Editar includes de sistema (hbclass.ch etc.) — guarda existente vale.
- Rename de VAR/DATA (setter `_NOME`) — fase própria depois do B4d
  (com `from`, o par `NOME`/`_NOME` vira derivação visível — anotar).
- Compatibilidade de schema com ast-2 além do leitor tolerante — o
  schema é livre para evoluir (liberação de 2026-07-05).

## Regras de trabalho da sessão executora

1. Compilar toda fixture ANTES de usá-la em teste (CLAUDE.md).
2. Provar cada fato do dump com sondagem ANTES de codar sobre ele
   (padrão das sessões B4/B4b/B4c: probe no scratchpad → depois código).
3. `make test` é o contrato; casos novos numerados na sequência.
4. Zero impacto sem `-x` é inegociável; conferir relink de harbour E
   hbmk2 após mexer em `libhbpp`.
5. Roadmap e ast-schema atualizados NO MESMO commit que mudar schema ou
   comportamento; commits só com autorização explícita do Diego.
