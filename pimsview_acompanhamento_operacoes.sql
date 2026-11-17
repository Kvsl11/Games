/* =====================================================================
   PIMS VIEW - ACOMPANHAMENTO DE OPERAÇÕES AGR
   Operação x Fazenda x Gleba x Área  |  Planejado x Programado x Realizado
   Somente SELECT - Oracle

   *** ATENÇÃO: os 3 CTEs marcados com  <<< CONFIRMAR  usam nomes de
   tabela/coluna PROVISÓRIOS. Rodar antes o pimsview_operacoes_descoberta.sql
   e trocar só esses 3 blocos (+ o cadastro OPERACOES). O resto já está
   no padrão validado (UPNIVEL1/UPNIVEL3/SAFRAS_PER).
   Cada CTE precisa devolver: cd_safra, cd_operacao, cd_upnivel1,
   cd_upnivel2, area (+ datas). Se a tabela for por talhão, o GROUP BY
   já consolida na gleba.
   ===================================================================== */
WITH
safra_atual AS (
    SELECT u1.instancia,
           NVL((SELECT MAX(sp.cd_safra)
                  FROM PIMS_CANA.SAFRAS_PER sp
                 WHERE sp.instancia = u1.instancia
                   AND sp.fg_tipo   = 'CTR'
                   AND TRUNC(SYSDATE) BETWEEN sp.dt_ini_safra AND sp.dt_fim_safra),
               EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -3))) AS cd_safra
      FROM (SELECT DISTINCT instancia FROM PIMS_CANA.UPNIVEL1) u1
),
gleba AS (                  -- área cadastrada da gleba (soma dos talhões)
    SELECT u1.instancia, u3.cd_unid_ind, u3.cd_safra,
           u3.cd_upnivel1, u1.de_upnivel1, u3.cd_upnivel2,
           COUNT(*)              AS qt_talhoes,
           SUM(u3.qt_area_prod)  AS area_gleba
      FROM PIMS_CANA.UPNIVEL3 u3
      JOIN PIMS_CANA.UPNIVEL1 u1 ON u1.cd_upnivel1 = u3.cd_upnivel1
      JOIN safra_atual sa
        ON sa.instancia = u1.instancia
       AND u3.cd_safra IN (sa.cd_safra, sa.cd_safra + 1)
     GROUP BY u1.instancia, u3.cd_unid_ind, u3.cd_safra,
              u3.cd_upnivel1, u1.de_upnivel1, u3.cd_upnivel2
),
plan AS (                   -- PLANEJAMENTO   <<< CONFIRMAR tabela/colunas
    SELECT p.cd_safra, p.cd_operacao, p.cd_upnivel1, p.cd_upnivel2,
           SUM(p.qt_area)        AS area_plan,
           MIN(p.dt_inicio)      AS dt_ini_plan,
           MAX(p.dt_fim)         AS dt_fim_plan
      FROM PIMS_CANA.PLANEJ_OPER p
     GROUP BY p.cd_safra, p.cd_operacao, p.cd_upnivel1, p.cd_upnivel2
),
prog AS (                   -- PROGRAMAÇÃO    <<< CONFIRMAR tabela/colunas
    SELECT g.cd_safra, g.cd_operacao, g.cd_upnivel1, g.cd_upnivel2,
           SUM(g.qt_area)        AS area_prog,
           MIN(g.dt_programacao) AS dt_ini_prog,
           MAX(g.dt_programacao) AS dt_fim_prog
      FROM PIMS_CANA.PROGRAM_OPER g
     WHERE NVL(g.fg_situacao, 'A') <> 'C'               -- ignorar programação cancelada
     GROUP BY g.cd_safra, g.cd_operacao, g.cd_upnivel1, g.cd_upnivel2
),
realiz AS (                   -- REALIZADO (apontamento)  <<< CONFIRMAR tabela/colunas
    SELECT r.cd_safra, r.cd_operacao, r.cd_upnivel1, r.cd_upnivel2,
           SUM(r.qt_area)        AS area_real,
           MIN(r.dt_operacao)    AS dt_ini_real,
           MAX(r.dt_operacao)    AS dt_ult_real
      FROM PIMS_CANA.APONT_OPER r
     GROUP BY r.cd_safra, r.cd_operacao, r.cd_upnivel1, r.cd_upnivel2
),
chaves AS (                 -- toda combinação que aparece em qualquer uma das 3 fases
    SELECT cd_safra, cd_operacao, cd_upnivel1, cd_upnivel2 FROM plan
    UNION
    SELECT cd_safra, cd_operacao, cd_upnivel1, cd_upnivel2 FROM prog
    UNION
    SELECT cd_safra, cd_operacao, cd_upnivel1, cd_upnivel2 FROM realiz
)
SELECT
    g.instancia                                          AS INSTANCIA,
    g.cd_unid_ind                                        AS UNIDADE_INDUSTRIAL,
    k.cd_safra                                           AS COD_SAFRA,
    k.cd_operacao                                        AS COD_OPERACAO,
    op.de_operacao                                       AS DSC_OPERACAO,
    TRIM(k.cd_upnivel1)                                  AS COD_FAZENDA,
    g.de_upnivel1                                        AS DSC_FAZENDA,
    TRIM(k.cd_upnivel2)                                  AS COD_GLEBA,
    g.qt_talhoes                                         AS QTD_TALHOES,
    ROUND(g.area_gleba, 2)                               AS AREA_GLEBA,
    ROUND(NVL(p.area_plan, 0), 2)                        AS AREA_PLANEJADA,
    ROUND(NVL(q.area_prog, 0), 2)                        AS AREA_PROGRAMADA,
    ROUND(NVL(r.area_real, 0), 2)                        AS AREA_REALIZADA,
    ROUND(GREATEST(NVL(p.area_plan,0) - NVL(q.area_prog,0), 0), 2) AS SALDO_A_PROGRAMAR,
    ROUND(GREATEST(NVL(q.area_prog,0) - NVL(r.area_real,0), 0), 2) AS SALDO_A_REALIZAR,
    ROUND(100 * NVL(q.area_prog,0) / NULLIF(p.area_plan,0), 1)     AS PERC_PROG_X_PLAN,
    ROUND(100 * NVL(r.area_real,0) / NULLIF(p.area_plan,0), 1)     AS PERC_REAL_X_PLAN,
    ROUND(100 * NVL(r.area_real,0) / NULLIF(q.area_prog,0), 1)     AS PERC_REAL_X_PROG,
    p.dt_ini_plan                                        AS DT_INI_PLANEJADA,
    p.dt_fim_plan                                        AS DT_FIM_PLANEJADA,
    q.dt_ini_prog                                        AS DT_INI_PROGRAMADA,
    q.dt_fim_prog                                        AS DT_FIM_PROGRAMADA,
    r.dt_ini_real                                        AS DT_INI_REALIZADA,
    r.dt_ult_real                                        AS DT_ULT_REALIZADA,
    CASE WHEN NVL(r.area_real,0) >= NVL(p.area_plan,0) AND p.area_plan > 0 THEN 'Concluído'
         WHEN p.area_plan IS NULL AND r.area_real > 0                     THEN 'Realizado sem planejamento'
         WHEN NVL(r.area_real,0) > 0                                      THEN 'Em andamento'
         WHEN NVL(q.area_prog,0) > 0                                      THEN 'Programado'
         WHEN p.dt_fim_plan < TRUNC(SYSDATE)                              THEN 'Atrasado'
         ELSE 'Planejado' END                            AS STATUS
FROM chaves k
JOIN gleba g                                             -- restringe à safra vigente + seguinte
  ON g.cd_safra    = k.cd_safra
 AND g.cd_upnivel1 = k.cd_upnivel1
 AND g.cd_upnivel2 = k.cd_upnivel2
LEFT JOIN plan p
  ON p.cd_safra = k.cd_safra AND p.cd_operacao = k.cd_operacao
 AND p.cd_upnivel1 = k.cd_upnivel1 AND p.cd_upnivel2 = k.cd_upnivel2
LEFT JOIN prog q
  ON q.cd_safra = k.cd_safra AND q.cd_operacao = k.cd_operacao
 AND q.cd_upnivel1 = k.cd_upnivel1 AND q.cd_upnivel2 = k.cd_upnivel2
LEFT JOIN realiz r
  ON r.cd_safra = k.cd_safra AND r.cd_operacao = k.cd_operacao
 AND r.cd_upnivel1 = k.cd_upnivel1 AND r.cd_upnivel2 = k.cd_upnivel2
LEFT JOIN PIMS_CANA.OPERACOES op                         -- <<< CONFIRMAR cadastro
  ON op.cd_operacao = k.cd_operacao
ORDER BY k.cd_safra, g.cd_unid_ind, k.cd_operacao, k.cd_upnivel1, k.cd_upnivel2
