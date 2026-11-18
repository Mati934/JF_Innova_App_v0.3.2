-- Registro de actividades formativas. Ejecutar en Supabase SQL Editor.
-- La cabecera se guarda en `actividades`. Su correlativo independiente requiere
-- supabase_migration_actividades_formativas_correlativo.sql.

CREATE TABLE IF NOT EXISTS public.actividad_formativa_registros (
  actividad_id UUID PRIMARY KEY
    REFERENCES public.actividades(id) ON DELETE CASCADE,
  empresa_id UUID NOT NULL REFERENCES public.empresas(id),
  area_id UUID REFERENCES public.areas(id),
  area_nombre TEXT,
  area_otro TEXT,
  centro_nombre TEXT,
  tipo_actividad TEXT NOT NULL,
  tipo_otro TEXT,
  descripcion TEXT,
  hora_inicio TEXT NOT NULL,
  hora_termino TEXT NOT NULL,
  asistentes INTEGER NOT NULL DEFAULT 0 CHECK (asistentes >= 0),
  duracion_real_minutos INTEGER,
  duracion_contabilizada_minutos INTEGER,
  hh_sin_relator NUMERIC(12, 2),
  hh_con_relator NUMERIC(12, 2),
  relator_nombre TEXT NOT NULL DEFAULT '',
  firma_relator_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_actividad_formativa_empresa
  ON public.actividad_formativa_registros (empresa_id, created_at DESC);

ALTER TABLE public.actividad_formativa_registros ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS actividad_formativa_owner_select
  ON public.actividad_formativa_registros;
CREATE POLICY actividad_formativa_owner_select
  ON public.actividad_formativa_registros FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id
        AND a.usuario_id = auth.uid()
        AND a.empresa_id = actividad_formativa_registros.empresa_id
    )
  );

DROP POLICY IF EXISTS actividad_formativa_owner_insert
  ON public.actividad_formativa_registros;
CREATE POLICY actividad_formativa_owner_insert
  ON public.actividad_formativa_registros FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id
        AND a.usuario_id = auth.uid()
        AND a.empresa_id = actividad_formativa_registros.empresa_id
    )
  );

DROP POLICY IF EXISTS actividad_formativa_owner_update
  ON public.actividad_formativa_registros;
CREATE POLICY actividad_formativa_owner_update
  ON public.actividad_formativa_registros FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id
        AND a.usuario_id = auth.uid()
        AND a.empresa_id = actividad_formativa_registros.empresa_id
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id
        AND a.usuario_id = auth.uid()
        AND a.empresa_id = actividad_formativa_registros.empresa_id
    )
  );

DROP POLICY IF EXISTS actividad_formativa_owner_delete
  ON public.actividad_formativa_registros;
CREATE POLICY actividad_formativa_owner_delete
  ON public.actividad_formativa_registros FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.actividades a
      WHERE a.id = actividad_id
        AND a.usuario_id = auth.uid()
        AND a.empresa_id = actividad_formativa_registros.empresa_id
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.actividad_formativa_registros TO authenticated;

INSERT INTO public.empresa_modulos (empresa_id, modulo_key, habilitado, orden)
SELECT e.id, 'ACTIVIDADES_FORMATIVAS', true, 60
FROM public.empresas e
ON CONFLICT (empresa_id, modulo_key) DO NOTHING;
