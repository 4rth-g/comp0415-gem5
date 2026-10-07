// grafo.cpp — Exemplo 7: busca em largura (BFS) em grafos.
// Objetivo no gem5: LOCALIDADE DE MEMÓRIA. O mesmo algoritmo, sobre dois grafos
// com o mesmo número de vértices (4096) e de arestas (4 por vértice):
//   ROI 1, grade 64×64: os vizinhos de v são v±1 e v±64 — os dados de vértices
//          próximos ficam próximos na memória;
//   ROI 2, grafo aleatório: os 4 vizinhos de cada vértice são sorteados — cada
//          aresta leva a um ponto qualquer do vetor de distâncias.
// O grafo fica em formato CSR (listas de adjacência em vetores contíguos):
// ~112 KiB no total, mais que a L1D (32 KiB) e menos que a L2 (256 KiB).
// Referência: exemplos/referencia/grafo.py (mesmos grafos via LCG).
#include <cstdio>
#include "comum.h"

const int L = 64, V = L * L, GRAU = 4;

struct Grafo {
    int inicio[V + 1];    // arestas do vértice v: adj[inicio[v] .. inicio[v+1])
    int adj[V * GRAU];
};

static Grafo grade, aleatorio;
static int dist[V], fila[V];

static void montar_grade(Grafo& g) {
    int e = 0;
    for (int v = 0; v < V; ++v) {
        g.inicio[v] = e;
        int lin = v / L, col = v % L;
        if (lin > 0)     g.adj[e++] = v - L;
        if (col > 0)     g.adj[e++] = v - 1;
        if (col < L - 1) g.adj[e++] = v + 1;
        if (lin < L - 1) g.adj[e++] = v + L;
    }
    g.inicio[V] = e;
}

static void montar_aleatorio(Grafo& g, uint32_t semente) {
    LCG r(semente);
    for (int v = 0; v < V; ++v) {
        g.inicio[v] = v * GRAU;
        for (int k = 0; k < GRAU; ++k) g.adj[v * GRAU + k] = r.inteiro(V);
    }
    g.inicio[V] = V * GRAU;
}

// BFS a partir de s: devolve quantos vértices foram alcançados; dist[] = nº de
// arestas até cada um (-1 = não alcançado)
static int bfs(const Grafo& g, int s, long* soma_dist) {
    for (int v = 0; v < V; ++v) dist[v] = -1;
    int ini = 0, fim = 0;
    dist[s] = 0;
    fila[fim++] = s;
    long soma = 0;
    while (ini < fim) {
        int u = fila[ini++];
        soma += dist[u];
        for (int e = g.inicio[u]; e < g.inicio[u + 1]; ++e) {
            int w = g.adj[e];
            if (dist[w] < 0) {
                dist[w] = dist[u] + 1;
                fila[fim++] = w;
            }
        }
    }
    *soma_dist = soma;
    return fim;
}

int main() {
    montar_grade(grade);
    montar_aleatorio(aleatorio, 42);
    long sg, sa;

    ROI_INICIO(1);
    int ng = bfs(grade, 0, &sg);
    ROI_FIM(1);

    ROI_INICIO(2);
    int na = bfs(aleatorio, 0, &sa);
    ROI_FIM(2);

    printf("grade: alcancados=%d soma_dist=%ld\n", ng, sg);
    printf("aleatorio: alcancados=%d soma_dist=%ld\n", na, sa);
    return 0;
}
