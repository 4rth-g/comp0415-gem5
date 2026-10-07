// ordenacao.cpp — Exemplo 2: ordenação, O(n²) × O(n log n).
// Objetivo no gem5: desvios condicionais, o preditor de desvios e o efeito da
// complexidade do algoritmo, sempre sobre os mesmos dados.
//   ROI 1: bubble sort de um vetor aleatório — o desvio "troca?" é imprevisível;
//   ROI 2: bubble sort do vetor JÁ ordenado — mesmas comparações, mesmo
//          código, mas o desvio nunca é tomado e o preditor acerta quase sempre;
//   ROI 3: quicksort de uma cópia do MESMO vetor aleatório da ROI 1 —
//          O(n log n) comparações em vez de O(n²), com recursão.
#include <cstdio>
#include "comum.h"

static void bubble_sort(int* a, int n) {
    for (int i = 0; i < n - 1; ++i)
        for (int j = 0; j < n - 1 - i; ++j)
            if (a[j] > a[j + 1]) {
                int t = a[j]; a[j] = a[j + 1]; a[j + 1] = t;
            }
}

// quicksort com partição de Hoare e pivô no meio do intervalo
static void quicksort(int* a, int lo, int hi) {
    if (lo >= hi) return;
    int pivo = a[lo + (hi - lo) / 2];
    int i = lo - 1, j = hi + 1;
    while (true) {
        do ++i; while (a[i] < pivo);
        do --j; while (a[j] > pivo);
        if (i >= j) break;
        int t = a[i]; a[i] = a[j]; a[j] = t;
    }
    quicksort(a, lo, j);
    quicksort(a, j + 1, hi);
}

static bool ordenado(const int* a, int n) {
    for (int i = 0; i + 1 < n; ++i)
        if (a[i] > a[i + 1]) return false;
    return true;
}

int main() {
    const int N = 256;
    static int a[N], b[N];
    LCG g(42);
    for (int i = 0; i < N; ++i) a[i] = b[i] = g.inteiro(100000);

    ROI_INICIO(1);
    bubble_sort(a, N);              // aleatório
    ROI_FIM(1);

    ROI_INICIO(2);
    bubble_sort(a, N);              // já ordenado
    ROI_FIM(2);

    ROI_INICIO(3);
    quicksort(b, 0, N - 1);         // o mesmo vetor aleatório da ROI 1
    ROI_FIM(3);

    bool iguais = true;
    for (int i = 0; i < N; ++i) iguais = iguais && a[i] == b[i];
    printf("bubble: %s  quicksort: %s  mesmo resultado: %s  a[0]=%d a[%d]=%d\n",
           ordenado(a, N) ? "ordenado" : "NAO", ordenado(b, N) ? "ordenado" : "NAO",
           iguais ? "sim" : "NAO", a[0], N - 1, a[N - 1]);
    return 0;
}
