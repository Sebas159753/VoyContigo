# Genera los gráficos de Play Store con la identidad de VoyContigo:
#   icon_512.png          — icono de la ficha (512x512, sin transparencia)
#   feature_1024x500.png  — gráfico destacado
# Uso:  python store_assets/generate_graphics.py

from PIL import Image, ImageDraw, ImageFont
import os

BASE = os.path.dirname(__file__)
MORADO_OSCURO = (66, 44, 109)    # #422c6d
MORADO = (118, 89, 175)          # #7659af
LILA = (208, 190, 244)           # #d0bef4
VERDE = (46, 158, 107)           # #2E9E6B
BLANCO = (255, 255, 255)

FJALLA = os.path.join(BASE, "fonts", "FjallaOne-Regular.ttf")
PUBLIC = os.path.join(BASE, "fonts", "PublicSans.ttf")


def gradiente_diagonal(w, h, c1, c2):
    """Degradado diagonal suave usando una máscara 2x2 reescalada."""
    mask = Image.new("L", (2, 2))
    mask.putdata([0, 128, 128, 255])
    mask = mask.resize((w, h), Image.BICUBIC)
    a = Image.new("RGB", (w, h), c1)
    b = Image.new("RGB", (w, h), c2)
    return Image.composite(b, a, mask)


def icono():
    img = gradiente_diagonal(512, 512, MORADO_OSCURO, MORADO)
    capa = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)

    # Acentos de ruta en las esquinas (sin cruzar el monograma).
    d.line([(336, 168), (452, 62)], fill=(255, 255, 255, 40), width=12)
    d.ellipse([436, 46, 468, 78], outline=(255, 255, 255, 70), width=7)
    d.line([(60, 452), (176, 346)], fill=(255, 255, 255, 40), width=12)
    d.ellipse([44, 436, 76, 468], outline=(255, 255, 255, 70), width=7)

    img = Image.alpha_composite(img.convert("RGBA"), capa)
    d = ImageDraw.Draw(img)

    # Monograma "V." centrado (Fjalla One), con el punto lila de la marca.
    f = ImageFont.truetype(FJALLA, 330)
    v_box = d.textbbox((0, 0), "V", font=f)
    v_w, v_h = v_box[2] - v_box[0], v_box[3] - v_box[1]
    x = (512 - v_w) / 2 - v_box[0] - 22
    y = (512 - v_h) / 2 - v_box[1] - 10
    # sombra ligera para despegar del fondo
    d.text((x + 6, y + 8), "V", font=f, fill=(0, 0, 0, 60))
    d.text((x, y), "V", font=f, fill=BLANCO)
    # punto lila en la línea base del monograma, como "V."
    dot_r = 34
    dot_x = x + v_w + v_box[0] + 26
    dot_bottom = y + v_box[3]
    d.ellipse([dot_x, dot_bottom - dot_r * 2, dot_x + dot_r * 2, dot_bottom], fill=LILA)

    img.convert("RGB").save(os.path.join(BASE, "icon_512.png"))
    print("icon_512.png listo")


def destacado():
    img = gradiente_diagonal(1024, 500, MORADO_OSCURO, MORADO).convert("RGBA")
    d = ImageDraw.Draw(img)

    # Marca
    f_logo = ImageFont.truetype(FJALLA, 104)
    logo = "VoyContigo"
    lx, ly = 64, 118
    d.text((lx + 4, ly + 5), logo, font=f_logo, fill=(0, 0, 0, 60))
    d.text((lx, ly), logo, font=f_logo, fill=BLANCO)
    ancho_logo = d.textlength(logo, font=f_logo)
    d.ellipse([lx + ancho_logo + 12, ly + 86, lx + ancho_logo + 40, ly + 114], fill=LILA)

    # Tagline y corredor
    f_tag = ImageFont.truetype(PUBLIC, 36)
    d.text((lx + 4, 258), "Tu viaje. Tus reglas.", font=f_tag, fill=(255, 255, 255, 235))
    f_sub = ImageFont.truetype(PUBLIC, 28)
    d.text((lx + 4, 318), "Viajes compartidos por paraderos", font=f_sub, fill=LILA)
    d.text((lx + 4, 356), "Machachi – Quito", font=f_sub, fill=LILA)

    # Motivo de línea de paraderos a la derecha.
    x = 880
    d.line([(x, 92), (x, 408)], fill=(255, 255, 255, 140), width=7)
    d.ellipse([x - 20, 72, x + 20, 112], fill=BLANCO)                      # subes
    d.ellipse([x - 14, 236, x + 14, 264], outline=BLANCO, width=6)        # intermedio
    d.ellipse([x - 20, 388, x + 20, 428], fill=VERDE, outline=BLANCO, width=5)  # bajas

    img.convert("RGB").save(os.path.join(BASE, "feature_1024x500.png"))
    print("feature_1024x500.png listo")


if __name__ == "__main__":
    icono()
    destacado()
