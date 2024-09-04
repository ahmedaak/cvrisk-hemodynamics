#!/usr/bin/env bash

# Performs  processing on resting-state functional MRI data
# Written by Ahmed Khalil for the Berlin Longterm Observation of Vascular Events Study (BeLOVE) study http://bit.ly/336kjS7 
# Edited by Ahmed Khalil in 02/2024 for the "Vascular risk factors and cerebral hemodynamics" substudy of BeLOVE

# do some preparatory steps
	# define data directory
	DATA_DIR=$1
	
	# define templates directory (for ANTS brain extraction, etc)
	TEMPLATES_DIR=$2
	
	
		if [ "$1" != "" ]; then
		:
		else
			echo "Please input the full path to the data directory"
			exit 1
		fi
		
	
	# define templates
	OASIS_TEMP=$TEMPLATES_DIR/OASIS/T_template0.nii.gz
	OASIS_TEMP_PRIOR=$TEMPLATES_DIR/OASIS/T_template0_BrainCerebellumProbabilityMask.nii.gz
	OASIS_MASK=$TEMPLATES_DIR/OASIS/T_template0_BrainCerebellumRegistrationMask.nii.gz
	MNI_1mm_TEMP=$TEMPLATES_DIR/MNI/MNI152_T1_1mm_brain.nii.gz
	MNI_2mm_TEMP=$TEMPLATES_DIR/MNI/MNI152_T1_2mm_brain.nii.gz
	MNI_1mm_MASK_reduced=$TEMPLATES_DIR/MNI/MNI152_T1_1mm_brain_mask_red.nii.gz # this is a mask of the MNI brain with the mask "reduced" so the first slice from the bottom is the first with cerebellar tissue 
	MNI_1mm_MASK=$TEMPLATES_DIR/MNI/MNI152_T1_1mm_brain_mask.nii.gz
	MNI_2mm_MASK=$TEMPLATES_DIR/MNI/MNI152_T1_2mm_brain_mask.nii.gz
	STRUCT_ATLAS=$TEMPLATES_DIR/MNI/MNI-maxprob-thr25-1mm.nii.gz
	VENOUS_SINUS_TEMP=$TEMPLATES_DIR/venous_sinus_template.nii.gz

	cd $DATA_DIR/
# loop through subjects
for i in sub-*

	do
	  echo $i
	
	# check if this patient's rsfMRI has already been processed - ******* if it is, delete the folder (DEV) ********
	#if [ -f "$DATA_DIR/$i/func/rest.pp.nii" ]
	#if [ -d "$SUBJECT_DIR_FUNC/proc" ]
	#then 
	#rm -r "$SUBJECT_DIR_FUNC/proc"
		#continue
	#fi 
		
	SUBJECT_DIR_FUNC=$DATA_DIR/$i/func
	SUBJECT_DIR_FUNC_PROC=$SUBJECT_DIR_FUNC/proc
	SUBJECT_DIR_STRUCT=$DATA_DIR/$i/anat/proc
	
	mkdir $SUBJECT_DIR_FUNC_PROC
	  # remove first ~10 seconds of data
	  V=$(grep -qi '"Manufacturer": "SIEMENS"' $SUBJECT_DIR_FUNC/${i}_task-rest_bold.json && echo 25 || echo 3)
	  3dcalc -a $SUBJECT_DIR_FUNC/${i}_task-rest_bold.nii.gz[$V..$] -expr 'a' -prefix $SUBJECT_DIR_FUNC_PROC/rest.tr.nii 

	  # Deoblique
	  3drefit -deoblique $SUBJECT_DIR_FUNC_PROC/rest.tr.nii

	  # Reorient into fsl friendly space (what AFNI calls RPI)
	  3dresample -orient RPI -inset $SUBJECT_DIR_FUNC_PROC/rest.tr.nii -prefix $SUBJECT_DIR_FUNC_PROC/rest.ro.nii

	  # Motion correct to average of timeseries
	  3dTstat -mean -prefix $SUBJECT_DIR_FUNC_PROC/rest.ro.mean.nii $SUBJECT_DIR_FUNC_PROC/rest.ro.nii
	  3dvolreg -Fourier -twopass -base $SUBJECT_DIR_FUNC_PROC/rest.ro.mean.nii -zpad 4 -prefix $SUBJECT_DIR_FUNC_PROC/rest.mc.nii -1Dfile $SUBJECT_DIR_FUNC_PROC/rest.mc.1D -maxdisp1D $SUBJECT_DIR_FUNC_PROC/rest.maxdisp.1D $SUBJECT_DIR_FUNC_PROC/rest.ro.nii

	  # Remove skull/edge detect - consider using SynthStrip https://surfer.nmr.mgh.harvard.edu/docs/synthstrip/ 
	  3dAutomask -prefix $SUBJECT_DIR_FUNC_PROC/rest.ro.mask.nii -dilate 1 $SUBJECT_DIR_FUNC_PROC/rest.mc.nii
	  3dcalc -a $SUBJECT_DIR_FUNC_PROC/rest.mc.nii -b $SUBJECT_DIR_FUNC_PROC/rest.ro.mask.nii -expr 'a*b' -prefix $SUBJECT_DIR_FUNC_PROC/rest.st.nii 

	  # Get example image for use in registration
	  fslroi $SUBJECT_DIR_FUNC_PROC/rest.st.nii $SUBJECT_DIR_FUNC_PROC/example_func 1 1

	  # Spatial smoothing
	  sigma=$(echo "scale=10;6/2.3548" | bc)
	  fslmaths $SUBJECT_DIR_FUNC_PROC/rest.st.nii -kernel gauss ${sigma} -fmean -mas $SUBJECT_DIR_FUNC_PROC/rest.ro.mask.nii $SUBJECT_DIR_FUNC_PROC/rest.ss.nii 

	  # Grandmean scaling
	  fslmaths $SUBJECT_DIR_FUNC_PROC/rest.ss.nii -ing 10000 $SUBJECT_DIR_FUNC_PROC/rest.gin.nii -odt float

	  # Create Mask
	  fslmaths $SUBJECT_DIR_FUNC_PROC/rest.gin.nii -Tmin -bin $SUBJECT_DIR_FUNC_PROC/rest.mask.nii -odt char
	  
	  # Register RS to T1
	  mkdir $SUBJECT_DIR_FUNC_PROC/reg
	  epi_reg --epi=$SUBJECT_DIR_FUNC_PROC/example_func.nii.gz --t1=$SUBJECT_DIR_STRUCT/t1_redfov.nii.gz --t1brain=$SUBJECT_DIR_STRUCT/output/t1_wholebrain.nii.gz --wmseg=$SUBJECT_DIR_STRUCT/output/t1_wm.nii.gz --out=$SUBJECT_DIR_FUNC_PROC/reg/rs2anat.nii.gz

	  # Register RS to MNI
	  antsApplyTransforms -d 3 -i $SUBJECT_DIR_FUNC_PROC/reg/rs2anat.nii.gz -r $MNI_1mm_TEMP -t $DATA_DIR/$i/anat/proc/reg/T1_mni1Warp.nii.gz -t $DATA_DIR/$i/anat/proc/reg/T1_mni0GenericAffine.mat -o $SUBJECT_DIR_FUNC_PROC/reg/rs2mni.nii.gz
	  
	  	# QUALITY CONTROL METRICS
		mkdir $SUBJECT_DIR_FUNC_PROC/QC
				# FD
				fsl_motion_outliers -i $SUBJECT_DIR_FUNC/${i}_task-rest_bold.nii.gz -o $SUBJECT_DIR_FUNC_PROC/QC/fd_conf -s $SUBJECT_DIR_FUNC_PROC/QC/fd.txt --fd --dummy=25
				
				# DVARS
				fsl_motion_outliers -i $SUBJECT_DIR_FUNC/${i}_task-rest_bold.nii.gz -o $SUBJECT_DIR_FUNC_PROC/QC/dvars_conf -s $SUBJECT_DIR_FUNC_PROC/QC/dvars.txt --dvars --dummy=25
				
				# Carpet plot
						
						# register tissue segmentation maps (in T1 space) to RS
						#antsApplyTransforms -d 3 -i $SUBJECT_DIR_STRUCT/output/t1_gm.nii.gz -r $SUBJECT_DIR_FUNC_PROC/example_func.nii.gz -t [ $SUBJECT_DIR_FUNC_PROC/reg/rs2anat0GenericAffine.mat, 1 ] -o $SUBJECT_DIR_FUNC_PROC/QC/t1_gm_rs.nii.gz -n NearestNeighbor
						flirt -applyxfm -init  $SUBJECT_DIR_FUNC_PROC/reg/rs2anat.mat -in $SUBJECT_DIR_STRUCT/output/t1_gm.nii.gz -ref $SUBJECT_DIR_FUNC_PROC/example_func.nii.gz -out $SUBJECT_DIR_FUNC_PROC/QC/t1_gm_rs.nii.gz -interp nearestneighbour
						
						#antsApplyTransforms -d 3 -i $SUBJECT_DIR_STRUCT/output/t1_wm.nii.gz -r $SUBJECT_DIR_FUNC_PROC/example_func.nii.gz -t [ $SUBJECT_DIR_FUNC_PROC/reg/rs2anat0GenericAffine.mat, 1 ] -o $SUBJECT_DIR_FUNC_PROC/QC/t1_wm_rs.nii.gz  -n NearestNeighbor
						flirt -applyxfm -init  $SUBJECT_DIR_FUNC_PROC/reg/rs2anat.mat -in $SUBJECT_DIR_STRUCT/output/t1_wm.nii.gz -ref $SUBJECT_DIR_FUNC_PROC/example_func.nii.gz -out $SUBJECT_DIR_FUNC_PROC/QC/t1_wm_rs.nii.gz -interp nearestneighbour

						#antsApplyTransforms -d 3 -i $SUBJECT_DIR_STRUCT/output/t1_csf.nii.gz -r $SUBJECT_DIR_FUNC_PROC/example_func.nii.gz -t [ $SUBJECT_DIR_FUNC_PROC/reg/rs2anat0GenericAffine.mat, 1 ] -o $SUBJECT_DIR_FUNC_PROC/QC/t1_csf_rs.nii.gz  -n NearestNeighbor
						flirt -applyxfm -init  $SUBJECT_DIR_FUNC_PROC/reg/rs2anat.mat -in $SUBJECT_DIR_STRUCT/output/t1_csf.nii.gz -ref $SUBJECT_DIR_FUNC_PROC/example_func.nii.gz -out $SUBJECT_DIR_FUNC_PROC/QC/t1_csf_rs.nii.gz -interp nearestneighbour

						# convert segmentation maps to byte format
						3dcalc -a $SUBJECT_DIR_FUNC_PROC/QC/t1_gm_rs.nii.gz -expr 'a' -datum byte -prefix $SUBJECT_DIR_FUNC_PROC/QC/t1_gm_rs_b.nii.gz
						3dcalc -a $SUBJECT_DIR_FUNC_PROC/QC/t1_wm_rs.nii.gz -expr 'a' -datum byte -prefix $SUBJECT_DIR_FUNC_PROC/QC/t1_wm_rs_b.nii.gz
						3dcalc -a $SUBJECT_DIR_FUNC_PROC/QC/t1_csf_rs.nii.gz -expr 'a' -datum byte -prefix $SUBJECT_DIR_FUNC_PROC/QC/t1_csf_rs_b.nii.gz
						
						# generate carpet plots
						3dGrayplot -mask $SUBJECT_DIR_FUNC_PROC/QC/t1_gm_rs_b.nii.gz -prefix $SUBJECT_DIR_FUNC_PROC/QC/carpet_plot_gm.png $SUBJECT_DIR_FUNC_PROC/rest.gin.nii.gz
						3dGrayplot -mask $SUBJECT_DIR_FUNC_PROC/QC/t1_wm_rs_b.nii.gz -prefix $SUBJECT_DIR_FUNC_PROC/QC/carpet_plot_wm.png $SUBJECT_DIR_FUNC_PROC/rest.gin.nii.gz
						3dGrayplot -mask $SUBJECT_DIR_FUNC_PROC/QC/t1_csf_rs_b.nii.gz -prefix $SUBJECT_DIR_FUNC_PROC/QC/carpet_plot_csf.png $SUBJECT_DIR_FUNC_PROC/rest.gin.nii.gz
				
				# tSNR
				3dTstat -tsnr -prefix $SUBJECT_DIR_FUNC_PROC/QC/tsnr.nii $SUBJECT_DIR_FUNC/${i}_task-rest_bold.nii.gz
				3dmaskdump -o $SUBJECT_DIR_FUNC_PROC/QC/tsnr.txt -mask $SUBJECT_DIR_FUNC_PROC/rest.mask.nii $SUBJECT_DIR_FUNC_PROC/QC/tsnr.nii
				
				# Outlier ratio
				3dToutcount -automask -fraction $SUBJECT_DIR_FUNC/${i}_task-rest_bold.nii.gz > $SUBJECT_DIR_FUNC_PROC/QC/outcount.txt
				
				# Quality index
				3dTqual -automask $SUBJECT_DIR_FUNC/${i}_task-rest_bold.nii.gz > $SUBJECT_DIR_FUNC_PROC/QC/qualind.txt
				
				
		# SECONDARY MOTION CORRECTION

				# Despiking and 6HMP regression with simultaneous temporal filtering
				3dDespike -prefix $SUBJECT_DIR_FUNC_PROC/rest.ds.nii.gz -NEW $SUBJECT_DIR_FUNC_PROC/rest.gin.nii.gz 
				3dTproject -input $SUBJECT_DIR_FUNC_PROC/rest.ds.nii.gz -prefix $SUBJECT_DIR_FUNC_PROC/rest.pp.nii.gz -ort $SUBJECT_DIR_FUNC_PROC/rest.mc.1D  -polort 0 -passband 0.01 0.15 -automask
				
				
		# BOLD DELAY CALCULATION
				mkdir $SUBJECT_DIR_FUNC_PROC/BOLD_DELAY
				# Register venous sinus template to RS (MNI to RS)
				antsRegistrationSyNQuick.sh -d 3 -f $SUBJECT_DIR_FUNC_PROC/example_func.nii.gz -m $MNI_1mm_TEMP -o $SUBJECT_DIR_FUNC_PROC/reg/mni2rs
				antsApplyTransforms -d 3 -i $VENOUS_SINUS_TEMP -r $SUBJECT_DIR_FUNC_PROC/example_func.nii.gz -o $SUBJECT_DIR_FUNC_PROC/BOLD_DELAY/venous_sinus_rs.nii.gz -t  $SUBJECT_DIR_FUNC_PROC/reg/mni2rs0GenericAffine.mat -t $SUBJECT_DIR_FUNC_PROC/reg/mni2rs1Warp.nii.gz -n NearestNeighbor
				
				# Extract venous sinus signal from RS data 
				fslmeants -i  $SUBJECT_DIR_FUNC_PROC/rest.pp.nii.gz -m $SUBJECT_DIR_FUNC_PROC/BOLD_DELAY/venous_sinus_rs.nii.gz -o $SUBJECT_DIR_FUNC_PROC/BOLD_DELAY/venous_sinus_ts.txt
				
				# Perform Time Shift Analysis 
				rapidtide --delaymapping --filterband lfo --noglm --mklthreads 16 --regressor $SUBJECT_DIR_FUNC_PROC/BOLD_DELAY/venous_sinus_ts.txt $SUBJECT_DIR_FUNC_PROC/rest.gin.nii.gz $SUBJECT_DIR_FUNC_PROC/BOLD_DELAY/rt
				
		# COEFFICIENT OF VARIATION (CoV) CALCULATION
				# Calculate mean of spatially smoothed RS data
				fslmaths $SUBJECT_DIR_FUNC_PROC/rest.ss.nii -Tmean $SUBJECT_DIR_FUNC_PROC/rest.ss.mean.nii 
				
				# Calculate SD of spatially smoothed RS data
				fslmaths $SUBJECT_DIR_FUNC_PROC/rest.ss.nii -Tstd $SUBJECT_DIR_FUNC_PROC/rest.ss.sd.nii 
				
				# Divide SD by mean of spatially smoothed RS data
				fslmaths $SUBJECT_DIR_FUNC_PROC/rest.ss.sd.nii -div $SUBJECT_DIR_FUNC_PROC/rest.ss.mean.nii $SUBJECT_DIR_FUNC_PROC/BOLD_DELAY/cov.nii.gz
done 