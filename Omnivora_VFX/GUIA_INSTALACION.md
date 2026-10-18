# VFX cósmicos de OMNÍVORA: guía de instalación

## Qué hay aquí

| Carpeta / archivo | Para qué sirve |
|---|---|
| `roblox/OmnivoraVFX.rbxmx` | El ModuleScript listo para insertar en Studio. |
| `roblox/OmnivoraVFX.lua` | El mismo código en texto, si prefieres copiar y pegar. |
| `roblox/texturas_necesarias.txt` | Las 36 imágenes que usa el módulo. |
| `textures/` | Las imágenes que hay que subir a Roblox (son exactamente esas 36). |
| `preview/` | Videos simulados de los efectos. |

Los generadores están en `KaijuZero_VFX/tools/`: el mismo motor genera los módulos de Kaiju Zero, Astral Colossus y Omnívora.

## Efectos incluidos

| Función | Qué es | Duración |
|---|---|---|
| `CosmicPillar(cf, radio, altura, escala, sacudida)` | **Pilar cósmico**: en la zona circular elegida brota un **cilindro de energía** que sube (no un pilar sólido). Primero hay una **carga de 0.5 s**: se marca el círculo en el suelo, el suelo se agrieta con luz, la energía y el polvo se absorben hacia el centro, crece un orbe eléctrico y los cubos del suelo levitan temblando. Luego viene la **erupción**, con destello, ondas en el suelo y una explosión de **cubos**. El **pilar dura 2 s**. Es **denso**, casi no se ve a través, y **cósmico**: por dentro es una nebulosa de azul muy oscuro con vetas azules y púrpura y puntitos de estrella, de bordes ondulados (nada cuadrado). Lleva estelas celestes y púrpura que suben ondulando, velos de aurora, destellos blancos, anillos que trepan, relámpagos, tres oleadas de energía y estrellas que giran en espiral. Al final **colapsa**: el cuerpo se desvanece, la energía sale disparada hacia arriba y quedan estrellas. | 3 s (los cubos del suelo se desvanecen hasta los 4 s) |
| `BlackHole(boca, enemigos, escala, sacudida, radio)` | **Agujero negro**, la habilidad que **golpea a dos enemigos a la vez**. Se forma frente a la boca de Omnívora: la energía y las estrellas se absorben y nace un núcleo negro con su anillo de luz. Después **avanza creciendo** en un arco suave hacia los enemigos. Lleva un disco de acreción que gira (azul celeste y púrpura), materia y estrellas que caen hacia él, una estela de nebulosa oscura con estrellas y ondas de gravedad. **Distorsiona el fondo** detrás de él y levanta polvo y cubitos del suelo. Al llegar **implosiona y detona en medio de los enemigos**: destello, nebulosa que se expande, anillos, rayos, estrellas, ondas y grietas de luz en el suelo, y la **destrucción de cubos** (los que el agujero ya levantaba salen despedidos con los demás). | 3.5 s (los cubos se desvanecen hasta los 5.6 s) |
| `Shake(intensidad, duración)` | Sacudida de cámara corta. Solo funciona en el cliente. | — |
| `ShakeRamp(inicial, final, duración)` | Sacudida continua que crece de `inicial` a `final` y se detiene al terminar. La usan el pilar y el agujero negro. Solo funciona en el cliente. | — |

**Paleta:** la del modelo de Omnívora. Domina el azul muy oscuro, que se aclara a azul y celeste, con destellos blancos. El púrpura intenso de su boca acompaña sin dominar: está en las vetas de la nebulosa, en estelas y auroras que suben entre las celestes, en destellos que giran, en los anillos de remolino y en algunos cubos. Es más oscura y densa que la de Astral Colossus (lavanda y blanco), para que se distingan.

**Sacudida de cámara:** en el pilar tiembla sin parar desde que empieza la carga, cada vez más fuerte, y se detiene en el colapso, junto con el pilar. En el agujero negro tiembla suave mientras se acerca, cada vez más, y fuerte al detonar.

Los dos efectos **cierran limpio**: el contenedor se destruye solo cuando ya murió la última partícula y desapareció el último cubo.

### Pilar cósmico: tiempos (para coordinarlo con la animación y con el daño)

| Momento | Qué pasa |
|---|---|
| 0 s | Omnívora elige la zona: aparece el círculo y empieza la carga. **Llama la función en este instante.** |
| 0 – 0.5 s | Carga: el círculo avisa dónde va a salir el pilar. |
| 0.5 s | **Erupción**: sale el pilar y explotan los cubos. |
| 0.5 – 2.5 s | El pilar está activo (oleadas a los 0.95, 1.45 y 1.95 s). |
| 2.5 s | Colapso. |

### Agujero negro: tiempos (para el combate por turnos)

El agujero siempre tarda lo mismo en llegar, estén los enemigos cerca o lejos: el turno dura igual.

| Momento | Qué pasa |
|---|---|
| 0 s | Omnívora abre la boca: el agujero empieza a formarse. **Llama la función en este instante.** |
| 0 – 0.55 s | Formación frente a la boca. |
| 0.55 – 1.95 s | Avanza hacia los enemigos y crece. La cámara tiembla cada vez más. |
| 1.95 – 2.1 s | Implosiona. |
| **2.1 s** | **Detona.** Aplica aquí el daño a los dos enemigos (`OmnivoraVFX.BlackHoleImpact` vale 2.1). |
| hasta 3.5 s | Se disipa la nebulosa; los cubos caen y se desvanecen hasta los 5.6 s. |

### La destrucción de cubos

- Son **unos 220 cubos pequeños de tamaños distintos** (escombros, no bloques grandes: la habilidad es enorme). Salen del suelo de la zona con su **mismo color y material**: si el pilar sale sobre pasto, los cubos son de pasto; sobre piedra, de piedra. Si no se encuentra suelo, son de piedra gris.
- **Algunos se desintegran en el aire**: brillan celeste o azul (unos pocos, púrpura rosado) y se encogen hasta desaparecer.
- **Los demás caen**, rebotan, se apoyan sobre una cara, se quedan un momento en el suelo y se desvanecen.
- Durante la carga, unos cubos **levitan temblando** y salen disparados en la erupción. Mientras dura el pilar, **el pilar se traga otros**: giran a su alrededor, suben y se deshacen.
- Además hay cubitos diminutos (partículas) que dan densidad sin costo.
- Son Parts anclados que se mueven por código: no chocan con nada, no empujan a los jugadores y no detectan toques.

En el agujero negro pasa lo mismo en la zona de la detonación: cuando el agujero llega, unos 30 cubos del suelo **levitan atraídos** por él, y al detonar salen despedidos con otros 150.

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

### Pilar cósmico: parámetros

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

### Agujero negro: parámetros

- **`boca`**: dónde se forma, normalmente un Attachment en la boca del modelo de Omnívora (`Vector3` o `CFrame`).
- **`enemigos`**: un enemigo o una lista. Cada uno puede ser un `Vector3`, una `BasePart` (por ejemplo el `HumanoidRootPart`) o un `Model`. El agujero vuela hasta el **centro de los enemigos**, a unos 16 studs × escala sobre el suelo, y detona ahí. La explosión **los cubre a todos**: su radio llega hasta el enemigo más lejano del centro más 14 studs × escala, y como mínimo mide 28 × escala. Si la lista está vacía y `boca` es un `CFrame`, sale 140 studs × escala hacia adelante.
- **`escala`**: tamaño general. Al llegar, el núcleo negro mide unos 20 studs de ancho y el disco unos 90 (× escala). Con `escala` 0.5 se ve como la primera versión, que era la mitad de grande.
- **`sacudida`**: `0` o `nil` la desactiva, `1` es normal y `2` es fuerte.
- **`radio`** (opcional): fuerza el radio de la detonación en studs.

```lua
-- LocalScript (el mismo que escucha el RemoteEvent de Omnívora)
evento.OnClientEvent:Connect(function(habilidad: string, boca: Vector3, enemigos: { Instance })
	if habilidad == "AgujeroNegro" then
		OmnivoraVFX.BlackHole(boca, enemigos, 1, 1)
	end
end)
```

```lua
-- Server: en el turno de Omnívora, contra dos enemigos
local boca = omnivora.Head.Boca.WorldPosition -- un Attachment en la boca del modelo
local objetivos = { enemigo1, enemigo2 } -- los Models de los enemigos
evento:FireAllClients("AgujeroNegro", boca, objetivos)
task.delay(2.1, function() -- cuando detona (OmnivoraVFX.BlackHoleImpact)
	for _, enemigo in objetivos do
		hacerDanio(enemigo, 60) -- tu función y tus valores
	end
end)
```

### El daño lo pone tu código (pilar)

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

En el pico, el pilar tiene unas 800 partículas, unos 220 cubos (Parts, movidos todos juntos con `BulkMoveTo`) y unos 97 emisores. El agujero negro llega a unas 400 partículas y 180 cubos. `OmnivoraVFX.Quality = 0.6` reduce las partículas y la cantidad de cubos, por ejemplo en celulares.

## Para que se vea como en el video

- La vista previa usa **Bloom**. En `Lighting` agrega un `BloomEffect` con *Intensity* 0.6–1, *Size* 24 y *Threshold* 1.5–2. Si se ve demasiado brillante, sube el *Threshold*.
- El círculo, las grietas, las ondas y la marca oscura del suelo son **Decals** en el plano del centro. Están pensados para suelo plano: en una pendiente fuerte pueden quedar flotando o enterrados.
- El cuerpo del pilar es `om_nebula_2x2`: una textura que ya trae sus colores (nebulosa, estrellas, bordes ondulados), por eso su `Color` es blanco. Son franjas casi opacas apiladas que se dibujan detrás de las estelas y los destellos (`ZOffset`). En el colapso se desvanecen.
- Las estrellas van pegadas a piezas invisibles que giran (`LockedToPart`): por eso suben en espiral.
- En el video, los cubos son grises porque el suelo de la simulación no tiene material. En el juego toman el color y el material del suelo.
- **La distorsión del agujero negro** es una esfera de vidrio (`Glass`) que va detrás del agujero, del lado contrario a la cámara, y crece con él. Roblox solo dibuja esa refracción **con gráficos altos**. En celulares o con gráficos bajos se ve como un halo azul oscuro muy tenue. Además, a través del vidrio no se ven partículas: por eso va detrás y las partículas del agujero quedan por delante. Si no la quieres, pon `OmnivoraVFX.Lens = false`.
- El disco inclinado del agujero se orienta hacia la cámara en el momento de la llamada, así se ve abierto desde cualquier ángulo. El disco que gira de frente siempre mira a la cámara.
- Los muñecos grises del video solo marcan dónde estarían los dos enemigos.

## Licencias de las texturas (todas libres para uso comercial)

- **Kenney Particle Pack** (`kk_*`): CC0, de kenney.nl. El crédito es opcional. Ver `textures/KENNEY_LICENSE.txt`.
- **Muestras oficiales de Effekseer** (`fx_*`): CC0. Agradecen el crédito a "Effekseer" y a los autores de las muestras. Ver `textures/EFFEKSEER_SAMPLES_LICENSE_CC0.txt`.
- **`om_*` y `kz_*`**: generadas para este proyecto (los cubitos, las grietas, el cuerpo del pilar, el núcleo del agujero negro y la marca del suelo), son tuyas.

## Si quieres cambiar algo

El pilar está en `KaijuZero_VFX/tools/vfx_omnivora.py`: colores, tiempos de la carga y del pilar, cantidad y tamaño de los cubos (`CUBES`), oleadas, luces. El agujero negro está en `KaijuZero_VFX/tools/vfx_blackhole.py`: tiempos de la formación, del avance y de la detonación, tamaño, altura, arco, la lente, las capas del agujero y los cubos (`CUBES_BH`). Después de editarlo, regenera los módulos desde la carpeta `KaijuZero_VFX`:

```
python tools/gen_luau.py roblox
```

Eso escribe `KaijuFireVFX`, `AstralColossusVFX` y `OmnivoraVFX` en sus carpetas.

La prueba `KaijuZero_VFX/tools/test_luau/run_runtime.py` ejecuta los efectos contra un Roblox simulado. En el pilar usa varios radios y alturas y comprueba cuatro cosas:
- que se limpie todo;
- que todas las emisiones caigan dentro del cilindro;
- que los cubos tomen el color del suelo y salgan despedidos fuera de la zona;
- que las estrellas y el cuerpo del pilar se borren en el colapso.

En el agujero negro prueba dos enemigos, enemigos como Parts y Models con escala 1.5, uno solo y ninguno. Comprueba que salga de la boca, que llegue sobre el centro de los enemigos, que la lente crezca con él, que los cubos tomen el color del suelo y salgan despedidos, y que se limpie todo.
