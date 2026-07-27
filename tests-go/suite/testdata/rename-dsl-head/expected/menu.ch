// DSL de pp da fixture B4 - as três famílias + par de comandos de laço.
// CMD_UNTIL usa a forma IF/EXIT/END/END: a std.ch tem '#command ENDIF <*x*>'
// cujo wild marker engole um '; ENDDO' que venha depois na expansão
// (armadilha pré-existente do Harbour, ver docs/ast-schema.md)
#xcommand CMD_REPEAT => DO WHILE .T.
#xcommand CMD_UNTIL <cond> => IF <cond> ; EXIT ; END ; END
#command MENU_ITEM <label> ACTION <act> AT <row>, <col> => ;
         MenuAdd( <row>, <col>, <label>, {|| <act> } )
#command MENUBOX <title> => MenuAdd( 0, 0, <title>, NIL )
#xtranslate SQUARED( <n> ) => ( ( <n> ) * ( <n> ) )
#define LIMITE_TETO 40
