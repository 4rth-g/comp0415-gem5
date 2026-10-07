// fibonacci.cpp — Exemplo 4: Fibonacci recursivo × iterativo.
// Objetivo no gem5: a recursão exercita chamadas de função e a pilha
// (O(φ^n) chamadas); a versão iterativa calcula o mesmo valor com um laço
// de n passos. ROI 1: recursivo;  ROI 2: iterativo.
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

    ROI_INICIO(1);
    long r = fib_rec(N);
    ROI_FIM(1);

    ROI_INICIO(2);
    long it = fib_iter(N);
    ROI_FIM(2);

    printf("fib_rec(%d)  = %ld\n", (int)N, r);    // 6765
    printf("fib_iter(%d) = %ld\n", (int)N, it);   // 6765
    return 0;
}
