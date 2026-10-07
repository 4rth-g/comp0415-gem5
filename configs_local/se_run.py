# se_run.py — config gem5 (Standard Library), modo SE, ISA RISC-V.
# Executa um binário estático RISC-V variando o modelo de CPU e, opcionalmente,
# tamanhos de cache e frequência do clock.
# Uso: gem5.opt se_run.py <binario> --cpu {atomic,timing,minor,o3}
#                         [--l1d 32KiB] [--l1i 32KiB] [--l2 256KiB] [--clk 1GHz]
#
# Os valores padrão definem a configuração-base do artigo; simular.sh grava
# todos os parâmetros no meta.json e os inclui no hash da execução.
import argparse

from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.cachehierarchies.classic.private_l1_private_l2_cache_hierarchy \
    import PrivateL1PrivateL2CacheHierarchy
from gem5.components.memory.single_channel import SingleChannelDDR3_1600
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.components.processors.cpu_types import CPUTypes
from gem5.isas import ISA
from gem5.resources.resource import BinaryResource
from gem5.simulate.simulator import Simulator

p = argparse.ArgumentParser()
p.add_argument("binary", help="caminho do binário estático RISC-V")
p.add_argument("--cpu", default="timing",
               choices=["atomic", "timing", "minor", "o3"])
p.add_argument("--l1d", default="32KiB", help="tamanho da L1 de dados")
p.add_argument("--l1i", default="32KiB", help="tamanho da L1 de instruções")
p.add_argument("--l2", default="256KiB", help="tamanho da L2")
p.add_argument("--clk", default="1GHz", help="frequência do clock")
args = p.parse_args()

CPU = {
    "atomic": CPUTypes.ATOMIC,   # funcional, rápido
    "timing": CPUTypes.TIMING,   # com latência de memória
    "minor":  CPUTypes.MINOR,    # in-order, pipeline
    "o3":     CPUTypes.O3,       # out-of-order, superescalar
}[args.cpu]

cache = PrivateL1PrivateL2CacheHierarchy(
    l1d_size=args.l1d, l1i_size=args.l1i, l2_size=args.l2)
memory = SingleChannelDDR3_1600("1GiB")
processor = SimpleProcessor(cpu_type=CPU, isa=ISA.RISCV, num_cores=1)

board = SimpleBoard(clk_freq=args.clk, processor=processor,
                    memory=memory, cache_hierarchy=cache)
board.set_se_binary_workload(BinaryResource(args.binary))

print(f">>> Rodando {args.binary} com CPU={args.cpu} "
      f"L1D={args.l1d} L1I={args.l1i} L2={args.l2} clk={args.clk}")
Simulator(board=board).run()
print(">>> Simulação concluída.")
