"""roteiro_docx.py — gera slides/roteiro.docx a partir de slides/roteiro.md.

O roteiro.md continua sendo a fonte; este script só cria um documento de
referência com estilos para leitura durante a gravação (A4, títulos dos
blocos em laranja, fala em letra maior com barra lateral, instruções de tela
em cinza) e chama o pandoc.

Uso: python3 slides/roteiro_docx.py   (ou: make roteiro)
"""
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path

DIR = Path(__file__).resolve().parent
FONTE, SAIDA = DIR / "roteiro.md", DIR / "roteiro.docx"

TINTA, LARANJA, CINZA = "1D2B3A", "C8642A", "56606B"


def estilo(st, sid, ppr="", rpr=""):
    """Substitui pPr/rPr de um estilo existente do reference.docx do pandoc."""
    padrao = r'(<w:style [^>]*w:styleId="%s"[^>]*>)(.*?)(</w:style>)' % sid
    m = re.search(padrao, st, re.S)
    assert m, sid
    corpo = re.sub(r"<w:pPr>.*?</w:pPr>|<w:pPr/>|<w:rPr>.*?</w:rPr>|<w:rPr/>", "", m.group(2), flags=re.S)
    novo = m.group(1) + corpo + f"<w:pPr>{ppr}</w:pPr><w:rPr>{rpr}</w:rPr>" + m.group(3)
    return st[:m.start()] + novo + st[m.end():]


fonte = '<w:rFonts w:ascii="Liberation Sans" w:hAnsi="Liberation Sans" w:cs="Liberation Sans"/>'
with tempfile.TemporaryDirectory() as tmp:
    ref = Path(tmp) / "ref.docx"
    subprocess.run(["pandoc", "-o", str(ref), "--print-default-data-file", "reference.docx"],
                   check=True)
    pasta = Path(tmp) / "ref"
    with zipfile.ZipFile(ref) as z:
        z.extractall(pasta)

    st = (pasta / "word/styles.xml").read_text(encoding="utf-8")
    st = re.sub(r"<w:rPrDefault>.*?</w:rPrDefault>",
                f'<w:rPrDefault><w:rPr>{fonte}<w:sz w:val="21"/><w:lang w:val="pt-BR"/></w:rPr></w:rPrDefault>',
                st, count=1, flags=re.S)
    st = estilo(st, "Title", '<w:spacing w:after="120"/>',
                f'{fonte}<w:b/><w:color w:val="{TINTA}"/><w:sz w:val="40"/>')
    st = estilo(st, "Heading1", '<w:keepNext/><w:spacing w:before="240" w:after="120"/>',
                f'{fonte}<w:b/><w:color w:val="{TINTA}"/><w:sz w:val="30"/>')
    st = estilo(st, "Heading2",
                '<w:keepNext/><w:spacing w:before="360" w:after="80"/>'
                f'<w:pBdr><w:top w:val="single" w:sz="6" w:space="6" w:color="E3DED6"/></w:pBdr>',
                f'{fonte}<w:b/><w:color w:val="{LARANJA}"/><w:sz w:val="26"/>')
    # fala (citação em markdown): letra maior, barra laranja à esquerda
    st = estilo(st, "BlockText",
                '<w:spacing w:before="80" w:after="80" w:line="300" w:lineRule="auto"/>'
                f'<w:pBdr><w:left w:val="single" w:sz="24" w:space="10" w:color="{LARANJA}"/></w:pBdr>'
                '<w:ind w:left="300" w:right="200"/>',
                f'{fonte}<w:color w:val="{TINTA}"/><w:sz w:val="25"/>')
    st = estilo(st, "BodyText", '<w:spacing w:before="60" w:after="60"/>', f'<w:color w:val="{CINZA}"/>')
    st = estilo(st, "FirstParagraph", '<w:spacing w:before="60" w:after="60"/>', f'<w:color w:val="{CINZA}"/>')
    st = estilo(st, "Compact", '<w:spacing w:before="20" w:after="20"/>', f'<w:color w:val="{CINZA}"/>')
    (pasta / "word/styles.xml").write_text(st, encoding="utf-8")

    # página A4, margens de 2 cm
    doc = (pasta / "word/document.xml").read_text(encoding="utf-8")
    doc = re.sub(r"<w:pgSz[^>]*/>", '<w:pgSz w:w="11906" w:h="16838"/>', doc)
    doc = re.sub(r"<w:pgMar[^>]*/>", '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" '
                 'w:left="1134" w:header="567" w:footer="567" w:gutter="0"/>', doc)
    (pasta / "word/document.xml").write_text(doc, encoding="utf-8")

    estilizado = Path(tmp) / "estilizado.docx"
    with zipfile.ZipFile(estilizado, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(pasta.rglob("*")):
            if f.is_file():
                z.write(f, f.relative_to(pasta))

    subprocess.run(["pandoc", str(FONTE), "-o", str(SAIDA), "--reference-doc", str(estilizado),
                    "-M", "lang=pt-BR",
                    "--shift-heading-level-by=0"], check=True)

print(f"{SAIDA.name} gerado a partir de {FONTE.name}")
