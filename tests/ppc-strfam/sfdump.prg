// METODO-V2(2026-07-14): revisado pelo metodo novo -- comentario INTERPRETA o
// oraculo (nao o transcreve), e o que ele afirma esta' provado por assert ou
// pelo dump. Prova: o simbolo que sai do macro chega SEM posicao (lacuna P18).
// (regua: docs/pp-corpus/METODO.md § 4b)
/*
 * ppc-strfam / sfdump.prg - a IRMA de sf.prg, para o que NAO se ve em runtime.
 *
 * O sf.prg prova, com asserts (hbtest + o pp vivo), o que a diretiva VIRA e o que
 * ela VALE. Mas ha' fatos que so' existem no DUMP e nao tem valor em runtime:
 * posicao de token, mkind, e a OP da derivacao ('c'lone x 's'tringify). Estes se
 * conferem no ast dump -- e para isso o arquivo precisa ser dumpavel pelo `harbour`
 * cru (o sf.prg nao e': ele usa #require, que so' o hbmk2 resolve).
 *
 * O QUE ESTE ARQUIVO ANCORA (guarda corpus_strfam):
 *   - o simbolo que o pp tira de DENTRO do macro chega ao compilador como CLONE
 *     (e' simbolo de verdade, nao dado);
 *   - ...mas chega SEM POSICAO -- e' a LACUNA P18: o recheio `&cAlvo` TEM linha e
 *     coluna; o simbolo emitido nao tem. Sem esse fato o rename nao pode editar
 *     dentro do macro, e recusa em falso.
 *
 * Quando o P18 for resolvido, a guarda que assere a lacuna QUEBRA -- e e' assim
 * que ela avisa que o corpus precisa ser atualizado.
 */

#xtranslate SF_NOR( <z> ) => sf_( <"z"> )

MEMVAR cAlvo

PROCEDURE Main()

   PRIVATE cAlvo := "oi"

   sf_( SF_NOR( &cAlvo ) )      // o pp desfaz o `&` -> o simbolo cAlvo, como codigo

   RETURN

STATIC FUNCTION sf_( x )
   RETURN x
