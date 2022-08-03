/**
 *  2022 08 03
 *  GAMA version: 1.8.2-RC2
 * 
 * 	main
 *  Author: Myriam Grillot
 *  Description: main code used to run the model (global of the model + experiment)
 */

model main

import "inputs/globalInit.gaml"
import "inputs/parameters.gaml"

import "constants.gaml"

import "species/village.gaml"
import "species/plot.gaml"
import "species/household.gaml"

import "species/livestockHerd.gaml"
import "species/stock.gaml"

import "outputs/saver.gaml"


global {
	string path_outputs <- "../outputs/";
	
	///* AREAS at terroir scale 
	float terroirArea_ha; 							//ha
	map<string,float> landUnitsAreas_ha <- ([]);	//ha
	
	/// bools for periods
	bool rainySeason;
		
	bool organicFertilizationPeriod;
	bool mineralFertilizationPeriod;
	bool sowingPeriod;
	bool harvestPeriod;
	bool croppingSeason;
	bool endCroppingSeason;
	
	bool pruneTreesPeriod;
	bool fatteningPeriod;
	bool begRain;
	bool transhumantPeriod;
	
	bool woodGatheringPeriod;
	bool dungGatheringPeriod;
	bool grassCuttingPeriod;

	bool treeGrowth;
	bool treeLooseLeaves;
	
	bool cropGrowth;
	bool naturalVegetationGrowth;
		
	// GLOBAL REFLEX
	reflex info when: every(monthly) {
		write "c : " + cycle + " - scenario: " + scenario;
	}
		
	reflex whichPeriod {
		ask first(village) {
			rainySeason <- false;
			dungGatheringPeriod <- true;
			sowingPeriod <- false;
			begRain <- false;
			treeGrowth <- false;
			
			fatteningPeriod <- false;
			
			if cycle = step_beg_rain {
				BIOMASS_kgNperkgDM[GRASS] <- grass_kgNperkgDM_rainySeason;
			}
						
			if (cycle >= step_beg_rain and cycle <= step_end_rain) {
				rainySeason <- true;
				dungGatheringPeriod <- false;
			}

			if cycle >= step_fattening and cycle <= end_fat {
				fatteningPeriod <- true;
			}
			
			if empty(agriculturalPlot where (each.landUse in IS_CROP and (each.status.value != FREE))) {
				croppingSeason <- false;
			} else {
				croppingSeason <- true;
			}
			
			if croppingSeason = false and harvestPeriod = true {
				endCroppingSeason <- true;
				woodGatheringPeriod <- true;
				grassCuttingPeriod <- false;
				BIOMASS_kgNperkgDM[GRASS] <- grass_kgNperkgDM_drySeason;			
			} else {
				endCroppingSeason <- false;
			}
			
			if empty(agriculturalPlot where (each.landUse in IS_CROP and (each.status.value = MATURE or each.status.value = PRODUCT_HARVESTED))) {
				harvestPeriod <- false;
			} else {
				harvestPeriod <- true;
			}
						
			if ((cycle >= startSowing) and (cycle <= endSowing)) {
				sowingPeriod <- true;
			} 
			
			if (cycle = beg_organicFerti) {
				organicFertilizationPeriod <- true;
			}
			
			if cycle = step_beg_rain {
				begRain <- true;
			}
			
			//* prune trees	
			if cycle >= faidherbia_step_begCycle and cycle <= (length_faidherbiaGrowth_days + faidherbia_step_begCycle) {
				treeGrowth <- true;
				if cycle = int((faidherbia_step_begCycle + (length_faidherbiaGrowth_days + faidherbia_step_begCycle))/2){
					pruneTreesPeriod <- true;
				}
			}
			
			if pruneTreesPeriod and empty(world.agents of_generic_species(plot) where (each.tree_totalVegetation() > 0)) {
				pruneTreesPeriod <- false;
			}			
			
			//* vegetation growth
			if length(agriculturalPlot where (each.landUse in IS_CROP and each.status.value = GROWING)) > 0 {
				cropGrowth <- true;
			} else {
				cropGrowth <- false;
			}
			
			if length(agriculturalPlot where (each.landUse in NATURAL_VEG and each.status.value = GROWING)) > 0 {
				naturalVegetationGrowth <- true;
			} else {
				naturalVegetationGrowth <- false;
			}
			
			// false changes in another reflex								
			if cycle = step_beg_rain {
				grassCuttingPeriod <- true;
				woodGatheringPeriod <- false;
				organicFertilizationPeriod <- false;
			}
			
			if cycle = faidherbia_loose_leaves {
				treeLooseLeaves <- true;
			}
		}
		if save_periods and (consecutiveYears or year = nb_year_simulated){
			ask saver {do savePeriods;}
		}
	}
	
	reflex updatesAtRain {
		if begRain {
			// DEMOGRAPHY module 
			if doLivestockDemography and year > beg_livestockDemography_year {
				ask world.agents of_generic_species(livestock_herd) {
					do demographicEvolution();
				}
			}

			ask household {
				do askUpdateWoodSurplus;
			}
			
			// start natural vegetation
			loop i over:NATURAL_VEG {
				ask agriculturalPlot where (each.landUse = i) {// and empty(each.total_production_current_year_kgDM_per_product)) {
					do computeYield;
					do updateStatus(GROWING);
					if empty(total_production_current_year_kgDM_per_product) {
						write "LAND USE OUTPUT: " + name + " " + landUse + " " + total_production_current_year_kgDM_per_product;
					}
				}
			}	
		}
	}
	
	reflex transhumance {
		if disableTranshumance = false {
			if begRain {
				transhumantPeriod <- true;
				
				ask world.agents of_generic_species(livestock_herd) where (each.management = FREEGRAZING and each.mySpecies = BOVINE) {
					transhumance <- true;
				}
			}
			
			if transhumantPeriod and endCroppingSeason {
				transhumantPeriod <- false;
				ask world.agents of_generic_species(livestock_herd) where (each.transhumance = true) {
					transhumance <- false;
				}
			}
		}
	}
		
	reflex doUpdatePaddock when:every(weekly) {		
		ask shuffle(world.agents of_generic_species(livestock_herd) where (each.management = FREEGRAZING and each.transhumance = false)) {
	 		do updatePaddock; 
	 	}
	 	
	 	if save_paddock {
	 	 	ask saver {
	 			do savePaddock;
			}
		}
	}
			
	reflex feedingLivestock {
		// update needs		
		
		ask world.agents of_generic_species(livestock_herd) where (each.transhumance = false) {
			do updateForageFeedNeed;
		}
		
		// free-grazing livestock
		ask shuffle(world.agents of_generic_species(livestock_herd) where (each.management = FREEGRAZING and each.transhumance = false)) {	
			do grazeInOnePlot;
		}
		
		// "hand-feeding" - feed with concentrated feed and "stored forage"		
		ask shuffle(household) {
			do feedMyLivestockConcentratedFeed;
			do feedMyLivestockForage;
		}
		
		ask shuffle(household) {	
			// prune trees
			list<livestock_herd> h <- myLivestock where (each.management = FREEGRAZING and each.transhumance = false);
			float needs_kgDM <- sum(h accumulate (each.herdForageNeeds_dDay[0]));
			if needs_kgDM > minPrunedQuantity_kgDM {
				list<livestock_herd> herds <- h where (each.herdForageNeeds_dDay[0] > 0);
				do pruneTrees(herds, needs_kgDM);
			}
		}
		
		// free-grazing livestock
		ask shuffle(world.agents of_generic_species(livestock_herd) where (each.management = FREEGRAZING and each.transhumance = false)) {	
			do grazeInOnePlot;
		}
		
		// excretions
		ask world.agents of_generic_species(livestock_herd) where (each.transhumance = false) {
			do excreteOnPlots;
		}
		
		// update ingestions
		ask world.agents of_generic_species(livestock_herd) where (each.transhumance = false) {
			do udpatePreviousDayIngestions;
		}
	}
	
	reflex doTradeLivestock when: every(weekly){ 
		ask household {
			do sellFatLivestock();
		
			if fatteningPeriod {
				do purchaseFatLivestock();
			}
		}
	}
	
	reflex updateTLUyear {
		if save_globalVariables {
			if (year = nb_year_simulated) or (consecutiveYears) {
				ask household {
					do updateTLUyear;
				}
			}			
		}
	}
	
	reflex householHomeConsumption when: every(weekly) {
		ask shuffle(household) {
			do updateCombustiblesNeed(weeklyActivity);
						
			if woodGatheringPeriod {
				do gatherWoodForStorage_week;
			}
		}
		ask shuffle(household) {
			do homeConsumption(dungGatheringPeriod, weeklyActivity);
		}
		
		if save_householdneedingestion {
			ask saver {
				do saveHouseholdNeed_ingestion;
			}
		}
	}	
	
	// cropping activities ------------------------------------
	reflex manureSpreading when: every(weekly) {
		if organicFertilizationPeriod {
			ask household {
				do spreadManure;
			}
		}
	}
			
	reflex sowingCrops {	
		if sowingPeriod {
			
			// draught animals are better fed when at work
			ask world.agents of_generic_species(livestock_herd) where (each.management = DRAUGHT and (each.transhumance = false)) {
				do increaseFeedNeeds; 
			}
						
			ask first(village) {
				loop i over: CROP_PLANTATION.keys {
					if  cycle >= CROP_PLANTATION[i][0] and  cycle <= CROP_PLANTATION[i][1] {
						ask household {
							do sowCrop(i);
						}
					}
				}	
			}
		} else {
			ask world.agents of_generic_species(livestock_herd) where (each.management = DRAUGHT and (each.transhumance = false)) {
				do decreaseFeedNeeds;
			}
		}
	}
		
	reflex do_mineralFertilization when: mineralFertilizationPeriod {
		ask household {
			do mineralFertilization;
		}
		mineralFertilizationPeriod <- false;
	} 
	
	reflex clearPlot_Wood {
		ask first(village){
			if cycle = step_beg_rain {
				ask  world.agents of_generic_species(plot) {
					do clearWood;
				}
			}
		}
	}

	// PLOT REFLEXES --------------------------------
	reflex plotVegetationGrowth when: every(weekly){
		// tree growth
		if treeGrowth {
			ask world.agents of_generic_species(plot) {
				do tree_growth(weekly);
			}
		}
		
		if treeLooseLeaves {
			ask world.agents of_generic_species(plot) {
				do clearTreeVegetation;
				do updateDeadWoodStock;
				do tree_N_fixation;
				do updatePruningIntensity;
			}
			treeLooseLeaves <- false;
		}
			
		// natural vegetation growth
		ask agriculturalPlot where (each.landUse in NATURAL_VEG and each.status.value = MATURE) {
			do naturalVegetationSenescence;
		}
		
		// crop sowing
		if rainySeason {
			ask agriculturalPlot where (each.status.value = SOWN) {
				do updateStatus(GROWING);
			}
		}
		
		// vegetation growth
		ask agriculturalPlot where (each.status.value = GROWING) {
			do vegetationGrowth(weeklyActivity);	
		}
	}
	
	
	reflex doEndCroppingSeason {
		if endCroppingSeason {
			ask agriculturalPlot where (each.myOwner != nil) {
				do updateFertilizationStatus;
				
				do updatePlanYear;
				do updateLandUse;
			}
			
			ask agriculturalPlot {
				total_production_current_year_kgDM_per_product <- ([]);
			}		

			ask household {
				do adjustCroppingPlan;
				do setFertilizationPriorities;
				do updateTargetedFertilizationQuantity;
				do chooseManureTarget;
				do stockSeeds;
				do askUpdateFoodSurplus;
				do askUpdateFeedSurplus;
				do sellGroundnut;
			}
			
			ask first(village){
				do updateStartSowing;
			}
			
			farmingSeason_year <- farmingSeason_year + 1;
		}
	}

	reflex harvestPeriod when: every(weekly) {
		if harvestPeriod = true {
			ask world.agents of_generic_species(livestock_herd) where (each.management = DRAUGHT and (each.transhumance = false)) {
				do increaseFeedNeeds;
			}
			
			ask household {
				list<agriculturalPlot> harvestablePlots <- (myAgriculturalPlots where (each.landUse in IS_CROP and each.status.value = MATURE));
				float harvestedArea;
				
				// harvest co-products
				list<agriculturalPlot> harvestableCoproducts <- (myAgriculturalPlots where (each.status.value = PRODUCT_HARVESTED));
				if empty(harvestablePlots) and !empty(harvestableCoproducts) {
					loop i over: shuffle(harvestableCoproducts) {
						do harvestCropCoProducts(i);
						harvestedArea <- harvestedArea + i.area_ha; 
						if harvestedArea > areaHarvested_hapWeek {
							break;
						}
					}					
				}
				
				// harvest products
				list<agriculturalPlot> lPlots <- harvestablePlots where (each.myLandUnit = HOMEFIELD);
								
				loop i over: shuffle(lPlots) {
					do harvestCropProducts(i);
					harvestedArea <- harvestedArea + i.area_ha; 
					if harvestedArea > areaHarvested_hapWeek {
						break;
					}
				}
				
				if harvestedArea < areaHarvested_hapWeek {
					lPlots <- harvestablePlots where (each.myLandUnit = BUSHFIELD);
									
					loop i over: shuffle(lPlots) {
						do harvestCropProducts(i);
						harvestedArea <- harvestedArea + i.area_ha; 
						if harvestedArea > areaHarvested_hapWeek {
							break;
						}
					}
				}
			}
		} else {
			ask world.agents of_generic_species(livestock_herd) where (each.management = DRAUGHT and (each.transhumance = false)) {
				do decreaseFeedNeeds;
			}
		}
	}
		
	reflex updateDung {
		ask agriculturalPlot where (!empty(each.dung_kgDM_Ncontent)) {
			do updateDung_kgDM;
		}
	}
	
	reflex doNdeposition {
		if rainySeason {
			ask world.agents of_generic_species(plot) {
				do global_N_fixation_atmosphere;
			}
		}
	}
	
	reflex livestockNeedCoverage when: every(monthly) {
		ask world.agents of_generic_species(livestock_herd) where (each.transhumance = false) {
			do updateNeedCoverageForage;
		}
	}
	
	reflex saveMain when: every(monthly) {
		if !batch_mode and save_monthly {
			if (consecutiveYears) or (year = nb_year_simulated) {
				
				ask saver {
					if save_plotbalance {	
						do savePlots_balance(0);
					}
					
					if save_stocks {
						do saveStocks;
					}
	
					if save_flows {
						do saveFlows(0);
					}
				}
			}
		}
	}
		
	reflex saveDataYearly when: every(cycle_per_year) {
		// save data current year
		if ! batch_mode {
			if (consecutiveYears) or (year = nb_year_simulated) {
				
				if !save_monthly {
					ask saver {
						if (save_flows) {
							do saveFlows(0);			
						}
						if save_stocks {
							do saveStocks;
						}
					}
				}
					
				if save_yields {
					ask saver {
						do saveTerroir_yields(0);
					}
				}
				
				if view_plotbalance {
					ask agriculturalPlot {
						do updateApparentBalance_kgNha;
					}
					
					ask first(village) {
						do update_balance_apparent_color;
					}
				}
				if save_plotbalance {	
					ask saver {
						do savePlots_balance(0);
					}
				}
			}
		}
	}
	
	reflex updateMonth when: every(monthly) {
		month <- month + 1;
	}
	
	reflex new_year when: every(cycle_per_year) {
		// end simulation ?
		if (year = nb_year_simulated) { 	
			end_sim <- true;
			if (not batch_mode) {
				write "END OF SIMULATION: " + year + " years simulated" ;
				ask world {
					do pause;
				}
			}
		} else {
			// new year
			year <- year + 1;
			month <- 1;	
								
			// update variables	
			ask household {
				flows_kgN <- map([]);
				TLU_G_year <- 0.0;
				TLU_D_year <- 0.0;
				TLU_FAT_year <- nil;
			}
			ask first(village){
				villageFlows_kgN <- map([]);
				do updateGlobalVariables;
			}
			
			mineralFertilizationPeriod <- true;

			if (year <= (nb_year_simulated - nb_years_of_balance)) or consecutiveYears {
				ask agriculturalPlot {
					do clear_balance_indicators;
				}
			}				
			
			// save data new year
			ask saver {
				if !batch_mode and (consecutiveYears or (year = nb_year_simulated)) {
					if (save_globalVariables) {
						do saveGlobalVariable(0);
						do saveHouseholdData(0);
					}
					if save_periods {
						do updatePeriodsFile;						
					}
				}
			}
		}
	}	
}

////////////////////////////////////EXPERIMENTS /////////////////////////////////////////////////
experiment batch_exp type:batch repeat: 2 until:end_sim  keep_seed: true {
	parameter "batch mode" var: batch_mode <- true;
	parameter "rewrite data?" var: rewrite_data <- true;
	
	// * scenarios
	parameter "scenario" var: scenario <- "ScFat" among: ["ScFat", "ScTrad"];
	parameter "number of year simulated" var: nb_year_simulated <- 5;
		
	parameter "fixedRainList" var: fixedRainList <- false;
	parameter "one of in rain list" var: one_of_rain <- false;

	// save?
	parameter "save global variables (e.g. households, areas)?" var: save_globalVariables <- true;
	parameter "save flows?" var: save_flows <- true;
	parameter "save yields?" var: save_yields <- true;
	
	parameter "nb_years_of_balance" var: nb_years_of_balance <- 1;
	parameter "save plot balance?" var: save_plotbalance <- false;
	
	parameter "save herd need & coverage?" var: save_herdYearNeedIngestion <- false;
		
	reflex save_data {
		int cpt <- 0;
				
		ask simulations	{	
			ask saver {
				if save_globalVariables {
					do saveGlobalVariable(cpt);
					do saveHouseholdData(cpt);					
				}

				if save_flows {
					do saveFlows(cpt);	
				}
				if save_yields {
					do saveTerroir_yields(cpt);
				}
	
				if save_plotbalance {
					do savePlots_balance(cpt);	
				}			
				
				if save_herdYearNeedIngestion {
					do saveHerdNeedCoverage(cpt);
				}

				write "Saved";
			}
			cpt <- cpt + 1;
		}
	}
}


experiment simulation type:gui {
	parameter "scenario" var: scenario <- "ScTrad" among: ["ScTrad", "ScTran", "ScFat"];

	parameter "number of year simulated" var: nb_year_simulated <- 5 min:1 max:20;
	
	parameter "fixedRainList" var: fixedRainList <- false;
	parameter "one of in rain list" var: one_of_rain <- false;

	// save??
	parameter "consecutive years " var: consecutiveYears <- false;
	parameter "rewrite data?" var: rewrite_data <- true;
	parameter "save monthly? " var: save_monthly <- true;
	
	parameter "save global variables (e.g. households, areas)?" var: save_globalVariables <- true;
	parameter "save flows?" var: save_flows <- true;
	parameter "save periods?" var: save_periods <- true;
	
	parameter "nb of consecutive years used to calculate N balance" var: nb_years_of_balance <- 1;
	parameter "save plot balance?" var: save_plotbalance <- true;
	parameter "view plot balance?" var: view_plotbalance <- true;
	
	parameter "save herd annual ingestion and need?" var: save_herdYearNeedIngestion <- false;
	parameter "save herd daily ingestion and need?" var: save_herdDailyIngestionNeed <- false;
		
	parameter "save herd paddock?" var: save_paddock <- false;
	
	parameter "save household need & ingestion?" var: save_householdneedingestion <- false;
	parameter "save stocks?" var: save_stocks <- true;
	
	parameter "save plot fertilisation?" var: save_plotfertilisation <- true;
	parameter "save plot status?" var: save_plotStatus <- false;
	
	// process?
	parameter "do livestock demography?" var: doLivestockDemography <- false;
			
	output{	
		inspect world;
		display terroir {
			species agriculturalPlot aspect:land_use; // among: land_use; //land_unit; //owner;
			species housingPlot aspect:land_unit;
			species household aspect:hh_look; // among: hh_look; //hh_type_look;

			species equine aspect:liv_look;
			species smallRuminant aspect:liv_look;
			species bovine aspect:liv_look;
			
			overlay position: { 2, 2 } size: { 165 #px, 260 #px } background: # black transparency: 0.6 border: #black rounded: true
            {
                float y <- 20#px;
                draw "Land uses: " at:{20#px, y} color: # white font: font("SansSerif", 11, #bold);
                y <- y + 15#px;
                
                loop type over: LU_COLOR.keys
                {
                	draw square(10#px) at: { 20#px, y } color: LU_COLOR[type] border: #black;
	                draw type at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 11, #bold);
	                y <- y + 20#px;
                }
		        
		        y <- y + 10#px;	
		
				// households simple (hh_look)
				draw "Households: " at:{20#px, y} color: # white font: font("SansSerif", 11, #bold);
                y <- y + 15#px;
                draw circle(5#px) at: { 20#px, y } color:#gainsboro border: #black;
                draw "household" at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 11, #bold);
                y <- y + 20#px;            
                
                y <- y + 10#px;
                draw file("../images/goat.png") size:25#px at:{20#px, y} color: #white;
				draw "paddock (graze)" at:{40#px, y + 4#px} color: # white font: font("SansSerif", 11, #bold);	
                
                y <- y + 10#px;
			}			
		}

		display apparent_balances {
			species agriculturalPlot aspect: balanceAspect;
			species housingPlot aspect: balanceAspect;
		}
			
		display ownership {
			species agriculturalPlot aspect:owner;// among: land_use; //land_unit; //owner;
			species housingPlot aspect:land_unit;

			species household aspect:hh_look; // among: hh_look; //hh_type_look;

			species equine aspect:liv_look;
			species smallRuminant aspect:liv_look;
			species bovine aspect:liv_look;
			
			overlay position: { 2, 2 } size: { 165 #px, 230 #px } background: # black transparency: 0.6 border: #black rounded: true
            {
                float y <- 20#px;
                draw "Plot owner type: " at:{20#px, y} color: # white font: font("SansSerif", 11, #bold);
                y <- y + 15#px;
                       
                loop type over: HH_TYPE_COLOR.keys
                {
                	draw square(10#px) at: { 20#px, y } color: HH_TYPE_COLOR[type] border: #black;
	                draw type at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 11, #bold);
	                y <- y + 20#px;
                }
		        
		        y <- y + 10#px;	
				
		 		draw "Household types : " at:{20#px, y} color: # white font: font("SansSerif", 11, #bold);
		 		y <- y + 15#px;
		 		
		 		draw circle(5#px) at: { 20#px, y } color:#gainsboro border: #black;
                draw "household" at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 11, #bold);
                y <- y + 20#px;    
		 		
		 		// household types (hh_type_look)
//		 		loop type over: HH_TYPE_COLOR.keys {
//                    draw circle(5#px) at: { 20#px, y } color: HH_TYPE_COLOR[type] border: #black;
//                    draw type at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 11, #bold);
//                    y <- y + 20#px;
//                }
                
                y <- y + 10#px;
                draw file("../images/goat.png") size:25#px at:{20#px, y} color: #white;
				draw "paddock (graze)" at:{40#px, y + 4#px} color: # white font: font("SansSerif", 11, #bold);	
			}
		}
	}
}