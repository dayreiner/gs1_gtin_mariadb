# Generating GS1 Check Digits and GTIN-14 Case Codes in MariaDB
An example MariaDB database for storing product GTINs and generating the GS1 check digit and GTIN-14 master case code.

- When an 11-digit GTIN is inserted, a trigger calls the function to generate the GS1 check digit and insert it into the check_digit column. 
- A second trigger generates the master case code GTIN and inserts that value in the master_case_code column. 
- Expanded upon from the function in this article: https://www.anycodings.com/1questions/4958850/check-for-invalid-upc-in-mysql

After creating the gtin database, you can insert a gtin to test that the check digit and case code are correctly added:
```
INSERT INTO `gtin` (`GTIN`) VALUES ('04210000526');
```
After inserting the GTIN-11 value, select it from the table to see the check digit and GTIN-14 master case code. 
```
SELECT * FROM `gtin` WHERE `GTIN` = '04210000526';
+-------------+-------------+------------------+
| GTIN        | Check_Digit | Master_Case_Code |
+-------------+-------------+------------------+
| 04210000526 | 4           | 10042100005261   |
+-------------+-------------+------------------+
```
