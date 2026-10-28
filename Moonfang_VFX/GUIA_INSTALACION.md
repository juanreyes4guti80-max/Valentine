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
- el plugin `SubirTexturasVFX.rbxmx`, que sube las 36 texturas por ti. Está en la carpeta `Plugin_Studio` de GitHub y también te lo mando en el chat.

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
| **Skill 2: Ola de hielo** | `IceWave(cf, largo, apertura, escala, sacudida)` | Golpea el suelo y una **ola densa de humo helado** sale hacia adelante **abriéndose en triángulo**. Sale con fuerza y se va frenando hasta asentarse. El humo tiene volumen: una base densa y azulada, el muro blanco encima y una cresta alta que se arremolina. Abajo va una niebla pegada al suelo, y el borde de adelante se revuelve con polvo de nieve, esquirlas y tierra. El humo se queda atrás como una **estela espesa** que cubre el triángulo y se disipa despacio. A su paso el suelo se rompe y se escarcha, brotan **bloques de hielo** inclinados (más grandes al fondo), saltan losas y salen rocas y pedazos grandes volando. Los bloques de hielo aguantan un par de segundos y revientan en esquirlas. | llega al borde lejano a los **1.12 s** |
| **Skill 3: Rugido helado** (el grito) | `FrostRoar(cabeza, escala, sacudida)` | El frío se junta en el hocico y **ruge**: ondas de sonido heladas, perpendiculares al grito, que avanzan y se abren. También salen líneas de grito, un **chorro de vaho helado** con esquirlas y brillos, y un destello en la boca. En el suelo, bajo él, se abre una **onda de escarcha** con grietas, niebla que sale hacia afuera y un anillo de **púas de hielo**. | ruge a los **0.28 s** |
| **Skill 3: aura de hielo** (la mejora) | `FrostAura(moonfang, escala, duración, intensidad)` | **El contorno es el aura.** Cada jugador ve el aura en el borde de Moonfang **visto desde su cámara**: llamas frías que suben, un borde que brilla, **cristales de hielo que brotan hacia afuera** y se rompen, brillos y vaho. Del contorno de abajo cae vapor helado (como hielo seco) y del cuerpo se desprende escarcha. Si lo miras desde otro lado el aura cambia de lugar: una pata delante del pecho no tiene aura de frente y sí de lado. Al encender, el hielo brota de golpe de todo el contorno; al apagar, se cae. | se enciende en 0.3 s |
| **Skill 4: Eclipse** (ULTIMATE) | `Eclipse(cf, radio, altura, escala, sacudida)` | La zona mide **120 studs de radio** (240 de ancho). Una **luna gigante** aparece sobre ella y se va **eclipsando**, mientras el mundo se oscurece. En el suelo se dibuja un **círculo lunar** con las 8 fases de la luna que marca la zona. La escarcha agrieta el suelo, el hielo y los pedazos de tierra flotan hacia la luna y una niebla helada entra desde el borde. Al quedar tapada, con su corona y el destello del anillo de diamante, cae de golpe una **columna de luz de luna del ancho de toda la zona**, con un contorno nítido. Congela el suelo: brota una **corona de picos de hielo** en el borde y un campo de cristales que salen del centro hacia afuera, y vuelan cientos de pedazos de tierra y cristal. Al final la columna **colapsa** en una línea y todo el hielo **revienta en una detonación**, con destello, cúpula de escarcha, esquirlas y brillos. Con ella vuelve la luna llena. | la columna pega a los **1.42 s** y la detonación es a los **3.55 s** (`MoonfangVFX.EclipseTimes`) |

El daño, el knockback y la duración de la mejora los pones tú en tu sistema de combate. Los momentos de la tabla también están en el módulo: `MoonfangVFX.MoonBiteImpact`, `MoonfangVFX.MoonBiteFinisherImpact`, `MoonfangVFX.MoonFangImpact`, `MoonfangVFX.MoonGuardHitImpact`, `MoonfangVFX.CrescentWaveImpact` y `MoonfangVFX.EclipseTimes` (`Eclipse` = queda tapada, `Impact` = pega la columna, `Collapse` = colapsa, `Detonation` = la detonación).

**En revisión:** el kit se rehace uno por uno. Ya son versión nueva la Medialuna, los mordiscos del M1, la Ola de hielo, el Eclipse y la Skill 3 (rugido y aura de contorno). El pesado todavía usa las mandíbulas de antes, y el aura del bloqueo (`MoonGuard`) todavía es la de antes.

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
	elseif que == "Rugido" then
		MoonfangVFX.FrostRoar(d.cabeza.CFrame, d.escala, 1) -- la cabeza mirando hacia adelante
		MoonfangVFX.FrostAura(d.moonfang, 1, d.duracion)     -- el aura dura lo que dure la mejora
	elseif que == "Eclipse" then
		-- d.centro = el centro de la zona en el suelo; 120 studs de radio y la luna a 340 de alto (a escala 1)
		MoonfangVFX.Eclipse(CFrame.new(d.centro), 120 * d.escala, 340 * d.escala, d.escala, 1)
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
- **Cómo funciona el aura de contorno:** varias veces por segundo, cada cliente lanza rayos (Raycast) desde su cámara **solo contra las partes visibles de Moonfang**. Los puntos del borde son los que tocan el modelo y tienen al lado uno que no lo toca, y de ahí sale el aura. Por eso sigue el contorno desde cualquier ángulo y no tapa el cuerpo con ningún filtro.
  - Necesita que las partes del modelo tengan `CanQuery = true` (lo normal). Las invisibles (`Transparency` 1, como el `HumanoidRootPart` o una caja de golpes) no cuentan.
  - Cuesta unos 450 rayos cada vez que busca el borde, unas 20 veces por segundo. Si Moonfang está lejos de la cámara o `Quality` es baja, busca menos seguido y con menos rayos.
  - El rugido busca el suelo bajo la cabeza (un Raycast hacia abajo) para la onda de escarcha y las púas.
- La media luna de la skill 1 son trazos de **Beams** que miran a la cámara, como pinceladas, más una luz que la sigue. Va de canto **a propósito**: desde atrás se ve fina, como una hoja que apunta hacia donde va.
- Las losas y las rocas de la skill 1 miran con un Raycast **el color y el material del suelo** donde salen. En el video son grises porque el suelo de prueba es oscuro; en tu mapa salen del color de tu pasto, arena o piedra.
- **El Eclipse es gigante a propósito:** la zona es de 120 studs de radio (el doble del largo de la Ola de hielo) y la luna está a 340 studs × escala de alto, con un disco de unos 250 studs. Si en tu mapa queda grande, pásale otro radio y otra altura y todo se ajusta solo.
- La luna, sus brillos y los destellos gigantes son **BillboardGuis**, y la columna son **Beams**. Así pueden medir más de 100 studs, que es el tope de las partículas en Roblox. La textura de la luna (`mf_moon_eclipse_4x4`) son 16 cuadros del eclipse: súbela tal cual, de 1024 × 1024.
- La columna sale **de debajo del disco** de la luna y su contorno son dos líneas finas en los bordes, **según desde dónde la mires**. Si la cámara está dentro de la columna, las cortinas de luz cercanas se aclaran para que se siga viendo.
- Los cristales son Parts de material `Ice` con una **punta** (un cubo parado sobre un vértice). Se pueden cambiar por modelos de Blender (más abajo).
- Mientras dura, el mundo se oscurece (un `ColorCorrectionEffect` en `Lighting`) y la pantalla destella con el golpe y con la detonación. Solo pasa en el cliente y cerca de la zona. `MoonfangVFX.ScreenFX = false` lo apaga.

## Rendimiento

En el pico:

| Efecto | Partículas | Otras piezas |
|---|---|---|
| Medialuna | unas 1100 | unas 118 losas, 62 rocas y 240 Beams |
| Ola de hielo | unas 1800 (casi todas de humo) | unos 120 bloques y losas, y 60 rocas |
| Rugido helado | unas 150 | 3 Decals en el suelo |
| Aura de hielo (por cada Moonfang con la mejora) | unas 350 | unos 450 Raycasts cada vez que busca el contorno (unas 20 por segundo; menos si está lejos) |
| Eclipse | unas 1600 | 13 BillboardGuis, 20 Beams, unos 170 cristales y losas (100 con punta), 490 pedazos y hasta 19 PointLights encendidas a la vez |
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
MoonfangVFX.Meshes.IceCrown = modelos.IceSpike   -- los picos de hielo gigantes del borde del Eclipse
MoonfangVFX.Meshes.IceCrystals = modelos.IceCrystal -- los cristales que brotan en la zona del Eclipse
```

- El modelo se clona y se escala al tamaño de cada pieza, y conserva su material, su color y su textura.
- También sirve para las rocas del corte, con los nombres `RocksOut`, `RocksIn` y `RocksUp`. Con un modelo, la roca ya no toma el color del suelo.

## Licencias de las texturas

- `kk_*` son de Kenney (CC0) y `fx_*` son de las muestras de Effekseer (CC0). Ver los archivos de licencia en `textures/`.
- `mf_*` (las de Moonfang) y `kz_*` se generaron para este proyecto: son tuyas.

## Si quieres cambiar algo

Todo el kit está en `KaijuZero_VFX/tools/vfx_moonfang.py`:

- arriba están los colores;
- después cada ataque, con sus tiempos (`T_CLAW`, `T_FIN`, `T_BITE`, `T_SHATTER`, `TW` de la medialuna, `TWW` y `WAVE_FIELD` de la ola, `T_ROAR`, `FROST_AURA`, y `ER`, `EH`, `TE_C`, `TE_I`, `TE_E` y `TE_D` del eclipse) y sus capas.

Sus texturas propias salen de `KaijuZero_VFX/tools/gen_moonfang_textures.py`.

Para regenerar, desde `KaijuZero_VFX/tools`:

1. `python gen_luau.py ../roblox` escribe los cuatro módulos.
2. Si cambiaste texturas, `python gen_plugin.py` actualiza el plugin.

La prueba `KaijuZero_VFX/tools/test_luau/run_runtime.py` ejecuta todo el kit contra un Roblox simulado. Comprueba:

- dónde salen los golpes y que se limpie todo;
- que caigan los colmillos;
- que el Eclipse saque la luna gigante, la columna de luz, los cristales con punta y los pedazos, y que no quede nada al terminar;
- que las auras salgan del cuerpo, sigan al modelo y se apaguen;
- que el aura de hielo salga del **contorno**: una mano delante del pecho no tiene aura vista de frente y sí vista de lado, y nada sale de las partes invisibles;
- que la onda del rugido salga en el suelo.
