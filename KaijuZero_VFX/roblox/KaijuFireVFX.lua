--!nonstrict
--[[
	KaijuFireVFX — VFX de fuego y lava para KAIJU ZERO
	(generado automáticamente desde vfx_specs.py; edita allí y regenera)

	USO (en el CLIENTE, por ejemplo al recibir un RemoteEvent del servidor):
		local KaijuFireVFX = require(ReplicatedStorage.KaijuFireVFX)
		-- cf = punto del SUELO bajo la explosión; 1 = escala; 1 = intensidad de la sacudida de cámara
		KaijuFireVFX.GiantExplosion(CFrame.new(puntoEnElSuelo), 1, 1)
		-- ULTIMATE: rayo de la boca al rival (o adonde lo apuntes con rayo:AimAt); se ignora al propio kaiju
		local rayo = KaijuFireVFX.UltimateBeam(bocaDeKaijuZero, rival, 1, 1, { modeloDeKaijuZero })
		-- golpes que recibe el rival: corte en garra (en diagonal), corte quemado y mordisco
		KaijuFireVFX.SlashHit(rival, 1, 1)
		KaijuFireVFX.BiteHit(rival, 1, 1)

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
	fx_burst_a = "rbxassetid://0",
	fx_burst_fan = "rbxassetid://0",
	fx_feather_4x4 = "rbxassetid://0",
	fx_fire_2x2 = "rbxassetid://0",
	fx_glow = "rbxassetid://0",
	fx_line = "rbxassetid://0",
	fx_line_curve = "rbxassetid://0",
	fx_shock_soft = "rbxassetid://0",
	fx_shock_spiky = "rbxassetid://0",
	fx_smoke_2x2 = "rbxassetid://0",
	fx_smoke_round = "rbxassetid://0",
	fx_spark4 = "rbxassetid://0",
	fx_star = "rbxassetid://0",
	fx_wind_lines = "rbxassetid://0",
	fx_wind_swirl = "rbxassetid://0",
	kk_circle_03 = "rbxassetid://0",
	kk_fire_01 = "rbxassetid://0",
	kk_fire_02 = "rbxassetid://0",
	kk_flare_01 = "rbxassetid://0",
	kk_muzzle_01 = "rbxassetid://0",
	kk_muzzle_03 = "rbxassetid://0",
	kk_muzzle_04 = "rbxassetid://0",
	kk_muzzle_05 = "rbxassetid://0",
	kk_scorch_02 = "rbxassetid://0",
	kk_smoke_04 = "rbxassetid://0",
	kk_smoke_07 = "rbxassetid://0",
	kk_smoke_08 = "rbxassetid://0",
	kk_smoke_10 = "rbxassetid://0",
	kk_spark_01 = "rbxassetid://0",
	kk_spark_02 = "rbxassetid://0",
	kk_star_06 = "rbxassetid://0",
	kk_trace_01 = "rbxassetid://0",
	kk_twirl_01 = "rbxassetid://0",
	kk_twirl_02 = "rbxassetid://0",
	kz_beam_core = "rbxassetid://0",
	kz_beam_flow = "rbxassetid://0",
	kz_beam_glow = "rbxassetid://0",
	kz_beam_ring = "rbxassetid://0",
	kz_bite_4x4 = "rbxassetid://0",
	kz_claw = "rbxassetid://0",
	kz_claw_4x4 = "rbxassetid://0",
	kz_claw_glow = "rbxassetid://0",
	kz_debris_2x2 = "rbxassetid://0",
	kz_lava_cracks = "rbxassetid://0",
	kz_lava_drop = "rbxassetid://0",
	kz_lava_glob_2x2 = "rbxassetid://0",
	kz_lava_pool = "rbxassetid://0",
	kz_lava_rock_2x2 = "rbxassetid://0",
	kz_lava_splat = "rbxassetid://0",
	kz_scorch = "rbxassetid://0",
}

-- Dónde se crean los efectos (puedes cambiarlo por una carpeta de VFX)
KaijuFireVFX.Parent = workspace :: Instance
-- Multiplicador de cantidad de partículas (bájalo en dispositivos lentos, p.ej. 0.6)
KaijuFireVFX.Quality = 1
-- Luz breve en el impacto (del color del efecto)
KaijuFireVFX.UseLight = true
-- Los golpes (corte, mordisco) se adaptan al alto del rival si le pasas su Model o su Part
KaijuFireVFX.HitAutoSize = true

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
local function landAt(L: Layer, holder: BasePart, s: number, worldPos: Vector3)
	-- un ancla quieta en el punto donde cayó: lo que arde ahí no se mueve aunque el contenedor se mueva
	local anchor = invisiblePart("Land", Vector3.new(0.2, 0.2, 0.2), CFrame.new(worldPos), holder)
	for _, LL in L.land do
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

-- lanza n rocas desde pos; groundY = altura del suelo donde caen
local function launchMeteors(L: Layer, holder: BasePart, s: number, n: number, pos: Vector3, groundY: number, frame: CFrame?)
	local accel = Vector3.new(L.accel[1], L.accel[2], L.accel[3]) * s
	local baseDir = ({
		Top = Vector3.yAxis, Bottom = -Vector3.yAxis, Front = -Vector3.zAxis, Back = Vector3.zAxis,
		Right = Vector3.xAxis, Left = -Vector3.xAxis,
	} :: any)[L.direction]
	local list = {}
	for i = 1, n do
		local spread = if L.direction == "Front" or L.direction == "Back"
			then CFrame.Angles(math.rad(rng:NextNumber(-L.spread[2], L.spread[2])),
				math.rad(rng:NextNumber(-L.spread[1], L.spread[1])), 0)
			else CFrame.Angles(math.rad(rng:NextNumber(-L.spread[1], L.spread[1])), 0,
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
			te.Rate = TL.rate * KaijuFireVFX.Quality
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

-- Sacudida continua que crece de i0 a i1 durante `duration` y se detiene al final (solo cliente).
-- power > 1 hace que crezca más hacia el final.
function KaijuFireVFX.ShakeRamp(i0: number, i1: number, duration: number, power: number?)
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

local function play(spec: Layer, cf: CFrame, scale: number?, length: number?, shake: number?, angle: number?,
	groundY: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local len = length or 0
	local tanH = math.tan(math.rad(math.clamp(angle or 60, 5, 170) / 2))
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf, KaijuFireVFX.Parent)
	for _, L in spec.layers do
		if L.at_ground then
			continue -- en el suelo bajo el impacto del rayo (las pone el rayo al pegar)
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
		local cam = workspace.CurrentCamera
		if r and cam then
			local seed = rng:NextNumber(0, 1000)
			local name = "KZBeamShake" .. tostring(rng:NextInteger(1, 1000000000))
			RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
				local tt = time() - t0
				if tt > math.min(r[2], stopAt or r[2]) or not holder.Parent then
					RunService:UnbindFromRenderStep(name)
					return
				end
				if tt < r[1] then
					return
				end
				local k = shake * (r[3] + (r[4] - r[3]) * ((tt - r[1]) / (r[2] - r[1])) ^ r[5])
				cam.CFrame = cam.CFrame * CFrame.Angles(math.noise(seed, tt * 24) * k * 0.03,
					math.noise(seed + 17, tt * 24) * k * 0.03, math.noise(seed + 31, tt * 16) * k * 0.015)
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
	zoneLights(spec, Z)
	return holder, Z
end

-- efecto en una zona circular: carga, erupción, pilar y colapso (+ cubos de destrucción)
local function _playZone(spec: Layer, cf: CFrame, scale: number?, radius: number?, height: number?, shake: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local holder = startZone(spec, cf, s, radius or spec.zone.radius * s, height or spec.zone.height * s, 8)
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
local function _playOrb(spec: Layer, mouth: any, targets: any, scale: number?, shake: number?, radius: number?): Part
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

local SPEC_GiantExplosion = {
	name = "GiantExplosion",
	duration = 5.8,
	cleanup = 7.2,
	layers = {
		{
			name = "FlashGlow",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			offset = {0, 6, 0},
			lifetime = {0.3, 0.3},
			size = {
				{0, 16, 0},
				{0.25, 50, 0},
				{1, 56, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 170, 70},
				},
				{
					0.4,
					{255, 120, 40},
				},
				{
					1,
					{210, 60, 18},
				},
			},
			light_emission = 1,
			brightness = 0.9,
			zoffset = 10,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FlashBurst",
			texture = "fx_burst_fan",
			emit = {
				{0, 2},
			},
			offset = {0, 5, 0},
			lifetime = {0.12, 0.15},
			size = {
				{0, 14, 0},
				{0.4, 38, 0},
				{1, 42, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 170, 80},
				},
				{
					1,
					{230, 80, 25},
				},
			},
			light_emission = 1,
			brightness = 1,
			rotation = {0, 360},
			zoffset = 11,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Glow",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			offset = {0, 10, 0},
			lifetime = {1.4, 1.4},
			size = {
				{0, 30, 0},
				{0.1, 80, 0},
				{1, 90, 0},
			},
			transparency = {
				{0, 0.45, 0},
				{0.4, 0.72, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 140, 55},
				},
				{
					1,
					{200, 60, 20},
				},
			},
			light_emission = 0.6,
			brightness = 0.9,
			zoffset = -12,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Scorch",
			texture = "kz_scorch",
			emit = {
				{0, 1},
			},
			offset = {0, 0.14, 0},
			lifetime = {5.6, 5.6},
			size = {
				{0, 12, 0},
				{0.03, 66, 0},
				{1, 70, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.8, 0.22, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			zoffset = -1,
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 255, 255},
				},
			},
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			line_u = 0,
		},
		{
			name = "LavaCracks",
			texture = "kz_lava_cracks",
			emit = {
				{0, 1},
			},
			offset = {0, 0.18, 0},
			lifetime = {5.4, 5.4},
			size = {
				{0, 20, 0},
				{0.05, 92, 0},
				{1, 98, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.7, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 110},
				},
				{
					0.1,
					{255, 150, 50},
				},
				{
					0.6,
					{230, 80, 25},
				},
				{
					1,
					{130, 34, 12},
				},
			},
			light_emission = 1,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaPool",
			texture = "kz_lava_pool",
			emit = {
				{0.02, 1},
			},
			offset = {0, 0.2, 0},
			lifetime = {5.5, 5.5},
			size = {
				{0, 10, 0},
				{0.03, 52, 0},
				{1, 56, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 110},
				},
				{
					0.08,
					{255, 160, 55},
				},
				{
					0.55,
					{235, 96, 30},
				},
				{
					0.85,
					{170, 50, 18},
				},
				{
					1,
					{90, 26, 12},
				},
			},
			light_emission = 1,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "HeatRing",
			texture = "kk_circle_03",
			emit = {
				{0, 1},
			},
			offset = {0, 0.3, 0},
			lifetime = {0.45, 0.45},
			size = {
				{0, 20, 0},
				{0.3, 70, 0},
				{1, 120, 0},
			},
			transparency = {
				{0, 0.55, 0},
				{0.4, 0.78, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 60},
				},
				{
					1,
					{220, 70, 25},
				},
			},
			light_emission = 0.4,
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
			line_u = 0,
		},
		{
			name = "DustWave",
			texture = "kk_smoke_07",
			emit = {
				{0.02, 32},
			},
			offset = {0, 2.5, 0},
			direction = "Front",
			spread = {180, 3},
			speed = {95, 150},
			drag = 3.6,
			accel = {0, 6, 0},
			lifetime = {1.1, 1.5},
			size = {
				{0, 9, 2},
				{0.3, 22, 4},
				{1, 30, 5},
			},
			transparency = {
				{0, 0.45, 0},
				{0.15, 0.25, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{128, 100, 84},
				},
				{
					0.5,
					{106, 92, 84},
				},
				{
					1,
					{96, 90, 86},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -3,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "MagmaCore",
			texture = "kk_fire_02",
			emit = {
				{0, 3},
				{0.06, 2},
			},
			offset = {0, 6, 0},
			speed = {0, 5},
			direction = "Top",
			spread = {180, 180},
			lifetime = {0.4, 0.5},
			size = {
				{0, 10, 3},
				{0.3, 24, 4},
				{1, 26, 4},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 200, 110},
				},
				{
					0.3,
					{255, 140, 45},
				},
				{
					1,
					{225, 70, 20},
				},
			},
			light_emission = 0.4,
			brightness = 1.2,
			rotation = {0, 360},
			rot_speed = {-80, 80},
			zoffset = 3,
			accel = {0, 0, 0},
			drag = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "MagmaBurst",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 6},
				{0.05, 4},
			},
			offset = {0, 6, 0},
			shape = {
				type = "Sphere",
				radius = 6,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {18, 36},
			drag = 3,
			accel = {0, 8, 0},
			lifetime = {0.5, 0.75},
			size = {
				{0, 8, 2},
				{0.3, 18, 3},
				{1, 20, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 140},
				},
				{
					0.15,
					{255, 170, 60},
				},
				{
					0.4,
					{250, 120, 30},
				},
				{
					0.75,
					{225, 70, 15},
				},
				{
					1,
					{190, 50, 12},
				},
			},
			light_emission = 0.25,
			brightness = 1.35,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaFountain",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 44},
				{0.05, 32},
				{0.12, 20},
				{0.2, 12},
			},
			offset = {0, 4, 0},
			direction = "Top",
			spread = {18, 18},
			speed = {90, 150},
			drag = 0.5,
			accel = {0, -140, 0},
			lifetime = {1, 1.4},
			size = {
				{0, 3, 1.05},
				{0.2, 6, 1.8},
				{1, 4, 1.2},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			transparency = {
				{0, 0, 0},
				{0.75, 0.05, 0},
				{1, 1, 0},
			},
			light_emission = 0.55,
			brightness = 1.45,
			rotation = {0, 360},
			rot_speed = {-220, 220},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaCrown",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 60},
				{0.04, 28},
			},
			offset = {0, 2, 0},
			direction = "Top",
			spread = {75, 75},
			speed = {40, 85},
			drag = 0.5,
			accel = {0, -150, 0},
			lifetime = {0.7, 1},
			size = {
				{0, 2, 0.7},
				{0.2, 3.6, 1.08},
				{1, 2.6, 0.78},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			transparency = {
				{0, 0, 0},
				{0.75, 0.05, 0},
				{1, 1, 0},
			},
			light_emission = 0.55,
			brightness = 1.45,
			rotation = {0, 360},
			rot_speed = {-220, 220},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaDrops",
			texture = "kz_lava_drop",
			orientation = "VelocityParallel",
			emit = {
				{0, 60},
				{0.06, 30},
			},
			offset = {0, 4, 0},
			direction = "Top",
			spread = {70, 70},
			speed = {80, 140},
			drag = 0.5,
			accel = {0, -150, 0},
			lifetime = {0.5, 0.8},
			size = {
				{0, 2.5, 0.6},
				{0.3, 4.5, 1},
				{1, 3, 0.6},
			},
			color = {
				{
					0,
					{255, 220, 140},
				},
				{
					0.15,
					{255, 170, 60},
				},
				{
					0.4,
					{250, 120, 30},
				},
				{
					0.75,
					{225, 70, 15},
				},
				{
					1,
					{190, 50, 12},
				},
			},
			transparency = {
				{0, 0, 0},
				{0.75, 0.05, 0},
				{1, 1, 0},
			},
			light_emission = 0.6,
			brightness = 1.5,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaChunks",
			texture = "kz_debris_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 36},
				{0.05, 14},
			},
			offset = {0, 4, 0},
			direction = "Top",
			spread = {65, 65},
			speed = {60, 120},
			drag = 0.4,
			accel = {0, -140, 0},
			lifetime = {0.8, 1.3},
			size = {
				{0, 1.6, 0.6},
				{1, 1.4, 0.5},
			},
			color = {
				{
					0,
					{150, 70, 40},
				},
				{
					0.3,
					{92, 44, 30},
				},
				{
					1,
					{60, 34, 26},
				},
			},
			light_emission = 0.1,
			rotation = {0, 360},
			rot_speed = {-400, 400},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "MagmaJets",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			emit = {
				{0.01, 12},
				{0.07, 6},
			},
			offset = {0, 6, 0},
			direction = "Top",
			spread = {100, 100},
			speed = {60, 100},
			drag = 6,
			accel = {0, -10, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 8, 2},
				{0.3, 22, 4},
				{1, 18, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 166, 50},
				},
				{
					0.7,
					{240, 90, 20},
				},
				{
					1,
					{160, 40, 12},
				},
			},
			light_emission = 0.3,
			brightness = 1.6,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "AshPlume",
			texture = "kk_smoke_07",
			emit = {
				{0.15, 6},
				{0.3, 6},
				{0.5, 5},
				{0.75, 4},
			},
			offset = {0, 22, 0},
			shape = {
				type = "Box",
				size = {14, 26, 14},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {35, 35},
			speed = {12, 24},
			drag = 1.2,
			accel = {0, 9, 0},
			lifetime = {2, 2.6},
			size = {
				{0, 20, 4},
				{0.4, 40, 6},
				{1, 54, 6},
			},
			transparency = {
				{0, 0.55, 0},
				{0.12, 0.36, 0},
				{0.6, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -12,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "AshPlume2",
			texture = "kk_smoke_08",
			emit = {
				{0.2, 5},
				{0.45, 4},
				{0.7, 3},
			},
			offset = {0, 34, 0},
			shape = {
				type = "Sphere",
				radius = 12,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {60, 60},
			speed = {10, 20},
			drag = 1.2,
			accel = {0, 8, 0},
			lifetime = {1.9, 2.4},
			size = {
				{0, 22, 4},
				{0.4, 42, 6},
				{1, 56, 6},
			},
			transparency = {
				{0, 0.55, 0},
				{0.12, 0.34, 0},
				{0.6, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -12,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "AshBase",
			texture = "kk_smoke_04",
			emit = {
				{0.1, 6},
				{0.3, 5},
			},
			offset = {0, 8, 0},
			shape = {
				type = "Box",
				size = {16, 10, 16},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {8, 16},
			drag = 1.2,
			accel = {0, 7, 0},
			lifetime = {1.5, 2},
			size = {
				{0, 14, 3},
				{0.5, 26, 4},
				{1, 32, 4},
			},
			transparency = {
				{0, 0.5, 0},
				{0.2, 0.3, 0},
				{0.7, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -11,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "MoltenRocks",
			type = "meteor",
			emit = {
				{0.02, 16},
			},
			offset = {0, 4, 0},
			direction = "Top",
			spread = {58, 58},
			speed = {70, 118},
			accel = {0, -120, 0},
			drag = 0.2,
			lifetime = {1.4, 1.8},
			trails = {
				{
					name = "RockGlow",
					rate = 60,
					locked = true,
					texture = "fx_glow",
					speed = {0, 0},
					direction = "Top",
					lifetime = {0.075, 0.075},
					size = {
						{0, 6.5, 0.8},
						{1, 6.5, 0.8},
					},
					color = {
						{
							0,
							{255, 80, 10},
						},
						{
							1,
							{255, 80, 10},
						},
					},
					transparency = {
						{0, 0.92, 0},
						{1, 0.92, 0},
					},
					light_emission = 1,
					brightness = 1,
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
					name = "RockDrip",
					rate = 26,
					texture = "kz_lava_glob_2x2",
					flipbook = {
						layout = "Grid2x2",
						mode = "Loop",
						fps = 0.001,
						startRandom = true,
					},
					speed = {0, 3},
					direction = "Top",
					spread = {180, 180},
					accel = {0, -70, 0},
					lifetime = {0.35, 0.55},
					size = {
						{0, 1.6, 0.4},
						{1, 0.8, 0.2},
					},
					color = {
						{
							0,
							{255, 214, 120},
						},
						{
							0.2,
							{255, 150, 40},
						},
						{
							0.55,
							{240, 90, 18},
						},
						{
							1,
							{185, 44, 12},
						},
					},
					light_emission = 0.4,
					brightness = 1.5,
					rotation = {0, 360},
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
					name = "RockEmbers",
					rate = 34,
					texture = "kk_flare_01",
					speed = {0, 3},
					direction = "Top",
					spread = {180, 180},
					lifetime = {0.25, 0.45},
					size = {
						{0, 0, 0},
						{0.15, 2.4, 0.6},
						{1, 0, 0},
					},
					color = {
						{
							0,
							{255, 225, 130},
						},
						{
							0.5,
							{255, 140, 40},
						},
						{
							1,
							{220, 60, 15},
						},
					},
					light_emission = 1,
					brightness = 1.7,
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
					name = "RockSmoke",
					rate = 24,
					texture = "kk_smoke_04",
					speed = {1, 4},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					accel = {0, 6, 0},
					lifetime = {0.55, 0.85},
					size = {
						{0, 3, 0.8},
						{1, 9, 2},
					},
					transparency = {
						{0, 0.35, 0},
						{0.6, 0.55, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 130, 50},
						},
						{
							0.06,
							{130, 74, 50},
						},
						{
							0.2,
							{78, 64, 58},
						},
						{
							0.6,
							{92, 84, 80},
						},
						{
							1,
							{112, 106, 102},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
			},
			land = {
				{
					name = "RockSplat",
					texture = "kz_lava_splat",
					emit = {
						{0, 1},
					},
					lifetime = {3, 3},
					size = {
						{0, 2, 0},
						{0.04, 11, 0},
						{1, 12, 0},
					},
					transparency = {
						{0, 0, 0},
						{0.8, 0.2, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 190, 80},
						},
						{
							0.3,
							{245, 120, 35},
						},
						{
							0.75,
							{170, 48, 16},
						},
						{
							1,
							{80, 26, 14},
						},
					},
					light_emission = 1,
					rotation = {0, 360},
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
				},
				{
					name = "RockSplash",
					texture = "kz_lava_glob_2x2",
					flipbook = {
						layout = "Grid2x2",
						mode = "Loop",
						fps = 0.001,
						startRandom = true,
					},
					emit = {
						{0, 8},
					},
					direction = "Top",
					spread = {60, 60},
					speed = {14, 28},
					accel = {0, -110, 0},
					drag = 0.5,
					lifetime = {0.4, 0.65},
					size = {
						{0, 1.2, 0.3},
						{0.3, 2.2, 0.5},
						{1, 1.4, 0.4},
					},
					color = {
						{
							0,
							{255, 214, 120},
						},
						{
							0.2,
							{255, 150, 40},
						},
						{
							0.55,
							{240, 90, 18},
						},
						{
							1,
							{185, 44, 12},
						},
					},
					light_emission = 0.4,
					brightness = 1.5,
					rotation = {0, 360},
					transparency = {
						{0, 0, 0},
						{1, 0, 0},
					},
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
				{
					name = "RockBurn",
					texture = "kk_muzzle_05",
					orientation = "VelocityParallel",
					direction = "Top",
					spread = {10, 10},
					speed = {3, 7},
					drag = 2,
					lifetime = {0.3, 0.5},
					size = {
						{0, 1.2, 0.4},
						{0.3, 4, 0.8},
						{1, 2.5, 0.6},
					},
					transparency = {
						{0, 0, 0},
						{0.6, 0.15, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 236, 150},
						},
						{
							0.3,
							{255, 166, 50},
						},
						{
							0.7,
							{240, 90, 20},
						},
						{
							1,
							{160, 40, 12},
						},
					},
					light_emission = 0.4,
					brightness = 1.5,
					stream = {
						{0, 2.5, 8, 0},
					},
					accel = {0, 0, 0},
					rotation = {0, 0},
					rot_speed = {0, 0},
					zoffset = 0,
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
				{
					name = "RockWisp",
					texture = "kk_smoke_04",
					direction = "Top",
					spread = {15, 15},
					speed = {4, 9},
					drag = 1.2,
					accel = {0, 5, 0},
					lifetime = {1, 1.4},
					size = {
						{0, 2, 0.6},
						{1, 7, 2},
					},
					transparency = {
						{0, 0.6, 0},
						{0.3, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 130, 50},
						},
						{
							0.06,
							{130, 74, 50},
						},
						{
							0.2,
							{78, 64, 58},
						},
						{
							0.6,
							{92, 84, 80},
						},
						{
							1,
							{112, 106, 102},
						},
					},
					rotation = {0, 360},
					stream = {
						{0.1, 2.6, 2.5, 0.5},
					},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
			},
			rock = {
				size = {2.8, 4.4},
				spin = {-480, 480},
				material = "CrackedLava",
				color = {150, 62, 32},
			},
		},
		{
			name = "RainSplats",
			texture = "kz_lava_splat",
			points = {
				{0.751, 1, -12.98, 0.24, -11.81},
				{0.818, 1, -23.26, 0.24, -31.58},
				{0.833, 1, 19.54, 0.24, 30.62},
				{0.879, 1, 13.73, 0.24, -14.36},
				{0.88, 1, -12.84, 0.24, -6.44},
				{0.924, 1, 38.19, 0.24, -4.24},
				{0.929, 1, 38.17, 0.24, -8.14},
				{1.076, 1, -20.51, 0.24, 4.04},
				{1.157, 1, 28.25, 0.24, -6.97},
				{1.164, 1, 11.31, 0.24, 38.73},
				{1.209, 1, -7.3, 0.24, 38.98},
				{1.227, 1, -24.91, 0.24, -24.26},
				{1.303, 1, 32.47, 0.24, -12.28},
				{1.316, 1, 26.59, 0.24, 4.9},
			},
			lifetime = {3.4, 3.4},
			size = {
				{0, 2, 0},
				{0.04, 9, 0},
				{1, 10, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 190, 80},
				},
				{
					0.3,
					{245, 120, 35},
				},
				{
					0.75,
					{170, 48, 16},
				},
				{
					1,
					{80, 26, 14},
				},
			},
			light_emission = 1,
			rotation = {0, 360},
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
			name = "Embers",
			texture = "kk_flare_01",
			emit = {
				{0.05, 40},
				{0.3, 30},
				{0.6, 22},
				{1, 14},
			},
			offset = {0, 10, 0},
			shape = {
				type = "Sphere",
				radius = 14,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {120, 120},
			speed = {10, 35},
			drag = 1.5,
			accel = {0, 14, 0},
			lifetime = {0.9, 1.5},
			size = {
				{0, 0, 0},
				{0.1, 2.6, 0.8},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 225, 130},
				},
				{
					0.5,
					{255, 140, 40},
				},
				{
					1,
					{220, 60, 15},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Sparks",
			texture = "fx_line",
			orientation = "VelocityParallel",
			offset = {0, 6, 0},
			emit = {
				{0, 22},
				{0.06, 10},
			},
			direction = "Top",
			spread = {180, 180},
			speed = {110, 200},
			drag = 4,
			accel = {0, -60, 0},
			lifetime = {0.3, 0.5},
			size = {
				{0, 16, 4},
				{1, 5, 0},
			},
			color = {
				{
					0,
					{255, 220, 130},
				},
				{
					0.5,
					{255, 160, 50},
				},
				{
					1,
					{240, 90, 20},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaPatch0",
			texture = "kz_lava_pool",
			emit = {
				{0.2, 1},
			},
			offset = {0, 0.22, 0},
			lifetime = {5, 5},
			size = {
				{0, 4, 0},
				{0.05, 26, 0},
				{1, 27, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 110},
				},
				{
					0.08,
					{255, 160, 55},
				},
				{
					0.55,
					{235, 96, 30},
				},
				{
					0.85,
					{170, 50, 18},
				},
				{
					1,
					{90, 26, 12},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles0",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {0, 0.6, 0},
			shape = {
				type = "Box",
				size = {10, 0.2, 10},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {12, 26},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 1.2, 0.2},
				{0.3, 3, 0.4},
				{1, 2, 0.3},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 9, 3},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaLick0",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {0, 0.5, 0},
			shape = {
				type = "Box",
				size = {10, 0.2, 10},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {6, 14},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 3, 0.5},
				{0.3, 9, 1},
				{1, 6, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 166, 50},
				},
				{
					0.7,
					{240, 90, 20},
				},
				{
					1,
					{160, 40, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			stream = {
				{0.2, 4.7, 5, 1},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaHeat0",
			texture = "kk_flare_01",
			offset = {0, 1.5, 0},
			shape = {
				type = "Box",
				size = {10, 1, 10},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 225, 130},
				},
				{
					0.5,
					{255, 140, 40},
				},
				{
					1,
					{220, 60, 15},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 1},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaSmoke0",
			texture = "kk_smoke_04",
			offset = {0, 2.5, 0},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 6, 2},
				{1, 24, 6},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 2.5, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaSpurts",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0.8, 7},
				{1.35, 7},
				{1.9, 7},
				{2.6, 7},
				{3.3, 7},
				{4, 7},
				{4.6, 7},
			},
			offset = {0, 1, 0},
			direction = "Top",
			spread = {22, 22},
			speed = {22, 42},
			drag = 0.5,
			accel = {0, -110, 0},
			lifetime = {0.6, 0.9},
			size = {
				{0, 1.5, 0.525},
				{0.2, 3.2, 0.96},
				{1, 2.2, 0.66},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			transparency = {
				{0, 0, 0},
				{0.75, 0.05, 0},
				{1, 1, 0},
			},
			light_emission = 0.55,
			brightness = 1.45,
			rotation = {0, 360},
			rot_speed = {-220, 220},
			shape = {
				type = "Box",
				size = {8, 0.5, 8},
				style = "Volume",
				inout = "Outward",
			},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaPatch1",
			texture = "kz_lava_pool",
			emit = {
				{0.25, 1},
			},
			offset = {2.9988, 0.22, 24.6326},
			lifetime = {5, 5},
			size = {
				{0, 2.0325, 0},
				{0.05, 13.2109, 0},
				{1, 13.719, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 110},
				},
				{
					0.08,
					{255, 160, 55},
				},
				{
					0.55,
					{235, 96, 30},
				},
				{
					0.85,
					{170, 50, 18},
				},
				{
					1,
					{90, 26, 12},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles1",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {2.9988, 0.6, 24.6326},
			shape = {
				type = "Box",
				size = {5.0811, 0.2, 5.0811},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {6.0974, 13.2109},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.6097, 0.2},
				{0.3, 1.5243, 0.4},
				{1, 1.0162, 0.3},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 9, 3},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaLick1",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {2.9988, 0.5, 24.6326},
			shape = {
				type = "Box",
				size = {5.0811, 0.2, 5.0811},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {3.0487, 7.1136},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 1.5243, 0.5},
				{0.3, 4.573, 1},
				{1, 3.0487, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 166, 50},
				},
				{
					0.7,
					{240, 90, 20},
				},
				{
					1,
					{160, 40, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			stream = {
				{0.2, 4.7, 5, 1},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaHeat1",
			texture = "kk_flare_01",
			offset = {2.9988, 1.5, 24.6326},
			shape = {
				type = "Box",
				size = {5.0811, 1, 5.0811},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 225, 130},
				},
				{
					0.5,
					{255, 140, 40},
				},
				{
					1,
					{220, 60, 15},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 1},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaSmoke1",
			texture = "kk_smoke_04",
			offset = {2.9988, 2.5, 24.6326},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 3.0487, 1.0162},
				{1, 12.1947, 3.0487},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 2.5, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaPatch2",
			texture = "kz_lava_pool",
			emit = {
				{0.3, 1},
			},
			offset = {-29.071, 0.22, -15.4951},
			lifetime = {5, 5},
			size = {
				{0, 2.7662, 0},
				{0.05, 17.9802, 0},
				{1, 18.6718, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 110},
				},
				{
					0.08,
					{255, 160, 55},
				},
				{
					0.55,
					{235, 96, 30},
				},
				{
					0.85,
					{170, 50, 18},
				},
				{
					1,
					{90, 26, 12},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles2",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {-29.071, 0.6, -15.4951},
			shape = {
				type = "Box",
				size = {6.9155, 0.2, 6.9155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {8.2986, 17.9802},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.8299, 0.2},
				{0.3, 2.0746, 0.4},
				{1, 1.3831, 0.3},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 9, 3},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaLick2",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {-29.071, 0.5, -15.4951},
			shape = {
				type = "Box",
				size = {6.9155, 0.2, 6.9155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.1493, 9.6817},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 2.0746, 0.5},
				{0.3, 6.2239, 1},
				{1, 4.1493, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 166, 50},
				},
				{
					0.7,
					{240, 90, 20},
				},
				{
					1,
					{160, 40, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			stream = {
				{0.2, 4.7, 5, 1},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaHeat2",
			texture = "kk_flare_01",
			offset = {-29.071, 1.5, -15.4951},
			shape = {
				type = "Box",
				size = {6.9155, 1, 6.9155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 225, 130},
				},
				{
					0.5,
					{255, 140, 40},
				},
				{
					1,
					{220, 60, 15},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 1},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaSmoke2",
			texture = "kk_smoke_04",
			offset = {-29.071, 2.5, -15.4951},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 4.1493, 1.3831},
				{1, 16.5971, 4.1493},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 2.5, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaPatch3",
			texture = "kz_lava_pool",
			emit = {
				{0.35, 1},
			},
			offset = {-20.72, 0.22, 18.6067},
			lifetime = {5, 5},
			size = {
				{0, 2.8243, 0},
				{0.05, 18.3578, 0},
				{1, 19.0638, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 110},
				},
				{
					0.08,
					{255, 160, 55},
				},
				{
					0.55,
					{235, 96, 30},
				},
				{
					0.85,
					{170, 50, 18},
				},
				{
					1,
					{90, 26, 12},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles3",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {-20.72, 0.6, 18.6067},
			shape = {
				type = "Box",
				size = {7.0607, 0.2, 7.0607},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {8.4728, 18.3578},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.8473, 0.2},
				{0.3, 2.1182, 0.4},
				{1, 1.4121, 0.3},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 9, 3},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaLick3",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {-20.72, 0.5, 18.6067},
			shape = {
				type = "Box",
				size = {7.0607, 0.2, 7.0607},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.2364, 9.885},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 2.1182, 0.5},
				{0.3, 6.3546, 1},
				{1, 4.2364, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 166, 50},
				},
				{
					0.7,
					{240, 90, 20},
				},
				{
					1,
					{160, 40, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			stream = {
				{0.2, 4.7, 5, 1},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaHeat3",
			texture = "kk_flare_01",
			offset = {-20.72, 1.5, 18.6067},
			shape = {
				type = "Box",
				size = {7.0607, 1, 7.0607},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 225, 130},
				},
				{
					0.5,
					{255, 140, 40},
				},
				{
					1,
					{220, 60, 15},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 1},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaSmoke3",
			texture = "kk_smoke_04",
			offset = {-20.72, 2.5, 18.6067},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 4.2364, 1.4121},
				{1, 16.9456, 4.2364},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 2.5, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaPatch4",
			texture = "kz_lava_pool",
			emit = {
				{0.4, 1},
			},
			offset = {5.4987, 0.22, -27.6806},
			lifetime = {5, 5},
			size = {
				{0, 2.7262, 0},
				{0.05, 17.7204, 0},
				{1, 18.4019, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 110},
				},
				{
					0.08,
					{255, 160, 55},
				},
				{
					0.55,
					{235, 96, 30},
				},
				{
					0.85,
					{170, 50, 18},
				},
				{
					1,
					{90, 26, 12},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles4",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {5.4987, 0.6, -27.6806},
			shape = {
				type = "Box",
				size = {6.8155, 0.2, 6.8155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {8.1786, 17.7204},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.8179, 0.2},
				{0.3, 2.0447, 0.4},
				{1, 1.3631, 0.3},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 9, 3},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaLick4",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {5.4987, 0.5, -27.6806},
			shape = {
				type = "Box",
				size = {6.8155, 0.2, 6.8155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.0893, 9.5417},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 2.0447, 0.5},
				{0.3, 6.134, 1},
				{1, 4.0893, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 166, 50},
				},
				{
					0.7,
					{240, 90, 20},
				},
				{
					1,
					{160, 40, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			stream = {
				{0.2, 4.7, 5, 1},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaHeat4",
			texture = "kk_flare_01",
			offset = {5.4987, 1.5, -27.6806},
			shape = {
				type = "Box",
				size = {6.8155, 1, 6.8155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 225, 130},
				},
				{
					0.5,
					{255, 140, 40},
				},
				{
					1,
					{220, 60, 15},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 1},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaSmoke4",
			texture = "kk_smoke_04",
			offset = {5.4987, 2.5, -27.6806},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 4.0893, 1.3631},
				{1, 16.3573, 4.0893},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 2.5, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaPatch5",
			texture = "kz_lava_pool",
			emit = {
				{0.45, 1},
			},
			offset = {-29.6959, 0.22, 11.8883},
			lifetime = {5, 5},
			size = {
				{0, 2.0171, 0},
				{0.05, 13.1109, 0},
				{1, 13.6152, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 110},
				},
				{
					0.08,
					{255, 160, 55},
				},
				{
					0.55,
					{235, 96, 30},
				},
				{
					0.85,
					{170, 50, 18},
				},
				{
					1,
					{90, 26, 12},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles5",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {-29.6959, 0.6, 11.8883},
			shape = {
				type = "Box",
				size = {5.0427, 0.2, 5.0427},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {6.0512, 13.1109},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.6051, 0.2},
				{0.3, 1.5128, 0.4},
				{1, 1.0085, 0.3},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 9, 3},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaLick5",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {-29.6959, 0.5, 11.8883},
			shape = {
				type = "Box",
				size = {5.0427, 0.2, 5.0427},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {3.0256, 7.0597},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 1.5128, 0.5},
				{0.3, 4.5384, 1},
				{1, 3.0256, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 166, 50},
				},
				{
					0.7,
					{240, 90, 20},
				},
				{
					1,
					{160, 40, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			stream = {
				{0.2, 4.7, 5, 1},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaHeat5",
			texture = "kk_flare_01",
			offset = {-29.6959, 1.5, 11.8883},
			shape = {
				type = "Box",
				size = {5.0427, 1, 5.0427},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 225, 130},
				},
				{
					0.5,
					{255, 140, 40},
				},
				{
					1,
					{220, 60, 15},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 1},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaSmoke5",
			texture = "kk_smoke_04",
			offset = {-29.6959, 2.5, 11.8883},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 3.0256, 1.0085},
				{1, 12.1024, 3.0256},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 2.5, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaPatch6",
			texture = "kz_lava_pool",
			emit = {
				{0.5, 1},
			},
			offset = {-3.2365, 0.22, -19.0166},
			lifetime = {5, 5},
			size = {
				{0, 2.0345, 0},
				{0.05, 13.2243, 0},
				{1, 13.733, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 110},
				},
				{
					0.08,
					{255, 160, 55},
				},
				{
					0.55,
					{235, 96, 30},
				},
				{
					0.85,
					{170, 50, 18},
				},
				{
					1,
					{90, 26, 12},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles6",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {-3.2365, 0.6, -19.0166},
			shape = {
				type = "Box",
				size = {5.0863, 0.2, 5.0863},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {6.1035, 13.2243},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.6104, 0.2},
				{0.3, 1.5259, 0.4},
				{1, 1.0173, 0.3},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 9, 3},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaLick6",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {-3.2365, 0.5, -19.0166},
			shape = {
				type = "Box",
				size = {5.0863, 0.2, 5.0863},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {3.0518, 7.1208},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 1.5259, 0.5},
				{0.3, 4.5777, 1},
				{1, 3.0518, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 166, 50},
				},
				{
					0.7,
					{240, 90, 20},
				},
				{
					1,
					{160, 40, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			stream = {
				{0.2, 4.7, 5, 1},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaHeat6",
			texture = "kk_flare_01",
			offset = {-3.2365, 1.5, -19.0166},
			shape = {
				type = "Box",
				size = {5.0863, 1, 5.0863},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 225, 130},
				},
				{
					0.5,
					{255, 140, 40},
				},
				{
					1,
					{220, 60, 15},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 1},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaSmoke6",
			texture = "kk_smoke_04",
			offset = {-3.2365, 2.5, -19.0166},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 3.0518, 1.0173},
				{1, 12.2071, 3.0518},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 2.5, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaPatch7",
			texture = "kz_lava_pool",
			emit = {
				{0.55, 1},
			},
			offset = {-21.3471, 0.22, -20.2424},
			lifetime = {5, 5},
			size = {
				{0, 1.8833, 0},
				{0.05, 12.2414, 0},
				{1, 12.7123, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 110},
				},
				{
					0.08,
					{255, 160, 55},
				},
				{
					0.55,
					{235, 96, 30},
				},
				{
					0.85,
					{170, 50, 18},
				},
				{
					1,
					{90, 26, 12},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles7",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {-21.3471, 0.6, -20.2424},
			shape = {
				type = "Box",
				size = {4.7082, 0.2, 4.7082},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {5.6499, 12.2414},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.565, 0.2},
				{0.3, 1.4125, 0.4},
				{1, 0.9416, 0.3},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 9, 3},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaLick7",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {-21.3471, 0.5, -20.2424},
			shape = {
				type = "Box",
				size = {4.7082, 0.2, 4.7082},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {2.8249, 6.5915},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 1.4125, 0.5},
				{0.3, 4.2374, 1},
				{1, 2.8249, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 166, 50},
				},
				{
					0.7,
					{240, 90, 20},
				},
				{
					1,
					{160, 40, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			stream = {
				{0.2, 4.7, 5, 1},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaHeat7",
			texture = "kk_flare_01",
			offset = {-21.3471, 1.5, -20.2424},
			shape = {
				type = "Box",
				size = {4.7082, 1, 4.7082},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 225, 130},
				},
				{
					0.5,
					{255, 140, 40},
				},
				{
					1,
					{220, 60, 15},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 1},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaSmoke7",
			texture = "kk_smoke_04",
			offset = {-21.3471, 2.5, -20.2424},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 2.8249, 0.9416},
				{1, 11.2998, 2.8249},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 2.5, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaPatch8",
			texture = "kz_lava_pool",
			emit = {
				{0.6, 1},
			},
			offset = {30.5851, 0.22, 6.4354},
			lifetime = {5, 5},
			size = {
				{0, 3.0136, 0},
				{0.05, 19.5887, 0},
				{1, 20.3421, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 110},
				},
				{
					0.08,
					{255, 160, 55},
				},
				{
					0.55,
					{235, 96, 30},
				},
				{
					0.85,
					{170, 50, 18},
				},
				{
					1,
					{90, 26, 12},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles8",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {30.5851, 0.6, 6.4354},
			shape = {
				type = "Box",
				size = {7.5341, 0.2, 7.5341},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {9.0409, 19.5887},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.9041, 0.2},
				{0.3, 2.2602, 0.4},
				{1, 1.5068, 0.3},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 9, 3},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaLick8",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {30.5851, 0.5, 6.4354},
			shape = {
				type = "Box",
				size = {7.5341, 0.2, 7.5341},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.5205, 10.5478},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 2.2602, 0.5},
				{0.3, 6.7807, 1},
				{1, 4.5205, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 166, 50},
				},
				{
					0.7,
					{240, 90, 20},
				},
				{
					1,
					{160, 40, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.5,
			stream = {
				{0.2, 4.7, 5, 1},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaHeat8",
			texture = "kk_flare_01",
			offset = {30.5851, 1.5, 6.4354},
			shape = {
				type = "Box",
				size = {7.5341, 1, 7.5341},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 225, 130},
				},
				{
					0.5,
					{255, 140, 40},
				},
				{
					1,
					{220, 60, 15},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 1},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "LavaSmoke8",
			texture = "kk_smoke_04",
			offset = {30.5851, 2.5, 6.4354},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 4.5205, 1.5068},
				{1, 18.0819, 4.5205},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 2.5, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
	},
	light = {
		color = {255, 130, 45},
		brightness = 6,
		range = 60,
		time = 1.4,
	},
}

-- Explosión GIGANTE DE LAVA: el suelo se abre en grietas de magma, brota un charco de lava, una fuente de magma llueve gotas que se enfrían y salpican, vuelan rocas fundidas (CrackedLava) que gotean lava, sube humo volcánico y la lava queda viva en el suelo 5 s. Cierra limpio: lo último se apaga a los 6.9 s.
function KaijuFireVFX.GiantExplosion(cf: CFrame, scale: number?, shake: number?): Part
	return play(SPEC_GiantExplosion, cf, scale, nil, shake)
end

local SPEC_GiantExplosionIgnition = {
	name = "GiantExplosionIgnition",
	duration = 5.8,
	cleanup = 7.2,
	layers = {
		{
			name = "FlashGlow",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			offset = {0, 6, 0},
			lifetime = {0.3, 0.3},
			size = {
				{0, 16, 0},
				{0.25, 50, 0},
				{1, 56, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 103, 115},
				},
				{
					0.4,
					{255, 44, 60},
				},
				{
					1,
					{195, 12, 31},
				},
			},
			light_emission = 1,
			brightness = 1.17,
			zoffset = 10,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FlashBurst",
			texture = "fx_burst_fan",
			emit = {
				{0, 2},
			},
			offset = {0, 5, 0},
			lifetime = {0.12, 0.15},
			size = {
				{0, 14, 0},
				{0.4, 38, 0},
				{1, 42, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 103, 115},
				},
				{
					1,
					{221, 20, 39},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			rotation = {0, 360},
			zoffset = 11,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Glow",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			offset = {0, 10, 0},
			lifetime = {1.4, 1.4},
			size = {
				{0, 30, 0},
				{0.1, 80, 0},
				{1, 90, 0},
			},
			transparency = {
				{0, 0.45, 0},
				{0.4, 0.72, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 61, 76},
				},
				{
					1,
					{183, 12, 31},
				},
			},
			light_emission = 0.6,
			brightness = 1.17,
			zoffset = -12,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Scorch",
			texture = "kz_scorch",
			emit = {
				{0, 1},
			},
			offset = {0, 0.14, 0},
			lifetime = {5.6, 5.6},
			size = {
				{0, 12, 0},
				{0.03, 66, 0},
				{1, 70, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.8, 0.22, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			zoffset = -1,
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 255, 255},
				},
			},
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			line_u = 0,
		},
		{
			name = "LavaCracks",
			texture = "kz_lava_cracks",
			emit = {
				{0, 1},
			},
			offset = {0, 0.18, 0},
			lifetime = {5.4, 5.4},
			size = {
				{0, 20, 0},
				{0.05, 92, 0},
				{1, 98, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.7, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 92, 105},
				},
				{
					0.1,
					{217, 35, 47},
				},
				{
					0.6,
					{188, 10, 21},
				},
				{
					1,
					{89, 4, 15},
				},
			},
			light_emission = 1,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaPool",
			texture = "kz_lava_pool",
			emit = {
				{0.02, 1},
			},
			offset = {0, 0.2, 0},
			lifetime = {5.5, 5.5},
			size = {
				{0, 10, 0},
				{0.03, 52, 0},
				{1, 56, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.85, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 92, 105},
				},
				{
					0.08,
					{217, 44, 55},
				},
				{
					0.55,
					{194, 14, 25},
				},
				{
					0.85,
					{125, 6, 16},
				},
				{
					1,
					{57, 3, 14},
				},
			},
			light_emission = 1,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "HeatRing",
			texture = "kk_circle_03",
			emit = {
				{0, 1},
			},
			offset = {0, 0.3, 0},
			lifetime = {0.45, 0.45},
			size = {
				{0, 20, 0},
				{0.3, 70, 0},
				{1, 120, 0},
			},
			transparency = {
				{0, 0.65, 0},
				{0.4, 0.88, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 35, 47},
				},
				{
					1,
					{177, 8, 19},
				},
			},
			light_emission = 0.4,
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
			line_u = 0,
		},
		{
			name = "DustWave",
			texture = "kk_smoke_07",
			emit = {
				{0.02, 48},
			},
			offset = {0, 2.5, 0},
			direction = "Front",
			spread = {180, 3},
			speed = {95, 150},
			drag = 3.6,
			accel = {0, 6, 0},
			lifetime = {1.1, 1.5},
			size = {
				{0, 9, 2},
				{0.3, 22, 4},
				{1, 30, 5},
			},
			transparency = {
				{0, 0.45, 0},
				{0.15, 0.25, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{96, 68, 59},
				},
				{
					0.5,
					{80, 63, 59},
				},
				{
					1,
					{73, 61, 60},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -3,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "MagmaCore",
			texture = "kk_fire_02",
			emit = {
				{0, 4},
				{0.06, 3},
			},
			offset = {0, 6, 0},
			speed = {0, 5},
			direction = "Top",
			spread = {180, 180},
			lifetime = {0.4, 0.5},
			size = {
				{0, 10, 3},
				{0.3, 24, 4},
				{1, 26, 4},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 242, 242},
				},
				{
					0.35,
					{255, 172, 178},
				},
				{
					1,
					{220, 40, 60},
				},
			},
			light_emission = 0.4,
			brightness = 1.56,
			rotation = {0, 360},
			rot_speed = {-80, 80},
			zoffset = 3,
			accel = {0, 0, 0},
			drag = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "MagmaBurst",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 9},
				{0.05, 6},
			},
			offset = {0, 6, 0},
			shape = {
				type = "Sphere",
				radius = 6,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {18, 36},
			drag = 3,
			accel = {0, 8, 0},
			lifetime = {0.5, 0.75},
			size = {
				{0, 8, 2},
				{0.3, 18, 3},
				{1, 20, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 246},
				},
				{
					0.2,
					{255, 202, 206},
				},
				{
					0.45,
					{255, 96, 110},
				},
				{
					0.75,
					{220, 36, 56},
				},
				{
					1,
					{170, 20, 40},
				},
			},
			light_emission = 0.25,
			brightness = 1.755,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaFountain",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 66},
				{0.05, 48},
				{0.12, 30},
				{0.2, 18},
			},
			offset = {0, 4, 0},
			direction = "Top",
			spread = {18, 18},
			speed = {90, 150},
			drag = 0.5,
			accel = {0, -140, 0},
			lifetime = {1, 1.4},
			size = {
				{0, 3, 1.05},
				{0.2, 6, 1.8},
				{1, 4, 1.2},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			transparency = {
				{0, 0, 0},
				{0.75, 0.05, 0},
				{1, 1, 0},
			},
			light_emission = 0.55,
			brightness = 1.885,
			rotation = {0, 360},
			rot_speed = {-220, 220},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaCrown",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 90},
				{0.04, 42},
			},
			offset = {0, 2, 0},
			direction = "Top",
			spread = {75, 75},
			speed = {40, 85},
			drag = 0.5,
			accel = {0, -150, 0},
			lifetime = {0.7, 1},
			size = {
				{0, 2, 0.7},
				{0.2, 3.6, 1.08},
				{1, 2.6, 0.78},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			transparency = {
				{0, 0, 0},
				{0.75, 0.05, 0},
				{1, 1, 0},
			},
			light_emission = 0.55,
			brightness = 1.885,
			rotation = {0, 360},
			rot_speed = {-220, 220},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaDrops",
			texture = "kz_lava_drop",
			orientation = "VelocityParallel",
			emit = {
				{0, 90},
				{0.06, 45},
			},
			offset = {0, 4, 0},
			direction = "Top",
			spread = {70, 70},
			speed = {80, 140},
			drag = 0.5,
			accel = {0, -150, 0},
			lifetime = {0.5, 0.8},
			size = {
				{0, 2.5, 0.6},
				{0.3, 4.5, 1},
				{1, 3, 0.6},
			},
			color = {
				{
					0,
					{255, 205, 209},
				},
				{
					0.15,
					{255, 103, 115},
				},
				{
					0.4,
					{248, 44, 60},
				},
				{
					0.75,
					{214, 16, 35},
				},
				{
					1,
					{171, 11, 30},
				},
			},
			transparency = {
				{0, 0, 0},
				{0.75, 0.05, 0},
				{1, 1, 0},
			},
			light_emission = 0.6,
			brightness = 1.95,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaChunks",
			texture = "kz_debris_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 54},
				{0.05, 21},
			},
			offset = {0, 4, 0},
			direction = "Top",
			spread = {65, 65},
			speed = {60, 120},
			drag = 0.4,
			accel = {0, -140, 0},
			lifetime = {0.8, 1.3},
			size = {
				{0, 1.6, 0.6},
				{1, 1.4, 0.5},
			},
			color = {
				{
					0,
					{125, 16, 35},
				},
				{
					0.3,
					{68, 10, 29},
				},
				{
					1,
					{42, 8, 28},
				},
			},
			light_emission = 0.1,
			rotation = {0, 360},
			rot_speed = {-400, 400},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "MagmaJets",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			emit = {
				{0.01, 18},
				{0.07, 9},
			},
			offset = {0, 6, 0},
			direction = "Top",
			spread = {100, 100},
			speed = {60, 100},
			drag = 6,
			accel = {0, -10, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 8, 2},
				{0.3, 22, 4},
				{1, 18, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 228, 230},
				},
				{
					0.3,
					{255, 97, 109},
				},
				{
					0.7,
					{234, 24, 42},
				},
				{
					1,
					{136, 9, 28},
				},
			},
			light_emission = 0.3,
			brightness = 2.08,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "AshPlume",
			texture = "kk_smoke_07",
			emit = {
				{0.15, 9},
				{0.3, 9},
				{0.5, 8},
				{0.75, 6},
			},
			offset = {0, 22, 0},
			shape = {
				type = "Box",
				size = {14, 26, 14},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {35, 35},
			speed = {12, 24},
			drag = 1.2,
			accel = {0, 9, 0},
			lifetime = {2, 2.6},
			size = {
				{0, 20, 4},
				{0.4, 40, 6},
				{1, 54, 6},
			},
			transparency = {
				{0, 0.55, 0},
				{0.12, 0.36, 0},
				{0.6, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -12,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "AshPlume2",
			texture = "kk_smoke_08",
			emit = {
				{0.2, 8},
				{0.45, 6},
				{0.7, 4},
			},
			offset = {0, 34, 0},
			shape = {
				type = "Sphere",
				radius = 12,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {60, 60},
			speed = {10, 20},
			drag = 1.2,
			accel = {0, 8, 0},
			lifetime = {1.9, 2.4},
			size = {
				{0, 22, 4},
				{0.4, 42, 6},
				{1, 56, 6},
			},
			transparency = {
				{0, 0.55, 0},
				{0.12, 0.34, 0},
				{0.6, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -12,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "AshBase",
			texture = "kk_smoke_04",
			emit = {
				{0.1, 9},
				{0.3, 8},
			},
			offset = {0, 8, 0},
			shape = {
				type = "Box",
				size = {16, 10, 16},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {8, 16},
			drag = 1.2,
			accel = {0, 7, 0},
			lifetime = {1.5, 2},
			size = {
				{0, 14, 3},
				{0.5, 26, 4},
				{1, 32, 4},
			},
			transparency = {
				{0, 0.5, 0},
				{0.2, 0.3, 0},
				{0.7, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -11,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "MoltenRocks",
			type = "meteor",
			emit = {
				{0.02, 24},
			},
			offset = {0, 4, 0},
			direction = "Top",
			spread = {58, 58},
			speed = {70, 118},
			accel = {0, -120, 0},
			drag = 0.2,
			lifetime = {1.4, 1.8},
			trails = {
				{
					name = "RockGlow",
					rate = 60,
					locked = true,
					texture = "fx_glow",
					speed = {0, 0},
					direction = "Top",
					lifetime = {0.075, 0.075},
					size = {
						{0, 6.5, 0.8},
						{1, 6.5, 0.8},
					},
					color = {
						{
							0,
							{255, 20, 39},
						},
						{
							1,
							{255, 20, 39},
						},
					},
					transparency = {
						{0, 0.92, 0},
						{1, 0.92, 0},
					},
					light_emission = 1,
					brightness = 1.3,
					emit = {},
					spread = {0, 0},
					accel = {0, 0, 0},
					drag = 0,
					rotation = {0, 0},
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
				{
					name = "RockDrip",
					rate = 26,
					texture = "kz_lava_glob_2x2",
					flipbook = {
						layout = "Grid2x2",
						mode = "Loop",
						fps = 0.001,
						startRandom = true,
					},
					speed = {0, 3},
					direction = "Top",
					spread = {180, 180},
					accel = {0, -70, 0},
					lifetime = {0.35, 0.55},
					size = {
						{0, 1.6, 0.4},
						{1, 0.8, 0.2},
					},
					color = {
						{
							0,
							{255, 193, 198},
						},
						{
							0.2,
							{255, 70, 85},
						},
						{
							0.55,
							{234, 24, 42},
						},
						{
							1,
							{165, 10, 29},
						},
					},
					light_emission = 0.4,
					brightness = 1.95,
					rotation = {0, 360},
					emit = {},
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
				},
				{
					name = "RockEmbers",
					rate = 34,
					texture = "kk_flare_01",
					speed = {0, 3},
					direction = "Top",
					spread = {180, 180},
					lifetime = {0.25, 0.45},
					size = {
						{0, 0, 0},
						{0.15, 2.4, 0.6},
						{1, 0, 0},
					},
					color = {
						{
							0,
							{255, 215, 218},
						},
						{
							0.5,
							{255, 61, 76},
						},
						{
							1,
							{208, 12, 31},
						},
					},
					light_emission = 1,
					brightness = 2.21,
					emit = {},
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
				},
				{
					name = "RockSmoke",
					rate = 24,
					texture = "kk_smoke_04",
					speed = {1, 4},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					accel = {0, 6, 0},
					lifetime = {0.55, 0.85},
					size = {
						{0, 3, 0.8},
						{1, 9, 2},
					},
					transparency = {
						{0, 0.35, 0},
						{0.6, 0.55, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 53, 68},
						},
						{
							0.06,
							{105, 18, 36},
						},
						{
							0.2,
							{60, 44, 41},
						},
						{
							0.6,
							{70, 57, 56},
						},
						{
							1,
							{85, 72, 71},
						},
					},
					rotation = {0, 360},
					emit = {},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			land = {
				{
					name = "RockSplat",
					texture = "kz_lava_splat",
					emit = {
						{0, 1},
					},
					lifetime = {3, 3},
					size = {
						{0, 2, 0},
						{0.04, 11, 0},
						{1, 12, 0},
					},
					transparency = {
						{0, 0.1, 0},
						{0.8, 0.3, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{217, 71, 83},
						},
						{
							0.3,
							{205, 22, 33},
						},
						{
							0.75,
							{125, 5, 16},
						},
						{
							1,
							{49, 3, 14},
						},
					},
					light_emission = 1,
					rotation = {0, 360},
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
				},
				{
					name = "RockSplash",
					texture = "kz_lava_glob_2x2",
					flipbook = {
						layout = "Grid2x2",
						mode = "Loop",
						fps = 0.001,
						startRandom = true,
					},
					emit = {
						{0, 12},
					},
					direction = "Top",
					spread = {60, 60},
					speed = {14, 28},
					accel = {0, -110, 0},
					drag = 0.5,
					lifetime = {0.4, 0.65},
					size = {
						{0, 1.2, 0.3},
						{0.3, 2.2, 0.5},
						{1, 1.4, 0.4},
					},
					color = {
						{
							0,
							{255, 193, 198},
						},
						{
							0.2,
							{255, 70, 85},
						},
						{
							0.55,
							{234, 24, 42},
						},
						{
							1,
							{165, 10, 29},
						},
					},
					light_emission = 0.4,
					brightness = 1.95,
					rotation = {0, 360},
					transparency = {
						{0, 0, 0},
						{1, 0, 0},
					},
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
				{
					name = "RockBurn",
					texture = "kk_muzzle_05",
					orientation = "VelocityParallel",
					direction = "Top",
					spread = {10, 10},
					speed = {3, 7},
					drag = 2,
					lifetime = {0.3, 0.5},
					size = {
						{0, 1.2, 0.4},
						{0.3, 4, 0.8},
						{1, 2.5, 0.6},
					},
					transparency = {
						{0, 0, 0},
						{0.6, 0.15, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 228, 230},
						},
						{
							0.3,
							{255, 97, 109},
						},
						{
							0.7,
							{234, 24, 42},
						},
						{
							1,
							{136, 9, 28},
						},
					},
					light_emission = 0.4,
					brightness = 1.95,
					stream = {
						{0, 2.5, 12, 0},
					},
					emit = {},
					accel = {0, 0, 0},
					rotation = {0, 0},
					rot_speed = {0, 0},
					zoffset = 0,
					offset = {0, 0, 0},
					line_u = 0,
				},
				{
					name = "RockWisp",
					texture = "kk_smoke_04",
					direction = "Top",
					spread = {15, 15},
					speed = {4, 9},
					drag = 1.2,
					accel = {0, 5, 0},
					lifetime = {1, 1.4},
					size = {
						{0, 2, 0.6},
						{1, 7, 2},
					},
					transparency = {
						{0, 0.6, 0},
						{0.3, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 53, 68},
						},
						{
							0.06,
							{105, 18, 36},
						},
						{
							0.2,
							{60, 44, 41},
						},
						{
							0.6,
							{70, 57, 56},
						},
						{
							1,
							{85, 72, 71},
						},
					},
					rotation = {0, 360},
					stream = {
						{0.1, 2.6, 3.75, 0.75},
					},
					emit = {},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			rock = {
				size = {2.8, 4.4},
				spin = {-480, 480},
				material = "CrackedLava",
				color = {125, 13, 32},
			},
		},
		{
			name = "RainSplats",
			texture = "kz_lava_splat",
			points = {
				{0.751, 1, -12.98, 0.24, -11.81},
				{0.818, 1, -23.26, 0.24, -31.58},
				{0.833, 1, 19.54, 0.24, 30.62},
				{0.879, 1, 13.73, 0.24, -14.36},
				{0.88, 1, -12.84, 0.24, -6.44},
				{0.924, 1, 38.19, 0.24, -4.24},
				{0.929, 1, 38.17, 0.24, -8.14},
				{1.076, 1, -20.51, 0.24, 4.04},
				{1.157, 1, 28.25, 0.24, -6.97},
				{1.164, 1, 11.31, 0.24, 38.73},
				{1.209, 1, -7.3, 0.24, 38.98},
				{1.227, 1, -24.91, 0.24, -24.26},
				{1.303, 1, 32.47, 0.24, -12.28},
				{1.316, 1, 26.59, 0.24, 4.9},
			},
			lifetime = {3.4, 3.4},
			size = {
				{0, 2, 0},
				{0.04, 9, 0},
				{1, 10, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 71, 83},
				},
				{
					0.3,
					{205, 22, 33},
				},
				{
					0.75,
					{125, 5, 16},
				},
				{
					1,
					{49, 3, 14},
				},
			},
			light_emission = 1,
			rotation = {0, 360},
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
			name = "Embers",
			texture = "kk_flare_01",
			emit = {
				{0.05, 60},
				{0.3, 45},
				{0.6, 33},
				{1, 21},
			},
			offset = {0, 10, 0},
			shape = {
				type = "Sphere",
				radius = 14,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {120, 120},
			speed = {10, 35},
			drag = 1.5,
			accel = {0, 14, 0},
			lifetime = {0.9, 1.5},
			size = {
				{0, 0, 0},
				{0.1, 2.6, 0.8},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 215, 218},
				},
				{
					0.5,
					{255, 61, 76},
				},
				{
					1,
					{208, 12, 31},
				},
			},
			light_emission = 1,
			brightness = 2.21,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Sparks",
			texture = "fx_line",
			orientation = "VelocityParallel",
			offset = {0, 6, 0},
			emit = {
				{0, 33},
				{0.06, 15},
			},
			direction = "Top",
			spread = {180, 180},
			speed = {110, 200},
			drag = 4,
			accel = {0, -60, 0},
			lifetime = {0.3, 0.5},
			size = {
				{0, 16, 4},
				{1, 5, 0},
			},
			color = {
				{
					0,
					{255, 205, 209},
				},
				{
					0.5,
					{255, 87, 100},
				},
				{
					1,
					{234, 24, 42},
				},
			},
			light_emission = 1,
			brightness = 1.95,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaPatch0",
			texture = "kz_lava_pool",
			emit = {
				{0.2, 1},
			},
			offset = {0, 0.22, 0},
			lifetime = {5, 5},
			size = {
				{0, 4, 0},
				{0.05, 26, 0},
				{1, 27, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 92, 105},
				},
				{
					0.08,
					{217, 44, 55},
				},
				{
					0.55,
					{194, 14, 25},
				},
				{
					0.85,
					{125, 6, 16},
				},
				{
					1,
					{57, 3, 14},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles0",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {0, 0.6, 0},
			shape = {
				type = "Box",
				size = {10, 0.2, 10},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {12, 26},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 1.2, 0.2},
				{0.3, 3, 0.4},
				{1, 2, 0.3},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 13.5, 4.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaLick0",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {0, 0.5, 0},
			shape = {
				type = "Box",
				size = {10, 0.2, 10},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {6, 14},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 3, 0.5},
				{0.3, 9, 1},
				{1, 6, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 228, 230},
				},
				{
					0.3,
					{255, 97, 109},
				},
				{
					0.7,
					{234, 24, 42},
				},
				{
					1,
					{136, 9, 28},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			stream = {
				{0.2, 4.7, 7.5, 1.5},
			},
			emit = {},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaHeat0",
			texture = "kk_flare_01",
			offset = {0, 1.5, 0},
			shape = {
				type = "Box",
				size = {10, 1, 10},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 215, 218},
				},
				{
					0.5,
					{255, 61, 76},
				},
				{
					1,
					{208, 12, 31},
				},
			},
			light_emission = 1,
			brightness = 2.08,
			stream = {
				{0.3, 5, 7.5, 1.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaSmoke0",
			texture = "kk_smoke_04",
			offset = {0, 2.5, 0},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 6, 2},
				{1, 24, 6},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 3.75, 1.2},
			},
			emit = {},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaSpurts",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0.8, 10},
				{1.35, 10},
				{1.9, 10},
				{2.6, 10},
				{3.3, 10},
				{4, 10},
				{4.6, 10},
			},
			offset = {0, 1, 0},
			direction = "Top",
			spread = {22, 22},
			speed = {22, 42},
			drag = 0.5,
			accel = {0, -110, 0},
			lifetime = {0.6, 0.9},
			size = {
				{0, 1.5, 0.525},
				{0.2, 3.2, 0.96},
				{1, 2.2, 0.66},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			transparency = {
				{0, 0, 0},
				{0.75, 0.05, 0},
				{1, 1, 0},
			},
			light_emission = 0.55,
			brightness = 1.885,
			rotation = {0, 360},
			rot_speed = {-220, 220},
			shape = {
				type = "Box",
				size = {8, 0.5, 8},
				style = "Volume",
				inout = "Outward",
			},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaPatch1",
			texture = "kz_lava_pool",
			emit = {
				{0.25, 1},
			},
			offset = {2.9988, 0.22, 24.6326},
			lifetime = {5, 5},
			size = {
				{0, 2.0325, 0},
				{0.05, 13.2109, 0},
				{1, 13.719, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 92, 105},
				},
				{
					0.08,
					{217, 44, 55},
				},
				{
					0.55,
					{194, 14, 25},
				},
				{
					0.85,
					{125, 6, 16},
				},
				{
					1,
					{57, 3, 14},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles1",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {2.9988, 0.6, 24.6326},
			shape = {
				type = "Box",
				size = {5.0811, 0.2, 5.0811},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {6.0974, 13.2109},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.6097, 0.2},
				{0.3, 1.5243, 0.4},
				{1, 1.0162, 0.3},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 13.5, 4.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaLick1",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {2.9988, 0.5, 24.6326},
			shape = {
				type = "Box",
				size = {5.0811, 0.2, 5.0811},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {3.0487, 7.1136},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 1.5243, 0.5},
				{0.3, 4.573, 1},
				{1, 3.0487, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 228, 230},
				},
				{
					0.3,
					{255, 97, 109},
				},
				{
					0.7,
					{234, 24, 42},
				},
				{
					1,
					{136, 9, 28},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			stream = {
				{0.2, 4.7, 7.5, 1.5},
			},
			emit = {},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaHeat1",
			texture = "kk_flare_01",
			offset = {2.9988, 1.5, 24.6326},
			shape = {
				type = "Box",
				size = {5.0811, 1, 5.0811},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 215, 218},
				},
				{
					0.5,
					{255, 61, 76},
				},
				{
					1,
					{208, 12, 31},
				},
			},
			light_emission = 1,
			brightness = 2.08,
			stream = {
				{0.3, 5, 7.5, 1.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaSmoke1",
			texture = "kk_smoke_04",
			offset = {2.9988, 2.5, 24.6326},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 3.0487, 1.0162},
				{1, 12.1947, 3.0487},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 3.75, 1.2},
			},
			emit = {},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaPatch2",
			texture = "kz_lava_pool",
			emit = {
				{0.3, 1},
			},
			offset = {-29.071, 0.22, -15.4951},
			lifetime = {5, 5},
			size = {
				{0, 2.7662, 0},
				{0.05, 17.9802, 0},
				{1, 18.6718, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 92, 105},
				},
				{
					0.08,
					{217, 44, 55},
				},
				{
					0.55,
					{194, 14, 25},
				},
				{
					0.85,
					{125, 6, 16},
				},
				{
					1,
					{57, 3, 14},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles2",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {-29.071, 0.6, -15.4951},
			shape = {
				type = "Box",
				size = {6.9155, 0.2, 6.9155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {8.2986, 17.9802},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.8299, 0.2},
				{0.3, 2.0746, 0.4},
				{1, 1.3831, 0.3},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 13.5, 4.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaLick2",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {-29.071, 0.5, -15.4951},
			shape = {
				type = "Box",
				size = {6.9155, 0.2, 6.9155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.1493, 9.6817},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 2.0746, 0.5},
				{0.3, 6.2239, 1},
				{1, 4.1493, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 228, 230},
				},
				{
					0.3,
					{255, 97, 109},
				},
				{
					0.7,
					{234, 24, 42},
				},
				{
					1,
					{136, 9, 28},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			stream = {
				{0.2, 4.7, 7.5, 1.5},
			},
			emit = {},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaHeat2",
			texture = "kk_flare_01",
			offset = {-29.071, 1.5, -15.4951},
			shape = {
				type = "Box",
				size = {6.9155, 1, 6.9155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 215, 218},
				},
				{
					0.5,
					{255, 61, 76},
				},
				{
					1,
					{208, 12, 31},
				},
			},
			light_emission = 1,
			brightness = 2.08,
			stream = {
				{0.3, 5, 7.5, 1.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaSmoke2",
			texture = "kk_smoke_04",
			offset = {-29.071, 2.5, -15.4951},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 4.1493, 1.3831},
				{1, 16.5971, 4.1493},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 3.75, 1.2},
			},
			emit = {},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaPatch3",
			texture = "kz_lava_pool",
			emit = {
				{0.35, 1},
			},
			offset = {-20.72, 0.22, 18.6067},
			lifetime = {5, 5},
			size = {
				{0, 2.8243, 0},
				{0.05, 18.3578, 0},
				{1, 19.0638, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 92, 105},
				},
				{
					0.08,
					{217, 44, 55},
				},
				{
					0.55,
					{194, 14, 25},
				},
				{
					0.85,
					{125, 6, 16},
				},
				{
					1,
					{57, 3, 14},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles3",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {-20.72, 0.6, 18.6067},
			shape = {
				type = "Box",
				size = {7.0607, 0.2, 7.0607},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {8.4728, 18.3578},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.8473, 0.2},
				{0.3, 2.1182, 0.4},
				{1, 1.4121, 0.3},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 13.5, 4.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaLick3",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {-20.72, 0.5, 18.6067},
			shape = {
				type = "Box",
				size = {7.0607, 0.2, 7.0607},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.2364, 9.885},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 2.1182, 0.5},
				{0.3, 6.3546, 1},
				{1, 4.2364, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 228, 230},
				},
				{
					0.3,
					{255, 97, 109},
				},
				{
					0.7,
					{234, 24, 42},
				},
				{
					1,
					{136, 9, 28},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			stream = {
				{0.2, 4.7, 7.5, 1.5},
			},
			emit = {},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaHeat3",
			texture = "kk_flare_01",
			offset = {-20.72, 1.5, 18.6067},
			shape = {
				type = "Box",
				size = {7.0607, 1, 7.0607},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 215, 218},
				},
				{
					0.5,
					{255, 61, 76},
				},
				{
					1,
					{208, 12, 31},
				},
			},
			light_emission = 1,
			brightness = 2.08,
			stream = {
				{0.3, 5, 7.5, 1.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaSmoke3",
			texture = "kk_smoke_04",
			offset = {-20.72, 2.5, 18.6067},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 4.2364, 1.4121},
				{1, 16.9456, 4.2364},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 3.75, 1.2},
			},
			emit = {},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaPatch4",
			texture = "kz_lava_pool",
			emit = {
				{0.4, 1},
			},
			offset = {5.4987, 0.22, -27.6806},
			lifetime = {5, 5},
			size = {
				{0, 2.7262, 0},
				{0.05, 17.7204, 0},
				{1, 18.4019, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 92, 105},
				},
				{
					0.08,
					{217, 44, 55},
				},
				{
					0.55,
					{194, 14, 25},
				},
				{
					0.85,
					{125, 6, 16},
				},
				{
					1,
					{57, 3, 14},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles4",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {5.4987, 0.6, -27.6806},
			shape = {
				type = "Box",
				size = {6.8155, 0.2, 6.8155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {8.1786, 17.7204},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.8179, 0.2},
				{0.3, 2.0447, 0.4},
				{1, 1.3631, 0.3},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 13.5, 4.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaLick4",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {5.4987, 0.5, -27.6806},
			shape = {
				type = "Box",
				size = {6.8155, 0.2, 6.8155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.0893, 9.5417},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 2.0447, 0.5},
				{0.3, 6.134, 1},
				{1, 4.0893, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 228, 230},
				},
				{
					0.3,
					{255, 97, 109},
				},
				{
					0.7,
					{234, 24, 42},
				},
				{
					1,
					{136, 9, 28},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			stream = {
				{0.2, 4.7, 7.5, 1.5},
			},
			emit = {},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaHeat4",
			texture = "kk_flare_01",
			offset = {5.4987, 1.5, -27.6806},
			shape = {
				type = "Box",
				size = {6.8155, 1, 6.8155},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 215, 218},
				},
				{
					0.5,
					{255, 61, 76},
				},
				{
					1,
					{208, 12, 31},
				},
			},
			light_emission = 1,
			brightness = 2.08,
			stream = {
				{0.3, 5, 7.5, 1.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaSmoke4",
			texture = "kk_smoke_04",
			offset = {5.4987, 2.5, -27.6806},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 4.0893, 1.3631},
				{1, 16.3573, 4.0893},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 3.75, 1.2},
			},
			emit = {},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaPatch5",
			texture = "kz_lava_pool",
			emit = {
				{0.45, 1},
			},
			offset = {-29.6959, 0.22, 11.8883},
			lifetime = {5, 5},
			size = {
				{0, 2.0171, 0},
				{0.05, 13.1109, 0},
				{1, 13.6152, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 92, 105},
				},
				{
					0.08,
					{217, 44, 55},
				},
				{
					0.55,
					{194, 14, 25},
				},
				{
					0.85,
					{125, 6, 16},
				},
				{
					1,
					{57, 3, 14},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles5",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {-29.6959, 0.6, 11.8883},
			shape = {
				type = "Box",
				size = {5.0427, 0.2, 5.0427},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {6.0512, 13.1109},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.6051, 0.2},
				{0.3, 1.5128, 0.4},
				{1, 1.0085, 0.3},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 13.5, 4.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaLick5",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {-29.6959, 0.5, 11.8883},
			shape = {
				type = "Box",
				size = {5.0427, 0.2, 5.0427},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {3.0256, 7.0597},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 1.5128, 0.5},
				{0.3, 4.5384, 1},
				{1, 3.0256, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 228, 230},
				},
				{
					0.3,
					{255, 97, 109},
				},
				{
					0.7,
					{234, 24, 42},
				},
				{
					1,
					{136, 9, 28},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			stream = {
				{0.2, 4.7, 7.5, 1.5},
			},
			emit = {},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaHeat5",
			texture = "kk_flare_01",
			offset = {-29.6959, 1.5, 11.8883},
			shape = {
				type = "Box",
				size = {5.0427, 1, 5.0427},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 215, 218},
				},
				{
					0.5,
					{255, 61, 76},
				},
				{
					1,
					{208, 12, 31},
				},
			},
			light_emission = 1,
			brightness = 2.08,
			stream = {
				{0.3, 5, 7.5, 1.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaSmoke5",
			texture = "kk_smoke_04",
			offset = {-29.6959, 2.5, 11.8883},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 3.0256, 1.0085},
				{1, 12.1024, 3.0256},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 3.75, 1.2},
			},
			emit = {},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaPatch6",
			texture = "kz_lava_pool",
			emit = {
				{0.5, 1},
			},
			offset = {-3.2365, 0.22, -19.0166},
			lifetime = {5, 5},
			size = {
				{0, 2.0345, 0},
				{0.05, 13.2243, 0},
				{1, 13.733, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 92, 105},
				},
				{
					0.08,
					{217, 44, 55},
				},
				{
					0.55,
					{194, 14, 25},
				},
				{
					0.85,
					{125, 6, 16},
				},
				{
					1,
					{57, 3, 14},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles6",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {-3.2365, 0.6, -19.0166},
			shape = {
				type = "Box",
				size = {5.0863, 0.2, 5.0863},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {6.1035, 13.2243},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.6104, 0.2},
				{0.3, 1.5259, 0.4},
				{1, 1.0173, 0.3},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 13.5, 4.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaLick6",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {-3.2365, 0.5, -19.0166},
			shape = {
				type = "Box",
				size = {5.0863, 0.2, 5.0863},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {3.0518, 7.1208},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 1.5259, 0.5},
				{0.3, 4.5777, 1},
				{1, 3.0518, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 228, 230},
				},
				{
					0.3,
					{255, 97, 109},
				},
				{
					0.7,
					{234, 24, 42},
				},
				{
					1,
					{136, 9, 28},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			stream = {
				{0.2, 4.7, 7.5, 1.5},
			},
			emit = {},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaHeat6",
			texture = "kk_flare_01",
			offset = {-3.2365, 1.5, -19.0166},
			shape = {
				type = "Box",
				size = {5.0863, 1, 5.0863},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 215, 218},
				},
				{
					0.5,
					{255, 61, 76},
				},
				{
					1,
					{208, 12, 31},
				},
			},
			light_emission = 1,
			brightness = 2.08,
			stream = {
				{0.3, 5, 7.5, 1.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaSmoke6",
			texture = "kk_smoke_04",
			offset = {-3.2365, 2.5, -19.0166},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 3.0518, 1.0173},
				{1, 12.2071, 3.0518},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 3.75, 1.2},
			},
			emit = {},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaPatch7",
			texture = "kz_lava_pool",
			emit = {
				{0.55, 1},
			},
			offset = {-21.3471, 0.22, -20.2424},
			lifetime = {5, 5},
			size = {
				{0, 1.8833, 0},
				{0.05, 12.2414, 0},
				{1, 12.7123, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 92, 105},
				},
				{
					0.08,
					{217, 44, 55},
				},
				{
					0.55,
					{194, 14, 25},
				},
				{
					0.85,
					{125, 6, 16},
				},
				{
					1,
					{57, 3, 14},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles7",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {-21.3471, 0.6, -20.2424},
			shape = {
				type = "Box",
				size = {4.7082, 0.2, 4.7082},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {5.6499, 12.2414},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.565, 0.2},
				{0.3, 1.4125, 0.4},
				{1, 0.9416, 0.3},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 13.5, 4.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaLick7",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {-21.3471, 0.5, -20.2424},
			shape = {
				type = "Box",
				size = {4.7082, 0.2, 4.7082},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {2.8249, 6.5915},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 1.4125, 0.5},
				{0.3, 4.2374, 1},
				{1, 2.8249, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 228, 230},
				},
				{
					0.3,
					{255, 97, 109},
				},
				{
					0.7,
					{234, 24, 42},
				},
				{
					1,
					{136, 9, 28},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			stream = {
				{0.2, 4.7, 7.5, 1.5},
			},
			emit = {},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaHeat7",
			texture = "kk_flare_01",
			offset = {-21.3471, 1.5, -20.2424},
			shape = {
				type = "Box",
				size = {4.7082, 1, 4.7082},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 215, 218},
				},
				{
					0.5,
					{255, 61, 76},
				},
				{
					1,
					{208, 12, 31},
				},
			},
			light_emission = 1,
			brightness = 2.08,
			stream = {
				{0.3, 5, 7.5, 1.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaSmoke7",
			texture = "kk_smoke_04",
			offset = {-21.3471, 2.5, -20.2424},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 2.8249, 0.9416},
				{1, 11.2998, 2.8249},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 3.75, 1.2},
			},
			emit = {},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaPatch8",
			texture = "kz_lava_pool",
			emit = {
				{0.6, 1},
			},
			offset = {30.5851, 0.22, 6.4354},
			lifetime = {5, 5},
			size = {
				{0, 3.0136, 0},
				{0.05, 19.5887, 0},
				{1, 20.3421, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{217, 92, 105},
				},
				{
					0.08,
					{217, 44, 55},
				},
				{
					0.55,
					{194, 14, 25},
				},
				{
					0.85,
					{125, 6, 16},
				},
				{
					1,
					{57, 3, 14},
				},
			},
			light_emission = 0.9,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "LavaBubbles8",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {30.5851, 0.6, 6.4354},
			shape = {
				type = "Box",
				size = {7.5341, 0.2, 7.5341},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {9.0409, 19.5887},
			drag = 0.5,
			accel = {0, -45, 0},
			lifetime = {0.4, 0.65},
			size = {
				{0, 0.9041, 0.2},
				{0.3, 2.2602, 0.4},
				{1, 1.5068, 0.3},
			},
			color = {
				{
					0,
					{255, 193, 198},
				},
				{
					0.2,
					{255, 70, 85},
				},
				{
					0.55,
					{234, 24, 42},
				},
				{
					1,
					{165, 10, 29},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			rotation = {0, 360},
			stream = {
				{0.2, 4.9, 13.5, 4.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaLick8",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {30.5851, 0.5, 6.4354},
			shape = {
				type = "Box",
				size = {7.5341, 0.2, 7.5341},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.5205, 10.5478},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 2.2602, 0.5},
				{0.3, 6.7807, 1},
				{1, 4.5205, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 228, 230},
				},
				{
					0.3,
					{255, 97, 109},
				},
				{
					0.7,
					{234, 24, 42},
				},
				{
					1,
					{136, 9, 28},
				},
			},
			light_emission = 0.4,
			brightness = 1.95,
			stream = {
				{0.2, 4.7, 7.5, 1.5},
			},
			emit = {},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "LavaHeat8",
			texture = "kk_flare_01",
			offset = {30.5851, 1.5, 6.4354},
			shape = {
				type = "Box",
				size = {7.5341, 1, 7.5341},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {5, 12},
			drag = 1.5,
			accel = {0, 9, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 1.3, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 215, 218},
				},
				{
					0.5,
					{255, 61, 76},
				},
				{
					1,
					{208, 12, 31},
				},
			},
			light_emission = 1,
			brightness = 2.08,
			stream = {
				{0.3, 5, 7.5, 1.5},
			},
			emit = {},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "LavaSmoke8",
			texture = "kk_smoke_04",
			offset = {30.5851, 2.5, 6.4354},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			drag = 1.2,
			accel = {0, 5, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 4.5205, 1.5068},
				{1, 18.0819, 4.5205},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 53, 68},
				},
				{
					0.06,
					{105, 18, 36},
				},
				{
					0.2,
					{60, 44, 41},
				},
				{
					0.6,
					{70, 57, 56},
				},
				{
					1,
					{85, 72, 71},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -2,
			stream = {
				{0.4, 5.2, 3.75, 1.2},
			},
			emit = {},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
	},
	shakes = {
		{0, 1.5, 1.1},
	},
	scale_mult = 1.5,
	light = {
		color = {255, 60, 90},
		brightness = 9,
		range = 60,
		time = 1.4,
	},
}

-- H1 IGNITION: la explosión de lava en carmesí, 1.5 veces más grande y más intensa (más magma, más rocas fundidas, luz y sacudida más fuertes); la lava carmesí queda viva en el suelo 5 s.
function KaijuFireVFX.GiantExplosionIgnition(cf: CFrame, scale: number?, shake: number?): Part
	return play(SPEC_GiantExplosionIgnition, cf, scale, nil, shake)
end

local SPEC_GiantExplosionClassic = {
	name = "GiantExplosionClassic",
	duration = 5.8,
	cleanup = 7.2,
	layers = {
		{
			name = "FlashBurst",
			texture = "fx_burst_a",
			emit = {
				{0, 2},
			},
			offset = {0, 8, 0},
			lifetime = {0.1, 0.13},
			size = {
				{0, 16, 0},
				{0.3, 62, 0},
				{1, 72, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 170},
				},
				{
					1,
					{255, 170, 70},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {0, 360},
			zoffset = 12,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FlashStar",
			texture = "fx_star",
			emit = {
				{0, 1},
			},
			offset = {0, 8, 0},
			lifetime = {0.15, 0.15},
			size = {
				{0, 40, 0},
				{0.25, 120, 0},
				{1, 60, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 200},
				},
				{
					1,
					{255, 196, 110},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			zoffset = 13,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Glow",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			offset = {0, 12, 0},
			lifetime = {0.8, 0.8},
			size = {
				{0, 30, 0},
				{0.12, 84, 0},
				{1, 100, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.4, 0.65, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 170, 70},
				},
				{
					1,
					{230, 90, 30},
				},
			},
			light_emission = 0.45,
			brightness = 1,
			zoffset = -12,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "GroundRing",
			decal = true,
			texture = "fx_shock_spiky",
			emit = {
				{0, 1},
			},
			offset = {0, 0.3, 0},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {0.55, 0.55},
			size = {
				{0, 34, 0},
				{0.2, 84, 0},
				{0.6, 142, 0},
				{1, 160, 0},
			},
			transparency = {
				{0, 0.55, 0},
				{0.35, 0.72, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 176, 90},
				},
				{
					1,
					{255, 120, 50},
				},
			},
			light_emission = 0.35,
			brightness = 1,
			rotation = {0, 360},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundRing2",
			decal = true,
			texture = "kk_circle_03",
			emit = {
				{0.06, 1},
			},
			offset = {0, 0.25, 0},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {0.5, 0.5},
			size = {
				{0, 26, 0},
				{0.25, 70, 0},
				{1, 126, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.5, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 210, 150},
				},
				{
					1,
					{255, 180, 120},
				},
			},
			light_emission = 0.3,
			brightness = 1,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "DustWave",
			texture = "kk_smoke_07",
			emit = {
				{0.02, 38},
			},
			offset = {0, 2.5, 0},
			direction = "Front",
			spread = {180, 3},
			speed = {110, 170},
			drag = 3.6,
			accel = {0, 6, 0},
			lifetime = {1.1, 1.5},
			size = {
				{0, 9, 2},
				{0.3, 22, 4},
				{1, 32, 5},
			},
			transparency = {
				{0, 0.45, 0},
				{0.15, 0.18, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{222, 200, 172},
				},
				{
					0.5,
					{200, 186, 170},
				},
				{
					1,
					{186, 178, 170},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -3,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "DustWave2",
			texture = "kk_smoke_04",
			emit = {
				{0.07, 24},
			},
			offset = {0, 3, 0},
			direction = "Front",
			spread = {180, 5},
			speed = {70, 115},
			drag = 3,
			accel = {0, 8, 0},
			lifetime = {1.1, 1.45},
			size = {
				{0, 10, 2},
				{0.35, 24, 4},
				{1, 34, 5},
			},
			transparency = {
				{0, 0.45, 0},
				{0.15, 0.22, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{222, 200, 172},
				},
				{
					0.5,
					{200, 186, 170},
				},
				{
					1,
					{186, 178, 170},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -3,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FireWaveGround",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			emit = {
				{0.03, 22},
			},
			offset = {0, 2.5, 0},
			direction = "Front",
			spread = {180, 4},
			speed = {70, 105},
			drag = 4.5,
			accel = {0, 10, 0},
			lifetime = {0.45, 0.62},
			size = {
				{0, 8, 2},
				{0.3, 18, 3},
				{1, 12, 2},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.3,
			brightness = 1.5,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundStreaks",
			texture = "fx_line",
			orientation = "VelocityParallel",
			emit = {
				{0, 18},
			},
			offset = {0, 1.5, 0},
			direction = "Front",
			spread = {180, 2},
			speed = {190, 270},
			drag = 7,
			lifetime = {0.18, 0.26},
			size = {
				{0, 18, 4},
				{1, 28, 4},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 200},
				},
				{
					1,
					{255, 190, 100},
				},
			},
			light_emission = 0.8,
			brightness = 1.3,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "FireCore",
			texture = "kk_fire_02",
			emit = {
				{0, 4},
				{0.06, 2},
			},
			offset = {0, 9, 0},
			speed = {0, 6},
			direction = "Top",
			spread = {180, 180},
			lifetime = {0.5, 0.6},
			size = {
				{0, 14, 3},
				{0.3, 38, 4},
				{1, 42, 4},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 248, 214},
				},
				{
					0.3,
					{255, 214, 110},
				},
				{
					1,
					{255, 140, 50},
				},
			},
			light_emission = 0.5,
			brightness = 1.6,
			rotation = {0, 360},
			rot_speed = {-90, 90},
			zoffset = 3,
			accel = {0, 0, 0},
			drag = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FireballA",
			texture = "kk_fire_01",
			emit = {
				{0, 10},
				{0.05, 6},
				{0.1, 4},
			},
			offset = {0, 10, 0},
			shape = {
				type = "Sphere",
				radius = 5,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {26, 46},
			drag = 3.6,
			accel = {0, 14, 0},
			lifetime = {0.85, 1.15},
			size = {
				{0, 14, 3.5},
				{0.15, 34, 6.12},
				{0.6, 42, 5.88},
				{1, 46, 6.44},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.25,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FireballB",
			texture = "kk_fire_02",
			emit = {
				{0, 8},
				{0.06, 5},
				{0.12, 3},
			},
			offset = {0, 10, 0},
			shape = {
				type = "Sphere",
				radius = 5,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {22, 42},
			drag = 3.6,
			accel = {0, 14, 0},
			lifetime = {0.8, 1.1},
			size = {
				{0, 13, 3.25},
				{0.15, 32, 5.76},
				{0.6, 40, 5.6},
				{1, 44, 6.16},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.25,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FireRoll",
			texture = "kk_fire_01",
			emit = {
				{0.14, 6},
				{0.24, 5},
				{0.34, 4},
			},
			offset = {0, 22, 0},
			shape = {
				type = "Sphere",
				radius = 10,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {18, 34},
			drag = 2,
			accel = {0, 14, 0},
			lifetime = {0.8, 1.05},
			size = {
				{0, 16, 4},
				{0.15, 30, 5.4},
				{0.6, 36, 5.04},
				{1, 36, 5.04},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.25,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Jets",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			emit = {
				{0.01, 14},
				{0.07, 6},
			},
			direction = "Top",
			spread = {110, 110},
			speed = {70, 120},
			drag = 6.5,
			accel = {0, -10, 0},
			lifetime = {0.45, 0.65},
			size = {
				{0, 10, 3},
				{0.2, 26, 6.5},
				{1, 22, 5.5},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.25,
					{255, 190, 70},
				},
				{
					0.6,
					{250, 120, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.3,
			brightness = 1.7,
			offset = {0, 8, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "Jets2",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			emit = {
				{0.02, 10},
			},
			direction = "Top",
			spread = {110, 110},
			speed = {60, 110},
			drag = 6.5,
			accel = {0, -10, 0},
			lifetime = {0.42, 0.6},
			size = {
				{0, 9, 2.7},
				{0.2, 22, 5.5},
				{1, 18, 4.5},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.25,
					{255, 190, 70},
				},
				{
					0.6,
					{250, 120, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.3,
			brightness = 1.7,
			offset = {0, 8, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "Column",
			texture = "kk_muzzle_01",
			orientation = "VelocityParallel",
			emit = {
				{0.03, 6},
				{0.12, 3},
			},
			direction = "Top",
			spread = {12, 12},
			speed = {90, 140},
			drag = 4.5,
			accel = {0, 0, 0},
			lifetime = {0.5, 0.65},
			size = {
				{0, 14, 4.2},
				{0.2, 36, 9},
				{1, 30, 7.5},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.25,
					{255, 190, 70},
				},
				{
					0.6,
					{250, 120, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.3,
			brightness = 1.7,
			offset = {0, 6, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "FlamesOut",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			emit = {
				{0.01, 12},
				{0.08, 6},
			},
			offset = {0, 8, 0},
			shape = {
				type = "Sphere",
				radius = 6,
				style = "Surface",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {50, 90},
			drag = 6,
			accel = {0, 14, 0},
			lifetime = {0.5, 0.7},
			size = {
				{0, 8, 2},
				{0.25, 22, 4},
				{1, 18, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.3,
			brightness = 1.4,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "Pops",
			texture = "kk_fire_01",
			emit = {
				{0.12, 4},
				{0.22, 4},
				{0.32, 3},
				{0.45, 2},
			},
			offset = {0, 14, 0},
			shape = {
				type = "Sphere",
				radius = 17,
				style = "Surface",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {4, 12},
			drag = 4,
			accel = {0, 6, 0},
			lifetime = {0.36, 0.5},
			size = {
				{0, 6, 1.5},
				{0.15, 13, 2.34},
				{0.6, 16, 2.24},
				{1, 16, 2.24},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.25,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "SmokeCap",
			texture = "kk_smoke_07",
			emit = {
				{0.5, 6},
				{0.62, 5},
				{0.75, 4},
			},
			offset = {0, 40, 0},
			shape = {
				type = "Sphere",
				radius = 13,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {70, 70},
			speed = {10, 22},
			drag = 1.2,
			accel = {0, 8, 0},
			lifetime = {1.8, 2.3},
			size = {
				{0, 24, 4},
				{0.4, 44, 6},
				{1, 58, 6},
			},
			transparency = {
				{0, 0.55, 0},
				{0.1, 0.3, 0},
				{0.55, 0.48, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 156, 76},
				},
				{
					0.08,
					{170, 112, 84},
				},
				{
					0.25,
					{126, 114, 108},
				},
				{
					0.65,
					{150, 144, 140},
				},
				{
					1,
					{172, 168, 164},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -12,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "SmokeCap2",
			texture = "kk_smoke_08",
			emit = {
				{0.56, 5},
				{0.7, 4},
			},
			offset = {0, 36, 0},
			shape = {
				type = "Sphere",
				radius = 13,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {70, 70},
			speed = {10, 20},
			drag = 1.2,
			accel = {0, 8, 0},
			lifetime = {1.7, 2.2},
			size = {
				{0, 22, 4},
				{0.4, 42, 6},
				{1, 54, 6},
			},
			transparency = {
				{0, 0.55, 0},
				{0.1, 0.32, 0},
				{0.55, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 156, 76},
				},
				{
					0.08,
					{170, 112, 84},
				},
				{
					0.25,
					{126, 114, 108},
				},
				{
					0.65,
					{150, 144, 140},
				},
				{
					1,
					{172, 168, 164},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -12,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "CapRing",
			texture = "kk_smoke_07",
			emit = {
				{0.6, 10},
				{0.72, 6},
			},
			offset = {0, 46, 0},
			direction = "Front",
			spread = {180, 12},
			speed = {26, 42},
			drag = 1.5,
			accel = {0, 7, 0},
			lifetime = {1.6, 2},
			size = {
				{0, 18, 4},
				{0.4, 34, 5},
				{1, 44, 5},
			},
			transparency = {
				{0, 0.6, 0},
				{0.12, 0.35, 0},
				{0.55, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 156, 76},
				},
				{
					0.08,
					{170, 112, 84},
				},
				{
					0.25,
					{126, 114, 108},
				},
				{
					0.65,
					{150, 144, 140},
				},
				{
					1,
					{172, 168, 164},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -13,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "SmokeStem",
			texture = "kk_smoke_04",
			emit = {
				{0.5, 4},
				{0.62, 4},
			},
			offset = {0, 14, 0},
			shape = {
				type = "Box",
				size = {10, 24, 10},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {10, 20},
			drag = 1.2,
			accel = {0, 8, 0},
			lifetime = {1.4, 1.8},
			size = {
				{0, 14, 3},
				{0.5, 24, 4},
				{1, 30, 4},
			},
			transparency = {
				{0, 0.55, 0},
				{0.2, 0.28, 0},
				{0.7, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 156, 76},
				},
				{
					0.08,
					{170, 112, 84},
				},
				{
					0.25,
					{126, 114, 108},
				},
				{
					0.65,
					{150, 144, 140},
				},
				{
					1,
					{172, 168, 164},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -11,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Meteors",
			type = "meteor",
			emit = {
				{0.02, 10},
			},
			offset = {0, 4, 0},
			direction = "Top",
			spread = {62, 62},
			speed = {70, 115},
			accel = {0, -120, 0},
			drag = 0.2,
			lifetime = {1.4, 1.8},
			trails = {
				{
					name = "MeteorSmoke",
					rate = 40,
					texture = "kk_smoke_04",
					speed = {1, 4},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					accel = {0, 6, 0},
					lifetime = {0.55, 0.85},
					size = {
						{0, 3, 0.8},
						{1, 9, 2},
					},
					transparency = {
						{0, 0.3, 0},
						{0.6, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 170, 80},
						},
						{
							0.2,
							{100, 88, 82},
						},
						{
							1,
							{140, 134, 130},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
				{
					name = "MeteorFire",
					rate = 55,
					texture = "kk_fire_01",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					lifetime = {0.16, 0.26},
					size = {
						{0, 6, 1.2},
						{1, 1.5, 0},
					},
					color = {
						{
							0,
							{255, 246, 210},
						},
						{
							0.1,
							{255, 218, 110},
						},
						{
							0.3,
							{255, 160, 50},
						},
						{
							0.55,
							{240, 104, 30},
						},
						{
							0.8,
							{190, 60, 22},
						},
						{
							1,
							{96, 32, 16},
						},
					},
					light_emission = 0.5,
					brightness = 1.6,
					rotation = {0, 360},
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
			land = {
				{
					name = "MeteorDust",
					emit = {
						{0, 5},
					},
					texture = "kk_smoke_04",
					direction = "Top",
					spread = {75, 75},
					speed = {8, 18},
					drag = 3,
					accel = {0, 4, 0},
					lifetime = {0.6, 0.9},
					size = {
						{0, 3, 1},
						{0.4, 8, 1.5},
						{1, 10, 1.5},
					},
					transparency = {
						{0, 0.35, 0},
						{0.6, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{222, 200, 172},
						},
						{
							0.5,
							{200, 186, 170},
						},
						{
							1,
							{186, 178, 170},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
				{
					name = "MeteorBurn",
					texture = "kk_muzzle_05",
					orientation = "VelocityParallel",
					direction = "Top",
					spread = {10, 10},
					speed = {4, 9},
					drag = 2,
					lifetime = {0.35, 0.55},
					size = {
						{0, 1.5, 0.5},
						{0.3, 5, 1},
						{1, 3, 0.8},
					},
					transparency = {
						{0, 0, 0},
						{0.6, 0.12, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 236, 150},
						},
						{
							0.3,
							{255, 176, 60},
						},
						{
							0.7,
							{245, 108, 30},
						},
						{
							1,
							{180, 50, 18},
						},
					},
					light_emission = 0.35,
					brightness = 1.5,
					stream = {
						{0, 2.6, 12, 0},
					},
					accel = {0, 0, 0},
					rotation = {0, 0},
					rot_speed = {0, 0},
					zoffset = 0,
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
				{
					name = "MeteorWisp",
					texture = "kk_smoke_04",
					direction = "Top",
					spread = {15, 15},
					speed = {5, 10},
					drag = 1.2,
					accel = {0, 5, 0},
					lifetime = {1, 1.4},
					size = {
						{0, 2, 0.6},
						{1, 8, 2},
					},
					transparency = {
						{0, 0.6, 0},
						{0.3, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{120, 104, 96},
						},
						{
							1,
							{150, 144, 140},
						},
					},
					rotation = {0, 360},
					stream = {
						{0.1, 2.8, 3, 0.5},
					},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
			},
			rock = {
				size = {2.4, 3.6},
				spin = {-500, 500},
				material = "Slate",
				color = {95, 78, 70},
			},
		},
		{
			name = "Streaks",
			texture = "fx_line",
			orientation = "VelocityParallel",
			offset = {0, 8, 0},
			emit = {
				{0, 36},
				{0.06, 18},
			},
			direction = "Top",
			spread = {180, 180},
			speed = {120, 220},
			drag = 4,
			accel = {0, -50, 0},
			lifetime = {0.3, 0.55},
			size = {
				{0, 20, 5},
				{1, 6, 0},
			},
			color = {
				{
					0,
					{255, 238, 150},
				},
				{
					0.5,
					{255, 184, 60},
				},
				{
					1,
					{255, 110, 24},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "Embers",
			texture = "kk_flare_01",
			emit = {
				{0.15, 22},
				{0.35, 14},
				{0.6, 10},
			},
			offset = {0, 14, 0},
			shape = {
				type = "Sphere",
				radius = 14,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {120, 120},
			speed = {10, 30},
			drag = 1.6,
			accel = {0, 16, 0},
			lifetime = {0.8, 1.2},
			size = {
				{0, 0, 0},
				{0.1, 2.8, 0.8},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Twinkles",
			texture = "fx_spark4",
			emit = {
				{0.1, 14},
			},
			offset = {0, 12, 0},
			shape = {
				type = "Sphere",
				radius = 18,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {6, 18},
			drag = 2,
			accel = {0, 8, 0},
			lifetime = {0.35, 0.6},
			size = {
				{0, 0, 0},
				{0.15, 5, 1.5},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 236, 160},
				},
				{
					1,
					{255, 150, 50},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {0, 360},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Scorch",
			decal = true,
			texture = "kz_scorch",
			orientation = "VelocityPerpendicular",
			emit = {
				{0.02, 1},
			},
			offset = {0, 0.15, 0},
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {5.6, 5.6},
			size = {
				{0, 10, 0},
				{0.03, 52, 0},
				{1, 54, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.8, 0.25, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			zoffset = -1,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 255, 255},
				},
			},
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			line_u = 0,
		},
		{
			name = "GroundGlow0",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			emit = {
				{0.15, 1},
			},
			offset = {0, 0.3, 0},
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {5.25, 5.25},
			size = {
				{0, 0, 0},
				{0.04, 28.6, 0},
				{0.75, 22, 0},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.8, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 60},
				},
				{
					1,
					{220, 80, 30},
				},
			},
			light_emission = 0.8,
			brightness = 1.2,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundFlames0",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			offset = {0, 0.6, 0},
			shape = {
				type = "Box",
				size = {13.2, 0.2, 13.2},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {15.4, 28.6},
			drag = 2,
			lifetime = {0.4, 0.62},
			size = {
				{0, 8.8, 2.2},
				{0.3, 24.2, 6.6},
				{1, 15.4, 4.4},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0.15, 3.2, 14, 5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFireBase0",
			texture = "kk_fire_01",
			offset = {0, 1.2, 0},
			shape = {
				type = "Box",
				size = {13.2, 0.2, 13.2},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 6.6, 2.2},
				{0.4, 13.2, 3.3},
				{1, 8.8, 2.2},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.15, 5.1, 9, 0},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFlamesSmall0",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {0, 0.5, 0},
			shape = {
				type = "Box",
				size = {13.2, 0.2, 13.2},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {8.8, 17.6},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 4.4, 1.32},
				{0.3, 13.2, 3.3},
				{1, 8.8, 2.2},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.5,
			stream = {
				{0.15, 5.1, 6, 0},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundSmoke0",
			texture = "kk_smoke_04",
			offset = {0, 3, 0},
			direction = "Top",
			spread = {15, 15},
			speed = {6, 12},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 6.6, 2.2},
				{1, 28.6, 6.6},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 104, 96},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.3, 5.2, 3, 1},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundEmbers0",
			texture = "kk_flare_01",
			offset = {0, 3, 0},
			shape = {
				type = "Box",
				size = {13.2, 2, 13.2},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 10, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.5, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundGlow1",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			emit = {
				{0.15, 1},
			},
			offset = {8.8707, 0.3, 7.5665},
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {5.25, 5.25},
			size = {
				{0, 0, 0},
				{0.04, 18.3855, 0},
				{0.75, 14.1427, 0},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.8, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 60},
				},
				{
					1,
					{220, 80, 30},
				},
			},
			light_emission = 0.8,
			brightness = 1.2,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundFlames1",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			offset = {8.8707, 0.6, 7.5665},
			shape = {
				type = "Box",
				size = {8.4856, 0.2, 8.4856},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {9.8999, 18.3855},
			drag = 2,
			lifetime = {0.4, 0.62},
			size = {
				{0, 5.6571, 1.4143},
				{0.3, 15.557, 4.2428},
				{1, 9.8999, 2.8285},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0.15, 3.2, 14, 5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFireBase1",
			texture = "kk_fire_01",
			offset = {8.8707, 1.2, 7.5665},
			shape = {
				type = "Box",
				size = {8.4856, 0.2, 8.4856},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 4.2428, 1.4143},
				{0.4, 8.4856, 2.1214},
				{1, 5.6571, 1.4143},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.15, 5.1, 9, 0},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFlamesSmall1",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {8.8707, 0.5, 7.5665},
			shape = {
				type = "Box",
				size = {8.4856, 0.2, 8.4856},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {5.6571, 11.3142},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 2.8285, 0.8486},
				{0.3, 8.4856, 2.1214},
				{1, 5.6571, 1.4143},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.5,
			stream = {
				{0.15, 5.1, 6, 0},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundSmoke1",
			texture = "kk_smoke_04",
			offset = {8.8707, 3, 7.5665},
			direction = "Top",
			spread = {15, 15},
			speed = {6, 12},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 4.2428, 1.4143},
				{1, 18.3855, 4.2428},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 104, 96},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.3, 5.2, 3, 1},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundEmbers1",
			texture = "kk_flare_01",
			offset = {8.8707, 3, 7.5665},
			shape = {
				type = "Box",
				size = {8.4856, 2, 8.4856},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 10, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.5, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundGlow2",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			emit = {
				{0.15, 1},
			},
			offset = {18.57, 0.3, 22.0751},
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {5.25, 5.25},
			size = {
				{0, 0, 0},
				{0.04, 15.4694, 0},
				{0.75, 11.8995, 0},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.8, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 60},
				},
				{
					1,
					{220, 80, 30},
				},
			},
			light_emission = 0.8,
			brightness = 1.2,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundFlames2",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			offset = {18.57, 0.6, 22.0751},
			shape = {
				type = "Box",
				size = {7.1397, 0.2, 7.1397},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {8.3297, 15.4694},
			drag = 2,
			lifetime = {0.4, 0.62},
			size = {
				{0, 4.7598, 1.19},
				{0.3, 13.0895, 3.5699},
				{1, 8.3297, 2.3799},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0.15, 3.2, 14, 5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFireBase2",
			texture = "kk_fire_01",
			offset = {18.57, 1.2, 22.0751},
			shape = {
				type = "Box",
				size = {7.1397, 0.2, 7.1397},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 3.5699, 1.19},
				{0.4, 7.1397, 1.7849},
				{1, 4.7598, 1.19},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.15, 5.1, 9, 0},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFlamesSmall2",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {18.57, 0.5, 22.0751},
			shape = {
				type = "Box",
				size = {7.1397, 0.2, 7.1397},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.7598, 9.5196},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 2.3799, 0.714},
				{0.3, 7.1397, 1.7849},
				{1, 4.7598, 1.19},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.5,
			stream = {
				{0.15, 5.1, 6, 0},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundSmoke2",
			texture = "kk_smoke_04",
			offset = {18.57, 3, 22.0751},
			direction = "Top",
			spread = {15, 15},
			speed = {6, 12},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 3.5699, 1.19},
				{1, 15.4694, 3.5699},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 104, 96},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.3, 5.2, 3, 1},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundEmbers2",
			texture = "kk_flare_01",
			offset = {18.57, 3, 22.0751},
			shape = {
				type = "Box",
				size = {7.1397, 2, 7.1397},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 10, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.5, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundGlow3",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			emit = {
				{0.15, 1},
			},
			offset = {0.9802, 0.3, -20.5316},
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {5.25, 5.25},
			size = {
				{0, 0, 0},
				{0.04, 15.833, 0},
				{0.75, 12.1792, 0},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.8, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 60},
				},
				{
					1,
					{220, 80, 30},
				},
			},
			light_emission = 0.8,
			brightness = 1.2,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundFlames3",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			offset = {0.9802, 0.6, -20.5316},
			shape = {
				type = "Box",
				size = {7.3075, 0.2, 7.3075},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {8.5254, 15.833},
			drag = 2,
			lifetime = {0.4, 0.62},
			size = {
				{0, 4.8717, 1.2179},
				{0.3, 13.3971, 3.6538},
				{1, 8.5254, 2.4358},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0.15, 3.2, 14, 5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFireBase3",
			texture = "kk_fire_01",
			offset = {0.9802, 1.2, -20.5316},
			shape = {
				type = "Box",
				size = {7.3075, 0.2, 7.3075},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 3.6538, 1.2179},
				{0.4, 7.3075, 1.8269},
				{1, 4.8717, 1.2179},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.15, 5.1, 9, 0},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFlamesSmall3",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {0.9802, 0.5, -20.5316},
			shape = {
				type = "Box",
				size = {7.3075, 0.2, 7.3075},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.8717, 9.7434},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 2.4358, 0.7308},
				{0.3, 7.3075, 1.8269},
				{1, 4.8717, 1.2179},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.5,
			stream = {
				{0.15, 5.1, 6, 0},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundSmoke3",
			texture = "kk_smoke_04",
			offset = {0.9802, 3, -20.5316},
			direction = "Top",
			spread = {15, 15},
			speed = {6, 12},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 3.6538, 1.2179},
				{1, 15.833, 3.6538},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 104, 96},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.3, 5.2, 3, 1},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundEmbers3",
			texture = "kk_flare_01",
			offset = {0.9802, 3, -20.5316},
			shape = {
				type = "Box",
				size = {7.3075, 2, 7.3075},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 10, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.5, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundGlow4",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			emit = {
				{0.15, 1},
			},
			offset = {-15.5475, 0.3, -25.2523},
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {5.25, 5.25},
			size = {
				{0, 0, 0},
				{0.04, 15.7204, 0},
				{0.75, 12.0926, 0},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.8, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 60},
				},
				{
					1,
					{220, 80, 30},
				},
			},
			light_emission = 0.8,
			brightness = 1.2,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundFlames4",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			offset = {-15.5475, 0.6, -25.2523},
			shape = {
				type = "Box",
				size = {7.2556, 0.2, 7.2556},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {8.4648, 15.7204},
			drag = 2,
			lifetime = {0.4, 0.62},
			size = {
				{0, 4.8371, 1.2093},
				{0.3, 13.3019, 3.6278},
				{1, 8.4648, 2.4185},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0.15, 3.2, 14, 5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFireBase4",
			texture = "kk_fire_01",
			offset = {-15.5475, 1.2, -25.2523},
			shape = {
				type = "Box",
				size = {7.2556, 0.2, 7.2556},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 3.6278, 1.2093},
				{0.4, 7.2556, 1.8139},
				{1, 4.8371, 1.2093},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.15, 5.1, 9, 0},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFlamesSmall4",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {-15.5475, 0.5, -25.2523},
			shape = {
				type = "Box",
				size = {7.2556, 0.2, 7.2556},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.8371, 9.6741},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 2.4185, 0.7256},
				{0.3, 7.2556, 1.8139},
				{1, 4.8371, 1.2093},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.5,
			stream = {
				{0.15, 5.1, 6, 0},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundSmoke4",
			texture = "kk_smoke_04",
			offset = {-15.5475, 3, -25.2523},
			direction = "Top",
			spread = {15, 15},
			speed = {6, 12},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 3.6278, 1.2093},
				{1, 15.7204, 3.6278},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 104, 96},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.3, 5.2, 3, 1},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundEmbers4",
			texture = "kk_flare_01",
			offset = {-15.5475, 3, -25.2523},
			shape = {
				type = "Box",
				size = {7.2556, 2, 7.2556},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 10, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.5, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundGlow5",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			emit = {
				{0.15, 1},
			},
			offset = {-25.1466, 0.3, 8.5653},
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {5.25, 5.25},
			size = {
				{0, 0, 0},
				{0.04, 18.5907, 0},
				{0.75, 14.3006, 0},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.8, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 60},
				},
				{
					1,
					{220, 80, 30},
				},
			},
			light_emission = 0.8,
			brightness = 1.2,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundFlames5",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			offset = {-25.1466, 0.6, 8.5653},
			shape = {
				type = "Box",
				size = {8.5803, 0.2, 8.5803},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {10.0104, 18.5907},
			drag = 2,
			lifetime = {0.4, 0.62},
			size = {
				{0, 5.7202, 1.4301},
				{0.3, 15.7306, 4.2902},
				{1, 10.0104, 2.8601},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0.15, 3.2, 14, 5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFireBase5",
			texture = "kk_fire_01",
			offset = {-25.1466, 1.2, 8.5653},
			shape = {
				type = "Box",
				size = {8.5803, 0.2, 8.5803},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 4.2902, 1.4301},
				{0.4, 8.5803, 2.1451},
				{1, 5.7202, 1.4301},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.15, 5.1, 9, 0},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFlamesSmall5",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {-25.1466, 0.5, 8.5653},
			shape = {
				type = "Box",
				size = {8.5803, 0.2, 8.5803},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {5.7202, 11.4404},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 2.8601, 0.858},
				{0.3, 8.5803, 2.1451},
				{1, 5.7202, 1.4301},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.5,
			stream = {
				{0.15, 5.1, 6, 0},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundSmoke5",
			texture = "kk_smoke_04",
			offset = {-25.1466, 3, 8.5653},
			direction = "Top",
			spread = {15, 15},
			speed = {6, 12},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 4.2902, 1.4301},
				{1, 18.5907, 4.2902},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 104, 96},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.3, 5.2, 3, 1},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundEmbers5",
			texture = "kk_flare_01",
			offset = {-25.1466, 3, 8.5653},
			shape = {
				type = "Box",
				size = {8.5803, 2, 8.5803},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 10, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.5, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundGlow6",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			emit = {
				{0.15, 1},
			},
			offset = {27.4752, 0.3, 18.1993},
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {5.25, 5.25},
			size = {
				{0, 0, 0},
				{0.04, 14.5118, 0},
				{0.75, 11.1629, 0},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.8, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 60},
				},
				{
					1,
					{220, 80, 30},
				},
			},
			light_emission = 0.8,
			brightness = 1.2,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundFlames6",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			offset = {27.4752, 0.6, 18.1993},
			shape = {
				type = "Box",
				size = {6.6978, 0.2, 6.6978},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {7.8141, 14.5118},
			drag = 2,
			lifetime = {0.4, 0.62},
			size = {
				{0, 4.4652, 1.1163},
				{0.3, 12.2792, 3.3489},
				{1, 7.8141, 2.2326},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0.15, 3.2, 14, 5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFireBase6",
			texture = "kk_fire_01",
			offset = {27.4752, 1.2, 18.1993},
			shape = {
				type = "Box",
				size = {6.6978, 0.2, 6.6978},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 3.3489, 1.1163},
				{0.4, 6.6978, 1.6744},
				{1, 4.4652, 1.1163},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.15, 5.1, 9, 0},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFlamesSmall6",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {27.4752, 0.5, 18.1993},
			shape = {
				type = "Box",
				size = {6.6978, 0.2, 6.6978},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.4652, 8.9303},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 2.2326, 0.6698},
				{0.3, 6.6978, 1.6744},
				{1, 4.4652, 1.1163},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.5,
			stream = {
				{0.15, 5.1, 6, 0},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundSmoke6",
			texture = "kk_smoke_04",
			offset = {27.4752, 3, 18.1993},
			direction = "Top",
			spread = {15, 15},
			speed = {6, 12},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 3.3489, 1.1163},
				{1, 14.5118, 3.3489},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 104, 96},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.3, 5.2, 3, 1},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundEmbers6",
			texture = "kk_flare_01",
			offset = {27.4752, 3, 18.1993},
			shape = {
				type = "Box",
				size = {6.6978, 2, 6.6978},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 10, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.5, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundGlow7",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			emit = {
				{0.15, 1},
			},
			offset = {-26.4506, 0.3, 18.4793},
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {5.25, 5.25},
			size = {
				{0, 0, 0},
				{0.04, 16.3644, 0},
				{0.75, 12.588, 0},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.8, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 60},
				},
				{
					1,
					{220, 80, 30},
				},
			},
			light_emission = 0.8,
			brightness = 1.2,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundFlames7",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			offset = {-26.4506, 0.6, 18.4793},
			shape = {
				type = "Box",
				size = {7.5528, 0.2, 7.5528},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {8.8116, 16.3644},
			drag = 2,
			lifetime = {0.4, 0.62},
			size = {
				{0, 5.0352, 1.2588},
				{0.3, 13.8468, 3.7764},
				{1, 8.8116, 2.5176},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0.15, 3.2, 14, 5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFireBase7",
			texture = "kk_fire_01",
			offset = {-26.4506, 1.2, 18.4793},
			shape = {
				type = "Box",
				size = {7.5528, 0.2, 7.5528},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 3.7764, 1.2588},
				{0.4, 7.5528, 1.8882},
				{1, 5.0352, 1.2588},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.15, 5.1, 9, 0},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFlamesSmall7",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {-26.4506, 0.5, 18.4793},
			shape = {
				type = "Box",
				size = {7.5528, 0.2, 7.5528},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {5.0352, 10.0704},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 2.5176, 0.7553},
				{0.3, 7.5528, 1.8882},
				{1, 5.0352, 1.2588},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.5,
			stream = {
				{0.15, 5.1, 6, 0},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundSmoke7",
			texture = "kk_smoke_04",
			offset = {-26.4506, 3, 18.4793},
			direction = "Top",
			spread = {15, 15},
			speed = {6, 12},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 3.7764, 1.2588},
				{1, 16.3644, 3.7764},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 104, 96},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.3, 5.2, 3, 1},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundEmbers7",
			texture = "kk_flare_01",
			offset = {-26.4506, 3, 18.4793},
			shape = {
				type = "Box",
				size = {7.5528, 2, 7.5528},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 10, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.5, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundGlow8",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			emit = {
				{0.15, 1},
			},
			offset = {-15.0622, 0.3, 17.1076},
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {5.25, 5.25},
			size = {
				{0, 0, 0},
				{0.04, 24.2332, 0},
				{0.75, 18.6409, 0},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.8, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 60},
				},
				{
					1,
					{220, 80, 30},
				},
			},
			light_emission = 0.8,
			brightness = 1.2,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundFlames8",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			offset = {-15.0622, 0.6, 17.1076},
			shape = {
				type = "Box",
				size = {11.1845, 0.2, 11.1845},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {13.0486, 24.2332},
			drag = 2,
			lifetime = {0.4, 0.62},
			size = {
				{0, 7.4564, 1.8641},
				{0.3, 20.505, 5.5923},
				{1, 13.0486, 3.7282},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0.15, 3.2, 14, 5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFireBase8",
			texture = "kk_fire_01",
			offset = {-15.0622, 1.2, 17.1076},
			shape = {
				type = "Box",
				size = {11.1845, 0.2, 11.1845},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 5.5923, 1.8641},
				{0.4, 11.1845, 2.7961},
				{1, 7.4564, 1.8641},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.15, 5.1, 9, 0},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFlamesSmall8",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			offset = {-15.0622, 0.5, 17.1076},
			shape = {
				type = "Box",
				size = {11.1845, 0.2, 11.1845},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {7.4564, 14.9127},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 3.7282, 1.1185},
				{0.3, 11.1845, 2.7961},
				{1, 7.4564, 1.8641},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.5,
			stream = {
				{0.15, 5.1, 6, 0},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundSmoke8",
			texture = "kk_smoke_04",
			offset = {-15.0622, 3, 17.1076},
			direction = "Top",
			spread = {15, 15},
			speed = {6, 12},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 5.5923, 1.8641},
				{1, 24.2332, 5.5923},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 104, 96},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.3, 5.2, 3, 1},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundEmbers8",
			texture = "kk_flare_01",
			offset = {-15.0622, 3, 17.1076},
			shape = {
				type = "Box",
				size = {11.1845, 2, 11.1845},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 10, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.5, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundGlow9",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			emit = {
				{0.15, 1},
			},
			offset = {4.1278, 0.3, 19.5764},
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {5.25, 5.25},
			size = {
				{0, 0, 0},
				{0.04, 20.383, 0},
				{0.75, 15.6792, 0},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.8, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 60},
				},
				{
					1,
					{220, 80, 30},
				},
			},
			light_emission = 0.8,
			brightness = 1.2,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundFlames9",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			offset = {4.1278, 0.6, 19.5764},
			shape = {
				type = "Box",
				size = {9.4075, 0.2, 9.4075},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {10.9754, 20.383},
			drag = 2,
			lifetime = {0.4, 0.62},
			size = {
				{0, 6.2717, 1.5679},
				{0.3, 17.2471, 4.7038},
				{1, 10.9754, 3.1358},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0.15, 3.2, 14, 5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFireBase9",
			texture = "kk_fire_01",
			offset = {4.1278, 1.2, 19.5764},
			shape = {
				type = "Box",
				size = {9.4075, 0.2, 9.4075},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 4.7038, 1.5679},
				{0.4, 9.4075, 2.3519},
				{1, 6.2717, 1.5679},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 210},
				},
				{
					0.1,
					{255, 218, 110},
				},
				{
					0.3,
					{255, 160, 50},
				},
				{
					0.55,
					{240, 104, 30},
				},
				{
					0.8,
					{190, 60, 22},
				},
				{
					1,
					{96, 32, 16},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.15, 5.1, 9, 0},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundFlamesSmall9",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			offset = {4.1278, 0.5, 19.5764},
			shape = {
				type = "Box",
				size = {9.4075, 0.2, 9.4075},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {6.2717, 12.5434},
			drag = 2,
			lifetime = {0.35, 0.55},
			size = {
				{0, 3.1358, 0.9408},
				{0.3, 9.4075, 2.3519},
				{1, 6.2717, 1.5679},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.12, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.5,
			stream = {
				{0.15, 5.1, 6, 0},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundSmoke9",
			texture = "kk_smoke_04",
			offset = {4.1278, 3, 19.5764},
			direction = "Top",
			spread = {15, 15},
			speed = {6, 12},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.2, 1.7},
			size = {
				{0, 4.7038, 1.5679},
				{1, 20.383, 4.7038},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 104, 96},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.3, 5.2, 3, 1},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundEmbers9",
			texture = "kk_flare_01",
			offset = {4.1278, 3, 19.5764},
			shape = {
				type = "Box",
				size = {9.4075, 2, 9.4075},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 10, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.5, 0.4},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.3, 5, 5, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
	},
	light = {
		color = {255, 150, 60},
		brightness = 6,
		range = 60,
		time = 1,
	},
}

-- La explosión gigante anterior (fuego, estilo detonación), por si quieres volver a ella. Explosión GIGANTE: destello, onda de choque, ola de polvo, bola de fuego, rocas en llamas, hongo de humo y fuego en el suelo 5 s. Cierra limpio a los 5.8 s.
function KaijuFireVFX.GiantExplosionClassic(cf: CFrame, scale: number?, shake: number?): Part
	return play(SPEC_GiantExplosionClassic, cf, scale, nil, shake)
end

local SPEC_H3_Detonation = {
	name = "H3_Detonation",
	duration = 2.8,
	cleanup = 3.7,
	layers = {
		{
			name = "TD_FlashBurst",
			texture = "fx_burst_a",
			lifetime = {0.1, 0.13},
			size = {
				{0, 6, 0},
				{0.3, 22.8, 0},
				{1, 25.2, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					1,
					{255, 150, 60},
				},
			},
			light_emission = 0.35,
			brightness = 1,
			rotation = {0, 360},
			zoffset = 4.8,
			rock_emit = {
				{
					{0, 2, 0, 0, 3.36},
				},
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
			name = "TD_GroundRing",
			decal = true,
			texture = "fx_shock_spiky",
			lifetime = {0.4, 0.4},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			size = {
				{0, 9.6, 0},
				{0.25, 22.8, 0},
				{1, 31.2, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 176, 90},
				},
				{
					1,
					{255, 120, 50},
				},
			},
			light_emission = 0.35,
			rotation = {0, 360},
			rock_emit = {
				{
					{0, 1, 0, 0, 0.3},
				},
			},
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
			name = "TD_DustWave",
			texture = "kk_smoke_07",
			direction = "Front",
			spread = {180, 3},
			speed = {48, 72},
			drag = 3.6,
			accel = {0, 2.4, 0},
			lifetime = {1, 1.35},
			size = {
				{0, 3.84, 0.96},
				{0.3, 9.6, 1.68},
				{1, 13.68, 2.16},
			},
			transparency = {
				{0, 0.45, 0},
				{0.15, 0.18, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{222, 200, 172},
				},
				{
					0.5,
					{200, 186, 170},
				},
				{
					1,
					{186, 178, 170},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -1.2,
			rock_emit = {
				{
					{0.02, 12, 0, 0, 2.5},
				},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TD_FireDome",
			texture = "kk_fire_01",
			shape = {
				type = "Sphere",
				radius = 1.92,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {70, 70},
			speed = {8.4, 16.8},
			drag = 4,
			accel = {0, 6, 0},
			lifetime = {0.55, 0.75},
			size = {
				{0, 3.36, 0.96},
				{0.15, 7.68, 1.44},
				{0.6, 9.12, 1.44},
				{1, 9.6, 1.44},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 232, 160},
				},
				{
					0.1,
					{255, 196, 90},
				},
				{
					0.3,
					{255, 150, 46},
				},
				{
					0.6,
					{236, 96, 28},
				},
				{
					1,
					{150, 50, 20},
				},
			},
			light_emission = 0.2,
			brightness = 1.35,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			rock_emit = {
				{
					{0, 5, 0, 0, 2.4},
				},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TD_FireDome2",
			texture = "kk_fire_02",
			shape = {
				type = "Sphere",
				radius = 1.92,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {70, 70},
			speed = {7.2, 14.4},
			drag = 4,
			accel = {0, 6, 0},
			lifetime = {0.5, 0.7},
			size = {
				{0, 3.12, 0.96},
				{0.15, 7.2, 1.2},
				{0.6, 8.64, 1.2},
				{1, 9.12, 1.2},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 232, 160},
				},
				{
					0.1,
					{255, 196, 90},
				},
				{
					0.3,
					{255, 150, 46},
				},
				{
					0.6,
					{236, 96, 28},
				},
				{
					1,
					{150, 50, 20},
				},
			},
			light_emission = 0.2,
			brightness = 1.35,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			rock_emit = {
				{
					{0.03, 3, 0, 0, 2.4},
				},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TD_Sparks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {75, 75},
			speed = {52.8, 96},
			drag = 4,
			accel = {0, -21.6, 0},
			lifetime = {0.3, 0.55},
			size = {
				{0, 8.16, 1.92},
				{1, 2.88, 0},
			},
			color = {
				{
					0,
					{255, 238, 150},
				},
				{
					0.5,
					{255, 184, 60},
				},
				{
					1,
					{255, 110, 24},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			rock_emit = {
				{
					{0, 14, 0, 0, 3.36},
				},
			},
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
			name = "TD_Rocks",
			type = "meteor",
			direction = "Top",
			spread = {60, 60},
			speed = {30, 48},
			accel = {0, -50.4, 0},
			drag = 0.2,
			lifetime = {1.4, 1.8},
			trails = {
				{
					name = "TD_RockSmoke",
					rate = 40,
					texture = "kk_smoke_04",
					speed = {1, 4},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					accel = {0, 6, 0},
					lifetime = {0.5, 0.8},
					size = {
						{0, 1.32, 0.8},
						{1, 3.84, 2},
					},
					transparency = {
						{0, 0.3, 0},
						{0.6, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 170, 80},
						},
						{
							0.2,
							{100, 88, 82},
						},
						{
							1,
							{140, 134, 130},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
				{
					name = "TD_RockFire",
					rate = 55,
					texture = "kk_fire_01",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					lifetime = {0.16, 0.26},
					size = {
						{0, 2.4, 1.2},
						{1, 0.648, 0},
					},
					color = {
						{
							0,
							{255, 246, 210},
						},
						{
							0.3,
							{255, 170, 60},
						},
						{
							1,
							{200, 60, 22},
						},
					},
					light_emission = 0.5,
					brightness = 1.6,
					rotation = {0, 360},
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
			land = {
				{
					name = "TD_RockDust",
					emit = {
						{0, 4},
					},
					texture = "kk_smoke_04",
					direction = "Top",
					spread = {75, 75},
					speed = {8, 18},
					drag = 3,
					accel = {0, 4, 0},
					lifetime = {0.6, 0.9},
					size = {
						{0, 3, 1},
						{0.4, 8, 1.5},
						{1, 10, 1.5},
					},
					transparency = {
						{0, 0.35, 0},
						{0.6, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{222, 200, 172},
						},
						{
							0.5,
							{200, 186, 170},
						},
						{
							1,
							{186, 178, 170},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
				{
					name = "TD_RockBurn",
					texture = "kk_muzzle_05",
					orientation = "VelocityParallel",
					direction = "Top",
					spread = {10, 10},
					speed = {4, 9},
					drag = 2,
					lifetime = {0.35, 0.55},
					size = {
						{0, 1.5, 0.5},
						{0.3, 5, 1},
						{1, 3, 0.8},
					},
					transparency = {
						{0, 0, 0},
						{0.6, 0.12, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 236, 150},
						},
						{
							0.3,
							{255, 176, 60},
						},
						{
							0.7,
							{245, 108, 30},
						},
						{
							1,
							{180, 50, 18},
						},
					},
					light_emission = 0.35,
					brightness = 1.5,
					stream = {
						{0, 0.8, 12, 0},
					},
					accel = {0, 0, 0},
					rotation = {0, 0},
					rot_speed = {0, 0},
					zoffset = 0,
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
			},
			rock_emit = {
				{
					{0.02, 2, 0, 0, 1.68},
				},
			},
			offset = {0, 0, 0},
			emit = {},
			rock = {
				size = {1.032, 1.56},
				spin = {-500, 500},
				material = "Slate",
				color = {60, 50, 48},
			},
		},
		{
			name = "TWS140_Outer",
			texture = "kk_muzzle_04",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.011, 1, 0.1468, 0.39, 23.66},
				},
				{
					{0.008, 1, -0.1027, -1.14, 23.66},
				},
				{},
			},
			final_emit = {
				{0.02, 1, 0, -2.4, 23.66},
				{0.03, 1, 0, 2.2, 23.66},
			},
			accel = {0, -33.275, 0},
			lifetime = {0.75, 0.85},
			size = {
				{0, 36.676, 0},
				{0.08, 59.155, 0},
				{0.55, 60.93, 0},
				{1, 36.676, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.6, 0.04, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 160, 58},
				},
				{
					0.15,
					{255, 128, 40},
				},
				{
					0.5,
					{242, 94, 28},
				},
				{
					0.8,
					{206, 60, 20},
				},
				{
					1,
					{150, 34, 14},
				},
			},
			light_emission = 0.08,
			brightness = 1.1,
			rotation = {-3, 3},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS140_Body",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.026, 1, 0.1468, 0.39, 15.53},
				},
				{
					{0.023, 1, -0.1027, -1.14, 15.53},
				},
				{},
			},
			final_emit = {
				{0.035, 1, 0, -2.4, 15.53},
				{0.045, 1, 0, 2.2, 15.53},
			},
			accel = {0, -24.194, 0},
			lifetime = {0.71, 0.81},
			size = {
				{0, 23.031, 0},
				{0.08, 37.147, 0},
				{0.55, 38.261, 0},
				{1, 23.031, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.55, 0.05, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					0.25,
					{255, 184, 66},
				},
				{
					0.65,
					{252, 140, 44},
				},
				{
					1,
					{226, 94, 30},
				},
			},
			light_emission = 0.2,
			brightness = 1.25,
			rotation = {-6, 6},
			zoffset = 0.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS140_Core",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.031, 1, 0.1468, 0.39, 8.52},
				},
				{
					{0.028, 1, -0.1027, -1.14, 8.52},
				},
				{},
			},
			final_emit = {
				{0.04, 1, 0, -2.4, 8.52},
				{0.05, 1, 0, 2.2, 8.52},
			},
			accel = {0, -14.783, 0},
			lifetime = {0.67, 0.77},
			size = {
				{0, 12.63, 0},
				{0.08, 20.371, 0},
				{0.55, 20.982, 0},
				{1, 12.63, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.06, 0.05, 0},
				{0.5, 0.1, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 220},
				},
				{
					0.4,
					{255, 230, 160},
				},
				{
					1,
					{255, 186, 96},
				},
			},
			light_emission = 0.45,
			brightness = 1.35,
			rotation = {-7, 7},
			zoffset = 1,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS140_Licks",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.051, 2, 0.1468, 0.39, 4.2},
					{0.171, 2, 0.1468, 0.39, 4.2},
					{0.291, 2, 0.1468, 0.39, 4.2},
					{0.411, 2, 0.1468, 0.39, 4.2},
				},
				{
					{0.048, 2, -0.1027, -1.14, 4.2},
					{0.168, 2, -0.1027, -1.14, 4.2},
					{0.288, 2, -0.1027, -1.14, 4.2},
					{0.408, 2, -0.1027, -1.14, 4.2},
				},
				{},
			},
			final_emit = {
				{0.06, 2, 0, -2.4, 4.2},
				{0.18, 2, 0, -2.4, 4.2},
				{0.3, 2, 0, -2.4, 4.2},
				{0.42, 2, 0, -2.4, 4.2},
				{0.07, 2, 0, 2.2, 4.2},
				{0.19, 2, 0, 2.2, 4.2},
				{0.31, 2, 0, 2.2, 4.2},
				{0.43, 2, 0, 2.2, 4.2},
			},
			direction = "Top",
			spread = {6, 6},
			speed = {50.4, 100.8},
			drag = 4,
			lifetime = {0.25, 0.4},
			size = {
				{0, 5.04, 0},
				{0.3, 12.6, 0},
				{1, 5.88, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 160, 58},
				},
				{
					0.15,
					{255, 128, 40},
				},
				{
					0.5,
					{242, 94, 28},
				},
				{
					0.8,
					{206, 60, 20},
				},
				{
					1,
					{150, 34, 14},
				},
			},
			light_emission = 0.15,
			brightness = 1.2,
			zoffset = 0.3,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS140_Foot",
			texture = "kk_fire_01",
			rock_emit = {
				{
					{0.011, 2, 0.1468, 0.39, 2.52},
					{0.161, 2, 0.1468, 0.39, 2.52},
					{0.311, 2, 0.1468, 0.39, 2.52},
				},
				{
					{0.008, 2, -0.1027, -1.14, 2.52},
					{0.158, 2, -0.1027, -1.14, 2.52},
					{0.308, 2, -0.1027, -1.14, 2.52},
				},
				{},
			},
			final_emit = {
				{0.02, 2, 0, -2.4, 2.52},
				{0.17, 2, 0, -2.4, 2.52},
				{0.32, 2, 0, -2.4, 2.52},
				{0.03, 2, 0, 2.2, 2.52},
				{0.18, 2, 0, 2.2, 2.52},
				{0.33, 2, 0, 2.2, 2.52},
			},
			shape = {
				type = "Box",
				size = {8.4, 0.5, 8.4},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {8.4, 33.6},
			drag = 3,
			accel = {0, 12.6, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 5.04, 1.26},
				{0.3, 10.92, 1.68},
				{1, 8.4, 1.26},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					0.25,
					{255, 184, 66},
				},
				{
					0.65,
					{252, 140, 44},
				},
				{
					1,
					{226, 94, 30},
				},
			},
			light_emission = 0.25,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 1.5,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS140_Pop",
			texture = "fx_burst_fan",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.011, 1, 0.1468, 0.39, 8.4},
				},
				{
					{0.008, 1, -0.1027, -1.14, 8.4},
				},
				{},
			},
			final_emit = {
				{0.02, 1, 0, -2.4, 8.4},
				{0.03, 1, 0, 2.2, 8.4},
			},
			lifetime = {0.16, 0.2},
			size = {
				{0, 8.4, 0},
				{0.3, 23.1, 0},
				{1, 26.04, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 200},
				},
				{
					0.4,
					{255, 200, 100},
				},
				{
					1,
					{255, 140, 50},
				},
			},
			light_emission = 0.25,
			brightness = 1.15,
			zoffset = 2,
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
			name = "TWS140_Streak",
			texture = "fx_line",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.011, 1, 0.1468, 0.39, 2.1},
				},
				{
					{0.008, 1, -0.1027, -1.14, 2.1},
				},
				{},
			},
			final_emit = {
				{0.02, 1, 0, -2.4, 2.1},
				{0.03, 1, 0, 2.2, 2.1},
			},
			direction = "Top",
			spread = {2, 2},
			speed = {168, 210},
			drag = 8,
			lifetime = {0.2, 0.26},
			size = {
				{0, 25.2, 4.2},
				{1, 33.6, 4.2},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 225},
				},
				{
					1,
					{255, 200, 110},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS140_Embers",
			texture = "kk_flare_01",
			rock_emit = {
				{
					{0.111, 2, 0.1468, 0.39, 21},
					{0.361, 2, 0.1468, 0.39, 21},
				},
				{
					{0.108, 2, -0.1027, -1.14, 21},
					{0.358, 2, -0.1027, -1.14, 21},
				},
				{},
			},
			final_emit = {
				{0.12, 2, 0, -2.4, 21},
				{0.37, 2, 0, -2.4, 21},
				{0.13, 2, 0, 2.2, 21},
				{0.38, 2, 0, 2.2, 21},
			},
			shape = {
				type = "Box",
				size = {6.3, 29.4, 6.3},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {40, 40},
			speed = {4.2, 21},
			drag = 1.6,
			accel = {0, 10.5, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.68, 0.504},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
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
			name = "TWS100_Outer",
			texture = "kk_muzzle_04",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{},
				{
					{0.004, 1, 0.1597, -1.02, 16.9},
				},
				{
					{0.002, 1, -0.1463, 0.15, 16.9},
					{0.004, 1, 0.1098, 0.43, 16.9},
				},
			},
			final_emit = {
				{0.04, 1, 0, -4.6, 16.9},
				{0.05, 1, 0, 4.4, 16.9},
				{0.03, 1, -0.25, 0.8, 16.9},
			},
			accel = {0, -23.768, 0},
			lifetime = {0.75, 0.85},
			size = {
				{0, 26.197, 0},
				{0.08, 42.254, 0},
				{0.55, 43.521, 0},
				{1, 26.197, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.6, 0.04, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 160, 58},
				},
				{
					0.15,
					{255, 128, 40},
				},
				{
					0.5,
					{242, 94, 28},
				},
				{
					0.8,
					{206, 60, 20},
				},
				{
					1,
					{150, 34, 14},
				},
			},
			light_emission = 0.08,
			brightness = 1.1,
			rotation = {-3, 3},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS100_Body",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{},
				{
					{0.019, 1, 0.1597, -1.02, 11.09},
				},
				{
					{0.017, 1, -0.1463, 0.15, 11.09},
					{0.019, 1, 0.1098, 0.43, 11.09},
				},
			},
			final_emit = {
				{0.055, 1, 0, -4.6, 11.09},
				{0.065, 1, 0, 4.4, 11.09},
				{0.045, 1, -0.25, 0.8, 11.09},
			},
			accel = {0, -17.282, 0},
			lifetime = {0.71, 0.81},
			size = {
				{0, 16.451, 0},
				{0.08, 26.534, 0},
				{0.55, 27.33, 0},
				{1, 16.451, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.55, 0.05, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					0.25,
					{255, 184, 66},
				},
				{
					0.65,
					{252, 140, 44},
				},
				{
					1,
					{226, 94, 30},
				},
			},
			light_emission = 0.2,
			brightness = 1.25,
			rotation = {-6, 6},
			zoffset = 0.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS100_Core",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{},
				{
					{0.024, 1, 0.1597, -1.02, 6.08},
				},
				{
					{0.022, 1, -0.1463, 0.15, 6.08},
					{0.024, 1, 0.1098, 0.43, 6.08},
				},
			},
			final_emit = {
				{0.06, 1, 0, -4.6, 6.08},
				{0.07, 1, 0, 4.4, 6.08},
				{0.05, 1, -0.25, 0.8, 6.08},
			},
			accel = {0, -10.559, 0},
			lifetime = {0.67, 0.77},
			size = {
				{0, 9.021, 0},
				{0.08, 14.551, 0},
				{0.55, 14.987, 0},
				{1, 9.021, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.06, 0.05, 0},
				{0.5, 0.1, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 220},
				},
				{
					0.4,
					{255, 230, 160},
				},
				{
					1,
					{255, 186, 96},
				},
			},
			light_emission = 0.45,
			brightness = 1.35,
			rotation = {-7, 7},
			zoffset = 1,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS100_Licks",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			rock_emit = {
				{},
				{
					{0.044, 2, 0.1597, -1.02, 3},
					{0.164, 2, 0.1597, -1.02, 3},
					{0.284, 2, 0.1597, -1.02, 3},
					{0.404, 2, 0.1597, -1.02, 3},
				},
				{
					{0.042, 2, -0.1463, 0.15, 3},
					{0.162, 2, -0.1463, 0.15, 3},
					{0.282, 2, -0.1463, 0.15, 3},
					{0.402, 2, -0.1463, 0.15, 3},
					{0.044, 2, 0.1098, 0.43, 3},
					{0.164, 2, 0.1098, 0.43, 3},
					{0.284, 2, 0.1098, 0.43, 3},
					{0.404, 2, 0.1098, 0.43, 3},
				},
			},
			final_emit = {
				{0.08, 2, 0, -4.6, 3},
				{0.2, 2, 0, -4.6, 3},
				{0.32, 2, 0, -4.6, 3},
				{0.44, 2, 0, -4.6, 3},
				{0.09, 2, 0, 4.4, 3},
				{0.21, 2, 0, 4.4, 3},
				{0.33, 2, 0, 4.4, 3},
				{0.45, 2, 0, 4.4, 3},
				{0.07, 2, -0.25, 0.8, 3},
				{0.19, 2, -0.25, 0.8, 3},
				{0.31, 2, -0.25, 0.8, 3},
				{0.43, 2, -0.25, 0.8, 3},
			},
			direction = "Top",
			spread = {6, 6},
			speed = {36, 72},
			drag = 4,
			lifetime = {0.25, 0.4},
			size = {
				{0, 3.6, 0},
				{0.3, 9, 0},
				{1, 4.2, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 160, 58},
				},
				{
					0.15,
					{255, 128, 40},
				},
				{
					0.5,
					{242, 94, 28},
				},
				{
					0.8,
					{206, 60, 20},
				},
				{
					1,
					{150, 34, 14},
				},
			},
			light_emission = 0.15,
			brightness = 1.2,
			zoffset = 0.3,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS100_Foot",
			texture = "kk_fire_01",
			rock_emit = {
				{},
				{
					{0.004, 2, 0.1597, -1.02, 1.8},
					{0.154, 2, 0.1597, -1.02, 1.8},
					{0.304, 2, 0.1597, -1.02, 1.8},
				},
				{
					{0.002, 2, -0.1463, 0.15, 1.8},
					{0.152, 2, -0.1463, 0.15, 1.8},
					{0.302, 2, -0.1463, 0.15, 1.8},
					{0.004, 2, 0.1098, 0.43, 1.8},
					{0.154, 2, 0.1098, 0.43, 1.8},
					{0.304, 2, 0.1098, 0.43, 1.8},
				},
			},
			final_emit = {
				{0.04, 2, 0, -4.6, 1.8},
				{0.19, 2, 0, -4.6, 1.8},
				{0.34, 2, 0, -4.6, 1.8},
				{0.05, 2, 0, 4.4, 1.8},
				{0.2, 2, 0, 4.4, 1.8},
				{0.35, 2, 0, 4.4, 1.8},
				{0.03, 2, -0.25, 0.8, 1.8},
				{0.18, 2, -0.25, 0.8, 1.8},
				{0.33, 2, -0.25, 0.8, 1.8},
			},
			shape = {
				type = "Box",
				size = {6, 0.5, 6},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {6, 24},
			drag = 3,
			accel = {0, 9, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 3.6, 0.9},
				{0.3, 7.8, 1.2},
				{1, 6, 0.9},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					0.25,
					{255, 184, 66},
				},
				{
					0.65,
					{252, 140, 44},
				},
				{
					1,
					{226, 94, 30},
				},
			},
			light_emission = 0.25,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 1.5,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS100_Pop",
			texture = "fx_burst_fan",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{},
				{
					{0.004, 1, 0.1597, -1.02, 6},
				},
				{
					{0.002, 1, -0.1463, 0.15, 6},
					{0.004, 1, 0.1098, 0.43, 6},
				},
			},
			final_emit = {
				{0.04, 1, 0, -4.6, 6},
				{0.05, 1, 0, 4.4, 6},
				{0.03, 1, -0.25, 0.8, 6},
			},
			lifetime = {0.16, 0.2},
			size = {
				{0, 6, 0},
				{0.3, 16.5, 0},
				{1, 18.6, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 200},
				},
				{
					0.4,
					{255, 200, 100},
				},
				{
					1,
					{255, 140, 50},
				},
			},
			light_emission = 0.25,
			brightness = 1.15,
			zoffset = 2,
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
			name = "TWS100_Streak",
			texture = "fx_line",
			orientation = "VelocityParallel",
			rock_emit = {
				{},
				{
					{0.004, 1, 0.1597, -1.02, 1.5},
				},
				{
					{0.002, 1, -0.1463, 0.15, 1.5},
					{0.004, 1, 0.1098, 0.43, 1.5},
				},
			},
			final_emit = {
				{0.04, 1, 0, -4.6, 1.5},
				{0.05, 1, 0, 4.4, 1.5},
				{0.03, 1, -0.25, 0.8, 1.5},
			},
			direction = "Top",
			spread = {2, 2},
			speed = {120, 150},
			drag = 8,
			lifetime = {0.2, 0.26},
			size = {
				{0, 18, 3},
				{1, 24, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 225},
				},
				{
					1,
					{255, 200, 110},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS100_Embers",
			texture = "kk_flare_01",
			rock_emit = {
				{},
				{
					{0.104, 2, 0.1597, -1.02, 15},
					{0.354, 2, 0.1597, -1.02, 15},
				},
				{
					{0.102, 2, -0.1463, 0.15, 15},
					{0.352, 2, -0.1463, 0.15, 15},
					{0.104, 2, 0.1098, 0.43, 15},
					{0.354, 2, 0.1098, 0.43, 15},
				},
			},
			final_emit = {
				{0.14, 2, 0, -4.6, 15},
				{0.39, 2, 0, -4.6, 15},
				{0.15, 2, 0, 4.4, 15},
				{0.4, 2, 0, 4.4, 15},
				{0.13, 2, -0.25, 0.8, 15},
				{0.38, 2, -0.25, 0.8, 15},
			},
			shape = {
				type = "Box",
				size = {4.5, 21, 4.5},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {40, 40},
			speed = {3, 15},
			drag = 1.6,
			accel = {0, 7.5, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.2, 0.36},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
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
			name = "TWS74_Outer",
			texture = "kk_muzzle_04",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.008, 1, -0.1561, 0.03, 12.51},
				},
				{
					{0.008, 1, 0.4125, 0.96, 12.51},
				},
				{
					{0.006, 1, -0.3854, -0.22, 12.51},
					{0.018, 1, 0.3953, -0.99, 12.51},
				},
			},
			accel = {0, -17.588, 0},
			lifetime = {0.75, 0.85},
			size = {
				{0, 19.386, 0},
				{0.08, 31.268, 0},
				{0.55, 32.206, 0},
				{1, 19.386, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.6, 0.04, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 160, 58},
				},
				{
					0.15,
					{255, 128, 40},
				},
				{
					0.5,
					{242, 94, 28},
				},
				{
					0.8,
					{206, 60, 20},
				},
				{
					1,
					{150, 34, 14},
				},
			},
			light_emission = 0.08,
			brightness = 1.1,
			rotation = {-3, 3},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS74_Body",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.023, 1, -0.1561, 0.03, 8.21},
				},
				{
					{0.023, 1, 0.4125, 0.96, 8.21},
				},
				{
					{0.021, 1, -0.3854, -0.22, 8.21},
					{0.033, 1, 0.3953, -0.99, 8.21},
				},
			},
			accel = {0, -12.788, 0},
			lifetime = {0.71, 0.81},
			size = {
				{0, 12.174, 0},
				{0.08, 19.635, 0},
				{0.55, 20.224, 0},
				{1, 12.174, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.55, 0.05, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					0.25,
					{255, 184, 66},
				},
				{
					0.65,
					{252, 140, 44},
				},
				{
					1,
					{226, 94, 30},
				},
			},
			light_emission = 0.2,
			brightness = 1.25,
			rotation = {-6, 6},
			zoffset = 0.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS74_Core",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.028, 1, -0.1561, 0.03, 4.5},
				},
				{
					{0.028, 1, 0.4125, 0.96, 4.5},
				},
				{
					{0.026, 1, -0.3854, -0.22, 4.5},
					{0.038, 1, 0.3953, -0.99, 4.5},
				},
			},
			accel = {0, -7.814, 0},
			lifetime = {0.67, 0.77},
			size = {
				{0, 6.676, 0},
				{0.08, 10.767, 0},
				{0.55, 11.09, 0},
				{1, 6.676, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.06, 0.05, 0},
				{0.5, 0.1, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 220},
				},
				{
					0.4,
					{255, 230, 160},
				},
				{
					1,
					{255, 186, 96},
				},
			},
			light_emission = 0.45,
			brightness = 1.35,
			rotation = {-7, 7},
			zoffset = 1,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS74_Licks",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.048, 2, -0.1561, 0.03, 2.22},
					{0.168, 2, -0.1561, 0.03, 2.22},
					{0.288, 2, -0.1561, 0.03, 2.22},
					{0.408, 2, -0.1561, 0.03, 2.22},
				},
				{
					{0.048, 2, 0.4125, 0.96, 2.22},
					{0.168, 2, 0.4125, 0.96, 2.22},
					{0.288, 2, 0.4125, 0.96, 2.22},
					{0.408, 2, 0.4125, 0.96, 2.22},
				},
				{
					{0.046, 2, -0.3854, -0.22, 2.22},
					{0.166, 2, -0.3854, -0.22, 2.22},
					{0.286, 2, -0.3854, -0.22, 2.22},
					{0.406, 2, -0.3854, -0.22, 2.22},
					{0.058, 2, 0.3953, -0.99, 2.22},
					{0.178, 2, 0.3953, -0.99, 2.22},
					{0.298, 2, 0.3953, -0.99, 2.22},
					{0.418, 2, 0.3953, -0.99, 2.22},
				},
			},
			direction = "Top",
			spread = {6, 6},
			speed = {26.64, 53.28},
			drag = 4,
			lifetime = {0.25, 0.4},
			size = {
				{0, 2.664, 0},
				{0.3, 6.66, 0},
				{1, 3.108, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 160, 58},
				},
				{
					0.15,
					{255, 128, 40},
				},
				{
					0.5,
					{242, 94, 28},
				},
				{
					0.8,
					{206, 60, 20},
				},
				{
					1,
					{150, 34, 14},
				},
			},
			light_emission = 0.15,
			brightness = 1.2,
			zoffset = 0.3,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS74_Foot",
			texture = "kk_fire_01",
			rock_emit = {
				{
					{0.008, 2, -0.1561, 0.03, 1.33},
					{0.158, 2, -0.1561, 0.03, 1.33},
					{0.308, 2, -0.1561, 0.03, 1.33},
				},
				{
					{0.008, 2, 0.4125, 0.96, 1.33},
					{0.158, 2, 0.4125, 0.96, 1.33},
					{0.308, 2, 0.4125, 0.96, 1.33},
				},
				{
					{0.006, 2, -0.3854, -0.22, 1.33},
					{0.156, 2, -0.3854, -0.22, 1.33},
					{0.306, 2, -0.3854, -0.22, 1.33},
					{0.018, 2, 0.3953, -0.99, 1.33},
					{0.168, 2, 0.3953, -0.99, 1.33},
					{0.318, 2, 0.3953, -0.99, 1.33},
				},
			},
			shape = {
				type = "Box",
				size = {4.44, 0.5, 4.44},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {4.44, 17.76},
			drag = 3,
			accel = {0, 6.66, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 2.664, 0.666},
				{0.3, 5.772, 0.888},
				{1, 4.44, 0.666},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					0.25,
					{255, 184, 66},
				},
				{
					0.65,
					{252, 140, 44},
				},
				{
					1,
					{226, 94, 30},
				},
			},
			light_emission = 0.25,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 1.5,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS74_Pop",
			texture = "fx_burst_fan",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.008, 1, -0.1561, 0.03, 4.44},
				},
				{
					{0.008, 1, 0.4125, 0.96, 4.44},
				},
				{
					{0.006, 1, -0.3854, -0.22, 4.44},
					{0.018, 1, 0.3953, -0.99, 4.44},
				},
			},
			lifetime = {0.16, 0.2},
			size = {
				{0, 4.44, 0},
				{0.3, 12.21, 0},
				{1, 13.764, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 200},
				},
				{
					0.4,
					{255, 200, 100},
				},
				{
					1,
					{255, 140, 50},
				},
			},
			light_emission = 0.25,
			brightness = 1.15,
			zoffset = 2,
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
			name = "TWS74_Streak",
			texture = "fx_line",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.008, 1, -0.1561, 0.03, 1.11},
				},
				{
					{0.008, 1, 0.4125, 0.96, 1.11},
				},
				{
					{0.006, 1, -0.3854, -0.22, 1.11},
					{0.018, 1, 0.3953, -0.99, 1.11},
				},
			},
			direction = "Top",
			spread = {2, 2},
			speed = {88.8, 111},
			drag = 8,
			lifetime = {0.2, 0.26},
			size = {
				{0, 13.32, 2.22},
				{1, 17.76, 2.22},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 225},
				},
				{
					1,
					{255, 200, 110},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS74_Embers",
			texture = "kk_flare_01",
			rock_emit = {
				{
					{0.108, 2, -0.1561, 0.03, 11.1},
					{0.358, 2, -0.1561, 0.03, 11.1},
				},
				{
					{0.108, 2, 0.4125, 0.96, 11.1},
					{0.358, 2, 0.4125, 0.96, 11.1},
				},
				{
					{0.106, 2, -0.3854, -0.22, 11.1},
					{0.356, 2, -0.3854, -0.22, 11.1},
					{0.118, 2, 0.3953, -0.99, 11.1},
					{0.368, 2, 0.3953, -0.99, 11.1},
				},
			},
			shape = {
				type = "Box",
				size = {3.33, 15.54, 3.33},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {40, 40},
			speed = {2.22, 11.1},
			drag = 1.6,
			accel = {0, 5.55, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 0.888, 0.266},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
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
			name = "TWS52_Outer",
			texture = "kk_muzzle_04",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.018, 1, -0.3683, -1, 8.79},
					{0.004, 1, 0.3832, -0.93, 8.79},
				},
				{
					{0.005, 1, -0.3771, -0.94, 8.79},
				},
				{},
			},
			accel = {0, -12.359, 0},
			lifetime = {0.75, 0.85},
			size = {
				{0, 13.623, 0},
				{0.08, 21.972, 0},
				{0.55, 22.631, 0},
				{1, 13.623, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.6, 0.04, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 160, 58},
				},
				{
					0.15,
					{255, 128, 40},
				},
				{
					0.5,
					{242, 94, 28},
				},
				{
					0.8,
					{206, 60, 20},
				},
				{
					1,
					{150, 34, 14},
				},
			},
			light_emission = 0.08,
			brightness = 1.1,
			rotation = {-3, 3},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS52_Body",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.033, 1, -0.3683, -1, 5.77},
					{0.019, 1, 0.3832, -0.93, 5.77},
				},
				{
					{0.02, 1, -0.3771, -0.94, 5.77},
				},
				{},
			},
			accel = {0, -8.986, 0},
			lifetime = {0.71, 0.81},
			size = {
				{0, 8.554, 0},
				{0.08, 13.797, 0},
				{0.55, 14.211, 0},
				{1, 8.554, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.55, 0.05, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					0.25,
					{255, 184, 66},
				},
				{
					0.65,
					{252, 140, 44},
				},
				{
					1,
					{226, 94, 30},
				},
			},
			light_emission = 0.2,
			brightness = 1.25,
			rotation = {-6, 6},
			zoffset = 0.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS52_Core",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.038, 1, -0.3683, -1, 3.16},
					{0.024, 1, 0.3832, -0.93, 3.16},
				},
				{
					{0.025, 1, -0.3771, -0.94, 3.16},
				},
				{},
			},
			accel = {0, -5.491, 0},
			lifetime = {0.67, 0.77},
			size = {
				{0, 4.691, 0},
				{0.08, 7.566, 0},
				{0.55, 7.793, 0},
				{1, 4.691, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.06, 0.05, 0},
				{0.5, 0.1, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 220},
				},
				{
					0.4,
					{255, 230, 160},
				},
				{
					1,
					{255, 186, 96},
				},
			},
			light_emission = 0.45,
			brightness = 1.35,
			rotation = {-7, 7},
			zoffset = 1,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS52_Licks",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.058, 2, -0.3683, -1, 1.56},
					{0.178, 2, -0.3683, -1, 1.56},
					{0.298, 2, -0.3683, -1, 1.56},
					{0.418, 2, -0.3683, -1, 1.56},
					{0.044, 2, 0.3832, -0.93, 1.56},
					{0.164, 2, 0.3832, -0.93, 1.56},
					{0.284, 2, 0.3832, -0.93, 1.56},
					{0.404, 2, 0.3832, -0.93, 1.56},
				},
				{
					{0.045, 2, -0.3771, -0.94, 1.56},
					{0.165, 2, -0.3771, -0.94, 1.56},
					{0.285, 2, -0.3771, -0.94, 1.56},
					{0.405, 2, -0.3771, -0.94, 1.56},
				},
				{},
			},
			direction = "Top",
			spread = {6, 6},
			speed = {18.72, 37.44},
			drag = 4,
			lifetime = {0.25, 0.4},
			size = {
				{0, 1.872, 0},
				{0.3, 4.68, 0},
				{1, 2.184, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 160, 58},
				},
				{
					0.15,
					{255, 128, 40},
				},
				{
					0.5,
					{242, 94, 28},
				},
				{
					0.8,
					{206, 60, 20},
				},
				{
					1,
					{150, 34, 14},
				},
			},
			light_emission = 0.15,
			brightness = 1.2,
			zoffset = 0.3,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS52_Foot",
			texture = "kk_fire_01",
			rock_emit = {
				{
					{0.018, 2, -0.3683, -1, 0.94},
					{0.168, 2, -0.3683, -1, 0.94},
					{0.318, 2, -0.3683, -1, 0.94},
					{0.004, 2, 0.3832, -0.93, 0.94},
					{0.154, 2, 0.3832, -0.93, 0.94},
					{0.304, 2, 0.3832, -0.93, 0.94},
				},
				{
					{0.005, 2, -0.3771, -0.94, 0.94},
					{0.155, 2, -0.3771, -0.94, 0.94},
					{0.305, 2, -0.3771, -0.94, 0.94},
				},
				{},
			},
			shape = {
				type = "Box",
				size = {3.12, 0.5, 3.12},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {3.12, 12.48},
			drag = 3,
			accel = {0, 4.68, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 1.872, 0.468},
				{0.3, 4.056, 0.624},
				{1, 3.12, 0.468},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					0.25,
					{255, 184, 66},
				},
				{
					0.65,
					{252, 140, 44},
				},
				{
					1,
					{226, 94, 30},
				},
			},
			light_emission = 0.25,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 1.5,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS52_Pop",
			texture = "fx_burst_fan",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.018, 1, -0.3683, -1, 3.12},
					{0.004, 1, 0.3832, -0.93, 3.12},
				},
				{
					{0.005, 1, -0.3771, -0.94, 3.12},
				},
				{},
			},
			lifetime = {0.16, 0.2},
			size = {
				{0, 3.12, 0},
				{0.3, 8.58, 0},
				{1, 9.672, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 200},
				},
				{
					0.4,
					{255, 200, 100},
				},
				{
					1,
					{255, 140, 50},
				},
			},
			light_emission = 0.25,
			brightness = 1.15,
			zoffset = 2,
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
			name = "TWS52_Streak",
			texture = "fx_line",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.018, 1, -0.3683, -1, 0.78},
					{0.004, 1, 0.3832, -0.93, 0.78},
				},
				{
					{0.005, 1, -0.3771, -0.94, 0.78},
				},
				{},
			},
			direction = "Top",
			spread = {2, 2},
			speed = {62.4, 78},
			drag = 8,
			lifetime = {0.2, 0.26},
			size = {
				{0, 9.36, 1.56},
				{1, 12.48, 1.56},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 225},
				},
				{
					1,
					{255, 200, 110},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TWS52_Embers",
			texture = "kk_flare_01",
			rock_emit = {
				{
					{0.118, 2, -0.3683, -1, 7.8},
					{0.368, 2, -0.3683, -1, 7.8},
					{0.104, 2, 0.3832, -0.93, 7.8},
					{0.354, 2, 0.3832, -0.93, 7.8},
				},
				{
					{0.105, 2, -0.3771, -0.94, 7.8},
					{0.355, 2, -0.3771, -0.94, 7.8},
				},
				{},
			},
			shape = {
				type = "Box",
				size = {2.34, 10.92, 2.34},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {40, 40},
			speed = {1.56, 7.8},
			drag = 1.6,
			accel = {0, 3.9, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 0.624, 0.187},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
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
			name = "TW_WallSmoke",
			texture = "kk_smoke_08",
			rock_emit = {
				{
					{0.23, 1, 0.3832, -2.31, 10.86},
					{0.25, 1, 0.1468, -0.85, 32.17},
					{0.272, 1, -0.1561, -0.39, 13.77},
					{0.274, 1, -0.3683, -1.23, 12.25},
					{0.446, 1, -0.3683, -1.92, 11.79},
					{0.458, 1, 0.3832, 0.03, 11.17},
					{0.474, 1, 0.1468, 0.66, 31.78},
					{0.475, 1, -0.1561, 0.3, 18.43},
					{0.646, 1, 0.3832, -1.56, 11.02},
					{0.651, 1, -0.3683, -1.13, 9.5},
					{0.665, 1, -0.1561, 1.44, 16.14},
					{0.67, 1, 0.1468, -0.56, 27.82},
				},
				{
					{0.252, 1, 0.1597, -1.93, 27.8},
					{0.255, 1, 0.4125, 0.49, 20.25},
					{0.272, 1, -0.3771, -0.32, 13.88},
					{0.277, 1, -0.1027, -0.58, 39.51},
					{0.439, 1, -0.3771, -0.8, 14.38},
					{0.476, 1, -0.1027, 0.21, 33.12},
					{0.477, 1, 0.4125, 2.15, 18.66},
					{0.481, 1, 0.1597, -1.87, 19.09},
					{0.653, 1, 0.4125, 1.54, 19.77},
					{0.656, 1, 0.1597, -2.01, 23.71},
					{0.661, 1, -0.3771, 0.4, 10.27},
					{0.687, 1, -0.1027, -0.39, 30.29},
				},
				{
					{0.234, 1, 0.1098, 0.28, 22.44},
					{0.255, 1, -0.1463, -0.64, 23.89},
					{0.272, 1, -0.3854, -0.05, 17.59},
					{0.291, 1, 0.3953, 0.1, 17.19},
					{0.429, 1, 0.1098, 1.03, 23.04},
					{0.45, 1, -0.1463, 0, 25.54},
					{0.476, 1, -0.3854, -1.39, 18.22},
					{0.485, 1, 0.3953, -0.47, 18.02},
					{0.622, 1, -0.1463, -0.22, 26.25},
					{0.646, 1, -0.3854, -0.04, 19.81},
					{0.655, 1, 0.3953, -1.53, 16.03},
					{0.665, 1, 0.1098, 0.55, 23.84},
				},
			},
			final_emit = {
				{0.258, 1, 0, -1.02, 30.22},
				{0.267, 1, 0, 0.97, 28.39},
				{0.268, 1, -0.25, -0.47, 27.61},
				{0.294, 1, 0, -4.77, 27.01},
				{0.318, 1, 0, 3.73, 21.8},
				{0.463, 1, 0, -2.64, 37.2},
				{0.466, 1, 0, 3.26, 32.59},
				{0.476, 1, 0, -3.55, 20.6},
				{0.479, 1, 0, 5.41, 18.95},
				{0.489, 1, -0.25, -0.19, 28.25},
				{0.657, 1, 0, 2.09, 26.98},
				{0.669, 1, 0, -2.24, 28.96},
				{0.705, 1, -0.25, -0.15, 18.2},
				{0.714, 1, 0, 4.09, 25.13},
				{0.719, 1, 0, -4.2, 18.45},
			},
			direction = "Top",
			spread = {25, 25},
			speed = {2.4, 10.5},
			drag = 1,
			accel = {0, 4.5, 0},
			lifetime = {1.3, 1.9},
			size = {
				{0, 4.8, 1.2},
				{0.35, 12, 2.4},
				{1, 18, 3},
			},
			transparency = {
				{0, 0.8, 0},
				{0.12, 0.45, 0},
				{0.5, 0.6, 0},
				{0.8, 0.85, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{150, 96, 64},
				},
				{
					0.15,
					{92, 80, 74},
				},
				{
					0.6,
					{120, 114, 110},
				},
				{
					1,
					{150, 146, 142},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -9,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFin_FlashBurst",
			texture = "fx_burst_a",
			lifetime = {0.1, 0.13},
			size = {
				{0, 11, 0},
				{0.3, 41.8, 0},
				{1, 46.2, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					1,
					{255, 150, 60},
				},
			},
			light_emission = 0.35,
			brightness = 1,
			rotation = {0, 360},
			zoffset = 8.8,
			final_emit = {
				{0, 2, 0, 0, 6.16},
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
			name = "TFin_FlashStar",
			texture = "fx_star",
			lifetime = {0.15, 0.15},
			size = {
				{0, 26.4, 0},
				{0.25, 79.2, 0},
				{1, 44, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.6, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					1,
					{255, 150, 60},
				},
			},
			light_emission = 0.5,
			brightness = 1,
			zoffset = 9.68,
			final_emit = {
				{0, 1, 0, 0, 6.16},
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
			name = "TFin_Glow",
			texture = "fx_glow",
			lifetime = {0.7, 0.7},
			size = {
				{0, 22, 0},
				{0.15, 66, 0},
				{1, 74.8, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{0.4, 0.75, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 170, 70},
				},
				{
					1,
					{230, 90, 30},
				},
			},
			light_emission = 0.3,
			zoffset = -8.8,
			final_emit = {
				{0, 1, 0, 0, 11},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFin_GroundRing",
			decal = true,
			texture = "fx_shock_spiky",
			lifetime = {0.4, 0.4},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			size = {
				{0, 17.6, 0},
				{0.25, 41.8, 0},
				{1, 57.2, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 176, 90},
				},
				{
					1,
					{255, 120, 50},
				},
			},
			light_emission = 0.35,
			rotation = {0, 360},
			final_emit = {
				{0, 1, 0, 0, 0.3},
			},
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
			name = "TFin_ShockRing",
			decal = true,
			texture = "kk_circle_03",
			lifetime = {0.55, 0.55},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			size = {
				{0, 22, 0},
				{0.2, 70.4, 0},
				{0.6, 110, 0},
				{1, 123.2, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 176, 90},
				},
				{
					1,
					{255, 120, 50},
				},
			},
			light_emission = 0.35,
			final_emit = {
				{0, 1, 0, 0, 0.35},
			},
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
			name = "TFin_GroundRing2",
			decal = true,
			texture = "kk_circle_03",
			lifetime = {0.45, 0.45},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			size = {
				{0, 19.8, 0},
				{0.25, 55, 0},
				{1, 99, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.5, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 200},
				},
				{
					0.4,
					{255, 200, 100},
				},
				{
					1,
					{255, 140, 50},
				},
			},
			light_emission = 0.3,
			final_emit = {
				{0.06, 1, 0, 0, 0.25},
			},
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
			name = "TFin_GroundStreaks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Front",
			spread = {180, 2},
			speed = {149.6, 211.2},
			drag = 7,
			lifetime = {0.18, 0.26},
			size = {
				{0, 15.84, 2.64},
				{1, 22, 2.64},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 225},
				},
				{
					1,
					{255, 200, 110},
				},
			},
			light_emission = 0.8,
			brightness = 1.3,
			final_emit = {
				{0, 18, 0, 0, 1.5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFin_DustWave",
			texture = "kk_smoke_07",
			direction = "Front",
			spread = {180, 3},
			speed = {88, 132},
			drag = 3.6,
			accel = {0, 4.4, 0},
			lifetime = {1, 1.35},
			size = {
				{0, 7.04, 1.76},
				{0.3, 17.6, 3.08},
				{1, 25.08, 3.96},
			},
			transparency = {
				{0, 0.45, 0},
				{0.15, 0.18, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{222, 200, 172},
				},
				{
					0.5,
					{200, 186, 170},
				},
				{
					1,
					{186, 178, 170},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -2.2,
			final_emit = {
				{0.02, 34, 0, 0, 2.5},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFin_FireDome",
			texture = "kk_fire_01",
			shape = {
				type = "Sphere",
				radius = 3.52,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {70, 70},
			speed = {15.4, 30.8},
			drag = 4,
			accel = {0, 11, 0},
			lifetime = {0.55, 0.75},
			size = {
				{0, 6.16, 1.76},
				{0.15, 14.08, 2.64},
				{0.6, 16.72, 2.64},
				{1, 17.6, 2.64},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 232, 160},
				},
				{
					0.1,
					{255, 196, 90},
				},
				{
					0.3,
					{255, 150, 46},
				},
				{
					0.6,
					{236, 96, 28},
				},
				{
					1,
					{150, 50, 20},
				},
			},
			light_emission = 0.2,
			brightness = 1.35,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			final_emit = {
				{0, 8, 0, 0, 4.4},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFin_FireDome2",
			texture = "kk_fire_02",
			shape = {
				type = "Sphere",
				radius = 3.52,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {70, 70},
			speed = {13.2, 26.4},
			drag = 4,
			accel = {0, 11, 0},
			lifetime = {0.5, 0.7},
			size = {
				{0, 5.72, 1.76},
				{0.15, 13.2, 2.2},
				{0.6, 15.84, 2.2},
				{1, 16.72, 2.2},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 232, 160},
				},
				{
					0.1,
					{255, 196, 90},
				},
				{
					0.3,
					{255, 150, 46},
				},
				{
					0.6,
					{236, 96, 28},
				},
				{
					1,
					{150, 50, 20},
				},
			},
			light_emission = 0.2,
			brightness = 1.35,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			final_emit = {
				{0.03, 5, 0, 0, 4.4},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFin_Sparks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {75, 75},
			speed = {96.8, 176},
			drag = 4,
			accel = {0, -39.6, 0},
			lifetime = {0.3, 0.55},
			size = {
				{0, 14.96, 3.52},
				{1, 5.28, 0},
			},
			color = {
				{
					0,
					{255, 238, 150},
				},
				{
					0.5,
					{255, 184, 60},
				},
				{
					1,
					{255, 110, 24},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			final_emit = {
				{0, 36, 0, 0, 6.16},
			},
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
			name = "TFin_Rocks",
			type = "meteor",
			direction = "Top",
			spread = {60, 60},
			speed = {55, 88},
			accel = {0, -92.4, 0},
			drag = 0.2,
			lifetime = {1.4, 1.8},
			trails = {
				{
					name = "TFin_RockSmoke",
					rate = 40,
					texture = "kk_smoke_04",
					speed = {1, 4},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					accel = {0, 6, 0},
					lifetime = {0.5, 0.8},
					size = {
						{0, 2.42, 0.8},
						{1, 7.04, 2},
					},
					transparency = {
						{0, 0.3, 0},
						{0.6, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 170, 80},
						},
						{
							0.2,
							{100, 88, 82},
						},
						{
							1,
							{140, 134, 130},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
				{
					name = "TFin_RockFire",
					rate = 55,
					texture = "kk_fire_01",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					lifetime = {0.16, 0.26},
					size = {
						{0, 4.4, 1.2},
						{1, 1.188, 0},
					},
					color = {
						{
							0,
							{255, 246, 210},
						},
						{
							0.3,
							{255, 170, 60},
						},
						{
							1,
							{200, 60, 22},
						},
					},
					light_emission = 0.5,
					brightness = 1.6,
					rotation = {0, 360},
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
			land = {
				{
					name = "TFin_RockDust",
					emit = {
						{0, 4},
					},
					texture = "kk_smoke_04",
					direction = "Top",
					spread = {75, 75},
					speed = {8, 18},
					drag = 3,
					accel = {0, 4, 0},
					lifetime = {0.6, 0.9},
					size = {
						{0, 3, 1},
						{0.4, 8, 1.5},
						{1, 10, 1.5},
					},
					transparency = {
						{0, 0.35, 0},
						{0.6, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{222, 200, 172},
						},
						{
							0.5,
							{200, 186, 170},
						},
						{
							1,
							{186, 178, 170},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
				{
					name = "TFin_RockBurn",
					texture = "kk_muzzle_05",
					orientation = "VelocityParallel",
					direction = "Top",
					spread = {10, 10},
					speed = {4, 9},
					drag = 2,
					lifetime = {0.35, 0.55},
					size = {
						{0, 1.5, 0.5},
						{0.3, 5, 1},
						{1, 3, 0.8},
					},
					transparency = {
						{0, 0, 0},
						{0.6, 0.12, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 236, 150},
						},
						{
							0.3,
							{255, 176, 60},
						},
						{
							0.7,
							{245, 108, 30},
						},
						{
							1,
							{180, 50, 18},
						},
					},
					light_emission = 0.35,
					brightness = 1.5,
					stream = {
						{0, 1, 12, 0},
					},
					accel = {0, 0, 0},
					rotation = {0, 0},
					rot_speed = {0, 0},
					zoffset = 0,
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
			},
			final_emit = {
				{0.02, 6, 0, 0, 3.08},
			},
			offset = {0, 0, 0},
			emit = {},
			rock = {
				size = {1.892, 2.86},
				spin = {-500, 500},
				material = "Slate",
				color = {60, 50, 48},
			},
		},
		{
			name = "TFP_Outer",
			texture = "kk_muzzle_04",
			orientation = "FacingCameraWorldUp",
			final_emit = {
				{0, 1, 0, -1, 35.49},
				{0.02, 1, 0, 1, 35.49},
			},
			accel = {0, -35.395, 0},
			lifetime = {0.9, 1},
			size = {
				{0, 55.014, 0},
				{0.08, 88.732, 0},
				{0.55, 91.394, 0},
				{1, 55.014, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.6, 0.04, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 160, 58},
				},
				{
					0.15,
					{255, 128, 40},
				},
				{
					0.5,
					{242, 94, 28},
				},
				{
					0.8,
					{206, 60, 20},
				},
				{
					1,
					{150, 34, 14},
				},
			},
			light_emission = 0.08,
			brightness = 1.1,
			rotation = {-3, 3},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFP_Body",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			final_emit = {
				{0.015, 1, 0, -1, 23.29},
				{0.035, 1, 0, 1, 23.29},
			},
			accel = {0, -25.313, 0},
			lifetime = {0.86, 0.96},
			size = {
				{0, 34.547, 0},
				{0.08, 55.72, 0},
				{0.55, 57.392, 0},
				{1, 34.547, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.55, 0.05, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					0.25,
					{255, 184, 66},
				},
				{
					0.65,
					{252, 140, 44},
				},
				{
					1,
					{226, 94, 30},
				},
			},
			light_emission = 0.2,
			brightness = 1.25,
			rotation = {-6, 6},
			zoffset = 0.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFP_Core",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			final_emit = {
				{0.02, 1, 0, -1, 12.77},
				{0.04, 1, 0, 1, 12.77},
			},
			accel = {0, -15.187, 0},
			lifetime = {0.82, 0.92},
			size = {
				{0, 18.945, 0},
				{0.08, 30.556, 0},
				{0.55, 31.473, 0},
				{1, 18.945, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.06, 0.05, 0},
				{0.5, 0.1, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 220},
				},
				{
					0.4,
					{255, 230, 160},
				},
				{
					1,
					{255, 186, 96},
				},
			},
			light_emission = 0.45,
			brightness = 1.35,
			rotation = {-7, 7},
			zoffset = 1,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFP_Licks",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			final_emit = {
				{0.04, 2, 0, -1, 6.3},
				{0.16, 2, 0, -1, 6.3},
				{0.28, 2, 0, -1, 6.3},
				{0.4, 2, 0, -1, 6.3},
				{0.06, 2, 0, 1, 6.3},
				{0.18, 2, 0, 1, 6.3},
				{0.3, 2, 0, 1, 6.3},
				{0.42, 2, 0, 1, 6.3},
			},
			direction = "Top",
			spread = {6, 6},
			speed = {75.6, 151.2},
			drag = 4,
			lifetime = {0.25, 0.4},
			size = {
				{0, 7.56, 0},
				{0.3, 18.9, 0},
				{1, 8.82, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 160, 58},
				},
				{
					0.15,
					{255, 128, 40},
				},
				{
					0.5,
					{242, 94, 28},
				},
				{
					0.8,
					{206, 60, 20},
				},
				{
					1,
					{150, 34, 14},
				},
			},
			light_emission = 0.15,
			brightness = 1.2,
			zoffset = 0.3,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFP_Foot",
			texture = "kk_fire_01",
			final_emit = {
				{0, 2, 0, -1, 3.78},
				{0.15, 2, 0, -1, 3.78},
				{0.3, 2, 0, -1, 3.78},
				{0.02, 2, 0, 1, 3.78},
				{0.17, 2, 0, 1, 3.78},
				{0.32, 2, 0, 1, 3.78},
			},
			shape = {
				type = "Box",
				size = {12.6, 0.5, 12.6},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {12.6, 50.4},
			drag = 3,
			accel = {0, 18.9, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 7.56, 1.89},
				{0.3, 16.38, 2.52},
				{1, 12.6, 1.89},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					0.25,
					{255, 184, 66},
				},
				{
					0.65,
					{252, 140, 44},
				},
				{
					1,
					{226, 94, 30},
				},
			},
			light_emission = 0.25,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 1.5,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFP_Pop",
			texture = "fx_burst_fan",
			orientation = "FacingCameraWorldUp",
			final_emit = {
				{0, 1, 0, -1, 12.6},
				{0.02, 1, 0, 1, 12.6},
			},
			lifetime = {0.16, 0.2},
			size = {
				{0, 12.6, 0},
				{0.3, 34.65, 0},
				{1, 39.06, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 200},
				},
				{
					0.4,
					{255, 200, 100},
				},
				{
					1,
					{255, 140, 50},
				},
			},
			light_emission = 0.25,
			brightness = 1.15,
			zoffset = 2,
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
			name = "TFP_Streak",
			texture = "fx_line",
			orientation = "VelocityParallel",
			final_emit = {
				{0, 1, 0, -1, 3.15},
				{0.02, 1, 0, 1, 3.15},
			},
			direction = "Top",
			spread = {2, 2},
			speed = {252, 315},
			drag = 8,
			lifetime = {0.2, 0.26},
			size = {
				{0, 37.8, 6.3},
				{1, 50.4, 6.3},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 225},
				},
				{
					1,
					{255, 200, 110},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TFP_Embers",
			texture = "kk_flare_01",
			final_emit = {
				{0.1, 2, 0, -1, 31.5},
				{0.35, 2, 0, -1, 31.5},
				{0.12, 2, 0, 1, 31.5},
				{0.37, 2, 0, 1, 31.5},
			},
			shape = {
				type = "Box",
				size = {9.45, 44.1, 9.45},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {40, 40},
			speed = {6.3, 31.5},
			drag = 1.6,
			accel = {0, 15.75, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 2.52, 0.756},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
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
			name = "TF_Cap",
			texture = "kk_fire_02",
			final_emit = {
				{0.1, 6, 0, 0, 53.55},
				{0.3, 4, 0, 0, 51.66},
			},
			shape = {
				type = "Sphere",
				radius = 3.78,
				style = "Surface",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {5.04, 15.75},
			drag = 3,
			accel = {0, 11.34, 0},
			lifetime = {0.55, 0.75},
			size = {
				{0, 8.82, 0},
				{0.3, 18.9, 0},
				{1, 23.94, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 232, 160},
				},
				{
					0.1,
					{255, 196, 90},
				},
				{
					0.3,
					{255, 150, 46},
				},
				{
					0.6,
					{236, 96, 28},
				},
				{
					1,
					{150, 50, 20},
				},
			},
			light_emission = 0.2,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TF_Column",
			texture = "kk_smoke_07",
			final_emit = {
				{0.35, 3, 0, 0, 56.7},
				{0.6, 3, 0, 0, 53.55},
				{0.85, 2, 0, 0, 50.4},
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6.3, 15.75},
			drag = 1.2,
			accel = {0, 8.82, 0},
			lifetime = {1.4, 1.9},
			size = {
				{0, 11.34, 2.52},
				{0.4, 25.2, 3.78},
				{1, 34.65, 5.04},
			},
			transparency = {
				{0, 0.7, 0},
				{0.12, 0.4, 0},
				{0.55, 0.55, 0},
				{0.85, 0.85, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{150, 96, 64},
				},
				{
					0.15,
					{92, 80, 74},
				},
				{
					0.6,
					{120, 114, 110},
				},
				{
					1,
					{150, 146, 142},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -12.6,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TA_GroundGlow",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {1.1, 1.1},
			size = {
				{0, 8.8, 0},
				{0.1, 33, 0},
				{0.7, 30.8, 0},
				{1, 26.4, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{0.1, 0.25, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 170, 70},
				},
				{
					1,
					{230, 90, 30},
				},
			},
			light_emission = 0.8,
			zoffset = -0.5,
			rock_emit = {
				{
					{0.02, 1, 0, 0, 0.25},
				},
			},
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
			name = "TA_Scorch",
			decal = true,
			texture = "kz_scorch",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {2.4, 2.4},
			size = {
				{0, 6.6, 0},
				{0.04, 23.1, 0},
				{1, 24.2, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			zoffset = -1,
			rock_emit = {
				{
					{0.03, 1, 0, 0, 0.15},
				},
			},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 255, 255},
				},
			},
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TA_Embers",
			texture = "kk_flare_01",
			direction = "Top",
			spread = {60, 60},
			speed = {8.8, 26.4},
			drag = 1.6,
			accel = {0, 13.2, 0},
			lifetime = {0.8, 1.2},
			size = {
				{0, 0, 0},
				{0.1, 2.64, 0.88},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 220, 120},
				},
				{
					1,
					{255, 110, 30},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rock_emit = {
				{
					{0.15, 5, 0, 0, 13.2},
				},
			},
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
			name = "TLick_Licks",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {5.5, 0.2, 5.5},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {6.6, 12},
			drag = 2,
			lifetime = {0.35, 0.55},
			offset = {0, 0.6, 0},
			size = {
				{0, 3.3, 1.1},
				{0.3, 8.8, 2.2},
				{1, 5.5, 1.6},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 176, 60},
				},
				{
					0.7,
					{245, 108, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0, 1.1, 10, 0},
			},
			rock_stream = {
				{
					{0.5, 0, -0.88, 0},
				},
				{},
				{
					{0.5, 0, 0.75, 0},
				},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
	},
	shakes = {
		{0, 1, 0.8},
	},
	rocks = {
		gap = 14,
		gap_min = 6,
		gap_max = 34,
		jitter = 0.03,
	},
	light = {
		color = {255, 150, 60},
		brightness = 6,
		range = 60,
		time = 1.1,
	},
}

-- H3: las rocas del rayo detonan a la vez y levantan una pared de llamas. KaijuFireVFX.<nombre>(rocas, escala, sacudida): rocas = lista de Vector3 (suelo) o de las Parts.
-- rocks = las rocas del rayo: lista de Vector3 (punto del suelo) o de las Parts/Models de las rocas.
-- Todas detonan en el instante de la llamada; el pilar gigante sale en la roca más lejana.
function KaijuFireVFX.H3_Detonation(rocks: { any }, scale: number?, shake: number?): Part?
	return playRocks(SPEC_H3_Detonation, rocks, scale, shake)
end

local SPEC_H3_DetonationIgnition = {
	name = "H3_DetonationIgnition",
	duration = 4.6,
	cleanup = 5.58,
	layers = {
		{
			name = "JD_FlashBurst",
			texture = "fx_burst_a",
			lifetime = {0.1, 0.13},
			size = {
				{0, 6, 0},
				{0.3, 22.8, 0},
				{1, 25.2, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 160},
				},
				{
					1,
					{240, 50, 66},
				},
			},
			light_emission = 0.35,
			brightness = 1,
			rotation = {0, 360},
			zoffset = 4.8,
			rock_emit = {
				{
					{0, 2, 0, 0, 3.36},
				},
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
			name = "JD_GroundRing",
			decal = true,
			texture = "fx_shock_spiky",
			lifetime = {0.4, 0.4},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			size = {
				{0, 9.6, 0},
				{0.25, 22.8, 0},
				{1, 31.2, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 90, 104},
				},
				{
					1,
					{220, 30, 50},
				},
			},
			light_emission = 0.35,
			rotation = {0, 360},
			rock_emit = {
				{
					{0, 1, 0, 0, 0.3},
				},
			},
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
			name = "JD_DustWave",
			texture = "kk_smoke_07",
			direction = "Front",
			spread = {180, 3},
			speed = {48, 72},
			drag = 3.6,
			accel = {0, 2.4, 0},
			lifetime = {1, 1.35},
			size = {
				{0, 3.84, 0.96},
				{0.3, 9.6, 1.68},
				{1, 13.68, 2.16},
			},
			transparency = {
				{0, 0.45, 0},
				{0.15, 0.18, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 176, 160},
				},
				{
					0.5,
					{180, 164, 156},
				},
				{
					1,
					{170, 162, 158},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -1.2,
			rock_emit = {
				{
					{0.02, 12, 0, 0, 2.5},
				},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JD_FireDome",
			texture = "kk_fire_01",
			shape = {
				type = "Sphere",
				radius = 1.92,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {70, 70},
			speed = {8.4, 16.8},
			drag = 4,
			accel = {0, 6, 0},
			lifetime = {0.55, 0.75},
			size = {
				{0, 3.36, 0.96},
				{0.15, 7.68, 1.44},
				{0.6, 9.12, 1.44},
				{1, 9.6, 1.44},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 200, 204},
				},
				{
					0.1,
					{255, 110, 120},
				},
				{
					0.3,
					{240, 50, 66},
				},
				{
					0.6,
					{200, 22, 42},
				},
				{
					1,
					{100, 10, 22},
				},
			},
			light_emission = 0.2,
			brightness = 1.35,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			rock_emit = {
				{
					{0, 5, 0, 0, 2.4},
				},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JD_FireDome2",
			texture = "kk_fire_02",
			shape = {
				type = "Sphere",
				radius = 1.92,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {70, 70},
			speed = {7.2, 14.4},
			drag = 4,
			accel = {0, 6, 0},
			lifetime = {0.5, 0.7},
			size = {
				{0, 3.12, 0.96},
				{0.15, 7.2, 1.2},
				{0.6, 8.64, 1.2},
				{1, 9.12, 1.2},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 200, 204},
				},
				{
					0.1,
					{255, 110, 120},
				},
				{
					0.3,
					{240, 50, 66},
				},
				{
					0.6,
					{200, 22, 42},
				},
				{
					1,
					{100, 10, 22},
				},
			},
			light_emission = 0.2,
			brightness = 1.35,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			rock_emit = {
				{
					{0.03, 3, 0, 0, 2.4},
				},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JD_Sparks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {75, 75},
			speed = {52.8, 96},
			drag = 4,
			accel = {0, -21.6, 0},
			lifetime = {0.3, 0.55},
			size = {
				{0, 8.16, 1.92},
				{1, 2.88, 0},
			},
			color = {
				{
					0,
					{255, 232, 232},
				},
				{
					0.5,
					{255, 110, 120},
				},
				{
					1,
					{230, 36, 50},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			rock_emit = {
				{
					{0, 14, 0, 0, 3.36},
				},
			},
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
			name = "JD_Rocks",
			type = "meteor",
			direction = "Top",
			spread = {60, 60},
			speed = {30, 48},
			accel = {0, -50.4, 0},
			drag = 0.2,
			lifetime = {1.4, 1.8},
			trails = {
				{
					name = "JD_RockSmoke",
					rate = 40,
					texture = "kk_smoke_04",
					speed = {1, 4},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					accel = {0, 6, 0},
					lifetime = {0.5, 0.8},
					size = {
						{0, 1.32, 0.8},
						{1, 3.84, 2},
					},
					transparency = {
						{0, 0.3, 0},
						{0.6, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{210, 44, 56},
						},
						{
							0.2,
							{78, 58, 62},
						},
						{
							1,
							{118, 110, 114},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
				{
					name = "JD_RockFire",
					rate = 55,
					texture = "kk_fire_01",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					lifetime = {0.16, 0.26},
					size = {
						{0, 2.4, 1.2},
						{1, 0.648, 0},
					},
					color = {
						{
							0,
							{255, 236, 236},
						},
						{
							0.3,
							{255, 92, 104},
						},
						{
							1,
							{190, 24, 40},
						},
					},
					light_emission = 0.5,
					brightness = 1.6,
					rotation = {0, 360},
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
			land = {
				{
					name = "JD_RockDust",
					emit = {
						{0, 4},
					},
					texture = "kk_smoke_04",
					direction = "Top",
					spread = {75, 75},
					speed = {8, 18},
					drag = 3,
					accel = {0, 4, 0},
					lifetime = {0.6, 0.9},
					size = {
						{0, 3, 1},
						{0.4, 8, 1.5},
						{1, 10, 1.5},
					},
					transparency = {
						{0, 0.35, 0},
						{0.6, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{200, 176, 160},
						},
						{
							0.5,
							{180, 164, 156},
						},
						{
							1,
							{170, 162, 158},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
				{
					name = "JD_RockBurn",
					texture = "kk_muzzle_05",
					orientation = "VelocityParallel",
					direction = "Top",
					spread = {10, 10},
					speed = {4, 9},
					drag = 2,
					lifetime = {0.35, 0.55},
					size = {
						{0, 1.5, 0.5},
						{0.3, 5, 1},
						{1, 3, 0.8},
					},
					transparency = {
						{0, 0, 0},
						{0.6, 0.12, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 220, 220},
						},
						{
							0.3,
							{255, 90, 96},
						},
						{
							0.7,
							{224, 30, 46},
						},
						{
							1,
							{150, 14, 24},
						},
					},
					light_emission = 0.35,
					brightness = 1.5,
					stream = {
						{0, 1.4, 12, 0},
					},
					accel = {0, 0, 0},
					rotation = {0, 0},
					rot_speed = {0, 0},
					zoffset = 0,
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
			},
			rock_emit = {
				{
					{0.02, 2, 0, 0, 1.68},
				},
			},
			offset = {0, 0, 0},
			emit = {},
			rock = {
				size = {1.032, 1.56},
				spin = {-500, 500},
				material = "Slate",
				color = {60, 50, 48},
			},
		},
		{
			name = "JWS140_Outer",
			texture = "kk_muzzle_04",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.011, 1, 0.1468, 0.39, 26.82},
				},
				{
					{0.008, 1, -0.1027, -1.14, 26.82},
				},
				{},
			},
			final_emit = {
				{0.02, 1, 0, -2.4, 26.82},
				{0.03, 1, 0, 2.2, 26.82},
			},
			accel = {0, -37.711, 0},
			lifetime = {0.75, 0.85},
			size = {
				{0, 41.566, 0},
				{0.08, 67.042, 0},
				{0.55, 69.054, 0},
				{1, 41.566, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.6, 0.04, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 80, 84},
				},
				{
					0.15,
					{235, 36, 50},
				},
				{
					0.5,
					{200, 20, 38},
				},
				{
					0.8,
					{150, 10, 26},
				},
				{
					1,
					{90, 6, 16},
				},
			},
			light_emission = 0.08,
			brightness = 1.1,
			rotation = {-3, 3},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS140_Body",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.026, 1, 0.1468, 0.39, 17.6},
				},
				{
					{0.023, 1, -0.1027, -1.14, 17.6},
				},
				{},
			},
			final_emit = {
				{0.035, 1, 0, -2.4, 17.6},
				{0.045, 1, 0, 2.2, 17.6},
			},
			accel = {0, -27.42, 0},
			lifetime = {0.71, 0.81},
			size = {
				{0, 26.102, 0},
				{0.08, 42.1, 0},
				{0.55, 43.363, 0},
				{1, 26.102, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.55, 0.05, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 150},
				},
				{
					0.25,
					{255, 86, 92},
				},
				{
					0.65,
					{240, 44, 58},
				},
				{
					1,
					{190, 22, 38},
				},
			},
			light_emission = 0.2,
			brightness = 1.25,
			rotation = {-6, 6},
			zoffset = 0.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS140_Core",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.031, 1, 0.1468, 0.39, 9.65},
				},
				{
					{0.028, 1, -0.1027, -1.14, 9.65},
				},
				{},
			},
			final_emit = {
				{0.04, 1, 0, -2.4, 9.65},
				{0.05, 1, 0, 2.2, 9.65},
			},
			accel = {0, -16.754, 0},
			lifetime = {0.67, 0.77},
			size = {
				{0, 14.314, 0},
				{0.08, 23.087, 0},
				{0.55, 23.78, 0},
				{1, 14.314, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.06, 0.05, 0},
				{0.5, 0.1, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 244, 240},
				},
				{
					0.4,
					{255, 200, 196},
				},
				{
					1,
					{255, 126, 128},
				},
			},
			light_emission = 0.45,
			brightness = 1.35,
			rotation = {-7, 7},
			zoffset = 1,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS140_Licks",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.051, 2, 0.1468, 0.39, 4.76},
					{0.171, 2, 0.1468, 0.39, 4.76},
					{0.291, 2, 0.1468, 0.39, 4.76},
					{0.411, 2, 0.1468, 0.39, 4.76},
				},
				{
					{0.048, 2, -0.1027, -1.14, 4.76},
					{0.168, 2, -0.1027, -1.14, 4.76},
					{0.288, 2, -0.1027, -1.14, 4.76},
					{0.408, 2, -0.1027, -1.14, 4.76},
				},
				{},
			},
			final_emit = {
				{0.06, 2, 0, -2.4, 4.76},
				{0.18, 2, 0, -2.4, 4.76},
				{0.3, 2, 0, -2.4, 4.76},
				{0.42, 2, 0, -2.4, 4.76},
				{0.07, 2, 0, 2.2, 4.76},
				{0.19, 2, 0, 2.2, 4.76},
				{0.31, 2, 0, 2.2, 4.76},
				{0.43, 2, 0, 2.2, 4.76},
			},
			direction = "Top",
			spread = {6, 6},
			speed = {57.12, 114.24},
			drag = 4,
			lifetime = {0.25, 0.4},
			size = {
				{0, 5.712, 0},
				{0.3, 14.28, 0},
				{1, 6.664, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 80, 84},
				},
				{
					0.15,
					{235, 36, 50},
				},
				{
					0.5,
					{200, 20, 38},
				},
				{
					0.8,
					{150, 10, 26},
				},
				{
					1,
					{90, 6, 16},
				},
			},
			light_emission = 0.15,
			brightness = 1.2,
			zoffset = 0.3,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS140_Foot",
			texture = "kk_fire_01",
			rock_emit = {
				{
					{0.011, 2, 0.1468, 0.39, 2.86},
					{0.161, 2, 0.1468, 0.39, 2.86},
					{0.311, 2, 0.1468, 0.39, 2.86},
				},
				{
					{0.008, 2, -0.1027, -1.14, 2.86},
					{0.158, 2, -0.1027, -1.14, 2.86},
					{0.308, 2, -0.1027, -1.14, 2.86},
				},
				{},
			},
			final_emit = {
				{0.02, 2, 0, -2.4, 2.86},
				{0.17, 2, 0, -2.4, 2.86},
				{0.32, 2, 0, -2.4, 2.86},
				{0.03, 2, 0, 2.2, 2.86},
				{0.18, 2, 0, 2.2, 2.86},
				{0.33, 2, 0, 2.2, 2.86},
			},
			shape = {
				type = "Box",
				size = {9.52, 0.5, 9.52},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {9.52, 38.08},
			drag = 3,
			accel = {0, 14.28, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 5.712, 1.428},
				{0.3, 12.376, 1.904},
				{1, 9.52, 1.428},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 150},
				},
				{
					0.25,
					{255, 86, 92},
				},
				{
					0.65,
					{240, 44, 58},
				},
				{
					1,
					{190, 22, 38},
				},
			},
			light_emission = 0.25,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 1.5,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS140_Pop",
			texture = "fx_burst_fan",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.011, 1, 0.1468, 0.39, 9.52},
				},
				{
					{0.008, 1, -0.1027, -1.14, 9.52},
				},
				{},
			},
			final_emit = {
				{0.02, 1, 0, -2.4, 9.52},
				{0.03, 1, 0, 2.2, 9.52},
			},
			lifetime = {0.16, 0.2},
			size = {
				{0, 9.52, 0},
				{0.3, 26.18, 0},
				{1, 29.512, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 238, 238},
				},
				{
					0.4,
					{255, 140, 146},
				},
				{
					1,
					{255, 60, 74},
				},
			},
			light_emission = 0.25,
			brightness = 1.15,
			zoffset = 2,
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
			name = "JWS140_Streak",
			texture = "fx_line",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.011, 1, 0.1468, 0.39, 2.38},
				},
				{
					{0.008, 1, -0.1027, -1.14, 2.38},
				},
				{},
			},
			final_emit = {
				{0.02, 1, 0, -2.4, 2.38},
				{0.03, 1, 0, 2.2, 2.38},
			},
			direction = "Top",
			spread = {2, 2},
			speed = {190.4, 238},
			drag = 8,
			lifetime = {0.2, 0.26},
			size = {
				{0, 28.56, 4.76},
				{1, 38.08, 4.76},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 246},
				},
				{
					1,
					{255, 130, 136},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS140_Embers",
			texture = "kk_flare_01",
			rock_emit = {
				{
					{0.111, 2, 0.1468, 0.39, 23.8},
					{0.361, 2, 0.1468, 0.39, 23.8},
				},
				{
					{0.108, 2, -0.1027, -1.14, 23.8},
					{0.358, 2, -0.1027, -1.14, 23.8},
				},
				{},
			},
			final_emit = {
				{0.12, 2, 0, -2.4, 23.8},
				{0.37, 2, 0, -2.4, 23.8},
				{0.13, 2, 0, 2.2, 23.8},
				{0.38, 2, 0, 2.2, 23.8},
			},
			shape = {
				type = "Box",
				size = {7.14, 33.32, 7.14},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {40, 40},
			speed = {4.76, 23.8},
			drag = 1.6,
			accel = {0, 11.9, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.904, 0.571},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 200, 200},
				},
				{
					1,
					{240, 40, 56},
				},
			},
			light_emission = 1,
			brightness = 1.6,
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
			name = "JWS100_Outer",
			texture = "kk_muzzle_04",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{},
				{
					{0.004, 1, 0.1597, -1.02, 19.15},
				},
				{
					{0.002, 1, -0.1463, 0.15, 19.15},
					{0.004, 1, 0.1098, 0.43, 19.15},
				},
			},
			final_emit = {
				{0.04, 1, 0, -4.6, 19.15},
				{0.05, 1, 0, 4.4, 19.15},
				{0.03, 1, -0.25, 0.8, 19.15},
			},
			accel = {0, -26.937, 0},
			lifetime = {0.75, 0.85},
			size = {
				{0, 29.69, 0},
				{0.08, 47.887, 0},
				{0.55, 49.324, 0},
				{1, 29.69, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.6, 0.04, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 80, 84},
				},
				{
					0.15,
					{235, 36, 50},
				},
				{
					0.5,
					{200, 20, 38},
				},
				{
					0.8,
					{150, 10, 26},
				},
				{
					1,
					{90, 6, 16},
				},
			},
			light_emission = 0.08,
			brightness = 1.1,
			rotation = {-3, 3},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS100_Body",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{},
				{
					{0.019, 1, 0.1597, -1.02, 12.57},
				},
				{
					{0.017, 1, -0.1463, 0.15, 12.57},
					{0.019, 1, 0.1098, 0.43, 12.57},
				},
			},
			final_emit = {
				{0.055, 1, 0, -4.6, 12.57},
				{0.065, 1, 0, 4.4, 12.57},
				{0.045, 1, -0.25, 0.8, 12.57},
			},
			accel = {0, -19.586, 0},
			lifetime = {0.71, 0.81},
			size = {
				{0, 18.644, 0},
				{0.08, 30.071, 0},
				{0.55, 30.973, 0},
				{1, 18.644, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.55, 0.05, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 150},
				},
				{
					0.25,
					{255, 86, 92},
				},
				{
					0.65,
					{240, 44, 58},
				},
				{
					1,
					{190, 22, 38},
				},
			},
			light_emission = 0.2,
			brightness = 1.25,
			rotation = {-6, 6},
			zoffset = 0.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS100_Core",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{},
				{
					{0.024, 1, 0.1597, -1.02, 6.89},
				},
				{
					{0.022, 1, -0.1463, 0.15, 6.89},
					{0.024, 1, 0.1098, 0.43, 6.89},
				},
			},
			final_emit = {
				{0.06, 1, 0, -4.6, 6.89},
				{0.07, 1, 0, 4.4, 6.89},
				{0.05, 1, -0.25, 0.8, 6.89},
			},
			accel = {0, -11.967, 0},
			lifetime = {0.67, 0.77},
			size = {
				{0, 10.224, 0},
				{0.08, 16.491, 0},
				{0.55, 16.985, 0},
				{1, 10.224, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.06, 0.05, 0},
				{0.5, 0.1, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 244, 240},
				},
				{
					0.4,
					{255, 200, 196},
				},
				{
					1,
					{255, 126, 128},
				},
			},
			light_emission = 0.45,
			brightness = 1.35,
			rotation = {-7, 7},
			zoffset = 1,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS100_Licks",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			rock_emit = {
				{},
				{
					{0.044, 2, 0.1597, -1.02, 3.4},
					{0.164, 2, 0.1597, -1.02, 3.4},
					{0.284, 2, 0.1597, -1.02, 3.4},
					{0.404, 2, 0.1597, -1.02, 3.4},
				},
				{
					{0.042, 2, -0.1463, 0.15, 3.4},
					{0.162, 2, -0.1463, 0.15, 3.4},
					{0.282, 2, -0.1463, 0.15, 3.4},
					{0.402, 2, -0.1463, 0.15, 3.4},
					{0.044, 2, 0.1098, 0.43, 3.4},
					{0.164, 2, 0.1098, 0.43, 3.4},
					{0.284, 2, 0.1098, 0.43, 3.4},
					{0.404, 2, 0.1098, 0.43, 3.4},
				},
			},
			final_emit = {
				{0.08, 2, 0, -4.6, 3.4},
				{0.2, 2, 0, -4.6, 3.4},
				{0.32, 2, 0, -4.6, 3.4},
				{0.44, 2, 0, -4.6, 3.4},
				{0.09, 2, 0, 4.4, 3.4},
				{0.21, 2, 0, 4.4, 3.4},
				{0.33, 2, 0, 4.4, 3.4},
				{0.45, 2, 0, 4.4, 3.4},
				{0.07, 2, -0.25, 0.8, 3.4},
				{0.19, 2, -0.25, 0.8, 3.4},
				{0.31, 2, -0.25, 0.8, 3.4},
				{0.43, 2, -0.25, 0.8, 3.4},
			},
			direction = "Top",
			spread = {6, 6},
			speed = {40.8, 81.6},
			drag = 4,
			lifetime = {0.25, 0.4},
			size = {
				{0, 4.08, 0},
				{0.3, 10.2, 0},
				{1, 4.76, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 80, 84},
				},
				{
					0.15,
					{235, 36, 50},
				},
				{
					0.5,
					{200, 20, 38},
				},
				{
					0.8,
					{150, 10, 26},
				},
				{
					1,
					{90, 6, 16},
				},
			},
			light_emission = 0.15,
			brightness = 1.2,
			zoffset = 0.3,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS100_Foot",
			texture = "kk_fire_01",
			rock_emit = {
				{},
				{
					{0.004, 2, 0.1597, -1.02, 2.04},
					{0.154, 2, 0.1597, -1.02, 2.04},
					{0.304, 2, 0.1597, -1.02, 2.04},
				},
				{
					{0.002, 2, -0.1463, 0.15, 2.04},
					{0.152, 2, -0.1463, 0.15, 2.04},
					{0.302, 2, -0.1463, 0.15, 2.04},
					{0.004, 2, 0.1098, 0.43, 2.04},
					{0.154, 2, 0.1098, 0.43, 2.04},
					{0.304, 2, 0.1098, 0.43, 2.04},
				},
			},
			final_emit = {
				{0.04, 2, 0, -4.6, 2.04},
				{0.19, 2, 0, -4.6, 2.04},
				{0.34, 2, 0, -4.6, 2.04},
				{0.05, 2, 0, 4.4, 2.04},
				{0.2, 2, 0, 4.4, 2.04},
				{0.35, 2, 0, 4.4, 2.04},
				{0.03, 2, -0.25, 0.8, 2.04},
				{0.18, 2, -0.25, 0.8, 2.04},
				{0.33, 2, -0.25, 0.8, 2.04},
			},
			shape = {
				type = "Box",
				size = {6.8, 0.5, 6.8},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {6.8, 27.2},
			drag = 3,
			accel = {0, 10.2, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 4.08, 1.02},
				{0.3, 8.84, 1.36},
				{1, 6.8, 1.02},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 150},
				},
				{
					0.25,
					{255, 86, 92},
				},
				{
					0.65,
					{240, 44, 58},
				},
				{
					1,
					{190, 22, 38},
				},
			},
			light_emission = 0.25,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 1.5,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS100_Pop",
			texture = "fx_burst_fan",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{},
				{
					{0.004, 1, 0.1597, -1.02, 6.8},
				},
				{
					{0.002, 1, -0.1463, 0.15, 6.8},
					{0.004, 1, 0.1098, 0.43, 6.8},
				},
			},
			final_emit = {
				{0.04, 1, 0, -4.6, 6.8},
				{0.05, 1, 0, 4.4, 6.8},
				{0.03, 1, -0.25, 0.8, 6.8},
			},
			lifetime = {0.16, 0.2},
			size = {
				{0, 6.8, 0},
				{0.3, 18.7, 0},
				{1, 21.08, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 238, 238},
				},
				{
					0.4,
					{255, 140, 146},
				},
				{
					1,
					{255, 60, 74},
				},
			},
			light_emission = 0.25,
			brightness = 1.15,
			zoffset = 2,
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
			name = "JWS100_Streak",
			texture = "fx_line",
			orientation = "VelocityParallel",
			rock_emit = {
				{},
				{
					{0.004, 1, 0.1597, -1.02, 1.7},
				},
				{
					{0.002, 1, -0.1463, 0.15, 1.7},
					{0.004, 1, 0.1098, 0.43, 1.7},
				},
			},
			final_emit = {
				{0.04, 1, 0, -4.6, 1.7},
				{0.05, 1, 0, 4.4, 1.7},
				{0.03, 1, -0.25, 0.8, 1.7},
			},
			direction = "Top",
			spread = {2, 2},
			speed = {136, 170},
			drag = 8,
			lifetime = {0.2, 0.26},
			size = {
				{0, 20.4, 3.4},
				{1, 27.2, 3.4},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 246},
				},
				{
					1,
					{255, 130, 136},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS100_Embers",
			texture = "kk_flare_01",
			rock_emit = {
				{},
				{
					{0.104, 2, 0.1597, -1.02, 17},
					{0.354, 2, 0.1597, -1.02, 17},
				},
				{
					{0.102, 2, -0.1463, 0.15, 17},
					{0.352, 2, -0.1463, 0.15, 17},
					{0.104, 2, 0.1098, 0.43, 17},
					{0.354, 2, 0.1098, 0.43, 17},
				},
			},
			final_emit = {
				{0.14, 2, 0, -4.6, 17},
				{0.39, 2, 0, -4.6, 17},
				{0.15, 2, 0, 4.4, 17},
				{0.4, 2, 0, 4.4, 17},
				{0.13, 2, -0.25, 0.8, 17},
				{0.38, 2, -0.25, 0.8, 17},
			},
			shape = {
				type = "Box",
				size = {5.1, 23.8, 5.1},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {40, 40},
			speed = {3.4, 17},
			drag = 1.6,
			accel = {0, 8.5, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.36, 0.408},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 200, 200},
				},
				{
					1,
					{240, 40, 56},
				},
			},
			light_emission = 1,
			brightness = 1.6,
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
			name = "JWS74_Outer",
			texture = "kk_muzzle_04",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.008, 1, -0.1561, 0.03, 14.2},
				},
				{
					{0.008, 1, 0.4125, 0.96, 14.2},
				},
				{
					{0.006, 1, -0.3854, -0.22, 14.2},
					{0.018, 1, 0.3953, -0.99, 14.2},
				},
			},
			accel = {0, -19.965, 0},
			lifetime = {0.75, 0.85},
			size = {
				{0, 22.006, 0},
				{0.08, 35.493, 0},
				{0.55, 36.558, 0},
				{1, 22.006, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.6, 0.04, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 80, 84},
				},
				{
					0.15,
					{235, 36, 50},
				},
				{
					0.5,
					{200, 20, 38},
				},
				{
					0.8,
					{150, 10, 26},
				},
				{
					1,
					{90, 6, 16},
				},
			},
			light_emission = 0.08,
			brightness = 1.1,
			rotation = {-3, 3},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS74_Body",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.023, 1, -0.1561, 0.03, 9.32},
				},
				{
					{0.023, 1, 0.4125, 0.96, 9.32},
				},
				{
					{0.021, 1, -0.3854, -0.22, 9.32},
					{0.033, 1, 0.3953, -0.99, 9.32},
				},
			},
			accel = {0, -14.517, 0},
			lifetime = {0.71, 0.81},
			size = {
				{0, 13.819, 0},
				{0.08, 22.288, 0},
				{0.55, 22.957, 0},
				{1, 13.819, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.55, 0.05, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 150},
				},
				{
					0.25,
					{255, 86, 92},
				},
				{
					0.65,
					{240, 44, 58},
				},
				{
					1,
					{190, 22, 38},
				},
			},
			light_emission = 0.2,
			brightness = 1.25,
			rotation = {-6, 6},
			zoffset = 0.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS74_Core",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.028, 1, -0.1561, 0.03, 5.11},
				},
				{
					{0.028, 1, 0.4125, 0.96, 5.11},
				},
				{
					{0.026, 1, -0.3854, -0.22, 5.11},
					{0.038, 1, 0.3953, -0.99, 5.11},
				},
			},
			accel = {0, -8.87, 0},
			lifetime = {0.67, 0.77},
			size = {
				{0, 7.578, 0},
				{0.08, 12.223, 0},
				{0.55, 12.589, 0},
				{1, 7.578, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.06, 0.05, 0},
				{0.5, 0.1, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 244, 240},
				},
				{
					0.4,
					{255, 200, 196},
				},
				{
					1,
					{255, 126, 128},
				},
			},
			light_emission = 0.45,
			brightness = 1.35,
			rotation = {-7, 7},
			zoffset = 1,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS74_Licks",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.048, 2, -0.1561, 0.03, 2.52},
					{0.168, 2, -0.1561, 0.03, 2.52},
					{0.288, 2, -0.1561, 0.03, 2.52},
					{0.408, 2, -0.1561, 0.03, 2.52},
				},
				{
					{0.048, 2, 0.4125, 0.96, 2.52},
					{0.168, 2, 0.4125, 0.96, 2.52},
					{0.288, 2, 0.4125, 0.96, 2.52},
					{0.408, 2, 0.4125, 0.96, 2.52},
				},
				{
					{0.046, 2, -0.3854, -0.22, 2.52},
					{0.166, 2, -0.3854, -0.22, 2.52},
					{0.286, 2, -0.3854, -0.22, 2.52},
					{0.406, 2, -0.3854, -0.22, 2.52},
					{0.058, 2, 0.3953, -0.99, 2.52},
					{0.178, 2, 0.3953, -0.99, 2.52},
					{0.298, 2, 0.3953, -0.99, 2.52},
					{0.418, 2, 0.3953, -0.99, 2.52},
				},
			},
			direction = "Top",
			spread = {6, 6},
			speed = {30.24, 60.48},
			drag = 4,
			lifetime = {0.25, 0.4},
			size = {
				{0, 3.024, 0},
				{0.3, 7.56, 0},
				{1, 3.528, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 80, 84},
				},
				{
					0.15,
					{235, 36, 50},
				},
				{
					0.5,
					{200, 20, 38},
				},
				{
					0.8,
					{150, 10, 26},
				},
				{
					1,
					{90, 6, 16},
				},
			},
			light_emission = 0.15,
			brightness = 1.2,
			zoffset = 0.3,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS74_Foot",
			texture = "kk_fire_01",
			rock_emit = {
				{
					{0.008, 2, -0.1561, 0.03, 1.51},
					{0.158, 2, -0.1561, 0.03, 1.51},
					{0.308, 2, -0.1561, 0.03, 1.51},
				},
				{
					{0.008, 2, 0.4125, 0.96, 1.51},
					{0.158, 2, 0.4125, 0.96, 1.51},
					{0.308, 2, 0.4125, 0.96, 1.51},
				},
				{
					{0.006, 2, -0.3854, -0.22, 1.51},
					{0.156, 2, -0.3854, -0.22, 1.51},
					{0.306, 2, -0.3854, -0.22, 1.51},
					{0.018, 2, 0.3953, -0.99, 1.51},
					{0.168, 2, 0.3953, -0.99, 1.51},
					{0.318, 2, 0.3953, -0.99, 1.51},
				},
			},
			shape = {
				type = "Box",
				size = {5.04, 0.5, 5.04},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {5.04, 20.16},
			drag = 3,
			accel = {0, 7.56, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 3.024, 0.756},
				{0.3, 6.552, 1.008},
				{1, 5.04, 0.756},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 150},
				},
				{
					0.25,
					{255, 86, 92},
				},
				{
					0.65,
					{240, 44, 58},
				},
				{
					1,
					{190, 22, 38},
				},
			},
			light_emission = 0.25,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 1.5,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS74_Pop",
			texture = "fx_burst_fan",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.008, 1, -0.1561, 0.03, 5.04},
				},
				{
					{0.008, 1, 0.4125, 0.96, 5.04},
				},
				{
					{0.006, 1, -0.3854, -0.22, 5.04},
					{0.018, 1, 0.3953, -0.99, 5.04},
				},
			},
			lifetime = {0.16, 0.2},
			size = {
				{0, 5.04, 0},
				{0.3, 13.86, 0},
				{1, 15.624, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 238, 238},
				},
				{
					0.4,
					{255, 140, 146},
				},
				{
					1,
					{255, 60, 74},
				},
			},
			light_emission = 0.25,
			brightness = 1.15,
			zoffset = 2,
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
			name = "JWS74_Streak",
			texture = "fx_line",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.008, 1, -0.1561, 0.03, 1.26},
				},
				{
					{0.008, 1, 0.4125, 0.96, 1.26},
				},
				{
					{0.006, 1, -0.3854, -0.22, 1.26},
					{0.018, 1, 0.3953, -0.99, 1.26},
				},
			},
			direction = "Top",
			spread = {2, 2},
			speed = {100.8, 126},
			drag = 8,
			lifetime = {0.2, 0.26},
			size = {
				{0, 15.12, 2.52},
				{1, 20.16, 2.52},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 246},
				},
				{
					1,
					{255, 130, 136},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS74_Embers",
			texture = "kk_flare_01",
			rock_emit = {
				{
					{0.108, 2, -0.1561, 0.03, 12.6},
					{0.358, 2, -0.1561, 0.03, 12.6},
				},
				{
					{0.108, 2, 0.4125, 0.96, 12.6},
					{0.358, 2, 0.4125, 0.96, 12.6},
				},
				{
					{0.106, 2, -0.3854, -0.22, 12.6},
					{0.356, 2, -0.3854, -0.22, 12.6},
					{0.118, 2, 0.3953, -0.99, 12.6},
					{0.368, 2, 0.3953, -0.99, 12.6},
				},
			},
			shape = {
				type = "Box",
				size = {3.78, 17.64, 3.78},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {40, 40},
			speed = {2.52, 12.6},
			drag = 1.6,
			accel = {0, 6.3, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.008, 0.302},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 200, 200},
				},
				{
					1,
					{240, 40, 56},
				},
			},
			light_emission = 1,
			brightness = 1.6,
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
			name = "JWS52_Outer",
			texture = "kk_muzzle_04",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.018, 1, -0.3683, -1, 9.97},
					{0.004, 1, 0.3832, -0.93, 9.97},
				},
				{
					{0.005, 1, -0.3771, -0.94, 9.97},
				},
				{},
			},
			accel = {0, -14.023, 0},
			lifetime = {0.75, 0.85},
			size = {
				{0, 15.456, 0},
				{0.08, 24.93, 0},
				{0.55, 25.677, 0},
				{1, 15.456, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.6, 0.04, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 80, 84},
				},
				{
					0.15,
					{235, 36, 50},
				},
				{
					0.5,
					{200, 20, 38},
				},
				{
					0.8,
					{150, 10, 26},
				},
				{
					1,
					{90, 6, 16},
				},
			},
			light_emission = 0.08,
			brightness = 1.1,
			rotation = {-3, 3},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS52_Body",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.033, 1, -0.3683, -1, 6.54},
					{0.019, 1, 0.3832, -0.93, 6.54},
				},
				{
					{0.02, 1, -0.3771, -0.94, 6.54},
				},
				{},
			},
			accel = {0, -10.196, 0},
			lifetime = {0.71, 0.81},
			size = {
				{0, 9.706, 0},
				{0.08, 15.655, 0},
				{0.55, 16.124, 0},
				{1, 9.706, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.55, 0.05, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 150},
				},
				{
					0.25,
					{255, 86, 92},
				},
				{
					0.65,
					{240, 44, 58},
				},
				{
					1,
					{190, 22, 38},
				},
			},
			light_emission = 0.2,
			brightness = 1.25,
			rotation = {-6, 6},
			zoffset = 0.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS52_Core",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.038, 1, -0.3683, -1, 3.59},
					{0.024, 1, 0.3832, -0.93, 3.59},
				},
				{
					{0.025, 1, -0.3771, -0.94, 3.59},
				},
				{},
			},
			accel = {0, -6.23, 0},
			lifetime = {0.67, 0.77},
			size = {
				{0, 5.323, 0},
				{0.08, 8.585, 0},
				{0.55, 8.842, 0},
				{1, 5.323, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.06, 0.05, 0},
				{0.5, 0.1, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 244, 240},
				},
				{
					0.4,
					{255, 200, 196},
				},
				{
					1,
					{255, 126, 128},
				},
			},
			light_emission = 0.45,
			brightness = 1.35,
			rotation = {-7, 7},
			zoffset = 1,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS52_Licks",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.058, 2, -0.3683, -1, 1.77},
					{0.178, 2, -0.3683, -1, 1.77},
					{0.298, 2, -0.3683, -1, 1.77},
					{0.418, 2, -0.3683, -1, 1.77},
					{0.044, 2, 0.3832, -0.93, 1.77},
					{0.164, 2, 0.3832, -0.93, 1.77},
					{0.284, 2, 0.3832, -0.93, 1.77},
					{0.404, 2, 0.3832, -0.93, 1.77},
				},
				{
					{0.045, 2, -0.3771, -0.94, 1.77},
					{0.165, 2, -0.3771, -0.94, 1.77},
					{0.285, 2, -0.3771, -0.94, 1.77},
					{0.405, 2, -0.3771, -0.94, 1.77},
				},
				{},
			},
			direction = "Top",
			spread = {6, 6},
			speed = {21.24, 42.48},
			drag = 4,
			lifetime = {0.25, 0.4},
			size = {
				{0, 2.124, 0},
				{0.3, 5.31, 0},
				{1, 2.478, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 80, 84},
				},
				{
					0.15,
					{235, 36, 50},
				},
				{
					0.5,
					{200, 20, 38},
				},
				{
					0.8,
					{150, 10, 26},
				},
				{
					1,
					{90, 6, 16},
				},
			},
			light_emission = 0.15,
			brightness = 1.2,
			zoffset = 0.3,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS52_Foot",
			texture = "kk_fire_01",
			rock_emit = {
				{
					{0.018, 2, -0.3683, -1, 1.06},
					{0.168, 2, -0.3683, -1, 1.06},
					{0.318, 2, -0.3683, -1, 1.06},
					{0.004, 2, 0.3832, -0.93, 1.06},
					{0.154, 2, 0.3832, -0.93, 1.06},
					{0.304, 2, 0.3832, -0.93, 1.06},
				},
				{
					{0.005, 2, -0.3771, -0.94, 1.06},
					{0.155, 2, -0.3771, -0.94, 1.06},
					{0.305, 2, -0.3771, -0.94, 1.06},
				},
				{},
			},
			shape = {
				type = "Box",
				size = {3.54, 0.5, 3.54},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {3.54, 14.16},
			drag = 3,
			accel = {0, 5.31, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 2.124, 0.531},
				{0.3, 4.602, 0.708},
				{1, 3.54, 0.531},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 150},
				},
				{
					0.25,
					{255, 86, 92},
				},
				{
					0.65,
					{240, 44, 58},
				},
				{
					1,
					{190, 22, 38},
				},
			},
			light_emission = 0.25,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 1.5,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS52_Pop",
			texture = "fx_burst_fan",
			orientation = "FacingCameraWorldUp",
			rock_emit = {
				{
					{0.018, 1, -0.3683, -1, 3.54},
					{0.004, 1, 0.3832, -0.93, 3.54},
				},
				{
					{0.005, 1, -0.3771, -0.94, 3.54},
				},
				{},
			},
			lifetime = {0.16, 0.2},
			size = {
				{0, 3.54, 0},
				{0.3, 9.735, 0},
				{1, 10.974, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 238, 238},
				},
				{
					0.4,
					{255, 140, 146},
				},
				{
					1,
					{255, 60, 74},
				},
			},
			light_emission = 0.25,
			brightness = 1.15,
			zoffset = 2,
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
			name = "JWS52_Streak",
			texture = "fx_line",
			orientation = "VelocityParallel",
			rock_emit = {
				{
					{0.018, 1, -0.3683, -1, 0.89},
					{0.004, 1, 0.3832, -0.93, 0.89},
				},
				{
					{0.005, 1, -0.3771, -0.94, 0.89},
				},
				{},
			},
			direction = "Top",
			spread = {2, 2},
			speed = {70.8, 88.5},
			drag = 8,
			lifetime = {0.2, 0.26},
			size = {
				{0, 10.62, 1.77},
				{1, 14.16, 1.77},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 246},
				},
				{
					1,
					{255, 130, 136},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JWS52_Embers",
			texture = "kk_flare_01",
			rock_emit = {
				{
					{0.118, 2, -0.3683, -1, 8.85},
					{0.368, 2, -0.3683, -1, 8.85},
					{0.104, 2, 0.3832, -0.93, 8.85},
					{0.354, 2, 0.3832, -0.93, 8.85},
				},
				{
					{0.105, 2, -0.3771, -0.94, 8.85},
					{0.355, 2, -0.3771, -0.94, 8.85},
				},
				{},
			},
			shape = {
				type = "Box",
				size = {2.655, 12.39, 2.655},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {40, 40},
			speed = {1.77, 8.85},
			drag = 1.6,
			accel = {0, 4.425, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 0.708, 0.212},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 200, 200},
				},
				{
					1,
					{240, 40, 56},
				},
			},
			light_emission = 1,
			brightness = 1.6,
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
			name = "JW_WallSmoke",
			texture = "kk_smoke_08",
			rock_emit = {
				{
					{0.23, 1, 0.3832, -2.31, 12.31},
					{0.25, 1, 0.1468, -0.85, 36.46},
					{0.272, 1, -0.1561, -0.39, 15.6},
					{0.274, 1, -0.3683, -1.23, 13.89},
					{0.446, 1, -0.3683, -1.92, 13.36},
					{0.458, 1, 0.3832, 0.03, 12.66},
					{0.474, 1, 0.1468, 0.66, 36.01},
					{0.475, 1, -0.1561, 0.3, 20.89},
					{0.646, 1, 0.3832, -1.56, 12.49},
					{0.651, 1, -0.3683, -1.13, 10.76},
					{0.665, 1, -0.1561, 1.44, 18.29},
					{0.67, 1, 0.1468, -0.56, 31.53},
				},
				{
					{0.252, 1, 0.1597, -1.93, 31.51},
					{0.255, 1, 0.4125, 0.49, 22.95},
					{0.272, 1, -0.3771, -0.32, 15.74},
					{0.277, 1, -0.1027, -0.58, 44.78},
					{0.439, 1, -0.3771, -0.8, 16.29},
					{0.476, 1, -0.1027, 0.21, 37.53},
					{0.477, 1, 0.4125, 2.15, 21.15},
					{0.481, 1, 0.1597, -1.87, 21.63},
					{0.653, 1, 0.4125, 1.54, 22.4},
					{0.656, 1, 0.1597, -2.01, 26.87},
					{0.661, 1, -0.3771, 0.4, 11.64},
					{0.687, 1, -0.1027, -0.39, 34.33},
				},
				{
					{0.234, 1, 0.1098, 0.28, 25.43},
					{0.255, 1, -0.1463, -0.64, 27.07},
					{0.272, 1, -0.3854, -0.05, 19.94},
					{0.291, 1, 0.3953, 0.1, 19.48},
					{0.429, 1, 0.1098, 1.03, 26.11},
					{0.45, 1, -0.1463, 0, 28.95},
					{0.476, 1, -0.3854, -1.39, 20.65},
					{0.485, 1, 0.3953, -0.47, 20.42},
					{0.622, 1, -0.1463, -0.22, 29.75},
					{0.646, 1, -0.3854, -0.04, 22.45},
					{0.655, 1, 0.3953, -1.53, 18.17},
					{0.665, 1, 0.1098, 0.55, 27.01},
				},
			},
			final_emit = {
				{0.258, 1, 0, -1.02, 34.25},
				{0.267, 1, 0, 0.97, 32.18},
				{0.268, 1, -0.25, -0.47, 31.29},
				{0.294, 1, 0, -4.77, 30.61},
				{0.318, 1, 0, 3.73, 24.71},
				{0.463, 1, 0, -2.64, 42.16},
				{0.466, 1, 0, 3.26, 36.93},
				{0.476, 1, 0, -3.55, 23.35},
				{0.479, 1, 0, 5.41, 21.48},
				{0.489, 1, -0.25, -0.19, 32.02},
				{0.657, 1, 0, 2.09, 30.57},
				{0.669, 1, 0, -2.24, 32.82},
				{0.705, 1, -0.25, -0.15, 20.63},
				{0.714, 1, 0, 4.09, 28.49},
				{0.719, 1, 0, -4.2, 20.91},
			},
			direction = "Top",
			spread = {25, 25},
			speed = {2.72, 11.9},
			drag = 1,
			accel = {0, 5.1, 0},
			lifetime = {1.3, 1.9},
			size = {
				{0, 5.44, 1.36},
				{0.35, 13.6, 2.72},
				{1, 20.4, 3.4},
			},
			transparency = {
				{0, 0.8, 0},
				{0.12, 0.45, 0},
				{0.5, 0.6, 0},
				{0.8, 0.85, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{140, 40, 50},
				},
				{
					0.15,
					{70, 52, 56},
				},
				{
					0.6,
					{96, 86, 90},
				},
				{
					1,
					{124, 118, 120},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -10.2,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFin_FlashBurst",
			texture = "fx_burst_a",
			lifetime = {0.1, 0.13},
			size = {
				{0, 11, 0},
				{0.3, 41.8, 0},
				{1, 46.2, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 160},
				},
				{
					1,
					{240, 50, 66},
				},
			},
			light_emission = 0.35,
			brightness = 1,
			rotation = {0, 360},
			zoffset = 8.8,
			final_emit = {
				{0, 2, 0, 0, 6.16},
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
			name = "JFin_FlashStar",
			texture = "fx_star",
			lifetime = {0.15, 0.15},
			size = {
				{0, 26.4, 0},
				{0.25, 79.2, 0},
				{1, 44, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.6, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 160},
				},
				{
					1,
					{240, 50, 66},
				},
			},
			light_emission = 0.5,
			brightness = 1,
			zoffset = 9.68,
			final_emit = {
				{0, 1, 0, 0, 6.16},
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
			name = "JFin_Glow",
			texture = "fx_glow",
			lifetime = {0.7, 0.7},
			size = {
				{0, 22, 0},
				{0.15, 66, 0},
				{1, 74.8, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{0.4, 0.75, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 70, 84},
				},
				{
					1,
					{190, 20, 40},
				},
			},
			light_emission = 0.3,
			zoffset = -8.8,
			final_emit = {
				{0, 1, 0, 0, 11},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFin_GroundRing",
			decal = true,
			texture = "fx_shock_spiky",
			lifetime = {0.4, 0.4},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			size = {
				{0, 17.6, 0},
				{0.25, 41.8, 0},
				{1, 57.2, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 90, 104},
				},
				{
					1,
					{220, 30, 50},
				},
			},
			light_emission = 0.35,
			rotation = {0, 360},
			final_emit = {
				{0, 1, 0, 0, 0.3},
			},
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
			name = "JFin_ShockRing",
			decal = true,
			texture = "kk_circle_03",
			lifetime = {0.55, 0.55},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			size = {
				{0, 22, 0},
				{0.2, 70.4, 0},
				{0.6, 110, 0},
				{1, 123.2, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 90, 104},
				},
				{
					1,
					{220, 30, 50},
				},
			},
			light_emission = 0.35,
			final_emit = {
				{0, 1, 0, 0, 0.35},
			},
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
			name = "JFin_GroundRing2",
			decal = true,
			texture = "kk_circle_03",
			lifetime = {0.45, 0.45},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			size = {
				{0, 19.8, 0},
				{0.25, 55, 0},
				{1, 99, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.5, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 238, 238},
				},
				{
					0.4,
					{255, 140, 146},
				},
				{
					1,
					{255, 60, 74},
				},
			},
			light_emission = 0.3,
			final_emit = {
				{0.06, 1, 0, 0, 0.25},
			},
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
			name = "JFin_GroundStreaks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Front",
			spread = {180, 2},
			speed = {149.6, 211.2},
			drag = 7,
			lifetime = {0.18, 0.26},
			size = {
				{0, 15.84, 2.64},
				{1, 22, 2.64},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 246},
				},
				{
					1,
					{255, 130, 136},
				},
			},
			light_emission = 0.8,
			brightness = 1.3,
			final_emit = {
				{0, 18, 0, 0, 1.5},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFin_DustWave",
			texture = "kk_smoke_07",
			direction = "Front",
			spread = {180, 3},
			speed = {88, 132},
			drag = 3.6,
			accel = {0, 4.4, 0},
			lifetime = {1, 1.35},
			size = {
				{0, 7.04, 1.76},
				{0.3, 17.6, 3.08},
				{1, 25.08, 3.96},
			},
			transparency = {
				{0, 0.45, 0},
				{0.15, 0.18, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 176, 160},
				},
				{
					0.5,
					{180, 164, 156},
				},
				{
					1,
					{170, 162, 158},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -2.2,
			final_emit = {
				{0.02, 34, 0, 0, 2.5},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFin_FireDome",
			texture = "kk_fire_01",
			shape = {
				type = "Sphere",
				radius = 3.52,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {70, 70},
			speed = {15.4, 30.8},
			drag = 4,
			accel = {0, 11, 0},
			lifetime = {0.55, 0.75},
			size = {
				{0, 6.16, 1.76},
				{0.15, 14.08, 2.64},
				{0.6, 16.72, 2.64},
				{1, 17.6, 2.64},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 200, 204},
				},
				{
					0.1,
					{255, 110, 120},
				},
				{
					0.3,
					{240, 50, 66},
				},
				{
					0.6,
					{200, 22, 42},
				},
				{
					1,
					{100, 10, 22},
				},
			},
			light_emission = 0.2,
			brightness = 1.35,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			final_emit = {
				{0, 8, 0, 0, 4.4},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFin_FireDome2",
			texture = "kk_fire_02",
			shape = {
				type = "Sphere",
				radius = 3.52,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {70, 70},
			speed = {13.2, 26.4},
			drag = 4,
			accel = {0, 11, 0},
			lifetime = {0.5, 0.7},
			size = {
				{0, 5.72, 1.76},
				{0.15, 13.2, 2.2},
				{0.6, 15.84, 2.2},
				{1, 16.72, 2.2},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.05, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 200, 204},
				},
				{
					0.1,
					{255, 110, 120},
				},
				{
					0.3,
					{240, 50, 66},
				},
				{
					0.6,
					{200, 22, 42},
				},
				{
					1,
					{100, 10, 22},
				},
			},
			light_emission = 0.2,
			brightness = 1.35,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			final_emit = {
				{0.03, 5, 0, 0, 4.4},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFin_Sparks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {75, 75},
			speed = {96.8, 176},
			drag = 4,
			accel = {0, -39.6, 0},
			lifetime = {0.3, 0.55},
			size = {
				{0, 14.96, 3.52},
				{1, 5.28, 0},
			},
			color = {
				{
					0,
					{255, 232, 232},
				},
				{
					0.5,
					{255, 110, 120},
				},
				{
					1,
					{230, 36, 50},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			final_emit = {
				{0, 36, 0, 0, 6.16},
			},
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
			name = "JFin_Rocks",
			type = "meteor",
			direction = "Top",
			spread = {60, 60},
			speed = {55, 88},
			accel = {0, -92.4, 0},
			drag = 0.2,
			lifetime = {1.4, 1.8},
			trails = {
				{
					name = "JFin_RockSmoke",
					rate = 40,
					texture = "kk_smoke_04",
					speed = {1, 4},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					accel = {0, 6, 0},
					lifetime = {0.5, 0.8},
					size = {
						{0, 2.42, 0.8},
						{1, 7.04, 2},
					},
					transparency = {
						{0, 0.3, 0},
						{0.6, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{210, 44, 56},
						},
						{
							0.2,
							{78, 58, 62},
						},
						{
							1,
							{118, 110, 114},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
				{
					name = "JFin_RockFire",
					rate = 55,
					texture = "kk_fire_01",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					lifetime = {0.16, 0.26},
					size = {
						{0, 4.4, 1.2},
						{1, 1.188, 0},
					},
					color = {
						{
							0,
							{255, 236, 236},
						},
						{
							0.3,
							{255, 92, 104},
						},
						{
							1,
							{190, 24, 40},
						},
					},
					light_emission = 0.5,
					brightness = 1.6,
					rotation = {0, 360},
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
			land = {
				{
					name = "JFin_RockDust",
					emit = {
						{0, 4},
					},
					texture = "kk_smoke_04",
					direction = "Top",
					spread = {75, 75},
					speed = {8, 18},
					drag = 3,
					accel = {0, 4, 0},
					lifetime = {0.6, 0.9},
					size = {
						{0, 3, 1},
						{0.4, 8, 1.5},
						{1, 10, 1.5},
					},
					transparency = {
						{0, 0.35, 0},
						{0.6, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{200, 176, 160},
						},
						{
							0.5,
							{180, 164, 156},
						},
						{
							1,
							{170, 162, 158},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
				{
					name = "JFin_RockBurn",
					texture = "kk_muzzle_05",
					orientation = "VelocityParallel",
					direction = "Top",
					spread = {10, 10},
					speed = {4, 9},
					drag = 2,
					lifetime = {0.35, 0.55},
					size = {
						{0, 1.5, 0.5},
						{0.3, 5, 1},
						{1, 3, 0.8},
					},
					transparency = {
						{0, 0, 0},
						{0.6, 0.12, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{255, 220, 220},
						},
						{
							0.3,
							{255, 90, 96},
						},
						{
							0.7,
							{224, 30, 46},
						},
						{
							1,
							{150, 14, 24},
						},
					},
					light_emission = 0.35,
					brightness = 1.5,
					stream = {
						{0, 2, 12, 0},
					},
					accel = {0, 0, 0},
					rotation = {0, 0},
					rot_speed = {0, 0},
					zoffset = 0,
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
			},
			final_emit = {
				{0.02, 6, 0, 0, 3.08},
			},
			offset = {0, 0, 0},
			emit = {},
			rock = {
				size = {1.892, 2.86},
				spin = {-500, 500},
				material = "Slate",
				color = {60, 50, 48},
			},
		},
		{
			name = "JFP_Outer",
			texture = "kk_muzzle_04",
			orientation = "FacingCameraWorldUp",
			final_emit = {
				{0, 1, 0, -1, 40.23},
				{0.02, 1, 0, 1, 40.23},
			},
			accel = {0, -40.114, 0},
			lifetime = {0.9, 1},
			size = {
				{0, 62.349, 0},
				{0.08, 100.563, 0},
				{0.55, 103.58, 0},
				{1, 62.349, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.6, 0.04, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 80, 84},
				},
				{
					0.15,
					{235, 36, 50},
				},
				{
					0.5,
					{200, 20, 38},
				},
				{
					0.8,
					{150, 10, 26},
				},
				{
					1,
					{90, 6, 16},
				},
			},
			light_emission = 0.08,
			brightness = 1.1,
			rotation = {-3, 3},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFP_Body",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			final_emit = {
				{0.015, 1, 0, -1, 26.4},
				{0.035, 1, 0, 1, 26.4},
			},
			accel = {0, -28.689, 0},
			lifetime = {0.86, 0.96},
			size = {
				{0, 39.153, 0},
				{0.08, 63.15, 0},
				{0.55, 65.044, 0},
				{1, 39.153, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.06, 0, 0},
				{0.55, 0.05, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 150},
				},
				{
					0.25,
					{255, 86, 92},
				},
				{
					0.65,
					{240, 44, 58},
				},
				{
					1,
					{190, 22, 38},
				},
			},
			light_emission = 0.2,
			brightness = 1.25,
			rotation = {-6, 6},
			zoffset = 0.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFP_Core",
			texture = "kk_muzzle_01",
			orientation = "FacingCameraWorldUp",
			final_emit = {
				{0.02, 1, 0, -1, 14.48},
				{0.04, 1, 0, 1, 14.48},
			},
			accel = {0, -17.212, 0},
			lifetime = {0.82, 0.92},
			size = {
				{0, 21.471, 0},
				{0.08, 34.631, 0},
				{0.55, 35.669, 0},
				{1, 21.471, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.06, 0.05, 0},
				{0.5, 0.1, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 244, 240},
				},
				{
					0.4,
					{255, 200, 196},
				},
				{
					1,
					{255, 126, 128},
				},
			},
			light_emission = 0.45,
			brightness = 1.35,
			rotation = {-7, 7},
			zoffset = 1,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			drag = 0,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFP_Licks",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			final_emit = {
				{0.04, 2, 0, -1, 7.14},
				{0.16, 2, 0, -1, 7.14},
				{0.28, 2, 0, -1, 7.14},
				{0.4, 2, 0, -1, 7.14},
				{0.06, 2, 0, 1, 7.14},
				{0.18, 2, 0, 1, 7.14},
				{0.3, 2, 0, 1, 7.14},
				{0.42, 2, 0, 1, 7.14},
			},
			direction = "Top",
			spread = {6, 6},
			speed = {85.68, 171.36},
			drag = 4,
			lifetime = {0.25, 0.4},
			size = {
				{0, 8.568, 0},
				{0.3, 21.42, 0},
				{1, 9.996, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 80, 84},
				},
				{
					0.15,
					{235, 36, 50},
				},
				{
					0.5,
					{200, 20, 38},
				},
				{
					0.8,
					{150, 10, 26},
				},
				{
					1,
					{90, 6, 16},
				},
			},
			light_emission = 0.15,
			brightness = 1.2,
			zoffset = 0.3,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFP_Foot",
			texture = "kk_fire_01",
			final_emit = {
				{0, 2, 0, -1, 4.28},
				{0.15, 2, 0, -1, 4.28},
				{0.3, 2, 0, -1, 4.28},
				{0.02, 2, 0, 1, 4.28},
				{0.17, 2, 0, 1, 4.28},
				{0.32, 2, 0, 1, 4.28},
			},
			shape = {
				type = "Box",
				size = {14.28, 0.5, 14.28},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {12, 12},
			speed = {14.28, 57.12},
			drag = 3,
			accel = {0, 21.42, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 8.568, 2.142},
				{0.3, 18.564, 2.856},
				{1, 14.28, 2.142},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 150, 150},
				},
				{
					0.25,
					{255, 86, 92},
				},
				{
					0.65,
					{240, 44, 58},
				},
				{
					1,
					{190, 22, 38},
				},
			},
			light_emission = 0.25,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 1.5,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFP_Pop",
			texture = "fx_burst_fan",
			orientation = "FacingCameraWorldUp",
			final_emit = {
				{0, 1, 0, -1, 14.28},
				{0.02, 1, 0, 1, 14.28},
			},
			lifetime = {0.16, 0.2},
			size = {
				{0, 14.28, 0},
				{0.3, 39.27, 0},
				{1, 44.268, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 238, 238},
				},
				{
					0.4,
					{255, 140, 146},
				},
				{
					1,
					{255, 60, 74},
				},
			},
			light_emission = 0.25,
			brightness = 1.15,
			zoffset = 2,
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
			name = "JFP_Streak",
			texture = "fx_line",
			orientation = "VelocityParallel",
			final_emit = {
				{0, 1, 0, -1, 3.57},
				{0.02, 1, 0, 1, 3.57},
			},
			direction = "Top",
			spread = {2, 2},
			speed = {285.6, 357},
			drag = 8,
			lifetime = {0.2, 0.26},
			size = {
				{0, 42.84, 7.14},
				{1, 57.12, 7.14},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 246},
				},
				{
					1,
					{255, 130, 136},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JFP_Embers",
			texture = "kk_flare_01",
			final_emit = {
				{0.1, 2, 0, -1, 35.7},
				{0.35, 2, 0, -1, 35.7},
				{0.12, 2, 0, 1, 35.7},
				{0.37, 2, 0, 1, 35.7},
			},
			shape = {
				type = "Box",
				size = {10.71, 49.98, 10.71},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {40, 40},
			speed = {7.14, 35.7},
			drag = 1.6,
			accel = {0, 17.85, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 2.856, 0.857},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 200, 200},
				},
				{
					1,
					{240, 40, 56},
				},
			},
			light_emission = 1,
			brightness = 1.6,
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
			name = "JF_Cap",
			texture = "kk_fire_02",
			final_emit = {
				{0.1, 6, 0, 0, 60.69},
				{0.3, 4, 0, 0, 58.55},
			},
			shape = {
				type = "Sphere",
				radius = 4.284,
				style = "Surface",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {5.712, 17.85},
			drag = 3,
			accel = {0, 12.852, 0},
			lifetime = {0.55, 0.75},
			size = {
				{0, 9.996, 0},
				{0.3, 21.42, 0},
				{1, 27.132, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.1, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 200, 204},
				},
				{
					0.1,
					{255, 110, 120},
				},
				{
					0.3,
					{240, 50, 66},
				},
				{
					0.6,
					{200, 22, 42},
				},
				{
					1,
					{100, 10, 22},
				},
			},
			light_emission = 0.2,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-50, 50},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JF_Column",
			texture = "kk_smoke_07",
			final_emit = {
				{0.35, 3, 0, 0, 64.26},
				{0.6, 3, 0, 0, 60.69},
				{0.85, 2, 0, 0, 57.12},
			},
			direction = "Top",
			spread = {30, 30},
			speed = {7.14, 17.85},
			drag = 1.2,
			accel = {0, 9.996, 0},
			lifetime = {1.4, 1.9},
			size = {
				{0, 12.852, 2.856},
				{0.4, 28.56, 4.284},
				{1, 39.27, 5.712},
			},
			transparency = {
				{0, 0.7, 0},
				{0.12, 0.4, 0},
				{0.55, 0.55, 0},
				{0.85, 0.85, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{140, 40, 50},
				},
				{
					0.15,
					{70, 52, 56},
				},
				{
					0.6,
					{96, 86, 90},
				},
				{
					1,
					{124, 118, 120},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -14.28,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JA_GroundGlow",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {1.5, 1.5},
			size = {
				{0, 8.8, 0},
				{0.1, 33, 0},
				{0.7, 30.8, 0},
				{1, 26.4, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{0.1, 0.25, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 70, 84},
				},
				{
					1,
					{190, 20, 40},
				},
			},
			light_emission = 0.8,
			zoffset = -0.5,
			rock_emit = {
				{
					{0.02, 1, 0, 0, 0.25},
				},
			},
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
			name = "JA_Scorch",
			decal = true,
			texture = "kz_scorch",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {3.6, 3.6},
			size = {
				{0, 6.6, 0},
				{0.04, 23.1, 0},
				{1, 24.2, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.3, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			zoffset = -1,
			rock_emit = {
				{
					{0.03, 1, 0, 0, 0.15},
				},
			},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 255, 255},
				},
			},
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "JA_Embers",
			texture = "kk_flare_01",
			direction = "Top",
			spread = {60, 60},
			speed = {8.8, 26.4},
			drag = 1.6,
			accel = {0, 13.2, 0},
			lifetime = {0.8, 1.2},
			size = {
				{0, 0, 0},
				{0.1, 2.64, 0.88},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 200, 200},
				},
				{
					1,
					{240, 40, 56},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rock_emit = {
				{
					{0.15, 5, 0, 0, 13.2},
				},
			},
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
			name = "JBurn_BurnGlow",
			decal = true,
			texture = "fx_glow",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {3.3, 3.3},
			size = {
				{0, 0, 0},
				{0.04, 14, 0},
				{0.75, 11, 0},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.8, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 70, 84},
				},
				{
					1,
					{190, 20, 40},
				},
			},
			light_emission = 0.8,
			rock_emit = {
				{
					{0.45, 1, 0, -0.88, 0.3},
				},
				{
					{0.45, 1, 0, -1.75, 0.3},
				},
				{
					{0.45, 1, 0, 0.75, 0.3},
				},
			},
			final_emit = {
				{0.45, 1, 0, 0, 0.3},
			},
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
			name = "JBurn_BurnFlames",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {6, 0.2, 6},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {8, 8},
			speed = {8, 14},
			drag = 2,
			lifetime = {0.4, 0.62},
			size = {
				{0, 4.4, 1.1},
				{0.3, 12, 3.3},
				{1, 7.7, 2.2},
			},
			offset = {0, 0.6, 0},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 220},
				},
				{
					0.3,
					{255, 90, 96},
				},
				{
					0.7,
					{224, 30, 46},
				},
				{
					1,
					{150, 14, 24},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			stream = {
				{0, 1.65, 14, 5},
				{1.65, 3, 5, 0},
			},
			rock_stream = {
				{
					{0.45, 0, -0.88, 0},
				},
				{
					{0.45, 0, -1.75, 0},
				},
				{
					{0.45, 0, 0.75, 0},
				},
			},
			final_stream = {
				{0.45, 0, 0, 0},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "JBurn_BurnBase",
			texture = "kk_fire_01",
			shape = {
				type = "Box",
				size = {6, 0.2, 6},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 2,
			lifetime = {0.35, 0.55},
			offset = {0, 0.6, 0},
			size = {
				{0, 3.3, 1.1},
				{0.4, 6.6, 1.6},
				{1, 4.4, 1.1},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 236},
				},
				{
					0.1,
					{255, 136, 140},
				},
				{
					0.3,
					{248, 60, 72},
				},
				{
					0.55,
					{212, 24, 44},
				},
				{
					0.8,
					{150, 12, 28},
				},
				{
					1,
					{70, 8, 16},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0, 3, 9, 0},
			},
			rock_stream = {
				{
					{0.45, 0, -0.88, 0},
				},
				{
					{0.45, 0, -1.75, 0},
				},
				{
					{0.45, 0, 0.75, 0},
				},
			},
			final_stream = {
				{0.45, 0, 0, 0},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "JBurn_BurnSmoke",
			texture = "kk_smoke_04",
			direction = "Top",
			spread = {15, 15},
			speed = {6, 12},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.2, 1.7},
			offset = {0, 3, 0},
			size = {
				{0, 3.3, 1.1},
				{1, 14, 3.3},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{96, 70, 74},
				},
				{
					1,
					{124, 116, 118},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.15, 3.1, 3, 1},
			},
			rock_stream = {
				{
					{0.45, 0, -0.88, 0},
				},
				{
					{0.45, 0, -1.75, 0},
				},
				{
					{0.45, 0, 0.75, 0},
				},
			},
			final_stream = {
				{0.45, 0, 0, 0},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
	},
	shakes = {
		{0, 1, 0.8},
	},
	rocks = {
		gap = 14,
		gap_min = 6,
		gap_max = 34,
		jitter = 0.03,
	},
	light = {
		color = {255, 60, 90},
		brightness = 6,
		range = 60,
		time = 1.5,
	},
}

-- H3 IGNITION: las rocas detonan a la vez en una pared de llamas carmesí y dejan marcas de fuego. KaijuFireVFX.<nombre>(rocas, escala, sacudida): rocas = lista de Vector3 (suelo) o de las Parts.
-- rocks = las rocas del rayo: lista de Vector3 (punto del suelo) o de las Parts/Models de las rocas.
-- Todas detonan en el instante de la llamada; el pilar gigante sale en la roca más lejana.
function KaijuFireVFX.H3_DetonationIgnition(rocks: { any }, scale: number?, shake: number?): Part?
	return playRocks(SPEC_H3_DetonationIgnition, rocks, scale, shake)
end

local SPEC_Explosion = {
	name = "Explosion",
	duration = 1.3,
	cleanup = 1.6,
	layers = {
		{
			name = "FlashCore",
			texture = "kk_star_06",
			emit = {
				{0, 2},
			},
			lifetime = {0.1, 0.13},
			size = {
				{0, 10, 0},
				{0.25, 28, 0},
				{1, 32, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 228, 150},
				},
				{
					1,
					{255, 180, 90},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			zoffset = 4,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FlashBurst",
			texture = "kk_scorch_02",
			emit = {
				{0, 2},
				{0.035, 1},
			},
			lifetime = {0.1, 0.14},
			size = {
				{0, 10, 0},
				{0.35, 26, 0},
				{1, 30, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 244, 190},
				},
				{
					1,
					{255, 170, 60},
				},
			},
			light_emission = 0.6,
			brightness = 1.8,
			rotation = {0, 360},
			zoffset = 3,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "GroundRing",
			texture = "kk_circle_03",
			emit = {
				{0, 1},
			},
			offset = {0, -1.9, 0},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {0.34, 0.34},
			size = {
				{0, 4, 0},
				{0.18, 26, 0},
				{0.5, 38, 0},
				{1, 46, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 214, 140},
				},
				{
					1,
					{255, 150, 70},
				},
			},
			light_emission = 0.5,
			brightness = 1.3,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "AirRing",
			texture = "kk_smoke_10",
			emit = {
				{0.015, 1},
			},
			lifetime = {0.26, 0.26},
			size = {
				{0, 8, 0},
				{0.3, 30, 0},
				{1, 38, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.5, 0.65, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 214, 160},
				},
				{
					1,
					{230, 196, 160},
				},
			},
			light_emission = 0.1,
			zoffset = 2,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "WindArcs",
			texture = "kk_twirl_02",
			emit = {
				{0.02, 3},
			},
			lifetime = {0.22, 0.28},
			size = {
				{0, 12, 0},
				{0.4, 32, 0},
				{1, 40, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 248, 230},
				},
				{
					1,
					{255, 230, 190},
				},
			},
			light_emission = 0.5,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-160, 160},
			zoffset = 1.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "WindArcs2",
			texture = "kk_twirl_01",
			emit = {
				{0.05, 2},
			},
			lifetime = {0.2, 0.26},
			size = {
				{0, 14, 0},
				{0.4, 36, 0},
				{1, 44, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.55, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 248, 230},
				},
				{
					1,
					{255, 230, 190},
				},
			},
			light_emission = 0.5,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-160, 160},
			zoffset = 1.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "WindStreaks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{0, 16},
			},
			direction = "Front",
			spread = {180, 8},
			speed = {130, 190},
			drag = 9,
			lifetime = {0.16, 0.24},
			size = {
				{0, 12, 3},
				{1, 18, 3},
			},
			transparency = {
				{0, 0.05, 0},
				{0.5, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 248, 225},
				},
				{
					1,
					{255, 225, 170},
				},
			},
			light_emission = 0.6,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FireballA",
			texture = "kk_fire_01",
			emit = {
				{0, 7},
				{0.04, 3},
			},
			shape = {
				type = "Sphere",
				radius = 2.5,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {18, 34},
			drag = 4.2,
			accel = {0, 10, 0},
			lifetime = {0.5, 0.75},
			size = {
				{0, 6, 1.8},
				{0.15, 16, 3.2},
				{0.6, 22, 3.3},
				{1, 24, 3.6},
			},
			transparency = {
				{0, 0, 0},
				{0.45, 0.05, 0},
				{0.8, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 205},
				},
				{
					0.12,
					{255, 214, 92},
				},
				{
					0.35,
					{255, 150, 42},
				},
				{
					0.65,
					{226, 82, 22},
				},
				{
					1,
					{112, 36, 16},
				},
			},
			light_emission = 0.3,
			brightness = 1.6,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FireballB",
			texture = "kk_fire_02",
			emit = {
				{0, 6},
				{0.05, 3},
			},
			shape = {
				type = "Sphere",
				radius = 2.5,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {18, 34},
			drag = 4.2,
			accel = {0, 10, 0},
			lifetime = {0.5, 0.75},
			size = {
				{0, 5, 1.5},
				{0.15, 14, 2.8},
				{0.6, 20, 3},
				{1, 22, 3.3},
			},
			transparency = {
				{0, 0, 0},
				{0.45, 0.05, 0},
				{0.8, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 205},
				},
				{
					0.12,
					{255, 214, 92},
				},
				{
					0.35,
					{255, 150, 42},
				},
				{
					0.65,
					{226, 82, 22},
				},
				{
					1,
					{112, 36, 16},
				},
			},
			light_emission = 0.3,
			brightness = 1.6,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FireCore",
			texture = "kk_fire_02",
			emit = {
				{0, 3},
			},
			lifetime = {0.28, 0.34},
			speed = {0, 4},
			size = {
				{0, 8, 2},
				{0.3, 18, 3},
				{1, 20, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 250, 220},
				},
				{
					0.4,
					{255, 220, 110},
				},
				{
					1,
					{255, 150, 50},
				},
			},
			light_emission = 0.5,
			brightness = 2,
			rotation = {0, 360},
			rot_speed = {-90, 90},
			zoffset = 1,
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FireTongues",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			emit = {
				{0.01, 10},
				{0.07, 4},
			},
			direction = "Top",
			spread = {110, 110},
			speed = {50, 90},
			drag = 6.5,
			accel = {0, -10, 0},
			lifetime = {0.36, 0.52},
			size = {
				{0, 6, 1.8},
				{0.2, 16, 4},
				{1, 13, 3.25},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.25,
					{255, 190, 70},
				},
				{
					0.6,
					{250, 120, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.3,
			brightness = 1.7,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FireTongues2",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			emit = {
				{0.02, 8},
			},
			direction = "Top",
			spread = {110, 110},
			speed = {45, 85},
			drag = 6.5,
			accel = {0, -10, 0},
			lifetime = {0.34, 0.5},
			size = {
				{0, 5, 1.5},
				{0.2, 14, 3.5},
				{1, 11, 2.75},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.25,
					{255, 190, 70},
				},
				{
					0.6,
					{250, 120, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.3,
			brightness = 1.7,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Column",
			texture = "kk_muzzle_01",
			orientation = "VelocityParallel",
			emit = {
				{0.03, 5},
			},
			direction = "Top",
			spread = {14, 14},
			speed = {60, 95},
			drag = 5,
			accel = {0, 0, 0},
			lifetime = {0.4, 0.55},
			size = {
				{0, 10, 3},
				{0.2, 22, 5.5},
				{1, 18, 4.5},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.25,
					{255, 190, 70},
				},
				{
					0.6,
					{250, 120, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.3,
			brightness = 1.7,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Pops",
			texture = "kk_fire_01",
			emit = {
				{0.1, 3},
				{0.17, 2},
			},
			shape = {
				type = "Sphere",
				radius = 7,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {4, 10},
			drag = 4,
			accel = {0, 4, 0},
			lifetime = {0.34, 0.44},
			size = {
				{0, 4, 1.2},
				{0.15, 8, 1.6},
				{0.6, 10, 1.5},
				{1, 10, 1.5},
			},
			transparency = {
				{0, 0, 0},
				{0.45, 0.05, 0},
				{0.8, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 205},
				},
				{
					0.12,
					{255, 214, 92},
				},
				{
					0.35,
					{255, 150, 42},
				},
				{
					0.65,
					{226, 82, 22},
				},
				{
					1,
					{112, 36, 16},
				},
			},
			light_emission = 0.3,
			brightness = 1.6,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Sparks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{0, 30},
				{0.06, 16},
			},
			direction = "Top",
			spread = {180, 180},
			speed = {70, 140},
			drag = 4,
			accel = {0, -60, 0},
			lifetime = {0.25, 0.5},
			size = {
				{0, 9, 3},
				{1, 3, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.5,
					{255, 170, 60},
				},
				{
					1,
					{230, 80, 20},
				},
			},
			light_emission = 0.8,
			brightness = 1.8,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Debris",
			texture = "kz_debris_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0.02, 14},
			},
			direction = "Top",
			spread = {70, 70},
			speed = {40, 75},
			drag = 1.2,
			accel = {0, -110, 0},
			lifetime = {0.7, 0.95},
			size = {
				{0, 1.6, 0.7},
				{1, 1.4, 0.6},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			rot_speed = {-420, 420},
			zoffset = -0.5,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 255, 255},
				},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "GroundDust",
			texture = "kk_smoke_04",
			emit = {
				{0.02, 14},
			},
			offset = {0, -1.2, 0},
			direction = "Front",
			spread = {180, 4},
			speed = {55, 95},
			drag = 5.5,
			accel = {0, 5, 0},
			lifetime = {0.5, 0.7},
			size = {
				{0, 5, 1},
				{0.4, 11, 2},
				{1, 14, 2},
			},
			transparency = {
				{0, 0.3, 0},
				{0.5, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{226, 206, 178},
				},
				{
					1,
					{205, 192, 176},
				},
			},
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = -0.5,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Smoke",
			texture = "kk_smoke_07",
			emit = {
				{0.24, 4},
				{0.32, 2},
			},
			shape = {
				type = "Sphere",
				radius = 4,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {60, 60},
			speed = {16, 28},
			drag = 1.6,
			accel = {0, 18, 0},
			lifetime = {0.75, 0.92},
			size = {
				{0, 14, 3},
				{0.5, 28, 4},
				{1, 34, 4},
			},
			transparency = {
				{0, 0.45, 0},
				{0.25, 0.2, 0},
				{0.75, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{112, 98, 90},
				},
				{
					0.5,
					{128, 118, 112},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -7,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Smoke2",
			texture = "kk_smoke_08",
			emit = {
				{0.28, 4},
			},
			shape = {
				type = "Sphere",
				radius = 4,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {60, 60},
			speed = {14, 24},
			drag = 1.6,
			accel = {0, 16, 0},
			lifetime = {0.72, 0.9},
			size = {
				{0, 12, 3},
				{0.5, 26, 4},
				{1, 32, 4},
			},
			transparency = {
				{0, 0.45, 0},
				{0.25, 0.2, 0},
				{0.75, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{112, 98, 90},
				},
				{
					0.5,
					{128, 118, 112},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -7,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Embers",
			texture = "kk_flare_01",
			emit = {
				{0.12, 18},
			},
			shape = {
				type = "Sphere",
				radius = 4,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {120, 120},
			speed = {10, 30},
			drag = 2,
			accel = {0, 14, 0},
			lifetime = {0.45, 0.7},
			size = {
				{0, 2.2, 0.6},
				{1, 0, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.7, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 140},
				},
				{
					1,
					{255, 110, 40},
				},
			},
			light_emission = 1,
			brightness = 2,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
	},
	light = {
		color = {255, 150, 60},
		brightness = 4,
		range = 30,
		time = 0.35,
	},
}

-- Explosión de fuego estilo anime (impacto de la H1). Dura 1.3 s y cierra limpio.
function KaijuFireVFX.Explosion(cf: CFrame, scale: number?, shake: number?): Part
	return play(SPEC_Explosion, cf, scale, nil, shake)
end

local SPEC_ExplosionAnime = {
	name = "ExplosionAnime",
	duration = 1.3,
	cleanup = 1.6,
	layers = {
		{
			name = "FlashBurst",
			texture = "fx_burst_a",
			emit = {
				{0, 2},
			},
			offset = {0, 4, 0},
			lifetime = {0.12, 0.15},
			size = {
				{0, 10, 0},
				{0.3, 34, 0},
				{1, 40, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 170},
				},
				{
					1,
					{255, 180, 80},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {0, 360},
			zoffset = 6,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FlashStar",
			texture = "fx_star",
			emit = {
				{0, 1},
			},
			offset = {0, 4, 0},
			lifetime = {0.16, 0.16},
			size = {
				{0, 20, 0},
				{0.25, 52, 0},
				{1, 30, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 200},
				},
				{
					1,
					{255, 200, 110},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 0},
			zoffset = 7,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Glow",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			offset = {0, 5, 0},
			lifetime = {0.4, 0.4},
			size = {
				{0, 18, 0},
				{0.15, 40, 0},
				{1, 46, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.5, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 214, 110},
				},
				{
					1,
					{255, 130, 40},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = -2,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "GroundRing",
			texture = "fx_shock_spiky",
			emit = {
				{0, 1},
			},
			offset = {0, -1.9, 0},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {0.36, 0.36},
			size = {
				{0, 6, 0},
				{0.25, 40, 0},
				{1, 60, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.5, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					1,
					{255, 140, 50},
				},
			},
			light_emission = 0.7,
			brightness = 1.2,
			rotation = {0, 360},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "AirRing",
			texture = "fx_shock_soft",
			emit = {
				{0.02, 1},
			},
			offset = {0, 5, 0},
			lifetime = {0.24, 0.24},
			size = {
				{0, 10, 0},
				{0.4, 44, 0},
				{1, 54, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 190},
				},
				{
					1,
					{255, 190, 110},
				},
			},
			light_emission = 0.8,
			brightness = 1,
			zoffset = 3,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "WindSwirl",
			texture = "fx_wind_lines",
			emit = {
				{0, 2},
				{0.06, 1},
			},
			offset = {0, -1.2, 0},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			lifetime = {0.4, 0.48},
			size = {
				{0, 12, 2},
				{0.3, 40, 4},
				{1, 58, 4},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 222, 120},
				},
				{
					0.5,
					{255, 160, 56},
				},
				{
					1,
					{240, 96, 28},
				},
			},
			light_emission = 0.8,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-640, -460},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "WindSwirl2",
			texture = "fx_wind_swirl",
			emit = {
				{0.03, 2},
			},
			offset = {0, 0.5, 0},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			spread = {14, 14},
			speed = {0.01, 0.01},
			lifetime = {0.38, 0.44},
			size = {
				{0, 14, 2},
				{0.3, 36, 3},
				{1, 50, 3},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 222, 120},
				},
				{
					0.5,
					{255, 160, 56},
				},
				{
					1,
					{240, 96, 28},
				},
			},
			light_emission = 0.8,
			brightness = 1.2,
			rotation = {0, 360},
			rot_speed = {420, 600},
			accel = {0, 0, 0},
			drag = 0,
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "ArcsFlat",
			texture = "fx_feather_4x4",
			flipbook = {
				layout = "Grid4x4",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 6},
				{0.05, 4},
			},
			offset = {0, -0.8, 0},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			spread = {18, 18},
			speed = {0.01, 0.01},
			lifetime = {0.36, 0.48},
			size = {
				{0, 12, 3},
				{0.3, 30, 5},
				{1, 42, 5},
			},
			transparency = {
				{0, 0, 0},
				{0.65, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 222, 120},
				},
				{
					0.5,
					{255, 160, 56},
				},
				{
					1,
					{240, 96, 28},
				},
			},
			light_emission = 0.7,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-520, -320},
			accel = {0, 0, 0},
			drag = 0,
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "ArcsOut",
			texture = "fx_feather_4x4",
			flipbook = {
				layout = "Grid4x4",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 10},
				{0.05, 6},
			},
			offset = {0, 4, 0},
			shape = {
				type = "Sphere",
				radius = 4,
				style = "Surface",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {30, 60},
			drag = 6,
			lifetime = {0.3, 0.42},
			size = {
				{0, 8, 2},
				{0.3, 18, 3},
				{1, 22, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 222, 120},
				},
				{
					0.5,
					{255, 160, 56},
				},
				{
					1,
					{240, 96, 28},
				},
			},
			light_emission = 0.6,
			brightness = 1.3,
			rotation = {0, 360},
			rot_speed = {-480, 480},
			zoffset = 2,
			accel = {0, 0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FireFan",
			texture = "fx_burst_fan",
			emit = {
				{0.02, 2},
			},
			offset = {0, 6, 0},
			lifetime = {0.36, 0.42},
			size = {
				{0, 14, 0},
				{0.25, 40, 0},
				{1, 46, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 196, 80},
				},
				{
					0.7,
					{255, 138, 40},
				},
				{
					1,
					{220, 74, 20},
				},
			},
			light_emission = 0.55,
			brightness = 1.3,
			rotation = {-12, 12},
			zoffset = 0.5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FlamesOut",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			emit = {
				{0.01, 10},
				{0.06, 6},
			},
			offset = {0, 3, 0},
			shape = {
				type = "Sphere",
				radius = 3,
				style = "Surface",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {40, 80},
			drag = 6,
			accel = {0, 12, 0},
			lifetime = {0.4, 0.58},
			size = {
				{0, 6, 2},
				{0.25, 17, 3},
				{1, 14, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 186, 70},
				},
				{
					0.35,
					{255, 132, 38},
				},
				{
					0.75,
					{226, 78, 22},
				},
				{
					1,
					{150, 40, 14},
				},
			},
			light_emission = 0.35,
			brightness = 1.4,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "Core",
			texture = "fx_smoke_round",
			emit = {
				{0, 3},
			},
			offset = {0, 5, 0},
			shape = {
				type = "Sphere",
				radius = 2,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {2, 6},
			drag = 3,
			accel = {0, 6, 0},
			lifetime = {0.42, 0.52},
			size = {
				{0, 10, 2},
				{0.2, 26, 3},
				{1, 30, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.55, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 226, 120},
				},
				{
					0.35,
					{255, 170, 60},
				},
				{
					1,
					{220, 80, 24},
				},
			},
			light_emission = 0.55,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Streaks",
			texture = "fx_line",
			orientation = "VelocityParallel",
			offset = {0, 4, 0},
			emit = {
				{0, 28},
				{0.05, 14},
			},
			direction = "Top",
			spread = {180, 180},
			speed = {90, 170},
			drag = 4.5,
			accel = {0, -40, 0},
			lifetime = {0.22, 0.4},
			size = {
				{0, 14, 4},
				{1, 5, 0},
			},
			color = {
				{
					0,
					{255, 238, 150},
				},
				{
					0.5,
					{255, 184, 60},
				},
				{
					1,
					{255, 110, 24},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "CurveStreaks",
			texture = "fx_line_curve",
			emit = {
				{0.02, 8},
			},
			offset = {0, 4, 0},
			shape = {
				type = "Sphere",
				radius = 6,
				style = "Surface",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {20, 40},
			drag = 5,
			lifetime = {0.2, 0.3},
			size = {
				{0, 10, 2},
				{1, 16, 2},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 222, 120},
				},
				{
					0.5,
					{255, 160, 56},
				},
				{
					1,
					{240, 96, 28},
				},
			},
			light_emission = 0.9,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-300, 300},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Twinkles",
			texture = "fx_spark4",
			emit = {
				{0.08, 14},
			},
			offset = {0, 6, 0},
			shape = {
				type = "Sphere",
				radius = 9,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {8, 22},
			drag = 2,
			accel = {0, 8, 0},
			lifetime = {0.3, 0.55},
			size = {
				{0, 0, 0},
				{0.15, 3.5, 1},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 236, 160},
				},
				{
					1,
					{255, 150, 50},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {0, 360},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "Debris",
			texture = "kz_debris_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0.02, 10},
			},
			direction = "Top",
			spread = {70, 70},
			speed = {40, 75},
			drag = 1.2,
			accel = {0, -110, 0},
			lifetime = {0.7, 0.95},
			size = {
				{0, 1.6, 0.7},
				{1, 1.4, 0.6},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			rot_speed = {-420, 420},
			zoffset = -0.5,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 255, 255},
				},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Smoke",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0.2, 5},
				{0.28, 3},
			},
			offset = {0, 7, 0},
			shape = {
				type = "Sphere",
				radius = 5,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {60, 60},
			speed = {10, 20},
			drag = 1.6,
			accel = {0, 14, 0},
			lifetime = {0.75, 0.9},
			size = {
				{0, 14, 3},
				{0.5, 26, 4},
				{1, 32, 4},
			},
			transparency = {
				{0, 0.6, 0},
				{0.2, 0.15, 0},
				{0.7, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{92, 78, 74},
				},
				{
					0.5,
					{110, 98, 94},
				},
				{
					1,
					{132, 124, 120},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -9,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
	},
	light = {
		color = {255, 160, 60},
		brightness = 5,
		range = 36,
		time = 0.45,
	},
}

-- Explosión de fuego estilo ANIME (texturas Effekseer CC0: medias lunas, remolinos, estallido). 1.3 s, cierra limpio.
function KaijuFireVFX.ExplosionAnime(cf: CFrame, scale: number?, shake: number?): Part
	return play(SPEC_ExplosionAnime, cf, scale, nil, shake)
end

local SPEC_FireLine = {
	name = "FireLine",
	duration = 2.5,
	cleanup = 3.2,
	layers = {
		{
			name = "CrackA",
			texture = "kk_spark_01",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			emit = {
				{0.05, 1, 0, 0.72, 0.15},
				{0.104, 1, 0.077, -0.66, 0.15},
				{0.158, 1, 0.154, 0.38, 0.15},
				{0.212, 1, 0.231, -0.31, 0.15},
				{0.265, 1, 0.308, 0.17, 0.15},
				{0.319, 1, 0.385, -0.55, 0.15},
				{0.373, 1, 0.462, -0.17, 0.15},
				{0.427, 1, 0.538, 0.79, 0.15},
				{0.481, 1, 0.615, 0.07, 0.15},
				{0.535, 1, 0.692, -0.37, 0.15},
				{0.588, 1, 0.769, -0.76, 0.15},
				{0.642, 1, 0.846, -0.29, 0.15},
				{0.696, 1, 0.923, 0.63, 0.15},
				{0.75, 1, 1, 0.1, 0.15},
			},
			lifetime = {2.05, 2.15},
			size = {
				{0, 3, 0},
				{0.04, 14, 2},
				{0.75, 14, 2},
				{1, 11, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.7, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 160},
				},
				{
					0.3,
					{255, 170, 60},
				},
				{
					1,
					{220, 70, 20},
				},
			},
			light_emission = 0.8,
			brightness = 1.8,
			rotation = {0, 360},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "CrackB",
			texture = "kk_spark_02",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			emit = {
				{0.093, 1, 0.018, -0.86, 0.12},
				{0.121, 1, 0.058, 1.2, 0.12},
				{0.179, 1, 0.141, -0.91, 0.12},
				{0.246, 1, 0.237, -0.37, 0.12},
				{0.306, 1, 0.323, -0.64, 0.12},
				{0.362, 1, 0.403, -0.43, 0.12},
				{0.406, 1, 0.466, 1.04, 0.12},
				{0.462, 1, 0.546, 1.02, 0.12},
				{0.517, 1, 0.624, -1.08, 0.12},
				{0.575, 1, 0.708, 0.21, 0.12},
				{0.613, 1, 0.762, -0.74, 0.12},
				{0.682, 1, 0.86, 0.2, 0.12},
				{0.738, 1, 0.941, 0.66, 0.12},
				{0.78, 1, 1, 0.16, 0.12},
			},
			lifetime = {2, 2.1},
			size = {
				{0, 3, 0},
				{0.04, 12, 2},
				{0.75, 12, 2},
				{1, 9, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.7, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 160},
				},
				{
					0.3,
					{255, 170, 60},
				},
				{
					1,
					{220, 70, 20},
				},
			},
			light_emission = 0.8,
			brightness = 1.6,
			rotation = {0, 360},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FuseHead",
			texture = "kk_star_06",
			emit = {
				{0.05, 1, 0, 0, 1},
				{0.104, 1, 0.077, 0, 1},
				{0.158, 1, 0.154, 0, 1},
				{0.212, 1, 0.231, 0, 1},
				{0.265, 1, 0.308, 0, 1},
				{0.319, 1, 0.385, 0, 1},
				{0.373, 1, 0.462, 0, 1},
				{0.427, 1, 0.538, 0, 1},
				{0.481, 1, 0.615, 0, 1},
				{0.535, 1, 0.692, 0, 1},
				{0.588, 1, 0.769, 0, 1},
				{0.642, 1, 0.846, 0, 1},
				{0.696, 1, 0.923, 0, 1},
				{0.75, 1, 1, 0, 1},
			},
			lifetime = {0.12, 0.15},
			size = {
				{0, 6, 0},
				{0.3, 11, 0},
				{1, 7, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 230, 160},
				},
				{
					1,
					{255, 170, 80},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {0, 360},
			zoffset = 2,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FuseSparks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{0.05, 6, 0, 0, 0.5},
				{0.104, 6, 0.077, 0, 0.5},
				{0.158, 6, 0.154, 0, 0.5},
				{0.212, 6, 0.231, 0, 0.5},
				{0.265, 6, 0.308, 0, 0.5},
				{0.319, 6, 0.385, 0, 0.5},
				{0.373, 6, 0.462, 0, 0.5},
				{0.427, 6, 0.538, 0, 0.5},
				{0.481, 6, 0.615, 0, 0.5},
				{0.535, 6, 0.692, 0, 0.5},
				{0.588, 6, 0.769, 0, 0.5},
				{0.642, 6, 0.846, 0, 0.5},
				{0.696, 6, 0.923, 0, 0.5},
				{0.75, 6, 1, 0, 0.5},
			},
			direction = "Top",
			spread = {55, 55},
			speed = {30, 60},
			drag = 3,
			accel = {0, -70, 0},
			lifetime = {0.25, 0.4},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					1,
					{240, 110, 30},
				},
			},
			light_emission = 0.8,
			brightness = 1.8,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FuseFlames",
			texture = "kk_muzzle_05",
			orientation = "VelocityParallel",
			emit = {
				{0.05, 2, 0, 0, 0.3},
				{0.104, 2, 0.077, 0, 0.3},
				{0.158, 2, 0.154, 0, 0.3},
				{0.212, 2, 0.231, 0, 0.3},
				{0.265, 2, 0.308, 0, 0.3},
				{0.319, 2, 0.385, 0, 0.3},
				{0.373, 2, 0.462, 0, 0.3},
				{0.427, 2, 0.538, 0, 0.3},
				{0.481, 2, 0.615, 0, 0.3},
				{0.535, 2, 0.692, 0, 0.3},
				{0.588, 2, 0.769, 0, 0.3},
				{0.642, 2, 0.846, 0, 0.3},
				{0.696, 2, 0.923, 0, 0.3},
				{0.75, 2, 1, 0, 0.3},
			},
			direction = "Top",
			spread = {25, 25},
			speed = {18, 30},
			drag = 3,
			accel = {0, 0, 0},
			lifetime = {0.32, 0.45},
			size = {
				{0, 3, 0.9},
				{0.2, 8, 2},
				{1, 6, 1.5},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.25,
					{255, 190, 70},
				},
				{
					0.6,
					{250, 120, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.3,
			brightness = 1.7,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "EruptFlash",
			texture = "kk_scorch_02",
			emit = {
				{0.95, 1, 0, 0, 3},
				{0.981, 1, 0.154, 0, 3},
				{1.012, 1, 0.308, 0, 3},
				{1.042, 1, 0.462, 0, 3},
				{1.073, 1, 0.615, 0, 3},
				{1.104, 1, 0.769, 0, 3},
				{1.135, 1, 0.923, 0, 3},
			},
			lifetime = {0.09, 0.12},
			size = {
				{0, 8, 0},
				{0.35, 20, 0},
				{1, 22, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					1,
					{255, 160, 60},
				},
			},
			light_emission = 0.6,
			brightness = 1.7,
			rotation = {0, 360},
			zoffset = 3,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "EruptRing",
			texture = "kk_circle_03",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			emit = {
				{0.95, 1, 0, 0, 0.2},
				{0.996, 1, 0.231, 0, 0.2},
				{1.042, 1, 0.462, 0, 0.2},
				{1.088, 1, 0.692, 0, 0.2},
				{1.135, 1, 0.923, 0, 0.2},
			},
			lifetime = {0.3, 0.3},
			size = {
				{0, 3, 0},
				{0.2, 18, 0},
				{0.5, 26, 0},
				{1, 30, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 214, 140},
				},
				{
					1,
					{255, 150, 70},
				},
			},
			light_emission = 0.5,
			brightness = 1.3,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "EruptColumn",
			texture = "kk_muzzle_01",
			orientation = "VelocityParallel",
			emit = {
				{0.95, 3, 0, 1.85, 0.5},
				{0.965, 3, 0.077, 0.82, 0.5},
				{0.981, 3, 0.154, -1.01, 0.5},
				{0.996, 3, 0.231, -1.16, 0.5},
				{1.012, 3, 0.308, -0.16, 0.5},
				{1.027, 3, 0.385, -0.02, 0.5},
				{1.042, 3, 0.462, 1.32, 0.5},
				{1.058, 3, 0.538, -1.06, 0.5},
				{1.073, 3, 0.615, -0.93, 0.5},
				{1.088, 3, 0.692, 1.61, 0.5},
				{1.104, 3, 0.769, -1.55, 0.5},
				{1.119, 3, 0.846, 1.97, 0.5},
				{1.135, 3, 0.923, 0.48, 0.5},
				{1.15, 3, 1, 0.64, 0.5},
			},
			direction = "Top",
			spread = {14, 14},
			speed = {70, 115},
			drag = 4.5,
			accel = {0, 0, 0},
			lifetime = {0.45, 0.62},
			size = {
				{0, 8, 2.4},
				{0.2, 21, 5.25},
				{1, 17, 4.25},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.25,
					{255, 190, 70},
				},
				{
					0.6,
					{250, 120, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.3,
			brightness = 1.7,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "EruptColumn2",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			emit = {
				{0.97, 2, 0, 0.81, 0.5},
				{0.985, 2, 0.077, -1.51, 0.5},
				{1.001, 2, 0.154, -0.03, 0.5},
				{1.016, 2, 0.231, -0.21, 0.5},
				{1.032, 2, 0.308, -1.23, 0.5},
				{1.047, 2, 0.385, -0.88, 0.5},
				{1.062, 2, 0.462, 1.44, 0.5},
				{1.078, 2, 0.538, 2.22, 0.5},
				{1.093, 2, 0.615, -1.31, 0.5},
				{1.108, 2, 0.692, 0.38, 0.5},
				{1.124, 2, 0.769, 0.89, 0.5},
				{1.139, 2, 0.846, 1.68, 0.5},
				{1.155, 2, 0.923, -1.01, 0.5},
				{1.17, 2, 1, 2.38, 0.5},
			},
			direction = "Top",
			spread = {18, 18},
			speed = {60, 100},
			drag = 4.5,
			accel = {0, 0, 0},
			lifetime = {0.42, 0.58},
			size = {
				{0, 7, 2.1},
				{0.2, 18, 4.5},
				{1, 15, 3.75},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.25,
					{255, 190, 70},
				},
				{
					0.6,
					{250, 120, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.3,
			brightness = 1.7,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "EruptBurst",
			texture = "kk_fire_01",
			emit = {
				{0.95, 2, 0, -0.63, 3},
				{0.965, 2, 0.077, 1.83, 3},
				{0.981, 2, 0.154, 0.01, 3},
				{0.996, 2, 0.231, -2.1, 3},
				{1.012, 2, 0.308, 0.58, 3},
				{1.027, 2, 0.385, -0.6, 3},
				{1.042, 2, 0.462, -0.24, 3},
				{1.058, 2, 0.538, -1.71, 3},
				{1.073, 2, 0.615, -1.95, 3},
				{1.088, 2, 0.692, 2.12, 3},
				{1.104, 2, 0.769, 1.37, 3},
				{1.119, 2, 0.846, 1.23, 3},
				{1.135, 2, 0.923, -1.04, 3},
				{1.15, 2, 1, 1.13, 3},
			},
			shape = {
				type = "Sphere",
				radius = 1.5,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {8, 20},
			drag = 4,
			accel = {0, 12, 0},
			lifetime = {0.55, 0.75},
			size = {
				{0, 7, 2.1},
				{0.15, 15, 3},
				{0.6, 19, 2.85},
				{1, 20, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.45, 0.05, 0},
				{0.8, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 246, 205},
				},
				{
					0.12,
					{255, 214, 92},
				},
				{
					0.35,
					{255, 150, 42},
				},
				{
					0.65,
					{226, 82, 22},
				},
				{
					1,
					{112, 36, 16},
				},
			},
			light_emission = 0.3,
			brightness = 1.6,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "EruptDebris",
			texture = "kz_debris_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0.95, 3, 0, 0, 1},
				{0.965, 3, 0.077, 0, 1},
				{0.981, 3, 0.154, 0, 1},
				{0.996, 3, 0.231, 0, 1},
				{1.012, 3, 0.308, 0, 1},
				{1.027, 3, 0.385, 0, 1},
				{1.042, 3, 0.462, 0, 1},
				{1.058, 3, 0.538, 0, 1},
				{1.073, 3, 0.615, 0, 1},
				{1.088, 3, 0.692, 0, 1},
				{1.104, 3, 0.769, 0, 1},
				{1.119, 3, 0.846, 0, 1},
				{1.135, 3, 0.923, 0, 1},
				{1.15, 3, 1, 0, 1},
			},
			direction = "Top",
			spread = {45, 45},
			speed = {40, 72},
			drag = 1.2,
			accel = {0, -110, 0},
			lifetime = {0.7, 0.9},
			size = {
				{0, 1.5, 0.6},
				{1, 1.3, 0.5},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			rot_speed = {-420, 420},
			zoffset = -0.5,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 255, 255},
				},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "EruptSparks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{0.95, 5, 0, 0, 2},
				{0.965, 5, 0.077, 0, 2},
				{0.981, 5, 0.154, 0, 2},
				{0.996, 5, 0.231, 0, 2},
				{1.012, 5, 0.308, 0, 2},
				{1.027, 5, 0.385, 0, 2},
				{1.042, 5, 0.462, 0, 2},
				{1.058, 5, 0.538, 0, 2},
				{1.073, 5, 0.615, 0, 2},
				{1.088, 5, 0.692, 0, 2},
				{1.104, 5, 0.769, 0, 2},
				{1.119, 5, 0.846, 0, 2},
				{1.135, 5, 0.923, 0, 2},
				{1.15, 5, 1, 0, 2},
			},
			direction = "Top",
			spread = {75, 75},
			speed = {70, 130},
			drag = 4,
			accel = {0, -60, 0},
			lifetime = {0.25, 0.45},
			size = {
				{0, 10, 2},
				{1, 3, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.5,
					{255, 170, 60},
				},
				{
					1,
					{230, 80, 20},
				},
			},
			light_emission = 0.8,
			brightness = 1.8,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "EruptWindR",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{0.95, 1, 0, 0, 2},
				{0.981, 1, 0.154, 0, 2},
				{1.012, 1, 0.308, 0, 2},
				{1.042, 1, 0.462, 0, 2},
				{1.073, 1, 0.615, 0, 2},
				{1.104, 1, 0.769, 0, 2},
				{1.135, 1, 0.923, 0, 2},
			},
			direction = "Right",
			spread = {20, 10},
			speed = {120, 170},
			drag = 9,
			lifetime = {0.16, 0.22},
			size = {
				{0, 12, 2},
				{1, 18, 2},
			},
			transparency = {
				{0, 0.05, 0},
				{0.5, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 248, 225},
				},
				{
					1,
					{255, 225, 170},
				},
			},
			light_emission = 0.6,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "EruptWindL",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{0.95, 1, 0, 0, 2},
				{0.981, 1, 0.154, 0, 2},
				{1.012, 1, 0.308, 0, 2},
				{1.042, 1, 0.462, 0, 2},
				{1.073, 1, 0.615, 0, 2},
				{1.104, 1, 0.769, 0, 2},
				{1.135, 1, 0.923, 0, 2},
			},
			direction = "Left",
			spread = {20, 10},
			speed = {120, 170},
			drag = 9,
			lifetime = {0.16, 0.22},
			size = {
				{0, 12, 2},
				{1, 18, 2},
			},
			transparency = {
				{0, 0.05, 0},
				{0.5, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 248, 225},
				},
				{
					1,
					{255, 225, 170},
				},
			},
			light_emission = 0.6,
			brightness = 1.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Scorch",
			texture = "kz_scorch",
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			emit = {
				{0.95, 1, 0, 0.41, 0.1},
				{0.965, 1, 0.077, 0.88, 0.1},
				{0.981, 1, 0.154, -0.49, 0.1},
				{0.996, 1, 0.231, 0.32, 0.1},
				{1.012, 1, 0.308, 0.37, 0.1},
				{1.027, 1, 0.385, 0.56, 0.1},
				{1.042, 1, 0.462, -0.55, 0.1},
				{1.058, 1, 0.538, -0.28, 0.1},
				{1.073, 1, 0.615, 0.61, 0.1},
				{1.088, 1, 0.692, -0.7, 0.1},
				{1.104, 1, 0.769, 0.33, 0.1},
				{1.119, 1, 0.846, 0.3, 0.1},
				{1.135, 1, 0.923, -0.33, 0.1},
				{1.15, 1, 1, -0.59, 0.1},
			},
			lifetime = {1.3, 1.4},
			size = {
				{0, 8, 1},
				{0.1, 14, 2},
				{1, 15, 2},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.35, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			zoffset = -0.2,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 255, 255},
				},
			},
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Wall",
			texture = "kk_muzzle_03",
			orientation = "VelocityParallel",
			emit = {
				{1.09, 3, 0, -2.93, 0.5},
				{1.105, 3, 0.077, -2.05, 0.5},
				{1.121, 3, 0.154, -2.9, 0.5},
				{1.136, 3, 0.231, 1.09, 0.5},
				{1.152, 3, 0.308, 3, 0.5},
				{1.167, 3, 0.385, -0.97, 0.5},
				{1.182, 3, 0.462, -1.32, 0.5},
				{1.198, 3, 0.538, -1.63, 0.5},
				{1.213, 3, 0.615, 2.25, 0.5},
				{1.228, 3, 0.692, -1.66, 0.5},
				{1.244, 3, 0.769, 0.07, 0.5},
				{1.259, 3, 0.846, -0.27, 0.5},
				{1.275, 3, 0.923, -2.53, 0.5},
				{1.29, 3, 1, -0.84, 0.5},
			},
			direction = "Top",
			spread = {20, 20},
			speed = {40, 70},
			drag = 4,
			accel = {0, 0, 0},
			lifetime = {0.42, 0.55},
			size = {
				{0, 7, 2.1},
				{0.2, 16, 4},
				{1, 13, 3.25},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.25,
					{255, 190, 70},
				},
				{
					0.6,
					{250, 120, 30},
				},
				{
					1,
					{180, 50, 18},
				},
			},
			light_emission = 0.3,
			brightness = 1.7,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Smoke",
			texture = "kk_smoke_07",
			emit = {
				{1.25, 1, 0, -0.12, 6},
				{1.265, 1, 0.077, -0.32, 6},
				{1.281, 1, 0.154, 0.95, 6},
				{1.296, 1, 0.231, 0.81, 6},
				{1.312, 1, 0.308, -1.19, 6},
				{1.327, 1, 0.385, -2.15, 6},
				{1.342, 1, 0.462, -1.14, 6},
				{1.358, 1, 0.538, 2.74, 6},
				{1.373, 1, 0.615, 2.36, 6},
				{1.388, 1, 0.692, 1, 6},
				{1.404, 1, 0.769, -0.26, 6},
				{1.419, 1, 0.846, -1.22, 6},
				{1.435, 1, 0.923, -1.14, 6},
				{1.45, 1, 1, 1.73, 6},
			},
			direction = "Top",
			spread = {40, 40},
			speed = {14, 26},
			drag = 1.6,
			accel = {0, 16, 0},
			lifetime = {0.75, 0.92},
			size = {
				{0, 12, 3},
				{0.5, 24, 4},
				{1, 30, 4},
			},
			transparency = {
				{0, 0.45, 0},
				{0.25, 0.2, 0},
				{0.75, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{112, 98, 90},
				},
				{
					0.5,
					{128, 118, 112},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -7,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Smoke2",
			texture = "kk_smoke_08",
			emit = {
				{1.31, 1, 0, 1.71, 6},
				{1.325, 1, 0.077, 0.07, 6},
				{1.341, 1, 0.154, 2.98, 6},
				{1.356, 1, 0.231, -2.11, 6},
				{1.372, 1, 0.308, -1.44, 6},
				{1.387, 1, 0.385, -1.39, 6},
				{1.402, 1, 0.462, -1.05, 6},
				{1.418, 1, 0.538, 0.42, 6},
				{1.433, 1, 0.615, -2.58, 6},
				{1.448, 1, 0.692, 0.25, 6},
				{1.464, 1, 0.769, 1.4, 6},
				{1.479, 1, 0.846, -0.51, 6},
				{1.495, 1, 0.923, 1.37, 6},
				{1.51, 1, 1, -0.62, 6},
			},
			direction = "Top",
			spread = {40, 40},
			speed = {12, 22},
			drag = 1.6,
			accel = {0, 14, 0},
			lifetime = {0.72, 0.9},
			size = {
				{0, 11, 3},
				{0.5, 22, 4},
				{1, 28, 4},
			},
			transparency = {
				{0, 0.45, 0},
				{0.25, 0.2, 0},
				{0.75, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{112, 98, 90},
				},
				{
					0.5,
					{128, 118, 112},
				},
				{
					1,
					{150, 144, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -7,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Embers",
			texture = "kk_flare_01",
			emit = {
				{1.15, 3, 0, 0, 4},
				{1.165, 3, 0.077, 0, 4},
				{1.181, 3, 0.154, 0, 4},
				{1.196, 3, 0.231, 0, 4},
				{1.212, 3, 0.308, 0, 4},
				{1.227, 3, 0.385, 0, 4},
				{1.242, 3, 0.462, 0, 4},
				{1.258, 3, 0.538, 0, 4},
				{1.273, 3, 0.615, 0, 4},
				{1.288, 3, 0.692, 0, 4},
				{1.304, 3, 0.769, 0, 4},
				{1.319, 3, 0.846, 0, 4},
				{1.335, 3, 0.923, 0, 4},
				{1.35, 3, 1, 0, 4},
			},
			direction = "Top",
			spread = {110, 110},
			speed = {10, 28},
			drag = 2,
			accel = {0, 14, 0},
			lifetime = {0.45, 0.7},
			size = {
				{0, 2.2, 0.6},
				{1, 0, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.7, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 140},
				},
				{
					1,
					{255, 110, 40},
				},
			},
			light_emission = 1,
			brightness = 2,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
	},
	light = {
		color = {255, 140, 50},
		brightness = 3,
		range = 40,
		time = 0.6,
	},
}

-- Línea de fuego (H3): KaijuFireVFX.FireLine(CFrame.lookAt(origen, origen + direccion), largo, escala).
-- length = largo de la línea en studs (por defecto 90 × escala).
function KaijuFireVFX.FireLine(cf: CFrame, length: number?, scale: number?, shake: number?): Part
	return play(SPEC_FireLine, cf, scale, length or 90 * (scale or 1), shake)
end

local SPEC_UltimateBeam = {
	name = "UltimateBeam",
	duration = 3.6,
	cleanup = 7.62,
	layers = {
		{
			name = "ChargeGlow",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			offset = {0, 0, -1},
			lifetime = {0.34, 0.34},
			size = {
				{0, 4, 0},
				{0.85, 24, 0},
				{1, 32, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.8, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 70, 86},
				},
				{
					0.7,
					{255, 150, 150},
				},
				{
					1,
					{255, 236, 232},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			zoffset = 2,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "ChargeIn",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			offset = {0, 0, -1},
			shape = {
				type = "Sphere",
				radius = 18,
				style = "Surface",
				inout = "Inward",
			},
			speed = {62, 82},
			lifetime = {0.2, 0.26},
			size = {
				{0, 0, 0},
				{0.3, 11, 2},
				{1, 3, 0},
			},
			color = {
				{
					0,
					{255, 236, 232},
				},
				{
					0.4,
					{255, 96, 104},
				},
				{
					1,
					{210, 22, 46},
				},
			},
			light_emission = 1,
			brightness = 2,
			stream = {
				{0, 0.27, 110, 150},
			},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeSparks",
			texture = "fx_spark4",
			offset = {0, 0, -1},
			shape = {
				type = "Sphere",
				radius = 14,
				style = "Surface",
				inout = "Inward",
			},
			speed = {45, 60},
			lifetime = {0.2, 0.26},
			size = {
				{0, 0, 0},
				{0.3, 3.2, 0.8},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 232},
				},
				{
					0.4,
					{255, 96, 104},
				},
				{
					1,
					{210, 22, 46},
				},
			},
			light_emission = 1,
			brightness = 2,
			rotation = {0, 360},
			stream = {
				{0, 0.27, 50, 70},
			},
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
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeRings",
			texture = "kz_beam_ring",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			offset = {0, 0, -1},
			speed = {0.5, 0.5},
			lifetime = {0.22, 0.22},
			size = {
				{0, 26, 0},
				{1, 3, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.35, 0.3, 0},
				{1, 0.15, 0},
			},
			color = {
				{
					0,
					{220, 24, 50},
				},
				{
					1,
					{255, 200, 200},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {0, 360},
			stream = {
				{0, 0.24, 14, 18},
			},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "MouthFlash",
			texture = "fx_glow",
			emit = {
				{0.3, 1},
			},
			offset = {0, 0, -2},
			lifetime = {0.3, 0.3},
			size = {
				{0, 18, 0},
				{0.25, 44, 0},
				{1, 48, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.5, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 236},
				},
				{
					0.25,
					{255, 120, 120},
				},
				{
					0.6,
					{235, 40, 62},
				},
				{
					1,
					{170, 14, 36},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 4,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "MouthBurst",
			texture = "fx_star",
			emit = {
				{0.3, 3},
			},
			offset = {0, 0, -2},
			lifetime = {0.18, 0.24},
			size = {
				{0, 24, 0},
				{0.3, 52, 0},
				{1, 36, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 236},
				},
				{
					0.25,
					{255, 120, 120},
				},
				{
					0.6,
					{235, 40, 62},
				},
				{
					1,
					{170, 14, 36},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			rotation = {0, 360},
			zoffset = 5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "MouthStar",
			texture = "fx_star",
			offset = {0, 0, -2},
			lifetime = {0.1, 0.16},
			size = {
				{0, 28, 6},
				{0.5, 38, 7},
				{1, 28, 6},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 236},
				},
				{
					0.25,
					{255, 120, 120},
				},
				{
					0.6,
					{235, 40, 62},
				},
				{
					1,
					{170, 14, 36},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			rotation = {0, 360},
			zoffset = 5,
			stream = {
				{0.3, 3.28, 16, 16},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "MouthStarCore",
			texture = "kk_star_06",
			offset = {0, 0, -2},
			lifetime = {0.08, 0.12},
			size = {
				{0, 14, 3},
				{0.5, 18, 3},
				{1, 14, 3},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 248, 244},
				},
				{
					0.5,
					{255, 140, 140},
				},
				{
					1,
					{230, 40, 60},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {0, 360},
			zoffset = 6,
			stream = {
				{0.3, 3.28, 12, 12},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "MouthGlow",
			texture = "fx_glow",
			offset = {0, 0, -2},
			lifetime = {0.15, 0.2},
			size = {
				{0, 26, 3},
				{1, 32, 3},
			},
			transparency = {
				{0, 0.55, 0},
				{1, 0.8, 0},
			},
			color = {
				{
					0,
					{230, 30, 55},
				},
				{
					1,
					{170, 10, 32},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 3,
			stream = {
				{0.3, 3.28, 12, 12},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "MouthRings",
			texture = "kz_beam_ring",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			offset = {0, 0, -2},
			speed = {14, 26},
			drag = 2,
			lifetime = {0.32, 0.46},
			size = {
				{0, 8, 0},
				{0.4, 26, 0},
				{1, 38, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.5, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 236},
				},
				{
					0.25,
					{255, 120, 120},
				},
				{
					0.6,
					{235, 40, 62},
				},
				{
					1,
					{170, 14, 36},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {0, 360},
			stream = {
				{0.32, 3.28, 8, 8},
			},
			spread = {0, 0},
			accel = {0, 0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "MouthSwirl",
			texture = "kk_twirl_01",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			offset = {0, 0, -3},
			speed = {3, 5},
			lifetime = {0.25, 0.35},
			size = {
				{0, 16, 0},
				{1, 30, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 92, 104},
				},
				{
					0.5,
					{225, 28, 52},
				},
				{
					1,
					{160, 10, 32},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {380, 560},
			stream = {
				{0.32, 3.28, 9, 9},
			},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "MouthSparks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Front",
			offset = {0, 0, -2},
			spread = {55, 55},
			speed = {70, 130},
			drag = 3,
			lifetime = {0.2, 0.35},
			size = {
				{0, 10, 2},
				{1, 3, 0},
			},
			color = {
				{
					0,
					{255, 236, 232},
				},
				{
					0.4,
					{255, 96, 104},
				},
				{
					1,
					{210, 22, 46},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			stream = {
				{0.32, 3.28, 50, 50},
			},
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "MouthSmoke",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			offset = {0, 2, -3},
			direction = "Top",
			spread = {40, 40},
			speed = {6, 12},
			drag = 1.5,
			accel = {0, 10, 0},
			lifetime = {0.9, 1.3},
			size = {
				{0, 6, 2},
				{1, 20, 4},
			},
			transparency = {
				{0, 1, 0},
				{0.15, 0.62, 0},
				{0.5, 0.72, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 52, 62},
				},
				{
					0.3,
					{175, 40, 52},
				},
				{
					0.7,
					{135, 40, 50},
				},
				{
					1,
					{112, 58, 64},
				},
			},
			light_emission = 0.1,
			brightness = 1.2,
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -3,
			stream = {
				{0.4, 3.28, 7, 7},
			},
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "BeamHead",
			texture = "fx_glow",
			line_u = 1,
			lifetime = {0.05, 0.07},
			size = {
				{0, 20, 0},
				{1, 24, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{1, 0.4, 0},
			},
			color = {
				{
					0,
					{255, 236, 232},
				},
				{
					1,
					{255, 120, 120},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			zoffset = 4,
			stream = {
				{0.3, 0.43, 70, 70},
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
			emit = {},
		},
		{
			name = "BeamHeadStar",
			texture = "kk_star_06",
			line_u = 1,
			lifetime = {0.05, 0.07},
			size = {
				{0, 24, 0},
				{1, 28, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0.3, 0},
			},
			color = {
				{
					0,
					{255, 240, 236},
				},
				{
					0.25,
					{255, 120, 120},
				},
				{
					0.6,
					{235, 40, 62},
				},
				{
					1,
					{170, 14, 36},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {0, 360},
			zoffset = 5,
			stream = {
				{0.3, 0.43, 40, 40},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			emit = {},
		},
		{
			name = "TravelRings",
			texture = "kz_beam_ring",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			offset = {0, 0, -3},
			speed_len = {1.7, 2.1},
			lifetime = {0.4, 0.45},
			size = {
				{0, 26, 0},
				{0.5, 30, 0},
				{1, 27, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.12, 0.3, 0},
				{0.75, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 170, 170},
				},
				{
					0.3,
					{250, 64, 80},
				},
				{
					1,
					{215, 24, 48},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			stream = {
				{0.42, 3.25, 9, 9},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "TravelRingsBig",
			texture = "kz_beam_ring",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			offset = {0, 0, -3},
			speed_len = {0.8, 1},
			lifetime = {0.85, 0.95},
			size = {
				{0, 34, 0},
				{0.5, 38, 0},
				{1, 35, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.12, 0.45, 0},
				{0.75, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 92, 104},
				},
				{
					0.5,
					{225, 28, 52},
				},
				{
					1,
					{160, 10, 32},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {0, 360},
			stream = {
				{0.42, 2.7, 3.5, 3.5},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "BeamEmbers",
			texture = "kk_flare_01",
			shape = {
				type = "Box",
				size = {7, 7, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.92,
			},
			direction = "Top",
			spread = {180, 180},
			speed = {6, 22},
			drag = 1,
			accel = {0, 12, 0},
			lifetime = {0.4, 0.8},
			size = {
				{0, 0, 0},
				{0.15, 2.4, 0.6},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 200, 196},
				},
				{
					0.4,
					{255, 70, 84},
				},
				{
					1,
					{190, 14, 38},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			stream = {
				{0.4, 3.28, 70, 70},
			},
			line_u = 0.5,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			emit = {},
		},
		{
			name = "BeamStreaks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {8, 8, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.76,
			},
			line_u = 0.42,
			direction = "Front",
			spread = {4, 4},
			speed_len = {1.6, 2.2},
			lifetime = {0.07, 0.1},
			size = {
				{0, 12, 3},
				{1, 7, 0},
			},
			color = {
				{
					0,
					{255, 236, 232},
				},
				{
					0.4,
					{255, 96, 104},
				},
				{
					1,
					{210, 22, 46},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			stream = {
				{0.4, 3.28, 45, 45},
			},
			speed = {0, 0},
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
			emit = {},
		},
		{
			name = "BeamLava",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Box",
				size = {6, 6, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.9,
			},
			direction = "Top",
			spread = {180, 180},
			speed = {4, 14},
			drag = 0.4,
			accel = {0, -90, 0},
			lifetime = {0.5, 0.8},
			size = {
				{0, 1, 0.3},
				{0.3, 2.1, 0.5},
				{1, 1.2, 0.3},
			},
			transparency = {
				{0, 0, 0},
				{0.75, 0.05, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 170, 160},
				},
				{
					0.25,
					{255, 70, 80},
				},
				{
					0.6,
					{205, 20, 44},
				},
				{
					1,
					{120, 12, 28},
				},
			},
			light_emission = 0.5,
			brightness = 1.6,
			rotation = {0, 360},
			rot_speed = {-200, 200},
			stream = {
				{0.45, 3.28, 22, 22},
			},
			line_u = 0.5,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			emit = {},
		},
		{
			name = "BeamSmoke",
			texture = "kk_smoke_08",
			shape = {
				type = "Box",
				size = {12, 12, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.9,
			},
			direction = "Top",
			spread = {60, 60},
			speed = {3, 8},
			drag = 1,
			accel = {0, 6, 0},
			lifetime = {0.8, 1.1},
			size = {
				{0, 8, 2},
				{1, 22, 4},
			},
			transparency = {
				{0, 1, 0},
				{0.15, 0.5, 0},
				{0.6, 0.62, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{190, 42, 52},
				},
				{
					0.4,
					{125, 34, 42},
				},
				{
					1,
					{86, 46, 50},
				},
			},
			light_emission = 0.1,
			brightness = 1.2,
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -6,
			stream = {
				{0.45, 3.28, 14, 14},
			},
			line_u = 0.5,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			emit = {},
		},
		{
			name = "ImpactFlash",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			on_hit = true,
			lifetime = {0.3, 0.3},
			size = {
				{0, 20, 0},
				{0.25, 60, 0},
				{1, 66, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.5, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 236},
				},
				{
					0.25,
					{255, 120, 120},
				},
				{
					0.6,
					{235, 40, 62},
				},
				{
					1,
					{170, 14, 36},
				},
			},
			light_emission = 1,
			brightness = 1.1,
			zoffset = 4,
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
		},
		{
			name = "ImpactBurst",
			texture = "fx_burst_a",
			emit = {
				{0, 2},
			},
			on_hit = true,
			lifetime = {0.2, 0.24},
			size = {
				{0, 16, 0},
				{0.4, 50, 0},
				{1, 56, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 230},
				},
				{
					0.2,
					{255, 116, 116},
				},
				{
					0.55,
					{228, 32, 56},
				},
				{
					1,
					{120, 10, 26},
				},
			},
			light_emission = 0.6,
			brightness = 1.6,
			rotation = {0, 360},
			zoffset = 3,
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
		},
		{
			name = "ImpactShock",
			texture = "kz_beam_ring",
			orientation = "VelocityPerpendicular",
			direction = "Back",
			emit = {
				{0, 2},
			},
			on_hit = true,
			speed = {0.5, 0.5},
			lifetime = {0.32, 0.4},
			size = {
				{0, 12, 0},
				{1, 80, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 236},
				},
				{
					0.25,
					{255, 120, 120},
				},
				{
					0.6,
					{235, 40, 62},
				},
				{
					1,
					{170, 14, 36},
				},
			},
			light_emission = 1,
			brightness = 1.7,
			rotation = {0, 360},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
		},
		{
			name = "ImpactRings",
			texture = "kz_beam_ring",
			orientation = "VelocityPerpendicular",
			direction = "Back",
			speed = {6, 14},
			lifetime = {0.3, 0.4},
			size = {
				{0, 10, 0},
				{1, 46, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.5, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 236},
				},
				{
					0.25,
					{255, 120, 120},
				},
				{
					0.6,
					{235, 40, 62},
				},
				{
					1,
					{170, 14, 36},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {0, 360},
			stream = {
				{0.42, 3.28, 7, 7},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			emit = {},
		},
		{
			name = "ImpactStar",
			texture = "fx_star",
			lifetime = {0.08, 0.14},
			size = {
				{0, 32, 6},
				{0.5, 42, 8},
				{1, 30, 6},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 236},
				},
				{
					0.25,
					{255, 120, 120},
				},
				{
					0.6,
					{235, 40, 62},
				},
				{
					1,
					{170, 14, 36},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {0, 360},
			zoffset = 4,
			stream = {
				{0.4, 3.28, 15, 15},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			emit = {},
		},
		{
			name = "ImpactGlow",
			texture = "fx_glow",
			lifetime = {0.15, 0.22},
			size = {
				{0, 36, 4},
				{1, 42, 4},
			},
			transparency = {
				{0, 0.55, 0},
				{1, 0.8, 0},
			},
			color = {
				{
					0,
					{230, 30, 55},
				},
				{
					1,
					{170, 10, 32},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 2,
			stream = {
				{0.4, 3.28, 10, 10},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			emit = {},
		},
		{
			name = "ImpactFire",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Back",
			spread = {75, 75},
			speed = {12, 30},
			drag = 2.5,
			accel = {0, 14, 0},
			lifetime = {0.3, 0.5},
			size = {
				{0, 8, 2},
				{0.4, 18, 3},
				{1, 22, 3},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 230},
				},
				{
					0.2,
					{255, 116, 116},
				},
				{
					0.55,
					{228, 32, 56},
				},
				{
					1,
					{120, 10, 26},
				},
			},
			light_emission = 0.35,
			brightness = 1.6,
			rotation = {0, 360},
			rot_speed = {-90, 90},
			stream = {
				{0.4, 3.28, 26, 26},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			zoffset = 0,
			orientation = "FacingCamera",
			emit = {},
		},
		{
			name = "ImpactSpray",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Back",
			spread = {80, 80},
			speed = {90, 170},
			drag = 3.5,
			accel = {0, -70, 0},
			lifetime = {0.25, 0.45},
			size = {
				{0, 12, 3},
				{1, 4, 0},
			},
			color = {
				{
					0,
					{255, 236, 232},
				},
				{
					0.4,
					{255, 96, 104},
				},
				{
					1,
					{210, 22, 46},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			emit = {
				{0, 40},
			},
			on_hit = true,
			stream = {
				{0.4, 3.28, 75, 75},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
		},
		{
			name = "ImpactLava",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Back",
			spread = {70, 70},
			speed = {35, 75},
			drag = 0.5,
			accel = {0, -130, 0},
			lifetime = {0.6, 0.9},
			size = {
				{0, 1.6, 0.4},
				{0.3, 3, 0.6},
				{1, 2, 0.4},
			},
			transparency = {
				{0, 0, 0},
				{0.75, 0.05, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 170, 160},
				},
				{
					0.25,
					{255, 70, 80},
				},
				{
					0.6,
					{205, 20, 44},
				},
				{
					1,
					{120, 12, 28},
				},
			},
			light_emission = 0.45,
			brightness = 1.6,
			rotation = {0, 360},
			rot_speed = {-220, 220},
			emit = {
				{0, 20},
			},
			on_hit = true,
			stream = {
				{0.4, 3.28, 30, 30},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			zoffset = 0,
			orientation = "FacingCamera",
		},
		{
			name = "ImpactDebris",
			texture = "kz_lava_rock_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Back",
			spread = {70, 70},
			speed = {40, 90},
			drag = 0.3,
			accel = {0, -130, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 2.2, 0.8},
				{1, 1.9, 0.7},
			},
			color = {
				{
					0,
					{255, 140, 130},
				},
				{
					1,
					{240, 100, 96},
				},
			},
			light_emission = 0.1,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-360, 360},
			emit = {
				{0, 16},
			},
			on_hit = true,
			stream = {
				{0.4, 3.28, 18, 18},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			zoffset = 0,
			orientation = "FacingCamera",
		},
		{
			name = "ImpactSmoke",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {35, 35},
			speed = {10, 20},
			drag = 1.2,
			accel = {0, 10, 0},
			lifetime = {1, 1.5},
			size = {
				{0, 10, 3},
				{1, 30, 5},
			},
			transparency = {
				{0, 0.6, 0},
				{0.15, 0.32, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 52, 62},
				},
				{
					0.3,
					{175, 40, 52},
				},
				{
					0.7,
					{135, 40, 50},
				},
				{
					1,
					{112, 58, 64},
				},
			},
			light_emission = 0.1,
			brightness = 1.2,
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -5,
			stream = {
				{0.45, 3.28, 9, 9},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			orientation = "FacingCamera",
			emit = {},
		},
		{
			name = "ImpactSplash",
			texture = "kk_muzzle_01",
			orientation = "VelocityParallel",
			direction = "Back",
			spread = {85, 85},
			speed = {40, 70},
			drag = 4,
			lifetime = {0.16, 0.26},
			size = {
				{0, 6, 2},
				{0.3, 18, 4},
				{1, 14, 3},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 230},
				},
				{
					0.2,
					{255, 116, 116},
				},
				{
					0.55,
					{228, 32, 56},
				},
				{
					1,
					{120, 10, 26},
				},
			},
			light_emission = 0.5,
			brightness = 1.6,
			stream = {
				{0.4, 3.28, 34, 34},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			emit = {},
		},
		{
			name = "ImpactRocks",
			type = "meteor",
			emit = {
				{0.42, 4},
				{1.3, 2},
				{2, 2},
			},
			direction = "Back",
			spread = {55, 55},
			speed = {55, 95},
			accel = {0, -130, 0},
			drag = 0.2,
			lifetime = {1, 1.3},
			trails = {
				{
					name = "RockGlow",
					rate = 60,
					locked = true,
					texture = "fx_glow",
					speed = {0, 0},
					direction = "Top",
					lifetime = {0.075, 0.075},
					size = {
						{0, 6.5, 0.8},
						{1, 6.5, 0.8},
					},
					color = {
						{
							0,
							{255, 30, 50},
						},
						{
							1,
							{255, 30, 50},
						},
					},
					transparency = {
						{0, 0.9, 0},
						{1, 0.9, 0},
					},
					light_emission = 1,
					brightness = 1,
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
					name = "RockEmbers",
					rate = 30,
					texture = "kk_flare_01",
					speed = {0, 3},
					direction = "Top",
					spread = {180, 180},
					lifetime = {0.25, 0.45},
					size = {
						{0, 0, 0},
						{0.15, 2.4, 0.6},
						{1, 0, 0},
					},
					color = {
						{
							0,
							{255, 200, 196},
						},
						{
							0.4,
							{255, 70, 84},
						},
						{
							1,
							{190, 14, 38},
						},
					},
					light_emission = 1,
					brightness = 1.7,
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
					name = "RockSmoke",
					rate = 22,
					texture = "kk_smoke_04",
					speed = {1, 4},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					accel = {0, 6, 0},
					lifetime = {0.5, 0.8},
					size = {
						{0, 3, 0.8},
						{1, 9, 2},
					},
					transparency = {
						{0, 0.4, 0},
						{0.6, 0.6, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 52, 62},
						},
						{
							0.3,
							{175, 40, 52},
						},
						{
							0.7,
							{135, 40, 50},
						},
						{
							1,
							{112, 58, 64},
						},
					},
					rotation = {0, 360},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
			},
			land = {
				{
					name = "RockSplat",
					texture = "kz_lava_splat",
					emit = {
						{0, 1},
					},
					lifetime = {1.4, 1.4},
					size = {
						{0, 2, 0},
						{0.05, 7, 0},
						{1, 7.5, 0},
					},
					transparency = {
						{0, 0.1, 0},
						{0.75, 0.3, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{230, 60, 70},
						},
						{
							0.3,
							{170, 20, 40},
						},
						{
							1,
							{70, 12, 20},
						},
					},
					light_emission = 0.5,
					rotation = {0, 360},
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
				},
				{
					name = "RockWisp",
					texture = "kk_smoke_04",
					direction = "Top",
					spread = {15, 15},
					speed = {4, 9},
					drag = 1.2,
					accel = {0, 5, 0},
					lifetime = {0.7, 1},
					size = {
						{0, 2, 0.6},
						{1, 7, 2},
					},
					transparency = {
						{0, 0.6, 0},
						{0.3, 0.5, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 52, 62},
						},
						{
							0.3,
							{175, 40, 52},
						},
						{
							0.7,
							{135, 40, 50},
						},
						{
							1,
							{112, 58, 64},
						},
					},
					rotation = {0, 360},
					stream = {
						{0.05, 0.7, 3, 0.5},
					},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
					emit = {},
				},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			rock = {
				size = {2.6, 4.2},
				spin = {-480, 480},
				material = "CrackedLava",
				color = {140, 34, 38},
			},
		},
		{
			name = "CutPuff",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{3.32, 8},
			},
			direction = "Back",
			spread = {70, 70},
			speed = {14, 30},
			drag = 2,
			accel = {0, 10, 0},
			lifetime = {0.9, 1.3},
			size = {
				{0, 8, 2},
				{1, 26, 5},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 52, 62},
				},
				{
					0.3,
					{175, 40, 52},
				},
				{
					0.7,
					{135, 40, 50},
				},
				{
					1,
					{112, 58, 64},
				},
			},
			light_emission = 0.1,
			brightness = 1.2,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -4,
			line_u = 1,
			offset = {0, 0, 3},
			orientation = "FacingCamera",
		},
		{
			name = "CutEmbers",
			texture = "kk_flare_01",
			emit = {
				{3.32, 40},
			},
			direction = "Back",
			spread = {90, 90},
			speed = {20, 60},
			drag = 2,
			accel = {0, 10, 0},
			lifetime = {0.5, 1},
			size = {
				{0, 0, 0},
				{0.15, 2.6, 0.6},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 200, 196},
				},
				{
					0.4,
					{255, 70, 84},
				},
				{
					1,
					{190, 14, 38},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			line_u = 1,
			offset = {0, 0, 3},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
		},
		{
			name = "GroundScorch",
			texture = "kz_scorch",
			emit = {
				{0.02, 1},
			},
			on_hit = true,
			at_ground = true,
			offset = {0, 0.14, 0},
			lifetime = {4, 4},
			size = {
				{0, 8, 0},
				{0.05, 40, 0},
				{1, 44, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.25, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 255, 255},
				},
			},
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "GroundCracks",
			texture = "kz_lava_cracks",
			emit = {
				{0.05, 1},
			},
			on_hit = true,
			at_ground = true,
			offset = {0, 0.18, 0},
			lifetime = {3.9, 3.9},
			size = {
				{0, 10, 0},
				{0.06, 46, 0},
				{1, 50, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.7, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 120, 120},
				},
				{
					0.1,
					{240, 40, 62},
				},
				{
					0.6,
					{190, 18, 40},
				},
				{
					1,
					{90, 10, 22},
				},
			},
			light_emission = 1,
			rotation = {0, 360},
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
			line_u = 0,
		},
		{
			name = "GroundDust",
			texture = "kk_smoke_07",
			emit = {
				{0.02, 22},
			},
			on_hit = true,
			at_ground = true,
			offset = {0, 2, 0},
			direction = "Front",
			spread = {180, 3},
			speed = {60, 100},
			drag = 3.5,
			accel = {0, 4, 0},
			lifetime = {0.9, 1.3},
			size = {
				{0, 8, 2},
				{0.3, 18, 3},
				{1, 24, 4},
			},
			transparency = {
				{0, 0.5, 0},
				{0.2, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{150, 50, 50},
				},
				{
					0.4,
					{122, 60, 60},
				},
				{
					1,
					{105, 80, 80},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -3,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "GroundFire",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			at_ground = true,
			offset = {0, 0.5, 0},
			shape = {
				type = "Box",
				size = {16, 0.5, 16},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {10, 10},
			speed = {4, 9},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 2, 0.5},
				{0.3, 6, 1},
				{1, 4, 0.8},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 230},
				},
				{
					0.2,
					{255, 116, 116},
				},
				{
					0.55,
					{228, 32, 56},
				},
				{
					1,
					{120, 10, 26},
				},
			},
			light_emission = 0.4,
			brightness = 1.6,
			stream = {
				{0.5, 3.28, 12, 12},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundEmbers",
			texture = "kk_flare_01",
			at_ground = true,
			offset = {0, 1, 0},
			shape = {
				type = "Box",
				size = {18, 1, 18},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {6, 16},
			accel = {0, 10, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.15, 2.2, 0.6},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 200, 196},
				},
				{
					0.4,
					{255, 70, 84},
				},
				{
					1,
					{190, 14, 38},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			stream = {
				{0.5, 3.28, 16, 16},
			},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "TrailScorch",
			texture = "kz_scorch",
			trail = true,
			at_ground = true,
			offset = {0, 0.12, 0},
			lifetime = {2.4, 2.4},
			size = {
				{0, 6, 0},
				{0.08, 17, 0},
				{1, 18, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.75, 0.3, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 255, 255},
				},
			},
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "TrailCracks",
			texture = "kz_lava_cracks",
			trail = true,
			at_ground = true,
			offset = {0, 0.16, 0},
			lifetime = {2, 2},
			size = {
				{0, 6, 0},
				{0.1, 15, 0},
				{1, 16, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.6, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 120, 120},
				},
				{
					0.15,
					{240, 40, 62},
				},
				{
					0.6,
					{180, 16, 38},
				},
				{
					1,
					{80, 10, 20},
				},
			},
			light_emission = 1,
			rotation = {0, 360},
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
			line_u = 0,
			emit = {},
		},
	},
	shakes = {
		{0.4, 1, 0.6},
		{3.3, 0.5, 0.4},
	},
	shake_ramp = {0.3, 3.3, 0.3, 0.55, 1},
	beam = {
		start = 0.3,
		grow = 0.1,
		stop = 3.3,
		fade = 0.3,
		max_len = 186,
		trail_every = 0.1,
		trail_move = 4,
		rehit = 0.3,
		light_color = {255, 40, 62},
		light_brightness = 5,
		light_range = 50,
	},
	beams = {
		{
			name = "Glow",
			texture = "kz_beam_glow",
			mode = "Wrap",
			tex_len = 60,
			speed = 0.4,
			light_emission = 1,
			brightness = 0.8,
			color = {
				{
					0,
					{200, 10, 34},
				},
				{
					1,
					{180, 8, 30},
				},
			},
			transparency = {
				{0, 0.84},
				{0.03, 0.76},
				{1, 0.78},
			},
			width = 42,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.3, 0},
				{0.33, 1.35},
				{0.45, 1},
				{3.25, 1},
				{3.3, 0.85},
				{3.6, 0},
			},
			alpha_t = {
				{0, 0},
				{3.3, 0},
				{3.6, 1},
			},
			pulse = 0.1,
			pulse_hz = 5,
			zoffset = 0,
		},
		{
			name = "Wisps",
			texture = "kz_beam_flow",
			mode = "Wrap",
			tex_len = 48,
			speed = 2.4,
			light_emission = 0.15,
			brightness = 1.4,
			color = {
				{
					0,
					{205, 14, 36},
				},
				{
					1,
					{190, 10, 32},
				},
			},
			transparency = {
				{0, 0.8},
				{0.05, 0.52},
				{1, 0.56},
			},
			width = 30,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.3, 0},
				{0.33, 1.35},
				{0.45, 1},
				{3.25, 1},
				{3.3, 0.85},
				{3.6, 0},
			},
			alpha_t = {
				{0, 0},
				{3.3, 0},
				{3.6, 1},
			},
			pulse = 0.1,
			pulse_hz = 6,
			zoffset = 0.05,
		},
		{
			name = "Sheath",
			texture = "kz_beam_flow",
			mode = "Wrap",
			tex_len = 36,
			speed = 1.6,
			light_emission = 0.06,
			brightness = 1.5,
			color = {
				{
					0,
					{190, 8, 28},
				},
				{
					1,
					{175, 6, 26},
				},
			},
			transparency = {
				{0, 0.4},
				{0.04, 0.04},
				{1, 0.06},
			},
			width = 22,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.3, 0},
				{0.33, 1.35},
				{0.45, 1},
				{3.25, 1},
				{3.3, 0.85},
				{3.6, 0},
			},
			alpha_t = {
				{0, 0},
				{3.3, 0},
				{3.6, 1},
			},
			pulse = 0.07,
			pulse_hz = 7,
			zoffset = 0.1,
		},
		{
			name = "Inner",
			texture = "kz_beam_flow",
			mode = "Wrap",
			tex_len = 24,
			speed = 2.6,
			light_emission = 0.45,
			brightness = 1.8,
			color = {
				{
					0,
					{255, 52, 70},
				},
				{
					1,
					{245, 40, 60},
				},
			},
			transparency = {
				{0, 0.35},
				{0.04, 0},
				{1, 0.05},
			},
			width = 12,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.3, 0},
				{0.33, 1.35},
				{0.45, 1},
				{3.25, 1},
				{3.3, 0.85},
				{3.6, 0},
			},
			alpha_t = {
				{0, 0},
				{3.3, 0},
				{3.6, 1},
			},
			pulse = 0.09,
			pulse_hz = 11,
			zoffset = 0.2,
		},
		{
			name = "Core",
			texture = "kz_beam_core",
			mode = "Wrap",
			tex_len = 18,
			speed = 3.5,
			light_emission = 1,
			brightness = 2.4,
			color = {
				{
					0,
					{255, 248, 244},
				},
				{
					1,
					{255, 236, 232},
				},
			},
			transparency = {
				{0, 0.2},
				{0.03, 0},
				{1, 0},
			},
			width = 6.5,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.3, 0},
				{0.33, 1.35},
				{0.45, 1},
				{3.25, 1},
				{3.3, 0.85},
				{3.6, 0},
			},
			alpha_t = {
				{0, 0},
				{3.3, 0},
				{3.6, 1},
			},
			pulse = 0.12,
			pulse_hz = 17,
			zoffset = 0.3,
		},
	},
}

-- ULTIMATE de Kaiju Zero: la boca junta energía 0.3 s y suelta un RAYO CARMESÍ de 3 s con el núcleo al rojo blanco y vetas de lava, con aros, brasas y humo rojo. Se puede apuntar mientras dura: pega en la primera superficie (hasta 186 studs × escala) con destellos, chispas, lava y rocas fundidas, y el suelo debajo se quema y se agrieta (deja una estela si lo barre). Cierra limpio.
-- origin = de dónde sale: un Attachment en la boca (lo sigue solo), una Part, un Vector3 o un CFrame.
-- target = hacia dónde apunta: el rival (Model o Part: lo sigue solo) o un punto (Vector3 o CFrame).
-- ignore = lo que el rayo atraviesa (el modelo de quien lo lanza). Se corta en la primera superficie
-- que toca y nunca pasa de su largo máximo (186 studs × escala). Devuelve un control:
--   rayo:AimAt(objetivo)     apunta a otro lado (Model, Part, Vector3 o CFrame; si se mueve, lo sigue)
--   rayo:SetDirection(dir)   apunta en una dirección (Vector3)
--   rayo:SetOrigin(origen)   cambia de dónde sale
--   rayo:Stop()              lo corta antes de tiempo
--   rayo.MaxLength           largo máximo (lo puedes cambiar); rayo.Length = largo de ahora
--   rayo.HitPosition, rayo.HitInstance = dónde y qué está tocando (nil si no toca nada)
--   rayo.Active = true mientras se ve; rayo.Holder = la Part que lo contiene
function KaijuFireVFX.UltimateBeam(origin: any, target: any, scale: number?, shake: number?, ignore: { Instance }?): BeamControl
	return playBeam(SPEC_UltimateBeam, origin, target, scale, shake, ignore)
end
-- segundos (desde la llamada) en que llega a su largo máximo y en que se corta solo
KaijuFireVFX.UltimateBeamStart = 0.4
KaijuFireVFX.UltimateBeamStop = 3.3

local SPEC_SlashHit = {
	name = "SlashHit",
	duration = 0.6,
	cleanup = 1.05,
	layers = {
		{
			name = "ClawMarks",
			texture = "kz_claw_4x4",
			flipbook = {
				layout = "Grid4x4",
				mode = "OneShot",
				fps = 30,
				startRandom = false,
			},
			orientation = "VelocityParallel",
			direction = "Bottom",
			speed = {4, 4},
			emit = {
				{0, 1},
			},
			lifetime = {0.28, 0.28},
			size = {
				{0, 27, 0},
				{1, 28, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.7, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.6,
					{255, 240, 220},
				},
				{
					1,
					{255, 205, 160},
				},
			},
			light_emission = 0.55,
			brightness = 1.15,
			zoffset = 5,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "ClawGlow",
			texture = "kz_claw_glow",
			orientation = "VelocityParallel",
			direction = "Bottom",
			speed = {4, 4},
			emit = {
				{0.03, 1},
			},
			lifetime = {0.32, 0.32},
			size = {
				{0, 29, 0},
				{1, 31, 0},
			},
			transparency = {
				{0, 0.62, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 230, 200},
				},
				{
					1,
					{255, 180, 120},
				},
			},
			light_emission = 1,
			brightness = 0.45,
			zoffset = 4,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "HitFlash",
			texture = "fx_glow",
			emit = {
				{0.05, 1},
			},
			lifetime = {0.16, 0.18},
			size = {
				{0, 6, 0},
				{0.3, 20, 0},
				{1, 22, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 246, 236},
				},
			},
			light_emission = 1,
			brightness = 0.9,
			zoffset = 6,
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
		},
		{
			name = "HitStar",
			texture = "kk_star_06",
			emit = {
				{0.05, 1},
			},
			lifetime = {0.14, 0.14},
			size = {
				{0, 10, 0},
				{0.4, 19, 0},
				{1, 12, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 252, 244},
				},
				{
					0.5,
					{255, 226, 186},
				},
				{
					1,
					{255, 180, 110},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			zoffset = 7,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "HitRing",
			texture = "kz_beam_ring",
			emit = {
				{0.05, 1},
			},
			lifetime = {0.22, 0.24},
			size = {
				{0, 6, 0},
				{1, 34, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 246, 236},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {0, 360},
			zoffset = 3,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "SparksRight",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {14, 22, 1},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Right",
			spread = {25, 35},
			speed = {70, 140},
			drag = 5,
			accel = {0, -40, 0},
			lifetime = {0.16, 0.3},
			emit = {
				{0.04, 16},
				{0.07, 8},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{255, 252, 244},
				},
				{
					0.5,
					{255, 226, 186},
				},
				{
					1,
					{255, 180, 110},
				},
			},
			light_emission = 1,
			brightness = 2,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "SparksLeft",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {14, 22, 1},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Left",
			spread = {25, 35},
			speed = {70, 140},
			drag = 5,
			accel = {0, -40, 0},
			lifetime = {0.16, 0.3},
			emit = {
				{0.04, 16},
				{0.07, 8},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{255, 252, 244},
				},
				{
					0.5,
					{255, 226, 186},
				},
				{
					1,
					{255, 180, 110},
				},
			},
			light_emission = 1,
			brightness = 2,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "ClawShards",
			texture = "fx_spark4",
			shape = {
				type = "Box",
				size = {14, 24, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.05, 16},
			},
			direction = "Back",
			spread = {60, 60},
			speed = {8, 20},
			drag = 2,
			lifetime = {0.2, 0.35},
			size = {
				{0, 0, 0},
				{0.2, 2.2, 0.6},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 252, 244},
				},
				{
					0.5,
					{255, 226, 186},
				},
				{
					1,
					{255, 180, 110},
				},
			},
			light_emission = 1,
			brightness = 2,
			rotation = {0, 360},
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Chips",
			texture = "kz_debris_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0.05, 8},
			},
			direction = "Back",
			spread = {55, 55},
			speed = {25, 50},
			drag = 0.5,
			accel = {0, -90, 0},
			lifetime = {0.45, 0.7},
			size = {
				{0, 1, 0.3},
				{1, 0.9, 0.3},
			},
			color = {
				{
					0,
					{150, 120, 100},
				},
				{
					1,
					{100, 88, 80},
				},
			},
			light_emission = 0.05,
			rotation = {0, 360},
			rot_speed = {-400, 400},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "DustPuff",
			texture = "kk_smoke_04",
			emit = {
				{0.06, 3},
			},
			direction = "Back",
			spread = {60, 60},
			speed = {4, 10},
			drag = 2,
			accel = {0, 4, 0},
			lifetime = {0.45, 0.6},
			size = {
				{0, 4, 1},
				{1, 11, 2},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{170, 160, 150},
				},
				{
					1,
					{130, 124, 120},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -2,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
	},
	shakes = {
		{0.05, 0.45, 0.22},
	},
	light = {
		color = {255, 236, 210},
		brightness = 3,
		range = 22,
		time = 0.25,
		delay = 0.05,
	},
	hit = {
		lift = 3,
		ref = 22,
		angle = 35,
		angled = true,
		impact = 0.05,
	},
}

-- CORTE: el rival recibe un zarpazo de garra (tres marcas rasgadas) que se desgarra en diagonal, con chispas, destello y anillo.
-- target = el rival (Model, Part, Vector3 o CFrame). El golpe sale delante de lo que ve la cámara y mira
-- hacia ella. Con un Model o una Part se adapta al alto del rival (22 studs = tamaño 1; scale lo multiplica).
-- angle = inclinación del corte en grados (por defecto 35: en diagonal, de arriba a la izquierda
-- a abajo a la derecha). 0 = vertical, -35 = la otra diagonal (de arriba a la derecha a abajo a la
-- izquierda), 90 = horizontal.
function KaijuFireVFX.SlashHit(target: any, scale: number?, shake: number?, angle: number?): Part
	return playHit(SPEC_SlashHit, target, scale, shake, angle)
end
-- segundo (desde la llamada) en que el golpe conecta: para sincronizar el número de daño o el sonido
KaijuFireVFX.SlashHitImpact = 0.05

local SPEC_BurningSlashHit = {
	name = "BurningSlashHit",
	duration = 1,
	cleanup = 2.2,
	layers = {
		{
			name = "ClawMarks",
			texture = "kz_claw_4x4",
			flipbook = {
				layout = "Grid4x4",
				mode = "OneShot",
				fps = 30,
				startRandom = false,
			},
			orientation = "VelocityParallel",
			direction = "Bottom",
			speed = {4, 4},
			emit = {
				{0, 1},
			},
			lifetime = {0.28, 0.28},
			size = {
				{0, 27, 0},
				{1, 28, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.7, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 240},
				},
				{
					0.3,
					{255, 212, 120},
				},
				{
					0.65,
					{255, 140, 45},
				},
				{
					1,
					{220, 70, 20},
				},
			},
			light_emission = 0.55,
			brightness = 1.2,
			zoffset = 5,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "ClawGlow",
			texture = "kz_claw_glow",
			orientation = "VelocityParallel",
			direction = "Bottom",
			speed = {4, 4},
			emit = {
				{0.03, 1},
			},
			lifetime = {0.45, 0.45},
			size = {
				{0, 29, 0},
				{1, 31, 0},
			},
			transparency = {
				{0, 0.62, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 160, 60},
				},
				{
					1,
					{255, 100, 30},
				},
			},
			light_emission = 1,
			brightness = 0.45,
			zoffset = 4,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "BurnScar",
			texture = "kz_claw",
			orientation = "VelocityParallel",
			direction = "Bottom",
			speed = {0.5, 0.5},
			emit = {
				{0.11, 1},
			},
			lifetime = {0.9, 0.9},
			size = {
				{0, 27.5, 0},
				{1, 27.5, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 226, 150},
				},
				{
					0.2,
					{255, 146, 50},
				},
				{
					0.6,
					{215, 64, 20},
				},
				{
					1,
					{90, 26, 12},
				},
			},
			light_emission = 0.85,
			brightness = 1.6,
			zoffset = 4.5,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "ScarGlow",
			texture = "kz_claw_glow",
			orientation = "VelocityParallel",
			direction = "Bottom",
			speed = {0.5, 0.5},
			emit = {
				{0.11, 1},
			},
			lifetime = {0.8, 0.8},
			size = {
				{0, 30, 0},
				{1, 31, 0},
			},
			transparency = {
				{0, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 120, 35},
				},
				{
					1,
					{200, 50, 15},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 4,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FireLicks",
			texture = "kk_muzzle_04",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {14, 24, 1.5},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {35, 35},
			speed = {4, 10},
			drag = 1.5,
			accel = {0, 35, 0},
			lifetime = {0.3, 0.5},
			size = {
				{0, 2, 0.5},
				{0.3, 6, 1.2},
				{1, 3.5, 0.8},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.25, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 236, 150},
				},
				{
					0.3,
					{255, 166, 50},
				},
				{
					0.7,
					{240, 90, 20},
				},
				{
					1,
					{160, 40, 12},
				},
			},
			light_emission = 0.4,
			brightness = 1.6,
			stream = {
				{0.06, 0.75, 45, 10},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "FireBurst",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Box",
				size = {14, 22, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.05, 14},
			},
			direction = "Back",
			spread = {60, 60},
			speed = {10, 26},
			drag = 3,
			accel = {0, 12, 0},
			lifetime = {0.3, 0.45},
			size = {
				{0, 4, 1},
				{0.4, 9, 2},
				{1, 10, 2},
			},
			transparency = {
				{0, 0.05, 0},
				{0.6, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 220, 140},
				},
				{
					0.15,
					{255, 170, 60},
				},
				{
					0.4,
					{250, 120, 30},
				},
				{
					0.75,
					{225, 70, 15},
				},
				{
					1,
					{190, 50, 12},
				},
			},
			light_emission = 0.3,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-90, 90},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "LavaDrops",
			texture = "kz_lava_glob_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Box",
				size = {14, 22, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.06, 12},
			},
			direction = "Back",
			spread = {60, 60},
			speed = {8, 20},
			drag = 0.4,
			accel = {0, -110, 0},
			lifetime = {0.4, 0.7},
			size = {
				{0, 0.8, 0.2},
				{0.3, 1.6, 0.4},
				{1, 1, 0.3},
			},
			transparency = {
				{0, 0, 0},
				{0.75, 0.05, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 214, 120},
				},
				{
					0.2,
					{255, 150, 40},
				},
				{
					0.55,
					{240, 90, 18},
				},
				{
					1,
					{185, 44, 12},
				},
			},
			light_emission = 0.5,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-220, 220},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Embers",
			texture = "kk_flare_01",
			shape = {
				type = "Box",
				size = {16, 24, 2},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {60, 60},
			speed = {4, 14},
			accel = {0, 14, 0},
			lifetime = {0.5, 0.9},
			size = {
				{0, 0, 0},
				{0.15, 1.8, 0.5},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 225, 130},
				},
				{
					0.5,
					{255, 140, 40},
				},
				{
					1,
					{220, 60, 15},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			emit = {
				{0.05, 20},
			},
			stream = {
				{0.06, 0.9, 40, 10},
			},
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
		},
		{
			name = "BurnSmoke",
			texture = "kk_smoke_04",
			shape = {
				type = "Box",
				size = {12, 22, 1},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {4, 9},
			drag = 1,
			accel = {0, 8, 0},
			lifetime = {0.7, 1},
			size = {
				{0, 3, 1},
				{1, 10, 2},
			},
			transparency = {
				{0, 0.7, 0},
				{0.3, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 130, 50},
				},
				{
					0.06,
					{130, 74, 50},
				},
				{
					0.2,
					{78, 64, 58},
				},
				{
					0.6,
					{92, 84, 80},
				},
				{
					1,
					{112, 106, 102},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			stream = {
				{0.15, 0.9, 12, 4},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "HitFlash",
			texture = "fx_glow",
			emit = {
				{0.05, 1},
			},
			lifetime = {0.16, 0.18},
			size = {
				{0, 6, 0},
				{0.3, 24, 0},
				{1, 26.4, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 200},
				},
				{
					1,
					{255, 140, 50},
				},
			},
			light_emission = 1,
			brightness = 0.9,
			zoffset = 6,
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
		},
		{
			name = "HitStar",
			texture = "kk_star_06",
			emit = {
				{0.05, 1},
			},
			lifetime = {0.14, 0.14},
			size = {
				{0, 10, 0},
				{0.4, 22.8, 0},
				{1, 14.4, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 240},
				},
				{
					0.3,
					{255, 212, 120},
				},
				{
					0.65,
					{255, 140, 45},
				},
				{
					1,
					{220, 70, 20},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			zoffset = 7,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "HitRing",
			texture = "kz_beam_ring",
			emit = {
				{0.05, 1},
			},
			lifetime = {0.22, 0.24},
			size = {
				{0, 6, 0},
				{1, 34, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 240, 200},
				},
				{
					1,
					{255, 140, 50},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {0, 360},
			zoffset = 3,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "SparksRight",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {14, 22, 1},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Right",
			spread = {25, 35},
			speed = {70, 140},
			drag = 5,
			accel = {0, -40, 0},
			lifetime = {0.16, 0.3},
			emit = {
				{0.04, 16},
				{0.07, 8},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.5,
					{255, 170, 60},
				},
				{
					1,
					{240, 90, 20},
				},
			},
			light_emission = 1,
			brightness = 2,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "SparksLeft",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {14, 22, 1},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Left",
			spread = {25, 35},
			speed = {70, 140},
			drag = 5,
			accel = {0, -40, 0},
			lifetime = {0.16, 0.3},
			emit = {
				{0.04, 16},
				{0.07, 8},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{255, 240, 180},
				},
				{
					0.5,
					{255, 170, 60},
				},
				{
					1,
					{240, 90, 20},
				},
			},
			light_emission = 1,
			brightness = 2,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
	},
	shakes = {
		{0.05, 0.55, 0.25},
	},
	light = {
		color = {255, 140, 50},
		brightness = 5,
		range = 26,
		time = 0.6,
		delay = 0.05,
	},
	hit = {
		lift = 3,
		ref = 22,
		angle = 35,
		angled = true,
		impact = 0.05,
	},
}

-- CORTE QUEMADO: el zarpazo sale al rojo vivo y sus marcas quedan encendidas ardiendo un momento, con llamas, brasas, gotas de lava y humo.
-- target = el rival (Model, Part, Vector3 o CFrame). El golpe sale delante de lo que ve la cámara y mira
-- hacia ella. Con un Model o una Part se adapta al alto del rival (22 studs = tamaño 1; scale lo multiplica).
-- angle = inclinación del corte en grados (por defecto 35: en diagonal, de arriba a la izquierda
-- a abajo a la derecha). 0 = vertical, -35 = la otra diagonal (de arriba a la derecha a abajo a la
-- izquierda), 90 = horizontal.
function KaijuFireVFX.BurningSlashHit(target: any, scale: number?, shake: number?, angle: number?): Part
	return playHit(SPEC_BurningSlashHit, target, scale, shake, angle)
end
-- segundo (desde la llamada) en que el golpe conecta: para sincronizar el número de daño o el sonido
KaijuFireVFX.BurningSlashHitImpact = 0.05

local SPEC_BiteHit = {
	name = "BiteHit",
	duration = 0.6,
	cleanup = 1.14,
	layers = {
		{
			name = "Jaws",
			texture = "kz_bite_4x4",
			flipbook = {
				layout = "Grid4x4",
				mode = "OneShot",
				fps = 30,
				startRandom = false,
			},
			emit = {
				{0, 1},
			},
			lifetime = {0.36, 0.36},
			size = {
				{0, 25, 0},
				{1, 26, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{0.06, 0, 0},
				{0.62, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 246, 236},
				},
			},
			light_emission = 0.08,
			brightness = 1.1,
			zoffset = 5,
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
		},
		{
			name = "HitFlash",
			texture = "fx_glow",
			emit = {
				{0.14, 1},
			},
			lifetime = {0.16, 0.18},
			size = {
				{0, 6, 0},
				{0.3, 12, 0},
				{1, 13.2, 0},
			},
			transparency = {
				{0, 0.65, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 246, 236},
				},
			},
			light_emission = 1,
			brightness = 0.45,
			zoffset = 6,
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
		},
		{
			name = "HitStar",
			texture = "kk_star_06",
			emit = {
				{0.14, 1},
			},
			lifetime = {0.14, 0.14},
			size = {
				{0, 10, 0},
				{0.4, 11.4, 0},
				{1, 7.2, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 252, 244},
				},
				{
					0.5,
					{255, 226, 186},
				},
				{
					1,
					{255, 180, 110},
				},
			},
			light_emission = 1,
			brightness = 0.75,
			rotation = {0, 360},
			zoffset = 7,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "HitRing",
			texture = "kz_beam_ring",
			emit = {
				{0.14, 1},
			},
			lifetime = {0.22, 0.24},
			size = {
				{0, 6, 0},
				{1, 34, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{255, 246, 236},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {0, 360},
			zoffset = 3,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "ChompBurst",
			texture = "fx_burst_a",
			emit = {
				{0.14, 1},
			},
			lifetime = {0.1, 0.12},
			size = {
				{0, 6, 0},
				{0.4, 15, 0},
				{1, 17, 0},
			},
			transparency = {
				{0, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 252, 244},
				},
				{
					0.5,
					{255, 226, 186},
				},
				{
					1,
					{255, 180, 110},
				},
			},
			light_emission = 0.6,
			brightness = 0.9,
			rotation = {0, 360},
			zoffset = 5,
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FangSparks",
			texture = "fx_spark4",
			shape = {
				type = "Box",
				size = {18, 2, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.14, 10},
			},
			direction = "Back",
			spread = {70, 70},
			speed = {10, 24},
			drag = 2,
			lifetime = {0.2, 0.35},
			size = {
				{0, 0, 0},
				{0.2, 1.8, 0.5},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 252, 244},
				},
				{
					0.5,
					{255, 226, 186},
				},
				{
					1,
					{255, 180, 110},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {0, 360},
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "SparksRight",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {18, 2, 1},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Right",
			spread = {25, 35},
			speed = {70, 140},
			drag = 5,
			accel = {0, -40, 0},
			lifetime = {0.16, 0.3},
			emit = {
				{0.13, 10},
				{0.16, 6},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{255, 252, 244},
				},
				{
					0.5,
					{255, 226, 186},
				},
				{
					1,
					{255, 180, 110},
				},
			},
			light_emission = 1,
			brightness = 2,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "SparksLeft",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {18, 2, 1},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Left",
			spread = {25, 35},
			speed = {70, 140},
			drag = 5,
			accel = {0, -40, 0},
			lifetime = {0.16, 0.3},
			emit = {
				{0.13, 10},
				{0.16, 6},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{255, 252, 244},
				},
				{
					0.5,
					{255, 226, 186},
				},
				{
					1,
					{255, 180, 110},
				},
			},
			light_emission = 1,
			brightness = 2,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Chips",
			texture = "kz_debris_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0.14, 8},
			},
			direction = "Back",
			spread = {55, 55},
			speed = {25, 50},
			drag = 0.5,
			accel = {0, -90, 0},
			lifetime = {0.45, 0.7},
			size = {
				{0, 1, 0.3},
				{1, 0.9, 0.3},
			},
			color = {
				{
					0,
					{150, 120, 100},
				},
				{
					1,
					{100, 88, 80},
				},
			},
			light_emission = 0.05,
			rotation = {0, 360},
			rot_speed = {-400, 400},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "DustPuff",
			texture = "kk_smoke_04",
			emit = {
				{0.15, 3},
			},
			direction = "Back",
			spread = {60, 60},
			speed = {4, 10},
			drag = 2,
			accel = {0, 4, 0},
			lifetime = {0.45, 0.6},
			size = {
				{0, 4, 1},
				{1, 11, 2},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{170, 160, 150},
				},
				{
					1,
					{130, 124, 120},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -2,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
	},
	shakes = {
		{0.14, 0.55, 0.25},
	},
	light = {
		color = {255, 240, 220},
		brightness = 1.2,
		range = 18,
		time = 0.18,
		delay = 0.14,
	},
	hit = {
		lift = 3,
		ref = 22,
		angle = 0,
		angled = false,
		impact = 0.14,
	},
}

-- MORDISCO: dos mandíbulas de colmillos se cierran de golpe sobre el rival; al chocar hay un destello corto y chispas.
-- target = el rival (Model, Part, Vector3 o CFrame). El golpe sale delante de lo que ve la cámara y mira
-- hacia ella. Con un Model o una Part se adapta al alto del rival (22 studs = tamaño 1; scale lo multiplica).
function KaijuFireVFX.BiteHit(target: any, scale: number?, shake: number?): Part
	return playHit(SPEC_BiteHit, target, scale, shake, 0)
end
-- segundo (desde la llamada) en que el golpe conecta: para sincronizar el número de daño o el sonido
KaijuFireVFX.BiteHitImpact = 0.14

return KaijuFireVFX
