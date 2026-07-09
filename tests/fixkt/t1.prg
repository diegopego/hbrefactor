// fixture B9 (-kt): tipos declarados IMPOSTOS em runtime. Cobre as
// decisoes T2 (NIL falha; nao-anotado segue opcional), T3 (is-a passa;
// nao-relacionada falha), T4 (params + locals + retorno via DECLARE), o
// alcance novo (classe montada em runtime passa pelo cheque por NOME no
// objeto vivo - veneno 3, nada keyed a hbclass) e a fronteira da forma
// DIMENSIONADA (LOCAL a[n] NAO e anotacao escrita - reatribuir e legal).
// Valores errados viajam por VARIAVEL (literal direto num call site
// declarado geraria warning estatico em -w3 e -es2 derrubaria o build).
#include "hbclass.ch"
#include "hboo.ch"

DECLARE Metade( nQuanto AS NUMERIC ) AS NUMERIC
DECLARE Torce() AS NUMERIC

CREATE CLASS Conta
   VAR nSaldo INIT 0
   METHOD Credita( n )
END CLASS

METHOD Credita( n ) CLASS Conta
   ::nSaldo := ::nSaldo + n
   RETURN Self

CREATE CLASS ContaVip INHERIT Conta
END CLASS

CREATE CLASS Pedra
END CLASS

PROCEDURE Main()

   LOCAL oErr, xIsca
   LOCAL oCofre AS CLASS Conta
   LOCAL aLivre[ 2 ]

   // T3: subclasse passa; classe exata passa; classe de RUNTIME passa
   OutStd( Guarda( ContaVip():New() ) + hb_eol() )
   OutStd( Guarda( Conta():New() ) + hb_eol() )
   OutStd( Guarda( ForjaConta() ) + hb_eol() )

   // classe NAO relacionada falha nomeando site/declarado/recebido
   xIsca := Pedra():New()
   BEGIN SEQUENCE WITH {| e | Break( e ) }
      Guarda( xIsca )
      OutStd( "NAO checou classe" + hb_eol() )
   RECOVER USING oErr
      OutStd( "cls: " + oErr:Description + " @ " + oErr:Operation + hb_eol() )
   END SEQUENCE

   // T2: NIL falha em parametro anotado...
   BEGIN SEQUENCE WITH {| e | Break( e ) }
      Guarda( NIL )
      OutStd( "NAO checou NIL" + hb_eol() )
   RECOVER USING oErr
      OutStd( "nil: " + oErr:Description + hb_eol() )
   END SEQUENCE
   // ...e o parametro NAO anotado ao lado segue opcional
   OutStd( Etiqueta( Conta():New() ) + hb_eol() )

   // kind errado em parametro anotado
   xIsca := "oito"
   BEGIN SEQUENCE WITH {| e | Break( e ) }
      OutStd( hb_ntos( Metade( xIsca ) ) + hb_eol() )
   RECOVER USING oErr
      OutStd( "kind: " + oErr:Description + " @ " + oErr:Operation + hb_eol() )
   END SEQUENCE
   OutStd( hb_ntos( Metade( 8 ) ) + hb_eol() )

   // local anotado: a boa atribuicao passa e encadeia pela identidade
   // (o uso como ARGUMENTO conta p/ W0032; send nao conta - licao B7)
   oCofre := Conta():New()
   oCofre:Credita( 3 )
   OutStd( Etiqueta( oCofre, "cofre" ) + hb_eol() )
   // ...e a de kind errado falha. O cheque e POS-armazenamento: quem
   // recupera o erro segue com o valor que gravou (filosofia de erro da
   // linguagem) - a ancora vale nos caminhos sem violacao; por isso
   // oCofre nao e mais usado daqui em diante
   BEGIN SEQUENCE WITH {| e | Break( e ) }
      oCofre := xIsca
      OutStd( "NAO checou local" + hb_eol() )
   RECOVER USING oErr
      OutStd( "local: " + oErr:Description + " @ " + oErr:Operation + hb_eol() )
   END SEQUENCE
   // pos-recover a variavel FICA com o que se gravou (fail-fast e do
   // caminho, nao rollback) - o ValType documenta e conta como leitura
   OutStd( "sobra: " + ValType( oCofre ) + hb_eol() )

   // RETURN violando o DECLARE da propria funcao
   BEGIN SEQUENCE WITH {| e | Break( e ) }
      OutStd( hb_ntos( Torce() ) + hb_eol() )
   RECOVER USING oErr
      OutStd( "ret: " + oErr:Description + " @ " + oErr:Operation + hb_eol() )
   END SEQUENCE

   // forma DIMENSIONADA nao e anotacao: reatribuir e legal sob -kt
   aLivre[ 1 ] := 1
   aLivre := "virou string"
   OutStd( aLivre + hb_eol() )

   Fluxo( Conta():New() )

   RETURN

FUNCTION Guarda( oOnde AS CLASS Conta )
   oOnde:nSaldo := oOnde:nSaldo + 1
   RETURN "ok " + hb_ntos( oOnde:nSaldo )

FUNCTION Etiqueta( oQuem AS CLASS Conta, cRotulo )
   RETURN iif( cRotulo == NIL, "sem rotulo", cRotulo ) + ":" + ;
      hb_ntos( oQuem:nSaldo )

FUNCTION Metade( nQuanto AS NUMERIC )
   RETURN nQuanto / 2

FUNCTION Torce()
   // a definicao nao carrega AS de retorno (fato da gramatica): o canal
   // de retorno e o DECLARE la de cima - e este valor o viola
   RETURN "torto"

FUNCTION ForjaConta()
   // classe montada em RUNTIME com o nome declarado: o cheque e por NOME
   // no objeto vivo - o alcance que a estatica nunca teve
   STATIC s_h
   LOCAL oNovo
   IF s_h == NIL
      s_h := __clsNew( "Conta", 1 )
      __clsAddMsg( s_h, "nSaldo", 1, HB_OO_MSG_ACCESS )
      __clsAddMsg( s_h, "_nSaldo", 1, HB_OO_MSG_ASSIGN )
   ENDIF
   oNovo := __clsInst( s_h )
   oNovo:nSaldo := 0
   RETURN oNovo
