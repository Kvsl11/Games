/* Diagnóstico: 21 talhões em que a consulta difere do PRCL-077 de 25/11/2026
   (19 só na consulta + 2 com saldo diferente). Hipótese: o PRCL-077 desconta
   também lançamentos 'E' (baixa) da HISTPREPRO que não vêm de OC. */
WITH t AS (
    SELECT TRIM(COLUMN_VALUE) k FROM TABLE(sys.odcivarchar2list(
      '198|1|4022','198|1|4033','198|1|4035','912|1|43','231|1|81','231|1|82','301|1|54',
      '330|10|24','373|2|12','373|2|25','417|1|13','420|2|44','420|2|51','420|2|64',
      '604|4|48','604|4|51','604|6|24','622|1|21','623|1|35','330|10|33','385|1|11'))
)
-- 1) Todos os lançamentos da HISTPREPRO na safra 2026
SELECT 'HIST' origem, TRIM(h.cd_upnivel1) faz, TRIM(h.cd_upnivel2) gl, TRIM(h.cd_upnivel3) tl,
       h.cd_safra, h.cd_hist, h.dt_historico dt, h.qt_area_prod area, h.qt_tch tch,
       NULL no_oc, NULL parc_tot, NULL situacao
  FROM PIMS_CANA.HISTPREPRO h
  JOIN t ON t.k = TRIM(h.cd_upnivel1)||'|'||TRIM(h.cd_upnivel2)||'|'||TRIM(h.cd_upnivel3)
 WHERE h.cd_safra = 2026
UNION ALL
-- 2) Todas as OCs de safra desses talhões (qualquer safra)
SELECT 'OC', TRIM(d.cd_upnivel1), TRIM(d.cd_upnivel2), TRIM(d.cd_upnivel3),
       d.cd_safra, NULL, he.dt_queima, d.qt_area, d.qt_tch,
       d.no_queima, d.fg_parc_tot, he.fg_situacao
  FROM PIMS_CANA.QUEIMA_DE d
  JOIN PIMS_CANA.QUEIMA_HE he ON he.instancia = d.instancia AND he.no_queima = d.no_queima
  JOIN t ON t.k = TRIM(d.cd_upnivel1)||'|'||TRIM(d.cd_upnivel2)||'|'||TRIM(d.cd_upnivel3)
ORDER BY 2, 3, 4, 5, 7
