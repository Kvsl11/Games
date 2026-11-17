/* =====================================================================
   OPERAÇÕES AGR - DESCOBERTA COMPLETA  (um único SELECT)
   Acha as tabelas de Planejamento / Programação / Apontamento / Cadastro
   de operações e, para cada uma, já traz:
     - todas as colunas
     - qtd de linhas (estatística) e qtd da fazenda de teste / safra 2026
     - AMOSTRA de 3 linhas (em XML) - da fazenda de teste quando houver
   Ajuste a fazenda/safra de teste nos 2 parâmetros abaixo se quiser.
   Exporte o resultado inteiro (Excel/CSV) e me mande.
   ===================================================================== */
WITH
par AS (SELECT '462276' AS faz, 2026 AS safra FROM dual),
cols AS (
    SELECT c.owner, c.table_name,
           MAX(CASE WHEN c.column_name LIKE 'CD_OPER%'    THEN 1 ELSE 0 END) AS tem_oper,
           MAX(CASE WHEN c.column_name =    'CD_UPNIVEL1' THEN 1 ELSE 0 END) AS tem_faz,
           MAX(CASE WHEN c.column_name =    'CD_UPNIVEL2' THEN 1 ELSE 0 END) AS tem_gleba,
           MAX(CASE WHEN c.column_name =    'CD_SAFRA'    THEN 1 ELSE 0 END) AS tem_safra,
           MAX(CASE WHEN c.column_name LIKE 'QT_AREA%'    THEN 1 ELSE 0 END) AS tem_area,
           MAX(CASE WHEN c.data_type IN ('LONG','LONG RAW','BLOB','BFILE') THEN 1 ELSE 0 END) AS tem_long,
           LISTAGG(c.column_name, ', ') WITHIN GROUP (ORDER BY c.column_id)  AS colunas
      FROM all_tab_columns c
     WHERE c.owner LIKE 'PIMS%'
     GROUP BY c.owner, c.table_name
),
cand AS (
    SELECT t.owner, t.table_name, t.num_rows, t.last_analyzed, c.*,
           CASE WHEN c.tem_oper = 1 AND c.tem_faz = 1 AND c.tem_area = 1 THEN 1   -- forte candidata
                WHEN c.tem_oper = 1 AND c.tem_faz = 1                    THEN 2
                WHEN t.table_name LIKE 'OPERAC%'                         THEN 3   -- cadastro
                WHEN c.tem_oper = 1                                      THEN 4
                ELSE 5 END AS prioridade
      FROM all_tables t
      JOIN cols c ON c.owner = t.owner AND c.table_name = t.table_name
     WHERE c.tem_oper = 1
        OR t.table_name LIKE '%PLAN%'  OR t.table_name LIKE '%PROG%'
        OR t.table_name LIKE '%APT%'   OR t.table_name LIKE '%APON%'
        OR t.table_name LIKE '%OPER%'  OR t.table_name LIKE '%ORDSERV%'
        OR t.table_name LIKE 'OS%'     OR t.table_name LIKE '%BOLET%'
),
sqls AS (
    SELECT k.*,
           '"' || k.owner || '"."' || k.table_name || '"' AS tab,
           CASE WHEN k.tem_faz = 1
                THEN ' WHERE TRIM(CD_UPNIVEL1) = ''' || p.faz || '''' END AS filtro_faz,
           CASE WHEN k.tem_safra = 1
                THEN ' WHERE CD_SAFRA = ' || p.safra END                AS filtro_safra
      FROM cand k CROSS JOIN par p
)
SELECT s.prioridade,
       s.owner,
       s.table_name,
       s.num_rows                                        AS linhas_estatistica,
       s.last_analyzed,
       CASE WHEN s.tem_faz = 1 THEN
            TO_NUMBER(EXTRACTVALUE(XMLTYPE(DBMS_XMLGEN.GETXML(
               'SELECT COUNT(*) C FROM ' || s.tab || s.filtro_faz)), '/ROWSET/ROW/C')) END
                                                         AS linhas_fazenda_teste,
       CASE WHEN s.tem_safra = 1 THEN
            TO_NUMBER(EXTRACTVALUE(XMLTYPE(DBMS_XMLGEN.GETXML(
               'SELECT COUNT(*) C FROM ' || s.tab || s.filtro_safra)), '/ROWSET/ROW/C')) END
                                                         AS linhas_safra_teste,
       s.tem_oper, s.tem_faz, s.tem_gleba, s.tem_safra, s.tem_area,
       s.colunas,
       CASE WHEN s.tem_long = 0 THEN
            DBMS_LOB.SUBSTR(DBMS_XMLGEN.GETXML(
               'SELECT * FROM ' || s.tab ||
               CASE WHEN s.filtro_faz IS NOT NULL THEN s.filtro_faz || ' AND ROWNUM <= 3'
                    ELSE ' WHERE ROWNUM <= 3' END), 4000, 1)
            ELSE '(tem coluna LONG/BLOB - sem amostra)' END
                                                         AS amostra_xml
  FROM sqls s
 ORDER BY s.prioridade, s.owner, s.table_name
