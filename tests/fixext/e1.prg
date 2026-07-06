// fixture B4e P2a: extract-function em corpo de MÉTODO (extract-to-method)
#include "hbclass.ch"

CREATE CLASS Conta
   VAR nSaldo INIT 0
   VAR nBonus INIT 0
   VAR cLog INIT ""
   VAR nReservado
   METHOD Deposita( nValor )
   METHOD Fatura( nQtde )
   METHOD Extrato()
   METHOD Troca( oOutra )
   METHOD Ajustada()
   PROTECTED:
   METHOD Registra( cEvento )
END CLASS

METHOD Deposita( nValor ) CLASS Conta
   LOCAL nTaxa
   LOCAL nLiquido
   nTaxa := nValor * 0.10
   nLiquido := nValor - nTaxa
   ::nSaldo := ::nSaldo + nLiquido
   ::nBonus := ::nBonus + iif( nLiquido > 50, 1, 0 )
   ::Registra( "dep" )
   RETURN ::nSaldo

METHOD Fatura( nQtde ) CLASS Conta
   LOCAL nTotal
   LOCAL nI
   nTotal := 0
   FOR nI := 1 TO nQtde
      nTotal := nTotal + ::nSaldo
   NEXT
   ::Registra( "fat" )
   RETURN nTotal

METHOD Extrato() CLASS Conta
   RETURN "saldo=" + hb_ntos( ::nSaldo ) + " bonus=" + hb_ntos( ::nBonus ) + " log=" + ::cLog

METHOD Troca( oOutra ) CLASS Conta
   oOutra:nBonus := ::nBonus
   Self := oOutra
   RETURN ::nSaldo

METHOD Ajustada() CLASS Conta
   Espia( @Self )
   RETURN ::nSaldo

METHOD Registra( cEvento ) CLASS Conta
   ::cLog += cEvento
   RETURN NIL

STATIC FUNCTION Espia( o )
   RETURN o

CREATE CLASS ContaVip FROM Conta
   METHOD Deposita( nValor )
END CLASS

METHOD Deposita( nValor ) CLASS ContaVip
   LOCAL nAntes
   nAntes := ::nSaldo
   ::Super:Deposita( nValor )
   ::nBonus := ::nBonus + iif( ::nSaldo - nAntes > 80, 5, 0 )
   RETURN ::nSaldo

PROCEDURE Main()
   LOCAL oC := Conta():New()
   LOCAL oV := ContaVip():New()
   oC:Deposita( 100 )
   oC:Fatura( 3 )
   oC:Deposita( 30 )
   oV:Deposita( 100 )
   OutStd( oC:Extrato() + hb_eol() )
   OutStd( oV:Extrato() + hb_eol() )
   OutStd( hb_ntos( oC:Fatura( 2 ) ) + hb_eol() )
   RETURN
