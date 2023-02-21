-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:4306
-- Creato il: Feb 21, 2023 alle 10:31
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
-- Struttura della tabella `abilitazioni`
--
-- Creazione: Feb 16, 2023 alle 10:15
--

CREATE TABLE `abilitazioni` (
  `ID_Personale` int(8) NOT NULL,
  `Abilitazione` int(8) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- RELAZIONI PER TABELLA `abilitazioni`:
--   `ID_Personale`
--       `personale` -> `ID`
--   `Abilitazione`
--       `listaprestazioni` -> `Codice_Prestazione`
--

-- --------------------------------------------------------

--
-- Struttura stand-in per le viste `assistenti`
-- (Vedi sotto per la vista effettiva)
--
CREATE TABLE `assistenti` (
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
CREATE TABLE `controlli` (
`Codice_Prestazione` int(8)
,`Nome_Prestazione` varchar(30)
,`Costo` float
);

-- --------------------------------------------------------

--
-- Struttura della tabella `listaprestazioni`
--
-- Creazione: Feb 16, 2023 alle 10:15
--

CREATE TABLE `listaprestazioni` (
  `Codice_Prestazione` int(8) NOT NULL,
  `Nome_Prestazione` varchar(30) NOT NULL,
  `Tipo_Prestazione` enum('Controllo','Trattamento') NOT NULL,
  `Costo` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- RELAZIONI PER TABELLA `listaprestazioni`:
--

-- --------------------------------------------------------

--
-- Struttura della tabella `pazienti`
--
-- Creazione: Feb 17, 2023 alle 10:40
--

CREATE TABLE `pazienti` (
  `CF` varchar(16) NOT NULL,
  `Cognome` varchar(30) NOT NULL,
  `Nome` varchar(30) NOT NULL,
  `Data_Nascita` date NOT NULL,
  `Genere` enum('M','F') DEFAULT NULL,
  `Recapito` varchar(13) NOT NULL,
  `E-mail` varchar(50) DEFAULT NULL,
  `Sconto` float NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- RELAZIONI PER TABELLA `pazienti`:
--

-- --------------------------------------------------------

--
-- Struttura della tabella `personale`
--
-- Creazione: Feb 17, 2023 alle 10:39
-- Ultimo aggiornamento: Feb 20, 2023 alle 11:50
--

CREATE TABLE `personale` (
  `ID` int(8) NOT NULL,
  `Cognome` varchar(30) NOT NULL,
  `Nome` varchar(30) NOT NULL,
  `Recapito` varchar(13) NOT NULL,
  `E-mail` varchar(50) NOT NULL,
  `Specializzazione` varchar(30) DEFAULT NULL,
  `Stipendio` float NOT NULL,
  `Quota` float NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- RELAZIONI PER TABELLA `personale`:
--

-- --------------------------------------------------------

--
-- Struttura della tabella `pp`
--
-- Creazione: Feb 16, 2023 alle 10:15
-- Ultimo aggiornamento: Feb 20, 2023 alle 11:52
--

CREATE TABLE `pp` (
  `ID_PP` int(8) NOT NULL,
  `Paziente` varchar(16) NOT NULL,
  `Codice_Prestazione` int(8) NOT NULL,
  `Data` datetime NOT NULL,
  `Stanza` enum('A1','A2','A3','A4','B1','B2','B3','B4') NOT NULL,
  `Specialista` int(8) NOT NULL,
  `Assistente` int(8) DEFAULT NULL,
  `Esito` enum('OK','NECESSITA CONTROLLO','NECESSITA TRATTAMENTO') DEFAULT NULL,
  `Importo_Fattura` float DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

-- --------------------------------------------------------

--
-- Struttura stand-in per le viste `prenotazioni`
-- (Vedi sotto per la vista effettiva)
--
CREATE TABLE `prenotazioni` (
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
CREATE TABLE `prestazionieffetttuate` (
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
CREATE TABLE `specialisti` (
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
CREATE TABLE `trattamenti` (
`Codice_Prestazione` int(8)
,`Nome_Prestazione` varchar(30)
,`Costo` float
);

-- --------------------------------------------------------

--
-- Struttura della tabella `turni`
--
-- Creazione: Feb 16, 2023 alle 10:15
-- Ultimo aggiornamento: Feb 20, 2023 alle 11:38
--

CREATE TABLE `turni` (
  `ID_Personale` int(8) NOT NULL,
  `Giorno` enum('lunedì','martedì','mercoledì','giovedì','venerdì') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- RELAZIONI PER TABELLA `turni`:
--   `ID_Personale`
--       `personale` -> `ID`
--

-- --------------------------------------------------------

--
-- Struttura per vista `assistenti`
--
DROP TABLE IF EXISTS `assistenti`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `assistenti`  AS SELECT `personale`.`ID` AS `ID`, `personale`.`Cognome` AS `Cognome`, `personale`.`Nome` AS `Nome`, `personale`.`Recapito` AS `Recapito`, `personale`.`E-mail` AS `E-mail`, `personale`.`Stipendio` AS `Stipendio`, `personale`.`Quota` AS `Quota` FROM `personale` WHERE `personale`.`Specializzazione` is null WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Struttura per vista `controlli`
--
DROP TABLE IF EXISTS `controlli`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `controlli`  AS SELECT `listaprestazioni`.`Codice_Prestazione` AS `Codice_Prestazione`, `listaprestazioni`.`Nome_Prestazione` AS `Nome_Prestazione`, `listaprestazioni`.`Costo` AS `Costo` FROM `listaprestazioni` WHERE `listaprestazioni`.`Tipo_Prestazione` = 'Controllo' WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Struttura per vista `prenotazioni`
--
DROP TABLE IF EXISTS `prenotazioni`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `prenotazioni`  AS SELECT `pp`.`ID_PP` AS `Prenotazione`, `pp`.`Paziente` AS `Paziente`, `pp`.`Codice_Prestazione` AS `Codice_Prestazione`, `pp`.`Data` AS `Data`, `pp`.`Stanza` AS `Stanza`, `pp`.`Specialista` AS `Specialista` FROM `pp` WHERE `pp`.`Importo_Fattura` is null WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Struttura per vista `prestazionieffetttuate`
--
DROP TABLE IF EXISTS `prestazionieffetttuate`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `prestazionieffetttuate`  AS SELECT `pp`.`ID_PP` AS `Prestazione`, `pp`.`Paziente` AS `Paziente`, `pp`.`Codice_Prestazione` AS `Codice_Prestazione`, `pp`.`Data` AS `Data`, `pp`.`Stanza` AS `Stanza`, `pp`.`Specialista` AS `Specialista`, `pp`.`Assistente` AS `Assistente`, `pp`.`Esito` AS `Esito`, `pp`.`Importo_Fattura` AS `Importo_Fattura` FROM `pp` WHERE `pp`.`Importo_Fattura` is not null WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Struttura per vista `specialisti`
--
DROP TABLE IF EXISTS `specialisti`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `specialisti`  AS SELECT `personale`.`ID` AS `ID`, `personale`.`Cognome` AS `Cognome`, `personale`.`Nome` AS `Nome`, `personale`.`Recapito` AS `Recapito`, `personale`.`E-mail` AS `E-mail`, `personale`.`Specializzazione` AS `Specializzazione`, `personale`.`Stipendio` AS `Stipendio`, `personale`.`Quota` AS `Quota` FROM `personale` WHERE `personale`.`Specializzazione` is not null WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Struttura per vista `trattamenti`
--
DROP TABLE IF EXISTS `trattamenti`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `trattamenti`  AS SELECT `listaprestazioni`.`Codice_Prestazione` AS `Codice_Prestazione`, `listaprestazioni`.`Nome_Prestazione` AS `Nome_Prestazione`, `listaprestazioni`.`Costo` AS `Costo` FROM `listaprestazioni` WHERE `listaprestazioni`.`Tipo_Prestazione` = 'Trattamento' WITH CASCADED CHECK OPTION  ;

--
-- Indici per le tabelle scaricate
--

--
-- Indici per le tabelle `abilitazioni`
--
ALTER TABLE `abilitazioni`
  ADD UNIQUE KEY `Abilitazioni_fk2` (`ID_Personale`,`Abilitazione`),
  ADD KEY `ID_Personale` (`ID_Personale`,`Abilitazione`),
  ADD KEY `Abilitazioni_fk1` (`Abilitazione`);

--
-- Indici per le tabelle `listaprestazioni`
--
ALTER TABLE `listaprestazioni`
  ADD PRIMARY KEY (`Codice_Prestazione`) USING BTREE,
  ADD UNIQUE KEY `Nome` (`Nome_Prestazione`) USING BTREE;

--
-- Indici per le tabelle `pazienti`
--
ALTER TABLE `pazienti`
  ADD PRIMARY KEY (`CF`);

--
-- Indici per le tabelle `personale`
--
ALTER TABLE `personale`
  ADD PRIMARY KEY (`ID`) USING BTREE;

--
-- Indici per le tabelle `pp`
--
ALTER TABLE `pp`
  ADD PRIMARY KEY (`ID_PP`),
  ADD KEY `Paziente` (`Paziente`),
  ADD KEY `Codice_Prestazione` (`Codice_Prestazione`),
  ADD KEY `Specialista` (`Specialista`),
  ADD KEY `Assistente` (`Assistente`);

--
-- Indici per le tabelle `turni`
--
ALTER TABLE `turni`
  ADD UNIQUE KEY `Turni_fk1` (`ID_Personale`,`Giorno`),
  ADD KEY `ID_Personale` (`ID_Personale`,`Giorno`);

--
-- AUTO_INCREMENT per le tabelle scaricate
--

--
-- AUTO_INCREMENT per la tabella `listaprestazioni`
--
ALTER TABLE `listaprestazioni`
  MODIFY `Codice_Prestazione` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT per la tabella `personale`
--
ALTER TABLE `personale`
  MODIFY `ID` int(8) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT per la tabella `pp`
--
ALTER TABLE `pp`
  MODIFY `ID_PP` int(8) NOT NULL AUTO_INCREMENT;

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
