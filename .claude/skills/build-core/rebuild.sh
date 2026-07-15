#!/usr/bin/env bash
# rebuild.sh — rebuild do harbour-core sem cair nas 3 armadilhas do CLAUDE.md §2.
#
#   (a) mudança no compilador exige rebuildar harbour E hbmk2 (o hbmk2 EMBUTE o
#       compilador — linka libhbcplr; um hbmk2 velho emite dump de schema antigo
#       mesmo com harbour novo).
#   (b) o `make` MENTE "up to date" e não relinca → apagar os binários antes.
#   (c) HB_REBUILD_PARSER=yes regenera o obj/<plat>/harboury.c a partir do .y,
#       mas NÃO os harbour.yyc/.yyh COMMITADOS — este script copia à mão e
#       reconstrói SEM a flag para provar que um rebuild default carrega a feature.
#
# NÃO commita nada: commit no core é autorização por-commit do Diego (§6).
#
# Uso:  rebuild.sh [--grammar] [CORE_DIR]
#   --grammar   você mexeu na GRAMÁTICA (src/compiler/harbour.y) → regenera o
#               parser e sincroniza os .yyc/.yyh commitados. Omita para mudança
#               só no C do compilador/pp.
#   CORE_DIR    raiz do harbour-core (default: derivado de HB_BIN, senão
#               $HOME/devel/harbour-core/harbour).

set -uo pipefail

GRAMMAR=0
CORE=""
for a in "$@"; do
   case "$a" in
      --grammar) GRAMMAR=1 ;;
      *) CORE="$a" ;;
   esac
done

# CORE: argumento > derivado de HB_BIN (bin/linux/gcc → sobe 3) > default do Makefile
if [ -z "$CORE" ]; then
   if [ -n "${HB_BIN:-}" ]; then
      CORE=$(cd "$HB_BIN/../../.." 2>/dev/null && pwd)
   fi
   CORE="${CORE:-$HOME/devel/harbour-core/harbour}"
fi

BINDIR="$CORE/bin/linux/gcc"
[ -d "$CORE/src/compiler" ] || { echo "rebuild: '$CORE' não parece o harbour-core (sem src/compiler)"; exit 1; }

BR=$(git -C "$CORE" branch --show-current 2>/dev/null || echo "?")
echo "== rebuild do core =="
echo "   CORE   : $CORE"
echo "   branch : $BR  (esperado: feature/compiler-ast-dump)"
echo "   modo   : $([ $GRAMMAR -eq 1 ] && echo 'GRAMÁTICA (regenera parser)' || echo 'compilador/pp (C)')"
echo

# --- armadilha (b): o make não relinca; apagar os DOIS binários ---------------
echo "-- (b) apagando binários para forçar relink (harbour E hbmk2)"
rm -f "$BINDIR/harbour" "$BINDIR/hbmk2"

# --- build --------------------------------------------------------------------
build() { # build [HB_REBUILD_PARSER=...]
   local rp="${1:-}"
   echo "-- make ${rp:+($rp)}"
   ( cd "$CORE" && env ${rp:+$rp} make ) || return 1
}

if [ $GRAMMAR -eq 1 ]; then
   # --- armadilha (c): regenera o parser a partir do .y ----------------------
   build "HB_REBUILD_PARSER=yes" || { echo "rebuild: make (HB_REBUILD_PARSER=yes) FALHOU"; exit 1; }

   YC=$(find "$CORE/obj" -name 'harboury.c' 2>/dev/null | head -1)
   YH=$(find "$CORE/obj" -name 'harboury.h' 2>/dev/null | head -1)
   [ -f "$YC" ] && [ -f "$YH" ] || { echo "rebuild: não achei o parser regenerado (obj/**/harboury.{c,h})"; exit 1; }

   echo "-- (c) sincronizando os .yyc/.yyh commitados a partir do parser regenerado"
   echo "       $YC -> src/compiler/harbour.yyc"
   echo "       $YH -> src/compiler/harbour.yyh"
   cp "$YC" "$CORE/src/compiler/harbour.yyc"
   cp "$YH" "$CORE/src/compiler/harbour.yyh"

   # rebuild SEM a flag: prova que os .yyc/.yyh commitados carregam a feature
   echo "-- (c) rebuild DEFAULT (sem HB_REBUILD_PARSER) para provar o parser commitado"
   rm -f "$BINDIR/harbour" "$BINDIR/hbmk2"
   build || { echo "rebuild: make default (pós-sync) FALHOU"; exit 1; }
else
   build || { echo "rebuild: make FALHOU"; exit 1; }
fi

# --- verificação --------------------------------------------------------------
echo
echo "-- verificação"
FAIL=0
for b in harbour hbmk2; do
   if [ -x "$BINDIR/$b" ]; then echo "   ok  $b presente"; else echo "   FALTA  $b"; FAIL=1; fi
done
# a feature do branch (dump ast) tem de estar EMBUTIDA no binário
if strings "$BINDIR/harbour" 2>/dev/null | grep -q 'ast-'; then
   echo "   ok  harbour carrega o schema do dump (strings | grep ast-)"
else
   echo "   ALERTA  não encontrei marca 'ast-' no harbour — feature pode não ter entrado"
   FAIL=1
fi

echo
if [ $GRAMMAR -eq 1 ]; then
   echo "LEMBRETE (§2): commitar os TRÊS juntos — src/compiler/harbour.y + .yyc + .yyh —"
   echo "               conferindo antes 'git -C $CORE status'. Commit sob autorização"
   echo "               por-commit do Diego (§6). Depois: NEWS.md + site (pipeline do core)."
else
   echo "LEMBRETE (§6): commit no core é autorização por-commit do Diego; depois NEWS.md + site."
fi

exit $FAIL
