#!/bin/sh
# ---------------------------------------------------------------------------
# FONTE ÚNICA dos DOIS toolchains de que o hbrefactor depende.
#
# Antes, cada script e o Makefile tinham o caminho cravado como default próprio -
# mudar de layout obrigava a editar N arquivos. Aqui a detecção mora num lugar
# só; todos derivam.
#
# SÃO DOIS, e QUAL SE USA QUANDO não é preferência - é o que dá sentido a cada um:
#
#   BRANCH (HB_CORE / HB_BIN)   feature/compiler-ast-dump: o compilador que SABE
#                               responder (-x, -kt). É com ele que a ferramenta
#                               compila, analisa e verifica - TODO o trabalho.
#                               Reconhece-se por carregar `ast-N` no binário.
#
#   STOCK  (HB_STOCK / ..._BIN) upstream/master, sem remendo nenhum. NÃO se usa
#                               para trabalhar: existe para ser COMPARADO. É a
#                               base da única prova que a proposta aos
#                               mantenedores faz - com os switches desligados, o
#                               remendado gera pcode idêntico ao de fábrica.
#                               Reconhece-se por NÃO carregar `ast-N`.
#
# Confundir os dois não dá erro, dá VERDE FALSO: medir o remendado contra ele
# mesmo prova nada e passa. Por isso os papéis são conferidos em código -
# `make core-check` (tem de ter o dump) e `make stock-check` (não pode ter).
#
# DOIS modos de uso:
#   . tools/hbenv.sh             -> define as variáveis no shell
#   sh tools/hbenv.sh --print HB_BIN  -> ecoa uma variável (para o Makefile
#                                        via $(shell ...))
#
# REGRA: um valor já presente no ambiente VENCE (override sempre respeitado);
# senão, escolhe o PRIMEIRO layout conhecido que de fato tem o binário `harbour`;
# se nenhum existe, cai no preferido (o novo) - o erro aponta o caminho pretendido.
# ---------------------------------------------------------------------------

if [ -z "${HB_CORE:-}" ]; then
   for _d in \
      "$HOME/devel/harbour-hbrefactor/harbour-core" \
      "$HOME/devel/harbour-core/harbour"; do
      if [ -x "$_d/bin/linux/gcc/harbour" ]; then HB_CORE="$_d"; break; fi
   done
   [ -z "${HB_CORE:-}" ] && HB_CORE="$HOME/devel/harbour-hbrefactor/harbour-core"
fi

# derivados de HB_CORE (a detecção), cada um respeitando um valor já exportado.
# NAMESPACE: HBREFACTOR_HB_BIN vem do FORK DETECTADO, nunca de um HB_BIN
# herdado - por isso um HB_BIN global de OUTRO harbour no computador NAO
# contamina o hbrefactor. Só um HBREFACTOR_HB_BIN explícito (make/extensao/
# usuario) o sobrescreve. O HB_BIN (make var / build) e' separado.
HB_BIN="${HB_BIN:-$HB_CORE/bin/linux/gcc}"           # Makefile (HBMK2) + fallback da ferramenta
HBREFACTOR_HB_BIN="${HBREFACTOR_HB_BIN:-$HB_CORE/bin/linux/gcc}"   # o que a ferramenta le PRIMEIRO
HB="${HB:-$HB_CORE}"                          # tests/lexdiff.sh
ROOT="${ROOT:-$HB_CORE}"                      # tools/pcode-identity.sh
CORE="${CORE:-$HB_CORE}"                      # tools/publish-core-site.sh

# O STOCK - worktree de upstream/master, irmão do core. Provisionado por
# `make stock`; NUNCA usado para trabalhar (ver o cabeçalho).
HB_STOCK="${HB_STOCK:-$(dirname "$HB_CORE")/harbour-stock}"
HB_STOCK_BIN="${HB_STOCK_BIN:-$HB_STOCK/bin/linux/gcc}"

# guarda barata contra o pior erro possível: apontar o stock para o próprio
# branch faria a prova de pcode comparar o binário com ele mesmo - verde, e sem
# valor nenhum. Aqui só o CAMINHO; que cada binário é mesmo o que diz ser, quem
# confere é `make core-check` / `make stock-check` (pelo dump dentro dele).
if [ "$HB_STOCK" = "$HB_CORE" ]; then
   echo "hbenv: HB_STOCK e HB_CORE apontam para o MESMO lugar ($HB_CORE);" >&2
   echo "       o stock existe para ser comparado com o branch, nao para ser ele." >&2
   return 1 2>/dev/null || exit 1
fi

# modo --print: ecoa a variável pedida (só quando invocado explicitamente;
# sourceado, o $1 seria o argumento do script-pai, então exige o literal --print)
if [ "${1:-}" = "--print" ]; then
   eval "printf '%s\n' \"\${$2}\""
fi
