"""Render captured command output as terminal screenshots."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT = Path(r"C:\Windows\Fonts\consola.ttf")
HEADER = Path(r"C:\Windows\Fonts\segoeui.ttf")


def wrap(text: str, width: int) -> list[str]:
    lines = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if raw == "":
            lines.append("")
            continue
        while len(raw) > width:
            lines.append(raw[:width])
            raw = raw[width:]
        lines.append(raw)
    return lines


def render(title: str, body: str, dest: Path, width_chars: int = 100) -> None:
    font = ImageFont.truetype(str(FONT), 18)
    header_font = ImageFont.truetype(str(HEADER), 16)
    lines = wrap(body.rstrip("\n"), width_chars)
    if not lines:
        lines = [""]
    # Keep each picture short enough to paste into a report.
    page_size = 42
    pages = [lines[i : i + page_size] for i in range(0, len(lines), page_size)]
    for idx, page in enumerate(pages):
        line_h = 24
        margin_x = 18
        header_h = 36
        img_w = margin_x * 2 + width_chars * 11
        img_h = header_h + 16 + line_h * len(page) + 16
        img = Image.new("RGB", (img_w, img_h), "#1e1e1e")
        draw = ImageDraw.Draw(img)
        draw.rectangle((0, 0, img_w, header_h), fill="#2d2d30")
        draw.ellipse((14, 12, 26, 24), fill="#ff5f56")
        draw.ellipse((32, 12, 44, 24), fill="#ffbd2e")
        draw.ellipse((50, 12, 62, 24), fill="#27c93f")
        suffix = f"  ({idx + 1}/{len(pages)})" if len(pages) > 1 else ""
        draw.text((74, 8), title + suffix, font=header_font, fill="#dddddd")
        y = header_h + 12
        for line in page:
            draw.text((margin_x, y), line, font=font, fill="#d4d4d4")
            y += line_h
        out = dest if len(pages) == 1 else dest.with_name(f"{dest.stem}-{idx + 1}{dest.suffix}")
        img.save(out)
        print(out)


if __name__ == "__main__":
    title, src, dest = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
    render(title, src.read_text(encoding="utf-8", errors="replace"), dest)
