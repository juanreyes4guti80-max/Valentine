# VFX cósmicos de OMNÍVORA: guía de instalación

## Cómo descargar los archivos

Hay dos caminos y los dos te dan la misma carpeta `Omnivora_VFX`.

**A. El ZIP del chat (lo más fácil).** Descarga `Omnivora_VFX.zip` y descomprímelo. En Windows: clic derecho > *Extraer todo…*. En Mac: doble clic. Te queda la carpeta `Omnivora_VFX` con esta guía, `roblox/` y `textures/` (con sus licencias).

**B. Desde GitHub.**

1. Abre el repositorio `juanreyes4guti80-max/Valentine` en github.com.
2. Arriba a la izquierda está el botón de la rama (dice `main`). Elige **`claude/inspiring-fermi-z0y6if`**, que es donde está la última versión.
3. Botón verde **Code** > **Download ZIP**.
4. Descomprime el ZIP. Lo de Omnívora está en la carpeta `Omnivora_VFX`, lo de Kaiju Zero en `KaijuZero_VFX` y lo de Astral Colossus en `AstralColossus_VFX`. Los videos de cada uno están en su carpeta `preview/`.

Si solo quieres un archivo (por ejemplo el módulo actualizado), ábrelo en GitHub y toca **Download raw file**: es la flecha hacia abajo, arriba a la derecha del archivo.

**Lo que vas a usar en Studio:**

| Archivo | Para qué |
|---|---|
| `roblox/OmnivoraVFX.rbxmx` | El módulo con todos los efectos, también la ULTIMATE. |
| `textures/` | Las 43 imágenes que hay que subir a Roblox. |
| `roblox/CataclysmDemo.client.lua` | La escena de prueba de la ULTIMATE (opcional). |

**Si ya tenías una versión anterior del módulo**, cópiate los IDs de su tabla `TEXTURES` antes de borrarlo. Los nombres no cambian, así que los pegas igual en el módulo nuevo y solo subes las imágenes que te falten (compara con `roblox/texturas_necesarias.txt`). La ULTIMATE no trae texturas nuevas: usa las mismas 43. Si usas también los módulos de Kaiju Zero o de Astral Colossus, actualízalos a la vez: los tres comparten la sacudida de cámara.

## Qué hay aquí

| Carpeta / archivo | Para qué sirve |
|---|---|
| `roblox/OmnivoraVFX.rbxmx` | El ModuleScript listo para insertar en Studio. |
| `roblox/OmnivoraVFX.lua` | El mismo código en texto, si prefieres copiar y pegar. |
| `roblox/CataclysmDemo.client.lua` | La escena de prueba de la ULTIMATE: la ves completa sin el modelo de Omnívora, desde una cámara fija, y puedes saltar a cualquier fase. |
| `roblox/texturas_necesarias.txt` | Las 43 imágenes que usa el módulo. |
| `textures/` | Las imágenes que hay que subir a Roblox (son exactamente esas 43). |
| `preview/` | Videos simulados de los efectos. |

Los generadores están en `KaijuZero_VFX/tools/`: el mismo motor genera los módulos de Kaiju Zero, Astral Colossus y Omnívora.

## Efectos incluidos

| Función | Qué es | Duración |
|---|---|---|
| `CosmicPillar(cf, radio, altura, escala, sacudida)` | **Pilar cósmico**: en la zona circular elegida brota un **cilindro de energía** que sube (no un pilar sólido). Primero hay una **carga de 0.5 s**: se marca el círculo en el suelo, el suelo se agrieta con luz, la energía y el polvo se absorben hacia el centro, crece un orbe eléctrico y los cubos del suelo levitan temblando. Luego viene la **erupción**, con destello, ondas en el suelo y una explosión de **cubos**. El **pilar dura 2 s**. Es **denso**, casi no se ve a través, y **cósmico**: por dentro es una nebulosa de azul muy oscuro con vetas azules y púrpura y puntitos de estrella, de bordes ondulados (nada cuadrado). Lleva estelas celestes y púrpura que suben ondulando, velos de aurora, destellos blancos, anillos que trepan, relámpagos, tres oleadas de energía y estrellas que giran en espiral. Al final **colapsa**: el cuerpo se desvanece, la energía sale disparada hacia arriba y quedan estrellas. | 3 s (los cubos del suelo se desvanecen hasta los 4 s) |
| `BlackHole(boca, enemigos, escala, sacudida, radio)` | **Agujero negro**, la habilidad que **golpea a dos enemigos a la vez**. Se forma frente a la boca de Omnívora: la energía y las estrellas se absorben y nace un núcleo negro con su anillo de luz. Después **avanza creciendo** en un arco suave hacia los enemigos. Lleva un disco de acreción que gira (azul celeste y púrpura), materia y estrellas que caen hacia él, una estela de nebulosa oscura con estrellas y ondas de gravedad. **Distorsiona el fondo** detrás de él y levanta polvo y cubitos del suelo. Al llegar **implosiona y detona en medio de los enemigos**: destello, nebulosa que se expande, anillos, rayos, estrellas, ondas y grietas de luz en el suelo, y la **destrucción de cubos** (los que el agujero ya levantaba salen despedidos con los demás). | 3.5 s (los cubos se desvanecen hasta los 5.6 s) |
| `CosmicBeam(origen, objetivo, escala, sacudida, ignorar)` | **Rayo cósmico** de 3 s que **se puede apuntar** mientras dura. La boca de Omnívora **devora energía y estrellas** un instante (estelas que caen hacia ella, un disco púrpura que gira) y suelta un rayo de **nebulosa**: un cuerpo denso de azul muy oscuro con venas celestes, manchas púrpura y estrellas, envuelto en hebras de energía celestes y púrpura, con el núcleo blanco. En la boca gira el disco púrpura y se abren anillos. A lo largo del rayo **viajan anillos y remolinos**, saltan relámpagos y suben auroras, y deja una **estela cósmica** de nebulosa y estrellas que se queda flotando cuando lo mueves. Se corta en la **primera superficie que toca** y, si no toca nada, llega a su **largo máximo de 124 studs** × escala. Donde pega: destello, halo, ondas, la nebulosa que estalla, estelas, **cubitos** que salen volando y **grietas de luz** en el suelo. Si **barres el suelo** deja una estela de grietas. | 3.6 s (las marcas del suelo se borran unos 3 s después de hechas) |
| `CosmicAura(modelo, escala, duración, intensidad)` | **Aura cósmica** que se adapta a cualquier modelo. Delinea todo el cuerpo en celeste que respira hacia el púrpura y de toda su silueta emanan lenguas de nebulosa azul muy oscura con venas celestes, energía celeste y púrpura, estrellas y chispas; a los pies, anillos y destellos que suben. | hasta que la apagues |
| `GravitationalCataclysm(epicentro, víctimas, opciones)` | **ULTIMATE: Cataclismo gravitacional** en un radio de **500 m** (1786 studs). La gravedad desaparece y el terreno se levanta. La materia forma una tormenta cósmica colosal, sobre el epicentro nace una singularidad que se traga la tormenta y a las víctimas, acumula energía hasta un destello blanco y detona, y las víctimas se estrellan contra el suelo. Todo lo mueve **una sola fuerza gravitacional**. Tiene su propia sección más abajo. | 23 s: 17.6 s de habilidad y 5.4 s de secuelas |
| `CataclysmImpact(cf, escala, sacudida)` | El impacto de una víctima contra el suelo. Lo usa la ULTIMATE, pero también lo puedes llamar tú. | 5.6 s |
| `Shake(intensidad, duración)` | Sacudida de cámara corta. Solo funciona en el cliente. Si se juntan varias sacudidas, de este módulo o de los de Kaiju Zero y Astral Colossus, se suman y al terminar la cámara vuelve exacta a su sitio. | — |
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

### Aura (CosmicAura)

Un aura que **se adapta sola a cualquier modelo**: le pasas el Model y el módulo recorre sus partes, mide su alto y la arma encima. No hace falta ajustar nada a mano para Omnívora.

```lua
-- LocalScript (en todos los clientes, igual que los demás efectos)
local aura = OmnivoraVFX.CosmicAura(modeloDeOmnivora, 1)   -- encendida hasta que la apagues
aura:SetIntensity(1.5)                 -- más fuerte (0.5 = suave)
aura:Stop()                            -- se desvanece en 0.7 s y se limpia sola

OmnivoraVFX.CosmicAura(modeloDeOmnivora, 1, 5)             -- o con duración: 5 s y se apaga sola
```

- **`model`**: el Model (o una Part). **`escala`**: multiplica el tamaño (por defecto 1). **`duración`**: segundos, o `nil` para dejarla encendida. **`intensidad`**: 1 normal.
- **Qué la forma**: un **delineado de todo el cuerpo** (un `Highlight` de Roblox) que respira entre celeste y púrpura, y lenguas de energía que **emanan de toda la silueta** y suben, con estrellas, chispas y estelas; a los pies, anillos que se abren y destellos que suben. Las lenguas grandes son de la misma nebulosa que el pilar y el rayo. Cada 2.2 s hay una **oleada**: el delineado se enciende y sale una ráfaga.
- **Cómo se adapta**: pone un emisor en cada parte visible del modelo (las 30 más grandes; la tasa se reparte según el tamaño de cada una, así brota de toda la silueta por igual). Se salta la `HumanoidRootPart` y las partes invisibles (hitboxes). El tamaño de todo crece con el alto del modelo (22 studs = tamaño 1): en un kaiju de 200 studs se ve igual de proporcionada.
- **Sigue las animaciones**: los emisores van dentro de las partes del modelo, así que se mueven con él. Lo que ya salió se queda atrás un momento, por eso al caminar deja estela.
- **Al apagarla** borra todo lo que puso (también los emisores de dentro de tus partes). Si el modelo se destruye, el aura se limpia sola.
- **Ten en cuenta**: Roblox muestra como mucho 31 `Highlight` a la vez, y si el modelo ya tiene uno propio solo se ve uno de los dos. En las MeshParts las partículas salen de su caja, no de la malla exacta (en modelos normales no se nota).

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

En el pico, el pilar tiene unas 800 partículas, unos 220 cubos (Parts, movidos todos juntos con `BulkMoveTo`) y unos 97 emisores. El agujero negro llega a unas 400 partículas y 180 cubos. El aura tiene unas 370 partículas encendidas y un emisor por capa en cada parte (hasta 30 partes). El rayo cósmico se mantiene en unas 370 partículas, con 6 Beams; al barrer el suelo deja hasta unas 10 marcas por segundo (Decals), que se borran solas. La ULTIMATE es mucho más grande: su sección tiene sus números. `OmnivoraVFX.Quality = 0.6` reduce las partículas y la cantidad de cubos, por ejemplo en celulares.

## ULTIMATE: Cataclismo gravitacional

Es una sola secuencia continua de 23 s: 17.6 s de habilidad y 5.4 s de secuelas. Las fases se encadenan sin cortes.

**Todo responde a la misma fuerza.** El polvo, las rocas, las corrientes de energía, la nebulosa, las partículas y las víctimas no son efectos sueltos encimados. Los mueve un único campo gravitacional, que va cambiando con el tiempo:

1. Primero anula la gravedad y levanta el terreno.
2. Después lo hace girar todo alrededor del epicentro, más rápido cuanto más cerca del centro, en un embudo que sube.
3. Luego tira de todo hacia la singularidad.
4. En la detonación lo suelta de golpe.

Por eso todo gira junto, se dobla junto hacia el agujero y desaparece en él.

### Las fases

| Segundo | Fase | Qué pasa |
|---|---|---|
| 0 – 3.6 | **1. Despertar gravitacional** | Una onda sale del epicentro y llega hasta los 500 m. El suelo se agrieta detrás de ella. Las piedras tiemblan, se despegan y flotan, y algunas se arrancan de golpe y salen disparadas hacia arriba. |
| 2.4 – 10.6 | **2. Formación del vórtice** | La materia se organiza en una tormenta colosal con forma de embudo y el ambiente se oscurece. Tiene anillos de polvo y rocas que giran a distinta velocidad, corrientes de energía celestes y púrpura, remolinos secundarios y columnas de energía que suben. Las rocas chocan, se parten y se desintegran. **No es un cilindro sólido**: se ve a través de ella. |
| 6.4 – 12.4 | **3. La singularidad emerge** | Sobre el epicentro nace un punto negro con un destello, para que se note desde el primer instante. Crece con su anillo de luz, su disco de acreción y su halo. El tornado la alimenta: los brazos de la tormenta y los escombros caen hacia ella en espiral. |
| 10.6 – 14.4 | **4. Consumo total** | El vórtice colapsa dentro del agujero. Desde los 10.8 s las víctimas suben en espiral, una tras otra, y quedan atrapadas girando junto a él. El campo queda limpio: vacío y tensión. |
| 14.4 – 16.6 | **5. Masa crítica** | El agujero se contrae y su brillo crece a pulsos cada vez más rápidos, con rayos y distorsión. Termina en un **destello blanco corto** (de 16.45 a 16.95 s) que no tapa la explosión. |
| 16.62 | **6. Detonación cósmica** | Estalla en muchas capas: núcleo, dos cascarones de nebulosa, un anillo, distorsión, rayos, estrellas y un muro de polvo en el suelo. La cámara tiembla fuerte. Las víctimas salen disparadas **hacia abajo**, no hacia los lados. |
| 17.17 | **7. Impacto planetario** | Cada víctima se estrella en su punto, una cada 0.06 s. Cada impacto trae destello, ondas de choque, un cráter con grietas de luz, rocas, una columna y un anillo de polvo, residuos cósmicos y su propio golpe de cámara. |
| 17.6 – 23 | **8. Secuelas cósmicas** | Unos 5 s de polvo que se asienta, piedritas que caen, partículas que flotan y energía que se apaga. Al terminar se borra todo. |

**La cámara no se mueve.** El efecto no cambia de sitio la cámara ni la hace girar: solo le suma una sacudida, cada vez más fuerte según la fase. Hay un golpe fuerte en la detonación y uno por cada impacto, y al terminar la cámara queda exacta donde estaba.

### La escala: 500 m en studs

En Roblox 1 stud = 0.28 m, así que **500 m = 1786 studs**. Ese es el radio por defecto. Si tu juego usa otra escala, cámbialo con la opción `Radius` y todo se escala con él: la altura de la singularidad, el agujero, las rocas, las partículas y las ondas. Por ejemplo, con `Radius = 893` todo queda a la mitad.

La singularidad queda a **760 studs sobre el epicentro** (× `Radius` / 1786). Si tu cámara de combate no alcanza a verla, bájala con `Height`.

### Cómo llamarla

Igual que los demás efectos: el servidor avisa a todos los clientes con el RemoteEvent y cada cliente la reproduce. El daño y el movimiento de las víctimas los decide el servidor (más abajo está cómo).

```lua
-- LocalScript (el mismo que escucha el RemoteEvent de Omnívora)
evento.OnClientEvent:Connect(function(habilidad: string, datos: any)
	if habilidad == "Cataclismo" then
		OmnivoraVFX.GravitationalCataclysm(datos.omnivora, datos.victimas, { Caster = datos.omnivora })
	end
end)
```

```lua
-- Server: cuando Omnívora lanza la ULTIMATE
evento:FireAllClients("Cataclismo", { omnivora = modeloDeOmnivora, victimas = { kaiju1, kaiju2, kaiju3 } })
```

- **`epicentro`**: el centro de la habilidad. Puede ser el modelo de Omnívora (o su `HumanoidRootPart`), una Part, un `Vector3` o un `CFrame`. El módulo busca el suelo debajo.
- **`víctimas`**: los kaijus atrapados, en una lista de Models (o Parts, `Vector3`, `CFrame`). Cada uno sube a la singularidad y se estrella en el punto donde estaba. La lista puede ir vacía.
- **`opciones`** (todas opcionales):

| Opción | Qué hace |
|---|---|
| `Radius` | Radio en studs. Por defecto 1786 (500 m). Todo se escala con él. |
| `Height` | Altura de la singularidad sobre el epicentro. Por defecto 760 × `Radius` / 1786. |
| `Shake` | Intensidad de la sacudida: 1 normal, 2 fuerte, 0 sin sacudida. |
| `MoveVictims` | `true`: el efecto mueve los modelos de las víctimas por su recorrido. Es para pruebas o para modelos que nadie más mueve. En el juego déjalo apagado y muévelas desde el servidor (ver abajo). |
| `ImpactPoints` | `{ Vector3 }`: dónde cae cada víctima, en el mismo orden de la lista. Por defecto cae donde estaba. Si estaba a más de 418 studs del centro (× escala), cae a 418 en la misma dirección, para que la caída siga siendo hacia abajo. |
| `AutoImpacts` | `false`: no dibuja los impactos. Los dibujas tú con `OmnivoraVFX.CataclysmImpact(CFrame.new(punto), escala, sacudida)`. |
| `StartTime` | Empieza en ese segundo, para revisar una fase. El campo se adelanta sin dibujar nada, así que todo aparece donde debe estar. |
| `Flash` | `false`: sin el destello blanco de pantalla. |
| `Caster` | El modelo de Omnívora: se ignora al buscar el suelo. |
| `OnEvent` | `function(nombre, ...)`: avisa de cada momento (ver la tabla de eventos). |

Lo que devuelve:

| | Para qué sirve |
|---|---|
| `ult.Time` | En qué segundo de la secuencia va. |
| `ult.Phase` | El nombre de la fase actual ("Despertar gravitacional", "Formación del vórtice"…). |
| `ult.Active` | `true` mientras dura. |
| `ult.Center` | El epicentro, en el suelo. |
| `ult.Singularity` | Dónde está la singularidad. |
| `ult.SingularityRadius` | El radio del agujero en este momento, en studs. |
| `ult:GetVictimCFrame(víctima, t)` | Dónde está una víctima en el segundo `t` (sin `t`, ahora). |
| `ult:GetImpactPoint(víctima)` | Dónde se estrella esa víctima. |
| `ult:Stop()` | La corta y borra todo. |
| `ult.Holder` | La Part que contiene todo el efecto. |

Eventos de `OnEvent`:

| Evento | Cuándo | Qué trae |
|---|---|---|
| `"Phase"` | Empieza una fase | el nombre y el número (1 – 8) |
| `"VictimLift"` | Una víctima empieza a subir | la víctima y su número |
| `"VictimLaunch"` | Una víctima sale disparada hacia abajo (en la detonación) | la víctima y su número |
| `"Detonation"` | Detona | la posición de la singularidad |
| `"VictimImpact"` | Una víctima se estrella | la víctima, su número y el punto del suelo |
| `"Finished"` | Terminó y se borró todo | — |

Los eventos ocurren en cada cliente. Úsalos para sonidos, la interfaz o tu cámara. El daño va en el servidor, con los tiempos del plan.

`OmnivoraVFX.GravitationalCataclysmTimes` tiene los segundos de cada momento, para coordinar animaciones y sonidos:

| Campo | Segundo | Qué es |
|---|---|---|
| `Vortex` | 2.4 | Empieza a formarse el vórtice. |
| `Singularity` | 6.4 | Nace la singularidad. |
| `Consumption` | 10.6 | Empieza el consumo total. |
| `VictimsLifted` | 10.8 | La primera víctima empieza a subir. Las demás le siguen cada 0.28 s. |
| `VictimsHeld` | 13.6 | Todas las víctimas quedan atrapadas junto al agujero. |
| `CriticalMass` | 14.4 | Empieza la masa crítica. |
| `Flash` | 16.6 | El destello blanco en su punto más fuerte. |
| `Detonation` | 16.62 | Detona y las víctimas salen disparadas hacia abajo. |
| `FirstImpact` | 17.17 | Se estrella la primera víctima. Las demás caen cada 0.06 s. |
| `Aftermath` | 17.6 | Empiezan las secuelas. |
| `End` | 23 | Se borra todo. |

### En el servidor: mover a las víctimas y el daño

El efecto **solo dibuja**: no toca vida, Humanoids ni tu sistema de combate. Para el servidor está `GravitationalCataclysmPlan`, que calcula **exactamente el mismo recorrido** que dibujan los clientes, sin crear nada. No usa números al azar, así que el servidor y los clientes coinciden.

```lua
-- Server: la ULTIMATE en el turno de Omnívora
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OmnivoraVFX = require(ReplicatedStorage.OmnivoraVFX)
local Tm = OmnivoraVFX.GravitationalCataclysmTimes

local function lanzarCataclismo(omnivora: Model, victimas: { Model })
	local plan = OmnivoraVFX.GravitationalCataclysmPlan(omnivora, victimas, { Caster = omnivora })
	evento:FireAllClients("Cataclismo", { omnivora = omnivora, victimas = victimas })

	-- las víctimas siguen el mismo recorrido que dibujan los clientes
	local t0 = os.clock()
	local conexion
	conexion = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		for _, v in victimas do
			local cf = plan:GetVictimCFrame(v, t)
			if cf then
				v:PivotTo(cf)
			end
		end
		if t > Tm.Aftermath then
			conexion:Disconnect()
		end
	end)

	-- el daño, cuando cada una se estrella
	for _, v in victimas do
		local tiempos = plan:GetVictimTimes(v) -- { Lift, Held, Launch, Impact }
		task.delay(tiempos.Impact, function()
			hacerDanio(v, 300) -- tu función y tus valores
		end)
	end
end
```

- **Usa las mismas víctimas y opciones** en el servidor y en los clientes (`Radius`, `Height`, `ImpactPoints`, `Caster`). Llama al plan en el mismo momento en que avisas a los clientes, con las víctimas quietas, como en un combate por turnos.
- Con `MoveVictims` apagado, los efectos de cada víctima (el aura que la rodea al subir, el lazo de energía y la estela de la caída) **siguen a su modelo real**. Así, cuando el servidor las mueve, todo coincide.
- Si tus kaijus no están anclados, ancla su `HumanoidRootPart` mientras dura y suéltalo al final. Si no, la física los tira entre cuadro y cuadro. Si un jugador controla a la víctima, el anclaje también evita que su cliente la mueva.
- Después del impacto, el plan las deja en el cráter, un poco hundidas y torcidas. Cuando tu combate siga, ponlas de pie con tu animación o con `PivotTo`.
- `plan.Center`, `plan.Singularity` y `plan:GetImpactPoint(v)` te sirven para el daño en área o para tu cámara.

### Probarla sin el modelo de Omnívora

`roblox/CataclysmDemo.client.lua` arma una escena de prueba y reproduce la ULTIMATE completa desde una cámara fija:

1. El módulo `OmnivoraVFX` tiene que estar en `ReplicatedStorage`, con los IDs de las texturas pegados.
2. En `StarterPlayer` > `StarterPlayerScripts` crea un **LocalScript**, pega el contenido de `CataclysmDemo.client.lua` y dale **Play**. Mejor en un lugar vacío, como un Baseplate: la habilidad ocupa 500 m a la redonda.
3. En el centro aparece un Omnívora de prueba (una figura azul oscuro de 90 studs) y a su alrededor tres kaijus de prueba (grises, de 60 studs, a unos 275 – 370 studs). A los 2 s la ULTIMATE empieza sola.

| Tecla | Qué hace |
|---|---|
| R | Repetir desde el principio. |
| 1 … 8 | Empezar en una fase: 1 despertar, 2 vórtice, 3 singularidad, 4 consumo, 5 masa crítica, 6 justo antes del destello, 7 el destello y la detonación, 8 impactos y secuelas. |
| V | Cambiar de cámara: dentro del área, lejos (se ve todo el radio de 500 m) o cerca de un impacto. |
| C | Devolver la cámara al jugador. Con otra C vuelve la cámara fija. |
| H | Ocultar o mostrar el panel. |

El panel de abajo a la izquierda muestra la fase, el segundo y dónde fue el último impacto. Así compruebas las transiciones, los escombros, la absorción, la detonación y que cada kaiju caiga en su punto. En la prueba el efecto mueve a los kaijus de prueba (`MoveVictims = true`). Todo es local, solo lo ves tú, y no toca tu sistema de combate.

### Rendimiento de la ULTIMATE

Es la habilidad más pesada, pero está pensada para Roblox:

- **Lo colosal no son partículas.** La tormenta, las corrientes, el agujero y las ondas son Beams y Parts, porque Roblox no dibuja partículas de más de 100 studs.
- **Números en el pico:**
  - unas 5000 partículas, en la detonación;
  - hasta unas 300 Parts (rocas y piezas del agujero), movidas todas juntas con `BulkMoveTo`;
  - unos 275 Beams encendidos;
  - unos 340 emisores encendidos.
- **Las rocas no cargan la física.** Tienen un tope de rocas vivas, sus choques se calculan en el mismo bucle (un solo `Heartbeat`) y no chocan con nada ni detectan toques.
- **Calidad.** `OmnivoraVFX.Quality = 0.6` baja las partículas y las rocas, por ejemplo en celulares.
- **Pantalla.** El destello blanco (un `ScreenGui`) y el oscurecimiento del ambiente (un `ColorCorrectionEffect` en `Lighting`) solo existen en el cliente y se borran al terminar.
- **Distorsión.** La distorsión alrededor del agujero es vidrio (`Glass`), y Roblox solo la dibuja con gráficos altos. `OmnivoraVFX.Lens = false` la quita, igual que en el agujero negro.

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
- **El video de la ULTIMATE** se ve desde las mismas tres cámaras fijas de `CataclysmDemo`: dentro del área, lejos (todo el radio de 500 m) y cerca de un impacto. Al final repite en cámara lenta desde la masa crítica hasta los impactos. Abajo se ve la fase, el segundo y una línea con las 8 fases. La sacudida del video es la misma que el módulo le aplica a la cámara.
- En la ULTIMATE, el ambiente se oscurece durante la tormenta y se aclara en la masa crítica. Eso lo hace un `ColorCorrectionEffect` que el efecto pone en `Lighting` y quita al terminar. Si tu juego ya usa uno, los dos se combinan.
- El agujero de la ULTIMATE es una esfera negra (`Neon` negro), con discos de acreción inclinados y anillos de luz que siempre miran a la cámara. Las corrientes de la tormenta, los brazos de polvo y las ondas son cadenas de Beams que se desvanecen solas cuando pasan muy cerca de la cámara, para no taparte la vista.

## Licencias de las texturas (todas libres para uso comercial)

- **Kenney Particle Pack** (`kk_*`): CC0, de kenney.nl. El crédito es opcional. Ver `textures/KENNEY_LICENSE.txt`.
- **Muestras oficiales de Effekseer** (`fx_*`): CC0. Agradecen el crédito a "Effekseer" y a los autores de las muestras. Ver `textures/EFFEKSEER_SAMPLES_LICENSE_CC0.txt`.
- **`om_*` y `kz_*`**: generadas para este proyecto (los cubitos, las grietas, el cuerpo del pilar, el núcleo del agujero negro, la marca del suelo, las del rayo cósmico (`om_beam_*`) y las del aura, `om_aura_wisp_2x2` y `fx_aura_tongue_2x2`), son tuyas.

## Si quieres cambiar algo

El pilar está en `KaijuZero_VFX/tools/vfx_omnivora.py`: colores, tiempos de la carga y del pilar, cantidad y tamaño de los cubos (`CUBES`), oleadas, luces. El agujero negro está en `KaijuZero_VFX/tools/vfx_blackhole.py`: tiempos de la formación, del avance y de la detonación, tamaño, altura, arco, la lente, las capas del agujero y los cubos (`CUBES_BH`). El rayo cósmico está en `KaijuZero_VFX/tools/vfx_cosmicbeam.py`: arriba los tiempos (`START`, `GROW`, `STOP`, `FADE`), en `BEAMS` el ancho, el color y la velocidad de cada capa del rayo, y al final, en `"beam"`, el largo máximo (`max_len`: 124), cada cuánto deja marcas al barrer (`trail_every`, `trail_move`) y el tiempo mínimo entre impactos (`rehit`). Sus texturas (`om_beam_*`) salen de `KaijuZero_VFX/tools/gen_cosmic_beam_textures.py`. El aura está en `KaijuZero_VFX/tools/vfx_aura.py` (la misma receta que el aura carmesí de Kaiju Zero; `COSMIC` es su paleta y en `aura_cfg` están el delineado, las oleadas y los tiempos) y sus texturas salen de `KaijuZero_VFX/tools/gen_aura_textures.py`.

La ULTIMATE está en `KaijuZero_VFX/tools/vfx_cataclysm.py`. Arriba están:

- los tiempos de cada fase: `T`, `PHASES` y `DET` (la detonación);
- el radio y la altura: `R` y `H`;
- el campo gravitacional, en `FIELD`: cuánto gira, cuánto atrae y la forma del embudo;
- el agujero (`HOLE`), las rocas (`ROCKS`), los anillos de la tormenta (`RINGS`), las corrientes (`CURRENTS`) y las víctimas (`VICTIMS`);
- la detonación (`DETO`), la sacudida (`SHAKE`), el oscurecimiento (`CC`) y el destello (`FLASH_T`).

Más abajo están las capas de partículas (`LAYERS`) y el impacto (`IMPACT`). El simulador que hace sus videos es `vfx_cataclysm_sim.py`.

Después de editar cualquiera de estos archivos, regenera los módulos desde la carpeta `KaijuZero_VFX`:

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

En el aura comprueba que salga de las partes visibles del cuerpo (no de la raíz ni de hitboxes invisibles), que su tamaño siga el alto del modelo, que haya oleadas, que siga al modelo si se mueve y que se limpie al apagarla, al acabar su duración o si el modelo desaparece.

En la ULTIMATE corre la secuencia completa con tres víctimas y comprueba:
- que se levanten las rocas;
- que las víctimas lleguen a la singularidad;
- que haya destello;
- que cada víctima caiga en su punto (donde estaba);
- que los tiempos del plan del servidor cuadren;
- que lleguen todos los eventos y en orden (8 fases, 3 suben, 3 salen disparadas, 3 impactos y `Finished` al final);
- que al terminar se borre todo, también el oscurecimiento y el destello.

También prueba empezar en una fase (`StartTime`) y cortarla antes con `Stop()`. Además comprueba que las sacudidas juntas dejen la cámara exacta en su sitio.
