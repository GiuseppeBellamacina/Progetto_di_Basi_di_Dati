-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:4306
-- Creato il: Feb 26, 2023 alle 17:52
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
CREATE DATABASE IF NOT EXISTS `dentistbase` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `dentistbase`;

DELIMITER $$
--
-- Procedure
--
DROP PROCEDURE IF EXISTS `EffettuaPrenotazione`$$
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

DROP PROCEDURE IF EXISTS `EffettuaPrestazione`$$
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

DROP PROCEDURE IF EXISTS `EffettuaPrestazioniConCursore`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `EffettuaPrestazioniConCursore` ()   BEGIN
	DECLARE done BOOLEAN DEFAULT FALSE;
    DECLARE paz int(8);
    DECLARE cur CURSOR FOR(SELECT pp.ID_PP
                           FROM pp
                           WHERE pp.Data<CURRENT_TIMESTAMP
                           ORDER BY pp.Data);
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN cur;
    
	cursloop: LOOP
    	FETCH cur INTO paz;
        IF done THEN
        	LEAVE cursloop;
        END IF;
        CALL EffettuaPrestazione(paz,'OK');
    END LOOP cursloop;
        
	CLOSE cur;
END$$

DROP PROCEDURE IF EXISTS `RipristinaStipendiEQuote`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `RipristinaStipendiEQuote` ()   BEGIN
	UPDATE personale
    SET Quota=0;
    
    UPDATE specialisti
    SET Stipendio=2500;
    
    UPDATE assistenti
    SET Stipendio=1800;
END$$

--
-- Funzioni
--
DROP FUNCTION IF EXISTS `findAssistente`$$
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
			AND TIME_TO_SEC(ABS(TIMEDIFF(Data, DataOra)))<3600)
            AND EXISTS (SELECT *
                FROM turni
                WHERE turni.ID_Personale=assistenti.ID
                AND Giorno=DAYNAME(DataOra))
     ORDER BY RAND()
     LIMIT 1;
	RETURN ass;
END$$

DROP FUNCTION IF EXISTS `findSpecialista`$$
CREATE DEFINER=`root`@`localhost` FUNCTION `findSpecialista` (`Tipo` VARCHAR(11), `CodicePrestazione` INT(8), `DataOra` DATETIME) RETURNS INT(8)  BEGIN
	DECLARE spe int(8);
    SET lc_time_names = 'it_IT';
	IF Tipo='Controllo' THEN
		SELECT ID INTO spe
        	FROM specialisti
		WHERE NOT EXISTS (SELECT *
			FROM pp
			WHERE ID=Specialista
			AND TIME_TO_SEC(ABS(TIMEDIFF(Data, DataOra)))<3600)
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
			AND TIME_TO_SEC(ABS(TIMEDIFF(Data, DataOra)))<3600)
            AND EXISTS (SELECT *
                FROM turni
                WHERE turni.ID_Personale=specialisti.ID
                AND Giorno=DAYNAME(DataOra))
        	ORDER BY RAND()
        	LIMIT 1;
	END IF;
	RETURN spe;
END$$

DROP FUNCTION IF EXISTS `findStanza`$$
CREATE DEFINER=`root`@`localhost` FUNCTION `findStanza` (`Tipo` VARCHAR(11), `DataOra` DATETIME) RETURNS VARCHAR(2) CHARSET utf8mb4  BEGIN
	IF Tipo='Controllo' THEN
		CASE
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='A1'
              			AND TIME_TO_SEC(ABS(TIMEDIFF(Data, DataOra)))<3600) THEN RETURN 'A1';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='A2'
              			AND TIME_TO_SEC(ABS(TIMEDIFF(Data, DataOra)))<3600) THEN RETURN 'A2';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='A3'
              			AND TIME_TO_SEC(ABS(TIMEDIFF(Data, DataOra)))<3600) THEN RETURN 'A3';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='A4'
              			AND TIME_TO_SEC(ABS(TIMEDIFF(Data, DataOra)))<3600) THEN RETURN 'A4';
			ELSE RETURN NULL;
		END CASE;
	ELSE
		CASE
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='B1'
              			AND TIME_TO_SEC(ABS(TIMEDIFF(Data, DataOra)))<3600) THEN RETURN 'B1';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='B2'
              			AND TIME_TO_SEC(ABS(TIMEDIFF(Data, DataOra)))<3600) THEN RETURN 'B2';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='B3'
              			AND TIME_TO_SEC(ABS(TIMEDIFF(Data, DataOra)))<3600) THEN RETURN 'B3';
			WHEN NOT EXISTS (SELECT *
       				FROM pp
            			WHERE Stanza='B4'
              			AND TIME_TO_SEC(ABS(TIMEDIFF(Data, DataOra)))<3600) THEN RETURN 'B4';
			ELSE RETURN NULL;
		END CASE;
	END IF;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Struttura della tabella `abilitazioni`
--
-- Creazione: Feb 16, 2023 alle 10:15
-- Ultimo aggiornamento: Feb 25, 2023 alle 16:17
--

DROP TABLE IF EXISTS `abilitazioni`;
CREATE TABLE IF NOT EXISTS `abilitazioni` (
  `ID_Personale` int(8) NOT NULL,
  `Abilitazione` int(8) NOT NULL,
  UNIQUE KEY `Abilitazioni_fk2` (`ID_Personale`,`Abilitazione`),
  KEY `ID_Personale` (`ID_Personale`,`Abilitazione`),
  KEY `Abilitazioni_fk1` (`Abilitazione`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- RELAZIONI PER TABELLA `abilitazioni`:
--   `ID_Personale`
--       `personale` -> `ID`
--   `Abilitazione`
--       `listaprestazioni` -> `Codice_Prestazione`
--

--
-- Svuota la tabella prima dell'inserimento `abilitazioni`
--

TRUNCATE TABLE `abilitazioni`;
--
-- Dump dei dati per la tabella `abilitazioni`
--

INSERT INTO `abilitazioni` (`ID_Personale`, `Abilitazione`) VALUES
(1, 3),
(1, 4),
(1, 8),
(1, 10),
(1, 13),
(2, 3),
(2, 4),
(2, 8),
(2, 10),
(2, 13),
(3, 6),
(3, 14),
(4, 6),
(4, 14),
(5, 15),
(6, 15),
(7, 2),
(7, 5),
(8, 2),
(8, 5),
(9, 12),
(10, 12),
(11, 2),
(12, 2),
(13, 9),
(14, 9),
(15, 16),
(16, 16),
(17, 2),
(17, 5),
(18, 2),
(18, 5),
(19, 3),
(19, 4),
(20, 6),
(20, 8),
(21, 9),
(21, 10),
(22, 12),
(22, 13),
(23, 14),
(23, 15),
(24, 3),
(24, 16),
(25, 10),
(25, 14),
(26, 8),
(26, 9);

--
-- Trigger `abilitazioni`
--
DROP TRIGGER IF EXISTS `abilitazioni_INS_AbilitazioneControllo`;
DELIMITER $$
CREATE TRIGGER `abilitazioni_INS_AbilitazioneControllo` AFTER INSERT ON `abilitazioni` FOR EACH ROW BEGIN
	IF ('Controllo'=(SELECT Tipo_Prestazione
                   FROM listaprestazioni
                   WHERE new.Abilitazione=Codice_Prestazione)) THEN
		DELETE FROM abilitazioni
		WHERE ID_Personale=new.ID_Personale
		AND Abilitazione=new.Abilitazione;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Abilitazione non assegnabile';
	END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `abilitazioni_UPD_AbilitazioneControllo`;
DELIMITER $$
CREATE TRIGGER `abilitazioni_UPD_AbilitazioneControllo` AFTER UPDATE ON `abilitazioni` FOR EACH ROW BEGIN
	IF ('Controllo'=(SELECT Tipo_Prestazione
                   FROM listaprestazioni
                   WHERE new.Abilitazione=Codice_Prestazione)) THEN
		DELETE FROM abilitazioni
		WHERE ID_Personale=new.ID_Personale
		AND Abilitazione=new.Abilitazione;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Abilitazione non assegnabile';
	END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struttura stand-in per le viste `assistenti`
-- (Vedi sotto per la vista effettiva)
--
DROP VIEW IF EXISTS `assistenti`;
CREATE TABLE IF NOT EXISTS `assistenti` (
`ID` int(8)
,`Cognome` varchar(30)
,`Nome` varchar(30)
,`Recapito` varchar(13)
,`E-mail` varchar(50)
,`Stipendio` float
,`Quota` float
);

-- --------------------------------------------------------

--
-- Struttura stand-in per le viste `controlli`
-- (Vedi sotto per la vista effettiva)
--
DROP VIEW IF EXISTS `controlli`;
CREATE TABLE IF NOT EXISTS `controlli` (
`Codice_Prestazione` int(8)
,`Nome_Prestazione` varchar(30)
,`Costo` float
);

-- --------------------------------------------------------

--
-- Struttura della tabella `listaprestazioni`
--
-- Creazione: Feb 16, 2023 alle 10:15
-- Ultimo aggiornamento: Feb 25, 2023 alle 16:17
--

DROP TABLE IF EXISTS `listaprestazioni`;
CREATE TABLE IF NOT EXISTS `listaprestazioni` (
  `Codice_Prestazione` int(8) NOT NULL AUTO_INCREMENT,
  `Nome_Prestazione` varchar(30) NOT NULL,
  `Tipo_Prestazione` enum('Controllo','Trattamento') NOT NULL,
  `Costo` float NOT NULL,
  PRIMARY KEY (`Codice_Prestazione`) USING BTREE,
  UNIQUE KEY `Nome` (`Nome_Prestazione`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4;

--
-- RELAZIONI PER TABELLA `listaprestazioni`:
--

--
-- Svuota la tabella prima dell'inserimento `listaprestazioni`
--

TRUNCATE TABLE `listaprestazioni`;
--
-- Dump dei dati per la tabella `listaprestazioni`
--

INSERT INTO `listaprestazioni` (`Codice_Prestazione`, `Nome_Prestazione`, `Tipo_Prestazione`, `Costo`) VALUES
(1, 'Visita Generale', 'Controllo', 60),
(2, 'Rimozione Carie', 'Trattamento', 150),
(3, 'Istallazione Apparecchio', 'Trattamento', 3500),
(4, 'Rimozione Apparecchio', 'Trattamento', 200),
(5, 'Devitalizzazione', 'Trattamento', 180),
(6, 'Sbiancamento', 'Trattamento', 300),
(7, 'Controllo Stato Apparecchio', 'Controllo', 60),
(8, 'Riparazione Apparecchio', 'Trattamento', 200),
(9, 'Terapia Ortognatodontica', 'Trattamento', 200),
(10, 'Sostituzione Dente', 'Trattamento', 1500),
(11, 'Analisi per Protesi Dentaria', 'Controllo', 150),
(12, 'Protesi Dentaria', 'Trattamento', 600),
(13, 'Impianto Completo', 'Trattamento', 22000),
(14, 'Pulizia Dentale', 'Trattamento', 90),
(15, 'Ricostruzione Parodonto', 'Trattamento', 300),
(16, 'Terapia Gnatologica', 'Trattamento', 250);

--
-- Trigger `listaprestazioni`
--
DROP TRIGGER IF EXISTS `listaprestazioni_INSValoreNegativo`;
DELIMITER $$
CREATE TRIGGER `listaprestazioni_INSValoreNegativo` BEFORE INSERT ON `listaprestazioni` FOR EACH ROW BEGIN
	IF new.Costo<0 THEN
    	SET new.Costo=0;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Prezzo inferiore a 0';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `listaprestazioni_UPDValoreNegativo`;
DELIMITER $$
CREATE TRIGGER `listaprestazioni_UPDValoreNegativo` BEFORE UPDATE ON `listaprestazioni` FOR EACH ROW BEGIN
	IF new.Costo<0 THEN
    	SET new.Costo=0;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Prezzo inferiore a 0';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struttura della tabella `pazienti`
--
-- Creazione: Feb 17, 2023 alle 10:40
-- Ultimo aggiornamento: Feb 25, 2023 alle 16:17
--

DROP TABLE IF EXISTS `pazienti`;
CREATE TABLE IF NOT EXISTS `pazienti` (
  `CF` varchar(16) NOT NULL,
  `Cognome` varchar(30) NOT NULL,
  `Nome` varchar(30) NOT NULL,
  `Data_Nascita` date NOT NULL,
  `Genere` enum('M','F') DEFAULT NULL,
  `Recapito` varchar(13) NOT NULL,
  `E-mail` varchar(50) DEFAULT NULL,
  `Sconto` float NOT NULL DEFAULT 0,
  PRIMARY KEY (`CF`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- RELAZIONI PER TABELLA `pazienti`:
--

--
-- Svuota la tabella prima dell'inserimento `pazienti`
--

TRUNCATE TABLE `pazienti`;
--
-- Dump dei dati per la tabella `pazienti`
--

INSERT INTO `pazienti` (`CF`, `Cognome`, `Nome`, `Data_Nascita`, `Genere`, `Recapito`, `E-mail`, `Sconto`) VALUES
('BBRCLL77M06E667V', 'Abbrescia', 'Catello', '1977-08-06', 'M', '3004684984', 'catello.abbrescia@alice.it', 0),
('BBRRNL00D57E783T', 'Abbruzzesi', 'Reginella', '2000-04-17', 'F', '3855425808', 'NULL', 0.1),
('BBTMSM06M65H384W', 'Abbatelli', 'Massimiliana', '2006-08-25', 'F', '3285632586', 'massimiliana.abbatelli@virgilio.it', 0.05),
('BCCDIA69E64F316B', 'Biccarino', 'Ida', '1969-05-24', 'F', '3607196124', 'NULL', 0),
('BCCFNC00D56I697H', 'Bacchini', 'Francesca', '2000-04-16', 'F', '3684183191', 'francesca.bacchini@outlook.it', 0),
('BCCGAI42H60L206K', 'Buccino', 'Gaia', '1942-06-20', 'F', '3949131033', 'NULL', 0.15),
('BCCGMN68E58F304R', 'Bacchino', 'Germana', '1968-05-18', 'F', '3822190474', 'NULL', 0),
('BCCGND76A04F776J', 'Boccanera', 'Giocondo', '1976-01-04', 'M', '3516616789', 'NULL', 0.05),
('BCCLCU58L07L046M', 'Buccella', 'Lucio', '1958-07-07', 'M', '3910420130', 'NULL', 0.2),
('BCCLTR08H48H205T', 'Bacco', 'Elettra', '2008-06-08', 'F', '3338607470', 'NULL', 0),
('BCCMRN61S53D348J', 'Baccigaluppi', 'Marina', '1961-11-13', 'F', '3615329722', 'NULL', 0),
('BCCNTA82T61F186Z', 'Boiocchi', 'Anita', '1982-12-21', 'F', '3689626611', 'NULL', 0),
('BCCNTS52T42L500L', 'Baiocchini', 'Anastasia', '1952-12-02', 'F', '3750880371', 'anastasia.baiocchini@gmail.com', 0),
('BCCWND03R56C300Q', 'Boccalini', 'Wanda', '2003-10-16', 'F', '3053935694', 'NULL', 0),
('BCGPPP02D62C587H', 'Bicego', 'Peppa', '2002-04-22', 'F', '3352456407', 'NULL', 0.25),
('BCHLVR05L31A942W', 'Bochicchio', 'Alvaro', '2005-07-31', 'M', '3727492405', 'NULL', 0),
('BCHPLA59H55C381I', 'Bochicchio', 'Paola', '1959-06-15', 'F', '3150383779', 'NULL', 0),
('BCOMMM68S12H985P', 'Boca', 'Mimmo', '1968-11-12', 'M', '3412691303', 'mimmo.boca@outlook.it', 0.3),
('BDLRMN89D66G783T', 'Badolato', 'Romana', '1989-04-26', 'F', '3581192979', 'NULL', 0),
('BDLSVS90L09A557E', 'Badalato', 'Silvestro', '1990-07-09', 'M', '3201838088', 'NULL', 0),
('BDSRML41T04H429D', 'Badesso', 'Romolo', '1941-12-04', 'M', '3987548418', 'NULL', 0),
('BFFCRL08C70E922P', 'Boffi', 'Carola', '2008-03-30', 'F', '3006773048', 'NULL', 0),
('BFLTNI40E50I255H', 'Bifolchi', 'Tina', '1940-05-10', 'F', '3414226540', 'NULL', 0),
('BGGRRT01H44I968V', 'Baggio', 'Roberta', '2001-06-04', 'F', '3160984437', 'NULL', 0),
('BGLGBR47A18H501M', 'Baglio', 'Gilberto', '1947-01-18', 'M', '3377435824', 'NULL', 0.15),
('BGLLSN41R29H017J', 'Baglieri', 'Alessandro', '1941-10-29', 'M', '3827329612', 'NULL', 0),
('BGLPRZ96T29H096Y', 'Baglieri', 'Patrizio', '1996-12-29', 'M', '3511193715', 'NULL', 0.1),
('BGNFRZ87T55E546C', 'Bignami', 'Fabrizia', '1987-12-15', 'F', '3055296870', 'NULL', 0.2),
('BGNLNE44E70H919L', 'Bignotti', 'Eliana', '1944-05-30', 'F', '3804108553', 'NULL', 0.15),
('BGNMME07A51F013K', 'Bagnato', 'Emma', '2007-01-11', 'F', '3747530235', 'NULL', 0.05),
('BGNVLM88A54H348M', 'Bignardelli', 'Vilma', '1988-01-14', 'F', '3829587772', 'NULL', 0),
('BGRMMM13H30B645J', 'Bigarani', 'Mimmo', '2013-06-30', 'M', '3698838952', 'NULL', 0),
('BGRVGN14M69C529U', 'Baiguera', 'Virginia', '2014-08-29', 'F', '3919256888', 'NULL', 0),
('BGTFNZ77M48H900I', 'Bagat', 'Fiorenza', '1977-08-08', 'F', '3751886365', 'NULL', 0),
('BGZLHN79D06D509Z', 'Bigozzi', 'Luchino', '1979-04-06', 'M', '3541969058', 'NULL', 0),
('BIAMRN98L41C655K', 'Bia', 'Marina', '1998-07-01', 'F', '3912173337', 'marina.bia@gmail.com', 0),
('BLCCRL44H17C548T', 'Balocco', 'Carlo', '1944-06-17', 'M', '3855421313', 'NULL', 0),
('BLCLNE94P19M313Y', 'Belcastro', 'Leone', '1994-09-19', 'M', '3266172205', 'NULL', 0),
('BLCRSR45M43L474L', 'Balcon', 'Rosaria', '1945-08-03', 'F', '3418086652', 'NULL', 0.05),
('BLDFRC15S10C166X', 'Baldanzi', 'Federico', '2015-11-10', 'M', '3996309137', 'federico.baldanzi@virgilio.it', 0.1),
('BLDGUO66D16C270J', 'Baldolini', 'Ugo', '1966-04-16', 'M', '3416292109', 'NULL', 0),
('BLDLRC10H29H736R', 'Baldessarri', 'Alarico', '2010-06-29', 'M', '3593323664', 'NULL', 0),
('BLDMRN91E53B857G', 'Baldazzi', 'Marina', '1991-05-13', 'F', '3169183661', 'marina.baldazzi@gmail.com', 0),
('BLDRMI66A62B609B', 'Bledig', 'Irma', '1966-01-22', 'F', '3880089628', 'irma.bledig@outlook.it', 0),
('BLDRND79A11B346J', 'Baldassarre', 'Orlando', '1979-01-11', 'M', '3012745047', 'orlando.baldassarre@pec.it', 0),
('BLDSML69P67A208J', 'Baldessare', 'Samuela', '1969-09-27', 'F', '3109716700', 'NULL', 0.15),
('BLDVTR40T22D630S', 'Ubaldi', 'Vittoriano', '1940-12-22', 'M', '3202524890', 'NULL', 0),
('BLFFBA92H15E793Q', 'Belforti', 'Fabio', '1992-06-15', 'M', '3460568912', 'NULL', 0.3),
('BLFLPA82E04L551C', 'Belforti', 'Lapo', '1982-05-04', 'M', '3526821472', 'NULL', 0),
('BLFVGN62A57F286Q', 'Belfort', 'Virginia', '1962-01-17', 'F', '3785328154', 'NULL', 0),
('BLGRLN90T46H540J', 'Bulgarelli', 'Rosalina', '1990-12-06', 'F', '3579758140', 'NULL', 0),
('BLGRNL57R17B424L', 'Buluggiu', 'Reginaldo', '1957-10-17', 'M', '3667374640', 'reginaldo.buluggiu@outlook.it', 0),
('BLLCSS79E30D309N', 'Bellomini', 'Cassio', '1979-05-30', 'M', '3711288949', 'NULL', 0),
('BLLDBR54H53B142N', 'Bellisario', 'Debora', '1954-06-13', 'F', '3360490401', 'NULL', 0),
('BLLDNT58B58A914D', 'Belli', 'Donata', '1958-02-18', 'F', '3224277571', 'NULL', 0),
('BLLPQL61T18D868O', 'Bellini', 'Pasquale', '1961-12-18', 'M', '3925891914', 'NULL', 0),
('BLLRLA41B19G618F', 'Bellaria', 'Aurelio', '1941-02-19', 'M', '3494358117', 'NULL', 0),
('BLLRMR02P70I053Y', 'Bellani', 'Rosamaria', '2002-09-30', 'F', '3383622791', 'NULL', 0),
('BLLRNI77H04H931L', 'Balloi', 'Rino', '1977-06-04', 'M', '3119652069', 'NULL', 0.1),
('BLLRST55L42E351G', 'Belluomini', 'Ernesta', '1955-07-02', 'F', '3031751402', 'NULL', 0),
('BLMNTL51H16L187U', 'Belmessieri', 'Natale', '1951-06-16', 'M', '3818822358', 'NULL', 0),
('BLNFPP72A63L323K', 'Blando', 'Filippa', '1972-01-23', 'F', '3830825697', 'NULL', 0.2),
('BLNMLD78D65H796T', 'Bailone', 'Mafalda', '1978-04-25', 'F', '3912897872', 'mafalda.bailone@outlook.it', 0.15),
('BLOVTT46M58D508M', 'Bolia', 'Violetta', '1946-08-18', 'F', '3919833281', 'NULL', 0),
('BLRNZR44H29D218X', 'Belardo', 'Nazzareno', '1944-06-29', 'M', '3869233405', 'NULL', 0),
('BLSFBN50C67G870L', 'Balestrini', 'Fabiana', '1950-03-27', 'F', '3190503247', 'NULL', 0.2),
('BLSMDL83S42F029V', 'Balestro', 'Maddalena', '1983-11-02', 'F', '3717060346', 'NULL', 0),
('BLSRKE06S48H393O', 'Balestri', 'Erika', '2006-11-08', 'F', '3597235209', 'NULL', 0.2),
('BLSZOE99B56I614Q', 'Blasio', 'Zoe', '1999-02-16', 'F', '3929555897', 'NULL', 0),
('BLTDRN11S67D072X', 'Blaiotta', 'Adriana', '2011-11-27', 'F', '3973761973', 'NULL', 0.05),
('BLTLND90B13G318R', 'Beltrano', 'Lindo', '1990-02-13', 'M', '3316982851', 'NULL', 0.1),
('BLTTLL63T13E695K', 'Beltrama', 'Otello', '1963-12-13', 'M', '3666612344', 'NULL', 0.2),
('BLVYLO62P69D208H', 'Balivo', 'Yole', '1962-09-29', 'F', '3925769425', 'yole.balivo@outlook.it', 0.1),
('BLZVSC48S29C975I', 'Bolzon', 'Vasco', '1948-11-29', 'M', '3347355930', 'vasco.bolzon@outlook.it', 0.3),
('BMBCLD99R27E299N', 'Bomboi', 'Claudio', '1999-10-27', 'M', '3319752359', 'NULL', 0.15),
('BMBGTV14A51H708C', 'Bambino', 'Gustava', '2014-01-11', 'F', '3255986749', 'gustava.bambino@virgilio.it', 0.2),
('BMBMRN44T29A297W', 'Bombardiere', 'Moreno', '1944-12-29', 'M', '3830391384', 'NULL', 0.1),
('BMNSVN76T61E202A', 'Biamonti', 'Silvana', '1976-12-21', 'F', '3202437540', 'NULL', 0.2),
('BNCLNS05B21I165Y', 'Bianco', 'Alfonsino', '2005-02-21', 'M', '3400857264', 'NULL', 0),
('BNCLNZ84T30C638Y', 'Benacchio', 'Lorenzo', '1984-12-30', 'M', '3076746978', 'NULL', 0.15),
('BNCMBR00L53G123B', 'Benacchio', 'Ambra', '2000-07-13', 'F', '3709135313', 'NULL', 0.15),
('BNCMCL62H70A823M', 'Biancalana', 'Marcella', '1962-06-30', 'F', '3098714578', 'NULL', 0.15),
('BNDBDT56T46F524Y', 'Benedetto', 'Benedetta', '1956-12-06', 'F', '3702996112', 'NULL', 0.05),
('BNDDLC71A44D812L', 'Bondi', 'Doralice', '1971-01-04', 'F', '3539026400', 'NULL', 0),
('BNDLCU50C15A259P', 'Buonadonna', 'Lucio', '1950-03-15', 'M', '3003776878', 'lucio.buonadonna@alice.it', 0),
('BNFFST83H50F458P', 'Bonfratello', 'Fausta', '1983-06-10', 'F', '3570841370', 'NULL', 0),
('BNFLNZ65R54M002M', 'Benfenati', 'Lorenza', '1965-10-14', 'F', '3685194830', 'lorenza.benfenati@pec.it', 0),
('BNFLRG43P10G187V', 'Bonafide', 'Alberigo', '1943-09-10', 'M', '3678116189', 'NULL', 0.05),
('BNFMGH85B52C918H', 'Benfenati', 'Margherita', '1985-02-12', 'F', '3585995134', 'NULL', 0.2),
('BNFNLC04T54B932E', 'Bonforti', 'Angelica', '2004-12-14', 'F', '3215062741', 'NULL', 0),
('BNFNRC09T51L733M', 'Bonifaci', 'Enrica', '2009-12-11', 'F', '3538387106', 'enrica.bonifaci@virgilio.it', 0.2),
('BNFSMN65S20G978H', 'Benfanti', 'Simone', '1965-11-20', 'M', '3122106716', 'NULL', 0),
('BNFSNO06L61L450R', 'Benfanti', 'Sonia', '2006-07-21', 'F', '3319312100', 'NULL', 0),
('BNGCCL62R03G317F', 'Binago', 'Cecilio', '1962-10-03', 'M', '3857327296', 'NULL', 0.3),
('BNGMRN95A19A632D', 'Bongiorni', 'Marino', '1995-01-19', 'M', '3957082659', 'NULL', 0),
('BNLSRG06B12D407N', 'Banelli', 'Sergio', '2006-02-12', 'M', '3369217454', 'NULL', 0),
('BNMLDA80P64L970W', 'Buonamici', 'Alda', '1980-09-24', 'F', '3651272422', 'NULL', 0),
('BNMMDL07S66A848O', 'Bonamico', 'Maddalena', '2007-11-26', 'F', '3833587042', 'NULL', 0.1),
('BNNBND54S09G865V', 'Benini', 'Abbondio', '1954-11-09', 'M', '3395002268', 'NULL', 0),
('BNNDLF85P12E338H', 'Benino', 'Adolfo', '1985-09-12', 'M', '3634893516', 'adolfo.benino@pec.it', 0.3),
('BNNDTT49A47E207F', 'Beninca', 'Diletta', '1949-01-07', 'F', '3344253300', 'diletta.beninca@virgilio.it', 0),
('BNNFDR11C19B993Y', 'Bonincontro', 'Fedro', '2011-03-19', 'M', '3465343668', 'NULL', 0),
('BNNGLL62C51D566O', 'Benenato', 'Gisella', '1962-03-11', 'F', '3286678541', 'NULL', 0.15),
('BNNLDA14A28H159G', 'Bonincontro', 'Aldo', '2014-01-28', 'M', '3839295072', 'NULL', 0),
('BNNLRC89T25F114W', 'Benincà', 'Alberico', '1989-12-25', 'M', '3572888685', 'NULL', 0),
('BNNWLM65C68G084P', 'Benini', 'Wilma', '1965-03-28', 'F', '3166097078', 'wilma.benini@pec.it', 0),
('BNRGVF97R65M317E', 'Bonardi', 'Genoveffa', '1997-10-25', 'F', '3213556648', 'NULL', 0.05),
('BNRLNZ09T64G476X', 'Bonarrota', 'Lorenza', '2009-12-24', 'F', '3459767504', 'lorenza.bonarrota@virgilio.it', 0),
('BNRLRD77D25C094G', 'Bonura', 'Leonardo', '1977-04-25', 'M', '3192272562', 'NULL', 0),
('BNRNLN12H28E492O', 'Boniardi', 'Napoleone', '2012-06-28', 'M', '3130946775', 'napoleone.boniardi@outlook.it', 0),
('BNSGTN12S50B787R', 'Benussi', 'Gaetana', '2012-11-10', 'F', '3016491967', 'gaetana.benussi@alice.it', 0.25),
('BNTDLM73D24H818A', 'Bonato', 'Adelmo', '1973-04-24', 'M', '3189149803', 'NULL', 0),
('BNTFLV74R05E626F', 'Bontempo', 'Flavio', '1974-10-05', 'M', '3889673281', 'NULL', 0),
('BNTFNC73D52C860P', 'Bonaiuti', 'Francesca', '1973-04-12', 'F', '3494491823', 'NULL', 0),
('BNTMDE63H06F220J', 'Bontempo', 'Emidio', '1963-06-06', 'M', '3787156451', 'NULL', 0),
('BNTNBR04D05B143Q', 'Bonato', 'Norberto', '2004-04-05', 'M', '3987246326', 'norberto.bonato@alice.it', 0),
('BNTTVN02L17C323I', 'Bonitatibus', 'Ottaviano', '2002-07-17', 'M', '3017531828', 'NULL', 0.3),
('BNVLCN76H58D054E', 'Bonavite', 'Luciana', '1976-06-18', 'F', '3901180700', 'NULL', 0.25),
('BNVLNE94D66D100L', 'Benivento', 'Eliana', '1994-04-26', 'F', '3346873843', 'eliana.benivento@alice.it', 0),
('BNVMMI70P61D086K', 'Buonavita', 'Imma', '1970-09-21', 'F', '3317949554', 'NULL', 0),
('BNVMTT61S07H423I', 'Benevento', 'Matteo', '1961-11-07', 'M', '3557510896', 'NULL', 0),
('BOIPRZ43R30E602Z', 'Boi', 'Patrizio', '1943-10-30', 'M', '3307255710', 'NULL', 0),
('BRBCLD06S18F562Q', 'Brabanti', 'Cataldo', '2006-11-18', 'M', '3428550179', 'NULL', 0.3),
('BRBDRA77T04I363Z', 'Barbata', 'Dario', '1977-12-04', 'M', '3450658630', 'NULL', 0),
('BRBGLD71C06L316Y', 'Barbanera', 'Gildo', '1971-03-06', 'M', '3029336533', 'NULL', 0),
('BRBGMN14D30C725Z', 'Barbagalli', 'Germano', '2014-04-30', 'M', '3164788067', 'germano.barbagalli@gmail.com', 0),
('BRBLHN55C07G811U', 'Barbarini', 'Luchino', '1955-03-07', 'M', '3324281342', 'NULL', 0),
('BRBMRZ79T67H424W', 'Barbarossa', 'Marzia', '1979-12-27', 'F', '3535467962', 'NULL', 0),
('BRBMSM46S46E292S', 'Barbuto', 'Massima', '1946-11-06', 'F', '3934112559', 'massima.barbuto@outlook.it', 0),
('BRBPCC10M08F152N', 'Barbosa', 'Pinuccio', '2010-08-08', 'M', '3353630412', 'NULL', 0),
('BRBRMR76B62E667P', 'Barban', 'Rosamaria', '1976-02-22', 'F', '3708418776', 'NULL', 0),
('BRBRNN01L58L643E', 'Barbazzi', 'Rosanna', '2001-07-18', 'F', '3604411762', 'NULL', 0),
('BRBVVN75A49G050S', 'Barbisotti', 'Viviana', '1975-01-09', 'F', '3618817877', 'NULL', 0),
('BRBWNN98S59D292F', 'Barbosa', 'Wanna', '1998-11-19', 'F', '3105660032', 'NULL', 0),
('BRCBNC62R59M317D', 'Baracca', 'Bianca', '1962-10-19', 'F', '3317515326', 'NULL', 0),
('BRCCSR91C18A177U', 'Barcelli', 'Cesare', '1991-03-18', 'M', '3254377691', 'cesare.barcelli@outlook.it', 0),
('BRCNRN52T58A488P', 'Bricca', 'Andreina', '1952-12-18', 'F', '3771721061', 'NULL', 0),
('BRCSFN50H45D554N', 'Boracchi', 'Serafina', '1950-06-05', 'F', '3849492951', 'serafina.boracchi@outlook.it', 0),
('BRCSTN79D56G529G', 'Barichello', 'Sabatina', '1979-04-16', 'F', '3319232348', 'NULL', 0),
('BRDCNL93R49B725R', 'Bordoni', 'Cornelia', '1993-10-09', 'F', '3789770174', 'NULL', 0),
('BRDDRS66C44D756C', 'Bordino', 'Doris', '1966-03-04', 'F', '3275127599', 'NULL', 0.15),
('BRDLDN14D10D468B', 'Bardino', 'Aldino', '2014-04-10', 'M', '3647870899', 'NULL', 0),
('BRDMMM59E64M127N', 'Baiardo', 'Mimma', '1959-05-24', 'F', '3926495065', 'mimma.baiardo@virgilio.it', 0),
('BRDNTS64L17I165H', 'Bardari', 'Anastasio', '1964-07-17', 'M', '3157247600', 'anastasio.bardari@alice.it', 0),
('BRDVNT05B42I595M', 'Bordin', 'Violante', '2005-02-02', 'F', '3203137273', 'NULL', 0),
('BRDZEI59T31H421T', 'Bardella', 'Ezio', '1959-12-31', 'M', '3887417614', 'ezio.bardella@pec.it', 0),
('BRFCML03M18F336D', 'Barufaldi', 'Carmelo', '2003-08-18', 'M', '3314736012', 'carmelo.barufaldi@virgilio.it', 0),
('BRFCRL72M48D569Y', 'Baruffi', 'Carla', '1972-08-08', 'F', '3746438027', 'NULL', 0),
('BRGCRL07A69E245L', 'Borghino', 'Carla', '2007-01-29', 'F', '3592845379', 'NULL', 0),
('BRGDLB15E66B288E', 'Bergamasco', 'Doralba', '2015-05-26', 'F', '3593230350', 'doralba.bergamasco@gmail.com', 0),
('BRGFDN93C15I558P', 'Borgna', 'Ferdinando', '1993-03-15', 'M', '3064108678', 'NULL', 0),
('BRGFRZ07T01E596D', 'Borgatello', 'Fabrizio', '2007-12-01', 'M', '3649982887', 'fabrizio.borgatello@gmail.com', 0),
('BRGFRZ14L23H481H', 'Broggin', 'Fabrizio', '2014-07-23', 'M', '3754793885', 'NULL', 0.15),
('BRGGRL65P10H182Y', 'Braga', 'Gabriele', '1965-09-10', 'M', '3952918135', 'gabriele.braga@outlook.it', 0),
('BRGMSM83M14A918D', 'Bragaglia', 'Massimiliano', '1983-08-14', 'M', '3503823335', 'NULL', 0),
('BRGNTL75A65E682O', 'Borghini', 'Natalia', '1975-01-25', 'F', '3195043962', 'NULL', 0.15),
('BRGRSO49P57H189Y', 'Brigo', 'Rosa', '1949-09-17', 'F', '3972386716', 'NULL', 0),
('BRGSRG55D30F509C', 'Burgo', 'Sergio', '1955-04-30', 'M', '3518949856', 'sergio.burgo@outlook.it', 0.05),
('BRLBND09P05H404S', 'Baral', 'Abbondio', '2009-09-05', 'M', '3219463460', 'NULL', 0),
('BRLCNL65T48G729B', 'Baroli', 'Cornelia', '1965-12-08', 'F', '3288680679', 'cornelia.baroli@outlook.it', 0),
('BRLDRO52D67A413E', 'Burlandi', 'Doria', '1952-04-27', 'F', '3701053127', 'NULL', 0),
('BRLFDR57H67D671F', 'Berlingero', 'Fedora', '1957-06-27', 'F', '3352484969', 'NULL', 0.15),
('BRLFRZ44B11H258F', 'Barale', 'Fabrizio', '1944-02-11', 'M', '3138578183', 'fabrizio.barale@virgilio.it', 0.2),
('BRLGIA40B07B727F', 'Berlocco', 'Iago', '1940-02-07', 'M', '3251356260', 'iago.berlocco@virgilio.it', 0),
('BRLLDN78L70L899T', 'Barla', 'Loredana', '1978-07-30', 'F', '3926105269', 'NULL', 0.25),
('BRLLIO90S56E707A', 'Borlini', 'Iole', '1990-11-16', 'F', '3041008457', 'NULL', 0.3),
('BRLLNZ66M02D685E', 'Barillaro', 'Lorenzo', '1966-08-02', 'M', '3670979461', 'lorenzo.barillaro@gmail.com', 0),
('BRLMLE74A51E543S', 'Berlangeri', 'Emilia', '1974-01-11', 'F', '3189561524', 'NULL', 0),
('BRLNLN97M13C660Z', 'Birollo', 'Angelino', '1997-08-13', 'M', '3420517741', 'NULL', 0),
('BRLPML67A46H501X', 'Barilari', 'Pamela', '1967-01-06', 'F', '3320434294', 'NULL', 0),
('BRLRZO66B10I632Z', 'Barilà', 'Orazio', '1966-02-10', 'M', '3540976173', 'NULL', 0),
('BRLSDR81S19A093E', 'Borlini', 'Sandro', '1981-11-19', 'M', '3889742805', 'NULL', 0),
('BRLZEI52M18L720R', 'Borlando', 'Ezio', '1952-08-18', 'M', '3139141650', 'NULL', 0),
('BRLZRA52A51C471P', 'Barlassina', 'Zaira', '1952-01-11', 'F', '3485995623', 'zaira.barlassina@pec.it', 0),
('BRMLDA79C21F414G', 'Bormolini', 'Aldo', '1979-03-21', 'M', '3998287595', 'NULL', 0),
('BRMLSN06M23D683I', 'Brambati', 'Alessandro', '2006-08-23', 'M', '3419683591', 'NULL', 0),
('BRMRNT68E22D965R', 'Abram', 'Renato', '1968-05-22', 'M', '3754229081', 'NULL', 0.1),
('BRNBRC56L51A845I', 'Barni', 'Beatrice', '1956-07-11', 'F', '3439260730', 'NULL', 0.05),
('BRNCRN49M57G822U', 'Bernuzzi', 'Caterina', '1949-08-17', 'F', '3241224257', 'NULL', 0.2),
('BRNFRS14E43D273K', 'Burani', 'Eufrasia', '2014-05-03', 'F', '3668054803', 'NULL', 0.25),
('BRNGBB66D21F595K', 'Branco', 'Giacobbe', '1966-04-21', 'M', '3987623164', 'giacobbe.branco@virgilio.it', 0.1),
('BRNGNZ80S03L123Q', 'Brancaforte', 'Ignazio', '1980-11-03', 'M', '3468604432', 'NULL', 0.15),
('BRNLND68A13D399N', 'Brun', 'Leonida', '1968-01-13', 'M', '3485532462', 'NULL', 0.15),
('BRNLRT45E04B550X', 'Brunozzi', 'Alberto', '1945-05-04', 'M', '3998833048', 'NULL', 0.15),
('BRNMMM79C09B907O', 'Bernabé', 'Mimmo', '1979-03-09', 'M', '3251254724', 'NULL', 0),
('BRNMNL68C22D752P', 'Bruno', 'Emanuele', '1968-03-22', 'M', '3161014556', 'NULL', 0.3),
('BRNMRA44P45L624X', 'Brundi', 'Mara', '1944-09-05', 'F', '3559544715', 'NULL', 0.3),
('BRNMRC61T22D366X', 'Barone', 'Americo', '1961-12-22', 'M', '3008999578', 'NULL', 0.05),
('BRNMRN53H10C331N', 'Bernacchioni', 'Moreno', '1953-06-10', 'M', '3621443424', 'NULL', 0.2),
('BRNPRI72H16C653T', 'Brancalion', 'Piero', '1972-06-16', 'M', '3133803274', 'piero.brancalion@virgilio.it', 0),
('BRNSLL01D56C694E', 'Brione', 'Stella', '2001-04-16', 'F', '3758966064', 'stella.brione@gmail.com', 0.05),
('BRNVTI53E21E309J', 'Bernuzzi', 'Vito', '1953-05-21', 'M', '3321884951', 'NULL', 0),
('BRNVTR05E12B328J', 'Brentazzoli', 'Vittoriano', '2005-05-12', 'M', '3884374906', 'NULL', 0),
('BRNVVN62H03C998R', 'Bernardini', 'Viviano', '1962-06-03', 'M', '3349370334', 'NULL', 0),
('BRNVVN80M08C770I', 'Barni', 'Viviano', '1980-08-08', 'M', '3561908499', 'NULL', 0.1),
('BRNVVN92A05I074N', 'Brancati', 'Viviano', '1992-01-05', 'M', '3722303267', 'viviano.brancati@outlook.it', 0),
('BRNYLO59R46H986X', 'Abrioni', 'Yole', '1959-10-06', 'F', '3521843664', 'NULL', 0),
('BRRGLL54R06G015D', 'Barrichello', 'Guglielmo', '1954-10-06', 'M', '3927949628', 'guglielmo.barrichello@pec.it', 0),
('BRRMIA40R66D928J', 'Barretta', 'Mia', '1940-10-26', 'F', '3549362103', 'NULL', 0),
('BRSGLI49R52D738V', 'Bruseghini', 'Giulia', '1949-10-12', 'F', '3425075237', 'giulia.bruseghini@virgilio.it', 0),
('BRSGTA01A63D450F', 'Brasola', 'Agata', '2001-01-23', 'F', '3851527821', 'NULL', 0),
('BRSLBN50L51E764H', 'Brusaschetto', 'Albina', '1950-07-11', 'F', '3124736248', 'NULL', 0),
('BRSLVN45R64G436D', 'Brasca', 'Lavinia', '1945-10-24', 'F', '3082829283', 'NULL', 0),
('BRSMLT72D26C056A', 'Berisso', 'Amleto', '1972-04-26', 'M', '3263405786', 'NULL', 0.3),
('BRSRCE89E60I402R', 'Barison', 'Erica', '1989-05-20', 'F', '3964355971', 'NULL', 0),
('BRSRMN65D07L010F', 'Barasso', 'Erminio', '1965-04-07', 'M', '3356478158', 'erminio.barasso@pec.it', 0.3),
('BRSRTD12D08L507C', 'Brusone', 'Aristide', '2012-04-08', 'M', '3071097133', 'NULL', 0.1),
('BRSVLR12P52D613I', 'Brischetti', 'Valeria', '2012-09-12', 'F', '3073998113', 'NULL', 0.1),
('BRTCLO70M58I493N', 'Bortoli', 'Cloe', '1970-08-18', 'F', '3889074039', 'NULL', 0),
('BRTCRL48E54G433N', 'Bertagnin', 'Carola', '1948-05-14', 'F', '3869867319', 'NULL', 0),
('BRTCRL65H50A615U', 'Bertolo', 'Carla', '1965-06-10', 'F', '3329689880', 'NULL', 0),
('BRTCTN04D14D021K', 'Bertagnon', 'Costanzo', '2004-04-14', 'M', '3402813660', 'costanzo.bertagnon@pec.it', 0.05),
('BRTGIA53D16H917L', 'Bertulli', 'Iago', '1953-04-16', 'M', '3310723117', 'NULL', 0.25),
('BRTGLI75R07H615C', 'Bartalotta', 'Gioele', '1975-10-07', 'M', '3739424855', 'NULL', 0.2),
('BRTGMN80S50L823O', 'Bartalotta', 'Germana', '1980-11-10', 'F', '3634309709', 'NULL', 0),
('BRTLRA92L48H203P', 'Bertolaia', 'Lara', '1992-07-08', 'F', '3140627572', 'NULL', 0.1),
('BRTLRC93B66I697Q', 'Bertoldo', 'Ulderica', '1993-02-26', 'F', '3563344752', 'NULL', 0),
('BRTMLE10A45F889S', 'Birtig', 'Emilia', '2010-01-05', 'F', '3625682967', 'emilia.birtig@outlook.it', 0),
('BRTNRN13B15E940I', 'Bertaglia', 'Nerone', '2013-02-15', 'M', '3081920476', 'nerone.bertaglia@pec.it', 0),
('BRTPLL60C16G492W', 'Bertanza', 'Apollo', '1960-03-16', 'M', '3776450847', 'NULL', 0.25),
('BRTRMN57R47E221J', 'Bertocchini', 'Erminia', '1957-10-07', 'F', '3529417886', 'NULL', 0),
('BRTRNL71L17B923U', 'Bertazzo', 'Reginaldo', '1971-07-17', 'M', '3737370570', 'NULL', 0),
('BRTSLL00B42C479J', 'Bertullo', 'Stella', '2000-02-02', 'F', '3988727852', 'NULL', 0.3),
('BRTSST69H22E968W', 'Bertorelli', 'Sisto', '1969-06-22', 'M', '3638468064', 'NULL', 0),
('BRTSVT53P13L112S', 'Bartolazzi', 'Salvatore', '1953-09-13', 'M', '3220892320', 'NULL', 0),
('BRTVGL58D12C882Q', 'Bertolini', 'Virgilio', '1958-04-12', 'M', '3659569391', 'virgilio.bertolini@gmail.com', 0),
('BRTVNA54T62C276N', 'Berutti', 'Vania', '1954-12-22', 'F', '3470731749', 'vania.berutti@virgilio.it', 0),
('BRVLCN42P53G862O', 'Baravalli', 'Luciana', '1942-09-13', 'F', '3193333028', 'NULL', 0),
('BRVLSI08P57G980Y', 'Breveglieri', 'Lisa', '2008-09-17', 'F', '3495307095', 'NULL', 0),
('BRVSLV49H28E235V', 'Brevigliero', 'Silvio', '1949-06-28', 'M', '3372427313', 'NULL', 0),
('BRZBGI99S06H885M', 'Borzacchielli', 'Biagio', '1999-11-06', 'M', '3061155949', 'NULL', 0),
('BRZBLD02H25D749Y', 'Borzelli', 'Ubaldo', '2002-06-25', 'M', '3727865541', 'NULL', 0.15),
('BRZMRG97E66E288E', 'Berzi', 'Ambrogia', '1997-05-26', 'F', '3444572953', 'NULL', 0),
('BRZSLL17T47F486W', 'Barzizza', 'Isabella', '2017-12-07', 'F', '3391059712', 'NULL', 0.1),
('BSCBRC50T55I726R', 'Boschi', 'Beatrice', '1950-12-15', 'F', '3622819044', 'NULL', 0),
('BSCCRI10R17L777P', 'Biscuoli', 'Icaro', '2010-10-17', 'M', '3829037163', 'NULL', 0),
('BSCDLC98P43E873I', 'Boscheri', 'Doralice', '1998-09-03', 'F', '3864535714', 'NULL', 0.05),
('BSCDLZ62E29A159A', 'Beschi', 'Diocleziano', '1962-05-29', 'M', '3845682828', 'diocleziano.beschi@alice.it', 0.15),
('BSCDRO45A60E587I', 'Bosco', 'Doria', '1945-01-20', 'F', '3986673006', 'NULL', 0.05),
('BSCLCA12H09L735T', 'Bisaccio', 'Alceo', '2012-06-09', 'M', '3180643260', 'NULL', 0),
('BSCLCU78L13E088Y', 'Biscolo', 'Luca', '1978-07-13', 'M', '3347552777', 'NULL', 0.2),
('BSCMNN80T67C855H', 'Boscari', 'Marianna', '1980-12-27', 'F', '3041605668', 'NULL', 0.2),
('BSCNNZ02M17F348Z', 'Buscetta', 'Nunzio', '2002-08-17', 'M', '3017987606', 'nunzio.buscetta@gmail.com', 0),
('BSCRMN40H03C217Z', 'Boschini', 'Erminio', '1940-06-03', 'M', '3598806625', 'NULL', 0),
('BSCVCN76M58B284U', 'Boscolo', 'Vincenzina', '1976-08-18', 'F', '3583077528', 'vincenzina.boscolo@virgilio.it', 0),
('BSFDRT50T53B181F', 'Bisoffi', 'Dorotea', '1950-12-13', 'F', '3910077146', 'dorotea.bisoffi@pec.it', 0),
('BSIRLF58C03E167T', 'Biso', 'Rodolfo', '1958-03-03', 'M', '3518262026', 'NULL', 0),
('BSLRRT89C47E239X', 'Basilico', 'Roberta', '1989-03-07', 'F', '3763255131', 'NULL', 0),
('BSNDLL15C58G329W', 'Besani', 'Dalila', '2015-03-18', 'F', '3250233443', 'NULL', 0),
('BSNFLV95L16F504L', 'Busne', 'Flavio', '1995-07-16', 'M', '3451073350', 'NULL', 0),
('BSSCLI43H67I758P', 'Bossone', 'Clio', '1943-06-27', 'F', '3072780333', 'NULL', 0.1),
('BSSCLL56M13H450K', 'Bosis', 'Catello', '1956-08-13', 'M', '3499505036', 'catello.bosis@gmail.com', 0.05),
('BSSCML10A58B169K', 'Bossone', 'Carmela', '2010-01-18', 'F', '3259122655', 'carmela.bossone@alice.it', 0.25),
('BSSDVG94P63L335U', 'Bossa', 'Edvige', '1994-09-23', 'F', '3112871481', 'edvige.bossa@pec.it', 0),
('BSSGIO99L63H534S', 'Bossoletti', 'Gioia', '1999-07-23', 'F', '3056087405', 'NULL', 0),
('BSSLRZ55H48C988A', 'Busso', 'Lucrezia', '1955-06-08', 'F', '3271273723', 'lucrezia.busso@pec.it', 0),
('BSSMCL06R65D161X', 'Bissolo', 'Micol', '2006-10-25', 'F', '3750667829', 'NULL', 0),
('BSSMLA68D64E325N', 'Bassanello', 'Amelia', '1968-04-24', 'F', '3345834227', 'amelia.bassanello@gmail.com', 0),
('BSSMRZ81B12L501V', 'Bassignana', 'Maurizio', '1981-02-12', 'M', '3424226589', 'NULL', 0),
('BSSPLG69M12I929Z', 'Bassanello', 'Pellegrino', '1969-08-12', 'M', '3706938468', 'pellegrino.bassanello@outlook.it', 0),
('BSSVGL77P23C275K', 'Bussola', 'Virgilio', '1977-09-23', 'M', '3116375075', 'NULL', 0.3),
('BSSYNN49E48I570K', 'Bossi', 'Yvonne', '1949-05-08', 'F', '3408090352', 'yvonne.bossi@pec.it', 0.05),
('BSTDNT07H08M109V', 'Basto', 'Donato', '2007-06-08', 'M', '3710499020', 'NULL', 0),
('BSTGGI02C03E661X', 'Bestetti', 'Gigi', '2002-03-03', 'M', '3309931927', 'NULL', 0),
('BSZDND71R43I980M', 'Biasuz', 'Doranda', '1971-10-03', 'F', '3813252906', 'NULL', 0.1),
('BTRMRT43L53L187A', 'Botrugno', 'Umberta', '1943-07-13', 'F', '3855990135', 'umberta.botrugno@pec.it', 0.05),
('BTTCNN73S59C005M', 'Bettè', 'Corinna', '1973-11-19', 'F', '3340415735', 'NULL', 0),
('BTTFLV12D08G722R', 'Battaglino', 'Fulvio', '2012-04-08', 'M', '3221609071', 'NULL', 0),
('BTTGTV56S23E910L', 'Bottino', 'Gustavo', '1956-11-23', 'M', '3061417973', 'NULL', 0),
('BTTLNU60R53E435S', 'Battaglioni', 'Luana', '1960-10-13', 'F', '3953252663', 'NULL', 0.1),
('BTTMLN98R19M150J', 'Bottarelli', 'Emiliano', '1998-10-19', 'M', '3411346349', 'NULL', 0),
('BTTMRM04E66G046W', 'Battistella', 'Miriam', '2004-05-26', 'F', '3973875624', 'NULL', 0.1),
('BTTNZE76H60H021A', 'Bitetto', 'Enza', '1976-06-20', 'F', '3301184858', 'enza.bitetto@alice.it', 0),
('BTTRMN70H20G448A', 'Boatto', 'Erminio', '1970-06-20', 'M', '3598473884', 'NULL', 0),
('BTTRRA05R69F358F', 'Bettini', 'Aurora', '2005-10-29', 'F', '3897409754', 'NULL', 0.15),
('BTTSVT58H03F776N', 'Bottarello', 'Salvatore', '1958-06-03', 'M', '3232945237', 'NULL', 0),
('BTTTCR56B03L743J', 'Bottega', 'Tancredi', '1956-02-03', 'M', '3587653112', 'NULL', 0),
('BTTVNA47B68D553N', 'Buttarello', 'Vania', '1947-02-28', 'F', '3370247572', 'vania.buttarello@outlook.it', 0),
('BTTZNE59A07H620R', 'Bettin', 'Zeno', '1959-01-07', 'M', '3980768034', 'zeno.bettin@outlook.it', 0),
('BVIGLL01H20G058K', 'Biava', 'Galileo', '2001-06-20', 'M', '3518549686', 'NULL', 0.15),
('BVOFBL47P48L546D', 'Bove', 'Fabiola', '1947-09-08', 'F', '3813942567', 'NULL', 0),
('BVSGTV07B11G686X', 'Biavaschi', 'Gustavo', '2007-02-11', 'M', '3428866849', 'NULL', 0),
('BYUFBA84S18D947P', 'Buy', 'Fabio', '1984-11-18', 'M', '3027345860', 'NULL', 0.3),
('BYULRG10L10H200G', 'Buy', 'Alberigo', '2010-07-10', 'M', '3933530047', 'NULL', 0.05),
('BZORGR91P23G779O', 'Boz', 'Ruggero', '1991-09-23', 'M', '3778971580', 'NULL', 0),
('BZZGLL93D17D483P', 'Bezzoli', 'Galileo', '1993-04-17', 'M', '3249630421', 'NULL', 0.15),
('BZZGRG95T16B851T', 'Beozzi', 'Giorgio', '1995-12-16', 'M', '3359253638', 'giorgio.beozzi@outlook.it', 0),
('BZZSRA66A26F094H', 'Bozzano', 'Saro', '1966-01-26', 'M', '3245972725', 'NULL', 0),
('CAOPCR83R03I787K', 'Cao', 'Pancrazio', '1983-10-03', 'M', '3856320060', 'NULL', 0.15),
('CAUDMN57S02D364N', 'Cau', 'Damiano', '1957-11-02', 'M', '3639501803', 'NULL', 0),
('CBNSNL82T55G364A', 'Cabianca', 'Serenella', '1982-12-15', 'F', '3748392979', 'NULL', 0),
('CBNTNZ78H14D334I', 'Iacoboni', 'Terenzio', '1978-06-14', 'M', '3841033636', 'NULL', 0.15),
('CBRRZO13L13B062S', 'Cabrele', 'Orazio', '2013-07-13', 'M', '3317338794', 'NULL', 0),
('CCCBRM43R12C284F', 'Cicconi', 'Abramo', '1943-10-12', 'M', '3713515227', 'NULL', 0),
('CCCCPI56S15L805J', 'Coccione', 'Iacopo', '1956-11-15', 'M', '3127475472', 'NULL', 0.25),
('CCCDRA49S62G183H', 'Ceccherini', 'Daria', '1949-11-22', 'F', '3022357177', 'daria.ceccherini@virgilio.it', 0.25),
('CCCGLI73E44G154O', 'Caccavelli', 'Giulia', '1973-05-04', 'F', '3934189072', 'giulia.caccavelli@pec.it', 0.15),
('CCCGRT15D14B498B', 'Cuccus', 'Gioberto', '2015-04-14', 'M', '3725250152', 'gioberto.cuccus@gmail.com', 0),
('CCCLNU88P57G185M', 'Cuccuru', 'Luana', '1988-09-17', 'F', '3711780566', 'NULL', 0),
('CCCLRT90M54L048I', 'Caccamo', 'Alberta', '1990-08-14', 'F', '3098066493', 'alberta.caccamo@alice.it', 0),
('CCCMBR41S68L158T', 'Cocconi', 'Ambra', '1941-11-28', 'F', '3011228794', 'NULL', 0),
('CCCMLD12B46M316J', 'Ceccaroni', 'Matilde', '2012-02-06', 'F', '3794742640', 'NULL', 0),
('CCCMLN48P70M182Q', 'Cecchini', 'Emiliana', '1948-09-30', 'F', '3396283924', 'NULL', 0.3),
('CCCMRZ50L65C353K', 'Cecconati', 'Marzia', '1950-07-25', 'F', '3179982364', 'NULL', 0),
('CCCRNN03P61I605H', 'Ciccarella', 'Rosanna', '2003-09-21', 'F', '3509699296', 'NULL', 0),
('CCCRSL92E59L831N', 'Ciccardi', 'Ursula', '1992-05-19', 'F', '3372774632', 'NULL', 0),
('CCHDTR13C02C033G', 'Occhiuzzo', 'Demetrio', '2013-03-02', 'M', '3706773107', 'NULL', 0),
('CCNLFA86P19I914K', 'Acconcia', 'Alfio', '1986-09-19', 'M', '3851202669', 'NULL', 0.3),
('CCNPRN90H51D629R', 'Cucinotta', 'Pierina', '1990-06-11', 'F', '3348390152', 'NULL', 0.2),
('CCRGCM90C11C288V', 'Accordini', 'Giacomo', '1990-03-11', 'M', '3258059326', 'NULL', 0),
('CCRGRG09B49H627H', 'Accursi', 'Giorgia', '2009-02-09', 'F', '3178770628', 'NULL', 0),
('CCRMND59C65L011F', 'Iaccarino', 'Miranda', '1959-03-25', 'F', '3893543744', 'NULL', 0.25),
('CCRRNN81M48F920Z', 'Cucurachi', 'Rosanna', '1981-08-08', 'F', '3227443992', 'NULL', 0),
('CCRSAI72L51G798R', 'Accursio', 'Asia', '1972-07-11', 'F', '3989312431', 'NULL', 0),
('CCRYND10D44L295Q', 'Cecere', 'Yolanda', '2010-04-04', 'F', '3995077128', 'NULL', 0),
('CCSNDA95H47B584E', 'Cucusi', 'Nadia', '1995-06-07', 'F', '3233859681', 'NULL', 0),
('CCTRHL87S53G953Z', 'Accetturi', 'Rachele', '1987-11-13', 'F', '3149983419', 'NULL', 0),
('CCTSVR98E04I249V', 'Accetti', 'Saverio', '1998-05-04', 'M', '3834446457', 'NULL', 0),
('CDLTZN59B26C545I', 'Codeleoncini', 'Tiziano', '1959-02-26', 'M', '3876537085', 'NULL', 0),
('CDMDNI87H60H627S', 'Cadamagnani', 'Dina', '1987-06-20', 'F', '3949316148', 'NULL', 0),
('CDORSL12E54B181P', 'Code', 'Ursula', '2012-05-14', 'F', '3162401123', 'NULL', 0),
('CDUCGR57C04E589I', 'Cudia', 'Calogero', '1957-03-04', 'M', '3085440893', 'NULL', 0.05),
('CDZLRT48D58I689N', 'Codazzi', 'Liberata', '1948-04-18', 'F', '3495599814', 'NULL', 0),
('CDZMRT74S23B584N', 'Codazza', 'Umberto', '1974-11-23', 'M', '3100905229', 'NULL', 0.15),
('CFFMSM78P48F503F', 'Ciuffo', 'Massimiliana', '1978-09-08', 'F', '3191258516', 'NULL', 0),
('CGGNTL95P52B535D', 'Caggeggi', 'Natalia', '1995-09-12', 'F', '3732149838', 'NULL', 0.2),
('CGGPNI95P64L188V', 'Cagegi', 'Pina', '1995-09-24', 'F', '3865917945', 'NULL', 0),
('CGLDRO54T55L936J', 'Coglianese', 'Dora', '1954-12-15', 'F', '3538789805', 'NULL', 0.05),
('CGLFLV13T64M041Q', 'Coglianese', 'Flavia', '2013-12-24', 'F', '3919134478', 'NULL', 0),
('CGNDMN16T70I965L', 'Cagnoli', 'Damiana', '2016-12-30', 'F', '3871493379', 'NULL', 0),
('CHLSRA46R19G221W', 'Chilo', 'Saro', '1946-10-19', 'M', '3283918860', 'saro.chilo@alice.it', 0.25),
('CHLSVN77B48L433E', 'Chilelli', 'Silvana', '1977-02-08', 'F', '3837792319', 'NULL', 0.1),
('CHLTST65T20E270Q', 'Chiola', 'Tristano ', '1965-12-20', 'M', '3476426510', 'tristano.chiola@outlook.it', 0),
('CHNDIA44M48E946W', 'Chinello', 'Ida', '1944-08-08', 'F', '3265269269', 'NULL', 0.05),
('CHNRNN72T22F874G', 'Chenet', 'Ermanno', '1972-12-22', 'M', '3219422626', 'NULL', 0),
('CHPGLD96C43D232J', 'Chiappetti', 'Gilda', '1996-03-03', 'F', '3394867615', 'gilda.chiappetti@virgilio.it', 0),
('CHPSND07S24B810F', 'Chiappetto', 'Secondo', '2007-11-24', 'M', '3077976923', 'NULL', 0.1),
('CHPTLI04E69D022U', 'Chiappetti', 'Italia', '2004-05-29', 'F', '3650217106', 'NULL', 0.1),
('CHRCHR91A49F147A', 'Chiara', 'Chiara', '1991-01-09', 'F', '3607872070', 'NULL', 0),
('CHRCML57L08M101C', 'Chieregati', 'Carmelo', '1957-07-08', 'M', '3568500300', 'NULL', 0),
('CHRDIA68A65I370E', 'Chirco', 'Ida', '1968-01-25', 'F', '3174967343', 'NULL', 0.25),
('CHRFNZ16D18G577Q', 'Chiaramonte', 'Fiorenzo', '2016-04-18', 'M', '3313758996', 'NULL', 0),
('CHRGIA96E15C830Q', 'Cherchi', 'Iago', '1996-05-15', 'M', '3390457237', 'iago.cherchi@gmail.com', 0),
('CHRMMM05T60A359S', 'Chiaramella', 'Mimma', '2005-12-20', 'F', '3463081318', 'NULL', 0.3),
('CHRNDR44H08L445N', 'Chierchia', 'Andrea', '1944-06-08', 'M', '3573895917', 'NULL', 0),
('CHRPRM17S08D999R', 'Chiericati', 'Primo', '2017-11-08', 'M', '3511816375', 'NULL', 0.1),
('CHRRLB02C54C311W', 'Cherini', 'Rosalba', '2002-03-14', 'F', '3585006050', 'NULL', 0),
('CHRSVS44M26F363J', 'Chiaromonte', 'Silvestro', '1944-08-26', 'M', '3781613186', 'NULL', 0.1),
('CHRTNZ79M23I578C', 'Chierichini', 'Terenzio', '1979-08-23', 'M', '3756402721', 'NULL', 0),
('CHSLRA02A62B858Y', 'Chiussi', 'Lara', '2002-01-22', 'F', '3314529060', 'NULL', 0),
('CHTSDR54M02H861K', 'Chitto', 'Isodoro', '1954-08-02', 'M', '3537952356', 'NULL', 0.1),
('CHVCST79B56I463B', 'Chiavazzo', 'Cristiana', '1979-02-16', 'F', '3578205154', 'NULL', 0),
('CLACMN63E08E522Q', 'Cal', 'Clemente', '1963-05-08', 'M', '3631417639', 'NULL', 0.25),
('CLCFMN93S17C153V', 'Coluccio', 'Flaminio', '1993-11-17', 'M', '3966599249', 'NULL', 0.2),
('CLCMHL41B61B203M', 'Calicchia', 'Michela', '1941-02-21', 'F', '3529814989', 'NULL', 0),
('CLCNZE46D19L292F', 'Colace', 'Enzo', '1946-04-19', 'M', '3556205267', 'NULL', 0),
('CLDNDR03E04F262Z', 'Caldani', 'Andrea', '2003-05-04', 'M', '3399634187', 'andrea.caldani@gmail.com', 0.2),
('CLDWND79C41L665S', 'Caldan', 'Wanda', '1979-03-01', 'F', '3941877593', 'NULL', 0),
('CLFDND67S50H577J', 'Caleffi', 'Doranda', '1967-11-10', 'F', '3955631813', 'NULL', 0.3),
('CLFNBL14L65B824H', 'Calafato', 'Annabella', '2014-07-25', 'F', '3826479902', 'NULL', 0),
('CLFNTL09C64A185O', 'Calafatto', 'Natalia', '2009-03-24', 'F', '3932382258', 'NULL', 0),
('CLGGLD94L01I470U', 'Caligiuri', 'Gildo', '1994-07-01', 'M', '3427220231', 'NULL', 0.15),
('CLGRND45L03A988O', 'Calogeri', 'Armando', '1945-07-03', 'M', '3544073084', 'NULL', 0),
('CLLFTN06T30I786V', 'Ciulla', 'Faustino', '2006-12-30', 'M', '3030334989', 'NULL', 0),
('CLLGTV68S14L145E', 'Cella', 'Gustavo', '1968-11-14', 'M', '3062480577', 'gustavo.cella@virgilio.it', 0.25),
('CLLLGO54R68I991S', 'Collurà', 'Olga', '1954-10-28', 'F', '3816890812', 'olga.collurà@virgilio.it', 0.1),
('CLLLSN87M69A551P', 'Ciolla', 'Alessandra', '1987-08-29', 'F', '3057824307', 'NULL', 0.25),
('CLLLVO14E53E900C', 'Colleoni', 'Oliva', '2014-05-13', 'F', '3769720222', 'NULL', 0.3),
('CLMGRM93H29L575M', 'Colombini', 'Geremia', '1993-06-29', 'M', '3375280193', 'NULL', 0),
('CLMMCL53R68B838X', 'Colombarini', 'Marcella', '1953-10-28', 'F', '3967092770', 'NULL', 0),
('CLMRFL08P23G025O', 'Calami', 'Raffaele', '2008-09-23', 'M', '3751158305', 'NULL', 0.25),
('CLNDRD62S30E152T', 'Calandri', 'Edoardo', '1962-11-30', 'M', '3274349588', 'NULL', 0.2),
('CLNMRG91P49G400Y', 'Colnaghi', 'Ambrogia', '1991-09-09', 'F', '3750195938', 'NULL', 0.25),
('CLNMSM85S26F730V', 'Calandrella', 'Massimiliano', '1985-11-26', 'M', '3708189133', 'NULL', 0),
('CLOMRA84C57C542R', 'Clo', 'Maura', '1984-03-17', 'F', '3596623350', 'NULL', 0),
('CLPLCU57S12A495U', 'Colapietro', 'Lucio', '1957-11-12', 'M', '3153903397', 'lucio.colapietro@outlook.it', 0),
('CLPNTS58P61H262N', 'Colpani', 'Anastasia', '1958-09-21', 'F', '3619220412', 'NULL', 0),
('CLPYNN00D58E020M', 'Claps', 'Yvonne', '2000-04-18', 'F', '3373536936', 'yvonne.claps@pec.it', 0),
('CLRDNA94D04A128F', 'Calora', 'Adone', '1994-04-04', 'M', '3132465803', 'adone.calora@gmail.com', 0),
('CLRMNL03E20D366K', 'Celori', 'Emanuele', '2003-05-20', 'M', '3889138311', 'NULL', 0),
('CLRMRA03R06D630P', 'Celauro', 'Mario', '2003-10-06', 'M', '3255191278', 'NULL', 0.25),
('CLSCSM76C43A391F', 'Coloso', 'Cosima', '1976-03-03', 'F', '3627757843', 'NULL', 0.05),
('CLSCST68D49D785B', 'Calista', 'Cristofora', '1968-04-09', 'F', '3054340733', 'NULL', 0.15),
('CLSGNT61S06G224I', 'Culos', 'Giacinto', '1961-11-06', 'M', '3213476738', 'NULL', 0.15),
('CLSLTZ68R53H233N', 'Colosetti', 'Letizia', '1968-10-13', 'F', '3826174108', 'letizia.colosetti@virgilio.it', 0),
('CLTMHL14C52L887O', 'Coltraro', 'Michela', '2014-03-12', 'F', '3048173421', 'NULL', 0.05),
('CLTMRA66T02C999N', 'Caltagirone', 'Mauro', '1966-12-02', 'M', '3079024835', 'NULL', 0.2),
('CLTPML84A57L105O', 'Caltabiano', 'Pamela', '1984-01-17', 'F', '3635404134', 'NULL', 0.15),
('CLVMLN71S41I651N', 'Calvia', 'Emiliana', '1971-11-01', 'F', '3053214824', 'NULL', 0),
('CLZPNI59P15E887N', 'Calzolai', 'Pino', '1959-09-15', 'M', '3788806684', 'NULL', 0),
('CMAGLN03E03G431B', 'Caimi', 'Giuliano', '2003-05-03', 'M', '3933549846', 'NULL', 0),
('CMBBDT77H01I437S', 'Cambio', 'Benedetto', '1977-06-01', 'M', '3342324707', 'NULL', 0),
('CMBCLI63C42M163K', 'Cimbri', 'Clio', '1963-03-02', 'F', '3761126999', 'clio.cimbri@virgilio.it', 0),
('CMBCVN63H07G105J', 'Cambi', 'Calvino', '1963-06-07', 'M', '3953814542', 'NULL', 0),
('CMBLRT81S28F863P', 'Cambie', 'Loreto', '1981-11-28', 'M', '3965334919', 'loreto.cambie@alice.it', 0.3),
('CMBMRZ77M45I234Q', 'Cambareri', 'Marzia', '1977-08-05', 'F', '3259577476', 'marzia.cambareri@gmail.com', 0.15),
('CMBNRN64S55B888R', 'Cambi', 'Andreina', '1964-11-15', 'F', '3843899595', 'NULL', 0.15),
('CMBPCR45P13G553G', 'Cimbri', 'Pancrazio', '1945-09-13', 'M', '3164808065', 'pancrazio.cimbri@pec.it', 0),
('CMBPML69A51B006E', 'Cambie', 'Pamela', '1969-01-11', 'F', '3120777650', 'pamela.cambie@outlook.it', 0.2),
('CMBPNI76H25I251D', 'Cambria', 'Pino', '1976-06-25', 'M', '3543695961', 'pino.cambria@virgilio.it', 0),
('CMBRRT09L26C629C', 'Cambriani', 'Roberto', '2009-07-26', 'M', '3838673835', 'NULL', 0),
('CMBSST73E71B857O', 'Cambie', 'Sebastiana', '1973-05-31', 'F', '3457715624', 'NULL', 0),
('CMILLL05L25H394P', 'Cima', 'Lello', '2005-07-25', 'M', '3346803490', 'NULL', 0),
('CMLDCC60D27F553Y', 'Camello', 'Duccio', '1960-04-27', 'M', '3023124325', 'NULL', 0),
('CMLSAI48L43A721V', 'Camillo', 'Asia', '1948-07-03', 'F', '3950755483', 'NULL', 0),
('CMMRMN02A26B005P', 'Cammaroto', 'Romano', '2002-01-26', 'M', '3987394182', 'romano.cammaroto@pec.it', 0),
('CMNDMA56B28A866I', 'Camana', 'Adamo', '1956-02-28', 'M', '3635262591', 'NULL', 0.2),
('CMNDZN78P50H648Z', 'Caminito', 'Domiziana', '1978-09-10', 'F', '3532444202', 'NULL', 0),
('CMNMRN46S02E451Q', 'Caminiti', 'Moreno', '1946-11-02', 'M', '3409710870', 'moreno.caminiti@alice.it', 0),
('CMNRLN87D69C768T', 'Comandi', 'Rosalinda', '1987-04-29', 'F', '3031339049', 'NULL', 0),
('CMNRSL81M50H055R', 'Comandu', 'Rossella', '1981-08-10', 'F', '3031207703', 'NULL', 0),
('CMNSLV67B14C398T', 'Camaioni', 'Salvo', '1967-02-14', 'M', '3278225383', 'NULL', 0),
('CMNTNI52R41B104R', 'Comand', 'Tina', '1952-10-01', 'F', '3733959986', 'NULL', 0.25),
('CMOCLN40D44E758R', 'Como', 'Carolina', '1940-04-04', 'F', '3157140611', 'carolina.como@virgilio.it', 0),
('CMPDNL90M44H425H', 'Compagno', 'Daniela', '1990-08-04', 'F', '3438567126', 'NULL', 0.25),
('CMPDTL63R43I463L', 'Campomaggiore', 'Domitilla', '1963-10-03', 'F', '3247460199', 'NULL', 0),
('CMPLCN99L43D329X', 'Compagni', 'Luciana', '1999-07-03', 'F', '3268510552', 'NULL', 0.05),
('CMPLVC93M25A765G', 'Campanili', 'Ludovico', '1993-08-25', 'M', '3153472706', 'NULL', 0),
('CMPMRC94T70F410B', 'Campaci', 'Marica', '1994-12-30', 'F', '3568046915', 'NULL', 0),
('CMPMRM40S60I786Y', 'Compagna', 'Miriam', '1940-11-20', 'F', '3836263154', 'NULL', 0),
('CMPMRM85D49A334X', 'Campolungo', 'Miriam', '1985-04-09', 'F', '3372350775', 'NULL', 0),
('CMPPPP16E59G076T', 'Campomaggiore', 'Peppa', '2016-05-19', 'F', '3493037439', 'NULL', 0),
('CMPTMR41B50I511I', 'Ciampoli', 'Tamara', '1941-02-10', 'F', '3835120070', 'NULL', 0),
('CMPVGL88L53H536S', 'Campani', 'Virgilia', '1988-07-13', 'F', '3648546407', 'NULL', 0),
('CMRCPI08H25M118H', 'Camerlenghi', 'Iacopo', '2008-06-25', 'M', '3318297371', 'NULL', 0.15),
('CMRPMR12M59C100U', 'Cameran', 'Palmira', '2012-08-19', 'F', '3646966757', 'palmira.cameran@alice.it', 0),
('CMSGDE92M17G822H', 'Camosso', 'Egidio', '1992-08-17', 'M', '3523723372', 'NULL', 0.1),
('CMTLND11R27G854C', 'Comita', 'Leonida', '2011-10-27', 'M', '3671655204', 'NULL', 0.25),
('CMTMRC94R71F795H', 'Comite', 'America', '1994-10-31', 'F', '3962446157', 'NULL', 0),
('CMTNTS17E53E092T', 'Comito', 'Anastasia', '2017-05-13', 'F', '3391499985', 'anastasia.comito@alice.it', 0.05),
('CNBLGR15T41E465M', 'Canobbio', 'Allegra', '2015-12-01', 'F', '3619174430', 'NULL', 0),
('CNCDRA56M42L724P', 'Cancian', 'Daria', '1956-08-02', 'F', '3109401375', 'daria.cancian@alice.it', 0),
('CNCMNO92C69G766M', 'Cancellari', 'Monia', '1992-03-29', 'F', '3199036625', 'monia.cancellari@virgilio.it', 0),
('CNCRCC83A63I760L', 'Ciancimino', 'Rebecca', '1983-01-23', 'F', '3371052166', 'NULL', 0.05),
('CNCRNN83T50H300A', 'Cancedda', 'Ermanna', '1983-12-10', 'F', '3020357168', 'NULL', 0.3),
('CNCTZN70A11M113N', 'Concilio', 'Tiziano', '1970-01-11', 'M', '3136845433', 'NULL', 0.25),
('CNCWLM43M65B375I', 'Conconi', 'Wilma', '1943-08-25', 'F', '3753767393', 'NULL', 0),
('CNDCSR10R29G833S', 'Condemi', 'Cesare', '2010-10-29', 'M', '3641305177', 'NULL', 0.2),
('CNDCSS63H06C115T', 'Candore', 'Cassio', '1963-06-06', 'M', '3882661552', 'NULL', 0),
('CNDLRI48C17L586J', 'Condemi', 'Ilario', '1948-03-17', 'M', '3646575633', 'NULL', 0.05),
('CNDLRT08L47E496E', 'Condo', 'Alberta', '2008-07-07', 'F', '3112272258', 'NULL', 0),
('CNDMRN91C60L410K', 'Condemi', 'Marina', '1991-03-20', 'F', '3598574277', 'NULL', 0.25),
('CNDPCR48T17G250Y', 'Cundari', 'Pancrazio', '1948-12-17', 'M', '3300895838', 'NULL', 0),
('CNFNCL88D07F250X', 'Confalone', 'Nicola', '1988-04-07', 'M', '3430389494', 'nicola.confalone@alice.it', 0.05),
('CNFNRN09L58H493F', 'Acanfora', 'Nazarena', '2009-07-18', 'F', '3391758182', 'NULL', 0),
('CNGCRL51E51F991N', 'Cangini', 'Carla', '1951-05-11', 'F', '3076237618', 'carla.cangini@alice.it', 0),
('CNGFCN98D30L304T', 'Cunegatti', 'Feliciano', '1998-04-30', 'M', '3053967381', 'NULL', 0.2),
('CNGPRD80T02M286H', 'Congiu', 'Paride', '1980-12-02', 'M', '3293845528', 'NULL', 0.05),
('CNGVTR80E06E875P', 'Cangiano', 'Vittoriano', '1980-05-06', 'M', '3956212187', 'NULL', 0),
('CNILRG80B18B364U', 'Cino', 'Alberigo', '1980-02-18', 'M', '3564986563', 'NULL', 0),
('CNISNT11E57D214O', 'Cione', 'Samanta', '2011-05-17', 'F', '3801321576', 'NULL', 0),
('CNISNT60A47B056X', 'Ciona', 'Samantha', '1960-01-07', 'F', '3437822085', 'NULL', 0),
('CNNCTN76R07I817E', 'Cannatà', 'Cateno', '1976-10-07', 'M', '3832406103', 'NULL', 0),
('CNNDFN09R53D049W', 'Cannavacciuolo', 'Dafne', '2009-10-13', 'F', '3300011984', 'dafne.cannavacciuolo@pec.it', 0.2),
('CNNMLN96R23I774W', 'Cannavaciuolo', 'Emiliano', '1996-10-23', 'M', '3308747643', 'NULL', 0),
('CNNRKE83R67G773V', 'Cionna', 'Erika', '1983-10-27', 'F', '3045599362', 'NULL', 0),
('CNNVVN90E19B860F', 'Cannavaro', 'Viviano', '1990-05-19', 'M', '3830584251', 'NULL', 0),
('CNNYLN49T68I800I', 'Cannavacciolo', 'Ylenia', '1949-12-28', 'F', '3487287413', 'NULL', 0.05),
('CNOLRI98S48D222F', 'Conio', 'Ilaria', '1998-11-08', 'F', '3276827657', 'ilaria.conio@outlook.it', 0),
('CNRRRT49H22E030R', 'Cinardi', 'Roberto', '1949-06-22', 'M', '3509416426', 'roberto.cinardi@alice.it', 0),
('CNRTNO54L57I808M', 'Cinardi', 'Tonia', '1954-07-17', 'F', '3253571544', 'NULL', 0),
('CNSLGO86C47C343L', 'Consonni', 'Olga', '1986-03-07', 'F', '3628326910', 'NULL', 0.1),
('CNSMRN03P12C704A', 'Canese', 'Moreno', '2003-09-12', 'M', '3468098415', 'moreno.canese@outlook.it', 0),
('CNSMRN89R59C694E', 'Cinus', 'Morena', '1989-10-19', 'F', '3339734719', 'NULL', 0.3),
('CNSRNN55T01F406L', 'Consorte', 'Ermanno', '1955-12-01', 'M', '3619677643', 'ermanno.consorte@alice.it', 0),
('CNTCSM42H69F256N', 'Cunietti', 'Cosima', '1942-06-29', 'F', '3612957369', 'NULL', 0),
('CNTDNI84P60H844F', 'Centonze', 'Diana', '1984-09-20', 'F', '3517937210', 'NULL', 0.2),
('CNTDNL05P58C400H', 'Contiero', 'Daniela', '2005-09-18', 'F', '3237699203', 'NULL', 0),
('CNTFNC95M04C780K', 'Contarini', 'Francesco', '1995-08-04', 'M', '3102800433', 'NULL', 0),
('CNTGNR17S06C250S', 'Contardo', 'Gennaro', '2017-11-06', 'M', '3395111335', 'NULL', 0),
('CNTLRD16E20F563Z', 'Conter', 'Alfredo', '2016-05-20', 'M', '3483155226', 'alfredo.conter@pec.it', 0),
('CNTRNN73S55L931L', 'Cantelli', 'Arianna', '1973-11-15', 'F', '3965169253', 'arianna.cantelli@pec.it', 0),
('CNVLDA41S17D667X', 'Converso', 'Aldo', '1941-11-17', 'M', '3922580332', 'NULL', 0.2),
('COXLSI94H54L677Z', 'Co', 'Lisa', '1994-06-14', 'F', '3816696859', 'lisa.co@gmail.com', 0),
('CPDMNZ76L49G011O', 'Capodieci', 'Amanzia', '1976-07-09', 'F', '3138425677', 'amanzia.capodieci@gmail.com', 0),
('CPFLTR69D53B769H', 'Capoferri', 'Elettra', '1969-04-13', 'F', '3581932038', 'NULL', 0),
('CPLCSG06C67B082Q', 'Capolungo', 'Consiglia', '2006-03-27', 'F', '3250704986', 'NULL', 0.15),
('CPLFLV70B46B461C', 'Capolupi', 'Fulvia', '1970-02-06', 'F', '3661626165', 'NULL', 0.2),
('CPLGST71L17C013I', 'Cipellitti', 'Egisto', '1971-07-17', 'M', '3161786818', 'NULL', 0),
('CPLLCN57A12F486N', 'Capelli', 'Luciano', '1957-01-12', 'M', '3049544254', 'NULL', 0),
('CPLMDA56P16A804F', 'Cipollini', 'Amedeo', '1956-09-16', 'M', '3992893175', 'NULL', 0),
('CPLNEE53L06E625P', 'Cupelli', 'Enea', '1953-07-06', 'M', '3556466792', 'enea.cupelli@alice.it', 0),
('CPLNFR94D05F205F', 'Cupelli', 'Onofrio', '1994-04-05', 'M', '3240916792', 'NULL', 0),
('CPLTTV95P20G830J', 'Capiluppi', 'Ottavio', '1995-09-20', 'M', '3119872803', 'NULL', 0.1),
('CPNLDR96T31E459C', 'Caponero', 'Leandro', '1996-12-31', 'M', '3544279117', 'NULL', 0.1),
('CPNNVE53H27I337Y', 'Caponera', 'Nevio', '1953-06-27', 'M', '3229195494', 'NULL', 0),
('CPPCMN62P26D952X', 'Coppotelli', 'Carmine', '1962-09-26', 'M', '3721767556', 'NULL', 0.15),
('CPPLFA40L15A811Q', 'Cappello', 'Alfio', '1940-07-15', 'M', '3347231296', 'NULL', 0),
('CPPLLL96A52H269W', 'Cappello', 'Lucilla', '1996-01-12', 'F', '3314781821', 'NULL', 0.1),
('CPRBBR09M47D674Z', 'Caporiccio', 'Barbara', '2009-08-07', 'F', '3395474034', 'NULL', 0),
('CPRFLV42A68G874G', 'Caporaso', 'Flavia', '1942-01-28', 'F', '3843161307', 'NULL', 0),
('CPRGNI01A28H976G', 'Capurro', 'Igino', '2001-01-28', 'M', '3157766191', 'NULL', 0),
('CPRGRT88H11I781J', 'Capretta', 'Gioberto', '1988-06-11', 'M', '3032161320', 'NULL', 0),
('CPRLBN62C08F648G', 'Capriolo', 'Albino', '1962-03-08', 'M', '3062664735', 'NULL', 0.25),
('CPRLNE85C63E929X', 'Caparelli', 'Elena', '1985-03-23', 'F', '3048461590', 'NULL', 0),
('CPRLVI70H68H039S', 'Caprili', 'Livia', '1970-06-28', 'F', '3845139603', 'NULL', 0),
('CPRRZO93P17A309Z', 'Caprettini', 'Orazio', '1993-09-17', 'M', '3525420656', 'orazio.caprettini@outlook.it', 0),
('CPTGTA40A66A713G', 'Caputo', 'Agata', '1940-01-26', 'F', '3535602155', 'NULL', 0),
('CPZDRN78D20A487G', 'Capezzuoli', 'Adriano', '1978-04-20', 'M', '3665768193', 'NULL', 0.05),
('CPZFMN70D42E668A', 'Capezzuoli', 'Flaminia', '1970-04-02', 'F', '3486112456', 'flaminia.capezzuoli@pec.it', 0),
('CQRRNN88E55H331U', 'Acquarone', 'Arianna', '1988-05-15', 'F', '3801386276', 'NULL', 0.1),
('CRACTN98R62G260O', 'Carau', 'Costanza', '1998-10-22', 'F', '3450445887', 'NULL', 0.05),
('CRBCTL59A59B927J', 'Carbonello', 'Clotilde', '1959-01-19', 'F', '3313082033', 'NULL', 0.05),
('CRBDRN91R11I140M', 'Acerbis', 'Adriano', '1991-10-11', 'M', '3801639187', 'NULL', 0),
('CRBLRC10D03I026F', 'Carbonetto', 'Alarico', '2010-04-03', 'M', '3054415171', 'NULL', 0),
('CRBNRN81M10L211J', 'Carbonera', 'Nerone', '1981-08-10', 'M', '3124060076', 'NULL', 0.05),
('CRBRLB46L55H047G', 'Carobbi', 'Rosalba', '1946-07-15', 'F', '3141864496', 'NULL', 0),
('CRBRNN89T56H818Y', 'Carbonella', 'Ermanna', '1989-12-16', 'F', '3862149151', 'NULL', 0.3),
('CRBSNT58L51G371Z', 'Corbascio', 'Samanta', '1958-07-11', 'F', '3189473243', 'NULL', 0),
('CRBTST60S27I799R', 'Carbonello', 'Tristano ', '1960-11-27', 'M', '3954953742', 'NULL', 0),
('CRCDNT72H04D653O', 'Caracciolo', 'Donato', '1972-06-04', 'M', '3735306637', 'NULL', 0),
('CRCDRN73E03H034D', 'Caricati', 'Adriano', '1973-05-03', 'M', '3668064926', 'NULL', 0),
('CRCLCI68L58H688V', 'Curci', 'Licia', '1968-07-18', 'F', '3973960978', 'NULL', 0),
('CRCMRN52R26I085A', 'Crocetta', 'Mariano', '1952-10-26', 'M', '3553445536', 'NULL', 0),
('CRCNTS74P30B542T', 'Crocini', 'Anastasio', '1974-09-30', 'M', '3910512157', 'anastasio.crocini@outlook.it', 0.05),
('CRCRTI04A65F729G', 'Crocoli', 'Rita', '2004-01-25', 'F', '3674093563', 'NULL', 0),
('CRCSRA84H54D121I', 'Cercato', 'Sara', '1984-06-14', 'F', '3023896825', 'NULL', 0),
('CRCVLR95A10L675O', 'Caracristi', 'Valerio', '1995-01-10', 'M', '3214177683', 'NULL', 0),
('CRDCMN75D54B500Q', 'Cardellicchio', 'Clementina', '1975-04-14', 'F', '3699607950', 'NULL', 0),
('CRDGST90P03C413M', 'Crudele', 'Giusto', '1990-09-03', 'M', '3925022087', 'NULL', 0),
('CRDRSL57S62L281G', 'Ciardo', 'Rossella', '1957-11-22', 'F', '3228036646', 'rossella.ciardo@outlook.it', 0),
('CRDRSL93L56C002V', 'Aicardi', 'Ursula', '1993-07-16', 'F', '3424765083', 'NULL', 0.3),
('CRGMRT93S61H531L', 'Corigliani', 'Marta', '1993-11-21', 'F', '3825738595', 'marta.corigliani@gmail.com', 0),
('CRGRCL96H03A059S', 'Curigliano', 'Ercole', '1996-06-03', 'M', '3702232305', 'NULL', 0.2),
('CRGRSR09P51I969B', 'Cirignano', 'Rosaria', '2009-09-11', 'F', '3001512509', 'NULL', 0),
('CRLCLL69A53F002N', 'Ceraolo', 'Camilla', '1969-01-13', 'F', '3811748680', 'camilla.ceraolo@alice.it', 0),
('CRLCTN43S19M090U', 'Crialesi', 'Costanzo', '1943-11-19', 'M', '3794274137', 'NULL', 0.3),
('CRLGLI41T02I782H', 'Carlesi', 'Gioele', '1941-12-02', 'M', '3737079272', 'NULL', 0.15),
('CRLGNZ72D09L521U', 'Ciriello', 'Ignazio', '1972-04-09', 'M', '3766020582', 'NULL', 0.2),
('CRLGVF86L44L061D', 'Carollo', 'Genoveffa', '1986-07-04', 'F', '3953442749', 'NULL', 0),
('CRLLVC53E21A060G', 'Cerello', 'Ludovico', '1953-05-21', 'M', '3628796858', 'NULL', 0.05),
('CRLMRA53D20H459K', 'Corleto', 'Mario', '1953-04-20', 'M', '3472506647', 'mario.corleto@outlook.it', 0.05),
('CRLMRO52A29E377E', 'Carolei', 'Omar', '1952-01-29', 'M', '3070844729', 'omar.carolei@pec.it', 0),
('CRLNGL16B22H714I', 'Carella', 'Angelo', '2016-02-22', 'M', '3953773306', 'NULL', 0),
('CRLRLL94B59L835Z', 'Ceraulo', 'Rosella', '1994-02-19', 'F', '3846179407', 'NULL', 0.15),
('CRLRNL03E16G568R', 'Carelli', 'Reginaldo', '2003-05-16', 'M', '3770230705', 'NULL', 0.2),
('CRLSCR87R11H475H', 'Ciraldo', 'Oscar', '1987-10-11', 'M', '3069705833', 'NULL', 0),
('CRMFST49D27B248T', 'Crim', 'Fausto', '1949-04-27', 'M', '3652124134', 'NULL', 0),
('CRMGLL86H27M336D', 'Cremona', 'Galileo', '1986-06-27', 'M', '3226472167', 'NULL', 0),
('CRMRGN41D55B238S', 'Cerminara', 'Regina', '1941-04-15', 'F', '3646446156', 'NULL', 0),
('CRMRGR65B07L450W', 'Cremonese', 'Ruggero', '1965-02-07', 'M', '3430629378', 'NULL', 0.3),
('CRMSLL90H70E808F', 'Caremoli', 'Stella', '1990-06-30', 'F', '3331332719', 'NULL', 0),
('CRMSVG55R41A853F', 'Caramagna', 'Selvaggia', '1955-10-01', 'F', '3997732697', 'NULL', 0),
('CRNCVN63D16C006W', 'Corneli', 'Calvino', '1963-04-16', 'M', '3604355482', 'NULL', 0),
('CRNDNI77A65B866C', 'Cerini', 'Diana', '1977-01-25', 'F', '3436300061', 'NULL', 0.05),
('CRNDRN06T29H768D', 'Cariano', 'Adriano', '2006-12-29', 'M', '3769421122', 'NULL', 0),
('CRNGZZ07S12F262N', 'Coronella', 'Galeazzo', '2007-11-12', 'M', '3349913267', 'NULL', 0.1),
('CRNLEO12E06E094V', 'Cirnigliano', 'Leo', '2012-05-06', 'M', '3563305041', 'NULL', 0),
('CRNLFA11D26D412F', 'Cerne', 'Alfio', '2011-04-26', 'M', '3453221988', 'alfio.cerne@alice.it', 0.1),
('CRNMRO95C43E168R', 'Cernigliano', 'Moira', '1995-03-03', 'F', '3076028003', 'moira.cernigliano@gmail.com', 0),
('CRNNCL83L25C656T', 'Carnesecca', 'Nicola', '1983-07-25', 'M', '3042144041', 'nicola.carnesecca@outlook.it', 0.2),
('CRNRCC79M65B791A', 'Coroneo', 'Rebecca', '1979-08-25', 'F', '3896352726', 'NULL', 0),
('CRNRSL75T59F004D', 'Corain', 'Rosalia', '1975-12-19', 'F', '3992291960', 'NULL', 0),
('CRNSLL94M47M002B', 'Carnesecchi', 'Isabella', '1994-08-07', 'F', '3101674984', 'NULL', 0),
('CRNTZN93P28C716Y', 'Caringi', 'Tiziano', '1993-09-28', 'M', '3158304995', 'NULL', 0.2),
('CRPLSN98M51D134Y', 'Carpani', 'Luisiana', '1998-08-11', 'F', '3565562567', 'NULL', 0),
('CRPMDA40C31D244E', 'Crepaldi', 'Amadeo', '1940-03-31', 'M', '3129370774', 'NULL', 0.1),
('CRPMSM85L08E930H', 'Carpano', 'Massimo', '1985-07-08', 'M', '3893259781', 'massimo.carpano@alice.it', 0),
('CRPVLI79B50D540H', 'Carpentieri', 'Viola', '1979-02-10', 'F', '3373369684', 'NULL', 0),
('CRQDNL05T14G102Z', 'Cerquetti', 'Danilo', '2005-12-14', 'M', '3023618961', 'danilo.cerquetti@pec.it', 0),
('CRRBNR78B24C632Z', 'Corrente', 'Bernardo', '1978-02-24', 'M', '3364722558', 'NULL', 0),
('CRRGNS68E43I410G', 'Corrao', 'Agnese', '1968-05-03', 'F', '3653531393', 'agnese.corrao@outlook.it', 0),
('CRRGTA61T64L886S', 'Cerrini', 'Agata', '1961-12-24', 'F', '3318806367', 'NULL', 0),
('CRRLVI00D10A480J', 'Carrà', 'Livio', '2000-04-10', 'M', '3436308893', 'livio.carrà@alice.it', 0.25),
('CRRPRI15C46E090B', 'Corradi', 'Piera', '2015-03-06', 'F', '3226103914', 'NULL', 0),
('CRRPRZ65S66H245E', 'Acerrano', 'Patrizia', '1965-11-26', 'F', '3042883451', 'NULL', 0),
('CRRRNN96A21M429Y', 'Cerri', 'Ermanno', '1996-01-21', 'M', '3968624663', 'NULL', 0),
('CRSBNT98A26M288J', 'Cresti', 'Benito', '1998-01-26', 'M', '3222809909', 'NULL', 0),
('CRSCLI16M59I354X', 'Carsana', 'Clio', '2016-08-19', 'F', '3535534216', 'NULL', 0),
('CRSCST60B09H999F', 'Crossignani', 'Cristiano', '1960-02-09', 'M', '3728078063', 'NULL', 0.1),
('CRSFST62P04B886M', 'Cursio', 'Fausto', '1962-09-04', 'M', '3607851226', 'fausto.cursio@pec.it', 0),
('CRSGIA12S13G657U', 'Crosara', 'Iago', '2012-11-13', 'M', '3527526250', 'NULL', 0),
('CRSGST13M22L865S', 'Carosi', 'Egisto', '2013-08-22', 'M', '3221920735', 'egisto.carosi@alice.it', 0.15),
('CRSMNI77E29G511U', 'Crispini', 'Mino', '1977-05-29', 'M', '3606914546', 'NULL', 0.2),
('CRSMRN89H10M308W', 'Carisio', 'Moreno', '1989-06-10', 'M', '3273696350', 'NULL', 0),
('CRSPLT52B13G400H', 'Criscino', 'Ippolito', '1952-02-13', 'M', '3844120418', 'NULL', 0),
('CRSPML87H57F604Q', 'Cristoforo', 'Pamela', '1987-06-17', 'F', '3499885377', 'NULL', 0),
('CRSSVN82H48F623J', 'Crosara', 'Silvana', '1982-06-08', 'F', '3490483714', 'NULL', 0.1),
('CRSZTI61B68C978P', 'Crisafulli', 'Zita', '1961-02-28', 'F', '3667521448', 'NULL', 0.2),
('CRTCMN81P17E610B', 'Crotti', 'Carmine', '1981-09-17', 'M', '3955385785', 'carmine.crotti@alice.it', 0),
('CRTGDE42P04E995T', 'Cariota', 'Egidio', '1942-09-04', 'M', '3442812142', 'egidio.cariota@alice.it', 0),
('CRTMIA03A45B430Z', 'Creti', 'Mia', '2003-01-05', 'F', '3371668547', 'NULL', 0),
('CRTNSC92L57I759H', 'Caratti', 'Natascia', '1992-07-17', 'F', '3827107803', 'NULL', 0),
('CRTPMR12L51L751A', 'Curotto', 'Palmira', '2012-07-11', 'F', '3077194087', 'NULL', 0),
('CRTRSN05B51D333F', 'Cortis', 'Rossana', '2005-02-11', 'F', '3969483908', 'NULL', 0.25),
('CRTYND78M51L126D', 'Crott', 'Yolanda', '1978-08-11', 'F', '3556730073', 'NULL', 0),
('CRUCRN57E51G982F', 'Curi', 'Caterina', '1957-05-11', 'F', '3788464143', 'NULL', 0),
('CRURBN74P48A957C', 'Curio', 'Rubina', '1974-09-08', 'F', '3229381165', 'rubina.curio@gmail.com', 0),
('CRVCSR41B16L238X', 'Cervellino', 'Cesare', '1941-02-16', 'M', '3677964744', 'NULL', 0),
('CRVLNE52P43B741O', 'Ceravolo', 'Eleana', '1952-09-03', 'F', '3899429938', 'eleana.ceravolo@virgilio.it', 0),
('CRVLNE63D68M158X', 'Cervelli', 'Elena', '1963-04-28', 'F', '3495660024', 'elena.cervelli@virgilio.it', 0.15),
('CRVNLT17H03C934E', 'Cervotti', 'Anacleto', '2017-06-03', 'M', '3574727397', 'NULL', 0),
('CRVSVN10B43D024V', 'Cervera', 'Silvana', '2010-02-03', 'F', '3245393443', 'silvana.cervera@alice.it', 0.25),
('CSAMRZ12P48A570O', 'Causio', 'Maurizia', '2012-09-08', 'F', '3218518805', 'NULL', 0.05),
('CSBVLM73M64B180T', 'Casabianca', 'Vilma', '1973-08-24', 'F', '3335566378', 'NULL', 0.2),
('CSCGNT89H29F199U', 'Cosco', 'Giacinto', '1989-06-29', 'M', '3362414589', 'giacinto.cosco@virgilio.it', 0.15),
('CSCGTR55A28D714F', 'Cascone', 'Gualtiero', '1955-01-28', 'M', '3542263432', 'NULL', 0),
('CSCLVN91S49L611S', 'Casaccio', 'Lavinia', '1991-11-09', 'F', '3073687047', 'NULL', 0.25),
('CSCNLT69C65A786W', 'Ceschini', 'Nicoletta', '1969-03-25', 'F', '3931558081', 'NULL', 0.25),
('CSCRGR78D18D902C', 'Cascio', 'Ruggero', '1978-04-18', 'M', '3713077439', 'ruggero.cascio@virgilio.it', 0),
('CSGSLN79P50L829F', 'Casagrande', 'Selene', '1979-09-10', 'F', '3924500092', 'NULL', 0),
('CSLCLL00P48F893H', 'Cosoleto', 'Camilla', '2000-09-08', 'F', '3286282743', 'camilla.cosoleto@outlook.it', 0),
('CSLFMN68H04C027E', 'Casolo', 'Flaminio', '1968-06-04', 'M', '3761242240', 'NULL', 0.25),
('CSLLCU97A16A275D', 'Casalini', 'Luca', '1997-01-16', 'M', '3744398062', 'NULL', 0.15),
('CSLNCL56D12E004Y', 'Casolo', 'Nicola', '1956-04-12', 'M', '3499275615', 'NULL', 0),
('CSLSML74D04I927D', 'Casulla', 'Samuele', '1974-04-04', 'M', '3121485045', 'NULL', 0),
('CSMGVF75D51B107K', 'Cosimini', 'Genoveffa', '1975-04-11', 'F', '3938483616', 'genoveffa.cosimini@alice.it', 0),
('CSMMRK10R28C654B', 'Casamassa', 'Mirko', '2010-10-28', 'M', '3238879406', 'mirko.casamassa@virgilio.it', 0),
('CSMVNN77E63G989P', 'Cusma', 'Vanna', '1977-05-23', 'F', '3290068660', 'NULL', 0),
('CSNCNL61E54B450B', 'Cusani', 'Cornelia', '1961-05-14', 'F', '3154292268', 'NULL', 0.05),
('CSNDLF73R23H347X', 'Cusano', 'Adolfo', '1973-10-23', 'M', '3144015923', 'NULL', 0),
('CSNFRC14B13H669P', 'Cosentino', 'Federico', '2014-02-13', 'M', '3596641987', 'federico.cosentino@virgilio.it', 0),
('CSNLRZ64D22H486D', 'Casini', 'Lucrezio', '1964-04-22', 'M', '3231577852', 'NULL', 0),
('CSNTZN52D57H710M', 'Ciusani', 'Tiziana', '1952-04-17', 'F', '3396991641', 'NULL', 0),
('CSNVND86S41I437J', 'Cesano', 'Vanda', '1986-11-01', 'F', '3925687379', 'NULL', 0),
('CSSLSN88B22G237G', 'Cassetti', 'Alessandro', '1988-02-22', 'M', '3718113825', 'NULL', 0),
('CSSMRK81E26D451Y', 'Cossutta', 'Mirko', '1981-05-26', 'M', '3673343987', 'NULL', 0),
('CSSMSM02M09D495R', 'Cassetto', 'Massimo', '2002-08-09', 'M', '3907576155', 'NULL', 0),
('CSSRSR09P30C633V', 'Cassandri', 'Rosario', '2009-09-30', 'M', '3518508741', 'rosario.cassandri@alice.it', 0),
('CSSSFO85T42G267F', 'Cossu', 'Sofia', '1985-12-02', 'F', '3294747103', 'sofia.cossu@gmail.com', 0),
('CSSTST79H20M272E', 'Cassera', 'Tristano ', '1979-06-20', 'M', '3754519951', 'NULL', 0.25),
('CSSVGL50M05C813Z', 'Cassarotto', 'Virgilio', '1950-08-05', 'M', '3760240932', 'virgilio.cassarotto@pec.it', 0),
('CSTBLD65M21E135B', 'Castracane', 'Ubaldo', '1965-08-21', 'M', '3951845393', 'NULL', 0),
('CSTDRA94M03A901P', 'Castorino', 'Dario', '1994-08-03', 'M', '3146718266', 'NULL', 0),
('CSTGCH40B27L017J', 'Castrioti', 'Gioacchino', '1940-02-27', 'M', '3230862353', 'NULL', 0),
('CSTLCI45A57H484B', 'Castrini', 'Licia', '1945-01-17', 'F', '3371820272', 'NULL', 0),
('CSTLGU71H16C457L', 'Castrovillari', 'Luigi', '1971-06-16', 'M', '3157845972', 'NULL', 0.25),
('CSTLND64M31M032C', 'Castrino', 'Lando', '1964-08-31', 'M', '3009716545', 'lando.castrino@outlook.it', 0),
('CSTMBR44H66G538C', 'Castronovo', 'Ambra', '1944-06-26', 'F', '3764487470', 'NULL', 0),
('CSTMLE13R15L396U', 'Costanzi', 'Emilio', '2013-10-15', 'M', '3198827748', 'NULL', 0),
('CSTNZE43E07H652R', 'Costa', 'Enzo', '1943-05-07', 'M', '3260840991', 'NULL', 0),
('CSTQMD60B20C641J', 'Cisternino', 'Quasimodo', '1960-02-20', 'M', '3504075210', 'NULL', 0.05),
('CSTRGR60H67A218K', 'Castellano', 'Ruggera', '1960-06-27', 'F', '3945702424', 'NULL', 0),
('CSTRNN06B48E115F', 'Castriota', 'Ermanna', '2006-02-08', 'F', '3189618849', 'ermanna.castriota@alice.it', 0.2),
('CSTSML45L70E639X', 'Castrini', 'Samuela', '1945-07-30', 'F', '3233264217', 'NULL', 0),
('CTAGTR53D26F880F', 'Cato', 'Gualtiero', '1953-04-26', 'M', '3340556272', 'NULL', 0),
('CTIPRM75S12L325V', 'Citi', 'Primo', '1975-11-12', 'M', '3904047269', 'NULL', 0),
('CTLMLN93C56M085K', 'Catalini', 'Melania', '1993-03-16', 'F', '3447920074', 'NULL', 0.2),
('CTLSNT44A52H128H', 'Cutolo', 'Samantha', '1944-01-12', 'F', '3308546406', 'NULL', 0),
('CTNGCH71H15C587V', 'Catena', 'Gioacchino', '1971-06-15', 'M', '3046308662', 'NULL', 0),
('CTNLIO52A53H880V', 'Catani', 'Iole', '1952-01-13', 'F', '3517850540', 'NULL', 0),
('CTNLRD07B20C078C', 'Catenazzo', 'Leonardo', '2007-02-20', 'M', '3662988002', 'NULL', 0.15),
('CTNLRI42R21C120T', 'Catino', 'Ilario', '1942-10-21', 'M', '3121770330', 'NULL', 0.3),
('CTNMRM94M68I133G', 'Cateni', 'Miriam', '1994-08-28', 'F', '3027946165', 'NULL', 0.15),
('CTODVG10S47I608Z', 'Coti', 'Edvige', '2010-11-07', 'F', '3090535848', 'NULL', 0),
('CTOGNZ45E25L958Y', 'Coti', 'Ignazio', '1945-05-25', 'M', '3633678136', 'ignazio.coti@pec.it', 0.1),
('CTRCTN16C05H716V', 'Cutarelli', 'Costantino', '2016-03-05', 'M', '3392058816', 'costantino.cutarelli@outlook.it', 0),
('CTRDRD73R05L823W', 'Cotruffo', 'Edoardo', '1973-10-05', 'M', '3498014718', 'NULL', 0.2),
('CTRLFA82L24I798P', 'Cetrone', 'Alfo', '1982-07-24', 'M', '3848984550', 'NULL', 0),
('CTRPRD03A18B778X', 'Cetrone', 'Paride', '2003-01-18', 'M', '3829227681', 'paride.cetrone@gmail.com', 0),
('CTRRLF50D30I604K', 'Cetro', 'Rodolfo', '1950-04-30', 'M', '3312115611', 'NULL', 0.15),
('CTTDLM92T21D420H', 'Ciotti', 'Adelmo', '1992-12-21', 'M', '3064577014', 'adelmo.ciotti@outlook.it', 0.2),
('CTTFMN13L26H716I', 'Citteri', 'Flaminio', '2013-07-26', 'M', '3280020701', 'flaminio.citteri@pec.it', 0),
('CTTPIA55M43L282S', 'Ciotto', 'Pia', '1955-08-03', 'F', '3336739436', 'NULL', 0),
('CTTSMN75T28G669K', 'Coatto', 'Simone', '1975-12-28', 'M', '3417485260', 'NULL', 0),
('CTTSRG56S02B128Y', 'Cetto', 'Sergio', '1956-11-02', 'M', '3803424958', 'sergio.cetto@virgilio.it', 0),
('CTZCRL47R55E685U', 'Cotza', 'Carla', '1947-10-15', 'F', '3411462790', 'NULL', 0),
('CTZYLO86M60C466P', 'Catzula', 'Yole', '1986-08-20', 'F', '3967976214', 'NULL', 0),
('CVAMRA67M58C404B', 'Cava', 'Maria', '1967-08-18', 'F', '3753845242', 'NULL', 0.25),
('CVCNTS47H59I196L', 'Cavicchiolo', 'Anastasia', '1947-06-19', 'F', '3676970246', 'NULL', 0),
('CVCSST49R25L424W', 'Cavicchioli', 'Sebastiano', '1949-10-25', 'M', '3148237279', 'sebastiano.cavicchioli@alice.it', 0),
('CVGFNC95B47F136I', 'Caviglia', 'Franca', '1995-02-07', 'F', '3260953513', 'NULL', 0.1),
('CVGRRT60C65B989T', 'Cavaglià', 'Roberta', '1960-03-25', 'F', '3545914079', 'NULL', 0.2),
('CVLLDN04M03D324I', 'Cavallini', 'Aldino', '2004-08-03', 'M', '3732013447', 'aldino.cavallini@alice.it', 0),
('CVLMDA07T30D419F', 'Civiello', 'Amadeo', '2007-12-30', 'M', '3226115450', 'NULL', 0),
('CVLTLI88B13B473Q', 'Cavalli', 'Italo', '1988-02-13', 'M', '3247008586', 'italo.cavalli@gmail.com', 0),
('CVNCMN47T20L943Z', 'Covini', 'Carmine', '1947-12-20', 'M', '3491827813', 'NULL', 0),
('CVNLRT67P01L971S', 'Cavanna', 'Loreto', '1967-09-01', 'M', '3971874573', 'NULL', 0.2),
('CVNNMO15L50M106D', 'Covoni', 'Noemi', '2015-07-10', 'F', '3926789166', 'NULL', 0),
('CVOVLR05B65I914N', 'Cova', 'Valeria', '2005-02-25', 'F', '3526062028', 'NULL', 0.05),
('CVRLGR15M57M411O', 'Covre', 'Allegra', '2015-08-17', 'F', '3719861041', 'allegra.covre@alice.it', 0.3),
('CVRLLN61A61E354G', 'Civardi', 'Liliana', '1961-01-21', 'F', '3287249458', 'NULL', 0.1),
('CVRRTT49B49L593L', 'Civardi', 'Rosetta', '1949-02-09', 'F', '3531070509', 'rosetta.civardi@pec.it', 0.05),
('CVTLRT84P28I690C', 'Cavuoti', 'Albertino', '1984-09-28', 'M', '3670419331', 'NULL', 0),
('CVTNNE15S25C332W', 'Cavuto', 'Ennio', '2015-11-25', 'M', '3956600962', 'NULL', 0),
('CVTRML06R04I786C', 'Iacovetti', 'Romolo', '2006-10-04', 'M', '3499882614', 'NULL', 0),
('CVTSML54B68F831A', 'Civitella', 'Samuela', '1954-02-28', 'F', '3432863419', 'NULL', 0.1),
('CVZCLD73E24G340M', 'Cavezzi', 'Cataldo', '1973-05-24', 'M', '3302816000', 'NULL', 0),
('CVZCLD77M68L117Y', 'Cavazzini', 'Claudia', '1977-08-28', 'F', '3762302725', 'NULL', 0.1),
('CVZLNU85T45I027B', 'Cavazzini', 'Luana', '1985-12-05', 'F', '3030682200', 'NULL', 0.25),
('CZZCST61A48C880A', 'Cazzoli', 'Cristiana', '1961-01-08', 'F', '3201180367', 'cristiana.cazzoli@alice.it', 0),
('CZZDLB92P59F549A', 'Caizzi', 'Doralba', '1992-09-19', 'F', '3032804960', 'NULL', 0),
('CZZGFR03P18C352F', 'Cozzolino', 'Goffredo', '2003-09-18', 'M', '3715405206', 'NULL', 0),
('CZZNCL66C16D817I', 'Cuzzocrea', 'Nicola', '1966-03-16', 'M', '3537216357', 'NULL', 0),
('DBERNN67E67F877N', 'De Bei', 'Rosanna', '1967-05-27', 'F', '3758820792', 'NULL', 0.05),
('DBNLSN81E50I444Z', 'Di Boni', 'Luisiana', '1981-05-10', 'F', '3826807157', 'NULL', 0),
('DBNSDR80C23E976U', 'De Bianchi', 'Sandro', '1980-03-23', 'M', '3245169942', 'NULL', 0),
('DBRFLV14A51F394I', 'DAbrosca', 'Fulvia', '2014-01-11', 'F', '3850889495', 'fulvia.dabrosca@gmail.com', 0.05),
('DBRGLL45H24G834M', 'De Berardis', 'Guglielmo', '1945-06-24', 'M', '3397712065', 'NULL', 0.1),
('DCEGVF71H57G282Q', 'De Iaco', 'Genoveffa', '1971-06-17', 'F', '3975119041', 'genoveffa.deiaco@virgilio.it', 0.1),
('DCHGLL48L43H361V', 'Di Chio', 'Gisella', '1948-07-03', 'F', '3298479371', 'NULL', 0),
('DCILCL87T10C883D', 'Iudica', 'Lucilio', '1987-12-10', 'M', '3497617953', 'NULL', 0.05),
('DCLGNN08S62L938I', 'Di Cola', 'Giovanna', '2008-11-22', 'F', '3838067654', 'NULL', 0.2),
('DCNLFA84A19C230G', 'Dicandia', 'Alfo', '1984-01-19', 'M', '3581594668', 'NULL', 0),
('DCNNBL78P25B635Y', 'Diacono', 'Annibale', '1978-09-25', 'M', '3527650415', 'NULL', 0),
('DCNNLM70D08C624Z', 'DAcunto', 'Anselmo', '1970-04-08', 'M', '3281666455', 'anselmo.dacunto@outlook.it', 0.1),
('DCRBRC47E61B413Z', 'Di Cristofori', 'Beatrice', '1947-05-21', 'F', '3937984157', 'beatrice.dicristofori@gmail.com', 0.2),
('DCRFLV14E65M096M', 'Di Cara', 'Flavia', '2014-05-25', 'F', '3038342191', 'NULL', 0.15),
('DCRFNC61P16G340T', 'De Cristofano', 'Francesco', '1961-09-16', 'M', '3466984560', 'NULL', 0),
('DCRGTV46B27G234L', 'De Cara', 'Gustavo', '1946-02-27', 'M', '3193230027', 'NULL', 0),
('DCRLRA14D46G040A', 'De Caria', 'Laura', '2014-04-06', 'F', '3468800334', 'NULL', 0),
('DCRVGN70B42H154J', 'Di Cristofori', 'Virginia', '1970-02-02', 'F', '3240144305', 'NULL', 0),
('DCRVTR41C26F249G', 'Di Cara', 'Vittoriano', '1941-03-26', 'M', '3390491851', 'vittoriano.dicara@pec.it', 0),
('DCSBDT01S12I238Z', 'Dei Cas', 'Benedetto', '2001-11-12', 'M', '3851627503', 'NULL', 0),
('DCURTI81R42C665H', 'Duce', 'Rita', '1981-10-02', 'F', '3475770298', 'rita.duce@alice.it', 0.1),
('DDCPCC48E28B574K', 'Adduce', 'Pinuccio', '1948-05-28', 'M', '3894628601', 'pinuccio.adduce@pec.it', 0),
('DDIDLN14P48H505I', 'Di Deo', 'Adelina', '2014-09-08', 'F', '3381754914', 'NULL', 0),
('DDNLNI75E54F917C', 'Didone', 'Ileana', '1975-05-14', 'F', '3236623574', 'NULL', 0),
('DDTTMS88L61L295Y', 'Adeodato', 'Tommasina', '1988-07-21', 'F', '3315510557', 'NULL', 0.2),
('DEIMRZ16M55C354K', 'Dei', 'Marzia', '2016-08-15', 'F', '3277903282', 'NULL', 0),
('DFBLCU70H03M379G', 'De Fabio', 'Lucio', '1970-06-03', 'M', '3006123098', 'lucio.defabio@gmail.com', 0.25),
('DFBMRG00H18B865L', 'Di Febo', 'Amerigo', '2000-06-18', 'M', '3506627130', 'NULL', 0),
('DFBVTI99A01F987H', 'De Fabiis', 'Vito', '1999-01-01', 'M', '3899984602', 'NULL', 0),
('DFBYND46D42G392N', 'De Fabiis', 'Yolanda', '1946-04-02', 'F', '3791537396', 'NULL', 0.1),
('DFDRKE85R43F935X', 'Di Federico', 'Erika', '1985-10-03', 'F', '3615240873', 'NULL', 0.05),
('DFDVNC93H64G482Q', 'Di Federico', 'Veronica', '1993-06-24', 'F', '3780986006', 'veronica.difederico@virgilio.it', 0.3),
('DFLCST42E45C189N', 'De Felice', 'Cristina', '1942-05-05', 'F', '3460985374', 'NULL', 0.25),
('DFLGGR99E11F939O', 'Di Falco', 'Gregorio', '1999-05-11', 'M', '3696142094', 'NULL', 0),
('DFLMIA60M51M031X', 'De Florio', 'Mia', '1960-08-11', 'F', '3598118523', 'mia.deflorio@pec.it', 0),
('DFNPLA65R28C276Z', 'Defende', 'Paolo', '1965-10-28', 'M', '3896940005', 'NULL', 0.3),
('DGDCDD44M10D995H', 'De Giudici', 'Candido', '1944-08-10', 'M', '3347916956', 'NULL', 0),
('DGDRMO63C18I550J', 'Dei Giudici', 'Romeo', '1963-03-18', 'M', '3197306164', 'NULL', 0),
('DGLGLL67L10E497B', 'Degli Osti', 'Guglielmo', '1967-07-10', 'M', '3952746329', 'NULL', 0),
('DGLSNT57C70G114T', 'Degli Esposti', 'Samanta', '1957-03-30', 'F', '3002421281', 'NULL', 0.1),
('DGNLNZ82T22I678Y', 'Dignani', 'Lorenzo', '1982-12-22', 'M', '3519262071', 'NULL', 0.3),
('DGNSLL68M51C254D', 'Dignani', 'Isabella', '1968-08-11', 'F', '3537814082', 'NULL', 0),
('DGRLNE11E66I785D', 'Di Grandi', 'Eleana', '2011-05-26', 'F', '3275100469', 'NULL', 0),
('DGRMRC64L56H766B', 'Degregori', 'America', '1964-07-16', 'F', '3767562855', 'america.degregori@gmail.com', 0),
('DGSGRZ83D56C525N', 'Digesu', 'Grazia', '1983-04-16', 'F', '3648655805', 'NULL', 0),
('DGSMDA92D25B925W', 'Di Giusto', 'Amadeo', '1992-04-25', 'M', '3762549885', 'NULL', 0),
('DGSMTT71C02D449F', 'Digesu', 'Mattia', '1971-03-02', 'M', '3185233274', 'NULL', 0),
('DGTVSS81S50C937D', 'De Gaetani', 'Vanessa', '1981-11-10', 'F', '3695696754', 'NULL', 0),
('DHELNE90P66G271R', 'Deho', 'Eleana', '1990-09-26', 'F', '3382636356', 'NULL', 0.25),
('DJNLCA62H13M424W', 'Dejana', 'Alceo', '1962-06-13', 'M', '3493100163', 'NULL', 0.25),
('DLBNRN98R54D634D', 'Dal Borgo', 'Andreina', '1998-10-14', 'F', '3852059129', 'NULL', 0.25),
('DLBSRI70A52E483E', 'Del Bianco', 'Siria', '1970-01-12', 'F', '3884276800', 'siria.delbianco@pec.it', 0),
('DLCDLE62T50D016N', 'De Luca', 'Delia', '1962-12-10', 'F', '3343904711', 'NULL', 0),
('DLCMNI59D13I640Y', 'Di Luca', 'Mino', '1959-04-13', 'M', '3228362657', 'NULL', 0),
('DLCMRZ81H51B489T', 'Dilecce', 'Marzia', '1981-06-11', 'F', '3626129878', 'NULL', 0),
('DLCRND75C30L893K', 'Dolcemaschio', 'Raimondo', '1975-03-30', 'M', '3273353354', 'NULL', 0),
('DLCVGL44E16I156G', 'Dolcetta', 'Virgilio', '1944-05-16', 'M', '3220701378', 'NULL', 0.2),
('DLDMRN84M68A956J', 'Dal Dosso', 'Morena', '1984-08-28', 'F', '3119843191', 'NULL', 0),
('DLESVT45E11D011Z', 'DElia', 'Salvatore', '1945-05-11', 'M', '3312150153', 'NULL', 0),
('DLGCMN48T17M425V', 'Del Grosso', 'Carmine', '1948-12-17', 'M', '3283461412', 'NULL', 0.1),
('DLLCPI73P24L200I', 'Dellabella', 'Iacopo', '1973-09-24', 'M', '3684003239', 'NULL', 0),
('DLLDLD77P54F845K', 'Dallolio', 'Adelaide', '1977-09-14', 'F', '3477987576', 'adelaide.dallolio@alice.it', 0),
('DLLGST53D26C006N', 'De Lelli', 'Egisto', '1953-04-26', 'M', '3957683373', 'NULL', 0.05),
('DLLLNE91H58D325P', 'DellAia', 'Eleana', '1991-06-18', 'F', '3976072182', 'NULL', 0),
('DLLLRT95T01B444T', 'Della Monica', 'Albertino', '1995-12-01', 'M', '3024419475', 'albertino.dellamonica@gmail.com', 0),
('DLLLVC59A09B924S', 'Dalla Monica', 'Ludovico', '1959-01-09', 'M', '3123635347', 'ludovico.dallamonica@pec.it', 0),
('DLLMCL05C10I611J', 'Delle Grottaglie', 'Marcello', '2005-03-10', 'M', '3429126370', 'marcello.dellegrottaglie@pec.it', 0),
('DLLMCL55S69I264F', 'Della Giustina', 'Marcella', '1955-11-29', 'F', '3920815784', 'NULL', 0),
('DLLMCL95D55G587P', 'DellEra', 'Marcella', '1995-04-15', 'F', '3194226105', 'marcella.dellera@outlook.it', 0),
('DLLMDA53S06H070W', 'DellErba', 'Amadeo', '1953-11-06', 'M', '3957314030', 'NULL', 0),
('DLLNMO49E45L461H', 'Dallabora', 'Noemi', '1949-05-05', 'F', '3897674639', 'NULL', 0.1),
('DLLPIA57C71A405G', 'Della Vedova', 'Pia', '1957-03-31', 'F', '3789555234', 'NULL', 0),
('DLLSBN96D55B351O', 'DellAcqua', 'Sabina', '1996-04-15', 'F', '3889060380', 'NULL', 0),
('DLLSLV54M02L032V', 'Della Ratta', 'Silvio', '1954-08-02', 'M', '3475613571', 'NULL', 0.25),
('DLLSND86H22L075O', 'Delle Fratte', 'Secondo', '1986-06-22', 'M', '3225333180', 'secondo.dellefratte@alice.it', 0.1),
('DLMDNC63S23A815D', 'Delmati', 'Domenico', '1963-11-23', 'M', '3361083660', 'domenico.delmati@outlook.it', 0.25),
('DLMGPP54E26A577K', 'Delmiglio', 'Giuseppe', '1954-05-26', 'M', '3501048579', 'NULL', 0),
('DLMSDR85L43E066N', 'Dolmetta', 'Isidora', '1985-07-03', 'F', '3655224357', 'NULL', 0),
('DLNDRN62H46A946Z', 'DAlonso', 'Doriana', '1962-06-06', 'F', '3831274254', 'doriana.dalonso@gmail.com', 0),
('DLNLRT15R50L613Z', 'Di Leonardis', 'Alberta', '2015-10-10', 'F', '3681101152', 'NULL', 0),
('DLPVND56D42B766J', 'Del Piano', 'Vanda', '1956-04-02', 'F', '3043563583', 'NULL', 0),
('DLRRCL49D28H655P', 'Delorenzis', 'Ercole', '1949-04-28', 'M', '3819384445', 'NULL', 0),
('DLSBNT11P25H220A', 'Deluis', 'Benito', '2011-09-25', 'M', '3335896548', 'NULL', 0),
('DLSBRM45E21H509N', 'DAlessio', 'Abramo', '1945-05-21', 'M', '3806660976', 'NULL', 0),
('DLSNZR07R16H945E', 'DEliso', 'Nazzareno', '2007-10-16', 'M', '3044979614', 'NULL', 0),
('DLSSTR01A67D293Z', 'Di Luisi', 'Ester', '2001-01-27', 'F', '3714457680', 'ester.diluisi@outlook.it', 0),
('DLTFLV89T13C632H', 'DAltiero', 'Fulvio', '1989-12-13', 'M', '3739653786', 'NULL', 0),
('DLTMMM04S53L788C', 'Del Tufo', 'Mimma', '2004-11-13', 'F', '3029082922', 'NULL', 0.25),
('DLTSFO16S50G992M', 'Diolaiuti', 'Sofia', '2016-11-10', 'F', '3871633401', 'NULL', 0),
('DMBRNN64E05D639W', 'DAmbra', 'Ermanno', '1964-05-05', 'M', '3142316144', 'NULL', 0),
('DMCLNR59P53I035E', 'Dimichele', 'Eleonora', '1959-09-13', 'F', '3055008497', 'NULL', 0),
('DMCPRZ73T09E490U', 'Di Micco', 'Patrizio', '1973-12-09', 'M', '3223915405', 'NULL', 0),
('DMCWND62B44I145U', 'DAmicis', 'Wanda', '1962-02-04', 'F', '3424220697', 'wanda.damicis@outlook.it', 0.2),
('DMGQMD10A04H340W', 'Di Maggio', 'Quasimodo', '2010-01-04', 'M', '3851592319', 'NULL', 0),
('DMLDLN47S54H505O', 'Adamoli', 'Adelina', '1947-11-14', 'F', '3580168089', 'NULL', 0),
('DMNSLL01E60C812N', 'Damiano', 'Isabella', '2001-05-20', 'F', '3046990513', 'NULL', 0),
('DMNVGN82D41A952V', 'Demonte', 'Verginia', '1982-04-01', 'F', '3818306985', 'NULL', 0.3),
('DMRLRD54E31H114R', 'De Martiis', 'Alfredino', '1954-05-31', 'M', '3868964481', 'NULL', 0),
('DMRRNN66B57A166L', 'De Maria', 'Ermanna', '1966-02-17', 'F', '3299100842', 'NULL', 0.25),
('DMRSRA57B01F556H', 'Di Mari', 'Saro', '1957-02-01', 'M', '3149390196', 'saro.dimari@gmail.com', 0),
('DMRVNT45R62H717G', 'Di Marcantonio', 'Valentina', '1945-10-22', 'F', '3681957186', 'NULL', 0),
('DMSGNR46M24E961T', 'De Maestri', 'Gennaro', '1946-08-24', 'M', '3822144768', 'NULL', 0),
('DMSTZN49H27E700G', 'Di Massa', 'Tiziano', '1949-06-27', 'M', '3443534979', 'tiziano.dimassa@pec.it', 0),
('DMTCRL66H28C137F', 'De Metri', 'Carlo', '1966-06-28', 'M', '3248360637', 'NULL', 0.15),
('DMTCSR91D02E451M', 'Dametti', 'Cesare', '1991-04-02', 'M', '3891183032', 'cesare.dametti@pec.it', 0.1),
('DMTMCL65R56C343Z', 'DAmato', 'Immacolata', '1965-10-16', 'F', '3614729940', 'NULL', 0.2),
('DMTMTA56E50F665C', 'Demattio', 'Amata', '1956-05-10', 'F', '3851374451', 'amata.demattio@outlook.it', 0),
('DMTNLN86M18H186A', 'DAmato', 'Napoleone', '1986-08-18', 'M', '3698490030', 'NULL', 0),
('DNCGRM95E15C456B', 'Di Nicola', 'Geremia', '1995-05-15', 'M', '3595725924', 'NULL', 0),
('DNDLLD56P22A305Q', 'Donida', 'Leopoldo', '1956-09-22', 'M', '3217050076', 'NULL', 0),
('DNGPRZ87E56A070R', 'Don Giovanni', 'Patrizia', '1987-05-16', 'F', '3965975039', 'NULL', 0),
('DNGRND15A18L434D', 'Denigris', 'Orlando', '2015-01-18', 'M', '3339647229', 'orlando.denigris@alice.it', 0.2),
('DNGTNZ75P12A306W', 'Dionigio', 'Terenzio', '1975-09-12', 'M', '3041118659', 'NULL', 0),
('DNGTTV50T03H420M', 'Dongiovanni', 'Ottavio', '1950-12-03', 'M', '3362449841', 'NULL', 0.1),
('DNGVNZ89C41C719X', 'Dongo', 'Vicenza', '1989-03-01', 'F', '3602837608', 'vicenza.dongo@outlook.it', 0),
('DNIMRN75A65H716Y', 'Dini', 'Morena', '1975-01-25', 'F', '3761595133', 'NULL', 0.15),
('DNLSLL91D48F130O', 'DAniello', 'Isabella', '1991-04-08', 'F', '3754971091', 'isabella.daniello@alice.it', 0),
('DNNBNR75B06B024Y', 'Di Nunna', 'Bernardo', '1975-02-06', 'M', '3990431353', 'NULL', 0.25),
('DNNCNZ74H47H329B', 'Denni', 'Cinzia', '1974-06-07', 'F', '3623028632', 'NULL', 0.2),
('DNNFBA72E07G492P', 'De Anna', 'Fabio', '1972-05-07', 'M', '3047517474', 'NULL', 0),
('DNNFLV63H63I809K', 'Donnoli', 'Fulvia', '1963-06-23', 'F', '3424389555', 'fulvia.donnoli@pec.it', 0),
('DNNGST02R09F569Y', 'De Ianni', 'Giusto', '2002-10-09', 'M', '3628593660', 'NULL', 0),
('DNNGTN13H03B030C', 'Danna', 'Giustino', '2013-06-03', 'M', '3581437367', 'NULL', 0),
('DNNLRT76A04F258P', 'Dianni', 'Liberato', '1976-01-04', 'M', '3417687407', 'NULL', 0),
('DNNLSN73B16C351W', 'DAnnibale', 'Alessandrino', '1973-02-16', 'M', '3962298296', 'NULL', 0),
('DNNMLN03D08L158E', 'Donna', 'Emiliano', '2003-04-08', 'M', '3338637168', 'NULL', 0),
('DNNMRN47A29H081Z', 'De Ianni', 'Mariano', '1947-01-29', 'M', '3666095346', 'mariano.deianni@gmail.com', 0),
('DNNNLM04D29C528K', 'Donnoli', 'Anselmo', '2004-04-29', 'M', '3996582722', 'anselmo.donnoli@virgilio.it', 0),
('DNONLC82M67H888J', 'Dono', 'Angelica', '1982-08-27', 'F', '3454015471', 'angelica.dono@gmail.com', 0),
('DNRGRM59P11A425A', 'De Naro', 'Geremia', '1959-09-11', 'M', '3130772217', 'geremia.denaro@alice.it', 0.05),
('DNSVTT93A69H842R', 'Dainese', 'Violetta', '1993-01-29', 'F', '3890770182', 'NULL', 0),
('DNTZEI69C31C621X', 'Danti', 'Ezio', '1969-03-31', 'M', '3363848619', 'NULL', 0.15),
('DPECHR08H50D690X', 'Depau', 'Chiara', '2008-06-10', 'F', '3475803163', 'chiara.depau@alice.it', 0),
('DPLRND68R07G808C', 'Di Polo', 'Orlando', '1968-10-07', 'M', '3567921058', 'NULL', 0),
('DPLSDR98M04G476F', 'De Paoli', 'Isidoro', '1998-08-04', 'M', '3961456554', 'NULL', 0),
('DPMLNI81E59H365L', 'De Pompeis', 'Lina', '1981-05-19', 'F', '3709158888', 'lina.depompeis@pec.it', 0),
('DPNLSS89L28B368N', 'Depinè', 'Alessio', '1989-07-28', 'M', '3404520129', 'NULL', 0),
('DPNVGN55D55F280X', 'Depine', 'Virginia', '1955-04-15', 'F', '3699797438', 'NULL', 0),
('DPRRBN07T65D528I', 'DAprea', 'Rubina', '2007-12-25', 'F', '3222178723', 'NULL', 0),
('DPSFBN62E41H443F', 'De Pascalis', 'Fabiana', '1962-05-01', 'F', '3155364873', 'NULL', 0),
('DPSMHL14M30F116R', 'DEpiscopo', 'Michele', '2014-08-30', 'M', '3120567731', 'NULL', 0.3),
('DPSMRK42L43D697E', 'Dipasquale', 'Mirka', '1942-07-03', 'F', '3897880103', 'NULL', 0),
('DPSSLV50S01I878Z', 'Di Pascale', 'Silvio', '1950-11-01', 'M', '3652037440', 'NULL', 0),
('DRAFMN46E42D752U', 'Dare', 'Filomena', '1946-05-02', 'F', '3856828280', 'NULL', 0.15),
('DRBNLN40D20C206R', 'Derobertis', 'Angelino', '1940-04-20', 'M', '3641258443', 'NULL', 0.1),
('DRGGGN89S14C723V', 'Drago', 'Gigino', '1989-11-14', 'M', '3044204963', 'NULL', 0.2),
('DRHPQN98B25D673V', 'De Raho', 'Pasquino', '1998-02-25', 'M', '3180555035', 'NULL', 0.25),
('DRLGZZ57D17F686O', 'Darello', 'Galeazzo', '1957-04-17', 'M', '3401265588', 'galeazzo.darello@gmail.com', 0.3),
('DRLVVN89H05B352S', 'DOrlando', 'Viviano', '1989-06-05', 'M', '3770687064', 'NULL', 0),
('DRNGST69S22H552Y', 'Adornetto', 'Giusto', '1969-11-22', 'M', '3593906382', 'NULL', 0.2),
('DRNSND69M14G188O', 'Durando', 'Secondo', '1969-08-14', 'M', '3683259996', 'secondo.durando@alice.it', 0),
('DROCST91M61L220D', 'Doro', 'Cristina', '1991-08-21', 'F', '3753880392', 'NULL', 0),
('DRSFBN59S69I150Z', 'DOrso', 'Fabiana', '1959-11-29', 'F', '3252583128', 'NULL', 0),
('DR�LRC78B14L397U', 'Da Rè', 'Alarico', '1978-02-14', 'M', '3012562224', 'NULL', 0),
('DR�RFL74E65F340B', 'De Ré', 'Raffaella', '1974-05-25', 'F', '3160124323', 'NULL', 0),
('DR�SML43E14A286A', 'De Rè', 'Samuele', '1943-05-14', 'M', '3815288150', 'NULL', 0),
('DSBGPP66H66H152V', 'Disabato', 'Giuseppina', '1966-06-26', 'F', '3257602145', 'NULL', 0.25),
('DSCVLR47B26I985Z', 'DAscoli', 'Valerio', '1947-02-26', 'M', '3991304998', 'NULL', 0.3),
('DSDPRD55H11E328W', 'Desiderio', 'Paride', '1955-06-11', 'M', '3126883982', 'NULL', 0),
('DSENGL43R11D611J', 'De Iasi', 'Angelo', '1943-10-11', 'M', '3129235438', 'NULL', 0),
('DSGGLL64P27L357M', 'Desogos', 'Guglielmo', '1964-09-27', 'M', '3374573717', 'guglielmo.desogos@pec.it', 0.05),
('DSNGFR67D26A225R', 'De Santis', 'Goffredo', '1967-04-26', 'M', '3899185526', 'NULL', 0),
('DSNMRT69B66D137W', 'Desiena', 'Umberta', '1969-02-26', 'F', '3828116239', 'umberta.desiena@gmail.com', 0),
('DSPLNZ03S68E911V', 'Dispinzieri', 'Lorenza', '2003-11-28', 'F', '3553791748', 'NULL', 0),
('DSPNDA88T55C732E', 'Dispirito', 'Nadia', '1988-12-15', 'F', '3007592276', 'NULL', 0.15),
('DSTCLD03D17H769Y', 'De Stazio', 'Claudio', '2003-04-17', 'M', '3879673136', 'NULL', 0.05),
('DSTMCL11B65A546P', 'De Stazio', 'Immacolata', '2011-02-25', 'F', '3541664668', 'immacolata.destazio@pec.it', 0),
('DSTTMR81T64E288W', 'Distaso', 'Tamara', '1981-12-24', 'F', '3580639395', 'NULL', 0.25),
('DSTVTR57R50F299J', 'De Astis', 'Vittoria', '1957-10-10', 'F', '3518946137', 'NULL', 0.2),
('DTRCLL52B27B482E', 'Di Trapani', 'Catello', '1952-02-27', 'M', '3352769806', 'NULL', 0),
('DTTDGS82E63F214J', 'Dutti', 'Adalgisa', '1982-05-23', 'F', '3201613568', 'NULL', 0),
('DTTTNO15H61D237T', 'Deotto', 'Tonia', '2015-06-21', 'F', '3866934310', 'tonia.deotto@outlook.it', 0.3),
('DVCNLT54T05L483S', 'De Vecchio', 'Anacleto', '1954-12-05', 'M', '3542527187', 'anacleto.devecchio@gmail.com', 0),
('DVNLNZ85L68L643M', 'DAvanzo', 'Lorenza', '1985-07-28', 'F', '3904023866', 'NULL', 0.05),
('DVRDVG67M60F387J', 'De Virgilio', 'Edvige', '1967-08-20', 'F', '3896941220', 'edvige.devirgilio@gmail.com', 0),
('DVRLNE14L20I322A', 'Di Virgilio', 'Leone', '2014-07-20', 'M', '3065853179', 'leone.divirgilio@alice.it', 0),
('DVRSRA05S67L947A', 'Di Virgilio', 'Sara', '2005-11-27', 'F', '3726669476', 'NULL', 0),
('DVTLRZ62T28D828Z', 'Di Vietro', 'Lucrezio', '1962-12-28', 'M', '3930240016', 'NULL', 0),
('DVTPCC44E25F537J', 'De Vitis', 'Pinuccio', '1944-05-25', 'M', '3879262195', 'NULL', 0),
('DVTRCR87B10F622G', 'Devota', 'Riccardo', '1987-02-10', 'M', '3825513950', 'riccardo.devota@alice.it', 0),
('DVTRSN98B65B663F', 'Di Vita', 'Rossana', '1998-02-25', 'F', '3949195143', 'NULL', 0),
('DVVSTR82C42D624V', 'Devivo', 'Ester', '1982-03-02', 'F', '3539277856', 'ester.devivo@outlook.it', 0.25),
('DZZLRC85L13F410Y', 'Dazzo', 'Alarico', '1985-07-13', 'M', '3980435005', 'NULL', 0.25),
('FBAMRC40A56D775D', 'Fabio', 'America', '1940-01-16', 'F', '3372014823', 'america.fabio@outlook.it', 0),
('FBBGVF79D42D835L', 'Fabbi', 'Genoveffa', '1979-04-02', 'F', '3089764698', 'genoveffa.fabbi@outlook.it', 0),
('FBBLND59E29C835J', 'Fabbiano', 'Olindo', '1959-05-29', 'M', '3904393687', 'NULL', 0.2),
('FBBRMN45E15A139T', 'Fabbrica', 'Erminio', '1945-05-15', 'M', '3454758268', 'NULL', 0.15),
('FBBRMN62H65L154K', 'Fabbri', 'Romana', '1962-06-25', 'F', '3485977502', 'NULL', 0),
('FB�NLT06L41H769M', 'FabÈn', 'Nicoletta', '2006-07-01', 'F', '3735862233', 'NULL', 0),
('FCCSNT86H11B466V', 'Fucci', 'Sante', '1986-06-11', 'M', '3230086514', 'NULL', 0),
('FCHTST75A15F926G', 'Fichera', 'Tristano ', '1975-01-15', 'M', '3788505921', 'tristano.fichera@pec.it', 0),
('FDDDAA84T61B630M', 'Foddai', 'Ada', '1984-12-21', 'F', '3057774130', 'NULL', 0),
('FDDGDE91B04H926M', 'Foddai', 'Egidio', '1991-02-04', 'M', '3661943550', 'egidio.foddai@gmail.com', 0),
('FDDGIA77R13H928H', 'Foddai', 'Iago', '1977-10-13', 'M', '3799553500', 'iago.foddai@pec.it', 0.05),
('FDNGMN83T57C560X', 'Fidanzi', 'Germana', '1983-12-17', 'F', '3831517761', 'NULL', 0.05),
('FDRBRT60E56G338B', 'Federici', 'Berta', '1960-05-16', 'F', '3781888565', 'NULL', 0),
('FGGCRI17L25C794L', 'Faggi', 'Ciro', '2017-07-25', 'M', '3207072020', 'NULL', 0),
('FGGRRT97A07M067E', 'Fogagnolo', 'Roberto', '1997-01-07', 'M', '3223226844', 'roberto.fogagnolo@alice.it', 0),
('FGGVCN78S50A713L', 'Fogagnolo', 'Vincenza', '1978-11-10', 'F', '3044039338', 'NULL', 0.05),
('FGLFMN66P56G751B', 'Foglia', 'Flaminia', '1966-09-16', 'F', '3127178959', 'NULL', 0.2),
('FGLRMN45B10H184H', 'Figliola', 'Romano', '1945-02-10', 'M', '3038202480', 'NULL', 0.1),
('FGLSVG14P42H071K', 'Fogli', 'Selvaggia', '2014-09-02', 'F', '3350218008', 'NULL', 0.3),
('FGRMRT51S19I248U', 'Figura', 'Umberto', '1951-11-19', 'M', '3415943592', 'umberto.figura@outlook.it', 0.3),
('FLCFBA49S05E995U', 'Falaci', 'Fabio', '1949-11-05', 'M', '3605550521', 'NULL', 0),
('FLCFTN49T03D651T', 'Falconetti', 'Faustino', '1949-12-03', 'M', '3185919934', 'NULL', 0),
('FLCLDA71M22L677K', 'Folchini', 'Aldo', '1971-08-22', 'M', '3295837269', 'NULL', 0.1),
('FLCNEE10S08E145D', 'Fulconis', 'Enea', '2010-11-08', 'M', '3708355594', 'NULL', 0.3),
('FLCRCR96H28C791F', 'Falchero', 'Riccardo', '1996-06-28', 'M', '3286538936', 'NULL', 0),
('FLCRSL67S53A207H', 'Flacco', 'Rossella', '1967-11-13', 'F', '3619478480', 'NULL', 0),
('FLGVDN65A41A825J', 'Folgheraiter', 'Veridiana', '1965-01-01', 'F', '3194658900', 'NULL', 0.25),
('FLLCST69B46E900A', 'Fella', 'Cristina', '1969-02-06', 'F', '3268529649', 'cristina.fella@outlook.it', 0),
('FLLDNI05S59E131G', 'Filiali', 'Diana', '2005-11-19', 'F', '3913369197', 'NULL', 0),
('FLLLND16A28A249Q', 'Fulla', 'Leonida', '2016-01-28', 'M', '3707101146', 'NULL', 0),
('FLLRMR45P65B876C', 'Felletto', 'Rosamaria', '1945-09-25', 'F', '3362634372', 'rosamaria.felletto@outlook.it', 0),
('FLNPLT13D18E782Q', 'Filoni', 'Ippolito', '2013-04-18', 'M', '3111882072', 'NULL', 0),
('FLNSDR74B10D258L', 'Folino', 'Isidoro', '1974-02-10', 'M', '3789832765', 'NULL', 0),
('FLRCRI47D04D103O', 'Floresta', 'Icaro', '1947-04-04', 'M', '3487042751', 'NULL', 0),
('FLRMNL51M69F814M', 'Florean', 'Emanuela', '1951-08-29', 'F', '3611264630', 'NULL', 0),
('FLRSTN62H59L655Z', 'Florestano', 'Santina', '1962-06-19', 'F', '3630541033', 'NULL', 0),
('FLSNLC45T52E187S', 'Filisetti', 'Angelica', '1945-12-12', 'F', '3184388709', 'NULL', 0.1),
('FLZLVC74S17A082F', 'Falzone', 'Ludovico', '1974-11-17', 'M', '3722318670', 'NULL', 0.25),
('FMNMLN02H28G489D', 'Fiumani', 'Emiliano', '2002-06-28', 'M', '3579284074', 'emiliano.fiumani@alice.it', 0),
('FMNRBN98D55B466E', 'Fiumani', 'Rubina', '1998-04-15', 'F', '3398254750', 'NULL', 0),
('FMUMRL84L03D234W', 'Fumei', 'Maurilio', '1984-07-03', 'M', '3533019236', 'NULL', 0.3),
('FMURCC62T69G691X', 'Fumo', 'Rebecca', '1962-12-29', 'F', '3609174479', 'NULL', 0.25),
('FNCGRM46T22L014L', 'Fanciullacci', 'Geremia', '1946-12-22', 'M', '3612874196', 'NULL', 0.3),
('FNCMDL56E68B541C', 'Finco', 'Maddalena', '1956-05-28', 'F', '3163877028', 'NULL', 0.15),
('FNCMME64H64C351A', 'Finocchiaro', 'Emma', '1964-06-24', 'F', '3371665972', 'NULL', 0),
('FNCVTI58L27E737D', 'Finocchiaro', 'Vito', '1958-07-27', 'M', '3465245727', 'vito.finocchiaro@outlook.it', 0),
('FNNLBN58R22L590K', 'Fanini', 'Albino', '1958-10-22', 'M', '3021480857', 'NULL', 0),
('FNTFCT05L49G194Y', 'Fantin', 'Felicita', '2005-07-09', 'F', '3426753084', 'felicita.fantin@outlook.it', 0.15),
('FNTGIA52M03B629O', 'Fantecchi', 'Iago', '1952-08-03', 'M', '3379660359', 'NULL', 0),
('FNTLND97S64I887Z', 'Fontanari', 'Iolanda', '1997-11-24', 'F', '3400204438', 'NULL', 0),
('FNTTTI44L27F939L', 'Fantoni', 'Tito', '1944-07-27', 'M', '3187377097', 'NULL', 0.1),
('FNZDLL51C42E527B', 'Fenzini', 'Dalila', '1951-03-02', 'F', '3458534222', 'NULL', 0),
('FNZLND01P22G420J', 'Fanizzo', 'Olindo', '2001-09-22', 'M', '3578200485', 'NULL', 0),
('FNZVTR10T41F175O', 'Finzi', 'Vittorina', '2010-12-01', 'F', '3535882621', 'NULL', 0),
('FPPMGH76S60F697X', 'Fappani', 'Margherita', '1976-11-20', 'F', '3591865707', 'NULL', 0.05),
('FRCFLV74A45L942P', 'Fracassi', 'Fulvia', '1974-01-05', 'F', '3771033048', 'NULL', 0.3),
('FRCRNL68P69A957X', 'Africano', 'Reginella', '1968-09-29', 'F', '3085477932', 'NULL', 0),
('FRGFNC73T41I533L', 'Frignani', 'Francesca', '1973-12-01', 'F', '3297844814', 'NULL', 0),
('FRGGNT73L05H379N', 'Fregna', 'Giacinto', '1973-07-05', 'M', '3571100217', 'NULL', 0),
('FRGGTV08R08B310C', 'Fragala', 'Gustavo', '2008-10-08', 'M', '3376441591', 'NULL', 0.15),
('FRGLVO55B52L194H', 'Feruglio', 'Olivia', '1955-02-12', 'F', '3415498419', 'olivia.feruglio@gmail.com', 0),
('FRGMNC78H66G638D', 'Fragiacomo', 'Monica', '1978-06-26', 'F', '3147135929', 'NULL', 0),
('FRGPQN42T14I982A', 'Fregonesi', 'Pasquino', '1942-12-14', 'M', '3663169468', 'NULL', 0),
('FRICAI75A24H980B', 'Fiori', 'Caio', '1975-01-24', 'M', '3351168795', 'NULL', 0.05),
('FRIPCC46T02H969E', 'Fiora', 'Pinuccio', '1946-12-02', 'M', '3374397478', 'pinuccio.fiora@gmail.com', 0),
('FRJCLL08P28E868T', 'Frijo', 'Catello', '2008-09-28', 'M', '3184292559', 'NULL', 0),
('FRLGBR02C28C995B', 'Furlano', 'Gilberto', '2002-03-28', 'M', '3273441834', 'gilberto.furlano@virgilio.it', 0),
('FRLNLT54S05L201Y', 'Fraiola', 'Anacleto', '1954-11-05', 'M', '3571618479', 'anacleto.fraiola@alice.it', 0.1),
('FRLRMR69M61B150L', 'Fiorilli', 'Rosamaria', '1969-08-21', 'F', '3579558892', 'NULL', 0),
('FRLRRT43C50E423T', 'Furlano', 'Roberta', '1943-03-10', 'F', '3125041776', 'NULL', 0.15),
('FRLVIO69H07H183M', 'Fiorello', 'Ivo', '1969-06-07', 'M', '3350087963', 'NULL', 0),
('FRMCRL46P49I008K', 'Formichella', 'Carola', '1946-09-09', 'F', '3583414906', 'NULL', 0),
('FRMGNR83T09B194L', 'Frumento', 'Gennaro', '1983-12-09', 'M', '3402892577', 'NULL', 0),
('FRMNGL46M67I074M', 'Formigari', 'Angela', '1946-08-27', 'F', '3999368007', 'NULL', 0),
('FRMPML95P56E552M', 'Formichella', 'Pamela', '1995-09-16', 'F', '3363514594', 'NULL', 0),
('FRNDNL68A03F004A', 'Franchi', 'Daniele', '1968-01-03', 'M', '3780804820', 'NULL', 0),
('FRNGRD13P16H365S', 'Fornoni', 'Gerardo', '2013-09-16', 'M', '3910166117', 'gerardo.fornoni@pec.it', 0),
('FRNGTN60M66E769D', 'Faronato', 'Gaetana', '1960-08-26', 'F', '3750501118', 'NULL', 0),
('FRNLBR86T31B732Q', 'Francini', 'Lamberto', '1986-12-31', 'M', '3271092237', 'NULL', 0),
('FRNLRN58C44E233K', 'Farnesi', 'Lorena', '1958-03-04', 'F', '3157485088', 'NULL', 0),
('FRNMDA42H25I577B', 'Francese', 'Amadeo', '1942-06-25', 'M', '3802420085', 'NULL', 0),
('FRNMRG78D65I261Q', 'Fiorentina', 'Ambrogia', '1978-04-25', 'F', '3543117324', 'ambrogia.fiorentina@pec.it', 0),
('FRNPLT59D30D662U', 'Franzoi', 'Ippolito', '1959-04-30', 'M', '3234419329', 'NULL', 0),
('FRNPRD93M14D924H', 'Francola', 'Paride', '1993-08-14', 'M', '3132996440', 'NULL', 0),
('FRNPRI89L45I346I', 'Fornello', 'Piera', '1989-07-05', 'F', '3164985328', 'piera.fornello@alice.it', 0),
('FRNPSQ89S49F740D', 'Francescatti', 'Pasqua', '1989-11-09', 'F', '3266031350', 'NULL', 0),
('FRNPTR13E09E775O', 'Franchi', 'Pietro', '2013-05-09', 'M', '3801926297', 'NULL', 0),
('FRNSRA72H54I158C', 'Fiorini', 'Sara', '1972-06-14', 'F', '3977938216', 'NULL', 0),
('FRNSST02M44F573J', 'Frances', 'Sebastiana', '2002-08-04', 'F', '3101894634', 'sebastiana.frances@gmail.com', 0),
('FRNTCR89H09D764K', 'Farinaro', 'Tancredi', '1989-06-09', 'M', '3442686755', 'NULL', 0.1),
('FRNTLL81S02M116T', 'Furian', 'Otello', '1981-11-02', 'M', '3102795587', 'NULL', 0),
('FRNTZN55L51C076B', 'Fiorenzo', 'Tiziana', '1955-07-11', 'F', '3249379480', 'tiziana.fiorenzo@pec.it', 0),
('FRRCML40M06C700B', 'Ferragutti', 'Carmelo', '1940-08-06', 'M', '3694956779', 'NULL', 0),
('FRRDNA99D03A735I', 'Ferruggia', 'Adone', '1999-04-03', 'M', '3860596639', 'NULL', 0),
('FRRDRT90L49G135K', 'Ferrazzo', 'Dorotea', '1990-07-09', 'F', '3732521005', 'NULL', 0.3),
('FRRFMN08C63C791Z', 'Ferrieri', 'Filomena', '2008-03-23', 'F', '3995130686', 'NULL', 0.25),
('FRRFNC54E48A387Q', 'Ferraro', 'Francesca', '1954-05-08', 'F', '3226694968', 'NULL', 0),
('FRRFNZ63D04L202N', 'Ferrone', 'Fiorenzo', '1963-04-04', 'M', '3381371356', 'NULL', 0),
('FRRGST67P06A561E', 'Fraracci', 'Egisto', '1967-09-06', 'M', '3967344333', 'NULL', 0.3),
('FRRGUO54D13I721D', 'Ferraro', 'Ugo', '1954-04-13', 'M', '3534464440', 'NULL', 0.1),
('FRRLRI45D11I537Y', 'Ferreti', 'Ilario', '1945-04-11', 'M', '3675817772', 'NULL', 0),
('FRRMRA66H62H910H', 'Ferraboli', 'Mara', '1966-06-22', 'F', '3326647635', 'NULL', 0),
('FRRMRA80D45F249G', 'Ferraioli', 'Mara', '1980-04-05', 'F', '3883106719', 'NULL', 0),
('FRRNRN01E23L333Q', 'Ferragutti', 'Nerone', '2001-05-23', 'M', '3497167125', 'NULL', 0),
('FRRSDR42L31G178A', 'Ferraiuolo', 'Isidoro', '1942-07-31', 'M', '3275114060', 'NULL', 0),
('FRRSRN46C43L883X', 'Farris', 'Siriana', '1946-03-03', 'F', '3740206373', 'NULL', 0.15),
('FRRSVT66L20M189Y', 'Ferrazzoli', 'Salvatore', '1966-07-20', 'M', '3748772569', 'NULL', 0),
('FRRSVT68C17G146A', 'Ferraro', 'Salvatore', '1968-03-17', 'M', '3654916219', 'NULL', 0.3),
('FRRVRN62R44I170E', 'Ferraro', 'Valeriana', '1962-10-04', 'F', '3758135402', 'NULL', 0),
('FRSFBN48R24M339J', 'Frisanco', 'Fabiano', '1948-10-24', 'M', '3652956845', 'NULL', 0),
('FRSMRT52S01G943Q', 'Foresti', 'Umberto', '1952-11-01', 'M', '3480682798', 'NULL', 0.1),
('FRTMRA17D58B633Y', 'Fratini', 'Maria', '2017-04-18', 'F', '3127737826', 'NULL', 0),
('FRTMRA72T23E625K', 'Fiorot', 'Mario', '1972-12-23', 'M', '3662615023', 'mario.fiorot@pec.it', 0),
('FRVFDN06P41L455N', 'Faravolo', 'Ferdinanda', '2006-09-01', 'F', '3380369934', 'NULL', 0.1),
('FRZGST96M47D814G', 'Frezzolini', 'Augusta', '1996-08-07', 'F', '3852570538', 'NULL', 0),
('FRZLVN53H69A432I', 'Frezzi', 'Lavinia', '1953-06-29', 'F', '3551813970', 'NULL', 0),
('FRZMTN07D65E896R', 'Frezzi', 'Martina', '2007-04-25', 'F', '3774069472', 'NULL', 0),
('FSCMRG48S24G561X', 'Foschiatti', 'Ambrogio', '1948-11-24', 'M', '3526196834', 'NULL', 0),
('FSCVEA69A48L014G', 'Foschiatto', 'Eva', '1969-01-08', 'F', '3951789873', 'NULL', 0),
('FSCVTR99S68E386H', 'Fiaschi', 'Vittorina', '1999-11-28', 'F', '3572955210', 'vittorina.fiaschi@outlook.it', 0.1),
('FSNBLD09T05F701O', 'Fusinato', 'Ubaldo', '2009-12-05', 'M', '3975795739', 'NULL', 0.15),
('FTAGDE57P47L916M', 'Faeta', 'Egidia', '1957-09-07', 'F', '3053788163', 'NULL', 0),
('FTALSN75E08H443Q', 'Faeti', 'Alessandro', '1975-05-08', 'M', '3243613462', 'NULL', 0),
('FVLMRC05B03H695N', 'Favillo', 'Marco', '2005-02-03', 'M', '3245895694', 'marco.favillo@pec.it', 0.2),
('FVRGZZ50E06B463A', 'Faverio', 'Galeazzo', '1950-05-06', 'M', '3857155642', 'NULL', 0.25),
('FZZLVS57E17I618I', 'Fozzati', 'Alvise', '1957-05-17', 'M', '3431346407', 'NULL', 0),
('GBBGDE78E43A560U', 'Gabbani', 'Egidia', '1978-05-03', 'F', '3364352476', 'NULL', 0),
('GBBLND03T12C740U', 'Gobbo', 'Lindo', '2003-12-12', 'M', '3773306264', 'NULL', 0),
('GBBLRZ01L22C722V', 'Gobbi', 'Lucrezio', '2001-07-22', 'M', '3805433663', 'NULL', 0.1),
('GBRMHL49H45B632K', 'Gaburri', 'Michela', '1949-06-05', 'F', '3524611201', 'NULL', 0),
('GBRTMS86E52G333Q', 'Gaburro', 'Tommasina', '1986-05-12', 'F', '3023656072', 'NULL', 0),
('GCBGCM64P05L245E', 'Giacobazzi', 'Giacomo', '1964-09-05', 'M', '3870107191', 'giacomo.giacobazzi@gmail.com', 0),
('GCBGLI76P24A579J', 'Giacobbi', 'Gioele', '1976-09-24', 'M', '3878124696', 'NULL', 0),
('GCCBRN59L30F595K', 'Giacco', 'Bruno', '1959-07-30', 'M', '3005485181', 'NULL', 0.05),
('GCIGBR78E29F023B', 'Giaco', 'Gilberto', '1978-05-29', 'M', '3472228141', 'NULL', 0),
('GCMCDD72S41E389S', 'Giacomotti', 'Candida', '1972-11-01', 'F', '3524535716', 'NULL', 0),
('GCMVDN64T52G044J', 'Giacomello', 'Verdiana', '1964-12-12', 'F', '3214703022', 'verdiana.giacomello@outlook.it', 0.1),
('GDALVC06M52H050N', 'Gadia', 'Ludovica', '2006-08-12', 'F', '3179417716', 'NULL', 0),
('GDDVCN43A58L522C', 'Gaddo', 'Vincenza', '1943-01-18', 'F', '3132516054', 'NULL', 0),
('GDEMLI82P09A154G', 'Egidi', 'Milo', '1982-09-09', 'M', '3085689768', 'NULL', 0),
('GDLVSC89L20L111A', 'Gaudiello', 'Vasco', '1989-07-20', 'M', '3436378884', 'NULL', 0),
('GDNRNI79M66I249E', 'Gaudini', 'Irene', '1979-08-26', 'F', '3212460848', 'irene.gaudini@gmail.com', 0),
('GFFMLN43L27D369E', 'Goffi', 'Emiliano', '1943-07-27', 'M', '3232995186', 'emiliano.goffi@virgilio.it', 0.05),
('GGLGBB50H18F272A', 'Guglielmoni', 'Giacobbe', '1950-06-18', 'M', '3140456971', 'NULL', 0.15),
('GGLGLI52D27L859K', 'Gaglio', 'Gioele', '1952-04-27', 'M', '3269610430', 'gioele.gaglio@alice.it', 0.3),
('GGLMRZ47A11F951P', 'Guglielmetti', 'Maurizio', '1947-01-11', 'M', '3310275980', 'NULL', 0.05),
('GGLMSM72P15H428E', 'Gugliotto', 'Massimo', '1972-09-15', 'M', '3743525275', 'NULL', 0),
('GGLSRI49H41F238A', 'Agugliari', 'Siria', '1949-06-01', 'F', '3311751908', 'siria.agugliari@alice.it', 0),
('GGNTLD58S65A042Z', 'Gigante', 'Tilde', '1958-11-25', 'F', '3673980916', 'NULL', 0),
('GGULEA94M43C565P', 'Ugge', 'Lea', '1994-08-03', 'F', '3281836313', 'lea.ugge@alice.it', 0.15),
('GHNGMN74E49H644N', 'Ghini', 'Germana', '1974-05-09', 'F', '3788652396', 'NULL', 0),
('GHRLRI09D27F217R', 'Ghirello', 'Ilario', '2009-04-27', 'M', '3070651965', 'NULL', 0),
('GHRVNC97P55E102B', 'Ghirardello', 'Veronica', '1997-09-15', 'F', '3426438244', 'veronica.ghirardello@outlook.it', 0),
('GHSGGN99H04I074T', 'Ghislanzoni', 'Gigino', '1999-06-04', 'M', '3887828884', 'gigino.ghislanzoni@virgilio.it', 0),
('GHSLNS91E16I889E', 'Ghislieri', 'Alfonsino', '1991-05-16', 'M', '3576802040', 'NULL', 0.2),
('GHSPLT90R02G255F', 'Ghisi', 'Ippolito', '1990-10-02', 'M', '3040757557', 'NULL', 0.25),
('GHSSRN55C60B871A', 'Ghislanzoni', 'Serena', '1955-03-20', 'F', '3495934760', 'NULL', 0.3),
('GHSTNZ53S25E415M', 'Ghisleri', 'Terenzio', '1953-11-25', 'M', '3593342760', 'NULL', 0),
('GHZNBR74L17C694X', 'Ghezzi', 'Norberto', '1974-07-17', 'M', '3635722125', 'NULL', 0),
('GHZPNG48P41B377M', 'Ghezzo', 'Pierangela', '1948-09-01', 'F', '3584402416', 'pierangela.ghezzo@alice.it', 0),
('GLBMNL58S20H942M', 'Golob', 'Emanuele', '1958-11-20', 'M', '3712476253', 'NULL', 0.25),
('GLBMTA01L49A354A', 'Golob', 'Amata', '2001-07-09', 'F', '3839610253', 'amata.golob@outlook.it', 0),
('GLBSNO12H70E899C', 'Giliberto', 'Sonia', '2012-06-30', 'F', '3643404075', 'NULL', 0),
('GLDGTR60R46G568A', 'Goldi', 'Geltrude', '1960-10-06', 'F', '3818728388', 'NULL', 0),
('GLDTTR89D14E072P', 'Goldone', 'Ettore', '1989-04-14', 'M', '3095392374', 'ettore.goldone@virgilio.it', 0),
('GLFLSN08B10G268S', 'Golfieri', 'Alessandrino', '2008-02-10', 'M', '3321331737', 'NULL', 0),
('GLLFRZ15S23A795D', 'Gellera', 'Fabrizio', '2015-11-23', 'M', '3963246160', 'NULL', 0),
('GLLGDN54C13D430Y', 'Galletto', 'Giordano', '1954-03-13', 'M', '3129530558', 'giordano.galletto@virgilio.it', 0.2),
('GLLLNI63H44E370G', 'Iagulli', 'Ileana', '1963-06-04', 'F', '3936582280', 'NULL', 0.3),
('GLLLRZ89B53E397V', 'Galliazzo', 'Lucrezia', '1989-02-13', 'F', '3087699894', 'NULL', 0),
('GLLVGN54L41G167D', 'Gallelli', 'Verginia', '1954-07-01', 'F', '3870042791', 'NULL', 0.05),
('GLMSNT59T56E647P', 'Galimberto', 'Samanta', '1959-12-16', 'F', '3564666301', 'NULL', 0),
('GLNFTM90R41C957Z', 'Golin', 'Fatima', '1990-10-01', 'F', '3882877478', 'NULL', 0.3),
('GLNGTN76S23D932Z', 'Gulini', 'Gaetano', '1976-11-23', 'M', '3035711292', 'gaetano.gulini@outlook.it', 0),
('GLNRNN88P63D529W', 'Galieno', 'Rosanna', '1988-09-23', 'F', '3705902588', 'rosanna.galieno@outlook.it', 0),
('GLNVVN64S63A191N', 'Golinelli', 'Viviana', '1964-11-23', 'F', '3631645530', 'NULL', 0),
('GLPGND49H30H157W', 'Galuppini', 'Giocondo', '1949-06-30', 'M', '3155023937', 'giocondo.galuppini@outlook.it', 0),
('GLRCTN82R03C768N', 'Galiardi', 'Costanzo', '1982-10-03', 'M', '3402489758', 'NULL', 0.25),
('GLRDLF12T07A467H', 'Galardo', 'Adolfo', '2012-12-07', 'M', '3106707560', 'NULL', 0),
('GLRLDN52H57E191C', 'Gilardo', 'Loredana', '1952-06-17', 'F', '3620680442', 'NULL', 0),
('GLRTTI92A01L368M', 'Galardi', 'Tito', '1992-01-01', 'M', '3922814980', 'NULL', 0),
('GLTGLE63T52L508J', 'Galata', 'Egle', '1963-12-12', 'F', '3729138469', 'NULL', 0.05),
('GLVTST08A08G944Z', 'Galvanin', 'Tristano ', '2008-01-08', 'M', '3713778252', 'NULL', 0),
('GLZTLI51T27E660X', 'Galizi', 'Italo', '1951-12-27', 'M', '3847358420', 'NULL', 0),
('GMBFRC41P29A329E', 'Gambella', 'Federico', '1941-09-29', 'M', '3570051516', 'federico.gambella@alice.it', 0.2),
('GMBPRI77A31C768A', 'Gambacorta', 'Piero', '1977-01-31', 'M', '3138318779', 'NULL', 0.25),
('GMBRRT41E63M070U', 'Gambaro', 'Roberta', '1941-05-23', 'F', '3904767369', 'NULL', 0),
('GMGGNN82A55D237T', 'Gemignano', 'Giovanna', '1982-01-15', 'F', '3754280362', 'NULL', 0),
('GMMFLR83C71H693N', 'Giammusso', 'Flora', '1983-03-31', 'F', '3326428697', 'NULL', 0.1),
('GMMLVR88B08B400K', 'Gammi', 'Alvaro', '1988-02-08', 'M', '3935764583', 'NULL', 0),
('GMMPRL74E67C988A', 'Giammusso', 'Perla', '1974-05-27', 'F', '3944170931', 'perla.giammusso@outlook.it', 0),
('GNCDNC73D08D195Z', 'Giancristoforo', 'Domenico', '1973-04-08', 'M', '3211664937', 'NULL', 0),
('GNCLNI92S59I322Z', 'Gnocchi', 'Ilenia', '1992-11-19', 'F', '3808055357', 'ilenia.gnocchi@pec.it', 0),
('GNCPLP80T43A083X', 'Gianicolo', 'Penelope', '1980-12-03', 'F', '3393577287', 'NULL', 0.1),
('GNDCLL49H21C452G', 'Gandossi', 'Achille', '1949-06-21', 'M', '3732429716', 'NULL', 0),
('GNDRLN97P62G448T', 'Gandelli', 'Rosalinda', '1997-09-22', 'F', '3929506738', 'NULL', 0),
('GNECDD70L55C189P', 'Genio', 'Candida', '1970-07-15', 'F', '3125019658', 'NULL', 0),
('GNFDNT77L19E535K', 'Gianfranceschi', 'Donato', '1977-07-19', 'M', '3701364032', 'NULL', 0.25),
('GNGCTN94H16E160L', 'Gangemi', 'Costanzo', '1994-06-16', 'M', '3343274431', 'costanzo.gangemi@outlook.it', 0.15),
('GNGGST16L23F912B', 'Gangale', 'Giusto', '2016-07-23', 'M', '3043628199', 'giusto.gangale@gmail.com', 0),
('GNLMLN84D42E429G', 'Agnolo', 'Milena', '1984-04-02', 'F', '3555672338', 'NULL', 0),
('GNLNZE51B60G838K', 'Gianoli', 'Enza', '1951-02-20', 'F', '3767077605', 'NULL', 0.15),
('GNNBLD05D05D312U', 'Giannone', 'Ubaldo', '2005-04-05', 'M', '3478378209', 'NULL', 0),
('GNNLDA65P12I865L', 'Gennari', 'Aldo', '1965-09-12', 'M', '3003509274', 'NULL', 0.3),
('GNNLLE49C31D560M', 'Giannino', 'Lelio', '1949-03-31', 'M', '3318167277', 'NULL', 0),
('GNNLNZ67T25D849U', 'Giannoni', 'Lorenzo', '1967-12-25', 'M', '3285453150', 'NULL', 0),
('GNNPML49S66I422L', 'Genino', 'Pamela', '1949-11-26', 'F', '3301500528', 'NULL', 0.3),
('GNNSRN83B65C900W', 'Gnoni', 'Sabrina', '1983-02-25', 'F', '3161729574', 'sabrina.gnoni@alice.it', 0),
('GNNVLR01R41D604B', 'Aguniano', 'Valeria', '2001-10-01', 'F', '3604488703', 'NULL', 0.15),
('GNOCLN85S57B145E', 'Gon', 'Carolina', '1985-11-17', 'F', '3023230060', 'carolina.gon@alice.it', 0),
('GNSPCR40S11H156W', 'Gnesetti', 'Pancrazio', '1940-11-11', 'M', '3288838965', 'pancrazio.gnesetti@alice.it', 0),
('GNTGTN83C48A745D', 'Giuntino', 'Gaetana', '1983-03-08', 'F', '3672942823', 'NULL', 0),
('GNTSNT11E65E429I', 'Gentinetta', 'Samanta', '2011-05-25', 'F', '3761139363', 'samanta.gentinetta@virgilio.it', 0),
('GNXRRA41E42H488T', 'Ginex', 'Aurora', '1941-05-02', 'F', '3894615742', 'NULL', 0),
('GNZBSL02R04C469D', 'Ignazio', 'Basilio', '2002-10-04', 'M', '3914418612', 'basilio.ignazio@gmail.com', 0),
('GNZGMN81A50B966C', 'Ganzerla', 'Germana', '1981-01-10', 'F', '3649677216', 'germana.ganzerla@virgilio.it', 0),
('GNZRSO01B64G702J', 'Ganzerla', 'Rosa', '2001-02-24', 'F', '3186713580', 'NULL', 0.15);
INSERT INTO `pazienti` (`CF`, `Cognome`, `Nome`, `Data_Nascita`, `Genere`, `Recapito`, `E-mail`, `Sconto`) VALUES
('GNZSRI52E48H047F', 'Gonzaga', 'Siria', '1952-05-08', 'F', '3295217444', 'NULL', 0),
('GQNCRL43S03F182R', 'Giaquinta', 'Carlo', '1943-11-03', 'M', '3865472019', 'carlo.giaquinta@alice.it', 0.1),
('GQNTMS61B21D695I', 'Giaquinta', 'Tommaso', '1961-02-21', 'M', '3121354987', 'NULL', 0),
('GRBCML88P49A396T', 'Garbati', 'Carmela', '1988-09-09', 'F', '3165105972', 'NULL', 0.1),
('GRBCMN49R52D990F', 'Garbellini', 'Clementina', '1949-10-12', 'F', '3750280549', 'NULL', 0),
('GRBDVG53D66B856F', 'Garbati', 'Edvige', '1953-04-26', 'F', '3161355944', 'NULL', 0),
('GRBGZZ86T12G198J', 'Gerboni', 'Galeazzo', '1986-12-12', 'M', '3082559249', 'NULL', 0),
('GRBLND69M14G771S', 'Guariberto', 'Lindo', '1969-08-14', 'M', '3338297973', 'NULL', 0),
('GRBWND62P41F352T', 'Garbati', 'Wanda', '1962-09-01', 'F', '3273849631', 'NULL', 0.25),
('GRCBRC67T47A662B', 'Gerace', 'Beatrice', '1967-12-07', 'F', '3925401721', 'beatrice.gerace@outlook.it', 0),
('GRCMTN64L52L146J', 'Gracchi', 'Martina', '1964-07-12', 'F', '3446369825', 'NULL', 0),
('GRECSS57T04F739G', 'Gero', 'Cassio', '1957-12-04', 'M', '3303473690', 'NULL', 0.25),
('GREMRC86C24G040M', 'Gero', 'Marco', '1986-03-24', 'M', '3940602250', 'NULL', 0.2),
('GRFBLD74M18G557X', 'Garuffo', 'Ubaldo', '1974-08-18', 'M', '3630934766', 'NULL', 0),
('GRFPMR60L63A394W', 'Garufi', 'Palmira', '1960-07-23', 'F', '3743821297', 'palmira.garufi@pec.it', 0.3),
('GRFRSR94R24A230O', 'Goreffi', 'Rosario', '1994-10-24', 'M', '3236671369', 'NULL', 0.25),
('GRGCTN79E31B410W', 'Gargiulo', 'Costantino', '1979-05-31', 'M', '3438614754', 'NULL', 0),
('GRGMLD11P63F267M', 'Gargiulo', 'Mafalda', '2011-09-23', 'F', '3941640203', 'NULL', 0),
('GRGSDI13B56B813B', 'Gorgone', 'Iside', '2013-02-16', 'F', '3590418955', 'NULL', 0),
('GRISVS02P06E392N', 'Gioria', 'Silvestro', '2002-09-06', 'M', '3589769917', 'NULL', 0.1),
('GRLLNZ73S52F608R', 'Grolli', 'Lorenza', '1973-11-12', 'F', '3374350365', 'NULL', 0),
('GRLMCL99M58M188T', 'Gerlini', 'Immacolata', '1999-08-18', 'F', '3113776702', 'immacolata.gerlini@virgilio.it', 0.25),
('GRLMND48B67F017F', 'Grelle', 'Miranda', '1948-02-27', 'F', '3934184533', 'miranda.grelle@virgilio.it', 0),
('GRLSDI87R70C483H', 'Garelli', 'Iside', '1987-10-30', 'F', '3778503917', 'NULL', 0),
('GRMBRC67S52B693H', 'Grimani', 'Beatrice', '1967-11-12', 'F', '3952210562', 'NULL', 0.25),
('GRMCTL66H70F338B', 'Grumelli', 'Clotilde', '1966-06-30', 'F', '3663091945', 'NULL', 0),
('GRMGNT56L24E973M', 'Germinara', 'Giacinto', '1956-07-24', 'M', '3534807633', 'NULL', 0),
('GRMLSN71B07E915E', 'Germi', 'Alessandrino', '1971-02-07', 'M', '3271698285', 'alessandrino.germi@gmail.com', 0),
('GRMMLE99A68L368N', 'Grimaldo', 'Emilia', '1999-01-28', 'F', '3677340047', 'NULL', 0.05),
('GRMRCR43B18I275Y', 'Germi', 'Riccardo', '1943-02-18', 'M', '3716810946', 'riccardo.germi@gmail.com', 0),
('GRMWLM89A57G624P', 'Grimoldi', 'Wilma', '1989-01-17', 'F', '3868542886', 'NULL', 0),
('GRMZEI54C13E844C', 'Germiniani', 'Ezio', '1954-03-13', 'M', '3962452995', 'ezio.germiniani@alice.it', 0),
('GRMZRR67H50B061X', 'Grimaudi', 'Azzurra', '1967-06-10', 'F', '3396963401', 'NULL', 0),
('GRNCDD89E01H945Q', 'Garnero', 'Candido', '1989-05-01', 'M', '3874145691', 'NULL', 0),
('GRNFBL00E50H856A', 'Grandinetto', 'Fabiola', '2000-05-10', 'F', '3262631256', 'NULL', 0),
('GRNFNN14E08D886L', 'Goriani', 'Fernando', '2014-05-08', 'M', '3817922597', 'NULL', 0),
('GRNGFR85L28C527P', 'Gariano', 'Goffredo', '1985-07-28', 'M', '3085304082', 'NULL', 0.1),
('GRNLRC77B54L305M', 'Garino', 'Ulderica', '1977-02-14', 'F', '3872363075', 'ulderica.garino@pec.it', 0.15),
('GRNMRS86L49L497I', 'Granzini', 'Marisa', '1986-07-09', 'F', '3836757201', 'NULL', 0),
('GRNNNI11L27H826E', 'Giorno', 'Nino', '2011-07-27', 'M', '3314339115', 'NULL', 0.3),
('GRNSDR92A60C165Q', 'Grani', 'Sandra', '1992-01-20', 'F', '3823482430', 'sandra.grani@pec.it', 0.25),
('GRNTLL50D07H460Q', 'Guarnaschelli', 'Otello', '1950-04-07', 'M', '3939555462', 'NULL', 0.1),
('GRNVSC63P11I499A', 'Grondona', 'Vasco', '1963-09-11', 'M', '3068253936', 'NULL', 0),
('GROBRN97M47D575M', 'Goria', 'Bruna', '1997-08-07', 'F', '3287187997', 'NULL', 0.15),
('GRRCHR86L42A160R', 'Guerrini', 'Chiara', '1986-07-02', 'F', '3487085956', 'NULL', 0),
('GRRGLN07B05A284C', 'Guerrini', 'Giuliano', '2007-02-05', 'M', '3434767948', 'NULL', 0),
('GRRLDL44D03B810O', 'Garreffa', 'Landolfo', '1944-04-03', 'M', '3500289333', 'NULL', 0),
('GRRLSI01C71A231P', 'Gorrara', 'Lisa', '2001-03-31', 'F', '3602047648', 'NULL', 0.1),
('GRRMTA86C51E284X', 'Garreffa', 'Amata', '1986-03-11', 'F', '3737893617', 'NULL', 0),
('GRRNZR11R07C971T', 'Giarratano', 'Nazzareno', '2011-10-07', 'M', '3775716858', 'NULL', 0),
('GRRRNI63S11E866E', 'Garro', 'Rino', '1963-11-11', 'M', '3062368512', 'NULL', 0.05),
('GRRVIO05C14I088V', 'Giarrizzo', 'Ivo', '2005-03-14', 'M', '3493776743', 'ivo.giarrizzo@virgilio.it', 0),
('GRSCMN90R65E785L', 'Grassia', 'Clementina', '1990-10-25', 'F', '3665024705', 'NULL', 0),
('GRSCRL60M65A348R', 'Gresta', 'Carola', '1960-08-25', 'F', '3234985824', 'NULL', 0),
('GRSDLR11H44D594D', 'Grispi', 'Addolorata', '2011-06-04', 'F', '3292715734', 'NULL', 0),
('GRSFNC68H19F563I', 'Gresti', 'Francesco', '1968-06-19', 'M', '3951630506', 'NULL', 0),
('GRSGTA79C45F922P', 'Grassani', 'Agata', '1979-03-05', 'F', '3529564781', 'NULL', 0),
('GRSGTN79E43H799V', 'Grassi', 'Agostina', '1979-05-03', 'F', '3360038942', 'agostina.grassi@virgilio.it', 0.25),
('GRSLBR96T17I613G', 'Grasso', 'Lamberto', '1996-12-17', 'M', '3457807539', 'NULL', 0),
('GRSNTL90T11B646X', 'Guarasco', 'Natale', '1990-12-11', 'M', '3348096621', 'NULL', 0),
('GRSPTR06M14G724D', 'Grisostomo', 'Pietro', '2006-08-14', 'M', '3953418898', 'pietro.grisostomo@gmail.com', 0.3),
('GRSVGN53S64I119K', 'Guereschi', 'Verginia', '1953-11-24', 'F', '3775149560', 'NULL', 0),
('GRSWND95S54M284T', 'Agreste', 'Wanda', '1995-11-14', 'F', '3859046296', 'NULL', 0.25),
('GRSZRA62T52G610L', 'Grespan', 'Zara', '1962-12-12', 'F', '3634020536', 'NULL', 0.2),
('GRTDLM64B25A449D', 'Grotti', 'Adelmo', '1964-02-25', 'M', '3529951080', 'NULL', 0.25),
('GRTFMN98H48H102H', 'Giurato', 'Flaminia', '1998-06-08', 'F', '3980167414', 'flaminia.giurato@virgilio.it', 0),
('GRTMLA16C47E015J', 'Giaretta', 'Amelia', '2016-03-07', 'F', '3233139626', 'NULL', 0.15),
('GRVFST41A65F829Z', 'Garavagli', 'Fausta', '1941-01-25', 'F', '3088019833', 'NULL', 0),
('GRVGMN64P17D882Y', 'Gravanti', 'Germano', '1964-09-17', 'M', '3464827823', 'NULL', 0),
('GRVLND83T70D700L', 'Garavaglia', 'Linda', '1983-12-30', 'F', '3580704762', 'linda.garavaglia@pec.it', 0),
('GRVLVC82B01B328L', 'Gervasini', 'Ludovico', '1982-02-01', 'M', '3993090082', 'NULL', 0),
('GRZCSN73R47M259S', 'Garzelli', 'Cassandra', '1973-10-07', 'F', '3343394006', 'NULL', 0.05),
('GRZGRT75T68B404M', 'Graziana', 'Greta', '1975-12-28', 'F', '3222864948', 'NULL', 0),
('GRZNDA69R47A292R', 'Grazioli', 'Nadia', '1969-10-07', 'F', '3336422717', 'nadia.grazioli@alice.it', 0),
('GSAMLD45R66F117P', 'Agus', 'Matilde', '1945-10-26', 'F', '3526219688', 'NULL', 0),
('GSLMCL97S01I260V', 'Gusella', 'Marcello', '1997-11-01', 'M', '3114916656', 'NULL', 0),
('GSLSMN77R12I062O', 'Gesuele', 'Simone', '1977-10-12', 'M', '3918484437', 'simone.gesuele@alice.it', 0),
('GSMMLD10A42E074X', 'Gusmeroli', 'Matilde', '2010-01-02', 'F', '3626855134', 'matilde.gusmeroli@virgilio.it', 0),
('GSMRTD88M08A146M', 'Gusmeroli', 'Aristide', '1988-08-08', 'M', '3910563979', 'NULL', 0.1),
('GSPSLM87M41L165S', 'Giuseppucci', 'Selma', '1987-08-01', 'F', '3496836449', 'NULL', 0),
('GSSDLE56L29E236Z', 'Goisis', 'Delio', '1956-07-29', 'M', '3056428243', 'NULL', 0),
('GSSLGR14A46E538V', 'Gussi', 'Allegra', '2014-01-06', 'F', '3523533056', 'allegra.gussi@pec.it', 0),
('GSSLNS15R24D818E', 'Gussone', 'Alfonso', '2015-10-24', 'M', '3698964751', 'NULL', 0.2),
('GSSMRT96A58B934O', 'Agasso', 'Marta', '1996-01-18', 'F', '3563273208', 'marta.agasso@pec.it', 0),
('GSTFNZ60S12G191P', 'Giusto', 'Fiorenzo', '1960-11-12', 'M', '3981330550', 'NULL', 0),
('GSTLSN56E27D667P', 'Agostini', 'Alessandrino', '1956-05-27', 'M', '3869411466', 'NULL', 0.2),
('GSTLVI59R64D783A', 'Guastello', 'Livia', '1959-10-24', 'F', '3340681939', 'NULL', 0),
('GSTMCL53E17L737K', 'Guastello', 'Marcello', '1953-05-17', 'M', '3277101214', 'NULL', 0),
('GS�YNN04M50H315R', 'Gesù', 'Yvonne', '2004-08-10', 'F', '3241847290', 'NULL', 0),
('GTARNN86T57G421H', 'Agati', 'Ermanna', '1986-12-17', 'F', '3240277886', 'NULL', 0.25),
('GTLGLR47T63E900E', 'Gotelli', 'Gloria', '1947-12-23', 'F', '3897856031', 'gloria.gotelli@gmail.com', 0.25),
('GTNCTN09H15G076X', 'Gaetano', 'Costanzo', '2009-06-15', 'M', '3975080234', 'NULL', 0),
('GTNMRZ06A60L470M', 'Gaetano', 'Marzia', '2006-01-20', 'F', '3692638438', 'NULL', 0),
('GTNVCN47P08H233X', 'Gaetani', 'Vincenzo', '1947-09-08', 'M', '3092551706', 'NULL', 0.3),
('GTTLLD07E06E927M', 'Gottarelli', 'Leopoldo', '2007-05-06', 'M', '3853668987', 'NULL', 0),
('GTTSLL09D57E940U', 'Gotto', 'Isabella', '2009-04-17', 'F', '3708326635', 'NULL', 0.2),
('GTTSNO47S66L233T', 'Guttadauro', 'Sonia', '1947-11-26', 'F', '3949854610', 'NULL', 0),
('GTTVNT88P64B740U', 'Gottardi', 'Violante', '1988-09-24', 'F', '3746862676', 'NULL', 0),
('GVNDNL64P12A937D', 'Gaviano', 'Danilo', '1964-09-12', 'M', '3029182735', 'NULL', 0),
('GVNFCN61P11F176W', 'Giovannone', 'Feliciano', '1961-09-11', 'M', '3910923718', 'feliciano.giovannone@pec.it', 0),
('GVNMRT52A46A520Q', 'Giovannotti', 'Umberta', '1952-01-06', 'F', '3594969777', 'NULL', 0),
('GVRGND13B15A107D', 'Governali', 'Giocondo', '2013-02-15', 'M', '3026138084', 'NULL', 0),
('GZZBBR77T41E148U', 'Gazzola', 'Barbara', '1977-12-01', 'F', '3226306875', 'NULL', 0),
('GZZDTR98D05B246P', 'Guizzari', 'Demetrio', '1998-04-05', 'M', '3338487447', 'NULL', 0),
('GZZFBL83P54E715X', 'Guzzino', 'Fabiola', '1983-09-14', 'F', '3737548252', 'fabiola.guzzino@pec.it', 0.3),
('GZZFLR95P41B086R', 'Guizzari', 'Flora', '1995-09-01', 'F', '3981447264', 'NULL', 0),
('GZZLLL46C15M427H', 'Guizzi', 'Lello', '1946-03-15', 'M', '3617728007', 'NULL', 0),
('GZZLSE58T50B430P', 'Agazzi', 'Elisa', '1958-12-10', 'F', '3055442373', 'elisa.agazzi@alice.it', 0),
('GZZNCN75B14M065C', 'Agazzino', 'Innocenzo', '1975-02-14', 'M', '3184390580', 'NULL', 0),
('GZZNNE99D17H594L', 'Gazzaniga', 'Ennio', '1999-04-17', 'M', '3645520811', 'NULL', 0.2),
('GZZNTN89R69F424J', 'Gazzera', 'Antonia', '1989-10-29', 'F', '3249775317', 'antonia.gazzera@alice.it', 0.1),
('GZZSFN55D66C040F', 'Guizzardi', 'Serafina', '1955-04-26', 'F', '3345423806', 'NULL', 0),
('GZZVGN83B10E258N', 'Guzzetti', 'Virginio', '1983-02-10', 'M', '3372131047', 'NULL', 0),
('JLANTL77P19A637Z', 'Ajala', 'Natale', '1977-09-19', 'M', '3229160283', 'NULL', 0),
('LAOPLG55L10G198U', 'Alo', 'Pellegrino', '1955-07-10', 'M', '3135227703', 'NULL', 0),
('LBNLPA64T14L984B', 'La Banchi', 'Lapo', '1964-12-14', 'M', '3682222919', 'NULL', 0.15),
('LBRDLF09T24D441Y', 'Albergo', 'Adolfo', '2009-12-24', 'M', '3098090318', 'NULL', 0),
('LBRFMN10S48H703L', 'Albiero', 'Flaminia', '2010-11-08', 'F', '3090529552', 'NULL', 0),
('LBRGTN43T20E494C', 'Alibrandi', 'Giustiniano', '1943-12-20', 'M', '3191249848', 'NULL', 0),
('LBRMRG67T01G364Z', 'Alberta', 'Ambrogio', '1967-12-01', 'M', '3509809796', 'ambrogio.alberta@outlook.it', 0),
('LBRNTS90T02G866O', 'Albrisio', 'Anastasio', '1990-12-02', 'M', '3442791511', 'NULL', 0.05),
('LBRRNT45A64D566G', 'Liberalon', 'Renata', '1945-01-24', 'F', '3529058985', 'NULL', 0),
('LBRSFN60E43G986M', 'Alberici', 'Stefania', '1960-05-03', 'F', '3777145736', 'stefania.alberici@pec.it', 0.05),
('LBRSFN70C47G905K', 'Albrizzi', 'Stefania', '1970-03-07', 'F', '3141410206', 'NULL', 0.3),
('LBTSML72B19C080P', 'Labate', 'Samuele', '1972-02-19', 'M', '3089500097', 'NULL', 0),
('LCCDLC42B60L402L', 'Licciardò', 'Doralice', '1942-02-20', 'F', '3625389288', 'doralice.licciardò@gmail.com', 0),
('LCCDNC49R17G048G', 'Leccis', 'Domenico', '1949-10-17', 'M', '3379496275', 'NULL', 0),
('LCCGST63S14B545P', 'Locci', 'Egisto', '1963-11-14', 'M', '3075234781', 'NULL', 0),
('LCCMRZ98L48A341T', 'Liccardo', 'Marzia', '1998-07-08', 'F', '3583358054', 'marzia.liccardo@pec.it', 0),
('LCDSRN99S53G471Y', 'Lucidi', 'Siriana', '1999-11-13', 'F', '3189359095', 'NULL', 0),
('LCFGLL47B41F526R', 'Luciforo', 'Guglielma', '1947-02-01', 'F', '3034017957', 'NULL', 0),
('LCSLSN41C59E903X', 'Lo Castro', 'Alessandra', '1941-03-19', 'F', '3772527154', 'NULL', 0.3),
('LCVRCL69A14E531A', 'La Cavalla', 'Ercole', '1969-01-14', 'M', '3720414508', 'NULL', 0),
('LDGRND83L16D284Z', 'Aldegheri', 'Orlando', '1983-07-16', 'M', '3888839410', 'NULL', 0),
('LDGTTI89C27B667Y', 'Aldighiero', 'Tito', '1989-03-27', 'M', '3471486529', 'NULL', 0),
('LDNLLL86A30H022U', 'Aldini', 'Lello', '1986-01-30', 'M', '3861317088', 'NULL', 0.1),
('LDNLRZ54T64E323H', 'Aldino', 'Lucrezia', '1954-12-24', 'F', '3808201084', 'NULL', 0),
('LDSLFA55T23E330V', 'Laudisio', 'Alfo', '1955-12-23', 'M', '3169651840', 'NULL', 0.15),
('LDSMRL01C18G135V', 'Aldisi', 'Maurilio', '2001-03-18', 'M', '3400464179', 'NULL', 0),
('LDZLNE43A56F454W', 'Aldizio', 'Eliana', '1943-01-16', 'F', '3202821464', 'NULL', 0.05),
('LFNDMA14H26H466V', 'La Fiandra', 'Adamo', '2014-06-26', 'M', '3399106965', 'NULL', 0.15),
('LFNLRG69D23H491P', 'Alfonsetti', 'Alberigo', '1969-04-23', 'M', '3580804721', 'NULL', 0),
('LFNRTT68M58L221G', 'Alfonso', 'Rosetta', '1968-08-18', 'F', '3750810509', 'rosetta.alfonso@virgilio.it', 0.15),
('LFRRCL68M21G483T', 'Alfero', 'Ercole', '1968-08-21', 'M', '3556477445', 'NULL', 0),
('LGHNRO49H55F867G', 'Alghisi', 'Nora', '1949-06-15', 'F', '3456576854', 'NULL', 0),
('LGLGTN79B42B028B', 'Logoluso', 'Gaetana', '1979-02-02', 'F', '3858921582', 'gaetana.logoluso@pec.it', 0),
('LGRFTN95A07H615A', 'Lagorio', 'Faustino', '1995-01-07', 'M', '3502759890', 'NULL', 0.2),
('LGSNRC92D07B676A', 'Algisi', 'Enrico', '1992-04-07', 'M', '3093208391', 'enrico.algisi@gmail.com', 0),
('LLCGGI93B05C407K', 'Allocchio', 'Gigi', '1993-02-05', 'M', '3601055336', 'gigi.allocchio@outlook.it', 0.3),
('LLCGNN71P51B489U', 'Allocchio', 'Giovanna', '1971-09-11', 'F', '3331429411', 'giovanna.allocchio@alice.it', 0.15),
('LLGDIA08A59D630G', 'Allighi', 'Ida', '2008-01-19', 'F', '3746062315', 'ida.allighi@virgilio.it', 0.25),
('LLLMNN76T54G291F', 'Lello', 'Marianna', '1976-12-14', 'F', '3116350596', 'NULL', 0),
('LLSVGN51T08L716L', 'Allasia', 'Virginio', '1951-12-08', 'M', '3818754880', 'NULL', 0.1),
('LLTMSC54H66G613J', 'Alliata', 'Mascia', '1954-06-26', 'F', '3570062138', 'mascia.alliata@virgilio.it', 0.05),
('LLVFLR67E70M253P', 'Allevato', 'Flora', '1967-05-30', 'F', '3489449821', 'NULL', 0),
('LLVLDI98R52G119W', 'Allevi', 'Lidia', '1998-10-12', 'F', '3280762780', 'NULL', 0),
('LMBFTM49T55I294Y', 'Lambra', 'Fatima', '1949-12-15', 'F', '3132825325', 'fatima.lambra@alice.it', 0),
('LMBLLN83C43C344A', 'Lombardi', 'Liliana', '1983-03-03', 'F', '3690260907', 'NULL', 0.1),
('LMELRT45A62F826A', 'Elmi', 'Liberata', '1945-01-22', 'F', '3415582717', 'NULL', 0.2),
('LMLMLN46P48L113F', 'Lomellini', 'Milena', '1946-09-08', 'F', '3139039139', 'NULL', 0),
('LMNCCL60R16H104F', 'Lamon', 'Cecilio', '1960-10-16', 'M', '3602468536', 'NULL', 0),
('LMNCMN91M07H700V', 'Alemanno', 'Clemente', '1991-08-07', 'M', '3517744982', 'NULL', 0),
('LMNDVG04S66A870Q', 'Elmini', 'Edvige', '2004-11-26', 'F', '3222526557', 'NULL', 0),
('LMNGRN10H14M023I', 'Elmone', 'Guarino', '2010-06-14', 'M', '3801504290', 'NULL', 0),
('LMNNBL97L46C554K', 'La Montagna', 'Annabella', '1997-07-06', 'F', '3163854675', 'NULL', 0.05),
('LMNRMN93B64H996T', 'Limongi', 'Romana', '1993-02-24', 'F', '3600455779', 'NULL', 0),
('LMNRMN98P17E148F', 'La Manna', 'Romano', '1998-09-17', 'M', '3961310054', 'NULL', 0),
('LMRRLB76R50F487S', 'Lameri', 'Rosalba', '1976-10-10', 'F', '3929198027', 'NULL', 0.2),
('LMTGTN93B09C285G', 'Lamattina', 'Giustiniano', '1993-02-09', 'M', '3222334244', 'giustiniano.lamattina@virgilio.it', 0),
('LMTLRC56C16H189X', 'Lamatrice', 'Alberico', '1956-03-16', 'M', '3932220286', 'alberico.lamatrice@pec.it', 0.3),
('LNCLND54L69M204A', 'Lanciotti', 'Linda', '1954-07-29', 'F', '3593094452', 'NULL', 0),
('LNDMCL07A65A606G', 'Lando', 'Micol', '2007-01-25', 'F', '3960142976', 'NULL', 0.3),
('LNDSRN58H68A333N', 'Aleandro', 'Serena', '1958-06-28', 'F', '3341407740', 'NULL', 0.2),
('LNERNL74A11F848O', 'Lena', 'Reginaldo', '1974-01-11', 'M', '3438637840', 'NULL', 0.3),
('LNGGNR85P04B871I', 'Longoni', 'Gennaro', '1985-09-04', 'M', '3930302686', 'gennaro.longoni@pec.it', 0),
('LNGMRN87M42L949T', 'Longoni', 'Morena', '1987-08-02', 'F', '3613229414', 'NULL', 0),
('LNLGGR87B12F223G', 'Leonella', 'Gregorio', '1987-02-12', 'M', '3210569828', 'gregorio.leonella@outlook.it', 0),
('LNRCAI00L10C829J', 'Lenardo', 'Caio', '2000-07-10', 'M', '3615952893', 'NULL', 0),
('LNRGFR93M27D539G', 'Lunardo', 'Goffredo', '1993-08-27', 'M', '3113156083', 'goffredo.lunardo@alice.it', 0),
('LNRNNA12P64A249E', 'Alinari', 'Anna', '2012-09-24', 'F', '3825430050', 'NULL', 0),
('LNSTNA02H56B030K', 'Alonsi', 'Tania', '2002-06-16', 'F', '3414312032', 'tania.alonsi@pec.it', 0),
('LNTVVN89S55B632B', 'Leonetti', 'Viviana', '1989-11-15', 'F', '3335364221', 'NULL', 0),
('LNZLRD71B19C914F', 'Lanzotto', 'Leonardo', '1971-02-19', 'M', '3488504308', 'NULL', 0),
('LOITMS59A30M027V', 'Loi', 'Tommaso', '1959-01-30', 'M', '3004270986', 'tommaso.loi@pec.it', 0),
('LPMNDR42E14I671E', 'Li Puma', 'Andrea', '1942-05-14', 'M', '3151773845', 'NULL', 0),
('LRALNI47A71B844O', 'Alaria', 'Ilenia', '1947-01-31', 'F', '3796057962', 'NULL', 0),
('LRILSI98L56L433Y', 'Ilario', 'Lisa', '1998-07-16', 'F', '3368001206', 'NULL', 0.05),
('LRLLCA62C46A604C', 'Lorella', 'Alice', '1962-03-06', 'F', '3176265318', 'NULL', 0),
('LRNPLM93S56G954N', 'Laurenzano', 'Palma', '1993-11-16', 'F', '3589044534', 'NULL', 0),
('LRNSIA05L52A603Q', 'Lorenzetti', 'Isa', '2005-07-12', 'F', '3492607404', 'NULL', 0),
('LSALRD64P09L265T', 'Alesio', 'Alfredino', '1964-09-09', 'M', '3444761802', 'alfredino.alesio@alice.it', 0),
('LSARKE47T54H623R', 'Lasio', 'Erika', '1947-12-14', 'F', '3499772919', 'erika.lasio@outlook.it', 0),
('LSNMSM40L20G944E', 'Alesini', 'Massimo', '1940-07-20', 'M', '3765622990', 'massimo.alesini@virgilio.it', 0),
('LSSBND47D08H992M', 'Lessio', 'Abbondio', '1947-04-08', 'M', '3870447835', 'abbondio.lessio@alice.it', 0),
('LSSBRC43M50F917V', 'Lussu', 'Beatrice', '1943-08-10', 'F', '3768505064', 'NULL', 0),
('LSSCVN83A04E829H', 'Lessa', 'Calvino', '1983-01-04', 'M', '3756336318', 'NULL', 0),
('LSSDRD97E29G804M', 'Alessandrucci', 'Edoardo', '1997-05-29', 'M', '3854585457', 'edoardo.alessandrucci@outlook.it', 0.15),
('LSSLEO82A15A568M', 'Alessandroni', 'Leo', '1982-01-15', 'M', '3118361070', 'NULL', 0),
('LSSNLN44E21F393M', 'Ulisse', 'Angelino', '1944-05-21', 'M', '3228275852', 'NULL', 0),
('LSSSRA45E03L586H', 'Lossi', 'Saro', '1945-05-03', 'M', '3295424855', 'saro.lossi@outlook.it', 0),
('LTBBRM50C05G875Q', 'Altobrandi', 'Abramo', '1950-03-05', 'M', '3858654606', 'NULL', 0),
('LTMCLN49R62H028W', 'Altamura', 'Carolina', '1949-10-22', 'F', '3415047313', 'carolina.altamura@outlook.it', 0),
('LTMLND16R31I152G', 'Altomare', 'Olindo', '2016-10-31', 'M', '3496715250', 'NULL', 0.1),
('LTMMRN76M03A472N', 'Altomare', 'Moreno', '1976-08-03', 'M', '3508895275', 'moreno.altomare@gmail.com', 0),
('LTRLVR63P10C507U', 'Altieri', 'Alvaro', '1963-09-10', 'M', '3189441711', 'NULL', 0.3),
('LTTCLL95P25H564D', 'Eletti', 'Catello', '1995-09-25', 'M', '3831031549', 'catello.eletti@outlook.it', 0),
('LTUCMN04E03D554T', 'Luti', 'Clemente', '2004-05-03', 'M', '3714396191', 'NULL', 0.3),
('LVIDLD57A64E691O', 'Livio', 'Adelaide', '1957-01-24', 'F', '3674950786', 'NULL', 0),
('LVNGTN46L19F829K', 'Lo Ventre', 'Giustino', '1946-07-19', 'M', '3051362595', 'NULL', 0),
('LVRNNZ99B43C852H', 'Livieri', 'Annunziata', '1999-02-03', 'F', '3849294079', 'annunziata.livieri@virgilio.it', 0.2),
('LVSMLE66T04E707J', 'Lovison', 'Emilio', '1966-12-04', 'M', '3536179208', 'NULL', 0),
('LVTLSE09T69A137H', 'Levato', 'Elisa', '2009-12-29', 'F', '3525591890', 'NULL', 0),
('LVTVNC51T47B317B', 'Oliveti', 'Veronica', '1951-12-07', 'F', '3814661088', 'veronica.oliveti@virgilio.it', 0),
('LZZDLN74S43H338W', 'Luzzardi', 'Adelina', '1974-11-03', 'F', '3311778193', 'adelina.luzzardi@alice.it', 0),
('LZZNLN55E05F427Z', 'Lazzero', 'Angelino', '1955-05-05', 'M', '3457937464', 'NULL', 0),
('MCACGR85A23H076P', 'Amici', 'Calogero', '1985-01-23', 'M', '3099065413', 'NULL', 0.15),
('MCCMDE84H06G212Q', 'Mocci', 'Emidio', '1984-06-06', 'M', '3166581225', 'NULL', 0.2),
('MCCPMP45P28A131K', 'Moccelin', 'Pompeo', '1945-09-28', 'M', '3961266441', 'NULL', 0),
('MCCTVN63C20M106Q', 'Maccagno', 'Ottaviano', '1963-03-20', 'M', '3994797496', 'ottaviano.maccagno@alice.it', 0.1),
('MCHGIA13E15L176R', 'Mochen', 'Iago', '2013-05-15', 'M', '3363152587', 'iago.mochen@alice.it', 0.25),
('MCSMCL91T45G109K', 'Macis', 'Marcella', '1991-12-05', 'F', '3743564689', 'marcella.macis@gmail.com', 0),
('MDACST73T47B620Z', 'Madeo', 'Celeste', '1973-12-07', 'F', '3681355964', 'NULL', 0),
('MDALBN00C26L722A', 'Amadei', 'Albino', '2000-03-26', 'M', '3760059248', 'NULL', 0),
('MDALDN60P42H403Z', 'Amodeo', 'Loredana', '1960-09-02', 'F', '3790189871', 'NULL', 0),
('MDLGPR72P25E091Y', 'Medioli', 'Gaspare', '1972-09-25', 'M', '3469444106', 'NULL', 0),
('MDNMRC53S30H341J', 'Modena', 'Americo', '1953-11-30', 'M', '3620549398', 'NULL', 0),
('MDTCST74H10B711X', 'Medeot', 'Cristiano', '1974-06-10', 'M', '3619595991', 'NULL', 0.1),
('MGELRD80D11I147H', 'Mega', 'Alfredo', '1980-04-11', 'M', '3107022097', 'NULL', 0.15),
('MGGFNN82P30I289R', 'Magagni', 'Fernando', '1982-09-30', 'M', '3624349772', 'fernando.magagni@alice.it', 0),
('MGGLDR98E02B977H', 'Maggiora', 'Leandro', '1998-05-02', 'M', '3439066090', 'NULL', 0),
('MGLFBL69L47A328R', 'Moglia', 'Fabiola', '1969-07-07', 'F', '3499688770', 'NULL', 0.15),
('MGLGMN43E23A023B', 'Migliaccio', 'Germano', '1943-05-23', 'M', '3223712007', 'germano.migliaccio@alice.it', 0),
('MGLMLN55H59D266R', 'Migliavacca', 'Milena', '1955-06-19', 'F', '3495585585', 'NULL', 0.25),
('MGLRCC40A24D269E', 'Migliaro', 'Rocco', '1940-01-24', 'M', '3476289766', 'NULL', 0.25),
('MGNMMM47L49A771Z', 'Magnani', 'Mimma', '1947-07-09', 'F', '3719428044', 'NULL', 0),
('MGNRCE50P59F429T', 'Migone', 'Erica', '1950-09-19', 'F', '3739301164', 'NULL', 0.3),
('MGNVNC94T71A157Z', 'Megani', 'Veronica', '1994-12-31', 'F', '3885718955', 'NULL', 0.1),
('MGRSDI48R70D113F', 'Magrini', 'Iside', '1948-10-30', 'F', '3724536572', 'NULL', 0.1),
('MGSYNN96D59L723I', 'Magistrello', 'Yvonne', '1996-04-19', 'F', '3731503347', 'NULL', 0.25),
('MJRMRA44B48E571L', 'Mejer', 'Maria', '1944-02-08', 'F', '3108275830', 'NULL', 0),
('MLALDL69C28E051P', 'Ameli', 'Landolfo', '1969-03-28', 'M', '3881061421', 'NULL', 0.25),
('MLFLCN63C21I027U', 'Malfatti', 'Luciano', '1963-03-21', 'M', '3443663729', 'NULL', 0),
('MLLCRL59C30I280D', 'Maiella', 'Carlo', '1959-03-30', 'M', '3772927654', 'NULL', 0),
('MLLLRT04L23G537Y', 'Amella', 'Liberato', '2004-07-23', 'M', '3466149875', 'NULL', 0),
('MLNBTL40P25C069C', 'Melani', 'Bartolomeo', '1940-09-25', 'M', '3671419536', 'NULL', 0),
('MLNGLM54H03C236H', 'Malanca', 'Girolamo', '1954-06-03', 'M', '3327860058', 'NULL', 0),
('MLNPQN03S18E682V', 'Molinengo', 'Pasquino', '2003-11-18', 'M', '3552229416', 'NULL', 0.1),
('MLNRND56M07B511C', 'Molino', 'Orlando', '1956-08-07', 'M', '3547629103', 'orlando.molino@pec.it', 0.3),
('MLNVTR06B15F910U', 'Meloni', 'Vittorio', '2006-02-15', 'M', '3399797922', 'vittorio.meloni@gmail.com', 0.25),
('MLPNRC80C25E644W', 'Malpeli', 'Enrico', '1980-03-25', 'M', '3309301360', 'NULL', 0),
('MLRDRN02H51A837V', 'Malerba', 'Doriana', '2002-06-11', 'F', '3914454247', 'NULL', 0),
('MLZMRC09D15E558Q', 'Emiliozzi', 'Marco', '2009-04-15', 'M', '3252254150', 'NULL', 0.15),
('MMELEO73P09F238T', 'Emma', 'Leo', '1973-09-09', 'M', '3643138280', 'NULL', 0),
('MMESLL88E64I980F', 'Meme', 'Stella', '1988-05-24', 'F', '3307142280', 'stella.meme@virgilio.it', 0),
('MMLDLZ16D12L093J', 'Memoli', 'Diocleziano', '2016-04-12', 'M', '3103596095', 'diocleziano.memoli@alice.it', 0.25),
('MMMGNN85B05C351I', 'Mammuru', 'Giuanni', '1985-02-05', 'M', '3174712349', 'NULL', 0.2),
('MMMSLV99R09C990B', 'Memmo', 'Silvio', '1999-10-09', 'M', '3721775162', 'NULL', 0),
('MMRCST49R53H564O', 'Ammirati', 'Celeste', '1949-10-13', 'F', '3253721261', 'NULL', 0.25),
('MMRGLN15A46I954Z', 'Mamertino', 'Giuliana', '2015-01-06', 'F', '3540675055', 'NULL', 0),
('MNAMRA85L29G597S', 'Amone', 'Mario', '1985-07-29', 'M', '3538300154', 'NULL', 0),
('MNCDND80D58D860L', 'Mancarella', 'Doranda', '1980-04-18', 'F', '3245825881', 'NULL', 0),
('MNCFMN55E02E554F', 'Monachella', 'Flaminio', '1955-05-02', 'M', '3088279417', 'NULL', 0.2),
('MNCGAI01L09L527R', 'Minciarelli', 'Gaio', '2001-07-09', 'M', '3166124145', 'NULL', 0),
('MNCTLL85S04B187L', 'Minicuci', 'Otello', '1985-11-04', 'M', '3362869732', 'otello.minicuci@alice.it', 0),
('MNDDBR50A20D565G', 'Menditto', 'Adalberto', '1950-01-20', 'M', '3692794958', 'adalberto.menditto@virgilio.it', 0),
('MNDLNE79E56I373B', 'Manueddu', 'Elena', '1979-05-16', 'F', '3412959335', 'NULL', 0),
('MNDMLI41M01B435M', 'Mundo', 'Milo', '1941-08-01', 'M', '3087770454', 'NULL', 0),
('MNGBDT86L53F529Z', 'Mangano', 'Benedetta', '1986-07-13', 'F', '3158600648', 'NULL', 0),
('MNGFRC97M21G797C', 'Minighino', 'Federico', '1997-08-21', 'M', '3794065385', 'NULL', 0),
('MNGFRC99D16B942P', 'Menegale', 'Federico', '1999-04-16', 'M', '3972066250', 'NULL', 0.3),
('MNGPLA84T59L297O', 'Menegotto', 'Paola', '1984-12-19', 'F', '3077225483', 'paola.menegotto@virgilio.it', 0),
('MNLTDD78R13L909C', 'Maniello', 'Taddeo', '1978-10-13', 'M', '3329408806', 'taddeo.maniello@gmail.com', 0),
('MNNCLL72E08L461L', 'Mannaro', 'Catello', '1972-05-08', 'M', '3214550542', 'NULL', 0),
('MNNLND92P04G030B', 'Mennoni', 'Lindo', '1992-09-04', 'M', '3540734970', 'NULL', 0),
('MNNSNL85C68A159Y', 'Munno', 'Serenella', '1985-03-28', 'F', '3512220307', 'NULL', 0.05),
('MNNTMR85E56E965U', 'Amanniti', 'Tamara', '1985-05-16', 'F', '3906843480', 'tamara.amanniti@virgilio.it', 0.05),
('MNRGRL83C21B607W', 'Minardi', 'Gabriele', '1983-03-21', 'M', '3503918083', 'gabriele.minardi@alice.it', 0),
('MNRLDA77P63I388J', 'Mainardis', 'Alda', '1977-09-23', 'F', '3702517568', 'NULL', 0),
('MNSDNI46H46G335Y', 'Monassi', 'Diana', '1946-06-06', 'F', '3511284523', 'NULL', 0),
('MNSSDR45L09I193S', 'Mansi', 'Sandro', '1945-07-09', 'M', '3818686553', 'NULL', 0),
('MNTCCL40A46C110S', 'Montefusco', 'Cecilia', '1940-01-06', 'F', '3892282905', 'NULL', 0.1),
('MNTDLZ96S09D043W', 'Montanelli', 'Diocleziano', '1996-11-09', 'M', '3447236684', 'diocleziano.montanelli@outlook.it', 0),
('MNTFBA78M16E464H', 'Montefusco', 'Fabio', '1978-08-16', 'M', '3318370179', 'fabio.montefusco@pec.it', 0),
('MNTFRC84M59F117U', 'Montagnani', 'Federica', '1984-08-19', 'F', '3746862093', 'NULL', 0),
('MNTGGN97D03G491P', 'Monticelli', 'Gigino', '1997-04-03', 'M', '3431949355', 'NULL', 0.15),
('MPRCTN61M08A175N', 'Imparato', 'Costanzo', '1961-08-08', 'M', '3195229894', 'NULL', 0.2),
('MPRGMN45R21D684H', 'Imperatore', 'Germano', '1945-10-21', 'M', '3333239180', 'NULL', 0),
('MRAVVN86P01D399S', 'Amaro', 'Viviano', '1986-09-01', 'M', '3645855137', 'NULL', 0.3),
('MRCDMN81T09I118B', 'Marcheggiani', 'Damiano', '1981-12-09', 'M', '3312477993', 'damiano.marcheggiani@gmail.com', 0.3),
('MRCDNC15S03B448S', 'Marci', 'Domenico', '2015-11-03', 'M', '3899478229', 'domenico.marci@pec.it', 0),
('MRCGTN91B61F528K', 'Morciano', 'Gaetana', '1991-02-21', 'F', '3238877731', 'NULL', 0),
('MRCGTR59E28E709P', 'Marchesi', 'Gualtiero', '1959-05-28', 'M', '3957515727', 'NULL', 0),
('MRCLND15P24D338V', 'Marchiorri', 'Lando', '2015-09-24', 'M', '3285374891', 'lando.marchiorri@alice.it', 0),
('MRCNCN90S18G886Q', 'Marocco', 'Innocenzo', '1990-11-18', 'M', '3454763322', 'NULL', 0),
('MRCRFL46D45G597J', 'Mercuri', 'Raffaella', '1946-04-05', 'F', '3221461076', 'NULL', 0),
('MRLCST43B05B745C', 'Marola', 'Cristoforo', '1943-02-05', 'M', '3072922441', 'NULL', 0.2),
('MRNDNC05S07E092E', 'Amarante', 'Domenico', '2005-11-07', 'M', '3518825288', 'domenico.amarante@gmail.com', 0),
('MRNLNE76C10D230C', 'Marandola', 'Leone', '1976-03-10', 'M', '3783487494', 'NULL', 0.3),
('MRNPMP47S53G763X', 'Maranzana', 'Pompea', '1947-11-13', 'F', '3153921245', 'NULL', 0),
('MRNRMN85C53A312B', 'Marnini', 'Ramona', '1985-03-13', 'F', '3972499441', 'NULL', 0),
('MRNSML05P08A024M', 'Amarante', 'Samuele', '2005-09-08', 'M', '3443811850', 'NULL', 0),
('MRNSRN85L59F887P', 'Muroni', 'Serena', '1985-07-19', 'F', '3271517065', 'serena.muroni@alice.it', 0),
('MRRMGH95E47F653J', 'Marraffino', 'Margherita', '1995-05-07', 'F', '3922382057', 'NULL', 0),
('MRSCTN14H17M272O', 'Marascia', 'Cateno', '2014-06-17', 'M', '3154487084', 'NULL', 0),
('MRSDLE00H51I103S', 'Marsella', 'Delia', '2000-06-11', 'F', '3386470958', 'NULL', 0),
('MRSLND98L19C549U', 'Marsigli', 'Lando', '1998-07-19', 'M', '3101887379', 'NULL', 0),
('MRSLSN17M45I507H', 'Morosino', 'Luisiana', '2017-08-05', 'F', '3797462046', 'NULL', 0),
('MRSPRN62D41I082D', 'Morasca', 'Pierina', '1962-04-01', 'F', '3337845620', 'NULL', 0),
('MRSTLI82H24I847T', 'Marassi', 'Italo', '1982-06-24', 'M', '3792829581', 'NULL', 0),
('MRSZNE86H24G083P', 'Morisco', 'Zeno', '1986-06-24', 'M', '3198101081', 'zeno.morisco@alice.it', 0),
('MRTCDD69R01E125I', 'Amirata', 'Candido', '1969-10-01', 'M', '3736878982', 'candido.amirata@outlook.it', 0),
('MRTDLL48C55G561C', 'Martinenghi', 'Dalila', '1948-03-15', 'F', '3559418976', 'dalila.martinenghi@alice.it', 0.2),
('MRTGRM59C23F352D', 'Marturano', 'Geremia', '1959-03-23', 'M', '3900660863', 'NULL', 0.15),
('MRTMRA41P66C505B', 'Martignone', 'Maura', '1941-09-26', 'F', '3119811085', 'NULL', 0),
('MRTMRN78E47I234G', 'Maritato', 'Mirena', '1978-05-07', 'F', '3585321291', 'NULL', 0),
('MRTRCL11M20G529Q', 'Martiradonna', 'Ercole', '2011-08-20', 'M', '3787815656', 'NULL', 0),
('MRTSFO51C61A815W', 'Martinenghi', 'Sofia', '1951-03-21', 'F', '3920497571', 'sofia.martinenghi@alice.it', 0),
('MRTVGL60M01H532B', 'Martignoni', 'Virgilio', '1960-08-01', 'M', '3142116223', 'NULL', 0),
('MRTVVN99P67E327X', 'Amoretto', 'Viviana', '1999-09-27', 'F', '3361969033', 'NULL', 0.15),
('MRZLNZ10C71G551U', 'Marzaro', 'Lorenza', '2010-03-31', 'F', '3152942276', 'NULL', 0),
('MRZMRC67T19E560G', 'Marzadro', 'Americo', '1967-12-19', 'M', '3143805839', 'americo.marzadro@alice.it', 0),
('MSCGDI50L50B866W', 'Miscali', 'Giada', '1950-07-10', 'F', '3296868532', 'NULL', 0),
('MSCGDN46R64E428J', 'Maschietto', 'Giordana', '1946-10-24', 'F', '3091997685', 'giordana.maschietto@virgilio.it', 0),
('MSCLSS69T68H672X', 'Musco', 'Larissa', '1969-12-28', 'F', '3915505514', 'larissa.musco@alice.it', 0),
('MSCLVN70L69C936I', 'Mascia', 'Lavinia', '1970-07-29', 'F', '3570147372', 'NULL', 0),
('MSCMRT68E64H436F', 'Moscatelli', 'Ombretta', '1968-05-24', 'F', '3768504543', 'NULL', 0),
('MSCNRC91P18A399Q', 'Muscettola', 'Enrico', '1991-09-18', 'M', '3349520128', 'enrico.muscettola@gmail.com', 0),
('MSCPQL46M29E783J', 'Maschio', 'Pasquale', '1946-08-29', 'M', '3756702317', 'NULL', 0),
('MSCPQL47D22E296G', 'Mascali', 'Pasquale', '1947-04-22', 'M', '3749812914', 'NULL', 0.05),
('MSCVTR13C62C658X', 'Moschin', 'Veturia', '2013-03-22', 'F', '3141672066', 'NULL', 0),
('MSLMRG42M11L284Z', 'Muselli', 'Amerigo', '1942-08-11', 'M', '3763001424', 'NULL', 0),
('MSNCLD83B01C501Y', 'Musone', 'Cataldo', '1983-02-01', 'M', '3103358841', 'NULL', 0),
('MSNDNL48A20F304C', 'Maesano', 'Danilo', '1948-01-20', 'M', '3778556181', 'NULL', 0.25),
('MSRLNE40D50B514V', 'Miserocchi', 'Eleana', '1940-04-10', 'F', '3850535477', 'NULL', 0),
('MSRSNT67E44A382J', 'Musarella', 'Assunta', '1967-05-04', 'F', '3839298407', 'NULL', 0.2),
('MSSLEA70C55G767Y', 'Massidda', 'Lea', '1970-03-15', 'F', '3311563769', 'lea.massidda@pec.it', 0),
('MSSMLA84C66H347S', 'Massaro', 'Amalia', '1984-03-26', 'F', '3531302147', 'NULL', 0),
('MSSRME02R29G325T', 'Missiaglia', 'Remo', '2002-10-29', 'M', '3738016522', 'NULL', 0.1),
('MSSRRA92T56E092T', 'Mussa', 'Aurora', '1992-12-16', 'F', '3975940230', 'NULL', 0),
('MSSSRA95D12F513J', 'Massarelli', 'Saro', '1995-04-12', 'M', '3596374481', 'saro.massarelli@outlook.it', 0.15),
('MSSVVN61E29E185J', 'Massimiano', 'Viviano', '1961-05-29', 'M', '3933735011', 'viviano.massimiano@pec.it', 0),
('MSTCSR45R06B894A', 'Mostacchi', 'Cesare', '1945-10-06', 'M', '3142159780', 'cesare.mostacchi@gmail.com', 0.3),
('MSTNCN63B23B159F', 'Mastantuoni', 'Innocenzo', '1963-02-23', 'M', '3778616404', 'NULL', 0.05),
('MSTSTN86A50C175T', 'Mastrangeli', 'Santina', '1986-01-10', 'F', '3598936770', 'santina.mastrangeli@virgilio.it', 0),
('MSTSVN58M24D798H', 'Mastrota', 'Silvano', '1958-08-24', 'M', '3422268658', 'NULL', 0),
('MSTYLN03B43A940C', 'Mastrapasqua', 'Ylenia', '2003-02-03', 'F', '3048083890', 'NULL', 0.2),
('MTIRST04A03D156K', 'Mito', 'Oreste', '2004-01-03', 'M', '3701257824', 'oreste.mito@virgilio.it', 0.2),
('MTLNRC53B48I993S', 'Miatello', 'Enrica', '1953-02-08', 'F', '3477923267', 'NULL', 0),
('MTLTLI61R49A757E', 'Mitola', 'Italia', '1961-10-09', 'F', '3667380571', 'NULL', 0),
('MTRCTL99H55C307H', 'Amatore', 'Clotilde', '1999-06-15', 'F', '3826295556', 'clotilde.amatore@pec.it', 0.3),
('MTRGDN52E63L842R', 'Amatruda', 'Giordana', '1952-05-23', 'F', '3580157270', 'NULL', 0.1),
('MTRGRG91E70F627N', 'Matrango', 'Giorgia', '1991-05-30', 'F', '3203037614', 'NULL', 0.05),
('MTRLRT67D01L675C', 'Mataresi', 'Alberto', '1967-04-01', 'M', '3674930346', 'NULL', 0.2),
('MTRRLA85B10B100Q', 'Amatrude', 'Aurelio', '1985-02-10', 'M', '3391874140', 'aurelio.amatrude@gmail.com', 0),
('MTSGTN59L51L131X', 'Matassi', 'Gaetana', '1959-07-11', 'F', '3882012356', 'gaetana.matassi@pec.it', 0.3),
('MTTFPP02A51I470E', 'Matteo', 'Filippa', '2002-01-11', 'F', '3551082181', 'NULL', 0),
('MTTMDA15E05D050D', 'Motteran', 'Amedeo', '2015-05-05', 'M', '3087647831', 'NULL', 0),
('MTTRMN13C70F006G', 'Mattavelli', 'Ramona', '2013-03-30', 'F', '3901507983', 'ramona.mattavelli@gmail.com', 0.15),
('MTTVVN56D05F223X', 'Mottura', 'Viviano', '1956-04-05', 'M', '3663006356', 'viviano.mottura@outlook.it', 0),
('MZRFNC06T57G349D', 'Mazurco', 'Francesca', '2006-12-17', 'F', '3973698792', 'NULL', 0),
('MZZCLR43A71I671J', 'Mazzotti', 'Clara', '1943-01-31', 'F', '3283547801', 'NULL', 0.05),
('MZZDRO56R67E578C', 'Mozzo', 'Dora', '1956-10-27', 'F', '3656451497', 'NULL', 0),
('MZZMRN53P03G616G', 'Mazzacane', 'Marino', '1953-09-03', 'M', '3317538462', 'NULL', 0),
('MZZNZE68E30E675Z', 'Mezzadri', 'Enzo', '1968-05-30', 'M', '3020442859', 'NULL', 0),
('MZZSDR74L03B437O', 'Mazzuolo', 'Isidoro', '1974-07-03', 'M', '3689856717', 'NULL', 0.2),
('NCCMTT57R16M119U', 'Nocco', 'Matteo', '1957-10-16', 'M', '3347495383', 'NULL', 0),
('NCCSST90P17E742S', 'Nuccio', 'Sisto', '1990-09-17', 'M', '3762884924', 'sisto.nuccio@alice.it', 0),
('NCIRNO76E64C038I', 'Ienco', 'Oriana', '1976-05-24', 'F', '3792641467', 'NULL', 0),
('NCLFDR14P19A816P', 'Nicoletti', 'Fedro', '2014-09-19', 'M', '3772429635', 'NULL', 0),
('NCNMIA81T55A185Q', 'Nicandri', 'Mia', '1981-12-15', 'F', '3513296247', 'NULL', 0.05),
('NCRFDL52E24H486X', 'Incarnata', 'Fedele', '1952-05-24', 'M', '3728682973', 'NULL', 0.1),
('NCRSNO80M41G160G', 'Incorvaja', 'Sonia', '1980-08-01', 'F', '3222209476', 'NULL', 0.3),
('NCSSDI77E66I090K', 'Nicastro', 'Iside', '1977-05-26', 'F', '3733549243', 'NULL', 0),
('NDLCRI97H10L563Z', 'Nadalino', 'Ciro', '1997-06-10', 'M', '3798963853', 'NULL', 0.05),
('NDNGDE01L19L422L', 'Andeni', 'Egidio', '2001-07-19', 'M', '3321366909', 'NULL', 0),
('NDRBTL50A28G185P', 'Andreani', 'Bartolomeo', '1950-01-28', 'M', '3134932657', 'NULL', 0),
('NDRDLA61D47H738Y', 'Andreazzi', 'Adele', '1961-04-07', 'F', '3083253606', 'adele.andreazzi@pec.it', 0),
('NDRGRN96D30G542U', 'Andreotti', 'Guarino', '1996-04-30', 'M', '3819833166', 'NULL', 0),
('NDRMCR98M10M358B', 'Andreasi', 'Amilcare', '1998-08-10', 'M', '3316805034', 'NULL', 0),
('NDRMDE94L03I344O', 'Andrade', 'Emidio', '1994-07-03', 'M', '3238816770', 'emidio.andrade@gmail.com', 0),
('NDRPQN02T05B516V', 'Andreutti', 'Pasquino', '2002-12-05', 'M', '3213824195', 'NULL', 0),
('NDRTSC92P49G813S', 'Andreani', 'Tosca', '1992-09-09', 'F', '3007699840', 'NULL', 0),
('NEADZN43R64F065U', 'Ena', 'Domiziana', '1943-10-24', 'F', '3865553441', 'domiziana.ena@virgilio.it', 0),
('NFSBLD80P07B131K', 'Nifosi', 'Ubaldo', '1980-09-07', 'M', '3972957029', 'NULL', 0),
('NFSDGS14H65E760L', 'Anfuso', 'Adalgisa', '2014-06-25', 'F', '3031807304', 'adalgisa.anfuso@outlook.it', 0),
('NGANTS61L07E371X', 'Angiu', 'Anastasio', '1961-07-07', 'M', '3152801834', 'anastasio.angiu@virgilio.it', 0),
('NGGVNC92E49F978L', 'Naggi', 'Veronica', '1992-05-09', 'F', '3180452407', 'veronica.naggi@virgilio.it', 0),
('NGLLNE45D60E483R', 'Angelini', 'Eleana', '1945-04-20', 'F', '3109287144', 'eleana.angelini@virgilio.it', 0),
('NGLLNI73S62G179Q', 'Angeletti', 'Lina', '1973-11-22', 'F', '3369026184', 'lina.angeletti@pec.it', 0.15),
('NGLLRT69L57D964B', 'Angiuli', 'Alberta', '1969-07-17', 'F', '3379655653', 'alberta.angiuli@gmail.com', 0.2),
('NGLRNL98L11G681L', 'Angelelli', 'Reginaldo', '1998-07-11', 'M', '3043797005', 'NULL', 0),
('NGLTSC60E70E078W', 'Angeli', 'Tosca', '1960-05-30', 'F', '3365820305', 'NULL', 0),
('NGNCLL56T51M317I', 'Nugnes', 'Camilla', '1956-12-11', 'F', '3864918281', 'camilla.nugnes@pec.it', 0.25),
('NGRGLI54R41I296O', 'Negro', 'Giulia', '1954-10-01', 'F', '3677351180', 'giulia.negro@virgilio.it', 0.15),
('NGRTNA68S70L658K', 'Ongaretto', 'Tania', '1968-11-30', 'F', '3549487465', 'tania.ongaretto@outlook.it', 0),
('NLDMDA54L18D223L', 'Naldi', 'Amedeo', '1954-07-18', 'M', '3723621635', 'NULL', 0),
('NLLMRN63C30M108W', 'Nallo', 'Moreno', '1963-03-30', 'M', '3571618528', 'NULL', 0),
('NLSMRT59C52F578H', 'Nolaschi', 'Umberta', '1959-03-12', 'F', '3144599346', 'NULL', 0.15),
('NLTLDE88B55L503N', 'Nalti', 'Elide', '1988-02-15', 'F', '3764327316', 'NULL', 0.05),
('NLUGDE46C26D512T', 'Unali', 'Egidio', '1946-03-26', 'M', '3518881769', 'egidio.unali@gmail.com', 0),
('NNBPCR92E13L812Q', 'Anniballo', 'Pancrazio', '1992-05-13', 'M', '3282764078', 'NULL', 0),
('NNCTTN47T24B394V', 'Innocenti', 'Ottone', '1947-12-24', 'M', '3786816546', 'ottone.innocenti@pec.it', 0),
('NNMCLD04D11B740S', 'Innamorati', 'Cataldo', '2004-04-11', 'M', '3084935136', 'NULL', 0.3),
('NNNMSS75L63A439L', 'Annunzio', 'Melissa', '1975-07-23', 'F', '3121497507', 'NULL', 0.15),
('NNNRND11D02E784O', 'Annunziata', 'Rolando', '2011-04-02', 'M', '3094623304', 'rolando.annunziata@gmail.com', 0),
('NNNVNI74C51A716K', 'Annunziata', 'Ivana', '1974-03-11', 'F', '3559403851', 'NULL', 0),
('NPPCSR00P13F383E', 'Nappi', 'Cesare', '2000-09-13', 'M', '3931935883', 'NULL', 0.3),
('NRCVNA68C65E821Z', 'Norcia', 'Vania', '1968-03-25', 'F', '3656762943', 'vania.norcia@pec.it', 0),
('NRDLDR98S02G486H', 'Nardinocchi', 'Leandro', '1998-11-02', 'M', '3214713396', 'NULL', 0.1),
('NRDRNL91S21E213P', 'Nardone', 'Reginaldo', '1991-11-21', 'M', '3284652767', 'reginaldo.nardone@alice.it', 0),
('NRDSLN07M61E798E', 'Nardese', 'Selena', '2007-08-21', 'F', '3615595402', 'selena.nardese@alice.it', 0),
('NSLFRC92T30G324S', 'Ansolini', 'Federico', '1992-12-30', 'M', '3704197891', 'NULL', 0),
('NSLRMN78D30B531N', 'Naselli', 'Erminio', '1978-04-30', 'M', '3790637465', 'NULL', 0),
('NSTCLL91E09D973D', 'Nastasio', 'Achille', '1991-05-09', 'M', '3791663760', 'achille.nastasio@gmail.com', 0),
('NSTMDE16A23A245J', 'Nasti', 'Emidio', '2016-01-23', 'M', '3186777671', 'emidio.nasti@gmail.com', 0),
('NSTSRI77H55G638G', 'Nastasi', 'Siria', '1977-06-15', 'F', '3892552355', 'NULL', 0.2),
('NSTTTI51A02L060C', 'Nasta', 'Tito', '1951-01-02', 'M', '3495174544', 'NULL', 0.15),
('NTGVNI79D52F887N', 'Antognoni', 'Ivana', '1979-04-12', 'F', '3832046468', 'NULL', 0.05),
('NTLLNS99B04L687A', 'Antolino', 'Alfonso', '1999-02-04', 'M', '3585785709', 'NULL', 0),
('NTLRND17B26G011L', 'Natali', 'Rolando', '2017-02-26', 'M', '3410789918', 'NULL', 0.15),
('NTLRND17H03A370Z', 'Intelisano', 'Orlando', '2017-06-03', 'M', '3142017061', 'NULL', 0),
('NTNFDR08P30C237B', 'Antina', 'Fedro', '2008-09-30', 'M', '3534694144', 'NULL', 0.1),
('NTNGTT09S67C120S', 'Antonio', 'Giuditta', '2009-11-27', 'F', '3904092847', 'NULL', 0),
('NTNRNR55R22G012D', 'Intini', 'Raniero', '1955-10-22', 'M', '3697721767', 'NULL', 0),
('NTNTTN00C05H356C', 'Antonicelli', 'Ottone', '2000-03-05', 'M', '3271785071', 'NULL', 0),
('NTNVTT95A46E368N', 'Antonelli', 'Violetta', '1995-01-06', 'F', '3268244838', 'violetta.antonelli@virgilio.it', 0),
('NTRPCR16C05I760K', 'Interrante', 'Pancrazio', '2016-03-05', 'M', '3810619817', 'NULL', 0.15),
('NTRRBN61D43A052S', 'Notaristefano', 'Rubina', '1961-04-03', 'F', '3492663199', 'NULL', 0.1),
('NTZFNN68B11I183R', 'Antuzzi', 'Fernando', '1968-02-11', 'M', '3445972467', 'NULL', 0),
('NVLRNI98M59A301O', 'Novellino', 'Rina', '1998-08-19', 'F', '3603657309', 'rina.novellino@pec.it', 0),
('NVZMLT51C31I996S', 'Novazzi', 'Amleto', '1951-03-31', 'M', '3925211237', 'NULL', 0),
('NZLDRO70T69H545N', 'Anzilutti', 'Doria', '1970-12-29', 'F', '3908908558', 'doria.anzilutti@alice.it', 0),
('NZLNNZ09R07C404G', 'Anzelmo', 'Nunzio', '2009-10-07', 'M', '3972434398', 'NULL', 0.2),
('NZNLCL48H25D179Q', 'Anzuinelli', 'Lucilio', '1948-06-25', 'M', '3465427071', 'lucilio.anzuinelli@pec.it', 0),
('NZTTDD44S03D986L', 'Inzitari', 'Taddeo', '1944-11-03', 'M', '3690459637', 'NULL', 0),
('NZVLSS97L56B256S', 'Anzivino', 'Alessia', '1997-07-16', 'F', '3904553743', 'NULL', 0),
('PAIRTT99R58G295L', 'Api', 'Rosetta', '1999-10-18', 'F', '3671979220', 'NULL', 0),
('PCCCRL13E56E029N', 'Paccagnella', 'Carola', '2013-05-16', 'F', '3728723178', 'NULL', 0.3),
('PCCCTN89A31E586H', 'Picciriello', 'Costanzo', '1989-01-31', 'M', '3194444638', 'costanzo.picciriello@gmail.com', 0),
('PCCFLV17E05F229Y', 'Pecchioli', 'Flavio', '2017-05-05', 'M', '3584319179', 'NULL', 0),
('PCCMRO95S46L810D', 'Picchi', 'Moira', '1995-11-06', 'F', '3586670575', 'moira.picchi@gmail.com', 0.2),
('PCCPSC51C61A317L', 'Paccagnini', 'Priscilla', '1951-03-21', 'F', '3526153175', 'NULL', 0),
('PCCWND89D48G134B', 'Pecchioli', 'Wanda', '1989-04-08', 'F', '3431120313', 'NULL', 0.3),
('PDNGTT52P47B608J', 'Padoani', 'Giuditta', '1952-09-07', 'F', '3595714839', 'NULL', 0),
('PDRGTR15H55F569G', 'Pedrali', 'Geltrude', '2015-06-15', 'F', '3793619940', 'NULL', 0),
('PDSPNG12R62G362A', 'Podestà', 'Pierangela', '2012-10-22', 'F', '3433241126', 'pierangela.podestà@alice.it', 0),
('PFFCST93P51B789D', 'Paffumi', 'Cristiana', '1993-09-11', 'F', '3090906252', 'NULL', 0),
('PGGBRT14S55L007L', 'Poggiolo', 'Berta', '2014-11-15', 'F', '3623346046', 'NULL', 0),
('PGZTLD95A53E045P', 'Pigozzi', 'Tilde', '1995-01-13', 'F', '3257236691', 'NULL', 0),
('PLCMRC79A43F968A', 'Paolucci', 'Marica', '1979-01-03', 'F', '3766783559', 'NULL', 0),
('PLDDZN43L54L317W', 'Polidoro', 'Domiziana', '1943-07-14', 'F', '3206900885', 'NULL', 0),
('PLDLEA92T51E439Q', 'Polidoro', 'Lea', '1992-12-11', 'F', '3153379750', 'NULL', 0),
('PLGNTN89A12L879G', 'Pelegatti', 'Antonio', '1989-01-12', 'M', '3758911647', 'antonio.pelegatti@virgilio.it', 0.25),
('PLLCLL63T51E165R', 'Paulli', 'Camilla', '1963-12-11', 'F', '3791658540', 'NULL', 0),
('PLLLCA90S09I242G', 'Pellacani', 'Alceo', '1990-11-09', 'M', '3142332442', 'NULL', 0),
('PLLMCL69A51F396I', 'Pellizzon', 'Immacolata', '1969-01-11', 'F', '3624248234', 'NULL', 0),
('PLLPIA65D47A906G', 'Pallotto', 'Pia', '1965-04-07', 'F', '3400303134', 'NULL', 0.3),
('PLMLDN64B42C090A', 'Palmesano', 'Loredana', '1964-02-02', 'F', '3212351434', 'NULL', 0),
('PLMNNZ11T48I181O', 'Palmitessa', 'Annunziata', '2011-12-08', 'F', '3101389195', 'annunziata.palmitessa@virgilio.it', 0),
('PLNLSU47C48F503Q', 'Piolini', 'Luisa', '1947-03-08', 'F', '3672526962', 'NULL', 0),
('PLNMRA00M24I174E', 'Poloni', 'Mario', '2000-08-24', 'M', '3026883234', 'mario.poloni@virgilio.it', 0),
('PLPSML73M21G560A', 'Pulpito', 'Samuele', '1973-08-21', 'M', '3047104164', 'NULL', 0),
('PLTDCC62H28C971T', 'Polati', 'Duccio', '1962-06-28', 'M', '3359274750', 'NULL', 0.1),
('PLTGLM68C31L731I', 'Pilittu', 'Girolamo', '1968-03-31', 'M', '3644865288', 'NULL', 0),
('PLTGST49E04F405Y', 'Polato', 'Egisto', '1949-05-04', 'M', '3277046161', 'NULL', 0),
('PLTSLL86M69C141H', 'Pioltelli', 'Stella', '1986-08-29', 'F', '3952235598', 'NULL', 0),
('PLTTTV50M07C082Q', 'Apolito', 'Ottavio', '1950-08-07', 'M', '3970034067', 'NULL', 0),
('PLVTLL98C26H581H', 'Polverino', 'Otello', '1998-03-26', 'M', '3931448671', 'NULL', 0),
('PLZCRL84R25B513W', 'Pelizzo', 'Carlo', '1984-10-25', 'M', '3977885760', 'NULL', 0),
('PLZFRZ17L64L277L', 'Palazzo', 'Fabrizia', '2017-07-24', 'F', '3263833858', 'fabrizia.palazzo@alice.it', 0),
('PMNBDT72P68D423A', 'Pomini', 'Benedetta', '1972-09-28', 'F', '3298319986', 'NULL', 0),
('PMPPRZ68S19E034K', 'Pampani', 'Patrizio', '1968-11-19', 'M', '3182139483', 'NULL', 0),
('PNALVC05M69H723U', 'Pane', 'Ludovica', '2005-08-29', 'F', '3265632128', 'NULL', 0),
('PNBNZR71R25D049J', 'Panebianco', 'Nazzareno', '1971-10-25', 'M', '3637455549', 'NULL', 0.2),
('PNCFNC43D19H489E', 'Pancrazi', 'Francesco', '1943-04-19', 'M', '3476741982', 'NULL', 0.3),
('PNCGBR61L29F802M', 'Paniccia', 'Gilberto', '1961-07-29', 'M', '3335793910', 'NULL', 0.15),
('PNDTZN84P11D858V', 'Pandolfo', 'Tiziano', '1984-09-11', 'M', '3343255687', 'tiziano.pandolfo@alice.it', 0.15),
('PNRDND75H67F960P', 'Panara', 'Doranda', '1975-06-27', 'F', '3509002864', 'doranda.panara@virgilio.it', 0.3),
('PNSMDA01R25E305S', 'Pensato', 'Amedeo', '2001-10-25', 'M', '3655527511', 'NULL', 0),
('PNZFLV65E53L738E', 'Ponzone', 'Flavia', '1965-05-13', 'F', '3900044701', 'NULL', 0),
('PNZGLD17A03E432K', 'Pinzani', 'Gildo', '2017-01-03', 'M', '3498184179', 'NULL', 0),
('PNZRMN66C46A515D', 'Punzi', 'Ramona', '1966-03-06', 'F', '3547491313', 'NULL', 0.2),
('PPADLB46E47D456A', 'Papia', 'Doralba', '1946-05-07', 'F', '3572116240', 'NULL', 0),
('PPLLCL65P29C954C', 'Papalato', 'Lucilio', '1965-09-29', 'M', '3296716664', 'NULL', 0),
('PPOBRN96A01C638O', 'Oppio', 'Bruno', '1996-01-01', 'M', '3503001443', 'NULL', 0.25),
('PPPGDI97R46E769P', 'Pappi', 'Giada', '1997-10-06', 'F', '3867682574', 'NULL', 0),
('PRASML65A29L620L', 'Aprea', 'Samuele', '1965-01-29', 'M', '3703212857', 'NULL', 0),
('PRCNDR45E07F074U', 'Peraccini', 'Andrea', '1945-05-07', 'M', '3971809034', 'andrea.peraccini@pec.it', 0.25),
('PRJMRZ99H57F640Y', 'Prejano', 'Maurizia', '1999-06-17', 'F', '3730269733', 'NULL', 0),
('PRLLVS14C04C615I', 'Pirali', 'Alvise', '2014-03-04', 'M', '3361960180', 'NULL', 0),
('PRLSVR74C06F594Q', 'Prola', 'Saverio', '1974-03-06', 'M', '3033359959', 'saverio.prola@outlook.it', 0),
('PRLZOE03C70C273Y', 'Perla', 'Zoe', '2003-03-30', 'F', '3065386065', 'NULL', 0),
('PRMMLA72A68H633B', 'Primieri', 'Amalia', '1972-01-28', 'F', '3047940098', 'NULL', 0.1),
('PRMTZN49A22B598F', 'Parmiggiani', 'Tiziano', '1949-01-22', 'M', '3855199749', 'NULL', 0),
('PRNNNZ67L21C943E', 'Pirano', 'Nunzio', '1967-07-21', 'M', '3821561433', 'nunzio.pirano@outlook.it', 0),
('PRNRRG55D02E325X', 'Pernice', 'Rodrigo', '1955-04-02', 'M', '3620708469', 'NULL', 0),
('PRRDRO14H57E742W', 'Parravicini', 'Dora', '2014-06-17', 'F', '3508665479', 'NULL', 0),
('PRRDVD13H02B576B', 'Perretta', 'Davide', '2013-06-02', 'M', '3438151971', 'NULL', 0),
('PRRFRZ83H06F833Y', 'Porrini', 'Fabrizio', '1983-06-06', 'M', '3210807853', 'fabrizio.porrini@outlook.it', 0),
('PRRLDN89P08L454N', 'Perrelli', 'Aldino', '1989-09-08', 'M', '3553100511', 'NULL', 0.1),
('PRSCLR77C58D874Q', 'Persichello', 'Clara', '1977-03-18', 'F', '3878375185', 'clara.persichello@gmail.com', 0),
('PRSMLA11T67L102Y', 'Piersanti', 'Amalia', '2011-12-27', 'F', '3344992955', 'NULL', 0),
('PRSPNG11D50F007G', 'Presente', 'Pierangela', '2011-04-10', 'F', '3197827481', 'NULL', 0),
('PRTLVS60T02G843N', 'Perotti', 'Alvise', '1960-12-02', 'M', '3564806922', 'NULL', 0.2),
('PRTNRO76M48E893Q', 'Peritore', 'Nora', '1976-08-08', 'F', '3680529960', 'NULL', 0),
('PRTPLG06L29E914Y', 'Pierotti', 'Pellegrino', '2006-07-29', 'M', '3403554050', 'NULL', 0),
('PRVDLL98T44C904G', 'Pirovini', 'Dalila', '1998-12-04', 'F', '3565154336', 'NULL', 0),
('PRVLNZ01H06H930W', 'Provenzano', 'Lorenzo', '2001-06-06', 'M', '3179824558', 'NULL', 0),
('PRZMRL84P28E055O', 'Pirozzo', 'Maurilio', '1984-09-28', 'M', '3356456261', 'NULL', 0),
('PRZMRN74E60E723N', 'Parzani', 'Morena', '1974-05-20', 'F', '3624836041', 'NULL', 0.15),
('PRZSCR82L16B182I', 'Peruzzini', 'Oscar', '1982-07-16', 'M', '3480300068', 'NULL', 0),
('PSARSR81T27D994H', 'Pasi', 'Rosario', '1981-12-27', 'M', '3608485314', 'NULL', 0),
('PSRGLN81S47B748Q', 'Pisaroni', 'Giuliana', '1981-11-07', 'F', '3523668009', 'giuliana.pisaroni@gmail.com', 0),
('PSSVNI96C71F306S', 'Passalenti', 'Ivana', '1996-03-31', 'F', '3237559853', 'NULL', 0),
('PSTGNE65R48F970U', 'Postiglioni', 'Eugenia', '1965-10-08', 'F', '3264719901', 'NULL', 0),
('PSTGNN64C51H881H', 'Pastor', 'Giovanna', '1964-03-11', 'F', '3632954680', 'NULL', 0),
('PSTNRO94B44L322D', 'Apostoli', 'Nora', '1994-02-04', 'F', '3637428386', 'NULL', 0.2),
('PTMGLL51M66F162A', 'Patamia', 'Gisella', '1951-08-26', 'F', '3101107286', 'gisella.patamia@gmail.com', 0),
('PTRCST64M64G116H', 'Putrino', 'Celeste', '1964-08-24', 'F', '3967994416', 'NULL', 0),
('PTRGLL57M54I962N', 'Petrucci', 'Gisella', '1957-08-14', 'F', '3276030765', 'gisella.petrucci@gmail.com', 0.2),
('PTRLRN60R59L944A', 'Patarini', 'Lorena', '1960-10-19', 'F', '3806059811', 'lorena.patarini@virgilio.it', 0.3),
('PTRMRT42A60I452L', 'Patruno', 'Ombretta', '1942-01-20', 'F', '3568788213', 'ombretta.patruno@pec.it', 0),
('PTTGLL45E15L207X', 'Petitto', 'Galileo', '1945-05-15', 'M', '3610486288', 'NULL', 0),
('PTTMRT52L14D458K', 'Pettoni', 'Umberto', '1952-07-14', 'M', '3088837548', 'NULL', 0.1),
('PTTPRI53L23F493W', 'Pittalis', 'Piero', '1953-07-23', 'M', '3203783631', 'piero.pittalis@outlook.it', 0.1),
('PVNLGR56E41F046O', 'Peviani', 'Allegra', '1956-05-01', 'F', '3010680402', 'NULL', 0),
('PVZMCL96E42E727E', 'Ipaviz', 'Marcella', '1996-05-02', 'F', '3668304456', 'marcella.ipaviz@virgilio.it', 0.15),
('PZZDRN65C43A100I', 'Pozzoni', 'Doriana', '1965-03-03', 'F', '3627398977', 'NULL', 0),
('PZZMAI03C58I066F', 'Pizzichella', 'Maia', '2003-03-18', 'F', '3719060481', 'NULL', 0),
('PZZMGH05E51H006Y', 'Pizzighella', 'Margherita', '2005-05-11', 'F', '3968834911', 'NULL', 0.15),
('PZZSFN98T69E531D', 'Pezzutti', 'Stefania', '1998-12-29', 'F', '3481411248', 'stefania.pezzutti@outlook.it', 0.1),
('PZZSRI15B21B287T', 'Pozza', 'Siro', '2015-02-21', 'M', '3755833029', 'NULL', 0),
('QNTCLL52T28H480V', 'Quintilio', 'Catello', '1952-12-28', 'M', '3057597189', 'NULL', 0),
('QNTNTL45A67C294E', 'Quintiliani', 'Natalia', '1945-01-27', 'F', '3887597349', 'NULL', 0.25),
('QRCCLD61L26I970H', 'Querci', 'Cataldo', '1961-07-26', 'M', '3059610305', 'cataldo.querci@virgilio.it', 0),
('QRCMMM97B27B144B', 'Quercia', 'Mimmo', '1997-02-27', 'M', '3489392891', 'NULL', 0.1),
('QSSLLD40S07E651M', 'Quassi', 'Leopoldo', '1940-11-07', 'M', '3661446660', 'NULL', 0),
('RBNDNT09R08I359T', 'Rubino', 'Donato', '2009-10-08', 'M', '3918768534', 'NULL', 0.15),
('RCARTD11P14H532J', 'Arico', 'Aristide', '2011-09-14', 'M', '3497766468', 'aristide.arico@virgilio.it', 0.2),
('RCCBGI05B25L063H', 'Riccoboni', 'Biagio', '2005-02-25', 'M', '3494155402', 'NULL', 0),
('RCCPTR74M04E403Z', 'Ricchiuti', 'Pietro', '1974-08-04', 'M', '3743553195', 'pietro.ricchiuti@outlook.it', 0),
('RCCRML51M08L219U', 'Reccagni', 'Romolo', '1951-08-08', 'M', '3182018350', 'NULL', 0),
('RCDTTR11B28F147L', 'Arcidiacono', 'Ettore', '2011-02-28', 'M', '3217151522', 'NULL', 0),
('RCHRSN13L66A029R', 'Archinti', 'Rossana', '2013-07-26', 'F', '3462873799', 'NULL', 0.25),
('RCIFMN52C18E899C', 'Ierace', 'Flaminio', '1952-03-18', 'M', '3421497229', 'NULL', 0),
('RCLRSO79L59G461E', 'Ercoles', 'Rosa', '1979-07-19', 'F', '3988765243', 'NULL', 0),
('RCPRMN11T25A616S', 'Arcipreti', 'Erminio', '2011-12-25', 'M', '3082572077', 'NULL', 0.2),
('RCTRLA61P67D291A', 'Ricetto', 'Aurelia', '1961-09-27', 'F', '3984823660', 'NULL', 0),
('RDGFST55A56C771X', 'Ardigo’', 'Fausta', '1955-01-16', 'F', '3477515469', 'NULL', 0),
('RDGSNT80E47C294B', 'Redigonda', 'Assunta', '1980-05-07', 'F', '3265742586', 'NULL', 0),
('RDLGRL56E67B268S', 'Ridolfi', 'Gabriella', '1956-05-27', 'F', '3230784508', 'NULL', 0.1),
('RDMMLN68L46G312T', 'Ardemanni', 'Melania', '1968-07-06', 'F', '3638482569', 'NULL', 0),
('RDMSVN88A56B453K', 'Ardemagni', 'Silvana', '1988-01-16', 'F', '3253871744', 'NULL', 0),
('RDRLSS77T58G865K', 'Rodrigues', 'Larissa', '1977-12-18', 'F', '3569409695', 'NULL', 0),
('RDTLNZ91S55A870E', 'Ardito', 'Lorenza', '1991-11-15', 'F', '3346609227', 'NULL', 0.3),
('RDTMNL07L21B062R', 'Ardito', 'Emanuele', '2007-07-21', 'M', '3536427279', 'NULL', 0),
('RDVNBL84S43C919G', 'Ardovini', 'Annabella', '1984-11-03', 'F', '3750876386', 'NULL', 0.05),
('RFFFRZ72C60G071F', 'Aroffu', 'Fabrizia', '1972-03-20', 'F', '3715449760', 'fabrizia.aroffu@alice.it', 0),
('RFOSNO44H70B219M', 'Orfei', 'Sonia', '1944-06-30', 'F', '3526981530', 'NULL', 0),
('RGGCGR47M15C389T', 'Roggiani', 'Calogero', '1947-08-15', 'M', '3440616482', 'calogero.roggiani@gmail.com', 0),
('RGGCMN83E19B567W', 'Raggiotto', 'Carmine', '1983-05-19', 'M', '3377131018', 'carmine.raggiotto@alice.it', 0),
('RGGGRM73E28H121K', 'Ruggieri', 'Geremia', '1973-05-28', 'M', '3220412746', 'NULL', 0),
('RGGSNO13B52A676B', 'Reggiani', 'Sonia', '2013-02-12', 'F', '3441141297', 'sonia.reggiani@alice.it', 0),
('RGLDNI00A41L607U', 'Rigoli', 'Diana', '2000-01-01', 'F', '3478344421', 'NULL', 0),
('RGLGNS65T60H614F', 'Rigoletti', 'Agnese', '1965-12-20', 'F', '3902091387', 'agnese.rigoletti@virgilio.it', 0.1),
('RGNRNL97A56L154A', 'Argenti', 'Reginella', '1997-01-16', 'F', '3279773713', 'NULL', 0),
('RGOFBL42P54A084J', 'Orgiu', 'Fabiola', '1942-09-14', 'F', '3781474263', 'NULL', 0.1),
('RGSSRN58P69G854Z', 'Raguseo', 'Serena', '1958-09-29', 'F', '3815098179', 'serena.raguseo@gmail.com', 0),
('RIUPMR41T70C129J', 'Iuri', 'Palmira', '1941-12-30', 'F', '3171778969', 'NULL', 0),
('RLACTN98M06D888E', 'Raiolo', 'Cateno', '1998-08-06', 'M', '3372055601', 'NULL', 0),
('RLDBRN66T23L449H', 'Rioldi', 'Bruno', '1966-12-23', 'M', '3503512797', 'bruno.rioldi@alice.it', 0.15),
('RLDCLL01C58A910T', 'Araldo', 'Clelia', '2001-03-18', 'F', '3766868098', 'clelia.araldo@virgilio.it', 0),
('RLDDTT99A54A409H', 'Airoldo', 'Diletta', '1999-01-14', 'F', '3433283543', 'NULL', 0.3),
('RLDFLV63B54F330A', 'Arioldi', 'Fulvia', '1963-02-14', 'F', '3054053466', 'NULL', 0),
('RLLCST83A64L503V', 'Roll', 'Cristina', '1983-01-24', 'F', '3826133039', 'NULL', 0),
('RLLPLP15S64A028H', 'Rollo', 'Penelope', '2015-11-24', 'F', '3052744723', 'NULL', 0),
('RLLSNT01M51I673M', 'Iurilli', 'Samanta', '2001-08-11', 'F', '3774622874', 'samanta.iurilli@gmail.com', 0),
('RLNFDR86D07G979Q', 'Rolando', 'Fedro', '1986-04-07', 'M', '3187205582', 'NULL', 0),
('RLNNTN74S09B162P', 'Orlando', 'Antonio', '1974-11-09', 'M', '3606169182', 'NULL', 0.1),
('RMCLRT88A61D640Q', 'Ermacora', 'Alberta', '1988-01-21', 'F', '3399789723', 'NULL', 0),
('RMLCSS90L30D352B', 'Rimoldi', 'Cassio', '1990-07-30', 'M', '3448800516', 'NULL', 0),
('RMNDLD89H55M366X', 'Ramundo', 'Adelaide', '1989-06-15', 'F', '3432872677', 'adelaide.ramundo@gmail.com', 0),
('RMNFBN87L68I681O', 'Erminio', 'Fabiana', '1987-07-28', 'F', '3376439825', 'NULL', 0),
('RMNLIO71S44A952C', 'Aromando', 'Iole', '1971-11-04', 'F', '3616168624', 'NULL', 0.3),
('RMNRLB87T53B566T', 'Raimondi', 'Rosalba', '1987-12-13', 'F', '3864262845', 'rosalba.raimondi@virgilio.it', 0),
('RMNVND98P44C020F', 'Armandino', 'Vanda', '1998-09-04', 'F', '3499419672', 'NULL', 0),
('RMPLRZ62M19F589P', 'Rampone', 'Lucrezio', '1962-08-19', 'M', '3431310056', 'NULL', 0),
('RNACST76R21D817Y', 'Arena', 'Cristoforo', '1976-10-21', 'M', '3786139047', 'NULL', 0),
('RNAGGN59C02I565Y', 'Aroni', 'Gigino', '1959-03-02', 'M', '3168821732', 'gigino.aroni@alice.it', 0),
('RNBRSM80S02C229Y', 'Arnaboldi', 'Erasmo', '1980-11-02', 'M', '3797739896', 'NULL', 0.15),
('RNCSVS43L31F843W', 'Aronica', 'Silvestro', '1943-07-31', 'M', '3440689746', 'NULL', 0),
('RNDGAI86S17G329E', 'Rinaudo', 'Gaio', '1986-11-17', 'M', '3149256766', 'NULL', 0),
('RNDSNN80E51L653U', 'Renda', 'Susanna', '1980-05-11', 'F', '3277309706', 'NULL', 0.2),
('RNESLV53L46F949H', 'Reni', 'Silvia', '1953-07-06', 'F', '3428823175', 'NULL', 0),
('RNIFTN72H05L957T', 'Ironi', 'Fortunato', '1972-06-05', 'M', '3451868667', 'NULL', 0),
('RNLLSE43R69L571A', 'Rinaldin', 'Elisa', '1943-10-29', 'F', '3278449328', 'elisa.rinaldin@pec.it', 0),
('RNLLVI09L66B771K', 'Ranoldi', 'Livia', '2009-07-26', 'F', '3098161909', 'livia.ranoldi@gmail.com', 0),
('RNLMLD93D57G400J', 'Ranaldo', 'Matilde', '1993-04-17', 'F', '3626698483', 'NULL', 0.1),
('RNLRNL07L13A015E', 'Rinalduzzi', 'Reginaldo', '2007-07-13', 'M', '3062918510', 'reginaldo.rinalduzzi@gmail.com', 0.15),
('RNNMRA74R42E570U', 'Arnone', 'Maria', '1974-10-02', 'F', '3187370958', 'NULL', 0),
('RNRMSS62A46B082T', 'Rineri', 'Melissa', '1962-01-06', 'F', '3507791965', 'melissa.rineri@gmail.com', 0),
('RNRRMO03T07L805A', 'Renier', 'Romeo', '2003-12-07', 'M', '3709949936', 'NULL', 0),
('RNZBRT45T50C547M', 'Arienzo', 'Berta', '1945-12-10', 'F', '3949725659', 'NULL', 0),
('RNZLRT77S25H554L', 'Ranzato', 'Albertino', '1977-11-25', 'M', '3323996851', 'NULL', 0.1),
('RNZYLN46T69F783W', 'Arenzi', 'Ylenia', '1946-12-29', 'F', '3369947666', 'NULL', 0),
('RPNVIO67R26B183E', 'Arpini', 'Ivo', '1967-10-26', 'M', '3524916019', 'NULL', 0.05),
('RRDBBR03E65I794V', 'Ierardi', 'Barbara', '2003-05-25', 'F', '3709732970', 'NULL', 0),
('RRGGTR10M56G604P', 'Arrigone', 'Geltrude', '2010-08-16', 'F', '3138179414', 'NULL', 0),
('RRSMME89B50M052Y', 'Arras', 'Emma', '1989-02-10', 'F', '3354872149', 'emma.arras@pec.it', 0.3),
('RRTRLA04L49C715X', 'Rorato', 'Aurelia', '2004-07-09', 'F', '3780145405', 'NULL', 0.2),
('RSADRO54A66D239T', 'Arosio', 'Dora', '1954-01-26', 'F', '3395551250', 'NULL', 0),
('RSALRZ84H67C614F', 'Rauseo', 'Lucrezia', '1984-06-27', 'F', '3027421525', 'lucrezia.rauseo@alice.it', 0),
('RSATTV81E06H988Y', 'Aresu', 'Ottavio', '1981-05-06', 'M', '3834343061', 'NULL', 0),
('RSCDBR63E21D157B', 'Rescaldina', 'Adalberto', '1963-05-21', 'M', '3000136745', 'NULL', 0),
('RSCWND04A48I283D', 'Rescaldina', 'Wanda', '2004-01-08', 'F', '3540468466', 'NULL', 0),
('RSLSLD03H06H674Z', 'Ursella', 'Osvaldo', '2003-06-06', 'M', '3336977903', 'NULL', 0.15),
('RSNBSL91M06F427C', 'Rosanni', 'Basilio', '1991-08-06', 'M', '3873800684', 'NULL', 0.05),
('RSNCTN13C19B527I', 'Rosanno', 'Cateno', '2013-03-19', 'M', '3315056949', 'cateno.rosanno@virgilio.it', 0),
('RSNFLV67A03C062Q', 'Arsenio', 'Flavio', '1967-01-03', 'M', '3787227984', 'flavio.arsenio@pec.it', 0.25),
('RSNMTN93P28F476N', 'Orsino', 'Martino', '1993-09-28', 'M', '3905590414', 'NULL', 0),
('RSNVRN06M59H726Y', 'Orsini', 'Valeriana', '2006-08-19', 'F', '3930863565', 'NULL', 0),
('RSPPRD11H02G339L', 'Ruspino', 'Paride', '2011-06-02', 'M', '3532730519', 'paride.ruspino@pec.it', 0.3),
('RSPRBN09A60H300O', 'Raspa', 'Rubina', '2009-01-20', 'F', '3537335604', 'rubina.raspa@pec.it', 0),
('RSSGLN74C20B389X', 'Rossato', 'Giuliano', '1974-03-20', 'M', '3937592777', 'NULL', 0),
('RSTLTR74P48B828O', 'Ristoro', 'Elettra', '1974-09-08', 'F', '3981447106', 'NULL', 0.05),
('RSTRME14L26B743D', 'Rosita', 'Remo', '2014-07-26', 'M', '3157013651', 'NULL', 0),
('RTAVDN65T70L354N', 'Arieta', 'Veridiana', '1965-12-30', 'F', '3897520220', 'veridiana.arieta@gmail.com', 0),
('RTLDLR00H53I301W', 'Rotilio', 'Addolorata', '2000-06-13', 'F', '3515542165', 'NULL', 0.25),
('RTLMRT64E60E576O', 'Ortelli', 'Umberta', '1964-05-20', 'F', '3978055173', 'NULL', 0.05),
('RTSFNC15B11C480O', 'Artuso', 'Franco', '2015-02-11', 'M', '3162837359', 'NULL', 0),
('RTSFRZ77T30A772S', 'Artesio', 'Fabrizio', '1977-12-30', 'M', '3132368726', 'NULL', 0),
('RTSGNN07A65F453C', 'Artusi', 'Giovanna', '2007-01-25', 'F', '3381302202', 'NULL', 0.05),
('RTSTCR05A25B698Q', 'Artuso', 'Tancredi', '2005-01-25', 'M', '3712819061', 'NULL', 0),
('RVDSRI42S54D455H', 'Rivadossi', 'Siria', '1942-11-14', 'F', '3828354823', 'NULL', 0),
('RVGCLD61B12L407I', 'Ravaglioli', 'Claudio', '1961-02-12', 'M', '3521209261', 'NULL', 0),
('RVZLDE05R45A390S', 'Ravazzini', 'Elide', '2005-10-05', 'F', '3617019405', 'NULL', 0.15),
('SBLMRA16P63A308H', 'Isabella', 'Maura', '2016-09-23', 'F', '3837376022', 'maura.isabella@gmail.com', 0.2),
('SBRNCN83L07H186V', 'Sibra', 'Innocenzo', '1983-07-07', 'M', '3247407006', 'innocenzo.sibra@pec.it', 0),
('SBTPIO55C03B152M', 'Sobatti', 'Pio ', '1955-03-03', 'M', '3116526998', 'pio.sobatti@virgilio.it', 0.1),
('SCCDVG80A44L162P', 'Isacchini', 'Edvige', '1980-01-04', 'F', '3632657629', 'NULL', 0.1),
('SCCLRC05M27B729U', 'Sciacca', 'Alberico', '2005-08-27', 'M', '3333762783', 'alberico.sciacca@outlook.it', 0.1),
('SCCNRN59T41H432N', 'Sciclone', 'Nazarena', '1959-12-01', 'F', '3734933636', 'NULL', 0),
('SCGMRC01E30F355S', 'Scoglio', 'Marco', '2001-05-30', 'M', '3564389483', 'marco.scoglio@outlook.it', 0.1),
('SCHDRA02E66F786Q', 'Schiaffino', 'Daria', '2002-05-26', 'F', '3765278702', 'NULL', 0),
('SCHDRT91C70F955K', 'Schetti', 'Dorotea', '1991-03-30', 'F', '3598864657', 'NULL', 0),
('SCHFNN99H04B408Y', 'Schiraldi', 'Fernando', '1999-06-04', 'M', '3969541771', 'NULL', 0.15),
('SCHLSN01R41I794U', 'Schifi', 'Luisiana', '2001-10-01', 'F', '3522589029', 'NULL', 0.05),
('SCHMNO73R49G656P', 'Schiavone', 'Monia', '1973-10-09', 'F', '3203746936', 'NULL', 0.05),
('SCHNDR92B23A806E', 'Schiratto', 'Andrea', '1992-02-23', 'M', '3246782111', 'NULL', 0),
('SCHSLN42S57H240Y', 'Schirone', 'Selena', '1942-11-17', 'F', '3296318551', 'selena.schirone@outlook.it', 0),
('SCHSRG73C19F110N', 'Schiavoni', 'Sergio', '1973-03-19', 'M', '3564879515', 'NULL', 0.1),
('SCHVLR69C24H977J', 'Schierano', 'Valerio', '1969-03-24', 'M', '3439078988', 'NULL', 0.25),
('SCLDLF84S02A444O', 'Sicilia', 'Adolfo', '1984-11-02', 'M', '3673964413', 'adolfo.sicilia@gmail.com', 0),
('SCLSST98C29L992O', 'Scialpi', 'Sebastiano', '1998-03-29', 'M', '3835579890', 'NULL', 0),
('SCLVGN78R04H559Z', 'Seculin', 'Virginio', '1978-10-04', 'M', '3491029123', 'NULL', 0.15),
('SCNCTN81C13D703T', 'Scandelli', 'Costantino', '1981-03-13', 'M', '3608667940', 'NULL', 0),
('SCNNLT59B60E180I', 'Scandella', 'Nicoletta', '1959-02-20', 'F', '3966110170', 'NULL', 0.05),
('SCNNSC51H42C273S', 'Scannapiecoro', 'Natascia', '1951-06-02', 'F', '3408788393', 'natascia.scannapiecoro@outlook.it', 0),
('SCPTTR63L18L850P', 'Scappin', 'Ettore', '1963-07-18', 'M', '3054546332', 'NULL', 0.05),
('SCRBRN67M63H538J', 'Scuria', 'Bruna', '1967-08-23', 'F', '3347495385', 'NULL', 0.05),
('SCRBRT16T54G774T', 'Scardina', 'Berta', '2016-12-14', 'F', '3976640804', 'berta.scardina@pec.it', 0.05),
('SCRMGN08E57D567L', 'Scaramel', 'Morgana', '2008-05-17', 'F', '3323414177', 'NULL', 0.05),
('SCRMHL94E41I394D', 'Scarpa', 'Michela', '1994-05-01', 'F', '3692114632', 'NULL', 0),
('SCRMMM53A54D720O', 'Scaramuccia', 'Mimma', '1953-01-14', 'F', '3989415715', 'NULL', 0),
('SCRNNA05M71B582J', 'Scaramello', 'Anna', '2005-08-31', 'F', '3528918519', 'NULL', 0.05),
('SCRVNI49R66A511C', 'Scarpetti', 'Ivana', '1949-10-26', 'F', '3818603422', 'ivana.scarpetti@pec.it', 0),
('SCVPMP80B26H110N', 'Scivoli', 'Pompeo', '1980-02-26', 'M', '3236862382', 'NULL', 0.2),
('SDNBRN01E13A370N', 'Sidoni', 'Bruno', '2001-05-13', 'M', '3536439201', 'bruno.sidoni@virgilio.it', 0),
('SDNMME65T63D328R', 'Seidner', 'Emma', '1965-12-23', 'F', '3537648795', 'NULL', 0),
('SEURCC17A61F085T', 'Seu', 'Rocca', '2017-01-21', 'F', '3369963506', 'NULL', 0.05),
('SGGGTN15P08D899P', 'Saggini', 'Gastone', '2015-09-08', 'M', '3846368042', 'NULL', 0),
('SGGRMN13T10I564G', 'Saggina', 'Romano', '2013-12-10', 'M', '3748200809', 'NULL', 0),
('SGGRMN91H54E107Z', 'Soggiri', 'Romana', '1991-06-14', 'F', '3384446315', 'NULL', 0),
('SGGRNI54C48I354W', 'Saggina', 'Rina', '1954-03-08', 'F', '3674943722', 'rina.saggina@virgilio.it', 0),
('SGLMSM91T01E730P', 'Saglimbene', 'Massimo', '1991-12-01', 'M', '3529024988', 'NULL', 0),
('SGSVNI13S08I072E', 'Sigismondo', 'Ivano', '2013-11-08', 'M', '3133929065', 'ivano.sigismondo@alice.it', 0.3),
('SIALHN94B25F544D', 'Iasi', 'Luchino', '1994-02-25', 'M', '3840591670', 'luchino.iasi@pec.it', 0),
('SIAMLT00C09G867B', 'Isaia', 'Amleto', '2000-03-09', 'M', '3470947019', 'NULL', 0.2),
('SIASRA67T07H739S', 'Iasio', 'Saro', '1967-12-07', 'M', '3898804964', 'saro.iasio@pec.it', 0),
('SLASFN83B56H378U', 'Sale', 'Stefania', '1983-02-16', 'F', '3070498786', 'NULL', 0),
('SLDGLL50R57L820X', 'Soldano', 'Gisella', '1950-10-17', 'F', '3514337650', 'NULL', 0.25),
('SLMWTR59E24L062D', 'Solmi', 'Walter', '1959-05-24', 'M', '3269991268', 'NULL', 0),
('SLNDTL14B43A565O', 'Silenzi', 'Domitilla', '2014-02-03', 'F', '3016538280', 'NULL', 0),
('SLRBGI48M23I288J', 'Salernitano', 'Biagio', '1948-08-23', 'M', '3698831812', 'NULL', 0),
('SLTLND84L22C517I', 'Solito', 'Lindo', '1984-07-22', 'M', '3637473121', 'NULL', 0.3),
('SLVGTN05B15A491A', 'Silvestro', 'Gastone', '2005-02-15', 'M', '3781183647', 'NULL', 0),
('SLVLVR85H28E203T', 'Salvadore', 'Alvaro', '1985-06-28', 'M', '3758721388', 'alvaro.salvadore@gmail.com', 0.2),
('SLVMRG81M30G840B', 'Salvagno', 'Ambrogio', '1981-08-30', 'M', '3718233504', 'NULL', 0),
('SLVTZN00E44G949H', 'Salvidio', 'Tiziana', '2000-05-04', 'F', '3934465461', 'NULL', 0.1),
('SMNCLL95R70E851B', 'Simoncelli', 'Clelia', '1995-10-30', 'F', '3518059321', 'NULL', 0.05),
('SMRGTV16C42H621N', 'Samarini', 'Gustava', '2016-03-02', 'F', '3025950369', 'gustava.samarini@outlook.it', 0),
('SMRRLL41S58D740F', 'Samaro', 'Rosella', '1941-11-18', 'F', '3467678160', 'NULL', 0.25),
('SMRRTD77A31F731P', 'Smeraldina', 'Aristide', '1977-01-31', 'M', '3557594786', 'NULL', 0),
('SNCLRG65T04B739K', 'Sinicco', 'Alberigo', '1965-12-04', 'M', '3828485255', 'NULL', 0),
('SNGLDA78P46F877X', 'Sangiorgio', 'Alda', '1978-09-06', 'F', '3623193950', 'alda.sangiorgio@virgilio.it', 0.1),
('SNGNVE16H26A412S', 'Sanguineti', 'Nevio', '2016-06-26', 'M', '3677633322', 'NULL', 0),
('SNIFCT42L69I405P', 'Siano', 'Felicita', '1942-07-29', 'F', '3040201253', 'NULL', 0),
('SNNSRN87E47I278X', 'Sannini', 'Serena', '1987-05-07', 'F', '3706802253', 'serena.sannini@outlook.it', 0.2),
('SNPDRT53E48B893M', 'Sinopoli', 'Dorotea', '1953-05-08', 'F', '3873996962', 'NULL', 0),
('SNSMRC06A48A025C', 'Sanesi', 'America', '2006-01-08', 'F', '3545995834', 'NULL', 0),
('SNTLRC12B44E515C', 'Santella', 'Ulderica', '2012-02-04', 'F', '3696959163', 'NULL', 0),
('SNTMRA47D09M140Q', 'Santovito', 'Mauro', '1947-04-09', 'M', '3051214561', 'NULL', 0.25),
('SNTVGL44B44B136B', 'Santarsieri', 'Virgilia', '1944-02-04', 'F', '3740574617', 'NULL', 0.1),
('SNZFNZ67C08E130W', 'Sanza', 'Fiorenzo', '1967-03-08', 'M', '3970807603', 'NULL', 0),
('SPDSLL55D49A656W', 'Spedaliere', 'Stella', '1955-04-09', 'F', '3950183757', 'NULL', 0),
('SPDVNA97S70B270H', 'Spadea', 'Vania', '1997-11-30', 'F', '3263405819', 'vania.spadea@outlook.it', 0),
('SPIMTN40D10D088E', 'Isopi', 'Martino', '1940-04-10', 'M', '3918999396', 'martino.isopi@gmail.com', 0.1),
('SPMNZE85T14C351R', 'Spampinato', 'Enzo', '1985-12-14', 'M', '3954397461', 'NULL', 0),
('SPPBRT89R52I611Y', 'Sapuppo', 'Berta', '1989-10-12', 'F', '3437568870', 'NULL', 0),
('SPRCMN09L44H034L', 'Sperti', 'Clementina', '2009-07-04', 'F', '3331579542', 'NULL', 0),
('SPRRND97R26C773F', 'Sparace', 'Orlando', '1997-10-26', 'M', '3467230320', 'NULL', 0.15),
('SPRVGN08T11L809D', 'Spurio', 'Virginio', '2008-12-11', 'M', '3128175719', 'virginio.spurio@alice.it', 0),
('SPSGNR05P05A313P', 'Esposito', 'Gennaro', '2005-09-05', 'M', '3342577107', 'NULL', 0),
('SPZCMN74D10D760K', 'Spezzaferro', 'Clemente', '1974-04-10', 'M', '3403695932', 'NULL', 0),
('SQNLRT96B49B656S', 'Asquini', 'Alberta', '1996-02-09', 'F', '3084123026', 'NULL', 0),
('SRAVGL67P65H810T', 'Asaro', 'Virgilia', '1967-09-25', 'F', '3682587370', 'NULL', 0),
('SRBCLL02M42E621T', 'Sorba', 'Clelia', '2002-08-02', 'F', '3650183692', 'clelia.sorba@outlook.it', 0.25),
('SRCGLI77R15A789O', 'Sirocchi', 'Gioele', '1977-10-15', 'M', '3418111359', 'NULL', 0),
('SRRDZN01C51C141Q', 'Sorrenti', 'Domiziana', '2001-03-11', 'F', '3084584730', 'domiziana.sorrenti@outlook.it', 0),
('SRSGTN92S16G641U', 'Sarais', 'Gastone', '1992-11-16', 'M', '3848098157', 'NULL', 0),
('SSACLR00B66H403V', 'Assi', 'Clara', '2000-02-26', 'F', '3186077620', 'NULL', 0.15),
('SSITNI62R44I925W', 'Iessi', 'Tina', '1962-10-04', 'F', '3960525182', 'NULL', 0.15),
('SSNGMN45D04H171B', 'Sisinno', 'Germano', '1945-04-04', 'M', '3443326477', 'NULL', 0.25),
('SSNLCA69L19E878J', 'Sisenna', 'Alceo', '1969-07-19', 'M', '3441690758', 'alceo.sisenna@pec.it', 0),
('SSONZE70T45E910A', 'Osso', 'Enza', '1970-12-05', 'F', '3124707945', 'enza.osso@virgilio.it', 0.25),
('SSSPRD64H26E968P', 'Assisi', 'Paride', '1964-06-26', 'M', '3279705378', 'NULL', 0.1),
('STCCLO04R49G062I', 'Stecchelli', 'Cloe', '2004-10-09', 'F', '3798099759', 'NULL', 0.1),
('STCTTV87B08L484Q', 'Stecco', 'Ottavio', '1987-02-08', 'M', '3747814468', 'NULL', 0),
('STFFNC70S70B675O', 'Stefanel', 'Franca', '1970-11-30', 'F', '3367255711', 'NULL', 0.2),
('STFPRI80D68E184R', 'Stefanè', 'Piera', '1980-04-28', 'F', '3288548781', 'NULL', 0.15),
('STFRRT76T44F407N', 'Stefanon', 'Roberta', '1976-12-04', 'F', '3155070205', 'NULL', 0),
('STLCRI05D27L245O', 'Stolfa', 'Icaro', '2005-04-27', 'M', '3270671089', 'NULL', 0.25),
('STLNNI99T09C781M', 'Stolfa', 'Nino', '1999-12-09', 'M', '3036668091', 'NULL', 0.15),
('STNBLD83S10H316V', 'Stanghi', 'Ubaldo', '1983-11-10', 'M', '3622400610', 'NULL', 0),
('STNCSN59C68B802Z', 'Austoni', 'Cassandra', '1959-03-28', 'F', '3273253596', 'NULL', 0),
('STRCML17P23E295Q', 'Stracuzzi', 'Carmelo', '2017-09-23', 'M', '3722284200', 'carmelo.stracuzzi@outlook.it', 0),
('STRDRA98C65C943H', 'Straccio', 'Daria', '1998-03-25', 'F', '3053949342', 'NULL', 0),
('STRGAI16M03G028J', 'Stradaioli', 'Gaio', '2016-08-03', 'M', '3354598477', 'NULL', 0),
('STRGIO12B41L720L', 'Stridi', 'Gioia', '2012-02-01', 'F', '3187586031', 'NULL', 0.1),
('STRGLD42D18D815W', 'Stregapete', 'Gildo', '1942-04-18', 'M', '3894132465', 'NULL', 0),
('STRLRT68M30C429A', 'Astarotta', 'Alberto', '1968-08-30', 'M', '3823390915', 'alberto.astarotta@virgilio.it', 0),
('STRRNL84D21I970A', 'Strazzullo', 'Reginaldo', '1984-04-21', 'M', '3760885936', 'NULL', 0),
('STRTMS49R56F044D', 'Stranges', 'Tommasina', '1949-10-16', 'F', '3022994329', 'NULL', 0),
('STRVTR49B27D293W', 'Astori', 'Vittoriano', '1949-02-27', 'M', '3951018143', 'NULL', 0),
('STTBBR08A55C486V', 'Staiti', 'Barbara', '2008-01-15', 'F', '3920561680', 'NULL', 0.3),
('STTPML56B60L324O', 'Saetta', 'Pamela', '1956-02-20', 'F', '3353287148', 'pamela.saetta@outlook.it', 0),
('SVALVN97H27I226G', 'Savoia', 'Lavinio', '1997-06-27', 'M', '3471162238', 'NULL', 0),
('SVNPPN04M67C738P', 'Savino', 'Peppina', '2004-08-27', 'F', '3982816289', 'NULL', 0),
('TBNTNO78E48E192H', 'Tobini', 'Tonia', '1978-05-08', 'F', '3904910516', 'NULL', 0),
('TBRRNT97D15B225T', 'Tiberio', 'Renato', '1997-04-15', 'M', '3337174712', 'NULL', 0.3),
('TCCLRI75C28M266E', 'Toccafondo', 'Ilario', '1975-03-28', 'M', '3702837807', 'NULL', 0.05),
('TCCNBR50E15B068K', 'Taccoli', 'Norberto', '1950-05-15', 'M', '3592919687', 'NULL', 0),
('TCCRST17P65H096A', 'Tacca', 'Ernesta', '2017-09-25', 'F', '3558037116', 'NULL', 0),
('TDDCLI62L49C880K', 'Taddeo', 'Clio', '1962-07-09', 'F', '3118884788', 'NULL', 0.1),
('TDDMLN57C41G097L', 'Taddei', 'Emiliana', '1957-03-01', 'F', '3273611988', 'NULL', 0),
('TDNGLD93D27C375Z', 'Tudino', 'Gildo', '1993-04-27', 'M', '3131060324', 'NULL', 0.05),
('TDRSMN47A07A960G', 'Toderi', 'Simone', '1947-01-07', 'M', '3078668534', 'NULL', 0),
('TFNZOE05T49B511J', 'Tofani', 'Zoe', '2005-12-09', 'F', '3042713190', 'NULL', 0),
('TLLDNI72A68L409Q', 'Tilla', 'Diana', '1972-01-28', 'F', '3706533785', 'NULL', 0),
('TLLDRD16B23A072T', 'Tulli', 'Edoardo', '2016-02-23', 'M', '3107308312', 'edoardo.tulli@pec.it', 0),
('TLLFMN77H57D428F', 'Telli', 'Filomena', '1977-06-17', 'F', '3360975925', 'NULL', 0),
('TLLMNO95D46G185Y', 'Talloni', 'Monia', '1995-04-06', 'F', '3878909958', 'NULL', 0),
('TMASRA52C59F856N', 'Tame', 'Sara', '1952-03-19', 'F', '3229363833', 'NULL', 0),
('TMMFNC50A47B390U', 'Tummino', 'Francesca', '1950-01-07', 'F', '3752757257', 'NULL', 0),
('TMMMRO98A16F654C', 'Tommassoni', 'Omar', '1998-01-16', 'M', '3071036914', 'NULL', 0.2),
('TMNGVR93T65F582L', 'Tamantini', 'Ginevra', '1993-12-25', 'F', '3290601042', 'NULL', 0.2),
('TMTVCN45H49L640K', 'Tumatis', 'Vincenzina', '1945-06-09', 'F', '3774549939', 'vincenzina.tumatis@outlook.it', 0),
('TNCMRA04B65M374H', 'Tenconi', 'Mara', '2004-02-25', 'F', '3627615943', 'NULL', 0),
('TNDPLT96C05A696A', 'Tondi', 'Ippolito', '1996-03-05', 'M', '3147820114', 'NULL', 0.2),
('TNGSND92M09C312E', 'Tanghetti', 'Secondo', '1992-08-09', 'M', '3313918050', 'NULL', 0),
('TNNLVN91H65H584U', 'Tanino', 'Lavinia', '1991-06-25', 'F', '3870708016', 'NULL', 0),
('TRANRC59L17M401Q', 'Autero', 'Enrico', '1959-07-17', 'M', '3047227615', 'NULL', 0),
('TRAVVN50R43D459Q', 'Autero', 'Viviana', '1950-10-03', 'F', '3899604324', 'viviana.autero@virgilio.it', 0),
('TRBMLD06A54F207V', 'Tribuzi', 'Mafalda', '2006-01-14', 'F', '3143911806', 'mafalda.tribuzi@gmail.com', 0),
('TRLLNS51A22F410S', 'Turle', 'Alfonso', '1951-01-22', 'M', '3178096417', 'NULL', 0),
('TRNCRL13S17C347F', 'Traino', 'Carlo', '2013-11-17', 'M', '3509776363', 'NULL', 0),
('TRNNMO01L50L492M', 'Terni', 'Noemi', '2001-07-10', 'F', '3120726354', 'noemi.terni@outlook.it', 0.25),
('TRNNRN17T45E984J', 'Terenzio', 'Andreina', '2017-12-05', 'F', '3953823458', 'NULL', 0),
('TRNNTL11P20F707F', 'Tirone', 'Natale', '2011-09-20', 'M', '3255261323', 'NULL', 0),
('TRNRME57E18I774Y', 'Tornincasa', 'Remo', '1957-05-18', 'M', '3089397972', 'NULL', 0),
('TRNRSN02A64L682V', 'Tronchin', 'Rossana', '2002-01-24', 'F', '3082429597', 'rossana.tronchin@outlook.it', 0),
('TROMCR87B01B608H', 'Toaiar', 'Amilcare', '1987-02-01', 'M', '3547678290', 'amilcare.toaiar@virgilio.it', 0),
('TRPVTR72A55L968Z', 'Tirapelle', 'Vittorina', '1972-01-15', 'F', '3664607618', 'vittorina.tirapelle@virgilio.it', 0),
('TRRDNI64P46L631K', 'Terracciano', 'Dina', '1964-09-06', 'F', '3263345773', 'NULL', 0),
('TRRNRN50H55F586G', 'Terracina', 'Andreina', '1950-06-15', 'F', '3633669005', 'NULL', 0),
('TRRVGN97T19L814K', 'Turrina', 'Virginio', '1997-12-19', 'M', '3344837081', 'NULL', 0),
('TRSLNE57C65G631Q', 'Tres', 'Eliana', '1957-03-25', 'F', '3027810291', 'NULL', 0),
('TRSMDA44E01G336L', 'Tarsio', 'Amadeo', '1944-05-01', 'M', '3002786799', 'NULL', 0),
('TRSMTT73S14G419L', 'Tarso', 'Matteo', '1973-11-14', 'M', '3629342284', 'NULL', 0),
('TRSRCR07D12E936Q', 'Trisolini', 'Riccardo', '2007-04-12', 'M', '3072694851', 'NULL', 0.3),
('TRTFMN40C11G274T', 'Tortora', 'Flaminio', '1940-03-11', 'M', '3402266969', 'NULL', 0),
('TRTTTI45C05D763V', 'Turato', 'Tito', '1945-03-05', 'M', '3736690826', 'NULL', 0.05),
('TRVDMN78E06L575M', 'Travella', 'Damiano', '1978-05-06', 'M', '3156307393', 'damiano.travella@virgilio.it', 0),
('TRVVTR48L61D832U', 'Trovarello', 'Vittorina', '1948-07-21', 'F', '3058901117', 'NULL', 0),
('TSCCCT81R69F887L', 'Tiscia', 'Concetta', '1981-10-29', 'F', '3831559049', 'concetta.tiscia@outlook.it', 0),
('TSCCLD82E30L213A', 'Toscan', 'Claudio', '1982-05-30', 'M', '3941717901', 'NULL', 0.3),
('TSCRLL90D52G672K', 'Toscano', 'Rosella', '1990-04-12', 'F', '3345065940', 'rosella.toscano@virgilio.it', 0),
('TSLPSC45L64H378I', 'Tosello', 'Priscilla', '1945-07-24', 'F', '3879547537', 'NULL', 0),
('TSSCTN98H21L382W', 'Tassetti', 'Costanzo', '1998-06-21', 'M', '3393651247', 'costanzo.tassetti@gmail.com', 0),
('TSSTTN59T01C578L', 'Tassi', 'Ottone', '1959-12-01', 'M', '3355827581', 'NULL', 0.05),
('TSTLCU13A29G801E', 'Testoni', 'Lucio', '2013-01-29', 'M', '3048822999', 'NULL', 0),
('TSTLND08A20G947L', 'Tosti', 'Lando', '2008-01-20', 'M', '3179777855', 'lando.tosti@outlook.it', 0),
('TSTLTZ67B54G949C', 'Tosatti', 'Letizia', '1967-02-14', 'F', '3810349050', 'NULL', 0),
('TSTMNI02M41C351V', 'Testa', 'Mina', '2002-08-01', 'F', '3479205749', 'NULL', 0.3),
('TSTSRG46M57G728V', 'Tosto', 'Sergia', '1946-08-17', 'F', '3316686629', 'NULL', 0),
('TSTYLO93M67G601S', 'Testaverde', 'Yole', '1993-08-27', 'F', '3474552518', 'NULL', 0.15),
('TTADNL70H63G249V', 'Atti', 'Daniela', '1970-06-23', 'F', '3693153876', 'daniela.atti@virgilio.it', 0.3),
('TTALCA05T53H831H', 'Atta', 'Alice', '2005-12-13', 'F', '3184218605', 'NULL', 0),
('TVRLSU09R41F316G', 'Taverniti', 'Luisa', '2009-10-01', 'F', '3003516157', 'luisa.taverniti@gmail.com', 0),
('TZZBTL98D10G158A', 'Tuzzi', 'Bartolomeo', '1998-04-10', 'M', '3165125128', 'NULL', 0.1),
('TZZLCN46C47H789D', 'Tuozzi', 'Luciana', '1946-03-07', 'F', '3804831156', 'luciana.tuozzi@gmail.com', 0),
('TZZVSC95P01C313N', 'Tuzzio', 'Vasco', '1995-09-01', 'M', '3753807589', 'NULL', 0),
('VCCMRN97D16F526G', 'Viceconte', 'Marino', '1997-04-16', 'M', '3020104371', 'NULL', 0),
('VCCTRS50R64C694D', 'Viciconte', 'Teresa', '1950-10-24', 'F', '3974211412', 'teresa.viciconte@pec.it', 0),
('VCRLRT55R48G434E', 'Vicario', 'Alberta', '1955-10-08', 'F', '3124143618', 'alberta.vicario@outlook.it', 0.2),
('VDIFPP68R03D201X', 'Vido', 'Filippo', '1968-10-03', 'M', '3008395482', 'NULL', 0),
('VDVGGN86A21D066G', 'Vedovelli', 'Gigino', '1986-01-21', 'M', '3410469679', 'NULL', 0.1),
('VDVLVC44R44F639U', 'Vedovati', 'Ludovica', '1944-10-04', 'F', '3097649203', 'NULL', 0),
('VGLMNI78B19L146H', 'Voglino', 'Mino', '1978-02-19', 'M', '3084901872', 'NULL', 0),
('VGRNCL88T01A081Z', 'Avogaro', 'Nicola', '1988-12-01', 'M', '3871427247', 'NULL', 0.1),
('VGRYLN88D53E079O', 'Vigoriti', 'Ylenia', '1988-04-13', 'F', '3205898209', 'NULL', 0),
('VGRYND15R71C910M', 'Vigoriti', 'Yolanda', '2015-10-31', 'F', '3778015222', 'NULL', 0),
('VJNLEA12C48L739L', 'Vajna', 'Lea', '2012-03-08', 'F', '3288579646', 'NULL', 0.15),
('VLDRMN64B27B762N', 'Valdameri', 'Erminio', '1964-02-27', 'M', '3310107911', 'NULL', 0),
('VLLDMA41A19F533D', 'Avalli', 'Adamo', '1941-01-19', 'M', '3475276987', 'NULL', 0),
('VLLSRN04T56I486N', 'Vallon', 'Serena', '2004-12-16', 'F', '3998097512', 'NULL', 0),
('VLNCTN98E25G783F', 'Violanti', 'Cateno', '1998-05-25', 'M', '3857777543', 'cateno.violanti@virgilio.it', 0.25),
('VLNFSC03D50D853H', 'Valenzia', 'Fosca', '2003-04-10', 'F', '3217707444', 'NULL', 0),
('VLNGFR72A01L215X', 'Valente', 'Goffredo', '1972-01-01', 'M', '3800323505', 'NULL', 0),
('VLNLIA93C55G145L', 'Violin', 'Lia', '1993-03-15', 'F', '3973111615', 'NULL', 0),
('VLNLVS91T13L066B', 'Violoni', 'Alvise', '1991-12-13', 'M', '3400481741', 'alvise.violoni@virgilio.it', 0),
('VLNMSC51T71A193O', 'Violanti', 'Mascia', '1951-12-31', 'F', '3334168220', 'NULL', 0.05),
('VLNNBL92P51M004O', 'Valania', 'Annabella', '1992-09-11', 'F', '3999216377', 'NULL', 0.3),
('VLNNVE81A29D728X', 'Volontè', 'Nevio', '1981-01-29', 'M', '3920630771', 'NULL', 0),
('VLNRBN89C48B294V', 'Valenza', 'Rubina', '1989-03-08', 'F', '3806350979', 'NULL', 0),
('VLNSRL02L46F777U', 'Volonté', 'Esmeralda', '2002-07-06', 'F', '3470958165', 'NULL', 0),
('VLPLVC17E21C312C', 'Volpato', 'Ludovico', '2017-05-21', 'M', '3399314535', 'NULL', 0.1),
('VLRLSN73M71L462L', 'Valerio', 'Luisiana', '1973-08-31', 'F', '3558486115', 'NULL', 0.25),
('VLTTCR89C12G881S', 'Valtorta', 'Tancredi', '1989-03-12', 'M', '3898570227', 'tancredi.valtorta@outlook.it', 0),
('VNAMRN73D41D821I', 'Avenia', 'Mariana', '1973-04-01', 'F', '3574233058', 'mariana.avenia@pec.it', 0),
('VNCDRO11R63E767P', 'Vencelli', 'Dora', '2011-10-23', 'F', '3994470183', 'dora.vencelli@gmail.com', 0),
('VNDCRN59A09L768U', 'Vandini', 'Caterino', '1959-01-09', 'M', '3743770630', 'NULL', 0.05),
('VNDLLN08L63E364G', 'Avondo', 'Liliana', '2008-07-23', 'F', '3210867459', 'NULL', 0.3),
('VNDVNZ66T48M333B', 'Vandone', 'Vicenza', '1966-12-08', 'F', '3898101634', 'NULL', 0.1),
('VNDVRN41M52E864S', 'Vendramin', 'Valeriana', '1941-08-12', 'F', '3538997365', 'NULL', 0),
('VNGVNT07H53D223W', 'Evangelisti', 'Valentina', '2007-06-13', 'F', '3042149287', 'NULL', 0),
('VNILCA44H69F059R', 'Viano', 'Alice', '1944-06-29', 'F', '3070218679', 'NULL', 0.1),
('VNNMTA44L41L539I', 'Vanoni', 'Amata', '1944-07-01', 'F', '3074212496', 'NULL', 0.05),
('VNNRFL66H06E323B', 'Vanoni', 'Raffaele', '1966-06-06', 'M', '3066268965', 'NULL', 0.25),
('VNTGAI03T68D481L', 'Vanotta', 'Gaia', '2003-12-28', 'F', '3420298096', 'NULL', 0.3),
('VNTLRT64E21F783M', 'Vanotta', 'Alberto', '1964-05-21', 'M', '3564842687', 'NULL', 0.15),
('VNTMDA92S53L649Y', 'Vinattieri', 'Amedea', '1992-11-13', 'F', '3867056501', 'NULL', 0.2),
('VNTMRC14D45A668X', 'Vantaggi', 'America', '2014-04-05', 'F', '3008196192', 'NULL', 0.15),
('VNTRMN76T55C293H', 'Venta', 'Erminia', '1976-12-15', 'F', '3379569283', 'erminia.venta@virgilio.it', 0.05),
('VNZGTN62C41D769W', 'Vanzin', 'Gaetana', '1962-03-01', 'F', '3308179844', 'NULL', 0),
('VNZNCN96A04I121U', 'Vanzin', 'Innocenzo', '1996-01-04', 'M', '3700402974', 'NULL', 0),
('VRABNR15H24L019D', 'Vari', 'Bernardo', '2015-06-24', 'M', '3930553339', 'NULL', 0.3),
('VRLVGL10L25C918K', 'Verolo', 'Virgilio', '2010-07-25', 'M', '3038936169', 'NULL', 0.1),
('VRNNBL05A09C359E', 'Vernaccia', 'Annibale', '2005-01-09', 'M', '3225506531', 'NULL', 0),
('VRRCMN93T57F747P', 'Varrica', 'Clementina', '1993-12-17', 'F', '3926601437', 'NULL', 0.25),
('VRSCLL55C21A643D', 'Varesi', 'Camillo', '1955-03-21', 'M', '3478744498', 'NULL', 0.25),
('VRTDLE50D61I171P', 'Varetti', 'Delia', '1950-04-21', 'F', '3916582758', 'NULL', 0),
('VRZLNZ67M29F704S', 'Virzo', 'Lorenzo', '1967-08-29', 'M', '3695614069', 'NULL', 0),
('VSPPIA53P55E177A', 'Vespi', 'Pia', '1953-09-15', 'F', '3024665035', 'NULL', 0),
('VSPYLN79A49C908K', 'Vespo', 'Ylenia', '1979-01-09', 'F', '3691019287', 'NULL', 0),
('VTLDFN89C56B921J', 'Vitoli', 'Dafne', '1989-03-16', 'F', '3425157517', 'NULL', 0),
('VTLRFL46B19B667U', 'Vitalone', 'Raffaele', '1946-02-19', 'M', '3569590781', 'raffaele.vitalone@alice.it', 0.05),
('VTLSLL80A66B813F', 'Vitalone', 'Isabella', '1980-01-26', 'F', '3031668769', 'isabella.vitalone@virgilio.it', 0.25),
('VTTBRC81L54L397G', 'Vettori', 'Beatrice', '1981-07-14', 'F', '3765615136', 'NULL', 0.3),
('ZCCLLD57R10H095E', 'Zecca', 'Leopoldo', '1957-10-10', 'M', '3010305295', 'NULL', 0),
('ZCCNDR99D10F067F', 'Zaccaria', 'Andrea', '1999-04-10', 'M', '3809134296', 'NULL', 0),
('ZLFLND54H14D107P', 'Zolfanelli', 'Lindo', '1954-06-14', 'M', '3791030524', 'NULL', 0.1),
('ZLLGRL70M45F498B', 'Zillo', 'Gabriella', '1970-08-05', 'F', '3735865062', 'NULL', 0),
('ZLLNZE09P64A127V', 'Zillo', 'Enza', '2009-09-24', 'F', '3863243403', 'NULL', 0),
('ZLLPNG14A64D720S', 'Zelli', 'Pierangela', '2014-01-24', 'F', '3816346575', 'NULL', 0.2),
('ZLLSVG42P61A363I', 'Zillino', 'Selvaggia', '1942-09-21', 'F', '3313142147', 'NULL', 0),
('ZLODRD84S18F374M', 'Zola', 'Edoardo', '1984-11-18', 'M', '3944003022', 'NULL', 0),
('ZLORCL53M28L008I', 'Zolo', 'Ercole', '1953-08-28', 'M', '3898726721', 'NULL', 0),
('ZMBCSN46H68F784C', 'Zambotti', 'Cassandra', '1946-06-28', 'F', '3617360523', 'cassandra.zambotti@virgilio.it', 0),
('ZMMRNT73A57F109W', 'Zammuto', 'Renata', '1973-01-17', 'F', '3739152300', 'NULL', 0),
('ZMTNNZ40C07G372H', 'Zamataro', 'Nunzio', '1940-03-07', 'M', '3475863702', 'NULL', 0),
('ZNASTN62B44G698F', 'Zane', 'Santina', '1962-02-04', 'F', '3520994976', 'NULL', 0.25),
('ZNBDRN67L47D901B', 'Zanobio', 'Adriana', '1967-07-07', 'F', '3664095451', 'adriana.zanobio@outlook.it', 0),
('ZNBTNO98A66C353F', 'Zanobini', 'Tonia', '1998-01-26', 'F', '3025130035', 'tonia.zanobini@alice.it', 0),
('ZNCCML74T25G874H', 'Zanchi', 'Carmelo', '1974-12-25', 'M', '3156199338', 'NULL', 0),
('ZNDMRN60L49A254J', 'Zendrini', 'Mirena', '1960-07-09', 'F', '3906363044', 'mirena.zendrini@virgilio.it', 0.1),
('ZNELND17E14H159I', 'Zen', 'Olindo', '2017-05-14', 'M', '3888244033', 'NULL', 0),
('ZNEYND87H52G656E', 'Zeno', 'Yolanda', '1987-06-12', 'F', '3094036496', 'NULL', 0.25),
('ZNGNZE50P27C523U', 'Zangrando', 'Enzo', '1950-09-27', 'M', '3779148475', 'enzo.zangrando@pec.it', 0.3),
('ZNGRMI75C49H014I', 'Zangara', 'Irma', '1975-03-09', 'F', '3439104795', 'NULL', 0),
('ZNISDR14L49C848S', 'Ziani', 'Sandrina', '2014-07-09', 'F', '3094502929', 'NULL', 0.15),
('ZNNSRN13D70D304C', 'Zenoni', 'Sabrina', '2013-04-30', 'F', '3276461822', 'sabrina.zenoni@virgilio.it', 0.2),
('ZNRTLI95E27F866S', 'Zanardelli', 'Italo', '1995-05-27', 'M', '3903217939', 'NULL', 0),
('ZNTLSN97R63B510V', 'Zanette', 'Alessandra', '1997-10-23', 'F', '3721735394', 'alessandra.zanette@gmail.com', 0),
('ZPPGNR69T12B396E', 'Zappatori', 'Gennaro', '1969-12-12', 'M', '3993164382', 'NULL', 0.2),
('ZPPLSI97T71F838L', 'Zappavigna', 'Lisa', '1997-12-31', 'F', '3252459107', 'NULL', 0),
('ZPPLTR00R65H517T', 'Zappavigna', 'Elettra', '2000-10-25', 'F', '3695865235', 'NULL', 0.15),
('ZRDFNC83M31D006G', 'Zordan', 'Francesco', '1983-08-31', 'M', '3725444748', 'francesco.zordan@outlook.it', 0),
('ZTTLRT53R16I271Y', 'Zetti', 'Albertino', '1953-10-16', 'M', '3191822239', 'NULL', 0),
('ZTTNRN88P03H558P', 'Zottin', 'Nerone', '1988-09-03', 'M', '3607959155', 'NULL', 0.2),
('ZVGGTN98L67E757J', 'Zavagli', 'Gaetana', '1998-07-27', 'F', '3326366344', 'NULL', 0.1),
('ZVTBDT86D30G776K', 'Zavatteri', 'Benedetto', '1986-04-30', 'M', '3868857778', 'benedetto.zavatteri@alice.it', 0.3),
('ZZACMB80T63I965I', 'Azzia', 'Colomba', '1980-12-23', 'F', '3091240460', 'NULL', 0),
('ZZADGS61H65M344N', 'Aiazzo', 'Adalgisa', '1961-06-25', 'F', '3545828263', 'NULL', 0),
('ZZRLND85T31E153R', 'Zizari', 'Lando', '1985-12-31', 'M', '3102523972', 'NULL', 0),
('ZZRNTL45E26C396L', 'Azzarita', 'Natale', '1945-05-26', 'M', '3692664517', 'natale.azzarita@gmail.com', 0);

--
-- Trigger `pazienti`
--
DROP TRIGGER IF EXISTS `pazienti_INSScontoEcc`;
DELIMITER $$
CREATE TRIGGER `pazienti_INSScontoEcc` BEFORE INSERT ON `pazienti` FOR EACH ROW BEGIN
	IF new.Sconto>1 THEN
    	SET new.Sconto=1;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sconto eccessivo';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `pazienti_UPDScontoEcc`;
DELIMITER $$
CREATE TRIGGER `pazienti_UPDScontoEcc` BEFORE UPDATE ON `pazienti` FOR EACH ROW BEGIN
	IF new.Sconto>1 THEN
    	SET new.Sconto=1;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sconto eccessivo';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struttura della tabella `personale`
--
-- Creazione: Feb 17, 2023 alle 10:39
-- Ultimo aggiornamento: Feb 25, 2023 alle 16:17
--

DROP TABLE IF EXISTS `personale`;
CREATE TABLE IF NOT EXISTS `personale` (
  `ID` int(8) NOT NULL AUTO_INCREMENT,
  `Cognome` varchar(30) NOT NULL,
  `Nome` varchar(30) NOT NULL,
  `Recapito` varchar(13) NOT NULL,
  `E-mail` varchar(50) NOT NULL,
  `Specializzazione` varchar(30) DEFAULT NULL,
  `Stipendio` float NOT NULL,
  `Quota` float NOT NULL DEFAULT 0,
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8mb4;

--
-- RELAZIONI PER TABELLA `personale`:
--

--
-- Svuota la tabella prima dell'inserimento `personale`
--

TRUNCATE TABLE `personale`;
--
-- Dump dei dati per la tabella `personale`
--

INSERT INTO `personale` (`ID`, `Cognome`, `Nome`, `Recapito`, `E-mail`, `Specializzazione`, `Stipendio`, `Quota`) VALUES
(1, 'Filip', 'Pino', '3475684952', 'filip.pino@gmail.com', 'Implantologia', 2500, 0),
(2, 'Pappalardo', 'Daniele', '3289456217', 'pappalardo.daniele@outlook.it', 'Implantologia', 2500, 0),
(3, 'Torrisi', 'Antonio', '3458896521', 'torrisi.antonio@gmail.com', 'Igiene Dentale', 2500, 0),
(4, 'Bianchi', 'Priscilla', '3259664114', 'bianchi.priscilla@gmail.com', 'Igiene Dentale', 2500, 0),
(5, 'Giorgio', 'Giovanni', '3398725654', 'giorgio.giovanni@alice.it', 'Parodontologia', 2500, 0),
(6, 'Escobar', 'Pedro', '3288851293', 'escobar.pedro@virgilio.it', 'Parodontologia', 2500, 0),
(7, 'Pricoco', 'Martina', '3496862541', 'pricoco.martina@alice.it', 'Endodonzia', 2500, 0),
(8, 'Zappalà', 'Ludovica', '3935521469', 'zappala.ludovica@gmail.com', 'Endodonzia', 2500, 0),
(9, 'Di Stefano', 'Stefano', '3458559612', 'distefano.stefano@gmail.com', 'Protesi Dentaria', 2500, 0),
(10, 'Messina', 'Paola', '3589641258', 'messina.paola@gmail.com', 'Protesi Dentaria', 2500, 0),
(11, 'Lanzafame', 'Alfio', '3289456441', 'lanzafame.alfio@gmail.com', 'Odontostomatologia', 2500, 0),
(12, 'Santonocito', 'Maria', '3396555123', 'santonocito.maria@outlook.it', 'Odontostomatologia', 2500, 0),
(13, 'Barbero', 'Alfonso', '3256987214', 'barbero.alfonso@outlook.it', 'Ortognatodonzia', 2500, 0),
(14, 'Calderone', 'Lucia', '3226541978', 'calderone.lucia@gmail.com', 'Ortognatodonzia', 2500, 0),
(15, 'Verdi', 'Luigi', '3456987124', 'verdi.luigi@gmail.com', 'Gnatologia', 2500, 0),
(16, 'Rossi', 'Mario', '3479165428', 'rossi.mario@gmail.com', 'Gnatologia', 2500, 0),
(17, 'Aldini', 'Matteo', '3456974521', 'aldini.matteo@alice.it', NULL, 1800, 0),
(18, 'Aquila', 'Noemi', '3256415258', 'aquila.noemi@gmail.com', NULL, 1800, 0),
(19, 'Cristoforo', 'Elga', '3596458741', 'cristoforo.elga@outlook.it', NULL, 1800, 0),
(20, 'Napoli', 'Giovanna', '3253657914', 'napoli.giovanna@outlook.it', NULL, 1800, 0),
(21, 'Dente', 'Andrea', '3325669855', 'dente.andrea@virgilio.it', NULL, 1800, 0),
(22, 'Favara', 'Gianfranco', '3255419753', 'favara.gianfranco@gmail.com', NULL, 1800, 0),
(23, 'Giotto', 'Alessandro', '3256412879', 'giotto.alessandro@outlook.it', NULL, 1800, 0),
(24, 'Iannone', 'Pietro', '3225654780', 'iannone.pietro@gmail.com', NULL, 1800, 0),
(25, 'Leone', 'Vincenza', '3254520015', 'leone.vincenza@gmail.com', NULL, 1800, 0),
(26, 'Moreno', 'Antonio', '3205489540', 'moreno.antonio@gmail.com', NULL, 1800, 0),
(27, 'Ruspino', 'Roberto', '3257941065', 'ruspino.roberto@gmail.com', NULL, 1800, 0),
(28, 'Cristaldi', 'Daniela', '3257941500', 'cristaldi.daniela@alice.it', NULL, 1800, 0);

--
-- Trigger `personale`
--
DROP TRIGGER IF EXISTS `personale_INSLimiteStipendio`;
DELIMITER $$
CREATE TRIGGER `personale_INSLimiteStipendio` BEFORE INSERT ON `personale` FOR EACH ROW BEGIN
	IF new.Stipendio>5000 THEN
    	SET new.Stipendio=5000;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stipendio superiore a 5000';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `personale_UPDLimiteStipendio`;
DELIMITER $$
CREATE TRIGGER `personale_UPDLimiteStipendio` BEFORE UPDATE ON `personale` FOR EACH ROW BEGIN
	IF new.Stipendio>5000 THEN
    	SET new.Stipendio=5000;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stipendio superiore a 5000';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struttura della tabella `pp`
--
-- Creazione: Feb 16, 2023 alle 10:15
-- Ultimo aggiornamento: Feb 25, 2023 alle 16:17
--

DROP TABLE IF EXISTS `pp`;
CREATE TABLE IF NOT EXISTS `pp` (
  `ID_PP` int(8) NOT NULL AUTO_INCREMENT,
  `Paziente` varchar(16) NOT NULL,
  `Codice_Prestazione` int(8) NOT NULL,
  `Data` datetime NOT NULL,
  `Stanza` enum('A1','A2','A3','A4','B1','B2','B3','B4') NOT NULL,
  `Specialista` int(8) NOT NULL,
  `Assistente` int(8) DEFAULT NULL,
  `Esito` enum('OK','NECESSITA CONTROLLO','NECESSITA TRATTAMENTO') DEFAULT NULL,
  `Importo_Fattura` float DEFAULT NULL,
  PRIMARY KEY (`ID_PP`),
  KEY `Paziente` (`Paziente`),
  KEY `Codice_Prestazione` (`Codice_Prestazione`),
  KEY `Specialista` (`Specialista`),
  KEY `Assistente` (`Assistente`)
) ENGINE=InnoDB AUTO_INCREMENT=1162 DEFAULT CHARSET=utf8mb4;

--
-- RELAZIONI PER TABELLA `pp`:
--   `Paziente`
--       `pazienti` -> `CF`
--   `Codice_Prestazione`
--       `listaprestazioni` -> `Codice_Prestazione`
--   `Specialista`
--       `personale` -> `ID`
--   `Assistente`
--       `personale` -> `ID`
--

--
-- Svuota la tabella prima dell'inserimento `pp`
--

TRUNCATE TABLE `pp`;
--
-- Dump dei dati per la tabella `pp`
--

INSERT INTO `pp` (`ID_PP`, `Paziente`, `Codice_Prestazione`, `Data`, `Stanza`, `Specialista`, `Assistente`, `Esito`, `Importo_Fattura`) VALUES
(1, 'SPMNZE85T14C351R', 14, '2023-11-07 09:14:27', 'B1', 3, NULL, NULL, NULL),
(2, 'FNCMME64H64C351A', 2, '2023-07-12 14:22:29', 'B1', 7, NULL, NULL, NULL),
(3, 'TSTMNI02M41C351V', 11, '2023-03-21 15:47:15', 'A1', 15, NULL, NULL, NULL),
(4, 'MMMGNN85B05C351I', 4, '2023-05-26 14:25:23', 'B1', 1, NULL, NULL, NULL),
(5, 'GRSDLR11H44D594D', 16, '2023-07-19 16:39:18', 'B1', 16, NULL, NULL, NULL),
(6, 'GLLVGN54L41G167D', 1, '2023-05-18 10:04:20', 'A1', 3, NULL, NULL, NULL),
(7, 'FZZLVS57E17I618I', 16, '2023-05-24 14:26:41', 'B1', 16, NULL, NULL, NULL),
(8, 'CSNDLF73R23H347X', 2, '2023-09-11 09:18:49', 'B1', 12, NULL, NULL, NULL),
(9, 'LCCMRZ98L48A341T', 14, '2023-07-17 09:20:46', 'B1', 4, NULL, NULL, NULL),
(10, 'GNNLLE49C31D560M', 1, '2023-10-17 14:54:57', 'A1', 5, NULL, NULL, NULL),
(11, 'VLNCTN98E25G783F', 16, '2023-05-10 15:25:06', 'B1', 16, NULL, NULL, NULL),
(12, 'GHRVNC97P55E102B', 13, '2023-09-01 10:28:49', 'B1', 1, NULL, NULL, NULL),
(13, 'GZZBBR77T41E148U', 14, '2023-07-25 11:56:45', 'B1', 3, NULL, NULL, NULL),
(14, 'MZZCLR43A71I671J', 1, '2023-06-13 12:44:34', 'A1', 15, NULL, NULL, NULL),
(15, 'LFRRCL68M21G483T', 4, '2023-07-21 14:48:39', 'B1', 1, NULL, NULL, NULL),
(16, 'SMRGTV16C42H621N', 8, '2023-08-25 11:29:00', 'B1', 1, NULL, NULL, NULL),
(17, 'CCNPRN90H51D629R', 5, '2023-05-30 14:38:10', 'B1', 8, NULL, NULL, NULL),
(18, 'BLMNTL51H16L187U', 15, '2023-03-13 10:50:06', 'B1', 5, NULL, NULL, NULL),
(19, 'BNSGTN12S50B787R', 15, '2023-10-12 12:58:46', 'B1', 6, NULL, NULL, NULL),
(20, 'TSCRLL90D52G672K', 11, '2023-06-28 15:14:54', 'A1', 16, NULL, NULL, NULL),
(21, 'CMNMRN46S02E451Q', 14, '2023-07-24 11:48:01', 'B1', 4, NULL, NULL, NULL),
(22, 'LBNLPA64T14L984B', 15, '2023-03-10 14:38:43', 'B1', 6, NULL, NULL, NULL),
(23, 'BRBRNN01L58L643E', 1, '2023-10-10 13:55:58', 'A1', 15, NULL, NULL, NULL),
(24, 'DRNGST69S22H552Y', 7, '2023-03-21 09:10:46', 'A1', 4, NULL, NULL, NULL),
(25, 'MCACGR85A23H076P', 6, '2023-08-02 15:22:16', 'B1', 3, NULL, NULL, NULL),
(26, 'GRGCTN79E31B410W', 3, '2023-08-31 14:03:37', 'B1', 2, NULL, NULL, NULL),
(27, 'FMURCC62T69G691X', 11, '2023-04-10 12:15:04', 'A1', 2, NULL, NULL, NULL),
(28, 'BVIGLL01H20G058K', 7, '2023-10-03 10:27:28', 'A1', 10, NULL, NULL, NULL),
(29, 'VGRYND15R71C910M', 11, '2023-10-10 13:29:14', 'A2', 10, NULL, NULL, NULL),
(30, 'DNIMRN75A65H716Y', 8, '2023-05-25 10:07:26', 'B1', 2, NULL, NULL, NULL),
(31, 'BSCLCA12H09L735T', 4, '2023-09-11 16:08:26', 'B1', 2, NULL, NULL, NULL),
(32, 'GRSFNC68H19F563I', 7, '2023-05-03 15:26:56', 'A1', 12, NULL, NULL, NULL),
(33, 'DGSMDA92D25B925W', 7, '2023-10-24 12:12:29', 'A1', 3, NULL, NULL, NULL),
(34, 'ZNISDR14L49C848S', 13, '2023-05-10 15:00:51', 'B2', 2, NULL, NULL, NULL),
(35, 'CTNLIO52A53H880V', 12, '2023-09-05 17:56:34', 'B1', 10, NULL, NULL, NULL),
(36, 'MRSLSN17M45I507H', 9, '2023-06-13 13:51:50', 'B1', 14, NULL, NULL, NULL),
(37, 'TMNGVR93T65F582L', 7, '2023-04-06 17:44:03', 'A1', 13, NULL, NULL, NULL),
(38, 'STTBBR08A55C486V', 10, '2023-02-20 09:47:40', 'B1', 2, NULL, NULL, NULL),
(39, 'CVLTLI88B13B473Q', 15, '2023-09-22 13:19:11', 'B1', 6, NULL, NULL, NULL),
(40, 'CNTDNI84P60H844F', 6, '2023-04-18 10:55:02', 'B1', 4, NULL, NULL, NULL),
(41, 'BRNYLO59R46H986X', 1, '2023-05-23 09:31:04', 'A1', 15, NULL, NULL, NULL),
(42, 'FRSFBN48R24M339J', 14, '2023-04-11 15:41:21', 'B1', 4, NULL, NULL, NULL),
(43, 'DMSGNR46M24E961T', 11, '2023-07-05 14:29:17', 'A1', 10, NULL, NULL, NULL),
(44, 'LNRNNA12P64A249E', 2, '2023-06-20 11:07:14', 'B1', 11, NULL, NULL, NULL),
(45, 'SCNCTN81C13D703T', 5, '2023-08-11 15:35:23', 'B1', 8, NULL, NULL, NULL),
(46, 'CCCMRZ50L65C353K', 9, '2023-06-05 11:49:03', 'B1', 14, NULL, NULL, NULL),
(47, 'CNCDRA56M42L724P', 6, '2023-04-03 14:02:57', 'B1', 4, NULL, NULL, NULL),
(48, 'CMBMRZ77M45I234Q', 3, '2023-10-26 13:09:57', 'B1', 2, NULL, NULL, NULL),
(49, 'GRCBRC67T47A662B', 3, '2023-06-02 16:20:15', 'B1', 1, NULL, NULL, NULL),
(50, 'CSTDRA94M03A901P', 12, '2023-03-03 17:10:06', 'B1', 10, NULL, NULL, NULL),
(51, 'CPLLCN57A12F486N', 10, '2023-06-13 11:55:03', 'B1', 1, NULL, NULL, NULL),
(52, 'RLLCST83A64L503V', 3, '2023-08-22 13:47:19', 'B1', 1, NULL, NULL, NULL),
(53, 'BLDVTR40T22D630S', 13, '2023-07-10 14:45:33', 'B1', 1, NULL, NULL, NULL),
(54, 'FRCFLV74A45L942P', 13, '2023-05-29 17:39:26', 'B1', 2, NULL, NULL, NULL),
(55, 'MSCPQL46M29E783J', 2, '2023-10-02 12:33:57', 'B1', 7, NULL, NULL, NULL),
(56, 'DSTCLD03D17H769Y', 4, '2023-10-12 10:29:01', 'B1', 2, NULL, NULL, NULL),
(57, 'CMBCLI63C42M163K', 14, '2023-07-03 11:37:36', 'B1', 4, NULL, NULL, NULL),
(58, 'CCRMND59C65L011F', 10, '2023-08-21 10:19:47', 'B1', 2, NULL, NULL, NULL),
(59, 'CRMRGR65B07L450W', 15, '2023-07-10 16:15:54', 'B1', 5, NULL, NULL, NULL),
(60, 'CDZLRT48D58I689N', 1, '2023-10-23 13:23:17', 'A1', 5, NULL, NULL, NULL),
(61, 'MSCLSS69T68H672X', 10, '2023-08-09 09:05:12', 'B1', 2, NULL, NULL, NULL),
(62, 'GSAMLD45R66F117P', 2, '2023-05-10 14:07:37', 'B1', 7, NULL, NULL, NULL),
(63, 'RNBRSM80S02C229Y', 1, '2023-03-17 16:53:52', 'A1', 10, NULL, NULL, NULL),
(64, 'SMRRLL41S58D740F', 3, '2023-04-07 16:42:51', 'B1', 1, NULL, NULL, NULL),
(65, 'RVDSRI42S54D455H', 15, '2023-11-09 17:39:59', 'B1', 6, NULL, NULL, NULL),
(66, 'SGLMSM91T01E730P', 16, '2023-02-28 13:49:25', 'B1', 15, NULL, NULL, NULL),
(67, 'TRTFMN40C11G274T', 15, '2023-07-24 16:27:15', 'B1', 5, NULL, NULL, NULL),
(68, 'CNFNCL88D07F250X', 15, '2023-05-08 12:48:03', 'B1', 5, NULL, NULL, NULL),
(69, 'SCHNDR92B23A806E', 4, '2023-07-28 16:50:32', 'B1', 1, NULL, NULL, NULL),
(70, 'CLTPML84A57L105O', 7, '2023-09-11 12:31:19', 'A1', 4, NULL, NULL, NULL),
(71, 'CSTMLE13R15L396U', 5, '2023-07-12 09:01:11', 'B1', 7, NULL, NULL, NULL),
(72, 'CMPDTL63R43I463L', 6, '2023-10-10 14:52:07', 'B1', 4, NULL, NULL, NULL),
(73, 'SCLVGN78R04H559Z', 6, '2023-09-28 15:42:58', 'B1', 3, NULL, NULL, NULL),
(74, 'MSTSVN58M24D798H', 2, '2023-09-22 16:38:36', 'B1', 8, NULL, NULL, NULL),
(75, 'MGLGMN43E23A023B', 7, '2023-07-28 12:52:36', 'A1', 6, NULL, NULL, NULL),
(76, 'MRSCTN14H17M272O', 9, '2023-06-01 10:12:39', 'B1', 13, NULL, NULL, NULL),
(77, 'BLDMRN91E53B857G', 13, '2023-04-24 17:44:38', 'B1', 1, NULL, NULL, NULL),
(78, 'FLLCST69B46E900A', 4, '2023-11-06 13:26:46', 'B1', 2, NULL, NULL, NULL),
(79, 'CVNCMN47T20L943Z', 8, '2023-03-28 11:49:26', 'B1', 1, NULL, NULL, NULL),
(80, 'BRVLCN42P53G862O', 2, '2023-07-24 14:53:22', 'B1', 12, NULL, NULL, NULL),
(81, 'PRZMRL84P28E055O', 4, '2023-03-20 10:53:36', 'B1', 1, NULL, NULL, NULL),
(82, 'BCCWND03R56C300Q', 1, '2023-09-26 10:33:55', 'A1', 13, NULL, NULL, NULL),
(83, 'DCRFNC61P16G340T', 13, '2023-06-16 12:13:35', 'B1', 1, NULL, NULL, NULL),
(84, 'MNCTLL85S04B187L', 15, '2023-10-06 12:04:31', 'B1', 6, NULL, NULL, NULL),
(85, 'GNZRSO01B64G702J', 8, '2023-07-14 16:21:21', 'B1', 1, NULL, NULL, NULL),
(86, 'CNNCTN76R07I817E', 16, '2023-09-22 10:36:39', 'B1', 16, NULL, NULL, NULL),
(87, 'CNTGNR17S06C250S', 1, '2023-04-21 10:15:27', 'A1', 8, NULL, NULL, NULL),
(88, 'CTRCTN16C05H716V', 16, '2023-03-28 17:45:49', 'B1', 15, NULL, NULL, NULL),
(89, 'RNLLSE43R69L571A', 14, '2023-03-21 14:58:50', 'B1', 3, NULL, NULL, NULL),
(90, 'FRNTZN55L51C076B', 15, '2023-11-15 15:40:12', 'B1', 6, NULL, NULL, NULL),
(91, 'RGSSRN58P69G854Z', 10, '2023-10-27 10:59:01', 'B1', 1, NULL, NULL, NULL),
(92, 'CHNRNN72T22F874G', 4, '2023-10-31 14:53:41', 'B1', 1, NULL, NULL, NULL),
(93, 'DVTPCC44E25F537J', 8, '2023-11-06 09:23:06', 'B1', 2, NULL, NULL, NULL),
(94, 'MRNLNE76C10D230C', 11, '2023-05-03 09:50:58', 'A1', 3, NULL, NULL, NULL),
(95, 'CRTPMR12L51L751A', 14, '2023-05-17 11:44:33', 'B1', 3, NULL, NULL, NULL),
(96, 'DMBRNN64E05D639W', 14, '2023-10-27 11:15:39', 'B2', 4, NULL, NULL, NULL),
(97, 'BRGCRL07A69E245L', 3, '2023-05-24 14:14:16', 'B2', 2, NULL, NULL, NULL),
(98, 'GSTFNZ60S12G191P', 11, '2023-10-31 16:00:38', 'A1', 15, NULL, NULL, NULL),
(99, 'PNDTZN84P11D858V', 14, '2023-02-24 09:56:06', 'B1', 4, NULL, NULL, NULL),
(100, 'GRSGTN79E43H799V', 16, '2023-09-18 17:41:11', 'B1', 15, NULL, NULL, NULL),
(101, 'GMBRRT41E63M070U', 11, '2023-11-10 11:10:11', 'A1', 6, NULL, NULL, NULL),
(102, 'ZZACMB80T63I965I', 6, '2023-05-24 14:16:10', 'B3', 3, NULL, NULL, NULL),
(103, 'CRCRTI04A65F729G', 15, '2023-05-03 13:18:02', 'B1', 6, NULL, NULL, NULL),
(104, 'MGLFBL69L47A328R', 5, '2023-05-02 16:38:32', 'B1', 8, NULL, NULL, NULL),
(105, 'LLVLDI98R52G119W', 3, '2023-06-22 10:00:01', 'B1', 2, NULL, NULL, NULL),
(106, 'MRZLNZ10C71G551U', 9, '2023-08-10 17:00:26', 'B1', 13, NULL, NULL, NULL),
(107, 'CTRRLF50D30I604K', 7, '2023-02-22 17:21:06', 'A1', 12, NULL, NULL, NULL),
(108, 'TBNTNO78E48E192H', 9, '2023-06-07 14:34:13', 'B1', 13, NULL, NULL, NULL),
(109, 'CLLLGO54R68I991S', 1, '2023-04-18 11:17:45', 'A1', 13, NULL, NULL, NULL),
(110, 'LFNLRG69D23H491P', 2, '2023-10-31 12:17:59', 'B1', 12, NULL, NULL, NULL),
(111, 'SDNMME65T63D328R', 6, '2023-08-29 14:33:44', 'B1', 4, NULL, NULL, NULL),
(112, 'MGGFNN82P30I289R', 2, '2023-10-25 11:48:56', 'B1', 12, NULL, NULL, NULL),
(113, 'GRNMRS86L49L497I', 5, '2023-09-21 17:25:38', 'B1', 8, NULL, NULL, NULL),
(114, 'LSARKE47T54H623R', 3, '2023-03-29 13:46:43', 'B1', 2, NULL, NULL, NULL),
(115, 'CSSLSN88B22G237G', 10, '2023-04-05 13:10:38', 'B1', 2, NULL, NULL, NULL),
(116, 'MLNRND56M07B511C', 8, '2023-08-01 10:24:33', 'B1', 1, NULL, NULL, NULL),
(117, 'CMBCVN63H07G105J', 16, '2023-11-03 15:53:14', 'B1', 16, NULL, NULL, NULL),
(118, 'GDLVSC89L20L111A', 3, '2023-03-21 16:56:04', 'B1', 1, NULL, NULL, NULL),
(119, 'BNDBDT56T46F524Y', 8, '2023-08-18 09:58:45', 'B1', 1, NULL, NULL, NULL),
(120, 'BTTRRA05R69F358F', 1, '2023-07-27 13:34:02', 'A1', 6, NULL, NULL, NULL),
(121, 'DR├SML43E14A286A', 14, '2023-03-14 09:01:29', 'B1', 4, NULL, NULL, NULL),
(122, 'LNDMCL07A65A606G', 13, '2023-09-07 14:52:13', 'B1', 2, NULL, NULL, NULL),
(123, 'SCGMRC01E30F355S', 12, '2023-03-24 10:46:15', 'B1', 10, NULL, NULL, NULL),
(124, 'VRNNBL05A09C359E', 16, '2023-03-20 12:20:35', 'B1', 15, NULL, NULL, NULL),
(125, 'CGNDMN16T70I965L', 13, '2023-06-30 15:25:35', 'B1', 1, NULL, NULL, NULL),
(126, 'LDNLRZ54T64E323H', 5, '2023-10-25 12:40:30', 'B2', 7, NULL, NULL, NULL),
(127, 'BLRNZR44H29D218X', 2, '2023-03-23 16:29:09', 'B1', 8, NULL, NULL, NULL),
(128, 'SLVMRG81M30G840B', 2, '2023-08-10 12:21:15', 'B1', 11, NULL, NULL, NULL),
(129, 'GRBLND69M14G771S', 11, '2023-08-30 14:54:52', 'A1', 12, NULL, NULL, NULL),
(130, 'BNCMBR00L53G123B', 2, '2023-04-28 12:24:58', 'B1', 11, NULL, NULL, NULL),
(131, 'PZZSFN98T69E531D', 7, '2023-08-08 09:16:14', 'A1', 10, NULL, NULL, NULL),
(132, 'DVRSRA05S67L947A', 16, '2023-07-25 17:29:06', 'B1', 15, NULL, NULL, NULL),
(133, 'FRCRNL68P69A957X', 8, '2023-06-28 11:37:20', 'B1', 2, NULL, NULL, NULL),
(134, 'TNCMRA04B65M374H', 3, '2023-11-01 15:20:50', 'B1', 2, NULL, NULL, NULL),
(135, 'DCRVTR41C26F249G', 11, '2023-05-12 15:48:58', 'A1', 11, NULL, NULL, NULL),
(136, 'SCLDLF84S02A444O', 9, '2023-11-03 15:56:16', 'B2', 14, NULL, NULL, NULL),
(137, 'CPLCSG06C67B082Q', 10, '2023-03-23 11:28:43', 'B1', 2, NULL, NULL, NULL),
(138, 'CCCGLI73E44G154O', 6, '2023-10-23 10:59:28', 'B1', 4, NULL, NULL, NULL),
(139, 'SSSPRD64H26E968P', 8, '2023-07-26 14:14:52', 'B1', 2, NULL, NULL, NULL),
(140, 'CLLGTV68S14L145E', 2, '2023-07-10 10:58:58', 'B1', 7, NULL, NULL, NULL),
(141, 'PLMNNZ11T48I181O', 2, '2023-05-10 09:18:22', 'B1', 12, NULL, NULL, NULL),
(142, 'MNNCLL72E08L461L', 9, '2023-04-21 17:13:23', 'B1', 14, NULL, NULL, NULL),
(143, 'FMNMLN02H28G489D', 3, '2023-05-11 17:20:14', 'B1', 2, NULL, NULL, NULL),
(144, 'LCCDLC42B60L402L', 11, '2023-11-08 16:44:03', 'A1', 13, NULL, NULL, NULL),
(145, 'MRNRMN85C53A312B', 14, '2023-03-20 17:54:02', 'B1', 4, NULL, NULL, NULL),
(146, 'BNFNLC04T54B932E', 15, '2023-04-06 16:00:10', 'B1', 6, NULL, NULL, NULL),
(147, 'NGRGLI54R41I296O', 16, '2023-04-20 09:31:57', 'B1', 15, NULL, NULL, NULL),
(148, 'CNNDFN09R53D049W', 4, '2023-05-01 14:08:12', 'B1', 2, NULL, NULL, NULL),
(149, 'LDZLNE43A56F454W', 16, '2023-11-10 11:08:59', 'B1', 16, NULL, NULL, NULL),
(150, 'CPLNEE53L06E625P', 5, '2023-06-02 17:08:31', 'B2', 7, NULL, NULL, NULL),
(151, 'PDNGTT52P47B608J', 10, '2023-08-21 10:53:58', 'B2', 1, NULL, NULL, NULL),
(152, 'LBRSFN60E43G986M', 15, '2023-10-30 15:49:42', 'B1', 5, NULL, NULL, NULL),
(153, 'DBERNN67E67F877N', 15, '2023-05-30 17:51:04', 'B1', 5, NULL, NULL, NULL),
(154, 'SSITNI62R44I925W', 5, '2023-08-23 10:46:59', 'B1', 7, NULL, NULL, NULL),
(155, 'CSCGNT89H29F199U', 3, '2023-03-16 13:35:11', 'B1', 2, NULL, NULL, NULL),
(156, 'BLDSML69P67A208J', 7, '2023-03-07 16:36:04', 'A1', 11, NULL, NULL, NULL),
(157, 'PLTGLM68C31L731I', 12, '2023-03-16 13:34:20', 'B2', 9, NULL, NULL, NULL),
(158, 'RGGCGR47M15C389T', 11, '2023-11-01 12:06:54', 'A1', 12, NULL, NULL, NULL),
(159, 'GRLLNZ73S52F608R', 7, '2023-10-27 12:18:49', 'A1', 8, NULL, NULL, NULL),
(160, 'ZVTBDT86D30G776K', 6, '2023-04-06 11:40:50', 'B1', 3, NULL, NULL, NULL),
(161, 'PLDDZN43L54L317W', 16, '2023-03-22 12:45:04', 'B1', 16, NULL, NULL, NULL),
(162, 'MLPNRC80C25E644W', 12, '2023-03-24 10:52:12', 'B2', 9, NULL, NULL, NULL),
(163, 'PLCMRC79A43F968A', 15, '2023-09-07 14:40:28', 'B2', 6, NULL, NULL, NULL),
(164, 'STFPRI80D68E184R', 2, '2023-06-08 16:07:40', 'B1', 11, NULL, NULL, NULL),
(165, 'LSSNLN44E21F393M', 16, '2023-06-07 11:00:05', 'B1', 16, NULL, NULL, NULL),
(166, 'GLRTTI92A01L368M', 16, '2023-06-15 11:55:38', 'B1', 15, NULL, NULL, NULL),
(167, 'CNCRNN83T50H300A', 6, '2023-09-05 13:29:19', 'B1', 4, NULL, NULL, NULL),
(168, 'MSCGDI50L50B866W', 7, '2023-06-12 15:49:08', 'A1', 5, NULL, NULL, NULL),
(169, 'BRNPRI72H16C653T', 8, '2023-10-18 15:22:43', 'B1', 2, NULL, NULL, NULL),
(170, 'LBRSFN70C47G905K', 11, '2023-05-19 13:45:41', 'A1', 4, NULL, NULL, NULL),
(171, 'CMNTNI52R41B104R', 16, '2023-09-28 15:38:35', 'B2', 15, NULL, NULL, NULL),
(172, 'BRNVVN62H03C998R', 7, '2023-08-28 11:01:36', 'A1', 2, NULL, NULL, NULL),
(173, 'FMNRBN98D55B466E', 12, '2023-10-18 13:53:11', 'B1', 10, NULL, NULL, NULL),
(174, 'CNISNT11E57D214O', 13, '2023-08-21 16:32:53', 'B1', 1, NULL, NULL, NULL),
(175, 'BCCNTA82T61F186Z', 12, '2023-04-26 09:39:28', 'B1', 10, NULL, NULL, NULL),
(176, 'CDMDNI87H60H627S', 6, '2023-03-16 15:35:28', 'B1', 3, NULL, NULL, NULL),
(177, 'SNTLRC12B44E515C', 7, '2023-03-30 14:51:05', 'A1', 13, NULL, NULL, NULL),
(178, 'MSSMLA84C66H347S', 8, '2023-09-18 15:36:22', 'B1', 1, NULL, NULL, NULL),
(179, 'RSTLTR74P48B828O', 9, '2023-08-14 12:55:16', 'B1', 14, NULL, NULL, NULL),
(180, 'MTSGTN59L51L131X', 7, '2023-08-18 09:55:52', 'A1', 7, NULL, NULL, NULL),
(181, 'BRBDRA77T04I363Z', 12, '2023-06-13 12:30:38', 'B2', 10, NULL, NULL, NULL),
(182, 'DRLGZZ57D17F686O', 16, '2023-05-30 15:04:23', 'B2', 16, NULL, NULL, NULL),
(183, 'DLLNMO49E45L461H', 9, '2023-10-25 16:41:18', 'B1', 13, NULL, NULL, NULL),
(184, 'RTSGNN07A65F453C', 4, '2023-03-14 15:52:38', 'B1', 1, NULL, NULL, NULL),
(185, 'MNNSNL85C68A159Y', 14, '2023-10-11 15:09:36', 'B1', 3, NULL, NULL, NULL),
(186, 'NFSDGS14H65E760L', 1, '2023-09-05 15:38:57', 'A1', 10, NULL, NULL, NULL),
(187, 'BLDGUO66D16C270J', 5, '2023-10-20 12:59:54', 'B1', 8, NULL, NULL, NULL),
(188, 'DFBYND46D42G392N', 2, '2023-09-22 10:54:41', 'B2', 7, NULL, NULL, NULL),
(189, 'CMSGDE92M17G822H', 14, '2023-08-09 12:02:21', 'B1', 3, NULL, NULL, NULL),
(190, 'DSBGPP66H66H152V', 5, '2023-10-10 11:49:48', 'B1', 8, NULL, NULL, NULL),
(191, 'FRZGST96M47D814G', 2, '2023-07-18 14:27:06', 'B1', 8, NULL, NULL, NULL),
(192, 'BCGPPP02D62C587H', 4, '2023-03-01 11:17:25', 'B1', 2, NULL, NULL, NULL),
(193, 'BLLRNI77H04H931L', 3, '2023-05-09 15:42:09', 'B1', 1, NULL, NULL, NULL),
(194, 'DGSMTT71C02D449F', 5, '2023-05-04 14:43:01', 'B1', 8, NULL, NULL, NULL),
(195, 'GRNGFR85L28C527P', 2, '2023-07-12 14:13:46', 'B2', 12, NULL, NULL, NULL),
(196, 'GSPSLM87M41L165S', 15, '2023-10-10 13:50:42', 'B1', 5, NULL, NULL, NULL),
(197, 'NZVLSS97L56B256S', 14, '2023-04-12 10:34:17', 'B1', 3, NULL, NULL, NULL),
(198, 'SSONZE70T45E910A', 15, '2023-07-11 15:01:07', 'B1', 5, NULL, NULL, NULL),
(199, 'TLLMNO95D46G185Y', 13, '2023-10-16 15:18:42', 'B1', 1, NULL, NULL, NULL),
(200, 'TSTYLO93M67G601S', 14, '2023-09-25 10:12:53', 'B1', 4, NULL, NULL, NULL),
(201, 'DMTMTA56E50F665C', 14, '2023-08-29 17:25:23', 'B1', 4, NULL, NULL, NULL),
(202, 'GLLFRZ15S23A795D', 10, '2023-07-07 12:54:41', 'B1', 1, NULL, NULL, NULL),
(203, 'LTBBRM50C05G875Q', 2, '2023-09-29 13:13:23', 'B1', 7, NULL, NULL, NULL),
(204, 'MGELRD80D11I147H', 6, '2023-07-04 13:20:38', 'B1', 4, NULL, NULL, NULL),
(205, 'SNPDRT53E48B893M', 1, '2023-09-07 09:02:21', 'A1', 15, NULL, NULL, NULL),
(206, 'BNFLRG43P10G187V', 6, '2023-06-14 13:55:21', 'B1', 3, NULL, NULL, NULL),
(207, 'BTTRMN70H20G448A', 9, '2023-03-16 10:31:21', 'B1', 13, NULL, NULL, NULL),
(208, 'CSTRNN06B48E115F', 13, '2023-04-10 15:21:45', 'B1', 2, NULL, NULL, NULL),
(209, 'ZCCLLD57R10H095E', 13, '2023-07-04 12:29:16', 'B2', 1, NULL, NULL, NULL),
(210, 'TFNZOE05T49B511J', 7, '2023-08-24 15:11:46', 'A1', 6, NULL, NULL, NULL),
(211, 'ZMMRNT73A57F109W', 11, '2023-09-18 15:20:09', 'A1', 5, NULL, NULL, NULL),
(212, 'GNDCLL49H21C452G', 7, '2023-07-12 16:16:02', 'A1', 13, NULL, NULL, NULL),
(213, 'RSNCTN13C19B527I', 14, '2023-09-19 09:18:21', 'B1', 3, NULL, NULL, NULL),
(214, 'VNCDRO11R63E767P', 4, '2023-05-09 17:26:34', 'B1', 1, NULL, NULL, NULL),
(215, 'LDNLLL86A30H022U', 3, '2023-05-30 10:11:22', 'B1', 1, NULL, NULL, NULL),
(216, 'GZZLSE58T50B430P', 1, '2023-10-13 09:15:37', 'A1', 10, NULL, NULL, NULL),
(217, 'LMBFTM49T55I294Y', 16, '2023-08-17 12:37:33', 'B1', 15, NULL, NULL, NULL),
(218, 'SPZCMN74D10D760K', 10, '2023-11-10 14:17:55', 'B1', 1, NULL, NULL, NULL),
(219, 'PRCNDR45E07F074U', 7, '2023-03-21 14:13:26', 'A1', 1, NULL, NULL, NULL),
(220, 'BNMMDL07S66A848O', 2, '2023-10-03 13:49:39', 'B1', 11, NULL, NULL, NULL),
(221, 'RMNRLB87T53B566T', 16, '2023-04-06 16:41:49', 'B2', 15, NULL, NULL, NULL),
(222, 'GS├YNN04M50H315R', 7, '2023-03-03 09:56:42', 'A1', 11, NULL, NULL, NULL),
(223, 'GGLGLI52D27L859K', 2, '2023-08-10 15:39:20', 'B1', 11, NULL, NULL, NULL),
(224, 'LLTMSC54H66G613J', 14, '2023-05-30 11:25:09', 'B1', 3, NULL, NULL, NULL),
(225, 'BRBGLD71C06L316Y', 14, '2023-08-24 09:53:09', 'B1', 3, NULL, NULL, NULL),
(226, 'RTLDLR00H53I301W', 4, '2023-04-10 09:59:37', 'B1', 1, NULL, NULL, NULL),
(227, 'VGRNCL88T01A081Z', 4, '2023-06-14 17:22:29', 'B1', 2, NULL, NULL, NULL),
(228, 'CPRLNE85C63E929X', 13, '2023-10-04 13:23:34', 'B1', 2, NULL, NULL, NULL),
(229, 'RSNVRN06M59H726Y', 5, '2023-09-27 16:38:14', 'B1', 7, NULL, NULL, NULL),
(230, 'CRDRSL57S62L281G', 2, '2023-07-31 15:21:21', 'B1', 12, NULL, NULL, NULL),
(231, 'RSALRZ84H67C614F', 13, '2023-04-14 13:24:36', 'B1', 1, NULL, NULL, NULL),
(232, 'GZZLLL46C15M427H', 12, '2023-05-19 17:06:48', 'B1', 10, NULL, NULL, NULL),
(233, 'BRLNLN97M13C660Z', 14, '2023-05-31 14:01:25', 'B1', 3, NULL, NULL, NULL),
(234, 'VLNMSC51T71A193O', 8, '2023-07-24 13:20:57', 'B1', 1, NULL, NULL, NULL),
(235, 'FRRFNZ63D04L202N', 5, '2023-04-11 17:11:16', 'B1', 8, NULL, NULL, NULL),
(236, 'TSCCLD82E30L213A', 2, '2023-04-13 17:29:48', 'B1', 11, NULL, NULL, NULL),
(237, 'CSCGTR55A28D714F', 2, '2023-03-03 12:08:30', 'B1', 8, NULL, NULL, NULL),
(238, 'DSTTMR81T64E288W', 11, '2023-08-31 13:25:20', 'A1', 13, NULL, NULL, NULL),
(239, 'BGNFRZ87T55E546C', 15, '2023-08-18 12:11:21', 'B1', 6, NULL, NULL, NULL),
(240, 'CRGRSR09P51I969B', 5, '2023-09-07 14:17:22', 'B3', 8, NULL, NULL, NULL),
(241, 'SPIMTN40D10D088E', 15, '2023-07-28 17:43:54', 'B2', 6, NULL, NULL, NULL),
(242, 'NNNVNI74C51A716K', 16, '2023-09-01 12:08:32', 'B1', 16, NULL, NULL, NULL),
(243, 'CTRDRD73R05L823W', 15, '2023-08-11 17:36:22', 'B1', 6, NULL, NULL, NULL),
(244, 'SCVPMP80B26H110N', 13, '2023-10-27 16:07:31', 'B1', 1, NULL, NULL, NULL),
(245, 'DNGVNZ89C41C719X', 13, '2023-08-02 12:56:53', 'B1', 2, NULL, NULL, NULL),
(246, 'CVAMRA67M58C404B', 14, '2023-07-26 16:33:20', 'B1', 3, NULL, NULL, NULL),
(247, 'CMPPPP16E59G076T', 10, '2023-11-06 12:29:51', 'B2', 1, NULL, NULL, NULL),
(248, 'BSTGGI02C03E661X', 10, '2023-05-18 14:12:43', 'B1', 2, NULL, NULL, NULL),
(249, 'CRBCTL59A59B927J', 1, '2023-09-27 12:12:55', 'A1', 3, NULL, NULL, NULL),
(250, 'FRNPSQ89S49F740D', 8, '2023-05-16 11:56:16', 'B1', 1, NULL, NULL, NULL),
(251, 'DLSSTR01A67D293Z', 13, '2023-07-11 13:44:14', 'B1', 1, NULL, NULL, NULL),
(252, 'GLDGTR60R46G568A', 2, '2023-04-18 16:05:25', 'B1', 12, NULL, NULL, NULL),
(253, 'SMRRTD77A31F731P', 2, '2023-10-30 11:39:08', 'B1', 7, NULL, NULL, NULL),
(254, 'DLTMMM04S53L788C', 9, '2023-08-04 13:32:31', 'B1', 14, NULL, NULL, NULL),
(255, 'DPLRND68R07G808C', 1, '2023-08-01 11:09:47', 'A1', 10, NULL, NULL, NULL),
(256, 'STNCSN59C68B802Z', 14, '2023-03-09 13:11:05', 'B1', 3, NULL, NULL, NULL),
(257, 'BRSMLT72D26C056A', 10, '2023-03-15 16:30:16', 'B1', 2, NULL, NULL, NULL),
(258, 'LNLGGR87B12F223G', 16, '2023-08-18 15:48:11', 'B1', 16, NULL, NULL, NULL),
(259, 'CTZCRL47R55E685U', 13, '2023-08-31 09:36:05', 'B1', 2, NULL, NULL, NULL),
(260, 'VNTGAI03T68D481L', 5, '2023-08-09 15:01:22', 'B1', 7, NULL, NULL, NULL),
(261, 'CSCNLT69C65A786W', 15, '2023-09-04 15:04:58', 'B1', 5, NULL, NULL, NULL),
(262, 'PLGNTN89A12L879G', 13, '2023-08-02 14:50:12', 'B2', 2, NULL, NULL, NULL),
(263, 'CRLSCR87R11H475H', 6, '2023-10-24 16:08:58', 'B1', 4, NULL, NULL, NULL),
(264, 'DGTVSS81S50C937D', 5, '2023-06-28 12:33:10', 'B2', 7, NULL, NULL, NULL),
(265, 'VLLDMA41A19F533D', 6, '2023-10-03 10:18:26', 'B1', 3, NULL, NULL, NULL),
(266, 'DPMLNI81E59H365L', 8, '2023-11-09 14:10:12', 'B1', 2, NULL, NULL, NULL),
(267, 'SCHSLN42S57H240Y', 13, '2023-09-21 10:03:56', 'B1', 2, NULL, NULL, NULL),
(268, 'SCRBRT16T54G774T', 16, '2023-11-02 12:43:15', 'B1', 15, NULL, NULL, NULL),
(269, 'CLRDNA94D04A128F', 1, '2023-10-25 14:53:31', 'A1', 6, NULL, NULL, NULL),
(270, 'GLFLSN08B10G268S', 1, '2023-06-09 11:40:05', 'A1', 6, NULL, NULL, NULL),
(271, 'FGRMRT51S19I248U', 6, '2023-08-01 14:03:23', 'B1', 3, NULL, NULL, NULL),
(272, 'BRLMLE74A51E543S', 11, '2023-03-29 11:17:44', 'A1', 7, NULL, NULL, NULL),
(273, 'DNTZEI69C31C621X', 12, '2023-06-28 15:20:02', 'B1', 10, NULL, NULL, NULL),
(274, 'VRTDLE50D61I171P', 6, '2023-08-23 13:46:44', 'B1', 3, NULL, NULL, NULL),
(275, 'BSCDLC98P43E873I', 2, '2023-10-27 12:46:47', 'B1', 7, NULL, NULL, NULL),
(276, 'BNNBND54S09G865V', 3, '2023-02-27 09:18:11', 'B1', 2, NULL, NULL, NULL),
(277, 'TRNNTL11P20F707F', 4, '2023-09-18 13:24:17', 'B1', 2, NULL, NULL, NULL),
(278, 'CRNLEO12E06E094V', 3, '2023-07-19 16:30:37', 'B2', 2, NULL, NULL, NULL),
(279, 'DRAFMN46E42D752U', 1, '2023-07-06 16:50:13', 'A1', 8, NULL, NULL, NULL),
(280, 'ZMTNNZ40C07G372H', 5, '2023-03-13 11:30:42', 'B2', 7, NULL, NULL, NULL),
(281, 'BRGFRZ07T01E596D', 14, '2023-04-18 09:08:22', 'B1', 4, NULL, NULL, NULL),
(282, 'CHRGIA96E15C830Q', 5, '2023-09-07 09:49:46', 'B1', 8, NULL, NULL, NULL),
(283, 'NNMCLD04D11B740S', 8, '2023-09-28 13:30:09', 'B1', 2, NULL, NULL, NULL),
(284, 'CRBRNN89T56H818Y', 6, '2023-09-01 09:37:09', 'B2', 4, NULL, NULL, NULL),
(285, 'MSCGDN46R64E428J', 13, '2023-03-15 12:19:00', 'B1', 2, NULL, NULL, NULL),
(286, 'PRSCLR77C58D874Q', 5, '2023-07-18 12:04:53', 'B1', 8, NULL, NULL, NULL),
(287, 'GRMMLE99A68L368N', 2, '2023-06-20 13:33:29', 'B1', 8, NULL, NULL, NULL),
(288, 'PCCCRL13E56E029N', 3, '2023-04-26 12:41:17', 'B1', 2, NULL, NULL, NULL),
(289, 'CTAGTR53D26F880F', 7, '2023-06-06 12:34:10', 'A1', 3, NULL, NULL, NULL),
(290, 'BLDRND79A11B346J', 4, '2023-06-02 10:52:15', 'B1', 1, NULL, NULL, NULL),
(291, 'MLRDRN02H51A837V', 4, '2023-07-03 13:58:24', 'B1', 2, NULL, NULL, NULL),
(292, 'DMCPRZ73T09E490U', 11, '2023-11-03 09:29:35', 'A1', 7, NULL, NULL, NULL),
(293, 'RLLPLP15S64A028H', 7, '2023-04-10 09:33:23', 'A1', 4, NULL, NULL, NULL),
(294, 'MSRSNT67E44A382J', 5, '2023-03-07 11:47:53', 'B1', 8, NULL, NULL, NULL),
(295, 'CLPLCU57S12A495U', 11, '2023-06-16 11:10:30', 'A1', 9, NULL, NULL, NULL),
(296, 'MRRMGH95E47F653J', 5, '2023-05-26 13:57:03', 'B2', 8, NULL, NULL, NULL),
(297, 'ZLLPNG14A64D720S', 5, '2023-03-17 15:45:37', 'B1', 7, NULL, NULL, NULL),
(298, 'CCRGRG09B49H627H', 14, '2023-04-04 12:20:46', 'B1', 4, NULL, NULL, NULL),
(299, 'RMNLIO71S44A952C', 10, '2023-06-20 15:35:16', 'B1', 1, NULL, NULL, NULL),
(300, 'GRECSS57T04F739G', 13, '2023-05-04 15:30:48', 'B2', 2, NULL, NULL, NULL),
(301, 'LNSTNA02H56B030K', 14, '2023-08-22 16:52:38', 'B1', 3, NULL, NULL, NULL),
(302, 'FNNLBN58R22L590K', 14, '2023-04-05 13:41:08', 'B2', 3, NULL, NULL, NULL),
(303, 'LFNDMA14H26H466V', 7, '2023-08-02 17:24:57', 'A1', 12, NULL, NULL, NULL),
(304, 'CMNRSL81M50H055R', 13, '2023-03-23 16:06:14', 'B2', 2, NULL, NULL, NULL),
(305, 'STTPML56B60L324O', 14, '2023-06-28 16:16:44', 'B2', 3, NULL, NULL, NULL),
(306, 'MRTRCL11M20G529Q', 2, '2023-03-30 14:46:07', 'B1', 11, NULL, NULL, NULL),
(307, 'LTMMRN76M03A472N', 15, '2023-09-11 17:58:17', 'B1', 5, NULL, NULL, NULL),
(308, 'LBRNTS90T02G866O', 10, '2023-08-09 15:12:06', 'B2', 2, NULL, NULL, NULL),
(309, 'CRRGNS68E43I410G', 2, '2023-09-12 11:30:42', 'B1', 12, NULL, NULL, NULL),
(310, 'BSSGIO99L63H534S', 3, '2023-11-07 12:32:16', 'B1', 1, NULL, NULL, NULL),
(311, 'CHTSDR54M02H861K', 4, '2023-02-23 15:50:50', 'B1', 2, NULL, NULL, NULL),
(312, 'DMTMCL65R56C343Z', 5, '2023-05-03 11:16:49', 'B1', 7, NULL, NULL, NULL),
(313, 'SNTLRC12B44E515C', 7, '2023-03-30 14:51:05', 'A2', 9, NULL, NULL, NULL),
(314, 'MSSMLA84C66H347S', 8, '2023-09-18 15:36:22', 'B2', 2, NULL, NULL, NULL),
(315, 'MTSGTN59L51L131X', 7, '2023-08-18 09:55:52', 'A2', 14, NULL, NULL, NULL),
(316, 'DRLGZZ57D17F686O', 16, '2023-05-30 15:04:23', 'B3', 15, NULL, NULL, NULL),
(317, 'NFSDGS14H65E760L', 1, '2023-09-05 15:38:57', 'A2', 16, NULL, NULL, NULL),
(318, 'BLDGUO66D16C270J', 5, '2023-10-20 12:59:54', 'B2', 7, NULL, NULL, NULL),
(319, 'DFBYND46D42G392N', 2, '2023-09-22 10:54:41', 'B3', 11, NULL, NULL, NULL),
(320, 'FRZGST96M47D814G', 2, '2023-07-18 14:27:06', 'B2', 11, NULL, NULL, NULL),
(321, 'TLLMNO95D46G185Y', 13, '2023-10-16 15:18:42', 'B2', 2, NULL, NULL, NULL),
(322, 'DMTMTA56E50F665C', 14, '2023-08-29 17:25:23', 'B2', 3, NULL, NULL, NULL),
(323, 'LTBBRM50C05G875Q', 2, '2023-09-29 13:13:23', 'B2', 8, NULL, NULL, NULL),
(324, 'MGELRD80D11I147H', 6, '2023-07-04 13:20:38', 'B3', 3, NULL, NULL, NULL),
(325, 'SNPDRT53E48B893M', 1, '2023-09-07 09:02:21', 'A2', 2, NULL, NULL, NULL),
(326, 'CSTRNN06B48E115F', 13, '2023-04-10 15:21:45', 'B2', 1, NULL, NULL, NULL),
(327, 'TFNZOE05T49B511J', 7, '2023-08-24 15:11:46', 'A2', 9, NULL, NULL, NULL),
(328, 'ZMMRNT73A57F109W', 11, '2023-09-18 15:20:09', 'A2', 12, NULL, NULL, NULL),
(329, 'GNDCLL49H21C452G', 7, '2023-07-12 16:16:02', 'A2', 7, NULL, NULL, NULL),
(330, 'RSNCTN13C19B527I', 14, '2023-09-19 09:18:21', 'B2', 4, NULL, NULL, NULL),
(331, 'GZZLSE58T50B430P', 1, '2023-10-13 09:15:37', 'A2', 6, NULL, NULL, NULL),
(332, 'PRCNDR45E07F074U', 7, '2023-03-21 14:13:26', 'A2', 13, NULL, NULL, NULL),
(333, 'BNMMDL07S66A848O', 2, '2023-10-03 13:49:39', 'B2', 8, NULL, NULL, NULL),
(334, 'GS├YNN04M50H315R', 7, '2023-03-03 09:56:42', 'A2', 1, NULL, NULL, NULL),
(335, 'GGLGLI52D27L859K', 2, '2023-08-10 15:39:20', 'B2', 8, NULL, NULL, NULL),
(336, 'LLTMSC54H66G613J', 14, '2023-05-30 11:25:09', 'B2', 4, NULL, NULL, NULL),
(337, 'RTLDLR00H53I301W', 4, '2023-04-10 09:59:37', 'B2', 2, NULL, NULL, NULL),
(338, 'CRDRSL57S62L281G', 2, '2023-07-31 15:21:21', 'B2', 7, NULL, NULL, NULL),
(339, 'GZZLLL46C15M427H', 12, '2023-05-19 17:06:48', 'B2', 9, NULL, NULL, NULL),
(340, 'VLNMSC51T71A193O', 8, '2023-07-24 13:20:57', 'B2', 2, NULL, NULL, NULL),
(341, 'TSCCLD82E30L213A', 2, '2023-04-13 17:29:48', 'B2', 8, NULL, NULL, NULL),
(342, 'CSCGTR55A28D714F', 2, '2023-03-03 12:08:30', 'B2', 7, NULL, NULL, NULL),
(343, 'DSTTMR81T64E288W', 11, '2023-08-31 13:25:20', 'A2', 11, NULL, NULL, NULL),
(344, 'CRBCTL59A59B927J', 1, '2023-09-27 12:12:55', 'A2', 2, NULL, NULL, NULL),
(345, 'GLDGTR60R46G568A', 2, '2023-04-18 16:05:25', 'B2', 8, NULL, NULL, NULL),
(346, 'SMRRTD77A31F731P', 2, '2023-10-30 11:39:08', 'B2', 12, NULL, NULL, NULL),
(347, 'DPLRND68R07G808C', 1, '2023-08-01 11:09:47', 'A2', 4, NULL, NULL, NULL),
(348, 'TRNRSN02A64L682V', 9, '2023-10-16 09:49:48', 'B1', 14, NULL, NULL, NULL),
(349, 'ZNRTLI95E27F866S', 2, '2023-03-08 11:32:09', 'B1', 7, NULL, NULL, NULL),
(350, 'GRZCSN73R47M259S', 14, '2023-11-09 14:18:40', 'B2', 3, NULL, NULL, NULL),
(351, 'CPLTTV95P20G830J', 1, '2023-03-17 10:08:18', 'A1', 6, NULL, NULL, NULL),
(352, 'BSSLRZ55H48C988A', 1, '2023-03-15 10:50:46', 'A1', 7, NULL, NULL, NULL),
(353, 'SCCDVG80A44L162P', 7, '2023-02-23 12:37:26', 'A1', 3, NULL, NULL, NULL),
(354, 'LSSLEO82A15A568M', 5, '2023-10-09 14:12:37', 'B1', 7, NULL, NULL, NULL),
(355, 'CNILRG80B18B364U', 9, '2023-06-23 14:34:02', 'B1', 14, NULL, NULL, NULL),
(356, 'SDNBRN01E13A370N', 6, '2023-09-14 13:05:23', 'B1', 3, NULL, NULL, NULL),
(357, 'SRAVGL67P65H810T', 7, '2023-03-01 11:42:05', 'A1', 10, NULL, NULL, NULL),
(358, 'GRVLVC82B01B328L', 10, '2023-08-10 11:34:31', 'B2', 2, NULL, NULL, NULL),
(359, 'NDRMCR98M10M358B', 15, '2023-08-21 12:19:32', 'B1', 5, NULL, NULL, NULL),
(360, 'CLPNTS58P61H262N', 2, '2023-02-20 15:11:58', 'B1', 7, NULL, NULL, NULL),
(361, 'LRNPLM93S56G954N', 2, '2023-06-14 09:45:36', 'B1', 12, NULL, NULL, NULL),
(362, 'SLNDTL14B43A565O', 7, '2023-05-01 09:34:12', 'A1', 7, NULL, NULL, NULL),
(363, 'MLLLRT04L23G537Y', 5, '2023-09-25 15:57:29', 'B1', 7, NULL, NULL, NULL),
(364, 'BRTSST69H22E968W', 5, '2023-08-15 09:45:50', 'B1', 8, NULL, NULL, NULL),
(365, 'SRAVGL67P65H810T', 7, '2023-03-01 11:42:05', 'A2', 3, NULL, NULL, NULL),
(366, 'CLPNTS58P61H262N', 2, '2023-02-20 15:11:58', 'B2', 12, NULL, NULL, NULL),
(367, 'LRNPLM93S56G954N', 2, '2023-06-14 09:45:36', 'B2', 7, NULL, NULL, NULL),
(368, 'SLNDTL14B43A565O', 7, '2023-05-01 09:34:12', 'A2', 9, NULL, NULL, NULL),
(369, 'NTLRND17B26G011L', 9, '2023-11-16 15:06:55', 'B1', 13, NULL, NULL, NULL),
(370, 'PNRDND75H67F960P', 16, '2023-10-06 17:46:55', 'B1', 16, NULL, NULL, NULL),
(371, 'CMBPCR45P13G553G', 1, '2023-07-27 10:45:40', 'A1', 6, NULL, NULL, NULL),
(372, 'GNDRLN97P62G448T', 10, '2023-10-23 13:38:37', 'B1', 1, NULL, NULL, NULL),
(373, 'SCHMNO73R49G656P', 12, '2023-06-27 10:15:46', 'B1', 10, NULL, NULL, NULL),
(374, 'NSLRMN78D30B531N', 4, '2023-07-24 17:15:12', 'B2', 2, NULL, NULL, NULL),
(375, 'LNCLND54L69M204A', 7, '2023-03-16 13:43:20', 'A1', 15, NULL, NULL, NULL),
(376, 'STRRNL84D21I970A', 10, '2023-07-20 10:53:11', 'B1', 2, NULL, NULL, NULL),
(377, 'SGGRMN13T10I564G', 15, '2023-03-01 10:51:46', 'B2', 6, NULL, NULL, NULL),
(378, 'MCCTVN63C20M106Q', 2, '2023-09-12 13:20:04', 'B1', 12, NULL, NULL, NULL),
(379, 'GNZGMN81A50B966C', 6, '2023-04-10 16:48:39', 'B1', 4, NULL, NULL, NULL),
(380, 'TRVVTR48L61D832U', 16, '2023-04-17 15:04:57', 'B1', 15, NULL, NULL, NULL),
(381, 'BRBPCC10M08F152N', 2, '2023-05-11 10:36:23', 'B1', 11, NULL, NULL, NULL),
(382, 'GRLMCL99M58M188T', 14, '2023-04-24 16:32:21', 'B1', 4, NULL, NULL, NULL),
(383, 'CLNMRG91P49G400Y', 5, '2023-05-29 09:23:51', 'B1', 7, NULL, NULL, NULL),
(384, 'GRMRCR43B18I275Y', 13, '2023-07-11 15:35:09', 'B2', 1, NULL, NULL, NULL),
(385, 'FNCMDL56E68B541C', 16, '2023-05-08 17:52:45', 'B1', 15, NULL, NULL, NULL),
(386, 'BMBMRN44T29A297W', 4, '2023-09-11 15:16:46', 'B2', 1, NULL, NULL, NULL),
(387, 'BRFCML03M18F336D', 12, '2023-08-31 16:26:10', 'B1', 9, NULL, NULL, NULL),
(388, 'GSSLNS15R24D818E', 8, '2023-11-09 11:10:41', 'B1', 2, NULL, NULL, NULL),
(389, 'BRNVTR05E12B328J', 11, '2023-03-27 15:50:46', 'A1', 9, NULL, NULL, NULL),
(390, 'BRLZRA52A51C471P', 12, '2023-07-24 14:29:57', 'B2', 9, NULL, NULL, NULL),
(391, 'BLDFRC15S10C166X', 8, '2023-06-12 10:52:48', 'B1', 1, NULL, NULL, NULL),
(392, 'BLTTLL63T13E695K', 11, '2023-04-17 14:08:32', 'A1', 4, NULL, NULL, NULL),
(393, 'CHRSVS44M26F363J', 14, '2023-02-17 16:43:24', 'B1', 4, NULL, NULL, NULL),
(394, 'CLLLVO14E53E900C', 3, '2023-05-15 15:44:49', 'B1', 2, NULL, NULL, NULL),
(395, 'BGNVLM88A54H348M', 12, '2023-11-17 14:01:20', 'B1', 9, NULL, NULL, NULL),
(396, 'TSTLCU13A29G801E', 5, '2023-09-29 09:49:13', 'B1', 8, NULL, NULL, NULL),
(397, 'STRTMS49R56F044D', 7, '2023-09-15 17:59:43', 'A1', 16, NULL, NULL, NULL),
(398, 'SGGRNI54C48I354W', 12, '2023-09-20 15:19:00', 'B1', 10, NULL, NULL, NULL),
(399, 'MNRLDA77P63I388J', 16, '2023-04-27 09:56:59', 'B1', 15, NULL, NULL, NULL),
(400, 'STRLRT68M30C429A', 13, '2023-06-02 13:13:51', 'B1', 1, NULL, NULL, NULL),
(401, 'SNCLRG65T04B739K', 11, '2023-05-16 10:41:15', 'A1', 15, NULL, NULL, NULL),
(402, 'TDRSMN47A07A960G', 3, '2023-06-16 15:26:33', 'B1', 1, NULL, NULL, NULL),
(403, 'BLLRLA41B19G618F', 5, '2023-05-15 17:26:43', 'B1', 7, NULL, NULL, NULL),
(404, 'DFLCST42E45C189N', 16, '2023-06-21 10:32:27', 'B1', 16, NULL, NULL, NULL),
(405, 'CMNRLN87D69C768T', 10, '2023-10-26 14:32:29', 'B1', 2, NULL, NULL, NULL),
(406, 'NTNFDR08P30C237B', 12, '2023-07-20 09:52:10', 'B1', 9, NULL, NULL, NULL),
(407, 'BNNDLF85P12E338H', 4, '2023-10-19 12:49:58', 'B1', 2, NULL, NULL, NULL),
(408, 'SGGGTN15P08D899P', 2, '2023-04-06 10:37:36', 'B1', 11, NULL, NULL, NULL),
(409, 'CMBPCR45P13G553G', 1, '2023-07-27 10:45:40', 'A2', 3, NULL, NULL, NULL),
(410, 'GNDRLN97P62G448T', 10, '2023-10-23 13:38:37', 'B2', 2, NULL, NULL, NULL),
(411, 'NSLRMN78D30B531N', 4, '2023-07-24 17:15:12', 'B3', 1, NULL, NULL, NULL),
(412, 'LNCLND54L69M204A', 7, '2023-03-16 13:43:20', 'A2', 3, NULL, NULL, NULL),
(413, 'SGGRMN13T10I564G', 15, '2023-03-01 10:51:46', 'B3', 5, NULL, NULL, NULL),
(414, 'MCCTVN63C20M106Q', 2, '2023-09-12 13:20:04', 'B2', 11, NULL, NULL, NULL),
(415, 'BRBPCC10M08F152N', 2, '2023-05-11 10:36:23', 'B2', 8, NULL, NULL, NULL),
(416, 'BRNVTR05E12B328J', 11, '2023-03-27 15:50:46', 'A2', 15, NULL, NULL, NULL),
(417, 'BLDFRC15S10C166X', 8, '2023-06-12 10:52:48', 'B2', 2, NULL, NULL, NULL),
(418, 'BLTTLL63T13E695K', 11, '2023-04-17 14:08:32', 'A2', 5, NULL, NULL, NULL),
(419, 'CLLLVO14E53E900C', 3, '2023-05-15 15:44:49', 'B2', 1, NULL, NULL, NULL),
(420, 'BGNVLM88A54H348M', 12, '2023-11-17 14:01:20', 'B2', 10, NULL, NULL, NULL),
(421, 'TSTLCU13A29G801E', 5, '2023-09-29 09:49:13', 'B2', 7, NULL, NULL, NULL),
(422, 'STRTMS49R56F044D', 7, '2023-09-15 17:59:43', 'A2', 10, NULL, NULL, NULL),
(423, 'SNCLRG65T04B739K', 11, '2023-05-16 10:41:15', 'A2', 14, NULL, NULL, NULL),
(424, 'SGGGTN15P08D899P', 2, '2023-04-06 10:37:36', 'B2', 8, NULL, NULL, NULL),
(425, 'CRLSCR87R11H475H', 6, '2023-10-24 16:08:58', 'B2', 3, NULL, NULL, NULL),
(426, 'VLLDMA41A19F533D', 6, '2023-10-03 10:18:26', 'B2', 4, NULL, NULL, NULL),
(427, 'CLRDNA94D04A128F', 1, '2023-10-25 14:53:31', 'A2', 5, NULL, NULL, NULL),
(428, 'GLFLSN08B10G268S', 1, '2023-06-09 11:40:05', 'A2', 10, NULL, NULL, NULL),
(429, 'FGRMRT51S19I248U', 6, '2023-08-01 14:03:23', 'B2', 4, NULL, NULL, NULL),
(430, 'TRNNTL11P20F707F', 4, '2023-09-18 13:24:17', 'B2', 1, NULL, NULL, NULL),
(431, 'DRAFMN46E42D752U', 1, '2023-07-06 16:50:13', 'A2', 9, NULL, NULL, NULL),
(432, 'BRGFRZ07T01E596D', 14, '2023-04-18 09:08:22', 'B2', 3, NULL, NULL, NULL),
(433, 'GRMMLE99A68L368N', 2, '2023-06-20 13:33:29', 'B2', 11, NULL, NULL, NULL),
(434, 'CTAGTR53D26F880F', 7, '2023-06-06 12:34:10', 'A2', 13, NULL, NULL, NULL),
(435, 'MLRDRN02H51A837V', 4, '2023-07-03 13:58:24', 'B2', 1, NULL, NULL, NULL),
(436, 'DMCPRZ73T09E490U', 11, '2023-11-03 09:29:35', 'A2', 6, NULL, NULL, NULL),
(437, 'RLLPLP15S64A028H', 7, '2023-04-10 09:33:23', 'A2', 5, NULL, NULL, NULL),
(438, 'CLPLCU57S12A495U', 11, '2023-06-16 11:10:30', 'A2', 10, NULL, NULL, NULL),
(439, 'MRRMGH95E47F653J', 5, '2023-05-26 13:57:03', 'B3', 7, NULL, NULL, NULL),
(440, 'ZLLPNG14A64D720S', 5, '2023-03-17 15:45:37', 'B2', 8, NULL, NULL, NULL),
(441, 'CCRGRG09B49H627H', 14, '2023-04-04 12:20:46', 'B2', 3, NULL, NULL, NULL),
(442, 'LNSTNA02H56B030K', 14, '2023-08-22 16:52:38', 'B2', 4, NULL, NULL, NULL),
(443, 'LFNDMA14H26H466V', 7, '2023-08-02 17:24:57', 'A2', 2, NULL, NULL, NULL),
(444, 'MRTRCL11M20G529Q', 2, '2023-03-30 14:46:07', 'B2', 8, NULL, NULL, NULL),
(445, 'CRRGNS68E43I410G', 2, '2023-09-12 11:30:42', 'B2', 8, NULL, NULL, NULL),
(446, 'FRRVRN62R44I170E', 10, '2023-08-30 14:52:12', 'B1', 2, NULL, NULL, NULL),
(447, 'CHPGLD96C43D232J', 16, '2023-02-23 14:27:48', 'B1', 15, NULL, NULL, NULL),
(448, 'MTIRST04A03D156K', 10, '2023-10-09 15:37:38', 'B1', 1, NULL, NULL, NULL),
(449, 'BRNSLL01D56C694E', 10, '2023-03-13 16:34:24', 'B1', 1, NULL, NULL, NULL),
(450, 'FLRSTN62H59L655Z', 16, '2023-06-30 09:36:01', 'B1', 16, NULL, NULL, NULL),
(451, 'BLSMDL83S42F029V', 14, '2023-06-29 14:00:31', 'B1', 3, NULL, NULL, NULL),
(452, 'CTNLRI42R21C120T', 4, '2023-08-14 09:04:50', 'B1', 2, NULL, NULL, NULL),
(453, 'GCBGCM64P05L245E', 8, '2023-09-04 15:06:47', 'B2', 1, NULL, NULL, NULL),
(454, 'GRNVSC63P11I499A', 9, '2023-05-15 10:15:28', 'B1', 14, NULL, NULL, NULL),
(455, 'SLRBGI48M23I288J', 12, '2023-03-13 16:21:04', 'B2', 9, NULL, NULL, NULL),
(456, 'RRGGTR10M56G604P', 14, '2023-03-08 17:54:49', 'B1', 3, NULL, NULL, NULL),
(457, 'CSLLCU97A16A275D', 2, '2023-11-09 12:45:26', 'B1', 11, NULL, NULL, NULL),
(458, 'MCHGIA13E15L176R', 9, '2023-04-24 17:27:58', 'B2', 14, NULL, NULL, NULL),
(459, 'BTTSVT58H03F776N', 12, '2023-03-14 15:58:15', 'B2', 10, NULL, NULL, NULL),
(460, 'DRAFMN46E42D752U', 1, '2023-07-06 16:50:13', 'A3', 15, NULL, NULL, NULL),
(461, 'GRMMLE99A68L368N', 2, '2023-06-20 13:33:29', 'B3', 12, NULL, NULL, NULL),
(462, 'CTAGTR53D26F880F', 7, '2023-06-06 12:34:10', 'A3', 15, NULL, NULL, NULL),
(463, 'DMCPRZ73T09E490U', 11, '2023-11-03 09:29:35', 'A3', 1, NULL, NULL, NULL),
(464, 'RLLPLP15S64A028H', 7, '2023-04-10 09:33:23', 'A3', 12, NULL, NULL, NULL),
(465, 'CLPLCU57S12A495U', 11, '2023-06-16 11:10:30', 'A3', 8, NULL, NULL, NULL),
(466, 'LFNDMA14H26H466V', 7, '2023-08-02 17:24:57', 'A3', 13, NULL, NULL, NULL),
(467, 'CRRGNS68E43I410G', 2, '2023-09-12 11:30:42', 'B3', 11, NULL, NULL, NULL),
(468, 'MTIRST04A03D156K', 10, '2023-10-09 15:37:38', 'B2', 2, NULL, NULL, NULL),
(469, 'BRNSLL01D56C694E', 10, '2023-03-13 16:34:24', 'B3', 2, NULL, NULL, NULL),
(470, 'CTNLRI42R21C120T', 4, '2023-08-14 09:04:50', 'B2', 1, NULL, NULL, NULL),
(471, 'GCBGCM64P05L245E', 8, '2023-09-04 15:06:47', 'B3', 2, NULL, NULL, NULL),
(472, 'CSLLCU97A16A275D', 2, '2023-11-09 12:45:26', 'B2', 8, NULL, NULL, NULL),
(473, 'LCFGLL47B41F526R', 12, '2023-03-31 15:18:44', 'B1', 10, NULL, NULL, NULL),
(474, 'CPRFLV42A68G874G', 6, '2023-06-30 14:04:29', 'B1', 4, NULL, NULL, NULL),
(475, 'CTAGTR53D26F880F', 7, '2023-06-06 12:34:10', 'A4', 10, NULL, NULL, NULL),
(476, 'DMCPRZ73T09E490U', 11, '2023-11-03 09:29:35', 'A4', 16, NULL, NULL, NULL),
(477, 'RLLPLP15S64A028H', 7, '2023-04-10 09:33:23', 'A4', 9, NULL, NULL, NULL),
(478, 'CLPLCU57S12A495U', 11, '2023-06-16 11:10:30', 'A4', 14, NULL, NULL, NULL),
(479, 'LFNDMA14H26H466V', 7, '2023-08-02 17:24:57', 'A4', 16, NULL, NULL, NULL),
(480, 'LCFGLL47B41F526R', 12, '2023-03-31 15:18:44', 'B2', 9, NULL, NULL, NULL),
(481, 'BNTNBR04D05B143Q', 12, '2023-03-29 09:16:37', 'B1', 10, NULL, NULL, NULL),
(482, 'DSTVTR57R50F299J', 15, '2023-06-08 12:26:59', 'B1', 6, NULL, NULL, NULL),
(483, 'FBBGVF79D42D835L', 3, '2023-06-21 14:25:08', 'B1', 2, NULL, NULL, NULL),
(484, 'SLTLND84L22C517I', 12, '2023-06-20 17:27:54', 'B1', 10, NULL, NULL, NULL),
(485, 'MTTFPP02A51I470E', 2, '2023-05-19 15:37:13', 'B1', 7, NULL, NULL, NULL),
(486, 'MTTFPP02A51I470E', 2, '2023-05-19 15:37:13', 'B2', 8, NULL, NULL, NULL),
(487, 'DNGPRZ87E56A070R', 16, '2023-09-14 13:29:03', 'B2', 15, NULL, NULL, NULL),
(488, 'TSTSRG46M57G728V', 6, '2023-10-13 09:46:40', 'B1', 4, NULL, NULL, NULL),
(489, 'GRMZEI54C13E844C', 1, '2023-10-11 14:00:34', 'A1', 5, NULL, NULL, NULL),
(490, 'PLPSML73M21G560A', 10, '2023-05-22 10:14:15', 'B1', 2, NULL, NULL, NULL),
(491, 'NCSSDI77E66I090K', 4, '2023-05-22 16:32:41', 'B1', 1, NULL, NULL, NULL),
(492, 'LTUCMN04E03D554T', 5, '2023-09-28 09:35:35', 'B1', 8, NULL, NULL, NULL),
(493, 'MLLCRL59C30I280D', 5, '2023-06-30 12:17:36', 'B1', 7, NULL, NULL, NULL),
(494, 'ZTTNRN88P03H558P', 2, '2023-11-08 09:20:30', 'B1', 12, NULL, NULL, NULL),
(495, 'FNTLND97S64I887Z', 16, '2023-08-17 14:24:28', 'B1', 15, NULL, NULL, NULL),
(496, 'VNDVRN41M52E864S', 16, '2023-11-13 14:28:14', 'B1', 15, NULL, NULL, NULL),
(497, 'DCRBRC47E61B413Z', 1, '2023-11-15 11:08:24', 'A1', 3, NULL, NULL, NULL),
(498, 'RDRLSS77T58G865K', 14, '2023-04-24 09:20:53', 'B1', 4, NULL, NULL, NULL),
(499, 'GSTMCL53E17L737K', 12, '2023-04-28 12:27:15', 'B2', 9, NULL, NULL, NULL),
(500, 'MTTFPP02A51I470E', 2, '2023-05-19 15:37:13', 'B3', 11, NULL, NULL, NULL),
(501, 'GRMZEI54C13E844C', 1, '2023-10-11 14:00:34', 'A2', 2, NULL, NULL, NULL),
(502, 'PLPSML73M21G560A', 10, '2023-05-22 10:14:15', 'B2', 1, NULL, NULL, NULL),
(503, 'NCSSDI77E66I090K', 4, '2023-05-22 16:32:41', 'B2', 2, NULL, NULL, NULL),
(504, 'MLLCRL59C30I280D', 5, '2023-06-30 12:17:36', 'B2', 8, NULL, NULL, NULL),
(505, 'ZTTNRN88P03H558P', 2, '2023-11-08 09:20:30', 'B2', 7, NULL, NULL, NULL),
(506, 'DCRBRC47E61B413Z', 1, '2023-11-15 11:08:24', 'A2', 10, NULL, NULL, NULL),
(507, 'GSTMCL53E17L737K', 12, '2023-04-28 12:27:15', 'B3', 10, NULL, NULL, NULL),
(508, 'LSSBRC43M50F917V', 2, '2023-04-20 17:29:04', 'B1', 8, NULL, NULL, NULL),
(509, 'DVVSTR82C42D624V', 13, '2023-06-26 09:15:03', 'B1', 1, NULL, NULL, NULL),
(510, 'CRVNLT17H03C934E', 7, '2023-05-02 16:23:30', 'A1', 3, NULL, NULL, NULL),
(511, 'GRVGMN64P17D882Y', 7, '2023-03-01 11:39:02', 'A3', 12, NULL, NULL, NULL),
(512, 'BNGCCL62R03G317F', 12, '2023-04-21 12:12:43', 'B1', 10, NULL, NULL, NULL),
(513, 'STRGAI16M03G028J', 1, '2023-06-26 10:19:19', 'A1', 5, NULL, NULL, NULL),
(514, 'PRRDVD13H02B576B', 6, '2023-04-17 15:08:53', 'B2', 4, NULL, NULL, NULL),
(515, 'BGTFNZ77M48H900I', 11, '2023-10-13 14:38:04', 'A1', 7, NULL, NULL, NULL),
(516, 'BRGDLB15E66B288E', 15, '2023-07-07 16:30:01', 'B1', 6, NULL, NULL, NULL),
(517, 'SNZFNZ67C08E130W', 10, '2023-05-03 09:30:49', 'B1', 2, NULL, NULL, NULL),
(518, 'DPECHR08H50D690X', 2, '2023-02-22 11:43:24', 'B1', 12, NULL, NULL, NULL),
(519, 'BNMLDA80P64L970W', 2, '2023-07-28 14:26:14', 'B1', 7, NULL, NULL, NULL),
(520, 'FDRBRT60E56G338B', 15, '2023-04-24 11:06:29', 'B1', 5, NULL, NULL, NULL),
(521, 'MRNPMP47S53G763X', 6, '2023-11-07 09:14:27', 'B2', 4, NULL, NULL, NULL),
(522, 'CRSFST62P04B886M', 4, '2023-07-12 14:22:29', 'B3', 2, NULL, NULL, NULL),
(523, 'GROBRN97M47D575M', 12, '2023-03-21 15:47:15', 'B2', 10, NULL, NULL, NULL),
(524, 'FRRFNC54E48A387Q', 9, '2023-05-18 10:04:20', 'B1', 13, NULL, NULL, NULL),
(525, 'CMNSLV67B14C398T', 15, '2023-05-24 14:26:41', 'B4', 6, NULL, NULL, NULL),
(526, 'FRRSRN46C43L883X', 10, '2023-09-11 09:18:49', 'B2', 2, NULL, NULL, NULL),
(527, 'BSCVCN76M58B284U', 2, '2023-07-17 09:20:46', 'B2', 12, NULL, NULL, NULL),
(528, 'GLNRNN88P63D529W', 16, '2023-10-17 14:54:57', 'B1', 15, NULL, NULL, NULL),
(529, 'FRMNGL46M67I074M', 7, '2023-05-10 15:25:06', 'A1', 12, NULL, NULL, NULL),
(530, 'BRZBLD02H25D749Y', 12, '2023-09-01 10:28:49', 'B3', 9, NULL, NULL, NULL),
(531, 'STLNNI99T09C781M', 10, '2023-07-25 11:56:45', 'B2', 1, NULL, NULL, NULL),
(532, 'CRSCLI16M59I354X', 14, '2023-07-21 14:48:39', 'B2', 4, NULL, NULL, NULL),
(533, 'BRCBNC62R59M317D', 9, '2023-08-25 11:29:00', 'B2', 14, NULL, NULL, NULL),
(534, 'CNNYLN49T68I800I', 4, '2023-05-30 14:38:10', 'B4', 1, NULL, NULL, NULL),
(535, 'DNNFBA72E07G492P', 14, '2023-10-12 12:58:46', 'B2', 3, NULL, NULL, NULL),
(536, 'MRSPRN62D41I082D', 13, '2023-06-28 15:14:54', 'B2', 2, NULL, NULL, NULL),
(537, 'CNTDNL05P58C400H', 9, '2023-07-24 11:48:01', 'B2', 14, NULL, NULL, NULL),
(538, 'BRNGBB66D21F595K', 13, '2023-03-10 14:38:43', 'B2', 1, NULL, NULL, NULL),
(539, 'FMUMRL84L03D234W', 15, '2023-03-21 09:10:46', 'B1', 5, NULL, NULL, NULL),
(540, 'MLZMRC09D15E558Q', 15, '2023-08-31 14:03:37', 'B2', 6, NULL, NULL, NULL),
(541, 'FNTFCT05L49G194Y', 5, '2023-04-10 12:15:04', 'B1', 7, NULL, NULL, NULL),
(542, 'CTTPIA55M43L282S', 2, '2023-10-03 10:27:28', 'B3', 11, NULL, NULL, NULL),
(543, 'BRGRSO49P57H189Y', 13, '2023-10-10 13:29:14', 'B2', 1, NULL, NULL, NULL),
(544, 'GRBDVG53D66B856F', 1, '2023-05-25 10:07:26', 'A1', 13, NULL, NULL, NULL),
(545, 'BGLPRZ96T29H096Y', 7, '2023-09-11 16:08:26', 'A1', 5, NULL, NULL, NULL),
(546, 'GNCPLP80T43A083X', 16, '2023-05-03 15:26:56', 'B1', 16, NULL, NULL, NULL),
(547, 'CHRFNZ16D18G577Q', 9, '2023-10-24 12:12:29', 'B1', 13, NULL, NULL, NULL),
(548, 'MRSDLE00H51I103S', 3, '2023-09-05 17:56:34', 'B2', 1, NULL, NULL, NULL),
(549, 'CCCMLD12B46M316J', 4, '2023-06-13 13:51:50', 'B2', 1, NULL, NULL, NULL),
(550, 'MRSTLI82H24I847T', 1, '2023-04-06 17:44:03', 'A2', 15, NULL, NULL, NULL),
(551, 'BRNVVN80M08C770I', 13, '2023-02-20 09:47:40', 'B2', 1, NULL, NULL, NULL),
(552, 'FRICAI75A24H980B', 2, '2023-09-22 13:19:11', 'B2', 11, NULL, NULL, NULL),
(553, 'MGSYNN96D59L723I', 7, '2023-04-18 10:55:02', 'A2', 3, NULL, NULL, NULL),
(554, 'BRZBGI99S06H885M', 14, '2023-05-23 09:31:04', 'B1', 3, NULL, NULL, NULL),
(555, 'PTTMRT52L14D458K', 3, '2023-04-11 15:41:21', 'B2', 1, NULL, NULL, NULL),
(556, 'CMTLND11R27G854C', 6, '2023-07-05 14:29:17', 'B1', 3, NULL, NULL, NULL),
(557, 'FNZLND01P22G420J', 14, '2023-06-20 11:07:14', 'B2', 3, NULL, NULL, NULL),
(558, 'NSTTTI51A02L060C', 16, '2023-08-11 15:35:23', 'B2', 16, NULL, NULL, NULL),
(559, 'CRNCVN63D16C006W', 8, '2023-06-05 11:49:03', 'B2', 1, NULL, NULL, NULL),
(560, 'MNSSDR45L09I193S', 2, '2023-04-03 14:02:57', 'B2', 12, NULL, NULL, NULL),
(561, 'VDIFPP68R03D201X', 1, '2023-10-26 13:09:57', 'A1', 3, NULL, NULL, NULL),
(562, 'PTRMRT42A60I452L', 14, '2023-06-02 16:20:15', 'B3', 4, NULL, NULL, NULL),
(563, 'BLNFPP72A63L323K', 7, '2023-03-03 17:10:06', 'A1', 4, NULL, NULL, NULL),
(564, 'FRRSRN46C43L883X', 10, '2023-09-11 09:18:49', 'B3', 1, NULL, NULL, NULL),
(565, 'BSCVCN76M58B284U', 2, '2023-07-17 09:20:46', 'B3', 7, NULL, NULL, NULL),
(566, 'GLNRNN88P63D529W', 16, '2023-10-17 14:54:57', 'B2', 16, NULL, NULL, NULL),
(567, 'FRMNGL46M67I074M', 7, '2023-05-10 15:25:06', 'A2', 3, NULL, NULL, NULL),
(568, 'BRZBLD02H25D749Y', 12, '2023-09-01 10:28:49', 'B4', 10, NULL, NULL, NULL),
(569, 'CTTPIA55M43L282S', 2, '2023-10-03 10:27:28', 'B4', 8, NULL, NULL, NULL),
(570, 'GRBDVG53D66B856F', 1, '2023-05-25 10:07:26', 'A2', 8, NULL, NULL, NULL),
(571, 'BGLPRZ96T29H096Y', 7, '2023-09-11 16:08:26', 'A2', 14, NULL, NULL, NULL),
(572, 'CHRFNZ16D18G577Q', 9, '2023-10-24 12:12:29', 'B2', 14, NULL, NULL, NULL),
(573, 'MRSTLI82H24I847T', 1, '2023-04-06 17:44:03', 'A3', 11, NULL, NULL, NULL),
(574, 'FRICAI75A24H980B', 2, '2023-09-22 13:19:11', 'B3', 7, NULL, NULL, NULL),
(575, 'MGSYNN96D59L723I', 7, '2023-04-18 10:55:02', 'A3', 10, NULL, NULL, NULL),
(576, 'BRZBGI99S06H885M', 14, '2023-05-23 09:31:04', 'B2', 4, NULL, NULL, NULL),
(577, 'FNZLND01P22G420J', 14, '2023-06-20 11:07:14', 'B3', 4, NULL, NULL, NULL),
(578, 'CRNCVN63D16C006W', 8, '2023-06-05 11:49:03', 'B3', 2, NULL, NULL, NULL),
(579, 'MNSSDR45L09I193S', 2, '2023-04-03 14:02:57', 'B3', 7, NULL, NULL, NULL),
(580, 'VDIFPP68R03D201X', 1, '2023-10-26 13:09:57', 'A2', 9, NULL, NULL, NULL),
(581, 'BLNFPP72A63L323K', 7, '2023-03-03 17:10:06', 'A2', 14, NULL, NULL, NULL),
(582, 'VNNRFL66H06E323B', 15, '2023-08-22 13:47:19', 'B2', 5, NULL, NULL, NULL),
(583, 'CCCMLN48P70M182Q', 13, '2023-07-10 14:45:33', 'B2', 2, NULL, NULL, NULL),
(584, 'RMCLRT88A61D640Q', 15, '2023-05-29 17:39:26', 'B2', 5, NULL, NULL, NULL),
(585, 'FRZMTN07D65E896R', 2, '2023-10-02 12:33:57', 'B2', 12, NULL, NULL, NULL),
(586, 'FRMNGL46M67I074M', 7, '2023-05-10 15:25:06', 'A3', 5, NULL, NULL, NULL),
(587, 'GRBDVG53D66B856F', 1, '2023-05-25 10:07:26', 'A3', 15, NULL, NULL, NULL),
(588, 'BGLPRZ96T29H096Y', 7, '2023-09-11 16:08:26', 'A3', 12, NULL, NULL, NULL),
(589, 'MRSTLI82H24I847T', 1, '2023-04-06 17:44:03', 'A4', 6, NULL, NULL, NULL),
(590, 'FRICAI75A24H980B', 2, '2023-09-22 13:19:11', 'B4', 8, NULL, NULL, NULL),
(591, 'MGSYNN96D59L723I', 7, '2023-04-18 10:55:02', 'A4', 8, NULL, NULL, NULL),
(592, 'VDIFPP68R03D201X', 1, '2023-10-26 13:09:57', 'A3', 13, NULL, NULL, NULL),
(593, 'BLNFPP72A63L323K', 7, '2023-03-03 17:10:06', 'A3', 8, NULL, NULL, NULL),
(594, 'MNGFRC97M21G797C', 16, '2023-10-12 10:29:01', 'B2', 15, NULL, NULL, NULL),
(595, 'FRMNGL46M67I074M', 7, '2023-05-10 15:25:06', 'A4', 13, NULL, NULL, NULL),
(596, 'GRBDVG53D66B856F', 1, '2023-05-25 10:07:26', 'A4', 3, NULL, NULL, NULL),
(597, 'BGLPRZ96T29H096Y', 7, '2023-09-11 16:08:26', 'A4', 7, NULL, NULL, NULL),
(598, 'VDIFPP68R03D201X', 1, '2023-10-26 13:09:57', 'A4', 11, NULL, NULL, NULL),
(599, 'BLNFPP72A63L323K', 7, '2023-03-03 17:10:06', 'A4', 6, NULL, NULL, NULL),
(600, 'DJNLCA62H13M424W', 4, '2023-07-03 11:37:36', 'B2', 2, NULL, NULL, NULL),
(601, 'DJNLCA62H13M424W', 4, '2023-07-03 11:37:36', 'B3', 1, NULL, NULL, NULL),
(602, 'ZLLGRL70M45F498B', 11, '2023-08-21 10:19:47', 'A1', 7, NULL, NULL, NULL),
(603, 'CMRPMR12M59C100U', 11, '2023-11-14 12:55:36', 'A1', 14, NULL, NULL, NULL),
(604, 'ZLLGRL70M45F498B', 11, '2023-08-21 10:19:47', 'A2', 14, NULL, NULL, NULL),
(605, 'CMRPMR12M59C100U', 11, '2023-11-14 12:55:36', 'A2', 12, NULL, NULL, NULL),
(606, 'ZLLGRL70M45F498B', 11, '2023-08-21 10:19:47', 'A3', 5, NULL, NULL, NULL),
(607, 'CMRPMR12M59C100U', 11, '2023-11-14 12:55:36', 'A3', 15, NULL, NULL, NULL),
(608, 'FRRCML40M06C700B', 13, '2023-07-10 16:15:54', 'B2', 1, NULL, NULL, NULL),
(609, 'NLSMRT59C52F578H', 16, '2023-08-09 09:05:12', 'B2', 16, NULL, NULL, NULL),
(610, 'RSSGLN74C20B389X', 13, '2023-03-17 16:53:52', 'B1', 1, NULL, NULL, NULL),
(611, 'DVRDVG67M60F387J', 14, '2023-04-07 16:42:51', 'B2', 4, NULL, NULL, NULL),
(612, 'ZLLGRL70M45F498B', 11, '2023-08-21 10:19:47', 'A4', 12, NULL, NULL, NULL),
(613, 'CMRPMR12M59C100U', 11, '2023-11-14 12:55:36', 'A4', 8, NULL, NULL, NULL),
(614, 'FRRCML40M06C700B', 13, '2023-07-10 16:15:54', 'B3', 2, NULL, NULL, NULL),
(615, 'LMNRMN98P17E148F', 11, '2023-11-09 17:39:59', 'A1', 9, NULL, NULL, NULL),
(616, 'DLLDLD77P54F845K', 11, '2023-02-28 13:49:25', 'A1', 16, NULL, NULL, NULL),
(617, 'BGRVGN14M69C529U', 9, '2023-05-08 12:48:03', 'B2', 14, NULL, NULL, NULL),
(618, 'BNLSRG06B12D407N', 14, '2023-07-28 16:50:32', 'B3', 4, NULL, NULL, NULL),
(619, 'RNZBRT45T50C547M', 8, '2023-09-11 12:31:19', 'B1', 2, NULL, NULL, NULL),
(620, 'NSTMDE16A23A245J', 15, '2023-07-12 09:01:11', 'B2', 5, NULL, NULL, NULL),
(621, 'GTTSNO47S66L233T', 10, '2023-10-10 14:52:07', 'B2', 1, NULL, NULL, NULL),
(622, 'RBNDNT09R08I359T', 8, '2023-09-22 16:38:36', 'B2', 1, NULL, NULL, NULL),
(623, 'BRGMSM83M14A918D', 11, '2023-07-28 12:52:36', 'A2', 11, NULL, NULL, NULL),
(624, 'CTRPRD03A18B778X', 8, '2023-06-01 10:12:39', 'B2', 2, NULL, NULL, NULL),
(625, 'DVTLRZ62T28D828Z', 11, '2024-01-10 15:34:26', 'A1', 7, NULL, NULL, NULL),
(626, 'CRLMRO52A29E377E', 4, '2023-09-12 10:29:41', 'B1', 1, NULL, NULL, NULL),
(627, 'BSCCRI10R17L777P', 12, '2023-07-27 16:11:01', 'B1', 9, NULL, NULL, NULL),
(628, 'FLCFTN49T03D651T', 14, '2023-12-05 09:52:15', 'B1', 3, NULL, NULL, NULL),
(629, 'DNONLC82M67H888J', 9, '2024-01-26 15:07:18', 'B1', 14, NULL, NULL, NULL),
(630, 'BCOMMM68S12H985P', 4, '2023-05-31 11:28:19', 'B1', 2, NULL, NULL, NULL),
(631, 'LTMCLN49R62H028W', 10, '2023-08-30 12:57:28', 'B1', 2, NULL, NULL, NULL),
(632, 'LBRFMN10S48H703L', 6, '2023-10-11 09:52:03', 'B1', 3, NULL, NULL, NULL),
(633, 'GRNFBL00E50H856A', 13, '2023-07-14 13:05:28', 'B1', 1, NULL, NULL, NULL),
(634, 'GRSLBR96T17I613G', 6, '2023-06-07 12:20:24', 'B1', 3, NULL, NULL, NULL),
(635, 'CRCDNT72H04D653O', 2, '2023-09-29 15:55:12', 'B1', 7, NULL, NULL, NULL),
(636, 'VJNLEA12C48L739L', 8, '2023-05-19 17:09:23', 'B3', 1, NULL, NULL, NULL),
(637, 'BTRMRT43L53L187A', 9, '2023-03-27 12:26:11', 'B1', 14, NULL, NULL, NULL),
(638, 'MSRLNE40D50B514V', 14, '2024-01-30 16:56:59', 'B1', 3, NULL, NULL, NULL),
(639, 'PLDLEA92T51E439Q', 3, '2023-10-05 16:13:58', 'B1', 2, NULL, NULL, NULL),
(640, 'FRNPRI89L45I346I', 9, '2024-01-10 16:20:16', 'B1', 13, NULL, NULL, NULL),
(641, 'GLBMNL58S20H942M', 11, '2024-01-23 13:16:51', 'A1', 10, NULL, NULL, NULL),
(642, 'FCHTST75A15F926G', 4, '2023-12-26 15:26:39', 'B1', 1, NULL, NULL, NULL),
(643, 'BNRGVF97R65M317E', 6, '2023-03-13 16:57:19', 'B4', 4, NULL, NULL, NULL),
(644, 'FNCGRM46T22L014L', 11, '2023-07-12 15:07:32', 'A1', 5, NULL, NULL, NULL),
(645, 'PFFCST93P51B789D', 16, '2023-09-26 14:16:39', 'B1', 16, NULL, NULL, NULL),
(646, 'CMBRRT09L26C629C', 7, '2023-12-28 17:40:21', 'A1', 6, NULL, NULL, NULL),
(647, 'CGLFLV13T64M041Q', 15, '2023-06-19 10:46:59', 'B1', 5, NULL, NULL, NULL),
(648, 'FDDDAA84T61B630M', 5, '2023-07-13 12:39:24', 'B1', 8, NULL, NULL, NULL),
(649, 'NCLFDR14P19A816P', 7, '2023-02-24 12:23:35', 'A1', 8, NULL, NULL, NULL),
(650, 'CDLTZN59B26C545I', 3, '2024-01-18 09:48:37', 'B1', 2, NULL, NULL, NULL),
(651, 'NCCMTT57R16M119U', 8, '2024-01-15 17:51:14', 'B1', 2, NULL, NULL, NULL),
(652, 'BLFVGN62A57F286Q', 12, '2023-07-31 17:11:39', 'B1', 9, NULL, NULL, NULL),
(653, 'LVIDLD57A64E691O', 2, '2023-07-07 14:04:50', 'B1', 8, NULL, NULL, NULL),
(654, 'MNDDBR50A20D565G', 2, '2023-09-27 09:46:37', 'B1', 12, NULL, NULL, NULL),
(655, 'FLSNLC45T52E187S', 11, '2024-01-23 09:00:50', 'A1', 14, NULL, NULL, NULL),
(656, 'BCHLVR05L31A942W', 8, '2023-08-03 11:19:26', 'B1', 2, NULL, NULL, NULL),
(657, 'MDALBN00C26L722A', 7, '2024-01-10 13:21:01', 'A1', 12, NULL, NULL, NULL),
(658, 'BRTPLL60C16G492W', 3, '2024-01-11 17:33:21', 'B1', 2, NULL, NULL, NULL),
(659, 'ZNTLSN97R63B510V', 7, '2023-05-23 14:51:13', 'A1', 10, NULL, NULL, NULL),
(660, 'PTMGLL51M66F162A', 6, '2024-01-25 12:24:55', 'B1', 3, NULL, NULL, NULL),
(661, 'VLNFSC03D50D853H', 6, '2023-09-18 11:14:49', 'B1', 4, NULL, NULL, NULL),
(662, 'NZNLCL48H25D179Q', 16, '2023-08-28 17:27:45', 'B1', 15, NULL, NULL, NULL),
(663, 'BNVMMI70P61D086K', 2, '2023-05-05 13:42:09', 'B1', 7, NULL, NULL, NULL),
(664, 'BTTMLN98R19M150J', 7, '2023-02-20 15:04:03', 'A1', 2, NULL, NULL, NULL),
(665, 'BRSGTA01A63D450F', 5, '2023-08-16 12:33:01', 'B1', 7, NULL, NULL, NULL),
(666, 'GSSDLE56L29E236Z', 2, '2024-02-05 12:51:23', 'B1', 12, NULL, NULL, NULL),
(667, 'SCNNSC51H42C273S', 13, '2023-04-07 09:28:53', 'B1', 1, NULL, NULL, NULL),
(668, 'DMTNLN86M18H186A', 6, '2023-03-17 15:44:44', 'B3', 4, NULL, NULL, NULL),
(669, 'GLLLNI63H44E370G', 12, '2023-08-02 15:22:28', 'B3', 10, NULL, NULL, NULL),
(670, 'BRLLDN78L70L899T', 8, '2023-07-06 14:12:46', 'B1', 2, NULL, NULL, NULL),
(671, 'TSCCCT81R69F887L', 4, '2023-04-03 16:09:26', 'B1', 1, NULL, NULL, NULL),
(672, 'CMBRRT09L26C629C', 7, '2023-12-28 17:40:21', 'A2', 15, NULL, NULL, NULL),
(673, 'NCLFDR14P19A816P', 7, '2023-02-24 12:23:35', 'A2', 1, NULL, NULL, NULL),
(674, 'NCCMTT57R16M119U', 8, '2024-01-15 17:51:14', 'B2', 1, NULL, NULL, NULL),
(675, 'LVIDLD57A64E691O', 2, '2023-07-07 14:04:50', 'B2', 7, NULL, NULL, NULL),
(676, 'MNDDBR50A20D565G', 2, '2023-09-27 09:46:37', 'B2', 7, NULL, NULL, NULL),
(677, 'FLSNLC45T52E187S', 11, '2024-01-23 09:00:50', 'A2', 11, NULL, NULL, NULL),
(678, 'MDALBN00C26L722A', 7, '2024-01-10 13:21:01', 'A2', 2, NULL, NULL, NULL),
(679, 'ZNTLSN97R63B510V', 7, '2023-05-23 14:51:13', 'A2', 15, NULL, NULL, NULL),
(680, 'BNVMMI70P61D086K', 2, '2023-05-05 13:42:09', 'B2', 8, NULL, NULL, NULL),
(681, 'BTTMLN98R19M150J', 7, '2023-02-20 15:04:03', 'A2', 9, NULL, NULL, NULL),
(682, 'GSSDLE56L29E236Z', 2, '2024-02-05 12:51:23', 'B2', 7, NULL, NULL, NULL),
(683, 'TSCCCT81R69F887L', 4, '2023-04-03 16:09:26', 'B2', 2, NULL, NULL, NULL),
(684, 'BLSRKE06S48H393O', 6, '2023-08-28 11:11:12', 'B1', 4, NULL, NULL, NULL),
(685, 'MSTCSR45R06B894A', 11, '2023-04-25 11:00:10', 'A1', 11, NULL, NULL, NULL),
(686, 'PSRGLN81S47B748Q', 14, '2023-08-09 10:58:59', 'B1', 3, NULL, NULL, NULL),
(687, 'SBRNCN83L07H186V', 12, '2023-12-11 15:23:50', 'B1', 9, NULL, NULL, NULL),
(688, 'CRLCLL69A53F002N', 12, '2023-07-10 13:19:21', 'B1', 9, NULL, NULL, NULL),
(689, 'CRRPRI15C46E090B', 2, '2023-05-10 09:36:49', 'B2', 7, NULL, NULL, NULL),
(690, 'CCCRNN03P61I605H', 16, '2023-03-20 17:55:52', 'B2', 15, NULL, NULL, NULL),
(691, 'CPRRZO93P17A309Z', 15, '2023-09-26 11:52:01', 'B1', 5, NULL, NULL, NULL),
(692, 'BRCNRN52T58A488P', 11, '2023-02-22 17:24:30', 'A2', 2, NULL, NULL, NULL),
(693, 'DBRGLL45H24G834M', 2, '2023-11-07 10:12:38', 'B3', 8, NULL, NULL, NULL),
(694, 'CMPMRM85D49A334X', 11, '2023-06-05 15:25:40', 'A1', 7, NULL, NULL, NULL),
(695, 'CMOCLN40D44E758R', 5, '2023-07-19 10:26:43', 'B1', 7, NULL, NULL, NULL),
(696, 'GDDVCN43A58L522C', 10, '2023-11-28 11:43:56', 'B1', 1, NULL, NULL, NULL),
(697, 'CPLFLV70B46B461C', 12, '2023-04-26 16:47:42', 'B1', 10, NULL, NULL, NULL),
(698, 'BTTVNA47B68D553N', 3, '2023-10-02 17:31:48', 'B1', 2, NULL, NULL, NULL),
(699, 'GLVTST08A08G944Z', 6, '2023-09-21 14:37:46', 'B1', 3, NULL, NULL, NULL),
(700, 'RNRMSS62A46B082T', 10, '2023-12-06 17:24:51', 'B1', 2, NULL, NULL, NULL),
(701, 'PPOBRN96A01C638O', 8, '2023-03-20 14:14:07', 'B1', 2, NULL, NULL, NULL),
(702, 'BNVMTT61S07H423I', 15, '2024-02-16 12:07:23', 'B1', 6, NULL, NULL, NULL),
(703, 'CPRGRT88H11I781J', 2, '2023-04-24 13:57:21', 'B1', 12, NULL, NULL, NULL),
(704, 'ZPPGNR69T12B396E', 2, '2023-05-23 10:59:57', 'B1', 12, NULL, NULL, NULL),
(705, 'NCLFDR14P19A816P', 7, '2023-02-24 12:23:35', 'A3', 6, NULL, NULL, NULL),
(706, 'LVIDLD57A64E691O', 2, '2023-07-07 14:04:50', 'B3', 11, NULL, NULL, NULL),
(707, 'FLSNLC45T52E187S', 11, '2024-01-23 09:00:50', 'A3', 8, NULL, NULL, NULL),
(708, 'MDALBN00C26L722A', 7, '2024-01-10 13:21:01', 'A3', 7, NULL, NULL, NULL),
(709, 'ZNTLSN97R63B510V', 7, '2023-05-23 14:51:13', 'A3', 1, NULL, NULL, NULL),
(710, 'BNVMMI70P61D086K', 2, '2023-05-05 13:42:09', 'B3', 11, NULL, NULL, NULL),
(711, 'BTTMLN98R19M150J', 7, '2023-02-20 15:04:03', 'A3', 5, NULL, NULL, NULL),
(712, 'MSTCSR45R06B894A', 11, '2023-04-25 11:00:10', 'A2', 5, NULL, NULL, NULL),
(713, 'BRCNRN52T58A488P', 11, '2023-02-22 17:24:30', 'A3', 3, NULL, NULL, NULL),
(714, 'DBRGLL45H24G834M', 2, '2023-11-07 10:12:38', 'B4', 11, NULL, NULL, NULL),
(715, 'CMPMRM85D49A334X', 11, '2023-06-05 15:25:40', 'A2', 2, NULL, NULL, NULL),
(716, 'BTTVNA47B68D553N', 3, '2023-10-02 17:31:48', 'B2', 1, NULL, NULL, NULL),
(717, 'PPOBRN96A01C638O', 8, '2023-03-20 14:14:07', 'B2', 1, NULL, NULL, NULL),
(718, 'CPRGRT88H11I781J', 2, '2023-04-24 13:57:21', 'B2', 7, NULL, NULL, NULL),
(719, 'ZPPGNR69T12B396E', 2, '2023-05-23 10:59:57', 'B2', 11, NULL, NULL, NULL),
(720, 'NCCSST90P17E742S', 11, '2023-05-22 15:37:22', 'A1', 9, NULL, NULL, NULL),
(721, 'VRSCLL55C21A643D', 4, '2023-07-03 16:14:54', 'B1', 2, NULL, NULL, NULL),
(722, 'NCLFDR14P19A816P', 7, '2023-02-24 12:23:35', 'A4', 10, NULL, NULL, NULL),
(723, 'FLSNLC45T52E187S', 11, '2024-01-23 09:00:50', 'A4', 16, NULL, NULL, NULL),
(724, 'MDALBN00C26L722A', 7, '2024-01-10 13:21:01', 'A4', 16, NULL, NULL, NULL),
(725, 'ZNTLSN97R63B510V', 7, '2023-05-23 14:51:13', 'A4', 11, NULL, NULL, NULL),
(726, 'BTTMLN98R19M150J', 7, '2023-02-20 15:04:03', 'A4', 15, NULL, NULL, NULL),
(727, 'MSTCSR45R06B894A', 11, '2023-04-25 11:00:10', 'A3', 14, NULL, NULL, NULL),
(728, 'BRCNRN52T58A488P', 11, '2023-02-22 17:24:30', 'A4', 16, NULL, NULL, NULL),
(729, 'CMPMRM85D49A334X', 11, '2023-06-05 15:25:40', 'A3', 4, NULL, NULL, NULL),
(730, 'ZPPGNR69T12B396E', 2, '2023-05-23 10:59:57', 'B3', 8, NULL, NULL, NULL),
(731, 'NCCSST90P17E742S', 11, '2023-05-22 15:37:22', 'A2', 12, NULL, NULL, NULL),
(732, 'VRSCLL55C21A643D', 4, '2023-07-03 16:14:54', 'B2', 1, NULL, NULL, NULL),
(733, 'PZZMGH05E51H006Y', 15, '2023-08-29 10:28:28', 'B1', 5, NULL, NULL, NULL),
(734, 'MSTCSR45R06B894A', 11, '2023-04-25 11:00:10', 'A4', 4, NULL, NULL, NULL),
(735, 'CMPMRM85D49A334X', 11, '2023-06-05 15:25:40', 'A4', 12, NULL, NULL, NULL),
(736, 'NCCSST90P17E742S', 11, '2023-05-22 15:37:22', 'A3', 5, NULL, NULL, NULL),
(737, 'NCCSST90P17E742S', 11, '2023-05-22 15:37:22', 'A4', 15, NULL, NULL, NULL),
(738, 'LTMLND16R31I152G', 10, '2024-01-08 13:37:07', 'B1', 2, NULL, NULL, NULL),
(739, 'NRDRNL91S21E213P', 15, '2023-09-19 10:58:03', 'B1', 5, NULL, NULL, NULL),
(740, 'FVLMRC05B03H695N', 2, '2023-06-29 11:08:13', 'B1', 11, NULL, NULL, NULL),
(741, 'DPSSLV50S01I878Z', 9, '2023-06-26 17:22:15', 'B1', 14, NULL, NULL, NULL),
(742, 'MMESLL88E64I980F', 4, '2024-01-25 15:06:47', 'B1', 2, NULL, NULL, NULL),
(743, 'BRNMNL68C22D752P', 15, '2023-05-19 10:43:46', 'B1', 6, NULL, NULL, NULL),
(744, 'RNAGGN59C02I565Y', 7, '2023-05-17 11:13:31', 'A1', 5, NULL, NULL, NULL),
(745, 'LVNGTN46L19F829K', 3, '2024-01-03 12:18:58', 'B1', 2, NULL, NULL, NULL),
(746, 'GLBMTA01L49A354A', 15, '2023-12-25 16:11:09', 'B1', 5, NULL, NULL, NULL),
(747, 'FNZDLL51C42E527B', 12, '2024-01-05 12:57:42', 'B1', 10, NULL, NULL, NULL),
(748, 'LTMLND16R31I152G', 10, '2024-01-08 13:37:07', 'B2', 1, NULL, NULL, NULL),
(749, 'FVLMRC05B03H695N', 2, '2023-06-29 11:08:13', 'B2', 8, NULL, NULL, NULL),
(750, 'RNAGGN59C02I565Y', 7, '2023-05-17 11:13:31', 'A2', 13, NULL, NULL, NULL),
(751, 'FNZDLL51C42E527B', 12, '2024-01-05 12:57:42', 'B2', 9, NULL, NULL, NULL),
(752, 'RNAGGN59C02I565Y', 7, '2023-05-17 11:13:31', 'A3', 10, NULL, NULL, NULL),
(753, 'DLCDLE62T50D016N', 4, '2023-09-11 13:30:16', 'B2', 1, NULL, NULL, NULL),
(754, 'FRNPLT59D30D662U', 4, '2023-12-15 10:43:50', 'B1', 1, NULL, NULL, NULL),
(755, 'DPNVGN55D55F280X', 14, '2023-07-07 11:22:36', 'B1', 4, NULL, NULL, NULL),
(756, 'CRSSVN82H48F623J', 16, '2024-01-23 11:49:33', 'B1', 15, NULL, NULL, NULL),
(757, 'MNTDLZ96S09D043W', 9, '2023-05-22 10:42:57', 'B3', 14, NULL, NULL, NULL),
(758, 'CNRTNO54L57I808M', 2, '2023-10-26 16:31:15', 'B1', 11, NULL, NULL, NULL),
(759, 'DSCVLR47B26I985Z', 9, '2023-02-27 14:15:16', 'B1', 14, NULL, NULL, NULL),
(760, 'PRRLDN89P08L454N', 1, '2023-10-30 09:12:48', 'A1', 15, NULL, NULL, NULL),
(761, 'PRLSVR74C06F594Q', 3, '2023-05-01 11:21:19', 'B1', 2, NULL, NULL, NULL),
(762, 'FSCVEA69A48L014G', 13, '2023-06-23 12:32:03', 'B1', 1, NULL, NULL, NULL),
(763, 'DFNPLA65R28C276Z', 1, '2023-02-21 11:24:51', 'A1', 11, NULL, NULL, NULL),
(764, 'RNAGGN59C02I565Y', 7, '2023-05-17 11:13:31', 'A4', 16, NULL, NULL, NULL),
(765, 'CRSSVN82H48F623J', 16, '2024-01-23 11:49:33', 'B2', 16, NULL, NULL, NULL),
(766, 'CNRTNO54L57I808M', 2, '2023-10-26 16:31:15', 'B2', 8, NULL, NULL, NULL),
(767, 'PRRLDN89P08L454N', 1, '2023-10-30 09:12:48', 'A2', 5, NULL, NULL, NULL),
(768, 'PRLSVR74C06F594Q', 3, '2023-05-01 11:21:19', 'B2', 1, NULL, NULL, NULL),
(769, 'DFNPLA65R28C276Z', 1, '2023-02-21 11:24:51', 'A2', 14, NULL, NULL, NULL),
(770, 'VNZGTN62C41D769W', 7, '2023-03-09 15:06:46', 'A1', 2, NULL, NULL, NULL),
(771, 'NNNRND11D02E784O', 15, '2023-04-17 15:15:54', 'B3', 5, NULL, NULL, NULL),
(772, 'DVNLNZ85L68L643M', 9, '2023-04-21 13:01:22', 'B2', 14, NULL, NULL, NULL),
(773, 'STCCLO04R49G062I', 3, '2023-09-14 16:07:42', 'B1', 2, NULL, NULL, NULL),
(774, 'GLTGLE63T52L508J', 15, '2023-03-24 16:40:53', 'B1', 6, NULL, NULL, NULL),
(775, 'DNNGST02R09F569Y', 8, '2024-01-12 15:41:58', 'B1', 1, NULL, NULL, NULL),
(776, 'FRRFMN08C63C791Z', 4, '2023-12-04 17:22:40', 'B1', 1, NULL, NULL, NULL),
(777, 'DLLLRT95T01B444T', 4, '2023-06-15 12:25:43', 'B2', 2, NULL, NULL, NULL),
(778, 'RCLRSO79L59G461E', 10, '2023-03-02 13:22:54', 'B1', 2, NULL, NULL, NULL),
(779, 'RCARTD11P14H532J', 16, '2023-03-16 10:56:00', 'B2', 15, NULL, NULL, NULL),
(780, 'ZMBCSN46H68F784C', 10, '2023-05-17 17:41:31', 'B1', 2, NULL, NULL, NULL),
(781, 'CVCNTS47H59I196L', 9, '2023-09-19 11:34:29', 'B2', 14, NULL, NULL, NULL),
(782, 'RNDGAI86S17G329E', 4, '2023-03-30 12:04:10', 'B1', 2, NULL, NULL, NULL),
(783, 'FGGRRT97A07M067E', 7, '2023-10-17 15:22:14', 'A2', 8, NULL, NULL, NULL),
(784, 'RTLMRT64E60E576O', 3, '2023-09-18 09:30:23', 'B1', 1, NULL, NULL, NULL),
(785, 'VLRLSN73M71L462L', 1, '2023-11-27 09:42:44', 'A1', 7, NULL, NULL, NULL),
(786, 'CSTBLD65M21E135B', 3, '2023-07-18 16:55:45', 'B1', 1, NULL, NULL, NULL),
(787, 'BFLTNI40E50I255H', 12, '2023-09-14 15:21:47', 'B2', 9, NULL, NULL, NULL),
(788, 'CSMMRK10R28C654B', 6, '2023-09-01 14:33:13', 'B1', 4, NULL, NULL, NULL),
(789, 'MCCPMP45P28A131K', 9, '2023-02-27 10:49:13', 'B1', 14, NULL, NULL, NULL),
(790, 'LNDSRN58H68A333N', 8, '2023-06-21 17:02:27', 'B1', 2, NULL, NULL, NULL),
(791, 'CRBTST60S27I799R', 2, '2023-04-21 10:53:24', 'B1', 11, NULL, NULL, NULL),
(792, 'RGNRNL97A56L154A', 5, '2023-11-30 12:55:41', 'B1', 8, NULL, NULL, NULL),
(793, 'NGLTSC60E70E078W', 10, '2024-01-08 17:44:22', 'B1', 2, NULL, NULL, NULL),
(794, 'DNNCNZ74H47H329B', 15, '2024-01-19 16:24:00', 'B1', 6, NULL, NULL, NULL),
(795, 'RNZLRT77S25H554L', 8, '2023-05-23 13:48:36', 'B1', 1, NULL, NULL, NULL),
(796, 'BLCCRL44H17C548T', 5, '2023-03-08 16:02:05', 'B1', 7, NULL, NULL, NULL),
(797, 'CRDGST90P03C413M', 5, '2023-11-20 13:30:33', 'B1', 7, NULL, NULL, NULL),
(798, 'FNCVTI58L27E737D', 11, '2023-08-29 17:13:34', 'A1', 16, NULL, NULL, NULL),
(799, 'DPNLSS89L28B368N', 15, '2023-02-23 11:10:46', 'B1', 6, NULL, NULL, NULL),
(800, 'PMNBDT72P68D423A', 15, '2024-02-05 12:08:04', 'B3', 5, NULL, NULL, NULL),
(801, 'MRAVVN86P01D399S', 10, '2023-10-24 14:42:40', 'B1', 1, NULL, NULL, NULL),
(802, 'CMTNTS17E53E092T', 6, '2023-12-01 10:51:56', 'B1', 4, NULL, NULL, NULL),
(803, 'DGLSNT57C70G114T', 14, '2023-05-15 17:49:34', 'B2', 4, NULL, NULL, NULL),
(804, 'GZZSFN55D66C040F', 13, '2023-11-03 16:48:48', 'B3', 1, NULL, NULL, NULL),
(805, 'TRTTTI45C05D763V', 10, '2023-09-14 13:45:11', 'B3', 2, NULL, NULL, NULL),
(806, 'GZZNCN75B14M065C', 4, '2023-05-08 12:40:18', 'B3', 2, NULL, NULL, NULL),
(807, 'CBNTNZ78H14D334I', 11, '2023-12-07 16:44:48', 'A1', 2, NULL, NULL, NULL),
(808, 'PLTTTV50M07C082Q', 12, '2023-11-07 11:26:44', 'B1', 10, NULL, NULL, NULL),
(809, 'TRAVVN50R43D459Q', 12, '2023-09-13 12:54:39', 'B1', 10, NULL, NULL, NULL),
(810, 'GLNFTM90R41C957Z', 2, '2023-08-31 14:04:37', 'B3', 8, NULL, NULL, NULL),
(811, 'CRPMDA40C31D244E', 11, '2023-08-04 11:30:07', 'A1', 14, NULL, NULL, NULL),
(812, 'LMNNBL97L46C554K', 3, '2024-01-23 16:47:26', 'B1', 1, NULL, NULL, NULL),
(813, 'NTRRBN61D43A052S', 10, '2024-01-31 15:42:38', 'B1', 2, NULL, NULL, NULL),
(814, 'CQRRNN88E55H331U', 14, '2023-12-06 12:19:42', 'B1', 3, NULL, NULL, NULL),
(815, 'MNTCCL40A46C110S', 10, '2023-11-15 17:15:00', 'B1', 2, NULL, NULL, NULL),
(816, 'RGGCMN83E19B567W', 13, '2023-11-29 12:23:26', 'B1', 2, NULL, NULL, NULL),
(817, 'FGLFMN66P56G751B', 14, '2023-07-11 10:17:13', 'B1', 4, NULL, NULL, NULL),
(818, 'BLDRMI66A62B609B', 11, '2023-04-28 12:19:39', 'A1', 6, NULL, NULL, NULL),
(819, 'CNDPCR48T17G250Y', 9, '2023-11-24 16:58:45', 'B1', 14, NULL, NULL, NULL),
(820, 'FNTTTI44L27F939L', 16, '2023-09-12 16:55:04', 'B1', 15, NULL, NULL, NULL),
(821, 'GRRLDL44D03B810O', 8, '2024-02-07 15:16:17', 'B1', 2, NULL, NULL, NULL),
(822, 'CMBBDT77H01I437S', 8, '2023-10-13 12:16:27', 'B1', 1, NULL, NULL, NULL),
(823, 'RFFFRZ72C60G071F', 5, '2023-06-23 09:28:02', 'B1', 7, NULL, NULL, NULL),
(824, 'GZZNCN75B14M065C', 4, '2023-05-08 12:40:18', 'B4', 1, NULL, NULL, NULL),
(825, 'CBNTNZ78H14D334I', 11, '2023-12-07 16:44:48', 'A2', 13, NULL, NULL, NULL),
(826, 'CRPMDA40C31D244E', 11, '2023-08-04 11:30:07', 'A2', 11, NULL, NULL, NULL),
(827, 'FGLFMN66P56G751B', 14, '2023-07-11 10:17:13', 'B2', 3, NULL, NULL, NULL),
(828, 'BLDRMI66A62B609B', 11, '2023-04-28 12:19:39', 'A2', 16, NULL, NULL, NULL),
(829, 'FNTTTI44L27F939L', 16, '2023-09-12 16:55:04', 'B2', 16, NULL, NULL, NULL),
(830, 'RFFFRZ72C60G071F', 5, '2023-06-23 09:28:02', 'B2', 8, NULL, NULL, NULL),
(831, 'BRSRTD12D08L507C', 3, '2023-09-08 11:30:37', 'B1', 1, NULL, NULL, NULL),
(832, 'QSSLLD40S07E651M', 6, '2023-10-19 11:17:23', 'B1', 3, NULL, NULL, NULL),
(833, 'LNRCAI00L10C829J', 8, '2023-03-24 16:08:52', 'B2', 1, NULL, NULL, NULL),
(834, 'NTZFNN68B11I183R', 5, '2023-06-23 14:00:51', 'B2', 7, NULL, NULL, NULL),
(835, 'SCRBRN67M63H538J', 6, '2023-02-22 14:56:55', 'B1', 3, NULL, NULL, NULL),
(836, 'BNTDLM73D24H818A', 8, '2023-02-27 15:29:34', 'B1', 1, NULL, NULL, NULL),
(837, 'FRNGRD13P16H365S', 1, '2023-08-25 09:41:59', 'A1', 16, NULL, NULL, NULL),
(838, 'BNCLNZ84T30C638Y', 11, '2023-09-12 14:30:38', 'A1', 5, NULL, NULL, NULL),
(839, 'CMBNRN64S55B888R', 2, '2023-09-28 10:41:04', 'B1', 8, NULL, NULL, NULL),
(840, 'GRRNZR11R07C971T', 12, '2023-03-06 12:59:32', 'B1', 9, NULL, NULL, NULL),
(841, 'PNCFNC43D19H489E', 14, '2023-03-06 16:31:15', 'B1', 4, NULL, NULL, NULL),
(842, 'PTRLRN60R59L944A', 1, '2024-01-04 09:01:02', 'A1', 8, NULL, NULL, NULL),
(843, 'GGULEA94M43C565P', 4, '2024-02-14 11:18:16', 'B1', 2, NULL, NULL, NULL),
(844, 'LPMNDR42E14I671E', 2, '2023-06-28 10:02:35', 'B1', 7, NULL, NULL, NULL),
(845, 'CMLDCC60D27F553Y', 8, '2023-12-07 10:03:18', 'B1', 2, NULL, NULL, NULL),
(846, 'RTSFRZ77T30A772S', 7, '2023-02-22 12:46:32', 'A1', 16, NULL, NULL, NULL),
(847, 'BTTGTV56S23E910L', 7, '2023-11-17 14:10:04', 'A1', 14, NULL, NULL, NULL),
(848, 'ZRDFNC83M31D006G', 6, '2023-08-17 09:24:32', 'B1', 3, NULL, NULL, NULL),
(849, 'CHPSND07S24B810F', 12, '2023-11-10 09:39:53', 'B1', 9, NULL, NULL, NULL),
(850, 'GLRLDN52H57E191C', 9, '2023-10-16 16:55:56', 'B1', 14, NULL, NULL, NULL),
(851, 'DHELNE90P66G271R', 7, '2023-06-27 16:55:47', 'A1', 4, NULL, NULL, NULL),
(852, 'DPSFBN62E41H443F', 13, '2023-12-08 16:19:28', 'B1', 1, NULL, NULL, NULL),
(853, 'DMRVNT45R62H717G', 8, '2023-04-12 12:47:11', 'B1', 2, NULL, NULL, NULL),
(854, 'CLDWND79C41L665S', 13, '2023-05-23 09:43:25', 'B3', 1, NULL, NULL, NULL),
(855, 'TMMFNC50A47B390U', 6, '2023-09-14 16:54:40', 'B2', 3, NULL, NULL, NULL),
(856, 'CSAMRZ12P48A570O', 8, '2024-01-02 16:37:42', 'B1', 1, NULL, NULL, NULL),
(857, 'LTRLVR63P10C507U', 11, '2023-08-09 14:05:09', 'A1', 12, NULL, NULL, NULL),
(858, 'RCCBGI05B25L063H', 8, '2023-05-30 13:06:34', 'B1', 1, NULL, NULL, NULL),
(859, 'BSIRLF58C03E167T', 1, '2023-04-14 10:30:58', 'A1', 11, NULL, NULL, NULL),
(860, 'TRSLNE57C65G631Q', 12, '2023-08-14 12:31:27', 'B2', 9, NULL, NULL, NULL),
(861, 'VLNRBN89C48B294V', 9, '2023-11-16 12:18:39', 'B1', 13, NULL, NULL, NULL),
(862, 'BRGGRL65P10H182Y', 5, '2023-08-02 17:19:12', 'B1', 7, NULL, NULL, NULL),
(863, 'SRSGTN92S16G641U', 5, '2024-01-17 15:37:55', 'B1', 7, NULL, NULL, NULL),
(864, 'LZZDLN74S43H338W', 15, '2023-03-31 11:14:00', 'B1', 6, NULL, NULL, NULL),
(865, 'CRSPLT52B13G400H', 15, '2023-04-25 15:38:56', 'B1', 5, NULL, NULL, NULL),
(866, 'SCHDRT91C70F955K', 2, '2023-09-05 15:01:34', 'B1', 12, NULL, NULL, NULL),
(867, 'CPNLDR96T31E459C', 5, '2023-04-04 17:27:49', 'B1', 8, NULL, NULL, NULL),
(868, 'NNBPCR92E13L812Q', 9, '2024-02-16 14:49:37', 'B1', 14, NULL, NULL, NULL),
(869, 'SNSMRC06A48A025C', 4, '2023-10-11 16:12:33', 'B1', 2, NULL, NULL, NULL),
(870, 'BLLRMR02P70I053Y', 15, '2023-07-18 13:22:44', 'B1', 5, NULL, NULL, NULL),
(871, 'CLNMSM85S26F730V', 7, '2023-04-27 09:39:16', 'A1', 8, NULL, NULL, NULL),
(872, 'GLZTLI51T27E660X', 7, '2023-09-19 12:23:01', 'A1', 4, NULL, NULL, NULL),
(873, 'BNRNLN12H28E492O', 14, '2023-09-01 13:00:48', 'B2', 4, NULL, NULL, NULL),
(874, 'LGLGTN79B42B028B', 16, '2023-12-20 15:10:37', 'B1', 16, NULL, NULL, NULL),
(875, 'BZORGR91P23G779O', 9, '2023-04-13 10:10:10', 'B1', 13, NULL, NULL, NULL),
(876, 'BRTLRA92L48H203P', 6, '2023-05-29 16:10:05', 'B1', 4, NULL, NULL, NULL),
(877, 'SRRDZN01C51C141Q', 7, '2023-11-24 10:58:01', 'A1', 14, NULL, NULL, NULL),
(878, 'CBNSNL82T55G364A', 9, '2023-07-07 13:05:02', 'B4', 14, NULL, NULL, NULL),
(879, 'FRNMDA42H25I577B', 14, '2024-01-10 14:06:31', 'B1', 3, NULL, NULL, NULL),
(880, 'RGLGNS65T60H614F', 6, '2024-01-17 17:52:19', 'B1', 3, NULL, NULL, NULL),
(881, 'VNNMTA44L41L539I', 9, '2023-03-07 11:10:20', 'B2', 14, NULL, NULL, NULL),
(882, 'BRLFDR57H67D671F', 9, '2023-06-16 15:36:53', 'B2', 14, NULL, NULL, NULL),
(883, 'MRTMRN78E47I234G', 14, '2023-08-11 09:04:01', 'B1', 4, NULL, NULL, NULL),
(884, 'FGGVCN78S50A713L', 1, '2023-08-02 11:29:08', 'A1', 5, NULL, NULL, NULL),
(885, 'DLCRND75C30L893K', 16, '2023-12-06 12:31:51', 'B2', 16, NULL, NULL, NULL),
(886, 'GSLMCL97S01I260V', 16, '2023-03-31 17:31:16', 'B1', 16, NULL, NULL, NULL),
(887, 'RGLDNI00A41L607U', 11, '2023-06-07 12:42:39', 'A1', 2, NULL, NULL, NULL),
(888, 'BNCLNS05B21I165Y', 7, '2023-10-24 11:46:29', 'A2', 8, NULL, NULL, NULL),
(889, 'BNNFDR11C19B993Y', 15, '2023-09-15 12:08:44', 'B1', 6, NULL, NULL, NULL),
(890, 'DDIDLN14P48H505I', 2, '2023-10-16 13:29:47', 'B1', 12, NULL, NULL, NULL),
(891, 'CRPVLI79B50D540H', 7, '2024-01-09 11:12:44', 'A1', 5, NULL, NULL, NULL),
(892, 'SNTMRA47D09M140Q', 8, '2023-11-23 11:55:20', 'B1', 2, NULL, NULL, NULL),
(893, 'CNNMLN96R23I774W', 10, '2023-11-17 13:25:39', 'B3', 1, NULL, NULL, NULL),
(894, 'GRISVS02P06E392N', 5, '2023-03-14 11:26:25', 'B1', 8, NULL, NULL, NULL),
(895, 'CLMMCL53R68B838X', 5, '2023-05-25 17:55:32', 'B1', 8, NULL, NULL, NULL),
(896, 'SNGLDA78P46F877X', 1, '2023-06-22 15:55:41', 'A1', 9, NULL, NULL, NULL),
(897, 'GRFBLD74M18G557X', 8, '2023-02-20 11:57:26', 'B1', 2, NULL, NULL, NULL),
(898, 'LNTVVN89S55B632B', 13, '2023-02-27 15:59:39', 'B2', 2, NULL, NULL, NULL),
(899, 'LNGMRN87M42L949T', 3, '2023-11-08 13:45:39', 'B1', 2, NULL, NULL, NULL),
(900, 'BSCBRC50T55I726R', 11, '2023-09-06 11:13:23', 'A1', 2, NULL, NULL, NULL),
(901, 'TSSTTN59T01C578L', 11, '2023-11-01 14:16:06', 'A1', 13, NULL, NULL, NULL),
(902, 'CVZCLD77M68L117Y', 4, '2023-03-15 09:49:14', 'B1', 2, NULL, NULL, NULL),
(903, 'FRNTCR89H09D764K', 10, '2023-07-24 09:51:15', 'B1', 2, NULL, NULL, NULL),
(904, 'NCIRNO76E64C038I', 10, '2023-08-25 13:44:18', 'B1', 1, NULL, NULL, NULL),
(905, 'BRCSFN50H45D554N', 3, '2023-05-24 09:26:33', 'B1', 2, NULL, NULL, NULL),
(906, 'TMASRA52C59F856N', 9, '2023-05-30 17:11:54', 'B2', 14, NULL, NULL, NULL),
(907, 'PTRGLL57M54I962N', 6, '2023-06-26 16:20:43', 'B1', 4, NULL, NULL, NULL),
(908, 'SRBCLL02M42E621T', 13, '2023-09-19 15:31:22', 'B1', 1, NULL, NULL, NULL),
(909, 'DMGQMD10A04H340W', 4, '2023-12-21 14:20:10', 'B1', 2, NULL, NULL, NULL),
(910, 'CNSMRN89R59C694E', 14, '2023-02-23 16:24:14', 'B2', 3, NULL, NULL, NULL),
(911, 'LMNGRN10H14M023I', 15, '2023-10-04 12:30:06', 'B2', 5, NULL, NULL, NULL),
(912, 'CNGVTR80E06E875P', 15, '2023-07-10 14:38:56', 'B3', 5, NULL, NULL, NULL),
(913, 'CRVSVN10B43D024V', 4, '2023-07-06 16:26:33', 'B1', 2, NULL, NULL, NULL),
(914, 'CNDLRT08L47E496E', 2, '2023-03-23 14:18:40', 'B1', 8, NULL, NULL, NULL),
(915, 'CPRLBN62C08F648G', 1, '2023-09-21 16:43:05', 'A1', 3, NULL, NULL, NULL),
(916, 'TLLDRD16B23A072T', 11, '2023-07-04 10:44:24', 'A1', 14, NULL, NULL, NULL),
(917, 'LOITMS59A30M027V', 10, '2024-01-19 11:59:50', 'B1', 1, NULL, NULL, NULL),
(918, 'BRTSLL00B42C479J', 4, '2023-03-07 09:34:16', 'B1', 1, NULL, NULL, NULL),
(919, 'TZZVSC95P01C313N', 5, '2023-05-12 09:38:48', 'B1', 7, NULL, NULL, NULL),
(920, 'TDDCLI62L49C880K', 8, '2023-04-19 15:44:02', 'B1', 2, NULL, NULL, NULL),
(921, 'DSNMRT69B66D137W', 1, '2023-11-07 16:31:48', 'A1', 4, NULL, NULL, NULL),
(922, 'LBRGTN43T20E494C', 16, '2023-10-18 10:49:33', 'B1', 16, NULL, NULL, NULL),
(923, 'RFOSNO44H70B219M', 2, '2023-11-15 13:56:17', 'B1', 12, NULL, NULL, NULL),
(924, 'CSNTZN52D57H710M', 13, '2024-01-25 16:52:41', 'B1', 2, NULL, NULL, NULL),
(925, 'PRSMLA11T67L102Y', 9, '2023-12-06 09:58:02', 'B1', 13, NULL, NULL, NULL),
(926, 'SCHFNN99H04B408Y', 3, '2023-05-29 13:58:02', 'B1', 2, NULL, NULL, NULL),
(927, 'DCRFLV14E65M096M', 11, '2023-08-16 17:33:31', 'A1', 13, NULL, NULL, NULL),
(928, 'CLFNBL14L65B824H', 7, '2023-07-21 12:59:11', 'A1', 4, NULL, NULL, NULL),
(929, 'BSSVGL77P23C275K', 10, '2023-09-27 17:09:11', 'B2', 2, NULL, NULL, NULL),
(930, 'PTTGLL45E15L207X', 15, '2023-10-16 11:05:34', 'B1', 5, NULL, NULL, NULL),
(931, 'MSCMRT68E64H436F', 2, '2023-09-28 14:56:39', 'B3', 8, NULL, NULL, NULL),
(932, 'CRPMSM85L08E930H', 5, '2023-06-26 12:37:59', 'B1', 7, NULL, NULL, NULL),
(933, 'MRTVGL60M01H532B', 4, '2023-08-17 14:32:12', 'B2', 2, NULL, NULL, NULL),
(934, 'NNNMSS75L63A439L', 1, '2023-12-29 16:41:56', 'A1', 1, NULL, NULL, NULL),
(935, 'CVCSST49R25L424W', 16, '2023-07-21 12:20:16', 'B1', 16, NULL, NULL, NULL),
(936, 'DLSBNT11P25H220A', 1, '2023-12-01 16:53:19', 'A1', 4, NULL, NULL, NULL),
(937, 'BCCGND76A04F776J', 2, '2024-01-26 12:10:43', 'B1', 8, NULL, NULL, NULL),
(938, 'LMBLLN83C43C344A', 8, '2023-08-28 15:39:07', 'B1', 1, NULL, NULL, NULL),
(939, 'BRBMRZ79T67H424W', 12, '2023-10-25 14:08:54', 'B1', 10, NULL, NULL, NULL),
(940, 'BFFCRL08C70E922P', 12, '2023-02-28 12:38:44', 'B1', 10, NULL, NULL, NULL),
(941, 'MRSZNE86H24G083P', 3, '2024-02-01 12:38:30', 'B1', 2, NULL, NULL, NULL),
(942, 'RCIFMN52C18E899C', 3, '2023-05-04 17:09:44', 'B1', 2, NULL, NULL, NULL),
(943, 'CNISNT60A47B056X', 16, '2023-11-14 11:16:18', 'B1', 15, NULL, NULL, NULL),
(944, 'RSNBSL91M06F427C', 4, '2023-04-25 09:09:31', 'B1', 1, NULL, NULL, NULL),
(945, 'FDDGIA77R13H928H', 2, '2023-10-10 13:32:53', 'B3', 12, NULL, NULL, NULL),
(946, 'MSCMRT68E64H436F', 2, '2023-09-28 14:56:39', 'B4', 11, NULL, NULL, NULL),
(947, 'NNNMSS75L63A439L', 1, '2023-12-29 16:41:56', 'A2', 16, NULL, NULL, NULL),
(948, 'DLSBNT11P25H220A', 1, '2023-12-01 16:53:19', 'A2', 7, NULL, NULL, NULL),
(949, 'BCCGND76A04F776J', 2, '2024-01-26 12:10:43', 'B2', 7, NULL, NULL, NULL),
(950, 'LMBLLN83C43C344A', 8, '2023-08-28 15:39:07', 'B2', 2, NULL, NULL, NULL),
(951, 'CNISNT60A47B056X', 16, '2023-11-14 11:16:18', 'B2', 16, NULL, NULL, NULL),
(952, 'FDDGIA77R13H928H', 2, '2023-10-10 13:32:53', 'B4', 8, NULL, NULL, NULL),
(953, 'PSSVNI96C71F306S', 4, '2023-05-10 13:34:08', 'B2', 2, NULL, NULL, NULL),
(954, 'LSSSRA45E03L586H', 12, '2023-03-13 12:56:27', 'B1', 9, NULL, NULL, NULL),
(955, 'CNTLRD16E20F563Z', 13, '2024-01-03 15:58:30', 'B1', 2, NULL, NULL, NULL),
(956, 'PRLZOE03C70C273Y', 12, '2024-01-22 13:59:52', 'B1', 9, NULL, NULL, NULL),
(957, 'CPPLFA40L15A811Q', 15, '2023-05-12 15:00:32', 'B1', 6, NULL, NULL, NULL),
(958, 'DCURTI81R42C665H', 5, '2023-04-12 15:32:54', 'B1', 7, NULL, NULL, NULL),
(959, 'LMTLRC56C16H189X', 8, '2023-03-17 13:45:28', 'B1', 1, NULL, NULL, NULL),
(960, 'GHSGGN99H04I074T', 14, '2023-08-11 10:51:40', 'B1', 4, NULL, NULL, NULL),
(961, 'FLLLND16A28A249Q', 13, '2023-10-03 15:11:49', 'B1', 1, NULL, NULL, NULL),
(962, 'TCCNBR50E15B068K', 7, '2023-05-12 17:22:42', 'A1', 8, NULL, NULL, NULL),
(963, 'PDRGTR15H55F569G', 5, '2023-06-09 17:05:21', 'B1', 8, NULL, NULL, NULL),
(964, 'TRSMTT73S14G419L', 9, '2023-11-30 11:03:39', 'B1', 13, NULL, NULL, NULL),
(965, 'CVZCLD73E24G340M', 2, '2023-10-19 15:24:09', 'B1', 8, NULL, NULL, NULL),
(966, 'LZZNLN55E05F427Z', 6, '2023-04-18 12:28:09', 'B1', 3, NULL, NULL, NULL),
(967, 'FRRGUO54D13I721D', 14, '2023-06-29 17:06:47', 'B1', 3, NULL, NULL, NULL),
(968, 'PRRFRZ83H06F833Y', 13, '2023-10-18 09:30:53', 'B1', 2, NULL, NULL, NULL),
(969, 'DLLCPI73P24L200I', 11, '2023-08-04 14:35:35', 'A1', 6, NULL, NULL, NULL),
(970, 'DGNLNZ82T22I678Y', 15, '2024-01-10 16:33:22', 'B2', 6, NULL, NULL, NULL),
(971, 'CSTMBR44H66G538C', 11, '2023-09-27 10:26:15', 'A1', 6, NULL, NULL, NULL),
(972, 'MSCVTR13C62C658X', 16, '2024-02-08 12:33:08', 'B1', 15, NULL, NULL, NULL),
(973, 'MTLTLI61R49A757E', 15, '2023-08-31 15:50:45', 'B2', 6, NULL, NULL, NULL),
(974, 'FSCMRG48S24G561X', 13, '2024-01-04 11:07:22', 'B1', 2, NULL, NULL, NULL),
(975, 'CRLGLI41T02I782H', 9, '2023-04-24 11:05:56', 'B2', 14, NULL, NULL, NULL),
(976, 'DLTSFO16S50G992M', 16, '2023-06-28 16:27:14', 'B1', 16, NULL, NULL, NULL),
(977, 'NRDLDR98S02G486H', 6, '2023-12-19 16:59:24', 'B1', 3, NULL, NULL, NULL),
(978, 'NFSBLD80P07B131K', 3, '2023-06-21 13:09:36', 'B1', 2, NULL, NULL, NULL),
(979, 'LSALRD64P09L265T', 16, '2024-02-15 16:35:27', 'B1', 15, NULL, NULL, NULL),
(980, 'CPLMDA56P16A804F', 1, '2023-12-15 15:50:45', 'A1', 1, NULL, NULL, NULL),
(981, 'BRMLSN06M23D683I', 3, '2023-07-26 09:06:09', 'B1', 2, NULL, NULL, NULL),
(982, 'MRTVVN99P67E327X', 13, '2023-08-16 15:04:58', 'B1', 2, NULL, NULL, NULL),
(983, 'CRQDNL05T14G102Z', 11, '2023-03-28 11:20:04', 'A1', 3, NULL, NULL, NULL),
(984, 'BRTSVT53P13L112S', 4, '2024-01-24 15:34:43', 'B1', 2, NULL, NULL, NULL),
(985, 'MNSDNI46H46G335Y', 3, '2023-05-01 16:20:55', 'B1', 1, NULL, NULL, NULL),
(986, 'CRQDNL05T14G102Z', 11, '2023-03-28 11:20:04', 'A2', 8, NULL, NULL, NULL),
(987, 'MNSDNI46H46G335Y', 3, '2023-05-01 16:20:55', 'B2', 2, NULL, NULL, NULL),
(988, 'CNBLGR15T41E465M', 7, '2023-10-05 10:38:47', 'A1', 6, NULL, NULL, NULL),
(989, 'STRCML17P23E295Q', 8, '2023-10-09 14:01:28', 'B2', 1, NULL, NULL, NULL),
(990, 'GRNLRC77B54L305M', 15, '2023-04-14 10:31:06', 'B1', 6, NULL, NULL, NULL),
(991, 'BDLSVS90L09A557E', 1, '2023-04-18 11:58:21', 'A2', 1, NULL, NULL, NULL),
(992, 'DSGGLL64P27L357M', 11, '2023-07-10 10:06:48', 'A1', 9, NULL, NULL, NULL),
(993, 'ZPPLTR00R65H517T', 8, '2023-09-07 12:22:13', 'B1', 2, NULL, NULL, NULL),
(994, 'FLCFBA49S05E995U', 3, '2023-12-13 15:43:12', 'B1', 2, NULL, NULL, NULL),
(995, 'TLLFMN77H57D428F', 13, '2023-10-11 11:41:08', 'B1', 2, NULL, NULL, NULL),
(996, 'DNNNLM04D29C528K', 3, '2023-03-03 11:10:14', 'B3', 1, NULL, NULL, NULL),
(997, 'CRGRCL96H03A059S', 4, '2023-09-25 12:42:22', 'B1', 1, NULL, NULL, NULL),
(998, 'CPRGNI01A28H976G', 6, '2023-10-31 16:42:58', 'B1', 3, NULL, NULL, NULL),
(999, 'BRMLDA79C21F414G', 1, '2023-12-05 13:08:46', 'A1', 1, NULL, NULL, NULL),
(1000, 'BNTFLV74R05E626F', 12, '2024-01-25 14:14:30', 'B2', 9, NULL, NULL, NULL),
(1001, 'LLLMNN76T54G291F', 3, '2023-07-13 14:06:54', 'B1', 2, NULL, NULL, NULL),
(1002, 'BTTTCR56B03L743J', 2, '2023-11-16 09:52:22', 'B1', 8, NULL, NULL, NULL),
(1003, 'CSBVLM73M64B180T', 11, '2023-06-08 12:56:57', 'A1', 3, NULL, NULL, NULL),
(1004, 'GRNSDR92A60C165Q', 2, '2023-12-20 10:21:22', 'B1', 12, NULL, NULL, NULL),
(1005, 'PLVTLL98C26H581H', 8, '2023-10-30 16:33:44', 'B2', 1, NULL, NULL, NULL),
(1006, 'GRTDLM64B25A449D', 6, '2023-11-24 14:26:09', 'B1', 4, NULL, NULL, NULL),
(1007, 'MRNSRN85L59F887P', 3, '2023-06-09 15:55:26', 'B1', 1, NULL, NULL, NULL),
(1008, 'BRCSTN79D56G529G', 4, '2023-07-03 10:17:14', 'B1', 1, NULL, NULL, NULL),
(1009, 'DNCGRM95E15C456B', 5, '2023-12-19 16:27:20', 'B2', 8, NULL, NULL, NULL),
(1010, 'FLRCRI47D04D103O', 5, '2024-01-25 16:23:11', 'B2', 8, NULL, NULL, NULL),
(1011, 'CRCVLR95A10L675O', 5, '2024-02-12 09:02:46', 'B1', 7, NULL, NULL, NULL),
(1012, 'ZNASTN62B44G698F', 14, '2023-12-22 15:56:17', 'B1', 4, NULL, NULL, NULL),
(1013, 'CRTMIA03A45B430Z', 10, '2023-03-01 16:23:36', 'B1', 2, NULL, NULL, NULL),
(1014, 'CRNGZZ07S12F262N', 12, '2023-08-02 09:09:33', 'B1', 10, NULL, NULL, NULL),
(1015, 'DFLMIA60M51M031X', 15, '2023-03-20 09:47:15', 'B1', 5, NULL, NULL, NULL),
(1016, 'MGLRCC40A24D269E', 14, '2024-01-23 10:46:26', 'B1', 4, NULL, NULL, NULL),
(1017, 'PGZTLD95A53E045P', 13, '2024-02-14 16:14:56', 'B1', 2, NULL, NULL, NULL),
(1018, 'GNTGTN83C48A745D', 12, '2023-11-01 17:05:26', 'B1', 10, NULL, NULL, NULL),
(1019, 'DNDLLD56P22A305Q', 9, '2023-04-28 12:08:55', 'B4', 14, NULL, NULL, NULL),
(1020, 'CHPTLI04E69D022U', 4, '2023-05-26 17:59:26', 'B1', 1, NULL, NULL, NULL),
(1021, 'GBBLND03T12C740U', 15, '2023-11-08 09:57:21', 'B3', 6, NULL, NULL, NULL),
(1022, 'VGRYLN88D53E079O', 12, '2023-12-22 13:02:06', 'B1', 10, NULL, NULL, NULL),
(1023, 'SBTPIO55C03B152M', 12, '2023-08-21 14:30:30', 'B1', 9, NULL, NULL, NULL),
(1024, 'GRBWND62P41F352T', 15, '2023-04-10 17:06:15', 'B2', 5, NULL, NULL, NULL),
(1025, 'CMPDNL90M44H425H', 12, '2023-07-28 14:52:41', 'B2', 10, NULL, NULL, NULL),
(1026, 'SCHSRG73C19F110N', 7, '2023-12-27 12:24:28', 'A1', 2, NULL, NULL, NULL),
(1027, 'ZCCNDR99D10F067F', 2, '2023-12-07 14:33:11', 'B1', 8, NULL, NULL, NULL),
(1028, 'MSSSRA95D12F513J', 8, '2023-03-06 14:17:32', 'B1', 1, NULL, NULL, NULL),
(1029, 'DCSBDT01S12I238Z', 9, '2023-02-21 15:18:57', 'B1', 13, NULL, NULL, NULL),
(1030, 'FRNTLL81S02M116T', 14, '2024-01-11 11:09:06', 'B1', 3, NULL, NULL, NULL),
(1031, 'GNOCLN85S57B145E', 9, '2023-05-24 13:25:10', 'B1', 13, NULL, NULL, NULL),
(1032, 'VNDCRN59A09L768U', 8, '2023-03-22 14:37:41', 'B1', 2, NULL, NULL, NULL),
(1033, 'BRGFDN93C15I558P', 8, '2024-01-15 15:58:07', 'B1', 2, NULL, NULL, NULL),
(1034, 'PLTGST49E04F405Y', 1, '2024-01-19 09:09:13', 'A1', 9, NULL, NULL, NULL),
(1035, 'FRLNLT54S05L201Y', 9, '2023-12-28 15:08:28', 'B1', 13, NULL, NULL, NULL),
(1036, 'GVRGND13B15A107D', 10, '2023-05-17 09:31:45', 'B1', 2, NULL, NULL, NULL),
(1037, 'BLGRLN90T46H540J', 10, '2023-07-21 09:11:28', 'B1', 1, NULL, NULL, NULL),
(1038, 'DVCNLT54T05L483S', 2, '2023-08-25 15:21:50', 'B1', 8, NULL, NULL, NULL),
(1039, 'CSGSLN79P50L829F', 1, '2023-06-07 11:50:18', 'A2', 12, NULL, NULL, NULL),
(1040, 'CVLLDN04M03D324I', 2, '2024-01-18 09:24:34', 'B2', 11, NULL, NULL, NULL),
(1041, 'VCCTRS50R64C694D', 2, '2024-01-15 12:16:45', 'B1', 12, NULL, NULL, NULL),
(1042, 'GLNVVN64S63A191N', 6, '2023-12-04 14:46:40', 'B1', 4, NULL, NULL, NULL),
(1043, 'GRMGNT56L24E973M', 1, '2023-07-13 10:40:14', 'A1', 6, NULL, NULL, NULL),
(1044, 'CNSLGO86C47C343L', 15, '2023-03-01 16:10:39', 'B2', 5, NULL, NULL, NULL),
(1045, 'BNFLNZ65R54M002M', 7, '2024-01-31 14:53:10', 'A1', 10, NULL, NULL, NULL),
(1046, 'GNTSNT11E65E429I', 8, '2023-12-12 12:10:47', 'B1', 1, NULL, NULL, NULL),
(1047, 'BVSGTV07B11G686X', 7, '2023-12-07 12:13:29', 'A1', 9, NULL, NULL, NULL),
(1048, 'ZNGRMI75C49H014I', 5, '2023-09-06 17:09:48', 'B1', 7, NULL, NULL, NULL),
(1049, 'GNCLNI92S59I322Z', 7, '2024-01-11 10:31:58', 'A1', 15, NULL, NULL, NULL),
(1050, 'DMRLRD54E31H114R', 3, '2023-03-24 10:58:13', 'B3', 1, NULL, NULL, NULL),
(1051, 'DEIMRZ16M55C354K', 12, '2023-08-04 15:17:20', 'B1', 10, NULL, NULL, NULL),
(1052, 'CMBPML69A51B006E', 11, '2023-11-08 16:16:42', 'A2', 2, NULL, NULL, NULL),
(1053, 'GRTMLA16C47E015J', 9, '2023-09-13 13:43:21', 'B2', 13, NULL, NULL, NULL),
(1054, 'NSLFRC92T30G324S', 9, '2023-12-15 14:46:18', 'B1', 14, NULL, NULL, NULL),
(1055, 'BRBVVN75A49G050S', 7, '2023-10-09 11:26:07', 'A1', 14, NULL, NULL, NULL),
(1056, 'DSPNDA88T55C732E', 7, '2023-02-28 14:16:17', 'A2', 13, NULL, NULL, NULL),
(1057, 'MRNDNC05S07E092E', 16, '2023-05-04 09:11:15', 'B1', 15, NULL, NULL, NULL),
(1058, 'BNFFST83H50F458P', 8, '2023-11-17 09:31:33', 'B1', 1, NULL, NULL, NULL),
(1059, 'DTTDGS82E63F214J', 12, '2024-01-03 15:33:29', 'B2', 10, NULL, NULL, NULL),
(1060, 'CRRGTA61T64L886S', 8, '2023-06-09 13:09:45', 'B1', 1, NULL, NULL, NULL),
(1061, 'BGZLHN79D06D509Z', 10, '2024-01-03 09:28:57', 'B1', 2, NULL, NULL, NULL),
(1062, 'ZZRLND85T31E153R', 15, '2023-07-26 13:09:10', 'B1', 6, NULL, NULL, NULL),
(1063, 'DGRLNE11E66I785D', 2, '2023-07-03 09:14:35', 'B1', 7, NULL, NULL, NULL),
(1064, 'BRZSLL17T47F486W', 8, '2024-01-16 16:37:58', 'B1', 1, NULL, NULL, NULL),
(1065, 'DROCST91M61L220D', 5, '2023-03-03 15:54:27', 'B1', 7, NULL, NULL, NULL),
(1066, 'CSTLGU71H16C457L', 16, '2023-05-17 15:44:19', 'B1', 16, NULL, NULL, NULL),
(1067, 'VTLSLL80A66B813F', 13, '2023-11-14 17:44:44', 'B1', 1, NULL, NULL, NULL),
(1068, 'GRGSDI13B56B813B', 9, '2023-07-04 15:33:00', 'B1', 14, NULL, NULL, NULL),
(1069, 'BRCCSR91C18A177U', 10, '2023-10-06 16:02:45', 'B1', 1, NULL, NULL, NULL),
(1070, 'SCRNNA05M71B582J', 9, '2023-07-06 16:59:34', 'B2', 13, NULL, NULL, NULL),
(1071, 'FDDGDE91B04H926M', 5, '2023-05-25 14:08:07', 'B1', 8, NULL, NULL, NULL),
(1072, 'GMBPRI77A31C768A', 5, '2023-09-05 17:14:12', 'B3', 8, NULL, NULL, NULL),
(1073, 'CSSSFO85T42G267F', 10, '2023-12-20 11:38:27', 'B1', 2, NULL, NULL, NULL),
(1074, 'FRNMRG78D65I261Q', 12, '2023-05-10 14:12:06', 'B3', 10, NULL, NULL, NULL),
(1075, 'CRNLFA11D26D412F', 7, '2023-11-02 17:34:20', 'A1', 6, NULL, NULL, NULL),
(1076, 'GHRLRI09D27F217R', 5, '2023-11-24 13:43:58', 'B2', 8, NULL, NULL, NULL),
(1077, 'BRBVVN75A49G050S', 7, '2023-10-09 11:26:07', 'A2', 15, NULL, NULL, NULL),
(1078, 'DSPNDA88T55C732E', 7, '2023-02-28 14:16:17', 'A3', 10, NULL, NULL, NULL),
(1079, 'ZZRLND85T31E153R', 15, '2023-07-26 13:09:10', 'B2', 5, NULL, NULL, NULL),
(1080, 'DGRLNE11E66I785D', 2, '2023-07-03 09:14:35', 'B2', 12, NULL, NULL, NULL),
(1081, 'DROCST91M61L220D', 5, '2023-03-03 15:54:27', 'B2', 8, NULL, NULL, NULL),
(1082, 'GRGSDI13B56B813B', 9, '2023-07-04 15:33:00', 'B2', 13, NULL, NULL, NULL),
(1083, 'CRNLFA11D26D412F', 7, '2023-11-02 17:34:20', 'A2', 2, NULL, NULL, NULL),
(1084, 'GHRLRI09D27F217R', 5, '2023-11-24 13:43:58', 'B3', 7, NULL, NULL, NULL),
(1085, 'LCSLSN41C59E903X', 13, '2023-11-13 16:07:30', 'B1', 1, NULL, NULL, NULL),
(1086, 'GRNTLL50D07H460Q', 15, '2023-11-08 09:28:13', 'B4', 5, NULL, NULL, NULL),
(1087, 'BRGFRZ14L23H481H', 10, '2023-05-15 09:02:23', 'B1', 2, NULL, NULL, NULL),
(1088, 'CMNDZN78P50H648Z', 1, '2023-03-09 17:07:38', 'A1', 11, NULL, NULL, NULL),
(1089, 'BNTMDE63H06F220J', 6, '2023-10-03 12:09:50', 'B1', 4, NULL, NULL, NULL),
(1090, 'CRNRSL75T59F004D', 8, '2023-11-27 12:32:51', 'B1', 2, NULL, NULL, NULL),
(1091, 'CRTRSN05B51D333F', 4, '2024-01-17 15:12:56', 'B2', 2, NULL, NULL, NULL),
(1092, 'CTTSRG56S02B128Y', 9, '2023-05-12 17:32:32', 'B1', 14, NULL, NULL, NULL),
(1093, 'CRTCMN81P17E610B', 11, '2023-11-24 16:15:12', 'A1', 10, NULL, NULL, NULL),
(1094, 'BSCMNN80T67C855H', 7, '2023-11-27 11:02:03', 'A1', 1, NULL, NULL, NULL),
(1095, 'CPPLLL96A52H269W', 14, '2023-05-04 12:26:05', 'B1', 3, NULL, NULL, NULL),
(1096, 'FRRMRA66H62H910H', 4, '2023-05-12 11:42:02', 'B1', 1, NULL, NULL, NULL),
(1097, 'CGGPNI95P64L188V', 3, '2023-05-11 15:15:19', 'B1', 2, NULL, NULL, NULL),
(1098, 'BRLFRZ44B11H258F', 4, '2023-03-10 10:38:35', 'B1', 1, NULL, NULL, NULL),
(1099, 'CMTMRC94R71F795H', 5, '2023-06-09 15:36:37', 'B2', 8, NULL, NULL, NULL),
(1100, 'BRTCLO70M58I493N', 6, '2024-01-17 10:17:07', 'B1', 3, NULL, NULL, NULL),
(1101, 'GRFPMR60L63A394W', 1, '2023-03-15 12:02:04', 'A1', 7, NULL, NULL, NULL),
(1102, 'DCILCL87T10C883D', 3, '2023-11-28 15:52:18', 'B1', 1, NULL, NULL, NULL),
(1103, 'GRLMND48B67F017F', 7, '2023-12-01 16:13:13', 'A3', 8, NULL, NULL, NULL),
(1104, 'FRNDNL68A03F004A', 16, '2023-03-23 09:31:05', 'B1', 15, NULL, NULL, NULL),
(1105, 'DLLLVC59A09B924S', 4, '2023-04-21 10:29:28', 'B2', 1, NULL, NULL, NULL),
(1106, 'GRRLSI01C71A231P', 14, '2023-10-03 14:51:48', 'B2', 3, NULL, NULL, NULL),
(1107, 'DCRGTV46B27G234L', 2, '2023-10-10 10:10:29', 'B1', 11, NULL, NULL, NULL),
(1108, 'CRTGDE42P04E995T', 15, '2023-11-02 10:45:50', 'B1', 6, NULL, NULL, NULL),
(1109, 'DNNBNR75B06B024Y', 8, '2023-12-01 13:59:57', 'B1', 1, NULL, NULL, NULL),
(1110, 'CRNLFA11D26D412F', 7, '2023-11-02 17:34:20', 'A3', 11, NULL, NULL, NULL),
(1111, 'LCSLSN41C59E903X', 13, '2023-11-13 16:07:30', 'B2', 2, NULL, NULL, NULL),
(1112, 'BRGFRZ14L23H481H', 10, '2023-05-15 09:02:23', 'B2', 1, NULL, NULL, NULL),
(1113, 'CMNDZN78P50H648Z', 1, '2023-03-09 17:07:38', 'A2', 6, NULL, NULL, NULL),
(1114, 'BNTMDE63H06F220J', 6, '2023-10-03 12:09:50', 'B2', 3, NULL, NULL, NULL),
(1115, 'CRNRSL75T59F004D', 8, '2023-11-27 12:32:51', 'B2', 1, NULL, NULL, NULL),
(1116, 'CRTCMN81P17E610B', 11, '2023-11-24 16:15:12', 'A2', 1, NULL, NULL, NULL),
(1117, 'BSCMNN80T67C855H', 7, '2023-11-27 11:02:03', 'A2', 14, NULL, NULL, NULL),
(1118, 'CMTMRC94R71F795H', 5, '2023-06-09 15:36:37', 'B3', 7, NULL, NULL, NULL),
(1119, 'GRFPMR60L63A394W', 1, '2023-03-15 12:02:04', 'A2', 6, NULL, NULL, NULL),
(1120, 'GRLMND48B67F017F', 7, '2023-12-01 16:13:13', 'A4', 1, NULL, NULL, NULL),
(1121, 'GRRLSI01C71A231P', 14, '2023-10-03 14:51:48', 'B3', 4, NULL, NULL, NULL),
(1122, 'DCRGTV46B27G234L', 2, '2023-10-10 10:10:29', 'B2', 8, NULL, NULL, NULL),
(1123, 'VDVLVC44R44F639U', 14, '2023-12-01 13:16:24', 'B2', 4, NULL, NULL, NULL),
(1124, 'MTTRMN13C70F006G', 11, '2023-07-25 09:01:58', 'A1', 16, NULL, NULL, NULL),
(1125, 'NCRFDL52E24H486X', 1, '2023-03-17 12:31:01', 'A1', 4, NULL, NULL, NULL),
(1126, 'CRRPRZ65S66H245E', 5, '2024-01-26 17:19:19', 'B1', 8, NULL, NULL, NULL),
(1127, 'TRNCRL13S17C347F', 5, '2024-02-13 14:30:24', 'B1', 8, NULL, NULL, NULL),
(1128, 'BRGSRG55D30F509C', 12, '2023-07-05 17:57:37', 'B1', 10, NULL, NULL, NULL),
(1129, 'CPPCMN62P26D952X', 1, '2023-09-07 16:10:46', 'A1', 13, NULL, NULL, NULL),
(1130, 'STFRRT76T44F407N', 3, '2023-05-22 17:37:55', 'B1', 1, NULL, NULL, NULL),
(1131, 'GFFMLN43L27D369E', 6, '2023-05-16 12:39:20', 'B2', 4, NULL, NULL, NULL),
(1132, 'RDVNBL84S43C919G', 6, '2024-02-08 12:11:31', 'B2', 3, NULL, NULL, NULL),
(1133, 'CMNDZN78P50H648Z', 1, '2023-03-09 17:07:38', 'A3', 2, NULL, NULL, NULL),
(1134, 'CRTCMN81P17E610B', 11, '2023-11-24 16:15:12', 'A3', 6, NULL, NULL, NULL),
(1135, 'BSCMNN80T67C855H', 7, '2023-11-27 11:02:03', 'A3', 7, NULL, NULL, NULL),
(1136, 'GRFPMR60L63A394W', 1, '2023-03-15 12:02:04', 'A3', 5, NULL, NULL, NULL),
(1137, 'DCRGTV46B27G234L', 2, '2023-10-10 10:10:29', 'B3', 12, NULL, NULL, NULL),
(1138, 'MTTRMN13C70F006G', 11, '2023-07-25 09:01:58', 'A2', 12, NULL, NULL, NULL),
(1139, 'NCRFDL52E24H486X', 1, '2023-03-17 12:31:01', 'A2', 10, NULL, NULL, NULL),
(1140, 'CRRPRZ65S66H245E', 5, '2024-01-26 17:19:19', 'B2', 7, NULL, NULL, NULL),
(1141, 'CPPCMN62P26D952X', 1, '2023-09-07 16:10:46', 'A2', 2, NULL, NULL, NULL),
(1142, 'STFRRT76T44F407N', 3, '2023-05-22 17:37:55', 'B2', 2, NULL, NULL, NULL),
(1143, 'GFFMLN43L27D369E', 6, '2023-05-16 12:39:20', 'B3', 3, NULL, NULL, NULL),
(1144, 'RGGSNO13B52A676B', 14, '2023-06-29 15:25:13', 'B1', 3, NULL, NULL, NULL),
(1145, 'GRNCDD89E01H945Q', 12, '2024-02-02 16:14:57', 'B1', 10, NULL, NULL, NULL),
(1146, 'LRILSI98L56L433Y', 3, '2024-01-11 09:45:56', 'B1', 2, NULL, NULL, NULL),
(1147, 'TRBMLD06A54F207V', 6, '2023-11-13 09:01:47', 'B1', 4, NULL, NULL, NULL),
(1148, 'CHRRLB02C54C311W', 5, '2023-12-05 12:17:15', 'B1', 8, NULL, NULL, NULL),
(1149, 'SSNLCA69L19E878J', 2, '2024-02-14 12:31:56', 'B1', 7, NULL, NULL, NULL),
(1150, 'DLLSND86H22L075O', 11, '2023-06-19 12:21:47', 'A1', 1, NULL, NULL, NULL),
(1151, 'CPTGTA40A66A713G', 2, '2023-03-15 11:31:46', 'B2', 12, NULL, NULL, NULL),
(1152, 'CNFNRN09L58H493F', 4, '2023-08-08 14:11:12', 'B1', 1, NULL, NULL, NULL),
(1153, 'DLMSDR85L43E066N', 12, '2023-10-24 16:06:59', 'B3', 10, NULL, NULL, NULL),
(1154, 'CRMFST49D27B248T', 14, '2023-03-24 17:44:11', 'B1', 4, NULL, NULL, NULL),
(1155, 'FRRSVT68C17G146A', 4, '2023-09-19 14:29:23', 'B1', 1, NULL, NULL, NULL),
(1156, 'MTTRMN13C70F006G', 11, '2023-07-25 09:01:58', 'A3', 15, NULL, NULL, NULL),
(1157, 'NTNGTT09S67C120S', 14, '2023-11-21 12:32:56', 'B1', 4, NULL, NULL, NULL),
(1158, 'DDTTMS88L61L295Y', 11, '2023-11-06 10:14:12', 'A1', 1, NULL, NULL, NULL),
(1159, 'FSNBLD09T05F701O', 4, '2023-11-21 10:06:57', 'B1', 1, NULL, NULL, NULL),
(1160, 'GZZVGN83B10E258N', 10, '2023-02-20 14:44:07', 'B3', 1, NULL, NULL, NULL);

--
-- Trigger `pp`
--
DROP TRIGGER IF EXISTS `AggiornaStipendioEQuota`;
DELIMITER $$
CREATE TRIGGER `AggiornaStipendioEQuota` BEFORE UPDATE ON `pp` FOR EACH ROW trig: BEGIN
	IF (SELECT Importo_Fattura
        FROM pp
        WHERE ID_PP=new.ID_PP) IS NOT NULL THEN
        	LEAVE trig;
    END IF;
    
	UPDATE specialisti
    SET Quota=Quota+new.Importo_Fattura, Stipendio=2500+Quota*0.05
    WHERE ID=new.Specialista;
    
    UPDATE assistenti
    SET Quota=Quota+new.Importo_Fattura, Stipendio=1800+Quota*0.05
    WHERE ID=new.Assistente;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `pp_INSAbilitazioneRichiesta`;
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
                        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Abilitazione Richiesta';
     ELSEIF tip='Controllo'
     AND EXISTS (SELECT *
                 FROM assistenti
                 WHERE assistenti.ID=new.Specialista) THEN
                 	DELETE FROM pp
                    WHERE ID_PP=new.ID_PP;
                    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Abilitazione Richiesta';
     ELSEIF tip='Trattamento'
     AND EXISTS (SELECT *
                 FROM specialisti
                 WHERE specialisti.ID=new.Assistente) THEN
                 	DELETE FROM pp
                    WHERE ID_PP=new.ID_PP;
                    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Abilitazione Richiesta';
     ELSEIF tip='Controllo'
     AND new.Assistente IS NOT NULL THEN
     	DELETE FROM pp
        WHERE ID_PP=new.ID_PP;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Abilitazione Richiesta';
     END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `pp_INSPrenotazioneDalPassato`;
DELIMITER $$
CREATE TRIGGER `pp_INSPrenotazioneDalPassato` BEFORE INSERT ON `pp` FOR EACH ROW BEGIN
	IF new.Data<CURRENT_TIMESTAMP THEN
    	SET new.Data=CURRENT_TIMESTAMP;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data passata';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `pp_INSStessoLuogoEOra`;
DELIMITER $$
CREATE TRIGGER `pp_INSStessoLuogoEOra` AFTER INSERT ON `pp` FOR EACH ROW BEGIN
	IF EXISTS (SELECT *
              FROM pp
              WHERE Stanza=new.Stanza
              AND TIME_TO_SEC(ABS(TIMEDIFF(Data, new.Data)))<3600
              AND ID_PP<>new.ID_PP) THEN
        DELETE FROM pp
        WHERE ID_PP=new.ID_PP;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stanza occupata';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `pp_INSStessoMedEOra`;
DELIMITER $$
CREATE TRIGGER `pp_INSStessoMedEOra` AFTER INSERT ON `pp` FOR EACH ROW BEGIN
	IF EXISTS (SELECT *
              FROM pp
              WHERE Specialista=new.Specialista
              AND TIME_TO_SEC(ABS(TIMEDIFF(Data, new.Data)))<3600
              AND ID_PP<>new.ID_PP) THEN
        DELETE FROM pp
        WHERE ID_PP=new.ID_PP;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Medico occupato';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `pp_UPDAbilitazioneRichiesta`;
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
                        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Abilitazione Richiesta';
     ELSEIF tip='Controllo'
     AND EXISTS (SELECT *
                 FROM assistenti
                 WHERE assistenti.ID=new.Specialista) THEN
                 	SET new.Specialista=old.Specialista;
                    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Abilitazione Richiesta';
     END IF;
     IF tip='Trattamento'
     AND EXISTS (SELECT *
                 FROM specialisti
                 WHERE specialisti.ID=new.Assistente) THEN
                 	SET new.Assistente=old.Assistente;
                    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Abilitazione Richiesta';
     ELSEIF tip='Controllo'
     AND new.Assistente IS NOT NULL THEN
     SET new.Assistente=old.Assistente;
     SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Abilitazione Richiesta';
     END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `pp_UPDPrenotazioneDalPassato`;
DELIMITER $$
CREATE TRIGGER `pp_UPDPrenotazioneDalPassato` BEFORE UPDATE ON `pp` FOR EACH ROW BEGIN
	IF old.Data<>new.Data
    AND new.Data<CURRENT_TIMESTAMP THEN
    	SET new.Data=CURRENT_TIMESTAMP;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data passata';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `pp_UPDStessoLuogoEOra`;
DELIMITER $$
CREATE TRIGGER `pp_UPDStessoLuogoEOra` AFTER UPDATE ON `pp` FOR EACH ROW BEGIN
	IF EXISTS (SELECT *
              FROM pp
              WHERE Stanza=new.Stanza
              AND TIME_TO_SEC(ABS(TIMEDIFF(Data, new.Data)))<3600
              AND ID_PP<>new.ID_PP) THEN
        DELETE FROM pp
        WHERE ID_PP=new.ID_PP;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stanza occupata';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `pp_UPDStessoMedEOra`;
DELIMITER $$
CREATE TRIGGER `pp_UPDStessoMedEOra` AFTER UPDATE ON `pp` FOR EACH ROW BEGIN
	IF EXISTS (SELECT *
              FROM pp
              WHERE Specialista=new.Specialista
              AND TIME_TO_SEC(ABS(TIMEDIFF(Data, new.Data)))<3600
              AND ID_PP<>new.ID_PP) THEN
        DELETE FROM pp
        WHERE ID_PP=new.ID_PP;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Medico occupato';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struttura stand-in per le viste `prenotazioni`
-- (Vedi sotto per la vista effettiva)
--
DROP VIEW IF EXISTS `prenotazioni`;
CREATE TABLE IF NOT EXISTS `prenotazioni` (
`Prenotazione` int(8)
,`Paziente` varchar(16)
,`Codice_Prestazione` int(8)
,`Data` datetime
,`Stanza` enum('A1','A2','A3','A4','B1','B2','B3','B4')
,`Specialista` int(8)
);

-- --------------------------------------------------------

--
-- Struttura stand-in per le viste `prestazionieffetttuate`
-- (Vedi sotto per la vista effettiva)
--
DROP VIEW IF EXISTS `prestazionieffetttuate`;
CREATE TABLE IF NOT EXISTS `prestazionieffetttuate` (
`Prestazione` int(8)
,`Paziente` varchar(16)
,`Codice_Prestazione` int(8)
,`Data` datetime
,`Stanza` enum('A1','A2','A3','A4','B1','B2','B3','B4')
,`Specialista` int(8)
,`Assistente` int(8)
,`Esito` enum('OK','NECESSITA CONTROLLO','NECESSITA TRATTAMENTO')
,`Importo_Fattura` float
);

-- --------------------------------------------------------

--
-- Struttura stand-in per le viste `specialisti`
-- (Vedi sotto per la vista effettiva)
--
DROP VIEW IF EXISTS `specialisti`;
CREATE TABLE IF NOT EXISTS `specialisti` (
`ID` int(8)
,`Cognome` varchar(30)
,`Nome` varchar(30)
,`Recapito` varchar(13)
,`E-mail` varchar(50)
,`Specializzazione` varchar(30)
,`Stipendio` float
,`Quota` float
);

-- --------------------------------------------------------

--
-- Struttura stand-in per le viste `trattamenti`
-- (Vedi sotto per la vista effettiva)
--
DROP VIEW IF EXISTS `trattamenti`;
CREATE TABLE IF NOT EXISTS `trattamenti` (
`Codice_Prestazione` int(8)
,`Nome_Prestazione` varchar(30)
,`Costo` float
);

-- --------------------------------------------------------

--
-- Struttura della tabella `turni`
--
-- Creazione: Feb 16, 2023 alle 10:15
-- Ultimo aggiornamento: Feb 25, 2023 alle 16:17
--

DROP TABLE IF EXISTS `turni`;
CREATE TABLE IF NOT EXISTS `turni` (
  `ID_Personale` int(8) NOT NULL,
  `Giorno` enum('lunedì','martedì','mercoledì','giovedì','venerdì') NOT NULL,
  UNIQUE KEY `Turni_fk1` (`ID_Personale`,`Giorno`),
  KEY `ID_Personale` (`ID_Personale`,`Giorno`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- RELAZIONI PER TABELLA `turni`:
--   `ID_Personale`
--       `personale` -> `ID`
--

--
-- Svuota la tabella prima dell'inserimento `turni`
--

TRUNCATE TABLE `turni`;
--
-- Dump dei dati per la tabella `turni`
--

INSERT INTO `turni` (`ID_Personale`, `Giorno`) VALUES
(1, 'lunedì'),
(1, 'martedì'),
(1, 'venerdì'),
(2, 'lunedì'),
(2, 'mercoledì'),
(2, 'giovedì'),
(3, 'martedì'),
(3, 'mercoledì'),
(3, 'giovedì'),
(4, 'lunedì'),
(4, 'martedì'),
(4, 'venerdì'),
(5, 'lunedì'),
(5, 'martedì'),
(5, 'mercoledì'),
(6, 'mercoledì'),
(6, 'giovedì'),
(6, 'venerdì'),
(7, 'lunedì'),
(7, 'mercoledì'),
(7, 'venerdì'),
(8, 'martedì'),
(8, 'giovedì'),
(8, 'venerdì'),
(9, 'lunedì'),
(9, 'giovedì'),
(9, 'venerdì'),
(10, 'martedì'),
(10, 'mercoledì'),
(10, 'venerdì'),
(11, 'martedì'),
(11, 'giovedì'),
(11, 'venerdì'),
(12, 'lunedì'),
(12, 'martedì'),
(12, 'mercoledì'),
(13, 'martedì'),
(13, 'mercoledì'),
(13, 'giovedì'),
(14, 'lunedì'),
(14, 'martedì'),
(14, 'venerdì'),
(15, 'lunedì'),
(15, 'martedì'),
(15, 'giovedì'),
(16, 'martedì'),
(16, 'mercoledì'),
(16, 'venerdì'),
(17, 'lunedì'),
(17, 'martedì'),
(17, 'giovedì'),
(17, 'venerdì'),
(18, 'lunedì'),
(18, 'mercoledì'),
(18, 'giovedì'),
(18, 'venerdì'),
(19, 'lunedì'),
(19, 'martedì'),
(19, 'mercoledì'),
(19, 'giovedì'),
(19, 'venerdì'),
(20, 'lunedì'),
(20, 'martedì'),
(20, 'mercoledì'),
(20, 'giovedì'),
(20, 'venerdì'),
(21, 'lunedì'),
(21, 'martedì'),
(21, 'mercoledì'),
(21, 'giovedì'),
(21, 'venerdì'),
(22, 'lunedì'),
(22, 'martedì'),
(22, 'mercoledì'),
(22, 'giovedì'),
(22, 'venerdì'),
(23, 'lunedì'),
(23, 'martedì'),
(23, 'mercoledì'),
(23, 'giovedì'),
(23, 'venerdì'),
(24, 'lunedì'),
(24, 'martedì'),
(24, 'mercoledì'),
(24, 'giovedì'),
(24, 'venerdì'),
(25, 'lunedì'),
(25, 'martedì'),
(25, 'mercoledì'),
(25, 'giovedì'),
(25, 'venerdì'),
(26, 'lunedì'),
(26, 'martedì'),
(26, 'mercoledì'),
(26, 'giovedì'),
(26, 'venerdì');

-- --------------------------------------------------------

--
-- Struttura per vista `assistenti`
--
DROP TABLE IF EXISTS `assistenti`;

DROP VIEW IF EXISTS `assistenti`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `assistenti`  AS SELECT `personale`.`ID` AS `ID`, `personale`.`Cognome` AS `Cognome`, `personale`.`Nome` AS `Nome`, `personale`.`Recapito` AS `Recapito`, `personale`.`E-mail` AS `E-mail`, `personale`.`Stipendio` AS `Stipendio`, `personale`.`Quota` AS `Quota` FROM `personale` WHERE `personale`.`Specializzazione` is null WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Struttura per vista `controlli`
--
DROP TABLE IF EXISTS `controlli`;

DROP VIEW IF EXISTS `controlli`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `controlli`  AS SELECT `listaprestazioni`.`Codice_Prestazione` AS `Codice_Prestazione`, `listaprestazioni`.`Nome_Prestazione` AS `Nome_Prestazione`, `listaprestazioni`.`Costo` AS `Costo` FROM `listaprestazioni` WHERE `listaprestazioni`.`Tipo_Prestazione` = 'Controllo' WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Struttura per vista `prenotazioni`
--
DROP TABLE IF EXISTS `prenotazioni`;

DROP VIEW IF EXISTS `prenotazioni`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `prenotazioni`  AS SELECT `pp`.`ID_PP` AS `Prenotazione`, `pp`.`Paziente` AS `Paziente`, `pp`.`Codice_Prestazione` AS `Codice_Prestazione`, `pp`.`Data` AS `Data`, `pp`.`Stanza` AS `Stanza`, `pp`.`Specialista` AS `Specialista` FROM `pp` WHERE `pp`.`Importo_Fattura` is null WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Struttura per vista `prestazionieffetttuate`
--
DROP TABLE IF EXISTS `prestazionieffetttuate`;

DROP VIEW IF EXISTS `prestazionieffetttuate`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `prestazionieffetttuate`  AS SELECT `pp`.`ID_PP` AS `Prestazione`, `pp`.`Paziente` AS `Paziente`, `pp`.`Codice_Prestazione` AS `Codice_Prestazione`, `pp`.`Data` AS `Data`, `pp`.`Stanza` AS `Stanza`, `pp`.`Specialista` AS `Specialista`, `pp`.`Assistente` AS `Assistente`, `pp`.`Esito` AS `Esito`, `pp`.`Importo_Fattura` AS `Importo_Fattura` FROM `pp` WHERE `pp`.`Importo_Fattura` is not null WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Struttura per vista `specialisti`
--
DROP TABLE IF EXISTS `specialisti`;

DROP VIEW IF EXISTS `specialisti`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `specialisti`  AS SELECT `personale`.`ID` AS `ID`, `personale`.`Cognome` AS `Cognome`, `personale`.`Nome` AS `Nome`, `personale`.`Recapito` AS `Recapito`, `personale`.`E-mail` AS `E-mail`, `personale`.`Specializzazione` AS `Specializzazione`, `personale`.`Stipendio` AS `Stipendio`, `personale`.`Quota` AS `Quota` FROM `personale` WHERE `personale`.`Specializzazione` is not null WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Struttura per vista `trattamenti`
--
DROP TABLE IF EXISTS `trattamenti`;

DROP VIEW IF EXISTS `trattamenti`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `trattamenti`  AS SELECT `listaprestazioni`.`Codice_Prestazione` AS `Codice_Prestazione`, `listaprestazioni`.`Nome_Prestazione` AS `Nome_Prestazione`, `listaprestazioni`.`Costo` AS `Costo` FROM `listaprestazioni` WHERE `listaprestazioni`.`Tipo_Prestazione` = 'Trattamento' WITH CASCADED CHECK OPTION  ;

--
-- Limiti per le tabelle scaricate
--

--
-- Limiti per la tabella `abilitazioni`
--
ALTER TABLE `abilitazioni`
  ADD CONSTRAINT `Abilitazioni_fk0` FOREIGN KEY (`ID_Personale`) REFERENCES `personale` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `Abilitazioni_fk1` FOREIGN KEY (`Abilitazione`) REFERENCES `listaprestazioni` (`Codice_Prestazione`) ON UPDATE CASCADE;

--
-- Limiti per la tabella `pp`
--
ALTER TABLE `pp`
  ADD CONSTRAINT `PP_fk0` FOREIGN KEY (`Paziente`) REFERENCES `pazienti` (`CF`) ON DELETE NO ACTION ON UPDATE CASCADE,
  ADD CONSTRAINT `PP_fk1` FOREIGN KEY (`Codice_Prestazione`) REFERENCES `listaprestazioni` (`Codice_Prestazione`) ON UPDATE CASCADE,
  ADD CONSTRAINT `PP_fk2` FOREIGN KEY (`Specialista`) REFERENCES `personale` (`ID`) ON DELETE NO ACTION ON UPDATE CASCADE,
  ADD CONSTRAINT `PP_fk3` FOREIGN KEY (`Assistente`) REFERENCES `personale` (`ID`) ON DELETE NO ACTION ON UPDATE CASCADE;

--
-- Limiti per la tabella `turni`
--
ALTER TABLE `turni`
  ADD CONSTRAINT `Turni_fk0` FOREIGN KEY (`ID_Personale`) REFERENCES `personale` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;
SET FOREIGN_KEY_CHECKS=1;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
