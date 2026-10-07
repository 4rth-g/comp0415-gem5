"""Referência da regressão linear em NumPy, para conferir a versão em C++.

Uso:  python3 regressao_linear.py

Os dados vêm de um LCG (gerador congruencial linear) em vez de numpy.random,
para que o C++ gere EXATAMENTE os mesmos números:

    estado = (1664525 * estado + 1013904223) mod 2^32     (uint32_t em C++)
    u      = estado / 2^32                                  (uniforme em [0, 1))

Dados: x = 10 * u,  y = 3x + 2 + ruído,  ruído = 2u - 1  (uniforme em [-1, 1)).
"""
import numpy as np

N, SEMENTE = 100, 42
TAXA, EPOCAS = 0.01, 5000


def lcg(semente):
    estado = semente
    while True:
        estado = (1664525 * estado + 1013904223) % 2**32
        yield estado / 2**32


def gerar_dados(n, semente):
    g = lcg(semente)
    x = np.empty(n)
    y = np.empty(n)
    for i in range(n):
        x[i] = 10.0 * next(g)
        y[i] = 3.0 * x[i] + 2.0 + (2.0 * next(g) - 1.0)
    return x.reshape(-1, 1), y          # X: n × d (d = 1)


def perda(w, b, X, y):
    erro = X @ w + b - y
    return np.mean(erro**2)


# ---- 1) fechado, 1 variável: derivada = 0 ------------------------------------
def fechado_1d(X, y):
    x = X[:, 0]
    w = np.sum((x - x.mean()) * (y - y.mean())) / np.sum((x - x.mean()) ** 2)
    b = y.mean() - w * x.mean()
    return np.array([w]), b


# ---- 2) fechado, d variáveis: equações normais  (XᵀX) θ = Xᵀy -----------------
def equacoes_normais(X, y):
    X1 = np.column_stack([X, np.ones(len(X))])     # coluna de 1s = viés
    theta = np.linalg.solve(X1.T @ X1, X1.T @ y)    # resolve, não inverte
    return theta[:-1], theta[-1]


# ---- 3) gradiente descendente (o que você implementa em C++) -----------------
def gradiente(w, b, X, y):
    n = len(y)
    erro = X @ w + b - y                  # e_i = ŷ_i − y_i
    dw = (2.0 / n) * (X.T @ erro)         # ∂L/∂w_j = (2/n) Σ e_i x_ij
    db = (2.0 / n) * np.sum(erro)         # ∂L/∂b   = (2/n) Σ e_i
    return dw, db


def gradiente_descendente(X, y, taxa, epocas):
    w, b = np.zeros(X.shape[1]), 0.0
    for epoca in range(epocas):
        dw, db = gradiente(w, b, X, y)    # fase 1: acumula
        w -= taxa * dw                    # fase 2: atualiza
        b -= taxa * db
        if epoca in (0, 10, 100, 1000) or epoca == epocas - 1:
            print(f"  época {epoca:5d}  perda = {perda(w, b, X, y):.6f}")
    return w, b


# ---- 4) checagem do gradiente por diferença finita ---------------------------
def checar_gradiente(X, y, h=1e-5):
    w, b = np.array([0.7]), -0.3          # um ponto qualquer, não o ótimo
    dw, db = gradiente(w, b, X, y)
    num_w = (perda(w + h, b, X, y) - perda(w - h, b, X, y)) / (2 * h)
    num_b = (perda(w, b + h, X, y) - perda(w, b - h, X, y)) / (2 * h)
    print(f"  dw analítico = {dw[0]: .8f}   numérico = {num_w: .8f}")
    print(f"  db analítico = {db: .8f}   numérico = {num_b: .8f}")


if __name__ == "__main__":
    X, y = gerar_dados(N, SEMENTE)
    print(f"primeiros dados: x = {X[:3, 0].round(6)}, y = {y[:3].round(6)}")

    print("\n1) fechado (1 variável)")
    w, b = fechado_1d(X, y)
    print(f"  w = {w[0]:.6f}   b = {b:.6f}   perda = {perda(w, b, X, y):.6f}")

    print("\n2) equações normais")
    w, b = equacoes_normais(X, y)
    print(f"  w = {w[0]:.6f}   b = {b:.6f}")

    print("\n3) biblioteca: np.linalg.lstsq (QR/SVD, como o lm do R)")
    X1 = np.column_stack([X, np.ones(len(X))])
    theta, *_ = np.linalg.lstsq(X1, y, rcond=None)
    print(f"  w = {theta[0]:.6f}   b = {theta[1]:.6f}")

    print(f"\n4) gradiente descendente (taxa = {TAXA}, épocas = {EPOCAS})")
    w, b = gradiente_descendente(X, y, TAXA, EPOCAS)
    print(f"  w = {w[0]:.6f}   b = {b:.6f}")

    print("\n5) checagem do gradiente (em w = 0.7, b = -0.3)")
    checar_gradiente(X, y)
