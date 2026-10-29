--!nonstrict
--[[
	PebledonVFX — VFX del kaiju de piedra con venas de energía turquesa y placas de cristal cian para PEBLEDON
	(generado automáticamente desde vfx_pebledon.py; edita allí y regenera)

	USO (en el CLIENTE, por ejemplo al recibir un RemoteEvent del servidor):
		local PebledonVFX = require(ReplicatedStorage.PebledonVFX)
		PebledonVFX.SeismicRoar(boca.WorldCFrame, nil, nil, 1, 1)   -- skill 1 (o la CFrame de la cabeza)
		local aliento = PebledonVFX.BlueBreath(boca, rival, 1, 1, { pebledon })   -- skill 2 (aliento:AimAt(...))
		local cristal = PebledonVFX.CrystalSpire(pie.Position, puntoEnElSuelo, 1, 1)   -- skill 3 (el pie y dónde brota)
		local rayos = PebledonVFX.CrystalRefract(cristal, { rival1, rival2 }, 1)   -- el aliento le pega al cristal
		PebledonVFX.TectonicEruption(piesCFrame, nil, nil, 1, 1)   -- ULTIMATE (en sus pies, mirando hacia adelante)

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

local PebledonVFX = {}

-- Pega aquí los IDs de las imágenes subidas
PebledonVFX.TEXTURES = {
	fx_aura_tongue_2x2 = "rbxassetid://0",
	fx_fire_2x2 = "rbxassetid://0",
	fx_fog2001 = "rbxassetid://0",
	fx_glow = "rbxassetid://0",
	fx_particle02 = "rbxassetid://0",
	fx_smoke_2x2 = "rbxassetid://0",
	fx_spark002 = "rbxassetid://0",
	kk_circle_02 = "rbxassetid://0",
	kk_smoke_04 = "rbxassetid://0",
	kk_star_09 = "rbxassetid://0",
	kk_trace_01 = "rbxassetid://0",
	kz_beam_core = "rbxassetid://0",
	kz_beam_glow = "rbxassetid://0",
	kz_beam_ring = "rbxassetid://0",
	mf_shard_2x2 = "rbxassetid://0",
	om_cubes_2x2 = "rbxassetid://0",
	pb_breath_fire = "rbxassetid://0",
	pb_buff_ring = "rbxassetid://0",
	pb_rock_2x2 = "rbxassetid://0",
	pb_sonic_ring = "rbxassetid://0",
	pb_tectonic_veins = "rbxassetid://0",
	pb_vein_cracks = "rbxassetid://0",
}

-- Dónde se crean los efectos (puedes cambiarlo por una carpeta de VFX)
PebledonVFX.Parent = workspace :: Instance
-- Multiplicador de cantidad de partículas (bájalo en dispositivos lentos, p.ej. 0.6)
PebledonVFX.Quality = 1
-- Luz breve en el impacto (del color del efecto)
PebledonVFX.UseLight = true
-- Las ULTIMATES oscurecen el mundo y hacen destellar la pantalla de quien está cerca (solo en el cliente)
PebledonVFX.ScreenFX = true
-- Color y material de los cubos de destrucción (nil = los del suelo donde sale el efecto)
PebledonVFX.CubeColor = nil :: Color3?
PebledonVFX.CubeMaterial = nil :: Enum.Material?
-- Modelos (MeshPart) para las piezas sólidas, por nombre de capa: si pones uno, el módulo lo clona en vez de
-- un bloque. Por ejemplo: MoonfangVFX.Meshes.IceChunks = ReplicatedStorage.MoonfangMeshes.IceChunk
PebledonVFX.Meshes = {} :: { [string]: Instance }

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
	e.Texture = PebledonVFX.TEXTURES[L.texture] or ""
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
	e.LockedToPart = L.locked == true -- p. ej. el fuego que va pegado al rayo y gira con él
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
			e.Rate = rate * PebledonVFX.Quality
			e.Enabled = rate > 0.05
			task.wait(0.05)
		end
		if e.Parent then
			e.Enabled = false
		end
	end)
end

local function quality(n: number): number
	return math.max(1, math.floor(n * PebledonVFX.Quality + 0.5))
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
		d.Texture = PebledonVFX.TEXTURES[L.texture] or ""
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
	local template = PebledonVFX.Meshes[L.name]
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
			te.Rate = TL.rate * PebledonVFX.Quality
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
			acc[i] += rate * PebledonVFX.Quality * dt
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
function PebledonVFX.Shake(intensity: number, duration: number?)
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
function PebledonVFX.ShakeRamp(i0: number, i1: number, duration: number, power: number?)
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
	if PebledonVFX.UseLight and spec.light then
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
			task.delay(r[1], PebledonVFX.ShakeRamp, shake * r[3], shake * r[4], r[2] - r[1], r[5])
		end
		if spec.shakes then
			-- {t, intensidad relativa, duración}
			for _, sk in spec.shakes do
				task.delay(sk[1], PebledonVFX.Shake, shake * sk[2], sk[3])
			end
		elseif not spec.shake_ramp then
			PebledonVFX.Shake(shake, 0.9)
		end
	end
	-- se destruye cuando ya murió la última partícula (cleanup >= duración)
	Debris:AddItem(holder, spec.cleanup)
end

-- ---------------------------------------------------------------- losas y bloques que saltan del suelo
-- Los usan la Medialuna (las filas a los lados del corte y el cráter) y la Ola de hielo (el campo del triángulo).
-- Cada pieza aparece a su tiempo con el color y el material del suelo (o de hielo), sube con un rebote, se queda y
-- se hunde; con end = "shatter" desaparece de golpe al terminar y revienta en partículas. Se puede cambiar por un
-- modelo de Blender en PebledonVFX.Meshes[mesh].
type Slab = { t: number, x: number, z: number, size: Vector3, rot: CFrame, y0: number, drop: number, hold: number,
	rise: number, sink: number, ice: any, shatter: boolean, mesh: string?, L: any, part: BasePart?, base: CFrame?,
	gy: number, gone: boolean, tip: number?, tipPart: BasePart?, full: Vector3?, extra: { SlabExtra }?,
	crumble: boolean, crumbled: boolean? }
-- los otros bloques de un prisma hexagonal (y sus puntas), girados yaw alrededor del eje de la pieza
type SlabExtra = { part: BasePart, yaw: number, tip: boolean }

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
	if not SL.centered then -- (centered: el cristal del medio va justo en su punto)
		x += side * w / 2 * math.cos(a) * math.cos(yaw)
		z += side * w / 2 * math.cos(a) * math.sin(yaw)
	end
	local rot = CFrame.Angles(0, -yaw + math.rad(rng:NextNumber(-SL.yaw, SL.yaw)), 0)
		* CFrame.Angles(math.rad(rng:NextNumber(-SL.pitch, SL.pitch)), 0, 0) * CFrame.Angles(0, 0, -side * a)
	local top = w / 2 * math.sin(a) + th / 2 * math.cos(a)
	local y0 = top * (2 * SL.show - 1)
	-- hex: un prisma hexagonal de ancho w (de esquina a esquina) hecho con tres bloques girados 60°
	local size = if SL.hex then Vector3.new(w * 0.5, th, w * 0.866) else Vector3.new(w, th, ln)
	return {
		t = tS, x = x, z = z, size = size, rot = rot, y0 = y0, drop = y0 + top + 0.3 * s,
		hold = rng:NextNumber(SL.hold[1], SL.hold[2]), rise = SL.rise, sink = SL.sink,
		ice = if ice then SL.ice else nil, shatter = SL["end"] == "shatter", crumble = SL["end"] == "crumble",
		mesh = if ice and SL.ice.mesh then SL.ice.mesh else SL.mesh, L = SL,
		part = nil, base = nil, gy = 0, gone = false, full = if SL.hex then Vector3.new(w, th, w) else nil,
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
			local template = if L.mesh then PebledonVFX.Meshes[L.mesh] else nil
			local p: BasePart
			if template and template:IsA("BasePart") then
				p = (template :: BasePart):Clone()
				p.Name = "Slab"
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.Parent = holder
				p.Size = L.full or L.size -- (un modelo de Blender va entero: sin los bloques del hexágono)
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
				p.Size = L.size
				local function copy(name: string, size: Vector3): BasePart
					local c = bladePart(name, holder)
					c.Material = p.Material
					c.Color = p.Color
					c.Transparency = p.Transparency
					c.Size = size
					return c
				end
				if L.tip then
					L.tipPart = copy("SlabTip", Vector3.new(L.tip, L.tip, L.tip))
				end
				if L.L.hex then -- los otros dos bloques del prisma (y sus puntas)
					local ex = {}
					for k = 1, 2 do
						table.insert(ex, { part = copy("SlabHex", L.size), yaw = math.rad(60 * k), tip = false })
						if L.tip then
							table.insert(ex, { part = copy("SlabTip", Vector3.new(L.tip, L.tip, L.tip)),
								yaw = math.rad(60 * k), tip = true })
						end
					end
					L.extra = ex
				end
			end
			if L.L.query then -- el rayo lo puede tocar (p. ej. el cristal de Pebledon); sigue sin chocar
				p.CanQuery = true
				if L.tipPart then
					L.tipPart.CanQuery = true
				end
				for _, ex in (L.extra or {}) :: { SlabExtra } do
					ex.part.CanQuery = true
				end
			end
			if L.L.part_name then -- (los bloques; las puntas siguen siendo SlabTip)
				p.Name = L.L.part_name
				for _, ex in (L.extra or {}) :: { SlabExtra } do
					if not ex.tip then
						ex.part.Name = L.L.part_name
					end
				end
			end
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
			for _, ex in (L.extra or {}) :: { SlabExtra } do
				ex.part:Destroy()
			end
			L.gone = true
			if onShatter then
				onShatter(L, pos)
			end
			continue
		elseif age < L.rise + L.hold + L.sink then
			if L.crumble and not L.crumbled then -- crumble: se desmorona hundiéndose (suelta sus partículas al empezar)
				L.crumbled = true
				if onShatter then
					onShatter(L, part.Position)
				end
			end
			local p = (age - L.rise - L.hold) / L.sink
			y = L.y0 - L.drop * p * p
		else
			part:Destroy()
			if L.tipPart then
				L.tipPart:Destroy()
			end
			for _, ex in (L.extra or {}) :: { SlabExtra } do
				ex.part:Destroy()
			end
			L.gone = true
			continue
		end
		part.CFrame = (L.base :: CFrame) + Vector3.new(0, L.gy + y, 0)
		if L.tipPart then
			L.tipPart.CFrame = part.CFrame * CFrame.new(0, L.size.Y / 2, 0) * TIP_ROT
		end
		for _, ex in (L.extra or {}) :: { SlabExtra } do
			local cf = part.CFrame * CFrame.Angles(0, ex.yaw, 0)
			ex.part.CFrame = if ex.tip then cf * CFrame.new(0, L.size.Y / 2, 0) * TIP_ROT else cf
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
				it.pe.Rate = it.E.rate * PebledonVFX.Quality * (0.25 + 0.75 * u)
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
		for _ = 1, math.floor(G.count * PebledonVFX.Quality + 0.5) do
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
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf, PebledonVFX.Parent)
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

-- triángulo que sale de la cabeza (p. ej. un rugido): el triángulo va por el suelo bajo la boca, mirando hacia donde
-- mira la cabeza (en horizontal), y las capas "head" salen de la boca (su offset es relativo a ella)
local function playConeHead(spec: Layer, head: CFrame, scale: number?, length: number?, shake: number?,
	angle: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local look = Vector3.new(head.LookVector.X, 0, head.LookVector.Z)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	local _, _, gy = groundLook(head.Position, {}, 80 * s)
	local base = Vector3.new(head.Position.X, gy or (head.Position.Y - (spec.cone.mouth_h or 20) * s), head.Position.Z)
	local cf = CFrame.lookAt(base, base + look)
	local rel = cf:PointToObjectSpace(head.Position) / s
	local sp = table.clone(spec)
	sp.layers = table.create(#spec.layers)
	for i, L in spec.layers do
		if L.head then
			local c = table.clone(L)
			c.offset = { L.offset[1] + rel.X, L.offset[2] + rel.Y, L.offset[3] + rel.Z }
			sp.layers[i] = c
		else
			sp.layers[i] = L
		end
	end
	return play(sp, cf, scale, length, shake, angle)
end

-- efecto sobre las rocas del juego: todas detonan a la vez (con una diferencia mínima)
local function _playRocks(spec: Layer, rocks: { any }, scale: number?, shake: number?): Part?
	if #rocks == 0 then
		return nil
	end
	local s = (scale or 1) * (spec.scale_mult or 1)
	local R, dir = rockLayout(spec, rocks, s)
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2),
		CFrame.lookAt(R[1].pos, R[1].pos + dir), PebledonVFX.Parent)
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
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), lookCF(A0, lastDir), PebledonVFX.Parent)
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
		b.Texture = PebledonVFX.TEXTURES[B.texture] or ""
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
	if PebledonVFX.UseLight then
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
				PebledonVFX.Shake(shake * sk[2], sk[3])
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

-- ---------------------------------------------------------------- un rayo que se reparte (refracción)
-- crystal = de dónde salen (el contenedor que devolvió el efecto del cristal, una Part, un Model, un Vector3 o un
-- CFrame: salen de refract.h studs × escala sobre él, y no chocan con él). Un rayo por objetivo; :SetTargets cambia
-- a quiénes (corta los que ya no están y abre los nuevos) y :Stop los corta todos.
export type RefractControl = {
	Active: boolean,
	Rays: { [any]: BeamControl },
	SetTargets: (RefractControl, targets: { any }) -> (),
	Stop: (RefractControl) -> (),
}

local function playRefract(spec: Layer, crystal: any, targets: { any }, scale: number?, shake: number?): RefractControl
	local s = (scale or 1) * (spec.scale_mult or 1)
	local base = Vector3.zero
	local ignore: { Instance } = {}
	if typeof(crystal) == "Instance" then
		table.insert(ignore, crystal :: Instance)
		if (crystal :: Instance):IsA("BasePart") then
			base = (crystal :: BasePart).Position
		elseif (crystal :: Instance):IsA("Model") then
			base = (crystal :: Model):GetPivot().Position
		end
	elseif typeof(crystal) == "CFrame" then
		base = (crystal :: CFrame).Position
	elseif typeof(crystal) == "Vector3" then
		base = crystal :: Vector3
	end
	local origin = base + Vector3.new(0, spec.refract.h * s, 0)
	local ctl: RefractControl
	ctl = {
		Active = true,
		Rays = {},
		SetTargets = function(self: RefractControl, list: { any })
			if not self.Active then
				return
			end
			local keep: { [any]: boolean } = {}
			for _, tg in list do
				keep[tg] = true
				local r = self.Rays[tg]
				if not (r and r.Active) then
					self.Rays[tg] = playBeam(spec, origin, tg, scale, shake, ignore)
				end
			end
			for tg, r in self.Rays do
				if not keep[tg] then
					r:Stop()
					self.Rays[tg] = nil
				end
			end
		end,
		Stop = function(self: RefractControl)
			self.Active = false
			for _, r in self.Rays do
				r:Stop()
			end
			table.clear(self.Rays)
		end,
	}
	ctl:SetTargets(targets)
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
	local k = if height and (PebledonVFX :: any).HitAutoSize then math.clamp(height / H.ref, 0.5, 4) else 1
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

-- con at = {x, z} (fracciones del radio en el marco de la zona; -Z = hacia donde mira) la capa, el grupo o la luz
-- salen alrededor de ese punto en vez del centro (p. ej. una montaña que brota delante del que la invoca)
local function zoneAt(L: any, Z: Zone, cf: CFrame): CFrame
	if L.at then
		return CFrame.new(L.at[1] * Z.R, 0, L.at[2] * Z.R) * cf
	end
	return cf
end

-- punto al azar de la zona según L.zdist = {r = {r0, r1}, h = {h0, h1}, area}
local function zoneRandom(L: Layer, Z: Zone): CFrame
	local d = L.zdist
	local r = if d.area then math.sqrt(rng:NextNumber(d.r[1] ^ 2, d.r[2] ^ 2)) else rng:NextNumber(d.r[1], d.r[2])
	return zoneAt(L, Z, zoneLocal(Z, rng:NextNumber(), r, zoneY(L, Z, rng:NextNumber(d.h[1], d.h[2])), L.pitch, L.radial))
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
		acc += rate * mul * PebledonVFX.Quality * dt
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
	if not PebledonVFX.UseLight or not spec.lights then
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
				a.Position = if Lt.at then pos + Vector3.new(Lt.at[1] * Z.R, 0, Lt.at[2] * Z.R) else pos
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
	local opts = PebledonVFX :: any
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
				center = if G.at then center + base:VectorToWorldSpace(Vector3.new(G.at[1] * Z.R, 0, G.at[2] * Z.R))
					else center,
				k = 1, bounces = 0, seed = rng:NextNumber(0, 100),
				rot = CFrame.Angles(rng:NextNumber(0, 6.283), rng:NextNumber(0, 6.283), rng:NextNumber(0, 6.283)),
				axis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1) + 0.01).Unit,
				spin = math.rad(rng:NextNumber(C.spin[1], C.spin[2])),
				neon = rng:NextNumber() < (G.neon or 0), dissolve = rng:NextNumber() < (G.dissolve or 0),
				color = Color3.new(math.min(color.R * f, 1), math.min(color.G * f, 1), math.min(color.B * f, 1)),
				neonColor = Color3.fromRGB(nc[1], nc[2], nc[3]),
			})
			if G.sweep then -- salen cuando el frente que va del centro hacia afuera llega a su radio
				local c = list[#list]
				c.t0 += G.sweep * c.r / Z.R
			end
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
				local cx, cz = c.center.X + c.out.X * c.r, c.center.Z + c.out.Z * c.r
				if G.mode == "lift" then
					c.state = "rise"
					c.y0 = gy - c.size * 0.5
					c.y1 = gy + c.size * 0.5 + rng:NextNumber(G.lift[1], G.lift[2]) * s
					c.trel = rng:NextNumber(G.release[1], G.release[2])
					c.pos = Vector3.new(cx, c.y0, cz)
				elseif G.mode == "blast" then -- (h: salen a esa altura, p. ej. pedazos que se caen de un cristal)
					c.pos = Vector3.new(cx, gy + c.size * 0.5 + (if G.h then rng:NextNumber(G.h[1], G.h[2]) * s else 0), cz)
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
				c.pos = Vector3.new(c.center.X + c.out.X * c.r, c.y0 + (c.y1 - c.y0) * e, c.center.Z + c.out.Z * c.r) + jit
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
				c.pos = Vector3.new(c.center.X + dir.X * r, c.y, c.center.Z + dir.Z * r)
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
		im.Image = PebledonVFX.TEXTURES[L.texture] or ""
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
			b.Texture = PebledonVFX.TEXTURES[B.texture] or ""
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
		local n = math.floor((if G.pts then #G.pts else G.count) * PebledonVFX.Quality + 0.5)
		for i = 1, n do
			local x: number, z: number, yaw: number, tS: number
			if G.pts then -- piezas en puntos dados {x, z, yaw, t} (p. ej. a lo largo del camino de un pisotón)
				local pt = G.pts[math.floor((i - 0.5) * #G.pts / n) + 1] -- (con menos calidad, repartidas igual)
				x, z, yaw, tS = pt[1], pt[2], pt[3], pt[4] + rng:NextNumber(G.delay[1], G.delay[2])
			else
				local ang: number, r: number
				if G.ring then
					ang = 2 * math.pi * (i - 1 + rng:NextNumber(-0.35, 0.35)) / n
					r = rng:NextNumber(G.r[1], G.r[2])
				else
					ang = rng:NextNumber(0, 2 * math.pi)
					r = math.sqrt(rng:NextNumber(G.r[1] ^ 2, G.r[2] ^ 2))
				end
				x, z = math.cos(ang) * r * Z.R, math.sin(ang) * r * Z.R
				if G.at then
					x += G.at[1] * Z.R
					z += G.at[2] * Z.R
				end
				yaw = if G.lean == "radial" then ang else rng:NextNumber(0, 2 * math.pi)
				tS = G.t + (G.sweep or 0) * r + rng:NextNumber(G.delay[1], G.delay[2])
			end
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
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), flat, PebledonVFX.Parent)
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
				local lcf = zoneAt(L, Z, zoneLocal(Z, ev[3], ev[4], zoneY(L, Z, ev[5]), nil, false))
				task.delay(ev[1], function()
					if holder.Parent then
						playBill(L, Z, k, ev[2], lcf)
					end
				end)
			end
		elseif L.decal then
			local k = zoneK(L, Z)
			for _, ev in L.ring_emit or {} do
				local lcf = zoneAt(L, Z, zoneLocal(Z, ev[3], ev[4], zoneY(L, Z, ev[5]), nil, false))
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
				local lcf = zoneAt(L, Z, zoneLocal(Z, ev[3], ev[4], zoneY(L, Z, ev[5]), L.pitch, L.radial))
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
-- screen.range × radio. PebledonVFX.ScreenFX = false lo desactiva.
local function runScreen(spec: Layer, Z: Zone)
	local Sc = spec.screen
	if not (PebledonVFX :: any).ScreenFX or not RunService:IsClient() then
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

-- un pisotón que hace brotar una zona a la distancia (p. ej. un cristal): la zona va en target, mirando desde el pie,
-- y las capas "path" van por el suelo del pie (u = 0) al centro (u = 1): path_emit = {t, n, u, lado, alto}, que aquí
-- se pasan a ring_emit de la zona según la distancia de esta llamada
local function playStompZone(spec: Layer, foot: any, target: any, scale: number?, shake: number?): Part
	local s = (scale or 1) * (spec.scale_mult or 1)
	local fp: Vector3 = if typeof(foot) == "CFrame" then (foot :: CFrame).Position else foot :: Vector3
	local tp: Vector3 = if typeof(target) == "CFrame" then (target :: CFrame).Position else target :: Vector3
	local flat = Vector3.new(tp.X - fp.X, 0, tp.Z - fp.Z)
	local dist = flat.Magnitude
	local dir = if dist > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local R = spec.zone.radius * s
	local sp = table.clone(spec)
	sp.layers = table.create(#spec.layers)
	for i, L in spec.layers do
		if L.path_emit then
			-- en el marco de la zona el pie queda detrás (+Z) a dist studs
			local c = table.clone(L)
			local evs = table.create(#L.path_emit)
			for j, e in L.path_emit do
				local x, z = e[4] * s, dist * (1 - e[3])
				evs[j] = { e[1], e[2], (math.atan2(z, x) / (2 * math.pi)) % 1, math.sqrt(x * x + z * z) / R, e[5] }
			end
			c.ring_emit = evs
			c.radial = false
			sp.layers[i] = c
		else
			sp.layers[i] = L
		end
	end
	if spec.zfield then
		-- piezas a lo largo del camino (path = {u = {u0, u1}, side = {s0, s1}, t0, travel}): salen a un lado u otro,
		-- inclinadas hacia afuera, cuando pasa la grieta (como si algo avanzara bajo tierra)
		local F = table.clone(spec.zfield)
		F.groups = table.create(#spec.zfield.groups)
		for i, G in spec.zfield.groups do
			if G.path then
				local c = table.clone(G)
				local pts = table.create(G.count)
				for j = 1, G.count do
					local u = G.path.u[1] + (G.path.u[2] - G.path.u[1]) * (j - rng:NextNumber(0.2, 0.8)) / G.count
					local sd = (if j % 2 == 0 then 1 else -1) * rng:NextNumber(G.path.side[1], G.path.side[2]) * s
					pts[j] = { sd, dist * (1 - u), if sd > 0 then 0 else math.pi, G.path.t0 + G.path.travel * u }
				end
				c.pts = pts
				F.groups[i] = c
			else
				F.groups[i] = G
			end
		end
		sp.zfield = F
	end
	return playZone(sp, CFrame.lookAt(tp, tp + dir), scale, nil, nil, shake)
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
	if (PebledonVFX :: any).Lens and O.lens then
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

local function _playAura(spec: Layer, model: Instance, scale: number?, duration: number?, intensity: number?): AuraControl
	local Au = spec.aura
	local cf0, size0 = auraBox(model)
	local k = (scale or 1) * math.clamp(size0.Y / Au.ref, 0.25, 8)
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf0, PebledonVFX.Parent)
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
	if PebledonVFX.UseLight then
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
			local rate = (L.rate or 0) * it.share * k2 * gate * PebledonVFX.Quality
			it.e.Rate = rate
			it.e.Enabled = rate > 0.01
		end
		-- oleadas
		local surgeK = 0
		if Au.surge and Au.surge > 0 then
			if t - lastSurge >= Au.surge and on > 0.5 then
				lastSurge = t
				for _, it in items do
					local n = (it.L.surge or 0) * it.share * ctl.Intensity * PebledonVFX.Quality
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

-- ---------------------------------------------------------------- la hoja que vuela (Moonfang: Medialuna)
-- Una media luna de energía hecha de trazos finos (cadenas de Beams que miran a la cámara). Va vertical y DE CANTO:
-- de lado se ve la media luna (la punta adelante y los cuernos atrás) y desde atrás, una hoja fina que apunta hacia
-- donde va. Trazo j = 0 es el filo de afuera y j = 1 el borde de adentro: cada uno es un arco de radio
-- (1 - shrink·j)·R que empieza thick·R·j detrás de la punta y abarca arc_k·arc grados hacia cada cuerno.
-- Los trazos, los emisores de su estela y su luz cuelgan de un portador que avanza por la línea (llega al final a
-- los t0 + travel s); solo se mueve el portador. Su cuerno de abajo roza el suelo y lo corta: la grieta (gash), las
-- losas que saltan a los lados (slabs) y, al final, el cráter (crater). Las losas toman el color y el material del
-- suelo; las de hielo se pueden cambiar por un modelo en PebledonVFX.Meshes.IceSlab.
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
		if PebledonVFX.Quality < 0.7 and si > 3 and si % 2 == 1 then
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
			b.Texture = PebledonVFX.TEXTURES[S.texture] or ""
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
	if B.light and PebledonVFX.UseLight then
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
				if rng:NextNumber() <= PebledonVFX.Quality then
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
				d.Texture = PebledonVFX.TEXTURES[G.frost.texture] or ""
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
				em.pe.Rate = em.E.rate * PebledonVFX.Quality
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

local function _playBlade(spec: Layer, cf: CFrame, scale: number?, length: number?, shake: number?): Part
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

local function _playCataclysm(spec: Layer, impactSpec: Layer, epicenter: any, victimsIn: any, options: { [string]: any }?): CataclysmControl
	local opt: { [string]: any } = options or {}
	local Cf = spec.cataclysm
	local T, Fd, Hh, Rk = Cf.t, Cf.field, Cf.hole, Cf.rocks
	local plan = cataclysmPlan(spec, epicenter, victimsIn, opt)
	local R, k, Hs, C, B = plan.R, plan.k, plan.Hs, plan.C, plan.B
	local exclude = plan.exclude
	local shakeK = if opt.Shake == nil then 1 else opt.Shake
	local Q = PebledonVFX.Quality
	local victimList: { any } = if typeof(victimsIn) == "table" then victimsIn elseif victimsIn ~= nil then { victimsIn } else {}
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), CFrame.new(C), PebledonVFX.Parent)
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
		b.Texture = PebledonVFX.TEXTURES[Bs.texture] or ""
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
		d.Texture = PebledonVFX.TEXTURES[tex] or ""
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
				dd.Texture = PebledonVFX.TEXTURES[tex] or ""
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
	for i = 1, if (PebledonVFX :: any).Lens == false then 0 else 3 do
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
			h.lens.Transparency = if (PebledonVFX :: any).Lens == false then 1 else 1 - 0.38 * birth
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
local function _planCataclysm(spec: Layer, epicenter: any, victimsIn: any, options: { [string]: any }?): CataclysmPlanControl
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

local SPEC_SeismicRoar = {
	name = "SeismicRoar",
	duration = 3.6,
	cleanup = 5.62,
	layers = {
		{
			name = "GatherMotes",
			texture = "fx_particle02",
			shape = {
				type = "Sphere",
				radius = 13,
				style = "Surface",
				inout = "Inward",
			},
			speed = {34, 44},
			lifetime = {0.27, 0.3},
			size = {
				{0, 0, 0},
				{0.3, 1, 0},
				{1, 0.3, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			stream = {
				{0, 0.34, 120, 80},
			},
			head = true,
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
			name = "GatherFlames",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Sphere",
				radius = 2.6,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {40, 40},
			speed = {3, 8},
			drag = 1,
			accel = {0, 10, 0},
			lifetime = {0.25, 0.4},
			size = {
				{0, 1.2, 0.4},
				{0.35, 2.8, 0.6},
				{1, 0.6, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.6, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {-20, 20},
			stream = {
				{0.05, 0.36, 30, 80},
				{0.36, 1.06, 50, 0},
			},
			head = true,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "GatherGlow",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			lifetime = {0.36, 0.36},
			size = {
				{0, 2, 0},
				{1, 12, 0},
			},
			transparency = {
				{0, 0.85, 0},
				{1, 0.3, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			head = true,
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
			name = "TremorPebbles",
			floor = true,
			offset = {0, 0.5, 8},
			ring = {14, 7},
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 70,
			spread = {15, 15},
			speed = {10, 18},
			accel = {0, -150, 0},
			lifetime = {0.3, 0.4},
			size = {
				{0, 0.6, 0.2},
				{1, 0.5, 0.15},
			},
			color = {
				{
					0,
					{124, 116, 104},
				},
				{
					1,
					{96, 88, 78},
				},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			emit = {
				{0.04, 1},
				{0.14, 1},
				{0.24, 1},
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
		},
		{
			name = "TremorDust",
			floor = true,
			offset = {0, 1, 8},
			ring = {10, 6},
			texture = "kk_smoke_04",
			direction = "Front",
			pitch = 10,
			spread = {20, 10},
			speed = {4, 9},
			drag = 1.5,
			lifetime = {0.5, 0.8},
			size = {
				{0, 3, 1},
				{1, 8, 2},
			},
			transparency = {
				{0, 0.6, 0},
				{0.4, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			emit = {
				{0.05, 1},
				{0.2, 1},
			},
			accel = {0, 0, 0},
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "MouthFlash",
			texture = "fx_glow",
			emit = {
				{0.36, 1},
			},
			lifetime = {0.24, 0.24},
			size = {
				{0, 5, 0},
				{0.3, 18, 0},
				{1, 20, 0},
			},
			transparency = {
				{0, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1.1,
			zoffset = 3,
			head = true,
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
			name = "MouthStar",
			texture = "kk_star_09",
			emit = {
				{0.36, 1},
			},
			lifetime = {0.24, 0.24},
			rotation = {0, 90},
			size = {
				{0, 6, 0},
				{0.2, 26, 0},
				{1, 8, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			zoffset = 4,
			head = true,
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
		},
		{
			name = "MouthShock",
			texture = "pb_sonic_ring",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			speed = {8, 8},
			emit = {
				{0.36, 1},
			},
			lifetime = {0.3, 0.3},
			size = {
				{0, 5, 0},
				{1, 44, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.5, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			head = true,
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
			name = "SonicRings",
			texture = "pb_sonic_ring",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			speed = {156, 156},
			drag = 1.2,
			lifetime = {0.85, 0.85},
			size = {
				{0, 10, 0},
				{1, 85, 0},
			},
			transparency = {
				{0, 0.7, 0},
				{0.12, 0.28, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			emit = {
				{0.36, 1},
				{0.44, 1},
				{0.52, 1},
				{0.6, 1},
				{0.68, 1},
				{0.76, 1},
			},
			head = true,
			spread = {0, 0},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "SonicRingsSharp",
			texture = "kz_beam_ring",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			speed = {175, 175},
			drag = 1.1,
			lifetime = {0.75, 0.75},
			size = {
				{0, 8, 0},
				{1, 70, 0},
			},
			transparency = {
				{0, 0.7, 0},
				{0.12, 0.38, 0},
				{0.6, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			emit = {
				{0.4, 1},
				{0.56, 1},
				{0.72, 1},
			},
			head = true,
			spread = {0, 0},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "ScreamLines",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Front",
			spread = {34, 22},
			speed = {110, 170},
			drag = 3,
			lifetime = {0.18, 0.3},
			size = {
				{0, 11, 2},
				{1, 3, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			emit = {
				{0.36, 26},
				{0.48, 18},
				{0.62, 12},
			},
			head = true,
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
		},
		{
			name = "RoarBlast",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			spread = {16, 12},
			speed = {70, 120},
			drag = 2.4,
			accel = {0, 2, 0},
			lifetime = {0.7, 1},
			size = {
				{0, 4, 1},
				{0.4, 13, 2},
				{1, 19, 3},
			},
			transparency = {
				{0, 0.5, 0},
				{0.3, 0.62, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{150, 240, 234},
				},
				{
					0.5,
					{95, 205, 202},
				},
				{
					1,
					{60, 150, 152},
				},
			},
			light_emission = 0.15,
			rotation = {0, 360},
			rot_speed = {-40, 40},
			stream = {
				{0.36, 0.86, 60, 15},
			},
			head = true,
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "RoarFlames",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			spread = {20, 15},
			speed = {65, 115},
			drag = 2.8,
			accel = {0, 6, 0},
			lifetime = {0.3, 0.55},
			size = {
				{0, 2.5, 0.8},
				{0.3, 6.5, 1.5},
				{1, 2, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.36, 0.81, 70, 20},
			},
			head = true,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "RoarEmbers",
			texture = "fx_spark002",
			direction = "Front",
			spread = {30, 24},
			speed = {45, 100},
			drag = 2.4,
			accel = {0, 10, 0},
			lifetime = {0.6, 1.2},
			size = {
				{0, 0, 0},
				{0.08, 1.76, 0},
				{0.22, 0.77, 0},
				{0.38, 1.87, 0},
				{0.55, 0.66, 0},
				{0.72, 1.54, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 2,
			rotation = {0, 45},
			stream = {
				{0.36, 0.96, 70, 15},
			},
			head = true,
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
			name = "FloorRing",
			floor = true,
			offset = {0, 0, 2},
			texture = "kk_circle_02",
			emit = {
				{0.38, 1},
			},
			lifetime = {0.5, 0.5},
			size = {
				{0, 8, 0},
				{1, 70, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 0.8,
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
			name = "FloorCracks",
			floor = true,
			offset = {0, 0, 2},
			texture = "pb_vein_cracks",
			emit = {
				{0.4, 1},
			},
			lifetime = {1.6, 1.6},
			rotation = {0, 360},
			size = {
				{0, 6, 0},
				{0.1, 30, 0},
				{1, 31, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.2, 0},
				{0.7, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 0.9,
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
			name = "FloorDust",
			floor = true,
			offset = {0, 2, 4},
			ring = {16, 6},
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 8,
			spread = {10, 6},
			speed = {30, 55},
			drag = 2.5,
			accel = {0, 2, 0},
			lifetime = {0.9, 1.3},
			size = {
				{0, 5, 1},
				{1, 14, 2},
			},
			transparency = {
				{0, 0.4, 0},
				{0.35, 0.58, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			emit = {
				{0.39, 1},
			},
			light_emission = 0,
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FloorFlames",
			floor = true,
			offset = {0, 0.8, 5},
			ring = {9, 7},
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {10, 10},
			speed = {4, 8},
			drag = 1.2,
			accel = {0, 8, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 2, 0.6},
				{0.3, 5, 1},
				{1, 1, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {-10, 10},
			emit = {
				{0.39, 1},
				{0.54, 1},
				{0.69, 1},
				{0.84, 1},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "GroundCracks",
			texture = "pb_vein_cracks",
			lifetime = {2.6, 3.2},
			rotation = {0, 360},
			size = {
				{0, 8, 0},
				{0.05, 24, 4},
				{1, 25, 4},
			},
			transparency = {
				{0, 0.2, 0},
				{0.75, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{34, 30, 27},
				},
				{
					1,
					{40, 36, 32},
				},
			},
			cone_emit = {
				{0.562, 1, 0.2376, -0.106, 0.12},
				{0.57, 1, 0.2486, -0.923, 0.12},
				{0.663, 1, 0.3709, -0.305, 0.12},
				{0.701, 1, 0.4499, 0.268, 0.12},
				{0.737, 1, 0.5006, -0.186, 0.12},
				{0.804, 1, 0.5904, -0.537, 0.12},
				{0.812, 1, 0.5592, 0.809, 0.12},
				{0.813, 1, 0.5425, -0.303, 0.12},
				{0.819, 1, 0.5687, -0.026, 0.12},
				{0.842, 1, 0.6325, -0.203, 0.12},
				{0.856, 1, 0.6385, -0.632, 0.12},
				{0.865, 1, 0.66, 0.435, 0.12},
				{0.895, 1, 0.6872, -0.684, 0.12},
				{0.901, 1, 0.7066, -0.418, 0.12},
				{0.923, 1, 0.7045, 0.589, 0.12},
				{0.925, 1, 0.6841, 0.15, 0.12},
				{0.96, 1, 0.7548, -0.027, 0.12},
				{0.966, 1, 0.7746, -0.244, 0.12},
				{0.971, 1, 0.7863, -0.024, 0.12},
				{1.008, 1, 0.787, 0.243, 0.12},
				{1.02, 1, 0.8072, 0.909, 0.12},
				{1.039, 1, 0.8449, -0.175, 0.12},
				{1.042, 1, 0.829, 0.245, 0.12},
				{1.054, 1, 0.8597, -0.556, 0.12},
				{1.061, 1, 0.8522, -0.821, 0.12},
				{1.065, 1, 0.8434, -0.611, 0.12},
				{1.111, 1, 0.8831, 0.068, 0.12},
				{1.136, 1, 0.9233, -0.095, 0.12},
				{1.162, 1, 0.9223, -0.146, 0.12},
				{1.163, 1, 0.9555, 0.501, 0.12},
				{1.176, 1, 0.9456, 0.256, 0.12},
				{1.192, 1, 0.9472, 0.173, 0.12},
				{1.2, 1, 0.9715, -0.735, 0.12},
				{1.208, 1, 0.9782, -0.563, 0.12},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "VeinCracks",
			texture = "pb_vein_cracks",
			lifetime = {1.8, 2.3},
			rotation = {0, 360},
			size = {
				{0, 6, 0},
				{0.06, 20, 3},
				{1, 21, 3},
			},
			transparency = {
				{0, 0.5, 0},
				{0.1, 0.15, 0},
				{0.6, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			cone_emit = {
				{0.582, 1, 0.2376, -0.106, 0.2},
				{0.59, 1, 0.2486, -0.923, 0.2},
				{0.683, 1, 0.3709, -0.305, 0.2},
				{0.721, 1, 0.4499, 0.268, 0.2},
				{0.757, 1, 0.5006, -0.186, 0.2},
				{0.824, 1, 0.5904, -0.537, 0.2},
				{0.832, 1, 0.5592, 0.809, 0.2},
				{0.833, 1, 0.5425, -0.303, 0.2},
				{0.839, 1, 0.5687, -0.026, 0.2},
				{0.862, 1, 0.6325, -0.203, 0.2},
				{0.876, 1, 0.6385, -0.632, 0.2},
				{0.885, 1, 0.66, 0.435, 0.2},
				{0.915, 1, 0.6872, -0.684, 0.2},
				{0.921, 1, 0.7066, -0.418, 0.2},
				{0.943, 1, 0.7045, 0.589, 0.2},
				{0.945, 1, 0.6841, 0.15, 0.2},
				{0.98, 1, 0.7548, -0.027, 0.2},
				{0.986, 1, 0.7746, -0.244, 0.2},
				{0.991, 1, 0.7863, -0.024, 0.2},
				{1.028, 1, 0.787, 0.243, 0.2},
				{1.04, 1, 0.8072, 0.909, 0.2},
				{1.059, 1, 0.8449, -0.175, 0.2},
				{1.062, 1, 0.829, 0.245, 0.2},
				{1.074, 1, 0.8597, -0.556, 0.2},
				{1.081, 1, 0.8522, -0.821, 0.2},
				{1.085, 1, 0.8434, -0.611, 0.2},
				{1.131, 1, 0.8831, 0.068, 0.2},
				{1.156, 1, 0.9233, -0.095, 0.2},
				{1.182, 1, 0.9223, -0.146, 0.2},
				{1.183, 1, 0.9555, 0.501, 0.2},
				{1.196, 1, 0.9456, 0.256, 0.2},
				{1.212, 1, 0.9472, 0.173, 0.2},
				{1.22, 1, 0.9715, -0.735, 0.2},
				{1.228, 1, 0.9782, -0.563, 0.2},
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
			name = "CrackFlames",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 11},
			drag = 1.2,
			accel = {0, 9, 0},
			lifetime = {0.45, 0.8},
			size = {
				{0, 2.5, 0.8},
				{0.3, 6.5, 1.5},
				{1, 1.5, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.6, 0.38, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {-15, 15},
			cone_emit = {
				{0.598, 2, 0.1129, -0.36, 0.6},
				{0.697, 2, 0.3078, -0.661, 0.6},
				{0.708, 2, 0.3077, 0.568, 0.6},
				{0.728, 2, 0.328, -0.263, 0.6},
				{0.746, 2, 0.2269, 0.114, 0.6},
				{0.783, 2, 0.1129, -0.36, 0.6},
				{0.785, 2, 0.4527, -0.656, 0.6},
				{0.808, 2, 0.3108, 0.138, 0.6},
				{0.84, 2, 0.3842, 0.22, 0.6},
				{0.908, 2, 0.2269, 0.114, 0.6},
				{0.929, 2, 0.3077, 0.568, 0.6},
				{0.947, 2, 0.6673, 0.801, 0.6},
				{0.951, 2, 0.61, 0.757, 0.6},
				{0.952, 2, 0.6785, 0.175, 0.6},
				{0.959, 2, 0.4963, 0.594, 0.6},
				{0.961, 2, 0.3078, -0.661, 0.6},
				{0.969, 2, 0.7098, 0.607, 0.6},
				{0.98, 2, 0.6671, 0.021, 0.6},
				{0.986, 2, 0.6908, 0.859, 0.6},
				{1.013, 2, 0.3842, 0.22, 0.6},
				{1.013, 2, 0.4527, -0.656, 0.6},
				{1.018, 2, 0.7427, 0.628, 0.6},
				{1.022, 2, 0.1129, -0.36, 0.6},
				{1.027, 2, 0.328, -0.263, 0.6},
				{1.041, 2, 0.6006, 0.211, 0.6},
				{1.041, 2, 0.7349, -0.091, 0.6},
				{1.047, 2, 0.3108, 0.138, 0.6},
				{1.051, 2, 0.4963, 0.594, 0.6},
				{1.077, 2, 0.7142, -0.56, 0.6},
				{1.082, 2, 0.8111, 0.207, 0.6},
				{1.102, 2, 0.7865, 0.524, 0.6},
				{1.139, 2, 0.8845, -0.438, 0.6},
				{1.141, 2, 0.2269, 0.114, 0.6},
				{1.173, 2, 0.753, -0.71, 0.6},
				{1.176, 2, 0.7989, 0.598, 0.6},
				{1.183, 2, 0.7098, 0.607, 0.6},
				{1.189, 2, 0.6006, 0.211, 0.6},
				{1.19, 2, 0.3842, 0.22, 0.6},
				{1.191, 2, 0.7424, -0.806, 0.6},
				{1.192, 2, 0.3077, 0.568, 0.6},
				{1.217, 2, 0.8373, -0.568, 0.6},
				{1.22, 2, 0.7142, -0.56, 0.6},
				{1.221, 2, 0.8344, 0.646, 0.6},
				{1.226, 2, 0.3078, -0.661, 0.6},
				{1.227, 2, 0.1129, -0.36, 0.6},
				{1.231, 2, 0.7427, 0.628, 0.6},
				{1.242, 2, 0.328, -0.263, 0.6},
				{1.268, 2, 0.3108, 0.138, 0.6},
				{1.296, 2, 0.7424, -0.806, 0.6},
				{1.298, 2, 0.8111, 0.207, 0.6},
				{1.308, 2, 0.61, 0.757, 0.6},
				{1.31, 2, 0.6673, 0.801, 0.6},
				{1.316, 2, 0.4527, -0.656, 0.6},
				{1.334, 2, 0.9564, -0.883, 0.6},
				{1.338, 2, 0.7349, -0.091, 0.6},
				{1.348, 2, 0.6671, 0.021, 0.6},
				{1.349, 2, 0.6785, 0.175, 0.6},
				{1.354, 2, 0.3108, 0.138, 0.6},
				{1.359, 2, 0.7865, 0.524, 0.6},
				{1.365, 2, 0.966, -0.475, 0.6},
				{1.374, 2, 0.4963, 0.594, 0.6},
				{1.378, 2, 0.753, -0.71, 0.6},
				{1.385, 2, 0.8373, -0.568, 0.6},
				{1.391, 2, 0.6908, 0.859, 0.6},
				{1.394, 2, 0.2269, 0.114, 0.6},
				{1.408, 2, 0.8845, -0.438, 0.6},
				{1.416, 2, 0.8344, 0.646, 0.6},
				{1.427, 2, 0.9849, 0.836, 0.6},
				{1.429, 2, 0.7989, 0.598, 0.6},
				{1.436, 2, 0.6006, 0.211, 0.6},
				{1.45, 2, 0.61, 0.757, 0.6},
				{1.451, 2, 0.3077, 0.568, 0.6},
				{1.457, 2, 0.7098, 0.607, 0.6},
				{1.459, 2, 0.3078, -0.661, 0.6},
				{1.467, 2, 0.9564, -0.883, 0.6},
				{1.47, 2, 0.328, -0.263, 0.6},
				{1.475, 2, 0.6673, 0.801, 0.6},
				{1.477, 2, 0.6785, 0.175, 0.6},
				{1.481, 2, 0.7349, -0.091, 0.6},
				{1.493, 2, 0.7424, -0.806, 0.6},
				{1.494, 2, 0.4963, 0.594, 0.6},
				{1.51, 2, 0.7427, 0.628, 0.6},
				{1.517, 2, 0.3842, 0.22, 0.6},
				{1.528, 2, 0.9849, 0.836, 0.6},
				{1.53, 2, 0.6908, 0.859, 0.6},
				{1.544, 2, 0.8111, 0.207, 0.6},
				{1.556, 2, 0.7865, 0.524, 0.6},
				{1.564, 2, 0.7989, 0.598, 0.6},
				{1.573, 2, 0.7142, -0.56, 0.6},
				{1.582, 2, 0.753, -0.71, 0.6},
				{1.594, 2, 0.3108, 0.138, 0.6},
				{1.594, 2, 0.6671, 0.021, 0.6},
				{1.609, 2, 0.1129, -0.36, 0.6},
				{1.632, 2, 0.8344, 0.646, 0.6},
				{1.633, 2, 0.6785, 0.175, 0.6},
				{1.645, 2, 0.4527, -0.656, 0.6},
				{1.667, 2, 0.966, -0.475, 0.6},
				{1.672, 2, 0.8373, -0.568, 0.6},
				{1.678, 2, 0.6006, 0.211, 0.6},
				{1.679, 2, 0.6671, 0.021, 0.6},
				{1.685, 2, 0.6908, 0.859, 0.6},
				{1.687, 2, 0.7349, -0.091, 0.6},
				{1.689, 2, 0.3842, 0.22, 0.6},
				{1.701, 2, 0.1129, -0.36, 0.6},
				{1.708, 2, 0.7142, -0.56, 0.6},
				{1.719, 2, 0.2269, 0.114, 0.6},
				{1.729, 2, 0.7424, -0.806, 0.6},
				{1.73, 2, 0.3077, 0.568, 0.6},
				{1.736, 2, 0.3078, -0.661, 0.6},
				{1.74, 2, 0.8845, -0.438, 0.6},
				{1.741, 2, 0.61, 0.757, 0.6},
				{1.751, 2, 0.7427, 0.628, 0.6},
				{1.756, 2, 0.328, -0.263, 0.6},
				{1.799, 2, 0.7098, 0.607, 0.6},
				{1.807, 2, 0.2269, 0.114, 0.6},
				{1.809, 2, 0.7989, 0.598, 0.6},
				{1.81, 2, 0.6673, 0.801, 0.6},
				{1.814, 2, 0.4527, -0.656, 0.6},
				{1.823, 2, 0.753, -0.71, 0.6},
				{1.825, 2, 0.9849, 0.836, 0.6},
				{1.841, 2, 0.9564, -0.883, 0.6},
				{1.877, 2, 0.8344, 0.646, 0.6},
				{1.885, 2, 0.8373, -0.568, 0.6},
				{1.887, 2, 0.966, -0.475, 0.6},
				{1.893, 2, 0.4963, 0.594, 0.6},
				{1.909, 2, 0.8845, -0.438, 0.6},
				{1.913, 2, 0.3108, 0.138, 0.6},
				{1.913, 2, 0.6671, 0.021, 0.6},
				{1.913, 2, 0.8111, 0.207, 0.6},
				{1.92, 2, 0.3077, 0.568, 0.6},
				{1.922, 2, 0.7427, 0.628, 0.6},
				{1.928, 2, 0.6673, 0.801, 0.6},
				{1.933, 2, 0.3842, 0.22, 0.6},
				{1.938, 2, 0.7865, 0.524, 0.6},
				{1.957, 2, 0.6785, 0.175, 0.6},
				{1.964, 2, 0.7098, 0.607, 0.6},
				{1.971, 2, 0.3078, -0.661, 0.6},
				{1.98, 2, 0.4527, -0.656, 0.6},
				{1.985, 2, 0.753, -0.71, 0.6},
				{1.987, 2, 0.328, -0.263, 0.6},
				{1.991, 2, 0.6006, 0.211, 0.6},
				{1.991, 2, 0.7142, -0.56, 0.6},
				{1.992, 2, 0.966, -0.475, 0.6},
				{1.997, 2, 0.9564, -0.883, 0.6},
				{2.004, 2, 0.7865, 0.524, 0.6},
				{2.006, 2, 0.8111, 0.207, 0.6},
				{2.014, 2, 0.61, 0.757, 0.6},
				{2.034, 2, 0.7989, 0.598, 0.6},
				{2.037, 2, 0.6908, 0.859, 0.6},
				{2.049, 2, 0.7424, -0.806, 0.6},
				{2.07, 2, 0.9849, 0.836, 0.6},
				{2.093, 2, 0.8845, -0.438, 0.6},
				{2.095, 2, 0.7349, -0.091, 0.6},
				{2.118, 2, 0.4963, 0.594, 0.6},
				{2.123, 2, 0.8373, -0.568, 0.6},
				{2.124, 2, 0.6673, 0.801, 0.6},
				{2.135, 2, 0.6671, 0.021, 0.6},
				{2.144, 2, 0.9564, -0.883, 0.6},
				{2.16, 2, 0.6006, 0.211, 0.6},
				{2.168, 2, 0.7142, -0.56, 0.6},
				{2.19, 2, 0.7349, -0.091, 0.6},
				{2.192, 2, 0.8344, 0.646, 0.6},
				{2.194, 2, 0.7098, 0.607, 0.6},
				{2.214, 2, 0.6908, 0.859, 0.6},
				{2.216, 2, 0.61, 0.757, 0.6},
				{2.253, 2, 0.7865, 0.524, 0.6},
				{2.276, 2, 0.6785, 0.175, 0.6},
				{2.286, 2, 0.9849, 0.836, 0.6},
				{2.287, 2, 0.8344, 0.646, 0.6},
				{2.292, 2, 0.7427, 0.628, 0.6},
				{2.296, 2, 0.966, -0.475, 0.6},
				{2.299, 2, 0.7424, -0.806, 0.6},
				{2.324, 2, 0.8845, -0.438, 0.6},
				{2.33, 2, 0.753, -0.71, 0.6},
				{2.338, 2, 0.8373, -0.568, 0.6},
				{2.362, 2, 0.7989, 0.598, 0.6},
				{2.393, 2, 0.8111, 0.207, 0.6},
				{2.425, 2, 0.9564, -0.883, 0.6},
				{2.517, 2, 0.9849, 0.836, 0.6},
				{2.523, 2, 0.966, -0.475, 0.6},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CrackTongues",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {10, 10},
			speed = {4, 9},
			drag = 1.2,
			accel = {0, 8, 0},
			lifetime = {0.35, 0.6},
			size = {
				{0, 2.5, 0.8},
				{0.3, 7, 1.5},
				{1, 2, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {-10, 10},
			cone_emit = {
				{0.512, 1, 0.1129, -0.36, 0.6},
				{0.63, 1, 0.2269, 0.114, 0.6},
				{0.635, 1, 0.3077, 0.568, 0.6},
				{0.727, 1, 0.3078, -0.661, 0.6},
				{0.784, 1, 0.328, -0.263, 0.6},
				{0.8, 1, 0.3108, 0.138, 0.6},
				{0.804, 1, 0.1129, -0.36, 0.6},
				{0.848, 1, 0.3842, 0.22, 0.6},
				{0.863, 1, 0.4963, 0.594, 0.6},
				{0.889, 1, 0.2269, 0.114, 0.6},
				{0.91, 1, 0.4527, -0.656, 0.6},
				{0.97, 1, 0.3078, -0.661, 0.6},
				{0.971, 1, 0.6006, 0.211, 0.6},
				{0.982, 1, 0.7427, 0.628, 0.6},
				{1.022, 1, 0.3077, 0.568, 0.6},
				{1.035, 1, 0.6908, 0.859, 0.6},
				{1.038, 1, 0.6785, 0.175, 0.6},
				{1.045, 1, 0.328, -0.263, 0.6},
				{1.079, 1, 0.8111, 0.207, 0.6},
				{1.082, 1, 0.3108, 0.138, 0.6},
				{1.084, 1, 0.61, 0.757, 0.6},
				{1.087, 1, 0.4963, 0.594, 0.6},
				{1.096, 1, 0.7424, -0.806, 0.6},
				{1.11, 1, 0.6673, 0.801, 0.6},
				{1.118, 1, 0.7142, -0.56, 0.6},
				{1.133, 1, 0.7349, -0.091, 0.6},
				{1.135, 1, 0.3842, 0.22, 0.6},
				{1.135, 1, 0.6671, 0.021, 0.6},
				{1.138, 1, 0.7098, 0.607, 0.6},
				{1.141, 1, 0.8344, 0.646, 0.6},
				{1.159, 1, 0.753, -0.71, 0.6},
				{1.173, 1, 0.7865, 0.524, 0.6},
				{1.175, 1, 0.7989, 0.598, 0.6},
				{1.186, 1, 0.61, 0.757, 0.6},
				{1.195, 1, 0.4527, -0.656, 0.6},
				{1.219, 1, 0.6671, 0.021, 0.6},
				{1.226, 1, 0.1129, -0.36, 0.6},
				{1.23, 1, 0.8373, -0.568, 0.6},
				{1.231, 1, 0.6673, 0.801, 0.6},
				{1.247, 1, 0.3108, 0.138, 0.6},
				{1.254, 1, 0.6785, 0.175, 0.6},
				{1.262, 1, 0.8845, -0.438, 0.6},
				{1.273, 1, 0.753, -0.71, 0.6},
				{1.277, 1, 0.7349, -0.091, 0.6},
				{1.277, 1, 0.7427, 0.628, 0.6},
				{1.28, 1, 0.3842, 0.22, 0.6},
				{1.292, 1, 0.9849, 0.836, 0.6},
				{1.293, 1, 0.4527, -0.656, 0.6},
				{1.31, 1, 0.328, -0.263, 0.6},
				{1.317, 1, 0.6006, 0.211, 0.6},
				{1.324, 1, 0.6908, 0.859, 0.6},
				{1.324, 1, 0.7142, -0.56, 0.6},
				{1.326, 1, 0.2269, 0.114, 0.6},
				{1.328, 1, 0.3077, 0.568, 0.6},
				{1.352, 1, 0.1129, -0.36, 0.6},
				{1.366, 1, 0.3078, -0.661, 0.6},
				{1.372, 1, 0.966, -0.475, 0.6},
				{1.379, 1, 0.7865, 0.524, 0.6},
				{1.382, 1, 0.8344, 0.646, 0.6},
				{1.392, 1, 0.4963, 0.594, 0.6},
				{1.396, 1, 0.9564, -0.883, 0.6},
				{1.415, 1, 0.7098, 0.607, 0.6},
				{1.442, 1, 0.7989, 0.598, 0.6},
				{1.453, 1, 0.7424, -0.806, 0.6},
				{1.465, 1, 0.6671, 0.021, 0.6},
				{1.468, 1, 0.3108, 0.138, 0.6},
				{1.469, 1, 0.2269, 0.114, 0.6},
				{1.471, 1, 0.3077, 0.568, 0.6},
				{1.477, 1, 0.3078, -0.661, 0.6},
				{1.503, 1, 0.6006, 0.211, 0.6},
				{1.503, 1, 0.8111, 0.207, 0.6},
				{1.515, 1, 0.9564, -0.883, 0.6},
				{1.524, 1, 0.966, -0.475, 0.6},
				{1.527, 1, 0.61, 0.757, 0.6},
				{1.527, 1, 0.6673, 0.801, 0.6},
				{1.542, 1, 0.9849, 0.836, 0.6},
				{1.545, 1, 0.753, -0.71, 0.6},
				{1.551, 1, 0.7349, -0.091, 0.6},
				{1.556, 1, 0.8845, -0.438, 0.6},
				{1.56, 1, 0.8373, -0.568, 0.6},
				{1.566, 1, 0.4527, -0.656, 0.6},
				{1.57, 1, 0.328, -0.263, 0.6},
				{1.587, 1, 0.7865, 0.524, 0.6},
				{1.594, 1, 0.3842, 0.22, 0.6},
				{1.596, 1, 0.4963, 0.594, 0.6},
				{1.599, 1, 0.7424, -0.806, 0.6},
				{1.619, 1, 0.6908, 0.859, 0.6},
				{1.62, 1, 0.8111, 0.207, 0.6},
				{1.639, 1, 0.7098, 0.607, 0.6},
				{1.651, 1, 0.7142, -0.56, 0.6},
				{1.654, 1, 0.6785, 0.175, 0.6},
				{1.654, 1, 0.7427, 0.628, 0.6},
				{1.713, 1, 0.7989, 0.598, 0.6},
				{1.734, 1, 0.61, 0.757, 0.6},
				{1.748, 1, 0.1129, -0.36, 0.6},
				{1.759, 1, 0.8344, 0.646, 0.6},
				{1.769, 1, 0.3108, 0.138, 0.6},
				{1.78, 1, 0.9564, -0.883, 0.6},
				{1.786, 1, 0.7349, -0.091, 0.6},
				{1.802, 1, 0.6908, 0.859, 0.6},
				{1.806, 1, 0.6671, 0.021, 0.6},
				{1.812, 1, 0.8373, -0.568, 0.6},
				{1.813, 1, 0.7098, 0.607, 0.6},
				{1.814, 1, 0.6673, 0.801, 0.6},
				{1.832, 1, 0.3078, -0.661, 0.6},
				{1.836, 1, 0.7427, 0.628, 0.6},
				{1.838, 1, 0.7865, 0.524, 0.6},
				{1.846, 1, 0.2269, 0.114, 0.6},
				{1.852, 1, 0.7989, 0.598, 0.6},
				{1.852, 1, 0.8845, -0.438, 0.6},
				{1.853, 1, 0.3077, 0.568, 0.6},
				{1.872, 1, 0.6006, 0.211, 0.6},
				{1.894, 1, 0.7142, -0.56, 0.6},
				{1.896, 1, 0.9849, 0.836, 0.6},
				{1.898, 1, 0.3842, 0.22, 0.6},
				{1.899, 1, 0.6785, 0.175, 0.6},
				{1.909, 1, 0.7424, -0.806, 0.6},
				{1.924, 1, 0.328, -0.263, 0.6},
				{1.932, 1, 0.6006, 0.211, 0.6},
				{1.935, 1, 0.8111, 0.207, 0.6},
				{1.947, 1, 0.753, -0.71, 0.6},
				{1.961, 1, 0.8845, -0.438, 0.6},
				{1.974, 1, 0.4527, -0.656, 0.6},
				{1.974, 1, 0.4963, 0.594, 0.6},
				{1.974, 1, 0.966, -0.475, 0.6},
				{1.986, 1, 0.6673, 0.801, 0.6},
				{1.99, 1, 0.8373, -0.568, 0.6},
				{2.029, 1, 0.61, 0.757, 0.6},
				{2.039, 1, 0.7142, -0.56, 0.6},
				{2.042, 1, 0.8344, 0.646, 0.6},
				{2.076, 1, 0.7427, 0.628, 0.6},
				{2.076, 1, 0.753, -0.71, 0.6},
				{2.078, 1, 0.6785, 0.175, 0.6},
				{2.132, 1, 0.8111, 0.207, 0.6},
				{2.145, 1, 0.7424, -0.806, 0.6},
				{2.15, 1, 0.7098, 0.607, 0.6},
				{2.151, 1, 0.9564, -0.883, 0.6},
				{2.153, 1, 0.966, -0.475, 0.6},
				{2.168, 1, 0.6671, 0.021, 0.6},
				{2.186, 1, 0.8344, 0.646, 0.6},
				{2.189, 1, 0.9849, 0.836, 0.6},
				{2.196, 1, 0.7989, 0.598, 0.6},
				{2.208, 1, 0.7349, -0.091, 0.6},
				{2.21, 1, 0.6908, 0.859, 0.6},
				{2.244, 1, 0.7865, 0.524, 0.6},
				{2.258, 1, 0.8845, -0.438, 0.6},
				{2.297, 1, 0.8373, -0.568, 0.6},
				{2.304, 1, 0.966, -0.475, 0.6},
				{2.305, 1, 0.9564, -0.883, 0.6},
				{2.423, 1, 0.9849, 0.836, 0.6},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ResonanceRocks",
			texture = "pb_rock_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {25, 25},
			speed = {9, 16},
			drag = 0.8,
			accel = {0, -14, 0},
			lifetime = {1.1, 1.5},
			size = {
				{0, 0.8, 0.3},
				{1, 0.7, 0.2},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			rot_speed = {-90, 90},
			cone_emit = {
				{0.501, 2, 0.113, -0.199, 0.5},
				{0.583, 2, 0.2387, 0.136, 0.5},
				{0.617, 2, 0.2928, -0.764, 0.5},
				{0.623, 2, 0.3419, 0.636, 0.5},
				{0.632, 2, 0.3548, -0.433, 0.5},
				{0.656, 2, 0.3017, 0.889, 0.5},
				{0.755, 2, 0.44, 0.104, 0.5},
				{0.808, 2, 0.594, -0.841, 0.5},
				{0.817, 2, 0.5847, 0.071, 0.5},
				{0.823, 2, 0.5664, 0.065, 0.5},
				{0.843, 2, 0.6295, -0.775, 0.5},
				{0.851, 2, 0.5626, -0.129, 0.5},
				{0.866, 2, 0.6609, 0.368, 0.5},
				{0.893, 2, 0.6403, 0.571, 0.5},
				{0.931, 2, 0.7082, -0.414, 0.5},
				{0.931, 2, 0.7309, -0.433, 0.5},
				{0.943, 2, 0.701, 0.43, 0.5},
				{0.949, 2, 0.6912, -0.755, 0.5},
				{0.972, 2, 0.7244, -0.248, 0.5},
				{1.017, 2, 0.8184, 0.642, 0.5},
				{1.043, 2, 0.8054, 0.717, 0.5},
				{1.082, 2, 0.8676, 0.77, 0.5},
				{1.087, 2, 0.8372, 0.308, 0.5},
				{1.121, 2, 0.8693, 0.016, 0.5},
				{1.135, 2, 0.937, 0.704, 0.5},
				{1.136, 2, 0.9066, -0.349, 0.5},
				{1.154, 2, 0.9448, 0.133, 0.5},
				{1.161, 2, 0.9157, -0.797, 0.5},
				{1.191, 2, 0.9403, 0.195, 0.5},
				{1.229, 2, 0.9791, 0.804, 0.5},
			},
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
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CrackEmbers",
			texture = "fx_spark002",
			direction = "Top",
			spread = {35, 35},
			speed = {8, 18},
			drag = 1.5,
			accel = {0, 6, 0},
			lifetime = {0.6, 1.1},
			size = {
				{0, 0, 0},
				{0.08, 1.28, 0},
				{0.22, 0.56, 0},
				{0.38, 1.36, 0},
				{0.55, 0.48, 0},
				{0.72, 1.12, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 2,
			rotation = {0, 45},
			cone_emit = {
				{0.584, 2, 0.1129, -0.36, 0.6},
				{0.676, 2, 0.3077, 0.568, 0.6},
				{0.797, 2, 0.2269, 0.114, 0.6},
				{0.855, 2, 0.1129, -0.36, 0.6},
				{0.855, 2, 0.4963, 0.594, 0.6},
				{0.859, 2, 0.3108, 0.138, 0.6},
				{0.883, 2, 0.328, -0.263, 0.6},
				{0.893, 2, 0.4527, -0.656, 0.6},
				{0.914, 2, 0.3078, -0.661, 0.6},
				{0.954, 2, 0.6785, 0.175, 0.6},
				{0.968, 2, 0.3842, 0.22, 0.6},
				{0.974, 2, 0.61, 0.757, 0.6},
				{0.997, 2, 0.6673, 0.801, 0.6},
				{1.02, 2, 0.2269, 0.114, 0.6},
				{1.024, 2, 0.3078, -0.661, 0.6},
				{1.031, 2, 0.7142, -0.56, 0.6},
				{1.068, 2, 0.3108, 0.138, 0.6},
				{1.084, 2, 0.7424, -0.806, 0.6},
				{1.099, 2, 0.6006, 0.211, 0.6},
				{1.116, 2, 0.7427, 0.628, 0.6},
				{1.137, 2, 0.8373, -0.568, 0.6},
				{1.147, 2, 0.8111, 0.207, 0.6},
				{1.156, 2, 0.7098, 0.607, 0.6},
				{1.161, 2, 0.3077, 0.568, 0.6},
				{1.167, 2, 0.6671, 0.021, 0.6},
				{1.177, 2, 0.328, -0.263, 0.6},
				{1.178, 2, 0.7349, -0.091, 0.6},
				{1.182, 2, 0.7989, 0.598, 0.6},
				{1.188, 2, 0.753, -0.71, 0.6},
				{1.205, 2, 0.6908, 0.859, 0.6},
				{1.248, 2, 0.1129, -0.36, 0.6},
				{1.252, 2, 0.7865, 0.524, 0.6},
				{1.26, 2, 0.8344, 0.646, 0.6},
				{1.277, 2, 0.3842, 0.22, 0.6},
				{1.277, 2, 0.966, -0.475, 0.6},
				{1.296, 2, 0.8845, -0.438, 0.6},
				{1.306, 2, 0.4527, -0.656, 0.6},
				{1.348, 2, 0.3108, 0.138, 0.6},
				{1.356, 2, 0.4963, 0.594, 0.6},
				{1.358, 2, 0.328, -0.263, 0.6},
				{1.371, 2, 0.7427, 0.628, 0.6},
				{1.374, 2, 0.7989, 0.598, 0.6},
				{1.383, 2, 0.6006, 0.211, 0.6},
				{1.411, 2, 0.7424, -0.806, 0.6},
				{1.412, 2, 0.2269, 0.114, 0.6},
				{1.416, 2, 0.3842, 0.22, 0.6},
				{1.426, 2, 0.61, 0.757, 0.6},
				{1.43, 2, 0.9564, -0.883, 0.6},
				{1.438, 2, 0.6785, 0.175, 0.6},
				{1.445, 2, 0.7349, -0.091, 0.6},
				{1.446, 2, 0.3077, 0.568, 0.6},
				{1.45, 2, 0.7098, 0.607, 0.6},
				{1.454, 2, 0.753, -0.71, 0.6},
				{1.461, 2, 0.4527, -0.656, 0.6},
				{1.475, 2, 0.3078, -0.661, 0.6},
				{1.511, 2, 0.6673, 0.801, 0.6},
				{1.512, 2, 0.6671, 0.021, 0.6},
				{1.519, 2, 0.8373, -0.568, 0.6},
				{1.528, 2, 0.9849, 0.836, 0.6},
				{1.53, 2, 0.7142, -0.56, 0.6},
				{1.56, 2, 0.9564, -0.883, 0.6},
				{1.567, 2, 0.6908, 0.859, 0.6},
				{1.573, 2, 0.61, 0.757, 0.6},
				{1.573, 2, 0.8845, -0.438, 0.6},
				{1.578, 2, 0.4963, 0.594, 0.6},
				{1.62, 2, 0.7865, 0.524, 0.6},
				{1.62, 2, 0.8111, 0.207, 0.6},
				{1.638, 2, 0.7098, 0.607, 0.6},
				{1.649, 2, 0.6671, 0.021, 0.6},
				{1.666, 2, 0.7142, -0.56, 0.6},
				{1.684, 2, 0.8344, 0.646, 0.6},
				{1.709, 2, 0.9849, 0.836, 0.6},
				{1.725, 2, 0.966, -0.475, 0.6},
				{1.736, 2, 0.6006, 0.211, 0.6},
				{1.74, 2, 0.7349, -0.091, 0.6},
				{1.788, 2, 0.8111, 0.207, 0.6},
				{1.807, 2, 0.7424, -0.806, 0.6},
				{1.808, 2, 0.753, -0.71, 0.6},
				{1.812, 2, 0.7989, 0.598, 0.6},
				{1.816, 2, 0.6673, 0.801, 0.6},
				{1.859, 2, 0.6785, 0.175, 0.6},
				{1.869, 2, 0.6908, 0.859, 0.6},
				{1.892, 2, 0.8845, -0.438, 0.6},
				{1.899, 2, 0.7427, 0.628, 0.6},
				{1.961, 2, 0.7865, 0.524, 0.6},
				{1.981, 2, 0.8373, -0.568, 0.6},
				{2.023, 2, 0.8344, 0.646, 0.6},
				{2.07, 2, 0.966, -0.475, 0.6},
				{2.092, 2, 0.9849, 0.836, 0.6},
				{2.132, 2, 0.9564, -0.883, 0.6},
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
			name = "FieldDust",
			texture = "kk_smoke_04",
			direction = "Top",
			spread = {70, 70},
			speed = {6, 14},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 4, 1},
				{1, 12, 3},
			},
			transparency = {
				{0, 0.5, 0},
				{0.4, 0.62, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			zoffset = -2,
			cone_emit = {
				{0.582, 1, 0.2518, -0.915, 0.8},
				{0.61, 1, 0.3271, -0.805, 0.8},
				{0.632, 1, 0.3268, -0.198, 0.8},
				{0.703, 1, 0.4222, -0.667, 0.8},
				{0.709, 1, 0.4565, 0.486, 0.8},
				{0.716, 1, 0.43, -0.011, 0.8},
				{0.741, 1, 0.5056, 0.418, 0.8},
				{0.751, 1, 0.4827, 0.561, 0.8},
				{0.754, 1, 0.4947, -0.589, 0.8},
				{0.779, 1, 0.5298, -0.354, 0.8},
				{0.793, 1, 0.5597, 0.794, 0.8},
				{0.849, 1, 0.6124, 0.753, 0.8},
				{0.856, 1, 0.6409, -0.671, 0.8},
				{0.866, 1, 0.6312, 0.159, 0.8},
				{0.949, 1, 0.7539, 0.814, 0.8},
				{0.956, 1, 0.7467, 0.461, 0.8},
				{0.988, 1, 0.7541, 0.59, 0.8},
				{1.003, 1, 0.7941, 0.809, 0.8},
				{1.006, 1, 0.7874, 0.918, 0.8},
				{1.013, 1, 0.8279, -0.701, 0.8},
				{1.021, 1, 0.8288, 0.573, 0.8},
				{1.041, 1, 0.8187, 0.076, 0.8},
				{1.049, 1, 0.8537, 0.19, 0.8},
				{1.062, 1, 0.8669, -0.341, 0.8},
				{1.106, 1, 0.8835, -0.891, 0.8},
				{1.144, 1, 0.9114, 0.067, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "FieldSmoke",
			texture = "fx_fog2001",
			direction = "Top",
			spread = {30, 30},
			speed = {2, 6},
			drag = 1,
			accel = {0, 1.5, 0},
			lifetime = {1.8, 2.6},
			size = {
				{0, 8, 2},
				{0.5, 16, 3},
				{1, 21, 3},
			},
			transparency = {
				{0, 0.72, 0},
				{0.3, 0.64, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{118, 109, 98},
				},
				{
					1,
					{92, 85, 77},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -3,
			cone_emit = {
				{0.771, 1, 0.3015, -0.805, 1.59},
				{0.805, 1, 0.3891, -0.246, 2.48},
				{0.939, 1, 0.3785, 0.041, 2.07},
				{0.941, 1, 0.4417, 0.827, 2.22},
				{1.032, 1, 0.494, 0.7, 1.99},
				{1.087, 1, 0.5251, -0.745, 1.86},
				{1.089, 1, 0.7498, 0.099, 1.52},
				{1.124, 1, 0.6402, 0.113, 1.82},
				{1.14, 1, 0.5579, 0.561, 1.49},
				{1.179, 1, 0.5095, -0.003, 1.25},
				{1.179, 1, 0.8755, 0.765, 2.37},
				{1.198, 1, 0.4908, -0.915, 1.18},
				{1.269, 1, 0.9019, 0.688, 1.85},
				{1.289, 1, 0.6734, -0.212, 1.37},
				{1.304, 1, 0.9266, 0.376, 1.32},
				{1.322, 1, 0.8225, 0.359, 1.04},
				{1.34, 1, 0.8921, -0.577, 1.35},
				{1.347, 1, 0.7613, -0.521, 2.14},
				{1.383, 1, 0.9837, -0.48, 1.11},
				{1.44, 1, 0.7963, -0.784, 1.1},
				{1.442, 1, 0.9558, -0.949, 1.81},
				{1.469, 1, 0.8273, 0.34, 1.43},
				{1.475, 1, 0.9715, 0.202, 1.18},
				{1.507, 1, 0.8363, -0.742, 2.3},
				{1.525, 1, 0.8658, -0.442, 1.45},
				{1.545, 1, 0.9781, -0.352, 1.89},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "PlowRocks",
			type = "meteor",
			direction = "Front",
			pitch = 24,
			spread = {22, 12},
			speed = {60, 100},
			accel = {0, -196, 0},
			drag = 0.1,
			lifetime = {2, 2},
			trails = {
				{
					name = "PlowRockDust",
					rate = 12,
					texture = "kk_smoke_04",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					lifetime = {0.35, 0.55},
					size = {
						{0, 1.5, 0.5},
						{1, 3.75, 1},
					},
					transparency = {
						{0, 0.55, 0},
						{0.5, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{160, 150, 136},
						},
						{
							0.5,
							{138, 128, 116},
						},
						{
							1,
							{112, 104, 94},
						},
					},
					rotation = {0, 360},
					accel = {0, 0, 0},
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
					name = "RockPuff",
					texture = "kk_smoke_04",
					emit = {
						{0, 2},
					},
					direction = "Top",
					spread = {70, 70},
					speed = {4, 9},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 2.5, 0.5},
						{1, 6, 1},
					},
					transparency = {
						{0, 0.45, 0},
						{0.5, 0.6, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{160, 150, 136},
						},
						{
							0.5,
							{138, 128, 116},
						},
						{
							1,
							{112, 104, 94},
						},
					},
					rotation = {0, 360},
					accel = {0, 0, 0},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			shatter = {
				{
					name = "RockCrumble",
					texture = "om_cubes_2x2",
					flipbook = {
						layout = "Grid2x2",
						mode = "Loop",
						fps = 0.001,
						startRandom = true,
					},
					emit = {
						{0, 5},
					},
					shape = {
						type = "Box",
						size = {2, 1, 2},
						style = "Volume",
						inout = "Outward",
					},
					direction = "Top",
					spread = {60, 60},
					speed = {10, 20},
					drag = 0.5,
					accel = {0, -150, 0},
					lifetime = {0.4, 0.6},
					size = {
						{0, 0.7, 0.2},
						{1, 0.5, 0.15},
					},
					color = {
						{
							0,
							{120, 112, 100},
						},
						{
							1,
							{96, 88, 78},
						},
					},
					rotation = {0, 360},
					rot_speed = {-400, 400},
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
				},
				{
					name = "RockCrumbleDust",
					texture = "kk_smoke_04",
					emit = {
						{0, 1},
					},
					direction = "Top",
					spread = {60, 60},
					speed = {2, 5},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 2, 0.5},
						{1, 5, 1},
					},
					transparency = {
						{0, 0.5, 0},
						{0.5, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{160, 150, 136},
						},
						{
							0.5,
							{138, 128, 116},
						},
						{
							1,
							{112, 104, 94},
						},
					},
					rotation = {0, 360},
					accel = {0, 0, 0},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			cone_emit = {
				{0.433, 1, 0.068, 0.65, 0.6},
				{0.445, 1, 0.0866, -0.647, 0.6},
				{0.456, 1, 0.1027, -0.227, 0.6},
				{0.495, 1, 0.1628, -0.623, 0.6},
				{0.495, 1, 0.1633, 0.545, 0.6},
				{0.501, 1, 0.1726, 0.696, 0.6},
				{0.551, 1, 0.2463, -0.935, 0.6},
				{0.575, 1, 0.2822, -0.78, 0.6},
				{0.61, 1, 0.3329, -0.17, 0.6},
				{0.625, 1, 0.3534, -0.388, 0.6},
				{0.644, 1, 0.3807, -0.447, 0.6},
				{0.656, 1, 0.3977, -0.514, 0.6},
				{0.677, 1, 0.4259, 0.118, 0.6},
				{0.7, 1, 0.4578, 0.639, 0.6},
				{0.707, 1, 0.4671, -0.505, 0.6},
				{0.713, 1, 0.4749, -0.359, 0.6},
				{0.729, 1, 0.4975, -0.411, 0.6},
				{0.744, 1, 0.5168, -0.022, 0.6},
				{0.746, 1, 0.5195, -0.714, 0.6},
				{0.748, 1, 0.5214, -0.887, 0.6},
				{0.749, 1, 0.5233, 0.259, 0.6},
				{0.831, 1, 0.6281, 0.313, 0.6},
				{0.838, 1, 0.6366, 0.71, 0.6},
				{0.87, 1, 0.6752, -0.101, 0.6},
				{0.874, 1, 0.6794, -0.083, 0.6},
				{0.884, 1, 0.6916, 0.183, 0.6},
				{0.885, 1, 0.6926, 0.569, 0.6},
				{0.897, 1, 0.7065, 0.175, 0.6},
				{0.916, 1, 0.7275, 0.569, 0.6},
				{0.921, 1, 0.7337, 0.408, 0.6},
				{0.94, 1, 0.7544, -0.868, 0.6},
				{0.957, 1, 0.7731, 0.265, 0.6},
				{0.984, 1, 0.8019, -0.07, 0.6},
				{0.987, 1, 0.8047, 0.21, 0.6},
				{1.012, 1, 0.8305, -0.46, 0.6},
				{1.024, 1, 0.8424, 0.346, 0.6},
				{1.025, 1, 0.8439, 0.872, 0.6},
				{1.026, 1, 0.8446, -0.503, 0.6},
				{1.031, 1, 0.8499, -0.288, 0.6},
				{1.033, 1, 0.8514, 0.515, 0.6},
				{1.043, 1, 0.8613, -0.66, 0.6},
				{1.049, 1, 0.8666, -0.098, 0.6},
				{1.077, 1, 0.8927, 0.474, 0.6},
				{1.09, 1, 0.904, 0.332, 0.6},
				{1.107, 1, 0.9179, 0.535, 0.6},
				{1.111, 1, 0.9217, 0.331, 0.6},
				{1.112, 1, 0.9224, -0.689, 0.6},
				{1.112, 1, 0.9225, 0.497, 0.6},
				{1.113, 1, 0.9233, 0.642, 0.6},
				{1.129, 1, 0.936, -0.317, 0.6},
				{1.135, 1, 0.9404, 0.944, 0.6},
				{1.153, 1, 0.9537, -0.04, 0.6},
				{1.158, 1, 0.9576, 0.207, 0.6},
				{1.196, 1, 0.9816, -0.589, 0.6},
				{1.211, 1, 0.9895, -0.391, 0.6},
				{1.218, 1, 0.9929, 0.026, 0.6},
			},
			offset = {0, 0, 0},
			emit = {},
			rock = {
				size = {1.4, 3.2},
				spin = {-480, 480},
				material = "Slate",
				color = {104, 96, 86},
				aspect = {1, 0.85, 1},
				upright = false,
				stick = 1,
				sink = 0.2,
				ground = true,
				color_var = {0.8, 1.1},
			},
		},
		{
			name = "PlowBoulders",
			type = "meteor",
			direction = "Front",
			pitch = 32,
			spread = {16, 10},
			speed = {50, 80},
			accel = {0, -196, 0},
			drag = 0.1,
			lifetime = {2.3, 2.3},
			trails = {
				{
					name = "PlowBoulderDust",
					rate = 12,
					texture = "kk_smoke_04",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					lifetime = {0.35, 0.55},
					size = {
						{0, 2.5, 0.5},
						{1, 6.25, 1},
					},
					transparency = {
						{0, 0.55, 0},
						{0.5, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{160, 150, 136},
						},
						{
							0.5,
							{138, 128, 116},
						},
						{
							1,
							{112, 104, 94},
						},
					},
					rotation = {0, 360},
					accel = {0, 0, 0},
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
					name = "RockPuff",
					texture = "kk_smoke_04",
					emit = {
						{0, 2},
					},
					direction = "Top",
					spread = {70, 70},
					speed = {4, 9},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 2.5, 0.5},
						{1, 6, 1},
					},
					transparency = {
						{0, 0.45, 0},
						{0.5, 0.6, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{160, 150, 136},
						},
						{
							0.5,
							{138, 128, 116},
						},
						{
							1,
							{112, 104, 94},
						},
					},
					rotation = {0, 360},
					accel = {0, 0, 0},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			shatter = {
				{
					name = "RockCrumble",
					texture = "om_cubes_2x2",
					flipbook = {
						layout = "Grid2x2",
						mode = "Loop",
						fps = 0.001,
						startRandom = true,
					},
					emit = {
						{0, 5},
					},
					shape = {
						type = "Box",
						size = {2, 1, 2},
						style = "Volume",
						inout = "Outward",
					},
					direction = "Top",
					spread = {60, 60},
					speed = {10, 20},
					drag = 0.5,
					accel = {0, -150, 0},
					lifetime = {0.4, 0.6},
					size = {
						{0, 0.7, 0.2},
						{1, 0.5, 0.15},
					},
					color = {
						{
							0,
							{120, 112, 100},
						},
						{
							1,
							{96, 88, 78},
						},
					},
					rotation = {0, 360},
					rot_speed = {-400, 400},
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
				},
				{
					name = "RockCrumbleDust",
					texture = "kk_smoke_04",
					emit = {
						{0, 1},
					},
					direction = "Top",
					spread = {60, 60},
					speed = {2, 5},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 2, 0.5},
						{1, 5, 1},
					},
					transparency = {
						{0, 0.5, 0},
						{0.5, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{160, 150, 136},
						},
						{
							0.5,
							{138, 128, 116},
						},
						{
							1,
							{112, 104, 94},
						},
					},
					rotation = {0, 360},
					accel = {0, 0, 0},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			cone_emit = {
				{0.595, 1, 0.3108, 0.687, 0.6},
				{0.767, 1, 0.5462, 0.028, 0.6},
				{0.805, 1, 0.5946, -0.289, 0.6},
				{0.809, 1, 0.5998, -0.681, 0.6},
				{0.865, 1, 0.6689, 0.603, 0.6},
				{0.865, 1, 0.6691, 0.142, 0.6},
				{0.909, 1, 0.7197, -0.201, 0.6},
				{0.984, 1, 0.8018, 0.539, 0.6},
				{1.04, 1, 0.8582, 0.334, 0.6},
				{1.048, 1, 0.8658, -0.347, 0.6},
				{1.073, 1, 0.8886, -0.617, 0.6},
				{1.124, 1, 0.9318, -0.53, 0.6},
			},
			offset = {0, 0, 0},
			emit = {},
			rock = {
				size = {2.8, 4.8},
				spin = {-300, 300},
				material = "Slate",
				color = {104, 96, 86},
				aspect = {1, 0.8, 1},
				upright = false,
				stick = 1.3,
				sink = 0.25,
				ground = true,
				color_var = {0.8, 1.1},
			},
		},
		{
			name = "EndBurst",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 50,
			spread = {30, 25},
			speed = {25, 50},
			drag = 2.5,
			accel = {0, 2, 0},
			lifetime = {0.9, 1.4},
			size = {
				{0, 6, 1},
				{1, 18, 3},
			},
			transparency = {
				{0, 0.35, 0},
				{0.4, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			cone_emit = {
				{1.177, 2, 0.97, -0.95, 1},
				{1.177, 2, 0.97, -0.777, 1},
				{1.177, 2, 0.97, -0.605, 1},
				{1.177, 2, 0.97, -0.432, 1},
				{1.177, 2, 0.97, -0.259, 1},
				{1.177, 2, 0.97, -0.086, 1},
				{1.177, 2, 0.97, 0.086, 1},
				{1.177, 2, 0.97, 0.259, 1},
				{1.177, 2, 0.97, 0.432, 1},
				{1.177, 2, 0.97, 0.605, 1},
				{1.177, 2, 0.97, 0.777, 1},
				{1.177, 2, 0.97, 0.95, 1},
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
			name = "EndRocks",
			texture = "pb_rock_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 55,
			spread = {30, 25},
			speed = {35, 65},
			drag = 0.4,
			accel = {0, -160, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 2, 0.8},
				{1, 1.6, 0.6},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			cone_emit = {
				{1.177, 3, 0.97, -0.95, 1},
				{1.177, 3, 0.97, -0.739, 1},
				{1.177, 3, 0.97, -0.528, 1},
				{1.177, 3, 0.97, -0.317, 1},
				{1.177, 3, 0.97, -0.106, 1},
				{1.177, 3, 0.97, 0.106, 1},
				{1.177, 3, 0.97, 0.317, 1},
				{1.177, 3, 0.97, 0.528, 1},
				{1.177, 3, 0.97, 0.739, 1},
				{1.177, 3, 0.97, 0.95, 1},
			},
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
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EndFlames",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {25, 25},
			speed = {8, 16},
			drag = 1.2,
			accel = {0, 10, 0},
			lifetime = {0.45, 0.75},
			size = {
				{0, 3, 0.8},
				{0.3, 6, 1.2},
				{1, 1.5, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {-15, 15},
			cone_emit = {
				{1.177, 2, 0.97, -0.95, 0.6},
				{1.177, 2, 0.97, -0.712, 0.6},
				{1.177, 2, 0.97, -0.475, 0.6},
				{1.177, 2, 0.97, -0.238, 0.6},
				{1.177, 2, 0.97, 0, 0.6},
				{1.177, 2, 0.97, 0.238, 0.6},
				{1.177, 2, 0.97, 0.475, 0.6},
				{1.177, 2, 0.97, 0.712, 0.6},
				{1.177, 2, 0.97, 0.95, 0.6},
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
		{0.02, 0.25, 0.36},
		{0.36, 0.9, 0.5},
		{0.49, 0.5, 0.85},
	},
	light = {
		color = {94, 229, 224},
		brightness = 5,
		range = 40,
		time = 0.9,
		delay = 0.36,
	},
	cone = {
		length = 100,
		angle = 42,
		wave = {0.39, 0.85, 1.35},
		head = true,
		mouth_h = 21.5,
	},
	times = {
		Roar = 0.36,
		WaveStart = 0.39,
		WaveEnd = 1.24,
	},
	field = {
		wave = {0.39, 0.85, 1.35},
		groups = {
			{
				name = "RoarSlabs",
				count = 46,
				u = {0.08, 1},
				s = {-1, 1},
				lean = "radial",
				wid = {2, 3.8},
				thick = {0.6, 1.2},
				len = {1.8, 3.6},
				tilt = {18, 46},
				yaw = 16,
				pitch = 12,
				show = 0.62,
				rise = 0.08,
				hold = {1.5, 2.2},
				sink = 0.55,
				delay = {0, 0.05},
				ground = true,
				mesh = "RoarSlab",
			},
			{
				name = "RoarSlabsBig",
				count = 12,
				u = {0.18, 0.95},
				s = {-0.55, 0.55},
				lean = "radial",
				wid = {3.6, 6},
				thick = {1, 1.8},
				len = {3.4, 5.6},
				tilt = {24, 44},
				yaw = 12,
				pitch = 10,
				show = 0.6,
				rise = 0.1,
				hold = {1.5, 2.1},
				sink = 0.6,
				delay = {0, 0.04},
				ground = true,
				mesh = "RoarSlab",
			},
		},
	},
	front = {
		wave = {0.39, 0.85, 1.35},
		count = 12,
		s_max = 0.95,
		emitters = {
			{
				name = "DustWall",
				texture = "fx_smoke_2x2",
				flipbook = {
					layout = "Grid2x2",
					mode = "Loop",
					fps = 0.001,
					startRandom = true,
				},
				direction = "Front",
				spread = {30, 14},
				speed = {45, 85},
				drag = 2.6,
				accel = {0, 2, 0},
				lifetime = {1.2, 1.9},
				size = {
					{0, 6, 1.5},
					{0.25, 13, 2},
					{1, 20, 3},
				},
				transparency = {
					{0, 0.35, 0},
					{0.15, 0.3, 0},
					{0.5, 0.6, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{160, 150, 136},
					},
					{
						0.5,
						{138, 128, 116},
					},
					{
						1,
						{112, 104, 94},
					},
				},
				rotation = {0, 360},
				rot_speed = {-35, 35},
				zoffset = -2,
				light_emission = 0,
				brightness = 1,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 16,
				up = 2,
				pitch = 28,
			},
			{
				name = "DustLow",
				texture = "fx_fog2001",
				direction = "Front",
				spread = {55, 6},
				speed = {35, 70},
				drag = 2,
				accel = {0, 0.5, 0},
				lifetime = {1.8, 2.6},
				size = {
					{0, 6, 1},
					{0.4, 12, 2},
					{1, 16, 2},
				},
				transparency = {
					{0, 0.5, 0},
					{0.15, 0.45, 0},
					{0.5, 0.7, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{118, 109, 98},
					},
					{
						1,
						{92, 85, 77},
					},
				},
				rotation = {0, 360},
				rot_speed = {-20, 20},
				zoffset = -3,
				light_emission = 0,
				brightness = 1,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 12,
				up = 1,
				pitch = 0,
			},
			{
				name = "CarriedRocks",
				texture = "pb_rock_2x2",
				flipbook = {
					layout = "Grid2x2",
					mode = "Loop",
					fps = 0.001,
					startRandom = true,
				},
				direction = "Front",
				spread = {22, 14},
				speed = {70, 120},
				drag = 0.5,
				accel = {0, -150, 0},
				lifetime = {0.5, 0.8},
				size = {
					{0, 2.6, 1},
					{1, 2.2, 0.8},
				},
				transparency = {
					{0, 0, 0},
					{0.85, 0, 0},
					{1, 1, 0},
				},
				rotation = {0, 360},
				rot_speed = {-420, 420},
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
				zoffset = 0,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 14,
				up = 1.5,
				pitch = 26,
			},
			{
				name = "CarriedChips",
				texture = "om_cubes_2x2",
				flipbook = {
					layout = "Grid2x2",
					mode = "Loop",
					fps = 0.001,
					startRandom = true,
				},
				direction = "Front",
				spread = {30, 20},
				speed = {55, 105},
				drag = 0.5,
				accel = {0, -160, 0},
				lifetime = {0.4, 0.7},
				size = {
					{0, 0.8, 0.3},
					{1, 0.6, 0.2},
				},
				color = {
					{
						0,
						{128, 118, 106},
					},
					{
						1,
						{100, 92, 82},
					},
				},
				rotation = {0, 360},
				rot_speed = {-500, 500},
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
				rate = 18,
				up = 1,
				pitch = 34,
			},
			{
				name = "FrontFlames",
				texture = "fx_fire_2x2",
				flipbook = {
					layout = "Grid2x2",
					mode = "Loop",
					fps = 0.001,
					startRandom = true,
				},
				direction = "Top",
				spread = {25, 25},
				speed = {6, 14},
				drag = 1.5,
				accel = {0, 8, 0},
				lifetime = {0.35, 0.6},
				size = {
					{0, 3, 1},
					{0.3, 7, 1.5},
					{1, 2, 0},
				},
				transparency = {
					{0, 0.1, 0},
					{0.6, 0.35, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{175, 255, 250},
					},
					{
						0.3,
						{100, 236, 230},
					},
					{
						0.65,
						{60, 185, 186},
					},
					{
						1,
						{39, 121, 127},
					},
				},
				light_emission = 1,
				brightness = 1.45,
				rotation = {-15, 15},
				rot_speed = {0, 0},
				zoffset = 0,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 12,
				up = 2,
				pitch = 0,
			},
			{
				name = "FrontEmbers",
				texture = "fx_spark002",
				direction = "Front",
				spread = {35, 35},
				speed = {30, 70},
				drag = 2.2,
				accel = {0, 14, 0},
				lifetime = {0.5, 1},
				size = {
					{0, 0, 0},
					{0.08, 1.6, 0},
					{0.22, 0.7, 0},
					{0.38, 1.7, 0},
					{0.55, 0.6, 0},
					{0.72, 1.4, 0},
					{1, 0, 0},
				},
				color = {
					{
						0,
						{255, 255, 255},
					},
					{
						0.5,
						{205, 255, 250},
					},
					{
						1,
						{120, 235, 228},
					},
				},
				light_emission = 1,
				brightness = 2,
				rotation = {0, 45},
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
				rate = 14,
				up = 2,
				pitch = 40,
			},
		},
	},
}

-- PEBLEDON SKILL 1 (Rugido sísmico): junta energía en la boca y ruge hacia adelante: ondas de sonido turquesa, fuego cian y brasas. La onda baja al suelo y avanza en triángulo: parte el suelo, levanta losas, arrastra rocas hacia adelante y deja grietas con venas turquesa de las que brota fuego cian. Ruge a los SeismicRoarTimes.Roar s; el frente sale a los WaveStart s y llega al final a los WaveEnd s (SeismicRoarFrontTime(distancia) = cuándo pasa por cada punto: ahí aplica el daño, la lentitud, la exposición y el empujón).
-- head = la boca (Attachment.WorldCFrame) o la CFrame de la cabeza, mirando hacia adelante: el efecto sale
-- de ahí y el triángulo va por el suelo debajo (lo busca con un rayo; ignora los modelos con Humanoid).
-- length = largo del triángulo en studs (por defecto 100 × escala); angle = apertura en grados (por defecto 42).
function PebledonVFX.SeismicRoar(head: CFrame, length: number?, angle: number?, scale: number?, shake: number?): Part
	return playConeHead(SPEC_SeismicRoar, head, scale, length or 100 * (scale or 1), shake, angle or 42)
end
-- largo y apertura por defecto (studs a escala 1 y grados): para el área del daño en el servidor
PebledonVFX.SeismicRoarLength = 100
PebledonVFX.SeismicRoarAngle = 42
-- segundos (desde la llamada) de cada momento: para sincronizar el daño, el sonido o la cámara
PebledonVFX.SeismicRoarTimes = {
	Roar = 0.36,
	WaveStart = 0.39,
	WaveEnd = 1.24,
}
-- segundos (desde la llamada) en que el frente pasa a `distance` studs del vértice (usa el mismo length
-- con que llamaste el efecto): para aplicar el daño a cada enemigo cuando la onda lo alcanza
function PebledonVFX.SeismicRoarFrontTime(distance: number, length: number?): number
	local u = math.clamp(distance / (length or 100), 0, 1)
	return 0.39 + 0.85 * (1 - (1 - u) ^ (1 / 1.35))
end

local SPEC_BlueBreath = {
	name = "BlueBreath",
	duration = 3.85,
	cleanup = 6.67,
	layers = {
		{
			name = "BChargeMotes",
			texture = "fx_particle02",
			shape = {
				type = "Sphere",
				radius = 12,
				style = "Surface",
				inout = "Inward",
			},
			speed = {30, 40},
			lifetime = {0.28, 0.32},
			size = {
				{0, 0, 0},
				{0.3, 1, 0},
				{1, 0.3, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			stream = {
				{0, 0.52, 90, 130},
			},
			offset = {0, 0, -1.5},
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
			name = "BChargeGlow",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			lifetime = {0.55, 0.55},
			size = {
				{0, 2, 0},
				{0.85, 10, 0},
				{1, 13, 0},
			},
			transparency = {
				{0, 0.8, 0},
				{0.85, 0.3, 0},
				{1, 0.6, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			zoffset = 2,
			offset = {0, 0, -1.5},
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
			name = "BChargeFlames",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Sphere",
				radius = 2,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Front",
			spread = {45, 45},
			speed = {4, 9},
			accel = {0, 6, 0},
			lifetime = {0.2, 0.32},
			size = {
				{0, 1, 0.3},
				{0.35, 2.8, 0.6},
				{1, 0.6, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {0, 360},
			stream = {
				{0.1, 0.55, 20, 70},
			},
			offset = {0, 0, -1.5},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "BMouthFlash",
			texture = "fx_glow",
			emit = {
				{0.55, 1},
			},
			lifetime = {0.22, 0.22},
			size = {
				{0, 6, 0},
				{0.3, 15, 0},
				{1, 16, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 3,
			offset = {0, 0, -1.5},
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
			name = "BMouthFire",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			spread = {30, 30},
			speed = {18, 40},
			drag = 4,
			accel = {0, 4, 0},
			lifetime = {0.18, 0.3},
			size = {
				{0, 2, 0.5},
				{0.4, 5.5, 1.2},
				{1, 3, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {0, 360},
			rot_speed = {-120, 120},
			stream = {
				{0.55, 3.53, 50, 50},
			},
			offset = {0, 0, -1.5},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "BMouthGlow",
			texture = "fx_glow",
			lifetime = {0.14, 0.2},
			size = {
				{0, 9, 1.5},
				{1, 11, 1.5},
			},
			transparency = {
				{0, 0.62, 0},
				{1, 0.85, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 2,
			stream = {
				{0.55, 3.53, 12, 12},
			},
			offset = {0, 0, -1.5},
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
			name = "BFireJet",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			spread = {3, 3},
			speed_len = {3.3333, 3.6},
			lifetime = {0.276, 0.3},
			size = {
				{0, 2.6, 0.6},
				{0.5, 6.5, 1.4},
				{1, 9, 2},
			},
			transparency = {
				{0, 0.25, 0},
				{0.5, 0.35, 0},
				{0.85, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{170, 252, 250},
				},
				{
					0.3,
					{90, 225, 235},
				},
				{
					0.7,
					{45, 165, 210},
				},
				{
					1,
					{30, 110, 170},
				},
			},
			light_emission = 0.7,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-240, 240},
			locked = true,
			stream = {
				{0.55, 3.53, 150, 150},
			},
			speed = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "BFireTongues",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			direction = "Front",
			spread = {3, 3},
			speed_len = {3.3333, 3.6667},
			lifetime = {0.27, 0.3},
			size = {
				{0, 3, 0.8},
				{0.5, 8, 1.5},
				{1, 10, 2},
			},
			transparency = {
				{0, 0.3, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{170, 252, 250},
				},
				{
					0.3,
					{90, 225, 235},
				},
				{
					0.7,
					{45, 165, 210},
				},
				{
					1,
					{30, 110, 170},
				},
			},
			light_emission = 0.7,
			brightness = 1.45,
			locked = true,
			stream = {
				{0.55, 3.53, 80, 80},
			},
			speed = {0, 0},
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
			name = "BEmbers",
			texture = "fx_spark002",
			shape = {
				type = "Box",
				size = {5, 5, 1},
				style = "Volume",
				inout = "Outward",
				len_k = 0.92,
			},
			direction = "Top",
			spread = {180, 180},
			speed = {3, 9},
			drag = 1.5,
			accel = {0, 6, 0},
			lifetime = {0.4, 0.8},
			size = {
				{0, 0, 0},
				{0.08, 1.44, 0},
				{0.22, 0.63, 0},
				{0.38, 1.53, 0},
				{0.55, 0.54, 0},
				{0.72, 1.26, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.9,
			rotation = {0, 45},
			stream = {
				{0.69, 3.53, 30, 30},
			},
			line_u = 0.5,
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
			name = "BHead",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			line_u = 1,
			lifetime = {0.06, 0.09},
			size = {
				{0, 7, 0},
				{1, 9, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{1, 0.5, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			zoffset = 3,
			stream = {
				{0.55, 0.72, 60, 60},
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
			name = "BImpactFlash",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			on_hit = true,
			lifetime = {0.25, 0.25},
			size = {
				{0, 8, 0},
				{0.25, 20, 0},
				{1, 22, 0},
			},
			transparency = {
				{0, 0.45, 0},
				{0.5, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 0.9,
			zoffset = 3,
			line_u = 1,
			offset = {0, 0, 2.5},
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
			name = "BImpactBurst",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 14},
			},
			on_hit = true,
			direction = "Back",
			spread = {80, 80},
			speed = {25, 55},
			drag = 3,
			accel = {0, 10, 0},
			lifetime = {0.35, 0.55},
			size = {
				{0, 3, 1},
				{0.3, 8, 2},
				{1, 3, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {0, 360},
			rot_speed = {-80, 80},
			line_u = 1,
			offset = {0, 0, 2.5},
			impact = true,
			zoffset = 0,
			orientation = "FacingCamera",
		},
		{
			name = "BImpactRocks",
			texture = "pb_rock_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 14},
			},
			on_hit = true,
			direction = "Back",
			spread = {70, 70},
			speed = {30, 70},
			drag = 0.5,
			accel = {0, -150, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 1.8, 0.7},
				{1, 1.5, 0.5},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			line_u = 1,
			offset = {0, 0, 2.5},
			impact = true,
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
			zoffset = 0,
			orientation = "FacingCamera",
		},
		{
			name = "BImpactGlow",
			texture = "fx_glow",
			lifetime = {0.14, 0.2},
			size = {
				{0, 13, 2},
				{1, 16, 2},
			},
			transparency = {
				{0, 0.6, 0},
				{1, 0.85, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 2,
			stream = {
				{0.69, 3.53, 12, 12},
			},
			line_u = 1,
			offset = {0, 0, 2.5},
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
			name = "BImpactFlames",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Back",
			spread = {75, 75},
			speed = {14, 32},
			drag = 2.5,
			accel = {0, 12, 0},
			lifetime = {0.3, 0.5},
			size = {
				{0, 2.5, 0.8},
				{0.3, 6.5, 1.4},
				{1, 1.5, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0.69, 3.53, 45, 45},
			},
			line_u = 1,
			offset = {0, 0, 2.5},
			impact = true,
			zoffset = 0,
			orientation = "FacingCamera",
			emit = {},
		},
		{
			name = "BImpactTongues",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			direction = "Back",
			spread = {80, 80},
			speed = {20, 40},
			drag = 3,
			lifetime = {0.2, 0.35},
			size = {
				{0, 3, 0.8},
				{0.4, 6.5, 1.4},
				{1, 2, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			stream = {
				{0.69, 3.53, 30, 30},
			},
			line_u = 1,
			offset = {0, 0, 2.5},
			impact = true,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			emit = {},
		},
		{
			name = "BImpactChips",
			texture = "pb_rock_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Back",
			spread = {70, 70},
			speed = {30, 65},
			drag = 0.5,
			accel = {0, -150, 0},
			lifetime = {0.5, 0.9},
			size = {
				{0, 1.2, 0.5},
				{1, 1, 0.4},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0, 0},
				{1, 1, 0},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			stream = {
				{0.69, 3.53, 16, 16},
			},
			line_u = 1,
			offset = {0, 0, 2.5},
			impact = true,
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
			zoffset = 0,
			orientation = "FacingCamera",
			emit = {},
		},
		{
			name = "BImpactSparks",
			texture = "fx_spark002",
			direction = "Back",
			spread = {80, 80},
			speed = {20, 50},
			drag = 2,
			accel = {0, 8, 0},
			lifetime = {0.4, 0.8},
			size = {
				{0, 0, 0},
				{0.08, 1.6, 0},
				{0.22, 0.7, 0},
				{0.38, 1.7, 0},
				{0.55, 0.6, 0},
				{0.72, 1.4, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.9,
			rotation = {0, 45},
			stream = {
				{0.69, 3.53, 30, 30},
			},
			line_u = 1,
			offset = {0, 0, 2.5},
			impact = true,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			emit = {},
		},
		{
			name = "BImpactDust",
			texture = "kk_smoke_04",
			direction = "Back",
			spread = {70, 70},
			speed = {8, 18},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 4, 1},
				{1, 12, 2},
			},
			transparency = {
				{0, 0.5, 0},
				{0.4, 0.62, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			zoffset = -2,
			stream = {
				{0.74, 3.53, 10, 10},
			},
			line_u = 1,
			offset = {0, 0, 2.5},
			impact = true,
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			emit = {},
		},
		{
			name = "BCutFlash",
			texture = "fx_glow",
			emit = {
				{3.57, 1},
			},
			lifetime = {0.22, 0.22},
			size = {
				{0, 8, 0},
				{0.3, 18, 0},
				{1, 20, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 3,
			line_u = 1,
			offset = {0, 0, 2.5},
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
			name = "BCutEmbers",
			texture = "fx_spark002",
			emit = {
				{3.57, 24},
			},
			direction = "Back",
			spread = {180, 180},
			speed = {6, 20},
			drag = 1.5,
			accel = {0, 6, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 0, 0},
				{0.08, 1.6, 0},
				{0.22, 0.7, 0},
				{0.38, 1.7, 0},
				{0.55, 0.6, 0},
				{0.72, 1.4, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.9,
			rotation = {0, 45},
			line_u = 1,
			offset = {0, 0, 2.5},
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
		},
		{
			name = "BMouthPuff",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{3.57, 5},
			},
			direction = "Front",
			spread = {30, 30},
			speed = {6, 14},
			drag = 2,
			accel = {0, 4, 0},
			lifetime = {0.6, 0.9},
			size = {
				{0, 3, 1},
				{1, 9, 2},
			},
			transparency = {
				{0, 0.5, 0},
				{0.4, 0.65, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{150, 240, 234},
				},
				{
					0.5,
					{95, 205, 202},
				},
				{
					1,
					{60, 150, 152},
				},
			},
			light_emission = 0.2,
			rotation = {0, 360},
			offset = {0, 0, -1.5},
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "BGroundCracks",
			texture = "pb_vein_cracks",
			emit = {
				{0.02, 1},
			},
			on_hit = true,
			at_ground = true,
			offset = {0, 0.16, 0},
			lifetime = {2.6, 2.6},
			size = {
				{0, 6, 0},
				{0.08, 26, 0},
				{1, 27, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.3, 0},
				{0.7, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 236, 232},
				},
				{
					1,
					{52, 147, 152},
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
			name = "BGroundDark",
			texture = "pb_vein_cracks",
			emit = {
				{0.02, 1},
			},
			on_hit = true,
			at_ground = true,
			offset = {0, 0.12, 0},
			lifetime = {2.8, 2.8},
			size = {
				{0, 8, 0},
				{0.08, 28, 0},
				{1, 29, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.25, 0},
				{0.75, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{34, 30, 27},
				},
				{
					1,
					{40, 36, 32},
				},
			},
			rotation = {0, 360},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "BGroundFlames",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			at_ground = true,
			offset = {0, 0.8, 0},
			shape = {
				type = "Box",
				size = {8, 1, 8},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {10, 10},
			speed = {4, 9},
			accel = {0, 8, 0},
			lifetime = {0.35, 0.6},
			size = {
				{0, 2, 0.6},
				{0.3, 5.5, 1.2},
				{1, 1.5, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {-10, 10},
			stream = {
				{0.74, 3.53, 22, 22},
			},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
			emit = {},
		},
		{
			name = "BTrailCracks",
			texture = "pb_vein_cracks",
			trail = true,
			at_ground = true,
			offset = {0, 0.14, 0},
			lifetime = {2.2, 2.2},
			size = {
				{0, 6, 0},
				{0.1, 18, 0},
				{1, 19, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.06, 0.3, 0},
				{0.75, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 236, 232},
				},
				{
					1,
					{52, 147, 152},
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
			name = "BTrailBurn",
			texture = "fx_glow",
			trail = true,
			at_ground = true,
			offset = {0, 0.18, 0},
			lifetime = {1.6, 1.6},
			size = {
				{0, 5, 0},
				{0.1, 10, 0},
				{1, 9, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.06, 0.25, 0},
				{0.6, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
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
			name = "BTrailDark",
			texture = "pb_vein_cracks",
			trail = true,
			at_ground = true,
			offset = {0, 0.1, 0},
			lifetime = {2.4, 2.4},
			size = {
				{0, 7, 0},
				{0.1, 21, 0},
				{1, 22, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.06, 0.25, 0},
				{0.75, 0.42, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{34, 30, 27},
				},
				{
					1,
					{40, 36, 32},
				},
			},
			rotation = {0, 360},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
			emit = {},
		},
	},
	shakes = {
		{0.69, 0.5, 0.35},
		{3.55, 0.25, 0.3},
	},
	shake_ramp = {0.55, 3.55, 0.15, 0.3, 1},
	beam = {
		start = 0.55,
		grow = 0.14,
		stop = 3.55,
		fade = 0.3,
		max_len = 126,
		trail_every = 0.1,
		trail_move = 4,
		rehit = 0.3,
		light_color = {94, 229, 224},
		light_brightness = 4,
		light_range = 40,
	},
	beams = {
		{
			name = "Glow",
			texture = "kz_beam_glow",
			mode = "Wrap",
			tex_len = 60,
			speed = 0.4,
			light_emission = 1,
			brightness = 0.85,
			color = {
				{
					0,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			transparency = {
				{0, 0.84},
				{0.03, 0.78},
				{1, 0.8},
			},
			width = 24,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.55, 0},
				{0.6, 1.3},
				{0.75, 1},
				{3.5, 1},
				{3.55, 0.75},
				{3.85, 0},
			},
			alpha_t = {
				{0, 0},
				{3.55, 0},
				{3.85, 1},
			},
			pulse = 0.06,
			pulse_hz = 5,
			zoffset = 0,
		},
		{
			name = "FireOuter",
			texture = "pb_breath_fire",
			mode = "Wrap",
			tex_len = 34,
			speed = 4.5,
			light_emission = 0.5,
			brightness = 1.4,
			color = {
				{
					0,
					{50, 185, 215},
				},
				{
					1,
					{35, 140, 185},
				},
			},
			transparency = {
				{0, 0.45},
				{0.04, 0.22},
				{1, 0.3},
			},
			width = 18,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.55, 0},
				{0.6, 1.3},
				{0.75, 1},
				{3.5, 1},
				{3.55, 0.75},
				{3.85, 0},
			},
			alpha_t = {
				{0, 0},
				{3.55, 0},
				{3.85, 1},
			},
			pulse = 0.08,
			pulse_hz = 9,
			zoffset = 0.1,
		},
		{
			name = "FireInner",
			texture = "pb_breath_fire",
			mode = "Wrap",
			tex_len = 22,
			speed = 6.5,
			light_emission = 1,
			brightness = 1.6,
			color = {
				{
					0,
					{120, 245, 240},
				},
				{
					1,
					{70, 210, 210},
				},
			},
			transparency = {
				{0, 0.35},
				{0.04, 0.1},
				{1, 0.15},
			},
			width = 8.5,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.55, 0},
				{0.6, 1.3},
				{0.75, 1},
				{3.5, 1},
				{3.55, 0.75},
				{3.85, 0},
			},
			alpha_t = {
				{0, 0},
				{3.55, 0},
				{3.85, 1},
			},
			pulse = 0.08,
			pulse_hz = 13,
			zoffset = 0.2,
		},
		{
			name = "Core",
			texture = "kz_beam_core",
			mode = "Wrap",
			tex_len = 18,
			speed = 3.5,
			light_emission = 1,
			brightness = 2.2,
			color = {
				{
					0,
					{240, 255, 254},
				},
				{
					1,
					{210, 255, 251},
				},
			},
			transparency = {
				{0, 0.2},
				{0.03, 0},
				{1, 0},
			},
			width = 3.2,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.55, 0},
				{0.6, 1.3},
				{0.75, 1},
				{3.5, 1},
				{3.55, 0.75},
				{3.85, 0},
			},
			alpha_t = {
				{0, 0},
				{3.55, 0},
				{3.85, 1},
			},
			pulse = 0.08,
			pulse_hz = 15,
			zoffset = 0.3,
		},
	},
}

-- PEBLEDON SKILL 2 (Aliento azul): como el aliento de Godzilla: junta energía en la boca 0.55 s y escupe fuego azul concentrado que se mantiene recto (núcleo casi blanco, fuego turquesa en vetas y llamas que corren pegadas al rayo), sin aros. Dura 3 s y se puede apuntar: pega en la primera superficie (hasta 126 studs × escala = 3 veces su largo); el fuego salpica, saltan rocas y el suelo queda con grietas que arden (estela si lo barre).
-- origin = de dónde sale: un Attachment en la boca (lo sigue solo), una Part, un Vector3 o un CFrame.
-- target = hacia dónde apunta: el rival (Model o Part: lo sigue solo) o un punto (Vector3 o CFrame).
-- ignore = lo que el rayo atraviesa (el modelo de quien lo lanza). Se corta en la primera superficie
-- que toca y nunca pasa de su largo máximo (126 studs × escala). Devuelve un control:
--   rayo:AimAt(objetivo)     apunta a otro lado (Model, Part, Vector3 o CFrame; si se mueve, lo sigue)
--   rayo:SetDirection(dir)   apunta en una dirección (Vector3)
--   rayo:SetOrigin(origen)   cambia de dónde sale
--   rayo:Stop()              lo corta antes de tiempo
--   rayo.MaxLength           largo máximo (lo puedes cambiar); rayo.Length = largo de ahora
--   rayo.HitPosition, rayo.HitInstance = dónde y qué está tocando (nil si no toca nada)
--   rayo.Active = true mientras se ve; rayo.Holder = la Part que lo contiene
function PebledonVFX.BlueBreath(origin: any, target: any, scale: number?, shake: number?, ignore: { Instance }?): BeamControl
	return playBeam(SPEC_BlueBreath, origin, target, scale, shake, ignore)
end
-- segundos (desde la llamada) en que llega a su largo máximo y en que se corta solo
PebledonVFX.BlueBreathStart = 0.69
PebledonVFX.BlueBreathStop = 3.55

local SPEC_CrystalSpire = {
	name = "CrystalSpire",
	duration = 11.6,
	cleanup = 13.26,
	layers = {
		{
			name = "StompFlash",
			texture = "fx_glow",
			lifetime = {0.2, 0.2},
			size = {
				{0, 4, 0},
				{0.3, 14, 0},
				{1, 16, 0},
			},
			transparency = {
				{0, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 2,
			path_emit = {
				{0, 1, 0, 0, 1},
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
			name = "StompCracks",
			texture = "pb_vein_cracks",
			lifetime = {1.6, 1.6},
			rotation = {0, 360},
			size = {
				{0, 5, 0},
				{0.08, 20, 0},
				{1, 21, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.06, 0.3, 0},
				{0.7, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 236, 232},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 0.8,
			path_emit = {
				{0, 1, 0, 0, 0.15},
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
			name = "StompDark",
			texture = "pb_vein_cracks",
			lifetime = {2, 2},
			rotation = {0, 360},
			size = {
				{0, 6, 0},
				{0.08, 24, 0},
				{1, 25, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.06, 0.25, 0},
				{0.75, 0.42, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{34, 30, 27},
				},
				{
					1,
					{40, 36, 32},
				},
			},
			path_emit = {
				{0, 1, 0, 0, 0.1},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "StompDust",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {85, 85},
			speed = {14, 28},
			drag = 3,
			accel = {0, 2, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 5, 1},
				{1, 15, 3},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.58, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			path_emit = {
				{0, 18, 0, 0, 1},
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
			name = "StompChips",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {50, 50},
			speed = {18, 36},
			accel = {0, -150, 0},
			lifetime = {0.4, 0.7},
			size = {
				{0, 1, 0.3},
				{1, 0.8, 0.2},
			},
			color = {
				{
					0,
					{128, 118, 106},
				},
				{
					1,
					{100, 92, 82},
				},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			path_emit = {
				{0, 16, 0, 0, 0.5},
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
			name = "PathGlow",
			texture = "fx_glow",
			lifetime = {0.9, 1.2},
			size = {
				{0, 3, 0},
				{0.1, 9, 1},
				{1, 7, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.35, 0},
				{0.6, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			path_emit = {
				{0.044, 1, 0.06, 0, 0.18},
				{0.07, 1, 0.1262, 0, 0.18},
				{0.097, 1, 0.1923, 0, 0.18},
				{0.123, 1, 0.2585, 0, 0.18},
				{0.15, 1, 0.3246, 0, 0.18},
				{0.176, 1, 0.3908, 0, 0.18},
				{0.203, 1, 0.4569, 0, 0.18},
				{0.229, 1, 0.5231, 0, 0.18},
				{0.256, 1, 0.5892, 0, 0.18},
				{0.282, 1, 0.6554, 0, 0.18},
				{0.309, 1, 0.7215, 0, 0.18},
				{0.335, 1, 0.7877, 0, 0.18},
				{0.362, 1, 0.8538, 0, 0.18},
				{0.388, 1, 0.92, 0, 0.18},
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
			name = "PathCracks",
			texture = "pb_vein_cracks",
			lifetime = {1.5, 1.9},
			rotation = {0, 360},
			size = {
				{0, 5, 0},
				{0.08, 17, 2},
				{1, 18, 2},
			},
			transparency = {
				{0, 1, 0},
				{0.06, 0.2, 0},
				{0.7, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 236, 232},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 0.9,
			path_emit = {
				{0.044, 1, 0.06, 0, 0.15},
				{0.07, 1, 0.1262, 0, 0.15},
				{0.097, 1, 0.1923, 0, 0.15},
				{0.123, 1, 0.2585, 0, 0.15},
				{0.15, 1, 0.3246, 0, 0.15},
				{0.176, 1, 0.3908, 0, 0.15},
				{0.203, 1, 0.4569, 0, 0.15},
				{0.229, 1, 0.5231, 0, 0.15},
				{0.256, 1, 0.5892, 0, 0.15},
				{0.282, 1, 0.6554, 0, 0.15},
				{0.309, 1, 0.7215, 0, 0.15},
				{0.335, 1, 0.7877, 0, 0.15},
				{0.362, 1, 0.8538, 0, 0.15},
				{0.388, 1, 0.92, 0, 0.15},
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
			name = "PathDark",
			texture = "pb_vein_cracks",
			lifetime = {2.4, 2.8},
			rotation = {0, 360},
			size = {
				{0, 6, 0},
				{0.08, 19, 2},
				{1, 20, 2},
			},
			transparency = {
				{0, 1, 0},
				{0.06, 0.25, 0},
				{0.75, 0.42, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{34, 30, 27},
				},
				{
					1,
					{40, 36, 32},
				},
			},
			path_emit = {
				{0.044, 1, 0.06, 0, 0.1},
				{0.07, 1, 0.1262, 0, 0.1},
				{0.097, 1, 0.1923, 0, 0.1},
				{0.123, 1, 0.2585, 0, 0.1},
				{0.15, 1, 0.3246, 0, 0.1},
				{0.176, 1, 0.3908, 0, 0.1},
				{0.203, 1, 0.4569, 0, 0.1},
				{0.229, 1, 0.5231, 0, 0.1},
				{0.256, 1, 0.5892, 0, 0.1},
				{0.282, 1, 0.6554, 0, 0.1},
				{0.309, 1, 0.7215, 0, 0.1},
				{0.335, 1, 0.7877, 0, 0.1},
				{0.362, 1, 0.8538, 0, 0.1},
				{0.388, 1, 0.92, 0, 0.1},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "PathDust",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {30, 30},
			speed = {8, 16},
			drag = 2,
			accel = {0, 2, 0},
			lifetime = {0.8, 1.2},
			size = {
				{0, 4, 1},
				{1, 12, 2},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.58, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			path_emit = {
				{0.04, 3, 0.05, 0, 1},
				{0.067, 3, 0.1169, 0, 1},
				{0.094, 3, 0.1838, 0, 1},
				{0.12, 3, 0.2508, 0, 1},
				{0.147, 3, 0.3177, 0, 1},
				{0.174, 3, 0.3846, 0, 1},
				{0.201, 3, 0.4515, 0, 1},
				{0.227, 3, 0.5185, 0, 1},
				{0.254, 3, 0.5854, 0, 1},
				{0.281, 3, 0.6523, 0, 1},
				{0.308, 3, 0.7192, 0, 1},
				{0.334, 3, 0.7862, 0, 1},
				{0.361, 3, 0.8531, 0, 1},
				{0.388, 3, 0.92, 0, 1},
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
			name = "PathChunks",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {35, 35},
			speed = {20, 40},
			drag = 0.4,
			accel = {0, -150, 0},
			lifetime = {0.5, 0.8},
			size = {
				{0, 1.8, 0.7},
				{1, 1.5, 0.5},
			},
			color = {
				{
					0,
					{128, 118, 106},
				},
				{
					1,
					{100, 92, 82},
				},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			path_emit = {
				{0.04, 4, 0.05, 0, 0.6},
				{0.067, 4, 0.1169, 0, 0.6},
				{0.094, 4, 0.1838, 0, 0.6},
				{0.12, 4, 0.2508, 0, 0.6},
				{0.147, 4, 0.3177, 0, 0.6},
				{0.174, 4, 0.3846, 0, 0.6},
				{0.201, 4, 0.4515, 0, 0.6},
				{0.227, 4, 0.5185, 0, 0.6},
				{0.254, 4, 0.5854, 0, 0.6},
				{0.281, 4, 0.6523, 0, 0.6},
				{0.308, 4, 0.7192, 0, 0.6},
				{0.334, 4, 0.7862, 0, 0.6},
				{0.361, 4, 0.8531, 0, 0.6},
				{0.388, 4, 0.92, 0, 0.6},
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
			name = "PathFlames",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {15, 15},
			speed = {5, 10},
			accel = {0, 8, 0},
			lifetime = {0.3, 0.5},
			size = {
				{0, 2, 0.6},
				{0.3, 5, 1},
				{1, 1.2, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {-10, 10},
			path_emit = {
				{0.04, 2, 0.05, 0, 0.6},
				{0.067, 2, 0.1169, 0, 0.6},
				{0.094, 2, 0.1838, 0, 0.6},
				{0.12, 2, 0.2508, 0, 0.6},
				{0.147, 2, 0.3177, 0, 0.6},
				{0.174, 2, 0.3846, 0, 0.6},
				{0.201, 2, 0.4515, 0, 0.6},
				{0.227, 2, 0.5185, 0, 0.6},
				{0.254, 2, 0.5854, 0, 0.6},
				{0.281, 2, 0.6523, 0, 0.6},
				{0.308, 2, 0.7192, 0, 0.6},
				{0.334, 2, 0.7862, 0, 0.6},
				{0.361, 2, 0.8531, 0, 0.6},
				{0.388, 2, 0.92, 0, 0.6},
			},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "PathSparks",
			texture = "fx_spark002",
			direction = "Top",
			spread = {35, 35},
			speed = {8, 18},
			drag = 1.5,
			accel = {0, 6, 0},
			lifetime = {0.4, 0.8},
			size = {
				{0, 0, 0},
				{0.08, 1.44, 0},
				{0.22, 0.63, 0},
				{0.38, 1.53, 0},
				{0.55, 0.54, 0},
				{0.72, 1.26, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.9,
			rotation = {0, 45},
			path_emit = {
				{0.04, 3, 0.05, 0, 0.8},
				{0.067, 3, 0.1169, 0, 0.8},
				{0.094, 3, 0.1838, 0, 0.8},
				{0.12, 3, 0.2508, 0, 0.8},
				{0.147, 3, 0.3177, 0, 0.8},
				{0.174, 3, 0.3846, 0, 0.8},
				{0.201, 3, 0.4515, 0, 0.8},
				{0.227, 3, 0.5185, 0, 0.8},
				{0.254, 3, 0.5854, 0, 0.8},
				{0.281, 3, 0.6523, 0, 0.8},
				{0.308, 3, 0.7192, 0, 0.8},
				{0.334, 3, 0.7862, 0, 0.8},
				{0.361, 3, 0.8531, 0, 0.8},
				{0.388, 3, 0.92, 0, 0.8},
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
			name = "EruptFlash",
			texture = "fx_glow",
			lifetime = {0.3, 0.3},
			size = {
				{0, 10, 0},
				{0.25, 44, 0},
				{1, 48, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.5, 0.65, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 4,
			ring_emit = {
				{0.44, 1, 0, 0, 6},
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
			name = "EruptStar",
			texture = "kk_star_09",
			lifetime = {0.25, 0.25},
			size = {
				{0, 8, 0},
				{0.2, 40, 0},
				{1, 10, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {0, 90},
			zoffset = 5,
			ring_emit = {
				{0.56, 1, 0, 0, 18},
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
			name = "EruptFire",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {55, 55},
			speed = {20, 48},
			drag = 2.5,
			accel = {0, 10, 0},
			lifetime = {0.4, 0.7},
			size = {
				{0, 4, 1},
				{0.3, 10, 2},
				{1, 4, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			radial = false,
			ring_emit = {
				{0.44, 20, 0, 0, 1.5},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EruptTongues",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {55, 55},
			speed = {25, 50},
			drag = 3,
			lifetime = {0.3, 0.5},
			size = {
				{0, 4, 1},
				{0.4, 10, 2},
				{1, 3, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			radial = false,
			ring_emit = {
				{0.46, 16, 0, 0, 2},
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
			name = "EruptRocks",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {65, 65},
			speed = {35, 75},
			drag = 0.4,
			accel = {0, -150, 0},
			lifetime = {0.8, 1.3},
			size = {
				{0, 3, 1},
				{1, 2.6, 0.8},
			},
			color = {
				{
					0,
					{128, 118, 106},
				},
				{
					1,
					{100, 92, 82},
				},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			radial = false,
			ring_emit = {
				{0.44, 40, 0, 0, 2},
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
			name = "EruptDust",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 12,
			spread = {12, 8},
			speed = {28, 50},
			drag = 2.5,
			accel = {0, 2, 0},
			lifetime = {1, 1.5},
			size = {
				{0, 6, 1.5},
				{1, 18, 3},
			},
			transparency = {
				{0, 0.35, 0},
				{0.4, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			ring_emit = {
				{0.46, 1, 0, 0.0312, 2},
				{0.46, 1, 0.0714, 0.0312, 2},
				{0.46, 1, 0.1429, 0.0312, 2},
				{0.46, 1, 0.2143, 0.0312, 2},
				{0.46, 1, 0.2857, 0.0312, 2},
				{0.46, 1, 0.3571, 0.0312, 2},
				{0.46, 1, 0.4286, 0.0312, 2},
				{0.46, 1, 0.5, 0.0312, 2},
				{0.46, 1, 0.5714, 0.0312, 2},
				{0.46, 1, 0.6429, 0.0312, 2},
				{0.46, 1, 0.7143, 0.0312, 2},
				{0.46, 1, 0.7857, 0.0312, 2},
				{0.46, 1, 0.8571, 0.0312, 2},
				{0.46, 1, 0.9286, 0.0312, 2},
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
			name = "EruptCracks",
			texture = "pb_vein_cracks",
			lifetime = {10.54, 10.54},
			rotation = {0, 360},
			size = {
				{0, 10, 0},
				{0.02, 52, 0},
				{1, 54, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.01, 0.3, 0},
				{0.9, 0.42, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 236, 232},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 0.9,
			ring_emit = {
				{0.45, 1, 0, 0, 0.2},
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
			name = "EruptDark",
			texture = "pb_vein_cracks",
			lifetime = {10.74, 10.74},
			rotation = {0, 360},
			size = {
				{0, 12, 0},
				{0.02, 60, 0},
				{1, 62, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.01, 0.2, 0},
				{0.9, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{34, 30, 27},
				},
				{
					1,
					{40, 36, 32},
				},
			},
			ring_emit = {
				{0.45, 1, 0, 0, 0.12},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "BuffRing",
			texture = "pb_buff_ring",
			lifetime = {9.54, 9.54},
			size = {
				{0, 60.3015, 0},
				{0.02, 207.0352, 0},
				{0.035, 201.005, 0},
				{0.9581, 201.005, 0},
				{0.979, 110.5528, 0},
				{1, 16.0804, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.015, 0.05, 0},
				{0.05, 0.25, 0},
				{0.3, 0.36, 0},
				{0.55, 0.28, 0},
				{0.8, 0.36, 0},
				{0.869, 0.32, 0},
				{0.8847, 0.75, 0},
				{0.9004, 0.3, 0},
				{0.9161, 0.75, 0},
				{0.9319, 0.3, 0},
				{0.9476, 0.75, 0},
				{0.9581, 0.1, 0},
				{0.979, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{150, 250, 245},
				},
				{
					1,
					{110, 236, 232},
				},
			},
			light_emission = 1,
			ring_emit = {
				{0.51, 1, 0, 0, 0.25},
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
			name = "BuffGlow",
			texture = "fx_glow",
			lifetime = {9.54, 9.54},
			size = {
				{0, 100.5025, 0},
				{0.02, 190.9548, 0},
				{0.9581, 190.9548, 0},
				{1, 20.1005, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.02, 0.84, 0},
				{0.9, 0.88, 0},
				{0.9581, 0.78, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			ring_emit = {
				{0.51, 1, 0, 0, 0.2},
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
			name = "RingFlames",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			zdist = {
				r = {0.97, 1},
				h = {0.2, 0.4},
				area = false,
			},
			direction = "Top",
			spread = {8, 8},
			speed = {3, 7},
			accel = {0, 6, 0},
			lifetime = {0.35, 0.6},
			size = {
				{0, 1.5, 0.5},
				{0.3, 3.8, 0.8},
				{1, 1, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.6, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {-10, 10},
			radial = false,
			zstream = {
				{0.56, 8.8, 115, 115},
				{8.8, 10, 115, 30},
			},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "RingEmbers",
			texture = "fx_spark002",
			zdist = {
				r = {0.95, 1},
				h = {0.3, 1},
				area = false,
			},
			direction = "Top",
			spread = {20, 20},
			speed = {4, 9},
			drag = 1,
			accel = {0, 4, 0},
			lifetime = {0.7, 1.3},
			size = {
				{0, 0, 0},
				{0.08, 1.28, 0},
				{0.22, 0.56, 0},
				{0.38, 1.36, 0},
				{0.55, 0.48, 0},
				{0.72, 1.12, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.9,
			rotation = {0, 45},
			radial = false,
			zstream = {
				{0.56, 8.8, 65, 65},
				{8.8, 10, 65, 15},
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
			name = "CrystalGlow",
			texture = "fx_glow",
			zdist = {
				r = {0, 0.0104},
				h = {8, 26},
				area = false,
			},
			lifetime = {0.5, 0.8},
			size = {
				{0, 16, 3},
				{1, 20, 3},
			},
			transparency = {
				{0, 0.86, 0},
				{0.5, 0.76, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1,
			radial = false,
			zstream = {
				{0.58, 8.8, 8, 8},
				{8.8, 10, 8, 22},
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
			name = "BaseFlames",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			zdist = {
				r = {0.039, 0.0936},
				h = {0.2, 0.6},
				area = false,
			},
			direction = "Top",
			spread = {12, 12},
			speed = {6, 12},
			accel = {0, 9, 0},
			lifetime = {0.45, 0.75},
			size = {
				{0, 3, 0.8},
				{0.3, 8, 1.6},
				{1, 2, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {-15, 15},
			radial = false,
			zstream = {
				{0.56, 1.06, 80, 40},
				{1.06, 10, 40, 40},
				{10, 10.7, 40, 0},
			},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "BaseTongues",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			zdist = {
				r = {0.039, 0.104},
				h = {0.2, 0.5},
				area = false,
			},
			direction = "Top",
			spread = {10, 10},
			speed = {4, 9},
			accel = {0, 8, 0},
			lifetime = {0.35, 0.6},
			size = {
				{0, 2, 0.6},
				{0.3, 6, 1.2},
				{1, 1.5, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {-10, 10},
			radial = false,
			zstream = {
				{0.56, 10, 16, 16},
			},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CrystalEmbers",
			texture = "fx_spark002",
			zdist = {
				r = {0, 0.091},
				h = {0.5, 3},
				area = false,
			},
			direction = "Top",
			spread = {25, 25},
			speed = {6, 14},
			drag = 1,
			accel = {0, 4, 0},
			lifetime = {0.8, 1.6},
			size = {
				{0, 0, 0},
				{0.08, 1.6, 0},
				{0.22, 0.7, 0},
				{0.38, 1.7, 0},
				{0.55, 0.6, 0},
				{0.72, 1.4, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.9,
			rotation = {0, 45},
			radial = false,
			zstream = {
				{0.66, 10, 18, 18},
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
			name = "CrystalGlints",
			texture = "kk_star_09",
			zdist = {
				r = {0, 0.0364},
				h = {3, 28},
				area = false,
			},
			lifetime = {0.3, 0.5},
			size = {
				{0, 0, 0},
				{0.08, 3.84, 0},
				{0.22, 1.68, 0},
				{0.38, 4.08, 0},
				{0.55, 1.44, 0},
				{0.72, 3.36, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			rotation = {0, 45},
			zoffset = 6,
			radial = false,
			zstream = {
				{0.76, 8.8, 4, 4},
				{8.8, 10, 6, 18},
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
			name = "CrystalCracks",
			texture = "pb_vein_cracks",
			zdist = {
				r = {0, 0.0156},
				h = {3, 28},
				area = false,
			},
			lifetime = {0.25, 0.45},
			size = {
				{0, 2, 0},
				{0.15, 6, 1.5},
				{1, 6.5, 1.5},
			},
			transparency = {
				{0, 0.6, 0},
				{0.2, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			rotation = {0, 360},
			zoffset = 6,
			radial = false,
			zstream = {
				{8.8, 10, 6, 30},
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
			name = "CrumbleGlow",
			texture = "fx_glow",
			lifetime = {0.4, 0.4},
			size = {
				{0, 10, 0},
				{0.25, 30, 0},
				{1, 32, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{0.5, 0.75, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 0.9,
			zoffset = 4,
			ring_emit = {
				{10, 1, 0, 0, 14},
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
			name = "CrumbleDust",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 18,
			spread = {15, 10},
			speed = {14, 30},
			drag = 2.5,
			accel = {0, 3, 0},
			lifetime = {1, 1.5},
			size = {
				{0, 6, 1},
				{1, 17, 3},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.58, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			ring_emit = {
				{10.1, 1, 0, 0.026, 2},
				{10.1, 1, 0.0833, 0.026, 2},
				{10.1, 1, 0.1667, 0.026, 2},
				{10.1, 1, 0.25, 0.026, 2},
				{10.1, 1, 0.3333, 0.026, 2},
				{10.1, 1, 0.4167, 0.026, 2},
				{10.1, 1, 0.5, 0.026, 2},
				{10.1, 1, 0.5833, 0.026, 2},
				{10.1, 1, 0.6667, 0.026, 2},
				{10.1, 1, 0.75, 0.026, 2},
				{10.1, 1, 0.8333, 0.026, 2},
				{10.1, 1, 0.9167, 0.026, 2},
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
			name = "CrumbleColumn",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {25, 25},
			speed = {8, 18},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {1, 1.4},
			size = {
				{0, 8, 2},
				{1, 20, 3},
			},
			transparency = {
				{0, 0.5, 0},
				{0.4, 0.62, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			radial = false,
			ring_emit = {
				{10.15, 6, 0, 0, 3},
			},
			light_emission = 0,
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
	},
	shakes = {
		{0, 0.6, 0.3},
		{0.1, 0.35, 0.4},
		{0.44, 1, 0.55},
		{10, 0.45, 0.8},
	},
	zone = {
		radius = 100,
		height = 40,
	},
	lights = {
		{
			t = 0.44,
			h = 6,
			color = {94, 229, 224},
			brightness = 7,
			range = 50,
			rise = 0.03,
			hold = 0.1,
			fall = 0.5,
		},
		{
			t = 0.46,
			h = 18,
			color = {94, 229, 224},
			brightness = 2.5,
			range = 45,
			rise = 0.25,
			hold = 9.29,
			fall = 0.8,
		},
		{
			t = 10,
			h = 12,
			color = {94, 229, 224},
			brightness = 3.5,
			range = 45,
			rise = 0.05,
			hold = 0.1,
			fall = 0.6,
		},
	},
	times = {
		Stomp = 0,
		Erupt = 0.44,
		Crystal = 0.6,
		Warning = 8.8,
		End = 10,
	},
	cubes = {
		gravity = 170,
		bounce = 0.3,
		friction = 0.55,
		spin = {240, 820},
		rest = {0.4, 1},
		fade = 0.35,
		settle = 0.12,
		shrink = {0.16, 0.26},
		dissolve_time = {0.2, 0.5},
		color_var = {0.75, 1.08},
		dark = 0.12,
		neon_colors = {
			{94, 229, 224},
			{52, 147, 152},
			{150, 245, 240},
		},
		groups = {
			{
				name = "Erupt",
				mode = "blast",
				count = 110,
				t = {0.44, 0.49},
				r = {0.0052, 0.117},
				size = {0.8, 3.6},
				skew = 2.2,
				out = {18, 55},
				up = {45, 100},
				dissolve = 0.35,
				neon = 0.18,
			},
			{
				name = "CrumbleTop",
				mode = "blast",
				count = 16,
				t = {10, 10.15},
				r = {0, 0.026},
				h = {14, 26},
				size = {1.2, 3.4},
				skew = 1.6,
				out = {8, 24},
				up = {4, 22},
				dissolve = 0.4,
				neon = 0.85,
			},
			{
				name = "CrumbleLow",
				mode = "blast",
				count = 18,
				t = {10.1, 10.5},
				r = {0, 0.0364},
				h = {2, 13},
				size = {0.8, 2.8},
				skew = 1.8,
				out = {10, 28},
				up = {8, 26},
				dissolve = 0.4,
				neon = 0.8,
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
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
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
	zfield = {
		groups = {
			{
				hold = {1, 1},
				sink = 0.9,
				name = "PebledonCrystal",
				count = 1,
				r = {0, 0},
				centered = true,
				hex = true,
				query = true,
				part_name = "PebledonCrystal",
				lean = "random",
				wid = {9.5, 9.5},
				thick = {30, 30},
				len = {9.5, 9.5},
				tilt = {0, 0},
				yaw = 180,
				pitch = 0,
				show = 0.93,
				rise = 0.14,
				t = 0.46,
				delay = {0, 0},
				end_at = {10, 10},
				["end"] = "crumble",
				ice = {
					color = {94, 229, 224},
					material = "Glass",
					transparency = 0.3,
				},
				tip = 0.85,
				mesh = "PebledonCrystal",
				shatter = {
					{
						name = "ShardBurst",
						texture = "mf_shard_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 40},
						},
						shape = {
							type = "Box",
							size = {8, 26, 8},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {14, 38},
						drag = 0.5,
						accel = {0, -110, 0},
						lifetime = {0.6, 1.1},
						size = {
							{0, 1.8, 0.6},
							{1, 1.3, 0.4},
						},
						transparency = {
							{0, 0, 0},
							{0.85, 0.1, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{215, 255, 252},
							},
							{
								0.4,
								{94, 229, 224},
							},
							{
								1,
								{52, 147, 152},
							},
						},
						light_emission = 0.6,
						brightness = 1.5,
						rotation = {0, 360},
						rot_speed = {-500, 500},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardGlints",
						texture = "kk_star_09",
						emit = {
							{0, 14},
						},
						shape = {
							type = "Box",
							size = {8, 26, 8},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {3, 9},
						drag = 2,
						lifetime = {0.3, 0.55},
						size = {
							{0, 0, 0},
							{0.08, 4.48, 0},
							{0.22, 1.96, 0},
							{0.38, 4.76, 0},
							{0.55, 1.68, 0},
							{0.72, 3.92, 0},
							{1, 0, 0},
						},
						color = {
							{
								0,
								{255, 255, 255},
							},
							{
								0.5,
								{205, 255, 250},
							},
							{
								1,
								{120, 235, 228},
							},
						},
						light_emission = 1,
						brightness = 2,
						rotation = {0, 45},
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
						name = "ShardFire",
						texture = "fx_fire_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 18},
						},
						shape = {
							type = "Box",
							size = {8, 26, 8},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {40, 40},
						speed = {6, 14},
						drag = 1.5,
						accel = {0, 8, 0},
						lifetime = {0.35, 0.6},
						size = {
							{0, 3, 1},
							{0.3, 7, 1.5},
							{1, 2, 0},
						},
						transparency = {
							{0, 0.15, 0},
							{0.6, 0.42, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{175, 255, 250},
							},
							{
								0.3,
								{100, 236, 230},
							},
							{
								0.65,
								{60, 185, 186},
							},
							{
								1,
								{39, 121, 127},
							},
						},
						light_emission = 1,
						brightness = 1.45,
						rotation = {0, 360},
						rot_speed = {0, 0},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardDust",
						texture = "fx_smoke_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 6},
						},
						shape = {
							type = "Box",
							size = {8, 26, 8},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {60, 60},
						speed = {4, 10},
						drag = 2,
						accel = {0, 2, 0},
						lifetime = {0.8, 1.2},
						size = {
							{0, 4, 1},
							{1, 11, 2},
						},
						transparency = {
							{0, 0.45, 0},
							{0.4, 0.6, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{160, 150, 136},
							},
							{
								0.5,
								{138, 128, 116},
							},
							{
								1,
								{112, 104, 94},
							},
						},
						rotation = {0, 360},
						rot_speed = {-30, 30},
						light_emission = 0,
						brightness = 1,
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
				},
			},
			{
				hold = {1, 1},
				sink = 0.9,
				name = "CrystalCore",
				count = 1,
				r = {0, 0},
				centered = true,
				hex = true,
				lean = "random",
				wid = {5.6, 5.6},
				thick = {27, 27},
				len = {5.6, 5.6},
				tilt = {0, 0},
				yaw = 180,
				pitch = 0,
				show = 0.93,
				rise = 0.14,
				t = 0.46,
				delay = {0, 0},
				end_at = {10, 10},
				["end"] = "crumble",
				ice = {
					color = {60, 205, 205},
					material = "Neon",
					transparency = 0.05,
				},
				tip = 0.85,
				mesh = "CrystalCore",
			},
			{
				hold = {1, 1},
				sink = 0.6,
				name = "CrystalShards",
				count = 6,
				ring = true,
				r = {0.039, 0.0572},
				hex = true,
				lean = "radial",
				wid = {4, 5.6},
				thick = {11, 18},
				len = {4, 5.6},
				tilt = {18, 32},
				yaw = 10,
				pitch = 6,
				show = 0.86,
				rise = 0.13,
				t = 0.51,
				delay = {0, 0.07},
				end_at = {9.6, 9.95},
				["end"] = "crumble",
				ice = {
					color = {110, 236, 232},
					material = "Glass",
					transparency = 0.25,
				},
				tip = 0.85,
				mesh = "CrystalShards",
				shatter = {
					{
						name = "ShardBurst",
						texture = "mf_shard_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 10},
						},
						shape = {
							type = "Box",
							size = {4, 12, 4},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {14, 38},
						drag = 0.5,
						accel = {0, -110, 0},
						lifetime = {0.6, 1.1},
						size = {
							{0, 1.8, 0.6},
							{1, 1.3, 0.4},
						},
						transparency = {
							{0, 0, 0},
							{0.85, 0.1, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{215, 255, 252},
							},
							{
								0.4,
								{94, 229, 224},
							},
							{
								1,
								{52, 147, 152},
							},
						},
						light_emission = 0.6,
						brightness = 1.5,
						rotation = {0, 360},
						rot_speed = {-500, 500},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardGlints",
						texture = "kk_star_09",
						emit = {
							{0, 4},
						},
						shape = {
							type = "Box",
							size = {4, 12, 4},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {3, 9},
						drag = 2,
						lifetime = {0.3, 0.55},
						size = {
							{0, 0, 0},
							{0.08, 4.48, 0},
							{0.22, 1.96, 0},
							{0.38, 4.76, 0},
							{0.55, 1.68, 0},
							{0.72, 3.92, 0},
							{1, 0, 0},
						},
						color = {
							{
								0,
								{255, 255, 255},
							},
							{
								0.5,
								{205, 255, 250},
							},
							{
								1,
								{120, 235, 228},
							},
						},
						light_emission = 1,
						brightness = 2,
						rotation = {0, 45},
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
						name = "ShardFire",
						texture = "fx_fire_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 5},
						},
						shape = {
							type = "Box",
							size = {4, 12, 4},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {40, 40},
						speed = {6, 14},
						drag = 1.5,
						accel = {0, 8, 0},
						lifetime = {0.35, 0.6},
						size = {
							{0, 3, 1},
							{0.3, 7, 1.5},
							{1, 2, 0},
						},
						transparency = {
							{0, 0.15, 0},
							{0.6, 0.42, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{175, 255, 250},
							},
							{
								0.3,
								{100, 236, 230},
							},
							{
								0.65,
								{60, 185, 186},
							},
							{
								1,
								{39, 121, 127},
							},
						},
						light_emission = 1,
						brightness = 1.45,
						rotation = {0, 360},
						rot_speed = {0, 0},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardDust",
						texture = "fx_smoke_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 2},
						},
						shape = {
							type = "Box",
							size = {4, 12, 4},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {60, 60},
						speed = {4, 10},
						drag = 2,
						accel = {0, 2, 0},
						lifetime = {0.8, 1.2},
						size = {
							{0, 4, 1},
							{1, 11, 2},
						},
						transparency = {
							{0, 0.45, 0},
							{0.4, 0.6, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{160, 150, 136},
							},
							{
								0.5,
								{138, 128, 116},
							},
							{
								1,
								{112, 104, 94},
							},
						},
						rotation = {0, 360},
						rot_speed = {-30, 30},
						light_emission = 0,
						brightness = 1,
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
				},
			},
			{
				hold = {1, 1},
				sink = 0.4,
				name = "CrystalShards",
				count = 12,
				r = {0.0624, 0.13},
				hex = true,
				lean = "radial",
				wid = {1.8, 3},
				thick = {4, 8},
				len = {1.8, 3},
				tilt = {14, 40},
				yaw = 15,
				pitch = 8,
				show = 0.82,
				rise = 0.12,
				t = 0.54,
				sweep = 0.5769,
				delay = {0, 0.08},
				end_at = {9.3, 9.7},
				["end"] = "shatter",
				ice = {
					color = {94, 229, 224},
					material = "Neon",
					transparency = 0.15,
				},
				tip = 0.85,
				mesh = "CrystalShards",
				shatter = {
					{
						name = "ShardBurst",
						texture = "mf_shard_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 5},
						},
						shape = {
							type = "Box",
							size = {2, 6, 2},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {14, 38},
						drag = 0.5,
						accel = {0, -110, 0},
						lifetime = {0.6, 1.1},
						size = {
							{0, 1.8, 0.6},
							{1, 1.3, 0.4},
						},
						transparency = {
							{0, 0, 0},
							{0.85, 0.1, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{215, 255, 252},
							},
							{
								0.4,
								{94, 229, 224},
							},
							{
								1,
								{52, 147, 152},
							},
						},
						light_emission = 0.6,
						brightness = 1.5,
						rotation = {0, 360},
						rot_speed = {-500, 500},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardGlints",
						texture = "kk_star_09",
						emit = {
							{0, 2},
						},
						shape = {
							type = "Box",
							size = {2, 6, 2},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {3, 9},
						drag = 2,
						lifetime = {0.3, 0.55},
						size = {
							{0, 0, 0},
							{0.08, 4.48, 0},
							{0.22, 1.96, 0},
							{0.38, 4.76, 0},
							{0.55, 1.68, 0},
							{0.72, 3.92, 0},
							{1, 0, 0},
						},
						color = {
							{
								0,
								{255, 255, 255},
							},
							{
								0.5,
								{205, 255, 250},
							},
							{
								1,
								{120, 235, 228},
							},
						},
						light_emission = 1,
						brightness = 2,
						rotation = {0, 45},
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
						name = "ShardFire",
						texture = "fx_fire_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 2},
						},
						shape = {
							type = "Box",
							size = {2, 6, 2},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {40, 40},
						speed = {6, 14},
						drag = 1.5,
						accel = {0, 8, 0},
						lifetime = {0.35, 0.6},
						size = {
							{0, 3, 1},
							{0.3, 7, 1.5},
							{1, 2, 0},
						},
						transparency = {
							{0, 0.15, 0},
							{0.6, 0.42, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{175, 255, 250},
							},
							{
								0.3,
								{100, 236, 230},
							},
							{
								0.65,
								{60, 185, 186},
							},
							{
								1,
								{39, 121, 127},
							},
						},
						light_emission = 1,
						brightness = 1.45,
						rotation = {0, 360},
						rot_speed = {0, 0},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardDust",
						texture = "fx_smoke_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 2},
						},
						shape = {
							type = "Box",
							size = {2, 6, 2},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {60, 60},
						speed = {4, 10},
						drag = 2,
						accel = {0, 2, 0},
						lifetime = {0.8, 1.2},
						size = {
							{0, 4, 1},
							{1, 11, 2},
						},
						transparency = {
							{0, 0.45, 0},
							{0.4, 0.6, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{160, 150, 136},
							},
							{
								0.5,
								{138, 128, 116},
							},
							{
								1,
								{112, 104, 94},
							},
						},
						rotation = {0, 360},
						rot_speed = {-30, 30},
						light_emission = 0,
						brightness = 1,
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
				},
			},
			{
				hold = {1, 1},
				sink = 0.6,
				name = "SpireBlocks",
				count = 16,
				r = {0.052, 0.143},
				lean = "radial",
				wid = {2.8, 4.8},
				thick = {3, 6},
				len = {2.8, 4.8},
				tilt = {18, 42},
				yaw = 20,
				pitch = 12,
				show = 0.7,
				rise = 0.1,
				t = 0.46,
				sweep = 0.3846,
				delay = {0, 0.05},
				end_at = {10.2, 10.6},
				ground = true,
				mesh = "SpireBlocks",
			},
			{
				hold = {1, 1},
				sink = 0.5,
				name = "SpireSlabs",
				count = 48,
				r = {0.0416, 0.26},
				lean = "radial",
				wid = {3, 6},
				thick = {1.2, 2.4},
				len = {3, 6},
				tilt = {18, 46},
				yaw = 14,
				pitch = 10,
				show = 0.6,
				rise = 0.08,
				t = 0.44,
				sweep = 0.4615,
				delay = {0, 0.04},
				end_at = {10.3, 10.8},
				ground = true,
				mesh = "SpireSlabs",
			},
			{
				hold = {1.8, 2.8},
				sink = 0.55,
				name = "PathSlabs",
				count = 26,
				path = {
					u = {0.08, 0.9},
					t0 = 0.02,
					travel = 0.4,
					side = {1.4, 4.6},
				},
				r = {0, 0},
				t = 0.42,
				wid = {2.2, 4.2},
				thick = {1, 2.4},
				len = {2.2, 4.6},
				tilt = {26, 56},
				yaw = 22,
				pitch = 14,
				show = 0.62,
				rise = 0.09,
				delay = {0, 0.03},
				big = {
					frac = 0.3,
					k = 1.45,
				},
				ground = true,
				mesh = "PathSlabs",
			},
			{
				hold = {1.8, 2.8},
				sink = 0.6,
				name = "PathBlocks",
				count = 12,
				path = {
					u = {0.08, 0.9},
					t0 = 0.02,
					travel = 0.4,
					side = {2.2, 6.2},
				},
				r = {0, 0},
				t = 0.42,
				wid = {2.2, 4.4},
				thick = {2.2, 4.6},
				len = {2.2, 4.4},
				tilt = {14, 40},
				yaw = 30,
				pitch = 18,
				show = 0.64,
				rise = 0.1,
				delay = {0, 0.04},
				big = {
					frac = 0.25,
					k = 1.5,
				},
				ground = true,
				mesh = "PathBlocks",
			},
		},
	},
}

-- PEBLEDON SKILL 3 (Pilar de cristal): pisa fuerte y algo avanza bajo tierra hasta el punto elegido (se levantan losas y bloques por el camino); ahí el suelo revienta y brota duro un pilar de cristal como los de su espalda (unos 33 studs), con cristales más chicos, fuego cian y bloques de roca. Queda un círculo grande que marca la mejora y dura 10 s: al final avisa (titila y el círculo parpadea) y se desmorona hundiéndose (CrystalSpireTimes). El golpe al brotar llega a CrystalSpireHitRadius studs × escala; la mejora, a CrystalSpireRadius studs × escala.
-- foot = el pie que pisa (Vector3 o CFrame; llámalo cuando el pie toca el suelo). target = dónde brota
-- (Vector3 o CFrame, en el suelo). La grieta corre del pie hasta ahí y ahí brota todo.
function PebledonVFX.CrystalSpire(foot: any, target: any, scale: number?, shake: number?): Part
	return playStompZone(SPEC_CrystalSpire, foot, target, scale, shake)
end
-- segundos (desde la llamada) de cada momento: para sincronizar el daño, el sonido o la mejora
PebledonVFX.CrystalSpireTimes = {
	Stomp = 0,
	Erupt = 0.44,
	Crystal = 0.6,
	Warning = 8.8,
	End = 10,
}
-- radio alrededor del centro (studs a escala 1; multiplícalo por la escala): el círculo de la mejora (dentro, Pebledon y sus compañeros giran y corren más rápido)
PebledonVFX.CrystalSpireRadius = 100
-- hasta dónde golpea al brotar (studs a escala 1; multiplícalo por la escala): a quien esté ahí lo empuja y lo manda a volar (eso lo hace el servidor)
PebledonVFX.CrystalSpireHitRadius = 12

local SPEC_CrystalRay = {
	name = "CrystalRay",
	duration = 3.62,
	cleanup = 4.38,
	layers = {
		{
			name = "RSourceGlow",
			texture = "fx_glow",
			lifetime = {0.14, 0.2},
			size = {
				{0, 8, 1},
				{1, 10, 1},
			},
			transparency = {
				{0, 0.6, 0},
				{1, 0.85, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 2,
			stream = {
				{0, 3.38, 10, 10},
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
			name = "RSourceFire",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			spread = {35, 35},
			speed = {10, 24},
			drag = 4,
			accel = {0, 4, 0},
			lifetime = {0.16, 0.26},
			size = {
				{0, 1.4, 0.4},
				{0.4, 3.6, 0.8},
				{1, 2, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {0, 360},
			stream = {
				{0, 3.38, 26, 26},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "RFireJet",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			spread = {3, 3},
			speed_len = {6.25, 6.75},
			lifetime = {0.1472, 0.16},
			size = {
				{0, 1.6, 0.4},
				{0.5, 4, 1},
				{1, 5.5, 1.2},
			},
			transparency = {
				{0, 0.25, 0},
				{0.5, 0.35, 0},
				{0.85, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{170, 252, 250},
				},
				{
					0.3,
					{90, 225, 235},
				},
				{
					0.7,
					{45, 165, 210},
				},
				{
					1,
					{30, 110, 170},
				},
			},
			light_emission = 0.7,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-240, 240},
			locked = true,
			stream = {
				{0, 3.38, 90, 90},
			},
			speed = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "RImpactBurst",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 8},
			},
			on_hit = true,
			direction = "Back",
			spread = {80, 80},
			speed = {18, 40},
			drag = 3,
			accel = {0, 10, 0},
			lifetime = {0.3, 0.5},
			size = {
				{0, 2.4, 0.8},
				{0.3, 6, 1.4},
				{1, 2, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {0, 360},
			line_u = 1,
			offset = {0, 0, 2},
			impact = true,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
		},
		{
			name = "RImpactGlow",
			texture = "fx_glow",
			lifetime = {0.14, 0.2},
			size = {
				{0, 9, 1.5},
				{1, 11, 1.5},
			},
			transparency = {
				{0, 0.6, 0},
				{1, 0.85, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1,
			zoffset = 2,
			stream = {
				{0, 3.38, 12, 12},
			},
			line_u = 1,
			offset = {0, 0, 2},
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
			name = "RImpactFlames",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Back",
			spread = {75, 75},
			speed = {10, 24},
			drag = 2.5,
			accel = {0, 12, 0},
			lifetime = {0.25, 0.45},
			size = {
				{0, 2, 0.6},
				{0.3, 5, 1.2},
				{1, 1.2, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			stream = {
				{0, 3.38, 30, 30},
			},
			line_u = 1,
			offset = {0, 0, 2},
			impact = true,
			zoffset = 0,
			orientation = "FacingCamera",
			emit = {},
		},
		{
			name = "RImpactSparks",
			texture = "fx_spark002",
			direction = "Back",
			spread = {80, 80},
			speed = {16, 40},
			drag = 2,
			accel = {0, 8, 0},
			lifetime = {0.35, 0.7},
			size = {
				{0, 0, 0},
				{0.08, 1.44, 0},
				{0.22, 0.63, 0},
				{0.38, 1.53, 0},
				{0.55, 0.54, 0},
				{0.72, 1.26, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.9,
			rotation = {0, 45},
			stream = {
				{0, 3.38, 22, 22},
			},
			line_u = 1,
			offset = {0, 0, 2},
			impact = true,
			transparency = {
				{0, 0, 0},
				{1, 0, 0},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			emit = {},
		},
	},
	beam = {
		start = 0,
		grow = 0.1,
		stop = 3.4,
		fade = 0.22,
		max_len = 80,
		trail_every = 0.1,
		trail_move = 4,
		rehit = 0.3,
		light_color = {94, 229, 224},
		light_brightness = 2,
		light_range = 24,
	},
	refract = {
		name = "CrystalRefract",
		h = 20,
	},
	beams = {
		{
			name = "Glow",
			texture = "kz_beam_glow",
			mode = "Wrap",
			tex_len = 40,
			speed = 0.4,
			light_emission = 1,
			brightness = 0.85,
			color = {
				{
					0,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			transparency = {
				{0, 0.84},
				{0.03, 0.78},
				{1, 0.8},
			},
			width = 13,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.04, 1.4},
				{0.18, 1},
				{3.35, 1},
				{3.4, 0.75},
				{3.62, 0},
			},
			alpha_t = {
				{0, 0},
				{3.4, 0},
				{3.62, 1},
			},
			pulse = 0.06,
			pulse_hz = 5,
			zoffset = 0,
		},
		{
			name = "FireOuter",
			texture = "pb_breath_fire",
			mode = "Wrap",
			tex_len = 22,
			speed = 5,
			light_emission = 0.5,
			brightness = 1.4,
			color = {
				{
					0,
					{50, 185, 215},
				},
				{
					1,
					{35, 140, 185},
				},
			},
			transparency = {
				{0, 0.45},
				{0.04, 0.22},
				{1, 0.3},
			},
			width = 9,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.04, 1.4},
				{0.18, 1},
				{3.35, 1},
				{3.4, 0.75},
				{3.62, 0},
			},
			alpha_t = {
				{0, 0},
				{3.4, 0},
				{3.62, 1},
			},
			pulse = 0.08,
			pulse_hz = 9,
			zoffset = 0.1,
		},
		{
			name = "FireInner",
			texture = "pb_breath_fire",
			mode = "Wrap",
			tex_len = 14,
			speed = 7,
			light_emission = 1,
			brightness = 1.6,
			color = {
				{
					0,
					{120, 245, 240},
				},
				{
					1,
					{70, 210, 210},
				},
			},
			transparency = {
				{0, 0.35},
				{0.04, 0.1},
				{1, 0.15},
			},
			width = 4.8,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.04, 1.4},
				{0.18, 1},
				{3.35, 1},
				{3.4, 0.75},
				{3.62, 0},
			},
			alpha_t = {
				{0, 0},
				{3.4, 0},
				{3.62, 1},
			},
			pulse = 0.08,
			pulse_hz = 13,
			zoffset = 0.2,
		},
		{
			name = "Core",
			texture = "kz_beam_core",
			mode = "Wrap",
			tex_len = 12,
			speed = 3.5,
			light_emission = 1,
			brightness = 2.2,
			color = {
				{
					0,
					{240, 255, 254},
				},
				{
					1,
					{210, 255, 251},
				},
			},
			transparency = {
				{0, 0.2},
				{0.03, 0},
				{1, 0},
			},
			width = 1.9,
			w0 = 1,
			w1 = 1,
			width_t = {
				{0, 0},
				{0.04, 1.4},
				{0.18, 1},
				{3.35, 1},
				{3.4, 0.75},
				{3.62, 0},
			},
			alpha_t = {
				{0, 0},
				{3.4, 0},
				{3.62, 1},
			},
			pulse = 0.08,
			pulse_hz = 15,
			zoffset = 0.3,
		},
	},
}

-- PEBLEDON: un rayo de la refracción: fuego azul concentrado y delgado que sale del cristal hacia un enemigo (sin carga; dura hasta que lo cortan, como mucho 3.4 s). Normalmente lo usa CrystalRefract.
-- origin = de dónde sale: un Attachment en la boca (lo sigue solo), una Part, un Vector3 o un CFrame.
-- target = hacia dónde apunta: el rival (Model o Part: lo sigue solo) o un punto (Vector3 o CFrame).
-- ignore = lo que el rayo atraviesa (el modelo de quien lo lanza). Se corta en la primera superficie
-- que toca y nunca pasa de su largo máximo (80 studs × escala). Devuelve un control:
--   rayo:AimAt(objetivo)     apunta a otro lado (Model, Part, Vector3 o CFrame; si se mueve, lo sigue)
--   rayo:SetDirection(dir)   apunta en una dirección (Vector3)
--   rayo:SetOrigin(origen)   cambia de dónde sale
--   rayo:Stop()              lo corta antes de tiempo
--   rayo.MaxLength           largo máximo (lo puedes cambiar); rayo.Length = largo de ahora
--   rayo.HitPosition, rayo.HitInstance = dónde y qué está tocando (nil si no toca nada)
--   rayo.Active = true mientras se ve; rayo.Holder = la Part que lo contiene
function PebledonVFX.CrystalRay(origin: any, target: any, scale: number?, shake: number?, ignore: { Instance }?): BeamControl
	return playBeam(SPEC_CrystalRay, origin, target, scale, shake, ignore)
end
-- segundos (desde la llamada) en que llega a su largo máximo y en que se corta solo
PebledonVFX.CrystalRayStart = 0.1
PebledonVFX.CrystalRayStop = 3.4

-- CrystalRay repartido: un rayo desde crystal (lo que devolvió el efecto del cristal, una Part, un Model,
-- un Vector3 o un CFrame; salen de 20 studs × escala sobre él) hacia cada objetivo (Models, Parts o
-- Vector3: los siguen si se mueven). Devuelve un control:
--   r:SetTargets(lista)   cambia a quiénes (corta los que ya no están y abre los nuevos)
--   r:Stop()              los corta todos;  r.Active = true mientras dura;  r.Rays = el rayo de cada uno
function PebledonVFX.CrystalRefract(crystal: any, targets: { any }, scale: number?, shake: number?): RefractControl
	return playRefract(SPEC_CrystalRay, crystal, targets, scale, shake or 0)
end

local SPEC_TectonicEruption = {
	name = "TectonicEruption",
	duration = 6.65,
	cleanup = 9.47,
	layers = {
		{
			name = "SlamFlash",
			texture = "fx_glow",
			lifetime = {0.3, 0.3},
			size = {
				{0, 10, 0},
				{0.25, 75, 0},
				{1, 85, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.5, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			zoffset = 4,
			ring_emit = {
				{0.02, 1, 0, 0, 8},
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
			name = "SlamStar",
			texture = "kk_star_09",
			lifetime = {0.3, 0.3},
			size = {
				{0, 10, 0},
				{0.2, 95, 0},
				{1, 15, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			rotation = {0, 90},
			zoffset = 5,
			ring_emit = {
				{0.03, 1, 0, 0, 8},
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
			name = "SlamRing",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.55, 0.55},
			size = {
				{0, 20.34, 0},
				{1, 213.57, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 0.9,
			ring_emit = {
				{0.02, 1, 0, 0, 0.2},
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
			name = "SlamDust",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 10,
			spread = {12, 8},
			speed = {40, 70},
			drag = 2.5,
			accel = {0, 2, 0},
			lifetime = {1, 1.5},
			size = {
				{0, 8, 2},
				{1, 26, 4},
			},
			transparency = {
				{0, 0.35, 0},
				{0.35, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			ring_emit = {
				{0.03, 1, 0, 0.05, 4},
				{0.03, 1, 0.0417, 0.05, 4},
				{0.03, 1, 0.0833, 0.05, 4},
				{0.03, 1, 0.125, 0.05, 4},
				{0.03, 1, 0.1667, 0.05, 4},
				{0.03, 1, 0.2083, 0.05, 4},
				{0.03, 1, 0.25, 0.05, 4},
				{0.03, 1, 0.2917, 0.05, 4},
				{0.03, 1, 0.3333, 0.05, 4},
				{0.03, 1, 0.375, 0.05, 4},
				{0.03, 1, 0.4167, 0.05, 4},
				{0.03, 1, 0.4583, 0.05, 4},
				{0.03, 1, 0.5, 0.05, 4},
				{0.03, 1, 0.5417, 0.05, 4},
				{0.03, 1, 0.5833, 0.05, 4},
				{0.03, 1, 0.625, 0.05, 4},
				{0.03, 1, 0.6667, 0.05, 4},
				{0.03, 1, 0.7083, 0.05, 4},
				{0.03, 1, 0.75, 0.05, 4},
				{0.03, 1, 0.7917, 0.05, 4},
				{0.03, 1, 0.8333, 0.05, 4},
				{0.03, 1, 0.875, 0.05, 4},
				{0.03, 1, 0.9167, 0.05, 4},
				{0.03, 1, 0.9583, 0.05, 4},
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
			name = "SlamChips",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {55, 55},
			speed = {30, 60},
			drag = 0.4,
			accel = {0, -150, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 2, 0.7},
				{1, 1.6, 0.5},
			},
			color = {
				{
					0,
					{128, 118, 106},
				},
				{
					1,
					{100, 92, 82},
				},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			radial = false,
			ring_emit = {
				{0.02, 30, 0, 0, 1},
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
			name = "SlamCracks",
			texture = "pb_vein_cracks",
			lifetime = {6.29, 6.29},
			rotation = {0, 360},
			size = {
				{0, 10, 0},
				{0.01, 70, 0},
				{1, 72, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.005, 0.25, 0},
				{0.9, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 236, 232},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 0.9,
			ring_emit = {
				{0.03, 1, 0, 0, 0.24},
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
			name = "ZoneShade",
			texture = "fx_glow",
			rel = "r",
			lifetime = {6.29, 6.29},
			size = {
				{0, 75, 0},
				{0.1, 390, 0},
				{1, 405, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.42, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{8, 20, 22},
				},
				{
					1,
					{8, 20, 22},
				},
			},
			ring_emit = {
				{0.05, 1, 0, 0, 0.08},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "VeinsDark",
			texture = "pb_tectonic_veins",
			rel = "r",
			lifetime = {6.29, 6.29},
			rotation = {0, 0},
			size = {
				{0, 18.75, 0},
				{0.1494, 315.625, 0},
				{1, 315.625, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.005, 0.35, 0},
				{0.9, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{34, 30, 27},
				},
				{
					1,
					{40, 36, 32},
				},
			},
			ring_emit = {
				{0.06, 1, 0, 0, 0.18},
			},
			decal = true,
			orientation = "VelocityPerpendicular",
			direction = "Top",
			speed = {0.01, 0.01},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "Veins",
			texture = "pb_tectonic_veins",
			rel = "r",
			lifetime = {6.29, 6.29},
			rotation = {0, 0},
			size = {
				{0, 18.75, 0},
				{0.1494, 312.5, 0},
				{1, 312.5, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.005, 0.2, 0},
				{0.1653, 0.15, 0},
				{0.1892, 0, 0},
				{0.4277, 0.12, 0},
				{0.682, 0.05, 0},
				{0.7774, 0.4, 0},
				{0.92, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{170, 255, 250},
				},
				{
					1,
					{94, 229, 224},
				},
			},
			light_emission = 1,
			ring_emit = {
				{0.06, 1, 0, 0, 0.25},
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
			name = "VeinsFlash",
			texture = "pb_tectonic_veins",
			rel = "r",
			lifetime = {0.6, 0.6},
			rotation = {0, 0},
			size = {
				{0, 312.5, 0},
				{1, 318.75, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			ring_emit = {
				{1.15, 1, 0, 0, 0.3},
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
			name = "VeinsPulse",
			texture = "pb_tectonic_veins",
			rel = "r",
			lifetime = {0.35, 0.35},
			rotation = {0, 0},
			size = {
				{0, 312.5, 0},
				{1, 312.5, 0},
			},
			transparency = {
				{0, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			ring_emit = {
				{3.1, 1, 0, 0, 0.31},
				{3.4, 1, 0, 0, 0.31},
				{3.7, 1, 0, 0, 0.31},
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
			name = "CenterGlow",
			texture = "fx_glow",
			lifetime = {1.1, 1.1},
			size = {
				{0, 30, 0},
				{0.5, 70, 0},
				{1, 40, 0},
			},
			transparency = {
				{0, 0.6, 0},
				{0.5, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			ring_emit = {
				{0.05, 1, 0, 0, 0.3},
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
			name = "VeinFlames",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {12, 12},
			speed = {5, 12},
			accel = {0, 8, 0},
			lifetime = {0.4, 0.7},
			size = {
				{0, 2, 0.6},
				{0.3, 5.5, 1.2},
				{1, 1.5, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {-10, 10},
			radial = false,
			ring_emit = {
				{0.883, 1, 0.0139, 0.8318, 0.3},
				{0.736, 1, 0.0221, 0.5614, 0.3},
				{0.894, 1, 0.0332, 0.7124, 0.3},
				{0.929, 1, 0.039, 0.7509, 0.3},
				{0.902, 1, 0.0684, 0.7182, 0.3},
				{1.101, 1, 0.077, 0.9722, 0.3},
				{1.01, 1, 0.0783, 0.8946, 0.3},
				{0.692, 1, 0.0784, 0.6006, 0.3},
				{0.762, 1, 0.0817, 0.6067, 0.3},
				{0.767, 1, 0.0861, 0.5879, 0.3},
				{0.319, 1, 0.091, 0.142, 0.3},
				{0.758, 1, 0.0979, 0.5635, 0.3},
				{0.761, 1, 0.1148, 0.6505, 0.3},
				{0.996, 1, 0.1243, 0.821, 0.3},
				{0.661, 1, 0.1271, 0.5414, 0.3},
				{0.628, 1, 0.1284, 0.5347, 0.3},
				{0.958, 1, 0.1381, 0.8875, 0.3},
				{0.728, 1, 0.1451, 0.6508, 0.3},
				{0.943, 1, 0.1551, 0.8546, 0.3},
				{0.761, 1, 0.1593, 0.6167, 0.3},
				{0.78, 1, 0.1629, 0.6051, 0.3},
				{0.752, 1, 0.1704, 0.5562, 0.3},
				{1.111, 1, 0.1998, 0.9617, 0.3},
				{1.052, 1, 0.2009, 0.9653, 0.3},
				{0.474, 1, 0.2122, 0.3296, 0.3},
				{0.334, 1, 0.2185, 0.2262, 0.3},
				{1.07, 1, 0.2211, 0.9736, 0.3},
				{1.004, 1, 0.2239, 0.8455, 0.3},
				{0.844, 1, 0.2408, 0.7525, 0.3},
				{1.048, 1, 0.2502, 0.961, 0.3},
				{0.682, 1, 0.2599, 0.5548, 0.3},
				{0.286, 1, 0.2634, 0.1449, 0.3},
				{0.783, 1, 0.273, 0.6955, 0.3},
				{0.311, 1, 0.2731, 0.1542, 0.3},
				{0.932, 1, 0.2792, 0.8819, 0.3},
				{0.753, 1, 0.285, 0.5982, 0.3},
				{1.07, 1, 0.2856, 0.8884, 0.3},
				{0.861, 1, 0.2912, 0.67, 0.3},
				{0.697, 1, 0.3031, 0.5976, 0.3},
				{0.516, 1, 0.3076, 0.3716, 0.3},
				{0.844, 1, 0.3105, 0.7964, 0.3},
				{0.909, 1, 0.3166, 0.7379, 0.3},
				{0.376, 1, 0.3235, 0.1941, 0.3},
				{0.902, 1, 0.3339, 0.8055, 0.3},
				{0.757, 1, 0.3364, 0.638, 0.3},
				{0.717, 1, 0.3685, 0.5384, 0.3},
				{0.75, 1, 0.3756, 0.568, 0.3},
				{0.644, 1, 0.3807, 0.5859, 0.3},
				{0.913, 1, 0.3815, 0.8503, 0.3},
				{0.607, 1, 0.3829, 0.5033, 0.3},
				{0.659, 1, 0.3889, 0.59, 0.3},
				{0.871, 1, 0.3905, 0.6958, 0.3},
				{1.016, 1, 0.3999, 0.878, 0.3},
				{0.849, 1, 0.4049, 0.7769, 0.3},
				{0.863, 1, 0.4092, 0.708, 0.3},
				{0.991, 1, 0.4103, 0.8648, 0.3},
				{0.982, 1, 0.4161, 0.8777, 0.3},
				{0.559, 1, 0.4177, 0.4671, 0.3},
				{0.637, 1, 0.4279, 0.5745, 0.3},
				{1.002, 1, 0.4286, 0.8606, 0.3},
				{0.576, 1, 0.4332, 0.5151, 0.3},
				{0.831, 1, 0.4332, 0.7031, 0.3},
				{1.147, 1, 0.4375, 0.9671, 0.3},
				{0.428, 1, 0.442, 0.3534, 0.3},
				{0.734, 1, 0.4477, 0.6092, 0.3},
				{0.53, 1, 0.4498, 0.3992, 0.3},
				{0.906, 1, 0.4581, 0.7345, 0.3},
				{0.602, 1, 0.4746, 0.4706, 0.3},
				{0.928, 1, 0.4833, 0.751, 0.3},
				{0.758, 1, 0.4908, 0.6908, 0.3},
				{1.079, 1, 0.4922, 0.9298, 0.3},
				{0.653, 1, 0.4943, 0.5552, 0.3},
				{0.649, 1, 0.4988, 0.5315, 0.3},
				{0.505, 1, 0.5009, 0.3057, 0.3},
				{0.387, 1, 0.5029, 0.3015, 0.3},
				{0.998, 1, 0.5077, 0.9153, 0.3},
				{0.933, 1, 0.5111, 0.783, 0.3},
				{0.623, 1, 0.5162, 0.4629, 0.3},
				{0.637, 1, 0.5186, 0.4459, 0.3},
				{0.856, 1, 0.5223, 0.7513, 0.3},
				{0.871, 1, 0.5274, 0.7006, 0.3},
				{0.958, 1, 0.5413, 0.8443, 0.3},
				{0.873, 1, 0.5454, 0.7551, 0.3},
				{0.533, 1, 0.5472, 0.4227, 0.3},
				{1.033, 1, 0.5565, 0.9593, 0.3},
				{1.001, 1, 0.5596, 0.8429, 0.3},
				{0.77, 1, 0.5608, 0.6554, 0.3},
				{0.779, 1, 0.587, 0.7015, 0.3},
				{0.89, 1, 0.5929, 0.85, 0.3},
				{1.064, 1, 0.5941, 0.9717, 0.3},
				{0.683, 1, 0.6016, 0.6009, 0.3},
				{0.815, 1, 0.6019, 0.6768, 0.3},
				{0.824, 1, 0.6033, 0.7499, 0.3},
				{0.98, 1, 0.6069, 0.896, 0.3},
				{0.992, 1, 0.6263, 0.8728, 0.3},
				{1.03, 1, 0.6334, 0.9573, 0.3},
				{1.045, 1, 0.6339, 0.9461, 0.3},
				{0.869, 1, 0.6341, 0.7595, 0.3},
				{0.798, 1, 0.6398, 0.6952, 0.3},
				{0.981, 1, 0.6512, 0.8632, 0.3},
				{1.043, 1, 0.6672, 0.9274, 0.3},
				{1.002, 1, 0.6716, 0.8546, 0.3},
				{0.953, 1, 0.6749, 0.7728, 0.3},
				{1.079, 1, 0.6911, 0.9539, 0.3},
				{0.724, 1, 0.699, 0.6698, 0.3},
				{0.863, 1, 0.7012, 0.8051, 0.3},
				{0.94, 1, 0.704, 0.7942, 0.3},
				{0.38, 1, 0.7042, 0.259, 0.3},
				{0.934, 1, 0.7161, 0.8335, 0.3},
				{1.043, 1, 0.7182, 0.8855, 0.3},
				{0.963, 1, 0.7225, 0.8312, 0.3},
				{0.833, 1, 0.7234, 0.7249, 0.3},
				{0.465, 1, 0.7308, 0.3662, 0.3},
				{0.688, 1, 0.7315, 0.5673, 0.3},
				{1.082, 1, 0.7519, 0.9769, 0.3},
				{0.8, 1, 0.7525, 0.6473, 0.3},
				{0.553, 1, 0.7673, 0.4842, 0.3},
				{0.559, 1, 0.7699, 0.3858, 0.3},
				{0.931, 1, 0.77, 0.8536, 0.3},
				{0.916, 1, 0.7819, 0.8571, 0.3},
				{0.702, 1, 0.782, 0.5614, 0.3},
				{0.877, 1, 0.788, 0.6926, 0.3},
				{0.362, 1, 0.8, 0.1468, 0.3},
				{1.049, 1, 0.8106, 0.9062, 0.3},
				{1.005, 1, 0.8168, 0.9554, 0.3},
				{0.299, 1, 0.8369, 0.0789, 0.3},
				{1.102, 1, 0.8409, 0.9642, 0.3},
				{1.037, 1, 0.8439, 0.9146, 0.3},
				{0.975, 1, 0.8565, 0.8076, 0.3},
				{0.796, 1, 0.8576, 0.6781, 0.3},
				{0.853, 1, 0.8577, 0.795, 0.3},
				{1.048, 1, 0.8599, 0.9474, 0.3},
				{0.514, 1, 0.8609, 0.4406, 0.3},
				{0.826, 1, 0.8649, 0.7622, 0.3},
				{0.432, 1, 0.8691, 0.2965, 0.3},
				{0.787, 1, 0.8803, 0.7304, 0.3},
				{1.123, 1, 0.8835, 0.9454, 0.3},
				{0.982, 1, 0.8847, 0.9348, 0.3},
				{0.855, 1, 0.8994, 0.6999, 0.3},
				{0.763, 1, 0.9128, 0.7017, 0.3},
				{0.698, 1, 0.9276, 0.61, 0.3},
				{0.454, 1, 0.9285, 0.3314, 0.3},
				{0.906, 1, 0.9323, 0.8362, 0.3},
				{0.572, 1, 0.9465, 0.3781, 0.3},
				{1.097, 1, 0.9534, 0.9731, 0.3},
				{0.633, 1, 0.9666, 0.5419, 0.3},
				{1.046, 1, 0.9687, 0.9336, 0.3},
				{0.303, 1, 0.9911, 0.1611, 0.3},
				{0.826, 1, 0.9922, 0.6758, 0.3},
				{0.917, 1, 0.9945, 0.8111, 0.3},
			},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ChargeSparks",
			texture = "fx_spark002",
			direction = "Top",
			spread = {20, 20},
			speed = {8, 20},
			drag = 1,
			accel = {0, 4, 0},
			lifetime = {0.8, 1.4},
			size = {
				{0, 0, 0},
				{0.08, 1.76, 0},
				{0.22, 0.77, 0},
				{0.38, 1.87, 0},
				{0.55, 0.66, 0},
				{0.72, 1.54, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.9,
			rotation = {0, 45},
			radial = false,
			ring_emit = {
				{0.123, 1, 0.0729, 0.9063, 2.45},
				{0.124, 1, 0.7318, 0.583, 2.11},
				{0.132, 1, 0.1129, 0.9604, 2.549},
				{0.132, 1, 0.2737, 0.5362, 2.324},
				{0.142, 1, 0.4988, 0.0721, 2.279},
				{0.152, 1, 0.5668, 0.9698, 0.744},
				{0.161, 1, 0.8257, 0.8816, 1.695},
				{0.17, 1, 0.7544, 0.753, 1.053},
				{0.172, 1, 0.0636, 0.3451, 2.014},
				{0.174, 1, 0.1295, 0.9617, 1.171},
				{0.182, 1, 0.8624, 0.2544, 2.311},
				{0.198, 1, 0.796, 0.6917, 2.209},
				{0.207, 1, 0.5861, 0.2019, 2.934},
				{0.208, 1, 0.2318, 0.7079, 0.686},
				{0.211, 1, 0.1357, 0.5642, 1.021},
				{0.224, 1, 0.6357, 0.9269, 0.695},
				{0.225, 1, 0.8769, 0.7387, 1.035},
				{0.233, 1, 0.6422, 0.9957, 1.316},
				{0.236, 1, 0.5583, 0.8928, 2.764},
				{0.247, 1, 0.5157, 0.9836, 0.85},
				{0.251, 1, 0.1278, 0.852, 2.064},
				{0.276, 1, 0.9311, 0.3076, 2.662},
				{0.277, 1, 0.9388, 0.5806, 2.272},
				{0.28, 1, 0.4329, 0.6519, 2.319},
				{0.286, 1, 0.5865, 0.414, 1.572},
				{0.291, 1, 0.5705, 0.7194, 2.716},
				{0.308, 1, 0.7623, 0.8878, 1.633},
				{0.32, 1, 0.7936, 0.6749, 1.123},
				{0.331, 1, 0.593, 0.6693, 0.707},
				{0.342, 1, 0.5069, 0.765, 1.047},
				{0.344, 1, 0.7415, 0.8528, 2.927},
				{0.361, 1, 0.8821, 0.5459, 2.88},
				{0.363, 1, 0.5035, 0.474, 2.143},
				{0.368, 1, 0.6835, 0.2661, 1.759},
				{0.392, 1, 0.0965, 0.7011, 2.455},
				{0.396, 1, 0.8822, 0.8364, 2.316},
				{0.409, 1, 0.2441, 0.366, 1.711},
				{0.415, 1, 0.9118, 0.9551, 2.106},
				{0.417, 1, 0.4461, 0.9505, 2.95},
				{0.418, 1, 0.7462, 0.6642, 2.96},
				{0.421, 1, 0.4923, 0.6584, 2.829},
				{0.424, 1, 0.4316, 0.427, 1.054},
				{0.427, 1, 0.0557, 0.7042, 1.687},
				{0.43, 1, 0.1601, 0.4622, 1.896},
				{0.43, 1, 0.2375, 0.8235, 0.962},
				{0.432, 1, 0.0484, 0.9889, 2.403},
				{0.435, 1, 0.0136, 0.6292, 1.46},
				{0.44, 1, 0.8327, 0.7377, 1.699},
				{0.455, 1, 0.6293, 0.9773, 1.159},
				{0.475, 1, 0.3236, 0.4065, 2.383},
				{0.488, 1, 0.6298, 0.822, 2.998},
				{0.495, 1, 0.8468, 0.6923, 1.674},
				{0.508, 1, 0.6041, 0.7166, 2.036},
				{0.521, 1, 0.5421, 0.904, 1.348},
				{0.522, 1, 0.5438, 0.5821, 2.452},
				{0.529, 1, 0.6388, 0.8133, 0.529},
				{0.537, 1, 0.8528, 0.5164, 2.533},
				{0.54, 1, 0.2271, 0.9046, 1.785},
				{0.541, 1, 0.6101, 0.8293, 1.205},
				{0.545, 1, 0.9826, 0.5774, 2.855},
				{0.547, 1, 0.215, 0.3548, 1.76},
				{0.547, 1, 0.6558, 0.949, 2.09},
				{0.551, 1, 0.0641, 0.7342, 1.973},
				{0.553, 1, 0.8765, 0.7581, 2.311},
				{0.557, 1, 0.0221, 0.1903, 2.735},
				{0.568, 1, 0.0851, 0.5137, 2.435},
				{0.577, 1, 0.0102, 0.9651, 1.473},
				{0.591, 1, 0.618, 0.8893, 2.178},
				{0.594, 1, 0.0845, 0.6796, 1.062},
				{0.606, 1, 0.731, 0.5146, 1.305},
				{0.607, 1, 0.6897, 0.891, 2.325},
				{0.63, 1, 0.1436, 0.9114, 2.488},
				{0.64, 1, 0.3893, 0.6296, 2.651},
				{0.645, 1, 0.228, 0.6745, 0.951},
				{0.65, 1, 0.721, 0.8739, 1.709},
				{0.69, 1, 0.7428, 0.8208, 1.087},
				{0.696, 1, 0.7515, 0.3379, 2.284},
				{0.696, 1, 0.9049, 0.642, 2.768},
				{0.702, 1, 0.1075, 0.866, 2.471},
				{0.709, 1, 0.103, 0.4148, 1.118},
				{0.737, 1, 0.367, 0.4721, 0.709},
				{0.741, 1, 0.9781, 0.306, 0.554},
				{0.755, 1, 0.537, 0.9803, 0.844},
				{0.761, 1, 0.1318, 0.2349, 1.331},
				{0.77, 1, 0.4127, 0.8093, 0.528},
				{0.773, 1, 0.4459, 0.8503, 1.749},
				{0.782, 1, 0.0514, 0.7055, 2.976},
				{0.794, 1, 0.0725, 0.5778, 2.887},
				{0.81, 1, 0.4753, 0.964, 2.803},
				{0.814, 1, 0.0797, 0.9893, 2.637},
				{0.815, 1, 0.4367, 0.68, 1.717},
				{0.822, 1, 0.2237, 0.8205, 2.652},
				{0.837, 1, 0.6322, 0.7198, 0.682},
				{0.848, 1, 0.9878, 0.5553, 1.149},
				{0.879, 1, 0.3531, 0.7963, 0.63},
				{0.895, 1, 0.47, 0.2494, 0.906},
				{0.915, 1, 0.5517, 0.765, 2.009},
				{0.95, 1, 0.1754, 0.5459, 1.927},
				{0.962, 1, 0.7423, 0.8188, 2.698},
				{0.968, 1, 0.7336, 0.8337, 0.952},
				{0.973, 1, 0.2985, 0.2072, 2.471},
				{0.976, 1, 0.2098, 0.9926, 2.415},
				{0.99, 1, 0.3851, 0.912, 1.74},
				{0.993, 1, 0.91, 0.8159, 2.949},
				{1.017, 1, 0.1713, 0.9931, 1.876},
				{1.03, 1, 0.0398, 0.597, 2.611},
				{1.031, 1, 0.4563, 0.9183, 2.523},
				{1.043, 1, 0.8917, 0.7326, 1.384},
				{1.048, 1, 0.9927, 0.6376, 2.559},
				{1.081, 1, 0.1854, 0.8766, 0.764},
				{1.082, 1, 0.4728, 0.8258, 2.464},
				{1.092, 1, 0.8276, 0.8742, 0.909},
				{1.094, 1, 0.2011, 0.6524, 2.078},
				{1.106, 1, 0.3366, 0.7197, 1.146},
				{1.116, 1, 0.839, 0.2744, 1.156},
				{1.117, 1, 0.1122, 0.7974, 1.224},
				{1.126, 1, 0.7368, 0.5665, 2.665},
				{1.13, 1, 0.7847, 0.8213, 2.526},
				{1.139, 1, 0.0491, 0.3626, 0.981},
				{1.144, 1, 0.8976, 0.8731, 2.9},
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
			name = "ChargeDust",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {40, 40},
			speed = {2, 6},
			drag = 1,
			lifetime = {1, 1.4},
			size = {
				{0, 6, 1},
				{1, 14, 2},
			},
			transparency = {
				{0, 0.55, 0},
				{0.4, 0.68, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			radial = false,
			ring_emit = {
				{0.232, 1, 0.8211, 0.8685, 5},
				{0.242, 1, 0.02, 0.4042, 5},
				{0.258, 1, 0.7197, 0.8474, 5},
				{0.276, 1, 0.7096, 0.5556, 5},
				{0.295, 1, 0.6328, 0.7634, 5},
				{0.298, 1, 0.9726, 0.1327, 5},
				{0.324, 1, 0.8134, 0.9636, 5},
				{0.332, 1, 0.0332, 0.6144, 5},
				{0.333, 1, 0.6637, 0.6131, 5},
				{0.35, 1, 0.9091, 0.9291, 5},
				{0.385, 1, 0.5324, 0.5305, 5},
				{0.434, 1, 0.1834, 0.8303, 5},
				{0.445, 1, 0.5387, 0.606, 5},
				{0.456, 1, 0.3423, 0.84, 5},
				{0.458, 1, 0.5275, 0.967, 5},
				{0.468, 1, 0.6374, 0.5607, 5},
				{0.485, 1, 0.9904, 0.9732, 5},
				{0.492, 1, 0.8788, 0.7477, 5},
				{0.539, 1, 0.3773, 0.9224, 5},
				{0.546, 1, 0.8929, 0.9282, 5},
				{0.556, 1, 0.993, 0.438, 5},
				{0.585, 1, 0.6845, 0.2438, 5},
				{0.598, 1, 0.7722, 0.2464, 5},
				{0.624, 1, 0.3422, 0.8656, 5},
				{0.669, 1, 0.3343, 0.2671, 5},
				{0.699, 1, 0.1229, 0.2483, 5},
				{0.706, 1, 0.1725, 0.2442, 5},
				{0.718, 1, 0.4733, 0.5217, 5},
				{0.747, 1, 0.1859, 0.9077, 5},
				{0.812, 1, 0.2643, 0.3913, 5},
				{0.832, 1, 0.389, 0.8067, 5},
				{0.85, 1, 0.0583, 0.4409, 5},
				{0.888, 1, 0.6734, 0.6278, 5},
				{0.967, 1, 0.1349, 0.9529, 5},
				{0.978, 1, 0.8705, 0.7506, 5},
				{1.01, 1, 0.2088, 0.6823, 5},
				{1.021, 1, 0.7283, 0.8785, 5},
				{1.064, 1, 0.8881, 0.8038, 5},
				{1.082, 1, 0.2812, 0.6268, 5},
				{1.119, 1, 0.1237, 0.9407, 5},
			},
			accel = {0, 0, 0},
			light_emission = 0,
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "RuptureFlash",
			texture = "fx_glow",
			lifetime = {0.3, 0.3},
			size = {
				{0, 40, 0},
				{0.2, 225, 0},
				{1, 240, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{0.4, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			brightness = 1.2,
			zoffset = 4,
			ring_emit = {
				{1.15, 1, 0, 0, 12},
			},
			bill = true,
			rel = "r",
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "RuptureRing",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.95, 0.95},
			size = {
				{0, 20.34, 0},
				{0.8421, 508.5, 0},
				{1, 533.925, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.8, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			ring_emit = {
				{1.15, 1, 0, 0, 0.21},
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
			name = "RuptureRingSharp",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.9, 0.9},
			size = {
				{0, 20.34, 0},
				{0.8889, 508.5, 0},
				{1, 523.755, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			ring_emit = {
				{1.15, 1, 0, 0, 0.22},
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
			name = "GeyserJet",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {5, 5},
			speed = {100, 150},
			drag = 1.6,
			accel = {0, 10, 0},
			lifetime = {0.55, 0.8},
			size = {
				{0, 6, 1.5},
				{0.3, 9, 2},
				{1, 3, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.7, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			radial = false,
			ring_emit = {
				{1.315, 2, 0.6321, 0.1735, 0.5},
				{1.375, 2, 0.6321, 0.1735, 0.5},
				{1.435, 2, 0.6321, 0.1735, 0.5},
				{1.495, 2, 0.6321, 0.1735, 0.5},
				{1.575, 2, 0.6321, 0.1735, 0.5},
				{1.655, 2, 0.6321, 0.1735, 0.5},
				{1.735, 2, 0.6321, 0.1735, 0.5},
				{1.357, 2, 0.3013, 0.2467, 0.5},
				{1.417, 2, 0.3013, 0.2467, 0.5},
				{1.477, 2, 0.3013, 0.2467, 0.5},
				{1.537, 2, 0.3013, 0.2467, 0.5},
				{1.617, 2, 0.3013, 0.2467, 0.5},
				{1.697, 2, 0.3013, 0.2467, 0.5},
				{1.777, 2, 0.3013, 0.2467, 0.5},
				{1.361, 2, 0.4909, 0.245, 0.5},
				{1.421, 2, 0.4909, 0.245, 0.5},
				{1.481, 2, 0.4909, 0.245, 0.5},
				{1.541, 2, 0.4909, 0.245, 0.5},
				{1.621, 2, 0.4909, 0.245, 0.5},
				{1.701, 2, 0.4909, 0.245, 0.5},
				{1.781, 2, 0.4909, 0.245, 0.5},
				{1.37, 2, 0.7035, 0.255, 0.5},
				{1.43, 2, 0.7035, 0.255, 0.5},
				{1.49, 2, 0.7035, 0.255, 0.5},
				{1.55, 2, 0.7035, 0.255, 0.5},
				{1.63, 2, 0.7035, 0.255, 0.5},
				{1.71, 2, 0.7035, 0.255, 0.5},
				{1.79, 2, 0.7035, 0.255, 0.5},
				{1.373, 2, 0.9526, 0.2118, 0.5},
				{1.433, 2, 0.9526, 0.2118, 0.5},
				{1.493, 2, 0.9526, 0.2118, 0.5},
				{1.553, 2, 0.9526, 0.2118, 0.5},
				{1.633, 2, 0.9526, 0.2118, 0.5},
				{1.713, 2, 0.9526, 0.2118, 0.5},
				{1.793, 2, 0.9526, 0.2118, 0.5},
				{1.384, 2, 0.316, 0.2645, 0.5},
				{1.444, 2, 0.316, 0.2645, 0.5},
				{1.504, 2, 0.316, 0.2645, 0.5},
				{1.564, 2, 0.316, 0.2645, 0.5},
				{1.644, 2, 0.316, 0.2645, 0.5},
				{1.724, 2, 0.316, 0.2645, 0.5},
				{1.804, 2, 0.316, 0.2645, 0.5},
				{1.478, 2, 0.5882, 0.3432, 0.5},
				{1.538, 2, 0.5882, 0.3432, 0.5},
				{1.598, 2, 0.5882, 0.3432, 0.5},
				{1.658, 2, 0.5882, 0.3432, 0.5},
				{1.738, 2, 0.5882, 0.3432, 0.5},
				{1.818, 2, 0.5882, 0.3432, 0.5},
				{1.898, 2, 0.5882, 0.3432, 0.5},
				{1.514, 2, 0.8186, 0.4314, 0.5},
				{1.574, 2, 0.8186, 0.4314, 0.5},
				{1.634, 2, 0.8186, 0.4314, 0.5},
				{1.694, 2, 0.8186, 0.4314, 0.5},
				{1.774, 2, 0.8186, 0.4314, 0.5},
				{1.854, 2, 0.8186, 0.4314, 0.5},
				{1.934, 2, 0.8186, 0.4314, 0.5},
				{1.517, 2, 0.4217, 0.4375, 0.5},
				{1.577, 2, 0.4217, 0.4375, 0.5},
				{1.637, 2, 0.4217, 0.4375, 0.5},
				{1.697, 2, 0.4217, 0.4375, 0.5},
				{1.777, 2, 0.4217, 0.4375, 0.5},
				{1.857, 2, 0.4217, 0.4375, 0.5},
				{1.937, 2, 0.4217, 0.4375, 0.5},
				{1.522, 2, 0.0199, 0.4065, 0.5},
				{1.582, 2, 0.0199, 0.4065, 0.5},
				{1.642, 2, 0.0199, 0.4065, 0.5},
				{1.702, 2, 0.0199, 0.4065, 0.5},
				{1.782, 2, 0.0199, 0.4065, 0.5},
				{1.862, 2, 0.0199, 0.4065, 0.5},
				{1.942, 2, 0.0199, 0.4065, 0.5},
				{1.524, 2, 0.093, 0.405, 0.5},
				{1.584, 2, 0.093, 0.405, 0.5},
				{1.644, 2, 0.093, 0.405, 0.5},
				{1.704, 2, 0.093, 0.405, 0.5},
				{1.784, 2, 0.093, 0.405, 0.5},
				{1.864, 2, 0.093, 0.405, 0.5},
				{1.944, 2, 0.093, 0.405, 0.5},
				{1.549, 2, 0.3172, 0.4284, 0.5},
				{1.609, 2, 0.3172, 0.4284, 0.5},
				{1.669, 2, 0.3172, 0.4284, 0.5},
				{1.729, 2, 0.3172, 0.4284, 0.5},
				{1.809, 2, 0.3172, 0.4284, 0.5},
				{1.889, 2, 0.3172, 0.4284, 0.5},
				{1.969, 2, 0.3172, 0.4284, 0.5},
				{1.559, 2, 0.6554, 0.479, 0.5},
				{1.619, 2, 0.6554, 0.479, 0.5},
				{1.679, 2, 0.6554, 0.479, 0.5},
				{1.739, 2, 0.6554, 0.479, 0.5},
				{1.819, 2, 0.6554, 0.479, 0.5},
				{1.899, 2, 0.6554, 0.479, 0.5},
				{1.979, 2, 0.6554, 0.479, 0.5},
				{1.568, 2, 0.1583, 0.4987, 0.5},
				{1.628, 2, 0.1583, 0.4987, 0.5},
				{1.688, 2, 0.1583, 0.4987, 0.5},
				{1.748, 2, 0.1583, 0.4987, 0.5},
				{1.828, 2, 0.1583, 0.4987, 0.5},
				{1.908, 2, 0.1583, 0.4987, 0.5},
				{1.988, 2, 0.1583, 0.4987, 0.5},
				{1.569, 2, 0.8407, 0.4784, 0.5},
				{1.629, 2, 0.8407, 0.4784, 0.5},
				{1.689, 2, 0.8407, 0.4784, 0.5},
				{1.749, 2, 0.8407, 0.4784, 0.5},
				{1.829, 2, 0.8407, 0.4784, 0.5},
				{1.909, 2, 0.8407, 0.4784, 0.5},
				{1.989, 2, 0.8407, 0.4784, 0.5},
				{1.582, 2, 0.1535, 0.5242, 0.5},
				{1.642, 2, 0.1535, 0.5242, 0.5},
				{1.702, 2, 0.1535, 0.5242, 0.5},
				{1.762, 2, 0.1535, 0.5242, 0.5},
				{1.842, 2, 0.1535, 0.5242, 0.5},
				{1.922, 2, 0.1535, 0.5242, 0.5},
				{2.002, 2, 0.1535, 0.5242, 0.5},
				{1.586, 2, 0.9307, 0.5284, 0.5},
				{1.646, 2, 0.9307, 0.5284, 0.5},
				{1.706, 2, 0.9307, 0.5284, 0.5},
				{1.766, 2, 0.9307, 0.5284, 0.5},
				{1.846, 2, 0.9307, 0.5284, 0.5},
				{1.926, 2, 0.9307, 0.5284, 0.5},
				{2.006, 2, 0.9307, 0.5284, 0.5},
				{1.598, 2, 0.2695, 0.494, 0.5},
				{1.658, 2, 0.2695, 0.494, 0.5},
				{1.718, 2, 0.2695, 0.494, 0.5},
				{1.778, 2, 0.2695, 0.494, 0.5},
				{1.858, 2, 0.2695, 0.494, 0.5},
				{1.938, 2, 0.2695, 0.494, 0.5},
				{2.018, 2, 0.2695, 0.494, 0.5},
				{1.609, 2, 0.9107, 0.5561, 0.5},
				{1.669, 2, 0.9107, 0.5561, 0.5},
				{1.729, 2, 0.9107, 0.5561, 0.5},
				{1.789, 2, 0.9107, 0.5561, 0.5},
				{1.869, 2, 0.9107, 0.5561, 0.5},
				{1.949, 2, 0.9107, 0.5561, 0.5},
				{2.029, 2, 0.9107, 0.5561, 0.5},
				{1.612, 2, 0.9856, 0.553, 0.5},
				{1.672, 2, 0.9856, 0.553, 0.5},
				{1.732, 2, 0.9856, 0.553, 0.5},
				{1.792, 2, 0.9856, 0.553, 0.5},
				{1.872, 2, 0.9856, 0.553, 0.5},
				{1.952, 2, 0.9856, 0.553, 0.5},
				{2.032, 2, 0.9856, 0.553, 0.5},
				{1.634, 2, 0.6498, 0.6019, 0.5},
				{1.694, 2, 0.6498, 0.6019, 0.5},
				{1.754, 2, 0.6498, 0.6019, 0.5},
				{1.814, 2, 0.6498, 0.6019, 0.5},
				{1.894, 2, 0.6498, 0.6019, 0.5},
				{1.974, 2, 0.6498, 0.6019, 0.5},
				{2.054, 2, 0.6498, 0.6019, 0.5},
				{1.657, 2, 0.4452, 0.5825, 0.5},
				{1.717, 2, 0.4452, 0.5825, 0.5},
				{1.777, 2, 0.4452, 0.5825, 0.5},
				{1.837, 2, 0.4452, 0.5825, 0.5},
				{1.917, 2, 0.4452, 0.5825, 0.5},
				{1.997, 2, 0.4452, 0.5825, 0.5},
				{2.077, 2, 0.4452, 0.5825, 0.5},
				{1.712, 2, 0.4631, 0.6579, 0.5},
				{1.772, 2, 0.4631, 0.6579, 0.5},
				{1.832, 2, 0.4631, 0.6579, 0.5},
				{1.892, 2, 0.4631, 0.6579, 0.5},
				{1.972, 2, 0.4631, 0.6579, 0.5},
				{2.052, 2, 0.4631, 0.6579, 0.5},
				{2.132, 2, 0.4631, 0.6579, 0.5},
				{1.719, 2, 0.2724, 0.64, 0.5},
				{1.779, 2, 0.2724, 0.64, 0.5},
				{1.839, 2, 0.2724, 0.64, 0.5},
				{1.899, 2, 0.2724, 0.64, 0.5},
				{1.979, 2, 0.2724, 0.64, 0.5},
				{2.059, 2, 0.2724, 0.64, 0.5},
				{2.139, 2, 0.2724, 0.64, 0.5},
				{1.722, 2, 0.7521, 0.6503, 0.5},
				{1.782, 2, 0.7521, 0.6503, 0.5},
				{1.842, 2, 0.7521, 0.6503, 0.5},
				{1.902, 2, 0.7521, 0.6503, 0.5},
				{1.982, 2, 0.7521, 0.6503, 0.5},
				{2.062, 2, 0.7521, 0.6503, 0.5},
				{2.142, 2, 0.7521, 0.6503, 0.5},
				{1.733, 2, 0.5963, 0.6582, 0.5},
				{1.793, 2, 0.5963, 0.6582, 0.5},
				{1.853, 2, 0.5963, 0.6582, 0.5},
				{1.913, 2, 0.5963, 0.6582, 0.5},
				{1.993, 2, 0.5963, 0.6582, 0.5},
				{2.073, 2, 0.5963, 0.6582, 0.5},
				{2.153, 2, 0.5963, 0.6582, 0.5},
				{1.751, 2, 0.0887, 0.6869, 0.5},
				{1.811, 2, 0.0887, 0.6869, 0.5},
				{1.871, 2, 0.0887, 0.6869, 0.5},
				{1.931, 2, 0.0887, 0.6869, 0.5},
				{2.011, 2, 0.0887, 0.6869, 0.5},
				{2.091, 2, 0.0887, 0.6869, 0.5},
				{2.171, 2, 0.0887, 0.6869, 0.5},
				{1.761, 2, 0.7925, 0.741, 0.5},
				{1.821, 2, 0.7925, 0.741, 0.5},
				{1.881, 2, 0.7925, 0.741, 0.5},
				{1.941, 2, 0.7925, 0.741, 0.5},
				{2.021, 2, 0.7925, 0.741, 0.5},
				{2.101, 2, 0.7925, 0.741, 0.5},
				{2.181, 2, 0.7925, 0.741, 0.5},
				{1.763, 2, 0.1437, 0.7109, 0.5},
				{1.823, 2, 0.1437, 0.7109, 0.5},
				{1.883, 2, 0.1437, 0.7109, 0.5},
				{1.943, 2, 0.1437, 0.7109, 0.5},
				{2.023, 2, 0.1437, 0.7109, 0.5},
				{2.103, 2, 0.1437, 0.7109, 0.5},
				{2.183, 2, 0.1437, 0.7109, 0.5},
				{1.763, 2, 0.9887, 0.6947, 0.5},
				{1.823, 2, 0.9887, 0.6947, 0.5},
				{1.883, 2, 0.9887, 0.6947, 0.5},
				{1.943, 2, 0.9887, 0.6947, 0.5},
				{2.023, 2, 0.9887, 0.6947, 0.5},
				{2.103, 2, 0.9887, 0.6947, 0.5},
				{2.183, 2, 0.9887, 0.6947, 0.5},
				{1.77, 2, 0.0517, 0.7043, 0.5},
				{1.83, 2, 0.0517, 0.7043, 0.5},
				{1.89, 2, 0.0517, 0.7043, 0.5},
				{1.95, 2, 0.0517, 0.7043, 0.5},
				{2.03, 2, 0.0517, 0.7043, 0.5},
				{2.11, 2, 0.0517, 0.7043, 0.5},
				{2.19, 2, 0.0517, 0.7043, 0.5},
				{1.783, 2, 0.8816, 0.7223, 0.5},
				{1.843, 2, 0.8816, 0.7223, 0.5},
				{1.903, 2, 0.8816, 0.7223, 0.5},
				{1.963, 2, 0.8816, 0.7223, 0.5},
				{2.043, 2, 0.8816, 0.7223, 0.5},
				{2.123, 2, 0.8816, 0.7223, 0.5},
				{2.203, 2, 0.8816, 0.7223, 0.5},
				{1.79, 2, 0.4579, 0.7892, 0.5},
				{1.85, 2, 0.4579, 0.7892, 0.5},
				{1.91, 2, 0.4579, 0.7892, 0.5},
				{1.97, 2, 0.4579, 0.7892, 0.5},
				{2.05, 2, 0.4579, 0.7892, 0.5},
				{2.13, 2, 0.4579, 0.7892, 0.5},
				{2.21, 2, 0.4579, 0.7892, 0.5},
				{1.795, 2, 0.0684, 0.7635, 0.5},
				{1.855, 2, 0.0684, 0.7635, 0.5},
				{1.915, 2, 0.0684, 0.7635, 0.5},
				{1.975, 2, 0.0684, 0.7635, 0.5},
				{2.055, 2, 0.0684, 0.7635, 0.5},
				{2.135, 2, 0.0684, 0.7635, 0.5},
				{2.215, 2, 0.0684, 0.7635, 0.5},
				{1.796, 2, 0.4456, 0.7639, 0.5},
				{1.856, 2, 0.4456, 0.7639, 0.5},
				{1.916, 2, 0.4456, 0.7639, 0.5},
				{1.976, 2, 0.4456, 0.7639, 0.5},
				{2.056, 2, 0.4456, 0.7639, 0.5},
				{2.136, 2, 0.4456, 0.7639, 0.5},
				{2.216, 2, 0.4456, 0.7639, 0.5},
				{1.806, 2, 0.714, 0.7821, 0.5},
				{1.866, 2, 0.714, 0.7821, 0.5},
				{1.926, 2, 0.714, 0.7821, 0.5},
				{1.986, 2, 0.714, 0.7821, 0.5},
				{2.066, 2, 0.714, 0.7821, 0.5},
				{2.146, 2, 0.714, 0.7821, 0.5},
				{2.226, 2, 0.714, 0.7821, 0.5},
				{1.809, 2, 0.5593, 0.7885, 0.5},
				{1.869, 2, 0.5593, 0.7885, 0.5},
				{1.929, 2, 0.5593, 0.7885, 0.5},
				{1.989, 2, 0.5593, 0.7885, 0.5},
				{2.069, 2, 0.5593, 0.7885, 0.5},
				{2.149, 2, 0.5593, 0.7885, 0.5},
				{2.229, 2, 0.5593, 0.7885, 0.5},
				{1.812, 2, 0.161, 0.7962, 0.5},
				{1.872, 2, 0.161, 0.7962, 0.5},
				{1.932, 2, 0.161, 0.7962, 0.5},
				{1.992, 2, 0.161, 0.7962, 0.5},
				{2.072, 2, 0.161, 0.7962, 0.5},
				{2.152, 2, 0.161, 0.7962, 0.5},
				{2.232, 2, 0.161, 0.7962, 0.5},
				{1.823, 2, 0.0511, 0.8335, 0.5},
				{1.883, 2, 0.0511, 0.8335, 0.5},
				{1.943, 2, 0.0511, 0.8335, 0.5},
				{2.003, 2, 0.0511, 0.8335, 0.5},
				{2.083, 2, 0.0511, 0.8335, 0.5},
				{2.163, 2, 0.0511, 0.8335, 0.5},
				{2.243, 2, 0.0511, 0.8335, 0.5},
				{1.829, 2, 0.7708, 0.783, 0.5},
				{1.889, 2, 0.7708, 0.783, 0.5},
				{1.949, 2, 0.7708, 0.783, 0.5},
				{2.009, 2, 0.7708, 0.783, 0.5},
				{2.089, 2, 0.7708, 0.783, 0.5},
				{2.169, 2, 0.7708, 0.783, 0.5},
				{2.249, 2, 0.7708, 0.783, 0.5},
				{1.831, 2, 0.2823, 0.8189, 0.5},
				{1.891, 2, 0.2823, 0.8189, 0.5},
				{1.951, 2, 0.2823, 0.8189, 0.5},
				{2.011, 2, 0.2823, 0.8189, 0.5},
				{2.091, 2, 0.2823, 0.8189, 0.5},
				{2.171, 2, 0.2823, 0.8189, 0.5},
				{2.251, 2, 0.2823, 0.8189, 0.5},
				{1.839, 2, 0.9801, 0.8217, 0.5},
				{1.899, 2, 0.9801, 0.8217, 0.5},
				{1.959, 2, 0.9801, 0.8217, 0.5},
				{2.019, 2, 0.9801, 0.8217, 0.5},
				{2.099, 2, 0.9801, 0.8217, 0.5},
				{2.179, 2, 0.9801, 0.8217, 0.5},
				{2.259, 2, 0.9801, 0.8217, 0.5},
				{1.842, 2, 0.99, 0.7989, 0.5},
				{1.902, 2, 0.99, 0.7989, 0.5},
				{1.962, 2, 0.99, 0.7989, 0.5},
				{2.022, 2, 0.99, 0.7989, 0.5},
				{2.102, 2, 0.99, 0.7989, 0.5},
				{2.182, 2, 0.99, 0.7989, 0.5},
				{2.262, 2, 0.99, 0.7989, 0.5},
				{1.846, 2, 0.5545, 0.8234, 0.5},
				{1.906, 2, 0.5545, 0.8234, 0.5},
				{1.966, 2, 0.5545, 0.8234, 0.5},
				{2.026, 2, 0.5545, 0.8234, 0.5},
				{2.106, 2, 0.5545, 0.8234, 0.5},
				{2.186, 2, 0.5545, 0.8234, 0.5},
				{2.266, 2, 0.5545, 0.8234, 0.5},
				{1.847, 2, 0.5741, 0.8453, 0.5},
				{1.907, 2, 0.5741, 0.8453, 0.5},
				{1.967, 2, 0.5741, 0.8453, 0.5},
				{2.027, 2, 0.5741, 0.8453, 0.5},
				{2.107, 2, 0.5741, 0.8453, 0.5},
				{2.187, 2, 0.5741, 0.8453, 0.5},
				{2.267, 2, 0.5741, 0.8453, 0.5},
				{1.849, 2, 0.9898, 0.8071, 0.5},
				{1.909, 2, 0.9898, 0.8071, 0.5},
				{1.969, 2, 0.9898, 0.8071, 0.5},
				{2.029, 2, 0.9898, 0.8071, 0.5},
				{2.109, 2, 0.9898, 0.8071, 0.5},
				{2.189, 2, 0.9898, 0.8071, 0.5},
				{2.269, 2, 0.9898, 0.8071, 0.5},
				{1.856, 2, 0.5369, 0.8216, 0.5},
				{1.916, 2, 0.5369, 0.8216, 0.5},
				{1.976, 2, 0.5369, 0.8216, 0.5},
				{2.036, 2, 0.5369, 0.8216, 0.5},
				{2.116, 2, 0.5369, 0.8216, 0.5},
				{2.196, 2, 0.5369, 0.8216, 0.5},
				{2.276, 2, 0.5369, 0.8216, 0.5},
				{1.866, 1, 0.8387, 0.2621, 0.5},
				{1.926, 1, 0.8387, 0.2621, 0.5},
				{1.986, 1, 0.8387, 0.2621, 0.5},
				{2.046, 1, 0.8387, 0.2621, 0.5},
				{2.126, 1, 0.8387, 0.2621, 0.5},
				{2.206, 1, 0.8387, 0.2621, 0.5},
				{1.878, 2, 0.6262, 0.8749, 0.5},
				{1.938, 2, 0.6262, 0.8749, 0.5},
				{1.998, 2, 0.6262, 0.8749, 0.5},
				{2.058, 2, 0.6262, 0.8749, 0.5},
				{2.138, 2, 0.6262, 0.8749, 0.5},
				{2.218, 2, 0.6262, 0.8749, 0.5},
				{2.298, 2, 0.6262, 0.8749, 0.5},
				{1.89, 2, 0.6206, 0.8755, 0.5},
				{1.95, 2, 0.6206, 0.8755, 0.5},
				{2.01, 2, 0.6206, 0.8755, 0.5},
				{2.07, 2, 0.6206, 0.8755, 0.5},
				{2.15, 2, 0.6206, 0.8755, 0.5},
				{2.23, 2, 0.6206, 0.8755, 0.5},
				{2.31, 2, 0.6206, 0.8755, 0.5},
				{1.893, 1, 0.7542, 0.1731, 0.5},
				{1.953, 1, 0.7542, 0.1731, 0.5},
				{2.013, 1, 0.7542, 0.1731, 0.5},
				{2.073, 1, 0.7542, 0.1731, 0.5},
				{2.153, 1, 0.7542, 0.1731, 0.5},
				{2.233, 1, 0.7542, 0.1731, 0.5},
				{1.901, 2, 0.4458, 0.9212, 0.5},
				{1.961, 2, 0.4458, 0.9212, 0.5},
				{2.021, 2, 0.4458, 0.9212, 0.5},
				{2.081, 2, 0.4458, 0.9212, 0.5},
				{2.161, 2, 0.4458, 0.9212, 0.5},
				{2.241, 2, 0.4458, 0.9212, 0.5},
				{2.321, 2, 0.4458, 0.9212, 0.5},
				{1.903, 2, 0.3691, 0.9317, 0.5},
				{1.963, 2, 0.3691, 0.9317, 0.5},
				{2.023, 2, 0.3691, 0.9317, 0.5},
				{2.083, 2, 0.3691, 0.9317, 0.5},
				{2.163, 2, 0.3691, 0.9317, 0.5},
				{2.243, 2, 0.3691, 0.9317, 0.5},
				{2.323, 2, 0.3691, 0.9317, 0.5},
				{1.918, 2, 0.8701, 0.9324, 0.5},
				{1.978, 2, 0.8701, 0.9324, 0.5},
				{2.038, 2, 0.8701, 0.9324, 0.5},
				{2.098, 2, 0.8701, 0.9324, 0.5},
				{2.178, 2, 0.8701, 0.9324, 0.5},
				{2.258, 2, 0.8701, 0.9324, 0.5},
				{2.338, 2, 0.8701, 0.9324, 0.5},
				{1.919, 2, 0.3253, 0.9462, 0.5},
				{1.979, 2, 0.3253, 0.9462, 0.5},
				{2.039, 2, 0.3253, 0.9462, 0.5},
				{2.099, 2, 0.3253, 0.9462, 0.5},
				{2.179, 2, 0.3253, 0.9462, 0.5},
				{2.259, 2, 0.3253, 0.9462, 0.5},
				{2.339, 2, 0.3253, 0.9462, 0.5},
				{1.924, 2, 0.9362, 0.9408, 0.5},
				{1.984, 2, 0.9362, 0.9408, 0.5},
				{2.044, 2, 0.9362, 0.9408, 0.5},
				{2.104, 2, 0.9362, 0.9408, 0.5},
				{2.184, 2, 0.9362, 0.9408, 0.5},
				{2.264, 2, 0.9362, 0.9408, 0.5},
				{2.344, 2, 0.9362, 0.9408, 0.5},
				{1.934, 1, 0.9347, 0.4568, 0.5},
				{1.994, 1, 0.9347, 0.4568, 0.5},
				{2.054, 1, 0.9347, 0.4568, 0.5},
				{2.114, 1, 0.9347, 0.4568, 0.5},
				{2.194, 1, 0.9347, 0.4568, 0.5},
				{2.274, 1, 0.9347, 0.4568, 0.5},
				{1.942, 2, 0.2281, 0.9646, 0.5},
				{2.002, 2, 0.2281, 0.9646, 0.5},
				{2.062, 2, 0.2281, 0.9646, 0.5},
				{2.122, 2, 0.2281, 0.9646, 0.5},
				{2.202, 2, 0.2281, 0.9646, 0.5},
				{2.282, 2, 0.2281, 0.9646, 0.5},
				{2.362, 2, 0.2281, 0.9646, 0.5},
				{1.953, 2, 0.249, 0.9562, 0.5},
				{2.013, 2, 0.249, 0.9562, 0.5},
				{2.073, 2, 0.249, 0.9562, 0.5},
				{2.133, 2, 0.249, 0.9562, 0.5},
				{2.213, 2, 0.249, 0.9562, 0.5},
				{2.293, 2, 0.249, 0.9562, 0.5},
				{2.373, 2, 0.249, 0.9562, 0.5},
				{2.015, 1, 0.2292, 0.256, 0.5},
				{2.075, 1, 0.2292, 0.256, 0.5},
				{2.135, 1, 0.2292, 0.256, 0.5},
				{2.195, 1, 0.2292, 0.256, 0.5},
				{2.275, 1, 0.2292, 0.256, 0.5},
				{2.355, 1, 0.2292, 0.256, 0.5},
				{2.025, 1, 0.1948, 0.3303, 0.5},
				{2.085, 1, 0.1948, 0.3303, 0.5},
				{2.145, 1, 0.1948, 0.3303, 0.5},
				{2.205, 1, 0.1948, 0.3303, 0.5},
				{2.285, 1, 0.1948, 0.3303, 0.5},
				{2.365, 1, 0.1948, 0.3303, 0.5},
				{2.033, 1, 0.0149, 0.293, 0.5},
				{2.093, 1, 0.0149, 0.293, 0.5},
				{2.153, 1, 0.0149, 0.293, 0.5},
				{2.213, 1, 0.0149, 0.293, 0.5},
				{2.293, 1, 0.0149, 0.293, 0.5},
				{2.373, 1, 0.0149, 0.293, 0.5},
				{2.086, 1, 0.853, 0.5338, 0.5},
				{2.146, 1, 0.853, 0.5338, 0.5},
				{2.206, 1, 0.853, 0.5338, 0.5},
				{2.266, 1, 0.853, 0.5338, 0.5},
				{2.346, 1, 0.853, 0.5338, 0.5},
				{2.426, 1, 0.853, 0.5338, 0.5},
				{2.109, 1, 0.6377, 0.8684, 0.5},
				{2.169, 1, 0.6377, 0.8684, 0.5},
				{2.229, 1, 0.6377, 0.8684, 0.5},
				{2.289, 1, 0.6377, 0.8684, 0.5},
				{2.369, 1, 0.6377, 0.8684, 0.5},
				{2.449, 1, 0.6377, 0.8684, 0.5},
				{2.117, 1, 0.4071, 0.4441, 0.5},
				{2.177, 1, 0.4071, 0.4441, 0.5},
				{2.237, 1, 0.4071, 0.4441, 0.5},
				{2.297, 1, 0.4071, 0.4441, 0.5},
				{2.377, 1, 0.4071, 0.4441, 0.5},
				{2.457, 1, 0.4071, 0.4441, 0.5},
				{2.117, 1, 0.7917, 0.5286, 0.5},
				{2.177, 1, 0.7917, 0.5286, 0.5},
				{2.237, 1, 0.7917, 0.5286, 0.5},
				{2.297, 1, 0.7917, 0.5286, 0.5},
				{2.377, 1, 0.7917, 0.5286, 0.5},
				{2.457, 1, 0.7917, 0.5286, 0.5},
				{2.117, 1, 0.3286, 0.3049, 0.5},
				{2.177, 1, 0.3286, 0.3049, 0.5},
				{2.237, 1, 0.3286, 0.3049, 0.5},
				{2.297, 1, 0.3286, 0.3049, 0.5},
				{2.377, 1, 0.3286, 0.3049, 0.5},
				{2.457, 1, 0.3286, 0.3049, 0.5},
				{2.151, 1, 0.3948, 0.3457, 0.5},
				{2.211, 1, 0.3948, 0.3457, 0.5},
				{2.271, 1, 0.3948, 0.3457, 0.5},
				{2.331, 1, 0.3948, 0.3457, 0.5},
				{2.411, 1, 0.3948, 0.3457, 0.5},
				{2.155, 1, 0.0512, 0.7779, 0.5},
				{2.215, 1, 0.0512, 0.7779, 0.5},
				{2.275, 1, 0.0512, 0.7779, 0.5},
				{2.335, 1, 0.0512, 0.7779, 0.5},
				{2.415, 1, 0.0512, 0.7779, 0.5},
				{2.495, 1, 0.0512, 0.7779, 0.5},
				{2.161, 1, 0.6009, 0.7362, 0.5},
				{2.221, 1, 0.6009, 0.7362, 0.5},
				{2.281, 1, 0.6009, 0.7362, 0.5},
				{2.341, 1, 0.6009, 0.7362, 0.5},
				{2.421, 1, 0.6009, 0.7362, 0.5},
				{2.203, 1, 0.1046, 0.6806, 0.5},
				{2.263, 1, 0.1046, 0.6806, 0.5},
				{2.323, 1, 0.1046, 0.6806, 0.5},
				{2.383, 1, 0.1046, 0.6806, 0.5},
				{2.463, 1, 0.1046, 0.6806, 0.5},
				{2.543, 1, 0.1046, 0.6806, 0.5},
				{2.213, 1, 0.465, 0.8843, 0.5},
				{2.273, 1, 0.465, 0.8843, 0.5},
				{2.333, 1, 0.465, 0.8843, 0.5},
				{2.393, 1, 0.465, 0.8843, 0.5},
				{2.473, 1, 0.465, 0.8843, 0.5},
				{2.553, 1, 0.465, 0.8843, 0.5},
				{2.215, 1, 0.2578, 0.626, 0.5},
				{2.275, 1, 0.2578, 0.626, 0.5},
				{2.335, 1, 0.2578, 0.626, 0.5},
				{2.395, 1, 0.2578, 0.626, 0.5},
				{2.475, 1, 0.2578, 0.626, 0.5},
				{2.555, 1, 0.2578, 0.626, 0.5},
				{2.218, 1, 0.676, 0.6992, 0.5},
				{2.278, 1, 0.676, 0.6992, 0.5},
				{2.338, 1, 0.676, 0.6992, 0.5},
				{2.398, 1, 0.676, 0.6992, 0.5},
				{2.478, 1, 0.676, 0.6992, 0.5},
				{2.558, 1, 0.676, 0.6992, 0.5},
				{2.229, 1, 0.8448, 0.8404, 0.5},
				{2.289, 1, 0.8448, 0.8404, 0.5},
				{2.349, 1, 0.8448, 0.8404, 0.5},
				{2.409, 1, 0.8448, 0.8404, 0.5},
				{2.489, 1, 0.8448, 0.8404, 0.5},
				{2.569, 1, 0.8448, 0.8404, 0.5},
				{2.232, 1, 0.8013, 0.8388, 0.5},
				{2.292, 1, 0.8013, 0.8388, 0.5},
				{2.352, 1, 0.8013, 0.8388, 0.5},
				{2.412, 1, 0.8013, 0.8388, 0.5},
				{2.492, 1, 0.8013, 0.8388, 0.5},
				{2.572, 1, 0.8013, 0.8388, 0.5},
				{2.235, 1, 0.6787, 0.6227, 0.5},
				{2.295, 1, 0.6787, 0.6227, 0.5},
				{2.355, 1, 0.6787, 0.6227, 0.5},
				{2.415, 1, 0.6787, 0.6227, 0.5},
				{2.495, 1, 0.6787, 0.6227, 0.5},
				{2.244, 1, 0.0376, 0.6434, 0.5},
				{2.304, 1, 0.0376, 0.6434, 0.5},
				{2.364, 1, 0.0376, 0.6434, 0.5},
				{2.424, 1, 0.0376, 0.6434, 0.5},
				{2.504, 1, 0.0376, 0.6434, 0.5},
				{2.584, 1, 0.0376, 0.6434, 0.5},
				{2.26, 1, 0.5812, 0.9485, 0.5},
				{2.32, 1, 0.5812, 0.9485, 0.5},
				{2.38, 1, 0.5812, 0.9485, 0.5},
				{2.44, 1, 0.5812, 0.9485, 0.5},
				{2.52, 1, 0.5812, 0.9485, 0.5},
				{2.6, 1, 0.5812, 0.9485, 0.5},
				{2.266, 1, 0.7521, 0.2986, 0.5},
				{2.326, 1, 0.7521, 0.2986, 0.5},
				{2.386, 1, 0.7521, 0.2986, 0.5},
				{2.446, 1, 0.7521, 0.2986, 0.5},
				{2.526, 1, 0.7521, 0.2986, 0.5},
				{2.266, 1, 0.9445, 0.7775, 0.5},
				{2.326, 1, 0.9445, 0.7775, 0.5},
				{2.386, 1, 0.9445, 0.7775, 0.5},
				{2.446, 1, 0.9445, 0.7775, 0.5},
				{2.526, 1, 0.9445, 0.7775, 0.5},
				{2.606, 1, 0.9445, 0.7775, 0.5},
				{2.278, 1, 0.8817, 0.7292, 0.5},
				{2.338, 1, 0.8817, 0.7292, 0.5},
				{2.398, 1, 0.8817, 0.7292, 0.5},
				{2.458, 1, 0.8817, 0.7292, 0.5},
				{2.538, 1, 0.8817, 0.7292, 0.5},
				{2.618, 1, 0.8817, 0.7292, 0.5},
				{2.352, 1, 0.7304, 0.7476, 0.5},
				{2.412, 1, 0.7304, 0.7476, 0.5},
				{2.472, 1, 0.7304, 0.7476, 0.5},
				{2.532, 1, 0.7304, 0.7476, 0.5},
				{2.612, 1, 0.7304, 0.7476, 0.5},
				{2.372, 1, 0.8868, 0.9139, 0.5},
				{2.432, 1, 0.8868, 0.9139, 0.5},
				{2.492, 1, 0.8868, 0.9139, 0.5},
				{2.552, 1, 0.8868, 0.9139, 0.5},
				{2.632, 1, 0.8868, 0.9139, 0.5},
				{2.712, 1, 0.8868, 0.9139, 0.5},
				{2.389, 1, 0.0985, 0.8762, 0.5},
				{2.449, 1, 0.0985, 0.8762, 0.5},
				{2.509, 1, 0.0985, 0.8762, 0.5},
				{2.569, 1, 0.0985, 0.8762, 0.5},
				{2.649, 1, 0.0985, 0.8762, 0.5},
				{2.729, 1, 0.0985, 0.8762, 0.5},
				{2.395, 1, 0.3869, 0.2842, 0.5},
				{2.455, 1, 0.3869, 0.2842, 0.5},
				{2.515, 1, 0.3869, 0.2842, 0.5},
				{2.575, 1, 0.3869, 0.2842, 0.5},
				{2.655, 1, 0.3869, 0.2842, 0.5},
				{2.404, 1, 0.6625, 0.6108, 0.5},
				{2.464, 1, 0.6625, 0.6108, 0.5},
				{2.524, 1, 0.6625, 0.6108, 0.5},
				{2.584, 1, 0.6625, 0.6108, 0.5},
				{2.664, 1, 0.6625, 0.6108, 0.5},
				{2.408, 1, 0.2886, 0.3753, 0.5},
				{2.468, 1, 0.2886, 0.3753, 0.5},
				{2.528, 1, 0.2886, 0.3753, 0.5},
				{2.588, 1, 0.2886, 0.3753, 0.5},
				{2.668, 1, 0.2886, 0.3753, 0.5},
				{2.437, 1, 0.6765, 0.8373, 0.5},
				{2.497, 1, 0.6765, 0.8373, 0.5},
				{2.557, 1, 0.6765, 0.8373, 0.5},
				{2.617, 1, 0.6765, 0.8373, 0.5},
				{2.697, 1, 0.6765, 0.8373, 0.5},
				{2.442, 1, 0.4162, 0.4856, 0.5},
				{2.502, 1, 0.4162, 0.4856, 0.5},
				{2.562, 1, 0.4162, 0.4856, 0.5},
				{2.622, 1, 0.4162, 0.4856, 0.5},
				{2.702, 1, 0.4162, 0.4856, 0.5},
				{2.45, 1, 0.9033, 0.8469, 0.5},
				{2.51, 1, 0.9033, 0.8469, 0.5},
				{2.57, 1, 0.9033, 0.8469, 0.5},
				{2.63, 1, 0.9033, 0.8469, 0.5},
				{2.71, 1, 0.9033, 0.8469, 0.5},
				{2.462, 1, 0.2629, 0.7499, 0.5},
				{2.522, 1, 0.2629, 0.7499, 0.5},
				{2.582, 1, 0.2629, 0.7499, 0.5},
				{2.642, 1, 0.2629, 0.7499, 0.5},
				{2.722, 1, 0.2629, 0.7499, 0.5},
				{2.525, 1, 0.0934, 0.4428, 0.5},
				{2.585, 1, 0.0934, 0.4428, 0.5},
				{2.645, 1, 0.0934, 0.4428, 0.5},
				{2.705, 1, 0.0934, 0.4428, 0.5},
				{2.785, 1, 0.0934, 0.4428, 0.5},
				{2.525, 1, 0.7608, 0.8107, 0.5},
				{2.585, 1, 0.7608, 0.8107, 0.5},
				{2.645, 1, 0.7608, 0.8107, 0.5},
				{2.705, 1, 0.7608, 0.8107, 0.5},
				{2.785, 1, 0.7608, 0.8107, 0.5},
				{2.565, 1, 0.4668, 0.4761, 0.5},
				{2.625, 1, 0.4668, 0.4761, 0.5},
				{2.685, 1, 0.4668, 0.4761, 0.5},
				{2.745, 1, 0.4668, 0.4761, 0.5},
				{2.825, 1, 0.4668, 0.4761, 0.5},
				{2.57, 1, 0.4837, 0.7641, 0.5},
				{2.63, 1, 0.4837, 0.7641, 0.5},
				{2.69, 1, 0.4837, 0.7641, 0.5},
				{2.75, 1, 0.4837, 0.7641, 0.5},
				{2.83, 1, 0.4837, 0.7641, 0.5},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "GeyserTongues",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {4, 4},
			speed = {120, 180},
			drag = 2,
			lifetime = {0.4, 0.6},
			size = {
				{0, 6, 1},
				{0.4, 14, 2},
				{1, 4, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			radial = false,
			ring_emit = {
				{1.315, 1, 0.6321, 0.1735, 0.5},
				{1.375, 1, 0.6321, 0.1735, 0.5},
				{1.435, 1, 0.6321, 0.1735, 0.5},
				{1.495, 1, 0.6321, 0.1735, 0.5},
				{1.575, 1, 0.6321, 0.1735, 0.5},
				{1.655, 1, 0.6321, 0.1735, 0.5},
				{1.735, 1, 0.6321, 0.1735, 0.5},
				{1.357, 1, 0.3013, 0.2467, 0.5},
				{1.417, 1, 0.3013, 0.2467, 0.5},
				{1.477, 1, 0.3013, 0.2467, 0.5},
				{1.537, 1, 0.3013, 0.2467, 0.5},
				{1.617, 1, 0.3013, 0.2467, 0.5},
				{1.697, 1, 0.3013, 0.2467, 0.5},
				{1.777, 1, 0.3013, 0.2467, 0.5},
				{1.361, 1, 0.4909, 0.245, 0.5},
				{1.421, 1, 0.4909, 0.245, 0.5},
				{1.481, 1, 0.4909, 0.245, 0.5},
				{1.541, 1, 0.4909, 0.245, 0.5},
				{1.621, 1, 0.4909, 0.245, 0.5},
				{1.701, 1, 0.4909, 0.245, 0.5},
				{1.781, 1, 0.4909, 0.245, 0.5},
				{1.37, 1, 0.7035, 0.255, 0.5},
				{1.43, 1, 0.7035, 0.255, 0.5},
				{1.49, 1, 0.7035, 0.255, 0.5},
				{1.55, 1, 0.7035, 0.255, 0.5},
				{1.63, 1, 0.7035, 0.255, 0.5},
				{1.71, 1, 0.7035, 0.255, 0.5},
				{1.79, 1, 0.7035, 0.255, 0.5},
				{1.373, 1, 0.9526, 0.2118, 0.5},
				{1.433, 1, 0.9526, 0.2118, 0.5},
				{1.493, 1, 0.9526, 0.2118, 0.5},
				{1.553, 1, 0.9526, 0.2118, 0.5},
				{1.633, 1, 0.9526, 0.2118, 0.5},
				{1.713, 1, 0.9526, 0.2118, 0.5},
				{1.793, 1, 0.9526, 0.2118, 0.5},
				{1.384, 1, 0.316, 0.2645, 0.5},
				{1.444, 1, 0.316, 0.2645, 0.5},
				{1.504, 1, 0.316, 0.2645, 0.5},
				{1.564, 1, 0.316, 0.2645, 0.5},
				{1.644, 1, 0.316, 0.2645, 0.5},
				{1.724, 1, 0.316, 0.2645, 0.5},
				{1.804, 1, 0.316, 0.2645, 0.5},
				{1.478, 1, 0.5882, 0.3432, 0.5},
				{1.538, 1, 0.5882, 0.3432, 0.5},
				{1.598, 1, 0.5882, 0.3432, 0.5},
				{1.658, 1, 0.5882, 0.3432, 0.5},
				{1.738, 1, 0.5882, 0.3432, 0.5},
				{1.818, 1, 0.5882, 0.3432, 0.5},
				{1.898, 1, 0.5882, 0.3432, 0.5},
				{1.514, 1, 0.8186, 0.4314, 0.5},
				{1.574, 1, 0.8186, 0.4314, 0.5},
				{1.634, 1, 0.8186, 0.4314, 0.5},
				{1.694, 1, 0.8186, 0.4314, 0.5},
				{1.774, 1, 0.8186, 0.4314, 0.5},
				{1.854, 1, 0.8186, 0.4314, 0.5},
				{1.934, 1, 0.8186, 0.4314, 0.5},
				{1.517, 1, 0.4217, 0.4375, 0.5},
				{1.577, 1, 0.4217, 0.4375, 0.5},
				{1.637, 1, 0.4217, 0.4375, 0.5},
				{1.697, 1, 0.4217, 0.4375, 0.5},
				{1.777, 1, 0.4217, 0.4375, 0.5},
				{1.857, 1, 0.4217, 0.4375, 0.5},
				{1.937, 1, 0.4217, 0.4375, 0.5},
				{1.522, 1, 0.0199, 0.4065, 0.5},
				{1.582, 1, 0.0199, 0.4065, 0.5},
				{1.642, 1, 0.0199, 0.4065, 0.5},
				{1.702, 1, 0.0199, 0.4065, 0.5},
				{1.782, 1, 0.0199, 0.4065, 0.5},
				{1.862, 1, 0.0199, 0.4065, 0.5},
				{1.942, 1, 0.0199, 0.4065, 0.5},
				{1.524, 1, 0.093, 0.405, 0.5},
				{1.584, 1, 0.093, 0.405, 0.5},
				{1.644, 1, 0.093, 0.405, 0.5},
				{1.704, 1, 0.093, 0.405, 0.5},
				{1.784, 1, 0.093, 0.405, 0.5},
				{1.864, 1, 0.093, 0.405, 0.5},
				{1.944, 1, 0.093, 0.405, 0.5},
				{1.549, 1, 0.3172, 0.4284, 0.5},
				{1.609, 1, 0.3172, 0.4284, 0.5},
				{1.669, 1, 0.3172, 0.4284, 0.5},
				{1.729, 1, 0.3172, 0.4284, 0.5},
				{1.809, 1, 0.3172, 0.4284, 0.5},
				{1.889, 1, 0.3172, 0.4284, 0.5},
				{1.969, 1, 0.3172, 0.4284, 0.5},
				{1.559, 1, 0.6554, 0.479, 0.5},
				{1.619, 1, 0.6554, 0.479, 0.5},
				{1.679, 1, 0.6554, 0.479, 0.5},
				{1.739, 1, 0.6554, 0.479, 0.5},
				{1.819, 1, 0.6554, 0.479, 0.5},
				{1.899, 1, 0.6554, 0.479, 0.5},
				{1.979, 1, 0.6554, 0.479, 0.5},
				{1.568, 1, 0.1583, 0.4987, 0.5},
				{1.628, 1, 0.1583, 0.4987, 0.5},
				{1.688, 1, 0.1583, 0.4987, 0.5},
				{1.748, 1, 0.1583, 0.4987, 0.5},
				{1.828, 1, 0.1583, 0.4987, 0.5},
				{1.908, 1, 0.1583, 0.4987, 0.5},
				{1.988, 1, 0.1583, 0.4987, 0.5},
				{1.569, 1, 0.8407, 0.4784, 0.5},
				{1.629, 1, 0.8407, 0.4784, 0.5},
				{1.689, 1, 0.8407, 0.4784, 0.5},
				{1.749, 1, 0.8407, 0.4784, 0.5},
				{1.829, 1, 0.8407, 0.4784, 0.5},
				{1.909, 1, 0.8407, 0.4784, 0.5},
				{1.989, 1, 0.8407, 0.4784, 0.5},
				{1.582, 1, 0.1535, 0.5242, 0.5},
				{1.642, 1, 0.1535, 0.5242, 0.5},
				{1.702, 1, 0.1535, 0.5242, 0.5},
				{1.762, 1, 0.1535, 0.5242, 0.5},
				{1.842, 1, 0.1535, 0.5242, 0.5},
				{1.922, 1, 0.1535, 0.5242, 0.5},
				{2.002, 1, 0.1535, 0.5242, 0.5},
				{1.586, 1, 0.9307, 0.5284, 0.5},
				{1.646, 1, 0.9307, 0.5284, 0.5},
				{1.706, 1, 0.9307, 0.5284, 0.5},
				{1.766, 1, 0.9307, 0.5284, 0.5},
				{1.846, 1, 0.9307, 0.5284, 0.5},
				{1.926, 1, 0.9307, 0.5284, 0.5},
				{2.006, 1, 0.9307, 0.5284, 0.5},
				{1.598, 1, 0.2695, 0.494, 0.5},
				{1.658, 1, 0.2695, 0.494, 0.5},
				{1.718, 1, 0.2695, 0.494, 0.5},
				{1.778, 1, 0.2695, 0.494, 0.5},
				{1.858, 1, 0.2695, 0.494, 0.5},
				{1.938, 1, 0.2695, 0.494, 0.5},
				{2.018, 1, 0.2695, 0.494, 0.5},
				{1.609, 1, 0.9107, 0.5561, 0.5},
				{1.669, 1, 0.9107, 0.5561, 0.5},
				{1.729, 1, 0.9107, 0.5561, 0.5},
				{1.789, 1, 0.9107, 0.5561, 0.5},
				{1.869, 1, 0.9107, 0.5561, 0.5},
				{1.949, 1, 0.9107, 0.5561, 0.5},
				{2.029, 1, 0.9107, 0.5561, 0.5},
				{1.612, 1, 0.9856, 0.553, 0.5},
				{1.672, 1, 0.9856, 0.553, 0.5},
				{1.732, 1, 0.9856, 0.553, 0.5},
				{1.792, 1, 0.9856, 0.553, 0.5},
				{1.872, 1, 0.9856, 0.553, 0.5},
				{1.952, 1, 0.9856, 0.553, 0.5},
				{2.032, 1, 0.9856, 0.553, 0.5},
				{1.634, 1, 0.6498, 0.6019, 0.5},
				{1.694, 1, 0.6498, 0.6019, 0.5},
				{1.754, 1, 0.6498, 0.6019, 0.5},
				{1.814, 1, 0.6498, 0.6019, 0.5},
				{1.894, 1, 0.6498, 0.6019, 0.5},
				{1.974, 1, 0.6498, 0.6019, 0.5},
				{2.054, 1, 0.6498, 0.6019, 0.5},
				{1.657, 1, 0.4452, 0.5825, 0.5},
				{1.717, 1, 0.4452, 0.5825, 0.5},
				{1.777, 1, 0.4452, 0.5825, 0.5},
				{1.837, 1, 0.4452, 0.5825, 0.5},
				{1.917, 1, 0.4452, 0.5825, 0.5},
				{1.997, 1, 0.4452, 0.5825, 0.5},
				{2.077, 1, 0.4452, 0.5825, 0.5},
				{1.712, 1, 0.4631, 0.6579, 0.5},
				{1.772, 1, 0.4631, 0.6579, 0.5},
				{1.832, 1, 0.4631, 0.6579, 0.5},
				{1.892, 1, 0.4631, 0.6579, 0.5},
				{1.972, 1, 0.4631, 0.6579, 0.5},
				{2.052, 1, 0.4631, 0.6579, 0.5},
				{2.132, 1, 0.4631, 0.6579, 0.5},
				{1.719, 1, 0.2724, 0.64, 0.5},
				{1.779, 1, 0.2724, 0.64, 0.5},
				{1.839, 1, 0.2724, 0.64, 0.5},
				{1.899, 1, 0.2724, 0.64, 0.5},
				{1.979, 1, 0.2724, 0.64, 0.5},
				{2.059, 1, 0.2724, 0.64, 0.5},
				{2.139, 1, 0.2724, 0.64, 0.5},
				{1.722, 1, 0.7521, 0.6503, 0.5},
				{1.782, 1, 0.7521, 0.6503, 0.5},
				{1.842, 1, 0.7521, 0.6503, 0.5},
				{1.902, 1, 0.7521, 0.6503, 0.5},
				{1.982, 1, 0.7521, 0.6503, 0.5},
				{2.062, 1, 0.7521, 0.6503, 0.5},
				{2.142, 1, 0.7521, 0.6503, 0.5},
				{1.733, 1, 0.5963, 0.6582, 0.5},
				{1.793, 1, 0.5963, 0.6582, 0.5},
				{1.853, 1, 0.5963, 0.6582, 0.5},
				{1.913, 1, 0.5963, 0.6582, 0.5},
				{1.993, 1, 0.5963, 0.6582, 0.5},
				{2.073, 1, 0.5963, 0.6582, 0.5},
				{2.153, 1, 0.5963, 0.6582, 0.5},
				{1.751, 1, 0.0887, 0.6869, 0.5},
				{1.811, 1, 0.0887, 0.6869, 0.5},
				{1.871, 1, 0.0887, 0.6869, 0.5},
				{1.931, 1, 0.0887, 0.6869, 0.5},
				{2.011, 1, 0.0887, 0.6869, 0.5},
				{2.091, 1, 0.0887, 0.6869, 0.5},
				{2.171, 1, 0.0887, 0.6869, 0.5},
				{1.761, 1, 0.7925, 0.741, 0.5},
				{1.821, 1, 0.7925, 0.741, 0.5},
				{1.881, 1, 0.7925, 0.741, 0.5},
				{1.941, 1, 0.7925, 0.741, 0.5},
				{2.021, 1, 0.7925, 0.741, 0.5},
				{2.101, 1, 0.7925, 0.741, 0.5},
				{2.181, 1, 0.7925, 0.741, 0.5},
				{1.763, 1, 0.1437, 0.7109, 0.5},
				{1.823, 1, 0.1437, 0.7109, 0.5},
				{1.883, 1, 0.1437, 0.7109, 0.5},
				{1.943, 1, 0.1437, 0.7109, 0.5},
				{2.023, 1, 0.1437, 0.7109, 0.5},
				{2.103, 1, 0.1437, 0.7109, 0.5},
				{2.183, 1, 0.1437, 0.7109, 0.5},
				{1.763, 1, 0.9887, 0.6947, 0.5},
				{1.823, 1, 0.9887, 0.6947, 0.5},
				{1.883, 1, 0.9887, 0.6947, 0.5},
				{1.943, 1, 0.9887, 0.6947, 0.5},
				{2.023, 1, 0.9887, 0.6947, 0.5},
				{2.103, 1, 0.9887, 0.6947, 0.5},
				{2.183, 1, 0.9887, 0.6947, 0.5},
				{1.77, 1, 0.0517, 0.7043, 0.5},
				{1.83, 1, 0.0517, 0.7043, 0.5},
				{1.89, 1, 0.0517, 0.7043, 0.5},
				{1.95, 1, 0.0517, 0.7043, 0.5},
				{2.03, 1, 0.0517, 0.7043, 0.5},
				{2.11, 1, 0.0517, 0.7043, 0.5},
				{2.19, 1, 0.0517, 0.7043, 0.5},
				{1.783, 1, 0.8816, 0.7223, 0.5},
				{1.843, 1, 0.8816, 0.7223, 0.5},
				{1.903, 1, 0.8816, 0.7223, 0.5},
				{1.963, 1, 0.8816, 0.7223, 0.5},
				{2.043, 1, 0.8816, 0.7223, 0.5},
				{2.123, 1, 0.8816, 0.7223, 0.5},
				{2.203, 1, 0.8816, 0.7223, 0.5},
				{1.79, 1, 0.4579, 0.7892, 0.5},
				{1.85, 1, 0.4579, 0.7892, 0.5},
				{1.91, 1, 0.4579, 0.7892, 0.5},
				{1.97, 1, 0.4579, 0.7892, 0.5},
				{2.05, 1, 0.4579, 0.7892, 0.5},
				{2.13, 1, 0.4579, 0.7892, 0.5},
				{2.21, 1, 0.4579, 0.7892, 0.5},
				{1.795, 1, 0.0684, 0.7635, 0.5},
				{1.855, 1, 0.0684, 0.7635, 0.5},
				{1.915, 1, 0.0684, 0.7635, 0.5},
				{1.975, 1, 0.0684, 0.7635, 0.5},
				{2.055, 1, 0.0684, 0.7635, 0.5},
				{2.135, 1, 0.0684, 0.7635, 0.5},
				{2.215, 1, 0.0684, 0.7635, 0.5},
				{1.796, 1, 0.4456, 0.7639, 0.5},
				{1.856, 1, 0.4456, 0.7639, 0.5},
				{1.916, 1, 0.4456, 0.7639, 0.5},
				{1.976, 1, 0.4456, 0.7639, 0.5},
				{2.056, 1, 0.4456, 0.7639, 0.5},
				{2.136, 1, 0.4456, 0.7639, 0.5},
				{2.216, 1, 0.4456, 0.7639, 0.5},
				{1.806, 1, 0.714, 0.7821, 0.5},
				{1.866, 1, 0.714, 0.7821, 0.5},
				{1.926, 1, 0.714, 0.7821, 0.5},
				{1.986, 1, 0.714, 0.7821, 0.5},
				{2.066, 1, 0.714, 0.7821, 0.5},
				{2.146, 1, 0.714, 0.7821, 0.5},
				{2.226, 1, 0.714, 0.7821, 0.5},
				{1.809, 1, 0.5593, 0.7885, 0.5},
				{1.869, 1, 0.5593, 0.7885, 0.5},
				{1.929, 1, 0.5593, 0.7885, 0.5},
				{1.989, 1, 0.5593, 0.7885, 0.5},
				{2.069, 1, 0.5593, 0.7885, 0.5},
				{2.149, 1, 0.5593, 0.7885, 0.5},
				{2.229, 1, 0.5593, 0.7885, 0.5},
				{1.812, 1, 0.161, 0.7962, 0.5},
				{1.872, 1, 0.161, 0.7962, 0.5},
				{1.932, 1, 0.161, 0.7962, 0.5},
				{1.992, 1, 0.161, 0.7962, 0.5},
				{2.072, 1, 0.161, 0.7962, 0.5},
				{2.152, 1, 0.161, 0.7962, 0.5},
				{2.232, 1, 0.161, 0.7962, 0.5},
				{1.823, 1, 0.0511, 0.8335, 0.5},
				{1.883, 1, 0.0511, 0.8335, 0.5},
				{1.943, 1, 0.0511, 0.8335, 0.5},
				{2.003, 1, 0.0511, 0.8335, 0.5},
				{2.083, 1, 0.0511, 0.8335, 0.5},
				{2.163, 1, 0.0511, 0.8335, 0.5},
				{2.243, 1, 0.0511, 0.8335, 0.5},
				{1.829, 1, 0.7708, 0.783, 0.5},
				{1.889, 1, 0.7708, 0.783, 0.5},
				{1.949, 1, 0.7708, 0.783, 0.5},
				{2.009, 1, 0.7708, 0.783, 0.5},
				{2.089, 1, 0.7708, 0.783, 0.5},
				{2.169, 1, 0.7708, 0.783, 0.5},
				{2.249, 1, 0.7708, 0.783, 0.5},
				{1.831, 1, 0.2823, 0.8189, 0.5},
				{1.891, 1, 0.2823, 0.8189, 0.5},
				{1.951, 1, 0.2823, 0.8189, 0.5},
				{2.011, 1, 0.2823, 0.8189, 0.5},
				{2.091, 1, 0.2823, 0.8189, 0.5},
				{2.171, 1, 0.2823, 0.8189, 0.5},
				{2.251, 1, 0.2823, 0.8189, 0.5},
				{1.839, 1, 0.9801, 0.8217, 0.5},
				{1.899, 1, 0.9801, 0.8217, 0.5},
				{1.959, 1, 0.9801, 0.8217, 0.5},
				{2.019, 1, 0.9801, 0.8217, 0.5},
				{2.099, 1, 0.9801, 0.8217, 0.5},
				{2.179, 1, 0.9801, 0.8217, 0.5},
				{2.259, 1, 0.9801, 0.8217, 0.5},
				{1.842, 1, 0.99, 0.7989, 0.5},
				{1.902, 1, 0.99, 0.7989, 0.5},
				{1.962, 1, 0.99, 0.7989, 0.5},
				{2.022, 1, 0.99, 0.7989, 0.5},
				{2.102, 1, 0.99, 0.7989, 0.5},
				{2.182, 1, 0.99, 0.7989, 0.5},
				{2.262, 1, 0.99, 0.7989, 0.5},
				{1.846, 1, 0.5545, 0.8234, 0.5},
				{1.906, 1, 0.5545, 0.8234, 0.5},
				{1.966, 1, 0.5545, 0.8234, 0.5},
				{2.026, 1, 0.5545, 0.8234, 0.5},
				{2.106, 1, 0.5545, 0.8234, 0.5},
				{2.186, 1, 0.5545, 0.8234, 0.5},
				{2.266, 1, 0.5545, 0.8234, 0.5},
				{1.847, 1, 0.5741, 0.8453, 0.5},
				{1.907, 1, 0.5741, 0.8453, 0.5},
				{1.967, 1, 0.5741, 0.8453, 0.5},
				{2.027, 1, 0.5741, 0.8453, 0.5},
				{2.107, 1, 0.5741, 0.8453, 0.5},
				{2.187, 1, 0.5741, 0.8453, 0.5},
				{2.267, 1, 0.5741, 0.8453, 0.5},
				{1.849, 1, 0.9898, 0.8071, 0.5},
				{1.909, 1, 0.9898, 0.8071, 0.5},
				{1.969, 1, 0.9898, 0.8071, 0.5},
				{2.029, 1, 0.9898, 0.8071, 0.5},
				{2.109, 1, 0.9898, 0.8071, 0.5},
				{2.189, 1, 0.9898, 0.8071, 0.5},
				{2.269, 1, 0.9898, 0.8071, 0.5},
				{1.856, 1, 0.5369, 0.8216, 0.5},
				{1.916, 1, 0.5369, 0.8216, 0.5},
				{1.976, 1, 0.5369, 0.8216, 0.5},
				{2.036, 1, 0.5369, 0.8216, 0.5},
				{2.116, 1, 0.5369, 0.8216, 0.5},
				{2.196, 1, 0.5369, 0.8216, 0.5},
				{2.276, 1, 0.5369, 0.8216, 0.5},
				{1.866, 1, 0.8387, 0.2621, 0.5},
				{1.926, 1, 0.8387, 0.2621, 0.5},
				{1.986, 1, 0.8387, 0.2621, 0.5},
				{2.046, 1, 0.8387, 0.2621, 0.5},
				{2.126, 1, 0.8387, 0.2621, 0.5},
				{2.206, 1, 0.8387, 0.2621, 0.5},
				{1.878, 1, 0.6262, 0.8749, 0.5},
				{1.938, 1, 0.6262, 0.8749, 0.5},
				{1.998, 1, 0.6262, 0.8749, 0.5},
				{2.058, 1, 0.6262, 0.8749, 0.5},
				{2.138, 1, 0.6262, 0.8749, 0.5},
				{2.218, 1, 0.6262, 0.8749, 0.5},
				{2.298, 1, 0.6262, 0.8749, 0.5},
				{1.89, 1, 0.6206, 0.8755, 0.5},
				{1.95, 1, 0.6206, 0.8755, 0.5},
				{2.01, 1, 0.6206, 0.8755, 0.5},
				{2.07, 1, 0.6206, 0.8755, 0.5},
				{2.15, 1, 0.6206, 0.8755, 0.5},
				{2.23, 1, 0.6206, 0.8755, 0.5},
				{2.31, 1, 0.6206, 0.8755, 0.5},
				{1.893, 1, 0.7542, 0.1731, 0.5},
				{1.953, 1, 0.7542, 0.1731, 0.5},
				{2.013, 1, 0.7542, 0.1731, 0.5},
				{2.073, 1, 0.7542, 0.1731, 0.5},
				{2.153, 1, 0.7542, 0.1731, 0.5},
				{2.233, 1, 0.7542, 0.1731, 0.5},
				{1.901, 1, 0.4458, 0.9212, 0.5},
				{1.961, 1, 0.4458, 0.9212, 0.5},
				{2.021, 1, 0.4458, 0.9212, 0.5},
				{2.081, 1, 0.4458, 0.9212, 0.5},
				{2.161, 1, 0.4458, 0.9212, 0.5},
				{2.241, 1, 0.4458, 0.9212, 0.5},
				{2.321, 1, 0.4458, 0.9212, 0.5},
				{1.903, 1, 0.3691, 0.9317, 0.5},
				{1.963, 1, 0.3691, 0.9317, 0.5},
				{2.023, 1, 0.3691, 0.9317, 0.5},
				{2.083, 1, 0.3691, 0.9317, 0.5},
				{2.163, 1, 0.3691, 0.9317, 0.5},
				{2.243, 1, 0.3691, 0.9317, 0.5},
				{2.323, 1, 0.3691, 0.9317, 0.5},
				{1.918, 1, 0.8701, 0.9324, 0.5},
				{1.978, 1, 0.8701, 0.9324, 0.5},
				{2.038, 1, 0.8701, 0.9324, 0.5},
				{2.098, 1, 0.8701, 0.9324, 0.5},
				{2.178, 1, 0.8701, 0.9324, 0.5},
				{2.258, 1, 0.8701, 0.9324, 0.5},
				{2.338, 1, 0.8701, 0.9324, 0.5},
				{1.919, 1, 0.3253, 0.9462, 0.5},
				{1.979, 1, 0.3253, 0.9462, 0.5},
				{2.039, 1, 0.3253, 0.9462, 0.5},
				{2.099, 1, 0.3253, 0.9462, 0.5},
				{2.179, 1, 0.3253, 0.9462, 0.5},
				{2.259, 1, 0.3253, 0.9462, 0.5},
				{2.339, 1, 0.3253, 0.9462, 0.5},
				{1.924, 1, 0.9362, 0.9408, 0.5},
				{1.984, 1, 0.9362, 0.9408, 0.5},
				{2.044, 1, 0.9362, 0.9408, 0.5},
				{2.104, 1, 0.9362, 0.9408, 0.5},
				{2.184, 1, 0.9362, 0.9408, 0.5},
				{2.264, 1, 0.9362, 0.9408, 0.5},
				{2.344, 1, 0.9362, 0.9408, 0.5},
				{1.934, 1, 0.9347, 0.4568, 0.5},
				{1.994, 1, 0.9347, 0.4568, 0.5},
				{2.054, 1, 0.9347, 0.4568, 0.5},
				{2.114, 1, 0.9347, 0.4568, 0.5},
				{2.194, 1, 0.9347, 0.4568, 0.5},
				{2.274, 1, 0.9347, 0.4568, 0.5},
				{1.942, 1, 0.2281, 0.9646, 0.5},
				{2.002, 1, 0.2281, 0.9646, 0.5},
				{2.062, 1, 0.2281, 0.9646, 0.5},
				{2.122, 1, 0.2281, 0.9646, 0.5},
				{2.202, 1, 0.2281, 0.9646, 0.5},
				{2.282, 1, 0.2281, 0.9646, 0.5},
				{2.362, 1, 0.2281, 0.9646, 0.5},
				{1.953, 1, 0.249, 0.9562, 0.5},
				{2.013, 1, 0.249, 0.9562, 0.5},
				{2.073, 1, 0.249, 0.9562, 0.5},
				{2.133, 1, 0.249, 0.9562, 0.5},
				{2.213, 1, 0.249, 0.9562, 0.5},
				{2.293, 1, 0.249, 0.9562, 0.5},
				{2.373, 1, 0.249, 0.9562, 0.5},
				{2.015, 1, 0.2292, 0.256, 0.5},
				{2.075, 1, 0.2292, 0.256, 0.5},
				{2.135, 1, 0.2292, 0.256, 0.5},
				{2.195, 1, 0.2292, 0.256, 0.5},
				{2.275, 1, 0.2292, 0.256, 0.5},
				{2.355, 1, 0.2292, 0.256, 0.5},
				{2.025, 1, 0.1948, 0.3303, 0.5},
				{2.085, 1, 0.1948, 0.3303, 0.5},
				{2.145, 1, 0.1948, 0.3303, 0.5},
				{2.205, 1, 0.1948, 0.3303, 0.5},
				{2.285, 1, 0.1948, 0.3303, 0.5},
				{2.365, 1, 0.1948, 0.3303, 0.5},
				{2.033, 1, 0.0149, 0.293, 0.5},
				{2.093, 1, 0.0149, 0.293, 0.5},
				{2.153, 1, 0.0149, 0.293, 0.5},
				{2.213, 1, 0.0149, 0.293, 0.5},
				{2.293, 1, 0.0149, 0.293, 0.5},
				{2.373, 1, 0.0149, 0.293, 0.5},
				{2.086, 1, 0.853, 0.5338, 0.5},
				{2.146, 1, 0.853, 0.5338, 0.5},
				{2.206, 1, 0.853, 0.5338, 0.5},
				{2.266, 1, 0.853, 0.5338, 0.5},
				{2.346, 1, 0.853, 0.5338, 0.5},
				{2.426, 1, 0.853, 0.5338, 0.5},
				{2.109, 1, 0.6377, 0.8684, 0.5},
				{2.169, 1, 0.6377, 0.8684, 0.5},
				{2.229, 1, 0.6377, 0.8684, 0.5},
				{2.289, 1, 0.6377, 0.8684, 0.5},
				{2.369, 1, 0.6377, 0.8684, 0.5},
				{2.449, 1, 0.6377, 0.8684, 0.5},
				{2.117, 1, 0.4071, 0.4441, 0.5},
				{2.177, 1, 0.4071, 0.4441, 0.5},
				{2.237, 1, 0.4071, 0.4441, 0.5},
				{2.297, 1, 0.4071, 0.4441, 0.5},
				{2.377, 1, 0.4071, 0.4441, 0.5},
				{2.457, 1, 0.4071, 0.4441, 0.5},
				{2.117, 1, 0.7917, 0.5286, 0.5},
				{2.177, 1, 0.7917, 0.5286, 0.5},
				{2.237, 1, 0.7917, 0.5286, 0.5},
				{2.297, 1, 0.7917, 0.5286, 0.5},
				{2.377, 1, 0.7917, 0.5286, 0.5},
				{2.457, 1, 0.7917, 0.5286, 0.5},
				{2.117, 1, 0.3286, 0.3049, 0.5},
				{2.177, 1, 0.3286, 0.3049, 0.5},
				{2.237, 1, 0.3286, 0.3049, 0.5},
				{2.297, 1, 0.3286, 0.3049, 0.5},
				{2.377, 1, 0.3286, 0.3049, 0.5},
				{2.457, 1, 0.3286, 0.3049, 0.5},
				{2.151, 1, 0.3948, 0.3457, 0.5},
				{2.211, 1, 0.3948, 0.3457, 0.5},
				{2.271, 1, 0.3948, 0.3457, 0.5},
				{2.331, 1, 0.3948, 0.3457, 0.5},
				{2.411, 1, 0.3948, 0.3457, 0.5},
				{2.155, 1, 0.0512, 0.7779, 0.5},
				{2.215, 1, 0.0512, 0.7779, 0.5},
				{2.275, 1, 0.0512, 0.7779, 0.5},
				{2.335, 1, 0.0512, 0.7779, 0.5},
				{2.415, 1, 0.0512, 0.7779, 0.5},
				{2.495, 1, 0.0512, 0.7779, 0.5},
				{2.161, 1, 0.6009, 0.7362, 0.5},
				{2.221, 1, 0.6009, 0.7362, 0.5},
				{2.281, 1, 0.6009, 0.7362, 0.5},
				{2.341, 1, 0.6009, 0.7362, 0.5},
				{2.421, 1, 0.6009, 0.7362, 0.5},
				{2.203, 1, 0.1046, 0.6806, 0.5},
				{2.263, 1, 0.1046, 0.6806, 0.5},
				{2.323, 1, 0.1046, 0.6806, 0.5},
				{2.383, 1, 0.1046, 0.6806, 0.5},
				{2.463, 1, 0.1046, 0.6806, 0.5},
				{2.543, 1, 0.1046, 0.6806, 0.5},
				{2.213, 1, 0.465, 0.8843, 0.5},
				{2.273, 1, 0.465, 0.8843, 0.5},
				{2.333, 1, 0.465, 0.8843, 0.5},
				{2.393, 1, 0.465, 0.8843, 0.5},
				{2.473, 1, 0.465, 0.8843, 0.5},
				{2.553, 1, 0.465, 0.8843, 0.5},
				{2.215, 1, 0.2578, 0.626, 0.5},
				{2.275, 1, 0.2578, 0.626, 0.5},
				{2.335, 1, 0.2578, 0.626, 0.5},
				{2.395, 1, 0.2578, 0.626, 0.5},
				{2.475, 1, 0.2578, 0.626, 0.5},
				{2.555, 1, 0.2578, 0.626, 0.5},
				{2.218, 1, 0.676, 0.6992, 0.5},
				{2.278, 1, 0.676, 0.6992, 0.5},
				{2.338, 1, 0.676, 0.6992, 0.5},
				{2.398, 1, 0.676, 0.6992, 0.5},
				{2.478, 1, 0.676, 0.6992, 0.5},
				{2.558, 1, 0.676, 0.6992, 0.5},
				{2.229, 1, 0.8448, 0.8404, 0.5},
				{2.289, 1, 0.8448, 0.8404, 0.5},
				{2.349, 1, 0.8448, 0.8404, 0.5},
				{2.409, 1, 0.8448, 0.8404, 0.5},
				{2.489, 1, 0.8448, 0.8404, 0.5},
				{2.569, 1, 0.8448, 0.8404, 0.5},
				{2.232, 1, 0.8013, 0.8388, 0.5},
				{2.292, 1, 0.8013, 0.8388, 0.5},
				{2.352, 1, 0.8013, 0.8388, 0.5},
				{2.412, 1, 0.8013, 0.8388, 0.5},
				{2.492, 1, 0.8013, 0.8388, 0.5},
				{2.572, 1, 0.8013, 0.8388, 0.5},
				{2.235, 1, 0.6787, 0.6227, 0.5},
				{2.295, 1, 0.6787, 0.6227, 0.5},
				{2.355, 1, 0.6787, 0.6227, 0.5},
				{2.415, 1, 0.6787, 0.6227, 0.5},
				{2.495, 1, 0.6787, 0.6227, 0.5},
				{2.244, 1, 0.0376, 0.6434, 0.5},
				{2.304, 1, 0.0376, 0.6434, 0.5},
				{2.364, 1, 0.0376, 0.6434, 0.5},
				{2.424, 1, 0.0376, 0.6434, 0.5},
				{2.504, 1, 0.0376, 0.6434, 0.5},
				{2.584, 1, 0.0376, 0.6434, 0.5},
				{2.26, 1, 0.5812, 0.9485, 0.5},
				{2.32, 1, 0.5812, 0.9485, 0.5},
				{2.38, 1, 0.5812, 0.9485, 0.5},
				{2.44, 1, 0.5812, 0.9485, 0.5},
				{2.52, 1, 0.5812, 0.9485, 0.5},
				{2.6, 1, 0.5812, 0.9485, 0.5},
				{2.266, 1, 0.7521, 0.2986, 0.5},
				{2.326, 1, 0.7521, 0.2986, 0.5},
				{2.386, 1, 0.7521, 0.2986, 0.5},
				{2.446, 1, 0.7521, 0.2986, 0.5},
				{2.526, 1, 0.7521, 0.2986, 0.5},
				{2.266, 1, 0.9445, 0.7775, 0.5},
				{2.326, 1, 0.9445, 0.7775, 0.5},
				{2.386, 1, 0.9445, 0.7775, 0.5},
				{2.446, 1, 0.9445, 0.7775, 0.5},
				{2.526, 1, 0.9445, 0.7775, 0.5},
				{2.606, 1, 0.9445, 0.7775, 0.5},
				{2.278, 1, 0.8817, 0.7292, 0.5},
				{2.338, 1, 0.8817, 0.7292, 0.5},
				{2.398, 1, 0.8817, 0.7292, 0.5},
				{2.458, 1, 0.8817, 0.7292, 0.5},
				{2.538, 1, 0.8817, 0.7292, 0.5},
				{2.618, 1, 0.8817, 0.7292, 0.5},
				{2.352, 1, 0.7304, 0.7476, 0.5},
				{2.412, 1, 0.7304, 0.7476, 0.5},
				{2.472, 1, 0.7304, 0.7476, 0.5},
				{2.532, 1, 0.7304, 0.7476, 0.5},
				{2.612, 1, 0.7304, 0.7476, 0.5},
				{2.372, 1, 0.8868, 0.9139, 0.5},
				{2.432, 1, 0.8868, 0.9139, 0.5},
				{2.492, 1, 0.8868, 0.9139, 0.5},
				{2.552, 1, 0.8868, 0.9139, 0.5},
				{2.632, 1, 0.8868, 0.9139, 0.5},
				{2.712, 1, 0.8868, 0.9139, 0.5},
				{2.389, 1, 0.0985, 0.8762, 0.5},
				{2.449, 1, 0.0985, 0.8762, 0.5},
				{2.509, 1, 0.0985, 0.8762, 0.5},
				{2.569, 1, 0.0985, 0.8762, 0.5},
				{2.649, 1, 0.0985, 0.8762, 0.5},
				{2.729, 1, 0.0985, 0.8762, 0.5},
				{2.395, 1, 0.3869, 0.2842, 0.5},
				{2.455, 1, 0.3869, 0.2842, 0.5},
				{2.515, 1, 0.3869, 0.2842, 0.5},
				{2.575, 1, 0.3869, 0.2842, 0.5},
				{2.655, 1, 0.3869, 0.2842, 0.5},
				{2.404, 1, 0.6625, 0.6108, 0.5},
				{2.464, 1, 0.6625, 0.6108, 0.5},
				{2.524, 1, 0.6625, 0.6108, 0.5},
				{2.584, 1, 0.6625, 0.6108, 0.5},
				{2.664, 1, 0.6625, 0.6108, 0.5},
				{2.408, 1, 0.2886, 0.3753, 0.5},
				{2.468, 1, 0.2886, 0.3753, 0.5},
				{2.528, 1, 0.2886, 0.3753, 0.5},
				{2.588, 1, 0.2886, 0.3753, 0.5},
				{2.668, 1, 0.2886, 0.3753, 0.5},
				{2.437, 1, 0.6765, 0.8373, 0.5},
				{2.497, 1, 0.6765, 0.8373, 0.5},
				{2.557, 1, 0.6765, 0.8373, 0.5},
				{2.617, 1, 0.6765, 0.8373, 0.5},
				{2.697, 1, 0.6765, 0.8373, 0.5},
				{2.442, 1, 0.4162, 0.4856, 0.5},
				{2.502, 1, 0.4162, 0.4856, 0.5},
				{2.562, 1, 0.4162, 0.4856, 0.5},
				{2.622, 1, 0.4162, 0.4856, 0.5},
				{2.702, 1, 0.4162, 0.4856, 0.5},
				{2.45, 1, 0.9033, 0.8469, 0.5},
				{2.51, 1, 0.9033, 0.8469, 0.5},
				{2.57, 1, 0.9033, 0.8469, 0.5},
				{2.63, 1, 0.9033, 0.8469, 0.5},
				{2.71, 1, 0.9033, 0.8469, 0.5},
				{2.462, 1, 0.2629, 0.7499, 0.5},
				{2.522, 1, 0.2629, 0.7499, 0.5},
				{2.582, 1, 0.2629, 0.7499, 0.5},
				{2.642, 1, 0.2629, 0.7499, 0.5},
				{2.722, 1, 0.2629, 0.7499, 0.5},
				{2.525, 1, 0.0934, 0.4428, 0.5},
				{2.585, 1, 0.0934, 0.4428, 0.5},
				{2.645, 1, 0.0934, 0.4428, 0.5},
				{2.705, 1, 0.0934, 0.4428, 0.5},
				{2.785, 1, 0.0934, 0.4428, 0.5},
				{2.525, 1, 0.7608, 0.8107, 0.5},
				{2.585, 1, 0.7608, 0.8107, 0.5},
				{2.645, 1, 0.7608, 0.8107, 0.5},
				{2.705, 1, 0.7608, 0.8107, 0.5},
				{2.785, 1, 0.7608, 0.8107, 0.5},
				{2.565, 1, 0.4668, 0.4761, 0.5},
				{2.625, 1, 0.4668, 0.4761, 0.5},
				{2.685, 1, 0.4668, 0.4761, 0.5},
				{2.745, 1, 0.4668, 0.4761, 0.5},
				{2.825, 1, 0.4668, 0.4761, 0.5},
				{2.57, 1, 0.4837, 0.7641, 0.5},
				{2.63, 1, 0.4837, 0.7641, 0.5},
				{2.69, 1, 0.4837, 0.7641, 0.5},
				{2.75, 1, 0.4837, 0.7641, 0.5},
				{2.83, 1, 0.4837, 0.7641, 0.5},
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
			name = "GeyserCore",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {3, 3},
			speed = {140, 200},
			drag = 2.5,
			lifetime = {0.3, 0.45},
			size = {
				{0, 8, 0},
				{0.3, 26, 0},
				{1, 12, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			radial = false,
			ring_emit = {
				{1.315, 1, 0.6321, 0.1735, 0.5},
				{1.375, 1, 0.6321, 0.1735, 0.5},
				{1.435, 1, 0.6321, 0.1735, 0.5},
				{1.495, 1, 0.6321, 0.1735, 0.5},
				{1.357, 1, 0.3013, 0.2467, 0.5},
				{1.417, 1, 0.3013, 0.2467, 0.5},
				{1.477, 1, 0.3013, 0.2467, 0.5},
				{1.537, 1, 0.3013, 0.2467, 0.5},
				{1.361, 1, 0.4909, 0.245, 0.5},
				{1.421, 1, 0.4909, 0.245, 0.5},
				{1.481, 1, 0.4909, 0.245, 0.5},
				{1.541, 1, 0.4909, 0.245, 0.5},
				{1.37, 1, 0.7035, 0.255, 0.5},
				{1.43, 1, 0.7035, 0.255, 0.5},
				{1.49, 1, 0.7035, 0.255, 0.5},
				{1.55, 1, 0.7035, 0.255, 0.5},
				{1.373, 1, 0.9526, 0.2118, 0.5},
				{1.433, 1, 0.9526, 0.2118, 0.5},
				{1.493, 1, 0.9526, 0.2118, 0.5},
				{1.553, 1, 0.9526, 0.2118, 0.5},
				{1.384, 1, 0.316, 0.2645, 0.5},
				{1.444, 1, 0.316, 0.2645, 0.5},
				{1.504, 1, 0.316, 0.2645, 0.5},
				{1.564, 1, 0.316, 0.2645, 0.5},
				{1.478, 1, 0.5882, 0.3432, 0.5},
				{1.538, 1, 0.5882, 0.3432, 0.5},
				{1.598, 1, 0.5882, 0.3432, 0.5},
				{1.658, 1, 0.5882, 0.3432, 0.5},
				{1.514, 1, 0.8186, 0.4314, 0.5},
				{1.574, 1, 0.8186, 0.4314, 0.5},
				{1.634, 1, 0.8186, 0.4314, 0.5},
				{1.694, 1, 0.8186, 0.4314, 0.5},
				{1.517, 1, 0.4217, 0.4375, 0.5},
				{1.577, 1, 0.4217, 0.4375, 0.5},
				{1.637, 1, 0.4217, 0.4375, 0.5},
				{1.697, 1, 0.4217, 0.4375, 0.5},
				{1.522, 1, 0.0199, 0.4065, 0.5},
				{1.582, 1, 0.0199, 0.4065, 0.5},
				{1.642, 1, 0.0199, 0.4065, 0.5},
				{1.702, 1, 0.0199, 0.4065, 0.5},
				{1.524, 1, 0.093, 0.405, 0.5},
				{1.584, 1, 0.093, 0.405, 0.5},
				{1.644, 1, 0.093, 0.405, 0.5},
				{1.704, 1, 0.093, 0.405, 0.5},
				{1.549, 1, 0.3172, 0.4284, 0.5},
				{1.609, 1, 0.3172, 0.4284, 0.5},
				{1.669, 1, 0.3172, 0.4284, 0.5},
				{1.729, 1, 0.3172, 0.4284, 0.5},
				{1.559, 1, 0.6554, 0.479, 0.5},
				{1.619, 1, 0.6554, 0.479, 0.5},
				{1.679, 1, 0.6554, 0.479, 0.5},
				{1.739, 1, 0.6554, 0.479, 0.5},
				{1.568, 1, 0.1583, 0.4987, 0.5},
				{1.628, 1, 0.1583, 0.4987, 0.5},
				{1.688, 1, 0.1583, 0.4987, 0.5},
				{1.748, 1, 0.1583, 0.4987, 0.5},
				{1.569, 1, 0.8407, 0.4784, 0.5},
				{1.629, 1, 0.8407, 0.4784, 0.5},
				{1.689, 1, 0.8407, 0.4784, 0.5},
				{1.749, 1, 0.8407, 0.4784, 0.5},
				{1.582, 1, 0.1535, 0.5242, 0.5},
				{1.642, 1, 0.1535, 0.5242, 0.5},
				{1.702, 1, 0.1535, 0.5242, 0.5},
				{1.762, 1, 0.1535, 0.5242, 0.5},
				{1.586, 1, 0.9307, 0.5284, 0.5},
				{1.646, 1, 0.9307, 0.5284, 0.5},
				{1.706, 1, 0.9307, 0.5284, 0.5},
				{1.766, 1, 0.9307, 0.5284, 0.5},
				{1.598, 1, 0.2695, 0.494, 0.5},
				{1.658, 1, 0.2695, 0.494, 0.5},
				{1.718, 1, 0.2695, 0.494, 0.5},
				{1.778, 1, 0.2695, 0.494, 0.5},
				{1.609, 1, 0.9107, 0.5561, 0.5},
				{1.669, 1, 0.9107, 0.5561, 0.5},
				{1.729, 1, 0.9107, 0.5561, 0.5},
				{1.789, 1, 0.9107, 0.5561, 0.5},
				{1.612, 1, 0.9856, 0.553, 0.5},
				{1.672, 1, 0.9856, 0.553, 0.5},
				{1.732, 1, 0.9856, 0.553, 0.5},
				{1.792, 1, 0.9856, 0.553, 0.5},
				{1.634, 1, 0.6498, 0.6019, 0.5},
				{1.694, 1, 0.6498, 0.6019, 0.5},
				{1.754, 1, 0.6498, 0.6019, 0.5},
				{1.814, 1, 0.6498, 0.6019, 0.5},
				{1.657, 1, 0.4452, 0.5825, 0.5},
				{1.717, 1, 0.4452, 0.5825, 0.5},
				{1.777, 1, 0.4452, 0.5825, 0.5},
				{1.837, 1, 0.4452, 0.5825, 0.5},
				{1.712, 1, 0.4631, 0.6579, 0.5},
				{1.772, 1, 0.4631, 0.6579, 0.5},
				{1.832, 1, 0.4631, 0.6579, 0.5},
				{1.892, 1, 0.4631, 0.6579, 0.5},
				{1.719, 1, 0.2724, 0.64, 0.5},
				{1.779, 1, 0.2724, 0.64, 0.5},
				{1.839, 1, 0.2724, 0.64, 0.5},
				{1.899, 1, 0.2724, 0.64, 0.5},
				{1.722, 1, 0.7521, 0.6503, 0.5},
				{1.782, 1, 0.7521, 0.6503, 0.5},
				{1.842, 1, 0.7521, 0.6503, 0.5},
				{1.902, 1, 0.7521, 0.6503, 0.5},
				{1.733, 1, 0.5963, 0.6582, 0.5},
				{1.793, 1, 0.5963, 0.6582, 0.5},
				{1.853, 1, 0.5963, 0.6582, 0.5},
				{1.913, 1, 0.5963, 0.6582, 0.5},
				{1.751, 1, 0.0887, 0.6869, 0.5},
				{1.811, 1, 0.0887, 0.6869, 0.5},
				{1.871, 1, 0.0887, 0.6869, 0.5},
				{1.931, 1, 0.0887, 0.6869, 0.5},
				{1.761, 1, 0.7925, 0.741, 0.5},
				{1.821, 1, 0.7925, 0.741, 0.5},
				{1.881, 1, 0.7925, 0.741, 0.5},
				{1.941, 1, 0.7925, 0.741, 0.5},
				{1.763, 1, 0.1437, 0.7109, 0.5},
				{1.823, 1, 0.1437, 0.7109, 0.5},
				{1.883, 1, 0.1437, 0.7109, 0.5},
				{1.943, 1, 0.1437, 0.7109, 0.5},
				{1.763, 1, 0.9887, 0.6947, 0.5},
				{1.823, 1, 0.9887, 0.6947, 0.5},
				{1.883, 1, 0.9887, 0.6947, 0.5},
				{1.943, 1, 0.9887, 0.6947, 0.5},
				{1.77, 1, 0.0517, 0.7043, 0.5},
				{1.83, 1, 0.0517, 0.7043, 0.5},
				{1.89, 1, 0.0517, 0.7043, 0.5},
				{1.95, 1, 0.0517, 0.7043, 0.5},
				{1.783, 1, 0.8816, 0.7223, 0.5},
				{1.843, 1, 0.8816, 0.7223, 0.5},
				{1.903, 1, 0.8816, 0.7223, 0.5},
				{1.963, 1, 0.8816, 0.7223, 0.5},
				{1.79, 1, 0.4579, 0.7892, 0.5},
				{1.85, 1, 0.4579, 0.7892, 0.5},
				{1.91, 1, 0.4579, 0.7892, 0.5},
				{1.97, 1, 0.4579, 0.7892, 0.5},
				{1.795, 1, 0.0684, 0.7635, 0.5},
				{1.855, 1, 0.0684, 0.7635, 0.5},
				{1.915, 1, 0.0684, 0.7635, 0.5},
				{1.975, 1, 0.0684, 0.7635, 0.5},
				{1.796, 1, 0.4456, 0.7639, 0.5},
				{1.856, 1, 0.4456, 0.7639, 0.5},
				{1.916, 1, 0.4456, 0.7639, 0.5},
				{1.976, 1, 0.4456, 0.7639, 0.5},
				{1.806, 1, 0.714, 0.7821, 0.5},
				{1.866, 1, 0.714, 0.7821, 0.5},
				{1.926, 1, 0.714, 0.7821, 0.5},
				{1.986, 1, 0.714, 0.7821, 0.5},
				{1.809, 1, 0.5593, 0.7885, 0.5},
				{1.869, 1, 0.5593, 0.7885, 0.5},
				{1.929, 1, 0.5593, 0.7885, 0.5},
				{1.989, 1, 0.5593, 0.7885, 0.5},
				{1.812, 1, 0.161, 0.7962, 0.5},
				{1.872, 1, 0.161, 0.7962, 0.5},
				{1.932, 1, 0.161, 0.7962, 0.5},
				{1.992, 1, 0.161, 0.7962, 0.5},
				{1.823, 1, 0.0511, 0.8335, 0.5},
				{1.883, 1, 0.0511, 0.8335, 0.5},
				{1.943, 1, 0.0511, 0.8335, 0.5},
				{2.003, 1, 0.0511, 0.8335, 0.5},
				{1.829, 1, 0.7708, 0.783, 0.5},
				{1.889, 1, 0.7708, 0.783, 0.5},
				{1.949, 1, 0.7708, 0.783, 0.5},
				{2.009, 1, 0.7708, 0.783, 0.5},
				{1.831, 1, 0.2823, 0.8189, 0.5},
				{1.891, 1, 0.2823, 0.8189, 0.5},
				{1.951, 1, 0.2823, 0.8189, 0.5},
				{2.011, 1, 0.2823, 0.8189, 0.5},
				{1.839, 1, 0.9801, 0.8217, 0.5},
				{1.899, 1, 0.9801, 0.8217, 0.5},
				{1.959, 1, 0.9801, 0.8217, 0.5},
				{2.019, 1, 0.9801, 0.8217, 0.5},
				{1.842, 1, 0.99, 0.7989, 0.5},
				{1.902, 1, 0.99, 0.7989, 0.5},
				{1.962, 1, 0.99, 0.7989, 0.5},
				{2.022, 1, 0.99, 0.7989, 0.5},
				{1.846, 1, 0.5545, 0.8234, 0.5},
				{1.906, 1, 0.5545, 0.8234, 0.5},
				{1.966, 1, 0.5545, 0.8234, 0.5},
				{2.026, 1, 0.5545, 0.8234, 0.5},
				{1.847, 1, 0.5741, 0.8453, 0.5},
				{1.907, 1, 0.5741, 0.8453, 0.5},
				{1.967, 1, 0.5741, 0.8453, 0.5},
				{2.027, 1, 0.5741, 0.8453, 0.5},
				{1.849, 1, 0.9898, 0.8071, 0.5},
				{1.909, 1, 0.9898, 0.8071, 0.5},
				{1.969, 1, 0.9898, 0.8071, 0.5},
				{2.029, 1, 0.9898, 0.8071, 0.5},
				{1.856, 1, 0.5369, 0.8216, 0.5},
				{1.916, 1, 0.5369, 0.8216, 0.5},
				{1.976, 1, 0.5369, 0.8216, 0.5},
				{2.036, 1, 0.5369, 0.8216, 0.5},
				{1.866, 1, 0.8387, 0.2621, 0.5},
				{1.926, 1, 0.8387, 0.2621, 0.5},
				{1.986, 1, 0.8387, 0.2621, 0.5},
				{1.878, 1, 0.6262, 0.8749, 0.5},
				{1.938, 1, 0.6262, 0.8749, 0.5},
				{1.998, 1, 0.6262, 0.8749, 0.5},
				{2.058, 1, 0.6262, 0.8749, 0.5},
				{1.89, 1, 0.6206, 0.8755, 0.5},
				{1.95, 1, 0.6206, 0.8755, 0.5},
				{2.01, 1, 0.6206, 0.8755, 0.5},
				{2.07, 1, 0.6206, 0.8755, 0.5},
				{1.893, 1, 0.7542, 0.1731, 0.5},
				{1.953, 1, 0.7542, 0.1731, 0.5},
				{2.013, 1, 0.7542, 0.1731, 0.5},
				{1.901, 1, 0.4458, 0.9212, 0.5},
				{1.961, 1, 0.4458, 0.9212, 0.5},
				{2.021, 1, 0.4458, 0.9212, 0.5},
				{2.081, 1, 0.4458, 0.9212, 0.5},
				{1.903, 1, 0.3691, 0.9317, 0.5},
				{1.963, 1, 0.3691, 0.9317, 0.5},
				{2.023, 1, 0.3691, 0.9317, 0.5},
				{2.083, 1, 0.3691, 0.9317, 0.5},
				{1.918, 1, 0.8701, 0.9324, 0.5},
				{1.978, 1, 0.8701, 0.9324, 0.5},
				{2.038, 1, 0.8701, 0.9324, 0.5},
				{2.098, 1, 0.8701, 0.9324, 0.5},
				{1.919, 1, 0.3253, 0.9462, 0.5},
				{1.979, 1, 0.3253, 0.9462, 0.5},
				{2.039, 1, 0.3253, 0.9462, 0.5},
				{2.099, 1, 0.3253, 0.9462, 0.5},
				{1.924, 1, 0.9362, 0.9408, 0.5},
				{1.984, 1, 0.9362, 0.9408, 0.5},
				{2.044, 1, 0.9362, 0.9408, 0.5},
				{2.104, 1, 0.9362, 0.9408, 0.5},
				{1.934, 1, 0.9347, 0.4568, 0.5},
				{1.994, 1, 0.9347, 0.4568, 0.5},
				{2.054, 1, 0.9347, 0.4568, 0.5},
				{1.942, 1, 0.2281, 0.9646, 0.5},
				{2.002, 1, 0.2281, 0.9646, 0.5},
				{2.062, 1, 0.2281, 0.9646, 0.5},
				{2.122, 1, 0.2281, 0.9646, 0.5},
				{1.953, 1, 0.249, 0.9562, 0.5},
				{2.013, 1, 0.249, 0.9562, 0.5},
				{2.073, 1, 0.249, 0.9562, 0.5},
				{2.133, 1, 0.249, 0.9562, 0.5},
				{2.015, 1, 0.2292, 0.256, 0.5},
				{2.075, 1, 0.2292, 0.256, 0.5},
				{2.135, 1, 0.2292, 0.256, 0.5},
				{2.025, 1, 0.1948, 0.3303, 0.5},
				{2.085, 1, 0.1948, 0.3303, 0.5},
				{2.145, 1, 0.1948, 0.3303, 0.5},
				{2.033, 1, 0.0149, 0.293, 0.5},
				{2.093, 1, 0.0149, 0.293, 0.5},
				{2.153, 1, 0.0149, 0.293, 0.5},
				{2.086, 1, 0.853, 0.5338, 0.5},
				{2.146, 1, 0.853, 0.5338, 0.5},
				{2.206, 1, 0.853, 0.5338, 0.5},
				{2.109, 1, 0.6377, 0.8684, 0.5},
				{2.169, 1, 0.6377, 0.8684, 0.5},
				{2.229, 1, 0.6377, 0.8684, 0.5},
				{2.117, 1, 0.4071, 0.4441, 0.5},
				{2.177, 1, 0.4071, 0.4441, 0.5},
				{2.237, 1, 0.4071, 0.4441, 0.5},
				{2.117, 1, 0.7917, 0.5286, 0.5},
				{2.177, 1, 0.7917, 0.5286, 0.5},
				{2.237, 1, 0.7917, 0.5286, 0.5},
				{2.117, 1, 0.3286, 0.3049, 0.5},
				{2.177, 1, 0.3286, 0.3049, 0.5},
				{2.237, 1, 0.3286, 0.3049, 0.5},
				{2.151, 1, 0.3948, 0.3457, 0.5},
				{2.211, 1, 0.3948, 0.3457, 0.5},
				{2.271, 1, 0.3948, 0.3457, 0.5},
				{2.155, 1, 0.0512, 0.7779, 0.5},
				{2.215, 1, 0.0512, 0.7779, 0.5},
				{2.275, 1, 0.0512, 0.7779, 0.5},
				{2.161, 1, 0.6009, 0.7362, 0.5},
				{2.221, 1, 0.6009, 0.7362, 0.5},
				{2.281, 1, 0.6009, 0.7362, 0.5},
				{2.203, 1, 0.1046, 0.6806, 0.5},
				{2.263, 1, 0.1046, 0.6806, 0.5},
				{2.323, 1, 0.1046, 0.6806, 0.5},
				{2.213, 1, 0.465, 0.8843, 0.5},
				{2.273, 1, 0.465, 0.8843, 0.5},
				{2.333, 1, 0.465, 0.8843, 0.5},
				{2.215, 1, 0.2578, 0.626, 0.5},
				{2.275, 1, 0.2578, 0.626, 0.5},
				{2.335, 1, 0.2578, 0.626, 0.5},
				{2.218, 1, 0.676, 0.6992, 0.5},
				{2.278, 1, 0.676, 0.6992, 0.5},
				{2.338, 1, 0.676, 0.6992, 0.5},
				{2.229, 1, 0.8448, 0.8404, 0.5},
				{2.289, 1, 0.8448, 0.8404, 0.5},
				{2.349, 1, 0.8448, 0.8404, 0.5},
				{2.232, 1, 0.8013, 0.8388, 0.5},
				{2.292, 1, 0.8013, 0.8388, 0.5},
				{2.352, 1, 0.8013, 0.8388, 0.5},
				{2.235, 1, 0.6787, 0.6227, 0.5},
				{2.295, 1, 0.6787, 0.6227, 0.5},
				{2.355, 1, 0.6787, 0.6227, 0.5},
				{2.244, 1, 0.0376, 0.6434, 0.5},
				{2.304, 1, 0.0376, 0.6434, 0.5},
				{2.364, 1, 0.0376, 0.6434, 0.5},
				{2.26, 1, 0.5812, 0.9485, 0.5},
				{2.32, 1, 0.5812, 0.9485, 0.5},
				{2.38, 1, 0.5812, 0.9485, 0.5},
				{2.266, 1, 0.7521, 0.2986, 0.5},
				{2.326, 1, 0.7521, 0.2986, 0.5},
				{2.386, 1, 0.7521, 0.2986, 0.5},
				{2.266, 1, 0.9445, 0.7775, 0.5},
				{2.326, 1, 0.9445, 0.7775, 0.5},
				{2.386, 1, 0.9445, 0.7775, 0.5},
				{2.278, 1, 0.8817, 0.7292, 0.5},
				{2.338, 1, 0.8817, 0.7292, 0.5},
				{2.398, 1, 0.8817, 0.7292, 0.5},
				{2.352, 1, 0.7304, 0.7476, 0.5},
				{2.412, 1, 0.7304, 0.7476, 0.5},
				{2.472, 1, 0.7304, 0.7476, 0.5},
				{2.372, 1, 0.8868, 0.9139, 0.5},
				{2.432, 1, 0.8868, 0.9139, 0.5},
				{2.492, 1, 0.8868, 0.9139, 0.5},
				{2.389, 1, 0.0985, 0.8762, 0.5},
				{2.449, 1, 0.0985, 0.8762, 0.5},
				{2.509, 1, 0.0985, 0.8762, 0.5},
				{2.395, 1, 0.3869, 0.2842, 0.5},
				{2.455, 1, 0.3869, 0.2842, 0.5},
				{2.515, 1, 0.3869, 0.2842, 0.5},
				{2.404, 1, 0.6625, 0.6108, 0.5},
				{2.464, 1, 0.6625, 0.6108, 0.5},
				{2.524, 1, 0.6625, 0.6108, 0.5},
				{2.408, 1, 0.2886, 0.3753, 0.5},
				{2.468, 1, 0.2886, 0.3753, 0.5},
				{2.528, 1, 0.2886, 0.3753, 0.5},
				{2.437, 1, 0.6765, 0.8373, 0.5},
				{2.497, 1, 0.6765, 0.8373, 0.5},
				{2.557, 1, 0.6765, 0.8373, 0.5},
				{2.442, 1, 0.4162, 0.4856, 0.5},
				{2.502, 1, 0.4162, 0.4856, 0.5},
				{2.562, 1, 0.4162, 0.4856, 0.5},
				{2.45, 1, 0.9033, 0.8469, 0.5},
				{2.51, 1, 0.9033, 0.8469, 0.5},
				{2.57, 1, 0.9033, 0.8469, 0.5},
				{2.462, 1, 0.2629, 0.7499, 0.5},
				{2.522, 1, 0.2629, 0.7499, 0.5},
				{2.582, 1, 0.2629, 0.7499, 0.5},
				{2.525, 1, 0.0934, 0.4428, 0.5},
				{2.585, 1, 0.0934, 0.4428, 0.5},
				{2.645, 1, 0.0934, 0.4428, 0.5},
				{2.525, 1, 0.7608, 0.8107, 0.5},
				{2.585, 1, 0.7608, 0.8107, 0.5},
				{2.645, 1, 0.7608, 0.8107, 0.5},
				{2.565, 1, 0.4668, 0.4761, 0.5},
				{2.625, 1, 0.4668, 0.4761, 0.5},
				{2.685, 1, 0.4668, 0.4761, 0.5},
				{2.57, 1, 0.4837, 0.7641, 0.5},
				{2.63, 1, 0.4837, 0.7641, 0.5},
				{2.69, 1, 0.4837, 0.7641, 0.5},
			},
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
			name = "GeyserBase",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {30, 30},
			speed = {6, 14},
			drag = 2,
			accel = {0, 6, 0},
			lifetime = {0.4, 0.6},
			size = {
				{0, 6, 1},
				{0.3, 12, 2},
				{1, 4, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.6, 0.42, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {0, 360},
			radial = false,
			ring_emit = {
				{1.315, 1, 0.6321, 0.1735, 1.5},
				{1.435, 1, 0.6321, 0.1735, 1.5},
				{1.575, 1, 0.6321, 0.1735, 1.5},
				{1.735, 1, 0.6321, 0.1735, 1.5},
				{1.357, 1, 0.3013, 0.2467, 1.5},
				{1.477, 1, 0.3013, 0.2467, 1.5},
				{1.617, 1, 0.3013, 0.2467, 1.5},
				{1.777, 1, 0.3013, 0.2467, 1.5},
				{1.361, 1, 0.4909, 0.245, 1.5},
				{1.481, 1, 0.4909, 0.245, 1.5},
				{1.621, 1, 0.4909, 0.245, 1.5},
				{1.781, 1, 0.4909, 0.245, 1.5},
				{1.37, 1, 0.7035, 0.255, 1.5},
				{1.49, 1, 0.7035, 0.255, 1.5},
				{1.63, 1, 0.7035, 0.255, 1.5},
				{1.79, 1, 0.7035, 0.255, 1.5},
				{1.373, 1, 0.9526, 0.2118, 1.5},
				{1.493, 1, 0.9526, 0.2118, 1.5},
				{1.633, 1, 0.9526, 0.2118, 1.5},
				{1.793, 1, 0.9526, 0.2118, 1.5},
				{1.384, 1, 0.316, 0.2645, 1.5},
				{1.504, 1, 0.316, 0.2645, 1.5},
				{1.644, 1, 0.316, 0.2645, 1.5},
				{1.804, 1, 0.316, 0.2645, 1.5},
				{1.478, 1, 0.5882, 0.3432, 1.5},
				{1.598, 1, 0.5882, 0.3432, 1.5},
				{1.738, 1, 0.5882, 0.3432, 1.5},
				{1.898, 1, 0.5882, 0.3432, 1.5},
				{1.514, 1, 0.8186, 0.4314, 1.5},
				{1.634, 1, 0.8186, 0.4314, 1.5},
				{1.774, 1, 0.8186, 0.4314, 1.5},
				{1.934, 1, 0.8186, 0.4314, 1.5},
				{1.517, 1, 0.4217, 0.4375, 1.5},
				{1.637, 1, 0.4217, 0.4375, 1.5},
				{1.777, 1, 0.4217, 0.4375, 1.5},
				{1.937, 1, 0.4217, 0.4375, 1.5},
				{1.522, 1, 0.0199, 0.4065, 1.5},
				{1.642, 1, 0.0199, 0.4065, 1.5},
				{1.782, 1, 0.0199, 0.4065, 1.5},
				{1.942, 1, 0.0199, 0.4065, 1.5},
				{1.524, 1, 0.093, 0.405, 1.5},
				{1.644, 1, 0.093, 0.405, 1.5},
				{1.784, 1, 0.093, 0.405, 1.5},
				{1.944, 1, 0.093, 0.405, 1.5},
				{1.549, 1, 0.3172, 0.4284, 1.5},
				{1.669, 1, 0.3172, 0.4284, 1.5},
				{1.809, 1, 0.3172, 0.4284, 1.5},
				{1.969, 1, 0.3172, 0.4284, 1.5},
				{1.559, 1, 0.6554, 0.479, 1.5},
				{1.679, 1, 0.6554, 0.479, 1.5},
				{1.819, 1, 0.6554, 0.479, 1.5},
				{1.979, 1, 0.6554, 0.479, 1.5},
				{1.568, 1, 0.1583, 0.4987, 1.5},
				{1.688, 1, 0.1583, 0.4987, 1.5},
				{1.828, 1, 0.1583, 0.4987, 1.5},
				{1.988, 1, 0.1583, 0.4987, 1.5},
				{1.569, 1, 0.8407, 0.4784, 1.5},
				{1.689, 1, 0.8407, 0.4784, 1.5},
				{1.829, 1, 0.8407, 0.4784, 1.5},
				{1.989, 1, 0.8407, 0.4784, 1.5},
				{1.582, 1, 0.1535, 0.5242, 1.5},
				{1.702, 1, 0.1535, 0.5242, 1.5},
				{1.842, 1, 0.1535, 0.5242, 1.5},
				{2.002, 1, 0.1535, 0.5242, 1.5},
				{1.586, 1, 0.9307, 0.5284, 1.5},
				{1.706, 1, 0.9307, 0.5284, 1.5},
				{1.846, 1, 0.9307, 0.5284, 1.5},
				{2.006, 1, 0.9307, 0.5284, 1.5},
				{1.598, 1, 0.2695, 0.494, 1.5},
				{1.718, 1, 0.2695, 0.494, 1.5},
				{1.858, 1, 0.2695, 0.494, 1.5},
				{2.018, 1, 0.2695, 0.494, 1.5},
				{1.609, 1, 0.9107, 0.5561, 1.5},
				{1.729, 1, 0.9107, 0.5561, 1.5},
				{1.869, 1, 0.9107, 0.5561, 1.5},
				{2.029, 1, 0.9107, 0.5561, 1.5},
				{1.612, 1, 0.9856, 0.553, 1.5},
				{1.732, 1, 0.9856, 0.553, 1.5},
				{1.872, 1, 0.9856, 0.553, 1.5},
				{2.032, 1, 0.9856, 0.553, 1.5},
				{1.634, 1, 0.6498, 0.6019, 1.5},
				{1.754, 1, 0.6498, 0.6019, 1.5},
				{1.894, 1, 0.6498, 0.6019, 1.5},
				{2.054, 1, 0.6498, 0.6019, 1.5},
				{1.657, 1, 0.4452, 0.5825, 1.5},
				{1.777, 1, 0.4452, 0.5825, 1.5},
				{1.917, 1, 0.4452, 0.5825, 1.5},
				{2.077, 1, 0.4452, 0.5825, 1.5},
				{1.712, 1, 0.4631, 0.6579, 1.5},
				{1.832, 1, 0.4631, 0.6579, 1.5},
				{1.972, 1, 0.4631, 0.6579, 1.5},
				{2.132, 1, 0.4631, 0.6579, 1.5},
				{1.719, 1, 0.2724, 0.64, 1.5},
				{1.839, 1, 0.2724, 0.64, 1.5},
				{1.979, 1, 0.2724, 0.64, 1.5},
				{2.139, 1, 0.2724, 0.64, 1.5},
				{1.722, 1, 0.7521, 0.6503, 1.5},
				{1.842, 1, 0.7521, 0.6503, 1.5},
				{1.982, 1, 0.7521, 0.6503, 1.5},
				{2.142, 1, 0.7521, 0.6503, 1.5},
				{1.733, 1, 0.5963, 0.6582, 1.5},
				{1.853, 1, 0.5963, 0.6582, 1.5},
				{1.993, 1, 0.5963, 0.6582, 1.5},
				{2.153, 1, 0.5963, 0.6582, 1.5},
				{1.751, 1, 0.0887, 0.6869, 1.5},
				{1.871, 1, 0.0887, 0.6869, 1.5},
				{2.011, 1, 0.0887, 0.6869, 1.5},
				{2.171, 1, 0.0887, 0.6869, 1.5},
				{1.761, 1, 0.7925, 0.741, 1.5},
				{1.881, 1, 0.7925, 0.741, 1.5},
				{2.021, 1, 0.7925, 0.741, 1.5},
				{2.181, 1, 0.7925, 0.741, 1.5},
				{1.763, 1, 0.1437, 0.7109, 1.5},
				{1.883, 1, 0.1437, 0.7109, 1.5},
				{2.023, 1, 0.1437, 0.7109, 1.5},
				{2.183, 1, 0.1437, 0.7109, 1.5},
				{1.763, 1, 0.9887, 0.6947, 1.5},
				{1.883, 1, 0.9887, 0.6947, 1.5},
				{2.023, 1, 0.9887, 0.6947, 1.5},
				{2.183, 1, 0.9887, 0.6947, 1.5},
				{1.77, 1, 0.0517, 0.7043, 1.5},
				{1.89, 1, 0.0517, 0.7043, 1.5},
				{2.03, 1, 0.0517, 0.7043, 1.5},
				{2.19, 1, 0.0517, 0.7043, 1.5},
				{1.783, 1, 0.8816, 0.7223, 1.5},
				{1.903, 1, 0.8816, 0.7223, 1.5},
				{2.043, 1, 0.8816, 0.7223, 1.5},
				{2.203, 1, 0.8816, 0.7223, 1.5},
				{1.79, 1, 0.4579, 0.7892, 1.5},
				{1.91, 1, 0.4579, 0.7892, 1.5},
				{2.05, 1, 0.4579, 0.7892, 1.5},
				{2.21, 1, 0.4579, 0.7892, 1.5},
				{1.795, 1, 0.0684, 0.7635, 1.5},
				{1.915, 1, 0.0684, 0.7635, 1.5},
				{2.055, 1, 0.0684, 0.7635, 1.5},
				{2.215, 1, 0.0684, 0.7635, 1.5},
				{1.796, 1, 0.4456, 0.7639, 1.5},
				{1.916, 1, 0.4456, 0.7639, 1.5},
				{2.056, 1, 0.4456, 0.7639, 1.5},
				{2.216, 1, 0.4456, 0.7639, 1.5},
				{1.806, 1, 0.714, 0.7821, 1.5},
				{1.926, 1, 0.714, 0.7821, 1.5},
				{2.066, 1, 0.714, 0.7821, 1.5},
				{2.226, 1, 0.714, 0.7821, 1.5},
				{1.809, 1, 0.5593, 0.7885, 1.5},
				{1.929, 1, 0.5593, 0.7885, 1.5},
				{2.069, 1, 0.5593, 0.7885, 1.5},
				{2.229, 1, 0.5593, 0.7885, 1.5},
				{1.812, 1, 0.161, 0.7962, 1.5},
				{1.932, 1, 0.161, 0.7962, 1.5},
				{2.072, 1, 0.161, 0.7962, 1.5},
				{2.232, 1, 0.161, 0.7962, 1.5},
				{1.823, 1, 0.0511, 0.8335, 1.5},
				{1.943, 1, 0.0511, 0.8335, 1.5},
				{2.083, 1, 0.0511, 0.8335, 1.5},
				{2.243, 1, 0.0511, 0.8335, 1.5},
				{1.829, 1, 0.7708, 0.783, 1.5},
				{1.949, 1, 0.7708, 0.783, 1.5},
				{2.089, 1, 0.7708, 0.783, 1.5},
				{2.249, 1, 0.7708, 0.783, 1.5},
				{1.831, 1, 0.2823, 0.8189, 1.5},
				{1.951, 1, 0.2823, 0.8189, 1.5},
				{2.091, 1, 0.2823, 0.8189, 1.5},
				{2.251, 1, 0.2823, 0.8189, 1.5},
				{1.839, 1, 0.9801, 0.8217, 1.5},
				{1.959, 1, 0.9801, 0.8217, 1.5},
				{2.099, 1, 0.9801, 0.8217, 1.5},
				{2.259, 1, 0.9801, 0.8217, 1.5},
				{1.842, 1, 0.99, 0.7989, 1.5},
				{1.962, 1, 0.99, 0.7989, 1.5},
				{2.102, 1, 0.99, 0.7989, 1.5},
				{2.262, 1, 0.99, 0.7989, 1.5},
				{1.846, 1, 0.5545, 0.8234, 1.5},
				{1.966, 1, 0.5545, 0.8234, 1.5},
				{2.106, 1, 0.5545, 0.8234, 1.5},
				{2.266, 1, 0.5545, 0.8234, 1.5},
				{1.847, 1, 0.5741, 0.8453, 1.5},
				{1.967, 1, 0.5741, 0.8453, 1.5},
				{2.107, 1, 0.5741, 0.8453, 1.5},
				{2.267, 1, 0.5741, 0.8453, 1.5},
				{1.849, 1, 0.9898, 0.8071, 1.5},
				{1.969, 1, 0.9898, 0.8071, 1.5},
				{2.109, 1, 0.9898, 0.8071, 1.5},
				{2.269, 1, 0.9898, 0.8071, 1.5},
				{1.856, 1, 0.5369, 0.8216, 1.5},
				{1.976, 1, 0.5369, 0.8216, 1.5},
				{2.116, 1, 0.5369, 0.8216, 1.5},
				{2.276, 1, 0.5369, 0.8216, 1.5},
				{1.866, 1, 0.8387, 0.2621, 1.5},
				{1.986, 1, 0.8387, 0.2621, 1.5},
				{2.126, 1, 0.8387, 0.2621, 1.5},
				{1.878, 1, 0.6262, 0.8749, 1.5},
				{1.998, 1, 0.6262, 0.8749, 1.5},
				{2.138, 1, 0.6262, 0.8749, 1.5},
				{2.298, 1, 0.6262, 0.8749, 1.5},
				{1.89, 1, 0.6206, 0.8755, 1.5},
				{2.01, 1, 0.6206, 0.8755, 1.5},
				{2.15, 1, 0.6206, 0.8755, 1.5},
				{2.31, 1, 0.6206, 0.8755, 1.5},
				{1.893, 1, 0.7542, 0.1731, 1.5},
				{2.013, 1, 0.7542, 0.1731, 1.5},
				{2.153, 1, 0.7542, 0.1731, 1.5},
				{1.901, 1, 0.4458, 0.9212, 1.5},
				{2.021, 1, 0.4458, 0.9212, 1.5},
				{2.161, 1, 0.4458, 0.9212, 1.5},
				{2.321, 1, 0.4458, 0.9212, 1.5},
				{1.903, 1, 0.3691, 0.9317, 1.5},
				{2.023, 1, 0.3691, 0.9317, 1.5},
				{2.163, 1, 0.3691, 0.9317, 1.5},
				{2.323, 1, 0.3691, 0.9317, 1.5},
				{1.918, 1, 0.8701, 0.9324, 1.5},
				{2.038, 1, 0.8701, 0.9324, 1.5},
				{2.178, 1, 0.8701, 0.9324, 1.5},
				{2.338, 1, 0.8701, 0.9324, 1.5},
				{1.919, 1, 0.3253, 0.9462, 1.5},
				{2.039, 1, 0.3253, 0.9462, 1.5},
				{2.179, 1, 0.3253, 0.9462, 1.5},
				{2.339, 1, 0.3253, 0.9462, 1.5},
				{1.924, 1, 0.9362, 0.9408, 1.5},
				{2.044, 1, 0.9362, 0.9408, 1.5},
				{2.184, 1, 0.9362, 0.9408, 1.5},
				{2.344, 1, 0.9362, 0.9408, 1.5},
				{1.934, 1, 0.9347, 0.4568, 1.5},
				{2.054, 1, 0.9347, 0.4568, 1.5},
				{2.194, 1, 0.9347, 0.4568, 1.5},
				{1.942, 1, 0.2281, 0.9646, 1.5},
				{2.062, 1, 0.2281, 0.9646, 1.5},
				{2.202, 1, 0.2281, 0.9646, 1.5},
				{2.362, 1, 0.2281, 0.9646, 1.5},
				{1.953, 1, 0.249, 0.9562, 1.5},
				{2.073, 1, 0.249, 0.9562, 1.5},
				{2.213, 1, 0.249, 0.9562, 1.5},
				{2.373, 1, 0.249, 0.9562, 1.5},
				{2.015, 1, 0.2292, 0.256, 1.5},
				{2.135, 1, 0.2292, 0.256, 1.5},
				{2.275, 1, 0.2292, 0.256, 1.5},
				{2.025, 1, 0.1948, 0.3303, 1.5},
				{2.145, 1, 0.1948, 0.3303, 1.5},
				{2.285, 1, 0.1948, 0.3303, 1.5},
				{2.033, 1, 0.0149, 0.293, 1.5},
				{2.153, 1, 0.0149, 0.293, 1.5},
				{2.293, 1, 0.0149, 0.293, 1.5},
				{2.086, 1, 0.853, 0.5338, 1.5},
				{2.206, 1, 0.853, 0.5338, 1.5},
				{2.346, 1, 0.853, 0.5338, 1.5},
				{2.109, 1, 0.6377, 0.8684, 1.5},
				{2.229, 1, 0.6377, 0.8684, 1.5},
				{2.369, 1, 0.6377, 0.8684, 1.5},
				{2.117, 1, 0.4071, 0.4441, 1.5},
				{2.237, 1, 0.4071, 0.4441, 1.5},
				{2.377, 1, 0.4071, 0.4441, 1.5},
				{2.117, 1, 0.7917, 0.5286, 1.5},
				{2.237, 1, 0.7917, 0.5286, 1.5},
				{2.377, 1, 0.7917, 0.5286, 1.5},
				{2.117, 1, 0.3286, 0.3049, 1.5},
				{2.237, 1, 0.3286, 0.3049, 1.5},
				{2.377, 1, 0.3286, 0.3049, 1.5},
				{2.151, 1, 0.3948, 0.3457, 1.5},
				{2.271, 1, 0.3948, 0.3457, 1.5},
				{2.411, 1, 0.3948, 0.3457, 1.5},
				{2.155, 1, 0.0512, 0.7779, 1.5},
				{2.275, 1, 0.0512, 0.7779, 1.5},
				{2.415, 1, 0.0512, 0.7779, 1.5},
				{2.161, 1, 0.6009, 0.7362, 1.5},
				{2.281, 1, 0.6009, 0.7362, 1.5},
				{2.421, 1, 0.6009, 0.7362, 1.5},
				{2.203, 1, 0.1046, 0.6806, 1.5},
				{2.323, 1, 0.1046, 0.6806, 1.5},
				{2.463, 1, 0.1046, 0.6806, 1.5},
				{2.213, 1, 0.465, 0.8843, 1.5},
				{2.333, 1, 0.465, 0.8843, 1.5},
				{2.473, 1, 0.465, 0.8843, 1.5},
				{2.215, 1, 0.2578, 0.626, 1.5},
				{2.335, 1, 0.2578, 0.626, 1.5},
				{2.475, 1, 0.2578, 0.626, 1.5},
				{2.218, 1, 0.676, 0.6992, 1.5},
				{2.338, 1, 0.676, 0.6992, 1.5},
				{2.478, 1, 0.676, 0.6992, 1.5},
				{2.229, 1, 0.8448, 0.8404, 1.5},
				{2.349, 1, 0.8448, 0.8404, 1.5},
				{2.489, 1, 0.8448, 0.8404, 1.5},
				{2.232, 1, 0.8013, 0.8388, 1.5},
				{2.352, 1, 0.8013, 0.8388, 1.5},
				{2.492, 1, 0.8013, 0.8388, 1.5},
				{2.235, 1, 0.6787, 0.6227, 1.5},
				{2.355, 1, 0.6787, 0.6227, 1.5},
				{2.495, 1, 0.6787, 0.6227, 1.5},
				{2.244, 1, 0.0376, 0.6434, 1.5},
				{2.364, 1, 0.0376, 0.6434, 1.5},
				{2.504, 1, 0.0376, 0.6434, 1.5},
				{2.26, 1, 0.5812, 0.9485, 1.5},
				{2.38, 1, 0.5812, 0.9485, 1.5},
				{2.52, 1, 0.5812, 0.9485, 1.5},
				{2.266, 1, 0.7521, 0.2986, 1.5},
				{2.386, 1, 0.7521, 0.2986, 1.5},
				{2.526, 1, 0.7521, 0.2986, 1.5},
				{2.266, 1, 0.9445, 0.7775, 1.5},
				{2.386, 1, 0.9445, 0.7775, 1.5},
				{2.526, 1, 0.9445, 0.7775, 1.5},
				{2.278, 1, 0.8817, 0.7292, 1.5},
				{2.398, 1, 0.8817, 0.7292, 1.5},
				{2.538, 1, 0.8817, 0.7292, 1.5},
				{2.352, 1, 0.7304, 0.7476, 1.5},
				{2.472, 1, 0.7304, 0.7476, 1.5},
				{2.612, 1, 0.7304, 0.7476, 1.5},
				{2.372, 1, 0.8868, 0.9139, 1.5},
				{2.492, 1, 0.8868, 0.9139, 1.5},
				{2.632, 1, 0.8868, 0.9139, 1.5},
				{2.389, 1, 0.0985, 0.8762, 1.5},
				{2.509, 1, 0.0985, 0.8762, 1.5},
				{2.649, 1, 0.0985, 0.8762, 1.5},
				{2.395, 1, 0.3869, 0.2842, 1.5},
				{2.515, 1, 0.3869, 0.2842, 1.5},
				{2.655, 1, 0.3869, 0.2842, 1.5},
				{2.404, 1, 0.6625, 0.6108, 1.5},
				{2.524, 1, 0.6625, 0.6108, 1.5},
				{2.664, 1, 0.6625, 0.6108, 1.5},
				{2.408, 1, 0.2886, 0.3753, 1.5},
				{2.528, 1, 0.2886, 0.3753, 1.5},
				{2.668, 1, 0.2886, 0.3753, 1.5},
				{2.437, 1, 0.6765, 0.8373, 1.5},
				{2.557, 1, 0.6765, 0.8373, 1.5},
				{2.697, 1, 0.6765, 0.8373, 1.5},
				{2.442, 1, 0.4162, 0.4856, 1.5},
				{2.562, 1, 0.4162, 0.4856, 1.5},
				{2.702, 1, 0.4162, 0.4856, 1.5},
				{2.45, 1, 0.9033, 0.8469, 1.5},
				{2.57, 1, 0.9033, 0.8469, 1.5},
				{2.71, 1, 0.9033, 0.8469, 1.5},
				{2.462, 1, 0.2629, 0.7499, 1.5},
				{2.582, 1, 0.2629, 0.7499, 1.5},
				{2.722, 1, 0.2629, 0.7499, 1.5},
				{2.525, 1, 0.0934, 0.4428, 1.5},
				{2.645, 1, 0.0934, 0.4428, 1.5},
				{2.785, 1, 0.0934, 0.4428, 1.5},
				{2.525, 1, 0.7608, 0.8107, 1.5},
				{2.645, 1, 0.7608, 0.8107, 1.5},
				{2.785, 1, 0.7608, 0.8107, 1.5},
				{2.565, 1, 0.4668, 0.4761, 1.5},
				{2.685, 1, 0.4668, 0.4761, 1.5},
				{2.825, 1, 0.4668, 0.4761, 1.5},
				{2.57, 1, 0.4837, 0.7641, 1.5},
				{2.69, 1, 0.4837, 0.7641, 1.5},
				{2.83, 1, 0.4837, 0.7641, 1.5},
			},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "GeyserFlash",
			texture = "fx_glow",
			lifetime = {0.3, 0.3},
			size = {
				{0, 6, 0},
				{0.25, 26, 0},
				{1, 30, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.5, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			zoffset = 2,
			radial = false,
			ring_emit = {
				{1.315, 1, 0.6321, 0.1735, 2},
				{1.357, 1, 0.3013, 0.2467, 2},
				{1.361, 1, 0.4909, 0.245, 2},
				{1.37, 1, 0.7035, 0.255, 2},
				{1.373, 1, 0.9526, 0.2118, 2},
				{1.384, 1, 0.316, 0.2645, 2},
				{1.478, 1, 0.5882, 0.3432, 2},
				{1.514, 1, 0.8186, 0.4314, 2},
				{1.517, 1, 0.4217, 0.4375, 2},
				{1.522, 1, 0.0199, 0.4065, 2},
				{1.524, 1, 0.093, 0.405, 2},
				{1.549, 1, 0.3172, 0.4284, 2},
				{1.559, 1, 0.6554, 0.479, 2},
				{1.568, 1, 0.1583, 0.4987, 2},
				{1.569, 1, 0.8407, 0.4784, 2},
				{1.582, 1, 0.1535, 0.5242, 2},
				{1.586, 1, 0.9307, 0.5284, 2},
				{1.598, 1, 0.2695, 0.494, 2},
				{1.609, 1, 0.9107, 0.5561, 2},
				{1.612, 1, 0.9856, 0.553, 2},
				{1.634, 1, 0.6498, 0.6019, 2},
				{1.657, 1, 0.4452, 0.5825, 2},
				{1.712, 1, 0.4631, 0.6579, 2},
				{1.719, 1, 0.2724, 0.64, 2},
				{1.722, 1, 0.7521, 0.6503, 2},
				{1.733, 1, 0.5963, 0.6582, 2},
				{1.751, 1, 0.0887, 0.6869, 2},
				{1.761, 1, 0.7925, 0.741, 2},
				{1.763, 1, 0.1437, 0.7109, 2},
				{1.763, 1, 0.9887, 0.6947, 2},
				{1.77, 1, 0.0517, 0.7043, 2},
				{1.783, 1, 0.8816, 0.7223, 2},
				{1.79, 1, 0.4579, 0.7892, 2},
				{1.795, 1, 0.0684, 0.7635, 2},
				{1.796, 1, 0.4456, 0.7639, 2},
				{1.806, 1, 0.714, 0.7821, 2},
				{1.809, 1, 0.5593, 0.7885, 2},
				{1.812, 1, 0.161, 0.7962, 2},
				{1.823, 1, 0.0511, 0.8335, 2},
				{1.829, 1, 0.7708, 0.783, 2},
				{1.831, 1, 0.2823, 0.8189, 2},
				{1.839, 1, 0.9801, 0.8217, 2},
				{1.842, 1, 0.99, 0.7989, 2},
				{1.846, 1, 0.5545, 0.8234, 2},
				{1.847, 1, 0.5741, 0.8453, 2},
				{1.849, 1, 0.9898, 0.8071, 2},
				{1.856, 1, 0.5369, 0.8216, 2},
				{1.866, 1, 0.8387, 0.2621, 2},
				{1.878, 1, 0.6262, 0.8749, 2},
				{1.89, 1, 0.6206, 0.8755, 2},
				{1.893, 1, 0.7542, 0.1731, 2},
				{1.901, 1, 0.4458, 0.9212, 2},
				{1.903, 1, 0.3691, 0.9317, 2},
				{1.918, 1, 0.8701, 0.9324, 2},
				{1.919, 1, 0.3253, 0.9462, 2},
				{1.924, 1, 0.9362, 0.9408, 2},
				{1.934, 1, 0.9347, 0.4568, 2},
				{1.942, 1, 0.2281, 0.9646, 2},
				{1.953, 1, 0.249, 0.9562, 2},
				{2.015, 1, 0.2292, 0.256, 2},
				{2.025, 1, 0.1948, 0.3303, 2},
				{2.033, 1, 0.0149, 0.293, 2},
				{2.086, 1, 0.853, 0.5338, 2},
				{2.109, 1, 0.6377, 0.8684, 2},
				{2.117, 1, 0.4071, 0.4441, 2},
				{2.117, 1, 0.7917, 0.5286, 2},
				{2.117, 1, 0.3286, 0.3049, 2},
				{2.151, 1, 0.3948, 0.3457, 2},
				{2.155, 1, 0.0512, 0.7779, 2},
				{2.161, 1, 0.6009, 0.7362, 2},
				{2.203, 1, 0.1046, 0.6806, 2},
				{2.213, 1, 0.465, 0.8843, 2},
				{2.215, 1, 0.2578, 0.626, 2},
				{2.218, 1, 0.676, 0.6992, 2},
				{2.229, 1, 0.8448, 0.8404, 2},
				{2.232, 1, 0.8013, 0.8388, 2},
				{2.235, 1, 0.6787, 0.6227, 2},
				{2.244, 1, 0.0376, 0.6434, 2},
				{2.26, 1, 0.5812, 0.9485, 2},
				{2.266, 1, 0.7521, 0.2986, 2},
				{2.266, 1, 0.9445, 0.7775, 2},
				{2.278, 1, 0.8817, 0.7292, 2},
				{2.352, 1, 0.7304, 0.7476, 2},
				{2.372, 1, 0.8868, 0.9139, 2},
				{2.389, 1, 0.0985, 0.8762, 2},
				{2.395, 1, 0.3869, 0.2842, 2},
				{2.404, 1, 0.6625, 0.6108, 2},
				{2.408, 1, 0.2886, 0.3753, 2},
				{2.437, 1, 0.6765, 0.8373, 2},
				{2.442, 1, 0.4162, 0.4856, 2},
				{2.45, 1, 0.9033, 0.8469, 2},
				{2.462, 1, 0.2629, 0.7499, 2},
				{2.525, 1, 0.0934, 0.4428, 2},
				{2.525, 1, 0.7608, 0.8107, 2},
				{2.565, 1, 0.4668, 0.4761, 2},
				{2.57, 1, 0.4837, 0.7641, 2},
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
			name = "GeyserRocks",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {30, 30},
			speed = {40, 80},
			drag = 0.4,
			accel = {0, -150, 0},
			lifetime = {0.8, 1.3},
			size = {
				{0, 2.2, 0.8},
				{1, 1.8, 0.6},
			},
			color = {
				{
					0,
					{128, 118, 106},
				},
				{
					1,
					{100, 92, 82},
				},
			},
			rotation = {0, 360},
			rot_speed = {-400, 400},
			radial = false,
			ring_emit = {
				{1.315, 5, 0.6321, 0.1735, 0.6},
				{1.357, 5, 0.3013, 0.2467, 0.6},
				{1.361, 5, 0.4909, 0.245, 0.6},
				{1.37, 5, 0.7035, 0.255, 0.6},
				{1.373, 5, 0.9526, 0.2118, 0.6},
				{1.384, 5, 0.316, 0.2645, 0.6},
				{1.478, 5, 0.5882, 0.3432, 0.6},
				{1.514, 5, 0.8186, 0.4314, 0.6},
				{1.517, 5, 0.4217, 0.4375, 0.6},
				{1.522, 5, 0.0199, 0.4065, 0.6},
				{1.524, 5, 0.093, 0.405, 0.6},
				{1.549, 5, 0.3172, 0.4284, 0.6},
				{1.559, 5, 0.6554, 0.479, 0.6},
				{1.568, 5, 0.1583, 0.4987, 0.6},
				{1.569, 5, 0.8407, 0.4784, 0.6},
				{1.582, 5, 0.1535, 0.5242, 0.6},
				{1.586, 5, 0.9307, 0.5284, 0.6},
				{1.598, 5, 0.2695, 0.494, 0.6},
				{1.609, 5, 0.9107, 0.5561, 0.6},
				{1.612, 5, 0.9856, 0.553, 0.6},
				{1.634, 5, 0.6498, 0.6019, 0.6},
				{1.657, 5, 0.4452, 0.5825, 0.6},
				{1.712, 5, 0.4631, 0.6579, 0.6},
				{1.719, 5, 0.2724, 0.64, 0.6},
				{1.722, 5, 0.7521, 0.6503, 0.6},
				{1.733, 5, 0.5963, 0.6582, 0.6},
				{1.751, 5, 0.0887, 0.6869, 0.6},
				{1.761, 5, 0.7925, 0.741, 0.6},
				{1.763, 5, 0.1437, 0.7109, 0.6},
				{1.763, 5, 0.9887, 0.6947, 0.6},
				{1.77, 5, 0.0517, 0.7043, 0.6},
				{1.783, 5, 0.8816, 0.7223, 0.6},
				{1.79, 5, 0.4579, 0.7892, 0.6},
				{1.795, 5, 0.0684, 0.7635, 0.6},
				{1.796, 5, 0.4456, 0.7639, 0.6},
				{1.806, 5, 0.714, 0.7821, 0.6},
				{1.809, 5, 0.5593, 0.7885, 0.6},
				{1.812, 5, 0.161, 0.7962, 0.6},
				{1.823, 5, 0.0511, 0.8335, 0.6},
				{1.829, 5, 0.7708, 0.783, 0.6},
				{1.831, 5, 0.2823, 0.8189, 0.6},
				{1.839, 5, 0.9801, 0.8217, 0.6},
				{1.842, 5, 0.99, 0.7989, 0.6},
				{1.846, 5, 0.5545, 0.8234, 0.6},
				{1.847, 5, 0.5741, 0.8453, 0.6},
				{1.849, 5, 0.9898, 0.8071, 0.6},
				{1.856, 5, 0.5369, 0.8216, 0.6},
				{1.866, 4, 0.8387, 0.2621, 0.6},
				{1.878, 5, 0.6262, 0.8749, 0.6},
				{1.89, 5, 0.6206, 0.8755, 0.6},
				{1.893, 4, 0.7542, 0.1731, 0.6},
				{1.901, 5, 0.4458, 0.9212, 0.6},
				{1.903, 5, 0.3691, 0.9317, 0.6},
				{1.918, 5, 0.8701, 0.9324, 0.6},
				{1.919, 5, 0.3253, 0.9462, 0.6},
				{1.924, 5, 0.9362, 0.9408, 0.6},
				{1.934, 4, 0.9347, 0.4568, 0.6},
				{1.942, 5, 0.2281, 0.9646, 0.6},
				{1.953, 5, 0.249, 0.9562, 0.6},
				{2.015, 4, 0.2292, 0.256, 0.6},
				{2.025, 4, 0.1948, 0.3303, 0.6},
				{2.033, 4, 0.0149, 0.293, 0.6},
				{2.086, 4, 0.853, 0.5338, 0.6},
				{2.109, 4, 0.6377, 0.8684, 0.6},
				{2.117, 4, 0.4071, 0.4441, 0.6},
				{2.117, 4, 0.7917, 0.5286, 0.6},
				{2.117, 4, 0.3286, 0.3049, 0.6},
				{2.151, 3, 0.3948, 0.3457, 0.6},
				{2.155, 4, 0.0512, 0.7779, 0.6},
				{2.161, 3, 0.6009, 0.7362, 0.6},
				{2.203, 4, 0.1046, 0.6806, 0.6},
				{2.213, 4, 0.465, 0.8843, 0.6},
				{2.215, 4, 0.2578, 0.626, 0.6},
				{2.218, 4, 0.676, 0.6992, 0.6},
				{2.229, 4, 0.8448, 0.8404, 0.6},
				{2.232, 4, 0.8013, 0.8388, 0.6},
				{2.235, 3, 0.6787, 0.6227, 0.6},
				{2.244, 4, 0.0376, 0.6434, 0.6},
				{2.26, 4, 0.5812, 0.9485, 0.6},
				{2.266, 3, 0.7521, 0.2986, 0.6},
				{2.266, 4, 0.9445, 0.7775, 0.6},
				{2.278, 4, 0.8817, 0.7292, 0.6},
				{2.352, 3, 0.7304, 0.7476, 0.6},
				{2.372, 4, 0.8868, 0.9139, 0.6},
				{2.389, 4, 0.0985, 0.8762, 0.6},
				{2.395, 3, 0.3869, 0.2842, 0.6},
				{2.404, 3, 0.6625, 0.6108, 0.6},
				{2.408, 3, 0.2886, 0.3753, 0.6},
				{2.437, 3, 0.6765, 0.8373, 0.6},
				{2.442, 3, 0.4162, 0.4856, 0.6},
				{2.45, 3, 0.9033, 0.8469, 0.6},
				{2.462, 3, 0.2629, 0.7499, 0.6},
				{2.525, 3, 0.0934, 0.4428, 0.6},
				{2.525, 3, 0.7608, 0.8107, 0.6},
				{2.565, 3, 0.4668, 0.4761, 0.6},
				{2.57, 3, 0.4837, 0.7641, 0.6},
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
			name = "GeyserSteam",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {40, 40},
			speed = {10, 20},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {0.8, 1.2},
			size = {
				{0, 8, 2},
				{1, 20, 3},
			},
			transparency = {
				{0, 0.45, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			radial = false,
			ring_emit = {
				{1.315, 2, 0.6321, 0.1735, 6},
				{1.357, 2, 0.3013, 0.2467, 6},
				{1.361, 2, 0.4909, 0.245, 6},
				{1.37, 2, 0.7035, 0.255, 6},
				{1.373, 2, 0.9526, 0.2118, 6},
				{1.384, 2, 0.316, 0.2645, 6},
				{1.478, 2, 0.5882, 0.3432, 6},
				{1.514, 2, 0.8186, 0.4314, 6},
				{1.517, 2, 0.4217, 0.4375, 6},
				{1.522, 2, 0.0199, 0.4065, 6},
				{1.524, 2, 0.093, 0.405, 6},
				{1.549, 2, 0.3172, 0.4284, 6},
				{1.559, 2, 0.6554, 0.479, 6},
				{1.568, 2, 0.1583, 0.4987, 6},
				{1.569, 2, 0.8407, 0.4784, 6},
				{1.582, 2, 0.1535, 0.5242, 6},
				{1.586, 2, 0.9307, 0.5284, 6},
				{1.598, 2, 0.2695, 0.494, 6},
				{1.609, 2, 0.9107, 0.5561, 6},
				{1.612, 2, 0.9856, 0.553, 6},
				{1.634, 2, 0.6498, 0.6019, 6},
				{1.657, 2, 0.4452, 0.5825, 6},
				{1.712, 2, 0.4631, 0.6579, 6},
				{1.719, 2, 0.2724, 0.64, 6},
				{1.722, 2, 0.7521, 0.6503, 6},
				{1.733, 2, 0.5963, 0.6582, 6},
				{1.751, 2, 0.0887, 0.6869, 6},
				{1.761, 2, 0.7925, 0.741, 6},
				{1.763, 2, 0.1437, 0.7109, 6},
				{1.763, 2, 0.9887, 0.6947, 6},
				{1.77, 2, 0.0517, 0.7043, 6},
				{1.783, 2, 0.8816, 0.7223, 6},
				{1.79, 2, 0.4579, 0.7892, 6},
				{1.795, 2, 0.0684, 0.7635, 6},
				{1.796, 2, 0.4456, 0.7639, 6},
				{1.806, 2, 0.714, 0.7821, 6},
				{1.809, 2, 0.5593, 0.7885, 6},
				{1.812, 2, 0.161, 0.7962, 6},
				{1.823, 2, 0.0511, 0.8335, 6},
				{1.829, 2, 0.7708, 0.783, 6},
				{1.831, 2, 0.2823, 0.8189, 6},
				{1.839, 2, 0.9801, 0.8217, 6},
				{1.842, 2, 0.99, 0.7989, 6},
				{1.846, 2, 0.5545, 0.8234, 6},
				{1.847, 2, 0.5741, 0.8453, 6},
				{1.849, 2, 0.9898, 0.8071, 6},
				{1.856, 2, 0.5369, 0.8216, 6},
				{1.866, 1, 0.8387, 0.2621, 6},
				{1.878, 2, 0.6262, 0.8749, 6},
				{1.89, 2, 0.6206, 0.8755, 6},
				{1.893, 1, 0.7542, 0.1731, 6},
				{1.901, 2, 0.4458, 0.9212, 6},
				{1.903, 2, 0.3691, 0.9317, 6},
				{1.918, 2, 0.8701, 0.9324, 6},
				{1.919, 2, 0.3253, 0.9462, 6},
				{1.924, 2, 0.9362, 0.9408, 6},
				{1.934, 1, 0.9347, 0.4568, 6},
				{1.942, 2, 0.2281, 0.9646, 6},
				{1.953, 2, 0.249, 0.9562, 6},
				{2.015, 1, 0.2292, 0.256, 6},
				{2.025, 1, 0.1948, 0.3303, 6},
				{2.033, 1, 0.0149, 0.293, 6},
				{2.086, 1, 0.853, 0.5338, 6},
				{2.109, 1, 0.6377, 0.8684, 6},
				{2.117, 1, 0.4071, 0.4441, 6},
				{2.117, 1, 0.7917, 0.5286, 6},
				{2.117, 1, 0.3286, 0.3049, 6},
				{2.151, 1, 0.3948, 0.3457, 6},
				{2.155, 1, 0.0512, 0.7779, 6},
				{2.161, 1, 0.6009, 0.7362, 6},
				{2.203, 1, 0.1046, 0.6806, 6},
				{2.213, 1, 0.465, 0.8843, 6},
				{2.215, 1, 0.2578, 0.626, 6},
				{2.218, 1, 0.676, 0.6992, 6},
				{2.229, 1, 0.8448, 0.8404, 6},
				{2.232, 1, 0.8013, 0.8388, 6},
				{2.235, 1, 0.6787, 0.6227, 6},
				{2.244, 1, 0.0376, 0.6434, 6},
				{2.26, 1, 0.5812, 0.9485, 6},
				{2.266, 1, 0.7521, 0.2986, 6},
				{2.266, 1, 0.9445, 0.7775, 6},
				{2.278, 1, 0.8817, 0.7292, 6},
				{2.352, 1, 0.7304, 0.7476, 6},
				{2.372, 1, 0.8868, 0.9139, 6},
				{2.389, 1, 0.0985, 0.8762, 6},
				{2.395, 1, 0.3869, 0.2842, 6},
				{2.404, 1, 0.6625, 0.6108, 6},
				{2.408, 1, 0.2886, 0.3753, 6},
				{2.437, 1, 0.6765, 0.8373, 6},
				{2.442, 1, 0.4162, 0.4856, 6},
				{2.45, 1, 0.9033, 0.8469, 6},
				{2.462, 1, 0.2629, 0.7499, 6},
				{2.525, 1, 0.0934, 0.4428, 6},
				{2.525, 1, 0.7608, 0.8107, 6},
				{2.565, 1, 0.4668, 0.4761, 6},
				{2.57, 1, 0.4837, 0.7641, 6},
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
			name = "GeyserScorch",
			texture = "pb_vein_cracks",
			lifetime = {4.6, 4.6},
			rotation = {0, 360},
			size = {
				{0, 6, 0},
				{0.03, 22, 4},
				{1, 23, 4},
			},
			transparency = {
				{0, 1, 0},
				{0.02, 0.2, 0},
				{0.85, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{130, 245, 240},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 0.9,
			radial = false,
			ring_emit = {
				{1.315, 1, 0.6321, 0.1735, 0.26},
				{1.357, 1, 0.3013, 0.2467, 0.26},
				{1.361, 1, 0.4909, 0.245, 0.26},
				{1.37, 1, 0.7035, 0.255, 0.26},
				{1.373, 1, 0.9526, 0.2118, 0.26},
				{1.384, 1, 0.316, 0.2645, 0.26},
				{1.478, 1, 0.5882, 0.3432, 0.26},
				{1.514, 1, 0.8186, 0.4314, 0.26},
				{1.517, 1, 0.4217, 0.4375, 0.26},
				{1.522, 1, 0.0199, 0.4065, 0.26},
				{1.524, 1, 0.093, 0.405, 0.26},
				{1.549, 1, 0.3172, 0.4284, 0.26},
				{1.559, 1, 0.6554, 0.479, 0.26},
				{1.568, 1, 0.1583, 0.4987, 0.26},
				{1.569, 1, 0.8407, 0.4784, 0.26},
				{1.582, 1, 0.1535, 0.5242, 0.26},
				{1.586, 1, 0.9307, 0.5284, 0.26},
				{1.598, 1, 0.2695, 0.494, 0.26},
				{1.609, 1, 0.9107, 0.5561, 0.26},
				{1.612, 1, 0.9856, 0.553, 0.26},
				{1.634, 1, 0.6498, 0.6019, 0.26},
				{1.657, 1, 0.4452, 0.5825, 0.26},
				{1.712, 1, 0.4631, 0.6579, 0.26},
				{1.719, 1, 0.2724, 0.64, 0.26},
				{1.722, 1, 0.7521, 0.6503, 0.26},
				{1.733, 1, 0.5963, 0.6582, 0.26},
				{1.751, 1, 0.0887, 0.6869, 0.26},
				{1.761, 1, 0.7925, 0.741, 0.26},
				{1.763, 1, 0.1437, 0.7109, 0.26},
				{1.763, 1, 0.9887, 0.6947, 0.26},
				{1.77, 1, 0.0517, 0.7043, 0.26},
				{1.783, 1, 0.8816, 0.7223, 0.26},
				{1.79, 1, 0.4579, 0.7892, 0.26},
				{1.795, 1, 0.0684, 0.7635, 0.26},
				{1.796, 1, 0.4456, 0.7639, 0.26},
				{1.806, 1, 0.714, 0.7821, 0.26},
				{1.809, 1, 0.5593, 0.7885, 0.26},
				{1.812, 1, 0.161, 0.7962, 0.26},
				{1.823, 1, 0.0511, 0.8335, 0.26},
				{1.829, 1, 0.7708, 0.783, 0.26},
				{1.831, 1, 0.2823, 0.8189, 0.26},
				{1.839, 1, 0.9801, 0.8217, 0.26},
				{1.842, 1, 0.99, 0.7989, 0.26},
				{1.846, 1, 0.5545, 0.8234, 0.26},
				{1.847, 1, 0.5741, 0.8453, 0.26},
				{1.849, 1, 0.9898, 0.8071, 0.26},
				{1.856, 1, 0.5369, 0.8216, 0.26},
				{1.878, 1, 0.6262, 0.8749, 0.26},
				{1.89, 1, 0.6206, 0.8755, 0.26},
				{1.901, 1, 0.4458, 0.9212, 0.26},
				{1.903, 1, 0.3691, 0.9317, 0.26},
				{1.918, 1, 0.8701, 0.9324, 0.26},
				{1.919, 1, 0.3253, 0.9462, 0.26},
				{1.924, 1, 0.9362, 0.9408, 0.26},
				{1.942, 1, 0.2281, 0.9646, 0.26},
				{1.953, 1, 0.249, 0.9562, 0.26},
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
			name = "CrackFlames",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			zdist = {
				r = {0.05, 1},
				h = {0.3, 0.8},
				area = true,
			},
			direction = "Top",
			spread = {10, 10},
			speed = {4, 10},
			accel = {0, 8, 0},
			lifetime = {0.4, 0.7},
			size = {
				{0, 2.5, 0.8},
				{0.3, 7, 1.5},
				{1, 2, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {-10, 10},
			radial = false,
			zstream = {
				{1.35, 1.95, 50, 150},
				{1.95, 4.35, 150, 150},
				{4.35, 5.15, 150, 0},
			},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ZoneEmbers",
			texture = "fx_spark002",
			zdist = {
				r = {0, 1},
				h = {0.5, 6},
				area = true,
			},
			direction = "Top",
			spread = {25, 25},
			speed = {8, 18},
			drag = 1,
			accel = {0, 5, 0},
			lifetime = {1, 1.8},
			size = {
				{0, 0, 0},
				{0.08, 1.76, 0},
				{0.22, 0.77, 0},
				{0.38, 1.87, 0},
				{0.55, 0.66, 0},
				{0.72, 1.54, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.9,
			rotation = {0, 45},
			radial = false,
			zstream = {
				{1.35, 4.85, 100, 100},
				{4.85, 5.75, 100, 0},
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
			name = "PlateDust",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {60, 60},
			speed = {8, 18},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {1, 1.6},
			size = {
				{0, 10, 2},
				{1, 26, 4},
			},
			transparency = {
				{0, 0.45, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			radial = false,
			ring_emit = {
				{1.842, 2, 0.0504, 0.8031, 7},
				{1.927, 2, 0.0539, 0.9085, 7},
				{1.84, 2, 0.0686, 0.7995, 7},
				{1.97, 2, 0.0893, 0.9631, 7},
				{1.47, 2, 0.1194, 0.3371, 7},
				{1.736, 2, 0.1661, 0.6706, 7},
				{1.4, 2, 0.1668, 0.2501, 7},
				{1.469, 2, 0.1929, 0.3364, 7},
				{1.888, 2, 0.2272, 0.8605, 7},
				{1.478, 2, 0.2365, 0.3481, 7},
				{1.838, 2, 0.2624, 0.7972, 7},
				{1.54, 2, 0.3526, 0.4249, 7},
				{1.734, 2, 0.3632, 0.6679, 7},
				{1.898, 2, 0.3699, 0.8724, 7},
				{1.77, 2, 0.3766, 0.7126, 7},
				{1.493, 2, 0.3819, 0.3664, 7},
				{1.659, 2, 0.3826, 0.5738, 7},
				{1.86, 2, 0.3854, 0.8245, 7},
				{1.82, 2, 0.3872, 0.7746, 7},
				{1.359, 2, 0.4296, 0.1982, 7},
				{1.919, 2, 0.4319, 0.899, 7},
				{1.388, 2, 0.4499, 0.2351, 7},
				{1.907, 2, 0.4506, 0.8838, 7},
				{1.717, 2, 0.4775, 0.6467, 7},
				{1.688, 2, 0.4843, 0.6098, 7},
				{1.851, 2, 0.5012, 0.8133, 7},
				{1.635, 2, 0.518, 0.5432, 7},
				{1.75, 2, 0.6151, 0.6872, 7},
				{1.995, 2, 0.7121, 0.9939, 7},
				{1.996, 2, 0.739, 0.9944, 7},
				{1.521, 2, 0.7486, 0.4014, 7},
				{1.702, 2, 0.7843, 0.6269, 7},
				{1.815, 2, 0.7853, 0.7688, 7},
				{1.473, 2, 0.7929, 0.3415, 7},
				{1.809, 2, 0.8028, 0.7611, 7},
				{1.398, 2, 0.8056, 0.2478, 7},
				{1.792, 2, 0.8815, 0.7395, 7},
				{1.635, 2, 0.8825, 0.5439, 7},
				{1.854, 2, 0.8983, 0.8176, 7},
				{1.996, 2, 0.9018, 0.9949, 7},
				{1.839, 2, 0.9437, 0.7993, 7},
				{1.797, 2, 0.9542, 0.7457, 7},
				{1.354, 2, 0.9846, 0.1924, 7},
				{1.799, 2, 0.9914, 0.749, 7},
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
			name = "RuptureDust",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 12,
			spread = {10, 6},
			speed = {30, 60},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {1.4, 2},
			size = {
				{0, 14, 3},
				{1, 38, 5},
			},
			transparency = {
				{0, 0.4, 0},
				{0.35, 0.58, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			ring_emit = {
				{1.91, 1, 0, 0.97, 9},
				{1.91, 1, 0.025, 0.97, 9},
				{1.91, 1, 0.05, 0.97, 9},
				{1.91, 1, 0.075, 0.97, 9},
				{1.91, 1, 0.1, 0.97, 9},
				{1.91, 1, 0.125, 0.97, 9},
				{1.91, 1, 0.15, 0.97, 9},
				{1.91, 1, 0.175, 0.97, 9},
				{1.91, 1, 0.2, 0.97, 9},
				{1.91, 1, 0.225, 0.97, 9},
				{1.91, 1, 0.25, 0.97, 9},
				{1.91, 1, 0.275, 0.97, 9},
				{1.91, 1, 0.3, 0.97, 9},
				{1.91, 1, 0.325, 0.97, 9},
				{1.91, 1, 0.35, 0.97, 9},
				{1.91, 1, 0.375, 0.97, 9},
				{1.91, 1, 0.4, 0.97, 9},
				{1.91, 1, 0.425, 0.97, 9},
				{1.91, 1, 0.45, 0.97, 9},
				{1.91, 1, 0.475, 0.97, 9},
				{1.91, 1, 0.5, 0.97, 9},
				{1.91, 1, 0.525, 0.97, 9},
				{1.91, 1, 0.55, 0.97, 9},
				{1.91, 1, 0.575, 0.97, 9},
				{1.91, 1, 0.6, 0.97, 9},
				{1.91, 1, 0.625, 0.97, 9},
				{1.91, 1, 0.65, 0.97, 9},
				{1.91, 1, 0.675, 0.97, 9},
				{1.91, 1, 0.7, 0.97, 9},
				{1.91, 1, 0.725, 0.97, 9},
				{1.91, 1, 0.75, 0.97, 9},
				{1.91, 1, 0.775, 0.97, 9},
				{1.91, 1, 0.8, 0.97, 9},
				{1.91, 1, 0.825, 0.97, 9},
				{1.91, 1, 0.85, 0.97, 9},
				{1.91, 1, 0.875, 0.97, 9},
				{1.91, 1, 0.9, 0.97, 9},
				{1.91, 1, 0.925, 0.97, 9},
				{1.91, 1, 0.95, 0.97, 9},
				{1.91, 1, 0.975, 0.97, 9},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "PreGlow",
			texture = "fx_glow",
			at = {0, -0.3},
			lifetime = {0.6, 0.6},
			size = {
				{0, 20, 0},
				{1, 75, 0},
			},
			transparency = {
				{0, 0.85, 0},
				{0.8, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			ring_emit = {
				{2.2, 1, 0, 0, 0.3},
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
			name = "PreRumble",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			at = {0, -0.3},
			direction = "Top",
			spread = {50, 50},
			speed = {6, 14},
			drag = 1.5,
			lifetime = {0.8, 1.2},
			size = {
				{0, 6, 1},
				{1, 16, 2},
			},
			transparency = {
				{0, 0.5, 0},
				{0.4, 0.64, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			radial = false,
			ring_emit = {
				{2.263, 1, 0.9594, 0.0889, 4},
				{2.291, 1, 0.6364, 0.0266, 4},
				{2.301, 1, 0.8989, 0.0773, 4},
				{2.336, 1, 0.8751, 0.0884, 4},
				{2.377, 1, 0.7779, 0.0642, 4},
				{2.381, 1, 0.6178, 0.1142, 4},
				{2.382, 1, 0.9523, 0.0952, 4},
				{2.428, 1, 0.4946, 0.1027, 4},
				{2.428, 1, 0.8349, 0.1051, 4},
				{2.432, 1, 0.234, 0.1102, 4},
				{2.489, 1, 0.1877, 0.0273, 4},
				{2.506, 1, 0.3684, 0.0846, 4},
				{2.525, 1, 0.6946, 0.1194, 4},
				{2.569, 1, 0.9897, 0.0697, 4},
				{2.571, 1, 0.2693, 0.1117, 4},
				{2.607, 1, 0.2591, 0.065, 4},
				{2.635, 1, 0.7238, 0.0921, 4},
				{2.638, 1, 0.1207, 0.118, 4},
				{2.666, 1, 0.8095, 0.0601, 4},
				{2.678, 1, 0.6939, 0.0951, 4},
				{2.688, 1, 0.7485, 0.0876, 4},
				{2.694, 1, 0.4788, 0.0598, 4},
				{2.696, 1, 0.7611, 0.0886, 4},
				{2.707, 1, 0.8473, 0.0776, 4},
			},
			accel = {0, 0, 0},
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
			name = "MountainFlash",
			texture = "fx_glow",
			at = {0, -0.3},
			lifetime = {0.4, 0.4},
			size = {
				{0, 30, 0},
				{0.2, 240, 0},
				{1, 270, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			brightness = 1.8,
			zoffset = 4,
			ring_emit = {
				{2.75, 1, 0, 0, 40},
			},
			bill = true,
			rel = "r",
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "MountainStar",
			texture = "kk_star_09",
			at = {0, -0.3},
			lifetime = {0.4, 0.4},
			rotation = {0, 90},
			size = {
				{0, 30, 0},
				{0.15, 360, 0},
				{1, 40, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			brightness = 2.2,
			zoffset = 5,
			ring_emit = {
				{2.8, 1, 0, 0, 50},
			},
			bill = true,
			rel = "r",
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
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "MountainRing",
			texture = "kk_circle_02",
			at = {0, -0.3},
			rel = "r",
			lifetime = {0.6, 0.6},
			size = {
				{0, 40.68, 0},
				{1, 457.65, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.5, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			ring_emit = {
				{2.75, 1, 0, 0, 0.23},
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
			name = "MountainDust",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			at = {0, -0.3},
			direction = "Front",
			pitch = 20,
			spread = {14, 10},
			speed = {50, 100},
			drag = 2.2,
			accel = {0, 3, 0},
			lifetime = {1.3, 1.9},
			size = {
				{0, 16, 3},
				{1, 44, 5},
			},
			transparency = {
				{0, 0.35, 0},
				{0.3, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{160, 150, 136},
				},
				{
					0.5,
					{138, 128, 116},
				},
				{
					1,
					{112, 104, 94},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -1,
			ring_emit = {
				{2.78, 1, 0, 0.12, 10},
				{2.78, 1, 0.0333, 0.12, 10},
				{2.78, 1, 0.0667, 0.12, 10},
				{2.78, 1, 0.1, 0.12, 10},
				{2.78, 1, 0.1333, 0.12, 10},
				{2.78, 1, 0.1667, 0.12, 10},
				{2.78, 1, 0.2, 0.12, 10},
				{2.78, 1, 0.2333, 0.12, 10},
				{2.78, 1, 0.2667, 0.12, 10},
				{2.78, 1, 0.3, 0.12, 10},
				{2.78, 1, 0.3333, 0.12, 10},
				{2.78, 1, 0.3667, 0.12, 10},
				{2.78, 1, 0.4, 0.12, 10},
				{2.78, 1, 0.4333, 0.12, 10},
				{2.78, 1, 0.4667, 0.12, 10},
				{2.78, 1, 0.5, 0.12, 10},
				{2.78, 1, 0.5333, 0.12, 10},
				{2.78, 1, 0.5667, 0.12, 10},
				{2.78, 1, 0.6, 0.12, 10},
				{2.78, 1, 0.6333, 0.12, 10},
				{2.78, 1, 0.6667, 0.12, 10},
				{2.78, 1, 0.7, 0.12, 10},
				{2.78, 1, 0.7333, 0.12, 10},
				{2.78, 1, 0.7667, 0.12, 10},
				{2.78, 1, 0.8, 0.12, 10},
				{2.78, 1, 0.8333, 0.12, 10},
				{2.78, 1, 0.8667, 0.12, 10},
				{2.78, 1, 0.9, 0.12, 10},
				{2.78, 1, 0.9333, 0.12, 10},
				{2.78, 1, 0.9667, 0.12, 10},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "MountainFire",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			at = {0, -0.3},
			direction = "Front",
			pitch = 25,
			spread = {25, 15},
			speed = {40, 80},
			drag = 2.5,
			lifetime = {0.5, 0.8},
			size = {
				{0, 8, 2},
				{0.3, 18, 3},
				{1, 8, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			ring_emit = {
				{2.75, 2, 0, 0.1, 4},
				{2.75, 2, 0.0417, 0.1, 4},
				{2.75, 2, 0.0833, 0.1, 4},
				{2.75, 2, 0.125, 0.1, 4},
				{2.75, 2, 0.1667, 0.1, 4},
				{2.75, 2, 0.2083, 0.1, 4},
				{2.75, 2, 0.25, 0.1, 4},
				{2.75, 2, 0.2917, 0.1, 4},
				{2.75, 2, 0.3333, 0.1, 4},
				{2.75, 2, 0.375, 0.1, 4},
				{2.75, 2, 0.4167, 0.1, 4},
				{2.75, 2, 0.4583, 0.1, 4},
				{2.75, 2, 0.5, 0.1, 4},
				{2.75, 2, 0.5417, 0.1, 4},
				{2.75, 2, 0.5833, 0.1, 4},
				{2.75, 2, 0.625, 0.1, 4},
				{2.75, 2, 0.6667, 0.1, 4},
				{2.75, 2, 0.7083, 0.1, 4},
				{2.75, 2, 0.75, 0.1, 4},
				{2.75, 2, 0.7917, 0.1, 4},
				{2.75, 2, 0.8333, 0.1, 4},
				{2.75, 2, 0.875, 0.1, 4},
				{2.75, 2, 0.9167, 0.1, 4},
				{2.75, 2, 0.9583, 0.1, 4},
			},
			accel = {0, 0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "MountainTongues",
			texture = "fx_aura_tongue_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			at = {0, -0.3},
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {25, 25},
			speed = {80, 140},
			drag = 3,
			lifetime = {0.35, 0.55},
			size = {
				{0, 6, 1},
				{0.4, 16, 3},
				{1, 4, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.6, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			radial = false,
			ring_emit = {
				{2.75, 2, 0, 0.12, 2},
				{2.75, 2, 0.0625, 0.12, 2},
				{2.75, 2, 0.125, 0.12, 2},
				{2.75, 2, 0.1875, 0.12, 2},
				{2.75, 2, 0.25, 0.12, 2},
				{2.75, 2, 0.3125, 0.12, 2},
				{2.75, 2, 0.375, 0.12, 2},
				{2.75, 2, 0.4375, 0.12, 2},
				{2.75, 2, 0.5, 0.12, 2},
				{2.75, 2, 0.5625, 0.12, 2},
				{2.75, 2, 0.625, 0.12, 2},
				{2.75, 2, 0.6875, 0.12, 2},
				{2.75, 2, 0.75, 0.12, 2},
				{2.75, 2, 0.8125, 0.12, 2},
				{2.75, 2, 0.875, 0.12, 2},
				{2.75, 2, 0.9375, 0.12, 2},
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
			name = "CrystalGlow",
			texture = "fx_glow",
			at = {0, -0.3},
			zdist = {
				r = {0, 0.03},
				h = {15, 100},
				area = false,
			},
			lifetime = {0.5, 0.8},
			size = {
				{0, 34, 6},
				{1, 42, 6},
			},
			transparency = {
				{0, 0.86, 0},
				{0.5, 0.74, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			radial = false,
			zstream = {
				{2.95, 3.75, 10, 10},
				{3.75, 4.35, 10, 30},
			},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CrystalGlints",
			texture = "kk_star_09",
			at = {0, -0.3},
			zdist = {
				r = {0, 0.1},
				h = {10, 105},
				area = false,
			},
			lifetime = {0.3, 0.5},
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
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			rotation = {0, 45},
			zoffset = 8,
			radial = false,
			zstream = {
				{3.05, 3.75, 6, 6},
				{3.75, 4.35, 6, 26},
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
			name = "CrystalCracks",
			texture = "pb_vein_cracks",
			at = {0, -0.3},
			zdist = {
				r = {0, 0.05},
				h = {10, 100},
				area = false,
			},
			lifetime = {0.25, 0.45},
			size = {
				{0, 4, 0},
				{0.15, 12, 3},
				{1, 13, 3},
			},
			transparency = {
				{0, 0.6, 0},
				{0.2, 0.15, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			rotation = {0, 360},
			zoffset = 8,
			radial = false,
			zstream = {
				{3.45, 4.35, 6, 40},
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
			name = "BaseFlames",
			texture = "fx_fire_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			at = {0, -0.3},
			zdist = {
				r = {0.1, 0.2},
				h = {0.3, 1},
				area = false,
			},
			direction = "Top",
			spread = {12, 12},
			speed = {8, 16},
			accel = {0, 9, 0},
			lifetime = {0.45, 0.75},
			size = {
				{0, 4, 1},
				{0.3, 10, 2},
				{1, 3, 0},
			},
			transparency = {
				{0, 0.12, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{175, 255, 250},
				},
				{
					0.3,
					{100, 236, 230},
				},
				{
					0.65,
					{60, 185, 186},
				},
				{
					1,
					{39, 121, 127},
				},
			},
			light_emission = 1,
			brightness = 1.45,
			rotation = {-15, 15},
			radial = false,
			zstream = {
				{2.85, 4.35, 70, 70},
			},
			drag = 0,
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EnergyRise",
			texture = "fx_spark002",
			at = {0, -0.3},
			zdist = {
				r = {0, 0.22},
				h = {1, 10},
				area = false,
			},
			direction = "Top",
			spread = {10, 10},
			speed = {20, 40},
			drag = 0.5,
			lifetime = {0.8, 1.3},
			size = {
				{0, 0, 0},
				{0.08, 1.92, 0},
				{0.22, 0.84, 0},
				{0.38, 2.04, 0},
				{0.55, 0.72, 0},
				{0.72, 1.68, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 1.9,
			rotation = {0, 45},
			radial = false,
			zstream = {
				{2.95, 4.35, 60, 120},
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
			name = "ChargeRings",
			texture = "kk_circle_02",
			at = {0, -0.3},
			rel = "r",
			lifetime = {0.4, 0.4},
			size = {
				{0, 254.25, 0},
				{1, 30.51, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.45, 0},
				{0.9, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			ring_emit = {
				{3.1, 1, 0, 0, 0.24},
				{3.4, 1, 0, 0, 0.24},
				{3.7, 1, 0, 0, 0.24},
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
			name = "DetFlash",
			texture = "fx_glow",
			at = {0, -0.3},
			lifetime = {0.4, 0.4},
			size = {
				{0, 40, 0},
				{0.15, 300, 0},
				{1, 330, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{0.35, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{225, 255, 252},
				},
				{
					1,
					{94, 229, 224},
				},
			},
			brightness = 1.8,
			zoffset = 4,
			ring_emit = {
				{4.35, 1, 0, 0, 55},
			},
			bill = true,
			rel = "r",
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
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
			at = {0, -0.3},
			lifetime = {0.45, 0.45},
			rotation = {0, 90},
			size = {
				{0, 60, 0},
				{0.15, 480, 0},
				{1, 60, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			brightness = 2.2,
			zoffset = 5,
			ring_emit = {
				{4.35, 1, 0, 0, 60},
			},
			bill = true,
			rel = "r",
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
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "DetRing",
			texture = "kk_circle_02",
			at = {0, -0.3},
			rel = "r",
			lifetime = {0.7, 0.7},
			size = {
				{0, 101.7, 0},
				{1, 661.05, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.5, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 0.9,
			ring_emit = {
				{4.35, 1, 0, 0, 0.25},
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
			name = "DetRingSharp",
			texture = "kk_circle_02",
			at = {0, -0.3},
			rel = "r",
			lifetime = {0.5, 0.5},
			size = {
				{0, 101.7, 0},
				{1, 813.6, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			ring_emit = {
				{4.35, 1, 0, 0, 0.26},
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
			name = "DetDome",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			at = {0, -0.3},
			direction = "Front",
			pitch = 30,
			spread = {14, 12},
			speed = {70, 130},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {1.3, 1.9},
			size = {
				{0, 24, 4},
				{1, 64, 8},
			},
			transparency = {
				{0, 0.3, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{172, 196, 192},
				},
				{
					0.5,
					{134, 150, 146},
				},
				{
					1,
					{104, 112, 108},
				},
			},
			light_emission = 0.15,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -1,
			ring_emit = {
				{4.35, 1, 0, 0.2, 20},
				{4.35, 1, 0.0278, 0.2, 20},
				{4.35, 1, 0.0556, 0.2, 20},
				{4.35, 1, 0.0833, 0.2, 20},
				{4.35, 1, 0.1111, 0.2, 20},
				{4.35, 1, 0.1389, 0.2, 20},
				{4.35, 1, 0.1667, 0.2, 20},
				{4.35, 1, 0.1944, 0.2, 20},
				{4.35, 1, 0.2222, 0.2, 20},
				{4.35, 1, 0.25, 0.2, 20},
				{4.35, 1, 0.2778, 0.2, 20},
				{4.35, 1, 0.3056, 0.2, 20},
				{4.35, 1, 0.3333, 0.2, 20},
				{4.35, 1, 0.3611, 0.2, 20},
				{4.35, 1, 0.3889, 0.2, 20},
				{4.35, 1, 0.4167, 0.2, 20},
				{4.35, 1, 0.4444, 0.2, 20},
				{4.35, 1, 0.4722, 0.2, 20},
				{4.35, 1, 0.5, 0.2, 20},
				{4.35, 1, 0.5278, 0.2, 20},
				{4.35, 1, 0.5556, 0.2, 20},
				{4.35, 1, 0.5833, 0.2, 20},
				{4.35, 1, 0.6111, 0.2, 20},
				{4.35, 1, 0.6389, 0.2, 20},
				{4.35, 1, 0.6667, 0.2, 20},
				{4.35, 1, 0.6944, 0.2, 20},
				{4.35, 1, 0.7222, 0.2, 20},
				{4.35, 1, 0.75, 0.2, 20},
				{4.35, 1, 0.7778, 0.2, 20},
				{4.35, 1, 0.8056, 0.2, 20},
				{4.35, 1, 0.8333, 0.2, 20},
				{4.35, 1, 0.8611, 0.2, 20},
				{4.35, 1, 0.8889, 0.2, 20},
				{4.35, 1, 0.9167, 0.2, 20},
				{4.35, 1, 0.9444, 0.2, 20},
				{4.35, 1, 0.9722, 0.2, 20},
				{4.35, 1, 0.025, 0.08, 50},
				{4.35, 1, 0.075, 0.08, 50},
				{4.35, 1, 0.125, 0.08, 50},
				{4.35, 1, 0.175, 0.08, 50},
				{4.35, 1, 0.225, 0.08, 50},
				{4.35, 1, 0.275, 0.08, 50},
				{4.35, 1, 0.325, 0.08, 50},
				{4.35, 1, 0.375, 0.08, 50},
				{4.35, 1, 0.425, 0.08, 50},
				{4.35, 1, 0.475, 0.08, 50},
				{4.35, 1, 0.525, 0.08, 50},
				{4.35, 1, 0.575, 0.08, 50},
				{4.35, 1, 0.625, 0.08, 50},
				{4.35, 1, 0.675, 0.08, 50},
				{4.35, 1, 0.725, 0.08, 50},
				{4.35, 1, 0.775, 0.08, 50},
				{4.35, 1, 0.825, 0.08, 50},
				{4.35, 1, 0.875, 0.08, 50},
				{4.35, 1, 0.925, 0.08, 50},
				{4.35, 1, 0.975, 0.08, 50},
			},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "DetShards",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			at = {0, -0.3},
			direction = "Top",
			spread = {70, 70},
			speed = {60, 150},
			drag = 0.4,
			accel = {0, -150, 0},
			lifetime = {1, 1.6},
			size = {
				{0, 5, 1.4},
				{1, 3.5, 1},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{190, 255, 252},
				},
				{
					0.5,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 0.5,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			radial = false,
			ring_emit = {
				{4.351, 2, 0.1474, 0.0907, 39.621},
				{4.351, 2, 0.281, 0.0816, 95.479},
				{4.351, 2, 0.5462, 0.051, 86.143},
				{4.351, 2, 0.975, 0.0818, 75.764},
				{4.352, 2, 0.1946, 0.0478, 72.035},
				{4.352, 2, 0.2536, 0.0499, 30.312},
				{4.353, 2, 0.0947, 0.0568, 48.954},
				{4.353, 2, 0.4536, 0.0984, 34.739},
				{4.353, 2, 0.6131, 0.0674, 33.331},
				{4.354, 2, 0.4531, 0.0363, 11.905},
				{4.354, 2, 0.5184, 0.0286, 89.64},
				{4.355, 2, 0.4296, 0.0778, 77.621},
				{4.357, 2, 0.6444, 0.0543, 89.986},
				{4.357, 2, 0.8692, 0.0844, 59.193},
				{4.358, 2, 0.1068, 0.0983, 37.184},
				{4.358, 2, 0.1959, 0.0962, 57.797},
				{4.358, 2, 0.3436, 0.0451, 19.285},
				{4.36, 2, 0.9868, 0.0924, 19.553},
				{4.361, 2, 0.2894, 0.0968, 25.501},
				{4.361, 2, 0.8413, 0.089, 43.023},
				{4.362, 2, 0.3335, 0.0471, 50.454},
				{4.362, 2, 0.5647, 0.0996, 95.658},
				{4.363, 2, 0.1786, 0.0926, 30.084},
				{4.363, 2, 0.2271, 0.0526, 81.037},
				{4.366, 2, 0.2833, 0.0725, 38.683},
				{4.367, 2, 0.1755, 0.0516, 82.922},
				{4.367, 2, 0.4963, 0.0201, 70.399},
				{4.368, 2, 0.0823, 0.0325, 93.797},
				{4.372, 2, 0.819, 0.0993, 48.392},
				{4.373, 2, 0.5569, 0.0417, 10.635},
				{4.373, 2, 0.5913, 0.0866, 35.006},
				{4.373, 2, 0.6621, 0.0511, 42.907},
				{4.373, 2, 0.9675, 0.0909, 18.821},
				{4.374, 2, 0.1401, 0.0926, 17.205},
				{4.374, 2, 0.3039, 0.0566, 22.98},
				{4.375, 2, 0.5206, 0.0625, 82.705},
				{4.375, 2, 0.7694, 0.0268, 49.971},
				{4.375, 2, 0.8141, 0.073, 18.065},
				{4.375, 2, 0.8696, 0.086, 98.419},
				{4.376, 2, 0.7632, 0.0342, 59.617},
				{4.377, 2, 0.6297, 0.0381, 19.321},
				{4.379, 2, 0.1222, 0.0984, 81.813},
				{4.379, 2, 0.628, 0.0904, 66.768},
				{4.381, 2, 0.0462, 0.0846, 72.799},
				{4.381, 2, 0.2276, 0.0946, 10.092},
				{4.381, 2, 0.8502, 0.0673, 66.378},
				{4.381, 2, 0.9204, 0.0833, 94.248},
				{4.384, 2, 0.8664, 0.0728, 37.161},
				{4.385, 2, 0.0775, 0.0502, 48.058},
				{4.385, 2, 0.24, 0.0918, 30.86},
				{4.386, 2, 0.3375, 0.072, 68.24},
				{4.386, 2, 0.5705, 0.0937, 17.574},
				{4.387, 2, 0.6314, 0.0691, 75.467},
				{4.39, 2, 0.4082, 0.0857, 33.042},
				{4.391, 2, 0.0658, 0.0713, 53.283},
				{4.391, 2, 0.112, 0.0544, 93.498},
				{4.392, 2, 0.0406, 0.0814, 15.798},
				{4.392, 2, 0.7811, 0.0966, 90.591},
				{4.392, 2, 0.9066, 0.037, 86.968},
				{4.393, 2, 0.8256, 0.0967, 54.485},
				{4.394, 2, 0.8271, 0.0768, 10.563},
				{4.395, 2, 0.1264, 0.0116, 41.955},
				{4.395, 2, 0.4785, 0.027, 83.309},
				{4.395, 2, 0.8219, 0.0771, 44.541},
				{4.396, 2, 0.7295, 0.0051, 38.456},
				{4.397, 2, 0.7826, 0.0421, 41.247},
				{4.398, 2, 0.2162, 0.0498, 67.621},
				{4.398, 2, 0.8925, 0.0809, 26.331},
				{4.398, 2, 0.9732, 0.0848, 25.841},
				{4.399, 2, 0.0225, 0.0806, 40.401},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "RainShards",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Bottom",
			spread = {10, 10},
			speed = {30, 60},
			accel = {0, -80, 0},
			lifetime = {1.4, 2},
			size = {
				{0, 3, 1},
				{1, 2.5, 0.8},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{190, 255, 252},
				},
				{
					0.5,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 0.6,
			brightness = 1.6,
			rotation = {0, 360},
			rot_speed = {-300, 300},
			radial = false,
			ring_emit = {
				{4.601, 1, 0.2556, 0.9046, 135.693},
				{4.617, 1, 0.3593, 0.4792, 123.613},
				{4.63, 1, 0.9576, 0.2184, 119},
				{4.634, 1, 0.3516, 0.7746, 129.062},
				{4.635, 1, 0.5228, 0.6374, 97.691},
				{4.638, 1, 0.7513, 0.8465, 132.542},
				{4.658, 1, 0.0769, 0.3164, 146.963},
				{4.681, 1, 0.699, 0.5298, 92.583},
				{4.699, 1, 0.1204, 0.7593, 149.887},
				{4.713, 1, 0.8189, 0.7857, 124.848},
				{4.716, 1, 0.5359, 0.9993, 113.9},
				{4.734, 1, 0.342, 0.2657, 117.797},
				{4.749, 1, 0.9653, 0.3137, 92.956},
				{4.753, 1, 0.3607, 0.6042, 102.848},
				{4.753, 1, 0.5117, 0.9866, 142.308},
				{4.761, 1, 0.33, 0.2941, 101.876},
				{4.769, 1, 0.3209, 0.5122, 102.214},
				{4.778, 1, 0.7247, 0.9784, 79.747},
				{4.78, 1, 0.2811, 0.3773, 121.912},
				{4.788, 1, 0.8796, 0.6561, 73.175},
				{4.798, 1, 0.0982, 0.8468, 94.641},
				{4.822, 1, 0.3558, 0.7778, 109.225},
				{4.829, 1, 0.4641, 0.941, 140.757},
				{4.841, 1, 0.2996, 0.6225, 149.197},
				{4.861, 1, 0.3073, 0.8573, 78.099},
				{4.874, 1, 0.8842, 0.3503, 107.987},
				{4.883, 1, 0.3448, 0.9126, 123.464},
				{4.885, 1, 0.8509, 0.9447, 81.02},
				{4.909, 1, 0.0372, 0.9336, 91.342},
				{4.912, 1, 0.1111, 0.7293, 147.291},
				{4.914, 1, 0.3894, 0.3022, 85.606},
				{4.924, 1, 0.4779, 0.1027, 81.053},
				{4.925, 1, 0.3388, 0.9603, 85.914},
				{4.937, 1, 0.4739, 0.8671, 110.823},
				{4.939, 1, 0.4089, 0.5669, 74.919},
				{4.946, 1, 0.7201, 0.9773, 145.42},
				{4.948, 1, 0.8355, 0.6884, 93.108},
				{4.957, 1, 0.1066, 0.0827, 124.724},
				{4.961, 1, 0.6996, 0.3753, 96.849},
				{4.982, 1, 0.6652, 0.786, 90.482},
				{5.003, 1, 0.714, 0.7981, 124.489},
				{5.029, 1, 0.2638, 0.8086, 77.194},
				{5.038, 1, 0.3463, 0.9949, 110.174},
				{5.043, 1, 0.8229, 0.4368, 86.371},
				{5.054, 1, 0.1462, 0.8147, 140.135},
				{5.054, 1, 0.6418, 0.7381, 138.348},
				{5.056, 1, 0.2635, 0.9655, 145.784},
				{5.086, 1, 0.6849, 0.7822, 80.317},
				{5.089, 1, 0.1363, 0.0893, 142.274},
				{5.099, 1, 0.6201, 0.8485, 127.84},
				{5.1, 1, 0.7489, 0.7876, 75.931},
				{5.103, 1, 0.6237, 0.8774, 121.737},
				{5.103, 1, 0.7149, 0.0232, 106.618},
				{5.115, 1, 0.9463, 0.3397, 112.958},
				{5.117, 1, 0.9869, 0.2751, 74.534},
				{5.12, 1, 0.2452, 0.944, 85.615},
				{5.127, 1, 0.1793, 0.2501, 101.416},
				{5.139, 1, 0.4988, 0.1807, 101.069},
				{5.141, 1, 0.7652, 0.9677, 131.645},
				{5.147, 1, 0.1027, 0.7661, 128.371},
				{5.156, 1, 0.9958, 0.8481, 90.041},
				{5.161, 1, 0.651, 0.7601, 76.327},
				{5.187, 1, 0.5672, 0.9375, 92.417},
				{5.188, 1, 0.4967, 0.622, 103.869},
				{5.188, 1, 0.8548, 0.7187, 130.948},
				{5.199, 1, 0.6463, 0.8147, 90.468},
				{5.2, 1, 0.4772, 0.7974, 149.554},
				{5.205, 1, 0.2308, 0.4984, 90.713},
				{5.205, 1, 0.5602, 0.5837, 127.56},
				{5.223, 1, 0.4867, 0.808, 88.862},
				{5.225, 1, 0.8056, 0.5476, 134.795},
				{5.227, 1, 0.459, 0.9262, 78.603},
				{5.23, 1, 0.3857, 0.312, 74.375},
				{5.239, 1, 0.2302, 0.4427, 111.006},
				{5.241, 1, 0.6025, 0.2494, 103.591},
				{5.247, 1, 0.6008, 0.9212, 71.126},
				{5.263, 1, 0.3058, 0.938, 129.61},
				{5.278, 1, 0.9823, 0.418, 107.372},
				{5.291, 1, 0.9875, 0.9735, 96.523},
				{5.296, 1, 0.4836, 0.4622, 115.895},
				{5.307, 1, 0.4898, 0.7462, 87.674},
				{5.313, 1, 0.3525, 0.3836, 85.436},
				{5.355, 1, 0.4683, 0.5547, 125.45},
				{5.355, 1, 0.8395, 0.9875, 132.621},
				{5.373, 1, 0.5408, 0.9777, 74.877},
				{5.373, 1, 0.6027, 0.4599, 111.32},
				{5.385, 1, 0.0149, 0.9006, 129.473},
				{5.395, 1, 0.4966, 0.6898, 137.283},
				{5.396, 1, 0.7172, 0.3559, 130.598},
				{5.397, 1, 0.9197, 0.8418, 137.838},
				{5.403, 1, 0.8694, 0.5246, 146.316},
				{5.405, 1, 0.9706, 0.4807, 78.663},
				{5.407, 1, 0.0701, 0.887, 108.466},
				{5.418, 1, 0.9387, 0.7577, 133.264},
				{5.422, 1, 0.7835, 0.9876, 116.383},
				{5.427, 1, 0.8128, 0.9799, 106.397},
				{5.436, 1, 0.0939, 0.2605, 130.675},
				{5.454, 1, 0.0556, 0.2364, 148.362},
				{5.457, 1, 0.1865, 0.7064, 113.51},
				{5.461, 1, 0.0985, 0.9919, 105.186},
				{5.47, 1, 0.5236, 0.6949, 104.753},
				{5.483, 1, 0.1572, 0.4424, 72.545},
				{5.49, 1, 0.0355, 0.7559, 126.673},
				{5.5, 1, 0.569, 0.9813, 142.954},
				{5.508, 1, 0.0571, 0.2878, 107.925},
				{5.508, 1, 0.8557, 0.461, 149.907},
				{5.513, 1, 0.5989, 0.7459, 133.449},
				{5.534, 1, 0.7262, 0.9177, 139.541},
				{5.536, 1, 0.9281, 0.8401, 86.203},
				{5.538, 1, 0.868, 0.8871, 125.386},
				{5.548, 1, 0.7477, 0.9248, 72.963},
				{5.549, 1, 0.614, 0.9614, 142.16},
				{5.551, 1, 0.8085, 0.6164, 135.526},
				{5.552, 1, 0.4855, 0.0696, 90.678},
				{5.571, 1, 0.7169, 0.5867, 127.519},
				{5.589, 1, 0.9533, 0.5011, 148.005},
				{5.598, 1, 0.3299, 0.1161, 101.508},
				{5.599, 1, 0.5946, 0.8492, 78.236},
				{5.616, 1, 0.592, 0.9983, 87.513},
				{5.638, 1, 0.5045, 0.496, 113.352},
				{5.655, 1, 0.4809, 0.9355, 106.365},
				{5.656, 1, 0.9644, 0.5956, 128.9},
				{5.658, 1, 0.1483, 0.6925, 141.966},
				{5.664, 1, 0.7789, 0.3784, 142.189},
				{5.69, 1, 0.0843, 0.6537, 88.237},
				{5.699, 1, 0.4255, 0.9695, 133.227},
				{5.702, 1, 0.443, 0.51, 101.69},
				{5.712, 1, 0.1389, 0.6535, 138.438},
				{5.72, 1, 0.0625, 0.6392, 90.89},
				{5.731, 1, 0.7568, 0.8911, 80.924},
				{5.739, 1, 0.6014, 0.3889, 89.07},
				{5.745, 1, 0.1714, 0.8421, 103.808},
				{5.755, 1, 0.7509, 0.4498, 71.777},
				{5.761, 1, 0.3113, 0.9298, 82.988},
				{5.778, 1, 0.4902, 0.9486, 124.353},
				{5.784, 1, 0.919, 0.4253, 96.52},
				{5.816, 1, 0.4748, 0.5344, 140.293},
				{5.819, 1, 0.1129, 0.9361, 132.36},
				{5.826, 1, 0.7144, 0.8542, 148.494},
				{5.835, 1, 0.0748, 0.9087, 81.709},
			},
			drag = 0,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "RainGlints",
			texture = "kk_star_09",
			direction = "Bottom",
			spread = {10, 10},
			speed = {30, 50},
			lifetime = {1.2, 1.8},
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
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 2,
			rotation = {0, 45},
			radial = false,
			ring_emit = {
				{4.582, 1, 0.3928, 0.4452, 135.137},
				{4.605, 1, 0.3294, 0.4019, 62.132},
				{4.625, 1, 0.3688, 0.9811, 81.571},
				{4.648, 1, 0.9697, 0.6604, 112.145},
				{4.684, 1, 0.005, 0.5213, 134.117},
				{4.685, 1, 0.5647, 0.899, 111.542},
				{4.704, 1, 0.6016, 0.7231, 119.85},
				{4.711, 1, 0.8207, 0.4874, 76.893},
				{4.732, 1, 0.9997, 0.6066, 75.542},
				{4.736, 1, 0.0522, 0.5171, 121.823},
				{4.753, 1, 0.9167, 0.8744, 71.467},
				{4.769, 1, 0.5245, 0.9233, 105.143},
				{4.777, 1, 0.1628, 0.5695, 69.368},
				{4.784, 1, 0.3386, 0.6528, 107.907},
				{4.787, 1, 0.5907, 0.7074, 118.009},
				{4.79, 1, 0.1714, 0.9112, 99.837},
				{4.799, 1, 0.6412, 0.1909, 122.283},
				{4.805, 1, 0.8735, 0.7246, 127.005},
				{4.805, 1, 0.9896, 0.6805, 61.3},
				{4.843, 1, 0.9018, 0.5747, 139.758},
				{4.85, 1, 0.0887, 0.6231, 125.668},
				{4.865, 1, 0.2758, 0.9347, 114.72},
				{4.869, 1, 0.7022, 0.6304, 137.32},
				{4.871, 1, 0.0692, 0.5088, 117.715},
				{4.887, 1, 0.6037, 0.7539, 71.608},
				{4.887, 1, 0.947, 0.5668, 81.798},
				{4.897, 1, 0.0116, 0.8193, 123.056},
				{4.905, 1, 0.7643, 0.703, 101.974},
				{4.909, 1, 0.2789, 0.8608, 126.713},
				{4.911, 1, 0.4853, 0.8366, 75.658},
				{4.926, 1, 0.8782, 0.4101, 94.572},
				{4.934, 1, 0.4363, 0.4375, 116.497},
				{4.95, 1, 0.0668, 0.8122, 103.949},
				{4.975, 1, 0.6187, 0.5852, 124.094},
				{4.977, 1, 0.7075, 0.8106, 104.525},
				{4.986, 1, 0.2024, 0.9933, 126.596},
				{4.993, 1, 0.9489, 0.3771, 65.995},
				{5, 1, 0.8714, 0.8807, 71.725},
				{5.006, 1, 0.5521, 0.773, 116.6},
				{5.021, 1, 0.3025, 0.9637, 87.786},
				{5.063, 1, 0.8522, 0.9855, 132.33},
				{5.067, 1, 0.7941, 0.9889, 115.361},
				{5.07, 1, 0.6175, 0.4834, 126.902},
				{5.081, 1, 0.7457, 0.3721, 106.151},
				{5.104, 1, 0.2513, 0.6459, 72.636},
				{5.146, 1, 0.4051, 0.9052, 90.276},
				{5.16, 1, 0.6477, 0.7386, 78.86},
				{5.177, 1, 0.7585, 0.5296, 128.692},
				{5.185, 1, 0.9826, 0.1596, 80.568},
				{5.188, 1, 0.6378, 0.9843, 123.168},
				{5.222, 1, 0.8126, 0.4364, 128.842},
				{5.224, 1, 0.6416, 0.5623, 99.976},
				{5.232, 1, 0.9112, 0.5783, 122.195},
				{5.258, 1, 0.3944, 0.7412, 74.771},
				{5.263, 1, 0.3257, 0.3116, 136.819},
				{5.269, 1, 0.9833, 0.9882, 122.205},
				{5.27, 1, 0.7382, 0.9514, 126.726},
				{5.276, 1, 0.2577, 0.1047, 110.489},
				{5.277, 1, 0.5134, 0.5068, 137.804},
				{5.289, 1, 0.0252, 0.7361, 97.366},
				{5.297, 1, 0.3901, 0.4373, 107.229},
				{5.305, 1, 0.5996, 0.888, 121.917},
				{5.311, 1, 0.105, 0.7331, 107.275},
				{5.325, 1, 0.6205, 0.4702, 66.448},
				{5.328, 1, 0.0438, 0.7661, 110.517},
				{5.34, 1, 0.5941, 0.8017, 72.964},
				{5.34, 1, 0.8819, 0.5582, 114.862},
				{5.342, 1, 0.6052, 0.7487, 78.172},
				{5.384, 1, 0.6505, 0.6653, 72.819},
				{5.412, 1, 0.6074, 0.8464, 123.318},
				{5.418, 1, 0.9019, 0.6177, 93.36},
				{5.432, 1, 0.4752, 0.2036, 61.249},
				{5.444, 1, 0.9724, 0.3741, 83.287},
				{5.486, 1, 0.3618, 0.6877, 82.872},
				{5.489, 1, 0.6059, 0.4544, 84.561},
				{5.491, 1, 0.699, 0.9268, 77.781},
				{5.556, 1, 0.9004, 0.6743, 76.536},
				{5.563, 1, 0.5622, 0.5301, 76.689},
				{5.572, 1, 0.7711, 0.6264, 96.362},
				{5.578, 1, 0.5201, 0.4626, 79.43},
				{5.584, 1, 0.161, 0.4292, 88.757},
				{5.609, 1, 0.5668, 0.7458, 134.178},
				{5.613, 1, 0.0006, 0.6976, 67.332},
				{5.621, 1, 0.0634, 0.8273, 91.778},
				{5.648, 1, 0.1837, 0.5313, 66.53},
				{5.651, 1, 0.6619, 0.9905, 98.311},
				{5.656, 1, 0.0906, 0.6438, 80.471},
				{5.702, 1, 0.9555, 0.9734, 108.167},
				{5.707, 1, 0.0289, 0.9065, 66.794},
				{5.717, 1, 0.8394, 0.4024, 68.96},
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
			name = "DetGlitter",
			texture = "kk_star_09",
			direction = "Top",
			speed = {4, 14},
			drag = 0.8,
			accel = {0, -6, 0},
			lifetime = {1.4, 2.2},
			size = {
				{0, 0, 0},
				{0.08, 5.76, 0},
				{0.22, 2.52, 0},
				{0.38, 6.12, 0},
				{0.55, 2.16, 0},
				{0.72, 5.04, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
				},
			},
			light_emission = 1,
			brightness = 2.2,
			rotation = {0, 45},
			radial = false,
			ring_emit = {
				{4.365, 1, 0.2956, 0.4255, 16.258},
				{4.366, 1, 0.4554, 0.0938, 24.453},
				{4.372, 1, 0.2893, 0.423, 11.811},
				{4.373, 1, 0.1024, 0.978, 13.595},
				{4.373, 1, 0.2353, 0.5976, 39.603},
				{4.379, 1, 0.3069, 0.5436, 61.506},
				{4.38, 1, 0.4775, 0.552, 10.958},
				{4.393, 1, 0.1401, 0.6126, 63.925},
				{4.396, 1, 0.4247, 0.4372, 77.156},
				{4.398, 1, 0.522, 0.6321, 21.145},
				{4.398, 1, 0.8158, 0.2136, 10.034},
				{4.398, 1, 0.8468, 0.7216, 34.639},
				{4.401, 1, 0.8543, 0.2706, 38.899},
				{4.403, 1, 0.3976, 0.8183, 63.108},
				{4.409, 1, 0.499, 0.8183, 71.644},
				{4.412, 1, 0.6644, 0.928, 64.373},
				{4.416, 1, 0.4364, 0.8768, 79.687},
				{4.417, 1, 0.4871, 0.9402, 43.429},
				{4.422, 1, 0.0575, 0.8199, 14.835},
				{4.45, 1, 0.2534, 0.9146, 78.685},
				{4.453, 1, 0.19, 0.8875, 17.747},
				{4.457, 1, 0.0916, 0.5753, 31.114},
				{4.476, 1, 0.2052, 0.0774, 61.84},
				{4.476, 1, 0.684, 0.8316, 21.984},
				{4.481, 1, 0.1561, 0.9957, 62.503},
				{4.486, 1, 0.1984, 0.6064, 33.41},
				{4.487, 1, 0.9663, 0.7635, 24.544},
				{4.49, 1, 0.8704, 0.5846, 76.405},
				{4.492, 1, 0.7986, 0.8804, 67.603},
				{4.493, 1, 0.9701, 0.9765, 67.897},
				{4.494, 1, 0.7179, 0.944, 78.091},
				{4.499, 1, 0.5701, 0.6182, 52.576},
				{4.511, 1, 0.9997, 0.9404, 66.304},
				{4.513, 1, 0.4388, 0.9113, 48.457},
				{4.514, 1, 0.9975, 0.6724, 76.881},
				{4.515, 1, 0.5113, 0.7, 33.638},
				{4.518, 1, 0.0245, 0.8174, 32.956},
				{4.546, 1, 0.8967, 0.3834, 20.526},
				{4.547, 1, 0.5452, 0.5636, 66.611},
				{4.568, 1, 0.6663, 0.9126, 10.268},
				{4.575, 1, 0.4124, 0.6814, 48.862},
				{4.582, 1, 0.2429, 0.6853, 43.244},
				{4.584, 1, 0.0338, 0.5559, 79.693},
				{4.591, 1, 0.5182, 0.93, 67.582},
				{4.594, 1, 0.3695, 0.7995, 44.109},
				{4.594, 1, 0.9636, 0.5921, 37.929},
				{4.604, 1, 0.4303, 0.7808, 47.075},
				{4.605, 1, 0.915, 0.8572, 19.567},
				{4.608, 1, 0.541, 0.918, 10.937},
				{4.612, 1, 0.9418, 0.5892, 19.294},
				{4.626, 1, 0.848, 0.7838, 56.866},
				{4.645, 1, 0.8593, 0.7769, 41.709},
				{4.652, 1, 0.1894, 0.9947, 15.588},
				{4.654, 1, 0.6259, 0.974, 10.546},
				{4.662, 1, 0.2761, 0.8851, 25.315},
				{4.665, 1, 0.0045, 0.4702, 69.338},
				{4.672, 1, 0.5067, 0.8357, 43.573},
				{4.673, 1, 0.5672, 0.8678, 60.992},
				{4.677, 1, 0.146, 0.4242, 70.438},
				{4.68, 1, 0.2426, 0.5008, 72.425},
				{4.681, 1, 0.8222, 0.8913, 9.45},
				{4.692, 1, 0.9977, 0.3899, 49.315},
				{4.696, 1, 0.8399, 0.9305, 59.878},
				{4.699, 1, 0.461, 0.2847, 72.469},
				{4.708, 1, 0.1954, 0.962, 26.58},
				{4.712, 1, 0.0238, 0.2576, 77.084},
				{4.715, 1, 0.5552, 0.658, 58.013},
				{4.716, 1, 0.0989, 0.593, 43.31},
				{4.716, 1, 0.2133, 0.3524, 40.952},
				{4.717, 1, 0.398, 0.9972, 43.241},
				{4.719, 1, 0.6732, 0.8495, 17.696},
				{4.72, 1, 0.2856, 0.4767, 65.658},
				{4.735, 1, 0.2858, 0.7331, 45.775},
				{4.736, 1, 0.1358, 0.9261, 75.149},
				{4.739, 1, 0.4992, 0.8356, 72.706},
				{4.74, 1, 0.6535, 0.0689, 21.776},
				{4.744, 1, 0.3845, 0.5359, 35.648},
				{4.745, 1, 0.1634, 0.6252, 25.475},
				{4.747, 1, 0.2303, 0.9642, 44.808},
				{4.75, 1, 0.2985, 0.7887, 69.255},
				{4.756, 1, 0.7478, 0.6715, 51.757},
				{4.762, 1, 0.5726, 0.8004, 35.957},
				{4.762, 1, 0.7169, 0.4212, 45.721},
				{4.767, 1, 0.8799, 0.347, 30.639},
				{4.775, 1, 0.7867, 0.9627, 37.282},
				{4.776, 1, 0.8919, 0.9786, 75.313},
				{4.786, 1, 0.4538, 0.84, 66.459},
				{4.788, 1, 0.5764, 0.8721, 12.177},
				{4.803, 1, 0.3931, 0.797, 66.125},
				{4.816, 1, 0.6969, 0.9795, 34.857},
				{4.822, 1, 0.2744, 0.6857, 76.5},
				{4.832, 1, 0.387, 0.992, 79.131},
				{4.834, 1, 0.8165, 0.8904, 15.314},
				{4.84, 1, 0.7868, 0.2167, 11.368},
				{4.844, 1, 0.2521, 0.6067, 69.082},
				{4.847, 1, 0.5129, 0.5581, 49.524},
				{4.856, 1, 0.7964, 0.6579, 38.689},
				{4.862, 1, 0.8348, 0.8135, 73.102},
				{4.868, 1, 0.5415, 0.7158, 65.144},
				{4.873, 1, 0.7181, 0.9485, 71.395},
				{4.878, 1, 0.072, 0.3082, 24.192},
				{4.884, 1, 0.8353, 0.6186, 18.213},
				{4.885, 1, 0.2208, 0.1079, 35.873},
				{4.895, 1, 0.859, 0.6472, 47.273},
				{4.916, 1, 0.473, 0.4141, 52.018},
				{4.927, 1, 0.1728, 0.8125, 58.375},
				{4.932, 1, 0.3704, 0.7756, 77.766},
				{4.941, 1, 0.4746, 0.9056, 10.73},
				{4.941, 1, 0.4929, 0.932, 40.13},
				{4.944, 1, 0.0284, 0.4405, 18.06},
			},
			spread = {0, 0},
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
			name = "AfterMist",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {60, 60},
			speed = {2, 6},
			drag = 1,
			lifetime = {1.8, 2.4},
			size = {
				{0, 20, 3},
				{1, 40, 5},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.66, 0},
				{0.8, 0.76, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{172, 196, 192},
				},
				{
					0.5,
					{134, 150, 146},
				},
				{
					1,
					{104, 112, 108},
				},
			},
			light_emission = 0.15,
			rotation = {0, 360},
			rot_speed = {-15, 15},
			zoffset = -4,
			radial = false,
			ring_emit = {
				{4.456, 1, 0.0524, 0.8341, 16.688},
				{4.457, 1, 0.1454, 0.8063, 17.188},
				{4.462, 1, 0.9408, 0.8888, 14.64},
				{4.464, 1, 0.7083, 0.9182, 19.512},
				{4.487, 1, 0.7724, 0.6705, 14.604},
				{4.551, 1, 0.4966, 0.3306, 19.163},
				{4.556, 1, 0.2724, 0.8199, 15.856},
				{4.568, 1, 0.3221, 0.6574, 17.533},
				{4.569, 1, 0.3808, 0.7951, 15.705},
				{4.583, 1, 0.3158, 0.9779, 16.435},
				{4.6, 1, 0.8026, 0.5478, 14.368},
				{4.636, 1, 0.2255, 0.629, 14.27},
				{4.646, 1, 0.6882, 0.8981, 18.322},
				{4.685, 1, 0.5595, 0.8276, 16.13},
				{4.705, 1, 0.1477, 0.8511, 17.998},
				{4.723, 1, 0.523, 0.4639, 18.34},
				{4.736, 1, 0.929, 0.5172, 19.277},
				{4.751, 1, 0.2368, 0.7954, 16.819},
				{4.762, 1, 0.1506, 0.357, 17.505},
				{4.767, 1, 0.7875, 0.5851, 16.178},
				{4.781, 1, 0.4006, 0.9684, 16.376},
				{4.814, 1, 0.7676, 0.7848, 19.247},
				{4.842, 1, 0.7324, 0.5541, 14.026},
				{4.843, 1, 0.3598, 0.6456, 16.506},
				{4.843, 1, 0.7183, 0.526, 17.923},
				{4.87, 1, 0.5711, 0.951, 14.646},
				{4.895, 1, 0.1113, 0.6651, 19.32},
				{4.91, 1, 0.7502, 0.9537, 15.207},
				{4.912, 1, 0.6114, 0.221, 19.787},
				{4.915, 1, 0.7773, 0.4878, 18.856},
				{4.947, 1, 0.951, 0.6691, 18.128},
				{4.952, 1, 0.426, 0.9871, 18.609},
				{4.998, 1, 0.3873, 0.9243, 15.471},
				{5.004, 1, 0.6311, 0.6768, 15.217},
				{5.044, 1, 0.7344, 0.5902, 19.229},
				{5.065, 1, 0.5268, 0.3828, 14.228},
				{5.092, 1, 0.6727, 0.8958, 17.371},
				{5.12, 1, 0.5299, 0.4226, 16.185},
				{5.124, 1, 0.3465, 0.9256, 17.018},
				{5.147, 1, 0.064, 0.8299, 16.837},
			},
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "PillarBase",
			texture = "fx_glow",
			at = {0, -0.3},
			lifetime = {1.3, 1.3},
			size = {
				{0, 30, 0},
				{0.15, 75, 0},
				{1, 60, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 255, 252},
				},
				{
					0.4,
					{94, 229, 224},
				},
				{
					1,
					{52, 147, 152},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			zoffset = 3,
			ring_emit = {
				{4.37, 1, 0, 0, 8},
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
	},
	shakes = {
		{0, 1, 0.5},
		{1.15, 2, 0.8},
		{2.75, 2.4, 0.9},
		{4.35, 2.8, 1.2},
	},
	shake_ramp = {0, 4.35, 0.12, 1.1, 1.6},
	zone = {
		radius = 150,
		height = 420,
		front = {1.15, 0.8},
	},
	lights = {
		{
			t = 0.05,
			h = 6,
			color = {94, 229, 224},
			brightness = 2,
			range = 60,
			rise = 0.9,
			hold = 0.15,
			fall = 0.3,
		},
		{
			t = 1.3,
			h = 8,
			color = {94, 229, 224},
			brightness = 4,
			range = 60,
			rise = 0.15,
			hold = 1.3,
			fall = 0.5,
			ring = {8, 0.55},
		},
		{
			t = 2.75,
			h = 40,
			color = {170, 255, 250},
			brightness = 8,
			range = 60,
			rise = 0.03,
			hold = 0.1,
			fall = 0.5,
			at = {0, -0.3},
		},
		{
			t = 2.85,
			h = 50,
			color = {94, 229, 224},
			brightness = 4,
			range = 60,
			rise = 0.2,
			hold = 1.3,
			fall = 0.2,
			at = {0, -0.3},
		},
		{
			t = 4.35,
			h = 30,
			color = {205, 255, 252},
			brightness = 12,
			range = 60,
			rise = 0.02,
			hold = 0.06,
			fall = 0.9,
			at = {0, -0.3},
		},
		{
			t = 4.35,
			h = 10,
			color = {205, 255, 252},
			brightness = 8,
			range = 60,
			rise = 0.02,
			hold = 0.06,
			fall = 0.9,
			ring = {8, 0.6},
		},
	},
	times = {
		Slam = 0,
		Rupture = 1.15,
		Mountain = 2.75,
		Detonation = 4.35,
		End = 6.65,
	},
	screen = {
		range = 3,
		cc = {
			{0, 0, 0, 0, 255, 255, 255},
			{0.9, -0.1, 0.1, -0.12, 214, 236, 234},
			{1.15, -0.18, 0.16, -0.2, 190, 226, 222},
			{4.35, -0.18, 0.16, -0.2, 190, 226, 222},
			{4.45, 0.08, 0.12, -0.08, 225, 252, 248},
			{5.95, 0, 0, 0, 255, 255, 255},
		},
		flash = {
			{1.15, 0.25, 0.03, 0.25},
			{2.75, 0.35, 0.03, 0.3},
			{4.35, 0.5, 0.03, 0.4},
		},
		flash_color = {215, 255, 250},
	},
	cubes = {
		gravity = 160,
		bounce = 0.3,
		friction = 0.55,
		spin = {200, 760},
		rest = {0.5, 1.2},
		fade = 0.35,
		settle = 0.12,
		shrink = {0.16, 0.26},
		dissolve_time = {0.2, 0.6},
		color_var = {0.72, 1.08},
		dark = 0.15,
		neon_colors = {
			{94, 229, 224},
			{52, 147, 152},
			{150, 245, 240},
			{205, 255, 252},
		},
		groups = {
			{
				name = "Tremble",
				mode = "lift",
				count = 70,
				t = {0.1, 1},
				r = {0.08, 1},
				size = {0.5, 2.6},
				skew = 2.2,
				lift = {2, 8},
				release = {1.15, 1.95},
				out = {15, 45},
				up = {40, 90},
				dissolve = 0.3,
				neon = 0.15,
			},
			{
				name = "Rupture",
				mode = "blast",
				count = 200,
				t = {1.15, 1.2},
				sweep = 0.8,
				r = {0.05, 1},
				size = {0.6, 3.6},
				skew = 2.4,
				out = {15, 55},
				up = {45, 110},
				dissolve = 0.3,
				neon = 0.12,
			},
			{
				name = "Mountain",
				mode = "blast",
				count = 110,
				t = {2.75, 2.8},
				at = {0, -0.3},
				r = {0.02, 0.2},
				size = {1.2, 5},
				skew = 1.8,
				out = {30, 85},
				up = {60, 130},
				dissolve = 0.3,
				neon = 0.12,
			},
			{
				name = "CrystalRain",
				mode = "blast",
				count = 200,
				t = {4.35, 4.41},
				at = {0, -0.3},
				r = {0, 0.1},
				h = {12, 95},
				size = {1, 4.4},
				skew = 1.8,
				out = {25, 105},
				up = {20, 110},
				dissolve = 0.45,
				neon = 0.9,
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
					{205, 255, 250},
				},
				{
					1,
					{120, 235, 228},
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
	zbeams = {
		{
			count = 1,
			r = 0.3,
			a0 = 0.75,
			spin = 0,
			wobble = 0,
			near = 0,
			zoffset = 0,
			name = "PillarGlow",
			texture = "kz_beam_glow",
			width = 0.45,
			tex_len = 1,
			speed = 0,
			color = {
				{
					0,
					{170, 255, 250},
				},
				{
					1,
					{94, 229, 224},
				},
			},
			transparency = {
				{0, 0.15},
				{0.75, 0.3},
				{1, 1},
			},
			brightness = 2,
			light_emission = 1,
			width_t = {
				{4.35, 0.4},
				{4.5, 1.25},
				{4.85, 1},
				{5.65, 0.55},
				{6.05, 0},
			},
			alpha_t = {
				{4.35, 0.1},
				{5.25, 0.15},
				{6.05, 1},
			},
			drop = {4.35, 0.18},
			h = {1, 0},
			rim = false,
		},
		{
			count = 1,
			r = 0.3,
			a0 = 0.75,
			spin = 0,
			wobble = 0,
			near = 0,
			zoffset = 0,
			name = "PillarFire",
			texture = "pb_breath_fire",
			width = 0.24,
			tex_len = 0.25,
			speed = 3,
			color = {
				{
					0,
					{200, 255, 252},
				},
				{
					0.5,
					{100, 236, 230},
				},
				{
					1,
					{60, 185, 186},
				},
			},
			transparency = {
				{0, 0.1},
				{0.8, 0.25},
				{1, 1},
			},
			brightness = 1.4,
			light_emission = 1,
			width_t = {
				{4.35, 0.4},
				{4.5, 1.25},
				{4.85, 1},
				{5.65, 0.55},
				{6.05, 0},
			},
			alpha_t = {
				{4.35, 0.1},
				{5.25, 0.15},
				{6.05, 1},
			},
			drop = {4.35, 0.18},
			h = {1, 0},
			rim = false,
		},
		{
			count = 1,
			r = 0.3,
			a0 = 0.75,
			spin = 0,
			wobble = 0,
			near = 0,
			zoffset = 0,
			name = "PillarCore",
			texture = "kz_beam_core",
			width = 0.07,
			tex_len = 1,
			speed = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{205, 255, 250},
				},
			},
			transparency = {
				{0, 0},
				{0.85, 0.15},
				{1, 1},
			},
			brightness = 2.2,
			light_emission = 1,
			width_t = {
				{4.35, 0.5},
				{4.45, 1.4},
				{4.95, 1},
				{5.75, 0.4},
				{6.05, 0},
			},
			alpha_t = {
				{4.35, 0.1},
				{5.25, 0.15},
				{6.05, 1},
			},
			drop = {4.35, 0.18},
			h = {1, 0},
			rim = false,
		},
	},
	zfield = {
		groups = {
			{
				hold = {1, 1},
				sink = 0.9,
				name = "TectonicPlates",
				count = 46,
				r = {0.16, 1.02},
				lean = "radial",
				wid = {16, 28},
				thick = {3.5, 6.5},
				len = {16, 30},
				tilt = {12, 34},
				yaw = 20,
				pitch = 8,
				show = 0.55,
				rise = 0.16,
				t = 1.17,
				sweep = 0.8,
				delay = {0, 0.06},
				end_at = {5.05, 5.75},
				big = {
					frac = 0.2,
					k = 1.3,
				},
				ground = true,
				mesh = "TectonicPlates",
			},
			{
				hold = {1, 1},
				sink = 0.4,
				name = "TectonicPlates",
				count = 8,
				ring = true,
				at = {0, -0.3},
				r = {0.07, 0.13},
				lean = "radial",
				wid = {12, 18},
				thick = {3, 5},
				len = {12, 18},
				tilt = {16, 32},
				yaw = 20,
				pitch = 8,
				show = 0.55,
				rise = 0.16,
				t = 1.394,
				delay = {0, 0.05},
				end_at = {2.75, 2.79},
				["end"] = "shatter",
				ground = true,
				mesh = "TectonicPlates",
				shatter = {
					{
						name = "PlateBreak",
						texture = "om_cubes_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 14},
						},
						shape = {
							type = "Box",
							size = {14, 4, 14},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {70, 70},
						speed = {30, 70},
						drag = 0.4,
						accel = {0, -150, 0},
						lifetime = {0.8, 1.2},
						size = {
							{0, 2.8, 1},
							{1, 2.2, 0.8},
						},
						color = {
							{
								0,
								{128, 118, 106},
							},
							{
								1,
								{100, 92, 82},
							},
						},
						rotation = {0, 360},
						rot_speed = {-400, 400},
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
					},
					{
						name = "PlateBreakDust",
						texture = "fx_smoke_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 3},
						},
						shape = {
							type = "Box",
							size = {12, 3, 12},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {60, 60},
						speed = {8, 18},
						drag = 2,
						accel = {0, 3, 0},
						lifetime = {1, 1.4},
						size = {
							{0, 10, 2},
							{1, 24, 3},
						},
						transparency = {
							{0, 0.4, 0},
							{0.4, 0.58, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{160, 150, 136},
							},
							{
								0.5,
								{138, 128, 116},
							},
							{
								1,
								{112, 104, 94},
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
			},
			{
				hold = {1, 1},
				sink = 0.6,
				name = "RubbleSlabs",
				count = 70,
				r = {0.08, 1},
				lean = "radial",
				wid = {5, 10},
				thick = {1.2, 2.6},
				len = {5, 10},
				tilt = {15, 45},
				yaw = 15,
				pitch = 10,
				show = 0.6,
				rise = 0.1,
				t = 1.15,
				sweep = 0.8,
				delay = {0, 0.08},
				end_at = {4.95, 5.65},
				ground = true,
				mesh = "RubbleSlabs",
			},
			{
				hold = {1, 1},
				sink = 0.4,
				name = "CrystalShards",
				count = 50,
				r = {0.15, 0.95},
				hex = true,
				lean = "radial",
				wid = {2.4, 4.4},
				thick = {6, 15},
				len = {2.4, 4.4},
				tilt = {8, 35},
				yaw = 25,
				pitch = 10,
				show = 0.8,
				rise = 0.12,
				t = 1.25,
				sweep = 0.8,
				delay = {0, 0.1},
				end_at = {4.33, 4.45},
				["end"] = "shatter",
				ice = {
					color = {94, 229, 224},
					material = "Neon",
					transparency = 0.15,
				},
				tip = 0.85,
				mesh = "CrystalShards",
				shatter = {
					{
						name = "ShardBurst",
						texture = "mf_shard_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 5},
						},
						shape = {
							type = "Box",
							size = {3, 10, 3},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {14, 38},
						drag = 0.5,
						accel = {0, -110, 0},
						lifetime = {0.6, 1.1},
						size = {
							{0, 1.8, 0.6},
							{1, 1.3, 0.4},
						},
						transparency = {
							{0, 0, 0},
							{0.85, 0.1, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{215, 255, 252},
							},
							{
								0.4,
								{94, 229, 224},
							},
							{
								1,
								{52, 147, 152},
							},
						},
						light_emission = 0.6,
						brightness = 1.5,
						rotation = {0, 360},
						rot_speed = {-500, 500},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardGlints",
						texture = "kk_star_09",
						emit = {
							{0, 2},
						},
						shape = {
							type = "Box",
							size = {3, 10, 3},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {3, 9},
						drag = 2,
						lifetime = {0.3, 0.55},
						size = {
							{0, 0, 0},
							{0.08, 4.48, 0},
							{0.22, 1.96, 0},
							{0.38, 4.76, 0},
							{0.55, 1.68, 0},
							{0.72, 3.92, 0},
							{1, 0, 0},
						},
						color = {
							{
								0,
								{255, 255, 255},
							},
							{
								0.5,
								{205, 255, 250},
							},
							{
								1,
								{120, 235, 228},
							},
						},
						light_emission = 1,
						brightness = 2,
						rotation = {0, 45},
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
						name = "ShardFire",
						texture = "fx_fire_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 2},
						},
						shape = {
							type = "Box",
							size = {3, 10, 3},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {40, 40},
						speed = {6, 14},
						drag = 1.5,
						accel = {0, 8, 0},
						lifetime = {0.35, 0.6},
						size = {
							{0, 3, 1},
							{0.3, 7, 1.5},
							{1, 2, 0},
						},
						transparency = {
							{0, 0.15, 0},
							{0.6, 0.42, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{175, 255, 250},
							},
							{
								0.3,
								{100, 236, 230},
							},
							{
								0.65,
								{60, 185, 186},
							},
							{
								1,
								{39, 121, 127},
							},
						},
						light_emission = 1,
						brightness = 1.45,
						rotation = {0, 360},
						rot_speed = {0, 0},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardDust",
						texture = "fx_smoke_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 2},
						},
						shape = {
							type = "Box",
							size = {3, 10, 3},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {60, 60},
						speed = {4, 10},
						drag = 2,
						accel = {0, 2, 0},
						lifetime = {0.8, 1.2},
						size = {
							{0, 4, 1},
							{1, 11, 2},
						},
						transparency = {
							{0, 0.45, 0},
							{0.4, 0.6, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{160, 150, 136},
							},
							{
								0.5,
								{138, 128, 116},
							},
							{
								1,
								{112, 104, 94},
							},
						},
						rotation = {0, 360},
						rot_speed = {-30, 30},
						light_emission = 0,
						brightness = 1,
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
				},
			},
			{
				hold = {1, 1},
				sink = 0.4,
				name = "TectonicCrystal",
				count = 1,
				at = {0, -0.3},
				r = {0, 0},
				centered = true,
				hex = true,
				part_name = "TectonicCrystal",
				lean = "random",
				wid = {30, 30},
				thick = {115, 115},
				len = {30, 30},
				tilt = {0, 0},
				yaw = 180,
				pitch = 0,
				show = 0.93,
				rise = 0.3,
				t = 2.75,
				delay = {0, 0},
				end_at = {4.35, 4.35},
				["end"] = "shatter",
				ice = {
					color = {94, 229, 224},
					material = "Glass",
					transparency = 0.3,
				},
				tip = 0.85,
				mesh = "TectonicCrystal",
				shatter = {
					{
						name = "ShardBurst",
						texture = "mf_shard_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 90},
						},
						shape = {
							type = "Box",
							size = {26, 105, 26},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {14, 38},
						drag = 0.5,
						accel = {0, -110, 0},
						lifetime = {0.6, 1.1},
						size = {
							{0, 1.8, 0.6},
							{1, 1.3, 0.4},
						},
						transparency = {
							{0, 0, 0},
							{0.85, 0.1, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{215, 255, 252},
							},
							{
								0.4,
								{94, 229, 224},
							},
							{
								1,
								{52, 147, 152},
							},
						},
						light_emission = 0.6,
						brightness = 1.5,
						rotation = {0, 360},
						rot_speed = {-500, 500},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardGlints",
						texture = "kk_star_09",
						emit = {
							{0, 30},
						},
						shape = {
							type = "Box",
							size = {26, 105, 26},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {3, 9},
						drag = 2,
						lifetime = {0.3, 0.55},
						size = {
							{0, 0, 0},
							{0.08, 4.48, 0},
							{0.22, 1.96, 0},
							{0.38, 4.76, 0},
							{0.55, 1.68, 0},
							{0.72, 3.92, 0},
							{1, 0, 0},
						},
						color = {
							{
								0,
								{255, 255, 255},
							},
							{
								0.5,
								{205, 255, 250},
							},
							{
								1,
								{120, 235, 228},
							},
						},
						light_emission = 1,
						brightness = 2,
						rotation = {0, 45},
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
						name = "ShardFire",
						texture = "fx_fire_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 40},
						},
						shape = {
							type = "Box",
							size = {26, 105, 26},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {40, 40},
						speed = {6, 14},
						drag = 1.5,
						accel = {0, 8, 0},
						lifetime = {0.35, 0.6},
						size = {
							{0, 3, 1},
							{0.3, 7, 1.5},
							{1, 2, 0},
						},
						transparency = {
							{0, 0.15, 0},
							{0.6, 0.42, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{175, 255, 250},
							},
							{
								0.3,
								{100, 236, 230},
							},
							{
								0.65,
								{60, 185, 186},
							},
							{
								1,
								{39, 121, 127},
							},
						},
						light_emission = 1,
						brightness = 1.45,
						rotation = {0, 360},
						rot_speed = {0, 0},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardDust",
						texture = "fx_smoke_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 13},
						},
						shape = {
							type = "Box",
							size = {26, 105, 26},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {60, 60},
						speed = {4, 10},
						drag = 2,
						accel = {0, 2, 0},
						lifetime = {0.8, 1.2},
						size = {
							{0, 4, 1},
							{1, 11, 2},
						},
						transparency = {
							{0, 0.45, 0},
							{0.4, 0.6, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{160, 150, 136},
							},
							{
								0.5,
								{138, 128, 116},
							},
							{
								1,
								{112, 104, 94},
							},
						},
						rotation = {0, 360},
						rot_speed = {-30, 30},
						light_emission = 0,
						brightness = 1,
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
				},
			},
			{
				hold = {1, 1},
				sink = 0.4,
				name = "TectonicCore",
				count = 1,
				at = {0, -0.3},
				r = {0, 0},
				centered = true,
				hex = true,
				lean = "random",
				wid = {17, 17},
				thick = {105, 105},
				len = {17, 17},
				tilt = {0, 0},
				yaw = 180,
				pitch = 0,
				show = 0.93,
				rise = 0.3,
				t = 2.75,
				delay = {0, 0},
				end_at = {4.35, 4.35},
				["end"] = "shatter",
				ice = {
					color = {60, 205, 205},
					material = "Neon",
					transparency = 0.05,
				},
				tip = 0.85,
				mesh = "TectonicCrystal",
			},
			{
				hold = {1, 1},
				sink = 0.4,
				name = "TectonicCrystal",
				count = 10,
				ring = true,
				at = {0, -0.3},
				r = {0.1, 0.16},
				hex = true,
				lean = "radial",
				wid = {12, 18},
				thick = {48, 82},
				len = {12, 18},
				tilt = {16, 30},
				yaw = 10,
				pitch = 6,
				show = 0.9,
				rise = 0.26,
				t = 2.8,
				delay = {0, 0.08},
				end_at = {4.35, 4.38},
				["end"] = "shatter",
				ice = {
					color = {110, 236, 232},
					material = "Glass",
					transparency = 0.25,
				},
				tip = 0.85,
				mesh = "TectonicCrystal",
				shatter = {
					{
						name = "ShardBurst",
						texture = "mf_shard_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 30},
						},
						shape = {
							type = "Box",
							size = {12, 60, 12},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {14, 38},
						drag = 0.5,
						accel = {0, -110, 0},
						lifetime = {0.6, 1.1},
						size = {
							{0, 1.8, 0.6},
							{1, 1.3, 0.4},
						},
						transparency = {
							{0, 0, 0},
							{0.85, 0.1, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{215, 255, 252},
							},
							{
								0.4,
								{94, 229, 224},
							},
							{
								1,
								{52, 147, 152},
							},
						},
						light_emission = 0.6,
						brightness = 1.5,
						rotation = {0, 360},
						rot_speed = {-500, 500},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardGlints",
						texture = "kk_star_09",
						emit = {
							{0, 10},
						},
						shape = {
							type = "Box",
							size = {12, 60, 12},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {3, 9},
						drag = 2,
						lifetime = {0.3, 0.55},
						size = {
							{0, 0, 0},
							{0.08, 4.48, 0},
							{0.22, 1.96, 0},
							{0.38, 4.76, 0},
							{0.55, 1.68, 0},
							{0.72, 3.92, 0},
							{1, 0, 0},
						},
						color = {
							{
								0,
								{255, 255, 255},
							},
							{
								0.5,
								{205, 255, 250},
							},
							{
								1,
								{120, 235, 228},
							},
						},
						light_emission = 1,
						brightness = 2,
						rotation = {0, 45},
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
						name = "ShardFire",
						texture = "fx_fire_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 14},
						},
						shape = {
							type = "Box",
							size = {12, 60, 12},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {40, 40},
						speed = {6, 14},
						drag = 1.5,
						accel = {0, 8, 0},
						lifetime = {0.35, 0.6},
						size = {
							{0, 3, 1},
							{0.3, 7, 1.5},
							{1, 2, 0},
						},
						transparency = {
							{0, 0.15, 0},
							{0.6, 0.42, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{175, 255, 250},
							},
							{
								0.3,
								{100, 236, 230},
							},
							{
								0.65,
								{60, 185, 186},
							},
							{
								1,
								{39, 121, 127},
							},
						},
						light_emission = 1,
						brightness = 1.45,
						rotation = {0, 360},
						rot_speed = {0, 0},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardDust",
						texture = "fx_smoke_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 4},
						},
						shape = {
							type = "Box",
							size = {12, 60, 12},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {60, 60},
						speed = {4, 10},
						drag = 2,
						accel = {0, 2, 0},
						lifetime = {0.8, 1.2},
						size = {
							{0, 4, 1},
							{1, 11, 2},
						},
						transparency = {
							{0, 0.45, 0},
							{0.4, 0.6, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{160, 150, 136},
							},
							{
								0.5,
								{138, 128, 116},
							},
							{
								1,
								{112, 104, 94},
							},
						},
						rotation = {0, 360},
						rot_speed = {-30, 30},
						light_emission = 0,
						brightness = 1,
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
				},
			},
			{
				hold = {1, 1},
				sink = 0.4,
				name = "CrystalShards",
				count = 24,
				at = {0, -0.3},
				r = {0.15, 0.32},
				hex = true,
				lean = "radial",
				wid = {5, 9},
				thick = {18, 40},
				len = {5, 9},
				tilt = {14, 38},
				yaw = 15,
				pitch = 8,
				show = 0.85,
				rise = 0.2,
				t = 2.85,
				sweep = 0.25,
				delay = {0, 0.06},
				end_at = {4.36, 4.41},
				["end"] = "shatter",
				ice = {
					color = {94, 229, 224},
					material = "Neon",
					transparency = 0.15,
				},
				tip = 0.85,
				mesh = "CrystalShards",
				shatter = {
					{
						name = "ShardBurst",
						texture = "mf_shard_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 10},
						},
						shape = {
							type = "Box",
							size = {5, 20, 5},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {14, 38},
						drag = 0.5,
						accel = {0, -110, 0},
						lifetime = {0.6, 1.1},
						size = {
							{0, 1.8, 0.6},
							{1, 1.3, 0.4},
						},
						transparency = {
							{0, 0, 0},
							{0.85, 0.1, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{215, 255, 252},
							},
							{
								0.4,
								{94, 229, 224},
							},
							{
								1,
								{52, 147, 152},
							},
						},
						light_emission = 0.6,
						brightness = 1.5,
						rotation = {0, 360},
						rot_speed = {-500, 500},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardGlints",
						texture = "kk_star_09",
						emit = {
							{0, 4},
						},
						shape = {
							type = "Box",
							size = {5, 20, 5},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {3, 9},
						drag = 2,
						lifetime = {0.3, 0.55},
						size = {
							{0, 0, 0},
							{0.08, 4.48, 0},
							{0.22, 1.96, 0},
							{0.38, 4.76, 0},
							{0.55, 1.68, 0},
							{0.72, 3.92, 0},
							{1, 0, 0},
						},
						color = {
							{
								0,
								{255, 255, 255},
							},
							{
								0.5,
								{205, 255, 250},
							},
							{
								1,
								{120, 235, 228},
							},
						},
						light_emission = 1,
						brightness = 2,
						rotation = {0, 45},
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
						name = "ShardFire",
						texture = "fx_fire_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 5},
						},
						shape = {
							type = "Box",
							size = {5, 20, 5},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {40, 40},
						speed = {6, 14},
						drag = 1.5,
						accel = {0, 8, 0},
						lifetime = {0.35, 0.6},
						size = {
							{0, 3, 1},
							{0.3, 7, 1.5},
							{1, 2, 0},
						},
						transparency = {
							{0, 0.15, 0},
							{0.6, 0.42, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{175, 255, 250},
							},
							{
								0.3,
								{100, 236, 230},
							},
							{
								0.65,
								{60, 185, 186},
							},
							{
								1,
								{39, 121, 127},
							},
						},
						light_emission = 1,
						brightness = 1.45,
						rotation = {0, 360},
						rot_speed = {0, 0},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "ShardDust",
						texture = "fx_smoke_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 2},
						},
						shape = {
							type = "Box",
							size = {5, 20, 5},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {60, 60},
						speed = {4, 10},
						drag = 2,
						accel = {0, 2, 0},
						lifetime = {0.8, 1.2},
						size = {
							{0, 4, 1},
							{1, 11, 2},
						},
						transparency = {
							{0, 0.45, 0},
							{0.4, 0.6, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{160, 150, 136},
							},
							{
								0.5,
								{138, 128, 116},
							},
							{
								1,
								{112, 104, 94},
							},
						},
						rotation = {0, 360},
						rot_speed = {-30, 30},
						light_emission = 0,
						brightness = 1,
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
				},
			},
		},
	},
}

-- PEBLEDON ULTIMATE (Erupción tectónica): hunde los puños en el suelo y es el epicentro: las venas turquesa se riegan por una zona gigante, el mundo se oscurece y tiembla; el suelo se rompe en placas enormes y salen géiseres de fuego cian en cadena del centro hacia afuera; delante de él brota una montaña de cristal de más de 100 studs que se carga de luz y revienta en una lluvia de cristales con un pilar de energía hasta el cielo. cf = Pebledon en el suelo, mirando hacia adelante (la montaña brota delante). Golpes: el frente de la ruptura (TectonicEruptionFrontTime), la montaña a los 2.75 s y la explosión a los 4.35 s (ver TectonicEruptionTimes).
-- radius = radio de la zona en studs (por defecto 150 × escala); height = altura del pilar (por defecto 420 × escala).
function PebledonVFX.TectonicEruption(cf: CFrame, radius: number?, height: number?, scale: number?, shake: number?): Part
	return playZone(SPEC_TectonicEruption, cf, scale, radius, height, shake)
end

-- segundos (desde la llamada) de cada momento: para sincronizar el daño, el sonido o la cámara
PebledonVFX.TectonicEruptionTimes = {
	Slam = 0,
	Rupture = 1.15,
	Mountain = 2.75,
	Detonation = 4.35,
	End = 6.65,
}

-- radio de la zona (studs a escala 1; multiplícalo por la escala)
PebledonVFX.TectonicEruptionRadius = 150
-- segundos (desde la llamada) en que el frente que sale del centro pasa a `distance` studs (usa el
-- mismo radio con que llamaste el efecto): para aplicar el daño a cada enemigo cuando lo alcanza
function PebledonVFX.TectonicEruptionFrontTime(distance: number, radius: number?): number
	return 1.15 + 0.8 * math.clamp(distance / (radius or 150), 0, 1)
end
-- a cuántos studs delante del centro brota la montaña (a escala 1; multiplícalo por la escala)
PebledonVFX.TectonicEruptionMountainOffset = 45
-- hasta dónde golpea la montaña al brotar, alrededor de ella (studs a escala 1; multiplícalo por la escala): a quien esté ahí lo manda a volar
PebledonVFX.TectonicEruptionMountainRadius = 26

return PebledonVFX
