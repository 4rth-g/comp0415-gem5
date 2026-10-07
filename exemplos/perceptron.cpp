// perceptron.cpp — Exemplo 6: perceptron (regra de Rosenblatt).
// Objetivo no gem5: um desvio que DEPENDE DOS DADOS e do aprendizado —
// "errou a amostra? então atualiza". Nas primeiras épocas o modelo erra muito
// e o desvio é imprevisível; perto da convergência quase nunca é tomado.
// ROI 1 = o treino até zero erros (ou 100 épocas).
//
// Referência: exemplos/referencia/perceptron.py (mesmos dados via LCG).
#include <cmath>
#include <cstdio>
#include "comum.h"

const int N = 200, MAX_EPOCAS = 100;
const double TAXA = 0.1, MARGEM = 0.01;

static double X[N][2];
static int Y[N];

// x1, x2 em [0, 1); rótulo +1 se 0,3·x1 + 0,7·x2 > 0,6. Pontos a menos de
// MARGEM da fronteira são descartados: o conjunto é linearmente separável.
static void gerar_dados(uint32_t semente) {
    LCG g(semente);
    int n = 0;
    while (n < N) {
        double x1 = g.uniforme(), x2 = g.uniforme();
        double f = 0.3 * x1 + 0.7 * x2 - 0.6;
        if (std::fabs(f) < MARGEM) continue;
        X[n][0] = x1; X[n][1] = x2; Y[n] = f > 0.0 ? 1 : -1;
        n++;
    }
}

int main() {
    gerar_dados(42);
    double w[2] = {0.0, 0.0}, b = 0.0;
    int erros_por_epoca[MAX_EPOCAS], epocas = 0;

    ROI_INICIO(1);
    for (int e = 0; e < MAX_EPOCAS; e++) {
        int erros = 0;
        for (int i = 0; i < N; i++) {
            double z = w[0] * X[i][0] + w[1] * X[i][1] + b;
            if (Y[i] * z <= 0.0) {             // errou (ou ficou na fronteira)
                w[0] += TAXA * Y[i] * X[i][0];
                w[1] += TAXA * Y[i] * X[i][1];
                b += TAXA * Y[i];
                erros++;
            }
        }
        erros_por_epoca[epocas++] = erros;
        if (erros == 0) break;
    }
    ROI_FIM(1);

    printf("convergiu em %d épocas; erros por época: [", epocas);
    for (int e = 0; e < epocas; e++) printf(e ? ", %d" : "%d", erros_por_epoca[e]);
    printf("]\nw = (%.6f, %.6f)   b = %.6f\n", w[0], w[1], b);
    return 0;
}
