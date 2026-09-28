# Computer Vision Input & Output
Here you can find images & related outputs to those images. Because the model i used to detect these sucks ass, i had to edit them slightly so they better represent the image. Good luck! 

**NOTE:** This data currently DOES NOT take orientation into account! Further more, confidence ratings for detections are absolutely terrible. All will be fixed once I retrain a model with new & improved symbols :]

## Problem specification
A CV model will receive images of boats built of wooden blocks, where each block has a symbol on it which represents its **piece type**. In CV context, these are known as _classes_ and are given by an integer value. These correspond directly to the name of the class, for instance: `name: hull <-> class: 2`. The CV model will output a list of detected _classes_, as well as a more thorough list of where these classes are located and their confidence intervals. You can see an example of this 
[output here](valid-easy-output) with its [corresponding image here](valid-easy.png)

please write more here.
