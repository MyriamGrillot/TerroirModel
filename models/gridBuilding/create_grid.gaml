/**
 *  creerdescarres
 *  Author: grillot
 *  Description:  create the grid with the given area for each land unit and corresponding tree density
 */

model creerdescarres

import "../constants.gaml"

global {	
	file initGrid_ratioLU <- csv_file("../inputs/Gridbuilding_haLU.csv", false);
	file initGrid_treeDensity <- csv_file("../inputs/Gridbuilding_treeDensity.csv", false);
	
	string terroir;
	
	int grid_size const:true <- 50;
	float cell_area <- 0.25; 									//ha
	
	// --
	map<string,float> init_LU_area;
	 	
	int grid_radius <- int((grid_size - 1) / 2);
	cell central_cell <- cell[grid_radius, grid_radius];
	int neighb_at <- 8;
		
	int total_cells;
	int cell_HF;
	int cell_BF;
	int cell_DW;
	int cell_RGL;
	
	map<string,int> INIT_NB;
	
	// TREES	
	bool with_trees <- true;
	int total_trees;
	map<string,int> TREE_DENSITY_HA;
		
	// SAVING
	string cellFile <- ('../../includes/cells_'+terroir+'.shp');
	string cellFile_dwelling <- ('../../includes/cellsDwelling_'+terroir+'.shp');
	string cellFile_notDwelling <- ('../../includes/cellsNotDwelling_'+terroir+'.shp');
	string imageFile <- ('../../includes/cellsImage_'+terroir+'.jpg');
	string info <- ('../../includes/info_'+terroir+'.csv');  
	
	//////////// INIT //////////////
	init {	
		central_cell.color <- rgb(0,255,255);
		create center;
		
		// init map land uses and tree density
		matrix matinitGrid_ratioLU <- matrix(initGrid_ratioLU);
		int column; 
		int row;
		
		list<string> theList <- (matinitGrid_ratioLU) column_at 0;
		loop i over: theList {
			if i = terroir {
				row <- theList index_of (i);
				break;
			}
		}
		loop lu over: LAND_UNITS_NAMES {	
			theList <- (matinitGrid_ratioLU) row_at 0;
			loop i over: theList {
			if i = lu {
				column <- theList index_of (i);
				break;
			}
		}
			add lu::float(matinitGrid_ratioLU[column, row]) to:init_LU_area;
		}
		
		matrix matinitGrid_treeDensity <- matrix(initGrid_treeDensity);
		theList <- (matinitGrid_treeDensity) row_at 0;
		loop i over: theList {
			if i = terroir {
				column <- theList index_of (i);
				break;
			}
		}
		loop lu over: LAND_UNITS_NAMES {	
			theList <- (matinitGrid_treeDensity) column_at 0;
			loop i over: theList {
			if i = lu {
				row <- theList index_of (i);
				break;
			}
		}
			add lu::float(matinitGrid_treeDensity[column, row]) to:TREE_DENSITY_HA;
		}
		
		write "terroir: " + terroir + " - init_LU_area : " + init_LU_area;
		write "TREE_DENSITY_HA : " + TREE_DENSITY_HA;
	
		total_cells <- grid_size * grid_size;
		cell_HF <- int(init_LU_area[HOMEFIELD] / cell_area);
		cell_BF <- int(init_LU_area[BUSHFIELD] / cell_area);
		cell_DW <- int(init_LU_area[DWELLING] / cell_area);
		if cell_DW = 0 {
			cell_DW <- 1;
		}

		cell_RGL <- total_cells - cell_HF - cell_BF - cell_DW;
		INIT_NB <- ([HOMEFIELD::cell_HF, BUSHFIELD::cell_BF, RANGELAND ::cell_RGL, DWELLING::cell_DW]);
		
		save ["total cells: ", total_cells] to:info type:csv rewrite:true;
		save ["land unit ", "number of cells", "ratio", "total area"] to:info type:csv rewrite:false;
		loop i over: INIT_NB.keys {
			write "INIT_NB[i] " + INIT_NB[i] + " - " + init_LU_area[i];
			save [i, INIT_NB[i], INIT_NB[i]/total_cells, init_LU_area[i]] to:info type:csv rewrite:false;		
		}
		
		ask cell {
			dist_to_center <-  self distance_to central_cell ;
		}
		
		loop i over: LAND_UNITS_NAMES {
			loop times:INIT_NB[i] {
				list<cell> to_get_type <- cell where (each.has_type() = false);
				float min_value <- to_get_type min_of(each.dist_to_center);
				cell min <- any(to_get_type where (each.dist_to_center = min_value));
				min.type <- i; 
			}
		}
		ask cell {
			do colorie;
		}
		
		if with_trees {
			save ["land unit", "tree density", "area", "nb trees"] to:info type:csv rewrite:false;
			
			loop i over: LAND_UNITS_NAMES {
				float my_area <- sum (cell where (each.type = i) accumulate each.area);
				int my_trees <- int(my_area * TREE_DENSITY_HA[i]);
				
				loop times: my_trees {
					cell n <- any(cell where (each.type = i));
					n.nb_trees <- n.nb_trees + 1;
				}
				
				save [i, TREE_DENSITY_HA[i], my_area, my_trees] to:info type:csv rewrite:false;
			}
			save ["total trees: ", sum(cell accumulate(each.nb_trees))] to:info type:csv rewrite:false;
		}
		
		save cell to: cellFile attributes: ["Name"::name, "Type"::type, "Area"::area, "Trees"::nb_trees] type:shp rewrite:true;
		save cell where (each.type = DWELLING) to: cellFile_dwelling attributes: ["Name"::name, "Type"::type, "Area"::area, "Trees"::nb_trees] type:shp rewrite:true;
		save cell where (each.type != DWELLING) to: cellFile_notDwelling attributes: ["Name"::name, "Type"::type, "Area"::area, "Trees"::nb_trees] type:shp rewrite:true;
	}
}

grid cell height:grid_size width:grid_size neighbors:neighb_at {
	string type <- nil;
	float area <- cell_area;
	float dist_to_center <-0.0;
	int nb_trees;
	
	bool has_type {
		if type != nil {
			return true;	
		} else {
			return false;
		}	
	}
	
	action colorie {
		color <- TYPE_COLOR[type];	
	}
	
	aspect plotA {
		draw square(3.3) border:#black color: TYPE_HPorAP_COLOR[type];
	}
} 

species center {
	init {
		location <- central_cell.location;
	}
	
	aspect Imagecenter {			
		draw circle(1) color:#black;
	}
}

species tree {
}


experiment batch_exp type:batch repeat: 1 until:cycle=1  keep_seed: false {
	parameter "terroir" var: terroir <- "Sc1980a" among: ["Sc1900", "Sc1960", "Sc1980a", "Sc1980b", "ScTrad", "ScTran", "ScFat"];
}


experiment creerdescarres type: gui {
	parameter "terroir" var: terroir <- "ScTrad" among: ["Sc1900", "Sc1960", "Sc1980a", "Sc1980b", "ScTrad", "ScFat"];
	parameter "with trees?" var: with_trees <- true among: [true, false];
	output {
		display d {
			grid cell lines:rgb(0,0,0);
		
		overlay position: { 2, 3 } size: { 180 #px, 140 #px } background: # black transparency: 1 border: #black rounded: true {
                float y <- 18#px;
                int sizeText <- 14;
                
                draw "   Land units: area" at:{20#px, y} color: # black font: font("SansSerif", sizeText, #bold);
                y <- y + 20#px;
                draw "within the village (ha)" at:{12#px, y} color: # black font: font("SansSerif", sizeText, #bold);
                y <- y + 20#px;
                loop type over: TYPE_COLOR.keys {
                    draw square(15#px) at: { 20#px, y } color: TYPE_COLOR[type] border: #black;
                    draw type at: { 40#px, y + 4#px } color: # black font: font("SansSerif", sizeText, #bold);
                   	draw ": " + init_LU_area[type] + "ha" at: { 145#px, y + 2#px } color: # black font: font("SansSerif", sizeText, #bold);
                    y <- y + 20#px;
                }
            }
        }
	}
}