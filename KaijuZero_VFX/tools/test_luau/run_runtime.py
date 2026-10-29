"""Ejecuta KaijuFireVFX contra el Roblox simulado. uso: python run_runtime.py /ruta/luau"""
import os, subprocess, sys, tempfile
d = os.path.dirname(os.path.abspath(__file__))
luau = sys.argv[1]
mock = open(os.path.join(d, "runtime_mock.luau")).read()
mod = open(os.path.join(d, "..", "..", "roblox", "KaijuFireVFX.lua")).read().replace("--!nonstrict", "")
astral = open(os.path.join(d, "..", "..", "..", "AstralColossus_VFX", "roblox", "AstralColossusVFX.lua")).read() \
    .replace("--!nonstrict", "")
omni = open(os.path.join(d, "..", "..", "..", "Omnivora_VFX", "roblox", "OmnivoraVFX.lua")).read() \
    .replace("--!nonstrict", "")
moon = open(os.path.join(d, "..", "..", "..", "Moonfang_VFX", "roblox", "MoonfangVFX.lua")).read() \
    .replace("--!nonstrict", "")
peb = open(os.path.join(d, "..", "..", "..", "Pebledon_VFX", "roblox", "PebledonVFX.lua")).read() \
    .replace("--!nonstrict", "")
G = ["Vector3", "Vector2", "CFrame", "Color3", "NumberRange", "NumberSequence", "NumberSequenceKeypoint",
     "ColorSequence", "ColorSequenceKeypoint", "TweenInfo", "Random", "Enum", "Instance", "workspace", "game", "task", "time",
     "typeof", "RaycastParams", "UDim2"]
test = r'''
local function run(name, call, seconds, len)
	R.reset()
	R.workspace = R.Instance.new("Workspace")
	local holder = call()
	local t, dt = 0, 1 / 60
	local peakRate = 0
	while t < seconds do
		R.step(dt)
		t += dt
	end
	local dl, wt, hb, rs = R.pending()
	local leftovers = R.liveCount()
	print(("%-17s emits=%d particulas=%d rocas=%d decals=%d maxRate=%.0f | pendientes: delays=%d waits=%d heartbeat=%d render=%d | vivos=%d holderDestruido=%s"):format(
		name, R.stats.emits, R.stats.emitted, R.stats.rocks, R.stats.decals, R.stats.maxRate, dl, wt, hb, rs, leftovers, tostring(R.isDestroyed(holder))))
	assert(R.isDestroyed(holder), name .. ": el contenedor no se destruyó")
	assert(hb == 0, name .. ": quedaron conexiones Heartbeat activas")
	assert(rs == 0, name .. ": quedó la sacudida de cámara enlazada")
	if len then
		-- todo lo de la línea debe repartirse de 0 a -largo (adelante = -Z)
		local st = R.stats
		print(("%-17s   línea: emisiones z=[%.1f, %.1f]  partes z=[%.1f, %.1f]  (largo %d)"):format(
			"", st.emitMinZ, st.emitMaxZ, st.partMinZ, st.partMaxZ, len))
		assert(st.emitMinZ < -0.95 * len and st.emitMinZ > -1.05 * len - 80, name .. ": las emisiones no llegan al final de la línea")  -- (las rocas pueden caer ~75 studs más allá)
		assert(st.partMinZ < -0.95 * len and st.partMinZ > -1.05 * len - 80, name .. ": decals/rocas no llegan al final de la línea")
	end
end
-- efectos sobre rocas: cada roca debe recibir su explosión y el remate debe ir en la más lejana
local function runRocks(name, call, seconds, pts)
	run(name, call, seconds)
	local near = {}
	for i, p in pts do
		near[i] = 0
		for _, e in R.stats.emitPos do
			local dx, dz = e.X - p.X, e.Z - p.Z
			if dx * dx + dz * dz < 16 then near[i] += 1 end
		end
		assert(near[i] > 20, name .. ": la roca " .. i .. " casi no recibió emisiones")
	end
	local maxOther = 0
	for i = 1, #pts - 1 do maxOther = math.max(maxOther, near[i]) end
	print(("%-17s   rocas: emisiones cerca de cada roca = %s (raycasts=%d)"):format("", table.concat(near, ", "), R.stats.raycasts))
	assert(near[#pts] > maxOther, name .. ": el remate no quedó en la última roca")
end
local VFX = loadModule()
VFX.Parent = R.workspace
run("GiantExplosion", function() return VFX.GiantExplosion(R.CFrame.new(10, 0, 5), 1, 1) end, 7.6)
run("Giant x2.5", function() return VFX.GiantExplosion(R.CFrame.new(0, 0, 0), 2.5) end, 7.6)
run("Giant Ignition", function() return VFX.GiantExplosionIgnition(R.CFrame.new(0, 0, 0), 1, 1) end, 7.6)
run("Giant Classic", function() return VFX.GiantExplosionClassic(R.CFrame.new(0, 0, 0), 1, 1) end, 7.6)
run("Explosion", function() return VFX.Explosion(R.CFrame.new(0, 2.5, 0), 1) end, 2)
run("ExplosionAnime", function() return VFX.ExplosionAnime(R.CFrame.new(0, 2.5, 0), 1) end, 2)
run("FireLine", function() return VFX.FireLine(R.CFrame.new(0, 0, 0), 120, 1) end, 3.6, 120)
-- RAYOS que se apuntan (ULTIMATE de Kaiju Zero y rayo cósmico de Omnívora): sin nada delante llegan a su largo
-- máximo; contra el suelo se acortan; siguen la dirección, el objetivo y el origen que les des; al barrer el suelo
-- dejan marcas; Stop() los corta antes y todo se limpia
local function stepFor(sec)
	local t = 0
	while t < sec - 1e-9 do
		R.step(1 / 60)
		t += 1 / 60
	end
end
local function runSteer(name, mod, fnName, maxLen)
	R.reset()
	local A = R.Vector3.new(0, 20, 0)
	local beam = mod[fnName](A, R.Vector3.new(0, 20, -50), 1, 1, {})
	stepFor(0.6)
	assert(math.abs(beam.Length - maxLen) < 0.5, name .. ": sin nada delante no llegó a su largo máximo")
	assert(beam.HitPosition == nil and beam.HitInstance == nil, name .. ": pegó sin tener nada delante")
	-- apunta al suelo 40 studs adelante: se corta donde el rayo cruza el suelo
	beam:AimAt(R.Vector3.new(0, 0, -40))
	stepFor(0.2)
	local onGround = beam.Length
	assert(math.abs(onGround - math.sqrt(40 ^ 2 + 20 ^ 2)) < 0.5, name .. ": no se cortó en el suelo")
	assert(beam.HitPosition and math.abs(beam.HitPosition.Y) < 0.01 and beam.HitInstance, name .. ": no marca dónde pega")
	local decals0 = R.stats.decals
	-- barre el suelo acercándose: se acorta y va dejando marcas
	for i = 1, 30 do
		beam:AimAt(R.Vector3.new(0, 0, -40 + i))
		stepFor(1 / 60 * 2)
	end
	assert(beam.Length < onGround - 10, name .. ": no se acortó al barrer el suelo")
	assert(R.stats.decals - decals0 >= 4, name .. ": no dejó marcas al barrer el suelo")
	-- dirección hacia arriba: otra vez el largo máximo, sin impacto
	beam:SetDirection(R.Vector3.new(0, 1, -1))
	stepFor(0.2)
	assert(math.abs(beam.Length - maxLen) < 0.5 and beam.HitPosition == nil, name .. ": hacia el cielo no volvió al máximo")
	-- sigue a un objetivo que se mueve y a un origen nuevo
	local target = R.Instance.new("Model")
	local tp = R.Vector3.new(60, 20, 0)
	target.GetPivot = function() return R.CFrame.new(tp.X, tp.Y, tp.Z) end
	beam:AimAt(target)
	beam:SetOrigin(R.CFrame.new(0, 25, 10))
	stepFor(0.1)
	tp = R.Vector3.new(0, 25, -70)
	stepFor(0.1)
	local look = beam.Holder.CFrame.LookVector
	assert(look.Z < -0.99 and math.abs(beam.Holder.Position.Y - 25) < 0.01, name .. ": no siguió al objetivo ni al origen")
	-- un objetivo más cerca que el largo máximo, en el aire: el rayo pasa de largo hasta su máximo
	assert(math.abs(beam.Length - maxLen) < 0.5, name .. ": se cortó en el aire")
	-- se corta antes de tiempo y todo se limpia
	beam:Stop()
	stepFor(0.45)
	assert(not beam.Active, name .. ": no se apagó al cortarlo")
	stepFor(5)   -- lo último (las marcas grandes del suelo) dura unos 4 s después del corte
	local dl, wt, hb, rs = R.pending()
	print(("%-17s   rayo: máx %.0f | en el suelo %.1f | marcas %d | cortado antes: destruido=%s heartbeat=%d render=%d"):format(
		name, maxLen, onGround, R.stats.decals, tostring(R.isDestroyed(beam.Holder)), hb, rs))
	assert(R.isDestroyed(beam.Holder), name .. ": el contenedor no se destruyó al cortarlo")
	assert(hb == 0 and rs == 0, name .. ": quedaron conexiones o sacudidas activas")
end
runSteer("UltimateBeam", VFX, "UltimateBeam", 186)
-- sin cortarlo: dura sus 3 s y se limpia solo
run("UltimateBeam 3s", function()
	return VFX.UltimateBeam(R.CFrame.new(0, 30, 0), R.Vector3.new(0, -10, -60), 1.5, 0).Holder
end, 8)
assert(VFX.UltimateBeamStart > 0.3 and VFX.UltimateBeamStop >= VFX.UltimateBeamStart + 2.85, "tiempos del rayo")

-- GOLPES en el rival: salen delante del rival (hacia la cámara, que en el simulado está en 0, 10, 30), su tamaño
-- sigue el alto del rival y se limpian
local camPos = R.Vector3.new(0, 10, 30)
local function front(c, lift)
	return c + (camPos - c).Unit * lift
end
local function runHit(name, call, seconds, P, k)
	run(name, call, seconds)
	local st = R.stats
	local far = 0
	for _, p in st.emitPos do
		if (p - P).Magnitude > 14 * k then far += 1 end
	end
	for _, p in st.streamPos do
		if (p - P).Magnitude > 14 * k then far += 1 end
	end
	print(("%-17s   golpe: %d ráfagas, %d continuos, lejos del golpe %d | partícula más grande %.1f studs"):format(
		"", #st.emitPos, #st.streamPos, far, st.maxPSize))
	assert(#st.emitPos >= 6, name .. ": casi no hubo golpe")
	assert(far == 0, name .. ": hay emisiones lejos del golpe")
end
local victim = R.Instance.new("Model")
victim.GetPivot = function() return R.CFrame.new(0, 11, 0) end
victim.GetExtentsSize = function() return R.Vector3.new(12, 22, 12) end
runHit("SlashHit", function() return VFX.SlashHit(victim, 1, 1) end, 1.5, front(R.Vector3.new(0, 11, 0), 3), 1)
local size1 = R.stats.maxPSize
local giant = R.Instance.new("Model")
giant.GetPivot = function() return R.CFrame.new(0, 22, 0) end
giant.GetExtentsSize = function() return R.Vector3.new(24, 44, 24) end
runHit("SlashHit gigante", function() return VFX.SlashHit(giant, 1, 1, 30) end, 1.5, front(R.Vector3.new(0, 22, 0), 6), 2)
assert(math.abs(R.stats.maxPSize / size1 - 2) < 0.05, "el golpe no se adaptó al alto del rival")
local wall = R.Instance.new("Part")
wall.Size = R.Vector3.new(10, 22, 10)
wall.CFrame = R.CFrame.new(20, 11, -10)
runHit("BurningSlash Part", function() return VFX.BurningSlashHit(wall, 1, 0, -45) end, 2.5,
	front(R.Vector3.new(20, 11, -10), 3), 1)
runHit("BiteHit Vector3", function() return VFX.BiteHit(R.Vector3.new(5, 8, 0), 1, 1) end, 1.5,
	front(R.Vector3.new(5, 8, 0), 3), 1)
VFX.HitAutoSize = false
runHit("BiteHit x1.5", function() return VFX.BiteHit(giant, 1.5, 1) end, 1.5, front(R.Vector3.new(0, 22, 0), 4.5), 1.5)
VFX.HitAutoSize = true
assert(VFX.SlashHitImpact == 0.05 and VFX.BiteHitImpact == 0.14, "tiempos de los golpes")

-- rocas en línea recta (desordenadas a propósito: el módulo las ordena)
local line = {}
for i = 0, 6 do table.insert(line, R.Vector3.new(8 + 14 * i, 0, 0.5 * i)) end
local shuffled = { line[4], line[1], line[7], line[2], line[6], line[3], line[5] }
runRocks("H3", function() return VFX.H3_Detonation(shuffled, 1, 1) end, 4, line)
-- rocas como Parts semienterradas: el suelo se busca con un rayo hacia abajo
local parts, ground = {}, {}
for i = 0, 4 do
	local p = R.Instance.new("Part")
	p.Size = R.Vector3.new(4, 3, 4)
	p.CFrame = R.CFrame.new(-10 * i, 1, 30 + 10 * i)
	table.insert(parts, p)
	table.insert(ground, R.Vector3.new(-10 * i, 0, 30 + 10 * i))
end
runRocks("H3 Parts x1.5", function() return VFX.H3_Detonation(parts, 1.5, 1) end, 4.5, ground)
runRocks("H3 Ignition", function() return VFX.H3_DetonationIgnition(line, 1, 1) end, 6, line)
run("H3 una roca", function() return VFX.H3_Detonation({ R.Vector3.new(3, 0, 3) }, 1) end, 4.5)
-- rocas hechas con Models (varias piezas): se usa el pivote y el tamaño del conjunto
local models, mground = {}, {}
for i = 0, 3 do
	local m = R.Instance.new("Model")
	local c = R.CFrame.new(12 * i, 2, -20)
	m.GetPivot = function() return c end
	m.GetExtentsSize = function() return R.Vector3.new(5, 4, 5) end
	table.insert(models, m)
	table.insert(mground, R.Vector3.new(12 * i, 0, -20))
end
runRocks("H3 Models", function() return VFX.H3_DetonationIgnition(models, 1, 0) end, 6, mground)
assert(VFX.H3_Detonation({}, 1) == nil, "sin rocas no debe crear nada")

-- ASTRAL COLOSSUS: todo lo del triángulo debe caer dentro del triángulo (con cualquier largo/ángulo)
local AST = loadAstral()
AST.Parent = R.workspace
local function runCone(name, call, seconds, len, ang)
	run(name, call, seconds)
	local tanH = math.tan(math.rad(ang / 2))
	local fuera, n = 0, 0
	for i, p in R.stats.emitPos do
		-- el polvo donde ATERRIZAN las rocas puede quedar fuera: las rocas salen volando
		if string.sub(R.stats.emitNames[i], 1, 8) == "RockLand" then continue end
		n += 1
		local fwd = -p.Z
		if fwd > len * 1.02 + 0.5 or math.abs(p.X) > math.max(fwd, 0) * tanH + 0.6 then fuera += 1 end
	end
	print(("%-17s   triángulo: %d emisiones, fuera del triángulo: %d (largo %d, ángulo %d)"):format("", n, fuera, len, ang))
	assert(n > 100, name .. ": casi no emitió")
	assert(fuera == 0, name .. ": hay emisiones fuera del triángulo")
end
runCone("AstralClash", function() return AST.AstralClash(R.CFrame.new(0, 0, 0), nil, nil, 1, 1) end, 4.5, 70, 55)
runCone("Astral 100/35 x1", function() return AST.AstralClash(R.CFrame.new(0, 0, 0), 100, 35, 1, 0) end, 4.5, 100, 35)
runCone("Astral 60/90 x1.5", function() return AST.AstralClash(R.CFrame.new(0, 0, 0), 60, 90, 1.5, 2) end, 4.5, 60, 90)

-- OMNÍVORA: todo lo de la zona cae dentro del cilindro (con cualquier radio/altura); los cubos salen del suelo,
-- toman su color y salen despedidos fuera de la zona
local OMNI = loadOmnivora()
OMNI.Parent = R.workspace
local function runZone(name, call, seconds, rad, hgt)
	run(name, call, seconds)
	local fuera, n = 0, 0
	for i, p in R.stats.emitPos do
		if R.stats.emitNames[i] == "CubeDissolve" then continue end
		n += 1
		local r = math.sqrt(p.X * p.X + p.Z * p.Z)
		if r > rad * 1.35 + 0.6 or p.Y < -0.1 or p.Y > hgt * 1.02 + 1 then fuera += 1 end
	end
	local st = R.stats
	print(("%-17s   zona: %d emisiones, fuera del cilindro: %d (radio %d, altura %d) | cubos=%d (color del suelo: %d) más lejano a %.0f studs | Clear=%d"):format(
		"", n, fuera, rad, hgt, st.cubes, st.cubeGreen, st.cubeMaxR, st.clears))
	assert(n > 300, name .. ": casi no emitió")
	assert(fuera == 0, name .. ": hay emisiones fuera del cilindro")
	assert(st.cubes > 40, name .. ": casi no hubo cubos")
	assert(st.cubeGreen > st.cubes * 0.5, name .. ": los cubos no tomaron el color del suelo")
	assert(st.cubeMaxR > rad * 1.3, name .. ": los cubos no salieron despedidos")
	assert(st.clears > 0, name .. ": la galaxia interna no se borró en el colapso")
end
runZone("CosmicPillar", function() return OMNI.CosmicPillar(R.CFrame.new(0, 0, 0), nil, nil, 1, 1) end, 5, 18, 120)
runZone("Pillar 30/80", function() return OMNI.CosmicPillar(R.CFrame.new(0, 0, 0), 30, 80, 1, 0) end, 5, 30, 80)
runZone("Pillar 10/200 x1.5", function() return OMNI.CosmicPillar(R.CFrame.new(0, 0, 0), 10, 200, 1.5, 2) end, 5, 10, 200)
-- agujero negro: nace en la boca, llega sobre el centro de los enemigos y detona ahí
local function runOrb(name, call, seconds, cx, cz, rad)
	run(name, call, seconds)
	local path, st = R.orbPath, R.stats
	assert(#path > 20, name .. ": el agujero no se movió")
	local a, b = path[1], path[#path]
	print(("%-17s   agujero: de (%.0f, %.0f, %.0f) a (%.0f, %.0f, %.0f) | lente hasta %.0f studs | cubos=%d (color del suelo: %d) más lejano a %.0f studs | Clear=%d"):format(
		"", a.X, a.Y, a.Z, b.X, b.Y, b.Z, st.lensMax, st.cubes, st.cubeGreen, st.cubeMaxR, st.clears))
	assert(math.abs(b.X - cx) < 0.5 and math.abs(b.Z - cz) < 0.5, name .. ": no llegó sobre el centro de los enemigos")
	assert(b.Y > 4, name .. ": llegó enterrado")
	assert(st.lensMax > 10, name .. ": la lente no creció con el agujero")
	assert(st.cubes > 40, name .. ": casi no hubo cubos")
	assert(st.cubeGreen > st.cubes * 0.5, name .. ": los cubos no tomaron el color del suelo")
	assert(st.clears > 0, name .. ": el agujero no se borró al detonar")
	if rad then
		assert(st.cubeMaxR > rad * 1.3, name .. ": los cubos no salieron despedidos")
	end
end
runOrb("BlackHole x2", function()
	return OMNI.BlackHole(R.Vector3.new(-90, 16, 0), { R.Vector3.new(0, 0, -12), R.Vector3.new(0, 0, 12) }, 1, 1)
end, 6, 0, 0, 28)
local enemy1 = R.Instance.new("Part")
enemy1.CFrame = R.CFrame.new(10, 5, -15)
local enemy2 = R.Instance.new("Model")
enemy2.GetPivot = function() return R.CFrame.new(10, 5, 15) end
runOrb("BlackHole Parts1.5", function()
	return OMNI.BlackHole(R.CFrame.new(-60, 20, 30), { enemy1, enemy2 }, 1.5, 0)
end, 6, 10, 0)
runOrb("BlackHole 1 enemy", function()
	return OMNI.BlackHole(R.CFrame.new(0, 14, 80), R.Vector3.new(0, 0, 0), 1, 2)
end, 6, 0, 0, 28)
runOrb("BlackHole sin obj", function()
	return OMNI.BlackHole(R.CFrame.lookAt(R.Vector3.new(0, 14, 140), R.Vector3.new(0, 14, 0)), {}, 1, 1)
end, 6, 0, 0, 28)
runSteer("CosmicBeam", OMNI, "CosmicBeam", 124)
run("CosmicBeam 3s", function()
	return OMNI.CosmicBeam(R.Vector3.new(0, 30, 0), R.Vector3.new(0, -10, -60), 1, 1, {}).Holder
end, 8)
assert(OMNI.CosmicBeamStart > 0.3 and OMNI.CosmicBeamStop >= OMNI.CosmicBeamStart + 2.85, "tiempos del rayo cósmico")
-- AURAS: se adaptan al modelo (sus partes, su alto), lo siguen, tienen oleadas y se limpian al apagarlas
local function auraModel(height)
	local m = R.Instance.new("Model")
	m.Name = "Kaiju"
	m.Parent = R.workspace
	local k = height / 22
	local function part(name, size, pos, tr)
		local p = R.Instance.new("Part")
		p.Name = name
		p.Size = size * k
		p.CFrame = R.CFrame.new(pos.X * k, pos.Y * k, pos.Z * k)
		p.Transparency = tr or 0
		p.Parent = m
		return p
	end
	local list = {
		part("Torso", R.Vector3.new(6, 9, 5), R.Vector3.new(0, 8, 0)),
		part("Head", R.Vector3.new(4, 3, 3), R.Vector3.new(2, 19, 0)),
		part("LegL", R.Vector3.new(3, 6, 2.5), R.Vector3.new(-1, 3, 2)),
		part("LegR", R.Vector3.new(3, 6, 2.5), R.Vector3.new(-1, 3, -2)),
		part("Tail", R.Vector3.new(8, 2.5, 2.5), R.Vector3.new(-7, 2, 0)),
		part("HumanoidRootPart", R.Vector3.new(2, 2, 1), R.Vector3.new(0, 60, 0), 1),
		part("Hitbox", R.Vector3.new(10, 22, 10), R.Vector3.new(0, 80, 0), 1),
	}
	local center = R.Vector3.new(0, 11 * k, 0)
	m.GetBoundingBox = function() return R.CFrame.new(center.X, center.Y, center.Z), R.Vector3.new(16, 22, 6) * k end
	m.GetDescendants = function() return list end
	return m, function(c) center = c end
end
local function runAura(name, mod, fnName)
	R.reset()
	R.workspace = R.Instance.new("Workspace")
	mod.Parent = R.workspace
	local model, moveTo = auraModel(44)
	local aura = mod[fnName](model, 1, nil, 1)
	stepFor(1.0)
	-- los emisores van en las partes visibles del cuerpo (no en la raíz ni en la caja de golpes invisibles)
	local onBody, onHidden = 0, 0
	for _, p in R.stats.streamPos do
		if p.Y > 50 then onHidden += 1 elseif p.Y > 0.5 then onBody += 1 end
	end
	assert(onBody >= 5, name .. ": no salió de las partes del cuerpo")
	assert(onHidden == 0, name .. ": salió de una parte invisible")
	-- el tamaño sigue al alto del modelo (44 studs = el doble)
	assert(R.stats.maxPSize > 45 and R.stats.maxPSize < 55, name .. ": el tamaño no siguió al alto del modelo") -- el mayor: 25 studs a 22 de alto
	-- oleada
	local emits0 = R.stats.emits
	stepFor(2.0)
	assert(R.stats.emits > emits0, name .. ": no hubo oleada")
	-- lo sigue si se mueve
	moveTo(R.Vector3.new(30, 22, -12))
	stepFor(0.1)
	assert((aura.Holder.CFrame.p - R.Vector3.new(30, 22, -12)).Magnitude < 0.01, name .. ": no siguió al modelo")
	aura:SetIntensity(1.5)
	assert(aura.Active and aura.Intensity == 1.5, name .. ": intensidad")
	aura:Stop()
	stepFor(0.8)
	assert(not aura.Active, name .. ": no se apagó")
	stepFor(1.6)
	local dl, wt, hb, rs = R.pending()
	print(("%-17s   aura: emisores en el cuerpo %d | tamaño máx %.1f | emits %d | apagada: destruida=%s heartbeat=%d"):format(
		name, onBody, R.stats.maxPSize, R.stats.emits, tostring(R.isDestroyed(aura.Holder)), hb))
	assert(R.isDestroyed(aura.Holder) and hb == 0, name .. ": no se limpió al apagarla")
	-- con duración: se apaga sola
	R.reset()
	local model2 = auraModel(22)
	local a2 = mod[fnName](model2, 1, 1.5)
	stepFor(4.0)
	assert(R.isDestroyed(a2.Holder) and select(3, R.pending()) == 0, name .. ": con duración no se limpió sola")
	-- si el modelo desaparece, el aura también
	R.reset()
	local model3 = auraModel(22)
	local a3 = mod[fnName](model3)
	stepFor(0.5)
	model3:Destroy()
	stepFor(0.1)
	assert(R.isDestroyed(a3.Holder) and select(3, R.pending()) == 0, name .. ": quedó viva sin el modelo")
end
-- las sacudidas nunca corren la cámara: con una cámara fija (que nadie vuelve a poner en su sitio) queda igual
do
	R.reset()
	local cam = workspace.CurrentCamera
	local base = cam.CFrame
	VFX.Shake(2, 0.5)
	VFX.ShakeRamp(0.2, 1.5, 0.8, 2)
	OMNI.Shake(1, 0.3)
	local moved = false
	for _ = 1, 30 do
		R.step(1 / 60)
		if not (cam.CFrame == base) then moved = true end
	end
	stepFor(1.0)
	local _, _, _, rs = R.pending()
	print(("%-17s   la cámara se movió durante la sacudida: %s | al terminar quedó en su sitio: %s | render=%d"):format(
		"Sacudida", tostring(moved), tostring(cam.CFrame == base), rs))
	assert(moved, "la sacudida no movió la cámara")
	assert(cam.CFrame == base and rs == 0, "la cámara quedó corrida después de la sacudida")
end
runAura("CrimsonAura", VFX, "CrimsonAura")
runAura("CosmicAura", OMNI, "CosmicAura")
-- ULTIMATE de Omnívora: la secuencia completa con tres víctimas (el efecto las mueve), sin víctimas y cortada antes
local function cataDummy(x, z)
	local m = R.Instance.new("Model")
	local pivot = R.CFrame.new(x, 30, z)
	m.GetPivot = function() return pivot end
	m.PivotTo = function(_, cf) pivot = cf end
	m.GetBoundingBox = function() return pivot, R.Vector3.new(30, 60, 30) end
	m.Parent = R.workspace
	return m
end
do
	R.reset()
	OMNI.Parent = R.workspace
	local v1, v2, v3 = cataDummy(250, 0), cataDummy(-200, 180), cataDummy(60, -335)
	local events = {}
	local ult = OMNI.GravitationalCataclysm(R.Vector3.new(0, 10, 0), { v1, v2, v3 }, {
		MoveVictims = true,
		OnEvent = function(name) table.insert(events, name) end,
	})
	local Tm = OMNI.GravitationalCataclysmTimes
	local function stepTo(t1)
		while ult.Time < t1 - 1e-6 and ult.Active do R.step(1 / 30) end
	end
	stepTo(5.0)
	local _, _, hbMid, rsMid = R.pending()
	assert(R.stats.cataRocks > 40, "ULTIMATE: casi no se levantaron rocas")
	assert(hbMid >= 1 and rsMid == 2, "ULTIMATE: falta el bucle o la sacudida")
	stepTo(13.7)
	-- atrapadas junto a la singularidad
	for i, v in { v1, v2, v3 } do
		local d = (v:GetPivot().Position - ult.Singularity).Magnitude
		assert(d < 2 * 150 * 1.75 + 60, ("ULTIMATE: la víctima %d no llegó a la singularidad (a %.0f studs)"):format(i, d))
	end
	local rocksMid = R.stats.cataRocks
	-- la masa crítica empieza en el vacío: la singularidad ya se tragó todas las rocas
	stepTo(Tm.CriticalMass + 0.35)
	local floating = R.liveNamed("CataclysmRock")
	assert(floating == 0, ("ULTIMATE: quedan %d rocas flotando en la masa crítica"):format(floating))
	stepTo(Tm.Detonation + 1.2)
	assert(R.stats.flashMin < 0.05, "ULTIMATE: no hubo destello blanco")
	-- cada víctima quedó en su punto de impacto
	for i, v in { v1, v2, v3 } do
		local land = ult:GetImpactPoint(v)
		local p = v:GetPivot().Position
		assert(math.abs(p.X - land.X) < 0.01 and math.abs(p.Z - land.Z) < 0.01, "ULTIMATE: la víctima " .. i .. " no cayó en su punto")
		assert(p.Y < 40 and p.Y > 10, "ULTIMATE: la víctima " .. i .. " no quedó en el suelo")
	end
	local land1 = ult:GetImpactPoint(v1)
	assert(math.abs(land1.X - 250) < 0.5 and math.abs(land1.Z) < 0.5, "ULTIMATE: el punto de impacto no es donde estaba")
	local plan = OMNI.GravitationalCataclysmPlan(R.Vector3.new(0, 10, 0), { v1, v2, v3 })
	local times = plan:GetVictimTimes(v2)
	assert(times and times.Impact > Tm.Detonation and times.Lift < times.Held, "ULTIMATE: tiempos del plan")
	stepTo(30)
	stepFor(0.5)   -- la sacudida se desengancha en el cuadro siguiente al terminar
	local dl, wt, hb, rs = R.pending()
	local seq = table.concat(events, ",")
	local function count(name) local n = 0 for _, e in events do if e == name then n += 1 end end return n end
	print(("%-17s rocas creadas %d (a los 13.7 s: %d) | eventos: fases=%d suben=%d impactos=%d | destello %.2f | limpio=%s heartbeat=%d render=%d"):format(
		"Cataclysm", R.stats.cataRocks, rocksMid, count("Phase"), count("VictimLift"), count("VictimImpact"), R.stats.flashMin,
		tostring(R.isDestroyed(ult.Holder)), hb, rs))
	assert(count("Phase") == 8 and count("VictimLift") == 3 and count("VictimLaunch") == 3 and count("VictimImpact") == 3,
		"ULTIMATE: faltan eventos: " .. seq)
	assert(events[#events] == "Finished", "ULTIMATE: el último evento no es Finished")
	assert(seq:find("VictimLift") < seq:find("Detonation") and seq:find("Detonation") < seq:find("VictimImpact"),
		"ULTIMATE: los eventos no van en orden: " .. seq)
	assert(not ult.Active and R.isDestroyed(ult.Holder) and hb == 0 and rs == 0, "ULTIMATE: no se limpió")
	assert(R.isDestroyed(R.byClass.ColorCorrectionEffect) and R.isDestroyed(R.byClass.ScreenGui),
		"ULTIMATE: quedó la corrección de color o el destello")
	-- empezar en una fase (para revisarla) y cortarla antes
	R.reset()
	local u2 = OMNI.GravitationalCataclysm(R.Vector3.new(0, 10, 0), {}, { StartTime = 11 })
	assert(math.abs(u2.Time - 11) < 0.05 and u2.Phase == "Consumo total", "ULTIMATE: StartTime no empezó en la fase")
	R.step(1 / 30)
	R.step(1 / 30)
	u2:Stop()
	stepFor(1.5)
	local _, _, hb2, rs2 = R.pending()
	assert(R.isDestroyed(u2.Holder) and hb2 == 0 and rs2 == 0, "ULTIMATE: Stop() no limpió")
	print(("%-17s   empezar en una fase: t=%.2f (%s) | cortada antes: limpio"):format("", u2.Time, u2.Phase))
end
-- MOONFANG: todo el kit (golpes, bloqueo, medialuna, lluvia de colmillos, aullido, eclipse y las dos auras)
local MOON = loadMoonfang()
runHit("MoonBite", function() return MOON.MoonBite(victim, 1, 1) end, 2.5, front(R.Vector3.new(0, 11, 0), 3), 1)
runHit("MoonBiteFinisher", function() return MOON.MoonBiteFinisher(victim, 1, 1) end, 3,
	front(R.Vector3.new(0, 11, 0), 3), 1)
runHit("MoonFang", function() return MOON.MoonFang(victim, 1, 1) end, 2, front(R.Vector3.new(0, 11, 0), 3), 1)
run("MoonGuardHit", function() return MOON.MoonGuardHit(victim, 1, 1) end, 1.5)
run("CrescentWave", function()
	return MOON.CrescentWave(R.CFrame.lookAt(R.Vector3.new(0, 0, 0), R.Vector3.new(0, 0, -1)), nil, 1, 1)
end, 6, 130)
assert(R.stats.rocks >= 20, "CrescentWave: casi no salieron rocas del corte")
assert(R.stats.beamMaxW > 4, "CrescentWave: no se armó la hoja (Beams)")
assert(R.stats.slabs >= 60, "CrescentWave: casi no saltaron losas del suelo")
assert(R.stats.gash >= 8, "CrescentWave: no se abrió el corte en el suelo")
assert(R.stats.maxRate > 0, "CrescentWave: la hoja no soltó su estela")
for _, nm in { "Slab", "GashSeam", "GashFrost", "BladeCarrier" } do
	assert(R.liveNamed(nm) == 0, "CrescentWave: quedaron piezas " .. nm)
end
print(("%-17s   hoja: losas=%d tramos del corte=%d rocas=%d raycasts=%d"):format("", R.stats.slabs, R.stats.gash,
	R.stats.rocks, R.stats.raycasts))
run("IceWave", function()
	return MOON.IceWave(R.CFrame.lookAt(R.Vector3.new(0, 0, 0), R.Vector3.new(0, 0, -1)), nil, nil, 1, 1)
end, 6, 110)
assert(R.stats.slabs >= 60, "IceWave: casi no brotaron bloques de hielo ni losas")
assert(R.stats.rocks >= 10, "IceWave: casi no salieron rocas")
assert(R.stats.maxRate > 10, "IceWave: el frente no soltó su humo")
assert(R.liveNamed("Slab") == 0, "IceWave: quedaron bloques en el suelo")
print(("%-17s   ola: bloques y losas=%d rocas=%d raycasts=%d"):format("", R.stats.slabs, R.stats.rocks, R.stats.raycasts))
run("FrostRoar", function() return MOON.FrostRoar(R.CFrame.new(0, 14, 0), 1, 1) end, 5)
assert(MOON.FrostRoarImpact == 0.28 and MOON.FrostRoarRadius == 30, "FrostRoar: falta el momento o el radio del empujón")
do -- las capas del suelo van al piso bajo él (la cabeza está a 14 studs); la niebla y las púas, en anillo
	local mist, spikes = 0, 0
	for i, p in R.stats.emitPos do
		local nm = R.stats.emitNames[i]
		if nm == "FloorMist" and p.Y > 2.5 and p.Y < 4.5 then mist += 1 end
		if nm == "FloorSpikes" and p.Y > 0 and p.Y < 1.5 then spikes += 1 end
	end
	assert(mist >= 18 and spikes >= 16, "FrostRoar: la onda del suelo no salió en el piso")
	assert(R.stats.decals >= 3, "FrostRoar: no salieron las marcas del suelo")
	print(("%-17s   rugido: niebla en el piso=%d púas=%d marcas=%d"):format("", mist, spikes, R.stats.decals))
end
run("Eclipse", function() return MOON.Eclipse(R.CFrame.new(0, 0, 0), nil, nil, 1, 1) end, 8.5)
assert(R.stats.cubes > 200, "Eclipse: casi no hubo pedazos")
assert(R.stats.bills >= 8, "Eclipse: no salieron la luna ni los destellos gigantes (BillboardGui)")
assert(R.stats.billMax > 250, "Eclipse: la luna no es gigante")
assert(R.stats.beamMaxW > 150, "Eclipse: no se armó la columna de luz (Beams)")
assert(R.stats.slabs >= 120, "Eclipse: casi no brotaron cristales ni losas")
assert(R.stats.tips >= 60, "Eclipse: los cristales no tienen punta")
for _, nm in { "Slab", "SlabTip", "Moon", "Curtain", "Light" } do
	assert(R.liveNamed(nm) == 0, "Eclipse: quedaron piezas " .. nm)
end
print(("%-17s   eclipse: luna y destellos=%d (máx %.0f studs) columna máx %.0f studs | cristales y losas=%d puntas=%d cubos=%d"):format(
	"", R.stats.bills, R.stats.billMax, R.stats.beamMaxW, R.stats.slabs, R.stats.tips, R.stats.cubes))
print(("%-17s   tiempos: %s"):format("", (function()
	local o = {}
	for k, v in MOON.EclipseTimes do table.insert(o, k .. "=" .. v) end
	table.sort(o)
	return table.concat(o, " ")
end)()))
-- ---------------------------------------------------------------- Pebledon
local PEB = loadPebledon()
-- la boca a 21 studs, mirando un poco hacia abajo: el triángulo igual va por el suelo, en horizontal
run("SeismicRoar", function()
	return PEB.SeismicRoar(R.CFrame.lookAt(R.Vector3.new(0, 21, 0), R.Vector3.new(0, 19, -10)), nil, nil, 1, 1)
end, 6)
assert(PEB.SeismicRoarTimes.Roar == 0.36 and PEB.SeismicRoarLength == 100 and PEB.SeismicRoarAngle == 42,
	"SeismicRoar: faltan los tiempos, el largo o la apertura")
assert(math.abs(PEB.SeismicRoarFrontTime(0) - 0.39) < 1e-6 and math.abs(PEB.SeismicRoarFrontTime(100) - 1.24) < 1e-6
	and PEB.SeismicRoarFrontTime(50) > 0.39 and PEB.SeismicRoarFrontTime(50) < 0.39 + 0.85 / 2,
	"SeismicRoar: FrontTime no sigue al frente (sale rápido y se frena)")
assert(R.stats.slabs >= 40, "SeismicRoar: casi no saltaron losas del suelo")
assert(R.stats.rocks >= 30, "SeismicRoar: casi no salieron rocas arrastradas")
assert(R.stats.maxRate > 10, "SeismicRoar: el frente no soltó su polvo")
assert(R.stats.decals >= 40, "SeismicRoar: no quedaron las grietas")
assert(R.liveNamed("Slab") == 0, "SeismicRoar: quedaron losas en el suelo")
do -- lo de la boca sale a la altura de la boca; lo del suelo, en el piso y hacia adelante (-Z)
	local mouth, floor, cone, fwd = 0, 0, 0, math.huge
	for i, p in R.stats.emitPos do
		local nm = R.stats.emitNames[i]
		if (nm == "MouthFlash" or nm == "SonicRings" or nm == "RoarFlames") and math.abs(p.Y - 21) < 1 then mouth += 1 end
		if nm == "FloorDust" and p.Y > 1 and p.Y < 3 then floor += 1 end
		if nm == "CrackFlames" and p.Y > 0 and p.Y < 1.5 then
			cone += 1
			fwd = math.min(fwd, p.Z)
		end
	end
	assert(mouth >= 3, "SeismicRoar: el rugido no salió de la boca")
	assert(floor >= 16, "SeismicRoar: el polvo bajo él no salió en el piso")
	assert(cone >= 60 and fwd < -85, "SeismicRoar: el fuego de las grietas no cubre el triángulo en el suelo")
	print(("%-17s   rugido: boca=%d piso=%d fuego en grietas=%d (llega a z=%.0f) losas=%d rocas=%d grietas=%d"):format(
		"", mouth, floor, cone, fwd, R.stats.slabs, R.stats.rocks, R.stats.decals))
end
print("RUNTIME OK")
'''
b = "local R = (function()\n" + mock + "\nend)()\n"
b += "local shared = {}\n"   # en Roblox es una tabla global compartida entre scripts
for k in G:
    b += f"local {k} = R.{k}\n"
b += "local function loadModule()\n" + mod + "\nend\n"
b += "local function loadAstral()\n" + astral + "\nend\n"
b += "local function loadOmnivora()\n" + omni + "\nend\n"
b += "local function loadMoonfang()\n" + moon + "\nend\n"
b += "local function loadPebledon()\n" + peb + "\nend\n" + test
with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
    f.write(b)
sys.exit(subprocess.run([luau, f.name]).returncode)
