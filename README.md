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
Makefile               # pipeline (ver `make` alvos abaixo)
simular.sh             # roda 1 simulação -> resultados/<nome>_<cpu>[_variante]_<timestamp>_<hash>/
ambiente.sh            # Podman ou Docker + imagem, comum a todos os scripts
configs_local/
  se_run.py            # config gem5 (Standard Library), modo SE; CPU, caches e clock
                       # por argumento; dump+reset em cada ROI
exemplos/
  comum.h              # marcação de ROI (m5_work_begin/end) + gerador LCG compartilhado
  soma_vetor.cpp       # cache fria × quente + ROI vazia    (acesso sequencial; custo da marcação)
  bubble_sort.cpp      # vetor aleatório × já ordenado     (preditor de desvios)
  busca_binaria.cpp    # busca linear × binária            (O(N) × O(log N))
  fibonacci.cpp        # recursivo × iterativo (2000×)     (chamadas de função, pilha)
  regressao_linear.cpp # gradiente descendente             (ponto flutuante)
  perceptron.cpp       # regra de Rosenblatt               (desvio que depende do aprendizado)
  mlp_xor.cpp          # rede 2-4-1 aprendendo XOR         (FP + libm + retropropagação)
  camada_densa.cpp     # Y = ReLU(X·W + b), ordens i-j-k × i-k-j, N = 16..128 (hierarquia de memória)
  regioes.csv          # nome de cada ROI
  referencia/*.py      # referências em Python das redes neurais
  conferir.sh          # compila nativo e compara com as referências (make conferir)
analise/
  funcoes.R            # parser do stats.txt (segmentos/ROIs), config.ini e O3PipeView
  relatorio.R          # resultados/ -> metricas.csv, tabelas .docx, fig_*.pdf|png, sistema.dot
  fluxo.dot            # diagrama do fluxo reprodutível (fig_fluxo)
  testes.R             # testes do parser com um stats.txt sintético (make testar)
  visualizar.sh        # pipeline do o3, trace RISC-V e assembly de uma ROI (make visual)
  comparar.sh          # mesmo hash => mesmas estatísticas? (make reproduzir)
artigo/                # referencias.bib (conferido), zotero_novos.bib, ZOTERO.md
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
```

`make sim` reaproveita execuções já feitas com as mesmas entradas (mesmo
hash): com os resultados versionados, ele não simula nada de novo.

### Validação cruzada (máquina da dupla)

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

## Principais resultados (ROIs, configuração-base)

Figuras e tabelas completas em `analise/saida/` (`make analise`). A
configuração simulada está em `tabela_configuracao.docx` e `fig_sistema`.

- **Inicialização domina programas pequenos**: a soma de 4096 elementos tem
  16 mil instruções no laço, de quase 170 mil no programa inteiro
  (`fig_instrucoes`).
- **Custo da marcação de ROI** (ROI vazia, `tabela_custo_roi`): 5 instruções,
  de 6 ciclos (atomic, timing) a 25 ciclos (minor). No o3, o marcador esvazia
  o pipeline (`fig_pipeline_*`), o que pesa em ROIs pequenas.
- **Mesmas instruções, ciclos muito diferentes** (`fig_ipc`): o
  Fibonacci recursivo roda com IPC 0,67 no timing e 4,95 no o3. O atomic fica
  fora dos gráficos de IPC: é funcional, seus "ciclos" não medem tempo.
- **Cache fria × quente** (soma, o3): a mesma soma leva 5.752 ciclos com o
  vetor fora das caches e 4.124 com ele na L1D (IPC 2,85 contra 3,97).
- **Pipeline do o3** (`fig_pipeline_soma_vetor_roi2`): em regime permanente,
  o laço da soma (4 instruções) completa uma volta por ciclo.
- **Preditor de desvios** (`fig_predicao`): o bubble sort sobre vetor aleatório
  erra 3,4% dos desvios no o3 (IPC 1,55); sobre o vetor já ordenado, 0,4%
  (IPC 2,43). A busca binária, com desvios imprevisíveis, fica com IPC 0,91,
  contra 3,50 da linear.
- **Redes neurais trazem ponto flutuante**: de 24% a 51% das instruções do
  treino, contra 0% nos exemplos clássicos (`fig_mix`).
- **Hierarquia de memória × dependência de memória** (camada densa N = 64, o3,
  `fig_camada_n`, `fig_varredura_l1d`):

  | Ordem | Falhas L1D / mil instr. | Cargas retidas | Ciclos por mult.-acum. (o3) | (timing) |
  |---|---|---|---|---|
  | i-j-k (W por coluna) | 49,5 | 0 | 2,50 | 16,1 |
  | i-k-j (W por linha) | 3,0 | 274 mil | 5,12 | 14,4 |
  | i-k-j, 4 `k` por vez | 3,9 | 77 mil | 2,85 | 8,7 |

  A i-k-j quase não falha na cache e é a mais rápida no timing, como a
  análise só de cache prevê. No o3, porém, ela é duas vezes mais lenta: cada
  leitura de `Y[i][j]` vem logo depois da escrita do mesmo endereço, e o
  preditor de dependência de memória (*store sets*) retém a leitura até a
  escrita terminar. **Controle**: a variante com 4 valores de `k` por vez
  mantém o acesso por linha, mas grava `Y` 4× menos. As cargas retidas caem
  3,6× e o custo cai 44%, sem mudar as falhas de cache. Na varredura da L1D,
  o custo da i-k-j não muda com o tamanho da cache; o da i-j-k cai a partir de
  32 KiB.
- **Um controle que não funcionou**: zerar com mais frequência o preditor de
  dependência de memória (parâmetro `store_set_clear_period` do o3, de
  250.000 até 100 acessos) não mudou nenhuma estatística. Pelo rastreamento
  (`--debug-flags=StoreSet`), a mesma dependência volta a ser prevista logo
  depois de cada limpeza. Por isso o controle usado é o do código (4 `k` por
  vez). As execuções desse teste estão no commit `58fde2a`.
- **Reprodução entre motores de container**: binários compilados e simulações
  refeitas com Docker são idênticos aos do Podman (`make verificar`,
  `analise/comparar.sh`: 2 pares idênticos, 0 divergentes).
