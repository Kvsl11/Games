/* =====================================================================
   OPERAÇÕES AGR - DESCOBERTA  (somente SELECT)
   Objetivo: achar as tabelas de PLANEJAMENTO, PROGRAMAÇÃO e REALIZADO
   (apontamento) das operações agrícolas, para fechar a view
   pimsview_acompanhamento_operacoes.sql.
   Me devolva o resultado das consultas A, B e C (D e E só se A/B acharem).
   ===================================================================== */

-- A) Tabelas (qualquer owner) que têm código de operação + local (fazenda)
SELECT c.owner, c.table_name,
       LISTAGG(c.column_name, ', ') WITHIN GROUP (ORDER BY c.column_id) AS colunas_chave
  FROM all_tab_columns c
 WHERE c.column_name IN ('CD_OPERACAO','CD_OPERAC','CD_OPER',
                         'CD_UPNIVEL1','CD_UPNIVEL2','CD_UPNIVEL3',
                         'CD_SAFRA','QT_AREA','QT_AREA_PROG','QT_AREA_PLAN','QT_AREA_APON',
                         'DT_OPERACAO','DT_PROGRAMACAO','DT_APONTAMENTO','DT_PLANEJ')
 GROUP BY c.owner, c.table_name
HAVING SUM(CASE WHEN c.column_name IN ('CD_OPERACAO','CD_OPERAC','CD_OPER') THEN 1 ELSE 0 END) > 0
   AND SUM(CASE WHEN c.column_name = 'CD_UPNIVEL1' THEN 1 ELSE 0 END) > 0
 ORDER BY c.owner, c.table_name;

-- B) Tabelas pelo nome (planejamento / programação / apontamento / OS)
SELECT owner, table_name, num_rows, last_analyzed
  FROM all_tables
 WHERE owner LIKE 'PIMS%'
   AND (   table_name LIKE '%PLAN%'  OR table_name LIKE '%PROG%'
        OR table_name LIKE '%APT%'   OR table_name LIKE '%APON%'
        OR table_name LIKE '%OPER%'  OR table_name LIKE '%ORDSERV%'
        OR table_name LIKE 'OS%'     OR table_name LIKE '%BOLET%')
 ORDER BY owner, table_name;

-- C) Cadastro de operações (confirmar nome/colunas)
SELECT owner, table_name, column_id, column_name, data_type, data_length
  FROM all_tab_columns
 WHERE owner LIKE 'PIMS%'
   AND table_name IN ('OPERACOES','OPERACAO','GRUPOOPER','GRUPO_OPER','UNIDADE','UNIDADES')
 ORDER BY owner, table_name, column_id;

-- D) Estrutura das tabelas achadas em A/B (trocar a lista pelas tabelas encontradas)
SELECT owner, table_name, column_id, column_name, data_type, data_length
  FROM all_tab_columns
 WHERE owner LIKE 'PIMS%'
   AND table_name IN ('TABELA_PLANEJ','TABELA_PROG','TABELA_APONT')   -- <<< trocar
 ORDER BY owner, table_name, column_id;

-- E) Amostra de cada uma para a fazenda de teste (mesma do Locais a Colher)
-- SELECT * FROM PIMS_CANA.TABELA_PLANEJ WHERE cd_upnivel1 = '462276' AND ROWNUM <= 50;
-- SELECT * FROM PIMS_CANA.TABELA_PROG   WHERE cd_upnivel1 = '462276' AND ROWNUM <= 50;
-- SELECT * FROM PIMS_CANA.TABELA_APONT  WHERE cd_upnivel1 = '462276' AND ROWNUM <= 50;
