--!nonstrict
--[[
	MoonfangVFX — VFX del lobo kaiju lunar de cristal (plata, hielo y azul cristal) para MOONFANG
	(generado automáticamente desde vfx_moonfang.py; edita allí y regenera)

	USO (en el CLIENTE, por ejemplo al recibir un RemoteEvent del servidor):
		local MoonfangVFX = require(ReplicatedStorage.MoonfangVFX)
		MoonfangVFX.MoonBite(rival, 1, 1)                        -- M1 mordiscos 1-3
		MoonfangVFX.MoonBiteFinisher(rival, 1, 1)                -- M1 mordisco 4 (remate)
		MoonfangVFX.MoonFang(rival, 1, 1)                        -- pesado
		MoonfangVFX.MoonGuardHit(moonfang, 1, 1)                 -- cada golpe bloqueado
		MoonfangVFX.CrescentWave(CFrame.lookAt(origen, origen + direccion), 130, 1, 1)   -- skill 1
		MoonfangVFX.IceWave(CFrame.lookAt(origen, origen + direccion), nil, nil, 1, 1)  -- skill 2
		MoonfangVFX.FrostRoar(cabeza.CFrame, 1, 1)               -- skill 3 (el empujón: FrostRoarImpact / FrostRoarRadius)
		MoonfangVFX.Eclipse(CFrame.new(centroEnElSuelo), nil, nil, 1, 1)   -- skill 4 (ulti)

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

local MoonfangVFX = {}

-- Pega aquí los IDs de las imágenes subidas
MoonfangVFX.TEXTURES = {
	fx_fog2001 = "rbxassetid://0",
	fx_glow = "rbxassetid://0",
	fx_halo = "rbxassetid://0",
	fx_particle02 = "rbxassetid://0",
	fx_smoke_2x2 = "rbxassetid://0",
	fx_spark002 = "rbxassetid://0",
	fx_wind_swirl = "rbxassetid://0",
	kk_circle_02 = "rbxassetid://0",
	kk_smoke_04 = "rbxassetid://0",
	kk_smoke_07 = "rbxassetid://0",
	kk_star_06 = "rbxassetid://0",
	kk_star_08 = "rbxassetid://0",
	kk_star_09 = "rbxassetid://0",
	kk_trace_01 = "rbxassetid://0",
	kk_trace_03 = "rbxassetid://0",
	kz_beam_ring = "rbxassetid://0",
	kz_wind_arcs = "rbxassetid://0",
	mf_blade_glow = "rbxassetid://0",
	mf_blade_line = "rbxassetid://0",
	mf_blade_solid = "rbxassetid://0",
	mf_chomp_4x4 = "rbxassetid://0",
	mf_crescent = "rbxassetid://0",
	mf_eclipse_sigil = "rbxassetid://0",
	mf_frost_cracks = "rbxassetid://0",
	mf_frost_patch = "rbxassetid://0",
	mf_ice_spikes_2x2 = "rbxassetid://0",
	mf_moon_eclipse_4x4 = "rbxassetid://0",
	mf_moonbeam = "rbxassetid://0",
	mf_shard_2x2 = "rbxassetid://0",
	mf_spike = "rbxassetid://0",
	om_cubes_2x2 = "rbxassetid://0",
}

-- Dónde se crean los efectos (puedes cambiarlo por una carpeta de VFX)
MoonfangVFX.Parent = workspace :: Instance
-- Multiplicador de cantidad de partículas (bájalo en dispositivos lentos, p.ej. 0.6)
MoonfangVFX.Quality = 1
-- Luz breve en el impacto (del color del efecto)
MoonfangVFX.UseLight = true
-- Las ULTIMATES oscurecen el mundo y hacen destellar la pantalla de quien está cerca (solo en el cliente)
MoonfangVFX.ScreenFX = true
-- Los golpes (corte, mordisco) se adaptan al alto del rival si le pasas su Model o su Part
MoonfangVFX.HitAutoSize = true
-- Color y material de los cubos de destrucción (nil = los del suelo donde sale el efecto)
MoonfangVFX.CubeColor = nil :: Color3?
MoonfangVFX.CubeMaterial = nil :: Enum.Material?
-- Modelos (MeshPart) para las piezas sólidas, por nombre de capa: si pones uno, el módulo lo clona en vez de
-- un bloque. Por ejemplo: MoonfangVFX.Meshes.IceChunks = ReplicatedStorage.MoonfangMeshes.IceChunk
MoonfangVFX.Meshes = {} :: { [string]: Instance }

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
	e.Texture = MoonfangVFX.TEXTURES[L.texture] or ""
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
			e.Rate = rate * MoonfangVFX.Quality
			e.Enabled = rate > 0.05
			task.wait(0.05)
		end
		if e.Parent then
			e.Enabled = false
		end
	end)
end

local function quality(n: number): number
	return math.max(1, math.floor(n * MoonfangVFX.Quality + 0.5))
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
		d.Texture = MoonfangVFX.TEXTURES[L.texture] or ""
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
	local template = MoonfangVFX.Meshes[L.name]
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
			te.Rate = TL.rate * MoonfangVFX.Quality
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
			acc[i] += rate * MoonfangVFX.Quality * dt
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
function MoonfangVFX.Shake(intensity: number, duration: number?)
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
function MoonfangVFX.ShakeRamp(i0: number, i1: number, duration: number, power: number?)
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
	if MoonfangVFX.UseLight and spec.light then
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
			task.delay(r[1], MoonfangVFX.ShakeRamp, shake * r[3], shake * r[4], r[2] - r[1], r[5])
		end
		if spec.shakes then
			-- {t, intensidad relativa, duración}
			for _, sk in spec.shakes do
				task.delay(sk[1], MoonfangVFX.Shake, shake * sk[2], sk[3])
			end
		elseif not spec.shake_ramp then
			MoonfangVFX.Shake(shake, 0.9)
		end
	end
	-- se destruye cuando ya murió la última partícula (cleanup >= duración)
	Debris:AddItem(holder, spec.cleanup)
end

-- ---------------------------------------------------------------- losas y bloques que saltan del suelo
-- Los usan la Medialuna (las filas a los lados del corte y el cráter) y la Ola de hielo (el campo del triángulo).
-- Cada pieza aparece a su tiempo con el color y el material del suelo (o de hielo), sube con un rebote, se queda y
-- se hunde; con end = "shatter" desaparece de golpe al terminar y revienta en partículas. Se puede cambiar por un
-- modelo de Blender en MoonfangVFX.Meshes[mesh].
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
			local template = if L.mesh then MoonfangVFX.Meshes[L.mesh] else nil
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
				if L.L.veins then -- venas que brillan en la cara de arriba (la roca de Pebledon)
					local V = L.L.veins
					local d = Instance.new("Decal")
					d.Face = Enum.NormalId.Top
					d.Texture = MoonfangVFX.TEXTURES[V.texture] or ""
					local glow = (1 + 1.5 * (V.light_emission or 0)) / 255
					d.Color3 = Color3.new(V.color[1] * glow, V.color[2] * glow, V.color[3] * glow)
					d.Transparency = V.transparency or 0
					d.Parent = p
				end
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
				it.pe.Rate = it.E.rate * MoonfangVFX.Quality * (0.25 + 0.75 * u)
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
		for _ = 1, math.floor(G.count * MoonfangVFX.Quality + 0.5) do
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
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf, MoonfangVFX.Parent)
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
local function _playConeHead(spec: Layer, head: CFrame, scale: number?, length: number?, shake: number?,
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
		CFrame.lookAt(R[1].pos, R[1].pos + dir), MoonfangVFX.Parent)
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
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), lookCF(A0, lastDir), MoonfangVFX.Parent)
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
		b.Texture = MoonfangVFX.TEXTURES[B.texture] or ""
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
	if MoonfangVFX.UseLight then
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
				MoonfangVFX.Shake(shake * sk[2], sk[3])
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

local function _playRefract(spec: Layer, crystal: any, targets: { any }, scale: number?, shake: number?): RefractControl
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
	local k = if height and (MoonfangVFX :: any).HitAutoSize then math.clamp(height / H.ref, 0.5, 4) else 1
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
		acc += rate * mul * MoonfangVFX.Quality * dt
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
	if not MoonfangVFX.UseLight or not spec.lights then
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
	local opts = MoonfangVFX :: any
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
		im.Image = MoonfangVFX.TEXTURES[L.texture] or ""
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
			b.Texture = MoonfangVFX.TEXTURES[B.texture] or ""
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

-- Grietas que corren por el suelo (zcracks): tramos rectos (de Neon) que crecen de su punto de partida a su punto
-- final entre sus segundos t0 y t1; así una grieta avanza, se ramifica y se cruza con otras. Nacen calientes (hot) y se
-- enfrían en `birth` s; tr y heat (en segundos desde la llamada) las hacen destellar, latir y apagarse todas a la vez.
-- segs = {x0, z0, x1, z1, t0, t1, ancho, nivel}: coordenadas en fracciones del radio; con menos calidad se saltan los
-- niveles altos (0 = fisuras, 1 = ramas, 2 = grietas que las cruzan).
local function runZoneCracks(C: any, Z: Zone)
	local holder = Z.holder
	local segs = C.segs
	local parts: { [number]: Part } = {}
	local shaped: { [number]: boolean } = {}
	local base = Color3.fromRGB(C.color[1], C.color[2], C.color[3])
	local hot = Color3.fromRGB(C.hot[1], C.hot[2], C.hot[3])
	local mat = (Enum.Material :: any)[C.material or "Neon"]
	local maxLevel = MoonfangVFX.Quality * 2.5
	local t0 = time()
	local lastTr, lastHeat = -1, -1
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = time() - t0
		if not holder.Parent or t > C.t_end then
			conn:Disconnect()
			for _, p in parts do
				p:Destroy()
			end
			return
		end
		local tr = evalNum(C.tr, t)
		local heat = evalNum(C.heat, t)
		local global = math.abs(tr - lastTr) > 0.003 or math.abs(heat - lastHeat) > 0.003
		lastTr, lastHeat = tr, heat
		for i, sg in segs do
			if t < sg[5] or (sg[8] or 0) > maxLevel then
				continue
			end
			local p: Part
			local had = parts[i]
			if had then
				p = had
			else
				p = bladePart("Crack", holder)
				p.Material = mat
				parts[i] = p
			end
			local age = t - sg[5]
			local grow = t < sg[6]
			if grow or not shaped[i] then
				shaped[i] = not grow
				local ax, az = sg[1] * Z.R, sg[2] * Z.R
				local dx, dz = sg[3] * Z.R - ax, sg[4] * Z.R - az
				local full = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
				local len = math.max(full * (if grow then age / math.max(sg[6] - sg[5], 1e-3) else 1), 0.05)
				dx, dz = dx / full, dz / full
				p.Size = Vector3.new(len, C.thick * Z.s, sg[7] * Z.s)
				p.CFrame = holder.CFrame * CFrame.new(ax + dx * len / 2, C.height * Z.s, az + dz * len / 2)
					* CFrame.Angles(0, math.atan2(-dz, dx), 0)
			end
			if age < C.birth + 0.05 or global then
				p.Color = base:Lerp(hot, math.max(heat, 1 - math.min(age / C.birth, 1)))
				p.Transparency = tr
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
		local n = math.floor((if G.pts then #G.pts else G.count) * MoonfangVFX.Quality + 0.5)
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
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), flat, MoonfangVFX.Parent)
	local gColor, gMaterial, gy = groundLook(pos, { holder })
	if gy and math.abs(gy - pos.Y) < snap then
		holder.CFrame = flat + Vector3.new(0, gy - pos.Y, 0)
	end
	local Z: Zone = {
		holder = holder, R = R, H = H, s = s, kR = R / spec.zone.radius, kH = H / spec.zone.height,
		groundY = holder.Position.Y, groundColor = gColor, groundMaterial = gMaterial,
	}
	local spinners: { [number]: BasePart } = {}
	-- los eventos de las capas (ring_emit) van en una sola cola que recorre un solo Heartbeat (miles de task.delay
	-- serían miles de hilos)
	local queue: { { t: number, fn: () -> () } } = {}
	local function at(t: number, fn: () -> ())
		table.insert(queue, { t = t, fn = fn })
	end
	for _, L in spec.layers do
		if L.orb then
			continue -- van pegadas al proyectil (runOrb)
		elseif L.bill then
			local k = zoneK(L, Z)
			for _, ev in L.ring_emit or {} do
				local lcf = zoneAt(L, Z, zoneLocal(Z, ev[3], ev[4], zoneY(L, Z, ev[5]), nil, false))
				at(ev[1], function()
					playBill(L, Z, k, ev[2], lcf)
				end)
			end
		elseif L.decal then
			local k = zoneK(L, Z)
			for _, ev in L.ring_emit or {} do
				local lcf = zoneAt(L, Z, zoneLocal(Z, ev[3], ev[4], zoneY(L, Z, ev[5]), nil, false))
				at(ev[1], function()
					playDecalAt(L, holder, k, ev[2], holder.CFrame * lcf)
				end)
			end
		elseif L.type == "meteor" then
			-- rocas de verdad (Parts) con estela que salen de cada punto (p. ej. las que lanza un géiser)
			for _, ev in L.ring_emit or {} do
				local lcf = zoneAt(L, Z, zoneLocal(Z, ev[3], ev[4], zoneY(L, Z, ev[5]), L.pitch, L.radial))
				local n = quality(ev[2])
				at(ev[1], function()
					local w = holder.CFrame * lcf
					launchMeteors(L, holder, Z.s, n, w.Position, Z.groundY, w)
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
				at(ev[1], function()
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
	if #queue > 0 then
		table.sort(queue, function(x, y)
			return x.t < y.t
		end)
		local qi = 1
		local function fire(t: number)
			while qi <= #queue and queue[qi].t <= t do
				queue[qi].fn()
				qi += 1
			end
		end
		fire(0)
		if qi <= #queue then
			local q0 = time()
			local qconn: RBXScriptConnection
			qconn = RunService.Heartbeat:Connect(function()
				if not holder.Parent then
					qconn:Disconnect()
					return
				end
				fire(time() - q0)
				if qi > #queue then
					qconn:Disconnect()
				end
			end)
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
	if spec.zcracks then
		runZoneCracks(spec.zcracks, Z)
	end
	zoneLights(spec, Z)
	return holder, Z
end

-- Corrección de color y destellos de pantalla de una zona (solo en el cliente y cerca de la zona): con screen.cc =
-- {t, brillo, contraste, saturación, tinte R, G, B} el mundo se oscurece (p. ej. mientras la luna se eclipsa) y con
-- screen.flash = {t, alfa, subida, bajada} la pantalla destella. Se nota entero dentro de la zona y se apaga a
-- screen.range × radio. MoonfangVFX.ScreenFX = false lo desactiva.
local function runScreen(spec: Layer, Z: Zone)
	local Sc = spec.screen
	if not (MoonfangVFX :: any).ScreenFX or not RunService:IsClient() then
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
local function _playStompZone(spec: Layer, foot: any, target: any, scale: number?, shake: number?): Part
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
	if (MoonfangVFX :: any).Lens and O.lens then
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
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), cf0, MoonfangVFX.Parent)
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
	if MoonfangVFX.UseLight then
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
			local rate = (L.rate or 0) * it.share * k2 * gate * MoonfangVFX.Quality
			it.e.Rate = rate
			it.e.Enabled = rate > 0.01
		end
		-- oleadas
		local surgeK = 0
		if Au.surge and Au.surge > 0 then
			if t - lastSurge >= Au.surge and on > 0.5 then
				lastSurge = t
				for _, it in items do
					local n = (it.L.surge or 0) * it.share * ctl.Intensity * MoonfangVFX.Quality
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
-- suelo; las de hielo se pueden cambiar por un modelo en MoonfangVFX.Meshes.IceSlab.
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
		if MoonfangVFX.Quality < 0.7 and si > 3 and si % 2 == 1 then
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
			b.Texture = MoonfangVFX.TEXTURES[S.texture] or ""
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
	if B.light and MoonfangVFX.UseLight then
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
				if rng:NextNumber() <= MoonfangVFX.Quality then
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
				d.Texture = MoonfangVFX.TEXTURES[G.frost.texture] or ""
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
				em.pe.Rate = em.E.rate * MoonfangVFX.Quality
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

local function _playCataclysm(spec: Layer, impactSpec: Layer, epicenter: any, victimsIn: any, options: { [string]: any }?): CataclysmControl
	local opt: { [string]: any } = options or {}
	local Cf = spec.cataclysm
	local T, Fd, Hh, Rk = Cf.t, Cf.field, Cf.hole, Cf.rocks
	local plan = cataclysmPlan(spec, epicenter, victimsIn, opt)
	local R, k, Hs, C, B = plan.R, plan.k, plan.Hs, plan.C, plan.B
	local exclude = plan.exclude
	local shakeK = if opt.Shake == nil then 1 else opt.Shake
	local Q = MoonfangVFX.Quality
	local victimList: { any } = if typeof(victimsIn) == "table" then victimsIn elseif victimsIn ~= nil then { victimsIn } else {}
	local holder = invisiblePart("KZ_" .. spec.name, Vector3.new(0.2, 0.2, 0.2), CFrame.new(C), MoonfangVFX.Parent)
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
		b.Texture = MoonfangVFX.TEXTURES[Bs.texture] or ""
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
		d.Texture = MoonfangVFX.TEXTURES[tex] or ""
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
				dd.Texture = MoonfangVFX.TEXTURES[tex] or ""
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
	for i = 1, if (MoonfangVFX :: any).Lens == false then 0 else 3 do
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
			h.lens.Transparency = if (MoonfangVFX :: any).Lens == false then 1 else 1 - 0.38 * birth
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

local SPEC_MoonBite = {
	name = "MoonBite",
	duration = 1.3,
	cleanup = 2.24,
	layers = {
		{
			name = "Chomp",
			texture = "mf_chomp_4x4",
			flipbook = {
				layout = "Grid4x4",
				mode = "OneShot",
				fps = 30,
				startRandom = false,
			},
			emit = {
				{0, 1},
			},
			lifetime = {0.4, 0.4},
			size = {
				{0, 26, 0},
				{1, 27.04, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 235, 255},
				},
				{
					0.3,
					{255, 255, 255},
				},
				{
					0.6,
					{170, 210, 255},
				},
				{
					1,
					{120, 175, 255},
				},
			},
			light_emission = 0.8,
			brightness = 1.4,
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
			name = "ChompGlow",
			texture = "fx_glow",
			emit = {
				{0.1, 1},
			},
			lifetime = {0.24, 0.24},
			size = {
				{0, 10.4, 0},
				{0.3, 19.5, 0},
				{1, 22.1, 0},
			},
			transparency = {
				{0, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
				},
			},
			light_emission = 1,
			brightness = 0.8,
			zoffset = -1,
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
				{0.1, 1},
			},
			lifetime = {0.16, 0.18},
			size = {
				{0, 6, 0},
				{0.3, 10, 0},
				{1, 11, 0},
			},
			transparency = {
				{0, 0.6625, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 0.405,
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
				{0.1, 1},
			},
			lifetime = {0.14, 0.14},
			size = {
				{0, 10, 0},
				{0.4, 9.5, 0},
				{1, 6, 0},
			},
			transparency = {
				{0, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 0.72,
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
				{0.1, 1},
			},
			lifetime = {0.22, 0.24},
			size = {
				{0, 6, 0},
				{1, 30, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
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
				{0.09, 12},
				{0.12, 6},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
				{0.09, 12},
				{0.12, 6},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			name = "Shards",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Box",
				size = {18, 2, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.22, 10},
			},
			direction = "Back",
			spread = {70, 70},
			speed = {25, 55},
			drag = 0.6,
			accel = {0, -90, 0},
			lifetime = {0.4, 0.7},
			size = {
				{0, 1.3, 0.455},
				{1, 0.91, 0.325},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Breath",
			texture = "fx_fog2001",
			shape = {
				type = "Box",
				size = {18, 2, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.11, 4},
			},
			direction = "Back",
			spread = {80, 40},
			speed = {8, 22},
			drag = 3,
			accel = {0, 2, 0},
			lifetime = {0.5, 0.8},
			size = {
				{0, 3, 1},
				{1, 10, 2},
			},
			transparency = {
				{0, 0.5, 0},
				{0.3, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{225, 240, 255},
				},
				{
					1,
					{185, 210, 245},
				},
			},
			light_emission = 0.2,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = -1,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FrostbiteWound",
			texture = "mf_frost_cracks",
			emit = {
				{0.24, 1},
			},
			lifetime = {1, 1},
			size = {
				{0, 4.2, 0},
				{0.08, 14, 0},
				{1, 14.7, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.4, 0.15, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 185, 255},
				},
				{
					0.15,
					{225, 242, 255},
				},
				{
					0.35,
					{130, 190, 255},
				},
				{
					1,
					{40, 80, 200},
				},
			},
			light_emission = 0.9,
			brightness = 1.2,
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
			name = "FrostbiteDrip",
			texture = "fx_spark002",
			shape = {
				type = "Box",
				size = {18, 2, 1},
				style = "Volume",
				inout = "Outward",
			},
			stream = {
				{0.29, 1.24, 14, 6},
			},
			direction = "Bottom",
			spread = {25, 25},
			speed = {2, 6},
			accel = {0, -45, 0},
			lifetime = {0.4, 0.7},
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			rotation = {0, 45},
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
			name = "Glints",
			texture = "kk_star_06",
			shape = {
				type = "Box",
				size = {18, 8, 2},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.13, 6},
			},
			direction = "Back",
			spread = {80, 80},
			speed = {2, 8},
			drag = 2,
			lifetime = {0.35, 0.6},
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
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
	},
	shakes = {
		{0.1, 0.4, 0.2},
	},
	light = {
		color = {170, 210, 255},
		brightness = 3,
		range = 22,
		time = 0.25,
		delay = 0.1,
	},
	hit = {
		lift = 3,
		ref = 22,
		angle = 0,
		angled = false,
		impact = 0.1,
	},
}

-- MOONFANG M1 (mordiscos 1 a 3): dos filas de colmillos de cristal (solo los dientes, sin encía) se cierran de golpe sobre el rival y quedan trabadas; sueltan chispas de hielo, esquirlas y vaho helado, los colmillos se rompen y queda una herida de escarcha que gotea cristalitos un segundo.
-- target = el rival (Model, Part, Vector3 o CFrame). El golpe sale delante de lo que ve la cámara y mira
-- hacia ella. Con un Model o una Part se adapta al alto del rival (22 studs = tamaño 1; scale lo multiplica).
function MoonfangVFX.MoonBite(target: any, scale: number?, shake: number?): Part
	return playHit(SPEC_MoonBite, target, scale, shake, 0)
end
-- segundo (desde la llamada) en que el golpe conecta: para sincronizar el número de daño o el sonido
MoonfangVFX.MoonBiteImpact = 0.1

local SPEC_MoonBiteFinisher = {
	name = "MoonBiteFinisher",
	duration = 1.6,
	cleanup = 2.59,
	layers = {
		{
			name = "LungeLines",
			texture = "kk_trace_03",
			orientation = "VelocityParallel",
			shape = {
				type = "Sphere",
				radius = 18,
				style = "Surface",
				inout = "Inward",
			},
			emit = {
				{0, 14},
				{0.04, 8},
			},
			speed = {150, 200},
			lifetime = {0.09, 0.11},
			size = {
				{0, 9, 2},
				{1, 4, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Chomp",
			texture = "mf_chomp_4x4",
			flipbook = {
				layout = "Grid4x4",
				mode = "OneShot",
				fps = 30,
				startRandom = false,
			},
			emit = {
				{0.03, 1},
			},
			lifetime = {0.44, 0.44},
			size = {
				{0, 34, 0},
				{1, 35.36, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 235, 255},
				},
				{
					0.3,
					{255, 255, 255},
				},
				{
					0.6,
					{170, 210, 255},
				},
				{
					1,
					{120, 175, 255},
				},
			},
			light_emission = 0.8,
			brightness = 1.5,
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
			name = "ChompGlow",
			texture = "fx_glow",
			emit = {
				{0.14, 1},
			},
			lifetime = {0.24, 0.24},
			size = {
				{0, 13.6, 0},
				{0.3, 25.5, 0},
				{1, 28.9, 0},
			},
			transparency = {
				{0, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
				},
			},
			light_emission = 1,
			brightness = 0.8,
			zoffset = -1,
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
			name = "ChompEcho",
			texture = "mf_chomp_4x4",
			flipbook = {
				layout = "Grid4x4",
				mode = "OneShot",
				fps = 30,
				startRandom = false,
			},
			emit = {
				{0.045, 1},
			},
			lifetime = {0.44, 0.44},
			size = {
				{0, 42, 0},
				{1, 43.68, 0},
			},
			transparency = {
				{0, 0.7, 0},
				{0.8, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 235, 255},
				},
				{
					0.3,
					{255, 255, 255},
				},
				{
					0.6,
					{170, 210, 255},
				},
				{
					1,
					{120, 175, 255},
				},
			},
			light_emission = 0.8,
			brightness = 1,
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
			name = "ChompEchoGlow",
			texture = "fx_glow",
			emit = {
				{0.155, 1},
			},
			lifetime = {0.24, 0.24},
			size = {
				{0, 16.8, 0},
				{0.3, 31.5, 0},
				{1, 35.7, 0},
			},
			transparency = {
				{0, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
				},
			},
			light_emission = 1,
			brightness = 0.8,
			zoffset = -1,
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
				{0.3, 14, 0},
				{1, 15.4, 0},
			},
			transparency = {
				{0, 0.625, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
				{0.4, 13.3, 0},
				{1, 8.4, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 0.8,
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
				{1, 52, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
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
			name = "SnapStar",
			texture = "kk_star_08",
			emit = {
				{0.14, 1},
			},
			lifetime = {0.2, 0.2},
			size = {
				{0, 8, 0},
				{0.3, 28, 0},
				{1, 14, 0},
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			rotation = {0, 0},
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
			name = "CrystalRing",
			texture = "kk_circle_02",
			emit = {
				{0.16, 1},
			},
			lifetime = {0.32, 0.32},
			size = {
				{0, 10, 0},
				{1, 58, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.6, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			zoffset = 2,
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
			name = "IceBloom",
			texture = "mf_spike",
			orientation = "VelocityParallel",
			shape = {
				type = "Sphere",
				radius = 1.5,
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.26, 12},
			},
			direction = "Back",
			spread = {180, 180},
			speed = {40, 70},
			drag = 10,
			lifetime = {0.45, 0.6},
			size = {
				{0, 1, 0},
				{0.15, 7, 1.5},
				{0.8, 7.5, 1.5},
				{1, 0, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.5,
			brightness = 1.6,
			zoffset = 4,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "SparksRight",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {22, 2, 1},
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
				{0.13, 18},
				{0.16, 8},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
				size = {22, 2, 1},
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
				{0.13, 18},
				{0.16, 8},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			name = "SparksVTop",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {22, 2, 1},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 35},
			speed = {70, 140},
			drag = 5,
			accel = {0, -40, 0},
			lifetime = {0.16, 0.3},
			emit = {
				{0.13, 8},
				{0.16, 4},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			name = "SparksVBottom",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {22, 2, 1},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Bottom",
			spread = {25, 35},
			speed = {70, 140},
			drag = 5,
			accel = {0, -40, 0},
			lifetime = {0.16, 0.3},
			emit = {
				{0.13, 8},
				{0.16, 4},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			name = "Shards",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Box",
				size = {22, 4, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.26, 24},
			},
			direction = "Back",
			spread = {70, 70},
			speed = {35, 75},
			drag = 0.6,
			accel = {0, -90, 0},
			lifetime = {0.4, 0.7},
			size = {
				{0, 1.7, 0.595},
				{1, 1.19, 0.425},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Breath",
			texture = "fx_fog2001",
			shape = {
				type = "Box",
				size = {22, 3, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.15, 7},
			},
			direction = "Back",
			spread = {80, 40},
			speed = {8, 22},
			drag = 3,
			accel = {0, 2, 0},
			lifetime = {0.5, 0.8},
			size = {
				{0, 4, 1},
				{1, 13, 2},
			},
			transparency = {
				{0, 0.5, 0},
				{0.3, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{225, 240, 255},
				},
				{
					1,
					{185, 210, 245},
				},
			},
			light_emission = 0.2,
			rotation = {0, 360},
			rot_speed = {-60, 60},
			zoffset = -1,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "FrostbiteWound",
			texture = "mf_frost_cracks",
			emit = {
				{0.29, 1},
			},
			lifetime = {1.3, 1.3},
			size = {
				{0, 6, 0},
				{0.08, 20, 0},
				{1, 21, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.4, 0.15, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 185, 255},
				},
				{
					0.15,
					{225, 242, 255},
				},
				{
					0.35,
					{130, 190, 255},
				},
				{
					1,
					{40, 80, 200},
				},
			},
			light_emission = 0.9,
			brightness = 1.2,
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
			name = "FrostbiteDrip",
			texture = "fx_spark002",
			shape = {
				type = "Box",
				size = {22, 2, 1},
				style = "Volume",
				inout = "Outward",
			},
			stream = {
				{0.34, 1.59, 20, 8},
			},
			direction = "Bottom",
			spread = {25, 25},
			speed = {2, 6},
			accel = {0, -45, 0},
			lifetime = {0.4, 0.7},
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			rotation = {0, 45},
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
			name = "Glints",
			texture = "kk_star_06",
			shape = {
				type = "Box",
				size = {24, 12, 2},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.16, 10},
			},
			direction = "Back",
			spread = {80, 80},
			speed = {2, 8},
			drag = 2,
			lifetime = {0.35, 0.6},
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
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
	},
	shakes = {
		{0.02, 0.25, 0.12},
		{0.14, 0.8, 0.3},
	},
	light = {
		color = {180, 215, 255},
		brightness = 5,
		range = 28,
		time = 0.35,
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

-- MOONFANG M1 (mordisco 4, remate): una embestida; líneas de velocidad se cierran sobre el rival y dos filas de colmillos más grandes (con su eco) se traban de golpe, se rompen y revientan en una flor de púas de hielo, esquirlas y vaho helado; deja una herida de escarcha más grande.
-- target = el rival (Model, Part, Vector3 o CFrame). El golpe sale delante de lo que ve la cámara y mira
-- hacia ella. Con un Model o una Part se adapta al alto del rival (22 studs = tamaño 1; scale lo multiplica).
function MoonfangVFX.MoonBiteFinisher(target: any, scale: number?, shake: number?): Part
	return playHit(SPEC_MoonBiteFinisher, target, scale, shake, 0)
end
-- segundo (desde la llamada) en que el golpe conecta: para sincronizar el número de daño o el sonido
MoonfangVFX.MoonBiteFinisherImpact = 0.14

local SPEC_MoonFang = {
	name = "MoonFang",
	duration = 1.1,
	cleanup = 1.63,
	layers = {
		{
			name = "Chomp",
			texture = "mf_chomp_4x4",
			flipbook = {
				layout = "Grid4x4",
				mode = "OneShot",
				fps = 30,
				startRandom = false,
			},
			emit = {
				{0.03, 1},
			},
			lifetime = {0.44, 0.44},
			size = {
				{0, 40, 0},
				{1, 41.6, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 235, 255},
				},
				{
					0.3,
					{255, 255, 255},
				},
				{
					0.6,
					{170, 210, 255},
				},
				{
					1,
					{120, 175, 255},
				},
			},
			light_emission = 0.8,
			brightness = 1.6,
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
			name = "ChompGlow",
			texture = "fx_glow",
			emit = {
				{0.14, 1},
			},
			lifetime = {0.24, 0.24},
			size = {
				{0, 16, 0},
				{0.3, 30, 0},
				{1, 34, 0},
			},
			transparency = {
				{0, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
				},
			},
			light_emission = 1,
			brightness = 0.8,
			zoffset = -1,
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
			name = "ChompEcho",
			texture = "mf_chomp_4x4",
			flipbook = {
				layout = "Grid4x4",
				mode = "OneShot",
				fps = 30,
				startRandom = false,
			},
			emit = {
				{0.045, 1},
			},
			lifetime = {0.44, 0.44},
			size = {
				{0, 48, 0},
				{1, 49.92, 0},
			},
			transparency = {
				{0, 0.72, 0},
				{0.8, 0.72, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 235, 255},
				},
				{
					0.3,
					{255, 255, 255},
				},
				{
					0.6,
					{170, 210, 255},
				},
				{
					1,
					{120, 175, 255},
				},
			},
			light_emission = 0.8,
			brightness = 1,
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
			name = "ChompEchoGlow",
			texture = "fx_glow",
			emit = {
				{0.155, 1},
			},
			lifetime = {0.24, 0.24},
			size = {
				{0, 19.2, 0},
				{0.3, 36, 0},
				{1, 40.8, 0},
			},
			transparency = {
				{0, 0.7, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
				},
			},
			light_emission = 1,
			brightness = 0.8,
			zoffset = -1,
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
			name = "SpikesUp",
			texture = "mf_spike",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {18, 2, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.15, 7},
			},
			direction = "Top",
			spread = {40, 10},
			speed = {30, 55},
			drag = 12,
			lifetime = {0.48, 0.48},
			size = {
				{0, 1, 0},
				{0.2, 8, 2},
				{0.85, 8.6, 2},
				{1, 8.8, 2},
			},
			transparency = {
				{0, 0, 0},
				{0.92, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.5,
			brightness = 1.6,
			zoffset = 4.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "SpikesDown",
			texture = "mf_spike",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {18, 2, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.16, 6},
			},
			direction = "Bottom",
			spread = {40, 10},
			speed = {25, 45},
			drag = 12,
			lifetime = {0.47, 0.47},
			size = {
				{0, 1, 0},
				{0.2, 6.5, 1.5},
				{0.85, 7, 1.5},
				{1, 7.2, 1.5},
			},
			transparency = {
				{0, 0, 0},
				{0.92, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.5,
			brightness = 1.6,
			zoffset = 4.5,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "CrescentL",
			texture = "mf_crescent",
			emit = {
				{0.14, 1},
			},
			lifetime = {0.22, 0.22},
			size = {
				{0, 10, 0},
				{1, 36, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			rotation = {0, 0},
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
			name = "CrescentR",
			texture = "mf_crescent",
			emit = {
				{0.14, 1},
			},
			lifetime = {0.22, 0.22},
			size = {
				{0, 10, 0},
				{1, 36, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			rotation = {180, 180},
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
			name = "ShatterFlash",
			texture = "fx_glow",
			emit = {
				{0.62, 1},
			},
			lifetime = {0.14, 0.16},
			size = {
				{0, 10, 0},
				{0.3, 26, 0},
				{1, 28, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 1,
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
			name = "ShatterStar",
			texture = "kk_star_08",
			emit = {
				{0.62, 1},
			},
			lifetime = {0.2, 0.2},
			size = {
				{0, 10, 0},
				{0.3, 36, 0},
				{1, 18, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			rotation = {0, 90},
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
			name = "HitFlash",
			texture = "fx_glow",
			emit = {
				{0.14, 1},
			},
			lifetime = {0.16, 0.18},
			size = {
				{0, 6, 0},
				{0.3, 24, 0},
				{1, 26.4, 0},
			},
			transparency = {
				{0, 0.475, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 0.63,
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
				{0.4, 22.8, 0},
				{1, 14.4, 0},
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
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 1.12,
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
				{1, 46, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
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
				{0.13, 12},
				{0.16, 6},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
				{0.13, 12},
				{0.16, 6},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			name = "ShatterShards",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Box",
				size = {16, 14, 2},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.62, 30},
			},
			direction = "Back",
			spread = {85, 85},
			speed = {35, 80},
			drag = 0.6,
			accel = {0, -90, 0},
			lifetime = {0.4, 0.7},
			size = {
				{0, 1.8, 0.63},
				{1, 1.26, 0.45},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "ShatterGlints",
			texture = "kk_star_06",
			shape = {
				type = "Box",
				size = {22, 18, 2},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.64, 12},
			},
			direction = "Back",
			spread = {80, 80},
			speed = {2, 8},
			drag = 2,
			lifetime = {0.35, 0.6},
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
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
			name = "Mist",
			texture = "kk_smoke_04",
			shape = {
				type = "Box",
				size = {12, 6, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.15, 3},
			},
			direction = "Back",
			spread = {60, 60},
			speed = {3, 9},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {0.45, 0.7},
			size = {
				{0, 4, 1},
				{1, 11, 2},
			},
			transparency = {
				{0, 0.62, 0},
				{0.3, 0.58, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 228, 248},
				},
				{
					1,
					{175, 190, 222},
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
		{
			name = "ShatterMist",
			texture = "kk_smoke_04",
			shape = {
				type = "Box",
				size = {16, 14, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.63, 5},
			},
			direction = "Back",
			spread = {60, 60},
			speed = {3, 9},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {0.45, 0.7},
			size = {
				{0, 5, 1},
				{1, 13, 2},
			},
			transparency = {
				{0, 0.62, 0},
				{0.3, 0.58, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 228, 248},
				},
				{
					1,
					{175, 190, 222},
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
		{0.14, 0.85, 0.3},
		{0.62, 0.5, 0.22},
	},
	light = {
		color = {170, 210, 255},
		brightness = 5,
		range = 30,
		time = 0.4,
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

-- MOONFANG PESADO (Colmillo lunar): dos filas de colmillos de cristal grandes (solo los dientes, sin encía, con su eco) se traban de golpe sobre el rival; de la mordida brotan cristales que crecen y a los 0.62 s estallan en pedazos, con dos ondas de media luna.
-- target = el rival (Model, Part, Vector3 o CFrame). El golpe sale delante de lo que ve la cámara y mira
-- hacia ella. Con un Model o una Part se adapta al alto del rival (22 studs = tamaño 1; scale lo multiplica).
function MoonfangVFX.MoonFang(target: any, scale: number?, shake: number?): Part
	return playHit(SPEC_MoonFang, target, scale, shake, 0)
end
-- segundo (desde la llamada) en que el golpe conecta: para sincronizar el número de daño o el sonido
MoonfangVFX.MoonFangImpact = 0.14

local SPEC_MoonGuardHit = {
	name = "MoonGuardHit",
	duration = 0.5,
	cleanup = 1.02,
	layers = {
		{
			name = "Shield",
			texture = "mf_crescent",
			emit = {
				{0, 1},
			},
			lifetime = {0.28, 0.28},
			size = {
				{0, 22, 0},
				{0.2, 30, 0},
				{1, 32, 0},
			},
			transparency = {
				{0, 0.1, 0},
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
					{220, 232, 255},
				},
				{
					1,
					{165, 195, 250},
				},
			},
			light_emission = 1,
			brightness = 1.15,
			rotation = {180, 180},
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
			name = "ShieldGlow",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			lifetime = {0.24, 0.24},
			size = {
				{0, 26, 0},
				{1, 34, 0},
			},
			transparency = {
				{0, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
				},
			},
			light_emission = 1,
			brightness = 0.8,
			zoffset = 4,
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
			name = "Ripple",
			texture = "kz_beam_ring",
			emit = {
				{0.02, 1},
			},
			lifetime = {0.22, 0.22},
			size = {
				{0, 8, 0},
				{1, 36, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			zoffset = 3,
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
			name = "GuardStar",
			texture = "kk_star_06",
			emit = {
				{0.02, 1},
			},
			lifetime = {0.12, 0.12},
			size = {
				{0, 8, 0},
				{0.4, 18, 0},
				{1, 10, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
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
			name = "RicochetRight",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {6, 20, 1},
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
				{0.01, 12},
				{0.04, 6},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			name = "RicochetLeft",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			shape = {
				type = "Box",
				size = {6, 20, 1},
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
				{0.01, 12},
				{0.04, 6},
			},
			size = {
				{0, 6, 1.5},
				{1, 2, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			name = "ShardsR",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Box",
				size = {6, 20, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.02, 10},
			},
			direction = "Right",
			spread = {60, 40},
			speed = {30, 60},
			drag = 0.6,
			accel = {0, -90, 0},
			lifetime = {0.4, 0.7},
			size = {
				{0, 1.2, 0.42},
				{1, 0.84, 0.3},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "ShardsL",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Box",
				size = {6, 20, 1},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.02, 10},
			},
			direction = "Left",
			spread = {60, 40},
			speed = {30, 60},
			drag = 0.6,
			accel = {0, -90, 0},
			lifetime = {0.4, 0.7},
			size = {
				{0, 1.2, 0.42},
				{1, 0.84, 0.3},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Glints",
			texture = "kk_star_06",
			shape = {
				type = "Box",
				size = {16, 24, 2},
				style = "Volume",
				inout = "Outward",
			},
			emit = {
				{0.04, 6},
			},
			direction = "Back",
			spread = {80, 80},
			speed = {2, 8},
			drag = 2,
			lifetime = {0.35, 0.6},
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
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
	},
	shakes = {
		{0.02, 0.3, 0.15},
	},
	light = {
		color = {170, 210, 255},
		brightness = 2.5,
		range = 20,
		time = 0.2,
		delay = 0.02,
	},
	hit = {
		lift = 5,
		ref = 22,
		angle = 0,
		angled = false,
		impact = 0.02,
	},
}

-- MOONFANG BLOQUEO (cada golpe bloqueado): una media luna de luz aparece como escudo delante de él, con esquirlas que rebotan a los lados, una onda y destellos. target = Moonfang.
-- target = el rival (Model, Part, Vector3 o CFrame). El golpe sale delante de lo que ve la cámara y mira
-- hacia ella. Con un Model o una Part se adapta al alto del rival (22 studs = tamaño 1; scale lo multiplica).
function MoonfangVFX.MoonGuardHit(target: any, scale: number?, shake: number?): Part
	return playHit(SPEC_MoonGuardHit, target, scale, shake, 0)
end
-- segundo (desde la llamada) en que el golpe conecta: para sincronizar el número de daño o el sonido
MoonfangVFX.MoonGuardHitImpact = 0.02

local SPEC_CrescentWave = {
	name = "CrescentWave",
	duration = 4,
	cleanup = 5.04,
	layers = {
		{
			name = "SwipeFlash",
			texture = "mf_crescent",
			emit = {
				{0, 1, 0, 0, 10},
			},
			lifetime = {0.18, 0.18},
			size = {
				{0, 12, 0},
				{0.4, 32, 0},
				{1, 36, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.5, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 232, 255},
				},
				{
					1,
					{165, 195, 250},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			rotation = {160, 160},
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
			name = "SwipeGlow",
			texture = "fx_glow",
			emit = {
				{0.02, 1, 0, 0, 10},
			},
			lifetime = {0.26, 0.26},
			size = {
				{0, 10, 0},
				{1, 40, 0},
			},
			transparency = {
				{0, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
				},
			},
			light_emission = 1,
			brightness = 1,
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
			name = "SwipeWind",
			texture = "kz_wind_arcs",
			emit = {
				{0.03, 2, 0.02, 0, 6},
			},
			lifetime = {0.25, 0.3},
			size = {
				{0, 10, 0},
				{1, 42, 0},
			},
			transparency = {
				{0, 0.35, 0},
				{0.6, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 0.7,
			brightness = 1.1,
			rotation = {0, 360},
			rot_speed = {-160, 160},
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "SwipeDust",
			texture = "kk_smoke_04",
			emit = {
				{0.04, 8, 0.03, 0, 1},
			},
			direction = "Front",
			spread = {180, 6},
			speed = {30, 55},
			drag = 4,
			accel = {0, 4, 0},
			lifetime = {0.5, 0.7},
			size = {
				{0, 4, 1},
				{1, 12, 2},
			},
			transparency = {
				{0, 0.5, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{215, 228, 248},
				},
				{
					1,
					{175, 190, 222},
				},
			},
			rotation = {0, 360},
			zoffset = -2,
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "CutSnow",
			texture = "kk_smoke_04",
			direction = "Top",
			spread = {35, 35},
			speed = {14, 30},
			drag = 3,
			accel = {0, 2, 0},
			lifetime = {0.5, 0.8},
			size = {
				{0, 3, 1},
				{1, 9, 2},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{240, 246, 255},
				},
				{
					1,
					{205, 218, 240},
				},
			},
			rotation = {0, 360},
			rot_speed = {-60, 60},
			emit = {
				{0.23, 3, 0.05, -2.46, 0.5},
				{0.251, 3, 0.083, -1.52, 0.5},
				{0.271, 3, 0.116, -2.36, 0.5},
				{0.292, 3, 0.15, -1.17, 0.5},
				{0.313, 3, 0.183, -1.78, 0.5},
				{0.333, 3, 0.216, -2.78, 0.5},
				{0.354, 3, 0.249, -1.62, 0.5},
				{0.374, 3, 0.282, -1.2, 0.5},
				{0.395, 3, 0.316, -2.32, 0.5},
				{0.416, 3, 0.349, -0.79, 0.5},
				{0.436, 3, 0.382, -1.04, 0.5},
				{0.457, 3, 0.415, -2.72, 0.5},
				{0.477, 3, 0.448, -1.79, 0.5},
				{0.498, 3, 0.482, -0.89, 0.5},
				{0.518, 3, 0.515, -2.48, 0.5},
				{0.539, 3, 0.548, -2.54, 0.5},
				{0.56, 3, 0.581, -1.88, 0.5},
				{0.58, 3, 0.614, -2.1, 0.5},
				{0.601, 3, 0.648, -2.42, 0.5},
				{0.621, 3, 0.681, -1.06, 0.5},
				{0.642, 3, 0.714, -1.23, 0.5},
				{0.663, 3, 0.747, -0.85, 0.5},
				{0.683, 3, 0.78, -1.28, 0.5},
				{0.704, 3, 0.814, -1.63, 0.5},
				{0.724, 3, 0.847, -2.54, 0.5},
				{0.745, 3, 0.88, -1.14, 0.5},
			},
			light_emission = 0,
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "CutIce",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {50, 50},
			speed = {25, 55},
			drag = 0.5,
			accel = {0, -120, 0},
			lifetime = {0.5, 0.8},
			size = {
				{0, 1.1, 0.4},
				{1, 0.6, 0.2},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			emit = {
				{0.23, 3, 0.05, -0.87, 0.4},
				{0.251, 3, 0.083, -2.74, 0.4},
				{0.271, 3, 0.116, -2.42, 0.4},
				{0.292, 3, 0.15, -1.49, 0.4},
				{0.313, 3, 0.183, -1.01, 0.4},
				{0.333, 3, 0.216, -0.87, 0.4},
				{0.354, 3, 0.249, -1.59, 0.4},
				{0.374, 3, 0.282, -1.42, 0.4},
				{0.395, 3, 0.316, -1.37, 0.4},
				{0.416, 3, 0.349, -1.03, 0.4},
				{0.436, 3, 0.382, -2.17, 0.4},
				{0.457, 3, 0.415, -1.09, 0.4},
				{0.477, 3, 0.448, -0.91, 0.4},
				{0.498, 3, 0.482, -0.87, 0.4},
				{0.518, 3, 0.515, -1.39, 0.4},
				{0.539, 3, 0.548, -2.27, 0.4},
				{0.56, 3, 0.581, -2.16, 0.4},
				{0.58, 3, 0.614, -0.88, 0.4},
				{0.601, 3, 0.648, -2.5, 0.4},
				{0.621, 3, 0.681, -1.45, 0.4},
				{0.642, 3, 0.714, -2.69, 0.4},
				{0.663, 3, 0.747, -2.72, 0.4},
				{0.683, 3, 0.78, -1.78, 0.4},
				{0.704, 3, 0.814, -1.97, 0.4},
				{0.724, 3, 0.847, -0.96, 0.4},
				{0.745, 3, 0.88, -2.04, 0.4},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "CutSparks",
			texture = "kk_trace_01",
			orientation = "VelocityParallel",
			direction = "Back",
			spread = {35, 25},
			speed = {50, 90},
			drag = 4,
			accel = {0, -30, 0},
			lifetime = {0.16, 0.26},
			size = {
				{0, 5, 1},
				{1, 1.5, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 2,
			emit = {
				{0.23, 2, 0.05, -1.11, 0.5},
				{0.251, 2, 0.083, -1.16, 0.5},
				{0.271, 2, 0.116, -1.64, 0.5},
				{0.292, 2, 0.15, -1.74, 0.5},
				{0.313, 2, 0.183, -2.28, 0.5},
				{0.333, 2, 0.216, -2.24, 0.5},
				{0.354, 2, 0.249, -2.55, 0.5},
				{0.374, 2, 0.282, -1.45, 0.5},
				{0.395, 2, 0.316, -1.77, 0.5},
				{0.416, 2, 0.349, -2.02, 0.5},
				{0.436, 2, 0.382, -1.34, 0.5},
				{0.457, 2, 0.415, -1.54, 0.5},
				{0.477, 2, 0.448, -1.04, 0.5},
				{0.498, 2, 0.482, -1.37, 0.5},
				{0.518, 2, 0.515, -1.67, 0.5},
				{0.539, 2, 0.548, -2.09, 0.5},
				{0.56, 2, 0.581, -1.83, 0.5},
				{0.58, 2, 0.614, -1.64, 0.5},
				{0.601, 2, 0.648, -1.56, 0.5},
				{0.621, 2, 0.681, -2.3, 0.5},
				{0.642, 2, 0.714, -1.28, 0.5},
				{0.663, 2, 0.747, -2.41, 0.5},
				{0.683, 2, 0.78, -2.53, 0.5},
				{0.704, 2, 0.814, -1.67, 0.5},
				{0.724, 2, 0.847, -2.06, 0.5},
				{0.745, 2, 0.88, -2.13, 0.5},
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
		},
		{
			name = "CutChips",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {70, 70},
			speed = {25, 50},
			drag = 0.4,
			accel = {0, -130, 0},
			lifetime = {0.6, 0.9},
			size = {
				{0, 0.9, 0.3},
				{1, 0.7, 0.2},
			},
			color = {
				{
					0,
					{128, 126, 136},
				},
				{
					1,
					{100, 98, 108},
				},
			},
			rotation = {0, 360},
			rot_speed = {-500, 500},
			emit = {
				{0.23, 4, 0.05, -0.73, 0.5},
				{0.251, 4, 0.083, -3.38, 0.5},
				{0.271, 4, 0.116, -3.32, 0.5},
				{0.292, 4, 0.15, -3.83, 0.5},
				{0.313, 4, 0.183, -3.53, 0.5},
				{0.333, 4, 0.216, -0.67, 0.5},
				{0.354, 4, 0.249, -2.08, 0.5},
				{0.374, 4, 0.282, 0.65, 0.5},
				{0.395, 4, 0.316, -1.7, 0.5},
				{0.416, 4, 0.349, -0.59, 0.5},
				{0.436, 4, 0.382, -2.77, 0.5},
				{0.457, 4, 0.415, -3.86, 0.5},
				{0.477, 4, 0.448, -0.07, 0.5},
				{0.498, 4, 0.482, -2.66, 0.5},
				{0.518, 4, 0.515, -1.58, 0.5},
				{0.539, 4, 0.548, 0.18, 0.5},
				{0.56, 4, 0.581, -2.71, 0.5},
				{0.58, 4, 0.614, -3.94, 0.5},
				{0.601, 4, 0.648, -0.96, 0.5},
				{0.621, 4, 0.681, -0.19, 0.5},
				{0.642, 4, 0.714, 0.01, 0.5},
				{0.663, 4, 0.747, -0.58, 0.5},
				{0.683, 4, 0.78, -3.82, 0.5},
				{0.704, 4, 0.814, -3.52, 0.5},
				{0.724, 4, 0.847, -1.89, 0.5},
				{0.745, 4, 0.88, 0.58, 0.5},
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
		},
		{
			name = "CutDust",
			texture = "kk_smoke_04",
			direction = "Top",
			spread = {70, 70},
			speed = {6, 14},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {0.6, 0.9},
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
					{215, 228, 248},
				},
				{
					1,
					{175, 190, 222},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			zoffset = -2,
			emit = {
				{0.25, 2, 0.05, -2.77, 1},
				{0.271, 2, 0.083, 0.96, 1},
				{0.291, 2, 0.116, 1.18, 1},
				{0.312, 2, 0.15, -5.45, 1},
				{0.333, 2, 0.183, -3.74, 1},
				{0.353, 2, 0.216, -2.4, 1},
				{0.374, 2, 0.249, -4.79, 1},
				{0.394, 2, 0.282, 0.87, 1},
				{0.415, 2, 0.316, 0.57, 1},
				{0.436, 2, 0.349, 0.81, 1},
				{0.456, 2, 0.382, -2.92, 1},
				{0.477, 2, 0.415, -4.96, 1},
				{0.497, 2, 0.448, -0.7, 1},
				{0.518, 2, 0.482, -1.13, 1},
				{0.538, 2, 0.515, -4.27, 1},
				{0.559, 2, 0.548, -2.1, 1},
				{0.58, 2, 0.581, -1.28, 1},
				{0.6, 2, 0.614, -4.77, 1},
				{0.621, 2, 0.648, -5.47, 1},
				{0.641, 2, 0.681, 0.75, 1},
				{0.662, 2, 0.714, -2.4, 1},
				{0.683, 2, 0.747, -2.3, 1},
				{0.703, 2, 0.78, -1.75, 1},
				{0.724, 2, 0.814, -5.33, 1},
				{0.744, 2, 0.847, -3.53, 1},
				{0.765, 2, 0.88, -2.52, 1},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "CutMistR",
			texture = "kk_smoke_04",
			direction = "Right",
			spread = {25, 6},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 0.6, 0},
			lifetime = {1.4, 2},
			size = {
				{0, 5, 1},
				{0.5, 12, 2},
				{1, 15, 2},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.65, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{220, 236, 255},
				},
				{
					1,
					{175, 200, 240},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -3,
			emit = {
				{0.28, 1, 0.05, -1.49, 0.8},
				{0.307, 1, 0.094, -2.14, 0.8},
				{0.334, 1, 0.137, -2.32, 0.8},
				{0.362, 1, 0.181, -1.47, 0.8},
				{0.389, 1, 0.225, -1.57, 0.8},
				{0.416, 1, 0.268, -1.63, 0.8},
				{0.443, 1, 0.312, -1.21, 0.8},
				{0.47, 1, 0.356, -1.38, 0.8},
				{0.497, 1, 0.399, -1.22, 0.8},
				{0.524, 1, 0.443, -1.26, 0.8},
				{0.551, 1, 0.487, -2.23, 0.8},
				{0.578, 1, 0.531, -1.38, 0.8},
				{0.605, 1, 0.574, -1.95, 0.8},
				{0.632, 1, 0.618, -2.35, 0.8},
				{0.659, 1, 0.662, -2.04, 0.8},
				{0.687, 1, 0.705, -2.24, 0.8},
				{0.714, 1, 0.749, -2.38, 0.8},
				{0.741, 1, 0.793, -1.72, 0.8},
				{0.768, 1, 0.836, -1.37, 0.8},
				{0.795, 1, 0.88, -1.37, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "CutMistL",
			texture = "kk_smoke_04",
			direction = "Left",
			spread = {25, 6},
			speed = {6, 14},
			drag = 1.5,
			accel = {0, 0.6, 0},
			lifetime = {1.4, 2},
			size = {
				{0, 5, 1},
				{0.5, 12, 2},
				{1, 15, 2},
			},
			transparency = {
				{0, 0.6, 0},
				{0.3, 0.65, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{220, 236, 255},
				},
				{
					1,
					{175, 200, 240},
				},
			},
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -3,
			emit = {
				{0.28, 1, 0.05, -1.61, 0.8},
				{0.307, 1, 0.094, -1.24, 0.8},
				{0.334, 1, 0.137, -2.31, 0.8},
				{0.362, 1, 0.181, -1.99, 0.8},
				{0.389, 1, 0.225, -1.41, 0.8},
				{0.416, 1, 0.268, -1.3, 0.8},
				{0.443, 1, 0.312, -2.3, 0.8},
				{0.47, 1, 0.356, -1.7, 0.8},
				{0.497, 1, 0.399, -1.38, 0.8},
				{0.524, 1, 0.443, -1.5, 0.8},
				{0.551, 1, 0.487, -1.2, 0.8},
				{0.578, 1, 0.531, -1.22, 0.8},
				{0.605, 1, 0.574, -2.09, 0.8},
				{0.632, 1, 0.618, -1.98, 0.8},
				{0.659, 1, 0.662, -1.54, 0.8},
				{0.687, 1, 0.705, -2.27, 0.8},
				{0.714, 1, 0.749, -2.03, 0.8},
				{0.741, 1, 0.793, -1.27, 0.8},
				{0.768, 1, 0.836, -1.75, 0.8},
				{0.795, 1, 0.88, -1.54, 0.8},
			},
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "CutGlints",
			texture = "fx_spark002",
			direction = "Top",
			spread = {40, 40},
			speed = {1, 4},
			drag = 1,
			lifetime = {0.8, 1.4},
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			rotation = {0, 45},
			emit = {
				{0.26, 2, 0.05, -3.34, 0.6},
				{0.281, 2, 0.083, -1.4, 0.6},
				{0.301, 2, 0.116, -3.26, 0.6},
				{0.322, 2, 0.15, -2.12, 0.6},
				{0.343, 2, 0.183, -2.22, 0.6},
				{0.363, 2, 0.216, -3.27, 0.6},
				{0.384, 2, 0.249, -3.68, 0.6},
				{0.404, 2, 0.282, -3.41, 0.6},
				{0.425, 2, 0.316, -2.53, 0.6},
				{0.446, 2, 0.349, -3.27, 0.6},
				{0.466, 2, 0.382, -1.76, 0.6},
				{0.487, 2, 0.415, -1.14, 0.6},
				{0.507, 2, 0.448, -2.86, 0.6},
				{0.528, 2, 0.482, -3.26, 0.6},
				{0.548, 2, 0.515, -0.71, 0.6},
				{0.569, 2, 0.548, -2.75, 0.6},
				{0.59, 2, 0.581, -0.15, 0.6},
				{0.61, 2, 0.614, -3.29, 0.6},
				{0.631, 2, 0.648, -3.12, 0.6},
				{0.651, 2, 0.681, -3.66, 0.6},
				{0.672, 2, 0.714, -0.56, 0.6},
				{0.693, 2, 0.747, -2.28, 0.6},
				{0.713, 2, 0.78, 0.03, 0.6},
				{0.734, 2, 0.814, -1.14, 0.6},
				{0.754, 2, 0.847, -3.1, 0.6},
				{0.775, 2, 0.88, -3.03, 0.6},
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
		},
		{
			name = "RocksOut",
			type = "meteor",
			emit = {
				{0.23, 1, 0.05, -4.46, 0.3},
				{0.257, 1, 0.094, -3.55, 0.3},
				{0.284, 1, 0.137, -4.16, 0.3},
				{0.312, 1, 0.181, -3.93, 0.3},
				{0.339, 1, 0.225, -4.14, 0.3},
				{0.366, 1, 0.268, -2.9, 0.3},
				{0.393, 1, 0.312, -3.2, 0.3},
				{0.42, 1, 0.356, -3.5, 0.3},
				{0.447, 1, 0.399, -4.27, 0.3},
				{0.474, 1, 0.443, -2.23, 0.3},
				{0.501, 1, 0.487, -4.01, 0.3},
				{0.528, 1, 0.531, -3.61, 0.3},
				{0.555, 1, 0.574, -3.98, 0.3},
				{0.582, 1, 0.618, -3.09, 0.3},
				{0.609, 1, 0.662, -2.2, 0.3},
				{0.637, 1, 0.705, -3.64, 0.3},
				{0.664, 1, 0.749, -2.48, 0.3},
				{0.691, 1, 0.793, -4.42, 0.3},
				{0.718, 1, 0.836, -2.41, 0.3},
				{0.745, 1, 0.88, -3.97, 0.3},
			},
			direction = "Left",
			spread = {40, 25},
			speed = {45, 90},
			accel = {0, -196, 0},
			drag = 0.1,
			lifetime = {2.2, 2.2},
			trails = {
				{
					name = "RocksOutDust",
					rate = 14,
					texture = "kk_smoke_04",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 1.5, 0.5},
						{1, 4, 1},
					},
					transparency = {
						{0, 0.55, 0},
						{0.5, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
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
					speed = {4, 10},
					drag = 2,
					accel = {0, 3, 0},
					lifetime = {0.5, 0.8},
					size = {
						{0, 3, 1},
						{1, 8, 2},
					},
					transparency = {
						{0, 0.5, 0},
						{0.4, 0.6, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
						},
					},
					rotation = {0, 360},
					zoffset = -2,
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
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
						size = {2, 1.5, 2},
						style = "Volume",
						inout = "Outward",
					},
					direction = "Top",
					spread = {70, 70},
					speed = {6, 16},
					drag = 0.5,
					accel = {0, -110, 0},
					lifetime = {0.35, 0.55},
					size = {
						{0, 0.9, 0.3},
						{1, 0.7, 0.2},
					},
					color = {
						{
							0,
							{120, 118, 128},
						},
						{
							1,
							{96, 94, 104},
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
					name = "RockDust",
					texture = "kk_smoke_04",
					emit = {
						{0, 2},
					},
					direction = "Top",
					spread = {60, 60},
					speed = {2, 6},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 2, 0.5},
						{1, 6, 1},
					},
					transparency = {
						{0, 0.6, 0},
						{0.4, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
						},
					},
					rotation = {0, 360},
					zoffset = -2,
					accel = {0, 0, 0},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			offset = {0, 0, 0},
			rock = {
				size = {1.2, 3},
				spin = {-420, 420},
				material = "Slate",
				color = {96, 94, 104},
				aspect = {1, 1, 1},
				upright = false,
				stick = 1.2,
				sink = 0.2,
				ground = true,
				color_var = {0.8, 1.1},
			},
		},
		{
			name = "RocksIn",
			type = "meteor",
			emit = {
				{0.23, 1, 0.05, -1.3, 0.3},
				{0.265, 1, 0.105, -0.76, 0.3},
				{0.299, 1, 0.161, -0.3, 0.3},
				{0.333, 1, 0.216, -1.25, 0.3},
				{0.368, 1, 0.271, 0.53, 0.3},
				{0.402, 1, 0.327, 0.78, 0.3},
				{0.436, 1, 0.382, -0.6, 0.3},
				{0.47, 1, 0.437, 0.32, 0.3},
				{0.505, 1, 0.493, -1.47, 0.3},
				{0.539, 1, 0.548, 0.53, 0.3},
				{0.573, 1, 0.603, 0.8, 0.3},
				{0.608, 1, 0.659, -1.29, 0.3},
				{0.642, 1, 0.714, 0.86, 0.3},
				{0.676, 1, 0.769, -1.11, 0.3},
				{0.711, 1, 0.825, -1.37, 0.3},
				{0.745, 1, 0.88, -0.64, 0.3},
			},
			direction = "Right",
			spread = {40, 25},
			speed = {40, 85},
			accel = {0, -196, 0},
			drag = 0.1,
			lifetime = {2.2, 2.2},
			trails = {
				{
					name = "RocksInDust",
					rate = 14,
					texture = "kk_smoke_04",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 1.5, 0.5},
						{1, 4, 1},
					},
					transparency = {
						{0, 0.55, 0},
						{0.5, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
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
					speed = {4, 10},
					drag = 2,
					accel = {0, 3, 0},
					lifetime = {0.5, 0.8},
					size = {
						{0, 3, 1},
						{1, 8, 2},
					},
					transparency = {
						{0, 0.5, 0},
						{0.4, 0.6, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
						},
					},
					rotation = {0, 360},
					zoffset = -2,
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
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
						size = {2, 1.5, 2},
						style = "Volume",
						inout = "Outward",
					},
					direction = "Top",
					spread = {70, 70},
					speed = {6, 16},
					drag = 0.5,
					accel = {0, -110, 0},
					lifetime = {0.35, 0.55},
					size = {
						{0, 0.9, 0.3},
						{1, 0.7, 0.2},
					},
					color = {
						{
							0,
							{120, 118, 128},
						},
						{
							1,
							{96, 94, 104},
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
					name = "RockDust",
					texture = "kk_smoke_04",
					emit = {
						{0, 2},
					},
					direction = "Top",
					spread = {60, 60},
					speed = {2, 6},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 2, 0.5},
						{1, 6, 1},
					},
					transparency = {
						{0, 0.6, 0},
						{0.4, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
						},
					},
					rotation = {0, 360},
					zoffset = -2,
					accel = {0, 0, 0},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			offset = {0, 0, 0},
			rock = {
				size = {1.1, 2.8},
				spin = {-420, 420},
				material = "Slate",
				color = {96, 94, 104},
				aspect = {1, 1, 1},
				upright = false,
				stick = 1.2,
				sink = 0.2,
				ground = true,
				color_var = {0.8, 1.1},
			},
		},
		{
			name = "RocksUp",
			type = "meteor",
			emit = {
				{0.23, 1, 0.05, -1.62, 0.3},
				{0.27, 1, 0.114, -1.03, 0.3},
				{0.309, 1, 0.178, -1.42, 0.3},
				{0.349, 1, 0.242, -0.81, 0.3},
				{0.389, 1, 0.305, -1.43, 0.3},
				{0.428, 1, 0.369, -1.78, 0.3},
				{0.468, 1, 0.433, -1.72, 0.3},
				{0.507, 1, 0.497, -0.72, 0.3},
				{0.547, 1, 0.561, -2.27, 0.3},
				{0.587, 1, 0.625, -1.8, 0.3},
				{0.626, 1, 0.688, -1.53, 0.3},
				{0.666, 1, 0.752, -1.97, 0.3},
				{0.705, 1, 0.816, -0.76, 0.3},
				{0.745, 1, 0.88, -1.35, 0.3},
			},
			direction = "Top",
			spread = {22, 22},
			speed = {50, 85},
			accel = {0, -196, 0},
			drag = 0.1,
			lifetime = {2.2, 2.2},
			trails = {
				{
					name = "RocksUpDust",
					rate = 14,
					texture = "kk_smoke_04",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 1.5, 0.5},
						{1, 4, 1},
					},
					transparency = {
						{0, 0.55, 0},
						{0.5, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
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
					speed = {4, 10},
					drag = 2,
					accel = {0, 3, 0},
					lifetime = {0.5, 0.8},
					size = {
						{0, 3, 1},
						{1, 8, 2},
					},
					transparency = {
						{0, 0.5, 0},
						{0.4, 0.6, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
						},
					},
					rotation = {0, 360},
					zoffset = -2,
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
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
						size = {2, 1.5, 2},
						style = "Volume",
						inout = "Outward",
					},
					direction = "Top",
					spread = {70, 70},
					speed = {6, 16},
					drag = 0.5,
					accel = {0, -110, 0},
					lifetime = {0.35, 0.55},
					size = {
						{0, 0.9, 0.3},
						{1, 0.7, 0.2},
					},
					color = {
						{
							0,
							{120, 118, 128},
						},
						{
							1,
							{96, 94, 104},
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
					name = "RockDust",
					texture = "kk_smoke_04",
					emit = {
						{0, 2},
					},
					direction = "Top",
					spread = {60, 60},
					speed = {2, 6},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 2, 0.5},
						{1, 6, 1},
					},
					transparency = {
						{0, 0.6, 0},
						{0.4, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
						},
					},
					rotation = {0, 360},
					zoffset = -2,
					accel = {0, 0, 0},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			offset = {0, 0, 0},
			rock = {
				size = {1.3, 3.2},
				spin = {-420, 420},
				material = "Slate",
				color = {96, 94, 104},
				aspect = {1, 1, 1},
				upright = false,
				stick = 1.2,
				sink = 0.2,
				ground = true,
				color_var = {0.8, 1.1},
			},
		},
		{
			name = "DetFlash",
			texture = "fx_glow",
			emit = {
				{0.76, 1, 1, 0, 10},
			},
			lifetime = {0.22, 0.24},
			size = {
				{0, 14, 0},
				{0.3, 72, 0},
				{1, 80, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.5, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
				},
			},
			light_emission = 1,
			brightness = 1.2,
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
			name = "DetCore",
			texture = "fx_glow",
			emit = {
				{0.76, 1, 1, 0, 9},
			},
			lifetime = {0.16, 0.16},
			size = {
				{0, 8, 0},
				{0.25, 34, 0},
				{1, 30, 0},
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
					1,
					{235, 244, 255},
				},
			},
			light_emission = 1,
			brightness = 1.8,
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
			name = "DetStar",
			texture = "kk_star_09",
			emit = {
				{0.76, 1, 1, 0, 10},
			},
			lifetime = {0.28, 0.28},
			size = {
				{0, 18, 0},
				{0.2, 92, 0},
				{1, 30, 0},
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 1.5,
			rotation = {0, 90},
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
			name = "DetHalo",
			texture = "fx_halo",
			emit = {
				{0.78, 1, 1, 0, 10},
			},
			lifetime = {0.38, 0.38},
			size = {
				{0, 12, 0},
				{1, 110, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
				},
			},
			light_emission = 1,
			brightness = 1.2,
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
			name = "DetShock",
			texture = "kk_circle_02",
			emit = {
				{0.77, 1, 1, 0, 9},
			},
			lifetime = {0.32, 0.32},
			size = {
				{0, 10, 0},
				{1, 130, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.6, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 232, 255},
				},
				{
					1,
					{165, 195, 250},
				},
			},
			light_emission = 1,
			brightness = 1.3,
			zoffset = 4,
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
			name = "DetRing",
			texture = "kk_circle_02",
			emit = {
				{0.76, 1, 1, 0, 0.3},
			},
			lifetime = {0.55, 0.55},
			size = {
				{0, 14, 0},
				{1, 180, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.5, 0.42, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "DetRingSharp",
			texture = "kk_circle_02",
			emit = {
				{0.79, 1, 1, 0, 0.32},
			},
			lifetime = {0.36, 0.36},
			size = {
				{0, 12, 0},
				{1, 150, 0},
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
					{220, 232, 255},
				},
				{
					1,
					{165, 195, 250},
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
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "ColdCloud",
			texture = "kk_smoke_07",
			emit = {
				{0.77, 24, 1, 0, 8},
			},
			shape = {
				type = "Sphere",
				radius = 7,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {30, 70},
			drag = 3.2,
			accel = {0, 3, 0},
			lifetime = {1.4, 2},
			size = {
				{0, 12, 2},
				{0.3, 32, 5},
				{1, 44, 5},
			},
			transparency = {
				{0, 0.3, 0},
				{0.3, 0.45, 0},
				{0.8, 0.72, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{220, 236, 255},
				},
				{
					1,
					{175, 200, 240},
				},
			},
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -3,
			light_emission = 0,
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "ColdSwirl",
			texture = "fx_wind_swirl",
			emit = {
				{0.76, 2, 1, 0, 10},
				{0.86, 2, 1, 0, 12},
			},
			lifetime = {0.6, 0.85},
			size = {
				{0, 16, 0},
				{1, 92, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.5, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 0.6,
			brightness = 1.1,
			rotation = {0, 360},
			rot_speed = {-240, 240},
			zoffset = 2,
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
			name = "ColdArcs",
			texture = "kz_wind_arcs",
			emit = {
				{0.8, 4, 1, 0, 9},
			},
			lifetime = {0.4, 0.55},
			size = {
				{0, 18, 0},
				{1, 78, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.6, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 232, 255},
				},
				{
					1,
					{165, 195, 250},
				},
			},
			light_emission = 0.7,
			brightness = 1.2,
			rotation = {0, 360},
			rot_speed = {-200, 200},
			zoffset = 2,
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
			name = "GroundGust",
			texture = "kk_trace_03",
			orientation = "VelocityParallel",
			emit = {
				{0.78, 36, 1, 0, 1.2},
			},
			direction = "Front",
			spread = {180, 5},
			speed = {110, 180},
			drag = 3,
			lifetime = {0.4, 0.6},
			size = {
				{0, 12, 2},
				{0.4, 16, 3},
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
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
		},
		{
			name = "GroundMist",
			texture = "kk_smoke_04",
			emit = {
				{0.79, 20, 1, 0, 1},
			},
			direction = "Front",
			spread = {180, 4},
			speed = {50, 95},
			drag = 3.5,
			accel = {0, 2, 0},
			lifetime = {1, 1.4},
			size = {
				{0, 7, 1},
				{1, 22, 3},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.58, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{220, 236, 255},
				},
				{
					1,
					{175, 200, 240},
				},
			},
			rotation = {0, 360},
			zoffset = -2,
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "IceBurst",
			texture = "mf_spike",
			orientation = "VelocityParallel",
			emit = {
				{0.76, 22, 1, 0, 8},
			},
			shape = {
				type = "Sphere",
				radius = 3,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {90, 150},
			drag = 5,
			lifetime = {0.3, 0.45},
			size = {
				{0, 4, 1},
				{0.2, 14, 3},
				{1, 6, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.7, 0.2, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.6,
			brightness = 1.8,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
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
			emit = {
				{0.76, 70, 1, 0, 8},
			},
			shape = {
				type = "Sphere",
				radius = 4,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {55, 120},
			drag = 0.5,
			accel = {0, -110, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 2.2, 0.6},
				{1, 1.4, 0.4},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "IceCrown",
			texture = "mf_spike",
			orientation = "VelocityParallel",
			emit = {
				{0.8, 26, 1, 0, 0.5},
			},
			shape = {
				type = "Box",
				size = {28, 1, 28},
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {25, 25},
			speed = {28, 44},
			drag = 12,
			lifetime = {1.3, 1.6},
			size = {
				{0, 0.6, 0},
				{0.1, 12, 3},
				{0.8, 12.5, 3},
				{1, 0, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.5,
			brightness = 1.7,
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "IceChunks",
			type = "meteor",
			emit = {
				{0.78, 12, 1, 0, 4},
			},
			direction = "Top",
			spread = {70, 70},
			speed = {60, 110},
			accel = {0, -196, 0},
			drag = 0.1,
			lifetime = {2.4, 2.4},
			trails = {
				{
					name = "ChunkSparkle",
					rate = 16,
					texture = "fx_spark002",
					speed = {0, 4},
					direction = "Top",
					spread = {180, 180},
					lifetime = {0.3, 0.5},
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
							{225, 240, 255},
						},
						{
							1,
							{170, 205, 255},
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
					name = "ChunkCracks",
					texture = "mf_frost_cracks",
					emit = {
						{0, 1},
					},
					lifetime = {1.2, 1.4},
					rotation = {0, 360},
					size = {
						{0, 3, 0},
						{0.1, 11, 0},
						{1, 12, 0},
					},
					transparency = {
						{0, 0, 0},
						{0.3, 0.15, 0},
						{0.8, 0.45, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{120, 185, 255},
						},
						{
							0.15,
							{225, 242, 255},
						},
						{
							0.35,
							{130, 190, 255},
						},
						{
							1,
							{40, 80, 200},
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
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			shatter = {
				{
					name = "ChunkBreak",
					texture = "mf_shard_2x2",
					flipbook = {
						layout = "Grid2x2",
						mode = "Loop",
						fps = 0.001,
						startRandom = true,
					},
					emit = {
						{0, 8},
					},
					shape = {
						type = "Box",
						size = {3, 6, 3},
						style = "Volume",
						inout = "Outward",
					},
					direction = "Top",
					spread = {90, 90},
					speed = {12, 30},
					drag = 0.5,
					accel = {0, -110, 0},
					lifetime = {0.4, 0.65},
					size = {
						{0, 1.3, 0.4},
						{1, 0.9, 0.3},
					},
					color = {
						{
							0,
							{200, 230, 255},
						},
						{
							0.4,
							{120, 180, 255},
						},
						{
							1,
							{70, 120, 235},
						},
					},
					light_emission = 0.45,
					brightness = 1.4,
					rotation = {0, 360},
					rot_speed = {-500, 500},
					transparency = {
						{0, 0, 0},
						{1, 0, 0},
					},
					zoffset = 0,
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			offset = {0, 0, 0},
			rock = {
				size = {4, 8},
				spin = {-300, 300},
				material = "Ice",
				color = {150, 200, 255},
				aspect = {0.7, 1.6, 0.7},
				upright = false,
				stick = 0.9,
				sink = 0.3,
			},
		},
		{
			name = "DetCracks",
			texture = "mf_frost_cracks",
			emit = {
				{0.78, 1, 1, 0, 0.22},
			},
			lifetime = {2.4, 2.6},
			rotation = {0, 360},
			size = {
				{0, 24, 0},
				{0.06, 84, 0},
				{1, 88, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.25, 0.1, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 185, 255},
				},
				{
					0.15,
					{225, 242, 255},
				},
				{
					0.35,
					{130, 190, 255},
				},
				{
					1,
					{40, 80, 200},
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
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "DetFrost",
			texture = "fx_glow",
			emit = {
				{0.81, 1, 1, 0, 0.16},
			},
			lifetime = {2.3, 2.5},
			size = {
				{0, 34, 0},
				{0.1, 86, 0},
				{1, 90, 0},
			},
			transparency = {
				{0, 0.45, 0},
				{0.7, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "Snow",
			texture = "fx_spark002",
			shape = {
				type = "Sphere",
				radius = 30,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {2, 6},
			drag = 1,
			accel = {0, -3, 0},
			lifetime = {1.4, 2.2},
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			rotation = {0, 45},
			emit = {
				{0.81, 60, 1, 0, 14},
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
		},
	},
	shakes = {
		{0.02, 0.45, 0.25},
		{0.24, 0.3, 0.62},
		{0.76, 1.4, 0.55},
	},
	light = {
		color = {180, 215, 255},
		brightness = 5,
		range = 40,
		time = 0.3,
	},
	line = 130,
	blade = {
		t0 = 0.14,
		travel = 0.62,
		fade = 0.12,
		grow = 0.1,
		start_k = 0.4,
		radius = 18,
		arc = 72,
		tilt = 6,
		thick = 0.3,
		shrink = 0.1,
		lift = 0.5,
		n = 25,
		taper = 0.7,
		light = {
			color = {170, 210, 255},
			brightness = 6,
			range = 40,
			flash = 14,
			flash_time = 0.3,
		},
		gash = {
			seg = 10,
			start = 4,
			life = 1.9,
			fade = 0.5,
			cool = 0.3,
			spread = 0.25,
			open = 0.06,
			seam = {
				width = 0.6,
				height = 0.22,
				hot = {220, 240, 255},
				cold = {80, 150, 255},
				neon_k = 1.5,
				transparency = 0.25,
			},
			crevice = {
				width = 2.6,
				height = 0.15,
				color = {12, 14, 28},
			},
			frost = {
				texture = "mf_frost_patch",
				width = 11,
				overlap = 2.5,
				color = {180, 220, 255},
				light_emission = 0.4,
				transparency = 0.35,
			},
		},
		slabs = {
			spacing = 2.3,
			start = 6,
			gap = 1,
			wid = {1.6, 2.8},
			thick = {0.5, 1},
			len = {1.4, 2.6},
			tilt = {18, 44},
			yaw = 16,
			pitch = 10,
			show = 0.62,
			rise = 0.08,
			hold = {1.6, 2.1},
			sink = 0.5,
			delay = 0.04,
			seed = 5,
			ice = {
				frac = 0.3,
				wid = {1.8, 3},
				thick = {0.45, 0.8},
				len = {0.8, 1.5},
				tilt = {50, 72},
				color = {150, 200, 255},
				material = "Ice",
				transparency = 0.15,
				mesh = "IceSlab",
			},
		},
		crater = {
			count = 20,
			radius = 10,
			wid = {2.2, 4},
			thick = {0.8, 1.4},
			len = {2, 3.6},
			tilt = {30, 58},
			yaw = 12,
			pitch = 10,
			show = 0.6,
			rise = 0.1,
			hold = {1.9, 2.4},
			sink = 0.6,
			at = 0,
			delay = 0.05,
			seed = 6,
		},
		strands = {
			{
				name = "BladeHalo",
				j = 0.3,
				arc_k = 0.94,
				width = 6,
				texture = "mf_blade_glow",
				transparency = 0.62,
				color = {
					{
						0,
						{40, 80, 210},
					},
					{
						0.5,
						{80, 140, 255},
					},
					{
						1,
						{40, 80, 210},
					},
				},
				light_emission = 1,
				brightness = 1,
				zoffset = -1,
			},
			{
				name = "BladeStrand0",
				j = 0,
				arc_k = 1,
				width = 0.8,
				texture = "mf_blade_line",
				transparency = 0,
				color = {
					{
						0,
						{204, 204, 204},
					},
					{
						0.5,
						{255, 255, 255},
					},
					{
						1,
						{204, 204, 204},
					},
				},
				light_emission = 1,
				brightness = 3,
				zoffset = 3,
			},
			{
				name = "BladeStrand1",
				j = 0.09,
				arc_k = 0.98,
				width = 1.3,
				texture = "mf_blade_line",
				transparency = 0,
				color = {
					{
						0,
						{180, 194, 204},
					},
					{
						0.5,
						{225, 243, 255},
					},
					{
						1,
						{180, 194, 204},
					},
				},
				light_emission = 1,
				brightness = 2.2,
				zoffset = 2.6,
			},
			{
				name = "BladeStrand2",
				j = 0.19,
				arc_k = 0.95,
				width = 1.8,
				texture = "mf_blade_solid",
				transparency = 0.04,
				color = {
					{
						0,
						{136, 177, 204},
					},
					{
						0.5,
						{170, 222, 255},
					},
					{
						1,
						{136, 177, 204},
					},
				},
				light_emission = 1,
				brightness = 1.7,
				zoffset = 2.2,
			},
			{
				name = "BladeStrand3",
				j = 0.31,
				arc_k = 0.9,
				width = 2.2,
				texture = "mf_blade_solid",
				transparency = 0.12,
				color = {
					{
						0,
						{96, 156, 204},
					},
					{
						0.5,
						{120, 195, 255},
					},
					{
						1,
						{96, 156, 204},
					},
				},
				light_emission = 1,
				brightness = 1.4,
				zoffset = 1.8,
			},
			{
				name = "BladeStrand4",
				j = 0.44,
				arc_k = 0.84,
				width = 2.4,
				texture = "mf_blade_solid",
				transparency = 0.22,
				color = {
					{
						0,
						{72, 132, 204},
					},
					{
						0.5,
						{90, 165, 255},
					},
					{
						1,
						{72, 132, 204},
					},
				},
				light_emission = 1,
				brightness = 1.25,
				zoffset = 1.4,
			},
			{
				name = "BladeStrand5",
				j = 0.58,
				arc_k = 0.77,
				width = 2.4,
				texture = "mf_blade_solid",
				transparency = 0.34,
				color = {
					{
						0,
						{56, 108, 196},
					},
					{
						0.5,
						{70, 135, 245},
					},
					{
						1,
						{56, 108, 196},
					},
				},
				light_emission = 1,
				brightness = 1.1,
				zoffset = 1,
			},
			{
				name = "BladeStrand6",
				j = 0.72,
				arc_k = 0.69,
				width = 2.2,
				texture = "mf_blade_solid",
				transparency = 0.46,
				color = {
					{
						0,
						{44, 88, 188},
					},
					{
						0.5,
						{55, 110, 235},
					},
					{
						1,
						{44, 88, 188},
					},
				},
				light_emission = 1,
				brightness = 1,
				zoffset = 0.6,
			},
			{
				name = "BladeStrand7",
				j = 0.86,
				arc_k = 0.6,
				width = 1.9,
				texture = "mf_blade_solid",
				transparency = 0.58,
				color = {
					{
						0,
						{36, 72, 176},
					},
					{
						0.5,
						{45, 90, 220},
					},
					{
						1,
						{36, 72, 176},
					},
				},
				light_emission = 1,
				brightness = 1,
				zoffset = 0.2,
			},
			{
				name = "BladeStrand8",
				j = 1,
				arc_k = 0.5,
				width = 1.5,
				texture = "mf_blade_solid",
				transparency = 0.7,
				color = {
					{
						0,
						{32, 60, 160},
					},
					{
						0.5,
						{40, 75, 200},
					},
					{
						1,
						{32, 60, 160},
					},
				},
				light_emission = 1,
				brightness = 1,
				zoffset = -0.2,
			},
		},
		emitters = {
			{
				name = "TrailMist",
				texture = "fx_fog2001",
				direction = "Back",
				spread = {60, 60},
				speed = {1, 4},
				drag = 2,
				accel = {0, -1.5, 0},
				lifetime = {0.9, 1.4},
				size = {
					{0, 6, 1},
					{0.4, 13, 2},
					{1, 18, 3},
				},
				transparency = {
					{0, 0.78, 0},
					{0.3, 0.8, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{225, 240, 255},
					},
					{
						1,
						{190, 215, 250},
					},
				},
				light_emission = 0.15,
				rotation = {0, 360},
				rot_speed = {-40, 40},
				zoffset = -3,
				brightness = 1,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				at = {0.12, 0.25, 0.4, 0.55},
				j = 0.45,
				arc_k = 1,
				rate = 36,
			},
			{
				name = "TrailGlitter",
				texture = "fx_spark002",
				direction = "Back",
				spread = {180, 180},
				speed = {1, 4},
				drag = 1,
				accel = {0, -2, 0},
				lifetime = {0.5, 0.9},
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
						{225, 240, 255},
					},
					{
						1,
						{170, 205, 255},
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
				at = {0.1, 0.3, 0.5, 0.7, 0.9},
				j = 0.2,
				arc_k = 1,
				rate = 30,
			},
			{
				name = "TrailShards",
				texture = "mf_shard_2x2",
				flipbook = {
					layout = "Grid2x2",
					mode = "Loop",
					fps = 0.001,
					startRandom = true,
				},
				direction = "Back",
				spread = {50, 50},
				speed = {6, 14},
				drag = 0.6,
				accel = {0, -110, 0},
				lifetime = {0.5, 0.8},
				size = {
					{0, 0.9, 0.3},
					{1, 0.5, 0.2},
				},
				transparency = {
					{0, 0, 0},
					{0.8, 0.1, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{200, 230, 255},
					},
					{
						0.4,
						{120, 180, 255},
					},
					{
						1,
						{70, 120, 235},
					},
				},
				light_emission = 0.45,
				brightness = 1.4,
				rotation = {0, 360},
				rot_speed = {-500, 500},
				zoffset = 0,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				at = {0.25, 0.5, 0.75},
				j = 0.4,
				arc_k = 1,
				rate = 18,
			},
			{
				name = "TrailWind",
				texture = "kk_trace_03",
				orientation = "VelocityParallel",
				direction = "Back",
				spread = {6, 6},
				speed = {60, 90},
				drag = 4,
				lifetime = {0.15, 0.25},
				size = {
					{0, 5, 1},
					{1, 2, 0},
				},
				transparency = {
					{0, 0.35, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{230, 245, 255},
					},
					{
						0.5,
						{155, 210, 255},
					},
					{
						1,
						{85, 145, 245},
					},
				},
				light_emission = 1,
				brightness = 1.6,
				accel = {0, 0, 0},
				rotation = {0, 0},
				rot_speed = {0, 0},
				zoffset = 0,
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				at = {0.15, 0.4, 0.6, 0.85},
				j = 0.1,
				arc_k = 1,
				rate = 24,
			},
			{
				name = "TipGlint",
				texture = "kk_star_06",
				lifetime = {0.08, 0.12},
				size = {
					{0, 0, 0},
					{0.25, 7, 1.5},
					{1, 0, 0},
				},
				color = {
					{
						0,
						{255, 255, 255},
					},
					{
						0.5,
						{225, 240, 255},
					},
					{
						1,
						{170, 205, 255},
					},
				},
				light_emission = 1,
				brightness = 2.5,
				rotation = {0, 45},
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
				at = {0.5},
				j = 0,
				arc_k = 1,
				rate = 50,
			},
		},
	},
}

-- MOONFANG SKILL 1 (Medialuna): de un zarpazo lanza una media luna de energía que vuela vertical y de canto (de lado se ve la media luna; desde atrás, una hoja que apunta hacia donde va) y deja una estela de humo frío. Su cuerno de abajo corta el suelo: se abre una grieta con escarcha, las losas del suelo saltan a los lados y salen rocas que se quedan en el camino. Al llegar al final (0.76 s) detona en hielo y deja un cráter. MoonfangVFX.CrescentWave(CFrame.lookAt(origen, origen + dirección), largo, escala).
-- cf = el punto del suelo de donde sale, mirando hacia donde va. length = cuánto recorre (por defecto 130.0 × escala).
function MoonfangVFX.CrescentWave(cf: CFrame, length: number?, scale: number?, shake: number?): Part
	return playBlade(SPEC_CrescentWave, cf, scale, length or 130.0 * (scale or 1), shake)
end
-- segundo (desde la llamada) en que llega al final y detona: para sincronizar el daño
MoonfangVFX.CrescentWaveImpact = 0.76

local SPEC_IceWave = {
	name = "IceWave",
	duration = 4.6,
	cleanup = 5.55,
	layers = {
		{
			name = "SlamFlash",
			texture = "fx_glow",
			emit = {
				{0, 1},
			},
			offset = {0, 3, -4},
			lifetime = {0.2, 0.2},
			size = {
				{0, 8, 0},
				{0.3, 30, 0},
				{1, 34, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
				},
			},
			light_emission = 1,
			brightness = 1.1,
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
			name = "SlamStar",
			texture = "kk_star_09",
			emit = {
				{0, 1},
			},
			offset = {0, 3, -4},
			lifetime = {0.22, 0.22},
			size = {
				{0, 8, 0},
				{0.2, 34, 0},
				{1, 12, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			rotation = {0, 90},
			zoffset = 4,
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
			name = "SlamRing",
			texture = "kk_circle_02",
			emit = {
				{0.02, 1},
			},
			offset = {0, 0.3, -4},
			lifetime = {0.45, 0.45},
			size = {
				{0, 6, 0},
				{1, 60, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.5, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			name = "SlamMist",
			texture = "kk_smoke_07",
			emit = {
				{0.02, 8},
			},
			offset = {0, 2, -4},
			shape = {
				type = "Sphere",
				radius = 3,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {180, 180},
			speed = {18, 36},
			drag = 3,
			accel = {0, 2, 0},
			lifetime = {0.8, 1.2},
			size = {
				{0, 6, 1},
				{1, 18, 3},
			},
			transparency = {
				{0, 0.45, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{220, 236, 255},
				},
				{
					1,
					{175, 200, 240},
				},
			},
			rotation = {0, 360},
			zoffset = -2,
			light_emission = 0,
			brightness = 1,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "SlamShards",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			emit = {
				{0, 16},
			},
			offset = {0, 2, -4},
			shape = {
				type = "Sphere",
				radius = 2,
				style = "Volume",
				inout = "Outward",
			},
			direction = "Top",
			spread = {90, 90},
			speed = {30, 60},
			drag = 0.5,
			accel = {0, -110, 0},
			lifetime = {0.5, 0.8},
			size = {
				{0, 1.5, 0.4},
				{1, 1, 0.3},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "CrestSpray",
			texture = "kk_smoke_04",
			direction = "Top",
			spread = {30, 30},
			speed = {22, 44},
			drag = 2.5,
			accel = {0, -8, 0},
			lifetime = {0.6, 0.9},
			size = {
				{0, 4, 1},
				{1, 12, 2},
			},
			transparency = {
				{0, 0.35, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{240, 246, 255},
				},
				{
					1,
					{205, 218, 240},
				},
			},
			rotation = {0, 360},
			rot_speed = {-60, 60},
			cone_emit = {
				{0.154, 1, 0.05, -0.461, 0.6},
				{0.154, 1, 0.05, -0.173, 0.6},
				{0.154, 1, 0.05, 0.734, 0.6},
				{0.204, 1, 0.1231, -0.653, 0.6},
				{0.204, 1, 0.1231, 0.171, 0.6},
				{0.204, 1, 0.1231, 0.611, 0.6},
				{0.255, 1, 0.1962, -0.484, 0.6},
				{0.255, 1, 0.1962, -0.132, 0.6},
				{0.255, 1, 0.1962, 0.839, 0.6},
				{0.309, 1, 0.2692, -0.753, 0.6},
				{0.309, 1, 0.2692, -0.335, 0.6},
				{0.309, 1, 0.2692, 0.198, 0.6},
				{0.309, 1, 0.2692, 0.766, 0.6},
				{0.364, 1, 0.3423, -0.863, 0.6},
				{0.364, 1, 0.3423, -0.275, 0.6},
				{0.364, 1, 0.3423, 0.1, 0.6},
				{0.364, 1, 0.3423, 0.602, 0.6},
				{0.421, 1, 0.4154, -0.823, 0.6},
				{0.421, 1, 0.4154, -0.321, 0.6},
				{0.421, 1, 0.4154, 0.177, 0.6},
				{0.421, 1, 0.4154, 0.808, 0.6},
				{0.48, 1, 0.4885, -0.796, 0.6},
				{0.48, 1, 0.4885, -0.305, 0.6},
				{0.48, 1, 0.4885, 0.093, 0.6},
				{0.48, 1, 0.4885, 0.48, 0.6},
				{0.48, 1, 0.4885, 0.88, 0.6},
				{0.543, 1, 0.5615, -0.758, 0.6},
				{0.543, 1, 0.5615, -0.348, 0.6},
				{0.543, 1, 0.5615, 0.089, 0.6},
				{0.543, 1, 0.5615, 0.398, 0.6},
				{0.543, 1, 0.5615, 0.693, 0.6},
				{0.609, 1, 0.6346, -0.771, 0.6},
				{0.609, 1, 0.6346, -0.381, 0.6},
				{0.609, 1, 0.6346, -0.075, 0.6},
				{0.609, 1, 0.6346, 0.293, 0.6},
				{0.609, 1, 0.6346, 0.703, 0.6},
				{0.68, 1, 0.7077, -0.77, 0.6},
				{0.68, 1, 0.7077, -0.424, 0.6},
				{0.68, 1, 0.7077, -0.131, 0.6},
				{0.68, 1, 0.7077, 0.147, 0.6},
				{0.68, 1, 0.7077, 0.394, 0.6},
				{0.68, 1, 0.7077, 0.712, 0.6},
				{0.756, 1, 0.7808, -0.778, 0.6},
				{0.756, 1, 0.7808, -0.479, 0.6},
				{0.756, 1, 0.7808, -0.17, 0.6},
				{0.756, 1, 0.7808, 0.098, 0.6},
				{0.756, 1, 0.7808, 0.412, 0.6},
				{0.756, 1, 0.7808, 0.746, 0.6},
				{0.843, 1, 0.8538, -0.88, 0.6},
				{0.843, 1, 0.8538, -0.466, 0.6},
				{0.843, 1, 0.8538, -0.199, 0.6},
				{0.843, 1, 0.8538, 0.172, 0.6},
				{0.843, 1, 0.8538, 0.471, 0.6},
				{0.843, 1, 0.8538, 0.818, 0.6},
				{0.945, 1, 0.9269, -0.791, 0.6},
				{0.945, 1, 0.9269, -0.508, 0.6},
				{0.945, 1, 0.9269, -0.335, 0.6},
				{0.945, 1, 0.9269, 0.076, 0.6},
				{0.945, 1, 0.9269, 0.336, 0.6},
				{0.945, 1, 0.9269, 0.607, 0.6},
				{0.945, 1, 0.9269, 0.824, 0.6},
				{1.12, 1, 1, -0.756, 0.6},
				{1.12, 1, 1, -0.502, 0.6},
				{1.12, 1, 1, -0.321, 0.6},
				{1.12, 1, 1, 0.031, 0.6},
				{1.12, 1, 1, 0.335, 0.6},
				{1.12, 1, 1, 0.596, 0.6},
				{1.12, 1, 1, 0.898, 0.6},
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
			name = "CrestShards",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 40,
			spread = {25, 20},
			speed = {30, 60},
			drag = 0.5,
			accel = {0, -120, 0},
			lifetime = {0.5, 0.9},
			size = {
				{0, 1.3, 0.4},
				{1, 0.8, 0.3},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			cone_emit = {
				{0.154, 1, 0.05, -0.468, 0.8},
				{0.154, 1, 0.05, 0.585, 0.8},
				{0.213, 1, 0.1364, -0.732, 0.8},
				{0.213, 1, 0.1364, 0.58, 0.8},
				{0.275, 1, 0.2227, -0.691, 0.8},
				{0.275, 1, 0.2227, 0.615, 0.8},
				{0.338, 1, 0.3091, -0.491, 0.8},
				{0.338, 1, 0.3091, -0.05, 0.8},
				{0.338, 1, 0.3091, 0.48, 0.8},
				{0.405, 1, 0.3955, -0.824, 0.8},
				{0.405, 1, 0.3955, 0.006, 0.8},
				{0.405, 1, 0.3955, 0.513, 0.8},
				{0.475, 1, 0.4818, -0.554, 0.8},
				{0.475, 1, 0.4818, 0.043, 0.8},
				{0.475, 1, 0.4818, 0.647, 0.8},
				{0.549, 1, 0.5682, -0.678, 0.8},
				{0.549, 1, 0.5682, -0.344, 0.8},
				{0.549, 1, 0.5682, 0.23, 0.8},
				{0.549, 1, 0.5682, 0.595, 0.8},
				{0.628, 1, 0.6545, -0.714, 0.8},
				{0.628, 1, 0.6545, -0.157, 0.8},
				{0.628, 1, 0.6545, 0.142, 0.8},
				{0.628, 1, 0.6545, 0.782, 0.8},
				{0.714, 1, 0.7409, -0.584, 0.8},
				{0.714, 1, 0.7409, -0.294, 0.8},
				{0.714, 1, 0.7409, 0.158, 0.8},
				{0.714, 1, 0.7409, 0.655, 0.8},
				{0.81, 1, 0.8273, -0.631, 0.8},
				{0.81, 1, 0.8273, -0.365, 0.8},
				{0.81, 1, 0.8273, 0.323, 0.8},
				{0.81, 1, 0.8273, 0.658, 0.8},
				{0.925, 1, 0.9136, -0.716, 0.8},
				{0.925, 1, 0.9136, -0.298, 0.8},
				{0.925, 1, 0.9136, 0.081, 0.8},
				{0.925, 1, 0.9136, 0.316, 0.8},
				{0.925, 1, 0.9136, 0.787, 0.8},
				{1.12, 1, 1, -0.819, 0.8},
				{1.12, 1, 1, -0.301, 0.8},
				{1.12, 1, 1, -0.048, 0.8},
				{1.12, 1, 1, 0.311, 0.8},
				{1.12, 1, 1, 0.754, 0.8},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CrestSpikes",
			texture = "mf_spike",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {20, 20},
			speed = {26, 44},
			drag = 12,
			lifetime = {0.7, 1},
			size = {
				{0, 0.6, 0},
				{0.12, 6, 1.5},
				{0.8, 6.5, 1.5},
				{1, 0, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.5,
			brightness = 1.6,
			cone_emit = {
				{0.154, 1, 0.05, -0.726, 0.3},
				{0.154, 1, 0.05, 0.324, 0.3},
				{0.216, 1, 0.14, -0.568, 0.3},
				{0.216, 1, 0.14, -0.067, 0.3},
				{0.216, 1, 0.14, 0.524, 0.3},
				{0.28, 1, 0.23, -0.478, 0.3},
				{0.28, 1, 0.23, -0.093, 0.3},
				{0.28, 1, 0.23, 0.761, 0.3},
				{0.347, 1, 0.32, -0.575, 0.3},
				{0.347, 1, 0.32, 0.022, 0.3},
				{0.347, 1, 0.32, 0.704, 0.3},
				{0.417, 1, 0.41, -0.704, 0.3},
				{0.417, 1, 0.41, -0.143, 0.3},
				{0.417, 1, 0.41, 0.299, 0.3},
				{0.417, 1, 0.41, 0.66, 0.3},
				{0.49, 1, 0.5, -0.682, 0.3},
				{0.49, 1, 0.5, -0.24, 0.3},
				{0.49, 1, 0.5, 0.365, 0.3},
				{0.49, 1, 0.5, 0.616, 0.3},
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
			name = "CrestSpikesFar",
			texture = "mf_spike",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {20, 20},
			speed = {30, 50},
			drag = 12,
			lifetime = {0.8, 1.1},
			size = {
				{0, 0.8, 0},
				{0.12, 9.5, 2},
				{0.8, 10, 2},
				{1, 0, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.5,
			brightness = 1.6,
			cone_emit = {
				{0.533, 1, 0.55, -0.787, 0.3},
				{0.533, 1, 0.55, -0.279, 0.3},
				{0.533, 1, 0.55, -0.101, 0.3},
				{0.533, 1, 0.55, 0.441, 0.3},
				{0.533, 1, 0.55, 0.869, 0.3},
				{0.6, 1, 0.625, -0.751, 0.3},
				{0.6, 1, 0.625, -0.491, 0.3},
				{0.6, 1, 0.625, 0.064, 0.3},
				{0.6, 1, 0.625, 0.333, 0.3},
				{0.6, 1, 0.625, 0.78, 0.3},
				{0.672, 1, 0.7, -0.747, 0.3},
				{0.672, 1, 0.7, -0.521, 0.3},
				{0.672, 1, 0.7, -0.211, 0.3},
				{0.672, 1, 0.7, 0.087, 0.3},
				{0.672, 1, 0.7, 0.455, 0.3},
				{0.672, 1, 0.7, 0.731, 0.3},
				{0.75, 1, 0.775, -0.771, 0.3},
				{0.75, 1, 0.775, -0.421, 0.3},
				{0.75, 1, 0.775, -0.248, 0.3},
				{0.75, 1, 0.775, 0.167, 0.3},
				{0.75, 1, 0.775, 0.542, 0.3},
				{0.75, 1, 0.775, 0.862, 0.3},
				{0.838, 1, 0.85, -0.854, 0.3},
				{0.838, 1, 0.85, -0.479, 0.3},
				{0.838, 1, 0.85, -0.126, 0.3},
				{0.838, 1, 0.85, 0.166, 0.3},
				{0.838, 1, 0.85, 0.582, 0.3},
				{0.838, 1, 0.85, 0.888, 0.3},
				{0.942, 1, 0.925, -0.754, 0.3},
				{0.942, 1, 0.925, -0.617, 0.3},
				{0.942, 1, 0.925, -0.356, 0.3},
				{0.942, 1, 0.925, 0.015, 0.3},
				{0.942, 1, 0.925, 0.29, 0.3},
				{0.942, 1, 0.925, 0.515, 0.3},
				{0.942, 1, 0.925, 0.789, 0.3},
				{1.12, 1, 1, -0.784, 0.3},
				{1.12, 1, 1, -0.505, 0.3},
				{1.12, 1, 1, -0.358, 0.3},
				{1.12, 1, 1, -0.063, 0.3},
				{1.12, 1, 1, 0.314, 0.3},
				{1.12, 1, 1, 0.541, 0.3},
				{1.12, 1, 1, 0.774, 0.3},
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
			name = "CrestGlints",
			texture = "kk_star_06",
			direction = "Top",
			spread = {60, 60},
			speed = {4, 10},
			drag = 1.5,
			lifetime = {0.4, 0.7},
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 2,
			rotation = {0, 45},
			cone_emit = {
				{0.154, 1, 0.05, -0.224, 2},
				{0.154, 1, 0.05, 0.386, 2},
				{0.213, 1, 0.1364, -0.731, 2},
				{0.213, 1, 0.1364, 0.434, 2},
				{0.275, 1, 0.2227, -0.54, 2},
				{0.275, 1, 0.2227, 0.57, 2},
				{0.338, 1, 0.3091, -0.33, 2},
				{0.338, 1, 0.3091, 0.242, 2},
				{0.405, 1, 0.3955, -0.502, 2},
				{0.405, 1, 0.3955, 0.719, 2},
				{0.475, 1, 0.4818, -0.652, 2},
				{0.475, 1, 0.4818, 0.15, 2},
				{0.475, 1, 0.4818, 0.802, 2},
				{0.549, 1, 0.5682, -0.529, 2},
				{0.549, 1, 0.5682, 0.059, 2},
				{0.549, 1, 0.5682, 0.495, 2},
				{0.628, 1, 0.6545, -0.459, 2},
				{0.628, 1, 0.6545, -0.077, 2},
				{0.628, 1, 0.6545, 0.571, 2},
				{0.714, 1, 0.7409, -0.645, 2},
				{0.714, 1, 0.7409, 0.014, 2},
				{0.714, 1, 0.7409, 0.752, 2},
				{0.81, 1, 0.8273, -0.716, 2},
				{0.81, 1, 0.8273, -0.12, 2},
				{0.81, 1, 0.8273, 0.326, 2},
				{0.81, 1, 0.8273, 0.77, 2},
				{0.925, 1, 0.9136, -0.793, 2},
				{0.925, 1, 0.9136, -0.203, 2},
				{0.925, 1, 0.9136, 0.243, 2},
				{0.925, 1, 0.9136, 0.803, 2},
				{1.12, 1, 1, -0.793, 2},
				{1.12, 1, 1, -0.157, 2},
				{1.12, 1, 1, 0.305, 2},
				{1.12, 1, 1, 0.634, 2},
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
			name = "FrostFloor",
			texture = "mf_frost_patch",
			lifetime = {2.2, 2.6},
			rotation = {0, 360},
			size = {
				{0, 6, 0},
				{0.06, 18, 3},
				{1, 19, 3},
			},
			transparency = {
				{0, 0.3, 0},
				{0.8, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{190, 225, 255},
				},
				{
					1,
					{150, 200, 255},
				},
			},
			light_emission = 0.5,
			cone_emit = {
				{0.216, 1, 0.0532, 0.045, 0.2},
				{0.25, 1, 0.1866, -0.921, 0.2},
				{0.291, 1, 0.197, 0.405, 0.2},
				{0.295, 1, 0.2265, 0.242, 0.2},
				{0.381, 1, 0.2977, 0.805, 0.2},
				{0.391, 1, 0.3343, -0.647, 0.2},
				{0.42, 1, 0.3409, 0.503, 0.2},
				{0.48, 1, 0.446, -0.651, 0.2},
				{0.488, 1, 0.4607, 0.073, 0.2},
				{0.497, 1, 0.4667, -0.73, 0.2},
				{0.499, 1, 0.4586, 0.29, 0.2},
				{0.508, 1, 0.4965, -0.687, 0.2},
				{0.554, 1, 0.4867, 0.632, 0.2},
				{0.609, 1, 0.5675, -0.31, 0.2},
				{0.61, 1, 0.5541, -0.931, 0.2},
				{0.624, 1, 0.5854, 0.781, 0.2},
				{0.625, 1, 0.6493, -0.507, 0.2},
				{0.63, 1, 0.589, 0.639, 0.2},
				{0.636, 1, 0.6199, -0.717, 0.2},
				{0.659, 1, 0.6295, 0.856, 0.2},
				{0.662, 1, 0.6232, 0.802, 0.2},
				{0.667, 1, 0.6282, -0.168, 0.2},
				{0.677, 1, 0.6835, 0.153, 0.2},
				{0.677, 1, 0.6918, -0.637, 0.2},
				{0.705, 1, 0.6764, 0.913, 0.2},
				{0.713, 1, 0.6682, 0.431, 0.2},
				{0.717, 1, 0.6769, -0.8, 0.2},
				{0.725, 1, 0.7459, 0.056, 0.2},
				{0.731, 1, 0.7538, -0.172, 0.2},
				{0.736, 1, 0.7235, -0.58, 0.2},
				{0.74, 1, 0.7302, -0.718, 0.2},
				{0.759, 1, 0.7365, -0.931, 0.2},
				{0.761, 1, 0.7701, 0.61, 0.2},
				{0.807, 1, 0.8153, 0.429, 0.2},
				{0.81, 1, 0.8056, -0.128, 0.2},
				{0.817, 1, 0.7665, -0.469, 0.2},
				{0.849, 1, 0.7946, 0.619, 0.2},
				{0.876, 1, 0.8495, 0.018, 0.2},
				{0.883, 1, 0.8665, 0.112, 0.2},
				{0.9, 1, 0.8867, -0.652, 0.2},
				{0.973, 1, 0.8936, 0.738, 0.2},
				{0.974, 1, 0.9209, -0.483, 0.2},
				{1.026, 1, 0.9285, 0.164, 0.2},
				{1.06, 1, 0.9688, -0.112, 0.2},
				{1.119, 1, 0.992, 0.929, 0.2},
				{1.127, 1, 0.9817, 0.129, 0.2},
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
			name = "FrostCracks",
			texture = "mf_frost_cracks",
			lifetime = {2, 2.4},
			rotation = {0, 360},
			size = {
				{0, 8, 0},
				{0.06, 24, 4},
				{1, 25, 4},
			},
			transparency = {
				{0, 0.4, 0},
				{0.3, 0.45, 0},
				{0.8, 0.65, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 185, 255},
				},
				{
					0.15,
					{225, 242, 255},
				},
				{
					0.35,
					{130, 190, 255},
				},
				{
					1,
					{40, 80, 200},
				},
			},
			light_emission = 0.5,
			cone_emit = {
				{0.325, 1, 0.2582, 0.594, 0.25},
				{0.352, 1, 0.2947, -0.288, 0.25},
				{0.506, 1, 0.5021, 0.254, 0.25},
				{0.572, 1, 0.5652, -0.777, 0.25},
				{0.59, 1, 0.5943, 0.485, 0.25},
				{0.613, 1, 0.6302, 0.631, 0.25},
				{0.655, 1, 0.6473, 0.81, 0.25},
				{0.74, 1, 0.7553, 0.872, 0.25},
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
			name = "GroundCracks",
			texture = "mf_frost_cracks",
			lifetime = {2.6, 3.2},
			rotation = {0, 360},
			size = {
				{0, 8, 0},
				{0.05, 22, 4},
				{1, 23, 4},
			},
			transparency = {
				{0, 0.25, 0},
				{0.75, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{34, 40, 56},
				},
				{
					1,
					{40, 46, 62},
				},
			},
			cone_emit = {
				{0.242, 1, 0.1778, 0.043, 0.15},
				{0.27, 1, 0.2164, -0.825, 0.15},
				{0.282, 1, 0.2323, 0.808, 0.15},
				{0.343, 1, 0.3155, 0.677, 0.15},
				{0.365, 1, 0.3438, 0.256, 0.15},
				{0.513, 1, 0.5272, 0.303, 0.15},
				{0.543, 1, 0.5613, -0.298, 0.15},
				{0.545, 1, 0.5638, -0.119, 0.15},
				{0.604, 1, 0.6296, 0.267, 0.15},
				{0.615, 1, 0.6416, 0.644, 0.15},
				{0.621, 1, 0.6474, 0.23, 0.15},
				{0.789, 1, 0.8096, -0.864, 0.15},
				{0.798, 1, 0.8177, -0.855, 0.15},
				{0.85, 1, 0.86, 0.271, 0.15},
				{0.861, 1, 0.8684, 0.039, 0.15},
				{0.97, 1, 0.9419, -0.639, 0.15},
				{0.994, 1, 0.9551, 0.685, 0.15},
				{0.997, 1, 0.957, 0.427, 0.15},
				{1.001, 1, 0.9588, 0.85, 0.15},
				{1.014, 1, 0.9654, 0.08, 0.15},
				{1.02, 1, 0.9682, 0.361, 0.15},
				{1.069, 1, 0.9886, -0.773, 0.15},
				{1.094, 1, 0.9958, 0.217, 0.15},
				{1.102, 1, 0.9976, -0.576, 0.15},
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
			name = "FieldDust",
			texture = "kk_smoke_04",
			direction = "Top",
			spread = {70, 70},
			speed = {6, 14},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {0.6, 1},
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
					{215, 228, 248},
				},
				{
					1,
					{175, 190, 222},
				},
			},
			rotation = {0, 360},
			zoffset = -2,
			cone_emit = {
				{0.257, 1, 0.1855, 0.333, 0.8},
				{0.26, 1, 0.1949, -0.124, 0.8},
				{0.289, 1, 0.1758, -0.433, 0.8},
				{0.327, 1, 0.2493, -0.431, 0.8},
				{0.416, 1, 0.397, 0.15, 0.8},
				{0.418, 1, 0.3828, 0.498, 0.8},
				{0.49, 1, 0.4686, 0.683, 0.8},
				{0.499, 1, 0.4753, -0.384, 0.8},
				{0.551, 1, 0.5497, -0.502, 0.8},
				{0.602, 1, 0.6061, 0.581, 0.8},
				{0.624, 1, 0.6161, 0.25, 0.8},
				{0.626, 1, 0.6356, 0.386, 0.8},
				{0.628, 1, 0.6168, -0.867, 0.8},
				{0.655, 1, 0.6626, 0.212, 0.8},
				{0.676, 1, 0.676, 0.442, 0.8},
				{0.687, 1, 0.6639, -0.89, 0.8},
				{0.703, 1, 0.6987, -0.66, 0.8},
				{0.739, 1, 0.7534, -0.096, 0.8},
				{0.747, 1, 0.752, 0.289, 0.8},
				{0.787, 1, 0.781, 0.663, 0.8},
				{0.802, 1, 0.8186, -0.778, 0.8},
				{0.809, 1, 0.7918, -0.372, 0.8},
				{0.81, 1, 0.7848, -0.239, 0.8},
				{0.814, 1, 0.8188, -0.195, 0.8},
				{0.832, 1, 0.8082, 0.514, 0.8},
				{0.891, 1, 0.8864, 0.53, 0.8},
				{0.969, 1, 0.9164, -0.772, 0.8},
				{1.089, 1, 0.9801, 0.906, 0.8},
				{1.101, 1, 0.9919, -0.407, 0.8},
				{1.107, 1, 0.9922, -0.469, 0.8},
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
			name = "FieldChips",
			texture = "om_cubes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Top",
			spread = {55, 55},
			speed = {25, 55},
			drag = 0.4,
			accel = {0, -130, 0},
			lifetime = {0.6, 0.9},
			size = {
				{0, 0.9, 0.3},
				{1, 0.7, 0.2},
			},
			color = {
				{
					0,
					{128, 126, 136},
				},
				{
					1,
					{100, 98, 108},
				},
			},
			rotation = {0, 360},
			rot_speed = {-500, 500},
			cone_emit = {
				{0.239, 2, 0.1731, 0.59, 0.5},
				{0.317, 2, 0.2809, 0.503, 0.5},
				{0.348, 2, 0.3219, -0.183, 0.5},
				{0.349, 2, 0.3225, -0.465, 0.5},
				{0.364, 2, 0.3421, 0.432, 0.5},
				{0.372, 2, 0.3532, 0.9, 0.5},
				{0.393, 2, 0.3804, -0.632, 0.5},
				{0.408, 2, 0.3994, -0.595, 0.5},
				{0.415, 2, 0.4086, 0.472, 0.5},
				{0.425, 2, 0.4203, -0.753, 0.5},
				{0.434, 2, 0.4322, 0.871, 0.5},
				{0.47, 2, 0.4765, -0.866, 0.5},
				{0.51, 2, 0.5235, -0.637, 0.5},
				{0.527, 2, 0.5437, -0.739, 0.5},
				{0.566, 2, 0.5879, 0.804, 0.5},
				{0.601, 2, 0.6259, -0.702, 0.5},
				{0.613, 2, 0.6388, -0.809, 0.5},
				{0.697, 2, 0.7254, 0.564, 0.5},
				{0.836, 2, 0.8489, 0.429, 0.5},
				{0.838, 2, 0.8506, 0.534, 0.5},
				{0.846, 2, 0.8563, -0.064, 0.5},
				{0.85, 2, 0.86, 0.436, 0.5},
				{0.857, 2, 0.8654, -0.004, 0.5},
				{0.861, 2, 0.8685, 0.553, 0.5},
				{0.881, 2, 0.8831, 0.528, 0.5},
				{0.885, 2, 0.8858, 0.175, 0.5},
				{0.902, 2, 0.8982, 0.219, 0.5},
				{0.902, 2, 0.8984, 0.762, 0.5},
				{0.903, 2, 0.8992, 0.803, 0.5},
				{0.921, 2, 0.9109, -0.766, 0.5},
				{1.01, 2, 0.9635, -0.199, 0.5},
				{1.032, 2, 0.9739, 0.802, 0.5},
				{1.049, 2, 0.9811, -0.865, 0.5},
				{1.065, 2, 0.9872, 0.173, 0.5},
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
			name = "FieldSmoke",
			texture = "fx_fog2001",
			direction = "Top",
			spread = {30, 30},
			speed = {2, 6},
			drag = 1,
			accel = {0, 1.5, 0},
			lifetime = {2, 3},
			size = {
				{0, 8, 2},
				{0.5, 18, 3},
				{1, 24, 3},
			},
			transparency = {
				{0, 0.72, 0},
				{0.3, 0.62, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{220, 236, 255},
				},
				{
					1,
					{175, 200, 240},
				},
			},
			light_emission = 0.15,
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -3,
			cone_emit = {
				{0.511, 1, 0.3234, -0.725, 1.41},
				{0.543, 1, 0.4385, -0.595, 2.91},
				{0.707, 1, 0.6075, 0.853, 2.93},
				{0.753, 1, 0.1345, -0.183, 1.1},
				{0.761, 1, 0.4908, -0.688, 2.32},
				{0.827, 1, 0.4676, -0.566, 1.13},
				{0.836, 1, 0.5985, -0.515, 1.71},
				{0.841, 1, 0.7381, -0.228, 1.8},
				{0.877, 1, 0.6055, -0.321, 1.28},
				{0.887, 1, 0.2174, -0.875, 1.98},
				{0.949, 1, 0.7343, -0.651, 1.94},
				{0.96, 1, 0.293, 0.01, 1.15},
				{0.982, 1, 0.2986, 0.056, 2.68},
				{1.02, 1, 0.8422, -0.407, 2.52},
				{1.032, 1, 0.6257, 0.123, 1.1},
				{1.045, 1, 0.7028, 0.036, 1.85},
				{1.049, 1, 0.92, -0.567, 1.29},
				{1.054, 1, 0.8679, -0.448, 1.36},
				{1.061, 1, 0.7046, 0.844, 2.41},
				{1.079, 1, 0.3954, 0.001, 2.03},
				{1.089, 1, 0.7324, -0.385, 1.99},
				{1.12, 1, 0.927, 0.66, 2.12},
				{1.14, 1, 0.7416, 0.905, 2.16},
				{1.142, 1, 0.615, -0.256, 1.59},
				{1.216, 1, 0.9471, -0.318, 1.46},
				{1.231, 1, 0.9724, 0.219, 1.07},
				{1.246, 1, 0.9623, -0.225, 1.9},
				{1.259, 1, 0.9721, 0.754, 1.54},
				{1.261, 1, 0.8791, 0.71, 2.65},
				{1.265, 1, 0.9974, -0.151, 1.26},
				{1.311, 1, 0.8881, 0.113, 2.48},
				{1.322, 1, 0.9579, -0.795, 1.83},
				{1.337, 1, 0.9552, 0.917, 1.93},
				{1.36, 1, 0.7158, 0.571, 1.03},
				{1.416, 1, 0.7777, -0.384, 2.16},
				{1.421, 1, 0.9716, -0.629, 1.01},
				{1.533, 1, 0.8773, 0.438, 1.09},
				{1.593, 1, 0.9641, 0.906, 1.58},
				{1.616, 1, 0.9231, -0.209, 1.5},
				{1.758, 1, 0.9984, 0.455, 1.03},
			},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "WaveRocks",
			type = "meteor",
			direction = "Front",
			pitch = 45,
			spread = {25, 20},
			speed = {50, 95},
			accel = {0, -196, 0},
			drag = 0.1,
			lifetime = {2.2, 2.2},
			trails = {
				{
					name = "WaveRockDust",
					rate = 12,
					texture = "kk_smoke_04",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 1.5, 0.5},
						{1, 4, 1},
					},
					transparency = {
						{0, 0.55, 0},
						{0.5, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
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
					speed = {4, 10},
					drag = 2,
					accel = {0, 3, 0},
					lifetime = {0.5, 0.8},
					size = {
						{0, 3, 1},
						{1, 8, 2},
					},
					transparency = {
						{0, 0.5, 0},
						{0.4, 0.6, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
						},
					},
					rotation = {0, 360},
					zoffset = -2,
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
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
						size = {2, 1.5, 2},
						style = "Volume",
						inout = "Outward",
					},
					direction = "Top",
					spread = {70, 70},
					speed = {6, 16},
					drag = 0.5,
					accel = {0, -110, 0},
					lifetime = {0.35, 0.55},
					size = {
						{0, 0.9, 0.3},
						{1, 0.7, 0.2},
					},
					color = {
						{
							0,
							{120, 118, 128},
						},
						{
							1,
							{96, 94, 104},
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
					name = "RockDust",
					texture = "kk_smoke_04",
					emit = {
						{0, 2},
					},
					direction = "Top",
					spread = {60, 60},
					speed = {2, 6},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 2, 0.5},
						{1, 6, 1},
					},
					transparency = {
						{0, 0.6, 0},
						{0.4, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
						},
					},
					rotation = {0, 360},
					zoffset = -2,
					accel = {0, 0, 0},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			cone_emit = {
				{0.233, 1, 0.1641, -0.02, 0.5},
				{0.263, 1, 0.2068, 0.583, 0.5},
				{0.3, 1, 0.2571, 0.445, 0.5},
				{0.306, 1, 0.2663, -0.292, 0.5},
				{0.343, 1, 0.3152, 0.304, 0.5},
				{0.403, 1, 0.3923, -0.916, 0.5},
				{0.424, 1, 0.4193, 0.005, 0.5},
				{0.448, 1, 0.449, -0.142, 0.5},
				{0.473, 1, 0.4799, -0.752, 0.5},
				{0.479, 1, 0.4873, -0.704, 0.5},
				{0.507, 1, 0.5204, -0.304, 0.5},
				{0.51, 1, 0.5235, -0.73, 0.5},
				{0.543, 1, 0.5614, 0.898, 0.5},
				{0.556, 1, 0.5765, 0.854, 0.5},
				{0.602, 1, 0.6269, 0.245, 0.5},
				{0.606, 1, 0.6311, 0.618, 0.5},
				{0.632, 1, 0.6595, 0.289, 0.5},
				{0.663, 1, 0.6909, 0.507, 0.5},
				{0.678, 1, 0.7066, -0.682, 0.5},
				{0.68, 1, 0.7081, 0.95, 0.5},
				{0.682, 1, 0.7101, -0.54, 0.5},
				{0.685, 1, 0.7131, 0.237, 0.5},
				{0.692, 1, 0.7199, 0.545, 0.5},
				{0.694, 1, 0.7217, 0.696, 0.5},
				{0.701, 1, 0.7291, -0.346, 0.5},
				{0.708, 1, 0.7353, 0.159, 0.5},
				{0.714, 1, 0.7413, 0.132, 0.5},
				{0.715, 1, 0.7425, -0.317, 0.5},
				{0.731, 1, 0.7578, -0.386, 0.5},
				{0.734, 1, 0.76, 0.341, 0.5},
				{0.754, 1, 0.779, 0.429, 0.5},
				{0.778, 1, 0.7999, -0.398, 0.5},
				{0.802, 1, 0.8206, -0.556, 0.5},
				{0.841, 1, 0.8528, 0.514, 0.5},
				{0.843, 1, 0.8544, 0.078, 0.5},
				{0.846, 1, 0.8567, 0.066, 0.5},
				{0.853, 1, 0.8617, -0.913, 0.5},
				{0.854, 1, 0.8625, -0.276, 0.5},
				{0.854, 1, 0.863, -0.848, 0.5},
				{0.859, 1, 0.867, 0.642, 0.5},
				{0.903, 1, 0.8988, -0.304, 0.5},
				{0.928, 1, 0.9159, -0.385, 0.5},
				{0.931, 1, 0.9178, -0.617, 0.5},
				{0.956, 1, 0.9336, -0.935, 0.5},
				{0.988, 1, 0.9523, -0.662, 0.5},
				{0.99, 1, 0.9533, -0.066, 0.5},
				{1.028, 1, 0.9723, -0.78, 0.5},
				{1.031, 1, 0.9735, 0.444, 0.5},
				{1.059, 1, 0.9848, -0.747, 0.5},
				{1.081, 1, 0.9922, -0.894, 0.5},
			},
			offset = {0, 0, 0},
			emit = {},
			rock = {
				size = {1.2, 3},
				spin = {-420, 420},
				material = "Slate",
				color = {96, 94, 104},
				aspect = {1, 1, 1},
				upright = false,
				stick = 1.2,
				sink = 0.2,
				ground = true,
				color_var = {0.8, 1.1},
			},
		},
		{
			name = "WaveChunks",
			type = "meteor",
			direction = "Front",
			pitch = 55,
			spread = {20, 20},
			speed = {45, 75},
			accel = {0, -196, 0},
			drag = 0.1,
			lifetime = {2.4, 2.4},
			trails = {
				{
					name = "WaveChunkDust",
					rate = 16,
					texture = "kk_smoke_04",
					speed = {0, 2},
					direction = "Top",
					spread = {180, 180},
					drag = 2,
					lifetime = {0.5, 0.7},
					size = {
						{0, 2.5, 0.5},
						{1, 6, 1},
					},
					transparency = {
						{0, 0.5, 0},
						{0.5, 0.62, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
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
					speed = {4, 10},
					drag = 2,
					accel = {0, 3, 0},
					lifetime = {0.5, 0.8},
					size = {
						{0, 3, 1},
						{1, 8, 2},
					},
					transparency = {
						{0, 0.5, 0},
						{0.4, 0.6, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
						},
					},
					rotation = {0, 360},
					zoffset = -2,
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
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
						size = {2, 1.5, 2},
						style = "Volume",
						inout = "Outward",
					},
					direction = "Top",
					spread = {70, 70},
					speed = {6, 16},
					drag = 0.5,
					accel = {0, -110, 0},
					lifetime = {0.35, 0.55},
					size = {
						{0, 0.9, 0.3},
						{1, 0.7, 0.2},
					},
					color = {
						{
							0,
							{120, 118, 128},
						},
						{
							1,
							{96, 94, 104},
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
					name = "RockDust",
					texture = "kk_smoke_04",
					emit = {
						{0, 2},
					},
					direction = "Top",
					spread = {60, 60},
					speed = {2, 6},
					drag = 2,
					lifetime = {0.4, 0.6},
					size = {
						{0, 2, 0.5},
						{1, 6, 1},
					},
					transparency = {
						{0, 0.6, 0},
						{0.4, 0.65, 0},
						{1, 1, 0},
					},
					color = {
						{
							0,
							{215, 228, 248},
						},
						{
							1,
							{175, 190, 222},
						},
					},
					rotation = {0, 360},
					zoffset = -2,
					accel = {0, 0, 0},
					light_emission = 0,
					brightness = 1,
					rot_speed = {0, 0},
					orientation = "FacingCamera",
					offset = {0, 0, 0},
					line_u = 0,
				},
			},
			cone_emit = {
				{0.356, 1, 0.3323, 0.942, 0.5},
				{0.362, 1, 0.3406, -0.609, 0.5},
				{0.386, 1, 0.3716, -0.623, 0.5},
				{0.392, 1, 0.3783, 0.297, 0.5},
				{0.443, 1, 0.4425, 0.343, 0.5},
				{0.52, 1, 0.5354, -0.941, 0.5},
				{0.586, 1, 0.61, 0.742, 0.5},
				{0.622, 1, 0.6487, -0.436, 0.5},
				{0.635, 1, 0.6621, 0.622, 0.5},
				{0.735, 1, 0.7613, 0.282, 0.5},
				{0.736, 1, 0.7621, -0.124, 0.5},
				{0.85, 1, 0.8596, 0.029, 0.5},
			},
			offset = {0, 0, 0},
			emit = {},
			rock = {
				size = {2.5, 4.5},
				spin = {-300, 300},
				material = "Slate",
				color = {96, 94, 104},
				aspect = {1, 0.8, 1},
				upright = false,
				stick = 1.4,
				sink = 0.25,
				ground = true,
				color_var = {0.8, 1.1},
			},
		},
		{
			name = "CrashSpray",
			texture = "kk_smoke_07",
			direction = "Top",
			spread = {35, 35},
			speed = {20, 45},
			drag = 2.5,
			accel = {0, -6, 0},
			lifetime = {0.7, 1.1},
			size = {
				{0, 6, 1},
				{1, 18, 3},
			},
			transparency = {
				{0, 0.4, 0},
				{0.4, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{240, 246, 255},
				},
				{
					1,
					{205, 218, 240},
				},
			},
			rotation = {0, 360},
			rot_speed = {-40, 40},
			cone_emit = {
				{1.023, 1, 0.98, -0.97, 1},
				{1.023, 1, 0.98, -0.841, 1},
				{1.023, 1, 0.98, -0.711, 1},
				{1.023, 1, 0.98, -0.582, 1},
				{1.023, 1, 0.98, -0.453, 1},
				{1.023, 1, 0.98, -0.323, 1},
				{1.023, 1, 0.98, -0.194, 1},
				{1.023, 1, 0.98, -0.065, 1},
				{1.023, 1, 0.98, 0.065, 1},
				{1.023, 1, 0.98, 0.194, 1},
				{1.023, 1, 0.98, 0.323, 1},
				{1.023, 1, 0.98, 0.453, 1},
				{1.023, 1, 0.98, 0.582, 1},
				{1.023, 1, 0.98, 0.711, 1},
				{1.023, 1, 0.98, 0.841, 1},
				{1.023, 1, 0.98, 0.97, 1},
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
			name = "CrashSpikes",
			texture = "mf_spike",
			orientation = "VelocityParallel",
			direction = "Front",
			pitch = 60,
			spread = {20, 20},
			speed = {30, 50},
			drag = 12,
			lifetime = {0.9, 1.2},
			size = {
				{0, 0.6, 0},
				{0.12, 10, 2.5},
				{0.8, 10.5, 2.5},
				{1, 0, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.8, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.5,
			brightness = 1.7,
			cone_emit = {
				{1.023, 1, 0.98, -0.97, 0.3},
				{1.023, 1, 0.98, -0.821, 0.3},
				{1.023, 1, 0.98, -0.672, 0.3},
				{1.023, 1, 0.98, -0.522, 0.3},
				{1.023, 1, 0.98, -0.373, 0.3},
				{1.023, 1, 0.98, -0.224, 0.3},
				{1.023, 1, 0.98, -0.075, 0.3},
				{1.023, 1, 0.98, 0.075, 0.3},
				{1.023, 1, 0.98, 0.224, 0.3},
				{1.023, 1, 0.98, 0.373, 0.3},
				{1.023, 1, 0.98, 0.522, 0.3},
				{1.023, 1, 0.98, 0.672, 0.3},
				{1.023, 1, 0.98, 0.821, 0.3},
				{1.023, 1, 0.98, 0.97, 0.3},
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
			name = "CrashShards",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 50,
			spread = {35, 30},
			speed = {35, 70},
			drag = 0.5,
			accel = {0, -110, 0},
			lifetime = {0.6, 1},
			size = {
				{0, 1.8, 0.5},
				{1, 1.2, 0.4},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			cone_emit = {
				{1.023, 2, 0.98, -0.97, 1},
				{1.023, 2, 0.98, -0.794, 1},
				{1.023, 2, 0.98, -0.617, 1},
				{1.023, 2, 0.98, -0.441, 1},
				{1.023, 2, 0.98, -0.265, 1},
				{1.023, 2, 0.98, -0.088, 1},
				{1.023, 2, 0.98, 0.088, 1},
				{1.023, 2, 0.98, 0.265, 1},
				{1.023, 2, 0.98, 0.441, 1},
				{1.023, 2, 0.98, 0.617, 1},
				{1.023, 2, 0.98, 0.794, 1},
				{1.023, 2, 0.98, 0.97, 1},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
	},
	shakes = {
		{0.02, 0.6, 0.3},
		{0.17, 0.45, 1},
		{1.023, 0.5, 0.35},
	},
	light = {
		color = {170, 210, 255},
		brightness = 4,
		range = 40,
		time = 0.6,
	},
	cone = {
		length = 110,
		angle = 50,
		wave = {0.12, 1},
	},
	field = {
		wave = {0.12, 1, 1.5},
		groups = {
			{
				name = "IceBlocks",
				count = 34,
				u = {0.08, 0.55},
				s = {-0.92, 0.92},
				lean = "random",
				wid = {1, 2.2},
				thick = {1, 2.4},
				len = {1, 2.2},
				tilt = {5, 30},
				yaw = 0,
				pitch = 15,
				show = 0.75,
				rise = 0.09,
				hold = {1.3, 2},
				sink = 0.4,
				delay = {0, 0.07},
				big = {
					frac = 0.15,
					k = 1.8,
				},
				["end"] = "shatter",
				ice = {
					color = {150, 200, 255},
					material = "Ice",
					transparency = 0.15,
				},
				mesh = "IceBlocks",
				shatter = {
					{
						name = "IceBreak",
						texture = "mf_shard_2x2",
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
							size = {2.5, 2.5, 2.5},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {12, 30},
						drag = 0.5,
						accel = {0, -110, 0},
						lifetime = {0.4, 0.7},
						size = {
							{0, 1.2, 0.4},
							{1, 0.8, 0.3},
						},
						transparency = {
							{0, 0, 0},
							{0.85, 0.1, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{200, 230, 255},
							},
							{
								0.4,
								{120, 180, 255},
							},
							{
								1,
								{70, 120, 235},
							},
						},
						light_emission = 0.45,
						brightness = 1.4,
						rotation = {0, 360},
						rot_speed = {-500, 500},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "IceBreakGlint",
						texture = "kk_star_06",
						emit = {
							{0, 2},
						},
						shape = {
							type = "Box",
							size = {3, 3, 3},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {2, 6},
						drag = 2,
						lifetime = {0.3, 0.5},
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
								{225, 240, 255},
							},
							{
								1,
								{170, 205, 255},
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
						name = "IceBreakMist",
						texture = "fx_fog2001",
						emit = {
							{0, 1},
						},
						direction = "Top",
						spread = {60, 60},
						speed = {2, 5},
						drag = 2,
						accel = {0, 1, 0},
						lifetime = {0.6, 0.9},
						size = {
							{0, 3, 1},
							{1, 8, 2},
						},
						transparency = {
							{0, 0.6, 0},
							{0.4, 0.65, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{220, 236, 255},
							},
							{
								1,
								{175, 200, 240},
							},
						},
						light_emission = 0.15,
						rotation = {0, 360},
						zoffset = -1,
						brightness = 1,
						rot_speed = {0, 0},
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
				},
			},
			{
				name = "IceBlocks",
				count = 36,
				u = {0.55, 1},
				s = {-0.92, 0.92},
				lean = "random",
				wid = {1.5, 3.2},
				thick = {1.5, 3.4},
				len = {1.5, 3.2},
				tilt = {5, 30},
				yaw = 0,
				pitch = 15,
				show = 0.75,
				rise = 0.1,
				hold = {1.3, 2},
				sink = 0.4,
				delay = {0, 0.07},
				big = {
					frac = 0.2,
					k = 2,
				},
				["end"] = "shatter",
				ice = {
					color = {150, 200, 255},
					material = "Ice",
					transparency = 0.15,
				},
				mesh = "IceBlocks",
				shatter = {
					{
						name = "IceBreak",
						texture = "mf_shard_2x2",
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
							size = {2.5, 2.5, 2.5},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {12, 30},
						drag = 0.5,
						accel = {0, -110, 0},
						lifetime = {0.4, 0.7},
						size = {
							{0, 1.2, 0.4},
							{1, 0.8, 0.3},
						},
						transparency = {
							{0, 0, 0},
							{0.85, 0.1, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{200, 230, 255},
							},
							{
								0.4,
								{120, 180, 255},
							},
							{
								1,
								{70, 120, 235},
							},
						},
						light_emission = 0.45,
						brightness = 1.4,
						rotation = {0, 360},
						rot_speed = {-500, 500},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "IceBreakGlint",
						texture = "kk_star_06",
						emit = {
							{0, 2},
						},
						shape = {
							type = "Box",
							size = {3, 3, 3},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {2, 6},
						drag = 2,
						lifetime = {0.3, 0.5},
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
								{225, 240, 255},
							},
							{
								1,
								{170, 205, 255},
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
						name = "IceBreakMist",
						texture = "fx_fog2001",
						emit = {
							{0, 1},
						},
						direction = "Top",
						spread = {60, 60},
						speed = {2, 5},
						drag = 2,
						accel = {0, 1, 0},
						lifetime = {0.6, 0.9},
						size = {
							{0, 3, 1},
							{1, 8, 2},
						},
						transparency = {
							{0, 0.6, 0},
							{0.4, 0.65, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{220, 236, 255},
							},
							{
								1,
								{175, 200, 240},
							},
						},
						light_emission = 0.15,
						rotation = {0, 360},
						zoffset = -1,
						brightness = 1,
						rot_speed = {0, 0},
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
				},
			},
			{
				name = "WaveSlabs",
				count = 50,
				u = {0.06, 1},
				s = {-1, 1},
				lean = "radial",
				wid = {1.6, 3},
				thick = {0.5, 1},
				len = {1.4, 2.8},
				tilt = {15, 40},
				yaw = 14,
				pitch = 10,
				show = 0.62,
				rise = 0.07,
				hold = {1.4, 2},
				sink = 0.5,
				delay = {0, 0.05},
				ground = true,
				mesh = "WaveSlabs",
			},
		},
	},
	front = {
		wave = {0.12, 1, 1.5},
		count = 14,
		s_max = 0.95,
		emitters = {
			{
				name = "FogCore",
				texture = "fx_smoke_2x2",
				flipbook = {
					layout = "Grid2x2",
					mode = "Loop",
					fps = 0.001,
					startRandom = true,
				},
				direction = "Front",
				spread = {35, 12},
				speed = {60, 100},
				drag = 2.5,
				accel = {0, 1.5, 0},
				lifetime = {1.8, 2.8},
				size = {
					{0, 9, 2},
					{0.2, 15, 3},
					{0.6, 20, 3},
					{1, 23, 3},
				},
				transparency = {
					{0, 0.4, 0},
					{0.1, 0.25, 0},
					{0.35, 0.55, 0},
					{0.7, 0.75, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{195, 214, 242},
					},
					{
						0.5,
						{152, 176, 216},
					},
					{
						1,
						{128, 150, 196},
					},
				},
				rotation = {0, 360},
				rot_speed = {-30, 30},
				zoffset = -3,
				light_emission = 0,
				brightness = 1,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 18,
				up = 5,
				pitch = 0,
			},
			{
				name = "FogWall",
				texture = "fx_smoke_2x2",
				flipbook = {
					layout = "Grid2x2",
					mode = "Loop",
					fps = 0.001,
					startRandom = true,
				},
				direction = "Front",
				spread = {35, 18},
				speed = {55, 95},
				drag = 2.4,
				accel = {0, 2, 0},
				lifetime = {2, 3},
				size = {
					{0, 10, 2},
					{0.15, 18, 3},
					{0.6, 26, 4},
					{1, 32, 4},
				},
				transparency = {
					{0, 0.45, 0},
					{0.08, 0.3, 0},
					{0.3, 0.58, 0},
					{0.6, 0.76, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{238, 246, 255},
					},
					{
						0.35,
						{200, 222, 252},
					},
					{
						1,
						{160, 188, 236},
					},
				},
				light_emission = 0.12,
				rotation = {0, 360},
				rot_speed = {-40, 40},
				zoffset = -2,
				brightness = 1,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 16,
				up = 6,
				pitch = 0,
			},
			{
				name = "FogBillow",
				texture = "fx_smoke_2x2",
				flipbook = {
					layout = "Grid2x2",
					mode = "Loop",
					fps = 0.001,
					startRandom = true,
				},
				direction = "Front",
				spread = {30, 25},
				speed = {40, 80},
				drag = 2,
				accel = {0, 5, 0},
				lifetime = {1.6, 2.4},
				size = {
					{0, 11, 2},
					{0.3, 21, 3},
					{1, 32, 4},
				},
				transparency = {
					{0, 0.55, 0},
					{0.12, 0.38, 0},
					{0.4, 0.64, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{250, 252, 255},
					},
					{
						1,
						{200, 218, 245},
					},
				},
				light_emission = 0.18,
				rotation = {0, 360},
				rot_speed = {-45, 45},
				zoffset = -1,
				brightness = 1,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 10,
				up = 11,
				pitch = 0,
			},
			{
				name = "FogLow",
				texture = "fx_fog2001",
				direction = "Front",
				spread = {60, 6},
				speed = {30, 70},
				drag = 1.8,
				accel = {0, 0.3, 0},
				lifetime = {2.6, 3.6},
				size = {
					{0, 6, 1},
					{0.4, 12, 2},
					{1, 16, 2},
				},
				transparency = {
					{0, 0.5, 0},
					{0.12, 0.4, 0},
					{0.4, 0.66, 0},
					{0.8, 0.82, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{225, 238, 255},
					},
					{
						1,
						{182, 202, 236},
					},
				},
				light_emission = 0.12,
				rotation = {0, 360},
				rot_speed = {-20, 20},
				zoffset = -3,
				brightness = 1,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 18,
				up = 4,
				pitch = 0,
			},
			{
				name = "FrontEdge",
				texture = "fx_smoke_2x2",
				flipbook = {
					layout = "Grid2x2",
					mode = "Loop",
					fps = 0.001,
					startRandom = true,
				},
				direction = "Front",
				spread = {30, 10},
				speed = {150, 200},
				drag = 5,
				accel = {0, 3, 0},
				lifetime = {0.6, 1},
				size = {
					{0, 6, 1},
					{1, 14, 2},
				},
				transparency = {
					{0, 0.35, 0},
					{0.3, 0.5, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{245, 250, 255},
					},
					{
						1,
						{205, 222, 248},
					},
				},
				light_emission = 0.15,
				rotation = {0, 360},
				rot_speed = {-60, 60},
				brightness = 1,
				zoffset = 0,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 14,
				up = 1.5,
				pitch = 0,
			},
			{
				name = "FrontPowder",
				texture = "kk_smoke_04",
				direction = "Front",
				spread = {25, 30},
				speed = {110, 160},
				drag = 4,
				accel = {0, -10, 0},
				lifetime = {0.5, 0.9},
				size = {
					{0, 3, 1},
					{1, 10, 2},
				},
				transparency = {
					{0, 0.3, 0},
					{0.5, 0.5, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{240, 246, 255},
					},
					{
						1,
						{205, 218, 240},
					},
				},
				rotation = {0, 360},
				rot_speed = {-60, 60},
				light_emission = 0,
				brightness = 1,
				zoffset = 0,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 18,
				up = 3,
				pitch = 0,
			},
			{
				name = "FrontGlitter",
				texture = "fx_spark002",
				direction = "Front",
				spread = {40, 40},
				speed = {60, 120},
				drag = 3,
				accel = {0, -4, 0},
				lifetime = {0.6, 1.2},
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
						{225, 240, 255},
					},
					{
						1,
						{170, 205, 255},
					},
				},
				light_emission = 1,
				brightness = 1.8,
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
				rate = 12,
				up = 4,
				pitch = 0,
			},
			{
				name = "FrontIce",
				texture = "mf_shard_2x2",
				flipbook = {
					layout = "Grid2x2",
					mode = "Loop",
					fps = 0.001,
					startRandom = true,
				},
				direction = "Front",
				spread = {30, 20},
				speed = {50, 90},
				drag = 0.6,
				accel = {0, -110, 0},
				lifetime = {0.5, 0.9},
				size = {
					{0, 1.3, 0.4},
					{1, 0.8, 0.3},
				},
				transparency = {
					{0, 0, 0},
					{0.85, 0.1, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{200, 230, 255},
					},
					{
						0.4,
						{120, 180, 255},
					},
					{
						1,
						{70, 120, 235},
					},
				},
				light_emission = 0.45,
				brightness = 1.4,
				rotation = {0, 360},
				rot_speed = {-500, 500},
				zoffset = 0,
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 10,
				up = 2,
				pitch = 35,
			},
			{
				name = "FrontDust",
				texture = "kk_smoke_04",
				direction = "Front",
				spread = {40, 20},
				speed = {40, 80},
				drag = 3,
				accel = {0, 2, 0},
				lifetime = {0.8, 1.2},
				size = {
					{0, 5, 1},
					{1, 14, 3},
				},
				transparency = {
					{0, 0.45, 0},
					{0.4, 0.58, 0},
					{1, 1, 0},
				},
				color = {
					{
						0,
						{215, 228, 248},
					},
					{
						1,
						{175, 190, 222},
					},
				},
				rotation = {0, 360},
				zoffset = -2,
				light_emission = 0,
				brightness = 1,
				rot_speed = {0, 0},
				orientation = "FacingCamera",
				offset = {0, 0, 0},
				line_u = 0,
				emit = {},
				rate = 10,
				up = 1,
				pitch = 0,
			},
		},
	},
}

-- MOONFANG SKILL 2 (Ola de hielo): golpea el suelo y una ola densa de humo helado sale hacia adelante abriéndose en triángulo; sale con fuerza y se va frenando, y deja una estela espesa de humo. A su paso brotan bloques de hielo inclinados, saltan losas del suelo, salen rocas volando y el suelo queda escarchado. Llega al borde lejano a los 1.12 s; los bloques de hielo revientan al final.
-- length = largo del triángulo en studs (por defecto 110.0 × escala); angle = apertura en grados (por defecto 50.0).
function MoonfangVFX.IceWave(cf: CFrame, length: number?, angle: number?, scale: number?, shake: number?): Part
	return play(SPEC_IceWave, cf, scale, length or 110.0 * (scale or 1), shake, angle or 50.0)
end

local SPEC_FrostRoar = {
	name = "FrostRoar",
	duration = 1.7,
	cleanup = 2.43,
	layers = {
		{
			name = "GatherMotes",
			texture = "fx_particle02",
			shape = {
				type = "Sphere",
				radius = 12,
				style = "Surface",
				inout = "Inward",
			},
			speed = {32, 42},
			lifetime = {0.26, 0.28},
			size = {
				{0, 0, 0},
				{0.3, 0.9, 0},
				{1, 0.3, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			stream = {
				{0, 0.26, 110, 70},
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
			name = "GatherMist",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			shape = {
				type = "Sphere",
				radius = 9,
				style = "Surface",
				inout = "Inward",
			},
			speed = {22, 30},
			lifetime = {0.3, 0.32},
			size = {
				{0, 5, 1},
				{1, 1.5, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.4, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{238, 246, 255},
				},
				{
					0.35,
					{200, 222, 252},
				},
				{
					1,
					{160, 188, 236},
				},
			},
			light_emission = 0.3,
			rotation = {0, 360},
			stream = {
				{0, 0.24, 30, 20},
			},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			brightness = 1,
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
			lifetime = {0.28, 0.28},
			size = {
				{0, 2, 0},
				{1, 10, 0},
			},
			transparency = {
				{0, 0.85, 0},
				{1, 0.35, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			name = "MouthFlash",
			texture = "fx_glow",
			emit = {
				{0.28, 1},
			},
			lifetime = {0.22, 0.22},
			size = {
				{0, 6, 0},
				{0.3, 24, 0},
				{1, 26, 0},
			},
			transparency = {
				{0, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 1.2,
			zoffset = 3,
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
				{0.28, 1},
			},
			lifetime = {0.22, 0.22},
			rotation = {0, 90},
			size = {
				{0, 6, 0},
				{0.2, 30, 0},
				{1, 8, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 1.6,
			zoffset = 4,
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
			name = "RoarRings",
			texture = "kk_circle_02",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			speed = {58, 58},
			drag = 1.6,
			lifetime = {0.55, 0.55},
			size = {
				{0, 8, 0},
				{1, 62, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.5, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{235, 248, 255},
				},
				{
					0.5,
					{170, 215, 255},
				},
				{
					1,
					{110, 165, 255},
				},
			},
			light_emission = 0.9,
			brightness = 1.5,
			emit = {
				{0.28, 1},
				{0.365, 1},
				{0.45, 1},
				{0.535, 1},
				{0.62, 1},
				{0.705, 1},
				{0.79, 1},
			},
			spread = {0, 0},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "RoarRingsSharp",
			texture = "kz_beam_ring",
			orientation = "VelocityPerpendicular",
			direction = "Front",
			speed = {85, 85},
			drag = 1.2,
			lifetime = {0.4, 0.4},
			size = {
				{0, 6, 0},
				{1, 46, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 232, 255},
				},
				{
					1,
					{165, 195, 250},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			emit = {
				{0.31, 1},
				{0.48, 1},
				{0.65, 1},
				{0.82, 1},
			},
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
			spread = {38, 26},
			speed = {95, 155},
			drag = 3,
			lifetime = {0.18, 0.3},
			size = {
				{0, 10, 2},
				{1, 3, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 1.8,
			emit = {
				{0.28, 24},
				{0.4, 16},
				{0.54, 12},
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
		},
		{
			name = "FrostBreath",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			spread = {16, 12},
			speed = {55, 100},
			drag = 2.2,
			accel = {0, 3, 0},
			lifetime = {0.9, 1.3},
			size = {
				{0, 4, 1},
				{0.4, 14, 2},
				{1, 22, 3},
			},
			transparency = {
				{0, 0.3, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{238, 246, 255},
				},
				{
					0.35,
					{200, 222, 252},
				},
				{
					1,
					{160, 188, 236},
				},
			},
			light_emission = 0.3,
			rotation = {0, 360},
			rot_speed = {-40, 40},
			stream = {
				{0.28, 0.83, 70, 20},
			},
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "BreathShards",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			spread = {22, 16},
			speed = {70, 130},
			drag = 0.6,
			accel = {0, -60, 0},
			lifetime = {0.5, 0.8},
			size = {
				{0, 1.6, 0.4},
				{1, 1.1, 0.3},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			emit = {
				{0.28, 20},
				{0.43, 12},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
		},
		{
			name = "BreathGlitter",
			texture = "kk_star_06",
			direction = "Front",
			spread = {25, 20},
			speed = {40, 90},
			drag = 2.5,
			lifetime = {0.5, 0.9},
			size = {
				{0, 0, 0},
				{0.08, 2.56, 0},
				{0.22, 1.12, 0},
				{0.38, 2.72, 0},
				{0.55, 0.96, 0},
				{0.72, 2.24, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 2,
			rotation = {0, 45},
			stream = {
				{0.28, 0.88, 60, 10},
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
			name = "FloorRing",
			floor = true,
			offset = {0, 0, 9},
			texture = "kk_circle_02",
			emit = {
				{0.3, 1},
			},
			lifetime = {0.6, 0.6},
			size = {
				{0, 8, 0},
				{1, 95, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
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
			name = "FloorFrost",
			floor = true,
			offset = {0, 0, 9},
			texture = "mf_frost_patch",
			emit = {
				{0.33, 1},
			},
			lifetime = {1.4, 1.4},
			rotation = {0, 360},
			size = {
				{0, 8, 0},
				{0.15, 40, 0},
				{1, 42, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.1, 0.3, 0},
				{0.8, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 185, 255},
				},
				{
					0.15,
					{225, 242, 255},
				},
				{
					0.35,
					{130, 190, 255},
				},
				{
					1,
					{40, 80, 200},
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
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
		{
			name = "FloorCracks",
			floor = true,
			offset = {0, 0, 9},
			texture = "mf_frost_cracks",
			emit = {
				{0.32, 1},
			},
			lifetime = {1.3, 1.3},
			rotation = {0, 360},
			size = {
				{0, 6, 0},
				{0.12, 34, 0},
				{1, 36, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.25, 0},
				{0.8, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 185, 255},
				},
				{
					0.15,
					{225, 242, 255},
				},
				{
					0.35,
					{130, 190, 255},
				},
				{
					1,
					{40, 80, 200},
				},
			},
			light_emission = 0.85,
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
			name = "FloorMist",
			floor = true,
			offset = {0, 3.5, 9},
			ring = {18, 7},
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			direction = "Front",
			pitch = 8,
			spread = {8, 6},
			speed = {35, 60},
			drag = 2.5,
			accel = {0, 2, 0},
			lifetime = {1, 1.4},
			size = {
				{0, 6, 1},
				{1, 16, 2},
			},
			transparency = {
				{0, 0.4, 0},
				{0.35, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{238, 246, 255},
				},
				{
					0.35,
					{200, 222, 252},
				},
				{
					1,
					{160, 188, 236},
				},
			},
			light_emission = 0.2,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			emit = {
				{0.31, 1},
			},
			brightness = 1,
			zoffset = 0,
			orientation = "FacingCamera",
			line_u = 0,
		},
		{
			name = "FloorSpikes",
			floor = true,
			offset = {0, 0.5, 9},
			ring = {16, 15},
			texture = "mf_ice_spikes_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			orientation = "VelocityParallel",
			direction = "Front",
			pitch = 68,
			spread = {6, 6},
			speed = {10, 16},
			drag = 10,
			lifetime = {0.8, 1},
			size = {
				{0, 0.5, 0},
				{0.15, 6.5, 1},
				{0.8, 7, 1},
				{1, 0, 0},
			},
			transparency = {
				{0, 0.05, 0},
				{0.8, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			emit = {
				{0.36, 1},
			},
			accel = {0, 0, 0},
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			line_u = 0,
		},
	},
	shakes = {
		{0.28, 0.8, 0.7},
	},
	light = {
		color = {190, 225, 255},
		brightness = 5,
		range = 40,
		time = 0.9,
		delay = 0.28,
	},
}

-- MOONFANG SKILL 3 (Rugido helado): el frío se junta en el hocico y ruge: ondas de sonido heladas, líneas de grito y un chorro de vaho con esquirlas hacia adelante; en el suelo, una onda de escarcha y púas de hielo alrededor. cf = la cabeza, mirando hacia adelante (-Z). Ruge a los FrostRoarImpact s; la onda del suelo llega a FrostRoarRadius studs × escala (el empujón).
function MoonfangVFX.FrostRoar(cf: CFrame, scale: number?, shake: number?): Part
	return play(SPEC_FrostRoar, cf, scale, nil, shake)
end
-- segundo (desde la llamada) en que pega: para sincronizar el daño o el empujón
MoonfangVFX.FrostRoarImpact = 0.28
-- hasta dónde llega (studs a escala 1; multiplícalo por la escala): el radio del empujón
MoonfangVFX.FrostRoarRadius = 30

local SPEC_Eclipse = {
	name = "Eclipse",
	duration = 4.95,
	cleanup = 7.89,
	layers = {
		{
			name = "MoonHalo",
			texture = "fx_glow",
			lifetime = {4.75, 4.75},
			size = {
				{0, 156, 0},
				{0.06, 592.8, 0},
				{1, 624, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.45, 0},
				{0.2105, 0.5, 0},
				{0.2737, 0.75, 0},
				{0.7474, 0.75, 0},
				{0.7684, 0.35, 0},
				{0.85, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{110, 170, 255},
				},
				{
					0.5,
					{60, 115, 240},
				},
				{
					1,
					{30, 60, 190},
				},
			},
			brightness = 1.2,
			zoffset = 50,
			ring_emit = {
				{0, 1, 0, 0, 1},
			},
			bill = true,
			rel = "r",
			hu = "H",
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
			name = "CoronaRays",
			texture = "fx_halo",
			lifetime = {2.85, 2.85},
			rotation = {0, 360},
			rot_speed = {7, 10},
			size = {
				{0, 296.4, 0},
				{0.05, 411.84, 0},
				{1, 443.04, 0},
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
					{255, 255, 255},
				},
				{
					0.5,
					{220, 232, 255},
				},
				{
					1,
					{165, 195, 250},
				},
			},
			brightness = 1.3,
			zoffset = 55,
			ring_emit = {
				{1.22, 1, 0, 0, 1},
			},
			bill = true,
			rel = "r",
			hu = "H",
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "Moon",
			texture = "mf_moon_eclipse_4x4",
			flipbook = {
				layout = "Grid4x4",
				mode = "OneShot",
				fps = 0,
				startRandom = false,
			},
			flip_t = {
				{0, 0},
				{0.0632, 0},
				{0.2737, 15},
				{0.7453, 15},
				{0.7474, 0},
				{1, 0},
			},
			lifetime = {4.75, 4.75},
			size = {
				{0, 109.2, 0},
				{0.05, 327.6, 0},
				{0.09, 312, 0},
				{1, 312, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.04, 0, 0},
				{0.88, 0, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{235, 242, 255},
				},
			},
			brightness = 1.7,
			zoffset = 60,
			ring_emit = {
				{0, 1, 0, 0, 1},
			},
			bill = true,
			rel = "r",
			hu = "H",
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
			name = "Corona",
			texture = "kk_circle_02",
			lifetime = {2.25, 2.25},
			size = {
				{0, 592.8, 0},
				{0.04, 468, 0},
				{1, 483.6, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.9, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{220, 232, 255},
				},
				{
					1,
					{165, 195, 250},
				},
			},
			brightness = 2.6,
			zoffset = 62,
			ring_emit = {
				{1.3, 1, 0, 0, 1},
			},
			bill = true,
			rel = "r",
			hu = "H",
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
			name = "DiamondGlow",
			texture = "fx_glow",
			lifetime = {0.45, 0.45},
			size = {
				{0, 31.2, 0},
				{0.2, 156, 0},
				{1, 93.6, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{0.6, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			brightness = 2.4,
			zoffset = 64,
			ring_emit = {
				{1.24, 1, 0, 0, 1},
			},
			bill = true,
			rel = "r",
			hu = "H",
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
			slide_x = {
				{0, 90.48},
				{1, 90.48},
			},
			slide_y = {
				{0, 84.24},
				{1, 84.24},
			},
		},
		{
			name = "DiamondStar",
			texture = "kk_star_09",
			lifetime = {0.45, 0.45},
			rotation = {10, 20},
			size = {
				{0, 15.6, 0},
				{0.18, 343.2, 0},
				{1, 46.8, 0},
			},
			transparency = {
				{0, 0, 0},
				{1, 0.4, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			brightness = 3,
			zoffset = 65,
			ring_emit = {
				{1.24, 1, 0, 0, 1},
			},
			bill = true,
			rel = "r",
			hu = "H",
			speed = {0, 0},
			spread = {0, 0},
			direction = "Top",
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			rot_speed = {0, 0},
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
			slide_x = {
				{0, 90.48},
				{1, 90.48},
			},
			slide_y = {
				{0, 84.24},
				{1, 84.24},
			},
		},
		{
			name = "MoonReturn",
			texture = "fx_glow",
			lifetime = {0.6, 0.6},
			size = {
				{0, 280.8, 0},
				{0.2, 530.4, 0},
				{1, 592.8, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.4, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			brightness = 2.4,
			zoffset = 63,
			ring_emit = {
				{3.55, 1, 0, 0, 1},
			},
			bill = true,
			rel = "r",
			hu = "H",
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
			name = "DropHead",
			texture = "fx_glow",
			direction = "Bottom",
			speed_h = {8.2, 8.2},
			lifetime = {0.12, 0.12},
			size = {
				{0, 120, 0},
				{1, 180, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{1, 0.25, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			brightness = 2,
			ring_emit = {
				{1.3, 1, 0, 0, 1},
			},
			bill = true,
			rel = "r",
			hu = "H",
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "ZoneShade",
			texture = "fx_glow",
			rel = "r",
			lifetime = {4.85, 4.85},
			size = {
				{0, 48, 0},
				{0.1, 300, 0},
				{1, 312, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.08, 0.4, 0},
				{0.85, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{14, 18, 44},
				},
				{
					1,
					{22, 28, 62},
				},
			},
			ring_emit = {
				{0.05, 1, 0, 0, 0.1},
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
			name = "Sigil",
			texture = "mf_eclipse_sigil",
			rel = "r",
			lifetime = {3.6, 3.6},
			rotation = {0, 360},
			rot_speed = {6, 6},
			size = {
				{0, 313.1524, 0},
				{0.06, 250.5219, 0},
				{1, 250.5219, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.15, 0},
				{0.3, 0.05, 0},
				{0.97, 0.05, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{150, 205, 255},
				},
				{
					0.3,
					{215, 236, 255},
				},
				{
					1,
					{120, 175, 250},
				},
			},
			light_emission = 1,
			ring_emit = {
				{0.05, 1, 0, 0, 0.16},
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
			name = "SigilFlash",
			texture = "mf_eclipse_sigil",
			rel = "r",
			lifetime = {0.5, 0.5},
			rotation = {0, 360},
			size = {
				{0, 250.5219, 0},
				{1, 265.5532, 0},
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
					1,
					{235, 244, 255},
				},
			},
			light_emission = 1,
			ring_emit = {
				{1.42, 1, 0, 0, 0.2},
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
			name = "ZoneCracks",
			texture = "mf_frost_cracks",
			rel = "r",
			lifetime = {4.55, 4.55},
			rotation = {0, 360},
			size = {
				{0, 24, 0},
				{0.08, 132, 0},
				{1, 138, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.3, 0},
				{0.85, 0.35, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 185, 255},
				},
				{
					0.15,
					{225, 242, 255},
				},
				{
					0.35,
					{130, 190, 255},
				},
				{
					1,
					{40, 80, 200},
				},
			},
			light_emission = 0.85,
			ring_emit = {
				{0.15, 1, 0, 0, 0.18},
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
			name = "ZoneCracksOut",
			texture = "mf_frost_cracks",
			rel = "r",
			lifetime = {4.15, 4.15},
			rotation = {0, 360},
			size = {
				{0, 18, 0},
				{0.08, 90, 0},
				{1, 96, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.35, 0},
				{0.85, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{120, 185, 255},
				},
				{
					0.15,
					{225, 242, 255},
				},
				{
					0.35,
					{130, 190, 255},
				},
				{
					1,
					{40, 80, 200},
				},
			},
			light_emission = 0.85,
			ring_emit = {
				{0.364, 1, 0.1498, 0.525, 0.19},
				{0.645, 1, 0.1675, 0.835, 0.19},
				{0.692, 1, 0.2159, 0.886, 0.19},
				{0.492, 1, 0.2307, 0.666, 0.19},
				{0.573, 1, 0.3835, 0.755, 0.19},
				{0.691, 1, 0.4394, 0.885, 0.19},
				{0.649, 1, 0.5764, 0.839, 0.19},
				{0.617, 1, 0.6208, 0.804, 0.19},
				{0.668, 1, 0.6616, 0.86, 0.19},
				{0.585, 1, 0.6901, 0.768, 0.19},
				{0.646, 1, 0.7323, 0.836, 0.19},
				{0.297, 1, 0.7843, 0.452, 0.19},
				{0.277, 1, 0.8669, 0.43, 0.19},
				{0.37, 1, 0.9138, 0.532, 0.19},
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
			name = "FrostSheet",
			texture = "mf_frost_patch",
			rel = "r",
			lifetime = {3.53, 3.53},
			rotation = {0, 360},
			size = {
				{0, 36, 0},
				{0.06, 96, 0},
				{1, 102, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.05, 0.25, 0},
				{0.85, 0.3, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{150, 205, 255},
				},
				{
					0.3,
					{215, 236, 255},
				},
				{
					1,
					{120, 175, 250},
				},
			},
			light_emission = 0.5,
			ring_emit = {
				{1.42, 1, 0, 0, 0.2},
				{1.532, 1, 0.0657, 0.45, 0.2},
				{1.502, 1, 0.1349, 0.328, 0.2},
				{1.64, 1, 0.3014, 0.882, 0.2},
				{1.511, 1, 0.3178, 0.365, 0.2},
				{1.617, 1, 0.3219, 0.789, 0.2},
				{1.595, 1, 0.3948, 0.701, 0.2},
				{1.612, 1, 0.6082, 0.77, 0.2},
				{1.582, 1, 0.6633, 0.649, 0.2},
				{1.534, 1, 0.6677, 0.457, 0.2},
				{1.529, 1, 0.67, 0.438, 0.2},
				{1.59, 1, 0.7282, 0.68, 0.2},
				{1.585, 1, 0.7444, 0.66, 0.2},
				{1.602, 1, 0.8804, 0.727, 0.2},
				{1.542, 1, 0.8878, 0.488, 0.2},
				{1.529, 1, 0.9132, 0.437, 0.2},
				{1.621, 1, 0.98, 0.806, 0.2},
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
			name = "GroundGlow",
			texture = "fx_glow",
			rel = "r",
			lifetime = {0.55, 0.65},
			size = {
				{0, 240, 0},
				{1, 276, 0},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.45, 0},
				{0.7, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			ring_emit = {
				{1.42, 1, 0, 0, 0.25},
				{1.87, 1, 0, 0, 0.25},
				{2.32, 1, 0, 0, 0.25},
				{2.77, 1, 0, 0, 0.25},
				{3.22, 1, 0, 0, 0.25},
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
			name = "PulseRing",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.55, 0.55},
			size = {
				{0, 101.7, 0},
				{1, 427.14, 0},
			},
			transparency = {
				{0, 0.4, 0},
				{0.6, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 0.9,
			ring_emit = {
				{1.87, 1, 0, 0, 0.25},
				{2.32, 1, 0, 0, 0.25},
				{2.77, 1, 0, 0, 0.25},
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
			name = "ShockRing",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.6, 0.6},
			size = {
				{0, 406.8, 0},
				{1, 976.32, 0},
			},
			transparency = {
				{0, 0.15, 0},
				{0.5, 0.45, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 0.8,
			ring_emit = {
				{1.42, 1, 0, 0, 0.21},
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
			lifetime = {0.42, 0.42},
			size = {
				{0, 406.8, 0},
				{1, 1220.4, 0},
			},
			transparency = {
				{0, 0.05, 0},
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
					{220, 232, 255},
				},
				{
					1,
					{165, 195, 250},
				},
			},
			light_emission = 0.9,
			ring_emit = {
				{1.42, 1, 0, 0, 0.22},
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
			name = "DetRing",
			texture = "kk_circle_02",
			rel = "r",
			lifetime = {0.7, 0.7},
			size = {
				{0, 122.04, 0},
				{1, 1057.68, 0},
			},
			transparency = {
				{0, 0.1, 0},
				{0.5, 0.4, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 0.9,
			ring_emit = {
				{3.55, 1, 0, 0, 0.23},
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
			rel = "r",
			lifetime = {0.5, 0.5},
			size = {
				{0, 122.04, 0},
				{1, 1383.12, 0},
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
					{220, 232, 255},
				},
				{
					1,
					{165, 195, 250},
				},
			},
			light_emission = 1,
			ring_emit = {
				{3.55, 1, 0, 0, 0.24},
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
			name = "ChargeRise",
			texture = "kk_star_06",
			rel = "r",
			direction = "Top",
			speed = {14, 28},
			lifetime = {0.8, 1.2},
			size = {
				{0, 0, 0},
				{0.08, 5.44, 0},
				{0.22, 2.38, 0},
				{0.38, 5.78, 0},
				{0.55, 2.04, 0},
				{0.72, 4.76, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 2,
			rotation = {0, 45},
			ring_emit = {
				{0.05, 1, 0.0387, 0.875, 1.321},
				{0.067, 1, 0.9895, 0.767, 2.404},
				{0.087, 1, 0.9417, 0.907, 3.358},
				{0.089, 1, 0.7521, 0.914, 3.507},
				{0.09, 1, 0.4624, 0.789, 2.456},
				{0.092, 1, 0.8355, 0.796, 2.309},
				{0.122, 1, 0.5409, 0.637, 2.88},
				{0.13, 1, 0.567, 0.818, 1.949},
				{0.152, 1, 0.2687, 0.911, 4.208},
				{0.152, 1, 0.9331, 0.705, 3.222},
				{0.158, 1, 0.9035, 0.787, 4.692},
				{0.16, 1, 0.1602, 0.704, 3.095},
				{0.162, 1, 0.3154, 0.406, 4.371},
				{0.166, 1, 0.9949, 0.525, 4.382},
				{0.186, 1, 0.6779, 0.647, 3.066},
				{0.206, 1, 0.4455, 0.905, 4.763},
				{0.209, 1, 0.5407, 0.984, 1.087},
				{0.213, 1, 0.0176, 0.64, 4.81},
				{0.231, 1, 0.1054, 0.743, 1.609},
				{0.235, 1, 0.0074, 0.992, 2.405},
				{0.236, 1, 0.5308, 0.719, 3.621},
				{0.245, 1, 0.6098, 0.423, 2.957},
				{0.255, 1, 0.1806, 0.468, 1.124},
				{0.268, 1, 0.8118, 0.895, 4.287},
				{0.269, 1, 0.8592, 0.966, 4.229},
				{0.272, 1, 0.0322, 0.881, 4.918},
				{0.282, 1, 0.644, 0.872, 2.789},
				{0.302, 1, 0.3908, 0.906, 1.839},
				{0.303, 1, 0.3693, 0.21, 2.185},
				{0.312, 1, 0.4738, 0.969, 3.648},
				{0.313, 1, 0.5845, 0.946, 2.85},
				{0.324, 1, 0.8223, 0.665, 3.444},
				{0.337, 1, 0.4289, 0.712, 1.396},
				{0.348, 1, 0.6643, 0.644, 1.645},
				{0.35, 1, 0.9405, 0.515, 2.334},
				{0.357, 1, 0.4935, 0.385, 4.587},
				{0.358, 1, 0.8367, 0.667, 2.633},
				{0.363, 1, 0.2274, 0.584, 2.486},
				{0.365, 1, 0.0839, 0.738, 1.874},
				{0.366, 1, 0.5323, 0.698, 3.744},
				{0.375, 1, 0.3499, 0.965, 4.478},
				{0.377, 1, 0.9162, 0.583, 1.085},
				{0.381, 1, 0.6902, 0.837, 4.026},
				{0.386, 1, 0.2146, 0.265, 3.706},
				{0.388, 1, 0.6183, 0.659, 1.136},
				{0.395, 1, 0.1829, 0.479, 4.533},
				{0.395, 1, 0.6861, 0.984, 1.846},
				{0.402, 1, 0.8534, 0.817, 2.003},
				{0.429, 1, 0.6916, 0.768, 4.19},
				{0.435, 1, 0.8539, 0.952, 1.607},
				{0.441, 1, 0.1949, 0.951, 4.347},
				{0.461, 1, 0.6761, 0.401, 1.913},
				{0.465, 1, 0.8058, 0.983, 3.549},
				{0.483, 1, 0.2897, 0.485, 1.447},
				{0.489, 1, 0.173, 0.612, 4.456},
				{0.49, 1, 0.9219, 0.773, 3.727},
				{0.515, 1, 0.085, 0.868, 4.18},
				{0.523, 1, 0.4608, 0.348, 1.851},
				{0.533, 1, 0.1482, 0.592, 4.055},
				{0.546, 1, 0.8369, 0.543, 2.734},
				{0.548, 1, 0.8924, 0.982, 3.848},
				{0.548, 1, 0.9267, 0.506, 2.467},
				{0.55, 1, 0.8363, 0.952, 2.103},
				{0.552, 1, 0.9524, 0.152, 1.312},
				{0.556, 1, 0.7528, 0.557, 3.178},
				{0.563, 1, 0.4101, 0.561, 2.731},
				{0.569, 1, 0.5607, 0.799, 1.008},
				{0.57, 1, 0.4796, 0.716, 2.4},
				{0.576, 1, 0.5663, 0.422, 1.352},
				{0.576, 1, 0.6708, 0.688, 4.753},
				{0.606, 1, 0.0372, 0.491, 1.005},
				{0.609, 1, 0.2383, 0.669, 4.079},
				{0.609, 1, 0.4751, 0.318, 2.159},
				{0.615, 1, 0.9261, 0.801, 4.482},
				{0.623, 1, 0.0765, 0.72, 4.428},
				{0.636, 1, 0.3924, 0.913, 3.757},
				{0.64, 1, 0.8866, 0.949, 3.12},
				{0.643, 1, 0.4952, 0.433, 1.288},
				{0.665, 1, 0.5343, 0.995, 2.583},
				{0.672, 1, 0.8937, 0.745, 4.883},
				{0.675, 1, 0.233, 0.494, 3.377},
				{0.681, 1, 0.068, 0.976, 2.928},
				{0.689, 1, 0.2892, 0.723, 3.749},
				{0.691, 1, 0.177, 0.8, 3.599},
				{0.722, 1, 0.4705, 0.93, 2.54},
				{0.743, 1, 0.5475, 0.832, 2.602},
				{0.764, 1, 0.4334, 0.276, 1.098},
				{0.768, 1, 0.3799, 0.938, 4.559},
				{0.772, 1, 0.2804, 0.337, 1.442},
				{0.773, 1, 0.5862, 0.839, 3.967},
				{0.776, 1, 0.1538, 0.975, 2.384},
				{0.783, 1, 0.4896, 0.728, 3.758},
				{0.791, 1, 0.594, 0.82, 4.698},
				{0.795, 1, 0.5212, 0.691, 4.987},
				{0.8, 1, 0.9779, 0.708, 3.882},
				{0.815, 1, 0.0097, 0.923, 2.087},
				{0.833, 1, 0.6696, 0.332, 1.528},
				{0.843, 1, 0.0823, 0.855, 2.829},
				{0.854, 1, 0.5221, 0.87, 2.147},
				{0.855, 1, 0.1318, 0.332, 1.264},
				{0.86, 1, 0.9291, 0.136, 1.935},
				{0.86, 1, 0.9865, 0.885, 1.363},
				{0.876, 1, 0.8891, 0.339, 1.511},
				{0.887, 1, 0.6618, 0.238, 4.2},
				{0.889, 1, 0.8081, 0.997, 1.961},
				{0.9, 1, 0.45, 0.857, 2.642},
				{0.906, 1, 0.7123, 0.784, 1.738},
				{0.911, 1, 0.3237, 0.513, 3.939},
				{0.915, 1, 0.246, 0.526, 4.616},
				{0.921, 1, 0.2249, 0.596, 3.035},
				{0.931, 1, 0.2994, 0.825, 2.691},
				{0.935, 1, 0.7599, 0.848, 1.107},
				{0.94, 1, 0.6379, 0.112, 3.895},
				{0.942, 1, 0.3887, 0.665, 1.425},
				{0.951, 1, 0.1806, 0.755, 1.759},
				{0.959, 1, 0.1862, 0.876, 2.543},
				{0.96, 1, 0.0933, 0.371, 3.804},
				{0.982, 1, 0.2073, 0.658, 1.043},
				{0.984, 1, 0.4576, 0.974, 1.745},
				{0.987, 1, 0.4184, 0.811, 3.436},
				{0.992, 1, 0.1933, 0.902, 3.09},
				{0.993, 1, 0.8533, 0.698, 4.211},
				{0.995, 1, 0.8223, 0.628, 4.059},
				{0.995, 1, 0.8556, 0.956, 3.189},
				{1, 1, 0.148, 0.697, 1.361},
				{1.019, 1, 0.9515, 0.555, 3.999},
				{1.025, 1, 0.1682, 0.922, 2.383},
				{1.026, 1, 0.291, 0.721, 3.416},
				{1.03, 1, 0.5098, 0.854, 1.287},
				{1.035, 1, 0.7085, 0.856, 3.109},
				{1.051, 1, 0.1746, 0.888, 4.822},
				{1.054, 1, 0.0299, 0.885, 4.03},
				{1.054, 1, 0.3666, 0.448, 2.29},
				{1.063, 1, 0.4585, 0.637, 3.825},
				{1.077, 1, 0.9247, 0.703, 2.117},
				{1.079, 1, 0.0239, 0.182, 2.084},
				{1.08, 1, 0.1771, 0.797, 4.148},
				{1.082, 1, 0.8258, 0.97, 1.217},
				{1.087, 1, 0.2794, 0.784, 4.476},
				{1.091, 1, 0.9625, 0.84, 3.631},
				{1.094, 1, 0.6697, 0.27, 4.999},
				{1.121, 1, 0.9817, 0.981, 3.488},
				{1.128, 1, 0.7514, 0.214, 4.498},
				{1.134, 1, 0.8728, 0.421, 1.887},
				{1.135, 1, 0.0228, 0.52, 2.174},
				{1.143, 1, 0.9279, 0.361, 3.291},
				{1.147, 1, 0.7967, 0.886, 4.346},
				{1.156, 1, 0.732, 0.62, 4.004},
				{1.157, 1, 0.3349, 0.777, 3.898},
				{1.17, 1, 0.689, 0.945, 4.219},
				{1.171, 1, 0.6809, 0.555, 1.741},
				{1.172, 1, 0.9246, 0.531, 2.303},
				{1.175, 1, 0.7489, 0.72, 3.109},
				{1.193, 1, 0.2754, 0.947, 4.855},
				{1.204, 1, 0.763, 0.542, 3.949},
				{1.23, 1, 0.655, 0.647, 2.801},
				{1.233, 1, 0.9206, 0.928, 4.267},
				{1.234, 1, 0.4521, 0.15, 3.271},
				{1.237, 1, 0.299, 0.607, 1.583},
				{1.237, 1, 0.53, 0.872, 2.343},
				{1.241, 1, 0.6263, 0.292, 4.634},
				{1.244, 1, 0.8985, 0.612, 4.677},
				{1.248, 1, 0.7698, 0.902, 4.888},
				{1.252, 1, 0.4374, 0.922, 1.967},
				{1.254, 1, 0.2236, 0.538, 1.055},
				{1.267, 1, 0.6919, 0.95, 4.514},
				{1.281, 1, 0.2702, 0.435, 2.078},
				{1.282, 1, 0.1574, 0.971, 4.061},
				{1.283, 1, 0.9087, 0.469, 3.302},
				{1.297, 1, 0.713, 0.352, 3.395},
			},
			spread = {0, 0},
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
			name = "ChargeIce",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			direction = "Top",
			spread = {15, 15},
			speed = {8, 16},
			drag = 0.6,
			accel = {0, 6, 0},
			lifetime = {1, 1.4},
			size = {
				{0, 0.5, 0},
				{0.15, 2.2, 0.6},
				{0.85, 2.2, 0.6},
				{1, 0, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.5,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-120, 120},
			ring_emit = {
				{0.12, 1, 0.7354, 0.727, 1.843},
				{0.125, 1, 0.3929, 0.854, 1.913},
				{0.144, 1, 0.3555, 0.581, 1.804},
				{0.157, 1, 0.7781, 0.389, 1.423},
				{0.168, 1, 0.3887, 0.925, 1.67},
				{0.185, 1, 0.3803, 0.613, 1.108},
				{0.196, 1, 0.2732, 0.935, 1.422},
				{0.203, 1, 0.342, 0.938, 1.743},
				{0.213, 1, 0.0365, 0.668, 1.975},
				{0.228, 1, 0.9982, 0.834, 1.184},
				{0.241, 1, 0.3125, 0.686, 1.612},
				{0.246, 1, 0.4504, 0.818, 1.285},
				{0.253, 1, 0.3782, 0.862, 1.442},
				{0.254, 1, 0.086, 0.839, 1.484},
				{0.272, 1, 0.6121, 0.554, 0.844},
				{0.315, 1, 0.6218, 0.483, 1.627},
				{0.318, 1, 0.9011, 0.659, 0.682},
				{0.325, 1, 0.8142, 0.693, 1.727},
				{0.332, 1, 0.4153, 0.839, 1.239},
				{0.338, 1, 0.6166, 0.629, 0.832},
				{0.354, 1, 0.514, 0.488, 0.627},
				{0.363, 1, 0.9436, 0.622, 1.885},
				{0.365, 1, 0.9283, 0.138, 1.947},
				{0.371, 1, 0.2042, 0.846, 1.048},
				{0.374, 1, 0.1154, 0.304, 1.374},
				{0.378, 1, 0.3271, 0.997, 1.4},
				{0.404, 1, 0.8172, 0.618, 1.954},
				{0.418, 1, 0.4083, 0.94, 0.981},
				{0.44, 1, 0.1845, 0.545, 1.913},
				{0.445, 1, 0.5254, 0.974, 0.968},
				{0.45, 1, 0.8486, 0.84, 1.039},
				{0.451, 1, 0.7859, 0.771, 0.654},
				{0.455, 1, 0.7502, 0.527, 0.943},
				{0.468, 1, 0.607, 0.409, 0.856},
				{0.48, 1, 0.5051, 0.685, 0.875},
				{0.495, 1, 0.3537, 0.47, 1.578},
				{0.496, 1, 0.8209, 0.561, 1.205},
				{0.507, 1, 0.4272, 0.556, 0.808},
				{0.508, 1, 0.1312, 0.332, 0.552},
				{0.524, 1, 0.9879, 0.556, 1.175},
				{0.536, 1, 0.3043, 0.644, 0.828},
				{0.551, 1, 0.4608, 0.275, 1.246},
				{0.553, 1, 0.4854, 0.289, 0.723},
				{0.56, 1, 0.8511, 0.559, 1.412},
				{0.578, 1, 0.8533, 0.643, 1.984},
				{0.579, 1, 0.3927, 0.359, 1.809},
				{0.589, 1, 0.779, 0.563, 1.982},
				{0.596, 1, 0.7376, 0.709, 1.435},
				{0.598, 1, 0.7507, 0.866, 1.823},
				{0.602, 1, 0.2522, 0.659, 0.725},
				{0.604, 1, 0.3694, 0.769, 0.971},
				{0.628, 1, 0.5582, 0.96, 1.709},
				{0.629, 1, 0.3396, 0.886, 1.935},
				{0.631, 1, 0.0631, 0.938, 0.944},
				{0.635, 1, 0.6157, 0.242, 1.302},
				{0.64, 1, 0.58, 0.592, 1.282},
				{0.645, 1, 0.5302, 0.365, 0.505},
				{0.651, 1, 0.4595, 0.97, 0.775},
				{0.654, 1, 0.8091, 0.765, 1.188},
				{0.658, 1, 0.6489, 0.981, 1.163},
				{0.66, 1, 0.0416, 0.973, 0.777},
				{0.661, 1, 0.9185, 0.56, 1.347},
				{0.667, 1, 0.7314, 0.652, 1.928},
				{0.687, 1, 0.0439, 0.359, 1.01},
				{0.692, 1, 0.3874, 0.671, 0.906},
				{0.697, 1, 0.056, 0.526, 1.689},
				{0.716, 1, 0.2997, 0.703, 1.762},
				{0.733, 1, 0.2008, 0.613, 1.176},
				{0.762, 1, 0.5684, 0.48, 1.07},
				{0.764, 1, 0.445, 0.665, 0.663},
				{0.769, 1, 0.561, 0.903, 0.976},
				{0.77, 1, 0.8565, 0.438, 1.342},
				{0.786, 1, 0.6753, 0.922, 1.173},
				{0.791, 1, 0.5453, 0.317, 0.579},
				{0.799, 1, 0.4782, 0.678, 1.766},
				{0.803, 1, 0.8236, 0.778, 1.533},
				{0.814, 1, 0.0201, 0.906, 1.476},
				{0.82, 1, 0.2054, 0.893, 1.124},
				{0.822, 1, 0.4437, 0.464, 1.796},
				{0.827, 1, 0.0572, 0.552, 1.735},
				{0.877, 1, 0.9857, 0.972, 1.788},
				{0.882, 1, 0.4827, 0.62, 1.221},
				{0.901, 1, 0.9465, 0.489, 0.605},
				{0.902, 1, 0.3859, 0.609, 0.508},
				{0.903, 1, 0.0422, 0.967, 0.87},
				{0.911, 1, 0.894, 0.426, 1.57},
				{0.914, 1, 0.1785, 0.246, 0.657},
				{0.918, 1, 0.1497, 0.689, 1.392},
				{0.934, 1, 0.7578, 0.856, 1.283},
				{0.945, 1, 0.1624, 0.834, 1.307},
				{0.949, 1, 0.5121, 0.49, 0.531},
				{0.953, 1, 0.7539, 0.659, 0.611},
				{0.964, 1, 0.5321, 0.581, 1.466},
				{0.991, 1, 0.9199, 0.689, 0.545},
				{1.01, 1, 0.4515, 0.527, 1.02},
				{1.018, 1, 0.9374, 0.933, 1.881},
				{1.047, 1, 0.6541, 0.629, 0.727},
				{1.057, 1, 0.913, 0.748, 1.664},
				{1.062, 1, 0.1085, 0.778, 0.952},
				{1.065, 1, 0.3414, 0.814, 0.69},
				{1.07, 1, 0.3138, 0.812, 1.423},
				{1.08, 1, 0.4888, 0.435, 1.201},
				{1.082, 1, 0.2856, 0.769, 0.903},
				{1.086, 1, 0.8761, 0.85, 0.597},
				{1.092, 1, 0.7361, 0.62, 1.839},
				{1.099, 1, 0.2328, 0.467, 1.171},
				{1.108, 1, 0.338, 0.98, 1.431},
				{1.128, 1, 0.6435, 0.918, 1.765},
				{1.131, 1, 0.726, 0.953, 0.603},
				{1.137, 1, 0.211, 0.973, 1.498},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "InflowMist",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			direction = "Back",
			spread = {14, 6},
			speed = {26, 46},
			drag = 1.2,
			lifetime = {1.5, 2},
			size = {
				{0, 18, 3},
				{1, 40, 5},
			},
			transparency = {
				{0, 1, 0},
				{0.25, 0.55, 0},
				{0.75, 0.68, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{238, 246, 255},
				},
				{
					0.35,
					{200, 222, 252},
				},
				{
					1,
					{160, 188, 236},
				},
			},
			light_emission = 0.15,
			rotation = {0, 360},
			rot_speed = {-25, 25},
			zoffset = -3,
			ring_emit = {
				{0.1, 1, 0, 1.06, 14},
				{0.1, 1, 0.0385, 1.06, 14},
				{0.1, 1, 0.0769, 1.06, 14},
				{0.1, 1, 0.1154, 1.06, 14},
				{0.1, 1, 0.1538, 1.06, 14},
				{0.1, 1, 0.1923, 1.06, 14},
				{0.1, 1, 0.2308, 1.06, 14},
				{0.1, 1, 0.2692, 1.06, 14},
				{0.1, 1, 0.3077, 1.06, 14},
				{0.1, 1, 0.3462, 1.06, 14},
				{0.1, 1, 0.3846, 1.06, 14},
				{0.1, 1, 0.4231, 1.06, 14},
				{0.1, 1, 0.4615, 1.06, 14},
				{0.1, 1, 0.5, 1.06, 14},
				{0.1, 1, 0.5385, 1.06, 14},
				{0.1, 1, 0.5769, 1.06, 14},
				{0.1, 1, 0.6154, 1.06, 14},
				{0.1, 1, 0.6538, 1.06, 14},
				{0.1, 1, 0.6923, 1.06, 14},
				{0.1, 1, 0.7308, 1.06, 14},
				{0.1, 1, 0.7692, 1.06, 14},
				{0.1, 1, 0.8077, 1.06, 14},
				{0.1, 1, 0.8462, 1.06, 14},
				{0.1, 1, 0.8846, 1.06, 14},
				{0.1, 1, 0.9231, 1.06, 14},
				{0.1, 1, 0.9615, 1.06, 14},
				{0.45, 1, 0.0192, 1.06, 14},
				{0.45, 1, 0.0577, 1.06, 14},
				{0.45, 1, 0.0962, 1.06, 14},
				{0.45, 1, 0.1346, 1.06, 14},
				{0.45, 1, 0.1731, 1.06, 14},
				{0.45, 1, 0.2115, 1.06, 14},
				{0.45, 1, 0.25, 1.06, 14},
				{0.45, 1, 0.2885, 1.06, 14},
				{0.45, 1, 0.3269, 1.06, 14},
				{0.45, 1, 0.3654, 1.06, 14},
				{0.45, 1, 0.4038, 1.06, 14},
				{0.45, 1, 0.4423, 1.06, 14},
				{0.45, 1, 0.4808, 1.06, 14},
				{0.45, 1, 0.5192, 1.06, 14},
				{0.45, 1, 0.5577, 1.06, 14},
				{0.45, 1, 0.5962, 1.06, 14},
				{0.45, 1, 0.6346, 1.06, 14},
				{0.45, 1, 0.6731, 1.06, 14},
				{0.45, 1, 0.7115, 1.06, 14},
				{0.45, 1, 0.75, 1.06, 14},
				{0.45, 1, 0.7885, 1.06, 14},
				{0.45, 1, 0.8269, 1.06, 14},
				{0.45, 1, 0.8654, 1.06, 14},
				{0.45, 1, 0.9038, 1.06, 14},
				{0.45, 1, 0.9423, 1.06, 14},
				{0.45, 1, 0.9808, 1.06, 14},
				{0.8, 1, 0, 1.06, 14},
				{0.8, 1, 0.0385, 1.06, 14},
				{0.8, 1, 0.0769, 1.06, 14},
				{0.8, 1, 0.1154, 1.06, 14},
				{0.8, 1, 0.1538, 1.06, 14},
				{0.8, 1, 0.1923, 1.06, 14},
				{0.8, 1, 0.2308, 1.06, 14},
				{0.8, 1, 0.2692, 1.06, 14},
				{0.8, 1, 0.3077, 1.06, 14},
				{0.8, 1, 0.3462, 1.06, 14},
				{0.8, 1, 0.3846, 1.06, 14},
				{0.8, 1, 0.4231, 1.06, 14},
				{0.8, 1, 0.4615, 1.06, 14},
				{0.8, 1, 0.5, 1.06, 14},
				{0.8, 1, 0.5385, 1.06, 14},
				{0.8, 1, 0.5769, 1.06, 14},
				{0.8, 1, 0.6154, 1.06, 14},
				{0.8, 1, 0.6538, 1.06, 14},
				{0.8, 1, 0.6923, 1.06, 14},
				{0.8, 1, 0.7308, 1.06, 14},
				{0.8, 1, 0.7692, 1.06, 14},
				{0.8, 1, 0.8077, 1.06, 14},
				{0.8, 1, 0.8462, 1.06, 14},
				{0.8, 1, 0.8846, 1.06, 14},
				{0.8, 1, 0.9231, 1.06, 14},
				{0.8, 1, 0.9615, 1.06, 14},
			},
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "FallingStreaks",
			texture = "kk_trace_01",
			rel = "r",
			hu = "H",
			orientation = "VelocityParallel",
			direction = "Bottom",
			speed_h = {0.9, 1.4},
			lifetime = {0.25, 0.4},
			size = {
				{0, 14, 0},
				{0.3, 55, 0},
				{1, 30, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			light_emission = 1,
			brightness = 1.4,
			zstream = {
				{1.37, 1.52, 80, 200},
				{1.52, 3.15, 200, 200},
				{3.15, 3.3, 200, 0},
			},
			zdist = {
				r = {0.05, 1},
				h = {0.2, 0.62},
				area = true,
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
			name = "FallingStars",
			texture = "fx_spark002",
			rel = "r",
			hu = "H",
			direction = "Bottom",
			speed_h = {0.2, 0.32},
			lifetime = {0.8, 1.2},
			size = {
				{0, 0, 0},
				{0.08, 7.04, 0},
				{0.22, 3.08, 0},
				{0.38, 7.48, 0},
				{0.55, 2.64, 0},
				{0.72, 6.16, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 2,
			rotation = {0, 45},
			zstream = {
				{1.37, 1.52, 64, 160},
				{1.52, 3.15, 160, 160},
				{3.15, 3.3, 160, 0},
			},
			zdist = {
				r = {0, 1.05},
				h = {0.1, 0.62},
				area = true,
			},
			speed = {0, 0},
			spread = {0, 0},
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
			name = "BaseMist",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			direction = "Front",
			spread = {30, 10},
			speed = {6, 16},
			drag = 0.8,
			accel = {0, 2, 0},
			lifetime = {1.4, 2},
			size = {
				{0, 30, 4},
				{1, 55, 6},
			},
			transparency = {
				{0, 1, 0},
				{0.25, 0.6, 0},
				{0.8, 0.74, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{238, 246, 255},
				},
				{
					0.35,
					{200, 222, 252},
				},
				{
					1,
					{160, 188, 236},
				},
			},
			light_emission = 0.2,
			rotation = {0, 360},
			rot_speed = {-20, 20},
			zoffset = -5,
			zstream = {
				{1.37, 1.52, 14.4, 36},
				{1.52, 3.15, 36, 36},
				{3.15, 3.3, 36, 0},
			},
			zdist = {
				r = {0.55, 1.12},
				h = {18, 26},
				area = false,
			},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "GroundSpikes",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			orientation = "VelocityParallel",
			direction = "Top",
			spread = {18, 18},
			speed = {22, 34},
			drag = 12,
			lifetime = {1.3, 1.6},
			size = {
				{0, 0.5, 0},
				{0.12, 11, 3},
				{0.85, 11.5, 3},
				{1, 0, 0},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.5,
			brightness = 1.5,
			ring_emit = {
				{1.57, 1, 0.0425, 0.597, 0.5},
				{1.618, 1, 0.0819, 0.706, 0.5},
				{1.619, 1, 0.0873, 0.679, 0.5},
				{1.589, 1, 0.0894, 0.576, 0.5},
				{1.583, 1, 0.0958, 0.559, 0.5},
				{1.631, 1, 0.1008, 0.763, 0.5},
				{1.622, 1, 0.1058, 0.788, 0.5},
				{1.491, 1, 0.1217, 0.262, 0.5},
				{1.594, 1, 0.1249, 0.596, 0.5},
				{1.644, 1, 0.1273, 0.804, 0.5},
				{1.486, 1, 0.138, 0.196, 0.5},
				{1.476, 1, 0.1409, 0.188, 0.5},
				{1.672, 1, 0.1588, 0.933, 0.5},
				{1.663, 1, 0.1598, 0.86, 0.5},
				{1.65, 1, 0.1617, 0.906, 0.5},
				{1.636, 1, 0.1629, 0.829, 0.5},
				{1.625, 1, 0.1848, 0.752, 0.5},
				{1.662, 1, 0.1926, 0.936, 0.5},
				{1.642, 1, 0.2144, 0.799, 0.5},
				{1.669, 1, 0.2215, 0.972, 0.5},
				{1.518, 1, 0.222, 0.375, 0.5},
				{1.576, 1, 0.223, 0.599, 0.5},
				{1.468, 1, 0.2318, 0.189, 0.5},
				{1.681, 1, 0.2337, 0.995, 0.5},
				{1.496, 1, 0.254, 0.241, 0.5},
				{1.503, 1, 0.2555, 0.216, 0.5},
				{1.624, 1, 0.2571, 0.759, 0.5},
				{1.649, 1, 0.2643, 0.808, 0.5},
				{1.649, 1, 0.2682, 0.905, 0.5},
				{1.624, 1, 0.2785, 0.771, 0.5},
				{1.557, 1, 0.2825, 0.438, 0.5},
				{1.553, 1, 0.283, 0.495, 0.5},
				{1.644, 1, 0.2887, 0.893, 0.5},
				{1.626, 1, 0.2926, 0.815, 0.5},
				{1.69, 1, 0.3026, 0.998, 0.5},
				{1.547, 1, 0.3286, 0.428, 0.5},
				{1.684, 1, 0.3428, 0.981, 0.5},
				{1.604, 1, 0.3488, 0.637, 0.5},
				{1.608, 1, 0.3512, 0.651, 0.5},
				{1.608, 1, 0.3678, 0.649, 0.5},
				{1.666, 1, 0.372, 0.894, 0.5},
				{1.52, 1, 0.3741, 0.366, 0.5},
				{1.651, 1, 0.3927, 0.869, 0.5},
				{1.672, 1, 0.4028, 0.929, 0.5},
				{1.536, 1, 0.4233, 0.409, 0.5},
				{1.636, 1, 0.4355, 0.855, 0.5},
				{1.663, 1, 0.4639, 0.932, 0.5},
				{1.624, 1, 0.4697, 0.767, 0.5},
				{1.587, 1, 0.4766, 0.631, 0.5},
				{1.672, 1, 0.4995, 0.998, 0.5},
				{1.618, 1, 0.5007, 0.723, 0.5},
				{1.626, 1, 0.501, 0.796, 0.5},
				{1.636, 1, 0.517, 0.788, 0.5},
				{1.678, 1, 0.5224, 0.992, 0.5},
				{1.591, 1, 0.5389, 0.605, 0.5},
				{1.502, 1, 0.5438, 0.228, 0.5},
				{1.646, 1, 0.5531, 0.841, 0.5},
				{1.617, 1, 0.5641, 0.75, 0.5},
				{1.682, 1, 0.5803, 0.969, 0.5},
				{1.55, 1, 0.5823, 0.485, 0.5},
				{1.607, 1, 0.6046, 0.658, 0.5},
				{1.576, 1, 0.6289, 0.508, 0.5},
				{1.557, 1, 0.6317, 0.448, 0.5},
				{1.613, 1, 0.6352, 0.704, 0.5},
				{1.549, 1, 0.6453, 0.405, 0.5},
				{1.578, 1, 0.6461, 0.567, 0.5},
				{1.637, 1, 0.652, 0.789, 0.5},
				{1.608, 1, 0.6588, 0.749, 0.5},
				{1.577, 1, 0.6674, 0.583, 0.5},
				{1.596, 1, 0.6884, 0.666, 0.5},
				{1.548, 1, 0.69, 0.507, 0.5},
				{1.651, 1, 0.6977, 0.919, 0.5},
				{1.664, 1, 0.7042, 0.905, 0.5},
				{1.584, 1, 0.725, 0.634, 0.5},
				{1.672, 1, 0.7912, 0.958, 0.5},
				{1.674, 1, 0.8142, 0.909, 0.5},
				{1.637, 1, 0.8196, 0.859, 0.5},
				{1.563, 1, 0.8243, 0.536, 0.5},
				{1.641, 1, 0.8359, 0.812, 0.5},
				{1.522, 1, 0.8519, 0.322, 0.5},
				{1.56, 1, 0.8547, 0.514, 0.5},
				{1.474, 1, 0.8683, 0.21, 0.5},
				{1.614, 1, 0.8713, 0.713, 0.5},
				{1.664, 1, 0.8801, 0.968, 0.5},
				{1.513, 1, 0.8905, 0.342, 0.5},
				{1.573, 1, 0.9609, 0.542, 0.5},
				{1.538, 1, 0.9616, 0.455, 0.5},
				{1.542, 1, 0.9772, 0.481, 0.5},
				{1.564, 1, 0.9835, 0.463, 0.5},
				{1.586, 1, 0.9866, 0.654, 0.5},
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
			name = "ImpactFlash",
			texture = "fx_glow",
			lifetime = {0.28, 0.28},
			size = {
				{0, 30, 0},
				{0.2, 288, 0},
				{1, 312, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.3, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			brightness = 2,
			zoffset = 4,
			ring_emit = {
				{1.42, 1, 0, 0, 30},
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
			name = "ImpactStar",
			texture = "kk_star_09",
			lifetime = {0.35, 0.35},
			rotation = {0, 90},
			size = {
				{0, 40, 0},
				{0.15, 384, 0},
				{1, 40, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			brightness = 2.5,
			zoffset = 5,
			ring_emit = {
				{1.42, 1, 0, 0, 30},
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
			name = "DustRing",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			direction = "Front",
			spread = {10, 6},
			speed = {60, 110},
			drag = 2.2,
			accel = {0, 3, 0},
			lifetime = {1.4, 2},
			size = {
				{0, 20, 3},
				{1, 52, 6},
			},
			transparency = {
				{0, 0.35, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{238, 246, 255},
				},
				{
					0.35,
					{200, 222, 252},
				},
				{
					1,
					{160, 188, 236},
				},
			},
			light_emission = 0.15,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			ring_emit = {
				{1.48, 1, 0, 0.98, 17},
				{1.48, 1, 0.025, 0.98, 17},
				{1.48, 1, 0.05, 0.98, 17},
				{1.48, 1, 0.075, 0.98, 17},
				{1.48, 1, 0.1, 0.98, 17},
				{1.48, 1, 0.125, 0.98, 17},
				{1.48, 1, 0.15, 0.98, 17},
				{1.48, 1, 0.175, 0.98, 17},
				{1.48, 1, 0.2, 0.98, 17},
				{1.48, 1, 0.225, 0.98, 17},
				{1.48, 1, 0.25, 0.98, 17},
				{1.48, 1, 0.275, 0.98, 17},
				{1.48, 1, 0.3, 0.98, 17},
				{1.48, 1, 0.325, 0.98, 17},
				{1.48, 1, 0.35, 0.98, 17},
				{1.48, 1, 0.375, 0.98, 17},
				{1.48, 1, 0.4, 0.98, 17},
				{1.48, 1, 0.425, 0.98, 17},
				{1.48, 1, 0.45, 0.98, 17},
				{1.48, 1, 0.475, 0.98, 17},
				{1.48, 1, 0.5, 0.98, 17},
				{1.48, 1, 0.525, 0.98, 17},
				{1.48, 1, 0.55, 0.98, 17},
				{1.48, 1, 0.575, 0.98, 17},
				{1.48, 1, 0.6, 0.98, 17},
				{1.48, 1, 0.625, 0.98, 17},
				{1.48, 1, 0.65, 0.98, 17},
				{1.48, 1, 0.675, 0.98, 17},
				{1.48, 1, 0.7, 0.98, 17},
				{1.48, 1, 0.725, 0.98, 17},
				{1.48, 1, 0.75, 0.98, 17},
				{1.48, 1, 0.775, 0.98, 17},
				{1.48, 1, 0.8, 0.98, 17},
				{1.48, 1, 0.825, 0.98, 17},
				{1.48, 1, 0.85, 0.98, 17},
				{1.48, 1, 0.875, 0.98, 17},
				{1.48, 1, 0.9, 0.98, 17},
				{1.48, 1, 0.925, 0.98, 17},
				{1.48, 1, 0.95, 0.98, 17},
				{1.48, 1, 0.975, 0.98, 17},
			},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "DustRingHigh",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			direction = "Front",
			pitch = 35,
			spread = {12, 10},
			speed = {50, 90},
			drag = 2,
			accel = {0, 4, 0},
			lifetime = {1.2, 1.8},
			size = {
				{0, 18, 3},
				{1, 44, 5},
			},
			transparency = {
				{0, 0.45, 0},
				{0.3, 0.55, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{238, 246, 255},
				},
				{
					0.35,
					{200, 222, 252},
				},
				{
					1,
					{160, 188, 236},
				},
			},
			light_emission = 0.2,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -2,
			ring_emit = {
				{1.52, 1, 0.0179, 0.95, 26},
				{1.52, 1, 0.0536, 0.95, 26},
				{1.52, 1, 0.0893, 0.95, 26},
				{1.52, 1, 0.125, 0.95, 26},
				{1.52, 1, 0.1607, 0.95, 26},
				{1.52, 1, 0.1964, 0.95, 26},
				{1.52, 1, 0.2321, 0.95, 26},
				{1.52, 1, 0.2679, 0.95, 26},
				{1.52, 1, 0.3036, 0.95, 26},
				{1.52, 1, 0.3393, 0.95, 26},
				{1.52, 1, 0.375, 0.95, 26},
				{1.52, 1, 0.4107, 0.95, 26},
				{1.52, 1, 0.4464, 0.95, 26},
				{1.52, 1, 0.4821, 0.95, 26},
				{1.52, 1, 0.5179, 0.95, 26},
				{1.52, 1, 0.5536, 0.95, 26},
				{1.52, 1, 0.5893, 0.95, 26},
				{1.52, 1, 0.625, 0.95, 26},
				{1.52, 1, 0.6607, 0.95, 26},
				{1.52, 1, 0.6964, 0.95, 26},
				{1.52, 1, 0.7321, 0.95, 26},
				{1.52, 1, 0.7679, 0.95, 26},
				{1.52, 1, 0.8036, 0.95, 26},
				{1.52, 1, 0.8393, 0.95, 26},
				{1.52, 1, 0.875, 0.95, 26},
				{1.52, 1, 0.9107, 0.95, 26},
				{1.52, 1, 0.9464, 0.95, 26},
				{1.52, 1, 0.9821, 0.95, 26},
			},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "EdgeShards",
			texture = "mf_shard_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			direction = "Front",
			pitch = 45,
			spread = {25, 20},
			speed = {60, 120},
			drag = 0.4,
			accel = {0, -140, 0},
			lifetime = {0.9, 1.3},
			size = {
				{0, 3.2, 0.8},
				{1, 2.2, 0.6},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.4,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			ring_emit = {
				{1.5, 1, 0, 0.97, 3},
				{1.5, 1, 0.0167, 0.97, 3},
				{1.5, 1, 0.0333, 0.97, 3},
				{1.5, 1, 0.05, 0.97, 3},
				{1.5, 1, 0.0667, 0.97, 3},
				{1.5, 1, 0.0833, 0.97, 3},
				{1.5, 1, 0.1, 0.97, 3},
				{1.5, 1, 0.1167, 0.97, 3},
				{1.5, 1, 0.1333, 0.97, 3},
				{1.5, 1, 0.15, 0.97, 3},
				{1.5, 1, 0.1667, 0.97, 3},
				{1.5, 1, 0.1833, 0.97, 3},
				{1.5, 1, 0.2, 0.97, 3},
				{1.5, 1, 0.2167, 0.97, 3},
				{1.5, 1, 0.2333, 0.97, 3},
				{1.5, 1, 0.25, 0.97, 3},
				{1.5, 1, 0.2667, 0.97, 3},
				{1.5, 1, 0.2833, 0.97, 3},
				{1.5, 1, 0.3, 0.97, 3},
				{1.5, 1, 0.3167, 0.97, 3},
				{1.5, 1, 0.3333, 0.97, 3},
				{1.5, 1, 0.35, 0.97, 3},
				{1.5, 1, 0.3667, 0.97, 3},
				{1.5, 1, 0.3833, 0.97, 3},
				{1.5, 1, 0.4, 0.97, 3},
				{1.5, 1, 0.4167, 0.97, 3},
				{1.5, 1, 0.4333, 0.97, 3},
				{1.5, 1, 0.45, 0.97, 3},
				{1.5, 1, 0.4667, 0.97, 3},
				{1.5, 1, 0.4833, 0.97, 3},
				{1.5, 1, 0.5, 0.97, 3},
				{1.5, 1, 0.5167, 0.97, 3},
				{1.5, 1, 0.5333, 0.97, 3},
				{1.5, 1, 0.55, 0.97, 3},
				{1.5, 1, 0.5667, 0.97, 3},
				{1.5, 1, 0.5833, 0.97, 3},
				{1.5, 1, 0.6, 0.97, 3},
				{1.5, 1, 0.6167, 0.97, 3},
				{1.5, 1, 0.6333, 0.97, 3},
				{1.5, 1, 0.65, 0.97, 3},
				{1.5, 1, 0.6667, 0.97, 3},
				{1.5, 1, 0.6833, 0.97, 3},
				{1.5, 1, 0.7, 0.97, 3},
				{1.5, 1, 0.7167, 0.97, 3},
				{1.5, 1, 0.7333, 0.97, 3},
				{1.5, 1, 0.75, 0.97, 3},
				{1.5, 1, 0.7667, 0.97, 3},
				{1.5, 1, 0.7833, 0.97, 3},
				{1.5, 1, 0.8, 0.97, 3},
				{1.5, 1, 0.8167, 0.97, 3},
				{1.5, 1, 0.8333, 0.97, 3},
				{1.5, 1, 0.85, 0.97, 3},
				{1.5, 1, 0.8667, 0.97, 3},
				{1.5, 1, 0.8833, 0.97, 3},
				{1.5, 1, 0.9, 0.97, 3},
				{1.5, 1, 0.9167, 0.97, 3},
				{1.5, 1, 0.9333, 0.97, 3},
				{1.5, 1, 0.95, 0.97, 3},
				{1.5, 1, 0.9667, 0.97, 3},
				{1.5, 1, 0.9833, 0.97, 3},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "CollapseGlow",
			texture = "fx_glow",
			hu = "H",
			lifetime = {0.3, 0.3},
			direction = "Bottom",
			speed_h = {2.2, 2.2},
			size = {
				{0, 96, 0},
				{1, 48, 0},
			},
			transparency = {
				{0, 0.2, 0},
				{1, 0.4, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			brightness = 2.2,
			ring_emit = {
				{3.28, 1, 0, 0, 0.85},
			},
			bill = true,
			rel = "r",
			speed = {0, 0},
			spread = {0, 0},
			accel = {0, 0, 0},
			drag = 0,
			light_emission = 0,
			rotation = {0, 0},
			rot_speed = {0, 0},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "DetFlash",
			texture = "fx_glow",
			lifetime = {0.38, 0.38},
			size = {
				{0, 40, 0},
				{0.15, 300, 0},
				{1, 324, 0},
			},
			transparency = {
				{0, 0.25, 0},
				{0.3, 0.6, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{230, 245, 255},
				},
				{
					0.5,
					{155, 210, 255},
				},
				{
					1,
					{85, 145, 245},
				},
			},
			brightness = 2.4,
			zoffset = 4,
			ring_emit = {
				{3.55, 1, 0, 0, 40},
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
			lifetime = {0.4, 0.4},
			rotation = {0, 90},
			size = {
				{0, 60, 0},
				{0.15, 456, 0},
				{1, 60, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			brightness = 2.8,
			zoffset = 5,
			ring_emit = {
				{3.55, 1, 0, 0, 40},
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
			name = "DetDome",
			texture = "fx_smoke_2x2",
			flipbook = {
				layout = "Grid2x2",
				mode = "Loop",
				fps = 0.001,
				startRandom = true,
			},
			rel = "r",
			direction = "Front",
			pitch = 30,
			spread = {14, 12},
			speed = {70, 130},
			drag = 2,
			accel = {0, 3, 0},
			lifetime = {1.3, 1.9},
			size = {
				{0, 26, 4},
				{1, 70, 8},
			},
			transparency = {
				{0, 0.3, 0},
				{0.3, 0.5, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{238, 246, 255},
				},
				{
					0.35,
					{200, 222, 252},
				},
				{
					1,
					{160, 188, 236},
				},
			},
			light_emission = 0.25,
			rotation = {0, 360},
			rot_speed = {-30, 30},
			zoffset = -1,
			ring_emit = {
				{3.55, 1, 0, 0.35, 26},
				{3.55, 1, 0.0294, 0.35, 26},
				{3.55, 1, 0.0588, 0.35, 26},
				{3.55, 1, 0.0882, 0.35, 26},
				{3.55, 1, 0.1176, 0.35, 26},
				{3.55, 1, 0.1471, 0.35, 26},
				{3.55, 1, 0.1765, 0.35, 26},
				{3.55, 1, 0.2059, 0.35, 26},
				{3.55, 1, 0.2353, 0.35, 26},
				{3.55, 1, 0.2647, 0.35, 26},
				{3.55, 1, 0.2941, 0.35, 26},
				{3.55, 1, 0.3235, 0.35, 26},
				{3.55, 1, 0.3529, 0.35, 26},
				{3.55, 1, 0.3824, 0.35, 26},
				{3.55, 1, 0.4118, 0.35, 26},
				{3.55, 1, 0.4412, 0.35, 26},
				{3.55, 1, 0.4706, 0.35, 26},
				{3.55, 1, 0.5, 0.35, 26},
				{3.55, 1, 0.5294, 0.35, 26},
				{3.55, 1, 0.5588, 0.35, 26},
				{3.55, 1, 0.5882, 0.35, 26},
				{3.55, 1, 0.6176, 0.35, 26},
				{3.55, 1, 0.6471, 0.35, 26},
				{3.55, 1, 0.6765, 0.35, 26},
				{3.55, 1, 0.7059, 0.35, 26},
				{3.55, 1, 0.7353, 0.35, 26},
				{3.55, 1, 0.7647, 0.35, 26},
				{3.55, 1, 0.7941, 0.35, 26},
				{3.55, 1, 0.8235, 0.35, 26},
				{3.55, 1, 0.8529, 0.35, 26},
				{3.55, 1, 0.8824, 0.35, 26},
				{3.55, 1, 0.9118, 0.35, 26},
				{3.55, 1, 0.9412, 0.35, 26},
				{3.55, 1, 0.9706, 0.35, 26},
				{3.55, 1, 0.025, 0.12, 48},
				{3.55, 1, 0.075, 0.12, 48},
				{3.55, 1, 0.125, 0.12, 48},
				{3.55, 1, 0.175, 0.12, 48},
				{3.55, 1, 0.225, 0.12, 48},
				{3.55, 1, 0.275, 0.12, 48},
				{3.55, 1, 0.325, 0.12, 48},
				{3.55, 1, 0.375, 0.12, 48},
				{3.55, 1, 0.425, 0.12, 48},
				{3.55, 1, 0.475, 0.12, 48},
				{3.55, 1, 0.525, 0.12, 48},
				{3.55, 1, 0.575, 0.12, 48},
				{3.55, 1, 0.625, 0.12, 48},
				{3.55, 1, 0.675, 0.12, 48},
				{3.55, 1, 0.725, 0.12, 48},
				{3.55, 1, 0.775, 0.12, 48},
				{3.55, 1, 0.825, 0.12, 48},
				{3.55, 1, 0.875, 0.12, 48},
				{3.55, 1, 0.925, 0.12, 48},
				{3.55, 1, 0.975, 0.12, 48},
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
			rel = "r",
			direction = "Top",
			spread = {70, 70},
			speed = {60, 140},
			drag = 0.4,
			accel = {0, -150, 0},
			lifetime = {0.9, 1.4},
			size = {
				{0, 4.5, 1.2},
				{1, 3, 0.8},
			},
			transparency = {
				{0, 0, 0},
				{0.85, 0.1, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{200, 230, 255},
				},
				{
					0.4,
					{120, 180, 255},
				},
				{
					1,
					{70, 120, 235},
				},
			},
			light_emission = 0.45,
			brightness = 1.5,
			rotation = {0, 360},
			rot_speed = {-500, 500},
			ring_emit = {
				{3.551, 2, 0.7221, 0.328, 19.735},
				{3.551, 2, 0.7297, 0.388, 12.623},
				{3.552, 2, 0.5158, 0.472, 19.177},
				{3.552, 2, 0.7912, 0.494, 20.998},
				{3.554, 2, 0.5039, 0.743, 19.546},
				{3.555, 2, 0.6754, 0.348, 15.98},
				{3.555, 2, 0.9681, 0.736, 13.24},
				{3.556, 2, 0.3183, 0.851, 14.663},
				{3.557, 2, 0.4234, 0.575, 11.465},
				{3.557, 2, 0.9877, 0.886, 19.893},
				{3.558, 2, 0.0828, 0.339, 20.063},
				{3.558, 2, 0.6756, 0.837, 10.458},
				{3.56, 2, 0.3111, 0.728, 14.628},
				{3.56, 2, 0.3469, 0.915, 15.161},
				{3.561, 2, 0.7791, 0.619, 19.421},
				{3.562, 2, 0.4729, 0.713, 15.647},
				{3.563, 2, 0.1312, 0.993, 24.925},
				{3.563, 2, 0.4401, 0.741, 17.267},
				{3.563, 2, 0.4942, 0.252, 5.245},
				{3.563, 2, 0.627, 0.765, 13.993},
				{3.564, 2, 0.7954, 0.768, 18.235},
				{3.564, 2, 0.8643, 0.892, 18.874},
				{3.565, 2, 0.5669, 0.674, 16.321},
				{3.567, 2, 0.2826, 0.985, 7.193},
				{3.568, 2, 0.2416, 0.89, 11.056},
				{3.568, 2, 0.3121, 0.266, 8.846},
				{3.569, 2, 0.1772, 0.335, 23.063},
				{3.569, 2, 0.9256, 0.985, 23.208},
				{3.569, 2, 0.9436, 0.938, 17.31},
				{3.57, 2, 0.6147, 0.966, 20.812},
				{3.57, 2, 0.8632, 0.884, 9.017},
				{3.57, 2, 0.9513, 0.932, 10.234},
				{3.571, 2, 0.1868, 0.898, 5.297},
				{3.571, 2, 0.2744, 0.36, 12.438},
				{3.573, 2, 0.0074, 0.734, 17.729},
				{3.573, 2, 0.3575, 0.961, 19.217},
				{3.573, 2, 0.407, 0.926, 9.84},
				{3.573, 2, 0.6211, 0.276, 22.106},
				{3.574, 2, 0.6016, 0.929, 19.738},
				{3.575, 2, 0.5949, 0.557, 21.395},
				{3.576, 2, 0.3246, 0.902, 7.415},
				{3.577, 2, 0.2384, 0.91, 23.817},
				{3.578, 2, 0.2461, 0.927, 13.927},
				{3.579, 2, 0.3304, 0.798, 20.696},
				{3.579, 2, 0.4582, 0.603, 7.963},
				{3.582, 2, 0.8241, 0.564, 9.835},
				{3.584, 2, 0.4723, 0.584, 13.188},
				{3.585, 2, 0.5492, 0.357, 9.558},
				{3.585, 2, 0.6666, 0.397, 21.449},
				{3.585, 2, 0.857, 0.035, 24.875},
				{3.586, 2, 0.1899, 0.739, 5.381},
				{3.586, 2, 0.3546, 0.326, 7.37},
				{3.586, 2, 0.9962, 0.762, 10.573},
				{3.588, 2, 0.2923, 0.534, 20.868},
				{3.589, 2, 0.0089, 0.883, 21.819},
				{3.589, 2, 0.1884, 0.738, 18.013},
				{3.59, 2, 0.6382, 0.673, 9.267},
				{3.591, 2, 0.0629, 0.494, 21.515},
				{3.592, 2, 0.77, 0.625, 18.227},
				{3.593, 2, 0.7889, 0.992, 19.229},
				{3.594, 2, 0.0015, 0.858, 24.198},
				{3.594, 2, 0.0471, 0.361, 21.834},
				{3.595, 2, 0.4974, 0.741, 18.39},
				{3.595, 2, 0.5174, 0.712, 17.227},
				{3.596, 2, 0.5355, 0.329, 14.352},
				{3.597, 2, 0.2464, 0.306, 9.328},
				{3.597, 2, 0.6062, 0.764, 19.077},
				{3.598, 2, 0.134, 0.309, 14.865},
				{3.599, 2, 0.165, 0.78, 17.867},
				{3.599, 2, 0.2885, 0.408, 8.765},
			},
			zoffset = 0,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
		{
			name = "DetGlitter",
			texture = "kk_star_06",
			rel = "r",
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
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
				},
			},
			light_emission = 1,
			brightness = 2.2,
			rotation = {0, 45},
			ring_emit = {
				{3.55, 1, 0.8059, 0.62, 25.948},
				{3.55, 1, 0.8679, 0.511, 67.167},
				{3.553, 1, 0.039, 0.549, 58.57},
				{3.553, 1, 0.6093, 1.036, 66.697},
				{3.555, 1, 0.5678, 0.788, 68.2},
				{3.555, 1, 0.7359, 0.469, 10.67},
				{3.559, 1, 0.0199, 0.809, 48.503},
				{3.56, 1, 0.1073, 0.362, 23.266},
				{3.56, 1, 0.7521, 1.095, 26.364},
				{3.564, 1, 0.5546, 0.786, 66.384},
				{3.565, 1, 0.2537, 0.795, 61.666},
				{3.566, 1, 0.8225, 0.785, 48.37},
				{3.573, 1, 0.2793, 0.146, 11.449},
				{3.576, 1, 0.2402, 0.754, 62.916},
				{3.577, 1, 0.0115, 0.804, 54.887},
				{3.577, 1, 0.0886, 0.237, 45.543},
				{3.585, 1, 0.1934, 0.921, 39.942},
				{3.59, 1, 0.666, 0.784, 63.631},
				{3.592, 1, 0.848, 1.016, 16.488},
				{3.593, 1, 0.1527, 0.459, 25.203},
				{3.593, 1, 0.7036, 0.795, 39.769},
				{3.596, 1, 0.1022, 0.749, 63.79},
				{3.596, 1, 0.4259, 1.008, 44.031},
				{3.602, 1, 0.6526, 0.374, 15.429},
				{3.602, 1, 0.9169, 0.719, 67.016},
				{3.603, 1, 0.6972, 0.574, 48.342},
				{3.607, 1, 0.9741, 0.701, 54.142},
				{3.609, 1, 0.9003, 0.692, 65.625},
				{3.612, 1, 0.9, 0.858, 18.148},
				{3.614, 1, 0.6627, 0.832, 39.08},
				{3.618, 1, 0.9939, 0.437, 59.993},
				{3.626, 1, 0.9708, 0.878, 12.546},
				{3.629, 1, 0.408, 0.898, 20.475},
				{3.631, 1, 0.326, 1.043, 33.38},
				{3.631, 1, 0.7308, 0.439, 54.916},
				{3.633, 1, 0.4035, 0.274, 8.937},
				{3.636, 1, 0.6212, 0.907, 58.616},
				{3.644, 1, 0.7911, 0.725, 52.665},
				{3.647, 1, 0.4771, 0.906, 14.143},
				{3.653, 1, 0.1054, 0.9, 39.697},
				{3.654, 1, 0.8452, 0.447, 25.127},
				{3.658, 1, 0.9839, 0.956, 42.071},
				{3.659, 1, 0.7004, 0.874, 66.882},
				{3.66, 1, 0.4766, 0.433, 65.769},
				{3.662, 1, 0.9522, 0.733, 43.667},
				{3.664, 1, 0.3593, 0.17, 25.475},
				{3.665, 1, 0.7789, 0.762, 44.742},
				{3.668, 1, 0.8866, 0.856, 37.254},
				{3.674, 1, 0.5969, 0.64, 10.279},
				{3.678, 1, 0.1548, 0.879, 16.967},
				{3.679, 1, 0.2876, 0.575, 36.527},
				{3.682, 1, 0.7431, 0.95, 38.777},
				{3.683, 1, 0.359, 0.96, 53.333},
				{3.685, 1, 0.8923, 0.83, 14.609},
				{3.692, 1, 0.0085, 0.839, 45.387},
				{3.692, 1, 0.0486, 0.809, 38.34},
				{3.694, 1, 0.5948, 0.867, 46.051},
				{3.698, 1, 0.5916, 0.533, 50.3},
				{3.699, 1, 0.7131, 0.925, 47.491},
				{3.699, 1, 0.8873, 1.083, 11.809},
				{3.703, 1, 0.7734, 0.694, 14.232},
				{3.705, 1, 0.8083, 0.448, 69.647},
				{3.713, 1, 0.7224, 0.248, 61.722},
				{3.717, 1, 0.5048, 0.473, 56.332},
				{3.718, 1, 0.0237, 1.05, 46.852},
				{3.724, 1, 0.6477, 0.934, 61.496},
				{3.724, 1, 0.6673, 0.743, 23.134},
				{3.727, 1, 0.9736, 0.296, 18.739},
				{3.731, 1, 0.0135, 0.087, 55.597},
				{3.739, 1, 0.21, 0.871, 32.987},
				{3.743, 1, 0.4084, 0.26, 63.414},
				{3.743, 1, 0.4328, 1.051, 33.39},
				{3.745, 1, 0.0838, 0.785, 61.731},
				{3.747, 1, 0.1224, 0.819, 68.342},
				{3.756, 1, 0.1913, 0.796, 68.553},
				{3.757, 1, 0.2443, 0.974, 30.885},
				{3.766, 1, 0.5026, 0.877, 26.904},
				{3.767, 1, 0.6402, 0.647, 65.269},
				{3.767, 1, 0.9877, 0.797, 20.423},
				{3.768, 1, 0.3639, 0.898, 40.764},
				{3.768, 1, 0.4674, 1.071, 12.273},
				{3.77, 1, 0.5396, 0.911, 10.496},
				{3.771, 1, 0.2188, 1.019, 61.817},
				{3.775, 1, 0.9068, 0.076, 39.485},
				{3.778, 1, 0.9404, 0.745, 34.766},
				{3.786, 1, 0.1846, 0.811, 65.273},
				{3.786, 1, 0.8749, 0.479, 66.065},
				{3.787, 1, 0.614, 0.909, 38.908},
				{3.788, 1, 0.4854, 1.003, 64.967},
				{3.79, 1, 0.1653, 0.762, 46.367},
				{3.794, 1, 0.3918, 0.383, 32.84},
				{3.796, 1, 0.6477, 0.66, 55.762},
				{3.798, 1, 0.6101, 0.123, 11.302},
				{3.805, 1, 0.3744, 0.811, 66.708},
				{3.806, 1, 0.5223, 0.147, 45.897},
				{3.813, 1, 0.8809, 0.527, 62.566},
				{3.814, 1, 0.3534, 0.695, 26.835},
				{3.815, 1, 0.2683, 0.666, 52.542},
				{3.816, 1, 0.5654, 0.279, 60.404},
				{3.83, 1, 0.488, 0.83, 53.085},
				{3.831, 1, 0.0273, 0.74, 8.099},
				{3.834, 1, 0.9524, 0.276, 52.067},
				{3.835, 1, 0.5115, 1.038, 32.867},
				{3.839, 1, 0.3398, 0.698, 36.517},
				{3.842, 1, 0.6107, 0.753, 15.459},
				{3.842, 1, 0.7606, 0.603, 10.979},
				{3.846, 1, 0.7786, 0.87, 63.668},
				{3.847, 1, 0.9573, 0.681, 12.133},
				{3.856, 1, 0.9744, 0.25, 20.078},
				{3.864, 1, 0.0006, 0.85, 21.652},
				{3.868, 1, 0.4591, 0.895, 50.653},
				{3.873, 1, 0.5413, 0.835, 54.423},
				{3.878, 1, 0.8887, 0.714, 8.483},
				{3.887, 1, 0.5508, 1.003, 19.349},
				{3.887, 1, 0.7366, 0.993, 49.198},
				{3.892, 1, 0.2429, 0.269, 24.439},
				{3.897, 1, 0.7359, 0.989, 43.538},
				{3.9, 1, 0.3406, 0.878, 30.017},
				{3.906, 1, 0.0856, 1.1, 18.27},
				{3.907, 1, 0.5342, 0.615, 47.023},
				{3.911, 1, 0.6393, 0.153, 42.82},
				{3.912, 1, 0.4576, 1.029, 13.378},
				{3.913, 1, 0.1037, 0.627, 26.394},
				{3.913, 1, 0.1667, 0.841, 23.477},
				{3.914, 1, 0.5372, 0.954, 28.211},
				{3.916, 1, 0.1049, 0.426, 49.718},
				{3.918, 1, 0.923, 0.668, 32.727},
				{3.922, 1, 0.8598, 0.653, 10.67},
				{3.929, 1, 0.5543, 0.513, 53.576},
				{3.929, 1, 0.7522, 1.019, 15.184},
				{3.93, 1, 0.5902, 0.679, 55.044},
				{3.933, 1, 0.1677, 0.983, 50.919},
				{3.936, 1, 0.4408, 0.709, 21.706},
				{3.939, 1, 0.5084, 1.08, 61.793},
				{3.941, 1, 0.7033, 0.419, 32.613},
				{3.942, 1, 0.3253, 1.074, 58.748},
				{3.943, 1, 0.3785, 0.97, 34.344},
				{3.95, 1, 0.5296, 0.96, 17.265},
				{3.96, 1, 0.7738, 0.481, 32.171},
				{3.965, 1, 0.2174, 0.946, 32.325},
				{3.965, 1, 0.4804, 0.724, 50.083},
				{3.97, 1, 0.6235, 0.835, 14.974},
				{3.974, 1, 0.8557, 0.518, 8.873},
				{3.976, 1, 0.8134, 1.063, 37.308},
				{3.981, 1, 0.3898, 0.594, 33.317},
				{3.983, 1, 0.1801, 0.439, 18.853},
				{3.988, 1, 0.7967, 0.94, 49.521},
				{3.99, 1, 0.9842, 0.946, 15.489},
				{3.991, 1, 0.7937, 0.833, 43.357},
				{3.995, 1, 0.1089, 0.45, 32.726},
				{3.998, 1, 0.6961, 0.449, 12.66},
				{4.004, 1, 0.9465, 0.997, 10.153},
				{4.008, 1, 0.1102, 0.923, 40.654},
				{4.008, 1, 0.2081, 0.809, 53.437},
				{4.011, 1, 0.9112, 0.933, 47.355},
				{4.013, 1, 0.8898, 1.058, 25.994},
				{4.014, 1, 0.3534, 0.544, 66.724},
				{4.021, 1, 0.9428, 0.934, 14.081},
				{4.023, 1, 0.3165, 1.035, 11.553},
				{4.024, 1, 0.9265, 0.564, 64.297},
				{4.026, 1, 0.0526, 0.956, 26.646},
				{4.027, 1, 0.124, 0.826, 40.368},
				{4.029, 1, 0.2168, 0.406, 30.992},
				{4.029, 1, 0.5735, 0.706, 35.528},
				{4.029, 1, 0.7008, 0.489, 35.866},
				{4.032, 1, 0.9135, 0.634, 53.707},
				{4.034, 1, 0.6015, 0.884, 8.43},
				{4.037, 1, 0.7109, 0.335, 22.975},
				{4.046, 1, 0.1701, 1.061, 18.935},
				{4.05, 1, 0.0397, 0.925, 34.307},
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
			rel = "r",
			direction = "Top",
			spread = {60, 60},
			speed = {2, 6},
			drag = 1,
			lifetime = {1.8, 2.4},
			size = {
				{0, 22, 3},
				{1, 44, 5},
			},
			transparency = {
				{0, 1, 0},
				{0.3, 0.68, 0},
				{0.8, 0.78, 0},
				{1, 1, 0},
			},
			color = {
				{
					0,
					{238, 246, 255},
				},
				{
					0.35,
					{200, 222, 252},
				},
				{
					1,
					{160, 188, 236},
				},
			},
			light_emission = 0.2,
			rotation = {0, 360},
			rot_speed = {-15, 15},
			zoffset = -4,
			ring_emit = {
				{3.669, 1, 0.2421, 0.834, 18.326},
				{3.672, 1, 0.6297, 0.615, 17.523},
				{3.701, 1, 0.3023, 0.862, 18.387},
				{3.749, 1, 0.1263, 0.293, 16.298},
				{3.749, 1, 0.6508, 0.934, 19.956},
				{3.755, 1, 0.4535, 0.52, 18.367},
				{3.757, 1, 0.2509, 0.696, 15.134},
				{3.759, 1, 0.0937, 0.654, 17.343},
				{3.764, 1, 0.6304, 0.575, 19.178},
				{3.775, 1, 0.5584, 0.774, 18.525},
				{3.775, 1, 0.794, 0.398, 15.634},
				{3.811, 1, 0.2523, 0.852, 18.441},
				{3.812, 1, 0.1503, 0.703, 17.033},
				{3.814, 1, 0.7712, 0.862, 19.857},
				{3.848, 1, 0.4897, 0.85, 18.279},
				{3.853, 1, 0.4286, 0.346, 16.513},
				{3.877, 1, 0.5754, 0.567, 19.782},
				{3.884, 1, 0.068, 0.98, 17.198},
				{3.886, 1, 0.832, 0.591, 19.78},
				{3.89, 1, 0.9973, 0.888, 15.183},
				{3.895, 1, 0.8683, 0.755, 18.283},
				{3.905, 1, 0.7754, 0.557, 16.229},
				{3.908, 1, 0.3723, 0.892, 18.664},
				{3.914, 1, 0.1101, 0.584, 17.581},
				{3.925, 1, 0.8937, 0.299, 18.338},
				{3.986, 1, 0.045, 0.908, 17.876},
				{4.001, 1, 0.0075, 0.726, 18.912},
				{4.002, 1, 0.6209, 0.884, 16.383},
				{4.008, 1, 0.5913, 0.937, 16.235},
				{4.015, 1, 0.9989, 0.876, 16.14},
				{4.027, 1, 0.8597, 0.463, 16.41},
				{4.07, 1, 0.5731, 0.969, 18.139},
				{4.08, 1, 0.0233, 0.965, 16.588},
				{4.111, 1, 0.5881, 0.89, 17.813},
				{4.117, 1, 0.7693, 0.825, 19.032},
				{4.146, 1, 0.2331, 0.381, 16.373},
			},
			accel = {0, 0, 0},
			brightness = 1,
			orientation = "FacingCamera",
			offset = {0, 0, 0},
			line_u = 0,
			emit = {},
		},
	},
	shakes = {
		{1.42, 2.2, 0.8},
		{3.55, 2.6, 1},
	},
	shake_ramp = {0, 3.3, 0.15, 1.3, 1.8},
	zone = {
		radius = 120,
		height = 340,
		charge = 1.3,
		collapse = 3.3,
	},
	lights = {
		{
			t = 0.3,
			h = 10,
			color = {150, 190, 255},
			brightness = 1.5,
			range = 60,
			rise = 0.8,
			hold = 0.2,
			fall = 0.3,
			ring = {6, 0.6},
		},
		{
			t = 1.42,
			h = 8,
			color = {190, 225, 255},
			brightness = 10,
			range = 60,
			rise = 0.03,
			hold = 0.08,
			fall = 0.6,
		},
		{
			t = 1.42,
			h = 8,
			color = {190, 225, 255},
			brightness = 10,
			range = 60,
			rise = 0.03,
			hold = 0.08,
			fall = 0.6,
			ring = {6, 0.62},
		},
		{
			t = 1.52,
			h = 14,
			color = {150, 200, 255},
			brightness = 4,
			range = 60,
			rise = 0.1,
			hold = 1.58,
			fall = 0.3,
			ring = {6, 0.55},
		},
		{
			t = 3.55,
			h = 10,
			color = {200, 230, 255},
			brightness = 12,
			range = 60,
			rise = 0.02,
			hold = 0.05,
			fall = 0.8,
		},
		{
			t = 3.55,
			h = 10,
			color = {200, 230, 255},
			brightness = 12,
			range = 60,
			rise = 0.02,
			hold = 0.05,
			fall = 0.8,
			ring = {8, 0.6},
		},
	},
	times = {
		Eclipse = 1.3,
		Impact = 1.42,
		Collapse = 3.3,
		Detonation = 3.55,
	},
	screen = {
		range = 3,
		cc = {
			{0, 0, 0, 0, 255, 255, 255},
			{0.4, -0.04, 0.04, -0.08, 228, 236, 255},
			{1.3, -0.16, 0.14, -0.22, 188, 204, 255},
			{3.3, -0.16, 0.14, -0.22, 188, 204, 255},
			{3.55, 0.06, 0.1, -0.1, 232, 242, 255},
			{4.85, 0, 0, 0, 255, 255, 255},
		},
		flash = {
			{1.42, 0.45, 0.03, 0.35},
			{3.55, 0.6, 0.03, 0.55},
		},
		flash_color = {226, 238, 255},
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
			{150, 205, 255},
			{90, 150, 255},
			{220, 238, 255},
			{120, 175, 255},
		},
		groups = {
			{
				name = "Lift",
				mode = "lift",
				count = 90,
				t = {0.15, 1},
				r = {0.1, 0.95},
				size = {0.5, 3},
				skew = 2.2,
				lift = {3, 14},
				release = {1.42, 1.47},
				out = {25, 70},
				up = {50, 110},
				dissolve = 0.35,
				neon = 0.4,
			},
			{
				name = "Blast",
				mode = "blast",
				count = 260,
				t = {1.42, 1.5},
				r = {0.15, 1.05},
				size = {0.4, 3.2},
				skew = 2.6,
				out = {25, 90},
				up = {35, 110},
				dissolve = 0.35,
				neon = 0.3,
			},
			{
				name = "DetBlast",
				mode = "blast",
				count = 140,
				t = {3.55, 3.6},
				r = {0.05, 0.9},
				size = {0.4, 2.6},
				skew = 2.4,
				out = {40, 120},
				up = {40, 120},
				dissolve = 0.5,
				neon = 0.5,
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
				{0.2, 2.2, 0},
				{1, 0, 0},
			},
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					0.5,
					{225, 240, 255},
				},
				{
					1,
					{170, 205, 255},
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
			r = 0,
			a0 = 0,
			spin = 0,
			wobble = 0,
			near = 0,
			zoffset = 0,
			name = "Guide",
			texture = "mf_blade_line",
			width = 0.016,
			tex_len = 1,
			speed = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{235, 244, 255},
				},
			},
			transparency = {
				{0, 0.1},
				{1, 0.1},
			},
			brightness = 2.4,
			light_emission = 1,
			drop = {1.02, 0.14},
			h = {0, 0.985},
			width_t = {
				{1.02, 1},
				{1.3, 1.6},
				{1.42, 0},
			},
			alpha_t = {
				{1.02, 0},
				{1.39, 0},
				{1.42, 1},
			},
			rim = false,
		},
		{
			count = 14,
			r = 0.74,
			a0 = 0,
			spin = 10,
			wobble = 0.05,
			near = 0.85,
			zoffset = 0,
			name = "Curtain",
			texture = "mf_moonbeam",
			width = 0.55,
			tex_len = 0.35,
			speed = 1.3,
			color = {
				{
					0,
					{215, 232, 255},
				},
				{
					0.5,
					{165, 208, 255},
				},
				{
					1,
					{130, 185, 255},
				},
			},
			transparency = {
				{0, 1},
				{0.3, 1},
				{0.42, 0.42},
				{0.92, 0.34},
				{1, 0.45},
			},
			brightness = 1,
			light_emission = 1,
			width_t = {
				{1.3, 0.35},
				{1.42, 1.1},
				{1.54, 1},
				{3.25, 1},
				{3.48, 0.05},
				{3.53, 0.03},
				{3.55, 0},
			},
			alpha_t = {
				{1.3, 0.4},
				{1.42, 0},
				{3.3, 0},
				{3.5, 0.2},
				{3.55, 0.5},
			},
			r_t = {
				{3.25, 1},
				{3.48, 0.04},
			},
			drop = {1.3, 0.12},
			h = {0, 0.985},
			rim = false,
		},
		{
			count = 1,
			r = 0,
			a0 = 0.13,
			spin = 0,
			wobble = 0.03,
			near = 0.75,
			zoffset = 0,
			name = "Body",
			texture = "mf_moonbeam",
			width = 1.6,
			tex_len = 0.5,
			speed = 0.9,
			color = {
				{
					0,
					{150, 195, 255},
				},
				{
					1,
					{90, 150, 250},
				},
			},
			transparency = {
				{0, 1},
				{0.3, 1},
				{0.42, 0.6},
				{1, 0.62},
			},
			brightness = 0.85,
			light_emission = 1,
			width_t = {
				{1.3, 0.35},
				{1.42, 1.1},
				{1.54, 1},
				{3.25, 1},
				{3.48, 0.05},
				{3.53, 0.03},
				{3.55, 0},
			},
			alpha_t = {
				{1.3, 0.4},
				{1.42, 0},
				{3.3, 0},
				{3.5, 0.2},
				{3.55, 0.5},
			},
			drop = {1.3, 0.12},
			h = {0, 0.985},
			rim = false,
		},
		{
			count = 1,
			r = 0,
			a0 = 0,
			spin = 0,
			wobble = 0,
			near = 0.6,
			zoffset = 0,
			name = "Heart",
			texture = "mf_blade_glow",
			width = 0.5,
			tex_len = 1,
			speed = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{215, 235, 255},
				},
			},
			transparency = {
				{0, 1},
				{0.3, 1},
				{0.42, 0.25},
				{1, 0.2},
			},
			brightness = 1.5,
			light_emission = 1,
			width_t = {
				{1.3, 0.35},
				{1.42, 1.1},
				{1.54, 1},
				{3.25, 1},
				{3.48, 0.05},
				{3.53, 0.03},
				{3.55, 0},
			},
			alpha_t = {
				{1.3, 0.4},
				{1.42, 0},
				{3.3, 0},
				{3.5, 0.2},
				{3.55, 0.5},
			},
			drop = {1.3, 0.12},
			h = {0, 0.985},
			rim = false,
		},
		{
			count = 1,
			r = 0,
			a0 = 0,
			spin = 0,
			wobble = 0,
			near = 0,
			zoffset = 0,
			name = "Core",
			texture = "mf_blade_line",
			width = 0.08,
			tex_len = 1,
			speed = 0,
			color = {
				{
					0,
					{255, 255, 255},
				},
				{
					1,
					{235, 244, 255},
				},
			},
			transparency = {
				{0, 1},
				{0.3, 1},
				{0.42, 0},
				{1, 0},
			},
			brightness = 2.4,
			light_emission = 1,
			width_t = {
				{1.3, 0.6},
				{1.42, 1.2},
				{1.52, 1},
				{3.3, 1},
				{3.45, 1.5},
				{3.52, 1.8},
				{3.55, 0},
			},
			alpha_t = {
				{1.3, 0.2},
				{1.42, 0},
			},
			drop = {1.3, 0.12},
			h = {0, 0.985},
			rim = false,
		},
		{
			count = 1,
			r = 1,
			a0 = 0,
			spin = 0,
			wobble = 0,
			near = 0,
			zoffset = 0,
			name = "Rim",
			texture = "mf_blade_line",
			rim = true,
			width = 0.022,
			tex_len = 1,
			speed = 0,
			color = {
				{
					0,
					{235, 245, 255},
				},
				{
					1,
					{175, 215, 255},
				},
			},
			transparency = {
				{0, 1},
				{0.3, 1},
				{0.42, 0.1},
				{1, 0.15},
			},
			brightness = 2.2,
			light_emission = 1,
			width_t = {
				{1.3, 0.35},
				{1.42, 1.1},
				{1.54, 1},
				{3.25, 1},
				{3.48, 0.05},
				{3.53, 0.03},
				{3.55, 0},
			},
			alpha_t = {
				{1.3, 0.4},
				{1.42, 0},
				{3.3, 0},
				{3.5, 0.2},
				{3.55, 0.5},
			},
			r_t = {
				{3.25, 1},
				{3.48, 0.04},
			},
			drop = {1.3, 0.12},
			h = {0, 0.985},
		},
	},
	zfield = {
		groups = {
			{
				hold = {1, 1},
				sink = 0.4,
				name = "IceCrown",
				count = 40,
				ring = true,
				r = {0.96, 1.04},
				lean = "radial",
				wid = {3.5, 6},
				thick = {18, 34},
				len = {3.5, 6},
				tilt = {22, 42},
				yaw = 25,
				pitch = 8,
				show = 0.85,
				rise = 0.16,
				t = 1.44,
				sweep = 0.2,
				delay = {0, 0.06},
				end_at = {3.55, 3.6},
				big = {
					frac = 0.2,
					k = 1.35,
				},
				["end"] = "shatter",
				ice = {
					color = {150, 200, 255},
					material = "Ice",
					transparency = 0.22,
				},
				tip = 0.8,
				mesh = "IceCrown",
				shatter = {
					{
						name = "CrownBreak",
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
							size = {7, 26, 7},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {85, 85},
						speed = {25, 60},
						drag = 0.4,
						accel = {0, -120, 0},
						lifetime = {0.7, 1.1},
						size = {
							{0, 3.2, 0.8},
							{1, 2.2, 0.6},
						},
						transparency = {
							{0, 0, 0},
							{0.85, 0.1, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{200, 230, 255},
							},
							{
								0.4,
								{120, 180, 255},
							},
							{
								1,
								{70, 120, 235},
							},
						},
						light_emission = 0.45,
						brightness = 1.5,
						rotation = {0, 360},
						rot_speed = {-500, 500},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "CrownBreakGlint",
						texture = "kk_star_06",
						emit = {
							{0, 3},
						},
						shape = {
							type = "Box",
							size = {8, 24, 8},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {3, 9},
						drag = 2,
						lifetime = {0.4, 0.7},
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
								{225, 240, 255},
							},
							{
								1,
								{170, 205, 255},
							},
						},
						light_emission = 1,
						brightness = 2.2,
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
						name = "CrownBreakMist",
						texture = "fx_smoke_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 1},
						},
						offset = {0, 10, 0},
						direction = "Top",
						spread = {60, 60},
						speed = {4, 10},
						drag = 1.5,
						accel = {0, 2, 0},
						lifetime = {0.9, 1.3},
						size = {
							{0, 12, 2},
							{1, 26, 3},
						},
						transparency = {
							{0, 0.5, 0},
							{0.4, 0.62, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{220, 236, 255},
							},
							{
								1,
								{175, 200, 240},
							},
						},
						light_emission = 0.2,
						rotation = {0, 360},
						zoffset = -1,
						brightness = 1,
						rot_speed = {0, 0},
						orientation = "FacingCamera",
						line_u = 0,
					},
				},
			},
			{
				hold = {1, 1},
				sink = 0.4,
				name = "IceCrystals",
				count = 60,
				r = {0.12, 0.9},
				lean = "radial",
				wid = {2.5, 4.5},
				thick = {8, 18},
				len = {2.5, 4.5},
				tilt = {10, 40},
				yaw = 30,
				pitch = 12,
				show = 0.75,
				rise = 0.12,
				t = 1.42,
				sweep = 0.22,
				delay = {0, 0.05},
				end_at = {3.53, 3.63},
				big = {
					frac = 0.15,
					k = 1.5,
				},
				["end"] = "shatter",
				ice = {
					color = {150, 200, 255},
					material = "Ice",
					transparency = 0.22,
				},
				tip = 0.8,
				mesh = "IceCrystals",
				shatter = {
					{
						name = "CrownBreak",
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
							size = {4.2, 15.6, 4.2},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {85, 85},
						speed = {25, 60},
						drag = 0.4,
						accel = {0, -120, 0},
						lifetime = {0.7, 1.1},
						size = {
							{0, 3.2, 0.8},
							{1, 2.2, 0.6},
						},
						transparency = {
							{0, 0, 0},
							{0.85, 0.1, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{200, 230, 255},
							},
							{
								0.4,
								{120, 180, 255},
							},
							{
								1,
								{70, 120, 235},
							},
						},
						light_emission = 0.45,
						brightness = 1.5,
						rotation = {0, 360},
						rot_speed = {-500, 500},
						zoffset = 0,
						orientation = "FacingCamera",
						offset = {0, 0, 0},
						line_u = 0,
					},
					{
						name = "CrownBreakGlint",
						texture = "kk_star_06",
						emit = {
							{0, 1},
						},
						shape = {
							type = "Box",
							size = {4.8, 14.4, 4.8},
							style = "Volume",
							inout = "Outward",
						},
						direction = "Top",
						spread = {80, 80},
						speed = {3, 9},
						drag = 2,
						lifetime = {0.4, 0.7},
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
								{225, 240, 255},
							},
							{
								1,
								{170, 205, 255},
							},
						},
						light_emission = 1,
						brightness = 2.2,
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
						name = "CrownBreakMist",
						texture = "fx_smoke_2x2",
						flipbook = {
							layout = "Grid2x2",
							mode = "Loop",
							fps = 0.001,
							startRandom = true,
						},
						emit = {
							{0, 1},
						},
						offset = {0, 10, 0},
						direction = "Top",
						spread = {60, 60},
						speed = {4, 10},
						drag = 1.5,
						accel = {0, 2, 0},
						lifetime = {0.9, 1.3},
						size = {
							{0, 12, 2},
							{1, 26, 3},
						},
						transparency = {
							{0, 0.5, 0},
							{0.4, 0.62, 0},
							{1, 1, 0},
						},
						color = {
							{
								0,
								{220, 236, 255},
							},
							{
								1,
								{175, 200, 240},
							},
						},
						light_emission = 0.2,
						rotation = {0, 360},
						zoffset = -1,
						brightness = 1,
						rot_speed = {0, 0},
						orientation = "FacingCamera",
						line_u = 0,
					},
				},
			},
			{
				hold = {1, 1},
				sink = 0.5,
				name = "ZoneSlabs",
				count = 70,
				r = {0.1, 1},
				lean = "radial",
				wid = {4, 8},
				thick = {1, 2},
				len = {4, 8},
				tilt = {15, 45},
				yaw = 14,
				pitch = 10,
				show = 0.6,
				rise = 0.08,
				t = 1.42,
				sweep = 0.25,
				delay = {0, 0.05},
				end_at = {3.85, 4.35},
				ground = true,
				mesh = "ZoneSlabs",
			},
		},
	},
}

-- MOONFANG SKILL 4 (Eclipse, la ULTIMATE): una luna gigante aparece sobre la zona y se eclipsa mientras en el suelo se dibuja el círculo lunar y el hielo flota hacia ella; al quedar tapada cae una columna de luz de luna del ancho de toda la zona que congela el suelo (corona de picos de hielo en el borde, campo de cristales, escombros); al final la columna colapsa y todo el hielo revienta en una detonación. cf = centro de la zona en el suelo. Golpes: la columna a los 1.42 s y la detonación a los 3.55 s (ver EclipseTimes).
-- radius = radio de la zona en studs (por defecto 120 × escala); height = altura del pilar (por defecto 340 × escala).
function MoonfangVFX.Eclipse(cf: CFrame, radius: number?, height: number?, scale: number?, shake: number?): Part
	return playZone(SPEC_Eclipse, cf, scale, radius, height, shake)
end

-- segundos (desde la llamada) de cada momento: para sincronizar el daño, el sonido o la cámara
MoonfangVFX.EclipseTimes = {
	Eclipse = 1.3,
	Impact = 1.42,
	Collapse = 3.3,
	Detonation = 3.55,
}

return MoonfangVFX
