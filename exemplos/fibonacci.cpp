// fibonacci.cpp — Exemplo 4: Fibonacci recursivo × iterativo.
// Objetivo no gem5: a recursão exercita chamadas de função e a pilha
// (O(φ^n) chamadas); a versão iterativa calcula o mesmo valor com um laço
// de n passos. ROI 1: recursivo (1 chamada);  ROI 2: iterativo, repetido
// REPETICOES vezes — uma chamada só tem ~110 instruções, pouco para as taxas
// (IPC, predição) serem estáveis; por chamada, divida por REPETICOES.
#include <cstdio>
#include "comum.h"

long fib_rec(int n) {                 // recursivo: muitas chamadas
    if (n < 2) return n;
    return fib_rec(n - 1) + fib_rec(n - 2);
}

long fib_iter(int n) {                // iterativo: laço simples
    long a = 0, b = 1;
    for (int i = 0; i < n; ++i) { long t = a + b; a = b; b = t; }
    return a;
}

int main() {
    volatile int N = 20;              // volatile: impede o cálculo em compilação
    const int REPETICOES = 2000;

    ROI_INICIO(1);
    long r = fib_rec(N);
    ROI_FIM(1);

    ROI_INICIO(2);
    long soma_it = 0;                 // N relido a cada volta: nada é reaproveitado
    for (int k = 0; k < REPETICOES; ++k) soma_it += fib_iter(N);
    ROI_FIM(2);
    long it = soma_it / REPETICOES;

    printf("fib_rec(%d)  = %ld\n", (int)N, r);    // 6765
    printf("fib_iter(%d) = %ld\n", (int)N, it);   // 6765
    return 0;
}
