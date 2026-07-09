// fixture RE.2 - modulo 3: anotacoes em sites que a fatia 1 do -kt NAO
// cobre (matriz do RE.1 na spec-re): a marca kt nao pode sair - o
// veredito degrada para o canal da promessa (declared/possible), sem o
// selo de invariante. Nada daqui e chamado em runtime (o run.log do
// caso 87 nao muda); os sends existem para o usages classificar.
// Param de bloco AS CLASS ficou de fora POR FATO: com classe conhecida
// no modulo o compilador segfaulta (A6); em modulo sem a classe, W0025
// derruba o build sob -es2 - o site e inescrevivel ate o A6 fechar.
_HB_CLASS Conta

MEMVAR oSaco

// site 1 (A1b): local anotado cuja UNICA escrita vive em codeblock -
// store block-relative nao e checado; guaranteed aqui e overclaim
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

// site 4 (A1a): parametro de codeblock anotado com value-kind - o
// binding do Eval nao e checado; o veredito fica no canal declared
// (excluded pela promessa), sem selo kt
PROCEDURE Miuda()

   LOCAL bConta := {| nQtd AS NUMERIC | nQtd:Credita( 6 ) }

   Eval( bConta, 1 )

   RETURN
