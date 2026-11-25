/* LOOKUPS DOS PARÂMETROS - PIMS VIEW LOCAIS A COLHER
   Cada SELECT devolve CODIGO (valor do parâmetro) e DESCRICAO (texto do combo).
   A primeira linha é '%' = TODOS. */

-- P_FAZENDA
SELECT codigo, descricao FROM (
    SELECT '%' AS codigo, 'TODAS' AS descricao, 0 AS ordem, 0 AS cod_num FROM dual
    UNION ALL
    SELECT TRIM(f.cd_upnivel1), TRIM(f.cd_upnivel1) || ' - ' || f.de_upnivel1, 1,
           TO_NUMBER(REGEXP_SUBSTR(TRIM(f.cd_upnivel1), '^\d+'))
      FROM PIMS_CANA.UPNIVEL1 f
     WHERE f.fg_ativo = 'S'
) ORDER BY ordem, cod_num, codigo;

-- P_GLEBA (filtra pela fazenda escolhida; '%' = todas)
SELECT codigo, descricao FROM (
    SELECT '%' AS codigo, 'TODAS' AS descricao, 0 AS ordem, 0 AS cod_num FROM dual
    UNION ALL
    SELECT DISTINCT TRIM(g.cd_upnivel2), 'GLEBA ' || TRIM(g.cd_upnivel2), 1,
           TO_NUMBER(REGEXP_SUBSTR(TRIM(g.cd_upnivel2), '^\d+'))
      FROM PIMS_CANA.UPNIVEL2 g
     WHERE TRIM(g.cd_upnivel1) LIKE NVL(TRIM(:P_FAZENDA), '%')
) ORDER BY ordem, cod_num, codigo;

-- P_UNIDADE_INDUSTRIAL
SELECT codigo, descricao FROM (
    SELECT '%' AS codigo, 'TODAS' AS descricao, 0 AS ordem, 0 AS cod_num FROM dual
    UNION ALL
    SELECT '10', '10 - MONTE ALEGRE', 1, 10 FROM dual UNION ALL
    SELECT '20', '20 - ANGÉLICA',     1, 20 FROM dual UNION ALL
    SELECT '23', '23 - IVINHEMA',     1, 23 FROM dual UNION ALL
    SELECT '44', '44 - CAARAPÓ',      1, 44 FROM dual
) ORDER BY ordem, cod_num, codigo;

-- P_TP_PROPRIETARIO
SELECT codigo, descricao FROM (
    SELECT '%' AS codigo, 'TODOS' AS descricao, 0 AS ordem, 0 AS cod_num FROM dual
    UNION ALL
    SELECT TO_CHAR(t.cd_tp_propr), t.cd_tp_propr || ' - ' || t.de_tp_propr, 1, t.cd_tp_propr
      FROM PIMS_CANA.TIPOPROPRI t
) ORDER BY ordem, cod_num, codigo;
