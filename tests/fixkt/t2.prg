// fixture B9 - modulo 2: os sends que o usages classifica sob -kt.
// oCta e parametro ANOTADO em modulo -kt: invariante imposta (camada
// guaranteed). aC e DIMENSIONADA reatribuida para um objeto: a marca
// "dim" (ast-7) diz que o 'A' interno NAO e promessa - o veredito cai
// para possible HONESTO (a declaracao dimensionada ja conta um write,
// entao o binding unico nao fecha); antes do "dim" este send que RODA
// saia "excluded ... kind array" - resposta ERRADA, fechada aqui.
// A classe referida por AS CLASS precisa estar declarada NO MODULO
// (canal por modulo - sem isso o compilador degrada o tipo para 'O' e a
// invariante perde o nome; idioma do ast-schema).
_HB_CLASS Conta

PROCEDURE Fluxo( oCta AS CLASS Conta )

   LOCAL aC[ 2 ]

   oCta:Credita( 1 )
   // uso do array dimensionado ANTES da reatribuicao (a reatribuicao
   // de dimensionada nunca usada dispara W0032 - comportamento de
   // fabrica, provado no binario antigo)
   aC[ 1 ] := 1
   aC := Conta():New()
   aC:Credita( 2 )
   OutStd( "fluxo: " + hb_ntos( oCta:nSaldo + aC:nSaldo ) + hb_eol() )

   RETURN
