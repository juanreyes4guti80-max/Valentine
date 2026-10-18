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
G = ["Vector3", "Vector2", "CFrame", "Color3", "NumberRange", "NumberSequence", "NumberSequenceKeypoint",
     "ColorSequence", "ColorSequenceKeypoint", "TweenInfo", "Random", "Enum", "Instance", "workspace", "game", "task", "time",
     "typeof", "RaycastParams"]
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
-- ULTIMATE: el rayo llega hasta donde pega (el rival o la primera superficie) y el impacto sale ahí; el suelo
-- debajo se quema; al final los Beams se apagan y todo se limpia
local function runBeam(name, call, seconds, hit, gy)
	run(name, call, seconds)
	local st = R.stats
	local e = st.beamEnd
	assert(e ~= nil, name .. ": el rayo no tiene punta")
	-- ráfagas (Emit) y emisores continuos (Rate) en el impacto y en el suelo debajo
	local nearHit, streamHit, nearGround = 0, 0, 0
	local function onGround(p)
		return gy and math.abs(p.Y - gy) < 2.5 and (R.Vector3.new(p.X, 0, p.Z) - R.Vector3.new(hit.X, 0, hit.Z)).Magnitude < 6
	end
	for _, p in st.emitPos do
		if (p - hit).Magnitude < 8 then nearHit += 1 end
		if onGround(p) then nearGround += 1 end
	end
	for _, p in st.streamPos do
		if (p - hit).Magnitude < 8 then streamHit += 1 end
		if onGround(p) then nearGround += 1 end
	end
	print(("%-17s   rayo: largo %.1f | ancho máx %.1f | Beams apagados %d | impacto: %d ráfagas, %d continuos | suelo: %d | decals %d"):format(
		"", e.Magnitude, st.beamMaxW, st.beamsOff, nearHit, streamHit, nearGround, st.decals))
	assert(st.beamMaxW > 10, name .. ": el rayo casi no tiene ancho")
	assert(st.beamsOff >= 4, name .. ": los Beams no se apagaron al final")
	assert(nearHit >= 6 and streamHit >= 8, name .. ": casi no hubo impacto donde pega el rayo")
	if gy then
		assert(nearGround >= 3, name .. ": el suelo bajo el impacto no recibió nada")
		assert(st.decals >= 2, name .. ": faltan las marcas del suelo")
	end
end
-- de lado, sin nada en el camino: pega en el punto del rival (a 120 studs); el suelo está 20 studs abajo
runBeam("UltimateBeam", function()
	return VFX.UltimateBeam(R.Vector3.new(0, 20, 0), R.Vector3.new(0, 20, -120), 1, 1)
end, 6, R.Vector3.new(0, 20, -117), 0)
assert(math.abs(R.stats.beamEnd.Magnitude - 120) < 0.5, "UltimateBeam: el rayo no llegó al rival")
-- hacia abajo: el rival está bajo tierra, así que pega en el suelo (a 45 studs de la boca, en horizontal)
runBeam("Beam al suelo x1.5", function()
	return VFX.UltimateBeam(R.CFrame.new(0, 30, 0), R.Vector3.new(0, -10, -60), 1.5, 0)
end, 6, R.Vector3.new(0, 0, -45), 0)
assert(math.abs(R.stats.beamEnd.Magnitude - math.sqrt(45 ^ 2 + 30 ^ 2)) < 0.5, "Beam al suelo: no se cortó en el suelo")
-- contra un Model (el pivote del rival), ignorando a quien lo lanza
local rival = R.Instance.new("Model")
rival.GetPivot = function() return R.CFrame.new(80, 15, 0) end
local caster = R.Instance.new("Model")
runBeam("Beam Model", function()
	return VFX.UltimateBeam(R.Vector3.new(0, 25, 0), rival, 1, 2, { caster })
end, 6, R.Vector3.new(80, 15, 0) + (R.Vector3.new(0, 25, 0) - R.Vector3.new(80, 15, 0)).Unit * 3, 0)
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
print("RUNTIME OK")
'''
b = "local R = (function()\n" + mock + "\nend)()\n"
for k in G:
    b += f"local {k} = R.{k}\n"
b += "local function loadModule()\n" + mod + "\nend\n"
b += "local function loadAstral()\n" + astral + "\nend\n"
b += "local function loadOmnivora()\n" + omni + "\nend\n" + test
with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
    f.write(b)
sys.exit(subprocess.run([luau, f.name]).returncode)
