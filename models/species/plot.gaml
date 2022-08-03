/**
 *  Author: grillot
 *  Description:  plot agent and childs (housingPlot and agriculturalPlot)
 */

model plot

import "../constants.gaml"
import "../inputs/parameters.gaml"

import "village.gaml"
import "livestockHerd.gaml"

global {
	string path_outputs <- "../../outputs/";
}

species plot {
	// ************* variables ***********************************
	float area_ha;											// hectares
	string myLandUnit;
		

	// N available & fertilization	
	pair<float, float> Navailable_ha_currentProd;		// updated only when yield is calculated (N available)
	float coef_Ferti_currentP;
	
		// trees
	int initNb_trees;
	map<int, pair<int,float>> prunedTrees <- [];
	map<int, pair<int,float>> notPrunedTrees <- [];
	float deadWoodStock_kgDM <- 0.0;						// in kgDM
		
	// trees
	float tree_totalVeg_pruned {
		float val <- sum(prunedTrees accumulate each.value);
		if val = nil {
			val <- 0.0;
		}
		return val;		
	}	
	
	float tree_totalVeg_notPruned {
		float val <- sum(notPrunedTrees accumulate each.value);
		if val = nil {
			val <- 0.0;
		}
		return val;		
	}	
	
	float tree_totalVegetation {
		return tree_totalVeg_pruned() + tree_totalVeg_notPruned();		
	}	
	
	int nbTree {
		int val <- sum(notPrunedTrees accumulate each.key);
		int val2 <- sum(prunedTrees accumulate each.key);
		if val = nil {
			val <- 0;
		}
		if val2 = nil {
			val2 <- 0;
		}
		return val + val2;		
	}
	
	//---------- no use but as view or saver -------------------------------------
	// N balance (used only by viewer)
	float balance_kgNapparent_ha <- 0.0;
	rgb balance_apparent_color <- #black;	

	// input & output (used only by saver)
	float input_kgNapparent <- 0.0;
	float output_kgNapparent <- 0.0;
	
	float input_kgN_nonapparent <- 0.0;
	float output_kgN_nonapparent <- 0.0;
	//---------- no use but as view or saver -------------------------------------
	
	
	// ************* actions ***********************************
	float destockPlot (string biomassType, float gathered_kgDM) {
		float val_kgN <- destockTree(biomassType, gathered_kgDM);
		return val_kgN;
	}
	
	float destockTree (string biomass, float value){
		if biomass = WOOD {
			do decrementDeadWoodStock(value);
			return BIOMASS_kgNperkgDM[biomass];
		}
	}
	
	action decrementPrunedTrees (int ind, float decrement) {
		int k <- prunedTrees[ind].key;
		float val <- prunedTrees[ind].value - decrement;
		prunedTrees[ind] <- k::val;
	}
	
	action decrementNotPrunedTrees (int ind, float decrement) {
		int nbT <- notPrunedTrees[ind].key;
		float treeVeg <- notPrunedTrees[ind].value;
		
		float prod_pTree <- treeVeg / nbT;
		int nbPrunedT <- int(decrement/prod_pTree);
		if nbPrunedT = 0 {
			nbPrunedT <- 1;
		}
		float vegPrunedTrees <- prod_pTree * nbPrunedT;
		float vegLeft <- vegPrunedTrees - decrement;
		
		notPrunedTrees[ind] <- (nbT - nbPrunedT) :: ((treeVeg - vegPrunedTrees));
				
		if prunedTrees[ind] = nil {
			add ind::((nbPrunedT)::(vegLeft)) to:prunedTrees;
		} else {
			prunedTrees[ind] <- (prunedTrees[ind].key + nbPrunedT) :: ((prunedTrees[ind].value + vegLeft));
		}
	}
		
	action decrementDeadWoodStock (float value) {
		deadWoodStock_kgDM <- (deadWoodStock_kgDM - value);
	}
	
	// update variables **
	action updatePruningIntensity {
		int ind <- 0;
		int ind_increment;
		
		int nbT <- 0;
		float val <- 0.0;
		
		pair<int,float> temp_pair_to_increment;
		pair<int,float> temp_pair2;
		
		loop while: ind < treePruningIntensities {
			ind_increment <- ind + 1;
			
			temp_pair_to_increment <- notPrunedTrees[ind];
			temp_pair2 <- notPrunedTrees[ind_increment];

			// not pruned trees
			if ind_increment < treePruningIntensities {
				nbT <- temp_pair_to_increment.key + temp_pair2.key;
				val <- temp_pair_to_increment.value + temp_pair2.value;
				notPrunedTrees[ind] <- nbT::val;
				notPrunedTrees[ind_increment] <- 0::0.0;
			} else {
				notPrunedTrees[ind] <- 0::0.0;
			}
			ind <- ind + 1;
		}

			// pruned trees
		ind <- 0;
		loop while: ind < treePruningIntensities {
			ind_increment <- ind + 1;
			
			temp_pair_to_increment <- notPrunedTrees[ind_increment];
			temp_pair2 <- prunedTrees[ind];
			
			if ind_increment < treePruningIntensities {
				if temp_pair2 = nil {
					nbT <- temp_pair_to_increment.key;
					val <- temp_pair_to_increment.value;
				} else {
					nbT <- temp_pair2.key + temp_pair_to_increment.key;
					val <- temp_pair2.value + temp_pair_to_increment.value;
				}
				notPrunedTrees[ind_increment] <- nbT::val;
			}
			
			prunedTrees[] >- ind;
			ind <- ind + 1;
		}
	}
	
	action updateDeadWoodStock {
		int ind <- 0;
		deadWoodStock_kgDM <- 0.0;
		
		loop times:treePruningIntensities {
			int nbT <- notPrunedTrees[ind].key;
			float yieldYear <- meanYield_wood_kgDMpTree[ind] * nbT;
						
			if prunedTrees[ind] != nil {
				nbT <- prunedTrees[ind].key;
					
				yieldYear <- yieldYear + meanYield_wood_kgDMpTree[ind] * nbT;
			}
			deadWoodStock_kgDM <- (deadWoodStock_kgDM + yieldYear);

			ind <- ind + 1;
		}
	}
	
			
	// Yields and growth
	//* Trees
	action tree_growth (int freq) {
		int ind <- 0;
		loop times:treePruningIntensities {
			
			// not pruned trees
			int nbT <- notPrunedTrees[ind].key;
			float treeVeg <- notPrunedTrees[ind].value;
			float yieldYear <- meanYield_leaves_kgDMpTree[ind] * nbT;
			float increment <- (yieldYear/length_faidherbiaGrowth_days) * freq;
			notPrunedTrees[ind] <- (nbT) :: (treeVeg +  increment) with_precision 2;
			
			// pruned trees
			if prunedTrees[ind] != nil {
				nbT <- prunedTrees[ind].key;
				treeVeg <- prunedTrees[ind].value;
				yieldYear <- meanYield_leaves_kgDMpTree[ind] * nbT;
				increment <- (yieldYear/length_faidherbiaGrowth_days) * freq;
				prunedTrees[ind] <- (nbT) :: (treeVeg +  increment) with_precision 2;
			}
						
			ind <- ind + 1;
		} 
	}

	action clearTreeVegetation {
		loop k over: notPrunedTrees.keys {
			notPrunedTrees[k] <- notPrunedTrees[k].key::0.0;
		}
		loop k over: prunedTrees.keys {
			prunedTrees[k] <- prunedTrees[k].key::0.0;
		}			
	}
	
	action clearWood {
		deadWoodStock_kgDM <- 0.0;
	}
		
	//* deposition 
	action global_N_fixation_atmosphere {
	}
	
	action tree_N_fixation {
	}
			
	aspect balanceAspect {
		draw shape color:#white border:TYPE_COLOR[myLandUnit] wireframe:false;
	}
}

species agriculturalPlot parent:plot {
	household myOwner <- nil;
	
	pair<int,string> status <- 0::FREE;
		
		// cropping plan _ land use
	list<string> croppingPlan <- [] ;						// plot's cropping plan
	int planYear;  											// year the cropping plan started (1 = this is the first year, 2 = the second..)
	string landUse <- INIT_LAND_USE[myLandUnit];
	string future_landUse <- INIT_LAND_USE[myLandUnit];
	map<string, float> yieldHaPerCrop_kgDM <- ([]);
	map<string, float> total_production_current_year_kgDM_per_product <- ([]);
	pair<string, map<string, float>>  total_production_previous_year_kgDM_per_product;
					
		// fertility
	int fertilizationPriority;
	float organicFertilizationTargeted_kgDM <- 0.0;			// organic fertilization targeted
	float organicFertilizationInput_kgDM <- 0.0;			// kgDM applied	
	bool isManureTarget <- false;
	
	map<int, map<string, float>> fertilizerInput_kgN;
	map<int, float> organicFertilizationStatus <- ([]);		// list of years for fertilization and ratio applied over targeted
		
		// stock
	float NStock_kgN <- 0.0;								// in kgN
	map<string, float> plantStocks_kgDM <- ([]);
	map<int, pair<float, float>> dung_kgDM_Ncontent <- ([]);
		
		// related to livestock
	list<livestock_herd> paddockedLivestock <- [];
	bool isGrazable <- true;

	float NAvailable {										// in kgN
		float NinputAv;
		loop ye over: fertilizerInput_kgN.keys {
			loop biomass over: fertilizerInput_kgN[ye].keys {
				float coef <- FERTIYEAR_kgNusable_pkgNinput[ye][biomass];
				float val_kgN <- fertilizerInput_kgN[ye][biomass];
				NinputAv <- NinputAv + coef * val_kgN;
			}
		}
		Navailable_ha_currentProd <- (NStock_kgN/area_ha)::(NinputAv/area_ha);
		return NStock_kgN + NinputAv;
	}	

	//* change variables 
		// landuse
	action updateStatus (string st) {
		status <- cycle::st;
		if save_plotStatus {
			ask saver {
				do savePlotStatus(myself.myOwner, myself, st);				
			}
		}
	}
		
	action changeLandUse (string new_landUse) {
		landUse <- new_landUse;
		planYear <- croppingPlan index_of(landUse);
		do updateFutureLandUse;
		
		if status.value != FREE {
			do updateStatus(FREE);
		}
	}
	
	action updatePlanYear {
		if (planYear < length(croppingPlan) - 1){
			planYear <- planYear + 1;
		} else {
			planYear <- 0;
		}
	}
		
	action updateLandUse {
		// land_use
		landUse <- croppingPlan[planYear];
		do updateFutureLandUse;
		
		if status.value != FREE {
			do updateStatus(FREE);
		}
	}
	
	action updateFutureLandUse {
		// future land_use (n+1)
		if (planYear < length(croppingPlan) - 1){
			future_landUse <- croppingPlan [planYear + 1];
		} else {
			future_landUse <- croppingPlan[0];
		}
	}
	
	// stocks
	action incrementProductStock(string biomass, float increment_kgDM) {
		if increment_kgDM <= 0 {
			write "in plot, increment_kgDM <= 0 " + increment_kgDM + " - " + biomass;
		} else {
			if biomass in plantStocks_kgDM.keys {
				plantStocks_kgDM[biomass] <- plantStocks_kgDM[biomass] + increment_kgDM ;
			} else {
				add biomass::increment_kgDM to: plantStocks_kgDM;
			}
		}
	}
	
	action updateDung_kgDM {
		int stillHarvestableStep <- cycle - length_dungIsHarvestable_day;
		loop i over:dung_kgDM_Ncontent.keys { 
			if i < stillHarvestableStep {
				float value_kgDM <- dung_kgDM_Ncontent[i].key;
				float Ncontent <- dung_kgDM_Ncontent[i].value;
				float value_kgN <- value_kgDM * Ncontent;
				do isFertilized_inN(DUNG, value_kgN);
				dung_kgDM_Ncontent[] >- i;
			}
		} 
	}
	
	// ------ viewing and saving purposes only ----------//
	// balances parameters
	action incrementInput_apparent (float increment) {
		input_kgNapparent <- input_kgNapparent + increment;
	}
	
	action incrementOutput_apparent (float increment) {
		output_kgNapparent <- output_kgNapparent + increment;
	}
	
	action incrementInput_nonapparent (float increment) {
		input_kgN_nonapparent <- input_kgN_nonapparent + increment;
	}
	
	action incrementOutput_nonapparent (float increment) {
		output_kgN_nonapparent <- output_kgN_nonapparent + increment;
	}
	
	// viewing purpose only
	action updateApparentBalance_kgNha {
		balance_kgNapparent_ha <- (input_kgNapparent - output_kgNapparent)/area_ha;
	}
	
	action clear_balance_indicators {
		input_kgNapparent <- 0.0;
		output_kgNapparent <- 0.0;
		input_kgN_nonapparent <- 0.0;
		output_kgN_nonapparent <- 0.0;
	}	
	// ------ end viewing and saving purposes only ----------//
	
	// -------- actions : stock / destock and increment / decrement ------------------------ //
	float destockPlot (string biomassType, float gathered_kgDM) {
		// PLANT PRODUCTS
		if biomassType in PLANTPRODUCTS {
			do decrementProductStock(biomassType, gathered_kgDM);
			float Ncontent <- BIOMASS_kgNperkgDM[biomassType];
			do incrementOutput_apparent(gathered_kgDM * Ncontent);
			return Ncontent;
		}
		
		if biomassType = DUNG {
			float Ncontent <- decrementDungHarvestable(gathered_kgDM);
			do incrementOutput_apparent(gathered_kgDM * Ncontent);
			
			organicFertilizationInput_kgDM <- organicFertilizationInput_kgDM - gathered_kgDM;
			if organicFertilizationInput_kgDM < 0 {
				organicFertilizationInput_kgDM <- 0.0;
			}
			return Ncontent;
		}
		
		// WOOD
		if biomassType = WOOD {
			float Ncontent <- destockTree(biomassType, gathered_kgDM);
			do incrementOutput_apparent(gathered_kgDM * Ncontent);
			return Ncontent;
		}
	}

	float decrementDungHarvestable (float decrement_kgDM) {
		float totalNcontent;
		float totalGathered_kgDM;		
		loop theDay over: dung_kgDM_Ncontent.keys {
			float stock_kgDM <- dung_kgDM_Ncontent[theDay].key;		
			float stock_Ncontent <- dung_kgDM_Ncontent[theDay].value;
			float val <- min([stock_kgDM, decrement_kgDM]);
			
			if val > 0 {
				float gather_kgDM <- totalGathered_kgDM;
				totalGathered_kgDM <- totalGathered_kgDM + val;
				
				if val = decrement_kgDM and val != stock_kgDM {
					float vDM <- stock_kgDM - val;
					dung_kgDM_Ncontent[theDay] <- (vDM::stock_Ncontent);
					
					if vDM <= 0 {
						write "in plot, VDM = " + vDM;
					}
				} else {
					dung_kgDM_Ncontent[] >- theDay;
				}
				
				decrement_kgDM <- decrement_kgDM - val;
				
				if totalNcontent != stock_Ncontent {
					totalNcontent <- (val * stock_Ncontent + gather_kgDM * totalNcontent)/ (totalGathered_kgDM);
				}
				
				if decrement_kgDM = 0 {
					break;
				}
				
			} else {
				write " in PLOT, decrement dung : val = " + val;
				dung_kgDM_Ncontent[] >- theDay;
			}
		}
		return totalNcontent;
	}
		
	action decrementProductStock(string biomass, float decrement_kgDM) {
		plantStocks_kgDM[biomass] <- (plantStocks_kgDM[biomass] - decrement_kgDM);
		if plantStocks_kgDM[biomass] = 0 {
			plantStocks_kgDM[] >- biomass;
		}
	}
		
	//* Fertilization
	action isFertilized (string fertiType, float application_kgDM, float Ncontent) {
		if application_kgDM > 0 {
			// DUNG (usefull to mark it is on the plot as household can pick it up as fuel)
			if fertiType = DUNG {
				float VN;
				if dung_kgDM_Ncontent[cycle] != nil {
					float VDM <-  dung_kgDM_Ncontent[cycle].key;
					float totalVDM <- VDM + application_kgDM;

					VN <-  dung_kgDM_Ncontent[cycle].value;
								
					if VN != Ncontent {
						VN <- (VDM * VN + application_kgDM * Ncontent)/(totalVDM);
					}
					
					dung_kgDM_Ncontent[cycle] <- (VDM::VN);
				} else {
					dung_kgDM_Ncontent[cycle] <- (application_kgDM::Ncontent);
				}
			
			// other FERTILIZERS
			} else {
				float application_kgN <- application_kgDM * Ncontent;
				do isFertilized_inN(fertiType, application_kgN);
			}
			
			// update organic fertilization target (for household to focus its next organic inputs)
			if fertiType in [DUNG, MANURE, WASTE, REFUSAL] {
				organicFertilizationInput_kgDM <- organicFertilizationInput_kgDM + application_kgDM;
				if myOwner != nil and organicFertilizationInput_kgDM > organicFertilizationTargeted_kgDM and isManureTarget {
					ask myOwner {
						do chooseManureTarget();
					}
				}
			}
			do incrementInput_apparent(application_kgDM * Ncontent);
			
			if save_plotfertilisation and (consecutiveYears or year = nb_year_simulated){
				ask saver {
					do savePlotFertilisation(myself.myOwner, myself, application_kgDM, fertiType, Ncontent);
				}
			}
			
		} else {
			write "in PLOT, is Fertilized application = " + application_kgDM;
		}
	}
	
	action isFertilized_inN (string fertiType, float Napplication) {
		if(fertilizerInput_kgN.keys contains(1)) {	
			map<string,float> mmap <- fertilizerInput_kgN[1];
			
			if(mmap.keys contains (fertiType)) {
				add (mmap[fertiType] + Napplication) at: fertiType to: mmap;
			} else { 
				add (Napplication) at: fertiType to: mmap;
			}
				
		} else {
			add ([fertiType::Napplication]) at: 1 to:fertilizerInput_kgN;
		} 
	}
	
	// when yield is computed
	action updateFertilizerInput {
		map<int, map<string, float>> mapi;
		
		loop k over: fertilizerInput_kgN.keys {
			map<string, float> m <- fertilizerInput_kgN[k];
			int newK <- k + 1;
			
			if newK <= length(FERTIYEAR_kgNusable_pkgNinput) {
				add newK::m to: mapi;
			}
		}
		
		fertilizerInput_kgN <- mapi;
		organicFertilizationInput_kgDM <- 0.0;
	}
	
	// annual
	action updateFertilizationStatus {
		if organicFertilizationTargeted_kgDM > 0 {
			float ratio <- (organicFertilizationInput_kgDM/organicFertilizationTargeted_kgDM);
			
			if ratio < 0 {
				write "in plot, ratio fertilization status: " + ratio;
				ask world {do pause;}
			} else {
				if farmingSeason_year in organicFertilizationStatus.keys {
					if ratio = 0 {
						organicFertilizationStatus[] >- farmingSeason_year;
					} else {
						organicFertilizationStatus[farmingSeason_year] <- ratio;
					}
				} else {
					if ratio > 0 { 
						add farmingSeason_year::ratio to:organicFertilizationStatus;
					}
				}			
			}
		}		
	}
	
	action tree_N_fixation { // TODO test
//		int nbT <- nbTree();
//		float flow_kgN <- tree_fixation_kgN_tree_year * nbT;
//		NStock_kgN <- NStock_kgN + flow_kgN;
//		
//		string biomassType <- ATMO_N;
//		do incrementInput_nonapparent(flow_kgN);
//		
//		ask world {
//			do updateFlowMaps_kgN (nil, myself.myOwner, biomassType, flow_kgN, [RESPIRATION, RESPIRATION], [PLOT, myself.myLandUnit]);
//		}
	}
	
	//* landuse: yields
	action computeYield {
		float coef_ferti <- getFertilizationCoef();

		float product_kgDM;
		float product_byproduct_kgDM;
		float coproduct_kgDM;
		
		// total yield
		float Y0;
		ask first(village) {
			Y0 <- LU_Y0PRODUCT_DM_ha[myself.landUse];
		}
		
		// product yield
		string product <- LANDUSE_PRODUCTS_COPRODUCTS_NAMES[landUse][0];
		
		product_kgDM <- Y0 * coef_ferti * area_ha;
		
		if landUse = MILLET {		
			product_kgDM <- product_kgDM * coefYieldMillet;
		}

		if (product in GRAIN_kgDM_TOTAL_kgDM.keys) {
			product_byproduct_kgDM <- product_kgDM / GRAIN_kgDM_TOTAL_kgDM[product];
		} else {
			product_byproduct_kgDM <- product_kgDM;
		}
			
		if product_byproduct_kgDM > 0 {		
			add product::product_byproduct_kgDM to:total_production_current_year_kgDM_per_product;
		}

		// coproduct
		string coproduct <- LANDUSE_PRODUCTS_COPRODUCTS_NAMES[landUse][1];
		if coproduct != nil {
			coproduct_kgDM <- product_kgDM * RATIO_COPRODUCT_PRODUCT_kgDM_kgDM[landUse];
			
			if coproduct_kgDM > 0 {
				add coproduct::coproduct_kgDM to:total_production_current_year_kgDM_per_product;	
			}
		}
		
		if landUse in IS_CROP {
			float mean <- freshGrassMeanYield_kgDMha[myLandUnit].key;
			float sd <- freshGrassMeanYield_kgDMha[myLandUnit].value;
			float yieldGrassWeed <- (gauss(mean, sd) * area_ha) with_precision 2;
			add FRESH_GRASS::yieldGrassWeed to:total_production_current_year_kgDM_per_product;
		}
		
		do updateFertilizerInput;
		NStock_kgN <- 0.0;
	}
	
	
	float getFertilizationCoef {
		float coefFerti <- 0.0;
		
		if area_ha > 0 {
			float v <- NAvailable();
			float NAvailable_ha <- v /area_ha;
			
			if v < 0 {
				write "in plot, Navailable = " + v + " - " + name + " - " + myLandUnit;
				ask world {
					do pause;
				}
			}
			
			if landUse != GROUNDNUT {	
				ask first(village) {
					coefFerti <- COEF_FERTI_PRODUCT_NAVAILABLE(myself.landUse, NAvailable_ha);
				}
			
				if coefFerti <= 0 {
					write "GET FERTILIZATION COEF : COEF = 0!! => NIL COLUMN?" + coefFerti;
				}
			} else {
				coefFerti <- 1.0;
			}
			
			//save data
			coef_Ferti_currentP <- coefFerti;
			
			return coefFerti;
		} else {
			write "in plot, area_ha = " + area_ha + " : " + name + " - " + myLandUnit;
			ask world {
				do pause;
			}
		}
	}
	
	
	//* landuse: growth	
	action vegetationGrowth (int frequency) {
		int cycleLength;
		if landUse in IS_CROP {
			cycleLength <- CROP_CYCLE_LENGTH_DAYS[landUse];
		}
		if landUse in NATURAL_VEG {
			ask first(village) {
				cycleLength <- lengthGrassCycle;
			}
		}
		
		loop i over:total_production_current_year_kgDM_per_product.keys {
			float growth_kgDM <- (plantStocks_kgDM[i] + (total_production_current_year_kgDM_per_product[i] / cycleLength) * frequency);
			
			plantStocks_kgDM[i] <- min([growth_kgDM, total_production_current_year_kgDM_per_product[i]]);

			if plantStocks_kgDM[i] > total_production_current_year_kgDM_per_product[i] {
				write "in plot,  plantStocks_kgDM[i] = " + plantStocks_kgDM[i] + " - " + total_production_current_year_kgDM_per_product[i] +
				" - " + (total_production_current_year_kgDM_per_product[i] / cycleLength);
			}
		}
		
		// N fixation by legumes
		if cycle >= (status.key + cycleLength) and status.value != MATURE{
			if landUse in CROP_FIX_N {
				float flow_kgN <- crop_legume_fixation_kgN_ha_year * area_ha;
				NStock_kgN <- NStock_kgN + flow_kgN;
				string biomassType <- ATMO_N;
				do incrementInput_nonapparent(flow_kgN);
		
				ask world {
					do updateFlowMaps_kgN (nil, myself.myOwner, biomassType, flow_kgN, [RESPIRATION, RESPIRATION], [PLOT, myself.myLandUnit]);
				}
			}
			
			if save_yields {
				if (consecutiveYears) or (year = nb_year_simulated) {
					total_production_previous_year_kgDM_per_product <- landUse::total_production_current_year_kgDM_per_product;					
				}
			}
			
			do updateStatus(MATURE);
		}
	}
		
	action naturalVegetationSenescence {
		float grassQuantity <- plantStocks_kgDM[GRASS];
		float quantity <- grassQuantity * dailySenescence;
		
		if status.key > (cycle + maxLengthSenescence_days) {
			quantity <- grassQuantity;
		}
		
		float n <- destockPlot(GRASS, quantity);
				
		if plantStocks_kgDM[GRASS] = nil {
			do updateStatus(FREE);
		}	
	}
		
	//* deposition 
	action global_N_fixation_atmosphere {
		float flow_kgN;
		ask first(village) {
			flow_kgN <- Nfixation_kgN_pRainyDay_pha * myself.area_ha;
		}
		string biomassType <- ATMO_N;
		NStock_kgN <- NStock_kgN + flow_kgN;
		
		do incrementInput_nonapparent(flow_kgN);
		
		ask world {
			do updateFlowMaps_kgN (nil, myself.myOwner, biomassType, flow_kgN, [RESPIRATION, RESPIRATION], [PLOT, myself.myLandUnit]);
		}
	}
 
	
	// ASPECT
	aspect land_unit {	
		draw shape color: TYPE_COLOR[myLandUnit] border:#black wireframe:false;
	}
	
	aspect land_use {
		draw shape color: LU_COLOR[landUse] border:TYPE_COLOR[myLandUnit] wireframe:false;
	}
	
	aspect owner {	
		if (myOwner != nil) {
			draw shape color: HH_TYPE_COLOR[myOwner.myType] border:TYPE_COLOR[myLandUnit] wireframe:false;
		} else {
			draw shape color: #white border: TYPE_COLOR[myLandUnit] wireframe:false;
		}
	}
	
	aspect balanceAspect {
		draw shape color:balance_apparent_color border:TYPE_COLOR[myLandUnit] wireframe:false;
	}
}

species housingPlot parent:plot{	
	init {
		balance_kgNapparent_ha <- 1000.0;
	}

	// ASPECT
	aspect land_unit {
		draw shape color: TYPE_COLOR[myLandUnit] border:#black wireframe:false;
	}
}