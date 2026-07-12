# Roadmap da exploração do PP — estado, plano e o CHECKLIST ANTI-ERRO

Este arquivo existe porque a exploração do pp é LONGA e eu me perdi (ordem do
Diego, 2026-07-12: *"mantenha um roadmap dentro de docs/pp-corpus para não se
perder mais"*). Duas partes: **(1)** onde a exploração está e para onde vai;
**(2)** o **checklist anti-erro** — cada item nasceu de um erro REAL que eu cometi
e o Diego teve que pegar. Ler ANTES de retomar a exploração.

---

# PARTE 1 — O CHECKLIST ANTI-ERRO (ler primeiro, sempre)

> Seis erros meus nesta fase, seis regras. Nenhum foi por falta de capacidade —
> todos por pular uma disciplina que o projeto já tinha. **Rodar o checklist não é
> burocracia: é o que impede o Diego de ter que ser o meu revisor.**

### ❶ Provar, nunca afirmar — inclusive a CLASSIFICAÇÃO
**Erro:** rotulei lacunas como "[Consumo futuro] — derivável do `ppApplications`"
**por raciocínio**, sem rodar o dump. O Diego perguntou "não foram resolvidas?" e,
ao verificar, os rótulos até se confirmaram — mas eu não sabia disso quando
escrevi.
**Regra:** todo item de Lacuna traz **VERIFICADO** + o **trecho do dump colado**.
Sem evidência, é hipótese, não classificação. Vale para o meta-julgamento também:
*"é derivável"* é uma afirmação de fato e exige prova como qualquer outra.

### ❷ Comando que falha NÃO é evidência de ausência
**Erro:** `grep -rn --include=*.ch '<@>'` falhou (erro de glob no zsh, *"no matches
found"*) e eu li o silêncio como **"o `<@>` não tem uso nenhum no core"** — e quase
enterrei o marker mais interessante do pp. O Diego mandou procurar de novo.
**Regra:** antes de concluir "não existe", **conferir o exit code e a forma do
comando**. Silêncio de ferramenta quebrada ≠ ausência de fato. Se a busca é
importante, fazer por dois caminhos.

### ❸ Falta de fato → VÁ AO CORE. "Zero mudança no core" é SINAL DE ALERTA
**Erro:** o recheio de um marker não-numerado chegava com `marker: 0`, igual a uma
palavra da regra. Remendei **na ferramenta**, comparando TEXTO — e repeti "zero
mudança no core" como se fosse virtude. Furo provado em uma linha: `ANOTA ANOTA`
(com `#xcommand ANOTA <*x*>`) classificava conteúdo do usuário como palavra de
regra. **O fato faltava no core** (o pp descartava o casamento) → `ast-14`.
**Regra (agora no [CLAUDE.md](../../CLAUDE.md)):** ao detectar falta de informação,
a primeira reação é **estender o core**. Se um conserto precisou de esperteza na
ferramenta, quase sempre o fato faltava no core e a esperteza é o sintoma.
**Pergunta de controle:** *"o pp SABE isso e não exporta?"* Se sim → core.

### ❹ Régua do caso 64: NENHUMA palavra de fixture no fonte da ferramenta
**Erro:** escrevi `RECOZE MODO <m: FRIO, QUENTE>` num **comentário** de
`src/hbrefactor.prg`. O caso 64 quebrou — corretamente.
**Regra:** exemplos em comentário usam nomes **genéricos** (`<m: A, B>`). A régua
vale para comentário também.

### ❺ Documentação anda JUNTO com o código, não atrás
**Erro:** implementei P4/P5 inteiro (core + ferramenta) com a doc em lugar nenhum.
O Diego perguntou *"a documentação está ficando para trás?"* — e estava, com a
suíte VERMELHA ainda por cima.
**Regra:** ao fechar um achado, **documentar antes de abrir o próximo**. Ordem
quando há regressão: (a) contrato verde primeiro, (b) doc, (c) próximo achado.

### ❻ Achado sobre o PP mora AQUI (`docs/pp-corpus/`)
**Erro:** documentei P4/P5 no `ast-schema`/`spec-p`/`roadmap` e **esqueci o
corpus** — que é justamente a pasta de exploração do pp. O Diego lembrou.
**Regra:** todo fato novo sobre o **pp** ganha entrada no corpus (família própria,
1 arquivo), além do canal técnico (`ast-schema`) e do registro de fase (`spec-p`).

### ❼ Drift em teste PRÉ-EXISTENTE → apresentar ANTES de re-baselinar
Regra que já existia no CLAUDE.md e vale reforçar aqui: quando uma mudança faz um
teste antigo divergir, **apresentar o drift site a site** e deixar o Diego decidir
qual lado cede. Teste novo da própria entrega não precisa de consulta.

---

# PARTE 2 — Estado e plano da exploração

## Método (não negociar)

**Os QUATRO oráculos**, sempre juntos: `.ppo` (expandido) + `.ppt` (traço) +
**ast dump** (o fato estruturado) + **fixture COMPILÁVEL**. Sintaxe e semântica
saem do **fonte do core** (`ppcore.c`, `hbpp.h`, `compast.c`, `ChangeLog.txt`),
nunca de memória. Suíte separada: **`make ppcorpus`** (o `make test` é o contrato e
fica byte-idêntico).

**Classificação de lacuna** (ver [README.md](README.md)): *Consumo futuro* (o dado
ESTÁ nos oráculos → fatia de consumo) × *LACUNA real* (o dado NÃO está → **pausa a
exploração + experimento no core, imediatamente**).

## Famílias do corpus — entregues

| Família | Ensina | Arquivo |
|---|---|---|
| SET EXACT | `restrict` + `strsmart`; multi-passe com `#define` | [set-exact.md](set-exact.md) |
| `@ … SAY` | grupos opcionais (`opt-open`/`opt-close`) + seleção de forma | [say.md](say.md) |
| STORE | o grupo opcional que REPETE | [store.md](store.md) |
| hbclass | o dialeto OO É pp: paste, genealogia, `AS CLASS Self` | [class.md](class.md) |
| **MARKERS** | **os 15 tipos de `<x>`** (6 match + 9 result), com veredito | [markers.md](markers.md) |
| **`<@>`** | **o guarda anti-recursão** de regras circulares | [reference-guard.md](reference-guard.md) |

## Fatias da fase P (roadmap principal: [../roadmap.md](../roadmap.md) § P)

- **P1 ✅** granularidade paste×stringify → `genOp` recusado; `ast-13` (genealogia).
- **P2 ✅** marker que gera E passa adiante → veredito ESTRUTURAL (a rede confere o
  artefato compilado final; indiferente a multiplicidade/aninhamento).
- **P4 ✅ + P5 ✅** os 15 mkinds EXAURIDOS → 13 consumidos, 2 com recusa
  documentada; **`ast-14`** (todo marker de match numerado); `restrict` validado,
  `wild`/descarte separado por fato, `logical`/`nul` relatados. Caso 111.
- **P3** — `generates` para `usages`/find-references (**a hipótese grande**,
  adr-003:60-63). PRÓXIMA na ordem.
- **P6** — estrutura da regra: multi-passe, opcionais reordenados, **regra sem
  cabeça** (`head null`). O miolo "regra-em-expansão" já caiu no P1.
- **P7** (Eixo B) — o pp como INSTRUMENTO (motor/oráculo de migração de DSL).
- **P8** (Eixo C) — edição ESTRUTURAL da regra. *Atenção:* é aqui que o `<@>` vira
  restrição de 1ª classe (não pode ser perdido/movido) — ver
  [reference-guard.md](reference-guard.md) § Lacunas.
- **P9** custo do reverse-scan · **P10** síntese/completude.

## Famílias planejadas para o corpus

- Um **contrib** rico (hbct/Clipper Tools) — MEDIÇÃO, não capacidade (nuance xhb do
  CLAUDE.md: número vindo só de lá não justifica capacidade).
- `TEXT … ENDTEXT` — a maquinaria de **stream** (`#pragma __text`), onde o
  `strdump`/`%s` de fato vive.
- Diretivas com **`#define` dinâmico** (`__FILE__`/`__LINE__`) — o `dynval`.

## Critério de "fase P exaurida"

Cada pergunta do [adr-003](../adr-003-derivacao-pp-como-fato.md) com veredito ·
cada mkind com fixture provando consumo OU recusa documentada (**✅ feito, P4/P5**)
· Eixo B com veredito · todo fato sobrevivente com consumidor + caso na suíte
(nenhum `ast-N` sem cliente) · toda prova em DSL inventada NÃO-espelho.
