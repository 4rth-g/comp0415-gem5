// mlp_xor.cpp — Exemplo 7: rede neural (MLP 2-4-1) aprendendo XOR.
// Objetivo no gem5: o menor problema que EXIGE uma camada oculta (XOR não é
// linearmente separável). Mistura ponto flutuante, chamadas à libm (exp, na
// sigmoide) e o laço de retropropagação. ROI 1 = o treino (3000 épocas).
//
// Camada oculta com 4 sigmoides, saída sigmoide, entropia cruzada (gradiente
// na saída = p − y), SGD amostra a amostra em ordem fixa.
// Referência: exemplos/referencia/mlp_xor.py (mesmos pesos iniciais via LCG).
#include <cmath>
#include <cstdio>
#include "comum.h"

const int H = 4, EPOCAS = 3000;
const double TAXA = 0.5;
const double XOR_X[4][2] = {{0, 0}, {0, 1}, {1, 0}, {1, 1}};
const double XOR_Y[4] = {0, 1, 1, 0};

struct Rede {
    double W1[H][2], b1[H], W2[H], b2;
};

static double sigmoide(double z) { return 1.0 / (1.0 + std::exp(-z)); }

// pesos uniformes em [-1, 1), na ordem W1 (linha a linha), b1, W2, b2
static void iniciar(Rede& r, uint32_t semente) {
    LCG g(semente);
    auto u = [&g] { return 2.0 * g.uniforme() - 1.0; };
    for (int k = 0; k < H; k++) { r.W1[k][0] = u(); r.W1[k][1] = u(); }
    for (int k = 0; k < H; k++) r.b1[k] = u();
    for (int k = 0; k < H; k++) r.W2[k] = u();
    r.b2 = u();
}

static double frente(const Rede& r, const double* x, double* h) {
    double z = r.b2;
    for (int k = 0; k < H; k++) {
        h[k] = sigmoide(r.W1[k][0] * x[0] + r.W1[k][1] * x[1] + r.b1[k]);
        z += r.W2[k] * h[k];
    }
    return sigmoide(z);
}

static double perda(const Rede& r) {
    double h[H], s = 0.0;
    for (int i = 0; i < 4; i++) {
        double p = frente(r, XOR_X[i], h);
        s += -(XOR_Y[i] * std::log(p) + (1.0 - XOR_Y[i]) * std::log(1.0 - p));
    }
    return s / 4;
}

int main() {
    Rede r;
    iniciar(r, 42);
    const int MARCAS[] = {0, 100, 1000, EPOCAS - 1};
    double perdas[4];
    int m = 0;

    ROI_INICIO(1);
    double h[H];
    for (int e = 0; e < EPOCAS; e++) {
        for (int i = 0; i < 4; i++) {
            const double* x = XOR_X[i];
            double p = frente(r, x, h);
            double d2 = p - XOR_Y[i];                         // dL/dz da saída
            for (int k = 0; k < H; k++) {
                double d1 = d2 * r.W2[k] * h[k] * (1.0 - h[k]);   // retropropagação
                r.W2[k] -= TAXA * d2 * h[k];
                r.W1[k][0] -= TAXA * d1 * x[0];
                r.W1[k][1] -= TAXA * d1 * x[1];
                r.b1[k] -= TAXA * d1;
            }
            r.b2 -= TAXA * d2;
        }
        if (m < 4 && e == MARCAS[m]) perdas[m++] = perda(r);
    }
    ROI_FIM(1);

    for (int k = 0; k < 4; k++)
        printf("  época %5d  perda = %.6f\n", MARCAS[k], perdas[k]);
    for (int i = 0; i < 4; i++)
        printf("  XOR(%d, %d) = %.6f  (alvo %d)\n", (int)XOR_X[i][0], (int)XOR_X[i][1],
               frente(r, XOR_X[i], h), (int)XOR_Y[i]);
    return 0;
}
