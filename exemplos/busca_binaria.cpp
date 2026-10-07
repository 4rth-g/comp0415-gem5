// busca_binaria.cpp — Exemplo 3: busca linear × busca binária.
// Objetivo no gem5: as MESMAS consultas, no mesmo vetor ordenado, com dois
// algoritmos — O(N) com acesso sequencial × O(log N) com saltos de índice.
//   ROI 1: busca linear;  ROI 2: busca binária.
#include <cstdio>
#include "comum.h"

static int busca_linear(const int* v, int n, int alvo) {
    for (int i = 0; i < n; ++i)
        if (v[i] == alvo) return i;
    return -1;
}

static int busca_binaria(const int* v, int n, int alvo) {
    int lo = 0, hi = n - 1;
    while (lo <= hi) {
        int mid = lo + (hi - lo) / 2;
        if (v[mid] == alvo) return mid;
        else if (v[mid] < alvo) lo = mid + 1;
        else hi = mid - 1;
    }
    return -1;
}

int main() {
    const int N = 2048, Q = 500;
    static int v[N], consultas[Q];
    for (int i = 0; i < N; ++i) v[i] = 2 * i;            // pares: 0, 2, 4, ...
    LCG g(42);
    for (int q = 0; q < Q; ++q) consultas[q] = g.inteiro(2 * N);  // ~metade existe

    long soma_lin = 0, soma_bin = 0;                      // usa os resultados
    ROI_INICIO(1);
    for (int q = 0; q < Q; ++q) soma_lin += busca_linear(v, N, consultas[q]);
    ROI_FIM(1);

    ROI_INICIO(2);
    for (int q = 0; q < Q; ++q) soma_bin += busca_binaria(v, N, consultas[q]);
    ROI_FIM(2);

    printf("%d consultas: soma dos indices linear=%ld binaria=%ld (%s)\n",
           Q, soma_lin, soma_bin, soma_lin == soma_bin ? "iguais" : "DIFERENTES");
    return 0;
}
