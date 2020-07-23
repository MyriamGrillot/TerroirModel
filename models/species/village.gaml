/**
* Author: grillot
* Description: village agent => used as a global agent (particularly to compute N flows)
*/

model village

import "../constants.gaml"
import "../inputs/parameters.gaml"

import "plot.gaml"
import "household.gaml"
import "stock.gaml"
import "livestockHerd.gaml"


global {	
	string path_outputs <- "../../outputs/";
	
	species village {
		map<string, map<pair<list<string>, list<string>>, float>> villageFlows_kgN <- map([]);
		
		// *** Independent variables ****
		//* climate
		list<int> rainList; 				// rain in mm/year
		
		int day_beg_rain;
		int step_beg_rain; 					// the rainy season begins
		int step_beg_rainY2;
				
		//* trees cycles
		int day_beg_faidherbiaCycle;
		int faidherbia_step_begCycle;
		
					
		// *** Dependent variables ****
		//* climate inputs
		int step_end_rain; 					// at the end of this step, the rainy season stops
		
		//* veg cycles
		int faidherbia_loose_leaves;
		int lengthGrassCycle;
		
		// beginning of crop cycles (in steps)
		map<string,list<int>> CROP_PLANTATION;
		int beg_organicFerti;
		
		// fattening
		int step_fattening;
		
		int beg_fat_after_rain;
		int end_fat;
		
		//N deposition
		float Nfixation_kgN_pRainyDay_pha;
		
		// YIELDS converted from fresh matter to dry matter
		map<string,float> LU_Y0PRODUCT_DM_ha; 	
		
		int startSowing;
		int endSowing;
		
		int mineralFertilizationStep;
				
		//**********************************************************************************************************************
		// init Global Variables
		action initIndependentGlobalVariables {
			if fixedRainList {
				rainList <- [1, 550, 550, 550, 550, 637, 726, 382, 508, 475, 679, 479, 541, 805, 663, 605, 603, 601, 682, 408, 692, 1]; //[300, 350, 400, 450, 500, 550, 600, 650, 700];
			}
			day_beg_rain <- 10;
			lengthRainySeason_days <- 65;
			
			day_beg_faidherbiaCycle <- 165;
			length_faidherbiaGrowth_days <- 100;
			
			beg_fat_after_rain <- 30;
			
			woodGatheringPeriod <- false;
			grassCuttingPeriod <- false;
			harvestPeriod <- false;
			
			CROP_PLANTATION <- ([MILLET::[0, day_beg_rain + 7], GROUNDNUT::[day_beg_rain, day_beg_rain]]);
			startSowing <- 0;
			endSowing <- day_beg_rain + 7;
			mineralFertilizationStep <- 0; // startSowing
		}
		
		// UPDATE GLOBAL VARIABLES
		action updateGlobalVariables {
			do updateDependentGlobalVariables;
		}
	
		action updateDependentGlobalVariables {
			if fixedRainList {
				if one_of_rain {
					rain_mm <- one_of(rainList);
				} else {
					rain_mm <- rainList[year]; 	
				}
			}
			step_beg_rain <- cycle + day_beg_rain;
			step_beg_rainY2 <- cycle + day_beg_rain + cycle_per_year;
			
			step_end_rain <- step_beg_rain + lengthRainySeason_days;
			
			step_fattening <- step_beg_rain + beg_fat_after_rain;
			end_fat <- step_fattening + length_FATTENINGPERIOD_days;
						
			faidherbia_step_begCycle <- cycle + day_beg_faidherbiaCycle;
			faidherbia_loose_leaves <- faidherbia_step_begCycle + length_faidherbiaGrowth_days + durationFederbiaMaintainLeaves_days;
			lengthGrassCycle <- lengthRainySeason_days + 7;
			
			// yields in KGDM/ha: limited by rain only (millet cob ; groundnut unhusked)
			float Y0millet_kgFW <- (0.4322 * ln(rain_mm) - 1.195) * 1000#kg; // = Y50 (average = 30gkN/ha available) 
			float Y0grass_kgDM <- (1.8608 * ln(rain_mm) - 8.6756) * 1000#kg;// = Y0 (average = 10gkN/ha available)
			LU_Y0PRODUCT_DM_ha <- ([MILLET::(Y0millet_kgFW * 0.95), GROUNDNUT::450 #kg, FALLOW::(Y0grass_kgDM), RGL_VEG::(Y0grass_kgDM)]); 
			Nfixation_kgN_pRainyDay_pha <- Nfixation_kgNha_pyear / lengthRainySeason_days;
		}
		
		action updateStartSowing {
			CROP_PLANTATION <- ([MILLET::[(step_beg_rainY2 - 30), (step_beg_rainY2 + 7)], GROUNDNUT::[step_beg_rainY2, step_beg_rainY2]]);
			
			list<int> listPlant;
			loop i over: CROP_PLANTATION.values {
				listPlant <- listPlant + i;
			}
			
			startSowing <- min(listPlant);
			endSowing <- max(listPlant);
			
			beg_organicFerti <- startSowing - beg_organicFert_days_before_sowing;
		}
		
		// Related to plots
		//* fertilization
		
		float COEF_FERTI_PRODUCT_NAVAILABLE (string landU, float Nav) {
			float val;
			// N available bounds
			int row;
			list<string> theList <- (matFertilizationCoefBounds) column_at 0;
			loop i over: theList {
				if i = landU {
					row <- theList index_of (i);
					break;
				}
			}
						
			float bound <- float(matFertilizationCoefBounds[1, row]);
			if Nav <= bound {
				Nav <- bound;
			} else {
				bound <- float(matFertilizationCoefBounds[2, row]);
				if Nav >= bound {
					Nav <- bound;
				}
			}
				
			// get fertilization coef				
			if landU = MILLET {
				val <- 0.5012 * ln(Nav) - 1.2179; 
			}
			if landU = FALLOW or landU = RGL_VEG {
				val <- 0.4140 * ln(Nav) - 0.7012; 
			}
			
			if val <= 0 {
				write "village: VAL N av: " + val + " " + landU + " - " + Nav + " " + ln(Nav);
			}
			return val;
		}
		
		action lessRecentlyFertilized (list<agriculturalPlot> theList) {
			list<agriculturalPlot> newList <- [];
			
			loop p over:theList {
				if empty(p.organicFertilizationStatus) {
					add p to: newList;
				}
			}
			
			if empty(newList) {
				// the less recently fertilized
				int minmax <- theList min_of(max(each.organicFertilizationStatus.keys));
				newList <- theList where((max(each.organicFertilizationStatus.keys) = minmax));
				
				// among the less recently fertilized, the smallest value
				float minlast <- newList min_of(last(each.organicFertilizationStatus.values));
				newList <- newList where((last(each.organicFertilizationStatus.values) = minlast));
			}
			return newList;
		}
		
		action smallerFertilization (list<agriculturalPlot> theList) {
			list<agriculturalPlot> newList <- [];
			
			loop p over:theList {
				if empty(p.organicFertilizationStatus) {
					add p to: newList;
				}
			}
			
			if empty(newList) {				
				// among the less recently fertilized, the smallest value
				float minlast <- newList min_of(last(each.organicFertilizationStatus.values));
				newList <- newList where((last(each.organicFertilizationStatus.values) = minlast));
			}
			return newList;
		}
		
		action update_balance_apparent_color {
			float maxb <- agriculturalPlot max_of(each.balance_kgNapparent_ha);
			float minb <- agriculturalPlot min_of(each.balance_kgNapparent_ha);
			write "cycle: " + cycle + " - max balance = " + maxb + " - min balance = " + minb;
			maxb <- maxb + abs(minb);
			
			if maxb > 0 {
				ask agriculturalPlot {
					int v <- int(255-(balance_kgNapparent_ha + abs(minb))*255/maxb);
					balance_apparent_color <- rgb(0,v,0);
				}
			} else {
				ask agriculturalPlot {
					balance_apparent_color <- rgb(0,0,0);
				}
			}
		}
		
		// related to livestock
		float lowNeedCoverage <- 0.5;
				
		// related to flows
		
		action 	updateVillageFlowMap(string type, float flow, string originAct, string destinationAct, string originLU, string destinationLU) {

			pair<list<string>, list<string>> theP <- ([originAct, destinationAct]::[originLU, destinationLU]);	
			
			if empty(villageFlows_kgN) = false and type in villageFlows_kgN.keys {
				map<pair<list<string>, list<string>>, float> theM;// <- map([]);
				theM <- villageFlows_kgN[type];
				
				if empty(theM) = false and theP in theM.keys {
					float val <- theM[theP] + flow;
					theM[theP] <- val;
				} else {
					villageFlows_kgN[type] <- villageFlows_kgN[type] + (theP::flow);
				}
			} else {
				villageFlows_kgN <- (villageFlows_kgN + ([type::([theP::flow])]));
			}
		}
	}
	
	// *** global actions
	action switchOtherOriginDestination (string act, string lu) {
		switch act {
			match GRANARY {
				act <- OTHER_GRANARY;
			}
			match FERTILIZERS {
				act <- OTHER_FERTILIZER;
			}
			match HUMAN {
				act <- OTHER_HUMAN;
			}
			match PLOT {
				act <- OTHER_PLOT;
			}
			match LIVESTOCK {
				act <- OTHER_LIVESTOCK;
			}
		}		
		
		switch lu {
			match DWELLING {
				lu <- OTHER_DWELLING;
			}
			match HOMEFIELD {
				lu <- OTHER_HOMEFIELD;
			}
			match BUSHFIELD {
				lu <- OTHER_BUSHFIELD;
			}
			match LIVESTOCK_LU {
				lu <- OTHER_LIVESTOCK_LU;
			}
		}
		return [act, lu];
	}
	
	
	action switchOriginDestination (list<string> theListOrigin, list<string> theListDestination) {
		string act_O1 <- first(theListOrigin);
		string lu_O1 <- last(theListOrigin);
		
		string act_D1 <- first(theListDestination);
		string lu_D1 <- last(theListDestination);
		
		string act_O2 <- first(theListDestination);
		string lu_O2 <- last(theListDestination);
		
		string act_D2 <- first(theListOrigin);
		string lu_D2 <- last(theListOrigin);
		
		switch act_D1 {
			match GRANARY {
				act_D2 <- OTHER_GRANARY;
			}
			match FERTILIZERS {
				act_D2 <- OTHER_FERTILIZER;
			}
			match HUMAN {
				act_D2 <- OTHER_HUMAN;
			}
			match PLOT {
				act_D2 <- OTHER_PLOT;
			}
			match LIVESTOCK {
				act_D2 <- OTHER_LIVESTOCK;
			}
			
			match OTHER_GRANARY {
				act_D2 <- GRANARY;
			}
			match OTHER_FERTILIZER {
				act_D2 <- FERTILIZERS;
			}
			match OTHER_HUMAN {
				act_D2 <- HUMAN;
			}
			match OTHER_PLOT {
				act_D2 <- PLOT;
			}
			match OTHER_LIVESTOCK {
				act_D2 <- LIVESTOCK;
			}
		}		
		
		switch act_O1 {
			match GRANARY {
				act_O2 <- OTHER_GRANARY;
			}
			match FERTILIZERS {
				act_O2 <- OTHER_FERTILIZER;
			}
			match HUMAN {
				act_O2 <- OTHER_HUMAN;
			}
			match PLOT {
				act_O2 <- OTHER_PLOT;
			}
			match LIVESTOCK {
				act_O2 <- OTHER_LIVESTOCK;
			}
			
			match OTHER_GRANARY {
				act_O2 <- GRANARY;
			}
			match OTHER_FERTILIZER {
				act_O2 <- FERTILIZERS;
			}
			match OTHER_HUMAN {
				act_O2 <- HUMAN;
			}
			match OTHER_PLOT {
				act_O2 <- PLOT;
			}
			match OTHER_LIVESTOCK {
				act_O2 <- LIVESTOCK;
			}
		}		
		
		switch lu_D1 {
			match DWELLING {
				lu_D2 <- OTHER_DWELLING;
			}
			match HOMEFIELD {
				lu_D2 <- OTHER_HOMEFIELD;
			}
			match BUSHFIELD {
				lu_D2 <- OTHER_BUSHFIELD;
			}
			match LIVESTOCK_LU {
				lu_D2 <- OTHER_LIVESTOCK_LU;
			}
			
			match OTHER_DWELLING {
				lu_D2 <- DWELLING;
			}
			match OTHER_HOMEFIELD {
				lu_D2 <- HOMEFIELD;
			}
			match OTHER_BUSHFIELD {
				lu_D2 <- BUSHFIELD;
			}
			match OTHER_LIVESTOCK_LU {
				lu_D2 <- LIVESTOCK_LU;
			}
		}
		
		switch lu_O1 {
			match DWELLING {
				lu_O2 <- OTHER_DWELLING;
			}
			match HOMEFIELD {
				lu_O2 <- OTHER_HOMEFIELD;
			}
			match BUSHFIELD {
				lu_O2 <- OTHER_BUSHFIELD;
			}
			match LIVESTOCK_LU {
				lu_O2 <- OTHER_LIVESTOCK_LU;
			}
			
			match OTHER_DWELLING {
				lu_O2 <- DWELLING;
			}
			match OTHER_HOMEFIELD {
				lu_O2 <- HOMEFIELD;
			}
			match OTHER_BUSHFIELD {
				lu_O2 <- BUSHFIELD;
			}
			match OTHER_LIVESTOCK_LU {
				lu_O2 <- LIVESTOCK_LU;
			}
		}
		
		theListOrigin <- [act_O2, lu_O2];
		theListDestination <- [act_D2, lu_D2];
		return [theListOrigin, theListDestination];
	}

	action updateFlowMaps_kgN (household HHO, household HHD, string type, float quantity_kgN, list<string> theListOrigin, list<string> theListDestination){
		if quantity_kgN > 0 {
			string actOrigin <- first(theListOrigin);
			string luOrigin <- last(theListOrigin);
			string actDestination <- first(theListDestination);
			string luDestination <- last(theListDestination);
			list<string> theList;
			list<list<string>> pairList;	
	
			if HHO = HHD {
				if HHO != nil {
					ask HHO {
						do updateFlowMap(type, quantity_kgN, actOrigin, actDestination, luOrigin, luDestination);
					}
				} else {
					ask first(village) {
						do updateVillageFlowMap(type, quantity_kgN, actOrigin, actDestination, luOrigin, luDestination);
					}
				}
				
			} else {
			
				if HHO != nil {
					ask HHO {
						do updateFlowMap(type, quantity_kgN, actOrigin, actDestination, luOrigin, luDestination);
					}
					
					if actDestination != EXT and actDestination != RESPIRATION {
						
						pairList <- switchOriginDestination(theListOrigin, theListDestination);
						
						if actOrigin = EXT or actOrigin = RESPIRATION {
							write " VILLAGE: HHO != nil but actOrigin = EXT: " + type + " " + actOrigin;
						}
						
						theListOrigin <- first(pairList);
						theListDestination <- last(pairList);
						
						actOrigin <- first(theListOrigin);
						luOrigin <- last(theListOrigin);
						actDestination <- first(theListDestination);
						luDestination <- last(theListDestination);
							
						if HHD != nil {
							ask HHD {
								do updateFlowMap(type, quantity_kgN, actOrigin, actDestination, luOrigin, luDestination);
							}
							
						} else {
							ask first(village) {
								do updateVillageFlowMap(type, quantity_kgN, actOrigin, actDestination, luOrigin, luDestination);
							}
						}
					}
					
				} else {
					if actOrigin = EXT or actOrigin = RESPIRATION{
						ask HHD {
							do updateFlowMap(type, quantity_kgN, actOrigin, actDestination, luOrigin, luDestination);
						}					
					} else {
						ask first(village) {
							do updateVillageFlowMap(type, quantity_kgN, actOrigin, actDestination, luOrigin, luDestination);
						}
						
						if actDestination = EXT or actDestination = RESPIRATION {
							write " VILLAGE: HHO = nil and actDestination = EXT: " + type + " " + actOrigin;
						}
										
						pairList <- switchOriginDestination(theListOrigin, theListDestination);
						
						theListOrigin <- first(pairList);
						theListDestination <- last(pairList);
						
						actOrigin <- first(theListOrigin);
						luOrigin <- last(theListOrigin);
						actDestination <- first(theListDestination);
						luDestination <- last(theListDestination);
						
						ask HHD {
							do updateFlowMap(type, quantity_kgN, actOrigin, actDestination, luOrigin, luDestination);
							do updateFlowMap(type, quantity_kgN, actOrigin, actDestination, luOrigin, luDestination);
						}
					}
				}
			}
		}
	}
}