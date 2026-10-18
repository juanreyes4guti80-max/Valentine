--!nonstrict
--[[
	OmnivoraVFX — VFX cósmicos (el vacío: violeta profundo, azul índigo y negro estelar) para OMNÍVORA
	(generado automáticamente desde vfx_omnivora.py; edita allí y regenera)

	USO (en el CLIENTE, por ejemplo al recibir un RemoteEvent del servidor):
		local OmnivoraVFX = require(ReplicatedStorage.OmnivoraVFX)
		-- cf = centro de la zona en el SUELO; radio y altura del pilar en studs; escala; sacudida
		OmnivoraVFX.CosmicPillar(CFrame.new(centroEnElSuelo), 18, 120, 1, 1)

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

local OmnivoraVFX = {}

-- Pega aquí los IDs de las imágenes subidas
OmnivoraVFX.TEXTURES = {
	fx_aurora = "rbxassetid://0",
	fx_beam = "rbxassetid://0",
	fx_beam_wavy = "rbxassetid://0",
	fx_electric_ball = "rbxassetid://0",
	fx_glow = "rbxassetid://0",
	fx_halo = "rbxassetid://0",
	fx_laser_thin = "rbxassetid://0",
	fx_particle02 = "rbxassetid://0",
	fx_spark002 = "rbxassetid://0",
	fx_spikes = "rbxassetid://0",
	fx_swirl_rings = "rbxassetid://0",
	fx_thunder = "rbxassetid://0",
	fx_wind_swirl = "rbxassetid://0",
	kk_circle_01 = "rbxassetid://0",
	kk_circle_02 = "rbxassetid://0",
	kk_light_03 = "rbxassetid://0",
	kk_smoke_04 = "rbxassetid://0",
	kk_smoke_07 = "rbxassetid://0",
	kk_spark_03 = "rbxassetid://0",
	kk_spark_04 = "rbxassetid://0",
	kk_spark_05 = "rbxassetid://0",
	kk_spark_06 = "rbxassetid://0",
	kk_star_06 = "rbxassetid://0",
	kk_star_08 = "rbxassetid://0",
	kk_star_09 = "rbxassetid://0",
	kk_trace_01 = "rbxassetid://0",
	kk_trace_03 = "rbxassetid://0",
	kk_trace_04 = "rbxassetid://0",
	kk_trace_06 = "rbxassetid://0",
	kk_twirl_01 = "rbxassetid://0",
	kk_twirl_02 = "rbxassetid://0",
	kz_scorch = "rbxassetid://0",
	om_cracks = "rbxassetid://0",
	om_cubes_2x2 = "rbxassetid://0",
	om_nebula_2x2 = "rbxassetid://0",
}

-- Dónde se crean los efectos (puedes cambiarlo por una carpeta de VFX)
OmnivoraVFX.Parent = workspace :: Instance
-- Multiplicador de cantidad de partículas (bájalo en dispositivos lentos, p.ej. 0.6)
OmnivoraVFX.Quality = 1
-- Luz breve en el impacto (del color del efecto)
OmnivoraVFX.UseLight = true
-- Color y material de los cubos de destrucción (nil = los del suelo donde sale el efecto)
OmnivoraVFX.CubeColor = nil :: Color3?
OmnivoraVFX.CubeMaterial = nil :: Enum.Material?

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
	e.Texture = OmnivoraVFX.TEXTURES[L.texture] or ""
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
local function runStream(L: Layer, e: ParticleEmitter, delayStart: number?, windows: { any }?, mul: number?)
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
			rate *= mul or 1
			e.Rate = rate * OmnivoraVFX.Quality
			e.Enabled = rate > 0.05
			task.wait(0.05)
		end
		if e.Parent then
			e.Enabled = false
		end
	end)
end

local function quality(n: number): number
	return math.max(1, math.floor(n * OmnivoraVFX.Quality + 0.5))
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
		local spin = math.rad(rng:NextNumber(L.rot_speed[1], L.rot_speed[2]))
		local cf = baseCF * CFrame.Angles(0, rot, 0)
		local p = invisiblePart(L.name, Vector3.new(0.1, 0.05, 0.1), cf, holder)
		-- los Decals no tienen LightEmission: un Color3 mayor que 1 los hace brillar (con Bloom)
		local glow = 1 + 1.5 * (L.light_emission or 0)
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Top
		d.Texture = OmnivoraVFX.TEXTURES[L.texture] or ""
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
local function landAt(L: Layer, holder: BasePart, s: number, worldPos: Vector3)
	local localPos = holder.CFrame:PointToObjectSpace(worldPos)
	for _, LL in L.land do
		if LL.decal then
			playDecalAt(LL, holder, s, LL.emit[1][2], holder.CFrame.Rotation + worldPos)
			continue
		end
		local e = buildEmitter(LL, holder, s, localPos)
		if LL.stream then
			runStream(LL, e)
		else
			e:Emit(quality(LL.emit[1][2]))
		end
	end
end

-- lanza n rocas desde pos; groundY = altura del suelo donde caen
local function launchMeteors(L: Layer, holder: BasePart, s: number, n: number, pos: Vector3, groundY: number, frame: CFrame?)
	local accel = Vector3.new(L.accel[1], L.accel[2], L.accel[3]) * s
	local baseDir = ({
		Top = Vector3.yAxis, Bottom = -Vector3.yAxis, Front = -Vector3.zAxis, Back = Vector3.zAxis,
		Right = Vector3.xAxis, Left = -Vector3.xAxis,
	} :: any)[L.direction]
	local list = {}
	for i = 1, n do
		local spread = CFrame.Angles(math.rad(rng:NextNumber(-L.spread[1], L.spread[1])), 0,
			math.rad(rng:NextNumber(-L.spread[2], L.spread[2])))
		local dir = (frame or holder.CFrame):VectorToWorldSpace((spread :: CFrame):VectorToWorldSpace(baseDir))
		local sz = rng:NextNumber(L.rock.size[1], L.rock.size[2]) * s
		local rock = Instance.new("Part")
		rock.Name = "Rock"
		rock.Anchored = true
		rock.CanCollide = false
		rock.CanQuery = false
		rock.CanTouch = false
		rock.CastShadow = false
		rock.Material = (Enum.Material :: any)[L.rock.material or "Slate"]
		rock.Color = Color3.fromRGB(L.rock.color[1], L.rock.color[2], L.rock.color[3])
		rock.Size = Vector3.new(sz, sz * 0.8, sz * 0.9)
		rock.CFrame = CFrame.new(pos)
		rock.Parent = holder
		local att = Instance.new("Attachment")
		att.Parent = rock
		local emitters = {}
		for _, TL in L.trails do
			local te = configureEmitter(TL, s)
			te.Rate = TL.rate * OmnivoraVFX.Quality
			te.LockedToPart = TL.locked == true -- p.ej. el resplandor de la roca fundida va pegado a ella
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
			acc[i] += rate * OmnivoraVFX.Quality * dt
			while acc[i] >= 1 do
				acc[i] -= 1
				placeCarrier(carrier, holder, src.pos)
				e:Emit(1)
			end
		end
	end)
end

-- Sacudida de cámara (solo cliente). intensity ~ 0.5 (suave) .. 2 (fuerte)
function OmnivoraVFX.Shake(intensity: number, duration: number?)
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

-- Sacudida continua que crece de i0 a i1 durante `duration` y se detiene al final (solo cliente).
-- power > 1 hace que crezca más hacia el final.
function OmnivoraVFX.ShakeRamp(i0: number, i1: number, duration: number, power: number?)
	if not RunService:IsClient() then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local t0 = time()
	local pw = power or 1
	local name = "KZShakeRamp" .. tostring(rng:NextInteger(1, 1000000000))
	local seed = rng:NextNumber(0, 1000)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local t = time() - t0
		if t > duration then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local a = i0 + (i1 - i0) * (t / duration) ^ pw
		local rx = math.noise(seed, t * 24) * a * 0.03
		local ry = math.noise(seed + 17, t * 24) * a * 0.03
		local rz = math.noise(seed + 31, t * 16) * a * 0.015
		cam.CFrame = cam.CFrame * CFrame.Angles(rx, ry, rz)
	end)
end

-- luces, sacudida y limpieza (comunes a todos los efectos)
local function finish(spec: Layer, holder: BasePart, s: number, shake: number?, lights: { { pos: Vector3, t: number } })
	if OmnivoraVFX.UseLight and spec.light then
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
			task.delay(r[1], OmnivoraVFX.ShakeRamp, shake * r[3], shake * r[4], r[2] - r[1], r[5])
		end
		if spec.shakes then
			-- {t, intensidad relativa, duración}
			for _, sk in spec.shakes do
				task.delay(sk[1], OmnivoraVFX.Shake, shake * sk[2], sk[3])
			end
		elseif not spec.shake_ramp then
			OmnivoraVFX.Shake(shake, 0.9)
		end
	end
	-- se destruye cuando ya murió la última partícula (cleanup >= duración)
	Debris:AddItem(holder, spec.cleanup)
end

local function _play(spec: Layer, cf: CFrame, scale: number?, length: number?, shake: number?, angle: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local len = length or 0
	local tanH = math.tan(math.rad(math.clamp(angle or 60, 5, 170) / 2))
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf, OmnivoraVFX.Parent)
	for _, L in spec.layers do
		if L.cone_emit and L.type == "meteor" then
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
			table.insert(lights, { pos = holder.CFrame:PointToWorldSpace(lp), t = (spec.light and spec.light.sweep or 0) * u })
		end
	end
	finish(spec, holder, s, shake, lights)
	return holder
end

-- efecto sobre las rocas del juego: todas detonan a la vez (con una diferencia mínima)
local function _playRocks(spec: Layer, rocks: { any }, scale: number?, shake: number?): Part?
	if #rocks == 0 then
		return nil
	end
	local s = (scale or 1) * (spec.scale_mult or 1)
	local R, dir = rockLayout(spec, rocks, s)
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2),
		CFrame.lookAt(R[1].pos, R[1].pos + dir), OmnivoraVFX.Parent)
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

local GROUND_FALLBACK = Color3.fromRGB(112, 106, 112)

-- color y material del suelo en el centro de la zona (los cubos de destrucción salen de ahí)
local function groundLook(pos: Vector3, holder: Instance): (Color3, Enum.Material, number?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { holder }
	for _ = 1, 4 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
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
	return if L.hu == "H" then h * Z.H else h * zoneK(L, Z)
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
		acc += rate * mul * OmnivoraVFX.Quality * dt
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
	if not OmnivoraVFX.UseLight or not spec.lights then
		return
	end
	for _, Lt in spec.lights do
		task.delay(Lt.t, function()
			if not Z.holder.Parent then
				return
			end
			local a = Instance.new("Attachment")
			a.Name = "Light"
			a.Parent = Z.holder
			a.Position = Vector3.new(0, if Lt.hu == "H" then Lt.h * Z.H else Lt.h * Z.s, 0)
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
	local opts = OmnivoraVFX :: any
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

-- efecto en una zona circular: carga, erupción, pilar y colapso (+ cubos de destrucción)
local function playZone(spec: Layer, cf: CFrame, scale: number?, radius: number?, height: number?, shake: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local R = radius or spec.zone.radius * s
	local H = height or spec.zone.height * s
	-- la zona queda plana (solo se usa el giro horizontal de cf) y apoyada en el suelo
	local pos = cf.Position
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local flat = if look.Magnitude > 1e-3 then CFrame.lookAt(pos, pos + look) else CFrame.new(pos)
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), flat, OmnivoraVFX.Parent)
	local gColor, gMaterial, gy = groundLook(pos, holder)
	if gy and math.abs(gy - pos.Y) < 8 then
		holder.CFrame = flat + Vector3.new(0, gy - pos.Y, 0)
	end
	local Z: Zone = {
		holder = holder, R = R, H = H, s = s, kR = R / spec.zone.radius, kH = H / spec.zone.height,
		groundY = holder.Position.Y, groundColor = gColor, groundMaterial = gMaterial,
	}
	local spinners: { [number]: BasePart } = {}
	for _, L in spec.layers do
		if L.decal then
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
	zoneLights(spec, Z)
	finish(spec, holder, s, shake, {})
	return holder
end

local SPEC_CosmicPillar = {
	name = "CosmicPillar",
	duration = 3,
	cleanup = 4.34,
	layers = {
		{
			name = "ZoneRing",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.6, 0.6},
			size = {
				{0, 76.275, 0},
				{0.2, 61.02, 0},
				{1, 61.02, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.15, 0.12, 0},
				{0.8, 0.08, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 235, 255},
				},
				{
					0.4,
					{110, 180, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 0.8,
			ring_emit = {
				{0, 1, 0, 0, 0.14},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ZoneRingInner",
			texture = "kk_circle_01",
			rel = "r",
			lifetime = {0.6, 0.6},
			size = {
				{0, 54.8208, 0},
				{0.25, 45.684, 0},
				{1, 45.684, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.5, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{90, 150, 255},
				},
				{
					0.5,
					{50, 100, 230},
				},
				{
					1,
					{25, 50, 170},
				},
			},
			light_emission = 0.6,
			ring_emit = {
				{0.03, 1, 0, 0, 0.13},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ZoneVoid",
			texture = "fx_glow",
			rel = "r",
			lifetime = {3, 3},
			size = {
				{0, 10, 0},
				{0.2, 39.6, 0},
				{1, 41.4, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.12, 0.45, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{10, 16, 52},
				},
				{
					0.5,
					{6, 10, 40},
				},
				{
					1,
					{4, 6, 26},
				},
			},
			light_emission = 0,
			ring_emit = {
				{0.02, 1, 0, 0, 0.1},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ZoneCracks",
			texture = "om_cracks",
			rel = "r",
			lifetime = {3, 3},
			rotation = {0, 360},
			size = {
				{0, 13.5, 0},
				{0.15, 40.5, 0},
				{0.25, 45, 0},
				{1, 46.8, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.35, 0},
				{0.14, 0.2, 0},
				{0.16, 0.02, 0},
				{0.3, 0.15, 0},
				{0.8, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{90, 160, 255},
				},
				{
					0.15,
					{190, 230, 255},
				},
				{
					0.3,
					{80, 150, 255},
				},
				{
					1,
					{30, 60, 180},
				},
			},
			light_emission = 0.8,
			ring_emit = {
				{0.06, 1, 0, 0, 0.16},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ZoneSwirl",
			texture = "fx_wind_swirl",
			rel = "r",
			lifetime = {2.6, 2.6},
			rotation = {0, 360},
			rot_speed = {-200, -200},
			size = {
				{0, 28.8, 0},
				{0.15, 39.6, 0},
				{1, 41.4, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.12, 0.55, 0},
				{0.2, 0.35, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{40, 80, 210},
				},
				{
					0.5,
					{25, 50, 160},
				},
				{
					1,
					{12, 25, 100},
				},
			},
			light_emission = 0.7,
			ring_emit = {
				{0.1, 1, 0, 0, 0.18},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeIn",
			texture = "kk_trace_06",
			rel = "r",
			orientation = "VelocityParallel",
			direction = "Back",
			speed_r = {2.6, 3},
			lifetime = {0.33, 0.38},
			size = {
				{0, 2, 0},
				{0.3, 8, 0},
				{1, 3, 0},
			},
			transparency = {
				{0, 0.7, 0},
				{0.2, 0.1, 0},
				{0.85, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{40, 90, 230},
				},
				{
					0.6,
					{120, 190, 255},
				},
				{
					1,
					{240, 248, 255},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			ring_emit = {
				{0.02, 1, 0.0082, 1.08, 1.36},
				{0.02, 1, 0.0915, 1.08, 2.5},
				{0.02, 1, 0.1749, 1.08, 1.49},
				{0.02, 1, 0.2582, 1.08, 2.55},
				{0.02, 1, 0.3415, 1.08, 0.61},
				{0.02, 1, 0.4249, 1.08, 0.89},
				{0.02, 1, 0.5082, 1.08, 3.7},
				{0.02, 1, 0.5915, 1.08, 2.4},
				{0.02, 1, 0.6749, 1.08, 2.81},
				{0.02, 1, 0.7582, 1.08, 3.8},
				{0.02, 1, 0.8415, 1.08, 2.12},
				{0.02, 1, 0.9249, 1.08, 1.09},
				{0.075, 1, 0.0319, 1.08, 4.02},
				{0.075, 1, 0.1153, 1.08, 3.15},
				{0.075, 1, 0.1986, 1.08, 3.46},
				{0.075, 1, 0.2819, 1.08, 3.29},
				{0.075, 1, 0.3653, 1.08, 4.87},
				{0.075, 1, 0.4486, 1.08, 2.13},
				{0.075, 1, 0.5319, 1.08, 3.92},
				{0.075, 1, 0.6153, 1.08, 2.16},
				{0.075, 1, 0.6986, 1.08, 3.07},
				{0.075, 1, 0.7819, 1.08, 3.47},
				{0.075, 1, 0.8653, 1.08, 1.91},
				{0.075, 1, 0.9486, 1.08, 0.76},
				{0.13, 1, 0.0591, 1.08, 3.73},
				{0.13, 1, 0.1424, 1.08, 3.16},
				{0.13, 1, 0.2258, 1.08, 2.51},
				{0.13, 1, 0.3091, 1.08, 3.39},
				{0.13, 1, 0.3924, 1.08, 1.32},
				{0.13, 1, 0.4758, 1.08, 1.3},
				{0.13, 1, 0.5591, 1.08, 1.96},
				{0.13, 1, 0.6424, 1.08, 4.17},
				{0.13, 1, 0.7258, 1.08, 1.38},
				{0.13, 1, 0.8091, 1.08, 1.01},
				{0.13, 1, 0.8924, 1.08, 0.89},
				{0.13, 1, 0.9758, 1.08, 2.63},
				{0.185, 1, 0.0002, 1.08, 1.66},
				{0.185, 1, 0.0836, 1.08, 0.94},
				{0.185, 1, 0.1669, 1.08, 0.68},
				{0.185, 1, 0.2502, 1.08, 1.74},
				{0.185, 1, 0.3336, 1.08, 3.08},
				{0.185, 1, 0.4169, 1.08, 4.19},
				{0.185, 1, 0.5002, 1.08, 1.99},
				{0.185, 1, 0.5836, 1.08, 2.16},
				{0.185, 1, 0.6669, 1.08, 1.8},
				{0.185, 1, 0.7502, 1.08, 1.87},
				{0.185, 1, 0.8336, 1.08, 4},
				{0.185, 1, 0.9169, 1.08, 2.97},
				{0.24, 1, 0.0087, 1.08, 2.95},
				{0.24, 1, 0.092, 1.08, 4.63},
				{0.24, 1, 0.1754, 1.08, 3.17},
				{0.24, 1, 0.2587, 1.08, 4.75},
				{0.24, 1, 0.342, 1.08, 1.25},
				{0.24, 1, 0.4254, 1.08, 4.89},
				{0.24, 1, 0.5087, 1.08, 0.75},
				{0.24, 1, 0.592, 1.08, 0.98},
				{0.24, 1, 0.6754, 1.08, 4.03},
				{0.24, 1, 0.7587, 1.08, 3.68},
				{0.24, 1, 0.842, 1.08, 4.23},
				{0.24, 1, 0.9254, 1.08, 1.57},
				{0.295, 1, 0.0071, 1.08, 2.92},
				{0.295, 1, 0.0904, 1.08, 4.95},
				{0.295, 1, 0.1737, 1.08, 3.87},
				{0.295, 1, 0.2571, 1.08, 2.06},
				{0.295, 1, 0.3404, 1.08, 4.88},
				{0.295, 1, 0.4237, 1.08, 2.37},
				{0.295, 1, 0.5071, 1.08, 0.61},
				{0.295, 1, 0.5904, 1.08, 4.14},
				{0.295, 1, 0.6737, 1.08, 3.59},
				{0.295, 1, 0.7571, 1.08, 4.88},
				{0.295, 1, 0.8404, 1.08, 4.12},
				{0.295, 1, 0.9237, 1.08, 4.77},
				{0.35, 1, 0.0301, 1.08, 4.78},
				{0.35, 1, 0.1134, 1.08, 1.47},
				{0.35, 1, 0.1968, 1.08, 0.97},
				{0.35, 1, 0.2801, 1.08, 2.88},
				{0.35, 1, 0.3634, 1.08, 1.26},
				{0.35, 1, 0.4468, 1.08, 2.95},
				{0.35, 1, 0.5301, 1.08, 2.2},
				{0.35, 1, 0.6134, 1.08, 1.37},
				{0.35, 1, 0.6968, 1.08, 0.84},
				{0.35, 1, 0.7801, 1.08, 2.6},
				{0.35, 1, 0.8634, 1.08, 1.38},
				{0.35, 1, 0.9468, 1.08, 4.7},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeMotes",
			texture = "fx_particle02",
			rel = "r",
			direction = "Back",
			speed_r = {1.7, 2.4},
			lifetime = {0.42, 0.5},
			size = {
				{0, 0, 0},
				{0.2, 1.1, 0.3},
				{0.8, 0.8, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 238, 255},
				},
				{
					1,
					{140, 190, 255},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			ring_emit = {
				{0.008, 1, 0.1392, 1.055, 4.394},
				{0.014, 1, 0.9747, 1.017, 2.917},
				{0.033, 1, 0.6706, 1.256, 2.485},
				{0.036, 1, 0.3957, 1.251, 5.246},
				{0.043, 1, 0.3325, 1.248, 4.529},
				{0.044, 1, 0.0793, 1.291, 5.843},
				{0.054, 1, 0.8569, 1.098, 0.92},
				{0.056, 1, 0.3539, 1.191, 5.639},
				{0.057, 1, 0.5833, 1.239, 1.237},
				{0.058, 1, 0.3095, 1.142, 4.598},
				{0.068, 1, 0.9118, 1.196, 6.84},
				{0.081, 1, 0.1732, 1.26, 4.864},
				{0.087, 1, 0.6627, 1.053, 0.71},
				{0.101, 1, 0.9009, 1.244, 3.126},
				{0.102, 1, 0.0891, 1.166, 2.163},
				{0.106, 1, 0.5025, 1.065, 6.01},
				{0.11, 1, 0.1466, 1.242, 2.727},
				{0.117, 1, 0.9152, 1.204, 0.824},
				{0.119, 1, 0.0864, 1.158, 6.322},
				{0.121, 1, 0.3413, 1.105, 6.73},
				{0.126, 1, 0.4455, 1.074, 4.794},
				{0.137, 1, 0.8138, 1.133, 6.279},
				{0.139, 1, 0.2686, 1.059, 6.852},
				{0.151, 1, 0.1419, 1.001, 5.564},
				{0.163, 1, 0.3157, 1.063, 0.692},
				{0.168, 1, 0.4778, 1.116, 5.771},
				{0.169, 1, 0.6996, 1.135, 0.848},
				{0.171, 1, 0.6196, 1.062, 2.422},
				{0.185, 1, 0.566, 1.033, 1.11},
				{0.188, 1, 0.5698, 1.22, 5.051},
				{0.188, 1, 0.7184, 1.168, 3.312},
				{0.197, 1, 0.7907, 1.085, 3.958},
				{0.205, 1, 0.4144, 1.175, 6.357},
				{0.205, 1, 0.5729, 1.19, 2.123},
				{0.209, 1, 0.5933, 1.243, 3.896},
				{0.217, 1, 0.0676, 1.154, 1.113},
				{0.225, 1, 0.2351, 1.024, 3.93},
				{0.228, 1, 0.798, 1.228, 4.132},
				{0.241, 1, 0.5881, 1.051, 0.726},
				{0.242, 1, 0.3196, 1.202, 2.254},
				{0.245, 1, 0.5069, 1.293, 3.167},
				{0.249, 1, 0.6083, 1.161, 3.165},
				{0.256, 1, 0.2953, 1.249, 1.897},
				{0.259, 1, 0.1974, 1.298, 6.166},
				{0.267, 1, 0.9209, 1.284, 1.053},
				{0.275, 1, 0.693, 1.269, 3.065},
				{0.276, 1, 0.5559, 1.144, 3.912},
				{0.284, 1, 0.2729, 1.222, 4.779},
				{0.29, 1, 0.5351, 1.119, 5.38},
				{0.293, 1, 0.8202, 1.22, 0.775},
				{0.298, 1, 0.3118, 1.195, 6.501},
				{0.3, 1, 0.5316, 1.186, 4.363},
				{0.309, 1, 0.5499, 1.123, 4.033},
				{0.31, 1, 0.0395, 1.114, 5.868},
				{0.318, 1, 0.9572, 1.024, 5.123},
				{0.329, 1, 0.4144, 1.128, 4.249},
				{0.329, 1, 0.5914, 1.231, 4.339},
				{0.329, 1, 0.9675, 1.052, 4.157},
				{0.333, 1, 0.8042, 1.184, 1.693},
				{0.334, 1, 0.9515, 1.168, 1.964},
				{0.336, 1, 0.3824, 1.019, 2.923},
				{0.343, 1, 0.8509, 1.133, 2.037},
				{0.344, 1, 0.3619, 1.16, 3.221},
				{0.345, 1, 0.7769, 1.263, 3.635},
				{0.36, 1, 0.6892, 1.171, 1.326},
				{0.385, 1, 0.7904, 1.089, 0.449},
				{0.39, 1, 0.8095, 1.043, 0.3},
				{0.393, 1, 0.0427, 1.074, 4.549},
				{0.393, 1, 0.1292, 1.266, 6.882},
				{0.393, 1, 0.4302, 1.276, 4.728},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeDust",
			texture = "kk_smoke_04",
			rel = "r",
			direction = "Back",
			speed_r = {0.7, 1},
			drag = 0.5,
			lifetime = {0.45, 0.55},
			size = {
				{0, 3, 0},
				{1, 8, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.55, 0},
				{0.8, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{150, 154, 168},
				},
				{
					0.5,
					{128, 132, 146},
				},
				{
					1,
					{110, 114, 128},
				},
			},
			light_emission = 0.05,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			ring_emit = {
				{0.056, 1, 0.5927, 1, 1},
				{0.065, 1, 0.2477, 1, 1},
				{0.081, 1, 0.5008, 1, 1},
				{0.105, 1, 0.8851, 1, 1},
				{0.119, 1, 0.1595, 1, 1},
				{0.126, 1, 0.3578, 1, 1},
				{0.133, 1, 0.2472, 1, 1},
				{0.134, 1, 0.6369, 1, 1},
				{0.14, 1, 0.8231, 1, 1},
				{0.158, 1, 0.9518, 1, 1},
				{0.16, 1, 0.1526, 1, 1},
				{0.176, 1, 0.2662, 1, 1},
				{0.187, 1, 0.1276, 1, 1},
				{0.19, 1, 0.8004, 1, 1},
				{0.198, 1, 0.7683, 1, 1},
				{0.199, 1, 0.7759, 1, 1},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeOrb",
			texture = "fx_electric_ball",
			rel = "r",
			lifetime = {0.46, 0.46},
			size = {
				{0, 2, 0},
				{0.6, 9, 0},
				{0.9, 12, 0},
				{1, 15, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.15, 0},
				{0.9, 0.05, 0},
				{1, 0.6, 0},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.35,
					{110, 185, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			rotation = {0, 360},
			rot_speed = {120, 200},
			ring_emit = {
				{0.04, 1, 0, 0, 3},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeCore",
			texture = "fx_glow",
			rel = "r",
			lifetime = {0.48, 0.48},
			size = {
				{0, 4, 0},
				{1, 20, 0},
			},
			transparency = {
				{0, 0.9, 0},
				{0.7, 0.35, 0},
				{1, 0.2, 0},
			},
			color = {
				{
					0,
					{40, 80, 210},
				},
				{
					0.5,
					{25, 50, 160},
				},
				{
					1,
					{12, 25, 100},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			ring_emit = {
				{0.02, 1, 0, 0, 3},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeSparks0",
			texture = "kk_spark_03",
			rel = "r",
			lifetime = {0.07, 0.1},
			size = {
				{0, 9, 2},
				{1, 12, 2},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.5,
					{150, 210, 255},
				},
				{
					1,
					{60, 120, 235},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			ring_emit = {
				{0.216, 1, 0.7384, 0.916, 0.8},
				{0.265, 1, 0.6665, 0.849, 0.8},
				{0.274, 1, 0.48, 0.322, 0.8},
				{0.281, 1, 0.0533, 0.831, 0.8},
				{0.384, 1, 0.1742, 0.595, 0.8},
				{0.401, 1, 0.3377, 0.657, 0.8},
				{0.46, 1, 0.0237, 0.893, 0.8},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeSparks1",
			texture = "kk_spark_04",
			rel = "r",
			lifetime = {0.07, 0.1},
			size = {
				{0, 9, 2},
				{1, 12, 2},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.5,
					{150, 210, 255},
				},
				{
					1,
					{60, 120, 235},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			ring_emit = {
				{0.311, 1, 0.5227, 0.534, 0.8},
				{0.349, 1, 0.6213, 0.928, 0.8},
				{0.384, 1, 0.7717, 0.34, 0.8},
				{0.4, 1, 0.693, 0.882, 0.8},
				{0.453, 1, 0.1438, 0.762, 0.8},
				{0.46, 1, 0.4004, 0.754, 0.8},
				{0.467, 1, 0.947, 0.757, 0.8},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "GuideLine",
			texture = "fx_laser_thin",
			rel = "h",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			lifetime = {0.16, 0.16},
			size = {
				{0, 25.2, 0},
				{1, 25.2, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.1, 0},
				{1, 0.5, 0},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.35,
					{110, 185, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			ring_emit = {
				{0.407, 1, 0, 0, 0.083},
				{0.42, 1, 0, 0, 0.25},
				{0.433, 1, 0, 0, 0.417},
				{0.447, 1, 0, 0, 0.583},
				{0.46, 1, 0, 0, 0.75},
				{0.473, 1, 0, 0, 0.917},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EruptFlash",
			texture = "fx_glow",
			rel = "r",
			lifetime = {0.2, 0.2},
			size = {
				{0, 8, 0},
				{0.25, 27, 0},
				{1, 30.6, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.4, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{235, 245, 255},
				},
				{
					0.25,
					{140, 200, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 1,
			brightness = 1.15,
			zoffset = 3,
			ring_emit = {
				{0.5, 1, 0, 0, 4},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EruptHalo",
			texture = "fx_halo",
			rel = "r",
			lifetime = {0.3, 0.34},
			size = {
				{0, 9, 0},
				{1, 75.6, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.5, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{180, 225, 255},
				},
				{
					0.5,
					{90, 150, 255},
				},
				{
					1,
					{30, 70, 200},
				},
			},
			light_emission = 0.9,
			brightness = 1.1,
			rotation = {0, 360},
			zoffset = 2,
			ring_emit = {
				{0.5, 1, 0, 0, 6},
				{0.54, 1, 0, 0, 6},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EruptStar",
			texture = "kk_star_09",
			rel = "r",
			lifetime = {0.3, 0.3},
			size = {
				{0, 20, 0},
				{0.15, 50.4, 0},
				{1, 12, 0},
			},
			color = {
				{
					0,
					{235, 245, 255},
				},
				{
					0.25,
					{140, 200, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			rotation = {0, 90},
			zoffset = 4,
			ring_emit = {
				{0.5, 1, 0, 0, 8},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EruptGlint",
			texture = "kk_star_08",
			rel = "r",
			lifetime = {0.24, 0.24},
			size = {
				{0, 81, 0},
				{1, 21.6, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{180, 225, 255},
				},
				{
					0.5,
					{90, 150, 255},
				},
				{
					1,
					{30, 70, 200},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			rotation = {0, 360},
			zoffset = 4,
			ring_emit = {
				{0.52, 1, 0, 0, 10},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ShockRing",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.5, 0.5},
			size = {
				{0, 61.02, 0},
				{1, 231.876, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{180, 225, 255},
				},
				{
					0.5,
					{90, 150, 255},
				},
				{
					1,
					{30, 70, 200},
				},
			},
			light_emission = 0.5,
			ring_emit = {
				{0.5, 1, 0, 0, 0.2},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ShockRingSharp",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.32, 0.32},
			size = {
				{0, 61.02, 0},
				{1, 305.1, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{180, 225, 255},
				},
				{
					0.5,
					{90, 150, 255},
				},
				{
					1,
					{30, 70, 200},
				},
			},
			light_emission = 0.7,
			ring_emit = {
				{0.5, 1, 0, 0, 0.21},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ShockRing2",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.4, 0.4},
			size = {
				{0, 61.02, 0},
				{1, 152.55, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.6, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{90, 150, 255},
				},
				{
					0.5,
					{50, 100, 230},
				},
				{
					1,
					{25, 50, 170},
				},
			},
			light_emission = 0.5,
			ring_emit = {
				{0.56, 1, 0, 0, 0.22},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "LaunchRings",
			texture = "kk_light_03",
			rel = "r",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed_h = {1.9, 2.1},
			lifetime = {0.5, 0.5},
			size = {
				{0, 46.8, 0},
				{0.5, 52.2, 0},
				{1, 55.8, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.7, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{170, 220, 255},
				},
				{
					0.5,
					{90, 160, 255},
				},
				{
					1,
					{30, 70, 200},
				},
			},
			light_emission = 0.9,
			brightness = 1.3,
			ring_emit = {
				{0.5, 1, 0, 0, 1},
				{0.55, 1, 0, 0, 1},
				{0.6, 1, 0, 0, 1},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "LaunchHead",
			texture = "fx_glow",
			rel = "r",
			direction = "Top",
			speed_h = {5, 5.2},
			lifetime = {0.2, 0.2},
			size = {
				{0, 18, 0},
				{1, 25.2, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{235, 245, 255},
				},
				{
					0.25,
					{140, 200, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			ring_emit = {
				{0.5, 1, 0, 0, 2},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "LaunchBeam",
			texture = "fx_beam",
			rel = "h",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			lifetime = {0.32, 0.36},
			size = {
				{0, 33.6, 0},
				{1, 36, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.15, 0.2, 0},
				{0.6, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{235, 245, 255},
				},
				{
					0.25,
					{140, 200, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			ring_emit = {
				{0.516, 1, 0, 0, 0.08},
				{0.544, 1, 0, 0, 0.22},
				{0.572, 1, 0, 0, 0.36},
				{0.6, 1, 0, 0, 0.5},
				{0.628, 1, 0, 0, 0.64},
				{0.656, 1, 0, 0, 0.78},
				{0.684, 1, 0, 0, 0.92},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "LaunchBody",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			lifetime = {0.55, 0.65},
			size = {
				{0, 39.6, 0},
				{0.3, 44.1, 0},
				{1, 45, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.12, 0.25, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{225, 225, 240},
				},
			},
			light_emission = 0.1,
			zoffset = -4,
			ring_emit = {
				{0.511, 1, 0, 0, 0.06},
				{0.532, 1, 0, 0, 0.18},
				{0.554, 1, 0, 0, 0.3},
				{0.576, 1, 0, 0, 0.42},
				{0.597, 1, 0, 0, 0.54},
				{0.619, 1, 0, 0, 0.66},
				{0.64, 1, 0, 0, 0.78},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "LaunchStreaks",
			texture = "kk_trace_01",
			rel = "r",
			orientation = "VelocityParallel",
			direction = "Top",
			speed_h = {1.6, 2.4},
			lifetime = {0.25, 0.4},
			size = {
				{0, 6, 0},
				{0.3, 26, 0},
				{1, 16, 0},
			},
			color = {
				{
					0,
					{215, 240, 255},
				},
				{
					0.5,
					{120, 190, 255},
				},
				{
					1,
					{45, 100, 230},
				},
			},
			light_emission = 1,
			brightness = 1.05,
			ring_emit = {
				{0.5, 1, 0.313, 0.929, 1.608},
				{0.5, 1, 0.6249, 0.834, 2.023},
				{0.501, 1, 0.3002, 0.479, 1.344},
				{0.502, 1, 0.326, 0.873, 1.645},
				{0.502, 1, 0.957, 0.786, 3.016},
				{0.504, 1, 0.116, 0.443, 0.462},
				{0.505, 1, 0.1396, 0.516, 0.991},
				{0.507, 1, 0.5872, 0.784, 3.96},
				{0.511, 1, 0.8781, 0.83, 0.151},
				{0.512, 1, 0.0016, 0.442, 1.548},
				{0.512, 1, 0.1768, 0.598, 0.343},
				{0.514, 1, 0.6376, 0.92, 0.959},
				{0.52, 1, 0.7476, 0.836, 2.285},
				{0.523, 1, 0.7916, 0.37, 1.259},
				{0.526, 1, 0.8856, 0.928, 0.918},
				{0.529, 1, 0.9135, 0.36, 2.907},
				{0.529, 1, 0.926, 0.405, 1.404},
				{0.533, 1, 0.85, 0.632, 2.352},
				{0.536, 1, 0.339, 0.873, 1.61},
				{0.537, 1, 0.79, 0.497, 1.738},
				{0.537, 1, 0.985, 0.443, 0.91},
				{0.538, 1, 0.8659, 0.728, 0.32},
				{0.54, 1, 0.2747, 0.895, 3.388},
				{0.54, 1, 0.8438, 0.768, 3.341},
				{0.541, 1, 0.9832, 0.988, 3.925},
				{0.542, 1, 0.9268, 0.813, 1.024},
				{0.543, 1, 0.3714, 0.532, 0.012},
				{0.544, 1, 0.7319, 0.474, 2.984},
				{0.544, 1, 0.8518, 0.711, 2.478},
				{0.546, 1, 0.0938, 0.579, 0.532},
				{0.546, 1, 0.7304, 0.741, 3.139},
				{0.548, 1, 0.5224, 0.883, 1.024},
				{0.549, 1, 0.0454, 0.743, 0.184},
				{0.549, 1, 0.6405, 0.926, 2.164},
				{0.551, 1, 0.4965, 0.411, 2.114},
				{0.552, 1, 0.1011, 0.697, 1.421},
				{0.553, 1, 0.0937, 0.69, 0.983},
				{0.554, 1, 0.2822, 0.885, 2.985},
				{0.555, 1, 0.5402, 0.515, 0.168},
				{0.558, 1, 0.18, 0.678, 3.463},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "LaunchPurple",
			texture = "kk_trace_01",
			rel = "r",
			orientation = "VelocityParallel",
			direction = "Top",
			speed_h = {1.5, 2.2},
			lifetime = {0.25, 0.4},
			size = {
				{0, 6, 0},
				{0.3, 26, 0},
				{1, 16, 0},
			},
			color = {
				{
					0,
					{225, 140, 255},
				},
				{
					0.4,
					{190, 70, 250},
				},
				{
					1,
					{115, 30, 200},
				},
			},
			light_emission = 1,
			brightness = 1.15,
			ring_emit = {
				{0.501, 1, 0.5365, 0.867, 0.767},
				{0.502, 1, 0.7832, 0.491, 3.009},
				{0.506, 1, 0.2241, 0.539, 2.049},
				{0.507, 1, 0.5675, 0.69, 0.36},
				{0.513, 1, 0.1955, 0.656, 2.23},
				{0.513, 1, 0.4594, 0.55, 1.431},
				{0.516, 1, 0.095, 0.37, 1.553},
				{0.516, 1, 0.3405, 0.969, 0.66},
				{0.519, 1, 0.2241, 0.81, 3.144},
				{0.529, 1, 0.7944, 0.914, 0.351},
				{0.533, 1, 0.4585, 0.707, 0.299},
				{0.534, 1, 0.9026, 0.672, 2.764},
				{0.535, 1, 0.7193, 0.962, 2.224},
				{0.542, 1, 0.975, 0.926, 1.259},
				{0.544, 1, 0.7455, 0.5, 0.243},
				{0.547, 1, 0.9018, 0.934, 0.627},
				{0.548, 1, 0.8143, 0.511, 3.051},
				{0.551, 1, 0.6805, 0.882, 3.845},
				{0.552, 1, 0.5675, 0.624, 0.065},
				{0.553, 1, 0.2006, 0.712, 2.485},
				{0.554, 1, 0.8068, 0.907, 0.128},
				{0.554, 1, 0.8698, 0.556, 0.221},
				{0.557, 1, 0.1584, 0.873, 3.891},
				{0.557, 1, 0.3392, 0.822, 3.585},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EruptSpikes",
			texture = "fx_spikes",
			rel = "r",
			orientation = "FacingCameraWorldUp",
			lifetime = {0.32, 0.4},
			size = {
				{0, 9, 0},
				{0.3, 18, 0},
				{1, 20.7, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{0.3, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{170, 220, 255},
				},
				{
					0.5,
					{90, 160, 255},
				},
				{
					1,
					{30, 70, 200},
				},
			},
			light_emission = 0.7,
			brightness = 1,
			ring_emit = {
				{0.5, 1, 0.5267, 1, 5.76},
				{0.5, 1, 0.5822, 1, 5.76},
				{0.5, 1, 0.6378, 1, 5.76},
				{0.5, 1, 0.6933, 1, 5.76},
				{0.5, 1, 0.7489, 1, 5.76},
				{0.5, 1, 0.8044, 1, 5.76},
				{0.5, 1, 0.86, 1, 5.76},
				{0.5, 1, 0.9156, 1, 5.76},
				{0.5, 1, 0.9711, 1, 5.76},
				{0.5, 1, 0.0267, 1, 5.76},
				{0.5, 1, 0.0822, 1, 5.76},
				{0.5, 1, 0.1378, 1, 5.76},
				{0.5, 1, 0.1933, 1, 5.76},
				{0.5, 1, 0.2489, 1, 5.76},
				{0.5, 1, 0.3044, 1, 5.76},
				{0.5, 1, 0.36, 1, 5.76},
				{0.5, 1, 0.4156, 1, 5.76},
				{0.5, 1, 0.4711, 1, 5.76},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EruptThunder",
			texture = "fx_thunder",
			rel = "h",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			lifetime = {0.08, 0.12},
			size = {
				{0, 33.6, 0},
				{1, 36, 0},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.5,
					{150, 210, 255},
				},
				{
					1,
					{60, 120, 235},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			rotation = {-10, 10},
			ring_emit = {
				{0.527, 1, 0.432, 1.032, 0.473},
				{0.541, 1, 0.4877, 0.981, 0.292},
				{0.548, 1, 0.2487, 0.984, 0.461},
				{0.56, 1, 0.5958, 1.012, 0.503},
				{0.575, 1, 0.1795, 1.007, 0.421},
				{0.585, 1, 0.1502, 0.983, 0.574},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EruptDust",
			texture = "kk_smoke_07",
			rel = "r",
			direction = "Front",
			spread = {15, 8},
			pitch = 8,
			speed = {30, 55},
			drag = 2.5,
			accel = {0, 3, 0},
			lifetime = {0.9, 1.3},
			size = {
				{0, 6, 1},
				{0.3, 14, 2},
				{1, 18, 2},
			},
			transparency = {
				{0, 0.5, 0},
				{0.3, 0.5, 0},
				{0.7, 0.75, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{150, 154, 168},
				},
				{
					0.5,
					{128, 132, 146},
				},
				{
					1,
					{110, 114, 128},
				},
			},
			light_emission = 0.05,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			zoffset = -1,
			ring_emit = {
				{0.5, 2, 0.4079, 1, 1.5},
				{0.5, 2, 0.4496, 1, 1.5},
				{0.5, 2, 0.4913, 1, 1.5},
				{0.5, 2, 0.5329, 1, 1.5},
				{0.5, 2, 0.5746, 1, 1.5},
				{0.5, 2, 0.6163, 1, 1.5},
				{0.5, 2, 0.6579, 1, 1.5},
				{0.5, 2, 0.6996, 1, 1.5},
				{0.5, 2, 0.7413, 1, 1.5},
				{0.5, 2, 0.7829, 1, 1.5},
				{0.5, 2, 0.8246, 1, 1.5},
				{0.5, 2, 0.8663, 1, 1.5},
				{0.5, 2, 0.9079, 1, 1.5},
				{0.5, 2, 0.9496, 1, 1.5},
				{0.5, 2, 0.9913, 1, 1.5},
				{0.5, 2, 0.0329, 1, 1.5},
				{0.5, 2, 0.0746, 1, 1.5},
				{0.5, 2, 0.1163, 1, 1.5},
				{0.5, 2, 0.1579, 1, 1.5},
				{0.5, 2, 0.1996, 1, 1.5},
				{0.5, 2, 0.2413, 1, 1.5},
				{0.5, 2, 0.2829, 1, 1.5},
				{0.5, 2, 0.3246, 1, 1.5},
				{0.5, 2, 0.3663, 1, 1.5},
			},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CubeBits",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 55,
			spread = {25, 25},
			speed = {25, 70},
			accel = {0, -160, 0},
			drag = 0.4,
			lifetime = {0.8, 1.2},
			size = {
				{0, 0.3, 0.12},
				{1, 0.24, 0.1},
			},
			rotation = {0, 360},
			rot_speed = {-500, 500},
			color = {
				{
					0,
					{112, 106, 112},
				},
				{
					1,
					{112, 106, 112},
				},
			},
			ground_mix = 1,
			lit = true,
			ring_emit = {
				{0.5, 3, 0.0181, 0.623, 0.6},
				{0.5, 3, 0.0188, 0.628, 0.6},
				{0.5, 3, 0.0216, 0.533, 0.6},
				{0.5, 3, 0.0388, 0.923, 0.6},
				{0.5, 3, 0.0535, 0.519, 0.6},
				{0.5, 3, 0.0545, 0.612, 0.6},
				{0.5, 3, 0.0607, 0.882, 0.6},
				{0.5, 3, 0.0695, 0.688, 0.6},
				{0.5, 3, 0.0801, 0.985, 0.6},
				{0.5, 3, 0.0881, 0.586, 0.6},
				{0.5, 3, 0.0883, 0.867, 0.6},
				{0.5, 3, 0.0919, 0.842, 0.6},
				{0.5, 3, 0.1163, 0.529, 0.6},
				{0.5, 3, 0.1232, 0.275, 0.6},
				{0.5, 3, 0.1415, 0.874, 0.6},
				{0.5, 3, 0.1462, 0.893, 0.6},
				{0.5, 3, 0.1503, 0.844, 0.6},
				{0.5, 3, 0.179, 0.994, 0.6},
				{0.5, 3, 0.1843, 0.702, 0.6},
				{0.5, 3, 0.2328, 0.784, 0.6},
				{0.5, 3, 0.233, 0.501, 0.6},
				{0.5, 3, 0.2352, 0.413, 0.6},
				{0.5, 3, 0.2665, 0.861, 0.6},
				{0.5, 3, 0.2731, 0.288, 0.6},
				{0.5, 3, 0.2808, 0.531, 0.6},
				{0.5, 3, 0.2864, 0.705, 0.6},
				{0.5, 3, 0.2904, 0.694, 0.6},
				{0.5, 3, 0.2971, 0.278, 0.6},
				{0.5, 3, 0.3182, 0.676, 0.6},
				{0.5, 3, 0.3537, 0.838, 0.6},
				{0.5, 3, 0.3593, 0.329, 0.6},
				{0.5, 3, 0.3612, 0.829, 0.6},
				{0.5, 3, 0.3734, 0.92, 0.6},
				{0.5, 3, 0.3816, 0.62, 0.6},
				{0.5, 3, 0.4018, 0.73, 0.6},
				{0.5, 3, 0.4114, 0.803, 0.6},
				{0.5, 3, 0.4329, 0.286, 0.6},
				{0.5, 3, 0.4392, 0.644, 0.6},
				{0.5, 3, 0.4479, 0.274, 0.6},
				{0.5, 3, 0.4564, 0.646, 0.6},
				{0.5, 3, 0.4692, 0.323, 0.6},
				{0.5, 3, 0.49, 0.927, 0.6},
				{0.5, 3, 0.4916, 0.554, 0.6},
				{0.5, 3, 0.5082, 0.854, 0.6},
				{0.5, 3, 0.5129, 0.922, 0.6},
				{0.5, 3, 0.5252, 0.739, 0.6},
				{0.5, 3, 0.5355, 0.917, 0.6},
				{0.5, 3, 0.5412, 0.529, 0.6},
				{0.5, 3, 0.5784, 0.509, 0.6},
				{0.5, 3, 0.5912, 0.813, 0.6},
				{0.5, 3, 0.6174, 0.497, 0.6},
				{0.5, 3, 0.6223, 0.584, 0.6},
				{0.5, 3, 0.6253, 0.85, 0.6},
				{0.5, 3, 0.6319, 0.949, 0.6},
				{0.5, 3, 0.649, 0.462, 0.6},
				{0.5, 3, 0.6558, 0.837, 0.6},
				{0.5, 3, 0.6593, 0.533, 0.6},
				{0.5, 3, 0.6616, 0.822, 0.6},
				{0.5, 3, 0.6788, 0.68, 0.6},
				{0.5, 3, 0.7035, 0.904, 0.6},
				{0.5, 3, 0.7201, 0.966, 0.6},
				{0.5, 3, 0.7279, 1, 0.6},
				{0.5, 3, 0.7483, 0.634, 0.6},
				{0.5, 3, 0.75, 0.998, 0.6},
				{0.5, 3, 0.7579, 0.915, 0.6},
				{0.5, 3, 0.7609, 0.848, 0.6},
				{0.5, 3, 0.7898, 0.619, 0.6},
				{0.5, 3, 0.7909, 0.495, 0.6},
				{0.5, 3, 0.8109, 0.772, 0.6},
				{0.5, 3, 0.8254, 0.836, 0.6},
				{0.5, 3, 0.8668, 0.693, 0.6},
				{0.5, 3, 0.8678, 0.868, 0.6},
				{0.5, 3, 0.885, 0.671, 0.6},
				{0.5, 3, 0.9003, 0.655, 0.6},
				{0.5, 3, 0.9084, 0.654, 0.6},
				{0.5, 3, 0.9379, 0.36, 0.6},
				{0.5, 3, 0.9502, 0.368, 0.6},
				{0.5, 3, 0.9717, 0.967, 0.6},
				{0.5, 3, 0.9728, 0.636, 0.6},
				{0.5, 3, 0.9979, 0.606, 0.6},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			light_emission = 0,
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EruptBolts0",
			texture = "kk_spark_05",
			rel = "r",
			lifetime = {0.08, 0.12},
			size = {
				{0, 16, 4},
				{1, 22, 4},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.5,
					{150, 210, 255},
				},
				{
					1,
					{60, 120, 235},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			zoffset = 2,
			ring_emit = {
				{0.55, 1, 0.2654, 0.934, 8.459},
				{0.591, 1, 0.23, 0.81, 2.541},
				{0.654, 1, 0.9967, 1.094, 5.978},
				{0.67, 1, 0.8941, 0.832, 5.87},
				{0.674, 1, 0.3944, 0.881, 3.643},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EruptBolts1",
			texture = "kk_spark_06",
			rel = "r",
			lifetime = {0.08, 0.12},
			size = {
				{0, 16, 4},
				{1, 22, 4},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.5,
					{150, 210, 255},
				},
				{
					1,
					{60, 120, 235},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			zoffset = 2,
			ring_emit = {
				{0.535, 1, 0.1301, 0.864, 2.79},
				{0.547, 1, 0.2754, 0.865, 2.24},
				{0.56, 1, 0.9046, 0.73, 7.169},
				{0.652, 1, 0.3217, 0.961, 5.967},
				{0.656, 1, 0.1356, 0.838, 12.386},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "Body",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			speed_h = {0.1, 0.18},
			lifetime = {0.9, 1.2},
			size = {
				{0, 41.895, 2.205},
				{0.5, 44.1, 2.205},
				{1, 45.864, 2.205},
			},
			transparency = {
				{0, 1, 0},
				{0.15, 0.25, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{225, 225, 240},
				},
			},
			light_emission = 0.1,
			zoffset = -4,
			zstream = {
				{0.5, 0.58, 12, 12},
				{0.58, 2.38, 12, 12},
				{2.38, 2.5, 12, 0},
			},
			zdist = {
				r = {0, 0.08},
				h = {0.04, 0.7},
				area = false,
			},
			radial = false,
			cover = true,
			fade_at = {2.48, 0.25},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "BodyRim",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			speed_h = {0.12, 0.2},
			lifetime = {0.8, 1.1},
			size = {
				{0, 43.218, 0},
				{1, 46.746, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.7, 0},
				{0.8, 0.72, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{40, 80, 210},
				},
				{
					0.5,
					{25, 50, 160},
				},
				{
					1,
					{12, 25, 100},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = -3,
			zstream = {
				{0.5, 0.58, 8, 8},
				{0.58, 2.38, 8, 8},
				{2.38, 2.5, 8, 0},
			},
			zdist = {
				r = {0, 0.08},
				h = {0.05, 0.75},
				area = false,
			},
			radial = false,
			cover = true,
			fade_at = {2.48, 0.25},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "BodyPurple",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			speed_h = {0.12, 0.2},
			lifetime = {0.7, 1},
			size = {
				{0, 39.69, 0},
				{1, 44.1, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.6, 0},
				{0.7, 0.64, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{225, 140, 255},
				},
				{
					0.4,
					{190, 70, 250},
				},
				{
					1,
					{115, 30, 200},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = -3,
			zstream = {
				{0.5, 0.58, 7, 7},
				{0.58, 2.38, 7, 7},
				{2.38, 2.5, 7, 0},
			},
			zdist = {
				r = {0, 0.08},
				h = {0.1, 0.7},
				area = false,
			},
			radial = false,
			cover = true,
			fade_at = {2.48, 0.25},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "WavyFlow",
			texture = "fx_beam_wavy",
			rel = "r",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			speed_h = {0.4, 0.55},
			lifetime = {0.7, 0.9},
			size = {
				{0, 30, 0},
				{0.5, 40, 0},
				{1, 44, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.25, 0.6, 0},
				{0.75, 0.66, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{40, 80, 210},
				},
				{
					0.5,
					{25, 50, 160},
				},
				{
					1,
					{12, 25, 100},
				},
			},
			light_emission = 0.6,
			brightness = 1,
			zoffset = -2,
			zstream = {
				{0.5, 0.58, 9.1, 26},
				{0.58, 2.38, 26, 26},
				{2.38, 2.5, 26, 0},
			},
			zdist = {
				r = {0.25, 0.85},
				h = {0, 0.45},
				area = false,
			},
			radial = false,
			cover = true,
			fade_at = {2.48, 0.25},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "WallBeams",
			texture = "fx_beam_wavy",
			rel = "r",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			speed_h = {0.55, 0.75},
			lifetime = {0.55, 0.7},
			size = {
				{0, 30, 0},
				{0.5, 36, 0},
				{1, 38, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.6, 0},
				{0.7, 0.66, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 235, 255},
				},
				{
					0.4,
					{110, 180, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 0.8,
			brightness = 0.9,
			zoffset = 1,
			zstream = {
				{0.5, 0.58, 14, 40},
				{0.58, 2.38, 40, 40},
				{2.38, 2.5, 40, 0},
			},
			zdist = {
				r = {0.88, 1},
				h = {0, 0.5},
				area = false,
			},
			radial = false,
			cover = true,
			fade_at = {2.48, 0.25},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CoreStreaks",
			texture = "kk_trace_03",
			rel = "r",
			hu = "H",
			orientation = "VelocityParallel",
			direction = "Top",
			speed_h = {1.2, 1.8},
			lifetime = {0.25, 0.35},
			size = {
				{0, 4, 0},
				{0.3, 22, 0},
				{1, 12, 0},
			},
			color = {
				{
					0,
					{215, 240, 255},
				},
				{
					0.5,
					{120, 190, 255},
				},
				{
					1,
					{45, 100, 230},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			zoffset = 2,
			zstream = {
				{0.5, 0.58, 8.75, 25},
				{0.58, 2.38, 25, 25},
				{2.38, 2.5, 25, 0},
			},
			zdist = {
				r = {0.1, 0.7},
				h = {0, 0.4},
				area = true,
			},
			radial = false,
			cover = true,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "WallStreaks",
			texture = "kk_trace_04",
			rel = "r",
			hu = "H",
			orientation = "VelocityParallel",
			direction = "Top",
			speed_h = {1, 1.4},
			lifetime = {0.35, 0.5},
			size = {
				{0, 8, 0},
				{0.3, 34, 0},
				{1, 22, 0},
			},
			color = {
				{
					0,
					{215, 240, 255},
				},
				{
					0.5,
					{120, 190, 255},
				},
				{
					1,
					{45, 100, 230},
				},
			},
			transparency = {
				{0, 0.3, 0},
				{0.7, 0.5, 0},
				{1, 1, 0},
			},
			light_emission = 0.9,
			brightness = 1.1,
			zoffset = 2,
			zstream = {
				{0.5, 0.58, 24.5, 70},
				{0.58, 2.38, 70, 70},
				{2.38, 2.5, 70, 0},
			},
			zdist = {
				r = {0.85, 1},
				h = {0, 0.4},
				area = false,
			},
			radial = false,
			cover = true,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "PurpleStreaks",
			texture = "kk_trace_03",
			rel = "r",
			hu = "H",
			orientation = "VelocityParallel",
			direction = "Top",
			speed_h = {0.9, 1.3},
			lifetime = {0.4, 0.55},
			size = {
				{0, 8, 0},
				{0.3, 34, 0},
				{1, 22, 0},
			},
			color = {
				{
					0,
					{225, 140, 255},
				},
				{
					0.4,
					{190, 70, 250},
				},
				{
					1,
					{115, 30, 200},
				},
			},
			transparency = {
				{0, 0.2, 0},
				{0.7, 0.4, 0},
				{1, 1, 0},
			},
			light_emission = 1,
			brightness = 1.3,
			zoffset = 2,
			zstream = {
				{0.5, 0.58, 33.25, 95},
				{0.58, 2.38, 95, 95},
				{2.38, 2.5, 95, 0},
			},
			zdist = {
				r = {0.78, 1},
				h = {0, 0.45},
				area = false,
			},
			radial = false,
			cover = true,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "AuroraBlue",
			texture = "fx_aurora",
			rel = "r",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			speed_h = {0.3, 0.45},
			lifetime = {0.6, 0.9},
			size = {
				{0, 22, 0},
				{0.5, 30, 0},
				{1, 34, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.25, 0.55, 0},
				{0.75, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 235, 255},
				},
				{
					0.4,
					{110, 180, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 0.9,
			brightness = 1,
			zoffset = 1,
			zstream = {
				{0.5, 0.58, 5.6, 16},
				{0.58, 2.38, 16, 16},
				{2.38, 2.5, 16, 0},
			},
			zdist = {
				r = {0.55, 1},
				h = {0, 0.6},
				area = false,
			},
			radial = false,
			cover = true,
			fade_at = {2.48, 0.25},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "AuroraPurple",
			texture = "fx_aurora",
			rel = "r",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			speed_h = {0.3, 0.45},
			lifetime = {0.6, 0.9},
			size = {
				{0, 22, 0},
				{0.5, 30, 0},
				{1, 34, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.25, 0.5, 0},
				{0.75, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{225, 140, 255},
				},
				{
					0.4,
					{190, 70, 250},
				},
				{
					1,
					{115, 30, 200},
				},
			},
			light_emission = 0.9,
			brightness = 1.05,
			zoffset = 1,
			zstream = {
				{0.5, 0.58, 6.3, 18},
				{0.58, 2.38, 18, 18},
				{2.38, 2.5, 18, 0},
			},
			zdist = {
				r = {0.55, 1},
				h = {0, 0.6},
				area = false,
			},
			radial = false,
			cover = true,
			fade_at = {2.48, 0.25},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "PurpleCore",
			texture = "kk_trace_04",
			rel = "r",
			hu = "H",
			orientation = "VelocityParallel",
			direction = "Top",
			speed_h = {1.1, 1.6},
			lifetime = {0.25, 0.35},
			size = {
				{0, 4, 0},
				{0.3, 20, 0},
				{1, 10, 0},
			},
			color = {
				{
					0,
					{225, 140, 255},
				},
				{
					0.4,
					{190, 70, 250},
				},
				{
					1,
					{115, 30, 200},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			zoffset = 2,
			zstream = {
				{0.5, 0.58, 12.25, 35},
				{0.58, 2.38, 35, 35},
				{2.38, 2.5, 35, 0},
			},
			zdist = {
				r = {0.2, 0.75},
				h = {0, 0.4},
				area = true,
			},
			radial = false,
			cover = true,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "BodySparkles",
			texture = "fx_particle02",
			rel = "r",
			hu = "H",
			direction = "Top",
			speed_h = {0.02, 0.06},
			lifetime = {0.3, 0.6},
			size = {
				{0, 0, 0},
				{0.3, 0.8, 0.2},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					1,
					{190, 225, 255},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			zoffset = 3,
			zstream = {
				{0.5, 0.58, 31.5, 90},
				{0.58, 2.38, 90, 90},
				{2.38, 2.5, 90, 0},
			},
			zdist = {
				r = {0.5, 1},
				h = {0, 0.95},
				area = false,
			},
			radial = false,
			cover = true,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "Rings",
			texture = "kk_light_03",
			rel = "r",
			hu = "H",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed_h = {0.8, 0.95},
			lifetime = {1, 1.1},
			size = {
				{0, 49.5, 0},
				{1, 53.1, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.3, 0},
				{0.75, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{170, 220, 255},
				},
				{
					0.5,
					{90, 160, 255},
				},
				{
					1,
					{30, 70, 200},
				},
			},
			light_emission = 0.9,
			brightness = 1.1,
			zoffset = 2,
			zstream = {
				{0.5, 0.58, 5, 5},
				{0.58, 2.38, 5, 5},
				{2.38, 2.5, 5, 0},
			},
			zdist = {
				r = {0, 0},
				h = {0.01, 0.01},
				area = false,
			},
			radial = false,
			clear_at = 2.52,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "SwirlRings",
			texture = "fx_swirl_rings",
			rel = "r",
			hu = "H",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed_h = {0.55, 0.7},
			lifetime = {1.2, 1.4},
			rotation = {0, 360},
			rot_speed = {-260, -200},
			size = {
				{0, 43.2, 0},
				{1, 48.6, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.1, 0.45, 0},
				{0.75, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 150, 255},
				},
				{
					0.5,
					{190, 80, 235},
				},
				{
					1,
					{110, 40, 190},
				},
			},
			light_emission = 0.8,
			brightness = 1,
			zoffset = 2,
			zstream = {
				{0.5, 0.58, 3, 3},
				{0.58, 2.38, 3, 3},
				{2.38, 2.5, 3, 0},
			},
			zdist = {
				r = {0, 0},
				h = {0.02, 0.02},
				area = false,
			},
			radial = false,
			clear_at = 2.52,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "Lightning",
			texture = "fx_thunder",
			rel = "h",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			lifetime = {0.07, 0.12},
			size = {
				{0, 31.2, 4.8},
				{1, 33.6, 4.8},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.5,
					{150, 210, 255},
				},
				{
					1,
					{60, 120, 235},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {-12, 12},
			zoffset = 3,
			zstream = {
				{0.5, 0.58, 3.5, 10},
				{0.58, 2.38, 10, 10},
				{2.38, 2.5, 10, 0},
			},
			zdist = {
				r = {0.92, 1.05},
				h = {0.05, 0.8},
				area = false,
			},
			radial = false,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "VortexStars",
			texture = "fx_spark002",
			rel = "r",
			hu = "H",
			direction = "Top",
			speed_h = {0.25, 0.42},
			lifetime = {1.4, 1.9},
			size = {
				{0, 0, 0},
				{0.15, 2.2, 0.6},
				{0.85, 1.6, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 238, 255},
				},
				{
					1,
					{140, 190, 255},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			rotation = {0, 45},
			zoffset = 3,
			zstream = {
				{0.5, 0.58, 14, 40},
				{0.58, 2.38, 40, 40},
				{2.38, 2.5, 40, 0},
			},
			zdist = {
				r = {0.6, 1.05},
				h = {0, 0.08},
				area = false,
			},
			radial = false,
			clear_at = 2.52,
			spin = 210,
			slots = 8,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "VortexPurple",
			texture = "fx_spark002",
			rel = "r",
			hu = "H",
			direction = "Top",
			speed_h = {0.25, 0.4},
			lifetime = {1.2, 1.7},
			size = {
				{0, 0, 0},
				{0.15, 2, 0.5},
				{0.85, 1.4, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{225, 140, 255},
				},
				{
					0.4,
					{190, 70, 250},
				},
				{
					1,
					{115, 30, 200},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {0, 45},
			zoffset = 3,
			zstream = {
				{0.5, 0.58, 9.1, 26},
				{0.58, 2.38, 26, 26},
				{2.38, 2.5, 26, 0},
			},
			zdist = {
				r = {0.6, 1.05},
				h = {0, 0.08},
				area = false,
			},
			radial = false,
			clear_at = 2.52,
			spin = 210,
			slots = 6,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "VortexTwinkle",
			texture = "kk_star_06",
			rel = "r",
			hu = "H",
			direction = "Top",
			speed_h = {0.15, 0.3},
			lifetime = {1.2, 1.8},
			size = {
				{0, 0, 0},
				{0.08, 3.2, 0},
				{0.22, 1.4, 0},
				{0.38, 3.4, 0},
				{0.55, 1.2, 0},
				{0.72, 2.8, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 238, 255},
				},
				{
					1,
					{140, 190, 255},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			rotation = {0, 30},
			zoffset = 3,
			zstream = {
				{0.5, 0.58, 6.3, 18},
				{0.58, 2.38, 18, 18},
				{2.38, 2.5, 18, 0},
			},
			zdist = {
				r = {0.6, 1},
				h = {0, 0.1},
				area = false,
			},
			radial = false,
			clear_at = 2.52,
			spin = 210,
			slots = 8,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "VortexMotes",
			texture = "fx_particle02",
			rel = "r",
			hu = "H",
			direction = "Top",
			speed_h = {0.2, 0.4},
			lifetime = {1.2, 1.8},
			size = {
				{0, 0, 0},
				{0.1, 0.9, 0.3},
				{0.8, 0.7, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					1,
					{150, 200, 255},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			zoffset = 3,
			zstream = {
				{0.5, 0.58, 21, 60},
				{0.58, 2.38, 60, 60},
				{2.38, 2.5, 60, 0},
			},
			zdist = {
				r = {0.5, 1.05},
				h = {0, 0.1},
				area = true,
			},
			radial = false,
			clear_at = 2.52,
			spin = 210,
			slots = 8,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "BaseSpikes",
			texture = "fx_spikes",
			rel = "r",
			orientation = "FacingCameraWorldUp",
			lifetime = {0.22, 0.32},
			size = {
				{0, 9, 0},
				{0.5, 14.4, 0},
				{1, 16.2, 0},
			},
			transparency = {
				{0, 0.7, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{170, 220, 255},
				},
				{
					0.5,
					{90, 160, 255},
				},
				{
					1,
					{30, 70, 200},
				},
			},
			light_emission = 0.7,
			brightness = 1,
			zoffset = 1,
			zstream = {
				{0.5, 0.58, 7.7, 22},
				{0.58, 2.38, 22, 22},
				{2.38, 2.5, 22, 0},
			},
			zdist = {
				r = {0.92, 1.02},
				h = {5.04, 5.04},
				area = false,
			},
			radial = false,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "BaseSplash",
			texture = "kk_trace_01",
			rel = "r",
			orientation = "VelocityParallel",
			direction = "Front",
			spread = {8, 8},
			pitch = 12,
			speed = {35, 60},
			drag = 2,
			lifetime = {0.18, 0.28},
			size = {
				{0, 3, 0},
				{0.3, 10, 0},
				{1, 6, 0},
			},
			color = {
				{
					0,
					{200, 235, 255},
				},
				{
					0.4,
					{110, 180, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			zoffset = 1,
			zstream = {
				{0.5, 0.58, 11.9, 34},
				{0.58, 2.38, 34, 34},
				{2.38, 2.5, 34, 0},
			},
			zdist = {
				r = {0.95, 1},
				h = {0.5, 1.5},
				area = false,
			},
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "BaseGlow",
			texture = "fx_glow",
			rel = "r",
			lifetime = {2.05, 2.05},
			size = {
				{0, 36, 0},
				{0.05, 46.8, 0},
				{1, 48.6, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.04, 0.45, 0},
				{0.9, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{40, 80, 210},
				},
				{
					0.5,
					{25, 50, 160},
				},
				{
					1,
					{12, 25, 100},
				},
			},
			light_emission = 0.4,
			ring_emit = {
				{0.5, 1, 0, 0, 0.24},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TopStars",
			texture = "fx_spark002",
			rel = "r",
			hu = "H",
			direction = "Top",
			spread = {70, 70},
			speed = {6, 16},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.2, 2, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 238, 255},
				},
				{
					1,
					{140, 190, 255},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			rotation = {0, 45},
			zoffset = 3,
			zstream = {
				{0.5, 0.58, 5.6, 16},
				{0.58, 2.38, 16, 16},
				{2.38, 2.5, 16, 0},
			},
			zdist = {
				r = {0, 1},
				h = {0.8, 1},
				area = true,
			},
			radial = false,
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ColumnAura",
			texture = "fx_glow",
			rel = "r",
			hu = "H",
			direction = "Top",
			speed_h = {0.05, 0.1},
			lifetime = {0.5, 0.7},
			size = {
				{0, 36, 0},
				{0.5, 46.8, 0},
				{1, 50.4, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.84, 0},
				{0.7, 0.87, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{40, 80, 210},
				},
				{
					0.5,
					{25, 50, 160},
				},
				{
					1,
					{12, 25, 100},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = -6,
			zstream = {
				{0.5, 0.58, 4.9, 14},
				{0.58, 2.38, 14, 14},
				{2.38, 2.5, 14, 0},
			},
			zdist = {
				r = {0, 0.2},
				h = {0.05, 0.85},
				area = false,
			},
			radial = false,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "SurgeRing",
			texture = "kk_light_03",
			rel = "r",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed_h = {1.5, 1.5},
			lifetime = {0.65, 0.65},
			size = {
				{0, 50.4, 0},
				{1, 54, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.7, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{170, 220, 255},
				},
				{
					0.5,
					{90, 160, 255},
				},
				{
					1,
					{30, 70, 200},
				},
			},
			light_emission = 0.9,
			brightness = 1.3,
			zoffset = 2,
			ring_emit = {
				{0.95, 1, 0, 0, 1},
				{1.45, 1, 0, 0, 1},
				{1.95, 1, 0, 0, 1},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "SurgeStreaks",
			texture = "kk_trace_01",
			rel = "r",
			orientation = "VelocityParallel",
			direction = "Top",
			speed_h = {1.4, 2},
			lifetime = {0.3, 0.4},
			size = {
				{0, 6, 0},
				{0.3, 24, 0},
				{1, 14, 0},
			},
			color = {
				{
					0,
					{215, 240, 255},
				},
				{
					0.5,
					{120, 190, 255},
				},
				{
					1,
					{45, 100, 230},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			zoffset = 2,
			ring_emit = {
				{0.952, 1, 0.1166, 0.874, 0.949},
				{0.952, 1, 0.2319, 0.973, 2.016},
				{0.952, 1, 0.3567, 0.549, 3.54},
				{0.952, 1, 0.725, 0.907, 2.041},
				{0.956, 1, 0.0191, 0.773, 3.556},
				{0.956, 1, 0.9908, 0.782, 1.266},
				{0.961, 1, 0.2116, 0.567, 1.812},
				{0.968, 1, 0.6521, 0.766, 2.121},
				{0.969, 1, 0.2726, 0.811, 2.418},
				{0.97, 1, 0.8143, 0.991, 0.162},
				{0.975, 1, 0.585, 0.726, 1.88},
				{0.979, 1, 0.3576, 0.74, 2.143},
				{0.98, 1, 0.7829, 0.877, 0.716},
				{0.983, 1, 0.8655, 0.972, 3.536},
				{0.984, 1, 0.5612, 0.731, 1.231},
				{0.986, 1, 0.6363, 0.94, 2.002},
				{0.988, 1, 0.5508, 0.676, 2.384},
				{0.989, 1, 0.1554, 0.729, 2.89},
				{1.453, 1, 0.7658, 0.752, 2.989},
				{1.455, 1, 0.395, 0.887, 0.018},
				{1.456, 1, 0.1791, 0.908, 2.619},
				{1.456, 1, 0.9226, 0.93, 1.504},
				{1.457, 1, 0.6239, 0.619, 3.144},
				{1.458, 1, 0.0317, 0.524, 2.299},
				{1.462, 1, 0.4566, 0.587, 2.184},
				{1.462, 1, 0.7057, 0.601, 2.73},
				{1.464, 1, 0.618, 0.739, 1.139},
				{1.465, 1, 0.5458, 0.611, 1.542},
				{1.468, 1, 0.4959, 0.67, 3.715},
				{1.468, 1, 0.641, 0.779, 0.249},
				{1.471, 1, 0.8464, 0.885, 0.286},
				{1.474, 1, 0.5043, 0.612, 0.644},
				{1.476, 1, 0.2417, 0.709, 0.962},
				{1.478, 1, 0.1079, 0.581, 3.104},
				{1.482, 1, 0.644, 0.846, 2.138},
				{1.489, 1, 0.2621, 0.778, 1.28},
				{1.95, 1, 0.9117, 0.863, 3.197},
				{1.953, 1, 0.111, 0.823, 2.081},
				{1.954, 1, 0.9654, 0.554, 0.939},
				{1.958, 1, 0.1302, 0.587, 0.874},
				{1.962, 1, 0.9682, 0.928, 1.786},
				{1.963, 1, 0.1687, 0.793, 2.115},
				{1.964, 1, 0.2723, 0.849, 3.738},
				{1.97, 1, 0.2944, 0.883, 0.225},
				{1.97, 1, 0.4645, 0.599, 2.779},
				{1.97, 1, 0.7722, 0.643, 3.204},
				{1.972, 1, 0.5382, 0.997, 3.2},
				{1.977, 1, 0.9728, 0.809, 3.3},
				{1.978, 1, 0.0194, 0.812, 1.045},
				{1.98, 1, 0.1597, 0.529, 2.02},
				{1.986, 1, 0.2731, 0.741, 1.444},
				{1.986, 1, 0.4736, 0.781, 2.464},
				{1.988, 1, 0.1283, 0.628, 2.911},
				{1.988, 1, 0.4642, 0.776, 3.437},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "SurgePurple",
			texture = "kk_trace_01",
			rel = "r",
			orientation = "VelocityParallel",
			direction = "Top",
			speed_h = {1.4, 2},
			lifetime = {0.3, 0.4},
			size = {
				{0, 6, 0},
				{0.3, 24, 0},
				{1, 14, 0},
			},
			color = {
				{
					0,
					{225, 140, 255},
				},
				{
					0.4,
					{190, 70, 250},
				},
				{
					1,
					{115, 30, 200},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			zoffset = 2,
			ring_emit = {
				{0.955, 1, 0.0205, 0.684, 2.558},
				{0.955, 1, 0.2072, 0.545, 2.606},
				{0.956, 1, 0.8484, 0.926, 2.963},
				{0.962, 1, 0.1617, 0.966, 1.444},
				{0.968, 1, 0.0141, 0.707, 3.407},
				{0.97, 1, 0.3491, 0.829, 2.18},
				{0.973, 1, 0.2874, 0.995, 0.222},
				{0.977, 1, 0.8765, 0.759, 3.874},
				{0.982, 1, 0.3397, 0.657, 3.408},
				{0.982, 1, 0.6211, 0.895, 2.601},
				{1.451, 1, 0.8049, 0.981, 2.969},
				{1.456, 1, 0.2935, 0.707, 2.061},
				{1.456, 1, 0.6245, 0.921, 3.303},
				{1.46, 1, 0.1712, 0.948, 0.126},
				{1.471, 1, 0.4732, 0.9, 1.974},
				{1.483, 1, 0.775, 0.734, 0.702},
				{1.483, 1, 0.8996, 0.501, 2.992},
				{1.484, 1, 0.7869, 0.825, 3.176},
				{1.485, 1, 0.539, 0.788, 1.891},
				{1.487, 1, 0.5852, 0.518, 2.276},
				{1.95, 1, 0.3409, 0.556, 3.845},
				{1.956, 1, 0.3726, 0.548, 0.349},
				{1.965, 1, 0.0649, 0.795, 1.285},
				{1.966, 1, 0.6206, 0.903, 1.785},
				{1.966, 1, 0.6885, 0.988, 3.65},
				{1.967, 1, 0.9742, 0.71, 2.513},
				{1.974, 1, 0.4888, 0.886, 1.438},
				{1.976, 1, 0.8048, 0.974, 3.83},
				{1.978, 1, 0.9042, 0.707, 1.651},
				{1.981, 1, 0.7197, 0.791, 2.332},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "SurgeFlash",
			texture = "fx_glow",
			rel = "r",
			lifetime = {0.18, 0.18},
			size = {
				{0, 18, 0},
				{1, 25.2, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{235, 245, 255},
				},
				{
					0.25,
					{140, 200, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 1,
			brightness = 1.1,
			zoffset = 3,
			ring_emit = {
				{0.95, 1, 0, 0, 3},
				{1.45, 1, 0, 0, 3},
				{1.95, 1, 0, 0, 3},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "SurgeThunder",
			texture = "fx_thunder",
			rel = "h",
			hu = "H",
			orientation = "FacingCameraWorldUp",
			lifetime = {0.08, 0.12},
			size = {
				{0, 33.6, 0},
				{1, 36, 0},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.5,
					{150, 210, 255},
				},
				{
					1,
					{60, 120, 235},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {-10, 10},
			zoffset = 3,
			ring_emit = {
				{0.952, 1, 0.1561, 0.959, 0.228},
				{0.976, 1, 0.2563, 1.025, 0.299},
				{0.991, 1, 0.1908, 0.973, 0.424},
				{1.482, 1, 0.2403, 1.026, 0.648},
				{1.487, 1, 0.0992, 0.976, 0.507},
				{1.525, 1, 0.7425, 0.956, 0.108},
				{1.95, 1, 0.8437, 1.03, 0.333},
				{1.997, 1, 0.0937, 0.983, 0.518},
				{2.026, 1, 0.525, 1.015, 0.692},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "Bolts0",
			texture = "kk_spark_05",
			rel = "r",
			hu = "H",
			lifetime = {0.08, 0.12},
			size = {
				{0, 14, 4},
				{1, 20, 4},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.5,
					{150, 210, 255},
				},
				{
					1,
					{60, 120, 235},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			zoffset = 3,
			zstream = {
				{0.5, 0.58, 2.1, 6},
				{0.58, 2.38, 6, 6},
				{2.38, 2.5, 6, 0},
			},
			zdist = {
				r = {0.8, 1.05},
				h = {0, 0.8},
				area = false,
			},
			radial = false,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "Bolts1",
			texture = "kk_spark_06",
			rel = "r",
			hu = "H",
			lifetime = {0.08, 0.12},
			size = {
				{0, 14, 4},
				{1, 20, 4},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.5,
					{150, 210, 255},
				},
				{
					1,
					{60, 120, 235},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			zoffset = 3,
			zstream = {
				{0.5, 0.58, 2.1, 6},
				{0.58, 2.38, 6, 6},
				{2.38, 2.5, 6, 0},
			},
			zdist = {
				r = {0.8, 1.05},
				h = {0, 0.8},
				area = false,
			},
			radial = false,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "Arcs0",
			texture = "kk_twirl_01",
			rel = "r",
			hu = "H",
			direction = "Top",
			speed_h = {0.1, 0.2},
			lifetime = {0.4, 0.6},
			size = {
				{0, 10, 0},
				{0.5, 22, 0},
				{1, 26, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 235, 255},
				},
				{
					0.4,
					{110, 180, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-320, -220},
			zoffset = 2,
			zstream = {
				{0.5, 0.58, 2.45, 7},
				{0.58, 2.38, 7, 7},
				{2.38, 2.5, 7, 0},
			},
			zdist = {
				r = {0.7, 1},
				h = {0.05, 0.7},
				area = false,
			},
			radial = false,
			clear_at = 2.52,
			spin = 260,
			slots = 6,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "Arcs1",
			texture = "kk_twirl_02",
			rel = "r",
			hu = "H",
			direction = "Top",
			speed_h = {0.1, 0.2},
			lifetime = {0.4, 0.6},
			size = {
				{0, 10, 0},
				{0.5, 22, 0},
				{1, 26, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 150, 255},
				},
				{
					0.5,
					{190, 80, 235},
				},
				{
					1,
					{110, 40, 190},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-320, -220},
			zoffset = 2,
			zstream = {
				{0.5, 0.58, 2.45, 7},
				{0.58, 2.38, 7, 7},
				{2.38, 2.5, 7, 0},
			},
			zdist = {
				r = {0.7, 1},
				h = {0.05, 0.7},
				area = false,
			},
			radial = false,
			clear_at = 2.52,
			spin = 260,
			slots = 6,
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CollapseRush",
			texture = "kk_trace_01",
			rel = "r",
			hu = "H",
			orientation = "VelocityParallel",
			direction = "Top",
			speed_h = {3, 4.2},
			lifetime = {0.25, 0.35},
			size = {
				{0, 8, 0},
				{0.3, 36, 0},
				{1, 20, 0},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.35,
					{110, 185, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			zoffset = 3,
			ring_emit = {
				{2.46, 1, 0.6683, 0.796, 0.286},
				{2.461, 1, 0.0758, 0.344, 0.11},
				{2.462, 1, 0.0266, 0.335, 0.216},
				{2.463, 1, 0.834, 0.569, 0.174},
				{2.467, 1, 0.2491, 0.788, 0.008},
				{2.467, 1, 0.504, 0.75, 0.167},
				{2.47, 1, 0.261, 0.565, 0.023},
				{2.473, 1, 0.3046, 0.629, 0.103},
				{2.474, 1, 0.3075, 0.768, 0.273},
				{2.474, 1, 0.3607, 0.651, 0.264},
				{2.474, 1, 0.8782, 0.515, 0.058},
				{2.475, 1, 0.2892, 0.734, 0.053},
				{2.476, 1, 0.2871, 0.3, 0.232},
				{2.476, 1, 0.9017, 0.382, 0.295},
				{2.478, 1, 0.728, 0.489, 0.278},
				{2.479, 1, 0.748, 0.574, 0.12},
				{2.48, 1, 0.1805, 0.677, 0.208},
				{2.481, 1, 0.1383, 0.443, 0.29},
				{2.482, 1, 0.5783, 0.604, 0.227},
				{2.484, 1, 0.5516, 0.797, 0.27},
				{2.486, 1, 0.5468, 0.724, 0.155},
				{2.488, 1, 0.2106, 0.58, 0.136},
				{2.489, 1, 0.2173, 0.521, 0.155},
				{2.489, 1, 0.5719, 0.488, 0.006},
				{2.49, 1, 0.3004, 0.102, 0.094},
				{2.49, 1, 0.6739, 0.793, 0.251},
				{2.49, 1, 0.7721, 0.745, 0.229},
				{2.49, 1, 0.9837, 0.215, 0.103},
				{2.491, 1, 0.3653, 0.235, 0.105},
				{2.491, 1, 0.605, 0.727, 0.205},
				{2.491, 1, 0.6392, 0.277, 0.133},
				{2.494, 1, 0.1849, 0.203, 0.018},
				{2.495, 1, 0.3319, 0.379, 0.065},
				{2.496, 1, 0.6775, 0.266, 0.108},
				{2.498, 1, 0.6054, 0.607, 0.078},
				{2.501, 1, 0.1683, 0.168, 0.283},
				{2.504, 1, 0.5099, 0.468, 0.236},
				{2.506, 1, 0.1682, 0.544, 0.01},
				{2.506, 1, 0.7658, 0.541, 0.297},
				{2.507, 1, 0.2516, 0.2, 0.158},
				{2.509, 1, 0.5864, 0.327, 0.004},
				{2.51, 1, 0.7637, 0.689, 0.097},
				{2.511, 1, 0.4176, 0.606, 0.076},
				{2.511, 1, 0.6901, 0.788, 0.004},
				{2.512, 1, 0.455, 0.754, 0.259},
				{2.513, 1, 0.3963, 0.679, 0.279},
				{2.516, 1, 0.0726, 0.738, 0.122},
				{2.516, 1, 0.4163, 0.357, 0.039},
				{2.517, 1, 0.1423, 0.497, 0.28},
				{2.518, 1, 0.1548, 0.62, 0.053},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CollapseFlash",
			texture = "fx_glow",
			rel = "r",
			lifetime = {0.22, 0.22},
			size = {
				{0, 8, 0},
				{0.3, 32.4, 0},
				{1, 39.6, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.5, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					0.35,
					{110, 185, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			zoffset = 4,
			ring_emit = {
				{2.5, 1, 0, 0, 4},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CollapseRing",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.4, 0.4},
			size = {
				{0, 54.918, 0},
				{1, 158.652, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 235, 255},
				},
				{
					0.4,
					{110, 180, 255},
				},
				{
					1,
					{40, 90, 220},
				},
			},
			light_emission = 0.9,
			ring_emit = {
				{2.5, 1, 0, 0, 0.26},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CollapseStars",
			texture = "fx_spark002",
			rel = "r",
			hu = "H",
			direction = "Front",
			spread = {35, 35},
			pitch = 10,
			speed = {6, 18},
			drag = 1.5,
			lifetime = {0.8, 1.2},
			size = {
				{0, 0, 0},
				{0.15, 2.6, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 238, 255},
				},
				{
					1,
					{140, 190, 255},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			rotation = {0, 45},
			zoffset = 3,
			ring_emit = {
				{2.5, 1, 0.0607, 0.866, 0.459},
				{2.5, 1, 0.4155, 0.726, 0.428},
				{2.503, 1, 0.6135, 0.537, 0.371},
				{2.504, 1, 0.8551, 0.743, 0.021},
				{2.509, 1, 0.1523, 0.604, 0.492},
				{2.509, 1, 0.1789, 0.549, 0.651},
				{2.509, 1, 0.3793, 0.685, 0.103},
				{2.509, 1, 0.7592, 0.807, 0.5},
				{2.51, 1, 0.6101, 0.833, 0.388},
				{2.511, 1, 0.8219, 0.355, 0.26},
				{2.512, 1, 0.0858, 0.056, 0.584},
				{2.512, 1, 0.7026, 0.548, 0.444},
				{2.514, 1, 0.5272, 0.482, 0.535},
				{2.514, 1, 0.8772, 0.577, 0.117},
				{2.515, 1, 0.2958, 0.443, 0.205},
				{2.516, 1, 0.0467, 0.892, 0.495},
				{2.516, 1, 0.4796, 0.458, 0.732},
				{2.518, 1, 0.6089, 0.818, 0.786},
				{2.519, 1, 0.7907, 0.388, 0.696},
				{2.52, 1, 0.4789, 0.522, 0.42},
				{2.52, 1, 0.6648, 0.602, 0.207},
				{2.521, 1, 0.4214, 0.879, 0.064},
				{2.521, 1, 0.8188, 0.725, 0.689},
				{2.523, 1, 0.4096, 0.463, 0.181},
				{2.523, 1, 0.4859, 0.839, 0.731},
				{2.524, 1, 0.2691, 0.425, 0.082},
				{2.524, 1, 0.6638, 0.534, 0.338},
				{2.526, 1, 0.1612, 0.327, 0.483},
				{2.527, 1, 0.5099, 0.811, 0.148},
				{2.527, 1, 0.7342, 0.519, 0.79},
				{2.527, 1, 0.9447, 0.427, 0.545},
				{2.53, 1, 0.8379, 0.734, 0.419},
				{2.531, 1, 0.2362, 0.673, 0.025},
				{2.531, 1, 0.4793, 0.56, 0.047},
				{2.531, 1, 0.5199, 0.673, 0.222},
				{2.531, 1, 0.9813, 0.657, 0.519},
				{2.534, 1, 0.4129, 0.443, 0.124},
				{2.535, 1, 0.4068, 0.766, 0.666},
				{2.536, 1, 0.8111, 0.593, 0.233},
				{2.538, 1, 0.0655, 0.726, 0.688},
				{2.541, 1, 0.3035, 0.119, 0.783},
				{2.542, 1, 0.6961, 0.689, 0.379},
				{2.544, 1, 0.0461, 0.384, 0.742},
				{2.544, 1, 0.3408, 0.896, 0.302},
				{2.544, 1, 0.592, 0.674, 0.776},
				{2.548, 1, 0.3257, 0.737, 0.626},
			},
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CollapseTwinkle",
			texture = "kk_star_06",
			rel = "r",
			hu = "H",
			direction = "Front",
			spread = {35, 35},
			speed = {3, 10},
			drag = 1.5,
			lifetime = {0.9, 1.3},
			size = {
				{0, 0, 0},
				{0.08, 3.2, 0},
				{0.22, 1.4, 0},
				{0.38, 3.4, 0},
				{0.55, 1.2, 0},
				{0.72, 2.8, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 238, 255},
				},
				{
					1,
					{140, 190, 255},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			rotation = {0, 30},
			zoffset = 3,
			ring_emit = {
				{2.501, 1, 0.4522, 0.814, 0.558},
				{2.501, 1, 0.5767, 0.221, 0.504},
				{2.506, 1, 0.7597, 0.646, 0.565},
				{2.508, 1, 0.0486, 0.567, 0.514},
				{2.509, 1, 0.8281, 0.668, 0.147},
				{2.509, 1, 0.923, 0.022, 0.675},
				{2.513, 1, 0.3825, 0.897, 0.456},
				{2.513, 1, 0.9434, 0.447, 0.165},
				{2.515, 1, 0.3336, 0.449, 0.452},
				{2.515, 1, 0.701, 0.737, 0.455},
				{2.517, 1, 0.5143, 0.794, 0.635},
				{2.518, 1, 0.8212, 0.807, 0.356},
				{2.518, 1, 0.8697, 0.171, 0.53},
				{2.522, 1, 0.872, 0.607, 0.603},
				{2.524, 1, 0.0253, 0.205, 0.485},
				{2.529, 1, 0.5932, 0.687, 0.339},
				{2.533, 1, 0.0176, 0.566, 0.31},
				{2.533, 1, 0.1123, 0.888, 0.491},
				{2.533, 1, 0.3249, 0.663, 0.489},
				{2.533, 1, 0.3598, 0.675, 0.359},
				{2.535, 1, 0.9501, 0.435, 0.189},
				{2.538, 1, 0.8651, 0.357, 0.223},
				{2.539, 1, 0.2543, 0.687, 0.728},
				{2.544, 1, 0.6886, 0.176, 0.558},
			},
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundScar",
			texture = "kz_scorch",
			rel = "r",
			lifetime = {3.1, 3.1},
			rotation = {0, 360},
			size = {
				{0, 39.6, 0},
				{0.1, 47.7, 0},
				{1, 49.5, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.06, 0.5, 0},
				{0.75, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{8, 12, 36},
				},
				{
					1,
					{14, 20, 50},
				},
			},
			light_emission = 0,
			zoffset = -1,
			ring_emit = {
				{0.5, 1, 0, 0, 0.08},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
	},
	shake_ramp = {0, 2.5, 0.12, 1.3, 1.4},
	zone = {
		radius = 18,
		height = 120,
		charge = 0.5,
		collapse = 2.5,
	},
	lights = {
		{
			t = 0,
			h = 4,
			color = {60, 110, 255},
			brightness = 3,
			range = 40,
			rise = 0.5,
			hold = 0,
			fall = 0.25,
		},
		{
			t = 0.5,
			h = 6,
			color = {120, 190, 255},
			brightness = 9,
			range = 60,
			rise = 0.03,
			hold = 0.05,
			fall = 0.6,
		},
		{
			t = 0.5,
			h = 0.3,
			hu = "H",
			color = {50, 100, 255},
			brightness = 5,
			range = 60,
			rise = 0.1,
			hold = 1.8,
			fall = 0.4,
		},
		{
			t = 2.5,
			h = 4,
			color = {120, 190, 255},
			brightness = 5,
			range = 50,
			rise = 0.02,
			hold = 0.03,
			fall = 0.5,
		},
		{
			t = 0.95,
			h = 4,
			color = {90, 160, 255},
			brightness = 3,
			range = 45,
			rise = 0.02,
			hold = 0.03,
			fall = 0.3,
		},
		{
			t = 1.45,
			h = 4,
			color = {90, 160, 255},
			brightness = 3,
			range = 45,
			rise = 0.02,
			hold = 0.03,
			fall = 0.3,
		},
		{
			t = 1.95,
			h = 4,
			color = {90, 160, 255},
			brightness = 3,
			range = 45,
			rise = 0.02,
			hold = 0.03,
			fall = 0.3,
		},
	},
	cubes = {
		gravity = 160,
		bounce = 0.32,
		friction = 0.55,
		spin = {240, 820},
		rest = {0.5, 1.3},
		fade = 0.35,
		settle = 0.12,
		shrink = {0.16, 0.26},
		dissolve_time = {0.18, 0.6},
		color_var = {0.72, 1.08},
		dark = 0.15,
		neon_colors = {
			{110, 185, 255},
			{50, 110, 255},
			{170, 220, 255},
			{190, 80, 235},
		},
		groups = {
			{
				name = "Lift",
				mode = "lift",
				count = 26,
				t = {0.02, 0.2},
				r = {0.12, 0.9},
				size = {0.25, 1.1},
				skew = 1.8,
				lift = {0.8, 4},
				release = {0.5, 0.53},
				out = {18, 48},
				up = {45, 90},
				dissolve = 0.3,
			},
			{
				name = "Blast",
				mode = "blast",
				count = 150,
				t = {0.5, 0.56},
				r = {0.25, 1.05},
				size = {0.12, 1.3},
				skew = 2.8,
				out = {18, 62},
				up = {26, 80},
				dissolve = 0.35,
				neon = 0.1,
			},
			{
				name = "Vortex",
				mode = "vortex",
				count = 44,
				t = {0.6, 2.25},
				r = {0.95, 1.25},
				size = {0.15, 0.8},
				skew = 2.2,
				rise = {0.14, 0.26},
				orbit = {2.4, 3.8},
				top = {0.4, 0.85},
				release = 2.5,
			},
		},
		fx = {
			name = "CubeDissolve",
			texture = "fx_spark002",
			direction = "Top",
			spread = {180, 180},
			speed = {4, 12},
			lifetime = {0.25, 0.4},
			size = {
				{0, 0, 0},
				{0.2, 1.8, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 238, 255},
				},
				{
					1,
					{140, 190, 255},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			rotation = {0, 45},
			emit_n = 2,
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
	},
}

-- OMNÍVORA: elige una zona circular y brota un PILAR DE ENERGÍA cósmica (0.5 s de carga, 2 s de pilar) con destrucción de cubos. OmnivoraVFX.CosmicPillar(cf, radio, altura, escala, sacudida): cf = centro de la zona en el suelo.
-- radius = radio de la zona en studs (por defecto 18 × escala); height = altura del pilar (por defecto 120 × escala).
function OmnivoraVFX.CosmicPillar(cf: CFrame, radius: number?, height: number?, scale: number?, shake: number?): Part
	return playZone(SPEC_CosmicPillar, cf, scale, radius, height, shake)
end

return OmnivoraVFX
