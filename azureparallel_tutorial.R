## This script featurizes a large number of images. 
## We assume you have run through azureparallel_setup.R and you have worker machines in your cluster.


##########################################################################################
#### Get the list of blobs to process
library(AzureSMR)

BLOB_URL_BASE = "https://storage4tomasbatch.blob.core.windows.net/tutorial/";

## list blob contents
blob_info <- azureListStorageBlobs(NULL, 
                                   storageAccount = "storage4tomasbatch",
                                   storageKey = "WpJqUKKq+8dgOGIXNlubRVrLu6vdNArNW9sE+cAGdwss1ETSb3P9ihjcSbFBQitAMs7RX/avXtGAYRORhuhHZA==", 
                                   container = "tutorial",
                                   # prefix = "faces_small")
                                   prefix = "faces_full") # replace with the full dataset


# preprocess the file names into class (person) names
blob_info$url <- paste(BLOB_URL_BASE, sep='', blob_info$name)
blob_info$fname <- sapply(strsplit(blob_info$name, '/'), function(l) {l[2]})
blob_info$bname <- sapply(strsplit(blob_info$fname, ".", fixed=TRUE), function(l) l[1])
blob_info$pname <- sapply(strsplit(blob_info$fname, "_", fixed=TRUE), 
                          function(l) paste(l[1:(length(l)-1)], collapse=" "))


##########################################################################################
# Parallel kernel for featurization
parallel_kernel <- function(blob_info) {
  
  library("MicrosoftML")
  
  image_features <- rxFeaturize(data = blob_info,
                                mlTransforms = list(loadImage(vars = list(Image = "url")),
                                                    resizeImage(vars = list(Features = "Image"),
                                                                width = 224, height = 224,
                                                                resizingOption = "IsoPad"),
                                                    extractPixels(vars = "Features"),
                                                    featurizeImage(var = "Features",
                                                                   dnnModel = "Resnet18")),
                                mlTransformVars = c("url"),
                                reportProgress=1)
  image_features
}

##########################################################################################
#### Run the parallel kernel

BATCH_SIZE = 14;                             # 27 is two tasks per node on small dataset
                                             # 14 is one tasks per node on large dataset
                                             # larger batch size for larger dataset will defray overhead
NO_BATCHES = ceiling(nrow(blob_info)/BATCH_SIZE);
setVerbose(TRUE)

#### local execution
start_time <- Sys.time()
results <- foreach(i=1:NO_BATCHES ) %do% {  # %do% is the serial version
  N = nrow(blob_info);
  fromRow = (i-1)*BATCH_SIZE+1;
  toRow = min(i*BATCH_SIZE, N);
  parallel_kernel(blob_info[fromRow:toRow,])
}
end_time <- Sys.time()
print(paste0("Ran for ", end_time - start_time, " seconds"))

#### cluster execution
start_time <- Sys.time()
results <- foreach(i=1:NO_BATCHES ) %dopar% {     # %dopar% invokes parallel backend (registered cluster)
  N = nrow(blob_info);
  fromRow = (i-1)*BATCH_SIZE+1;
  toRow = min(i*BATCH_SIZE, N);
  parallel_kernel(blob_info[fromRow:toRow,])
}
end_time <- Sys.time()
print(paste0("Ran for ", end_time - start_time, " seconds"))

## 108 images take 20 seconds on small cluster 
## 108 images take 27 seconds on large cluster 
## 5k images take 37 seconds on large cluster )


##########################################################################################
# clean up result: it's a list of outputs, one from each task, we need to rbind them
single_df <- Reduce(rbind, results)

# only URLs were processed, turn them into person names
blob_info$fname <- sapply(strsplit(blob_info$name, '/'), function(l) {l[2]})
blob_info$bname <- sapply(strsplit(blob_info$fname, ".", fixed=TRUE), function(l) l[1])
blob_info$pname <- sapply(strsplit(blob_info$fname, "_", fixed=TRUE), 
                          function(l) paste(l[1:(length(l)-1)], collapse=" "))

# TODO: save results as an Rds, if they are of the right form

#####################################################################################
# makes sense?
library(tidyr)
library(ggplot2)
library(magrittr)
features <- single_df %>% gather(featname, featval, -bname)        # plot features by file
plottable <- features[startsWith(features$featname, 'Feature'),];

(
  p <- ggplot(plottable, aes(featname, pname)) + 
    geom_tile(aes(fill = featval), colour = "white") +
    scale_fill_gradient(low = "white",high = "steelblue")
)



