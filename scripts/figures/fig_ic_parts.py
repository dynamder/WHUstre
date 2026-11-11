"""互换性插图用到的「零件基形」。

原则：只画零件本体（不含形位公差标注），返回一组锚点，标注脚本据此精准落点。
为可靠起见，除阶梯轴用侧视图外，其余零件都用**剖视 / 断面**表示——
剖视图用多边形 + 剖面线画，几何关系一目了然，也便于标「面」还是「中心」。
"""

from __future__ import annotations

import math

from gdt import Fig, INK, W_THICK, W_THIN, W_THINNER


# ---------------- 通用 -----------------

def disk_pts(cx, cy, r, n=72):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n))
            for i in range(n)]


def annulus_pts(cx, cy, r1, r2, n=72):
    """圆环（r1 外、r2 内）的多边形点集，用于剖面线。"""
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        pts.append((cx + r1 * math.cos(a), cy + r1 * math.sin(a)))
    for i in range(n - 1, -1, -1):
        a = 2 * math.pi * i / n
        pts.append((cx + r2 * math.cos(a), cy + r2 * math.sin(a)))
    return pts


def ring(f: Fig, cx, cy, r1, r2, hatch=True, spacing=8, angle=45, w=W_THICK):
    """画圆环并打剖面线。"""
    f.circle(cx, cy, r1, sw=w)
    f.circle(cx, cy, r2, sw=w)
    if hatch:
        f.hatch(annulus_pts(cx, cy, r1 - 1, r2 + 1), spacing=spacing, angle=angle)


def rect_section(f: Fig, x, y, w, h, hatch=True, spacing=8, angle=45, lw=W_THICK):
    f.rect(x, y, w, h, sw=lw)
    if hatch:
        f.hatch([(x + 1, y + 1), (x + w - 1, y + 1), (x + w - 1, y + h - 1), (x + 1, y + h - 1)],
                spacing=spacing, angle=angle)


# ---------------- 阶梯轴（侧视） -----------------

def stepped_shaft(f: Fig, ox=90, oy=150, r_big=45, r_small=22, len_big=190,
                  len_small=140, keyway=False):
    """两段阶梯轴；keyway=True 时用虚线画出键槽（隐藏）。"""
    x0, x1, x2 = ox, ox + len_big, ox + len_big + len_small
    a = {"axis": oy, "x0": x0, "x1": x1, "x2": x2,
         "top_big": oy - r_big, "bot_big": oy + r_big,
         "top_small": oy - r_small, "bot_small": oy + r_small,
         "r_big": r_big, "r_small": r_small}
    f.centerline(x0 - 32, oy, x2 + 32, oy)
    # φ 大段
    f.line(x0, oy - r_big, x1, oy - r_big, w=W_THICK)
    f.line(x0, oy + r_big, x1, oy + r_big, w=W_THICK)
    f.line(x0, oy - r_big, x0, oy + r_big, w=W_THICK)
    # 台阶面
    f.line(x1, oy - r_big, x1, oy - r_small, w=W_THICK)
    f.line(x1, oy + r_small, x1, oy + r_big, w=W_THICK)
    # φ 小段
    f.line(x1, oy - r_small, x2 - 6, oy - r_small, w=W_THICK)
    f.line(x1, oy + r_small, x2 - 6, oy + r_small, w=W_THICK)
    f.line(x2 - 6, oy - r_small, x2, oy - r_small + 4, w=W_THICK)
    f.line(x2 - 6, oy + r_small, x2, oy + r_small - 4, w=W_THICK)
    f.line(x2, oy - r_small + 4, x2, oy + r_small - 4, w=W_THICK)
    if keyway:
        kx0, kx1 = x0 + 30, x0 + 130
        kd = 16                                   # 键槽宽（半宽画出来）
        kb = oy - r_big + 9                       # 槽底
        f.line(kx0, oy - r_big, kx0, kb, w=W_THINNER)   # 槽端面（可见）
        f.line(kx1, oy - r_big, kx1, kb, w=W_THINNER)
        f.line(kx0, kb, kx1, kb, w=W_THINNER)
        a.update({"kx0": kx0, "kx1": kx1, "k_mid": (kx0 + kx1) / 2, "k_bottom": kb})
    return a


# ---------------- 键槽断面 -----------------

def keyway_section(f: Fig, cx, cy, r=46, width=28, depth=16):
    """轴的断面：圆 + 上方键槽；用于对称度、键槽尺寸标注。"""
    a = {"cx": cx, "cy": cy, "r": r, "w": width, "depth": depth}
    # 圆弧
    f.add(f'<path d="M {_fmt(cx - width / 2)} {_fmt(cy - math.sqrt(r * r - (width / 2) ** 2))} '
          f'A {_fmt(r)} {_fmt(r)} 0 1 0 {_fmt(cx + width / 2)} {_fmt(cy - math.sqrt(r * r - (width / 2) ** 2))}" '
          f'fill="none" stroke="{INK}" stroke-width="{_fmt(W_THICK)}"/>')
    y_slot = cy - r + depth
    f.line(cx - width / 2, cy - math.sqrt(r * r - (width / 2) ** 2),
           cx - width / 2, y_slot, w=W_THICK)
    f.line(cx + width / 2, cy - math.sqrt(r * r - (width / 2) ** 2),
           cx + width / 2, y_slot, w=W_THICK)
    f.line(cx - width / 2, y_slot, cx + width / 2, y_slot, w=W_THICK)
    f.centerline(cx - r - 26, cy, cx + r + 26, cy)
    f.centerline(cx, cy - r - 26, cx, cy + r + 26)
    a.update({"slot_y": y_slot, "slot_x0": cx - width / 2, "slot_x1": cx + width / 2})
    return a


# ---------------- 套筒全剖 -----------------

def sleeve_section(f: Fig, ox=120, oy=180, r_out=56, r_in=32, length=210,
                   flange_r=72, flange_w=22):
    """带凸缘套筒的全剖视图（上下对称）。"""
    x0, x1 = ox, ox + length
    xf = x0 + flange_w
    a = {"axis": oy, "x0": x0, "x1": x1, "xf": xf,
         "top_out": oy - r_out, "bot_out": oy + r_out,
         "top_in": oy - r_in, "bot_in": oy + r_in,
         "flange_top": oy - flange_r, "flange_bot": oy + flange_r,
         "r_out": r_out, "r_in": r_in, "r_flange": flange_r}
    f.centerline(x0 - 34, oy, x1 + 34, oy)
    up = [(x0, oy - flange_r), (xf, oy - flange_r), (xf, oy - r_out),
          (x1, oy - r_out), (x1, oy - r_in), (x0, oy - r_in)]
    dn = [(x0, oy + flange_r), (xf, oy + flange_r), (xf, oy + r_out),
          (x1, oy + r_out), (x1, oy + r_in), (x0, oy + r_in)]
    f.hatch([(x + 1, y + (1 if y < oy else -1)) for x, y in up], spacing=8, angle=45)
    f.hatch([(x + 1, y + (1 if y < oy else -1)) for x, y in dn], spacing=8, angle=45)
    for pts in (up, dn):
        f.poly(pts, w=W_THICK, close=True)
    return a


# ---------------- 板件 -----------------

def plate_top(f: Fig, ox=90, oy=70, w=240, h=150, holes=((70, 60), (170, 60))):
    a = {"x0": ox, "y0": oy, "x1": ox + w, "y1": oy + h}
    f.rect(ox, oy, w, h, sw=W_THICK)
    pts = []
    for hx, hy in holes:
        cx, cy = ox + hx, oy + hy
        f.circle(cx, cy, 12, sw=W_THICK)
        f.centerline(cx - 18, cy, cx + 18, cy)
        f.centerline(cx, cy - 18, cx, cy + 18)
        pts.append((cx, cy))
    a["holes"] = pts
    return a


# ---------------- 平键联结断面 -----------------

def key_joint_section(f: Fig, cx=170, cy=170, r_shaft=42, r_hub=74,
                      width=26, t1=18, t2=13):
    """垂直于轴线的断面：轴（带键槽）+ 键 + 轮毂（带键槽）。"""
    a = {"cx": cx, "cy": cy, "w": width, "t1": t1, "t2": t2,
         "r_shaft": r_shaft, "r_hub": r_hub}
    half = width / 2
    ys = math.sqrt(r_shaft ** 2 - half ** 2)      # 键槽两侧与圆的交点 y
    # 轴（缺一个键槽口的圆）
    f.add(f'<path d="M {_fmt(cx - half)} {_fmt(cy - ys)} A {_fmt(r_shaft)} {_fmt(r_shaft)} 0 1 1 '
          f'{_fmt(cx + half)} {_fmt(cy - ys)} L {_fmt(cx + half)} {_fmt(cy - r_shaft + t1)} '
          f'L {_fmt(cx - half)} {_fmt(cy - r_shaft + t1)} Z" '
          f'fill="none" stroke="{INK}" stroke-width="{_fmt(W_THICK)}"/>')
    shaft_pts = []
    for i in range(60):
        ang = math.radians(180 + 360 * i / 60)
        shaft_pts.append((cx + r_shaft * math.cos(ang), cy + r_shaft * math.sin(ang)))
    shaft_pts += [(cx - half, cy - r_shaft + t1), (cx - half, cy - ys)]
    f.hatch(shaft_pts, spacing=7.5, angle=45)
    # 键（不剖）
    key_top = cy - r_shaft - t2
    f.rect(cx - half, key_top, width, (cy - r_shaft + t1) - key_top, sw=W_THICK)
    # 轮毂（内孔 + 键槽口）
    yh = math.sqrt(r_hub ** 2 - half ** 2)
    f.add(f'<path d="M {_fmt(cx - half)} {_fmt(cy - yh)} A {_fmt(r_hub)} {_fmt(r_hub)} 0 1 1 '
          f'{_fmt(cx + half)} {_fmt(cy - yh)} L {_fmt(cx + half)} {_fmt(cy - r_hub - 1)} '
          f'L {_fmt(cx - half)} {_fmt(cy - r_hub - 1)} Z" fill="none"/>')
    f.add(f'<path d="M {_fmt(cx - half)} {_fmt(cy - yh)} A {_fmt(r_hub)} {_fmt(r_hub)} 0 0 0 '
          f'{_fmt(cx + half)} {_fmt(cy - yh)}" fill="none" stroke="{INK}" '
          f'stroke-width="{_fmt(W_THICK)}"/>')
    f.add(f'<path d="M {_fmt(cx - half)} {_fmt(cy - yh)} L {_fmt(cx - half)} {_fmt(key_top)} '
          f'L {_fmt(cx + half)} {_fmt(key_top)} L {_fmt(cx + half)} {_fmt(cy - yh)}" '
          f'fill="none" stroke="{INK}" stroke-width="{_fmt(W_THICK)}"/>')
    hub_pts = []
    for i in range(30):
        ang = math.radians(200 + 140 * i / 29)
        hub_pts.append((cx + r_hub * math.cos(ang), cy + r_hub * math.sin(ang)))
    for i in range(30):
        ang = math.radians(340 - 140 * i / 29)
        hub_pts.append((cx + r_shaft * math.cos(ang), cy + r_shaft * math.sin(ang)))
    hub_pts += [(cx - half, cy - r_shaft + t1), (cx - half, cy - yh)]
    f.hatch(hub_pts, spacing=7.5, angle=-45)
    f.centerline(cx - r_hub - 26, cy, cx + r_hub + 26, cy)
    f.centerline(cx, cy - r_hub - 26, cx, cy + r_hub + 26)
    a.update({"slot_top": cy - r_shaft + t1, "key_top": key_top,
              "yh": yh, "ys": ys})
    return a


# ---------------- 滚动轴承装配断面 -----------------

def bearing_section(f: Fig, cx=180, cy=180, r_shaft=34, r_in_out=52,
                    r_out_in=70, r_out_out=88, r_housing=108):
    """滚动轴承装配的断面示意：轴 / 内圈 / 滚动体 / 外圈 / 壳体。"""
    a = {"cx": cx, "cy": cy, "r_shaft": r_shaft}
    # 轴
    f.circle(cx, cy, r_shaft, sw=W_THICK)
    f.hatch(disk_pts(cx, cy, r_shaft - 1, n=60), spacing=8, angle=45)
    # 内圈
    ring(f, cx, cy, r_in_out, r_shaft, spacing=8, angle=45)
    # 滚动体
    rb = (r_out_in - r_in_out) / 2 - 1
    rm = (r_in_out + r_out_in) / 2
    for ang in (90, 270):
        f.circle(cx + rm * math.cos(math.radians(ang)),
                 cy + rm * math.sin(math.radians(ang)), rb, sw=W_THIN)
    # 外圈
    ring(f, cx, cy, r_out_out, r_out_in, spacing=8, angle=45)
    # 壳体
    f.circle(cx, cy, r_housing, sw=W_THICK)
    f.hatch(annulus_pts(cx, cy, r_housing - 1, r_out_out + 1, n=72), spacing=8, angle=-45)
    f.centerline(cx - r_housing - 26, cy, cx + r_housing + 26, cy)
    f.centerline(cx, cy - r_housing - 26, cx, cy + r_housing + 26)
    a.update({"r_in_out": r_in_out, "r_out_in": r_out_in,
              "r_out_out": r_out_out, "r_housing": r_housing,
              "housing_bore": r_out_out})
    return a


def _fmt(v: float) -> str:
    return f"{v:.2f}".rstrip("0").rstrip(".")


# ---------------- 平键联结（横断面） ----------------

def _arc(cx, cy, r, a0, a1, n=90):
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / (n - 1)),
             cy + r * math.sin(a0 + (a1 - a0) * i / (n - 1))) for i in range(n)]


def key_joint_cross(f: Fig, cx=300, cy=280, r_shaft=54, r_hub=96,
                    width=32, t1=22, t2=18):
    """平键联结横断面：轴（带键槽）+ 键 + 轮毂（带键槽），用于「键连接」应用题。"""
    half = width / 2.0
    h_s = math.sqrt(r_shaft ** 2 - half ** 2)
    h_h = math.sqrt(r_hub ** 2 - half ** 2)
    key_bot = cy - r_shaft + t1
    key_top = cy - r_shaft - t2
    a_r = math.atan2(-h_s, half)
    a_l = math.atan2(-h_s, -half)

    # 轴：整圆去掉上方键槽
    shaft = _arc(cx, cy, r_shaft, a_r, a_l + 2 * math.pi, 120)
    shaft += [(cx - half, key_bot), (cx + half, key_bot)]
    f.hatch(shaft, spacing=8, angle=45)

    # 轮毂：环形（外圆 + 内孔，同一角度起止形成零宽切口）
    ring = _arc(cx, cy, r_hub, a_r, a_r + 2 * math.pi, 150)
    ring += list(reversed(_arc(cx, cy, r_shaft, a_r, a_r + 2 * math.pi, 120)))
    f.hatch(ring, spacing=8, angle=-45)

    # 挖掉轮毂键槽处的剖面线
    notch = [(cx - half, cy - h_s), (cx - half, key_top), (cx + half, key_top),
             (cx + half, cy - h_s)]
    notch += _arc(cx, cy, r_shaft, a_r, a_l, 40)
    f.poly(notch, close=True, fill="#ffffff", color="none", w=0)

    # 键（不剖，白底）
    f.rect(cx - half, key_top, width, key_bot - key_top, sw=W_THICK, fill="#ffffff")

    # 轮廓线
    f.circle(cx, cy, r_hub, sw=W_THICK)
    f.poly(shaft, w=W_THICK, close=True)
    f.poly([(cx - half, cy - h_s), (cx - half, key_top), (cx + half, key_top),
            (cx + half, cy - h_s)], w=W_THICK)

    f.centerline(cx - r_hub - 26, cy, cx + r_hub + 26, cy)
    f.centerline(cx, cy - r_hub - 26, cx, cy + r_hub + 26)
    return {"cx": cx, "cy": cy, "r_shaft": r_shaft, "r_hub": r_hub,
            "half": half, "key_top": key_top, "key_bot": key_bot,
            "h_s": h_s, "h_h": h_h, "a_r": a_r, "a_l": a_l}
