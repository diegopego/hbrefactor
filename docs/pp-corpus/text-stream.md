<!-- guarda: corpus_text -->
# Família TEXT/ENDTEXT — o fonte que vira DADO

> **O conhecimento mora em [`tests/ppc-text/txt.prg`](../../tests/ppc-text/txt.prg)** — que
> compila, **RODA** e se afirma (asserts do `hbtest`, capturando a saída do bloco por
> redefinição do `QOut`, como fazem os testes do core). Guarda: `corpus_text`.
> Este `.md` é índice e decisão.

**Diretiva real:** `std.ch:221` — `#command TEXT => text QOut, QQOut`, que põe o pp em modo de
**stream** (`HB_PP_STREAM_CLIPPER`).

## O que ensina

1. **Dentro do bloco, o seu fonte deixa de ser código e vira DADO.** Cada linha crua sai como
   string — **verbatim**, com a margem de espaços inclusa.
2. **As linhas do bloco não passam pela maquinaria de regras.** O dump mostra que a aplicação
   da regra `TEXT` consumiu **um token só** (a palavra `TEXT`): as linhas do meio não casaram
   com nada, não são recheio de marker nenhum. O pp as engole em modo de stream e **fabrica**
   sozinho a chamada de saída (marker `strdump`, `ppcore.c:5821`) — ninguém escreveu `%s`.
3. **O que o pp emite volta para a fila**: as chamadas fabricadas pelo stream são
   **re-escaneadas** pelas regras (a fixture prova redefinindo `QOut`).
4. **A colisão**: uma palavra dentro do bloco pode ser igual ao nome de um local — e continua
   sendo texto. O compilador não vê variável ali (as ocorrências do símbolo, no dump, são só a
   declaração e o uso fora do bloco), e o assert confirma: chega **o nome**, não o valor.

## A lacuna que virou canal (`ast-17`, 2026-07-13)

As strings do bloco chegavam ao dump com **`line: 0`, `col: null`, `prov: "n"`** — **sem origem
nenhuma** —, enquanto uma string comum do mesmo arquivo vinha posicionada. Não era regra sobre
strings: era a maquinaria de stream **descartando** a linha que acabara de ler.

**Por que era correção, e não enfeite:** o conteúdo é dado — a ferramenta **não o edita, nem com
opt-in** (§1) —, mas sem posição ela não podia sequer **RELATAR**. Renomear um símbolo homônimo
deixava o bloco imprimindo o nome antigo **em silêncio**, e nada no mundo podia avisar. **O fato
que faltava não protegia uma edição; protegia um aviso.** *(Conserto no core:
`hb_pp_tokenAddStreamFunc`, gated por `fTrackPos`; expansão intacta.)*

## Lacunas

> Regra: PROVE, MARQUE e SIGA ([README.md](README.md)).

- **[Consumo futuro — VERIFICADO] o `usages` ainda não relata a ocorrência em DADO.** O fato
  existe (posição + `prov: "s"`) e nenhum verbo o usa → fase **P16**. Não implementado.
- **[Limite honesto, não-lacuna] `__stream`/`__cstream` juntam o bloco numa string só** — a
  posição é a do terminador, não a de cada linha. O `TEXT` do Cl*pper (o que a linguagem expõe)
  não tem esse problema. Não vale core novo sem consumidor pedindo.
