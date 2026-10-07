// soma_vetor.cpp — Exemplo 1: soma dos elementos de um vetor.
// Objetivo no gem5: acesso linear (sequencial) à memória e o efeito da cache.
// 4096 inteiros = 16 KiB = 256 linhas de 64 B (cabe na L1D de 32 KiB).
//   ROI 1, cache fria:   antes dela, um buffer de 1 MiB (maior que a L2) é
//                        percorrido e expulsa o vetor das caches — cada linha
//                        do vetor falta na L1D e na L2 (faltas compulsórias);
//   ROI 2, cache quente: a mesma soma logo em seguida — o vetor já está na L1D;
//   ROI 3, vazia:        nada entre as marcações — mede o custo da própria
//                        marcação de ROI em cada modelo de CPU.
#include <cstdio>
#include "comum.h"

int main() {
    const int N = 4096;
    static int v[N];
    static char lixo[1 << 20];                   // 1 MiB: maior que a L2 (256 KiB)
    LCG g(42);
    for (int i = 0; i < N; ++i) v[i] = g.inteiro(1000);

    for (int i = 0; i < (int)sizeof lixo; i += 64) lixo[i] = (char)i;  // expulsa v

    ROI_INICIO(1);
    long fria = 0;
    for (int i = 0; i < N; ++i) fria += v[i];    // laço-alvo
    ROI_FIM(1);

    ROI_INICIO(2);
    long quente = 0;
    for (int i = 0; i < N; ++i) quente += v[i];  // mesmo laço, cache quente
    ROI_FIM(2);

    ROI_INICIO(3);
    ROI_FIM(3);

    printf("soma de %d elementos = %ld (fria) = %ld (quente); lixo[64]=%d\n",
           N, fria, quente, lixo[64]);
    return 0;
}
