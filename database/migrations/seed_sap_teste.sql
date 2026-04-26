-- =============================================================================
-- SEED DE DADOS SAP PARA TESTES (substitui a sincronização com o SAP real)
-- Execute no SQL Editor do Supabase enquanto o SAP não está disponível.
-- Estes dados populam as tabelas de cache e permitem testar:
--   ✔ Dropdowns de local / equipamento / sintoma na criação de SAF
--   ✔ Resolução de TPLNR / EQUNR / QMGRP / QMCOD na aprovação CCM
--   ✔ Fluxo completo com SAP_MOCK_MODE=true (sem chamada HTTP real ao SAP)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Locais de Instalação (TPLNR)
-- ─────────────────────────────────────────────────────────────
-- Apaga equipamentos antes (FK fk_local aponta locais_instalacao → equipamentos)
DELETE FROM equipamentos
WHERE local_id_sap IN (
  'BR-SP-UTIL-001',
  'BR-SP-PROD-001',
  'BR-SP-PROD-002',
  'BR-RJ-UTIL-001',
  'BR-RJ-PROD-001'
);

DELETE FROM locais_instalacao
WHERE id_sap IN (
  'BR-SP-UTIL-001',
  'BR-SP-PROD-001',
  'BR-SP-PROD-002',
  'BR-RJ-UTIL-001',
  'BR-RJ-PROD-001'
);

INSERT INTO locais_instalacao (id_sap, codigo, descricao, ativo, sincronizado_em)
VALUES
  ('BR-SP-UTIL-001',  'BR-SP-UTIL-001',  'Subestação SP - Utilidades',         true, now()),
  ('BR-SP-PROD-001',  'BR-SP-PROD-001',  'Linha de Produção SP - Bloco A',     true, now()),
  ('BR-SP-PROD-002',  'BR-SP-PROD-002',  'Linha de Produção SP - Bloco B',     true, now()),
  ('BR-RJ-UTIL-001',  'BR-RJ-UTIL-001',  'Subestação RJ - Utilidades',         true, now()),
  ('BR-RJ-PROD-001',  'BR-RJ-PROD-001',  'Linha de Produção RJ - Bloco 1',     true, now());

-- ─────────────────────────────────────────────────────────────
-- 2. Equipamentos (EQUNR), vinculados aos locais acima
-- ─────────────────────────────────────────────────────────────
DELETE FROM equipamentos
WHERE id_sap IN (
  '10000001','10000002','10000003','10000004','10000005',
  '10000006','10000007','10000008','10000009'
);

INSERT INTO equipamentos (id_sap, codigo, descricao, local_id_sap, local_instalacao_id, grupo_catalogo, ativo, sincronizado_em)
VALUES
  -- grupo_catalogo = grupo SAP do catálogo de danos válido para este tipo de equip.
  ('10000001', '10000001', 'Compressor de Ar CP-01',       'BR-SP-UTIL-001', NULL, 'ME', true, now()),
  ('10000002', '10000002', 'Bomba Hidráulica BH-01',       'BR-SP-UTIL-001', NULL, 'HI', true, now()),
  ('10000003', '10000003', 'Motor Elétrico ME-01',         'BR-SP-PROD-001', NULL, 'EL', true, now()),
  ('10000004', '10000004', 'Esteira Transportadora ET-01', 'BR-SP-PROD-001', NULL, 'ME', true, now()),
  ('10000005', '10000005', 'Robô Soldagem RS-01',          'BR-SP-PROD-002', NULL, 'ME', true, now()),
  ('10000006', '10000006', 'Transformador TR-01',          'BR-RJ-UTIL-001', NULL, 'EL', true, now()),
  ('10000007', '10000007', 'Gerador GE-01',                'BR-RJ-UTIL-001', NULL, 'EL', true, now()),
  ('10000008', '10000008', 'Prensa Hidráulica PH-01',      'BR-RJ-PROD-001', NULL, 'HI', true, now()),
  ('10000009', '10000009', 'Torno CNC TC-01',              'BR-RJ-PROD-001', NULL, 'ME', true, now());

-- ─────────────────────────────────────────────────────────────
-- 3. Catálogo de Sintomas (QMGRP + QMCOD, Catálogo C)
-- ─────────────────────────────────────────────────────────────
-- codigo = '<grupo>-<codigo_item>'  (chave única)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'sintomas_catalogo'
      AND column_name = 'id_sap'
  ) THEN
    EXECUTE $sql$
      DELETE FROM sintomas_catalogo
      WHERE id_sap IN (
        'EL-001','EL-002','EL-003','EL-004',
        'ME-001','ME-002','ME-003','ME-004','ME-005',
        'HI-001','HI-002','HI-003',
        'IN-001','IN-002','IN-003'
      )
    $sql$;

    EXECUTE $sql$
      INSERT INTO sintomas_catalogo (id_sap, codigo, grupo, codigo_item, descricao, tipo_catalogo, ativo, sincronizado_em)
      VALUES
        ('EL-001', 'EL-001', 'EL', '001', 'Falha de isolamento',                'C', true, now()),
        ('EL-002', 'EL-002', 'EL', '002', 'Curto-circuito',                     'C', true, now()),
        ('EL-003', 'EL-003', 'EL', '003', 'Sobrecarga elétrica',                'C', true, now()),
        ('EL-004', 'EL-004', 'EL', '004', 'Falha no painel de controle',        'C', true, now()),
        ('ME-001', 'ME-001', 'ME', '001', 'Vibração excessiva',                 'C', true, now()),
        ('ME-002', 'ME-002', 'ME', '002', 'Ruptura de peça',                    'C', true, now()),
        ('ME-003', 'ME-003', 'ME', '003', 'Desgaste prematuro',                 'C', true, now()),
        ('ME-004', 'ME-004', 'ME', '004', 'Folga mecânica',                     'C', true, now()),
        ('ME-005', 'ME-005', 'ME', '005', 'Quebra de rolamento',                'C', true, now()),
        ('HI-001', 'HI-001', 'HI', '001', 'Vazamento de óleo',                  'C', true, now()),
        ('HI-002', 'HI-002', 'HI', '002', 'Queda de pressão',                   'C', true, now()),
        ('HI-003', 'HI-003', 'HI', '003', 'Falha na válvula de controle',       'C', true, now()),
        ('IN-001', 'IN-001', 'IN', '001', 'Leitura incorreta de sensor',        'C', true, now()),
        ('IN-002', 'IN-002', 'IN', '002', 'Falha em transmissor',               'C', true, now()),
        ('IN-003', 'IN-003', 'IN', '003', 'Atuador não responde',               'C', true, now())
    $sql$;
  ELSE
    EXECUTE $sql$
      DELETE FROM sintomas_catalogo
      WHERE codigo IN (
        'EL-001','EL-002','EL-003','EL-004',
        'ME-001','ME-002','ME-003','ME-004','ME-005',
        'HI-001','HI-002','HI-003',
        'IN-001','IN-002','IN-003'
      )
    $sql$;

    EXECUTE $sql$
      INSERT INTO sintomas_catalogo (codigo, grupo, codigo_item, descricao, tipo_catalogo, ativo, sincronizado_em)
      VALUES
        ('EL-001', 'EL', '001', 'Falha de isolamento',                'C', true, now()),
        ('EL-002', 'EL', '002', 'Curto-circuito',                     'C', true, now()),
        ('EL-003', 'EL', '003', 'Sobrecarga elétrica',                'C', true, now()),
        ('EL-004', 'EL', '004', 'Falha no painel de controle',        'C', true, now()),
        ('ME-001', 'ME', '001', 'Vibração excessiva',                 'C', true, now()),
        ('ME-002', 'ME', '002', 'Ruptura de peça',                    'C', true, now()),
        ('ME-003', 'ME', '003', 'Desgaste prematuro',                 'C', true, now()),
        ('ME-004', 'ME', '004', 'Folga mecânica',                     'C', true, now()),
        ('ME-005', 'ME', '005', 'Quebra de rolamento',                'C', true, now()),
        ('HI-001', 'HI', '001', 'Vazamento de óleo',                  'C', true, now()),
        ('HI-002', 'HI', '002', 'Queda de pressão',                   'C', true, now()),
        ('HI-003', 'HI', '003', 'Falha na válvula de controle',       'C', true, now()),
        ('IN-001', 'IN', '001', 'Leitura incorreta de sensor',        'C', true, now()),
        ('IN-002', 'IN', '002', 'Falha em transmissor',               'C', true, now()),
        ('IN-003', 'IN', '003', 'Atuador não responde',               'C', true, now())
    $sql$;
  END IF;
END $$;
