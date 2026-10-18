# VFX cósmicos de OMNÍVORA: guía de instalación

## Qué hay aquí

| Carpeta / archivo | Para qué sirve |
|---|---|
| `roblox/OmnivoraVFX.rbxmx` | El ModuleScript listo para insertar en Studio. |
| `roblox/OmnivoraVFX.lua` | El mismo código en texto, si prefieres copiar y pegar. |
| `roblox/texturas_necesarias.txt` | Las 33 imágenes que usa el módulo. |
| `textures/` | Las imágenes que hay que subir a Roblox (son exactamente esas 33). |
| `preview/` | Video simulado del efecto. |

Los generadores están en `KaijuZero_VFX/tools/`: el mismo motor genera los módulos de Kaiju Zero, Astral Colossus y Omnívora.

## Efecto incluido

| Función | Qué es | Duración |
|---|---|---|
| `CosmicPillar(cf, radio, altura, escala, sacudida)` | **Pilar cósmico**: en la zona circular elegida brota un **cilindro de energía** que sube (no un pilar sólido). Primero hay una **carga de 0.5 s**: se marca el círculo en el suelo, el suelo se agrieta con luz, la energía y el polvo se absorben hacia el centro, crece un orbe eléctrico y los cubos del suelo levitan temblando. Luego viene la **erupción**, con destello, ondas en el suelo y una explosión de **cubos**. El **pilar dura 2 s**. Es **denso**, casi no se ve a través: azul muy oscuro que se aclara hacia los bordes, con estelas celestes que suben, destellos blancos, anillos que trepan, relámpagos, tres oleadas de energía y estrellas que giran en espiral. Al final **colapsa**: el cuerpo se desvanece, la energía sale disparada hacia arriba y quedan estrellas. | 3 s (los cubos del suelo se desvanecen hasta los 4 s) |
| `Shake(intensidad, duración)` | Sacudida de cámara corta. Solo funciona en el cliente. | — |
| `ShakeRamp(inicial, final, duración)` | Sacudida continua que crece de `inicial` a `final` y se detiene al terminar. Es la que usa el pilar. Solo funciona en el cliente. | — |

**Paleta:** la del modelo de Omnívora. Domina el azul muy oscuro, que se aclara a azul y celeste, con destellos blancos. El púrpura casi rosado de su boca es solo un acento: aparece en los anillos de remolino, en algunos arcos y en algunos cubos. Es más oscura y densa que la de Astral Colossus (lavanda y blanco), para que se distingan.

**Sacudida de cámara:** tiembla sin parar desde que empieza la carga, cada vez más fuerte, y se detiene en el colapso, junto con el pilar.

El efecto **cierra limpio**: el contenedor se destruye solo cuando ya murió la última partícula y desapareció el último cubo.

### Tiempos (para coordinarlo con la animación y con el daño)

| Momento | Qué pasa |
|---|---|
| 0 s | Omnívora elige la zona: aparece el círculo y empieza la carga. **Llama la función en este instante.** |
| 0 – 0.5 s | Carga: el círculo avisa dónde va a salir el pilar. |
| 0.5 s | **Erupción**: sale el pilar y explotan los cubos. |
| 0.5 – 2.5 s | El pilar está activo (oleadas a los 0.95, 1.45 y 1.95 s). |
| 2.5 s | Colapso. |

### La destrucción de cubos

- Son **unos 220 cubos pequeños de tamaños distintos** (escombros, no bloques grandes: la habilidad es enorme). Salen del suelo de la zona con su **mismo color y material**: si el pilar sale sobre pasto, los cubos son de pasto; sobre piedra, de piedra. Si no se encuentra suelo, son de piedra gris.
- **Algunos se desintegran en el aire**: brillan celeste o azul (unos pocos, púrpura rosado) y se encogen hasta desaparecer.
- **Los demás caen**, rebotan, se apoyan sobre una cara, se quedan un momento en el suelo y se desvanecen.
- Durante la carga, unos cubos **levitan temblando** y salen disparados en la erupción. Mientras dura el pilar, **el pilar se traga otros**: giran a su alrededor, suben y se deshacen.
- Además hay cubitos diminutos (partículas) que dan densidad sin costo.
- Son Parts anclados que se mueven por código: no chocan con nada, no empujan a los jugadores y no detectan toques.

Si quieres que los cubos sean siempre de un color o material, ponlo en el módulo:

```lua
OmnivoraVFX.CubeColor = Color3.fromRGB(70, 66, 80)
OmnivoraVFX.CubeMaterial = Enum.Material.Slate
```

## Instalación (unos 10 minutos)

1. **Inserta el módulo.** En Studio, clic derecho sobre `ReplicatedStorage` > *Insert from File…* > elige `roblox/OmnivoraVFX.rbxmx`.
2. **Sube las texturas.** Ve a *View* > *Asset Manager* > botón *Bulk Import* y selecciona todas las imágenes de `textures/`.
3. **Pega los IDs.** En el Asset Manager, clic derecho en cada imagen > *Copy ID to clipboard*. Luego pega el número en la tabla `TEXTURES` del módulo:

   ```lua
   fx_beam = "rbxassetid://123456789",
   ```

   Usa el ID de la **imagen**, no el de un Decal. Algunas imágenes son las mismas que las de Kaiju Zero o Astral Colossus (`fx_glow`, `kk_trace_01`, `kz_scorch`…): si ya las subiste, puedes reutilizar esos IDs.

## Cómo llamarlo

Llámalo desde un **LocalScript**. El servidor avisa a todos los clientes con un RemoteEvent y cada cliente reproduce el efecto. Así no se carga el servidor y la sacudida de cámara funciona.

### Parámetros

- **`cf`**: el **centro de la zona, en el suelo**. Si le pasas un punto un poco por encima o por debajo del suelo, el módulo lo busca con un rayo y apoya el efecto en él. El círculo siempre queda plano.
- **`radio`**: radio de la zona en studs. Si no lo pasas, vale `18 × escala`.
- **`altura`**: altura del pilar en studs. Si no lo pasas, vale `120 × escala`.
- **`escala`**: tamaño general (partículas, cubos y alcance de las luces).
- **`sacudida`**: `0` o `nil` la desactiva, `1` es normal y `2` es fuerte.

Puedes cambiar el radio y la altura por separado: el efecto se adapta y reparte más partículas si el pilar queda más alto o más ancho.

```lua
-- LocalScript (por ejemplo en StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OmnivoraVFX = require(ReplicatedStorage.OmnivoraVFX)
local evento = ReplicatedStorage:WaitForChild("OmnivoraHabilidadVFX") -- RemoteEvent

evento.OnClientEvent:Connect(function(habilidad: string, centro: Vector3, radio: number)
	if habilidad == "Pilar" then
		OmnivoraVFX.CosmicPillar(CFrame.new(centro), radio, nil, 1, 1)
	end
end)
```

```lua
-- Server: cuando Omnívora confirma la zona (centro = el punto del suelo que eligió el jugador)
local RADIO = 18
evento:FireAllClients("Pilar", centro, RADIO)
```

### El daño lo pone tu código

El módulo solo dibuja el efecto. El daño va en tu script del servidor. Para que coincida con lo que se ve, usa el mismo centro, radio y altura:

```lua
local function dentroDelPilar(centro: Vector3, radio: number, altura: number, punto: Vector3): boolean
	local d = Vector3.new(punto.X - centro.X, 0, punto.Z - centro.Z).Magnitude
	return d <= radio and punto.Y >= centro.Y - 3 and punto.Y <= centro.Y + altura
end

-- golpe fuerte en la erupción (0.5 s) y daño continuo mientras dura el pilar (hasta los 2.5 s)
task.delay(0.5, function()
	local fin = os.clock() + 2
	local primero = true
	while os.clock() < fin do
		for _, enemigo in enemigos do
			local raiz = enemigo:FindFirstChild("HumanoidRootPart")
			if raiz and dentroDelPilar(centro, RADIO, 120, raiz.Position) then
				hacerDanio(enemigo, if primero then 40 else 5) -- tu función y tus valores
			end
		end
		primero = false
		task.wait(0.25)
	end
end)
```

### Rendimiento

En el pico hay unas 700 partículas, unos 220 cubos (Parts, movidos todos juntos con `BulkMoveTo`) y unos 85 emisores. `OmnivoraVFX.Quality = 0.6` reduce las partículas y la cantidad de cubos, por ejemplo en celulares.

## Para que se vea como en el video

- La vista previa usa **Bloom**. En `Lighting` agrega un `BloomEffect` con *Intensity* 0.6–1, *Size* 24 y *Threshold* 1.5–2. Si se ve demasiado brillante, sube el *Threshold*.
- El círculo, las grietas, las ondas y la marca oscura del suelo son **Decals** en el plano del centro. Están pensados para suelo plano: en una pendiente fuerte pueden quedar flotando o enterrados.
- El cuerpo denso del pilar son franjas anchas casi opacas (`om_slab`) apiladas, que se dibujan detrás de las estelas y los destellos (`ZOffset`). En el colapso se desvanecen.
- Las estrellas van pegadas a piezas invisibles que giran (`LockedToPart`): por eso suben en espiral.
- En el video, los cubos son grises porque el suelo de la simulación no tiene material. En el juego toman el color y el material del suelo.

## Licencias de las texturas (todas libres para uso comercial)

- **Kenney Particle Pack** (`kk_*`): CC0, de kenney.nl. El crédito es opcional. Ver `textures/KENNEY_LICENSE.txt`.
- **Muestras oficiales de Effekseer** (`fx_*`): CC0. Agradecen el crédito a "Effekseer" y a los autores de las muestras. Ver `textures/EFFEKSEER_SAMPLES_LICENSE_CC0.txt`.
- **`om_*` y `kz_*`**: generadas para este proyecto (los cubitos, las grietas, el cuerpo del pilar y la marca del suelo), son tuyas.

## Si quieres cambiar algo

El efecto está en `KaijuZero_VFX/tools/vfx_omnivora.py`: colores, tiempos de la carga y del pilar, cantidad y tamaño de los cubos (`CUBES`), oleadas, luces. Después de editarlo, regenera los módulos desde la carpeta `KaijuZero_VFX`:

```
python tools/gen_luau.py roblox
```

Eso escribe `KaijuFireVFX`, `AstralColossusVFX` y `OmnivoraVFX` en sus carpetas.

La prueba `KaijuZero_VFX/tools/test_luau/run_runtime.py` ejecuta el efecto contra un Roblox simulado con varios radios y alturas. Comprueba cuatro cosas:
- que se limpie todo;
- que todas las emisiones caigan dentro del cilindro;
- que los cubos tomen el color del suelo y salgan despedidos fuera de la zona;
- que las estrellas y el cuerpo del pilar se borren en el colapso.
