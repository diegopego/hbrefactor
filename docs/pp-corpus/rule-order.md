<!-- guarda: corpus_order -->
# Família ORDEM DAS REGRAS — vence a ÚLTIMA declarada (LIFO)

> **O conhecimento mora em [`tests/ppc-order/od.prg`](../../tests/ppc-order/od.prg)** (10
> asserts). Guarda: `corpus_order`. *(Pergunta do Diego, 2026-07-14: "tem uma ordem de execução
> nestes casos e não me lembro se é do primeiro para o último ou o contrário".)*

## A resposta, e ela está no fonte

```c
// ppcore.c, ao registrar a regra:
pRule->pPrev = pState->pCommands;   // a regra NOVA entra na CABEÇA da lista
pState->pCommands = pRule;
```

…e a busca começa pela cabeça. Logo: **a última regra declarada é tentada primeiro**. É **pilha
(LIFO)** — **não** especificidade. A regra mais específica **não tem prioridade nenhuma**: ganha
quem nasceu **depois**.

**Prova (a mesma ambiguidade, nas duas ordens):** com `#xcommand ECO <x>` e `#xcommand ECO <*x*>`
declaradas em ordens opostas, `ECO 5` casa **a última** dos dois lados — o resultado **vira**.
Se o critério fosse especificidade, seria o mesmo nas duas.

## É isto que faz o hbclass funcionar

O `hbclass.ch` declara uma regra **genérica** de `METHOD … CLASS …` que **avisa**
(*"method not declared or declaration mismatch"*), e cada `CLASS` **gera**, em tempo de pp, as
regras **específicas** de cada método (`__HB_CLS_DECLARE_METHOD`, com marcadores escapados
`\<type>`). Como as geradas nascem **depois**, são tentadas **antes**: o método declarado casa a
sua regra; o **não declarado** escorrega para a genérica e leva o aviso.
**O aviso do hbclass é uma consequência direta da ordem LIFO.** *(Provado em miniatura na
fixture.)*

## Multilinha: `;` continua a diretiva, `;;` separa statements

Uma diretiva pode ocupar várias linhas com `;` no fim — continua sendo **uma** regra. Já o `;;`
no **resultado** é o separador de **statement**: é assim que **uma** diretiva entrega **duas**
linhas de código.

**E o `;;` sobrevive no texto**: o `__pp_Process` devolve `od_( 1, 7 ) ;; od_( 2, 8 )` — o pp
**não quebra a linha**; quem parte aquilo em dois statements é o **compilador**. *(Mais uma vez:
o pp mexe em texto; o significado é do compilador.)*

## Consequência para o refatorador

**Não se descobre qual regra casou lendo o arquivo de cima para baixo.** Uma regra pode ser
**sombreada** por outra declarada depois — e regras **geradas** entram na frente de todas. Quem
sabe é o pp: o dump diz, em `ppApplications[].rule`, **qual** regra casou cada sítio. Adivinhar
por leitura é o erro que o `ruletok`/`ast-15` já eliminou noutro eixo.
