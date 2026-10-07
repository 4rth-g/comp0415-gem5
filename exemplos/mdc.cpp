// mdc.cpp — Exemplo 6: máximo divisor comum, Euclides × binário.
// Objetivo no gem5: a LATÊNCIA DA DIVISÃO INTEIRA. O algoritmo de Euclides
// calcula um resto (instrução remu, divisão) a cada passo, e o passo seguinte
// depende desse resto: a latência da unidade de divisão não pode ser
// escondida. O MDC binário (Stein) chega ao mesmo resultado só com
// deslocamentos e subtrações, ao custo de mais passos.
//   ROI 1: Euclides para Q pares;  ROI 2: binário para os mesmos Q pares.
#include <cstdint>
#include <cstdio>
#include "comum.h"

__attribute__((noinline))
uint32_t mdc_euclides(uint32_t a, uint32_t b) {
    while (b != 0) {
        uint32_t r = a % b;           // divisão inteira
        a = b;
        b = r;
    }
    return a;
}

__attribute__((noinline))
uint32_t mdc_binario(uint32_t a, uint32_t b) {
    if (a == 0) return b;
    if (b == 0) return a;
    int k = 0;                        // fator 2^k comum aos dois
    while (((a | b) & 1) == 0) { a >>= 1; b >>= 1; ++k; }
    while ((a & 1) == 0) a >>= 1;
    do {
        while ((b & 1) == 0) b >>= 1;
        if (a > b) { uint32_t t = a; a = b; b = t; }
        b -= a;
    } while (b != 0);
    return a << k;
}

int main() {
    const int Q = 2000;
    static uint32_t x[Q], y[Q];
    LCG g(42);
    for (int q = 0; q < Q; ++q) {
        x[q] = g.inteiro(1 << 30) + 1;
        y[q] = g.inteiro(1 << 30) + 1;
    }

    uint64_t soma_e = 0, soma_b = 0;
    ROI_INICIO(1);
    for (int q = 0; q < Q; ++q) soma_e += mdc_euclides(x[q], y[q]);
    ROI_FIM(1);

    ROI_INICIO(2);
    for (int q = 0; q < Q; ++q) soma_b += mdc_binario(x[q], y[q]);
    ROI_FIM(2);

    printf("%d pares: soma dos MDCs Euclides=%llu binario=%llu (%s)\n", Q,
           (unsigned long long)soma_e, (unsigned long long)soma_b,
           soma_e == soma_b ? "iguais" : "DIFERENTES");
    return 0;
}
