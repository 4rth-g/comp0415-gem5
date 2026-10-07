// camada_densa.cpp — Exemplo 8: inferência de uma camada densa, Y = ReLU(X·W + b).
// Objetivo no gem5: a HIERARQUIA DE MEMÓRIA. O núcleo é um produto de matrizes
// N×N (double); o mesmo cálculo é feito em duas ordens de laço:
//   ROI 1, ordem i-j-k: percorre W por COLUNA (salto de N·8 bytes a cada passo)
//   ROI 2, ordem i-k-j: percorre W e Y por LINHA (acesso sequencial), mas
//          relê Y[i][j] logo depois de gravá-lo (a cada passo de k)
//   ROI 3, ordem i-k-j com 4 valores de k por vez: mesmo acesso por linha,
//          mas acumula em registrador e grava Y[i][j] 4× menos vezes — isola
//          o custo da dependência escrita→leitura em memória (ver README)
// Mesmas operações, mesmo resultado — só muda o padrão de acesso à memória.
//
// N é fixado na compilação (-DN=...), um binário por tamanho, para comparar
// matrizes que cabem na L1D (32 KiB), só na L2 (256 KiB) ou em nenhuma das duas:
//   N = 16 → 3 matrizes ×  2 KiB;   N = 32 → ×  8 KiB (24 KiB, cabe na L1D)
//   N = 64 → 3 × 32 KiB (só na L2); N = 128 → 3 × 128 KiB (maior que a L2)
#include <cstdio>
#include "comum.h"

#ifndef N
#define N 64
#endif

static double X[N][N], W[N][N], Y1[N][N], Y2[N][N], Y3[N][N], B[N];

static void camada_ijk(double Y[N][N]) {
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            double s = B[j];
            for (int k = 0; k < N; k++) s += X[i][k] * W[k][j];   // W por coluna
            Y[i][j] = s > 0.0 ? s : 0.0;                          // ReLU
        }
}

static void camada_ikj(double Y[N][N]) {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) Y[i][j] = B[j];
        for (int k = 0; k < N; k++) {
            double xik = X[i][k];
            for (int j = 0; j < N; j++) Y[i][j] += xik * W[k][j];  // W por linha
        }
        for (int j = 0; j < N; j++) Y[i][j] = Y[i][j] > 0.0 ? Y[i][j] : 0.0;
    }
}

// como camada_ikj, com k desenrolado 4×; cada Y[i][j] ainda soma os termos
// com k crescente, um de cada vez (mesmo arredondamento, resultado idêntico)
static void camada_ikj4(double Y[N][N]) {
    static_assert(N % 4 == 0, "N deve ser múltiplo de 4");
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) Y[i][j] = B[j];
        for (int k = 0; k < N; k += 4) {
            double x0 = X[i][k], x1 = X[i][k + 1], x2 = X[i][k + 2], x3 = X[i][k + 3];
            for (int j = 0; j < N; j++) {
                double t = Y[i][j];
                t += x0 * W[k][j];
                t += x1 * W[k + 1][j];
                t += x2 * W[k + 2][j];
                t += x3 * W[k + 3][j];
                Y[i][j] = t;
            }
        }
        for (int j = 0; j < N; j++) Y[i][j] = Y[i][j] > 0.0 ? Y[i][j] : 0.0;
    }
}

int main() {
    LCG g(42);
    for (int i = 0; i < N; i++)
        for (int k = 0; k < N; k++) X[i][k] = 2.0 * g.uniforme() - 1.0;
    for (int k = 0; k < N; k++)
        for (int j = 0; j < N; j++) W[k][j] = 2.0 * g.uniforme() - 1.0;
    for (int j = 0; j < N; j++) B[j] = 2.0 * g.uniforme() - 1.0;

    ROI_INICIO(1);
    camada_ijk(Y1);
    ROI_FIM(1);

    ROI_INICIO(2);
    camada_ikj(Y2);
    ROI_FIM(2);

    ROI_INICIO(3);
    camada_ikj4(Y3);
    ROI_FIM(3);

    // nas três ordens cada Y[i][j] acumula os termos com k crescente, então
    // (sem fusão multiply-add, -ffp-contract=off) o resultado é idêntico: dif = 0
    double soma = 0.0, dif = 0.0;
    auto maior = [&dif](double d) { if (d < 0) d = -d; if (d > dif) dif = d; };
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            soma += Y1[i][j];
            maior(Y1[i][j] - Y2[i][j]);
            maior(Y1[i][j] - Y3[i][j]);
        }
    printf("N=%d  soma(Y)=%.6f  max|diferença entre as 3 ordens|=%.2e\n", N, soma, dif);
    return 0;
}
