// modulo LOG: stringify + clone a um LOCAL externo (Preco). Custo existe
// como local irmao - renomear o marker para Custo re-aponta o clone (correto
// por semantica, verificado compilando); para nome inexistente, rollback.
#include "p2.ch"

PROCEDURE Main()
   LOCAL Preco := 5, Custo := 9
   ? Preco, Custo
   LOG Preco
   RETURN
