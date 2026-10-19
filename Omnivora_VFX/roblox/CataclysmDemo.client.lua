--[[
	CataclysmDemo: prueba de la ULTIMATE de Omnívora (cataclismo gravitacional) sin los modelos reales.

	Cómo usarlo:
	  1. El ModuleScript OmnivoraVFX tiene que estar en ReplicatedStorage, con los IDs de sus texturas pegados.
	  2. Pon este LocalScript en StarterPlayer > StarterPlayerScripts y dale Play.
	  3. Aparecen un Omnívora de prueba en el centro (figura azul oscuro) y tres kaijus de prueba (grises), y la cámara
	     queda fija mirando todo. La ULTIMATE empieza sola a los 2 segundos.

	Teclas:
	  R        repetir desde el principio
	  1 .. 8   empezar en una fase: 1 despertar, 2 vórtice, 3 singularidad, 4 consumo, 5 masa crítica,
	           6 justo antes del destello, 7 detonación, 8 impactos y secuelas
	  V        cambiar de cámara (dentro del área / lejos, todo el radio / cerca de un impacto)
	  C        devolver la cámara al jugador (y otra vez C para volver a la cámara fija)
	  H        ocultar o mostrar el panel

	Todo lo de la prueba es local (solo lo ves tú) y se borra al salir. No toca tu sistema de combate.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OmnivoraVFX = require(ReplicatedStorage:WaitForChild("OmnivoraVFX"))

-- ---------------------------------------------------------------- ajustes de la prueba
local EPICENTER = Vector3.new(0, 0, 0) -- el centro (se busca el suelo debajo)
local VICTIM_OFFSETS = { Vector3.new(220, 0, 300), Vector3.new(-300, 0, 180), Vector3.new(90, 0, -260) }
local VICTIM_HEIGHT = 60
local OMNIVORA_HEIGHT = 90
local CAMERAS = { -- relativas al epicentro
	{ name = "Dentro del área", pos = Vector3.new(-420, 70, 1060), look = Vector3.new(0, 330, 0) },
	{ name = "Lejos: todo el radio de 500 m", pos = Vector3.new(-1500, 950, 1900), look = Vector3.new(0, 260, 0) },
	{ name = "Cerca de un impacto", pos = Vector3.new(560, 55, 820), look = Vector3.new(60, 110, 120) },
}

-- ---------------------------------------------------------------- figuras de prueba (cajas con forma de kaiju)
local FIG = {
	{ Vector3.new(-1, 0, 2.2), Vector3.new(3.2, 7, 2.6) }, { Vector3.new(-1, 0, -2.2), Vector3.new(3.2, 7, 2.6) },
	{ Vector3.new(0, 6, 0), Vector3.new(6, 8, 5.5) }, { Vector3.new(1, 12, 0), Vector3.new(5.2, 5, 4.6) },
	{ Vector3.new(2.5, 16, 0), Vector3.new(2.6, 3, 2.6) }, { Vector3.new(3.8, 18.2, 0), Vector3.new(4.6, 2.8, 3) },
	{ Vector3.new(6.4, 18.3, 0), Vector3.new(2.4, 1.8, 2.2) }, { Vector3.new(3.6, 9.5, 2.9), Vector3.new(3.2, 1.6, 1.4) },
	{ Vector3.new(3.6, 9.5, -2.9), Vector3.new(3.2, 1.6, 1.4) }, { Vector3.new(-4.2, 3.5, 0), Vector3.new(4, 3.2, 3) },
	{ Vector3.new(-7.6, 2, 0), Vector3.new(3.6, 2.4, 2.2) }, { Vector3.new(-10.6, 1, 0), Vector3.new(3, 1.6, 1.6) },
	{ Vector3.new(-13, 0.4, 0), Vector3.new(2.4, 1, 1) }, { Vector3.new(-1.2, 17, 0), Vector3.new(1, 2.2, 0.5) },
	{ Vector3.new(0.8, 17, 0), Vector3.new(1, 2.6, 0.5) }, { Vector3.new(-3.2, 14, 0), Vector3.new(1, 2, 0.5) },
}

local function groundAt(pos: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 500, 0), Vector3.new(0, -2000, 0), params)
	return if hit then hit.Position else pos
end

local function makeFigure(name: string, height: number, color: Color3, yaw: number, ground: Vector3): Model
	local model = Instance.new("Model")
	model.Name = name
	local s = height / 21
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new(ground + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, yaw, 0)
	root.Parent = model
	for _, b in FIG do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Material = Enum.Material.Slate
		p.Color = color
		p.Size = b[2] * s
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = root.CFrame * CFrame.new(b[1].X * s, (b[1].Y + b[2].Y / 2) * s - height / 2, b[1].Z * s)
		p.Parent = model
	end
	model.PrimaryPart = root
	model.Parent = workspace
	return model
end

local center = groundAt(EPICENTER, {})
local omnivora = makeFigure("OmnivoraDePrueba", OMNIVORA_HEIGHT, Color3.fromRGB(34, 40, 80), 1.2, center)
local victims: { Model } = {}
local starts: { CFrame } = {}
for i, off in VICTIM_OFFSETS do
	local g = groundAt(center + off, { omnivora })
	local m = makeFigure("KaijuDePrueba" .. i, VICTIM_HEIGHT, Color3.fromRGB(118, 114, 124), math.atan2(-off.Z, off.X), g)
	victims[i] = m
	starts[i] = m:GetPivot()
end

-- ---------------------------------------------------------------- la ULTIMATE
local current = nil
local lastImpact = ""
local function run(startTime: number)
	if current then
		current:Stop()
	end
	for i, m in victims do
		m:PivotTo(starts[i])
	end
	lastImpact = ""
	current = OmnivoraVFX.GravitationalCataclysm(omnivora, victims, {
		MoveVictims = true, -- en la prueba el efecto mueve a los kaijus de prueba; en el juego lo hace tu código
		Caster = omnivora,
		StartTime = startTime,
		OnEvent = function(name: string, a: any, b: any, c: any)
			if name == "VictimImpact" then
				lastImpact = ("impacto de %s en (%.0f, %.0f)"):format(a.Name, c.X, c.Z)
			end
		end,
	})
end

local Tm = OmnivoraVFX.GravitationalCataclysmTimes
local PHASE_STARTS = { 0, Tm.Vortex, Tm.Singularity, Tm.Consumption, Tm.CriticalMass, Tm.CriticalMass + 1.4,
	Tm.Detonation - 0.6, Tm.Detonation - 0.05 }

-- ---------------------------------------------------------------- la cámara fija
local cam = workspace.CurrentCamera
local fixed = true
local camIndex = 1
RunService:BindToRenderStep("CataclysmDemoCamera", Enum.RenderPriority.Camera.Value, function()
	if not fixed then
		return
	end
	local c = CAMERAS[camIndex]
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 70
	cam.CFrame = CFrame.lookAt(center + c.pos, center + c.look)
end)

-- ---------------------------------------------------------------- el panel
local gui = Instance.new("ScreenGui")
gui.Name = "CataclysmDemo"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 560, 0, 112)
label.Position = UDim2.new(0, 12, 1, -124)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.45
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.Code
label.TextSize = 16
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Parent = gui
RunService.RenderStepped:Connect(function()
	local phase, t = "(esperando)", 0
	if current and current.Active then
		phase, t = current.Phase, current.Time
	elseif current then
		phase, t = "terminó", current.Time
	end
	label.Text = (" ULTIMATE de Omnívora: cataclismo gravitacional\n %s  ·  %.2f s\n cámara: %s\n %s\n [R] repetir  [1-8] fase  [V] cámara  [C] cámara libre  [H] panel")
		:format(phase, t, if fixed then CAMERAS[camIndex].name else "libre", lastImpact)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	local key = input.KeyCode
	local numbers = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
		Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }
	local n = table.find(numbers, key)
	if n then
		run(PHASE_STARTS[n])
	elseif key == Enum.KeyCode.R then
		run(0)
	elseif key == Enum.KeyCode.V then
		camIndex = camIndex % #CAMERAS + 1
	elseif key == Enum.KeyCode.C then
		fixed = not fixed
		if not fixed then
			cam.CameraType = Enum.CameraType.Custom
		end
	elseif key == Enum.KeyCode.H then
		gui.Enabled = not gui.Enabled
	end
end)

task.delay(2, function()
	run(0)
end)
