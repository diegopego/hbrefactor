// DSL de pp da fixture B4 - as três famílias + par de comandos de laço.
// UNTIL usa a forma IF/EXIT/END/END: a std.ch tem '#command ENDIF <*x*>'
// cujo wild marker engole um '; ENDDO' que venha depois na expansão
// (armadilha pré-existente do Harbour, ver docs/ast-schema.md)
#xcommand REPEAT => DO WHILE .T.
#xcommand UNTIL <cond> => IF <cond> ; EXIT ; END ; END
#command MENUITEM <label> ACTION <act> AT <row>, <col> => ;
         MenuAdd( <row>, <col>, <label>, {|| <act> } )
#command MENUBOX <title> => MenuAdd( 0, 0, <title>, NIL )
#xtranslate SQUARED( <n> ) => ( ( <n> ) * ( <n> ) )
#define LIMITE_TETO 40
