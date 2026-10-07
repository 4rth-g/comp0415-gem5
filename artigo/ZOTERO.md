# Referências: Zotero ↔ `referencias.bib`

O Zotero é a fonte de verdade. O `referencias.bib` deste diretório já está
corrigido e completo, e o artigo pode usá-lo agora. Depois dos passos abaixo,
o auto-export do Better BibTeX passa a regerá-lo a partir do Zotero, com as
**mesmas chaves**.

Metadados conferidos em 2026-10-07 no Crossref/DataCite (doi.org).

## Estado encontrado (cópia do `zotero.sqlite`, só leitura)

- As duplicatas já tinham sido mescladas. Restam 35 obras e 207 itens na
  lixeira. As coleções `Simuladores` e três das `referencias` já estão na
  lixeira.
- `Arquitetura de Computadores › referencias` tem as 27 obras da Av.1. As
  demais obras de `Arquitetura de Computadores` são de benchmark e ficam fora
  do escopo.

## 1. Organizar as coleções

- [ ] Renomear `Arquitetura de Computadores › referencias` para **`Av1 · Simuladores`**.
- [ ] Conferir a lixeira e depois esvaziá-la (são as cópias já mescladas).

## 2. Importar as 6 obras novas

`File › Import…` › `artigo/zotero_novos.bib` › opção para colocar na coleção
`Av1 · Simuladores`.

| Chave | Obra | Para quê |
|---|---|---|
| `chrysos1998storesets` | Chrysos & Emer, *Store Sets*, ISCA 1998 | explica a camada densa i-k-j no o3 |
| `smith1981branch` | Smith, *Branch Prediction Strategies*, ISCA 1981 | preditor de desvios (bubble, busca) |
| `lam1991blocked` | Lam, Rothberg & Wolf, ASPLOS 1991 | ordem de laço × cache |
| `rosenblatt1958perceptron` | Rosenblatt 1958 | exemplo do perceptron |
| `rumelhart1986backprop` | Rumelhart, Hinton & Williams 1986 | exemplo MLP-XOR |
| `lowepower2026learning` | *Learning gem5* (documentação) | uso da biblioteca padrão do gem5 |

## 3. Corrigir os itens existentes

Em cada item, fixar a **Citation Key** (campo no topo do painel do item; ao
editar, ela fica fixada) e aplicar as correções.

| Item atual | Citation Key | Correções |
|---|---|---|
| Computer Architecture: A Quantitative Approach | `hennessy2017quantitative` | **autores na ordem errada**: Hennessy, John L.; Patterson, David A. |
| Computer Organization and Design RISC-V | `patterson2020riscv` | nomes completos: Patterson, David A.; Hennessy, John L. |
| Computer Organization and Architecture | `stallings2022organization` | — |
| Structured Computer Organization | `tanenbaum2013structured` | Tanenbaum, Andrew S. |
| Measuring Computer Performance | `lilja2000measuring` | — |
| A Survey of Computer Architecture Simulation… | `akram2019survey` | — |
| Survey of CPU and Memory Simulators… | `hwang2025survey` | **ano 2025**; volume 138; páginas 103032; título completo: "…: A Comprehensive Analysis Including Compiler Integration and Emerging Technology Applications" |
| A Survey and Evaluation of Simulators… | `nikolic2009survey` | **ordem dos autores**: Nikolić, Radivojević, **Đorđević, Milutinović** |
| QEMU | `bellard2005qemu` | — |
| Sniper | `carlson2011sniper` | **ordem dos autores**: Carlson, **Heirman, Eeckhout**; páginas 1–12 |
| Flexible Timing Simulation of RISC-V… | `mallya2018sniper` | nomes: Mallya, Neethu Bal; Gonzalez-Alvarez, Cecilia; Carlson, Trevor E. |
| Ripes | `petersen2021ripes` | — |
| WebRISC-V | `giorgi2019webriscv` | páginas 1–6 |
| MARS | `vollmar2006mars` | — |
| MIPS Processor Implemented in a Visual Simulator… | `rodrigues2024mips` | nomes: Rodrigues, Christofer; Gonçalves, Rogério Aparecido; Fabrício Filho, João |
| The gem5 Simulator | `binkert2011gem5` | — |
| The gem5 Simulator: Version 20.0+ | `lowepower2020gem5v20` | — |
| Enabling Reproducible and Agile Full-System Simulation | `bruce2021gem5art` | **ordem dos autores** (Bruce é o 1º): Bruce, Akram, Nguyen, Roarty, Samani, Fariborz, Reddy, Sinclair, Lowe-Power; **DOI 10.1109/ISPASS51385.2021.00035**; páginas 183–193 |
| Toward Reproducible and Standardized… | `pai2026gem5` | **publicado no ISPASS 2026**: tipo *Conference Paper*; autores Pai, Kunal; Patel, Harshil; Le, Erin; Krim, Noah; Samani, Mahyar; Bruce, Bobby R.; Lowe-Power, Jason (não "The gem5 community"); ano 2026; páginas 184–196; **DOI 10.1109/ISPASS69572.2026.00027** |
| Abordagem para Aprendizado do Simulador gem5… | `rigotto2023gem5` | evento: **WSCAD 2023** (Anais Estendidos do XXIV Simpósio em Sistemas Computacionais de Alto Desempenho); Freitas, Henrique Cota de; páginas 9–16; **DOI 10.5753/wscad_estendido.2023.235800** |
| Architectural Simulation with gem5 | `aquino2024gem5` | **autores**: Aquino, Iago Caran; Wanner, Lucas; Rigo, Sandro; páginas 89–115; **DOI 10.5753/sbc.16010.0.4** |
| Sources of Error in Full-System Simulation | `gutierrez2014sources` | **8 autores**: + Sudanthi, Chander; Emmons, Christopher D.; Hayenga, Mitchell; Paver, Nigel |
| Validation of the gem5 Simulator for x86… | `akram2019validation` | páginas 53–58 |
| Measuring Experimental Error in Microprocessor Simulation | `desikan2001error` | evento: ISCA 2001; local **Göteborg** (está "G?teborg") |
| The RISC-V Instruction Set Manual | `waterman2019riscv` | — |
| Reproducibility of Build Environments… | `malka2024nix` | páginas 97–101 |
| Improving Reproducibility… Nix/NixOS… preCICE | `hausch2025nix` | **autores** (estavam vazios): Hausch, Max; Hauser, Simon; Uekermann, Benjamin; **ano 2025** |

## 4. Auto-export para o repositório

Clicar com o botão direito em `Av1 · Simuladores` › `Export Collection…` ›
formato **Better BibTeX** › marcar **Keep updated** › salvar como
`~/src/comp0415-gem5/artigo/referencias.bib`, substituindo o atual.

Depois, conferir com `git diff artigo/referencias.bib`. Devem mudar só
formatação e campos extras (resumo, URL), nunca as chaves.
