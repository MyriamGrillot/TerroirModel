/**
* Name: grid
* Author: grillot
* Description: used to display grid only
*/

model grid_model

import "../inputs/parameters.gaml"

global {
	file initScenario <- csv_file("../inputs/InitScenarios.csv", false);
	
// couleurs pour ScFAT:
//	map<string,rgb> TYPE_COLOR const:true <- ([DWELLING::#skyblue, HOMEFIELD::#yellow, BUSHFIELD::#mediumspringgreen, RANGELAND::#mediumspringgreen]);
	
	init {	
		// load data
		int column;
		int row;
		list<string> theList;
		
		matrix matScenario <- matrix(initScenario);
		theList <- (matScenario) row_at 0;
		loop i over: theList {
			if i = scenario {
				column <- theList index_of (i);
				break;
			}
		}
				
		string shape_name <- string(matScenario[column, 1]);
		
		file dwellingFile <- file("../includes/cellsDwelling_" + shape_name + ".shp");
		file notDwellingFile <- file("../includes/cellsNotDwelling_"+ shape_name + ".shp");
		shape <- envelope("../includes/cells_"+ shape_name +".shp");
		
		create housingPlot from: dwellingFile with: [
			myLandUnit::string(read("Type")),
			area_ha::float(read("Area"))
		];
				
		create agriculturalPlot from: notDwellingFile with: [
			myLandUnit::string(read("Type")),
			area_ha::float(read("Area"))
		];
	}

}

species plot {
	string myLandUnit;
	float area_ha;
}

species agriculturalPlot parent:plot{
	// ASPECT
	aspect land_unit {
		draw shape color: TYPE_COLOR[myLandUnit] border:#black empty:false;
	}
}

species housingPlot parent:plot{
	// ASPECT
	aspect land_unit {
		draw shape color: TYPE_COLOR[myLandUnit] border:#black empty:false;
	}
}

////////////////////////////////////EXPERIMENT /////////////////////////////////////////////////
experiment displaygrid type:gui {
	parameter "initial shape" var: scenario <- "ScTrad" among: ["ScTrad"];
	
	output{	
		display terroir {
			species agriculturalPlot aspect:land_unit;
			species housingPlot aspect:land_unit;		
			
			// legend
			overlay position: { 2, 2 } size: { 180 #px, 205 #px } background: # white transparency: 1.0 border: #black rounded: true
            {
                float y <- 30#px;
                draw "Land units: " at:{35#px, y} color: # black font: font("SansSerif", 18, #bold);
                y <- y + 30#px;
                
                loop type over: TYPE_COLOR.keys
                {
                	draw square(30#px) at: { 25#px, y } color: TYPE_COLOR[type] border: #black;
	                draw type at: { 45#px, y + 4#px } color: # black font: font("SansSerif", 18, #bold);
	                y <- y + 40#px;
                }    
            }
		}
	}
}