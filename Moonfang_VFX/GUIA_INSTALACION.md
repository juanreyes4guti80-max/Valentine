# VFX de MOONFANG (lobo kaiju lunar de cristal): guía final

El kit está completo:

- **M1:** tres mordiscos y el remate.
- **Pesado** y el **golpe bloqueado**.
- **Skill 1:** Medialuna.
- **Skill 2:** Ola de hielo.
- **Skill 3:** Rugido helado.
- **Skill 4 (ULTIMATE):** Eclipse.

Todo vive en un solo módulo, `MoonfangVFX`, con **31 texturas**.

## Qué trae la carpeta

| Archivo | Qué es |
|---|---|
| `roblox/MoonfangVFX.rbxmx` | El módulo. Lo insertas en Studio. |
| `roblox/MoonfangVFX.lua` | El mismo módulo en texto, por si lo quieres pegar a mano. |
| `roblox/texturas_necesarias.txt` | La lista de las 31 texturas que usa. |
| `textures/` | Las 31 texturas en PNG y sus licencias. |
| `SubirTexturasVFX.rbxmx` | El plugin que sube las texturas por ti (en GitHub está en la carpeta `Plugin_Studio`). |
| `preview/` (en GitHub y en el chat) | Los videos de cada ataque. |

## Cómo descargarlo

Hay dos caminos y los dos te dan la misma carpeta `Moonfang_VFX`.

**A. El ZIP del chat (lo más fácil).** Descarga `Moonfang_VFX.zip` y descomprímelo:

- en Windows: clic derecho > *Extraer todo…*;
- en Mac: doble clic.

**B. Desde GitHub.**

1. Abre el repositorio `juanreyes4guti80-max/Valentine`.
2. Elige la rama **`claude/inspiring-fermi-z0y6if`** con el botón de la rama (arriba a la izquierda, dice `main`).
3. Toca el botón verde **Code** > **Download ZIP**.
4. Descomprímelo. Lo de Moonfang está en `Moonfang_VFX` y el plugin en `Plugin_Studio`.

## Instalación (unos 2 minutos, con el plugin)

1. **Instala el plugin (una sola vez).** En Studio, pestaña *Plugins* > *Plugins Folder*. Copia ahí `SubirTexturasVFX.rbxmx` y reinicia Studio.
2. **Inserta el módulo.** Clic derecho sobre `ReplicatedStorage` > *Insert from File…* > `roblox/MoonfangVFX.rbxmx`.
3. **Sube las texturas.** Pestaña *Plugins*, barra **VFX Kaiju** > **Subir texturas**. El plugin sube las 31 y pega sus IDs en el módulo.

**Si el plugin falla**, súbelas a mano:

1. En el Asset Manager, usa *Bulk Import* con las imágenes de `textures/` (solo las de `texturas_necesarias.txt`; el ZIP ya trae solo esas).
2. Pega el ID de cada **imagen** (no el de un Decal) en la tabla `TEXTURES` del módulo, al principio del archivo.
3. Sube `mf_moon_eclipse_4x4` tal cual, de 1024 × 1024: son los 16 cuadros del eclipse y el módulo los recorta por píxeles.

**Si en Studio se ve peor que en el video:**

1. Toca **Revisar texturas** en el plugin.
2. Sube la calidad gráfica al máximo.
3. Prueba con la luz por defecto y un `BloomEffect` en `Lighting`: *Intensity* 0.6–1, *Size* 24, *Threshold* 1.5–2.

## El kit

**Identidad:** luz de luna fría (plata y blanco), hielo y azul cristal, esquirlas afiladas, medias lunas y destellos de estrella. Formas cortantes y brillantes.

| Ataque | Función | Qué se ve | Momento clave |
|---|---|---|---|
| **M1** mordiscos 1-3 | `MoonBite(rival, escala, sacudida)` | **Solo los colmillos**, sin encía: dos filas de colmillos de cristal se cierran de golpe sobre el rival y quedan trabadas. Salen chispas de hielo hacia los lados y vaho helado. Los colmillos se rompen en esquirlas y queda una herida de escarcha que gotea cristalitos un segundo. | se traban a los **0.1 s** (`MoonBiteImpact`) |
| **M1** mordisco 4 | `MoonBiteFinisher(rival, escala, sacudida)` | El remate es una **embestida**. Unas líneas de velocidad se cierran sobre el rival y dos filas de colmillos más grandes, con su eco, se traban, se rompen y revientan en una flor de púas de hielo. | se traban a los **0.14 s** (`MoonBiteFinisherImpact`) |
| **Pesado** | `MoonFang(rival, escala, sacudida)` | Dos filas de **colmillos de cristal grandes**, con su eco, se traban de golpe sobre el rival (solo los dientes, como el M1). De la mordida brotan agujas de cristal que crecen y estallan, con dos ondas de media luna. | se traban a los **0.14 s** (`MoonFangImpact`) |
| **Bloqueo** (cada golpe bloqueado) | `MoonGuardHit(moonfang, escala, sacudida)` | Una media luna de luz aparece como escudo delante de él, con esquirlas que rebotan a los lados. | **0.02 s** (`MoonGuardHitImpact`) |
| **Skill 1: Medialuna** | `CrescentWave(cf, largo, escala, sacudida)` | Lanza una **media luna de energía** que vuela vertical y **de canto**: de lado se ve la media luna; desde atrás, una hoja fina que apunta hacia donde va. Tiene el filo blanco y duro y el cuerpo celeste y azul. Deja una estela de humo frío, brillos y esquirlas. Su cuerno de abajo **corta el suelo**: se abre una grieta con escarcha, saltan losas a los dos lados y caen **rocas cúbicas** que se quedan un rato en el camino. Al final **detona en hielo**, con lanzas de hielo, una nube helada, una corona de púas y un cráter de losas. | detona a los **0.76 s** (`CrescentWaveImpact`) |
| **Skill 2: Ola de hielo** | `IceWave(cf, largo, apertura, escala, sacudida)` | Golpea el suelo y una **ola densa de humo helado** sale hacia adelante abriéndose en triángulo. Sale con fuerza y se va frenando. Deja una estela espesa que cubre el triángulo. A su paso el suelo se rompe y se escarcha, brotan **bloques de hielo**, saltan losas y salen rocas volando. Los bloques revientan en esquirlas a los dos segundos. | llega al fondo a los **1.12 s** |
| **Skill 3: Rugido helado** | `FrostRoar(cabeza, escala, sacudida)` | El frío se junta en el hocico y **ruge**: ondas de sonido heladas que avanzan y se abren, líneas de grito, un chorro de vaho helado con esquirlas y un destello en la boca. En el suelo, bajo él, se abre una **onda de escarcha** con grietas, niebla que sale hacia afuera y un anillo de **púas de hielo**. En el juego es un **escape de combos que empuja** (ver abajo). | ruge a los **0.28 s** (`FrostRoarImpact`); la onda llega a **30 studs × escala** (`FrostRoarRadius`) |
| **Skill 4: Eclipse** (ULTIMATE) | `Eclipse(cf, radio, altura, escala, sacudida)` | La zona mide **120 studs de radio**. Una **luna gigante** aparece sobre ella y se va eclipsando mientras el mundo se oscurece. En el suelo se dibuja un **círculo lunar** con las 8 fases de la luna. El hielo y la tierra flotan hacia la luna. Al quedar tapada, con su corona y el destello del anillo de diamante, cae de golpe una **columna de luz de luna** del ancho de toda la zona, con un contorno nítido. El suelo se congela: brota una **corona de picos de hielo** en el borde, un campo de cristales y vuelan cientos de pedazos. Al final la columna **colapsa** y todo el hielo **revienta en una detonación**, y vuelve la luna llena. | la columna pega a los **1.42 s** y la detonación es a los **3.55 s** (`EclipseTimes`) |

Todos los momentos están en el módulo con el nombre de la tabla, por ejemplo `MoonfangVFX.MoonFangImpact`.

`MoonfangVFX.EclipseTimes` tiene cuatro momentos:

- `Eclipse`: la luna queda tapada;
- `Impact`: pega la columna;
- `Collapse`: la columna colapsa;
- `Detonation`: la detonación.

El daño, el knockback y la mejora del rugido los pones tú en tu sistema de combate.

## Cómo llamarlo

El servidor avisa a todos los clientes con un RemoteEvent y **cada cliente** llama al módulo. Así no se carga el servidor y la sacudida de cámara funciona.

```lua
-- LocalScript (por ejemplo en StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MoonfangVFX = require(ReplicatedStorage.MoonfangVFX)
local evento = ReplicatedStorage:WaitForChild("MoonfangVFX") -- RemoteEvent

evento.OnClientEvent:Connect(function(que: string, d: any)
	if que == "M1" then
		if d.golpe < 4 then
			MoonfangVFX.MoonBite(d.rival, d.escala, 1)
		else
			MoonfangVFX.MoonBiteFinisher(d.rival, d.escala, 1) -- el 4.º es el remate
		end
	elseif que == "Pesado" then
		MoonfangVFX.MoonFang(d.rival, d.escala, 1)
	elseif que == "Bloqueado" then
		MoonfangVFX.MoonGuardHit(d.moonfang, d.escala, 1)
	elseif que == "Medialuna" then
		-- cf en el suelo, mirando hacia donde sale la media luna; 130 studs de largo (a escala 1)
		MoonfangVFX.CrescentWave(CFrame.lookAt(d.origen, d.origen + d.direccion), 130 * d.escala, d.escala, 1)
	elseif que == "Ola" then
		-- cf en el suelo, mirando hacia donde sale la ola; 110 studs de largo y 50° de apertura (a escala 1)
		MoonfangVFX.IceWave(CFrame.lookAt(d.origen, d.origen + d.direccion), 110 * d.escala, 50, d.escala, 1)
	elseif que == "Rugido" then
		MoonfangVFX.FrostRoar(d.cabeza.CFrame, d.escala, 1) -- la cabeza mirando hacia adelante
	elseif que == "Eclipse" then
		-- d.centro = el centro de la zona en el suelo; 120 studs de radio y la luna a 340 de alto (a escala 1)
		MoonfangVFX.Eclipse(CFrame.new(d.centro), 120 * d.escala, 340 * d.escala, d.escala, 1)
	end
end)
```

### El daño sincronizado con lo que se ve (servidor)

```lua
-- el pesado: el daño cuando muerde
evento:FireAllClients("Pesado", { rival = rival, escala = 3 })
task.delay(MoonfangVFX.MoonFangImpact, function()
	hacerDanio(rival, 40) -- tu función y tus valores
end)

-- el Eclipse: un golpe cuando cae la columna y otro con la detonación
evento:FireAllClients("Eclipse", { centro = centro, escala = 3 })
task.delay(MoonfangVFX.EclipseTimes.Impact, function() danioEnZona(centro, 120 * 3, 30) end)
task.delay(MoonfangVFX.EclipseTimes.Detonation, function() danioEnZona(centro, 120 * 3, 60) end)
```

### El rugido como escape de combos (servidor)

La idea es que Moonfang lo pueda usar **aunque le estén pegando**, y que **empuje hacia atrás** a los que tiene cerca para escapar. La prioridad (que corte su aturdimiento y el combo del rival) va en tu sistema de combate. El empujón sale en el momento del rugido y llega hasta donde llega la onda del suelo:

```lua
local Debris = game:GetService("Debris")

local function rugido(moonfang: Model, escala: number, rivales: { Model })
	-- tu sistema de combate: se puede usar aunque Moonfang esté aturdido; corta su aturdimiento y el combo del rival
	evento:FireAllClients("Rugido", { cabeza = moonfang.Head, escala = escala })
	task.delay(MoonfangVFX.FrostRoarImpact, function()
		local centro = moonfang:GetPivot().Position
		local radio = MoonfangVFX.FrostRoarRadius * escala
		for _, rival in rivales do
			local raiz = rival:FindFirstChild("HumanoidRootPart") :: BasePart?
			if raiz and (raiz.Position - centro).Magnitude <= radio then
				local dir = (raiz.Position - centro) * Vector3.new(1, 0, 1)
				dir = if dir.Magnitude > 0.1 then dir.Unit else moonfang:GetPivot().LookVector
				local att = raiz:FindFirstChild("RootAttachment") :: Attachment?
				if not att then
					att = Instance.new("Attachment")
					att.Parent = raiz
				end
				local empujon = Instance.new("LinearVelocity")
				empujon.Attachment0 = att
				empujon.MaxForce = math.huge
				empujon.VectorVelocity = dir * 80 + Vector3.new(0, 20, 0) -- la fuerza: ajústala a tu juego
				empujon.Parent = raiz
				Debris:AddItem(empujon, 0.25)
			end
		end
	end)
end
```

**Escala.** Tamaño 1 está pensado para kaijus de unos 22 studs de alto. Si Moonfang mide 66 studs, usa escala 3.

- Los golpes (M1, pesado y bloqueo) **se adaptan solos al alto del rival** si le pasas su Model.
- Las skills se escalan con `escala`. El Eclipse también acepta otro radio y otra altura, y todo se ajusta solo.

## Para que se vea como en el video

- El video es de mi simulador, de noche y con Bloom. El lobo y el rival son cajas de prueba.
- Los golpes salen delante de lo que ve la cámara y miran hacia ella.
- **Medialuna:** son trazos de **Beams** que miran a la cámara, más una luz que la sigue. Va de canto a propósito. Las losas y las rocas miran con un Raycast **el color y el material del suelo** donde salen. En el video son grises porque el suelo de prueba es oscuro.
- **Ola de hielo:** los bloques de hielo son Parts de material `Ice`, anclados, sin colisión ni toques.
- **Rugido:** busca el suelo bajo la cabeza (un Raycast hacia abajo) para la onda de escarcha y las púas.
- **Eclipse:**
  - Es gigante a propósito: la zona es de 120 studs de radio y la luna está a 340 studs × escala, con un disco de unos 250.
  - La luna y los destellos gigantes son **BillboardGuis** y la columna son **Beams**. Así pueden medir más de 100 studs, el tope de las partículas.
  - Mientras dura, el mundo se oscurece (un `ColorCorrectionEffect` en `Lighting`) y la pantalla destella con el golpe y la detonación. Solo pasa en el cliente y cerca de la zona; `MoonfangVFX.ScreenFX = false` lo apaga.
  - Los cristales son Parts de material `Ice` con una punta.
- Las grietas, los anillos y las marcas del suelo son Decals pensados para suelo plano.

## Rendimiento

En el pico:

| Efecto | Partículas | Otras piezas |
|---|---|---|
| Golpes (M1, pesado, bloqueo) | de 60 a 160 | — |
| Medialuna | unas 1100 | unas 118 losas, 62 rocas y 240 Beams |
| Ola de hielo | unas 1800 (casi todas de humo) | unos 120 bloques y losas, y 60 rocas |
| Rugido helado | unas 150 | 3 Decals en el suelo |
| Eclipse | unas 1600 | 13 BillboardGuis, 20 Beams, unos 170 cristales y losas (100 con punta), 490 pedazos y hasta 19 PointLights encendidas a la vez |

`MoonfangVFX.Quality = 0.6` baja las partículas, los pedazos, las losas y los trazos (por ejemplo, en celulares).

## Modelos de Blender (opcional)

Las piezas sólidas se pueden cambiar por modelos hechos en Blender (una **MeshPart** cada una). Ponlos en `MoonfangVFX.Meshes` con el nombre de la pieza y el módulo los usa en vez de los bloques:

```lua
local MoonfangVFX = require(ReplicatedStorage.MoonfangVFX)
local modelos = ReplicatedStorage.MoonfangMeshes   -- una carpeta con tus MeshParts
MoonfangVFX.Meshes.IceChunks = modelos.IceChunk     -- los pedazos de hielo de la detonación de la Medialuna
MoonfangVFX.Meshes.IceSlab = modelos.IceSlab        -- las placas de hielo que saltan en el corte
MoonfangVFX.Meshes.IceBlocks = modelos.IceBlock     -- los bloques de hielo de la Ola de hielo
MoonfangVFX.Meshes.IceCrown = modelos.IceSpike      -- los picos de hielo gigantes del borde del Eclipse
MoonfangVFX.Meshes.IceCrystals = modelos.IceCrystal -- los cristales que brotan en la zona del Eclipse
```

- El modelo se clona y se escala al tamaño de cada pieza, y conserva su material, su color y su textura.
- También sirve para las rocas del corte, con los nombres `RocksOut`, `RocksIn` y `RocksUp`. Con un modelo, la roca ya no toma el color del suelo.

## Las 31 texturas

Están en `textures/` (y en el ZIP). El plugin las sube todas.

**Propias de Moonfang (`mf_`):**

| Textura | Qué es | Dónde se usa |
|---|---|---|
| `mf_chomp_4x4` | los colmillos de cristal que se cierran y se rompen (16 cuadros) | M1, pesado |
| `mf_shard_2x2` | cuatro esquirlas de cristal facetadas | casi todo el kit |
| `mf_spike` | una aguja de cristal | M1, pesado, Medialuna, Ola |
| `mf_crescent` | media luna con borde brillante | pesado, bloqueo, Medialuna |
| `mf_blade_solid`, `mf_blade_line`, `mf_blade_glow` | el cuerpo, el filo y el halo de los Beams de la media luna | Medialuna, Eclipse |
| `mf_frost_cracks` | grietas de escarcha que salen del centro | M1, Medialuna, Ola, Rugido, Eclipse |
| `mf_frost_patch` | escarcha que se forma en el suelo | Medialuna, Ola, Rugido, Eclipse |
| `mf_ice_spikes_2x2` | púas de cristal de hielo | Rugido |
| `mf_moon_eclipse_4x4` | la luna llena que se va eclipsando (16 cuadros; súbela de 1024) | Eclipse |
| `mf_eclipse_sigil` | el círculo lunar del suelo, con las 8 fases de la luna | Eclipse |
| `mf_moonbeam` | la luz de luna que cae en vetas (Beams de la columna) | Eclipse |

**Del proyecto (de los otros kits):** `kz_beam_ring` (anillo), `kz_wind_arcs` (arcos de viento) y `om_cubes_2x2` (pedazos de tierra).

**Kenney (CC0):** `kk_circle_02` (anillos del suelo y ondas), `kk_smoke_04` y `kk_smoke_07` (humo), `kk_star_06`, `kk_star_08` y `kk_star_09` (destellos), `kk_trace_01` y `kk_trace_03` (rayas y chispas).

**Effekseer (CC0):** `fx_glow` (resplandor), `fx_halo` (corona de rayos), `fx_smoke_2x2` (humo realista), `fx_fog2001` (vaho), `fx_spark002` (chispas), `fx_particle02` (partículas de luz) y `fx_wind_swirl` (remolino).

### Licencias

- `kk_*` son de Kenney (CC0) y `fx_*` son de las muestras de Effekseer (CC0). Ver los archivos de licencia en `textures/`.
- `mf_*`, `kz_*` y `om_*` se generaron para este proyecto: son tuyas.

## Los videos

En `preview/`:

1. `1_M1_Mordiscos`
2. `2_Pesado_y_Bloqueo`
3. `3_Skill1_Medialuna`
4. `4_Skill2_OlaDeHielo`
5. `5_Skill3_Rugido`
6. `6_Skill4_Eclipse`

## Si quieres cambiar algo

Todo el kit está en `KaijuZero_VFX/tools/vfx_moonfang.py`:

- arriba están los colores;
- después cada ataque, con sus tiempos y sus capas:
  - `T_BITE1` y `T_FIN` (M1), `T_BITE` y `T_SHATTER` (pesado), `T_GUARD` (bloqueo);
  - `TW` (Medialuna) y `TWW` y `WAVE_FIELD` (Ola);
  - `T_ROAR` y `ROAR_RADIUS` (Rugido);
  - `ER`, `EH`, `TE_C`, `TE_I`, `TE_E` y `TE_D` (Eclipse).

Sus texturas propias salen de `KaijuZero_VFX/tools/gen_moonfang_textures.py`.

Para regenerar, desde `KaijuZero_VFX/tools`:

1. `python gen_luau.py ../roblox` escribe los módulos de todos los kaijus.
2. Si cambiaste texturas, `python gen_plugin.py` actualiza el plugin.

La prueba `KaijuZero_VFX/tools/test_luau/run_runtime.py` ejecuta todo el kit contra un Roblox simulado. Comprueba:

- dónde salen los golpes;
- que caigan los colmillos;
- que la hoja corte el suelo;
- que la ola deje sus bloques;
- que el rugido ponga su onda en el piso y exporte el momento y el radio del empujón;
- que el Eclipse saque la luna gigante, la columna, los cristales con punta y los pedazos;
- que no quede nada vivo al terminar cada efecto.
