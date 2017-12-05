
# Featurize all images


LABELLED_FEATURIZED_DATA <- "data/labelled_knots_featurized_resnet18.Rds"
UNLABELLED_FEATURIZED_DATA <- "data/unlabelled_knots_featurized_resnet18.Rds"

LABELLED_IMAGE_DIR <- "e:/ml_data/wood_knots/knot_images_png"
UNLABELLED_IMAGE_DIR <- "e:/ml_data/WOOD/unlabelled_cropped_png"

LABELS_FILE <- "names.txt"
PSEUDOLABELS_FILE <- "data/unlabelled_knot_info.csv" # We'll pretend these come from our labellers


# I have a beta version that capitalized the model name. This should (?) work for other folks.
DNN_MODEL <- if ("Microsoft R Server version 9.2.0.2731 (2017-07-26 06:17:26 UTC)" == Revo.version$version.string){
  "Resnet18"
} else {
  "resnet18"
}


featurize_directory <- function(dir){
  pwd <- setwd(dir)
  knot_info <- data.frame(path = list.files(pattern="*.png"), stringsAsFactors=FALSE)
  
  image_features <- rxFeaturize(data = knot_info,
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

# Note: be sure the file name has not been converted to a factor! If it has, you get an error like this:
# Exception: 'Source column 'path' has invalid type ('Key<U4, 0-595>'): Expected Text type.

if( file.exists(UNLABELLED_FEATURIZED_DATA)){
  unlabelled_knot_data_df <- readRDS(UNLABELLED_FEATURIZED_DATA)
} else {
  unlabelled_knot_data_df <- featurize_directory(UNLABELLED_IMAGE_DIR)
  saveRDS(unlabelled_knot_data_df, UNLABELLED_FEATURIZED_DATA)
}

if( file.exists(LABELLED_FEATURIZED_DATA)){
  labelled_knot_data_df <- readRDS(LABELLED_FEATURIZED_DATA)
} else {
  labelled_knot_data_df <- featurize_directory(LABELLED_IMAGE_DIR)
  
  # Add labels to labelled dataset
  labels <- read.table(LABELS_FILE, header=FALSE, sep=" ", stringsAsFactors=FALSE)[1:2]
  names(labels) <- c("path", "knot_class")
  labels$path <- gsub("ppm$", "png", labels$path)
  rownames(labels) <- labels$path
  
  labelled_knot_data_df$knot_class <- labels[labelled_knot_data_df$path, "knot_class"]
  labelled_knot_data_df <- labelled_knot_data_df[labelled_knot_data_df$knot_class %in% KNOT_CLASSES,]
  labelled_knot_data_df$knot_class <- factor(as.character(labelled_knot_data_df$knot_class), levels=KNOT_CLASSES)
  
  saveRDS(labelled_knot_data_df, LABELLED_FEATURIZED_DATA)
}

