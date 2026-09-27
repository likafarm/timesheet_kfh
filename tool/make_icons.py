"""Иконка программы: зелёный квадрат, белый календарь с галочкой.

Рисуется крупно (1024 px) и уменьшается (UI_REQUIREMENTS п. 2.1). Выход:
- android/app/src/main/res/mipmap-*/ic_launcher.png — обычная иконка;
- android/app/src/main/res/mipmap-*/ic_launcher_foreground.png — слой
  адаптивной иконки (Android 8+), фон — цвет ic_launcher_background;
- android/app/src/main/res/drawable-nodpi/splash_logo.png — заставка;
- windows/runner/resources/app_icon.ico — 16…256 px;
- web/favicon.png, web/icons/*.png — веб-версия (maskable — на зелёном
  квадрате без скругления: браузер сам обрежет по форме).

Запуск из корня репозитория: python tool/make_icons.py (нужен Pillow).
"""

from PIL import Image, ImageDraw

GREEN = (46, 125, 50, 255)  # AppTheme.primaryColor
DARK = (27, 94, 32, 255)  # AppTheme.secondaryColor
WHITE = (255, 255, 255, 255)
S = 1024


def calendar(size, box):
    """Календарь с галочкой в квадрате box = (x0, y0, x1, y1) на прозрачном
    холсте size×size."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    w = x1 - x0
    u = w / 20  # единица сетки
    top = y0 + 2 * u
    # лист календаря
    d.rounded_rectangle((x0, top, x1, y1), radius=2 * u, fill=WHITE)
    # шапка
    d.rounded_rectangle((x0, top, x1, top + 5 * u), radius=2 * u, fill=DARK)
    d.rectangle((x0, top + 3 * u, x1, top + 5 * u), fill=DARK)
    # кольца
    for cx in (x0 + 5.5 * u, x1 - 5.5 * u):
        d.rounded_rectangle(
            (cx - u, y0, cx + u, top + 3 * u), radius=u, fill=WHITE
        )
    # клетки дней 4×3
    cell, gap = 2.6 * u, 1.0 * u
    gx0, gy0 = x0 + (w - 4 * cell - 3 * gap) / 2, top + 7 * u
    for r in range(3):
        for c in range(4):
            cx = gx0 + c * (cell + gap)
            cy = gy0 + r * (cell + gap)
            d.rounded_rectangle(
                (cx, cy, cx + cell, cy + cell),
                radius=0.6 * u,
                fill=(200, 230, 201, 255),
            )
    # галочка поверх
    pts = [
        (x0 + 5 * u, top + 12.5 * u),
        (x0 + 9 * u, top + 16.5 * u),
        (x0 + 16 * u, top + 8.5 * u),
    ]
    d.line(pts, fill=GREEN, width=int(2.6 * u), joint='curve')
    for p in (pts[0], pts[2]):
        r = 1.3 * u
        d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=GREEN)
    return img


def full_icon():
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle((0, 0, S - 1, S - 1), radius=S * 0.2, fill=GREEN)
    m = S * 0.18
    img.alpha_composite(calendar(S, (m, m, S - m, S - m)))
    return img


def foreground():
    # Адаптивная иконка: видимая часть — круг ~66/108 в центре.
    m = S * 0.30
    return calendar(S, (m, m, S - m, S - m))


def main():
    icon = full_icon()
    fg = foreground()
    res = 'android/app/src/main/res'
    for name, px in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
    }.items():
        icon.resize((px, px), Image.LANCZOS).save(f'{res}/mipmap-{name}/ic_launcher.png')
        fpx = px * 108 // 48
        fg.resize((fpx, fpx), Image.LANCZOS).save(
            f'{res}/mipmap-{name}/ic_launcher_foreground.png'
        )
    import os

    os.makedirs(f'{res}/drawable-nodpi', exist_ok=True)
    icon.resize((288, 288), Image.LANCZOS).save(f'{res}/drawable-nodpi/splash_logo.png')
    icon.save(
        'windows/runner/resources/app_icon.ico',
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


def web_icons():
    icon = full_icon()
    icon.resize((32, 32), Image.LANCZOS).save('web/favicon.png')
    maskable = Image.new('RGBA', (S, S), GREEN)
    maskable.alpha_composite(foreground())
    for px in (192, 512):
        icon.resize((px, px), Image.LANCZOS).save(f'web/icons/Icon-{px}.png')
        maskable.resize((px, px), Image.LANCZOS).save(
            f'web/icons/Icon-maskable-{px}.png'
        )


if __name__ == '__main__':
    main()
    web_icons()
