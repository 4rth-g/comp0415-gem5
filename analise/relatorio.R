#!/usr/bin/env Rscript
# relatorio.R — lê as simulações em resultados/ e gera tabelas e gráficos
# para o artigo.
#
# Uso (na raiz do repo):  Rscript analise/relatorio.R   (ou: make analise)
#
# Entrada: resultados/<execução>/{meta.json, stats.txt.gz} (gerados por simular.sh)
#          exemplos/regioes.csv (nome de cada ROI)
# Saída:   analise/saida/metricas.csv   1 linha por execução × segmento
#          analise/saida/mix.csv        mix de instruções por execução × segmento
#          analise/saida/tabela_*.docx  tabelas nativas do Word
#          analise/saida/fig_*.pdf|png  gráficos
#
# Segmentos: o se_run.py despeja e zera as estatísticas no início e no fim de
# cada região de interesse (ROI), então o stats.txt tem os dumps
#   [antes] [ROI 1] [entre] [ROI 2] ... [depois]
# Cada ROI vira uma linha; a soma de todos os dumps vira "programa inteiro".
# As taxas (IPC, taxas de falha...) são recalculadas a partir das contagens.
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(purrr); library(stringr)
  library(readr); library(ggplot2); library(jsonlite)
})

DIR_RES <- "resultados"
DIR_OUT <- "analise/saida"
CONFIG  <- "configs_local/se_run.py"
dir.create(DIR_OUT, recursive = TRUE, showWarnings = FALSE)

CPUS <- c("atomic", "timing", "minor", "o3")
BASE <- list(l1d = "32KiB", l1i = "32KiB", l2 = "256KiB", clk = "1GHz")

# ---- leitura do stats.txt ---------------------------------------------------
P <- "board.processor.cores.core."
C <- "board.cache_hierarchy."
CONTADORES <- c(
  instrucoes      = "simInsts",
  ticks           = "simTicks",
  ciclos          = paste0(P, "numCycles"),
  l1d_falhas      = paste0(C, "l1d-cache-0.overallMisses::total"),
  l1d_acessos     = paste0(C, "l1d-cache-0.overallAccesses::total"),
  l1i_falhas      = paste0(C, "l1i-cache-0.overallMisses::total"),
  l1i_acessos     = paste0(C, "l1i-cache-0.overallAccesses::total"),
  l2_falhas       = paste0(C, "l2-cache-0.overallMisses::total"),
  l2_acessos      = paste0(C, "l2-cache-0.overallAccesses::total"),
  desvios         = paste0(P, "branchPred.condPredicted"),   # só minor e o3
  desvios_errados = paste0(P, "branchPred.condIncorrect")
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

# ---- execuções válidas ------------------------------------------------------
# Válida = gerada pelas entradas ATUAIS: binário listado no bin/SHA256SUMS e
# se_run.py igual ao do repositório. Execuções antigas continuam em
# resultados/ (rastreáveis pelo meta.json), mas não entram na análise.
sha_bins <- read_table("bin/SHA256SUMS", col_names = c("sha", "arquivo"),
                       show_col_types = FALSE)$sha
sha_cfg  <- str_extract(system2("sha256sum", CONFIG, stdout = TRUE), "^\\S+")

metas <- list.files(DIR_RES, pattern = "^meta\\.json$", recursive = TRUE,
                    full.names = TRUE)
valida <- map_lgl(metas, function(arq) {
  m <- fromJSON(arq)
  !is.null(m$parametros) && m$binario_sha256 %in% sha_bins &&
    m$config_sha256 == sha_cfg
})
if (any(!valida))
  message("ignorando ", sum(!valida), " execução(ões) de entradas antigas ",
          "(binário ou se_run.py diferentes dos atuais)")
dirs <- dirname(metas[valida])
if (!length(dirs)) stop("nenhuma execução válida em ", DIR_RES, " — rode `make sim`")

regioes <- read_csv("exemplos/regioes.csv", show_col_types = FALSE)

ler_execucao <- function(dir) {
  m    <- fromJSON(file.path(dir, "meta.json"))
  nome <- str_remove(basename(m$binario), "_riscv$")
  seg  <- segmentar(ler_dumps(file.path(dir, "stats.txt.gz")))
  id   <- tibble(execucao = basename(dir),
                 programa = str_remove(nome, "_N\\d+$"),
                 n = as.integer(str_match(nome, "_N(\\d+)$")[, 2]),
                 cpu = m$cpu, l1d = m$parametros$l1d, l1i = m$parametros$l1i,
                 l2 = m$parametros$l2, clk = m$parametros$clk,
                 hash = m$hash, timestamp = m$timestamp)
  list(cont = cross_join(id, seg$cont), mix = cross_join(id, seg$mix))
}

execucoes <- map(dirs, ler_execucao)
nomear <- function(df) df |>
  left_join(regioes, by = c("programa", "roi")) |>
  mutate(regiao = if_else(roi == 0, "programa inteiro",
                          coalesce(regiao, paste("ROI", roi))))

# gem5 é determinístico: execuções com o mesmo hash são idênticas -> fica a
# mais recente de cada
dados <- list_rbind(map(execucoes, "cont")) |>
  group_by(hash) |> filter(timestamp == max(timestamp)) |> ungroup() |>
  nomear() |>
  mutate(cpu = factor(cpu, levels = CPUS),
         ipc            = instrucoes / ciclos,
         cpi            = ciclos / instrucoes,
         mpki_l1d       = 1000 * l1d_falhas / instrucoes,
         taxa_falha_l1d = l1d_falhas / l1d_acessos,
         taxa_falha_l2  = l2_falhas / l2_acessos,
         erro_predicao  = desvios_errados / desvios) |>
  arrange(programa, n, roi, cpu)
mix <- list_rbind(map(execucoes, "mix")) |>
  semi_join(dados, by = c("execucao", "roi")) |>
  nomear() |>
  mutate(cpu = factor(cpu, levels = CPUS), grupo = factor(grupo, levels = GRUPOS))

write_csv(dados, file.path(DIR_OUT, "metricas.csv"))
write_csv(mix, file.path(DIR_OUT, "mix.csv"))

# configuração-base (sem as variações de cache/clock)
base <- dados |> filter(l1d == BASE$l1d, l1i == BASE$l1i, l2 == BASE$l2, clk == BASE$clk)
# visão geral: da camada densa, só o tamanho N = 64
geral <- base |> filter(is.na(n) | n == 64) |>
  mutate(rotulo = if_else(is.na(n), programa, paste0(programa, " (N=", n, ")")))
rois  <- geral |> filter(roi > 0) |>
  mutate(rotulo_roi = paste0(rotulo, ": ", regiao),
         rotulo_roi = factor(rotulo_roi, levels = unique(rotulo_roi)))

# ---- estilo dos gráficos ------------------------------------------------------
# paleta categórica de referência (skill dataviz), validada para daltonismo;
# a cor segue a entidade (CPU sempre com a mesma cor em todas as figuras)
PALETA <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4")
CORES_CPU <- setNames(PALETA[1:4], CPUS)
TINTA <- "#0b0b0b"; TINTA2 <- "#52514e"; GRADE <- "#e4e3df"

num <- function(acc = 1) scales::label_number(accuracy = acc, big.mark = ".",
                                              decimal.mark = ",")
pct <- function(acc = 0.1) scales::label_percent(accuracy = acc, big.mark = ".",
                                                 decimal.mark = ",")
tema <- theme_minimal(base_size = 10) +
  theme(text = element_text(colour = TINTA),
        axis.text = element_text(colour = TINTA2),
        panel.grid.major = element_line(colour = GRADE, linewidth = 0.3),
        panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold", hjust = 0),
        plot.title.position = "plot",
        legend.position = "top", legend.justification = "left")

salvar <- function(g, nome, w = 6.5, h = 4) {
  for (ext in c("pdf", "png"))
    ggsave(file.path(DIR_OUT, paste0(nome, ".", ext)), g,
           width = w, height = h, dpi = 300, bg = "white")
}

# 1) programa inteiro × ROI: quanto do programa é o algoritmo -----------------
#    (instruções não dependem da CPU; usa o atomic)
d1 <- geral |> filter(cpu == "atomic") |>
  group_by(rotulo) |>
  summarise(`programa inteiro` = instrucoes[roi == 0],
            `só as ROIs` = sum(instrucoes[roi > 0]), .groups = "drop") |>
  pivot_longer(-rotulo, names_to = "medida", values_to = "instrucoes") |>
  mutate(rotulo = reorder(rotulo, instrucoes, max))
g1 <- ggplot(d1, aes(instrucoes, rotulo)) +
  geom_line(aes(group = rotulo), colour = GRADE, linewidth = 2) +
  geom_point(aes(colour = medida), size = 3) +
  geom_text(aes(label = num()(instrucoes), colour = medida,
                hjust = if_else(medida == "programa inteiro", -0.25, 1.25)),
            size = 2.6, show.legend = FALSE) +
  scale_x_log10(labels = num(), expand = expansion(mult = 0.15)) +
  scale_colour_manual(values = c(`programa inteiro` = PALETA[2],
                                 `só as ROIs` = PALETA[1]), name = NULL) +
  labs(x = "instruções simuladas (escala log)", y = NULL,
       title = "Instruções do programa inteiro × só das regiões de interesse") +
  tema
salvar(g1, "fig_instrucoes", h = 3.2)

# 2) IPC por modelo de CPU, em cada ROI ----------------------------------------
g2 <- ggplot(rois, aes(cpu, ipc, fill = cpu)) +
  geom_col(width = 0.75, colour = "white", linewidth = 0.4) +
  geom_text(aes(label = num(0.01)(ipc)), vjust = -0.4, size = 2.3, colour = TINTA2) +
  facet_wrap(~rotulo_roi, ncol = 4, labeller = label_wrap_gen(28)) +
  scale_fill_manual(values = CORES_CPU, guide = "none") +
  scale_y_continuous(labels = num(0.1), expand = expansion(mult = c(0, 0.18))) +
  labs(x = "modelo de CPU", y = "IPC (instruções por ciclo)",
       title = "IPC por modelo de CPU em cada região de interesse",
       caption = "atomic: modelo funcional; seus ciclos são aproximados, não cycle-accurate.") +
  tema + theme(panel.grid.major.x = element_blank(),
               strip.text = element_text(size = 7))
salvar(g2, "fig_ipc", h = 6.5)

# 3) mix de instruções por ROI (não depende da CPU; usa o atomic) --------------
d3 <- mix |> semi_join(rois |> filter(cpu == "atomic"), by = c("execucao", "roi")) |>
  left_join(rois |> distinct(execucao, roi, rotulo_roi), by = c("execucao", "roi")) |>
  group_by(rotulo_roi) |> mutate(frac = qtd / sum(qtd)) |> ungroup() |>
  mutate(rotulo_roi = factor(rotulo_roi, levels = rev(levels(rois$rotulo_roi))))
g3 <- ggplot(d3, aes(frac, rotulo_roi, fill = grupo)) +
  geom_col(width = 0.7, colour = "white", linewidth = 0.5) +
  geom_text(aes(label = if_else(frac >= 0.08, pct(1)(frac), "")),
            position = position_stack(vjust = 0.5), size = 2.3, colour = "white") +
  scale_fill_manual(values = setNames(PALETA, GRUPOS), name = NULL) +
  scale_x_continuous(labels = pct(1), expand = expansion(mult = 0)) +
  labs(x = "fração das instruções executadas", y = NULL,
       title = "Mix de instruções por região de interesse") +
  guides(fill = guide_legend(nrow = 1)) +
  tema + theme(panel.grid.major.y = element_blank())
salvar(g3, "fig_mix", h = 4.2)

# 4) erro de predição de desvios (CPUs com preditor) ---------------------------
d4 <- rois |> filter(cpu %in% c("minor", "o3"), desvios > 0) |>
  mutate(rotulo_roi = factor(rotulo_roi, levels = rev(levels(rotulo_roi))))
g4 <- ggplot(d4, aes(erro_predicao, rotulo_roi, fill = cpu)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75,
           colour = "white", linewidth = 0.4) +
  geom_text(aes(label = pct()(erro_predicao)), position = position_dodge(width = 0.8),
            hjust = -0.15, size = 2.3, colour = TINTA2) +
  scale_fill_manual(values = CORES_CPU, name = NULL) +
  scale_x_continuous(labels = pct(1), expand = expansion(mult = c(0, 0.15))) +
  labs(x = "desvios condicionais com predição errada", y = NULL,
       title = "Erro de predição de desvios por região de interesse") +
  tema + theme(panel.grid.major.y = element_blank())
salvar(g4, "fig_predicao", h = 4.6)

# 5) camada densa: efeito do tamanho N (CPU o3) --------------------------------
metricas_mem <- c(ipc = "IPC", mpki_l1d = "falhas na L1D por mil instruções")
linhas_mem <- function(d, x, rotulo_x, escala_x) {
  dl <- d |> pivot_longer(all_of(names(metricas_mem)), names_to = "metrica") |>
    mutate(metrica = factor(metricas_mem[metrica], levels = metricas_mem))
  ultimo <- dl |> group_by(metrica, regiao) |> filter({{ x }} == max({{ x }}))
  ggplot(dl, aes({{ x }}, value, colour = regiao)) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 2.2) +
    geom_text(data = ultimo, aes(label = regiao), hjust = -0.15, size = 2.6,
              show.legend = FALSE) +
    facet_wrap(~metrica, scales = "free_y") +
    escala_x +
    scale_y_continuous(labels = num(0.1), limits = c(0, NA)) +
    scale_colour_manual(values = c(`ordem i-j-k` = PALETA[2],
                                   `ordem i-k-j` = PALETA[1]), name = NULL) +
    labs(x = rotulo_x, y = NULL) + tema
}
d5 <- base |> filter(programa == "camada_densa", cpu == "o3", roi > 0)
g5 <- linhas_mem(d5, n, "N (matrizes N×N de double)",
                 scale_x_continuous(trans = "log2", breaks = c(16, 32, 64, 128),
                                    expand = expansion(mult = c(0.05, 0.3)))) +
  labs(title = "Camada densa: mesma conta, duas ordens de laço (CPU o3)",
       subtitle = "L1D = 32 KiB: com N = 32 as três matrizes ainda cabem; com N = 64 já não")
salvar(g5, "fig_camada_n", h = 3.4)

# 6) camada densa N=64: varredura do tamanho da L1D (CPU o3) -------------------
d6 <- dados |> filter(programa == "camada_densa", n == 64, cpu == "o3", roi > 0,
                      l1i == BASE$l1i, l2 == BASE$l2, clk == BASE$clk) |>
  mutate(l1d_kib = as.numeric(str_remove(l1d, "KiB")))
if (n_distinct(d6$l1d_kib) > 1) {
  g6 <- linhas_mem(d6, l1d_kib, "tamanho da L1D (KiB)",
                   scale_x_continuous(trans = "log2", breaks = unique(d6$l1d_kib),
                                      expand = expansion(mult = c(0.05, 0.3)))) +
    labs(title = "Camada densa (N = 64): variando o tamanho da L1D (CPU o3)")
  salvar(g6, "fig_varredura_l1d", h = 3.4)
} else message("sem varredura de L1D em resultados/ (rode `make varredura`)")

# ---- tabelas para o Word ----------------------------------------------------
if (requireNamespace("flextable", quietly = TRUE)) {
  library(flextable)
  fmt_pct <- function(x) ifelse(is.na(x), "—", pct()(x))

  # ROIs na CPU o3
  rois |> filter(cpu == "o3") |>
    transmute(Programa = rotulo, `Região` = regiao, `Instruções` = instrucoes,
              Ciclos = ciclos, IPC = ipc, `Falhas L1D/mil instr.` = mpki_l1d,
              `Erro de predição` = erro_predicao) |>
    flextable() |>
    colformat_double(j = c("Instruções", "Ciclos"), digits = 0, big.mark = ".",
                     decimal.mark = ",") |>
    colformat_double(j = c("IPC", "Falhas L1D/mil instr."), digits = 2,
                     big.mark = ".", decimal.mark = ",") |>
    set_formatter(`Erro de predição` = fmt_pct) |>
    merge_v(j = "Programa") |> theme_booktabs() |> autofit() |>
    save_as_docx(path = file.path(DIR_OUT, "tabela_rois_o3.docx"))

  # IPC de cada ROI nos quatro modelos de CPU
  rois |> select(Programa = rotulo, `Região` = regiao, cpu, ipc) |>
    pivot_wider(names_from = cpu, values_from = ipc) |>
    flextable() |>
    colformat_double(j = CPUS, digits = 2, decimal.mark = ",") |>
    add_header_row(values = c("", "IPC por modelo de CPU"), colwidths = c(2, 4)) |>
    merge_v(j = "Programa") |> theme_booktabs() |> autofit() |>
    save_as_docx(path = file.path(DIR_OUT, "tabela_ipc_cpus.docx"))
} else {
  message("flextable não instalado: pulando tabelas .docx")
}

message("OK: ", n_distinct(dados$execucao), " execuções, ", nrow(dados),
        " segmentos -> ", DIR_OUT)
