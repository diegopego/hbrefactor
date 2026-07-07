// DSL 2 da B4f-3: declarativa PURA - só o canal da linguagem, SEM função
// geradora (gizmo-style, vocabulário próprio). A dona existe apenas nas
// tabelas declared; a prova cobre homônimos entre donos assim declaradas.

#xcommand AMULETO <cls> FEITO_POR <fn> => _HB_CLASS <cls> <fn>

#xcommand DOTE <msg> RENDE <cls> => _HB_MEMBER <msg>() AS CLASS <cls>
