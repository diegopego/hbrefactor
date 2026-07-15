// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; cada afirmacao esta'
// provada por assert que passa PELA diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
//
// Familia STORE (docs/pp-corpus/store.md) - a multi-atribuicao do Clipper.
// Diretiva real, std.ch:78:
//   #command STORE <v> TO <v1> [,<vN>] => <v1> := [ <vN> :=] <v>
// Um grupo opcional so' -- [,<vN>] -- mas que REPETE: cada variavel extra e' uma
// repeticao do grupo, e o result [ <vN> :=] emite um ":=" por repeticao.
//
// AS DUAS CAMADAS (METODO.md § 4):
//   (A) o que a diretiva VIRA -> pp vivo: STORE 9 TO a, b, c vira `a := b := c := 9`.
//   (B) o que a diretiva VALE -> runtime: a cadeia atribui 9 a TODAS as variaveis.
//
// COMO COMPILAR/RODAR:
//   sintaxe:  harbour storex.prg -n -q0 -w3 -es2 -s -I<core>/contrib/hbtest
//   rodar:    hbmk2  storex.prg  <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbtest.ch"

REQUEST __pp_StdRules

PROCEDURE Main()

   LOCAL a, b, c
   LOCAL pp := __pp_Init()    // regras PADRAO da linguagem: o STORE ja' esta' aqui

   // ----- camada A: o TEXTO (o grupo opcional REPETE) -----
   // STORE e' comando de LINGUAGEM (std.ch), entao o estado padrao ja' o conhece --
   // nao preciso de __pp_AddRule (contraste com a familia <@>, cuja regra era do
   // ARQUIVO). Com UMA variavel o grupo [,<vN>] casa zero vezes -> um ":=" so'.
   HBTEST AllTrim( __pp_Process( pp, "STORE 0 TO a" ) ) IS "a := 0"
   // Com TRES, o grupo casa DUAS vezes (`, b` e `, c`), e o result emite um ":="
   // por repeticao -> a cadeia. E' assim que o Clipper faz "lista" sem marker de
   // lista: um grupo opcional que se REPETE (nao um <x,...> de mkind 'list').
   HBTEST AllTrim( __pp_Process( pp, "STORE 9 TO a, b, c" ) ) IS "a := b := c := 9"

   // ----- camada B: o VALOR (a cadeia atribui a TODAS) -----
   STORE 0 TO a               // a diretiva expandiu para `a := 0`
   HBTEST a IS 0              // le a AQUI: alem de provar o valor, evita o dead-store
                             // W0032 (senao o `a := 0` morreria antes do STORE 9)
   STORE 9 TO a, b, c         // expandiu para `a := b := c := 9`
   HBTEST a IS 9              // as tres recebem o MESMO 9 -- e' a cadeia, nao 3 comandos
   HBTEST b IS 9
   HBTEST c IS 9

   RETURN
