#!/usr/bin/env bash
# visualizar.sh — figuras "de dentro" do simulador, para o artigo:
#   pipeline.txt  linha do tempo do pipeline da CPU o3, instrução por
#                 instrução (O3PipeView + util/o3-pipeview.py do gem5);
#                 cada coluna é um ciclo: f=fetch d=decode n=rename p=dispatch
#                 i=issue c=complete r=retire (commit)
#   exec.txt      trace das instruções RISC-V executadas (debug flag Exec,
#                 CPU atomic): tick, PC, instrução e resultado
#   main.s        assembly RISC-V da função main (objdump)
#   sistema.svg   diagrama do sistema simulado (config.dot.svg do gem5)
# Tudo restrito ao início de uma região de interesse (ROI), a partir das
# simulações já feitas por `make sim` — que dão o tick em que a ROI começa.
#
# Uso: analise/visualizar.sh [programa] [roi] [ciclos]
#      (padrão: soma_vetor 1 100) -> analise/saida/visual/<programa>_roi<roi>/
set -euo pipefail

PROG="${1:-soma_vetor}"; ROI="${2:-1}"; CICLOS="${3:-100}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GEM5_DIR="${GEM5_DIR:-$REPO_DIR/../gem5-build/gem5}"
GEM5_DIR="$(cd "$GEM5_DIR" && pwd)"
source "$REPO_DIR/ambiente.sh"
BIN="bin/${PROG}_riscv"
OUT="analise/saida/visual/${PROG}_roi${ROI}"
TICKS_POR_CICLO=1000                                  # clock de 1 GHz

cd "$REPO_DIR"
[ -f "$BIN" ] || { echo "binário não encontrado: $BIN (rode make bin)" >&2; exit 1; }
SHA="$(sha256sum "$BIN" | cut -d' ' -f1)"
mkdir -p "$OUT"

# execução mais recente deste binário nesta CPU, na configuração-base
execucao() {
  ls -dt resultados/"${PROG}_$1"_2* 2>/dev/null | while read -r d; do
    grep -q "\"binario_sha256\": \"$SHA\"" "$d/meta.json" 2>/dev/null && { echo "$d"; break; }
  done
}

# tick do início da ROI: o dump 2·roi−1 é o segmento logo antes dela, e seu
# finalTick (cumulativo, nunca zerado) é o instante em que a ROI começa
inicio_roi() {
  zcat "$1/stats.txt.gz" | awk -v alvo=$((2 * ROI - 1)) '
    /Begin Simulation Statistics/ { d++ }
    d == alvo && $1 == "finalTick" && !t { t = $2 }
    END { print t }'
}

gem5() {   # gem5 <cpu> <tick inicial> <flag> <arquivo>
  em_container -v "$REPO_DIR":/w -v "$GEM5_DIR":/gem5:ro -w /w "$IMG" \
    /gem5/build/RISCV/gem5.opt --outdir="$OUT/gem5_$1" \
      --debug-flags="$3" --debug-start="$2" \
      --debug-end=$(($2 + CICLOS * TICKS_POR_CICLO)) --debug-file="$4" \
      configs_local/se_run.py "$BIN" --cpu "$1" >/dev/null
}

for cpu in o3 atomic; do
  d="$(execucao $cpu)"
  [ -n "$d" ] || { echo "sem simulação $cpu de $BIN em resultados/ (rode make sim)" >&2; exit 1; }
  t="$(inicio_roi "$d")"
  echo ">>> $PROG ROI $ROI na CPU $cpu começa no tick $t ($d)"
  if [ "$cpu" = o3 ]; then
    gem5 o3 "$t" O3PipeView o3pipeview.txt
    em_container -v "$REPO_DIR":/w -v "$GEM5_DIR":/gem5:ro -w /w "$IMG" \
      python3 /gem5/util/o3-pipeview.py -c $TICKS_POR_CICLO -w $((CICLOS + 10)) \
        --only_committed -o "$OUT/pipeline.txt" "$OUT/gem5_o3/o3pipeview.txt"
    cp "$d/config.dot.svg" "$OUT/sistema.svg" 2>/dev/null \
      || cp "$OUT/gem5_o3/config.dot.svg" "$OUT/sistema.svg"
  else
    gem5 atomic "$t" Exec exec_bruto.txt
    sed 's/^ *[0-9]*: board\.processor\.cores\.core: //' \
      "$OUT/gem5_atomic/exec_bruto.txt" > "$OUT/exec.txt"
  fi
done

em_container -v "$REPO_DIR":/w -w /w "$IMG" \
  riscv64-linux-gnu-objdump -d --no-show-raw-insn "$BIN" \
  | awk '/^[0-9a-f]+ <main>:/,/^$/' > "$OUT/main.s"

echo ">>> $OUT: pipeline.txt exec.txt main.s sistema.svg"
