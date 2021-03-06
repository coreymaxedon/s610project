library(tidyverse)
library(plyr)

# read in the data
table_2_1979 <- read.csv("table_2_1979.csv")
table_2_1980 <- read.csv("table_2_1980.csv")
table_3_1975 <- read.csv("table_3_1975.csv")
table_3_1978 <- read.csv("table_3_1978.csv")

# drop the first column because we don't need it 
table_2_1979 = table_2_1979[, -1]
table_2_1980 = table_2_1980[, -1]
table_3_1975 = table_3_1975[, -1]
table_3_1978 = table_3_1978[, -1]

# We have to convert the data into proportions from counts
divfun <- function(x) {
  x = as.matrix(x)
  ans = matrix(NA, nrow = dim(x)[1], ncol = dim(x)[2])
  for (i in 1:dim(x)[1]) {
    for (j in 1:dim(x)[2]) {
      ans[i, j] = x[i, j] / sum(x[ , j], na.rm = TRUE)
    }
  }
  return(ans)
}

table_2_1979 = divfun(table_2_1979)
table_2_1980 = divfun(table_2_1980)
table_3_1975 = divfun(table_3_1975)
table_3_1978 = divfun(table_3_1978)




#We will refer to this as model (1).


#' Generates four numbers between 0 and 1 and will act as the priors
#'
#' @return a list of four random numbers
simulate_parameters <- function() {
  names = c("qc1", "qh1", "qc2", "qh2")
  
  param = list(runif(1),
               runif(1),
               runif(1),
               runif(1))
  names(param) = names
  return(param)
}


#' The probability that j out of the s susceptibles in a household become infected
#' 
#' @param j number that become infected
#' @param s number of susceptibles
#' @param qc probability that a susceptible individual does not get infected from the community
#' @param qh probability that a susceptible individual does not get infected from their household
#' @param wjj the jth element of the diagonal of w
#' 
#' @return A number between 0 and 1, representing the probability of people infected in a household
model_1 <- function(j, s, qc, qh, wjj){
  return(choose(s, j) * wjj * (qc * qh^j)^(s - j))
}

#' Generate data from the model specified above
#'
#' @param qc probability that a susceptible individual does not get infected from the community
#' @param qh probability that a susceptible individual does not get infected from their household
#' @param m number of rows of the data
#' @param n number of columns of the data
#'
#' @return a matrix of generated data

data_gen <- function(qc, qh, m, n){
  
  # pre-allocate matrix
  d_star = matrix(NA, nrow = m, ncol = n)
  
  # make first row of matrix using w_{0s} = q_c^s
  d_star[1, ] = qc^(1:n)      # number infected out of s, paper says s = 0,1,2,...
  # but j/0 is na
  
  # create rest of the data 
  # we will work across the matrix rather than down the columns
  for (j in 2:(m-1)) {
    d_star[j, j-1]= wjj = 1 - sum(d_star[ , j-1], na.rm = TRUE) # create diagonal data point 
    # (when j = s)
    
    for (s in j:n) {
      # plug it in to the model_1 function to calculate the probability
      d_star[j,s] = model_1(j - 1, s, qc, qh, wjj)
    }
  }
  d_star[m, m-1] = 1 - sum(d_star[ , m-1], na.rm = TRUE)
  
  return(d_star)
}

#' Calculate the frobenious norm of a matrix
#'
#' @param A the matrix
#'
#' @return the frobenious norm
frobenious <- function(A){
  return(sqrt(sum(abs(A)^2, na.rm = TRUE)))
}

#' Calculating the distance specified above
#'
#' @param d1 The first data matrix (i.e. 1977-78 from table 2)
#' @param d2 The second data matrix (i.e. 1980-81 from table 2)
#' @param d_star1 The first matrix of generated data
#' @param d_star2 The second matrix of generated data
#'
#' @return
distance <- function(d1, d2, d_star1, d_star2){
  
  # calculate the two frobenious norms
  f1 = frobenious(d1 - d_star1)
  f2 = frobenious(d2 - d_star2)
  
  # this is the distance metric
  ans = 0.5 * (f1 + f2) 
  return(ans)
}


#' Generate an ABC sample
#'
#' @param epsilon The specified tolerance levels
#' @param d1 The first data matrix (i.e. 1977-78 from table 2)
#' @param d2 The second data matrix (i.e. 1980-81 from table 2)
#'
#' @return A prior sample that has 
generate_abc_sample <- function(epsilon, d1, d2){
  # get the dimensions for each dataframe
  dim_d1 = dim(d1)
  dim_d2 = dim(d2)
  
  # basic ABC stuff
  while(TRUE){
    # prior
    prior = simulate_parameters() 
    
    # generate data
    res1 = data_gen(qc = prior$qc1, qh = prior$qh1, m = dim_d1[1], n = dim_d1[2])
    res2 = data_gen(qc = prior$qc2, qh = prior$qh2, m = dim_d2[1], n = dim_d2[2])
    
    # calculate distance
    distance = distance(d1,
                        d2,
                        d_star1 = res1,
                        d_star2 = res2)
    
    # check against tolerance
    if(distance < epsilon){
      break
    }
  }
  return(do.call(rbind, prior))
}


# only uncomment and run if we figure out it's broken, it takes a while
# results = replicate(1000, generate_abc_sample(epsilon = 0.3,
#                                              d1 = table_2_1979,
#                                              d2 = table_2_1980))

# qc1 = results[1,,]
# qh1 = results[2,,]
# qc2 = results[3,,]
# qh2 = results[4,,]

# this comes from table 2
# res_df <- rbind(data.frame(year = 1977, qh = qh1, qc = qc1), 
#                 data.frame(year = 1980, qh = qh2, qc = qc2))



# write.csv(res_df, "results_3a.csv")

# load in the data that was saved from above
res_df <- read.csv("results_3a.csv")



res_df %>% 
  ggplot(aes(qh, qc, color = factor(year)))+
  geom_point(shape=1, stroke = 1.055)+
  scale_color_manual(values = c("red", "blue")) +
  theme_minimal()+
  scale_x_continuous(breaks = seq(0,1,0.2), limits = c(0,1))+
  scale_y_continuous(breaks = seq(0,1,0.2), limits = c(0,1))+
  labs(color = "Year")
