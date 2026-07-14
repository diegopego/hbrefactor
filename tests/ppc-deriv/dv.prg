// METODO-V2(2026-07-14): revisado pelo metodo novo -- comentario INTERPRETA o
// oraculo, e cada afirmacao esta' provada por assert que PASSA PELA DIRETIVA.
// (regua: docs/pp-corpus/METODO.md § 4b)
//
// Fixture da familia DERIVACAO (docs/pp-corpus/derivation.md) -- ate' 2026-07-14 era
// markdown SEM TESTE nenhum, e e' a espinha de metade do corpus.
//
// COMO COMPILAR:
//   sintaxe:  harbour dv.prg -n -q0 -w3 -es2 -s -I$HB_CORE/contrib/hbtest
//   rodar:    hbmk2  dv.prg $HB_CORE/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi
//
// O ASSUNTO: o que uma diretiva FAZ com o nome que voce escreveu. Sao TRES coisas, e
// o dump as nomeia (`from[].op`):
//
//   clone     -- copia o token: ele CHEGA ao compilador como voce escreveu
//   paste     -- cola o nome dentro de OUTRO identificador: nasce um simbolo novo
//   stringify -- cita o nome: vira string (dado)
//
// Duas camadas, as duas assertadas: (A) o TEXTO que a diretiva vira, pelo pp vivo;
// (B) o VALOR que ela vale, executando.

#include "hbtest.ch"

REQUEST __pp_StdRules

#xcommand ECOA <x>  => s_xEco := dv_Eco( <x> )
#xcommand FORJA <n> => FUNCTION fj_<n>() ;; RETURN <"n">

STATIC s_xEco

PROCEDURE Main()

   LOCAL pp
   LOCAL cAlvo := "oi"

   /* ---------- (A) o TEXTO que cada op produz ---------- */

   // estado VIRGEM (cStdCh = ""): so' as regras que eu registrar -- a linguagem fica
   // de fora, e o que sair da expansao e' obra EXCLUSIVA da diretiva sob teste.
   // O __pp_AddRule e' obrigatorio: o pp de runtime NAO conhece as diretivas deste
   // arquivo (o pp do compilador morreu com a compilacao) -- ver docs/pp-corpus/pp-api.md
   pp := __pp_Init( , "" )
   __pp_AddRule( pp, "#xcommand ECOA <x> => s_xEco := dv_Eco( <x> )" )
   __pp_AddRule( pp, '#xcommand FORJA <n> => FUNCTION fj_<n>() ;; RETURN <"n">' )

   // CLONE: o nome sai IGUAL ao que entrou -- o pp so' o copiou para dentro do result
   HBTEST __pp_Process( pp, "ECOA cAlvo" ) IS "s_xEco := dv_Eco( cAlvo )"

   // PASTE + STRINGIFY na MESMA regra: o nome escrito uma vez vira o sufixo de um
   // identificador NOVO (`fj_Alfa`) e o conteudo de uma string ("Alfa")
   HBTEST __pp_Process( pp, "FORJA Alfa" ) ;
      IS 'FUNCTION fj_Alfa() ;; RETURN "Alfa"'

   /* ---------- (B) o VALOR -- e o que ele PROVA ---------- */

   // O `ECOA` guarda o resultado em s_xEco. Se o marker tivesse CITADO o nome (como o
   // `#<x>` faz), aqui chegaria a string "cAlvo". Chega "oi": o token foi COPIADO, e o
   // compilador o leu como a variavel local. Passar por diretiva nao muda a natureza
   // do nome -- muda o marker que o consome.
   ECOA cAlvo
   HBTEST s_xEco IS "oi"

   // A funcao `fj_Alfa` NAO EXISTE neste fonte: quem a criou foi o `paste` da linha
   // `FORJA Alfa`, la' embaixo. Chamar-la e' a prova de que o simbolo nasceu -- e o
   // que ela devolve ("Alfa") e' a prova de que o `stringify` citou o MESMO nome.
   // Um assert, duas ops.
   HBTEST fj_Alfa() IS "Alfa"

   // No dump, esses dois artefatos chegam SEM POSICAO (line 0, col null): eles nao
   // estao no seu arquivo. Quem tem linha e coluna e' o nome que voce ESCREVEU -- e o
   // campo `from` liga um ao outro com OFFSET:
   //     fj_Alfa  op=paste      at=3 len=4   (os 4 bytes a partir do 3o sao o nome)
   //     "Alfa"   op=stringify  at=0 len=4   (a string inteira e' o nome)
   // E' esse offset que permite renomear sem adivinhar: a ferramenta edita o NOME
   // ESCRITO e deixa o pp re-derivar os artefatos. Ela nunca edita `fj_Alfa`.
   // (a guarda corpus_deriv confere isso no dump)

   RETURN

FORJA Alfa

STATIC FUNCTION dv_Eco( x )
   RETURN x
