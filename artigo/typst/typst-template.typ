// typst-template.typ — modelo Typst do artigo, imitando o modelo .docx da
// disciplina (template SBC): página Carta, margens de 1 pol. (1,2 pol. embaixo),
// Times 10 pt, corpo em duas colunas (espaço de 0,32 pol.), parágrafos
// justificados com recuo na primeira linha, títulos de seção em negrito.
// Figuras e tabelas ocupam a largura das duas colunas (como figure* no LaTeX).
// O bloco de título é escrito pelo próprio artigo.qmd (função cabecalho()).
#let artigo(doc) = {
  set page(paper: "us-letter", columns: 2,
           margin: (top: 1in, left: 1in, right: 1in, bottom: 1.2in),
           numbering: "1", number-align: center)
  set columns(gutter: 0.32in)
  set text(font: ("Liberation Serif", "Nimbus Roman"),  // métricas da Times New Roman
           size: 10pt, lang: "pt", region: "BR")
  set par(justify: true, leading: 0.5em, spacing: 0.5em,
          first-line-indent: (amount: 0.17in, all: true))
  set list(indent: 0.6em)

  show heading.where(level: 1): it => block(above: 1.3em, below: 0.7em,
    text(size: 12pt, weight: "bold", it.body))
  show heading.where(level: 2): it => block(above: 1.1em, below: 0.6em,
    text(size: 11pt, weight: "bold", it.body))

  show raw: set text(font: ("Liberation Mono", "DejaVu Sans Mono"), size: 7.5pt)
  show raw.where(block: true): it => block(width: 100%, inset: 4pt,
    fill: luma(245), radius: 2pt, it)

  show figure: it => place(auto, float: true, scope: "parent", clearance: 1.2em, it)
  show figure.caption: set text(size: 9pt, weight: "bold")
  show figure.where(kind: table): set figure.caption(position: top)
  show table: set text(size: 9pt)

  show link: set text(fill: black)

  doc
}
