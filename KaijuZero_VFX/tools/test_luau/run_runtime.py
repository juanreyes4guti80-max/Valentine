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
run("Explosion", function() return VFX.Explosion(R.CFrame.new(0, 2.5, 0), 1) end, 2)
run("ExplosionAnime", function() return VFX.ExplosionAnime(R.CFrame.new(0, 2.5, 0), 1) end, 2)
run("FireLine", function() return VFX.FireLine(R.CFrame.new(0, 0, 0), 120, 1) end, 3.6, 120)
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
