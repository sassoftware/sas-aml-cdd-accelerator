////////////////////////////////////////////////
// AML 8.3
// - aml_8.3_fdx_tables_oracle
//
// Each script is setup with substitution a 
// variable.  Set "tenant" for the pluggable
// database that will align with your tenant.
// This will alter the session appropriately
// and fence the tablesspaces under /u02.
//
// Run this script as AMLDBADMIN.
// If Oracle is configured as a PDB, fill in
// the tenant or remove the lines.

DEFINE tenant = '[provide your tenant name]';

//
////////////////////////////////////////////////

ALTER SESSION SET CONTAINER = &&tenant;

--FSC_JOB_CALENDAR
CREATE TABLE CORE.FSC_JOB_CALENDAR 
(	JOB_CALENDAR_ID numeric(5,0), 
	SEGMENT_ID VARCHAR(128),
	CALENDAR_DATE TIMESTAMP WITH TIME ZONE, 
	RUNDATE_IND CHAR(1), 
	DAILY_RUNDATE_IND CHAR(1), 
	WEEKLY_RUNDATE_IND CHAR(1), 
	MONTHLY_RUNDATE_IND CHAR(1), 
	STATUS_IND CHAR(1), 
	BUSINESS_DAY_COUNT numeric(15,0),
	primary key(job_calendar_id)
);
CREATE INDEX XIE1FSC_JOB_CALENDAR ON
CORE.FSC_JOB_CALENDAR( CALENDAR_DATE );

--FSC_JOB
CREATE TABLE CORE.FSC_JOB 
(	JOB_ID numeric(3,0),
	JOB_NAME VARCHAR(50), 
	JOB_DESC VARCHAR(255), 
	JOB_CAT VARCHAR(50), 
	JOB_INCLUDE numeric(2,0),
	primary key(job_id)
);

--FSC_TYPE2_DIM_FACT
CREATE TABLE CORE.FSC_TYPE2_DIM_FACT 
(	DIMENSION_TABLE VARCHAR(50), 
	DIMENSION_SK NUMERIC(11,0), 
	FIELD_NAME VARCHAR(45), 
	CHANGE_BEGIN_DATE TIMESTAMP WITH TIME ZONE
) ;

--FSC_PROCESS
CREATE TABLE CORE.FSC_PROCESS 
(	PROCESS_ID NUMERIC(16,0), 
	PROCESS_PARENT_ID NUMERIC(16,0),
	PROCESS_START_DT TIMESTAMP WITH TIME ZONE, 
	PROCESS_END_DT TIMESTAMP WITH TIME ZONE, 
	PROCESS_NOTES VARCHAR(255), 
	PROCESS_STATUS VARCHAR(20), 
	JOB_ID NUMERIC(3,0),
	RUN_DATE NUMERIC(10,0),
	PRIMARY KEY (PROCESS_ID, JOB_ID)
);

--FSC_PROCESS_METRIC
CREATE TABLE CORE.FSC_PROCESS_METRIC 
(	METRIC_ID NUMERIC(16,0),
   	METRIC_NAME VARCHAR(50), 
	METRIC_DESC VARCHAR(255), 
	METRIC_VALUE NUMERIC(16,5),
	PROCESS_ID NUMERIC(16,0),
	PRIMARY KEY (METRIC_ID, PROCESS_ID)
);

-- FSC_SCD_COLUMNS
CREATE TABLE CORE.FSC_SCD_COLUMNS 
(	SCD_KEY NUMERIC(12,0), 
   	SEGMENT_ID VARCHAR(128),
   	SCD_TABLE VARCHAR(35), 
   	SCD_COLUMN VARCHAR(35), 
   	SCD_TYPE VARCHAR(6),
   	XREF_VALID_IND CHAR(1), 
   	ORDER_ID NUMERIC(6,0),
   	CREATE_DATE TIMESTAMP WITH TIME ZONE, 
   	END_DATE TIMESTAMP WITH TIME ZONE, 
   	CREATE_USER_ID VARCHAR(60), 
   	VERSION_NUMBER NUMERIC(10,0), 
   	CURRENT_IND CHAR(1),
   	PRIMARY KEY (SCD_KEY)
);

--FSC_DATE_DIM
CREATE TABLE CORE.FSC_DATE_DIM
(
	DATE_KEY             NUMERIC(8,0) NOT NULL ,
	CALENDAR_DATE        TIMESTAMP WITH TIME ZONE,
	CALENDAR_DATE_SAS    NUMERIC(8,0) NULL ,
	CALENDAR_DATE_DMY    CHAR(9) NULL ,
	DAY_NAME             VARCHAR(9) NULL ,
	DAY_NAME_SHORT       CHAR(3) NULL ,
	DAY_NUMBER_IN_MONTH  NUMERIC(2,0) NULL ,
	DAY_NUMBER_IN_YEAR   NUMERIC(3,0) NULL ,
	WEEK_NUMBER_IN_MONTH NUMERIC(1,0) NULL ,
	WEEK_NUMBER_IN_YEAR  NUMERIC(2,0) NULL ,
	MONTH_NUMBER_IN_YEAR NUMERIC(2,0) NULL ,
	MONTH_KEY            NUMERIC(6,0) NULL ,
	MONTH_AND_YEAR       CHAR(6) NULL ,
	MONTH_NAME           VARCHAR(9) NULL ,
	MONTH_NAME_SHORT     CHAR(3) NULL ,
	QUARTER_NAME         CHAR(4) NULL ,
	QUARTER_AND_YEAR     CHAR(6) NULL ,
	MONTH_NAME_3C        CHAR(3) NULL ,
	QUARTER_NAME_2C      CHAR(2) NULL ,
	QUARTER_NAME_4C      CHAR(4) NULL ,
	YEAR_2C              CHAR(2) NULL ,
	YEAR_4C              CHAR(4) NULL ,
	HOLIDAY_IND          CHAR(1) NULL ,
	HOLIDAY_NAME         CHAR(9) NULL ,
	WEEK_DAY_IND         CHAR(1) NULL ,
	END_OF_MONTH_IND     CHAR(1) NULL ,
	ECONOMIC_RELEASE_DESC VARCHAR(20) NULL ,
	ECONOMIC_EVENT_DESC  VARCHAR(20) NULL,
	PRIMARY KEY(DATE_KEY)
);
CREATE INDEX XIE1FSC_DATE_DIM ON
core.FSC_DATE_DIM( CALENDAR_DATE );

--FSC_TIME_DIM
CREATE TABLE CORE.FSC_TIME_DIM
(
	TIME_KEY             NUMERIC(6) NOT NULL ,
	TIME_HHMMSS          CHAR(6) NULL ,
	TIME_HH              CHAR(2) NULL ,
	TIME_MM              CHAR(2) NULL ,
	TIME_SS              CHAR(2) NULL ,
	TIME_AM_PM           CHAR(2) NULL,
	PRIMARY KEY(TIME_KEY)
);

-- FSC_CURRENCY_DIM
CREATE TABLE CORE.FSC_CURRENCY_DIM
(
	CURRENCY_KEY         NUMERIC(5,0) NOT NULL ,
	CURRENCY_CODE        CHAR(3) NULL ,
	CURRENCY_NAME        VARCHAR(100) NULL,
	PRIMARY KEY(CURRENCY_KEY)
);

-- FSC_MONTH_DIM
CREATE TABLE CORE.FSC_MONTH_DIM
(
	MONTH_KEY            NUMERIC(6,0) NOT NULL ,
	MONTH_AND_YEAR       CHAR(6) NULL ,
	MONTH_NAME           VARCHAR(9) NULL ,
	MONTH_NAME_3C        CHAR(3) NULL ,
	QUARTER_NAME_2C      CHAR(2) NULL ,
	QUARTER_NAME_4C      CHAR(4) NULL ,
	YEAR_2C              CHAR(2) NULL ,
	YEAR_4C              CHAR(4) NULL ,
	CURRENT_MONTH_IND    CHAR(1) NULL,
	PRIMARY KEY(MONTH_KEY)
);

-- PROCESS_ID
CREATE SEQUENCE CORE.PROCESS_ID 
    INCREMENT BY 1
	START WITH 1
	MINVALUE 1
;

-- METRIC_ID
CREATE SEQUENCE CORE.METRIC_ID
    INCREMENT BY 1
	START WITH 1
	MINVALUE 1
;

-- FSC_PROCESS_SEQUENCE
CREATE SEQUENCE CORE.FSC_PROCESS_SEQUENCE
    INCREMENT BY 1
	START WITH 1
	MINVALUE 1
;

GRANT DELETE,INSERT,SELECT,UPDATE,REFERENCES ON CORE.FSC_JOB_CALENDAR TO AMLDBUSER;
GRANT DELETE,INSERT,SELECT,UPDATE,REFERENCES ON CORE.FSC_JOB TO AMLDBUSER;
GRANT DELETE,INSERT,SELECT,UPDATE,REFERENCES ON CORE.FSC_TYPE2_DIM_FACT TO AMLDBUSER;
GRANT DELETE,INSERT,SELECT,UPDATE,REFERENCES ON CORE.FSC_PROCESS_METRIC TO AMLDBUSER;
GRANT DELETE,INSERT,SELECT,UPDATE,REFERENCES ON CORE.FSC_SCD_COLUMNS TO AMLDBUSER;

GRANT DELETE,INSERT,SELECT,UPDATE,REFERENCES ON CORE.FSC_DATE_DIM TO AMLDBUSER;
GRANT DELETE,INSERT,SELECT,UPDATE,REFERENCES ON CORE.FSC_TIME_DIM TO AMLDBUSER;
GRANT DELETE,INSERT,SELECT,UPDATE,REFERENCES ON CORE.FSC_MONTH_DIM TO AMLDBUSER;
GRANT DELETE,INSERT,SELECT,UPDATE,REFERENCES ON CORE.FSC_CURRENCY_DIM TO AMLDBUSER;

GRANT SELECT,ALTER ON CORE.PROCESS_ID TO AMLDBUSER;
GRANT SELECT,ALTER ON CORE.METRIC_ID TO AMLDBUSER;
GRANT SELECT,ALTER ON CORE.FSC_PROCESS_SEQUENCE TO AMLDBUSER;