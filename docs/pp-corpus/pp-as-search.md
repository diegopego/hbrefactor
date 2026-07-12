# Família O PP COMO ENGENHO DE BUSCA — casar para ACHAR, não para transformar

Índice: [README.md](README.md). Fatia **P12** do roadmap. **Ideia do Diego
(2026-07-12)**, nas palavras dele:

> *"tenho uma ideia de uso do pp que pode ser talvez usada como uma ferramenta
> adicional de inspeção. imagine que ao invés de usar ela para transformar algo,
> usá-la como um engenho de busca com pattern matching? o pattern matching do PP é
> incrível. (…) ainda mais com a vantagem de podermos alterar o core do harbour para
> fazer o PP nos dar ainda mais informações do que já dava."*

> ⚠️ **STATUS: NADA AQUI FOI PROVADO AINDA.** Este arquivo é o **plano de sondagem**
> da fatia, não um registro de fato. Cada afirmação abaixo está marcada
> **[A PROVAR]**. Regra ❶ do [ROADMAP](ROADMAP.md): classificação sem evidência é
> hipótese, não fato. Ao executar o P12, cada item vira **VERIFICADO + trecho do
> dump colado** — ou cai.

---

## 1. Por que a intuição é boa (o que o casador do pp tem que um grep não tem)

O `grep` casa **texto**. O casador do pp casa **estrutura de tokens Harbour**, e já
sabe de graça o que um buscador teria de reimplementar:

| o pp já sabe | exemplo de padrão | o que o grep faria |
|---|---|---|
| lista de argumentos de tamanho livre | `<x,...>` | regex frágil, quebra com vírgula dentro de string |
| pedaço **opcional** | `[ ALL ]` | duas regexes |
| **alternativa restrita** | `<x: ON, OFF>` | alternação, sem noção de token |
| o argumento é uma **macro** | `<x:&>` | impossível |
| o argumento é um **nome** | `<!nome!>` | impossível distinguir de string |
| fronteira de **statement** (`#command`) | cabeça só no início | impossível |
| **abreviação dBase** | `SET EXAC ON` casa `SET EXACT ON` | impossível |
| string com qualquer delimitador (`"` `'` `[]`) | — | pesadelo |

E o argumento mais forte, que não é técnico: **o público-alvo já sabe escrever esse
padrão.** Todo programador Harbour já escreveu um `#command`. Um buscador cuja
linguagem de consulta é a do `#xcommand` tem **curva de aprendizado zero** — não é
uma DSL nova que eu inventei, é a que o Harbour já tem. E ele obedece à REGRA DO
FATO por construção: quem casa é o **casador do core**, não uma réplica minha.

## 2. Usos candidatos [A PROVAR]

1. **Busca estrutural** (`hbrefactor find <padrão>`): *"todo `dbSetFilter( <x> )` em
   que `<x>` é macro"* → `<x:&>`. É a pergunta que o grep não faz.
2. **Lint com regras do USUÁRIO**: o time escreve os anti-padrões da casa como
   padrões de pp num arquivo, e a ferramenta reporta os sites. Um linter cujas
   regras são escritas na linguagem que o usuário já domina.
3. **Codemod / migração**: busca + reescrita — e o **escritor já existe** (P11:
   `__pp_process` calcula o texto novo; a ferramenta grava por posição de byte, com
   os comentários preservados). É o portão **D-P5** generalizado: não só migração de
   DSL, mas de **qualquer** forma de código.
4. **Inventário de uso de uma API**: por FORMA, não por nome (ex.: chamadas com um
   número/arranjo específico de argumentos).

## 3. A dificuldade real — e por que ela talvez já esteja resolvida

**O problema:** `__pp_process` devolve **TEXTO transformado**. Um engenho de busca
precisa de **ONDE** (arquivo, linha, coluna, span de bytes) e **O QUE casou em cada
marker**. Texto não tem isso. O `.ppt` é traço, também texto.

**A hipótese central [A PROVAR]:** *esse canal nós já construímos.* O
`ppApplications` do dump (`-x`) entrega exatamente isso — por aplicação de regra: o
site, as posições, e (com **ast-14**) **todo** marker de match numerado, (com
**ast-15**) qual literal da regra cada token casou, e (com **ast-13**) a genealogia.
Ou seja: **um engenho de busca = `ppApplications` + as regras do USUÁRIO injetadas
no build.** O fato já existe; o que falta é o canal de **injetar a consulta**.

**A sacada que fecha o circuito [A PROVAR]:** uma regra de consulta não pode
transformar o código (senão a busca vira edição). Mas o corpus já tem a peça — o
**`<@>`**, o guarda anti-recursão de regra circular
([reference-guard.md](reference-guard.md)). Uma regra que **casa e se regenera** é um
**NO-OP**: o código sai do pp igual ao que entrou, e mesmo assim a aplicação **fica
registrada no `ppApplications`**. Se isso se confirmar, a **primeira versão da busca
não precisa de mudança nenhuma no core** — é `-u` + regra no-op + dump.

## 4. O que sondar (ordem), e onde o core provavelmente entra

1. Uma regra no-op com `<@>` **registra** aplicação no dump sem alterar o `.ppo`?
   (Se sim: busca sem core, e sem tocar no artefato compilado.)
2. Marker de match casado mas **não usado no result** chega ao dump? — pelo
   **ast-14**, sim; confirmar que vale para a regra no-op.
3. Injetar regra de consulta **sem sujar o projeto**: `-u` (isola as regras do
   usuário) + include forçado. Sonda: `harbour --help` inteiro (regra ❽/❿).
4. **Se** faltar fato, o candidato natural de extensão do core é um **modo de
   consulta**: o pp reporta o casamento **sem aplicar o result** (match-only),
   devolvendo span do site + span de cada marker. Seria o `ppApplications` dirigido
   por regra ad-hoc. **Só depois de (1)-(3) falharem** — "zero mudança no core" não é
   virtude, mas inventar canal que já existe é o outro erro.

## 5. Limites honestos que já dá para antecipar [A PROVAR]

- O pp casa **linha/statement**, não expressão aninhada em profundidade arbitrária:
  buscar *"`Val()` dentro de um `IF` dentro de um `FOR`"* é pergunta de **AST**, não
  de pp. Os dois canais são complementares — a busca boa provavelmente **combina**
  pp (forma do statement) com a AST (contexto, escopo, tipo).
- Regra de consulta mal escrita pode casar demais; o `-u` limita o estrago ao
  relato, não ao artefato.
- Multi-passe: o pp reaplica regras; um "hit" pode ser de código **gerado** por outra
  regra, não escrito pelo usuário. O `from` (ast-3) e a genealogia (ast-13) separam
  os dois — é fato disponível, mas o relato precisa **dizer qual é qual**.

---

## Lacunas (VERIFICADO)

- Nenhuma ainda: a fatia **não foi executada**. Este arquivo é plano, não registro.
