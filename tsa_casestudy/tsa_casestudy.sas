/******************/
/* Accessing Data */
/******************/
options validvarname=v7;
%let tsapath=~/ECRB94/programs/tsa_casestudy/tsa_data;
libname tsa "&tsapath";

/* uncomment below only if tsa.claims_raw does not exist */
/* proc import datafile="&tsapath/TSAClaims2002_2017.csv" out=tsa.claims_raw dbms=csv replace; */
/* 	GUESSINGROWS=MAX; */
/* run; */
/* Copy raw(imported) data for manipulation */
data tsa.claims_cleaned;
	set tsa.claims_raw;
run;

/******************/
/* Exploring Data */
/******************/
proc freq data=tsa.claims_cleaned;
	tables claim_site disposition claim_type;
run;

/******************/
/* Preparing Data */
/******************/
/* 1. Removing duplicate rows */
proc sort data=tsa.claims_cleaned out=tsa.claims_cleaned_nodup nodupkey 
		dupout=claims_cleaned_dups;
	by _all_;
run;

/* checking the duplicates */
proc print data=tsa.claims_cleaned;
	where claim_number in ("2004050450432", "2016102435072", "2016102835336", 
		"2016120935963", "2017020337228");
run;

/* 2.  Sort the data by ascending Incident_Date. */
/* overwrite tsa.claims_cleaned so there's no complete duplicates and it's sorted*/
proc sort data=tsa.claims_cleaned_nodup out=tsa.claims_cleaned;
	by incident_date;
run;

/* for step 8: creating macro variable */
proc sql noprint;
	select cat(name, ' = ', '"', tranwrd(name, "_", ""), '"') into :labels 
		separated by ' ' from dictionary.columns where libname='TSA' AND 
		memname='CLAIMS_CLEANED';
quit;

data tsa.claims_cleaned;
	set tsa.claims_cleaned;

	/* 3.  Clean the Claim_Site column.  */
	if claim_site in ("-", " ") then
		claim_site="Unknown";

	/* 4.  Clean the Disposition column.  */
	if disposition in ("-", " ") then
		disposition="Unknown";
	else if disposition="losed: Contractor Claim" then
		disposition="Closed:Contractor Claim";
	else if disposition="Closed: Canceled" then
		disposition="Closed:Canceled";

	/* 5.  Clean the Claim_Type column.  */
	if claim_type in ("-", " ") then
		claim_type="Unknown";
	else if claim_type in ("Passenger Property Loss/Personal Injur", 
		"Passenger Property Loss/Personal Injury") then
			claim_type="Passenger Property Loss";
	else if disposition in ("-", " ") then
		disposition="Unknown";
	else if disposition="Property Damage/Personal Injury" then
		disposition="Property Damage";

	/* 6.  Convert all State values to uppercase and all StateName values to proper case.  */
	State=upcase(State);
	StateName=propcase(StateName);

	/* 7.  Create a new column to indicate date issues.  */
	/* 	missing dates */
	if Incident_Date=. OR Date_Received=.

	/* 	or year(incident_date)  not between 2002 and 2017 -> why not? */
	or not (2002 <=year(incident_date) <=2017) or not (2002 <=year(Date_Received) 
		<=2017) or incident_date > Date_Received then
			Date_Issues="Needs Review";

	/* 8.  Add permanent labels and formats.  */
	label &labels;

	/* 	formating data */
	format Close_Amount dollar10.2 Date_Received Incident_Date date9.;

	/* 9.  Exclude County and City from the output table. */
	drop County City;

	/* 	sort data by ascending incident date */
	by Incident_Date;
run;

/******************/
/* Analyzing Data */
/******************/
proc template;
	define style styles.textstyle;
		parent=styles.Journal;
		class UserText from SystemTitle / fontsize=13pt margintop=5pt 
			textalign=center;
	end;
run;

/* Using the Output Delivery System: PDF */
/* Exporting PDF Results */
ods pdf file="&tsapath/TSAClaims2002_2017_report.pdf" STARTPAGE=NO 
	style=styles.textstyle pdftoc=1;
ods noproctitle;

/* 1. How many date issues are in the overall data? */
/* For the remaining analyses, exclude all rows with date issues. */
ods proclabel "Number of Claims with invalid dates";
title "Number of Claims with invalid dates";

proc freq data=tsa.claims_cleaned;
	tables date_issues / NOPERCENT NOCUM;
run;

data tsa.claims_cleaned;
	set tsa.claims_cleaned;
	where date_issues~="Needs Review";
run;

title;

/* 2. How many claims per year of Incident_Date are in the overall data? Be sure to include a plot. */
ods pdf startpage=now;
ods proclabel "Number of Claims by Year";
title "Number of Claims by Year";

proc freq data=tsa.claims_cleaned;
	tables incident_date / NOPERCENT NOCUM plots=freqplot;
	format incident_date year.;
run;

title;

/* 3. Lastly, a user should be able to dynamically input a specific state value and answer the following: */
ods pdf startpage=now;

/* Macro variables for state and statename */
%let state_val='HI';

proc sql noprint outobs=1;
	select statename into :statename_val from tsa.claims_cleaned where 
		state=&state_val;
quit;

/* a. What are the frequency values for Claim_Type for the selected state? */
/* b. What are the frequency values for Claim_Site for the selected state? */
/* c. What are the frequency values for Disposition for the selected state? */
ods proclabel "Claims Overview for &statename_val";
title "Claim Type, Claim Site and Disposition for &statename_val";

proc freq data=tsa.claims_cleaned order=freq;
	tables claim_type Claim_Site Disposition/ NOPERCENT NOCUM;
	where state=&state_val;
run;

title;

/* d. What is the mean, minimum, maximum, and sum of Close_Amount for the selected state? */
/* The statistics should be rounded to the nearest integer */
ods pdf startpage=now;
ods proclabel "Close Amount Analysis for &statename_val";
title "Close Amount Analysis for &statename_val";

proc means data=tsa.claims_cleaned mean min max sum maxdec=0;
	var close_amount;
	where state=&state_val;
run;

title;
ods pdf close;
libname tsa clear;