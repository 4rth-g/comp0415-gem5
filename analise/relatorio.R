#!/usr/bin/env Rscript
# relatorio.R — lê todas as simulações em resultados/ e gera tabelas e gráficos
# para o artigo.
#
# Uso (na raiz do repo):  Rscript analise/relatorio.R
#
# Entrada: resultados/<execução>/stats.txt.gz + meta.json (gerados por simular.sh;
#          execução sem meta.json não terminou com sucesso e é ignorada)
# Saída:   analise/saida/metricas.csv      (formato tidy: 1 linha por execução)
#          analise/saida/tabela_*.docx     (tabelas nativas do Word)
#          analise/saida/fig_*.pdf|png     (gráficos)
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(purrr); library(stringr)
  library(readr); library(ggplot2); library(jsonlite)
})

DIR_RES <- "resultados"
DIR_OUT <- "analise/saida"
dir.create(DIR_OUT, recursive = TRUE, showWarnings = FALSE)

CPUS <- c("atomic", "timing", "minor", "o3")

# stats.txt -> vetor nomeado {estatística: valor}. Só linhas escalares;
# com vários dumps, vale a última ocorrência.
ler_stats <- function(arquivo) {
  linhas <- readLines(arquivo, warn = FALSE)
  linhas <- linhas[nzchar(trimws(linhas)) & !startsWith(linhas, "-")]
  partes <- str_split_fixed(str_squish(linhas), " ", 3)
  valor  <- suppressWarnings(as.numeric(partes[, 2]))
  ok     <- !is.na(valor)
  v      <- setNames(valor[ok], partes[ok, 1])
  v[!duplicated(names(v), fromLast = TRUE)]
}

# Primeira estatística cujo nome casa com o regex (NA se nenhuma).
pegar <- function(s, padrao) {
  i <- str_which(names(s), padrao)
  if (length(i)) unname(s[i[1]]) else NA_real_
}

# Uma execução -> uma linha.
ler_execucao <- function(dir) {
  arq  <- list.files(dir, pattern = "^stats\\.txt(\\.gz)?$", full.names = TRUE)[1]
  s    <- ler_stats(arq)   # readLines descomprime .gz sozinho
  m    <- fromJSON(file.path(dir, "meta.json"))
  par  <- m$parametros
  tibble(
    execucao        = basename(dir),
    programa        = str_remove(basename(m$binario), "_riscv$"),
    cpu             = m$cpu,
    l1d = par$l1d, l1i = par$l1i, l2 = par$l2, clk = par$clk,
    hash            = m$hash,
    timestamp       = m$timestamp,
    instrucoes      = pegar(s, "^simInsts$"),
    ciclos          = pegar(s, "\\.numCycles$"),
    ipc             = pegar(s, "\\.core\\.ipc$"),
    cpi             = pegar(s, "\\.core\\.cpi$"),
    tempo_simulado  = pegar(s, "^simSeconds$"),
    tempo_host      = pegar(s, "^hostSeconds$"),
    miss_l1d        = pegar(s, "l1d.*overallMissRate::total$"),
    miss_l1i        = pegar(s, "l1i.*overallMissRate::total$"),
    miss_l2         = pegar(s, "l2.*overallMissRate::total$"),
    # erro de predição só existe em CPUs com preditor (minor, o3)
    erro_predicao   = pegar(s, "branchPred\\.condIncorrect$") /
                      pegar(s, "branchPred\\.condPredicted$")
  )
}

dirs <- dirname(list.files(DIR_RES, pattern = "^meta\\.json$",
                           recursive = TRUE, full.names = TRUE))
# execuções do formato antigo (antes de simular.sh gravar "parametros" e
# comprimir o stats.txt) não são comparáveis com as atuais: ficam de fora
atual <- map_lgl(dirs, \(d) !is.null(fromJSON(file.path(d, "meta.json"))$parametros))
if (any(!atual))
  message("ignorando ", sum(!atual), " execução(ões) no formato antigo: ",
          paste(basename(dirs[!atual]), collapse = ", "))
dirs <- dirs[atual]
if (!length(dirs)) stop("nenhuma execução (meta.json) em ", DIR_RES)

# gem5 é determinístico: execuções com o mesmo hash são idênticas,
# então fica só a mais recente de cada.
dados <- map(dirs, ler_execucao) |>
  list_rbind() |>
  arrange(desc(timestamp)) |>
  distinct(hash, .keep_all = TRUE) |>
  mutate(cpu = factor(cpu, levels = CPUS)) |>
  arrange(programa, cpu)

write_csv(dados, file.path(DIR_OUT, "metricas.csv"))

# ---- gráficos ---------------------------------------------------------------
tema <- theme_minimal(base_size = 11) +
  theme(panel.grid.major.x = element_blank(), legend.position = "none")
cores_cpu <- c(atomic = "#9aa5b1", timing = "#5b8def",
               minor = "#f0a830", o3 = "#2bb673")

salvar <- function(g, nome, w = 6, h = 3.5) {
  for (ext in c("pdf", "png"))
    ggsave(file.path(DIR_OUT, paste0(nome, ".", ext)), g,
           width = w, height = h, dpi = 300)
}

g_ipc <- ggplot(dados, aes(cpu, ipc, fill = cpu)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = scales::number(ipc, accuracy = 0.01)),
            vjust = -0.4, size = 3) +
  facet_wrap(~programa) +
  scale_fill_manual(values = cores_cpu) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = "Modelo de CPU", y = "IPC (instruções por ciclo)",
       title = "Mesmo programa, microarquiteturas diferentes") +
  tema
salvar(g_ipc, "fig_ipc")

g_ciclos <- ggplot(dados, aes(cpu, ciclos, fill = cpu)) +
  geom_col(width = 0.7) +
  facet_wrap(~programa, scales = "free_y") +
  scale_fill_manual(values = cores_cpu) +
  scale_y_continuous(labels = scales::label_number(scale_cut = scales::cut_si("")),
                     expand = expansion(mult = c(0, 0.05))) +
  labs(x = "Modelo de CPU", y = "Ciclos") +
  tema
salvar(g_ciclos, "fig_ciclos")

# ---- tabela para o Word -----------------------------------------------------
if (requireNamespace("flextable", quietly = TRUE)) {
  library(flextable)
  pct <- function(x) ifelse(is.na(x), "—",
                            scales::percent(x, accuracy = 0.1, decimal.mark = ","))
  tab <- dados |>
    transmute(Programa = programa, CPU = as.character(cpu),
              `Instruções` = instrucoes, Ciclos = ciclos,
              IPC = ipc, CPI = cpi,
              `Miss L1D` = miss_l1d, `Erro de predição` = erro_predicao) |>
    flextable() |>
    colformat_num(j = c("Instruções", "Ciclos"), big.mark = ".",
                  decimal.mark = ",", digits = 0) |>
    colformat_double(j = c("IPC", "CPI"), digits = 2, big.mark = ".", decimal.mark = ",") |>
    set_formatter(`Miss L1D` = pct, `Erro de predição` = pct) |>
    merge_v(j = "Programa") |>
    theme_booktabs() |>
    autofit()
  save_as_docx(tab, path = file.path(DIR_OUT, "tabela_metricas.docx"))
} else {
  message("flextable não instalado: pulando tabela .docx")
}

message("OK: ", nrow(dados), " execuções -> ", DIR_OUT)
