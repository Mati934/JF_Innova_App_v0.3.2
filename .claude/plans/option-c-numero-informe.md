# Plan: Eliminar "Pendiente" y aplicar Opción C completa

## Problema
- El campo "N° Informe" muestra "Pendiente" en el formulario
- "Pendiente" se puede guardar en SQLite como `numero_reporte`
- El PROV-* sigue existiendo como fallback
- El guard en `_persistirDatos` chequea "Pendiente..." (con dots) pero init pone "Pendiente" (sin dots) — inconsistencia

## Solución: El campo muestra vacío ("") cuando no hay número real

El hint text "Auto" ya existe en el widget del header. Si dejamos el controller vacío, el usuario ve el hint "Auto" — limpio y sin confusión.

### Cambios en `inspection_form_controller.dart`:

1. **Línea 155** — `_init()`: Cambiar `"Pendiente"` → `""` (vacío)
   ```dart
   // Antes:
   numeroInformeController.text = "Pendiente";
   // Después:
   numeroInformeController.text = "";
   ```

2. **Líneas 574-577** — `finalizarInspeccion()`: Simplificar check de número real
   ```dart
   // Antes: chequea "Pendiente...", "Pendiente", "PROV-"
   // Después: solo chequea vacío y PROV-
   final bool tieneNumeroReal =
       textoNumero.isNotEmpty &&
       !textoNumero.startsWith("PROV-");
   ```

3. **Líneas 757** — `_persistirDatos()`: Actualizar guard para que no guarde "" en DB
   ```dart
   // Antes: chequea "Pendiente..."
   // Después: chequea vacío (que es lo que ahora será)
   if ((numeroFinal.isEmpty || numeroFinal == "Pendiente..." || numeroFinal == "Pendiente") &&
   ```

4. **En `_persistirDatos`**: No guardar "Pendiente" ni "" como `numero_reporte` en SQLite — guardar `null`
   ```dart
   'numero_reporte': (numeroFinal != null && numeroFinal.isNotEmpty) ? numeroFinal : null,
   ```

5. **Eliminar generación de PROV-\***: En `finalizarInspeccion()`, quitar las líneas que generan `PROV-${activityId.substring(0,8)}`. Ya no son necesarias con Opción C.

### Cambios en `inspection_form_screen.dart`:

6. **Línea 71** — Timer: Ya verifica `.isEmpty`, no necesita cambio (funciona con "")

### Cambios en `inspection_setup_screen.dart`:

7. Sin cambios — ya muestra hint "Automático al sincronizar" cuando el campo está vacío

### Cambios en `buceo_header_widget.dart`:

8. Sin cambios — ya muestra hint "Auto" cuando el campo está vacío

### Fix del bug de sync (PGRST204):

9. **En `sync_service.dart`**: Asegurar que `pdf_path_local` se remueve antes de enviar a Supabase en `_sincronizarActividades()`. Este es el bug que impide la subida.

### Tests nuevos:

10. Tests unitarios en `sync_and_draft_test.dart`:
    - Test: campo numero_informe inicia vacío (no "Pendiente")
    - Test: `_persistirDatos` no guarda "Pendiente" ni "" en SQLite
    - Test: `pdf_path_local` siempre se remueve antes de upsert
    - Test: sin número real → pdfDiferido = true (no genera PROV-*)
    - Test: con número real → genera PDF normalmente
    - Test: guard en _persistirDatos no sobreescribe número real de DB con vacío
    - Test: flujo offline completo (sin sync → sin PDF → sync posterior → PDF generado)

## Archivos a modificar:
1. `lib/features/inspection/presentation/controllers/inspection_form_controller.dart`
2. `lib/features/sync/services/sync_service.dart`
3. `test/sync_and_draft_test.dart`
