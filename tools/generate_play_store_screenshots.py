# -*- coding: utf-8 -*-
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "play_store_assets" / "screenshots_phone"
OUT.mkdir(parents=True, exist_ok=True)

BG_PATH = ROOT / "assets" / "backgrounds" / "botanical_background.webp"
LOGO_PATH = ROOT / "assets" / "brand" / "logo_mark.png"
W, H = 1080, 1920

FONT_DIR = Path("C:/Windows/Fonts")


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    path = FONT_DIR / name
    if not path.exists():
        path = FONT_DIR / "arial.ttf"
    return ImageFont.truetype(str(path), size)


F_BLACK = font("arialbd.ttf", 64)
F_TITLE = font("arialbd.ttf", 54)
F_H2 = font("arialbd.ttf", 40)
F_BODY = font("arial.ttf", 31)
F_BODY_B = font("arialbd.ttf", 31)
F_SMALL = font("arial.ttf", 24)
F_SMALL_B = font("arialbd.ttf", 24)
F_CAP_B = font("arialbd.ttf", 21)

COL = {
    "dark": "#184C38",
    "green": "#2F7D57",
    "mint": "#DCEFE1",
    "ink": "#17241D",
    "muted": "#6B776E",
    "warn": "#E9A94F",
    "soil": "#C8A978",
}


def cover_bg() -> Image.Image:
    bg = Image.open(BG_PATH).convert("RGB")
    ratio = max(W / bg.width, H / bg.height)
    resized = bg.resize((int(bg.width * ratio), int(bg.height * ratio)), Image.Resampling.LANCZOS)
    left = (resized.width - W) // 2
    top = (resized.height - H) // 2
    cropped = resized.crop((left, top, left + W, top + H))
    return Image.alpha_composite(cropped.convert("RGBA"), Image.new("RGBA", (W, H), (255, 250, 240, 105)))


def rounded(draw: ImageDraw.ImageDraw, xy, radius: int, fill, outline=None, width: int = 1) -> None:
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def shadow_card(img: Image.Image, xy, radius: int = 34, fill=(255, 255, 255, 245), shadow=(24, 76, 56, 38)):
    x1, y1, x2, y2 = xy
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer_draw = ImageDraw.Draw(layer)
    layer_draw.rounded_rectangle((x1, y1 + 14, x2, y2 + 14), radius=radius, fill=shadow)
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(24)))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=(255, 255, 255, 170), width=2)
    return draw


def draw_wrapped(draw: ImageDraw.ImageDraw, text: str, xy, fnt, fill, width: int, align: str = "left", gap: int = 8):
    x, y = xy
    words = text.split(" ")
    lines, current = [], ""
    for word in words:
        candidate = (current + " " + word).strip()
        if draw.textlength(candidate, font=fnt) <= width or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    for line in lines:
        if align == "center":
            draw.text((x + width / 2, y), line, font=fnt, fill=fill, anchor="ma")
        else:
            draw.text((x, y), line, font=fnt, fill=fill)
        bbox = draw.textbbox((0, 0), line, font=fnt)
        y += bbox[3] - bbox[1] + gap


def phone_status(draw: ImageDraw.ImageDraw) -> None:
    draw.text((80, 50), "11:24", font=F_BODY_B, fill=(20, 35, 28, 230))
    color = (20, 35, 28, 230)
    for i, h in enumerate([14, 22, 30, 38]):
        x = 850 + i * 14
        draw.rounded_rectangle((x, 88 - h, x + 8, 88), radius=3, fill=color)
    draw.arc((920, 48, 980, 108), 215, 325, fill=color, width=5)
    draw.arc((935, 63, 965, 93), 215, 325, fill=color, width=5)
    draw.ellipse((947, 84, 955, 92), fill=color)
    draw.rounded_rectangle((995, 58, 1040, 88), radius=8, outline=color, width=4)
    draw.rectangle((1040, 67, 1046, 79), fill=color)
    draw.rounded_rectangle((1002, 64, 1030, 82), radius=5, fill=color)


def logo(img: Image.Image, x: int, y: int, size: int) -> None:
    mark = Image.open(LOGO_PATH).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    img.alpha_composite(mark, (x, y))


def draw_leaf(draw: ImageDraw.ImageDraw, cx: int, cy: int, size: int, fill) -> None:
    draw.ellipse((cx - size, cy - size // 2, cx + size, cy + size // 2), fill=fill)
    draw.line((cx - size // 2, cy + size // 3, cx + size // 2, cy - size // 3), fill=(255, 255, 255, 170), width=max(2, size // 10))


def draw_camera(draw: ImageDraw.ImageDraw, cx: int, cy: int, size: int, fill) -> None:
    w, h = size, int(size * 0.72)
    draw.rounded_rectangle((cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2), radius=size // 8, outline=fill, width=max(3, size // 13))
    draw.rectangle((cx - w // 5, cy - h // 2 - size // 9, cx + w // 5, cy - h // 2 + 2), fill=fill)
    draw.ellipse((cx - size // 5, cy - size // 5, cx + size // 5, cy + size // 5), outline=fill, width=max(3, size // 14))


def draw_calendar(draw: ImageDraw.ImageDraw, cx: int, cy: int, size: int, fill) -> None:
    w, h = size, size
    draw.rounded_rectangle((cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2), radius=size // 9, outline=fill, width=max(3, size // 14))
    draw.line((cx - w // 2, cy - h // 5, cx + w // 2, cy - h // 5), fill=fill, width=max(3, size // 15))
    draw.line((cx - w // 4, cy - h // 2 - 4, cx - w // 4, cy - h // 3), fill=fill, width=max(3, size // 15))
    draw.line((cx + w // 4, cy - h // 2 - 4, cx + w // 4, cy - h // 3), fill=fill, width=max(3, size // 15))


def draw_badge(draw: ImageDraw.ImageDraw, cx: int, cy: int, size: int, fill) -> None:
    draw.ellipse((cx - size // 2, cy - size // 2, cx + size // 2, cy + size // 2), outline=fill, width=max(3, size // 12))
    draw.line((cx - size // 5, cy + size // 2, cx - size // 5, cy + size // 2 + size // 3), fill=fill, width=max(3, size // 14))
    draw.line((cx + size // 5, cy + size // 2, cx + size // 5, cy + size // 2 + size // 3), fill=fill, width=max(3, size // 14))
    draw.text((cx, cy), "*", font=F_H2, fill=fill, anchor="mm")


def draw_check(draw: ImageDraw.ImageDraw, cx: int, cy: int, size: int, fill, circle: bool = False) -> None:
    if circle:
        draw.ellipse((cx - size // 2, cy - size // 2, cx + size // 2, cy + size // 2), fill=fill)
        line_fill = "white"
    else:
        line_fill = fill
    w = max(5, size // 8)
    draw.line((cx - size // 4, cy, cx - size // 12, cy + size // 5, cx + size // 3, cy - size // 4), fill=line_fill, width=w, joint="curve")


def draw_shield_check(draw: ImageDraw.ImageDraw, cx: int, cy: int, size: int, fill) -> None:
    points = [
        (cx, cy - size // 2),
        (cx + size // 2, cy - size // 4),
        (cx + size // 3, cy + size // 3),
        (cx, cy + size // 2),
        (cx - size // 3, cy + size // 3),
        (cx - size // 2, cy - size // 4),
    ]
    draw.line(points + [points[0]], fill=fill, width=max(5, size // 12), joint="curve")
    draw_check(draw, cx, cy + 2, size // 2, fill)


def draw_sparkle(draw: ImageDraw.ImageDraw, cx: int, cy: int, size: int, fill) -> None:
    draw.polygon([(cx, cy - size), (cx + size // 4, cy - size // 4), (cx + size, cy), (cx + size // 4, cy + size // 4), (cx, cy + size), (cx - size // 4, cy + size // 4), (cx - size, cy), (cx - size // 4, cy - size // 4)], fill=fill)


def draw_nav_icon(draw: ImageDraw.ImageDraw, kind: str, cx: int, cy: int, color) -> None:
    if kind == "home":
        draw.polygon([(cx - 28, cy), (cx, cy - 26), (cx + 28, cy), (cx + 28, cy + 30), (cx - 28, cy + 30)], outline=color)
        draw.line((cx - 18, cy + 30, cx - 18, cy + 3, cx + 18, cy + 3, cx + 18, cy + 30), fill=color, width=4)
    elif kind == "camera":
        draw_camera(draw, cx, cy + 8, 54, color)
    elif kind == "plants":
        draw_leaf(draw, cx - 13, cy + 8, 18, color)
        draw_leaf(draw, cx + 15, cy, 18, color)
        draw.line((cx, cy + 28, cx, cy - 18), fill=color, width=4)
    elif kind == "calendar":
        draw_calendar(draw, cx, cy + 8, 52, color)
    else:
        draw.ellipse((cx - 15, cy - 20, cx + 15, cy + 10), outline=color, width=5)
        draw.arc((cx - 32, cy + 0, cx + 32, cy + 58), 200, 340, fill=color, width=5)


def bottom_nav(img: Image.Image, draw: ImageDraw.ImageDraw, active: str) -> None:
    shadow_card(img, (58, 1690, 1022, 1848), radius=48, fill=(255, 255, 255, 235), shadow=(24, 76, 56, 28))
    items = [("home", "Ana Sayfa"), ("camera", "Tara"), ("plants", "Bitkilerim"), ("calendar", "Takvim"), ("profile", "Profil")]
    for (icon, label), x in zip(items, [160, 340, 540, 720, 900]):
        selected = label == active
        if selected:
            rounded(draw, (x - 62, 1708, x + 62, 1816), 40, COL["mint"])
        color = COL["dark"] if selected else COL["muted"]
        draw_nav_icon(draw, icon, x, 1735, color)
        draw.text((x, 1800), label, font=F_CAP_B, fill=color, anchor="mm")


def save(img: Image.Image, name: str) -> Path:
    path = OUT / name
    img.convert("RGB").save(path, quality=92, optimize=True)
    return path


def screenshot_1() -> Path:
    img, draw = cover_bg(), None
    draw = ImageDraw.Draw(img)
    phone_status(draw)
    logo(img, 70, 135, 130)
    shadow_card(img, (90, 590, 990, 750), radius=58, fill=(255, 255, 255, 232))
    draw.text((230, 670), "ÜCRETSİZ KULLANILABİLİR", font=F_H2, fill=COL["dark"], anchor="lm")
    rounded(draw, (115, 625, 205, 715), 30, COL["mint"])
    draw_leaf(draw, 160, 670, 28, COL["green"])
    draw_sparkle(draw, 905, 670, 22, COL["warn"])
    shadow_card(img, (340, 850, 680, 1190), radius=58, fill=(255, 255, 255, 248))
    draw_shield_check(draw, 510, 1020, 145, COL["green"])
    draw_wrapped(draw, "Bakım geçmişin hesabında güvende kalsın.", (90, 1280), F_BLACK, COL["ink"], 900, "center", 12)
    draw_wrapped(draw, "Teşhislerin, bitki listen ve premium hakların Google hesabınla eşleşir.", (120, 1455), F_BODY, COL["muted"], 840, "center")
    rounded(draw, (70, 1660, 1010, 1780), 34, COL["green"])
    draw.text((540, 1720), "Google ile devam et", font=F_BODY_B, fill="white", anchor="mm")
    draw.text((540, 1830), "Satın alma gerekmeden Google hesabınla devam edebilirsin.", font=F_SMALL, fill=COL["muted"], anchor="mm")
    return save(img, "01_onboarding_google.png")


def screenshot_2() -> Path:
    img = cover_bg()
    draw = ImageDraw.Draw(img)
    phone_status(draw)
    logo(img, 62, 95, 110)
    draw.text((190, 120), "Çiçek Doktoru", font=F_TITLE, fill=COL["dark"])
    draw.text((190, 185), "Bitkilerini iyi, sen rahat ol.", font=F_BODY, fill=COL["muted"])
    shadow_card(img, (70, 300, 1010, 520), radius=42, fill=(24, 76, 56, 245))
    draw.text((110, 355), "Bugünkü bakım özeti", font=F_H2, fill="white")
    draw.text((110, 420), "Sulama, kontrol ve son teşhislerin tek ekranda.", font=F_BODY, fill=(255, 255, 255, 210))
    for i, (icon, label, color) in enumerate([("camera", "Tara", COL["green"]), ("plus", "Bitki ekle", COL["green"]), ("calendar", "Takvim", COL["warn"]), ("badge", "Premium", COL["warn"])]):
        x = 85 + i * 245
        shadow_card(img, (x, 595, x + 210, 755), radius=30, fill=(255, 255, 255, 235))
        if icon == "camera":
            draw_camera(draw, x + 105, 645, 44, color)
        elif icon == "plus":
            draw.line((x + 86, 645, x + 124, 645), fill=color, width=6)
            draw.line((x + 105, 626, x + 105, 664), fill=color, width=6)
        elif icon == "calendar":
            draw_calendar(draw, x + 105, 645, 44, color)
        else:
            draw_badge(draw, x + 105, 636, 42, color)
        draw.text((x + 105, 710), label, font=F_CAP_B, fill=color, anchor="mm")
    draw.text((70, 840), "Bakım özeti", font=F_H2, fill=COL["dark"])
    rows = [
        ("Bugün bakım bekleyen bitkiler", "Bugün için planlı bakım görevi yok", "Rahat", "leaf", COL["green"]),
        ("Kontrol zamanı gelen bitkiler", "2 bitki için yaprak ve toprak kontrolü", "Kontrol", "shield", COL["warn"]),
        ("Son teşhisler", "Barış Çiçeği görüntüye göre orta seviyede", "Orta", "refresh", COL["soil"]),
    ]
    for idx, (title, sub, badge, icon, color) in enumerate(rows):
        y = 900 + idx * 185
        shadow_card(img, (70, y, 1010, y + 145), radius=34, fill=(255, 255, 255, 238))
        rounded(draw, (105, y + 34, 175, y + 104), 24, COL["mint"] if idx == 0 else "#FFF1DA")
        if icon == "leaf":
            draw_leaf(draw, 140, y + 70, 22, color)
        elif icon == "shield":
            draw_shield_check(draw, 140, y + 70, 42, color)
        else:
            draw.arc((118, y + 48, 162, y + 92), 40, 330, fill=color, width=5)
            draw.polygon([(158, y + 51), (170, y + 65), (151, y + 67)], fill=color)
        draw.text((205, y + 36), title, font=F_BODY_B, fill=COL["ink"])
        draw.text((205, y + 82), sub, font=F_SMALL, fill=COL["muted"])
        rounded(draw, (790, y + 48, 940, y + 96), 24, "#EAF5ED")
        draw.text((865, y + 72), badge, font=F_CAP_B, fill=COL["green"], anchor="mm")
    bottom_nav(img, draw, "Ana Sayfa")
    return save(img, "02_home_care_summary.png")


def screenshot_3() -> Path:
    img = cover_bg()
    draw = ImageDraw.Draw(img)
    phone_status(draw)
    draw.text((70, 130), "Bitkini Tara", font=F_TITLE, fill=COL["dark"])
    draw_wrapped(draw, "Fotoğraf ve kısa bakım cevaplarıyla AI destekli yorum al.", (70, 205), F_BODY, COL["muted"], 900)
    questions = [
        ("Bitki nerede duruyor?", ["İç mekân", "Dış mekân"], 0),
        ("En son ne zaman suladın?", ["Bugün", "1-3 gün önce", "Hatırlamıyorum"], 2),
        ("Güneş görüyor mu?", ["Direkt güneş", "Aydınlık ama direkt değil", "Az ışık"], 1),
        ("Saksının altında delik var mı?", ["Evet", "Hayır", "Bilmiyorum"], 0),
    ]
    for i, (question, options, selected) in enumerate(questions):
        y = 360 + i * 265
        shadow_card(img, (70, y, 1010, y + 205), radius=34, fill=(255, 255, 255, 240))
        draw.text((110, y + 45), question, font=F_BODY_B, fill=COL["ink"])
        x, yy = 110, y + 105
        for j, option in enumerate(options):
            pill_w = int(draw.textlength(option, font=F_CAP_B) + 44)
            fill = COL["green"] if j == selected else "#DDEFE3"
            text_color = "white" if j == selected else COL["green"]
            rounded(draw, (x, yy, x + pill_w, yy + 52), 26, fill)
            label_x = x + pill_w / 2
            if j == selected:
                draw_check(draw, x + 22, yy + 27, 22, "white")
                label_x += 8
            draw.text((label_x, yy + 26), option, font=F_CAP_B, fill=text_color, anchor="mm")
            x += pill_w + 14
            if x > 820:
                x, yy = 110, yy + 64
    rounded(draw, (70, 1500, 1010, 1620), 34, COL["green"])
    draw.text((540, 1560), "Teşhisi Başlat", font=F_BODY_B, fill="white", anchor="mm")
    bottom_nav(img, draw, "Tara")
    return save(img, "03_scan_questions.png")


def screenshot_4() -> Path:
    img = cover_bg()
    draw = ImageDraw.Draw(img)
    phone_status(draw)
    draw.line((95, 125, 62, 158, 95, 191), fill=COL["dark"], width=8, joint="curve")
    draw.text((160, 135), "Teşhis Sonucu", font=F_TITLE, fill=COL["dark"])
    shadow_card(img, (70, 260, 1010, 585), radius=42, fill=(232, 239, 225, 245))
    for x in [430, 505, 580]:
        draw.rounded_rectangle((x, 320, x + 42, 520), radius=22, fill="#486C4E")
        draw.ellipse((x - 20, 310, x + 60, 405), fill="#5E875F")
    shadow_card(img, (70, 650, 1010, 900), radius=42, fill=(24, 76, 56, 248))
    rounded(draw, (110, 700, 205, 795), 28, (255, 255, 255, 34))
    draw_leaf(draw, 157, 747, 28, "#BDE2C5")
    draw.text((235, 705), "Paşa kılıcı", font=F_TITLE, fill="white")
    draw.text((235, 770), "(Sansevieria)", font=F_H2, fill="white")
    for i, text in enumerate(["70/100 sağlık", "Orta", "Görüntü yeterli"]):
        x = [110, 360, 610][i]
        y = 825
        rounded(draw, (x, y, x + 220, y + 60), 30, "#376D51", outline=(230, 190, 90, 150), width=2)
        draw.text((x + 110, y + 30), text, font=F_CAP_B, fill="white", anchor="mm")
    shadow_card(img, (70, 1000, 1010, 1185), radius=38, fill=(255, 255, 255, 242))
    draw.text((300, 1040), "Bitki Sağlığı: %70", font=F_H2, fill=COL["ink"])
    draw.text((300, 1110), "Orta", font=F_TITLE, fill=COL["warn"])
    draw.ellipse((110, 1020, 250, 1160), outline="#F2E7CF", width=28)
    draw.arc((110, 1020, 250, 1160), -90, 160, fill=COL["warn"], width=28)
    shadow_card(img, (70, 1265, 1010, 1585), radius=38, fill=(255, 255, 255, 242))
    draw.text((110, 1310), "7 Günlük Bakım Planı", font=F_H2, fill=COL["ink"])
    for i, text in enumerate(["Toprak tamamen kurumadan sulama yapma.", "Saksı tabağında su bırakma.", "Aynı açıdan tekrar fotoğraf çek."]):
        draw.text((120, 1380 + i * 58), "•", font=F_BODY_B, fill=COL["green"])
        draw.text((160, 1382 + i * 58), text, font=F_BODY, fill=COL["ink"])
    bottom_nav(img, draw, "Tara")
    return save(img, "04_diagnosis_result.png")


def screenshot_5() -> Path:
    img = cover_bg()
    draw = ImageDraw.Draw(img)
    phone_status(draw)
    draw.text((70, 130), "Bitkilerim", font=F_TITLE, fill=COL["dark"])
    draw_wrapped(draw, "Sağlık, görev ve gelişim durumları bir arada.", (70, 205), F_BODY, COL["muted"], 900)
    plants = [("Paşa kılıcı", "Orta seviye bakım", 70, COL["warn"]), ("Barış Çiçeği", "Sulama kontrolü", 82, COL["green"]), ("Orkide", "Yaklaşan görev", 64, COL["soil"])]
    for i, (name, status, score, color) in enumerate(plants):
        y = 360 + i * 300
        shadow_card(img, (70, y, 1010, y + 230), radius=40, fill=(255, 255, 255, 242))
        rounded(draw, (105, y + 35, 240, y + 175), 34, COL["mint"])
        draw_leaf(draw, 172, y + 105, 36, COL["green"])
        draw.text((275, y + 45), name, font=F_H2, fill=COL["ink"])
        draw.text((275, y + 100), status, font=F_BODY, fill=COL["muted"])
        rounded(draw, (275, y + 150, 455, y + 200), 25, "#EAF5ED")
        draw.text((365, y + 175), f"{score}/100", font=F_CAP_B, fill=COL["green"], anchor="mm")
        rounded(draw, (760, y + 60, 930, y + 120), 28, color)
        draw.text((845, y + 90), "Bakım", font=F_CAP_B, fill="white", anchor="mm")
    shadow_card(img, (70, 1260, 1010, 1440), radius=38, fill=(24, 76, 56, 245))
    draw.text((110, 1310), "Gelişim takibi", font=F_H2, fill="white")
    draw.text((110, 1365), "Aynı açıdan çekilen fotoğraflarla değişimi izle.", font=F_BODY, fill=(255, 255, 255, 210))
    bottom_nav(img, draw, "Bitkilerim")
    return save(img, "05_my_plants.png")


def screenshot_6() -> Path:
    img = cover_bg()
    draw = ImageDraw.Draw(img)
    phone_status(draw)
    draw.text((70, 130), "Çiçek Doktoru Premium", font=F_TITLE, fill=COL["dark"])
    draw_wrapped(draw, "Daha fazla teşhis, reklamsız kullanım ve detaylı bakım planları.", (70, 205), F_BODY, COL["muted"], 900)
    shadow_card(img, (70, 310, 1010, 1040), radius=42, fill=(24, 76, 56, 248))
    draw.text((110, 370), "Aylık Premium", font=F_TITLE, fill="white")
    draw.text((110, 455), "₺69,99 / ay", font=F_BLACK, fill="white")
    benefits = ["Ayda 100 detaylı AI teşhis", "Reklamsız kullanım", "Sınırsız bitki kaydetme", "7 günlük kurtarma planı"]
    for i, text in enumerate(benefits):
        y = 560 + i * 80
        draw_check(draw, 132, y + 17, 34, "#BDE2C5", circle=True)
        draw.text((170, y), text, font=F_BODY, fill="white")
    rounded(draw, (110, 900, 930, 1000), 32, "#2F8A60")
    draw.text((520, 950), "Premium’a Geç", font=F_BODY_B, fill="white", anchor="mm")
    shadow_card(img, (70, 1115, 1010, 1540), radius=40, fill=(255, 255, 255, 240))
    draw.text((110, 1160), "Free ve Premium farkı", font=F_H2, fill=COL["dark"])
    rows = [("Teşhis", "Günlük sınırlı", "100/ay"), ("Bitki", "3 kayıt", "Sınırsız"), ("Reklam", "Var", "Yok"), ("Plan", "Temel", "Detaylı")]
    for i, (label, free, premium) in enumerate(rows):
        y = 1245 + i * 75
        draw.text((110, y), label, font=F_BODY_B, fill=COL["ink"])
        draw.text((450, y), free, font=F_SMALL, fill=COL["muted"])
        rounded(draw, (700, y - 8, 930, y + 42), 25, "#EAF5ED")
        draw.text((815, y + 17), premium, font=F_CAP_B, fill=COL["green"], anchor="mm")
    bottom_nav(img, draw, "Profil")
    return save(img, "06_premium.png")


if __name__ == "__main__":
    for maker in [screenshot_1, screenshot_2, screenshot_3, screenshot_4, screenshot_5, screenshot_6]:
        print(maker())
