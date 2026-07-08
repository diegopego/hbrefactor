// fixture B7b (spec-b7b-inferencia.md) - modulo hbclass: retorno de METODO
// (send encadeado), Self em corpo INLINE/OPERATOR (padrao money), blocos
// (detached de binding unico, parametro via Eval, continuacao) e venenos
// (Self envenenado no corpo, ciclo entre metodos, retornos discordantes,
// bloco irrastreavel, detached multi-write).
#include "hbclass.ch"

CREATE CLASS Moeda
   VAR nCents INIT 0
   METHOD Soma( n )
   METHOD Vira( oOutro )
   METHOD Mista( lQual )
   METHOD Total INLINE ::Soma( 0 ):nCents
   OPERATOR "+" ARG nQ INLINE ::Soma( nQ )
END CLASS

METHOD Soma( n ) CLASS Moeda
   // retorno-identidade: todo RETURN devolve Self (encadeia)
   ::nCents := ::nCents + n
   RETURN Self

METHOD Vira( oOutro ) CLASS Moeda
   // veneno: Self reescrito - "RETURN Self" NAO e identidade do receptor
   ::nCents := ::nCents + 1
   Self := oOutro
   RETURN Self

METHOD Mista( lQual ) CLASS Moeda
   // veneno: retornos DISCORDANTES (classe x valor) - a uniao nao fecha
   ::nCents := ::nCents + 2
   IF lQual
      RETURN Moeda():New()
   ENDIF
   RETURN 5

CREATE CLASS Carteira
   VAR oM
   METHOD Pega()
   METHOD Gira( n )
   METHOD Volta( n )
END CLASS

METHOD Pega() CLASS Carteira
   // retorno nao-Self: o fato vem do push rotulado "ret" (ast-6)
   ::oM := NIL
   RETURN Moeda():New()

METHOD Gira( n ) CLASS Carteira
   // veneno: ciclo Gira <-> Volta nos pushes de RETURN - a guarda de
   // ciclo degrada sem fato (o contador so existe p/ terminar em runtime)
   ::oM := NIL
   IF n > 0
      RETURN ::Volta( n - 1 )
   ENDIF
   RETURN Moeda():New()

METHOD Volta( n ) CLASS Carteira
   ::oM := NIL
   IF n > 0
      RETURN ::Gira( n - 1 )
   ENDIF
   RETURN Moeda():New()

PROCEDURE Main()

   LOCAL oC := Carteira():New()
   LOCAL oM := Moeda():New()
   LOCAL oDet := Moeda():New()
   LOCAL oMuda := Moeda():New()
   LOCAL bLe, bPar, bCont, bSolto, bMulti, nX

   // alvo 1: send encadeado - o retorno do metodo resolvido tipa o receptor
   oC:Pega():Soma( 5 )
   nX := oC:Pega():Total
   oM:Soma( 1 ):Soma( 2 )
   // venenos do alvo 1: Self reescrito, ciclo, retornos discordantes
   oM:Vira( oDet ):Soma( 9 )
   oC:Gira( 1 ):Soma( 7 )
   oM:Mista( .T. ):Soma( 8 )

   // alvo 3a: bloco lendo detached de binding unico
   bLe := {|| oDet:Soma( 1 ) }
   Eval( bLe )
   // alvo 3b: parametro de bloco pela uniao dos sites de Eval
   bPar := {| oPar | oPar:Soma( 2 ) }
   Eval( bPar, Moeda():New() )
   // alvo 3b em statement CONTINUADO (a occurrence aponta a ultima linha
   // fisica; a decisao por fato da declaracao nao depende da linha do uso)
   bCont := {| oCont | oCont:Soma( 6 ), ;
      .T. }
   Eval( bCont, Moeda():New() )
   // veneno: bloco que sai da funcao (leitura fora de Eval) - irrastreavel
   bSolto := {| oQem | oQem:Soma( 3 ) }
   Repassa( bSolto )
   // veneno: detached multi-write permanece desconhecido
   bMulti := {|| oMuda:Soma( 4 ) }
   oMuda := Moeda():New()
   Eval( bMulti )

   OutStd( hb_ntos( nX ) + hb_eol() )
   // dispatch REAL do inline da DSL (q2): se o 1o argumento do bloco nao
   // fosse o receptor (classes.c:4554), tigela:mexe() quebraria aqui
   Aquece()

   RETURN

STATIC PROCEDURE Repassa( bQem )
   // o Eval daqui existe, mas o rastro do BLOCO ate ele atravessa a
   // fronteira de funcao - fato nao alcanca, relato honesto
   Eval( bQem, Moeda():New() )
   RETURN
