/**
 *  Author: grillot
 *  Description: household agent
 */

model household

import "../constants.gaml"
import "../inputs/parameters.gaml"

import "village.gaml"
import "plot.gaml"
import "stock.gaml"
import "livestockHerd.gaml"

global {
	string path_outputs <- "../../outputs/";
}
	
species household {
	// "properties"
	housingPlot home;
	agriculturalPlot theDump;
	
	list<agriculturalPlot> myAgriculturalPlots <- [];
	list<livestock_herd> myLivestock <- [];

	list<livestock_herd> myLivestock_away <- [];
	list<stock> myStocks <- [];
	
	// type-related caracteristics
	string myType among:HOUSEHOLD_TYPES <- first(HOUSEHOLD_TYPES);
		
	float inhabitants <- 1.0;
	map<string, float> average_FAT_TLU;
	
	// for saving issues only
	float TLU_G_year;
	float TLU_D_year;
	pair<int,float> TLU_FAT_year;
	
	// "daily" caracteristics
	map<string, map<int, list<float>>> deadLivestock_NeedCoverage;
	map<string, list<string>> deadLivestock_year;
	map<string, list<float>> deadLivestock_month_year;
	
	agriculturalPlot manureTarget;
	map<string, float> foodNeeds_kgDM <- [];						// kgDM/adult equivalent/frequence
	map<string, float> foodIngestions_kgDM <- [];	
	bool dungGathered <- false;
	float firewoodNeed_kgDM; 										// kgDM/adult equivalent/frequence	
	
	map<string, map<pair<list<string>, list<string>>, float>> flows_kgN <- map([]);

	// area the HH has in HOME FIELD
	float myHFarea {
		return sum(myAgriculturalPlots where (each.myLandUnit = HOMEFIELD) accumulate each.area_ha);
	}
	
	// area the HH has in BUSH FIELD
	float myBFarea {
		return sum(myAgriculturalPlots where (each.myLandUnit = BUSHFIELD) accumulate each.area_ha);
	}
	
	// total area
	float my_farming_area {					
		return myHFarea() + myBFarea();
	}
	
	// list of plots currently available for grazing livestock
	list<agriculturalPlot> myGrazablePlots {
		return myAgriculturalPlots where (each.isGrazable);
	}
	
	// total TLU owned
	float total_TLU_owned {
		return sum(myLivestock accumulate each.value_TLU); 
	}
	
	// for saving issues only
	action updateTLUyear {
		TLU_G_year <- TLU_G_year + sum(myLivestock where(each.transhumance = false and each.management = FREEGRAZING) accumulate each.value_TLU);
		TLU_D_year <- TLU_D_year + sum(myLivestock where(each.transhumance = false and each.management = DRAUGHT) accumulate each.value_TLU);
		float vFat <- sum(myLivestock where(each.transhumance = false and each.management = FAT) accumulate each.value_TLU);
			
		if (vFat > 0) {
			int vk <- TLU_FAT_year.key + 1; 
			TLU_FAT_year <- vk::(TLU_FAT_year.value + vFat);
		}
	}
	
	// ACTION
	// change variables
	action updateFoodNeeds (int frequency) {
		foodNeeds_kgDM <- [];
		loop i over:FOOD {
			add i::inhabitants*FOODNEEDS_PINHABITANTS_kgDM_PDAY[i]*frequency to: foodNeeds_kgDM;
		}
		foodIngestions_kgDM <- ([]);
	}
	
	action updateCombustiblesNeed (int stepi) {
		firewoodNeed_kgDM <- inhabitants * firewoodNeed_kgDM_pinhabitant_pday * stepi;
	}
	
	
	//* stock surplus surplus
	action askUpdateFoodSurplus {		
		loop i over:HH_STORED_FOOD {
			float need_day <- inhabitants * FOODNEEDS_PINHABITANTS_kgDM_PDAY[i];
			float need_year <- need_day * year_duration_days;
			need_year <- need_year + need_year * extraShareForStock;
			float surplus_kgDM <- udpdateSurplusAndStockLevel(i, need_year);
						
			if i = MILLET_COB {
				float keep_kgDM <- need_year * ratio_save_millet_surplus;
				if surplus_kgDM > keep_kgDM {				
					do sellSurplusToMarket(i, (surplus_kgDM - keep_kgDM));
				}
			}
		}
	}
	
	action askUpdateFeedSurplus {
		loop i over:HH_STORED_FEED {
			float need_day <- 0.0;
			float need_year_kgDM;
						
			if i in LOW_FORAGE {
				loop spe over:FAT_SPECIES {
					need_year_kgDM <- need_year_kgDM + average_FAT_TLU[spe] * forage_need_increase_kgDM_TLU_day[myType][spe][FAT].key * length_FATTENINGPERIOD_days;
				}
				need_year_kgDM <- need_year_kgDM + TLU_D_year * forage_need_increase_kgDM_TLU_day[myType][EQUINE][DRAUGHT].key;
							
				if need_year_kgDM < minimum_lowForage_stored_kgDM {
					need_year_kgDM <- minimum_lowForage_stored_kgDM;
				} else {
					need_year_kgDM <- need_year_kgDM + need_year_kgDM * extraShareForStock;
				}
			}
			if i in HIGH_FORAGE {
				loop spe over:FAT_SPECIES {
					need_year_kgDM <- need_year_kgDM + average_FAT_TLU[spe] * forage_need_increase_kgDM_TLU_day[myType][spe][FAT].value * length_FATTENINGPERIOD_days;
				}
				need_year_kgDM <- need_year_kgDM + TLU_D_year * forage_need_increase_kgDM_TLU_day[myType][EQUINE][DRAUGHT].value;
				need_year_kgDM <- need_year_kgDM + need_year_kgDM * extraShareForStock;
			}
			
			if need_year_kgDM < 0 {
				write "in household, need year = " + need_year_kgDM;
			}
			do udpdateSurplusAndStockLevel(i, need_year_kgDM);			
		}
	}
	
	float woodNeed_kgDM_year;
	
	action askUpdateWoodSurplus {
		string biomassType <- WOOD;
		woodNeed_kgDM_year <- inhabitants * firewoodNeed_kgDM_pinhabitant_pday * annualUseRatioWood * year_duration_days;
		do udpdateSurplusAndStockLevel(biomassType, woodNeed_kgDM_year);
	}
	
	float udpdateSurplusAndStockLevel (string biomassType, float need_year) {
		stock theStock <-  first(myStocks where (each.biomass = biomassType));
		float stock_kgDM <- theStock.level_kgDM_Ncontent.key;
				
		float getInSurplus_kgDM <- need_year - stock_kgDM;
		float surplus_kgDM <- 0.0;
		
		if getInSurplus_kgDM > 0 and  theStock.surplus_kgDM_Ncontent.key > 0 {
			ask theStock {
				getInSurplus_kgDM <- min([getInSurplus_kgDM, theStock.surplus_kgDM_Ncontent.key]);
				float content_N <- decrementSurplus_kgDM(getInSurplus_kgDM);
				do incrementLevel(getInSurplus_kgDM, content_N);
			}
		} else {
			surplus_kgDM <- stock_kgDM - need_year;
			if surplus_kgDM > 0 {
				ask theStock {
					do updateSurplusFromStockLevel(surplus_kgDM);
				}
			} else {
				surplus_kgDM <- 0.0;
			}
		}
		return surplus_kgDM;
	}
	
	//* flows
	action updateFlowMap(string type, float flow, string originAct, string destinationAct, string originLU, string destinationLU) {

		pair<list<string>, list<string>> theP <- ([originAct, destinationAct]::[originLU, destinationLU]);	
		if !empty(flows_kgN) and type in flows_kgN.keys {
			map<pair<list<string>, list<string>>, float> theM;
			theM <- flows_kgN[type];
			
			if empty(theM) = false and theP in theM.keys {
				float val <- theM[theP] + flow;
				theM[theP] <- val;
			} else {
				flows_kgN[type] <- flows_kgN[type] + (theP::flow);
			}
		} else {
			flows_kgN <- (flows_kgN + ([type::([theP::flow])]));
		}
	}
		
	// 1- Livestock management ***********************************************************************
	//* FEEDING
	//** concentrated feed
	action feedMyLivestockConcentratedFeed {
		list<string> listDestinations;
		string biomassType <- CONCENTRATED_FEED;
						
		loop live over:myLivestock where (each.transhumance = false) {
			listDestinations <- [LIVESTOCK, live.myLocation.myLandUnit];
			float concentratedFeedNeed <- live.herd_concentrate_needs_pday();

			if concentratedFeedNeed > 0 {
				pair<list<string>, list<float>> origins <- purchaseMarket(biomassType, concentratedFeedNeed);
				float purchased_kgDM <- origins.value[0];
				float purchased_kgN;
				
				if purchased_kgDM > 0 {
					float Ncontent <- origins.value[1];
					purchased_kgN <- purchased_kgDM * Ncontent;
					ask live {
						do ingest(biomassType, myLocation, purchased_kgDM, Ncontent);
					}
					concentratedFeedNeed <- concentratedFeedNeed - purchased_kgDM;		
					
					//* flow
					list<string> listOrigins <- origins.key;
					ask world {
						do updateFlowMaps_kgN(nil, myself, biomassType, purchased_kgN, listOrigins, listDestinations);
					}				
				}							
			}
		}
	}
	
	//** Forage
	action feedMyLivestockForage {
		list<string> listOrigins;
		list<string> listDestinations;
		
		loop herd over:myLivestock where (each.transhumance = false) {
			listDestinations <- [LIVESTOCK, herd.myLocation.myLandUnit];
			int lengthNeeds <- length(herd.herdForageNeeds_dDay);
			int forageIndex <- 0;
			
			pair<list<string>, list<float>> origins;
			household theH;
						
			loop while: (forageIndex) < lengthNeeds {
				float need_kgDM <- herd.herdForageNeeds_dDay[forageIndex];
				
				list<string> listFeed <- forageBiomassNeedIndex[forageIndex];
				int indListFeed <- 0;
				
				loop while: indListFeed < length(listFeed) and need_kgDM > 0 {				
					string biomassType <- listFeed[indListFeed];
																					
					//* destock forage
					if biomassType in HH_STORED_GOODS {
						origins <- destockStorage (biomassType, herd.herdForageNeeds_dDay[forageIndex]);
						float destocked_kgDM <- origins.value[0];
						float destocked_kgN;
								
						if destocked_kgDM > 0 {
							need_kgDM <- need_kgDM - destocked_kgDM;
							destocked_kgN <- destocked_kgDM * origins.value[1];
							
							ask herd {
								do eatForageAndProduceRefusals(biomassType, destocked_kgDM, destocked_kgN, forageIndex);
							}
								
							//* flow (stored forage)
							listOrigins <- origins.key;
							ask world {
								do updateFlowMaps_kgN(myself, myself, biomassType, destocked_kgN, listOrigins, listDestinations);
							}
						}
					}
					
					if need_kgDM > 0 {
						// (FAT & DRAUGHT managements)
						if herd.myLocation in housingPlot {		
							// cut fresh grass
							if biomassType = FRESH_GRASS and grassCuttingPeriod = true {	
								float gathered_kgDM;
								
								loop while: need_kgDM > 0 {
									map<agriculturalPlot, pair<list<string>, list<float>>> theM <- gatherOnAgriculturalPlot(biomassType, need_kgDM);
									
									if empty(theM) {
										break;
									}
									
									agriculturalPlot theP;
									
									loop h over: theM.keys {
										theP <- h;
										theH <- theP.myOwner;
										break;	
									}
									
									origins <- theM[theP];
									gathered_kgDM <- origins.value[0];
					
									if gathered_kgDM > 0.0 {
										float gathered_NC <- origins.value[1];
										float gathered_kgN <- gathered_kgDM * gathered_NC;
										
										ask herd {
											do eatForageAndProduceRefusals(biomassType, gathered_kgDM, gathered_kgN, forageIndex);
										}
																				
										//* flow
										listOrigins <- origins.key;

										ask world {
											if theH != myself {
												listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
											}
											
											do updateFlowMaps_kgN(theH, myself, biomassType, gathered_kgN, listOrigins, listDestinations);
										}
										need_kgDM <- need_kgDM - gathered_kgDM;
									} else {
										break;
									}
								}
							}
							
							// purchase
							if need_kgDM > 0 and biomassType in HH_STORED_GOODS {
								map<household, pair<list<string>, list<float>>> theM <- purchaseVillage(biomassType, need_kgDM);
								
								if !empty(theM) {
									loop h over: theM.keys {
										theH <- h;
										break;	
									}
									origins <- theM[theH];
									
									float purchased_kgDM <- origins.value[0];
									float purchased_kgN <- purchased_kgDM * origins.value[1];
															
									if purchased_kgDM > 0 {
										ask herd {
											do eatForageAndProduceRefusals(biomassType, purchased_kgDM, purchased_kgN, forageIndex);
										}
										
										//* flow
										listOrigins <- origins.key;
										ask world {
											if theH != myself {
												listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
											}
											
											do updateFlowMaps_kgN(theH, myself, biomassType, purchased_kgN, listOrigins, listDestinations);
										}
									}
								}
							}
						}
					}
					indListFeed <- indListFeed + 1;
				}
				forageIndex <- forageIndex + 1;
			}
		}
	}
	
	action sellFatLivestock { 
		loop l over: myLivestock where (each.management = FAT and (each.transhumance = false)) {
			if cycle >= l.cycle_sell() or fatteningPeriod = false {
				//sell
				float value_TLU <- l.value_TLU;
				do sellHerd(l, value_TLU);
			}
		}
	}
		
	action sellHerd (livestock_herd herd, float quantity_TLU) {
		list<string> theListOrigin <- [LIVESTOCK, herd.myLocation.myLandUnit];
		list<string> theListDestination <- [EXT, EXTERIOR_LU];
		float value_kgN <- herd.herd_value_kgN();

		// fattening livestock gained weight (computed when sold)
		if herd.management = FAT {
			value_kgN <- value_kgN * weigth_gain;
		}
		
		ask world { 
			do updateFlowMaps_kgN(myself, nil, LIVESTOCK, value_kgN, theListOrigin, theListDestination);
		}
		ask herd {
			do decrementValue_TLU(quantity_TLU);
		}
	}
	
	action saveDyingLivestockNeedCoverage (livestock_herd herd) {
		string n <- herd.name;
		list<string> l <- [herd.mySpecies, herd.management];
		add n::[herd.mySpecies, herd.management] to: deadLivestock_year;
		add n::[float(month * year), herd.value_TLU] to:deadLivestock_month_year;
		add n::herd.needCoverage to:deadLivestock_NeedCoverage;
	}
	
	action purchaseFatLivestock {
		loop spe over:FAT_SPECIES {
			if average_FAT_TLU[spe] > 0 {
				int nbHerd <- length(myLivestock where (each.management = FAT and each.mySpecies = spe));
				
				if nbHerd = 0 {
					float nbTLU <- average_FAT_TLU[spe] * (year_duration_days / length_FATTENINGPERIOD_days / FAT_NB_CYCLES[spe]) ;

					if nbTLU > 0 {
						
						list<livestock_herd> ags;
						
						ask world {
							switch spe {
								match "bovine" {
									create bovine number: 1 {ags << self;}
								}
								match "smallRuminant" {
									create smallRuminant number: 1 {ags << self;}
								}
							}
						}			
								
						ask ags {
							myOwner <- myself;
							myLocation <- myOwner.home;
							management <- FAT;
							value_TLU <- nbTLU;
					
							displayLocation <- any_location_in(myLocation);
								
							stepPurchase <- cycle;
							fatteningDuration_day <- FAT_DURATION[mySpecies];
							
							int column;
							list<string> theList <- (matinitLivestockForageNeeds) row_at 0;

							loop i over: theList {
								if i = mySpecies {
									column <- theList index_of (i);
									// fattened livestock always 2nd column
									column <- column +1;
									break;
								}
							}
							
							loop i from: 1 to: matinitLivestockForageNeeds.rows - 1 {
								if (matinitLivestockForageNeeds[0,i]) = myOwner.myType and (matinitLivestockForageNeeds[1,i]) = "normal" {
									list<string> vals <- string(matinitLivestockForageNeeds[column,i]) split_with "|";
									lowForageNeed_TLUpday <- float(vals[0]);
									highForageNeed_TLUpday <- float(vals[1]);
								}
							}
									
							loop i from: 1 to: matinitLivestockConcentratedFeedNeeds.rows - 1 {
								if (matinitLivestockConcentratedFeedNeeds[0,i]) = management {
									concentratedFeedNeed_TLUpday <- float(matinitLivestockConcentratedFeedNeeds[column,i]);
								}		
							}
							do updateForageFeedNeed;
						}
						myLivestock <- myLivestock + ags;
								
						//* flow
						list<string> theListOrigin <- [EXT, EXTERIOR_LU];
						list<string> theListDestination <- [LIVESTOCK, home.myLandUnit];
						ask world {
							loop l over: ags {
								do updateFlowMaps_kgN(nil, myself, LIVESTOCK, l.herd_value_kgN(), theListOrigin, theListDestination);
							}
						}
					}
				}	
			}
		}
	}

	action pruneTrees  (list<livestock_herd> herds, float needs_kgDM) {
		if pruneTreesPeriod {
			list<string> listOrigins;
			list<string> listDestinations;
			list<string> listDestinationsWood;
			
			string biomassType;
			float Ncontent;
			int forageIndex <- 0;
			float totalNeeds <- needs_kgDM;
						
			int n <- 0;
			loop while: n <= numberOfPossibleTreeTargetpDay and needs_kgDM > 0 {
				pair<list<string>, float> origin;
				float gathered_kgDM <- 0.0;
				float available_kgDM <- 0.0;
				plot target;
	
				int ind <- 0;
				list<plot> pPlots;
				list<plot> NPplots;
				list<plot> tempPlots;
				plot tempPlot;
				bool pruned;
					
				// select plot
				loop while: (ind < treePruningIntensities and empty(pPlots + NPplots)) {
					pPlots <-  myAgriculturalPlots where (each.prunedTrees[ind] != nil);
					if pPlots != nil {
						pPlots <- pPlots where (each.prunedTrees[ind].value > 0);
					}
					
					loop times:10 {
						if flip(0.5) {
							tempPlot <- shuffle(housingPlot + agriculturalPlot where (each.myLandUnit = RANGELAND)) first_with(each.notPrunedTrees[ind].value > 0);
								
							if flip(0.5) and tempPlot != nil {
								NPplots <- NPplots + tempPlot;
							}
						} else {
							tempPlot <-  shuffle(housingPlot + agriculturalPlot where (each.myLandUnit = RANGELAND)) first_with(each.prunedTrees[ind] != nil);
							if tempPlot != nil {
								if tempPlot.prunedTrees[ind].value <= 0 {
									tempPlot <- nil;
								} else {
									if flip(0.5) {
										pPlots <- pPlots + tempPlot;
									}
								}
							}
						}
					}
	
					if empty(pPlots + NPplots) or length(pPlots) < 5 { 
						NPplots <- NPplots + myAgriculturalPlots where (each.notPrunedTrees[ind].value > 0);
							
						list<plot> tempList;
							
						loop times:10 {
							tempPlot <- shuffle(housingPlot + agriculturalPlot) first_with(each.notPrunedTrees[ind].value > 0);
							if tempPlot = nil {
								break;
							} else {
								NPplots <- NPplots + tempPlot;
							}
						}
						if empty(pPlots + NPplots) {
							ind <- ind + 1;		
						}
					}			
				}
					
				// prune 
				if !empty(pPlots + NPplots) {
					if !empty(pPlots) {
						target <- pPlots with_max_of(each.prunedTrees[ind].value);
						available_kgDM <- target.prunedTrees[ind].value;
						pruned <- true;
					} else {
						target <- NPplots with_max_of(each.notPrunedTrees[ind].value);
						available_kgDM <- target.notPrunedTrees[ind].value;				
						pruned <- false;
					}
					gathered_kgDM <- min([needs_kgDM, available_kgDM]);
							
					if gathered_kgDM > 0 {
						household theH;
						
						ask target {
							if pruned {
								do decrementPrunedTrees(ind, gathered_kgDM);
							} else {
								do decrementNotPrunedTrees(ind, gathered_kgDM);
							}	
						}
						
						biomassType <- LEAVES;
						Ncontent <- BIOMASS_kgNperkgDM[biomassType];
						needs_kgDM <- needs_kgDM - gathered_kgDM;
						float gathered_kgN <- gathered_kgDM * Ncontent;
						
						// feed
						loop hd over:herds {
							float ratio <- hd.herdForageNeeds_dDay[0]/totalNeeds;
							float quantity_kgDM <- gathered_kgDM * ratio;
							ask hd {
								do eatForageAndProduceRefusals(biomassType, quantity_kgDM, Ncontent, forageIndex);
							}
						}
																
						// collect wood 
						biomassType <- WOOD;
						float woodQuantity_kgDM <- ratioWoodPruned_overLeaves_kgDM_ptree * gathered_kgDM;
						float woodNcontent <- BIOMASS_kgNperkgDM[biomassType];
						float woodQuantity_kgN <- woodQuantity_kgDM * woodNcontent;
						listDestinationsWood <- stockStorage(biomassType, woodQuantity_kgDM, woodNcontent);		
																					
						// flow (leaves & wood)
						listOrigins <- [PLOT, target.myLandUnit];
						listDestinations <- [LIVESTOCK, target.myLandUnit];
						ask world {							
							if target in agriculturalPlot {
								agriculturalPlot theT <- agriculturalPlot(target);
								theH <- theT.myOwner;
								if theH != myself {
									listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
									listDestinationsWood <- switchOtherOriginDestination(listDestinationsWood[0], listDestinationsWood[1]);
								}
							} else {
								theH <- myself;
							}
							do updateFlowMaps_kgN(theH, myself, LEAVES, gathered_kgN, listOrigins, listDestinations);
							do updateFlowMaps_kgN(theH, myself, WOOD, woodQuantity_kgN, listOrigins, listDestinationsWood);
						}
					}
				}
				n <- n + 1;
			}
		}	
	}
	
	// 2- PLOT MANAGEMENT *******************************************************************************	
	//* yearly activities	
	action adjustCroppingPlan {
		string luse <- MILLET;
		float areaCereals_ha <- sum(myAgriculturalPlots where (each.landUse = luse) accumulate (each.area_ha));
		
		float areaTargeted_ha <- int(my_farming_area() * cereal_areaTargeted_ratioTFA[myType]/0.25) * 0.25;
				
		list<agriculturalPlot> theL;
		// if too much cereals => other land use from the cropping plan
		if (areaCereals_ha > areaTargeted_ha) {
			theL <- myAgriculturalPlots where (each.myLandUnit = BUSHFIELD and each.landUse = luse);
			loop while: (areaCereals_ha > areaTargeted_ha) and !empty(theL) {
				ask one_of(theL) {
					string newLU;
					
					if (GROUNDNUT in croppingPlan and myself.myType in household_favorGROUNDNUT) {
						newLU <- GROUNDNUT;	
					} 
					if newLU = nil {
						newLU <- one_of(croppingPlan where (each != luse));
					}
					
					if newLU != nil {
						do changeLandUse(newLU);
						areaCereals_ha <- areaCereals_ha - area_ha;						
					}
					theL >- self;
				}
			}
		}
	
		// if not enouch cereals => add cereals
		if (areaCereals_ha < areaTargeted_ha) {
			theL <- myAgriculturalPlots where (each.myLandUnit = BUSHFIELD and each.landUse != luse and luse in each.croppingPlan);
					
			loop while: (areaCereals_ha < areaTargeted_ha) and !empty(theL) {
				ask one_of(theL) {
					do changeLandUse(MILLET);
					areaCereals_ha <- areaCereals_ha + area_ha;
					theL >- self;
				}
			}		
		}
	}
	
	
	action updateTargetedFertilizationQuantity {
		ask myAgriculturalPlots {
			organicFertilizationTargeted_kgDM <- (TARGETED_MO_kgDMHa[myLandUnit] * area_ha);
		}
	}
	
	action setFertilizationPriorities {
		list<agriculturalPlot> lHF <- myAgriculturalPlots where (each.myLandUnit = HOMEFIELD);
		agriculturalPlot theP;
		list<agriculturalPlot> theL;
		list<agriculturalPlot> targetsMILLET <- [];
					
		int priority <- 1;
		int nbFields <- length(myAgriculturalPlots);
		
		loop times: length(lHF) {
			targetsMILLET <- lHF where (each.landUse = MILLET);
			theL <- targetsMILLET where (empty(each.organicFertilizationStatus));
			
			if empty(theL) {
				// less recently fertilized
				int minmax <- targetsMILLET min_of(max(each.organicFertilizationStatus.keys));
				theL <- targetsMILLET where((max(each.organicFertilizationStatus.keys) = minmax));
								
				// among the less recently fertilized, the smallest value
				float minlast <- theL min_of(each.organicFertilizationStatus[minmax]);
												
				theL <- theL where(each.organicFertilizationStatus[minmax] = minlast);
			}
						
			if length(theL) = 0 {
				break;
			} else {
				if length(theL) > 1 {
					float minFert <- theL where (MILLET in each.yieldHaPerCrop_kgDM.keys) min_of(each.yieldHaPerCrop_kgDM[MILLET]);
					list<agriculturalPlot> theLtemp <- theL where (MILLET in each.yieldHaPerCrop_kgDM.keys and each.yieldHaPerCrop_kgDM[MILLET] = minFert);
					if !empty(theLtemp) {
						theL <- theLtemp;
					}
				}
							
				theP <- first(shuffle(theL));
				theP.fertilizationPriority <- priority;
				lHF >- theP;
				
				priority <- priority + 1;
			}
		}
		
		if !empty(lHF) {
			ask lHF {
				fertilizationPriority <- nbFields;
			}
		}
		
		list<agriculturalPlot> lBF <- myAgriculturalPlots where (each.myLandUnit = BUSHFIELD);
				
		loop times: length(lBF) {
			targetsMILLET <- lBF where (each.landUse = MILLET);
			if !empty(targetsMILLET) {
				theL <- targetsMILLET where (each.future_landUse = GROUNDNUT);
				if empty(theL) = true {
					theL <- targetsMILLET;
				} 
			} else {
				theL <- lBF;
			}
			
			theL <- theL where (empty(each.organicFertilizationStatus));
			
			if empty(theL) {		
				// less recently fertilized
				int minmax <- theL min_of(max(each.organicFertilizationStatus.keys));
				theL <- theL where((max(each.organicFertilizationStatus.keys) = minmax));
					
				// among the less recently fertilized, the smallest value
				float minlast <- theL min_of((each.organicFertilizationStatus[minmax]));
				theL <- theL where(each.organicFertilizationStatus[minmax] = minlast);
			}
	
			if length(theL) = 0 {
				break;
			} else {
				if length(theL) > 1 {
					float minFert <- theL where (MILLET in each.yieldHaPerCrop_kgDM.keys) min_of(each.yieldHaPerCrop_kgDM[MILLET]);
					list<agriculturalPlot> theLtemp <- theL where (MILLET in each.yieldHaPerCrop_kgDM.keys and each.yieldHaPerCrop_kgDM[MILLET] = minFert);
					if !empty(theLtemp) {
						theL <- theLtemp;
					}		
				}
				
				theP <- first(shuffle(theL));
				theP.fertilizationPriority <- priority;
				lBF >- theP;
				
				priority <- priority + 1;
			}
		}
	
		if !empty(lBF) {
			ask lBF {
				fertilizationPriority  <- nbFields;
			}
		}
	}
	
	//* frequent activities
	action sowCrop (string LU)  {
		list<string> listDestinations;
		list<string> listOrigins;
		
		loop i over:myAgriculturalPlots where (each.landUse = LU and each.status.value = FREE){		
			string seed_name <- CROP_SEEDS[LU];
			float seedNeed_kgDM <- i.area_ha * SEED_DENSITY_KGDMHA[i.landUse];
			
			pair<list<string>,list<float>> origin <- destockStorage(seed_name, seedNeed_kgDM);
			listOrigins <- origin.key;
			listDestinations <- [PLOT, i.myLandUnit];
			
			float seedQuantity_kgDM <- origin.value[0];
			float Ncontent <- origin.value[1];
			float quantity_kgN <- seedQuantity_kgDM * Ncontent;
			
			ask i {
				plantStocks_kgDM <- ([]);
				do updateStatus(SOWN);
				if isManureTarget {
					isManureTarget <- false;
					i.myOwner.manureTarget <- nil;
				}
				isGrazable <- false;
			
				do computeYield;
				do incrementInput_apparent(quantity_kgN);
			}
			
			ask world {
				do updateFlowMaps_kgN(myself, myself, seed_name, quantity_kgN, listOrigins, listDestinations);
			}
		}
	}
	
	action harvestCropProducts (agriculturalPlot plotOrigin) {
		string land_use <- plotOrigin.landUse;		
		string product_name <- LANDUSE_PRODUCTS_COPRODUCTS_NAMES[land_use][0];
		float product_kgDM;
		
		string coproduct_name <- LANDUSE_PRODUCTS_COPRODUCTS_NAMES[land_use][1];		
		float coproduct_kgDM;
		
		ask plotOrigin {
			product_kgDM <- plantStocks_kgDM[product_name];
			coproduct_kgDM <- plantStocks_kgDM[coproduct_name];		
			do updateStatus(PRODUCT_HARVESTED);
			
			// save yield in attribute
			yieldHaPerCrop_kgDM[land_use] <- (product_kgDM + coproduct_kgDM)/area_ha; // (product_kgDM*(1-PRODUCE_BYPRODUCTS_GRAIN_RATIO[product_name]) + coproduct_kgDM)/area_ha;		
		}
				
		do harvestPlot(plotOrigin, product_name, product_kgDM);	
	}
	
	action harvestCropCoProducts (agriculturalPlot plotOrigin) {
		string land_use <- plotOrigin.landUse;
		string coproduct_name <- LANDUSE_PRODUCTS_COPRODUCTS_NAMES[land_use][1];		
		float coproduct_kgDM;
		float coproduct_kgN;
		
		ask plotOrigin {
			coproduct_kgDM <- plantStocks_kgDM[coproduct_name]; 
			do updateStatus(FREE);
			isGrazable <- true;
		}

		// residues left in the field?
		if (land_use in canLetResidues) and coproduct_kgDM > 0 {
			float residues_kgDM <- coproduct_kgDM * residuesLeft_ratio[myType];
			if residues_kgDM > 0 {
				coproduct_kgDM <- coproduct_kgDM - residues_kgDM;
				ask plotOrigin {
					float residues_Ncontent <- destockPlot(coproduct_name, residues_kgDM);
					float residues_kgN <- residues_kgDM * residues_Ncontent;
					do incrementProductStock(coproduct_name, residues_kgDM);
				}
			}
		}
		
		//* harvest plot	
		do harvestPlot(plotOrigin, coproduct_name, coproduct_kgDM);
		
		if plotOrigin.plantStocks_kgDM[FRESH_GRASS] != nil {
			plotOrigin.plantStocks_kgDM[] >- FRESH_GRASS;
		}
	}
	
	action harvestPlot (agriculturalPlot plotOrigin, string biomass, float quantity_kgDM) {	
		list<string> listOrigins <- [PLOT, plotOrigin.myLandUnit];
		float Ncontent;
						
		if quantity_kgDM > 0 {
			//* destock plot
			ask plotOrigin {			
				Ncontent <- destockPlot(biomass, quantity_kgDM);
			}
						
			household HHO <- plotOrigin.myOwner;
			float quantity_kgN <- quantity_kgDM * Ncontent;
					
			if Ncontent = 0 {
				write "in household, Ncontent = 0 in harvest plot !!!! "; 
			}
			
			//* store products
			list<string> listDestinations <- stockStorage(biomass, quantity_kgDM, Ncontent);
		
			//* flows
			ask world {
				do updateFlowMaps_kgN(myself, myself, biomass, quantity_kgN, listOrigins, listDestinations);
			}
		}
	}
	
	// fertilization
	// fertilize with manure
	action spreadManure {
		string biomassType <- MANURE;
		pair<list<string>, list<float>> origin;
		list<string> listOrigins;
		list<string> listDestinations;
		
		float manureStock <- sum(myStocks where (each.biomass = biomassType) accumulate (each.level_kgDM_Ncontent.key));	
		float manureDestocked_kgDM <- 0.0;
		float cart_limit_kgDM <- cartSize_kgDM[myType];
		
		if manureTarget = nil {
			do chooseManureTarget();
		}
				
		loop while: manureStock > 0 and manureDestocked_kgDM < cart_limit_kgDM and manureTarget != nil {
			float need_kgDM <- manureTarget.organicFertilizationTargeted_kgDM - manureTarget.organicFertilizationInput_kgDM;
			if need_kgDM = 0 {
				do chooseManureTarget();
				if manureTarget = nil {
					break;
				}
				need_kgDM <- manureTarget.organicFertilizationTargeted_kgDM - manureTarget.organicFertilizationInput_kgDM;	
			}
				
			float manure_allocation_kgDM <- min([manureStock, need_kgDM, (cart_limit_kgDM - manureDestocked_kgDM)]);
			float manure_allocation_kgN;
			household HHD <- manureTarget.myOwner;
				
			if manure_allocation_kgDM > 0 {
				origin <- destockStorage(biomassType, manure_allocation_kgDM);
				
				listOrigins <- origin.key;
				manure_allocation_kgDM <- origin.value[0];
				
				manureDestocked_kgDM <- manureDestocked_kgDM + manure_allocation_kgDM;
				manureStock <- manureStock - manure_allocation_kgDM;
				
				
				float Ncontent <- origin.value[1];	
				
				listDestinations <- stockPlot(manureTarget, biomassType, manure_allocation_kgDM, Ncontent);
				manure_allocation_kgN <- manure_allocation_kgDM * Ncontent;
								
				//* flow
				ask world {
					do updateFlowMaps_kgN(myself, HHD, biomassType, manure_allocation_kgN, listOrigins, listDestinations);
				}
			} else {
				break;
			}
		}
	}
	
	// manure & place for night coralling
	action chooseManureTarget {
		agriculturalPlot mt <- manureTarget;

		list<agriculturalPlot> targetsFree <- (myAgriculturalPlots where (each.status.value = FREE)) sort_by(each.fertilizationPriority);
		if !empty(targetsFree) {
			list<agriculturalPlot> targetsFerti <- (targetsFree where (each.organicFertilizationInput_kgDM < each.organicFertilizationTargeted_kgDM)) sort_by(each.fertilizationPriority);// and each.status.value = FREE)) sort_by(each.fertilizationPriority);
		
			if !empty(targetsFerti) {
				// owned by owner and needs fertilization
				// update for the household
				agriculturalPlot target <- first(targetsFerti);
				if manureTarget != nil {
					if target.fertilizationPriority < manureTarget.fertilizationPriority {
						manureTarget <- target;
					}
				} else {
					manureTarget <- target;
				}
			
			} else {
				// owned by owner with no need for fertilization
				// update for the household
				agriculturalPlot target <- first(targetsFree);
				if manureTarget != nil {
					if target.fertilizationPriority < manureTarget.fertilizationPriority {
						manureTarget <- target;
					}
				} else {
					manureTarget <- target;
				}
			}
		
			// update for the agricultural plot
			ask manureTarget {
				isManureTarget <- true;
			}
			if mt != nil and mt != manureTarget {
				ask mt {
					isManureTarget <- false;
				}
			} 
		
		} else {
			manureTarget <- nil; 
		}
	}
	
	action mineralFertilization {
		map<string, float> mmap <- mineralFertilizerAvailable_kgDM[myType];
		string biomassType <- MINERAL;
		agriculturalPlot target;
		
		// find a land use where you can use mineral input
		loop use over: FERTILISABLE_LANDUSES {
			float mineral_kgDM <- mmap[use];
			list<agriculturalPlot> targetList <- myAgriculturalPlots where (each.landUse = use);
			
			loop while: mineral_kgDM > 0 and !empty(targetList) {
				list<agriculturalPlot> tl <- targetList where (use in each.yieldHaPerCrop_kgDM.keys);
				if !empty(tl) {
					target <- tl where (each.organicFertilizationTargeted_kgDM > each.organicFertilizationInput_kgDM) with_min_of(each.yieldHaPerCrop_kgDM[use]);
					if target = nil {
						target <- tl with_min_of(each.yieldHaPerCrop_kgDM[use]);
					}			
				} else {
					target <- one_of(targetList);
				}
						
				float targetQuantity_kgN <- target.area_ha * MINERAL_FERTI_DOSE_kgN_Ha[myType][use] ; 
				float targetedQuantity_kgDM <- targetQuantity_kgN / BIOMASS_kgNperkgDM[biomassType];
				
				//household HHD <- target.myOwner;
				float input_kgDM <- min([mineral_kgDM, targetedQuantity_kgDM]);
				float Ncontent;
				float input_kgN;
				
				// purchase
				pair<list<string>, list<float>> origin;	
				origin <- purchaseMarket(biomassType, input_kgDM);
				input_kgDM <- origin.value[0];
				Ncontent <- origin.value[1];
				input_kgN <- input_kgDM * Ncontent;
				
				// apply
				list<string> listdestination <- stockPlot(target, biomassType, input_kgDM, Ncontent);
				
				//* flow
				list<string> listOrigin <- origin.key;
				ask world {
					do updateFlowMaps_kgN(nil, myself, biomassType, input_kgN, listOrigin, listdestination);	
				}
				
				mineral_kgDM <- mineral_kgDM - input_kgDM;
				targetList >- target;
			}
			
			// second run if mineral left
			if mineral_kgDM > 0 {
				list<agriculturalPlot> targetList <- myAgriculturalPlots where (each.landUse = use);
			
				loop while: mineral_kgDM > 0 and !empty(targetList) {
					list<agriculturalPlot> tl <- targetList where (use in each.yieldHaPerCrop_kgDM.keys);
					if !empty(tl) {
						target <- tl where (each.organicFertilizationTargeted_kgDM > each.organicFertilizationInput_kgDM) with_min_of(each.yieldHaPerCrop_kgDM[use]);
						if target = nil {
							target <- tl with_min_of(each.yieldHaPerCrop_kgDM[use]);
						}			
					} else {
						target <- one_of(targetList);
					}
							
					float targetQuantity_kgN <- target.area_ha * MINERAL_FERTI_DOSE_kgN_Ha[myType][use] ; 
					float targetedQuantity_kgDM <- targetQuantity_kgN / BIOMASS_kgNperkgDM[biomassType];
					
					float input_kgDM <- min([mineral_kgDM, targetedQuantity_kgDM]);
					float Ncontent;
					float input_kgN;
					
					// purchase
					pair<list<string>, list<float>> origin;	
					origin <- purchaseMarket(biomassType, input_kgDM);
					input_kgDM <- origin.value[0];
					Ncontent <- origin.value[1];
					input_kgN <- input_kgDM * Ncontent;
					
					// apply
					list<string> listdestination <- stockPlot(target, biomassType, input_kgDM, Ncontent);
					
					//* flow
					list<string> listOrigin <- origin.key;
					ask world {
						do updateFlowMaps_kgN(nil, myself, biomassType, input_kgN, listOrigin, listdestination);	
					}
					
					mineral_kgDM <- mineral_kgDM - input_kgDM;
					targetList >- target;
				}
			}
		}
	}
	
	// 3- home consumption *************************************************************
	action homeConsumption (bool gatherDung, int frequency) {
		string activity <- HUMAN;
		plot ploti <- home;
		
		do useCombustibles(gatherDung, frequency, activity, ploti);
		do eat(frequency, activity, ploti);
		do produceAndCollectWaste(frequency, activity, ploti);
	}

	action useCombustibles (bool gatherDung, int frequency, string actDestination, plot plotDestination) {
		pair<list<string>, list<float>> origin;
		float fuelNeed_kgDM;

		// gather dung
		if firewoodNeed_kgDM > 0 and gatherDung {
			float dungNeed_kgDM <- firewoodNeed_kgDM * dungOverWood;
			
			pair<float, float> gathered <- gatherDungAsCombustible(dungNeed_kgDM, actDestination, plotDestination);
			float dungGathered_kgDM <- gathered.key;
			float firewoodEquivalence_kgDM <- dungGathered_kgDM * dungOverWood;
			firewoodNeed_kgDM <- firewoodNeed_kgDM - firewoodEquivalence_kgDM;
		}
		
		if firewoodNeed_kgDM > 0 {
			// destock fuel
			loop combuType over: HH_STORED_COMBUSTIBLE {
				if combuType = DUNG {
					fuelNeed_kgDM <- firewoodNeed_kgDM * dungOverWood;
				} else {
					fuelNeed_kgDM <- firewoodNeed_kgDM;
				}
				
				origin <- destockStorage(combuType, fuelNeed_kgDM);
				float destocked_kgDM <- origin.value[0];
				float destocked_kgN <- origin.value[1];
							
				list<string> theListOrigin <- origin.key;
				ask world {
					do updateFlowMaps_kgN(myself, myself, combuType, destocked_kgN, theListOrigin, [actDestination, plotDestination.myLandUnit]);
				}
				
				if combuType = DUNG {
					destocked_kgDM <- destocked_kgDM * dungOverWood;
				}
				firewoodNeed_kgDM <- firewoodNeed_kgDM - destocked_kgDM;
			}
		}
		
		float purchased_kgDM;
		float purchased_kgN;
		if firewoodNeed_kgDM > 0 {
			// purchase in the village
			loop combuType over: HH_STORED_COMBUSTIBLE {
				if combuType = DUNG {
					fuelNeed_kgDM <- firewoodNeed_kgDM * dungOverWood;
				} else {
					fuelNeed_kgDM <- firewoodNeed_kgDM ;
				}
	
				map<household, pair<list<string>, list<float>>> theM <- purchaseVillage(combuType, fuelNeed_kgDM);
				
				if !empty(theM) {
					household theH;
					loop h over: theM.keys {
						theH <- h;
						break;	
					}
					
					origin <- theM[theH];				
					purchased_kgDM <- origin.value[0];
					purchased_kgN <- origin.value[1];
					
					if combuType = DUNG {
						purchased_kgDM <- purchased_kgDM * dungOverWood;
					}
					firewoodNeed_kgDM <- firewoodNeed_kgDM - purchased_kgDM;
					
					list<string> listOrigins <- origin.key;
					list<string> listDestinations <- [actDestination, plotDestination.myLandUnit];
					
					ask world {
						if theH != myself and theH != nil {
							listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
						}
						do updateFlowMaps_kgN(theH, myself, combuType, purchased_kgN, listOrigins, listDestinations);
					}
					
					if firewoodNeed_kgDM = 0 {
						break;
					}
				} else {
					break;
				}
			}
		}
		
		if firewoodNeed_kgDM > 0 {
			// purchase wood
			if firewoodNeed_kgDM > 0 {
				origin <- purchaseMarket(WOOD, firewoodNeed_kgDM);
				purchased_kgDM <- origin.value[0];
				purchased_kgN <- origin.value[1];
				firewoodNeed_kgDM <- firewoodNeed_kgDM - purchased_kgDM;
					
				list<string> theListOrigin <- origin.key;
				ask world {
					do updateFlowMaps_kgN(nil, myself, WOOD, purchased_kgN, theListOrigin, [actDestination, plotDestination.myLandUnit]);
				}
			}
		}
	}
	
	action eat (int frequency, string actDestination, plot plotDestination) {
		pair<list<string>, list<float>> origin;
		list<string> listOrigins;
		list<string> listDestinations <- [actDestination, plotDestination.myLandUnit];

		do updateFoodNeeds(frequency);
		float value_kgDM;
		float Ncontent;
		float value_kgN;
		
		loop biomass over:foodNeeds_kgDM.keys {
			float need_kgDM <- foodNeeds_kgDM[biomass];
		
			// destock
			if need_kgDM > 0 {
				if biomass in HH_STORED_FOOD {
					origin <- destockStorage (biomass, need_kgDM);
					value_kgDM <- origin.value[0];
					
					if value_kgDM > 0 {
						listOrigins <- origin.key;
						Ncontent <- origin.value[1];
											
						// flow
						value_kgN <- value_kgDM * Ncontent;
						ask world {
							do updateFlowMaps_kgN(myself, myself, biomass, value_kgN, listOrigins, listDestinations);
						}
						
						do separateProductandByproduct(listDestinations, biomass, value_kgDM);
						need_kgDM <- need_kgDM - value_kgDM;
					}	
					
					// purchase in the village
					if need_kgDM > 0 {
						map<household, pair<list<string>, list<float>>> theM <- purchaseVillage(biomass, need_kgDM);
						
						if !empty(theM) {
							household theH;
							loop h over: theM.keys {
								theH <- h;
								break;	
							}
							origin <- theM[theH];
							
							value_kgDM <- origin.value[0];
							
							if value_kgDM > 0 {
								listOrigins <- origin.key;
								Ncontent <- origin.value[1];

								// product & by-product are separated by the buyer
								do separateProductandByproduct(listDestinations, biomass, value_kgDM);

								// food flow
								value_kgN <- value_kgDM * Ncontent;								
								ask world {
									if theH != myself {
										listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
									}
									do updateFlowMaps_kgN(theH, myself, biomass, value_kgN, listOrigins, listDestinations);
								}
					

								need_kgDM <- need_kgDM - value_kgDM;	
							}
						}
					}
				}
				
				if need_kgDM > 0 and biomass in PURCHASED_MARKET_FOOD {
					origin <- purchaseMarket(biomass, need_kgDM);
					value_kgDM <- origin.value[0];
		
					if value_kgDM > 0 {
						value_kgN <- value_kgDM * origin.value[1];
							
						//* flow
						listOrigins <- origin.key;
						listDestinations <- [actDestination, plotDestination.myLandUnit];
						ask world {
							do updateFlowMaps_kgN(nil, myself, biomass, value_kgN, listOrigins, listDestinations);	
						}
						need_kgDM <- need_kgDM - value_kgDM;
					}
				}
				
				if foodIngestions_kgDM[biomass] != nil {
					float v <- foodIngestions_kgDM[biomass] + foodNeeds_kgDM[biomass] - need_kgDM;
					foodIngestions_kgDM[biomass] <- v;
				} else {
					add biomass::(foodNeeds_kgDM[biomass] - need_kgDM)	to:foodIngestions_kgDM;
				}				
			}
		
		}
	}
	
	action separateProductandByproduct (list<string> listOrigins, string biomass, float value_kgDM) {
		string product <- PRODUCT_NAME[biomass];
		string byproduct <- BYPRODUCT_NAME[biomass];
		
		// product quantity
		float product_kgDM <- value_kgDM * GRAIN_kgDM_TOTAL_kgDM[biomass];
		float productNcontent <- BIOMASS_kgNperkgDM[product];
		// by-product quantity
		float byproduct_kgDM <- value_kgDM - product_kgDM;
		float byproductNcontent <- BIOMASS_kgNperkgDM[byproduct];	
							
		// throw byproduct
		do throwWaste(listOrigins, byproduct, byproduct_kgDM, byproductNcontent);
		pair<string, list<float>> theP <- product::[product_kgDM, productNcontent];
		return theP;
	}	
	
	action throwWaste (list<string> listOrigins, string biomassType, float waste_kgDM, float Ncontent) {
		agriculturalPlot target <- theDump;
		household theH <- target.myOwner;
		biomassType <- WASTE;
		
		float waste_in_HF_kgDM <- waste_kgDM * ratio_waste_in_home_field;
		float waste_in_HF_kgN <- waste_in_HF_kgDM * Ncontent;
		
		// throw n% in the dump
		list<string> listDestinations <- stockPlot(target, biomassType, waste_in_HF_kgDM, Ncontent);		
		//* flow
		ask world {
			if theH != myself {
				listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
			}
			do updateFlowMaps_kgN(myself, target.myOwner, biomassType, waste_in_HF_kgN, listOrigins, listDestinations);
		}
		
		// throw the rest in the fertilizer stock
		float waste_in_fertilizer_stock_kgDM <-  waste_kgDM - waste_in_HF_kgDM;
		float waste_in_fertilizer_stock_kgN <- waste_in_fertilizer_stock_kgDM * Ncontent;
		
		if waste_in_fertilizer_stock_kgDM > 0 {
			listDestinations <- stockStorage(biomassType, waste_in_fertilizer_stock_kgDM, Ncontent);
			//* flow
			ask world {
				do updateFlowMaps_kgN(myself, myself, biomassType, waste_in_fertilizer_stock_kgN, listOrigins, listDestinations);
			}
		}
		
		if (waste_in_HF_kgDM + waste_in_fertilizer_stock_kgDM) = 0 {
			write "in household, no waste thrown ";
			ask world {
				do pause;
			}
		}
	}
	
	action produceAndCollectWaste (int frequency, string actOrigin, plot plotOrigin) {
		string biomassType <- WASTE;
		list<string> listOrigins <- [actOrigin, plotOrigin.myLandUnit];
		float waste_kgDM;
		float Ncontent;
		
		// food waste
		loop w over: foodIngestions_kgDM.keys {
			float w_kgDM <- foodIngestions_kgDM[w] * FOOD_WASTE_kgDMperkgDM[w];
			if w_kgDM > 0 {
				float w_Ncontent <- BIOMASS_kgNperkgDM[w];
					
				if Ncontent != w_Ncontent {
					Ncontent <- (Ncontent * waste_kgDM + w_kgDM * w_Ncontent) / (waste_kgDM + w_kgDM);
				}
			
				waste_kgDM <- waste_kgDM + w_kgDM;
			}
		}

		if waste_kgDM > 0 {
			do throwWaste(listOrigins, biomassType, waste_kgDM, Ncontent);
		}
		
		// kitchen (ashes) and yard wastes
		waste_kgDM <- yardWaste_kgDM_pInhabitant_pday * inhabitants;
		Ncontent <- BIOMASS_kgNperkgDM[biomassType];
		do throwWaste(listOrigins, biomassType, waste_kgDM, Ncontent);
	}
	
	// 3-
	action gatherDungAsCombustible (float need_kgDM, string actDestination, plot plotDestination) {
		string biomassType <- DUNG;
		float gathered_kgDM;
		float gathered_kgN;
		float totalGathered_kgDM;
		float totalGathered_kgN;
		bool noresource <- false;
		
		pair<list<string>, list<float>> origin;
		
		loop while: need_kgDM > 0 or noresource = false {
			map<agriculturalPlot, pair<list<string>, list<float>>> theM <- gatherOnAgriculturalPlot(biomassType, need_kgDM);
									
			if empty(theM) {
				noresource <- true;
				break;
			}
			
			agriculturalPlot theP;
			// get the plot - the map has only one key
			loop h over: theM.keys {
				theP <- h;
				break;
			}
			origin <- theM[theP];
			gathered_kgDM <- origin.value[0];

			if gathered_kgDM > 0.0 {
				gathered_kgN <- gathered_kgDM * origin.value[1];
				
				totalGathered_kgDM <- totalGathered_kgDM + gathered_kgDM;
				totalGathered_kgN <- totalGathered_kgN + gathered_kgN;
				
				need_kgDM <- need_kgDM - gathered_kgDM;
				
				//* flow
				list<string> listOrigins <- origin.key;
				list<string> listDestinations <- [actDestination, plotDestination.myLandUnit];
				ask world {
					household theH <- theP.myOwner;
					if theH != myself {
						listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
					}
					do updateFlowMaps_kgN(theH, myself, biomassType, gathered_kgN, listOrigins, listDestinations);	
				}
			} else {
				noresource <- true;
			}
			return totalGathered_kgDM::totalGathered_kgN;
		}
	}
	
	action gatherWoodForStorage_week {
		string biomassType <- WOOD;
		float stock_kgDM <- first(myStocks where (each.biomass = biomassType)).level_kgDM_Ncontent.key;
		float need_kgDM <- woodNeed_kgDM_year * (1 + extraShareForStock) - stock_kgDM;
		
		if need_kgDM > 0 {
			float targetedQuantity_kgDM <- min([need_kgDM, woodGathered_kgDM_pweek]);
			float gathered_kgDM;
			
			loop while: targetedQuantity_kgDM > 0 {
				plot target <- shuffle (housingPlot + (agriculturalPlot where (each.myLandUnit = HOMEFIELD))) first_with(each.deadWoodStock_kgDM > 0);
				if target = nil {
					target <- shuffle (agriculturalPlot) first_with(each.deadWoodStock_kgDM > 0 and each.myLandUnit = BUSHFIELD);
					if target = nil {
						target <- shuffle (agriculturalPlot) first_with(each.deadWoodStock_kgDM > 0 and each.myLandUnit = RANGELAND);
					}
				}
				
				if target = nil {
					break;
				} else {
					float available_kgDM <- target.deadWoodStock_kgDM;
					list<string> listOrigins <- [PLOT, target.myLandUnit];
					list<string> listDestinations;
					gathered_kgDM <- min([available_kgDM, targetedQuantity_kgDM]);
					
					if gathered_kgDM > 0 {
						targetedQuantity_kgDM <- targetedQuantity_kgDM - gathered_kgDM;
						
						//* destock wood
						float woodNcontent;
						ask target {
							woodNcontent <- destockPlot(biomassType, gathered_kgDM);
						}
						float wood_gathered_kgN <- gathered_kgDM * woodNcontent;
						
						//* gather dung on the way
						if target in agriculturalPlot {
							float dunggathered_kgDM;
							float dunggathered_kgN;
									
							if firewoodNeed_kgDM > 0 {
								biomassType <- DUNG;
								float dungNeed_kgDM <- firewoodNeed_kgDM * dungOverWood;
								agriculturalPlot dungTarget <- agriculturalPlot where (sum(each.dung_kgDM_Ncontent.keys) >= dungNeed_kgDM) closest_to(target);
								
								if dungTarget = nil {
									dungTarget <- agriculturalPlot where (sum(each.dung_kgDM_Ncontent.keys) > 0) closest_to(target);
								}
				
								if dungTarget != nil {
									float dunggathered_Ncontent;
									
									list<float> theL <- dungTarget.dung_kgDM_Ncontent accumulate float(each.key);
									float dung_available_kgDM <- sum(theL);
								
									dunggathered_kgDM <- min([dungNeed_kgDM, dung_available_kgDM]);
									
									ask dungTarget {
										dunggathered_Ncontent <- destockPlot(biomassType, dunggathered_kgDM);
									}
									dunggathered_kgN <- dunggathered_kgDM * dunggathered_Ncontent;
									firewoodNeed_kgDM <- firewoodNeed_kgDM - dunggathered_kgDM/dungOverWood;
								}				
								
								if dunggathered_kgDM > 0 {
									list<string> listDungOrigins <- [PLOT, dungTarget.myLandUnit];
									list<string> listDungDestinations <- [HUMAN, home.myLandUnit];
																	
									ask world {
										household theH <- dungTarget.myOwner;
		
										if theH != myself {
											listDungDestinations <- switchOtherOriginDestination(listDungDestinations[0], listDungDestinations[1]);
										}
										do updateFlowMaps_kgN(theH, myself, biomassType, dunggathered_kgN, listDungOrigins, listDungDestinations);
									}
								}
							}
						}
						
						biomassType <- WOOD;
						//* store wood
						listDestinations <- stockStorage(biomassType, gathered_kgDM, woodNcontent);
						
						//* flow
						ask world {
							household theH <- myself;
							if target in agriculturalPlot {
								agriculturalPlot theP <- agriculturalPlot(target);
								theH <- theP.myOwner;
								if theH != myself or theH = nil {
									listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
								}
							}
							do updateFlowMaps_kgN(theH, myself, biomassType, wood_gathered_kgN, listOrigins, listDestinations);
						}
					} else {
						break;
					}
				}
			}
		}
	}
	
	// 4- manage stocks ********************************************************
		// sales
	action sellGroundnut {
		string biomassType <- GROUNDNUT_UNHUSKED;
		stock groundnutGrainStock <- first(myStocks where (each.biomass = biomassType));
		float sales;
		 
		ask groundnutGrainStock {
			sales <- updateGroundnutSurplus();
		}
		do sellSurplusToMarket(biomassType, sales);
	}
		
	
//***********************************************************************************************************************************	
		//* stock
	action stockStorage (string biomassType, float quantity_kgDM, float Ncontent) {
		list<string> listDestination <- [];
				
		string actDestination <- GRANARY;
		
		if biomassType in MANURE_COMPONENT {
			biomassType <- MANURE;
		}
				
		plot plotDestination;
				
		//* stock biomass
		stock theStock <- first(myStocks where (each.biomass = biomassType));

		if theStock != nil and quantity_kgDM > 0 {		
			plotDestination <- theStock.myLocation;
			listDestination <- [actDestination, plotDestination.myLandUnit];
			
			if biomassType in HH_STORED_FERTILIZER {
				actDestination <- FERTILIZERS;
				listDestination <- [actDestination, plotDestination.myLandUnit];
				
					//* losses (when moved to storage)
				float Nquantity_kgN <- quantity_kgDM * Ncontent;
				float Nquantity_afterLosses_kgN <- Nlosses_toStorage(biomassType, Nquantity_kgN, listDestination);
					
					//* losses (storage losses)
				Nquantity_afterLosses_kgN <- Nlosses_heap(biomassType, Nquantity_afterLosses_kgN, listDestination);
				Ncontent <- Nquantity_afterLosses_kgN/quantity_kgDM;
			}
						
			ask theStock {
				do incrementLevel(quantity_kgDM, Ncontent);
			}
			
		} else {
			write "in household, STOCK STORAGE: " + biomassType + " stock nil: " + theStock + " or quantity = " + quantity_kgDM;
			ask world {
				do pause;
			}
		}
		return listDestination;
	}
	
	float Nlosses_toStorage (string biomassType, float Nquantity_kgN, list<string> listOrigins) {
		list<string> listDestinations <- [RESPIRATION, RESPIRATION];
		
		pair<list<string>, float> destination;
		float losses_kgN <- Nquantity_kgN * N_LOSSES_ToStoragekgNpkgN[biomassType];
		if losses_kgN = nil {
			losses_kgN <- 0.0;
		} 
		
		if losses_kgN > 0 {
			//* flow
			ask world {
				do updateFlowMaps_kgN(myself, nil, N_LOST, losses_kgN, listOrigins, listDestinations);
			}	
		}
			
		Nquantity_kgN <- Nquantity_kgN - losses_kgN;

		return Nquantity_kgN;	
	}	

	
	action stockPlot (agriculturalPlot target, string biomassType, float quantity_kgDM, float Ncontent) {
		list<string> listDestinations <- [PLOT, target.myLandUnit];
				
		if quantity_kgDM > 0 and target != nil {
			if biomassType = REFUSAL {
				biomassType <- RESIDUE;
			}
			
			//* losses
			float quantity_kgN <- quantity_kgDM * Ncontent;
			float NQuantityAfterLosses <- Nlosses_application(target, biomassType, quantity_kgN, listDestinations);
			Ncontent <- NQuantityAfterLosses/quantity_kgDM;

			//* fertilization
			ask target {
				if biomassType in FERTILIZER_TYPES {
					do isFertilized(biomassType, quantity_kgDM, Ncontent);
				} else {
					write "in Household, stock plot error biomass: " + biomassType;
					ask world {
						do pause;
					}
				}
			}
		} else {
			write "in Household, no stock plot: " + biomassType + " - target " + target + " - " + quantity_kgDM;
			ask world {
				do pause;
			}
		}
		return listDestinations;
	}
	
	float Nlosses_application (agriculturalPlot target, string biomassType, float Nquantity_kgN, list<string> listOrigins) {
		list<string> listDestinations <- [RESPIRATION, RESPIRATION];
		
		pair<list<string>, float> destination;
		float losses_kgN <- Nquantity_kgN * N_LOSSES_APPLICATIONkgNpkgN[biomassType];
		if losses_kgN = nil {
			losses_kgN <- 0.0;
		} 
		
		if losses_kgN > 0 {
			ask target {
				do incrementOutput_nonapparent(losses_kgN);
			}
			//* flow
			ask world {
				do updateFlowMaps_kgN(myself, nil, N_LOST, losses_kgN, listOrigins, listDestinations);
			}	
		}
			
		Nquantity_kgN <- Nquantity_kgN - losses_kgN;

		return Nquantity_kgN;	
	}
	
	action stockSeeds {
		list<string> listOrigins;
		list<string> listDestinations;
		
		loop lu over: IS_CROP {
			string seedi <- CROP_SEEDS[lu];
			string seedOrigin <- CROP_SEEDS_ORIGINS[lu];
					
			float seed_need_kgDM <- sum(myAgriculturalPlots where (each.landUse = lu) accumulate each.area_ha) * SEED_DENSITY_KGDMHA[lu];
			float seed_stock_kgDM <- sum(myStocks where (each.biomass = seedi) accumulate each.level_kgDM_Ncontent.key);
			seed_need_kgDM <- seed_need_kgDM - seed_stock_kgDM;
			
			float origin_stock_kgDM <- sum(myStocks where (each.biomass = seedOrigin) accumulate each.level_kgDM_Ncontent.key);
							
			if seed_need_kgDM > 0 and origin_stock_kgDM > 0 {
				float origin_need_kgDM <- seed_need_kgDM * GRAIN_kgDM_TOTAL_kgDM[seedOrigin];
				float stock_available_kgDM <- min([origin_stock_kgDM, origin_need_kgDM]);
								
				pair<list<string>, list<float>> origins <- destockStorage(seedOrigin, stock_available_kgDM);
				listOrigins <- origins.key;
				float destocked_kgDM <- origins.value[0];
				
				// throw by product & stock seeds
				pair<string, list<float>> theP <- separateProductandByproduct(listOrigins, seedOrigin, destocked_kgDM);
				
				float seed_kgDM <- theP.value[0];
				float seedNcontent <- theP.value[1];
				listDestinations <- stockStorage(seedi, seed_kgDM, seedNcontent);
			}
		}
	}
		
	// purchases 
	//* purchases Market
	action purchaseMarket (string biomassType, float purchases_kgDM) {
		pair<list<string>, list<float>> origin;
		
		// flows
		list<string> listOrigin <- [EXT, EXTERIOR_LU];
		float purchases_Ncontent <- BIOMASS_kgNperkgDM[biomassType];
		origin <- listOrigin::[purchases_kgDM, purchases_Ncontent];
		return origin;
	}

	//* purchases Village
	action purchaseVillage (string biomassType, float quantity_kgDM) {
		pair<list<string>, list<float>> origin;	
		
		list<stock> ls <- stock where (each.biomass = biomassType);
		float available_kgDM <- ls max_of(each.surplus_kgDM_Ncontent.key);
//		float available_kgDM <- household max_of(sum(each.myStocks where (each.biomass = biomassType) accumulate each.surplus_kgDM_Ncontent.key)); 
		
		if available_kgDM > 0 {
			household theHousehold <- (shuffle(ls) with_max_of(each.surplus_kgDM_Ncontent.key)).myOwner;
				
			ask theHousehold {
				origin <- sellVillage (biomassType, quantity_kgDM);
			}

			return ([theHousehold::origin]);			
		} else {
			return nil;
		}
	}
	
	//* destock	
	action destockStorage (string biomassType, float quantity_kgDM) {
		stock theStock <- first(myStocks where (each.biomass = biomassType));
		pair<list<string>,list<float>> origin;
				
		float destocked_kgDM;
		float Ncontent <- 0.0;
		
		string actOrigin <- GRANARY;
		if biomassType in HH_STORED_FERTILIZER {
			actOrigin <- FERTILIZERS;	
		}
		plot plotOrigin;
		
		if theStock != nil {
			float stockLevel_kgDM <- theStock.level_kgDM_Ncontent.key;
			
			if stockLevel_kgDM > 0 {
				destocked_kgDM <- min([stockLevel_kgDM, quantity_kgDM]);
				ask theStock {
					Ncontent <- decrementLevel_kgDM(destocked_kgDM);
				}	
			}
			
			float need_kgDM <- quantity_kgDM - destocked_kgDM;

			// if need > 0 , use surplus			
			if need_kgDM > 0 {
				float surplusLevel_kgDM <- theStock.surplus_kgDM_Ncontent.key;	
				float destocked_kgDM_surplus;
				float NcontentSurplus; 
				if surplusLevel_kgDM > 0 {
					destocked_kgDM_surplus <- min([surplusLevel_kgDM, need_kgDM]);
					
					ask theStock {
						NcontentSurplus  <- decrementSurplus_kgDM(need_kgDM);
					}	
				}
				
				if destocked_kgDM > 0 and Ncontent != NcontentSurplus {
					Ncontent <- (destocked_kgDM * Ncontent + need_kgDM * NcontentSurplus)/ (destocked_kgDM + need_kgDM);
				}
				destocked_kgDM <- destocked_kgDM + destocked_kgDM_surplus;
			}
	
			plotOrigin <- theStock.myLocation;
			
			list<string> listOrigin <- [actOrigin, plotOrigin.myLandUnit];
			origin <- listOrigin::[destocked_kgDM, Ncontent];
		} else {
			write "in Household, Destock storage = STOCK NIL: " + biomassType;
			ask world {
				do pause;
			}
		}
		return origin;
	}
	
	float Nlosses_heap (string biomassType, float Nquantity_kgN, list<string> listOrigins) {
		list<string> listDestinations <- [RESPIRATION, RESPIRATION];
				
		pair<list<string>, float> destination;
		float losses_kgN <- Nquantity_kgN * N_LOSSES_HEAPkgNpkgN[biomassType];
		if losses_kgN = nil {
			losses_kgN <- 0.0;
		} 
		
		if losses_kgN > 0 {
			//* flow
			ask world {
				do updateFlowMaps_kgN(myself, nil, N_LOST, losses_kgN, listOrigins, listDestinations);
			}	
		}
		Nquantity_kgN <- Nquantity_kgN - losses_kgN;

		return Nquantity_kgN;	
	}
	
	action destockStoredSurplus (string biomassType, float quantity_kgDM) {
		stock theStock <- first(myStocks where (each.biomass = biomassType));
		pair<list<string>,list<float>> origin;
		
		float destockedQty_kgDM <- 0.0;
		float Ncontent <- 0.0;
		
		string actOrigin <- GRANARY;
		if biomassType in HH_STORED_FERTILIZER {
			actOrigin <- FERTILIZERS;	
		}
		plot plotOrigin;
		float surplus_kgDM;
		
		if theStock != nil {
			plotOrigin <- theStock.myLocation;
						
			surplus_kgDM <-  min([quantity_kgDM, theStock.surplus_kgDM_Ncontent.key]);
			
			if surplus_kgDM > 0 {
				destockedQty_kgDM <- surplus_kgDM;
				ask theStock {
					Ncontent <- decrementSurplus_kgDM(surplus_kgDM);
				}	
			}
		}
		origin <- [actOrigin, plotOrigin.myLandUnit]::[destockedQty_kgDM, Ncontent];
		return origin;
	}
	
	//* gathering
	action gatherOnAgriculturalPlot (string biomassType, float need_kgDM) {
		map<agriculturalPlot, pair<list<string>, list<float>>> theM;
		pair<list<string>, list<float>> origin;
		list<string> listOrigin;
		float gathered_kgDM <- 0.0;
		float gathered_Ncontent <- 0.0;
		pair<agriculturalPlot, float> targetAvailable;
		float available_kgDM <- 0.0;
		agriculturalPlot target;

		targetAvailable <- gatherChooseTarget(biomassType);
		
		target <- targetAvailable.key;
		available_kgDM <- targetAvailable.value;
			
		
		if target != nil and  available_kgDM > 0 {
			gathered_kgDM <- min([need_kgDM, available_kgDM]);
			
			if gathered_kgDM > 0 {
				ask target {
					gathered_Ncontent <- destockPlot(biomassType, gathered_kgDM);
				}		
			
				// flow	
				listOrigin <- [PLOT, target.myLandUnit];
			}
			origin <- listOrigin::[gathered_kgDM, gathered_Ncontent];
			
			theM <- ([target::origin]);
		} else {
			theM <- map([]);
		}
		return theM;
	}
		
	action gatherChooseTarget (string biomassType) {
		agriculturalPlot target;
		float available <- 0.0;
		
		if biomassType = FRESH_GRASS {
			// first in my plots in home fields
			list<agriculturalPlot> theL <- myAgriculturalPlots where (each.myLandUnit = HOMEFIELD and each.plantStocks_kgDM[biomassType] != nil);
			
			if !empty(theL) {
				target <- theL with_max_of(each.plantStocks_kgDM[biomassType]);
			
				if target != nil {
					available <- target.plantStocks_kgDM[biomassType];
				}
			}

			// then in my plots in bush fields
			if available = 0  or target = nil {
				
				theL <- myAgriculturalPlots where (each.myLandUnit = BUSHFIELD and each.plantStocks_kgDM[biomassType] != nil);
				if !empty(theL) {
					target <- theL with_max_of(each.plantStocks_kgDM[biomassType]);
			
					if target != nil {
						available <- target.plantStocks_kgDM[biomassType];
					}
				}
			}
			
			// then in any plots
			if available = 0 or target = nil {
				theL <- agriculturalPlot where (each.plantStocks_kgDM[biomassType] != nil);
				if !empty(theL) {
					target <- theL with_max_of(each.plantStocks_kgDM[biomassType]);

					if target != nil {
						available <- target.plantStocks_kgDM[biomassType];
					}
				}
			}
		}
			
		if biomassType = DUNG {
			target <- shuffle (agriculturalPlot) first_with(sum(each.dung_kgDM_Ncontent.keys) > minimum_dung_harvestable_kgDM);
			
			if target != nil { 			
				ask target {
					list<float> theL <- dung_kgDM_Ncontent accumulate float(each.key);
					available <- sum(theL);
				} 
			}
		}
		
		
		if target = nil or available = 0 {
			return nil;
		} else {
			return target::available;
		}
	}
				
	//* sales Market
	action sellSurplusToMarket (string biomassType, float sales_kgDM) {
		//* destockage
		pair<list<string>, list<float>> origin <- destockStoredSurplus(biomassType, sales_kgDM);

		//* flow
		list<string> theListOrigin <- origin.key;
		float value_kgDM <- origin.value[0];
		float value_kgN <- value_kgDM * origin.value[1];
		list<string> theListDestination <- [EXT, EXTERIOR_LU];
		ask world {
			do updateFlowMaps_kgN(myself, nil, biomassType, value_kgN, theListOrigin, theListDestination);
		}	
	}
		
	
	//* sell Village
	action sellVillage (string biomassType, float quantity_kgDM) {
		//* destockage
		pair<list<string>, list<float>> origin <- destockStoredSurplus (biomassType, quantity_kgDM);
		
		return origin;
	}
	
	// ASPECT
	aspect hh_look {
		draw circle (1) border:#black color:#gainsboro;
	}
	
	aspect hh_type_look {
		draw circle (1) border:#black color: HH_TYPE_COLOR[myType];
	}
}