-- Roblox simulado (lo justo) para ejecutar KaijuFireVFX fuera de Studio y verificar
-- que cada efecto corre sin errores, emite, y se limpia por completo.
local M = {}
local now = 0
M.time = function() return now end

-- Vector3
local V = {}
V.__index = V
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
V.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2) end
	if k == "Unit" then local m = math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2); return v3(t.X / m, t.Y / m, t.Z / m) end
	return rawget(V, k)
end
function V.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V.Lerp(a, b, u) return v3(a.X + (b.X - a.X) * u, a.Y + (b.Y - a.Y) * u, a.Z + (b.Z - a.Z) * u) end
M.Vector3 = { new = v3, xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1), zero = v3(0, 0, 0), one = v3(1, 1, 1) }
M.Vector2 = { new = function(x, y) return { X = x, Y = y } end }
M.UDim2 = { new = function(a, b, c, d) return { a, b, c, d } end, fromScale = function(x, y) return { x, 0, y, 0 } end }

-- CFrame (posición + matriz 3x3 por filas)
local C = {}
local function mat(r, p) return setmetatable({ r = r, p = p }, C) end
local function mulMV(r, v) return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z) end
local function mulMM(a, b)
	local o = {}
	for i = 0, 2 do for j = 0, 2 do
		o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
	end end
	return o
end
local function transpose(r) return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] } end
local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
C.__add = function(a, b) return mat(a.r, a.p + b) end
C.__sub = function(a, b) return mat(a.r, a.p - b) end
C.__eq = function(a, b)
	for i = 1, 9 do if math.abs(a.r[i] - b.r[i]) > 1e-9 then return false end end
	return (a.p - b.p).Magnitude < 1e-9
end
C.__mul = function(a, b)
	if getmetatable(b) == C then return mat(mulMM(a.r, b.r), a.p + mulMV(a.r, b.p)) end
	return a.p + mulMV(a.r, b)
end
C.__index = function(t, k)
	if k == "Position" then return t.p end
	if k == "Rotation" then return mat(t.r, v3()) end
	if k == "UpVector" then return mulMV(t.r, v3(0, 1, 0)) end
	if k == "LookVector" then return mulMV(t.r, v3(0, 0, -1)) end
	if k == "RightVector" then return mulMV(t.r, v3(1, 0, 0)) end
	if k == "PointToWorldSpace" then return function(self, v) return self.p + mulMV(self.r, v) end end
	if k == "Inverse" then return function(self)
		local rt = transpose(self.r)
		return mat(rt, -mulMV(rt, self.p))
	end end
	if k == "X" then return t.p.X end
	if k == "Y" then return t.p.Y end
	if k == "Z" then return t.p.Z end
	if k == "PointToObjectSpace" then return function(self, v) return mulMV(transpose(self.r), v - self.p) end end
	if k == "VectorToWorldSpace" then return function(self, v) return mulMV(self.r, v) end end
	if k == "Lerp" then return function(self, o, u)
		local r = {}
		for i = 1, 9 do r[i] = self.r[i] + (o.r[i] - self.r[i]) * u end
		return mat(r, self.p + (o.p - self.p) * u)
	end end
	return nil
end
local function rx(a) local c, s = math.cos(a), math.sin(a); return { 1, 0, 0, 0, c, -s, 0, s, c } end
local function ry(a) local c, s = math.cos(a), math.sin(a); return { c, 0, s, 0, 1, 0, -s, 0, c } end
local function rz(a) local c, s = math.cos(a), math.sin(a); return { c, -s, 0, s, c, 0, 0, 0, 1 } end
M.CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then return mat(I, x) end
		return mat(I, v3(x or 0, y or 0, z or 0))
	end,
	Angles = function(a, b, c) return mat(mulMM(mulMM(rx(a), ry(b)), rz(c)), v3()) end,
	lookAt = function(at, target)
		local f = (target - at).Unit                  -- LookVector = -Z
		local r = f:Cross(v3(0, 1, 0)).Unit           -- RightVector = X
		local u = r:Cross(f)                          -- UpVector = Y
		return mat({ r.X, u.X, -f.X, r.Y, u.Y, -f.Y, r.Z, u.Z, -f.Z }, at)
	end,
	identity = mat(I, v3()),
	fromAxisAngle = function(ax, ang)
		local u = ax.Unit; local c, s = math.cos(ang), math.sin(ang); local t = 1 - c
		return mat({ t * u.X * u.X + c, t * u.X * u.Y - s * u.Z, t * u.X * u.Z + s * u.Y,
			t * u.X * u.Y + s * u.Z, t * u.Y * u.Y + c, t * u.Y * u.Z - s * u.X,
			t * u.X * u.Z - s * u.Y, t * u.Y * u.Z + s * u.X, t * u.Z * u.Z + c }, v3())
	end,
}
local Col = {}
Col.__index = Col
function Col:Lerp(o, u) return setmetatable({ R = self.R + (o.R - self.R) * u, G = self.G + (o.G - self.G) * u, B = self.B + (o.B - self.B) * u }, Col) end
M.Color3 = { new = function(r, g, b)
	assert(r >= 0 and g >= 0 and b >= 0, "Color3 negativo")
	return setmetatable({ R = r, G = g, B = b }, Col) end,
	fromRGB = function(r, g, b)
	assert(r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255, "Color3 fuera de rango")
	return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, Col) end }
M.NumberRange = { new = function(a, b) b = b or a; assert(a <= b, "NumberRange min>max"); return { Min = a, Max = b } end }
M.NumberSequenceKeypoint = { new = function(t, v, e) assert(v >= 0, "valor negativo"); return { Time = t, Value = v, Envelope = e or 0 } end }
M.ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
local function checkSeq(k, name)
	assert(#k >= 2 and #k <= 20, name .. ": 2..20 keypoints")
	assert(k[1].Time == 0 and k[#k].Time == 1, name .. ": debe ir de 0 a 1")
	for i = 2, #k do assert(k[i].Time > k[i - 1].Time, name .. ": tiempos no crecientes") end
end
M.NumberSequence = { new = function(k)
	if type(k) == "number" then
		return { Keypoints = { { Time = 0, Value = k, Envelope = 0 }, { Time = 1, Value = k, Envelope = 0 } } }
	end
	checkSeq(k, "NumberSequence"); return { Keypoints = k }
end }
M.ColorSequence = { new = function(k, k2)
	if type(k) == "table" and k.R ~= nil then -- un color (o dos): como en Roblox
		return { Keypoints = { { Time = 0, Value = k }, { Time = 1, Value = k2 or k } } }
	end
	checkSeq(k, "ColorSequence"); return { Keypoints = k }
end }
M.TweenInfo = { new = function(...) return { ... } end }
M.Random = { new = function() return {
	NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + (b - a) * math.random() end,
	NextInteger = function(_, a, b) return math.random(a, b) end,
} end }
M.Enum = setmetatable({}, { __index = function(_, enumName)
	return setmetatable({}, { __index = function(_, item)
		if enumName == "RenderPriority" then
			local v = ({ First = 0, Input = 100, Camera = 200, Character = 300, Last = 2000 })[item] or 200
			return { Value = v, Name = item }
		end
		return { Name = item, EnumType = enumName }
	end })
end })

-- planificador de tareas
local delays, waiting = {}, {}
M.task = {
	delay = function(t, f, ...) table.insert(delays, { at = now + t, f = f, args = { ... } }) end,
	spawn = function(f, ...)
		local co = coroutine.create(f)
		local ok, err = coroutine.resume(co, ...)
		if not ok then error(err) end
		return co
	end,
	wait = function(t)
		local co = coroutine.running()
		table.insert(waiting, { at = now + (t or 0.03), co = co })
		return coroutine.yield()
	end,
}

-- instancias
M.stats = { created = 0, destroyed = 0, emits = 0, emitted = 0, maxRate = 0, decals = 0, rocks = 0, landings = 0,
	emitMinZ = 0, emitMaxZ = 0, partMinZ = 0, partMaxZ = 0, raycasts = 0, cubes = 0, cubeGreen = 0, cubeMaxR = 0, clears = 0,
	lensMax = 0, beamMaxW = 0, beamsOff = 0, maxPSize = 0, flashMin = 1, cataRocks = 0, slabs = 0, gash = 0,
	bills = 0, billMax = 0, tips = 0 }
M.orbPath = {}
M.byClass = {}
local live = {}
-- lo que devuelve el rayo al tocar el suelo: una Part de pasto verde (no cuenta como instancia viva)
local groundFake = setmetatable({}, { __index = {
	IsA = function(_, c) return c == "BasePart" or c == "Part" end,
	FindFirstAncestorOfClass = function() return nil end,
} })
local function isDestroyed(o)
	while o do
		if rawget(o, "__destroyed") then return true end
		o = rawget(o, "__props").Parent
	end
	return false
end
M.isDestroyed = isDestroyed
-- posición en el mundo del portador de un emisor (Attachment dentro del contenedor, o Part con forma)
local function worldPosOf(c)
	if c == nil then return nil end
	if c.ClassName == "Attachment" then
		if c.WorldCFrame then return c.WorldCFrame.p end
		if c.WorldPosition then return c.WorldPosition end
		local par = c.Parent
		if par and par.CFrame and c.Position then return par.CFrame * c.Position end
		return c.Position
	end
	return c.CFrame and c.CFrame.p
end
local Inst = {}
function Inst.new(class)
	local props = { ClassName = class }
	local o = { __props = props }
	M.stats.created += 1
	M.byClass[class] = o
	if class == "Decal" then M.stats.decals += 1 end
	if class == "BillboardGui" then M.stats.bills += 1 end
	setmetatable(o, {
		__index = function(self, k)
			if k == "Emit" then return function(_, n)
				assert(props.Parent ~= nil, "Emit sin Parent")
				M.stats.emits += 1; M.stats.emitted += n
				-- dónde se emitió (el contenedor de prueba está en el origen y sin rotar)
				local pos = worldPosOf(props.Parent)
				M.stats.emitPos = M.stats.emitPos or {}
				if pos then table.insert(M.stats.emitPos, pos); table.insert(M.stats.emitNames, rawget(self, "__props").Name or "") end
				if pos then
					M.stats.emitMinZ = math.min(M.stats.emitMinZ, pos.Z)
					M.stats.emitMaxZ = math.max(M.stats.emitMaxZ, pos.Z)
				end
			end end
			if k == "Destroy" then return function() rawset(self, "__destroyed", true); props.Parent = nil; M.stats.destroyed += 1 end end
			if k == "IsA" then return function(_, c) return c == class or (c == "BasePart" and class == "Part") end end
			if k == "Clear" then return function() M.stats.clears += 1 end end
			if k == "FindFirstAncestorOfClass" or k == "FindFirstChildOfClass" then return function() return nil end end
			if k == "BulkMoveTo" then return function(_, ps, cs, mode)
				assert(#ps == #cs, "BulkMoveTo: listas de distinto largo")
				for i, part in ps do
					assert(part.Parent ~= nil, "BulkMoveTo de una Part destruida")
					part.CFrame = cs[i]
				end
			end end
			if k == "Raycast" then return function(_, origin, dirv, params)
				M.stats.raycasts += 1
				-- solo contra unas partes (Include): cajas giradas (el aura de contorno busca el modelo)
				if params and params.FilterType and params.FilterType.Name == "Include" then
					local best, bestPart = math.huge, nil
					for _, part in params.FilterDescendantsInstances or {} do
						local pcf, psz = part.CFrame, part.Size
						if pcf and psz then
							local o = pcf:PointToObjectSpace(origin)
							local d = pcf:PointToObjectSpace(origin + dirv) - o
							local t0, t1 = 0, 1
							local ok = true
							for _, ax in { "X", "Y", "Z" } do
								local h = psz[ax] / 2
								if math.abs(d[ax]) < 1e-12 then
									if math.abs(o[ax]) > h then ok = false break end
								else
									local a, b = (-h - o[ax]) / d[ax], (h - o[ax]) / d[ax]
									if a > b then a, b = b, a end
									t0, t1 = math.max(t0, a), math.min(t1, b)
									if t0 > t1 then ok = false break end
								end
							end
							if ok and t0 < best then best, bestPart = t0, part end
						end
					end
					if bestPart then
						return { Position = origin + dirv * best, Instance = bestPart, Material = M.Enum.Material.Plastic }
					end
					return nil
				end
				-- suelo plano en y = 0 (si el rayo lo cruza): el punto donde lo cruza
				if origin.Y >= 0 and origin.Y + dirv.Y <= 0 then
					groundFake.Color = groundFake.Color or M.Color3.fromRGB(90, 140, 70)
					local u = if dirv.Y < 0 then origin.Y / -dirv.Y else 0
					return { Position = v3(origin.X + dirv.X * u, 0, origin.Z + dirv.Z * u), Instance = groundFake,
						Material = M.Enum.Material.Grass }
				end
				return nil
			end end
			if k == "Position" and class == "Part" then return props.CFrame and props.CFrame.p end
			if k == "Parent" then
				-- como en Roblox: al destruir algo, todos sus descendientes quedan con Parent = nil
				if isDestroyed(self) then return nil end
				return props.Parent
			end
			return props[k]
		end,
		__newindex = function(self, k, v)
			if k == "Rate" then M.stats.maxRate = math.max(M.stats.maxRate, v) end
			if k == "BackgroundTransparency" then M.stats.flashMin = math.min(M.stats.flashMin, v) end
			if k == "Name" and v == "CataclysmRock" then M.stats.cataRocks += 1 end
			-- emisión continua: dónde está el emisor (una vez por emisor)
			if k == "Rate" and v > 0 and not rawget(self, "__streamed") then
				rawset(self, "__streamed", true)
				local pos = worldPosOf(props.Parent)
				if pos then table.insert(M.stats.streamPos, pos) end
			end
			if k == "Name" and v == "Rock" then M.stats.rocks += 1 end
			if k == "Name" and v == "Slab" then M.stats.slabs += 1 end
			if k == "Name" and v == "SlabTip" then M.stats.tips += 1 end
			-- la luna y los destellos gigantes (BillboardGui): su tamaño en studs
			if class == "BillboardGui" and k == "Size" then M.stats.billMax = math.max(M.stats.billMax, v[1]) end
			if k == "Name" and v == "GashSeam" then M.stats.gash += 1 end
			if k == "Name" and v == "Cube" then M.stats.cubes += 1 end
			if props.Name == "Cube" and k == "Color" and v.G > v.R and v.G > v.B then M.stats.cubeGreen += 1 end
			-- recorrido del agujero negro y tamaño de su lente
			if props.Name == "Orb" and k == "CFrame" then table.insert(M.orbPath, v.p) end
			if props.Name == "Lens" and k == "Size" then M.stats.lensMax = math.max(M.stats.lensMax, v.X) end
			-- el rayo: ancho máximo de sus Beams y hasta dónde llega su punta
			if class == "Beam" and k == "Width0" then M.stats.beamMaxW = math.max(M.stats.beamMaxW, v) end
			-- tamaño de partícula más grande (los golpes siguen el alto del rival)
			if class == "ParticleEmitter" and k == "Size" then
				for _, kp in v.Keypoints do M.stats.maxPSize = math.max(M.stats.maxPSize, kp.Value) end
			end
			if class == "Beam" and k == "Enabled" and v == false then M.stats.beamsOff += 1 end
			if props.Name == "BeamEnd" and k == "Position" then M.stats.beamEnd = v end
			if props.Name == "Cube" and k == "CFrame" then
				M.stats.cubeMaxR = math.max(M.stats.cubeMaxR, math.sqrt(v.p.X ^ 2 + v.p.Z ^ 2))
			end
			-- un Attachment colocado con .CFrame: su posición en el mundo según la Part que lo contiene
			if class == "Attachment" and k == "CFrame" then
				local par = props.Parent
				props.WorldPosition = if par and par.CFrame then (par.CFrame * v).p else v.p
			end
			if k == "CFrame" and type(v) == "table" and v.p then
				M.stats.partMinZ = math.min(M.stats.partMinZ, v.p.Z)
				M.stats.partMaxZ = math.max(M.stats.partMaxZ, v.p.Z)
			end
			props[k] = v
		end,
	})
	table.insert(live, o)
	return o
end
M.Instance = Inst
M.RaycastParams = { new = function() return {} end }
M.typeof = function(v)
	if getmetatable(v) == V then return "Vector3" end
	if getmetatable(v) == C then return "CFrame" end
	if type(v) == "table" and rawget(v, "__props") then return "Instance" end
	return typeof(v)
end
M.workspace = Inst.new("Workspace")
-- la cámara (perspectiva de 70° vertical, 800 × 600): la usa el aura de contorno para buscar el contorno del modelo
local Cam = {}
Cam.__index = Cam
local function camF(self) return (self.ViewportSize.Y / 2) / math.tan(math.rad(self.FieldOfView) / 2) end
function Cam:WorldToViewportPoint(p)
	local q = self.CFrame:PointToObjectSpace(p)
	local depth = -q.Z
	if depth <= 1e-6 then return v3(0, 0, depth), false end
	local f = camF(self)
	return v3(self.ViewportSize.X / 2 + f * q.X / depth, self.ViewportSize.Y / 2 - f * q.Y / depth, depth), true
end
function Cam:ViewportPointToRay(x, y)
	local f = camF(self)
	local d = v3((x - self.ViewportSize.X / 2) / f, -(y - self.ViewportSize.Y / 2) / f, -1).Unit
	return { Origin = self.CFrame.Position, Direction = self.CFrame:VectorToWorldSpace(d) }
end
local ws0 = M.workspace
M.setCamera = function(pos, target)
	ws0.CurrentCamera = setmetatable({ CFrame = if target then M.CFrame.lookAt(pos, target) else M.CFrame.new(pos.X, pos.Y, pos.Z),
		ViewportSize = M.Vector2.new(800, 600), FieldOfView = 70 }, Cam)
end
M.setCamera(v3(0, 10, 30))

local heart, renders = {}, {}
local RunService = {
	Heartbeat = { Connect = function(_, fn)
		local c = { fn = fn, on = true }
		c.Disconnect = function() c.on = false end
		table.insert(heart, c)
		return c
	end },
	IsClient = function() return true end,
	BindToRenderStep = function(_, name, prio, fn) renders[name] = { prio = prio, fn = fn } end,
	UnbindFromRenderStep = function(_, name) renders[name] = nil end,
}
M.lighting = Inst.new("Lighting")
M.playerGui = Inst.new("PlayerGui")
local services = {
	Lighting = M.lighting,
	Players = { LocalPlayer = { PlayerGui = M.playerGui } },
	Debris = { AddItem = function(_, item, t) M.task.delay(t, function() item:Destroy() end) end },
	TweenService = { Create = function() return { Play = function() end } end },
	RunService = RunService,
}
M.game = { GetService = function(_, n) return assert(services[n], "servicio no simulado: " .. n) end }

function M.step(dt)
	now += dt
	table.sort(delays, function(a, b) return a.at < b.at end)
	while delays[1] and delays[1].at <= now do
		local d = table.remove(delays, 1)
		d.f(table.unpack(d.args))
	end
	local i = 1
	while i <= #waiting do
		local w = waiting[i]
		if w.at <= now then
			table.remove(waiting, i)
			local ok, err = coroutine.resume(w.co)
			if not ok then error(err) end
		else
			i += 1
		end
	end
	for _, c in heart do if c.on then c.fn(dt) end end
	-- como en Roblox: en orden de prioridad (First antes que Camera)
	local order = {}
	for _, r in renders do table.insert(order, r) end
	table.sort(order, function(a, b) return a.prio < b.prio end)
	for _, r in order do r.fn() end
end
function M.pending()
	local h = 0
	for _, c in heart do if c.on then h += 1 end end
	local r = 0
	for _ in renders do r += 1 end
	return #delays, #waiting, h, r
end
function M.reset()
	now = 0; delays = {}; waiting = {}; heart = {}; renders = {}; live = {}
	for k in M.stats do M.stats[k] = 0 end
	M.stats.emitPos = {}
	M.stats.emitNames = {}
	M.stats.streamPos = {}
	M.stats.beamEnd = nil
	M.stats.flashMin = 1
	M.byClass = {}
	M.orbPath = {}
end
-- cuántas instancias vivas tienen ese nombre
function M.liveNamed(name)
	local n = 0
	for _, o in live do
		if rawget(o, "__props").Name == name and not isDestroyed(o) then n += 1 end
	end
	return n
end
function M.liveCount()
	local n = 0
	for _, o in live do
		if o.ClassName ~= "Workspace" and not isDestroyed(o) then n += 1 end
	end
	return n
end
return M
