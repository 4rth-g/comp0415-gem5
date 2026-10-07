// comum.h — utilidades compartilhadas pelos exemplos.
//
// ROI_INICIO/ROI_FIM marcam a região de interesse (ROI): o trecho que o gem5
// mede separadamente (ver configs_local/se_run.py). Fora do gem5 (compilação
// nativa para teste, -DSEM_GEM5) viram no-ops — a instrução m5op mataria o
// processo num processador real.
//
// LCG: dados pseudoaleatórios determinísticos, idênticos aos das referências
// em Python (exemplos/referencia/), para conferir os resultados:
//     estado = (1664525 * estado + 1013904223) mod 2^32
//     u      = estado / 2^32                        (uniforme em [0, 1))
// Dados gerados em tempo de execução também impedem que o compilador
// calcule o resultado de antemão (constant folding).
#pragma once
#include <cstdint>

#ifdef SEM_GEM5
#define ROI_INICIO(id) ((void)0)
#define ROI_FIM(id) ((void)0)
#else
#include <gem5/m5ops.h>
#define ROI_INICIO(id) m5_work_begin((id), 0)
#define ROI_FIM(id) m5_work_end((id), 0)
#endif

struct LCG {
    uint32_t estado;
    explicit LCG(uint32_t semente) : estado(semente) {}
    double uniforme() {                       // [0, 1)
        estado = 1664525u * estado + 1013904223u;
        return estado / 4294967296.0;
    }
    int inteiro(int n) { return static_cast<int>(uniforme() * n); }  // [0, n)
};
