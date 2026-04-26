-- =============================================================
--  Migração: tabela saf_imagens + políticas RLS
--  Execute no SQL Editor do Supabase (ou via psql)
-- =============================================================

-- 1. Tabela ----------------------------------------------------------------
create table if not exists public.saf_imagens (
  id              uuid          primary key default gen_random_uuid(),
  solicitacao_id  uuid          not null
                    references public.saf_solicitacoes(id)
                    on delete cascade
                    on update cascade,
  storage_path    text          not null,          -- caminho no Supabase Storage
  url_publica     text,                            -- URL pública (se bucket público)
  latitude        numeric(10, 7),
  longitude       numeric(10, 7),
  precisao_metros integer,
  mime_type       text,
  tamanho_bytes   bigint,
  criado_por      uuid
                    references public.usuarios(id)
                    on update cascade
                    on delete set null,
  criado_em       timestamptz   not null default now()
);

comment on table  public.saf_imagens                is 'Evidências fotográficas vinculadas a cada SAF, com coordenadas GPS opcionais.';
comment on column public.saf_imagens.storage_path   is 'Caminho relativo dentro do bucket do Supabase Storage.';
comment on column public.saf_imagens.url_publica    is 'URL pública de acesso direto, preenchida após upload bem-sucedido.';
comment on column public.saf_imagens.latitude       is 'Latitude capturada no momento da foto (graus decimais, WGS-84).';
comment on column public.saf_imagens.longitude      is 'Longitude capturada no momento da foto (graus decimais, WGS-84).';
comment on column public.saf_imagens.precisao_metros is 'Precisão horizontal do GPS em metros (± acc).';

-- Índice para consultas por SAF
create index if not exists idx_saf_imagens_solicitacao
  on public.saf_imagens (solicitacao_id);

-- 2. RLS -------------------------------------------------------------------
alter table public.saf_imagens enable row level security;

-- 2.1 ADMIN: acesso total
create policy "admin_all_imagens"
  on public.saf_imagens
  for all
  using (
    exists (
      select 1 from public.usuarios u
      where u.id = auth.uid()
        and u.perfil = 'ADMIN'
        and u.ativo = true
    )
  )
  with check (true);

-- 2.2 CCM: leitura de todas as imagens
create policy "ccm_select_imagens"
  on public.saf_imagens
  for select
  using (
    exists (
      select 1 from public.usuarios u
      where u.id = auth.uid()
        and u.perfil = 'CCM'
        and u.ativo = true
    )
  );

-- 2.3 SOLICITANTE: inserir e ler apenas imagens de suas próprias SAFs
create policy "solicitante_insert_imagens"
  on public.saf_imagens
  for insert
  with check (
    exists (
      select 1
      from public.saf_solicitacoes s
      join public.usuarios u on u.id = auth.uid()
      where s.id    = solicitacao_id
        and s.notificador_id = auth.uid()
        and u.perfil = 'SOLICITANTE'
        and u.ativo  = true
    )
  );

create policy "solicitante_select_imagens"
  on public.saf_imagens
  for select
  using (
    exists (
      select 1
      from public.saf_solicitacoes s
      where s.id              = solicitacao_id
        and s.notificador_id  = auth.uid()
    )
  );
