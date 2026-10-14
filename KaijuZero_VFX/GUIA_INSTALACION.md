# VFX de fuego de KAIJU ZERO: guía de instalación

## Qué hay aquí

| Carpeta / archivo | Para qué sirve |
|---|---|
| `roblox/KaijuFireVFX.rbxmx` | El ModuleScript listo para insertar en Studio. |
| `roblox/KaijuFireVFX.lua` | El mismo código en texto, si prefieres copiar y pegar. |
| `roblox/texturas_necesarias.txt` | Las 36 imágenes que usa el módulo. |
| `textures/` | Las imágenes que hay que subir a Roblox. |
| `preview/` | Videos simulados de cada efecto. |
| `tools/` | Generadores (texturas, simulador, módulo). No hace falta tocarlos. |

## Efectos incluidos

### Habilidades (pared de llamas en línea recta)

| Función | Qué es | Duración |
|---|---|---|
| `H1_Explosion(cf, largo, escala, sacudida)` | **H1**: el tajo detona en el punto de impacto (destello, onda de choque, polvo y rocas en llamas). Desde ahí brota hacia adelante una **pared de picos de fuego** de alturas variadas. Los picos se hunden de vuelta en el suelo y dejan la línea quemada y brillando, con brasas, humo oscuro y llamitas. | 3.6 s |
| `H1_ExplosionIgnition(cf, largo, escala, sacudida)` | **H1 Ignition**: la misma idea en **rojo carmesí** con núcleo blanco-rosado. Es más alta y más larga (×1.35), arde más tiempo y deja **marcas de fuego** unos 4 s. | 6.8 s |
| `H3_Detonation(cf, largo, escala, sacudida)` | **H3**: las rocas que dejó el rayo se ponen al rojo y **detonan en cadena**. Cada roca levanta su racimo de pilares y entre todas forman la pared de llamas. Al final del rayo hay un remate: un **pilar gigante** que revienta arriba en fuego y humo. | 3.9 s |
| `H3_DetonationIgnition(cf, largo, escala, sacudida)` | **H3 Ignition**: en carmesí, con pilares más altos, y deja una marca de fuego en cada roca. | 6.5 s |

### Otros efectos

| Función | Qué es | Duración |
|---|---|---|
| `GiantExplosion(cf, escala, sacudida)` | **Explosión gigante**: destello, onda de choque, ola de polvo, bola de fuego, rocas en llamas con estela, hongo de humo y **fuego en el suelo durante 5 s**. | 5.8 s |
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

   Usa el ID de la **imagen**, no el de un Decal. Si solo vas a usar la H1 y la H3 (con sus versiones Ignition), basta con estas 19 texturas:

   `fx_burst_a, fx_burst_fan, fx_fire_2x2, fx_glow, fx_line, fx_shock_spiky, fx_star, kk_circle_03, kk_fire_01, kk_fire_02, kk_flare_01, kk_muzzle_01, kk_muzzle_04, kk_muzzle_05, kk_smoke_04, kk_smoke_07, kk_smoke_08, kk_trace_01, kz_scorch`

## Cómo llamarlo

Llámalo desde un **LocalScript**. El servidor avisa a todos los clientes con un RemoteEvent y cada cliente reproduce el efecto. Así no se carga el servidor y la sacudida de cámara funciona.

### H1 y H3 (efectos en línea)

`cf` es el **inicio de la línea en el suelo**, mirando hacia donde avanza la pared. En la H1 es el punto de impacto del tajo; en la H3, el inicio del rayo. La pared crece hacia adelante (`cf.LookVector`) a lo largo de `largo` studs.

```lua
-- LocalScript (por ejemplo en StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KaijuFireVFX = require(ReplicatedStorage.KaijuFireVFX)
local evento = ReplicatedStorage:WaitForChild("KaijuHabilidadVFX") -- RemoteEvent

evento.OnClientEvent:Connect(function(habilidad: string, inicio: Vector3, direccion: Vector3, largo: number?, ignition: boolean)
	-- la línea va pegada al suelo: quita la parte vertical de la dirección
	local plana = Vector3.new(direccion.X, 0, direccion.Z).Unit
	local cf = CFrame.lookAt(inicio, inicio + plana)
	if habilidad == "H1" then
		if ignition then
			KaijuFireVFX.H1_ExplosionIgnition(cf, largo, 1, 1)
		else
			KaijuFireVFX.H1_Explosion(cf, largo, 1, 1)
		end
	elseif habilidad == "H3" then
		if ignition then
			KaijuFireVFX.H3_DetonationIgnition(cf, largo, 1, 1)
		else
			KaijuFireVFX.H3_Detonation(cf, largo, 1, 1)
		end
	end
end)
```

```lua
-- Server (cuando la H1 impacta)
evento:FireAllClients("H1", puntoDeImpacto, kaiju.HumanoidRootPart.CFrame.LookVector, 100, enIgnition)
```

- **Largo**: si pasas `nil`, se usa el largo de diseño (H1: 100, H1 Ignition: 135, H3: 100, en studs, por la escala). Para que los picos sigan pegados entre sí, usa un largo cercano a `100 × escala`. Con líneas mucho más largas a la misma escala, los picos se separan.
- **Escala**: con `1`, los picos de la H1 miden unos 32 studs de alto (y hasta unos 45 los más altos). Para un kaiju más grande prueba de `1.5` a `2`.
- **Sacudida**: `0` o `nil` la desactiva, `1` es normal y `2` es fuerte. La H3 sacude suave en la primera roca y fuerte en el remate.

### Explosión gigante y las demás

```lua
-- cf = punto del SUELO bajo la explosión (las alturas del efecto se miden desde ahí)
KaijuFireVFX.GiantExplosion(CFrame.new(puntoEnElSuelo), 1, 1)
```

- **Dónde va `cf`**: en `GiantExplosion` y `FireLine`, `cf` es el punto del suelo. En `Explosion` y `ExplosionAnime`, ponlo unos `2.5 × escala` studs por encima del suelo.
- **Escala**: con `1`, la bola de fuego de la explosión gigante mide unos 45 studs.

### Rendimiento

En el pico, la H1 llega a unas 1200 partículas; la H1 Ignition y la H3, a unas 1600; y la H3 Ignition, a unas 1700. `KaijuFireVFX.Quality = 0.6` reduce las partículas, por ejemplo en celulares.

## Para que se vea como en el video

- La vista previa usa **Bloom**. En `Lighting` agrega un `BloomEffect` con *Intensity* 0.6–1, *Size* 24 y *Threshold* 1.5–2. Si se ve demasiado blanco, sube el *Threshold*.
- Los anillos de choque, la quemadura y el brillo del suelo son **Decals**, para que no les afecte ningún límite de tamaño de partícula. Están pensados para suelo plano.
- Los picos de fuego usan la orientación `FacingCameraWorldUp`: siempre quedan verticales aunque la cámara se incline.
- Las rocas son Parts reales (Slate oscuro) que se mueven por código y dejan estela. Al caer levantan polvo y dejan fuego unos segundos.

## Licencias de las texturas (todas libres para uso comercial)

- **Kenney Particle Pack** (`kk_*`): CC0, de kenney.nl. El crédito es opcional. Ver `textures/KENNEY_LICENSE.txt`.
- **Muestras oficiales de Effekseer** (`fx_*`): CC0. Agradecen el crédito a "Effekseer" y a los autores de las muestras. Ver `textures/EFFEKSEER_SAMPLES_LICENSE_CC0.txt`.
- **`kz_*`**: generadas aquí, son tuyas.

## Si quieres cambiar algo

Los números de la H1 y la H3 (tiempos, tamaños, colores, cantidad de picos) están en `tools/vfx_pillars.py`, y los de los demás efectos en `tools/vfx_specs.py`. Después de editarlos se regenera el módulo con:

```
python tools/gen_luau.py roblox
```

Las pruebas que validan el módulo son estas:
- `tools/test_luau/run_runtime.py`: ejecuta cada efecto contra un Roblox simulado. Comprueba que se limpie todo y que la pared llegue al final de la línea.
- `luau-lsp analyze` con las definiciones de Roblox: verifica que todas las propiedades y métodos existan en la API.
