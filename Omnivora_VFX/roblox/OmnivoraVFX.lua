--!nonstrict
--[[
	OmnivoraVFX — VFX cósmicos (azul muy oscuro, celeste y blanco, con el púrpura de su boca) para OMNÍVORA
	(generado automáticamente desde vfx_omnivora.py y vfx_blackhole.py; edita allí y regenera)

	USO (en el CLIENTE, por ejemplo al recibir un RemoteEvent del servidor):
		local OmnivoraVFX = require(ReplicatedStorage.OmnivoraVFX)
		-- cf = centro de la zona en el SUELO; radio y altura del pilar en studs; escala; sacudida
		OmnivoraVFX.CosmicPillar(CFrame.new(centroEnElSuelo), 18, 120, 1, 1)
		-- agujero negro desde la boca hasta dos enemigos (detona a los OmnivoraVFX.BlackHoleImpact s)
		OmnivoraVFX.BlackHole(bocaDeOmnivora, { enemigo1, enemigo2 }, 1, 1)

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
	fx_aura_tongue_2x2 = "rbxassetid://0",
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
	om_aura_wisp_2x2 = "rbxassetid://0",
	om_beam_core = "rbxassetid://0",
	om_beam_flow = "rbxassetid://0",
	om_beam_glow = "rbxassetid://0",
	om_beam_nebula = "rbxassetid://0",
	om_beam_stars = "rbxassetid://0",
	om_cracks = "rbxassetid://0",
	om_cubes_2x2 = "rbxassetid://0",
	om_hole = "rbxassetid://0",
	om_nebula_2x2 = "rbxassetid://0",
}

-- Dónde se crean los efectos (puedes cambiarlo por una carpeta de VFX)
OmnivoraVFX.Parent = workspace :: Instance
-- Multiplicador de cantidad de partículas (bájalo en dispositivos lentos, p.ej. 0.6)
OmnivoraVFX.Quality = 1
-- Luz breve en el impacto (del color del efecto)
OmnivoraVFX.UseLight = true
-- Lente de vidrio que distorsiona el fondo detrás del agujero negro (solo con gráficos altos)
OmnivoraVFX.Lens = true
-- Color y material de los cubos de destrucción (nil = los del suelo donde sale el efecto)
OmnivoraVFX.CubeColor = nil :: Color3?
OmnivoraVFX.CubeMaterial = nil :: Enum.Material?

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
		local start = pos
		if L.shape and L.shape.type == "Box" then -- cada pieza sale de un punto al azar de la caja
			local b = L.shape.size
			start = pos + (frame or holder.CFrame):VectorToWorldSpace(Vector3.new(rng:NextNumber(-0.5, 0.5) * b[1],
				rng:NextNumber(-0.5, 0.5) * b[2], rng:NextNumber(-0.5, 0.5) * b[3]) * s)
		end
		local rock = Instance.new("Part")
		rock.Name = "Rock"
		rock.Anchored = true
		rock.CanCollide = false
		rock.CanQuery = false
		rock.CanTouch = false
		rock.CastShadow = false
		rock.Material = (Enum.Material :: any)[L.rock.material or "Slate"]
		rock.Color = Color3.fromRGB(L.rock.color[1], L.rock.color[2], L.rock.color[3])
		local asp = L.rock.aspect or { 1, 0.8, 0.9 }
		rock.Size = Vector3.new(sz * asp[1], sz * asp[2], sz * asp[3])
		rock.CFrame = CFrame.new(start)
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
			acc[i] += rate * OmnivoraVFX.Quality * dt
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
function OmnivoraVFX.Shake(intensity: number, duration: number?)
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
function OmnivoraVFX.ShakeRamp(i0: number, i1: number, duration: number, power: number?)
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

local function play(spec: Layer, cf: CFrame, scale: number?, length: number?, shake: number?, angle: number?,
	groundY: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local len = length or 0
	local tanH = math.tan(math.rad(math.clamp(angle or 60, 5, 170) / 2))
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf, OmnivoraVFX.Parent)
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
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), lookCF(A0, lastDir), OmnivoraVFX.Parent)
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
		b.Texture = OmnivoraVFX.TEXTURES[B.texture] or ""
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
	if OmnivoraVFX.UseLight then
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
				OmnivoraVFX.Shake(shake * sk[2], sk[3])
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
local function _playHit(spec: Layer, target: any, scale: number?, shake: number?, angle: number?): Part
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
	local k = if height and (OmnivoraVFX :: any).HitAutoSize then math.clamp(height / H.ref, 0.5, 4) else 1
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

-- arranca las capas de una zona circular (+ cubos de destrucción y luces); snap = hasta cuántos studs
-- se baja o se sube el centro para apoyarlo en el suelo
local function startZone(spec: Layer, cf: CFrame, s: number, R: number, H: number, snap: number): (Part, Zone)
	-- la zona queda plana (solo se usa el giro horizontal de cf) y apoyada en el suelo
	local pos = cf.Position
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local flat = if look.Magnitude > 1e-3 then CFrame.lookAt(pos, pos + look) else CFrame.new(pos)
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), flat, OmnivoraVFX.Parent)
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
local function playZone(spec: Layer, cf: CFrame, scale: number?, radius: number?, height: number?, shake: number?): Part
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
	if (OmnivoraVFX :: any).Lens and O.lens then
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
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf0, OmnivoraVFX.Parent)
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
	if OmnivoraVFX.UseLight then
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
			local rate = (L.rate or 0) * it.share * k2 * gate * OmnivoraVFX.Quality
			it.e.Rate = rate
			it.e.Enabled = rate > 0.01
		end
		-- oleadas
		local surgeK = 0
		if Au.surge and Au.surge > 0 then
			if t - lastSurge >= Au.surge and on > 0.5 then
				lastSurge = t
				for _, it in items do
					local n = (it.L.surge or 0) * it.share * ctl.Intensity * OmnivoraVFX.Quality
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
	local Q = OmnivoraVFX.Quality
	local victimList: { any } = if typeof(victimsIn) == "table" then victimsIn elseif victimsIn ~= nil then { victimsIn } else {}
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), CFrame.new(C), OmnivoraVFX.Parent)
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
		b.Texture = OmnivoraVFX.TEXTURES[Bs.texture] or ""
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
		d.Texture = OmnivoraVFX.TEXTURES[tex] or ""
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
				dd.Texture = OmnivoraVFX.TEXTURES[tex] or ""
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
	for i = 1, if (OmnivoraVFX :: any).Lens == false then 0 else 3 do
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
			h.lens.Transparency = if (OmnivoraVFX :: any).Lens == false then 1 else 1 - 0.38 * birth
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

local SPEC_BlackHole = {
	name = "BlackHole",
	duration = 3.5,
	cleanup = 5.94,
	layers = {
		{
			name = "HoleAura",
			orb = "sprite",
			locked = true,
			grow = true,
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			lifetime = {2.1, 2.1},
			size = {
				{0, 5.5, 0},
				{1, 5.5, 0},
			},
			color = {
				{
					0,
					{10, 14, 40},
				},
				{
					1,
					{6, 8, 26},
				},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.3, 0},
				{0.9, 0.25, 0},
				{1, 0.6, 0},
			},
			light_emission = 0,
			zoffset = -1,
			clear_at = 2.1,
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
			name = "DiskSwirl",
			orb = "sprite",
			locked = true,
			grow = true,
			texture = "fx_swirl_rings",
			emit = {
				{0, 1},
			},
			lifetime = {2.1, 2.1},
			size = {
				{0, 6.8, 0},
				{1, 6.8, 0},
			},
			color = {
				{
					0,
					{130, 200, 255},
				},
				{
					0.5,
					{90, 160, 255},
				},
				{
					1,
					{120, 190, 255},
				},
			},
			transparency = {
				{0, 1, 0},
				{0.1, 0.35, 0},
				{0.88, 0.3, 0},
				{0.95, 0.1, 0},
				{1, 0.5, 0},
			},
			light_emission = 0.7,
			zoffset = 0.5,
			clear_at = 2.1,
			brightness = 1,
			rotation = {0, 360},
			rot_speed = {-260, -260},
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
			name = "DiskWind",
			orb = "sprite",
			locked = true,
			grow = true,
			texture = "fx_wind_swirl",
			emit = {
				{0, 1},
			},
			lifetime = {2.1, 2.1},
			size = {
				{0, 8, 0},
				{1, 8, 0},
			},
			color = {
				{
					0,
					{175, 70, 250},
				},
				{
					1,
					{150, 55, 235},
				},
			},
			transparency = {
				{0, 1, 0},
				{0.12, 0.3, 0},
				{0.9, 0.28, 0},
				{1, 0.6, 0},
			},
			light_emission = 0.6,
			zoffset = 0.4,
			clear_at = 2.1,
			brightness = 1.1,
			rotation = {0, 360},
			rot_speed = {170, 170},
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
			name = "DiskTilt",
			orb = "sprite",
			locked = true,
			grow = true,
			texture = "kk_light_03",
			emit = {
				{0, 1},
			},
			lifetime = {2.1, 2.1},
			size = {
				{0, 7, 0},
				{1, 7, 0},
			},
			color = {
				{
					0,
					{150, 210, 255},
				},
				{
					1,
					{100, 170, 255},
				},
			},
			transparency = {
				{0, 1, 0},
				{0.1, 0.45, 0},
				{0.9, 0.4, 0},
				{1, 0.65, 0},
			},
			light_emission = 0.7,
			zoffset = 0.6,
			clear_at = 2.1,
			brightness = 1,
			rotation = {0, 360},
			rot_speed = {-200, -200},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "DiskTiltPurple",
			orb = "sprite",
			locked = true,
			grow = true,
			texture = "fx_swirl_rings",
			emit = {
				{0, 1},
			},
			lifetime = {2.1, 2.1},
			size = {
				{0, 9, 0},
				{1, 9, 0},
			},
			color = {
				{
					0,
					{200, 100, 255},
				},
				{
					1,
					{150, 60, 235},
				},
			},
			transparency = {
				{0, 1, 0},
				{0.12, 0.4, 0},
				{0.9, 0.38, 0},
				{1, 0.7, 0},
			},
			light_emission = 0.6,
			zoffset = 0.3,
			clear_at = 2.1,
			brightness = 1.05,
			rotation = {0, 360},
			rot_speed = {120, 120},
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "HoleCore",
			orb = "sprite",
			locked = true,
			grow = true,
			texture = "om_hole",
			emit = {
				{0, 1},
			},
			lifetime = {2.1, 2.1},
			size = {
				{0, 2.15, 0},
				{1, 2.15, 0},
			},
			color = {
				{
					0,
					{4, 6, 20},
				},
				{
					1,
					{4, 6, 20},
				},
			},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			light_emission = 0,
			zoffset = 1.5,
			clear_at = 2.1,
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
			name = "PhotonRing",
			orb = "sprite",
			locked = true,
			grow = true,
			texture = "kk_circle_02",
			emit = {
				{0, 1},
			},
			lifetime = {2.1, 2.1},
			size = {
				{0, 3.85, 0},
				{1, 3.85, 0},
			},
			color = {
				{
					0,
					{240, 248, 255},
				},
				{
					1,
					{190, 230, 255},
				},
			},
			transparency = {
				{0, 1, 0},
				{0.06, 0.15, 0},
				{0.86, 0.1, 0},
				{0.93, 0, 0},
				{1, 0.3, 0},
			},
			light_emission = 1,
			zoffset = 2,
			clear_at = 2.1,
			brightness = 1.45,
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
			name = "PhotonPurple",
			orb = "sprite",
			locked = true,
			grow = true,
			texture = "kk_circle_02",
			emit = {
				{0, 1},
			},
			lifetime = {2.1, 2.1},
			size = {
				{0, 4.5, 0},
				{1, 4.5, 0},
			},
			color = {
				{
					0,
					{232, 160, 255},
				},
				{
					1,
					{190, 90, 250},
				},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.4, 0},
				{0.9, 0.35, 0},
				{1, 0.6, 0},
			},
			light_emission = 1,
			zoffset = 1.9,
			clear_at = 2.1,
			brightness = 1.4,
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
			name = "Inflow",
			orb = "shell",
			shell = 3.4,
			grow = true,
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			speed = {8.5, 10.5},
			lifetime = {0.3, 0.36},
			size = {
				{0, 0.25, 0},
				{0.4, 1.3, 0},
				{1, 0.5, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.25, 0.1, 0},
				{1, 0.4, 0},
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
			brightness = 1.4,
			stream = {
				{0.15, 0.55, 20, 45},
				{0.55, 1.95, 45, 85},
				{1.95, 2.08, 85, 0},
			},
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
			name = "InflowPurple",
			orb = "shell",
			shell = 3.8,
			grow = true,
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			speed = {8.5, 10.5},
			lifetime = {0.34, 0.4},
			size = {
				{0, 0.25, 0},
				{0.4, 1.3, 0},
				{1, 0.5, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.25, 0.1, 0},
				{1, 0.4, 0},
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
			brightness = 1.4,
			stream = {
				{0.15, 0.55, 10, 22.5},
				{0.55, 1.95, 22.5, 42.5},
				{1.95, 2.08, 42.5, 0},
			},
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
			name = "InflowStars",
			orb = "shell",
			shell = 3,
			grow = true,
			texture = "fx_spark002",
			speed = {6, 8},
			lifetime = {0.38, 0.48},
			size = {
				{0, 0, 0},
				{0.25, 0.32, 0},
				{1, 0.12, 0},
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
			rotation = {0, 45},
			stream = {
				{0.2, 1.95, 25, 50},
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
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "FormGather",
			orb = "shell",
			shell_abs = 10,
			texture = "kk_trace_06",
			orientation = "VelocityParallel",
			speed = {26, 30},
			lifetime = {0.32, 0.38},
			size = {
				{0, 1, 0},
				{0.3, 4.5, 0},
				{1, 1.5, 0},
			},
			transparency = {
				{0, 0.7, 0},
				{0.2, 0.2, 0},
				{0.85, 0.3, 0},
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
			brightness = 1.2,
			stream = {
				{0, 0.5, 90, 60},
			},
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
			name = "FormGatherPurple",
			orb = "shell",
			shell_abs = 8,
			texture = "kk_trace_06",
			orientation = "VelocityParallel",
			speed = {21, 25},
			lifetime = {0.32, 0.38},
			size = {
				{0, 1, 0},
				{0.3, 4, 0},
				{1, 1.5, 0},
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
			brightness = 1.5,
			stream = {
				{0, 0.5, 45, 30},
			},
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
			name = "FormMotes",
			orb = "shell",
			shell_abs = 7,
			texture = "fx_particle02",
			speed = {16, 20},
			lifetime = {0.38, 0.45},
			size = {
				{0, 0, 0},
				{0.2, 1, 0},
				{1, 0.4, 0},
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
			stream = {
				{0, 0.5, 60, 40},
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
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "FormGlow",
			orb = "sprite",
			locked = true,
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			lifetime = {0.65, 0.65},
			size = {
				{0, 1.5, 0},
				{0.8, 13, 0},
				{1, 6, 0},
			},
			color = {
				{
					0,
					{150, 60, 240},
				},
				{
					1,
					{90, 40, 200},
				},
			},
			transparency = {
				{0, 0.5, 0},
				{0.7, 0.35, 0},
				{1, 1, 0},
			},
			light_emission = 1,
			brightness = 1.3,
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
		},
		{
			name = "LaunchPop",
			orb = "burst",
			texture = "kk_circle_02",
			emit = {
				{0.55, 1},
			},
			lifetime = {0.35, 0.35},
			size = {
				{0, 4, 0},
				{1, 30, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.6, 0.6, 0},
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
			light_emission = 1,
			brightness = 1.3,
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
		},
		{
			name = "LaunchFlash",
			orb = "burst",
			texture = "fx_halo",
			emit = {
				{0.55, 1},
			},
			lifetime = {0.22, 0.22},
			size = {
				{0, 6, 0},
				{1, 22, 0},
			},
			transparency = {
				{0, 0.2, 0},
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
			brightness = 1.3,
			rotation = {0, 360},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Ripples",
			orb = "burst",
			locked = true,
			grow = true,
			texture = "kk_circle_02",
			emit = {
				{0.8, 1},
				{1.05, 1},
				{1.3, 1},
				{1.55, 1},
				{1.8, 1},
			},
			lifetime = {0.5, 0.5},
			size = {
				{0, 3.8, 0},
				{1, 11, 0},
			},
			transparency = {
				{0, 0.55, 0},
				{0.5, 0.75, 0},
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
			light_emission = 1,
			brightness = 1.1,
			zoffset = -0.5,
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
			name = "Trail",
			orb = "trail",
			grow = true,
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			speed = {0, 1.5},
			spread = {180, 180},
			drag = 1,
			lifetime = {0.55, 0.85},
			size = {
				{0, 1.6, 0},
				{0.4, 2.4, 0},
				{1, 2.8, 0},
			},
			transparency = {
				{0, 0.55, 0},
				{0.35, 0.6, 0},
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
			light_emission = 0.15,
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -2,
			stream = {
				{0.6, 1.95, 30, 34},
			},
			direction = "Top",
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TrailDark",
			orb = "trail",
			grow = true,
			texture = "kk_smoke_04",
			speed = {0, 1},
			spread = {180, 180},
			lifetime = {0.6, 0.9},
			size = {
				{0, 1.4, 0},
				{1, 2.6, 0},
			},
			transparency = {
				{0, 0.55, 0},
				{0.4, 0.62, 0},
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
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2.5,
			stream = {
				{0.6, 1.95, 16, 20},
			},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "TrailStars",
			orb = "trail",
			texture = "fx_particle02",
			speed = {1, 4},
			spread = {180, 180},
			drag = 1.5,
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.1, 1.4, 0},
				{0.3, 0.6, 0},
				{0.5, 1.3, 0},
				{0.75, 0.5, 0},
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
			brightness = 1.9,
			stream = {
				{0.6, 1.95, 40, 50},
			},
			direction = "Top",
			accel = {0, 0, 0},
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
			name = "GroundPull",
			orb = "ground",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Box",
				size = {14, 1, 14},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {12, 26},
			accel = {0, 25, 0},
			lifetime = {0.55, 0.85},
			size = {
				{0, 0.55, 0.3},
				{1, 0.35, 0.2},
			},
			color = {
				{
					0,
					{150, 154, 168},
				},
				{
					1,
					{120, 124, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-300, 300},
			stream = {
				{0.75, 1.95, 30, 70},
			},
			drag = 0,
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
			name = "GroundDust",
			orb = "ground",
			texture = "kk_smoke_04",
			shape = {
				type = "Box",
				size = {16, 1, 16},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {4, 10},
			accel = {0, 6, 0},
			lifetime = {0.8, 1.2},
			size = {
				{0, 3, 1},
				{1, 9, 2},
			},
			transparency = {
				{0, 0.65, 0},
				{0.3, 0.55, 0},
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
			rotation = {0, 360},
			rot_speed = {-40, 40},
			stream = {
				{0.75, 1.95, 8, 16},
			},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "Implode",
			orb = "shell",
			shell_abs = 16,
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{1.95, 46},
			},
			speed = {70, 90},
			lifetime = {0.15, 0.2},
			size = {
				{0, 2, 0},
				{0.4, 9, 0},
				{1, 3, 0},
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
			brightness = 1.5,
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
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "ImplodePurple",
			orb = "shell",
			shell_abs = 14,
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{1.95, 26},
			},
			speed = {62, 80},
			lifetime = {0.15, 0.2},
			size = {
				{0, 2, 0},
				{0.4, 8, 0},
				{1, 3, 0},
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
			brightness = 1.5,
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
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "CollapseFlare",
			orb = "burst",
			locked = true,
			texture = "fx_glow",
			emit = {
				{1.95, 1},
			},
			lifetime = {0.16, 0.16},
			size = {
				{0, 6, 0},
				{1, 18, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{1, 0, 0},
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
		},
		{
			name = "DetFlash",
			texture = "fx_glow",
			lifetime = {0.26, 0.26},
			size = {
				{0, 10, 0},
				{0.25, 28.8, 0},
				{1, 32, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.4, 0.5, 0},
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
			zoffset = 4,
			ring_emit = {
				{2.1, 1, 0, 0, 8},
			},
			rel = "r",
			hu = "s",
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
			name = "DetStar",
			texture = "kk_star_09",
			lifetime = {0.32, 0.32},
			size = {
				{0, 14, 0},
				{0.15, 48, 0},
				{1, 10, 0},
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
			brightness = 1.3,
			rotation = {0, 90},
			zoffset = 5,
			ring_emit = {
				{2.1, 1, 0, 0, 8},
			},
			rel = "r",
			hu = "s",
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
			name = "DetHalo",
			texture = "fx_halo",
			lifetime = {0.38, 0.42},
			size = {
				{0, 8, 0},
				{1, 67.2, 0},
			},
			transparency = {
				{0, 0.3, 0},
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
			light_emission = 1,
			brightness = 1.1,
			rotation = {0, 360},
			zoffset = 3,
			ring_emit = {
				{2.1, 1, 0, 0, 8},
				{2.15, 1, 0, 0, 8},
			},
			rel = "r",
			hu = "s",
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
			name = "DetNebula",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {180, 180},
			speed_r = {0.7, 1.6},
			drag = 2,
			lifetime = {1, 1.4},
			size = {
				{0, 8, 0},
				{0.3, 20, 0},
				{1, 27.2, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.06, 0.25, 0},
				{0.6, 0.4, 0},
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
			light_emission = 0.12,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -3,
			ring_emit = {
				{2.1, 16, 0, 0, 8},
			},
			rel = "r",
			hu = "s",
			speed = {0, 0},
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "DetShell",
			texture = "kk_circle_02",
			lifetime = {0.45, 0.45},
			size = {
				{0, 13.56, 0},
				{1, 92.208, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.45, 0},
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
			light_emission = 1,
			brightness = 1.2,
			zoffset = 4,
			ring_emit = {
				{2.1, 1, 0, 0, 8},
			},
			rel = "r",
			hu = "s",
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
			name = "DetShellPurple",
			texture = "kk_circle_02",
			lifetime = {0.45, 0.45},
			size = {
				{0, 13.56, 0},
				{1, 75.936, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.5, 0},
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
			brightness = 1.2,
			zoffset = 3.8,
			ring_emit = {
				{2.16, 1, 0, 0, 8},
			},
			rel = "r",
			hu = "s",
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
			name = "DetStreaks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {180, 180},
			speed_r = {2.6, 4.2},
			lifetime = {0.28, 0.42},
			size = {
				{0, 4, 0},
				{0.3, 20, 0},
				{1, 8, 0},
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
			brightness = 1.1,
			ring_emit = {
				{2.1, 54, 0, 0, 8},
			},
			rel = "r",
			hu = "s",
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
			line_u = 0,
			emit = {},
		},
		{
			name = "DetPurple",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {180, 180},
			speed_r = {2.4, 3.8},
			lifetime = {0.28, 0.42},
			size = {
				{0, 4, 0},
				{0.3, 20, 0},
				{1, 8, 0},
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
				{2.1, 30, 0, 0, 8},
			},
			rel = "r",
			hu = "s",
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
			line_u = 0,
			emit = {},
		},
		{
			name = "DetStars",
			texture = "fx_spark002",
			direction = "Top",
			spread = {180, 180},
			speed_r = {0.9, 2.6},
			drag = 2.2,
			lifetime = {0.9, 1.5},
			size = {
				{0, 0, 0},
				{0.08, 2.6, 0},
				{0.3, 1.2, 0},
				{0.5, 2.4, 0},
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
			rotation = {0, 45},
			ring_emit = {
				{2.1, 70, 0, 0, 8},
			},
			rel = "r",
			hu = "s",
			speed = {0, 0},
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
			emit = {},
		},
		{
			name = "DetBolts",
			texture = "fx_thunder",
			lifetime = {0.08, 0.12},
			size = {
				{0, 14.4, 0},
				{1, 17.6, 0},
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
				{2.105, 1, 0.4029, 0.153, 10.639},
				{2.128, 1, 0.6839, 0.055, 7.357},
				{2.128, 1, 0.7576, 0.186, 6.391},
				{2.154, 1, 0.5474, 0.229, 8.509},
				{2.183, 1, 0.9551, 0.223, 7.189},
				{2.212, 1, 0.9963, 0.366, 7.475},
				{2.285, 1, 0.1366, 0.192, 8.973},
				{2.31, 1, 0.2039, 0.488, 7.133},
			},
			rel = "r",
			hu = "s",
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
			name = "DetShock",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.55, 0.55},
			size = {
				{0, 16.272, 0},
				{1, 130.176, 0},
			},
			transparency = {
				{0, 0.3, 0},
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
			light_emission = 0.35,
			ring_emit = {
				{2.1, 1, 0, 0, 0.2},
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
			name = "DetShockSharp",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.35, 0.35},
			size = {
				{0, 16.272, 0},
				{1, 162.72, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.6, 0.55, 0},
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
				{2.1, 1, 0, 0, 0.21},
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
			name = "DetVoid",
			texture = "fx_glow",
			rel = "r",
			lifetime = {1.8, 1.8},
			size = {
				{0, 10, 0},
				{0.15, 35.2, 0},
				{1, 36.8, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.1, 0.4, 0},
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
				{2.1, 1, 0, 0, 0.1},
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
			name = "DetCracks",
			texture = "om_cracks",
			rel = "r",
			lifetime = {1.8, 1.8},
			rotation = {0, 360},
			size = {
				{0, 12, 0},
				{0.12, 38, 0},
				{1, 41.6, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.25, 0},
				{0.12, 0.02, 0},
				{0.3, 0.15, 0},
				{0.8, 0.3, 0},
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
				{2.1, 1, 0, 0, 0.16},
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
			name = "DetScorch",
			texture = "kz_scorch",
			rel = "r",
			lifetime = {2, 2},
			rotation = {0, 360},
			size = {
				{0, 8, 0},
				{0.05, 36.8, 0},
				{1, 38.4, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.35, 0},
				{0.8, 0.45, 0},
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
				{2.1, 1, 0, 0, 0.08},
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
		{
			name = "DetDust",
			texture = "kk_smoke_07",
			rel = "r",
			direction = "Front",
			spread = {15, 8},
			pitch = 8,
			speed_r = {1.6, 2.6},
			drag = 3,
			accel = {0, 4, 0},
			lifetime = {0.9, 1.3},
			size = {
				{0, 8, 2},
				{0.3, 18, 3},
				{1, 26, 4},
			},
			transparency = {
				{0, 0.5, 0},
				{0.2, 0.32, 0},
				{0.6, 0.5, 0},
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
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -3,
			ring_emit = {
				{2.12, 1, 0, 0.5, 1.5},
				{2.12, 1, 0.0714, 0.5, 1.5},
				{2.12, 1, 0.1429, 0.5, 1.5},
				{2.12, 1, 0.2143, 0.5, 1.5},
				{2.12, 1, 0.2857, 0.5, 1.5},
				{2.12, 1, 0.3571, 0.5, 1.5},
				{2.12, 1, 0.4286, 0.5, 1.5},
				{2.12, 1, 0.5, 0.5, 1.5},
				{2.12, 1, 0.5714, 0.5, 1.5},
				{2.12, 1, 0.6429, 0.5, 1.5},
				{2.12, 1, 0.7143, 0.5, 1.5},
				{2.12, 1, 0.7857, 0.5, 1.5},
				{2.12, 1, 0.8571, 0.5, 1.5},
				{2.12, 1, 0.9286, 0.5, 1.5},
			},
			speed = {0, 0},
			light_emission = 0,
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
			spread = {30, 30},
			speed_r = {1.6, 3.6},
			accel = {0, -160, 0},
			lifetime = {0.6, 1.1},
			size = {
				{0, 0.6, 0.3},
				{1, 0.5, 0.25},
			},
			color = {
				{
					0,
					{150, 154, 168},
				},
				{
					1,
					{120, 124, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			ring_emit = {
				{2.1, 1, 0.0002, 0.703, 0.6},
				{2.102, 1, 0.112, 0.807, 0.6},
				{2.102, 1, 0.1249, 0.457, 0.6},
				{2.102, 1, 0.614, 0.933, 0.6},
				{2.103, 1, 0.249, 0.883, 0.6},
				{2.105, 1, 0.0989, 0.761, 0.6},
				{2.105, 1, 0.1941, 0.992, 0.6},
				{2.105, 1, 0.7831, 0.41, 0.6},
				{2.107, 1, 0.4549, 0.572, 0.6},
				{2.107, 1, 0.8531, 0.772, 0.6},
				{2.108, 1, 0.2144, 0.639, 0.6},
				{2.108, 1, 0.4548, 0.996, 0.6},
				{2.108, 1, 0.8139, 0.537, 0.6},
				{2.108, 1, 0.8207, 0.488, 0.6},
				{2.108, 1, 0.921, 0.36, 0.6},
				{2.111, 1, 0.1816, 0.969, 0.6},
				{2.112, 1, 0.1763, 0.893, 0.6},
				{2.112, 1, 0.4255, 0.637, 0.6},
				{2.113, 1, 0.3343, 0.282, 0.6},
				{2.115, 1, 0.2825, 0.225, 0.6},
				{2.115, 1, 0.6127, 0.554, 0.6},
				{2.116, 1, 0.8176, 0.624, 0.6},
				{2.117, 1, 0.1406, 0.393, 0.6},
				{2.118, 1, 0.7889, 0.899, 0.6},
				{2.119, 1, 0.2971, 0.269, 0.6},
				{2.119, 1, 0.4998, 0.8, 0.6},
				{2.12, 1, 0.7884, 0.705, 0.6},
				{2.121, 1, 0.7171, 0.652, 0.6},
				{2.121, 1, 0.8597, 0.841, 0.6},
				{2.122, 1, 0.2427, 0.85, 0.6},
				{2.122, 1, 0.6745, 0.799, 0.6},
				{2.123, 1, 0.4034, 0.957, 0.6},
				{2.125, 1, 0.8954, 0.268, 0.6},
				{2.126, 1, 0.2192, 0.475, 0.6},
				{2.126, 1, 0.8362, 0.648, 0.6},
				{2.128, 1, 0.0956, 0.786, 0.6},
				{2.128, 1, 0.3683, 0.61, 0.6},
				{2.129, 1, 0.4669, 0.695, 0.6},
				{2.129, 1, 0.6929, 0.415, 0.6},
				{2.129, 1, 0.8272, 0.888, 0.6},
				{2.129, 1, 0.8541, 0.602, 0.6},
				{2.13, 1, 0.3005, 0.636, 0.6},
				{2.131, 1, 0.2548, 0.987, 0.6},
				{2.132, 1, 0.7298, 0.5, 0.6},
				{2.135, 1, 0.6512, 0.864, 0.6},
				{2.136, 1, 0.6493, 0.651, 0.6},
				{2.138, 1, 0.6901, 0.869, 0.6},
				{2.139, 1, 0.3487, 0.88, 0.6},
				{2.139, 1, 0.9935, 0.981, 0.6},
				{2.14, 1, 0.0304, 0.918, 0.6},
			},
			speed = {0, 0},
			drag = 0,
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
			name = "AfterNebula",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {180, 180},
			speed = {2, 6},
			drag = 1,
			lifetime = {1, 1.4},
			size = {
				{0, 16, 0},
				{1, 24, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.15, 0.55, 0},
				{0.7, 0.65, 0},
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
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -4,
			ring_emit = {
				{2.25, 6, 0, 0, 8},
			},
			rel = "r",
			hu = "s",
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "AfterStars",
			texture = "kk_star_06",
			direction = "Top",
			spread = {180, 180},
			speed = {1, 3},
			lifetime = {0.7, 1.1},
			size = {
				{0, 0, 0},
				{0.1, 3.2, 0},
				{0.3, 1.4, 0},
				{0.5, 3, 0},
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
			rotation = {0, 45},
			ring_emit = {
				{2.236, 1, 0.5385, 0.615, 7.134},
				{2.272, 1, 0.0569, 0.452, 13.886},
				{2.3, 1, 0.2286, 1.026, 6.716},
				{2.31, 1, 0.8712, 0.741, 9.782},
				{2.313, 1, 0.8029, 0.73, 1.347},
				{2.381, 1, 0.9062, 0.475, 4.899},
				{2.387, 1, 0.8465, 0.97, 10.078},
				{2.456, 1, 0.5741, 0.809, 2.44},
				{2.499, 1, 0.9411, 0.476, 9.137},
				{2.543, 1, 0.7848, 1.049, 9.342},
				{2.552, 1, 0.3426, 0.574, 11.046},
				{2.584, 1, 0.6857, 0.73, 8.171},
				{2.615, 1, 0.3086, 0.903, 13.875},
				{2.742, 1, 0.2216, 0.685, 9.314},
				{2.784, 1, 0.4015, 0.217, 7.765},
				{2.788, 1, 0.7385, 0.994, 14.657},
				{2.803, 1, 0.7859, 0.453, 2.623},
				{2.824, 1, 0.0782, 0.567, 7.482},
				{2.837, 1, 0.2483, 1.091, 1.925},
				{2.859, 1, 0.7058, 0.705, 4.635},
				{2.862, 1, 0.3389, 1.044, 11.908},
				{2.928, 1, 0.3891, 0.83, 5.834},
				{2.956, 1, 0.8388, 0.711, 11.262},
				{2.964, 1, 0.3237, 0.241, 11.261},
				{2.968, 1, 0.3132, 0.642, 7.316},
				{2.999, 1, 0.0477, 0.771, 3.11},
			},
			rel = "r",
			hu = "s",
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
	shakes = {
		{2.1, 1.6, 0.9},
	},
	shake_ramp = {0.3, 2.1, 0.08, 0.5, 1.6},
	scale_mult = 2,
	zone = {
		radius = 16,
		height = 40,
	},
	lights = {
		{
			t = 1.3,
			h = 8,
			color = {60, 100, 255},
			brightness = 2,
			range = 40,
			rise = 0.6,
			hold = 0.1,
			fall = 0.1,
		},
		{
			t = 2.1,
			h = 8,
			color = {140, 200, 255},
			brightness = 10,
			range = 60,
			rise = 0.02,
			hold = 0.06,
			fall = 0.6,
		},
		{
			t = 2.1,
			h = 3,
			color = {170, 80, 255},
			brightness = 5,
			range = 50,
			rise = 0.05,
			hold = 0.25,
			fall = 0.9,
		},
	},
	orb = {
		form = {0, 0.55},
		travel = {0.55, 1.95},
		collapse = {1.95, 2.1},
		size = {0, 1.3, 5, 0.7},
		height = 8,
		arc = 6,
		tilt = 24,
		lens = 4.2,
		lens_transparency = 0.62,
		lens_color = {24, 30, 80},
		min_radius = 14,
		margin = 7,
		reach = 70,
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
				name = "Pulled",
				mode = "lift",
				count = 30,
				t = {1.25, 1.75},
				r = {0.1, 0.95},
				size = {0.25, 1.2},
				skew = 1.8,
				lift = {2.5, 8},
				release = {2.1, 2.13},
				out = {20, 56},
				up = {40, 85},
				dissolve = 0.35,
			},
			{
				name = "Blast",
				mode = "blast",
				count = 150,
				t = {2.1, 2.16},
				r = {0.2, 1.05},
				size = {0.12, 1.3},
				skew = 2.8,
				out = {20, 66},
				up = {30, 85},
				dissolve = 0.35,
				neon = 0.1,
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

-- OMNÍVORA: un AGUJERO NEGRO se forma frente a su boca, avanza creciendo y distorsionando el entorno, y detona en medio de los enemigos (la explosión los cubre a todos) con destrucción de cubos. Para el combate por turnos: golpea a dos enemigos a la vez.
-- mouth = la boca (Vector3 o CFrame): ahí se forma. targets = un enemigo o una lista (Vector3, BasePart
-- o Model): detona en medio de ellos y la explosión los cubre a todos. radius = radio de la detonación
-- (si no, se calcula con los enemigos: mínimo 28 × escala). Detona a los 2.1 s (ver BlackHoleImpact).
function OmnivoraVFX.BlackHole(mouth: Vector3 | CFrame, targets: any, scale: number?, shake: number?, radius: number?): Part
	return playOrb(SPEC_BlackHole, mouth, targets, scale, shake, radius)
end
-- segundo (desde la llamada) en que detona: para sincronizar el daño
OmnivoraVFX.BlackHoleImpact = 2.1

local SPEC_CosmicBeam = {
	name = "CosmicBeam",
	duration = 3.6,
	cleanup = 6.83,
	layers = {
		{
			name = "ChargeGather",
			texture = "kk_trace_06",
			orientation = "VelocityParallel",
			shape = {
				type = "Sphere",
				radius = 18,
				style = "Surface",
				inout = "Inward",
			},
			speed = {62, 80},
			lifetime = {0.22, 0.27},
			size = {
				{0, 1, 0},
				{0.3, 6, 0},
				{1, 2, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.2, 0.1, 0},
				{1, 0.3, 0},
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
			brightness = 1.3,
			stream = {
				{0, 0.27, 100, 140},
			},
			offset = {0, 0, -2},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeGatherPurple",
			texture = "kk_trace_06",
			orientation = "VelocityParallel",
			shape = {
				type = "Sphere",
				radius = 15,
				style = "Surface",
				inout = "Inward",
			},
			speed = {52, 66},
			lifetime = {0.22, 0.27},
			size = {
				{0, 1, 0},
				{0.3, 5.5, 0},
				{1, 2, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.2, 0.1, 0},
				{1, 0.3, 0},
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
			brightness = 1.5,
			stream = {
				{0, 0.27, 50, 70},
			},
			offset = {0, 0, -2},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeMotes",
			texture = "fx_particle02",
			shape = {
				type = "Sphere",
				radius = 14,
				style = "Surface",
				inout = "Inward",
			},
			speed = {45, 58},
			lifetime = {0.24, 0.3},
			size = {
				{0, 0, 0},
				{0.2, 1.2, 0.3},
				{1, 0.5, 0},
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
			stream = {
				{0, 0.27, 60, 80},
			},
			offset = {0, 0, -2},
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
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeGlow",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			lifetime = {0.34, 0.34},
			size = {
				{0, 4, 0},
				{0.85, 22, 0},
				{1, 30, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{150, 60, 240},
				},
				{
					0.6,
					{120, 190, 255},
				},
				{
					1,
					{235, 245, 255},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			zoffset = 2,
			offset = {0, 0, -2},
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
			name = "ChargeSwirl",
			texture = "fx_swirl_rings",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			speed = {0.5, 0.5},
			lifetime = {0.26, 0.26},
			size = {
				{0, 30, 0},
				{1, 6, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.35, 0},
				{1, 0.3, 0},
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
			light_emission = 0.9,
			brightness = 1.2,
			rotation = {0, 360},
			rot_speed = {-420, -360},
			stream = {
				{0, 0.24, 9, 12},
			},
			offset = {0, 0, -2},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
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
			lifetime = {0.3, 0.3},
			size = {
				{0, 16, 0},
				{0.25, 38, 0},
				{1, 42, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.5, 0.65, 0},
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
			brightness = 0.85,
			zoffset = 4,
			offset = {0, 0, -2},
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
			texture = "kk_star_09",
			emit = {
				{0.3, 2},
			},
			lifetime = {0.26, 0.3},
			size = {
				{0, 20, 0},
				{0.15, 50, 0},
				{1, 14, 0},
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
			brightness = 1,
			rotation = {0, 90},
			zoffset = 5,
			offset = {0, 0, -2},
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
			line_u = 0,
		},
		{
			name = "MouthHalo",
			texture = "fx_halo",
			emit = {
				{0.3, 1},
			},
			lifetime = {0.32, 0.36},
			size = {
				{0, 10, 0},
				{1, 60, 0},
			},
			transparency = {
				{0, 0.3, 0},
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
			light_emission = 1,
			brightness = 1.1,
			rotation = {0, 360},
			zoffset = 3,
			offset = {0, 0, -2},
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
			texture = "kk_star_08",
			lifetime = {0.1, 0.16},
			size = {
				{0, 20, 4},
				{0.5, 26, 5},
				{1, 20, 4},
			},
			transparency = {
				{0, 0.3, 0},
				{0.6, 0.4, 0},
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
			brightness = 0.9,
			rotation = {0, 360},
			zoffset = 5,
			stream = {
				{0.3, 3.28, 14, 14},
			},
			offset = {0, 0, -2},
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
			lifetime = {0.15, 0.2},
			size = {
				{0, 22, 3},
				{1, 28, 3},
			},
			transparency = {
				{0, 0.62, 0},
				{1, 0.82, 0},
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
			zoffset = 3,
			stream = {
				{0.3, 3.28, 12, 12},
			},
			offset = {0, 0, -2},
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
			name = "MouthDisk",
			texture = "fx_swirl_rings",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			speed = {1, 1},
			lifetime = {0.4, 0.5},
			size = {
				{0, 18, 0},
				{1, 26, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.4, 0},
				{0.8, 0.5, 0},
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
			light_emission = 0.9,
			brightness = 1.1,
			rotation = {0, 360},
			rot_speed = {-320, -260},
			stream = {
				{0.32, 3.28, 6, 6},
			},
			offset = {0, 0, -2},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "MouthRings",
			texture = "kk_light_03",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			speed = {14, 24},
			drag = 2,
			lifetime = {0.35, 0.45},
			size = {
				{0, 8, 0},
				{0.4, 24, 0},
				{1, 34, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.5, 0.4, 0},
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
			brightness = 1.2,
			rotation = {0, 360},
			stream = {
				{0.32, 3.28, 7, 7},
			},
			offset = {0, 0, -2},
			spread = {0, 0},
			accel = {0, 0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "MouthInflow",
			texture = "kk_trace_06",
			orientation = "VelocityParallel",
			shape = {
				type = "Sphere",
				radius = 16,
				style = "Surface",
				inout = "Inward",
			},
			speed = {50, 64},
			lifetime = {0.22, 0.28},
			size = {
				{0, 1, 0},
				{0.3, 5, 0},
				{1, 2, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.2, 0.15, 0},
				{1, 0.4, 0},
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
			brightness = 1.2,
			stream = {
				{0.4, 3.28, 30, 30},
			},
			offset = {0, 0, -2},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "MouthBolts0",
			texture = "kk_spark_05",
			lifetime = {0.07, 0.1},
			size = {
				{0, 10, 2},
				{1, 14, 2},
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
			rotation = {0, 360},
			zoffset = 4,
			stream = {
				{0.35, 3.28, 5, 5},
			},
			offset = {0, 0, -2},
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
			line_u = 0,
			emit = {},
		},
		{
			name = "MouthBolts1",
			texture = "kk_spark_06",
			lifetime = {0.07, 0.1},
			size = {
				{0, 10, 2},
				{1, 14, 2},
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
			rotation = {0, 360},
			zoffset = 4,
			stream = {
				{0.35, 3.28, 5, 5},
			},
			offset = {0, 0, -2},
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
			brightness = 1.3,
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
			texture = "kk_star_08",
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
			brightness = 1.4,
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
			texture = "kk_light_03",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			offset = {0, 0, -3},
			speed_len = {1.6, 2},
			lifetime = {0.4, 0.45},
			size = {
				{0, 28, 0},
				{0.5, 32, 0},
				{1, 29, 0},
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
			brightness = 1.2,
			rotation = {0, 360},
			stream = {
				{0.42, 3.25, 8, 8},
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
			name = "TravelSwirls",
			texture = "fx_swirl_rings",
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
			rotation = {0, 360},
			rot_speed = {-260, -200},
			stream = {
				{0.42, 2.7, 3, 3},
			},
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "NebulaTrail",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Box",
				size = {10, 10, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.9,
			},
			direction = "Top",
			spread = {180, 180},
			speed = {2, 6},
			drag = 1,
			lifetime = {1, 1.5},
			size = {
				{0, 8, 2},
				{0.4, 14, 3},
				{1, 18, 3},
			},
			transparency = {
				{0, 1, 0},
				{0.15, 0.55, 0},
				{0.65, 0.65, 0},
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
			light_emission = 0.12,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -5,
			stream = {
				{0.45, 3.28, 24, 24},
			},
			line_u = 0.5,
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			emit = {},
		},
		{
			name = "TrailStars",
			texture = "fx_spark002",
			shape = {
				type = "Box",
				size = {9, 9, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.92,
			},
			direction = "Top",
			spread = {180, 180},
			speed = {2, 10},
			drag = 1.5,
			lifetime = {0.8, 1.4},
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
			brightness = 1.8,
			rotation = {0, 45},
			stream = {
				{0.4, 3.28, 90, 90},
			},
			line_u = 0.5,
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			emit = {},
		},
		{
			name = "TrailMotes",
			texture = "fx_particle02",
			shape = {
				type = "Box",
				size = {8, 8, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.92,
			},
			direction = "Top",
			spread = {180, 180},
			speed = {3, 12},
			drag = 1.5,
			lifetime = {0.5, 0.9},
			size = {
				{0, 0, 0},
				{0.15, 0.9, 0.3},
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
			stream = {
				{0.4, 3.28, 50, 50},
			},
			line_u = 0.5,
			accel = {0, 0, 0},
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
			name = "Streaks",
			texture = "kk_trace_03",
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
			stream = {
				{0.4, 3.28, 40, 40},
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
			name = "StreaksPurple",
			texture = "kk_trace_04",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {9, 9, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.76,
			},
			line_u = 0.42,
			direction = "Front",
			spread = {4, 4},
			speed_len = {1.4, 2},
			lifetime = {0.08, 0.11},
			size = {
				{0, 12, 3},
				{1, 7, 0},
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
			stream = {
				{0.4, 3.28, 25, 25},
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
			name = "Lightning",
			texture = "fx_thunder",
			orientation = "VelocityParallel",
			direction = "Front",
			speed = {2, 2},
			shape = {
				type = "Box",
				size = {6, 6, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.8,
			},
			lifetime = {0.07, 0.11},
			size = {
				{0, 16, 4},
				{1, 18, 4},
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
			zoffset = 2,
			stream = {
				{0.4, 3.28, 8, 8},
			},
			line_u = 0.5,
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
			emit = {},
		},
		{
			name = "AuroraBlue",
			texture = "fx_aurora",
			shape = {
				type = "Box",
				size = {10, 10, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.9,
			},
			direction = "Top",
			spread = {60, 60},
			speed = {2, 5},
			lifetime = {0.6, 0.9},
			size = {
				{0, 14, 0},
				{0.5, 20, 0},
				{1, 22, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.25, 0.6, 0},
				{0.75, 0.65, 0},
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
			stream = {
				{0.4, 3.28, 9, 9},
			},
			line_u = 0.5,
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			emit = {},
		},
		{
			name = "AuroraPurple",
			texture = "fx_aurora",
			shape = {
				type = "Box",
				size = {10, 10, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.9,
			},
			direction = "Top",
			spread = {60, 60},
			speed = {2, 5},
			lifetime = {0.6, 0.9},
			size = {
				{0, 14, 0},
				{0.5, 20, 0},
				{1, 22, 0},
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
			stream = {
				{0.4, 3.28, 10, 10},
			},
			line_u = 0.5,
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
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
				{0, 14, 0},
				{0.25, 40, 0},
				{1, 44, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.5, 0.65, 0},
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
			brightness = 0.75,
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
			name = "ImpactStarBurst",
			texture = "kk_star_09",
			emit = {
				{0, 2},
			},
			on_hit = true,
			lifetime = {0.28, 0.32},
			size = {
				{0, 18, 0},
				{0.15, 46, 0},
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
			brightness = 1,
			rotation = {0, 90},
			zoffset = 5,
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
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
		},
		{
			name = "ImpactHalo",
			texture = "fx_halo",
			emit = {
				{0, 1},
				{0.05, 1},
			},
			on_hit = true,
			lifetime = {0.36, 0.4},
			size = {
				{0, 10, 0},
				{1, 80, 0},
			},
			transparency = {
				{0, 0.3, 0},
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
			light_emission = 1,
			brightness = 1.1,
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
			name = "ImpactShell",
			texture = "kk_circle_02",
			orientation = "VelocityPerpendicular",
			direction = "Back",
			speed = {0.5, 0.5},
			emit = {
				{0, 1},
			},
			on_hit = true,
			lifetime = {0.4, 0.4},
			size = {
				{0, 12, 0},
				{1, 84, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.45, 0},
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
			light_emission = 1,
			brightness = 1.2,
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
		},
		{
			name = "ImpactShellPurple",
			texture = "kk_circle_02",
			orientation = "VelocityPerpendicular",
			direction = "Back",
			speed = {0.5, 0.5},
			emit = {
				{0.06, 1},
			},
			on_hit = true,
			lifetime = {0.4, 0.4},
			size = {
				{0, 10, 0},
				{1, 66, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.5, 0},
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
			brightness = 1.2,
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
		},
		{
			name = "ImpactNebulaBurst",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 10},
			},
			on_hit = true,
			direction = "Back",
			spread = {75, 75},
			speed = {20, 45},
			drag = 2.5,
			lifetime = {0.8, 1.2},
			size = {
				{0, 8, 2},
				{0.3, 20, 3},
				{1, 26, 3},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.3, 0},
				{0.6, 0.45, 0},
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
			light_emission = 0.12,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -3,
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
		},
		{
			name = "ImpactStreakBurst",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{0, 36},
			},
			on_hit = true,
			direction = "Back",
			spread = {80, 80},
			speed = {90, 160},
			drag = 3.5,
			lifetime = {0.25, 0.4},
			size = {
				{0, 6, 0},
				{0.3, 22, 0},
				{1, 9, 0},
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
			brightness = 1.1,
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
		},
		{
			name = "ImpactPurpleBurst",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{0, 20},
			},
			on_hit = true,
			direction = "Back",
			spread = {80, 80},
			speed = {80, 150},
			drag = 3.5,
			lifetime = {0.25, 0.4},
			size = {
				{0, 6, 0},
				{0.3, 22, 0},
				{1, 9, 0},
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
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
		},
		{
			name = "ImpactThunder",
			texture = "fx_thunder",
			emit = {
				{0, 3},
				{0.08, 2},
			},
			on_hit = true,
			lifetime = {0.08, 0.12},
			size = {
				{0, 22, 0},
				{1, 26, 0},
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
			zoffset = 4,
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
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
			name = "ImpactStar",
			texture = "kk_star_08",
			lifetime = {0.08, 0.14},
			size = {
				{0, 30, 6},
				{0.5, 40, 8},
				{1, 28, 6},
			},
			transparency = {
				{0, 0.15, 0},
				{0.6, 0.3, 0},
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
			brightness = 1.3,
			rotation = {0, 360},
			zoffset = 4,
			stream = {
				{0.4, 3.28, 14, 14},
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
			name = "ImpactRings",
			texture = "kk_light_03",
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
			name = "ImpactSplash",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Back",
			spread = {80, 80},
			speed = {80, 150},
			drag = 3.5,
			lifetime = {0.22, 0.36},
			size = {
				{0, 5, 0},
				{0.3, 18, 0},
				{1, 8, 0},
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
			brightness = 1.1,
			stream = {
				{0.4, 3.28, 60, 60},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			emit = {},
		},
		{
			name = "ImpactSplashPurple",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Back",
			spread = {80, 80},
			speed = {70, 140},
			drag = 3.5,
			lifetime = {0.22, 0.36},
			size = {
				{0, 5, 0},
				{0.3, 18, 0},
				{1, 8, 0},
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
			stream = {
				{0.4, 3.28, 30, 30},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			emit = {},
		},
		{
			name = "ImpactNebula",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Back",
			spread = {70, 70},
			speed = {8, 20},
			drag = 1.5,
			lifetime = {0.6, 0.9},
			size = {
				{0, 6, 1},
				{0.4, 14, 2},
				{1, 17, 2},
			},
			transparency = {
				{0, 1, 0},
				{0.15, 0.45, 0},
				{0.65, 0.55, 0},
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
			light_emission = 0.12,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -3,
			stream = {
				{0.45, 3.28, 14, 14},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
			emit = {},
		},
		{
			name = "ImpactCubes",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Back",
			spread = {70, 70},
			speed = {40, 90},
			drag = 0.4,
			accel = {0, -160, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0.9, 0.35},
				{1, 0.7, 0.3},
			},
			color = {
				{
					0,
					{150, 154, 168},
				},
				{
					1,
					{120, 124, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			emit = {
				{0, 24},
			},
			on_hit = true,
			stream = {
				{0.4, 3.28, 22, 22},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			light_emission = 0,
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
		},
		{
			name = "ImpactStars",
			texture = "fx_spark002",
			direction = "Back",
			spread = {180, 180},
			speed = {10, 40},
			drag = 2,
			lifetime = {0.4, 0.8},
			size = {
				{0, 0, 0},
				{0.15, 2.2, 0.6},
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
			rotation = {0, 45},
			emit = {
				{0, 40},
			},
			on_hit = true,
			stream = {
				{0.4, 3.28, 40, 40},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
		},
		{
			name = "ImpactBolts0",
			texture = "kk_spark_05",
			lifetime = {0.07, 0.11},
			size = {
				{0, 12, 3},
				{1, 18, 3},
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
			rotation = {0, 360},
			zoffset = 4,
			stream = {
				{0.4, 3.28, 5, 5},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
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
			emit = {},
		},
		{
			name = "ImpactBolts1",
			texture = "kk_spark_06",
			lifetime = {0.07, 0.11},
			size = {
				{0, 12, 3},
				{1, 18, 3},
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
			rotation = {0, 360},
			zoffset = 4,
			stream = {
				{0.4, 3.28, 5, 5},
			},
			line_u = 1,
			offset = {0, 0, 3},
			impact = true,
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
			emit = {},
		},
		{
			name = "CutFlash",
			texture = "fx_glow",
			emit = {
				{3.32, 1},
			},
			lifetime = {0.25, 0.25},
			size = {
				{0, 14, 0},
				{0.3, 30, 0},
				{1, 34, 0},
			},
			transparency = {
				{0, 0.25, 0},
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
			brightness = 1,
			zoffset = 3,
			line_u = 1,
			offset = {0, 0, 3},
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
			name = "CutStars",
			texture = "fx_spark002",
			emit = {
				{3.32, 40},
			},
			direction = "Back",
			spread = {180, 180},
			speed = {8, 26},
			drag = 1.5,
			lifetime = {0.7, 1.1},
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
			brightness = 1.8,
			rotation = {0, 45},
			line_u = 1,
			offset = {0, 0, 3},
			accel = {0, 0, 0},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
		},
		{
			name = "CutNebula",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{3.32, 6},
			},
			direction = "Back",
			spread = {80, 80},
			speed = {6, 16},
			drag = 1.5,
			lifetime = {0.8, 1.2},
			size = {
				{0, 8, 2},
				{1, 20, 3},
			},
			transparency = {
				{0, 1, 0},
				{0.12, 0.5, 0},
				{0.65, 0.6, 0},
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
			light_emission = 0.12,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -3,
			line_u = 1,
			offset = {0, 0, 3},
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
		},
		{
			name = "GroundShock",
			texture = "kk_circle_02",
			emit = {
				{0.01, 1},
			},
			on_hit = true,
			at_ground = true,
			offset = {0, 0.22, 0},
			lifetime = {0.45, 0.45},
			size = {
				{0, 20, 0},
				{1, 90, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.5, 0.55, 0},
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
			name = "GroundVoid",
			texture = "fx_glow",
			emit = {
				{0.02, 1},
			},
			on_hit = true,
			at_ground = true,
			offset = {0, 0.1, 0},
			lifetime = {3.2, 3.2},
			size = {
				{0, 10, 0},
				{0.08, 34, 0},
				{1, 36, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.4, 0},
				{0.8, 0.45, 0},
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
			name = "GroundCracks",
			texture = "om_cracks",
			emit = {
				{0.03, 1},
			},
			on_hit = true,
			at_ground = true,
			offset = {0, 0.16, 0},
			lifetime = {3.2, 3.2},
			size = {
				{0, 10, 0},
				{0.08, 44, 0},
				{1, 46, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.25, 0},
				{0.12, 0.05, 0},
				{0.3, 0.15, 0},
				{0.8, 0.3, 0},
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
				{0.02, 18},
			},
			on_hit = true,
			at_ground = true,
			offset = {0, 2, 0},
			direction = "Front",
			spread = {180, 3},
			speed = {50, 90},
			drag = 3.5,
			accel = {0, 4, 0},
			lifetime = {0.9, 1.3},
			size = {
				{0, 8, 2},
				{0.3, 16, 3},
				{1, 22, 4},
			},
			transparency = {
				{0, 0.5, 0},
				{0.2, 0.35, 0},
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
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -3,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "GroundSpikes",
			texture = "fx_spikes",
			orientation = "FacingCameraWorldUp",
			at_ground = true,
			offset = {0, 3, 0},
			shape = {
				type = "Box",
				size = {12, 1, 12},
				style = "Volume",
				inout = "Outward",
			},
			lifetime = {0.22, 0.32},
			size = {
				{0, 6, 0},
				{0.5, 10, 0},
				{1, 11, 0},
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
			stream = {
				{0.45, 3.28, 14, 14},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundCubes",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			at_ground = true,
			offset = {0, 0.6, 0},
			shape = {
				type = "Box",
				size = {14, 1, 14},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {15, 35},
			accel = {0, -120, 0},
			lifetime = {0.5, 0.8},
			size = {
				{0, 0.7, 0.3},
				{1, 0.5, 0.2},
			},
			color = {
				{
					0,
					{150, 154, 168},
				},
				{
					1,
					{120, 124, 140},
				},
			},
			rotation = {0, 360},
			rot_speed = {-300, 300},
			stream = {
				{0.45, 3.28, 18, 18},
			},
			drag = 0,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			light_emission = 0,
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundStars",
			texture = "fx_spark002",
			at_ground = true,
			offset = {0, 1, 0},
			shape = {
				type = "Box",
				size = {16, 1, 16},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {20, 20},
			speed = {6, 16},
			accel = {0, 8, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.15, 2, 0.5},
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
			stream = {
				{0.5, 3.28, 14, 14},
			},
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
			name = "TrailVoid",
			texture = "fx_glow",
			trail = true,
			at_ground = true,
			offset = {0, 0.08, 0},
			lifetime = {2.4, 2.4},
			size = {
				{0, 6, 0},
				{0.08, 15, 0},
				{1, 16, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.45, 0},
				{0.8, 0.5, 0},
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
			emit = {},
		},
		{
			name = "TrailCracks",
			texture = "om_cracks",
			trail = true,
			at_ground = true,
			offset = {0, 0.14, 0},
			lifetime = {2.2, 2.2},
			size = {
				{0, 6, 0},
				{0.1, 16, 0},
				{1, 17, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.06, 0.2, 0},
				{0.3, 0.2, 0},
				{0.8, 0.35, 0},
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
				{0, 1, 0},
				{0.06, 0.45, 0},
				{0.75, 0.55, 0},
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
		{0.4, 0.9, 0.5},
		{3.3, 0.45, 0.35},
	},
	shake_ramp = {0.3, 3.3, 0.25, 0.5, 1},
	beam = {
		start = 0.3,
		grow = 0.1,
		stop = 3.3,
		fade = 0.3,
		max_len = 124,
		trail_every = 0.1,
		trail_move = 4,
		rehit = 0.3,
		light_color = {90, 150, 255},
		light_brightness = 5,
		light_range = 50,
	},
	beams = {
		{
			name = "Aura",
			texture = "om_beam_glow",
			mode = "Wrap",
			tex_len = 60,
			speed = 0.4,
			light_emission = 1,
			brightness = 0.8,
			color = {
				{
					0,
					{40, 80, 210},
				},
				{
					1,
					{30, 60, 180},
				},
			},
			transparency = {
				{0, 0.82},
				{0.03, 0.72},
				{1, 0.75},
			},
			width = 46,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.3, 0},
				{0.33, 1.3},
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
			name = "Body",
			texture = "om_beam_nebula",
			mode = "Wrap",
			tex_len = 44,
			speed = 0.9,
			light_emission = 0.1,
			brightness = 1,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{235, 240, 255},
				},
			},
			transparency = {
				{0, 0.45},
				{0.04, 0.05},
				{1, 0.08},
			},
			width = 27,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.3, 0},
				{0.33, 1.3},
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
			pulse = 0.06,
			pulse_hz = 6,
			zoffset = 0.1,
		},
		{
			name = "Strands",
			texture = "om_beam_flow",
			mode = "Wrap",
			tex_len = 30,
			speed = 2.4,
			light_emission = 0.9,
			brightness = 1.1,
			color = {
				{
					0,
					{150, 210, 255},
				},
				{
					1,
					{110, 185, 255},
				},
			},
			transparency = {
				{0, 0.5},
				{0.04, 0.3},
				{1, 0.35},
			},
			width = 21,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.3, 0},
				{0.33, 1.3},
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
			pulse = 0.08,
			pulse_hz = 9,
			zoffset = 0.2,
		},
		{
			name = "StrandsPurple",
			texture = "om_beam_flow",
			mode = "Wrap",
			tex_len = 38,
			speed = 1.5,
			light_emission = 1,
			brightness = 1.1,
			color = {
				{
					0,
					{220, 130, 255},
				},
				{
					1,
					{180, 80, 245},
				},
			},
			transparency = {
				{0, 0.6},
				{0.04, 0.42},
				{1, 0.45},
			},
			width = 17,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.3, 0},
				{0.33, 1.3},
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
			pulse = 0.08,
			pulse_hz = 7,
			zoffset = 0.25,
		},
		{
			name = "Stars",
			texture = "om_beam_stars",
			mode = "Wrap",
			tex_len = 40,
			speed = 0.7,
			light_emission = 1,
			brightness = 1.6,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{200, 230, 255},
				},
			},
			transparency = {
				{0, 0.4},
				{0.04, 0.1},
				{1, 0.15},
			},
			width = 19,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.3, 0},
				{0.33, 1.3},
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
			pulse = 0.05,
			pulse_hz = 4,
			zoffset = 0.3,
		},
		{
			name = "Core",
			texture = "om_beam_core",
			mode = "Wrap",
			tex_len = 18,
			speed = 3.2,
			light_emission = 1,
			brightness = 1.6,
			color = {
				{
					0,
					{245, 250, 255},
				},
				{
					1,
					{205, 235, 255},
				},
			},
			transparency = {
				{0, 0.3},
				{0.03, 0.05},
				{1, 0.05},
			},
			width = 4.2,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.3, 0},
				{0.33, 1.3},
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
			pulse_hz = 15,
			zoffset = 0.35,
		},
	},
}

-- OMNÍVORA: RAYO CÓSMICO de 3 s. La boca devora energía 0.3 s y suelta un rayo de nebulosa azul muy oscura con hebras celestes y púrpura y el núcleo blanco; viajan anillos y remolinos, deja una estela de nebulosa y estrellas. Se puede apuntar mientras dura: pega en la primera superficie (hasta 124 studs × escala) con halo, ondas, nebulosa, cubitos y grietas de luz en el suelo (deja una estela si lo barre). Cierra limpio.
-- origin = de dónde sale: un Attachment en la boca (lo sigue solo), una Part, un Vector3 o un CFrame.
-- target = hacia dónde apunta: el rival (Model o Part: lo sigue solo) o un punto (Vector3 o CFrame).
-- ignore = lo que el rayo atraviesa (el modelo de quien lo lanza). Se corta en la primera superficie
-- que toca y nunca pasa de su largo máximo (124 studs × escala). Devuelve un control:
--   rayo:AimAt(objetivo)     apunta a otro lado (Model, Part, Vector3 o CFrame; si se mueve, lo sigue)
--   rayo:SetDirection(dir)   apunta en una dirección (Vector3)
--   rayo:SetOrigin(origen)   cambia de dónde sale
--   rayo:Stop()              lo corta antes de tiempo
--   rayo.MaxLength           largo máximo (lo puedes cambiar); rayo.Length = largo de ahora
--   rayo.HitPosition, rayo.HitInstance = dónde y qué está tocando (nil si no toca nada)
--   rayo.Active = true mientras se ve; rayo.Holder = la Part que lo contiene
function OmnivoraVFX.CosmicBeam(origin: any, target: any, scale: number?, shake: number?, ignore: { Instance }?): BeamControl
	return playBeam(SPEC_CosmicBeam, origin, target, scale, shake, ignore)
end
-- segundos (desde la llamada) en que llega a su largo máximo y en que se corta solo
OmnivoraVFX.CosmicBeamStart = 0.4
OmnivoraVFX.CosmicBeamStop = 3.3

local SPEC_CosmicAura = {
	name = "CosmicAura",
	duration = 0,
	cleanup = 0.3,
	layers = {
		{
			name = "AuraWisps",
			aura = "surface",
			texture = "om_aura_wisp_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			spread = {35, 35},
			speed = {2, 5},
			drag = 1,
			accel = {0, 9, 0},
			lifetime = {0.8, 1.3},
			size = {
				{0, 2.5, 0.6},
				{0.3, 6, 1.2},
				{1, 8, 1.5},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.35, 0},
				{0.7, 0.5, 0},
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
			light_emission = 0.5,
			brightness = 1.1,
			rotation = {-10, 10},
			rate = 60,
			surge = 25,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "AuraWispsOut",
			aura = "surface",
			texture = "om_aura_wisp_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			spread = {20, 20},
			speed = {2, 5},
			drag = 1,
			accel = {0, 9, 0},
			lifetime = {0.8, 1.3},
			size = {
				{0, 4, 1},
				{0.3, 9, 2},
				{1, 12, 2},
			},
			transparency = {
				{0, 1, 0},
				{0.25, 0.5, 0},
				{0.7, 0.62, 0},
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
			light_emission = 0.5,
			brightness = 1.1,
			rotation = {-10, 10},
			zoffset = -2,
			rate = 16,
			surge = 8,
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "AuraTongues",
			aura = "surface",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			spread = {20, 20},
			speed = {2, 4},
			drag = 1,
			accel = {0, 10, 0},
			lifetime = {0.45, 0.7},
			size = {
				{0, 3, 0.6},
				{0.4, 6, 1.2},
				{1, 7, 1.4},
			},
			transparency = {
				{0, 1, 0},
				{0.15, 0.3, 0},
				{0.7, 0.45, 0},
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
			rotation = {-10, 10},
			rate = 45,
			surge = 20,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "AuraTongues2",
			aura = "surface",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			spread = {20, 20},
			speed = {2, 4},
			drag = 1,
			accel = {0, 10, 0},
			lifetime = {0.45, 0.7},
			size = {
				{0, 2.6, 0.5},
				{0.4, 5, 1},
				{1, 6, 1.2},
			},
			transparency = {
				{0, 1, 0},
				{0.15, 0.35, 0},
				{0.7, 0.5, 0},
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
			brightness = 1.35,
			rotation = {-10, 10},
			rate = 20,
			surge = 10,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "AuraStars",
			aura = "surface",
			texture = "fx_spark002",
			direction = "Top",
			spread = {60, 60},
			speed = {1, 3},
			drag = 1,
			accel = {0, 4, 0},
			lifetime = {0.8, 1.4},
			size = {
				{0, 0, 0},
				{0.08, 0.96, 0},
				{0.22, 0.42, 0},
				{0.38, 1.02, 0},
				{0.55, 0.36, 0},
				{0.72, 0.84, 0},
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
			rotation = {0, 45},
			rate = 40,
			surge = 25,
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
			name = "AuraMotes",
			aura = "surface",
			texture = "fx_particle02",
			direction = "Top",
			spread = {60, 60},
			speed = {1, 4},
			drag = 1.5,
			accel = {0, 6, 0},
			lifetime = {0.5, 0.9},
			size = {
				{0, 0, 0},
				{0.15, 0.32, 0.1},
				{0.8, 0.24, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{150, 200, 255},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rate = 30,
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
			name = "AuraBolts",
			aura = "surface",
			texture = "kk_spark_05",
			lifetime = {0.07, 0.1},
			size = {
				{0, 2, 0.6},
				{1, 2.6, 0.6},
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
			rotation = {0, 360},
			rate = 6,
			surge = 8,
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
			name = "AuraHalo",
			aura = "body",
			box = {0.8, 0.8, 0.8},
			texture = "fx_glow",
			lifetime = {0.6, 0.9},
			size = {
				{0, 15, 2},
				{1, 18, 2},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.8, 0},
				{0.7, 0.84, 0},
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
			rate = 6,
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
			name = "AuraStreaks",
			aura = "body",
			box = {1.05, 0.8, 1.05},
			texture = "kk_trace_03",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {5, 5},
			speed = {18, 28},
			lifetime = {0.25, 0.4},
			size = {
				{0, 0.5, 0},
				{0.3, 3, 0},
				{1, 0.6, 0},
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
			rate = 14,
			surge = 16,
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
			name = "FeetRings",
			aura = "feet",
			radius_k = 0.05,
			texture = "kk_circle_02",
			offset = {0, 0.25, 0},
			lifetime = {1, 1.2},
			size = {
				{0, 8, 0},
				{1, 20, 0},
			},
			transparency = {
				{0, 0.45, 0},
				{0.6, 0.7, 0},
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
			light_emission = 1,
			brightness = 1.1,
			rate = 1.6,
			surge = 1,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "FeetGlow",
			aura = "feet",
			radius_k = 0.05,
			texture = "fx_glow",
			offset = {0, 0.15, 0},
			lifetime = {0.6, 0.8},
			size = {
				{0, 22, 0},
				{1, 25, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.65, 0},
				{0.7, 0.7, 0},
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
			rate = 4,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
		{
			name = "FeetRise",
			aura = "feet",
			radius_k = 0.6,
			texture = "fx_spark002",
			offset = {0, 0.3, 0},
			direction = "Top",
			spread = {10, 10},
			speed = {6, 12},
			drag = 0.5,
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.08, 0.8, 0},
				{0.22, 0.35, 0},
				{0.38, 0.85, 0},
				{0.55, 0.3, 0},
				{0.72, 0.7, 0},
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
			rate = 25,
			surge = 15,
			accel = {0, 0, 0},
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
			name = "FeetTongues",
			aura = "feet",
			radius_k = 0.55,
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "FacingCameraWorldUp",
			offset = {0, 0.5, 0},
			direction = "Top",
			speed = {2, 4},
			accel = {0, 8, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 3, 0},
				{0.4, 6, 0},
				{1, 7, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.35, 0},
				{0.7, 0.5, 0},
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
			rotation = {-8, 8},
			rate = 18,
			surge = 8,
			spread = {0, 0},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
	},
	aura = {
		ref = 22,
		fade_in = 0.6,
		fade_out = 0.7,
		surge = 2.2,
		pulse_hz = 0.8,
		max_parts = 30,
		outline = {
			{90, 170, 255},
			{200, 120, 255},
		},
		outline_t = {0, 0.35},
		fill = {20, 40, 140},
		fill_t = {0.74, 0.88},
		light_color = {90, 150, 255},
		light_brightness = 2.5,
		light_range = 26,
		life_max = 1.4,
	},
}

-- OMNÍVORA: AURA CÓSMICA que se adapta a cualquier modelo. Delinea todo su cuerpo (celeste que respira hacia el púrpura) y de toda su silueta emanan lenguas de nebulosa azul muy oscura con venas celestes, energía celeste y púrpura, estrellas y chispas; a los pies, anillos que se abren y destellos que suben. Cada 2.2 s, una oleada.
-- model = el modelo (Model o Part): el aura se adapta sola a su forma y a su tamaño y lo sigue si se mueve
-- (22 studs de alto = tamaño 1; scale lo multiplica). duration = segundos que dura (nil = hasta que la
-- apagues); intensity = 1 normal (0.5 suave, 1.5 fuerte). Devuelve un control:
--   aura:Stop(fade)          la apaga (se desvanece en fade s; nil = el de siempre)
--   aura:SetIntensity(k)     más fuerte o más suave mientras dura
--   aura.Active = true mientras se ve; aura.Holder = la Part que la contiene
function OmnivoraVFX.CosmicAura(model: Instance, scale: number?, duration: number?, intensity: number?): AuraControl
	return playAura(SPEC_CosmicAura, model, scale, duration, intensity)
end

local SPEC_CataclysmImpact = {
	name = "CataclysmImpact",
	duration = 5.6,
	cleanup = 9.1,
	layers = {
		{
			name = "ImpFlash",
			texture = "fx_glow",
			emit = {
				{0, 2},
			},
			lifetime = {0.28, 0.32},
			size = {
				{0, 30, 0},
				{0.25, 100, 0},
				{1, 100, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.5, 0},
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
			brightness = 1.3,
			offset = {0, 12, 0},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "ImpStar",
			texture = "kk_star_09",
			emit = {
				{0, 2},
			},
			lifetime = {0.3, 0.36},
			size = {
				{0, 30, 0},
				{0.15, 100, 0},
				{1, 25, 0},
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
			brightness = 1.3,
			rotation = {0, 90},
			offset = {0, 14, 0},
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
			line_u = 0,
		},
		{
			name = "ImpShock",
			texture = "kk_circle_02",
			emit = {
				{0, 1},
			},
			lifetime = {0.6, 0.6},
			size = {
				{0, 40, 0},
				{1, 560, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.55, 0},
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
			light_emission = 0.45,
			offset = {0, 0.6, 0},
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
			name = "ImpShockSharp",
			texture = "kk_circle_02",
			emit = {
				{0.04, 1},
			},
			lifetime = {0.42, 0.42},
			size = {
				{0, 40, 0},
				{1, 760, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.6, 0},
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
			light_emission = 0.6,
			offset = {0, 0.7, 0},
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
			name = "ImpCrater",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			lifetime = {5.4, 5.4},
			size = {
				{0, 30, 0},
				{0.03, 220, 0},
				{1, 230, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.03, 0.15, 0},
				{0.8, 0.3, 0},
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
			offset = {0, 0.3, 0},
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
			name = "ImpCracks",
			texture = "om_cracks",
			emit = {
				{0.02, 1},
			},
			lifetime = {5.2, 5.2},
			size = {
				{0, 60, 0},
				{0.05, 340, 0},
				{1, 360, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.03, 0.2, 0},
				{0.1, 0.02, 0},
				{0.4, 0.2, 0},
				{0.85, 0.35, 0},
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
			rotation = {0, 360},
			offset = {0, 0.5, 0},
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
			name = "ImpScorch",
			texture = "kz_scorch",
			emit = {
				{0, 1},
			},
			lifetime = {5.5, 5.5},
			size = {
				{0, 40, 0},
				{0.03, 300, 0},
				{1, 310, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.03, 0.3, 0},
				{0.8, 0.45, 0},
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
			rotation = {0, 360},
			offset = {0, 0.4, 0},
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
			name = "ImpRocks",
			type = "meteor",
			emit = {
				{0, 14},
			},
			direction = "Top",
			spread = {60, 60},
			speed = {160, 300},
			accel = {0, -196, 0},
			drag = 0.15,
			lifetime = {1.6, 2.4},
			trails = {
				{
					name = "ImpRockDust",
					rate = 28,
					texture = "kk_smoke_04",
					speed = {1, 6},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					accel = {0, 5, 0},
					lifetime = {0.6, 1},
					size = {
						{0, 8, 2},
						{1, 26, 4},
					},
					transparency = {
						{0, 0.45, 0},
						{0.6, 0.6, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{138, 144, 170},
						},
						{
							0.5,
							{112, 118, 146},
						},
						{
							1,
							{90, 96, 124},
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
					name = "ImpRockSparks",
					rate = 20,
					texture = "fx_spark002",
					speed = {0, 8},
					direction = "Top",
					spread = {180, 180},
					lifetime = {0.4, 0.7},
					size = {
						{0, 0, 0},
						{0.08, 5.12, 0},
						{0.22, 2.24, 0},
						{0.38, 5.44, 0},
						{0.55, 1.92, 0},
						{0.72, 4.48, 0},
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
					rotation = {0, 45},
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
					name = "ImpRockPuff",
					texture = "kk_smoke_07",
					emit = {
						{0, 4},
					},
					direction = "Top",
					spread = {70, 70},
					speed = {10, 30},
					drag = 2,
					accel = {0, 4, 0},
					lifetime = {1, 1.5},
					size = {
						{0, 12, 3},
						{1, 34, 6},
					},
					transparency = {
						{0, 0.45, 0},
						{0.4, 0.6, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{138, 144, 170},
						},
						{
							0.5,
							{112, 118, 146},
						},
						{
							1,
							{90, 96, 124},
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
			},
			offset = {0, 0, 0},
			rock = {
				size = {8, 22},
				spin = {-360, 360},
				material = "Slate",
				color = {112, 116, 130},
				aspect = {1, 0.8, 0.9},
				upright = false,
				stick = 0,
				sink = 0.3,
			},
			shatter = {},
		},
		{
			name = "ImpDust",
			texture = "kk_smoke_07",
			emit = {
				{0, 34},
			},
			shape = {
				type = "Sphere",
				radius = 20,
				style = "Surface",
				inout = "Outward",
			},
			speed = {60, 180},
			drag = 2.5,
			accel = {0, 8, 0},
			lifetime = {2.6, 4},
			size = {
				{0, 50, 10},
				{0.3, 90, 10},
				{1, 100, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.3, 0.5, 0},
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
			rotation = {0, 360},
			rot_speed = {-30, 30},
			offset = {0, 10, 0},
			zoffset = -3,
			spread = {0, 0},
			direction = "Top",
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "ImpColumn",
			texture = "kk_smoke_07",
			emit = {
				{0.03, 22},
			},
			direction = "Top",
			spread = {12, 12},
			speed = {120, 320},
			drag = 1.6,
			lifetime = {2.2, 3.4},
			size = {
				{0, 50, 10},
				{0.3, 100, 0},
				{1, 100, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.4, 0.5, 0},
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
			rotation = {0, 360},
			rot_speed = {-30, 30},
			offset = {0, 10, 0},
			zoffset = -3,
			accel = {0, 0, 0},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "ImpDustRing",
			texture = "kk_smoke_04",
			emit = {
				{0.02, 40},
			},
			direction = "Front",
			spread = {180, 3},
			speed = {260, 450},
			drag = 3,
			accel = {0, 6, 0},
			lifetime = {1.6, 2.3},
			size = {
				{0, 40, 8},
				{1, 100, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{138, 144, 170},
				},
				{
					0.5,
					{112, 118, 146},
				},
				{
					1,
					{90, 96, 124},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			offset = {0, 8, 0},
			zoffset = -3,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "ImpNebula",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 12},
			},
			shape = {
				type = "Sphere",
				radius = 15,
				style = "Surface",
				inout = "Outward",
			},
			speed = {40, 120},
			drag = 2,
			lifetime = {1.6, 2.6},
			size = {
				{0, 60, 0},
				{0.3, 100, 0},
				{1, 100, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.35, 0},
				{0.6, 0.5, 0},
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
			light_emission = 0.15,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			offset = {0, 18, 0},
			zoffset = -2,
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "ImpStreaks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{0, 50},
			},
			shape = {
				type = "Sphere",
				radius = 10,
				style = "Surface",
				inout = "Outward",
			},
			speed = {300, 600},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 10, 0},
				{0.3, 70, 0},
				{1, 20, 0},
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
			brightness = 1.3,
			offset = {0, 10, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
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
			name = "ImpPurple",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			emit = {
				{0, 30},
			},
			shape = {
				type = "Sphere",
				radius = 10,
				style = "Surface",
				inout = "Outward",
			},
			speed = {260, 520},
			drag = 2,
			lifetime = {0.3, 0.5},
			size = {
				{0, 10, 0},
				{0.3, 70, 0},
				{1, 20, 0},
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
			brightness = 1.35,
			offset = {0, 10, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
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
			name = "ImpStars",
			texture = "fx_spark002",
			emit = {
				{0, 80},
			},
			shape = {
				type = "Sphere",
				radius = 10,
				style = "Surface",
				inout = "Outward",
			},
			speed = {60, 260},
			drag = 1.5,
			lifetime = {1, 2},
			size = {
				{0, 0, 0},
				{0.08, 7.68, 0},
				{0.22, 3.36, 0},
				{0.38, 8.16, 0},
				{0.55, 2.88, 0},
				{0.72, 6.72, 0},
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
			brightness = 1.9,
			rotation = {0, 45},
			offset = {0, 12, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
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
			name = "ImpLingerDust",
			texture = "kk_smoke_07",
			direction = "Top",
			spread = {60, 60},
			speed = {10, 30},
			drag = 0.5,
			accel = {0, 5, 0},
			lifetime = {3.5, 5},
			size = {
				{0, 70, 10},
				{1, 100, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.55, 0},
				{0.75, 0.7, 0},
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
			rotation = {0, 360},
			rot_speed = {-15, 15},
			zoffset = -4,
			shape = {
				type = "Box",
				size = {220, 10, 220},
				style = "Volume",
				inout = "Outward",
			},
			stream = {
				{0.3, 3.8, 18, 3},
			},
			offset = {0, 10, 0},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "ImpLingerMotes",
			texture = "fx_particle02",
			direction = "Top",
			spread = {50, 50},
			speed = {6, 22},
			drag = 0.4,
			accel = {0, 4, 0},
			lifetime = {1.6, 2.8},
			size = {
				{0, 0, 0},
				{0.15, 6, 2},
				{0.8, 4, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{220, 240, 255},
				},
				{
					1,
					{120, 180, 255},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			shape = {
				type = "Box",
				size = {200, 20, 200},
				style = "Volume",
				inout = "Outward",
			},
			stream = {
				{0.2, 4.2, 22, 3},
			},
			offset = {0, 12, 0},
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
	shakes = {
		{0, 1.4, 0.7},
	},
	light = {
		color = {150, 200, 255},
		brightness = 8,
		range = 60,
		time = 0.9,
	},
}

-- OMNÍVORA: el impacto de una víctima que cae desde el cielo bajo una gravedad descomunal: destello, ondas de choque, cráter oscuro con grietas de luz, rocas que salen disparadas, una nube densa de polvo y residuos cósmicos que quedan unos 5 s. cf = el punto del suelo.
function OmnivoraVFX.CataclysmImpact(cf: CFrame, scale: number?, shake: number?): Part
	return play(SPEC_CataclysmImpact, cf, scale, nil, shake)
end

local SPEC_GravitationalCataclysm = {
	name = "GravitationalCataclysm",
	duration = 23,
	cleanup = 23.3,
	layers = {
		{
			name = "StormDust",
			role = "storm",
			locked = true,
			texture = "kk_smoke_07",
			direction = "Top",
			spread = {40, 40},
			speed = {5, 20},
			accel = {0, 6, 0},
			lifetime = {2.6, 3.6},
			size = {
				{0, 60, 15},
				{1, 100, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.72, 0},
				{0.7, 0.78, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{138, 144, 170},
				},
				{
					0.5,
					{112, 118, 146},
				},
				{
					1,
					{90, 96, 124},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -4,
			rate = 5,
			env = {
				{0, 0},
				{2.4, 0.15},
				{5, 0.8},
				{7.5, 1},
				{10.6, 1.25},
				{12.6, 1.1},
				{13.8, 0.3},
				{14.2, 0},
			},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "StormDark",
			role = "storm",
			locked = true,
			texture = "kk_smoke_04",
			direction = "Top",
			spread = {40, 40},
			speed = {4, 14},
			lifetime = {2.4, 3.2},
			size = {
				{0, 70, 15},
				{1, 100, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.55, 0},
				{0.7, 0.62, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{30, 38, 80},
				},
				{
					1,
					{16, 22, 52},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -5,
			rate = 1.6,
			env = {
				{0, 0},
				{2.4, 0.15},
				{5, 0.8},
				{7.5, 1},
				{10.6, 1.25},
				{12.6, 1.1},
				{13.8, 0.3},
				{14.2, 0},
			},
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "StormNebula",
			role = "storm",
			locked = true,
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {40, 40},
			speed = {4, 14},
			lifetime = {2.2, 3},
			size = {
				{0, 70, 15},
				{1, 100, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.5, 0},
				{0.7, 0.58, 0},
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
			light_emission = 0.15,
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -3,
			rate = 2.4,
			env = {
				{0, 0},
				{2.4, 0.15},
				{5, 0.8},
				{7.5, 1},
				{10.6, 1.25},
				{12.6, 1.1},
				{13.8, 0.3},
				{14.2, 0},
			},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "StormMotes",
			role = "storm",
			locked = true,
			texture = "fx_spark002",
			direction = "Top",
			spread = {60, 60},
			speed = {10, 30},
			lifetime = {1.2, 2},
			size = {
				{0, 0, 0},
				{0.08, 9.6, 0},
				{0.22, 4.2, 0},
				{0.38, 10.2, 0},
				{0.55, 3.6, 0},
				{0.72, 8.4, 0},
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
			rotation = {0, 45},
			rate = 8,
			env = {
				{0, 0},
				{2.4, 0.15},
				{5, 0.8},
				{7.5, 1},
				{10.6, 1.25},
				{12.6, 1.1},
				{13.8, 0.3},
				{14.2, 0},
			},
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
			name = "StormPebbles",
			role = "storm",
			locked = true,
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {30, 30},
			speed = {10, 30},
			lifetime = {2.5, 3.5},
			size = {
				{0, 5, 2},
				{1, 4, 1.5},
			},
			color = {
				{
					0,
					{150, 154, 168},
				},
				{
					1,
					{112, 116, 132},
				},
			},
			rotation = {0, 360},
			rot_speed = {-300, 300},
			rate = 10,
			env = {
				{0, 0},
				{2.4, 0.15},
				{5, 0.8},
				{7.5, 1},
				{10.6, 1.25},
				{12.6, 1.1},
				{13.8, 0.3},
				{14.2, 0},
			},
			accel = {0, 0, 0},
			drag = 0,
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
			name = "StormStreaks",
			role = "storm",
			locked = true,
			texture = "kk_trace_03",
			orientation = "VelocityParallel",
			direction = "Front",
			spread = {6, 6},
			speed = {90, 170},
			lifetime = {0.4, 0.7},
			size = {
				{0, 10, 0},
				{0.3, 55, 0},
				{1, 15, 0},
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
			rate = 2.2,
			env = {
				{0, 0},
				{2.4, 0.15},
				{5, 0.8},
				{7.5, 1},
				{10.6, 1.25},
				{12.6, 1.1},
				{13.8, 0.3},
				{14.2, 0},
			},
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
			name = "FrontDust",
			role = "front",
			texture = "kk_smoke_07",
			direction = "Top",
			spread = {35, 35},
			speed = {15, 40},
			drag = 0.5,
			accel = {0, 4, 0},
			lifetime = {2.5, 3.5},
			size = {
				{0, 50, 10},
				{1, 100, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.15, 0.62, 0},
				{0.7, 0.72, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{138, 144, 170},
				},
				{
					0.5,
					{112, 118, 146},
				},
				{
					1,
					{90, 96, 124},
				},
			},
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -4,
			rate = 8,
			env = {
				{0, 0.4},
				{0.5, 1},
				{3.6, 1},
				{4.4, 0},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "FrontPebbles",
			role = "front",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {25, 25},
			speed = {20, 60},
			accel = {0, 10, 0},
			lifetime = {3, 4},
			size = {
				{0, 5, 2},
				{1, 4, 1.5},
			},
			color = {
				{
					0,
					{150, 154, 168},
				},
				{
					1,
					{112, 116, 132},
				},
			},
			rotation = {0, 360},
			rot_speed = {-300, 300},
			rate = 24,
			env = {
				{0, 0.3},
				{0.6, 1},
				{3.6, 1},
				{4.4, 0},
			},
			drag = 0,
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
			name = "FrontMotes",
			role = "front",
			texture = "fx_particle02",
			direction = "Top",
			spread = {40, 40},
			speed = {10, 35},
			lifetime = {1.5, 2.5},
			size = {
				{0, 0, 0},
				{0.15, 7, 2},
				{0.8, 5, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{220, 240, 255},
				},
				{
					1,
					{120, 180, 255},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rate = 16,
			env = {
				{0, 0.5},
				{0.6, 1},
				{3.6, 1},
				{4.4, 0},
			},
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
			name = "Updraft",
			role = "updraft",
			texture = "kk_trace_03",
			orientation = "VelocityParallel",
			direction = "Front",
			spread = {6, 6},
			speed = {350, 700},
			lifetime = {0.7, 1.2},
			size = {
				{0, 10, 0},
				{0.3, 75, 0},
				{1, 20, 0},
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
			rate = 6,
			env = {
				{0, 0},
				{2.4, 0},
				{5, 0.8},
				{7.5, 1},
				{12.6, 1.3},
				{13.8, 0.2},
				{14.2, 0},
			},
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
			name = "UpdraftPurple",
			role = "updraft",
			texture = "kk_trace_04",
			orientation = "VelocityParallel",
			direction = "Front",
			spread = {8, 8},
			speed = {300, 600},
			lifetime = {0.7, 1.1},
			size = {
				{0, 10, 0},
				{0.3, 60, 0},
				{1, 18, 0},
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
			rate = 3,
			env = {
				{0, 0},
				{3, 0},
				{6, 0.8},
				{8, 1},
				{12.6, 1.2},
				{13.8, 0.2},
				{14.2, 0},
			},
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
			name = "UpdraftMotes",
			role = "updraft",
			texture = "fx_spark002",
			direction = "Front",
			spread = {15, 15},
			speed = {100, 220},
			lifetime = {1, 1.8},
			size = {
				{0, 0, 0},
				{0.08, 7.68, 0},
				{0.22, 3.36, 0},
				{0.38, 8.16, 0},
				{0.55, 2.88, 0},
				{0.72, 6.72, 0},
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
			rotation = {0, 45},
			rate = 10,
			env = {
				{0, 0},
				{2.4, 0},
				{5, 1},
				{12.6, 1.2},
				{14.2, 0},
			},
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
			name = "EddyDust",
			role = "eddy",
			locked = true,
			texture = "kk_smoke_04",
			direction = "Top",
			spread = {30, 30},
			speed = {4, 12},
			lifetime = {1.5, 2.2},
			size = {
				{0, 45, 10},
				{1, 90, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.68, 0},
				{0.7, 0.75, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{138, 144, 170},
				},
				{
					0.5,
					{112, 118, 146},
				},
				{
					1,
					{90, 96, 124},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -2,
			rate = 7,
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EddySwirl",
			role = "eddy",
			locked = true,
			texture = "fx_swirl_rings",
			lifetime = {1, 1.4},
			size = {
				{0, 60, 0},
				{1, 100, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.55, 0},
				{0.75, 0.6, 0},
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
			light_emission = 0.7,
			brightness = 1.1,
			rotation = {0, 360},
			rot_speed = {-260, -180},
			rate = 1.6,
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
			name = "EddyWind",
			role = "eddy",
			locked = true,
			texture = "fx_wind_swirl",
			lifetime = {0.9, 1.3},
			size = {
				{0, 70, 0},
				{1, 100, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.5, 0},
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
			light_emission = 0.8,
			brightness = 1.1,
			rotation = {0, 360},
			rot_speed = {160, 240},
			rate = 1.4,
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
			name = "HoleInflow",
			role = "hole",
			shell = 3.3,
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			lifetime = {0.38, 0.46},
			size = {
				{0, 8, 0},
				{0.4, 70, 0},
				{1, 22, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.25, 0.1, 0},
				{1, 0.4, 0},
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
			brightness = 1.4,
			rate = 150,
			env = {
				{0, 0},
				{6.4, 0},
				{8, 0.3},
				{10.6, 0.7},
				{12.6, 1},
				{14.2, 0.35},
				{16, 0.6},
				{16.6, 1},
				{16.62, 0},
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
			name = "HoleInflowPurple",
			role = "hole",
			shell = 3.6,
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			lifetime = {0.4, 0.5},
			size = {
				{0, 8, 0},
				{0.4, 70, 0},
				{1, 22, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.25, 0.1, 0},
				{1, 0.4, 0},
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
			brightness = 1.4,
			rate = 70,
			env = {
				{0, 0},
				{6.4, 0},
				{8, 0.3},
				{10.6, 0.7},
				{12.6, 1},
				{14.2, 0.35},
				{16.6, 0.8},
				{16.62, 0},
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
			name = "HoleStars",
			role = "hole",
			shell = 2.9,
			texture = "fx_spark002",
			lifetime = {0.45, 0.55},
			size = {
				{0, 0, 0},
				{0.25, 9, 0},
				{1, 3, 0},
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
			rotation = {0, 45},
			rate = 80,
			env = {
				{0, 0},
				{6.4, 0.2},
				{10.6, 0.8},
				{12.6, 1},
				{14.2, 0.4},
				{16.62, 0},
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
			name = "HoleDebris",
			role = "hole",
			shell = 4,
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			lifetime = {0.55, 0.7},
			size = {
				{0, 6, 2},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{150, 154, 168},
				},
				{
					1,
					{112, 116, 132},
				},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			rate = 60,
			env = {
				{0, 0},
				{8, 0},
				{10.6, 0.6},
				{12.6, 1},
				{14, 0.2},
				{14.4, 0},
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
			light_emission = 0,
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CritBolts",
			role = "crit",
			shell = 1.3,
			texture = "fx_thunder",
			lifetime = {0.08, 0.12},
			size = {
				{0, 80, 15},
				{1, 100, 0},
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
			rate = 26,
			env = {
				{0, 0},
				{14.4, 0},
				{15.6, 0.5},
				{16.6, 1},
				{16.62, 0},
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
			name = "CritSparks",
			role = "crit",
			shell = 1.1,
			outward = true,
			texture = "fx_spark002",
			speed = {60, 160},
			lifetime = {0.5, 0.9},
			size = {
				{0, 0, 0},
				{0.08, 9.6, 0},
				{0.22, 4.2, 0},
				{0.38, 10.2, 0},
				{0.55, 3.6, 0},
				{0.72, 8.4, 0},
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
			brightness = 1.9,
			rotation = {0, 45},
			rate = 90,
			env = {
				{0, 0},
				{14.4, 0.2},
				{16.6, 1},
				{16.62, 0},
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
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "VictimAura",
			role = "victim",
			locked = true,
			texture = "om_aura_wisp_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "FacingCameraWorldUp",
			direction = "Top",
			spread = {25, 25},
			speed = {4, 12},
			lifetime = {0.6, 1},
			size = {
				{0, 15, 4},
				{0.3, 35, 6},
				{1, 45, 8},
			},
			transparency = {
				{0, 1, 0},
				{0.2, 0.35, 0},
				{0.7, 0.5, 0},
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
			light_emission = 0.5,
			rate = 30,
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
			name = "VictimSparks",
			role = "victim",
			locked = true,
			texture = "fx_spark002",
			direction = "Top",
			spread = {60, 60},
			speed = {10, 30},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.08, 6.4, 0},
				{0.22, 2.8, 0},
				{0.38, 6.8, 0},
				{0.55, 2.4, 0},
				{0.72, 5.6, 0},
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
			rotation = {0, 45},
			rate = 30,
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
			name = "FallTrail",
			role = "trail",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {25, 25},
			speed = {10, 30},
			drag = 1,
			lifetime = {0.8, 1.2},
			size = {
				{0, 40, 8},
				{1, 100, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.5, 0.55, 0},
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
			light_emission = 0.2,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			rate = 70,
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "FallStreaks",
			role = "trail",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {5, 5},
			speed = {200, 420},
			lifetime = {0.25, 0.4},
			size = {
				{0, 20, 0},
				{0.3, 90, 0},
				{1, 30, 0},
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
			brightness = 1.3,
			rate = 45,
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
			name = "BurstDust",
			role = "burst",
			texture = "kk_smoke_07",
			shape = {
				type = "Sphere",
				radius = 0.5,
				style = "Surface",
				inout = "Outward",
			},
			speed = {30, 80},
			drag = 2,
			accel = {0, 4, 0},
			lifetime = {1, 1.6},
			size = {
				{0, 25, 6},
				{1, 60, 10},
			},
			transparency = {
				{0, 0.5, 0},
				{0.3, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{138, 144, 170},
				},
				{
					0.5,
					{112, 118, 146},
				},
				{
					1,
					{90, 96, 124},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			spread = {0, 0},
			direction = "Top",
			light_emission = 0,
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "BurstSparks",
			role = "burst",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Sphere",
				radius = 0.5,
				style = "Surface",
				inout = "Outward",
			},
			speed = {120, 260},
			drag = 2,
			lifetime = {0.25, 0.4},
			size = {
				{0, 5, 0},
				{0.3, 30, 0},
				{1, 10, 0},
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
			brightness = 1.3,
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
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
			name = "BurstDebris",
			role = "burst",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Sphere",
				radius = 0.5,
				style = "Surface",
				inout = "Outward",
			},
			speed = {40, 110},
			drag = 1,
			lifetime = {0.8, 1.4},
			size = {
				{0, 6, 2},
				{1, 3, 0},
			},
			color = {
				{
					0,
					{150, 154, 168},
				},
				{
					1,
					{112, 116, 132},
				},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
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
			name = "BurstFlash",
			role = "burst",
			texture = "kk_star_09",
			lifetime = {0.22, 0.28},
			size = {
				{0, 30, 0},
				{0.2, 90, 0},
				{1, 20, 0},
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
			name = "ConsumeFlash",
			role = "burst",
			texture = "fx_glow",
			lifetime = {0.2, 0.25},
			size = {
				{0, 30, 0},
				{0.3, 80, 0},
				{1, 40, 0},
			},
			transparency = {
				{0, 0.2, 0},
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
			brightness = 1.3,
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
			name = "DetStreaks",
			role = "det",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Sphere",
				radius = 0.5,
				style = "Surface",
				inout = "Outward",
			},
			speed = {900, 1600},
			drag = 0.6,
			lifetime = {0.5, 0.9},
			size = {
				{0, 20, 0},
				{0.3, 100, 0},
				{1, 40, 0},
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
			brightness = 1.3,
			n = 150,
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
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
			name = "DetPurple",
			role = "det",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Sphere",
				radius = 0.5,
				style = "Surface",
				inout = "Outward",
			},
			speed = {800, 1400},
			drag = 0.6,
			lifetime = {0.5, 0.9},
			size = {
				{0, 20, 0},
				{0.3, 100, 0},
				{1, 40, 0},
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
			brightness = 1.35,
			n = 80,
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
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
			name = "DetNebula",
			role = "det",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Sphere",
				radius = 0.5,
				style = "Surface",
				inout = "Outward",
			},
			speed = {150, 420},
			drag = 1.5,
			lifetime = {1.6, 2.4},
			size = {
				{0, 60, 0},
				{0.3, 100, 0},
				{1, 100, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.3, 0},
				{0.6, 0.45, 0},
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
			light_emission = 0.15,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -3,
			n = 50,
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "DetStars",
			role = "det",
			texture = "fx_spark002",
			shape = {
				type = "Sphere",
				radius = 0.5,
				style = "Surface",
				inout = "Outward",
			},
			speed = {100, 600},
			drag = 1.2,
			lifetime = {1.2, 2.2},
			size = {
				{0, 0, 0},
				{0.08, 12.8, 0},
				{0.22, 5.6, 0},
				{0.38, 13.6, 0},
				{0.55, 4.8, 0},
				{0.72, 11.2, 0},
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
			brightness = 1.9,
			rotation = {0, 45},
			n = 260,
			spread = {0, 0},
			direction = "Top",
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
			emit = {},
		},
		{
			name = "DetBolts",
			role = "det",
			texture = "fx_thunder",
			shape = {
				type = "Sphere",
				radius = 0.8,
				style = "Surface",
				inout = "Outward",
			},
			lifetime = {0.1, 0.16},
			size = {
				{0, 90, 0},
				{1, 100, 0},
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
			brightness = 1.6,
			rotation = {0, 360},
			n = 18,
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
			name = "DetFlash",
			role = "det",
			texture = "fx_glow",
			lifetime = {0.4, 0.4},
			size = {
				{0, 60, 0},
				{0.2, 100, 0},
				{1, 100, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.4, 0.4, 0},
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
			brightness = 1.4,
			n = 6,
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
			name = "WallDust",
			role = "wall",
			texture = "kk_smoke_07",
			direction = "Top",
			spread = {40, 40},
			speed = {40, 110},
			drag = 1.2,
			accel = {0, 6, 0},
			lifetime = {1.8, 2.8},
			size = {
				{0, 60, 10},
				{1, 100, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.3, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{138, 144, 170},
				},
				{
					0.5,
					{112, 118, 146},
				},
				{
					1,
					{90, 96, 124},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -3,
			rate = 18,
			env = {
				{16.62, 0},
				{16.77, 1},
				{17.92, 0.7},
				{18.22, 0},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "WallSparks",
			role = "wall",
			texture = "fx_spark002",
			direction = "Top",
			spread = {50, 50},
			speed = {60, 200},
			drag = 1,
			lifetime = {0.8, 1.4},
			size = {
				{0, 0, 0},
				{0.08, 9.6, 0},
				{0.22, 4.2, 0},
				{0.38, 10.2, 0},
				{0.55, 3.6, 0},
				{0.72, 8.4, 0},
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
			rotation = {0, 45},
			rate = 20,
			env = {
				{16.62, 0},
				{16.77, 1},
				{17.92, 0.5},
				{18.22, 0},
			},
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
			emit = {},
		},
		{
			name = "AfterDust",
			role = "after",
			texture = "kk_smoke_07",
			direction = "Top",
			spread = {40, 40},
			speed = {8, 25},
			drag = 0.6,
			accel = {0, 3, 0},
			lifetime = {3.5, 5},
			size = {
				{0, 60, 10},
				{1, 100, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.25, 0.5, 0},
				{0.75, 0.62, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{138, 144, 170},
				},
				{
					0.5,
					{112, 118, 146},
				},
				{
					1,
					{90, 96, 124},
				},
			},
			rotation = {0, 360},
			rot_speed = {-15, 15},
			zoffset = -4,
			rate = 4.5,
			env = {
				{16.62, 0},
				{16.92, 1},
				{19.12, 0.8},
				{21.22, 0},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "AfterMotes",
			role = "after",
			texture = "fx_spark002",
			direction = "Top",
			spread = {70, 70},
			speed = {5, 20},
			drag = 0.5,
			accel = {0, 4, 0},
			lifetime = {1.8, 3},
			size = {
				{0, 0, 0},
				{0.08, 10.24, 0},
				{0.22, 4.48, 0},
				{0.38, 10.88, 0},
				{0.55, 3.84, 0},
				{0.72, 8.96, 0},
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
			brightness = 1.9,
			rotation = {0, 45},
			rate = 14,
			env = {
				{16.62, 0},
				{17.02, 1},
				{19.62, 0.6},
				{21.62, 0},
			},
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
			name = "AfterNebula",
			role = "after",
			texture = "om_nebula_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {60, 60},
			speed = {4, 14},
			lifetime = {2.5, 3.6},
			size = {
				{0, 60, 0},
				{1, 100, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.25, 0.65, 0},
				{0.7, 0.72, 0},
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
			light_emission = 0.12,
			rotation = {0, 360},
			rot_speed = {-15, 15},
			zoffset = -3,
			rate = 1.6,
			env = {
				{16.62, 0},
				{17.02, 1},
				{19.62, 0.5},
				{21.22, 0},
			},
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundCrack",
			role = "decal",
			texture = "om_cracks",
			lifetime = {5.5, 7},
			size = {
				{0, 30, 0},
				{0.06, 240, 0},
				{1, 260, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.04, 0.25, 0},
				{0.1, 0.05, 0},
				{0.4, 0.2, 0},
				{0.85, 0.35, 0},
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
			name = "GroundVoid",
			role = "decal",
			texture = "fx_glow",
			lifetime = {6, 7.5},
			size = {
				{0, 20, 0},
				{0.05, 160, 0},
				{1, 170, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.35, 0},
				{0.8, 0.45, 0},
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
			name = "GroundScar",
			role = "decal",
			texture = "kz_scorch",
			lifetime = {6, 7.5},
			size = {
				{0, 20, 0},
				{0.05, 200, 0},
				{1, 210, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.4, 0},
				{0.8, 0.5, 0},
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
	},
	cataclysm = {
		radius = 1786,
		height = 760,
		t = {
			front = {0, 3.6},
			lift = {0.2, 3},
			swirl = {2.4, 7.5},
			swirl_up = {10.6, 13},
			sing = {6.4, 12.4},
			attract = {6.8, 10.6, 12.4},
			victims = {10.8, 13.6},
			crit = {14.4, 16.6},
			det = 16.62,
			["end"] = 23,
		},
		phases = {
			{"Despertar gravitacional", 0},
			{"Formación del vórtice", 2.4},
			{"La singularidad emerge", 6.4},
			{"Consumo total", 10.6},
			{"Masa crítica", 14.4},
			{"Detonación cósmica", 16.62},
			{"Impacto planetario", 17.15},
			{"Secuelas cósmicas", 17.6},
		},
		field = {
			omega0 = 0.16,
			omega_pow = 0.6,
			r_core = 0.12,
			swirl_boost = 0.9,
			a_mid = 0.35,
			c_in = 0.62,
			c_up = 1.4,
			c_rise = 0.9,
			funnel = 0.45,
			turb_r = 0.025,
			turb_y = 0.02,
			capture = 1.3,
		},
		hole = {
			rb = {6, 150},
			crit_shrink = 0.82,
			halo = 6.5,
			photon = 2.35,
			purple = 2.85,
			swirl = 6,
			wind = 7.6,
			disk = 8,
			lens = 4.2,
			glow = {2.6, 10.5},
			spin_swirl = -260,
			spin_wind = 170,
			spin_disk = -45,
			tilt = 22,
			shell = 3.3,
			pulse_hz = {1, 7},
		},
		rocks = {
			medium = {
				rate = {
					{1, 3, 4, 12},
					{3, 10, 12, 12},
					{10, 11.5, 12, 0},
				},
				size = {6, 26},
				skew = 1.8,
				aspect = {0.55, 1.1},
				max = 140,
				tremble = {0.25, 0.9},
				shoot = 0.22,
				band = {0.04, 0.5},
				rise = {0.5, 1.3},
				w = {0.75, 1.3},
				inward = {0.7, 1.3},
				break_p = 0.22,
				break_t = {4.5, 12.5},
				dark = 0.45,
			},
			chunk = {
				rate = {
					{2, 9.5, 1.3, 1.3},
				},
				size = {45, 110},
				skew = 1.4,
				aspect = {0.28, 0.5},
				max = 18,
				tremble = {0.6, 1.4},
				shoot = 0.12,
				band = {0.03, 0.3},
				rise = {0.32, 0.7},
				w = {0.7, 1.1},
				inward = {0.6, 1},
				break_p = 0.65,
				break_t = {5, 12},
				dark = 0.15,
			},
			frag = {
				n = {3, 5},
				k = {0.32, 0.6},
				life = {1.8, 3.4},
			},
			collide = {
				every = 0.12,
				min_size = 24,
			},
			sweep = {1, 2.5},
			rain = {
				n = 36,
				t = {16.87, 19.52},
				size = {3, 11},
				height = {160, 620},
				r = {0.05, 0.7},
			},
			r_min = 0.08,
		},
		rings = {
			{0.16, 5, 0.4, 0.32},
			{0.3, 7, 0.33, 0.29},
			{0.46, 9, 0.26, 0.25},
			{0.62, 10, 0.2, 0.22},
			{0.78, 9, 0.15, 0.19},
			{0.94, 8, 0.1, 0.16},
		},
		front_n = 16,
		cracks = {0.3, 4.2, 0.12},
		updrafts = {
			n = 10,
			r = {0.2, 0.85},
			band = {0.05, 0.2},
		},
		eddies = {
			n = 6,
			r = {0.25, 0.8},
			band = {0.06, 0.3},
			box = {260, 140, 260},
			spin = {110, 190},
			life = {
				{3.6, 9.5},
				{4.6, 10.4},
				{5.2, 11},
				{6, 11.6},
				{6.8, 12},
				{7.6, 12.2},
			},
		},
		after = {
			n = 18,
			r = {0.04, 0.7},
		},
		currents = {
			n = 14,
			points = 11,
			r = {0.2, 0.62},
			wind = {1.885, 3.1416},
			top = 1.15,
			taper = 0.55,
			w = {0.85, 1.15},
			fade = {3.2, 6.5},
			bend = 1.4,
			beams = {
				{
					name = "CurrentCeleste",
					texture = "om_beam_flow",
					width = 90,
					color = {
						{
							0,
							{160, 215, 255},
						},
						{
							1,
							{110, 185, 255},
						},
					},
					transparency = 0.25,
					light_emission = 1,
					brightness = 1.25,
					tex_len = 260,
					speed = 1.4,
				},
				{
					name = "CurrentPurple",
					texture = "om_beam_flow",
					width = 72,
					color = {
						{
							0,
							{220, 140, 255},
						},
						{
							1,
							{180, 80, 245},
						},
					},
					transparency = 0.32,
					light_emission = 1,
					brightness = 1.25,
					tex_len = 300,
					speed = 1.1,
				},
				{
					name = "CurrentGlow",
					texture = "om_beam_glow",
					width = 130,
					color = {
						{
							0,
							{120, 180, 255},
						},
						{
							1,
							{90, 150, 255},
						},
					},
					transparency = 0.5,
					light_emission = 1,
					brightness = 1.1,
					tex_len = 400,
					speed = 0.8,
				},
			},
		},
		bands = {
			n = 6,
			points = 9,
			r = {0.15, 0.75},
			spiral = 1.7,
			band = {0.04, 0.2},
			fade = {2.6, 6},
			beams = {
				{
					name = "DustArm",
					texture = "om_beam_nebula",
					width = 300,
					color = {
						{
							0,
							{255, 255, 255},
						},
						{
							1,
							{230, 235, 255},
						},
					},
					transparency = 0.42,
					light_emission = 0.18,
					brightness = 1,
					tex_len = 420,
					speed = 0.35,
				},
				{
					name = "DustArmStars",
					texture = "om_beam_stars",
					width = 220,
					color = {
						{
							0,
							{255, 255, 255},
						},
						{
							1,
							{200, 230, 255},
						},
					},
					transparency = 0.35,
					light_emission = 1,
					brightness = 1.4,
					tex_len = 360,
					speed = 0.6,
				},
			},
		},
		streams = {
			n = 5,
			points = 13,
			r = {0.4, 0.75},
			band = {0.12, 0.3},
			turns = 1.1,
			fade = {8, 10.5},
			beams = {
				{
					name = "Accretion",
					texture = "om_beam_flow",
					width = 110,
					color = {
						{
							0,
							{200, 235, 255},
						},
						{
							1,
							{120, 190, 255},
						},
					},
					transparency = 0.15,
					light_emission = 1,
					brightness = 1.4,
					tex_len = 240,
					speed = 2.2,
				},
			},
		},
		loops = {
			points = 36,
			front = {
				name = "FrontWave",
				texture = "om_beam_glow",
				width = 70,
				color = {
					{
						0,
						{150, 210, 255},
					},
					{
						1,
						{150, 210, 255},
					},
				},
				transparency = 0.35,
				light_emission = 1,
				brightness = 1.2,
				tex_len = 500,
				speed = 0.6,
			},
			ripple = {
				name = "GravityRipple",
				texture = "om_beam_glow",
				width = 46,
				color = {
					{
						0,
						{120, 170, 255},
					},
					{
						1,
						{120, 170, 255},
					},
				},
				transparency = 0.5,
				light_emission = 1,
				brightness = 1.1,
				tex_len = 500,
				speed = 0.4,
			},
			ripple_purple = {
				name = "GravityRipplePurple",
				texture = "om_beam_glow",
				width = 40,
				color = {
					{
						0,
						{200, 110, 255},
					},
					{
						1,
						{200, 110, 255},
					},
				},
				transparency = 0.55,
				light_emission = 1,
				brightness = 1.1,
				tex_len = 500,
				speed = 0.4,
			},
			ripples = {0.5, 1.4, 2.3, 3.2, 4.1, 5, 5.9, 6.8, 7.7, 8.6},
			ripple_time = 2.4,
			det_ground = {
				name = "ShockGround",
				texture = "om_beam_glow",
				width = 150,
				color = {
					{
						0,
						{190, 230, 255},
					},
					{
						1,
						{190, 230, 255},
					},
				},
				transparency = 0.15,
				light_emission = 1,
				brightness = 1.4,
				tex_len = 600,
				speed = 0,
			},
			det_ground_core = {
				name = "ShockGroundCore",
				texture = "om_beam_core",
				width = 60,
				color = {
					{
						0,
						{235, 245, 255},
					},
					{
						1,
						{235, 245, 255},
					},
				},
				transparency = 0.1,
				light_emission = 1,
				brightness = 1.6,
				tex_len = 600,
				speed = 0,
			},
			det_sky = {
				name = "ShockSky",
				texture = "om_beam_glow",
				width = 120,
				color = {
					{
						0,
						{170, 215, 255},
					},
					{
						1,
						{170, 215, 255},
					},
				},
				transparency = 0.2,
				light_emission = 1,
				brightness = 1.3,
				tex_len = 600,
				speed = 0,
			},
			det_sky_purple = {
				name = "ShockSkyPurple",
				texture = "om_beam_glow",
				width = 100,
				color = {
					{
						0,
						{200, 110, 255},
					},
					{
						1,
						{200, 110, 255},
					},
				},
				transparency = 0.3,
				light_emission = 1,
				brightness = 1.3,
				tex_len = 600,
				speed = 0,
			},
		},
		victims = {
			stagger = 0.28,
			hold_r = 1.75,
			hold_drop = 0.25,
			hold_spin = 0.6,
			turns = 0.85,
			tremble = 0.5,
			fall = 0.55,
			fall_stagger = 0.06,
			land_max = 0.55,
			ref = 40,
			tether = {
				name = "Tether",
				texture = "om_beam_flow",
				width = 34,
				color = {
					{
						0,
						{170, 220, 255},
					},
					{
						1,
						{210, 130, 255},
					},
				},
				transparency = 0.3,
				light_emission = 1,
				brightness = 1.4,
				tex_len = 120,
				speed = 2.6,
			},
		},
		det = {
			core = {0.3, 3, 0.04, 0.45},
			shell = {1.1, 2040, 0.15},
			shell2 = {1, 1700, 0.06, 0.25},
			ring = {0.6, 2040},
			distort = {0.85, 2040, 0.55},
			sky = {1.4, 1},
			ground = {0.15, 1.35, 1},
			wall_n = 20,
		},
		shake = {
			{0, 0.04},
			{3.5, 0.22},
			{7.5, 0.4},
			{10.6, 0.5},
			{12.6, 0.85},
			{14.2, 0.32},
			{14.4, 0.3},
			{16.55, 0.95},
			{16.62, 2.4},
			{17.32, 0.9},
			{18.52, 0.35},
			{20.52, 0.1},
			{22.02, 0},
		},
		cc = {
			{0, 0, 0, 0, 255, 255, 255},
			{2.5, -0.06, 0.05, -0.05, 225, 232, 255},
			{6.4, -0.14, 0.1, -0.12, 200, 210, 255},
			{12.6, -0.18, 0.14, -0.15, 190, 200, 255},
			{14.4, -0.2, 0.15, -0.18, 188, 196, 255},
			{16.3, 0.15, 0.22, -0.2, 225, 236, 255},
			{16.55, 0.4, 0.3, -0.3, 230, 240, 255},
			{16.62, 0.3, 0.2, -0.15, 240, 246, 255},
			{17.22, 0.05, 0.08, -0.08, 235, 240, 255},
			{19.62, -0.05, 0.05, -0.05, 230, 236, 255},
			{22.12, 0, 0, 0, 255, 255, 255},
		},
		flash = {16.45, 16.6, 0.05, 0.3},
	},
}

-- OMNÍVORA ULTIMATE: CATACLISMO GRAVITACIONAL en un radio de 500 m (1786 studs). La gravedad desaparece y se levanta el terreno; la materia se organiza en una tormenta cósmica colosal; sobre el epicentro nace una singularidad que crece, se traga la tormenta y a las víctimas; acumula energía hasta un destello blanco y detona, estrellando a las víctimas contra el suelo. Quedan 5 s de residuos y todo se limpia.
-- epicenter = el epicentro: el Model de Omnívora (o su HumanoidRootPart), una Part, un Vector3 o un CFrame;
--   se busca el suelo debajo. victims = los kaijus atrapados: lista de Models (o Parts, Vector3, CFrame).
--   Cada uno sube a la singularidad y se estrella contra el suelo en su punto.
-- options (todo opcional):
--   Radius = radio en studs (por defecto 1786 = 500 m con 1 stud = 0.28 m); todo se escala con él
--   Height = altura de la singularidad sobre el epicentro (por defecto 760 × Radius / 1786)
--   Shake = intensidad de la sacudida (1; 0 = sin sacudida)
--   MoveVictims = true: el efecto mueve los modelos de las víctimas por su recorrido (pruebas o modelos anclados)
--   ImpactPoints = { Vector3 }: el punto del suelo donde cae cada víctima (por defecto, donde estaba)
--   AutoImpacts = false: no dibuja los impactos (llámalos tú con CataclysmImpact)
--   StartTime = segundo en que empieza (para revisar una fase); Flash = false: sin el destello blanco
--   Caster = el modelo de Omnívora (lo ignora al buscar el suelo)
--   OnEvent = function(nombre, ...): "Phase" (nombre, i), "VictimLift" (víctima, i), "VictimLaunch"
--     (víctima, i), "Detonation" (posición), "VictimImpact" (víctima, i, punto), "Finished"
-- Devuelve un control: .Time, .Phase, .Active, .Center, .Singularity, .SingularityRadius,
--   :GetVictimCFrame(víctima, t?), :GetImpactPoint(víctima), :Stop()
function OmnivoraVFX.GravitationalCataclysm(epicenter: any, victims: any, options: { [string]: any }?): CataclysmControl
	return playCataclysm(SPEC_GravitationalCataclysm, SPEC_CataclysmImpact, epicenter, victims, options)
end
-- el mismo recorrido de las víctimas, sin efectos: para el servidor (moverlas, el daño). Mismas options.
-- :GetVictimCFrame(víctima, t), :GetImpactPoint(víctima), :GetVictimTimes(víctima) -> {Lift, Held, Launch, Impact}
function OmnivoraVFX.GravitationalCataclysmPlan(epicenter: any, victims: any, options: { [string]: any }?): CataclysmPlanControl
	return planCataclysm(SPEC_GravitationalCataclysm, epicenter, victims, options)
end
-- segundos (desde la llamada) en que empieza cada momento
OmnivoraVFX.GravitationalCataclysmTimes = {
	Vortex = 2.4,
	Singularity = 6.4,
	Consumption = 10.6,
	VictimsLifted = 10.8,
	VictimsHeld = 13.6,
	CriticalMass = 14.4,
	Flash = 16.6,
	Detonation = 16.62,
	FirstImpact = 17.17,
	Aftermath = 17.6,
	End = 23,
}

return OmnivoraVFX
