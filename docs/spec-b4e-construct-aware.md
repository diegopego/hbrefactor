# Spec B4e — comandos de refatoração cientes de construtos de diretiva de pp

Spec-driven: ORDEM DE SERVIÇO escrita ANTES do código (regra do roadmap).
Ler antes de começar: [roadmap.md](roadmap.md) (B4/B4c/B4d),
[ast-schema.md](ast-schema.md) (rastro `from`, receitas B4d), `CLAUDE.md`
dos dois repositórios (regras de trabalho; commits só com autorização).

## Ordem do Diego (2026-07-06, origem desta spec)

> Os recursos de refatoração devem ser completos para o máximo de casos
> possível.

O alvo são os construtos que uma diretiva de pp cria — **método de classe**
(hbclass.ch) e **função gerada por DSL** — hoje cobertos só em parte pelos
comandos que não são da família B4 (usages/rename-dsl/rename-pp-marker já
são cientes; reorder/extract/rename-param/call-graph não).

## Princípio da fase (o critério transversal)

Todo comando de refatoração, aplicado a um construto de diretiva de pp,
faz UMA de duas coisas — **(a)** a refatoração correta e verificada, ou
**(b)** recusa LIMPA com mensagem clara. Nunca corrompe, nunca falha de
forma confusa (o rollback pós-recompilação é rede de segurança, não a
experiência pretendida). A precisão vem do rastro `from` (ast-3): sites que
compartilham origem-fonte colapsam; a declaração de um método/param vive nos
markers posicionados de `ppApplications`.

## Matriz da auditoria (estado ANTES da fase)

| Comando | Método de classe | Função gerada por DSL |
|---|---|---|
| reorder-params | ~~recusa limpa (não resolve método)~~ **P1b: OK** | funciona |
| extract-function | falha controlada (não modela `Self`; rollback) | recusa limpa (N/A) |
| inline-local | funciona | N/A |
| rename-param/local | ~~falha controlada (esquece a assinatura)~~ **P1a: OK** | ~~**corrompia** (double-apply)~~ **P0: OK** |
| rename-static | N/A (recusa limpa) | N/A (recusa limpa) |
| unused-locals | funciona | funciona |
| call-graph | ~~parcial (só símbolo manglado; sem consulta por nome)~~ **P2b: OK** | funciona |
| find-dynamic-calls | ~~ruído (flag do `&` da expansão hbclass)~~ **P3: OK** | correto |

## Itens da fase (prioridade)

### P0 — bug de corrupção (ENTREGUE 2026-07-06)

`rename-local`/`rename-param`: sites que compartilham a MESMA `(linha,col)`
de origem — clones de um único token-fonte que a expansão multiplicou (o
parâmetro de uma FUNCTION gerada, declarado e usado no corpo, deriva do
mesmo marker) — geravam edição dupla na span (`nA`→`nAlfa` virava
`nAlfalfa`), e como nome de local/param não entra no pcode o verify
byte-idêntico deixava passar (corrupção silenciosa, exit 0). Fix: `DedupHits`
por posição-fonte antes de aplicar. Caso 54 (regressão) verde.

### P1a — rename-param/rename-local ciente de assinatura de método

**Escopo**: ao renomear param/local de um MÉTODO, editar também a
DECLARAÇÃO na assinatura da implementação (`METHOD Resize( nW, nH ) CLASS
UWMenu`) e o protótipo no `CREATE CLASS`, não só os usos no corpo. Os
tokens da assinatura são markers posicionados de `ppApplications` — colhê-los
como sites de edição (não aparecem em `hAst["tokens"]` do corpo). Sem tocar
call sites (param é local ao método; sends passam posicional). **Pronto**:
renomear `UWMenu:Resize` param `nW`→`nLargura` recompila, execução idêntica,
round-trip A→B→A byte-exato; fixture com método de 2+ params.

### P1b — reorder-params ciente de método

**Escopo**: (1) resolver `Classe:Método`/nome cru/manglado → função gerada e
lista de params da assinatura (reuso B4d: `MethodImplOf`/`PpMarkerLift`);
(2) reordenar a assinatura (protótipo no `CREATE CLASS` + linha `METHOD`);
(3) reordenar os argumentos nos **call sites de send** (`o:Resize(a,b)`) —
estender o recorte de span de argumentos, hoje só para FUNCALL, aos nós SEND
da árvore (`parms.items[]`); (4) **política de unicidade de mensagem** (a
mesma do rename-method, via `PpMarkerOwners`): só reordenar sends quando o
método pertence a UMA classe do projeto — senão recusa nomeando as classes
(send é despacho dinâmico). **Verificação**: o pcode muda legitimamente
(ordem de push); `HrbSymbolsEqual` (símbolos/funções intactos) em todos os
módulos + rollback. **Pronto**: reordenar `UWMenu:Resize` "nH,nW" edita
assinatura + todos os sends, execução idêntica, round-trip byte-exato;
fixture de recusa com método homônimo em duas classes.

### P2a — extract-function em corpo de método

> **DECISÃO DO DIEGO (2026-07-06)**: suporte **PLENO** já nesta fase, NÃO a
> recusa-limpa recomendada abaixo. Extrair para um novo `METHOD` da classe
> (ou passar `Self` a uma FUNCTION), com `::`/`Self` e os sends internos
> convergindo. Sub-fase maior — encarada quando P1b fechar. A recusa-limpa
> fica como piso de segurança se um sub-caso do range for intratável.

**Escopo recomendado na spec (superado pela decisão acima — piso de
segurança)**: detectar `::`/`Self` no range e RECUSAR com mensagem clara
("o intervalo usa Self — extração de corpo de método ainda não suportada")
ANTES de editar, em vez de depender do rollback pós-recompilação (que hoje
salva mas confunde). **Futuro (agora é ESTA fase, por decisão do Diego)**:
suporte pleno = extrair para um novo `METHOD` da classe (ou passar `Self` a
uma FUNCTION), com os sends internos convergindo.

### P2b — call-graph ciente de método

**Escopo**: resolver nome de método (`Resize`, `Classe:Método`) → símbolo
gerado, para `call-graph Resize` responder a definição; e listar os sites de
send como arestas DINÂMICAS ("dynamic call to Resize" a partir de `sends`)
quando a mensagem é única no projeto (mesma política). **Pronto**:
`call-graph UWMenu:Resize` mostra a definição e os sites que a invocam,
marcados como dinâmicos; sem inventar aresta estática onde não há.

### P3 — find-dynamic-calls: filtrar ruído de expansão de classe

**Escopo**: o `&` interno da expansão do hbclass.ch é atribuído à linha do
`CREATE CLASS` e vira falso positivo. Suprimir finding cujo `usesMacro`
provém de função GERADA/expansão de sistema (o token do `&` não é `prov 's'`
do usuário) — relatar só macro real do código do usuário. **Pronto**:
find-dynamic-calls num projeto com classe limpa reporta 0; um `&` real do
usuário continua flagado.

## Não-objetivos

- Suporte pleno de extract-para-método (P2a v2) — anotado, fase própria.
- Arestas estáticas para dispatch de send (é dinâmico por natureza; só
  anotação a partir de `sends` + unicidade).
- Reescrever a maquinaria B4d — esta fase CONSOME o rastro `from`, não o
  altera; schema permanece ast-3.

## Regras de trabalho da sessão executora

1. Compilar toda fixture ANTES de usá-la (CLAUDE.md).
2. Provar cada fato do dump com sondagem ANTES de codar sobre ele.
3. `make test` é o contrato; casos novos numerados na sequência (55+).
4. Zero impacto no compilador: esta fase é só ferramenta (nenhum gancho
   novo no pp/compilador) — o schema ast-3 já basta.
5. Roadmap e ast-schema atualizados no mesmo commit que mudar comportamento;
   commits só com autorização explícita do Diego.
