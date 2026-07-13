# Suíte dos exemplos da landing page

**Exemplo na página só existe se ele RODA.** Nenhum bloco de código, nenhuma
saída de terminal e nenhum número da `site/index.html` é escrito à mão: tudo é
produzido executando o `hbrefactor` de verdade contra os projetos deste
diretório, e o build **falha** se a página divergir da execução.

```
make site-examples   # RE-EXECUTA todo exemplo e regrava os blocos da página
make site-check      # FALHA se algum bloco estiver defasado (roda no portão)
```

## Por que isto existe (a cicatriz)

A landing page nasceu com transcripts **inventados**. Havia um projeto
`vendas.hbp` que não existe, um `billing.hbp` que não existe, classes
`Payment`/`Logger` que nunca foram escritas, e uma saída de terminal com números
(`47 matches`, `3 changed inside a string`) que nenhuma execução jamais
produziu. Estavam dentro de uma caixa estilizada de terminal, com botão *Copy* —
ou seja, com todos os sinais visuais de "isto é um transcript real". Não era.

Pior: quando a ferramenta foi traduzida para inglês, um desses blocos passou a
exibir uma mensagem em português que o programa **não emite mais**. O exemplo
tinha apodrecido calado, exatamente como um número mantido à mão apodrece.

Um transcript inventado é uma promessa que o produto não cumpre, e o leitor
descobre isso no primeiro comando que digitar. Para uma ferramenta cuja tese
inteira é *"eu não chuto, eu provo"*, publicar exemplo não-provado é a
contradição mais cara possível.

## O princípio

> **exemplo na página: só o que se executa sozinho.**

Houve um irmão mais velho desta regra — `tools/site-numbers.sh`, que re-media os
indicadores da página (tamanho da suíte, contagem de schemas) e falhava o build se
defasassem. Ele **foi removido** em 2026-07-13, por ordem do Diego: *"quero que tire
estes medidores, isto só atrapalha"*. O número, mesmo automatizado, cobrava um imposto
por entrega (re-medir nos dois repositórios, sujar o core) e não servia a leitor nenhum.
**Número vira comando**; o portão do EXEMPLO, que prova capacidade, é o que fica.

Se um exemplo não pode ser gerado por execução, ele não vai para a página. E se
alguém editar um bloco à mão, o `make site-check` quebra o build — a página não
tem como mentir por descuido, esquecimento ou boa intenção.

## As quatro portas

Cada exemplo atravessa quatro portas antes de virar HTML. Nenhuma delas é
opcional:

1. **O fonte ANTES tem de compilar limpo** (`hbmk2`, com os flags do `.hbp`).
   Fixture que não compila produz diagnóstico enganoso — e um exemplo cujo
   ponto de partida é código quebrado não prova nada.
2. **O comando tem de sair com o exit esperado** (`expect`, default `0`).
   Se a ferramenta regredir e passar a recusar o que antes fazia — ou pior, a
   fazer o que antes recusava — o build cai aqui.
3. **O fonte DEPOIS tem de compilar limpo.** É isto que torna a refatoração
   *provada* e não apenas *executada*: o resultado publicado é código que o
   compilador aceita.
4. **Recusa e relatório têm de deixar o fonte byte a byte intacto.** Um
   `expect: 1` (recusa) ou um `kind: report` (só leitura) que mexa num único
   caractere reprova o build. É a promessa central da ferramenta virada teste.

## Anatomia de um exemplo

```
tests/site/03-reorder-params/
   app.hbp     projeto (qualquer alvo que o hbmk2 aceite)
   app.prg     o(s) fonte(s) — o estado ANTES
   cmd         a linha do hbrefactor, SEM o binário
   show        qual(is) fonte(s) exibir na página — UM POR LINHA
   expect      (opcional) exit code esperado; default 0
   kind        (opcional) `refactor` (default) ou `report` (só lê, não edita)
```

Cada arquivo do `show` vira dois painéis lado a lado — **antes à esquerda, depois
à direita**, cada bloco independente, com numeração de linha própria (o número sai
de um contador CSS, então não entra no copy/paste). Embaixo, a saída real do
comando. Um arquivo que a rodada não mexeu aparece uma vez só.

**O `show` aceita mais de um arquivo, e às vezes ele PRECISA aceitar:** a
refatoração que atravessa a fronteira de arquivo — o `.ch` onde a regra nasce e o
`.prg` onde ela morre — só é honesta na página se os dois aparecerem. Mostrar um
lado de uma edição de dois lados é a mesma meia-verdade que o transcript digitado
à mão contava.

## Como adicionar um exemplo

1. Crie a pasta com os arquivos acima. Mantenha o fonte **curto e legível** —
   ele vai ser lido por um programador Harbour numa página web, não por um
   compilador. É uma restrição de produto, não de teste.
2. Confira que o `.prg` compila limpo sob `-w3 -es2` **antes** de seguir.
3. Ponha o marcador vazio no lugar certo da `site/index.html`:
   `<!-- SITE-EX:03-reorder-params -->`
4. Rode `make site-examples`. O marcador vira o par `BEGIN`/`END` com o bloco
   gerado. **Nunca edite o que está entre eles** — a próxima execução sobrescreve,
   e o `site-check` acusa antes disso.

## O que ainda não está aqui (dívida honesta)

**As quatro seções profundas foram migradas em 2026-07-13** (exemplos 11-18: rename
de `DATA` e a recusa por homônimo, dono do valor de marker, genealogia de regra,
tempo de vida de diretiva, `#uncommand` que casa por padrão, `#uncommand` órfão,
sequestro por abreviação). Elas carregavam transcript colado à mão — e **já tinham
começado a apodrecer**: o bloco do rename de `DATA` exibia uma classe com o membro
`nSaldo` e, embaixo, a saída de um comando que renomeava `nLimite`; o da genealogia
mostrava uma regra `MAKE` cujo corpo não era o da fixture que produzira aquela
saída. Ninguém tinha mentido — o código ao lado do transcript simplesmente
envelheceu sozinho, que é exatamente o modo de falha que este portão existe para
tornar impossível.

**Sobraram dois blocos digitados**, ambos ilustrações de uma linha, e ambos fora do
portão: a saída `confirmed send` da seção dos métodos `INLINE`, e o aborto de
`-kt` (que é um erro de *runtime*, não saída da ferramenta — o portão de hoje roda
o `hbrefactor` e compara fonte, não executa o programa do usuário). O segundo pede
uma porta nova; o primeiro só pede uma fixture.
