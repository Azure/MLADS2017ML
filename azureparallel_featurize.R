## This script featurizes a large number of images. 
## We assume you have run through azureparallel_setup.R and you have worker machines in your cluster.

## Where is the data, on this machine?
IMAGE_DIR <- "E:\\Projects\\MLADS2017ML\\faces"
IMAGE_DIR <- "E:\\Projects\\MLADS2017ML\\faces_small"

# I have a beta version that capitalized the model name. This should (?) work for other folks.
DNN_MODEL <- if ("Microsoft R Server version 9.2.0.2731 (2017-07-26 06:17:26 UTC)" == Revo.version$version.string){
  "Resnet18"
} else {
  "resnet18"
}

## Featurize the images, but do it on the batch cluster.
## This makes sense if the featurization is processing-bound.
##
## If the process was data-bound, we would use outData rxDataSource to avoid this machine
## becoming a bottleneck for the returned data. 

featurize_directory <- function(dir){
  pwd <- setwd(dir)
  
  # Note: be sure the file name has not been converted to a factor! If it has, you get an error like this:
  # Exception: 'Source column 'path' has invalid type ('Key<U4, 0-595>'): Expected Text type.
  files_info = data.frame(path = list.files(pattern="*.jpg"), stringsAsFactors=FALSE)
  
  image_features <- rxFeaturize(data = files_info,
                                mlTransforms = list(loadImage(vars = list(Image = "path")),
                                                    resizeImage(vars = list(Features = "Image"), 
                                                                width = 224, height = 224, 
                                                                resizingOption = "IsoPad"),
                                                    extractPixels(vars = "Features"),
                                                    featurizeImage(var = "Features", 
                                                                   dnnModel = DNN_MODEL)),
                                mlTransformVars = c("path"),
                                reportProgress=1)
  
  setwd(pwd)
  image_features
}

pixelize_directory <- function(dir){
  pwd <- setwd(dir)
  
  # Note: be sure the file name has not been converted to a factor! If it has, you get an error like this:
  # Exception: 'Source column 'path' has invalid type ('Key<U4, 0-595>'): Expected Text type.
  files_info = data.frame(path = list.files(pattern="*.jpg"), stringsAsFactors=FALSE)
  
  image_features <- rxFeaturize(data = files_info,
                                mlTransforms = list(loadImage(vars = list(Image = "path")),
                                                    resizeImage(vars = list(Features = "Image"), 
                                                                width = 224, height = 224, 
                                                                resizingOption = "IsoPad"),
                                                    extractPixels(vars = "Features")
                                                    ),
                                mlTransformVars = c("path"),
                                reportProgress=1)
  
  setwd(pwd)
  image_features
}

batch_directory <- function(dir){
  pwd <- setwd(dir)
  
  # Note: be sure the file name has not been converted to a factor! If it has, you get an error like this:
  # Exception: 'Source column 'path' has invalid type ('Key<U4, 0-595>'): Expected Text type.
  files_info = data.frame(path = list.files(pattern="*.jpg"), stringsAsFactors=FALSE)

  # do this locally, it's fast
  image_pixels <- rxFeaturize(data = files_info,
                                mlTransforms = list(loadImage(vars = list(Image = "path")),
                                                    resizeImage(vars = list(Features = "Image"), 
                                                                width = 224, height = 224, 
                                                                resizingOption = "IsoPad"),
                                                    extractPixels(vars = "Features")
                                                    ),
                                mlTransformVars = c("path"),
                                reportProgress=1)
  # i'm only getting 5000 columns
  print(dim(image_pixels))
  
  # parallelize this
  image_features <- rxFeaturize(data = image_pixels,
                                mlTransforms = list(featurizeImage(var = "Features", dnnModel = DNN_MODEL)),
                                mlTransformVars = c("Features"),
                                reportProgress=1)
  
  setwd(pwd)
  image_features
}

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
}

##########################################################################################
# Make labels: We'll get the name of the person from the file name, and that is our label. 
origdir <- setwd(IMAGE_DIR)
files_info = data.frame(path = list.files(pattern = "*.jpg"), stringsAsFactors=FALSE)
files_info$fname <- sapply(strsplit(files_info$path, ".", fixed=TRUE), function(l) l[1])
# all elements of list but last are the person's name
files_info$pname <- sapply(strsplit(files_info$fname, "_", fixed=TRUE), 
                           function(l) paste(l[1:(length(l)-1)], collapse=" "))
files_info$imnum <- sapply(strsplit(files_info$fname, "_", fixed=TRUE), 
                           function(l) as.integer(l[length(l)]));

# Use file #1 as test instance, ...
testset <- files_info[files_info$imnum == 1, ];
trainset <- files_info[files_info$imnum > 1, ];
# but only if there is a file #2 and up to use for training
testset <- testset[ testset$pname %in% unique(trainset$pname), ]

# make the classes factors
trainset$pname <- as.factor(trainset$pname);
testset$pname <- as.factor(testset$pname);

BLOB_URL_BASE = "https://storage4tomasbatch.blob.core.windows.net/tutorial";

###########################################################################################
library(AzureSMR)
####


## list blob contents
blob_info <- azureBlobLS(azureActiveContext = NULL, 
                         directory = "faces_small", 
                         recursive = FALSE, 
                         storageAccount = "storage4tomasbatch",
                         storageKey = "WpJqUKKq+8dgOGIXNlubRVrLu6vdNArNW9sE+cAGdwss1ETSb3P9ihjcSbFBQitAMs7RX/avXtGAYRORhuhHZA==", 
                         container = "tutorial", 
                         resourceGroup = "FTK", 
                         verbose = FALSE)

# yes, I'm rotating the keys after the tutorial 

blob_info$url <- paste(BLOB_URL_BASE, sep='', blob_info$name)


###########################################################################################
## Featurize the images
face_data_df <- featurize_directory(IMAGE_DIR)
# takes 20s /108 images
# would take ~2700s on the full directory

azure_pixels_df <- pixelize_directory(IMAGE_DIR)# interestingly, only sends 5000 featuresout!
# takes <1 s

## so the hard part really is running the DNN
## let's try to separate the two pipelines
image_features <- batch_blob_directory(IMAGE_DIR)



############ do it the AzurePArallel way
BATCH_SIZE = 27;
NO_BATCHES = ceiling(nrow(blob_info)/BATCH_SIZE);
setVerbose(TRUE)

results <- foreach(i=1:NO_BATCHES) %dopar% {
  N = nrow(blob_info);
  fromRow = (i-1)*BATCH_SIZE+1;
  toRow = min(i*BATCH_SIZE, N);
  parallel_kernel(blob_info[fromRow:toRow,])
}

# clean up result



