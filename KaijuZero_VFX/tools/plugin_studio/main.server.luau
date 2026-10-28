--!strict
--[[
	Subir texturas VFX: plugin de Studio para los módulos KaijuFireVFX, OmnivoraVFX, AstralColossusVFX y MoonfangVFX.

	Botón "Subir texturas": busca los módulos en tu juego, sube como Image a tu cuenta las texturas que les faltan
	(el plugin ya las trae dentro) y pega los IDs en la tabla TEXTURES de cada módulo. Si un ID ya funciona, lo
	deja. Recuerda los IDs que subió, así que con una versión nueva de un módulo solo vuelves a tocar el botón.
	Botón "Revisar texturas": dice qué texturas faltan o no cargan (por ejemplo un ID de Decal en vez de imagen).

	Usa AssetService:CreateAssetAsync, que solo funciona en plugins instalados en tu carpeta de Plugins.
]]

local AssetService = game:GetService("AssetService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ContentProvider = game:GetService("ContentProvider")
local ScriptEditorService = game:GetService("ScriptEditorService")
local StudioService = game:GetService("StudioService")

local root = script :: any
local Png = require(root.Png) :: any
local INDEX = require(root.Indice) :: any -- nombre -> { w, h, hash }
local DATA = root.Texturas -- un ModuleScript por textura: devuelve el PNG en base64

local SETTING = "VFXTexturasIds" -- nombre@huella -> id de la imagen subida

-- ---------------------------------------------------------------- ventana con el registro
local toolbar = plugin:CreateToolbar("VFX Kaiju")
local uploadButton = toolbar:CreateButton("Subir texturas", "Sube las texturas que faltan y pega sus IDs en los módulos de VFX", "")
local checkButton = toolbar:CreateButton("Revisar texturas", "Dice qué texturas faltan o no cargan en los módulos de VFX", "")
uploadButton.ClickableWhenViewportHidden = true
checkButton.ClickableWhenViewportHidden = true

local widget = plugin:CreateDockWidgetPluginGuiAsync("VFXTexturas",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 460, 320, 320, 200))
widget.Title = "Texturas VFX"
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.fromScale(1, 1)
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 8
scroll.BackgroundColor3 = Color3.fromRGB(37, 37, 37)
scroll.BorderSizePixel = 0
scroll.Parent = widget
local text = Instance.new("TextLabel")
text.Size = UDim2.new(1, -16, 0, 0)
text.Position = UDim2.fromOffset(8, 6)
text.AutomaticSize = Enum.AutomaticSize.Y
text.BackgroundTransparency = 1
text.TextColor3 = Color3.fromRGB(230, 230, 230)
text.Font = Enum.Font.Code
text.TextSize = 14
text.TextWrapped = true
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.Text = ""
text.Parent = scroll

local lines: { string } = {}
local function log(s: string)
	print("[Texturas VFX] " .. s)
	table.insert(lines, s)
	if #lines > 400 then
		table.remove(lines, 1)
	end
	text.Text = table.concat(lines, "\n")
	scroll.CanvasPosition = Vector2.new(0, 1e6)
end

-- ---------------------------------------------------------------- los módulos de VFX del juego
type Module = { script: ModuleScript, ids: { [string]: string }, order: { string } }

local function parseTextures(src: string): ({ [string]: string }?, { string })
	local a = string.find(src, ".TEXTURES = {", 1, true)
	if not a then
		return nil, {}
	end
	local b = string.find(src, "\n}", a, true)
	if not b then
		return nil, {}
	end
	local ids: { [string]: string } = {}
	local order: { string } = {}
	for name, id in string.gmatch(string.sub(src, a, b), "\n\t([%w_]+) = \"rbxassetid://(%d*)\"") do
		ids[name :: string] = id :: string
		table.insert(order, name :: string)
	end
	return ids, order
end

local function findModules(): { Module }
	local out: { Module } = {}
	for _, d in game:GetDescendants() do
		if d:IsA("ModuleScript") then
			local ok, src = pcall(function()
				return (d :: ModuleScript).Source
			end)
			if ok and string.find(src, "Pega aquí los IDs", 1, true) then
				local ids, order = parseTextures(src)
				if ids and #order > 0 then
					table.insert(out, { script = d :: ModuleScript, ids = ids, order = order })
				end
			end
		end
	end
	return out
end

local function writeIds(m: Module, chosen: { [string]: string }): boolean
	local function edit(src: string): string
		for _, name in m.order do
			local id = chosen[name]
			if id then
				src = string.gsub(src, "(\n\t" .. name .. " = \"rbxassetid://)%d*\"", "%1" .. id .. "\"", 1)
			end
		end
		return src
	end
	local ok = pcall(function()
		ScriptEditorService:UpdateSourceAsync(m.script, edit)
	end)
	if not ok then
		ok = pcall(function()
			m.script.Source = edit(m.script.Source)
		end)
	end
	return ok
end

-- qué IDs cargan: id -> true / false
local function probe(ids: { string }): { [string]: boolean }
	local res: { [string]: boolean } = {}
	if #ids == 0 then
		return res
	end
	local list = {}
	for _, id in ids do
		table.insert(list, "rbxassetid://" .. id)
	end
	pcall(function()
		ContentProvider:PreloadAsync(list, function(content: string, status: Enum.AssetFetchStatus)
			local id = string.match(content, "%d+")
			if id then
				res[id] = status == Enum.AssetFetchStatus.Success
			end
		end)
	end)
	for _, id in ids do
		if res[id] == nil then
			res[id] = false
		end
	end
	return res
end

-- ---------------------------------------------------------------- subir una textura
-- si el juego es de un grupo, las imágenes van al grupo (el último intento, a tu cuenta)
local function creator(attempt: number): (number, Enum.AssetCreatorType)
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 and attempt < 3 then
		return game.CreatorId, Enum.AssetCreatorType.Group
	end
	return StudioService:GetUserId(), Enum.AssetCreatorType.User
end

local function upload(name: string, png64: string): (string?, string?)
	local w, h, px = Png.decode(Png.fromBase64(png64))
	local lastErr = "?"
	for attempt = 1, 3 do
		local img = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
		if not img then
			lastErr = "no hay memoria para la imagen"
		else
			img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), px)
			local creatorId, creatorType = creator(attempt)
			local ok, result, value = pcall(function()
				return (AssetService :: any):CreateAssetAsync(img, Enum.AssetType.Image, {
					Name = "VFX_" .. name,
					Description = "Textura de los VFX de Kaiju Zero / Omnívora / Astral Colossus / Moonfang",
					CreatorId = creatorId,
					CreatorType = creatorType,
				})
			end)
			img:Destroy()
			if ok and result == Enum.CreateAssetResult.Success then
				return tostring(value), nil
			end
			lastErr = if ok then tostring(result) .. " " .. tostring(value) else tostring(result)
		end
		task.wait(2 * attempt * attempt)
	end
	return nil, lastErr
end

-- ---------------------------------------------------------------- los botones
local busy = false

local function run(doUpload: boolean)
	if busy then
		return
	end
	busy = true
	widget.Enabled = true
	table.clear(lines)
	xpcall(function()
		local modules = findModules()
		if #modules == 0 then
			log("No encontré ningún módulo de VFX en el juego. Inserta primero KaijuFireVFX, OmnivoraVFX, AstralColossusVFX o MoonfangVFX.")
			return
		end
		for _, m in modules do
			log(("Módulo %s: %d texturas"):format(m.script:GetFullName(), #m.order))
		end
		-- los IDs que ya tienen los módulos: ¿cargan?
		local current: { string } = {}
		local seen: { [string]: boolean } = {}
		for _, m in modules do
			for _, name in m.order do
				local id = m.ids[name]
				if id ~= "" and id ~= "0" and not seen[id] then
					seen[id] = true
					table.insert(current, id)
				end
			end
		end
		log(("Revisando %d IDs que ya están puestos…"):format(#current))
		local works = probe(current)

		local cache = plugin:GetSetting(SETTING) or {}
		local chosen: { [string]: string } = {}
		local missing: { string } = {}
		local broken: { string } = {}
		local unknown: { string } = {}
		local names: { string } = {}
		local isNeeded: { [string]: boolean } = {}
		for _, m in modules do
			for _, name in m.order do
				if not isNeeded[name] then
					isNeeded[name] = true
					table.insert(names, name)
				end
			end
		end
		table.sort(names)
		for _, name in names do
			local good: string? = nil
			for _, m in modules do
				local id = m.ids[name]
				if id and works[id] then
					good = id
					break
				end
			end
			local info = INDEX[name]
			local key = if info then name .. "@" .. info.hash else nil
			if good then
				chosen[name] = good
				if key and not cache[key] then
					cache[key] = good
				end
			elseif key and cache[key] then
				chosen[name] = cache[key]
			else
				table.insert(missing, name)
				for _, m in modules do
					local id = m.ids[name]
					if id and id ~= "" and id ~= "0" then
						table.insert(broken, name)
						break
					end
				end
				if not info then
					table.insert(unknown, name)
				end
			end
		end
		if #broken > 0 then
			log(("No cargan %d IDs (¿IDs de Decal en vez de imagen, o imágenes rechazadas?): %s"):format(#broken, table.concat(broken, ", ")))
		end

		if not doUpload then
			log(("Faltan %d texturas: %s"):format(#missing, if #missing > 0 then table.concat(missing, ", ") else "ninguna"))
			log(if #missing > 0 then "Toca \"Subir texturas\" para subirlas y pegar sus IDs." else "Todo listo: todas las texturas cargan.")
			return
		end

		local recording = ChangeHistoryService:TryBeginRecording("Pegar IDs de texturas VFX")
		local uploaded, failed = 0, 0
		for i, name in missing do
			local info = INDEX[name]
			local data = DATA:FindFirstChild(name)
			if not info or not data then
				log(("  %s: el plugin no la trae. Actualiza el plugin a la versión de tus módulos."):format(name))
				failed += 1
				continue
			end
			log(("Subiendo %d/%d: %s (%dx%d)…"):format(i, #missing, name, info.w, info.h))
			local id, why = upload(name, require(data) :: any)
			if id then
				chosen[name] = id
				cache[name .. "@" .. info.hash] = id
				plugin:SetSetting(SETTING, cache)
				uploaded += 1
			else
				log(("  no se pudo subir: %s"):format(why or "?"))
				failed += 1
			end
		end
		plugin:SetSetting(SETTING, cache)

		local wrote = 0
		for _, m in modules do
			if writeIds(m, chosen) then
				wrote += 1
			else
				log("  no pude escribir en " .. m.script:GetFullName())
			end
		end
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
		local reused = 0
		for _ in chosen do
			reused += 1
		end
		reused -= uploaded
		log(("Listo: %d subidas, %d que ya estaban, %d sin subir. IDs pegados en %d módulo(s)."):format(uploaded, reused, failed, wrote))
		if uploaded > 0 then
			log("Roblox revisa las imágenes nuevas: pueden tardar unos minutos en verse. Si alguna sale en blanco, espera y toca \"Revisar texturas\".")
		end
		if #unknown > 0 then
			log("Estas texturas no vienen en el plugin: " .. table.concat(unknown, ", "))
		end
	end, function(err)
		log("Error: " .. tostring(err))
	end)
	busy = false
end

uploadButton.Click:Connect(function()
	run(true)
end)
checkButton.Click:Connect(function()
	run(false)
end)
