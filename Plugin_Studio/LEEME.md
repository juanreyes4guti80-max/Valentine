# Plugin "Subir texturas VFX"

Sube a Roblox las texturas de los módulos de VFX (KaijuFireVFX, OmnivoraVFX, AstralColossusVFX y MoonfangVFX) y pega sus IDs en el módulo. Las texturas ya vienen dentro del plugin.

1. En Studio: pestaña *Plugins* > *Plugins Folder*. Copia `SubirTexturasVFX.rbxmx` en esa carpeta y reinicia Studio.
2. Inserta los módulos de VFX en tu juego (por ejemplo, en `ReplicatedStorage`).
3. Pestaña *Plugins* > barra **VFX Kaiju** > **Subir texturas**.

**Revisar texturas** dice qué texturas faltan o no cargan. Con una versión nueva de un módulo, vuelve a tocar **Subir texturas**: el plugin recuerda lo que ya subió y solo pega los IDs.

Lo genera `KaijuZero_VFX/tools/gen_plugin.py` (el código está en `KaijuZero_VFX/tools/plugin_studio/`). Se prueba con `KaijuZero_VFX/tools/test_luau/run_plugin_test.py`.
