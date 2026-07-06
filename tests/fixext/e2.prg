// módulo 2 da fixture P2a: material de recusa e de aviso
#include "inc.ch"

FUNCTION RodaExterno( oQualquer )
   RETURN oQualquer:Processa()

METHOD Dobra( nD ) CLASS IncCfg
   LOCAL nR
   nR := ::nV + nD
   nR := nR * 2
   RETURN nR

FUNCTION ForaDeMetodo( oObj )
   LOCAL Self
   LOCAL nX
   Self := oObj
   nX := ::nSaldo + 1
   RETURN nX

CREATE CLASS Sobre FROM HBPersistent
   VAR nPeso INIT 1
   METHOD Calcula( nFator )
END CLASS

METHOD Calcula( nFator ) CLASS Sobre
   LOCAL nRes
   nRes := ::nPeso * nFator
   nRes := nRes + 1
   RETURN nRes
