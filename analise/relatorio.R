#!/usr/bin/env Rscript
# relatorio.R — lê as simulações em resultados/ e gera tabelas e gráficos
# para o artigo.
#
# Uso (na raiz do repo):  Rscript analise/relatorio.R   (ou: make analise)
#
# Entrada: resultados/<execução>/{meta.json, stats.txt.gz, config.ini.gz}
#          exemplos/regioes.csv (nome de cada ROI)
#          analise/saida/visual/*/gem5_o3/o3pipeview.txt (opcional, make visual)
# Saída:   analise/saida/metricas.csv, mix.csv, configuracao.csv
#          analise/saida/tabela_*.docx  tabelas nativas do Word
#          analise/saida/fig_*.pdf|png  gráficos
#          analise/saida/sistema.dot    diagrama do sistema (o Makefile renderiza)
suppressPackageStartupMessages(library(ggplot2))
source("analise/funcoes.R")

DIR_OUT <- "analise/saida"
dir.create(DIR_OUT, recursive = TRUE, showWarnings = FALSE)
# saídas são regeneráveis: apaga as da rodada anterior (inclusive de figuras
# que deixaram de existir)
unlink(list.files(DIR_OUT, "^(fig|tabela)_.*\\.(pdf|png|docx)$", full.names = TRUE))

dirs <- execucoes_validas()
if (!length(dirs)) stop("nenhuma execução válida em resultados/ — rode `make sim`")
lido  <- ler_tudo(dirs, read_csv("exemplos/regioes.csv", show_col_types = FALSE))
dados <- lido$dados
mix   <- lido$mix
write_csv(dados, file.path(DIR_OUT, "metricas.csv"))
write_csv(mix, file.path(DIR_OUT, "mix.csv"))

# ordem dos programas nas figuras = ordem do artigo: clássicos, matrizes,
# redes neurais
ORDEM <- c("soma_vetor", "ordenacao", "busca_binaria", "grafo", "fibonacci",
           "fatorial", "mdc", "camada_densa", "regressao_linear", "perceptron",
           "mlp_xor")
NOMES <- c(soma_vetor = "soma de vetor", ordenacao = "ordenação",
           busca_binaria = "busca", grafo = "busca em grafo", fibonacci = "Fibonacci",
           fatorial = "fatorial", mdc = "MDC", camada_densa = "matrizes",
           regressao_linear = "regressão linear", perceptron = "perceptron",
           mlp_xor = "rede neural (XOR)")
base  <- na_base(dados) |> arrange(match(programa, ORDEM), n, roi, cpu)
# visão geral: da camada densa, só o tamanho N = 64
geral <- base |> filter(is.na(n) | n == 64) |>
  mutate(rotulo = if_else(is.na(n), NOMES[programa], paste0(NOMES[programa], " (N=", n, ")")))
rois  <- geral |> filter(roi > 0) |> arrange(match(programa, ORDEM), roi, cpu) |>
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
  mutate(rotulo = factor(rotulo, levels = rev(unique(geral$rotulo))))
g1 <- ggplot(d1, aes(instrucoes, rotulo)) +
  geom_line(aes(group = rotulo), colour = GRADE, linewidth = 2) +
  geom_point(aes(colour = medida), size = 3) +
  geom_text(aes(label = num()(instrucoes), colour = medida,
                hjust = if_else(medida == "programa inteiro", -0.25, 1.25)),
            size = 2.6, show.legend = FALSE) +
  scale_x_log10(labels = num(), expand = expansion(mult = c(0.15, 0.3))) +
  scale_colour_manual(values = c(`programa inteiro` = PALETA[2],
                                 `só as ROIs` = PALETA[1]), name = NULL) +
  labs(x = "instruções simuladas (escala log)", y = NULL,
       title = "Instruções do programa inteiro × só das regiões de interesse") +
  tema
salvar(g1, "fig_instrucoes", h = 0.24 * n_distinct(d1$rotulo) + 1)

# 2) IPC de cada ROI em cada modelo de CPU: mapa de calor --------------------
#    sem o atomic: é um modelo funcional, seus "ciclos" não medem tempo
d2 <- rois |> filter(cpu != "atomic", regiao != "ROI vazia") |> droplevels() |>
  mutate(rotulo_roi = factor(rotulo_roi, levels = rev(levels(rotulo_roi))))
g2 <- ggplot(d2, aes(cpu, rotulo_roi, fill = ipc)) +
  geom_tile(colour = "white", linewidth = 1.2) +
  geom_text(aes(label = num(0.01)(ipc), colour = ipc > 2.6), size = 3) +
  scale_fill_gradient(low = "#cde2fb", high = "#104281", name = "IPC",
                      labels = num(0.1)) +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = TINTA), guide = "none") +
  scale_x_discrete(position = "top", expand = c(0, 0)) +
  scale_y_discrete(expand = c(0, 0)) +
  labs(x = NULL, y = NULL,
       title = "IPC (instruções por ciclo) de cada região de interesse",
       caption = "Mesmas instruções em todas as colunas: muda só a microarquitetura simulada.") +
  tema + theme(panel.grid = element_blank(), legend.position = "right",
               axis.text.x = element_text(size = 10, face = "bold", colour = TINTA))
salvar(g2, "fig_ipc", w = 6.5, h = 0.22 * n_distinct(d2$rotulo_roi) + 1.2)

# 3) mix de instruções por ROI (não depende da CPU; usa o atomic) --------------
d3 <- mix |> semi_join(rois |> filter(cpu == "atomic", regiao != "ROI vazia"),
                       by = c("execucao", "roi")) |>
  left_join(rois |> distinct(execucao, roi, rotulo_roi), by = c("execucao", "roi")) |>
  group_by(rotulo_roi) |> mutate(frac = qtd / sum(qtd)) |> ungroup() |>
  mutate(rotulo_roi = factor(rotulo_roi, levels = rev(levels(rois$rotulo_roi))))
g3 <- ggplot(d3, aes(frac, rotulo_roi, fill = grupo)) +
  geom_col(width = 0.7, colour = "white", linewidth = 0.5,
           position = position_stack(reverse = TRUE)) +
  geom_text(aes(label = if_else(frac >= 0.08, pct(1)(frac), "")),
            position = position_stack(vjust = 0.5, reverse = TRUE),
            size = 2.3, colour = "white") +
  scale_fill_manual(values = setNames(PALETA, GRUPOS), name = NULL) +
  scale_x_continuous(labels = pct(1), expand = expansion(mult = c(0, 0.03))) +
  labs(x = "fração das instruções executadas", y = NULL,
       title = "Mix de instruções por região de interesse") +
  guides(fill = guide_legend(nrow = 2)) +
  tema + theme(panel.grid.major.y = element_blank())
salvar(g3, "fig_mix", h = 0.2 * n_distinct(d3$rotulo_roi) + 1.3)

# 4) erro de predição de desvios (CPUs com preditor) ---------------------------
d4 <- rois |> filter(cpu %in% c("minor", "o3"), desvios > 0, regiao != "ROI vazia") |>
  mutate(rotulo_roi = factor(rotulo_roi, levels = rev(levels(rotulo_roi))))
g4 <- ggplot(d4, aes(erro_predicao, rotulo_roi, fill = cpu,
                     group = factor(cpu, levels = rev(CPUS)))) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75,
           colour = "white", linewidth = 0.4) +
  geom_text(aes(label = pct()(erro_predicao)), position = position_dodge(width = 0.8),
            hjust = -0.15, size = 2.3, colour = TINTA2) +
  scale_fill_manual(values = CORES_CPU, name = NULL) +
  scale_x_continuous(labels = pct(1), expand = expansion(mult = c(0, 0.15))) +
  labs(x = "desvios condicionais com predição errada", y = NULL,
       title = "Erro de predição de desvios por região de interesse") +
  tema + theme(panel.grid.major.y = element_blank())
salvar(g4, "fig_predicao", h = 0.3 * n_distinct(d4$rotulo_roi) + 1)

# 5–6) camada densa: tamanho N e tamanho da L1D (CPU o3) ----------------------
# IPC engana aqui: as duas ordens executam números diferentes de instruções
# para a mesma conta. Ciclos por multiplicação-acumulação compara o custo real.
linhas <- function(d, x, metricas, rotulo_x, escala_x) {
  dl <- d |> pivot_longer(all_of(names(metricas)), names_to = "metrica") |>
    mutate(metrica = factor(metricas[metrica], levels = metricas))
  ggplot(dl, aes({{ x }}, value, colour = regiao)) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 2.2) +
    facet_wrap(~metrica, scales = "free_y", nrow = 1) +
    escala_x +
    scale_y_continuous(labels = scales::label_number(big.mark = ".", decimal.mark = ","),
                       limits = c(0, NA)) +
    scale_colour_manual(values = c(`ordem i-j-k` = PALETA[2], `ordem i-k-j` = PALETA[1],
                                   `ordem i-k-j (4 k por vez)` = PALETA[3]), name = NULL) +
    labs(x = rotulo_x, y = NULL) + tema
}
log2_x <- function(br) scale_x_continuous(trans = "log2", breaks = br,
                                          expand = expansion(mult = 0.06))
MEM <- c(ciclos_por_mac = "ciclos por multiplicação-acumulação",
         mpki_l1d = "falhas na L1D por mil instruções",
         retidas_por_mac = "cargas retidas por mult.-acumulação")

por_mac <- function(d) mutate(d, retidas_por_mac = cargas_retidas / n^3)
d5 <- base |> filter(programa == "camada_densa", cpu == "o3", roi > 0) |> por_mac()
salvar(linhas(d5, n, MEM, "N (matrizes N×N de double)", log2_x(c(16, 32, 64, 128))) +
         labs(title = "Multiplicação de matrizes: mesma conta, três ordens de laço (CPU o3)",
              subtitle = paste("L1D = 32 KiB: com N = 32 as três matrizes cabem; com N = 64 já não.",
                               "Na i-k-j, o o3 retém cada leitura de Y até a escrita anterior terminar.",
                               sep = "\n")),
       "fig_camada_n", w = 7.5, h = 3.5)

d6 <- dados |> filter(programa == "camada_densa", n == 64, cpu == "o3", roi > 0,
                      l1i == BASE$l1i, l2 == BASE$l2, clk == BASE$clk) |>
  mutate(l1d_kib = as.numeric(str_remove(l1d, "KiB"))) |> por_mac()
if (n_distinct(d6$l1d_kib) > 1) {
  salvar(linhas(d6, l1d_kib, MEM, "tamanho da L1D (KiB)", log2_x(unique(d6$l1d_kib))) +
           labs(title = "Multiplicação de matrizes (N = 64): variando o tamanho da L1D (CPU o3)"),
         "fig_varredura_l1d", w = 7.5, h = 3.3)
} else message("sem varredura de L1D (rode `make varredura`)")

# 8) pipeline do o3, instrução por instrução (make visual) ----------------------
FASES <- c("busca", "decodificação e renomeação", "fila de emissão",
           "execução", "espera p/ confirmar")
for (trace in Sys.glob("analise/saida/visual/*/gem5_o3/o3pipeview.txt")) {
  caso <- basename(dirname(dirname(trace)))           # ex.: soma_vetor_roi2
  pv <- ler_pipeview(trace)
  if (!nrow(pv)) next
  t <- pv |> pivot_wider(names_from = estagio, values_from = tick) |> arrange(seq)
  # regime permanente: pula o marcador de ROI e a 1ª volta do laço
  t <- t |> filter(!str_detect(disasm, "M5Op")) |> slice(9:24)
  ciclo0 <- min(t$fetch)
  fase <- function(de, ate, nome) t |>
    transmute(seq, disasm, inicio = ({{ de }} - ciclo0) / 1000,
              fim = ({{ ate }} - ciclo0) / 1000, fase = nome)
  seg <- bind_rows(fase(fetch, decode, FASES[1]), fase(decode, dispatch, FASES[2]),
                   fase(dispatch, issue, FASES[3]), fase(issue, complete, FASES[4]),
                   fase(complete, retire, FASES[5])) |>
    mutate(fase = factor(fase, levels = FASES),
           instr = factor(paste0(seq, "  ", disasm), levels = rev(paste0(t$seq, "  ", t$disasm))))
  g8 <- ggplot(seg, aes(y = instr)) +
    geom_linerange(aes(xmin = inicio, xmax = fim, colour = fase), linewidth = 3.2) +
    geom_point(data = t |> mutate(instr = factor(paste0(seq, "  ", disasm), levels = levels(seg$instr))),
               aes(x = (retire - ciclo0) / 1000), shape = 21, fill = "white",
               colour = TINTA, size = 1.6) +
    scale_colour_manual(values = setNames(PALETA, FASES), name = NULL) +
    scale_x_continuous(breaks = scales::breaks_width(2), expand = expansion(mult = 0.02)) +
    labs(x = "ciclo", y = NULL,
         title = paste0("Pipeline do o3, instrução por instrução (", str_replace(caso, "_roi", ", ROI "), ")"),
         caption = "Cada linha é uma instrução confirmada, na ordem de busca; o círculo marca a confirmação (commit).") +
    guides(colour = guide_legend(nrow = 2)) +
    tema + theme(axis.text.y = element_text(family = "mono", size = 7),
                 legend.text = element_text(size = 8),
                 panel.grid.major.y = element_blank())
  salvar(g8, paste0("fig_pipeline_", caso), h = 4.2)
}

# 9) "captura de tela": a saída real do gem5 no terminal ----------------------
#    (o gem5 não tem interface gráfica; mostra a execução da soma no o3)
exec_soma <- base |> filter(programa == "soma_vetor", cpu == "o3", roi == 0) |> pull(execucao)
if (length(exec_soma)) {
  dir_s <- file.path("resultados", exec_soma[1])
  simout <- readLines(file.path(dir_s, "simout.txt"))
  simout <- simout[!str_detect(simout, "^(Redirecting|info: Standard input)") & nzchar(simout)]
  simout <- str_replace(simout, "^command line: .*", "command line: gem5.opt ... se_run.py bin/soma_vetor_riscv --cpu o3 ...")
  d <- ler_dumps(file.path(dir_s, "stats.txt.gz")) |> filter(dump == 4)   # ROI 2 (cache quente)
  mostrar <- c("simInsts", paste0(P, "numCycles"), paste0(P, "ipc"),
               paste0(C, "l1d-cache-0.overallMisses::total"),
               paste0(P, "branchPred.condIncorrect"))
  st <- d |> filter(nome %in% mostrar) |> arrange(match(nome, mostrar)) |>
    mutate(l = sprintf("%-58s %10s", str_remove(nome, "^board\\."), format(valor, big.mark = "", scientific = FALSE, drop0trailing = TRUE)))
  linhas <- c("$ ./simular.sh bin/soma_vetor_riscv o3", simout, "",
              "$ zcat resultados/soma_vetor_o3_*/stats.txt.gz   # ROI 2 (cache quente)",
              "---------- Begin Simulation Statistics ----------", st$l)
  n <- length(linhas)
  g9 <- ggplot() +
    annotate("text", x = 0, y = rev(seq_len(n)), label = linhas, hjust = 0, vjust = 0.5,
             family = "mono", size = 2.55,
             colour = if_else(str_starts(linhas, "\\$"), "#9ec5f4",
                              if_else(str_starts(linhas, ">>>|soma de"), "#f4c27a", "#e8e8e3"))) +
    scale_x_continuous(limits = c(0, 1), expand = c(0.02, 0)) +
    scale_y_continuous(limits = c(0.3, n + 0.7), expand = c(0, 0)) +
    theme_void() +
    theme(plot.background = element_rect(fill = "#1e1f22", colour = "#1e1f22"))
  salvar(g9, "fig_terminal", w = 6.5, h = 0.155 * n + 0.3)
}

# ---- configuração do sistema simulado -----------------------------------------
# lida do config.ini de uma execução de cada CPU (configuração-base)
ini_de <- function(c) {
  d <- base |> filter(cpu == c, roi == 0) |> slice(1)
  ler_config(file.path("resultados", d$execucao, "config.ini.gz"))
}
ini <- setNames(map(CPUS, ini_de), CPUS)
o3 <- ini$o3; mn <- ini$minor
k <- function(ini, s, c) cfg(ini, s, c)
kib <- function(b) paste0(as.numeric(b) / 1024, " KiB")
CORE <- "board.processor.cores.core"
cache_txt <- function(nome) {
  s <- paste0("board.cache_hierarchy.", nome, "-cache-0")
  sprintf("%s, %s vias, linha de 64 B; latência: tag %s + dados %s ciclo(s); %s MSHRs; prefetcher %s",
          kib(k(o3, s, "size")), k(o3, s, "assoc"), k(o3, s, "tag_latency"),
          k(o3, s, "data_latency"), k(o3, s, "mshrs"), k(o3, paste0(s, ".prefetcher"), "type"))
}
bp_txt <- function(ini) {
  s <- paste0(CORE, ".branchPred.conditionalBranchPred")
  sprintf("%s (local %s, global %s, escolha %s entradas)", k(ini, s, "type"),
          k(ini, s, "localPredictorSize"), k(ini, s, "globalPredictorSize"),
          k(ini, s, "choicePredictorSize"))
}
dram <- "board.memory.mem_ctrl.dram"
config <- tribble(
  ~Componente, ~`Parâmetro`, ~Valor,
  "Sistema", "ISA e modo", "RISC-V RV64GC, modo SE (syscall emulation), 1 núcleo",
  "Sistema", "Clock", paste0(1e6 / as.numeric(k(o3, "board.clk_domain", "clock")) / 1000, " GHz"),
  "Cache L1I", "Organização", cache_txt("l1i"),
  "Cache L1D", "Organização", cache_txt("l1d"),
  "Cache L2", "Organização", cache_txt("l2"),
  "Memória", "DRAM", sprintf("DDR3-1600, 1 canal, 1 GiB; tCK %s ns, tCL %s ns",
                             num(0.01)(as.numeric(k(o3, dram, "tCK")) / 1000),
                             num(0.01)(as.numeric(k(o3, dram, "tCL")) / 1000)),
  "atomic", "Execução", "1 instrução por vez; acesso à memória instantâneo (latência só estimada)",
  "timing", "Execução", "1 instrução por vez; espera cada acesso à memória terminar",
  "minor", "Pipeline", sprintf("em ordem; decodifica %s, emite %s, confirma %s instruções/ciclo; %s acesso(s) à memória/ciclo",
                               k(mn, CORE, "decodeInputWidth"), k(mn, CORE, "executeIssueLimit"),
                               k(mn, CORE, "executeCommitLimit"), k(mn, CORE, "executeMemoryIssueLimit")),
  "minor", "Preditor de desvios", bp_txt(mn),
  "o3", "Pipeline", sprintf("fora de ordem; largura %s (busca, decodificação, renomeação, emissão, confirmação)",
                            k(o3, CORE, "fetchWidth")),
  "o3", "Janela", sprintf("ROB %s; fila de cargas %s, de escritas %s; %s registradores físicos inteiros e %s de ponto flutuante",
                          k(o3, CORE, "numROBEntries"), k(o3, CORE, "LQEntries"), k(o3, CORE, "SQEntries"),
                          k(o3, CORE, "numPhysIntRegs"), k(o3, CORE, "numPhysFloatRegs")),
  "o3", "Preditor de desvios", bp_txt(o3),
  "o3", "Dependência de memória", sprintf("store sets (SSIT %s, LFST %s), zerado a cada %s acessos à memória",
                                          k(o3, CORE, "SSITSize"), k(o3, CORE, "LFSTSize"),
                                          num()(as.numeric(k(o3, CORE, "store_set_clear_period"))))
)
write_csv(config, file.path(DIR_OUT, "configuracao.csv"))

# diagrama do sistema (Graphviz), com os mesmos valores da tabela
c_lbl <- function(nome, s) sprintf("%s\\n%s · %s vias", nome, kib(k(o3, s, "size")), k(o3, s, "assoc"))
writeLines(c(
  "digraph sistema {",
  "  graph [rankdir=TB, fontname=\"Helvetica\", nodesep=0.5, ranksep=0.45];",
  "  node  [shape=box, style=\"rounded,filled\", fontname=\"Helvetica\", fontsize=11, color=\"#52514e\", fillcolor=\"#f4f3ef\"];",
  "  edge  [color=\"#52514e\", arrowsize=0.7, dir=both];",
  sprintf("  cpu [label=\"CPU RISC-V (RV64GC), %s GHz\\natomic · timing · minor · o3\", fillcolor=\"#dbe8f8\"];",
          1e6 / as.numeric(k(o3, "board.clk_domain", "clock")) / 1000),
  sprintf("  l1i [label=\"%s\"];", c_lbl("L1 de instruções", "board.cache_hierarchy.l1i-cache-0")),
  sprintf("  l1d [label=\"%s\"];", c_lbl("L1 de dados", "board.cache_hierarchy.l1d-cache-0")),
  "  l2bus [label=\"barramento L2\", shape=box, style=filled, fillcolor=\"#e4e3df\", height=0.25, fontsize=9];",
  sprintf("  l2 [label=\"%s\"];", c_lbl("L2 (privada)", "board.cache_hierarchy.l2-cache-0")),
  "  membus [label=\"barramento de memória\", shape=box, style=filled, fillcolor=\"#e4e3df\", height=0.25, fontsize=9];",
  "  dram [label=\"DRAM DDR3-1600\\n1 canal · 1 GiB\", fillcolor=\"#fbe3d6\"];",
  "  { rank=same; l1i; l1d; }",
  "  cpu -> l1i; cpu -> l1d; l1i -> l2bus; l1d -> l2bus; l2bus -> l2; l2 -> membus; membus -> dram;",
  "}"), file.path(DIR_OUT, "sistema.dot"))

# ---- tabelas para o Word ----------------------------------------------------
if (requireNamespace("flextable", quietly = TRUE)) {
  suppressPackageStartupMessages(library(flextable))
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

  # IPC de cada ROI nos modelos de CPU com temporização
  rois |> filter(cpu != "atomic", regiao != "ROI vazia") |>
    select(Programa = rotulo, `Região` = regiao, cpu, ipc) |>
    pivot_wider(names_from = cpu, values_from = ipc) |>
    flextable() |>
    colformat_double(j = c("timing", "minor", "o3"), digits = 2, big.mark = ".",
                     decimal.mark = ",") |>
    add_header_row(values = c("", "IPC por modelo de CPU"), colwidths = c(2, 3)) |>
    merge_v(j = "Programa") |> theme_booktabs() |> autofit() |>
    save_as_docx(path = file.path(DIR_OUT, "tabela_ipc_cpus.docx"))

  # custo da marcação de ROI (ROI vazia) por modelo de CPU
  rois |> filter(regiao == "ROI vazia") |>
    transmute(CPU = as.character(cpu), `Instruções` = instrucoes, Ciclos = ciclos) |>
    flextable() |>
    colformat_double(j = c("Instruções", "Ciclos"), digits = 0, big.mark = ".",
                     decimal.mark = ",") |>
    theme_booktabs() |> autofit() |>
    save_as_docx(path = file.path(DIR_OUT, "tabela_custo_roi.docx"))

  # configuração do sistema simulado
  config |> flextable() |> merge_v(j = "Componente") |> theme_booktabs() |>
    width(j = 3, width = 4.2) |>
    save_as_docx(path = file.path(DIR_OUT, "tabela_configuracao.docx"))
} else {
  message("flextable não instalado: pulando tabelas .docx")
}

message("OK: ", n_distinct(dados$execucao), " execuções, ", nrow(dados),
        " segmentos -> ", DIR_OUT)
