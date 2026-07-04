#include "shared.ch"

FUNCTION Dupla( nV )

   LOCAL nR := nV + nV

   RETURN nR

FUNCTION UsaMeio( nV )

   RETURN Meio( nV ) + Meio( nV )

STATIC FUNCTION Meio( nN )

   RETURN nN * 0.5

FUNCTION Sub2( nA, nB )

   RETURN nA - nB
