/*
AUTHOR: Ryan Dang
Build Complete DATE: 10/28/2026
DESCRIPTION: DMND0091580 CV, RA, PsA - Baseline Cardiovascular Risk Assessment and Identification of Opportunities for Improvement in Rheumatoid Arthritis (RA) and Psoriatic Arthritis (PsA) No Visit Requirement
*/

/*
 ------------------------------------------------------------
USE CLARITY
DECLARE @StartDate DATE = '2021-01-01';
DECLARE @EndDate   DATE = '2025-12-31';
 ------------------------------------------------------------ 
 
 -- CONFIGURATION SECTION
 --	#DxMap
 
IF OBJECT_ID('tempdb..#DxMap') IS NOT NULL DROP TABLE #DxMap;
CREATE TABLE #DxMap (
    Diagnosis_Group VARCHAR(10) NOT NULL,
    ICD10_Prefix    VARCHAR(10) NOT NULL
);
INSERT INTO #DxMap (Diagnosis_Group, ICD10_Prefix)
VALUES
    ('RA',  'M05'),
    ('RA',  'M06'),
    ('PsA', 'L40.5');

------------------------------------------------------------ 
-- #Clinics
-- cohort attachments are labeled if they do not have a visit requirement at these clinics. 
-- Change: Clinic list: + Med Group, removed less than 100 visit filter

IF OBJECT_ID('tempdb..#DeptList') IS NOT NULL DROP TABLE #DeptList;

SELECT
    pe.DEPARTMENT_ID,
    d.DEPARTMENT_NAME,
    d.SPECIALTY,
	MIN(CAST(pe.CONTACT_DATE AS DATE)) FIRST_CONTACT_DATE,
	MAX(CAST(pe.CONTACT_DATE AS DATE)) LAST_CONTACT_DATE,
	COUNT(*) ClinicVisitsDuringStudy

INTO #DeptList
FROM PAT_ENC pe
INNER JOIN CLARITY_DEP d
    ON pe.DEPARTMENT_ID = d.DEPARTMENT_ID
WHERE pe.CONTACT_DATE >= @StartDate
  AND pe.CONTACT_DATE < DATEADD(DAY,1,@EndDate)
  AND (
       UPPER(d.DEPARTMENT_NAME) LIKE '%RHEUM%'
    OR UPPER(d.DEPARTMENT_NAME) LIKE '%PRIMARY CARE%'
    OR UPPER(d.DEPARTMENT_NAME) LIKE '%FAMILY MED%'
    OR UPPER(d.DEPARTMENT_NAME) LIKE '%INTERNAL MED%'
    OR UPPER(d.DEPARTMENT_NAME) LIKE '%PCP%'
	OR UPPER(d.DEPARTMENT_NAME) LIKE '%MEDICAL GROUP%'
  )
GROUP BY
    pe.DEPARTMENT_ID,
    d.DEPARTMENT_NAME,
    d.SPECIALTY
ORDER BY COUNT(*) DESC

---------------------------------------------------------------------------
-- #Adults

IF OBJECT_ID('tempdb..#Adults') IS NOT NULL DROP TABLE #Adults;
-- 18+ as of the EndDate of the study.
--EndDate chosen for a uniform point in time. 

WITH PatientDemographics AS (
    SELECT
        p.PAT_ID,
        p.PAT_MRN_ID,
        p.PAT_NAME,
        p.BIRTH_DATE,
		p.SEX_C,
		

  -- Age: (End Year - Birth Year) and subtract 1 if Bday hasn't happened in that year 
        DATEDIFF(YEAR, p.BIRTH_DATE, @EndDate)
            - CASE
                WHEN DATEADD(YEAR,
                             DATEDIFF(YEAR, p.BIRTH_DATE, @EndDate),
                             p.BIRTH_DATE) > @EndDate
                THEN 1 ELSE 0
              END AS Age_At_EndDate
    FROM PATIENT p
)
SELECT 
    pd.PAT_ID,
	pd.PAT_MRN_ID,
    pd.Age_At_EndDate,
	pd.SEX_C,
	zc.NAME AS Sex_Name

INTO #Adults
FROM PatientDemographics pd
LEFT JOIN ZC_SEX zc
	ON pd.SEX_C = zc.RCPT_MEM_SEX_C	
WHERE Age_At_EndDate >= 18;

-- SELECT COUNT(*) AS AdultsCount, '18+ as of the EndDate of the study' AS Description FROM #Adults

 ------------------------------------------------------------


-- PROFESSIONAL BILLING SECTION

-- #PB_Dx_TransactionLevel
-- 'Provider billing charges attributed to RA/PsA during study period (system-wide, no visit requirement)'

--DECLARE @StartDate DATE = '2021-01-01';
--DECLARE @EndDate   DATE = '2025-12-31';

IF OBJECT_ID('tempdb..#PB_Dx_TransactionLevel') IS NOT NULL DROP TABLE #PB_Dx_TransactionLevel;

SELECT
    tx.TX_ID,
    tx.SERVICE_DATE,
	p.PAT_ID,
    p.PAT_MRN_ID,
    dm.Diagnosis_Group,
    /* Number of matching diagnosis rows on this PB transaction */
    COUNT(*) AS Matching_Diagnosis_Rows_On_Transaction

INTO #PB_Dx_TransactionLevel
FROM ARPB_TRANSACTIONS tx
INNER JOIN TX_DIAG td
    ON tx.TX_ID = td.TX_ID
INNER JOIN CLARITY_EDG edg
    ON td.DX_ID = edg.DX_ID
INNER JOIN #DxMap dm
    ON edg.REF_BILL_CODE LIKE dm.ICD10_Prefix + '%'
INNER JOIN PATIENT p
    ON tx.PATIENT_ID = p.PAT_ID
WHERE tx.SERVICE_DATE >= @StartDate
  AND tx.SERVICE_DATE < DATEADD(DAY, 1, @EndDate)

  /* Keep only PB charge transactions */
  AND tx.TX_TYPE_C = 1

  /* Exclude voided transactions */
  AND tx.VOID_DATE IS NULL

GROUP BY
    tx.TX_ID,
    tx.SERVICE_DATE,
	p.PAT_ID,
    p.PAT_MRN_ID,
    dm.Diagnosis_Group
;

-- SELECT COUNT(*) AS #PB_Dx_TransactionLevelCount, 'Provider billing charges attributed to RA/PsA during study period (system-wide, no visit requirement)' AS Description FROM #PB_Dx_TransactionLevel


IF OBJECT_ID('tempdb..#PB_Dx_Cohort') IS NOT NULL DROP TABLE #PB_Dx_Cohort;

SELECT
    tl.PAT_ID,
    tl.PAT_MRN_ID,
    tl.Diagnosis_Group,
	a.Age_At_EndDate,
	a.SEX_C,
	a.Sex_Name,

    MIN(tl.SERVICE_DATE) AS First_Qualifying_PB_Service_Date,
    MAX(tl.SERVICE_DATE) AS Last_Qualifying_PB_Service_Date,

    /* Count of qualifying PB charge transactions */
    COUNT(*) AS Qualifying_PB_Charge_Transaction_Count

INTO #PB_Dx_Cohort
FROM #PB_Dx_TransactionLevel tl

INNER JOIN #Adults a
	ON tl.PAT_ID = a.PAT_ID
GROUP BY
    tl.PAT_ID,
    tl.PAT_MRN_ID,
    tl.Diagnosis_Group,
	a.Age_At_EndDate,
    a.SEX_C,
    a.Sex_Name;

SELECT COUNT(*) AS PB_Dx_CohortCount, 'Patients 18+ with Provider billing charges attributed to RA/PsA during study period (system-wide, no visit requirement)' AS Description FROM #PB_Dx_Cohort

-- 8298 RA 1871 PsA
SELECT Diagnosis_Group, COUNT(*) AS 'Table 1. Total Patients >= Age 18'
FROM #PB_Dx_Cohort
GROUP BY Diagnosis_Group

 ------------------------------------------------------------
 */

 /*
 -- LIPID PANEL ORDER & RESULT SECION
 -- 5:08 run time no MSTeams
 -- 280,915 individual lipid panels (all HonorHealth) with results; 1:52 run time
 -- 148,932 individual patients (all HonorHealth) with lipid panel results; 0:35 run time
   
DECLARE @StartDate DATE = '2021-01-01';
DECLARE @EndDate   DATE = '2025-12-31';

IF OBJECT_ID('tempdb..#PatientsWithLipidPanels') IS NOT NULL DROP TABLE #PatientsWithLipidPanels;

WITH LipidPanels AS
(
	SELECT 
	ROW_NUMBER() OVER(PARTITION BY op.PAT_ID,cohort.PAT_MRN_ID,cohort.Diagnosis_Group,cohort.Age_At_EndDate ORDER BY Age_At_EndDate) AS RowNumber
	,orz.ORDER_PROC_ID
	,orz.ORD_NUM_VALUE
	,cc.EXTERNAL_NAME
	,op.ORDERING_DATE
	,op.PAT_ID
	,eap.PROC_CODE
	,eap.PROC_NAME
	,cohort.PAT_MRN_ID
	,cohort.Diagnosis_Group
	,cohort.Age_At_EndDate

	
	FROM ORDER_RESULTS orz
	JOIN CLARITY_COMPONENT cc
		ON orz.COMPONENT_ID = cc.COMPONENT_ID
	JOIN ORDER_PROC op
		ON orz.ORDER_PROC_ID = op.ORDER_PROC_ID
	JOIN CLARITY_EAP eap
		ON op.PROC_ID = eap.PROC_ID
	JOIN #PB_Dx_Cohort cohort
		ON cohort.PAT_ID = op.PAT_ID
	
	WHERE 1=1
	AND orz.RESULT_STATUS_C = 3		/*2: prelim, 3:final, 4:corrected 5:incomplete*/
	AND orz.ORD_NUM_VALUE != 9999999
	AND cc.COMPONENT_ID = 6301280500 /* EXTERNAL_NAME: 'LDL Cholesterol, Calc' */
	AND op.PAT_ID IS NOT NULL
	AND op.ORDERING_DATE >= @StartDate
	AND op.ORDERING_DATE < DATEADD(DAY, 1, @EndDate)
	AND op.ORDER_STATUS_C = 5	/* completed orders */
	AND op.LAB_STATUS_C = 3		/*final result */
	--AND eap.PROC_CODE = '80061' /* 80061 | 'CHG LIPID PANEL' exisits in clarity_EAP but not when joined to orders */
	AND eap.PROC_CODE 
		IN('LAB18'	/* 'LIPID PANEL' */
		,'LAB7016'	/* 'LIPID PANEL W/RFLX LDL DIRECT' */
		)
	)
SELECT
PAT_ID
,PAT_MRN_ID 
,Diagnosis_Group 
,Age_At_EndDate
,ORDER_PROC_ID
,ORD_NUM_VALUE
,EXTERNAL_NAME
,ORDERING_DATE
,PROC_CODE
,PROC_NAME


INTO #PatientsWithLipidPanels
FROM LipidPanels
WHERE RowNumber = 1


SELECT TOP 5 * FROM #PatientsWithLipidPanels
SELECT COUNT(*) AS LipidPanelCount, 'Patients with Lipid Panel Results' AS Description FROM #PatientsWithLipidPanels

-- 2115 (25.5%) RA | 544 (29.1%) PsA
SELECT Diagnosis_Group, COUNT(*) AS 'Table 1 Patients with Lipid Panel'
FROM #PatientsWithLipidPanels
GROUP BY Diagnosis_Group

*/
-----------------------------------------------------------------

/*
-- 'Table 2A/B Total N'
SELECT 
	Diagnosis_Group
	,CASE WHEN Age_At_EndDate BETWEEN 20 AND 39 THEN '20-39'
		 WHEN Age_At_EndDate BETWEEN 40 AND 75 THEN '40-75'
		 WHEN Age_At_EndDate >= 76 THEN '>=76'
		 ELSE NULL
	End AgeGroup
	, COUNT(*) 'Table 2 Total N'

FROM #PB_Dx_Cohort
WHERE Age_At_EndDate >= 20
GROUP BY 
		CASE WHEN Age_At_EndDate BETWEEN 20 AND 39 THEN '20-39'
		 WHEN Age_At_EndDate BETWEEN 40 AND 75 THEN '40-75'
		 WHEN Age_At_EndDate >= 76 THEN '>=76'
		 ELSE NULL
		End 
	,Diagnosis_Group
ORDER BY 
	Diagnosis_Group DESC
	,AgeGroup
*/

/*
--'Table 2a/b LDL >= 190'
WITH LDLOver190 AS
(
	SELECT 
		cohort.Diagnosis_Group
		,CASE WHEN cohort.Age_At_EndDate BETWEEN 20 AND 39 THEN '20-39'
			 WHEN cohort.Age_At_EndDate BETWEEN 40 AND 75 THEN '40-75'
			 WHEN cohort.Age_At_EndDate >= 76 THEN '>=76'
			 ELSE NULL
		End AgeGroup
	,cohort.PAT_ID
	,cohort.PAT_MRN_ID 
	,cohort.Age_At_EndDate
	,ORDER_PROC_ID
	,ORD_NUM_VALUE
	,EXTERNAL_NAME
	,ORDERING_DATE
	,PROC_CODE
	,PROC_NAME
	
	FROM #PB_Dx_Cohort cohort
	JOIN #PatientsWithLipidPanels plp ON cohort.PAT_ID = plp.PAT_ID
	WHERE 1=1
	AND cohort.Age_At_EndDate >= 20
	AND ORD_NUM_VALUE >= 190
	--ORDER BY 
	--Diagnosis_Group DESC
	--,AgeGroup
	--,ORD_NUM_VALUE DESC
)

SELECT 
Diagnosis_Group
,AgeGroup
,COUNT(*) 'Table 2A/B LDL >= 190'

FROM LDLOver190
GROUP BY
Diagnosis_Group
,AgeGroup
ORDER BY 
Diagnosis_Group DESC
,AgeGroup
*/






/*
-- Table 2A/B On Statin among LDL >= 190

DECLARE @StartDate DATE = '2021-01-01';
DECLARE @EndDate DATE = '2025-12-31';

WITH LDLOver190 AS
(
	SELECT 
		cohort.Diagnosis_Group
		,CASE WHEN cohort.Age_At_EndDate BETWEEN 20 AND 39 THEN '20-39'
			 WHEN cohort.Age_At_EndDate BETWEEN 40 AND 75 THEN '40-75'
			 WHEN cohort.Age_At_EndDate >= 76 THEN '>=76'
			 ELSE NULL
		End AgeGroup
	,cohort.PAT_ID
	,cohort.PAT_MRN_ID 
	,cohort.Age_At_EndDate
	,ORDER_PROC_ID
	,ORD_NUM_VALUE
	,EXTERNAL_NAME
	,ORDERING_DATE
	,PROC_CODE
	,PROC_NAME
	
	FROM #PB_Dx_Cohort cohort
	JOIN #PatientsWithLipidPanels plp ON cohort.PAT_ID = plp.PAT_ID
	WHERE 1=1
	AND cohort.Age_At_EndDate >= 20
	AND ORD_NUM_VALUE >= 190
	--ORDER BY 
	--Diagnosis_Group DESC
	--,AgeGroup
	--,ORD_NUM_VALUE DESC
)
,
MedList AS 
/* ~91100 most rescent med list review times for each medication containing Statin  active on their medication list regardless of Diagnosis by patient. 
			A patient will have a row for each statin med they are on unless deduped*/
(
	SELECT 
	ROW_NUMBER() OVER(PARTITION BY list.PAT_ID ORDER BY pat.MEDS_LAST_REV_TM DESC) AS PatMedLastRevTm
	,pat.MEDS_LAST_REV_TM
	,pat.PAT_MRN_ID
	,list.PAT_ID
	,ordm.ORDER_INST
	,med.MEDICATION_ID
	,med.NAME
	,med.GENERIC_NAME

	FROM MEDS_REV_LAST_LIST  list
	JOIN ORDER_MED ordm ON list.MEDICATION_ORDER_ID = ordm.ORDER_MED_ID
	JOIN CLARITY_MEDICATION med ON ordm.MEDICATION_ID = med.MEDICATION_ID
	JOIN PATIENT pat ON list.PAT_ID = pat.PAT_ID

	WHERE 1=1
	AND list.TAKING_YN = 'Y' /* 1 */
	AND ORDER_INST >= DATEADD(YEAR,-1,@StartDate)
	AND ORDER_INST < DATEADD(DAY,1,@EndDate)
	AND pat.MEDS_LAST_REV_TM >= @StartDate
	AND pat.MEDS_LAST_REV_TM < DATEADD(DAY,1,@EndDate)
	AND ordm.MEDICATION_ID IN(
		5021, 6466, 8894, 8895, 10471, 11112, 11365, 11366, 19176, 19177, 19178, 19256, 19257, 21118, 23449, 23452, 28645, 28650, 29171, 29172,
		32126, 32128, 33183, 33184, 33191, 33192, 35134, 35135, 35136, 36185, 36186, 36187, 36188, 36201, 36202, 36203, 36204, 36606, 36607, 36608,
		36609, 36612, 37849, 37850, 37851, 37852, 37853, 37854, 37855, 37856, 38121, 38122, 38123, 38124, 38125, 38126, 38127, 38128, 38646, 38649,
		39215, 39216, 39217, 39221, 39222, 39223, 40202, 40203, 40204, 40208, 40209, 40210, 45037, 45752, 47422, 49562, 57530, 57780, 64920, 71676,
		71679, 71707, 76355, 76713, 104572, 104573, 104574, 104957, 104958, 104959, 105037, 105184, 105222, 105955, 105956, 105958, 105959, 115197, 115198, 115201,
		115202, 122077, 122078, 122298, 122299, 141845, 141937, 141938, 141939, 149691, 149692, 149693, 149694, 149841, 149843, 149844, 149845, 149893, 165215, 165251,
		165431, 130592, 131519, 131520, 131532, 131533, 131758, 131822, 131823, 136692, 136732, 136939, 150762, 150763, 151011, 151012, 160020, 160116, 160175, 160180,
		160217, 901325	/* 142 unique Statin medication IDs total as defined by `hhazdev.CustomDataEntry.StatinMedicationList` */
		)
)

SELECT 
*
FROM MedList
JOIN LDLOver190 ON MedList.PAT_ID = LDLOVer190.PAT_ID

WHERE PatMedLastRevTm = 1 /*Dedup to get 1 patient per row*/

*/

--------------------------------------------------------------------------------------
-- Table 2C/D Statin Use in Patients with RA/PsA Aged 40-75 with Diabetes				 

/*
DECLARE @StartDate DATE = '2021-01-01';
DECLARE @EndDate   DATE = '2025-12-31';

With MedList AS 
/* 
Most rescent med list review times for each medication containing Statin active on their medication list regardless of Diagnosis by patient. 
A patient will have a row for each statin med they are on unless deduped
*/
(
	SELECT 
	ROW_NUMBER() OVER(PARTITION BY list.PAT_ID ORDER BY pat.MEDS_LAST_REV_TM DESC) AS PatMedLastRevTm
	,pat.MEDS_LAST_REV_TM
	,pat.PAT_MRN_ID
	,list.PAT_ID
	,ordm.ORDER_INST
	,med.MEDICATION_ID
	,med.NAME
	,med.GENERIC_NAME

	FROM MEDS_REV_LAST_LIST  list
	JOIN ORDER_MED ordm ON list.MEDICATION_ORDER_ID = ordm.ORDER_MED_ID
	JOIN CLARITY_MEDICATION med ON ordm.MEDICATION_ID = med.MEDICATION_ID
	JOIN PATIENT pat ON list.PAT_ID = pat.PAT_ID

	WHERE 1=1
	AND list.TAKING_YN = 'Y' /* 1 */
	AND ORDER_INST >= DATEADD(YEAR,-1,@StartDate)
	AND ORDER_INST < DATEADD(DAY,1,@EndDate)
	AND pat.MEDS_LAST_REV_TM >= @StartDate
	AND pat.MEDS_LAST_REV_TM < DATEADD(DAY,1, @EndDate)
	AND ordm.MEDICATION_ID IN(
		5021, 6466, 8894, 8895, 10471, 11112, 11365, 11366, 19176, 19177, 19178, 19256, 19257, 21118, 23449, 23452, 28645, 28650, 29171, 29172,
		32126, 32128, 33183, 33184, 33191, 33192, 35134, 35135, 35136, 36185, 36186, 36187, 36188, 36201, 36202, 36203, 36204, 36606, 36607, 36608,
		36609, 36612, 37849, 37850, 37851, 37852, 37853, 37854, 37855, 37856, 38121, 38122, 38123, 38124, 38125, 38126, 38127, 38128, 38646, 38649,
		39215, 39216, 39217, 39221, 39222, 39223, 40202, 40203, 40204, 40208, 40209, 40210, 45037, 45752, 47422, 49562, 57530, 57780, 64920, 71676,
		71679, 71707, 76355, 76713, 104572, 104573, 104574, 104957, 104958, 104959, 105037, 105184, 105222, 105955, 105956, 105958, 105959, 115197, 115198, 115201,
		115202, 122077, 122078, 122298, 122299, 141845, 141937, 141938, 141939, 149691, 149692, 149693, 149694, 149841, 149843, 149844, 149845, 149893, 165215, 165251,
		165431, 130592, 131519, 131520, 131532, 131533, 131758, 131822, 131823, 136692, 136732, 136939, 150762, 150763, 151011, 151012, 160020, 160116, 160175, 160180,
		160217, 901325	/* 142 unique Statin medication IDs total as defined by `hhazdev.CustomDataEntry.StatinMedicationList` */
		)
)
,

DmTx AS 
/* 
PB charge transactions attributed to Diabetes E08- E13 (T1D,T2D, others). 
A patient will have a row for each charge transaction unless deduped
 77411 patients, run time < 1 min 
*/
(
    SELECT
        ROW_NUMBER() OVER(PARTITION BY tx.PATIENT_ID ORDER BY tx.SERVICE_DATE ) DmTxPerPatient
        ,tx.TX_ID
        ,tx.SERVICE_DATE
        ,td.POST_DATE
        ,edg.REF_BILL_CODE
        ,edg.DX_NAME  
        ,edg.PAT_FRIENDLY_TEXT
        ,p.PAT_ID
        ,p.PAT_MRN_ID
    
    FROM ARPB_TRANSACTIONS tx
    JOIN TX_DIAG td
        ON tx.TX_ID = td.TX_ID
    JOIN CLARITY_EDG edg
        ON td.DX_ID = edg.DX_ID
    JOIN PATIENT p
        ON tx.PATIENT_ID = p.PAT_ID

    WHERE 1=1
    AND tx.SERVICE_DATE >= @StartDate
    AND tx.SERVICE_DATE < DATEADD(DAY,1,@EndDate)
    AND td.POST_DATE >= @StartDate
    AND td.POST_DATE < DATEADD(MONTH,1,@EndDate) /* 0.3% found to post after the service date */
    AND tx.TX_TYPE_C = 1  /*PB charge transactions */
    AND tx.VOID_DATE IS NULL  /* Exclude voided transactions */
    AND 
    (edg.REF_BILL_CODE LIKE 'E08%'
    OR edg.REF_BILL_CODE LIKE 'E09%'
    OR edg.REF_BILL_CODE LIKE 'E10%'
    OR edg.REF_BILL_CODE LIKE 'E11%'
    OR edg.REF_BILL_CODE LIKE 'E12%'
    OR edg.REF_BILL_CODE LIKE 'E13%'
    )
)

/*
/* Line Level 1058 count 'Table 2C/D Total N Patients with RA/PsA Aged 40-75 with Diabetes' */
SELECT *
FROM DmTx 
JOIN #PB_Dx_Cohort cohort
ON DmTx.PAT_ID = cohort.PAT_ID

WHERE 1=1
AND DmTxPerPatient = 1 /*dedup to get 1 charge per patient */
AND Age_At_EndDate BETWEEN 40 AND 75
*/

/*
/* 'Table 2C/D Total N Patients with RA/PsA Aged 40-75 with Diabetes' */
SELECT 
cohort.Diagnosis_Group
, COUNT(*) AS 'Table 2C/D Total N Patients with RA/PsA Aged 40-75 with Diabetes'

FROM DmTx 
JOIN #PB_Dx_Cohort cohort
ON DmTx.PAT_ID = cohort.PAT_ID

WHERE 1=1
AND DmTxPerPatient = 1 /*dedup to get 1 charge per patient */
AND Age_At_EndDate BETWEEN 40 AND 75

GROUP BY cohort.Diagnosis_Group
;
*/

------------------------------------------------------------------------------------------

/* Line Level 110 count 'Table 2C/D Patients on Statin with RA/PsA Aged 40-75 with Diabetes' */
/*
SELECT 
*

FROM MedList
JOIN #PB_Dx_Cohort cohort
ON MedList.PAT_ID = cohort.PAT_ID
JOIN DmTx 
ON MedList.PAT_ID = DmTx.PAT_ID 

WHERE 1=1
AND PatMedLastRevTm = 1 /*Dedup to get one medical list review time per patient  */
AND DmTxPerPatient = 1 /*dedup to get 1 charge per patient */
AND Age_At_EndDate BETWEEN 40 AND 75
;
*/

/* 'Table 2C/D Patients on Statin with RA/PsA Aged 40-75 with Diabetes' */
/*
SELECT 
cohort.Diagnosis_Group
, COUNT(*) AS 'Table 2C/D Patients on Statin with RA/PsA Aged 40-75 with Diabetes'

FROM MedList
JOIN #PB_Dx_Cohort cohort
ON MedList.PAT_ID = cohort.PAT_ID
JOIN DmTx 
ON MedList.PAT_ID = DmTx.PAT_ID 

WHERE 1=1
AND PatMedLastRevTm = 1 /*Dedup to get one medical list review time per patient  */
AND DmTxPerPatient = 1 /*dedup to get 1 charge per patient */
AND Age_At_EndDate BETWEEN 40 AND 75

GROUP BY cohort.Diagnosis_Group
;
*/

*/


------------------------------------------------------------------------------------------
/* Table 3A/3B Use by BMI Category in RA/PsA */
/*
DECLARE @StartDate DATE = '2021-01-01';
DECLARE @EndDate DATE = '2025-12-31';

With MedList AS 
/* 
Most rescent med list review times for each medication containing Statin active on their medication list regardless of Diagnosis by patient. 
A patient will have a row for each statin med they are on unless deduped
*/
(
	SELECT 
	ROW_NUMBER() OVER(PARTITION BY list.PAT_ID ORDER BY pat.MEDS_LAST_REV_TM DESC) AS PatMedLastRevTm
	,pat.MEDS_LAST_REV_TM
	,pat.PAT_MRN_ID
	,list.PAT_ID
	,ordm.ORDER_INST
	,med.MEDICATION_ID
	,med.NAME
	,med.GENERIC_NAME

	FROM MEDS_REV_LAST_LIST  list
	JOIN ORDER_MED ordm ON list.MEDICATION_ORDER_ID = ordm.ORDER_MED_ID
	JOIN CLARITY_MEDICATION med ON ordm.MEDICATION_ID = med.MEDICATION_ID
	JOIN PATIENT pat ON list.PAT_ID = pat.PAT_ID

	WHERE 1=1
	AND list.TAKING_YN = 'Y' /* 1 */
	AND ORDER_INST >= DATEADD(YEAR,-1,@StartDate)
	AND ORDER_INST < DATEADD(DAY,1,@EndDate)
	AND pat.MEDS_LAST_REV_TM >= @StartDate
	AND pat.MEDS_LAST_REV_TM < DATEADD(DAY,1, @EndDate)
	AND ordm.MEDICATION_ID IN(
		5021, 6466, 8894, 8895, 10471, 11112, 11365, 11366, 19176, 19177, 19178, 19256, 19257, 21118, 23449, 23452, 28645, 28650, 29171, 29172,
		32126, 32128, 33183, 33184, 33191, 33192, 35134, 35135, 35136, 36185, 36186, 36187, 36188, 36201, 36202, 36203, 36204, 36606, 36607, 36608,
		36609, 36612, 37849, 37850, 37851, 37852, 37853, 37854, 37855, 37856, 38121, 38122, 38123, 38124, 38125, 38126, 38127, 38128, 38646, 38649,
		39215, 39216, 39217, 39221, 39222, 39223, 40202, 40203, 40204, 40208, 40209, 40210, 45037, 45752, 47422, 49562, 57530, 57780, 64920, 71676,
		71679, 71707, 76355, 76713, 104572, 104573, 104574, 104957, 104958, 104959, 105037, 105184, 105222, 105955, 105956, 105958, 105959, 115197, 115198, 115201,
		115202, 122077, 122078, 122298, 122299, 141845, 141937, 141938, 141939, 149691, 149692, 149693, 149694, 149841, 149843, 149844, 149845, 149893, 165215, 165251,
		165431, 130592, 131519, 131520, 131532, 131533, 131758, 131822, 131823, 136692, 136732, 136939, 150762, 150763, 151011, 151012, 160020, 160116, 160175, 160180,
		160217, 901325	/* 142 unique Statin medication IDs total as defined by `hhazdev.CustomDataEntry.StatinMedicationList` */
		)
)
,
BMIRecordings AS 
/*
Patients BMI recordings. Dedup with LatestBMIRecording. 
*/
(
  SELECT
  ROW_NUMBER() OVER(PARTITION BY r.PAT_ID ORDER BY fm.RECORDED_TIME DESC) LatestBMIRecording
  ,TRY_CAST(fm.MEAS_VALUE AS NUMERIC)  BMI       
  ,fm.RECORDED_TIME                         
  ,r.PAT_ID                                 
  ,g.DISP_NAME                              

  FROM IP_FLWSHT_MEAS           fm
  JOIN IP_FLWSHT_REC      r  ON r.FSD_ID = fm.FSD_ID 
  LEFT JOIN IP_FLO_GP_DATA      g  ON g.FLO_MEAS_ID = fm.FLO_MEAS_ID

  WHERE 1=1
  AND fm.FLO_MEAS_ID = '301070'  /* DISP_NAME "BMI (Calculated)"" */
  AND fm.ISACCEPTED_YN  = 'Y' /* the flowsheet record was accepted */
  AND fm.RECORDED_TIME >= @StartDate
  AND fm.RECORDED_TIME < DATEADD(DAY,1,@EndDate)
  AND r.RECORD_DATE >= @StartDate
  AND r.RECORD_DATE < DATEADD(DAY,1,@EndDate)
)
,
BMICategories AS 
/* Categories: cdc.gov/bmi/adult-calculator/bmi-categories.html */
(
  SELECT 
  BMI
  ,CASE 
        WHEN BMI < 10 THEN 'Clinically inplausible --> check calculation'
        WHEN BMI >= 10 AND BMI < 18.5 THEN 'Underweight'                             
        WHEN BMI >= 18.5 AND BMI < 25 THEN 'Healthy Weight'   
        WHEN BMI >= 25 AND BMI < 30 THEN 'Overweight'   
        WHEN BMI >= 30 AND BMI < 35 THEN 'Obesity Class 1'    
        WHEN BMI >= 35 AND BMI < 40 THEN 'Obesity Class 2'  
        WHEN BMI >= 40 AND BMI < 90 THEN 'Obesity Class 3 (Severe Obesity)' 
        WHEN BMI >= 90 THEN 'Clinically inplausible --> check calculation'  
		ELSE 'BMI Missing'
        END AS BMICategory 
  ,RECORDED_TIME
  ,PAT_ID
  ,DISP_NAME


  FROM BMIRecordings 
  WHERE 1=1
  AND LatestBMIRecording = 1 /*Dedup to get one patient per row*/
)

/* Table 3A/B. Line Level (included other BMI categories too) BMI Category in RA/PsA */	
/*
SELECT
*
FROM BMICategories bmic
JOIN #PB_Dx_Cohort cohort ON bmic.PAT_ID = cohort.PAT_ID
 WHERE 1=1
;
*/

/* Table 3A/B. BMI Category in RA/PsA Total N */	
/*
SELECT
BMICategory
,cohort.Diagnosis_Group
,COUNT(*) BMIRecordingCount
FROM BMICategories bmic
JOIN #PB_Dx_Cohort cohort ON bmic.PAT_ID = cohort.PAT_ID
 WHERE 1=1
 AND BMI >= 25
 AND BMI < 90
GROUP BY 
BMICategory
,cohort.Diagnosis_Group
ORDER BY 
cohort.Diagnosis_Group DESC
, COUNT(*) DESC
;
*/


/* Line Level (included other BMI categories too) for Table 3A/B. Statin Use by BMI Category in RA/PsA on Statin */		
/*
SELECT
*
FROM BMICategories bmic
JOIN MedList ml ON CAST(bmic.RECORDED_TIME AS DATE) = CAST(ml.MEDS_LAST_REV_TM AS DATE) AND bmic.PAT_ID = ml.PAT_ID
JOIN #PB_Dx_Cohort cohort ON bmic.PAT_ID = cohort.PAT_ID
 WHERE 1=1
 AND PatMedLastRevTm = 1 /*Dedup to get one patient per row*/
;
*/

/* Table 3A/B. Statin Use by BMI Category in RA/PsA on Statin */	
/*
SELECT
BMICategory
,cohort.Diagnosis_Group
,COUNT(*) BMIRecordingCount
FROM BMICategories bmic
JOIN MedList ml ON CAST(bmic.RECORDED_TIME AS DATE) = CAST(ml.MEDS_LAST_REV_TM AS DATE) AND bmic.PAT_ID = ml.PAT_ID
JOIN #PB_Dx_Cohort cohort ON bmic.PAT_ID = cohort.PAT_ID
 WHERE 1=1
 AND PatMedLastRevTm = 1 /*Dedup to get one patient per row*/
 AND BMI >= 25
 AND BMI < 90
GROUP BY 
BMICategory
,cohort.Diagnosis_Group
ORDER BY 
cohort.Diagnosis_Group DESC
, COUNT(*) DESC
;
*/
*/

/*
Table 4. DXA Screening Rates Among Patients with Rheumatoid Arthritis Meeting Osteoporosis Screening Criteria		
Dexa scan orders non-cancelled and finalized per patient. dedup with LatestDXAOrder = 1
From `hhazdev.SharedOrderReporting.ImagingStudies`
*/
/*
DECLARE @StartDate DATE = '2021-01-01';
DECLARE @EndDate Date = '2025-12-31';


WITH DXAOrders AS 
/*
DESCRIPTION: Dexa scan orders non-cancelled and finalized per patient. dedup with LatestDXAOrder = 1
From `hhazdev.SharedOrderReporting.ImagingStudies`
*/
(
  SELECT 
  ROW_NUMBER() OVER (PARTITION BY stu.PAT_ID ORDER BY stu.ORDERING_DTTM DESC) LatestDXAOrder
  ,stu.ORDERING_DTTM                                                                      
  ,stu.PROC_CODE                                                                          
  ,stu.PROC_NAME                                                                          
  ,stu.PAT_ID                                                                             

  FROM        V_IMG_STUDY               stu
  LEFT JOIN   ZC_RADIOLOGY_STS          zrs ON      zrs.RADIOLOGY_STATUS_C   = stu.STUDY_STATUS_C

  WHERE 1=1
  AND ORDERING_DTTM >= @StartDate
  AND ORDERING_DTTM < DATEADD(DAY,1,@EndDate)
  AND PROC_CODE IN
    (
    'IMG2407',  /* DEXA BONE DENSITOMETRY AXIAL */
    'IMG7523',  /* DEXA EXTERNAL IMAGE */
    'IMG2741',  /* DEXA BONE DENSITOMETRY AXIAL W VFA */
    'IMG2361',  /* DEXA BONE DENSITOMETRY PERIPHERAL */
    'HM8',      /* HM DEXA SCAN */
    'IMG2408',  /* DEXA BONE DENSITOMETRY VERTEBRAL FX */
    'IMG3501'   /* DEXA W VFA AND TBS */
    )
  AND IS_CANCELED_YN = 'N' /* N indicates the order is neither canceled nor discontinued. ~ 92% DXA orders were not canceled */
  AND zrs.NAME = 'Final' /* Final study status (e.g. technician ended the exam, reading physician finalized the exam) ~ 2/3 DXA's finalized */
)
*/
-- , 
 /*
IndicationGroups AS
(
	SELECT 
		Diagnosis_Group
		,CASE 
			  WHEN Sex_Name = 'Female' AND Age_At_EndDate BETWEEN 50 AND 65 THEN 'Women age 50-64'
			  WHEN Sex_Name = 'Female' AND Age_At_EndDate >= 65 THEN 'Women >= 65 years'
			  WHEN Sex_Name = 'Male' AND Age_At_EndDate BETWEEN 50 AND 69 THEN 'Men age 50–69 years'
			  WHEN Sex_Name = 'Male' AND Age_At_EndDate >= 70 THEN 'Men >= 70 years'
			  ELSE NULL
		      End AS IndicationGroup
	,Age_At_EndDate
	,Sex_Name
	,PAT_ID
	,PAT_MRN_ID 
	
	FROM #PB_Dx_Cohort
	WHERE 1=1
	AND Diagnosis_Group = 'RA'
)
*/

/* Total RA Patients in Indication Group */
/*
SELECT 
IndicationGroup
,COUNT(*) AS IndicationGroupCount
FROM IndicationGroups
WHERE IndicationGroup IS NOT NULL
GROUP BY 
IndicationGroup
*/

/* Line Level Had ≥1 DXA (at any point in time) (n) */
/*
SELECT 
*
FROM DXAOrders dord 
JOIN IndicationGroups igrp ON dord.PAT_ID = igrp.PAT_ID
WHERE 1=1
AND LatestDXAOrder = 1 /*Dedup to get one patient per row*/
AND IndicationGroup IS NOT NULL
*/
/* Had ≥1 DXA (at any point in time) (n) */
/*
SELECT 
IndicationGroup
,COUNT(*) AS IndicationGroupCount
FROM DXAOrders dord 
JOIN IndicationGroups igrp ON dord.PAT_ID = igrp.PAT_ID
WHERE 1=1
AND LatestDXAOrder = 1 /*Dedup to get one patient per row*/
AND IndicationGroup IS NOT NULL
GROUP BY 
IndicationGroup
*/


/*
Table 4 Glucocorticoid use ≥5 mg ≥3 months based on documented med review time 3+ months apart containing Glucocorticoid. it It does not prove uninterrupted daily use between those reviews
GCP base query Designed for SSMS retrofit from 
`hhazdev.SharedOrderReporting.MedicationOrders`
*/

/*
,
GlucocorticoidReviewDetail AS
 /*Grain: One patient + medication review + medication order. */
(
  SELECT 
  list.MEDICATION_ORDER_ID
  ,medrev.MEDS_HX_REV_INSTANT
  ,list.CONTACT_SERIAL_NUM
  ,list.PAT_ID
  ,pat.PAT_MRN_ID
  ,ordm.ORDER_INST
  ,med.MEDICATION_ID
  ,med.GENERIC_NAME
  ,med.STRENGTH /* including all strengths, strength not documented consistently */


  FROM MEDS_REV_HX_LIST  list
  JOIN MEDS_REV_HX  medrev ON list.PAT_ID = medrev.PAT_ID AND list.LINE_COUNT = medrev.LINE_COUNT
  JOIN ORDER_MED ordm ON list.MEDICATION_ORDER_ID = ordm.ORDER_MED_ID
  JOIN CLARITY_MEDICATION med ON ordm.MEDICATION_ID = med.MEDICATION_ID
  JOIN PATIENT pat ON list.PAT_ID = pat.PAT_ID

  WHERE 1=1
  AND list.TAKING_YN = 'Y' /* 1 */
  AND medrev.MEDS_HX_REV_INSTANT >= @StartDate
  AND medrev.MEDS_HX_REV_INSTANT < DATEADD(DAY,1,@EndDate)
  AND ORDER_INST >= DATEADD(YEAR, -1,@StartDate)
  AND ORDER_INST < DATEADD(DAY,1,@EndDate)
  AND
	(
    UPPER(med.GENERIC_NAME) LIKE '%PREDNISONE%'
    OR UPPER(med.GENERIC_NAME) LIKE '%PREDNISOLONE%'
    OR UPPER(med.GENERIC_NAME) LIKE '%METHYLPREDNISOLONE%'
    OR UPPER(med.GENERIC_NAME) LIKE '%DEXAMETHASONE%'
    OR UPPER(med.GENERIC_NAME) LIKE '%HYDROCORTISONE%'
	)
)
,
GlucocorticoidReviews AS
(
    /* 
    Grain: One row per patient per medication review. 
    GROUP BY prevents duplication review count due to multiple med orders within the same review 
    For this query, the number of medications in the review is irrelevant as long as it is >=1. 
    */
    SELECT
         PAT_ID
        ,PAT_MRN_ID
        ,MEDS_HX_REV_INSTANT
        ,COUNT(*) AS MedCount
    
    FROM GlucocorticoidReviewDetail
   
    GROUP BY
         PAT_ID
        ,PAT_MRN_ID
        ,MEDS_HX_REV_INSTANT
)
,
GlucocorticoidPatientSummary AS
(
    /* 
    Grain:
      One row per patient.FirstTakingReview and LastTakingReview represent the
      earliest/latest study-period medication reviews
    */
    SELECT
         PAT_ID
        ,PAT_MRN_ID
        ,COUNT(*) AS ReviewCount
        ,MIN(MEDS_HX_REV_INSTANT) AS FirstTakingReview
        ,MAX(MEDS_HX_REV_INSTANT) AS LastTakingReview
        ,DATEDIFF(DAY,MIN(MEDS_HX_REV_INSTANT),MAX(MEDS_HX_REV_INSTANT)) AS TakingReviewSpanDays

    FROM GlucocorticoidReviews

    GROUP BY
         PAT_ID
        ,PAT_MRN_ID
)
*/

/* Table 4 Total RA Patients in Group using Glucocorticoid */
/*
SELECT 
* 
FROM GlucocorticoidPatientSummary glu
JOIN #PB_Dx_Cohort cohort ON glu.PAT_ID = cohort.PAT_ID
WHERE 1=1
AND TakingReviewSpanDays > 90 
AND Diagnosis_Group = 'RA'
*/

/* Table 4 Total RA Patients in Group using Glucocorticoid & Had ≥1 DXA (at any point in time) */
/*
SELECT 
* 
FROM GlucocorticoidPatientSummary glu
JOIN #PB_Dx_Cohort cohort ON glu.PAT_ID = cohort.PAT_ID
JOIN DXAOrders dord ON glu.PAT_ID = dord.PAT_ID
WHERE 1=1
AND TakingReviewSpanDays > 90 
AND Diagnosis_Group = 'RA'
AND LatestDXAOrder = 1 /*Dedup to get one patient per row*/
*/

/* Table 5 "Table 5. Rate of Vertebral Compression Fractures Among RA Patients */
/*			
DECLARE @StartDate DATE ='2021-01-01';
DECLARE @EndDate DATE = '2025-12-31';

/*
With PbTxPat AS 
/* 
PB charge transactions attributed to Vertebral Compression Fractures. 
A patient will have a row for each charge transaction unless deduped
*/

(
    SELECT
        ROW_NUMBER() OVER(PARTITION BY tx.PATIENT_ID ORDER BY tx.SERVICE_DATE ) TxPerPatient
        ,tx.TX_ID
        ,tx.SERVICE_DATE
        ,td.POST_DATE
        ,edg.REF_BILL_CODE
        ,edg.DX_NAME  
        ,edg.PAT_FRIENDLY_TEXT
        ,p.PAT_ID
        ,p.PAT_MRN_ID
    
    FROM ARPB_TRANSACTIONS tx
    JOIN TX_DIAG td
        ON tx.TX_ID = td.TX_ID
    JOIN CLARITY_EDG edg
        ON td.DX_ID = edg.DX_ID
    JOIN PATIENT p
        ON tx.PATIENT_ID = p.PAT_ID

    WHERE 1=1
    AND tx.SERVICE_DATE >= @StartDate
    AND tx.SERVICE_DATE < DATEADD(DAY,1,@EndDate)
    AND td.POST_DATE >= @StartDate
    AND td.POST_DATE < DATEADD(MONTH,1,@EndDate) 
    AND tx.TX_TYPE_C = 1  /*PB charge transactions */
    AND tx.VOID_DATE IS NULL  /* Exclude voided transactions */
    AND 
    (
    edg.REF_BILL_CODE LIKE 'M80%'
    OR edg.REF_BILL_CODE LIKE 'M48.5%'
    )
)
,
*/
/*
WITH PBCohortSubGroups AS
(
	SELECT 
	CASE
		WHEN Sex_Name = 'Female' AND Age_At_EndDate BETWEEN 50 AND 64 THEN 'Women (Age 50–64), RA'
		WHEN Sex_Name = 'Male' AND Age_At_EndDate BETWEEN 50 AND 69 THEN 'Men (Age 50–69), RA'
		ELSE NULL
		END AS SubGroups
	,*
	FROM #PB_Dx_Cohort
	WHERE Diagnosis_Group = 'RA'
)
*/
/* Table 5 line level Total  (n)
  */
/*
SELECT 
*
FROM PBCohortSubGroups pcs
WHERE 1=1
AND SubGroups IS NOT NULL
*/

/* Table 5 total by subgroup */
/*
SELECT 
SubGroups
,COUNT(*) AS SubGroupCount
FROM PBCohortSubGroups pcs
WHERE 1=1
AND SubGroups IS NOT NULL
GROUP BY 
SubGroups
*/

/* Table 5 line level Patients with Vertebral Compression Fracture (n)
  */
/*
SELECT 
*
FROM PbTxPat ptp
JOIN PBCohortSubGroups pcs ON ptp.PAT_ID = pcs.PAT_ID
WHERE 1=1
AND TxPerPatient = 1 /*dedup to get 1 charge per patient */
AND SubGroups IS NOT NULL

*/

/* Table 5 Patients with Vertebral Compression Fracture (n) by subgroup */
/*
SELECT 
SubGroups
,COUNT(*) AS SubGroupCount
FROM PbTxPat ptp
JOIN PBCohortSubGroups pcs ON ptp.PAT_ID = pcs.PAT_ID
WHERE 1=1
AND TxPerPatient = 1 /*dedup to get 1 charge per patient */
AND SubGroups IS NOT NULL
GROUP BY 
SubGroups
*/

*/