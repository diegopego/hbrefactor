<!-- guarda: corpus_cycle -->
# Família CICLO DO PP — a linha é esgotada antes da próxima

> **O conhecimento mora em [`tests/ppc-cycle/cyc.prg`](../../tests/ppc-cycle/cyc.prg)** — que
> compila, **RODA** e se afirma. Guarda: `corpus_cycle` (prova as três faces: o traço, o
> runtime e o teto). Este `.md` é índice e decisão.

**Achado levantado pelo Diego (2026-07-14)** e provado no fonte e nos oráculos.

## O que ensina

**O pp não faz "uma passada" pelo arquivo.** Ele pega um comando e o **reprocessa até ninguém
mais casar** — só então avança. O laço, em `ppcore.c:6587`:

```c
pState->iCycle = 0;                              // zera A CADA comando
while( ! ISEOC( pTokenList ) && iCycle <= iMaxCycles ) {
   if( hb_pp_processDefine( ... ) )    continue; // casou? volta ao INÍCIO da cadeia
   if( hb_pp_processTranslate( ... ) ) continue;
   if( hb_pp_processCommand( ... ) )   continue;
   break;                                        // ninguém casou: o comando acabou
}
```

Três consequências, todas com prova executável:

1. **A ordem é fixa** — `#define` → `#translate` → `#command` — e **a cada substituição o pp
   volta ao início da cadeia**. Um `#command` pode emitir algo que um `#define` come no passe
   seguinte.
2. **O contador zera por comando.** O limite não é do arquivo: é de **cada linha**.
3. **O teto existe, é generoso e é configurável**: `HB_PP_MAX_CYCLES = 4096` (`hbpp.h:412`),
   ajustável por **`#pragma RECURSELEVEL=<n>`**. Estourado, o pp acusa **circularidade
   (E0022)** e deixa o token **por expandir**.

**A prova pelo `.ppt`** (o oráculo do caminho): uma cadeia `E1 → E2 → E3 → E4 → cy_Marca` faz a
**mesma linha do fonte** aparecer **quatro vezes seguidas** no traço; só depois disso a linha
seguinte é tocada.

**A prova pela execução**: o programa **roda**. Se o pp fizesse uma passada só, o compilador
teria recebido `E2` — um símbolo que não existe — e nada compilaria.

**A prova do teto**: a mesma cadeia, com `#pragma RECURSELEVEL=2`, **não compila** (E0022) e o
`.ppo` mostra o token parado no meio do caminho.

## Por que importa ao refatorador

O que chega ao compilador **não é o que a regra emite** — é o **ponto fixo** da cadeia inteira.
Uma diretiva que "parece" gerar `MODERNO x` pode, na verdade, entregar outra coisa três passes
adiante. **Ler o `.ppo` (o destino) sem o `.ppt` (o caminho) esconde o multi-passe** — e é por
isso que o corpus assere os dois. *(Foi exatamente o que aconteceu na família
[pp-as-instrument.md](pp-as-instrument.md): ao tornar o alvo da migração código de verdade, o
passo intermediário sumiu do `.ppo` e continuou no `.ppt`.)*
