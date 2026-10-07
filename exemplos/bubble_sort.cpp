// bubble_sort.cpp — Exemplo 2: ordenação (bubble sort).
// Objetivo no gem5: muitos desvios condicionais; contraste de ciclos/instruções
// com a soma de vetor. Bom para observar predição de desvios (CPU O3).
#include <cstdio>

int main() {
    const int N = 32;
    int a[N];
    // vetor propositalmente "quase invertido" para forçar trocas
    for (int i = 0; i < N; ++i) a[i] = N - i;

    for (int i = 0; i < N - 1; ++i)
        for (int j = 0; j < N - 1 - i; ++j)
            if (a[j] > a[j + 1]) {
                int t = a[j]; a[j] = a[j + 1]; a[j + 1] = t;
            }

    printf("ordenado: a[0]=%d a[%d]=%d\n", a[0], N - 1, a[N - 1]); // 1 ... 32
    return 0;
}
