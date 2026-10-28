"""Genera el ModuleScript Luau (y un .rbxmx insertable) desde vfx_specs.py.
uso: python gen_luau.py <outdir>"""
import os
import re
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vfx_specs as SP

LUA_KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local",
                "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue"}


def lua(v, ind=0):
    pad = "\t" * ind
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        r = round(float(v), 4)
        return str(int(r)) if r == int(r) else repr(r)
    if isinstance(v, str):
        return '"' + v + '"'
    if isinstance(v, (list, tuple)):
        if all(not isinstance(x, (list, tuple, dict)) for x in v):
            return "{" + ", ".join(lua(x) for x in v) + "}"
        return "{\n" + ",\n".join(pad + "\t" + lua(x, ind + 1) for x in v) + ",\n" + pad + "}"
    if isinstance(v, dict):
        items = []
        for k, x in v.items():
            key = f'["{k}"]' if k in LUA_KEYWORDS else k
            items.append(pad + "\t" + key + " = " + lua(x, ind + 1))
        return "{\n" + ",\n".join(items) + ",\n" + pad + "}"
    raise TypeError(type(v))


def norm_layer(L):
    """Rellena valores por defecto y traduce el flipbook 'estático aleatorio'."""
    o = dict(L)
    for k in ("rock_emit", "rock_stream"):
        if k in o:
            o[k] = [[list(e) for e in var] for var in o[k]]
    for k in ("final_emit", "final_stream", "cone_emit", "ring_emit", "zstream", "points"):
        if k in o:
            o[k] = [list(e) for e in o[k]]
    if "zdist" in o:
        o["zdist"] = {"r": list(o["zdist"]["r"]), "h": list(o["zdist"]["h"]), "area": bool(o["zdist"].get("area"))}
    if o.get("type") == "meteor":
        o.setdefault("spread", (0, 0))
        o.setdefault("direction", "Top")
        o.setdefault("accel", (0, -100, 0))
        o.setdefault("drag", 0)
        o.setdefault("offset", (0, 0, 0))
        o["emit"] = [list(e) for e in o.get("emit", [])]
        sp = dict(o["sprite"])
        o["rock"] = {"size": list(sp["size"]), "spin": list(sp.get("rot_speed", (0, 0))),
                     "material": sp.get("material", "Slate"),
                     "color": list(sp.get("color", (95, 78, 70))),
                     # proporción de la pieza (ancho, alto, fondo), derecha (sin dar vueltas) y clavada en el suelo
                     "aspect": list(sp.get("aspect", (1, 0.8, 0.9))), "upright": bool(sp.get("upright", False)),
                     "stick": sp.get("stick", 0), "sink": sp.get("sink", 0.3)}
        if sp.get("ground"):            # toma el color y el material del suelo donde sale
            o["rock"]["ground"] = True
        if sp.get("color_var"):         # cada pieza un poco más clara u oscura
            o["rock"]["color_var"] = list(sp["color_var"])
        del o["sprite"]
        o["trails"] = [norm_layer(T) for T in o.get("trails", [])]
        o["land"] = [norm_layer(T) for T in o.get("land", [])]
        o["shatter"] = [norm_layer(T) for T in o.get("shatter", [])]     # al romperse la pieza clavada
        return o
    o.setdefault("speed", (0, 0))
    o.setdefault("spread", (0, 0))
    o.setdefault("direction", "Top")
    o.setdefault("accel", (0, 0, 0))
    o.setdefault("drag", 0)
    o.setdefault("transparency", [(0, 0), (1, 0)])
    o.setdefault("color", [(0, (255, 255, 255)), (1, (255, 255, 255))])
    o.setdefault("light_emission", 0)
    o.setdefault("brightness", 1)
    o.setdefault("rotation", (0, 0))
    o.setdefault("rot_speed", (0, 0))
    o.setdefault("zoffset", 0)
    o.setdefault("orientation", "FacingCamera")
    o.setdefault("offset", (0, 0, 0))
    o.setdefault("line_u", 0)
    o["size"] = [list(k) + [0] * (3 - len(k)) for k in o["size"]]
    o["transparency"] = [list(k) + [0] * (3 - len(k)) for k in o["transparency"]]
    o["color"] = [[k[0], list(k[1])] for k in o["color"]]
    o["emit"] = [list(e) for e in o.get("emit", [])]
    if o.get("stream"):
        o["stream"] = [list(w) for w in o["stream"]]
    if o.get("slide"):            # bill: corrimiento en pantalla (studs), una secuencia por eje
        o["slide_x"] = [[k[0], k[1]] for k in o["slide"]]
        o["slide_y"] = [[k[0], k[2]] for k in o["slide"]]
        del o["slide"]
    if o.get("flip_t"):           # bill: cuadro del flipbook según la vida
        o["flip_t"] = [list(k) for k in o["flip_t"]]
    fb = o.get("flipbook")
    if fb:
        layout, mode, fps, start_random = fb
        if mode == "Random" and fps <= 0:      # frame aleatorio fijo por partícula
            mode, fps = "Loop", 0.001
        o["flipbook"] = {"layout": layout, "mode": mode, "fps": fps, "startRandom": bool(start_random)}
    sh = o.get("shape")
    if sh:
        if sh["type"] == "Box":
            o["shape"] = {"type": "Box", "size": list(sh["size"]), "style": sh.get("style", "Volume"),
                          "inout": sh.get("inout", "Outward")}
            if sh.get("len_k"):         # la caja se estira a lo largo de la línea: largo × len_k
                o["shape"]["len_k"] = sh["len_k"]
        else:
            o["shape"] = {"type": sh["type"], "radius": sh["radius"], "style": sh.get("style", "Volume"),
                          "inout": sh.get("inout", "Outward")}
    return o


def layer_end(L, jitter=0.0):
    """Momento (s) en que muere la última partícula de la capa (cota superior para las rocas).
    jitter = retraso aleatorio máximo por roca (efectos sobre rocas)."""
    life = L.get("lifetime", (0, 0))[1]
    starts = [ev[0] for ev in L.get("emit", [])]
    starts += [ev[0] + jitter for var in L.get("rock_emit", []) for ev in var]
    starts += [ev[0] + jitter for ev in L.get("final_emit", [])]
    starts += [ev[0] for ev in L.get("cone_emit", [])]
    starts += [ev[0] for ev in L.get("ring_emit", [])]
    starts += [ev[0] for ev in L.get("points", [])]
    if L.get("type") == "meteor":
        after = 0.0
        for T in L.get("trails", []):
            after = max(after, T["lifetime"][1])
        for T in L.get("land", []):
            after = max(after, T["lifetime"][1] + max([w[1] for w in T.get("stream", [])] + [0]))
        stick = L.get("sprite", L.get("rock", {})).get("stick", 0)
        if stick:
            after = max(after, stick + max([T["lifetime"][1] for T in L.get("shatter", [])] + [0]))
        life += after
    ends = [t + life for t in starts]
    delays = [0.0] if not (L.get("rock_stream") or L.get("final_stream")) else \
        [src[0] + jitter for var in L.get("rock_stream", []) for src in var] + \
        [src[0] + jitter for src in L.get("final_stream", [])]
    ends += [d + w[1] + life for w in L.get("stream", []) for d in delays]
    ends += [w[1] + life for w in L.get("zstream", [])]
    if L.get("clear_at") is not None:          # lo que queda se borra con Emitter:Clear()
        ends = [min(e, L["clear_at"]) for e in ends]
    if L.get("fade_at"):                       # lo que queda se desvanece y se borra
        ends = [min(e, L["fade_at"][0] + L["fade_at"][1]) for e in ends]
    return max(ends) if ends else 0.0


def cubes_end(C):
    """Cota superior del momento en que desaparece el último cubo de destrucción."""
    g, b = C["gravity"], C["bounce"]
    end = 0.0
    for G in C["groups"]:
        if G["mode"] == "vortex":
            # al acabar el pilar los que quedan se sueltan y se desintegran en menos de 0.45 s
            end = max(end, G["release"] + 0.45 + C["shrink"][1] + C["fx"]["lifetime"][1])
            continue
        t_launch = G["release"][1] if G["mode"] == "lift" else G["t"][1]
        up = G["up"][1]
        h0 = G["size"][1] + (G["lift"][1] if G["mode"] == "lift" else 0.0)
        v_hit = (up * up + 2 * g * h0) ** 0.5
        fly = (up + v_hit) / g
        vb = v_hit * b
        bounces = 2 * vb * (1 + b + b * b) / g
        end = max(end, t_launch + fly + bounces + C["settle"] + C["rest"][1] + C["fade"])
    return end


def spec_end(spec):
    jit = spec.get("rocks", {}).get("jitter", 0.0)
    B = spec.get("beam")

    def end_of(L):
        # en el rayo, las capas on_hit y trail pueden salir hasta el corte
        if B and (L.get("on_hit") or L.get("trail")):
            delay = max([ev[0] for ev in L.get("emit", [])] + [0.0])
            return B["stop"] + delay + L.get("lifetime", (0, 0))[1]
        return layer_end(L, jit)
    end = max(end_of(L) for L in spec["layers"])
    if spec.get("cubes"):
        end = max(end, cubes_end(spec["cubes"]))
    if spec.get("beam"):
        end = max(end, spec["beam"]["stop"] + spec["beam"]["fade"])
    if spec.get("blade"):
        end = max(end, blade_end(spec["blade"], spec.get("line", 0)))
    if spec.get("field"):
        end = max(end, field_end(spec["field"]))
    if spec.get("front"):
        end = max(end, front_end(spec["front"]))
    if spec.get("zbeams"):
        end = max(end, max(max(B["width_t"][-1][0], B["alpha_t"][-1][0]) for B in spec["zbeams"]))
    if spec.get("zfield"):
        end = max(end, zfield_end(spec["zfield"]))
    return end


def norm_blade(B):
    """Los datos de la media luna para el módulo: trazos, emisores de la estela, corte, losas y cráter."""
    Bd = {k: plain(v) for k, v in B.items() if k not in ("strands", "emitters", "slab_color")}
    Bd["strands"] = [plain(S) for S in B["strands"]]
    Bd["emitters"] = [dict(norm_layer({k: v for k, v in E.items() if k not in ("at", "j", "arc_k", "rate")}),
                           at=list(E["at"]), j=E.get("j", 0.0), arc_k=E.get("arc_k", 1.0), rate=E["rate"])
                      for E in B.get("emitters", [])]
    return Bd


def plain(v):
    """Tuplas a listas, en profundidad (para escribir los datos en Lua)."""
    if isinstance(v, dict):
        return {k: plain(x) for k, x in v.items()}
    if isinstance(v, (list, tuple)):
        return [plain(x) for x in v]
    return v


def norm_field(F):
    """Los grupos de bloques y losas de la ola triangular (las partículas al reventar, normalizadas)."""
    out = {"wave": list(F["wave"]) + ([1.0] if len(F["wave"]) < 3 else []), "groups": []}
    for G in F["groups"]:
        g = {k: plain(v) for k, v in G.items() if k not in ("shatter", "preview_color")}
        g["mesh"] = G["name"]
        if G.get("shatter"):
            g["shatter"] = [norm_layer(L) for L in G["shatter"]]
        out["groups"].append(g)
    return out


ZF_DEFAULTS = {"hold": (1.0, 1.0), "sink": 0.4}


def norm_zfield(F):
    """Los grupos de cristales y losas de una zona circular (las partículas al reventar, normalizadas)."""
    out = {"groups": []}
    for G in F["groups"]:
        g = {k: plain(v) for k, v in dict(ZF_DEFAULTS, **G).items() if k not in ("shatter", "preview_color")}
        g["mesh"] = G["name"]
        if G.get("shatter"):
            g["shatter"] = [norm_layer(L) for L in G["shatter"]]
        out["groups"].append(g)
    return out


def zfield_end(F):
    """Cuándo termina lo último del campo de la zona (las piezas que revientan y sus partículas): cota superior."""
    end = 0.0
    for G in F["groups"]:
        G = dict(ZF_DEFAULTS, **G)
        t = G["end_at"][1] if G.get("end_at") else G["t"] + G.get("sweep", 0.0) + G["delay"][1] + G["rise"] + G["hold"][1]
        after = max([L["lifetime"][1] for L in G.get("shatter", [])] + [0]) if G.get("end") == "shatter" else G["sink"]
        end = max(end, t + after)
    return end


def norm_zbeam(B):
    """Una columna de luz de la zona (Beams): valores por defecto y secuencias como listas."""
    o = dict({"count": 1, "r": 0.0, "a0": 0.0, "spin": 0.0, "wobble": 0.0, "near": 0.0, "zoffset": 0.0}, **B)
    o = {k: plain(v) for k, v in o.items()}
    o["rim"] = bool(B.get("rim"))
    return o


def wave_time(wave, u):
    """Cuándo el frente de la ola triangular llega a u: sale rápido y se va frenando (wave = T0, TW, freno)."""
    ease = wave[2] if len(wave) > 2 else 1.0
    return wave[0] + wave[1] * (1 - (1 - min(max(u, 0.0), 1.0)) ** (1 / ease))


def norm_front(Fr):
    """Los emisores que viajan con el frente de la ola (capas normalizadas, con su tasa, altura e inclinación)."""
    w = list(Fr["wave"]) + ([1.0] if len(Fr["wave"]) < 3 else [])
    return {"wave": w, "count": Fr["count"], "s_max": Fr["s_max"],
            "emitters": [dict(norm_layer({k: v for k, v in E.items() if k not in ("rate", "up", "pitch")}),
                              rate=E["rate"], up=E.get("up", 0.0), pitch=E.get("pitch", 0.0)) for E in Fr["emitters"]]}


def front_end(Fr):
    return Fr["wave"][0] + Fr["wave"][1] + max(E["lifetime"][1] for E in Fr["emitters"])


def field_end(F):
    """Cuándo termina lo último del campo (los bloques que revientan y sus partículas): cota superior."""
    end = 0.0
    for G in F["groups"]:
        t = wave_time(F["wave"], G["u"][1]) + G["delay"][1] + G["rise"] + G["hold"][1]
        after = max([L["lifetime"][1] for L in G.get("shatter", [])] + [0]) if G.get("end") == "shatter" else G["sink"]
        end = max(end, t + after)
    return end


def blade_end(B, length):
    """Cuándo termina todo lo de la media luna (la estela, el corte, las losas y el cráter): cota superior."""
    end = B["t0"] + B["travel"] + B["fade"]
    t_end = B["t0"] + B["travel"]
    for E in B.get("emitters", []):
        end = max(end, t_end + E["lifetime"][1])
    if B.get("light"):
        end = max(end, t_end + B["light"].get("flash_time", 0))
    if B.get("gash"):
        G = B["gash"]
        end = max(end, t_end + G["life"] + G["fade"])
    if B.get("slabs"):
        SL = B["slabs"]
        end = max(end, t_end + SL["delay"] + SL["rise"] + SL["hold"][1] + SL["sink"])
    if B.get("crater"):
        CR = B["crater"]
        end = max(end, t_end + CR["at"] + CR["delay"] + CR["rise"] + CR["hold"][1] + CR["sink"])
    return end


def textures_of(layers):
    out = set()
    for L in layers:
        if "texture" in L:
            out.add(L["texture"])
        for k in ("trails", "land"):
            out |= textures_of(L.get(k, []))
    return out


DOC_KAIJU = """	KaijuFireVFX — VFX de fuego y lava para KAIJU ZERO
	(generado automáticamente desde vfx_specs.py; edita allí y regenera)

	USO (en el CLIENTE, por ejemplo al recibir un RemoteEvent del servidor):
		local KaijuFireVFX = require(ReplicatedStorage.KaijuFireVFX)
		-- cf = punto del SUELO bajo la explosión; 1 = escala; 1 = intensidad de la sacudida de cámara
		KaijuFireVFX.GiantExplosion(CFrame.new(puntoEnElSuelo), 1, 1)
		-- ULTIMATE: rayo de la boca al rival (o adonde lo apuntes con rayo:AimAt); se ignora al propio kaiju
		local rayo = KaijuFireVFX.UltimateBeam(bocaDeKaijuZero, rival, 1, 1, { modeloDeKaijuZero })
		-- golpes que recibe el rival: corte en garra (en diagonal), corte quemado y mordisco
		KaijuFireVFX.SlashHit(rival, 1, 1)
		KaijuFireVFX.BiteHit(rival, 1, 1)"""

DOC_OMNIVORA = """	OmnivoraVFX — VFX cósmicos (azul muy oscuro, celeste y blanco, con el púrpura de su boca) para OMNÍVORA
	(generado automáticamente desde vfx_omnivora.py y vfx_blackhole.py; edita allí y regenera)

	USO (en el CLIENTE, por ejemplo al recibir un RemoteEvent del servidor):
		local OmnivoraVFX = require(ReplicatedStorage.OmnivoraVFX)
		-- cf = centro de la zona en el SUELO; radio y altura del pilar en studs; escala; sacudida
		OmnivoraVFX.CosmicPillar(CFrame.new(centroEnElSuelo), 18, 120, 1, 1)
		-- agujero negro desde la boca hasta dos enemigos (detona a los OmnivoraVFX.BlackHoleImpact s)
		OmnivoraVFX.BlackHole(bocaDeOmnivora, { enemigo1, enemigo2 }, 1, 1)"""

DOC_MOONFANG = """	MoonfangVFX — VFX del lobo kaiju lunar de cristal (plata, hielo y azul cristal) para MOONFANG
	(generado automáticamente desde vfx_moonfang.py; edita allí y regenera)

	USO (en el CLIENTE, por ejemplo al recibir un RemoteEvent del servidor):
		local MoonfangVFX = require(ReplicatedStorage.MoonfangVFX)
		MoonfangVFX.MoonBite(rival, 1, 1)                        -- M1 mordiscos 1-3
		MoonfangVFX.MoonBiteFinisher(rival, 1, 1)                -- M1 mordisco 4 (remate)
		MoonfangVFX.MoonFang(rival, 1, 1)                        -- pesado
		local guardia = MoonfangVFX.MoonGuard(moonfang)          -- bloqueo (guardia:Stop() al soltar)
		MoonfangVFX.MoonGuardHit(moonfang, 1, 1)                 -- cada golpe bloqueado
		MoonfangVFX.CrescentWave(CFrame.lookAt(origen, origen + direccion), 130, 1, 1)   -- skill 1
		MoonfangVFX.IceWave(CFrame.lookAt(origen, origen + direccion), nil, nil, 1, 1)  -- skill 2
		MoonfangVFX.LunarHowl(cabeza.CFrame, 1, 1)               -- skill 3 (y LunarAura para la mejora)
		MoonfangVFX.Eclipse(CFrame.new(centroEnElSuelo), 26, 150, 1, 1)   -- skill 4"""

DOC_ASTRAL = """	AstralColossusVFX — VFX cósmicos (galaxia: morado, azul y blanco) para ASTRAL COLOSSUS
	(generado automáticamente desde vfx_astral.py; edita allí y regenera)

	USO (en el CLIENTE, por ejemplo al recibir un RemoteEvent del servidor):
		local AstralColossusVFX = require(ReplicatedStorage.AstralColossusVFX)
		-- cf = vértice del triángulo en el SUELO (delante del kaiju), mirando hacia adelante
		-- largo en studs, ángulo del triángulo en grados, escala, sacudida
		AstralColossusVFX.AstralClash(cf, 70, 55, 1, 1)"""

HEADER = r'''--!nonstrict
--[[
__DOC__

	ANTES DE USARLO:
	  1) Sube las imágenes de la carpeta textures/ (Asset Manager > Images > Bulk Import).
	  2) Clic derecho en cada imagen > "Copy ID to clipboard" y pégalo en TEXTURES.
	     (Usa el ID de la IMAGEN, no el de un Decal.)

	CIERRE LIMPIO:
	  - Ráfagas con Emit(); la emisión continua baja su Rate hasta 0.
	  - Nada vive más que la duración del efecto: el contenedor se destruye al final.
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local KaijuFireVFX = {}

-- Pega aquí los IDs de las imágenes subidas
KaijuFireVFX.TEXTURES = {
__TEXTURES__
}

-- Dónde se crean los efectos (puedes cambiarlo por una carpeta de VFX)
KaijuFireVFX.Parent = workspace :: Instance
-- Multiplicador de cantidad de partículas (bájalo en dispositivos lentos, p.ej. 0.6)
KaijuFireVFX.Quality = 1
-- Luz breve en el impacto (del color del efecto)
KaijuFireVFX.UseLight = true
-- Modelos (MeshPart) para las piezas sólidas, por nombre de capa: si pones uno, el módulo lo clona en vez de
-- un bloque. Por ejemplo: MoonfangVFX.Meshes.IceChunks = ReplicatedStorage.MoonfangMeshes.IceChunk
KaijuFireVFX.Meshes = {} :: { [string]: Instance }

type Layer = { [string]: any }

local rng = Random.new()

local function numberSeq(points: { { number } }, scale: number): NumberSequence
	local kps = table.create(#points)
	for i, p in points do
		local v = math.clamp(p[2] * scale, 0, 100) -- Roblox no dibuja partículas de más de 100 studs
		kps[i] = NumberSequenceKeypoint.new(p[1], v, math.min((p[3] or 0) * scale, v))
	end
	return NumberSequence.new(kps)
end

local function transparencySeq(points: { { number } }): NumberSequence
	local kps = table.create(#points)
	for i, p in points do
		kps[i] = NumberSequenceKeypoint.new(p[1], math.clamp(p[2], 0, 1), p[3] or 0)
	end
	return NumberSequence.new(kps)
end

local function colorSeq(points: { any }): ColorSequence
	local kps = table.create(#points)
	for i, p in points do
		local c = p[2]
		kps[i] = ColorSequenceKeypoint.new(p[1], Color3.fromRGB(c[1], c[2], c[3]))
	end
	return ColorSequence.new(kps)
end

-- evaluación de secuencias (para los decals del suelo)
local function evalNum(points: { { number } }, t: number): number
	if t <= points[1][1] then
		return points[1][2]
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		if t <= b[1] then
			local u = (t - a[1]) / math.max(b[1] - a[1], 1e-6)
			return a[2] + (b[2] - a[2]) * u
		end
	end
	return points[#points][2]
end

local function evalColor(points: { any }, t: number): Color3
	local function c3(c)
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	if t <= points[1][1] then
		return c3(points[1][2])
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		if t <= b[1] then
			local u = (t - a[1]) / math.max(b[1] - a[1], 1e-6)
			return c3(a[2]):Lerp(c3(b[2]), u)
		end
	end
	return c3(points[#points][2])
end

local function invisiblePart(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function configureEmitter(L: Layer, scale: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = L.name
	e.Enabled = false
	e.Rate = 0
	e.Texture = KaijuFireVFX.TEXTURES[L.texture] or ""
	e.Lifetime = NumberRange.new(L.lifetime[1], L.lifetime[2])
	e.Speed = NumberRange.new(L.speed[1] * scale, L.speed[2] * scale)
	e.SpreadAngle = Vector2.new(L.spread[1], L.spread[2])
	e.EmissionDirection = (Enum.NormalId :: any)[L.direction]
	e.Acceleration = Vector3.new(L.accel[1], L.accel[2], L.accel[3]) * scale
	e.Drag = L.drag
	e.Size = numberSeq(L.size, scale)
	e.Transparency = transparencySeq(L.transparency)
	e.Color = colorSeq(L.color)
	e.LightEmission = L.light_emission
	e.LightInfluence = 0
	e.Brightness = L.brightness
	e.Rotation = NumberRange.new(L.rotation[1], L.rotation[2])
	e.RotSpeed = NumberRange.new(L.rot_speed[1], L.rot_speed[2])
	e.ZOffset = L.zoffset * scale
	e.Orientation = (Enum.ParticleOrientation :: any)[L.orientation]
	e.LockedToPart = false
	if L.flipbook then
		e.FlipbookLayout = (Enum.ParticleFlipbookLayout :: any)[L.flipbook.layout]
		e.FlipbookMode = (Enum.ParticleFlipbookMode :: any)[L.flipbook.mode]
		e.FlipbookFramerate = NumberRange.new(L.flipbook.fps)
		e.FlipbookStartRandom = L.flipbook.startRandom
	end
	if L.shape then
		e.Shape = (Enum.ParticleEmitterShape :: any)[L.shape.type]
		e.ShapeStyle = (Enum.ParticleEmitterShapeStyle :: any)[L.shape.style]
		e.ShapeInOut = (Enum.ParticleEmitterShapeInOut :: any)[L.shape.inout or "Outward"]
	end
	return e
end

-- posición local de un punto de la línea: u = fracción del largo (hacia adelante = -Z), lado, alto
local function linePos(u: number, side: number, up: number, scale: number, len: number): Vector3
	return Vector3.new(side * scale, up * scale, -u * len)
end

-- punto del triángulo hacia adelante: u = fracción del largo, s = fracción del medio ancho en esa
-- distancia, alto en studs. Devuelve la posición y la dirección desde el vértice hacia ese punto.
local function conePoint(holder: BasePart, ev: { number }, scale: number, len: number, tanH: number, pitch: number?): (Vector3, Vector3)
	local u, sf, up = ev[3], ev[4], ev[5]
	local pos = holder.CFrame:PointToWorldSpace(Vector3.new(sf * u * len * tanH, up * scale, -u * len))
	local dir = holder.CFrame:VectorToWorldSpace(Vector3.new(sf * tanH, 0, -1).Unit)
	if pitch and pitch ~= 0 then      -- inclina la salida hacia arriba (p. ej. rocas que saltan)
		local a = math.rad(pitch)
		dir = (dir * math.cos(a) + holder.CFrame.UpVector * math.sin(a)).Unit
	end
	return pos, dir
end

-- orienta el portador para que su "Front" mire en dir (las partículas salen en abanico)
local function aimCarrier(carrier: Instance, pos: Vector3, dir: Vector3)
	local cf = CFrame.lookAt(pos, pos + dir)
	if carrier:IsA("Attachment") then
		(carrier :: Attachment).WorldCFrame = cf
	else
		(carrier :: BasePart).CFrame = cf
	end
end

-- crea el emisor con su "portador": Part (si tiene forma) o Attachment
local function buildEmitter(L: Layer, holder: BasePart, scale: number, localPos: Vector3?, len: number?): (ParticleEmitter, Instance)
	local off = localPos
		or (Vector3.new(L.offset[1], L.offset[2], L.offset[3]) * scale + linePos(L.line_u or 0, 0, 0, scale, len or 0))
	local carrier: Instance
	if L.shape then
		local size
		if L.shape.type == "Box" then
			size = Vector3.new(L.shape.size[1], L.shape.size[2], L.shape.size[3]) * scale
			if L.shape.len_k and len then -- a lo largo de toda la línea (p. ej. el rayo)
				size = Vector3.new(size.X, size.Y, len * L.shape.len_k)
			end
		else
			local d = L.shape.radius * 2 * scale
			size = Vector3.new(d, d, d)
		end
		carrier = invisiblePart(L.name .. "_Shape", size, holder.CFrame * CFrame.new(off), holder)
	else
		local a = Instance.new("Attachment")
		a.Name = L.name
		a.Position = off
		a.Parent = holder
		carrier = a
	end
	local e = configureEmitter(L, scale)
	if L.speed_len and len and len > 0 then      -- velocidad proporcional al largo (la ola cruza el triángulo)
		e.Speed = NumberRange.new(L.speed_len[1] * len, L.speed_len[2] * len)
	end
	e.Parent = carrier
	return e, carrier
end

-- emisión continua: Rate interpolado por ventanas {t0, t1, rate0, rate1}
local function runStream(L: Layer, e: ParticleEmitter, delayStart: number?, windows: { any }?, mul: number?,
	gate: (() -> number)?)
	local W = windows or L.stream
	local tEnd = 0
	for _, w in W do
		tEnd = math.max(tEnd, w[2])
	end
	task.spawn(function()
		if delayStart and delayStart > 0 then
			task.wait(delayStart)
		end
		local t0 = time()
		while e.Parent do
			local t = time() - t0
			if t > tEnd then
				break
			end
			local rate = 0
			for _, w in W do
				if t >= w[1] and t <= w[2] then
					rate += w[3] + (w[4] - w[3]) * (t - w[1]) / math.max(w[2] - w[1], 1e-3)
				end
			end
			rate *= (mul or 1) * (if gate then gate() else 1)
			e.Rate = rate * KaijuFireVFX.Quality
			e.Enabled = rate > 0.05
			task.wait(0.05)
		end
		if e.Parent then
			e.Enabled = false
		end
	end)
end

local function quality(n: number): number
	return math.max(1, math.floor(n * KaijuFireVFX.Quality + 0.5))
end

-- coloca el portador del emisor (Attachment o Part con forma) en un punto del mundo
local function placeCarrier(carrier: Instance, holder: BasePart, pos: Vector3)
	if carrier:IsA("Attachment") then
		(carrier :: Attachment).WorldPosition = pos
	else
		(carrier :: BasePart).CFrame = holder.CFrame.Rotation + pos
	end
end

-- el portador de una capa del suelo va derecho (el suelo es horizontal; el rayo puede venir inclinado)
local function levelCarrier(carrier: Instance, pos: Vector3)
	if carrier:IsA("Attachment") then
		(carrier :: Attachment).WorldCFrame = CFrame.new(pos)
	else
		(carrier :: BasePart).CFrame = CFrame.new(pos)
	end
end

-- elemento plano del suelo hecho con Decal (sin límite de tamaño); baseCF = dónde va (horizontal)
local function playDecalAt(L: Layer, holder: BasePart, scale: number, n: number, baseCF: CFrame)
	for _ = 1, n do
		local life = rng:NextNumber(L.lifetime[1], L.lifetime[2])
		local rot = math.rad(rng:NextNumber(L.rotation[1], L.rotation[2]))
		local spin = math.rad(rng:NextNumber(L.rot_speed[1], L.rot_speed[2]))
		local cf = baseCF * CFrame.Angles(0, rot, 0)
		local p = invisiblePart(L.name, Vector3.new(0.1, 0.05, 0.1), cf, holder)
		-- los Decals no tienen LightEmission: un Color3 mayor que 1 los hace brillar (con Bloom)
		local glow = 1 + 1.5 * (L.light_emission or 0)
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Top
		d.Texture = KaijuFireVFX.TEXTURES[L.texture] or ""
		d.Transparency = 1
		d.Parent = p
		local t0 = time()
		local conn: RBXScriptConnection
		conn = RunService.Heartbeat:Connect(function()
			local t = (time() - t0) / life
			if t >= 1 or not p.Parent then
				conn:Disconnect()
				p:Destroy()
				return
			end
			local sz = math.max(evalNum(L.size, t) * scale, 0.1)
			p.Size = Vector3.new(sz, 0.05, sz)
			p.CFrame = if spin ~= 0 then cf * CFrame.Angles(0, spin * t * life, 0) else cf
			d.Transparency = math.clamp(evalNum(L.transparency, t), 0, 1)
			local c = evalColor(L.color, t)
			d.Color3 = Color3.new(c.R * glow, c.G * glow, c.B * glow)
		end)
	end
end

-- ráfagas Emit() programadas (y posiciones a lo largo de una línea)
local function scheduleBursts(L: Layer, e: ParticleEmitter, carrier: Instance, holder: BasePart, s: number, len: number)
	local baseOff = Vector3.new(L.offset[1], L.offset[2], L.offset[3]) * s
	for _, ev in L.emit do
		local t, n = ev[1], quality(ev[2])
		local off = baseOff + linePos(L.line_u or 0, 0, 0, s, len)
		if ev[3] ~= nil then
			off = baseOff + linePos(ev[3], ev[4], ev[5], s, len)
		end
		local function fire()
			if not e.Parent then
				return
			end
			placeCarrier(carrier, holder, holder.CFrame:PointToWorldSpace(off))
			e:Emit(n)
		end
		if t <= 0 then
			fire()
		else
			task.delay(t, fire)
		end
	end
end

-- rocas en llamas: vuelan con estela, y al caer levantan polvo y dejan fuego
local function landAt(L: Layer, holder: BasePart, s: number, worldPos: Vector3, list: { Layer }?)
	-- un ancla quieta en el punto donde cayó: lo que arde ahí no se mueve aunque el contenedor se mueva
	local anchor = invisiblePart("Land", Vector3.new(0.2, 0.2, 0.2), CFrame.new(worldPos), holder)
	for _, LL in list or L.land do
		if LL.decal then
			playDecalAt(LL, holder, s, LL.emit[1][2], CFrame.new(worldPos))
			continue
		end
		local e, carrier = buildEmitter(LL, anchor, s, Vector3.zero)
		levelCarrier(carrier, worldPos)
		if LL.stream then
			runStream(LL, e)
		else
			e:Emit(quality(LL.emit[1][2]))
		end
	end
end

local GROUND_FALLBACK = Color3.fromRGB(112, 106, 112)

-- color, material y altura del suelo bajo pos (los cubos de destrucción salen de ahí); exclude = lo que se ignora
local function groundLook(pos: Vector3, exclude: { Instance }, depth: number?): (Color3, Enum.Material, number?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = table.clone(exclude)
	for _ = 1, 4 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -(depth or 40), 0), params)
		if not hit then
			break
		end
		local inst = hit.Instance
		local model = inst:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			table.insert(ignore, model) -- un personaje encima: se ignora y se busca el suelo debajo
			continue
		end
		local mat = hit.Material
		if mat == Enum.Material.Water or mat == Enum.Material.Air then
			mat = Enum.Material.Slate
		end
		if inst:IsA("Terrain") then
			local ok, c = pcall(function()
				return (inst :: Terrain):GetMaterialColor(hit.Material)
			end)
			return if ok then c else GROUND_FALLBACK, mat, hit.Position.Y
		end
		return inst.Color, mat, hit.Position.Y
	end
	return GROUND_FALLBACK, Enum.Material.Slate, nil
end

-- lanza n rocas desde pos; groundY = altura del suelo donde caen
local function launchMeteors(L: Layer, holder: BasePart, s: number, n: number, pos: Vector3, groundY: number, frame: CFrame?)
	local accel = Vector3.new(L.accel[1], L.accel[2], L.accel[3]) * s
	local baseDir = ({
		Top = Vector3.yAxis, Bottom = -Vector3.yAxis, Front = -Vector3.zAxis, Back = Vector3.zAxis,
		Right = Vector3.xAxis, Left = -Vector3.xAxis,
	} :: any)[L.direction]
	-- las rocas del suelo toman su color y su material (una vez por tanda)
	local groundColor: Color3?, groundMat: Enum.Material? = nil, nil
	if L.rock.ground then
		groundColor, groundMat = groundLook(pos, { holder })
	end
	local template = KaijuFireVFX.Meshes[L.name]
	local list = {}
	for i = 1, n do
		local spread = if L.direction == "Front" or L.direction == "Back"
			then CFrame.Angles(math.rad(rng:NextNumber(-L.spread[2], L.spread[2])),
				math.rad(rng:NextNumber(-L.spread[1], L.spread[1])), 0)
			else CFrame.Angles(math.rad(rng:NextNumber(-L.spread[1], L.spread[1])), 0,
				math.rad(rng:NextNumber(-L.spread[2], L.spread[2])))
		local dir = (frame or holder.CFrame):VectorToWorldSpace((spread :: CFrame):VectorToWorldSpace(baseDir))
		local sz = rng:NextNumber(L.rock.size[1], L.rock.size[2]) * s
		local start = pos
		if L.shape and L.shape.type == "Box" then -- cada pieza sale de un punto al azar de la caja
			local b = L.shape.size
			start = pos + (frame or holder.CFrame):VectorToWorldSpace(Vector3.new(rng:NextNumber(-0.5, 0.5) * b[1],
				rng:NextNumber(-0.5, 0.5) * b[2], rng:NextNumber(-0.5, 0.5) * b[3]) * s)
		end
		local asp = L.rock.aspect or { 1, 0.8, 0.9 }
		local rock: BasePart
		if template and template:IsA("BasePart") then
			-- un modelo hecho en Blender (MeshPart): conserva su aspecto y se escala al tamaño de la pieza
			rock = (template :: BasePart):Clone()
			local big = math.max(rock.Size.X, rock.Size.Y, rock.Size.Z)
			rock.Size = rock.Size * (sz * math.max(asp[1], asp[2], asp[3]) / math.max(big, 1e-3))
		else
			rock = Instance.new("Part")
			rock.Material = groundMat or (Enum.Material :: any)[L.rock.material or "Slate"]
			local c = groundColor or Color3.fromRGB(L.rock.color[1], L.rock.color[2], L.rock.color[3])
			if L.rock.color_var then
				local v = rng:NextNumber(L.rock.color_var[1], L.rock.color_var[2])
				c = Color3.new(math.min(c.R * v, 1), math.min(c.G * v, 1), math.min(c.B * v, 1))
			end
			rock.Color = c
			rock.Size = Vector3.new(sz * asp[1], sz * asp[2], sz * asp[3])
		end
		rock.Name = "Rock"
		rock.Anchored = true
		rock.CanCollide = false
		rock.CanQuery = false
		rock.CanTouch = false
		rock.CastShadow = false
		rock.CFrame = CFrame.new(start)
		rock.Parent = holder
		local att = Instance.new("Attachment")
		att.Parent = rock
		local emitters = {}
		for _, TL in L.trails do
			local te = configureEmitter(TL, s)
			te.Rate = TL.rate * KaijuFireVFX.Quality
			te.LockedToPart = TL.locked == true -- p.ej. el resplandor de la roca fundida va pegado a ella
			te.Enabled = true
			te.Parent = att
			table.insert(emitters, te)
		end
		local spin = math.rad(rng:NextNumber(L.rock.spin[1], L.rock.spin[2]))
		list[i] = {
			rock = rock, pos = start, vel = dir * rng:NextNumber(L.speed[1], L.speed[2]) * s,
			age = 0, life = rng:NextNumber(L.lifetime[1], L.lifetime[2]),
			rot = if L.rock.upright then CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
				else CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0),
			spinAxis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit,
			spin = spin, emitters = emitters, done = false,
		}
	end
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		local alive = 0
		for _, m in list do
			if m.done then
				continue
			end
			alive += 1
			m.vel = m.vel * 2 ^ (-L.drag * dt) + accel * dt
			m.pos += m.vel * dt
			m.age += dt
			m.rot = CFrame.fromAxisAngle(m.spinAxis, m.spin * dt) * m.rot
			m.rock.CFrame = CFrame.new(m.pos) * m.rot
			if (m.pos.Y <= groundY + 0.3 * s and m.vel.Y < 0) or m.age >= m.life then
				m.done = true
				for _, te in m.emitters do
					te.Enabled = false
				end
				local onGround = m.pos.Y <= groundY + 0.6 * s
				local stick = L.rock.stick or 0
				if onGround and stick > 0 then
					-- se queda clavada (hundida un poco) y después se rompe
					local rock = m.rock
					local sunk = rock.Size.Y * (0.5 - (L.rock.sink or 0.3))
					rock.CFrame = CFrame.new(m.pos.X, groundY + sunk, m.pos.Z) * m.rot
					task.delay(stick, function()
						if rock.Parent and holder.Parent then
							rock.Transparency = 1
							landAt(L, holder, s, Vector3.new(m.pos.X, groundY + rock.Size.Y * 0.4, m.pos.Z), L.shatter)
						end
					end)
				else
					m.rock.Transparency = 1
				end
				if onGround then
					landAt(L, holder, s, Vector3.new(m.pos.X, groundY + 0.4 * s, m.pos.Z))
				end
			end
		end
		if alive == 0 then
			conn:Disconnect()
		end
	end)
end

local function playMeteors(L: Layer, holder: BasePart, s: number, len: number, groundY: number?)
	local gy = groundY or holder.Position.Y
	for _, ev in L.emit do
		local n = quality(ev[2])
		local startOff = Vector3.new(L.offset[1], L.offset[2], L.offset[3]) * s
		if ev[3] ~= nil then
			startOff += linePos(ev[3], ev[4], ev[5], s, len)
		else
			startOff += linePos(L.line_u or 0, 0, 0, s, len)
		end
		task.delay(ev[1], function()
			if holder.Parent then
				launchMeteors(L, holder, s, n, holder.CFrame:PointToWorldSpace(startOff), gy)
			end
		end)
	end
end

-- ---------------------------------------------------------------- efectos sobre las rocas del juego (H3)
type RockInfo = { pos: Vector3, gap: number, delay: number }

-- punto del suelo bajo una roca: el Vector3 tal cual, o un rayo hacia abajo desde la Part / el Model
local function groundPoint(item: any, exclude: { Instance }): Vector3
	if typeof(item) == "Vector3" then
		return item
	end
	local center: Vector3, height: number
	if item:IsA("Model") then
		center = (item :: Model):GetPivot().Position
		height = (item :: Model):GetExtentsSize().Y
	else
		center = (item :: BasePart).Position
		height = (item :: BasePart).Size.Y
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(center, Vector3.new(0, -(height + 40), 0), params)
	if hit then
		return hit.Position
	end
	return center - Vector3.new(0, height * 0.5, 0)
end

-- ordena las rocas a lo largo de la línea y da a cada una su separación (gap) y un retraso mínimo
local function rockLayout(spec: Layer, rocks: { any }, s: number): ({ RockInfo }, Vector3)
	local exclude = {}
	for _, r in rocks do
		if typeof(r) == "Instance" then
			table.insert(exclude, r)
		end
	end
	local pts = {}
	for i, r in rocks do
		pts[i] = groundPoint(r, exclude)
	end
	local d = pts[#pts] - pts[1]
	d = Vector3.new(d.X, 0, d.Z)
	local dir = if d.Magnitude > 0.1 then d.Unit else Vector3.new(0, 0, -1)
	local origin = pts[1]
	table.sort(pts, function(a: Vector3, b: Vector3)
		return (a - origin):Dot(dir) < (b - origin):Dot(dir)
	end)
	local cfg = spec.rocks
	local list: { RockInfo } = {}
	for i, p in pts do
		local sum, cnt = 0, 0
		if i > 1 then
			sum += (p - pts[i - 1]):Dot(dir)
			cnt += 1
		end
		if i < #pts then
			sum += (pts[i + 1] - p):Dot(dir)
			cnt += 1
		end
		local gap = if cnt > 0 then sum / cnt else cfg.gap * s
		gap = math.clamp(gap, cfg.gap_min * s, cfg.gap_max * s)
		list[i] = { pos = p, gap = gap, delay = rng:NextNumber(0, cfg.jitter) }
	end
	return list, dir
end

-- posición de una emisión relativa a una roca: du (en separaciones) adelante, lado y alto en studs
local function rockPos(r: RockInfo, dir: Vector3, s: number, du: number, side: number, up: number, off: Vector3?): Vector3
	local right = dir:Cross(Vector3.yAxis)
	local o = off or Vector3.zero
	return r.pos + dir * (du * r.gap - o.Z * s) + right * ((side + o.X) * s) + Vector3.yAxis * ((up + o.Y) * s)
end

-- recorre las emisiones de una capa en cada roca (variante i % n) y en la última (el remate)
local function forRockEvents(L: Layer, R: { RockInfo }, dir: Vector3, s: number, fn: (number, number, Vector3, RockInfo) -> ())
	local vars = L.rock_emit
	if vars and #vars > 0 then
		for i, r in R do
			for _, ev in vars[(i - 1) % #vars + 1] do
				fn(ev[1] + r.delay, ev[2], rockPos(r, dir, s, ev[3], ev[4], ev[5]), r)
			end
		end
	end
	if L.final_emit then
		local r = R[#R]
		for _, ev in L.final_emit do
			fn(ev[1] + r.delay, ev[2], rockPos(r, dir, s, ev[3], ev[4], ev[5]), r)
		end
	end
end

-- fuentes de emisión continua (marcas de fuego) en cada roca y en el remate
local function rockSources(L: Layer, R: { RockInfo }, dir: Vector3, s: number): { { pos: Vector3, delay: number } }
	local off = Vector3.new(L.offset[1], L.offset[2], L.offset[3])
	local out = {}
	local vars = L.rock_stream
	if vars and #vars > 0 then
		for i, r in R do
			for _, src in vars[(i - 1) % #vars + 1] do
				table.insert(out, { pos = rockPos(r, dir, s, src[2], src[3], src[4], off), delay = src[1] + r.delay })
			end
		end
	end
	if L.final_stream then
		local r = R[#R]
		for _, src in L.final_stream do
			table.insert(out, { pos = rockPos(r, dir, s, src[2], src[3], src[4], off), delay = src[1] + r.delay })
		end
	end
	return out
end

-- emisión continua en varias posiciones con UN solo emisor: cada fuente acumula su propio Rate
local function runMultiStream(L: Layer, e: ParticleEmitter, carrier: Instance, holder: BasePart, sources: { { pos: Vector3, delay: number } })
	local tEnd = 0
	for _, w in L.stream do
		tEnd = math.max(tEnd, w[2])
	end
	local last = 0
	for _, src in sources do
		last = math.max(last, src.delay + tEnd)
	end
	local acc = table.create(#sources, 0)
	local t0 = time()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		local t = time() - t0
		if not e.Parent or t > last then
			conn:Disconnect()
			return
		end
		for i, src in sources do
			local lt = t - src.delay
			local rate = 0
			for _, w in L.stream do
				if lt >= w[1] and lt <= w[2] then
					rate += w[3] + (w[4] - w[3]) * (lt - w[1]) / math.max(w[2] - w[1], 1e-3)
				end
			end
			acc[i] += rate * KaijuFireVFX.Quality * dt
			while acc[i] >= 1 do
				acc[i] -= 1
				placeCarrier(carrier, holder, src.pos)
				e:Emit(1)
			end
		end
	end)
end

-- Sacudidas de cámara (solo cliente). Todas se suman en un solo desplazamiento que se deshace al empezar el cuadro
-- siguiente (antes de los scripts de cámara): la cámara nunca se corre, ni con la cámara normal ni con una cámara
-- fija (Scriptable). Cada fuente devuelve su intensidad de ahora, o nil cuando terminó.
type ShakeMixer = { sources: { () -> number? }, offset: CFrame, bound: boolean, seed: number }

-- un solo mezclador para todos los módulos de VFX (Kaiju Zero, Omnívora, Astral Colossus): así los desplazamientos
-- se deshacen en el mismo orden en que se aplican
local function shakeMixer(): ShakeMixer
	local g = shared :: any
	local m = g.KZShakeMixer
	if not m then
		m = { sources = {}, offset = CFrame.identity, bound = false, seed = rng:NextNumber(0, 1000) }
		g.KZShakeMixer = m
	end
	return m
end

local function addShakeSource(fn: () -> number?)
	if not RunService:IsClient() then
		return
	end
	local m = shakeMixer()
	table.insert(m.sources, fn)
	if m.bound then
		return
	end
	m.bound = true
	local t0 = time()
	RunService:BindToRenderStep("KZShakeUndo", Enum.RenderPriority.First.Value, function()
		local cam = workspace.CurrentCamera
		if cam and m.offset ~= CFrame.identity then
			cam.CFrame = cam.CFrame * m.offset:Inverse()
		end
		m.offset = CFrame.identity
		if #m.sources == 0 then
			RunService:UnbindFromRenderStep("KZShakeUndo")
			RunService:UnbindFromRenderStep("KZShakeApply")
			m.bound = false
		end
	end)
	RunService:BindToRenderStep("KZShakeApply", Enum.RenderPriority.Camera.Value + 1, function()
		local a = 0
		local i = 1
		while i <= #m.sources do
			local v = m.sources[i]()
			if v == nil then
				table.remove(m.sources, i)
			else
				a += v
				i += 1
			end
		end
		local cam = workspace.CurrentCamera
		if not cam or a <= 0 then
			return
		end
		local t = time() - t0
		m.offset = CFrame.Angles(math.noise(m.seed, t * 24) * a * 0.03, math.noise(m.seed + 17, t * 24) * a * 0.03,
			math.noise(m.seed + 31, t * 16) * a * 0.015)
		cam.CFrame = cam.CFrame * m.offset
	end)
end

-- Sacudida corta: intensity ~ 0.5 (suave) .. 2 (fuerte)
function KaijuFireVFX.Shake(intensity: number, duration: number?)
	local dur = duration or 0.9
	local t0 = time()
	addShakeSource(function()
		local t = time() - t0
		if t > dur then
			return nil
		end
		return intensity * math.exp(-t / (dur * 0.35))
	end)
end

-- Sacudida continua que crece de i0 a i1 durante `duration` y se detiene al final.
-- power > 1 hace que crezca más hacia el final.
function KaijuFireVFX.ShakeRamp(i0: number, i1: number, duration: number, power: number?)
	local t0 = time()
	local pw = power or 1
	addShakeSource(function()
		local t = time() - t0
		if t > duration then
			return nil
		end
		return i0 + (i1 - i0) * (t / duration) ^ pw
	end)
end

-- luces, sacudida y limpieza (comunes a todos los efectos)
local function finish(spec: Layer, holder: BasePart, s: number, shake: number?, lights: { { pos: Vector3, t: number } })
	if KaijuFireVFX.UseLight and spec.light then
		for _, lt in lights do
			task.delay(lt.t, function()
				if not holder.Parent then
					return
				end
				local a = Instance.new("Attachment")
				a.Name = "Light"
				a.Parent = holder
				a.WorldPosition = lt.pos
				local li = Instance.new("PointLight")
				li.Color = Color3.fromRGB(spec.light.color[1], spec.light.color[2], spec.light.color[3])
				li.Brightness = spec.light.brightness
				li.Range = math.min(spec.light.range * s, 60)
				li.Shadows = false
				li.Parent = a
				TweenService:Create(li, TweenInfo.new(spec.light.time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Brightness = 0 }):Play()
			end)
		end
	end
	if shake and shake > 0 then
		if spec.shake_ramp then
			-- {t0, t1, intensidad inicial, intensidad final, curva}: tiembla sin parar y cada vez más
			local r = spec.shake_ramp
			task.delay(r[1], KaijuFireVFX.ShakeRamp, shake * r[3], shake * r[4], r[2] - r[1], r[5])
		end
		if spec.shakes then
			-- {t, intensidad relativa, duración}
			for _, sk in spec.shakes do
				task.delay(sk[1], KaijuFireVFX.Shake, shake * sk[2], sk[3])
			end
		elseif not spec.shake_ramp then
			KaijuFireVFX.Shake(shake, 0.9)
		end
	end
	-- se destruye cuando ya murió la última partícula (cleanup >= duración)
	Debris:AddItem(holder, spec.cleanup)
end

-- ---------------------------------------------------------------- losas y bloques que saltan del suelo
-- Los usan la Medialuna (las filas a los lados del corte y el cráter) y la Ola de hielo (el campo del triángulo).
-- Cada pieza aparece a su tiempo con el color y el material del suelo (o de hielo), sube con un rebote, se queda y
-- se hunde; con end = "shatter" desaparece de golpe al terminar y revienta en partículas. Se puede cambiar por un
-- modelo de Blender en KaijuFireVFX.Meshes[mesh].
type Slab = { t: number, x: number, z: number, size: Vector3, rot: CFrame, y0: number, drop: number, hold: number,
	rise: number, sink: number, ice: any, shatter: boolean, mesh: string?, L: any, part: BasePart?, base: CFrame?,
	gy: number, gone: boolean, tip: number?, tipPart: BasePart? }

-- la punta de un cristal: un cubo parado sobre un vértice (su diagonal (1, 1, 1) hacia arriba) en la cara de arriba
local TIP_ROT = CFrame.fromAxisAngle(Vector3.new(-1, 0, 1).Unit, math.acos(1 / math.sqrt(3)))

local function easeOutBack(p: number): number
	local q = math.clamp(p, 0, 1) - 1
	return 1 + q * q * (2.6 * q + 1.6)
end

local function bladePart(name: string, holder: BasePart): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = holder
	return p
end

-- una pieza en (x, z) local, inclinada hacia yaw (radianes en el plano X-Z): el borde de adentro asoma y el de afuera
-- queda enterrado. Con "ice" una fracción son de hielo (y pueden tener su tamaño); "big" agranda unas pocas.
local function makeSlab(SL: any, s: number, x: number, z: number, yaw: number, side: number, tS: number): Slab
	local ice = SL.ice ~= nil and rng:NextNumber() < (SL.ice.frac or 1)
	local function P(key: string): any
		return if ice and SL.ice[key] then SL.ice[key] else SL[key]
	end
	local k = if SL.big and rng:NextNumber() < SL.big.frac then SL.big.k else 1
	local w = rng:NextNumber(P("wid")[1], P("wid")[2]) * s * k
	local th = rng:NextNumber(P("thick")[1], P("thick")[2]) * s * k
	local ln = rng:NextNumber(P("len")[1], P("len")[2]) * s * k
	local a = math.rad(rng:NextNumber(P("tilt")[1], P("tilt")[2]))
	x += side * w / 2 * math.cos(a) * math.cos(yaw)
	z += side * w / 2 * math.cos(a) * math.sin(yaw)
	local rot = CFrame.Angles(0, -yaw + math.rad(rng:NextNumber(-SL.yaw, SL.yaw)), 0)
		* CFrame.Angles(math.rad(rng:NextNumber(-SL.pitch, SL.pitch)), 0, 0) * CFrame.Angles(0, 0, -side * a)
	local top = w / 2 * math.sin(a) + th / 2 * math.cos(a)
	local y0 = top * (2 * SL.show - 1)
	return {
		t = tS, x = x, z = z, size = Vector3.new(w, th, ln), rot = rot, y0 = y0, drop = y0 + top + 0.3 * s,
		hold = rng:NextNumber(SL.hold[1], SL.hold[2]), rise = SL.rise, sink = SL.sink,
		ice = if ice then SL.ice else nil, shatter = SL["end"] == "shatter",
		mesh = if ice and SL.ice.mesh then SL.ice.mesh else SL.mesh, L = SL,
		part = nil, base = nil, gy = 0, gone = false,
	}
end

-- anima las piezas en t; onShatter(pieza, posición) revienta las de end = "shatter". Devuelve si queda alguna.
local function stepSlabs(slabs: { Slab }, holder: BasePart, t: number, exclude: { Instance },
	onShatter: ((Slab, Vector3) -> ())?): boolean
	local alive = false
	for _, L in slabs do
		if L.gone then
			continue
		end
		alive = true
		local age = t - L.t
		if age < 0 then
			continue
		end
		if not L.part then
			local wp = holder.CFrame:PointToWorldSpace(Vector3.new(L.x, 0, L.z))
			local col, mat, gy = groundLook(wp, exclude)
			L.gy = gy or holder.Position.Y
			L.base = CFrame.new(wp.X, 0, wp.Z) * holder.CFrame.Rotation * L.rot
			local template = if L.mesh then KaijuFireVFX.Meshes[L.mesh] else nil
			local p: BasePart
			if template and template:IsA("BasePart") then
				p = (template :: BasePart):Clone()
				p.Name = "Slab"
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.Parent = holder
			else
				p = bladePart("Slab", holder)
				if L.ice then
					p.Material = (Enum.Material :: any)[L.ice.material]
					p.Color = Color3.fromRGB(L.ice.color[1], L.ice.color[2], L.ice.color[3])
					p.Transparency = L.ice.transparency
				else
					p.Material = mat
					p.Color = col:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.2))
				end
				if L.tip then
					local tp = bladePart("SlabTip", holder)
					tp.Material = p.Material
					tp.Color = p.Color
					tp.Transparency = p.Transparency
					tp.Size = Vector3.new(L.tip, L.tip, L.tip)
					L.tipPart = tp
				end
			end
			p.Size = L.size
			L.part = p
		end
		local part = L.part :: BasePart
		local y
		if age < L.rise then
			y = L.y0 - L.drop * (1 - easeOutBack(age / L.rise))
		elseif age < L.rise + L.hold then
			y = L.y0
		elseif L.shatter then
			local pos = part.Position
			part:Destroy()
			if L.tipPart then
				L.tipPart:Destroy()
			end
			L.gone = true
			if onShatter then
				onShatter(L, pos)
			end
			continue
		elseif age < L.rise + L.hold + L.sink then
			local p = (age - L.rise - L.hold) / L.sink
			y = L.y0 - L.drop * p * p
		else
			part:Destroy()
			if L.tipPart then
				L.tipPart:Destroy()
			end
			L.gone = true
			continue
		end
		part.CFrame = (L.base :: CFrame) + Vector3.new(0, L.gy + y, 0)
		if L.tipPart then
			L.tipPart.CFrame = part.CFrame * CFrame.new(0, L.size.Y / 2, 0) * TIP_ROT
		end
	end
	return alive
end

-- ---------------------------------------------------------------- lo que viaja con el frente de la ola triangular
-- `count` puntos repartidos a lo ancho del frente; cada capa suelta partículas por tasa (más cuanto más ancho está el
-- frente) en la dirección del abanico, inclinada `pitch` grados hacia arriba. El frente sale rápido y se va frenando
-- (wave = {T0, TW, freno}). Como el humo nace en el frente y se frena, deja detrás una estela espesa.
local function runFront(Fr: any, holder: BasePart, s: number, len: number, tanH: number)
	local items = {}
	for _, E in Fr.emitters do
		for k = 1, Fr.count do
			local a = Instance.new("Attachment")
			a.Name = E.name
			a.Parent = holder
			local pe = configureEmitter(E, s)
			pe.Parent = a
			table.insert(items, { a = a, pe = pe, E = E, sk = -Fr.s_max + 2 * Fr.s_max * (k - 0.5) / Fr.count, on = false })
		end
	end
	local T0, TW, ease = Fr.wave[1], Fr.wave[2], Fr.wave[3] or 1
	local t0 = time()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		local t = time() - t0
		if t < T0 then
			return
		end
		local u = 1 - (1 - math.clamp((t - T0) / TW, 0, 1)) ^ ease
		local on = t <= T0 + TW
		for _, it in items do
			if on then
				local pos = holder.CFrame:PointToWorldSpace(Vector3.new(it.sk * u * len * tanH, it.E.up * s, -u * len))
				local dir = holder.CFrame:VectorToWorldSpace(Vector3.new(it.sk * tanH, 0, -1).Unit)
				it.a.WorldCFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(math.rad(it.E.pitch or 0), 0, 0)
				it.pe.Rate = it.E.rate * KaijuFireVFX.Quality * (0.25 + 0.75 * u)
			end
			if on ~= it.on then
				it.on = on
				it.pe.Enabled = on
			end
		end
		if not on then
			conn:Disconnect()
		end
	end)
end

-- ---------------------------------------------------------------- lo que deja la ola triangular (Ola de hielo)
-- Grupos de bloques y losas repartidos por el triángulo (más donde es más ancho): saltan cuando pasa el frente (que
-- sale rápido y se va frenando: wave = {T0, TW, freno}), se quedan y se hunden; los de hielo revientan al final en
-- sus partículas "shatter".
local function runField(F: any, holder: BasePart, s: number, len: number, tanH: number)
	local slabs: { Slab } = {}
	local shatterFx: { [any]: { { e: ParticleEmitter, c: Instance, n: number } } } = {}
	for _, G in F.groups do
		for _ = 1, math.floor(G.count * KaijuFireVFX.Quality + 0.5) do
			local u = math.sqrt(rng:NextNumber(G.u[1] ^ 2, G.u[2] ^ 2))
			local x = rng:NextNumber(G.s[1], G.s[2]) * u * len * tanH
			local z = -u * len
			local yaw = if G.lean == "radial" then math.atan2(z, x) else rng:NextNumber(0, 2 * math.pi)
			local tS = F.wave[1] + F.wave[2] * (1 - (1 - u) ^ (1 / (F.wave[3] or 1))) + rng:NextNumber(G.delay[1], G.delay[2])
			table.insert(slabs, makeSlab(G, s, x, z, yaw, 1, tS))
		end
		if G.shatter then
			local list = {}
			for _, LL in G.shatter do
				local e, c = buildEmitter(LL, holder, s, Vector3.zero)
				table.insert(list, { e = e, c = c, n = LL.emit[1][2] })
			end
			shatterFx[G] = list
		end
	end
	local exclude = { holder :: Instance }
	local t0 = time()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		local alive = stepSlabs(slabs, holder, time() - t0, exclude, function(L: Slab, pos: Vector3)
			local list = shatterFx[L.L]
			if list then
				for _, fx in list do
					placeCarrier(fx.c, holder, pos)
					fx.e:Emit(quality(fx.n))
				end
			end
		end)
		if not alive then
			conn:Disconnect()
		end
	end)
end

local function play(spec: Layer, cf: CFrame, scale: number?, length: number?, shake: number?, angle: number?,
	groundY: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local len = length or 0
	local tanH = math.tan(math.rad(math.clamp(angle or 60, 5, 170) / 2))
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf, KaijuFireVFX.Parent)
	local floorY: number? = nil
	for _, L in spec.layers do
		if L.at_ground then
			continue -- en el suelo bajo el impacto del rayo (las pone el rayo al pegar)
		elseif L.floor then
			-- en el suelo bajo el efecto: offset horizontal y su Y es la altura sobre el suelo. ring = {n, radio}: n
			-- puntos alrededor, cada uno mirando hacia afuera (inclinado pitch grados hacia arriba)
			local base = holder.CFrame:PointToWorldSpace(Vector3.new(L.offset[1], 0, L.offset[3]) * s)
			if floorY == nil then
				local _, _, gy = groundLook(base, { holder }, 80 * s)
				floorY = gy or (base.Y - 12 * s)
			end
			local center = Vector3.new(base.X, (floorY :: number) + L.offset[2] * s, base.Z)
			if L.decal then
				for _, ev in L.emit do
					task.delay(ev[1], function()
						if holder.Parent then
							playDecalAt(L, holder, s, ev[2], CFrame.new(center))
						end
					end)
				end
				continue
			end
			local e, carrier = buildEmitter(L, holder, s, Vector3.zero, len)
			levelCarrier(carrier, center)
			for _, ev in L.emit do
				local n = quality(ev[2])
				task.delay(ev[1], function()
					if not e.Parent then
						return
					end
					if not L.ring then
						levelCarrier(carrier, center)
						e:Emit(n)
						return
					end
					for i = 1, L.ring[1] do
						local ang = 2 * math.pi * (i - 1) / L.ring[1]
						local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
						local p = center + out * L.ring[2] * s
						local cf = CFrame.lookAt(p, p + out) * CFrame.Angles(math.rad(L.pitch or 0), 0, 0)
						if carrier:IsA("Attachment") then
							(carrier :: Attachment).WorldCFrame = cf
						else
							(carrier :: BasePart).CFrame = cf
						end
						e:Emit(n)
					end
				end)
			end
			if L.stream then
				runStream(L, e)
			end
		elseif L.cone_emit and L.type == "meteor" then
			for _, ev in L.cone_emit do
				local pos, dir = conePoint(holder, ev, s, len, tanH, L.pitch)
				local n = quality(ev[2])
				task.delay(ev[1], function()
					if holder.Parent then
						launchMeteors(L, holder, s, n, pos, holder.Position.Y, CFrame.lookAt(pos, pos + dir))
					end
				end)
			end
		elseif L.cone_emit then
			if L.decal then
				for _, ev in L.cone_emit do
					local pos, dir = conePoint(holder, ev, s, len, tanH)
					task.delay(ev[1], function()
						if holder.Parent then
							playDecalAt(L, holder, s, ev[2], CFrame.lookAt(pos, pos + dir))
						end
					end)
				end
			else
				local e, carrier = buildEmitter(L, holder, s, nil, len)
				for _, ev in L.cone_emit do
					local pos, dir = conePoint(holder, ev, s, len, tanH, L.pitch)
					local n = quality(ev[2])
					task.delay(ev[1], function()
						if e.Parent then
							aimCarrier(carrier, pos, dir)
							e:Emit(n)
						end
					end)
				end
			end
		elseif L.type == "meteor" then
			playMeteors(L, holder, s, len, groundY)
		elseif L.decal then
			for _, ev in L.emit do
				local off = Vector3.new(L.offset[1], L.offset[2], L.offset[3]) * s
				if ev[3] ~= nil then
					off += linePos(ev[3], ev[4], ev[5], s, len)
				end
				task.delay(ev[1], function()
					if holder.Parent then
						playDecalAt(L, holder, s, ev[2], holder.CFrame * CFrame.new(off))
					end
				end)
			end
			for _, ev in L.points or {} do
				task.delay(ev[1], function()
					if holder.Parent then
						playDecalAt(L, holder, s, ev[2], holder.CFrame * CFrame.new(Vector3.new(ev[3], ev[4], ev[5]) * s))
					end
				end)
			end
		else
			local e, carrier = buildEmitter(L, holder, s, nil, len)
			if #L.emit > 0 then
				scheduleBursts(L, e, carrier, holder, s, len)
			end
			for _, ev in L.points or {} do
				-- (t, n, x, y, z): posición local suelta alrededor del centro
				local n = quality(ev[2])
				task.delay(ev[1], function()
					if e.Parent then
						placeCarrier(carrier, holder, holder.CFrame:PointToWorldSpace(Vector3.new(ev[3], ev[4], ev[5]) * s))
						e:Emit(n)
					end
				end)
			end
			if L.stream then
				runStream(L, e)
			end
		end
	end
	local lights: { { pos: Vector3, t: number } } = {}
	if spec.cone then
		-- triángulo: una luz en el choque y otra en medio del triángulo cuando pasa la onda
		table.insert(lights, { pos = holder.CFrame:PointToWorldSpace(Vector3.new(0, 10 * s, 0)), t = 0 })
		table.insert(lights, { pos = holder.CFrame:PointToWorldSpace(Vector3.new(0, 4 * s, -0.5 * len)),
			t = spec.cone.wave[1] + 0.5 * spec.cone.wave[2] })
	else
		-- en los efectos de línea, hasta 3 luces repartidas que se encienden al paso de la pared
		local n = if len > 0 then math.clamp(math.ceil(len / 50), 1, 3) else 1
		for i = 1, n do
			local u = if len > 0 then (i - 0.5) / n else 0
			local lp = if len > 0 then linePos(u, 0, 4, s, len) else Vector3.zero
			local t0 = if spec.light then (spec.light.delay or 0) + (spec.light.sweep or 0) * u else 0
			table.insert(lights, { pos = holder.CFrame:PointToWorldSpace(lp), t = t0 })
		end
	end
	if spec.front then
		runFront(spec.front, holder, s, len, tanH)
	end
	if spec.field then
		runField(spec.field, holder, s, len, tanH)
	end
	finish(spec, holder, s, shake, lights)
	return holder
end

-- efecto sobre las rocas del juego: todas detonan a la vez (con una diferencia mínima)
local function playRocks(spec: Layer, rocks: { any }, scale: number?, shake: number?): Part?
	if #rocks == 0 then
		return nil
	end
	local s = (scale or 1) * (spec.scale_mult or 1)
	local R, dir = rockLayout(spec, rocks, s)
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2),
		CFrame.lookAt(R[1].pos, R[1].pos + dir), KaijuFireVFX.Parent)
	for _, L in spec.layers do
		if L.type == "meteor" then
			forRockEvents(L, R, dir, s, function(t, n, pos, r)
				task.delay(t, function()
					if holder.Parent then
						launchMeteors(L, holder, s, quality(n), pos, r.pos.Y)
					end
				end)
			end)
		elseif L.decal then
			forRockEvents(L, R, dir, s, function(t, n, pos)
				task.delay(t, function()
					if holder.Parent then
						playDecalAt(L, holder, s, n, holder.CFrame.Rotation + pos)
					end
				end)
			end)
		else
			local e, carrier = buildEmitter(L, holder, s)
			if L.stream then
				runMultiStream(L, e, carrier, holder, rockSources(L, R, dir, s))
			else
				forRockEvents(L, R, dir, s, function(t, n, pos)
					task.delay(t, function()
						if e.Parent then
							placeCarrier(carrier, holder, pos)
							e:Emit(quality(n))
						end
					end)
				end)
			end
		end
	end
	-- luces en la primera roca, en la del medio y en la última
	local lights: { { pos: Vector3, t: number } } = {}
	local used = {}
	for _, i in { 1, math.ceil(#R / 2), #R } do
		if not used[i] then
			used[i] = true
			table.insert(lights, { pos = R[i].pos + Vector3.yAxis * 4 * s, t = 0 })
		end
	end
	finish(spec, holder, s, shake, lights)
	return holder
end

-- ---------------------------------------------------------------- efectos en una zona circular (pilar)
type Zone = {
	holder: BasePart, R: number, H: number, s: number, kR: number, kH: number,
	groundY: number, groundColor: Color3, groundMaterial: Enum.Material,
}

-- ---------------------------------------------------------------- rayo (beam) que se puede apuntar
-- El rayo sale de la boca a los `start` s y su punta avanza hasta el largo máximo en `grow` s. Cada cuadro mira
-- hacia donde apunta (el rival o lo que le digas), lanza un Raycast y se corta en la primera superficie que toca:
-- ahí sale el impacto y en el suelo de debajo quedan las marcas. Capas: line_u 0 = la boca, 1 = la punta;
-- impact = solo mientras pega; on_hit = sus ráfagas salen cada vez que empieza a pegar (emit relativo a ese
-- momento); at_ground = en el suelo bajo el impacto; trail = decals que van quedando en el suelo mientras el rayo
-- lo barre. Lo que va después de `stop` se adelanta si se corta antes (Stop).
export type BeamControl = {
	Holder: Part,
	Active: boolean,
	Length: number,
	MaxLength: number,
	HitPosition: Vector3?,
	HitInstance: Instance?,
	AimAt: (BeamControl, target: any) -> (),
	SetDirection: (BeamControl, direction: Vector3) -> (),
	SetOrigin: (BeamControl, origin: any) -> (),
	Stop: (BeamControl) -> (),
}

-- posición de un origen u objetivo: Vector3, CFrame, Attachment, BasePart o Model
local function pointOf(src: any): Vector3?
	if typeof(src) == "Vector3" then
		return src
	elseif typeof(src) == "CFrame" then
		return src.Position
	elseif typeof(src) == "Instance" then
		if src:IsA("Attachment") then
			return src.WorldPosition
		elseif src:IsA("BasePart") then
			return src.Position
		elseif src:IsA("Model") then
			return src:GetPivot().Position
		end
	end
	return nil
end

local function lookCF(A: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(A, A + dir, if math.abs(dir.Y) > 0.999 then Vector3.zAxis else Vector3.yAxis)
end

type BeamItem = { L: Layer, e: ParticleEmitter, c: Instance }
type BeamEvent = { t: number, fn: () -> (), abs: boolean }

local function playBeam(spec: Layer, origin: any, target: any, scale: number?, shake: number?,
	ignore: { Instance }?): BeamControl
	local s = (scale or 1) * (spec.scale_mult or 1)
	local Bm = spec.beam
	local originSrc: any, aimSrc: any, aimDir: Vector3? = origin, target, nil
	local A0 = pointOf(origin) or Vector3.zero
	local T0 = pointOf(target)
	local lastDir = if T0 and (T0 - A0).Magnitude > 1e-3 then (T0 - A0).Unit
		elseif typeof(origin) == "CFrame" then origin.LookVector
		else Vector3.new(0, 0, -1)
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), lookCF(A0, lastDir), KaijuFireVFX.Parent)
	local t0 = time()
	local stopAt: number? = nil
	local len, hitting, wasHitting = 0.05, false, false
	local ground: Vector3? = nil
	local lastHitEnd = -1e9
	local lastTrail, lastTrailPos = -1e9, nil :: Vector3?

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local exclude: { Instance } = table.clone(ignore or {})
	if typeof(target) == "Instance" then
		table.insert(exclude, target)
	end

	local ctl: BeamControl
	ctl = {
		Holder = holder,
		Active = true,
		Length = 0,
		MaxLength = Bm.max_len * s,
		HitPosition = nil,
		HitInstance = nil,
		AimAt = function(_, tg: any)
			aimSrc = tg
			aimDir = nil
		end,
		SetDirection = function(_, d: Vector3)
			if d.Magnitude > 1e-3 then
				aimDir = d.Unit
			end
		end,
		SetOrigin = function(_, o: any)
			originSrc = o
		end,
		Stop = function(_)
			local t = time() - t0
			if not stopAt and t < Bm.stop then
				stopAt = math.max(t, Bm.start)
			end
		end,
	}

	-- tiempos: los que van después de `stop` se corren si el rayo se corta antes
	local events: { BeamEvent } = {}
	local function at(tt: number, fn: () -> (), abs: boolean?)
		table.insert(events, { t = tt, fn = fn, abs = abs == true })
	end
	local function due(ev: BeamEvent): number
		if not ev.abs and ev.t >= Bm.stop then
			return (stopAt or Bm.stop) + (ev.t - Bm.stop)
		end
		return ev.t
	end
	local function cut(): boolean
		return stopAt ~= nil and time() - t0 > (stopAt :: number)
	end
	local function lineOff(L: Layer, u: number?, side: number?, up: number?): Vector3
		return Vector3.new(L.offset[1], L.offset[2], L.offset[3]) * s + linePos(u or L.line_u or 0, side or 0, up or 0, s, len)
	end
	local function groundCF(L: Layer): CFrame
		return CFrame.new((ground :: Vector3) + Vector3.new(0, L.offset[2] * s, 0))
	end

	local lineItems: { BeamItem } = {}
	local groundItems: { BeamItem } = {}
	local onHit: { { L: Layer, e: ParticleEmitter? } } = {}
	local trails: { Layer } = {}
	for _, L in spec.layers do
		if L.type == "meteor" then
			for _, ev in L.emit do
				local n = quality(ev[2])
				at(ev[1], function()
					if L.impact and not hitting then
						return
					end
					local pos = holder.CFrame:PointToWorldSpace(lineOff(L))
					launchMeteors(L, holder, s, n, pos, if ground then ground.Y else -math.huge)
				end)
			end
		elseif L.decal then
			if L.trail then
				table.insert(trails, L)
			elseif L.on_hit then
				table.insert(onHit, { L = L })
			else
				for _, ev in L.emit do
					at(ev[1], function()
						if ground then
							playDecalAt(L, holder, s, ev[2], groundCF(L))
						end
					end)
				end
			end
		else
			local e, carrier
			if L.at_ground then
				e, carrier = buildEmitter(L, holder, s, Vector3.zero, len)
				table.insert(groundItems, { L = L, e = e, c = carrier })
			else
				e, carrier = buildEmitter(L, holder, s, lineOff(L), len)
				if (L.line_u or 0) ~= 0 or L.speed_len or not carrier:IsA("Attachment") then
					table.insert(lineItems, { L = L, e = e, c = carrier })
				end
			end
			if L.on_hit then
				table.insert(onHit, { L = L, e = e })
			else
				for _, ev in L.emit do
					local n = quality(ev[2])
					at(ev[1], function()
						if not e.Parent or (L.impact and not hitting) or (L.at_ground and not ground) then
							return
						end
						if ev[3] ~= nil then
							placeCarrier(carrier, holder, holder.CFrame:PointToWorldSpace(lineOff(L, ev[3], ev[4], ev[5])))
						end
						e:Emit(n)
					end)
				end
			end
			if L.stream then
				runStream(L, e, nil, nil, nil, function()
					if cut() or (L.impact and not hitting) or (L.at_ground and not (hitting and ground)) then
						return 0
					end
					return 1
				end)
			end
		end
	end

	-- el cuerpo del rayo: Beams de la boca a la punta
	local a0 = Instance.new("Attachment")
	a0.Name = "BeamStart"
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Name = "BeamEnd"
	a1.Parent = holder
	local beams: { { B: Layer, b: Beam, seed: number } } = {}
	for _, B in spec.beams do
		local b = Instance.new("Beam")
		b.Name = B.name
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Texture = KaijuFireVFX.TEXTURES[B.texture] or ""
		b.TextureMode = (Enum.TextureMode :: any)[B.mode]
		b.TextureLength = B.tex_len * s
		b.TextureSpeed = B.speed
		b.LightEmission = B.light_emission
		b.LightInfluence = 0
		b.Brightness = B.brightness
		b.Color = colorSeq(B.color)
		b.FaceCamera = true
		b.Segments = 10 -- la cinta se gira hacia la cámara a lo largo de todo el rayo
		b.ZOffset = B.zoffset * s
		b.Width0 = 0
		b.Width1 = 0
		b.Transparency = NumberSequence.new(1)
		b.Parent = holder
		table.insert(beams, { B = B, b = b, seed = rng:NextNumber(0, 100) })
	end

	-- luces: una en la boca y otra en el impacto (solo mientras pega), que parpadean
	local lights: { { li: PointLight, a: Attachment, impact: boolean } } = {}
	if KaijuFireVFX.UseLight then
		for i = 1, 2 do
			local la = Instance.new("Attachment")
			la.Name = "Light"
			la.Parent = holder
			local li = Instance.new("PointLight")
			li.Color = Color3.fromRGB(Bm.light_color[1], Bm.light_color[2], Bm.light_color[3])
			li.Brightness = 0
			li.Range = math.min(Bm.light_range * s, 60)
			li.Shadows = false
			li.Parent = la
			table.insert(lights, { li = li, a = la, impact = i == 2 })
		end
	end

	-- sacudida: golpes en sus tiempos y un temblor continuo que se corta con el rayo
	if shake and shake > 0 and RunService:IsClient() then
		for _, sk in spec.shakes or {} do
			at(sk[1], function()
				KaijuFireVFX.Shake(shake * sk[2], sk[3])
			end)
		end
		local r = spec.shake_ramp
		if r then
			addShakeSource(function()
				local tt = time() - t0
				if tt > math.min(r[2], stopAt or r[2]) or not holder.Parent then
					return nil
				end
				if tt < r[1] then
					return 0
				end
				return shake * (r[3] + (r[4] - r[3]) * ((tt - r[1]) / (r[2] - r[1])) ^ r[5])
			end)
		end
	end

	local after = spec.cleanup - Bm.stop -- cuánto vive lo último después del corte
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = time() - t0
		local te = if stopAt and t > stopAt then Bm.stop + (t - stopAt) else t -- tiempo de las curvas del rayo
		if not holder.Parent or t > (stopAt or Bm.stop) + after then
			conn:Disconnect()
			if holder.Parent then
				holder:Destroy()
			end
			ctl.Active, ctl.Length, ctl.HitPosition, ctl.HitInstance = false, 0, nil, nil
			return
		end
		-- de dónde sale y hacia dónde apunta
		local A = pointOf(originSrc) or holder.Position
		local dir = aimDir
		if not dir then
			local T = pointOf(aimSrc)
			dir = if T and (T - A).Magnitude > 1e-3 then (T - A).Unit else lastDir
		end
		lastDir = dir :: Vector3
		-- hasta dónde llega: la punta crece al disparar y se corta en la primera superficie
		local maxLen = ctl.MaxLength
		local head = math.clamp((t - Bm.start) / math.max(Bm.grow, 1e-3), 0, 1) * maxLen
		local hit = workspace:Raycast(A, lastDir * maxLen, params)
		local rayLen = if hit then (hit.Position - A).Magnitude else maxLen
		len = math.max(math.min(rayLen, head), 0.05)
		hitting = hit ~= nil and head >= rayLen and te < Bm.stop
		holder.CFrame = lookCF(A, lastDir)
		local P = A + lastDir * len
		ground = nil
		if hitting then
			local _, _, gy = groundLook(P - lastDir * 2 * s, exclude, 200)
			ground = if gy then Vector3.new(P.X, gy, P.Z) else nil
		end
		-- cada vez que empieza a pegar: destello, onda, marcas grandes en el suelo
		if hitting and not wasHitting and t - lastHitEnd >= Bm.rehit then
			for _, h in onHit do
				for _, ev in h.L.emit do
					local n = if h.e then quality(ev[2]) else ev[2]
					at(t + ev[1], function()
						if h.e then
							if h.e.Parent and (not h.L.at_ground or ground) then
								h.e:Emit(n)
							end
						elseif ground then
							playDecalAt(h.L, holder, s, n, groundCF(h.L))
						end
					end, true)
				end
			end
		end
		if wasHitting and not hitting then
			lastHitEnd = t
		end
		wasHitting = hitting
		-- lo que va a lo largo del rayo y en la punta sigue su largo
		for _, it in lineItems do
			local L = it.L
			local off = lineOff(L)
			if it.c:IsA("Attachment") then
				(it.c :: Attachment).Position = off
			else
				local part = it.c :: BasePart
				if L.shape and L.shape.len_k then
					part.Size = Vector3.new(part.Size.X, part.Size.Y, math.min(len * L.shape.len_k, 2048))
				end
				part.CFrame = holder.CFrame * CFrame.new(off)
			end
			if L.speed_len then
				it.e.Speed = NumberRange.new(L.speed_len[1] * len, L.speed_len[2] * len)
			end
		end
		if ground then
			for _, it in groundItems do
				levelCarrier(it.c, (ground :: Vector3) + Vector3.new(0, it.L.offset[2] * s, 0))
			end
			-- marcas que van quedando en el suelo mientras el rayo lo barre
			if t - lastTrail >= Bm.trail_every
				and (not lastTrailPos or (ground - (lastTrailPos :: Vector3)).Magnitude >= Bm.trail_move * s) then
				lastTrail, lastTrailPos = t, ground
				for _, L in trails do
					playDecalAt(L, holder, s, 1, groundCF(L))
				end
			end
		end
		-- ráfagas y golpes en su tiempo
		local i = 1
		while i <= #events do
			local ev = events[i]
			if t >= due(ev) then
				table.remove(events, i)
				ev.fn()
			else
				i += 1
			end
		end
		-- el cuerpo del rayo: largo, ancho que late, se desvanece al final; sin superficie, la punta se esfuma
		a1.Position = Vector3.new(0, 0, -len)
		for _, it in beams do
			local B = it.B
			local pulse = math.clamp(2 * math.noise(it.seed, t * B.pulse_hz), -1, 1)
			local w = B.width * s * evalNum(B.width_t, te) * (1 + B.pulse * pulse)
			it.b.Width0 = w * B.w0
			it.b.Width1 = w * B.w1
			local fade = evalNum(B.alpha_t, te)
			local kps = {}
			for _, kp in B.transparency do
				if hitting or kp[1] < 0.8 then
					table.insert(kps, NumberSequenceKeypoint.new(kp[1], math.clamp(kp[2] + (1 - kp[2]) * fade, 0, 1)))
				end
			end
			if not hitting then
				local v = evalNum(B.transparency, 0.8)
				table.insert(kps, NumberSequenceKeypoint.new(0.8, math.clamp(v + (1 - v) * fade, 0, 1)))
				table.insert(kps, NumberSequenceKeypoint.new(1, 1))
			end
			it.b.Transparency = NumberSequence.new(kps)
			it.b.Enabled = te < Bm.stop + Bm.fade
		end
		local on = math.clamp((t - Bm.start) / 0.05, 0, 1) * math.clamp(1 - (te - Bm.stop) / Bm.fade, 0, 1)
		for k, Lt in lights do
			if Lt.impact then
				Lt.a.Position = Vector3.new(0, 0, -math.max(len - 4 * s, 0))
			end
			local lit = if Lt.impact and not hitting then 0 else on
			Lt.li.Brightness = Bm.light_brightness * lit * (1 + 0.25 * math.noise(k * 7.3, t * 12))
		end
		-- lo que el juego puede leer
		ctl.Active = te < Bm.stop + Bm.fade
		ctl.Length = len
		ctl.HitPosition = if hitting then P else nil
		ctl.HitInstance = if hitting and hit then hit.Instance else nil
	end)
	return ctl
end

-- ---------------------------------------------------------------- golpe que recibe el rival
-- el efecto mira a la cámara (X = derecha de la pantalla, Y = arriba, +Z = hacia la cámara) y sale delante de la
-- superficie del rival que se ve; con un Model o una Part su tamaño se adapta al alto del rival
local function playHit(spec: Layer, target: any, scale: number?, shake: number?, angle: number?): Part
	local H = spec.hit
	local C: Vector3
	local inst: Instance? = nil
	local height: number? = nil
	if typeof(target) == "Vector3" then
		C = target
	elseif typeof(target) == "CFrame" then
		C = target.Position
	elseif typeof(target) == "Instance" and target:IsA("Model") then
		C = (target :: Model):GetPivot().Position
		height = (target :: Model):GetExtentsSize().Y
		inst = target
	else
		C = (target :: BasePart).Position
		height = (target :: BasePart).Size.Y
		inst = target
	end
	local k = if height and (KaijuFireVFX :: any).HitAutoSize then math.clamp(height / H.ref, 0.5, 4) else 1
	local sc = (scale or 1) * k
	local s = sc * (spec.scale_mult or 1)
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else C + Vector3.new(0, 0, 60)
	local toCam = camPos - C
	if toCam.Magnitude < 1e-3 then
		toCam = Vector3.zAxis
	end
	local P = C
	if inst then
		-- la superficie del rival que ve la cámara
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { inst :: Instance }
		local hit = workspace:Raycast(camPos, C - camPos, params)
		if hit then
			P = hit.Position
		end
	end
	P += toCam.Unit * H.lift * s
	local cf = CFrame.lookAt(P, P - toCam.Unit) * CFrame.Angles(0, 0, math.rad(angle or H.angle))
	return play(spec, cf, sc, nil, shake)
end

-- escala de tamaños de una capa: con el radio ("r"), con la altura del pilar ("h") o con la escala
local function zoneK(L: Layer, Z: Zone): number
	if L.rel == "r" then
		return Z.kR
	elseif L.rel == "h" then
		return Z.kH
	end
	return Z.s
end

local function zoneY(L: Layer, Z: Zone, h: number): number
	if L.hu == "H" then
		return h * Z.H
	elseif L.hu == "s" then
		return h * Z.s
	end
	return h * zoneK(L, Z)
end

-- capas que cubren la superficie del pilar: más partículas si el pilar es más alto/ancho que su tamaño
local function coverMul(L: Layer, Z: Zone): number
	if not L.cover then
		return 1
	end
	local k = zoneK(L, Z)
	return math.clamp(Z.kR * Z.kH / (k * k), 0.5, 2.5)
end

-- marco local (respecto al centro) de un punto del círculo: a = fracción de vuelta, r = fracción del radio.
-- El "Front" del portador mira hacia afuera, inclinado pitch grados hacia arriba.
local function zoneLocal(Z: Zone, a: number, r: number, y: number, pitch: number?, radial: boolean?): CFrame
	local ang = a * 2 * math.pi
	local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
	local pos = out * (r * Z.R) + Vector3.new(0, y, 0)
	if radial == false then
		return CFrame.new(pos)
	end
	local cf = CFrame.lookAt(pos, pos + out)
	if pitch and pitch ~= 0 then
		cf = cf * CFrame.Angles(math.rad(pitch), 0, 0)
	end
	return cf
end

-- punto al azar de la zona según L.zdist = {r = {r0, r1}, h = {h0, h1}, area}
local function zoneRandom(L: Layer, Z: Zone): CFrame
	local d = L.zdist
	local r = if d.area then math.sqrt(rng:NextNumber(d.r[1] ^ 2, d.r[2] ^ 2)) else rng:NextNumber(d.r[1], d.r[2])
	return zoneLocal(Z, rng:NextNumber(), r, zoneY(L, Z, rng:NextNumber(d.h[1], d.h[2])), L.pitch, L.radial)
end

-- emisor de una capa de zona, en su propio Attachment (que se coloca con .CFrame respecto al centro)
local function zoneEmitter(L: Layer, Z: Zone, parent: Instance): (ParticleEmitter, Attachment)
	local a = Instance.new("Attachment")
	a.Name = L.name
	a.Parent = parent
	local e = configureEmitter(L, zoneK(L, Z))
	if L.speed_h then
		e.Speed = NumberRange.new(L.speed_h[1] * Z.H, L.speed_h[2] * Z.H)
	elseif L.speed_r then
		e.Speed = NumberRange.new(L.speed_r[1] * Z.R, L.speed_r[2] * Z.R)
	end
	if L.ground_mix then -- del color del suelo (las esquirlas más pequeñas)
		local kps = table.create(#L.color)
		for i, p in L.color do
			local c = Color3.fromRGB(p[2][1], p[2][2], p[2][3])
			kps[i] = ColorSequenceKeypoint.new(p[1], c:Lerp(Z.groundColor, L.ground_mix))
		end
		e.Color = ColorSequence.new(kps)
	end
	if L.lit then
		e.LightInfluence = 1
	end
	if L.spin then
		e.LockedToPart = true -- las partículas giran con la pieza: suben en espiral
	end
	e.Parent = a
	return e, a
end

-- emisión continua en puntos al azar de la zona: el portador se mueve antes de cada Emit
local function runZoneStream(L: Layer, Z: Zone, e: ParticleEmitter, a: Attachment, mul: number)
	local W = L.zstream
	local tEnd = 0
	for _, w in W do
		tEnd = math.max(tEnd, w[2])
	end
	local acc = 0
	local t0 = time()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		local t = time() - t0
		if not e.Parent or t > tEnd then
			conn:Disconnect()
			return
		end
		local rate = 0
		for _, w in W do
			if t >= w[1] and t <= w[2] then
				rate += w[3] + (w[4] - w[3]) * (t - w[1]) / math.max(w[2] - w[1], 1e-3)
			end
		end
		acc += rate * mul * KaijuFireVFX.Quality * dt
		while acc >= 1 do
			acc -= 1
			a.CFrame = zoneRandom(L, Z)
			e:Emit(1)
		end
	end)
end

-- pieza invisible que gira sobre el eje del pilar (una por velocidad de giro)
local function zoneSpinner(Z: Zone, spinners: { [number]: BasePart }, deg: number): BasePart
	local found = spinners[deg]
	if found then
		return found
	end
	local part = invisiblePart("Spin", Vector3.new(0.2, 0.2, 0.2), Z.holder.CFrame, Z.holder)
	spinners[deg] = part
	local base = Z.holder.CFrame
	local t0 = time()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not part.Parent then
			conn:Disconnect()
			return
		end
		part.CFrame = base * CFrame.Angles(0, math.rad(deg) * (time() - t0), 0)
	end)
	return part
end

-- borra de golpe las partículas que quedan (tapado por un destello)
local function clearAt(e: ParticleEmitter, t: number)
	task.delay(t, function()
		if e.Parent then
			e:Clear()
		end
	end)
end

-- desvanece las partículas que quedan (cambiar la curva del emisor afecta también a las ya emitidas)
local function fadeOut(e: ParticleEmitter, t0: number, dur: number)
	task.delay(t0, function()
		if not e.Parent then
			return
		end
		local base = e.Transparency.Keypoints
		local start = time()
		local conn: RBXScriptConnection
		conn = RunService.Heartbeat:Connect(function()
			if not e.Parent then
				conn:Disconnect()
				return
			end
			local u = math.clamp((time() - start) / dur, 0, 1)
			local kps = table.create(#base)
			for i, k in base do
				kps[i] = NumberSequenceKeypoint.new(k.Time, k.Value + (1 - k.Value) * u)
			end
			e.Transparency = NumberSequence.new(kps)
			if u >= 1 then
				conn:Disconnect()
				e:Clear()
			end
		end)
	end)
end

-- luces de la zona: suben en rise, se mantienen hold y se apagan en fall
local function zoneLights(spec: Layer, Z: Zone)
	if not KaijuFireVFX.UseLight or not spec.lights then
		return
	end
	for _, Lt in spec.lights do
		task.delay(Lt.t, function()
			if not Z.holder.Parent then
				return
			end
			-- una en el eje o, con ring = {cuántas, fracción del radio}, un anillo (una PointLight no pasa de 60 studs)
			local y = if Lt.hu == "H" then Lt.h * Z.H else Lt.h * Z.s
			local spots = { Vector3.new(0, y, 0) }
			if Lt.ring then
				spots = {}
				for i = 1, Lt.ring[1] do
					local ang = 2 * math.pi * (i - 1) / Lt.ring[1]
					table.insert(spots, Vector3.new(math.cos(ang) * Lt.ring[2] * Z.R, y, math.sin(ang) * Lt.ring[2] * Z.R))
				end
			end
			for _, pos in spots do
				local a = Instance.new("Attachment")
				a.Name = "Light"
				a.Parent = Z.holder
				a.Position = pos
				local li = Instance.new("PointLight")
				li.Color = Color3.fromRGB(Lt.color[1], Lt.color[2], Lt.color[3])
				li.Brightness = 0
				li.Range = math.min(Lt.range * Z.s, 60)
				li.Shadows = false
				li.Parent = a
				TweenService:Create(li, TweenInfo.new(math.max(Lt.rise, 0.01), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Brightness = Lt.brightness }):Play()
				task.delay(Lt.rise + Lt.hold, function()
					if li.Parent then
						TweenService:Create(li, TweenInfo.new(Lt.fall, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Brightness = 0 }):Play()
					end
				end)
			end
		end)
	end
end

-- ---------------------------------------------------------------- cubos de destrucción (estilo Roblox)
-- tamaño al azar con muchos pequeños y pocos grandes
local function skewed(lo: number, hi: number, skew: number): number
	return lo + (hi - lo) * rng:NextNumber() ^ skew
end

-- la misma orientación, girada lo mínimo para que una cara quede apoyada en el suelo
local function flatRot(rot: CFrame): CFrame
	local best, by = rot.RightVector, rot.RightVector.Y
	for _, v in { rot.UpVector, -rot.LookVector } do
		if math.abs(v.Y) > math.abs(by) then
			best, by = v, v.Y
		end
	end
	local up = if by < 0 then -best else best
	local axis = up:Cross(Vector3.yAxis)
	if axis.Magnitude < 1e-4 then
		return rot
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(up.Y, -1, 1))) * rot
end

-- distancia del centro del cubo a su punto más bajo
local function lowOffset(rot: CFrame, size: number): number
	return size * 0.5 * (math.abs(rot.RightVector.Y) + math.abs(rot.UpVector.Y) + math.abs(rot.LookVector.Y))
end

-- Parts anclados que se mueven por código (no empujan a nadie): saltan, rebotan, se apoyan y se
-- desvanecen; algunos se desintegran en el aire y otros los traga el pilar en espiral
local function playCubes(spec: Layer, Z: Zone)
	local C = spec.cubes
	local holder = Z.holder
	local s = Z.s
	local g = C.gravity * s
	local center = holder.Position
	local base = holder.CFrame
	local gy = Z.groundY
	local hardEnd = spec.cleanup - C.fade - 0.05
	local opts = KaijuFireVFX :: any
	local color: Color3 = opts.CubeColor or Z.groundColor
	local material: Enum.Material = opts.CubeMaterial or Z.groundMaterial
	local fxE: ParticleEmitter?, fxA: Attachment?
	if C.fx then
		fxE, fxA = zoneEmitter(C.fx, Z, holder)
	end
	local list: { Layer } = {}
	for _, G in C.groups do
		for _ = 1, quality(G.count) do
			local ang = rng:NextNumber(0, 2 * math.pi)
			local f = rng:NextNumber(C.color_var[1], C.color_var[2]) * (if rng:NextNumber() < C.dark then 0.6 else 1)
			local nc = C.neon_colors[rng:NextInteger(1, #C.neon_colors)]
			table.insert(list, {
				G = G, state = "wait", t0 = rng:NextNumber(G.t[1], G.t[2]), size = skewed(G.size[1], G.size[2], G.skew) * s,
				ang = ang, out = base:VectorToWorldSpace(Vector3.new(math.cos(ang), 0, -math.sin(ang))),
				r = math.sqrt(rng:NextNumber(G.r[1] ^ 2, G.r[2] ^ 2)) * Z.R, pos = center, vel = Vector3.zero,
				k = 1, bounces = 0, seed = rng:NextNumber(0, 100),
				rot = CFrame.Angles(rng:NextNumber(0, 6.283), rng:NextNumber(0, 6.283), rng:NextNumber(0, 6.283)),
				axis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1) + 0.01).Unit,
				spin = math.rad(rng:NextNumber(C.spin[1], C.spin[2])),
				neon = rng:NextNumber() < (G.neon or 0), dissolve = rng:NextNumber() < (G.dissolve or 0),
				color = Color3.new(math.min(color.R * f, 1), math.min(color.G * f, 1), math.min(color.B * f, 1)),
				neonColor = Color3.fromRGB(nc[1], nc[2], nc[3]),
			})
		end
	end
	local function spawnPart(c: Layer)
		local p = Instance.new("Part")
		p.Name = "Cube"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = c.size > 1.2 * s
		p.Size = Vector3.new(c.size, c.size, c.size)
		if c.neon then
			p.Material = Enum.Material.Neon
			p.Color = c.neonColor
		else
			p.Material = material
			p.Color = c.color
		end
		p.CFrame = CFrame.new(c.pos) * c.rot
		p.Parent = holder
		c.part = p
	end
	local function launch(c: Layer, t: number)
		local G = c.G
		local tang = Vector3.new(-c.out.Z, 0, c.out.X)
		c.vel = c.out * rng:NextNumber(G.out[1], G.out[2]) * s + Vector3.new(0, rng:NextNumber(G.up[1], G.up[2]) * s, 0)
			+ tang * rng:NextNumber(-6, 6) * s
		c.state = "fly"
		if c.dissolve then
			c.dissolveAt = t + rng:NextNumber(C.dissolve_time[1], C.dissolve_time[2])
		end
	end
	local function startDissolve(c: Layer, t: number)
		if c.d0 then
			return
		end
		c.d0 = t
		c.dur = rng:NextNumber(C.shrink[1], C.shrink[2])
		c.part.Material = Enum.Material.Neon
		c.part.Color = c.neonColor
		c.part.CastShadow = false
		if fxE and fxA then
			fxA.WorldPosition = c.pos
			fxE:Emit(quality(C.fx.emit_n or 2))
		end
	end
	local t0 = time()
	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(rawDt)
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		local dt = math.min(rawDt, 1 / 20)
		local t = time() - t0
		table.clear(parts)
		table.clear(cfs)
		local alive = 0
		for _, c in list do
			if c.state == "dead" then
				continue
			end
			alive += 1
			if c.state == "wait" then
				if t < c.t0 then
					continue
				end
				local G = c.G
				local cx, cz = center.X + c.out.X * c.r, center.Z + c.out.Z * c.r
				if G.mode == "lift" then
					c.state = "rise"
					c.y0 = gy - c.size * 0.5
					c.y1 = gy + c.size * 0.5 + rng:NextNumber(G.lift[1], G.lift[2]) * s
					c.trel = rng:NextNumber(G.release[1], G.release[2])
					c.pos = Vector3.new(cx, c.y0, cz)
				elseif G.mode == "blast" then
					c.pos = Vector3.new(cx, gy + c.size * 0.5, cz)
					launch(c, t)
				else
					c.state = "orbit"
					c.r0 = c.r
					c.y = gy + c.size * 0.5
					c.orbit = rng:NextNumber(G.orbit[1], G.orbit[2])
					c.rise = rng:NextNumber(G.rise[1], G.rise[2]) * Z.H
					c.top = gy + rng:NextNumber(G.top[1], G.top[2]) * Z.H
					c.pos = Vector3.new(cx, c.y, cz)
				end
				spawnPart(c)
			end
			local st = c.state
			local moving = st ~= "rest" and st ~= "fade"
			if c.d0 then
				c.k = 1 - (t - c.d0) / c.dur
				if c.k <= 0 then
					c.state = "dead"
					c.part:Destroy()
					continue
				end
				local sz = c.size * c.k
				c.part.Size = Vector3.new(sz, sz, sz)
			end
			if st == "rise" then
				local u = math.clamp((t - c.t0) / math.max(c.trel - c.t0, 1e-3), 0, 1)
				local e = 1 - (1 - u) ^ 3
				local jit = Vector3.new(math.noise(c.seed, t * 6) * 0.25, math.noise(c.seed + 7, t * 6) * 0.16,
					math.noise(c.seed + 13, t * 6) * 0.25) * s * u
				c.pos = Vector3.new(center.X + c.out.X * c.r, c.y0 + (c.y1 - c.y0) * e, center.Z + c.out.Z * c.r) + jit
				c.rot = CFrame.fromAxisAngle(c.axis, c.spin * 0.15 * dt) * c.rot
				if t >= c.trel then
					launch(c, t)
				end
			elseif st == "fly" then
				c.vel += Vector3.new(0, -g * (if c.d0 then 0.35 else 1) * dt, 0)
				c.pos += c.vel * dt
				c.rot = CFrame.fromAxisAngle(c.axis, c.spin * dt) * c.rot
				if c.dissolve and not c.d0 and t >= c.dissolveAt then
					startDissolve(c, t)
				end
				local low = c.pos.Y - lowOffset(c.rot, c.size * c.k)
				if low <= gy and c.vel.Y < 0 and not c.d0 then
					c.pos += Vector3.new(0, gy - low, 0)
					c.vel = Vector3.new(c.vel.X * C.friction, -c.vel.Y * C.bounce, c.vel.Z * C.friction)
					c.spin *= 0.55
					c.bounces += 1
					if math.abs(c.vel.Y) < 7 * s or c.bounces >= 3 then
						c.state = "settle"
						c.ts = t
						c.rot0 = c.rot
						c.rot1 = flatRot(c.rot)
						c.vel = Vector3.zero
					end
				end
			elseif st == "settle" then
				local u = math.min(1, (t - c.ts) / C.settle)
				c.rot = c.rot0:Lerp(c.rot1, u)
				c.pos = Vector3.new(c.pos.X, gy + lowOffset(c.rot, c.size), c.pos.Z)
				if u >= 1 then
					c.state = "rest"
					c.restEnd = math.min(t + rng:NextNumber(C.rest[1], C.rest[2]), hardEnd)
				end
			elseif st == "rest" then
				if t >= c.restEnd then
					c.state = "fade"
					c.tf = t
				end
			elseif st == "fade" then
				local a = (t - c.tf) / C.fade
				if a >= 1 then
					c.state = "dead"
					c.part:Destroy()
					continue
				end
				c.part.Transparency = a
			elseif st == "orbit" then
				c.ang += c.orbit * dt
				c.y += c.rise * dt
				local prog = math.clamp((c.y - gy) / math.max(c.top - gy, 1e-3), 0, 1)
				local r = c.r0 * (1 - 0.35 * prog)
				local dir = base:VectorToWorldSpace(Vector3.new(math.cos(c.ang), 0, -math.sin(c.ang)))
				c.pos = Vector3.new(center.X + dir.X * r, c.y, center.Z + dir.Z * r)
				c.rot = CFrame.fromAxisAngle(c.axis, c.spin * dt) * c.rot
				if c.y >= c.top then
					startDissolve(c, t)
				end
				if t >= c.G.release and not c.d0 then
					-- el pilar se apagó: el cubo sale despedido y se deshace
					local tang = base:VectorToWorldSpace(Vector3.new(-math.sin(c.ang), 0, -math.cos(c.ang)))
					c.vel = tang * c.orbit * r + Vector3.new(0, rng:NextNumber(4, 12) * s, 0)
					c.state = "fly"
					c.dissolve = true
					c.dissolveAt = t + rng:NextNumber(0.15, 0.45)
				end
			end
			if moving then
				table.insert(parts, c.part)
				table.insert(cfs, CFrame.new(c.pos) * c.rot)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
		if alive == 0 then
			conn:Disconnect()
		end
	end)
end

-- ---------------------------------------------------------------- piezas gigantes de la zona (sin el tope de 100 studs)
-- Capas bill: una BillboardGui con una ImageLabel por partícula (la luna del cielo, los destellos gigantes). Siguen el
-- tamaño, la transparencia, el color y el giro de la capa durante su vida; slide = corrimiento en pantalla (studs),
-- flip_t = cuadro del flipbook según la vida y speed/speed_h con direction Top/Bottom = se mueve en vertical. Una
-- ImageLabel no tiene LightEmission: Brightness (con LightInfluence 0) la hace brillar.
local FLIP_CELLS = { Grid2x2 = 2, Grid4x4 = 4, Grid8x8 = 8 } :: { [string]: number }

local function playBill(L: Layer, Z: Zone, k: number, n: number, lcf: CFrame)
	for _ = 1, n do
		local life = rng:NextNumber(L.lifetime[1], L.lifetime[2])
		local a = Instance.new("Attachment")
		a.Name = L.name
		a.CFrame = lcf
		a.Parent = Z.holder
		local g = Instance.new("BillboardGui")
		g.Name = L.name
		g.Adornee = a
		g.LightInfluence = 0
		g.Brightness = L.brightness
		g.AlwaysOnTop = false
		g.MaxDistance = math.huge
		g.ClipsDescendants = false
		g.Size = UDim2.fromScale(0, 0)
		g.Parent = a
		local im = Instance.new("ImageLabel")
		im.BackgroundTransparency = 1
		im.Size = UDim2.fromScale(1, 1)
		im.Image = KaijuFireVFX.TEXTURES[L.texture] or ""
		im.ImageTransparency = 1
		im.Parent = g
		local cells = if L.flipbook then FLIP_CELLS[L.flipbook.layout] or 1 else 1
		local cell = (L.tex_px or 1024) / cells
		if cells > 1 then
			im.ImageRectSize = Vector2.new(cell, cell)
		end
		local rot = rng:NextNumber(L.rotation[1], L.rotation[2])
		local spin = rng:NextNumber(L.rot_speed[1], L.rot_speed[2])
		local sp = if L.speed_h then rng:NextNumber(L.speed_h[1], L.speed_h[2]) * Z.H
			else rng:NextNumber(L.speed[1], L.speed[2]) * k
		local vy = if L.direction == "Bottom" then -sp elseif L.direction == "Top" then sp else 0
		local t0 = time()
		local conn: RBXScriptConnection
		conn = RunService.Heartbeat:Connect(function()
			local age = time() - t0
			local u = age / life
			if u >= 1 or not a.Parent then
				conn:Disconnect()
				a:Destroy()
				return
			end
			local sz = math.max(evalNum(L.size, u) * k, 0.01)
			g.Size = UDim2.fromScale(sz, sz)
			local sx, sy = 0, 0
			if L.slide_x then
				sx, sy = evalNum(L.slide_x, u) * k, evalNum(L.slide_y, u) * k
			end
			g.StudsOffset = Vector3.new(sx, sy, L.zoffset * k)
			im.ImageTransparency = math.clamp(evalNum(L.transparency, u), 0, 1)
			im.ImageColor3 = evalColor(L.color, u)
			im.Rotation = rot + spin * age
			if vy ~= 0 then
				a.CFrame = lcf + Vector3.new(0, vy * age, 0)
			end
			if cells > 1 then
				local f = if L.flip_t then evalNum(L.flip_t, u) else u * cells * cells
				f = math.clamp(math.floor(f + 0.5), 0, cells * cells - 1)
				im.ImageRectOffset = Vector2.new((f % cells) * cell, math.floor(f / cells) * cell)
			end
		end)
	end
end

-- Columnas de luz (zbeams): Beams que miran a la cámara, de arriba (Attachment0, la luna) al suelo. Bajan en
-- drop = {t0, duración}; count cintas en un anillo de r × radio que gira spin grados/s; rim = dos cintas finas en el
-- contorno de la columna visto desde la cámara (el delineado). width × radio y tex_len × altura; width_t y alpha_t
-- en el tiempo; r_t encoge el anillo (al colapsar); near aclara las cintas cuando la cámara está dentro de la columna.
type ZBeamItem = { B: Layer, beams: { Beam }, a0: { Attachment }, a1: { Attachment }, tr: { number }, seed: number }

local function runZoneBeams(spec: Layer, Z: Zone)
	local holder = Z.holder
	local items: { ZBeamItem } = {}
	local tEnd = 0
	for _, B in spec.zbeams do
		local n = if B.rim then 2 else B.count
		local it: ZBeamItem = { B = B, beams = {}, a0 = {}, a1 = {}, tr = {}, seed = rng:NextNumber(0, 100) }
		for i = 1, n do
			local a0 = Instance.new("Attachment")
			a0.Name = B.name
			a0.Parent = holder
			local a1 = Instance.new("Attachment")
			a1.Name = B.name
			a1.Parent = holder
			local b = Instance.new("Beam")
			b.Name = B.name
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Texture = KaijuFireVFX.TEXTURES[B.texture] or ""
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = math.max(B.tex_len * Z.H, 0.1)
			b.TextureSpeed = B.speed
			b.LightEmission = B.light_emission
			b.LightInfluence = 0
			b.Brightness = B.brightness
			b.Color = colorSeq(B.color)
			b.FaceCamera = true
			b.Segments = 1
			b.ZOffset = B.zoffset * Z.kR
			b.Width0 = 0
			b.Width1 = 0
			b.Transparency = NumberSequence.new(1)
			b.Enabled = false
			b.Parent = holder
			it.beams[i], it.a0[i], it.a1[i], it.tr[i] = b, a0, a1, 2
		end
		table.insert(items, it)
		tEnd = math.max(tEnd, B.width_t[#B.width_t][1], B.alpha_t[#B.alpha_t][1])
	end
	local t0 = time()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = time() - t0
		if not holder.Parent or t > tEnd then
			conn:Disconnect()
			for _, it in items do
				for i, b in it.beams do
					b:Destroy()
					it.a0[i]:Destroy()
					it.a1[i]:Destroy()
				end
			end
			return
		end
		local cam = workspace.CurrentCamera
		local camRel = if cam then holder.CFrame:PointToObjectSpace(cam.CFrame.Position) else Vector3.new(0, 0, 1e6)
		for _, it in items do
			local B = it.B
			local wk = evalNum(B.width_t, t)
			local fade = evalNum(B.alpha_t, t)
			if t < B.drop[1] or wk <= 1e-3 or fade >= 0.999 then
				for _, b in it.beams do
					b.Enabled = false
				end
				continue
			end
			local top = B.h[2] * Z.H
			local u = math.min((t - B.drop[1]) / math.max(B.drop[2], 1e-3), 1)
			local bot = top + (B.h[1] * Z.H - top) * u
			local rr = B.r * Z.R * (if B.r_t then evalNum(B.r_t, t) else 1)
			local xs, zs = table.create(#it.beams, 0), table.create(#it.beams, 0)
			if B.rim then
				local d = math.sqrt(camRel.X * camRel.X + camRel.Z * camRel.Z)
				if d <= rr * 1.02 then -- la cámara está dentro: no hay contorno
					for _, b in it.beams do
						b.Enabled = false
					end
					continue
				end
				local ux, uz = camRel.X / d, camRel.Z / d
				local c = rr / d
				local sn = math.sqrt(math.max(1 - c * c, 0))
				xs[1], zs[1] = rr * (c * ux - sn * uz), rr * (c * uz + sn * ux)
				xs[2], zs[2] = rr * (c * ux + sn * uz), rr * (c * uz - sn * ux)
			else
				for i = 1, #it.beams do
					local ang = 2 * math.pi * (B.a0 + (i - 1) / #it.beams) + math.rad(B.spin) * (t - B.drop[1])
					xs[i], zs[i] = math.cos(ang) * rr, math.sin(ang) * rr
				end
			end
			for i, b in it.beams do
				local x, z = xs[i], zs[i]
				it.a0[i].Position = Vector3.new(x, top, z)
				it.a1[i].Position = Vector3.new(x, bot, z)
				local w = B.width * Z.R * wk * (1 + B.wobble * math.noise(it.seed + i * 3.3, t * 2.3))
				b.Width0 = w
				b.Width1 = w
				local f = fade
				if B.near > 0 then
					local dd = math.sqrt((camRel.X - x) ^ 2 + (camRel.Z - z) ^ 2)
					local close = 1 - math.clamp((dd - 0.5 * w) / math.max(w, 1e-3), 0, 1)
					f = 1 - (1 - f) * (1 - B.near * close)
				end
				if f >= 0.999 then
					b.Enabled = false
					continue
				end
				b.Enabled = true
				if math.abs(it.tr[i] - f) > 0.01 then
					it.tr[i] = f
					local kps = table.create(#B.transparency)
					for j, p in B.transparency do
						kps[j] = NumberSequenceKeypoint.new(p[1], 1 - (1 - p[2]) * (1 - f))
					end
					b.Transparency = NumberSequence.new(kps)
				end
			end
		end
	end)
end

-- Cristales y losas que brotan en una zona circular (zfield): cada grupo reparte count piezas entre r = {r0, r1}
-- (fracción del radio; ring = parejas alrededor del anillo); brotan cuando la onda del centro llega a su radio
-- (t + sweep·r) y se inclinan hacia afuera (lean = "radial"); con end_at todas terminan a la vez (las de hielo
-- revientan). tip = punta de cristal. Los tamaños siguen al radio de la zona.
local function runZoneField(F: any, Z: Zone)
	local holder = Z.holder
	local k = Z.kR
	local slabs: { Slab } = {}
	local shatterFx: { [any]: { { e: ParticleEmitter, c: Instance, n: number } } } = {}
	for _, G in F.groups do
		local n = math.floor(G.count * KaijuFireVFX.Quality + 0.5)
		for i = 1, n do
			local ang: number, r: number
			if G.ring then
				ang = 2 * math.pi * (i - 1 + rng:NextNumber(-0.35, 0.35)) / n
				r = rng:NextNumber(G.r[1], G.r[2])
			else
				ang = rng:NextNumber(0, 2 * math.pi)
				r = math.sqrt(rng:NextNumber(G.r[1] ^ 2, G.r[2] ^ 2))
			end
			local x, z = math.cos(ang) * r * Z.R, math.sin(ang) * r * Z.R
			local yaw = if G.lean == "radial" then ang else rng:NextNumber(0, 2 * math.pi)
			local tS = G.t + (G.sweep or 0) * r + rng:NextNumber(G.delay[1], G.delay[2])
			local S = makeSlab(G, k, x, z, yaw, 1, tS)
			if G.end_at then
				S.hold = math.max(0.05, rng:NextNumber(G.end_at[1], G.end_at[2]) - tS - S.rise)
			end
			if G.tip then
				S.tip = G.tip * math.min(S.size.X, S.size.Z)
			end
			table.insert(slabs, S)
		end
		if G.shatter then
			local list = {}
			for _, LL in G.shatter do
				local e, c = buildEmitter(LL, holder, k, Vector3.zero)
				table.insert(list, { e = e, c = c, n = LL.emit[1][2] })
			end
			shatterFx[G] = list
		end
	end
	local exclude = { holder :: Instance }
	local t0 = time()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		local alive = stepSlabs(slabs, holder, time() - t0, exclude, function(L: Slab, pos: Vector3)
			local list = shatterFx[L.L]
			if list then
				for _, fx in list do
					placeCarrier(fx.c, holder, pos)
					fx.e:Emit(quality(fx.n))
				end
			end
		end)
		if not alive then
			conn:Disconnect()
		end
	end)
end

-- arranca las capas de una zona circular (+ cubos de destrucción y luces); snap = hasta cuántos studs
-- se baja o se sube el centro para apoyarlo en el suelo
local function startZone(spec: Layer, cf: CFrame, s: number, R: number, H: number, snap: number): (Part, Zone)
	-- la zona queda plana (solo se usa el giro horizontal de cf) y apoyada en el suelo
	local pos = cf.Position
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local flat = if look.Magnitude > 1e-3 then CFrame.lookAt(pos, pos + look) else CFrame.new(pos)
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), flat, KaijuFireVFX.Parent)
	local gColor, gMaterial, gy = groundLook(pos, { holder })
	if gy and math.abs(gy - pos.Y) < snap then
		holder.CFrame = flat + Vector3.new(0, gy - pos.Y, 0)
	end
	local Z: Zone = {
		holder = holder, R = R, H = H, s = s, kR = R / spec.zone.radius, kH = H / spec.zone.height,
		groundY = holder.Position.Y, groundColor = gColor, groundMaterial = gMaterial,
	}
	local spinners: { [number]: BasePart } = {}
	for _, L in spec.layers do
		if L.orb then
			continue -- van pegadas al proyectil (runOrb)
		elseif L.bill then
			local k = zoneK(L, Z)
			for _, ev in L.ring_emit or {} do
				local lcf = zoneLocal(Z, ev[3], ev[4], zoneY(L, Z, ev[5]), nil, false)
				task.delay(ev[1], function()
					if holder.Parent then
						playBill(L, Z, k, ev[2], lcf)
					end
				end)
			end
		elseif L.decal then
			local k = zoneK(L, Z)
			for _, ev in L.ring_emit or {} do
				local lcf = zoneLocal(Z, ev[3], ev[4], zoneY(L, Z, ev[5]), nil, false)
				task.delay(ev[1], function()
					if holder.Parent then
						playDecalAt(L, holder, k, ev[2], holder.CFrame * lcf)
					end
				end)
			end
		elseif L.zstream and L.spin then
			-- ranuras fijas en la pieza que gira, cada una con su parte de la tasa
			local spinner = zoneSpinner(Z, spinners, L.spin)
			local slots = L.slots or 8
			for _ = 1, slots do
				local e, a = zoneEmitter(L, Z, spinner)
				a.CFrame = zoneRandom(L, Z)
				runStream(L, e, nil, L.zstream, coverMul(L, Z) / slots)
				if L.clear_at then
					clearAt(e, L.clear_at)
				end
				if L.fade_at then
					fadeOut(e, L.fade_at[1], L.fade_at[2])
				end
			end
		else
			local e, a = zoneEmitter(L, Z, holder)
			for _, ev in L.ring_emit or {} do
				local lcf = zoneLocal(Z, ev[3], ev[4], zoneY(L, Z, ev[5]), L.pitch, L.radial)
				local n = quality(ev[2])
				task.delay(ev[1], function()
					if e.Parent then
						a.CFrame = lcf
						e:Emit(n)
					end
				end)
			end
			if L.zstream then
				runZoneStream(L, Z, e, a, coverMul(L, Z))
			end
			if L.clear_at then
				clearAt(e, L.clear_at)
			end
			if L.fade_at then
				fadeOut(e, L.fade_at[1], L.fade_at[2])
			end
		end
	end
	if spec.cubes then
		playCubes(spec, Z)
	end
	if spec.zbeams then
		runZoneBeams(spec, Z)
	end
	if spec.zfield then
		runZoneField(spec.zfield, Z)
	end
	zoneLights(spec, Z)
	return holder, Z
end

-- Corrección de color y destellos de pantalla de una zona (solo en el cliente y cerca de la zona): con screen.cc =
-- {t, brillo, contraste, saturación, tinte R, G, B} el mundo se oscurece (p. ej. mientras la luna se eclipsa) y con
-- screen.flash = {t, alfa, subida, bajada} la pantalla destella. Se nota entero dentro de la zona y se apaga a
-- screen.range × radio. KaijuFireVFX.ScreenFX = false lo desactiva.
local function runScreen(spec: Layer, Z: Zone)
	local Sc = spec.screen
	if not (KaijuFireVFX :: any).ScreenFX or not RunService:IsClient() then
		return
	end
	local holder = Z.holder
	local cc: ColorCorrectionEffect? = nil
	local gui: ScreenGui? = nil
	local frame: Frame? = nil
	pcall(function()
		local e = Instance.new("ColorCorrectionEffect")
		e.Name = "KZ_" .. spec.name
		e.Parent = game:GetService("Lighting")
		cc = e
	end)
	pcall(function()
		local lp = game:GetService("Players").LocalPlayer
		local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
		if not pg then
			return
		end
		local g = Instance.new("ScreenGui")
		g.Name = "KZ_" .. spec.name .. "Flash"
		g.IgnoreGuiInset = true
		g.ResetOnSpawn = false
		g.DisplayOrder = 1000
		local fr = Instance.new("Frame")
		fr.Size = UDim2.fromScale(1, 1)
		fr.BackgroundColor3 = Color3.fromRGB(Sc.flash_color[1], Sc.flash_color[2], Sc.flash_color[3])
		fr.BorderSizePixel = 0
		fr.BackgroundTransparency = 1
		fr.Parent = g
		g.Parent = pg
		gui = g
		frame = fr
	end)
	local tEnd = Sc.cc[#Sc.cc][1]
	for _, f in Sc.flash do
		tEnd = math.max(tEnd, f[1] + f[3] + f[4])
	end
	local t0 = time()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = time() - t0
		if not holder.Parent or t > tEnd then
			conn:Disconnect()
			if cc then
				cc:Destroy()
			end
			if gui then
				gui:Destroy()
			end
			return
		end
		local k = 1
		local cam = workspace.CurrentCamera
		if cam then
			local rel = holder.CFrame:PointToObjectSpace(cam.CFrame.Position)
			local d = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
			k = math.clamp(1 - (d - Z.R) / math.max((Sc.range - 1) * Z.R, 1), 0, 1)
		end
		if cc then
			local rows = Sc.cc
			local a, b = rows[1], rows[#rows]
			for i = 1, #rows - 1 do
				if t <= rows[i + 1][1] then
					a, b = rows[i], rows[i + 1]
					break
				end
			end
			local u = math.clamp((t - a[1]) / math.max(b[1] - a[1], 1e-3), 0, 1)
			local function v(j: number): number
				return a[j] + (b[j] - a[j]) * u
			end
			cc.Brightness = v(2) * k
			cc.Contrast = v(3) * k
			cc.Saturation = v(4) * k
			cc.TintColor = Color3.new(1 - (1 - v(5) / 255) * k, 1 - (1 - v(6) / 255) * k, 1 - (1 - v(7) / 255) * k)
		end
		if frame then
			local al = 0
			for _, f in Sc.flash do
				local tt = t - f[1]
				if tt >= 0 then
					local w = if tt < f[3] then tt / f[3] else 1 - math.clamp((tt - f[3]) / f[4], 0, 1)
					al = math.max(al, w * f[2])
				end
			end
			frame.BackgroundTransparency = 1 - al * k
		end
	end)
end

-- efecto en una zona circular: carga, erupción, pilar y colapso (+ cubos de destrucción)
local function playZone(spec: Layer, cf: CFrame, scale: number?, radius: number?, height: number?, shake: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local holder, Z = startZone(spec, cf, s, radius or spec.zone.radius * s, height or spec.zone.height * s, 8)
	if spec.screen then
		runScreen(spec, Z)
	end
	finish(spec, holder, s, shake, {})
	return holder
end

-- ---------------------------------------------------------------- proyectil que crece (agujero negro)
-- posición y radio del proyectil en el segundo t: se forma en A, viaja a B creciendo y colapsa en B
local function orbAt(O: Layer, t: number, A: Vector3, B: Vector3, s: number): (Vector3, number)
	local S = O.size
	if t < O.travel[1] then
		local u = math.clamp((t - O.form[1]) / math.max(O.form[2] - O.form[1], 1e-3), 0, 1)
		return A, S[2] * (1 - (1 - u) ^ 2) * s
	elseif t < O.travel[2] then
		local u = (t - O.travel[1]) / math.max(O.travel[2] - O.travel[1], 1e-3)
		local e = u * u * (3 - 2 * u)
		return A:Lerp(B, e) + Vector3.new(0, O.arc * s * math.sin(math.pi * u), 0), (S[2] + (S[3] - S[2]) * u ^ 0.9) * s
	elseif t < O.collapse[1] then
		return B, S[3] * s
	end
	local u = math.clamp((t - O.collapse[1]) / math.max(O.collapse[2] - O.collapse[1], 1e-3), 0, 1)
	return B, (S[3] + (S[4] - S[3]) * u * u) * s
end

-- orientación del proyectil: mira hacia donde va y su "Top" (el eje del disco) se inclina tilt grados
-- hacia la cámara, para que el disco se vea abierto desde donde se mire
local function orbFrame(O: Layer, A: Vector3, B: Vector3): CFrame
	local dir = Vector3.new(B.X - A.X, 0, B.Z - A.Z)
	dir = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.new(0, 0, -1)
	local up = Vector3.yAxis
	local cam = workspace.CurrentCamera
	if cam then
		local side = cam.CFrame.Position - (A + B) * 0.5
		side = Vector3.new(side.X, 0, side.Z)
		if side.Magnitude > 1e-3 then
			up = (Vector3.yAxis * math.cos(math.rad(O.tilt)) + side.Unit * math.sin(math.rad(O.tilt))).Unit
		end
	end
	local look = dir - up * dir:Dot(up)
	if look.Magnitude < 1e-3 then
		return CFrame.lookAt(Vector3.zero, dir)
	end
	return CFrame.lookAt(Vector3.zero, look.Unit, up)
end

-- capas pegadas al proyectil (orb = "sprite", "shell", "trail", "ground" o "burst"):
--   sprite/burst: en su centro; shell: salen de una esfera de radio shell × r y caen hacia el centro;
--   trail: estela que se queda atrás; ground: en el suelo, debajo del proyectil.
--   grow: los tamaños van en radios del proyectil (crecen con él); locked: LockedToPart.
local function runOrb(spec: Layer, Z: Zone, A: Vector3, B: Vector3)
	local O = spec.orb
	local s = Z.s
	local holder = Z.holder
	local rot = orbFrame(O, A, B)
	local carrier = invisiblePart("Orb", Vector3.new(0.2, 0.2, 0.2), CFrame.new(A) * rot, holder)
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = carrier
	local ground = Instance.new("Attachment")
	ground.Name = "OrbGround"
	ground.Parent = holder
	ground.WorldPosition = Vector3.new(A.X, Z.groundY, A.Z)
	local items: { { L: Layer, e: ParticleEmitter, shell: BasePart? } } = {}
	for _, L in spec.layers do
		if not L.orb then
			continue
		end
		local e = configureEmitter(L, s)
		local shell: BasePart? = nil
		if L.shell or L.shell_abs then
			local d = if L.shell_abs then 2 * L.shell_abs * s else 0.2
			local part = invisiblePart(L.name .. "_Shell", Vector3.new(d, d, d), CFrame.new(A), holder)
			part.Shape = Enum.PartType.Ball
			e.Shape = Enum.ParticleEmitterShape.Sphere
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
			e.LockedToPart = true
			e.Parent = part
			shell = part
		elseif L.orb == "ground" then
			e.Parent = ground
		else
			e.LockedToPart = L.locked == true
			e.Parent = center
		end
		for _, ev in L.emit do
			local n = quality(ev[2])
			task.delay(ev[1], function()
				if e.Parent then
					e:Emit(n)
				end
			end)
		end
		if L.stream then
			runStream(L, e)
		end
		if L.clear_at then
			clearAt(e, L.clear_at)
		end
		table.insert(items, { L = L, e = e, shell = shell })
	end
	-- lente de vidrio detrás del agujero (del lado contrario a la cámara): dobla la luz del fondo. Roblox
	-- solo dibuja la refracción con gráficos altos, y a través del vidrio no se ven partículas: por eso va
	-- detrás y las partículas del agujero quedan por delante
	local lens: Part? = nil
	if (KaijuFireVFX :: any).Lens and O.lens then
		local lp = invisiblePart("Lens", Vector3.new(0.2, 0.2, 0.2), CFrame.new(A), holder)
		lp.Shape = Enum.PartType.Ball
		lp.Material = Enum.Material.Glass
		lp.Color = Color3.fromRGB(O.lens_color[1], O.lens_color[2], O.lens_color[3])
		lens = lp
	end
	local t0 = time()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		local t = time() - t0
		local pos, r = orbAt(O, t, A, B, s)
		local done = t >= O.collapse[2]
		local rr = math.max(r, 0.02 * s)
		carrier.CFrame = CFrame.new(pos) * rot
		ground.WorldPosition = Vector3.new(pos.X, Z.groundY, pos.Z)
		for _, it in items do
			local L = it.L
			if L.grow then
				it.e.Size = numberSeq(L.size, rr)
			end
			local sh = it.shell
			if sh then
				sh.CFrame = CFrame.new(pos)
				if L.shell then
					local d = 2 * L.shell * rr
					sh.Size = Vector3.new(d, d, d)
					it.e.Speed = NumberRange.new(L.speed[1] * rr, L.speed[2] * rr)
				end
			end
		end
		if lens then
			local cam = workspace.CurrentCamera
			if done or r < 0.1 * s or not cam then
				lens.Transparency = 1
			else
				local lr = O.lens * r
				lens.Size = Vector3.new(2 * lr, 2 * lr, 2 * lr)
				lens.CFrame = CFrame.new(pos + (pos - cam.CFrame.Position).Unit * lr * 1.05)
				lens.Transparency = O.lens_transparency
			end
		end
		if done then
			conn:Disconnect()
			for _, it in items do
				it.e.Enabled = false
			end
			if lens then
				lens:Destroy()
			end
		end
	end)
end

-- proyectil (agujero negro) desde la boca hasta los enemigos, y la detonación en la zona que los cubre
local function playOrb(spec: Layer, mouth: any, targets: any, scale: number?, shake: number?, radius: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local O = spec.orb
	local A: Vector3 = if typeof(mouth) == "CFrame" then mouth.Position else mouth
	local list = if typeof(targets) == "table" then targets else { targets }
	local pts: { Vector3 } = {}
	for _, it in list do
		if typeof(it) == "Vector3" then
			table.insert(pts, it)
		elseif typeof(it) == "CFrame" then
			table.insert(pts, it.Position)
		elseif typeof(it) == "Instance" then
			if it:IsA("Model") then
				table.insert(pts, (it :: Model):GetPivot().Position)
			elseif it:IsA("BasePart") then
				table.insert(pts, (it :: BasePart).Position)
			end
		end
	end
	local c: Vector3
	if #pts > 0 then
		c = Vector3.zero
		for _, p in pts do
			c += p
		end
		c /= #pts
	else -- sin enemigos: hacia adelante de la boca
		local fwd = if typeof(mouth) == "CFrame" then mouth.LookVector else Vector3.new(0, 0, -1)
		fwd = Vector3.new(fwd.X, 0, fwd.Z)
		fwd = if fwd.Magnitude > 1e-3 then fwd.Unit else Vector3.new(0, 0, -1)
		c = A + fwd * O.reach * s
	end
	-- la detonación cubre a todos los enemigos: radio hasta el más lejano del centro + margen
	local far = 0
	for _, p in pts do
		far = math.max(far, Vector3.new(p.X - c.X, 0, p.Z - c.Z).Magnitude)
	end
	local R = radius or math.max(O.min_radius * s, far + O.margin * s)
	local look = Vector3.new(c.X - A.X, 0, c.Z - A.Z)
	local cf = if look.Magnitude > 1e-3 then CFrame.lookAt(c, c + look) else CFrame.new(c)
	local holder, Z = startZone(spec, cf, s, R, spec.zone.height * s, 60)
	runOrb(spec, Z, A, Vector3.new(c.X, Z.groundY + O.height * s, c.Z))
	finish(spec, holder, s, shake, {})
	return holder
end

-- ---------------------------------------------------------------- aura que se adapta al modelo
-- Envuelve cualquier Model (o una Part): un Highlight delinea todo el cuerpo y respira; capas `aura`:
-- "surface" = un emisor en cada parte del cuerpo (la tasa se reparte según su área: brota de toda la silueta),
-- "body" = un emisor en una caja invisible del tamaño del modelo que lo sigue, "feet" = en el suelo bajo sus pies.
-- Los tamaños de la spec son para un modelo de `ref` studs de alto: crecen con el alto real del modelo. Cada
-- `surge` s hay una oleada (capas con `surge` = partículas de golpe y el delineado se enciende).
export type AuraControl = {
	Holder: Part,
	Model: Instance,
	Active: boolean,
	Intensity: number,
	SetIntensity: (AuraControl, intensity: number) -> (),
	Stop: (AuraControl, fade: number?) -> (),
}

type AuraItem = { L: Layer, e: ParticleEmitter, share: number, carrier: Part? }

local function auraBox(model: Instance): (CFrame, Vector3)
	if model:IsA("Model") then
		return (model :: Model):GetBoundingBox()
	elseif model:IsA("BasePart") then
		return (model :: BasePart).CFrame, (model :: BasePart).Size
	end
	return CFrame.new(), Vector3.one
end

local function auraParts(model: Instance, maxParts: number): ({ BasePart }, { number })
	local list: { BasePart } = {}
	local function consider(p: Instance)
		if p:IsA("BasePart") and p.Transparency < 0.95 and p.Name ~= "HumanoidRootPart" then
			table.insert(list, p)
		end
	end
	consider(model)
	for _, d in model:GetDescendants() do
		consider(d)
	end
	local function area(p: BasePart): number
		local s = p.Size
		return 2 * (s.X * s.Y + s.Y * s.Z + s.Z * s.X)
	end
	-- solo las más grandes (las piezas diminutas casi no aportan y cuestan un emisor cada una)
	table.sort(list, function(a, b)
		return area(a) > area(b)
	end)
	while #list > maxParts do
		table.remove(list)
	end
	local total = 0
	for _, p in list do
		total += area(p)
	end
	local shares: { number } = {}
	for i, p in list do
		shares[i] = area(p) / math.max(total, 1e-3)
	end
	return list, shares
end

local function playAura(spec: Layer, model: Instance, scale: number?, duration: number?, intensity: number?): AuraControl
	local Au = spec.aura
	local cf0, size0 = auraBox(model)
	local k = (scale or 1) * math.clamp(size0.Y / Au.ref, 0.25, 8)
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf0, KaijuFireVFX.Parent)
	local t0 = time()
	local items: { AuraItem } = {}
	local bodyCarriers: { { c: Part, L: Layer } } = {}
	local feetCarriers: { { c: Part, L: Layer } } = {}
	local parts, shares = auraParts(model, Au.max_parts)

	for _, L in spec.layers do
		if L.aura == "surface" then
			for i, p in parts do
				local e = configureEmitter(L, k)
				e.Shape = Enum.ParticleEmitterShape.Box
				e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
				e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
				e.Name = "KZAura_" .. L.name
				e.Parent = p
				table.insert(items, { L = L, e = e, share = shares[i] })
			end
		else
			local c = invisiblePart(L.name .. "_Shape", Vector3.one, cf0, holder)
			local e = configureEmitter(L, k)
			if L.aura == "feet" then
				e.Shape = Enum.ParticleEmitterShape.Disc
				e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
				table.insert(feetCarriers, { c = c, L = L })
			else
				e.Shape = Enum.ParticleEmitterShape.Box
				e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
				table.insert(bodyCarriers, { c = c, L = L })
			end
			e.Parent = c
			table.insert(items, { L = L, e = e, share = 1, carrier = c })
		end
	end

	-- el delineado: un Highlight sobre todo el modelo
	local hl = Instance.new("Highlight")
	hl.Name = "KZAuraOutline"
	hl.Adornee = model
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.FillColor = Color3.fromRGB(Au.fill[1], Au.fill[2], Au.fill[3])
	hl.FillTransparency = 1
	hl.OutlineTransparency = 1
	hl.Parent = holder

	local light: PointLight? = nil
	if KaijuFireVFX.UseLight then
		local li = Instance.new("PointLight")
		li.Color = Color3.fromRGB(Au.light_color[1], Au.light_color[2], Au.light_color[3])
		li.Range = math.min(Au.light_range * k, 60)
		li.Brightness = 0
		li.Shadows = false
		li.Parent = holder
		light = li
	end

	local c1 = Color3.fromRGB(Au.outline[1][1], Au.outline[1][2], Au.outline[1][3])
	local c2 = Color3.fromRGB(Au.outline[2][1], Au.outline[2][2], Au.outline[2][3])
	local stopAt: number? = if duration then duration else nil
	local fadeOut = Au.fade_out
	local lastSurge = 0
	local groundY: number? = nil
	local nextGround = 0
	local ctl: AuraControl
	ctl = {
		Holder = holder,
		Model = model,
		Active = true,
		Intensity = intensity or 1,
		SetIntensity = function(self, v: number)
			self.Intensity = math.max(v, 0)
		end,
		Stop = function(_, fade: number?)
			local t = time() - t0
			if not stopAt or (stopAt :: number) > t then
				stopAt = t
				fadeOut = fade or Au.fade_out
			end
		end,
	}

	local function destroyAll()
		for _, it in items do
			if it.e.Parent then
				it.e:Destroy()
			end
		end
		if holder.Parent then
			holder:Destroy()
		end
		ctl.Active = false
	end

	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = time() - t0
		if not model.Parent or not holder.Parent then
			conn:Disconnect()
			destroyAll()
			return
		end
		-- cuánto está encendida: sube al empezar y baja al cortarla
		local on = math.clamp(t / math.max(Au.fade_in, 1e-3), 0, 1)
		if stopAt then
			local u = (t - (stopAt :: number)) / math.max(fadeOut, 1e-3)
			on = math.min(on, math.clamp(1 - u, 0, 1))
			if u >= 1 then
				for _, it in items do
					it.e.Enabled = false
				end
				hl.OutlineTransparency, hl.FillTransparency = 1, 1
				if light then
					light.Brightness = 0
				end
				ctl.Active = false
				if t > (stopAt :: number) + fadeOut + Au.life_max then
					conn:Disconnect()
					destroyAll()
				end
				return
			end
		end
		local k2 = on * ctl.Intensity
		-- seguir al modelo: caja del cuerpo y suelo bajo los pies
		local cf, size = auraBox(model)
		holder.CFrame = cf
		if t >= nextGround then
			nextGround = t + 0.25
			local _, _, gy = groundLook(cf.Position, { model, holder }, size.Y * 0.5 + 12)
			groundY = gy
		end
		local bottom = cf.Position.Y - size.Y * 0.5
		local nearGround = groundY ~= nil and bottom - (groundY :: number) < size.Y * 0.4
		for _, bc in bodyCarriers do
			local f = bc.L.box or { 1, 1, 1 }
			bc.c.Size = Vector3.new(size.X * f[1], size.Y * f[2], size.Z * f[3])
			bc.c.CFrame = cf
		end
		for _, fc in feetCarriers do
			local w = math.max(size.X, size.Z) * (fc.L.radius_k or 0.6)
			local y = if groundY then groundY :: number else bottom
			fc.c.Size = Vector3.new(w, 0.2, w)
			fc.c.CFrame = CFrame.new(cf.Position.X, y + (fc.L.offset[2] or 0) * k, cf.Position.Z)
		end
		-- tasas
		for _, it in items do
			local L = it.L
			local gate = if L.aura == "feet" and not nearGround then 0 else 1
			local rate = (L.rate or 0) * it.share * k2 * gate * KaijuFireVFX.Quality
			it.e.Rate = rate
			it.e.Enabled = rate > 0.01
		end
		-- oleadas
		local surgeK = 0
		if Au.surge and Au.surge > 0 then
			if t - lastSurge >= Au.surge and on > 0.5 then
				lastSurge = t
				for _, it in items do
					local n = (it.L.surge or 0) * it.share * ctl.Intensity * KaijuFireVFX.Quality
					local whole = math.floor(n)
					if rng:NextNumber() < n - whole then
						whole += 1
					end
					if whole > 0 and (it.L.aura ~= "feet" or nearGround) then
						it.e:Emit(whole)
					end
				end
			end
			surgeK = math.exp(-(t - lastSurge) / 0.25)
		end
		-- el delineado respira entre sus dos colores y se enciende en cada oleada
		local w = 0.5 + 0.5 * math.sin(t * math.pi * 2 * Au.pulse_hz)
		hl.OutlineColor = c1:Lerp(c2, math.clamp(w * 0.7 + surgeK * 0.6, 0, 1))
		local ot = Au.outline_t[1] + (Au.outline_t[2] - Au.outline_t[1]) * (1 - w)
		hl.OutlineTransparency = 1 - (1 - ot * (1 - surgeK)) * math.min(k2, 1)
		local ft = Au.fill_t[1] + (Au.fill_t[2] - Au.fill_t[1]) * (1 - w)
		hl.FillTransparency = math.clamp(1 - (1 - ft) * math.min(k2, 1) * (1 + surgeK * 0.6), 0, 1)
		if light then
			light.Brightness = Au.light_brightness * k2 * (0.75 + 0.25 * w + surgeK * 0.8)
		end
	end)
	return ctl
end

-- ---------------------------------------------------------------- aura de contorno (el delineado ES el aura)
-- Cada cliente busca el contorno del modelo visto desde SU cámara: lanza rayos (Raycast solo contra el modelo) en una
-- rejilla que cubre el modelo en pantalla; los nodos que tocan el modelo y tienen al lado (arriba, abajo, izquierda o
-- derecha) uno que no lo toca son el contorno. De ahí salen las capas sil = "edge" (hacia afuera en el plano de la
-- pantalla, mezclado con hacia arriba por up y separado del borde por push; side = "up" solo arriba y a los lados,
-- "down" solo abajo); sil = "body" sale de los puntos de adentro (el hielo que se desprende) y sil = "feet" alrededor
-- de los pies. Lo que queda detrás del cuerpo no se ve, así que el aura sale del borde; si la cámara cambia de lado,
-- el aura cambia de lugar: unas manos delante del pecho no tienen aura y las mismas manos vistas de lado sí.
-- Los puntos se guardan respecto a la parte que tocaron, así que siguen al modelo aunque se mueva entre una búsqueda y
-- otra. rate = partículas por segundo en total; burst = al encender; end_burst = al apagar.
type SilPoint = { part: BasePart, lp: Vector3, out: Vector3 }
type SilItem = { L: Layer, e: ParticleEmitter, a: Attachment, acc: number }

local function silhouette(parts: { BasePart }, cam: Camera, S: Layer, params: RaycastParams, q: number):
	({ SilPoint }, { SilPoint })
	-- el recuadro en pantalla de las partes visibles (las esquinas de cada una)
	local vp = cam.ViewportSize
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	local center, span = Vector3.zero, 0
	for _, p in parts do
		local cf, half = p.CFrame, p.Size / 2
		center += cf.Position
		span = math.max(span, p.Size.Magnitude)
		for i = 0, 7 do
			local c = cf:PointToWorldSpace(Vector3.new(if i % 2 == 0 then -half.X else half.X,
				if math.floor(i / 2) % 2 == 0 then -half.Y else half.Y, if i >= 4 then half.Z else -half.Z))
			local sp = cam:WorldToViewportPoint(c)
			if sp.Z <= 0 then
				return {}, {} -- la cámara está dentro o detrás: no hay contorno
			end
			x0, y0, x1, y1 = math.min(x0, sp.X), math.min(y0, sp.Y), math.max(x1, sp.X), math.max(y1, sp.Y)
		end
	end
	if #parts == 0 then
		return {}, {}
	end
	center /= #parts
	local g = math.max(S.cell * vp.Y, math.sqrt(math.max((x1 - x0) * (y1 - y0), 1) / (S.max_rays * q)))
	x0, y0 = math.max(x0 - g, 0), math.max(y0 - g, 0)
	x1, y1 = math.min(x1 + g, vp.X - 1), math.min(y1 + g, vp.Y - 1)
	if x1 <= x0 or y1 <= y0 then
		return {}, {}
	end
	local nx, ny = math.floor((x1 - x0) / g) + 1, math.floor((y1 - y0) / g) + 1
	local far = (cam.CFrame.Position - center).Magnitude + span * 4
	local hits: { [number]: RaycastResult } = {}
	for j = 0, ny - 1 do
		for i = 0, nx - 1 do
			local ray = cam:ViewportPointToRay(x0 + i * g, y0 + j * g)
			local h = workspace:Raycast(ray.Origin, ray.Direction * far, params)
			if h then
				hits[j * nx + i + 1] = h
			end
		end
	end
	local function miss(i: number, j: number): boolean
		return i < 0 or j < 0 or i >= nx or j >= ny or hits[j * nx + i + 1] == nil
	end
	local right, up = cam.CFrame.RightVector, cam.CFrame.UpVector
	local edges: { SilPoint }, body: { SilPoint } = {}, {}
	for j = 0, ny - 1 do
		for i = 0, nx - 1 do
			local h = hits[j * nx + i + 1]
			if h then
				local part = h.Instance :: BasePart
				local pt: SilPoint = { part = part, lp = part.CFrame:PointToObjectSpace(h.Position), out = Vector3.yAxis }
				local l, r, u, d = miss(i - 1, j), miss(i + 1, j), miss(i, j - 1), miss(i, j + 1)
				if l or r or u or d then
					local o = right * ((if r then 1 else 0) - (if l then 1 else 0)) - up * ((if d then 1 else 0) - (if u then 1 else 0))
					pt.out = if o.Magnitude > 1e-3 then o.Unit else Vector3.yAxis
					table.insert(edges, pt)
				else
					table.insert(body, pt)
				end
			end
		end
	end
	return edges, body
end

local function playSilhouette(spec: Layer, model: Instance, scale: number?, duration: number?, intensity: number?): AuraControl
	local S = spec.silhouette
	local cf0, size0 = auraBox(model)
	local k = (scale or 1) * math.clamp(size0.Y / S.ref, 0.25, 8)
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf0, KaijuFireVFX.Parent)
	-- los rayos solo tocan las partes visibles (no la raíz ni las cajas de golpes invisibles)
	local parts = auraParts(model, 400)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = (parts :: any) :: { Instance }
	local nextParts = 2
	local items: { SilItem } = {}
	for _, L in spec.layers do
		local a = Instance.new("Attachment")
		a.Name = L.name
		a.Parent = holder
		local e = configureEmitter(L, k)
		e.Name = L.name
		e.Parent = a
		table.insert(items, { L = L, e = e, a = a, acc = 0 })
	end
	local light: PointLight? = nil
	if KaijuFireVFX.UseLight and S.light then
		local li = Instance.new("PointLight")
		li.Color = Color3.fromRGB(S.light.color[1], S.light.color[2], S.light.color[3])
		li.Range = math.min(S.light.range * k, 60)
		li.Brightness = 0
		li.Shadows = false
		li.Parent = holder
		light = li
	end

	local t0 = time()
	local stopAt: number? = duration
	local fadeOut = S.fade_out
	local edges: { SilPoint }, body: { SilPoint } = {}, {}
	local upIdx: { number }, downIdx: { number } = {}, {}
	local nextScan = 0
	local burstDone, endDone = false, false
	local ctl: AuraControl
	ctl = {
		Holder = holder,
		Model = model,
		Active = true,
		Intensity = intensity or 1,
		SetIntensity = function(self, v: number)
			self.Intensity = math.max(v, 0)
		end,
		Stop = function(_, fade: number?)
			local t = time() - t0
			if not stopAt or (stopAt :: number) > t then
				stopAt = t
				fadeOut = fade or S.fade_out
			end
		end,
	}

	-- n partículas de la capa desde el contorno, el cuerpo o los pies
	local function emit(it: SilItem, n: number)
		local L = it.L
		for _ = 1, n do
			if L.sil == "edge" then
				local idx: number
				if L.side == "up" then
					if #upIdx == 0 then
						return
					end
					idx = upIdx[rng:NextInteger(1, #upIdx)]
				elseif L.side == "down" then
					if #downIdx == 0 then
						return
					end
					idx = downIdx[rng:NextInteger(1, #downIdx)]
				else
					if #edges == 0 then
						return
					end
					idx = rng:NextInteger(1, #edges)
				end
				local pt = edges[idx]
				if not pt.part.Parent then
					continue
				end
				local up = L.up or 0
				local pos = pt.part.CFrame:PointToWorldSpace(pt.lp) + pt.out * (L.push or 0) * k
				local look = pt.out * (1 - up) + Vector3.yAxis * up
				look = if look.Magnitude > 1e-3 then look.Unit else Vector3.yAxis
				it.a.WorldCFrame = CFrame.lookAt(pos, pos + look)
			elseif L.sil == "body" then
				if #body == 0 then
					return
				end
				local pt = body[rng:NextInteger(1, #body)]
				if not pt.part.Parent then
					continue
				end
				it.a.WorldCFrame = CFrame.new(pt.part.CFrame:PointToWorldSpace(pt.lp))
			else
				local cf, size = auraBox(model)
				local r = math.max(size.X, size.Z) * (L.radius_k or 0.6) / 2 * math.sqrt(rng:NextNumber())
				local ang = rng:NextNumber(0, 2 * math.pi)
				it.a.WorldCFrame = CFrame.new(cf.Position.X + r * math.cos(ang),
					cf.Position.Y - size.Y / 2 + (L.h or 0) * k, cf.Position.Z + r * math.sin(ang))
			end
			it.e:Emit(1)
		end
	end

	local function destroyAll()
		if holder.Parent then
			holder:Destroy()
		end
		ctl.Active = false
	end

	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		local t = time() - t0
		if not model.Parent or not holder.Parent then
			conn:Disconnect()
			destroyAll()
			return
		end
		if t >= nextParts then -- por si el modelo cambia de partes
			nextParts = t + 2
			parts = auraParts(model, 400)
			params.FilterDescendantsInstances = (parts :: any) :: { Instance }
		end
		local cam = workspace.CurrentCamera
		if cam and t >= nextScan then
			-- lejos de la cámara (o con calidad baja) busca el contorno menos seguido y con menos rayos
			local d = (cam.CFrame.Position - holder.Position).Magnitude
			local near = math.clamp(80 * k / math.max(d, 1), 0.35, 1)
			nextScan = t + 1 / (S.hz * near)
			edges, body = silhouette(parts, cam, S, params, math.max(KaijuFireVFX.Quality, 0.4))
			upIdx, downIdx = {}, {}
			for i, pt in edges do
				if pt.out.Y > -0.35 then
					table.insert(upIdx, i)
				else
					table.insert(downIdx, i)
				end
			end
		end
		local on = math.clamp(t / math.max(S.fade_in, 1e-3), 0, 1)
		if stopAt then
			local u = (t - (stopAt :: number)) / math.max(fadeOut, 1e-3)
			on = math.min(on, math.clamp(1 - u, 0, 1))
			if not endDone and t >= (stopAt :: number) then
				endDone = true
				for _, it in items do
					if it.L.end_burst then
						emit(it, quality(it.L.end_burst))
					end
				end
			end
			if u >= 1 then
				if light then
					light.Brightness = 0
				end
				ctl.Active = false
				if t > (stopAt :: number) + fadeOut + S.life_max then
					conn:Disconnect()
					destroyAll()
				end
				return
			end
		end
		if not burstDone and #edges > 0 then
			burstDone = true
			for _, it in items do
				if it.L.burst then
					emit(it, quality(it.L.burst))
				end
			end
		end
		local breath = 1 + (S.breath or 0) * math.sin(2 * math.pi * (S.breath_hz or 1) * t)
		local k2 = on * ctl.Intensity * breath * KaijuFireVFX.Quality
		for _, it in items do
			local rate = it.L.rate or 0
			if rate > 0 then
				it.acc += rate * k2 * math.min(dt, 0.1)
				local n = math.floor(it.acc)
				if n > 0 then
					it.acc -= n
					emit(it, n)
				end
			end
		end
		holder.CFrame = auraBox(model)
		if light then
			light.Brightness = S.light.brightness * on * ctl.Intensity
		end
	end)
	return ctl
end

-- ---------------------------------------------------------------- la hoja que vuela (Moonfang: Medialuna)
-- Una media luna de energía hecha de trazos finos (cadenas de Beams que miran a la cámara). Va vertical y DE CANTO:
-- de lado se ve la media luna (la punta adelante y los cuernos atrás) y desde atrás, una hoja fina que apunta hacia
-- donde va. Trazo j = 0 es el filo de afuera y j = 1 el borde de adentro: cada uno es un arco de radio
-- (1 - shrink·j)·R que empieza thick·R·j detrás de la punta y abarca arc_k·arc grados hacia cada cuerno.
-- Los trazos, los emisores de su estela y su luz cuelgan de un portador que avanza por la línea (llega al final a
-- los t0 + travel s); solo se mueve el portador. Su cuerno de abajo roza el suelo y lo corta: la grieta (gash), las
-- losas que saltan a los lados (slabs) y, al final, el cráter (crater). Las losas toman el color y el material del
-- suelo; las de hielo se pueden cambiar por un modelo en KaijuFireVFX.Meshes.IceSlab.
type BladeStrand = { atts: { Attachment }, beams: { Beam }, S: any, tr: number }
type BladeEmitter = { att: Attachment, pe: ParticleEmitter, E: any, S: any, sm: number }
type GashSeg = { a: number, b: number, tc: number, parts: { BasePart }?, decal: Decal?, gy: number, done: boolean }

local function bladeLocal(B: any, S: any, sm: number, R: number, h: number, axis: Vector3): Vector3
	local a = math.rad(B.arc) * (S.arc_k or 1)
	local th = -a + 2 * a * sm
	local Rj = R * (1 - B.shrink * S.j)
	-- relativo a la punta (z positivo = detrás de la punta)
	return Vector3.new(0, h, B.thick * R * S.j + Rj * (1 - math.cos(th))) + axis * (Rj * math.sin(th))
end

local function runBlade(B: any, holder: BasePart, s: number, len: number)
	local n = B.n
	local tl = math.rad(B.tilt)
	local axis = Vector3.new(math.sin(tl), math.cos(tl), 0)
	-- lo más bajo de la hoja (por unidad de radio): roza el suelo y ahí corta
	local ymin, lowX, lowZ = 0, 0, 0
	for _, S in B.strands do
		for i = 1, n do
			local p = bladeLocal(B, S, (i - 1) / (n - 1), 1, 0, axis)
			if p.Y < ymin then
				ymin, lowX, lowZ = p.Y, p.X, p.Z
			end
		end
	end
	local Rfull = B.radius * s
	local cutX = lowX * Rfull
	local tEnd = B.t0 + B.travel
	local function cutTime(x: number): number -- cuándo el corte llega a x studs del origen
		return B.t0 + B.travel * math.clamp((x + lowZ * Rfull) / len, 0, 1)
	end
	local exclude = { holder :: Instance }

	-- el portador con los trazos, los emisores y la luz
	local carrier = invisiblePart("BladeCarrier", Vector3.new(0.2, 0.2, 0.2), holder.CFrame, holder)
	local strands: { BladeStrand } = {}
	for si, S in B.strands do
		if KaijuFireVFX.Quality < 0.7 and si > 3 and si % 2 == 1 then
			continue
		end
		local atts: { Attachment } = {}
		for i = 1, n do
			local a = Instance.new("Attachment")
			a.Parent = carrier
			atts[i] = a
		end
		local beams: { Beam } = {}
		for i = 1, n - 1 do
			local b = Instance.new("Beam")
			b.Attachment0 = atts[i]
			b.Attachment1 = atts[i + 1]
			b.FaceCamera = true
			b.Segments = 1
			b.Texture = KaijuFireVFX.TEXTURES[S.texture] or ""
			b.TextureMode = Enum.TextureMode.Stretch
			b.TextureLength = 1
			b.LightEmission = S.light_emission
			b.LightInfluence = 0
			b.Brightness = S.brightness
			b.ZOffset = (S.zoffset or 0) * s
			b.Color = ColorSequence.new(evalColor(S.color, (i - 0.5) / (n - 1)))
			b.Transparency = NumberSequence.new(1)
			b.Enabled = false
			b.Parent = carrier
			beams[i] = b
		end
		table.insert(strands, { atts = atts, beams = beams, S = S, tr = -1 })
	end
	local emitters: { BladeEmitter } = {}
	local trailEnd = tEnd
	for _, E in B.emitters or {} do
		local S = { j = E.j or 0, arc_k = E.arc_k or 1 }
		for _, sm in E.at do
			local att = Instance.new("Attachment")
			att.Parent = carrier
			local pe = configureEmitter(E, s)
			pe.Parent = att
			table.insert(emitters, { att = att, pe = pe, E = E, S = S, sm = sm })
		end
		trailEnd = math.max(trailEnd, tEnd + E.lifetime[2])
	end
	local light: PointLight? = nil
	local lightAtt: Attachment? = nil
	local lightEnd = tEnd
	if B.light and KaijuFireVFX.UseLight then
		local la = Instance.new("Attachment")
		la.Parent = carrier
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(B.light.color[1], B.light.color[2], B.light.color[3])
		pl.Range = math.min(B.light.range * s, 60)
		pl.Brightness = 0
		pl.Shadows = false
		pl.Parent = la
		light, lightAtt = pl, la
		lightEnd = tEnd + (B.light.flash_time or 0)
	end

	-- el corte: tramos de `seg` studs que aparecen cuando el corte pasa
	local G = B.gash
	local segs: { GashSeg } = {}
	if G then
		local a = (G.start or 0) * s
		while a < len - 1e-6 do
			local b = math.min(a + G.seg * s, len)
			table.insert(segs, { a = a, b = b, tc = cutTime(a), parts = nil, decal = nil, gy = 0, done = false })
			a = b
		end
	end

	-- las losas: dos filas a los lados del corte y el cráter de la detonación
	local slabs: { Slab } = {}
	local function addSlab(SL: any, x: number, z: number, yaw: number, side: number, tS: number)
		table.insert(slabs, makeSlab(SL, s, x, z, yaw, side, tS))
	end
	local slabEnd = 0
	if B.slabs then
		local SL = B.slabs
		local z, zEnd = SL.start * s, len - lowZ * Rfull
		while z < zEnd do
			for _, side in { -1, 1 } do
				local zz = z + rng:NextNumber(-0.3, 0.3) * SL.spacing * s
				if rng:NextNumber() <= KaijuFireVFX.Quality then
					addSlab(SL, cutX + side * SL.gap * s, -zz, 0, side, cutTime(zz) + rng:NextNumber(0, SL.delay))
				end
			end
			z += SL.spacing * s
		end
	end
	if B.crater then
		local CR = B.crater
		for i = 1, CR.count do
			local phi = 2 * math.pi * (i - 1 + rng:NextNumber(-0.3, 0.3)) / CR.count
			local r = CR.radius * s * rng:NextNumber(0.85, 1.15)
			addSlab(CR, r * math.cos(phi), -len + r * math.sin(phi), phi, 1, tEnd + CR.at + rng:NextNumber(0, CR.delay))
		end
	end
	for _, L in slabs do
		slabEnd = math.max(slabEnd, L.t + L.rise + L.hold + L.sink)
	end

	local widths = table.create(n, 0)
	local grown = false
	local function setShape(k: number, R: number, h: number)
		for _, c in strands do
			for i = 1, n do
				local sm = (i - 1) / (n - 1)
				c.atts[i].Position = bladeLocal(B, c.S, sm, R, h, axis)
				widths[i] = c.S.width * k * math.max(math.sin(math.pi * sm), 0) ^ B.taper
			end
			for i, b in c.beams do
				b.Width0 = widths[i]
				b.Width1 = widths[i + 1]
			end
		end
		for _, em in emitters do
			em.att.Position = bladeLocal(B, em.S, em.sm, R, h, axis)
		end
		if lightAtt then
			lightAtt.Position = Vector3.new(0, h * 0.6, R * 0.3)
		end
	end

	local function stepGash(t: number, head: number)
		for _, sg in segs do
			if sg.done then
				continue
			end
			local age = t - sg.tc
			if age < 0 then
				continue
			end
			local vis = math.clamp(head - sg.a, 0, sg.b - sg.a)
			if vis < 0.05 then
				continue
			end
			if not sg.parts then
				local mid = holder.CFrame:PointToWorldSpace(Vector3.new(cutX, 0, -(sg.a + sg.b) / 2))
				local _, _, gy = groundLook(mid, exclude)
				sg.gy = gy or holder.Position.Y
				local frost = invisiblePart("GashFrost", Vector3.new(1, 0.1, 1), holder.CFrame, holder)
				local d = Instance.new("Decal")
				d.Face = Enum.NormalId.Top
				d.Texture = KaijuFireVFX.TEXTURES[G.frost.texture] or ""
				local fg = 1 + 1.5 * (G.frost.light_emission or 0) -- los Decals se iluminan: un Color3 > 1 los hace brillar
				d.Color3 = Color3.new(G.frost.color[1] / 255 * fg, G.frost.color[2] / 255 * fg, G.frost.color[3] / 255 * fg)
				d.Transparency = 1
				d.Parent = frost
				local crev = bladePart("GashCrevice", holder)
				crev.Material = Enum.Material.SmoothPlastic
				crev.Color = Color3.fromRGB(G.crevice.color[1], G.crevice.color[2], G.crevice.color[3])
				local seam = bladePart("GashSeam", holder)
				seam.Material = Enum.Material.Neon
				sg.parts = { frost :: BasePart, crev, seam }
				sg.decal = d
			end
			local parts = sg.parts :: { BasePart }
			local fz = math.clamp((age - G.life) / G.fade, 0, 1)
			if fz >= 1 then
				for _, p in parts do
					p:Destroy()
				end
				sg.done = true
				continue
			end
			local base = holder.CFrame * CFrame.new(cutX, 0, -(sg.a + vis / 2))
			local function at(y: number): CFrame
				return CFrame.new(base.Position.X, sg.gy + y, base.Position.Z) * base.Rotation
			end
			local sp = math.clamp(age / G.spread, 0, 1)
			sp = sp * sp * (3 - 2 * sp)
			local op = math.clamp(age / G.open, 0, 1)
			parts[1].Size = Vector3.new(G.frost.width * s * (0.35 + 0.65 * sp), 0.1, vis + 2 * G.frost.overlap * s)
			parts[1].CFrame = at(0.03 * s)
			parts[2].Size = Vector3.new(G.crevice.width * s * (0.3 + 0.7 * op), 2 * G.crevice.height * s, vis)
			parts[2].CFrame = at(0)
			parts[3].Size = Vector3.new(G.seam.width * s, 2 * G.seam.height * s, vis)
			parts[3].CFrame = at(0)
			local cu = math.clamp(age / G.cool, 0, 1)
			cu = cu * cu * (3 - 2 * cu)
			local hot = Color3.fromRGB(G.seam.hot[1], G.seam.hot[2], G.seam.hot[3])
			parts[3].Color = hot:Lerp(Color3.fromRGB(G.seam.cold[1], G.seam.cold[2], G.seam.cold[3]), cu)
			parts[3].Transparency = 1 - (1 - (G.seam.transparency or 0)) * (1 - fz)
			parts[2].Transparency = fz
			if sg.decal then
				sg.decal.Transparency = 1 - (1 - G.frost.transparency) * (1 - fz)
			end
		end
	end

	local t0 = time()
	local doneAt = math.max(B.t0 + B.travel + B.fade, trailEnd, lightEnd, slabEnd)
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = time() - t0
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		if t < B.t0 then
			return
		end
		local u = math.clamp((t - B.t0) / B.travel, 0, 1)
		local gr = math.clamp((t - B.t0) / math.max(B.grow, 1e-3), 0, 1)
		gr = gr * gr * (3 - 2 * gr)
		local k = s * (B.start_k + (1 - B.start_k) * gr)
		local fz = math.clamp((t - tEnd) / math.max(B.fade, 1e-3), 0, 1)
		local fade = fz * fz * (3 - 2 * fz)
		local R = B.radius * k
		local h = B.lift * s - R * ymin
		carrier.CFrame = holder.CFrame * CFrame.new(0, 0, -len * u)
		-- crece al salir (después la forma queda fija: solo se mueve el portador)
		if not grown then
			setShape(k, R, h)
			grown = gr >= 1
		end
		for _, c in strands do
			local tr = 1 - (1 - c.S.transparency) * (1 - fade)
			if math.abs(tr - c.tr) > 0.01 then
				c.tr = tr
				for _, b in c.beams do
					b.Transparency = NumberSequence.new(tr)
					b.Enabled = tr < 0.995
				end
			end
		end
		local flying = t <= tEnd
		for _, em in emitters do
			if flying ~= em.pe.Enabled then
				em.pe.Rate = em.E.rate * KaijuFireVFX.Quality
				em.pe.Enabled = flying
			end
		end
		if light then
			local flash = if t >= tEnd then B.light.flash * math.exp(-(t - tEnd) * 3 / math.max(B.light.flash_time, 1e-3)) else 0
			light.Brightness = math.max(B.light.brightness * (1 - fade), flash)
		end
		stepGash(t, len * math.min(u, 1) - lowZ * R)
		stepSlabs(slabs, holder, t, exclude)
		local gashDone = true
		for _, sg in segs do
			if not sg.done then
				gashDone = false
				break
			end
		end
		if t > doneAt and gashDone then
			conn:Disconnect()
			carrier:Destroy()
			for _, L in slabs do
				if L.part and not L.gone then
					(L.part :: BasePart):Destroy()
				end
			end
		end
	end)
end

local function playBlade(spec: Layer, cf: CFrame, scale: number?, length: number?, shake: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local len = length or spec.line * s
	local holder = play(spec, cf, scale, len, shake)
	runBlade(spec.blade, holder, s, len)
	return holder
end

-- ---------------------------------------------------------------- ULTIMATE: cataclismo gravitacional
-- (vfx_cataclysm.py) Una sola secuencia continua sobre un campo gravitacional único. Todo lo que se levanta (rocas,
-- portadores de partículas, corrientes de energía, brazos de polvo y las víctimas) se mueve con la misma fuerza: sin
-- gravedad sube a su franja de altura (L), gira alrededor del epicentro, más rápido cerca del centro (S), y cuando
-- aparece la singularidad cae en espiral hacia ella (A) hasta desaparecer en su horizonte. El reloj manda en todo.
export type CataclysmControl = {
	Holder: Part,
	Active: boolean,
	Time: number,
	Phase: string,
	Center: Vector3,
	Radius: number,
	Singularity: Vector3,
	SingularityRadius: number,
	Victims: { any },
	GetVictimCFrame: (CataclysmControl, victim: any, t: number?) -> CFrame?,
	GetImpactPoint: (CataclysmControl, victim: any) -> Vector3?,
	Stop: (CataclysmControl) -> (),
}

type CTracer = { r: number, th: number, y: number, w: number, band: number, rise: number, inward: number, vy: number,
	seed: number }
type CEm = { L: Layer, e: ParticleEmitter }
type CCarrier = { part: Part, o: CTracer?, ems: { CEm }, size: Vector3, spin: number, ang: number, on: boolean,
	r0: number, t0: number, t1: number }
type CRock = { part: Part, o: CTracer, size: Vector3, s0: Vector3, kind: string, state: string, t1: number,
	rot: CFrame, axis: Vector3, spin: number, pos: Vector3, breakAt: number?, dieAt: number?, dieT: number,
	dieDur: number, consume: boolean, vel: Vector3, base: Vector3 }
type CChain = { atts: { Attachment }, beams: { Beam }, spec: Layer, tr: { number } }
type CVictimPlan = { inst: any, index: number, start: CFrame, land: Vector3, height: number, phi: number, l0: number,
	tl: number, ti: number, r0: number, th0: number, axis: Vector3 }
type CPlan = { spec: Layer, C: Vector3, B: Vector3, R: number, k: number, Hs: number, victims: { CVictimPlan },
	exclude: { Instance } }
type CVictim = { plan: CVictimPlan, carrier: Part, aura: { CEm }, trail: { CEm }, tether: CChain, lifted: boolean,
	launched: boolean, impacted: boolean }

local function smooth01(a: number, b: number, t: number): number
	local u = math.clamp((t - a) / math.max(b - a, 1e-6), 0, 1)
	return u * u * (3 - 2 * u)
end

local function easeOut(u: number): number
	local v = 1 - math.clamp(u, 0, 1)
	return 1 - v * v * v
end

local function rnd(range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

-- el campo en el segundo t: L (sin gravedad), S (remolino), A (atracción) y el radio del agujero (fracción del máximo)
local function cataField(Cf: Layer, t: number): (number, number, number, number)
	local T, F, Hh = Cf.t, Cf.field, Cf.hole
	local after = t >= T.det
	local L = if after then 0 else smooth01(T.lift[1], T.lift[2], t)
	local S = smooth01(T.swirl[1], T.swirl[2], t) * (1 + F.swirl_boost * smooth01(T.swirl_up[1], T.swirl_up[2], t))
	if after then
		S *= math.exp(-(t - T.det) * 3)
	end
	local A = if after then 0
		else F.a_mid * smooth01(T.attract[1], T.attract[2], t) + (1 - F.a_mid) * smooth01(T.attract[2], T.attract[3], t)
	local rbk = 0
	if t >= T.sing[1] and not after then
		local g = smooth01(T.sing[1], T.sing[2], t)
		rbk = (Hh.rb[1] + (Hh.rb[2] - Hh.rb[1]) * g) / Hh.rb[2]
		rbk *= 1 - (1 - Hh.crit_shrink) * smooth01(T.crit[1] + 0.8, T.crit[2], t)
	end
	return L, S, A, rbk
end

-- un paso del campo para algo que flota (r, th, y relativos al epicentro)
local function stepTracer(o: CTracer, dt: number, F: Layer, R: number, Hs: number, k: number, L: number, S: number,
	A: number)
	local omega = F.omega0 * o.w * (R / (o.r + F.r_core * R)) ^ F.omega_pow * S
	o.th += omega * dt
	if A > 0 then
		o.r = math.max(o.r - A * F.c_in * o.inward * (o.r + 0.06 * R) * dt, 0)
	end
	local yb = o.band * Hs
	local yt = yb + A * (Hs - yb) * math.exp(-o.r / (F.funnel * R))
	local vmax = 140 * k * o.rise
	o.y += math.clamp((yt - o.y) * o.rise * L * F.c_rise, -vmax, vmax) * dt + o.vy * dt
	o.vy *= math.exp(-1.6 * dt)
	if A > 0 then
		o.y += (Hs - o.y) * math.min(1, A * A * F.c_up * dt)
	end
end

local function tracerPos(o: CTracer, C: Vector3, F: Layer, R: number, Hs: number, t: number): Vector3
	local rr = math.max(o.r + R * F.turb_r * math.noise(o.seed, t * 0.35), 0)
	local yy = o.y + Hs * F.turb_y * math.noise(o.seed + 7.3, t * 0.5)
	return C + Vector3.new(math.cos(o.th) * rr, yy, math.sin(o.th) * rr)
end


-- el radio del agujero en el segundo tt (studs)
local function cataRb(Cf: Layer, k: number, tt: number): number
	local _, _, _, rbk = cataField(Cf, math.min(tt, Cf.t.det - 1e-3))
	return rbk * Cf.hole.rb[2] * k
end

-- dónde pasa todo: el epicentro en el suelo, la singularidad y el recorrido de cada víctima. No crea nada ni usa números
-- al azar: el servidor y los clientes calculan exactamente lo mismo.
local function cataclysmPlan(spec: Layer, epicenter: any, victimsIn: any, options: { [string]: any }?): CPlan
	local opt: { [string]: any } = options or {}
	local Cf = spec.cataclysm
	local T, Vc = Cf.t, Cf.victims
	local R = opt.Radius or Cf.radius
	local k = R / Cf.radius
	local Hs = opt.Height or Cf.height * k
	local victimList: { any } = if typeof(victimsIn) == "table" then victimsIn elseif victimsIn ~= nil then { victimsIn } else {}
	local p0 = pointOf(epicenter) or Vector3.zero
	local exclude: { Instance } = {}
	if typeof(epicenter) == "Instance" then
		table.insert(exclude, epicenter)
	end
	if typeof(opt.Caster) == "Instance" then
		table.insert(exclude, opt.Caster)
	end
	for _, v in victimList do
		if typeof(v) == "Instance" then
			table.insert(exclude, v)
		end
	end
	local _, _, gy0 = groundLook(p0, exclude, 400)
	local C = Vector3.new(p0.X, gy0 or p0.Y, p0.Z)
	local victims: { CVictimPlan } = {}
	local n = #victimList
	for i, v in victimList do
		local cf: CFrame? = nil
		local height = Vc.ref * k
		if typeof(v) == "Instance" then
			if v:IsA("Model") then
				cf = v:GetPivot()
				local _, size = v:GetBoundingBox()
				height = size.Y
			elseif v:IsA("BasePart") then
				cf = v.CFrame
				height = v.Size.Y
			end
		elseif typeof(v) == "CFrame" then
			cf = v
		elseif typeof(v) == "Vector3" then
			cf = CFrame.new(v)
		end
		if not cf then
			continue
		end
		local start = cf :: CFrame
		local rel = Vector3.new(start.Position.X - C.X, 0, start.Position.Z - C.Z)
		local land: Vector3
		if opt.ImpactPoints and opt.ImpactPoints[i] then
			land = opt.ImpactPoints[i]
		else
			-- cae en su lugar, pero nunca tan lejos que la caída deje de ser hacia abajo
			local dist = math.min(rel.Magnitude, Vc.land_max * Hs)
			local dir = if rel.Magnitude > 1e-3 then rel.Unit else Vector3.xAxis
			land = C + dir * dist
			local _, _, ly = groundLook(land, exclude, 300)
			land = Vector3.new(land.X, ly or C.Y, land.Z)
		end
		local l0 = T.victims[1] + Vc.stagger * (i - 1)
		local tl = T.det + Vc.fall_stagger * (i - 1)
		table.insert(victims, { inst = v, index = i, start = start, land = land, height = height,
			phi = math.atan2(rel.Z, rel.X) + math.pi * (i - 1) / math.max(n, 1), l0 = l0, tl = tl, ti = tl + Vc.fall,
			r0 = rel.Magnitude, th0 = math.atan2(rel.Z, rel.X),
			axis = Vector3.new(math.sin(i * 1.7), 0.6, math.cos(i * 2.3)).Unit })
	end
	return { spec = spec, C = C, B = C + Vector3.new(0, Hs, 0), R = R, k = k, Hs = Hs, victims = victims, exclude = exclude }
end

local function cataHoldPos(P: CPlan, vic: CVictimPlan, tt: number): Vector3
	local Cf = P.spec.cataclysm
	local Vc = Cf.victims
	local rb = cataRb(Cf, P.k, tt)
	local ang = vic.phi + Vc.hold_spin * (tt - vic.l0)
	local rr = Vc.hold_r * rb + vic.height * 0.6
	return P.B + Vector3.new(math.cos(ang) * rr, -Vc.hold_drop * rb + math.sin(tt * 1.7 + vic.index) * 6 * P.k, math.sin(ang) * rr)
end

-- dónde está cada víctima en el segundo tt: tiembla, sube en espiral, queda atrapada junto al agujero, sale disparada
-- hacia abajo y queda en el cráter
local function cataVictimCFrame(P: CPlan, vic: CVictimPlan, tt: number): CFrame
	local Cf = P.spec.cataclysm
	local Vc = Cf.victims
	local C = P.C
	local start = vic.start
	local rotOnly = start - start.Position
	if tt < vic.l0 then
		local a = smooth01(vic.l0 - Vc.tremble, vic.l0, tt) * vic.height * 0.02
		return start + Vector3.new(math.noise(vic.index + 0.5, tt * 23) * a, 0, math.noise(vic.index + 5.5, tt * 23) * a)
	end
	local liftEnd = Cf.t.victims[2]
	if tt < liftEnd then
		local u = smooth01(vic.l0, liftEnd, tt)
		local H = cataHoldPos(P, vic, tt)
		local rel = H - C
		local rH = Vector3.new(rel.X, 0, rel.Z).Magnitude
		local thH = math.atan2(rel.Z, rel.X)
		local target = vic.th0 + Vc.turns * 2 * math.pi
		local dth = (thH - target + math.pi) % (2 * math.pi) - math.pi
		local th = vic.th0 + (Vc.turns * 2 * math.pi + dth) * u
		local rr = vic.r0 + (rH - vic.r0) * u ^ 0.9
		local y0 = start.Position.Y
		local yy = y0 + (H.Y - y0) * (u * u * (3 - 2 * u))
		return CFrame.new(C.X + math.cos(th) * rr, yy, C.Z + math.sin(th) * rr) * CFrame.fromAxisAngle(vic.axis, u * 2.2) * rotOnly
	end
	if tt < vic.tl then
		return CFrame.new(cataHoldPos(P, vic, tt)) * CFrame.fromAxisAngle(vic.axis, 2.2 + (tt - liftEnd) * 0.8) * rotOnly
	end
	if tt < vic.ti then
		local s = (tt - vic.tl) / (vic.ti - vic.tl)
		local from = cataHoldPos(P, vic, vic.tl)
		local to = vic.land + Vector3.new(0, vic.height * 0.35, 0)
		return CFrame.new(from + (to - from) * (s * s)) * CFrame.fromAxisAngle(vic.axis, 2.2 + (vic.tl - liftEnd) * 0.8 + s * 2) * rotOnly
	end
	-- en el cráter, un poco hundida y torcida
	return CFrame.new(vic.land + Vector3.new(0, vic.height * 0.3, 0)) * CFrame.fromAxisAngle(vic.axis, 0.5) * rotOnly
end

local function cataFindVictim(P: CPlan, v: any): CVictimPlan?
	for _, vic in P.victims do
		if vic.inst == v or vic.index == v then
			return vic
		end
	end
	return nil
end

local function randomUnit(): Vector3
	local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	return if v.Magnitude > 1e-3 then v.Unit else Vector3.yAxis
end

local function playCataclysm(spec: Layer, impactSpec: Layer, epicenter: any, victimsIn: any, options: { [string]: any }?): CataclysmControl
	local opt: { [string]: any } = options or {}
	local Cf = spec.cataclysm
	local T, Fd, Hh, Rk = Cf.t, Cf.field, Cf.hole, Cf.rocks
	local plan = cataclysmPlan(spec, epicenter, victimsIn, opt)
	local R, k, Hs, C, B = plan.R, plan.k, plan.Hs, plan.C, plan.B
	local exclude = plan.exclude
	local shakeK = if opt.Shake == nil then 1 else opt.Shake
	local Q = KaijuFireVFX.Quality
	local victimList: { any } = if typeof(victimsIn) == "table" then victimsIn elseif victimsIn ~= nil then { victimsIn } else {}
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), CFrame.new(C), KaijuFireVFX.Parent)
	table.insert(exclude, holder)
	local isClient = RunService:IsClient()

	local byRole: { [string]: { Layer } } = {}
	for _, L in spec.layers do
		local list = byRole[L.role]
		if not list then
			list = {}
			byRole[L.role] = list
		end
		table.insert(list, L)
	end
	local function roleLayers(role: string): { Layer }
		return byRole[role] or {}
	end
	local layerByName: { [string]: Layer } = {}
	for _, L in spec.layers do
		layerByName[L.name] = L
	end

	local ctl: CataclysmControl
	local clock = 0
	local silent = false
	local function fire(name: string, ...: any)
		if silent or not opt.OnEvent then
			return
		end
		task.spawn(opt.OnEvent, name, ...)
	end

	-- ---------------- emisores ----------------
	local allEms: { CEm } = {}
	local function addEmitters(part: Part, role: string, index: number, kk: number): { CEm }
		local out: { CEm } = {}
		for _, L in roleLayers(role) do
			if L.every and index % L.every ~= 0 then
				continue
			end
			local e = configureEmitter(L, kk)
			e.LockedToPart = L.locked == true
			if not L.shape then
				e.Shape = Enum.ParticleEmitterShape.Box
				e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			end
			e.Parent = part
			local item = { L = L, e = e }
			table.insert(out, item)
			table.insert(allEms, item)
		end
		return out
	end
	local function setRates(ems: { CEm }, t: number, gate: number)
		for _, it in ems do
			local env = if it.L.env then evalNum(it.L.env, t) else 1
			local rate = (it.L.rate or 0) * env * gate * Q
			if silent then
				rate = 0
			end
			it.e.Rate = rate
			it.e.Enabled = rate > 0.01
		end
	end
	local function disable(ems: { CEm })
		for _, it in ems do
			it.e.Enabled = false
		end
	end

	-- ráfagas: un emisor por capa que se mueve a cada punto y suelta Emit
	local bursts: { [string]: { part: Part, e: ParticleEmitter, L: Layer } } = {}
	for _, L in roleLayers("burst") do
		local part = invisiblePart(L.name .. "_Burst", Vector3.one, CFrame.new(C), holder)
		local e = configureEmitter(L, k)
		e.Parent = part
		bursts[L.name] = { part = part, e = e, L = L }
	end
	local function burst(name: string, pos: Vector3, n: number, sizeK: number?)
		local b = bursts[name]
		if silent or not b or n <= 0 then
			return
		end
		local sk = sizeK or 1
		local r = if b.L.shape and b.L.shape.radius then b.L.shape.radius * 2 * k * sk else 1
		b.part.Size = Vector3.one * math.clamp(r, 0.2, 2000)
		b.part.CFrame = CFrame.new(pos)
		b.e.Size = numberSeq(b.L.size, k * sk)
		b.e:Emit(quality(n))
	end
	local function decal(name: string, pos: Vector3, sizeK: number)
		local L = layerByName[name]
		if silent or not L then
			return
		end
		playDecalAt(L, holder, k * sizeK, 1, CFrame.new(pos + Vector3.new(0, 0.3 * k, 0)))
	end

	-- ---------------- cadenas de Beams (corrientes, brazos de polvo, ondas) ----------------
	local function makeBeam(Bs: Layer, a0: Attachment, a1: Attachment): Beam
		local b = Instance.new("Beam")
		b.Name = Bs.name
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Texture = KaijuFireVFX.TEXTURES[Bs.texture] or ""
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = Bs.tex_len * k
		b.TextureSpeed = Bs.speed
		b.LightEmission = Bs.light_emission
		b.LightInfluence = 0
		b.Brightness = Bs.brightness
		b.Color = colorSeq(Bs.color)
		b.FaceCamera = true
		b.Segments = 3
		b.Width0 = 0
		b.Width1 = 0
		b.Transparency = NumberSequence.new(1)
		b.Enabled = false
		b.Parent = holder
		return b
	end
	local function makeChain(Bs: Layer, n: number, closed: boolean): CChain
		local atts: { Attachment } = {}
		for i = 1, n do
			local a = Instance.new("Attachment")
			a.Name = Bs.name
			a.Parent = holder
			atts[i] = a
		end
		local beams: { Beam } = {}
		local tr: { number } = {}
		for i = 1, if closed then n else n - 1 do
			beams[i] = makeBeam(Bs, atts[i], atts[i % n + 1])
			tr[i] = 1
		end
		return { atts = atts, beams = beams, spec = Bs, tr = tr }
	end
	local camNow = Vector3.zero
	local function showChain(ch: CChain, pts: { Vector3 }, widths: { number }, trs: { number })
		if silent then
			return -- adelantando el campo (StartTime): no se dibuja
		end
		local n = #ch.atts
		for i = 1, n do
			ch.atts[i].WorldPosition = pts[i]
			local w = widths[i]
			local near = math.clamp(((pts[i] - camNow).Magnitude - w * 0.8) / (w * 2.5), 0, 1)
			trs[i] = 1 - (1 - trs[i]) * near
		end
		for i, b in ch.beams do
			local j = i % n + 1
			local tr = math.max(trs[i], trs[j])
			if tr >= 0.995 then
				b.Enabled = false
			else
				b.Enabled = true
				b.Width0 = widths[i]
				b.Width1 = widths[j]
				if math.abs(ch.tr[i] - tr) > 0.01 then
					ch.tr[i] = tr
					b.Transparency = NumberSequence.new(tr)
				end
			end
		end
	end
	local function hideChain(ch: CChain)
		for _, b in ch.beams do
			b.Enabled = false
		end
	end
	local LO = Cf.loops
	local function showLoop(ch: CChain, radius: number, y: number, width: number, tr: number)
		local n = #ch.atts
		local pts, ws, trs = table.create(n), table.create(n), table.create(n)
		for i = 1, n do
			local a = 2 * math.pi * (i - 1) / n
			pts[i] = C + Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
			ws[i] = width
			trs[i] = tr
		end
		showChain(ch, pts, ws, trs)
	end

	-- ---------------- el despertar: portadores en la onda que recorre el suelo ----------------
	local function frontR(t: number): number
		return R * easeOut((t - T.front[1]) / (T.front[2] - T.front[1]))
	end
	local front: { CCarrier } = {}
	for i = 1, Cf.front_n do
		local part = invisiblePart("CataFront", Vector3.one, CFrame.new(C), holder)
		local c: CCarrier = { part = part, o = nil, ems = addEmitters(part, "front", i, k), size = Vector3.one, spin = 0,
			ang = 2 * math.pi * (i - 1) / Cf.front_n + rng:NextNumber(-0.1, 0.1), on = true, r0 = 0, t0 = 0, t1 = 0 }
		table.insert(front, c)
	end
	local frontLoop = makeChain(LO.front, LO.points, true)
	local ripLoops = { makeChain(LO.ripple, LO.points, true), makeChain(LO.ripple_purple, LO.points, true),
		makeChain(LO.ripple, LO.points, true) }

	-- ---------------- la tormenta: anillos de portadores que siguen al campo ----------------
	local function newTracer(r: number, th: number, y: number, band: number): CTracer
		return { r = r, th = th, y = y, w = rng:NextNumber(0.85, 1.15), band = band, rise = rng:NextNumber(0.6, 1.0),
			inward = rng:NextNumber(0.85, 1.15), vy = 0, seed = rng:NextNumber(0, 1000) }
	end
	local storm: { CCarrier } = {}
	local idx = 0
	for _, ring in Cf.rings do
		local r, n, band, hgt = ring[1] * R, ring[2], ring[3], ring[4] * Hs
		for i = 1, n do
			idx += 1
			local part = invisiblePart("CataStorm", Vector3.one, CFrame.new(C), holder)
			local th = 2 * math.pi * (i - 1) / n + rng:NextNumber(-0.25, 0.25)
			local arc = math.min(2 * math.pi * r / n * 0.85, 2000)
			local c: CCarrier = { part = part, o = newTracer(r, th, band * Hs * 0.3, band), ems = addEmitters(part, "storm", idx, k),
				size = Vector3.new(math.min(R * 0.15, 2000), math.min(hgt, 2000), arc), spin = 0, ang = 0, on = true, r0 = r,
				t0 = 0, t1 = 0 }
			table.insert(storm, c)
		end
	end
	local UD = Cf.updrafts
	local updrafts: { CCarrier } = {}
	for i = 1, UD.n do
		local part = invisiblePart("CataUpdraft", Vector3.one * 60 * k, CFrame.new(C), holder)
		local r = rnd(UD.r) * R
		local c: CCarrier = { part = part, o = newTracer(r, rng:NextNumber(0, 2 * math.pi), 0, rnd(UD.band)),
			ems = addEmitters(part, "updraft", i, k), size = Vector3.new(120, 40, 120) * k, spin = 0, ang = 0, on = true,
			r0 = r, t0 = 0, t1 = 0 }
		table.insert(updrafts, c)
	end
	local ED = Cf.eddies
	local eddies: { CCarrier } = {}
	for i = 1, ED.n do
		local part = invisiblePart("CataEddy", Vector3.one, CFrame.new(C), holder)
		local r = rnd(ED.r) * R
		local life = ED.life[(i - 1) % #ED.life + 1]
		local c: CCarrier = { part = part, o = newTracer(r, rng:NextNumber(0, 2 * math.pi), 0, rnd(ED.band)),
			ems = addEmitters(part, "eddy", i, k), size = Vector3.new(ED.box[1], ED.box[2], ED.box[3]) * k,
			spin = math.rad(rnd(ED.spin)), ang = 0, on = true, r0 = r, t0 = life[1], t1 = life[2] }
		table.insert(eddies, c)
	end

	-- corrientes de energía, brazos de polvo y corrientes de acreción
	local Cu, Bd, St = Cf.currents, Cf.bands, Cf.streams
	type CCurrent = { ch: CChain, rc: number, th: number, wind: number, w: number, inward: number, seed: number }
	local currents: { CCurrent } = {}
	for c = 1, Cu.n do
		local frac = (c - 1) / math.max(Cu.n - 1, 1)
		table.insert(currents, { ch = makeChain(Cu.beams[(c - 1) % #Cu.beams + 1], Cu.points, false),
			rc = R * (Cu.r[1] + (Cu.r[2] - Cu.r[1]) * ((frac * 7.31) % 1)), th = 2 * math.pi * (c - 1) / Cu.n + rng:NextNumber(-0.2, 0.2),
			wind = rnd(Cu.wind), w = rnd(Cu.w), inward = rng:NextNumber(0.8, 1.2), seed = rng:NextNumber(0, 1000) })
	end
	type CArm = { ch: CChain, pts: { CTracer } }
	local arms: { CArm } = {}
	for a = 1, Bd.n do
		local th0 = 2 * math.pi * (a - 1) / Bd.n + rng:NextNumber(-0.2, 0.2)
		local pts: { CTracer } = {}
		local w = rng:NextNumber(0.95, 1.05)
		for j = 1, Bd.points do
			local u = (j - 1) / (Bd.points - 1)
			local band = Bd.band[1] + (Bd.band[2] - Bd.band[1]) * u
			local o = newTracer(R * (Bd.r[1] + (Bd.r[2] - Bd.r[1]) * u), th0 + Bd.spiral * u, band * Hs * 0.4, band)
			o.w, o.rise, o.inward = w, 0.6, 1
			pts[j] = o
		end
		table.insert(arms, { ch = makeChain(Bd.beams[(a - 1) % #Bd.beams + 1], Bd.points, false), pts = pts })
	end
	type CStream = { ch: CChain, o: CTracer }
	local streams: { CStream } = {}
	for s = 1, St.n do
		local o = newTracer(rnd(St.r) * R, 2 * math.pi * (s - 1) / St.n, 0, rnd(St.band))
		o.y = o.band * Hs
		table.insert(streams, { ch = makeChain(St.beams[(s - 1) % #St.beams + 1], St.points, false), o = o })
	end

	-- ---------------- rocas (Parts que siguen al campo) ----------------
	local rocks: { CRock } = {}
	local counts: { [string]: number } = { medium = 0, chunk = 0, frag = 0, rain = 0 }
	local function rockPart(size: Vector3, color: Color3, material: Enum.Material, shadow: boolean, cf: CFrame): Part
		local p = Instance.new("Part")
		p.Name = "CataclysmRock"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = shadow
		p.Material = material
		p.Color = color
		p.Size = size
		p.CFrame = cf
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = holder
		return p
	end
	local function spawnRock(kind: string, t: number)
		local P = Rk[kind]
		local rf = math.min(frontR(t), R)
		local rmin = Rk.r_min * R
		if rf <= rmin * 1.3 then
			return
		end
		local r = math.sqrt(rng:NextNumber((rmin / R) ^ 2, (rf / R) ^ 2)) * R
		local th = rng:NextNumber(0, 2 * math.pi)
		local gp = C + Vector3.new(math.cos(th) * r, 0, math.sin(th) * r)
		local col, mat, yy = groundLook(gp, exclude, 200)
		gp = Vector3.new(gp.X, yy or C.Y, gp.Z)
		if rng:NextNumber() < P.dark then
			col = Color3.fromRGB(62, 64, 76):Lerp(col, 0.25)
			mat = Enum.Material.Slate
		end
		local s = skewed(P.size[1], P.size[2], P.skew) * k
		local size = Vector3.new(s * rng:NextNumber(0.75, 1.25), s * rnd(P.aspect), s * rng:NextNumber(0.75, 1.25))
		local o: CTracer = { r = r, th = th, y = (gp.Y - C.Y) - size.Y * 0.35, w = rnd(P.w), band = rnd(P.band),
			rise = rnd(P.rise), inward = rnd(P.inward), vy = 0, seed = rng:NextNumber(0, 1000) }
		local shoot = rng:NextNumber() < P.shoot
		local rot = if kind == "chunk" then CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 2 * math.pi), rng:NextNumber(-0.15, 0.15))
			else CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
		local base = gp + Vector3.new(0, -size.Y * 0.35, 0)
		local rk: CRock = { part = rockPart(size, col, mat, kind == "chunk", CFrame.new(base) * rot), o = o, size = size, s0 = size, kind = kind,
			state = "embed", t1 = t + (if shoot then rng:NextNumber(0.08, 0.2) else rnd(P.tremble)), rot = rot,
			axis = randomUnit(), spin = if kind == "chunk" then rng:NextNumber(0.2, 0.6) else rng:NextNumber(0.8, 3.0),
			pos = gp, breakAt = if rng:NextNumber() < P.break_p then rnd(P.break_t) else nil, dieAt = nil, dieT = 0,
			dieDur = 0.45, consume = false, vel = Vector3.zero, base = base }
		if shoot then
			o.vy = rng:NextNumber(300, 500) * k
		end
		table.insert(rocks, rk)
		counts[kind] += 1
		if kind == "chunk" then
			decal("GroundCrack", gp, size.X / (80 * k))
			decal("GroundVoid", gp, size.X / (90 * k))
			burst("BurstDust", gp + Vector3.new(0, 10 * k, 0), 8, size.X / (60 * k))
			burst("BurstDebris", gp, 10)
		elseif rng:NextNumber() < 0.3 then
			burst("BurstDust", gp, 2, 0.5)
		end
	end
	local function newFragment(parent: CRock, t: number, kind: string)
		local Fg = Rk.frag
		local sz = Vector3.new(parent.size.X * rnd(Fg.k), math.min(parent.size.Y * rnd(Fg.k) * 1.5, parent.size.Y),
			parent.size.Z * rnd(Fg.k))
		local po = parent.o
		local o: CTracer = { r = math.max(po.r + rng:NextNumber(-0.5, 0.5) * parent.size.X, 0),
			th = po.th + rng:NextNumber(-0.5, 0.5) * parent.size.X / math.max(po.r, 1),
			y = po.y + rng:NextNumber(-0.5, 0.5) * parent.size.Y, w = po.w * rng:NextNumber(0.85, 1.25),
			band = po.band * rng:NextNumber(0.9, 1.4), rise = po.rise * rng:NextNumber(1, 1.5),
			inward = po.inward * rng:NextNumber(0.9, 1.3), vy = rng:NextNumber(-40, 120) * k, seed = rng:NextNumber(0, 1000) }
		local rot = parent.rot * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0)
		local rk: CRock = { part = rockPart(sz, parent.part.Color, parent.part.Material, false, CFrame.new(parent.pos) * rot),
			o = o, size = sz, s0 = sz, kind = kind, state = "fly", t1 = t, rot = rot,
			axis = randomUnit(), spin = rng:NextNumber(1.5, 4.0), pos = parent.pos, breakAt = nil, dieAt = t + rnd(Fg.life),
			dieT = 0, dieDur = 0.5, consume = false, vel = Vector3.zero, base = parent.pos }
		table.insert(rocks, rk)
		counts.frag += 1
	end
	local function fragment(rk: CRock, t: number)
		local n = rng:NextInteger(Rk.frag.n[1], Rk.frag.n[2])
		if counts.frag > 80 * Q then
			n = 1
		end
		for _ = 1, n do
			newFragment(rk, t, "frag")
		end
		local sk = rk.size.Magnitude / (40 * k)
		burst("BurstDust", rk.pos, 4 + math.floor(sk * 4), math.clamp(sk, 0.4, 2))
		burst("BurstSparks", rk.pos, 10, math.clamp(sk, 0.5, 2))
		burst("BurstDebris", rk.pos, 8, 1)
		if rk.kind == "chunk" then
			burst("BurstFlash", rk.pos, 1, math.clamp(sk, 0.6, 1.5))
		end
		rk.part:Destroy()
		counts[rk.kind] -= 1
	end
	local function kill(rk: CRock, t: number, consume: boolean, dur: number)
		rk.state = "die"
		rk.dieT = t
		rk.dieDur = dur
		rk.consume = consume
	end

	-- ---------------- la singularidad (geometría: el núcleo, anillos y discos que miran a la cámara, la lente) ---------
	type CBill = { part: Part, d: Decal }
	local function bill(name: string, tex: string): CBill
		local p = invisiblePart(name, Vector3.new(1, 1, 0.05), CFrame.new(B), holder)
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Front
		d.Texture = KaijuFireVFX.TEXTURES[tex] or ""
		d.Transparency = 1
		d.Parent = p
		return { part = p, d = d }
	end
	local function placeBill(b: CBill, pos: Vector3, camPos: Vector3, size: number, roll: number, color: Color3, tr: number)
		if silent then
			return
		end
		local sz = math.clamp(size, 0.1, 2048)
		b.part.Size = Vector3.new(sz, sz, 0.05)
		b.part.CFrame = CFrame.lookAt(pos, camPos) * CFrame.Angles(0, 0, roll)
		b.d.Color3 = color
		b.d.Transparency = math.clamp(tr, 0, 1)
	end
	local function ball(name: string, material: Enum.Material, color: Color3, tr: number): Part
		local p = invisiblePart(name, Vector3.one, CFrame.new(B), holder)
		p.Shape = Enum.PartType.Ball
		p.Material = material
		p.Color = color
		p.Transparency = tr
		return p
	end
	type CHole = { core: Part, lens: Part, halo: CBill, photon: CBill, purple: CBill, swirl: CBill, wind: CBill,
		glow: CBill, disk: Part, diskD: { Decal }, disk2: Part, tilt: CFrame, carriers: { { part: Part, ems: { CEm }, shell: number } } }
	local hole: CHole? = nil
	local function camPosition(): Vector3
		local cam = workspace.CurrentCamera
		return if cam then cam.CFrame.Position else B + Vector3.new(0, 0, 1000)
	end
	local function makeHole()
		local camPos = camPosition()
		local d = Vector3.new(camPos.X - B.X, 0, camPos.Z - B.Z)
		local tilt = CFrame.identity
		if d.Magnitude > 1e-3 then
			local axis = Vector3.yAxis:Cross(d.Unit)
			tilt = CFrame.fromAxisAngle(axis, math.rad(Hh.tilt))
		end
		local function disk(name: string, tex: string, col: Color3): (Part, { Decal })
			local p = invisiblePart(name, Vector3.new(1, 0.05, 1), CFrame.new(B), holder)
			local ds = {}
			for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
				local dd = Instance.new("Decal")
				dd.Face = face
				dd.Texture = KaijuFireVFX.TEXTURES[tex] or ""
				dd.Color3 = col
				dd.Transparency = 1
				dd.Parent = p
				table.insert(ds, dd)
			end
			return p, ds
		end
		local dk, dkd = disk("HoleDisk", "kk_light_03", Color3.new(0.75, 1.1, 1.5))
		local dk2, dk2d = disk("HoleDiskPurple", "fx_swirl_rings", Color3.new(1.2, 0.6, 1.6))
		for _, dd in dk2d do
			table.insert(dkd, dd)
		end
		local carriers = {}
		for _, role in { "hole", "crit" } do
			for _, L in roleLayers(role) do
				local part = invisiblePart(L.name .. "_Shell", Vector3.one, CFrame.new(B), holder)
				local e = configureEmitter(L, k)
				e.Shape = Enum.ParticleEmitterShape.Sphere
				e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
				e.ShapeInOut = if L.outward then Enum.ParticleEmitterShapeInOut.Outward else Enum.ParticleEmitterShapeInOut.Inward
				e.Parent = part
				local item = { L = L, e = e }
				table.insert(allEms, item)
				table.insert(carriers, { part = part, ems = { item }, shell = L.shell or 1 })
			end
		end
		hole = { core = ball("HoleCore", Enum.Material.Neon, Color3.new(0, 0, 0), 0),
			lens = ball("HoleLens", Enum.Material.Glass, Color3.fromRGB(24, 30, 80), 1),
			halo = bill("HoleHalo", "fx_glow"), photon = bill("PhotonRing", "kk_circle_02"),
			purple = bill("PhotonPurple", "kk_circle_02"), swirl = bill("HoleSwirl", "fx_swirl_rings"),
			wind = bill("HoleWind", "fx_wind_swirl"), glow = bill("CritGlow", "fx_glow"), disk = dk, diskD = dkd,
			disk2 = dk2, tilt = tilt, carriers = carriers }
	end
	local pulsePhase = 0

	-- ---------------- las víctimas ----------------
	local Vc = Cf.victims
	local victims: { CVictim } = {}
	for _, vp in plan.victims do
		local part = invisiblePart("CataVictim", Vector3.one, vp.start, holder)
		local vk = k * math.clamp(vp.height / (Vc.ref * k), 0.6, 2.2)
		table.insert(victims, { plan = vp, carrier = part, aura = addEmitters(part, "victim", vp.index, vk),
			trail = addEmitters(part, "trail", vp.index, vk), tether = makeChain(Vc.tether, 2, false), lifted = false,
			launched = false, impacted = false })
	end
	local function victimPos(vp: CVictimPlan, tt: number): Vector3
		if opt.MoveVictims or typeof(vp.inst) ~= "Instance" then
			return cataVictimCFrame(plan, vp, tt).Position
		end
		local inst = vp.inst :: any
		if inst:IsA("Model") then
			return inst:GetPivot().Position
		end
		return inst.Position
	end

	-- ---------------- destello y corrección de color (solo en el cliente) ----------------
	local cc: Instance? = nil
	local flashGui: Instance? = nil
	local flashFrame: Frame? = nil
	if isClient then
		pcall(function()
			local lighting = game:GetService("Lighting")
			local e = Instance.new("ColorCorrectionEffect")
			e.Name = "OmnivoraCataclysm"
			e.Parent = lighting
			cc = e
		end)
		if opt.Flash ~= false then
			pcall(function()
				local Players = game:GetService("Players")
				local lp = Players.LocalPlayer
				local pg = lp and (lp :: any).PlayerGui
				if not pg then
					return
				end
				local gui = Instance.new("ScreenGui")
				gui.Name = "OmnivoraCataclysmFlash"
				gui.IgnoreGuiInset = true
				gui.ResetOnSpawn = false
				gui.DisplayOrder = 1000
				local fr = Instance.new("Frame")
				fr.Size = UDim2.fromScale(1, 1)
				fr.BackgroundColor3 = Color3.new(1, 1, 1)
				fr.BorderSizePixel = 0
				fr.BackgroundTransparency = 1
				fr.Parent = gui
				gui.Parent = pg
				flashGui = gui
				flashFrame = fr
			end)
		end
	end

	-- ---------------- detonación ----------------
	local Dc = Cf.det
	type CDet = { core: Part, shell: Part, shell2: Part, ring: CBill, distort: Part, sky: { CChain }, ground: { CChain },
		wall: { CCarrier } }
	local det: CDet? = nil
	local detEms: { CEm } = {}
	local detCarrier = invisiblePart("CataDetonation", Vector3.one, CFrame.new(B), holder)
	for _, L in roleLayers("det") do
		local e = configureEmitter(L, k)
		e.Parent = detCarrier
		table.insert(detEms, { L = L, e = e })
	end
	local function makeDetonation()
		local wall: { CCarrier } = {}
		for i = 1, Dc.wall_n do
			local part = invisiblePart("CataWall", Vector3.one, CFrame.new(C), holder)
			table.insert(wall, { part = part, o = nil, ems = addEmitters(part, "wall", i, k), size = Vector3.one, spin = 0,
				ang = 2 * math.pi * (i - 1) / Dc.wall_n, on = true, r0 = 0, t0 = 0, t1 = 0 })
		end
		det = { core = ball("DetCore", Enum.Material.Neon, Color3.fromRGB(220, 238, 255), 0),
			shell = ball("DetShell", Enum.Material.ForceField, Color3.fromRGB(110, 170, 255), 0.15),
			shell2 = ball("DetShellPurple", Enum.Material.ForceField, Color3.fromRGB(190, 90, 255), 1),
			ring = bill("DetRing", "kk_circle_02"), distort = ball("DetDistortion", Enum.Material.Glass, Color3.fromRGB(40, 60, 120), 0.55),
			sky = { makeChain(LO.det_sky, LO.points, true), makeChain(LO.det_sky_purple, LO.points, true) },
			ground = { makeChain(LO.det_ground, LO.points, true), makeChain(LO.det_ground_core, LO.points, true) },
			wall = wall }
		detCarrier.Size = Vector3.one * math.min(2 * Hh.rb[2] * k, 2000)
		if not silent then
			for _, it in detEms do
				it.e:Emit(quality(it.L.n or 10))
			end
		end
	end
	local after: { CCarrier } = {}
	local function makeAftermath()
		local AF = Cf.after
		for i = 1, AF.n do
			local r = rnd(AF.r) * R
			local th = rng:NextNumber(0, 2 * math.pi)
			local part = invisiblePart("CataAfter", Vector3.new(300, 80, 300) * k,
				CFrame.new(C + Vector3.new(math.cos(th) * r, 40 * k, math.sin(th) * r)), holder)
			table.insert(after, { part = part, o = nil, ems = addEmitters(part, "after", i, k), size = Vector3.one, spin = 0,
				ang = 0, on = true, r0 = r, t0 = 0, t1 = 0 })
		end
	end

	-- ---------------- lluvia de piedras después de la detonación ----------------
	local rain = Rk.rain
	local rainTimes: { number } = {}
	for i = 1, math.floor(rain.n * Q + 0.5) do
		rainTimes[i] = rain.t[1] + (rain.t[2] - rain.t[1]) * (i - 1) / math.max(rain.n * Q - 1, 1)
	end
	local rainNext = 1
	local function spawnRain()
		local r = rnd(rain.r) * R
		local th = rng:NextNumber(0, 2 * math.pi)
		local s = rnd(rain.size) * k
		local size = Vector3.new(s * rng:NextNumber(0.7, 1.3), s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.7, 1.3))
		local pos = C + Vector3.new(math.cos(th) * r, rnd(rain.height) * k, math.sin(th) * r)
		local o: CTracer = { r = r, th = th, y = pos.Y - C.Y, w = 1, band = 0, rise = 0, inward = 0, vy = 0, seed = rng:NextNumber(0, 1000) }
		table.insert(rocks, { part = rockPart(size, Color3.fromRGB(96, 98, 110), Enum.Material.Slate, false, CFrame.new(pos)), o = o,
			size = size, s0 = size, kind = "rain", state = "fall", t1 = 0, rot = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			axis = randomUnit(), spin = rng:NextNumber(1, 4), pos = pos, breakAt = nil, dieAt = nil, dieT = 0, dieDur = 0.3,
			consume = false, vel = Vector3.new(rng:NextNumber(-20, 20), -rng:NextNumber(0, 60), rng:NextNumber(-20, 20)) * k, base = pos })
		counts.rain += 1
	end

	-- ---------------- lentes gravitacionales que laten durante la tormenta ----------------
	type CLens = { part: Part, o: CTracer, size: number, ph: number }
	local lenses: { CLens } = {}
	for i = 1, if (KaijuFireVFX :: any).Lens == false then 0 else 3 do
		local o = newTracer(rng:NextNumber(0.15, 0.5) * R, rng:NextNumber(0, 6.28), 0, rng:NextNumber(0.12, 0.3))
		table.insert(lenses, { part = ball("GravityLens", Enum.Material.Glass, Color3.fromRGB(30, 44, 110), 1), o = o,
			size = rng:NextNumber(140, 260) * k, ph = i * 2.1 })
	end

	-- ---------------- el control ----------------
	local conn: RBXScriptConnection? = nil
	local cleaned = false
	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true
		ctl.Active = false
		if conn then
			conn:Disconnect()
		end
		if holder.Parent then
			holder:Destroy()
		end
		if cc then
			cc:Destroy()
		end
		if flashGui then
			flashGui:Destroy()
		end
	end
	ctl = {
		Holder = holder,
		Active = true,
		Time = 0,
		Phase = Cf.phases[1][1],
		Center = C,
		Radius = R,
		Singularity = B,
		SingularityRadius = 0,
		Victims = victimList,
		GetVictimCFrame = function(_, v: any, tt: number?): CFrame?
			local vic = cataFindVictim(plan, v)
			return if vic then cataVictimCFrame(plan, vic, tt or clock) else nil
		end,
		GetImpactPoint = function(_, v: any): Vector3?
			local vic = cataFindVictim(plan, v)
			return if vic then vic.land else nil
		end,
		Stop = function(_)
			cleanup()
		end,
	}
	if shakeK > 0 then
		addShakeSource(function()
			if not ctl.Active then
				return nil
			end
			return shakeK * evalNum(Cf.shake, clock)
		end)
	end

	local phaseIdx = 0
	local nextRate = 0
	local nextCollide = 0
	local spawnAcc: { [string]: number } = { medium = 0, chunk = 0 }
	local ripplesFired = 0
	local nextCrack = Cf.cracks[1]
	local detDone, afterDone = false, false
	local movParts: { BasePart } = {}
	local movCF: { CFrame } = {}

	local function update(dt: number)
		clock += dt
		local t = clock
		ctl.Time = t
		while phaseIdx < #Cf.phases and t >= Cf.phases[phaseIdx + 1][2] do
			phaseIdx += 1
			ctl.Phase = Cf.phases[phaseIdx][1]
			fire("Phase", ctl.Phase, phaseIdx)
		end
		if t >= T["end"] then
			fire("Finished")
			cleanup()
			return
		end
		local L, S, A, rbk = cataField(Cf, t)
		local rb = rbk * Hh.rb[2] * k
		ctl.SingularityRadius = rb
		local doRates = t >= nextRate or silent
		if doRates then
			nextRate = t + 0.1
		end
		table.clear(movParts)
		table.clear(movCF)
		local camPos = camPosition()
		camNow = camPos

		-- el despertar
		local rf = frontR(t)
		for _, c in front do
			if not c.on then
				continue
			end
			if t > T.front[2] + 4.5 then
				c.on = false
				disable(c.ems)
				continue
			end
			local pos = C + Vector3.new(math.cos(c.ang) * rf, 30 * k, math.sin(c.ang) * rf)
			local tangent = Vector3.new(-math.sin(c.ang), 0, math.cos(c.ang))
			c.part.Size = Vector3.new(160 * k, 60 * k, math.clamp(2 * math.pi * rf / Cf.front_n * 0.8, 40 * k, 2000))
			table.insert(movParts, c.part)
			table.insert(movCF, CFrame.lookAt(pos, pos + tangent))
			if doRates then
				setRates(c.ems, t, 1)
			end
		end
		-- el suelo se agrieta detrás de la onda
		while t >= nextCrack and nextCrack <= Cf.cracks[2] do
			nextCrack += Cf.cracks[3]
			local cr = math.sqrt(rng:NextNumber((Rk.r_min * R / math.max(rf, 1)) ^ 2, 1)) * rf
			local ca = rng:NextNumber(0, 2 * math.pi)
			local cp = C + Vector3.new(math.cos(ca) * cr, 0, math.sin(ca) * cr)
			local _, _, cy = groundLook(cp, exclude, 200)
			decal("GroundCrack", Vector3.new(cp.X, cy or C.Y, cp.Z), rng:NextNumber(0.6, 1.3))
		end
		local ftr = 1 - (1 - LO.front.transparency) * (1 - smooth01(T.front[2] - 0.4, T.front[2] + 0.5, t))
		if ftr < 0.995 then
			showLoop(frontLoop, math.max(rf, 1), 18 * k, LO.front.width * k, ftr)
		else
			hideChain(frontLoop)
		end
		-- ondas de gravedad (cada una se abre hasta el borde)
		local anyRipple = { false, false, false }
		for ri, ts in LO.ripples do
			local u = (t - ts) / LO.ripple_time
			if u >= 0 and u <= 1 then
				local slot = (ri - 1) % 3 + 1
				local Bs = ripLoops[slot].spec
				anyRipple[slot] = true
				local radius = R * (0.05 + 0.95 * easeOut(u))
				showLoop(ripLoops[slot], radius, 12 * k, Bs.width * k * (1 - 0.4 * u),
					1 - (1 - Bs.transparency) * (1 - u) ^ 0.7)
				if ri > ripplesFired then
					ripplesFired = ri
				end
			end
		end
		for slot = 1, 3 do
			if not anyRipple[slot] then
				hideChain(ripLoops[slot])
			end
		end

		-- la tormenta
		for _, c in storm do
			if not c.on then
				continue
			end
			local o = c.o :: CTracer
			stepTracer(o, dt, Fd, R, Hs, k, L, S, A)
			local pos = tracerPos(o, C, Fd, R, Hs, t)
			if (rb > 1 and A > 0.25 and (pos - B).Magnitude < rb * Fd.capture * 1.5) or t >= T.det then
				c.on = false
				disable(c.ems)
				continue
			end
			local tangent = Vector3.new(-math.sin(o.th), 0, math.cos(o.th))
			local shrink = math.clamp((o.r / c.r0) ^ 0.8, 0.15, 1)
			if doRates then
				c.part.Size = Vector3.new(c.size.X * shrink, c.size.Y, c.size.Z * shrink)
				setRates(c.ems, t, 1)
			end
			table.insert(movParts, c.part)
			table.insert(movCF, CFrame.lookAt(pos, pos + tangent))
		end
		for _, c in updrafts do
			if not c.on then
				continue
			end
			local o = c.o :: CTracer
			stepTracer(o, dt, Fd, R, Hs, k, L, S, A)
			local pos = tracerPos(o, C, Fd, R, Hs, t)
			if (rb > 1 and A > 0.25 and (pos - B).Magnitude < rb * Fd.capture * 2) or t >= T.det then
				c.on = false
				disable(c.ems)
				continue
			end
			-- apuntan al cielo y, con la atracción, a la singularidad
			local up = pos + Vector3.new(0, 1000 * k, 0)
			local aim = up:Lerp(B, math.clamp(A * 1.3, 0, 1))
			table.insert(movParts, c.part)
			table.insert(movCF, CFrame.lookAt(pos, aim))
			if doRates then
				setRates(c.ems, t, 1)
			end
		end
		for _, c in eddies do
			if not c.on then
				continue
			end
			local o = c.o :: CTracer
			stepTracer(o, dt, Fd, R, Hs, k, L, S, A)
			local pos = tracerPos(o, C, Fd, R, Hs, t)
			if t > c.t1 + 2.5 or (rb > 1 and A > 0.25 and (pos - B).Magnitude < rb * Fd.capture * 1.5) then
				c.on = false
				disable(c.ems)
				continue
			end
			c.ang += c.spin * dt
			if doRates then
				c.part.Size = c.size
				local gate = smooth01(c.t0, c.t0 + 0.8, t) * (1 - smooth01(c.t1 - 0.8, c.t1, t))
				setRates(c.ems, t, gate)
			end
			table.insert(movParts, c.part)
			table.insert(movCF, CFrame.new(pos) * CFrame.Angles(0, c.ang, 0))
		end
		for _, ls in lenses do
			stepTracer(ls.o, dt, Fd, R, Hs, k, L, S, A)
			local pos = tracerPos(ls.o, C, Fd, R, Hs, t)
			local vis = smooth01(0.6, 2.0, t) * (1 - smooth01(9.0, 10.5, t))
			local pulse = 0.75 + 0.25 * math.sin(t * 2.3 + ls.ph)
			ls.part.Size = Vector3.one * math.max(ls.size * pulse, 0.2)
			ls.part.Transparency = 1 - 0.2 * vis
			table.insert(movParts, ls.part)
			table.insert(movCF, CFrame.new(pos))
		end

		-- corrientes de energía: giran con la tormenta y se doblan hacia la singularidad
		local np = Cu.points
		for _, cur in currents do
			local omega = Fd.omega0 * cur.w * (R / (cur.rc + Fd.r_core * R)) ^ Fd.omega_pow * S
			cur.th += omega * dt
			if A > 0 then
				cur.rc = math.max(cur.rc - A * Fd.c_in * cur.inward * (cur.rc + 0.06 * R) * dt, 0)
			end
			local alpha = smooth01(Cu.fade[1], Cu.fade[2], t) * math.clamp(cur.rc / (0.12 * R), 0, 1)
			if t >= T.det or alpha <= 0.01 then
				hideChain(cur.ch)
				continue
			end
			local Bs = cur.ch.spec
			local bend = math.clamp(A * Cu.bend, 0, 1)
			local pts, ws, trs = table.create(np), table.create(np), table.create(np)
			for j = 1, np do
				local u = (j - 1) / (np - 1)
				local rr = cur.rc * (1 - 0.3 * u)
				local th = cur.th + cur.wind * u + 0.15 * math.noise(cur.seed, t * 0.4 + u * 2)
				local yy = u * Cu.top * Hs
				local b = bend * u ^ 1.2
				rr *= 1 - b
				yy += (Hs - yy) * b
				pts[j] = C + Vector3.new(math.cos(th) * rr, yy, math.sin(th) * rr)
				ws[j] = Bs.width * k * (1 - Cu.taper * u) * (0.85 + 0.3 * math.noise(cur.seed + 3, t * 0.8 + u))
				local endFade = math.clamp(math.min(u / 0.12, (1 - u) / 0.12), 0, 1)
				trs[j] = 1 - (1 - Bs.transparency) * alpha * endFade
			end
			showChain(cur.ch, pts, ws, trs)
		end
		-- brazos de polvo: cada punto es arrastrado por el campo
		local na = Bd.points
		for _, arm in arms do
			local Bs = arm.ch.spec
			local pts, ws, trs = table.create(na), table.create(na), table.create(na)
			local anyVis = false
			for j = 1, na do
				local o = arm.pts[j]
				stepTracer(o, dt, Fd, R, Hs, k, L, S, A)
				local u = (j - 1) / (na - 1)
				pts[j] = tracerPos(o, C, Fd, R, Hs, t)
				ws[j] = Bs.width * k * (0.55 + 0.45 * math.sin(math.pi * u))
				local alpha = smooth01(Bd.fade[1], Bd.fade[2], t) * math.clamp(o.r / (0.1 * R), 0, 1)
				if t >= T.det then
					alpha = 0
				end
				local endFade = math.clamp(math.min(u / 0.15, (1 - u) / 0.15), 0, 1)
				trs[j] = 1 - (1 - Bs.transparency) * alpha * endFade
				anyVis = anyVis or alpha > 0.01
			end
			if anyVis then
				showChain(arm.ch, pts, ws, trs)
			else
				hideChain(arm.ch)
			end
		end
		-- corrientes de acreción: la tormenta alimenta al agujero
		local ns = St.points
		for _, st in streams do
			local o = st.o
			stepTracer(o, dt, Fd, R, Hs, k, L, S, A)
			local alpha = smooth01(St.fade[1], St.fade[2], t) * (1 - smooth01(13.6, 14.3, t)) * math.clamp(o.r / (0.08 * R), 0, 1)
			if t >= T.det or alpha <= 0.01 or rb < 1 then
				hideChain(st.ch)
				continue
			end
			local Bs = st.ch.spec
			local base = tracerPos(o, C, Fd, R, Hs, t)
			local pts, ws, trs = table.create(ns), table.create(ns), table.create(ns)
			for j = 1, ns do
				local u = (j - 1) / (ns - 1)
				local rr = o.r * (1 - u) ^ 1.3
				local th = o.th + St.turns * 2 * math.pi * u
				local yy = (base.Y - C.Y) + (Hs - (base.Y - C.Y)) * u ^ 0.8
				pts[j] = if j == ns then B else C + Vector3.new(math.cos(th) * rr, yy, math.sin(th) * rr)
				ws[j] = Bs.width * k * (1 - 0.75 * u)
				local endFade = math.clamp(u / 0.1, 0, 1)
				trs[j] = 1 - (1 - Bs.transparency) * alpha * endFade
			end
			showChain(st.ch, pts, ws, trs)
		end

		-- rocas: nacen, tiemblan, se despegan, orbitan, chocan, se rompen, se deshacen o se las traga el agujero
		if t < T.det then
			for _, kind in { "medium", "chunk" } do
				local P = Rk[kind]
				local rate = 0
				for _, w in P.rate do
					if t >= w[1] and t <= w[2] then
						rate += w[3] + (w[4] - w[3]) * (t - w[1]) / math.max(w[2] - w[1], 1e-3)
					end
				end
				spawnAcc[kind] += rate * Q * dt
				while spawnAcc[kind] >= 1 do
					spawnAcc[kind] -= 1
					if counts[kind] < P.max * Q then
						spawnRock(kind, t)
					end
				end
			end
		end
		while rainNext <= #rainTimes and t >= rainTimes[rainNext] do
			rainNext += 1
			spawnRain()
		end
		-- choques entre rocas grandes
		if t >= nextCollide and t < T.det then
			nextCollide = t + Rk.collide.every
			local big: { CRock } = {}
			for _, rk in rocks do
				if rk.state == "fly" and math.max(rk.size.X, rk.size.Z) >= Rk.collide.min_size * k then
					table.insert(big, rk)
				end
			end
			local hitA, hitB = nil, nil
			for a = 1, #big do
				for b = a + 1, #big do
					local ra, rb2 = big[a], big[b]
					if (ra.pos - rb2.pos).Magnitude < (ra.size.Magnitude + rb2.size.Magnitude) * 0.35 then
						hitA, hitB = ra, rb2
						break
					end
				end
				if hitA then
					break
				end
			end
			if hitA and hitB then
				burst("BurstFlash", (hitA.pos + hitB.pos) / 2, 1, 1)
				for _, rk in { hitA, hitB } do
					local at = table.find(rocks, rk)
					if at then
						fragment(rk, t)
						table.remove(rocks, at)
					end
				end
			end
		end

		local i = #rocks
		while i >= 1 do
			local rk = rocks[i]
			local o = rk.o
			local pos = rk.pos
			local removed = false
			if rk.state == "embed" then
				local a = rk.size.Magnitude * 0.03
				pos = rk.base + Vector3.new(math.noise(o.seed, t * 25) * a, math.noise(o.seed + 3, t * 25) * a * 0.5,
					math.noise(o.seed + 6, t * 25) * a)
				if t >= rk.t1 then
					rk.state = "fly"
					if rk.kind == "chunk" then
						burst("BurstDust", rk.base, 4, rk.size.X / (70 * k))
					end
				end
			elseif rk.state == "fly" then
				if t >= T.det then
					-- la detonación: se acaba la atracción, salen despedidas y caen
					local outward = pos - B
					rk.vel = (if outward.Magnitude > 1e-3 then outward.Unit else Vector3.yAxis) * rng:NextNumber(250, 600) * k
					rk.state = "fall"
				else
					-- al final del consumo la atracción se lleva lo que siga flotando: la masa crítica empieza en el vacío
					local sweep = smooth01(T.attract[3], T.attract[3] + Rk.sweep[1], t)
					if sweep > 0 then
						o.inward = math.max(o.inward, Rk.sweep[2] * sweep)
					end
					stepTracer(o, dt, Fd, R, Hs, k, L, S, A)
					pos = tracerPos(o, C, Fd, R, Hs, t)
					if rb > 1 and A > 0.2 and (pos - B).Magnitude < rb * Fd.capture or t >= T.crit[1] then
						kill(rk, t, true, 0.25)
						burst("ConsumeFlash", pos, 1, math.clamp(rk.size.Magnitude / (30 * k), 0.4, 1.6))
					elseif rk.breakAt and t >= rk.breakAt then
						rk.pos = pos
						fragment(rk, t)
						table.remove(rocks, i)
						removed = true
					elseif rk.dieAt and t >= rk.dieAt then
						kill(rk, t, false, 0.5)
						burst("BurstSparks", pos, 3, 0.5)
					end
				end
			elseif rk.state == "die" then
				local u = (t - rk.dieT) / rk.dieDur
				if u >= 1 then
					rk.part:Destroy()
					counts[rk.kind] -= 1
					table.remove(rocks, i)
					removed = true
				else
					if rk.consume then
						pos = pos:Lerp(B, math.min(1, dt * 8))
					end
					rk.part.Size = rk.s0 * math.max(1 - u, 0.05)
				end
			elseif rk.state == "fall" then
				rk.vel += Vector3.new(0, -230 * k, 0) * dt
				rk.vel *= math.exp(-0.4 * dt)
				pos += rk.vel * dt
				if pos.Y <= C.Y + rk.size.Y * 0.3 then
					pos = Vector3.new(pos.X, C.Y + rk.size.Y * 0.3, pos.Z)
					burst("BurstDust", pos, 2, math.clamp(rk.size.Magnitude / (25 * k), 0.3, 1.2))
					kill(rk, t, false, 0.3)
				end
			end
			if not removed then
				rk.rot = rk.rot * CFrame.fromAxisAngle(rk.axis, rk.spin * dt * (if rk.state == "embed" then 0 else 1))
				rk.pos = pos
				table.insert(movParts, rk.part)
				table.insert(movCF, CFrame.new(pos) * rk.rot)
			end
			i -= 1
		end
		-- la singularidad
		if not hole and t >= T.sing[1] and t < T.det then
			makeHole()
			-- nace: un destello en el cielo para que se note desde el primer instante
			burst("BurstFlash", B, 2, 3)
			burst("ConsumeFlash", B, 2, 3)
			burst("BurstSparks", B, 30, 2)
		end
		if hole and t < T.det then
			local h = hole :: CHole
			local birth = smooth01(T.sing[1], T.sing[1] + 0.8, t)
			local crit = smooth01(T.crit[1], T.crit[2], t)
			pulsePhase += 2 * math.pi * (Hh.pulse_hz[1] + (Hh.pulse_hz[2] - Hh.pulse_hz[1]) * crit) * dt
			local pulse = 0.5 + 0.5 * math.sin(pulsePhase)
			h.core.Size = Vector3.one * math.clamp(2 * rb, 0.2, 2048)
			table.insert(movParts, h.core)
			table.insert(movCF, CFrame.new(B))
			local glowK = 1.8 + 1.7 * crit * (0.6 + 0.4 * pulse)
			placeBill(h.halo, B, camPos, Hh.halo * rb, 0, Color3.fromRGB(10, 14, 40), 1 - 0.75 * birth)
			placeBill(h.photon, B, camPos, Hh.photon * rb, 0, Color3.new(0.92 * glowK, 0.97 * glowK, glowK),
				1 - (0.9 - 0.1 * crit) * birth)
			placeBill(h.purple, B, camPos, Hh.purple * rb, 0, Color3.new(0.9 * glowK * 0.8, 0.5 * glowK * 0.8, glowK * 0.8),
				1 - 0.6 * birth)
			placeBill(h.swirl, B, camPos, Hh.swirl * rb, math.rad(Hh.spin_swirl * t * (0.6 + 0.4 * S)),
				Color3.new(0.55, 0.85, 1.1), 1 - 0.65 * birth)
			placeBill(h.wind, B, camPos, Hh.wind * rb, math.rad(Hh.spin_wind * t), Color3.new(0.75, 0.3, 1.0), 1 - 0.6 * birth)
			placeBill(h.glow, B, camPos, rb * (Hh.glow[1] + (Hh.glow[2] - Hh.glow[1]) * crit), 0,
				Color3.new(0.9 * glowK, 0.95 * glowK, glowK), 1 - (0.92 * crit ^ 1.5) * (0.7 + 0.3 * pulse))
			local dsz = math.clamp(Hh.disk * rb, 0.1, 2048)
			h.disk.Size = Vector3.new(dsz, 0.05, dsz)
			h.disk2.Size = Vector3.new(math.min(dsz * 1.25, 2048), 0.05, math.min(dsz * 1.25, 2048))
			table.insert(movParts, h.disk)
			table.insert(movCF, CFrame.new(B) * h.tilt * CFrame.Angles(0, math.rad(Hh.spin_disk * t), 0))
			table.insert(movParts, h.disk2)
			table.insert(movCF, CFrame.new(B) * h.tilt * CFrame.Angles(0, math.rad(-Hh.spin_disk * 0.6 * t), 0))
			for di, dd in h.diskD do
				dd.Transparency = 1 - (if di <= 2 then 0.55 else 0.45) * birth
			end
			local away = B - camPos
			local lensPos = B + (if away.Magnitude > 1e-3 then away.Unit else Vector3.zAxis) * rb * 0.9
			h.lens.Size = Vector3.one * math.clamp(Hh.lens * rb * (1 + 0.08 * crit * pulse), 0.2, 2048)
			h.lens.Transparency = if (KaijuFireVFX :: any).Lens == false then 1 else 1 - 0.38 * birth
			table.insert(movParts, h.lens)
			table.insert(movCF, CFrame.new(lensPos))
			if doRates then
				for _, hc in h.carriers do
					local shell = hc.shell * rb
					hc.part.Size = Vector3.one * math.clamp(2 * shell, 0.2, 2000)
					for _, it in hc.ems do
						if not it.L.outward then
							it.e.Speed = NumberRange.new(shell / it.L.lifetime[2], shell / it.L.lifetime[1])
						end
					end
					setRates(hc.ems, t, birth)
				end
			end
		end

		-- las víctimas
		for _, vic in victims do
			local vp = vic.plan
			if opt.MoveVictims and typeof(vp.inst) == "Instance" and not silent then
				local cf = cataVictimCFrame(plan, vp, t)
				local inst = vp.inst :: any
				if inst:IsA("Model") then
					inst:PivotTo(cf)
				elseif inst:IsA("BasePart") then
					inst.CFrame = cf
				end
			end
			local pos = victimPos(vp, t)
			vic.carrier.Size = Vector3.new(vp.height * 0.8, vp.height, vp.height * 0.8)
			table.insert(movParts, vic.carrier)
			table.insert(movCF, CFrame.new(pos))
			if not vic.lifted and t >= vp.l0 then
				vic.lifted = true
				local gp = Vector3.new(vp.start.Position.X, C.Y, vp.start.Position.Z)
				burst("BurstDust", gp + Vector3.new(0, 8 * k, 0), 10, vp.height / (40 * k))
				burst("BurstDebris", gp, 16, 1)
				burst("BurstFlash", gp + Vector3.new(0, vp.height * 0.5, 0), 1, 1)
				decal("GroundCrack", gp, vp.height / (50 * k))
				decal("GroundVoid", gp, vp.height / (60 * k))
				fire("VictimLift", vp.inst, vp.index)
			end
			if not vic.launched and t >= vp.tl then
				vic.launched = true
				fire("VictimLaunch", vp.inst, vp.index)
			end
			if not vic.impacted and t >= vp.ti then
				vic.impacted = true
				if opt.AutoImpacts ~= false and not silent then
					play(impactSpec, CFrame.new(vp.land), k * math.clamp(vp.height / (Vc.ref * k), 0.6, 2.2), nil, shakeK)
				end
				fire("VictimImpact", vp.inst, vp.index, vp.land)
			end
			if doRates then
				setRates(vic.aura, t, if t >= vp.l0 and t < vp.tl then 1 else 0)
				setRates(vic.trail, t, if t >= vp.tl and t < vp.ti then 1 else 0)
			end
			local tetherOn = smooth01(vp.l0 + 0.3, vp.l0 + 1.0, t) * (1 - smooth01(vp.tl - 0.15, vp.tl, t))
			if tetherOn > 0.01 and rb > 1 then
				local Bs = Vc.tether
				local tr = 1 - (1 - Bs.transparency) * tetherOn * (0.7 + 0.3 * math.sin(t * 9 + vp.index))
				showChain(vic.tether, { pos, B }, { Bs.width * k, Bs.width * k * 0.4 }, { tr, tr })
			else
				hideChain(vic.tether)
			end
		end

		-- la detonación
		if not detDone and t >= T.det then
			detDone = true
			if hole then
				local h = hole :: CHole
				for _, hc in h.carriers do
					disable(hc.ems)
				end
				for _, p in { h.core, h.lens, h.halo.part, h.photon.part, h.purple.part, h.swirl.part, h.wind.part, h.glow.part, h.disk, h.disk2 } do
					p:Destroy()
				end
			end
			makeDetonation()
			fire("Detonation", B)
		end
		if det then
			local d = det :: CDet
			local td = t - T.det
			if td > 3.0 then
				for _, p in { d.core, d.shell, d.shell2, d.ring.part, d.distort } do
					if p.Parent then
						p:Destroy()
					end
				end
				for _, ch in d.sky do
					hideChain(ch)
				end
				for _, ch in d.ground do
					hideChain(ch)
				end
				for _, c in d.wall do
					disable(c.ems)
				end
			else
				local rbMax = Hh.rb[2] * k
				local core = math.clamp(2 * rbMax * Dc.core[2] * easeOut(td / Dc.core[1]), 0.2, 2048)
				d.core.Size = Vector3.one * core
				d.core.Transparency = smooth01(Dc.core[3], Dc.core[3] + Dc.core[4], td)
				local sh = math.clamp(300 * k + (Dc.shell[2] - 300 * k) * easeOut(td / Dc.shell[1]), 0.2, 2048)
				d.shell.Size = Vector3.one * sh
				d.shell.Transparency = Dc.shell[3] + (1 - Dc.shell[3]) * smooth01(0, Dc.shell[1], td) ^ 0.7
				local td2 = td - Dc.shell2[3]
				local sh2 = math.clamp(200 * k + (Dc.shell2[2] - 200 * k) * easeOut(td2 / Dc.shell2[1]), 0.2, 2048)
				d.shell2.Size = Vector3.one * sh2
				d.shell2.Transparency = if td2 < 0 then 1 else Dc.shell2[4] + (1 - Dc.shell2[4]) * smooth01(0, Dc.shell2[1], td2) ^ 0.7
				placeBill(d.ring, B, camPos, Dc.ring[2] * easeOut(td / Dc.ring[1]), 0, Color3.new(2.0, 2.2, 2.5),
					smooth01(0, Dc.ring[1], td))
				d.distort.Size = Vector3.one * math.clamp(Dc.distort[2] * easeOut(td / Dc.distort[1]), 0.2, 2048)
				d.distort.Transparency = Dc.distort[3] + (1 - Dc.distort[3]) * smooth01(0, Dc.distort[1], td)
				for _, p in { d.core, d.shell, d.shell2, d.distort } do
					table.insert(movParts, p)
					table.insert(movCF, CFrame.new(B))
				end
				local us = math.clamp(td / Dc.sky[1], 0, 1)
				for ci, ch in d.sky do
					local Bs = ch.spec
					if us < 1 then
						showLoop(ch, R * Dc.sky[2] * easeOut(us) * (if ci == 1 then 1 else 0.92), Hs, Bs.width * k * (1 - 0.5 * us),
							1 - (1 - Bs.transparency) * (1 - us) ^ 0.8)
					else
						hideChain(ch)
					end
				end
				local ug = math.clamp((td - Dc.ground[1]) / Dc.ground[2], 0, 1)
				local groundR = R * Dc.ground[3] * easeOut(ug)
				for _, ch in d.ground do
					local Bs = ch.spec
					if td >= Dc.ground[1] and ug < 1 then
						showLoop(ch, math.max(groundR, 1), 28 * k, Bs.width * k * (1 - 0.35 * ug),
							1 - (1 - Bs.transparency) * (1 - ug) ^ 0.6)
					else
						hideChain(ch)
					end
				end
				for _, c in d.wall do
					local pos = C + Vector3.new(math.cos(c.ang) * groundR, 30 * k, math.sin(c.ang) * groundR)
					c.part.Size = Vector3.new(120 * k, 60 * k, math.clamp(2 * math.pi * groundR / Dc.wall_n * 0.8, 40 * k, 2000))
					table.insert(movParts, c.part)
					table.insert(movCF, CFrame.lookAt(pos, pos + Vector3.new(-math.sin(c.ang), 0, math.cos(c.ang))))
					if doRates then
						setRates(c.ems, t, if td >= Dc.ground[1] then 1 else 0)
					end
				end
			end
		end
		if not afterDone and t >= T.det + 0.3 then
			afterDone = true
			makeAftermath()
		end
		if doRates then
			for _, c in after do
				setRates(c.ems, t, 1)
			end
		end

		-- destello y luz
		if cc then
			local e = cc :: any
			local n = #Cf.cc
			local row = Cf.cc[n]
			for ci = 1, n - 1 do
				local a, b = Cf.cc[ci], Cf.cc[ci + 1]
				if t <= b[1] then
					local u = math.clamp((t - a[1]) / math.max(b[1] - a[1], 1e-6), 0, 1)
					row = {}
					for c2 = 1, 7 do
						row[c2] = a[c2] + (b[c2] - a[c2]) * u
					end
					break
				end
			end
			e.Brightness = row[2]
			e.Contrast = row[3]
			e.Saturation = row[4]
			e.TintColor = Color3.fromRGB(math.clamp(row[5], 0, 255), math.clamp(row[6], 0, 255), math.clamp(row[7], 0, 255))
		end
		if flashFrame then
			local fl = Cf.flash
			local a = 0
			if t >= fl[1] and t < fl[2] then
				a = ((t - fl[1]) / (fl[2] - fl[1])) ^ 2
			elseif t >= fl[2] and t < fl[2] + fl[3] then
				a = 1
			elseif t >= fl[2] + fl[3] then
				a = 1 - math.clamp((t - fl[2] - fl[3]) / fl[4], 0, 1)
			end
			(flashFrame :: Frame).BackgroundTransparency = 1 - a
		end

		if #movParts > 0 and not silent then
			workspace:BulkMoveTo(movParts, movCF, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	-- empezar a mitad de la secuencia (para revisar una fase): se adelanta el campo sin partículas ni ráfagas
	local startT = math.clamp(opt.StartTime or 0, 0, T.det - 0.05)
	if startT > 0 then
		silent = true
		local steps = math.ceil(startT * 30)
		for _ = 1, steps do
			update(startT / steps)
			if cleaned then
				break
			end
		end
		silent = false
		nextRate = 0
	end
	if not cleaned then
		conn = RunService.Heartbeat:Connect(function(dt: number)
			if not holder.Parent then
				cleanup()
				return
			end
			update(math.min(dt, 0.1))
		end)
	end
	return ctl
end

-- el plan sin efectos (para el servidor): dónde está cada víctima en cada segundo, cuándo sube, cuándo sale disparada y
-- cuándo y dónde se estrella. Calcula lo mismo que GravitationalCataclysm en los clientes.
export type CataclysmPlanControl = {
	Center: Vector3,
	Singularity: Vector3,
	Radius: number,
	GetVictimCFrame: (CataclysmPlanControl, victim: any, t: number) -> CFrame?,
	GetImpactPoint: (CataclysmPlanControl, victim: any) -> Vector3?,
	GetVictimTimes: (CataclysmPlanControl, victim: any) -> { [string]: number }?,
}
local function planCataclysm(spec: Layer, epicenter: any, victimsIn: any, options: { [string]: any }?): CataclysmPlanControl
	local P = cataclysmPlan(spec, epicenter, victimsIn, options)
	return {
		Center = P.C,
		Singularity = P.B,
		Radius = P.R,
		GetVictimCFrame = function(_, v: any, t: number): CFrame?
			local vic = cataFindVictim(P, v)
			return if vic then cataVictimCFrame(P, vic, t) else nil
		end,
		GetImpactPoint = function(_, v: any): Vector3?
			local vic = cataFindVictim(P, v)
			return if vic then vic.land else nil
		end,
		GetVictimTimes = function(_, v: any): { [string]: number }?
			local vic = cataFindVictim(P, v)
			if not vic then
				return nil
			end
			return { Lift = vic.l0, Held = spec.cataclysm.t.victims[2], Launch = vic.tl, Impact = vic.ti }
		end,
	}
end

'''


def norm_cubes(C):
    """Cubos de destrucción: el destello (fx) es una capa normal; el color de la vista previa no va al módulo."""
    o = {k: v for k, v in C.items() if k not in ("fx", "preview_color", "groups")}
    o["groups"] = [dict(G) for G in C["groups"]]
    if C.get("fx"):
        o["fx"] = norm_layer(C["fx"])
    return o


def norm_beam(B):
    """Capa de Beam: secuencias como listas (el color a lo largo del rayo, el ancho y el desvanecido en el tiempo)."""
    o = dict(B)
    o["color"] = [[k[0], list(k[1])] for k in B["color"]]
    o["transparency"] = [list(k) for k in B["transparency"]]
    o["width_t"] = [list(k) for k in B["width_t"]]
    o["alpha_t"] = [list(k) for k in B["alpha_t"]]
    return o


def walk_textures(v):
    """Todas las texturas que nombra un diccionario anidado (las cadenas de Beams de la ULTIMATE)."""
    out = set()
    if isinstance(v, dict):
        if isinstance(v.get("texture"), str):
            out.add(v["texture"])
        for x in v.values():
            out |= walk_textures(x)
    elif isinstance(v, (list, tuple)):
        for x in v:
            out |= walk_textures(x)
    return out


def spec_textures(spec):
    extra = [spec["cubes"]["fx"]] if spec.get("cubes", {}).get("fx") else []
    tex = textures_of(spec["layers"] + extra + spec.get("beams", []))
    for k in ("cataclysm", "blade", "field", "front", "zbeams", "zfield"):
        if spec.get(k):
            tex |= walk_textures(spec[k])
    return tex | set(spec.get("textures", []))


def prefix_unused(src):
    """Funciones locales que este módulo no usa: el prefijo "_" evita el aviso de función sin usar."""
    for n in re.findall(r"^local function (\w+)\(", src, flags=re.M):
        if len(re.findall(r"\b" + n + r"\b", src)) == 1:
            src = re.sub(r"^local function " + n + r"\(", "local function _" + n + "(", src, count=1, flags=re.M)
    return src


def build(specs, name, doc):
    """Texto del ModuleScript `name` con los efectos de `specs`."""
    tex = sorted(set().union(*(spec_textures(spec) for spec in specs.values())))
    tex_lines = "\n".join(f'\t{t} = "rbxassetid://0",' for t in tex)
    out = HEADER.replace("__DOC__", doc).replace("__TEXTURES__", tex_lines)
    for key, spec in specs.items():
        data = {"name": spec["name"], "duration": spec["duration"],
                "cleanup": round(max(spec["duration"], spec_end(spec)) + 0.3, 2),
                "layers": [norm_layer(L) for L in spec["layers"]]}
        for k in ("shakes", "shake_ramp", "rocks", "scale_mult", "light", "cone", "zone", "lights", "orb", "beam", "hit",
                  "aura", "cataclysm", "line", "times", "screen"):
            if spec.get(k):
                data[k] = [list(x) for x in spec[k]] if k == "shakes" else spec[k]
        if spec.get("cubes"):
            data["cubes"] = norm_cubes(spec["cubes"])
        if spec.get("silhouette"):
            sc = dict(spec["silhouette"])
            sc["life_max"] = max(L["lifetime"][1] for L in spec["layers"])
            data["silhouette"] = plain(sc)
        if spec.get("aura"):
            a = dict(spec["aura"])
            a["life_max"] = max(L["lifetime"][1] for L in spec["layers"])
            data["aura"] = {k: (list(v) if isinstance(v, tuple) else v) for k, v in a.items()}
            data["aura"]["outline"] = [list(c) for c in a["outline"]]
        if spec.get("beams"):
            data["beams"] = [norm_beam(B) for B in spec["beams"]]
        if spec.get("blade"):
            data["blade"] = norm_blade(spec["blade"])
        if spec.get("field"):
            data["field"] = norm_field(spec["field"])
        if spec.get("front"):
            data["front"] = norm_front(spec["front"])
        if spec.get("zbeams"):
            data["zbeams"] = [norm_zbeam(B) for B in spec["zbeams"]]
        if spec.get("zfield"):
            data["zfield"] = norm_zfield(spec["zfield"])
        if spec.get("lights"):
            data["lights"] = [plain(Lt) for Lt in spec["lights"]]
        out += f"local SPEC_{key} = " + lua(data) + "\n\n"
        doc_k = spec.get("doc", "")
        head = f"-- {doc_k}\n" if doc_k else ""
        if spec.get("rocks"):
            out += head + \
                "-- rocks = las rocas del rayo: lista de Vector3 (punto del suelo) o de las Parts/Models de las rocas.\n" \
                "-- Todas detonan en el instante de la llamada; el pilar gigante sale en la roca más lejana.\n" + \
                f"function KaijuFireVFX.{key}(rocks: {{ any }}, scale: number?, shake: number?): Part?\n" \
                f"\treturn playRocks(SPEC_{key}, rocks, scale, shake)\nend\n\n"
        elif spec.get("cone"):
            c = spec["cone"]
            out += head + \
                f"-- length = largo del triángulo en studs (por defecto {c['length']} × escala); " \
                f"angle = apertura en grados (por defecto {c['angle']}).\n" + \
                f"function KaijuFireVFX.{key}(cf: CFrame, length: number?, angle: number?, scale: number?, shake: number?): Part\n" \
                f"\treturn play(SPEC_{key}, cf, scale, length or {c['length']} * (scale or 1), shake, angle or {c['angle']})\nend\n\n"
        elif spec.get("beam"):
            b = spec["beam"]
            hit = round(b["start"] + b["grow"], 3)
            out += head + \
                "-- origin = de dónde sale: un Attachment en la boca (lo sigue solo), una Part, un Vector3 o un CFrame.\n" \
                "-- target = hacia dónde apunta: el rival (Model o Part: lo sigue solo) o un punto (Vector3 o CFrame).\n" \
                "-- ignore = lo que el rayo atraviesa (el modelo de quien lo lanza). Se corta en la primera superficie\n" \
                f"-- que toca y nunca pasa de su largo máximo ({b['max_len']:g} studs × escala). Devuelve un control:\n" \
                "--   rayo:AimAt(objetivo)     apunta a otro lado (Model, Part, Vector3 o CFrame; si se mueve, lo sigue)\n" \
                "--   rayo:SetDirection(dir)   apunta en una dirección (Vector3)\n" \
                "--   rayo:SetOrigin(origen)   cambia de dónde sale\n" \
                "--   rayo:Stop()              lo corta antes de tiempo\n" \
                "--   rayo.MaxLength           largo máximo (lo puedes cambiar); rayo.Length = largo de ahora\n" \
                "--   rayo.HitPosition, rayo.HitInstance = dónde y qué está tocando (nil si no toca nada)\n" \
                "--   rayo.Active = true mientras se ve; rayo.Holder = la Part que lo contiene\n" + \
                f"function KaijuFireVFX.{key}(origin: any, target: any, scale: number?, shake: number?, " \
                f"ignore: {{ Instance }}?): BeamControl\n" \
                f"\treturn playBeam(SPEC_{key}, origin, target, scale, shake, ignore)\nend\n" \
                "-- segundos (desde la llamada) en que llega a su largo máximo y en que se corta solo\n" \
                f"KaijuFireVFX.{key}Start = {hit:g}\nKaijuFireVFX.{key}Stop = {b['stop']:g}\n\n"
        elif spec.get("cataclysm"):
            c = spec["cataclysm"]
            T = c["t"]
            imp = spec["impact"]
            Vc = c["victims"]
            times = {"Vortex": c["phases"][1][1], "Singularity": c["phases"][2][1], "Consumption": c["phases"][3][1],
                     "VictimsLifted": T["victims"][0], "VictimsHeld": T["victims"][1], "CriticalMass": T["crit"][0],
                     "Flash": c["flash"][1], "Detonation": T["det"], "FirstImpact": round(T["det"] + Vc["fall"], 3),
                     "Aftermath": c["phases"][7][1], "End": T["end"]}
            out += head + \
                "-- epicenter = el epicentro: el Model de Omnívora (o su HumanoidRootPart), una Part, un Vector3 o un CFrame;\n" \
                "--   se busca el suelo debajo. victims = los kaijus atrapados: lista de Models (o Parts, Vector3, CFrame).\n" \
                "--   Cada uno sube a la singularidad y se estrella contra el suelo en su punto.\n" \
                "-- options (todo opcional):\n" \
                f"--   Radius = radio en studs (por defecto {c['radius']:g} = 500 m con 1 stud = 0.28 m); todo se escala con él\n" \
                f"--   Height = altura de la singularidad sobre el epicentro (por defecto {c['height']:g} × Radius / {c['radius']:g})\n" \
                "--   Shake = intensidad de la sacudida (1; 0 = sin sacudida)\n" \
                "--   MoveVictims = true: el efecto mueve los modelos de las víctimas por su recorrido (pruebas o modelos anclados)\n" \
                "--   ImpactPoints = { Vector3 }: el punto del suelo donde cae cada víctima (por defecto, donde estaba)\n" \
                "--   AutoImpacts = false: no dibuja los impactos (llámalos tú con " + imp + ")\n" \
                "--   StartTime = segundo en que empieza (para revisar una fase); Flash = false: sin el destello blanco\n" \
                "--   Caster = el modelo de Omnívora (lo ignora al buscar el suelo)\n" \
                "--   OnEvent = function(nombre, ...): \"Phase\" (nombre, i), \"VictimLift\" (víctima, i), \"VictimLaunch\"\n" \
                "--     (víctima, i), \"Detonation\" (posición), \"VictimImpact\" (víctima, i, punto), \"Finished\"\n" \
                "-- Devuelve un control: .Time, .Phase, .Active, .Center, .Singularity, .SingularityRadius,\n" \
                "--   :GetVictimCFrame(víctima, t?), :GetImpactPoint(víctima), :Stop()\n" + \
                f"function KaijuFireVFX.{key}(epicenter: any, victims: any, options: {{ [string]: any }}?): CataclysmControl\n" \
                f"\treturn playCataclysm(SPEC_{key}, SPEC_{imp}, epicenter, victims, options)\nend\n" \
                "-- el mismo recorrido de las víctimas, sin efectos: para el servidor (moverlas, el daño). Mismas options.\n" \
                "-- :GetVictimCFrame(víctima, t), :GetImpactPoint(víctima), :GetVictimTimes(víctima) -> {Lift, Held, Launch, Impact}\n" + \
                f"function KaijuFireVFX.{key}Plan(epicenter: any, victims: any, options: {{ [string]: any }}?): CataclysmPlanControl\n" \
                f"\treturn planCataclysm(SPEC_{key}, epicenter, victims, options)\nend\n" \
                "-- segundos (desde la llamada) en que empieza cada momento\n" + \
                f"KaijuFireVFX.{key}Times = " + lua(times) + "\n\n"
        elif spec.get("silhouette"):
            sc = spec["silhouette"]
            out += head + \
                "-- model = el modelo (Model o Part). El aura sale del CONTORNO del modelo visto desde la cámara de cada\n" \
                f"-- jugador y lo sigue si se mueve ({sc['ref']:g} studs de alto = tamaño 1; scale lo multiplica).\n" \
                "-- duration = segundos que dura (nil = hasta que la apagues); intensity = 1 normal. Devuelve un control:\n" \
                "--   aura:Stop(fade)          la apaga (se desvanece en fade s; nil = el de siempre)\n" \
                "--   aura:SetIntensity(k)     más fuerte o más suave mientras dura\n" \
                "--   aura.Active = true mientras se ve; aura.Holder = la Part que la contiene\n" + \
                f"function KaijuFireVFX.{key}(model: Instance, scale: number?, duration: number?, intensity: number?): AuraControl\n" \
                f"\treturn playSilhouette(SPEC_{key}, model, scale, duration, intensity)\nend\n\n"
        elif spec.get("aura"):
            a = spec["aura"]
            out += head + \
                "-- model = el modelo (Model o Part): el aura se adapta sola a su forma y a su tamaño y lo sigue si se mueve\n" \
                f"-- ({a['ref']:g} studs de alto = tamaño 1; scale lo multiplica). duration = segundos que dura (nil = hasta que la\n" \
                "-- apagues); intensity = 1 normal (0.5 suave, 1.5 fuerte). Devuelve un control:\n" \
                "--   aura:Stop(fade)          la apaga (se desvanece en fade s; nil = el de siempre)\n" \
                "--   aura:SetIntensity(k)     más fuerte o más suave mientras dura\n" \
                "--   aura.Active = true mientras se ve; aura.Holder = la Part que la contiene\n" + \
                f"function KaijuFireVFX.{key}(model: Instance, scale: number?, duration: number?, intensity: number?): AuraControl\n" \
                f"\treturn playAura(SPEC_{key}, model, scale, duration, intensity)\nend\n\n"
        elif spec.get("hit"):
            h = spec["hit"]
            out += head + \
                "-- target = el rival (Model, Part, Vector3 o CFrame). El golpe sale delante de lo que ve la cámara y mira\n" \
                f"-- hacia ella. Con un Model o una Part se adapta al alto del rival ({h['ref']:g} studs = tamaño 1; " \
                "scale lo multiplica).\n"
            if h.get("angled"):
                out += f"-- angle = inclinación del corte en grados (por defecto {h['angle']:g}: en diagonal, de arriba a la izquierda\n" \
                    "-- a abajo a la derecha). 0 = vertical, -35 = la otra diagonal (de arriba a la derecha a abajo a la\n" \
                    "-- izquierda), 90 = horizontal.\n" + \
                    f"function KaijuFireVFX.{key}(target: any, scale: number?, shake: number?, angle: number?): Part\n" \
                    f"\treturn playHit(SPEC_{key}, target, scale, shake, angle)\nend\n"
            else:
                out += f"function KaijuFireVFX.{key}(target: any, scale: number?, shake: number?): Part\n" \
                    f"\treturn playHit(SPEC_{key}, target, scale, shake, 0)\nend\n"
            out += "-- segundo (desde la llamada) en que el golpe conecta: para sincronizar el número de daño o el sonido\n" \
                f"KaijuFireVFX.{key}Impact = {h['impact']:g}\n\n"
        elif spec.get("orb"):
            o = spec["orb"]
            out += head + \
                "-- mouth = la boca (Vector3 o CFrame): ahí se forma. targets = un enemigo o una lista (Vector3, BasePart\n" \
                "-- o Model): detona en medio de ellos y la explosión los cubre a todos. radius = radio de la detonación\n" \
                f"-- (si no, se calcula con los enemigos: mínimo {o['min_radius'] * spec.get('scale_mult', 1):g} × escala). " \
                f"Detona a los " \
                f"{o['collapse'][1]:g} s (ver {key}Impact).\n" + \
                f"function KaijuFireVFX.{key}(mouth: Vector3 | CFrame, targets: any, scale: number?, shake: number?, " \
                f"radius: number?): Part\n" \
                f"\treturn playOrb(SPEC_{key}, mouth, targets, scale, shake, radius)\nend\n" \
                f"-- segundo (desde la llamada) en que detona: para sincronizar el daño\n" \
                f"KaijuFireVFX.{key}Impact = {o['collapse'][1]:g}\n\n"
        elif spec.get("zone"):
            z = spec["zone"]
            out += head + \
                f"-- radius = radio de la zona en studs (por defecto {z['radius']:g} × escala); " \
                f"height = altura del pilar (por defecto {z['height']:g} × escala).\n" + \
                f"function KaijuFireVFX.{key}(cf: CFrame, radius: number?, height: number?, scale: number?, shake: number?): Part\n" \
                f"\treturn playZone(SPEC_{key}, cf, scale, radius, height, shake)\nend\n\n"
            if spec.get("times"):
                out += "-- segundos (desde la llamada) de cada momento: para sincronizar el daño, el sonido o la cámara\n" + \
                    f"KaijuFireVFX.{key}Times = " + lua(spec["times"]) + "\n\n"
        elif spec.get("blade"):
            B = spec["blade"]
            out += head + \
                f"-- cf = el punto del suelo de donde sale, mirando hacia donde va. length = cuánto recorre (por defecto " \
                f"{spec['line']} × escala).\n" + \
                f"function KaijuFireVFX.{key}(cf: CFrame, length: number?, scale: number?, shake: number?): Part\n" \
                f"\treturn playBlade(SPEC_{key}, cf, scale, length or {spec['line']} * (scale or 1), shake)\nend\n" \
                "-- segundo (desde la llamada) en que llega al final y detona: para sincronizar el daño\n" \
                f"KaijuFireVFX.{key}Impact = {round(B['t0'] + B['travel'], 3):g}\n\n"
        elif spec.get("line"):
            out += head + \
                f"-- length = largo de la línea en studs (por defecto {spec['line']} × escala).\n" + \
                f"function KaijuFireVFX.{key}(cf: CFrame, length: number?, scale: number?, shake: number?): Part\n" \
                f"\treturn play(SPEC_{key}, cf, scale, length or {spec['line']} * (scale or 1), shake)\nend\n\n"
        else:
            out += head + \
                f"function KaijuFireVFX.{key}(cf: CFrame, scale: number?, shake: number?): Part\n" \
                f"\treturn play(SPEC_{key}, cf, scale, nil, shake)\nend\n\n"
    out += "return KaijuFireVFX\n"
    if any(spec.get("cubes") for spec in specs.values()):
        out = out.replace("KaijuFireVFX.UseLight = true\n", "KaijuFireVFX.UseLight = true\n"
                          "-- Color y material de los cubos de destrucción (nil = los del suelo donde sale el efecto)\n"
                          "KaijuFireVFX.CubeColor = nil :: Color3?\n"
                          "KaijuFireVFX.CubeMaterial = nil :: Enum.Material?\n", 1)
    if any(spec.get("hit") for spec in specs.values()):
        out = out.replace("KaijuFireVFX.UseLight = true\n", "KaijuFireVFX.UseLight = true\n"
                          "-- Los golpes (corte, mordisco) se adaptan al alto del rival si le pasas su Model o su Part\n"
                          "KaijuFireVFX.HitAutoSize = true\n", 1)
    if any(spec.get("screen") for spec in specs.values()):
        out = out.replace("KaijuFireVFX.UseLight = true\n", "KaijuFireVFX.UseLight = true\n"
                          "-- Las ULTIMATES oscurecen el mundo y hacen destellar la pantalla de quien está cerca (solo en el cliente)\n"
                          "KaijuFireVFX.ScreenFX = true\n", 1)
    if any(spec.get("orb") for spec in specs.values()):
        out = out.replace("KaijuFireVFX.UseLight = true\n", "KaijuFireVFX.UseLight = true\n"
                          "-- Lente de vidrio que distorsiona el fondo detrás del agujero negro (solo con gráficos altos)\n"
                          "KaijuFireVFX.Lens = true\n", 1)
    out = prefix_unused(out)
    return out.replace("KaijuFireVFX", name), tex


REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main(out_kaiju, out_astral=None, out_omnivora=None, out_moonfang=None):
    """Genera los módulos: KaijuFireVFX (Kaiju Zero), AstralColossusVFX (Astral Colossus), OmnivoraVFX (Omnívora) y
    MoonfangVFX (Moonfang)."""
    import vfx_astral as VA
    import vfx_omnivora as VO
    import vfx_moonfang as VM
    out_astral = out_astral or os.path.join(REPO, "AstralColossus_VFX", "roblox")
    out_omnivora = out_omnivora or os.path.join(REPO, "Omnivora_VFX", "roblox")
    out_moonfang = out_moonfang or os.path.join(REPO, "Moonfang_VFX", "roblox")
    for out, specs, name, doc in ((out_kaiju, SP.SPECS, "KaijuFireVFX", DOC_KAIJU),
                                  (out_astral, VA.SPECS, "AstralColossusVFX", DOC_ASTRAL),
                                  (out_omnivora, VO.SPECS, "OmnivoraVFX", DOC_OMNIVORA),
                                  (out_moonfang, VM.SPECS, "MoonfangVFX", DOC_MOONFANG)):
        os.makedirs(out, exist_ok=True)
        src, tex = build(specs, name, doc)
        write_outputs(out, src, tex, name)
        print("OK", name, len(src.splitlines()), "líneas;", len(tex), "texturas ->", os.path.relpath(out, REPO))


def write_outputs(OUT, src, TEX, name="KaijuFireVFX"):
    with open(os.path.join(OUT, name + ".lua"), "w") as f:
        f.write(src)
    rbxmx = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
             'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
             'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
             '\t<Item class="ModuleScript" referent="RBX0">\n\t\t<Properties>\n'
             f'\t\t\t<string name="Name">{name}</string>\n'
             '\t\t\t<ProtectedString name="Source"><![CDATA[' + src + ']]></ProtectedString>\n'
             '\t\t</Properties>\n\t</Item>\n</roblox>\n')
    with open(os.path.join(OUT, name + ".rbxmx"), "w") as f:
        f.write(rbxmx)
    with open(os.path.join(OUT, "texturas_necesarias.txt"), "w") as f:
        f.write("\n".join(t + ".png" for t in TEX) + "\n")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
