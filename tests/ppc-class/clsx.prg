// P-DOC corpus - familia hbclass (CLASS/VAR/METHOD): o dialeto OO INTEIRO e
// diretiva de pp. hbclass.ch NAO e auto-incluida (precisa #include + -I).
// Aqui num so lugar: o paste do nome da funcao gerada (Conta_Deposita), a
// diretiva que GERA outra diretiva (o #xcommand METHOD ... CLASS Conta), o
// registro via oClass:AddMethod, e o `Self AS CLASS Conta := QSelf()`.
#include "hbclass.ch"

CREATE CLASS Conta
   VAR nSaldo INIT 0
   METHOD Deposita( nValor )
ENDCLASS

METHOD Deposita( nValor ) CLASS Conta
   ::nSaldo += nValor
   RETURN Self
