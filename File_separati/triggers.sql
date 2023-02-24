-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:4306
-- Creato il: Feb 21, 2023 alle 10:37
-- Versione del server: 10.4.25-MariaDB
-- Versione PHP: 8.1.10

--
-- BELLAMACINA GIUSEPPE COSIMO ALFIO - 1000030349
--
SET FOREIGN_KEY_CHECKS=0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `dentistbase`
--

-- --------------------------------------------------------

--
-- Trigger `abilitazioni`
--
DELIMITER $$
CREATE TRIGGER `abilitazioni_INS_AbilitazioneControllo` AFTER INSERT ON `abilitazioni` FOR EACH ROW BEGIN
	IF ('Controllo'=(SELECT Tipo_Prestazione
                   FROM listaprestazioni
                   WHERE new.Abilitazione=Codice_Prestazione)) THEN
		DELETE FROM abilitazioni
		WHERE ID_Personale=new.ID_Personale
		AND Abilitazione=new.Abilitazione;
	END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `abilitazioni_UPD_AbilitazioneControllo` AFTER UPDATE ON `abilitazioni` FOR EACH ROW BEGIN
	IF ('Controllo'=(SELECT Tipo_Prestazione
                   FROM listaprestazioni
                   WHERE new.Abilitazione=Codice_Prestazione)) THEN
		DELETE FROM abilitazioni
		WHERE ID_Personale=new.ID_Personale
		AND Abilitazione=new.Abilitazione;
	END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Trigger `listaprestazioni`
--
DELIMITER $$
CREATE TRIGGER `listaprestazioni_INSValoreNegativo` BEFORE INSERT ON `listaprestazioni` FOR EACH ROW BEGIN
	IF new.Costo<0 THEN
    	SET new.Costo=0;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `listaprestazioni_UPDValoreNegativo` BEFORE UPDATE ON `listaprestazioni` FOR EACH ROW BEGIN
	IF new.Costo<0 THEN
    	SET new.Costo=0;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Trigger `pazienti`
--
DELIMITER $$
CREATE TRIGGER `pazienti_INSScontoEcc` BEFORE INSERT ON `pazienti` FOR EACH ROW BEGIN
	IF new.Sconto>1 THEN
    	SET new.Sconto=1;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `pazienti_UPDScontoEcc` BEFORE UPDATE ON `pazienti` FOR EACH ROW BEGIN
	IF new.Sconto>1 THEN
    	SET new.Sconto=1;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Trigger `personale`
--
DELIMITER $$
CREATE TRIGGER `personale_INSLimiteStipendio` BEFORE INSERT ON `personale` FOR EACH ROW BEGIN
	IF new.Stipendio>5000 THEN
    	SET new.Stipendio=5000;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `personale_UPDLimiteStipendio` BEFORE UPDATE ON `personale` FOR EACH ROW BEGIN
	IF new.Stipendio>5000 THEN
    	SET new.Stipendio=5000;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Trigger `pp`
--
DELIMITER $$
CREATE TRIGGER `AggiornaStipendioEQuota` BEFORE UPDATE ON `pp` FOR EACH ROW trig: BEGIN
	IF (SELECT Importo_Fattura
        FROM pp
        WHERE ID_PP=new.ID_PP) IS NOT NULL THEN
        	LEAVE trig;
    END IF;
    
	UPDATE specialisti
    SET Quota=Quota+new.Importo_Fattura, Stipendio=Stipendio+Quota*0.05
    WHERE ID=new.Specialista;
    
    UPDATE assistenti
    SET Quota=Quota+new.Importo_Fattura, Stipendio=Stipendio+Quota*0.05
    WHERE ID=new.Assistente;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `pp_INSAbilitazioneRichiesta` AFTER INSERT ON `pp` FOR EACH ROW BEGIN
	DECLARE tip varchar(11);
    
    SELECT Tipo_Prestazione INTO tip
    FROM listaprestazioni
    WHERE listaprestazioni.Codice_Prestazione=new.Codice_Prestazione;
    
    IF tip='Trattamento'
    AND NOT EXISTS (SELECT *
                    FROM abilitazioni, specialisti
                    WHERE abilitazioni.ID_Personale=specialisti.ID
                    AND specialisti.ID=new.Specialista) THEN
                    	DELETE FROM pp
                        WHERE ID_PP=new.ID_PP;
     ELSEIF tip='Controllo'
     AND EXISTS (SELECT *
                 FROM assistenti
                 WHERE assistenti.ID=new.Specialista) THEN
                 	DELETE FROM pp
                    WHERE ID_PP=new.ID_PP;
     ELSEIF tip='Trattamento'
     AND EXISTS (SELECT *
                 FROM specialisti
                 WHERE specialisti.ID=new.Assistente) THEN
                 	DELETE FROM pp
                    WHERE ID_PP=new.ID_PP;
     ELSEIF tip='Controllo'
     AND new.Assistente IS NOT NULL THEN
     	DELETE FROM pp
        WHERE ID_PP=new.ID_PP;
     END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `pp_INSPrenotazioneDalPassato` BEFORE INSERT ON `pp` FOR EACH ROW BEGIN
	IF new.Data<CURRENT_TIMESTAMP THEN
    	SET new.Data=CURRENT_TIMESTAMP;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `pp_INSStessoLuogoEOra` AFTER INSERT ON `pp` FOR EACH ROW BEGIN
	IF EXISTS (SELECT *
              FROM pp
              WHERE Stanza=new.Stanza
              AND ABS(TIMEDIFF(Data, new.Data))<10000
              AND ID_PP<>new.ID_PP) THEN
        DELETE FROM pp
        WHERE ID_PP=new.ID_PP;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `pp_INSStessoMedEOra` AFTER INSERT ON `pp` FOR EACH ROW BEGIN
	IF EXISTS (SELECT *
              FROM pp
              WHERE Specialista=new.Specialista
              AND ABS(TIMEDIFF(Data, new.Data))<10000
              AND ID_PP<>new.ID_PP) THEN
        DELETE FROM pp
        WHERE ID_PP=new.ID_PP;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `pp_UPDAbilitazioneRichiesta` BEFORE UPDATE ON `pp` FOR EACH ROW BEGIN
	DECLARE tip varchar(11);
    
    SELECT Tipo_Prestazione INTO tip
    FROM listaprestazioni
    WHERE listaprestazioni.Codice_Prestazione=new.Codice_Prestazione;
    
    IF tip='Trattamento'
    AND NOT EXISTS (SELECT *
                    FROM abilitazioni, specialisti
                    WHERE abilitazioni.ID_Personale=specialisti.ID
                    AND specialisti.ID=new.Specialista) THEN
                    	SET new.Specialista=old.Specialista;
     ELSEIF tip='Controllo'
     AND EXISTS (SELECT *
                 FROM assistenti
                 WHERE assistenti.ID=new.Specialista) THEN
                 	SET new.Specialista=old.Specialista;
     END IF;
     IF tip='Trattamento'
     AND EXISTS (SELECT *
                 FROM specialisti
                 WHERE specialisti.ID=new.Assistente) THEN
                 	SET new.Assistente=old.Assistente;
     ELSEIF tip='Controllo'
     AND new.Assistente IS NOT NULL THEN
     SET new.Assistente=old.Assistente;
     END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `pp_UPDPrenotazioneDalPassato` BEFORE UPDATE ON `pp` FOR EACH ROW BEGIN
	IF old.Data<>new.Data
    AND new.Data<CURRENT_TIMESTAMP THEN
    	SET new.Data=CURRENT_TIMESTAMP;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `pp_UPDStessoLuogoEOra` AFTER UPDATE ON `pp` FOR EACH ROW BEGIN
	IF EXISTS (SELECT *
              FROM pp
              WHERE Stanza=new.Stanza
              AND ABS(TIMEDIFF(Data, new.Data))<10000
              AND ID_PP<>new.ID_PP) THEN
        DELETE FROM pp
        WHERE ID_PP=new.ID_PP;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `pp_UPDStessoMedEOra` AFTER UPDATE ON `pp` FOR EACH ROW BEGIN
	IF EXISTS (SELECT *
              FROM pp
              WHERE Specialista=new.Specialista
              AND ABS(TIMEDIFF(Data, new.Data))<10000
              AND ID_PP<>new.ID_PP) THEN
        DELETE FROM pp
        WHERE ID_PP=new.ID_PP;
    END IF;
END
$$
DELIMITER ;


SET FOREIGN_KEY_CHECKS=1;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
