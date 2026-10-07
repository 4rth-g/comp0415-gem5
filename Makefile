# Pipeline reprodutível: código-fonte -> binários RISC-V -> simulações -> análise.
#
#   make bin        compila os exemplos no container (estático) + bin/SHA256SUMS
#   make conferir   compila os exemplos nativamente (sem gem5) e compara a saída
#                   das redes neurais com as referências em Python
#   make sim        roda todos os programas em todas as CPUs (simular.sh;
#                   reaproveita execuções já feitas com as mesmas entradas)
#   make varredura  camada densa N=64, CPU o3, variando o tamanho da L1D
#   make storesets  camada densa N=64, CPU o3, variando o período em que o
#                   preditor de dependência de memória é zerado (resultado
#                   negativo: não muda nada — ver README; fora do `make tudo`)
#   make visual     pipeline do o3, trace RISC-V e assembly de uma ROI da soma
#   make analise    tabelas, gráficos e diagrama do sistema (analise/)
#   make testar     testes do parser de estatísticas (analise/testes.R)
#   make tudo       bin + sim + varredura + visual + analise
#
# Reprodução (validação cruzada, na máquina da dupla):
#   make verificar  recompila do zero e confere com o bin/SHA256SUMS versionado
#   make reproduzir simula tudo de novo e compara com as estatísticas versionadas
#   make arquivar   move execuções de entradas antigas para resultados/legado/
#
# Pré-requisito: ../gem5-build (gem5.opt, libm5 e imagem gem5-riscv:local),
# gerado pelo build-gem5.sh daquele repositório. Outro local: GEM5_DIR=...

GEM5_DIR ?= $(abspath ../gem5-build/gem5)
ENGINE   ?= $(shell command -v podman || command -v docker)
IMG      ?= gem5-riscv:local
CPUS     ?= atomic timing minor o3
TAMANHOS ?= 16 32 64 128
L1D_VARREDURA ?= 4KiB 8KiB 16KiB 32KiB 64KiB
SSCLEAR  ?= 100 1000 10000 250000
# simulações em paralelo (cada gem5 usa ~1,2 GB de RAM)
JOBS     ?= 4
export ENGINE IMG GEM5_DIR

# Docker com root gravaria os arquivos como root: roda com o usuário do host
# (no Podman sem root, o root do container já é o próprio usuário)
USUARIO  := $(if $(findstring docker,$(notdir $(ENGINE))),--user $(shell id -u):$(shell id -g) -e HOME=/tmp)
EM_CONTAINER = $(ENGINE) run --rm $(USUARIO) -v "$(CURDIR)":/w -v "$(GEM5_DIR)":/gem5:ro -w /w $(IMG)

# -ffp-contract=off: sem fusão multiply-add, para o ponto flutuante bater bit
# a bit com as referências em Python e entre as ordens de laço da camada densa
CXX      := riscv64-linux-gnu-g++
CXXFLAGS := -O2 -static -march=rv64gc -mabi=lp64d -ffp-contract=off -I/gem5/include
LDLIBS   := -L/gem5/util/m5/build/riscv/out -lm5

PROGS := $(filter-out camada_densa,$(basename $(notdir $(wildcard exemplos/*.cpp))))
BINS  := $(PROGS:%=bin/%_riscv) $(TAMANHOS:%=bin/camada_densa_N%_riscv)

.PHONY: tudo bin conferir sim varredura storesets visual analise testar \
        verificar reproduzir arquivar limpar
tudo: bin sim varredura visual analise

bin: bin/SHA256SUMS

bin/%_riscv: exemplos/%.cpp exemplos/comum.h | bin/
	$(EM_CONTAINER) $(CXX) $(CXXFLAGS) $< -o $@ $(LDLIBS)

bin/camada_densa_N%_riscv: exemplos/camada_densa.cpp exemplos/comum.h | bin/
	$(EM_CONTAINER) $(CXX) $(CXXFLAGS) -DN=$* $< -o $@ $(LDLIBS)

bin/SHA256SUMS: $(BINS)
	cd bin && sha256sum $(notdir $(BINS)) > SHA256SUMS

bin/:
	mkdir -p $@

conferir:
	./exemplos/conferir.sh

sim: bin
	@for b in $(BINS); do for c in $(CPUS); do echo "$$b $$c"; done; done \
	  | xargs -P $(JOBS) -L 1 ./simular.sh

varredura: bin
	@for t in $(L1D_VARREDURA); do echo "bin/camada_densa_N64_riscv o3 --l1d $$t"; done \
	  | xargs -P $(JOBS) -L 1 ./simular.sh

storesets: bin
	@for p in $(SSCLEAR); do echo "bin/camada_densa_N64_riscv o3 --ssclear $$p"; done \
	  | xargs -P $(JOBS) -L 1 ./simular.sh

visual: sim
	analise/visualizar.sh soma_vetor 2

analise:
	Rscript analise/relatorio.R
	$(EM_CONTAINER) dot -Tpdf analise/saida/sistema.dot -o analise/saida/fig_sistema.pdf
	$(EM_CONTAINER) dot -Tpng -Gdpi=300 analise/saida/sistema.dot -o analise/saida/fig_sistema.png

testar:
	Rscript analise/testes.R

verificar:
	git diff --quiet -- bin/SHA256SUMS || { echo "bin/SHA256SUMS com mudanças locais"; exit 1; }
	rm -f $(BINS)
	$(MAKE) $(BINS)
	cd bin && sha256sum -c SHA256SUMS

reproduzir: verificar
	FORCAR=1 $(MAKE) sim varredura
	analise/comparar.sh

arquivar:
	analise/arquivar.sh

limpar:
	rm -f $(BINS)
