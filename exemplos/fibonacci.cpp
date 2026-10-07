// fibonacci.cpp — Exemplo 4: Fibonacci (versão recursiva + iterativa).
// Objetivo no gem5: a recursão exercita chamadas de função e a pilha;
// comparar com a versão iterativa mostra impacto no nº de instruções/ciclos.
#include <cstdio>

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
    const int N = 20;                 // pequeno: simulação rápida
    printf("fib_rec(%d)  = %ld\n", N, fib_rec(N));   // 6765
    printf("fib_iter(%d) = %ld\n", N, fib_iter(N));  // 6765
    return 0;
}
