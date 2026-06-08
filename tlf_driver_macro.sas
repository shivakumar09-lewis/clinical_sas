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

proc freq data=work.ae; tables AEBODSYS AESEV AESER / nocum; run;
/* ── ADAE: TRTEMFL derivation ── */
data work.adae_base;
  /* Merge AE with ADSL to get TRTSDT */
  if _N_ = 1 then do;
    declare hash h(dataset:'work.adsl_base');
    h.definekey('USUBJID');
    h.definedata('TRTSDT');
    h.definedone();
  end;

  set work.ae;

  /* Look up this subject's TRTSDT */
  rc = h.find();

  /* Convert AE start date to SAS date */
  ASTDT = input(AESTDTC, yymmdd10.);
  format ASTDT date9.;

  /* TRTEMFL: Y if AE started on or after treatment start */
  if rc = 0 and TRTSDT ne . and ASTDT >= TRTSDT then TRTEMFL = 'Y';
  else TRTEMFL = '';

  /* AOCCIFL: First occurrence flag per subject per preferred term */
  /* WORSTFL: Worst severity flag per subject per preferred term */
  drop rc;
run;

/* Sort and derive AOCCIFL (first AE per subject per SOC) */
proc sort data=work.adae_base; by USUBJID AEBODSYS ASTDT; run;
data work.adae;
  set work.adae_base;
  by USUBJID AEBODSYS;
  if first.AEBODSYS then AOCCIFL = 'Y';
  else AOCCIFL = '';
run;

proc freq data=work.adae; tables TRTEMFL AOCCIFL / nocum; run;
proc print data=work.adae noobs;
  var USUBJID AEDECOD AESTDTC TRTEMFL AOCCIFL AETOXGR;
run;
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
data work.adsl_base;
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
proc contents data=work.adsl_base; run;
proc print data=work.adsl_base noobs; 
  var USUBJID TRT01P TRT01PN TRTSDT TRTEDT TRTDUR SAFFL AGEGR1;
run;
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
data work.adsl_base;
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
proc contents data=work.adsl_base; run;
proc print data=work.adsl_base noobs; 
  var USUBJID TRT01P TRT01PN TRTSDT TRTEDT TRTDUR SAFFL AGEGR1;
run;

/* ── Lab Shift Table — ALT ── */
/* Get baseline BNRIND and post-baseline ANRIND */
data work.shift_input;
  set work.adlb_raw;
  where PARAMCD = 'ALT' and ANL01FL ne 'Y'; /* Post-baseline only */
  /* Worst post-baseline value per subject */
run;

proc sort data=work.shift_input; by USUBJID PARAMCD AVAL; run;
data work.shift_worst;
  set work.shift_input;
  by USUBJID PARAMCD;
  if last.PARAMCD;  /* Keep worst (last after sort ascending = not worst — re-sort descending) */
run;

proc sort data=work.adlb_raw(where=(PARAMCD='ALT' and ANL01FL='Y'))
          out=work.baseline_alt;
  by USUBJID;
run;
data work.baseline_alt; set work.baseline_alt;
  BNRIND_ALT = BNRIND;
  keep USUBJID BNRIND_ALT;
run;

proc sort data=work.adlb_raw(where=(PARAMCD='ALT' and ANL01FL ne 'Y'))
          out=work.postbl_alt;
  by USUBJID descending AVAL;
run;
data work.worst_alt;
  set work.postbl_alt;
  by USUBJID;
  if first.USUBJID;
  ANRIND_ALT = ANRIND;
  keep USUBJID ANRIND_ALT AVAL;
run;

data work.shift_table;
  merge work.baseline_alt work.worst_alt;
  by USUBJID;
run;

proc freq data=work.shift_table;
  tables BNRIND_ALT * ANRIND_ALT / nocum nopercent;
  title "ALT Lab Shift Table: Baseline × Worst Post-Baseline";
run;
/* ── %tlf_driver — Multi-table driver macro ── */

/* Step 1: Create a parameter dataset — each row = one output */
data work.tlf_params;
  length pgm $40 outfile $80 popfl $8 title1 $100;
  infile datalines dsd;
  input pgm:$40. outfile:$80. popfl:$8. title1:$100.;
  datalines;
ae_table,/home/sasuser.v94/output/T14_3_1_AE_TEAE.rtf,SAFFL,Table 14.3.1 — Treatment-Emergent Adverse Events
ae_table,/home/sasuser.v94/output/T14_3_2_AE_SERIOUS.rtf,SAFFL,Table 14.3.2 — Serious Adverse Events
;
run;

/* Step 2: Driver macro loops through parameter dataset */
%macro tlf_driver(paramds=work.tlf_params);
  /* Count rows */
  %let nrows = 0;
  proc sql noprint;
    select count(*) into :nrows from &paramds;
  quit;

  %put NOTE: TLF Driver starting — &nrows tables to produce;

  /* Loop through each row */
  %do i = 1 %to &nrows;
    /* Extract parameters for this row */
    proc sql noprint;
      select pgm, outfile, popfl, title1
      into :pgm_i, :outfile_i, :popfl_i, :title1_i
      from &paramds
      where monotonic() = &i;
    quit;

    %put NOTE: Running table &i — %trim(&pgm_i);
    %put NOTE: Output: %trim(&outfile_i);

    /* Call the appropriate macro */
    %if %trim(&pgm_i) = ae_table %then %do;
      %ae_table(
        indata  = work.ae,
        popds   = work.adsl,
        popfl   = %trim(&popfl_i),
        arm     = TRT01P,
        outfile = %trim(&outfile_i)
      );
    %end;

    %put NOTE: Table &i complete.;
  %end;

  %put NOTE: TLF Driver complete — &nrows tables produced;
%mend tlf_driver;

/* ── Run the driver ── */
%tlf_driver(paramds=work.tlf_params);