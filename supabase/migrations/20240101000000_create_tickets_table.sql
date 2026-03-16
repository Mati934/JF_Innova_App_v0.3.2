-- =============================================
-- MIGRACIÓN: Tabla tickets con RLS habilitado
-- =============================================
-- Ejecutar este script en el Editor SQL de Supabase
-- para crear (o reparar) la tabla de tickets con
-- las políticas de seguridad correctas.
-- =============================================

-- 1. Crear la tabla si no existe
CREATE TABLE IF NOT EXISTS public.tickets (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  titulo      TEXT NOT NULL,
  descripcion TEXT,
  estado      TEXT NOT NULL DEFAULT 'Abierto'
                CHECK (estado IN ('Abierto', 'En Progreso', 'Cerrado')),
  prioridad   TEXT NOT NULL DEFAULT 'Media'
                CHECK (prioridad IN ('Baja', 'Media', 'Alta')),
  creado_por  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  nombre_creador TEXT,
  fecha_creacion      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Trigger para actualizar fecha_actualizacion automáticamente
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.fecha_actualizacion = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tickets_set_updated_at ON public.tickets;
CREATE TRIGGER tickets_set_updated_at
  BEFORE UPDATE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 3. Habilitar RLS (Row Level Security)
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;

-- 4. Políticas RLS
--    a) Cualquier usuario autenticado puede LEER todos los tickets
DROP POLICY IF EXISTS "tickets_select_authenticated" ON public.tickets;
CREATE POLICY "tickets_select_authenticated"
  ON public.tickets
  FOR SELECT
  TO authenticated
  USING (true);

--    b) Un usuario autenticado puede CREAR sus propios tickets
DROP POLICY IF EXISTS "tickets_insert_authenticated" ON public.tickets;
CREATE POLICY "tickets_insert_authenticated"
  ON public.tickets
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = creado_por);

--    c) Un usuario solo puede ACTUALIZAR sus propios tickets
DROP POLICY IF EXISTS "tickets_update_own" ON public.tickets;
CREATE POLICY "tickets_update_own"
  ON public.tickets
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = creado_por)
  WITH CHECK (auth.uid() = creado_por);

--    d) Un usuario solo puede BORRAR sus propios tickets
DROP POLICY IF EXISTS "tickets_delete_own" ON public.tickets;
CREATE POLICY "tickets_delete_own"
  ON public.tickets
  FOR DELETE
  TO authenticated
  USING (auth.uid() = creado_por);
