// Fixture da familia TEXT/ENDTEXT (docs/pp-corpus/text-stream.md). Compila
// limpo sob -w3 -es2. Diretiva REAL do core: std.ch:221 (`#command TEXT =>
// text QOut, QQOut`), que liga o modo de stream do pp (HB_PP_STREAM_CLIPPER).
//
// O assunto e' a COLISAO entre DADO e SIMBOLO: a segunda linha do bloco contem
// a palavra `cSaldo`, que TAMBEM e' um local de verdade aqui. Dentro do TEXT ela
// e' texto -- vira parte de uma string. Renomear o local NAO pode toca-la (seria
// editar dado por coincidencia de nome), mas a ferramenta PRECISA poder RELATAR
// que a palavra tambem aparece ali: e' o `ast-17` que torna isso possivel (antes
// dele a linha do bloco chegava ao compilador SEM POSICAO NENHUMA).

PROCEDURE Main()

   LOCAL cSaldo := "1.234,00"

   TEXT
   Relatorio mensal
   cSaldo apurado no periodo
   ENDTEXT

   ? cSaldo

   RETURN
