"""Re-expresa las claves del kit como DELTAS respecto al idle de referencia y las
suma al idle capturado del rig real. Así el kit conserva la postura propia del
personaje (altura de cadera, encorvamiento, apoyo de pies, cola).

Se trabaja sobre poses ya resueltas (herencia aplicada), así ningún campo
heredado se pierde en la conversión."""
import copy
import kzanim as K


def _add3(a, b, s=1.0):
    return tuple(x + y * s for x, y in zip(a, b))


def _sub3(a, b):
    return tuple(x - y for x, y in zip(a, b))


def resolve(keys, start):
    """Aplica la herencia de poses del kit (merge_pose) y devuelve poses completas."""
    pose = copy.deepcopy(start)
    out = []
    for item in keys:
        t, P = item[0], item[1]
        pose = K.merge_pose(pose, P)
        out.append((t, copy.deepcopy(pose), *item[2:]))
    return out


def convert_pose(P, ref, cap, rig):
    w = rig.p["spine_w"]
    n_tail = len(rig.p["tail"])
    Q = copy.deepcopy(P)
    Q["root"] = {
        "loc": _add3(cap["root"]["loc"], _sub3(P["root"]["loc"], ref["root"]["loc"])),
        "rot": _add3(cap["root"]["rot"], _sub3(P["root"]["rot"], ref["root"]["rot"])),
    }
    Q["hips"] = _add3(cap.get("hips", (0, 0, 0)), _sub3(P.get("hips", (0, 0, 0)), ref.get("hips", (0, 0, 0))))
    d = _sub3(P.get("spine", ref["spine"]), ref["spine"])
    base = cap.get("spine_per") or [(0, 0, 0)] * len(w)
    Q["spine_per"] = [_add3(b, d, wi) for b, wi in zip(base, w)]
    Q.pop("spine", None)
    Q["neck"] = _add3(cap.get("neck", (0, 0, 0)), _sub3(P.get("neck", (0, 0, 0)), ref.get("neck", (0, 0, 0))))
    Q["gaze"] = _add3(cap.get("gaze", (0, 0, 0)), _sub3(P.get("gaze", (0, 0, 0)), ref.get("gaze", (0, 0, 0))))
    Q.pop("head", None)
    for side in ("L", "R"):
        F = P.get("foot", {}).get(side, {})
        RF = ref["foot"][side]
        Q.setdefault("foot", {})[side] = {
            "loc": _sub3(F.get("loc", RF.get("loc", (0, 0, 0))), RF.get("loc", (0, 0, 0))),
            "rot": _sub3(F.get("rot", RF.get("rot", (0, 0, 0))), RF.get("rot", (0, 0, 0))),
            "knee": F.get("knee", 0.0) - RF.get("knee", 0.0),
        }
    T = P.get("tail", {})
    if n_tail:
        RT = ref.get("tail", {})
        base = (cap.get("tail") or {}).get("per") or [(0.0, 0.0)] * n_tail
        dp = T.get("pitch", 0) - RT.get("pitch", 0)
        dy = T.get("yaw", 0) - RT.get("yaw", 0)
        dc = T.get("curl", 0) - RT.get("curl", 0)
        ds = T.get("swing", 0) - RT.get("swing", 0)
        per = []
        for i in range(n_tail):
            tt = (i + 0.5) / n_tail
            pp = dp / n_tail + dc * (tt - 0.5) * 2.0 / n_tail
            yy = dy / n_tail + ds * (tt - 0.5) * 2.0 / n_tail
            b = base[min(i, len(base) - 1)]
            per.append((b[0] + pp, b[1] + yy))
        Q["tail"] = {"per": per}
    return Q


def retarget(keys, ref_idle, cap_idle, rig, start=None):
    """keys autorados contra ref_idle -> claves completas para el rig con cap_idle.
    Las claves que SON el idle de referencia se sustituyen por el idle capturado exacto."""
    full = resolve(keys, start if start is not None else ref_idle)
    out = []
    for (t, P, *opt), (_, Porig, *_o) in zip(full, keys):
        if Porig is ref_idle:
            out.append((t, copy.deepcopy(cap_idle), *opt))
        else:
            out.append((t, convert_pose(P, ref_idle, cap_idle, rig), *opt))
    return out
