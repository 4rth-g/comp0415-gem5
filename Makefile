# Pipeline reprodutível: código-fonte -> binários RISC-V -> simulações -> análise.
#
#   make bin        compila exemplos/*.cpp no container (estático) + bin/SHA256SUMS
#   make sim        roda todos os programas em todas as CPUs (simular.sh)
#   make analise    tabelas e gráficos (analise/relatorio.R)
#   make tudo       bin + sim + analise
#   make verificar  recompila do zero e confere com o bin/SHA256SUMS versionado
#                   (validação cruzada: na máquina da dupla, deve dar tudo OK)
#
# Pré-requisito: ../gem5-build (gem5.opt, libm5 e imagem gem5-riscv:local),
# gerado pelo build-gem5.sh daquele repositório. Outro local: GEM5_DIR=...

GEM5_DIR ?= $(abspath ../gem5-build/gem5)
ENGINE   ?= $(shell command -v podman || command -v docker)
IMG      ?= gem5-riscv:local
CPUS     ?= atomic timing minor o3

CXX      := riscv64-linux-gnu-g++
CXXFLAGS := -O2 -static -I/gem5/include
LDLIBS   := -L/gem5/util/m5/build/riscv/out -lm5
EM_CONTAINER = $(ENGINE) run --rm -v "$(CURDIR)":/w -v "$(GEM5_DIR)":/gem5:ro -w /w $(IMG)

PROGS := $(basename $(notdir $(wildcard exemplos/*.cpp)))
BINS  := $(PROGS:%=bin/%_riscv)

.PHONY: tudo bin sim analise verificar limpar
tudo: bin sim analise

bin: bin/SHA256SUMS

bin/%_riscv: exemplos/%.cpp | bin/
	$(EM_CONTAINER) $(CXX) $(CXXFLAGS) $< -o $@ $(LDLIBS)

bin/SHA256SUMS: $(BINS)
	cd bin && sha256sum $(notdir $(BINS)) > SHA256SUMS

bin/:
	mkdir -p $@

sim: bin
	@for p in $(PROGS); do for c in $(CPUS); do \
	  ./simular.sh bin/$${p}_riscv $$c || exit 1; \
	done; done

analise:
	Rscript analise/relatorio.R

verificar:
	git diff --quiet -- bin/SHA256SUMS || { echo "bin/SHA256SUMS com mudanças locais"; exit 1; }
	rm -f $(BINS)
	$(MAKE) $(BINS)
	cd bin && sha256sum -c SHA256SUMS

limpar:
	rm -f $(BINS)
