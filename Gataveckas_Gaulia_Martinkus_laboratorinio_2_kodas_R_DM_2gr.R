## ---- include=FALSE----------------------------------------------------------------------------------------
knitr::opts_chunk$set(warning=FALSE,message=FALSE)


## ----------------------------------------------------------------------------------------------------------
library(tidyverse)
library(car)
library(janitor)
x <- read_csv("life.csv") %>% clean_names()


## ----------------------------------------------------------------------------------------------------------
set.seed(150)
transform_1<- function(x) {
  x %>%
  group_by(country) %>%
  fill(everything(), .direction = "up") %>%
  dplyr::select(-c(1, 3), -population, -percentage_expenditure) %>%
  drop_na() %>%
  ungroup()
}

x <- transform_1(x)

x_1 <- x %>% filter(year == max(year)) %>% select(-2)
countries <- x_1$country
x_1 <- x_1 %>% select(-1)

# atskiri duomenys, patikrinti kaip gautas galutinis modelis prognozuoja reikšmes
x_predict <- x %>% filter(year != max(year)) %>% slice_sample(n=10) %>% select(-c(1,2)) 


# kaikurių kovariančių priklausomybę nėra tiesinė
x_1 %>% pivot_longer(-1) %>% ggplot(aes(x=value,y=life_expectancy)) + facet_wrap(vars(name),scales="free") + geom_point() + geom_smooth(method="lm") + theme_minimal()

model <- lm(life_expectancy ~ ., data = x_1)
crPlots(model)


## ----------------------------------------------------------------------------------------------------------
transform_2 <- function(x) {
    x %>% 
    mutate(gdp = log(gdp),
    infant_deaths = log(infant_deaths + 1),
    measles = log(measles + 1),
    under_five_deaths = log(under_five_deaths + 1)
  )
}

# transformuojamos kaikurios kovariantės
x_2 <- transform_2(x_1)
x_predict <- transform_2(x_predict)


# Kintamųjų tiesinis ryšys patikrinamas dar kartą
x_2 %>% pivot_longer(-1) %>% ggplot(aes(x=value,y=life_expectancy)) + facet_wrap(vars(name),scales="free") + geom_point() + geom_smooth(method="lm") + theme_minimal()


write_csv(x_2, "life_modified.csv")

# Sukuriamas modelis
model <- lm(life_expectancy ~ ., data = x_2)


## ----------------------------------------------------------------------------------------------------------
# Tikrinamas liekanų normalumas, homoskadiškumas, liekanų nepriklausomumas, išskirtys
plot(model)
plot(cooks.distance(model))
plot(hatvalues(model))

outliers <- c(121,147,44,4)

# patikrinu pagal kokį kintamajį išsiskiria šios reikšmės
for (i in outliers) {
  for (j in names(x_2)) {
    val <- ecdf(x_2[[j]])(x_2[i,j]) 
    if (val > 0.95 || val < 0.05) {
      print(paste(i,countries[i],j,val))
    }
  }
}

x_3 <- x_2[-outliers,]
write_csv(x_3,"life_modified_no_outliers.csv")

model <- lm(life_expectancy ~ ., data = x_3)
model_outliers <- lm(life_expectancy ~ ., data=x_2)


# Liekanų normalumo testas
shapiro.test(residuals(model))


# Homoskedastiškumo testas
library(lmtest)
bptest(model)


## ----------------------------------------------------------------------------------------------------------
crPlots(model)
avPlots(model)


## ----------------------------------------------------------------------------------------------------------
anova(model) # Tikrinama hipotezė H0: beta_1 = beta_2 = ... = 0


## ----------------------------------------------------------------------------------------------------------
# Požinksninė regresija
library(RcmdrMisc)
model_2 <- stepwise(model,direction = "forward/backward")
model_outliers_2 <- stepwise(model_outliers)


## ----------------------------------------------------------------------------------------------------------
# Pastebimas stiprus koeficientų reikšmių skirtumas tarp modelio su išskirtimis ir be
(coef(model_2) - coef(model_outliers_2)) / coef(model_2)

# Koeficientai
summary(model_2) 
  # Visų koeficientų interpretacija paprasta,
  # nes pažingsnine regresija neišrinkti transformuoti kintamieji
library(lm.beta)
# Standartizuoti koeficientai
lm.beta(model_2)

# Pasikliovimo interalai
confint(model_2)

# Kovariancių įtaka vizualizuota
library(effects)
plot(predictorEffects(model_2))


## ----------------------------------------------------------------------------------------------------------
vars <- dplyr::select(x_2, c(adult_mortality, hepatitis_b, total_expenditure,
  hiv_aids, income_composition_of_resources, life_expectancy))

#library(psych)
#corr.test(vars)

#dalinės koreliacijos
library(ppcor)
pcor(vars)$estimate

# Variance inflation factor
vif(model_2)


## ----------------------------------------------------------------------------------------------------------

summary(model_2) 
  # R-squared = 0.925
  # Adj R-squared = 0.922

plot_predictions <- function(x,y) {
  predictions <- predict(x,newdata = y, interval = "prediction")
  predictions <- as_tibble(predictions) %>% mutate(n = 1:nrow(predictions))

  
  predictions_points <- y %>%
  mutate(pred = predictions) %>% 
  unnest(pred) %>%
  dplyr::select(1,last_col(3),last_col(2),last_col(1),last_col(0)) %>%
  pivot_longer(c(1,2))
  

  ggplot(predictions) + 
  geom_linerange(aes(x=n,ymin=lwr,ymax=upr)) + 
  geom_point(data=predictions_points,aes(x=n,y=value,color=name),size = 4) + 
  scale_x_discrete("Observation") +
  scale_y_continuous("Life Expectancy") + 
  theme_minimal(base_size = 16) + 
  scale_color_brewer("",palette = "Set1") 
}

# Atliekamos kelios pavyzdinės prognozės
plot_predictions(model_2,x_predict)

