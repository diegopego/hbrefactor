---
name: update-manual
description: Mantém a documentação de USUÁRIO em dia com os commits, nos DOIS repositórios — os dois CHANGELOGs (hbrefactor + harbour-core), o manual vivo (docs/manual.md) e a landing page (site/index.html). Cada artefato tem seu próprio ponteiro de baseline, então o serviço é RETOMÁVEL mesmo se o fluxo não rodar por várias entregas. Use ANTES de um commit (analisa o diff staged) ou em catch-up (analisa os commits desde cada baseline).
---

# update-manual — a documentação de USUÁRIO acompanha os commits, nos dois repos

Quatro artefatos, um fluxo. Todos falam a língua do **programador Harbour final**,
nunca o jargão interno de fase:

| artefato | repo | o que é |
|---|---|---|
| `CHANGELOG.md` | hbrefactor | o que mudou, entrega a entrega |
| **`NEWS.md`** | harbour-core | idem, para o branch `feature/compiler-ast-dump` (convenção GNU: `ChangeLog` = desenvolvedor, **`NEWS` = usuário**; o core já tem `ChangeLog.txt`) |
| **`site/index.html`** | harbour-core | a **proposta aos MANTENEDORES** do Harbour — conceito consolidado, **não é log** |
| `docs/manual.md` | hbrefactor | o ESTADO ATUAL da ferramenta |
| `site/index.html` | hbrefactor | a página pública, derivada do manual |

**Cada um carrega o seu próprio PONTEIRO DE BASELINE** (um comentário no topo,
`changelog-baseline:` / `baseline:`) — o último commit já descrito ali. É isso que
torna o serviço **retomável**: se o fluxo não rodar por três entregas, ninguém
precisa adivinhar o que ficou para trás — `git log <baseline>..HEAD` diz. Depois de
escrever, o ponteiro avança.

> **Regra (Diego, 2026-07-12): cada repositório com commit novo ganha a sua
> entrada.** Commitou no core? o `NEWS.md` do core ganha entrada. Commitou nos
> dois? os dois ganham. Nenhum commit de entrega fica órfão de tradução para o
> usuário. *(O buraco que gerou esta regra: os seis comandos da fundação —
> `extract-function`, `inline-local`, `call-graph`, `unused-locals`,
> `find-dynamic-calls`, `reorder-params` — ficaram 8 dias sem UMA linha de
> changelog, porque a regra nasceu depois deles.)*

## Invariantes (não negociáveis)

1. **Propor antes de escrever.** Apresentar o delta do MANUAL site a site
   (seção → texto atual → texto proposto → por quê) e SÓ aplicar depois do OK
   do Diego — espelho da regra de drift do CLAUDE.md e do ethos report→apply do
   próprio `annotate`. A regeneração da página NÃO precisa de segunda
   aprovação: ela é derivação mecânica do manual aprovado.
2. **Não inventar efeito.** Commit interno (refactor, teste, infra, doc
   interna) → declarar "sem efeito para o usuário" e NÃO editar nada.
3. **Claim novo de capacidade = verificação viva.** Antes de afirmar capacidade
   nova, RODAR a ferramenta num fixture de scratchpad (exportar `HB_BIN`;
   compilar o fixture limpo antes — regra do CLAUDE.md). Se `bin/hbrefactor`
   for anterior ao commit analisado, `make build` primeiro. Colar a saída real
   na proveniência. Saídas de terminal exibidas na página = saídas reais.
4. **Respeitar a vacina anti-overclaim** no comentário de cabeçalho do manual
   (comportamentos removidos do veredito — RE.3 etc.). Nunca reafirmá-los.
5. **A skill ESCREVE os dois CHANGELOGs de usuário** (hbrefactor + core) — era
   invariante que ela só os LIA; revogado pelo Diego em 2026-07-12, que esclareceu
   que a proteção valia para os changelogs OFICIAIS do Harbour. **NUNCA tocar em
   `harbour-core/ChangeLog.txt`** (o log técnico do upstream, gerado por ferramenta
   própria do projeto) nem em `debian/changelog`. Se a sessão da entrega já escreveu
   a entrada, a skill CONFERE (e completa), não duplica.
6. **Só tocar nestes quatro arquivos** (os da tabela acima). Nada de src/, tests/,
   roadmap, specs. No core, SÓ o `NEWS.md`, o `site/index.html` e o ponteiro no
   `README.md` — nunca código, nunca
   `ChangeLog.txt`.
7. **A casca visual da página é patrimônio aprovado** — paleta Nord em custom
   properties, claro/escuro, divisores de tier, escada de certeza, cartões
   antes/depois, mock do Command Palette, logo SVG, botões de copiar. NÃO
   redesenhar; editar a cópia dentro dela. Elemento visual novo só quando o
   conteúdo pedir forma que não existe (ex.: a tabela de schemas) — no estilo
   da casca.
8. **O manual manda sobre a página.** Divergência = a página cede. Nunca claim
   na página sem lastro (com proveniência) no manual.
9. **Língua — o PRODUTO é em INGLÊS (Diego, 2026-07-13; REVOGA o "CHANGELOG em
   português" que estava aqui).** A régua é QUEM LÊ: superfície lida pelo USUÁRIO é
   inglês — `CHANGELOG.md` do hbrefactor, `docs/manual.md`, `site/index.html`, as
   mensagens da CLI e toda string que a extensão VSCode mostra. Português fica para a
   CONVERSA (roadmap, specs, CLAUDE.md, comentário de fonte). `NEWS.md` do core: **INGLÊS** — o harbour-core é o projeto Harbour
   internacional e este branch é upstreamável; **tudo lá é em inglês**, inclusive
   mensagem de commit. Manual e página: inglês (público).
10. **PÚBLICO-ALVO: o programador Harbour, NUNCA o contribuidor** (Diego,
   2026-07-12). O changelog do contribuidor **já existe e é o git** — completo,
   preciso, datado. Duplicá-lo em markdown não agrega e cria uma segunda fonte de
   verdade que envelhece pior. O CHANGELOG só se justifica ao responder o que o git
   NÃO responde: *"o que eu passo a poder fazer, e onde isso me morde?"*
   **Régua de reprovação — vale para o CORPO da entrada** (se aparecer lá,
   reescrever): nome de função C ou de arquivo de implementação (`hb_pp_*`,
   `harbour.y`, `ppcore.c`), nome de struct, jargão de build (`lexdiff`, `pcode`,
   `gated`, `schema bump`), número de caso da suíte, sigla de fase. O que fica: o
   problema do dia a dia, o antes/depois, o comando real, o limite honesto.
   **Exceção (já era regra do CLAUDE.md):** um PONTEIRO para os docs internos no
   FIM da entrada é permitido e útil (*"Detalhes: docs/spec-x.md § Y"*) — o que não
   pode é o corpo FALAR nesse idioma. E citar a saída REAL da ferramenta é sempre
   permitido, mesmo que ela mencione uma fase: é o que o usuário vê no terminal.

## Procedimento

### Etapa 0 — os dois CHANGELOGs (vêm ANTES: são o insumo do manual)

0.1 **Ler os dois ponteiros de delta:**
   - `CHANGELOG.md` (hbrefactor) → `<!-- changelog-baseline: hbrefactor@<c1> -->`
   - `~/devel/harbour-core/harbour/NEWS.md` → `<!-- changelog-baseline:
     harbour-core@<c2> (feature/compiler-ast-dump) -->`

0.2 **Para CADA repo, o delta é `git log <baseline>..HEAD`.** Repo sem commit novo
   → nada a fazer nele (dizer isso e seguir). Repo com commit novo → **ganha
   entrada**, mesmo que o outro não tenha.

0.3 **Escrever a entrada** para o programador Harbour: o problema do dia a dia →
   o que muda na prática (antes/depois quando couber) → o limite honesto. Nunca
   jargão de fase (B9/P6/RE.3 ficam nos docs; a entrada só aponta para eles no
   fim). Se a sessão da entrega já escreveu a entrada, **conferir e completar** —
   não duplicar.

   *Se a lacuna for grande (o fluxo não rodou por muitas entregas), agrupar por
   CAPACIDADE, não por commit — o usuário não quer 20 entradas, quer saber o que
   passou a poder fazer. Rotular a entrada como retroativa, honestamente.*

0.4 **Avançar os dois ponteiros** para o `HEAD` do respectivo repo.

0.4b **PIPELINE DO CORE — `commit → NEWS.md → landing page`** (Diego, 2026-07-12).
   Se o core ganhou entrada no `NEWS.md`, reavaliar a página
   `harbour-core/site/index.html` — a **proposta aos mantenedores**, que é o que vai
   decidir se o PR (fase B6) é sequer avaliado. **Ela NÃO é um log**: não ganha uma
   seção por commit, não lista versões de schema. Ela carrega o **CONCEITO
   CONSOLIDADO**, e só muda quando o conceito muda. Pergunte, a cada entrega:
   - o **argumento central** mudou? (hoje: *"o compilador já sabe; este branch faz
     ele contar — e sem `-x`/`-kt` o binário sai byte-idêntico"*);
   - a **forma do diff** mudou? (a tabela de arquivos/linhas — números REAIS,
     `git diff --numstat`, sem os `.yyc`/`.yyh` que o bison gera);
   - entrou um **canal conceitual** novo? (os quatro: posições que sobrevivem ao pp;
     o pp visível; o canal de tipos declarados; a imposição `-kt`) — 15 versões de
     schema NÃO são 15 ideias;
   - achamos outro **bug do stock Harbour**? (é o argumento mais forte que existe:
     vale mesmo se o PR for recusado);
   - mudaram os **números** (asserções/casos da suíte, `.hrb` byte-idênticos)?
   Se nada disso mudou, **a página não muda** — e dizer isso é a resposta certa.
   **NENHUM número na página sem medição na hora** (`git diff --numstat`, contagem
   real da suíte). A página é para mantenedor: um número inflado ou um comando que
   não roda destrói a credibilidade do PR inteiro. *(Já aconteceu: eu ia publicar um
   `make` inventado como "prova" de zero-impacto, e a prova real — 1085/1085 `.hrb`
   byte-idênticos — estava nos commits.)*
   Depois de editar, **republicar o artifact** (mesmo `file_path` → mesma URL).

0.4c **NENHUM NÚMERO NAS PÁGINAS (Diego, 2026-07-13: *"quero que tire estes medidores,
   isto só atrapalha"* — REVOGA o "só o que se mede sozinho").** Não existe mais
   `data-metric`, `tools/site-numbers.sh` nem `make site-numbers`. **Não reintroduza
   contagem de casos, de checks ou de schemas** em `site/index.html` (dos dois
   repositórios) — o que o leitor recebe é o **comando que ele roda** (`make test`,
   `tools/pcode-identity.sh`, `git diff --stat`), e o comando não envelhece.
   `make site-check` continua existindo e continua obrigatório, mas agora só com o
   portão dos EXEMPLOS. *(Números em roadmap, specs e mensagem de commit continuam —
   lá são registro datado, não promessa viva ao leitor.)*

0.5 **Régua anti-buraco (roda sempre, é barata):** confirmar que todo comando que
   o binário expõe hoje (`hbrefactor` sem args) aparece em alguma entrada do
   CHANGELOG. Um comando vivo sem UMA linha de changelog é o buraco que gerou a
   Etapa 0 — não deixar acontecer de novo.

### Etapa 1 — o manual

1. **Determinar o escopo.**
   - Ler o cabeçalho de `docs/manual.md`: linha `baseline: hbrefactor@<h1> ·
     harbour-core@<h2>`. *(É um baseline PRÓPRIO, distinto dos dois da Etapa 0: o
     manual descreve ESTADO, os changelogs descrevem MUDANÇA, e eles podem estar
     em pontos diferentes.)*
   - **Modo pré-commit** (default quando há diff staged): escopo =
     `git diff --cached` + mensagem de commit proposta, se houver.
   - **Modo catch-up**: escopo = `git log <h1>..HEAD` no hbrefactor E
     `git -C ~/devel/harbour-core/harbour log <h2>..HEAD` no core. Analisar
     commit a commit, do mais antigo ao mais novo.

2. **Classificar cada commit/diff.** Uma etiqueta por commit:
   - **capacidade** — comando novo, rótulo novo, comportamento novo visível;
   - **limite** — limite que mudou (fechou/abriu/nuance) ou recusa nova;
   - **canal-core** — schema `ast-N` novo, flag nova, fix no compilador
     (fonte: commits do branch `feature/compiler-ast-dump`);
   - **interno** — sem efeito para quem usa. Regra de bolso: se o CHANGELOG
     não ganhou (nem deveria ganhar) entrada, tende a interno.

   Pistas: a entrada nova do CHANGELOG já é a tradução para o usuário —
   reutilizar a linguagem dela; `echo "case NN:"` novos em tests/run.sh dizem
   o que passou a ser provado; a mensagem de commit costuma nomear o sintoma.

3. **Mapear para o manual.**
   - Os comentários `<!-- prov: ... -->` de cada seção dizem quais casos/
     commits a sustentam → mudança que toca caso/área citada = seção a
     revisitar.
   - Capacidade nova → seção temática certa (e catálogo de comandos se for
     verbo novo); se fechar item de "What's next", MOVER de lá para o corpo.
   - Limite novo/mudado → "Still rough" e/ou "What it never does".
   - Canal-core → tabela da escada de schemas.
   - Números vivos (casos/checks da suíte, versões CLI/extensão) → atualizar
     onde aparecem (Status, Install, cabeçalho).

4. **Propor.** Apresentar ao Diego, por seção: trecho atual → trecho proposto
   → justificativa (commit + caso + verificação viva). Perguntar
   explicitamente antes de aplicar.

5. **Aplicar (só após OK).** Editar `docs/manual.md` conforme aprovado,
   atualizando os comentários `prov:` das seções tocadas e avançando o
   baseline no cabeçalho (`hbrefactor@<HEAD> · harbour-core@<HEAD-do-branch>`
   + data + números da suíte). Se nada mudou (tudo interno), declarar e
   ENCERRAR aqui — a página não precisa de nada.

### Etapa 2 — a página (automática após a Etapa 1 aplicar algo)

6. Ler `docs/manual.md` inteiro (inclusive o cabeçalho) e fazer o diff mental
   seção a seção contra `site/index.html`: o que mudou, entrou, saiu.
   **Editar por seção (Edit), não reescrever o arquivo.** Estrutura espelhada:
   hero → Tier 1 (Start here) → Tier 2 (Going deeper) → Tier 3 (Under the
   hood) → Status → Help wanted → Install → Never does → colophon (disclosure
   do Claude Code + MIT). Seção nova no manual = decidir o tier e inserir;
   seção removida = remover da página. Números vivos e escada ast-N incluídos.

7. **Verificar a página**:
   - balanceamento de tags (parser HTML em python3 no scratchpad);
   - greps de regressão: nenhum número/rótulo defasado do manual anterior;
   - se houve mudança estrutural: preview local (`python3 -m http.server` em
     site/), claro E escuro, janela estreita.

## Saída esperada

Um relatório único: **por repo**, commits desde o baseline → entrada de changelog
proposta (ou "sem commit novo") → etiqueta de cada commit → delta proposto do
manual (ou "sem efeito para o usuário") → após aprovação: o que foi aplicado nos
changelogs/manual + o que mudou na página, seção a seção + **os ponteiros novos**.

## O que esta skill NÃO faz

- Não toca em `src/`, `tests/`, roadmap, specs.
- **Não toca no `ChangeLog.txt` do Harbour** (log técnico oficial do upstream) nem
  no `debian/changelog`, e não toca em NENHUM código do core.
- Não publica nem commita: deploy do Pages e commits são decisão do Diego (no core,
  a autorização é por-commit).
