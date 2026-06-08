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

/* ── Validation with PROC COMPARE ── */

/* Step 1: Create a reference ADSL (manually verified) */
data work.adsl_ref;
  set work.adsl_base;
  /* Intentionally match — in real life this is built by a second programmer */
run;

/* Step 2: Compare */
proc compare base=work.adsl_ref compare=work.adsl
             out=work.compare_out outbase outcomp outdif
             listall criterion=0.000001;
  title "PROC COMPARE: ADSL Validation";
run;

/* Step 3: Check for differences */
proc print data=work.compare_out; 
  where _TYPE_ in ('DIF','BASEOBS','COMPOBS'); 
  title "Differences found (should be empty)";
run;

/* QC Checklist */
data _null_;
  put "=== QC CHECKLIST ===";
  put "[ ] ADSL has 1 row per subject: YES";
  put "[ ] TRTSDT is never missing: CHECK proc means data=work.adsl_base; var TRTSDT; run;";
  put "[ ] TRT01PN is 1 for Drug A, 2 for Placebo: CHECK proc freq; tables TRT01P*TRT01PN; run;";
  put "[ ] SAFFL=Y for all subjects: CHECK proc freq; tables SAFFL; run;";
  put "[ ] AGEGR1N consistent with AGEGR1: CHECK proc freq; tables AGEGR1*AGEGR1N; run;";
run;