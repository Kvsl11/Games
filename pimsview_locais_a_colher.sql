/* =====================================================================
   PIMS VIEW - LOCAIS A COLHER (base PRCL-077 + Muda)
   Arquivo em 2 partes:
     PARTE 1 - SELECTs de descoberta (rodar e me devolver o resultado)
     PARTE 2 - Rascunho da view (ajusto nomes de tabela/coluna após a Parte 1)
   Sintaxe: Oracle (padrão do PIMS CS). Se o banco for SQL Server, avise.
   ===================================================================== */


/* =====================================================================
   PARTE 1 - DESCOBERTA
   ===================================================================== */

-- 1.1 Banco / schema em uso
SELECT banner FROM v$version WHERE ROWNUM = 1;
SELECT SYS_CONTEXT('USERENV','CURRENT_SCHEMA') AS schema_atual FROM dual;

-- 1.2 O relatório PRCL-077 tem SQL guardado em package/procedure/view?
SELECT owner, name, type, line, text
  FROM all_source
 WHERE owner = 'PIMS_CANA'
   AND (UPPER(text) LIKE '%PRCL%077%' OR UPPER(text) LIKE '%LOCAIS%COLHER%')
 ORDER BY owner, name, line;

SELECT owner, view_name
  FROM all_views
 WHERE owner = 'PIMS_CANA'
   AND (UPPER(view_name) LIKE '%COLHER%' OR UPPER(view_name) LIKE '%PRCL%'
    OR UPPER(view_name) LIKE '%ESTIM%'  OR UPPER(view_name) LIKE '%CORTE%');

-- 1.3 Tabelas candidatas (locais, estimativa, ordem de corte, cadastros)
SELECT owner, table_name, num_rows
  FROM all_tables
 WHERE owner = 'PIMS_CANA'
   AND (   table_name LIKE 'UPNIVEL%'
        OR table_name LIKE 'HISTPREPRO%'
        OR table_name LIKE '%ESTIM%'
        OR table_name LIKE '%CORTE%'
        OR table_name LIKE '%OCORTE%'
        OR table_name LIKE 'VARIED%'
        OR table_name LIKE 'ESTAG%'
        OR table_name LIKE 'TIPOPROP%' OR table_name LIKE '%TP_PROP%'
        OR table_name LIKE '%MOD%ADM%'
        OR table_name LIKE '%DIST%'
        OR table_name LIKE 'SAFRA%'
        OR table_name LIKE '%MUDA%'
        OR table_name LIKE '%INSTANC%'
        OR table_name LIKE '%UNID%IND%')
 ORDER BY owner, table_name;

-- 1.4 Colunas-chave espalhadas pelo banco (descobre onde estão distância, mod. adm, instância, muda...)
SELECT owner, table_name, column_name, data_type
  FROM all_tab_columns
 WHERE owner = 'PIMS_CANA'
   AND (   column_name LIKE '%DIST%'
        OR column_name LIKE '%MOD_ADM%' OR column_name LIKE '%MODADM%'
        OR column_name LIKE '%INSTANC%'
        OR column_name LIKE '%UNID_IND%'
        OR column_name LIKE '%MUDA%'
        OR column_name LIKE '%TP_PROPR%')
 ORDER BY column_name, table_name;

-- 1.5 Estrutura das tabelas principais (se algum nome não existir, ignore a linha vazia)
SELECT table_name, column_id, column_name, data_type, data_length, nullable
  FROM all_tab_columns
 WHERE owner = 'PIMS_CANA'
   AND table_name IN ('UPNIVEL1','UPNIVEL2','UPNIVEL3','HISTPREPRO','VARIEDAD','VARIEDADES',
                      'ESTAGIOS','TIPOPROP','SAFRAS','SAFRA','OCORTE','ORDCORTE','ORDEMCORTE',
                      'OCORTE_DET','OCORTE_HD','OCORTE_IT')
 ORDER BY table_name, column_id;

-- 1.6 Amostra do exemplo da planilha (Fazenda 462276, talhões 14/15/23)
SELECT * FROM PIMS_CANA.UPNIVEL3   WHERE cd_upnivel1 = '462276' AND cd_upnivel3 IN ('14','15','23');
SELECT * FROM PIMS_CANA.HISTPREPRO WHERE cd_upnivel1 = '462276' AND cd_upnivel3 IN ('14','15','23')
 ORDER BY cd_safra DESC;
SELECT * FROM PIMS_CANA.UPNIVEL1   WHERE cd_upnivel1 = '462276';


/* =====================================================================
   PARTE 2 - RASCUNHO DA VIEW  (NÃO rodar ainda - nomes a confirmar)
   Lógica (igual PRCL-077 + Muda):
     - Base: talhões com estimativa na safra (destino Safra OU Muda)
     - Área colhida: soma das OCs encerradas (total e parcial) na safra
     - Área a colher = Área estimada - Área colhida (só saldo > 0)
     - Ton estimada a colher = Área a colher * TCH estimado
   Itens marcados com  -- ???  dependem da Parte 1.
   ===================================================================== */
/*
CREATE OR REPLACE VIEW PIMS_CANA.V_PV_LOCAIS_A_COLHER AS
WITH safra_atual AS (
    SELECT cd_safra, dt_inicio, dt_fim                       -- ???
      FROM PIMS_CANA.SAFRAS
     WHERE SYSDATE BETWEEN dt_inicio AND dt_fim
),
est AS (  -- última estimativa/reestimativa do talhão na safra
    SELECT h.*,
           ROW_NUMBER() OVER (PARTITION BY h.cd_safra, h.cd_upnivel1, h.cd_upnivel2, h.cd_upnivel3
                              ORDER BY h.dt_historico DESC) rn
      FROM PIMS_CANA.HISTPREPRO h
      JOIN safra_atual s ON s.cd_safra = h.cd_safra
     WHERE h.cd_hist IN ('E','R')                            -- ??? códigos de estimativa
),
colhido AS (  -- OCs encerradas total + parcial
    SELECT oc.cd_safra, oc.cd_upnivel1, oc.cd_upnivel2, oc.cd_upnivel3,
           SUM(oc.qt_area_colh) AS area_colhida,              -- ???
           MAX(CASE WHEN oc.fg_situacao = 'P' THEN 1 ELSE 0 END) AS corte_parcial  -- ???
      FROM PIMS_CANA.OCORTE oc                                          -- ???
      JOIN safra_atual s ON s.cd_safra = oc.cd_safra
     WHERE oc.fg_situacao IN ('E','P')                        -- ??? encerrada total/parcial
     GROUP BY oc.cd_safra, oc.cd_upnivel1, oc.cd_upnivel2, oc.cd_upnivel3
)
SELECT
    u1.instancia                                   AS instancia,            -- ???
    u3.cd_unid_ind                                 AS unidade_industrial,
    u3.cd_tp_propr                                 AS cod_tp_proprietario,
    tp.de_tp_propr                                 AS dsc_tp_proprietario,
    u1.cd_mod_adm                                  AS cod_mod_adm,          -- ???
    ma.de_mod_adm                                  AS dsc_mod_adm,          -- ???
    u3.cd_upnivel1                                 AS cod_fazenda,
    u1.de_upnivel1                                 AS dsc_fazenda,
    u3.cd_upnivel2                                 AS cod_gleba,
    u3.cd_upnivel3                                 AS cod_talhao,
    u3.cd_varied                                   AS cod_variedade,
    v.de_varied                                    AS dsc_variedade,
    u3.cd_estagio                                  AS cod_estagio,
    es.de_estagio                                  AS dsc_estagio,
    ROUND(MONTHS_BETWEEN(SYSDATE, u3.dt_ultimo_corte),1) AS idade_cana_meses,
    NVL(u1.qt_dist_terra,0) + NVL(u1.qt_dist_asfalto,0)
      + NVL(u1.qt_dist_hidrovia,0)                 AS distancia,            -- ???
    u3.qt_area_prod                                AS area_talhao,
    e.qt_area_prod                                 AS area_estimada,
    CASE WHEN e.fg_destino = 'M' THEN 'Muda' ELSE 'Safra' END AS tipo_estimativa, -- ???
    NVL(c.area_colhida,0)                          AS area_colhida,
    e.qt_area_prod - NVL(c.area_colhida,0)         AS area_a_colher,
    CASE WHEN c.corte_parcial = 1 THEN 'S' ELSE 'N' END AS corte_parcial,
    e.dt_historico                                 AS data_estimativa,
    e.qt_tch                                       AS tch_estimado,         -- ??? (planilha chama de "TC Estimado")
    ROUND((e.qt_area_prod - NVL(c.area_colhida,0)) * e.qt_tch, 3) AS ton_estimada
FROM est e
JOIN PIMS_CANA.UPNIVEL3 u3  ON u3.cd_safra    = e.cd_safra
                 AND u3.cd_upnivel1 = e.cd_upnivel1
                 AND u3.cd_upnivel2 = e.cd_upnivel2
                 AND u3.cd_upnivel3 = e.cd_upnivel3
JOIN PIMS_CANA.UPNIVEL1 u1  ON u1.cd_upnivel1 = u3.cd_upnivel1
LEFT JOIN PIMS_CANA.TIPOPROP tp ON tp.cd_tp_propr = u3.cd_tp_propr
LEFT JOIN PIMS_CANA.VARIEDAD v  ON v.cd_varied   = u3.cd_varied
LEFT JOIN PIMS_CANA.ESTAGIOS es ON es.cd_estagio = u3.cd_estagio
LEFT JOIN PIMS_CANA.MOD_ADM  ma ON ma.cd_mod_adm = u1.cd_mod_adm                  -- ???
LEFT JOIN colhido c   ON c.cd_safra    = e.cd_safra
                     AND c.cd_upnivel1 = e.cd_upnivel1
                     AND c.cd_upnivel2 = e.cd_upnivel2
                     AND c.cd_upnivel3 = e.cd_upnivel3
WHERE e.rn = 1
  AND e.qt_area_prod - NVL(c.area_colhida,0) > 0;
*/
