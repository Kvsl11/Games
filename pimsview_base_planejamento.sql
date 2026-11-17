/* =====================================================================
   PIMS VIEW - BASE DE PLANEJAMENTO DE OPERAÇÕES AGR
   Somente SELECT - owner PIMS_CANA - Oracle
   Uma linha por TALHÃO (safra vigente + seguinte) com tudo que o
   planejamento de operações precisa: área, estágio, variedade, idade,
   último corte, estimativa e saldo a colher.
   Pode ser agregada por Fazenda/Gleba no BI (somar AREA_*).
   Usa só tabelas já validadas nos outros codes (Locais a Colher / PRCL-077).
   ===================================================================== */
WITH
safra_atual AS (            -- safra vigente por instância (fallback: ano-safra abr..mar)
    SELECT u1.instancia,
           NVL((SELECT MAX(sp.cd_safra)
                  FROM PIMS_CANA.SAFRAS_PER sp
                 WHERE sp.instancia = u1.instancia
                   AND sp.fg_tipo   = 'CTR'
                   AND TRUNC(SYSDATE) BETWEEN sp.dt_ini_safra AND sp.dt_fim_safra),
               EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -3))) AS cd_safra
      FROM (SELECT DISTINCT instancia FROM PIMS_CANA.UPNIVEL1) u1
),
est AS (                    -- última estimativa de safra ('O'/'1'..'9')
    SELECT h.cd_safra, h.cd_upnivel1, h.cd_upnivel2, h.cd_upnivel3,
           h.cd_hist, h.dt_historico, h.qt_area_prod, h.qt_tch, h.qt_idade,
           ROW_NUMBER() OVER (PARTITION BY h.cd_safra, h.cd_upnivel1, h.cd_upnivel2, h.cd_upnivel3
                              ORDER BY h.dt_historico DESC, h.cd_hist DESC) AS rn
      FROM PIMS_CANA.HISTPREPRO h
     WHERE h.cd_hist NOT IN ('E','S')
),
oc AS (                     -- OCs de safra: colhido na safra + data do último corte (qualquer safra)
    SELECT d.cd_upnivel1, d.cd_upnivel2, d.cd_upnivel3,
           MAX(h.dt_queima)                                              AS dt_ult_corte,
           d.cd_safra,
           SUM(d.qt_area)                                                AS area_colhida,
           MAX(CASE WHEN d.fg_parc_tot = 'T' THEN 1 ELSE 0 END)          AS fl_total
      FROM PIMS_CANA.QUEIMA_DE d
      JOIN PIMS_CANA.QUEIMA_HE h
        ON h.instancia = d.instancia
       AND h.no_queima = d.no_queima
     GROUP BY d.cd_upnivel1, d.cd_upnivel2, d.cd_upnivel3, d.cd_safra
),
ult_corte AS (
    SELECT cd_upnivel1, cd_upnivel2, cd_upnivel3, MAX(dt_ult_corte) AS dt_ult_corte
      FROM oc
     GROUP BY cd_upnivel1, cd_upnivel2, cd_upnivel3
)
SELECT
    u1.instancia                                         AS INSTANCIA,
    u3.cd_unid_ind                                       AS UNIDADE_INDUSTRIAL,
    u3.cd_safra                                          AS COD_SAFRA,
    u3.cd_tp_propr                                       AS COD_TP_PROPRIETARIO,
    tp.de_tp_propr                                       AS DSC_TP_PROPRIETARIO,
    TRIM(u3.cd_mod_adm)                                  AS COD_MOD_ADM,
    NVL(ma.de_mod_adm, ma.da_mod_adm)                    AS DSC_MOD_ADM,
    TRIM(u3.cd_upnivel1)                                 AS COD_FAZENDA,
    u1.de_upnivel1                                       AS DSC_FAZENDA,
    TRIM(u3.cd_upnivel2)                                 AS COD_GLEBA,
    TRIM(u3.cd_upnivel3)                                 AS COD_TALHAO,
    TRIM(u3.cd_upnivel1) || '-' || TRIM(u3.cd_upnivel2)  AS CHAVE_FAZ_GLEBA,
    TRIM(u3.cd_upnivel1) || '-' || TRIM(u3.cd_upnivel2) || '-' || TRIM(u3.cd_upnivel3)
                                                         AS CHAVE_TALHAO,
    u3.cd_varied                                         AS COD_VARIEDADE,
    va.de_varied                                         AS DSC_VARIEDADE,
    u3.cd_estagio                                        AS COD_ESTAGIO,
    eg.de_estagio                                        AS DSC_ESTAGIO,
    NVL(u3.ds_terra,0) + NVL(u3.ds_asfalto,0) + NVL(u3.ds_hidrovia,0)
                                                         AS DISTANCIA_KM,
    u3.qt_area_prod                                      AS AREA_TALHAO,
    NVL(u3.qt_area_muda,0)                               AS AREA_MUDA_CADASTRO,
    ROUND(NULLIF(e.qt_idade, 0) / 30, 1)                 AS IDADE_CANA_MESES,
    uc.dt_ult_corte                                      AS DT_ULTIMO_CORTE,
    ROUND(MONTHS_BETWEEN(TRUNC(SYSDATE), uc.dt_ult_corte), 1)
                                                         AS MESES_DESDE_CORTE,
    DECODE(e.cd_hist, 'O', 'Estimativa', NULL, NULL, 'Reestimativa ' || e.cd_hist)
                                                         AS ORIGEM_ESTIMATIVA,
    e.qt_tch                                             AS TCH_ESTIMADO,
    NVL(e.qt_area_prod,0)                                AS AREA_ESTIMADA,
    NVL(o.area_colhida,0)                                AS AREA_COLHIDA_SAFRA,
    CASE WHEN NVL(o.fl_total,0) = 1 THEN 0
         ELSE GREATEST(NVL(e.qt_area_prod,0) - NVL(o.area_colhida,0), 0) END
                                                         AS AREA_A_COLHER,
    CASE WHEN NVL(o.fl_total,0) = 1                 THEN 'Colhido'
         WHEN NVL(o.area_colhida,0) > 0             THEN 'Colhido parcial'
         WHEN e.cd_hist IS NOT NULL                 THEN 'A colher'
         ELSE 'Sem estimativa' END                       AS SITUACAO_COLHEITA
FROM PIMS_CANA.UPNIVEL3 u3
JOIN PIMS_CANA.UPNIVEL1 u1
  ON u1.cd_upnivel1 = u3.cd_upnivel1
JOIN safra_atual sa
  ON sa.instancia = u1.instancia
 AND u3.cd_safra IN (sa.cd_safra, sa.cd_safra + 1)
LEFT JOIN est e
  ON e.cd_safra    = u3.cd_safra
 AND e.cd_upnivel1 = u3.cd_upnivel1
 AND e.cd_upnivel2 = u3.cd_upnivel2
 AND e.cd_upnivel3 = u3.cd_upnivel3
 AND e.rn = 1
LEFT JOIN oc o
  ON o.cd_safra    = u3.cd_safra
 AND o.cd_upnivel1 = u3.cd_upnivel1
 AND o.cd_upnivel2 = u3.cd_upnivel2
 AND o.cd_upnivel3 = u3.cd_upnivel3
LEFT JOIN ult_corte uc
  ON uc.cd_upnivel1 = u3.cd_upnivel1
 AND uc.cd_upnivel2 = u3.cd_upnivel2
 AND uc.cd_upnivel3 = u3.cd_upnivel3
LEFT JOIN PIMS_CANA.TIPOPROPRI tp ON tp.cd_tp_propr = u3.cd_tp_propr
LEFT JOIN PIMS_CANA.MODULOADM  ma ON TRIM(ma.cd_mod_adm) = TRIM(u3.cd_mod_adm)
LEFT JOIN PIMS_CANA.VARIEDADES va ON va.cd_varied   = u3.cd_varied
LEFT JOIN PIMS_CANA.ESTAGIOS   eg ON eg.cd_estagio  = u3.cd_estagio
WHERE NVL(u3.qt_area_prod, 0) > 0
ORDER BY u3.cd_safra, u3.cd_unid_ind, u3.cd_upnivel1, u3.cd_upnivel2, u3.cd_upnivel3
