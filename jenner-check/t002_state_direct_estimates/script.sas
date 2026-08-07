/* -------------------------------------------------------------------------- *
 * t002_state_direct_estimates -- exercises the %report macro from MENDS
 *   source: 4_Small_Area_Estimation/State_Direct_Estimates.sas
 *
 * The %report macro below is the repo's, with one line changed: its input
 * "set weights.&ext" (a P: libname the pipeline reads) now reads a WORK
 * dataset of the same shape (aa_seq rakewgt zip state state_fips pph htnyn
 * htnc). Everything the macro does -- weighted PROC FREQ with outpct, the
 * crude/modeled stacking, PROC SUMMARY with CV, the closed-form standard
 * error se = 100*sqrt(p(1-p)/n), and the crosswalk merge -- is unchanged.
 * The final PROC EXPORT (a P: path) is outside the macro and not included.
 * -------------------------------------------------------------------------- */

/* State-name crosswalk (the pipeline reads this from a .sas7bdat; here a
   small inline stand-in keyed on state_fips, as the merge expects). */
data crosswalk;
    length state_fips $2 state_name $20;
    input state_fips $ state_name $;
    datalines;
06 California
17 Illinois
36 New_York
48 Texas
;
run;

proc sort data = crosswalk;
    by state_fips;
run;

/* Synthetic monthly weights extract, one row per patient, with the columns
   State_Direct_Estimates.sas keeps: a raked weight and the hypertension
   flags (pph, htnyn = has-HTN, htnc = HTN-controlled). */
data mends_weights;
    length aa_seq 8 zip $5 state $2 state_fips $2 pph $1 htnyn $1 htnc $1;
    input aa_seq rakewgt zip $ state $ state_fips $ pph $ htnyn $ htnc $;
    datalines;
1 118.4 90001 CA 06 1 1 0
2 132.7 90002 CA 06 1 1 1
3 97.2 90003 CA 06 0 0 .
4 145.1 90004 CA 06 2 1 0
5 110.9 90005 CA 06 1 1 1
6 128.3 60601 IL 17 0 0 .
7 101.6 60602 IL 17 1 1 0
8 156.8 60603 IL 17 2 1 1
9 90.4 60604 IL 17 1 1 0
10 143.5 60605 IL 17 0 0 .
11 122.0 10001 NY 36 1 1 1
12 137.9 10002 NY 36 2 1 0
13 99.7 10003 NY 36 0 0 .
14 148.2 10004 NY 36 1 1 1
15 115.6 10005 NY 36 1 1 0
16 130.5 73301 TX 48 0 0 .
17 108.8 73344 TX 48 1 1 1
18 151.3 75001 TX 48 2 1 0
19 94.9 75002 TX 48 1 1 0
20 141.7 75003 TX 48 1 1 1
;
run;

%macro report(ext, mmyy, out);

data state_weights;
	set &ext (keep = aa_seq rakewgt zip state state_fips pph htnyn htnc);
length year_month $7.;
year_month = &mmyy;

run;

proc freq data = state_weights;
	table pph * htnyn * htnc / list missing;
run;

proc freq data = state_weights noprint;
	where htnyn in("0","1");
	table year_month * STATE_FIPS * htnyn / list missing outpct out = model1
						(keep = year_month STATE_FIPS htnyn pct_row);
	weight rakewgt;
run;

proc freq data = state_weights noprint;
	where htnc in("0","1");
	table year_month * STATE_FIPS * htnc / list missing outpct out = model2
						(keep = year_month STATE_FIPS htnc pct_row);
	weight rakewgt;
run;

proc freq data = state_weights noprint;
	where htnyn in("0","1");
	table year_month * STATE_FIPS * htnyn / list missing outpct out = crude1
						(keep = year_month STATE_FIPS htnyn pct_row);
run;

proc freq data = state_weights noprint;
	where htnc in("0","1");
	table year_month * STATE_FIPS * htnc / list missing outpct out = crude2
						(keep = year_month STATE_FIPS htnc pct_row);
run;

proc summary data = state_weights nway noprint;
	where htnyn in("0","1");
  class year_month STATE_FIPS;
   var rakewgt;
   output
      out = samp1 (drop = _:)
      N = N_SAMP CV = CV;
run;

data samp1a;
	set samp1 (in=ina) samp1 (in=inb);

length Condition $5.;
Condition = "HTN";

length est_type $7.;
if ina then est_type = "crude";
else if inb then est_type = "modeled";

run;

proc summary data = state_weights nway noprint;
	where htnc in("0","1");
  class year_month STATE_FIPS;
   var rakewgt;
   output
      out = samp2 (drop = _:)
      N = N_SAMP CV = CV;
run;

data samp2a;
	set samp2 (in=ina) samp2 (in=inb);

length Condition $5.;
Condition = "HTN-C";

length est_type $7.;
if ina then est_type = "crude";
else if inb then est_type = "modeled";

run;

data htnyn;
	set crude1 (in=ina rename=pct_row=prevalence) model1 (in=inb rename=pct_row=prevalence);
by year_month STATE_FIPS htnyn;

if htnyn = "1";
drop htnyn;

length est_type $7.;
if ina then est_type = "crude";
else if inb then est_type = "modeled";
run;

data htnc;
	set crude2 (in=ina rename=pct_row=prevalence) model2 (in=inb rename=pct_row=prevalence);
by year_month STATE_FIPS htnc;

if htnc = "1";
drop htnc;

length est_type $7.;
if ina then est_type = "crude";
else if inb then est_type = "modeled";
run;

proc sort data = htnyn; by year_month est_type STATE_FIPS; run;
proc sort data = samp1a; by year_month est_type STATE_FIPS; run;

data htnyn;
	merge htnyn samp1a;
by year_month est_type STATE_FIPS;

if prevalence = . then prevalence = 0;
if CV = . then CV = 0;

if est_type = "crude" then se = 100*sqrt((prevalence/100)*(1-prevalence/100)/N_SAMP);

run;

proc sort data = htnc; by year_month est_type STATE_FIPS; run;
proc sort data = samp2a; by year_month est_type STATE_FIPS; run;

data htnc;
	merge htnc samp2a;
by year_month est_type STATE_FIPS;

if prevalence = . then prevalence = 0;
if CV = . then CV = 0;

if est_type = "crude" then se = 100*sqrt((prevalence/100)*(1-prevalence/100)/N_SAMP);

run;

data &out;
	set htnyn htnc;
run;

proc sort data = &out;	by state_fips; run;

data &out;
	merge &out (in=ina) crosswalk;
by state_fips;
if ina;
run;

proc sort data = &out; by condition est_type state_fips; run;

proc summary data = &out nway print n nmiss sum mean cv min median max;
  class condition est_type;
   var prevalence se CV N_SAMP;
run;

%mend;

%report(ext=mends_weights, mmyy="2023-01", out=jan_2023);
