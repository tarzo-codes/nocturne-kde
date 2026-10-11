"""Nocturne wallpaper: a generated aurora night sky (shipped default) and the
frosted-glass variant used by the lock screen, splash, logout screen and SDDM.
Everything is rendered with ImageMagick from the palette, so it is MIT-licensed
like the rest of the theme.
"""
import random
import tempfile
from pathlib import Path

from logo import magick
from palette import P

C = P


def generate(dest: Path, w=3840, h=2160, seed=7):
    """Render the default Nocturne wallpaper: aurora curtains over a starry sky and hills."""
    rnd = random.Random(seed)
    dest.parent.mkdir(parents=True, exist_ok=True)
    X = lambda f: int(w * f)
    Y = lambda f: int(h * f)
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        sky, glow, rays, aur, stars, hills = (t / f"{n}.png" for n in
                                              ("sky", "glow", "rays", "aur", "stars", "hills"))
        magick("-size", f"{w}x{h}", f"gradient:#16204a-{C['crust']}", sky)

        def curtain(color, path, width):
            return ["-stroke", color, "-strokewidth", str(width), "-fill", "none", "-draw", f"path '{path}'"]
        mint = f"M {X(.18)},{Y(-.05)} C {X(.40)},{Y(.20)} {X(.55)},{Y(.10)} {X(.66)},{Y(.62)}"
        violet = f"M {X(.02)},{Y(.10)} C {X(.25)},{Y(.30)} {X(.42)},{Y(.30)} {X(.56)},{Y(.66)}"
        blue = f"M {X(.70)},{Y(.05)} C {X(.80)},{Y(.25)} {X(.86)},{Y(.30)} {X(1.02)},{Y(.45)}"
        shapes = (curtain(C["violet"], violet, X(.07)) + curtain(C["mint"], mint, X(.06))
                  + curtain(C["blue"], blue, X(.03)))
        # soft glow of the curtains
        magick("-size", f"{w}x{h}", "xc:black", *shapes, "-blur", f"0x{X(.035)}", glow)
        # vertical light rays: stretched noise, masked by the (less blurred) curtains
        magick("-size", f"{w // 5}x1", "xc:", "-seed", str(seed), "+noise", "Random",
               "-colorspace", "gray", "-resize", f"{w}x{h}!", "-blur", f"0x{max(1, w // 1600)}",
               "-level", "15%,100%", rays)
        magick("-size", f"{w}x{h}", "xc:black", *shapes, "-blur", f"0x{X(.012)}", rays,
               "-compose", "multiply", "-composite", glow, "-compose", "screen", "-composite", aur)
        # stars
        magick("-size", f"{w}x{h}", "xc:", "-seed", str(seed + 1), "+noise", "Random",
               "-channel", "G", "-separate", "+channel", "-threshold", "99.96%",
               *(["-morphology", "Dilate", "Disk:1"] if w >= 3000 else []),
               "-blur", "0x0.8", "-level", "0,55%", stars)

        def ridge(base, rough, color, step):
            pts, x = [f"0,{h}"], 0
            while x <= w + step:
                pts.append(f"{x},{int(h * base - rnd.uniform(0, rough) * h)}")
                x += rnd.randint(step // 2, step)
            pts += [f"{w},{h}"]
            return ["-fill", color, "-draw", "polygon " + " ".join(pts)]
        magick("-size", f"{w}x{h}", "xc:none", *ridge(0.80, 0.16, "#121a30", w // 10),
               *ridge(0.88, 0.09, "#0c1222", w // 16), *ridge(0.95, 0.04, C["crust"], w // 24),
               "-blur", "0x2", hills)
        magick(sky, stars, "-compose", "screen", "-composite", aur, "-compose", "screen", "-composite",
               hills, "-compose", "over", "-composite", "-attenuate", "0.10", "+noise", "Gaussian", dest)
    return dest.exists()


def frost(src: Path, dest: Path, w=1920, h=1080):
    """Frosted glass: heavy blur, palette tint, light grain."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    return magick(src, "-resize", f"{w}x{h}^", "-gravity", "center", "-extent", f"{w}x{h}",
                  "-blur", "0x36", "-fill", C["crust"], "-colorize", "38%",
                  "-attenuate", "0.35", "+noise", "Gaussian", "-quality", "90", dest)
