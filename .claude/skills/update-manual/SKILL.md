---
name: update-manual
description: Atualiza o manual vivo (docs/manual.md) E a landing page (site/index.html) num único fluxo — traduz commits para o usuário final, propõe o delta do manual, aplica com aprovação do Diego e regenera a página em seguida. Use ANTES de um commit (analisa o diff staged) ou em catch-up (analisa os commits desde o baseline registrado no manual).
---

# update-manual — manual e página acompanham os commits, juntos

O `docs/manual.md` é a descrição de ESTADO ATUAL do hbrefactor para o programador
Harbour final; o `site/index.html` é a apresentação pública gerada dele. Esta
skill traduz mudanças de código em mudanças nos DOIS — no idioma do usuário,
nunca no jargão interno de fase. Manual e página sempre andam lado a lado: um
único comando cobre as duas etapas.

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
5. **CHANGELOG.md é INSUMO, nunca saída.** A skill o lê (é a voz de usuário da
   entrega); quem o escreve é a sessão da entrega.
6. **Só tocar em docs/manual.md e site/index.html.** Nada de src/, tests/,
   roadmap, specs.
7. **A casca visual da página é patrimônio aprovado** — paleta Nord em custom
   properties, claro/escuro, divisores de tier, escada de certeza, cartões
   antes/depois, mock do Command Palette, logo SVG, botões de copiar. NÃO
   redesenhar; editar a cópia dentro dela. Elemento visual novo só quando o
   conteúdo pedir forma que não existe (ex.: a tabela de schemas) — no estilo
   da casca.
8. **O manual manda sobre a página.** Divergência = a página cede. Nunca claim
   na página sem lastro (com proveniência) no manual.

## Procedimento

### Etapa 1 — o manual

1. **Determinar o escopo.**
   - Ler o cabeçalho de `docs/manual.md`: linha `baseline: hbrefactor@<h1> ·
     harbour-core@<h2>`.
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

Um relatório único: commits analisados → etiqueta de cada um → delta proposto
do manual (ou "sem efeito para o usuário") → após aprovação: o que foi aplicado
no manual + o que mudou na página, seção a seção + baseline novo.

## O que esta skill NÃO faz

- Não escreve CHANGELOG.md, src/, tests/, roadmap, specs.
- Não publica nem commita: deploy do Pages e commits são decisão do Diego.
