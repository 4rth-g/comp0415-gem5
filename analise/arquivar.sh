#!/usr/bin/env bash
# arquivar.sh — move para resultados/legado/ as execuções que não correspondem
# às entradas atuais (binário fora do bin/SHA256SUMS, se_run.py diferente ou
# formato antigo, sem "parametros"). Elas continuam versionadas e rastreáveis
# pelo meta.json, mas saem do caminho da análise e do simular.sh.
#
# Uso: analise/arquivar.sh   (usa git mv para o que já está versionado)
set -euo pipefail
cd "$(dirname "$0")/.."

CFG_SHA="$(sha256sum configs_local/se_run.py | cut -d' ' -f1)"
mkdir -p resultados/legado
n=0
for d in resultados/*/; do
  d="${d%/}"
  [ "$d" = resultados/legado ] && continue
  meta="$d/meta.json"
  atual=0
  if [ -f "$meta" ] && grep -q '"parametros"' "$meta"; then
    bin_sha="$(sed -n 's/.*"binario_sha256": "\([0-9a-f]*\)".*/\1/p' "$meta")"
    cfg_sha="$(sed -n 's/.*"config_sha256": "\([0-9a-f]*\)".*/\1/p' "$meta")"
    grep -q "^$bin_sha " bin/SHA256SUMS && [ "$cfg_sha" = "$CFG_SHA" ] && atual=1
  fi
  [ $atual -eq 1 ] && continue
  if git ls-files --error-unmatch "$d" >/dev/null 2>&1; then
    git mv "$d" resultados/legado/
  else
    mv "$d" resultados/legado/
  fi
  n=$((n + 1))
done
echo "$n execução(ões) movidas para resultados/legado/"
