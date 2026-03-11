# ETV CYCLE FOR PROJECT 1
# FOREST INVENTORY DATASET

# LIBRARIES FOR EXTRACTION, MANIPULATION, EXPORTING
# requires sf package not covered in class
# load package if not present
packages <- c("sf")
for (pkg in packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}
# other packages
library(tidyr)
library(dplyr)
library(lubridate)
library(stringr)
library(here)
library(ggplot2)
library(htmltab) 
library(readxl)
library(purrr)

# Recycle functions
# Summary function to get an idea of the data
describe_me <- function(df){
  cat("==Dimensions==\n")
  dims <- dim(df)
  print(dims)
  cat("==Sampling Years Available==\n")
  sampling_years <- sort(unique(df$SampleYear))
  print(sampling_years)
  cat("==Column Data Types==\n")
  data_types <- str(df)
  print(data_types)
  cat("==Quantitative Summary Insights==\n")
  quant_summary <- df |>
    select(where(is.numeric))
  print(summary(quant_summary))
}
#speed up importing data
read_me <- function(path){
  read.csv(here("data","raw", path))
}
# speed up export to data/clean
export_me <- function(df,path){
  write.csv(df, here("data","clean", path))
}


# Plot DB Extract, Transform
plotDB <- read_me("plotDB.csv")
# Plot Database Details 
describe_me(plotDB)
# For an interactive map of how many times plots were inventoried I'll need to group and clean the plotDB
# Need to count how many times Inventoried
plot_mod1 <- plotDB |>
  group_by(Plot) |>
  summarize(TotalTimesInventoried = n()) |>
  right_join(plotDB, by=c("Plot"))
# Need to bin for visualization - Use of binning #1
# Used summary(plot_mod1$TotalTimesInventoried), breaking into bins by quartile
# Will use
# Low visit = 1-3
# Mid visit  = 4-5
# Mid-high visit = 6-8
# High visit = 9+
# Also use of case when for radius of circle for map
# Low visit = radius 1
# Mid visit  = radius 3
# Mid-high visit = radius 6
# High visit = radius 10
plot_mod2 <- plot_mod1 |>
  mutate(VisitFrequency = case_when(
                                    TotalTimesInventoried <= 3 ~ "Low Visit",
TotalTimesInventoried > 3 & TotalTimesInventoried < 6 ~ "Mid Visit",
TotalTimesInventoried >= 6 & TotalTimesInventoried < 9 ~ "Mid-High Visit",
TRUE ~ "High Visit")) |>
  mutate(Radius = case_when(
        VisitFrequency =="Low Visit"~1,
        VisitFrequency =="Mid Visit"~ 3,
        VisitFrequency =="Mid-High Visit"~ 6,
        VisitFrequency =="High Visit"~ 10
))

#Need to convert northing/easting to lat/lon
# requires sf 
# reference link https://r-spatial.github.io/sf/
lat_lon <- plot_mod2 |>
    select(Plot,Easting,Northing)

points_sf <- st_as_sf(lat_lon,
                      coords = c("Easting", "Northing"),
                      crs = 32610)  # UTM 10N - Based on big sur region 

# Convert to lat/long WGS 1984
points_wgs84 <- unique(st_transform(points_sf, crs = 4326))
# Join to plot frequency data 
plot_mod_map <- plot_mod2 |>
  select(Plot,TotalTimesInventoried,VisitFrequency,Radius) |>
  distinct(Plot, .keep_all = TRUE) |> #ai help
  right_join(points_wgs84, by="Plot") 
# Clean lat/lon from sf output to two columns with distinct lat/lon
plot_mod_map1 <- plot_mod_map |>
 separate(geometry, into = c("Lon", "Lat"), sep = " ") |>
 mutate(Lon = str_remove_all(Lon, "c\\(|,"),
 Lat = str_remove_all(Lat,"\\)"))
# clean up data types
plot_mod_map2 <- plot_mod_map1 |>
  mutate(Lon = as.numeric(Lon),
         Lat = as.numeric(Lat))


# Clean plot attributes db with no coordinate data -- will be used with tree,cwd data
plot_mod3 <- plot_mod2 |>
  select(!(c(Easting, Northing,VisitFrequency,Radius,TotalTimesInventoried)))

# CWD Database 
# These are raw from the UC Davis Access database.
# Need to clean and merge tblCWD with tblCWD_samples
# CWD_ID, Plot ID, Species w/ CWD_ID,SampleYear,Volume,DecayClass
# Allows me to track repeated stems 
# Join with density per species, calculate cwd mass
# Need to keep CWD_ID, Plot,Species from tblCWD
cwd <- read_excel(here("data","raw", "tblCWD.xlsx"))
# rename, keep desired columns
cwd1 <- cwd |> 
  rename(CwdId = CWD_ID,
         Plot = BSPlotNumber,
         Species = PlantSpeciesAcronym) |>
  select(CwdId,Plot,Species)

# Keep CwdId, SampleYear,DecayClass,Volume in cwd_samples
# program stops here
cwd_samples <- read_excel(here("data","raw", "tblCWD_Samples.xlsx"))  
cwd_samples2 <- cwd_samples |>
  rename(CwdId = CWD_ID) |>
  select(CwdId,SampleYear,DecayClass,Volume)

# merge on CwdId to add plot,species id's
# these id's are unique to stems
cwd_final <- cwd_samples2 |>
  left_join(cwd1, by="CwdId")

# Densities per species per decay class - experimental dataset provided by my professor
cwd_density <- read.csv(here("data","raw", "cwd-density.csv"))  
cwd_density2 <- cwd_density |>
  pivot_longer(cols=X1:X5, values_to="Density", names_to="DecayClass") |>
  rename(Species = Speices) |>
  mutate(DecayClass = str_remove(DecayClass, "X"))

# need to get overall average density per decay class for cwd data not studied
avg_decay <- cwd_density2 |>
  group_by(DecayClass) |>
  summarize(Density = mean(Density))

# merge for one cohesive density table to be merged
cwd_density3 <- bind_rows(cwd_density2,avg_decay)

# Join with raw cwd data - only evaluating DecayClass 1-5 due to density data gaps (only 1-5 studied)
cwd_final2 <- cwd_final |>
  left_join(cwd_density3, by=c("Species","DecayClass")) |>
  filter(DecayClass <= 5)

# There may be an easier way to do the next steps but not using AI
# no na's dataset, need to add average density per decay class to the other species
cwd_no_na <- na.omit(cwd_final2)
# I will save na's elsewhere, use the average and bind back to cwd_no_na
# Take na's for binding with "Average"
na <- cwd_final2 |>
  filter(is.na(Density)) |>
  filter(!is.na(Species)) |>
  select(!Density)
na_mod1 <- na |>
  left_join(avg_decay, by="DecayClass")
# Na_mod1 is then ready to merge with cwd final
cwd_final3 <- bind_rows(cwd_no_na, na_mod1) 
# Need to calculate mass and scale to per hectare (plots are 1/20ha so scale by 20 to get ha)
# Mass (Mg) = volume (m3) * density (g/cm3)  * 20 
cwd_final4 <- cwd_final3 |>
  mutate(Mass = (Volume * (Density)),
  DecayClass = as.numeric(DecayClass))

# Need total host and total plot mass per plot per year to export to the plot db for mixed models
total_host <- cwd_final4 |>
  filter(Species %in% c("LIDE","ARME","QUAG"))|>
  group_by(Plot,SampleYear) |>
  summarize(HostCwdMass = (sum(Mass,na.rm=TRUE)*20))
plot_mass <- cwd_final4 |>
  group_by(Plot,SampleYear) |>
  summarize(PlotCwdMass = (sum(Mass,na.rm=TRUE)*20))
summary_cwd <- total_host |>
  left_join(plot_mass,by=c("Plot","SampleYear"))
# na check-335 total

# export to plot_mod3
plot_mod4 <- plot_mod3 |>
  left_join(summary_cwd,by=c("Plot","SampleYear"))
# need to evaluate data gaps - cwd data was not taken every year
cwd_na <- plot_mod4 |>
  filter(!is.na(HostCwdMass))
print(paste("Number of distinct plots with CWD data:" , n_distinct(cwd_na$Plot)))
# These 112 plots will only be studied for cwd-tree interactions

# Q4 need to track plot cwd mass changes pre post fire
# first need to join plot_mass with plot_mod3 then group by plot,sampleyear, burnscar sum cwd mass
cwd_mass_change <-  plot_mod3 |>
  right_join(plot_mass,by=c("Plot","SampleYear")) |>
  select(!c(Elevation,Slope,Fire))

# function to filter for desired species, rename to common english, will be used in tree db as well
species_me <- function(df){
  df_mod1 <- df |>
    filter(Species %in% c("SESE","LIDE","UMCA")) |>
    mutate(Species = case_when(
                               Species == "SESE" ~ "Redwood",
                               Species == "LIDE" ~ "Tanoak",
                               Species == "UMCA" ~ "Bay laurel"))
  return(df_mod1)
}


#Q7 - Evaluating decay rates of Redwood, tanoak, Coast Live Oak, Douglas Fir, Bay Laurel
#Need biomass data through time
# Main eq http://www.nrcresearchpress.com/doi/10.1139/x06-012
#ln (Mt/M0) = -kt where t=year, Mt percent mass remaning after year t, M0 intial mass
# t0 = first time log is measured
# Using cwd_final4
# Only want to study SESE, LIDE,QUAG,PSME,UMCA
cwd_species <- species_me(cwd_final4) 

# need fire status from plot data, only select needed columns
cwd_species1 <- cwd_species |>
  left_join(plot_mod3, by=c("Plot","SampleYear"), relationship = "many-to-many") |>
  select(CwdId,Plot,SampleYear,Fire,PRam,Species,DecayClass,Mass)

# Only to follow repeatedly measured cwd stems - at least measured twice 
cwd_repeated_species <- cwd_species1 |>
  group_by(CwdId) |>
  filter(n() > 1) #ai help 
describe_me(cwd_repeated_species)
# total dataset changes from 2263 to 1578 rows
# Only need id, sampleyear, DecayClass,Plot,Species,Mass
# Need to create t column where t0 is the first time the CwdId was measured 
# need to create column named y which is log(Mt / M0) 
# there are data entries in this so i need use distinct
cwd_repeated_species2 <- cwd_repeated_species |>
  distinct(CwdId,Plot,SampleYear, .keep_all=TRUE) |>
  group_by(CwdId, Plot, DecayClass) |>
  mutate(
    tInit = min(SampleYear),
    t = SampleYear - tInit,
    Mass0 = Mass[t == 0],
    Y = log(Mass / Mass0)
  ) |>
  ungroup() |>
  filter(!is.na(Y), !is.infinite(Y), !is.nan(Y))

# data check to follow one stem through time
cwd_32 <- cwd_repeated_species2 |> filter(CwdId == 32)



# Tree Database Cleaning
treeDB <- read_me("treeDB.csv")  
describe_me(treeDB)
# First steps, drop Na's,filter for study species, clean species values, clean data types
tree_mod1 <- na.omit(treeDB)
describe_me(tree_mod1)
# determined errors in species using unique(tree_mod1 Species)
# Only plan on studying Redwood, tanoak, bay laurel, ponderosa pine, douglas fir, madrone
tree_mod2 <- tree_mod1 |>
  mutate(Species = str_replace(Species,"quag", "QUAG")) |>
  filter(Species %in% c("SESE","LIDE","UMCA","PIPO","PSME", "ARME", "QUAG"))

# Need to quantify biomass, use allometric equations to convert DBH into biomass (kg C)
#allometric equations https://www.fs.usda.gov/nrs/pubs/jrnl/2014/nrs_2014_chojnacky_001.pdf
# equation is biomass(kg) = exp(b0 + b1 * log(DBH)) 
eq <- function(b0,b1,DBH){
  exp(b0+b1*log(DBH))
}
# parameters can be found on page 140 
tree_mod3 <- tree_mod2 |>
  mutate(Biomass = case_when(
    Species == "LIDE" ~ eq(-2.2198, 2.4410, DBH),
    Species == "SESE" ~ eq(-2.7765,2.4195, DBH),
    Species == "QUAG" ~ eq(-2.2198, 2.4410, DBH),
    Species == "UMCA" ~ eq(-2.2118, 2.4133, DBH),
    Species == "ARME" ~ eq(-2.2118, 2.4133, DBH),
    Species == "PSME" ~ eq(-2.4623, 2.4852, DBH),
    Species == "PIPO" ~ eq(-3.2007, 2.5339, DBH)
))

# Q1
# Need aggregated live biomass (hectare) per plot per species per year
tree_biomass <- tree_mod3 |>
  filter(Status == "L") |>
  group_by(Plot,SampleYear,Species) |>
  summarize(TotalStem = n(),
            LiveBiomass = (sum(Biomass, na.rm=TRUE)*20))
# will join the above df with plot attributes for question 3
# Need to join this with cwd_na to get studyset for mixed models, using a right join to maximize cwd data
tree_bio_mod1 <- tree_biomass |>
  right_join(cwd_na, by=c("Plot","SampleYear"), relationship="many-to-many")
# 64 na's due to cwd data with no tree data, lose 23 of 112 distinct plots 
tree_na <- tree_bio_mod1 |>
  filter(is.na(Species))
# Final biomass data to export for question 1, no na's with clean column types
tree_dtypes <- function(df){
  df <- df |>
    filter(!is.na(Species)) |>
    mutate(across(c(PRam,Fire,BurnScar,Species), as.factor)) |>
    mutate(across(c(LiveBiomass,HostCwdMass,PlotCwdMass), as.numeric))
  return(df)
}
tree_bio_mod2 <- tree_dtypes(tree_bio_mod1)
tree_bio_mod3 <- species_me(tree_bio_mod2)

# Q2
# Similar to q1 set up but predicting binary mortality 
# Mortality 0 = Status = L, 1= Stauts= D,M,E (dead, missing, eliminated- UC Davis jargon all mean dead)
tree_mortality <- tree_mod3 |>
  filter(Status %in% c("L","D","E","M")) |>
  mutate(Mortality = ifelse(Status %in% c("D","E","M"), 1, 0)) 
# need to merge with cwd_na for plot attributes
tree_mortality1 <- tree_mortality |>
  right_join(cwd_na, by=c("Plot","SampleYear"), relationship="many-to-many")
# only keeping plot,species,sampleyear,mortality,elevation,slope,pram,fire,hostcwd,plotcwd
# apply dtypes function as well
tree_mortality2 <- tree_mortality1 |>
  select(Plot,Species,SampleYear,Mortality,Elevation,Slope,PRam,Fire,HostCwdMass,PlotCwdMass)
tree_dtypes2 <- function(df){
  df <- df |>
    filter(!is.na(Species)) |>
    mutate(across(c(PRam,Fire,Species), as.factor)) |>
    mutate(across(c(Mortality,HostCwdMass,PlotCwdMass), as.numeric))
  return(df)
}
tree_mortality3 <- tree_dtypes2(tree_mortality2)
tree_mortality4 <- species_me(tree_mortality3)

# Q3 Need to track biomass changes pre and post fire
# using tree_biomass and plot_mod3
biomass_changes <- tree_biomass |>
  left_join(plot_mod3, by=c("Plot","SampleYear"), relationship="many-to-many")

# Q6 - Wikipedia Extraction, Transformation , Export 
url <- "https://en.wikipedia.org/wiki/List_of_California_wildfires"

df_ca <- htmltab(doc=url, which=3, rm_nodata_cols = FALSE)
df_ca1 <- df_ca |>
  separate(`Fire name (cause)`, into=c("FireName","Cause"),sep="\\(") |>
  separate(`Start date`, into=c("Month","Year"),sep=" ") |>
  mutate(Cause = str_remove(Cause, "\\)"),
  `Acres (hectares)` = str_remove(str_remove(`Acres (hectares)`, " .*"), ","),
  Structures = str_remove(Structures, ",")) |>
  rename(AcresBurned = `Acres (hectares)`)

# want to identify causes so ill drop undetermined/unknown and ifelse for human/non-human start
df_ca2 <- df_ca1 |>
  mutate(HumanCaused = ifelse(Cause =="lightning", 0, 1)) |>
  mutate(across(c(AcresBurned,Structures,Deaths), as.numeric)) |>
  mutate(across(c(HumanCaused,Cause,Month), as.factor))


# Exports
# to data/clean for q 1
export_me(tree_bio_mod3, "livebiomass_mixedmodel.csv")
# to data/clean for q2
export_me(tree_mortality4, "mortality_mixedmodel.csv")
# to data/clean for q3
export_me(biomass_changes, 'post_fire_summary.csv')
# to data/clean for q4
export_me(cwd_mass_change, "cwd_mass_change_fire.csv")
# to data/clean for q5 
export_me(cwd_repeated_species2,'cwd_decay.csv')
# to data/clean for q6
export_me(df_ca2, "wiki_fire_data.csv")
# to data/clean for q7
export_me(plot_mod_map2,'bias.csv')
