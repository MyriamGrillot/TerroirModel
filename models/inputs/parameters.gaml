/**
 *  parameters
 *  Author: grillot
 *  Description: model parameters (and constants with figures)
 */

model parameters

import "../constants.gaml"

global {
///// parameters **************************************************************************************************************	
	bool end_sim <- false;
	bool batch_mode <- false;
	bool disableTranshumance <- true;
	
	string scenario <- "ScTrad";
	string scenario_name <- "ScTrad";
	string path_outputs <- "../../outputs/";
	
//	int version <- 1;

///// variables ****************************************************************************************************************
	int year <- 0;
	int month <- 1;
	int farmingSeason_year <- 1;
	
	float step <- 1#day; 										// length of a step (day)
	int daysPerStep <- 1; 										// length of a step (day)
	int weekly <- 7#cycle; 										// happens every "weeklyAction" steps
	int weeklyActivity <- 7; 
	int monthly <- 30#cycle;									// happens every "monthlyAction" steps
	int monthlyActivity <- 30;
	
	int year_duration_days <- 360#cycle; 						// length of a year (day)
	int cycle_per_year <- int(year_duration_days / daysPerStep); // nb of cycle/year
	
	int rain_mm;
	int lengthRainySeason_days;
	
	map<string,float> BIOMASS_kgNperkgDM <- ([
		GRASS::0.020, // 0.006 during dry season
		STRAW::0.006,
		HAY::0.010,
		LEAVES::0.021,
		FRESH_GRASS::0.020,
		CONCENTRATED_FEED::0.056,
		REFUSAL::0.03,
		MILLET_COB::0.021,
		MILLET_GRAIN::0.018,
		MILLET_POD::0.024,
		GROUNDNUT_UNHUSKED::0.059,
		GROUNDNUT_GRAIN::0.080,
		GROUNDNUT_HUSK::0.010,
		FISH::0.038,
		RICE::0.018,
		WOOD::0.0076,
		MINERAL::0.15, 
		WASTE::0.04
	]);
	
	map<string,float> LIVESTOCK_kgNpTLU <- ([SMALLRUMINANT::(0.025*250.0), BOVINE::(0.034*250.0)]);
	
	float grass_kgNperkgDM_drySeason <- 0.006;
	float grass_kgNperkgDM_rainySeason <- 0.020;
	
	map<string, float> FOOD_WASTE_kgDMperkgDM <- ([MILLET_GRAIN::0.03, GROUNDNUT_GRAIN::0.02, RICE::0.03, FISH::0.1]);
	map<string, float> LIVESTOCK_EXCRETA_content_kgNpkgDM <-  ([URINE::0.9, DUNG::0.013]);
	
	float GRASS_N_CONTENT_DRY_SEASON_KGNpKGDM <- 0.039;
	
	// plot		
	// length of vegetation cycles (in days) after germination
	map<string,int> CROP_CYCLE_LENGTH_DAYS const:true <- ([MILLET::90, GROUNDNUT::90]);
		
		//* fertilization
	int beg_organicFert_days_before_sowing <- int(30 * 3.5);
	
	map<string,float> N_LOSSES_APPLICATIONkgNpkgN <- ([MINERAL::0.26, MANURE::0.10, WASTE::0.10, DUNG::0.2, URINE::0.6]);
	map<string,float> N_LOSSES_ToStoragekgNpkgN <- ([MANURE::0.45]);
	map<string, float> N_LOSSES_HEAPkgNpkgN <- ([MANURE::0.5]); // WASTE::0.3 (wastes are considered as manure here)
		
	map<string,map<string,float>> MINERAL_FERTI_DOSE_kgN_Ha const:true <- 	
						([LIV_SUBSISTENT::([MILLET::15.0,GROUNDNUT::50.0]), LIV_MARKET::([MILLET::37.0,GROUNDNUT::50.0]),
							CROP_SUBSISTENT::([MILLET::15.0,GROUNDNUT::50.0]), CROP_MARKET::([MILLET::37.0,GROUNDNUT::50.0])]);
					
	map<string,map<string,float>> mineralFertilizerAvailable_kgDM;
	
	// max size of a cart in kgDM for each household type
	map<string, float> cartSize_kgDM;

	map<string, float> TARGETED_MO_kgDMHa const:true <- ([HOMEFIELD::10000.0#kg, BUSHFIELD::10000.0#kg, RANGELAND::0.0#kg]);
	
	map<string,float> FERTI_Y1_kgNusable_pkgNinput const:true <- ([MINERAL::1.0, MANURE::0.60, WASTE::0.40, DUNG::0.60, URINE::1.0]); 	// kgN usable/kgNinput
	map<string,float> FERTI_Y2_kgNusable_pkgNinput const:true <- ([MINERAL::0.0, MANURE::0.40, WASTE::0.30, DUNG::0.40, URINE::0.0]); 	// kgN usable/kgNinput
	map<string,float> FERTI_Y3_kgNusable_pkgNinput const:true <- ([MINERAL::0.0, MANURE::0, WASTE::0.30, DUNG::0, URINE::0]);			// kgN usable/kgNinput
	map<int, map<string,float>> FERTIYEAR_kgNusable_pkgNinput <- ([1::(FERTI_Y1_kgNusable_pkgNinput), 2::(FERTI_Y2_kgNusable_pkgNinput), 3::(FERTI_Y3_kgNusable_pkgNinput)]);

	float Nfixation_kgNha_pyear <- 7.5;		
	float crop_legume_fixation_kgN_ha_year <- 20.0;
	float tree_fixation_kgN_tree_year <- 4.0;
	
		//* land use strategies
	list<string> household_favorGROUNDNUT <- [LIV_MARKET, CROP_MARKET];
		
		//* yields per LAND USE
	//targeted area per type of household for cereals (init with household file)
	map<string, float> cereal_areaTargeted_ratioTFA;
	
	map<string,float> SEED_DENSITY_KGDMHA const:true <- ([MILLET::4.6, GROUNDNUT::47.3]); 					// kgDMseed/ha
	
	file fertilizationCoefBounds <- csv_file("../inputs/FertilizationCoefBounds.csv", false) ;
	matrix matFertilizationCoefBounds <- matrix(fertilizationCoefBounds);
		
	float areaHarvested_hapWeek <- 1.0;

	// share of grain within raw product
	map<string, float> GRAIN_kgDM_TOTAL_kgDM const:true <- ([MILLET_COB::0.60, GROUNDNUT_UNHUSKED::0.70]);

	map<string, float> productLossRatioAtHarvest;
		//* coproduct	
	map<string, float> RATIO_COPRODUCT_PRODUCT_kgDM_kgDM const:true <- ([MILLET::3, GROUNDNUT::3, FALLOW::0.0, RGL_VEG::0.0]); // 2017/06/12: MILLET::2.0; GROUNDNUT::1.5
	list<string> canLetResidues <- [MILLET];
	
		// ratio: residues left in the field/total residues
	map<string,float> residuesLeft_ratio; 
	map<string, pair<float, float>> freshGrassMeanYield_kgDMha <- ([HOMEFIELD::(100.0::25.0), BUSHFIELD::(475.0::68.0)]);		// kg DM/ha
		
		//* trees
	//map<int, float> treeSenescenceRatios;
	int length_faidherbiaGrowth_days;
	int durationFederbiaMaintainLeaves_days <- 60;						// days
	
	int treePruningIntensities <- 5;
	map<int, float> meanYield_leaves_kgDMpTree const:true <- ([0::70.0#kg, 1::50.0#kg, 2::30.0#kg, 3::30.0#kg, 4::0.0#kg]);
	map<int, float> meanYield_wood_kgDMpTree const:true <- ([0::45.0#kg, 1::22.0#kg, 2::10.0#kg, 3::10.0#kg, 4::10.0#kg]);
	
	float minPrunedQuantity_kgDM <- 10.0;
	float ratioWoodPruned_overLeaves_kgDM_ptree <- 0.10;				// harvestable wood 

	float dailySenescence <- 0.01;										// %senescence per day (grass)
	float maxLengthSenescence_days <- 175#days;

//////	// household	/////
	// needs&consumption //kg MS required/day/human unit
	map<string, float> FOODNEEDS_PINHABITANTS_kgDM_PDAY <- ([
								MILLET_COB::(0.4 / GRAIN_kgDM_TOTAL_kgDM[MILLET_COB]), // assuming the ratio kgDM/kgDM is similar
								GROUNDNUT_UNHUSKED::(0.02 / GRAIN_kgDM_TOTAL_kgDM[GROUNDNUT_UNHUSKED]), 
								RICE::0.100, 
								FISH::(0.200)*20/100]);
	
	float yardWaste_kgDM_pInhabitant_pday <- 0.25 ; 					// waste production KGDM/day/ human unit
	
	float extraShareForStock <- 1/100;									// extra share saved for food & feed stocks, compared to calculated needs
	float ratio_save_millet_surplus <- 50/100;							// extra share saved for millet cob, compared to calculated needs
	
	float gdnut_bag_weight_kgDM <- 50.0; 								// weight of one groundnut bag in kgDM
	
	float woodGathered_kgDM_pweek <- 10.0;
	float dungOverWood <- 0.33;
	float firewoodNeed_kgDM_pinhabitant_pday <- 0.500; 					// kgDM
	float annualUseRatioWood <- 0.6;
	
	int length_dungIsHarvestable_day <- 15;
	float minimum_dung_harvestable_kgDM <- 0.5;
	
//////	// livestock			/////
	float minimum_lowForage_stored_kgDM <- 500.0; 														// households store a minimum of low quality forage (straw)

	int beg_livestockDemography_year <- 3; 																// livestock demography process starts after n years
	map<int, list<string>> forageBiomassNeedIndex const:true <-([0::[STRAW], 1::[FRESH_GRASS, HAY]]);	// 0: low quality forage, 1: high quality forage
		
		/// GRAZING 
	list<list<string>> biomassPreferencesGrazing <- [[HAY, STRAW], [GRASS, LEAVES], [FRESH_GRASS]]; // first residues (hay/straw), then grass or leaves then fresh grass (weed)
 		
 		// FATTENING
 	map<string, int> FAT_DURATION; 																		// duration of a fattening cycle for each species
 	map<string, int> FAT_NB_CYCLES const:true <- ([BOVINE::2, SMALLRUMINANT::2]);
 	map<string, float> FAT_NEED_INCREASE_ratio_purchase_sell const:true <- ([BOVINE::(0.3), SMALLRUMINANT::(0.3)]);
 	int length_FATTENINGPERIOD_days <- 240; 															// length of the full fattening period in days/year
 	float weigth_gain <- 1.5;																			// gain in TLU after fattening
 	 	
		// forage needs 	
 	map<string, map<string, map<string, pair<float, float>>>> forage_need_normal_kgDM_TLU_day; 			// normal needs for normal times 
 	map<string, map<string, map<string, pair<float, float>>>> forage_need_increase_kgDM_TLU_day;		// vs increase for fattened herds at the end of fattening period or draught animals while working
 	
 		// feed needs 
 	map<string, map<string, map<string, float>>> feed_need_normal_kgDM_TLU_day; 
 	map<string, map<string, map<string, float>>> feed_need_increase_kgDM_TLU_day;														
 	
 	 	// forage
 	int numberOfPossibleTreeTargetpDay <- 2;															// nb of trees pruned/day/household
	map<string,float> refusal_ratio const:true <- ([STRAW::0.05 #kg, HAY::0.01 #kg, GRASS::0.0 #kg, FRESH_GRASS::0.01 #kg, LEAVES::0.0]); 		// refusal in KGDM / forage given to livestock  in KGDM 
		
		// excretion 
	int hour_pDay <- 24;
	int time_in_corralHour <- 14; 																		// time spent in coral /day
	int time_grazeHour <- hour_pDay - time_in_corralHour ; 												// time spent out of coral /day
	
	map<string,float> DUNG_EXCRETION_RATIO_kgNpkgNingested const:true <- ([FAT::0.33, FREEGRAZING::0.59, DRAUGHT::0.33]);		// percentage of N excreted in dung depending on N ingested quantity
	map<string,float> URINE_EXCRETION_RATIO_kgNpkgNdung const:true <- ([FAT::1.24,FREEGRAZING::0.53, DRAUGHT::1.24]);			// percentage of N excreted in urine depending on N excreted as dung
}