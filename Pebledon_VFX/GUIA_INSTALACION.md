# VFX de PEBLEDON (kaiju de piedra con venas turquesa): guía

El kit se está haciendo por partes:

- **Skill 1: Rugido sísmico.** Lista.
- **Skill 2: Aliento azul** (como el de Godzilla). Lista.
- **Skill 3: Pilar de cristal.** Lista.
- **Combo: el aliento en el cristal.** Listo: si el aliento le pega al cristal, del cristal salen rayos a los enemigos del área.
- **ULTIMATE:** está por elegirse.

Todo vive en un solo módulo, `PebledonVFX`. Por ahora usa **21 texturas**.

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
| **Skill 2: Aliento azul** | `BlueBreath(boca, objetivo, escala, sacudida, ignorar)` | Como el aliento de Godzilla. **Carga:** la energía se junta en la boca y le salen llamas azules. **Disparo:** escupe **fuego azul concentrado que sale recto**: un núcleo casi blanco, fuego turquesa en vetas que corre muy rápido hacia adelante y llamas azules pegadas al rayo, de la boca a la punta. No lleva aros ni espirales. Es más delgado que los rayos de Kaiju Zero y Omnívora. **Se puede apuntar** los 3 s que dura: se corta en lo primero que toca y llega hasta **126 studs × escala** (3 veces su largo). **Donde pega**, el fuego salpica hacia afuera, saltan rocas con venas y chispas, y el suelo queda con grietas turquesa que arden. Si barre el suelo, deja una estela. | sale a los **0.69 s** (`BlueBreathStart`) y se corta a los **3.55 s** (`BlueBreathStop`) |
| **Skill 3: Pilar de cristal** | `CrystalSpire(pie, dónde, escala, sacudida)` | **Pisotón:** el suelo se raja bajo su pie y una **grieta turquesa corre por el suelo** hasta el punto elegido, con llamitas, chispas y piedras. **Ahí revienta:** destello, fuego cian, rocas y pedazos que vuelan, losas que saltan, polvo y grietas. **Brota duro un pilar de cristal** como los de su espalda: un prisma hexagonal de vidrio turquesa con un núcleo de luz adentro y punta, de unos **33 studs** (un poco más que Pebledon), con cristales más chicos alrededor inclinados hacia afuera. Sale golpeando: el servidor empuja y manda a volar a quien esté encima. **Queda un círculo** en el suelo que marca el área de la mejora, con llamitas y brasas por el borde. El cristal brilla, con fuego cian en la base, y **a los 8 s revienta** en esquirlas. | revienta el suelo a los **0.38 s** (`CrystalSpireTimes.Erupt`) y el cristal revienta a los **8 s** (`CrystalSpireTimes.Shatter`); golpea hasta **12 studs** (`CrystalSpireHitRadius`) y la mejora llega a **70 studs** (`CrystalSpireRadius`: un círculo de 140 studs de lado a lado, para que Pebledon corra adentro), los dos × escala |
| **Combo: el aliento en el cristal** | `CrystalRefract(cristal, enemigos, escala)` | Mientras el **aliento le pega al pilar**, el cristal lo reparte: de su parte alta salen **rayos más delgados** del mismo fuego azul (sin aros), uno hacia **cada enemigo dentro del círculo**, y les pegan mientras el aliento siga en el cristal. Donde pegan, el fuego salpica sobre el enemigo. `refr:SetTargets(lista)` cambia a quiénes y `refr:Stop()` los corta. El aliento del cliente ya se corta en el cristal (el pilar tiene `CanQuery`). | salen al instante (`CrystalRayStart` = 0.1 s para llegar) y duran como mucho **3.4 s** (`CrystalRayStop`) |

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
	elseif que == "Aliento" then
		-- sale de la boca (un Attachment: lo sigue solo) hacia el rival (lo sigue si se mueve);
		-- el último valor es lo que el rayo atraviesa (el modelo de Pebledon)
		local aliento = PebledonVFX.BlueBreath(d.boca, d.objetivo, d.escala, 1, { d.pebledon })
		-- mientras dura, lo puedes apuntar: aliento:AimAt(otraCosa) o aliento:SetDirection(direccion)
	elseif que == "Cristal" then
		-- el pie que pisa (llámalo cuando el pie toca el suelo) y el punto del suelo donde brota
		cristal = PebledonVFX.CrystalSpire(d.pie, d.donde, d.escala, 1)   -- guárdalo para el combo
	elseif que == "Refraccion" then
		-- el aliento está tocando el cristal: un rayo del cristal a cada enemigo de la lista
		if refraccion and refraccion.Active then
			refraccion:SetTargets(d.enemigos)
		elseif cristal and cristal.Parent then
			refraccion = PebledonVFX.CrystalRefract(cristal, d.enemigos, d.escala)
		end
	elseif que == "RefraccionFin" then
		if refraccion then
			refraccion:Stop()
			refraccion = nil
		end
	end
end)
```

(Arriba del `Connect`, declara `local cristal, refraccion = nil, nil`.)

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

### El aliento: el daño mientras pega (servidor)

El rayo se corta en lo primero que toca. En el servidor puedes hacer lo mismo con un Raycast cada pocos instantes, desde la boca hacia donde apunta, hasta `126 × escala` studs. Así le haces daño a lo que esté tocando:

```lua
local function aliento(pebledon: Model, escala: number, objetivo: Model)
	local boca = pebledon.Head.Boca :: Attachment
	evento:FireAllClients("Aliento", { boca = boca, objetivo = objetivo, escala = escala, pebledon = pebledon })
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { pebledon }
	task.wait(PebledonVFX.BlueBreathStart)             -- llega a su largo
	local fin = os.clock() + (PebledonVFX.BlueBreathStop - PebledonVFX.BlueBreathStart)
	while os.clock() < fin do
		local dir = (objetivo:GetPivot().Position - boca.WorldPosition).Unit
		local hit = workspace:Raycast(boca.WorldPosition, dir * 126 * escala, params)
		local modelo = hit and hit.Instance:FindFirstAncestorOfClass("Model")
		if modelo and modelo:FindFirstChildOfClass("Humanoid") then
			hacerDanio(modelo, 4)                        -- daño por tic (tus valores)
		end
		task.wait(0.2)
	end
end
```

Si cambias a dónde apunta (por ejemplo, para que siga la cámara del jugador), haz lo mismo en el servidor y en el cliente (`aliento:SetDirection(dir)`).

### El pilar de cristal: el golpe y la mejora (servidor)

```lua
local function pilar(pebledon: Model, escala: number, donde: Vector3, rivales: { Model })
	local pie = pebledon.RightFoot.Position                  -- el pie que pisa
	evento:FireAllClients("Cristal", { pie = pie, donde = donde, escala = escala })
	local T = PebledonVFX.CrystalSpireTimes
	-- el golpe al brotar: empuja y manda a volar a los que estén encima
	task.delay(T.Erupt, function()
		for _, rival in rivales do
			local raiz = rival:FindFirstChild("HumanoidRootPart") :: BasePart?
			if raiz and (raiz.Position - donde).Magnitude <= PebledonVFX.CrystalSpireHitRadius * escala then
				hacerDanio(rival, 15)                            -- tus valores
				local afuera = (raiz.Position - donde) * Vector3.new(1, 0, 1)
				afuera = if afuera.Magnitude > 0.1 then afuera.Unit else Vector3.zero
				empujar(raiz, afuera, 35)                        -- (la función del rugido) más un salto:
				raiz.AssemblyLinearVelocity += Vector3.new(0, 70, 0)
			end
		end
	end)
	-- la mejora: mientras el cristal está, si Pebledon está cerca gira y corre más rápido
	local humanoide = pebledon:FindFirstChildOfClass("Humanoid") :: Humanoid
	local base = humanoide.WalkSpeed
	local fin = os.clock() + T.Shatter
	task.spawn(function()
		while os.clock() < fin do
			local cerca = (pebledon:GetPivot().Position - donde).Magnitude <= PebledonVFX.CrystalSpireRadius * escala
			humanoide.WalkSpeed = if cerca then base * 1.25 else base   -- y el giro, en tu sistema de movimiento
			task.wait(0.1)
		end
		humanoide.WalkSpeed = base
	end)
end
```

### El combo: el aliento en el cristal (servidor)

El servidor no ve el cristal de los clientes, así que revisa con cuentas si el aliento lo está tocando. El pilar es un cilindro de unos 4.75 studs de radio y 33 de alto (× escala) en el punto donde brotó. Mientras lo toca, reparte el daño entre los enemigos que están dentro del círculo y avisa a los clientes:

```lua
-- ¿el rayo (de origen, con dirección dir unitaria y largo L) toca el pilar parado en centro?
local function tocaCristal(origen: Vector3, dir: Vector3, L: number, centro: Vector3, escala: number): boolean
	local r, alto = 4.75 * escala, 33 * escala
	local o = Vector2.new(origen.X - centro.X, origen.Z - centro.Z)
	local d = Vector2.new(dir.X, dir.Z)
	local a, b, c = d:Dot(d), 2 * o:Dot(d), o:Dot(o) - r * r
	local disc = b * b - 4 * a * c
	if a < 1e-6 or disc < 0 then
		return false
	end
	local t = (-b - math.sqrt(disc)) / (2 * a)
	local y = origen.Y + dir.Y * t - centro.Y
	return t >= 0 and t <= L and y >= 0 and y <= alto
end

-- en el bucle del aliento (ver arriba), cada 0.2 s:
local dentro = {}
if tocaCristal(boca.WorldPosition, dir, 126 * escala, centroDelCristal, escala) then
	for _, rival in rivales do
		local raiz = rival:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz and (raiz.Position - centroDelCristal).Magnitude <= PebledonVFX.CrystalSpireRadius * escala then
			table.insert(dentro, rival)
		end
	end
	for _, rival in dentro do
		hacerDanio(rival, 8 / #dentro)     -- el daño del tic se reparte entre todos (tus valores)
	end
end
-- avisa a los clientes solo cuando la lista cambia (ultimaLista = "" antes del bucle)
local nombres = {}
for _, rival in dentro do
	table.insert(nombres, rival:GetFullName())
end
table.sort(nombres)
local lista = table.concat(nombres, ",")
if lista ~= ultimaLista then
	ultimaLista = lista
	if #dentro > 0 then
		evento:FireAllClients("Refraccion", { enemigos = dentro, escala = escala })
	else
		evento:FireAllClients("RefraccionFin")
	end
end
```

Cuando el aliento se corta, manda también `"RefraccionFin"`.

**Escala.** Tamaño 1 está pensado para un Pebledon de unos **25 studs de alto**, con la boca a unos 21 studs del suelo. Si el tuyo mide 75 studs, usa escala 3. El largo del triángulo también se escala solo; si le pasas otro largo, usa el mismo en `SeismicRoarFrontTime`.

## Para que se vea como en el video

- El video es de mi simulador, con Bloom. Pebledon es una figura de cajas de prueba.
- Las losas y las rocas que arrastra la onda miran con un Raycast **el color y el material del suelo** donde salen. En el video son grises porque el suelo de prueba es oscuro.
- Las grietas, los anillos y las marcas del suelo son Decals pensados para suelo plano.
- **Aliento:** el rayo son **Beams** (el núcleo y dos capas de fuego en vetas que corren hacia adelante) más llamas que van **pegadas al rayo** (`LockedToPart`): si lo barres, el fuego se queda recto con él. Se corta en lo primero que toca con un Raycast cada cuadro.
- **Pilar de cristal:** el cristal es un **marcador** hecho con Parts. El pilar es un prisma hexagonal de tres bloques de `Glass` girados 60°, con punta y un núcleo de `Neon` adentro. Los chicos son de `Glass` y `Neon`. El pilar se llama `PebledonCrystal` y tiene `CanQuery` activado (sin colisión), así que el aliento se corta en él. El círculo es un Decal (`pb_buff_ring`) del radio de la mejora. Los pedazos que vuelan rebotan en el suelo y se deshacen.
- Para que el fuego cian brille como en el video, pon un `BloomEffect` en `Lighting`: *Intensity* 0.6–1, *Size* 24, *Threshold* 1.5–2.

## Rendimiento

| Skill | Partículas en el pico | Otras piezas |
|---|---|---|
| Rugido sísmico | unas 1200 | unas 58 losas y 68 rocas (Parts ancladas, sin colisión) y 70 Decals de grietas; todo se limpia solo a los 5.5 s |
| Aliento azul | unas 220 | 4 Beams y Decals en el suelo (más si lo barre) |
| Pilar de cristal | unas 400 | 20 cristales (60 Parts con sus puntas), 36 losas, 100 pedazos, unas 42 Decals y 3 PointLights; se limpia solo a los 10.8 s |
| Combo (por rayo) | unas 60 | 4 Beams y una PointLight |

`PebledonVFX.Quality = 0.6` baja las partículas, las losas y las rocas (por ejemplo, en celulares).

## Modelos de Blender (opcional)

Las piezas sólidas se pueden cambiar por modelos hechos en Blender (una **MeshPart** cada una). Ponlos en `PebledonVFX.Meshes` con el nombre de la pieza y el módulo los usa en vez de los bloques:

```lua
local PebledonVFX = require(ReplicatedStorage.PebledonVFX)
local modelos = ReplicatedStorage.PebledonMeshes        -- una carpeta con tus MeshParts
PebledonVFX.Meshes.RoarSlab = modelos.Slab              -- las losas que levanta el rugido
PebledonVFX.Meshes.PlowRocks = modelos.Rock             -- las rocas que arrastra la onda
PebledonVFX.Meshes.PlowBoulders = modelos.Boulder       -- las rocas grandes
PebledonVFX.Meshes.PebledonCrystal = modelos.Crystal    -- el pilar de cristal de la skill 3 (el grande)
PebledonVFX.Meshes.CrystalShards = modelos.CrystalSmall -- los cristales chicos de alrededor
```

El pilar (`PebledonCrystal`) es **lo más importante para hacer en Blender**: un cristal hexagonal alto con punta, como las placas de su espalda, de proporción 1 × 3.2 × 1 (ancho, alto, fondo). Con un modelo se escala al tamaño del pilar (unos 9.5 × 30 × 9.5 studs a escala 1) y ya no lleva los tres bloques ni el núcleo de Neon. Ponle tú el brillo, por ejemplo con un material de vidrio y una parte de Neon adentro.

- El modelo se clona y se escala al tamaño de cada pieza, y conserva su material, su color y su textura.
- Con un modelo, la pieza ya no toma el color del suelo.

## Las texturas

Están en `textures/`. El plugin las sube todas.

**Propias de Pebledon (`pb_`):**

| Textura | Qué es | Dónde se usa |
|---|---|---|
| `pb_rock_2x2` | cuatro rocas facetadas con venas turquesa que brillan (ya coloreada) | Rugido |
| `pb_sonic_ring` | onda de sonido: un anillo nítido con ondas detrás | Rugido |
| `pb_vein_cracks` | grietas que salen del centro y se ramifican | Rugido, Aliento |
| `pb_breath_fire` | fuego concentrado en vetas que corre a lo largo (Beams del aliento) | Aliento |
| `pb_buff_ring` | el círculo de la mejora: un anillo nítido con marcas de cristal | Pilar de cristal |

**Del proyecto (de los otros kits):** `kz_beam_ring` (anillo nítido), `kz_beam_core` y `kz_beam_glow` (el núcleo y la luz del aliento), `mf_shard_2x2` (esquirlas de cristal) y `om_cubes_2x2` (pedazos de tierra).

**Kenney (CC0):** `kk_circle_02` (anillo del suelo), `kk_smoke_04` (polvo), `kk_star_09` (destello) y `kk_trace_01` (líneas de grito).

**Effekseer (CC0):** `fx_fire_2x2` (fuego), `fx_aura_tongue_2x2` (lenguas de fuego), `fx_glow` (resplandor), `fx_smoke_2x2` (humo), `fx_fog2001` (polvo bajo), `fx_spark002` (brasas) y `fx_particle02` (partículas de luz).

### Licencias

- `kk_*` son de Kenney (CC0) y `fx_*` son de las muestras de Effekseer (CC0). Ver los archivos de licencia en `textures/`.
- `pb_*`, `kz_*`, `mf_*` y `om_*` se generaron para este proyecto: son tuyas.

## Los videos

En `preview/`:

1. `1_Skill1_RugidoSismico`
2. `2_Skill2_AlientoAzul`
3. `3_Skill3_PilarDeCristal`
4. `4_Combo_AlientoEnElCristal`

## Si quieres cambiar algo

Todo el kit está en `KaijuZero_VFX/tools/vfx_pebledon.py`:

- arriba están los colores;
- después cada skill, con sus tiempos y sus capas. Del rugido: `RL` y `RA` (largo y apertura), `T_ROAR`, `T0R`, `TWR` y `EASE_R` (cuándo ruge, cuándo sale la onda, cuánto tarda y cuánto se frena), `ROAR_FRONT` (lo que viaja con el frente) y `ROAR_FIELD` (las losas). Del aliento: `B_START`, `B_STOP` y `B_LEN` (cuándo sale, cuándo se corta y su largo máximo), `BREATH_BEAMS` (el núcleo y el fuego) y `B_JET` (lo que tarda una llama en ir de la boca a la punta). Del pilar: `SR` (el radio de la mejora), `S_ERUPT`, `S_RISE` y `S_END` (cuándo revienta el suelo, cuándo brota y cuándo se rompe), `S_HIT_R` (el radio del golpe) y `SPIRE_FIELD` (los cristales y las losas).

Sus texturas propias salen de `KaijuZero_VFX/tools/gen_pebledon_textures.py`.

Para regenerar, desde `KaijuZero_VFX/tools`:

1. `python gen_luau.py ../roblox` escribe los módulos de todos los kaijus.
2. Si cambiaste texturas, `python gen_plugin.py` actualiza el plugin.

La prueba `KaijuZero_VFX/tools/test_luau/run_runtime.py` ejecuta el kit contra un Roblox simulado. Comprueba:

- que el rugido salga de la boca;
- que el polvo, las grietas y el fuego vayan al suelo y cubran todo el triángulo;
- que salten las losas y las rocas;
- que exporte los tiempos, el largo y la apertura;
- que el aliento llegue a su largo máximo, se corte en el suelo, deje estela al barrer, siga a un objetivo que se mueve y se limpie si lo cortas antes;
- que la grieta del pilar corra del pie al cristal, que el pilar sea un prisma de tres bloques llamado `PebledonCrystal`, que brote el fuego de la base y que exporte los tiempos y los dos radios;
- que el combo saque un rayo por enemigo desde lo alto del cristal, que `SetTargets` corte los que sobran y que `Stop` limpie todo;
- que no quede nada vivo al terminar.
