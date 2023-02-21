-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:4306
-- Creato il: Feb 21, 2023 alle 10:35
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

DELIMITER $$
--
-- Procedure
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `EffettuaPrenotazione` (IN `CodiceFiscale` VARCHAR(16), IN `CodicePrestazione` INT(8), IN `DataOra` DATETIME)   BEGIN
	DECLARE sta varchar(2);
    DECLARE tip varchar(11);
    DECLARE spe int(8);
    
    SELECT Tipo_Prestazione INTO tip
    FROM listaprestazioni
    WHERE CodicePrestazione=Codice_Prestazione;
    
    IF 'Controllo'=tip THEN
    	SELECT findStanza('Controllo', DataOra) INTO sta;
        SELECT findSpecialista('Controllo', CodicePrestazione, DataOra) INTO spe;
    ELSE
    	SELECT findStanza('Trattamento', DataOra) INTO sta;
        SELECT findSpecialista('Trattamento', CodicePrestazione, DataOra) INTO spe;
    END IF;
    
    SET FOREIGN_KEY_CHECKS=0;
    
    INSERT INTO pp (`ID_PP`, `Paziente`, `Codice_Prestazione`, `Data`, `Stanza`, `Specialista`, `Assistente`, `Esito`, `Importo_Fattura`) VALUES
(NULL, CodiceFiscale, CodicePrestazione, DataOra, sta, spe, NULL, NULL, NULL);
    
    SET FOREIGN_KEY_CHECKS=1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EffettuaPrestazione` (IN `Prenotazione` INT, IN `Esito` ENUM('OK','NECESSITA CONTROLLO','NECESSITA TRATTAMENTO'))   proc: BEGIN
	DECLARE paz varchar(16);
    DECLARE cod INT(8);
    DECLARE dat datetime;
    DECLARE sco FLOAT(8);
    DECLARE cost FLOAT(8);
    DECLARE ass INT(8);
    
    IF (SELECT pp.Esito
        FROM pp
        WHERE ID_PP=Prenotazione) IS NOT NULL THEN
    	LEAVE proc;
    END IF;
    
	SELECT Paziente, Codice_Prestazione, Data INTO paz, cod, dat
    FROM pp
    WHERE ID_PP=Prenotazione;
    
    SELECT Sconto INTO sco
    FROM pazienti
    WHERE CF=paz;
    
    SELECT Costo-Costo*sco INTO cost
    FROM listaprestazioni
    WHERE Codice_Prestazione=cod;
    
	IF 'Trattamento' = (SELECT Tipo_Prestazione FROM listaprestazioni WHERE Codice_Prestazione=cod) THEN
		SELECT findAssistente(cod, dat) INTO ass;
	ELSE
       	SET ass=NULL;
	END IF;
    
    SET FOREIGN_KEY_CHECKS=0;

	UPDATE pp
    SET pp.Assistente=ass, pp.Esito=Esito, pp.Importo_Fattura=cost
    WHERE ID_PP=Prenotazione;
    
    SET FOREIGN_KEY_CHECKS=1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `RipristinaStipendiEQuote` ()   BEGIN
	UPDATE personale
    SET Quota=0;
    
    UPDATE specialisti
    SET Stipendio=1500;
    
    UPDATE assistenti
    SET Stipendio=1000;
END$$

--
-- Funzioni
--
CREATE DEFINER=`root`@`localhost` FUNCTION `findAssistente` (`CodicePrestazione` INT(8), `DataOra` DATETIME) RETURNS INT(8)  BEGIN
	DECLARE ass int(8);
    SET lc_time_names = 'it_IT';
	SELECT ID INTO ass
        	FROM assistenti, abilitazioni
       		WHERE CodicePrestazione=Abilitazione
        	AND ID=ID_Personale
		AND NOT EXISTS (SELECT *
			FROM pp
			WHERE ID=Assistente
			AND ABS(TIMEDIFF(Data, DataOra))<10000)
            AND EXISTS (SELECT *
                FROM turni
                WHERE turni.ID_Personale=assistenti.ID
                AND Giorno=DAYNAME(DataOra))
     ORDER BY RAND()
     LIMIT 1;
	RETURN ass;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `findSpecialista` (`Tipo` VARCHAR(11), `CodicePrestazione` INT(8), `DataOra` DATETIME) RETURNS INT(8)  BEGIN
	DECLARE spe int(8);
    SET lc_time_names = 'it_IT';
	IF Tipo='Controllo' THEN
		SELECT ID INTO spe
        	FROM specialisti
		WHERE NOT EXISTS (SELECT *
			FROM pp
			WHERE ID=Specialista
			AND ABS(TIMEDIFF(Data, DataOra))<10000)
            AND EXISTS (SELECT *
                FROM turni
                WHERE turni.ID_Personale=specialisti.ID
                AND Giorno=DAYNAME(DataOra))
        	ORDER BY RAND()
        	LIMIT 1;
	ELSE
		SELECT ID INTO spe
        	FROM specialisti, abilitazioni
       		WHERE CodicePrestazione=Abilitazione
        	AND ID=ID_Personale
		AND NOT EXISTS (SELECT *
			FROM pp
			WHERE ID=Specialista
			AND ABS(TIMEDIFF(Data, DataOra))<10000)
            AND EXISTS (SELECT *
                FROM turni
                WHERE turni.ID_Personale=specialisti.ID
                AND Giorno=DAYNAME(DataOra))
        	ORDER BY RAND()
        	LIMIT 1;
	END IF;
	RETURN spe;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `findStanza` (`Tipo` VARCHAR(11), `DataOra` DATETIME) RETURNS VARCHAR(2) CHARSET utf8mb4  BEGIN
	IF Tipo='Controllo' THEN
		CASE
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='A1'
              			AND ABS(TIMEDIFF(Data, DataOra))<10000) THEN RETURN 'A1';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='A2'
              			AND ABS(TIMEDIFF(Data, DataOra))<10000) THEN RETURN 'A2';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='A3'
              			AND ABS(TIMEDIFF(Data, DataOra))<10000) THEN RETURN 'A3';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='A4'
              			AND ABS(TIMEDIFF(Data, DataOra))<10000) THEN RETURN 'A4';
			ELSE RETURN NULL;
		END CASE;
	ELSE
		CASE
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='B1'
              			AND ABS(TIMEDIFF(Data, DataOra))<10000) THEN RETURN 'B1';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='B2'
              			AND ABS(TIMEDIFF(Data, DataOra))<10000) THEN RETURN 'B2';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='B3'
              			AND ABS(TIMEDIFF(Data, DataOra))<10000) THEN RETURN 'B3';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='B4'
              			AND ABS(TIMEDIFF(Data, DataOra))<10000) THEN RETURN 'B4';
			ELSE RETURN NULL;
		END CASE;
	END IF;
END$$

DELIMITER ;
SET FOREIGN_KEY_CHECKS=1;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
