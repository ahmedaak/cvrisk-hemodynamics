# CVrisk-hemodynamics

This repository contains the image processing code for the research project "The association between vascular risk factors and cerebral perfusion measured using resting-state functional MRI", which is part of the [Berlin Long-term Observation of Vascular Events (BeLOVE) study](https://doi.org/10.1136/bmjopen-2023-076415). 
Link to preregistration protocol: **ADD HERE**

## Requirements 
- Analysis of Functional NeuroImages (AFNI) version 23.3.02
- FMRIB Software Library (FSL) version 6.0.6.4
- Advanced Normalization Tools (ANTs) version 2.4.3
- rapidtide version 2.6.5

## Usage

###  Directory structure

Before processing, the data should be organized in BIDS format:

		1.	Data folder (can be named anything)
		1.1.	Subject folder(s) (“sub-XXX”)
		1.1.1.		Folder with T1-MPRAGE and FLAIR ("anat")
		1.1.2.		Folder with fMRI ("func")
		

### Structural processing script

#### Running the pipeline

The script is run by changing to the directory where the script is saved and typing:

```
./BLV_struct.sh <PATH TO DATA FOLDER> <PATH TO TEMPLATE FOLDER>
```

Where `PATH TO DATA FOLDER` is the absolute path to the data folder (see 1.1. above). The `PATH TO TEMPLATE FOLDER` must also be specified. This folder is located within the folder where the script is found. 
NB: Do not add a trailing forward slash to the paths (i.e. path/to/data NOT path/to/data/). 

An example:

```
./BLV_struct.sh khalila/belove_pts khalila/BLV_struct/TEMPLATES
```

#### Outputs

After the script runs successfully, the directory structure should look as follows:

		1.	Data folder (can be named anything)
		1.1.	Subject folder(s) (“sub-XXX”)
		1.1.1.		Folder with T1-MPRAGE and FLAIR ("anat")
		1.1.1.1.		Processing folder ("proc")
		1.1.1.1.1.			Quality control folder ("QC")
		1.1.1.1.2.			Folder with results of registrations including transformation matrices ("reg")
		1.1.1.1.3.			Folder with tissue-type segmentations and regional segmentation based on Harvard-Oxford atlas ("output")
		1.1.1.1.4.			Folder with cortical thickness results ("CortThick")
		1.1.1.1.5.			Folder with brain-extracted T1-MPRAGE ("brain_ext")

### Functional processing script

#### Running the pipeline

The script is run by changing to the directory where the script is saved and typing:

```
./BLV_func.sh <PATH TO DATA FOLDER> <PATH TO TEMPLATE FOLDER> 
```

Where `PATH TO DATA FOLDER` is the absolute path to the data folder (see 1.1. above). The `PATH TO TEMPLATE FOLDER` must also be specified. This folder is located within the folder where the script is found. 
NB: Do not add a trailing forward slash to the paths (i.e. path/to/data NOT path/to/data/). 

An example:

```
./BLV_func.sh khalila/belove_pts khalila/BLV_struct/TEMPLATES 
```

#### Outputs

After the script runs successfully, the directory structure should look as follows:

		1.	Data folder (can be named anything)
		1.1.	Subject folder(s) (“sub-XXX”)
		1.1.2.		Folder with fMRI ("func")
		1.1.2.1.		Processing folder ("proc")
		1.1.2.1.1.			Folder with results of rapidtide analysis including BOLD delay and CoV maps ("BOLD_DELAY")
		1.1.2.1.2.			Folder with results of registration including transformation matrices ("reg")
		1.1.2.1.3.			Folder with quality control metrics ("QC")

### Voxelwise GLM script 

#### Prerequisites

Before running this script, create a folder called "glm" in the Data folder (see folder 1.2. below). In this folder, place the contrasts and design matrix files required by FSL *randomise*. 

#### Running the pipeline

The script is run by changing to the directory where the script is saved and typing:

```
./BLV_glm.sh <PATH TO DATA FOLDER> <PATH TO TEMPLATE FOLDER> 
```

Where `PATH TO DATA FOLDER` is the absolute path to the data folder (see 1.1. above). The `PATH TO TEMPLATE FOLDER` must also be specified. This folder is located within the folder where the script is found. 
NB: Do not add a trailing forward slash to the paths (i.e. path/to/data NOT path/to/data/). 

An example:

```
./BLV_glm.sh khalila/belove_pts khalila/BLV_struct/TEMPLATES 
```

#### Outputs

After the script runs successfully, the directory structure should look as follows:

		1.	Data folder (can be named anything)
        1.2. Folder containing GLM results including output of *randomise* ("glm")
		1.1.	Subject folder(s) (“sub-XXX”)
		1.1.2.		Folder with fMRI ("func")
		1.1.2.1.		Script extracts BOLD delay and CoV values regions defined by the Harvard-Oxford and Hammersmith atlases and saves the output as text files in "proc"
		1.1.2.1.1.			Script adds registered BOLD delay and CoV maps (both to T1 and MNI) to the "BOLD_DELAY" folder 

## Code Authors 
- Ahmed Khalil, MD PhD – Center for Stroke Research Berlin, Charité Universitaetsmedizin Berlin - ahmed-abdelrahim.khalil@charite.de

- Ralf Mekle, PhD – Center for Stroke Research Berlin, Charité Universitaetsmedizin Berlin

## License
This code is available under the MIT license. 
