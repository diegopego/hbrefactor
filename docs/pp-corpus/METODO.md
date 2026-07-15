# MÉTODO — o processo do estudo do pp *(prompt: colar inteiro ao retomar)*

Este arquivo existe porque o estudo do pp é a frente mais produtiva do projeto **e
não sobrevive à sessão**. Sem ele, ao retomar eu reconstruo o método por leitura,
executo plano com premissa velha, e derivo para caça a bug — os três aconteceram em
2026-07-13, e o Diego corrigiu os três na mão.

**Ele não cria regra nova.** As regras já existem (`CLAUDE.md`, [README.md](README.md),
o checklist do [ROADMAP.md](ROADMAP.md)). O que não existia em lugar nenhum é o que
está aqui: a **ORDEM** e um **EXEMPLO REAL por passo** — o que aconteceu quando eu
segui, ou o que custou quando eu pulei.

---

## A MISSÃO (leia antes de tudo, e releia quando estiver empolgado)

> *"Quando você junta procurar explicar com precisão o que diretivas fazem, com
> código, `.ppo`, `.ppt`, ast, etc., e alterando o core para coletar mais informação
> sob necessidade, aí você cria um **corpus de compreensão completo do pp**."*
> — Diego, 2026-07-13

**O produto é a COMPREENSÃO.** O bug que aparece no caminho é **subproduto** (prove,
marque, siga). O número é **instrumento** (serve para escolher o espécime). "Fechar a
lista de famílias" **não é meta** — a lista acabou em 2026-07-13 e a exploração
continua, agora pelos **usos** no fonte do Harbour.

**Por que o material é o próprio Harbour** *(Diego)*: as diretivas do core **são** a
linguagem; foram escritas por quem conhece o pp a fundo, e por isso **usam os cantos**;
é o código que a ferramenta TEM de aguentar; e vem com oráculo executável (compila).
**Exemplo que eu invento nunca chega nos cantos — eu só invento o que já entendi.**

---

## ⚠️ O MODELO MENTAL — leia isto ANTES de raciocinar sobre qualquer diretiva

*(Exercício pedido pelo Diego, 2026-07-14. Ele apontou o erro que **um LLM comete por
default**: achar que o preprocessador "avalia" o código, ou que "acumula estado" a cada
passada. Um raciocínio errado aqui **contamina todo o resto** — e o resto é este corpus,
que vai treinar o Claude do futuro. Prova executável: [no-eval.md](no-eval.md),
`tests/ppc-eval/ev.prg`.)*

**1. O pp SUBSTITUI TEXTO. Ele não avalia o seu código.**
Não soma, não compara, não conhece valor de variável, não executa nada. O que ele entrega ao
compilador é **texto** — e quem decide o que aquilo significa é o **compilador**.

```harbour
#define N  2 + 3
? N * 2        // o compilador recebe `2 + 3 * 2`  ->  8, e NAO 10
```

`#define N 2 + 3` **não define o número cinco**: define **três tokens**. A precedência que
produz o 8 é do *compilador*, aplicada ao texto colado. **Se você se pegar escrevendo "o pp
calcula", "o pp sabe que vale 5", "o pp resolve a expressão" — pare: está errado.**

**2. A ÚNICA exceção é a condição de diretiva.** O `#if 2 + 3 == 5` **é avaliado**, por um
calculador interno do pp (`hb_pp_calcOperation`). A frase correta é: **o pp não avalia o SEU
código; ele avalia a condição das PRÓPRIAS diretivas.**

**3. Não existe "estado acumulado por passada".** O estado do pp é a **tabela de regras**, e ela
muda quando ele encontra uma **linha de diretiva** — por isso **a posição da diretiva é
semântica** (antes do `#define`, o token passa intacto; depois, casa; depois do `#undef`, volta
a passar intacto). O laço de passes ([pass-cycle.md](pass-cycle.md)) **reprocessa a linha até
ninguém mais casar** — mas **cada passe é substituição de texto, não avaliação**.

**4. A ordem das regras é PILHA (LIFO): vence a ÚLTIMA declarada — não a mais específica.**
*(Pergunta do Diego, 2026-07-14. Prova: [rule-order.md](rule-order.md), `tests/ppc-order/od.prg`.)*
No fonte: a regra nova entra **na cabeça da lista** (`pRule->pPrev = pState->pCommands`) e a
busca começa por ali. **Especificidade não conta.** Duas regras que casam o mesmo texto,
declaradas em ordens opostas, dão resultados **opostos**.
- **É isto que faz o `hbclass` funcionar**: a regra genérica de `METHOD` (que **avisa** *"method
  not declared"*) é declarada no header; as regras **específicas** de cada método são **geradas**
  quando a classe é declarada — e, por nascerem **depois**, são tentadas **antes**.
- **Consequência para a ferramenta**: **não se descobre qual regra casou lendo o arquivo de cima
  para baixo** — uma regra pode ser **sombreada** por outra declarada depois, e as **geradas**
  entram na frente de todas. Quem sabe é o pp: o dump diz, em `ppApplications[].rule`, **qual**
  regra casou cada sítio. **Adivinhar por leitura é o erro que o `ast-15` já matou noutro eixo.**

**5. Sujeito certo, sempre** *(é a versão profunda da regra do § 4b)*: o **pp** copia, cola e
cita; o **compilador** decide o que é variável, aplica precedência e gera pcode; a **VM**
avalia; a **ferramenta** edita. **A maioria dos erros deste corpus foi dar a um o que é do
outro.**

---

# OS 10 PASSOS

## 1. RETOMAR — leia, nesta ordem

`pp-corpus/README.md` (a INTENÇÃO) → o **checklist anti-erro** do
`pp-corpus/ROADMAP.md` → o índice de famílias → a fila de espécimes em
[uses-core.md](uses-core.md).

> **Exemplo do que custa pular:** o roadmap mandava "medir num contrib rico (hbct)".
> Fui executar sem conferir a premissa — o **hbct não tem UMA diretiva de comando**
> (é biblioteca de funções, só `#define` de constante). **Premissa de plano que cai é
> o plano dizendo que está velho: pare e reporte, não siga executando plano morto.**

## 2. ESCOLHER O ESPÉCIME — por FATO, e dentro do Harbour

```bash
HB_BIN=<bin do branch> tools/pp-uses.sh          # o censo: qual arquivo abrir
```

A sonda roda `harbour -x` sobre `work/` e conta `ppApplications[]` — **não é grep**
(grep conta comentário, string literal e ramo de `#ifdef` desligado). Ela aponta
**arquivo:linha**; o alvo é sempre o **fonte do core**, nunca um exemplo meu.

> **Exemplo:** o censo apontou `tests/rddtest/rddtst.prg:33` — a DSL de teste do RDD,
> **1.881 usos**. Foi abrindo ela que apareceram, no mesmo arquivo, o `#<x>` sobre
> nome que também é avaliado, a regra que expande em outra regra caseira, e o `#ifdef`
> com duas regras rivais (que virou a lacuna mais grave do projeto).

### 2b. POR ONDE COMEÇAR — os testes que os AUTORES do pp escreveram *(indicação do Diego, 2026-07-13)*

Antes de sair caçando espécime no censo, **estude os quatro arquivos abaixo**. O censo
acha onde o pp é MUITO usado; estes acham onde ele é usado **de propósito, no limite** —
são o pp testando a si mesmo, escritos por quem o construiu. **É o material mais denso
que existe, e não é meu.** *(Conferidos em 2026-07-13; caminhos relativos a
`~/devel/harbour-core/harbour`.)*

| arquivo | o que tem lá dentro | por que importa |
|---|---|---|
| **`tests/pp.prg`** (89 linhas) | *"Tests for stringify match markers"* — uma bateria de `#command _REGULAR_(<z>)`, `_LIST_`, etc., cobrindo os **tipos de marker um a um**, de propósito | é a família [markers.md](markers.md) **escrita pelo core** — a régua contra a qual conferir tudo o que eu afirmei sobre os 15 mkinds |
| **`tests/ppapi.prg`** (76 linhas) | `__pp_Init` / `__pp_Process` / `__pp_AddRule` — o **pp VIVO**, em processo, injetando regra em runtime | é o oráculo do P11 ([pp-as-instrument.md](pp-as-instrument.md)) e a base do **P12** (o pp como engenho de busca): aqui está como se INJETA uma regra |
| **`tests/pragma.prg`** (54 linhas) | `#pragma TracePragmas`, `ExitSeverity`, `Shortcut`, `/Y+`, e formas malucas (`Shortcut(OFF)`, `BadPragma=off`) | **superfície INTEIRA que o corpus NÃO estudou**: o `#pragma` muda o comportamento do compilador *no meio do arquivo*. Candidata a família própria |
| **`tests/hbpp/`** | `hbpptest.prg` + `_pp_test.prg` + `compare.hb` + `hbpptest.hbp` | o **harness** do pp: como o core testa o preprocessador (e como comparar saídas). Foi por ele que o Diego derrubou minha recusa do P7 |

**Ordem sugerida:** `pp.prg` (a definição, no limite) → `pragma.prg` (a superfície que
ninguém abriu) → `ppapi.prg` + `tests/hbpp/` (o pp vivo, que é o caminho do P12).

### 2c. A PROSA DO AUTOR — o design doc do pp *(indicação do Diego, 2026-07-14; HIPÓTESE, nunca oráculo)*

Dois textos escritos por **Przemyslaw Czerpak (druzus)**, o autor do pp. São o material
mais RICO em INTENÇÃO e VOCABULÁRIO que existe — o §2b dá o pp **testando a si mesmo**;
estes dão o autor **explicando o que quis construir** e como nomeia cada peça. Caminhos
relativos a `~/devel/harbour-core/harbour`.

| arquivo | o que tem lá dentro | por que importa |
|---|---|---|
| **`doc/pp.txt`** (682 linhas) | 25 pontos numerados: tokenização, os match/result markers um a um (a ORIGEM de [markers.md](markers.md)), o algoritmo de substituição define→translate→command (a ORIGEM de [pass-cycle.md](pass-cycle.md)), TEXT/ENDTEXT, compilação condicional, diretiva indireta, extensões sugeridas | é o SPEC do autor por trás de famílias que engenhamos a partir do C — dá NOME e INTENÇÃO ao que descobrimos medindo, e aponta cantos que o censo não acha |
| **`doc/pp_prg.txt`** (103 linhas) | a API `__pp_Init`/`__pp_Reset`/`__pp_AddRule`/`__pp_Process` + um programa que preprocessa um arquivo e roda por macro-compilador | é o SPEC do autor de [pp-api.md](pp-api.md) e do "pp vivo" (camada A do §4) — a régua contra a qual conferir como se usa o `__pp_*` |

**⚠️ A NATUREZA deles é o que os torna PERIGOSOS — é por isso que o Diego mandou "comprove
tudo".** O `doc/pp.txt` é datado **2006-11-08** e NÃO documenta o pp de hoje. São **notas de
análise + PLANO**: em parte dissecação do PP do *Clipper*, em parte projeto do PP novo, em
parte ideias que ele **rejeitou**. Cada frase carrega um TEMPO VERBAL, e o tempo diz que
oráculo apontar:
- **passado / "Clipper does…"** → histórico; pode não sobreviver no Harbour.
- **futuro / "new PP will…"** → intenção; pode ter sido feito assim, pode ter mudado desde então.
- **condicional / "I suggest / I don't want to replicate…"** → talvez nunca construído.

**Duas provas, dentro do próprio arquivo, de que a cautela não é cerimônia:**
1. **Ele se contradiz.** O ponto 3 lamenta a re-estringificação por FLEX; o **Update** no fim
   REVERTE (*"New Harbour lexer… not necessary to convert to strings… works faster"*). O autor
   discorda do autor — o texto tem camadas de tempo dentro dele.
2. **O vocabulário dele COLIDE com um fato que já provamos.** O `pp_prg.txt` chama
   `__DATE__`/`__TIME__` de *"dynamically created #defines"* — mas [dynval.md](dynval.md) provou
   que **só `__FILE__`/`__LINE__` são o mkind `dynval`**. São coisas DIFERENTES (um `#define`
   constante fixado no init × um marker que RE-RESOLVE por posição). Transcrever a prosa dele
   aqui viraria família podre.

**Como usar:** fonte de **HIPÓTESE e de NOME**, jamais de PROVA. Leia `pp.txt` para
ORIENTAÇÃO e VOCABULÁRIO (ele te ensina *o que perguntar*), e então prove no §2b + nos quatro
oráculos. **Nenhuma afirmação dele entra numa família sem `HBTEST`/dump que a confirme no
toolchain de HOJE** — a mesma régua da REGRA DO FATO, aplicada à prosa.

**Ordem sugerida:** `pp.txt` (a intenção e o mapa, lido com ceticismo) → §2b (o pp testando a
si mesmo, executável) → prove.

## 3. LER A DIRETIVA NO FONTE — e colá-la com arquivo:linha

Nada de parafrasear. A diretiva real, como está escrita.

> **Exemplo:**
> ```harbour
> // tests/rddtest/rddtst.prg:33
> #command RDDTESTF <r>, <s>, <x> => rddtst_tst( #<x>, <s>, <x>, <r> )
> ```

## 4. A FIXTURE É O CORPUS — ela COMPILA, RODA e se AFIRMA

*(VIRADA DE MÉTODO, Diego, 2026-07-14: "estes textos markdown vão apodrecer... o melhor
dos mundos: uma explicação em linguagem natural e comprovação via asserts, juntas, em
`.prg`s". O `.md` virou índice; **o conhecimento mora no `.prg`**.)*

O `.prg` tem, no mesmo arquivo: **a explicação densa** (comentário em português, com o
`arquivo:linha` do core) e **a prova** — e são **DUAS camadas**, porque elas **discordam**:

| camada | o que prova | com o quê |
|---|---|---|
| **(A) o que a diretiva VIRA** | o TEXTO da expansão | o **pp VIVO**: `__pp_Init` / `__pp_AddRule` / `__pp_Process` (transforma **sem executar**) — **veja a régua de uso abaixo** |
| **(B) o que a diretiva VALE** | o VALOR em runtime | `HBTEST <expr> IS <esperado>` (`contrib/hbtest`) |

Compila limpo sob `-w3 -es2`; DSL inventada **não-espelho** quando o assunto é capacidade
genérica, o **espécime real** quando o assunto é a diretiva do core.

> **Por que as DUAS** *(exemplo real, e me custou caro)*: o `#<z>` **preserva** o literal
> `"&cAlvo"` — a camada (A) prova. E em runtime aquilo **vale `"oi"`** — a camada (B)
> prova —, porque string com `&nome` é **macro vivo**. Eu tinha escrito no markdown "o
> dumb preserva o texto": certo em (A), **falso** no que o programa vê. **Comentário sem
> assert é opinião.**
>
> **E o assert pega o que o `.ppo` esconde:** ao escrever o teste, a string de ENTRADA que
> passei ao pp (`"SF_NOR( &cAlvo )"`) **se expandiu antes de chegar nele**; depois o VALOR
> ESPERADO também. O fato contaminou o próprio teste — e só apareceu porque **rodou**.

### 4b. COMO ESCREVER O COMENTÁRIO — *interprete o oráculo, não o transcreva* ⚠️

*(Ordem do Diego, 2026-07-14, em três correções seguidas: primeiro os comentários estavam
**imprecisos**; depois **complicados** — ensaio, cruzando arquivos; depois **vazios** — pura
transcrição do oráculo: **"isso eu já tenho. Você precisa INTERPRETAR o que ocorre no oráculo
e explicar"**. E o motivo é maior que a estética: **este material vai treinar o Claude do
futuro** — o que estiver torto aqui vira erro herdado.)*

**Três camadas por sítio, nesta ordem — e nenhuma delas é dispensável:**

| camada | o que é | como errar |
|---|---|---|
| **1. o FATO** | o que o oráculo mostra (`.ppt`, `.ppo`, dump, o valor do assert) | inventar (afirmar sem rodar) |
| **2. o SENTIDO** | **o que aquele fato quer dizer** — o mecanismo que ele revela | **transcrever o oráculo e parar aí** (o Diego já tem a saída do oráculo; ela sozinha não ensina nada) |
| **3. a CONSEQUÊNCIA** | por que isso importa a quem lê/refatora aquela linha | virar ensaio: generalizar, cruzar arquivos, contar a minha história |

**Exemplo — o mesmo sítio, escrito das três formas erradas e da certa:**

```harbour
// ❌ IMPRECISO   -- "o <v> emite a variavel e o #<v> emite o nome"
//                   (o pp nao sabe o que e' variavel: ele COPIA ou CITA)
// ❌ ENSAIO      -- tres paragrafos sobre colisao de nomes, com ponteiro para outro
//                   arquivo e a historia de como eu descobri
// ❌ TRANSCRICAO -- ".ppt: SELO nLastro AFERIDO -> nLastro := sd_Afere( \"nLastro\" )"
//                   (so' isso: e' a saida do oraculo, colada; nao ensina)
//
// ✅ CERTO:
//   O nome escrito UMA vez sai em DOIS papeis: o `<v>` copia o token (o dump marca
//   'clone': ele chega ao compilador, que vai le-lo como variavel) e o `#<v>` cita o
//   texto (o dump marca 'stringify': vira uma string, dado).
//   Quem decidiu o destino de cada um foi a REGRA, nao o texto -- e e' por isso que o
//   nome escrito nao basta para saber o que ele e'.
SELO nLastro AFERIDO
HBTEST nLastro IS 7   // sd_Afere recebeu a STRING "nLastro" (7 letras), nao o valor
```

**RODE ANTES DE ESCREVER.** A ordem certa é: gere os oráculos → **leia** → escreva o que eles
dizem. Escrever primeiro e conferir depois é como eu produzi as três frases falsas que o Diego
teve de pegar no `sd.prg` (*"o `<v>` emite a variável"*, *"o pp guarda o span, não as
palavras"*, *"os três tokens saem com stringify"* — as três, invenção plausível).

**LEIA O DUMP PELOS DOIS LADOS** — a confusão entre eles gerou o pior dos meus erros:

| lado | o que é | o que ele dá |
|---|---|---|
| `ppApplications[]` | o que o pp **CONSUMIU** do seu fonte | **cada palavra escrita, com linha e coluna** (mesmo as que somem depois) |
| `tokens[]` | o que ele **EMITIU** ao compilador | o artefato final, com a **OP da derivação** (`clone`/`paste`/`stringify`) |

*Exemplo:* um wild que engole três palavras **consome três** tokens posicionados e **emite um**
(a string do span). Dizer "o pp não guarda as palavras" é **falso** — e a consequência prática
é grande: a ferramenta tem **posição byte-exata de cada palavra**, mesmo quando o artefato
final é um texto só.

**SEMPRE QUE COUBER, PROVE COM `HBTEST`** *(ordem do Diego)* — inclusive numa fixture cujo
assunto é o dump. Comentário sem assert é a **minha palavra**; o assert é a do programa.
*Exemplo que só o assert dá:* a linha `LAVRA nLastro` (texto que colide com o nome de um local)
entrega à função a **string `"nLastro"`**, e não o **valor** da variável homônima — e é isso que
prova, executando, que aquilo é **dado** e não símbolo.

> **Cuidado ao ler o dump de uma fixture com asserts:** o `HBTEST <x> IS <r>` do core é
> `hbtest_Call( #<x>, {|| <x> }, <r> )` — ele **cita** a expressão (rótulo) e a **copia**
> (avaliação). Logo as próprias linhas de assert aparecem no dump com `clone`+`stringify`.
> Não é ruído: **explique isso no cabeçalho**, ou o leitor se perde. E **ancore a guarda em
> linhas COMPUTADAS do fonte** — contar sítios quebra assim que você acrescenta um assert.

**COMO USAR O pp VIVO — a régua** *(provada em [`tests/ppc-ppapi/pa.prg`](../../tests/ppc-ppapi/pa.prg), família [pp-api.md](pp-api.md); dúvida levantada pelo Diego)*:

- `__pp_Init( [cPath], [cStdCh], [lArchDefs] )` cria um estado **novo e independente**.
  **Sem argumentos** → carrega as **regras padrão** da linguagem. Com **`cStdCh = ""`** →
  **pp virgem**, sem regra nenhuma: é o que você quer quando o alvo é observar **só as suas
  regras**, sem a linguagem no meio.
- **`__pp_AddRule` é OBRIGATÓRIO.** O pp de runtime **não conhece as diretivas do seu
  arquivo** — o pp do compilador morreu com a compilação, e o estado novo nasce sem saber
  nada dele. Se você não registrar a regra, **não está testando a diretiva: está testando
  texto**.
- **Não existe "close"**: o estado é ponteiro sob **GC**. O modelo não é *init/close*, é
  **quantos estados eu quiser, vivos ao mesmo tempo**. **Aninhar é só ter dois** — a mesma
  cabeça pode ter regras **diferentes** em estados diferentes, sem interferência.
- **`__pp_Reset` derruba as SUAS regras e mantém as da linguagem.**

**O ASSERT TEM DE PASSAR PELA DIRETIVA** *(ordem do Diego, 2026-07-14, ao pegar o
`ppc-deriv/dv.prg`)*. Erro real que eu cometi:

```harbour
// ❌ o comentario fala da diretiva, o assert NAO a exercita:
ECOA cAlvo                                  // <- a expansao e' descartada
HBTEST dv_Eco( cAlvo ) IS "oi"              // <- chama a funcao DIRETO. Nao prova nada.

// ✅ o assert consome o RESULTADO da diretiva:
ECOA cAlvo                                  // #xcommand ECOA <x> => s_xEco := dv_Eco( <x> )
HBTEST s_xEco IS "oi"                       // se o marker tivesse CITADO em vez de COPIAR,
                                            // aqui chegaria "cAlvo" -- o nome, nao o valor
```

**Régua**: *se eu apagar a linha da diretiva e o assert continuar passando, o assert é
decorativo*. Todo `HBTEST` tem de consumir algo que **só existe porque a diretiva expandiu**.

**AS DUAS CAMADAS NÃO SÃO OPCIONAIS** — foi a falta da (A) que deixou o `dv.prg` **pobre** em
relação às fixtures que deram certo. Onde couber, a fixture prova **o texto** (camada A, pp
vivo: `__pp_Process`) **e o valor** (camada B, `hbtest`). Uma sozinha deixa metade da verdade
de fora — e foi exatamente a discordância entre as duas que revelou o macro-vivo-em-string.

**As regras da escrita:**
1. **Um fato por frase**, e o fato vem do oráculo — nunca da memória.
2. **Sempre responda "e daí?"**: um comentário que não diz o que o fato SIGNIFICA é lixo com
   aparência de rigor.
3. **Explique a LINHA que está ali.** Generalização, decisão de produto e história do achado
   vão para o `.md` (outro leitor) e para o `ROADMAP.md` (o diário). **Não cruze arquivos.**
4. **Nomeie o sujeito certo.** O **pp** copia ou cita; o **compilador** decide o que é
   variável; a **VM** avalia; a **ferramenta** edita. Trocar o sujeito é o erro mais caro.
5. Cada frase é (a) o que um oráculo mostra, (b) o que o assert ao lado prova, ou (c) uma
   citação do core com `arquivo:linha`. **Não há quarta opção.**

**TODO `.prg` do corpus COMPILA — sem exceção** *(ordem do Diego, 2026-07-14: "tem é que
garantir que vai compilar todos os exemplos")*. A guarda **`corpus_compile_all`** varre
`tests/ppc-*/` inteiro e compila cada um; um `.prg` que não compila é **conhecimento podre**
(CLAUDE.md §3) e o mundo inteiro — IDE incluído — o trata como quebrado.
- Use **`#include "hbtest.ch"`**, **nunca `#require "hbtest"`**: o `#require` só o **hbmk2**
  resolve, então o `harbour` cru (e o lint do editor) veem "syntax error" nas linhas de
  assert. Com `#include` + `-I<core>/contrib/hbtest`, o **mesmo arquivo** compila no
  compilador cru **e** roda pelo hbmk2 (que ainda precisa do `hbtest.hbc` para **linkar**).
- O `.vscode/settings.json` aponta a extensão para o **harbour do FORK** e inclui o
  `contrib/hbtest` — sem isso o editor usa o harbour do sistema e mente (cicatriz §5.3).
- **Custou um caso real:** o `ppc-instr/m.prg` nunca compilou (expandia para uma DSL que não
  existia como código) e ninguém tinha percebido — **a guarda universal o pegou na primeira
  execução**. O conserto foi tornar o alvo da migração código de verdade; o passo
  intermediário **não se perdeu**: migrou para o `.ppt`.

**Fatos que NÃO têm valor em runtime** (posição de token, `mkind`, op de derivação) vão
para uma **fixture-irmã** dumpável pelo `harbour` cru (ex.: `ppc-strfam/sfdump.prg`), e a
guarda os confere no dump. O `#require` do hbtest **só o hbmk2 resolve** — por isso a
separação.

## 5. OS QUATRO ORÁCULOS — todos, e todos ASSERTADOS

```bash
$HB_BIN/harbour x.prg -n -q0 -w3 -es2 -s   # (4) o código COMPILA
$HB_BIN/harbour x.prg -n -q0 -p            # (1) .ppo  - o que o compilador vê
$HB_BIN/harbour x.prg -n -q0 -p+           # (2) .ppt  - o traço, PASSO A PASSO
$HB_BIN/harbour x.prg -n -q0 -xx.ast.json  # (3) dump  - o FATO estruturado
```

**Não é "escolha um".** Cada um vê uma face, e **o achado mora onde eles discordam — ou
onde CALAM**:

- **`.ppo`** = o resultado FINAL. Ele **esconde o caminho**: uma migração de DSL em dois
  passes chega nele já no destino.
- **`.ppt`** = o **caminho**. *(Ordem do Diego, 2026-07-14: "para entender mesmo o
  preprocessador tem que analisar os oráculos incluindo o `.ppt` também".)* É o único que
  mostra **qual regra casou** e **o que ela emitiu em cada passe** — o multi-passe, a regra
  que gera regra, a colagem. **Prova viva:** quando o `ppc-instr/m.prg` passou a compilar,
  o passo intermediário sumiu do `.ppo` — e **continuou no `.ppt`**, que virou o oráculo da
  asserção.
- **dump** = o que a FERRAMENTA vai consumir (ver o passo 5b — ele é o mais importante).
- **o código que roda** = o que o PROGRAMA vê (e que desmente os outros; ver passo 4).

### 5b. A AST NÃO É SÓ ORÁCULO — ELA É O PRODUTO *(ordem do Diego, 2026-07-14)*

> *"Se precisou lembrar do `.ppt`, deve-se lembrar de usar a AST também. Afinal, um dos
> objetivos é garantir que a AST retorna tudo o que precisa, **melhorando cada vez mais a
> AST**."*

Os outros três oráculos são **instrumentos de investigação**; a AST é **o que a ferramenta
consome** — e portanto **é entregável**. Toda família termina com uma pergunta obrigatória,
e a resposta dela é metade do valor do estudo:

> **"O que a ferramenta precisaria saber AQUI, e a AST não conta?"**

Se a resposta não for "nada", é **LACUNA** → passo 7 (estender o core) ou marcação (passo 9).
**Foi assim que nasceram todos os canais**: `ast-13` (genealogia de regra), `ast-14` (marker
numerado), `ast-15` (`ruletok`), `ast-16` (tempo de vida da diretiva), `ast-17` (a linha de
stream posicionada) — em **todos**, o pp sabia e a AST calava. **"A AST já dá o que preciso"
é uma AFIRMAÇÃO DE FATO**: prove olhando o `.ast.json`, não a memória.

**A pergunta não se faz UMA vez — ela é um LOOP** *(Diego, 2026-07-15)*. Entender pelos quatro
oráculos → se a AST **falta um fato**, **melhorar a AST** (estender o core, passo 7) → rodar de
novo → entender de novo → **repetir até não sobrar buraco**. O loop **converge num estado
CONCRETO e conferível, não num palpite**: o código sob teste **compila e RODA**, e a AST o
**COBRE** — todo construto MAIS a proveniência que a ferramenta precisa (o buraco do `dynval`
não era construto faltando: o statement estava no dump, faltava o `from`). São **dois ganhos de
uma vez**: o pp fica **documentado** E a **geração da AST melhora**. A quem produz esse estado é
o agente rodando o loop; a evidência é a **fixture que roda + a asserção de cobertura**. O
veredito de convergência (`COMPLETE`) ou de buraco marcado (`HOLE=Pxx`) fica **registrado com
rastro executável** e o portão **`corpus_completude`** (em `make ppcorpus`) o testemunha — ele
não re-roda o loop, só pega a mentira estrutural. **`METODO-V2` prova a diretiva; `COMPLETUDE`
prova que o loop convergiu.** O passo a passo é ESTE § (5b→7); a fila e o contrato do veredito estão
em `docs/roadmap.md` § P-COMPLETUDE, e o portão que os testemunha é `corpus_completude`
(`tests/ppcorpus.sh`).

## 6. QUANDO O ORÁCULO CALA — VÁ AO FONTE C

`src/pp/ppcore.c` · `src/compiler/compast.c` · `include/hbpp.h`. Ache o **mecanismo**;
não teorize sobre ele.

> **Exemplos — cada um matou uma suposição minha:**
> - `ppcore.c:4277` — `type = fDump ? HB_PP_RMARKER_STRDUMP : ...` → o `strdump` é o
>   **`#<x>`**, e não só o `%s`. *(Eu tinha escrito na doc que ele "não existe em
>   regra". Está em 6 regras do `std.ch`.)*
> - `ppcore.c:5821` — no `TEXT`, **o pp FABRICA o marker** `QOut( %s )`. Ninguém
>   escreveu `%s`.
> - `ppcore.c:5429` — o `'s'` (stringify) registrado no ramo do STRDUMP: é ele que
>   acende o `generates` do `ast-12`.
> - `ppcore.c:7253` — só `__FILE__` e `__LINE__` são `dynval`. *(O `ast-schema` dizia
>   `__DATE__` também. Não é.)*

## 7. FATO FALTANDO → ESTENDA O DUMP (o core)

**Não é licença: é o método** (CLAUDE.md §1.2/§1.4). Padrão do branch, sem inventar
outro:

- gancho curto, **gated por `fTrackPos`**;
- o dado vai para **tabela lateral** (`hb_pp_posRecord`, `hb_pp_track*`), não para o
  token;
- **a expansão não muda** (`lexdiff` 0) — se mudou, está errado;
- rebuild: **apagar `harbour` E `hbmk2`** e refazer os dois (§2 do CLAUDE.md — o `make`
  mente "up to date");
- `make test` byte-idêntico + `make ppcorpus` verde;
- registrar o canal no `docs/ast-schema.md`.

> **Exemplo (`ast-17`):** 16 linhas em `hb_pp_tokenAddStreamFunc` fizeram a linha do
> bloco de stream chegar posicionada (`line: 7, prov: "s"`). **E o critério de valor,
> que é o que decide se vale a pena:** o fato **não protegia uma EDIÇÃO** (dado não se
> edita, nem com opt-in) — **protegia um AVISO**. Sem ele, renomear um símbolo deixava
> o bloco `TEXT` dizendo o nome antigo **em silêncio, para sempre**.

## 8. LENTE DE REFATORAÇÃO — RODE a ferramenta no espécime

Não raciocine sobre o que ela faria. **Rode:**

```bash
./bin/hbrefactor usages <proj> --at <arq>:<lin>:<col>
./bin/hbrefactor rename <proj> <arq>:<lin>:<col> <novo> --dry-run
./bin/hbrefactor verify <proj>
```

> **Exemplos — nenhum dos dois apareceria lendo o código:**
> - `MENU TO nEscolha` (do `std.ch`, Harbour puro): o `usages` chamou um **LOCAL** de
>   *"marker name (no identifiable owner)"* e o `rename` reverteu → **recusa falsa**
>   (fase **P15**).
> - o `#ifdef` do `rddtst.prg`: o `rename` da cabeça **gravou árvore quebrada e
>   anunciou sucesso** (`.ppo`/`.hrb` byte-idênticos) — e o outro build parou de
>   compilar (fase **P17**).

## 9. LACUNA → **PROVE, MARQUE e SIGA** *(regra do Diego, 2026-07-13)*

- **PROVE** — repro executável **mínimo**, colado. "Acho que" não entra.
- **MARQUE** — vira **fase no `docs/roadmap.md`**, com repro, classificação
  (core × consumo) e **critério de pronto mecânico**.
- **SIGA** — o conserto é **fatia própria, sob autorização**. **Não conserte no calor
  do achado** — é exatamente assim que eu pulo o portão.
- **EXCEÇÃO:** achado em que **a ferramenta QUEBRA código do usuário** sobe ao Diego
  **na hora** (urgência de aviso ≠ urgência de conserto).

> **Exemplo:** o P17 (o `rename` quebrando o build alternativo) subiu no mesmo minuto;
> o P15 e o P16 ficaram **marcados** e a exploração seguiu.

## 10. ANCORAR — nesta ordem (a `.md` é a ÚLTIMA, e é curta)

1. **`tests/ppc-<fam>/<fam>.prg`** — o corpus: explicação + asserts (camadas A e B);
   irmã `<fam>dump.prg` para o que só o dump vê;
2. **guarda `corpus_<fam>`** em `tests/ppcorpus.sh` — ela **BUILDA com o `hbtest.hbc`,
   RODA e exige ZERO falhas** (`grep -c '^ *!'`), além de conferir os oráculos;
3. **canal novo** em `docs/ast-schema.md`, se houve;
4. **`arquivo:linha` do core citado → `tests/corerefs.txt`** (senão apodrece calado);
5. **`docs/pp-corpus/<fam>.md` — CURTO**: o que ensina em ~5 linhas, ponteiro para o
   `.prg`, e a seção **Lacunas** (que é decisão, não conhecimento);
6. **verde nos dois**: `make ppcorpus` e `make test`.

> **Exemplo:** `corpus_strfam` roda 20 asserts e exige 0 falhas. A prova deixou de ser
> `grep` e passou a ser **execução**.

---

# AS ARMADILHAS QUE JÁ ME PEGARAM *(todas com cadáver; não são zelo)*

- **Coluna se COMPUTA do arquivo, nunca se conta na cabeça.**
  `python3 -c "l=open('f.prg').read().split(chr(10))[N-1]; print(l.index('nome')+1)"`.
  *A guarda do `corpus_text` falhou na primeira execução porque eu escrevi `7` na mão.*
- **Comando que falha ≠ ausência de fato.** Confira exit code e forma do comando antes
  de concluir "não existe". *(Um glob quebrado quase enterrou o `<@>`.)*
- **`git status` nos DOIS repos depois de rodar o compilador.** *O `sd.c` gerado vazou
  para o `git add` de hoje, escondido atrás do diretório colapsado.* E lixo no diretório
  do fixture faz o `hbmk2` falhar com erro enganoso.
- **Número só via sonda versionada** (`tools/pp-uses.sh`) — nunca de cabeça, nunca de
  script no `/tmp` (morre, e o número apodrece calado).
- **`export HB_BIN`** ao rodar a ferramenta fora do Makefile — sem ele o sintoma é o
  enganoso *"o projeto não compila"*.
- **A régua do caso 64 vale para COMENTÁRIO**: nenhuma palavra de DSL de fixture pode
  aparecer em `src/hbrefactor.prg`, nem em comentário.
- **Citou `arquivo:linha` do core numa doc? ENTRA em `tests/corerefs.txt`.** Toda
  edição minha no core faz as linhas andarem, e a citação apodrece **em silêncio**.
  *Custou caro em 2026-07-13: o `ast-17` (16 linhas novas) envenenou 6 citações
  escritas no mesmo dia, e uma citação antiga já apontava, havia sessões, para código
  sem nenhuma relação com o assunto. A guarda `corpus_refs` agora berra — e ainda
  imprime a linha verdadeira, para o conserto ser um `sed`.*

# O QUE **NÃO** É O PRODUTO

Caça a bug. Contagem. "Fechar a lista de famílias". **Consertar o que se acabou de
achar.** — Se eu estiver fazendo qualquer um desses e não a **compreensão**, saí do
trilho, e o Diego vai ter de me puxar de volta (de novo).
