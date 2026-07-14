#!/bin/bash
# tools/pp-uses.sh - o CENSO dos sitios de uso do pp no corpus (docs/pp-corpus/uses-core.md).
#
# INSTRUMENTO, nao verbo da CLI: nao entra no `hbrefactor`. Ele roda o compilador
# do core sobre cada .prg do corpus (work/ = copias de pastas do CORE), le o dump
# (`harbour -x`) e conta o FATO -- ppRules[] (as diretivas que aquela compilacao
# registrou) e ppApplications[] (cada sitio onde uma regra foi APLICADA).
#
# Por que nao grep: grep conta a string, e conta comentario, string literal, ramo
# de #ifdef DESLIGADO, e erra a abreviacao dBase escrita pela metade. O dump conta
# o que o pp DISSE que aplicou. E' a REGRA DO FATO aplicada a pesquisa.
#
# Todo numero de docs/pp-corpus/uses-core.md sai DAQUI. Re-rode antes de escrever
# numero novo -- e reporte os modulos que NAO dumparam (o rodape honesto).
#
#   uso:  HB_BIN=<bin do branch> tools/pp-uses.sh [<dir do corpus, default work/>]
set -u
HB_BIN="${HB_BIN:?HB_BIN must point to the harbour binaries dir}"
CORE="$(dirname "$(dirname "$HB_BIN")")"; CORE="${HB_BIN%/bin/*}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORPUS="${1:-$ROOT/work}"
OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT

OK=0; FAIL=0
for f in $(find "$CORPUS" -name '*.prg' | sort); do
   d="$OUT/$(echo "${f#"$CORPUS"/}" | tr '/' '_')"; mkdir -p "$d"
   ( cd "$(dirname "$f")" && "$HB_BIN/harbour" "$(basename "$f")" -n -q0 \
        -I"$CORE/include" -I"$(dirname "$f")" -I"$CORE/contrib/xhb" \
        -x"$d/x.ast.json" > /dev/null 2>&1 )
   if [ -s "$d/x.ast.json" ]; then OK=$((OK+1)); else FAIL=$((FAIL+1)); rm -rf "$d"; fi
done

python3 - "$OUT" "$OK" "$FAIL" <<'PYEOF'
import json, glob, os, sys, collections

out, ok, fail = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
tot = 0
byhdr = collections.Counter(); fam = collections.Counter(); heads = collections.Counter()
inprg = collections.Counter(); apps_per = []; genmods = 0; totgen = 0
declprg = collections.Counter()

def is_generated(r):            # ast-13: a genealogia vive nos TOKENS do match/result
    return any(t.get("from") for side in ("match", "result") for t in (r.get(side) or []))

for f in glob.glob(os.path.join(out, "*", "x.ast.json")):
    try:
        d = json.load(open(f))
    except Exception:
        continue
    rules = d.get("ppRules") or []
    apps = d.get("ppApplications") or []
    apps_per.append(len(apps))
    g = [r for r in rules if is_generated(r)]
    if g:
        genmods += 1; totgen += len(g)
    for a in apps:
        r = rules[a["rule"]] if a["rule"] < len(rules) else {}
        tot += 1
        src = r.get("file") or "builtin"
        base = src.split("/")[-1]
        byhdr[base] += 1
        fam[r.get("kind")] += 1
        heads[r.get("head")] += 1
        if src.endswith(".prg"):
            inprg[base] += 1
            if r.get("kind") not in ("define", "undef"):
                declprg[(base, r.get("head"), r.get("kind"), r.get("line"))] += 1

apps_per.sort()
n = len(apps_per)
oo = byhdr["hbclass.ch"] + byhdr["hboo.ch"]
print(f"modulos dumpados: {ok}   NAO dumparam: {fail}   (rodape honesto de todo numero abaixo)")
print(f"sitios de aplicacao de regra: {tot}")
print(f"aplicacoes por modulo: mediana {apps_per[n // 2]}   maximo {apps_per[-1]}")
print(f"dialeto OO (hbclass.ch + hboo.ch): {oo}  = {100 * oo // tot}% de todo o uso")
print(f"modulos que GERAM regra ao compilar (ast-13): {genmods} de {ok} = {100 * genmods // ok}%  ({totgen} regras geradas)")
print(f"modulos que declaram diretiva no PROPRIO .prg: {len(set(k for k in inprg))} arquivos-fonte de regra; {sum(inprg.values())} aplicacoes")
print(f"comandos (nao-define) inventados dentro de .prg: {len(declprg)} regras distintas, {sum(declprg.values())} aplicacoes")
print("\nfamilias em USO:")
for k, v in fam.most_common():
    print(f"  {v:7d}  #{k}")
print("\nos 10 comandos que o core mais ESCREVE:")
for k, v in heads.most_common(10):
    print(f"  {v:7d}  {k}")
print("\nas 6 DSLs caseiras (declaradas em .prg) mais usadas:")
for (fil, head, kind, line), v in declprg.most_common(6):
    print(f"  {v:7d}x  #{kind} {head}  ({fil}:{line})")
PYEOF
