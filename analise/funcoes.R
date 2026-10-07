# funcoes.R — leitura das simulações do gem5 (usado por relatorio.R e testes.R).
#
#   ler_dumps()      stats.txt(.gz) -> tibble (dump, nome, valor)
#   segmentar()      dumps -> 1 linha por segmento (programa inteiro + ROIs)
#   execucoes_validas(), ler_execucao(), ler_tudo()  resultados/ -> tabelas
#   ler_config(), cfg()                               config.ini(.gz) -> valores
#   ler_pipeview()                                    trace O3PipeView -> tibble
#
# Segmentos: o se_run.py despeja e zera as estatísticas no início e no fim de
# cada região de interesse (ROI), então o stats.txt tem os dumps
#   [antes] [ROI 1] [entre] [ROI 2] ... [depois]
# Cada ROI vira uma linha; a soma de todos os dumps vira "programa inteiro".
# As taxas (IPC, taxas de falha...) são recalculadas a partir das contagens.
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(purrr); library(stringr)
  library(readr); library(jsonlite)
})

CPUS <- c("atomic", "timing", "minor", "o3")
BASE <- list(l1d = "32KiB", l1i = "32KiB", l2 = "256KiB", clk = "1GHz")

P <- "board.processor.cores.core."
C <- "board.cache_hierarchy."
CONTADORES <- c(
  instrucoes      = "simInsts",
  ticks           = "simTicks",
  tempo_host      = "hostSeconds",   # tempo real no computador hospedeiro
  ciclos          = paste0(P, "numCycles"),
  l1d_falhas      = paste0(C, "l1d-cache-0.overallMisses::total"),
  l1d_acessos     = paste0(C, "l1d-cache-0.overallAccesses::total"),
  l1i_falhas      = paste0(C, "l1i-cache-0.overallMisses::total"),
  l1i_acessos     = paste0(C, "l1i-cache-0.overallAccesses::total"),
  l2_falhas       = paste0(C, "l2-cache-0.overallMisses::total"),
  l2_acessos      = paste0(C, "l2-cache-0.overallAccesses::total"),
  desvios         = paste0(P, "branchPred.condPredicted"),   # só minor e o3
  desvios_errados = paste0(P, "branchPred.condIncorrect"),
  # o3: cargas que o preditor de dependência de memória (store sets) segurou
  # até uma escrita anterior terminar
  cargas_retidas  = paste0(P, "MemDepUnit__0.conflictingLoads")
)
PREFIXO_MIX <- paste0(P, "commitStats0.committedInstType::")

# classes de instrução do gem5 -> grupos do artigo
grupo_mix <- function(classe) case_when(
  str_starts(classe, "Int")                     ~ "inteiro",
  classe %in% c("MemRead", "FloatMemRead")      ~ "leitura de memória",
  classe %in% c("MemWrite", "FloatMemWrite")    ~ "escrita em memória",
  str_starts(classe, "Float")                   ~ "ponto flutuante",
  TRUE                                          ~ "outros"
)
GRUPOS <- c("inteiro", "ponto flutuante", "leitura de memória",
            "escrita em memória", "outros")

# ---- stats.txt ----------------------------------------------------------------

# stats.txt(.gz) -> tibble (dump, nome, valor), só linhas escalares
ler_dumps <- function(arquivo) {
  linhas <- readLines(arquivo, warn = FALSE)        # descomprime .gz sozinho
  dump   <- cumsum(str_detect(linhas, "Begin Simulation Statistics"))
  ok     <- dump > 0 & nzchar(str_trim(linhas)) & !str_starts(linhas, "-")
  partes <- str_split_fixed(str_squish(linhas[ok]), " ", 3)
  tibble(dump = dump[ok], nome = partes[, 1],
         valor = suppressWarnings(as.numeric(partes[, 2]))) |>
    filter(!is.na(valor))
}

# Os dumps de uma execução -> uma linha por segmento (programa inteiro + ROIs).
# Contador ausente num dump = 0 (o gem5 omite contagens zeradas); ausente em
# todos = NA (o modelo de CPU não tem aquela estrutura, ex.: preditor no atomic).
segmentar <- function(d) {
  n <- max(d$dump)
  cont <- map_dfc(CONTADORES, function(nome) {
    v <- d |> filter(nome == !!nome)
    if (!nrow(v)) return(rep(NA_real_, n))
    x <- numeric(n); x[v$dump] <- v$valor; x
  }) |> mutate(dump = seq_len(n))
  mix <- d |>
    filter(str_starts(nome, fixed(PREFIXO_MIX)), !str_ends(nome, "::total")) |>
    mutate(grupo = grupo_mix(str_remove(nome, fixed(PREFIXO_MIX)))) |>
    group_by(dump, grupo) |> summarise(qtd = sum(valor), .groups = "drop")

  # dumps pares (2, 4, ...) são as ROIs, exceto o último (que é o "depois")
  rois <- if (n >= 3) seq(2, n - 1, by = 2) else integer(0)
  segmentos <- c(list(list(roi = 0L, dumps = seq_len(n))),
                 map(rois, \(i) list(roi = as.integer(i / 2), dumps = i)))
  linhas <- map(segmentos, function(s) {
    soma <- cont |> filter(dump %in% s$dumps) |> select(-dump) |>
      summarise(across(everything(), \(x) sum(x)))
    m <- mix |> filter(dump %in% s$dumps) |> group_by(grupo) |>
      summarise(qtd = sum(qtd), .groups = "drop")
    list(cont = mutate(soma, roi = s$roi), mix = mutate(m, roi = s$roi))
  })
  list(cont = list_rbind(map(linhas, "cont")), mix = list_rbind(map(linhas, "mix")))
}

# taxas derivadas das contagens
derivar <- function(df) df |> mutate(
  ipc            = instrucoes / ciclos,
  cpi            = ciclos / instrucoes,
  mpki_l1d       = 1000 * l1d_falhas / instrucoes,
  mpki_l2        = 1000 * l2_falhas / instrucoes,
  taxa_falha_l1d = l1d_falhas / l1d_acessos,
  taxa_falha_l2  = l2_falhas / l2_acessos,
  erro_predicao  = desvios_errados / desvios
)

# ---- resultados/ --------------------------------------------------------------

# Válida = gerada pelas entradas ATUAIS: binário listado no bin/SHA256SUMS e
# se_run.py igual ao do repositório. Execuções de entradas antigas são
# ignoradas (e podem ser apagadas: continuam no histórico do git).
execucoes_validas <- function(dir_res = "resultados", sha256sums = "bin/SHA256SUMS",
                              config = "configs_local/se_run.py") {
  sha_bins <- read_table(sha256sums, col_names = c("sha", "arquivo"),
                         show_col_types = FALSE)$sha
  sha_cfg  <- str_extract(system2("sha256sum", config, stdout = TRUE), "^\\S+")
  metas <- list.files(dir_res, pattern = "^meta\\.json$", recursive = TRUE,
                      full.names = TRUE)
  valida <- map_lgl(metas, function(arq) {
    m <- fromJSON(arq)
    !is.null(m$parametros) && m$binario_sha256 %in% sha_bins &&
      m$config_sha256 == sha_cfg
  })
  if (any(!valida))
    message("ignorando ", sum(!valida), " execução(ões) de entradas antigas ",
            "(binário ou se_run.py diferentes dos atuais)")
  dirname(metas[valida])
}

ler_execucao <- function(dir) {
  m    <- fromJSON(file.path(dir, "meta.json"))
  nome <- str_remove(basename(m$binario), "_riscv$")
  par  <- modifyList(BASE, m$parametros)     # parâmetro ausente = valor-base
  seg  <- segmentar(ler_dumps(file.path(dir, "stats.txt.gz")))
  id   <- tibble(execucao = basename(dir),
                 programa = str_remove(nome, "_N\\d+$"),
                 n = as.integer(str_match(nome, "_N(\\d+)$")[, 2]),
                 cpu = m$cpu, l1d = par$l1d, l1i = par$l1i, l2 = par$l2,
                 clk = par$clk,
                 hash = m$hash, timestamp = m$timestamp)
  list(cont = cross_join(id, seg$cont), mix = cross_join(id, seg$mix))
}

# todas as execuções válidas -> list(dados, mix); mesmo hash = mesmo resultado
# (o gem5 é determinístico), então fica só a execução mais recente de cada
ler_tudo <- function(dirs, regioes) {
  execucoes <- map(dirs, ler_execucao)
  nomear <- function(df) df |>
    left_join(regioes, by = c("programa", "roi")) |>
    mutate(regiao = if_else(roi == 0, "programa inteiro",
                            coalesce(regiao, paste("ROI", roi))))
  dados <- list_rbind(map(execucoes, "cont")) |>
    group_by(hash) |> filter(timestamp == max(timestamp)) |> ungroup() |>
    nomear() |> derivar() |>
    mutate(cpu = factor(cpu, levels = CPUS),
           # camada densa: N³ multiplicações-acumulações por ROI
           ciclos_por_mac = if_else(programa == "camada_densa" & roi > 0,
                                    ciclos / n^3, NA_real_)) |>
    arrange(programa, n, roi, cpu)
  mix <- list_rbind(map(execucoes, "mix")) |>
    semi_join(dados, by = c("execucao", "roi")) |>
    nomear() |>
    mutate(cpu = factor(cpu, levels = CPUS), grupo = factor(grupo, levels = GRUPOS))
  list(dados = dados, mix = mix)
}

na_base <- function(df) df |>
  filter(l1d == BASE$l1d, l1i == BASE$l1i, l2 == BASE$l2, clk == BASE$clk)

# ---- config.ini ------------------------------------------------------------------

# config.ini(.gz) -> lista {seção: c(chave = valor)}
ler_config <- function(arquivo) {
  linhas <- readLines(arquivo, warn = FALSE)
  secao  <- str_match(linhas, "^\\[(.*)\\]$")[, 2]
  atual  <- zoo_locf(secao)
  kv     <- str_match(linhas, "^([^=\\[]+)=(.*)$")
  ok     <- !is.na(kv[, 1]) & !is.na(atual)
  split(setNames(kv[ok, 3], kv[ok, 2]), atual[ok])
}
zoo_locf <- function(x) {          # repete o último valor não-NA para a frente
  i <- cumsum(!is.na(x)); i[i == 0] <- NA; x[!is.na(x)][i]
}
cfg <- function(ini, secao, chave) {
  v <- ini[[secao]][chave]
  if (is.null(v) || is.na(v)) NA_character_ else unname(v)
}

# ---- O3PipeView ---------------------------------------------------------------------

# trace do O3PipeView (--debug-flags=O3PipeView) -> 1 linha por instrução
# confirmada, com o tick de cada estágio. Instruções descartadas (especulação
# errada) têm estágios zerados e ficam de fora.
ESTAGIOS <- c("fetch", "decode", "rename", "dispatch", "issue", "complete", "retire")
ler_pipeview <- function(arquivo) {
  l <- str_split_fixed(readLines(arquivo, warn = FALSE), ":", 7)
  l <- l[l[, 1] == "O3PipeView", , drop = FALSE]
  inicio <- which(l[, 2] == "fetch")
  map(inicio, function(i) {
    b <- l[i:(i + 6), , drop = FALSE]
    tibble(seq = as.integer(b[1, 6]), pc = b[1, 4], disasm = str_trim(b[1, 7]),
           estagio = b[, 2], tick = as.numeric(b[, 3]))
  }) |>
    list_rbind() |>
    group_by(seq) |> filter(all(tick > 0)) |> ungroup() |>
    mutate(estagio = factor(estagio, levels = ESTAGIOS))
}
