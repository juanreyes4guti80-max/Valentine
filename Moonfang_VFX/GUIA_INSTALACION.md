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
- el plugin `SubirTexturasVFX.rbxmx`, que sube las 26 texturas por ti. Está en la carpeta `Plugin_Studio` de GitHub y también te lo mando en el chat.

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
| **M1** golpes 1-3 | `MoonClaw(rival, escala, sacudida, ángulo)` | Tres marcas de garra curvas en plata se desgarran sobre el rival, con esquirlas de cristal, chispas de hielo y destellos. | conecta a los **0.05 s** |
| **M1** golpe 4 | `MoonClawFinisher(rival, escala, sacudida, ángulo)` | Dos zarpazos que se cruzan en **X** y revientan en un anillo de cristal con muchas esquirlas. | conecta a los **0.1 s** |
| **Pesado** | `MoonFang(rival, escala, sacudida)` | Unas mandíbulas de luz plateada se cierran de golpe sobre el rival. De la mordida brotan agujas de cristal que crecen y **estallan**, con dos ondas de media luna. | muerde a los **0.14 s**; los cristales estallan a los **0.62 s** |
| **Bloqueo** (mientras bloquea) | `MoonGuard(moonfang, escala, duración, intensidad)` | Aura de escarcha que delinea todo su cuerpo en hielo y plata, con esquirlas de cristal flotando. | se enciende en 0.15 s |
| **Bloqueo** (cada golpe bloqueado) | `MoonGuardHit(moonfang, escala, sacudida)` | Una media luna de luz aparece como escudo delante de él, con esquirlas que rebotan a los lados. | 0.02 s |
| **Skill 1: Medialuna** | `CrescentWave(cf, largo, escala, sacudida)` | De un zarpazo lanza una media luna gigante de luz que vuela a ras del suelo. Abre una cicatriz de grietas de cristal, deja púas de hielo y al final se rompe en esquirlas. | llega al final a los **0.63 s** |
| **Skill 2: Lluvia de colmillos** | `FangRain(cf, escala, sacudida)` | Se marca un círculo de escarcha y del cielo caen 20 colmillos de cristal gigantes que se clavan, brillan y estallan en esquirlas. | caen entre los **0.85 y 1.7 s**; estallan 0.85 s después de clavarse |
| **Skill 3: Aullido lunar** | `LunarHowl(cabeza, escala, sacudida)` + `LunarAura(moonfang, …)` | La luz se junta en su hocico, aúlla con ondas de sonido y una luna llena enorme aparece detrás de él y lo baña de luz. Después, el aura de luz de luna mientras dure la mejora. | aúlla a los **0.3 s** |
| **Skill 4: Eclipse** | `Eclipse(cf, radio, altura, escala, sacudida)` | Una luna llena aparece sobre la zona y se va eclipsando. La zona se agrieta en escarcha y los pedazos del suelo levitan. Al quedar cubierta cae una columna de luz de luna que hace volar tierra y cristal. Al final queda un anillo de cristal roto. | el golpe es a los **1.15 s**; la columna dura hasta los 2.6 s |

El daño, el knockback y la duración de la mejora los pones tú en tu sistema de combate. Los momentos de la tabla también están en el módulo: `MoonfangVFX.MoonClawImpact`, `MoonfangVFX.MoonClawFinisherImpact`, `MoonfangVFX.MoonFangImpact` y `MoonfangVFX.MoonGuardHitImpact`.

## Cómo llamarlo

Igual que los otros módulos: el servidor avisa a todos los clientes con un RemoteEvent y **cada cliente** llama al módulo. Así no se carga el servidor y la sacudida de cámara funciona.

```lua
-- LocalScript (por ejemplo en StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MoonfangVFX = require(ReplicatedStorage.MoonfangVFX)
local evento = ReplicatedStorage:WaitForChild("MoonfangVFX") -- RemoteEvent

local ANGULOS = { 35, -35, 70 } -- M1: cada golpe en otra diagonal
local guardias = {}

evento.OnClientEvent:Connect(function(que: string, d: any)
	if que == "M1" then
		if d.golpe < 4 then
			MoonfangVFX.MoonClaw(d.rival, d.escala, 1, ANGULOS[d.golpe])
		else
			MoonfangVFX.MoonClawFinisher(d.rival, d.escala, 1)
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
		MoonfangVFX.CrescentWave(CFrame.lookAt(d.origen, d.origen + d.direccion), 110 * d.escala, d.escala, 1)
	elseif que == "Lluvia" then
		MoonfangVFX.FangRain(CFrame.new(d.centro), d.escala, 1)
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

**Los colmillos de la skill 2** son Parts de material `Ice`, anclados, sin colisión ni toques. Caen derechos, se quedan clavados un momento y estallan. Las grietas, los anillos y las marcas del suelo son Decals pensados para suelo plano.

## Para que se vea como en el video

- El video es de mi simulador, de noche y con Bloom. El lobo y el rival son cajas de prueba: el lobo azul oscuro con su cresta de cristal y el rival gris.
- Los golpes salen delante de lo que ve la cámara y miran hacia ella, como los golpes de Kaiju Zero.
- La luna del aullido aparece **detrás y arriba** de la cabeza. Si en tu juego queda tapada o muy alta, cambia `MOON_OFF` en `vfx_moonfang.py`.
- La columna del Eclipse es luz que **cae** y es transparente (al revés que el pilar de Omnívora, que sube y es denso).
- La luna del Eclipse está a 150 studs × escala sobre la zona. Si tu cámara no la ve, baja la altura (el 3.er parámetro).

## Rendimiento

En el pico:

| Efecto | Partículas | Otras piezas |
|---|---|---|
| Lluvia de colmillos | unas 600 | 20 colmillos |
| Eclipse | unas 600 | unos 150 pedazos |
| Golpes | de 60 a 140 | — |

`MoonfangVFX.Quality = 0.6` baja las partículas y los pedazos (por ejemplo, en celulares).

## Licencias de las texturas

- `kk_*` son de Kenney (CC0) y `fx_*` son de las muestras de Effekseer (CC0). Ver los archivos de licencia en `textures/`.
- `mf_*` (las de Moonfang) y `kz_*` se generaron para este proyecto: son tuyas.

## Si quieres cambiar algo

Todo el kit está en `KaijuZero_VFX/tools/vfx_moonfang.py`:

- arriba están los colores;
- después cada ataque, con sus tiempos (`T_CLAW`, `T_FIN`, `T_BITE`, `T_SHATTER`, `TW` de la medialuna, `FANGS_EMIT` de la lluvia, `T_HOWL`, `TE_C` y `TE_E` del eclipse) y sus capas.

Sus texturas propias salen de `KaijuZero_VFX/tools/gen_moonfang_textures.py`.

Para regenerar, desde `KaijuZero_VFX/tools`:

1. `python gen_luau.py ../roblox` escribe los cuatro módulos.
2. Si cambiaste texturas, `python gen_plugin.py` actualiza el plugin.

La prueba `KaijuZero_VFX/tools/test_luau/run_runtime.py` ejecuta todo el kit contra un Roblox simulado. Comprueba:

- dónde salen los golpes y que se limpie todo;
- que caigan los colmillos;
- que el Eclipse lance pedazos;
- que las auras salgan del cuerpo, sigan al modelo y se apaguen.
