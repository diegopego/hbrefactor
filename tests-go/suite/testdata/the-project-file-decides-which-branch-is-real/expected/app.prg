PROCEDURE Main()

   OutStd( hb_ntos( Calcula( 2 ) ) )

   RETURN

#ifdef MODO_NOVO

FUNCTION Calcula( nX )

   RETURN nX * 10

#else

FUNCTION Calcula( nX )

   RETURN nX * 2

#endif
