/**
 *  Author: grillot
 *  Description: livestock herd agent + childs (bovine/smallRuminant/equine)
 */

model livestockHerd

import "../constants.gaml"
import "../inputs/parameters.gaml"

import "village.gaml"
import "plot.gaml"
import "household.gaml"

import "../outputs/saver.gaml"

global {
	string path_outputs <- "../../outputs/";
}

species livestock_herd {
	household myOwner;
	string mySpecies;
	string management;
	bool transhumance <- false;
	int stepPurchase <- 0;
	int fatteningDuration_day;
	point displayLocation;
	
	float value_TLU;
	
	plot myLocation;
	agriculturalPlot myPaddock;
		
	// total forage biomass required/TLU/day
	float lowForageNeed_TLUpday;
	float highForageNeed_TLUpday;
	
	// total biomass required/day for the herd
	list<float> herdForageNeeds_dDay <- [];
		
	// total concentrated_feed biomass required/TLU/day
	float concentratedFeedNeed_TLUpday;
	
 	// ingestions for d-day and day n-1 : depends on the plot where livestock ate and the type of food
	map<string, float> previousDayIngestions_kgDM <- [];
	map<plot, map<string, float>> dDayIngestions <- [];
	
	map<int, float> totalHerdForageNeeds_kgDM;
	map<int, float> totalHerdForageIngested_kgDM;
	map<string, float> totalHerdExcretions_kgN;
	
	map<int, list<float>> needCoverage;
	
	// ***** calculations
	// total biomass required/day for the herd 
	float herd_concentrate_needs_pday {
		return value_TLU * concentratedFeedNeed_TLUpday; 	
	}
	
	float herd_value_kgN {
		float v <- value_TLU * LIVESTOCK_kgNpTLU[mySpecies];
		return v;
	}
		
	action decrementValue_TLU (float quantity_TLU) {
		if value_TLU - quantity_TLU = 0 {
			ask myOwner {
				do saveDyingLivestockNeedCoverage(myself);
			}
		}
		
		value_TLU <- value_TLU - quantity_TLU;
		
		if value_TLU = 0 {
			remove self from: myOwner.myLivestock;
			if myPaddock != nil {
				remove self from: myPaddock.paddockedLivestock;
			}
			do die;
		}
	}
	
	int cycle_sell {
		return stepPurchase + fatteningDuration_day;
	}
		
	// total excretas for d-day
 	map<string, float> dailyExcretions_kgN {
		map<string, float> theMap;
		
		float ingested_kgN <- previousDayIngestedQuantity_kgN();
		float incrementTotal_kgN;
				
		string excreta <- DUNG;
		float quantity_kgN <- ingested_kgN * DUNG_EXCRETION_RATIO_kgNpkgNingested[management];
		theMap[excreta] <- quantity_kgN;
		
		if totalHerdExcretions_kgN[excreta] != nil {
			totalHerdExcretions_kgN[excreta] <- totalHerdExcretions_kgN[excreta] + quantity_kgN;
		} else {
			totalHerdExcretions_kgN[excreta] <- quantity_kgN;
		}
		
		if save_herdDailyExcretion and (consecutiveYears or year = nb_year_simulated) {
			ask saver {
				do saveHerdDailyExcreta(myself, excreta, quantity_kgN);
			}
		}
		
		excreta <- URINE;
		quantity_kgN <- quantity_kgN * URINE_EXCRETION_RATIO_kgNpkgNdung[management];
		theMap[excreta] <- quantity_kgN;
		
		if totalHerdExcretions_kgN[excreta] != nil {
			totalHerdExcretions_kgN[excreta] <- totalHerdExcretions_kgN[excreta] + quantity_kgN;
		} else {
			totalHerdExcretions_kgN[excreta] <- quantity_kgN;
		}
		
		if save_herdDailyExcretion and (consecutiveYears or year = nb_year_simulated) {
			ask saver {
				do saveHerdDailyExcreta(myself, excreta, quantity_kgN);
			}
		}

		if ingested_kgN < sum(theMap) {
			write "in livestock, exceta > ingestion: " + sum(theMap);	
		}

		return theMap;
	}
		
	float previousDayIngestedQuantity_kgN {
		float tot <- 0.0 ;
		
		loop type over: previousDayIngestions_kgDM.keys {
			tot <- tot + previousDayIngestions_kgDM[type] * BIOMASS_kgNperkgDM[type];
		}
		return tot;
	}
	
	// ACTIONS 
	// Update variables *******************************
	
	action increaseFeedNeeds {
		lowForageNeed_TLUpday <- forage_need_increase_kgDM_TLU_day[myOwner.myType][mySpecies][management].key;
		highForageNeed_TLUpday <- forage_need_increase_kgDM_TLU_day[myOwner.myType][mySpecies][management].value;
		concentratedFeedNeed_TLUpday <- feed_need_increase_kgDM_TLU_day[myOwner.myType][mySpecies][management];
		
		if highForageNeed_TLUpday < 0 or concentratedFeedNeed_TLUpday < 0 {
			write "error in livestock, high forage need : " + highForageNeed_TLUpday + " - " + concentratedFeedNeed_TLUpday + mySpecies;
			ask world{do pause;}
		}
	}
			
	action decreaseFeedNeeds {
		lowForageNeed_TLUpday <- forage_need_normal_kgDM_TLU_day[myOwner.myType][mySpecies][management].key;
		highForageNeed_TLUpday <- forage_need_normal_kgDM_TLU_day[myOwner.myType][mySpecies][management].value;
		concentratedFeedNeed_TLUpday <- feed_need_normal_kgDM_TLU_day[myOwner.myType][mySpecies][management];
			
		if highForageNeed_TLUpday < 0 or concentratedFeedNeed_TLUpday < 0 {
			write "error in livestock, high forage need : " + highForageNeed_TLUpday + " - " + concentratedFeedNeed_TLUpday + mySpecies;
			ask world{do pause;}
		}			
	}
	
	// Previous ingestions
	action udpatePreviousDayIngestions {
		previousDayIngestions_kgDM <- [];
		loop plt over: dDayIngestions.keys {
			loop feed over:dDayIngestions[plt].keys {
				float value_kgDM <- dDayIngestions[plt][feed];
				previousDayIngestions_kgDM[feed] <- (previousDayIngestions_kgDM[feed] + value_kgDM);
				
				if save_herdDailyIngestionNeed {
					if (consecutiveYears) or (year = nb_year_simulated) {
						ask saver {
							do saveHerdDailyIngestion(myself, plt.myLandUnit, feed, value_kgDM);
						}
					}
				}
			}
		}
		dDayIngestions <- ([]);
	}
	
	action updateForageFeedNeed {
		if management = FAT {
			int stepIncreaseFN <- int(stepPurchase + (cycle_sell() - stepPurchase) * FAT_NEED_INCREASE_ratio_purchase_sell[mySpecies]);
			if cycle = stepIncreaseFN {
				do increaseFeedNeeds;
			}
		}
		
		float low_kgDM <- value_TLU * lowForageNeed_TLUpday;
		
		if low_kgDM = 0 {
			write "in livestock herd low_kgDM = 0" + " lowForageNeed_TLUpday="+lowForageNeed_TLUpday + " value TLU="+value_TLU;
			ask world{do pause;}
		}
		
		float high_kgDM <- value_TLU * highForageNeed_TLUpday;
		
		herdForageNeeds_dDay <- [low_kgDM, high_kgDM];
		
		if save_herdDailyIngestionNeed {
			if (consecutiveYears) or (year = nb_year_simulated) {
				ask saver {
					do saveHerdDailyNeed(myself, low_kgDM, high_kgDM);
				}
			}
		}
		
		int ind <- 0;
		loop fl over: herdForageNeeds_dDay {
			if totalHerdForageNeeds_kgDM[ind] != nil {
				totalHerdForageNeeds_kgDM[ind] <- totalHerdForageNeeds_kgDM[ind] + fl;
			} else {
				totalHerdForageNeeds_kgDM[ind] <- fl;
				totalHerdForageIngested_kgDM[ind] <- 0.0;
			}
			ind <- ind + 1;
		}
	}
	
	
	action updateNeedCoverageForage {
		float totalNeeds <- sum(totalHerdForageNeeds_kgDM);
		float totalIngested <- sum(totalHerdForageIngested_kgDM);

		needCoverage[month] <- [totalIngested, totalNeeds];
	}
	
		//* Paddocking
	action updatePaddock {
		if management = FREEGRAZING {
			
			agriculturalPlot mt <- myOwner.manureTarget; 
			agriculturalPlot newPaddock <- nil;
			
			// choose manure target
			if mt != nil and mt.isGrazable {
				if myPaddock != mt {	
					newPaddock <- mt;
				}
			} else {
				// choose other agricultural plot
				if (myPaddock.myLandUnit != RANGELAND and myPaddock.isGrazable and myPaddock.organicFertilizationTargeted_kgDM > myPaddock.organicFertilizationInput_kgDM) {
					newPaddock <- myPaddock;
				} else {
					newPaddock <- first((myOwner.myAgriculturalPlots where (each.organicFertilizationTargeted_kgDM > each.organicFertilizationInput_kgDM and each.isGrazable)) sort_by(each.fertilizationPriority));
					
					// one agricultural plot owned by my owner
					if newPaddock = nil {
						newPaddock <- first(shuffle(myOwner.myAgriculturalPlots where (each.landUse = FALLOW and each.future_landUse = MILLET and each.isGrazable)));
						
						if newPaddock = nil {
							newPaddock <- first(shuffle(myOwner.myAgriculturalPlots where (each.landUse = FALLOW and each.isGrazable)));
						
						// any agricultural plot in FALLOW
							if newPaddock = nil {
								newPaddock <- first(shuffle(agriculturalPlot where (each.landUse = FALLOW and each.isGrazable)));
								
								// any agricultural plot RANGELAND
								if newPaddock = nil {
									newPaddock <- first((agriculturalPlot where (each.myLandUnit = RANGELAND)));
								} 
							}
						}
					}
				}
			}
			
			if newPaddock != nil and newPaddock != myPaddock {
				ask myPaddock {
					paddockedLivestock >- myself;
				}
				
				myPaddock <- newPaddock;		
				myLocation <- myPaddock;
				displayLocation <- any_location_in(myLocation);			
				
				ask myPaddock {
					paddockedLivestock <- paddockedLivestock + myself;
				}
			}			
		}
	}
	
	
	////////// INGESTIONS
	action ingest (string biomass, plot theLocation, float theQuantity_kgDM, float Ncontent) {
		if theQuantity_kgDM > 0 {					
			if(dDayIngestions.keys contains(theLocation)) {	
				map<string,float> pplot <- dDayIngestions at theLocation;
				
				if(pplot.keys contains(biomass)) {
					add (pplot[biomass] + theQuantity_kgDM) at: biomass to: pplot;
					add pplot at: theLocation to: dDayIngestions; 				
				} else { 
					add (theQuantity_kgDM) at: biomass to: pplot;
				}
			} else {
				add ([biomass::theQuantity_kgDM]) at: theLocation to:dDayIngestions;
			}
		}
	}
	
	action decrementForageNeeds (int forageIndex, float distributedQuantity_kgDM) {
		herdForageNeeds_dDay[forageIndex] <- (herdForageNeeds_dDay[forageIndex] - distributedQuantity_kgDM);
		totalHerdForageIngested_kgDM[forageIndex] <- (totalHerdForageIngested_kgDM[forageIndex] + distributedQuantity_kgDM);
	}

	action grazeInOnePlot {
		list<string> listOrigins;
		list<string> listDestinations;
		int forageIndex <- 0;
		string theFeed;
		
		if herdForageNeeds_dDay[forageIndex] > 0 {
			agriculturalPlot targetPlot;
			pair<agriculturalPlot, pair<string, float>> plotnbiomass <- chooseGrazingPlot(); 
			targetPlot <- plotnbiomass.key;
								
			if targetPlot != nil {	
				listOrigins <- [PLOT, targetPlot.myLandUnit];
				listDestinations <- [LIVESTOCK, targetPlot.myLandUnit];			
				
				pair<string, float> biomassnvalue <- plotnbiomass.value; 
				theFeed <- biomassnvalue.key;
				float quantityAvailable <- biomassnvalue.value;				
 				float ingestedQuantity_kgDM <- min([targetPlot.plantStocks_kgDM[theFeed], herdForageNeeds_dDay[forageIndex]]);

				if (ingestedQuantity_kgDM > 0) {
					float Ncontent;
					ask targetPlot {
						Ncontent <- destockPlot(theFeed, ingestedQuantity_kgDM);
					}
												
					float ingestedQuantity_kgN <- ingestedQuantity_kgDM * Ncontent;
					do ingest(theFeed, targetPlot, ingestedQuantity_kgDM, Ncontent);																								
					do decrementForageNeeds(forageIndex, ingestedQuantity_kgDM);
												
					ask world {
						household theH <- targetPlot.myOwner;
						if theH != myself.myOwner {
							listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
						}
						do updateFlowMaps_kgN(theH, myself.myOwner, theFeed, ingestedQuantity_kgN, listOrigins, listDestinations);
					}
				}
			}
		}
	}
	
	action chooseGrazingPlot {
		list<string> listFeed;		
		map<agriculturalPlot, pair<string, float>> targetPlots <- ([]);
		pair<agriculturalPlot, pair<string, float>> plotnbiomass;
		agriculturalPlot target;
		int lengthBiomassP <- length(biomassPreferencesGrazing);

		// try in owned plots
		list<agriculturalPlot> freePlots <- myOwner.myAgriculturalPlots where (each.isGrazable and sum(each.plantStocks_kgDM) > 0);
		int biomassPreferenceIndex <- 0;
		
		if !empty(freePlots) {						
			loop while: empty(targetPlots) and biomassPreferenceIndex < lengthBiomassP {
				listFeed <- biomassPreferencesGrazing[biomassPreferenceIndex];	
				loop i over:listFeed {
					targetPlots <- targetPlots + (freePlots where (each.plantStocks_kgDM[i] > 0) as_map (each::(i::each.plantStocks_kgDM[i])));
				}
				biomassPreferenceIndex <- biomassPreferenceIndex + 1;
			}
		}
				
		// else try in any other plot
		if empty(targetPlots) {
			freePlots <- agriculturalPlot where (each.isGrazable and sum(each.plantStocks_kgDM) > 0);
			biomassPreferenceIndex <- 0;
		
			loop while: empty(targetPlots) and biomassPreferenceIndex < lengthBiomassP {
				listFeed <- biomassPreferencesGrazing[biomassPreferenceIndex];
				loop i over:listFeed {
					targetPlots <- targetPlots + (freePlots where (each.plantStocks_kgDM[i] > 0) as_map (each::(i::each.plantStocks_kgDM[i])));
				}
				biomassPreferenceIndex <- biomassPreferenceIndex + 1;
			}
		}	
		
		// return value
		if empty(targetPlots) {
			return nil;
		} else {
			map<agriculturalPlot, pair<string, float>> theMap <- [];
		
			// get max biomass value
			list<pair<string, float>> pairs <- targetPlots.values;
			pair<string, float> p <- pairs with_max_of(each.value);
			string biomass <- p.key;
			
			loop plt over:targetPlots.keys {
				if p = targetPlots[plt]{
					if plt.plantStocks_kgDM[biomass] > 0.00 {
						add plt::(biomass::plt.plantStocks_kgDM[biomass]) to: theMap;
					}
				} else {
					targetPlots[] >- plt;
				}
			} 
			
			// if no biomass on the plot but in surrounding plots
			if empty(theMap) {
				write "in livestock herd grazing: no biomass on the plot";
			}
				
			if empty(theMap) {
				write "in livestock,  .. " + targetPlots;
			} else {
				target <- one_of(theMap.keys);
				biomass <- theMap[target].key;					
				plotnbiomass <- target::(theMap[target]);
			}
			return plotnbiomass;
		}
	}
	
	action eatForageAndProduceRefusals (string biomassType, float distributed_qty_kgDM, float Ncontent, int forageIndex) {		
		float refusal_kgDM <- refusal_ratio[biomassType] * distributed_qty_kgDM;
		float ingested_qty_kgDM <- distributed_qty_kgDM - refusal_kgDM;
		
		do ingest(biomassType, myLocation, ingested_qty_kgDM, Ncontent);
		do decrementForageNeeds(forageIndex, (ingested_qty_kgDM + refusal_kgDM));
		
		list<string> listOrigins;
		household theH <- myOwner;
		
		// store refusals
		if refusal_kgDM > 0 {
			biomassType <- REFUSAL;
			float refusalNcontent <- BIOMASS_kgNperkgDM[biomassType];
			float refusalStored_kgN <- refusal_kgDM * refusalNcontent;
			list<string> listDestinations;
			
			ask myOwner {
				if myself.myPaddock = nil {
					listDestinations <- stockStorage(biomassType, refusal_kgDM, refusalNcontent);
				} else {
					listDestinations <- stockPlot(myself.myPaddock, biomassType, refusal_kgDM, refusalNcontent);
					theH <- myself.myPaddock.myOwner;
				}
			}
				
			//* flow (refusal)
			ask world {
				if theH != myself.myOwner {
					listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
					listOrigins <- [LIVESTOCK, listDestinations[1]];
				}
				listOrigins <- [LIVESTOCK, listDestinations[1]];
				
				do updateFlowMaps_kgN(myself.myOwner, theH, biomassType, refusalStored_kgN, listOrigins, listDestinations);
			}
		}
	}

	////////// EXCRETIONS
	action excreteOnPlots {
		map<string, float> dailyExc_kgN <- dailyExcretions_kgN();
		household theH <- myOwner;
		
		list<string> listOrigins;
		list<string> listDestinations;
		agriculturalPlot thePlot;
		float ratioExcretaOnThePlot;
		
		float totalIngested_kgDM;
		if management = FREEGRAZING {
			totalIngested_kgDM <- sum(dDayIngestions accumulate(each.values));
		}
		
		loop plt over: dDayIngestions.keys {
			ratioExcretaOnThePlot <- (time_grazeHour + time_in_corralHour)/hour_pDay;
			
			if length(dDayIngestions.keys) = 1 and ratioExcretaOnThePlot != 1 {
				write "in livestockherd, length(dDayIngestions.keys) " + length(dDayIngestions.keys) + " - " + ratioExcretaOnThePlot;
			}
			
			if management = FREEGRAZING {
				map<string, float> vals <- dDayIngestions[plt];		
				float ingestionOnPlt <- sum(vals.keys collect vals[each]);
				ratioExcretaOnThePlot <- ingestionOnPlt/totalIngested_kgDM * (time_grazeHour/hour_pDay);
			}
			
			loop eType over:dailyExc_kgN.keys {				
				float val_kgN <- dailyExc_kgN[eType];
				float excreta_kgN <- val_kgN * ratioExcretaOnThePlot;
				
				if excreta_kgN > 0 {
					float excreta_kgDM <- excreta_kgN / LIVESTOCK_EXCRETA_content_kgNpkgDM[eType];
					float Ncontent <- excreta_kgN/excreta_kgDM;
					
					// stock excreta
					ask myOwner {
						if plt in housingPlot {
							listDestinations <- stockStorage(eType, excreta_kgDM, Ncontent);
						} else {
							thePlot <- agriculturalPlot(plt);
							listDestinations <- stockPlot(thePlot, eType, excreta_kgDM, Ncontent);
							theH <- thePlot.myOwner;
						}
					}
					//* flow
					ask world {						
						if theH != myself.myOwner {
							listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
						}
						
						listOrigins <- [LIVESTOCK, listDestinations[1]];
						
						do updateFlowMaps_kgN(myself.myOwner, theH, eType, excreta_kgN, listOrigins, listDestinations);
					}
				}
			}
		}
		
		if management = FREEGRAZING {
			thePlot <- myPaddock;
			ratioExcretaOnThePlot <- time_in_corralHour/hour_pDay;
			
			loop eType over:dailyExc_kgN.keys {
				float val_kgN <- dailyExc_kgN[eType];
				float excreta_kgN <- val_kgN * ratioExcretaOnThePlot;
				
				if excreta_kgN > 0 {
					float excreta_kgDM <- excreta_kgN / LIVESTOCK_EXCRETA_content_kgNpkgDM[eType];
					float Ncontent <- excreta_kgN/excreta_kgDM;

					// stock excreta
					ask myOwner {
						listDestinations <- stockPlot(thePlot, eType, excreta_kgDM, Ncontent);
						theH <- thePlot.myOwner;
					}
					//* flow
					ask world {
						if theH != myself.myOwner {
							listDestinations <- switchOtherOriginDestination(listDestinations[0], listDestinations[1]);
						}
						listOrigins <- [LIVESTOCK, listDestinations[1]];
						
						do updateFlowMaps_kgN(myself.myOwner, theH, eType, excreta_kgN, listOrigins, listDestinations);
					}
				}
			}
		}
			
	}

//a module for demorgraphic evoluation can be added:
	float livestockMortalityRate (int number_months_withLowNeedCoverage) {
		float rate;
		if number_months_withLowNeedCoverage < 6 {
			rate <- 0.0333 * number_months_withLowNeedCoverage + 0.1;
		} else {
			rate <- 0.1167 * number_months_withLowNeedCoverage - 0.6;
		}
		return rate;
	}
		
	float livestockBirthRate (int number_months_withLowNeedCoverage) {
		float rate;
		if number_months_withLowNeedCoverage < 6 {
			rate <- - 0.0083 * number_months_withLowNeedCoverage + 0.05;
		} else {
			rate <- 0.0;
		}
		return rate;
	}
		

	action demographicEvolution {
		float low_NeedCoverage;
		ask first(village) {
			low_NeedCoverage <- lowNeedCoverage;
		}
		float mortalityRate;
		float birthRate;	
		int month_lowNeedCoverage <- length(needCoverage accumulate (each) where (each < low_NeedCoverage));
	
		// mortality & birth
		mortalityRate <- livestockMortalityRate(month_lowNeedCoverage);
		birthRate <- livestockBirthRate(month_lowNeedCoverage);
		
		float herd_growthRate <- birthRate - mortalityRate;
		float herd_growth <- value_TLU * herd_growthRate;
		value_TLU <- value_TLU + herd_growth;
		
		if herd_growth < 0 {
			ask myOwner {
				do sellHerd(myself, herd_growth);
			}
		}
	}
// end of module for demography	

	// ASPECT
	aspect liv_look {
		if (management = FREEGRAZING){
			draw file("../images/goat.png") at: displayLocation size:5 color: #black;
		} 	
	}
}

/// **************
species bovine parent:livestock_herd {
	init {
		mySpecies <- BOVINE;
	}	
}

species smallRuminant parent:livestock_herd {
	init {
		mySpecies <- SMALLRUMINANT;
	}
}

species equine parent:livestock_herd {
	init {
		mySpecies <- EQUINE;
	}
}