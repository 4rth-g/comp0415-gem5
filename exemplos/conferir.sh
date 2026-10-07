#!/usr/bin/env bash
# Confere a CORREÇÃO dos exemplos antes de simulá-los (o gem5 mede, não valida):
#  1) compila cada exemplo nativamente (x86-64, no container, -DSEM_GEM5 — as
#     marcações de ROI viram no-ops) e mostra a saída;
#  2) para a busca em grafo e as redes neurais, compara com a referência em Python
#     (exemplos/referencia/), linha a linha — também no container
#     (Python 3.12 e numpy 1.26.4 fixados na imagem).
# Uso (na raiz do repo): ./exemplos/conferir.sh   — ou: make conferir
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO_DIR/ambiente.sh"
OUT="$REPO_DIR/build/nativo"
mkdir -p "$OUT"
cd "$REPO_DIR"

nativo() {   # nativo <programa> [flags extras]
  local p="$1"; shift
  em_container -v "$REPO_DIR":/w -w /w "$IMG" \
    g++ -O2 -ffp-contract=off -DSEM_GEM5 "$@" "exemplos/${p%_N*}.cpp" -o "build/nativo/$p"
  "$OUT/$p"
}

for p in soma_vetor ordenacao busca_binaria fibonacci fatorial mdc; do
  echo "== $p"; nativo "$p"
done
for n in 16 32 64 128; do
  echo "== camada_densa_N$n"; nativo "camada_densa_N$n" -DN="$n"
done

falhas=0
compara() {  # compara <nome> <saída C++> <saída Python>
  if diff <(echo "$2") <(echo "$3") >/dev/null; then
    echo "== $1: OK (igual à referência Python)"
    echo "$2"
  else
    echo "== $1: DIFERENTE da referência Python"
    diff <(echo "$2") <(echo "$3") || true
    falhas=1
  fi
}

ref() { em_container -v "$REPO_DIR":/w -w /w/exemplos/referencia "$IMG" python3 "$1"; }

filtro='^  (época|w =)'
compara regressao_linear \
  "$(nativo regressao_linear | grep -E "$filtro")" \
  "$(ref regressao_linear.py | sed -n '/^4)/,/^5)/p' | grep -E "$filtro")"
compara grafo "$(nativo grafo)" "$(ref grafo.py)"
compara perceptron "$(nativo perceptron)" "$(ref perceptron.py)"
compara mlp_xor "$(nativo mlp_xor)" "$(ref mlp_xor.py)"

exit $falhas
