/* =====================================================================
   PIMS VIEW - LOCAIS A COLHER  (réplica PRCL-077 + área de MUDA)
   Somente SELECT - owner PIMS_CANA - Oracle
   Traz a safra vigente e a seguinte (tombo / virada de safra): filtrar por COD_SAFRA.
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
est AS (                    -- última estimativa / reestimativa do talhão ('E' = encerramento)
    SELECT h.cd_safra, h.cd_upnivel1, h.cd_upnivel2, h.cd_upnivel3,
           h.cd_hist, h.dt_historico, h.qt_area_prod, h.qt_tch, h.qt_idade,
           ROW_NUMBER() OVER (PARTITION BY h.cd_safra, h.cd_upnivel1, h.cd_upnivel2, h.cd_upnivel3
                              ORDER BY h.dt_historico DESC, h.cd_hist DESC) AS rn
      FROM PIMS_CANA.HISTPREPRO h
     WHERE h.cd_hist NOT IN ('E', 'S')
),
colh_safra AS (             -- OC de safra encerradas (total + parcial)
    SELECT d.cd_safra, d.cd_upnivel1, d.cd_upnivel2, d.cd_upnivel3,
           SUM(d.qt_area)                                       AS area_colhida,
           MAX(CASE WHEN d.fg_parc_tot = 'T' THEN 1 ELSE 0 END) AS fl_total,
           MAX(CASE WHEN d.fg_parc_tot = 'P' THEN 1 ELSE 0 END) AS fl_parcial,
           MAX(h.dt_fechamento)                                 AS dt_ult_fechamento
      FROM PIMS_CANA.QUEIMA_DE d
      JOIN PIMS_CANA.QUEIMA_HE h
        ON h.instancia = d.instancia
       AND h.no_queima = d.no_queima
     WHERE h.fg_situacao = 'F'
     GROUP BY d.cd_safra, d.cd_upnivel1, d.cd_upnivel2, d.cd_upnivel3
),
colh_muda AS (              -- OC de muda encerradas (total + parcial)
    SELECT d.cd_safra, d.cd_upnivel1, d.cd_upnivel2, d.cd_upnivel3,
           SUM(d.qt_area) AS area_colhida
      FROM PIMS_CANA.OCORTEMD_DE d
      JOIN PIMS_CANA.OCORTEMD_HE h
        ON h.instancia = d.instancia
       AND h.no_ordem  = d.no_ordem
     WHERE h.fg_situacao = 'F'
     GROUP BY d.cd_safra, d.cd_upnivel1, d.cd_upnivel2, d.cd_upnivel3
),
base AS (
    SELECT u1.instancia,
           u3.cd_unid_ind,
           u3.cd_tp_propr,
           u3.cd_mod_adm,
           u3.cd_safra,
           u3.cd_upnivel1, u1.de_upnivel1,
           u3.cd_upnivel2, u3.cd_upnivel3,
           u3.cd_varied, u3.cd_estagio,
           NVL(u3.ds_terra,0) + NVL(u3.ds_asfalto,0) + NVL(u3.ds_hidrovia,0) AS distancia,
           u3.qt_area_prod                        AS area_talhao,
           NVL(u3.qt_area_muda,0)                 AS area_muda_estimada,
           e.cd_hist, e.dt_historico, e.qt_tch, e.qt_idade,
           NVL(e.qt_area_prod,0)                  AS area_estimada,
           NVL(cs.area_colhida,0)                 AS area_colhida_safra,
           NVL(cm.area_colhida,0)                 AS area_colhida_muda,
           NVL(cs.fl_total,0)                     AS fl_total,
           NVL(cs.fl_parcial,0)                   AS fl_parcial,
           cs.dt_ult_fechamento
      FROM PIMS_CANA.UPNIVEL3 u3
      JOIN PIMS_CANA.UPNIVEL1 u1
        ON u1.cd_upnivel1 = u3.cd_upnivel1
      JOIN safra_atual sa
        ON sa.instancia = u1.instancia
       AND u3.cd_safra IN (sa.cd_safra, sa.cd_safra + 1)      -- safra atual + seguinte (tombo)
      JOIN est e
        ON e.cd_safra    = u3.cd_safra
       AND e.cd_upnivel1 = u3.cd_upnivel1
       AND e.cd_upnivel2 = u3.cd_upnivel2
       AND e.cd_upnivel3 = u3.cd_upnivel3
       AND e.rn = 1
      LEFT JOIN colh_safra cs
        ON cs.cd_safra    = u3.cd_safra
       AND cs.cd_upnivel1 = u3.cd_upnivel1
       AND cs.cd_upnivel2 = u3.cd_upnivel2
       AND cs.cd_upnivel3 = u3.cd_upnivel3
      LEFT JOIN colh_muda cm
        ON cm.cd_safra    = u3.cd_safra
       AND cm.cd_upnivel1 = u3.cd_upnivel1
       AND cm.cd_upnivel2 = u3.cd_upnivel2
       AND cm.cd_upnivel3 = u3.cd_upnivel3
)
SELECT
    b.instancia                                          AS INSTANCIA,
    b.cd_unid_ind                                        AS UNIDADE_INDUSTRIAL,
    b.cd_safra                                           AS COD_SAFRA,
    sf.de_safra                                          AS DSC_SAFRA,
    b.cd_tp_propr                                        AS COD_TP_PROPRIETARIO,
    tp.de_tp_propr                                       AS DSC_TP_PROPRIETARIO,
    TRIM(b.cd_mod_adm)                                   AS COD_MOD_ADM,
    NVL(ma.de_mod_adm, ma.da_mod_adm)                    AS DSC_MOD_ADM,
    TRIM(b.cd_upnivel1)                                  AS COD_FAZENDA,
    b.de_upnivel1                                        AS DSC_FAZENDA,
    TRIM(b.cd_upnivel2)                                  AS COD_GLEBA,
    TRIM(b.cd_upnivel3)                                  AS COD_TALHAO,
    b.cd_varied                                          AS COD_VARIEDADE,
    va.de_varied                                         AS DSC_VARIEDADE,
    b.cd_estagio                                         AS COD_ESTAGIO,
    es.de_estagio                                        AS DSC_ESTAGIO,
    ROUND(b.qt_idade / 30, 1)                            AS IDADE_CANA_MESES,
    b.distancia                                          AS DISTANCIA_KM,
    b.area_talhao                                        AS AREA_TALHAO,
    b.area_estimada                                      AS AREA_ESTIMADA,
    b.area_colhida_safra                                 AS AREA_COLHIDA_SAFRA,
    b.saldo_safra                                        AS AREA_A_COLHER,
    b.area_muda_estimada                                 AS AREA_MUDA_ESTIMADA,
    b.area_colhida_muda                                  AS AREA_MUDA_COLHIDA,
    b.saldo_muda                                         AS AREA_MUDA_A_COLHER,
    CASE WHEN b.saldo_safra > 0 AND b.saldo_muda > 0 THEN 'Safra + Muda'
         WHEN b.saldo_muda  > 0                      THEN 'Muda'
         ELSE 'Safra' END                                AS TIPO_ESTIMATIVA,
    CASE WHEN b.fl_parcial = 1 THEN 'S' ELSE 'N' END     AS CORTE_PARCIAL,
    DECODE(b.cd_hist, 'O', 'Estimativa', 'Reestimativa ' || b.cd_hist)
                                                         AS ORIGEM_ESTIMATIVA,
    b.dt_historico                                       AS DATA_ESTIMATIVA,
    b.qt_tch                                             AS TCH_ESTIMADO,
    ROUND(b.saldo_safra * b.qt_tch, 3)                   AS TON_ESTIMADA,
    ROUND(b.saldo_muda  * b.qt_tch, 3)                   AS TON_MUDA_ESTIMADA,
    b.dt_ult_fechamento                                  AS DT_ULT_FECHAMENTO_OC
FROM (SELECT x.*,
             -- safra: estimada - OC safra encerradas (OC total = saldo zero)
             CASE WHEN x.fl_total = 1 THEN 0
                  ELSE GREATEST(x.area_estimada - x.area_colhida_safra, 0) END AS saldo_safra,
             -- muda: área de muda do talhão - OC de muda encerradas
             GREATEST(x.area_muda_estimada - x.area_colhida_muda, 0)          AS saldo_muda
        FROM base x) b
LEFT JOIN PIMS_CANA.SAFRAS     sf ON sf.cd_safra    = b.cd_safra
LEFT JOIN PIMS_CANA.TIPOPROPRI tp ON tp.cd_tp_propr = b.cd_tp_propr
LEFT JOIN PIMS_CANA.MODULOADM  ma ON TRIM(ma.cd_mod_adm) = TRIM(b.cd_mod_adm)
LEFT JOIN PIMS_CANA.VARIEDADES va ON va.cd_varied   = b.cd_varied
LEFT JOIN PIMS_CANA.ESTAGIOS   es ON es.cd_estagio  = b.cd_estagio
WHERE b.saldo_safra > 0 OR b.saldo_muda > 0                              -- só locais com saldo a colher
ORDER BY b.cd_safra, b.instancia, b.cd_upnivel1, b.cd_upnivel2, b.cd_upnivel3
