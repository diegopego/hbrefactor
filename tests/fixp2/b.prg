// modulo WRAP+SNAP: WRAP cola w_<n> E chama a FUNCAO externa <n>(); SNAP
// cola 2x + stringifica 2x (funcoes geradas nao-usadas - a re-derivacao do
// marker fecha por conta propria, sem chamador nao-derivado)
#include "p2.ch"

WRAP Soma

SNAP Conta

FUNCTION Soma()
   RETURN 42
