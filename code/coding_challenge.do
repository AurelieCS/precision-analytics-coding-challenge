*Clear and set more off
clear all
set more off

*Working directory
cd "~/Dropbox (Personal)/Emplois/Precision Analytics/fertility-challenge"

*set log
capture log close
log using log/log_coding_challenge, text replace


******************************************************************
*                    CODING CHALLENGE QUESTION 1				 * 
******************************************************************

*Import datasets
foreach file_years in "1995-2002" "2003-2006" "2007-2017" {
	clear

	import delimited "raw/Natality, `file_years'.txt", delimiters(tab)
	
	*Add data column to keep track of source file
	gen source_file_year="`file_years'"
	
	save "import/natality_`file_years'.dta", replace
	
}

*Append datasets
use "import/natality_1995-2002.dta", clear 

foreach file in "2003-2006" "2007-2017" {
           append using "import/natality_`file'"
}

*Sort by state and year
sort state year

*Order variables
order state statecode year yearcode births totalpopulation birthrate femalepopulation fertilityrate source_file_year notes


******************************************************************
*                    CODING CHALLENGE QUESTION 2				 * 
******************************************************************

*Drop observations that are missing for everything besides notes
#delimit ;
drop if missing(state) & missing(statecode) & missing(year) & missing(yearcode)
		& missing(births) & missing(totalpopulation) & missing(birthrate)
		& missing(femalepopulation) & missing(fertilityrate);
#delimit cr;

*Make sure that states have the same statecodes in each raw source file
bysort state: egen max_statecode = max(statecode) // Find maxmimum value of statecode by state name
bysort state: egen min_statecode = min(statecode) // Find minimum value of statecode by state name
gen flag_different_statecode = (max_statecode !=min_statecode) // Flag if these 2 values are different

tab flag_different_statecode // States have the same statecode in each raw source file - OK
		
*Check frequencies and missing values for categorical variables
* - 50 states + District of Columbia for all years, and 156 missing values, which should correspond to total per state
* - 23 years per state and 3 missing values that should correspond to the total for all states
foreach var of varlist state  statecode year yearcode {
tab `var', m
}

*Confirm that missing values for state, statecode, year and yearcode correspond to the total values - OK
foreach var of varlist state  statecode year yearcode {
	di "Variable is `var'"
	tab note if missing(`var')
}

* Check mean, median, standard deviation, minimimum, and maximum values for continuous variables
* - All values are positive (>0) - OK
sum births totalpopulation birthrate femalepopulation fertilityrate
 
*For continuous variables, create and look at variable for number of missing values
* - No missing values for births - OK
foreach var of varlist  births totalpopulation birthrate femalepopulation fertilityrate {
	egen mis_`var' = rowmiss(`var')
	tab mis_`var'
}
 
* Check that missing values for totalpopulation, birthrate, femalepopulation, and fertilityrate
* correspond to the 1995-2002 source file - OK
foreach var of varlist mis_totalpopulation mis_birthrate mis_femalepopulation mis_fertilityrate {
	di "Variable is `var'"
	tab source_file_year if `var'==1
}
 
 *Drop totals per state and for all states, since they will not be needed in the remaining analyses
 drop if notes =="Total"
 
 *Drop variables used to do checks to keep dataset clean
 drop mis_* max_statecode min_statecode flag_different_statecode
  
*Add data labels
label var source_file_year "Years of source natality file"

*Save clean data
save clean/natality.dta, replace

******************************************************************
*                    CODING CHALLENGE QUESTION 3				 * 
******************************************************************

*Use clean data
use clean/natality.dta, clear

*Find state with highest average births over all years
bysort state: egen mean_births = mean(births) //Average births per state, over all years
egen max_births = max(mean_births) //Maximum value of average births
gen flag_state_max_birth = statecode if max_births==mean_births //Identify state with the maximum value of average births

*Save the statecode with the highest average births for use in figure
sum flag_state_max_birth
global state_max_birth =r(max)

*Births in thousands
gen births_thousand = births/1e3

*Identifying labels for the state with the highest average birth for display in figure legend
egen legend_statecode =group(statecode)
sum legend_statecode if statecode==$state_max_birth
global legend_high_statecode =r(max)

gen line_number =_n
egen line_high_statename = min(line_number) if statecode == $state_max_birth
sum line_high_statename
local legend_high_statename = state[r(max)]

*Create graph
levelsof statecode, local(states) 
foreach i of local states  {
	*The highest value to be displayed in red, all other states in grey
	local color= cond(`i'==$state_max_birth, "red", "gs12")
	
	*The highest value to be displayed using a thicker line
	local width= cond(`i'==$state_max_birth, "medthick", "medium")

	local graphs `graphs' (line births_thousand year if statecode == `i', lcolor(`color') lw(`width'))
	
}
graph twoway `graphs', legend(order($legend_high_statecode "`legend_high_statename'" 6 "Other States and District of Columbia")) graphregion(color(white)) ytitle("Births (in thousands)") ///
ylabel(0(100)600) xtitle("Years") title("Number of Births (in Thousands), by State and Year")  ///
note("Data Source: CDC Wonder’s online open access data portal, United States, 1995-2017") name("births_state_year", replace) 

*Export graph
graph export figures/births_per_year_and_state.png, as(png) replace

*Drop variables used to do checks to keep dataset clean
drop mean_births max_births flag_state_max_birth births_thousand legend_statecode line_high_statename line_number

******************************************************************
*                    CODING CHALLENGE QUESTION 4				 * 
******************************************************************

*Check if birthrate is normally distributed
hist birthrate, graphregion(color(white)) bcolor(navy) title("Distribution of Birth Rates")

*export graph
graph export figures/distribution_birth_rates.png, as (png) replace

*Perform linear regression, with dummies for state and year
reg birthrate ib1.statecode ib2003.year, cluster(statecode)

*Export results
outreg2 using tables/regression_results.xls, replace label

*Test significance of all years together - significant
testparm i.(year)




*Close log
log close
