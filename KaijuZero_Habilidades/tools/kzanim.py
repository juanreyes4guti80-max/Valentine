"""
kzanim — autoría de animación por poses semánticas sobre un rig Auto-Rig Pro.

Idea: las poses se describen en términos anatómicos del personaje (inclinar el
torso, dónde va la mano respecto al hombro, hacia dónde mira la palma...) y la
librería las convierte a rotaciones locales de los controladores usando las
matrices de reposo reales del rig. Así la misma animación funciona aunque cada
hueso tenga su propio roll.

Convenciones (espacio del armature):
  FWD  = hacia donde mira el personaje (ARP: -Y)
  UP   = +Z
  LEFT = UP x FWD (ARP: +X)
Vectores "de lado" se escriben (out, fwd, up): `out` positivo = hacia el lado de
ese brazo/pierna, así una misma pose sirve espejada para L y R.
Ángulos en grados.
"""
import bpy
import math
import copy
from mathutils import Vector, Matrix, Quaternion

D2R = math.pi / 180.0


def upd():
    bpy.context.view_layer.update()


def nrm(v):
    v = Vector(v)
    return v.normalized() if v.length > 1e-9 else v


def orth(v, ref):
    """Componente de v ortogonal a ref (normalizada)."""
    ref = nrm(ref)
    return nrm(Vector(v) - ref * Vector(v).dot(ref))


def basis(a, b):
    """Matriz 3x3 con columnas (a, b, a x b) a partir de a, b casi ortogonales (b manda)."""
    b = nrm(b)
    a = orth(a, b)
    c = a.cross(b)
    m = Matrix((a, b, c)).transposed()
    return m


def rot_from_frames(local_a, local_b, target_a, target_b):
    """Rotación que lleva el par (local_a, local_b) al par (target_a, target_b)."""
    L = basis(local_a, local_b)
    T = basis(target_a, target_b)
    return T @ L.inverted()


def deep_merge(base, over):
    out = copy.deepcopy(base)
    for k, v in over.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = copy.deepcopy(v)
    return out


def lerp(a, b, t):
    return a + (b - a) * t


DEFAULT_PROFILE = {
    "fwd": (0, -1, 0),
    "root": "c_root_master.x",
    "hips": "c_root.x",
    "spine": ["c_spine_01.x", "c_spine_02.x", "c_spine_03.x"],
    "spine_w": [0.34, 0.33, 0.33],
    "neck": "c_neck.x",
    "head": "c_head.x",
    "clav": {"L": "c_shoulder.l", "R": "c_shoulder.r"},
    "arm": {"L": ["c_arm_fk.l", "c_forearm_fk.l", "c_hand_fk.l"],
            "R": ["c_arm_fk.r", "c_forearm_fk.r", "c_hand_fk.r"]},
    "fingers": {s: {f: [f"c_{f}{i}.{s.lower()}" for i in (1, 2, 3)]
                    for f in ("thumb", "index", "middle", "ring", "pinky")} for s in ("L", "R")},
    "foot_ik": {"L": "c_foot_ik.l", "R": "c_foot_ik.r"},
    "pole": {"L": "c_leg_pole.l", "R": "c_leg_pole.r"},
    "tail": [f"c_tail_{i:02d}.x" for i in range(12)],
    # (bone, property, valor FK) para forzar FK en brazos
    "arm_fk_switch": {"L": ("c_hand_ik.l", "ik_fk_switch", 1.0),
                      "R": ("c_hand_ik.r", "ik_fk_switch", 1.0)},
}


class Rig:
    def __init__(self, ob, profile=None):
        self.ob = ob
        self.p = deep_merge(DEFAULT_PROFILE, profile or {})
        self.pb = ob.pose.bones
        self.bones = ob.data.bones
        self.FWD = nrm(self.p["fwd"])
        self.UP = Vector((0, 0, 1))
        self.LEFT = self.UP.cross(self.FWD)
        # filtrar listas a huesos existentes
        self.p["spine"] = [b for b in self.p["spine"] if b in self.pb]
        w = self.p["spine_w"][: len(self.p["spine"])]
        s = sum(w) or 1.0
        self.p["spine_w"] = [x / s for x in w]
        self.p["tail"] = [b for b in self.p["tail"] if b in self.pb]
        for side in ("L", "R"):
            for f in list(self.p["fingers"][side].keys()):
                chain = [b for b in self.p["fingers"][side][f] if b in self.pb]
                if chain:
                    self.p["fingers"][side][f] = chain
                else:
                    del self.p["fingers"][side][f]
        self.rest = {b.name: b.matrix_local.copy() for b in self.bones}
        self._calibrate()
        self.prev_q = {}

    # ------------------------------------------------------------------ util
    def cv(self, v, side=None, frame=None):
        """(out|left, fwd, up) -> vector del armature. side 'L'/'R' espeja `out`."""
        o, f, u = v
        lx = self.LEFT if side in (None, "L") else -self.LEFT
        if frame is not None:  # frame = 3x3 de rotación (pose vs reposo)
            return frame @ (lx * o + self.FWD * f + self.UP * u)
        return lx * o + self.FWD * f + self.UP * u

    def R(self, pitch=0.0, yaw=0.0, roll=0.0):
        """pitch + = inclinar hacia adelante, yaw + = girar a su izquierda, roll + = ladear a su izquierda."""
        ry = Matrix.Rotation(yaw * D2R, 3, self.UP)
        rp = Matrix.Rotation(pitch * D2R, 3, self.LEFT)
        rr = Matrix.Rotation(-roll * D2R, 3, self.FWD)
        return ry @ rp @ rr

    def rest3(self, name):
        return self.rest[name].to_3x3().normalized()

    def head_rest(self, name):
        return self.rest[name].translation.copy()

    def posed(self, name):
        return self.pb[name].matrix.copy()

    def frame_of(self, name):
        """Rotación (3x3) de un hueso posado respecto a su reposo, en espacio armature."""
        return self.posed(name).to_3x3().normalized() @ self.rest3(name).inverted()

    def set_local_rot_from_world(self, name, Rw):
        """Aplica una rotación expresada en ejes del personaje relativa al padre."""
        B = self.rest3(name)
        q = (B.inverted() @ Rw @ B).to_quaternion()
        self._set_q(name, q)

    def _set_q(self, name, q):
        pb = self.pb[name]
        if pb.rotation_mode == "QUATERNION":
            pb.rotation_quaternion = q
        elif pb.rotation_mode == "AXIS_ANGLE":
            ax, ang = q.to_axis_angle()
            pb.rotation_axis_angle = (ang, ax.x, ax.y, ax.z)
        else:
            pb.rotation_euler = q.to_euler(pb.rotation_mode, pb.rotation_euler)

    def set_world_matrix(self, name, M):
        self.pb[name].matrix = M

    # ------------------------------------------------------------- calibrar
    def _calibrate(self):
        p = self.p
        self.root_h = self.head_rest(p["root"]).z
        self.arm_len = {}
        self.seg = {}
        self.palm_local = {}
        self.finger_axis = {}
        for side in ("L", "R"):
            up, fo, ha = p["arm"][side]
            a = (self.head_rest(fo) - self.head_rest(up)).length
            b = (self.head_rest(ha) - self.head_rest(fo)).length
            self.seg[side] = (a, b)
            self.arm_len[side] = a + b
            # eje bisagra del codo en local del brazo
            ud = nrm(self.head_rest(fo) - self.head_rest(up))
            fd = nrm(self.head_rest(ha) - self.head_rest(fo))
            h = ud.cross(fd)
            if h.length < 0.05:
                # brazo recto en reposo: asumir que el codo se dobla hacia adelante
                h = ud.cross(self.FWD)
                # flexión del codo: el antebrazo va hacia adelante -> h = ud x fwd
            h.normalize()
            # El codo humano flexiona llevando el antebrazo hacia adelante/adentro.
            # Si la flexión de reposo fuera "hacia atrás", invertir para que
            # h = ud x (dirección de flexión).
            self.hinge_up_local = getattr(self, "hinge_up_local", {})
            self.hinge_up_local[side] = self.rest3(up).inverted() @ h
            self.hinge_fo_local = getattr(self, "hinge_fo_local", {})
            self.hinge_fo_local[side] = self.rest3(fo).inverted() @ h
            # palma de la mano (normal) a partir del pulgar
            hd = nrm(self.rest[ha].to_3x3().col[1])
            thumb = p["fingers"][side].get("thumb")
            if thumb:
                t = orth(self.head_rest(thumb[0]) - self.head_rest(ha), hd)
                n = hd.cross(t) if side == "L" else t.cross(hd)
            else:
                n = orth(-self.UP, hd)
            n.normalize()
            self.palm_rest = getattr(self, "palm_rest", {})
            self.palm_rest[side] = n
            self.palm_local[side] = self.rest3(ha).inverted() @ n
            # ejes de flexión de dedos
            for f, chain in p["fingers"][side].items():
                for bn in chain:
                    fd2 = nrm(self.rest[bn].to_3x3().col[1])
                    if f == "thumb":
                        ax = fd2.cross(orth(n, fd2))
                    else:
                        ax = fd2.cross(orth(n, fd2))
                    self.finger_axis[bn] = nrm(self.rest3(bn).inverted() @ ax)
        legs = []
        for side in ("L", "R"):
            fk = p["foot_ik"][side]
            if fk in self.pb:
                legs.append(self.head_rest(fk).z)
        self.leg_len = self.root_h  # aproximación: altura de cadera

    # --------------------------------------------------------------- aplicar
    def apply(self, P):
        """Aplica una pose semántica completa (sin keyframes)."""
        p = self.p
        H = self.root_h
        # 1) raíz: posición y rotación global del cuerpo
        r = P.get("root", {})
        rn = p["root"]
        B = self.rest3(rn)
        off = self.cv(r.get("loc", (0, 0, 0))) * H
        self.pb[rn].location = B.inverted() @ off
        self.set_local_rot_from_world(rn, self.R(*r.get("rot", (0, 0, 0))))
        # 2) pelvis
        if p["hips"] in self.pb:
            self.set_local_rot_from_world(p["hips"], self.R(*P.get("hips", (0, 0, 0))))
        # 3) columna (rotación total repartida)
        sp = P.get("spine", (0, 0, 0))
        for bn, w in zip(p["spine"], p["spine_w"]):
            self.set_local_rot_from_world(bn, self.R(sp[0] * w, sp[1] * w, sp[2] * w))
        if p["neck"] in self.pb:
            self.set_local_rot_from_world(p["neck"], self.R(*P.get("neck", (0, 0, 0))))
        upd()
        # 4) cabeza: rotación relativa o mirada estabilizada en espacio personaje
        hd = p["head"]
        if hd in self.pb:
            if "gaze" in P:
                g = P["gaze"]  # (pitch, yaw, roll) absolutos respecto al personaje
                Rabs = self.R(*g)
                Bh = self.rest3(hd)
                M = (Rabs @ Bh).to_4x4()
                M.translation = self.posed(hd).translation
                self.set_world_matrix(hd, M)
            else:
                self.set_local_rot_from_world(hd, self.R(*P.get("head", (0, 0, 0))))
        # 5) piernas (IK)
        for side in ("L", "R"):
            self._apply_leg(side, P.get("foot", {}).get(side, {}))
        # 6) cola
        self._apply_tail(P.get("tail", {}))
        upd()
        # 7) brazos (clavícula, IK analítico -> FK, mano, dedos)
        order = P.get("arm_order", ("R", "L"))
        for side in order:
            self._apply_arm(side, P.get("arm", {}).get(side, {}), P)
            upd()
        for side in ("L", "R"):
            self._apply_fingers(side, P.get("fingers", {}).get(side, {}))

    # piernas ---------------------------------------------------------------
    def _apply_leg(self, side, S):
        fk = self.p["foot_ik"][side]
        if fk not in self.pb:
            return
        H = self.root_h
        B = self.rest[fk]
        pos = B.translation + self.cv(S.get("loc", (0, 0, 0)), side) * H
        rot = S.get("rot", (0, 0, 0))  # pitch(punta abajo +), yaw(+ hacia fuera), roll(+ borde externo arriba)
        sgn = 1 if side == "L" else -1
        Rw = self.R(rot[0], rot[1] * sgn, rot[2] * sgn)
        M = (Rw @ B.to_3x3().normalized()).to_4x4()
        M.translation = pos
        self.set_world_matrix(fk, M)
        upd()
        pl = self.p["pole"][side]
        if pl in self.pb:
            Bp = self.rest[pl]
            rel = Bp.translation - B.translation
            knee = S.get("knee", 0.0)  # + rodilla hacia fuera (grados)
            Rk = Matrix.Rotation(rot[1] * sgn * D2R, 3, self.UP) @ Matrix.Rotation(-knee * sgn * D2R, 3, self.UP)
            ppos = pos + Rk @ rel
            Mp = Bp.copy()
            Mp.translation = ppos
            self.set_world_matrix(pl, Mp)

    # cola ------------------------------------------------------------------
    def _apply_tail(self, T):
        bones = self.p["tail"]
        n = len(bones)
        if not n:
            return
        pitch = T.get("pitch", 0.0)  # + arriba (total)
        yaw = T.get("yaw", 0.0)      # + hacia su izquierda (total)
        curl = T.get("curl", 0.0)    # curvatura extra creciente hacia la punta (pitch)
        swing = T.get("swing", 0.0)  # curvatura extra creciente (yaw)
        per = T.get("per", None)     # lista explícita [(pitch,yaw)] por segmento
        for i, bn in enumerate(bones):
            t = (i + 0.5) / n
            if per:
                pp, yy = per[min(i, len(per) - 1)]
            else:
                pp = pitch / n + curl * (t - 0.5) * 2.0 / n
                yy = yaw / n + swing * (t - 0.5) * 2.0 / n
            Rw = Matrix.Rotation(-yy * D2R, 3, self.UP) @ Matrix.Rotation(pp * D2R, 3, self.LEFT)
            self.set_local_rot_from_world(bn, Rw)

    # brazos ----------------------------------------------------------------
    def _apply_arm(self, side, S, P):
        if not S:
            return
        p = self.p
        cl = p["clav"][side]
        up, fo, ha = p["arm"][side]
        if cl in self.pb:
            sh = S.get("clav", (0, 0))  # (elevar, adelantar) en grados
            out = nrm(self.head_rest(up) - self.head_rest(cl))
            Rw = Matrix.Identity(3)
            if sh[0]:
                Rw = Matrix.Rotation(sh[0] * D2R, 3, nrm(out.cross(self.UP))) @ Rw
            if sh[1]:
                Rw = Matrix.Rotation(sh[1] * D2R, 3, nrm(out.cross(self.FWD))) @ Rw
            self.set_local_rot_from_world(cl, Rw)
            upd()
        a, b = self.seg[side]
        L = a + b
        chest = self.frame_of(p["spine"][-1]) if p["spine"] else Matrix.Identity(3)
        Sh = self.posed(up).translation
        # objetivo de la mano
        tgt = S.get("hand", (0.2, 0.3, -0.7))
        space = S.get("space", "chest")
        if space == "chest":
            T = Sh + self.cv(tgt, side, chest) * L
        elif space == "mid":  # relativo al punto medio entre hombros, ejes del pecho
            other = "L" if side == "R" else "R"
            Sh2 = self.posed(p["arm"][other][0]).translation
            mid = (Sh + Sh2) * 0.5
            T = mid + self.cv(tgt, side, chest) * L
        elif space == "root":
            rf = self.frame_of(p["root"])
            T = self.posed(p["root"]).translation + self.cv(tgt, side, rf) * L
        elif space == "char":
            T = self.posed(p["root"]).translation + self.cv(tgt, side) * L
        elif space == "shoulder_char":  # desde el hombro, ejes del personaje (apuntar)
            T = Sh + self.cv(tgt, side) * L
        elif space == "grip":  # segunda mano en el mango de un arma de la otra mano
            other = S["rel"]
            gR, ax_b, nO, fO, wrist_off = self.grip_frame(other)
            gL = gR - ax_b * S.get("spacing", 0.9) * self.hand_len(other)
            n_t, f_t = nO, -fO
            T = gL - f_t * wrist_off[0] - n_t * wrist_off[1]
            S = dict(S)
            S["_grip_orient"] = (n_t, f_t)
        elif space == "hand":  # relativo a la otra mano (ya resuelta)
            other = S["rel"]
            oha = p["arm"][other][2]
            Mo = self.posed(oha)
            fo3 = self.frame_of(oha)
            T = Mo.translation + self.cv(tgt, side, fo3) * L
        else:
            raise ValueError(space)
        # IK de 2 huesos analítico
        pole_dir = self.cv(S.get("elbow", (0.3, -0.2, -1.0)), side, chest)
        d_vec = T - Sh
        d = max(min(d_vec.length, (a + b) * 0.999), abs(a - b) * 1.001 + 1e-6)
        u = nrm(d_vec)
        v = orth(pole_dir, u)
        cos_a = (a * a + d * d - b * b) / (2 * a * d)
        cos_a = max(-1.0, min(1.0, cos_a))
        sin_a = math.sqrt(1 - cos_a * cos_a)
        E = Sh + (u * cos_a + v * sin_a) * a
        W = Sh + u * d
        ud = nrm(E - Sh)
        fd = nrm(W - E)
        h = ud.cross(fd)
        if h.length < 1e-4:
            # brazo totalmente recto: usar plano del polo
            h = ud.cross(v)
        h.normalize()
        Ru = rot_from_frames(self.hinge_up_local[side], Vector((0, 1, 0)), h, ud)
        Mu = Ru.to_4x4()
        Mu.translation = Sh
        self.set_world_matrix(up, Mu)
        upd()
        Rf = rot_from_frames(self.hinge_fo_local[side], Vector((0, 1, 0)), h, fd)
        Mf = Rf.to_4x4()
        Mf.translation = self.posed(fo).translation
        self.set_world_matrix(fo, Mf)
        upd()
        # mano
        hs = S.get("hand_space", "chest")
        if hs == "chest":
            fr = chest
        elif hs == "char":
            fr = Matrix.Identity(3)
        elif hs == "fore":
            fr = self.frame_of(fo)
        else:
            fr = chest
        palm = S.get("palm")
        fing = S.get("fingers")
        if "blade" in S:
            # orientar la mano para que la hoja apunte a `blade` (espacio personaje por defecto)
            bs = S.get("blade_space", "char")
            bfr = Matrix.Identity(3) if bs == "char" else chest
            a_t = nrm(self.cv(S["blade"], side, bfr))
            hint = S.get("edge", (0, 0, 1))  # hacia dónde mira la palma (aprox.)
            n_t = orth(self.cv(hint, side, bfr), a_t)
            tilt = self.p.get("grip_tilt", 20.0) * D2R
            if side == "R":
                t_t = Matrix.Rotation(-tilt, 3, n_t) @ a_t
                f_t = nrm(n_t.cross(t_t))
            else:
                t_t = Matrix.Rotation(tilt, 3, n_t) @ a_t
                f_t = nrm(t_t.cross(n_t))
            Rh = rot_from_frames(self.palm_local[side], Vector((0, 1, 0)), n_t, f_t)
            Mh = Rh.to_4x4()
        elif "_grip_orient" in S:
            n_t, f_t = S["_grip_orient"]
            Rh = rot_from_frames(self.palm_local[side], Vector((0, 1, 0)), n_t, f_t)
            Mh = Rh.to_4x4()
        elif palm is None and fing is None:
            # muñeca neutra: conservar relación de reposo con el antebrazo
            Rh = self.frame_of(fo)
            wr = S.get("wrist", (0, 0, 0))  # (flex palmar, desviación, pronación) grados
            Rh = self._wrist_offset(side, Rh, wr)
            Mh = (Rh @ self.rest3(ha)).to_4x4()
        else:
            n_t = nrm(self.cv(palm, side, fr)) if palm is not None else None
            f_t = nrm(self.cv(fing, side, fr)) if fing is not None else None
            if f_t is None:
                f_t = orth(fd, n_t)
            if n_t is None:
                # palma: la de reposo arrastrada por el antebrazo
                n_t = orth(self.frame_of(fo) @ self.palm_rest[side], f_t)
            Rh = rot_from_frames(self.palm_local[side], Vector((0, 1, 0)), n_t, f_t)
            Mh = Rh.to_4x4()
        Mh.translation = self.posed(ha).translation
        self.set_world_matrix(ha, Mh)
        upd()

    def hand_len(self, side):
        ha = self.p["arm"][side][2]
        chain = self.p["fingers"][side].get("middle")
        if chain:
            return (self.head_rest(chain[-1]) - self.head_rest(ha)).length + self.bones[chain[-1]].length
        return self.bones[ha].length * 1.8

    def hand_axes(self, side):
        """(muñeca, normal palma, dir dedos, dir pulgar) de la mano posada."""
        ha = self.p["arm"][side][2]
        M = self.posed(ha)
        R3 = M.to_3x3().normalized()
        n = nrm(R3 @ self.palm_local[side])
        f = nrm(R3.col[1])
        t = n.cross(f) if side == "L" else f.cross(n)
        return M.translation.copy(), n, f, nrm(t)

    def grip_frame(self, side):
        """Centro del puño y eje del mango (hacia la hoja) de la mano `side`."""
        w, n, f, t = self.hand_axes(side)
        hl = self.hand_len(side)
        wrist_off = (0.42 * hl, 0.18 * hl)
        g = w + f * wrist_off[0] + n * wrist_off[1]
        tilt = self.p.get("grip_tilt", 20.0) * D2R  # hoja inclinada hacia los dedos
        a = nrm(t * math.cos(tilt) + f * math.sin(tilt))
        return g, a, n, f, wrist_off

    def _wrist_offset(self, side, Rbase, wr):
        flex, dev, pron = wr
        n = Rbase @ self.palm_rest[side]
        fdir = nrm(Rbase @ self.rest3(self.p["arm"][side][2]).col[1])
        ax_flex = fdir.cross(n)  # flexión palmar lleva los dedos hacia la palma
        R1 = Matrix.Rotation(flex * D2R, 3, nrm(ax_flex))
        sgn = 1 if side == "L" else -1
        R2 = Matrix.Rotation(dev * sgn * D2R, 3, nrm(n))
        R3 = Matrix.Rotation(pron * sgn * D2R, 3, fdir)
        return R3 @ R2 @ R1 @ Rbase

    # dedos -----------------------------------------------------------------
    def _apply_fingers(self, side, F):
        if not F:
            F = {}
        chains = self.p["fingers"][side]
        curl = F.get("curl", 0.1)       # 0 abierta .. 1 puño
        claw = F.get("claw", 0.0)       # garra: base extendida, puntas flexionadas
        spread = F.get("spread", 0.0)   # grados de abanico
        thumb = F.get("thumb", curl)
        per = F.get("per", {})          # override por dedo: {"index": 0.2}
        order = ["index", "middle", "ring", "pinky"]
        for f, chain in chains.items():
            c = per.get(f, thumb if f == "thumb" else curl)
            for j, bn in enumerate(chain):
                if f == "thumb":
                    ang = [25, 30, 35][min(j, 2)] * c
                else:
                    base = [70, 95, 70][min(j, 2)] * c
                    cl = [-20, 70, 60][min(j, 2)] * claw
                    ang = base + cl
                q = Quaternion(self.finger_axis[bn], ang * D2R)
                if j == 0 and f in order and spread:
                    k = order.index(f)
                    sp = (k - 1.2) * spread / 1.5
                    n_local = self.rest3(bn).inverted() @ self.palm_rest[side]
                    sgn = 1 if side == "L" else -1
                    q = Quaternion(nrm(n_local), sp * sgn * D2R) @ q
                self._set_q(bn, q)

    # --------------------------------------------------------- keyframes
    def channels(self):
        """Huesos animados por la librería."""
        p = self.p
        out = [p["root"]]
        for k in ("hips", "neck", "head"):
            if p[k] in self.pb:
                out.append(p[k])
        out += p["spine"] + p["tail"]
        for side in ("L", "R"):
            if p["clav"][side] in self.pb:
                out.append(p["clav"][side])
            out += [b for b in p["arm"][side] if b in self.pb]
            for chain in p["fingers"][side].values():
                out += chain
            for k in ("foot_ik", "pole"):
                if p[k][side] in self.pb:
                    out.append(p[k][side])
        return out

    def key_all(self, frame, bones=None):
        for bn in bones or self.channels():
            pb = self.pb[bn]
            if pb.rotation_mode == "QUATERNION":
                q = pb.rotation_quaternion.copy()
                prev = self.prev_q.get(bn)
                if prev is not None and prev.dot(q) < 0:
                    q.negate()
                    pb.rotation_quaternion = q
                self.prev_q[bn] = q.copy()
                pb.keyframe_insert("rotation_quaternion", frame=frame, group=bn)
            elif pb.rotation_mode == "AXIS_ANGLE":
                pb.keyframe_insert("rotation_axis_angle", frame=frame, group=bn)
            else:
                pb.keyframe_insert("rotation_euler", frame=frame, group=bn)
            if not all(pb.lock_location):
                pb.keyframe_insert("location", frame=frame, group=bn)

    def reset(self):
        for pb in self.ob.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.rotation_euler = (0, 0, 0)
            pb.scale = (1, 1, 1)
        upd()


# ======================================================================
# Construcción de acciones
# ======================================================================

def new_action(rig, name):
    ob = rig.ob
    if ob.animation_data is None:
        ob.animation_data_create()
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ob.animation_data.action = act
    rig.prev_q = {}
    return act


def fcurves_of(act):
    try:
        return list(act.fcurves)
    except Exception:
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out += list(cb.fcurves)
        return out


def build_action(rig, name, keys, fps=60, loop=False, lags=None, ease=None):
    """
    keys: lista de (tiempo_s, pose_parcial, opciones). Las poses se heredan.
    opciones: {"interp": "BEZIER"/"LINEAR"/..., "easing": "EASE_IN"/..., "lag": {grupo: frames}}
    lags: {grupo: frames} retraso global de overlap por grupo (solo claves internas)
    """
    act = new_action(rig, name)
    rig.reset()
    pose = {}
    frames = []
    for t, P, *opt in keys:
        pose = deep_merge(pose, P)
        f = round(t * fps)
        rig.apply(pose)
        rig.key_all(f)
        frames.append((f, opt[0] if opt else {}))
    # interpolación por segmento
    fmap = {f: o for f, o in frames}
    for fc in fcurves_of(act):
        for kp in fc.keyframe_points:
            o = fmap.get(round(kp.co.x), {})
            kp.interpolation = o.get("interp", "BEZIER")
            if "easing" in o:
                kp.easing = o["easing"]
            kp.handle_left_type = o.get("handle", "AUTO_CLAMPED")
            kp.handle_right_type = o.get("handle", "AUTO_CLAMPED")
        if loop:
            fc.modifiers.new("CYCLES")
        fc.update()
    # overlap: desplazar claves internas por grupo
    if lags:
        groups = bone_groups(rig)
        first, last = frames[0][0], frames[-1][0]
        for fc in fcurves_of(act):
            bn = fc.data_path.split('"')[1] if '"' in fc.data_path else None
            for g, lag in lags.items():
                if bn in groups.get(g, ()):
                    for kp in fc.keyframe_points:
                        if first < kp.co.x < last or loop:
                            if loop and kp.co.x in (first, last):
                                continue
                            kp.co.x += lag
                            kp.handle_left.x += lag
                            kp.handle_right.x += lag
                    fc.update()
    act.frame_range = (frames[0][0], frames[-1][0])
    act.use_frame_range = True
    act.use_cyclic = bool(loop)
    return act


def bone_groups(rig):
    p = rig.p
    g = {"head": [p["neck"], p["head"]], "tail": list(p["tail"]), "spine": list(p["spine"])}
    for side in ("L", "R"):
        g.setdefault("arms", []).extend([b for b in [p["clav"][side]] + p["arm"][side][:2] if b in rig.pb])
        g.setdefault("hands", []).append(p["arm"][side][2])
        g.setdefault("fore", []).append(p["arm"][side][1])
        for chain in p["fingers"][side].values():
            g.setdefault("fingers", []).extend(chain)
    return g


# ======================================================================
# Capas procedurales (se hornean encima de las claves)
# ======================================================================

def _fc_map(act):
    m = {}
    for fc in fcurves_of(act):
        m[(fc.data_path, fc.array_index)] = fc
    return m


def bake_additive(rig, act, bone, f0, f1, fn, step=1):
    """Hornea fn(frame) -> Quaternion (local, multiplicado a la derecha) sobre el hueso."""
    pb = rig.pb[bone]
    m = _fc_map(act)
    if pb.rotation_mode != "QUATERNION":
        return
    dp = f'pose.bones["{bone}"].rotation_quaternion'
    fcs = [m.get((dp, i)) for i in range(4)]
    if any(fc is None for fc in fcs):
        return
    samples = []
    for f in range(f0, f1 + 1, step):
        q = Quaternion([fc.evaluate(f) for fc in fcs]).normalized()
        q2 = q @ fn(f)
        if q2.dot(q) < 0:
            q2.negate()
        samples.append((f, q2))
    prev = None
    for f, q in samples:
        if prev is not None and prev.dot(q) < 0:
            q.negate()
        prev = q
        for i, fc in enumerate(fcs):
            kp = fc.keyframe_points.insert(f, q[i], options={"FAST"})
            kp.interpolation = "BEZIER"
            kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
    for fc in fcs:
        fc.update()


def tremor(seed, amp_deg, cycles, length, axes=((1, 0, 0), (0, 0, 1)), env=None):
    """Temblor periódico: suma de senos con número ENTERO de ciclos en `length` frames
    (loop perfecto). env(frame)->0..1 escala la amplitud."""
    import random
    rnd = random.Random(seed)
    comps = []
    for ax in axes:
        for c in cycles:
            comps.append((Vector(ax), c, rnd.uniform(0, 2 * math.pi), rnd.uniform(0.5, 1.0)))
    tot = sum(w for *_, w in comps) / max(1, len(axes))

    def fn(f):
        e = env(f) if env else 1.0
        q = Quaternion()
        for ax, c, ph, w in comps:
            ang = amp_deg * D2R * e * (w / tot) * math.sin(2 * math.pi * c * f / length + ph)
            q = q @ Quaternion(ax, ang)
        return q
    return fn


def shift_keys(act, bone, lag, first, last, loop=False, length=None):
    """Desfasa claves de un hueso (overlap). En loops envuelve dentro del ciclo."""
    for fc in fcurves_of(act):
        if f'"{bone}"' not in fc.data_path:
            continue
        for kp in fc.keyframe_points:
            x = kp.co.x
            if loop:
                if x in (first, last):
                    continue
            elif not (first < x < last):
                continue
            kp.co.x += lag
            kp.handle_left.x += lag
            kp.handle_right.x += lag
        fc.update()


def add_markers(act, marks, fps):
    for name, t in marks:
        m = act.pose_markers.new(name)
        m.frame = round(t * fps)
