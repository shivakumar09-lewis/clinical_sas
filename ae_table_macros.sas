/* ── DM: Demographic Dataset ── */
data work.dm;
  length STUDYID $20 DOMAIN $2 USUBJID $20 SUBJID $8
         RFSTDTC $10 RFENDTC $10 AGE 8 AGEU $6 SEX $1
         RACE $50 ETHNIC $25 ARMCD $8 ARM $40 COUNTRY $3;
  infile datalines dsd missover;
  input STUDYID:$20. DOMAIN:$2. USUBJID:$20. SUBJID:$8.
        RFSTDTC:$10. RFENDTC:$10. AGE AGEU:$6. SEX:$1.
        RACE:$50. ETHNIC:$25. ARMCD:$8. ARM:$40. COUNTRY:$3.;
  datalines;
CDISCPILOT01,DM,CDISCPILOT01-01-001,001,2020-01-15,2020-07-15,45,YEARS,M,WHITE,NOT HISPANIC OR LATINO,A,Drug A,USA
CDISCPILOT01,DM,CDISCPILOT01-01-002,002,2020-01-20,2020-06-20,52,YEARS,F,ASIAN,NOT HISPANIC OR LATINO,B,Placebo,IND
CDISCPILOT01,DM,CDISCPILOT01-01-003,003,2020-02-01,2020-08-01,38,YEARS,M,BLACK OR AFRICAN AMERICAN,NOT HISPANIC OR LATINO,A,Drug A,USA
CDISCPILOT01,DM,CDISCPILOT01-01-004,004,2020-02-10,2020-07-10,61,YEARS,F,WHITE,HISPANIC OR LATINO,B,Placebo,USA
CDISCPILOT01,DM,CDISCPILOT01-01-005,005,2020-03-01,2020-09-01,47,YEARS,M,ASIAN,NOT HISPANIC OR LATINO,A,Drug A,IND
CDISCPILOT01,DM,CDISCPILOT01-01-006,006,2020-03-15,2020-09-15,55,YEARS,F,WHITE,NOT HISPANIC OR LATINO,B,Placebo,USA
;
run;

/* Verify */
proc freq data=work.dm; tables SEX RACE ARM / nocum nopercent; run;
proc print data=work.dm noobs; run;
/* ── ADSL: Subject-Level Analysis Dataset ── */
/* Step 1: Convert RFSTDTC and RFENDTC from character to SAS date */
data work.adsl;
  set work.dm;

  /* Convert ISO 8601 dates to SAS numeric dates */
  TRTSDT = input(RFSTDTC, yymmdd10.);  /* Treatment Start Date */
  TRTEDT = input(RFENDTC, yymmdd10.);  /* Treatment End Date */
  format TRTSDT TRTEDT date9.;

  /* Treatment duration */
  TRTDUR = TRTEDT - TRTSDT + 1;

  /* Planned and actual treatment */
  TRT01P  = ARM;    /* Planned */
  TRT01A  = ARM;    /* Actual (same in this dataset) */
  TRT01PN = ifn(ARMCD='A', 1, 2);  /* Numeric planned: 1=Drug A, 2=Placebo */
  TRT01AN = TRT01PN;

  /* Population flags */
  RANDFL  = 'Y';  /* Randomised flag — all subjects here are randomised */
  SAFFL   = 'Y';  /* Safety Analysis Set — received ≥1 dose */
  FASFL   = 'Y';  /* Full Analysis Set */
  PPROTFL = 'Y';  /* Per Protocol */

  /* Age group */
  if AGE < 65 then AGEGR1 = '<65';
  else AGEGR1 = '>=65';
  AGEGR1N = ifn(AGE < 65, 1, 2);

  /* Keep only ADSL variables */
  keep STUDYID USUBJID SUBJID SITEID AGE AGEU SEX RACE ETHNIC COUNTRY
       ARMCD ARM ACTARMCD ACTARM TRT01P TRT01A TRT01PN TRT01AN
       TRTSDT TRTEDT TRTDUR RFSTDTC RFENDTC
       RANDFL SAFFL FASFL PPROTFL AGEGR1 AGEGR1N;
run;

/* Verify ADSL */
proc contents data=work.adsl; run;
proc print data=work.adsl noobs; 
  var USUBJID TRT01P TRT01PN TRTSDT TRTEDT TRTDUR SAFFL AGEGR1;
run;
/* ── AE: Adverse Events Dataset ── */
data work.ae;
  length STUDYID $20 DOMAIN $2 USUBJID $20 AESEQ 8
         AETERM $200 AEDECOD $200 AEBODSYS $200
         AESEV $16 AESER $1 AESTDTC $10 AEENDTC $10
         AETOXGR $8 AEOUT $40 AEREL $40 AEACN $40;
  infile datalines dsd missover;
  input STUDYID:$20. DOMAIN:$2. USUBJID:$20. AESEQ
        AETERM:$200. AEDECOD:$200. AEBODSYS:$200.
        AESEV:$16. AESER:$1. AESTDTC:$10. AEENDTC:$10.
        AETOXGR:$8. AEOUT:$40. AEREL:$40. AEACN:$40.;
  datalines;
CDISCPILOT01,AE,CDISCPILOT01-01-001,1,NAUSEA,Nausea,Gastrointestinal disorders,MILD,N,2020-01-20,2020-01-25,1,RECOVERED/RESOLVED,RELATED,DOSE NOT CHANGED
CDISCPILOT01,AE,CDISCPILOT01-01-001,2,ALT INCREASED,Alanine aminotransferase increased,Investigations,MODERATE,Y,2020-02-10,2020-03-15,3,RECOVERED/RESOLVED,RELATED,DRUG WITHDRAWN
CDISCPILOT01,AE,CDISCPILOT01-01-003,1,FATIGUE,Fatigue,General disorders,MILD,N,2020-02-05,2020-02-20,1,RECOVERED/RESOLVED,POSSIBLY RELATED,DOSE NOT CHANGED
CDISCPILOT01,AE,CDISCPILOT01-01-003,2,NEUTROPENIA,Neutrophil count decreased,Investigations,SEVERE,Y,2020-03-01,2020-04-01,3,RECOVERED/RESOLVED,RELATED,DRUG INTERRUPTED
CDISCPILOT01,AE,CDISCPILOT01-01-005,1,RASH,Rash maculo-papular,Skin and subcutaneous tissue disorders,MILD,N,2020-03-10,2020-03-20,2,RECOVERED/RESOLVED,RELATED,DOSE NOT CHANGED
CDISCPILOT01,AE,CDISCPILOT01-01-002,1,HEADACHE,Headache,Nervous system disorders,MILD,N,2020-01-25,2020-01-28,1,RECOVERED/RESOLVED,UNLIKELY RELATED,DOSE NOT CHANGED
;
run;
proc sort data=work.ae; by USUBJID; run;
proc sort data=work.adsl; by USUBJID; run;

data work.ae_adsl;
  merge work.ae(in=a) work.adsl(in=b);
  by USUBJID;
  if a;   /* keep AE records only */
run;
proc freq data=work.ae_adsl noprint;
  tables TRT01P*AEBODSYS / out=work._ae_counts;
run;
ods rtf file="/home/sasuser.v94/Table14.3.1_AE_Summary.rtf";

proc report data=work._ae_counts nowd;
  column TRT01P AEBODSYS COUNT;

  define TRT01P  / group "Treatment";
  define AEBODSYS / group "System Organ Class";
  define COUNT   / analysis "Count";

run;

ods rtf close;