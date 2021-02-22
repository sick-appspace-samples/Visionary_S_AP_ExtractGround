## Visionary_S_AP_ExtractGround
Extract a pointcloud only containing the ground surface and small things on it

### Description
This App searches for flat regions in the Z image and assumes the biggest flat region is the ground.
The ground part of the image will be transfered to a pointcloud and a plane will be fitted to it.

### How to run
Start by running the app (F5) or debugging (F7+F10).
Set a breakpoint on the first row inside the main function to debug step-by-step.
See the results in the viewers on the DevicePage.

### Topics
View, Visionary, Stereo, Sample, SICK-AppSpace
