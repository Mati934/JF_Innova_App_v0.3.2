---
name: nueva-empresa-demo
description: Prepara una empresa nueva (demo o cliente) en JF Innova App y dice qué le falta para que su usuario la vea funcionando: empresa, módulos habilitados (más Historial), usuarios asociados, áreas y centros, y si los módulos pedidos existen en la app publicada. Genera el SQL de alta desde una plantilla (no lo ejecuta sin OK) y un diagnóstico de solo lectura. Usar cuando el usuario diga "nueva empresa", "crear empresa demo", "demo para X", "habilitar módulos a la empresa X", "¿qué le falta a la empresa X?", "no veo la empresa/el módulo", o cuando un cliente nuevo vaya a probar la app.
---

# Nueva empresa demo

## Modelo mental

Un demo es: **empresa nueva + usuario de esa empresa + los módulos que pidió +
Historial**. El usuario solo ve los módulos habilitados para su empresa
(`empresa_modulos`). No se programa nada salvo que el cliente pida algo que la
app no tiene (otro checklist, otro PDF): eso va por `nuevo-checklist` o
`nuevo-modulo`, y se avisa.

Quién hace qué (decisión de Mati, 2026-10-29):

- **Empresas y usuarios los crea Mati en la base** (Supabase). La app no tiene
  pantalla para crear empresas ni usuarios.
- Claude genera el SQL de empresa + módulos, revisa qué falta y lo reporta.

## Paso 1: reunir datos (una sola tanda de preguntas)

- Nombre exacto de la empresa (único en `empresas.nombre`).
- Módulos que pide: claves de `ModuleRegistry`
  (`lib/core/modules/module_registry.dart`) o checklists del motor
  (`docs/checklists/README.md`). Historial (`HISTORY`) va siempre.
- Si trae áreas/centros propios (si no tiene, la app le muestra los de todas las
  empresas: avisarlo).
- RUT y logo: opcionales. Sin logo, revisar qué muestra el PDF del módulo.

## Paso 2: diagnosticar (solo lectura)

Ejecutar `diagnostico_empresa.sql` con el MCP `supabase` reemplazando el nombre.
Además, en el código: cada clave pedida debe existir en `ModuleRegistry` **de la
versión publicada** (si el módulo es nuevo y no está publicado, el usuario no lo
verá aunque esté habilitado).

## Paso 3: generar el alta

Copiar `plantilla_empresa_demo.sql` a la raíz como
`supabase_seed_empresa_<nombre>_v1.sql`, llenar `cfg_empresa` y `cfg_modulos`.
Es reejecutable. No ejecutarlo sin OK explícito: lo corre Mati o, con su OK,
`supabase-write` (si el MCP de escritura falla desde el chat, dejar un guion para
la terminal).

## Paso 4: reportar lo que falta

Entregar siempre esta tabla, con ✅ / ❌ / ⚠️ y la acción concreta:

| Paso | Estado | Qué hacer |
|---|---|---|
| Empresa creada | | SQL del paso 3 |
| Módulos habilitados (+ Historial) | | SQL del paso 3 o Administración → Módulos |
| Módulos existen en la app publicada | | Publicar versión / `nuevo-modulo` |
| Usuario(s) asociados (`usuario_empresas`) | | Mati crea el usuario y lo asocia |
| Usuario con una sola empresa | | Si tiene varias, la app toma la primera por nombre |
| Áreas / centros propios (`empresa_areas`) | | Administración → Datos Maestros, o SQL |
| Checklists del motor: tarjetas y permisos | | `nuevo-checklist` modo C |
| El usuario sincronizó | | Cerrar sesión y volver a entrar |

## Paso 5: cerrar

`documentar-app`: empresa en `docs/glosario.md` (empresas) y
`docs/base-de-datos/maestros.md` (módulos por empresa), CHANGELOG.
