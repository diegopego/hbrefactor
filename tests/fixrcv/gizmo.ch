// DSL INVENTADO da B4f (caso 64): comandos próprios que declaram pelo
// CANAL DE TIPOS DA LINGUAGEM - nada disto existe em include algum do core
// e a ferramenta não menciona nenhuma destas palavras. É o contrato de
// extensão do ast-schema.md em ação: um comando novo fica semanticamente
// refatorável DECLARANDO na expansão (_HB_CLASS / _HB_MEMBER / AS CLASS),
// exatamente como o hbclass.ch (que é só o primeiro cliente do canal).
// Sem alterar harbour nem hbrefactor.

// declara a classe <cls> e que a função <fn> devolve instância dela
#xcommand CONTRAPTION <cls> MAKER <fn> => _HB_CLASS <cls> <fn>

// declara que a mensagem <msg> da classe corrente devolve <cls>
#xcommand APTITUDE <msg> GIVING <cls> => _HB_MEMBER <msg>() AS CLASS <cls>

// variável tipada no vocabulário do DSL
#xcommand GIZMO <var> OF <cls> => LOCAL <var> AS CLASS <cls>
