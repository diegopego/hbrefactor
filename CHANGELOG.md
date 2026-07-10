# Changelog

Escrito para o **programador Harbour final**: o que cada entrega muda no
seu dia a dia, com exemplos e limites honestos. O "como" interno (fases,
specs, decisões) vive em [docs/roadmap.md](docs/roadmap.md) e nas specs
de `docs/`.

## 2026-07-09 — `annotate`: seu código sem tipos vira código tipado, com prova

### O problema de todo dia

Código Harbour típico não diz o tipo de nada:

```harbour
LOCAL oMenu := UWMenu():New()
oMenu:AddItem( "Sair" )
```

Você sabe que `oMenu` é um `UWMenu`. O compilador, não — ele registra e
segue em frente. A consequência aparece nas ferramentas: qualquer busca
de referências ou rename sobre `AddItem` não tem como afirmar *de qual
classe* é aquele send. Ou a ferramenta chuta (e um dia renomeia o método
errado num homônimo), ou é honesta e te devolve "talvez" — que é o que o
hbrefactor faz: sem fato, o site sai `possible`, e conferência manual é
com você.

O detalhe que quase ninguém usa: **a linguagem já tem como dizer os
tipos**. `DECLARE`, `_HB_MEMBER` e `AS CLASS` existem desde sempre,
custam **zero** no programa compilado (nenhum pcode a mais) e alimentam
exatamente o canal que as ferramentas leem. Ninguém escreve porque é
chato, verboso e fácil de errar.

### O que o comando faz

`hbrefactor annotate <projeto>` analisa o projeto inteiro e classifica
cada variável e cada retorno numa escada de certeza:

- **nível 1** — o tipo já decorre do que está declarado; só falta
  escrever o `AS CLASS`.
- **nível 2** — falta *uma linha de declaração* no lugar certo (ex.: o
  `New` herdado que nenhuma classe declara). A ferramenta diz exatamente
  qual linha e onde.
- **nível 3** — a ferramenta até *conclui* o tipo olhando o projeto
  (todos os callers passam `Peca`), mas não existe declaração que
  transforme isso em fato. **Aí ela não escreve nada** — relata e a
  decisão é sua.

Com `--apply`, ela escreve por você — na ordem certa e com verificação
em cada passo:

1. escreve as declarações que faltam (`DECLARE`, `_HB_MEMBER`);
2. **prova que nada mudou no programa**: recompila e exige o binário
   byte-idêntico ao de antes (declaração é compile-time puro — se
   aparecesse um byte de diferença, é rollback automático);
3. prova que o projeto continua compilando limpo com `-w3 -es2`;
4. recompila com `-kt` e **executa** — os cheques de runtime confirmam
   que as anotações dizem a verdade;
5. só então anota as variáveis (`LOCAL oMenu AS CLASS UWMENU := ...`),
   e verifica tudo de novo.

Qualquer falha em qualquer passo: seus fontes voltam byte a byte ao que
eram, com o motivo nomeado.

### O que você ganha

**Antes** (o send encadeado é o exemplo clássico):

```
q1.prg:75: possible send (dynamic dispatch, receiver unknown)  | oM:Soma( 1 ):Soma( 2 )
```

**Depois** de `annotate --apply`:

```
q1.prg:79: confirmed send (receiver class MOEDA via declared types)  | oM:Soma( 1 ):Soma( 2 )
```

Na prática:

- **Rename e usages confiáveis** — sites que eram "talvez" viram fato;
  homônimos param de poluir suas buscas.
- **Documentação de graça** — `LOCAL oMenu AS CLASS UWMenu` conta ao
  próximo programador (e a você daqui a seis meses) o que a variável é,
  sem custar nada em runtime.
- **Fail-fast opcional** — se você compilar com `-kt`, cada anotação
  vira invariante checada: atribuir a coisa errada estoura na hora,
  nomeando variável, esperado e recebido — em vez de um erro de método
  inexistente três telas depois.
- **Seu código continua o mesmo programa** — provado byte a byte, não
  prometido.

No VSCode: `hbrefactor: Annotate report` (só relatório) e
`hbrefactor: Annotate apply` (pede confirmação antes de escrever).

### A mudança no compilador (por que ela foi necessária)

Havia um caso sem saída: método **já declarado** que só precisava ganhar
o tipo de retorno — o `METHOD Soma( n )` dentro do `CREATE CLASS`
declara o método, mas sem tipo. A linha que completa
(`_HB_MEMBER SOMA( n ) AS CLASS MOEDA` depois da classe) sempre
funcionou — o compilador foi *projetado* para a última declaração
prevalecer — mas emitia o warning **W0019 "Duplicate declaration of
method"**, e quem compila com warnings-como-erro (`-es2`) via o build
falhar por causa de uma linha que não muda nada.

A alteração (branch `feature/compiler-ast-dump`, commit `00ccbc20b3`) é
uma condição de cinco linhas: **completar um tipo que ainda não existia
não é duplicata** — segue silencioso. Continua warnando o que deve
warnar: re-declarar um método cujo tipo *já era conhecido* (conflito
real), classe duplicada, função duplicada. Num corpus real (hbhttpd),
18 métodos estavam presos só nesse warning — era o maior bloqueio do
projeto inteiro, e caiu com essa condição.

### O que o comando *nunca* faz

- Não escreve palpite: o nível 3 (só inferência) sai no relatório com o
  motivo, nunca no seu fonte.
- Não toca string, comentário ou dado — só declarações e anotações que
  a recompilação verifica.
- Não edita nada sem `--apply` (e na extensão do VSCode ainda pede
  confirmação antes).
- Não deixa estrago: falhou qualquer verificação, o rollback restaura
  tudo.

### Limites desta entrega (honestos, declarados)

- Parâmetros de função ainda não são anotados — só locais (a assinatura
  pede idioma próprio; fatia futura).
- Projeto que **já** compila com `-kt` fica para a fatia do strip no
  baseline (a prova de byte-idêntico exige compilar sem `-kt`).
- O rollback está exercido por falha real de build, mas o caso provocado
  ("anotação que mente e o `-kt` pega") ainda vira fixture própria.

Detalhes internos: [docs/spec-b9-fatia2-materializacao.md](docs/spec-b9-fatia2-materializacao.md)
§ "Entregue (F2.4)" e [docs/plano-b9-fatia2-escada.md](docs/plano-b9-fatia2-escada.md).
