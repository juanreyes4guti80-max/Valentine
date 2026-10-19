"""Prueba el plugin: ejecuta el plugin SubirTexturasVFX.rbxmx contra un Studio simulado, con las fuentes reales de los tres módulos."""
import xml.etree.ElementTree as ET, subprocess, sys, os, tempfile
# uso: python run_plugin_test.py /ruta/luau   (luau-compile tiene que estar en la misma carpeta)
LUAU = sys.argv[1]
COMPILE = os.path.join(os.path.dirname(LUAU), "luau-compile")
R = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TMP = tempfile.mkdtemp()
top = ET.parse(f"{R}/Plugin_Studio/SubirTexturasVFX.rbxmx").getroot().find("Item")
def src(it): return it.find("Properties/ProtectedString").text
kids = {c.find("Properties/string").text: c for c in top.findall("Item")}
main, png, indice = src(top), src(kids["Png"]), src(kids["Indice"])
data = {c.find("Properties/string").text: src(c) for c in kids["Texturas"].findall("Item")}
mods = {n: open(f"{R}/{d}/roblox/{n}.lua").read() for n, d in
        [("KaijuFireVFX", "KaijuZero_VFX"), ("OmnivoraVFX", "Omnivora_VFX"), ("AstralColossusVFX", "AstralColossus_VFX")]}
L = lambda s: "[==[" + s + "]==]"
b = r'''
local Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end })
local function obj(props) props = props or {}; return setmetatable(props, { __index = function() return nil end }) end
local Instance = { new = function(c) return obj({ ClassName = c }) end }
local UDim2 = { new = function() return 0 end, fromScale = function() return 0 end, fromOffset = function() return 0 end }
local Vector2 = { new = function(x, y) return { X = x, Y = y } end, zero = { X = 0, Y = 0 } }
local Color3 = { fromRGB = function() return 0 end }
local DockWidgetPluginGuiInfo = { new = function() return 0 end }
local task = { wait = function() end }
local stats = { uploads = 0, nextId = 1000000, badBuffer = 0, recordings = 0 }
local settings = {}
local handlers = {}
local function button() local b = obj({}); b.Click = { Connect = function(_, f) table.insert(handlers, f) end }; return b end
local plugin = {
	CreateToolbar = function() return { CreateButton = function() return button() end } end,
	CreateDockWidgetPluginGuiAsync = function() return obj({}) end,
	GetSetting = function(_, k) return settings[k] and table.clone(settings[k]) end,
	SetSetting = function(_, k, v) settings[k] = table.clone(v) end,
}
local modules = {}
local function module(name, source)
	local m = obj({ Name = name, Source = source })
	m.IsA = function(_, c) return c == "ModuleScript" end
	m.GetFullName = function() return "ReplicatedStorage." .. name end
	table.insert(modules, m)
	return m
end
local services = {
	AssetService = {
		CreateEditableImage = function(_, o)
			local img = { size = o.Size }
			img.WritePixelsBuffer = function(_, pos, size, buf)
				if buffer.len(buf) ~= size.X * size.Y * 4 then stats.badBuffer += 1 end
			end
			img.Destroy = function() end
			return img
		end,
		CreateAssetAsync = function(_, img, kind, p)
			assert(kind == "AssetType.Image" and p.Name and p.CreatorType == "AssetCreatorType.User")
			stats.uploads += 1
			stats.nextId += 1
			return "CreateAssetResult.Success", stats.nextId
		end,
	},
	ChangeHistoryService = { TryBeginRecording = function() stats.recordings += 1; return "r" end, FinishRecording = function() end },
	ContentProvider = { PreloadAsync = function(_, list, cb)
		for _, c in list do
			local id = tonumber(string.match(c, "%d+"))
			cb(c, if id and id > 1000000 then "AssetFetchStatus.Success" else "AssetFetchStatus.Failure")
		end
	end },
	ScriptEditorService = { UpdateSourceAsync = function(_, s, f) s.Source = f(s.Source) end },
	StudioService = { GetUserId = function() return 42 end },
}
local game = { CreatorType = "CreatorType.User", CreatorId = 0,
	GetService = function(_, n) return services[n] end,
	GetDescendants = function() return modules end }
local PNG = (function() ''' + png + r''' end)()
local INDICE = (function() ''' + indice + r''' end)()
local DATA = {
''' + "\n".join(f'\t{n} = {L(v.replace("return [[", "").replace("]]", "").strip())},' for n, v in data.items()) + r'''
}
local folder = { FindFirstChild = function(_, n) return DATA[n] and { __data = n } or nil end }
local script = { Png = { __mod = "Png" }, Indice = { __mod = "Indice" }, Texturas = folder }
local function require(x)
	if x.__mod == "Png" then return PNG elseif x.__mod == "Indice" then return INDICE end
	return DATA[x.__data]
end
''' + "".join(f'local M_{n} = module("{n}", {L(s)})\n' for n, s in mods.items()) + r'''
-- el plugin
do
''' + main + r'''
end
local function ids(m)
	local out, zero = {}, 0
	local a = string.find(m.Source, ".TEXTURES = {", 1, true)
	local blk = string.sub(m.Source, a, string.find(m.Source, "\n}", a, true))
	for n, id in string.gmatch(blk, "\n\t([%w_]+) = \"rbxassetid://(%d*)\"") do
		out[n] = id
		if id == "0" or id == "" then zero += 1 end
	end
	return out, zero
end
local function report(tag)
	local zeros, total = 0, 0
	for _, m in modules do local t, z = ids(m); zeros += z; for _ in t do total += 1 end end
	print(("%-28s subidas=%d  entradas=%d  sin ID=%d  buffers mal=%d"):format(tag, stats.uploads, total, zeros, stats.badBuffer))
	return zeros
end
local upload, check = handlers[1], handlers[2]
check()
report("revisar (sin subir nada)")
assert(stats.uploads == 0)
local t0 = os.clock()
upload()
local z = report("1a vez: subir")
assert(z == 0 and stats.uploads == ''' + str(len(data)) + r''' and stats.badBuffer == 0, "no se llenaron todos los IDs")
-- la misma textura comparte ID en los tres módulos
local a = ids(M_KaijuFireVFX).fx_glow; local b2 = ids(M_OmnivoraVFX).fx_glow
assert(a == b2, "fx_glow con IDs distintos")
print(("   (%.1f s)"):format(os.clock() - t0))
upload()
report("2a vez: no sube nada")
assert(stats.uploads == ''' + str(len(data)) + r''')
-- un módulo nuevo (IDs en 0) y un ID roto (de Decal): se llenan desde la memoria del plugin, sin subir
M_OmnivoraVFX.Source = ''' + L(mods["OmnivoraVFX"]) + r'''
M_KaijuFireVFX.Source = string.gsub(M_KaijuFireVFX.Source, "(\n\tfx_glow = \"rbxassetid://)%d+", "%1123")
upload()
z = report("módulo nuevo + ID roto")
assert(z == 0 and stats.uploads == ''' + str(len(data)) + r''')
assert(ids(M_KaijuFireVFX).fx_glow == a, "no se arregló el ID roto")
for _, m in modules do print("@@MOD " .. m.Name); print(m.Source); print("@@END") end
print("PLUGIN OK")
'''
open(f"{TMP}/plugin_test.luau", "w").write(b)
r = subprocess.run([LUAU, f"{TMP}/plugin_test.luau"], capture_output=True, text=True, timeout=1200)
import re, os
out=r.stdout
for name, body in re.findall(r"@@MOD (\w+)\n(.*?)\n@@END", out, re.S):
    f=f"{TMP}/filled_{name}.lua"; open(f,"w").write(body)
    c=subprocess.run([COMPILE, f], capture_output=True, text=True)
    m=re.search(r'\n\tfx_glow = "rbxassetid://(\d+)"', body)
    print(name, "compila" if c.returncode==0 else "NO COMPILA "+c.stderr[:300], "fx_glow =", m and m.group(1))
clean=re.sub(r"@@MOD.*?@@END\n?", "", out, flags=re.S)
print("\n".join(l for l in clean.splitlines() if not l.startswith("[Texturas VFX]")), r.stderr[-2000:])

ok = "PLUGIN OK" in r.stdout and "NO COMPILA" not in r.stdout
sys.exit(0 if ok else 1)
