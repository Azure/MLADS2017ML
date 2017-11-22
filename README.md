# Image classification workshop using featurization and active learning

## Image Featurization

The use case (labeling knots in lumber) and concepts of image featurization are described in our blog post entitled [Featurizing Images: the shallow end of deep learning](blog.revolutionanalytics.com/2017/09/wood-knots.html). Briefly, a pre-trained DNN image classification model is used to generate features for a set of images, which are then used to train a custom classifier. This is the simplest form of transfer learning, where the values leading into the last layer of the network are used as features, and we do not use backpropagation on the original DNN model.

## Active Learning

[Active learning](https://en.wikipedia.org/wiki/Active_learning) helps us address the common situation where we have large amounts of data, but labeling this data is expensive. By using a preliminary model to select the cases that are likely to be most useful for improving the model, and iterating through several cycles of model training and case selection, we can often build a model using a much smaller training set (thus requiring less labeling effort) than we would otherwise need.

### Image Labeling website

Our [label collection website](woodknotlabeler.azurewebsites.net) has instructions for how to recognize the different classes of knots, a page where you can practice, and a page where workshop participants can enter their labels for the images chosen for the first round of active learning.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
