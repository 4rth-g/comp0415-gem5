// fatorial.cpp — Exemplo 5: fatorial recursivo × iterativo.
// Objetivo no gem5: o CUSTO DE UMA CHAMADA DE FUNÇÃO. As duas versões fazem
// exatamente as mesmas n multiplicações; a recursiva acrescenta, a cada passo,
// uma chamada e um retorno (desvios, salvamento do endereço de retorno e de
// registradores na pilha). A diferença entre as ROIs é esse custo.
//   ROI 1: fatorial(20) recursivo, repetido REPETICOES vezes;
//   ROI 2: fatorial(20) iterativo, repetido REPETICOES vezes.
// (Ao contrário do Fibonacci, aqui o número de multiplicações é o mesmo.)
#include <cstdio>
#include "comum.h"

// sem otimização de chamada de cauda: o compilador transformaria a recursão
// em laço, e a comparação deixaria de existir
__attribute__((noinline, optimize("no-optimize-sibling-calls")))
long fat_rec(int n) {
    if (n < 2) return 1;
    return n * fat_rec(n - 1);
}

__attribute__((noinline))
long fat_iter(int n) {
    long f = 1;
    for (int i = 2; i <= n; ++i) f *= i;
    return f;
}

int main() {
    volatile int N = 20;              // 20! é o maior fatorial que cabe em 64 bits
    const int REPETICOES = 2000;

    // N relido e resultado gravado a cada volta (volatile): nenhuma chamada
    // pode ser reaproveitada ou eliminada pelo compilador
    volatile long rec, it;

    ROI_INICIO(1);
    for (int k = 0; k < REPETICOES; ++k) rec = fat_rec(N);
    ROI_FIM(1);

    ROI_INICIO(2);
    for (int k = 0; k < REPETICOES; ++k) it = fat_iter(N);
    ROI_FIM(2);

    printf("fat_rec(%d)  = %ld\n", (int)N, (long)rec);   // 2432902008176640000
    printf("fat_iter(%d) = %ld\n", (int)N, (long)it);
    return 0;
}
