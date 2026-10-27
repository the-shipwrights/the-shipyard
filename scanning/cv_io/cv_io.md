# Computer Vision Input & Output
Construct a parser that will take in CV input, and have the capacity to output a *Valid* Boat in 99% of cases, even if given near-faulty CV input. (See [boat.py](../boat.py)). 

## Problem specification
A CV model will receive images of boats built of wooden blocks, where each block has a symbol on it which represents its **piece type**. In CV context, these are known as _classes_ and are given by an integer value. These correspond directly to the name of the class, for instance: `name: hull <-> class: 2`. The CV model will output a list of detected _classes_, as well as a more thorough list of where these classes are located (their bounding box of x0, x1, y0, y1) and their confidence intervals. You can see an example of this 
[output here](real-valid.md) with its [corresponding image here](real-valid-labeled.jpg) and [original image](real-valid-original.jpg)


### 0. Count pieces by type. Prune collisions & illegal duplicates
Count the number of pieces first. 
- An empty prediction should return early. 
- A prediction without hull pieces should return early. hull pieces are the following: `hull-stern`, `hull-sec`, `hull-bow`.  

Any pieces that are nearly similar in position should be pruned with variable accuracy that should be adjustable inside of the script. Prioritize pieces with higher confidence rating. Default to 5px difference in bounding box position to start with. 

Multiple Bow & Stern pieces are not allowed to exist. Find the stern piece closest to `(max(y0, y1), min(x0, x1))`, other stern pieces should be removed. Same for Bow pieces: Find the bow piece closest to `(max(y0, y1), max(x0, x1))`, and remove others. 

### 1. Conform remainder to Uniform Grid
Find the __average__ x-distance of nearby pairs of hull pieces. So that would be pairs (0,1), (1,2), (2,3), where they are ordered after their x0. Use this as a unit of measurement for the grid. 

find the __naive__ y-distance of a hull piece and the nearest non-hull piece (the chosen hull piece has to be the one closest to a non-hull piece, so one has to calculate this distance).

#### 1.1. Laying out hull pieces
Create a grid where hull pieces are laid out on `cell[x:n,y:0]`. hull pieces must be laid on __even__ x-idx. Hull bow pieces must be to the RIGHT 

At this stage, one cannot overwrite a grid cell, if a cell is already occupied, skip its placement. (cheap solution)
- a non-cheap solution would attept to consolidate collisions. 

#### 1.2. Laying out Cabins 
When all hull pieces have been put on the grid, move on to cabins. 
- Cabins must be on y=1 slice. 
- Check how many multiples of x-distance/2 the cabin x0 is. This multiple determines its x-idx. 

#### 1.3. Laying out Accessories & Big Cabins. 
when all cabins are dealt with, move on to accessories & Big Cabins. 
- Accessories can be on y=1 or y=2. 
- Check how many multiples of x-distance/2 the accessory is to determine x-idx (floor)
- Check hom many multiples of y-distance the accessory is to determine y-idx. (floor)

By the end of this, you should have a uniform grid with boat pieces occupying unique cells. 

### 2. Clean-up: Applying Gravity & Cropping the Grid  
If a filled cell at y=2 has a non-filled cell under it, move it down. This removes accidental floating pieces.  

Crop the grid to only span the idx range of the hull pieces. so if a cabin would be at x=5, but the last hull piece is at x=4, it will be cropped out. 

### 3. Structural Integrity Check 
A Boat is structurally sound if it fulfills the following criteria:
1. Hull sections must be at the bottom of the grid. (should be guaranteed if step 1 is executed correctly)
2. No disjunct hulls (i.e, if a hull piece exists at x:0 and the nearest next one is at x:4, it is disjunct, if there was a hull piece at x:2, it wouldn't be disjunct)
3. No cabins directly above accessories
4. No cabins floating on the edge of hull (cabin's nearest hull+-1), or floating mid-air (cell below is empty and not x:0), or at x:0.
5. No accessories floating mid-air. 

If criteria are unfulfilled, initiate a "forgiving reconstruction", where input is reinterpreted to produce a valid boat. 

#### 3.1 Forgiving Reconstruction
for each Criteria: 
1. Abort forgiving reconstruction and give an error message telling host to redo the prediction step. 
2. Fill in disjunct hulls where a hull piece is missing
3. Remove accessory below a cabin and move the cabin in its place.
4. For each invalid cabin, select the cabin & all filled pieces above it that are on the same x slice as itself.  Move cabin & any filled cell directly above it to a neighbouring non-filled set of cells on the same y-slice that is directly above a hull or between two hulls. 
  4.1. If this is not possible, remove the pieces above the cabin and try again. 
  4.2. If this is not possible, remove the cabin.
5. remove accessory and print a warning.   

### 4. Return a `Boat` 
Parser should be able to return a boat, allowing it to be submitted to the boat database.
