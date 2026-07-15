// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; cada afirmacao esta'
// provada por assert que passa PELA diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
// COMPLETUDE(2026-07-15): COMPLETE
//   O loop dos 4 oraculos convergiu para os construtos que ESTA fixture exercita
//   (VAR INIT, dispatch de METHOD, ::nSaldo, RETURN Self): a AST cobre a genealogia
//   da regra METHOD gerada (from, ast-13), o paste do nome da funcao (Conta_Deposita)
//   e o Self tipado (AS CLASS Conta := QSelf()). Os itens em aberto de rename-DATA
//   fatia 2 (ACCESS/ASSIGN, DATA herdada de superclasse, resolve-at de ::membro) sao
//   CONSUMO da ferramenta -- o parentesco de superclasse ja' vive no dump (_HB_SUPER,
//   fase RE) --, nao lacuna da AST. O check COMPLETUDE(ppc-class=COMPLETE) le' a AST.
//
// Familia hbclass (docs/pp-corpus/class.md) - o dialeto OO INTEIRO e' diretiva de
// pp (hbclass.ch), sem UMA linha de gramatica no compilador.
//
// AS CAMADAS (METODO.md § 4): a camada A (o TEXTO) NAO cabe via pp vivo -- o
// dialeto sao dezenas de regras entrelacadas que so' fazem sentido com a classe
// inteira em contexto, nao uma diretiva isolada. O "o que VIRA" e' provado pelo
// .ppt na irma clsxdump.prg (o paste do nome, a regra que gera regra, o Self
// tipado). Aqui fica a camada B: o dialeto COMPILA e RODA, e o valor prova que
// VAR/METHOD/::send viraram funcao de verdade.
//
// hbclass.ch NAO e' auto-incluida (precisa #include + -I <core>/include).
//
// COMO COMPILAR/RODAR:
//   sintaxe:  harbour clsx.prg -n -q0 -w3 -es2 -s -I<core>/include -I<core>/contrib/hbtest
//   rodar:    hbmk2  clsx.prg  <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbclass.ch"
#include "hbtest.ch"

PROCEDURE Main()

   LOCAL oConta := Conta()     // CREATE CLASS gerou a funcao-fabrica Conta()

   // VAR nSaldo INIT 0: o objeto nasce com o DATA member em 0 -- o INIT rodou na
   // instanciacao. Se o INIT nao expandisse, nSaldo seria NIL, nao 0.
   HBTEST oConta:nSaldo IS 0
   // METHOD Deposita virou a funcao gerada (Conta_Deposita); a chamada dispara-a e
   // o `::nSaldo +=` soma no DATA member. E' o dispatch OO, tudo de pp.
   oConta:Deposita( 100 )
   HBTEST oConta:nSaldo IS 100
   // A soma ACUMULA no MESMO DATA member: o Self carrega o estado entre chamadas.
   oConta:Deposita( 50 )
   HBTEST oConta:nSaldo IS 150
   // RETURN Self: o metodo devolve o proprio objeto (o Self tipado do .ppt), o
   // idioma de encadeamento -- e e' por isso que o retorno == o objeto original.
   HBTEST ( oConta:Deposita( 0 ) == oConta ) IS .T.

   RETURN

CREATE CLASS Conta
   VAR nSaldo INIT 0
   METHOD Deposita( nValor )
ENDCLASS

METHOD Deposita( nValor ) CLASS Conta
   ::nSaldo += nValor
   RETURN Self
