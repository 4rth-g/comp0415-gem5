#!/usr/bin/env Rscript
# testes.R — testes do parser de estatísticas (analise/funcoes.R).
# Uso (na raiz do repo):  Rscript analise/testes.R   (ou: make testar)
#
# Monta um stats.txt sintético com 5 dumps — [antes] [ROI 1] [entre] [ROI 2]
# [depois] — e confere a segmentação, a soma do programa inteiro, o tratamento
# de contadores ausentes e as taxas derivadas.
source("analise/funcoes.R")

falhas <- 0
confere <- function(descricao, obtido, esperado) {
  ok <- isTRUE(all.equal(obtido, esperado))
  cat(if (ok) "ok    " else "FALHA ", descricao, "\n", sep = "")
  if (!ok) { cat("      obtido:  ", format(obtido), "\n      esperado:", format(esperado), "\n"); falhas <<- falhas + 1 }
}

dump <- function(insts, ciclos, l1d_falhas = NULL, desvios = NULL, errados = NULL,
                 mix = c(IntAlu = insts)) {
  c("",
    "---------- Begin Simulation Statistics ----------",
    sprintf("simInsts %d # Number of instructions simulated (Count)", insts),
    sprintf("simTicks %d # ticks", ciclos * 1000),
    sprintf("hostSeconds 0.5 # Real time elapsed on the host (Second)"),
    sprintf("%snumCycles %d # Number of cpu cycles simulated (Cycle)", P, ciclos),
    if (!is.null(l1d_falhas))
      sprintf("%sl1d-cache-0.overallMisses::total %d # misses", C, l1d_falhas),
    sprintf("%sl1d-cache-0.overallAccesses::total %d # accesses", C, insts %/% 4),
    if (!is.null(desvios)) sprintf("%sbranchPred.condPredicted %d # n", P, desvios),
    if (!is.null(errados)) sprintf("%sbranchPred.condIncorrect %d # n", P, errados),
    sprintf("%sdistribuicao::samples %d 50.00%% 50.00%% # linha de distribuição", P, 7),
    paste0(PREFIXO_MIX, names(mix), " ", mix, " 10.00% 10.00% # Class"),
    paste0(PREFIXO_MIX, "total ", insts, " # Class"),
    "",
    "---------- End Simulation Statistics   ----------")
}

arq <- tempfile(fileext = ".txt")
writeLines(c(
  dump(1000, 1500, l1d_falhas = 40, desvios = 100, errados = 10),            # antes
  dump(200, 100, desvios = 50, errados = 1,                                  # ROI 1:
       mix = c(IntAlu = 150, MemRead = 50)),                                 #  sem falhas
  dump(5, 12, desvios = 1, errados = 0),                                     # entre
  dump(400, 800, l1d_falhas = 20, desvios = 80, errados = 8,                 # ROI 2
       mix = c(FloatAdd = 100, FloatMultAcc = 100, MemWrite = 200)),
  dump(300, 600, l1d_falhas = 3, desvios = 30, errados = 3)                  # depois
), arq)

d <- ler_dumps(arq)
confere("lê 5 dumps", max(d$dump), 5L)
confere("linha com vários números (distribuição): fica o 1º valor",
        d$valor[d$nome == paste0(P, "distribuicao::samples")][1], 7)
confere("ler_dumps descomprime .gz",
        { gz <- paste0(arq, ".gz"); con <- gzfile(gz, "w"); writeLines(readLines(arq), con); close(con)
          nrow(ler_dumps(gz)) }, nrow(d))

s <- segmentar(d)
cont <- s$cont |> arrange(roi)
confere("3 segmentos: programa inteiro + 2 ROIs", cont$roi, c(0L, 1L, 2L))
confere("programa inteiro = soma dos 5 dumps (instruções)", cont$instrucoes[1], 1905)
confere("programa inteiro = soma dos 5 dumps (ciclos)", cont$ciclos[1], 3012)
confere("ROI 1 = 2º dump", c(cont$instrucoes[2], cont$ciclos[2]), c(200, 100))
confere("ROI 2 = 4º dump", c(cont$instrucoes[3], cont$ciclos[3]), c(400, 800))
confere("contador ausente num dump conta 0 (ROI 1 sem falhas)", cont$l1d_falhas[2], 0)
confere("contador ausente em todos os dumps = NA (sem L1I)", all(is.na(cont$l1i_falhas)), TRUE)

der <- derivar(cont)
confere("IPC da ROI 2 = 400/800", der$ipc[3], 0.5)
confere("falhas L1D por mil instruções da ROI 2", der$mpki_l1d[3], 50)
confere("erro de predição da ROI 2 = 8/80", der$erro_predicao[3], 0.1)

m <- s$mix |> filter(roi == 2) |> arrange(grupo)
confere("mix da ROI 2 agrupado (FP + escrita)",
        setNames(m$qtd, m$grupo), c(`escrita em memória` = 200, `ponto flutuante` = 200))

um <- tempfile(fileext = ".txt"); writeLines(dump(10, 20), um)
confere("sem ROI: só o programa inteiro", segmentar(ler_dumps(um))$cont$roi, 0L)

ini <- tempfile(fileext = ".ini")
writeLines(c("[board]", "type=Board", "", "[board.cache]", "size=32768", "assoc=8"), ini)
cf <- ler_config(ini)
confere("config.ini: valor de uma seção", cfg(cf, "board.cache", "size"), "32768")
confere("config.ini: chave ausente = NA", cfg(cf, "board.cache", "nada"), NA_character_)

cat(if (falhas) sprintf("\n%d teste(s) falharam\n", falhas) else "\ntodos os testes passaram\n")
quit(status = as.integer(falhas > 0))
