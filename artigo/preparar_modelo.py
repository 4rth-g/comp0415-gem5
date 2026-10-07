"""preparar_modelo.py — gera artigo/referencia.docx a partir do modelo do
professor (artigo/modelo.docx), para o Quarto/pandoc usar como reference-doc.

Mantém do modelo: página, margens, corpo em duas colunas, fontes e os
estilos do template (Title,
Author, Affiliation, Abstract Title, heading 1/2/3, References...). Ajusta os
estilos que o pandoc usa e que o modelo não tem, com a aparência do modelo:
  Body Text / First Paragraph  = corpo do modelo (justificado, recuo na 1ª linha)
  Compact                      = texto de tabela
  Image Caption / Table Caption = legendas centralizadas, em negrito
  Bibliography                 = estilo References do modelo
  Source Code                  = código, monoespaçado (cabe na coluna)

Uso: python3 artigo/preparar_modelo.py   (chamado por `make artigo`)
"""
import re
import shutil
import tempfile
import zipfile
from pathlib import Path

DIR = Path(__file__).resolve().parent
ORIGEM = DIR / "modelo.docx"
DESTINO = DIR / "referencia.docx"


def estilo(sid, nome, base, ppr="", rpr="", tipo="paragraph"):
    return (f'<w:style w:type="{tipo}" w:customStyle="1" w:styleId="{sid}">'
            f'<w:name w:val="{nome}"/><w:basedOn w:val="{base}"/><w:qFormat/>'
            f'<w:pPr>{ppr}</w:pPr><w:rPr>{rpr}</w:rPr></w:style>')


NOVOS = [
    estilo("FirstParagraph", "First Paragraph", "Corpodetexto"),
    estilo("Compact", "Compact", "Normal",
           '<w:spacing w:before="0" w:after="0"/><w:jc w:val="left"/>', '<w:sz w:val="20"/>'),
    estilo("ImageCaption", "Image Caption", "Normal",
           '<w:keepLines/><w:spacing w:before="60" w:after="240"/><w:jc w:val="center"/>',
           '<w:b/><w:sz w:val="20"/>'),
    estilo("TableCaption", "Table Caption", "Normal",
           '<w:keepNext/><w:spacing w:before="240" w:after="60"/><w:jc w:val="center"/>',
           '<w:b/><w:sz w:val="20"/>'),
    estilo("CaptionedFigure", "Captioned Figure", "Normal",
           '<w:keepNext/><w:spacing w:before="120" w:after="0"/><w:jc w:val="center"/>'),
    estilo("Figure", "Figure", "Normal", '<w:jc w:val="center"/>'),
    estilo("Bibliography", "Bibliography", "References",
           '<w:spacing w:after="60"/><w:ind w:left="284" w:hanging="284"/><w:jc w:val="both"/>'),
    estilo("SourceCode", "Source Code", "Normal",
           '<w:spacing w:before="60" w:after="60"/><w:jc w:val="left"/>',
           '<w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:sz w:val="15"/>'),
    # sem tamanho próprio: herda o do parágrafo (texto ou bloco de código)
    estilo("VerbatimChar", "Verbatim Char", "DefaultParagraphFont", "",
           '<w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/>',
           tipo="character"),
]

with tempfile.TemporaryDirectory() as tmp:
    with zipfile.ZipFile(ORIGEM) as z:
        z.extractall(tmp)
    word = Path(tmp) / "word"

    # corpo vazio; a seção final do documento gerado é a do corpo do modelo
    # (duas colunas). O bloco de título, em uma coluna, é encerrado por uma
    # quebra de seção no próprio artigo.qmd.
    doc = (word / "document.xml").read_text(encoding="utf-8")
    sect = [s for s in re.findall(r"<w:sectPr\b.*?</w:sectPr>", doc, re.S)
            if 'w:num="2"' in s][0]
    corpo = re.search(r"<w:body>.*</w:body>", doc, re.S)
    assert corpo, "modelo.docx sem <w:body>"
    doc = doc[:corpo.start()] + f"<w:body><w:p/>{sect}</w:body>" + doc[corpo.end():]
    (word / "document.xml").write_text(doc, encoding="utf-8")

    st = (word / "styles.xml").read_text(encoding="utf-8")
    # Body Text do modelo -> igual ao corpo usado no modelo (recuo de 1ª linha,
    # sem espaço extra entre parágrafos)
    st = re.sub(r'(<w:style [^>]*w:styleId="Corpodetexto">.*?<w:pPr>).*?(</w:pPr>)',
                r'\1<w:spacing w:before="0" w:after="0"/><w:ind w:firstLine="245"/>'
                r'<w:jc w:val="both"/>\2', st, count=1, flags=re.S)
    # títulos de seção com espaço antes e depois (no modelo, linhas em branco)
    for sid, antes, depois in (("Ttulo1", 240, 120), ("Ttulo2", 160, 60)):
        st = re.sub(r'(<w:style [^>]*w:styleId="%s">.*?<w:pPr>)' % sid,
                    r'\1<w:spacing w:before="%d" w:after="%d"/>' % (antes, depois),
                    st, count=1, flags=re.S)
    existentes = set(re.findall(r'w:styleId="([^"]+)"', st))
    novos = [n for n in NOVOS
             if re.findall(r'w:styleId="([^"]+)"', n)[0] not in existentes]
    st = st.replace("</w:styles>", "".join(novos) + "</w:styles>")
    (word / "styles.xml").write_text(st, encoding="utf-8")

    destino_tmp = Path(tmp) / "saida.docx"
    with zipfile.ZipFile(destino_tmp, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(Path(tmp).rglob("*")):
            if f.is_file() and f != destino_tmp:
                z.write(f, f.relative_to(tmp))
    shutil.copy(destino_tmp, DESTINO)

print(f"{DESTINO.name}: {len(novos)} estilo(s) acrescentado(s)")
