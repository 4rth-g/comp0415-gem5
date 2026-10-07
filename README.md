# Simulação arquitetural com gem5 (RISC-V) — Avaliação 1

Trabalho da disciplina **Arquitetura de Computadores (COMP0415 — UFS)**: uso do
simulador **gem5** para executar algoritmos básicos sobre a ISA **RISC-V** e
observar métricas de microarquitetura (instruções, ciclos, IPC/CPI, cache).

Ênfase em **reprodutibilidade**: a dupla usa sistemas diferentes, e todo o gem5
é compilado/executado dentro de um **container** idêntico, eliminando o "na
minha máquina funciona".

## Dois repositórios

| Repositório | Conteúdo | Muda |
|---|---|---|
| [`gem5-build`](../gem5-build) | build do gem5 (commit fixado) + imagem `gem5-riscv:local` | uma vez |
| **este** | exemplos, config de simulação, execução, análise | sempre |

Os dois ficam **lado a lado** (`~/src/gem5-build` e `~/src/comp0415-gem5`);
o `simular.sh` procura o gem5 em `../gem5-build/gem5`. Outro local:
`GEM5_DIR=/caminho/do/gem5 ./simular.sh ...`.

## Estrutura

```
Makefile               # pipeline completo: make bin | sim | analise | tudo | verificar
simular.sh             # roda 1 simulação -> resultados/<nome>_<cpu>[_variante]_<timestamp>_<hash>/
configs_local/
  se_run.py            # config gem5 (Standard Library), modo SE; CPU, caches e clock por argumento
exemplos/
  soma_vetor.cpp       # soma de vetor      (acesso linear à memória)
  bubble_sort.cpp      # ordenação          (desvios condicionais)
  busca_binaria.cpp    # busca binária      (acesso não-contíguo, O(log N))
  fibonacci.cpp        # recursão × iteração (pilha/chamadas)
analise/
  relatorio.R          # lê resultados/*/{meta.json,stats.txt.gz} -> metricas.csv, tabela .docx, gráficos
renv.lock              # versões exatas dos pacotes R (snapshot Posit PM de 25/09/2026)
bin/SHA256SUMS         # hashes dos binários RISC-V — referência para `make verificar`
```

Versionado de cada simulação: `meta.json`, `stats.txt.gz`, `config.ini.gz` e
`simout.txt` (saída do programa). Binários e `analise/saida/` são regeneráveis.

## Como reproduzir

```bash
# 0) pré-requisito: ../gem5-build/build-gem5.sh (gem5.opt, libm5, imagem gem5-riscv:local)

# 1) pacotes R nas versões do renv.lock (uma vez)
Rscript -e 'renv::restore()'

# 2) tudo: compila os exemplos, simula programa × CPU, gera tabelas e gráficos
make tudo
#    -> analise/saida/: metricas.csv, tabela_metricas.docx, fig_*.pdf|png

# Validação cruzada (máquina da dupla): os binários devem bater bit a bit
make verificar
```

Uma simulação avulsa, com parâmetros fora do padrão (entram no hash e no nome):

```bash
./simular.sh bin/soma_vetor_riscv o3 --l1d 8KiB --clk 2GHz
```

**Garantias de reprodutibilidade.** O hash de cada execução é
sha256(binário + `se_run.py` + commit do gem5 + CPU + parâmetros). O gem5 é
determinístico, então mesmas entradas dão o mesmo `stats.txt` em qualquer
máquina (exceto as linhas `host*`, que medem o computador hospedeiro). O
`meta.json` registra também o commit deste repositório e do `gem5-build`, o
sha256 do `Containerfile`, o ID da imagem e o host. Ele só é gravado se a
simulação termina com sucesso. Execuções com o repositório sujo aparecem com
`-dirty` no `repo_commit`.

## Resultado de exemplo (`soma_vetor`, 3 modelos de CPU)

> Programa inteiro, **incluindo a inicialização da glibc** (quase todas as ~115 mil
> instruções). A medição só do laço (região de interesse) é a próxima etapa.

| Métrica | ATOMIC | TIMING | O3 |
|---|---|---|---|
| Instruções | 115710 | 115710 | 115710 |
| Ciclos | 156180 | 231036 | 54936 |
| IPC | 0.74 | 0.50 | 2.11 |
| CPI | 1.35 | 2.00 | 0.47 |

Mesmo programa, **mesmas instruções**, ciclos muito diferentes: o desempenho vem
de **como** a microarquitetura executa (o `O3`, superescalar/fora de ordem,
alcança IPC > 2). É o que um simulador de arquitetura permite observar.
