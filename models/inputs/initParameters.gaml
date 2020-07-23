/**
 *  Initparameters
 *  Author: grillot
 *  Description: parameters used at initialisation
 */

model initParameters

import "../constants.gaml"
import "parameters.gaml"

global {			
//////	/// parameters 	/////
	file initScenario <- csv_file("../inputs/InitScenarios.csv", false);
	
	string shape_name;
	string init_households;
	string init_household_nb_types;
	string init_ruminants;
	string init_draught;
	
	int nb_year_simulated <- 5; 							// nb of years simulated (year)
		
	bool rewrite_data <- true;								// true if we want to clear and rewrite the saved data
	bool consecutiveYears <- false;							// if we want to save every year of the simulation
	bool save_monthly <- false;								// if we want to save every month
	
	bool save_globalVariables <- true;						// init data on household and land units + global variables used for yield computation
	bool save_flows <- true;	
	bool save_periods <- false;
	
	int nb_years_of_balance <- 1;							// nb of consecutive years used to calculate N balance
	bool save_plotbalance <- false;
	bool view_plotbalance <- false;
	
	bool save_herdYearNeedIngestion <- false;
	bool save_herdDailyIngestionNeed <- false;
	bool save_herdDailyExcretion <- false;
	bool save_paddock <- false;
	
	bool save_householdneedingestion <- false;
	bool save_plotfertilisation <- false;
	bool save_plotStatus <- false;
	bool save_stocks <- false;
	bool save_yields <- false;
	
	bool doLivestockDemography <- false; 					// use the action of livestock demography		

	// climate	
	bool fixedRainList <- false;
	bool one_of_rain <- false;

/////// ENVIRONMENT 
	geometry shape;
	
//////	// plot		/////
		//* inits
	map<string,string> INIT_LAND_USE const:true <- ([HOMEFIELD::FALLOW, BUSHFIELD::FALLOW, RANGELAND::RGL_VEG]); 											// land_use initialization per landscape_unit	
	map<string,list<float>> INIT_INFIELD_GRASS_HA const:true <- ([HOMEFIELD::[0.0#kg, 0.0#kg], BUSHFIELD::[0.0#kg, 0.0#kg],	RANGELAND::[0.0#kg, 0.0#kg]]); 	// in field forage to be used in a gaussian curve
		
	map<string,float> INIT_NSTOCK_kgNHa const:true <- ([HOMEFIELD::0.0, BUSHFIELD::0.0, RANGELAND::0.0]);
	map<string,float> INIT_TARGETED_MO_kgDMHa const:true <-  TARGETED_MO_kgDMHa;
	
	float coefYieldMillet;
		
//////	// household /////
	int nb_household;
	file initHouseholdNumber <- csv_file("../inputs/Init_ratio_hh_type.csv", false);
		
	float ratio_waste_in_home_field <- 0.60;
	
	list<string> typesThatCanGetExtraHomeFields <- [CROP_MARKET, CROP_SUBSISTENT, LIV_MARKET];
	
	file initLivestockForageNeeds <- csv_file("../inputs/InitLivestockForageNeeds_avVillage" + ".csv", false);
	file initLivestockConcentratedFeedNeeds <- csv_file("../inputs/InitLivestockConcentratedFeedNeeds_avVillage" + ".csv", false);
	
		//init PLOT	
	////////// init livestock ///
	matrix matinitLivestockForageNeeds;
	matrix matinitLivestockConcentratedFeedNeeds;
}

