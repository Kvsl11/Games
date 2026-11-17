/* Diagnóstico 2: por que o PRCL-077 (Ivinhema) não traz 169 fazendas que a consulta traz?
   Lista abaixo = as 127 fazendas que aparecem no PDF do PRCL-077 (empresa 20, safra 2026).
   Compara as características das fazendas DENTRO x FORA do relatório. */
WITH rel AS (
    SELECT TRIM(COLUMN_VALUE) faz FROM TABLE(sys.odcivarchar2list(
    '1','2','3','29','36','38','40','41','42','43','44','49','50','52','54','56','57','58','61','62','64','65','69','72','73','74','76','77','82','83','85','87','88','89','108','110','111','112','113','118','125','128','132','133','135','136','141','147','149','151','155','156','158','164','172','173','176','177','178','181','186','188','189','191','192','193','194','198','199','200','206','210','213','215','222','235','300','331','342','353','357','361','423','520','544','566','901','908','1100','1125','1126','1127','1129','1132','1135','1136','1139','1143','1144','1146','1154','1155','1156','1177','1205','1207','1209','1211','1215','1218','1237','1367','1375','1385','1388','1392','1393','1394','1397','1400','1402','1403','1404','1405','1406','1407','1421'))
),
tal AS (
    SELECT u3.*, u1.fg_ativo, u1.fg_virtual,
           CASE WHEN rel.faz IS NULL THEN 'FORA' ELSE 'NO_RELATORIO' END AS grupo,
           (SELECT COUNT(*) FROM PIMS_CANA.QUEIMA_DE d
             WHERE d.cd_safra = u3.cd_safra AND d.cd_upnivel1 = u3.cd_upnivel1
               AND d.cd_upnivel2 = u3.cd_upnivel2 AND d.cd_upnivel3 = u3.cd_upnivel3) AS qtd_oc,
           (SELECT COUNT(*) FROM PIMS_CANA.HISTPREPRO h
             WHERE h.cd_safra = u3.cd_safra AND h.cd_upnivel1 = u3.cd_upnivel1
               AND h.cd_upnivel2 = u3.cd_upnivel2 AND h.cd_upnivel3 = u3.cd_upnivel3
               AND h.cd_hist = 'E') AS qtd_e
      FROM PIMS_CANA.UPNIVEL3 u3
      JOIN PIMS_CANA.UPNIVEL1 u1 ON u1.cd_upnivel1 = u3.cd_upnivel1
      LEFT JOIN rel ON rel.faz = TRIM(u3.cd_upnivel1)
     WHERE u1.instancia = '20'
       AND u3.cd_safra  = 2026
       AND EXISTS (SELECT 1 FROM PIMS_CANA.HISTPREPRO h
                    WHERE h.cd_safra = u3.cd_safra AND h.cd_upnivel1 = u3.cd_upnivel1
                      AND h.cd_upnivel2 = u3.cd_upnivel2 AND h.cd_upnivel3 = u3.cd_upnivel3
                      AND h.cd_hist = 'O')
)
SELECT grupo, fg_ativo, fg_virtual, cd_empresa, cd_unid_ind, cd_ocup, cd_sist_colh, cd_tp_propr,
       CASE WHEN qtd_oc > 0 THEN 'COM OC' ELSE 'SEM OC' END AS oc,
       CASE WHEN qtd_e  > 0 THEN 'COM E'  ELSE 'SEM E'  END AS hist_e,
       COUNT(*) AS talhoes, ROUND(SUM(qt_area_prod), 2) AS area
  FROM tal
 GROUP BY grupo, fg_ativo, fg_virtual, cd_empresa, cd_unid_ind, cd_ocup, cd_sist_colh, cd_tp_propr,
          CASE WHEN qtd_oc > 0 THEN 'COM OC' ELSE 'SEM OC' END,
          CASE WHEN qtd_e  > 0 THEN 'COM E'  ELSE 'SEM E'  END
 ORDER BY grupo, talhoes DESC
