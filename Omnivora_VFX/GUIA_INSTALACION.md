# VFX cósmicos de OMNÍVORA: guía de instalación

## Qué hay aquí

| Carpeta / archivo | Para qué sirve |
|---|---|
| `roblox/OmnivoraVFX.rbxmx` | El ModuleScript listo para insertar en Studio. |
| `roblox/OmnivoraVFX.lua` | El mismo código en texto, si prefieres copiar y pegar. |
| `roblox/texturas_necesarias.txt` | Las 41 imágenes que usa el módulo. |
| `textures/` | Las imágenes que hay que subir a Roblox (son exactamente esas 41). |
| `preview/` | Videos simulados de los efectos. |

Los generadores están en `KaijuZero_VFX/tools/`: el mismo motor genera los módulos de Kaiju Zero, Astral Colossus y Omnívora.

## Efectos incluidos

| Función | Qué es | Duración |
|---|---|---|
| `CosmicPillar(cf, radio, altura, escala, sacudida)` | **Pilar cósmico**: en la zona circular elegida brota un **cilindro de energía** que sube (no un pilar sólido). Primero hay una **carga de 0.5 s**: se marca el círculo en el suelo, el suelo se agrieta con luz, la energía y el polvo se absorben hacia el centro, crece un orbe eléctrico y los cubos del suelo levitan temblando. Luego viene la **erupción**, con destello, ondas en el suelo y una explosión de **cubos**. El **pilar dura 2 s**. Es **denso**, casi no se ve a través, y **cósmico**: por dentro es una nebulosa de azul muy oscuro con vetas azules y púrpura y puntitos de estrella, de bordes ondulados (nada cuadrado). Lleva estelas celestes y púrpura que suben ondulando, velos de aurora, destellos blancos, anillos que trepan, relámpagos, tres oleadas de energía y estrellas que giran en espiral. Al final **colapsa**: el cuerpo se desvanece, la energía sale disparada hacia arriba y quedan estrellas. | 3 s (los cubos del suelo se desvanecen hasta los 4 s) |
| `BlackHole(boca, enemigos, escala, sacudida, radio)` | **Agujero negro**, la habilidad que **golpea a dos enemigos a la vez**. Se forma frente a la boca de Omnívora: la energía y las estrellas se absorben y nace un núcleo negro con su anillo de luz. Después **avanza creciendo** en un arco suave hacia los enemigos. Lleva un disco de acreción que gira (azul celeste y púrpura), materia y estrellas que caen hacia él, una estela de nebulosa oscura con estrellas y ondas de gravedad. **Distorsiona el fondo** detrás de él y levanta polvo y cubitos del suelo. Al llegar **implosiona y detona en medio de los enemigos**: destello, nebulosa que se expande, anillos, rayos, estrellas, ondas y grietas de luz en el suelo, y la **destrucción de cubos** (los que el agujero ya levantaba salen despedidos con los demás). | 3.5 s (los cubos se desvanecen hasta los 5.6 s) |
| `CosmicBeam(origen, objetivo, escala, sacudida, ignorar)` | **Rayo cósmico** de 3 s que **se puede apuntar** mientras dura. La boca de Omnívora **devora energía y estrellas** un instante (estelas que caen hacia ella, un disco púrpura que gira) y suelta un rayo de **nebulosa**: un cuerpo denso de azul muy oscuro con venas celestes, manchas púrpura y estrellas, envuelto en hebras de energía celestes y púrpura, con el núcleo blanco. En la boca gira el disco púrpura y se abren anillos. A lo largo del rayo **viajan anillos y remolinos**, saltan relámpagos y suben auroras, y deja una **estela cósmica** de nebulosa y estrellas que se queda flotando cuando lo mueves. Se corta en la **primera superficie que toca** y, si no toca nada, llega a su **largo máximo de 124 studs** × escala. Donde pega: destello, halo, ondas, la nebulosa que estalla, estelas, **cubitos** que salen volando y **grietas de luz** en el suelo. Si **barres el suelo** deja una estela de grietas. | 3.6 s (las marcas del suelo se borran unos 3 s después de hechas) |
| `Shake(intensidad, duración)` | Sacudida de cámara corta. Solo funciona en el cliente. | — |
| `ShakeRamp(inicial, final, duración)` | Sacudida continua que crece de `inicial` a `final` y se detiene al terminar. La usan el pilar y el agujero negro. Solo funciona en el cliente. | — |

**Paleta:** la del modelo de Omnívora. Domina el azul muy oscuro, que se aclara a azul y celeste, con destellos blancos. El púrpura intenso de su boca acompaña sin dominar: está en las vetas de la nebulosa, en estelas y auroras que suben entre las celestes, en destellos que giran, en los anillos de remolino y en algunos cubos. Es más oscura y densa que la de Astral Colossus (lavanda y blanco), para que se distingan.

**Sacudida de cámara:** en el pilar tiembla sin parar desde que empieza la carga, cada vez más fuerte, y se detiene en el colapso, junto con el pilar. En el agujero negro tiembla suave mientras se acerca, cada vez más, y fuerte al detonar. En el rayo tiembla mientras dura, cada vez más, con un golpe cuando llega y otro suave al cortarse.

Los tres efectos **cierran limpio**: el contenedor se destruye solo cuando ya murió la última partícula y desapareció el último cubo.

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

### Rayo cósmico: tiempos

| Momento | Qué pasa |
|---|---|
| 0 – 0.3 s | La boca devora energía y estrellas. **Llama la función cuando la animación abre la boca.** |
| 0.3 s | Dispara: destello en la boca y la punta sale disparada. |
| 0.4 s | La punta llega a donde pega (o a su largo máximo): destello, halo, ondas y el impacto queda activo. Es `OmnivoraVFX.CosmicBeamStart`. |
| 0.4 – 3.3 s | El rayo se sostiene y lo puedes mover. |
| 3.3 s | Se **corta** solo (o antes, si llamas `rayo:Stop()`): se adelgaza y se apaga en 0.3 s, con un último destello y estrellas en la punta. Es `OmnivoraVFX.CosmicBeamStop`. |
| después | La estela de nebulosa y estrellas se disipa en 1 – 1.5 s. Las marcas del suelo se borran solas unos 3 s después de hechas. |

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

### Rayo cósmico: cómo apuntarlo

La función devuelve un **control** con el que mueves el rayo mientras dura. Cada cuadro el módulo lanza un Raycast desde la boca: el rayo **se corta en la primera superficie que toca** (el rival, una pared, el suelo) y, si apunta al aire, llega a su **largo máximo: 124 studs × escala** (el mismo largo que la primera versión del rayo de Kaiju Zero). Al apuntarlo a otro lado se acorta o se alarga solo.

- **`origen`**: de dónde sale. Lo mejor es un **`Attachment` en la boca** del modelo: el rayo lo sigue solo si Omnívora se mueve o gira la cabeza. También acepta una Part, un `Vector3` o un `CFrame`.
- **`objetivo`**: hacia dónde apunta al salir. Un **Model** o una **Part** (si se mueve, el rayo lo sigue) o un punto (`Vector3` o `CFrame`). Si pasas `nil` y el origen es un `CFrame`, sale hacia donde mira ese CFrame.
- **`escala`**: tamaño general. Con `1`, el cuerpo de nebulosa mide unos 27 studs de ancho, el núcleo blanco unos 4 y el halo azul unos 46.
- **`sacudida`**: `0` o `nil` la desactiva, `1` es normal y `2` es fuerte.
- **`ignorar`** (opcional): lo que el rayo atraviesa. Pasa siempre `{ modeloDeOmnivora }`, así no choca con su propia cabeza.

Lo que devuelve:

| | Para qué sirve |
|---|---|
| `rayo:AimAt(objetivo)` | Apunta a otro lado: un Model, una Part, un `Vector3` o un `CFrame`. Si es un Model o una Part, lo sigue. |
| `rayo:SetDirection(dir)` | Apunta en una dirección (`Vector3`), por ejemplo la de la cámara. |
| `rayo:SetOrigin(origen)` | Cambia de dónde sale (Attachment, Part, `Vector3` o `CFrame`). |
| `rayo:Stop()` | Lo corta antes de tiempo: se adelgaza y se apaga igual que al final. |
| `rayo.MaxLength` | El largo máximo (124 × escala). Lo puedes cambiar mientras dura. |
| `rayo.Length` | Cuánto mide en este momento. |
| `rayo.HitPosition`, `rayo.HitInstance` | Dónde pega y qué toca (`nil` si apunta al aire). |
| `rayo.Active` | `true` mientras el rayo se ve. |
| `rayo.Holder` | La Part que contiene todo el efecto. |

El impacto sigue a la punta. Cada vez que el rayo **empieza a pegar en algo** después de pasar por el aire, revientan otra vez el destello, el halo, la nebulosa, los cubitos y las grietas grandes del suelo (como mucho una vez cada 0.3 s). Si **barre el suelo**, va dejando una **estela de grietas de luz** sobre una marca oscura, que se borra en unos 2 s.

**En el combate por turnos** (apunta al rival y lo sigue):

```lua
-- Server: evento:FireAllClients("Rayo", { omnivora = modeloDeOmnivora, rival = modeloDelRival })

-- LocalScript (el mismo que escucha el RemoteEvent de Omnívora)
evento.OnClientEvent:Connect(function(habilidad: string, datos: any)
	if habilidad == "Rayo" then
		local boca = datos.omnivora.Head.Boca -- un Attachment en la boca del modelo
		OmnivoraVFX.CosmicBeam(boca, datos.rival, 1, 1, { datos.omnivora })
	end
end)
```

**Apuntado con el mouse** por el jugador que lo lanza:

```lua
-- LocalScript del jugador que lanza el rayo
local RunService = game:GetService("RunService")
local mouse = game:GetService("Players").LocalPlayer:GetMouse()
-- boca = el Attachment de la boca; omnivora = el modelo de Omnívora

local rayo = OmnivoraVFX.CosmicBeam(boca, mouse.Hit.Position, 1, 1, { omnivora })
local conexion
conexion = RunService.RenderStepped:Connect(function()
	if not rayo.Active then
		conexion:Disconnect()
		return
	end
	rayo:AimAt(mouse.Hit.Position) -- sigue al mouse; se acorta o se alarga solo
end)
```

Para que los demás jugadores lo vean moverse, el que lo lanza manda a dónde apunta unas 20 veces por segundo (un `UnreliableRemoteEvent` va bien) y el servidor lo reenvía a los demás. Cada cliente guarda el rayo que creó y le llama `rayo:AimAt(punto)` con lo que llega.

**El daño** va en el servidor. Haz el mismo Raycast que el módulo, desde la boca, con el mismo largo máximo y hacia el último punto al que apuntó el jugador:

```lua
-- Server: daño por tics mientras el rayo pega (de 0.4 a 3.3 s).
-- puntoApuntado = el último punto que mandó el jugador (al principio, la posición del rival)
local LARGO = 124 -- × la escala que uses en CosmicBeam
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { modeloDeOmnivora }
local fin = os.clock() + OmnivoraVFX.CosmicBeamStop
task.delay(OmnivoraVFX.CosmicBeamStart, function()
	while os.clock() < fin do
		local desde = boca.WorldPosition
		local hit = workspace:Raycast(desde, (puntoApuntado - desde).Unit * LARGO, params)
		local modelo = hit and hit.Instance:FindFirstAncestorOfClass("Model")
		if modelo and modelo:FindFirstChildOfClass("Humanoid") then
			hacerDanio(modelo, 5) -- tu función y tus valores
		end
		task.wait(0.2)
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

En el pico, el pilar tiene unas 800 partículas, unos 220 cubos (Parts, movidos todos juntos con `BulkMoveTo`) y unos 97 emisores. El agujero negro llega a unas 400 partículas y 180 cubos. El rayo cósmico se mantiene en unas 370 partículas, con 6 Beams; al barrer el suelo deja hasta unas 10 marcas por segundo (Decals), que se borran solas. `OmnivoraVFX.Quality = 0.6` reduce las partículas y la cantidad de cubos, por ejemplo en celulares.

## Para que se vea como en el video

- La vista previa usa **Bloom**. En `Lighting` agrega un `BloomEffect` con *Intensity* 0.6–1, *Size* 24 y *Threshold* 1.5–2. Si se ve demasiado brillante, sube el *Threshold*.
- El círculo, las grietas, las ondas y la marca oscura del suelo son **Decals** en el plano del centro. Están pensados para suelo plano: en una pendiente fuerte pueden quedar flotando o enterrados.
- El cuerpo del pilar es `om_nebula_2x2`: una textura que ya trae sus colores (nebulosa, estrellas, bordes ondulados), por eso su `Color` es blanco. Son franjas casi opacas apiladas que se dibujan detrás de las estelas y los destellos (`ZOffset`). En el colapso se desvanecen.
- Las estrellas van pegadas a piezas invisibles que giran (`LockedToPart`): por eso suben en espiral.
- En el video, los cubos son grises porque el suelo de la simulación no tiene material. En el juego toman el color y el material del suelo.
- **La distorsión del agujero negro** es una esfera de vidrio (`Glass`) que va detrás del agujero, del lado contrario a la cámara, y crece con él. Roblox solo dibuja esa refracción **con gráficos altos**. En celulares o con gráficos bajos se ve como un halo azul oscuro muy tenue. Además, a través del vidrio no se ven partículas: por eso va detrás y las partículas del agujero quedan por delante. Si no la quieres, pon `OmnivoraVFX.Lens = false`.
- El disco inclinado del agujero se orienta hacia la cámara en el momento de la llamada, así se ve abierto desde cualquier ángulo. El disco que gira de frente siempre mira a la cámara.
- Los muñecos grises del video solo marcan dónde estarían los dos enemigos (y, en el rayo, Omnívora y el rival).
- El cuerpo del **rayo cósmico** son 6 **Beams** de Roblox entre la boca y la punta: el halo azul, el cuerpo de nebulosa (`om_beam_nebula`, que trae sus propios colores, por eso su `Color` es blanco), las hebras celestes y púrpura (`om_beam_flow`), el polvo de estrellas (`om_beam_stars`) y el núcleo blanco. Usan `FaceCamera` y sus texturas corren hacia la punta a distintas velocidades: la nebulosa deriva despacio y las hebras corren rápido. Cada cuadro, un Raycast desde la boca decide hasta dónde llega la punta; las piezas del efecto tienen `CanQuery` apagado, así que ni ese Raycast ni el mouse las tocan.
- En el video, el rayo sigue un recorrido de prueba: pega en el rival, baja y barre el suelo (se acorta), sube al cielo (llega a su máximo) y vuelve al rival. Abajo a la izquierda se ve cuánto mide en cada momento.

## Licencias de las texturas (todas libres para uso comercial)

- **Kenney Particle Pack** (`kk_*`): CC0, de kenney.nl. El crédito es opcional. Ver `textures/KENNEY_LICENSE.txt`.
- **Muestras oficiales de Effekseer** (`fx_*`): CC0. Agradecen el crédito a "Effekseer" y a los autores de las muestras. Ver `textures/EFFEKSEER_SAMPLES_LICENSE_CC0.txt`.
- **`om_*` y `kz_*`**: generadas para este proyecto (los cubitos, las grietas, el cuerpo del pilar, el núcleo del agujero negro, la marca del suelo y las del rayo cósmico, `om_beam_*`), son tuyas.

## Si quieres cambiar algo

El pilar está en `KaijuZero_VFX/tools/vfx_omnivora.py`: colores, tiempos de la carga y del pilar, cantidad y tamaño de los cubos (`CUBES`), oleadas, luces. El agujero negro está en `KaijuZero_VFX/tools/vfx_blackhole.py`: tiempos de la formación, del avance y de la detonación, tamaño, altura, arco, la lente, las capas del agujero y los cubos (`CUBES_BH`). El rayo cósmico está en `KaijuZero_VFX/tools/vfx_cosmicbeam.py`: arriba los tiempos (`START`, `GROW`, `STOP`, `FADE`), en `BEAMS` el ancho, el color y la velocidad de cada capa del rayo, y al final, en `"beam"`, el largo máximo (`max_len`: 124), cada cuánto deja marcas al barrer (`trail_every`, `trail_move`) y el tiempo mínimo entre impactos (`rehit`). Sus texturas (`om_beam_*`) salen de `KaijuZero_VFX/tools/gen_cosmic_beam_textures.py`. Después de editarlo, regenera los módulos desde la carpeta `KaijuZero_VFX`:

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

En el rayo cósmico comprueba que sin nada delante llegue a su largo máximo (124), que se corte en el suelo, que se acorte y deje marcas al barrer el suelo, que vuelva a su máximo al apuntar al cielo, que siga a un objetivo que se mueve y a un origen nuevo, y que `Stop()` lo apague y se limpie todo.
