## This script featurizes a large number of images. 
## We assume you have run through azureparallel_setup.R and you have worker machines in your cluster.

## Where is the data, on this machine?
IMAGE_DIR <- "E:\\Projects\\MLADS2017ML\\faces"

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

batch_featurize_directory <- function(dir){
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
                                mlTransformVars = c("path"))
  
  setwd(pwd)
  image_features
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

###########################################################################################
## Featurize the images
face_data_df <- batch_featurize_directory(IMAGE_DIR)
