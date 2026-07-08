#!/bin/bash
# M-cov 2 - medição de cobertura POR-PROGRAMA no corpus work/tests
# (git-ignorado; recopiar se ausente:
#  cp -r ~/devel/harbour-core/harbour/tests ~/devel/hbrefactor/work/tests)
# (método documentado em docs/limites-e-alavancas.md, seção M-cov 2).
# Uso: tests/mcov2.sh <binário-hbrefactor> <dir-saída>
# Fase A: compila cada .prg standalone com -x (harbour direto) e extrai as
#         mensagens distintas de sends[] do dump.
# Fase B: um projeto por programa; `usages <hbp> <mensagem>` por mensagem;
#         conta as linhas de veredito de send por camada.
set -u
BIN="$1"
OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
CORPUS="$HERE/../work/tests"
HB_BIN="${HB_BIN:?HB_BIN must point to the harbour binaries dir}"
INC="$HB_BIN/../../../include"
JOBS="$(nproc)"

mkdir -p "$OUT/dumps" "$OUT/prj" "$OUT/logs"

# fase A: dumps de descoberta (uma vez por corpus/saída)
if [ ! -f "$OUT/dumps/.done" ]; then
   ( cd "$CORPUS" && for f in *.prg; do
        "$HB_BIN/harbour" "$f" -n -q0 -w0 -gh -o"$OUT/dumps/${f%.prg}.hrb" \
           -x"$OUT/dumps/" -I"$INC" > /dev/null 2>&1 || echo "$f" >> "$OUT/dumps/failed.txt"
     done )
   touch "$OUT/dumps/.done"
fi

# mensagens por programa (sends[] do dump), projetos e lista de consultas
python3 - "$OUT" "$CORPUS" <<'EOF'
import json, os, sys, glob
out, corpus = sys.argv[1], sys.argv[2]
queries = []
progs = 0
for dump in sorted(glob.glob(os.path.join(out, "dumps", "*.ast.json"))):
    ast = json.load(open(dump))
    mod = os.path.basename(dump)[:-len(".ast.json")]
    prg = os.path.join(corpus, mod + ".prg")
    if not os.path.exists(prg):
        continue
    msgs = sorted({s["sym"].upper() for f in ast.get("functions", [])
                   for s in f.get("sends", [])})
    if not msgs:
        continue
    progs += 1
    d = os.path.join(out, "prj", mod)
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "p.hbp"), "w").write(mod + ".prg\n")
    dst = os.path.join(d, mod + ".prg")
    if not os.path.exists(dst):
        open(dst, "w").write(open(prg).read())
    for ch in glob.glob(os.path.join(corpus, "*.ch")):
        t = os.path.join(d, os.path.basename(ch))
        if not os.path.exists(t):
            open(t, "w").write(open(ch).read())
    for m in msgs:
        queries.append(f"{mod}\t{m}")
open(os.path.join(out, "queries.txt"), "w").write("\n".join(queries) + "\n")
print(f"programas com sends: {progs}; consultas: {len(queries)}")
EOF

# fase B: paralelo POR PROGRAMA (mensagens sequenciais dentro dele - duas
# compilações hbmk2 concorrentes no MESMO diretório de projeto colidem nos
# artefatos e a consulta falha com "o projeto não compila")
export BIN OUT
run_prog() {
   local mod="$1" msg
   while read -r msg; do
      ( cd "$OUT/prj/$mod" && "$BIN" usages p.hbp "$msg" > "$OUT/logs/$mod.$msg.log" 2>&1 )
   done < <(awk -F'\t' -v m="$mod" '$1 == m { print $2 }' "$OUT/queries.txt")
}
export -f run_prog
cut -f1 "$OUT/queries.txt" | sort -u | xargs -P "$JOBS" -n 1 bash -c 'run_prog "$@"' _

# consulta sem nenhuma linha de saída = falhou (corrida/erro de build):
# relatar em vez de silenciar
python3 - "$OUT" <<'EOF'
import os, sys
out = sys.argv[1]
bad = []
for ln in open(os.path.join(out, "queries.txt")):
    mod, msg = ln.strip().split("\t")
    log = os.path.join(out, "logs", f"{mod}.{msg}.log")
    if not os.path.exists(log) or "não compila" in open(log, errors="replace").read():
        bad.append(f"{mod}:{msg}")
print(f"consultas falhadas: {len(bad)}" + ("  " + " ".join(bad[:10]) if bad else ""))
EOF

# agregação
python3 - "$OUT" <<'EOF'
import re, sys, glob, os
out = sys.argv[1]
pat = re.compile(r':\d+: (confirmed|excluded|possible) send \((.*)\)')
tot = {"confirmed": 0, "excluded": 0, "poss_fora": 0, "poss_bloco": 0}
conf_blk = 0
for log in glob.glob(os.path.join(out, "logs", "*.log")):
    for ln in open(log, errors="replace"):
        m = pat.search(ln)
        if not m:
            continue
        kind, detail = m.groups()
        blk = detail.endswith(", codeblock") or ", codeblock" in detail
        if kind == "possible":
            tot["poss_bloco" if blk else "poss_fora"] += 1
        else:
            tot[kind] += 1
            if kind == "confirmed" and blk:
                conf_blk += 1
n = sum(tot.values())
print(f"sites: {n}")
for k, v in tot.items():
    print(f"{k}: {v} ({100.0*v/n:.1f}%)")
print(f"(confirmed dentro de bloco: {conf_blk})")
EOF
