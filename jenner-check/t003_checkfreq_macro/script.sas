/* -------------------------------------------------------------------------- *
 * t003_checkfreq_macro -- exercises the sample-size-check macros from MENDS
 *   source: 2_Weighting/2_0_quickstart_MENDS_weighting.sas
 *           (called as shown in 2_Weighting/2_2_Weighting_national.sas)
 *
 * %checkfreq / %checkfreq2 (verbatim below) are the repo's one- and two-way
 * PROC FREQ wrappers that tabulate each raking factor to an out= dataset
 * with a COUNT column. The national weighting step then stacks those counts
 * and flags any cell with count < 20 as "sample size is insufficient". This
 * bundle supplies a small synthetic analysis extract (the columns
 * %weights_national reads: age8, raceeth4, ru2, region, sex, insurance2,
 * age3) and reproduces that check on the WORK data -- no P: libname needed.
 * -------------------------------------------------------------------------- */

/* Synthetic analysis extract, one row per respondent, carrying the raking
   factors the sample-size checker tabulates. Pipe-delimited so the ru2
   category ("Mostly urban" / "Mostly or completely rural") keeps its space. */
data select_files;
    length age8 $8 raceeth4 $8 ru2 $30 region $8 sex $8 insurance2 $8 age3 $8;
    infile datalines dlm='|' dsd;
    input age8 $ raceeth4 $ ru2 $ region $ sex $ insurance2 $ age3 $;
    datalines;
20-24|White|Mostly urban|1|Male|Other|20-44
25-29|Black|Mostly urban|1|Female|Medicaid|20-44
35-44|White|Mostly or completely rural|2|Male|Other|20-44
45-54|Other|Mostly urban|3|Female|Other|45-64
55-64|White|Mostly urban|3|Male|Medicaid|45-64
65-74|Black|Mostly or completely rural|4|Female|Other|65-84
75-84|White|Mostly urban|2|Male|Other|65-84
20-24|Other|Mostly urban|1|Female|Medicaid|20-44
35-44|White|Mostly urban|2|Male|Other|20-44
45-54|Black|Mostly or completely rural|3|Female|Other|45-64
55-64|White|Mostly urban|4|Male|Medicaid|45-64
65-74|White|Mostly urban|1|Female|Other|65-84
25-29|Other|Mostly urban|2|Male|Other|20-44
35-44|Black|Mostly urban|3|Female|Medicaid|20-44
45-54|White|Mostly or completely rural|4|Male|Other|45-64
55-64|Other|Mostly urban|1|Female|Other|45-64
65-74|White|Mostly urban|2|Male|Other|65-84
75-84|Black|Mostly urban|3|Female|Medicaid|65-84
20-24|White|Mostly urban|4|Male|Other|20-44
35-44|White|Mostly urban|1|Female|Other|20-44
;
run;

/* ===== verbatim %checkfreq / %checkfreq2 from 2_0_quickstart_MENDS_weighting.sas ===== */
/*@Action: Execute sample size check for national level***/
%macro checkfreq(filein=, var=);

	proc freq data=&filein. noprint;
		table &var./list missing out=geo_&var. (drop=percent rename=(&var.=values1));
	run;

%mend;

%macro checkfreq2(filein=, var1=, var2=);

	proc freq data=&filein. noprint;
		table &var1.*&var2./list missing out=geo_&var1._&var2. (drop=percent rename=(&var1.=values1 &var2.=values2));
	run;

%mend;
/* ===== end verbatim macros ===== */

/* One-way and two-way sample-size tabulations, the same factor set
   %weights_national() checks before raking. */
%checkfreq(filein=select_files, var=age8);
%checkfreq(filein=select_files, var=raceeth4);
%checkfreq(filein=select_files, var=ru2);
%checkfreq(filein=select_files, var=region);
%checkfreq2(filein=select_files, var1=age3, var2=sex);
%checkfreq2(filein=select_files, var1=raceeth4, var2=sex);
%checkfreq2(filein=select_files, var1=insurance2, var2=age3);
%checkfreq2(filein=select_files, var1=insurance2, var2=raceeth4);

/* Stack the tabulations and apply the pipeline's sufficiency rule
   (count < 20 -> insufficient), exactly as %weights_national() does. */
data geo_freq;
    format checker_results $100.;
    length factor values1 values2 $100.;
    set geo_age8 (in=in1) geo_raceeth4 (in=in2) geo_ru2 (in=in3) geo_region (in=in4)
        geo_age3_sex (in=in5) geo_raceeth4_sex (in=in6) geo_insurance2_age3 (in=in7) geo_insurance2_raceeth4 (in=in8);

    if in1 then factor='age8';
    else if in2 then factor='raceeth4';
    else if in3 then factor='ru2';
    else if in4 then factor='region';
    else if in5 then factor='age3, sex';
    else if in6 then factor='raceeth4, sex';
    else if in7 then factor='insurance2, age3';
    else if in8 then factor='insurance2, raceeth4';

    if count<20 then checker_results="sample size is insufficient";
    else checker_results="sample size is sufficient";
run;

title "Sample-size checker results (factor x cell counts)";
proc print data=geo_freq;
    var factor values1 values2 count checker_results;
run;
title;
