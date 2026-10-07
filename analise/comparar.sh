#!/usr/bin/env bash
# comparar.sh — confere a REPRODUÇÃO: execuções com o mesmo hash (mesmas
# entradas) devem ter estatísticas idênticas, em qualquer máquina.
#
# Para cada hash com 2+ execuções completas em resultados/, compara os
# stats.txt ignorando só as linhas host* (tempo e memória do computador
# hospedeiro, que naturalmente variam). Execuções novas para comparar com as
# versionadas: FORCAR=1 make sim (ou make reproduzir, que faz as duas coisas).
#
# Uso: analise/comparar.sh        (código de saída 1 se alguma divergir)
set -euo pipefail
cd "$(dirname "$0")/.."

declare -A RUNS
for meta in resultados/*/meta.json; do
  d="$(dirname "$meta")"
  h="$(sed -n 's/.*"hash": "\([0-9a-f]*\)".*/\1/p' "$meta")"
  RUNS[$h]+="$d "
done

estat() { zcat "$1/stats.txt.gz" | grep -v '^host'; }
host()  { sed -n 's/.*"host": "\([^"]*\)".*/\1/p' "$1/meta.json"; }

iguais=0; diferentes=0; sozinhas=0
for h in "${!RUNS[@]}"; do
  read -ra ds <<< "${RUNS[$h]}"
  if [ ${#ds[@]} -lt 2 ]; then sozinhas=$((sozinhas + 1)); continue; fi
  ref="${ds[0]}"
  for d in "${ds[@]:1}"; do
    if cmp -s <(estat "$ref") <(estat "$d"); then
      iguais=$((iguais + 1))
    else
      diferentes=$((diferentes + 1))
      echo "DIFERENTE: $ref ($(host "$ref")) × $d ($(host "$d"))"
      diff <(estat "$ref") <(estat "$d") | head -6
    fi
  done
done

echo "pares idênticos: $iguais · divergentes: $diferentes · hashes sem repetição: $sozinhas"
[ "$diferentes" -eq 0 ]
