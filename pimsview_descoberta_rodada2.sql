/* =====================================================================
   LOCAIS A COLHER - DESCOBERTA RODADA 2  (somente SELECT)
   Já confirmado na rodada 1 (owner PIMS_CANA):
     UPNIVEL1  -> INSTANCIA, DE_UPNIVEL1
     UPNIVEL3  -> CD_SAFRA, CD_TP_PROPR, CD_MOD_ADM, CD_UNID_IND, CD_VARIED,
                  CD_ESTAGIO, DS_TERRA/DS_ASFALTO/DS_HIDROVIA, QT_AREA_PROD, QT_AREA_MUDA
     HISTPREPRO-> CD_HIST, DT_HISTORICO, QT_AREA_PROD, QT_TCH, QT_CANA_ENTR, QT_IDADE
     TIPOPROPRI, MODULOADM, VARIEDADES, ESTAGIOS, SAFRAS (descrições)
     QUEIMA_HE / QUEIMA_DE  -> Ordem de Corte (safra)
     OCORTEMD_HE / OCORTEMD_DE -> Ordem de Corte de Muda
   ===================================================================== */

-- A) Estrutura das tabelas de OC, reestimativa e período de safra
SELECT table_name, column_id, column_name, data_type, data_length
  FROM all_tab_columns
 WHERE owner = 'PIMS_CANA'
   AND table_name IN ('QUEIMA_HE','QUEIMA_DE','OCORTEMD_HE','OCORTEMD_DE',
                      'REESTIMAT','SAFRAS_PER','HISTQUEIMA')
 ORDER BY table_name, column_id;

-- B) Como o talhão está gravado (o filtro '14','15','23' não trouxe nada)
SELECT cd_safra, cd_upnivel1, '[' || cd_upnivel2 || ']' gleba, '[' || cd_upnivel3 || ']' talhao,
       qt_area_prod, qt_area_muda, cd_varied, cd_estagio, cd_tp_propr, cd_mod_adm, cd_unid_ind,
       ds_terra, ds_asfalto, ds_hidrovia
  FROM PIMS_CANA.UPNIVEL3
 WHERE cd_upnivel1 = '462276'
 ORDER BY cd_safra DESC, cd_upnivel2, cd_upnivel3;

-- C) Tipos de histórico da HISTPREPRO (estimativa / reestimativa / encerramento...)
SELECT cd_hist, COUNT(*) qtd, MIN(dt_historico) dt_min, MAX(dt_historico) dt_max
  FROM PIMS_CANA.HISTPREPRO
 GROUP BY cd_hist
 ORDER BY cd_hist;

-- D) Histórico da fazenda do exemplo
SELECT cd_hist, cd_safra, cd_upnivel2, cd_upnivel3, dt_historico, qt_area_prod, qt_tch,
       qt_cana_entr, qt_idade, cd_estagio, cd_varied, cd_proc_muda
  FROM PIMS_CANA.HISTPREPRO
 WHERE cd_upnivel1 = '462276'
 ORDER BY cd_safra DESC, cd_upnivel2, cd_upnivel3, dt_historico;

-- E) Cadastros auxiliares
SELECT * FROM PIMS_CANA.REESTIMAT;
SELECT * FROM PIMS_CANA.SAFRAS ORDER BY cd_safra DESC;
SELECT * FROM PIMS_CANA.SAFRAS_PER WHERE ROWNUM <= 30;

-- F) Ordens de corte (safra e muda) da fazenda do exemplo
SELECT h.*, d.*
  FROM PIMS_CANA.QUEIMA_HE h
  JOIN PIMS_CANA.QUEIMA_DE d ON d.no_queima = h.no_queima   -- se der erro de coluna, rode as 2 linhas abaixo
 WHERE d.cd_upnivel1 = '462276';
-- SELECT * FROM PIMS_CANA.QUEIMA_DE  WHERE cd_upnivel1 = '462276';
-- SELECT * FROM PIMS_CANA.QUEIMA_HE  WHERE ROWNUM <= 20 ORDER BY 1 DESC;

SELECT * FROM PIMS_CANA.OCORTEMD_DE WHERE cd_upnivel1 = '462276';
SELECT * FROM PIMS_CANA.OCORTEMD_HE WHERE ROWNUM <= 20;
