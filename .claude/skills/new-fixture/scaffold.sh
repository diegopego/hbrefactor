#!/usr/bin/env bash
# scaffold.sh — anda o esqueleto de uma fixture-PROJETO da suíte e prova que ela
# compila limpo, ANTES de qualquer fio no runner.
#
# Toda fixture é um PROJETO (>= 2 .prg + .hbp; .ch opcional): a ferramenta tem de
# provar que opera em nível de projeto, nunca sobre arquivo solto (tests/run.sh).
# Fixture que não compila gera diagnóstico enganoso (CLAUDE.md §3), então este
# script COMPILA cada módulo com o mesmo contrato do "case 0" (-w3 -es2 -s).
#
# NÃO mexe no run.sh — o fio (fresh<nome>/unit_N/ALL_UNITS) é delicado e o SKILL.md
# guia o Claude a fazê-lo à mão, revisado. Aqui só o que é mecânico e seguro.
#
# Uso:  scaffold.sh <nome> [--ch]
#   <nome>   sufixo da fixture (cria tests/fix<nome>/); [a-z0-9]+
#   --ch     inclui um header de DSL (fix<nome>.ch) em #xcommand (§7: código NOVO
#            nosso usa #xcommand/#xtranslate — nunca #command, salvo fixture cujo
#            ASSUNTO seja a abreviação dBase)

set -uo pipefail

NAME=""
WITH_CH=0
for a in "$@"; do
   case "$a" in
      --ch) WITH_CH=1 ;;
      -*)   echo "scaffold: flag desconhecida '$a'"; exit 2 ;;
      *)    NAME="$a" ;;
   esac
done

case "$NAME" in
   ''|*[!a-z0-9]*) echo "scaffold: <nome> obrigatório, só [a-z0-9] (ex.: scaffold.sh cst)"; exit 2 ;;
esac

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "scaffold: fora de um clone git"; exit 1; }
DIR="$ROOT/tests/fix$NAME"
[ -e "$DIR" ] && { echo "scaffold: '$DIR' já existe — escolha outro nome ou remova à mão"; exit 1; }

mkdir -p "$DIR"

# --- módulo A: alvo de rename + chamada entre módulos -------------------------
cat > "$DIR/a.prg" <<'PRG'
// módulo A da fixture __NAME__ — dois módulos provam operação em nível de projeto
__CHINCLUDE__
FUNCTION Main()

   LOCAL nSoma

   nSoma := Calcula( 3, 4 )
   ? nSoma
   Ajuda( "pronto" )

   RETURN NIL

FUNCTION Calcula( nA, nB )

   RETURN nA + nB
PRG

# --- módulo B: função consumida pelo A (usages/rename entre módulos) ----------
cat > "$DIR/b.prg" <<'PRG'
// módulo B da fixture __NAME__
FUNCTION Ajuda( cTexto )

   ? cTexto

   RETURN NIL
PRG

# --- .hbp: o projeto declara os flags do contrato (como as fixtures existentes)
cat > "$DIR/fix$NAME.hbp" <<PRG
-i.
-w3
-es2
a.prg
b.prg
PRG

# --- .ch opcional: DSL em #xcommand (§7) -------------------------------------
if [ $WITH_CH -eq 1 ]; then
   cat > "$DIR/fix$NAME.ch" <<'PRG'
// DSL da fixture __NAME__ — código NOVO nosso usa #xcommand (§7: comparação EXATA,
// nunca a abreviação dBase). Troque para #command SÓ se o ASSUNTO da fixture for
// justamente a abreviação (senão o teste passaria por vacuidade).
#xcommand REGISTRA <id> AS <val> => Calcula( <id>, <val> )
PRG
fi

# aplica o nome e o include só-se-tem-ch nos templates
sed -i "s/__NAME__/$NAME/g" "$DIR"/*.prg "$DIR"/*.ch 2>/dev/null
if [ $WITH_CH -eq 1 ]; then
   sed -i "s/__CHINCLUDE__/#include \"fix$NAME.ch\"\n/" "$DIR/a.prg"
else
   sed -i "/__CHINCLUDE__/d" "$DIR/a.prg"
fi

# --- PORTA DE COMPILAÇÃO: cada módulo tem de compilar limpo (o gate do case 0) -
HB_BIN="${HB_BIN:-$HOME/devel/harbour-core/harbour/bin/linux/gcc}"
HARBOUR="$HB_BIN/harbour"
echo "== fixture criada: tests/fix$NAME/ =="
ls -1 "$DIR"
echo
if [ -x "$HARBOUR" ]; then
   echo "-- porta de compilação (-w3 -es2 -s, como o case 0):"
   FAIL=0
   for f in "$DIR"/*.prg; do
      if "$HARBOUR" "$f" -n -q0 -w3 -es2 -s -I"$DIR" >/tmp/_scaf.$$ 2>&1; then
         echo "   ok  $(basename "$f")"
      else
         echo "   FALHA  $(basename "$f"):"; sed 's/^/        /' /tmp/_scaf.$$; FAIL=1
      fi
   done
   rm -f /tmp/_scaf.$$
   [ $FAIL -eq 0 ] || { echo "scaffold: conserte a fixture antes de fiá-la no runner"; exit 1; }
else
   echo "-- (harbour de HB_BIN ausente: pulei a porta de compilação; rode 'make' no core)"
fi

# --- FIO NO RUNNER: os três pontos que o Claude costura à mão (SKILL.md) -------
NEXT=$(awk -F'"' '/^ALL_UNITS=/{n=split($2,a," "); print a[n]+1}' "$ROOT/tests/run.sh" 2>/dev/null)
cat <<EOF

== fio no runner (tests/run.sh) — costurar À MÃO, revisado (SKILL.md) ==

(1) helper 'fresh', junto dos outros fresh*():

   fresh$NAME() { # fresh$NAME <case-name> -> fixture fix$NAME
      local d="\$HERE/tmp/\$1"
      rm -rf "\$d"; mkdir -p "\$d"
      cp "\$HERE"/fix$NAME/*.prg "\$HERE"/fix$NAME/*.hbp $([ $WITH_CH -eq 1 ] && echo '"$HERE"/fix'"$NAME"'/*.ch ')"\$d"/
      echo "\$d"
   }

(2) corpo do caso (próximo número livre sugerido: ${NEXT:-<confira ALL_UNITS>}):

   unit_${NEXT:-N}() {
   echo "case ${NEXT:-N}: <o que este caso prova>"
   D=\$(fresh$NAME case${NEXT:-N})
   ( cd "\$D" && "\$BIN" <verbo> fix$NAME.hbp a.prg:<lin>:<col> <arg> > out.log 2>&1 )
   RC=\$?
   check "exit 0"  \$([ \$RC -eq 0 ] && echo 0 || echo 1)
   # ... asserts sobre o fonte editado / recusa byte-a-byte / out.log ...
   }

(3) registrar o número em ALL_UNITS (fim do run.sh): acrescente ${NEXT:-N}.
EOF
