-- Data Model
-- 1
--Primary key for each table
ALTER TABLE ITEM ADD CONSTRAINT PK_ITEM PRIMARY KEY (ITEM);
ALTER TABLE LOC ADD CONSTRAINT PK_LOC PRIMARY KEY (LOC);
ALTER TABLE ITEM_LOC_SOH ADD CONSTRAINT PK_ITEM_LOC PRIMARY KEY (ITEM,LOC);
--Index at table ITEM_LOC_SOH because dept column is one of the attributes that most store/warehouse users search is by dept
CREATE INDEX IDX_ITEM_LOC_SOH_DEPT ON ITEM_LOC_SOH (DEPT);

-- 2
Creation of the IDX_ITEM_LOC_SOH_DEPT index for quick access to data in the ITEM_LOC_SOH table, with the DEPT column being the most used in searches.
Creation of the item_loc_soh table partitioned by the loc column because the access to the application data is per store/warehouse
--
CREATE TABLE item_loc_soh
(
    item          VARCHAR2(25)   NOT NULL,
    loc           NUMBER(10)     NOT NULL,
    dept          NUMBER(4)      NOT NULL,
    unit_cost     NUMBER(20,4)   NOT NULL,
    stock_on_hand NUMBER(12,4)   NOT NULL
)
PARTITION BY HASH (loc)
PARTITIONS 8
--
-- 3
Add INITRANS 10 when creating the table and when creating the primary key
-- 4
CREATE OR REPLACE VIEW V_ITEM_LOC_SOH AS
  SELECT item,
         loc,
         dept,
         unit_cost,
         stock_on_hand
    FROM item_loc_soh;
-- 5
CREATE TABLE DEPT (
    dept NUMBER(4) NOT NULL,
    dept_user varchar2(50) NOT NULL
);

ALTER TABLE DEPT ADD CONSTRAINT PK_DEPT PRIMARY KEY (DEPT);

insert into dept (dept,dept_user)
select (level-1)+1,'USER A' from dual connect by level <=50
union all
select (level-1+50)+1,'USER B' from dual connect by level <=50;

--PLSQL Development
-- 6
PKG_ORC.SAVE_ITEM_LOC_SOH_SV
-- 7
DEPT FILTER CREATED IN SCREEN PAGE
-- 8
-- CREATED TYPE T_LOC_TBL AND T_LOC_OBJ
PKG_ORC.GET_LOCATIONS
-- 9
CREATE INDEX idx_item_loc_soh_loc_dept ON ITEM_LOC_SOH (LOC, DEPT);

ANALYZE TABLE ITEM_LOC_SOH COMPUTE STATISTICS;

--10
-- desativate index in item_loc_soh
-- insert values in item_loc_soh
-- activate index in item_loc_soh
DECLARE
RESULT BOOLEAN;
BEGIN
RESULT := PKG_ORC.SAVE_ITEM_LOC_SOH_SV(NULL); -- NULL FOR ALL OR SPECIFY the LOC
DBMS_OUTPUT.PUT_LINE('RESULT = '||CASE WHEN RESULT THEN 'TRUE' WHEN RESULT IS NULL THEN 'NULL' ELSE 'FALSE' END);
END;

--11
The AWR report for your database highlights some significant issues, mainly the following:

Key Problem:
High Scheduler Wait Time:

The event "resmgr
quantum" consumed 83.1% of DB time (153,719 seconds of total wait time).
This event occurs when Oracle's Resource Manager restricts CPU usage due to set resource plans, which could mean CPU resources are under contention, leading to high wait times for processes to get CPU time.
CPU Utilization:

DB CPU consumed 15.8% of DB time (29,136 seconds), indicating the CPU is being used heavily, but the CPU resources may be insufficient for the current workload.
Top Wait Events:

Besides the CPU quantum issue, other foreground events like ASM IO for non-blocking poll, cursor: pin S wait on X, and cell single block physical read contribute much smaller amounts to the total DB time, meaning they aren't critical in comparison to the CPU resource issue.
--
--Potential Solution:
Review Resource Manager Plans:

Check and adjust Oracle Resource Manager settings to ensure that resource allocation is fair. You may need to modify the resource plans to allocate more CPU resources to high-priority workloads.
Increase CPU Resources:

The current CPU capacity may not be sufficient for the workload. Consider scaling up the CPU resources if the system supports it or optimizing application queries and workload to reduce CPU consumption.
Query Optimization:

Review high-consuming SQL queries and optimize them to reduce CPU usage and improve efficiency.
Monitor Background Processes:

Since background CPU usage is very low (almost 0%), focus on the foreground processes. Addressing the CPU quantum wait issue should be the first priority.

-- 12
-- ORA-01031: privilégios insuficientes
CREATE OR REPLACE DIRECTORY export_dir AS '/csv';

BEGIN
    PKG_ORC.extract_stock_data_to_csv;
END;