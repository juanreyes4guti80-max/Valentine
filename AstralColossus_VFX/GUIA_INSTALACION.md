# VFX cósmicos de ASTRAL COLOSSUS: guía de instalación

## Qué hay aquí

| Carpeta / archivo | Para qué sirve |
|---|---|
| `roblox/AstralColossusVFX.rbxmx` | El ModuleScript listo para insertar en Studio. |
| `roblox/AstralColossusVFX.lua` | El mismo código en texto, si prefieres copiar y pegar. |
| `roblox/texturas_necesarias.txt` | Las 21 imágenes que usa el módulo. |
| `textures/` | Las imágenes que hay que subir a Roblox (son exactamente esas 21). |
| `preview/` | Video simulado del efecto. |

Los generadores están en `KaijuZero_VFX/tools/`: el mismo motor genera los módulos de Kaiju Zero, Astral Colossus y Omnívora.

## Efecto incluido

| Función | Qué es | Duración |
|---|---|---|
| `AstralClash(cf, largo, angulo, escala, sacudida)` | **H1, choque astral**: la lanza choca contra el escudo (destello estelar, anillos y relámpagos cósmicos) y salen hacia adelante **tres olas de aire en forma de triángulo**, cada una más débil que la anterior. La primera es **destructiva**: rompe el suelo con grietas de luz y marcas oscuras, arranca **rocas que salen volando** con estela cósmica, levanta esquirlas y estallidos de polvo, y empuja un muro de polvo por delante. Al final queda un **campo de nebulosa** con estrellas y polvo suspendidos, casi quietos y titilando: es la zona donde el tiempo se frena. | 2.6 s |
| `Shake(intensidad, duración)` | Sacudida de cámara. Solo funciona en el cliente. | — |

Los colores son una mezcla de **morado, azul y blanco**. El efecto **cierra limpio**: el contenedor se destruye solo cuando ya murió la última partícula y la última roca.

### Tiempos (para coordinarlo con la animación y con tu ralentización)

| Momento | Qué pasa |
|---|---|
| 0 s | La lanza choca con el escudo: destello. **Llama la función en este instante.** |
| 0.05 s → 0.41 s | La primera ola (la destructiva) recorre el triángulo, del vértice al borde lejano. |
| 0.18 s → 0.54 s | Segunda ola. |
| 0.31 s → 0.67 s | Tercera ola. |
| hasta ~2.5 s | Campo de nebulosa y estrellas suspendidas. |

Las olas siempre tardan lo mismo en cruzar el triángulo, sea cual sea el largo. La primera ola llega a un punto que está a `d` studs del vértice en `0.05 + 0.36 × d / largo` segundos.

## Instalación (unos 10 minutos)

1. **Inserta el módulo.** En Studio, clic derecho sobre `ReplicatedStorage` > *Insert from File…* > elige `roblox/AstralColossusVFX.rbxmx`.
2. **Sube las texturas.** Ve a *View* > *Asset Manager* > botón *Bulk Import* y selecciona todas las imágenes de `textures/`.
3. **Pega los IDs.** En el Asset Manager, clic derecho en cada imagen > *Copy ID to clipboard*. Luego pega el número en la tabla `TEXTURES` del módulo:

   ```lua
   kk_star_09 = "rbxassetid://123456789",
   ```

   Usa el ID de la **imagen**, no el de un Decal. `kz_debris_2x2` y `kz_scorch` son las mismas imágenes del paquete de Kaiju Zero: si ya las subiste, puedes reutilizar esos IDs.

## Cómo llamarlo

Llámalo desde un **LocalScript**. El servidor avisa a todos los clientes con un RemoteEvent y cada cliente reproduce el efecto. Así no se carga el servidor y la sacudida de cámara funciona.

### Parámetros

- **`cf`**: el **vértice del triángulo, en el suelo**, mirando hacia donde sale la onda. El triángulo se abre hacia el `LookVector` de `cf`. Ponlo justo delante de los pies del Astral Colossus.
- **`largo`**: largo del triángulo en studs. Si no lo pasas, vale `70 × escala`.
- **`angulo`**: apertura del triángulo en grados. Si no lo pasas, vale 55.
- **`escala`**: tamaño general (partículas, rocas, altura del choque). El destello del choque sale `13 × escala` studs por encima del vértice y `4 × escala` hacia atrás, donde se juntan la lanza y el escudo. Si tu Astral Colossus es más grande, sube la escala.
- **`sacudida`**: `0` o `nil` la desactiva, `1` es normal y `2` es fuerte.

```lua
-- LocalScript (por ejemplo en StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AstralColossusVFX = require(ReplicatedStorage.AstralColossusVFX)
local evento = ReplicatedStorage:WaitForChild("AstralHabilidadVFX") -- RemoteEvent

evento.OnClientEvent:Connect(function(habilidad: string, cf: CFrame, largo: number, angulo: number)
	if habilidad == "H1" then
		AstralColossusVFX.AstralClash(cf, largo, angulo, 1, 1)
	end
end)
```

```lua
-- Server: en el instante en que la lanza choca con el escudo
local LARGO, ANGULO = 70, 55
local raiz = personaje.HumanoidRootPart
local mira = raiz.CFrame.LookVector
local adelante = Vector3.new(mira.X, 0, mira.Z).Unit
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { personaje }
local hit = workspace:Raycast(raiz.Position, Vector3.new(0, -100, 0), params)
local suelo = if hit then hit.Position else raiz.Position
local vertice = suelo + adelante * 4 -- un poco delante de los pies
local cf = CFrame.lookAt(vertice, vertice + adelante)
evento:FireAllClients("H1", cf, LARGO, ANGULO)
```

### La ralentización la pone tu código

El módulo solo dibuja el efecto. La ralentización de los enemigos va en tu script del servidor. Para que coincida exactamente con lo que se ve, usa el mismo `cf`, `largo` y `angulo`:

```lua
-- ¿está este punto dentro del triángulo del efecto?
local function dentroDelTriangulo(cf: CFrame, largo: number, angulo: number, punto: Vector3): boolean
	local p = cf:PointToObjectSpace(punto)
	local d = -p.Z -- distancia hacia adelante desde el vértice
	return d >= 0 and d <= largo and math.abs(p.X) <= d * math.tan(math.rad(angulo / 2))
end

-- ralentiza a cada enemigo justo cuando le llega la primera ola
for _, enemigo in enemigos do
	local pos = enemigo.HumanoidRootPart.Position
	if dentroDelTriangulo(cf, LARGO, ANGULO, pos) then
		local d = -cf:PointToObjectSpace(pos).Z
		task.delay(0.05 + 0.36 * d / LARGO, function()
			ralentizar(enemigo) -- tu función
		end)
	end
end
```

El campo de nebulosa dura unos 2.5 s. Si tu ralentización dura bastante más, el efecto ya no la acompañará hasta el final.

### Rendimiento

En el pico hay unas 1000 partículas y 20 rocas. `AstralColossusVFX.Quality = 0.6` reduce las partículas, por ejemplo en celulares.

## Para que se vea como en el video

- La vista previa usa **Bloom**. En `Lighting` agrega un `BloomEffect` con *Intensity* 0.6–1, *Size* 24 y *Threshold* 1.5–2. Si se ve demasiado blanco, sube el *Threshold*.
- Las grietas, las marcas oscuras y el brillo del suelo son **Decals** en el plano de `cf`. Están pensados para suelo plano: en una pendiente fuerte pueden quedar flotando o enterrados.
- Las rocas que salen volando son Parts reales (Slate oscuro) que se mueven por código. No chocan con nada ni detectan toques, y al caer levantan polvo. Las crea el efecto, así que no tocan las rocas de tu mapa.

## Licencias de las texturas (todas libres para uso comercial)

- **Kenney Particle Pack** (`kk_*`): CC0, de kenney.nl. El crédito es opcional. Ver `textures/KENNEY_LICENSE.txt`.
- **Muestras oficiales de Effekseer** (`fx_*`): CC0. Agradecen el crédito a "Effekseer" y a los autores de las muestras. Ver `textures/EFFEKSEER_SAMPLES_LICENSE_CC0.txt`.
- **`kz_*`**: generadas para este proyecto, son tuyas.

## Si quieres cambiar algo

El efecto está en `KaijuZero_VFX/tools/vfx_astral.py`: colores, tiempos de las olas, cantidad de rocas, tamaño del campo de nebulosa. Después de editarlo, regenera los módulos desde la carpeta `KaijuZero_VFX`:

```
python tools/gen_luau.py roblox
```

Eso escribe `KaijuFireVFX` en `KaijuZero_VFX/roblox`, `AstralColossusVFX` en `AstralColossus_VFX/roblox` y `OmnivoraVFX` en `Omnivora_VFX/roblox`.

La prueba `KaijuZero_VFX/tools/test_luau/run_runtime.py` ejecuta el efecto contra un Roblox simulado con varios largos y ángulos. Comprueba que se limpie todo y que todas las emisiones caigan dentro del triángulo.
