// bubble_sort.cpp — Exemplo 2: ordenação (bubble sort).
// Objetivo no gem5: muitos desvios condicionais e o preditor de desvios.
//   ROI 1: ordena um vetor aleatório — o desvio "troca?" é imprevisível;
//   ROI 2: ordena de novo o vetor JÁ ordenado — mesmas comparações, mesmo
//          código, mas o desvio nunca é tomado e o preditor acerta quase sempre.
// A diferença de ciclos entre as duas ROIs é o custo das predições erradas.
#include <cstdio>
#include "comum.h"

static void bubble_sort(int* a, int n) {
    for (int i = 0; i < n - 1; ++i)
        for (int j = 0; j < n - 1 - i; ++j)
            if (a[j] > a[j + 1]) {
                int t = a[j]; a[j] = a[j + 1]; a[j + 1] = t;
            }
}

int main() {
    const int N = 256;
    static int a[N];
    LCG g(42);
    for (int i = 0; i < N; ++i) a[i] = g.inteiro(100000);

    ROI_INICIO(1);
    bubble_sort(a, N);              // aleatório
    ROI_FIM(1);

    ROI_INICIO(2);
    bubble_sort(a, N);              // já ordenado
    ROI_FIM(2);

    bool ok = true;
    for (int i = 0; i + 1 < N; ++i) ok = ok && a[i] <= a[i + 1];
    printf("ordenado: %s  a[0]=%d a[%d]=%d\n", ok ? "sim" : "NAO", a[0], N - 1, a[N - 1]);
    return 0;
}
