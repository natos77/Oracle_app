DELETE FROM LOC;
--
-- CONNECT BY LEVEL <= 1000 REDUCED TO 100 BECAUSE TABLESPACE ERROR IN ITEM_LOC_SOH TABLE
INSERT INTO LOC(LOC,LOC_DESC)
SELECT LEVEL+100, TRANSLATE(DBMS_RANDOM.STRING('A', 20), 'ABCXYZ', LEVEL) FROM DUAL CONNECT BY LEVEL <= 100;