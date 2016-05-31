#Avatars that were decteced between Jan, 2006 to Jan, 2008 are used to train the model. 
#We want to predict if an avatar will appear again in the future at different threshold.
#The future time was binned in one week interval for 7 weeks. The prediction is to find out whether or not
# a user will be seen logged into the game within a defined time frame. 
# The output of this script is AUC and feature importance

library(stringr)
library(readr)
library(plyr)
library(reshape2)
library(dplyr)
library(tidyr)
library(h2o)
h2o.init(nthreads=-1, max_mem_size="4G")
h2o.removeAll()

df <- read.csv("user_eng_quarter")
label <- read.csv('label')
df <- df[df$mon != '2005-10-01 00:00:00', ]
user_duration <- read.csv('user_duration')
df$time <- sapply(df$mon, function(x){substr(x, 1, 7)})
label$week <- sapply(label$wk,function(x){substr(x, 6, 10)})
label$wk <- NULL
df$mon <- NULL

# reshape the table to make it in wide format
df1 <- df %>%
  gather(Var, val, daily_eng:density_mon) %>%
  unite(Var1, Var, time) %>%
  spread(Var1, val, fill = 0)

label <- label %>%
  gather(Var, val, label) %>%
  unite(Var1, Var, week) %>%
  spread(Var1, val, fill = 0)

index <- apply(label[, -1] > 0, 1,which.max)
index <- index + 1
label$start <- index

for (i in 1:nrow(label)){
  idx <- label[i,11] + 1
  label[i, idx:10] = 1
}

label$start <- NULL

# user stays more than 30 days
user_group <- user_duration[user_duration$tot_day > 30, ]

group <- merge(user_group, df1, by ='avatar_id', all.x = TRUE)
group_all <- merge(group, label, by = 'avatar_id')

group_all <- data.frame(group_all)[, c(1, 5:13, 18:26, 31:39)]

write.csv(group_all, file = "train_group_1.csv", row.names = F)

trainhex <- h2o.importFile(path = normalizePath("train_group_1.csv"))
features <- names(trainhex[, 2:19])

metric_evaluate <- c()
feature_imp <- data.frame()

# build classifier for each time bin
for (i in 20:28){
  trainhex[, i] <- as.factor(trainhex[, i])
  target <- names(trainhex[, i])
  
  model_fit<- h2o.gbm(x = features, 
                      y = target,
                      nfolds = 3,
                      ntrees = 10,
                      learn_rate = 0.5,
                      max_depth = 2,
                      training_frame = trainhex)
  
  dat <- model_fit@model$variable_importances[1:3,]
  feature_imp <- rbind(feature_imp, dat)
  
  metric_evaluate[i-19] <- model_fit@model$cross_validation_metrics@metrics$AUC
}

metric_evaluate
head(feature_imp)
