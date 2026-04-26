-- ============================================================
-- Migration: GPS em locais + grupo_catalogo em equipamentos
-- ============================================================
-- Execute no SQL Editor do Supabase após sap_integracao_v2.sql
-- ============================================================

-- 1. Geolocalização nos locais de instalação (para busca por proximidade GPS)
ALTER TABLE public.locais_instalacao
  ADD COLUMN IF NOT EXISTS lat  float8,
  ADD COLUMN IF NOT EXISTS lng  float8;

-- 2. Grupo de catálogo do equipamento (arborização SAP → filtro de sintomas)
--    Exemplos de valores: 'EL' (Elétrico), 'ME' (Mecânico),
--                         'HI' (Hidráulico), 'IN' (Instrumentação)
--    Corresponde ao campo RBNR (Catalog Profile) do SAP PM.
ALTER TABLE public.equipamentos
  ADD COLUMN IF NOT EXISTS grupo_catalogo text;

-- 3. Garantir colunas necessárias em sintomas_catalogo
--    (já podem existir se seed foi rodado; IF NOT EXISTS é seguro)
ALTER TABLE public.sintomas_catalogo
  ADD COLUMN IF NOT EXISTS grupo        text,
  ADD COLUMN IF NOT EXISTS codigo_item  text;

-- Coluna ativo em sintomas_catalogo (pode não existir no banco legado)
ALTER TABLE public.sintomas_catalogo
  ADD COLUMN IF NOT EXISTS ativo boolean NOT NULL DEFAULT true;

-- 4. Extensão pg_trgm (deve vir ANTES dos índices que a usam)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_equipamentos_grupo_catalogo
  ON public.equipamentos(grupo_catalogo)
  WHERE grupo_catalogo IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sintomas_catalogo_grupo
  ON public.sintomas_catalogo(grupo)
  WHERE grupo IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_equipamentos_descricao_trgm
  ON public.equipamentos USING gin(descricao gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_locais_descricao_trgm
  ON public.locais_instalacao USING gin(descricao gin_trgm_ops);

-- 5. Correção segura dos tipos das FK de saf_solicitacoes:
--    No banco legado, locais/equipamentos usam id_sap (text) como PK.
--    Precisamos que local_instalacao_id e equipamento_id aceitem texto.
DO $$
BEGIN
  -- Drop FK constraints se existirem (podem não existir no banco legado)
  BEGIN
    ALTER TABLE public.saf_solicitacoes
      DROP CONSTRAINT IF EXISTS saf_solicitacoes_local_instalacao_id_fkey;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER TABLE public.saf_solicitacoes
      DROP CONSTRAINT IF EXISTS saf_solicitacoes_equipamento_id_fkey;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  -- Converte bigint → text apenas se a coluna for bigint
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'saf_solicitacoes'
      AND column_name  = 'local_instalacao_id'
      AND data_type    = 'bigint'
  ) THEN
    ALTER TABLE public.saf_solicitacoes
      ALTER COLUMN local_instalacao_id TYPE text USING local_instalacao_id::text;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'saf_solicitacoes'
      AND column_name  = 'equipamento_id'
      AND data_type    = 'bigint'
  ) THEN
    ALTER TABLE public.saf_solicitacoes
      ALTER COLUMN equipamento_id TYPE text USING equipamento_id::text;
  END IF;

  -- Garante que as colunas existam caso não tenham sido criadas pela migration anterior
  BEGIN
    ALTER TABLE public.saf_solicitacoes ADD COLUMN IF NOT EXISTS local_instalacao_id text;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    ALTER TABLE public.saf_solicitacoes ADD COLUMN IF NOT EXISTS equipamento_id text;
  EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;
