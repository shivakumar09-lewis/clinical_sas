/* ── SDTM LB: Laboratory Test Results ── */
data work.lb;
  length STUDYID $20 DOMAIN $2 USUBJID $20 LBSEQ 8
         LBTESTCD $8 LBTEST $40 LBCAT $16
         LBORRES $20 LBORRESU $16 LBSTRESC $20
         LBSTRESN 8 LBSTRESU $16 LBSTNRLO 8 LBSTNRHI 8
         LBNRIND $8 LBBLFL $1 VISITNUM 8 VISIT $20 LBDTC $10;
  infile datalines dsd missover;
  input STUDYID:$20. DOMAIN:$2. USUBJID:$20. LBSEQ
        LBTESTCD:$8. LBTEST:$40. LBCAT:$16.
        LBORRES:$20. LBORRESU:$16. LBSTRESC:$20.
        LBSTRESN LBSTRESU:$16. LBSTNRLO LBSTNRHI
        LBNRIND:$8. LBBLFL:$1. VISITNUM VISIT:$20. LBDTC:$10.;
  datalines;
CDISCPILOT01,LB,CDISCPILOT01-01-001,1,ALT,Alanine Aminotransferase,CHEMISTRY,22,U/L,22,22,U/L,7,56,NORMAL,Y,1,BASELINE,2020-01-14
CDISCPILOT01,LB,CDISCPILOT01-01-001,2,ALT,Alanine Aminotransferase,CHEMISTRY,85,U/L,85,85,U/L,7,56,HIGH,N,2,WEEK 4,2020-02-12
CDISCPILOT01,LB,CDISCPILOT01-01-001,3,ALT,Alanine Aminotransferase,CHEMISTRY,175,U/L,175,175,U/L,7,56,HIGH,N,3,WEEK 8,2020-03-11
CDISCPILOT01,LB,CDISCPILOT01-01-001,4,AST,Aspartate Aminotransferase,CHEMISTRY,28,U/L,28,28,U/L,10,40,NORMAL,Y,1,BASELINE,2020-01-14
CDISCPILOT01,LB,CDISCPILOT01-01-001,5,AST,Aspartate Aminotransferase,CHEMISTRY,95,U/L,95,95,U/L,10,40,HIGH,N,2,WEEK 4,2020-02-12
CDISCPILOT01,LB,CDISCPILOT01-01-003,6,ALT,Alanine Aminotransferase,CHEMISTRY,18,U/L,18,18,U/L,7,56,NORMAL,Y,1,BASELINE,2020-02-01
CDISCPILOT01,LB,CDISCPILOT01-01-003,7,ALT,Alanine Aminotransferase,CHEMISTRY,32,U/L,32,32,U/L,7,56,NORMAL,N,2,WEEK 4,2020-03-01
CDISCPILOT01,LB,CDISCPILOT01-01-005,8,HB,Hemoglobin,HEMATOLOGY,13.2,g/dL,13.2,13.2,g/dL,11.5,17.5,NORMAL,Y,1,BASELINE,2020-03-01
CDISCPILOT01,LB,CDISCPILOT01-01-005,9,HB,Hemoglobin,HEMATOLOGY,9.5,g/dL,9.5,9.5,g/dL,11.5,17.5,LOW,N,2,WEEK 4,2020-04-01
CDISCPILOT01,LB,CDISCPILOT01-01-005,10,CREAT,Creatinine,CHEMISTRY,0.9,mg/dL,0.9,0.9,mg/dL,0.6,1.2,NORMAL,Y,1,BASELINE,2020-03-01
;
run;

proc freq data=work.lb; tables LBTESTCD LBNRIND / nocum; run;
/* ── ADLB Step 1: Extract baseline values ── */
data work.lb_base;
  set work.lb;
  where LBBLFL = 'Y';
  rename LBSTRESN = BASE LBNRIND = BNRIND;
  keep USUBJID LBTESTCD LBSTRESN LBNRIND;
  rename LBSTRESN=BASE LBNRIND=BNRIND;
run;

/* ── ADLB Step 2: Merge all LB records with baseline ── */
proc sort data=work.lb; by USUBJID LBTESTCD; run;
proc sort data=work.lb_base; by USUBJID LBTESTCD; run;

data work.adlb_raw;
  merge work.lb(in=a) work.lb_base(in=b);
  by USUBJID LBTESTCD;
  if a;

  /* Rename for ADaM conventions */
  AVAL   = LBSTRESN;         /* Analysis value */
  AVALU  = LBSTRESU;         /* Units */
  ANRLO  = LBSTNRLO;        /* Normal range low */
  ANRHI  = LBSTNRHI;        /* Normal range high */
  ANRIND = LBNRIND;         /* Post-baseline NRI */
  PARAMCD = LBTESTCD;
  PARAM   = LBTEST;

  /* Derive CHG and PCHG */
  if BASE ne . then do;
    CHG  = AVAL - BASE;
    if BASE ne 0 then PCHG = (AVAL - BASE) / BASE * 100;
  end;

  /* Analysis date */
  ADT  = input(LBDTC, yymmdd10.);
  format ADT date9.;

  /* Baseline flag for ADaM */
  if LBBLFL = 'Y' then ANL01FL = 'Y';

  /* Lab shift flags — clinical thresholds */
  /* ALT >3x ULN = Grade 2+ hepatotoxicity */
  if PARAMCD = 'ALT' and AVAL > 3 * ANRHI then ALT_3XULN = 'Y';
  else ALT_3XULN = '';

  /* Hb <10 g/dL = Grade 2 anaemia threshold */
  if PARAMCD = 'HB' and AVAL < 10 then HB_LOW = 'Y';
  else HB_LOW = '';

run;

/* ── ADLB Step 3: Verify ── */
proc print data=work.adlb_raw noobs;
  where PARAMCD in ('ALT','HB');
  var USUBJID PARAMCD VISITNUM BASE AVAL CHG PCHG ANRIND ALT_3XULN HB_LOW;
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