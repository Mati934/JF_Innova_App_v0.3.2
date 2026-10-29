-- =============================================================================
-- AST EVIDENCIAS V1
-- Check de solo lectura + migracion + pruebas posteriores.
--
-- IMPORTANTE: las consultas de la seccion 1 pueden ejecutarse solas para
-- verificar el estado antes de aplicar el resto del archivo.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. CHECK PREVIO (SOLO LECTURA)
-- -----------------------------------------------------------------------------
SELECT
  to_regclass('public.ast_evidencias') AS tabla_ast_evidencias,
  EXISTS (
    SELECT 1
    FROM storage.buckets
    WHERE id = 'evidencias'
  ) AS bucket_evidencias_existe;

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'ast_evidencias'
ORDER BY ordinal_position;

-- Interpretacion:
-- * tabla_ast_evidencias = NULL: la migracion aun NO fue aplicada.
-- * tabla_ast_evidencias = ast_evidencias y aparecen sus columnas: ya existe.
-- * bucket_evidencias_existe = false: la migracion creara el bucket requerido.

-- -----------------------------------------------------------------------------
-- 2. MIGRACION IDEMPOTENTE
-- -----------------------------------------------------------------------------
BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES ('evidencias', 'evidencias', true)
ON CONFLICT (id) DO UPDATE SET public = true;

CREATE TABLE IF NOT EXISTS public.ast_evidencias (
  storage_path TEXT PRIMARY KEY,
  informe_id UUID NOT NULL
    REFERENCES public.ast_informes(id) ON DELETE CASCADE,
  hallazgo_id UUID
    REFERENCES public.ast_hallazgos(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN ('general', 'hallazgo')),
  posicion INTEGER NOT NULL DEFAULT 0 CHECK (posicion >= 0),
  foto_url TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ast_evidencias_tipo_hallazgo_check CHECK (
    (tipo = 'general' AND hallazgo_id IS NULL)
    OR (tipo = 'hallazgo' AND hallazgo_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_ast_evidencias_informe
  ON public.ast_evidencias(informe_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ast_evidencias_general_posicion
  ON public.ast_evidencias(informe_id, posicion)
  WHERE tipo = 'general';

CREATE UNIQUE INDEX IF NOT EXISTS uq_ast_evidencias_hallazgo
  ON public.ast_evidencias(hallazgo_id)
  WHERE tipo = 'hallazgo';

ALTER TABLE public.ast_evidencias ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.ast_evidencias TO authenticated;
GRANT ALL ON public.ast_evidencias TO service_role;

DROP POLICY IF EXISTS ast_evidencias_owner_select ON public.ast_evidencias;
CREATE POLICY ast_evidencias_owner_select
  ON public.ast_evidencias FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.ast_informes i
      WHERE i.id = informe_id AND i.usuario_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ast_evidencias_owner_insert ON public.ast_evidencias;
CREATE POLICY ast_evidencias_owner_insert
  ON public.ast_evidencias FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.ast_informes i
      WHERE i.id = informe_id AND i.usuario_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ast_evidencias_owner_update ON public.ast_evidencias;
CREATE POLICY ast_evidencias_owner_update
  ON public.ast_evidencias FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.ast_informes i
      WHERE i.id = informe_id AND i.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.ast_informes i
      WHERE i.id = informe_id AND i.usuario_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ast_evidencias_owner_delete ON public.ast_evidencias;
CREATE POLICY ast_evidencias_owner_delete
  ON public.ast_evidencias FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.ast_informes i
      WHERE i.id = informe_id AND i.usuario_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ast_storage_owner_select ON storage.objects;
CREATE POLICY ast_storage_owner_select
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'evidencias'
    AND (storage.foldername(name))[1] = 'ast'
    AND EXISTS (
      SELECT 1
      FROM public.ast_informes i
      WHERE i.id::text = (storage.foldername(name))[2]
        AND i.usuario_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ast_storage_owner_insert ON storage.objects;
CREATE POLICY ast_storage_owner_insert
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'evidencias'
    AND (storage.foldername(name))[1] = 'ast'
    AND EXISTS (
      SELECT 1
      FROM public.ast_informes i
      WHERE i.id::text = (storage.foldername(name))[2]
        AND i.usuario_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ast_storage_owner_update ON storage.objects;
CREATE POLICY ast_storage_owner_update
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'evidencias'
    AND (storage.foldername(name))[1] = 'ast'
    AND EXISTS (
      SELECT 1
      FROM public.ast_informes i
      WHERE i.id::text = (storage.foldername(name))[2]
        AND i.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'evidencias'
    AND (storage.foldername(name))[1] = 'ast'
    AND EXISTS (
      SELECT 1
      FROM public.ast_informes i
      WHERE i.id::text = (storage.foldername(name))[2]
        AND i.usuario_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ast_storage_owner_delete ON storage.objects;
CREATE POLICY ast_storage_owner_delete
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'evidencias'
    AND (storage.foldername(name))[1] = 'ast'
    AND EXISTS (
      SELECT 1
      FROM public.ast_informes i
      WHERE i.id::text = (storage.foldername(name))[2]
        AND i.usuario_id = auth.uid()
    )
  );

COMMIT;

-- -----------------------------------------------------------------------------
-- 3. PRUEBAS POSTERIORES (SOLO LECTURA)
-- -----------------------------------------------------------------------------
SELECT
  c.relname AS tabla,
  c.relrowsecurity AS rls_habilitado
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'ast_evidencias';

SELECT policyname, cmd, roles
FROM pg_policies
WHERE (schemaname = 'public' AND tablename = 'ast_evidencias')
   OR (schemaname = 'storage' AND tablename = 'objects'
       AND policyname LIKE 'ast_storage_owner_%')
ORDER BY schemaname, tablename, policyname;

SELECT id, name, public
FROM storage.buckets
WHERE id = 'evidencias';

SELECT COUNT(*) AS evidencias_ast_guardadas
FROM public.ast_evidencias;

-- Resultado esperado:
-- * ast_evidencias con rls_habilitado = true.
-- * 4 policies ast_evidencias_owner_* y 4 ast_storage_owner_*.
-- * bucket evidencias con public = true.
-- * evidencias_ast_guardadas puede ser 0 hasta sincronizar un AST nuevo.