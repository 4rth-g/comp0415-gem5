#!/usr/bin/env bash
# Roda uma simulação gem5 (RISC-V, modo SE) com saída identificada por
# timestamp + hash, e grava meta.json com tudo que define a execução.
#
# Uso: ./simular.sh <binario_riscv> [atomic|timing|minor|o3]
#                   [--l1d 32KiB] [--l1i 32KiB] [--l2 256KiB] [--clk 1GHz]
#
# Hash = sha256 de (binário + se_run.py + commit do gem5 + CPU + parâmetros):
# mesmas entradas => mesmo hash, então repetições da MESMA simulação
# ficam agrupáveis pelo hash e distinguíveis pelo timestamp. O ID da
# imagem fica só no meta.json: ele muda por máquina e quebraria a
# comparação entre os hashes da dupla.
#
# O meta.json só é gravado se o gem5 terminar com sucesso: execução sem
# meta.json é ignorada pela análise. stats.txt e config.ini são guardados
# comprimidos (gzip -n, determinístico) para serem versionados.
#
# O gem5 vem do repositório gem5-build, clonado ao lado deste
# (../gem5-build/gem5); outro local pode ser passado em GEM5_DIR.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
GEM5_DIR="${GEM5_DIR:-$REPO_DIR/../gem5-build/gem5}"
ENGINE="$(command -v podman || command -v docker)"
IMG="gem5-riscv:local"
CONFIG="configs_local/se_run.py"
USO="uso: $0 <binario_riscv> [atomic|timing|minor|o3] [--l1d T] [--l1i T] [--l2 T] [--clk F]"

BIN="${1:?$USO}"; shift
CPU="timing"
if [ $# -gt 0 ] && [[ "$1" != --* ]]; then CPU="$1"; shift; fi
case "$CPU" in atomic|timing|minor|o3) ;; *) echo "CPU inválida: $CPU" >&2; exit 1 ;; esac

# parâmetros: os padrões são os mesmos de se_run.py e sempre entram no hash,
# para que "omitido" e "explícito com o valor padrão" deem o mesmo hash
declare -A PADRAO=([l1d]=32KiB [l1i]=32KiB [l2]=256KiB [clk]=1GHz)
declare -A PAR
for k in "${!PADRAO[@]}"; do PAR[$k]="${PADRAO[$k]}"; done
while [ $# -gt 0 ]; do
  k="${1#--}"
  [ -n "${PADRAO[$k]+x}" ] && [ $# -ge 2 ] || { echo "$USO" >&2; exit 1; }
  PAR[$k]="$2"; shift 2
done
CHAVES=(l1d l1i l2 clk)
PARAMS_TXT=""; ARGS_GEM5=(); VARIANTE=""
for k in "${CHAVES[@]}"; do
  PARAMS_TXT+="$k=${PAR[$k]};"
  ARGS_GEM5+=("--$k" "${PAR[$k]}")
  [ "${PAR[$k]}" = "${PADRAO[$k]}" ] || VARIANTE+="_$k${PAR[$k]}"
done

[ -x "$GEM5_DIR/build/RISCV/gem5.opt" ] || {
  echo "gem5.opt não encontrado em $GEM5_DIR (rode build-gem5.sh do gem5-build ou defina GEM5_DIR)" >&2
  exit 1
}
GEM5_DIR="$(cd "$GEM5_DIR" && pwd)"
BUILD_REPO="$(cd "$GEM5_DIR/.." && pwd)"

cd "$REPO_DIR"
[ -f "$BIN" ] || { echo "binário não encontrado: $BIN" >&2; exit 1; }

TS="$(date +%Y%m%dT%H%M%S)"
BIN_SHA="$(sha256sum "$BIN" | cut -d' ' -f1)"
CFG_SHA="$(sha256sum "$CONFIG" | cut -d' ' -f1)"
GEM5_COMMIT="$(git -C "$GEM5_DIR" rev-parse HEAD)"
IMG_ID="$("$ENGINE" image inspect "$IMG" --format '{{.Id}}')"
HASH="$(printf '%s\n' "$BIN_SHA" "$CFG_SHA" "$GEM5_COMMIT" "$CPU" "$PARAMS_TXT" \
        | sha256sum | cut -c1-10)"

NOME="$(basename "$BIN")"
NOME="${NOME%_riscv}"
OUT="resultados/${NOME}_${CPU}${VARIANTE}_${TS}_${HASH}"
mkdir -p "$OUT"

"$ENGINE" run --rm -v "$REPO_DIR":/w -v "$GEM5_DIR":/gem5:ro -w /w "$IMG" \
  /gem5/build/RISCV/gem5.opt --outdir="$OUT" --redirect-stdout --redirect-stderr \
  "$CONFIG" "$BIN" --cpu "$CPU" "${ARGS_GEM5[@]}" \
  || { echo "gem5 falhou — ver $OUT/simerr.txt" >&2; exit 1; }

gzip -nf "$OUT/stats.txt" "$OUT/config.ini"

cat > "$OUT/meta.json" <<EOF
{
  "timestamp": "$(date -Is)",
  "hash": "$HASH",
  "binario": "$BIN",
  "binario_sha256": "$BIN_SHA",
  "cpu": "$CPU",
  "parametros": {"l1d": "${PAR[l1d]}", "l1i": "${PAR[l1i]}", "l2": "${PAR[l2]}", "clk": "${PAR[clk]}"},
  "config": "$CONFIG",
  "config_sha256": "$CFG_SHA",
  "gem5_commit": "$GEM5_COMMIT",
  "gem5_build_repo_commit": "$(git -C "$BUILD_REPO" describe --always --dirty 2>/dev/null || echo desconhecido)",
  "containerfile_sha256": "$(sha256sum "$BUILD_REPO/Containerfile" 2>/dev/null | cut -d' ' -f1)",
  "imagem": "$IMG",
  "imagem_id": "$IMG_ID",
  "repo_commit": "$(git describe --always --dirty 2>/dev/null || echo desconhecido)",
  "host": "$(hostname)"
}
EOF

echo ">>> Saída: $OUT"
