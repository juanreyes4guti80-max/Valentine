# VFX de MOONFANG (lobo kaiju lunar de cristal): guía de instalación

## Cómo descargar los archivos

Hay dos caminos y los dos te dan la misma carpeta `Moonfang_VFX`.

**A. El ZIP del chat (lo más fácil).** Descarga `Moonfang_VFX.zip` y descomprímelo:

- en Windows: clic derecho > *Extraer todo…*;
- en Mac: doble clic.

**B. Desde GitHub.**

1. Abre el repositorio `juanreyes4guti80-max/Valentine`.
2. Elige la rama **`claude/inspiring-fermi-z0y6if`** con el botón de la rama (arriba a la izquierda, dice `main`).
3. Toca el botón verde **Code** > **Download ZIP**.
4. Descomprime el ZIP. Lo de Moonfang está en la carpeta `Moonfang_VFX`.

En Studio vas a usar:

- `roblox/MoonfangVFX.rbxmx`, el módulo;
- el plugin `SubirTexturasVFX.rbxmx`, que sube las 34 texturas por ti. Está en la carpeta `Plugin_Studio` de GitHub y también te lo mando en el chat.

## Instalación (unos 2 minutos, con el plugin)

1. **Instala el plugin (una sola vez).** En Studio, pestaña *Plugins* > *Plugins Folder*. Copia ahí `SubirTexturasVFX.rbxmx` y reinicia Studio.
2. **Inserta el módulo.** Clic derecho sobre `ReplicatedStorage` > *Insert from File…* > `roblox/MoonfangVFX.rbxmx`.
3. **Sube las texturas.** Pestaña *Plugins*, barra **VFX Kaiju** > **Subir texturas**. El plugin las sube y pega los IDs en el módulo.

**Si el plugin falla.** Sube a mano las imágenes de `textures/` desde el Asset Manager, con *Bulk Import*. Después pega el ID de cada **imagen** (no el de un Decal) en la tabla `TEXTURES` del módulo.

**Si en Studio se ve peor que en el video:**

1. Toca **Revisar texturas** en el plugin.
2. Sube la calidad gráfica al máximo.
3. Prueba con la luz por defecto y un `BloomEffect` en `Lighting`: *Intensity* 0.6–1, *Size* 24, *Threshold* 1.5–2.

## El kit

**Identidad:** luz de luna fría (plata y blanco), hielo y azul cristal, esquirlas afiladas, medias lunas y destellos de estrella. Formas cortantes y brillantes. Así no se confunde con Omnívora, que es nebulosa suave, púrpura y agujeros negros.

| Ataque | Función | Qué se ve | Momento clave |
|---|---|---|---|
| **M1** mordiscos 1-3 | `MoonBite(rival, escala, sacudida)` | **Solo los colmillos**, sin encía: dos filas de colmillos de cristal (caninos grandes, incisivos y muelas) se cierran de golpe sobre el rival y quedan **trabadas**, con los caninos cruzados. De la mordida salen chispas de hielo hacia los lados y vaho helado. Los colmillos se quedan clavados un instante y se rompen en esquirlas. Queda una **herida de escarcha** que gotea cristalitos durante un segundo, como el sangrado del Primal Bite. | los colmillos se traban a los **0.1 s** |
| **M1** mordisco 4 | `MoonBiteFinisher(rival, escala, sacudida)` | El remate es una **embestida**, como el último mordisco del Frenzied Feast. Unas líneas de velocidad se cierran sobre el rival y dos filas de colmillos más grandes, con su eco, se traban de golpe, se rompen y revientan en una **flor de púas de hielo**. Suelta más esquirlas y vaho, y la herida de escarcha es más grande. | se traban a los **0.14 s** |
| **Pesado** | `MoonFang(rival, escala, sacudida)` | Unas mandíbulas de luz plateada se cierran de golpe sobre el rival. De la mordida brotan agujas de cristal que crecen y **estallan**, con dos ondas de media luna. | muerde a los **0.14 s**; los cristales estallan a los **0.62 s** |
| **Bloqueo** (mientras bloquea) | `MoonGuard(moonfang, escala, duración, intensidad)` | Aura de escarcha que delinea todo su cuerpo en hielo y plata, con esquirlas de cristal flotando. | se enciende en 0.15 s |
| **Bloqueo** (cada golpe bloqueado) | `MoonGuardHit(moonfang, escala, sacudida)` | Una media luna de luz aparece como escudo delante de él, con esquirlas que rebotan a los lados. | 0.02 s |
| **Skill 1: Medialuna** | `CrescentWave(cf, largo, escala, sacudida)` | De un zarpazo lanza una **media luna de energía** que vuela **vertical y de canto**. De lado se ve la media luna, con la punta hacia adelante. Desde atrás (la cámara del jugador) se ve una hoja fina que apunta hacia donde va. Tiene el filo blanco y duro, y el cuerpo celeste y azul hecho de trazos finos. Mientras vuela deja una **estela de humo frío**, brillos y esquirlas. Su cuerno de abajo **corta el suelo**: se abre una grieta con escarcha y **las losas del suelo saltan inclinadas a los dos lados** (algunas son placas de hielo). También salen **rocas cúbicas** que caen y se quedan un rato en el camino antes de desmoronarse. Las losas y las rocas toman **el color y el material de tu suelo**. Al llegar al final **detona en hielo**: un destello, una cúpula de ondas, lanzas de hielo, una nube helada, viento frío por el suelo, una corona de púas, pedazos de hielo y un **cráter de losas**. | detona a los **0.76 s** (`MoonfangVFX.CrescentWaveImpact`) |
| **Skill 2: Ola de hielo** | `IceWave(cf, largo, apertura, escala, sacudida)` | Golpea el suelo y una **ola de hielo** sale hacia adelante **abriéndose en triángulo**. Es un muro de aire helado y nieve con su cresta de esquirlas y púas, y crece mientras avanza. A su paso brotan **bloques de hielo** inclinados, más grandes al fondo. También saltan losas del suelo, salen rocas volando, el suelo queda escarchado y sube **humo frío** que se queda flotando. Al llegar al borde lejano la ola choca. Los bloques de hielo aguantan un par de segundos y revientan en esquirlas. | llega al borde lejano a los **0.87 s** |
| **Skill 3: Aullido lunar** | `LunarHowl(cabeza, escala, sacudida)` + `LunarAura(moonfang, …)` | La luz se junta en su hocico, aúlla con ondas de sonido y una luna llena enorme aparece detrás de él y lo baña de luz. Después, el aura de luz de luna mientras dure la mejora. | aúlla a los **0.3 s** |
| **Skill 4: Eclipse** | `Eclipse(cf, radio, altura, escala, sacudida)` | Una luna llena aparece sobre la zona y se va eclipsando. La zona se agrieta en escarcha y los pedazos del suelo levitan. Al quedar cubierta cae una columna de luz de luna que hace volar tierra y cristal. Al final queda un anillo de cristal roto. | el golpe es a los **1.15 s**; la columna dura hasta los 2.6 s |

El daño, el knockback y la duración de la mejora los pones tú en tu sistema de combate. Los momentos de la tabla también están en el módulo: `MoonfangVFX.MoonBiteImpact`, `MoonfangVFX.MoonBiteFinisherImpact`, `MoonfangVFX.MoonFangImpact`, `MoonfangVFX.MoonGuardHitImpact` y `MoonfangVFX.CrescentWaveImpact`.

**En revisión:** el kit se rehace uno por uno. Ya son versión nueva la Medialuna y los mordiscos del M1. El pesado todavía usa las mandíbulas de antes.

## Cómo llamarlo

Igual que los otros módulos: el servidor avisa a todos los clientes con un RemoteEvent y **cada cliente** llama al módulo. Así no se carga el servidor y la sacudida de cámara funciona.

```lua
-- LocalScript (por ejemplo en StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MoonfangVFX = require(ReplicatedStorage.MoonfangVFX)
local evento = ReplicatedStorage:WaitForChild("MoonfangVFX") -- RemoteEvent

local guardias = {}

evento.OnClientEvent:Connect(function(que: string, d: any)
	if que == "M1" then
		if d.golpe < 4 then
			MoonfangVFX.MoonBite(d.rival, d.escala, 1)
		else
			MoonfangVFX.MoonBiteFinisher(d.rival, d.escala, 1) -- el 4.º es el remate
		end
	elseif que == "Pesado" then
		MoonfangVFX.MoonFang(d.rival, d.escala, 1)
	elseif que == "BloqueoOn" then
		guardias[d.moonfang] = MoonfangVFX.MoonGuard(d.moonfang, 1)
	elseif que == "BloqueoOff" then
		local g = guardias[d.moonfang]
		if g then g:Stop() guardias[d.moonfang] = nil end
	elseif que == "Bloqueado" then
		MoonfangVFX.MoonGuardHit(d.moonfang, d.escala, 1)
	elseif que == "Medialuna" then
		-- cf en el suelo, mirando hacia donde sale la media luna
		MoonfangVFX.CrescentWave(CFrame.lookAt(d.origen, d.origen + d.direccion), 130 * d.escala, d.escala, 1)
	elseif que == "Ola" then
		-- cf en el suelo, mirando hacia donde sale la ola; 110 studs de largo y 50° de apertura (a escala 1)
		MoonfangVFX.IceWave(CFrame.lookAt(d.origen, d.origen + d.direccion), 110 * d.escala, 50, d.escala, 1)
	elseif que == "Aullido" then
		MoonfangVFX.LunarHowl(d.cabeza.CFrame, d.escala, 1) -- la cabeza mirando hacia adelante
		MoonfangVFX.LunarAura(d.moonfang, 1, d.duracion)     -- el aura dura lo que dure la mejora
	elseif que == "Eclipse" then
		MoonfangVFX.Eclipse(CFrame.new(d.centro), 26 * d.escala, 150 * d.escala, d.escala, 1)
	end
end)
```

```lua
-- Server: el daño sincronizado con lo que se ve (ejemplo con el pesado)
evento:FireAllClients("Pesado", { rival = rival, escala = 3 })
task.delay(MoonfangVFX.MoonFangImpact, function()
	hacerDanio(rival, 40) -- tu función y tus valores
end)
```

**Escala.** Tamaño 1 está pensado para kaijus de unos 22 studs de alto. Si Moonfang mide 66 studs, usa escala 3.

- Los golpes (M1, pesado, bloqueo) **se adaptan solos al alto del rival** si le pasas su Model.
- Las auras se adaptan al modelo que les pases.

**Los bloques de hielo de la skill 2** son Parts de material `Ice`, anclados, sin colisión ni toques. Las losas y las rocas toman el color y el material de tu suelo. Las grietas, los anillos y las marcas del suelo son Decals pensados para suelo plano.

## Para que se vea como en el video

- El video es de mi simulador, de noche y con Bloom. El lobo y el rival son cajas de prueba: el lobo azul oscuro con su cresta de cristal y el rival gris.
- Los golpes salen delante de lo que ve la cámara y miran hacia ella, como los golpes de Kaiju Zero.
- La luna del aullido aparece **detrás y arriba** de la cabeza. Si en tu juego queda tapada o muy alta, cambia `MOON_OFF` en `vfx_moonfang.py`.
- La media luna de la skill 1 son trazos de **Beams** que miran a la cámara, como pinceladas, más una luz que la sigue. Va de canto **a propósito**: desde atrás se ve fina, como una hoja que apunta hacia donde va.
- Las losas y las rocas de la skill 1 miran con un Raycast **el color y el material del suelo** donde salen. En el video son grises porque el suelo de prueba es oscuro; en tu mapa salen del color de tu pasto, arena o piedra.
- La columna del Eclipse es luz que **cae** y es transparente (al revés que el pilar de Omnívora, que sube y es denso).
- La luna del Eclipse está a 150 studs × escala sobre la zona. Si tu cámara no la ve, baja la altura (el 3.er parámetro).

## Rendimiento

En el pico:

| Efecto | Partículas | Otras piezas |
|---|---|---|
| Medialuna | unas 1100 | unas 118 losas, 62 rocas y 240 Beams |
| Ola de hielo | unas 600 | unos 120 bloques y losas, y 30 rocas |
| Eclipse | unas 600 | unos 150 pedazos |
| Golpes | de 60 a 160 | — |

`MoonfangVFX.Quality = 0.6` baja las partículas, los pedazos, las losas y los trazos de la hoja (por ejemplo, en celulares).

## Modelos de Blender (opcional)

Las piezas sólidas se pueden cambiar por modelos hechos en Blender (una **MeshPart** cada una). Ponlos en `MoonfangVFX.Meshes` con el nombre de la pieza y el módulo los usa en vez de los bloques:

```lua
local MoonfangVFX = require(ReplicatedStorage.MoonfangVFX)
local modelos = ReplicatedStorage.MoonfangMeshes -- una carpeta con tus MeshParts
MoonfangVFX.Meshes.IceChunks = modelos.IceChunk -- los pedazos de hielo de la detonación de la Medialuna
MoonfangVFX.Meshes.IceSlab = modelos.IceSlab    -- las placas de hielo que saltan en el corte
MoonfangVFX.Meshes.IceBlocks = modelos.IceBlock  -- los bloques de hielo de la Ola de hielo
```

- El modelo se clona y se escala al tamaño de cada pieza, y conserva su material, su color y su textura.
- También sirve para las rocas del corte, con los nombres `RocksOut`, `RocksIn` y `RocksUp`. Con un modelo, la roca ya no toma el color del suelo.

## Licencias de las texturas

- `kk_*` son de Kenney (CC0) y `fx_*` son de las muestras de Effekseer (CC0). Ver los archivos de licencia en `textures/`.
- `mf_*` (las de Moonfang) y `kz_*` se generaron para este proyecto: son tuyas.

## Si quieres cambiar algo

Todo el kit está en `KaijuZero_VFX/tools/vfx_moonfang.py`:

- arriba están los colores;
- después cada ataque, con sus tiempos (`T_CLAW`, `T_FIN`, `T_BITE`, `T_SHATTER`, `TW` de la medialuna, `TWW` y `WAVE_FIELD` de la ola, `T_HOWL`, `TE_C` y `TE_E` del eclipse) y sus capas.

Sus texturas propias salen de `KaijuZero_VFX/tools/gen_moonfang_textures.py`.

Para regenerar, desde `KaijuZero_VFX/tools`:

1. `python gen_luau.py ../roblox` escribe los cuatro módulos.
2. Si cambiaste texturas, `python gen_plugin.py` actualiza el plugin.

La prueba `KaijuZero_VFX/tools/test_luau/run_runtime.py` ejecuta todo el kit contra un Roblox simulado. Comprueba:

- dónde salen los golpes y que se limpie todo;
- que caigan los colmillos;
- que el Eclipse lance pedazos;
- que las auras salgan del cuerpo, sigan al modelo y se apaguen.
