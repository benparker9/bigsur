## [Project Hub](../index.html)  

### Forest Inventory Data Source
Data was obtained through joint grant funding from the following universities -- UC Davis, UC Berekely, Cal Poly SLO, Boise State, North Carolina State and University of Georgia. The inventory includes three main datasets:    
    1) Plot attributes dataset which contains data on spatial and temporal elements of plot locations.   
    2) Tree dataset composed of tree measurements corresponding to size and health.    
    3) Coarse woody debris (CWD) dataset composed of woody material over 5cm in diameter found on the forest floor.   

#### Collection Method
Ecological field data collection focused on measuring different elements of Big Sur forests.   
- 280 500m2 fixed-radius plots were established to measure:   
    - Plot topographic features such as elevation,slope,aspect, gps coordinates and disease status.  
    - Diameter at breast height (DBH) of all trees over 1 cm   
        - Additionally trees are assessed for health class (categorical) and status (categorical).   
    - Coarse woody debris (CWD) volume of all woody debris > 5 cm present on the forest floor, additionally CWD is assessed for decay class (categorical).    

#### Generalizability, Limitations and Biases
This data represents the plot conditions, canopy and fuels structre of ecological conditions in a given year of time.
The Big Sur ecoregion is a biological hotspot with large tracts of untouched forest. There are a multidude of endemic species only located there,so drivers and trends identified for the Big Sur region may not be generalized to other regions. The initial research design does allow for generalizations for all of Big Sur. In question 7, I aim to better understand the potential bias inherent of plot sampling.    
    
### Datasets 
**Style Guide**    
- Column names cleaned to PascalCase (original case used by UC Davis)   
- Tables formatted with kable   
- Graphs utilize theme_classic (I would have made my own but the function is lengthy and I could not fit it < 6 pages>)   

### Plot Database
- Each row is when the plot was visited. There are many repeat variables (elevation,slope,burn scar,etc.) however this is the accounting method to track when plots were visitied and how they've changed.   
- Number of observations (n) = 899   
- Number of columns = 12   
- 2006-2025

#### Variable Descriptions
| \# | Variable Name | Data Type | Role |
|------------------|------------------|------------------|------------------|
| 1 | Plot | Categorical | Unique plot identifier used to track the spatial distribution of the plot, tree and cwd data. |
| 2 | SampleYear | Date | Year plot was inventoried. |
| 3 | Elevation | Numeric | Average elevation in meters of the plot.|
| 4 | Slope | Numeric | Average slope in percent of the plot.|
| 5 | Burn Scar | Categorical | Burn scar that impacted the plot - Chalk (2008), Sobreanes (2016), Dolan (2020). Some plots were burned twice in overlapping burns. Plots that did not burn are called control. |
| 6 | PRam | Categorical Binary| Disease presence within plot (from direct samples of tissue).|
| 7 | Fire | Categorical Binary| Fire presence within plot. For instance, although plots are within the Dolan fire burn scar, pre 2020, they will have Fire = 0. |
| 8 | Easting | Numeric | GPS reading of plot center.|
| 9 | Northing | Numeric | GPS reading of plot center.|

### Tree Database
- Each row is a tree measurement from when the plot was visited.    
- Number of observations (n) = 116,706    
- Number of columns = 7     
- 2006 - 2025

#### Variable Descriptions
| \# | Variable Name | Data Type | Role |
|------------------|------------------|------------------|------------------|
| 1 | Plot | Categorical | Unique plot identifier used to track the spatial distribution of the plot, tree and cwd data. |
| 2 | SampleYear | Date | Year plot was inventoried. |
| 3 | Species | Categorical | Unique species identifier built off the first two letters of the genus and species. IE. Sequoia sempervirens = SESE|
| 4 | StemId | Numeric | Unique stem id given to each stem.|
| 5 | Status | Categorical | Overall health of the tree - L (live) all the rest (D,M,E,NM) mean dead and are UC Davis jargon |
| 6 | DBH | Numeric | Diameter of the tree at breast height (cm).|


### Coarse woody debris (CWD) databases  
#### Tbl CWD (UC Davis)
- Each row is a unique CWD stem measured from when the plot was visited. Includes species and other metadata (time stamp, etc.)    
- Number of observations (n) = 1634  
- Number of columns = 6 (only three needed for analysis)     

#### Variable Descriptions
| \# | Variable Name | Data Type | Role |
|------------------|------------------|------------------|------------------|
| 1 | CWD_ID | Numeric | Unique stem id that allows us to track each stem through time. |
| 2 | BSPlotNumber | Numeric | Unique plot identifier used to track the spatial distribution of the plot, tree and cwd data. |
| 3 | PlantSpeciesAcronym | Categorical | Species identifier built off the first two letters of the genus and species. IE. Sequoia sempervirens = SESE.|

#### Tbl CWD Samples (UC Davis)
- Each row is a unique CWD stem measured from when the plot was visited. Includes actual measurements including diameters, volumes and decay class.    
- Number of observations (n) = 3363  
- Number of columns = 17 (only four needed for analysis)     
- 2009-2025  

#### Variable Descriptions
| \# | Variable Name | Data Type | Role |
|------------------|------------------|------------------|------------------|
| 1 | CWD_ID | Numeric | Unique stem id that allows us to track each stem through time. |
| 2 | SampleYear | Date | Year plot was inventoried. |
| 3 | DecayClass | Categorical | Indicates how recently the tree appeared on the forest floor (1=Fresh, 5=Very Decayed)|
| 4 | Volume | Numeric | Total volume (m3) of the stem. |


#### CWD Densities (Cal Poly)
- Each row is an average wood density (g/cm3) for six species across the five decay classes. Data was obtained through experiments by Dr.Cobb (CAFES) and has not been published.      
- Number of observations (n) = 6  
- Number of columns = 6 (will be pivoted to two)     

#### Variable Descriptions
| \# | Variable Name | Data Type | Role |
|------------------|------------------|------------------|------------------|
| 1 | Species | Categorical | Unique species identifier built off the first two letters of the genus and species. IE. Sequoia sempervirens = SESE. |
| 2 | X1 | Numeric | Density (g/cm3) at decay class 1. |
| 3 | X2 | Numeric | Density (g/cm3) at decay class 2. |
| 4 | X3 | Numeric | Density (g/cm3) at decay class 3. |
| 5 | X4 | Numeric | Density (g/cm3) at decay class 4. |
| 6 | X5 | Numeric | Density (g/cm3) at decay class 5. |



## Biological Context  
Key to the findings presented in analyze.qmd is the biological basis for the underlying wildfire and disease dynamics. From prior scientific literature, we understand that Phytophora ramorum kills tanoak, which accumulates on the forest floor until it's decomposed or burnt in wildire. We also know that redwood is a dead end host and does not die or spread the disease. Additionally, we understand that bay laurel is an asymptomatic spreader of Phytohpora ramorum and has the competitive advantage in diseased stands. 

In diseased stands, when wildfire occurs we expect to see higher mortality in redwood than in non-diseased stands.   
Dr. Cobb believes we may have some blindspots in pathogen sampling, so I aim to use dead host standing biomass and CWD to compare to disease status.





### Q7
-- Interactive map of the sites with number of times visited.   
-- Compare z-scores between our dataset and a simulated Poisson dataset.   
-- Seeking to understand where the bias in the sampling might have occured.     
Is there a spatial bias to the sampling that has occured?     












