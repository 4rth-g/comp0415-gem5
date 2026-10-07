# Simulação arquitetural com gem5 (RISC-V) — Avaliação 1

Trabalho da disciplina **Arquitetura de Computadores (COMP0415 — UFS)**: uso do
simulador **gem5** para executar algoritmos básicos sobre a ISA **RISC-V** e
observar métricas de microarquitetura (instruções, ciclos, IPC/CPI, cache).

Ênfase em **reprodutibilidade**: todo o gem5
é compilado/executado dentro de um **container** idêntico, eliminando o "na
minha máquina funciona".

## Dois repositórios

| Repositório | Conteúdo | Muda |
|---|---|---|
| [`gem5-build`](https://github.com/4rth-g/arquitetura-gem5-riscv) | build do gem5 (commit fixado) + imagem `gem5-riscv:local` | uma vez |
| **este** ([`comp0415-gem5`](https://github.com/4rth-g/comp0415-gem5)) | exemplos, config de simulação, execução, análise, artigo, slides | sempre |

Os dois ficam **lado a lado**, e o do build com o nome de pasta `gem5-build`
(o `simular.sh` procura o gem5 em `../gem5-build/gem5`):

```bash
git clone https://github.com/4rth-g/arquitetura-gem5-riscv.git gem5-build
git clone https://github.com/4rth-g/comp0415-gem5.git
```

Outro local: `GEM5_DIR=/caminho/do/gem5 ./simular.sh ...`.

## Estrutura

```
Makefile               # pipeline (ver `make` alvos abaixo)
simular.sh             # roda 1 simulação -> resultados/<nome>_<cpu>[_variante]_<timestamp>_<hash>/
ambiente.sh            # Podman ou Docker + imagem, comum a todos os scripts
configs_local/
  se_run.py            # config gem5 (Standard Library), modo SE; CPU, caches e clock
                       # por argumento; dump+reset em cada ROI
exemplos/
  comum.h              # marcação de ROI (m5_work_begin/end) + gerador LCG compartilhado
  soma_vetor.cpp       # cache fria × quente + ROI vazia    (acesso sequencial; custo da marcação)
  ordenacao.cpp        # bubble (aleatório × ordenado) × quicksort (preditor; complexidade)
  busca_binaria.cpp    # busca linear × binária            (O(N) × O(log N))
  grafo.cpp            # BFS em grade × grafo aleatório    (localidade de memória)
  fibonacci.cpp        # recursivo × iterativo (2000×)     (número de chamadas)
  fatorial.cpp         # recursivo × iterativo (2000×)     (custo de uma chamada)
  mdc.cpp              # Euclides × binário                (latência da divisão)
  regressao_linear.cpp # gradiente descendente             (ponto flutuante)
  perceptron.cpp       # regra de Rosenblatt               (desvio que depende do aprendizado)
  mlp_xor.cpp          # rede 2-4-1 aprendendo XOR         (FP + libm + retropropagação)
  camada_densa.cpp     # multiplicação de matrizes (camada densa), 3 ordens de laço, N = 16..128
  regioes.csv          # nome de cada ROI
  referencia/*.py      # referências em Python (busca em grafo e redes neurais)
  conferir.sh          # compila nativo e compara com as referências (make conferir)
analise/
  funcoes.R            # parser do stats.txt (segmentos/ROIs), config.ini e O3PipeView
  relatorio.R          # resultados/ -> metricas.csv, tabelas .docx, fig_*.pdf|png, sistema.dot
  fluxo.dot            # diagrama do fluxo reprodutível (fig_fluxo)
  testes.R             # testes do parser com um stats.txt sintético (make testar)
  visualizar.sh        # pipeline do o3, trace RISC-V e assembly de uma ROI (make visual)
  comparar.sh          # mesmo hash => mesmas estatísticas? (make reproduzir)
artigo/
  artigo.qmd           # o artigo (Quarto); números lidos de analise/saida/metricas.csv
  modelo.docx          # modelo da disciplina (template SBC, 2 colunas)
  preparar_modelo.py   # modelo.docx -> referencia.docx (reference-doc do Quarto)
  referencias.bib      # referências conferidas (Crossref/DataCite); ZOTERO.md, zotero_novos.bib
  abnt-numerico.csl    # estilo ABNT numérico, citação entre colchetes como no modelo
  typst/               # modelo Typst equivalente (PDF): 2 colunas, Times, página Carta
_quarto.yml            # projeto Quarto mínimo (raiz do Typst = raiz do repo)
renv.lock              # versões exatas dos pacotes R (snapshot Posit PM de 25/09/2026)
bin/SHA256SUMS         # hashes dos binários RISC-V — referência para `make verificar`
resultados/            # execuções das entradas atuais (as antigas ficam no histórico do git)
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

# 2) os exemplos estão certos? (saída nativa = referência em Python, no container)
make conferir
make testar                   # testes do parser de estatísticas

# 3) tudo: compila, simula, varreduras, pipeline do o3, tabelas e gráficos
make tudo                     # JOBS=n simulações em paralelo (padrão 4)
#    -> analise/saida/: metricas.csv, mix.csv, configuracao.csv,
#       tabela_*.docx, fig_*.pdf|png
#    -> artigo/artigo.docx e artigo/artigo.pdf (Typst) — requer Quarto
```

`make sim` reaproveita execuções já feitas com as mesmas entradas (mesmo
hash): com os resultados versionados, ele não simula nada de novo.

### Reprodução em outra máquina

```bash
cd ~/src/gem5-build && ./build-gem5.sh       # Docker: ENGINE=docker ./build-gem5.sh
cd ~/src/comp0415-gem5
Rscript -e 'renv::restore()'
make reproduzir     # 1) recompila e confere os binários com bin/SHA256SUMS
                    # 2) simula tudo de novo (FORCAR=1)
                    # 3) compara cada stats.txt novo com o versionado de mesmo
                    #    hash, ignorando só as linhas host* -> "pares idênticos: N"
git add resultados && git commit -m "Reprodução em <máquina>"
```

Com Docker, os scripts rodam o container com o usuário do host (`--user`),
para que `bin/` e `resultados/` não fiquem com dono root.

Uma simulação avulsa, com parâmetros fora do padrão (entram no hash e no nome):

```bash
./simular.sh bin/soma_vetor_riscv o3 --l1d 8KiB --clk 2GHz
```

**Garantias de reprodutibilidade.** O hash de cada execução é
sha256(binário + `se_run.py` + commit do gem5 + CPU + parâmetros). A análise
só usa execuções das entradas atuais (binário em `bin/SHA256SUMS` e
`se_run.py` do repositório); quando as entradas mudam, as execuções antigas
saem de `resultados/` e continuam no histórico do git. O gem5 é
determinístico, então mesmas entradas dão o mesmo `stats.txt` em qualquer
máquina (exceto as linhas `host*`, que medem o computador hospedeiro). O
`meta.json` registra também o commit deste repositório e do `gem5-build`, o
sha256 do `Containerfile`, o ID da imagem e o host. Ele só é gravado se a
simulação termina com sucesso. Execuções com o repositório sujo aparecem com
`-dirty` no `repo_commit`.

## Principais resultados

Os números estão no artigo (`make artigo`), que os lê de
`analise/saida/metricas.csv`; figuras e tabelas em `analise/saida/`.

- **Inicialização × algoritmo**: um binário estático executa ~117 mil
  instruções fora do algoritmo; por isso a medição é feita nas ROIs.
- **Mesmas instruções, ciclos muito diferentes** entre timing, minor e o3
  (`fig_ipc`).
- **Preditor de desvios**: bubble sort aleatório × ordenado; quicksort e busca
  binária com desvios imprevisíveis (`fig_predicao`).
- **Localidade**: a mesma BFS leva bem mais ciclos no grafo aleatório que na
  grade, com o mesmo número de instruções.
- **Custo de chamada**: fatorial recursivo × iterativo, mesmas multiplicações.
- **Latência da divisão**: no MDC, os modelos sem temporização de unidades
  funcionais (atomic, timing) apontam Euclides como o mais rápido; o o3
  (divisão de 20 ciclos) mostra o contrário.
- **Cache × dependência de memória** (multiplicação de matrizes): a ordem
  i-k-j quase não falha na cache, mas é a mais lenta no o3, porque o preditor
  de dependência de memória (*store sets*) retém as leituras de `Y`; o
  controle com 4 `k` por vez confirma a causa (`fig_camada_n`,
  `fig_varredura_l1d`).
- **Um controle que não funcionou**: zerar o preditor de dependência com mais
  frequência (`store_set_clear_period`) não mudou nenhuma estatística; as
  execuções desse teste estão no commit `58fde2a`.
- **Reprodução entre motores de container**: binários e simulações pelo
  Docker idênticos aos do Podman (`make verificar`, `analise/comparar.sh`).
