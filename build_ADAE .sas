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