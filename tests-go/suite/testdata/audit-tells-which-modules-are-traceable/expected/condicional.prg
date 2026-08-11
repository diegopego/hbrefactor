// o codigo que ESTE build nao compilou: nao e' dinamico, e' outra configuracao.
// A ferramenta cobre o que o arquivo de projeto manda compilar
FUNCTION Formata( cX )

#ifdef MODO_LEGADO
   RETURN "[" + cX + "]"
#else
   RETURN cX
#endif
