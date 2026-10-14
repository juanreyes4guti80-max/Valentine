"""Genera el ModuleScript Luau (y un .rbxmx insertable) desde vfx_specs.py.
uso: python gen_luau.py <outdir>"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vfx_specs as SP

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
            items.append(pad + "\t" + k + " = " + lua(x, ind + 1))
        return "{\n" + ",\n".join(items) + ",\n" + pad + "}"
    raise TypeError(type(v))


def norm_layer(L):
    """Rellena valores por defecto y traduce el flipbook 'estático aleatorio'."""
    assert "points" not in L, f"{L['name']}: 'points' no está soportado en el módulo; usa 'emit' con (t, n, u, lado, alto)"
    o = dict(L)
    for k in ("rock_emit", "rock_stream"):
        if k in o:
            o[k] = [[list(e) for e in var] for var in o[k]]
    for k in ("final_emit", "final_stream"):
        if k in o:
            o[k] = [list(e) for e in o[k]]
    if o.get("type") == "meteor":
        o.setdefault("spread", (0, 0))
        o.setdefault("direction", "Top")
        o.setdefault("accel", (0, -100, 0))
        o.setdefault("drag", 0)
        o.setdefault("offset", (0, 0, 0))
        o["emit"] = [list(e) for e in o.get("emit", [])]
        sp = dict(o["sprite"])
        o["rock"] = {"size": list(sp["size"]), "spin": list(sp.get("rot_speed", (0, 0))),
                     "color": list(sp.get("color", (95, 78, 70)))}
        del o["sprite"]
        o["trails"] = [norm_layer(T) for T in o.get("trails", [])]
        o["land"] = [norm_layer(T) for T in o.get("land", [])]
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
    fb = o.get("flipbook")
    if fb:
        layout, mode, fps, start_random = fb
        if mode == "Random" and fps <= 0:      # frame aleatorio fijo por partícula
            mode, fps = "Loop", 0.001
        o["flipbook"] = {"layout": layout, "mode": mode, "fps": fps, "startRandom": bool(start_random)}
    sh = o.get("shape")
    if sh:
        if sh["type"] == "Box":
            o["shape"] = {"type": "Box", "size": list(sh["size"]), "style": sh.get("style", "Volume")}
        else:
            o["shape"] = {"type": sh["type"], "radius": sh["radius"], "style": sh.get("style", "Volume")}
    return o


def layer_end(L, jitter=0.0):
    """Momento (s) en que muere la última partícula de la capa (cota superior para las rocas).
    jitter = retraso aleatorio máximo por roca (efectos sobre rocas)."""
    life = L.get("lifetime", (0, 0))[1]
    starts = [ev[0] for ev in L.get("emit", [])]
    starts += [ev[0] + jitter for var in L.get("rock_emit", []) for ev in var]
    starts += [ev[0] + jitter for ev in L.get("final_emit", [])]
    if L.get("type") == "meteor":
        after = 0.0
        for T in L.get("trails", []):
            after = max(after, T["lifetime"][1])
        for T in L.get("land", []):
            after = max(after, T["lifetime"][1] + max([w[1] for w in T.get("stream", [])] + [0]))
        life += after
    ends = [t + life for t in starts]
    delays = [0.0] if not (L.get("rock_stream") or L.get("final_stream")) else \
        [src[0] + jitter for var in L.get("rock_stream", []) for src in var] + \
        [src[0] + jitter for src in L.get("final_stream", [])]
    ends += [d + w[1] + life for w in L.get("stream", []) for d in delays]
    return max(ends) if ends else 0.0


def spec_end(spec):
    jit = spec.get("rocks", {}).get("jitter", 0.0)
    return max(layer_end(L, jit) for L in spec["layers"])


def textures_of(layers):
    out = set()
    for L in layers:
        if "texture" in L:
            out.add(L["texture"])
        for k in ("trails", "land"):
            out |= textures_of(L.get(k, []))
    return out


HEADER = r'''--!nonstrict
--[[
	KaijuFireVFX — VFX de fuego para KAIJU ZERO
	(generado automáticamente desde vfx_specs.py; edita allí y regenera)

	USO (en el CLIENTE, por ejemplo al recibir un RemoteEvent del servidor):
		local KaijuFireVFX = require(ReplicatedStorage.KaijuFireVFX)
		-- cf = punto del SUELO bajo la explosión; 1 = escala; 1 = intensidad de la sacudida de cámara
		KaijuFireVFX.GiantExplosion(CFrame.new(puntoEnElSuelo), 1, 1)

	ANTES DE USARLO:
	  1) Sube las imágenes de la carpeta textures/ (Asset Manager > Images > Bulk Import).
	  2) Clic derecho en cada imagen > "Copy ID to clipboard" y pégalo en TEXTURES.
	     (Usa el ID de la IMAGEN, no el de un Decal.)

	CIERRE LIMPIO:
	  - Ráfagas con Emit(); la emisión continua (fuego en el suelo) baja su Rate hasta 0.
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
-- Luz naranja breve en el impacto
KaijuFireVFX.UseLight = true

type Layer = { [string]: any }

local rng = Random.new()

local function numberSeq(points: { { number } }, scale: number): NumberSequence
	local kps = table.create(#points)
	for i, p in points do
		local v = math.max(p[2] * scale, 0)
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
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	end
	return e
end

-- posición local de un punto de la línea: u = fracción del largo (hacia adelante = -Z), lado, alto
local function linePos(u: number, side: number, up: number, scale: number, len: number): Vector3
	return Vector3.new(side * scale, up * scale, -u * len)
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
	e.Parent = carrier
	return e, carrier
end

-- emisión continua: Rate interpolado por ventanas {t0, t1, rate0, rate1}
local function runStream(L: Layer, e: ParticleEmitter, delayStart: number?)
	local tEnd = 0
	for _, w in L.stream do
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
			for _, w in L.stream do
				if t >= w[1] and t <= w[2] then
					rate += w[3] + (w[4] - w[3]) * (t - w[1]) / math.max(w[2] - w[1], 1e-3)
				end
			end
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

-- elemento plano del suelo hecho con Decal (sin límite de tamaño); baseCF = dónde va (horizontal)
local function playDecalAt(L: Layer, holder: BasePart, scale: number, n: number, baseCF: CFrame)
	for _ = 1, n do
		local life = rng:NextNumber(L.lifetime[1], L.lifetime[2])
		local rot = math.rad(rng:NextNumber(L.rotation[1], L.rotation[2]))
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
			p.CFrame = cf
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
local function landAt(L: Layer, holder: BasePart, s: number, worldPos: Vector3)
	local localPos = holder.CFrame:PointToObjectSpace(worldPos)
	for _, LL in L.land do
		local e = buildEmitter(LL, holder, s, localPos)
		if LL.stream then
			runStream(LL, e)
		else
			e:Emit(quality(LL.emit[1][2]))
		end
	end
end

-- lanza n rocas desde pos; groundY = altura del suelo donde caen
local function launchMeteors(L: Layer, holder: BasePart, s: number, n: number, pos: Vector3, groundY: number)
	local accel = Vector3.new(L.accel[1], L.accel[2], L.accel[3]) * s
	local baseDir = ({
		Top = Vector3.yAxis, Bottom = -Vector3.yAxis, Front = -Vector3.zAxis, Back = Vector3.zAxis,
		Right = Vector3.xAxis, Left = -Vector3.xAxis,
	} :: any)[L.direction]
	local list = {}
	for i = 1, n do
		local spread = CFrame.Angles(math.rad(rng:NextNumber(-L.spread[1], L.spread[1])), 0,
			math.rad(rng:NextNumber(-L.spread[2], L.spread[2])))
		local dir = holder.CFrame:VectorToWorldSpace((spread :: CFrame):VectorToWorldSpace(baseDir))
		local sz = rng:NextNumber(L.rock.size[1], L.rock.size[2]) * s
		local rock = Instance.new("Part")
		rock.Name = "Rock"
		rock.Anchored = true
		rock.CanCollide = false
		rock.CanQuery = false
		rock.CanTouch = false
		rock.CastShadow = false
		rock.Material = Enum.Material.Slate
		rock.Color = Color3.fromRGB(L.rock.color[1], L.rock.color[2], L.rock.color[3])
		rock.Size = Vector3.new(sz, sz * 0.8, sz * 0.9)
		rock.CFrame = CFrame.new(pos)
		rock.Parent = holder
		local att = Instance.new("Attachment")
		att.Parent = rock
		local emitters = {}
		for _, TL in L.trails do
			local te = configureEmitter(TL, s)
			te.Rate = TL.rate * KaijuFireVFX.Quality
			te.Enabled = true
			te.Parent = att
			table.insert(emitters, te)
		end
		local spin = math.rad(rng:NextNumber(L.rock.spin[1], L.rock.spin[2]))
		list[i] = {
			rock = rock, pos = pos, vel = dir * rng:NextNumber(L.speed[1], L.speed[2]) * s,
			age = 0, life = rng:NextNumber(L.lifetime[1], L.lifetime[2]),
			rot = CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0),
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
				m.rock.Transparency = 1
				if m.pos.Y <= groundY + 0.6 * s then
					landAt(L, holder, s, Vector3.new(m.pos.X, groundY + 0.4 * s, m.pos.Z))
				end
			end
		end
		if alive == 0 then
			conn:Disconnect()
		end
	end)
end

local function playMeteors(L: Layer, holder: BasePart, s: number, len: number)
	local groundY = holder.Position.Y
	for _, ev in L.emit do
		local n = quality(ev[2])
		local startOff = Vector3.new(L.offset[1], L.offset[2], L.offset[3]) * s
		if ev[3] ~= nil then
			startOff += linePos(ev[3], ev[4], ev[5], s, len)
		end
		task.delay(ev[1], function()
			if holder.Parent then
				launchMeteors(L, holder, s, n, holder.CFrame:PointToWorldSpace(startOff), groundY)
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

-- Sacudida de cámara (solo cliente). intensity ~ 0.5 (suave) .. 2 (fuerte)
function KaijuFireVFX.Shake(intensity: number, duration: number?)
	if not RunService:IsClient() then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local dur = duration or 0.9
	local t0 = time()
	local name = "KZShake" .. tostring(rng:NextInteger(1, 1000000000))
	local seed = rng:NextNumber(0, 1000)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local t = time() - t0
		if t > dur then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local a = intensity * math.exp(-t / (dur * 0.35))
		local rx = math.noise(seed, t * 24) * a * 0.03
		local ry = math.noise(seed + 17, t * 24) * a * 0.03
		local rz = math.noise(seed + 31, t * 16) * a * 0.015
		cam.CFrame = cam.CFrame * CFrame.Angles(rx, ry, rz)
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
		if spec.shakes then
			-- {t, intensidad relativa, duración}
			for _, sk in spec.shakes do
				task.delay(sk[1], KaijuFireVFX.Shake, shake * sk[2], sk[3])
			end
		else
			KaijuFireVFX.Shake(shake, 0.9)
		end
	end
	-- se destruye cuando ya murió la última partícula (cleanup >= duración)
	Debris:AddItem(holder, spec.cleanup)
end

local function play(spec: Layer, cf: CFrame, scale: number?, length: number?, shake: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local len = length or 0
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf, KaijuFireVFX.Parent)
	for _, L in spec.layers do
		if L.type == "meteor" then
			playMeteors(L, holder, s, len)
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
		else
			local e, carrier = buildEmitter(L, holder, s, nil, len)
			if #L.emit > 0 then
				scheduleBursts(L, e, carrier, holder, s, len)
			end
			if L.stream then
				runStream(L, e)
			end
		end
	end
	-- en los efectos de línea, hasta 3 luces repartidas que se encienden al paso de la pared
	local lights: { { pos: Vector3, t: number } } = {}
	local n = if len > 0 then math.clamp(math.ceil(len / 50), 1, 3) else 1
	for i = 1, n do
		local u = if len > 0 then (i - 0.5) / n else 0
		local lp = if len > 0 then linePos(u, 0, 4, s, len) else Vector3.zero
		table.insert(lights, { pos = holder.CFrame:PointToWorldSpace(lp), t = (spec.light and spec.light.sweep or 0) * u })
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

'''


def build():
    tex = sorted(set().union(*(textures_of(spec["layers"]) for spec in SP.SPECS.values())))
    tex_lines = "\n".join(f'\t{t} = "rbxassetid://0",' for t in tex)
    out = HEADER.replace("__TEXTURES__", tex_lines)
    for key, spec in SP.SPECS.items():
        data = {"name": spec["name"], "duration": spec["duration"],
                "cleanup": round(max(spec["duration"], spec_end(spec)) + 0.3, 2),
                "layers": [norm_layer(L) for L in spec["layers"]]}
        if spec.get("shakes"):
            data["shakes"] = [list(x) for x in spec["shakes"]]
        if spec.get("rocks"):
            data["rocks"] = spec["rocks"]
        if spec.get("scale_mult"):
            data["scale_mult"] = spec["scale_mult"]
        if spec.get("light"):
            data["light"] = spec["light"]
        out += f"local SPEC_{key} = " + lua(data) + "\n\n"
        doc = spec.get("doc", "")
        if spec.get("rocks"):
            out += (f"-- {doc}\n" if doc else "") + \
                "-- rocks = las rocas del rayo: lista de Vector3 (punto del suelo) o de las Parts/Models de las rocas.\n" \
                "-- Todas detonan en el instante de la llamada; el pilar gigante sale en la roca más lejana.\n" + \
                f"function KaijuFireVFX.{key}(rocks: {{ any }}, scale: number?, shake: number?): Part?\n" \
                f"\treturn playRocks(SPEC_{key}, rocks, scale, shake)\nend\n\n"
        elif spec.get("line"):
            out += (f"-- {doc}\n" if doc else "") + \
                f"-- length = largo de la línea en studs (por defecto {spec['line']} × escala).\n" + \
                f"function KaijuFireVFX.{key}(cf: CFrame, length: number?, scale: number?, shake: number?): Part\n" \
                f"\treturn play(SPEC_{key}, cf, scale, length or {spec['line']} * (scale or 1), shake)\nend\n\n"
        else:
            out += (f"-- {doc}\n" if doc else "") + \
                f"function KaijuFireVFX.{key}(cf: CFrame, scale: number?, shake: number?): Part\n" \
                f"\treturn play(SPEC_{key}, cf, scale, nil, shake)\nend\n\n"
    out += "return KaijuFireVFX\n"
    return out, tex


def main(out):
    os.makedirs(out, exist_ok=True)
    src, tex = build()
    write_outputs(out, src, tex)
    print("OK", len(src.splitlines()), "líneas;", len(tex), "texturas")


def write_outputs(OUT, src, TEX):
    with open(os.path.join(OUT, "KaijuFireVFX.lua"), "w") as f:
        f.write(src)
    rbxmx = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
             'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
             'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
             '\t<Item class="ModuleScript" referent="RBX0">\n\t\t<Properties>\n'
             '\t\t\t<string name="Name">KaijuFireVFX</string>\n'
             '\t\t\t<ProtectedString name="Source"><![CDATA[' + src + ']]></ProtectedString>\n'
             '\t\t</Properties>\n\t</Item>\n</roblox>\n')
    with open(os.path.join(OUT, "KaijuFireVFX.rbxmx"), "w") as f:
        f.write(rbxmx)
    with open(os.path.join(OUT, "texturas_necesarias.txt"), "w") as f:
        f.write("\n".join(t + ".png" for t in TEX) + "\n")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
