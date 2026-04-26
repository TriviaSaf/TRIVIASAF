-- ============================================================
-- Migration: alinha saf_solicitacoes com o código Python atual
--
-- Problema: schema original usa nomes antigos que diferem do
--   que a API Flask envia/lê.
--
-- Mudanças:
--   solicitante_id   → notificador_id
--   titulo           → titulo_falha
--   descricao_falha  → descricao_longa
--   url_foto         → mantido (alias, não usado no código novo)
--   + adiciona: local_instalacao (text), equipamento (text),
--               data_inicio_avaria (date), hora_inicio_avaria (time),
--               ticket_saf (bigint auto-gerado via sequence)
--
-- Execute no SQL Editor do Supabase.
-- É seguro executar mais de uma vez (todos os blocos são idempotentes).
-- ============================================================

-- ─── 1. solicitante_id → notificador_id ──────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'saf_solicitacoes'
      AND column_name = 'solicitante_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'saf_solicitacoes'
      AND column_name = 'notificador_id'
  ) THEN
    ALTER TABLE public.saf_solicitacoes
      RENAME COLUMN solicitante_id TO notificador_id;
  END IF;
END $$;

-- Garante a coluna caso ainda não exista de nenhuma forma
ALTER TABLE public.saf_solicitacoes
  ADD COLUMN IF NOT EXISTS notificador_id uuid
    REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL;

-- ─── 2. titulo → titulo_falha ────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'saf_solicitacoes'
      AND column_name = 'titulo'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'saf_solicitacoes'
      AND column_name = 'titulo_falha'
  ) THEN
    ALTER TABLE public.saf_solicitacoes
      RENAME COLUMN titulo TO titulo_falha;
  END IF;
END $$;

ALTER TABLE public.saf_solicitacoes
  ADD COLUMN IF NOT EXISTS titulo_falha text;

-- Remove NOT NULL herdado do schema original (código gera sempre um valor)
ALTER TABLE public.saf_solicitacoes
  ALTER COLUMN titulo_falha DROP NOT NULL;

-- ─── 3. descricao_falha → descricao_longa ────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'saf_solicitacoes'
      AND column_name = 'descricao_falha'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'saf_solicitacoes'
      AND column_name = 'descricao_longa'
  ) THEN
    ALTER TABLE public.saf_solicitacoes
      RENAME COLUMN descricao_falha TO descricao_longa;
  END IF;
END $$;

ALTER TABLE public.saf_solicitacoes
  ADD COLUMN IF NOT EXISTS descricao_longa text;

-- descricao_longa é opcional quando sintoma_id for preenchido
ALTER TABLE public.saf_solicitacoes
  ALTER COLUMN descricao_longa DROP NOT NULL;

-- ─── 4. Colunas novas ────────────────────────────────────────
ALTER TABLE public.saf_solicitacoes
  ADD COLUMN IF NOT EXISTS local_instalacao    text,
  ADD COLUMN IF NOT EXISTS equipamento         text,
  ADD COLUMN IF NOT EXISTS data_inicio_avaria  date,
  ADD COLUMN IF NOT EXISTS hora_inicio_avaria  time;

-- ─── 5. ticket_saf — número sequencial legível ───────────────
CREATE SEQUENCE IF NOT EXISTS public.saf_ticket_seq START 1000;

ALTER TABLE public.saf_solicitacoes
  ADD COLUMN IF NOT EXISTS ticket_saf bigint DEFAULT nextval('public.saf_ticket_seq');

-- Preenche ticket_saf nas linhas já existentes que ficaram NULL
UPDATE public.saf_solicitacoes
   SET ticket_saf = nextval('public.saf_ticket_seq')
 WHERE ticket_saf IS NULL;

-- ─── 6. Índice de performance para fila CCM ──────────────────
CREATE INDEX IF NOT EXISTS idx_saf_sol_notificador
  ON public.saf_solicitacoes(notificador_id);

CREATE INDEX IF NOT EXISTS idx_saf_sol_criado_em
  ON public.saf_solicitacoes(criado_em DESC);
