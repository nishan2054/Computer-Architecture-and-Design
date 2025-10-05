#!/usr/bin/env bash
set -euo pipefail
GEM5=./build/X86/gem5.opt
RUN="configs/deprecated/example/se.py"
OUT=/work/out; mkdir -p "$OUT"

run_case () {
  label="$1"; l1d="$2"; la="$3"; l1i="$4"; lia="$5"; l2="$6"; l2a="$7"; line="$8"; mib="$9"; stride="${10}"
  echo "==> $label"
  rm -rf m5out
  $GEM5 $RUN -c /work/mem_bench --options="$mib $stride" \
    --cpu-type=TimingSimpleCPU --caches --l2cache \
    --l1d_size=$l1d --l1d_assoc=$la --l1i_size=$l1i --l1i_assoc=$lia \
    --l2_size=$l2 --l2_assoc=$l2a --cacheline_size=$line
  dest="$OUT/$label"; rm -rf "$dest"; mkdir -p "$dest"; cp -r m5out/* "$dest"/
  echo "$label,$l1d,$la,$l1i,$lia,$l2,$l2a,$line,$mib,$stride" >> "$OUT/params.csv"
}

echo "label,l1d_size,l1d_assoc,l1i_size,l1i_assoc,l2_size,l2_assoc,cacheline,arrayMiB,strideB" > "$OUT/params.csv"

# Baseline
run_case baseline 32kB 2 32kB 2 1MB 8 64 64 64

# L1D size
for s in 16kB 32kB 64kB; do run_case L1D_${s} $s 2 32kB 2 1MB 8 64 128 64; done

# L1D associativity
for a in 1 2 4 8; do run_case L1Dassoc_${a} 32kB $a 32kB 2 1MB 8 64 128 64; done

# L2 size
for s in 512kB 1MB 2MB; do run_case L2_${s} 32kB 2 32kB 2 $s 8 64 256 64; done

# Cache line size
for l in 64 128; do run_case Line_${l} 32kB 2 32kB 2 1MB 8 $l 128 64; done

# TLB pressure via 4KiB stride (se.py doesn’t expose TLB entries on all builds, so we vary access pattern)
for m in 128 256 512; do run_case TLB_stride_4096_${m} 32kB 2 32kB 2 1MB 8 64 $m 4096; done

# ---- Parse stats into CSV ----
python3 - <<'PY'
import os,re,csv,glob
OUT="/work/out"
def last(lines,rx):
  p=re.compile(rx); v=None
  for ln in lines:
    if p.search(ln):
      for tok in reversed(ln.split()):
        try: v=float(tok); break
        except: pass
  return v
params={}
with open(os.path.join(OUT,"params.csv")) as f:
  for r in csv.DictReader(f): params[r["label"]]=r
rows=[]
for d in sorted(glob.glob(os.path.join(OUT,"*"))):
  if os.path.basename(d)=="params.csv": continue
  sf=os.path.join(d,"stats.txt")
  if not os.path.exists(sf): continue
  L=open(sf).read().splitlines()
  g=lambda rx: last(L,rx)
  rows.append({
    "label":os.path.basename(d),
    "sim_seconds":g(r"(^|\.)sim_seconds\b"),"sim_ticks":g(r"(^|\.)sim_ticks\b"),
    "dcache_miss_rate":g(r"cpu\.dcache\..*(overall_miss_rate|miss_rate)\b"),
    "icache_miss_rate":g(r"cpu\.icache\..*(overall_miss_rate|miss_rate)\b"),
    "l2_miss_rate":g(r"\bl2cache\..*(overall_miss_rate|miss_rate)\b"),
    **params.get(os.path.basename(d),{})
  })
with open("/work/results.csv","w",newline="") as f:
  cols=["label","l1d_size","l1d_assoc","l1i_size","l1i_assoc","l2_size","l2_assoc","cacheline","arrayMiB","strideB",
        "sim_seconds","sim_ticks","dcache_miss_rate","icache_miss_rate","l2_miss_rate"]
  w=csv.DictWriter(f,fieldnames=cols); w.writeheader()
  for r in rows: w.writerow(r)
print("Wrote /work/results.csv with",len(rows),"rows")
PY
echo "Done. See /work/out/*/ and /work/results.csv"
