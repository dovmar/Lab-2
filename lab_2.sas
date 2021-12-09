PROC IMPORT DATAFILE='/home/u45871880/life_modified.csv'
	DBMS=CSV
	OUT=data;
	GETNAMES=YES;
RUN;


PROC REG data=data simple corr plots=(diagnostics(stats=none) RStudentByLeverage(label)
             CooksD(label) Residuals(smooth) ObservedByPredicted(label));
MODEL life_expectancy = adult_mortality infant_deaths alcohol hepatitis_b measles 
bmi under_five_deaths polio total_expenditure diphtheria hiv_aids 
thinness_1_19_years thinness_5_9_years income_composition_of_resources 
schooling gdp_per_capita;
output out=rez residual=liekanos;  
run;


/* normalumo testas */
proc univariate data=rez normal;
var liekanos;
run;


/* modelio parinkimas */
/* parametru vertinimas */

PROC REG data=data plots=();
MODEL life_expectancy = adult_mortality infant_deaths alcohol hepatitis_b measles 
bmi under_five_deaths polio total_expenditure diphtheria hiv_aids 
thinness_1_19_years thinness_5_9_years income_composition_of_resources 
schooling gdp_per_capita / stb vif cli clb pcorr2 slentry=0.05 slstay=0.05 selection=stepwise p;
run;

