# Corpus do PP — índice

Fonte de conhecimento viva (fase P, P-DOC): o que o preprocessador do Harbour
REALMENTE faz, provado em diretivas REAIS do core/contribs. Método, formato e
critério: [../spec-pdoc-corpus-pp.md](../spec-pdoc-corpus-pp.md). Guarda
executável SEPARADA do contrato: **`make ppcorpus`** (o `make test` fica
byte-idêntico). Cada família casa a diretiva com os **QUATRO oráculos** — `.ppo`
(expandido) + `.ppt` (traço) + ast dump (mkinds/roles) + fixture COMPILÁVEL — e
explica bilíngue (técnico + programador Harbour).

## ⚠️ ORGANIZAÇÃO — instrução permanente (para o Claude do futuro)

**UM ARQUIVO POR FAMÍLIA** (`docs/pp-corpus/<familia>.md`), auto-contido. Este
README é só o ÍNDICE enxuto. **NUNCA concentrar tudo num arquivo só** — o corpus
cresce sem limite e um arquivo gigante estoura o contexto. Fluxo de consumo
futuro: leia este índice (pequeno) → ache a família pelo FATO que precisa (coluna
"ensina") → carregue SÓ aquele arquivo. Cada família ~60-140 linhas; se passar
muito, divida em sub-arquivos. Ao adicionar família: crie o `.md` próprio, some
uma linha na tabela abaixo, some um `corpus_<fam>` em `tests/ppcorpus.sh`.

## ⚠️ SER CRÍTICO — caçar o que NÃO vem (instrução permanente, ordem do Diego)

O corpus não é só descritivo. Em cada família, pergunte: *o que os quatro
oráculos NÃO mostram que um refatorador iria querer?* Toda família tem uma seção
**Lacunas** com essa análise, e cada item é classificado por FATO em UMA de duas:

1. **Consumo futuro** — o fato JÁ existe no dump/oráculos (derivável), só falta a
   ferramenta consumi-lo. NÃO pede mudança de core; vira item das fatias P3-P8.
2. **LACUNA real** — a informação NÃO está nos oráculos (nem derivável). Aqui vale
   a regra dura do Diego: **a lacuna PAUSA a exploração**. Ao detectá-la: (a) crie
   um todo imediatamente; (b) faça o EXPERIMENTO já — tente resolver ESTENDENDO o
   fonte do Harbour (`.ppt`/`.ppo`/dump mais ricos, permissão #7 do adr-004);
   (c) só siga a exploração após a tentativa. Vira `ast-N` + caso se destravar,
   ou recusa documentada se a prova mostrar que não compensa.

Distinguir 1 de 2 é uma decisão de FATO (o dado é derivável dos oráculos, sim ou
não?), não de conveniência — não rotular consumo-futuro como "sem lacuna" para
evitar o experimento, nem inventar lacuna onde o dado é derivável. Uma lacuna de
CAPACIDADE da ferramenta (info existe, verbo não) é decisão de produto do Diego,
não experimento de core. Anotar tudo NO CORPUS/roadmap, nunca na memória.

## A tese (o achado que motiva o corpus)

**Grande parte do que parece "a linguagem Harbour" é COMANDO criado por DIRETIVA
de preprocessador.** `SET EXACT ON`, `@ 1,1 SAY x GET y`, `STORE … TO`, o dialeto
OO inteiro (`CLASS`/`METHOD`/`VAR`) são regras `#command`/`#xcommand` nas `.ch`,
não gramática do compilador. Entender o pp = entender o que a maioria do código
Harbour É — a mesma camada universal (o FATO de derivação) em que o hbrefactor age.

### Vocabulário (do core — `doc/pp_prg.txt`)

**diretiva de pp** = a regra `#command`/`#xcommand`/`#translate`/`#define` (o core
chama de *rule*); **comando** = o que o programador escreve (`SET EXACT ON`);
**marker** `<x>` = o coringa; **match** = o que casa; **result** = o que emite.

Como ler o `.ppt`: pares `arquivo(linha) >entrada<` / `#tipo >saída<`; aplicações
em cascata (uma regra sobre o resultado de outra) aparecem em sequência — é o
multi-passe visível. O `(concatenate)` é a colagem (paste) anotada por linha.

## Famílias

| Família | `.ch` (origem) | Ensina (o FATO principal) | Arquivo |
|---|---|---|---|
| SET EXACT | std.ch:121 | marker `restrict` + result `strsmart` (smart-quote); multi-passe com `#define` | [set-exact.md](set-exact.md) |
| `@ … SAY` | std.ch:249 | grupos OPCIONAIS (`opt-open`/`opt-close`) + seleção de forma | [say.md](say.md) |
| STORE | std.ch:78 | grupo opcional que REPETE (multi-atribuição) | [store.md](store.md) |
| hbclass | hbclass.ch:235+ | o dialeto OO É pp: paste do nome, diretiva que gera diretiva, `AS CLASS Self` | [class.md](class.md) |

Planejadas: um contrib rico (hbct/Clipper Tools) para MEDIÇÃO; wild `<*x*>` (SET
ECHO/ENDDO); list marker verdadeiro `<x,...>` (DO … WITH).
