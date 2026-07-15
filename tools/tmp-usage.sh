#!/usr/bin/env bash
# tmp-usage.sh - AVISA quando os temporários da ferramenta passam de um limite.
#
# NUNCA apaga nada: mede, reporta e imprime o comando de limpeza para você
# colar. Determinístico e sob seu controle - a decisão de limpar é sempre sua.
# Gatilho: manual (make tmp-usage). Sem hook, sem ação automática.
#
# Limite default 500 M por alvo; override por env HBREFACTOR_TMP_WARN_MB.
# Exit code: 0 se tudo abaixo do limite, 1 se algum alvo passou (composável).
set -euo pipefail

WARN_MB="${HBREFACTOR_TMP_WARN_MB:-500}"
TMPROOT="${TMPDIR:-/tmp}"
HBDIR="$TMPROOT/hbrefactor"

# tamanho em MB de um caminho (0 se não existe)
size_mb() {
   [ -e "$1" ] || { echo 0; return; }
   du -sm "$1" 2>/dev/null | cut -f1
}

hb_mb=$( size_mb "$HBDIR" )
work_mb=$( size_mb "$HBDIR/work" )
snap_mb=$( size_mb "$HBDIR/snap" )

# scratchpad(s) do Claude Code deste projeto: é comportamento do HARNESS, não da
# ferramenta - reportado em SEPARADO, só como medida (foi o que mais encheu).
scratch_mb=0
scratch_paths=()
for d in /tmp/claude-*/*hbrefactor*/; do
   [ -d "$d" ] || continue          # glob sem match vira literal → descarta
   scratch_paths+=( "$d" )
   scratch_mb=$(( scratch_mb + $( size_mb "$d" ) ))
done

echo "temporários do hbrefactor:  ${hb_mb} M   (work ${work_mb} M · snap ${snap_mb} M)   → $HBDIR"
if [ "${#scratch_paths[@]}" -gt 0 ]; then
   echo "scratchpad do Claude Code:  ${scratch_mb} M   (${#scratch_paths[@]} sessão(ões) — fora da ferramenta)"
fi
echo "limite de aviso:            ${WARN_MB} M por alvo   (override: HBREFACTOR_TMP_WARN_MB)"
echo

over=0

if [ "$hb_mb" -ge "$WARN_MB" ]; then
   over=1
   echo "ACIMA DO LIMITE — temporários da ferramenta (${hb_mb} M). Rode você mesmo:"
   echo
   echo "  # lixo puro, sempre seguro:"
   echo "  rm -rf \"$HBDIR/work\""
   echo
   echo "  # tudo da ferramenta — inclui snap/, o buffer de \`verify --rollback\`;"
   echo "  # só se NÃO houver refatoração pendente de verificar:"
   echo "  rm -rf \"$HBDIR\""
   echo
fi

if [ "$scratch_mb" -ge "$WARN_MB" ]; then
   over=1
   echo "ACIMA DO LIMITE — scratchpad do Claude Code (${scratch_mb} M; sessões antigas, regenerável):"
   echo
   for d in "${scratch_paths[@]}"; do
      echo "  rm -rf \"${d%/}\""
   done
   echo
fi

if [ "$over" -eq 0 ]; then
   echo "OK — tudo abaixo do limite."
   exit 0
fi

exit 1
