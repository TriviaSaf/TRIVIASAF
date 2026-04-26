-- ============================================================
-- Migration: adiciona status DUPLICADA ao saf_controle_ccm
--
-- Quando o CCM aprova uma SAF, todas as outras SAFs ABERTAS
-- para o mesmo equipamento recebem status DUPLICADA e o
-- número da nota SAP criada (qmnum_duplicata).
-- ============================================================

-- 1. Coluna para armazenar o QMNUM da nota de referência
ALTER TABLE public.saf_controle_ccm
  ADD COLUMN IF NOT EXISTS qmnum_duplicata text;

COMMENT ON COLUMN public.saf_controle_ccm.qmnum_duplicata
  IS 'QMNUM da Nota SAP criada pela SAF original (quando esta foi marcada como duplicata).';

-- 2. Altera CHECK constraint para incluir DUPLICADA
DO $$
BEGIN
  -- Remove constraint existente (nome pode variar)
  ALTER TABLE public.saf_controle_ccm
    DROP CONSTRAINT IF EXISTS saf_controle_ccm_status_check;
  ALTER TABLE public.saf_controle_ccm
    DROP CONSTRAINT IF EXISTS chk_status;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.saf_controle_ccm
  ADD CONSTRAINT saf_controle_ccm_status_check
  CHECK (status IN ('ABERTA', 'EM_ANALISE', 'DEVOLVIDA', 'APROVADA', 'CANCELADA', 'DUPLICADA'));

-- 3. Também ajusta a constraint de motivo_devolucao para não exigir em DUPLICADA
DO $$
BEGIN
  ALTER TABLE public.saf_controle_ccm
    DROP CONSTRAINT IF EXISTS chk_motivo_devolucao;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Corrige linhas legadas DEVOLVIDA sem motivo (evita violação da constraint)
UPDATE public.saf_controle_ccm
   SET motivo_devolucao = 'Motivo não informado'
 WHERE status = 'DEVOLVIDA'
   AND (motivo_devolucao IS NULL OR length(trim(motivo_devolucao)) = 0);

ALTER TABLE public.saf_controle_ccm
  ADD CONSTRAINT chk_motivo_devolucao
  CHECK (
    (status <> 'DEVOLVIDA')
    OR (motivo_devolucao IS NOT NULL AND length(trim(motivo_devolucao)) > 0)
  );
