/**
 *  Author: grillot
 *  Description: stock agent
 */

model stock

import "../constants.gaml"
import "../inputs/parameters.gaml"
import "plot.gaml"

global {
	string path_outputs <- "../../outputs/";
}

species stock {
	plot myLocation;
	household myOwner;
	string biomass among:HH_STORED_GOODS;
	
	pair<float, float> level_kgDM_Ncontent <- 0.0::0.0;
	pair<float, float> surplus_kgDM_Ncontent <- 0.0::0.0;

	float decrementLevel_kgDM (float decrement_kgDM) {
		float NC <- level_kgDM_Ncontent.value;
		float VDM <- level_kgDM_Ncontent.key;
		VDM <- VDM - decrement_kgDM;
		level_kgDM_Ncontent <- VDM::NC;
		
		if VDM < 0 {
			write "negative stock " + biomass + " - " + level_kgDM_Ncontent;
		}
		if VDM = 0 {
			level_kgDM_Ncontent <- 0.0::0.0;
		}
		return NC;
	}
	
	action incrementLevel (float increment_kgDM, float Ncontent) {
		float stockValue <- level_kgDM_Ncontent.key;
		float totalValue <- stockValue + increment_kgDM;
		float NC <- level_kgDM_Ncontent.value;
		if stockValue > 0 and NC != Ncontent {
			Ncontent <- (stockValue * NC + increment_kgDM * Ncontent)/ (totalValue);
		}
		level_kgDM_Ncontent <- (totalValue)::(Ncontent);
		return level_kgDM_Ncontent;
	}
	
	float updateGroundnutSurplus {
		int bags <- int(surplus_kgDM_Ncontent.key / gdnut_bag_weight_kgDM);
		float surplus_kgDM <- gdnut_bag_weight_kgDM * bags;
		return surplus_kgDM;
	}
		
	action updateSurplusFromStockLevel (float quantity_kgDM) {
		float VN <- decrementLevel_kgDM(quantity_kgDM);
		float stockValue <- surplus_kgDM_Ncontent.key;
		float NC <- surplus_kgDM_Ncontent.value;
		float totalValue <- stockValue + quantity_kgDM;
		
		if stockValue > 0 and VN != NC {
			VN <- (stockValue * NC + quantity_kgDM * VN)/ (totalValue);
		}
		surplus_kgDM_Ncontent <- quantity_kgDM::VN;
		return surplus_kgDM_Ncontent;
	}
		
	float decrementSurplus_kgDM (float decrement_kgDM) {		
		float NC <- surplus_kgDM_Ncontent.value;
		float VDM <- surplus_kgDM_Ncontent.key - decrement_kgDM;
		
		if VDM = 0 {
			surplus_kgDM_Ncontent <- 0.0::0.0;
		} else {
			surplus_kgDM_Ncontent <- VDM::NC;	
		}
		return NC;
	}
}