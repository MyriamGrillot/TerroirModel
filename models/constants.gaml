/**
 *  constants
 *  Author: grillot
 *  Description: model constants (strings and lists)
 */

model constants

global {
	
	/// CONSTANTS for PLOTS ************************
		// * land units
	string HOMEFIELD const:true <- "home fields"; 	// village field
	string BUSHFIELD const:true <- "bush fields";
	string RANGELAND const:true <- "rangelands";
	string DWELLING const:true <- "housing areas";
	
	list<string> AGRIC_PLOT_LANDUNITS const:true <- [HOMEFIELD, BUSHFIELD, RANGELAND];
	list<string> LAND_UNITS_NAMES const:true <- [DWELLING, HOMEFIELD, BUSHFIELD, RANGELAND];

	// colors according to land unit
	map<string,rgb> TYPE_COLOR const:true <- ([DWELLING::#skyblue, HOMEFIELD::#yellow, BUSHFIELD::#mediumspringgreen, RANGELAND::#indianred]);
	// colors for housing plots vs agricultural plots
	map<string,rgb> TYPE_HPorAP_COLOR const:true <- ([DWELLING::#gainsboro, HOMEFIELD::#darkseagreen, BUSHFIELD::#darkseagreen, RANGELAND ::#darkseagreen]);		
		
		//* land units for flows
	string EXTERIOR_LU const:true <- "exterior";
	string LIVESTOCK_LU const:true <- "livestock";
	
	string OTHER_LIVESTOCK_LU const:true <- "other livestock";
	string OTHER_HOMEFIELD const:true <- "other home fields";
	string OTHER_BUSHFIELD const:true <- "other bush fields";
	string OTHER_DWELLING const:true <- "other housing areas";
		
		// * land_uses	
	list<string> LAND_USES const:true <- [MILLET, GROUNDNUT, FALLOW, RGL_VEG];
	
	string MILLET const:true <- "millet";
	string GROUNDNUT const:true <- "groundnut";
	string FALLOW const:true <- "fallow";
	string RGL_VEG const:true <- "rangeland";
	
	map<string,rgb> LU_COLOR const:true  <- ([MILLET::#yellow, GROUNDNUT::#lightpink, FALLOW::#skyblue, RGL_VEG::#darkseagreen]);
	
		// cropping activity happens
	list<string> IS_CROP const:true <- [MILLET, GROUNDNUT]; 				
	list<string> NATURAL_VEG const:true <- [FALLOW, RGL_VEG];
	
	list<string> CAN_GROW const:true <- IS_CROP + NATURAL_VEG; 				// land_use that can grow
	
		// fertilisation
	list<string> FERTILISABLE_LANDUSES const:true <- [MILLET, GROUNDNUT];
	list<string> CROP_FIX_N const:true <- [GROUNDNUT];

		//* agriculturalPlot statuses
	string FREE const:true <- "free";
	string SOWN const:true <- "sown";
	string GROWING const:true <- "on growth";
	string MATURE const:true <- "mature";
	string PRODUCT_HARVESTED const:true <- "product harvested";
	list<string> PLOT_STATUSES const:true <- [FREE, SOWN, GROWING, MATURE, PRODUCT_HARVESTED]; 


	/// CONSTANTS for HOUSEHOLDS ************************
	list<string> HOUSEHOLD_TYPES const:true <- [LIV_SUBSISTENT, LIV_MARKET, CROP_SUBSISTENT, CROP_MARKET];
	string LIV_SUBSISTENT const:true <- "livestock subsistent";
	string LIV_MARKET const:true <- "livestock market";
	string CROP_SUBSISTENT const:true <- "crop subsistent";
	string CROP_MARKET const:true <- "crop market";
	
	map<string,rgb> HH_TYPE_COLOR const:true <- ([LIV_SUBSISTENT::#darkturquoise, LIV_MARKET::#skyblue, CROP_SUBSISTENT::#orange, CROP_MARKET::#darksalmon]);
	
													
	/// CONSTANTS for LIVESTOCK ************************
		//*TYPE:
	string BOVINE const:true <- "bovine";
	string SMALLRUMINANT const:true <- "smallRuminant";
	string EQUINE const:true <- "equine";
	list<string> LIVESTOCK_SPECIES const:true <- [BOVINE, SMALLRUMINANT, EQUINE];
	list<string> FAT_SPECIES <- [BOVINE, SMALLRUMINANT];
		
		//*MANAGEMENT:
	string FREEGRAZING const:true <- "grazing animal";
	string FAT const:true <- "fattened animal";
	string DRAUGHT const:true <- "draught animal";
	list<string> LIVESTOCK_MANAGEMENT const:true <- [FREEGRAZING, FAT, DRAUGHT];
	map<string, rgb> L_MANAGEMENT_COLOR const:true <- ([FREEGRAZING::#darkturquoise, FAT::#darksalmon]);
	
	//* FEED 
	//list<string> FEED_TYPE const:true <- [GRASS, STRAW, HAY, CONCENTRATED_FEED, FRESH_GRASS, LEAVES];
	string GRASS const:true <- "grass";
	string FRESH_GRASS const:true <- "fresh grass";
	string LEAVES const:true <- "leaves";
	string STRAW const:true <- "straw";
	string HAY const:true <- "hay";
	string CONCENTRATED_FEED const:true <- "concentrated feed";

	list<string> HH_STORED_FEED const:true <- [STRAW, HAY];
	list<string> LOW_FORAGE const:true <- [STRAW, LEAVES, GRASS];
	list<string> HIGH_FORAGE const: true <- [HAY, FRESH_GRASS];

	//* fertilizers ************************
	list<string> FERTILIZER_TYPES const:true <- [MINERAL, MANURE, WASTE, DUNG, URINE, RESIDUE];
	string MINERAL const:true <- "mineral";
	string MANURE const:true <- "manure";
	string WASTE const:true <- "waste";
	string RESIDUE const:true <- "residue";
	
	//list<string> LIVESTOCK_EXCRETIONS const:true <- [DUNG, URINE]; 
	string DUNG const:true <- "dung";
	string URINE const:true <- "urine";
	string REFUSAL const:true <- "refusal";
	
	list<string> MANURE_COMPONENT const:true <- [REFUSAL, DUNG, URINE, WASTE];
	list<string> HH_STORED_FERTILIZER const:true <- [MANURE];
	
	/// seeds ************************
	list<string> SEEDS const:true <- [MILLET_SEED, GROUNDNUT_SEED];
	string MILLET_SEED const:true <- "millet seed";
	string GROUNDNUT_SEED const:true <- "groundnut seed";
	
	list<string> HH_STORED_SEED const:true <- SEEDS;
	
	/// food & combustible ************************
	// food
	list<string> FOOD const:true <- [MILLET_COB, GROUNDNUT_UNHUSKED, RICE, FISH];
	string MILLET_GRAIN const:true <- "millet grain";
	string GROUNDNUT_GRAIN const:true <- "groundnut grain";
	
	string MILLET_POD const:true <- "millet pod";
	string GROUNDNUT_HUSK const:true <- "groundnut husk";
	
	
	string MILLET_COB const:true <- "millet cob";
	string GROUNDNUT_UNHUSKED const:true <- "groundnut unhusked";
	string RICE const:true <- "rice";
	string FISH const:true <- "fish";
	
	list<string> HH_STORED_FOOD const:true <- [MILLET_COB, GROUNDNUT_UNHUSKED];	
	list<string> PURCHASED_MARKET_FOOD <- [RICE, FISH];
		
	/// combustibles
	string WOOD const:true<- "wood";	
	list<string> HH_STORED_COMBUSTIBLE const:true <- [WOOD];

	/// stored goods
	list<string> HH_STORED_GOODS const:true <-  HH_STORED_FERTILIZER + HH_STORED_FEED + HH_STORED_FOOD + HH_STORED_SEED + HH_STORED_COMBUSTIBLE;
	
			
	//* PLOT products, co-products, by-products ************************
		// vegetal production (products+co-products)
	list<string> PLANTPRODUCTS const:true <- [MILLET_COB, STRAW, GROUNDNUT_UNHUSKED, HAY, GRASS, FRESH_GRASS];
		// products and coproducts
	map<string,list<string>> LANDUSE_PRODUCTS_COPRODUCTS_NAMES const:true <- ([MILLET::[MILLET_COB, STRAW], GROUNDNUT::[GROUNDNUT_UNHUSKED, HAY], FALLOW::[GRASS, nil], RGL_VEG::[GRASS, nil]]);
	map<string> CROP_SEEDS_ORIGINS const:true <- ([MILLET::MILLET_COB, GROUNDNUT::GROUNDNUT_UNHUSKED]);
	map<string, string> CROP_SEEDS const:true <- ([MILLET::MILLET_SEED, GROUNDNUT::GROUNDNUT_SEED]);
	
		// from raw product to products (grain) and by-products
	map<string, string> PRODUCT_NAME const:true <- ([MILLET_COB::MILLET_GRAIN, GROUNDNUT_UNHUSKED::GROUNDNUT_GRAIN]);
	map<string, string> BYPRODUCT_NAME const:true <- ([MILLET_COB::MILLET_POD, GROUNDNUT_UNHUSKED::GROUNDNUT_HUSK]);
	
	/// nitrogen
	string ATMO_N const:true <- "N atmospheric";
	string N_LOST const:true <- "N lost";
	
	/// flows
	// nota bene : biomassNames are in (FEED_TYPE + FERTILIZER_TYPES + SEEDS + FOOD + WOOD + ATMO_N + LIVESTOCK);
		//* ACTIVITIES / ecological processes
	string PLOT const:true <- "plot";
	string HUMAN const:true <- "human";
	string LIVESTOCK const:true <- "livestock";
	string GRANARY const:true <- "granary";
	string FERTILIZERS const:true <- "fertilizer";
	string EXT const:true <- "exterior";
	string RESPIRATION const:true <- "non apparent";
	
	string OTHER_GRANARY const:true <- "other granary";
	string OTHER_FERTILIZER const:true <- "other fertilizer";
	string OTHER_HUMAN const:true <- "other human";
	string OTHER_PLOT const:true <- "other plot";
	string OTHER_LIVESTOCK const:true <- "other livestock";
}