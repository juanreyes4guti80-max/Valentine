# VFX de fuego y lava de KAIJU ZERO: guía de instalación

## Qué hay aquí

| Carpeta / archivo | Para qué sirve |
|---|---|
| `roblox/KaijuFireVFX.rbxmx` | El ModuleScript listo para insertar en Studio. |
| `roblox/KaijuFireVFX.lua` | El mismo código en texto, si prefieres copiar y pegar. |
| `roblox/texturas_necesarias.txt` | Las 50 imágenes que usa el módulo. |
| `textures/` | Las imágenes que hay que subir a Roblox. |
| `preview/` | Videos simulados de cada efecto. |
| `tools/` | Generadores (texturas, simulador, módulo). No hace falta tocarlos. |

## Efectos incluidos

### Habilidades

| Función | Qué es | Duración |
|---|---|---|
| `GiantExplosion(cf, escala, sacudida)` | **H1**: la explosión gigante **de lava**, una detonación de magma. Hay destello, ola de polvo y un núcleo de magma. El suelo se abre en **grietas de lava** y brota un **charco de lava fundida**. Una **fuente de magma** lanza gotas espesas que se enfrían en el aire (amarillo, naranja, rojo) y llueven dejando **salpicaduras encendidas**. Vuelan **rocas fundidas**: rocas de material CrackedLava, con resplandor, que gotean lava y al caer salpican y quedan ardiendo. Sube **humo volcánico** y la lava **sigue viva en el suelo 5 s**: burbujea, escupe chorritos y suelta brasas. | 5.8 s (las últimas partículas se apagan a los 6.9 s) |
| `GiantExplosionIgnition(cf, escala, sacudida)` | **H1 Ignition**: la misma explosión de lava en **rojo carmesí**, con la misma iluminación que la normal: el centro nace blanco y pasa a rojo encendido. Es **1.5 veces más grande** y **1.5 veces más intensa**: tiene más magma y más rocas fundidas, y la luz y la sacudida son más fuertes. La lava carmesí queda viva en el suelo 5 s. | 5.8 s |
| `H3_Detonation(rocas, escala, sacudida)` | **H3**: las rocas que dejó el rayo **detonan todas a la vez**. Cada una levanta su racimo de pilares de fuego y entre todas forman una pared de llamas. Los pilares brotan de golpe, se sostienen sin rebotar y se hunden. En la roca más lejana sale un **pilar gigante** de remate. | 2.8 s |
| `H3_DetonationIgnition(rocas, escala, sacudida)` | **H3 Ignition**: lo mismo en carmesí, con pilares más altos, y deja una **marca de fuego** en cada roca unos 3 s. | 4.6 s |
| `SlashHit(rival, escala, sacudida, ángulo)` | **Corte** (el golpe que recibe el rival): un **zarpazo de garra**, tres marcas rasgadas como la garra del logo de Monster. Va **en diagonal** y se desgarra sobre el rival en un instante, con chispas que saltan a los lados, un destello y un anillo. | 0.6 s |
| `BurningSlashHit(rival, escala, sacudida, ángulo)` | **Corte quemado**: el mismo zarpazo al rojo vivo. Las tres marcas quedan **encendidas ardiendo** un momento, con llamas, brasas, gotas de lava y humo. | 1 s |
| `BiteHit(rival, escala, sacudida)` | **Mordisco**: dos **mandíbulas de colmillos** aparecen sobre el rival y se cierran de golpe. Al chocar hay un destello corto (alumbra poco), chispas y un anillo. | 0.6 s |
| `UltimateBeam(origen, objetivo, escala, sacudida, ignorar)` | **ULTIMATE**: un **rayo carmesí de 3 s que se puede apuntar** mientras dura. Tiene el núcleo al rojo blanco y lo envuelve energía con **vetas de lava** que corre hacia la punta. La boca junta energía un instante (chispas y aros que se cierran) y dispara. En la boca queda un **estallido de destellos con aros** que se abren, y a lo largo del rayo pasan **aros finos**, brasas, gotas de lava y **humo rojo**. Se corta en la **primera superficie que toca** y, si no toca nada, llega a su **largo máximo de 186 studs** × escala; al moverlo se acorta o se alarga solo. Donde pega revienta un **impacto**: destellos, ondas, chispas, lava, escombros de roca y **rocas fundidas** que salen volando. El suelo debajo se quema y se agrieta en carmesí, y si **barres el suelo** con el rayo deja una estela de quemaduras. Al final el rayo se corta, se adelgaza y se apaga. | 3.6 s (las marcas del suelo se borran unos 4 s después de hechas) |

### Otros efectos

| Función | Qué es | Duración |
|---|---|---|
| `GiantExplosionClassic(cf, escala, sacudida)` | La explosión gigante anterior, de **fuego**: destello, onda de choque, bola de fuego, rocas en llamas, hongo de humo y fuego en el suelo 5 s. Se conserva por si la quieres usar. | 5.8 s |
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

   Usa el ID de la **imagen**, no el de un Decal. Si solo vas a usar la H1 y la H3 (con sus versiones Ignition), basta con estas 25 texturas:

   `fx_burst_a, fx_burst_fan, fx_fire_2x2, fx_glow, fx_line, fx_shock_spiky, fx_star, kk_circle_03, kk_fire_01, kk_fire_02, kk_flare_01, kk_muzzle_01, kk_muzzle_04, kk_muzzle_05, kk_smoke_04, kk_smoke_07, kk_smoke_08, kk_trace_01, kz_debris_2x2, kz_lava_cracks, kz_lava_drop, kz_lava_glob_2x2, kz_lava_pool, kz_lava_splat, kz_scorch`

   La ULTIMATE (el rayo) usa además estas 9:

   `fx_smoke_2x2, fx_spark4, kk_star_06, kk_twirl_01, kz_beam_core, kz_beam_flow, kz_beam_glow, kz_beam_ring, kz_lava_rock_2x2`

   Y los golpes (corte, corte quemado y mordisco) usan además estas 4:

   `kz_claw_4x4, kz_claw, kz_claw_glow, kz_bite_4x4`

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

### H1: tiempos (para coordinarla con la animación y con el daño)

| Momento | Qué pasa |
|---|---|
| 0 s | Impacto: destello, el suelo se agrieta y brota la lava. **Llama la función en este instante.** |
| 0 – 0.3 s | Revienta el núcleo de magma, sube la fuente de lava y salen volando las rocas fundidas. |
| 0.75 – 1.8 s | Llueve el magma y caen las rocas: dejan salpicaduras encendidas alrededor del cráter. Algunas rocas caen bastante lejos. |
| hasta 5.2 s | La lava sigue viva en el suelo y se enfría poco a poco. |

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

### ULTIMATE (el rayo que se apunta)

La función devuelve un **control** con el que mueves el rayo mientras dura. Cada cuadro el módulo lanza un Raycast desde la boca: el rayo **se corta en la primera superficie que toca** (el rival, una pared, el suelo) y, si apunta al aire, llega a su **largo máximo: 186 studs × escala** (1.5 veces más largo que la primera versión, con el mismo grosor). Al apuntarlo a otro lado se acorta o se alarga solo.

- **`origen`**: de dónde sale. Lo mejor es un **`Attachment` en la boca** del modelo: el rayo lo sigue solo si el kaiju se mueve o gira la cabeza. También acepta una Part, un `Vector3` o un `CFrame`.
- **`objetivo`**: hacia dónde apunta al salir. Un **Model** o una **Part** (si se mueve, el rayo lo sigue) o un punto (`Vector3` o `CFrame`). Si pasas `nil` y el origen es un `CFrame`, sale hacia donde mira ese CFrame.
- **`ignorar`** (opcional): lo que el rayo atraviesa. Pasa siempre `{ modeloDeKaijuZero }`, así no choca con su propia cabeza.

Lo que devuelve:

| | Para qué sirve |
|---|---|
| `rayo:AimAt(objetivo)` | Apunta a otro lado: un Model, una Part, un `Vector3` o un `CFrame`. Si es un Model o una Part, lo sigue. |
| `rayo:SetDirection(dir)` | Apunta en una dirección (`Vector3`), por ejemplo la de la cámara. |
| `rayo:SetOrigin(origen)` | Cambia de dónde sale (Attachment, Part, `Vector3` o `CFrame`). |
| `rayo:Stop()` | Lo corta antes de tiempo: se adelgaza y se apaga igual que al final. |
| `rayo.MaxLength` | El largo máximo (186 × escala). Lo puedes cambiar mientras dura. |
| `rayo.Length` | Cuánto mide en este momento. |
| `rayo.HitPosition`, `rayo.HitInstance` | Dónde pega y qué toca (`nil` si apunta al aire). |
| `rayo.Active` | `true` mientras el rayo se ve. |
| `rayo.Holder` | La Part que contiene todo el efecto. |

El impacto sigue a la punta. Cada vez que el rayo **empieza a pegar en algo** después de pasar por el aire, revientan otra vez el destello, la onda, la lava y las marcas grandes del suelo (como mucho una vez cada 0.3 s). Si **barre el suelo**, va dejando una **estela de quemaduras y grietas de lava** que se borra en unos 2 s.

**En el combate por turnos** (apunta al rival y lo sigue):

```lua
-- Server: evento:FireAllClients("ULT", { kaiju = modeloDeKaijuZero, rival = modeloDelRival })

-- LocalScript (el mismo evento de arriba)
evento.OnClientEvent:Connect(function(habilidad: string, datos: any)
	if habilidad == "ULT" then
		local boca = datos.kaiju.Head.Boca -- un Attachment en la boca del modelo
		KaijuFireVFX.UltimateBeam(boca, datos.rival, 1, 1, { datos.kaiju })
	end
end)
```

**Apuntado con el mouse** por el jugador que lo lanza:

```lua
-- LocalScript del jugador que lanza la ULTIMATE
local RunService = game:GetService("RunService")
local mouse = game:GetService("Players").LocalPlayer:GetMouse()
-- boca = el Attachment de la boca; kaiju = el modelo de Kaiju Zero

local rayo = KaijuFireVFX.UltimateBeam(boca, mouse.Hit.Position, 1, 1, { kaiju })
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
local LARGO = 186 -- × la escala que uses en UltimateBeam
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { modeloDeKaijuZero }
local fin = os.clock() + KaijuFireVFX.UltimateBeamStop
task.delay(KaijuFireVFX.UltimateBeamStart, function()
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

**Tiempos** (desde la llamada), para coordinarla con la animación y con el daño:

| Momento | Qué pasa |
|---|---|
| 0 – 0.3 s | La boca junta energía: chispas y aros que se cierran sobre ella. **Llama la función cuando la animación abre la boca.** |
| 0.3 s | Dispara: destello en la boca y la punta sale disparada. |
| 0.4 s | La punta llega a donde pega (o a su largo máximo): destello, onda y el impacto queda activo. Es `KaijuFireVFX.UltimateBeamStart`. |
| 0.4 – 3.3 s | El rayo se sostiene y lo puedes mover: aros, brasas, humo rojo, chispas, lava y rocas fundidas donde pega. |
| 3.3 s | Se **corta** solo (o antes, si llamas `rayo:Stop()`): se adelgaza y se apaga en 0.3 s. Es `KaijuFireVFX.UltimateBeamStop`. |
| después | Se disipan el humo y las brasas. Las marcas del suelo se borran solas unos 4 s después de hechas. |

- **Escala**: con `1`, el rayo mide unos 22 studs de ancho (el núcleo blanco unos 6.5), el resplandor llega a unos 42 y el largo máximo es de 186 studs. Para un kaiju más grande prueba de `1.5` a `2` (el largo máximo crece igual; si lo quieres fijo, cambia `rayo.MaxLength`).
- **Sacudida**: tiembla sin parar mientras dura el rayo, da un golpe cuando llega (0.4 s) y otro suave al cortarse (también si lo cortas antes). `0` o `nil` la desactiva.

### Golpes en el rival (corte y mordisco)

En el combate por turnos, Kaiju Zero hace su animación de ataque desde su lado (por ejemplo *Vertical Slash* con la mano) y **en el rival aparece el golpe**. Llama la función en el cuadro de la animación en que el golpe conecta, en todos los clientes:

```lua
-- Server, cuando el ataque conecta: evento:FireAllClients("GOLPE", { tipo = "corte", rival = modeloDelRival })

-- LocalScript (el mismo evento de arriba)
evento.OnClientEvent:Connect(function(habilidad: string, datos: any)
	if habilidad == "GOLPE" then
		if datos.tipo == "corte" then
			KaijuFireVFX.SlashHit(datos.rival, 1, 1)
		elseif datos.tipo == "corte quemado" then
			KaijuFireVFX.BurningSlashHit(datos.rival, 1, 1)
		elseif datos.tipo == "mordisco" then
			KaijuFireVFX.BiteHit(datos.rival, 1, 1)
		end
	end
end)
```

- **`rival`**: su **Model** (lo normal), una Part, o un `Vector3`/`CFrame` si quieres un punto exacto (por ejemplo `rival.Head.Position`).
- **Siempre se ve de frente**: el golpe mira a la cámara de cada jugador y sale delante de la parte del rival que se ve, así no queda escondido dentro del cuerpo.
- **Se adapta al tamaño del rival**: con un Model o una Part, el golpe crece con su alto (22 studs = tamaño 1; uno de 44 studs lo recibe el doble de grande). `escala` lo multiplica. Si prefieres controlarlo tú, pon `KaijuFireVFX.HitAutoSize = false`.
- **Ángulo del corte**: por defecto va **en diagonal**, de arriba a la izquierda a abajo a la derecha (35°). Puedes pasar otro: `0` = vertical, `-35` = la otra diagonal, `90` = horizontal. Por ejemplo `KaijuFireVFX.SlashHit(rival, 1, 1, -35)`.
- **Tiempos**: el corte conecta a los `KaijuFireVFX.SlashHitImpact` s (0.05) y el mordisco cierra la boca a los `KaijuFireVFX.BiteHitImpact` s (0.14). Úsalos para sincronizar el número de daño o el sonido.

### Otros efectos

- En `Explosion` y `ExplosionAnime`, pon `cf` unos `2.5 × escala` studs por encima del suelo. En `FireLine`, `cf` es el inicio de la línea en el suelo.

### Rendimiento

En el pico, la H1 llega a unas 1250 partículas y 16 rocas, y la H1 Ignition a unas 1900 partículas y 24 rocas. La H3 y la H3 Ignition llegan a unas 1600 partículas (con 7 rocas). La ULTIMATE se mantiene en unas 400 partículas, con 5 Beams y 8 rocas fundidas en total; al barrer el suelo deja hasta unas 10 marcas por segundo (Decals), que se borran solas. Los golpes son livianos: unas 80 partículas el corte y el mordisco, y unas 110 el corte quemado. `KaijuFireVFX.Quality = 0.6` reduce las partículas, por ejemplo en celulares.

## Para que se vea como en el video

- La vista previa usa **Bloom**. En `Lighting` agrega un `BloomEffect` con *Intensity* 0.6–1, *Size* 24 y *Threshold* 1.5–2. Si se ve demasiado blanco, sube el *Threshold*.
- Los anillos de choque, la quemadura, el brillo del suelo y, en la H1, el charco, las grietas y las salpicaduras de lava son **Decals**, para que no les afecte ningún límite de tamaño de partícula. Para que brillen se les pone un Color3 mayor que 1 (sin brillo extra si Roblox lo limitara). Están pensados para suelo plano.
- Los pilares de fuego usan la orientación `FacingCameraWorldUp`: siempre quedan verticales aunque la cámara se incline.
- Las **rocas fundidas** de la H1 son Parts reales con el material **CrackedLava** de Roblox (roca oscura con grietas de lava). Cada una lleva pegado un resplandor naranja (un ParticleEmitter con `LockedToPart`) y una estela de gotas de lava, brasas y humo. Al caer dejan una salpicadura encendida y arden unos segundos.
- Las rocas en llamas de la H1 clásica y de la H3 son Parts de Slate oscuro que dejan estela. Al caer levantan polvo y dejan fuego unos segundos.
- Todas las rocas se mueven por código: no chocan con nada, no empujan a los jugadores y no detectan toques.
- El cuerpo del **rayo** de la ULTIMATE son 5 **Beams** de Roblox entre la boca y la punta: resplandor, lenguas de energía, la envoltura con vetas de lava, el interior y el núcleo blanco. Usan `FaceCamera`, así que siempre se ven de frente, y su textura corre hacia la punta (`TextureSpeed`). El ancho late un poco mientras dura. Cada cuadro, un Raycast desde la boca decide hasta dónde llega la punta; las piezas del efecto tienen `CanQuery` apagado, así que ni ese Raycast ni el mouse las tocan.
- En el video, el rayo sigue un recorrido de prueba: pega en el rival, baja y barre el suelo (se acorta), sube al cielo (llega a su máximo) y vuelve al rival. Abajo a la izquierda se ve cuánto mide en cada momento.
- El zarpazo y el mordisco son **flipbooks** de 16 cuadros (`Grid4x4`, modo `OneShot`): la animación de la garra que se desgarra y de las mandíbulas que se cierran va dentro de la textura, así se ve igual en cualquier equipo. La garra usa la orientación `VelocityParallel`, así sigue el ángulo del corte.
- El carmesí se lee mejor con cielos no muy claros. Sobre un cielo azul muy brillante el resplandor tira un poco a rosa; en el video está la versión de día y la de noche para comparar.

## Licencias de las texturas (todas libres para uso comercial)

- **Kenney Particle Pack** (`kk_*`): CC0, de kenney.nl. El crédito es opcional. Ver `textures/KENNEY_LICENSE.txt`.
- **Muestras oficiales de Effekseer** (`fx_*`): CC0. Agradecen el crédito a "Effekseer" y a los autores de las muestras. Ver `textures/EFFEKSEER_SAMPLES_LICENSE_CC0.txt`.
- **`kz_*`**: generadas aquí, son tuyas. Las de lava (`kz_lava_*`) se hicieron en parte a partir de las muestras CC0 de Effekseer. Las del rayo (`kz_beam_*`), las rocas de lava (`kz_lava_rock_2x2`), la garra (`kz_claw_*`) y el mordisco (`kz_bite_4x4`) se generan desde cero.

## Si quieres cambiar algo

- **H3** (pilares, tiempos, colores, separación de rocas): `tools/vfx_pillars.py`.
- **H1** (explosión de lava): `tools/vfx_lava.py`. Sus texturas propias (`kz_lava_*`) salen de `tools/gen_lava_textures.py`. La Ignition se genera desde ella con `ignitionize`, en `tools/vfx_specs.py`. Ahí puedes cambiar el tamaño, la intensidad y el brillo del carmesí: `bright_k` sube el brillo y `_G_MAP_HOT` decide cuánto se blanquean los tonos más calientes. El núcleo de magma que nace blanco está en `IGNITION_CORE`, en `tools/vfx_lava.py`.
- **H1 clásica** (la de fuego): `GIANT` en `tools/vfx_specs.py`.
- **Golpes** (corte en garra, corte quemado y mordisco): `tools/vfx_hits.py`. Ahí están el ángulo por defecto del corte (`"angle"`), los colores y el brillo de cada golpe. Sus texturas (`kz_claw_*` y `kz_bite_4x4`) salen de `tools/gen_hit_textures.py`.
- **ULTIMATE** (el rayo): `tools/vfx_beam.py`. Arriba están los tiempos (`START`, `GROW`, `STOP`, `FADE`) y los colores, y en `BEAMS` el ancho, el color y la velocidad de cada capa del rayo. Al final, en `"beam"`, están el largo máximo (`max_len`: 186), cada cuánto deja marcas al barrer el suelo (`trail_every`, `trail_move`) y el tiempo mínimo entre impactos (`rehit`). Sus texturas (`kz_beam_*` y `kz_lava_rock_2x2`) salen de `tools/gen_beam_textures.py`.

Después de editarlos se regenera el módulo con:

```
python tools/gen_luau.py roblox
```

El mismo comando regenera también los módulos de Astral Colossus (`AstralColossus_VFX/roblox`) y Omnívora (`Omnivora_VFX/roblox`), que usan el mismo motor.

Las pruebas que validan el módulo son estas:
- `tools/test_luau/run_runtime.py`: ejecuta cada efecto contra un Roblox simulado. Comprueba que se limpie todo y, en la H3, que cada roca reciba su explosión y que el remate quede en la última. En la ULTIMATE comprueba que sin nada delante llegue a su largo máximo, que se corte en el suelo, que se acorte y deje marcas al barrer el suelo, que vuelva a su máximo al apuntar al cielo, que siga a un objetivo que se mueve y a un origen nuevo, y que `Stop()` lo apague y se limpie todo. En los golpes comprueba que salgan delante del rival y que su tamaño siga el alto del rival.
- `luau-lsp analyze` con las definiciones de Roblox: verifica que todas las propiedades y métodos existan en la API.
