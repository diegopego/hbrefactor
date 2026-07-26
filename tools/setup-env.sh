#!/bin/sh
# ---------------------------------------------------------------------------
# Adiciona (IDEMPOTENTE) o export HBREFACTOR_HB_BIN ao shell rc do usuário.
#
# Bloco com sentinela: re-rodar SUBSTITUI o bloco, nunca duplica linhas. O
# valor NAO e' cravado - o bloco chama tools/hbenv.sh (a fonte única), entao
# segue sincronizado se o layout do core mudar. Guarda `[ -f ]`: se o repo for
# movido, a linha vira no-op (sem erro), e basta re-rodar `make setup-env`.
#
#   uso: setup-env.sh <rc-file> <caminho ABS de tools/hbenv.sh>
# ---------------------------------------------------------------------------
set -u
RC="${1:?uso: setup-env.sh <rc-file> <abs de tools/hbenv.sh>}"
HBENV="${2:?falta o caminho absoluto de tools/hbenv.sh}"

BEGIN="# >>> hbrefactor (HBREFACTOR_HB_BIN) >>>"
END="# <<< hbrefactor <<<"

touch "$RC"

# remove um bloco anterior entre as sentinelas, se houver (idempotência)
tmp=$( mktemp )
awk -v b="$BEGIN" -v e="$END" '
   $0 == b { skip = 1 }
   skip == 1 && $0 == e { skip = 0; next }
   skip != 1 { print }
' "$RC" > "$tmp"

{
   cat "$tmp"
   printf '%s\n' "$BEGIN"
   printf '[ -f "%s" ] && export HBREFACTOR_HB_BIN="$( sh "%s" --print HBREFACTOR_HB_BIN )"\n' "$HBENV" "$HBENV"
   printf '%s\n' "$END"
} > "$RC"
rm -f "$tmp"

printf 'hbrefactor: bloco atualizado em %s\n' "$RC"
printf '            abra um novo terminal, ou rode: . %s\n' "$RC"
