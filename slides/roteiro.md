# Roteiro do vídeo (até 10 min)

Um bloco por slide de `slides/slides.html` (ou `slides.pdf`). Tempo total
previsto: **≈ 9 min 40 s**, com margem para respirar.

- **Quem fala**: sugestão de divisão. Arthur cobre o simulador e a
  instalação (slides 1–11); Renato, os exemplos e as conclusões (12–20).
  Troquem à vontade.
- **Fala**: texto para guiar, não para ler palavra por palavra. Os números em
  **negrito** estão no slide; não é preciso decorar.
- **Na tela**: o que mostrar ou apontar. Teclas do revealjs: → avança,
  **S** abre as notas do apresentador, **F** tela cheia.

Para gravar: OBS Studio capturando a janela do navegador com os slides em tela
cheia (F) e o microfone. A demonstração ao vivo (bloco 9) é opcional, mas
mostra o simulador de fato funcionando, que é o que o modelo do trabalho pede.

---

## Bloco 1 · Capa — 0:00 (15 s) · Arthur

> Olá! Eu sou o Arthur, e com o Renato apresentamos o trabalho de Arquitetura
> de Computadores: como usar o simulador gem5 para rodar algoritmos sobre a
> ISA RISC-V, e o que ele revela sobre o processador.

**Na tela:** capa.

## Bloco 2 · Por que simular um processador? — 0:15 (30 s) · Arthur

> Testar uma ideia de arquitetura em silício é **caro**. O hardware é
> **opaco**: não mostra o que acontece dentro do pipeline. E é **fixo**: para
> mudar o tamanho de uma cache, é preciso outro chip. Um simulador resolve os
> três problemas: roda **o mesmo programa** em **microarquiteturas
> diferentes** e registra cada evento interno.

**Na tela:** as três palavras; avançar para a frase de baixo.

## Bloco 3 · Por que o gem5? — 0:45 (30 s) · Arthur

> Existem vários simuladores. O QEMU é rápido, mas só funcional: não mede
> tempo. O Ripes e o MARS são ótimos para ensino, mas simulam um processador
> simples. O gem5 é o único desta lista com RISC-V, vários modelos de
> processador, do funcional ao fora de ordem, e estatísticas de cada
> componente. A contrapartida: não tem interface gráfica. Tudo é script e
> arquivo de texto — por isso todas as figuras aqui fomos nós que geramos.

**Na tela:** apontar a linha do gem5 (laranja).

## Bloco 4 · Como o gem5 funciona — 1:15 (35 s) · Arthur

> Por dentro, o gem5 é um simulador orientado a eventos, com o tempo contado em
> ticks de um picossegundo. Cada componente — CPU, caches, barramentos,
> memória — é um *SimObject* em C++, e eles conversam por portas, trocando
> pacotes. Quem monta o sistema é um script Python. No modo SE, que usamos, o
> próprio simulador atende as chamadas de sistema do programa, sem precisar de
> um Linux completo. No fim, sai um arquivo com milhares de estatísticas.

**Na tela:** percorrer o diagrama da esquerda para a direita.

## Bloco 5 · Quatro CPUs, quatro níveis de detalhe — 1:50 (30 s) · Arthur

> O gem5 tem quatro modelos de processador que executam exatamente as mesmas
> instruções: o *atomic*, funcional; o *timing*, que espera a memória; o
> *minor*, um pipeline em ordem; e o *o3*, superescalar e fora de ordem. O
> detalhe tem custo: o atomic simula cerca de **600 mil instruções por
> segundo**, o o3 cerca de **125 mil**, umas cinco vezes mais devagar.

**Na tela:** apontar as medianas, de cima para baixo.

## Bloco 6 · Dentro do o3 — 2:20 (35 s) · Arthur

> O o3 é o mais completo, e os nossos resultados dependem dele. A instrução
> passa por *fetch*, *decode*, *rename* e *dispatch*; espera na *issue queue*
> até os operandos ficarem prontos; sai **fora de ordem** para *execute* e
> *writeback*; e o *commit* confirma tudo na ordem original, pelo *reorder
> buffer*. Guardem dois componentes em laranja: o *branch predictor*, que
> adivinha os desvios, e o *memory dependence predictor*, que decide se um
> *load* pode passar na frente de um *store*. Os dois vão aparecer nos
> resultados.

**Na tela:** seguir a linha central; no fim, apontar as duas caixas laranja.

## Bloco 7 · O sistema simulado — 2:55 (25 s) · Arthur

> O sistema que montamos: um núcleo RISC-V de 64 bits a 1 GHz, caches L1 de
> 32 KiB para instruções e para dados, L2 de 256 KiB e memória DDR3. Com a
> Standard Library do gem5, isso cabe em poucas linhas de Python, e o modelo
> de CPU e o tamanho das caches viram parâmetros de linha de comando.

**Na tela:** diagrama à esquerda; depois o trecho de código.

## Bloco 8 · Instalação reprodutível — 3:20 (35 s) · Arthur

> Instalar o gem5 não é trivial: a compilação levou **76 minutos** e depende
> de muitas bibliotecas. Para qualquer pessoa obter o mesmo simulador, fizemos
> tudo dentro de um container e fixamos cada versão: o commit do gem5, a
> imagem base, o compilador cruzado e os pacotes de análise. Cada simulação
> ganha um hash calculado das suas entradas. E verificamos: com Podman e com
> Docker, os binários e as estatísticas saíram **idênticos**. Um único
> `make tudo` refaz o trabalho inteiro.

**Na tela:** percorrer o fluxo; depois os dois números.

## Bloco 9 · O gem5 rodando — 3:55 (30 s) · Arthur

> É assim que o gem5 aparece: no terminal. Ele carrega o programa, roda, o
> programa imprime a soma, e as estatísticas vão para o `stats.txt`: aqui,
> **16.390 instruções em 4.124 ciclos**, um IPC de quase **4**.

**Na tela:** apontar a linha laranja (saída do programa) e as estatísticas.

**Opção — demonstração ao vivo (≈ 40 s, no lugar da fala acima):** num
terminal, na pasta do repositório:

```fish
FORCAR=1 ./simular.sh bin/soma_vetor_riscv o3
zcat (ls -d resultados/soma_vetor_o3_* | tail -1)/stats.txt.gz | grep -E "^simInsts|core.ipc " | head -4
```

> Vou rodar a soma de vetor no o3… em poucos segundos ele termina, e aqui
> estão as instruções e o IPC de cada trecho.

## Bloco 10 · Medindo só o algoritmo — 4:25 (30 s) · Arthur

> Um detalhe de método que fez toda a diferença. Um binário estático executa
> mais de cem mil instruções só inicializando a biblioteca C. Na soma de vetor,
> o programa inteiro tem **254 mil** instruções, mas o laço que nos interessa
> tem só **16 mil**. Por isso marcamos a **região de interesse** no código:
> o gem5 zera as estatísticas no início e grava no fim, e medimos só o
> algoritmo.

**Na tela:** o código à esquerda; depois o gráfico (laranja = programa
inteiro, azul = só a região de interesse).

## Bloco 11 · O pipeline em ação — 4:55 (30 s) · Arthur

> E dá para ver o pipeline do o3 instrução por instrução. Cada linha é uma
> instrução do laço da soma; as cores são os estágios. A cada ciclo, quatro
> instruções entram pelo *fetch* e, alguns ciclos depois, quatro saem pelo
> *commit*: uma volta do laço por ciclo. Essa é a "tela" que o simulador não
> tem — montada a partir do registro do próprio gem5.

**Na tela:** seguir uma linha da esquerda para a direita; depois mostrar a
"escada" das linhas.

## Bloco 12 · Exemplos — 5:25 (5 s) · Renato

> Agora, os exemplos.

**Na tela:** slide escuro. Passar logo.

## Bloco 13 · Ordenação: o branch predictor — 5:30 (35 s) · Renato

> Eu sou o Renato. Primeiro, a ordenação. O mesmo bubble sort, rodando sobre
> um vetor aleatório e depois sobre o vetor já ordenado: no o3, o aleatório
> leva **138 mil** ciclos e o ordenado, **100 mil**, com o mesmo código. A
> diferença é o *branch predictor*: no aleatório ele erra **3,7%** dos
> desvios; no ordenado, quase nunca. O quicksort, no mesmo vetor, faz sete
> vezes menos instruções — mas erra **11,9%** dos desvios, porque cada passo
> da partição é imprevisível.

**Na tela:** comparar as barras do o3 (amarelo); depois a linha de baixo.

## Bloco 14 · Busca em grafo: localidade de memória — 6:05 (30 s) · Renato

> A mesma busca em largura, em dois grafos do mesmo tamanho: uma grade, em que
> os vizinhos ficam perto na memória, e um grafo aleatório. O número de
> instruções é praticamente igual, mas os *misses* na cache sobem de **20
> para 80** por mil instruções, e o o3 leva **2,6 vezes** mais ciclos. O
> algoritmo é o mesmo; só mudou a disposição dos dados.

**Na tela:** barras do o3 (60 → 155).

## Bloco 15 · MDC: o modelo de CPU muda a conclusão — 6:35 (40 s) · Renato

> Este é um dos resultados mais interessantes. O MDC de Euclides usa uma
> divisão por passo; a versão binária usa só deslocamentos e subtrações, e
> executa quase quatro vezes mais instruções. No *timing*, Euclides é quatro
> vezes mais rápido. Mas no o3, que modela a unidade de divisão com
> **20 ciclos** de latência, e com cada passo esperando o anterior, o
> Euclides passa a ser o **mais lento**. Um simulador simples demais daria a
> conclusão errada.

**Na tela:** primeiro o painel *timing* (172 contra 729); depois o painel
*o3* (738 contra 706).

## Bloco 16 · Matrizes: cache ou dependência de memória? — 7:15 (45 s) · Renato

> A multiplicação de matrizes, que é o núcleo de uma camada de rede neural,
> em três ordens de laço. A ordem i-k-j é a que a teoria de cache recomenda: e
> de fato quase não tem *misses*. Mas no o3 ela é **duas vezes mais lenta**.
> O motivo é o *memory dependence predictor* que vimos lá atrás: cada *load*
> de Y vem logo depois de um *store* no mesmo endereço, e o preditor passa a
> segurar esses *loads*. Para confirmar, fizemos um controle: a mesma ordem,
> gravando Y quatro vezes menos. Os *loads* retidos caem 3,6 vezes e o custo
> cai 44%. E, variando a cache, o custo da i-k-j nem se mexe: não é a cache
> que a limita.

**Na tela:** painel da esquerda (custo: azul no alto, plano); depois o da
direita (*loads* retidos).

## Bloco 17 · Uma versão em relação à outra — 8:00 (25 s) · Renato

> Este gráfico resume todas as comparações. O losango é quanto uma versão
> executa de instruções em relação à outra; os círculos, quanto ela leva de
> ciclos em cada CPU. Quando os círculos se afastam do losango, é a
> microarquitetura pesando: na busca em grafo, mesmas instruções e mais que o
> dobro de ciclos; no MDC e nas matrizes, o o3 cruza a linha e inverte a
> conclusão.

**Na tela:** apontar a linha "igual"; depois as linhas BFS e MDC.

## Bloco 18 · E as redes neurais? — 8:25 (25 s) · Renato

> Também rodamos três exemplos de redes neurais — regressão linear, perceptron
> e uma rede que aprende XOR — conferidos contra Python até a sexta casa
> decimal. No simulador, o que os distingue é o ponto flutuante: de **24 a
> 51%** das instruções, contra zero nos algoritmos clássicos, com exceção da
> multiplicação de matrizes.

**Na tela:** barras laranja de baixo.

## Bloco 19 · O que o simulador mostrou — 8:50 (35 s) · Renato

> Para fechar, quatro lições.
> Um: o desempenho vem de **como** a microarquitetura executa, não só de
> **quantas** instruções.
> Dois: um modelo simples demais pode dar a **conclusão errada**.
> Três: sem região de interesse, medimos a biblioteca C, não o algoritmo.
> Quatro: com container e hash por simulação, os resultados são
> **reprodutíveis**.
> A maior dificuldade foi prática: compilar o gem5 e entender o que ele mede.

**Na tela:** avançar item a item (cada → mostra um).

## Bloco 20 · Obrigado — 9:25 (15 s) · Arthur e Renato

> Todo o código, as simulações, o artigo e estes slides estão no repositório
> público. Obrigado!

**Na tela:** link do repositório. Fim: ≈ 9:40.
