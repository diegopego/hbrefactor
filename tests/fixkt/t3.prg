// fixture RE.2/RE.5 - modulo 3: a matriz de cobertura do -kt em sites
// vivos. Pos-RE.5 (K1-K4) a cobertura e FATO do dump (chk, ast-8):
// escrita em bloco e param de bloco AS CLASS viraram sites COBERTOS
// (o selo guaranteed sai do fato); @ref segue descoberto (K5 sob
// medicao) e PARAMETERS segue fora (K6) - sem selo, canal da promessa.
// Nada daqui e chamado em runtime (o run.log do caso 87 nao muda);
// os sends existem para o usages classificar. O site 5 (param de
// bloco AS CLASS) era INESCREVIVEL antes do RE.5 K1 (segfault A6).
_HB_CLASS Conta

MEMVAR oSaco

// site 1 (A1b -> RE.5 K3): local anotado com escrita em codeblock -
// o pos-store detached agora e checado: guaranteed aqui e FATO (chk)
PROCEDURE Sombra( oFonte )

   LOCAL oGuarda AS CLASS Conta
   LOCAL bTroca := {|| oGuarda := oFonte }

   Eval( bTroca )
   oGuarda:Credita( 3 )

   RETURN

// site 2 (A1c, gap extra do RE.1): local anotado passado por @ref - o
// pop acontece no parametro do callee, sem a anotacao do caller
PROCEDURE Refem( oFonte )

   LOCAL oCaixa AS CLASS Conta

   oCaixa := oFonte
   Enche( @oCaixa )
   oCaixa:Credita( 4 )

   RETURN

PROCEDURE Enche( xAlvo )
   xAlvo := "vazou"
   RETURN

// site 3 (A2): PARAMETERS x AS - anotacao no canal, nunca imposta; o
// gate de memvar ja degrada para possible (dynamic dispatch)
PROCEDURE Antiga
   PARAMETERS oSaco AS CLASS Conta
   oSaco:Credita( 5 )
   RETURN

// site 4 (A1a -> RE.5 K2): param de bloco value-kind - o prologo do
// bloco AGORA checa a cada Eval (chk na declaracao); o veredito segue
// excluded pela promessa de KIND (N nunca recebe send de Conta)
PROCEDURE Miuda()

   LOCAL bConta := {| nQtd AS NUMERIC | nQtd:Credita( 6 ) }

   Eval( bConta, 1 )

   RETURN

// site 5 (RE.5 K1+K2): parametro de codeblock AS CLASS - antes do K1
// era INESCREVIVEL (A6: segfault com classe no modulo); hoje a
// anotacao existe no dump (classe transportada), o prologo do bloco a
// impoe a cada Eval e o selo guaranteed sai do fato chk da declaracao
PROCEDURE Nova()

   LOCAL bPaga := {| oQuem AS CLASS Conta | oQuem:Credita( 7 ) }

   Eval( bPaga, Conta():New( 1 ) )

   RETURN
