"""Referência da busca em largura (BFS), para conferir grafo.cpp.

Uso:  python3 grafo.py

Mesmos grafos do C++: grade 64×64 (vizinhos v±1, v±64) e grafo aleatório com
4 vizinhos sorteados por vértice pelo mesmo LCG (semente 42).
"""
from collections import deque

L, GRAU = 64, 4
V = L * L


def lcg(semente):
    estado = semente
    while True:
        estado = (1664525 * estado + 1013904223) % 2**32
        yield estado / 2**32


def grade():
    adj = []
    for v in range(V):
        lin, col = divmod(v, L)
        viz = []
        if lin > 0:
            viz.append(v - L)
        if col > 0:
            viz.append(v - 1)
        if col < L - 1:
            viz.append(v + 1)
        if lin < L - 1:
            viz.append(v + L)
        adj.append(viz)
    return adj


def aleatorio(semente):
    g = lcg(semente)
    return [[int(next(g) * V) for _ in range(GRAU)] for _ in range(V)]


def bfs(adj, s):
    dist = [-1] * V
    dist[s] = 0
    fila = deque([s])
    alcancados, soma = 0, 0
    while fila:
        u = fila.popleft()
        alcancados += 1
        soma += dist[u]
        for w in adj[u]:
            if dist[w] < 0:
                dist[w] = dist[u] + 1
                fila.append(w)
    return alcancados, soma


if __name__ == "__main__":
    for nome, adj in (("grade", grade()), ("aleatorio", aleatorio(42))):
        n, soma = bfs(adj, 0)
        print(f"{nome}: alcancados={n} soma_dist={soma}")
