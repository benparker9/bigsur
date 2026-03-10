# Due to the complexity of the analysis, i am using this script for long-winded problems
# need mixed models packages
packages <- c("lme4")
for (pkg in packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}
#load the rest
library(tidyr)
library(dplyr)
library(here)
library(ggplot2)
library(readr)
library(purrr)
library(knitr)
#load lmerTest after for p-values
library(lmerTest)
# recycle functions
read_me <- function(path){
  read_csv(here("data","clean", path))
}
export_me <- function(df,path){
  write.csv(df, here("data","clean", path), row.names=FALSE)
}

# Q1 - Mixed-effects models to understand drivers of biomass in Big Sur trees
biomass <-  read_me("livebiomass_mixedmodel.csv")
species_df <- unique(biomass$Species)
biomass_model <- function(species){
  df1 <- biomass |>
    filter(Species == {{species}})
  mixed_model <- lmer(LiveBiomass ~ PlotCwdMass + HostCwdMass + Elevation + Slope + Fire + PRam +
                    (1|SampleYear) + (1|Plot),
                    data=df1
                     )
  summary <- summary(mixed_model)
  
  df_summary <- as.data.frame(summary$coefficients) |>
     mutate(Species = species)
  df_summary$Term = rownames(df_summary)
  return(df_summary)
}

species_models <- map_df(species_df, biomass_model)

species_models2 <- species_models |>
  rename(p = 5) |>
  mutate(Results = ifelse(
    p < 0.05,
    paste0("**", round(Estimate, 3), " (", formatC(p, format = "e", digits = 2), ")**"),
    paste0(round(Estimate, 3), " (", formatC(p, format = "e", digits = 2), ")")
  )) |>
  select(Species,Term,Results) |>
  pivot_wider(names_from="Term", values_from="Results") |>
  select(!`(Intercept)`)

species_models3 <- species_models2 |>
  rename(Disease = PRam,
        `Plot Cwd Mass` = 2,
        `Host Cwd Mass` = 3)


export_me(species_models3, "q1-table.csv")

# Q2 - Logistic regression
mortality <-  read_me("mortality_mixedmodel.csv")
species_mortality <- unique(mortality$Species)

mortality_model <- function(species){
  df1 <- mortality |>
    filter(Species == {{species}})
  logistic_model <- glm(Mortality ~ PlotCwdMass + HostCwdMass + Elevation + Slope + Fire + PRam,
                    data=df1, family = binomial
                     )
  summary <- summary(logistic_model)
  
  df_summary <- as.data.frame(summary$coefficients) |>
     mutate(Species = species)
  df_summary$Term = rownames(df_summary)
  return(df_summary)
}

mortality_results <- map_df(species_mortality, mortality_model)

mortality_results2 <- mortality_results |>
  rename(p = 4) |>
  mutate(Results = ifelse(
    p < 0.05,
    paste0("**", round(Estimate, 3), " (", formatC(p, format = "e", digits = 2), ")**"),
    paste0(round(Estimate, 3), " (", formatC(p, format = "e", digits = 2), ")")
  )) |>
  select(Species,Term,Results) |>
  pivot_wider(names_from="Term", values_from="Results") |>
  select(!`(Intercept)`)

mortality_results3 <- mortality_results2 |>
  rename(Disease = PRam,
        `Plot Cwd Mass` = 2,
        `Host Cwd Mass` = 3)

export_me(mortality_results3, "q2-table.csv")

#Q3
# only selecting stems that have been measured 5 years pre fire and 3 years post fire
burn_change <- function(burn, time1) {
  df <- biomass_changes |>
    filter(BurnScar == burn) |>
    select(!c(Elevation,Slope,Fire)) |>
    mutate(Pre = case_when(
      SampleYear < time1 & SampleYear > time1-5 ~ "Pre",
      SampleYear >= time1 & SampleYear <= time1+ 3 ~ "Post",
      TRUE ~ "NA")) 
  df_mod1 <- df |>
    filter(Pre %in% c("Pre","Post")) |>
    group_by(Plot, Species, BurnScar, PRam, Pre) |>
    summarise(
      TotalStem   = sum(TotalStem, na.rm = TRUE),
      LiveBiomass = sum(LiveBiomass, na.rm = TRUE),
      .groups = "drop"
    ) |>
    pivot_wider(names_from="Pre", values_from=c("TotalStem","LiveBiomass"))
  # only want to evaluate data with both pre and post 
  df_mod2 <- na.omit(df_mod1)
  df_mod3 <- df_mod2 |>
    mutate(ChangeStem = TotalStem_Post - TotalStem_Pre,
      ChangeBiomass = LiveBiomass_Post - LiveBiomass_Pre) |>
    select(c(1,2,3,4,9,10))
  return(df_mod3)
}
# apply summary function to dataset we want
sites_tree <- tibble(
  burn  = c("dolan", "sober", "chalk", "control" ),
  time1 = c(2020, 2016, 2007, 2007 )
)
demo_tree <- pmap_df(sites_tree, burn_change)

post_fire_summary <- demo_tree |>
  group_by(Species) |>
  summarize( n = n(),
            MeanStemChange = mean(ChangeStem, na.rm=TRUE),
            MeanBiomassChange = mean(ChangeBiomass, na.rm=TRUE),
            MedianStemChange    = median(ChangeStem, na.rm = TRUE),
            MedianBiomassChange = median(ChangeBiomass, na.rm = TRUE),
            SdStemChange = sd(ChangeStem, na.rm=TRUE),
            SdBiomassChange = sd(ChangeBiomass, na.rm=TRUE)
) |>
  rename(
         `Mean Change in Stem Density` = 3,
     `Mean Change in Biomass` = 4,
     `Median Change in Stem Density` = 5,
     `Median Change in Biomass` = 6,
  `SD Change in Stem Density` = 7,
  `SD Change in Biomass` = 8)

post_fire_summary2 <- species_me(post_fire_summary)
export_me(post_fire_summary2, 'q3-table.csv')

# Q4 
cwd_fire <- read_me("cwd_mass_change_fire.csv")

burn_cwd_change <- function(burn, time1) {
  df <- cwd_fire |>
    filter(BurnScar == burn) |>
    mutate(Time = case_when(
      SampleYear < time1 & SampleYear > time1-5 ~ "Pre",
      SampleYear >= time1 & SampleYear <= time1+ 3 ~ "Post",
      TRUE ~ "NA")) 
  df_mod1 <- df |>
    filter(Time %in% c("Pre","Post")) |>
    group_by(Plot, BurnScar, Time) |>
    summarise(
      Biomass = sum(PlotCwdMass, na.rm = TRUE)) |>
    pivot_wider(names_from="Time", values_from="Biomass",names_expand = TRUE)
  df_mod2 <- df_mod1 |>
    filter(!is.na(Pre) & !is.na(Post))
  df_mod3 <- df_mod2 |>
    mutate(ChangeBiomass = Post - Pre) 
  return(df_mod3)
}

sites_cwd <- tibble(
  burn  = c("dolan", "sober",  "control" ),
  time1 = c(2020, 2016, 2013  )
)

cwd_demo <- pmap_df(sites_cwd, burn_cwd_change)

post_fire_cwd_summary <- cwd_demo |>
  group_by(BurnScar) |>
  summarize( n = n(),
            MeanBiomassChange = mean(ChangeBiomass, na.rm=TRUE),
            MedianBiomassChange = median(ChangeBiomass, na.rm = TRUE),
            SdBiomassChange = sd(ChangeBiomass, na.rm=TRUE),
            MinBiomassChange = min(ChangeBiomass, na.rm=TRUE),
            MaxBiomassChange = max(ChangeBiomass, na.rm=TRUE)
) |>
  rename(`Burn Scar` = 1,
          `Mean Change in Cwd Biomass` = 3,
     `Median Change in Cwd Biomass` = 4,
      `SD Change in Cwd Biomass` = 5,
     `Min Change in Cwd Biomass` = 6,
     `Max Change in Cwd Biomass` = 7) |>
  mutate(`Burn Scar` = case_when(`Burn Scar` == "control" ~ "Control",
                                  `Burn Scar` == "dolan" ~ "Dolan Fire",
                                  `Burn Scar` == "sober" ~ "Sobreanes Fire"))


export_me(post_fire_cwd_summary, 'q4-table.csv')

# Q5 Exponential decay of Cwd
cwd_decay <- read_me("cwd_decay.csv")
expo_decay <- function(species){
  df <- cwd_decay |>
    filter(Species == species) 
  model <- nls(Y ~ -k*t, data=df, start=list(k=0.7))
  df$PredictedY <- predict(model)
  summary <- summary(model)
  
  return(df)
}
# apply model function to all species
species_vec <- unique(cwd_decay$Species)
expo_results <- map_df(species_vec, expo_decay)
# need to prepare for visuals
expo_results2 <- expo_results |>
  mutate(Fire = as.factor(Fire)) |>
  drop_na() |>
  mutate(Burn = ifelse(Fire == 0, "Unburned", "Burned"))

# export results
export_me(expo_results2, "q5-plot.csv")

# Q6 Wikipedia Multiple Regression
wiki_fire <- read_me("wiki_fire_data.csv")

deaths_per <- wiki_fire |>
  group_by(Cause,HumanCaused) |>
  summarize(total = n(),
            TotalDeaths=sum(Deaths))

wiki_model <- glm(Deaths ~ Structures + AcresBurned + Month + Year + HumanCaused, 
                  data=wiki_fire)

wiki_fire$PredictedDeaths <- predict(wiki_model)

export_me(wiki_fire, "q6-plot.csv")



# Q7 Sampling bias utilizing a simulated dataset
bias <- read_me("bias.csv")  
z_score <- function(df,x){
  df1 <- df |>
    summarize(
      pop_mean <- mean({{x}}, na.rm=TRUE),
      pop_sd <- sd({{x}}, na.rm=TRUE)) |>
        rename(Mean = 1, Sd = 2) 
  df <- df |>
    mutate(ZScore = ({{x}} - df1$Mean)/ df1$Sd)
  return(df)
}
#sd = 2.311 mean=3.21 
# plotted bias histogram to verify Poisson distribution
bias_mod1 <- z_score(bias, TotalTimesInventoried)

# simulate poisson distribution 280 total, mean of 3.2
set.seed(331)
sim <- data.frame(Simulated = rpois(280,3.2)) 
sim_mod1 <- z_score(sim,Simulated)

# simulated zscore dataset is slightly right skewed, project dataset is heavily right skewed
# simulated zscore dataset has no values over ~3 while project dataset has values near 4
# radius is built on times inventoried
# color will be built on z-score
# project dataset, if z-score < -0.5 they get green
# if z-score > 3 they get red
# use of binning 3
bias_mod2 <- bias_mod1 |>
  mutate(Color = case_when(
                           ZScore < -0.5 ~ "Green",
                           ZScore > 2.75 ~ "Red",
                           TRUE ~ "Blue"
                           ))
export_me(bias_mod2, "q7-map.csv")

# need this for .docx render
bias_hist <- bias_mod1 |>
  select(TotalTimesInventoried, ZScore) |>
  rename(Count = TotalTimesInventoried) |>
  mutate(Dataset = "Tree") 

sim_hist <- sim_mod1 |>
  rename(Count = Simulated) |>
  mutate(Dataset = "Simulated")
comp_hist <- bind_rows(bias_hist,sim_hist)
# export 
export_me(comp_hist, "q7-docx.csv")
