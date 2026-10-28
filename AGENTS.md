# Reglas para cualquier agente que trabaje en este proyecto

Este repositorio tiene los VFX de un juego de kaijus en Roblox. El usuario habla español: escríbele en español sencillo y tutéalo.

Antes de hacer o subir VFX, lee `HERENCIA_VFX_PARA_CLAUDE.md`. Explica:

- cómo se diseñan los efectos;
- cómo se exportan a Roblox;
- qué aprendimos de Roblox.

## Leyes globales

El usuario las fijó para **todos** los kaijus. Cúmplelas aunque el pedido no las mencione.

### 1. Los mordiscos muestran solo los dientes

Cualquier habilidad que muerda usa un mordisco como el de Moonfang, sea M1, pesado, skill o ulti y sea del kaiju que sea.

- **Se ven solo los colmillos:** dos filas, arriba y abajo, se cierran de golpe sobre el rival y quedan **trabadas** un instante, con los caninos cruzados. Después se rompen en pedazos.
- **Nunca** se ve la encía ni una mandíbula o boca completa. El usuario dijo de eso: "eso es Pokémon". Tampoco sirven unos arcos de luz sin dientes: "solo veo la encía".
- **Cómo se arma:**
  - un flipbook de 16 cuadros (4×4) que mira a la cámara, encima del rival: se cierra en los primeros 4 cuadros y se rompe al final;
  - un resplandor suave detrás al trabarse, que no tape los dientes;
  - chispas a los lados y esquirlas;
  - vaho o el elemento del personaje;
  - una herida que queda goteando un momento (en Moonfang, escarcha).
- **Los dientes son del material del personaje** y se tiñen con su paleta. En Moonfang son de cristal de hielo. En Kaiju Zero, por ejemplo, serían colmillos de obsidiana con lava naranja o carmesí. No tiene que ser el mismo mordisco: tiene que ser **como** ese.
- **De dónde copiarlo:**
  - En Roblox, en `Moonfang_VFX/roblox/MoonfangVFX.lua`: `MoonfangVFX.MoonBite` (M1), `MoonfangVFX.MoonBiteFinisher` (el remate, con eco y líneas de embestida) y `MoonfangVFX.MoonFang` (el pesado).
  - La textura es `Moonfang_VFX/textures/mf_chomp_4x4.png`. Es blanca con alfa: el color lo pone la capa, así que sirve para cualquier kaiju.
  - En el generador: la función `chomp()` de `KaijuZero_VFX/tools/vfx_moonfang.py` y `chomp_frame()` de `KaijuZero_VFX/tools/gen_moonfang_textures.py`.
- **Prohibida la textura vieja `kz_bite_4x4`** (las mandíbulas con encía). Todavía la usa el mordisco de Kaiju Zero (`KaijuFireVFX.BiteHit`, spec en `KaijuZero_VFX/tools/vfx_hits.py`): hay que cambiarlo por uno nuevo.

### 2. Nada de auras de delineado

El usuario descartó las auras:

- el Highlight con partículas encima ("un delineado, un filtro extraño y partículas sueltas");
- el aura de contorno por Raycasts que probamos después.

No hagas auras nuevas a menos que él las pida y te diga cómo las quiere.

### 3. Las ULTIMATES son de magnitud enorme

El estándar lo marcan tres ultis:

- la de Omnívora, un agujero negro que se come la tierra;
- la de Kaiju Zero, que se está rehaciendo como un rayo intensísimo y luego una bomba nuclear;
- el Eclipse de Moonfang: zona de 120 studs de radio, luna gigante, columna de luz y una detonación de hielo.

Una ulti tiene que sentirse gigante. Lleva varias fases: carga, golpe, sostén y detonación final. El mundo cambia (se oscurece, tiembla) y aparecen piezas sólidas.
