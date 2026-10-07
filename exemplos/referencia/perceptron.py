"""Referência do perceptron (regra de Rosenblatt), para conferir perceptron.cpp.

Uso:  python3 perceptron.py

Dados 2D do mesmo LCG do C++ (semente 42): x1, x2 uniformes em [0, 1);
rótulo +1 se 0,3·x1 + 0,7·x2 > 0,6, senão -1. Pontos a menos de 0,01 da
fronteira são descartados (margem): o conjunto é linearmente separável e o
treino converge, mas só depois de algumas dezenas de épocas.
"""
N, SEMENTE, TAXA, MAX_EPOCAS, MARGEM = 200, 42, 0.1, 100, 0.01


def lcg(semente):
    estado = semente
    while True:
        estado = (1664525 * estado + 1013904223) % 2**32
        yield estado / 2**32


def gerar_dados(n, semente):
    g, X, y = lcg(semente), [], []
    while len(X) < n:
        x1, x2 = next(g), next(g)
        f = 0.3 * x1 + 0.7 * x2 - 0.6
        if abs(f) < MARGEM:
            continue
        X.append((x1, x2))
        y.append(1 if f > 0.0 else -1)
    return X, y


def treinar(X, y):
    w, b, erros_por_epoca = [0.0, 0.0], 0.0, []
    for _ in range(MAX_EPOCAS):
        erros = 0
        for (x1, x2), yi in zip(X, y):
            z = w[0] * x1 + w[1] * x2 + b
            if yi * z <= 0.0:                 # errou (ou ficou na fronteira)
                w[0] += TAXA * yi * x1
                w[1] += TAXA * yi * x2
                b += TAXA * yi
                erros += 1
        erros_por_epoca.append(erros)
        if erros == 0:
            break
    return w, b, erros_por_epoca


if __name__ == "__main__":
    X, y = gerar_dados(N, SEMENTE)
    w, b, erros = treinar(X, y)
    print(f"convergiu em {len(erros)} épocas; erros por época: {erros}")
    print(f"w = ({w[0]:.6f}, {w[1]:.6f})   b = {b:.6f}")
