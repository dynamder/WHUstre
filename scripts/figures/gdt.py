"""形位公差插图工具箱：用 Python 描述工程图图元，先输出 SVG，再栅格化为 PNG。

坐标单位是「绘图单位」（约等于 1 设计像素）。画布用 viewBox 缩放，
`Fig.render(scale=2.4)` 会把 1 单位放大成 2.4 个输出像素，得到打印级的清晰度。

用法：
    from gdt import Fig, INK, RED
    f = Fig(520, 240)
    f.centerline(20, 120, 500, 120)
    f.line(60, 60, 400, 60, w=2.4)
    f.dim_v(60, 120, 34, "φ40")          # 垂直尺寸
    f.frame(80, 20, [("sym", "roundness"), ("val", "0.01"), ("dat", "A")])
    f.save("courses/interchangeability/src/assets/figs/demo.png")

依赖：Python 3 标准库 + ImageMagick（`magick`）或 rsvg-convert / cairosvg 之一。
中文字体优先 Microsoft YaHei，其次 SimHei / Noto Sans CJK。
"""

from __future__ import annotations

import math
import os
import shutil
import subprocess
import sys

INK = "#1a1a1a"
THICK = "#111111"
GRAY = "#8a8a8a"
RED = "#c62828"
BLUE = "#1a4fa0"
LIGHT_BLUE = "#dde9f7"
FILL = "#eef3f8"

FONT = "Microsoft YaHei, Microsoft YaHei UI, SimHei, Noto Sans CJK SC, sans-serif"

# 线宽约定（仿 GB 制图：粗线 : 细线 ≈ 2 : 1）
W_THICK = 2.4
W_THIN = 1.1
W_THINNER = 0.8


def _fmt(v: float) -> str:
    return f"{v:.2f}".rstrip("0").rstrip(".")


def text_width(s: str, size: float) -> float:
    """估算字串宽度：CJK 按 1.0 em，ASCII 按 0.58 em。"""
    w = 0.0
    for ch in s:
        w += size * (1.0 if ord(ch) > 0x2E7F else 0.58)
    return w


class Fig:
    def __init__(self, w: float, h: float, bg: str = "#ffffff"):
        self.w = w
        self.h = h
        self.bg = bg
        self.els: list[str] = []

    # ---------- 基本图元 ----------
    def add(self, s: str) -> None:
        self.els.append(s)

    def line(self, x1, y1, x2, y2, w=W_THIN, color=INK, dash=None, cap="butt", opacity=None):
        extra = ""
        if dash:
            extra += f' stroke-dasharray="{dash}"'
        if cap != "butt":
            extra += f' stroke-linecap="{cap}"'
        if opacity is not None:
            extra += f' opacity="{opacity}"'
        self.add(
            f'<line x1="{_fmt(x1)}" y1="{_fmt(y1)}" x2="{_fmt(x2)}" y2="{_fmt(y2)}" '
            f'stroke="{color}" stroke-width="{_fmt(w)}"{extra}/>'
        )

    def poly(self, pts, w=W_THIN, color=INK, close=False, fill="none", dash=None):
        d = " ".join(f"{_fmt(x)},{_fmt(y)}" for x, y in pts)
        tag = "polygon" if close else "polyline"
        extra = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(
            f'<{tag} points="{d}" fill="{fill}" stroke="{color}" stroke-width="{_fmt(w)}"'
            f' stroke-linejoin="round"{extra}/>'
        )

    def fillpoly(self, pts, fill=FILL):
        self.poly(pts, close=True, fill=fill, color="none", w=0)

    def rect(self, x, y, w, h, sw=W_THIN, color=INK, fill="none", rx=0):
        self.add(
            f'<rect x="{_fmt(x)}" y="{_fmt(y)}" width="{_fmt(w)}" height="{_fmt(h)}" '
            f'fill="{fill}" stroke="{color}" stroke-width="{_fmt(sw)}" rx="{_fmt(rx)}"/>'
        )

    def circle(self, cx, cy, r, sw=W_THIN, color=INK, fill="none"):
        self.add(
            f'<circle cx="{_fmt(cx)}" cy="{_fmt(cy)}" r="{_fmt(r)}" fill="{fill}" '
            f'stroke="{color}" stroke-width="{_fmt(sw)}"/>'
        )

    def dot(self, cx, cy, r=2.2, color=INK):
        self.circle(cx, cy, r, sw=0, color=color, fill=color)

    def text(self, x, y, s, size=13, anchor="middle", color=INK, italic=False,
             weight="normal", rotate=None, baseline="middle", opacity=None):
        style = f'font-family="{FONT}" font-size="{_fmt(size)}"'
        if italic:
            style += ' font-style="italic"'
        if weight != "normal":
            style += f' font-weight="{weight}"'
        if opacity is not None:
            style += f' opacity="{opacity}"'
        tr = f' transform="rotate({rotate} {_fmt(x)} {_fmt(y)})"' if rotate else ""
        s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        self.add(
            f'<text x="{_fmt(x)}" y="{_fmt(y)}" fill="{color}" {style} '
            f'text-anchor="{anchor}" dominant-baseline="{baseline}"{tr}>{s}</text>'
        )

    # ---------- 工程图常用线型 ----------
    def centerline(self, x1, y1, x2, y2, w=W_THINNER):
        self.line(x1, y1, x2, y2, w=w, dash="16,4,3,4")

    def hiddenline(self, x1, y1, x2, y2, w=W_THINNER):
        self.line(x1, y1, x2, y2, w=w, dash="6,3")

    def hatch(self, pts, spacing=7.0, angle=45.0, w=0.7, color=INK):
        """在凸/凹多边形内按角度画剖面线（扫描线求交）。"""
        a = math.radians(angle)
        dx, dy = math.cos(a), math.sin(a)
        nx, ny = -dy, dx
        proj = [x * nx + y * ny for x, y in pts]
        lo, hi = min(proj), max(proj)
        k = math.ceil((hi - lo) / spacing)
        for i in range(k + 1):
            c = lo + i * spacing
            hits = []
            n = len(pts)
            for j in range(n):
                x1, y1 = pts[j]
                x2, y2 = pts[(j + 1) % n]
                p1 = x1 * nx + y1 * ny - c
                p2 = x2 * nx + y2 * ny - c
                if p1 == 0 and p2 == 0:
                    continue
                if (p1 <= 0 < p2) or (p2 <= 0 < p1):
                    t = p1 / (p1 - p2) if p1 != p2 else 0
                    hits.append((x1 + t * (x2 - x1), y1 + t * (y2 - y1)))
            hits.sort(key=lambda p: p[0] * dx + p[1] * dy)
            for j in range(0, len(hits) - 1, 2):
                (ax, ay), (bx, by) = hits[j], hits[j + 1]
                self.line(ax, ay, bx, by, w=w, color=color)

    # ---------- 箭头与尺寸 ----------
    def arrowhead(self, x, y, ang, size=9.0, color=INK, half=3.0):
        """在 (x,y) 处画一个指向 ang 角度（度）的实心箭头。"""
        a = math.radians(ang)
        bx, by = x - size * math.cos(a), y - size * math.sin(a)
        px, py = -math.sin(a) * half, math.cos(a) * half
        self.poly(
            [(x, y), (bx + px, by + py), (bx - px, by - py)],
            w=0.4, color=color, close=True, fill=color,
        )

    def leader(self, pts, head=True, tail=False, w=W_THIN, color=INK, size=9.0):
        self.poly(pts, w=w, color=color)
        if head:
            (x1, y1), (x2, y2) = pts[-2], pts[-1]
            ang = math.degrees(math.atan2(y2 - y1, x2 - x1)) if (x2 - x1 or y2 - y1) else 0
            self.arrowhead(x2, y2, ang, size=size, color=color)
        if tail:
            (x1, y1), (x2, y2) = pts[0], pts[1]
            ang = math.degrees(math.atan2(y1 - y2, x1 - x2))
            self.arrowhead(x1, y1, ang, size=size, color=color)

    def dim_h(self, x1, x2, y, label, ext_y=None, size=12.5, above=-7,
              color=INK, out=False, thin=W_THINNER):
        """水平尺寸：x1..x2 两点、尺寸线在 y，尺寸界线从 ext_y 引到 y。"""
        if ext_y is not None:
            self.line(x1, ext_y, x1, y + (7 if out else 0), w=thin, color=color)
            self.line(x2, ext_y, x2, y + (7 if out else 0), w=thin, color=color)
        if out:
            self.line(x1 - 14, y, x1, y, w=W_THIN, color=color)
            self.line(x2, y, x2 + 14, y, w=W_THIN, color=color)
            self.arrowhead(x1, y, 0, color=color)
            self.arrowhead(x2, y, 180, color=color)
        else:
            self.line(x1, y, x2, y, w=W_THIN, color=color)
            self.arrowhead(x1, y, 180, color=color)
            self.arrowhead(x2, y, 0, color=color)
        if label:
            self.text((x1 + x2) / 2, y + above, label, size=size, color=color)

    def dim_v(self, y1, y2, x, label, ext_x=None, size=12.5, left=8,
              color=INK, out=False, thin=W_THINNER):
        """垂直尺寸：y1..y2、尺寸线在 x。"""
        if ext_x is not None:
            self.line(ext_x, y1, x + (7 if out else 0), y1, w=thin, color=color)
            self.line(ext_x, y2, x + (7 if out else 0), y2, w=thin, color=color)
        if out:
            self.line(x, y1 - 14, x, y1, w=W_THIN, color=color)
            self.line(x, y2, x, y2 + 14, w=W_THIN, color=color)
            self.arrowhead(x, y1, 90, color=color)
            self.arrowhead(x, y2, 270, color=color)
        else:
            self.line(x, y1, x, y2, w=W_THIN, color=color)
            self.arrowhead(x, y1, 90, color=color)
            self.arrowhead(x, y2, 270, color=color)
        if label:
            self.text(x - left, (y1 + y2) / 2, label, size=size, color=color, rotate=-90)

    # ---------- 形位公差框格 ----------
    def frame(self, x, y, cells, h=24, size=13.5, color=INK, sw=W_THIN,
              anchor="left", stretch=None):
        """画一个公差框格。cells = [("sym","roundness"), ("val","φ0.02"), ("dat","A")]。

        返回 dict：x0/x1/y0/y1/cy（cy 是框格中线，便于接指引线）。
        anchor="right" 时 x 解释为框格右端。
        """
        widths = []
        for kind, val in cells:
            if kind == "sym":
                widths.append(26 if h >= 22 else 22)
            elif kind == "dat":
                widths.append(max(20, text_width(val, size) + 12))
            elif kind in ("val", "txt"):
                widths.append(max(34, text_width(val, size) + 16))
            else:
                raise ValueError(kind)
        total = sum(widths)
        if stretch:
            widths = [wd * stretch for wd in widths]
            total = sum(widths)
        x0 = x - total if anchor == "right" else x
        cur = x0
        for (kind, val), wd in zip(cells, widths):
            self.rect(cur, y, wd, h, sw=sw, color=color)
            cx, cy = cur + wd / 2, y + h / 2
            if kind == "sym":
                draw_symbol(self, val, cx, cy, min(h * 0.62, 17))
            elif kind == "val":
                # 公差值整体居中；φ/Ⓜ 等修饰符用同一字号排出
                self.text(cx, cy + 0.5, val, size=size, color=color,
                          weight="normal")
            else:
                self.text(cx, cy + 0.5, val, size=size, color=color)
            cur += wd
        return {"x0": x0, "x1": x0 + total, "y0": y, "y1": y + h, "cy": y + h / 2}

    def datum(self, x, y, direction, letter, size=12.5, tri=7.0, gap=9.0,
              box=20.0, color=INK):
        """基准符号：涂黑三角形贴要素，细实线引出方框字母。

        direction: 'up' / 'down' / 'left' / 'right' —— 三角形尖端离开材料的方向。
        (x, y) 是三角形底边中点（即贴在要素轮廓上的点）。
        """
        base = 11.0
        if direction in ("up", "down"):
            s = -1 if direction == "up" else 1
            self.poly([(x - base / 2, y), (x + base / 2, y), (x, y + s * tri)],
                      w=0.4, close=True, fill=color, color=color)
            ly0, ly1 = y + s * tri, y + s * (tri + gap)
            self.line(x, ly0, x, ly1, w=W_THIN, color=color)
            self.rect(x - box / 2, ly1 if s > 0 else ly1 - box, box, box, sw=W_THIN, color=color)
            self.text(x, ly1 + (box / 2 if s > 0 else -box / 2) + 0.5, letter,
                      size=size, color=color)
        else:
            s = -1 if direction == "left" else 1
            self.poly([(x, y - base / 2), (x, y + base / 2), (x + s * tri, y)],
                      w=0.4, close=True, fill=color, color=color)
            lx0, lx1 = x + s * tri, x + s * (tri + gap)
            self.line(lx0, y, lx1, y, w=W_THIN, color=color)
            self.rect(lx1 if s > 0 else lx1 - box, y - box / 2, box, box, sw=W_THIN, color=color)
            self.text(lx1 + (box / 2 if s > 0 else -box / 2), y + 0.5, letter,
                      size=size, color=color)

    # ---------- 批注 ----------
    def note(self, x, y, s, size=11.5, color=RED, anchor="start", weight="bold"):
        self.text(x, y, s, size=size, color=color, anchor=anchor, weight=weight)

    def badge(self, n, x, y, r=8.5, color=RED):
        self.circle(x, y, r, sw=0, color=color, fill=color)
        self.text(x, y + 0.5, str(n), size=11, color="#ffffff", weight="bold")

    def mark_circle(self, cx, cy, rx, ry, color=RED, w=1.6, dash=None):
        self.add(
            f'<ellipse cx="{_fmt(cx)}" cy="{_fmt(cy)}" rx="{_fmt(rx)}" ry="{_fmt(ry)}" '
            f'fill="none" stroke="{color}" stroke-width="{_fmt(w)}"'
            + (f' stroke-dasharray="{dash}"' if dash else "")
            + "/>"
        )

    def mark_cross(self, cx, cy, r, color=RED, w=2.0):
        self.line(cx - r, cy - r, cx + r, cy + r, w=w, color=color)
        self.line(cx + r, cy - r, cx - r, cy + r, w=w, color=color)

    # ---------- 输出 ----------
    def svg(self, scale=2.4) -> str:
        head = (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{_fmt(self.w * scale)}" '
            f'height="{_fmt(self.h * scale)}" viewBox="0 0 {_fmt(self.w)} {_fmt(self.h)}">\n'
            f'<rect x="0" y="0" width="{_fmt(self.w)}" height="{_fmt(self.h)}" fill="{self.bg}"/>\n'
        )
        return head + "\n".join(self.els) + "\n</svg>\n"

    def save(self, png_path: str, svg_path: str | None = None, scale=2.4):
        """输出 PNG；SVG 只作为中间文件，默认不留在书里（避免 mdbook 把 SVG 一起发布）。"""
        os.makedirs(os.path.dirname(os.path.abspath(png_path)), exist_ok=True)
        tmp = svg_path is None
        if tmp:
            svg_path = png_path + ".tmp.svg"
        with open(svg_path, "w", encoding="utf-8") as fp:
            fp.write(self.svg(scale=scale))
        try:
            rasterize(svg_path, png_path)
        finally:
            if tmp and os.path.exists(svg_path):
                os.remove(svg_path)
        print(f"  -> {png_path}")


# ---------------- 形位公差项目符号 ----------------

def _sym_circle(f, cx, cy, s, lw):
    f.circle(cx, cy, s * 0.52, sw=lw, color=INK)


def _sym_cylindricity(f, cx, cy, s, lw):
    f.circle(cx, cy, s * 0.40, sw=lw, color=INK)
    f.line(cx - s * 0.62, cy - s * 0.62, cx + s * 0.62, cy - s * 0.62, w=lw, color=INK)
    f.line(cx - s * 0.62, cy + s * 0.62, cx + s * 0.62, cy + s * 0.62, w=lw, color=INK)


def _sym_straightness(f, cx, cy, s, lw):
    f.line(cx - s * 0.62, cy, cx + s * 0.62, cy, w=lw, color=INK)


def _sym_flatness(f, cx, cy, s, lw):
    k = s * 0.30
    f.poly([(cx - s * 0.62, cy + s * 0.34), (cx - s * 0.28, cy - s * 0.34),
            (cx + s * 0.62, cy - s * 0.34), (cx + s * 0.28, cy + s * 0.34)],
           w=lw, color=INK, close=True)


def _sym_profile_line(f, cx, cy, s, lw):
    f.add(f'<path d="M {_fmt(cx - s * 0.6)} {_fmt(cy + s * 0.38)} '
          f'A {_fmt(s * 0.6)} {_fmt(s * 0.6)} 0 0 1 {_fmt(cx + s * 0.6)} {_fmt(cy + s * 0.38)}" '
          f'fill="none" stroke="{INK}" stroke-width="{_fmt(lw)}"/>')


def _sym_profile_surface(f, cx, cy, s, lw):
    _sym_profile_line(f, cx, cy - s * 0.1, s, lw)
    f.line(cx - s * 0.6, cy + s * 0.28, cx + s * 0.6, cy + s * 0.28, w=lw, color=INK)


def _sym_parallelism(f, cx, cy, s, lw):
    d = s * 0.30
    f.line(cx - s * 0.52 + d, cy + s * 0.52, cx - s * 0.12 + d, cy - s * 0.52, w=lw, color=INK)
    f.line(cx - s * 0.12 - d * 0.1, cy + s * 0.52, cx + s * 0.28 - d * 0.1, cy - s * 0.52, w=lw, color=INK)


def _sym_perpendicularity(f, cx, cy, s, lw):
    f.line(cx - s * 0.05, cy - s * 0.58, cx - s * 0.05, cy + s * 0.52, w=lw, color=INK)
    f.line(cx - s * 0.62, cy + s * 0.52, cx + s * 0.58, cy + s * 0.52, w=lw, color=INK)


def _sym_angularity(f, cx, cy, s, lw):
    f.line(cx - s * 0.60, cy + s * 0.52, cx + s * 0.60, cy + s * 0.52, w=lw, color=INK)
    f.line(cx - s * 0.30, cy + s * 0.52, cx + s * 0.36, cy - s * 0.52, w=lw, color=INK)


def _sym_position(f, cx, cy, s, lw):
    f.circle(cx, cy, s * 0.40, sw=lw, color=INK)
    f.line(cx - s * 0.66, cy, cx + s * 0.66, cy, w=lw, color=INK)
    f.line(cx, cy - s * 0.66, cx, cy + s * 0.66, w=lw, color=INK)


def _sym_concentricity(f, cx, cy, s, lw):
    f.circle(cx, cy, s * 0.22, sw=lw, color=INK)
    f.circle(cx, cy, s * 0.58, sw=lw, color=INK)


def _sym_symmetry(f, cx, cy, s, lw):
    f.line(cx - s * 0.62, cy - s * 0.44, cx + s * 0.62, cy - s * 0.44, w=lw, color=INK)
    f.line(cx - s * 0.34, cy, cx + s * 0.34, cy, w=lw, color=INK)
    f.line(cx - s * 0.62, cy + s * 0.44, cx + s * 0.62, cy + s * 0.44, w=lw, color=INK)


def _sym_circular_runout(f, cx, cy, s, lw):
    f.line(cx - s * 0.52, cy + s * 0.52, cx + s * 0.52, cy - s * 0.52, w=lw, color=INK)
    f.arrowhead(cx + s * 0.56, cy - s * 0.56, -45, size=s * 0.55, color=INK, half=s * 0.3)


def _sym_total_runout(f, cx, cy, s, lw):
    for off in (-s * 0.34, s * 0.34):
        f.line(cx - s * 0.62 + off, cy + s * 0.5, cx + s * 0.1 + off, cy - s * 0.5,
               w=lw, color=INK)
        f.arrowhead(cx + s * 0.44 + off, cy - s * 0.5, -45, size=s * 0.42, color=INK, half=s * 0.26)


SYMBOLS = {
    "straightness": _sym_straightness,
    "flatness": _sym_flatness,
    "roundness": _sym_circle,
    "cylindricity": _sym_cylindricity,
    "profile_line": _sym_profile_line,
    "profile_surface": _sym_profile_surface,
    "parallelism": _sym_parallelism,
    "perpendicularity": _sym_perpendicularity,
    "angularity": _sym_angularity,
    "position": _sym_position,
    "concentricity": _sym_concentricity,
    "symmetry": _sym_symmetry,
    "circular_runout": _sym_circular_runout,
    "total_runout": _sym_total_runout,
}


def draw_symbol(f: Fig, name: str, cx, cy, s, lw=1.5):
    if name not in SYMBOLS:
        raise KeyError(f"未知形位公差项目：{name}")
    SYMBOLS[name](f, cx, cy, s, lw)


# ---------------- SVG -> PNG ----------------

def _find_rasterizer():
    magick = shutil.which("magick")
    if magick:
        return ("magick", magick)
    for cand in (
        r"C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe",
        r"C:\Program Files\ImageMagick-7.1.2-Q16\magick.exe",
    ):
        if os.path.exists(cand):
            return ("magick", cand)
    rsvg = shutil.which("rsvg-convert")
    if rsvg:
        return ("rsvg", rsvg)
    if shutil.which("cairosvg"):
        return ("cairosvg", shutil.which("cairosvg"))
    return (None, None)


def rasterize(svg_path: str, png_path: str, density=96):
    kind, exe = _find_rasterizer()
    if kind == "magick":
        cmd = [exe, "-background", "white", "-density", str(density),
               svg_path, "-flatten", f"png24:{png_path}"]
        subprocess.run(cmd, check=True)
    elif kind == "rsvg":
        subprocess.run([exe, "-b", "white", "-z", "1", svg_path, "-o", png_path], check=True)
    elif kind == "cairosvg":
        subprocess.run([exe, svg_path, "-o", png_path, "-b", "white"], check=True)
    else:
        raise RuntimeError(
            "找不到 SVG 栅格化工具：请安装 ImageMagick（magick）、librsvg（rsvg-convert）"
            "或 cairosvg 之一。"
        )


# ---------------- 尺寸公差与修饰符 ----------------

def circled(f: Fig, x, y, letter, r=8.0, size=11.5, color=INK):
    """带圈的修饰符（Ⓜ Ⓛ Ⓔ Ⓡ Ⓟ 用绘制代替字形，避免字体缺字）。"""
    f.circle(x, y, r, sw=1.3, color=color)
    f.text(x, y + 0.5, letter, size=size, color=color, weight="bold")


def size_label(f: Fig, x, y, base, dev=None, mod=None, size=13.0, sub=9.5,
               anchor="middle", color=INK):
    """尺寸 + 上下偏差 + 修饰符。

    base 基本尺寸（如 "φ40"）；dev 为 (上偏差, 下偏差) 或 "0/-0.033" 形式。
    返回文字占用的右边界，便于在尺寸线上排布。
    """
    f.text(x, y, base, size=size, color=color, anchor=anchor)
    if anchor == "end":
        right = x
    elif anchor == "middle":
        right = x + text_width(base, size) / 2
    else:
        right = x + text_width(base, size)
    if dev:
        up, dn = dev
        f.text(right + 3, y - sub * 0.62, up, size=sub, color=color, anchor="start")
        f.text(right + 3, y + sub * 0.62, dn, size=sub, color=color, anchor="start")
        right += 3 + max(text_width(up, sub), text_width(dn, sub))
    if mod:
        circled(f, right + 11, y, mod, r=7.5, size=10.5, color=color)
        right += 22
    return right
