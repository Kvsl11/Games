/* =====================================================================
   PIMS VIEW - LOCAIS A COLHER  (réplica PRCL-077 + área de MUDA)
   Somente SELECT - owner PIMS_CANA - Oracle
   Traz a safra vigente e a seguinte (tombo / virada de safra): filtrar por SAFRA.
   Para comparar com o PRCL-077 filtrar por UNID_IND (uma instância pode ter mais de uma empresa).

   Regras (validadas contra PRCL-077 de 25/11/2026: 6.782 talhões / 86.591,70 ha - 100% iguais):
     - Estimativa safra = HISTPREPRO CD_HIST 'O' (original) ou '1'..'9' (reestimativas), a mais recente
     - Estimativa muda  = HISTPREPRO CD_HIST 'S' (área e TCH da muda) - sem estimativa de muda = muda zerada
     - CD_HIST 'E'      = baixa do local (gerada pela OC ou lançada direto) - não é estimativa
     - Colhido safra    = soma das baixas HISTPREPRO CD_HIST 'E' da safra (mesma regra do PRCL-077:
                          inclui baixas geradas por OC e baixas lançadas sem OC)
     - OC total (FG_PARC_TOT 'T') zera o saldo do talhão (safra e muda)
     - Colhido muda     = OCs de muda (OCORTEMD), abertas e fechadas
     - CORTE_PARC 'S' = talhão já teve baixa e ainda tem saldo (igual ao '*' do PRCL-077)
     - SIT_ULT_OC: A = aberta, F = fechada (documento da OC; 'F' com saldo = corte parcial)
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
est AS (                    -- última estimativa de safra ('O'/'1'..'9') e de muda ('S')
    SELECT h.cd_safra, h.cd_upnivel1, h.cd_upnivel2, h.cd_upnivel3,
           CASE WHEN h.cd_hist = 'S' THEN 'M' ELSE 'S' END AS tipo,
           h.cd_hist, h.dt_historico, h.qt_area_prod, h.qt_tch, h.qt_idade,
           ROW_NUMBER() OVER (PARTITION BY h.cd_safra, h.cd_upnivel1, h.cd_upnivel2, h.cd_upnivel3,
                                           CASE WHEN h.cd_hist = 'S' THEN 'M' ELSE 'S' END
                              ORDER BY h.dt_historico DESC, h.cd_hist DESC) AS rn
      FROM PIMS_CANA.HISTPREPRO h
     WHERE h.cd_hist <> 'E'
),
colh_safra AS (             -- OC de safra emitidas (abertas e fechadas), total + parcial
    SELECT d.cd_safra, d.cd_upnivel1, d.cd_upnivel2, d.cd_upnivel3,
           SUM(d.qt_area)                                       AS area_colhida,
           MAX(CASE WHEN d.fg_parc_tot = 'T' THEN 1 ELSE 0 END) AS fl_total,
           MAX(CASE WHEN d.fg_parc_tot = 'P' THEN 1 ELSE 0 END) AS fl_parcial,
           MAX(h.dt_queima)                                     AS dt_ult_oc,
           MIN(h.fg_situacao)                                   AS situacao_oc   -- 'A' se houver OC aberta
      FROM PIMS_CANA.QUEIMA_DE d
      JOIN PIMS_CANA.QUEIMA_HE h
        ON h.instancia = d.instancia
       AND h.no_queima = d.no_queima
     GROUP BY d.cd_safra, d.cd_upnivel1, d.cd_upnivel2, d.cd_upnivel3
),
baixa_safra AS (            -- baixas de safra ('E'), com ou sem OC
    SELECT h.cd_safra, h.cd_upnivel1, h.cd_upnivel2, h.cd_upnivel3,
           SUM(h.qt_area_prod) AS area_baixada
      FROM PIMS_CANA.HISTPREPRO h
     WHERE h.cd_hist = 'E'
     GROUP BY h.cd_safra, h.cd_upnivel1, h.cd_upnivel2, h.cd_upnivel3
),
colh_muda AS (              -- OC de muda emitidas (abertas e fechadas)
    SELECT d.cd_safra, d.cd_upnivel1, d.cd_upnivel2, d.cd_upnivel3,
           SUM(d.qt_area)                                       AS area_colhida,
           MAX(CASE WHEN d.fg_parc_tot = 'T' THEN 1 ELSE 0 END) AS fl_total
      FROM PIMS_CANA.OCORTEMD_DE d
      JOIN PIMS_CANA.OCORTEMD_HE h
        ON h.instancia = d.instancia
       AND h.no_ordem  = d.no_ordem
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
           u3.qt_area_prod                                  AS area_talhao,
           es.cd_hist,
           NVL(es.dt_historico, em.dt_historico)            AS dt_historico,
           NVL(es.qt_idade, em.qt_idade)                    AS qt_idade,
           NVL(es.qt_tch,0)                                 AS tch_safra,
           NVL(em.qt_tch,0)                                 AS tch_muda,       -- só da estimativa de muda
           NVL(es.qt_area_prod,0)                           AS area_estimada,
           NVL(em.qt_area_prod,0)                           AS area_muda_estimada,
           NVL(bx.area_baixada,0)                           AS area_colhida_safra,
           NVL(cm.area_colhida,0)                           AS area_colhida_muda,
           NVL(cs.fl_total,0)                               AS fl_total,
           NVL(cm.fl_total,0)                               AS fl_total_muda,
           cs.dt_ult_oc,
           cs.situacao_oc
      FROM PIMS_CANA.UPNIVEL3 u3
      JOIN PIMS_CANA.UPNIVEL1 u1
        ON u1.cd_upnivel1 = u3.cd_upnivel1
      JOIN safra_atual sa
        ON sa.instancia = u1.instancia
       AND u3.cd_safra IN (sa.cd_safra, sa.cd_safra + 1)      -- safra atual + seguinte (tombo)
      LEFT JOIN est es
        ON es.cd_safra    = u3.cd_safra
       AND es.cd_upnivel1 = u3.cd_upnivel1
       AND es.cd_upnivel2 = u3.cd_upnivel2
       AND es.cd_upnivel3 = u3.cd_upnivel3
       AND es.tipo = 'S' AND es.rn = 1
      LEFT JOIN est em
        ON em.cd_safra    = u3.cd_safra
       AND em.cd_upnivel1 = u3.cd_upnivel1
       AND em.cd_upnivel2 = u3.cd_upnivel2
       AND em.cd_upnivel3 = u3.cd_upnivel3
       AND em.tipo = 'M' AND em.rn = 1
      LEFT JOIN colh_safra cs
        ON cs.cd_safra    = u3.cd_safra
       AND cs.cd_upnivel1 = u3.cd_upnivel1
       AND cs.cd_upnivel2 = u3.cd_upnivel2
       AND cs.cd_upnivel3 = u3.cd_upnivel3
      LEFT JOIN baixa_safra bx
        ON bx.cd_safra    = u3.cd_safra
       AND bx.cd_upnivel1 = u3.cd_upnivel1
       AND bx.cd_upnivel2 = u3.cd_upnivel2
       AND bx.cd_upnivel3 = u3.cd_upnivel3
      LEFT JOIN colh_muda cm
        ON cm.cd_safra    = u3.cd_safra
       AND cm.cd_upnivel1 = u3.cd_upnivel1
       AND cm.cd_upnivel2 = u3.cd_upnivel2
       AND cm.cd_upnivel3 = u3.cd_upnivel3
     WHERE es.cd_hist IS NOT NULL OR em.cd_hist IS NOT NULL       -- talhão com estimativa
)
SELECT
    b.cd_unid_ind                                        AS UNID_IND,
    b.cd_safra                                           AS SAFRA,
    b.cd_tp_propr                                        AS COD_TP_PROP,
    tp.de_tp_propr                                       AS TP_PROP,
    TRIM(b.cd_mod_adm)                                   AS COD_MOD_ADM,
    NVL(ma.de_mod_adm, ma.da_mod_adm)                    AS MOD_ADM,
    TRIM(b.cd_upnivel1)                                  AS COD_FAZ,
    b.de_upnivel1                                        AS FAZENDA,
    TRIM(b.cd_upnivel2)                                  AS GLEBA,
    TRIM(b.cd_upnivel3)                                  AS TALHAO,
    b.cd_varied                                          AS COD_VAR,
    va.de_varied                                         AS VARIEDADE,
    b.cd_estagio                                         AS COD_EST,
    es.de_estagio                                        AS ESTAGIO,
    ROUND(NULLIF(b.qt_idade, 0) / 30, 1)                 AS IDADE_MESES,  -- idade 0 no PIMS = vazio
    b.distancia                                          AS DIST_KM,
    b.area_talhao                                        AS AREA_TALHAO,
    b.area_estimada                                      AS AREA_EST_SAFRA,
    b.area_colhida_safra                                 AS AREA_COLH_SAFRA,
    b.saldo_safra                                        AS SALDO_SAFRA,
    b.area_muda_estimada                                 AS AREA_EST_MUDA,
    b.area_colhida_muda                                  AS AREA_COLH_MUDA,
    b.saldo_muda                                         AS SALDO_MUDA,
    b.saldo_safra + b.saldo_muda                         AS SALDO_SAFRA_MUDA,
    CASE WHEN b.area_colhida_safra > 0 AND b.saldo_safra > 0
         THEN 'S' ELSE 'N' END                           AS CORTE_PARC,
    DECODE(b.cd_hist, 'O', 'Estimativa', NULL, 'Estimativa Muda', 'Reestimativa ' || b.cd_hist)
                                                         AS ORIGEM_EST_SAFRA,
    b.dt_historico                                       AS DT_ESTIMATIVA,
    b.tch_safra                                          AS TCH_SAFRA,
    ROUND(b.saldo_safra * b.tch_safra, 3)                AS TON_SAFRA,
    b.tch_muda                                           AS TCH_MUDA,
    ROUND(b.saldo_muda  * b.tch_muda, 3)                 AS TON_MUDA,
    b.dt_ult_oc                                          AS DT_ULT_OC,
    b.situacao_oc                                        AS SIT_ULT_OC   -- A = aberta, F = fechada
FROM (SELECT x.*,
             -- safra: estimada - baixas 'E' (OC total = saldo zero)
             CASE WHEN x.fl_total = 1 THEN 0
                  ELSE GREATEST(x.area_estimada - x.area_colhida_safra, 0) END      AS saldo_safra,
             -- muda: estimativa de muda - OCs de muda (OC total de safra ou de muda = saldo zero)
             CASE WHEN x.fl_total = 1 OR x.fl_total_muda = 1 THEN 0
                  ELSE GREATEST(x.area_muda_estimada - x.area_colhida_muda, 0) END AS saldo_muda
        FROM base x) b
LEFT JOIN PIMS_CANA.TIPOPROPRI tp ON tp.cd_tp_propr = b.cd_tp_propr
LEFT JOIN PIMS_CANA.MODULOADM  ma ON TRIM(ma.cd_mod_adm) = TRIM(b.cd_mod_adm)
LEFT JOIN PIMS_CANA.VARIEDADES va ON va.cd_varied   = b.cd_varied
LEFT JOIN PIMS_CANA.ESTAGIOS   es ON es.cd_estagio  = b.cd_estagio
WHERE (b.saldo_safra > 0 OR b.saldo_muda > 0)                            -- só locais com saldo a colher
ORDER BY b.cd_safra, b.cd_unid_ind, b.cd_upnivel1, b.cd_upnivel2, b.cd_upnivel3
