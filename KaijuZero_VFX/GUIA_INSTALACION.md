# VFX de fuego de KAIJU ZERO: guía de instalación

## Qué hay aquí

| Carpeta / archivo | Para qué sirve |
|---|---|
| `roblox/KaijuFireVFX.rbxmx` | El ModuleScript listo para insertar en Studio. |
| `roblox/KaijuFireVFX.lua` | El mismo código en texto, si prefieres copiar y pegar. |
| `roblox/texturas_necesarias.txt` | Las 36 imágenes que usa el módulo. |
| `textures/` | Las imágenes que hay que subir a Roblox. |
| `preview/` | Videos simulados de cada efecto. |
| `tools/` | Generadores (texturas, simulador, módulo). No hace falta tocarlos. |

## Efectos incluidos

### Habilidades

| Función | Qué es | Duración |
|---|---|---|
| `GiantExplosion(cf, escala, sacudida)` | **H1**: la explosión gigante. Destello, onda de choque, ola de polvo, bola de fuego, rocas en llamas con estela, hongo de humo y **fuego en el suelo durante 5 s**. | 5.8 s |
| `GiantExplosionIgnition(cf, escala, sacudida)` | **H1 Ignition**: la misma explosión en **rojo carmesí**, **1.5 veces más grande** y **1.5 veces más intensa**: más partículas y más rocas, luz y sacudida más fuertes. El fuego carmesí queda en el suelo 5 s. | 5.8 s |
| `H3_Detonation(rocas, escala, sacudida)` | **H3**: las rocas que dejó el rayo **detonan todas a la vez**. Cada una levanta su racimo de pilares de fuego y entre todas forman una pared de llamas. Los pilares brotan de golpe, se sostienen sin rebotar y se hunden. En la roca más lejana sale un **pilar gigante** de remate. | 2.8 s |
| `H3_DetonationIgnition(rocas, escala, sacudida)` | **H3 Ignition**: lo mismo en carmesí, con pilares más altos, y deja una **marca de fuego** en cada roca unos 3 s. | 4.6 s |

### Otros efectos

| Función | Qué es | Duración |
|---|---|---|
| `Explosion(cf, escala, sacudida)` | Explosión de fuego "realista", la de texturas Kenney. | 1.3 s |
| `ExplosionAnime(cf, escala, sacudida)` | Versión con medias lunas y remolinos (texturas Effekseer). Luce mejor con fondos oscuros. | 1.3 s |
| `FireLine(cf, largo, escala)` | La línea de fuego anterior de la H3. Se conserva por si la quieres usar. | 2.5 s |
| `Shake(intensidad, duración)` | Sacudida de cámara. Solo funciona en el cliente. | — |

Todos los efectos **cierran limpio**: el contenedor se destruye solo cuando ya murió la última partícula, así que nada desaparece de golpe ni queda flotando.

## Instalación (unos 10 minutos)

1. **Inserta el módulo.** En Studio, clic derecho sobre `ReplicatedStorage` > *Insert from File…* > elige `roblox/KaijuFireVFX.rbxmx`.
2. **Sube las texturas.** Ve a *View* > *Asset Manager* > botón *Bulk Import* y selecciona todas las imágenes de `textures/` (no hace falta subir la subcarpeta `_no_usadas`).
3. **Pega los IDs.** En el Asset Manager, clic derecho en cada imagen > *Copy ID to clipboard*. Luego, en el módulo, pega el número en la tabla `TEXTURES`:

   ```lua
   kk_fire_01 = "rbxassetid://123456789",
   ```

   Usa el ID de la **imagen**, no el de un Decal. Si solo vas a usar la H1 y la H3 (con sus versiones Ignition), basta con estas 20 texturas:

   `fx_burst_a, fx_burst_fan, fx_fire_2x2, fx_glow, fx_line, fx_shock_spiky, fx_spark4, fx_star, kk_circle_03, kk_fire_01, kk_fire_02, kk_flare_01, kk_muzzle_01, kk_muzzle_04, kk_muzzle_05, kk_smoke_04, kk_smoke_07, kk_smoke_08, kk_trace_01, kz_scorch`

## Cómo llamarlo

Llámalo desde un **LocalScript**. El servidor avisa a todos los clientes con un RemoteEvent y cada cliente reproduce el efecto. Así no se carga el servidor y la sacudida de cámara funciona.

### H1 (explosión gigante)

`cf` es el punto del **suelo** bajo la explosión; las alturas del efecto se miden desde ahí.

```lua
-- LocalScript (por ejemplo en StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KaijuFireVFX = require(ReplicatedStorage.KaijuFireVFX)
local evento = ReplicatedStorage:WaitForChild("KaijuHabilidadVFX") -- RemoteEvent

evento.OnClientEvent:Connect(function(habilidad: string, datos: any, ignition: boolean)
	if habilidad == "H1" then
		-- datos = punto del suelo donde impacta la espada
		if ignition then
			KaijuFireVFX.GiantExplosionIgnition(CFrame.new(datos), 1, 1)
		else
			KaijuFireVFX.GiantExplosion(CFrame.new(datos), 1, 1)
		end
	elseif habilidad == "H3" then
		-- datos = lista con las rocas del rayo (sus posiciones o sus Parts)
		if ignition then
			KaijuFireVFX.H3_DetonationIgnition(datos, 1, 1)
		else
			KaijuFireVFX.H3_Detonation(datos, 1, 1)
		end
	end
end)
```

### H3 (las rocas del rayo): cómo coordinarla con tus rocas

El efecto se arma **sobre las rocas reales**, así que siempre cae justo donde están:

- **Qué pasarle**: la lista de rocas. Pueden ser **Vector3** (el punto del suelo de cada roca) o directamente las **Parts** (o **Models**) de las rocas. Con Parts o Models, el módulo busca el suelo con un rayo hacia abajo desde cada roca.
- **Cuándo llamarla**: en el **instante en que las rocas explotan**. No hay anticipación: todo detona en el mismo cuadro de la llamada, con una diferencia aleatoria de hasta 0.03 s entre rocas para que no se vea mecánico. En ese mismo momento, borra u oculta tus rocas: las esquirlas en llamas salen de cada una.
- **El orden no importa**: el módulo ordena las rocas a lo largo de la línea. El pilar gigante sale en la roca más lejana a la primera de la lista (el final del rayo).
- **La separación se adapta**: cada racimo de pilares ocupa el espacio hasta sus rocas vecinas, así la pared queda continua. Funciona igual con rocas a 6 o a 34 studs × escala. Si están más separadas, los racimos no llegan a tocarse.

```lua
-- Server (cuando las rocas de la H3 explotan). rocasDelRayo = tabla con las Parts de las rocas
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = rocasDelRayo
local posiciones = {}
for _, roca in rocasDelRayo do
	-- el punto del suelo bajo cada roca
	local hit = workspace:Raycast(roca.Position, Vector3.new(0, -50, 0), params)
	table.insert(posiciones, if hit then hit.Position else roca.Position)
	roca:Destroy()
end
evento:FireAllClients("H3", posiciones, enIgnition)
```

Si las rocas ya existen en el cliente, también puedes pasar las Parts tal cual, siempre que todavía no se hayan borrado.

- **Escala**: con `1`, los pilares de la H3 miden unos 30 studs (hasta unos 42 los más altos), y el pilar gigante unos 63. Para un kaiju más grande prueba de `1.5` a `2`.
- **Sacudida**: `0` o `nil` la desactiva, `1` es normal y `2` es fuerte. La H1 Ignition ya sacude 1.5 veces más que la normal.

### Otros efectos

- En `Explosion` y `ExplosionAnime`, pon `cf` unos `2.5 × escala` studs por encima del suelo. En `FireLine`, `cf` es el inicio de la línea en el suelo.

### Rendimiento

En el pico, la H1 llega a unas 800 partículas, la H1 Ignition a unas 1200, y la H3 y la H3 Ignition a unas 1600 (con 7 rocas). `KaijuFireVFX.Quality = 0.6` reduce las partículas, por ejemplo en celulares.

## Para que se vea como en el video

- La vista previa usa **Bloom**. En `Lighting` agrega un `BloomEffect` con *Intensity* 0.6–1, *Size* 24 y *Threshold* 1.5–2. Si se ve demasiado blanco, sube el *Threshold*.
- Los anillos de choque, la quemadura y el brillo del suelo son **Decals**, para que no les afecte ningún límite de tamaño de partícula. Para que brillen se les pone un Color3 mayor que 1 (sin brillo extra si Roblox lo limitara). Están pensados para suelo plano.
- Los pilares de fuego usan la orientación `FacingCameraWorldUp`: siempre quedan verticales aunque la cámara se incline.
- Las rocas en llamas son Parts reales (Slate oscuro) que se mueven por código y dejan estela. Al caer levantan polvo y dejan fuego unos segundos.

## Licencias de las texturas (todas libres para uso comercial)

- **Kenney Particle Pack** (`kk_*`): CC0, de kenney.nl. El crédito es opcional. Ver `textures/KENNEY_LICENSE.txt`.
- **Muestras oficiales de Effekseer** (`fx_*`): CC0. Agradecen el crédito a "Effekseer" y a los autores de las muestras. Ver `textures/EFFEKSEER_SAMPLES_LICENSE_CC0.txt`.
- **`kz_*`**: generadas aquí, son tuyas.

## Si quieres cambiar algo

- **H3** (pilares, tiempos, colores, separación de rocas): `tools/vfx_pillars.py`.
- **H1**: la explosión gigante está en `tools/vfx_specs.py`. La Ignition se genera desde ella con `ignitionize`, que permite cambiar el tamaño y la intensidad.

Después de editarlos se regenera el módulo con:

```
python tools/gen_luau.py roblox
```

Las pruebas que validan el módulo son estas:
- `tools/test_luau/run_runtime.py`: ejecuta cada efecto contra un Roblox simulado. Comprueba que se limpie todo y, en la H3, que cada roca reciba su explosión y que el remate quede en la última.
- `luau-lsp analyze` con las definiciones de Roblox: verifica que todas las propiedades y métodos existan en la API.
