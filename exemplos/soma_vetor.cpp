// soma_vetor.cpp — Exemplo 1: soma dos elementos de um vetor.
// Objetivo no gem5: acesso linear (sequencial) à memória, laço simples.
// ROI 1 = o laço de soma. 4096 inteiros = 16 KiB: cabe na L1D de 32 KiB, então
// as faltas são só as compulsórias (1 a cada 16 elementos — linha de 64 B).
#include <cstdio>
#include "comum.h"

int main() {
    const int N = 4096;
    static int v[N];
    LCG g(42);
    for (int i = 0; i < N; ++i) v[i] = g.inteiro(1000);

    ROI_INICIO(1);
    long soma = 0;
    for (int i = 0; i < N; ++i) soma += v[i];    // laço-alvo
    ROI_FIM(1);

    printf("soma de %d elementos = %ld\n", N, soma);
    return 0;
}
