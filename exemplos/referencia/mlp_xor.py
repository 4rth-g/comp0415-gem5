"""Referência da MLP 2-4-1 que aprende XOR, para conferir mlp_xor.cpp.

Uso:  python3 mlp_xor.py

Camada oculta com 4 neurônios sigmoide, saída sigmoide, perda de entropia
cruzada (gradiente na saída = p - y), SGD amostra a amostra, ordem fixa.
Pesos iniciais uniformes em [-1, 1) do mesmo LCG do C++ (semente 42), na
ordem W1 (linha a linha), b1, W2, b2.
"""
import math

H, SEMENTE, TAXA, EPOCAS = 4, 42, 0.5, 3000
XOR = [((0.0, 0.0), 0.0), ((0.0, 1.0), 1.0), ((1.0, 0.0), 1.0), ((1.0, 1.0), 0.0)]
MARCAS = (0, 100, 1000, EPOCAS - 1)


def lcg(semente):
    estado = semente
    while True:
        estado = (1664525 * estado + 1013904223) % 2**32
        yield estado / 2**32


def sigmoide(z):
    return 1.0 / (1.0 + math.exp(-z))


def iniciar(semente):
    g = lcg(semente)
    u = lambda: 2.0 * next(g) - 1.0
    W1 = [[u() for _ in range(2)] for _ in range(H)]
    b1 = [u() for _ in range(H)]
    W2 = [u() for _ in range(H)]
    b2 = u()
    return W1, b1, W2, b2


def frente(W1, b1, W2, b2, x):
    h = [sigmoide(W1[k][0] * x[0] + W1[k][1] * x[1] + b1[k]) for k in range(H)]
    z = b2
    for k in range(H):
        z += W2[k] * h[k]
    return h, sigmoide(z)


def perda(W1, b1, W2, b2):
    s = 0.0
    for x, y in XOR:
        _, p = frente(W1, b1, W2, b2, x)
        s += -(y * math.log(p) + (1.0 - y) * math.log(1.0 - p))
    return s / len(XOR)


if __name__ == "__main__":
    W1, b1, W2, b2 = iniciar(SEMENTE)
    for epoca in range(EPOCAS):
        for x, y in XOR:
            h, p = frente(W1, b1, W2, b2, x)
            d2 = p - y                                   # dL/dz da saída
            for k in range(H):
                d1 = d2 * W2[k] * h[k] * (1.0 - h[k])    # retropropagação
                W2[k] -= TAXA * d2 * h[k]
                W1[k][0] -= TAXA * d1 * x[0]
                W1[k][1] -= TAXA * d1 * x[1]
                b1[k] -= TAXA * d1
            b2 -= TAXA * d2
        if epoca in MARCAS:
            print(f"  época {epoca:5d}  perda = {perda(W1, b1, W2, b2):.6f}")
    for x, y in XOR:
        print(f"  XOR{tuple(int(v) for v in x)} = {frente(W1, b1, W2, b2, x)[1]:.6f}  (alvo {int(y)})")
