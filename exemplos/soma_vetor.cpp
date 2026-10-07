// soma_vetor.cpp — Exemplo 1: soma dos elementos de um vetor.
// Objetivo no gem5: acesso linear à memória, laço simples.
// Pequeno de propósito (simulação rápida). Saída pelo código de retorno + print.
#include <cstdio>

int main() {
    const int N = 64;
    int v[N];
    for (int i = 0; i < N; ++i) v[i] = i + 1;   // 1..64

    long soma = 0;
    for (int i = 0; i < N; ++i) soma += v[i];    // laço-alvo

    printf("soma(1..%d) = %ld\n", N, soma);      // esperado: 2080
    return 0;
}
