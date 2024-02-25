/******************/
/* Accessing Data */
/******************/
options validvarname=v7;
%let tourpath=~/ECRB94/programs/tour_casestudy;
libname tour "&tourpath";

data work.cleaned_tourism(keep=A COUNTRY Series _2014);
	set tour.tourism;
run;

/******************/
/* Exploring Data */
/******************/
proc template;
	define style styles.textstyle;
		parent=styles.Journal;
		class UserText from SystemTitle / fontsize=10pt margintop=5pt 
			textalign=center;
	end;
run;

/* Using the Output Delivery System: PDF */
/* Exporting PDF Results */
ods pdf file="&tourpath/Tourism_report.pdf" STARTPAGE=NO style=styles.textstyle 
	pdftoc=1;
ods noproctitle;
ods proclabel "Tourism data before preparing";
ods text="Tourism data before preparing (obs=15)";

proc print data=work.cleaned_tourism (obs=15);
run;

ods proclabel "country_info data";
ods text="country_info data (obs=10)";

proc print data=tour.country_info (obs=10);
run;

ods pdf startpage=now;

/******************/
/* Preparing Data */
/******************/
/* Create the cleaned_tourism table following data requirements */
/* Restructuring Country variable  */
/* Extracting Country_Name, Tourism_Type and Category from Country variable */
data work.cleaned_tourism;
	retain Country_Name Tourism_Type Category;
	length Country_Name $ 47;
	set work.cleaned_tourism(rename=(_2014=Y2014));

	if A ~=. then
		Country_Name=Country;
	else if Country="Inbound tourism" then
		Tourism_Type="Inbound tourism";
	else if Country="Outbound tourism" then
		Tourism_Type="Outbound tourism";
	else
		do;
			Category=Country;
			output;
		end;
	drop Country A;
run;

/* Handling missing values that are coded as ".." */
data work.cleaned_tourism;
	set work.cleaned_tourism;

	if Series=".." then
		Series=" ";
	else
		Series=upcase(Series);

	if Y2014=".." then
		Y2014=" ";

	/* 	Convert Y2014 into a numeric variable */
	Y2014_N=input(Y2014, 6.);
	drop Y2014;
run;

/* Cleaning scaled values */
data tour.cleaned_tourism;
	set work.cleaned_tourism(rename=(Y2014_N=Y2014));

	if find(category, "Mn") ~=0 then
		do;
			category=substr(category, 1, find(category, "Mn")-1);
			Y2014=Y2014*1000000;
		end;
	else if find(category, "Thousands") ~=0 then
		do;
			category=scan(category, 1, "-");
			Y2014=Y2014*1000;
		end;
	format Y2014 comma20.;
run;

ods proclabel "Tourism data after preparing step: cleaned_tourism";
ods text="Tourism data after preparing step: cleaned_tourism (obs=15)";

proc print data=tour.cleaned_tourism (obs=15);
run;

/* Preparing to merge the cleaned_tourism table with the country_info table */
data work.country_info(rename=(Country=Country_Name));
	set tour.country_info;
run;

proc sort data=work.country_info;
	by Country_Name;
run;

/* Creating a custom format to display the name of each continent  */
proc format;
	value continent_name 1=North America 2=South America 3=Europe 4=Africa 5=Asia 
		6=Oceania 7=Antarctica;
run;

ods proclabel "country_info ready to be merged";
ods text="country_info ready to be merged (obs=10)";

proc print data=work.country_info (obs=10);
run;

ods pdf startpage=now;

/* Creating final_tourism containing only merged data
and nocountryfound containing a list of countries from cleaned_tourism
that do not have a match in the country_info */
data tour.final_tourism tour.NoCountryFound(drop=continent);
	length Country_Name $55;
	merge tour.cleaned_tourism(in=inTour) work.country_info(in=inCountry);
	by Country_Name;

	if inTour=1 and inCountry=1 then
		output tour.final_tourism;
	else if inTour=1 and inCountry=0 then
		output tour.NoCountryFound;
	format continent continent_name.;
run;

ods proclabel "final_tourism";
ods text="final_tourism (obs=15)";

proc print data=tour.final_tourism (obs=15);
run;

ods proclabel "NoCountryFound";
ods text="NoCountryFound (obs=15)";

proc print data=tour.NoCountryFound(obs=15);
run;

ods pdf close;

/******************/
/* Analyzing Data */
/******************/
/* analyze the number of arrivals in 2014 for each continent */
proc means data=tour.final_tourism mean min max maxdec=0;
	var Y2014;
	class continent;
	where category="Arrivals";
run;

proc means data=tour.final_tourism mean maxdec=0;
	var Y2014;
	where category="Tourism expenditure in other countries - US$";
run;

libname tour clear;