# Forked from https://www.kaggle.com/benhamner/otto-group-product-classification-challenge/t-sne-visualization/code
# This script is for WoW user segmentation, use k-means to generate cluster of user group, then visualize it using t-SNE
# in a two dimentional space
setwd("/Users/yumingfang/wowah/WoWAH/")
install.packages('readr')
install.packages('Rtsne')
library(ggplot2)
library(readr)
library(Rtsne)
library(dplyr)
library(tidyr)

set.seed(1)

train <- read_csv("train_group.csv")
train <- train[, 1:19]
features <- train[, 2:19]
usercluster <- kmeans(features, centers = 5, nstart = 50)
train$cluster <- as.factor(usercluster$cluster)

center <- usercluster$centers
daily_time <- center[, 1:9]
daily_time <- as.data.frame(daily_time)
daily_time$cluster <- as.factor(c(1,2,3,4,5))
df <- daily_time %>%
  gather(time, value,daily_eng_2006.01:daily_eng_2008.01)
df$time <- as.factor(df$time)
df <- df[order(df$cluster),]

# generate plot of users' average gaming time in different cluster
ggplot(df, aes(x = time, y = value, group = cluster, colour=cluster))+
  geom_point()+
  geom_line()+
  scale_x_discrete(breaks = df$time, labels = rep(c('1','2','3','4','5','6','7','8','9'), 5))+
  xlab('Period')+
  ylab('Average gaming time per period')+
  ggtitle('User Segmentation')

tsne <- Rtsne(as.matrix(features), check_duplicates = FALSE, pca = FALSE, 
              perplexity = 30, theta = 0.5, dims = 2)

embedding <- as.data.frame(tsne$Y)
embedding$Class <- as.factor(usercluster$cluster)
table(embedding$Class)

# generate t-SNE 2D plot to visualize users' feature space
ggplot(embedding, aes(x=V1, y=V2, color=Class)) +
  geom_point(size=1.25) +
  guides(colour = guide_legend(override.aes = list(size=6))) +
  xlab("") + ylab("") +
  ggtitle("t-SNE 2D Segmentation of WoW User") +
  theme_light(base_size=20) +
  theme(strip.background = element_blank(),
        strip.text.x     = element_blank(),
        axis.text.x      = element_blank(),
        axis.text.y      = element_blank(),
        axis.ticks       = element_blank(),
        axis.line        = element_blank(),
        panel.border     = element_blank())

#ggsave("tsne_nopca.png", p, width=8, height=6, units="in")

