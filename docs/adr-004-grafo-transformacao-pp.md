# ADR 004 — o grafo de transformação do pp como raiz da AST (enraizar a proveniência na fase de preprocessamento)

Data: 2026-07-11. Status: **PRIMEIRO PEDAÇO DO GRAFO ENTREGUE (ast-13,
genealogia de regra + derivação sobrevivendo ao clone) — a visão foi
VINDICADA por execução**; o spike intermediário corrigiu uma hipótese no
caminho (ver §"O que está PROVADO" itens 3-5). Commit do core pendente de
autorização por-commit do Diego. Sucede o [adr-003](adr-003-derivacao-pp-como-fato.md)
(a operação de derivação como FATO) — este ADR sobe um nível: da derivação
pontual para o GRAFO inteiro, e de onde ele deve nascer. Contexto executável:
`from`/ast-3 e `ppApplications`/ast-2 em [ast-schema.md](ast-schema.md);
oráculo `.ppo`/`.ppt` (`harbour -p` / `-p+`); investigação em
[spec-p-pp-refatoracao.md](spec-p-pp-refatoracao.md).

## Por que este ADR

Na Fase P (P1), provando a granularidade paste×stringify, a investigação —
conduzida com o `.ppo`/`.ppt` por ordem do Diego — convergiu para uma tese
ARQUITETURAL que ultrapassa o P1. O Diego pediu explicitamente ("anote tudo
isso que tenho recomendado") que a visão e as recomendações ficassem
registradas. Este documento é esse registro, honesto sobre o que está PROVADO
e o que é aposta.

## As recomendações do Diego (2026-07-11, na ordem em que vieram)

1. **O pp É, em muitas formas, um refatorador.** Capaz de transformar padrões
   EXTREMAMENTE complexos. (`#command`/`#translate`/`#xcommand` são regras
   padrão→substituição — a definição de refatorar: casar uma forma, emitir
   outra.)
2. **O pp já opera sobre TODO código Harbour.** É universal e canônico —
   "isso pode valer para algo": uma transformação expressa COMO pp fala a
   língua que todo o ecossistema já roda.
3. **Mapear as transformações dá um GRAFO.** "acaba-se por ser possível mapear
   onde um token foi recriado, então passamos a ter as posições originais
   pré-passagem do processador E pós passagem. isto pode trazer insights ou
   soluções."
4. **Tratar diretivas COMPLEXAS.** "o código do Harbour está cheio delas" — a
   régua não são toy-DSLs, são as diretivas reais (hbclass, std.ch, contribs).
5. **Usar `.ppo` e `.ppt` como oráculo.** "para realmente ir fundo você vai
   precisar usar as gerações .ppo e .ppt para investigar o que o pré-compilador
   está fazendo em cada caso." (`.ppo` = saída expandida; `.ppt` = TRAÇO passo
   a passo, anotado por linha-fonte.)
6. **Enraizar a AST na fase pp.** "se o pp já produz um traço e informação rica
   (e poderíamos torná-lo mais rico), por que não começar a AST já na fase do
   pp e então enriquecer o dump da AST?"
7. **Estender `.ppo`/`.ppt` ao máximo.** "se investigar ao máximo o quanto
   podemos estender os .ppo e .ppt, podemos chegar a soluções nunca imaginadas.
   o Harbour pp é algo único."

## A tese, em uma frase

O preprocessador do Harbour é um **motor de reescrita de termos** que, no
instante da síntese, CONHECE a proveniência completa de cada token gerado
(o `.ppt` prova: cada `(concatenate)` vem anotado com a linha-fonte). Logo a
AST não deveria RE-PROJETAR essa proveniência a posteriori (perdendo-a nas
diretivas complexas) — deveria **nascer com ela**, capturada no FUNIL do pp,
e o dump apenas a carrega.

## O que está PROVADO (fatos desta sessão, com `.ppo`/`.ppt`)

1. **O `from` (ast-3) já é um grafo pré↔pós reconstruível.** Andando-o com
   aritmética de faixa: `Caixa_Info` ← paste(`Caixa`@4:13, `Info`@8:10);
   `"Info"` ← stringify(`Info`@8:10); `mk_Vendas` ← paste(`Vendas`@7:5). Os
   `op` (clone/paste/stringify) são as arestas.
2. **O `.ppt` é o MESMO grafo, no pp, anotado por linha-fonte — e é COMPLETO.**
   A impl de método `METHOD Info() CLASS Caixa` (`c1.prg(17)`) mostra
   `(concatenate) >Caixa_Info<` anotado na linha 17.
3. **O grafo vive em DUAS relações, e ambas são fiéis (correção do spike 1).**
   O spike investigou "por que @17 não aparece no grafo" e derrubou a hipótese
   de lacuna NO `from`: um diagnóstico gated no `hb_pp_drvMerge` provou na impl
   `'Caixa_'+'Info'  pos2 -> 8:10` — o hbclass GERA uma regra na declaração com
   o nome assado de @8; a impl @17 apenas CASA essa regra. `from` = derivação
   de bytes (fiel); `ppApplications` = consumo (onde @17 vive). Sem lacuna
   NESSAS duas relações.
4. **Mas havia uma TERCEIRA relação faltando — e era ela o conserto (correção
   da correção).** A hipótese intermediária "o homônimo pede binding, não
   grafo" TAMBÉM caiu. O que separa `? Vendas()` (fora) da impl @17 e do
   `USA Ponto` (dentro) é a **GENEALOGIA DE REGRA**: a regra que @17/`USA`
   casam foi **GERADA por uma aplicação do próprio nome**; a regra `?` não
   foi gerada por ninguém. Esse elo (regra → aplicação criadora) existia no
   pp (o probe do registro provou: `drvFind` acerta nos tokens da diretiva
   gerada no instante do `trackRuleAdd`) e não era emitido. **A visão do
   Diego — mapear o grafo — era exatamente o conserto; zero binding no
   resultado.**
5. **ENTREGUE (ast-13 + consumidores, mesma sessão).** (a) Canal: `from` nos
   tokens de `match[]`/`result[]` de regra gerada (`ppcore.c` `HB_PP_RULETOKEN`
   + accessors `hb_pp_trackRuleTokenFrom*` + emissão `compast.c`); (b)
   derivação sobrevive ao clone (`hb_pp_tokenClone` copia as entradas — o
   literal de result de regra gerada mantém a origem através das aplicações;
   a string derivada vira artefato previsível); (c) consumidores: coleta de
   sementes com gate de pertencimento por fato, resolução `genrule`,
   verificação com renome opcional do nome cru. Provas: caso 108 (14 checks,
   fixgen — DSL inventada não-espelho) + regras METHOD do hbclass real; suíte
   **796/0**, `lexdiff 0`, zero drift nos 782 checks pré-existentes.

6. **P2 (caso 109) — mecânica do pp descoberta com `.ppo`/`.ppt`, e o
   PRINCÍPIO ESTRUTURAL de segurança.** Investigando "marker que gera E passa
   adiante" (adr-003:87-90), o método-oráculo do #5 do Diego rendeu fatos novos
   sobre o grafo, e um princípio que sustenta as próximas fatias:
   - **O `(concatenate)` do `.ppt` é a aresta de PASTE, anotada por linha-fonte.**
     `WRAP Soma` → `.ppt` mostra `(concatenate) >w_Soma<` na linha do uso: o pp
     expõe a colagem como um passo nomeado. É o mesmo fato que o `from` op `paste`
     carrega no dump — o `.ppt` é a face humana dele.
   - **Nem toda diretiva gerada entra no grafo — o pp restringe por FATO.**
     Diretiva que gera `#[x]translate` **NÃO registra** a regra (o nome sai
     literal, `W0001`); só `#[x]command` gerado registra (é o que hbclass e a
     fixgen usam). Comando cuja keyword é COLADA (`SHOW_<n>`) nem casa (`E0020`).
     Consequência para o grafo: as arestas "regra gerada" que existem de fato são
     as de `#[x]command` — exatamente o alcance do ast-13/genealogia.
   - **A multiplicidade no destino é ILIMITADA** e o grafo a acompanha: o mesmo
     token-fonte pode gerar N arestas (paste/stringify repetidos) + M arestas de
     clone; o walker (`PpMarkerArtifacts`, reverse-scan sobre todo `from`) não põe
     teto.
   - **PRINCÍPIO ESTRUTURAL (a razão de fundo da segurança):** a ferramenta não
     precisa MODELAR a multiplicidade nem o aninhamento para ser segura, porque a
     rede de verificação confere o **ARTEFATO COMPILADO FINAL**, não a forma da
     regra — recompilação `-es2` (referências) + símbolos/identidade do `.hrb`
     (delta previsto). Todo caso é rollback honesto OU re-derivação verificada;
     nunca corrupção silenciosa, por mais complexa que a diretiva seja. É o
     complemento do grafo: o grafo PREVÊ (o que vai mudar), a rede GARANTE (que só
     mudou isso). Enquanto o grafo cresce fato a fato, a rede é o piso que segura
     o que o grafo ainda não modela. Registro em
     [spec-p § P2](spec-p-pp-refatoracao.md) e
     [limites-e-alavancas.md](limites-e-alavancas.md).

## Duas leituras (e como a execução as decidiu)

- **Fraca / incremental — EXECUTADA E PAGA.** O primeiro alvo ("carimbar
  `from`→@17") era mal-posto (@17 não deriva os bytes; eles vêm de @8 — a
  correção do spike 1). Mas o alvo CERTO da leitura incremental apareceu na
  sequência: a **genealogia de regra** (a terceira relação) + a derivação
  sobrevivendo ao clone. Entregues como `ast-13` com consumidores reais e
  custo mínimo (um `pFrom` por token de regra gerada; um memcpy por clone
  rastreado). A leitura incremental GANHOU o direito de continuar: o grafo
  cresce fato a fato, cada um com cliente.
- **Forte / radical (o horizonte):** re-enraizar a proveniência num artefato
  de grafo de primeira classe — a leitura literal do #6/#7 do Diego. Segue
  como aposta a provar por casos de uso maiores (P3 find-references através
  de regras geradas; P7 pp-como-instrumento; "expandir esta linha" na
  extensão). O ast-13 é a primeira evidência A FAVOR: o pedaço que faltava
  do grafo consertou um bug real e destravou um rename novo na mesma fatia.

Lição das duas rodadas: hipóteses locais minhas caíram DUAS vezes
(`generates` como filtro; binding como conserto) e a direção estrutural do
Diego (o grafo) venceu nas duas — mas só a EXECUÇÃO decidiu; nenhuma das
leituras se sustentaria por argumento.

## Riscos honestos (registrados, não para varrer)

- **Traço ≠ grafo.** O `.ppt` prova que a informação existe no pp, mas é TEXTO
  sem identidade estável de token entre passes. Enraizar exige tracking
  ESTRUTURADO (app/marker/faixa), não re-rotear o texto do `.ppt`.
- **Regras geradas em tempo de pp.** A lacuna é uma regra que o hbclass CRIA
  durante o preprocessamento. O tracking tem de seguir regras ausentes do
  `ppRules` estático. O pp as vê (o `.ppt` as mostra) — reachable, porém mais
  invasivo que os hooks gated atuais.
- **Custo/tamanho.** hbclass leque-abre em muitos apps `__HB_CLS_*`; um grafo
  COMPLETO pode inchar o dump e o reverse-scan (adr-003:96-98 amplificado).
  Pode exigir emissão opt-in/on-demand. Medir antes de generalizar.
- **Não-regressão sagrada.** Toda mudança no pp mantém `lexdiff 0` e a suíte
  byte-idêntica; valem as 3 armadilhas de build do core (rebuild harbour E
  hbmk2; binários stale; `HB_REBUILD_PARSER` copia os .yyc/.yyh commitados).

## O `.ppo`/`.ppt` como instrumento (liga ao Eixo B, roadmap § P / P7)

O `.ppt` já é um grafo humano do que o pp fez. Estendê-lo (mais rico,
estruturado) é a ponte para o pp-como-INSTRUMENTO: um motor de reescrita que já
roda em todo build, usável como oráculo de equivalência e — a aposta do Diego
#7 — como base de "soluções nunca imaginadas". Este ADR marca a direção; os
vereditos de viabilidade ficam para as fatias P (P3 grafo p/ find-references,
P7 instrumento).

## Renumeração conceitual

O **ast-13** deixou de ser o `genOp` (booleano de nicho, recusado no P1) e
nomeia o primeiro fato do **grafo de transformação**: a genealogia de regra
(+ derivação através do clone). Os próximos pedaços do grafo entram como
`ast-N` seguintes, cada um só com consumidor provado.

## Prova executável (o que ESTÁ fechado)

Investigação P1: casos 51/52/107 (paste/stringify), probes de colisão, walker
de proveniência sobre dumps reais, `.ppo`/`.ppt` do caso de método,
diagnóstico gated no `hb_pp_drvMerge` (revertido). **Entrega ast-13**: core
editado em `ppcore.c` (struct+captura+free+accessors+clone), `hbpp.h`
(declarações), `compast.c` (emissão `from` em rule tokens + schema);
ferramenta: aceite ast-13, `PpMarkerSeeds` v2, `genrule` na resolução,
`hOpt` na verificação; fixture `tests/fixgen` + **caso 108** (14 checks).
Suíte **796/0**, `lexdiff 0` divergências reais. **Commit do core PENDENTE
de autorização por-commit do Diego**; commit do hbrefactor idem.
