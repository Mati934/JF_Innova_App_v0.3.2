-- Agrega metadatos por extintor para inspecciones R004.
-- Ejecutar en Supabase SQL editor o dentro del flujo de migraciones del proyecto.

ALTER TABLE IF EXISTS public.extintores
  ADD COLUMN IF NOT EXISTS peso_extintor text;

ALTER TABLE IF EXISTS public.extintores
  ADD COLUMN IF NOT EXISTS fecha_ultima_mantencion text;

ALTER TABLE IF EXISTS public.extintores
  ADD COLUMN IF NOT EXISTS fecha_proxima_mantencion text;
