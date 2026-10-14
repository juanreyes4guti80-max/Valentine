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

| Función | Qué es | Duración |
|---|---|---|
| `GiantExplosion(cf, escala, sacudida)` | **Explosión gigante**: destello, onda de choque, ola de polvo, bola de fuego, rocas en llamas con estela que dejan fuego al caer, hongo de humo y **fuego en el suelo durante 5 s** que se apaga poco a poco. | 5.8 s |
| `Explosion(cf, escala, sacudida)` | Explosión de fuego "realista", la de texturas Kenney. | 1.3 s |
| `ExplosionAnime(cf, escala, sacudida)` | Versión con medias lunas y remolinos (texturas Effekseer). Luce mejor con fondos oscuros. | 1.3 s |
| `FireLine(cf, largo, escala)` | Línea de fuego para la H3: una grieta que corre, luego erupción en cadena, muro y humo. | 2.5 s |
| `Shake(intensidad, duración)` | Sacudida de cámara. Solo funciona en el cliente. | — |

Todos los efectos **cierran limpio**: al terminar no queda nada flotando y el contenedor se destruye solo.

## Instalación (unos 10 minutos)

1. **Inserta el módulo.** En Studio, clic derecho sobre `ReplicatedStorage` > *Insert from File…* > elige `roblox/KaijuFireVFX.rbxmx`.
2. **Sube las texturas.** Ve a *View* > *Asset Manager* > botón *Bulk Import* y selecciona todas las imágenes de `textures/` (no hace falta subir la subcarpeta `_no_usadas`).
3. **Pega los IDs.** En el Asset Manager, clic derecho en cada imagen > *Copy ID to clipboard*. Luego, en el módulo, pega el número en la tabla `TEXTURES`:

   ```lua
   kk_fire_01 = "rbxassetid://123456789",
   ```

   Usa el ID de la **imagen**, no el de un Decal. Si solo quieres la explosión gigante, basta con las 18 texturas de esta lista:

   `fx_burst_a, fx_fire_2x2, fx_glow, fx_line, fx_shock_spiky, fx_spark4, fx_star, kk_circle_03, kk_fire_01, kk_fire_02, kk_flare_01, kk_muzzle_01, kk_muzzle_04, kk_muzzle_05, kk_smoke_04, kk_smoke_07, kk_smoke_08, kz_scorch`

## Cómo llamarlo

Llámalo desde un **LocalScript**. El servidor avisa a todos los clientes con un RemoteEvent y cada cliente reproduce el efecto. Así no se carga el servidor y la sacudida de cámara funciona.

```lua
-- LocalScript (por ejemplo en StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KaijuFireVFX = require(ReplicatedStorage.KaijuFireVFX)
local evento = ReplicatedStorage:WaitForChild("KaijuExplosion") -- RemoteEvent

evento.OnClientEvent:Connect(function(puntoEnElSuelo: Vector3, escala: number)
	-- cf = punto del SUELO bajo la explosión (las alturas del efecto se miden desde ahí)
	KaijuFireVFX.GiantExplosion(CFrame.new(puntoEnElSuelo), escala, 1)
end)
```

```lua
-- Server (cuando la H1 impacta)
evento:FireAllClients(posicionDelImpacto, 1)
```

- **Dónde va `cf`**: en `GiantExplosion` y `FireLine`, `cf` es el punto del suelo. En `Explosion` y `ExplosionAnime`, ponlo unos `2.5 × escala` studs por encima del suelo.
- **Escala**: con `1`, la bola de fuego mide unos 45 studs. Para un kaiju más grande prueba de `1.5` a `2.5`.
- **Sacudida**: `0` la desactiva, `1` es normal y `2` es fuerte.
- **Rendimiento**: `KaijuFireVFX.Quality = 0.6` reduce las partículas, por ejemplo en celulares. En el pico la explosión gigante tiene unas 700 partículas.

## Para que se vea como en el video

- La vista previa usa **Bloom**. En `Lighting` agrega un `BloomEffect` con *Intensity* 0.6–1, *Size* 24 y *Threshold* 1.5–2. Si se ve demasiado blanco, sube el *Threshold*.
- Los anillos de choque, la quemadura y el brillo del suelo son **Decals**, para que no les afecte ningún límite de tamaño de partícula. Están pensados para suelo plano.
- Las rocas son Parts reales (Slate oscuro) que se mueven por código y dejan estela. Al caer levantan polvo y dejan fuego unos 2.5 s.

## Licencias de las texturas (todas libres para uso comercial)

- **Kenney Particle Pack** (`kk_*`): CC0, de kenney.nl. El crédito es opcional. Ver `textures/KENNEY_LICENSE.txt`.
- **Muestras oficiales de Effekseer** (`fx_*`): CC0. Agradecen el crédito a "Effekseer" y a los autores de las muestras. Ver `textures/EFFEKSEER_SAMPLES_LICENSE_CC0.txt`.
- **`kz_*`**: generadas aquí, son tuyas.

## Si quieres cambiar algo

Todos los números (tiempos, tamaños, colores, cantidades) están en `tools/vfx_specs.py`. Después de editarlos se regenera el módulo con:

```
python tools/gen_luau.py roblox
```

Las pruebas que validan el módulo son estas:
- `tools/test_luau/run_runtime.py`: ejecuta cada efecto contra un Roblox simulado y comprueba que se limpie todo.
- `luau-lsp analyze` con las definiciones de Roblox: verifica que todas las propiedades y métodos existan en la API.
