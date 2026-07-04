#include "shared.ch"

STATIC s_nContador := 0

FUNCTION Dupla( nV )

   LOCAL nR := nV + nV

   RETURN nR

FUNCTION UsaMeio( nV )

   RETURN Meio( nV ) + Meio( nV )

STATIC FUNCTION Meio( nN )

   RETURN nN * 0.5

FUNCTION Sub2( nA, nB )

   RETURN nA - nB

FUNCTION ProximoId()

   s_nContador++

   RETURN s_nContador

FUNCTION ComPrivada()

   PRIVATE xCfg := 7

   RETURN xCfg
