/**
* globalInit
* Author: grillot
* Description: global initialisation of the model
*/

model globalInit

import "initParameters.gaml"
import "../species/plot.gaml"

global {		
	// INIT GLOBAL	
	init{
		scenario_name <- scenario;
		
		// var used to init plot
		map<string, float> INIT_AREA_HF;
		map<string, float> INIT_AREA_BF;
	
		map<string, float> INIT_INHAB_MEAN;
		map<string, float> INIT_INHAB_SD;
		
		map<string, list<string>> rotationHF;
		map<string, list<string>> rotationBF;
				
		// load data for scenario initialization
		int column;
		//int row;
		list<string> theList;
		
		matrix matScenario <- matrix(initScenario);
		theList <- (matScenario) row_at 0;
		loop i over: theList {
			if i = scenario {
				column <- theList index_of (i);
				break;
			}
		}
				
		shape_name <- string(matScenario[column, 1]);
		init_households <- string(matScenario[column, 2]);
		init_household_nb_types <- string(matScenario[column, 3]);
		init_ruminants <- string(matScenario[column, 4]);
		init_draught <- string(matScenario[column, 5]);
		
		nb_household <- int(matScenario[column, 6]);
		
		if !fixedRainList {
			rain_mm <- int(matScenario[column, 7]); // rain_sensib;
		}
		
		if string(matScenario[column, 8]) = "true" {
			disableTranshumance <- false;	
		} 
		ratio_waste_in_home_field <- float(matScenario[column, 9]);
		coefYieldMillet <- float(matScenario[column, 10]);
		
		// grid
		file dwellingFile <- file("../includes/cellsDwelling_" + shape_name + ".shp");
		file notDwellingFile <- file("../includes/cellsNotDwelling_"+ shape_name + ".shp");
		geometry shape <- envelope(("../includes/cells_"+ shape_name) +".shp");
		
		// init files
		file initHousehold <- csv_file("../inputs/InitHousehold_" + init_households + ".csv", false);
		file initLivestockRuminant <- file("../inputs/Init_livestock_ruminant_" + init_ruminants + ".csv"); 
		file initLivestockDraught <- file("../inputs/Init_livestock_draught_" + init_draught + ".csv"); 
		
		// change food needs for scenario SC1900 (no rice)
		if scenario = "Sc1900" {
			FOODNEEDS_PINHABITANTS_kgDM_PDAY <- ([MILLET_COB::(0.6)/GRAIN_kgDM_TOTAL_kgDM[MILLET_COB], FISH::(0.100)*20/100]);
		}
		
		create village number:1 returns:newV;
		ask newV {
			do initIndependentGlobalVariables;
			do updateDependentGlobalVariables;
		}
		
		//* plot
		create housingPlot from: dwellingFile with: [
			myLandUnit::string(read("Type")),
			area_ha::float(read("Area")),
			initNb_trees::int(read("Trees"))
			];
			
		create agriculturalPlot from: notDwellingFile with: [
			myLandUnit::string(read("Type")),
			area_ha::float(read("Area")),
			initNb_trees::int(read("Trees"))
			];
			
	
		//* create HOUSEHOLD
		matrix matCreateHousehold <- matrix(initHouseholdNumber);
		theList <- (matCreateHousehold) row_at 0;
		loop i over: theList {
			if i = init_household_nb_types {
				column <- theList index_of (i);
				break;
			}
		}
		
		loop i from: 0 to: matCreateHousehold.rows - 1 {
			float ratio <- float(matCreateHousehold[column, i]);
			
			int numberHh <- int((nb_household * ratio)/100);
			if numberHh > 0 {
				create household number: numberHh with: 
				[myType::matCreateHousehold[0, i]];
			}
		}
				
		matrix matinitHousehold <- matrix(initHousehold);
		loop ty over: HOUSEHOLD_TYPES {
			list<string> theList_HH <- (matinitHousehold) row_at 0;
			loop i over: theList_HH {
				if i = ty {
					column <- theList_HH index_of (i);
					break;
				}
			}
			
			add ty::float(matinitHousehold[column, 1]) to:INIT_AREA_HF;
			add ty::float(matinitHousehold[column, 2]) to:INIT_AREA_BF;
			add ty::float(matinitHousehold[column, 3]) to:INIT_INHAB_MEAN;
			add ty::float(matinitHousehold[column, 4]) to:INIT_INHAB_SD;
			add ty::float(matinitHousehold[column, 5]) to:residuesLeft_ratio;
			add ty::([MILLET::float(matinitHousehold[column, 6]), GROUNDNUT::float(matinitHousehold[column, 7])]) to:mineralFertilizerAvailable_kgDM;
			add ty::string(matinitHousehold[column, 8]) split_with "|" to: rotationHF;
			add ty::string(matinitHousehold[column, 9]) split_with "|" to: rotationBF;
			add ty::float(matinitHousehold[column, 10]) to:cereal_areaTargeted_ratioTFA;
		}
		
		ask household {
			inhabitants <- gauss(INIT_INHAB_MEAN[myType], INIT_INHAB_SD[myType]);
			if inhabitants <= 1.0 {
				inhabitants <- 1.0;
			}
		}
		
		// ATTRIBUTE PLOT
		list<agriculturalPlot> plotHF <- agriculturalPlot  where (each.myLandUnit = HOMEFIELD);
		list<agriculturalPlot> plotBF <- agriculturalPlot  where (each.myLandUnit = BUSHFIELD);
		list<household> lhh <- copy(list(household)) ;
		
		loop while: ((!empty (lhh)) and (!empty (plotHF))) {
			loop i over: shuffle (lhh) {
				list<agriculturalPlot> HF_plot_available <- (plotHF where (((each.area_ha) + i.myHFarea()) <= INIT_AREA_HF[i.myType] ));
				agriculturalPlot new_plot <- one_of (HF_plot_available)	;
				if new_plot != nil {
					add new_plot to: i.myAgriculturalPlots;
					new_plot.myOwner <- i;
					remove new_plot from: plotHF ;
				} else {
					remove i from: lhh;
				}
			}
		}
		
		if (!empty (plotHF)) {
			write "init: !empty (plotHF) " + length(plotHF);
		}
		
		if (!empty (plotHF)) {
			write "init: !empty (lhh) " + length(lhh);
		}
		
		lhh <- copy(list(household)) ;	
		loop while: ((!empty(lhh)) and (!empty(plotBF))) {
			loop i over: shuffle(lhh) {	
				list BF_plot_available <- (plotBF where (((each.area_ha) + i.myBFarea()) <= INIT_AREA_BF[i.myType]));
				agriculturalPlot new_plot <- one_of(BF_plot_available);
				
				if new_plot != nil 	{
					add new_plot to: i.myAgriculturalPlots;
					new_plot.myOwner <- i;
					remove new_plot from: plotBF;
				} else 	{
					remove i from: lhh;
				}
			}
		}
		
		if (!empty (plotBF)) {
			write "init: !empty (plotBF) " + length(plotBF);
		}
		
		if (!empty (plotHF)) {
			write "init: !empty (lhh) " + length(lhh);
		}
				
		// Houshold inits PLOT
		ask household {
			//* attribute home & location
			home <- any(housingPlot);
			location <- any_location_in(home);
			theDump <- myAgriculturalPlots closest_to(home);	

			//* init agricultural plots
			loop i over: (myAgriculturalPlots where (each.myLandUnit = HOMEFIELD)) {
				i.croppingPlan <- rotationHF[myType];
			}
			loop i over: (myAgriculturalPlots where (each.myLandUnit = BUSHFIELD)) {
				i.croppingPlan <- rotationBF[myType];
			}
						
			ask myAgriculturalPlots {
				planYear <- rnd(length(croppingPlan) - 1);
				do updateLandUse;
				
				organicFertilizationTargeted_kgDM <- (INIT_TARGETED_MO_kgDMHa[myLandUnit] * area_ha);
			}

			do adjustCroppingPlan;
			do setFertilizationPriorities;
			do chooseManureTarget;
		}
		
		//  LIVESTOCK	///////
		matrix matinitRuminant <- matrix(initLivestockRuminant);
		matrix matinitDraught <- matrix(initLivestockDraught);
		
		// get livestock needs
		matinitLivestockForageNeeds <- matrix(initLivestockForageNeeds);
		matinitLivestockConcentratedFeedNeeds <- matrix(initLivestockConcentratedFeedNeeds);
		
		// add livestock FORAGE need to households
		loop ty over: HOUSEHOLD_TYPES {
			loop i from: 0 to: matinitLivestockForageNeeds.rows - 1 {							
				if (matinitLivestockForageNeeds[0,i]) = ty {
					
					loop n over: ["normal", "increase"] {
						if (matinitLivestockForageNeeds[1,i]) = n {
							int ind <- 2;
							loop times: 5 {
								string sp <- (matinitLivestockForageNeeds[ind,0]);
								string man <- (matinitLivestockForageNeeds[ind,1]);
								list<string> vals <- string(matinitLivestockForageNeeds[ind,i]) split_with "|";
								
								float low <- float(vals[0]);
								float high <- float(vals[1]);
								map<string, pair<float, float>> map2 <- ([man::(low::high)]);

								if n = "normal" {								
									if forage_need_normal_kgDM_TLU_day[ty] = nil {
										add ty::map(sp::map2) to:forage_need_normal_kgDM_TLU_day;
									} else {
										if forage_need_normal_kgDM_TLU_day[ty][sp] = nil {
											add map2 at:sp to:forage_need_normal_kgDM_TLU_day[ty];
										} else {
											forage_need_normal_kgDM_TLU_day[ty][sp][man] <- (low::high);
										}
									}
								}
								
								if n = "increase" {								
									if forage_need_increase_kgDM_TLU_day[ty] = nil {
										add ty::map(sp::map2) to:forage_need_increase_kgDM_TLU_day;
									} else {
										if forage_need_increase_kgDM_TLU_day[ty][sp] = nil {
											add map2 at:sp to:forage_need_increase_kgDM_TLU_day[ty];
										} else {
											forage_need_increase_kgDM_TLU_day[ty][sp][man] <- (low::high);
										}
									}
								}
								 
								ind <- ind + 1; 
							}
						}
					}
				}
			}
		}
		
		// add livestock FEED need to households
		loop ty over: HOUSEHOLD_TYPES {
			loop i from: 0 to: matinitLivestockConcentratedFeedNeeds.rows - 1 {								
				if (matinitLivestockConcentratedFeedNeeds[0,i]) = ty {
					loop n over: ["normal", "increase"] {
						if (matinitLivestockConcentratedFeedNeeds[1,i]) = n {
							int ind <- 2;
							loop times: 3 {
								string sp <- (matinitLivestockConcentratedFeedNeeds[ind,0]);
								string man <- (matinitLivestockConcentratedFeedNeeds[ind,1]);
								float val <- float(matinitLivestockConcentratedFeedNeeds[ind,i]);
								
								map<string, float> map2 <- ([man::val]);

								if n = "normal" {								
									if feed_need_normal_kgDM_TLU_day[ty] = nil {
										add ty::map(sp::map2) to:feed_need_normal_kgDM_TLU_day;
									} else {
										if feed_need_normal_kgDM_TLU_day[ty][sp] = nil {
											add map2 at:sp to:feed_need_normal_kgDM_TLU_day[ty];
										} else {
											feed_need_normal_kgDM_TLU_day[ty][sp][man] <- val;
										}
									}
								}
								
								if n = "increase" {								
									if feed_need_increase_kgDM_TLU_day[ty] = nil {
										add ty::map(sp::map2) to:feed_need_increase_kgDM_TLU_day;
									} else {
										if feed_need_increase_kgDM_TLU_day[ty][sp] = nil {
											add map2 at:sp to:feed_need_increase_kgDM_TLU_day[ty];
										} else {
											feed_need_increase_kgDM_TLU_day[ty][sp][man] <- val;
										}
									}
								}
								ind <- ind + 1; 
							}
						}
					}
				}
			}
		}
		
		// add cart size
		loop ty over: HOUSEHOLD_TYPES {
			loop i from: 0 to: matinitDraught.rows - 1 {								
				if (matinitDraught[0,i]) = ty {
					add ty::float(matinitDraught[3,i]) to: cartSize_kgDM;
				}
			}
		}
		
		//* create livestock herds
		ask household {
			string ty <- myType;
			
			loop i from: 0 to: matinitRuminant.rows - 1 {								
				if (matinitRuminant[0,i]) = ty {
					float nbTLU <- gauss(float(matinitRuminant[2,i]),float(matinitRuminant[3,i])) with_precision 2;
								
					if nbTLU > 0 {
						string spec <- matinitRuminant[1,i];
						float ratio_freeG <- float(matinitRuminant[4,i]);
						float freeG_TLU <- (nbTLU * ratio_freeG) with_precision 2;
						if ratio_freeG < 1 {
							average_FAT_TLU[spec] <- (nbTLU * (1 - ratio_freeG)) with_precision 2;						
						}

						list<livestock_herd> ags; 
												
						if freeG_TLU > 0 {
							string manag <- FREEGRAZING;
							switch spec {
								match "bovine" {
									create bovine number: 1 {ags << self;}										
								}
								match "smallRuminant" {
									create smallRuminant number: 1 {ags << self;}									
								}
							}
							
							ask ags {
								myOwner <- myself;
								myLocation <- myOwner.home;
								management <- manag;
								value_TLU <- freeG_TLU;
																
								displayLocation <- any_location_in(myLocation);
								
								lowForageNeed_TLUpday <- forage_need_normal_kgDM_TLU_day[myOwner.myType][mySpecies][management].key;
								highForageNeed_TLUpday <- forage_need_normal_kgDM_TLU_day[myOwner.myType][mySpecies][management].value;
								concentratedFeedNeed_TLUpday <- feed_need_normal_kgDM_TLU_day[myOwner.myType][mySpecies][management];

								do updateForageFeedNeed;
							}
							myLivestock <- myLivestock + ags;
						}
					}
				}
			}
			
			loop i over: myLivestock where (each.management = FREEGRAZING) {
				i.myPaddock <- any(agriculturalPlot where (each.myLandUnit = RANGELAND));
				ask i {
					do updatePaddock;
				}
				
				i.myLocation <- i.myPaddock;
				i.displayLocation <- any_location_in(i.myLocation);
			}	
			
			//* create draught animals
			loop i from: 0 to: matinitDraught.rows - 1 {
				list<livestock_herd> ags; 
								
				if (matinitDraught[0,i]) = ty {
					float nbTLU <- gauss(float(matinitDraught[1,i]),float(matinitDraught[2,i]));
								
					if nbTLU > 0 {
						create equine number: 1 {ags << self;}	
						ask ags {
							myOwner <- myself;
							myLocation <- myOwner.home;
							management <- DRAUGHT;
							value_TLU <- nbTLU;
																	
							displayLocation <- any_location_in(myLocation);
						
							lowForageNeed_TLUpday <- forage_need_normal_kgDM_TLU_day[myOwner.myType][mySpecies][management].key;
							highForageNeed_TLUpday <- forage_need_normal_kgDM_TLU_day[myOwner.myType][mySpecies][management].value;
							concentratedFeedNeed_TLUpday <- feed_need_normal_kgDM_TLU_day[myOwner.myType][mySpecies][management];
							do updateForageFeedNeed;
						}
						myLivestock <- myLivestock + ags;
					}
				}
			}
		}
		
		// set parameters for fattening activities
		loop i over:FAT_NB_CYCLES.keys {
 			FAT_DURATION[i] <- int(length_FATTENINGPERIOD_days/FAT_NB_CYCLES[i]);
 		}
				
		ask household {
			do updateTLUyear;
		}
		
		// CREATE Household STOCKs
		ask household {
			loop j over:HH_STORED_GOODS {
				int ind <- HH_STORED_GOODS index_of(j) + 1 ;
				create stock returns:new_stock with:[
				biomass:: j,
				myLocation::home,
				myOwner::self
				];
				add first(new_stock) to:self.myStocks;
			}
			
			loop s over: myStocks {
				if s.biomass = STRAW {
					s.myLocation <- myAgriculturalPlots closest_to(home); 
				}
				
				if s.biomass = MILLET_SEED or GROUNDNUT_SEED {
					string use <- MILLET;
					if (s.biomass = GROUNDNUT_SEED) {
						use <- GROUNDNUT_SEED;
					}
					
					float VDM <- sum(myAgriculturalPlots where (each.landUse = use) accumulate each.area_ha) * SEED_DENSITY_KGDMHA[use];
					float VN <- BIOMASS_kgNperkgDM[s.biomass]; 
					s.level_kgDM_Ncontent <- VDM::VN;
				}
			}
		}
		
		create saver;
		if (rewrite_data) {
			ask saver {
				do initClearFiles;
			}
		}
		
		//* terroir data
		terroirArea_ha <- sum(world.agents of_generic_species(plot) accumulate each.area_ha);
		write "terroirArea: " + terroirArea_ha + " - " +  sum(agriculturalPlot accumulate each.area_ha);
	
		loop i over: LAND_UNITS_NAMES {
			float totalArea <- sum(world.agents of_generic_species(plot) where (each.myLandUnit = i) accumulate (each.area_ha));	
			add i::totalArea to:landUnitsAreas_ha;
		}

		// init trees
		ask world.agents of_generic_species(plot) {
			int tree0 <- int(initNb_trees/2);
			int tree1 <- int(tree0/1.5);
			int tree2 <- initNb_trees - tree0 - tree1;
			notPrunedTrees <- ([0::(tree0::0.0), 1::(tree1::0.0), 2::(tree2::0.0), 3::(0::0.0), 4::(0::0.0)]);
		}		

		//* agricultural plot vegetation stocks
		ask agriculturalPlot {
			float value_ha <- gauss(INIT_INFIELD_GRASS_HA[myLandUnit][0], INIT_INFIELD_GRASS_HA[myLandUnit][1]) with_precision 2;
			if value_ha > 0 {
				do incrementProductStock(GRASS,(area_ha * value_ha));
			}	
			NStock_kgN <- INIT_NSTOCK_kgNHa[myLandUnit] * area_ha;
		}
		
		if (save_globalVariables and !batch_mode) {
			ask saver {
				do saveGlobalVariable(0);
				do saveHouseholdData(0);
			}
		}
		if (save_periods and consecutiveYears) {
			ask saver {
				do updatePeriodsFile;
				do savePeriods;
			}
			
		}
		
		if (save_stocks){
			ask saver {
				do saveStocks;
			}
		}
	}
}