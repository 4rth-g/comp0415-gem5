// busca_binaria.cpp — Exemplo 3: busca binária em vetor ordenado.
// Objetivo no gem5: acesso não-contíguo (saltos de índice), poucos passos
// (O(log N)) — contraste de contagem de instruções com a busca linear.
#include <cstdio>

int busca_binaria(const int* v, int n, int alvo) {
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
    const int N = 128;
    int v[N];
    for (int i = 0; i < N; ++i) v[i] = 2 * i;   // pares: 0,2,4,...

    int idx = busca_binaria(v, N, 42);           // 42 -> índice 21
    printf("busca(42) -> indice %d\n", idx);
    return 0;
}
