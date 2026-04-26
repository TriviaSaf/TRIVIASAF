-- ============================================================
-- Migration: Fundir saf_controle_ccm em saf_solicitacoes
--
-- Motivo: as duas tabelas representavam uma única entidade (1:1).
-- O fluxo CCM fica mais simples, com queries diretas na tabela
-- principal sem joins intermediários.
--
-- O que este script faz:
--   1. Adiciona as colunas CCM à saf_solicitacoes
--   2. Migra os dados de saf_controle_ccm → saf_solicitacoes
--   3. Converte valores antigos de status ('Pendente' → 'ABERTA', etc.)
--   4. Substitui a CHECK constraint de status pela lista CCM completa
--   5. Adiciona constraint de motivo de devolução obrigatório
--   6. Remove a tabela saf_controle_ccm
-- ============================================================

-- ── 1. Adiciona colunas CCM ──────────────────────────────────
ALTER TABLE public.saf_solicitacoes
  ADD COLUMN IF NOT EXISTS motivo_devolucao    text,
  ADD COLUMN IF NOT EXISTS motivo_cancelamento text,
  ADD COLUMN IF NOT EXISTS avaliado_por        uuid,
  ADD COLUMN IF NOT EXISTS data_avaliacao      timestamp with time zone,
  ADD COLUMN IF NOT EXISTS atualizado_sap      boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tipo_nota           text NOT NULL DEFAULT 'YP',
  ADD COLUMN IF NOT EXISTS qmnum_duplicata     text;

-- ── 2. Remove a constraint de status ANTES de copiar os dados ──
-- (a constraint legada só aceita 'Pendente','Aprovada','Duplicada';
--  os valores do CCM são maiúsculos: 'ABERTA','APROVADA', etc.)
ALTER TABLE public.saf_solicitacoes
  DROP CONSTRAINT IF EXISTS saf_solicitacoes_status_check;

-- ── 3. Copia dados de saf_controle_ccm ──────────────────────
UPDATE public.saf_solicitacoes s
SET
  status              = c.status,
  motivo_devolucao    = c.motivo_devolucao,
  motivo_cancelamento = c.motivo_cancelamento,
  avaliado_por        = c.avaliado_por,
  data_avaliacao      = c.data_avaliacao,
  atualizado_sap      = c.atualizado_sap,
  tipo_nota           = COALESCE(NULLIF(c.tipo_nota, 'M2'), 'YP'),
  qmnum_duplicata     = c.qmnum_duplicata
FROM public.saf_controle_ccm c
WHERE c.solicitacao_id = s.id;

-- ── 4. Converte registros sem linha em saf_controle_ccm ──────
-- (SAFs criadas antes da trigger / em ambiente de dev sem CCM insert)
UPDATE public.saf_solicitacoes
SET status = CASE status
  WHEN 'Pendente'   THEN 'ABERTA'
  WHEN 'Aprovada'   THEN 'APROVADA'
  WHEN 'Duplicada'  THEN 'DUPLICADA'
  WHEN 'Cancelada'  THEN 'CANCELADA'
  ELSE 'ABERTA'
END
WHERE status NOT IN (
  'ABERTA', 'EM_ANALISE', 'DEVOLVIDA', 'APROVADA', 'CANCELADA', 'DUPLICADA'
);

-- ── 5. Adiciona nova CHECK constraint de status ──────────────
ALTER TABLE public.saf_solicitacoes
  ADD CONSTRAINT saf_solicitacoes_status_check CHECK (
    status = ANY (ARRAY[
      'ABERTA'::text,
      'EM_ANALISE'::text,
      'DEVOLVIDA'::text,
      'APROVADA'::text,
      'CANCELADA'::text,
      'DUPLICADA'::text
    ])
  );

-- ── 6. Constraint: motivo_devolucao obrigatório ──────────────
ALTER TABLE public.saf_solicitacoes
  DROP CONSTRAINT IF EXISTS chk_motivo_devolucao;

ALTER TABLE public.saf_solicitacoes
  ADD CONSTRAINT chk_motivo_devolucao CHECK (
    status <> 'DEVOLVIDA'
    OR (
      motivo_devolucao IS NOT NULL
      AND length(trim(both from motivo_devolucao)) > 0
    )
  );

-- ── 7. Remove tabela legada ──────────────────────────────────
DROP TABLE IF EXISTS public.saf_controle_ccm;
