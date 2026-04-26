-- ============================================================
-- Migration: remove FK de local_instalacao_id e equipamento_id
--            e garante que ambas as colunas sejam text
--
-- Problema: add_geo_grupo_catalogo.sql tentou dropar
--   saf_solicitacoes_local_instalacao_id_fkey  (nome errado)
--   saf_solicitacoes_equipamento_id_fkey        (nome errado)
-- mas as constraints reais são:
--   saf_solicitacoes_local_instalacao_fkey
--   saf_solicitacoes_equipamento_fkey
--
-- Resultado: FK permaneceu e rejeita valores como 'TV11'
--   (id_sap em formato texto) com erro 23503.
--
-- Correção: dropar as constraints pelo nome correto e converter
--   as colunas para text se ainda forem bigint.
-- ============================================================

DO $$
BEGIN

  -- ── local_instalacao_id ─────────────────────────────────────
  -- Tenta dropar por todos os nomes conhecidos
  ALTER TABLE public.saf_solicitacoes
    DROP CONSTRAINT IF EXISTS saf_solicitacoes_local_instalacao_fkey;

  ALTER TABLE public.saf_solicitacoes
    DROP CONSTRAINT IF EXISTS saf_solicitacoes_local_instalacao_id_fkey;

  -- Converte para text caso ainda seja bigint
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'saf_solicitacoes'
      AND column_name  = 'local_instalacao_id'
      AND data_type IN ('bigint', 'integer', 'smallint')
  ) THEN
    ALTER TABLE public.saf_solicitacoes
      ALTER COLUMN local_instalacao_id TYPE text
      USING local_instalacao_id::text;
  END IF;

  -- ── equipamento_id ──────────────────────────────────────────
  ALTER TABLE public.saf_solicitacoes
    DROP CONSTRAINT IF EXISTS saf_solicitacoes_equipamento_fkey;

  ALTER TABLE public.saf_solicitacoes
    DROP CONSTRAINT IF EXISTS saf_solicitacoes_equipamento_id_fkey;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'saf_solicitacoes'
      AND column_name  = 'equipamento_id'
      AND data_type IN ('bigint', 'integer', 'smallint')
  ) THEN
    ALTER TABLE public.saf_solicitacoes
      ALTER COLUMN equipamento_id TYPE text
      USING equipamento_id::text;
  END IF;

  -- ── sintoma_id — mantém FK para sintomas_catalogo mas como text ─
  -- (sintomas_catalogo usa uuid como PK no banco atual)
  -- Não alterar sintoma_id aqui; é gerenciado por add_sintoma_id_saf_solicitacoes.sql

END $$;
