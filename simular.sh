#!/usr/bin/env bash
# Roda uma simulação gem5 (RISC-V, modo SE) com saída identificada por
# timestamp + hash, e grava meta.json com tudo que define a execução.
#
# Uso: ./simular.sh <binario_riscv> [atomic|timing|minor|o3]
#                   [--l1d 32KiB] [--l1i 32KiB] [--l2 256KiB] [--clk 1GHz]
#
# Hash = sha256 de (binário + se_run.py + commit do gem5 + CPU + parâmetros):
# mesmas entradas => mesmo hash. O ID da imagem fica só no meta.json: ele
# muda por máquina e quebraria a comparação entre os hashes da dupla.
#
# Se já existe uma execução completa com o mesmo hash, ela é reaproveitada
# (o gem5 é determinístico, o resultado seria o mesmo). FORCAR=1 simula de
# novo — é assim que a reprodução é conferida (make reproduzir).
#
# O meta.json só é gravado se o gem5 terminar com sucesso: execução sem
# meta.json é ignorada pela análise. stats.txt e config.ini são guardados
# comprimidos (gzip -n, determinístico) para serem versionados.
#
# O gem5 vem do repositório gem5-build, clonado ao lado deste
# (../gem5-build/gem5); outro local pode ser passado em GEM5_DIR.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$REPO_DIR/ambiente.sh"
GEM5_DIR="${GEM5_DIR:-$REPO_DIR/../gem5-build/gem5}"
CONFIG="configs_local/se_run.py"
USO="uso: $0 <binario_riscv> [atomic|timing|minor|o3] [--l1d T] [--l1i T] [--l2 T] [--clk F]"

BIN="${1:?$USO}"; shift
CPU="timing"
if [ $# -gt 0 ] && [[ "$1" != --* ]]; then CPU="$1"; shift; fi
case "$CPU" in atomic|timing|minor|o3) ;; *) echo "CPU inválida: $CPU" >&2; exit 1 ;; esac

# parâmetros: os padrões são os mesmos de se_run.py e sempre entram no hash,
# para que "omitido" e "explícito com o valor padrão" deem o mesmo hash
CHAVES=(l1d l1i l2 clk)
declare -A PADRAO=([l1d]=32KiB [l1i]=32KiB [l2]=256KiB [clk]=1GHz)
declare -A PAR
for k in "${CHAVES[@]}"; do PAR[$k]="${PADRAO[$k]}"; done
while [ $# -gt 0 ]; do
  k="${1#--}"
  [ -n "${PADRAO[$k]+x}" ] && [ $# -ge 2 ] || { echo "$USO" >&2; exit 1; }
  PAR[$k]="$2"; shift 2
done
PARAMS_TXT=""; PARAMS_JSON=""; ARGS_GEM5=(); VARIANTE=""
for k in "${CHAVES[@]}"; do
  PARAMS_TXT+="$k=${PAR[$k]};"
  PARAMS_JSON+="${PARAMS_JSON:+, }\"$k\": \"${PAR[$k]}\""
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

BIN_SHA="$(sha256sum "$BIN" | cut -d' ' -f1)"
CFG_SHA="$(sha256sum "$CONFIG" | cut -d' ' -f1)"
GEM5_COMMIT="$(git -C "$GEM5_DIR" rev-parse HEAD)"
HASH="$(printf '%s\n' "$BIN_SHA" "$CFG_SHA" "$GEM5_COMMIT" "$CPU" "$PARAMS_TXT" \
        | sha256sum | cut -c1-10)"

NOME="$(basename "$BIN")"
NOME="${NOME%_riscv}"
PREFIXO="${NOME}_${CPU}${VARIANTE}"

if [ -z "${FORCAR:-}" ]; then
  for d in resultados/"${PREFIXO}"_*_"$HASH"; do
    [ -f "$d/meta.json" ] && { echo ">>> Já existe: $d"; exit 0; }
  done
fi

TS="$(date +%Y%m%dT%H%M%S)"
OUT="resultados/${PREFIXO}_${TS}_${HASH}"
mkdir -p "$OUT"
IMG_ID="$("$ENGINE" image inspect "$IMG" --format '{{.Id}}')"

em_container -v "$REPO_DIR":/w -v "$GEM5_DIR":/gem5:ro -w /w "$IMG" \
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
  "parametros": {$PARAMS_JSON},
  "config": "$CONFIG",
  "config_sha256": "$CFG_SHA",
  "gem5_commit": "$GEM5_COMMIT",
  "gem5_build_repo_commit": "$(git -C "$BUILD_REPO" describe --always --dirty 2>/dev/null || echo desconhecido)",
  "containerfile_sha256": "$(sha256sum "$BUILD_REPO/Containerfile" 2>/dev/null | cut -d' ' -f1)",
  "imagem": "$IMG",
  "imagem_id": "$IMG_ID",
  "motor": "$(basename "$ENGINE")",
  "repo_commit": "$(git describe --always --dirty 2>/dev/null || echo desconhecido)",
  "host": "$(hostname)"
}
EOF

echo ">>> Saída: $OUT"
