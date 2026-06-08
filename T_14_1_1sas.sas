/* ── Table 14.1.1 Demographics ── */
 ods rtf file="/home/sasuser.v94/output/Table14.1.1_Demographics.rtf";
; 

title1 "Table 14.1.1";
title2 "Summary of Demographics and Baseline Characteristics";
title3 "Safety Analysis Set";
footnote1 "N = number of subjects in Safety Analysis Set";
footnote2 "SD = standard deviation";

/* Age summary */
proc means data=work.adsl_base n mean std min max maxdec=1 noprint;
  class TRT01P;
  var AGE;
  output out=age_stats n=N mean=MEAN std=STD min=MIN max=MAX;
run;

proc report data=work.adsl_base headline headskip;
  column TRT01P, (AGE SEX RACE);
  define TRT01P / across 'Treatment' order=data;
  define AGE    / analysis mean format=5.1 'Age (years) Mean (SD)';
  define SEX    / display 'Sex n (%)';
  define RACE   / display 'Race n (%)';
run;

/* Cleaner approach — PROC TABULATE for n and % */
proc tabulate data=work.adsl_base format=5. missing;
  class TRT01P SEX RACE AGEGR1;
  var AGE;
  table (SEX=' ' ALL='Total')*(N='n' COLPCTN='%') ,
        TRT01P=' '/ box='Characteristic';
  table (RACE=' ' ALL='Total')*(N='n' COLPCTN='%') ,
        TRT01P=' ' / box='Race';
  table AGE=' '*(MEAN='Mean' STD='SD' MIN='Min' MAX='Max') ,
        TRT01P=' ' / box='Age';
run;

ods rtf close;
title; footnote;