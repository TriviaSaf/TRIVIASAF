-- Corrige o DEFAULT da coluna status em saf_solicitacoes
-- após a fusão com saf_controle_ccm.
-- O DEFAULT legado era 'Pendente'; a nova constraint exige 'ABERTA'.

ALTER TABLE public.saf_solicitacoes
  ALTER COLUMN status SET DEFAULT 'ABERTA';
