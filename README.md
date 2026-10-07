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
Makefile               # pipeline: make bin | conferir | sim | varredura | analise | tudo | verificar
simular.sh             # roda 1 simulação -> resultados/<nome>_<cpu>[_variante]_<timestamp>_<hash>/
configs_local/
  se_run.py            # config gem5 (Standard Library), modo SE; CPU, caches e clock por argumento;
                       # despeja e zera as estatísticas no início e no fim de cada ROI
exemplos/
  comum.h              # marcação de ROI (m5_work_begin/end) + gerador LCG compartilhado
  soma_vetor.cpp       # soma de vetor                     (acesso sequencial à memória)
  bubble_sort.cpp      # vetor aleatório × já ordenado     (preditor de desvios)
  busca_binaria.cpp    # busca linear × binária            (O(N) × O(log N))
  fibonacci.cpp        # recursivo × iterativo             (chamadas de função, pilha)
  regressao_linear.cpp # gradiente descendente             (ponto flutuante)
  perceptron.cpp       # regra de Rosenblatt               (desvio que depende do aprendizado)
  mlp_xor.cpp          # rede 2-4-1 aprendendo XOR         (FP + libm + retropropagação)
  camada_densa.cpp     # Y = ReLU(X·W + b), ordens i-j-k × i-k-j, N = 16..128 (hierarquia de memória)
  regioes.csv          # nome de cada ROI
  referencia/*.py      # referências em Python das redes neurais
  conferir.sh          # compila nativo e compara com as referências (make conferir)
analise/
  relatorio.R          # resultados/ -> metricas.csv, mix.csv, tabelas .docx, fig_*.pdf|png
  visualizar.sh        # pipeline do o3, trace RISC-V, assembly e diagrama do sistema de uma ROI
renv.lock              # versões exatas dos pacotes R (snapshot Posit PM de 25/09/2026)
bin/SHA256SUMS         # hashes dos binários RISC-V — referência para `make verificar`
```

### Regiões de interesse (ROI)

Um binário estático passa ~110 mil instruções inicializando a glibc antes do
`main` — mais que o próprio algoritmo na maioria dos exemplos. Por isso cada
exemplo marca o trecho medido com `ROI_INICIO(k)`/`ROI_FIM(k)` (`comum.h`), e o
`se_run.py` despeja e zera as estatísticas nesses pontos: o `stats.txt` fica
dividido em `[antes] [ROI 1] [entre] [ROI 2] ... [depois]`. O `relatorio.R`
gera uma linha por ROI e uma para o programa inteiro (a soma dos segmentos).

Versionado de cada simulação: `meta.json`, `stats.txt.gz`, `config.ini.gz` e
`simout.txt` (saída do programa). Binários e `analise/saida/` são regeneráveis.

## Como reproduzir

```bash
# 0) pré-requisito: ../gem5-build/build-gem5.sh (gem5.opt, libm5, imagem gem5-riscv:local)

# 1) pacotes R nas versões do renv.lock (uma vez)
Rscript -e 'renv::restore()'

# 2) os exemplos estão certos? (saída nativa = referência em Python)
make conferir

# 3) tudo: compila, simula programa × CPU (+ varredura da L1D), tabelas e gráficos
make tudo                     # JOBS=n simulações em paralelo (padrão 4)
#    -> analise/saida/: metricas.csv, mix.csv, tabela_*.docx, fig_*.pdf|png

# 4) visualizações de uma ROI (pipeline do o3, trace, assembly, diagrama)
analise/visualizar.sh soma_vetor 1

# Validação cruzada (máquina da dupla): os binários devem bater bit a bit
make verificar
```

Uma simulação avulsa, com parâmetros fora do padrão (entram no hash e no nome):

```bash
./simular.sh bin/soma_vetor_riscv o3 --l1d 8KiB --clk 2GHz
```

**Garantias de reprodutibilidade.** O hash de cada execução é
sha256(binário + `se_run.py` + commit do gem5 + CPU + parâmetros). A análise
só usa execuções das entradas atuais (binário em `bin/SHA256SUMS` e
`se_run.py` do repositório); execuções antigas ficam em `resultados/`,
rastreáveis, mas fora das tabelas. O gem5 é
determinístico, então mesmas entradas dão o mesmo `stats.txt` em qualquer
máquina (exceto as linhas `host*`, que medem o computador hospedeiro). O
`meta.json` registra também o commit deste repositório e do `gem5-build`, o
sha256 do `Containerfile`, o ID da imagem e o host. Ele só é gravado se a
simulação termina com sucesso. Execuções com o repositório sujo aparecem com
`-dirty` no `repo_commit`.

## Principais resultados (ROIs, configuração-base)

Figuras e tabelas completas em `analise/saida/` (`make analise`).

- **Inicialização domina programas pequenos**: a soma de 4096 elementos executa
  16 mil instruções no laço e 169 mil no programa inteiro (`fig_instrucoes`).
- **Mesmas instruções, ciclos muito diferentes**: o Fibonacci recursivo roda
  com IPC 0,67 no `timing` e 5,19 no `o3` (`fig_ipc`).
- **Preditor de desvios**: o bubble sort sobre vetor aleatório erra 3,4% dos
  desvios no `o3` (IPC 1,55); o mesmo código sobre o vetor já ordenado erra
  0,4% (IPC 2,43). A busca binária, com desvios imprevisíveis, fica com IPC
  0,91 contra 3,50 da linear (`fig_predicao`).
- **Redes neurais trazem ponto flutuante**: 24–51% das instruções no treino,
  contra 0% nos exemplos clássicos (`fig_mix`).
- **Hierarquia de memória × especulação** (camada densa, `fig_camada_n` e
  `fig_varredura_l1d`): a ordem i-j-k falha muito mais na L1D quando as
  matrizes não cabem nela (49,5 contra 3,0 falhas por mil instruções com
  N = 64), e fica mais barata quando a L1D cresce para 32 KiB. Ainda assim,
  no `o3` ela é **mais rápida** que a i-k-j (2,5 contra 5,1 ciclos por
  multiplicação-acumulação): na i-k-j, o preditor de dependência de memória
  (*store sets*) retém as cargas de `Y` atrás das escritas anteriores
  (274 mil cargas retidas), e o custo não muda com o tamanho da cache. Nos
  modelos sem especulação (`timing`), a i-k-j ganha, como a análise só de
  cache prevê.
