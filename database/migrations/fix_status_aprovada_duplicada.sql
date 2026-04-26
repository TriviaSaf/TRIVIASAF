-- ============================================================
-- Migration: corrige status de saf_controle_ccm para registros
--            que já têm nota SAP criada com sucesso (SUCESSO)
--            mas cujo status ainda está como ABERTA.
--
-- Também marca como DUPLICADA os registros ABERTA cujo
-- qmnum_duplicata já foi preenchido.
-- ============================================================

-- 1. ABERTA + integração SAP com SUCESSO → APROVADA
UPDATE public.saf_controle_ccm c
   SET status = 'APROVADA'
  FROM public.saf_integracao_sap i
 WHERE i.solicitacao_id     = c.solicitacao_id
   AND i.status_integracao  = 'SUCESSO'
   AND i.qmnum              IS NOT NULL
   AND c.status             = 'ABERTA';

-- 2. ABERTA + qmnum_duplicata preenchido → DUPLICADA
UPDATE public.saf_controle_ccm
   SET status = 'DUPLICADA'
 WHERE qmnum_duplicata IS NOT NULL
   AND status = 'ABERTA';
