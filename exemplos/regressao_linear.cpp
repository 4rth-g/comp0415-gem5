// regressao_linear.cpp — Exemplo 5: regressão linear por gradiente descendente.
// Objetivo no gem5: laço numérico em ponto flutuante (double) — aparecem
// instruções FP (fadd.d, fmul.d, fmadd.d) que os exemplos anteriores não têm.
// ROI 1 = o treino inteiro (5000 épocas sobre 100 amostras).
//
// Referência: exemplos/referencia/regressao_linear.py (mesmos dados via LCG,
// mesma taxa e épocas) — perdas e w, b devem bater até a 6ª casa.
#include <cstdio>
#include <vector>
#include "comum.h"

struct Dados {
    std::vector<double> X;   // n × d, linha a linha: amostra i começa em &X[i*d]
    std::vector<double> y;   // n
    int n = 0;
    int d = 0;
};

struct Modelo {
    std::vector<double> w;
    double b = 0.0;
};

double ProdutoEscalar(const double* a, const double* b, int d) {
    double result = 0.0;
    for (int i = 0; i < d; i++) result += a[i] * b[i];
    return result;
}

double Predicao(const Modelo& modelo, const double* x) {
    return ProdutoEscalar(modelo.w.data(), x, static_cast<int>(modelo.w.size())) + modelo.b;
}

double Perda(const Modelo& modelo, const Dados& dados) {      // erro quadrático médio
    double result = 0.0;
    for (int i = 0; i < dados.n; i++) {
        double e = Predicao(modelo, &dados.X[i * dados.d]) - dados.y[i];
        result += e * e;
    }
    return result / dados.n;
}

// Um passo de gradiente descendente, em duas fases (como na referência):
// 1) acumula  dL/dw_j = (2/n) Σ e_i x_ij  e  dL/db = (2/n) Σ e_i,  e_i = ŷ_i − y_i
// 2) atualiza w ← w − taxa·dw,  b ← b − taxa·db
void Gradiente(Modelo& modelo, const Dados& dados, double taxa,
               std::vector<double>& dw) {
    for (int j = 0; j < dados.d; j++) dw[j] = 0.0;
    double db = 0.0;
    for (int i = 0; i < dados.n; i++) {
        const double* x = &dados.X[i * dados.d];
        double e = Predicao(modelo, x) - dados.y[i];
        for (int j = 0; j < dados.d; j++) dw[j] += e * x[j];
        db += e;
    }
    double k = 2.0 / dados.n;
    for (int j = 0; j < dados.d; j++) modelo.w[j] -= taxa * k * dw[j];
    modelo.b -= taxa * k * db;
}

Dados GerarDados(int n, uint32_t semente) {   // x = 10u,  y = 3x + 2 + (2u − 1)
    Dados dados;
    dados.n = n; dados.d = 1;
    dados.X.resize(n); dados.y.resize(n);
    LCG g(semente);
    for (int i = 0; i < n; i++) {
        dados.X[i] = 10.0 * g.uniforme();
        dados.y[i] = 3.0 * dados.X[i] + 2.0 + (2.0 * g.uniforme() - 1.0);
    }
    return dados;
}

int main() {
    const int N = 100, EPOCAS = 5000;
    const double TAXA = 0.01;
    Dados dados = GerarDados(N, 42);
    Modelo modelo;
    modelo.w.assign(dados.d, 0.0);
    std::vector<double> dw(dados.d);

    // perdas guardadas para imprimir depois: printf dentro da ROI seria medido
    const int MARCAS[] = {0, 10, 100, 1000, EPOCAS - 1};
    double perdas[5];
    int m = 0;

    ROI_INICIO(1);
    for (int epoca = 0; epoca < EPOCAS; epoca++) {
        Gradiente(modelo, dados, TAXA, dw);
        if (m < 5 && epoca == MARCAS[m]) perdas[m++] = Perda(modelo, dados);
    }
    ROI_FIM(1);

    for (int k = 0; k < 5; k++)
        printf("  época %5d  perda = %.6f\n", MARCAS[k], perdas[k]);
    printf("  w = %.6f   b = %.6f\n", modelo.w[0], modelo.b);
    return 0;
}
