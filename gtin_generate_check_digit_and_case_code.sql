-- 
-- @dayreiner |  https://18pct.com/ | https://sensibrands.ca | https://github.com/dayreiner 
--
-- An example database for storing product GTINs and generating the GS1 check digit and GTIN master case code. 
-- When an 11-digit GTIN is inserted, a trigger calls the function to generate the GS1 check digit and insert it into the check_digit column. 
-- A second trigger generates the master case code GTIN and inserts that value in the master_case_code column. 
-- Expanded upon from the function in this article: https://www.anycodings.com/1questions/4958850/check-for-invalid-upc-in-mysql
--
-- After creating the gtin database, you can insert a gtin to test that the check digit and case code are correctly added:
-- 
-- INSERT INTO `gtin` (`GTIN`) VALUES ('04210000526');
--
-- SELECT * FROM `gtin` WHERE `GTIN` = '04210000526';
-- +-------------+-------------+------------------+
-- | GTIN        | Check_Digit | Master_Case_Code |
-- +-------------+-------------+------------------+
-- | 04210000526 | 4           | 10042100005261   |
-- +-------------+-------------+------------------+
--

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

CREATE DATABASE IF NOT EXISTS `gtin` DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;
USE `gtin`;

DELIMITER $$

CREATE DEFINER=`root`@`localhost` FUNCTION `gs1_checkdigit` (`base` VARCHAR(13) CHARSET utf8) RETURNS CHAR(1) CHARSET utf8 DETERMINISTIC COMMENT 'Provide GTIN as value and calculate the GTIN check digit.' BEGIN
    ##
    ##  NAME
    ##      gs1_checkdigit -- calculate checkdigit for barcode numbers
    ##
    ##  SYNOPSIS
    ##      check_digit = gs1_checkdigit("NUMBER_WITHOUT_CHECKDIGIT")
    ##
    ##  DESCRIPTION
    ##      Given a GS1 input identifier (company_prefix + product_id)
    ##      without a check digit, returns the check digit that should
    ##      be appended to the input to be a valid identifier.
    ##
    ##      Can be used for inputs of any length. This is to accommodate
    ##      various GS1 standards ranging from GTIN-8 (7 input digits) to
    ##      SSCC (17 input digits). This function does NOT validate the
    ##      input length -- i.e. there is no valid 15-digit input length
    ##      in the GS1 standard, but this function will accept 15 digits.
    ##
    ##  OPTIONS
    ##      base        Input digits as a VARCHAR
    ##
    ##  RETURNS
    ##      Check digit as a CHAR(1)
    ##
    ##  EXAMPLES
    ##      SELECT gs1_checkdigit("05042829526")
    ##      --> 7
    ##
    ##  NOTES
    ##      Formula: http://www.gs1.org/how-calculate-check-digit-manually
    ##
    ##      Test cases: https://www.gs1us.org/tools/build-a-sample-upc-barcode
    ##
    ##------------------------------------------------------------------------
    ##
    ##  Local variables
    DECLARE odds INTEGER DEFAULT 0;     ## sum of odd positions
    DECLARE evens INTEGER DEFAULT 0;    ## sum of even positions
    DECLARE total INTEGER DEFAULT 0;    ## position-weighted sum
    DECLARE len INTEGER;                ## input string length
    DECLARE pos INTEGER DEFAULT 0;      ## current digit position
    DECLARE digit INTEGER;              ## current digit as INT
    DECLARE cd INTEGER;                 ## check digit for output
    ##
    ##  Main calculation
    SET len = LENGTH(base);
    mainloop: LOOP
        ##
        ##  Get digits, from the right
        SET digit = CAST(SUBSTRING(base, len-pos, 1) AS SIGNED INTEGER);
        ##
        ##  Example:
        ##
        ##     Input "12345678901" -- "X" is check digit placeholder
        ##     +-+-+-+-+-+-+-+-+-+-+-+-+
        ##     |1|2|3|4|5|6|7|8|9|0|1|X|
        ##     +-+-+-+-+-+-+-+-+-+-+-+-+
        ##      |                   |
        ##      "pos" 10 position   "pos" 0 position
        ##
        ##     Weighting factor by position
        ##     +-+-+-+-+-+-+-+-+-+-+-+-+
        ##     |3|1|3|1|3|1|3|1|3|1|3|0| 
        ##     +-+-+-+-+-+-+-+-+-+-+-+-+
        ##
        ##
        ##  Test cases:
        ##
        ##      SELECT gs1_checkdigit('04210000526');  ## 4
        ##      SELECT gs1_checkdigit('03600029145');  ## 2
        ##      SELECT gs1_checkdigit('05042829526');  ## 7
        ##      SELECT gs1_checkdigit('19147000000');  ## 0
        ##      SELECT gs1_checkdigit('19147056187');  ## 7
        ##      SELECT gs1_checkdigit('19147099999');  ## 1
        ##      SELECT gs1_checkdigit('62910415002');  ## 4
        ##
        IF (pos % 2 = 0)
        THEN
            SET evens = evens + digit;
        ELSE
            SET odds = odds + digit;
        END IF;
        ##
        ##  Bump the loop
        SET pos = pos + 1;
        IF (pos < LEN)
        THEN
            ITERATE mainloop;
        END IF;
        LEAVE mainloop;
    END LOOP mainloop;
    ##
    ##  GTIN formula
    SET total = odds + (3 * evens);
    SET cd = total % 10;
    IF (cd <> 0)
    THEN
        SET cd = 10 - cd;
    END IF;
    ##
    RETURN (CAST(cd AS CHAR));
END$$

DELIMITER ;

CREATE TABLE `gtin` (
  `GTIN` varchar(11) COLLATE utf8_bin NOT NULL COMMENT 'GTIN',
  `Check_Digit` char(1) COLLATE utf8_bin NOT NULL COMMENT 'Check Digit',
  `Master_Case_Code` varchar(14) COLLATE utf8_bin NOT NULL COMMENT 'Master Case Code'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

DELIMITER $$
CREATE TRIGGER `insert_case_code` BEFORE INSERT ON `gtin` FOR EACH ROW BEGIN
    SET NEW.master_case_code =  CONCAT(10,NEW.GTIN,gs1_checkdigit(CONCAT(10,NEW.GTIN)));
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `insert_check_digit` BEFORE INSERT ON `gtin` FOR EACH ROW BEGIN
    SET NEW.check_digit = gs1_checkdigit(NEW.GTIN);
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_case_code` BEFORE UPDATE ON `gtin` FOR EACH ROW BEGIN
    SET NEW.master_case_code =  CONCAT(10,NEW.GTIN,gs1_checkdigit(CONCAT(10,NEW.GTIN)));
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_check_digit` BEFORE INSERT ON `gtin` FOR EACH ROW BEGIN
    SET NEW.check_digit = gs1_checkdigit(NEW.GTIN);
END
$$
DELIMITER ;

ALTER TABLE `gtin`
  ADD PRIMARY KEY (`GTIN`) USING BTREE,
  ADD UNIQUE KEY `Master_Case_Code` (`Master_Case_Code`);
COMMIT;
