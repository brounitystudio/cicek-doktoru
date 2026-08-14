from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"C:\Users\omerc\OneDrive\Masaüstü\çiçek doktoru logo.png")


def resize_cover(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), Image.Resampling.LANCZOS)


def save_png(image: Image.Image, path: Path, size: int | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    output = image if size is None else resize_cover(image, size)
    output.save(path, "PNG", optimize=True)


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")

    # Full brand crop: icon, name, and slogan with the large outer margin removed.
    full_logo = source.crop((120, 205, 1135, 1040))

    # App icon crop: the central pot/stethoscope mark, preserving the designed rounded tile.
    icon_mark = source.crop((375, 205, 885, 715))

    save_png(full_logo, ROOT / "assets" / "brand" / "logo_full.png")
    save_png(icon_mark, ROOT / "assets" / "brand" / "logo_mark.png")

    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_sizes.items():
        save_png(icon_mark, ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png", size)

    web_sizes = {
        "Icon-192.png": 192,
        "Icon-maskable-192.png": 192,
        "Icon-512.png": 512,
        "Icon-maskable-512.png": 512,
    }
    for name, size in web_sizes.items():
        save_png(icon_mark, ROOT / "web" / "icons" / name, size)

    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, size in ios_sizes.items():
        save_png(icon_mark, ios_dir / name, size)


if __name__ == "__main__":
    main()
