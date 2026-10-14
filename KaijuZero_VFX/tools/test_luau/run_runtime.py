"""Ejecuta KaijuFireVFX contra el Roblox simulado. uso: python run_runtime.py /ruta/luau"""
import os, subprocess, sys, tempfile
d = os.path.dirname(os.path.abspath(__file__))
luau = sys.argv[1]
mock = open(os.path.join(d, "runtime_mock.luau")).read()
mod = open(os.path.join(d, "..", "..", "roblox", "KaijuFireVFX.lua")).read().replace("--!nonstrict", "")
G = ["Vector3", "Vector2", "CFrame", "Color3", "NumberRange", "NumberSequence", "NumberSequenceKeypoint",
     "ColorSequence", "ColorSequenceKeypoint", "TweenInfo", "Random", "Enum", "Instance", "workspace", "game", "task", "time"]
test = r'''
local function run(name, call, seconds)
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
	print(("%-15s emits=%d particulas=%d rocas=%d decals=%d maxRate=%.0f | pendientes: delays=%d waits=%d heartbeat=%d render=%d | vivos=%d holderDestruido=%s"):format(
		name, R.stats.emits, R.stats.emitted, R.stats.rocks, R.stats.decals, R.stats.maxRate, dl, wt, hb, rs, leftovers, tostring(R.isDestroyed(holder))))
	assert(R.isDestroyed(holder), name .. ": el contenedor no se destruyó")
	assert(hb == 0, name .. ": quedaron conexiones Heartbeat activas")
	assert(rs == 0, name .. ": quedó la sacudida de cámara enlazada")
end
local VFX = loadModule()
VFX.Parent = R.workspace
run("GiantExplosion", function() return VFX.GiantExplosion(R.CFrame.new(10, 0, 5), 1, 1) end, 7)
run("Giant x2.5", function() return VFX.GiantExplosion(R.CFrame.new(0, 0, 0), 2.5) end, 7)
run("Explosion", function() return VFX.Explosion(R.CFrame.new(0, 2.5, 0), 1) end, 2)
run("ExplosionAnime", function() return VFX.ExplosionAnime(R.CFrame.new(0, 2.5, 0), 1) end, 2)
run("FireLine", function() return VFX.FireLine(R.CFrame.new(0, 0, 0), 120, 1) end, 3.2)
print("RUNTIME OK")
'''
b = "local R = (function()\n" + mock + "\nend)()\n"
for k in G:
    b += f"local {k} = R.{k}\n"
b += "local function loadModule()\n" + mod + "\nend\n" + test
with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
    f.write(b)
sys.exit(subprocess.run([luau, f.name]).returncode)
