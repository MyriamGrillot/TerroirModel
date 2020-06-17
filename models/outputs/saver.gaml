/**
* saver
* Author: grillot
* Description: used to save data 
*/

model saver

import "../main.gaml"

import "../species/plot.gaml"
import "../species/stock.gaml"
import "../species/household.gaml"
import "../species/livestockHerd.gaml"

global{
	string path_outputs <- "../../outputs/";
}

species saver {	
	string file_household <- "household";
	string file_household_flows <- "household_flows";
	
	string file_terroir_globales_values <- "terroir_globales_values";
	string file_terroir_cropplantation <- "terroir_cropplantation";
	string file_terroir_Y0 <- "terroir_y0";
	
	string file_terroir_periods <- "terroir_periods";
	string saved_file_terroir_periods;
	string file_terroir_landunit <- "terroir_landunit";
	
	string file_plotStatus <- (path_outputs + "terroir_plotStatuses.csv");
	string file_terroirVegetation <- (path_outputs + "terroir_vegetation.csv");
	string file_terroirYield <- "terroir_yields";
		
	string file_terroir_vegTrees <- (path_outputs + "terroir_vegTrees.csv");
	string file_terroir_woodTrees <- (path_outputs + "terroir_woodTrees.csv");
		
	string file_hh_stocks <- "household_stocks";
	string file_hh_stocks_N <- "household_stocks_N";
	
	string file_household_need <- "household_needs";
		
	string file_plot_fertilisation <- "plot_fertilisation";
	
	string file_herds <- "herds";
	string file_herds_needCoverage <- "herd_needCoverage";
	string file_herds_paddock <- "herds_paddock";
	
	string file_herds_dailyNeed <- "herds_daily_needs";
	string file_herds_dailyIngestion <- "herds_daily_ingestion";
	
	string file_herds_dailyExcreta <- "herds_daily_excreta";
			
	string fileImage_Nbalance_agplot <- "N_balance_agplot";
	string fileImage_Nbalance_harea <- "N_balance_harea";
	
	// file names -------------------------------------------------------------
	action getFileName (string myname, int run) {
		string filename <- "" + path_outputs + myname + "_" + cycle + "_" + scenario_name + "_" + run +".csv";		
		return (filename);
	}
		
	action getSHPFileName (string myname, int run) {
		string filename <- "" + path_outputs + "shapes/" + myname + "_" + cycle + "_" + scenario_name + "_" + run +".shp";
		return (filename);
	}
	
	action updatePeriodsFile {
		saved_file_terroir_periods <- getFileName(file_terroir_periods, 0);
		if rewrite_data or !file_exists(saved_file_terroir_periods){
			save ["year", "period", "day"] to: (saved_file_terroir_periods) type:csv header:false rewrite: true;
		}
	}

	// save -------------------------------------------------------------
	action saveHouseholdData (int run) {
		string myfile <- getFileName(file_household, run);	
				
		if rewrite_data or !file_exists(myfile) {
			save ["household", "type", "HFarea_ha", "BFarea_ha", "population", 
					"TLU_GRAZING", "TLU_DRAUGHT", "Nb days Fat", "TLU_FAT"
			] to: (myfile) type:csv header:false rewrite: true;
		}
				
		ask household {	
			save [name, myType, myHFarea(), myBFarea(), inhabitants, TLU_G_year, TLU_D_year, TLU_FAT_year.key, TLU_FAT_year.value
			] to: (myfile) type:csv header: false rewrite: false;
		}
	}
	

	action initClearFiles {
		if rewrite_data {		
			// herds
			if save_herdDailyIngestionNeed {
				save ["year", "month", "cycle", "ownerType", "household", "species", "herd", "TLU", "management", 
						"low_kgDM", "high_kgDM"
					] to: string(getFileName(file_herds_dailyNeed, 0)) type:csv header: false rewrite: true;
				save["year", "month", "cycle", "ownerType", "household", "species", "herd", "TLU", "management", 
						"landUnit", "quality", "biomass", "quantity_kgDM"
					] to: string(getFileName(file_herds_dailyIngestion, 0)) type:csv header: false rewrite: true;
			}
			
			if save_herdDailyExcretion {
				save ["year", "month", "cycle", "ownerType", "household", "species", "herd", "TLU", "management", "type", "quantity_kgDM"
				] to: string(getFileName(file_herds_dailyExcreta, 0)) type:csv header: false rewrite: true;
			}
			
			// plot status
			if save_plotStatus {
				save ["year", "month", "cycle", "ownerType", "owner", "landUnit", "plot", "areaHa", "landUse", "status"
				] to: (file_plotStatus) type:csv header: false rewrite: true;
			}
		}
	}
	
	// global values
	action saveGlobalVariable (int run) {

		// grid - land units values
		float ha <- sum(housingPlot accumulate each.area_ha);
		float hf <- sum(agriculturalPlot where(each.myLandUnit = HOMEFIELD) accumulate each.area_ha);
		float bf <- sum(agriculturalPlot where(each.myLandUnit = BUSHFIELD) accumulate each.area_ha);
		float rgl <- sum(agriculturalPlot where(each.myLandUnit = RANGELAND) accumulate each.area_ha);
		
		string myfile <-  getFileName(file_terroir_globales_values, run);
		
		if(rewrite_data) {
			save ["shape_name", "scenario", "run", "seed", "init_household_file", "init_ruminants", "init_draught",
				"terroirArea_ha", "housingarea_ha", "homefield_ha", "bushfield_ha", "rangeland_ha",
				"rain_mm", "lengthRainySeason_days", "step_beg_rain", "lengthGrassCycle", 
				"Ndeposition_rainyDay_ha", "faidherbia_step_begCycle", "faidherbia_loose_leaves", 
				"startSowing", "endSowing", "mineralFertilizationStep"
				] to: (myfile) type:csv header:false rewrite:true;	
		}
		
		ask first(village){
			save [shape_name, scenario_name, run, seed, init_households, init_ruminants, init_draught, 
				terroirArea_ha, ha, hf, bf, rgl,
				rain_mm, lengthRainySeason_days, step_beg_rain, lengthGrassCycle, 
				Nfixation_kgN_pRainyDay_pha, faidherbia_step_begCycle, faidherbia_loose_leaves, 
				startSowing, endSowing, mineralFertilizationStep
			] to: (myfile) type:csv header: false rewrite:false;
		}
		
		// save crop plantation cycles
		myfile <-  getFileName(file_terroir_cropplantation, run);
		
		if rewrite_data {
			save ["year", "crop", "cycle"
			] to: (myfile) type:csv header:false rewrite: true;
		}
		
		ask first(village) {
			loop i over: CROP_PLANTATION.keys {
				save [year, i, CROP_PLANTATION[i]] to: myfile type:csv header:false rewrite: false;
			}
		}
		
		// save Y0
		myfile <-  getFileName(file_terroir_Y0, run);
		
		if rewrite_data {
			save ["year", "crop", "Y0"
			] to: (myfile) type:csv header:false rewrite: true;
		}
		
		ask first(village) {
			loop i over: CROP_PLANTATION.keys {
				save [year, i, LU_Y0PRODUCT_DM_ha[i]] to: myfile type:csv header:false rewrite: false;
			}
		}		
	}
	
	// periods
	action savePeriods {
		map<string, bool> periods <- ["rainy season"::rainySeason, "manure spreading"::organicFertilizationPeriod, "mineral fertilization"::mineralFertilizationPeriod, 
			"cropping season"::croppingSeason, "sowing"::sowingPeriod, "harvest"::harvestPeriod, 
			"prune trees"::pruneTreesPeriod, "wood gathering"::woodGatheringPeriod, 
			"dung gathering"::dungGatheringPeriod,
			"grass growth"::naturalVegetationGrowth, "grass cutting"::grassCuttingPeriod, 
			"crop growth"::cropGrowth, "fattening"::fatteningPeriod,
			"tree growth"::treeGrowth, "tree loose leaves"::treeLooseLeaves];
		
		bool anySave <- false;
		loop p over:periods.keys {
			if periods[p] {
				do savePeriod(p);
				anySave <- true;
			}
		}
		// in order to keep track of cycle without periods
		if anySave = false {
			do savePeriod("no period is on");
		}
	}
	
	// save species
	action savePlots_balance (int run) {
		save agriculturalPlot to: string(getSHPFileName(fileImage_Nbalance_agplot, run)) type:"shp" with:[
			myLandUnit::"landUnit", myOwner::"owner", area_ha::"areaHa",
			input_kgNapparent::"inkgNapp", output_kgNapparent::"outkgNapp",
			input_kgN_nonapparent:: "inkgN_nonap", output_kgN_nonapparent::"outkgN_nonap"
		];
		
		save housingPlot to: string(getSHPFileName(fileImage_Nbalance_harea, run)) type:"shp" with:[
			myLandUnit::"landUnit",  area_ha::"areaHa",
			input_kgNapparent::"inkgNapp", output_kgNapparent::"outkgNapp",
			input_kgN_nonapparent:: "inkgN_nonap", output_kgN_nonapparent::"outkgN_nonap"
		];
	}
	
			
	action saveHerdNeedCoverage (int run) {

		string myfile <- getFileName(file_herds, run);
		string myfile_cov  <- getFileName(file_herds_needCoverage, run);	
		
		if rewrite_data {
			save ["year", "month", "ownerType", "owner", "specie", "management", "herdName", "month_death"
			] to:myfile type:csv header: false rewrite: true;
			
			save ["year", "ownerType", "specie", "management", "monthRecord", "herdName", "TLU", "month", "distributed_kgDM", "need_kgDM"
			] to:myfile_cov type:csv header: false rewrite: true;
		}
	
		ask world.agents of_generic_species(livestock_herd) {
			save [year, month, myOwner.myType, myOwner.name, mySpecies, management, name, 0] to:myfile type:csv header: false rewrite: false;
			loop i over: needCoverage.keys {
				list<float> l <- needCoverage[i];
				save [year, myOwner.myType, mySpecies, management, month, name, value_TLU, i, l[0], l[1]] to:myfile_cov type:csv header: false rewrite: false;				
			}
		}
		
		ask household {
			float vTLU; 
			loop l over: deadLivestock_year.keys {			
				list<string> ls <- deadLivestock_year[l];
				list<float> lf <- deadLivestock_month_year[l];
				vTLU <- lf[1];
				save [year, month, myType, name, ls[0], ls[1], l, int(lf[0])] to:myfile type:csv header: false rewrite: false;

				 map<int, list<float>> m <- deadLivestock_NeedCoverage[l];
				loop i over: m.keys {
					list<float> lf <- m[i];
					save [year, myType, ls[0], ls[1], month, l, vTLU, i, lf[0], lf[1]] to:myfile_cov type:csv header: false rewrite: false;				
				}		
			}
		}
	}
		
	action saveTerroir_yields (int run) {
		string myfile <- getFileName(file_terroirYield, run);	
		
		if rewrite_data {
			save ["year", "run", "cycle", "owner", "ownerT", "plot", "landUnit", "landUse", "area_ha", 
			"NsoilStock_kgN_ha", "Navailable_kgN_ha", "coef_Ferti_currentP", "biomass", "production_kgDM", "product", "ratio product"
			] to: myfile type:csv header: false rewrite:true;
		}
				
		ask agriculturalPlot {
			float ratio_real_product <- 1.0;

			string land_use <- total_production_previous_year_kgDM_per_product.key;
			if land_use != nil {
				map<string, float> production <- total_production_previous_year_kgDM_per_product.value;
				
				loop product over:production.keys {
					float product_kgDM <- production[product];			
					string product_only <- product;
					
					if  GRAIN_kgDM_TOTAL_kgDM[product] != nil {
						ratio_real_product <- GRAIN_kgDM_TOTAL_kgDM[product];
						product_only <- PRODUCT_NAME[product];
					}
					
					string n;
					string ot;
					if myOwner != nil {
						n <- myOwner.name;
						ot <- myOwner.myType;
					}
					save [year, run, cycle, n, ot, name, myLandUnit, land_use, area_ha, 
						Navailable_ha_currentProd.key, Navailable_ha_currentProd.value, coef_Ferti_currentP, 
						product, product_kgDM, product_only, ratio_real_product
					] to: (myfile) type:csv header: false rewrite:false;	
				}		
			}
		}
	}
	
	//// save household flows 	
	action saveFlows (int run){

		string myfile <- getFileName(file_household_flows, run);	
		
  		if rewrite_data {
			save ["household", "originAct", "destinationAct", "originLU", "destinationLU", 
					"biomass", "quantity_kgN"
			] to: myfile type:csv header: false  rewrite: true;
		}
		
   		// household		
   		loop hh over:household {			
   			loop flow over: hh.flows_kgN {
   				if empty(hh.flows_kgN.keys) = false {
   					loop biomass over:hh.flows_kgN.keys {
   						
   						map<pair<list<string>, list<string>>, float> theM;	
						theM <- hh.flows_kgN[biomass];
				
						if empty(theM) = false {
							loop ls over:theM.keys {
								float val <- theM[ls];
								list<string> act <- ls.key;
								list<string> lu <- ls.value;
															
								if val != 0 {
									save [hh.name, act[0], act[1], lu[0], lu[1], biomass, val
									] to: myfile type:csv header: false rewrite:false;
								}
							}				
						} 	
					}
				}
				hh.flows_kgN <- map([]);
			}
		}
		
		// village	
		ask first(village) {		
   			loop flow over: villageFlows_kgN {
   				if empty(villageFlows_kgN.keys) = false {
   					loop biomass over:villageFlows_kgN.keys {
   						
   						map<pair<list<string>, list<string>>, float> theM;	
						theM <- villageFlows_kgN[biomass];
				
						if empty(theM) = false {
							loop ls over:theM.keys {
								float val <- theM[ls];
								list<string> act <- ls.key;
								list<string> lu <- ls.value;
															
								if val != 0 {
									save ["none", act[0], act[1], lu[0], lu[1], biomass, val] to: myfile type:csv header: false rewrite:false;
								}
							}				
						} 	
					}
				}
				villageFlows_kgN <- map([]);
			}
		}
	}
	
	// uniques: saved by agents within simulation (not batched) -----------
	action savePeriod (string period) {
		save [year, period, cycle] to: saved_file_terroir_periods type:csv header:false rewrite: false;
	}
	
	action saveTerroir_vegetation {
		float areaHa <- terroirArea_ha;		
		// crops
		loop landUni over: AGRIC_PLOT_LANDUNITS{
			loop landuse over:LANDUSE_PRODUCTS_COPRODUCTS_NAMES.keys {
				loop biomass over: LANDUSE_PRODUCTS_COPRODUCTS_NAMES[landuse] {
					if biomass != nil {
						list<agriculturalPlot> plotList <- agriculturalPlot where (each.myLandUnit = landUni and each.landUse = landuse and each.plantStocks_kgDM[biomass] != nil);
						float total_productStock_kgDM;
						
						if !empty(plotList) and plotList != nil {
							total_productStock_kgDM <-  sum(plotList accumulate (each.plantStocks_kgDM[biomass]));
							areaHa <- sum(plotList accumulate (each.area_ha));
																		
							save [year, month, landUni, landuse, areaHa, biomass, total_productStock_kgDM with_precision 2
							] to: (file_terroirVegetation) type:csv header: false rewrite:false;
						}
					}
				}
			}
		}
	}
	
	action saveStocks {
		string myfile <- getFileName(file_hh_stocks, 0);
		string myfileN <- getFileName(file_hh_stocks_N, 0);
		
		if (rewrite_data) {
			save "" + "year" + "," + "month" + "," + "household" + "," + "stockType," + (string(HH_STORED_GOODS) replace ("[","") replace ("]","")) 
			to: myfile type:csv header: false rewrite: true;
			
			save "" + "year" + "," + "month" + "," + "household" + "," + "stockType," + (string(HH_STORED_GOODS) replace ("[","") replace ("]","")) 
			to: myfileN type:csv header: false rewrite: true;
		}
		
		ask household {
			list<float> theList <- [];
			list<float> theList_N <- [];
			
			list<float> theListSurplus <- [];
			list<float> theList_NSurplus <- [];
			
			loop i over:myStocks {
				float kgDM <- i.level_kgDM_Ncontent.key;
				add kgDM to:theList;
				add i.level_kgDM_Ncontent.value to:theList_N;
				
				kgDM <- i.surplus_kgDM_Ncontent.key;
				add kgDM to:theListSurplus;
				add i.surplus_kgDM_Ncontent.value to:theList_NSurplus;
			}
			save "" + year + "," + month + "," + name + "," + "stock"+ "," + (string(theList) replace ("[","") replace ("]","")) 
			to: myfile header: false rewrite:false;
			save "" + year + "," + month + "," + name + "," + "stock"+ "," + (string(theList_N) replace ("[","") replace ("]","")) 
			to: myfileN header: false rewrite:false;
			
			save "" + year + "," + month + "," + name + "," + "surplus"+ "," + (string(theListSurplus) replace ("[","") replace ("]","")) 
			to: myfile header: false rewrite:false;
			save "" + year + "," + month + "," + name + "," + "surplus"+ "," + (string(theList_NSurplus) replace ("[","") replace ("]","")) 
			to: myfileN header: false rewrite:false;
		}
	}
		
	action savePaddock {
		if !batch_mode {
			string myfile <- getFileName(file_herds_paddock, 0);		
			loop lu over:AGRIC_PLOT_LANDUNITS {
				loop luse over: LAND_USES {
					ask agriculturalPlot where(each.myLandUnit = lu and each.landUse = luse and !empty(each.paddockedLivestock)) {
						int nbHerds <- length(paddockedLivestock);
						save [year, month, cycle, lu, luse, myOwner.name, myOwner.myType, name, area_ha, nbHerds,
							 sum(paddockedLivestock accumulate (each.value_TLU)) with_precision 2
						] to: myfile type:csv header: false rewrite: false;
					}
				}
			}
		}
	}

	action saveHerdDailyExcreta (livestock_herd liv, string type, float quantity_kgDM) {
		if !batch_mode {
			save [year, month, cycle, liv.myOwner.myType, liv.myOwner.name, liv.mySpecies, 
					liv, liv.value_TLU, liv.management, type, quantity_kgDM
			] to: string(getFileName(file_herds_dailyExcreta, 0)) type:csv header: false rewrite: false;			
		}
	}

	action saveHerdDailyNeed (livestock_herd liv, float low_kgDM, float high_kgDM) {
		if !batch_mode {			
			save [year, month, cycle, liv.myOwner.myType, liv.myOwner.name, liv.mySpecies, 
				liv, liv.value_TLU, liv.management, low_kgDM, high_kgDM
			] to: string(getFileName(file_herds_dailyNeed, 0)) type:csv header: false rewrite: false;
		}
	}

	action saveHerdDailyIngestion (livestock_herd liv, string landU, string biomass, float quantity_kgDM) {
		if !batch_mode {
			string quality;
			if biomass in LOW_FORAGE {
				quality <- "low";
			} else {
				quality <- "high";
			}
			save [year, month, cycle-1, liv.myOwner.myType, liv.myOwner.name, liv.mySpecies, 
				liv, liv.value_TLU, liv.management, landU, quality, biomass, quantity_kgDM	
			] to: string(getFileName(file_herds_dailyIngestion, 0)) type:csv header: false rewrite: false;
		}
	}

	action savePlotFertilisation(household hh, agriculturalPlot ploti, float quantity_kgDM, string biomass, float Ncontent) {
		if !batch_mode {	
			
			string myfile <- string(getFileName(file_plot_fertilisation, 0));
					
			
			// plot fertilisation			 
			if !file_exists(myfile) {
				save ["year", "month", "ownerType", "owner", "landUnit", "landUse", "plot", "areaHa", 
						"quantity_kgDM", "biomass", "Ncontent"] to: myfile  type:csv header:false rewrite: true;
			}
			
			string a <- nil;
			string b <- nil;
			
			if hh != nil {
				a <- hh.myType;
				b <- hh.name;
			}
			
			save [year, month, a, b, ploti.myLandUnit, ploti.landUse, ploti.name, ploti.area_ha, 
					quantity_kgDM, biomass, Ncontent
			] to:myfile type:csv header: false rewrite: false;			
		}
	}
	
	action saveHouseholdNeed_ingestion {
		if !batch_mode {
			
			string myfile <- getFileName(file_household_need, 0);
			if rewrite_data {
				save ["year", "month", "day", "type", "household", "original_needs", "quantity_kgDM"] to:myfile type:csv header: false rewrite: true;
			}
			
			ask household {
				loop b over: foodNeeds_kgDM.keys {
					save [year, month, cycle, myType, name, "need", foodNeeds_kgDM[b]] to:myfile type:csv header: false rewrite: false;
				}
				
				loop b over: foodIngestions_kgDM.keys {	
					save [year, month, cycle, myType, name, "ingestion", foodIngestions_kgDM[b]] to:myfile type:csv header: false rewrite: false;
				}
			}
		}	
	}

	action savePlotStatus (household hh, agriculturalPlot ploti, string st) {
		if !batch_mode {
			if (!consecutiveYears and year = nb_year_simulated) or consecutiveYears {
				if hh != nil {
					save [year, month, cycle, hh.myType, hh.name, ploti.myLandUnit, ploti.name, ploti.area_ha, ploti.landUse, st
					] to: (file_plotStatus) type:csv header: false rewrite: false;			
				} else {
					save [year, month, cycle, "nil", "nil", ploti.myLandUnit, ploti.name, ploti.area_ha,ploti.landUse, st
					] to: (file_plotStatus) type:csv header: false rewrite: false;
				}
			}			
		}
	}
}