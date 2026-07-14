// METODO-V2(2026-07-14): revisado pelo metodo novo -- comentario INTERPRETA o
// oraculo (nao o transcreve), e o que ele afirma esta' provado por assert ou
// pelo dump. Prova: os fatos que so' o DUMP tem: a OP da derivacao separa simbolo de dado.
// (regua: docs/pp-corpus/METODO.md § 4b)
// Fixture da familia STRDUMP (docs/pp-corpus/strdump.md). Compila limpo sob -w3 -es2.
// Aqui se leem os fatos que so' existem no DUMP -- a OP de cada derivacao.
// (A metade que RODA e se afirma e' o sdrun.prg.)
//
// As regras, em sd.ch:
//   #xcommand SELO <v> AFERIDO => <v> := sd_Afere( #<v> )
//   #xcommand LAVRA <*txt*>    => sd_Lavra( #<txt> )
//
// O dump tem DOIS lados, e a familia inteira vive na diferenca entre eles:
//   ppApplications[] = o que o pp CONSUMIU do seu fonte (com linha e coluna)
//   tokens[]         = o que ele EMITIU ao compilador (com a OP da derivacao)
//
// Aviso a quem for ler o dump deste arquivo: as proprias linhas de HBTEST aparecem
// com clone+stringify. Nao e' ruido nem coincidencia -- o `HBTEST <x> IS <r>` do core
// e' `hbtest_Call( #<x>, {|| <x> }, <r> )`: ele CITA a expressao (para o rotulo) e a
// COPIA (para avaliar). O framework de teste usa o mesmo `#<x>` que a fixture estuda.

#include "sd.ch"
#include "hbtest.ch"

STATIC s_cUltimo

PROCEDURE Main()

   LOCAL nLastro

   // Voce escreveu `nLastro` UMA vez; o compilador recebe DOIS tokens a partir dele.
   // O `<v>` copia (derivacao 'clone'): esse token e' lido como a variavel. O `#<v>`
   // cita (derivacao 'stringify'): esse vira uma string, dado.
   // O papel nao esta' no nome que voce escreveu -- esta' no MARKER que o consumiu.
   // Por isso um refatorador nao pode decidir nada por texto: o mesmo `nLastro`, na
   // mesma linha, e' codigo de um lado e conteudo do outro.
   SELO nLastro AFERIDO

   // O wild engoliu tres palavras. O pp CONSUMIU as tres, e guardou cada uma com a sua
   // coluna (fundo@9, de@15, reserva@18); mas EMITIU uma so' -- a string "fundo de
   // reserva".
   // A consequencia e' util e nao e' obvia: a ferramenta tem posicao byte-exata de cada
   // palavra que voce escreveu, mesmo que o artefato que chega ao compilador seja um
   // texto unico. O que ela NAO tem e' um simbolo -- nada disto e' nome de coisa nenhuma.
   LAVRA fundo de reserva
   HBTEST sd_Ultimo() IS "fundo de reserva"   // o que sd_Lavra recebeu: o span cru

   // A cilada. O texto do wild agora e' exatamente o nome do LOCAL declarado acima --
   // e nao muda nada: a derivacao continua sendo 'stringify', e so'. Nao ha' 'clone'.
   // O compilador nunca ve uma variavel nesta linha; ve uma string cujo conteudo, por
   // coincidencia, e' igual a um nome.
   // Repare no que NAO ajuda a decidir: o `generates` e' true nos dois sitios (o do SELO
   // e o desta linha), e o texto e' identico. Se a ferramenta olhasse so' isso, editaria
   // esta string ao renomear a variavel -- corrompendo DADO por coincidencia de nome.
   // Quem separa e' a OP: 'clone' = simbolo; so' 'stringify' = dado.
   LAVRA nLastro
   // O assert e' quem prova que esta linha e' DADO: sd_Lavra recebeu a STRING
   // "nLastro" -- e nao o VALOR da variavel, que neste ponto e' 7 (o assert abaixo
   // confirma). Se o pp tivesse tratado o texto como simbolo, chegaria 7 aqui.
   HBTEST sd_Ultimo() IS "nLastro"
   HBTEST nLastro     IS 7

   // Contraste que fecha a ideia: o `?` tambem e' #command (do std.ch) e tambem consome
   // o nome por um marker -- mas emite com 'clone'.
   // Ou seja: "passou por diretiva de pp" nao diz nada sobre a natureza do nome. Duas
   // diretivas consomem `nLastro` neste arquivo; uma o transforma em dado, a outra o
   // entrega intacto ao compilador.
   ? nLastro

   RETURN

STATIC FUNCTION sd_Afere( cNome )
   RETURN Len( cNome )

STATIC FUNCTION sd_Lavra( cTexto )
   s_cUltimo := cTexto
   RETURN NIL

// o que a ultima LAVRA entregou -- para os asserts poderem inspecionar
STATIC FUNCTION sd_Ultimo()
   RETURN s_cUltimo
