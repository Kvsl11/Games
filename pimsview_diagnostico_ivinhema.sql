/* Diagnóstico: diferença consulta x PRCL-077 (Ivinhema, instância 20, safra 2026)
   Talhões de teste:
     30 / 2 / 11    -> está na consulta (11,82 ha) e NÃO está no PRCL-077
     901 / 8 / 11   -> consulta 28,65 ha | PRCL-077 0,01 ha*
     1129 / 1 / 3   -> consulta 48,15 ha | PRCL-077 11,32 ha*
     1 / 1 / 11     -> igual nos dois (controle) */

-- 1) Todo o histórico de produção dos talhões
SELECT TRIM(cd_upnivel1) faz, TRIM(cd_upnivel2) gl, TRIM(cd_upnivel3) tl, cd_safra, cd_hist,
       dt_historico, qt_area_prod, qt_tch, qt_cana_entr, cd_empresa, cd_estagio
  FROM PIMS_CANA.HISTPREPRO
 WHERE cd_safra IN (2025, 2026, 2027)
   AND (TRIM(cd_upnivel1), TRIM(cd_upnivel2), TRIM(cd_upnivel3)) IN
       (('30','2','11'), ('901','8','11'), ('1129','1','3'), ('1','1','11'))
 ORDER BY 1, 2, 3, cd_safra, dt_historico;

-- 2) Todas as OCs de safra desses talhões (qualquer safra e qualquer situação)
SELECT TRIM(d.cd_upnivel1) faz, TRIM(d.cd_upnivel2) gl, TRIM(d.cd_upnivel3) tl,
       d.instancia, d.no_queima, d.cd_safra, d.qt_area, d.qt_estim, d.fg_parc_tot,
       h.fg_situacao, h.dt_queima, h.dt_fechamento
  FROM PIMS_CANA.QUEIMA_DE d
  LEFT JOIN PIMS_CANA.QUEIMA_HE h ON h.instancia = d.instancia AND h.no_queima = d.no_queima
 WHERE (TRIM(d.cd_upnivel1), TRIM(d.cd_upnivel2), TRIM(d.cd_upnivel3)) IN
       (('30','2','11'), ('901','8','11'), ('1129','1','3'), ('1','1','11'))
 ORDER BY 1, 2, 3, h.dt_queima;

-- 3) Cadastro do talhão nas safras 2025/2026/2027
SELECT TRIM(cd_upnivel1) faz, TRIM(cd_upnivel2) gl, TRIM(cd_upnivel3) tl, cd_safra,
       qt_area_prod, qt_area_muda, cd_estagio, cd_empresa, cd_unid_ind, cd_tp_propr
  FROM PIMS_CANA.UPNIVEL3
 WHERE cd_safra IN (2025, 2026, 2027)
   AND (TRIM(cd_upnivel1), TRIM(cd_upnivel2), TRIM(cd_upnivel3)) IN
       (('30','2','11'), ('901','8','11'), ('1129','1','3'), ('1','1','11'))
 ORDER BY 1, 2, 3, cd_safra;

-- 4) Período das safras por instância
SELECT * FROM PIMS_CANA.SAFRAS_PER
 WHERE instancia IN ('10', '20', '44') AND cd_safra IN (2025, 2026, 2027)
 ORDER BY instancia, cd_safra, fg_tipo;

-- 5) Situações possíveis da OC
SELECT fg_situacao, COUNT(*) FROM PIMS_CANA.QUEIMA_HE GROUP BY fg_situacao;
