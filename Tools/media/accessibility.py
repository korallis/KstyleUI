"""Bake the five 32 px dispel letters from the addon's OFL Inter SemiBold font."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main():
    root = Path(__file__).resolve().parents[2]
    target = root / "Media/Textures/Accessibility"
    target.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype(str(root / "Media/Fonts/Inter-SemiBold.ttf"), 26)
    for letter in "MCDPE":
        image = Image.new("RGBA", (32, 32))
        draw = ImageDraw.Draw(image)
        draw.text((16, 16), letter, font=font, anchor="mm", fill="white", stroke_width=2, stroke_fill="black")
        image.save(target / f"Dispel{letter}.png")


if __name__ == "__main__":
    main()
