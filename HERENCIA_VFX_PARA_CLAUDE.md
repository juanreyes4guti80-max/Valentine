# Herencia de los VFX de Kaiju Zero, Omnívora y Astral Colossus: guía para el próximo Claude

Hola. Este documento lo escribió el Claude que hizo los VFX de este proyecto en una sesión de Claude Code en la nube. Esa sesión no ve los modelos ni Roblox Studio del usuario; tú sí (vives en su OneDrive). Aquí está todo lo que necesitas para seguir el trabajo:

- cómo se piensan los efectos;
- cómo se guardan para que exportarlos a Roblox sea fácil;
- qué aprendimos de Roblox a golpes;
- cómo hacer efectos nuevos sobre los modelos reales y subirlos a Studio.

Léelo completo antes de tocar nada. Lo que dice sobre el usuario y sus gustos importa tanto como lo técnico.

**Leyes globales del usuario:** están en `AGENTS.md`, en la raíz del repositorio, y valen para todos los kaijus.

- Los **mordiscos** muestran solo los dientes, como los de Moonfang; nunca la encía ni una mandíbula entera.
- **Nada de auras** de delineado.
- Las **ULTIMATES** son de magnitud enorme.

---

## 1. El usuario y cómo trabajar con él

- **Idioma:** español, tono cercano (tutéalo). Las guías, comentarios de código y mensajes van en español sencillo, sin jerga innecesaria.
- **Proyecto:** un juego de kaijus en Roblox. Personajes con VFX hechos: **Kaiju Zero** (fuego y lava, rojo/carmesí), **Omnívora** (cósmica: azul muy oscuro, celeste y púrpura), **Astral Colossus** (cósmico claro: lavanda y blanco) y **Moonfang** (lobo lunar de cristal: plata, hielo y azul cristal; su kit completo de M1, bloqueo, pesado y skills 1-4 lo diseñé yo y el usuario lo aprobó).
- **Qué valora:** que se vea espectacular y pulido, como VFX de anime o de juego AAA, pero hecho con lo que Roblox permite. Se fija mucho en:
  - que la paleta respete al personaje;
  - que nada se vea como un cilindro o una figura sólida y plana;
  - que todo responda a una misma fuerza, sin capas sueltas encimadas;
  - que los destellos sean cortos y no tapen lo importante;
  - que el efecto cierre limpio, sin partículas que se quedan flotando para siempre.
- **Qué entregar siempre:** el efecto funcionando, un **video o captura** para que lo vea, la **guía** actualizada y el paquete para Studio. Él no programa mucho: las instrucciones van paso a paso.
- **Pregunta poco.** Si algo tiene una opción razonable por defecto, tómala y dilo. Pregunta solo lo que de verdad cambia el resultado.
- **Su queja más reciente:** en Studio los efectos se veían mucho peor que en mis videos, y subir texturas era un martirio. La causa más probable eran IDs de Decal en vez de imagen (ver §6). Para eso existe el plugin `Plugin_Studio/SubirTexturasVFX.rbxmx`. **Tú puedes verlo en Studio de verdad: esa es tu gran ventaja sobre mí.** Úsala para comparar y corregir.

---

## 2. La filosofía: cómo se diseña un efecto

Un efecto es una **pila de capas con un papel cada una**, coreografiadas en el tiempo. Antes de escribir una línea, decide:

1. **La fuerza o la idea física.** ¿Qué lo mueve? Una explosión empuja hacia afuera y el calor sube; un agujero negro tira hacia adentro y hace girar; un rayo corre hacia la punta. Todas las capas obedecen esa fuerza. En la ULTIMATE de Omnívora, un único "campo gravitacional" (`cataField` / `stepTracer`) mueve rocas, polvo, corrientes y víctimas. Por eso se siente como un solo fenómeno.
2. **El tiempo en tres actos:**
   - **anticipación:** la carga, que absorbe energía hacia el centro y avisa dónde va a pasar;
   - **golpe:** destello de 2–3 cuadros, ondas y cuerpo principal;
   - **decaimiento:** humo, brasas, residuos que se apagan y se limpian.

   El golpe tiene que ser instantáneo y el decaimiento lento.
3. **Los papeles de las capas** (un ParticleEmitter o una geometría por papel):
   - destello (núcleo blanco o crema, muy breve, `LightEmission` alto);
   - ondas (anillos en el suelo y en el aire, viento, rayas rápidas);
   - cuerpo (fuego, nebulosa, energía: la masa que lee el ojo);
   - secundarios (lenguas, chispas, estelas, relámpagos, estrellas);
   - escombros (rocas o cubos con gravedad, que toman el color del suelo);
   - humo o polvo (normal, no aditivo, oscuro, que sube y se rompe);
   - residuos (brasas que suben y se apagan, motas que flotan);
   - marcas del suelo (grietas, quemadura, cráter, como Decals).
4. **Valores y paleta.** Contraste de valores: núcleo casi blanco, medio saturado, bordes oscuros. Para cada personaje hay un color dominante y uno de acento que acompaña sin dominar (el púrpura de Omnívora va en vetas, estelas y destellos, nunca como masa principal). El humo es oscuro y opaco; el brillo es aditivo. No todo brilla: si todo es aditivo, todo se lava a blanco.
5. **Forma.** Nada de siluetas cilíndricas o esféricas perfectas: bordes ondulados, lóbulos, ruido, tamaños desiguales, asimetría. Varias velocidades a la vez (lo cercano al centro gira más rápido, lo grande va más lento).
6. **Escala.** Todo se escala con un `scale` o con el tamaño del modelo o de la zona. Los kaijus miden entre 60 y 200 studs; un efecto pensado para 6 studs se ve ridículo.
7. **Iteración.** Haz una vista previa, mírala con ojo crítico como si fueras el usuario, anota lo que falla y corrige. Repite. Mis mejoras más grandes vinieron de mirar cuadros sueltos en el destello, en el golpe y al final, y preguntarme qué sobra y qué falta.

**Errores que el usuario ya señaló y no deben repetirse:**
- Pilar "transparente y lleno de humo": lo quería denso, sin humo, de nebulosa cósmica.
- Destello que se queda demasiado y tapa la explosión: el destello es corto (unos 0.25 s de blanco total como máximo).
- Partículas gigantes que se ven como recortes cuadrados: lo colosal se hace con geometría.
- Tormenta como cilindro sólido: tiene que verse a través, por capas, a distintas velocidades.
- Cámara que se mueve en una habilidad cinemática: se queda quieta y solo se sacude, más fuerte según la fase.
- En las habilidades contra rivales, los rivales caen **hacia abajo** donde estaban, no salen volando de lado.

---

## 3. Cómo está guardado todo (y por qué la exportación es fácil)

### La idea central: una sola fuente de verdad

```
spec en Python (datos)  ──►  simulador (vfx_sim.py)  ──►  videos de vista previa
        │
        └──────────────►  generador (gen_luau.py)  ──►  ModuleScript Luau (.lua y .rbxmx) para Studio
```

- Cada efecto es un **diccionario de Python**, el "spec": capas, tiempos, colores, tamaños, sacudida, luces. No es código; son datos.
- El **mismo spec** alimenta dos cosas:
  - el **simulador**, que imita el sistema de partículas de Roblox y renderiza cuadros y videos;
  - el **generador**, que escribe un ModuleScript con un **motor Luau** compartido y los specs como tablas (`local SPEC_GiantExplosion = {...}`), más una función pública por efecto (`KaijuFireVFX.GiantExplosion(cf, escala, sacudida)`).
- Si cambias un número en el spec, cambian a la vez el video y el juego. Nunca se edita el `.lua` generado a mano: se edita el spec (o el motor en `gen_luau.py`) y se regenera.

### Por qué así se exporta sin dolor

- **Un solo archivo por personaje.** `KaijuFireVFX.rbxmx`, `OmnivoraVFX.rbxmx` y `AstralColossusVFX.rbxmx`. Se insertan con clic derecho en `ReplicatedStorage` > *Insert from File*. Nada de carpetas de partículas a mano.
- **Las texturas se nombran, no se cablean.** El spec dice `"texture": "kz_lava_cracks"`. El generador junta todas las texturas que usa el módulo en una tabla `TEXTURES` arriba del archivo (`kz_lava_cracks = "rbxassetid://0"`) y escribe `roblox/texturas_necesarias.txt`.
- **El plugin llena los IDs.** `Plugin_Studio/SubirTexturasVFX.rbxmx` lleva dentro todas las texturas (PNG en base64). Con un botón:
  1. encuentra los módulos del juego;
  2. sube como Image (`AssetService:CreateAssetAsync`) las texturas que faltan o cuyo ID no carga;
  3. pega los IDs en `TEXTURES`;
  4. recuerda lo que subió (`plugin:SetSetting`), así que con una versión nueva del módulo solo vuelve a pegar.

  Lo genera `tools/gen_plugin.py` y su código está en `tools/plugin_studio/`. **No lo pude probar en Studio real** (solo contra un Studio simulado). Si falla, corrígelo tú con el mensaje de error.
- **El motor hace el trabajo sucio:** crea emisores, programa ráfagas, mueve portadores, limpia todo al final (`cleanup`) y escala.

### Mapa de archivos

```
KaijuZero_VFX/
  GUIA_INSTALACION.md        guía para el usuario (instalación, cómo llamar cada efecto, tiempos)
  roblox/                    KaijuFireVFX.lua / .rbxmx / texturas_necesarias.txt   (GENERADOS)
  textures/                  PNG que usa el módulo (+ licencias Kenney y Effekseer, CC0)
  preview/                   videos del simulador
  tools/
    vfx_specs.py             specs de Kaiju Zero; SPECS = {...} -> KaijuFireVFX
    vfx_lava.py, vfx_pillars.py, vfx_beam.py, vfx_hits.py, vfx_aura.py   más specs (se registran en vfx_specs.py)
    vfx_omnivora.py          specs de Omnívora; SPECS -> OmnivoraVFX (importa vfx_blackhole, vfx_cosmicbeam,
                             vfx_aura, vfx_cataclysm)
    vfx_astral.py            specs de Astral Colossus; SPECS -> AstralColossusVFX
    vfx_moonfang.py          specs de Moonfang (todo su kit); SPECS -> MoonfangVFX. Texturas: gen_moonfang_textures.py
    vfx_pebledon.py          specs de Pebledon (se hace por partes); SPECS -> PebledonVFX. Texturas: gen_pebledon_textures.py
    gen_luau.py              EL MOTOR Luau (texto dentro del .py) + el generador. Escribe los 3 módulos
    vfx_sim.py               simulador general (render, render_beam, render_aura, to_mp4)
    vfx_cataclysm_sim.py     simulador propio de la ULTIMATE de Omnívora
    gen_*_textures.py, make_textures.py, anime_textures.py, hero_texture.py   texturas procedurales
    import_kenney.py, import_effekseer.py, import_astral.py, import_omnivora.py  importan texturas CC0
    gen_plugin.py, plugin_studio/   el plugin que sube texturas
    test_luau/               pruebas: runtime_mock.luau (Roblox simulado), run_runtime.py, run_plugin_test.py
Omnivora_VFX/, AstralColossus_VFX/, Moonfang_VFX/, Pebledon_VFX/   lo mismo por personaje (guía, roblox/, textures/, preview/)
Plugin_Studio/               el plugin listo para la carpeta de Plugins de Studio
KaijuZero_Habilidades/       desglose del video de referencia de las animaciones (pendientes)
```

El repositorio es `juanreyes4guti80-max/Valentine` en GitHub. La última versión está en la rama `claude/inspiring-fermi-z0y6if` (botón Code > Download ZIP).

---

## 4. El formato del spec

### Nivel efecto

```python
MI_EFECTO = {
    "name": "MiEfecto",
    "doc": "Una línea en español: qué es y cuánto dura. Va como comentario en el módulo.",
    "duration": 2.0,                 # después de esto no nace nada nuevo; la limpieza se calcula sola
    "light": {"color": (255, 150, 60), "brightness": 4, "range": 30, "time": 0.35},   # PointLight del golpe
    "shakes": [(0.0, 1.0, 0.6)],     # sacudidas: (segundo, intensidad, duración)
    "layers": [ ... ],               # una capa por papel (ver abajo)
}
```

Claves especiales que activan otros modos del motor; mira el archivo de ejemplo antes de usarlas:

| Clave | Para qué | Ejemplo |
|---|---|---|
| `zone`, `cubes`, `shake_ramp` | efecto en una zona circular con destrucción de cubos | `vfx_omnivora.py` (`COSMIC_PILLAR`) |
| `zone` + `zbeams`, `zfield`, `screen`, `times` | ULTIMATE gigante en una zona. `zbeams`: columnas de Beams que bajan de arriba, en un anillo de cortinas que gira o con `rim` (dos líneas en el contorno de la columna visto desde la cámara). `zfield`: cristales y losas sólidos que brotan con una onda desde el centro, con `tip` (punta de cristal) y `end_at` (todos revientan a la vez). `screen`: `ColorCorrectionEffect` y destello de pantalla solo en el cliente cerca de la zona. `times`: momentos exportados como `<Efecto>Times`. Las capas `bill` son BillboardGuis | `vfx_moonfang.py` (`ECLIPSE`) |
| `orb` | proyectil que nace, vuela creciendo y detona sobre enemigos | `vfx_blackhole.py` |
| `beam`, `beams`, `hit` | rayo apuntable (Beams + Raycast cada cuadro) | `vfx_beam.py`, `vfx_cosmicbeam.py` |
| `rocks` | efecto que sale de las rocas que le pasas | `vfx_pillars.py` (H3) |
| `line` + `blade` | una media luna de energía hecha de trazos finos de Beams que vuela de canto por la línea, con su estela (`emitters`), el corte del suelo (`gash`), las losas que saltan a los lados (`slabs`) y el cráter del final (`crater`); lo demás se sincroniza con eventos a lo largo del camino | `vfx_moonfang.py` (`CRESCENT_WAVE`) |
| `cone` (+ `front`, `field`) | onda en forma de triángulo hacia adelante. Con `front`, emisores que viajan con el frente (sale rápido y se frena: `wave` = T0, TW, freno) y dejan una estela; con `field`, bloques y losas sólidos que brotan donde pasa el frente (los de hielo revientan al final; `mesh` = el nombre en `Meshes`) | `vfx_astral.py`, `vfx_moonfang.py` (`ICE_WAVE`) |
| `zone` + `stomp` | un pisotón que hace brotar una zona a la distancia: la función recibe el pie y el punto. Las capas con `path_emit` (t, n, u, lado, alto) van por el suelo del pie (u = 0) al centro (u = 1); en cada llamada se pasan a `ring_emit` según la distancia. En el `zfield`: `hex` (prisma hexagonal de tres bloques), `centered` (justo en su punto), `query` (el rayo lo toca) y `part_name` | `vfx_pebledon.py` (`CRYSTAL_SPIRE`) |
| `cone` con `head: True` | el triángulo sale **de la cabeza** (un rugido): la función recibe la boca o la cabeza, busca el suelo debajo con un Raycast y pone el triángulo ahí, en horizontal hacia donde mira. Las capas con `head=True` salen de la boca (su `offset` es relativo a ella); las demás, del vértice en el suelo. Exporta `<Efecto>Length`, `<Efecto>Angle`, `<Efecto>Times` y `<Efecto>FrontTime(distancia, largo)` (cuándo pasa el frente por cada punto, para el daño) | `vfx_pebledon.py` (`SEISMIC_ROAR`) |
| `aura` | aura que se adapta a cualquier modelo (Highlight + emisores por parte). **Al usuario no le gustó** ("un delineado y un filtro raro con partículas sueltas"). Tampoco le gustó el aura de contorno que probamos después (abajo, en el estado de Moonfang). Antes de hacer otra aura, pregúntale qué quiere | `vfx_aura.py` |
| `cataclysm` | la ULTIMATE de Omnívora (campo gravitacional, geometría, plan para el servidor) | `vfx_cataclysm.py` |

### Nivel capa (un ParticleEmitter)

```python
{"name": "Fireball",                      # nombre del emisor (único dentro del efecto)
 "texture": "kz_fire_burst_4x4",          # nombre de la textura (sin .png)
 "flipbook": ("Grid4x4", "OneShot", 0, False),   # (layout, modo, fps, empezar al azar); ("Grid2x2","Random",0,True) = cuadro fijo al azar
 "emit": [(0.0, 9), (0.04, 5)],           # ráfagas Emit(): (segundo, cantidad)
 "stream": [(0.2, 1.2, 30, 0)],           # emisión continua: (desde, hasta, tasa inicial, tasa final)
 "shape": {"type": "Sphere", "radius": 2.5, "style": "Surface"},   # o {"type": "Box", "size": (x,y,z)}
 "offset": (0, -1.2, 0),                  # desde el centro, a escala 1
 "direction": "Top", "spread": (180, 180),
 "speed": (20, 38), "drag": 4.2, "accel": (0, 10, 0),
 "lifetime": (0.62, 0.85),
 "size": [(0, 8, 2), (0.15, 17, 3), (1, 19, 3)],          # (t 0..1, tamaño, variación)
 "transparency": [(0, 0), (0.9, 0), (1, 1)],              # siempre termina en 1
 "color": [(0, (255, 255, 255)), (1, (225, 170, 150))],
 "light_emission": 0.12, "brightness": 1.0,               # 0 = normal (humo), 1 = aditivo (brillo)
 "rotation": (0, 360), "rot_speed": (-45, 45),
 "orientation": "FacingCamera",            # o "VelocityParallel" (chispas, rayas), "VelocityPerpendicular" (anillos en el suelo)
 "zoffset": 0}                            # orden de dibujo: el destello adelante (+), el humo atrás (−)
```

Otras claves frecuentes:

- `"decal": True` hace una marca plana del suelo con Decal (sin límite de tamaño).
- `"floor": True` (en efectos que salen de un punto, como el rugido desde la cabeza) pone la capa en el suelo bajo el efecto (Raycast hacia abajo): `offset` horizontal, y su Y es la altura sobre el suelo. `ring = (n, radio)` la reparte en n puntos alrededor, mirando hacia afuera (`pitch` hacia arriba).
- `"bill": True` (en zonas) hace cada partícula con una **BillboardGui + ImageLabel**: sin el tope de 100 studs (la luna del Eclipse, los destellos gigantes).
  - No tiene `LightEmission` (mezcla alfa); `brightness` la hace brillar.
  - `zoffset` es el `StudsOffset` hacia la cámara de verdad, así que se ve un poco más grande.
  - `slide` = [(t, x, y)] corre la imagen en pantalla (studs).
  - `flip_t` = [(t, cuadro)] elige el cuadro del flipbook según la vida (la textura debe medir 1024; o pon `tex_px`).
  - Solo con `ring_emit`.
- `"type": "meteor"` hace rocas de verdad (Parts) con estela y salpicadura al caer: `sprite`, `trails`, `land`.
  - En `sprite`, `aspect` estira la pieza, `upright` la deja derecha y `stick` la deja clavada esos segundos antes de romperse con las capas de `shatter`.
  - `ground` le da el color y el material del suelo (Raycast), y `color_var` la aclara u oscurece un poco.
  - `cube` solo afecta al simulador: la dibuja como el bloque que es en Roblox (sin eso la dibuja como sprite).
  - `shape` de caja reparte de dónde sale cada pieza.
- **Modelos de Blender (`<Módulo>.Meshes`).** Las piezas sólidas se pueden cambiar por una MeshPart: `MoonfangVFX.Meshes.IceChunks = carpeta.IceChunk`.
  - La clave es el nombre de la capa meteor (o `IceSlab` para las placas de hielo del corte de la Medialuna).
  - El módulo clona el modelo, lo escala al tamaño de la pieza y le deja su material y su textura.
  - Así se mezclan bloques hechos en Blender con el VFX: **lo sólido en Blender, las partículas y el movimiento aquí** (lo pidió el usuario).
- `"lit": True` hace que la capa reciba luz de la escena (humo y polvo).
- `"spin": True` usa `LockedToPart`: la capa gira con su pieza y sube en espiral.
- `"ground_mix"` mezcla el color del suelo en la capa (esquirlas).
- `"fade_at"` y `"clear_at"` borran lo que queda a cierto segundo.

Si dudas de una clave, búscala en `gen_luau.py` (`L.<clave>`) y en los specs existentes.

**Reglas del formato:**
- Tiempos en segundos desde la llamada.
- Tamaños y velocidades en studs a escala 1.
- Las secuencias de tamaño y transparencia empiezan en t=0 y terminan en t=1.
- La transparencia termina en 1.
- Ninguna partícula pasa de 100 studs (es el tope de Roblox; el motor y el simulador lo recortan). Las capas `decal` y `bill` no tienen ese tope (el simulador antes recortaba también los decals a 100: ya no).

### Registrar un efecto nuevo

Al final del archivo de specs del personaje:

```python
SPECS["MiEfecto"] = MI_EFECTO   # -> función OmnivoraVFX.MiEfecto(cf, escala, sacudida) en el módulo
```

Y regenera (ver §8).

---

## 5. Qué aprendimos de Roblox (léelo dos veces)

1. **Partículas: máximo 100 studs.** Lo colosal (pilares, agujeros, tormentas, ondas de 500 m) se hace con **geometría**:
   - Beams con `FaceCamera` y texturas que corren;
   - Parts con Decal mirando a la cámara (`CFrame.lookAt`);
   - esferas `Neon` negras para un agujero negro;
   - vidrio (`Glass`) para la distorsión;
   - cadenas de Beams para anillos y corrientes.
2. **Los Decals reciben la luz de la escena.** No tienen `LightEmission`. Truco usado: `Color3` mayor que 1 (por ejemplo 2.5×) para que brillen con Bloom. Si unas grietas no brillan en Studio, la alternativa es un `SurfaceGui` con `LightInfluence = 0` y `Brightness` > 1 sobre una Part invisible. **No lo implementé; pruébalo tú en Studio.**
3. **Las partículas del motor usan `LightInfluence = 0`** (no se lavan con el sol), salvo las capas `lit`. Con un cielo muy claro, lo aditivo (`LightEmission` 1) se lava a amarillo o blanco: el cuerpo de un fuego necesita parte normal (`LightEmission` bajo) y el brillo se da con `Brightness`.
4. **IDs de imagen, no de Decal.** Si subes un PNG como Decal (web u Open Cloud), Roblox te da un ID de Decal que **no funciona** puesto por código en `Texture` (solo Studio lo convierte en la ventana de propiedades). La capa queda invisible. `AssetService:CreateAssetAsync(editableImage, Enum.AssetType.Image, {...})` desde un plugin local da el ID de imagen directo: eso usa el plugin.
5. **Calidad gráfica.** Con calidad baja Roblox dibuja muchas menos partículas. Para juzgar un efecto: Studio > *File* > *Studio Settings* > *Rendering* > *Editor Quality Level* al máximo, y en Play la calidad en manual al máximo.
6. **Todo visual va en el cliente.** El servidor manda un RemoteEvent y cada cliente llama al módulo. Así no se carga el servidor y la sacudida funciona. El daño y el movimiento de personajes van en el servidor; si un efecto mueve personajes, hay un "plan" determinista sin números al azar (por ejemplo `GravitationalCataclysmPlan`) que el servidor usa para calcular lo mismo que dibujan los clientes.
7. **Sacudida de cámara:** un solo mezclador compartido entre los tres módulos (`shared.KZShakeMixer`). Deshace el desplazamiento al empezar el cuadro (`RenderPriority.First`) y aplica la suma después de la cámara (`Camera + 1`). Así la cámara nunca se corre, ni con una cámara fija (Scriptable). Usa siempre `addShakeSource`, no muevas `CFrame` de la cámara a mano.
8. **Rendimiento:**
   - las piezas que se mueven por código van ancladas, sin colisión ni consulta (`CanCollide`, `CanQuery` y `CanTouch` en false) y se mueven juntas con `workspace:BulkMoveTo`;
   - un solo `Heartbeat` por efecto;
   - topes de cantidad;
   - `KaijuFireVFX.Quality` (0.6 en celulares) baja tasas y cantidades.
9. **Limpieza:** cada efecto vive en un `Holder` (una Part invisible); `cleanup` se calcula del spec y destruye todo cuando muere la última partícula. Nada queda vivo. Las pruebas lo comprueban.
10. **Glass** solo refracta con gráficos altos, y a través del vidrio no se ven partículas. **Highlight**: máximo 31 a la vez.
12. **Lo que mide más de 100 studs y mira a la cámara: BillboardGui.** Una BillboardGui con `Size = UDim2.fromScale(studs, studs)`, `LightInfluence = 0`, `Brightness` > 1 y `AlwaysOnTop = false` (el mundo la tapa). El flipbook se hace con `ImageRectOffset` e `ImageRectSize`. Su orden de dibujo contra los Beams no es confiable: diseña para que no se pisen (por ejemplo, la columna del Eclipse es transparente en su parte de arriba y sale de debajo de la luna).
11. **El suelo corta las partículas.** Una partícula es un cartel que mira a la cámara: si es grande y su centro está pegado al piso, el suelo la corta en línea recta (se ve como humo rebanado). Para humo o niebla baja, el centro debe ir a una altura de al menos un tercio de su tamaño; es mejor muchas partículas medianas a unas pocas gigantes. El simulador también lo muestra.

---

## 6. Hacer VFX "a mano" con los modelos reales en Studio

Tú tienes lo que yo no: los modelos y Studio. Hay dos caminos y puedes combinarlos.

### Camino A: con el pipeline (recomendado para efectos que se quedan)

1. Mide el modelo en Studio (`model:GetExtentsSize()`, posición de la boca y de las manos con Attachments). Anota alturas y puntos clave.
2. Escribe el spec en el archivo del personaje, con tamaños pensados para esas medidas o escalables.
3. Haz una vista previa con el simulador (§8) para iterar rápido el tiempo y la composición.
4. Regenera, valida (§8), inserta el módulo en Studio, toca **Subir texturas** en el plugin y **pruébalo sobre el modelo real**.
5. Lo que veas mal en Studio, corrígelo en el spec (no en el `.lua`) y repite. Si el simulador y Studio no coinciden, **manda Studio**: ajusta el simulador o anota la diferencia aquí.

### Camino B: directo en Studio (para prototipos o retoques rápidos)

Si tienes acceso a Studio (por ejemplo con el MCP de Roblox Studio, que ejecuta Luau), puedes armar el efecto con emisores en vivo sobre el modelo, ver el resultado y después pasarlo a spec. Plantilla básica que sigue las mismas reglas del motor:

```lua
-- en el cliente: un efecto de un solo uso que se limpia solo
local function emitter(parent: Instance, p: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false            -- todo por Emit(): control exacto del tiempo
	e.Texture = p.Texture        -- ¡ID de IMAGEN!
	e.Lifetime = p.Lifetime
	e.Speed = p.Speed
	e.Size = p.Size
	e.Transparency = p.Transparency
	e.Color = p.Color
	e.LightEmission = p.LightEmission or 0
	e.LightInfluence = 0
	e.ZOffset = p.ZOffset or 0
	e.Parent = parent
	return e
end

local function play(at: CFrame, scale: number)
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency, holder.Size, holder.CFrame = 1, Vector3.one, at
	holder.Parent = workspace
	local att = Instance.new("Attachment", holder)
	local flash = emitter(att, { Texture = "rbxassetid://...", Lifetime = NumberRange.new(0.12),
		Speed = NumberRange.new(0), Size = NumberSequence.new(10 * scale, 32 * scale),
		Transparency = NumberSequence.new(0, 1), Color = ColorSequence.new(Color3.fromRGB(255, 236, 170)),
		LightEmission = 1, ZOffset = 4 })
	flash:Emit(2)
	-- ... más capas con task.delay(t, function() e:Emit(n) end)
	task.delay(3, function() holder:Destroy() end)   -- después de que muera la última partícula
end
```

Para efectos pegados al modelo (auras, cargas en la boca o las manos):
- usa Attachments dentro de las partes del modelo, para que sigan las animaciones;
- escala con el alto del modelo;
- sáltate la `HumanoidRootPart` y las partes invisibles (hitboxes);
- mira `playAura` en `gen_luau.py` y `vfx_aura.py`.

Cuando el prototipo te guste, **pásalo a spec** (cada emisor es una capa; cada `Emit` es una entrada de `emit`) para que quede en el módulo, con limpieza, `Quality` y sacudida incluidos.

---

## 7. Preparar el entorno (en Windows)

- **Python 3.11 o más nuevo** con `numpy` y `pillow` (`pip install numpy pillow`). Basta para el generador, el simulador y el plugin.
- **ffmpeg** en el PATH, para los videos.
- **Luau** (opcional pero muy recomendado): `luau`, `luau-compile` y `luau-lsp` desde las releases de GitHub de `luau-lang/luau` y `JohnnyMorganz/luau-lsp`. `luau-lsp` necesita las definiciones de Roblox (`globalTypes.d.luau`, del repo de luau-lsp).
- Trabaja desde `KaijuZero_VFX/tools` (los imports son relativos a esa carpeta).

## 8. Comandos

```bash
cd KaijuZero_VFX/tools

# regenerar los módulos de todos los kaijus (.lua, .rbxmx y texturas_necesarias.txt)
python gen_luau.py ../roblox

# regenerar el plugin (después de cambiar texturas o el código del plugin)
python gen_plugin.py

# validar
luau-compile ../roblox/KaijuFireVFX.lua > NUL           # compila (y los otros dos módulos)
luau-lsp analyze --platform=roblox --definitions=@roblox=globalTypes.d.luau ../roblox/KaijuFireVFX.lua
python test_luau/run_runtime.py <ruta a luau>           # ejecuta todos los efectos contra un Roblox simulado
python test_luau/run_plugin_test.py <ruta a luau>       # prueba el plugin contra un Studio simulado
```

Vista previa con el simulador (ejemplo):

```python
import vfx_sim as V, vfx_specs as SP
cam = V.Camera(pos=(0, 30, 90), target=(0, 15, 0), fov=70, W=960, H=540)
V.render(SP.SPECS["GiantExplosion"], "../textures", "frames_tmp", cam,
         bloom={"threshold": 1.0, "intensity": 0.6})
V.to_mp4("frames_tmp", "../preview/mi_prueba.mp4")
```

Para Omnívora importa primero `vfx_omnivora`. La ULTIMATE usa `vfx_cataclysm_sim.render_cataclysm`. Los rayos usan `render_beam` y las auras `render_aura`.

**Antes de entregar:**
1. Compila sin errores.
2. `luau-lsp` sin errores.
3. `run_runtime.py` termina en `RUNTIME OK`.
4. Video revisado cuadro a cuadro en los momentos clave.
5. Guía del personaje actualizada.
6. Si hay texturas nuevas: regenerar el plugin.

---

## 9. Estado del trabajo y pendientes

**Hecho:**
- **Kaiju Zero** (`KaijuFireVFX`):
  - `GiantExplosion` (lava) y `GiantExplosionIgnition` (carmesí, 1.5×);
  - `H3_Detonation` y su versión Ignition;
  - `UltimateBeam` (rayo apuntable, 186 studs);
  - golpes (`SlashHit`, `BurningSlashHit`, `BiteHit`);
  - `CrimsonAura`;
  - explosiones clásicas.
- **Omnívora** (`OmnivoraVFX`):
  - `CosmicPillar`;
  - `BlackHole`;
  - `CosmicBeam` (124 studs);
  - `CosmicAura`;
  - **ULTIMATE `GravitationalCataclysm`**: 23 s, radio de 500 m (1786 studs), 8 fases, plan para el servidor, escena de prueba `CataclysmDemo.client.lua`.
- **Astral Colossus** (`AstralColossusVFX`): `AstralClash`.
- **Moonfang** (`MoonfangVFX`): `MoonBite` y `MoonBiteFinisher` (M1, mordiscos), `MoonGuardHit` (cada golpe bloqueado), `MoonFang` (pesado), `CrescentWave` (skill 1), `IceWave` (skill 2), `FrostRoar` (skill 3) y `Eclipse` (skill 4, la ULTIMATE). **El usuario dio el kit por terminado.** Ver `Moonfang_VFX/GUIA_INSTALACION.md`.
- **Pebledon** (`PebledonVFX`), kaiju de piedra tipo Godzilla con venas de energía turquesa y placas dorsales de cristal cian. **Se hace por partes:** una skill, el video y el visto bueno del usuario antes de la siguiente. Ver `Pebledon_VFX/GUIA_INSTALACION.md`.
  - Paleta (sacada de su imagen): cristal claro `94, 229, 224`, medio `52, 147, 152`, oscuro `39, 121, 127`; roca `93, 85, 76`; panza `164, 148, 133`.
  - **Skill 1 `SeismicRoar` (Rugido sísmico), hecha.** Lo pidió como "un grito hacia adelante que expone a los enemigos, los ralentiza y los empuja un poquito para atrás", con daño moderado, más detallado que el rugido de Moonfang, en sus colores, con "uno que otro efectillo de partícula de fuego" y que **destruya el suelo a medida que avanza y se lleve rocas consigo**. Es un `cone` con `head`: ondas de sonido turquesa que viajan con el frente, fuego cian, losas, rocas que saltan delante del frente y grietas con venas turquesa de las que brota fuego. Su primera reacción a los cuadros: "tiene pintaza".
  - **Skill 2 `BlueBreath` (Aliento azul), hecha.** Pidió un rayo azul como el aliento de Godzilla, del color de las placas, **más delgado** que los de Kaiju Zero y Omnívora, de unos **3 s** y que llegue a **3 veces su tamaño** (lo tomé como su largo de la nariz a la cola: 126 studs a escala 1). La primera versión era un rayo limpio con una doble hélice y aros que viajaban: **no le gustó**. Sus palabras: "no me gusta que tengan como esos círculos alrededor... el rayo de Godzilla es como un fuego concentrado hacia adelante que se mantiene recto. No tiene aros, no tiene vainas raras". Ahora es fuego azul concentrado: un núcleo casi blanco, dos Beams de fuego en vetas (`pb_breath_fire`) que corren muy rápido y llamas que viajan **pegadas al rayo** (capas con `locked=True` = `LockedToPart`, para que el fuego se quede recto al barrer). **En los rayos de fuego no pongas aros ni espirales.**
  - **Skill 3 `CrystalSpire` (Pilar de cristal), hecha.** Un pisotón; una grieta turquesa corre del pie al punto y ahí brota **duro** un pilar de cristal como los de su espalda (unos 33 studs), con fuego cian, rocas, losas y pedazos. El usuario pidió: que salga golpeando (empuja y manda a volar al enemigo: `CrystalSpireTimes.Erupt` y `CrystalSpireHitRadius`), que brille, y **un círculo alrededor que marque la mejora** (cerca del cristal Pebledon gira y corre más rápido: `CrystalSpireRadius`). Aquí el círculo sí lo pidió él. El cristal es un **marcador**: un prisma hexagonal de tres bloques de `Glass` girados 60° (`hex` en el grupo), con un núcleo de `Neon` adentro, llamado `PebledonCrystal`, con `CanQuery` para que el aliento se corte en él. **Tarea para Blender:** `Meshes.PebledonCrystal` (el pilar) y `Meshes.CrystalShards` (los chicos).
  - **El círculo de la mejora es grande a propósito:** 70 studs de radio (140 de lado a lado). Con 26 el usuario dijo: "es muy chiquito, con ese rango no llegas a nada". La mejora vale **mientras Pebledon esté dentro**, no al pisarlo. El grupo de cristales no crece con el círculo (`CR` y `cr()` en el spec).
  - **Combo `CrystalRefract`, hecho (idea del usuario).** Si el aliento le pega al cristal, del cristal salen rayos más delgados (`CrystalRay`, el mismo fuego azul) hacia cada enemigo del círculo mientras le siga pegando; el servidor reparte el daño. Es un rayo por objetivo (`playRefract` usa `playBeam`), con `:SetTargets` y `:Stop`. Un spec de rayo con `refract = {name, h}` genera las dos funciones. En el simulador, `render(..., beams=[...])` dibuja rayos (`BeamSim`) en la misma escena que una zona.
  - **ULTIMATE, por elegir:** el usuario pidió ideas y que la barra siga alta.
  - La figura de prueba para los videos son cajas (unos 25 studs de alto, boca a ~20 studs, mira hacia +X) con las placas que brillan (`glow` en los props del simulador).
- **Plugin** `SubirTexturasVFX`.

**Pendiente o por verificar (tu terreno):**
1. **Probar el plugin en Studio real** y corregir lo que falle. Usa `CreateAssetAsync` y EditableImage; no pude probarlos.
2. **Comparar cada efecto en Studio contra su video** con texturas bien puestas y calidad al máximo. Lo más probable de ajustar:
   - grietas y marcas del suelo que no brillan (probar `SurfaceGui` sin luz);
   - fuego que se lava con cielos claros (bajar `LightEmission` y subir `Brightness`).
3. Rocas de destrucción para Astral Colossus: el usuario iba a mandar detalles.
4. Animaciones del kit de Kaiju Zero (A1–A4, ver `KaijuZero_Habilidades/REFERENCIA_VIDEO.md`): necesitan el `.blend` con el rig.
5. **Moonfang, opinión del usuario: 3/10 al primer kit.** Solo le convenció la ulti (Eclipse). Pidió:
   - M1 como **mordiscos** al estilo de Devil Dinosaur (Marvel Rivals). Ojo con lo que quiere: **un buen mordisco muestra solo los dientes, no la encía**. No le gustaron ni las mandíbulas con encía y dientes ("eso es Pokémon") ni dos arcos de luz como una boca sin dientes ("solo veo la encía"). Ya están: `MoonBite` es un flipbook (`mf_chomp_4x4`) de dos filas de colmillos de cristal que se cierran, se traban, se rompen, más chispas, vaho y una herida de escarcha que gotea. No pude ver el video de Devil Dinosaur (red bloqueada); si tú puedes, compáralo;
   - el resto del kit, uno por uno cuando él diga. El pesado (`MoonFang`) todavía usa las mandíbulas con dientes (`kz_bite_4x4`) que no le gustaron.

   Las auras tampoco le convencieron en el juego. Codex las subió a Studio y dijo: "era como ponerle un delineado alrededor, un filtro extraño, y encima unas partículas de fuego sueltas". Su idea de aura: **"el delineado se convierte en el aura"**. Solo el borde exterior, visto desde la cámara, lleva el aura. Si miras de lado a un kaiju con las manos al frente, las manos tienen aura; de frente, las manos quedan dentro del pecho y el aura pasa a los hombros. Probamos un aura así (`FrostAura`, el modo `silhouette`): cada cliente lanzaba una rejilla de Raycasts desde su cámara solo contra las partes visibles y el aura salía del contorno, con llamas frías, cristales hacia afuera y vaho por abajo. La prueba demostraba que una mano delante del pecho no tenía aura de frente y sí de lado. **Tampoco le gustó**: se quitó del kit junto con el aura del bloqueo (`MoonGuard`). El código está en el commit `90c45e6` por si sirve.

   **La Skill 3 es un rugido (`FrostRoar`)** y le gustó tal cual. En el juego es un **escape de combos**: se puede usar aunque le estén pegando (con prioridad) y empuja hacia atrás a los que están cerca. El módulo exporta `FrostRoarImpact` (0.28 s) y `FrostRoarRadius` (30 studs × escala, lo que llega la onda del suelo). La guía trae un ejemplo de servidor con `LinearVelocity`. La mejora (todo más rápido) es de animación y gameplay.

   **La ULTIMATE (Eclipse) le encantó** ("brutalísima"). Si haces otra ulti, ese es el estándar: magnitud enorme, varias fases (carga, golpe, sostén, detonación final), oscurecer el mundo y piezas sólidas.

   **La skill 1 (Medialuna) va por la 3.ª versión.** Lo que pidió en cada vuelta, para que no se repita:
   - la media luna se ve **de lado**; desde la cámara del jugador (atrás) debe verse **de canto**, como una hoja que apunta hacia donde va (curvarla para que se lea como media luna desde atrás "se ve horrible");
   - estilo **energía anime**: filo blanco muy marcado y cuerpo celeste y azul, nada de una figura blanca lisa ni de vetas borrosas;
   - con detalle: estela de humo frío, brillos y esquirlas;
   - el corte del suelo debe verse como hielo cortando la tierra, con **rocas cuadradas** (es Roblox) y **pequeñas** que quedan en el camino;
   - la explosión final, intensa.

   **La skill 2 ahora es la Ola de hielo (`IceWave`).** Lo pidió así: "una ola de hielo que crece en formato triangular y va dejando a su paso destrucción, bloques de hielo y humo". Usa el modo `cone` con `front` y `field`. En la 2.ª vuelta pidió más: "que se sienta como una ola densa de humo de hielo de verdad que avanza y va dejando destrozos". Por eso el humo lo sueltan emisores que viajan con el frente (y se frenan detrás: la estela), y el frente se frena al final. En la 3.ª ("aún puede mejorar") le di volumen: humo realista (`fx_smoke_2x2`, no nubes de caricatura), una base más oscura y azulada, un borde que se revuelve (humo más rápido que el frente), grietas oscuras de suelo roto y pedazos grandes.

   **La skill 4 (Eclipse, la ULTIMATE) se rehízo en grande.** Dijo que el radio era "chiquito" y que las ultis del juego son de magnitud fuerte (Omnívora: un agujero negro que se come la tierra; Kaiju Zero: un rayo intensísimo y una bomba nuclear; Bublisk: un tsunami; Venomer: sale del suelo con una explosión de veneno). Pidió conservar la idea (una luna arriba que lanza un rayo hacia abajo) pero "súper clean, súper cool" y mucho más grande. Ahora:
   - la zona es de 120 studs de radio y la luna está a 340, con un disco de unos 250;
   - la luna es un flipbook del eclipse (`mf_moon_eclipse_4x4`) en una BillboardGui, sin un disco negro suelto que se vea fuera de la luna;
   - en el suelo hay un círculo lunar (`mf_eclipse_sigil`);
   - la columna son cortinas de Beams con un contorno según la cámara;
   - brota una corona de picos de hielo y un campo de cristales, y al final una detonación;
   - el mundo se oscurece (`screen`).

   **Tarea para ti con Blender:** hay cinco piezas que serían mejores como modelo:
   - los pedazos de hielo del final de la Medialuna (`IceChunks`), que no le convencieron;
   - las placas de hielo del corte (`IceSlab`);
   - los bloques de hielo de la Ola (`IceBlocks`), que serían mejores como cristales;
   - los picos de hielo del borde del Eclipse (`IceCrown`) y sus cristales (`IceCrystals`): hoy son un bloque con una punta de cubo; un cristal de verdad, alto y facetado, se vería mucho mejor.

   Haz las MeshParts y conéctalas con `MoonfangVFX.Meshes` (ver arriba).
6. Mantener este documento al día con lo que aprendas en Studio. Sobre todo las diferencias entre el simulador y Roblox, para que el siguiente no tropiece.

Suerte. El usuario es exigente pero agradecido, y le encanta ver el resultado: muéstraselo seguido.
