# VFX de PEBLEDON (kaiju de piedra con venas turquesa): guía

El kit se está haciendo por partes:

- **Skill 1: Rugido sísmico.** Lista.
- **Skill 2:** el aliento azul delgado. Viene después.
- **Skill 3:** el cristal gigante. Viene después.
- **ULTIMATE:** está por elegirse.

Todo vive en un solo módulo, `PebledonVFX`. Por ahora usa **16 texturas**.

## Qué trae la carpeta

| Archivo | Qué es |
|---|---|
| `roblox/PebledonVFX.rbxmx` | El módulo. Lo insertas en Studio. |
| `roblox/PebledonVFX.lua` | El mismo módulo en texto, por si lo quieres pegar a mano. |
| `roblox/texturas_necesarias.txt` | La lista de las texturas que usa. |
| `textures/` | Las texturas en PNG y sus licencias. |
| `preview/` | Los videos de cada skill. |

El plugin que sube las texturas está en la carpeta `Plugin_Studio` del repositorio (`SubirTexturasVFX.rbxmx`). Ya conoce las texturas de Pebledon.

## Instalación (con el plugin)

1. **Instala el plugin (una sola vez).** En Studio, pestaña *Plugins* > *Plugins Folder*. Copia ahí `SubirTexturasVFX.rbxmx` y reinicia Studio. Si ya lo tenías por Moonfang, reemplázalo por el nuevo.
2. **Inserta el módulo.** Clic derecho sobre `ReplicatedStorage` > *Insert from File…* > `roblox/PebledonVFX.rbxmx`.
3. **Sube las texturas.** Pestaña *Plugins*, barra **VFX Kaiju** > **Subir texturas**. El plugin las sube y pega sus IDs en el módulo.

**Si el plugin falla**, súbelas a mano:

1. En el Asset Manager, usa *Bulk Import* con las imágenes de `textures/` que aparecen en `texturas_necesarias.txt`.
2. Pega el ID de cada **imagen** (no el de un Decal) en la tabla `TEXTURES` del módulo, al principio del archivo.

## El kit

**Identidad:** roca viva y energía turquesa que se escapa por las grietas como fuego frío. Formas pesadas y sísmicas: el suelo se parte, las rocas vuelan y por las grietas brota fuego cian.

**Paleta** (sacada de su imagen): cristal claro `94, 229, 224`, medio `52, 147, 152` y oscuro `39, 121, 127`; roca `93, 85, 76`; panza `164, 148, 133`.

| Skill | Función | Qué se ve | Momentos clave |
|---|---|---|---|
| **Skill 1: Rugido sísmico** | `SeismicRoar(boca, largo, apertura, escala, sacudida)` | **Carga:** la energía turquesa se junta en la boca, le salen llamitas cian y el suelo tiembla bajo él (saltan piedritas). **Rugido:** destello en la boca, **ondas de sonido turquesa** que avanzan y se abren, líneas de grito y un chorro de aire cargado con **fuego cian** y brasas. Bajo él se abre un anillo con grietas que brillan y llamas alrededor de sus pies. **La onda del suelo** avanza en triángulo hacia adelante y se va frenando. A su paso parte el suelo y levanta losas. **Arrastra rocas**: saltan delante del frente, dan vueltas y caen más allá, levantando polvo. Algunas piedras flotan un momento por la vibración. Deja **grietas con venas turquesa** de las que **brota fuego cian** un rato. Al final, lo que arrastraba se amontona y revienta en polvo, rocas y llamas. | ruge a los **0.36 s**; la onda sale a los **0.39 s** y llega al final a los **1.24 s** (`SeismicRoarTimes`) |

`PebledonVFX.SeismicRoarTimes` tiene tres momentos:

- `Roar`: ruge;
- `WaveStart`: la onda del suelo sale;
- `WaveEnd`: la onda llega al final del triángulo.

Además:

- `PebledonVFX.SeismicRoarLength` (100) y `PebledonVFX.SeismicRoarAngle` (42°) son el largo y la apertura por defecto del triángulo, a escala 1.
- `PebledonVFX.SeismicRoarFrontTime(distancia, largo)` te dice en qué segundo la onda pasa por cada punto. Así el daño le llega a cada rival justo cuando la onda lo toca.

El daño, la lentitud, la exposición y el empujón los pones tú en tu sistema de combate (ver abajo).

## Cómo llamarlo

El servidor avisa a todos los clientes con un RemoteEvent y **cada cliente** llama al módulo. Así no se carga el servidor y la sacudida de cámara funciona.

```lua
-- LocalScript (por ejemplo en StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PebledonVFX = require(ReplicatedStorage.PebledonVFX)
local evento = ReplicatedStorage:WaitForChild("PebledonVFX") -- RemoteEvent

evento.OnClientEvent:Connect(function(que: string, d: any)
	if que == "Rugido" then
		-- la boca (un Attachment en la boca) o la cabeza, mirando hacia adelante.
		-- El triángulo va por el suelo debajo: 100 studs de largo y 42° de apertura (a escala 1)
		PebledonVFX.SeismicRoar(d.boca.WorldCFrame, nil, nil, d.escala, 1)
	end
end)
```

- Si no tienes un Attachment en la boca, pasa `d.cabeza.CFrame`.
- El rugido siempre sale **en horizontal**, hacia donde mira la cabeza, aunque la cabeza mire un poco hacia abajo.
- El módulo busca el suelo debajo con un Raycast. Ignora los modelos que tienen Humanoid, como el propio Pebledon.

### El daño sincronizado con la onda (servidor)

```lua
local Debris = game:GetService("Debris")
local PebledonVFX = require(ReplicatedStorage.PebledonVFX)

local function empujar(raiz: BasePart, dir: Vector3, fuerza: number)
	local att = raiz:FindFirstChild("RootAttachment") :: Attachment?
	if not att then
		att = Instance.new("Attachment")
		att.Parent = raiz
	end
	local empujon = Instance.new("LinearVelocity")
	empujon.Attachment0 = att
	empujon.MaxForce = math.huge
	empujon.VectorVelocity = dir * fuerza + Vector3.new(0, 10, 0)
	empujon.Parent = raiz
	Debris:AddItem(empujon, 0.2)
end

local function rugido(pebledon: Model, escala: number, rivales: { Model })
	local boca = pebledon.Head.Boca :: Attachment            -- o la cabeza
	evento:FireAllClients("Rugido", { boca = boca, escala = escala })
	local largo = PebledonVFX.SeismicRoarLength * escala
	local medio = math.rad(PebledonVFX.SeismicRoarAngle / 2)
	local origen = boca.WorldPosition * Vector3.new(1, 0, 1)
	local adelante = (boca.WorldCFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	for _, rival in rivales do
		local raiz = rival:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not raiz then
			continue
		end
		local v = raiz.Position * Vector3.new(1, 0, 1) - origen
		local d = v:Dot(adelante)
		-- dentro del triángulo: delante, no más lejos que el largo y dentro de la apertura
		if d <= 0 or d > largo or math.acos(math.clamp(v.Unit:Dot(adelante), -1, 1)) > medio then
			continue
		end
		task.delay(PebledonVFX.SeismicRoarFrontTime(d, largo), function()
			hacerDanio(rival, 20)           -- daño moderado (tu función y tus valores)
			ralentizar(rival, 0.6, 3)       -- tu sistema: 60 % de su velocidad por 3 s
			exponer(rival, 4)               -- tu sistema: expuesto por 4 s
			empujar(raiz, adelante, 45)     -- lo empuja un poco hacia atrás
		end)
	end
end
```

**Escala.** Tamaño 1 está pensado para un Pebledon de unos **25 studs de alto**, con la boca a unos 21 studs del suelo. Si el tuyo mide 75 studs, usa escala 3. El largo del triángulo también se escala solo; si le pasas otro largo, usa el mismo en `SeismicRoarFrontTime`.

## Para que se vea como en el video

- El video es de mi simulador, con Bloom. Pebledon es una figura de cajas de prueba.
- Las losas y las rocas que arrastra la onda miran con un Raycast **el color y el material del suelo** donde salen. En el video son grises porque el suelo de prueba es oscuro.
- Las grietas, los anillos y las marcas del suelo son Decals pensados para suelo plano.
- Para que el fuego cian brille como en el video, pon un `BloomEffect` en `Lighting`: *Intensity* 0.6–1, *Size* 24, *Threshold* 1.5–2.

## Rendimiento

En el pico del Rugido sísmico salen unas **1200 partículas**, unas **58 losas** y unas **68 rocas** (Parts ancladas, sin colisión) y **70 Decals** de grietas. Todo se limpia solo a los 5.5 s.

`PebledonVFX.Quality = 0.6` baja las partículas, las losas y las rocas (por ejemplo, en celulares).

## Modelos de Blender (opcional)

Las piezas sólidas se pueden cambiar por modelos hechos en Blender (una **MeshPart** cada una). Ponlos en `PebledonVFX.Meshes` con el nombre de la pieza y el módulo los usa en vez de los bloques:

```lua
local PebledonVFX = require(ReplicatedStorage.PebledonVFX)
local modelos = ReplicatedStorage.PebledonMeshes        -- una carpeta con tus MeshParts
PebledonVFX.Meshes.RoarSlab = modelos.Slab              -- las losas que levanta el rugido
PebledonVFX.Meshes.PlowRocks = modelos.Rock             -- las rocas que arrastra la onda
PebledonVFX.Meshes.PlowBoulders = modelos.Boulder       -- las rocas grandes
```

- El modelo se clona y se escala al tamaño de cada pieza, y conserva su material, su color y su textura.
- Con un modelo, la pieza ya no toma el color del suelo.

## Las texturas

Están en `textures/`. El plugin las sube todas.

**Propias de Pebledon (`pb_`):**

| Textura | Qué es | Dónde se usa |
|---|---|---|
| `pb_rock_2x2` | cuatro rocas facetadas con venas turquesa que brillan (ya coloreada) | Rugido |
| `pb_sonic_ring` | onda de sonido: un anillo nítido con ondas detrás | Rugido |
| `pb_vein_cracks` | grietas que salen del centro y se ramifican | Rugido |

**Del proyecto (de los otros kits):** `kz_beam_ring` (anillo nítido) y `om_cubes_2x2` (pedazos de tierra).

**Kenney (CC0):** `kk_circle_02` (anillo del suelo), `kk_smoke_04` (polvo), `kk_star_09` (destello) y `kk_trace_01` (líneas de grito).

**Effekseer (CC0):** `fx_fire_2x2` (fuego), `fx_aura_tongue_2x2` (lenguas de fuego), `fx_glow` (resplandor), `fx_smoke_2x2` (humo), `fx_fog2001` (polvo bajo), `fx_spark002` (brasas) y `fx_particle02` (partículas de luz).

### Licencias

- `kk_*` son de Kenney (CC0) y `fx_*` son de las muestras de Effekseer (CC0). Ver los archivos de licencia en `textures/`.
- `pb_*`, `kz_*` y `om_*` se generaron para este proyecto: son tuyas.

## Los videos

En `preview/`:

1. `1_Skill1_RugidoSismico`

## Si quieres cambiar algo

Todo el kit está en `KaijuZero_VFX/tools/vfx_pebledon.py`:

- arriba están los colores;
- después cada skill, con sus tiempos y sus capas. Del rugido: `RL` y `RA` (largo y apertura), `T_ROAR`, `T0R`, `TWR` y `EASE_R` (cuándo ruge, cuándo sale la onda, cuánto tarda y cuánto se frena), `ROAR_FRONT` (lo que viaja con el frente) y `ROAR_FIELD` (las losas).

Sus texturas propias salen de `KaijuZero_VFX/tools/gen_pebledon_textures.py`.

Para regenerar, desde `KaijuZero_VFX/tools`:

1. `python gen_luau.py ../roblox` escribe los módulos de todos los kaijus.
2. Si cambiaste texturas, `python gen_plugin.py` actualiza el plugin.

La prueba `KaijuZero_VFX/tools/test_luau/run_runtime.py` ejecuta el kit contra un Roblox simulado. Comprueba:

- que el rugido salga de la boca;
- que el polvo, las grietas y el fuego vayan al suelo y cubran todo el triángulo;
- que salten las losas y las rocas;
- que exporte los tiempos, el largo y la apertura;
- que no quede nada vivo al terminar.
