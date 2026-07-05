# Inventário do ecossistema Harbour para refatoração automatizada

Projeto **hbrefactor** — ferramenta de refatoração automatizada (rename de símbolos, reordenar/renomear parâmetros, extrair função) para código Harbour, integrada ao VSCode.

Este documento é o resultado da Tarefa 1 do plano: levantamento empírico do que o ecossistema Harbour já oferece como fundação. **Método**: toda afirmação abaixo foi verificada lendo o fonte do harbour-core ou executando os binários compilados. Nada foi respondido de memória.

- Fonte do Harbour: `/home/diego/devel/harbour-core/harbour` (referido abaixo como `$HB_ROOT`)
- Binários: `$HB_ROOT/bin/linux/gcc/` (referido como `$BIN`)
- Includes: `$HB_ROOT/include` (referido como `$INC`)
- Versão observada: Harbour 3.2.0dev (r2305191429)
- Data do levantamento: 2026-07-04

---

## 1. O compilador como biblioteca (fundação F1)

### 1.1 APIs existentes — utilizáveis hoje, sem tocar em nada

- **API C**: `hb_compMainExt()` em `$HB_ROOT/include/hbcomp.h:250`. Compila de arquivo **ou de buffer em memória** (parâmetro `szSource`) e pode devolver o HRB num buffer em memória (`pBufPtr`/`pnSize`). O compilador inteiro é linkável como biblioteca.
- **API em nível .prg**: `HB_COMPILE()`, `HB_COMPILEBUF()`, `HB_COMPILEFROMBUF()` em `$HB_ROOT/src/compiler/hbcmplib.c:199-230`.

**Teste executado** (via `hbrun`):

```harbour
proc main()
   local h := hb_compileFromBuf( "function f(); return 41+1", "-n2", "-q2" )
   ? ValType( h ), hb_BLen( h )       // → C 31   (HRB de 31 bytes em memória)
   ? hb_hrbDo( hb_hrbLoad( h ), "F" ) // → 42
   return
```

Resultado: compilou em memória e executou. **Uma ferramenta escrita em Harbour pode invocar o compilador real, in-process, a cada edição candidata.**

### 1.2 Modelo de escopo interno — completo e correto

- Cada variável é um `HB_HVAR` (`$HB_ROOT/include/hbcompdf.h:96-106`) com `szName`, `cType`, contador de usos (`iUsed`) e **`iDeclLine` — a linha da declaração**.
- Cada função compilada (`HB_HFUNC`, `hbcompdf.h:497-539`) mantém listas separadas: `pLocals / pStatics / pFields / pMemvars / pPrivates / pDetached` (`hbcompdf.h:504-509`). Inclui *detached locals* de codeblocks — o caso mais difícil de escopo da linguagem.

### 1.3 O que NÃO existe: AST persistente

- O nó de expressão `HB_EXPR` (`hbcompdf.h:349-439`) **não tem nenhum campo de posição** (linha/coluna).
- A compilação é **one-pass**: nas regras de statement da gramática (`$HB_ROOT/src/compiler/harbour.y:381-393`), cada expressão vira pcode e é imediatamente liberada com `HB_COMP_EXPR_FREE`. A AST do programa inteiro nunca existe de uma vez.
- Conclusão: "adicionar um flag `--dump-ast`" **não** é uma mudança pequena — exigiria reestruturar o compilador. Esse caminho está descartado.

### 1.4 O caminho viável de F1: gravador de ocorrências

- Toda referência a variável (push, pop, por referência) passa por um único ponto: **`hb_compVariableFind()`** em `$HB_ROOT/src/compiler/hbmain.c:685`, que devolve a variável já resolvida com escopo (local, static, field, memvar, detached de qual bloco). Os geradores `hb_compGenPushVar` / `hb_compGenPopVar` / `hb_compGenPushVarRef` (`hbmain.c:2730-2868`) o utilizam.
- O compilador conhece a linha corrente durante o parse (`HB_COMP_PARAM->currLine`, incrementada em `$HB_ROOT/src/compiler/complex.c:547`).
- **Precedente interno**: o coletor de i18n (`$HB_ROOT/src/compiler/compi18n.c`, flag `-j`) acumula `_HB_I18NPOS { szFile, uiLine }` (`hbcompdf.h:707-711`) durante o parse e grava um `.pot`. A mudança proposta imita esse padrão: um flag novo, uma lista acumulada de ocorrências (símbolo, escopo resolvido, função contêiner, arquivo, linha), um dump no fim.
- Características: sem mexer na gramática, sem novo pcode, sem quebrar `.hrb` — candidata natural a contribuição upstream.
- **Limitação honesta**: o compilador sabe **linha, não coluna** — e em linhas reescritas pelo pré-processador os tokens não correspondem mais ao texto original. Ver §2 (coluna via lexer do pp) e §4 (detecção de linhas transformadas).

## 2. O pré-processador como biblioteca

- API pública completa e linkável em `$HB_ROOT/include/hbpp.h`: `hb_pp_new/init/inFile/inBuffer/parseLine/nextLine/addSearchPath/addDefine`, etc.
- Wrappers em nível .prg em `$HB_ROOT/src/pp/pplib.c`: `__pp_Init()`, `__pp_Process()`, `__pp_AddRule()`, `__pp_Path()`.
- **Lexer standalone exportado**: `hb_pp_lexNew() / hb_pp_lexGet()` — usado em produção pelo **compilador de macros** (`$HB_ROOT/src/macro/macro.y`). Dá à ferramenta um tokenizador de Harbour exato (strings, comentários, `[...]` ambíguo, continuação `;`) sem parser próprio e sem regex.
- `HB_PP_TOKEN` (`hbpp.h:384`) guarda `value/len/spaces/type/index` mas **não linha nem coluna**. Como o pp trabalha linha a linha, a **coluna é reconstruível** para o fonte original acumulando `spaces + len` ao caminhar os tokens de uma linha.
- Divisão de trabalho resultante: o compilador diz *em que linha* está cada ocorrência (§1.4); o lexer do pp, aplicado à linha original, diz *em que coluna*.

## 3. `hbpp` — o binário standalone (veredito)

O `hbpp` (`$HB_ROOT/src/pp/hbpp.c`) tem três papéis: (a) pré-processar `.prg` → `.ppo` (`-w`); (b) gerar tabelas de regras em C — é assim que o build do core gera `pptable.c` a partir de `include/hbstdgen.ch` (`-o`); (c) gerar headers de versão/ChangeLog (`-v`, `-c`).

**Testes executados**:

```sh
# 1) hbpp padrão vs harbour -p — DIVERGEM:
$BIN/hbpp sample.prg -w -i$INC
diff sample_harbour.ppo sample.ppo
#   hbpp expandiu #define e #xcommand do usuário, mas NÃO traduziu
#   os comandos padrão: "SET DELETED ON" e "?" ficaram intactos
#   (harbour -p produz Set( 11, "ON" ) e QOut( ... )).

# 2) Causa (verificada no fonte): hbpp só carrega regras padrão com -u
#    (szStdCh = NULL por padrão; hbpp.c:667,801-802)

# 3) Com -u apontando para as regras padrão — IDÊNTICO byte a byte:
$BIN/hbpp sample.prg -w -i$INC -u$INC/hbstdgen.ch
diff sample_harbour.ppo sample.ppo   # → sem diferenças
```

**Veredito**:

- **hbpp binário: sem benefício exclusivo para a ferramenta de refatoração.** O que ele faz de útil já vem de `harbour -p` (diagnóstico `.ppo`, com a vantagem de refletir exatamente os switches/pragmas da compilação real) ou da biblioteca do pp in-process (§2).
- **Armadilha documentada**: sem `-u<arquivo.ch>`, o `.ppo` do hbpp não representa o que o compilador vê — comandos Clipper padrão não são traduzidos. Qualquer uso do hbpp para diagnóstico exige `-u$INC/hbstdgen.ch`.
- **Valor residual**: o mecanismo `-o` (geração de `pptable.c`) é a referência de como embutir conjuntos de regras pré-compilados, caso a ferramenta um dia precise disso; e o hbpp é a prova de que o motor do pp é totalmente desacoplado do compilador.
- **O benefício real está na biblioteca do pp** (lexer exato + regras custom + `__pp_*` acessível de .prg), não no binário.

## 4. `harbour -p` (`.ppo`): perdas e uso correto

Teste com fonte contendo `#define`, `#xcommand`, `SET DELETED ON`, codeblock e macro `&`:

```sh
$BIN/harbour sample.prg -p -n -q0 -I$INC
```

No `.ppo`: comentários **desaparecem**; `MAX_ITEMS` → `10`; `LOG "inicio"` → `QOut( "LOG:", "inicio" )`; `SET DELETED ON` → `Set( 11, "ON" )`; sincronismo de linhas mantido via `#line` + linhas em branco.

- **Inútil como base de reescrita**: não há caminho de volta do `.ppo` ao `.prg`.
- **Valioso como detector de risco**: comparar a linha N do `.prg` com a linha N do `.ppo` revela exatamente quais linhas o pp transformou — são as linhas onde rename textual ingênuo é perigoso e a ferramenta deve exigir confirmação.

## 5. Artefatos de verificação pós-refatoração

O resultado mais importante do inventário:

```sh
# HRB sem informação de linha:
$BIN/harbour sample.prg -n -q0 -I$INC -gh -l -osample_l.hrb
# (editar o fonte deslocando o código uma linha para baixo)
$BIN/harbour sample.prg -n -q0 -I$INC -gh -l -osample_l2.hrb
cmp sample_l.hrb sample_l2.hrb        # → IDÊNTICO byte a byte

# Sem -l, difere: opcodes HB_P_LINE embutem números de linha no pcode.
```

- **`harbour -gh -l` + `cmp` é o critério mecânico de "pronto"**: byte-idêntico sob deslocamento de linhas (testado), rápido (HRB de ~200 bytes no exemplo), sem gcc nem link.
- `-gc0` (C compacto) é determinístico — o único diff entre duas compilações veio do nome do módulo, derivado do nome do arquivo de saída.
- Via `hb_compileFromBuf()` (§1.1), essa verificação pode rodar **em memória, de dentro da própria ferramenta**.

## 6. Candidatos a reuso em contrib

- **`contrib/hbformat`** (`hbfmtcls.prg`, 963 linhas): lido — processamento caractere a caractere por linha (`SubStr`/`hb_tokenGet`), máquina de estados para strings/comentários, **sem noção de escopo, sem pp, sem visão entre linhas**. **Descartado como fundação de refatoração.** Uso legítimo: formatador pós-edição (é o padrão do projeto harbour-core, inclusive).
- **`hbide`**: **não está no core** — contrib tem apenas `hbformat`, `hbfoxpro` e `xhb` como candidatos desse tipo. Descartado.

## 7. Linguagem de implementação

A ferramenta pode ser escrita **majoritariamente em Harbour**: tudo de que ela precisa já está exposto ao nível `.prg` — pp (`__pp_*`), compilador (`hb_compileFromBuf`), execução de HRB (`hb_hrbLoad`), JSON no core (`$HB_ROOT/src/rtl/hbjson.c`) para falar com o VSCode, e leitura de `.hbp` para descobrir o conjunto de arquivos do projeto. **C entra só na mudança pequena do compilador** (gravador de ocorrências, §1.4), feita no harbour-core e candidata a upstream. Bônus: a ferramenta se auto-testa com o pipeline do §5.

## 8. Síntese

A fundação viável é o trio:

1. **Compilador = oráculo de escopo e ocorrências** — via gravador de ocorrências em `hb_compVariableFind()` (mudança pequena, com precedente interno no compi18n; não "expor a AST", que é inviável no desenho one-pass).
2. **Lexer do pp = precisão de coluna no texto original** — `hb_pp_lexNew/lexGet` + reconstrução `spaces + len`.
3. **`harbour -gh -l` = verificação mecânica byte a byte** — critério de "pronto" de cada fase.

O `hbpp` binário fica fora da fundação (§3); o `hbformat` fica como formatador pós-edição (§6).

---

## Premissa a QUESTIONAR (não assuma correta)

Minha inclinação inicial era "modificar o compilador em si", já que estamos no
fonte dele. Avalie criticamente se a ferramenta deve: (a) ser um projeto
standalone separado que consome saídas do compilador; (b) estender/modificar o
compilador; ou (c) ser escrita parcialmente no próprio Harbour. Diga o que faz
mais sentido e por quê. Reaproveite soluções existentes (hbpp, hbformat,
pré-processador, flags do compilador) SOMENTE quando forem a base certa — quero
uma solução bem construída, não um remendo.

> Nota de estado: a decisão (a)/(b)/(c) é o objeto da Tarefa 3 e deve ser
> respondida com base nas evidências deste inventário, sem tratar a síntese do
> §8 como decisão já tomada.

---

*Próximas etapas do plano: Tarefa 2 (tabela S/H/X de armadilhas da linguagem, indicando quais este desenho elimina), Tarefa 3 (decisão de arquitetura: fundação + forma de entrega) e Tarefa 4 (roadmap por fases com critérios de pronto).*
