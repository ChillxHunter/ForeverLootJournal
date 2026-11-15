"""Generate the original-style gold, parchment and bronze TGA textures for Forever Loot Journal.
Uses the Python standard library. Run: python tools/generate_media.py
"""
from pathlib import Path
from random import Random
from math import sin, cos, exp
from struct import pack

out = Path(__file__).resolve().parents[1] / "Media"
out.mkdir(parents=True, exist_ok=True)

def byte(n):
    return max(0, min(255, round(n)))

def make_tga(name, width, height, style):
    rng = Random(20261115 + len(name))
    path = out / name
    with path.open("wb") as f:
        # Uncompressed 24-bit TGA, bottom-left pixel origin.
        f.write(pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 24, 0))
        for y in range(height):
            line = bytearray()
            for x in range(width):
                u, v = x / (width - 1), y / (height - 1)
                grain = rng.randint(-9, 9)
                if style == "paper":
                    edge = min(u, 1-u, v, 1-v)
                    stain = max(0, .32-edge)*110
                    wave = 9*sin(u*25+v*10)+7*cos(u*9-v*25)
                    tone = grain + wave - stain
                    r,g,b = 179+tone,149+tone*.85,99+tone*.62
                elif style == "detail":
                    glow = 36*exp(-((v-.48)*7)**2)
                    rim = 45 if y < 4 or y > height-5 else 0
                    r,g,b = 38+glow+rim+grain,29+glow*.77+rim*.76+grain,24+glow*.37+rim*.35+grain
                else:
                    shine = 52*(1-abs(u-.5))*exp(-((v-.55)*2.1)**2)
                    rim = 54 if y < 6 or y > height-8 else 0
                    r,g,b = 40+shine+rim+grain,27+shine*.69+rim*.75+grain*.7,19+shine*.39+rim*.3+grain*.6
                line.extend((byte(b), byte(g), byte(r)))
            f.write(line)
    print(f"{path.name}: {width}x{height}")

make_tga("paper.tga", 512, 512, "paper")
make_tga("detail.tga", 1024, 64, "detail")
make_tga("banner.tga", 1024, 128, "banner")
