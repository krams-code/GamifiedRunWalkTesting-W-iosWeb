"""Tiny Lottie (bodymovin) JSON builder: shapes, groups, keyframes."""
import json, math, random

def hexc(h, a=1):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] + [a]

def _is_prop(v):
    return isinstance(v, dict) and 'k' in v

def S(v):
    """static property"""
    return v if _is_prop(v) else {"a": 0, "k": v}

def A(keys, linear=False, ease=(0.35, 0.65)):
    """animated property. keys = [(frame, value), ...] (value scalar or list)."""
    out = []
    for idx, (t, v) in enumerate(keys):
        v = list(v) if isinstance(v, (list, tuple)) else [v]
        kf = {"t": t, "s": v}
        if idx < len(keys) - 1:
            n = len(v)
            if linear:
                ix, iy, ox, oy = 1, 1, 0, 0
            else:
                ix, iy, ox, oy = 1 - ease[1], 1, ease[0], 0
            if n == 1:
                kf["i"] = {"x": [ix], "y": [iy]}
                kf["o"] = {"x": [ox], "y": [oy]}
            else:
                kf["i"] = {"x": ix, "y": iy}
                kf["o"] = {"x": ox, "y": oy}
        out.append(kf)
    return {"a": 1, "k": out}

def tr(p=(0, 0), a=(0, 0), s=(100, 100), r=0, o=100):
    return {"ty": "tr", "p": S(list(p) if not _is_prop(p) else p), "a": S(list(a) if not _is_prop(a) else a),
            "s": S(list(s) if not _is_prop(s) else s), "r": S(r), "o": S(o),
            "sk": S(0), "sa": S(0), "nm": "Transform"}

def group(items, name="g", **t):
    return {"ty": "gr", "nm": name, "it": list(items) + [tr(**t)], "np": len(items), "cix": 2, "bm": 0, "ix": 1, "mn": "ADBE Vector Group", "hd": False}

def ellipse(w, h=None, p=(0, 0)):
    return {"ty": "el", "nm": "e", "p": S(list(p) if not _is_prop(p) else p), "s": S([w, h if h is not None else w] if not _is_prop(w) else w), "d": 1}

def rrect(w, h, r=6, p=(0, 0)):
    return {"ty": "rc", "nm": "r", "p": S(list(p) if not _is_prop(p) else p), "s": S([w, h]), "r": S(r), "d": 1}

def star(n, outer, inner, rot=0, p=(0, 0), polygon=False):
    d = {"ty": "sr", "nm": "s", "sy": 2 if polygon else 1, "p": S(list(p)), "r": S(rot), "pt": S(n),
         "or": S(outer), "os": S(0), "d": 1}
    if not polygon:
        d["ir"] = S(inner)
        d["is"] = S(0)
    return d

def path(pts, closed=True, round_=0):
    return {"ty": "sh", "nm": "p", "ks": S({"i": [[0, 0]] * len(pts), "o": [[0, 0]] * len(pts),
                                            "v": [list(p) for p in pts], "c": closed}), "d": 1}

def fill(color, o=100):
    return {"ty": "fl", "nm": "f", "c": S(color if isinstance(color, list) else hexc(color)), "o": S(o), "r": 1, "bm": 0}

def stroke(color, w, o=100):
    return {"ty": "st", "nm": "st", "c": S(color if isinstance(color, list) else hexc(color)), "o": S(o),
            "w": S(w), "lc": 2, "lj": 2, "ml": 4, "bm": 0}

def layer(shapes, name, ind, op, p=(0, 0), s=(100, 100), r=0, o=100):
    return {"ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1,
            "ks": {"o": S(o), "r": S(r), "p": S([p[0], p[1], 0]) if not _is_prop(p) else p,
                   "a": S([0, 0, 0]), "s": S(list(s) if not _is_prop(s) else s)},
            "ao": 0, "shapes": list(shapes), "ip": 0, "op": op, "st": 0, "bm": 0}

def comp(name, w, h, op, layers, fr=30):
    return {"v": "5.7.0", "fr": fr, "ip": 0, "op": op, "w": w, "h": h, "nm": name, "ddd": 0,
            "assets": [], "layers": layers, "markers": []}

def save(c, path_):
    with open(path_, 'w') as f:
        json.dump(c, f, separators=(',', ':'))
