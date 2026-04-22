# 📋 Handoff: Dashboard con Multi-Empresa

> **Para el próximo chat / desarrollador que trabaje en el Dashboard.**
> Este documento describe el contexto de **multi-tenancy por empresa** que YA está
> implementado en la app y cómo el Dashboard debe respetarlo.
>
> Lee también `DASHBOARD_CONTEXT.md` (raíz) para los requerimientos funcionales.

---

## 🏢 Contexto: la app ya es multi-empresa

La app sirve a varias empresas independientes que comparten el mismo backend.
Cada usuario puede pertenecer a **una o más empresas** y tiene una empresa
**activa** seleccionable desde el header (selector de empresa).

### Empresas actuales en producción

| Empresa | Rol | Notas |
|---|---|---|
| **JF Innova** | Empresa "matriz" original | Logo default en Visitas/Extintores |
| **Servimaf** | Empresa **administradora** (`es_administradora = true`) | Sus admins ven datos de TODAS las empresas |
| **Aquachile** | Cliente | Logo default en Inspecciones |
| **Hidroser** *(nueva)* | Cliente del tío del owner | Caso de prueba para multi-empresa |
| *(otras a futuro)* | Clientes | Cada una con su logo |

### Tablas clave (ya existentes)

```
empresas (id, nombre, es_administradora, logo_url)
usuario_empresas (usuario_id, empresa_id)        -- N:N
empresa_modulos (empresa_id, modulo_key, habilitado, orden)
empresa_areas (empresa_id, area_id)              -- N:N
areas (id, nombre, empresa_id)                    -- 1:N legacy (sigue siendo fuente)
```

Todas las **actividades** (`actividades_pendientes`, `visitas_tecnicas_pendientes`,
`extintores_pendientes`) se relacionan a un **`area_id`**, y `areas.empresa_id`
indica a qué empresa pertenece esa actividad. **Esa es la columna que usar para
filtrar por empresa.** No agregues `empresa_id` directo a las tablas de actividad
salvo que sea estrictamente necesario.

---

## 🔑 La clase central: `UserSession` (singleton)

`lib/core/services/user_session.dart`

```dart
final session = UserSession();

session.empresaId          // UUID de la empresa activa
session.empresaNombre      // 'Hidroser'
session.empresaLogoUrl     // URL del logo (puede ser null)
session.empresas           // List<EmpresaUsuario> de TODAS las que tiene
session.tieneMultiEmpresa  // true si tiene > 1
session.esAdmin            // rol = 'administrador' o 'admin'
session.esSuperAdmin       // esAdmin && empresa activa es administradora (Servimaf)

session.cambiarEmpresa(id) // dispara invalidación de caché de logos, etc.
```

### Regla de oro para el Dashboard

> **TODO query del Dashboard se filtra por `empresaId` de la sesión activa…
> EXCEPTO cuando `esSuperAdmin == true`, donde el usuario PUEDE ver todas las
> empresas (con un selector adicional "Ver: [Todas | Empresa X | Empresa Y]").**

---

## ✅ Qué SÍ debe hacer el Dashboard

1. **Filtrar por empresa activa por defecto.**
   ```sql
   SELECT ... FROM actividades_pendientes a
   INNER JOIN areas ar ON ar.id = a.area_id
   WHERE ar.empresa_id = ?         -- session.empresaId
   ```

2. **Reaccionar al cambio de empresa.**
   Si el usuario cambia la empresa activa desde el selector, el Dashboard debe
   recargar sus datos. El `UserSession` no es `ChangeNotifier`, así que tienes
   dos opciones:
   - Detectar el cambio en `didChangeDependencies` / al volver al screen.
   - **Recomendado:** envolver `UserSession` en un `ChangeNotifier` o exponer un
     `ValueNotifier<String?> currentEmpresaId` para suscribirse. Si haces esto,
     hazlo de forma **no-breaking** (mantén la API actual del singleton).

3. **Mostrar el nombre de la empresa activa visible en el dashboard.**
   Header tipo: `"Dashboard de Reportes — HIDROSER"`. Útil cuando el usuario
   tiene multi-empresa.

4. **Si el usuario es `esSuperAdmin` (Servimaf):** agregar un dropdown extra
   `"Ver datos de: [Todas las empresas | Hidroser | Aquachile | ...]"` y
   permitir filtrar a nivel de query (`WHERE empresa_id IN (...)`).

5. **Cachear datos por empresa.** Si cacheas KPIs en memoria, la key debe
   incluir `empresaId` (ej: `Map<String, KpiData>`). Al cambiar empresa, sirve
   el caché de la nueva.

6. **Para el logo en exportaciones (PDF de reportes / capturas):** usar
   `EmpresaLogoService.instance.getLogoForActiveEmpresa(fallbackAsset: ...)`.
   Ver `lib/core/services/empresa_logo_service.dart`.

7. **Para el título "JF INNOVA" / "HIDROSER" en PDFs del Dashboard:** seguir el
   patrón de los otros módulos — pasar `empresaProveedor` desde el controller:
   ```dart
   empresaProveedor: (UserSession().empresaNombre ?? 'JF INNOVA').toUpperCase()
   ```

---

## 🚫 Qué NO debe hacer el Dashboard

1. ❌ **NO hacer queries sin filtro de empresa.** Es la falla #1 que va a
   filtrar datos entre empresas. Si una query no filtra, justifícalo en un
   comentario.

2. ❌ **NO asumir que "JF Innova" es la única empresa.** Cualquier string
   hardcodeado `"JF Innova"`, `"jf_innova"`, etc. en lógica de negocio es bug.

3. ❌ **NO cargar el logo con `rootBundle.load('assets/images/LogoJFInnova2.png')`
   directamente** en código nuevo. Usa `EmpresaLogoService`.

4. ❌ **NO mezclar datos de empresas en agregaciones globales** salvo cuando el
   usuario sea `esSuperAdmin` Y haya elegido explícitamente "Todas las
   empresas".

5. ❌ **NO usar `areas.empresa_id` como única fuente de verdad sin considerar
   `empresa_areas`** — ahora una área puede pertenecer a varias empresas (N:N
   desde la migración v41). Para listar áreas de una empresa, usa
   `DatabaseHelper.instance.getAreasByEmpresa(empresaId)` que ya hace el JOIN
   correcto contra `empresa_areas`.

6. ❌ **NO crear tablas nuevas sin columna `empresa_id`** (o relación clara a
   ella). Si agregas una tabla de configuración del Dashboard (favoritos,
   widgets guardados, etc.) **siempre incluye `empresa_id`**.

7. ❌ **NO romper el flujo offline-first.** Las queries del Dashboard deben
   ejecutarse contra **SQLite local**, no contra Supabase directamente. La sync
   ya está montada.

---

## 🧮 Patrón recomendado para queries del Dashboard

```dart
class DashboardRepository {
  Future<List<Map<String, dynamic>>> getInspeccionesPorPeriodo({
    required DateTime desde,
    required DateTime hasta,
    String? empresaIdOverride, // SOLO usar si esSuperAdmin
  }) async {
    final empresaId = empresaIdOverride ?? UserSession().empresaId;
    if (empresaId == null) {
      // Sin empresa = sin datos. Nunca devolver datos sin filtro.
      return [];
    }

    final db = await DatabaseHelper.instance.database;
    return db.rawQuery('''
      SELECT a.*
      FROM actividades_pendientes a
      INNER JOIN areas ar ON ar.id = a.area_id
      INNER JOIN empresa_areas ea ON ea.area_id = ar.id
      WHERE ea.empresa_id = ?
        AND a.fecha_inspeccion BETWEEN ? AND ?
        AND a.estado = 'FINALIZADO'
    ''', [empresaId, desde.toIso8601String(), hasta.toIso8601String()]);
  }
}
```

### Para el modo SuperAdmin "Ver todas"

```dart
final esSuperAdmin = UserSession().esSuperAdmin;
final mostrarTodas = esSuperAdmin && filtroVerTodas;

final whereEmpresa = mostrarTodas
    ? '' // sin filtro
    : 'AND ea.empresa_id = ?';
final args = mostrarTodas ? [...] : [empresaId, ...];
```

---

## 📊 KPIs que necesitan separación por empresa

Lista no exhaustiva, pero para que arranques pensando correctamente:

- Total de inspecciones / visitas / inspecciones de extintores → **por empresa**
- % cumplimiento global → **por empresa** (cada cliente tiene sus propios estándares)
- Top "no cumples" → **por empresa** (los hallazgos de Aquachile no le sirven a Hidroser)
- Reportería de profesionales → **por empresa** (un mismo profesional puede trabajar en varias)
- Comparativas históricas → **por empresa**

### Caso especial: SuperAdmin (Servimaf)
Como Servimaf vende el sistema, su admin puede querer ver:
- KPIs agregados de TODAS las empresas (cuántas inspecciones generó el sistema en total).
- Comparativas ENTRE empresas (Aquachile vs Hidroser en cumplimiento).

Para esto: dropdown `"Ver: [Todas | Empresa X]"` solo visible si `esSuperAdmin`.

---

## 🔌 Integraciones ya existentes que debe respetar el Dashboard

| Cosa | Dónde está | Cómo usar |
|---|---|---|
| Empresa activa | `UserSession()` | `session.empresaId`, `session.empresaNombre` |
| Logo de empresa | `EmpresaLogoService.instance` | `getLogoForActiveEmpresa(fallbackAsset: ...)` |
| Áreas de empresa | `DatabaseHelper.instance` | `getAreasByEmpresa(empresaId)` |
| Módulos habilitados | `DatabaseHelper.instance` | `getModulosByEmpresa(empresaId)` |
| Permisos de admin | `UserSession()` | `esAdmin`, `esSuperAdmin` |

---

## 📁 Estructura sugerida para el feature Dashboard

```
lib/features/dashboard/
├── data/
│   └── repositories/
│       └── dashboard_repository.dart      ← TODAS las queries con filtro empresa
├── domain/
│   └── models/
│       ├── kpi_data.dart
│       └── reporte_widget.dart
├── presentation/
│   ├── controllers/
│   │   └── dashboard_controller.dart      ← escucha cambios de UserSession
│   ├── screens/
│   │   └── dashboard_screen.dart          ← muestra empresa activa en header
│   └── widgets/
│       ├── kpi_card.dart
│       ├── empresa_selector_admin.dart    ← solo visible si esSuperAdmin
│       └── ...
└── services/
    └── dashboard_pdf_service.dart         ← usa EmpresaLogoService + empresaProveedor
```

---

## 🧪 Checklist de testing antes de mergear el Dashboard

- [ ] Login como usuario de **JF Innova** → solo ve datos de JF Innova.
- [ ] Login como usuario de **Hidroser** → solo ve datos de Hidroser.
- [ ] Login como usuario de **Servimaf (admin)** → ve selector "Ver todas / por empresa" y funciona.
- [ ] Cambiar empresa desde el selector → Dashboard recarga datos correctos.
- [ ] Generar PDF del Dashboard → sale con logo + nombre de la empresa activa.
- [ ] Usuario sin empresa asignada → Dashboard muestra estado vacío, no error.
- [ ] Modo offline → Dashboard funciona con datos en SQLite.

---

## 🆘 Si tienes dudas

- **Mecanismo de logos por empresa:** ver `lib/core/services/empresa_logo_service.dart` y
  `supabase_migration_logo_empresa.sql`.
- **Esquema de multi-empresa:** ver `supabase_migration_multi_empresa.sql` y
  `supabase_migration_servimaf.sql`.
- **Cómo se filtra cada módulo existente hoy:** mirar
  `lib/features/admin/services/master_data_batch_service.dart` y
  `lib/features/admin/presentation/screens/empresa_modulos_screen.dart` que ya
  manejan multi-empresa correctamente.

---

**TL;DR:** el Dashboard debe filtrar TODO por `UserSession().empresaId`, mostrar
el nombre de la empresa activa visible, soportar el caso SuperAdmin de
Servimaf, y usar `EmpresaLogoService` + `empresaProveedor` para sus PDFs.
