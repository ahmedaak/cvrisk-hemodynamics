#!/usr/bin/env bash

# Performs  processing on structural (anatomical T1-weighted) MRI data. This includes tissue-based and regional volumetry, as well as calculation of cortical thickness.
# Written by Ahmed Khalil & Ralf Mekle for the Berlin Longterm Observation of Vascular Events Study (BeLOVE) study http://bit.ly/336kjS7 
# Edited by Ahmed Khalil in 08/2023 for the "Vascular risk factors and cerebral hemodynamics" substudy of BeLOVE

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
	OASIS_MASK_2=$TEMPLATES_DIR/OASIS/T_template0_BrainCerebellumExtractionMask.nii.gz
	OASIS_TEMP_BRAIN=$TEMPLATES_DIR/OASIS/T_template0_BrainCerebellum.nii.gz
	MNI_1mm_TEMP=$TEMPLATES_DIR/MNI/MNI152_T1_1mm_brain.nii.gz
	MNI_2mm_TEMP=$TEMPLATES_DIR/MNI/MNI152_T1_2mm_brain.nii.gz
	MNI_1mm_MASK_reduced=$TEMPLATES_DIR/MNI/MNI152_T1_1mm_brain_mask_red.nii.gz # this is a mask of the MNI brain with the mask "reduced" so the first slice from the bottom is the first with cerebellar tissue 
	MNI_1mm_MASK=$TEMPLATES_DIR/MNI/MNI152_T1_1mm_brain_mask.nii.gz
	MNI_1mm_MASK_RH=$TEMPLATES_DIR/MNI/rightvol_bin.nii.gz
	MNI_1mm_MASK_LH=$TEMPLATES_DIR/MNI/leftvol_bin.nii.gz
	MNI_2mm_MASK=$TEMPLATES_DIR/MNI/MNI152_T1_2mm_brain_mask.nii.gz
	MNI_1mm_SNR_MASK=$TEMPLATES_DIR/MNI/MNI152_T1_1mm_brain_SNR_mask.nii.gz
	HAMMERSMITH_ATLAS=$TEMPLATES_DIR/Hammers_mith_atlas_n30r83_SPM5_MNI.nii.gz 
	HAMMERSMITH_LOBES=$TEMPLATES_DIR/hammersmith_lobes/lobes.nii.gz
	HARVARD_ATLAS=$TEMPLATES_DIR/MNI/MNI-maxprob-thr25-1mm.nii.gz 

	
	cd $DATA_DIR/
	# if a results file does not exist, create one
	if [ ! -f "$DATA_DIR/results.csv" ]
	then
	printf "%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s \n" "BLV" "DATE" "TIV_R_voxels" "TIV_R_volume" "GM_R_voxels" "GM_R_volume" "WM_R_voxels" "WM_R_volume" "CSF_R_voxels" "CSF_R_volume" "CAUD_R_voxels" "CAUD_R_volume" "CEREB_R_voxels" "CEREB_R_volume" "FRONT_R_voxels" "FRONT_R_volume" "INSUL_R_voxels" "INSUL_R_volume" "OCC_R_voxels" "OCC_R_volume" "PAR_R_voxels" "PAR_R_volume" "PUTAM_R_voxels" "PUTAM_R_volume" "TEMP_R_voxels" "TEMP_R_volume" "THAL_R_voxels" "THAL_R_volume" "TIV_L_voxels" "TIV_L_volume" "GM_L_voxels" "GM_L_volume" "WM_L_voxels" "WM_L_volume" "CSF_L_voxels" "CSF_L_volume" "CAUD_L_voxels" "CAUD_L_volume" "CEREB_L_voxels" "CEREB_L_volume" "FRONT_L_voxels" "FRONT_L_volume" "INSUL_L_voxels" "INSUL_L_volume" "OCC_L_voxels" "OCC_L_volume" "PAR_L_voxels" "PAR_L_volume" "PUTAM_L_voxels" "PUTAM_L_volume" "TEMP_L_voxels" "TEMP_L_volume" "THAL_L_voxels" "THAL_L_volume" "FRONT_TH_R" "INSUL_TH_R" "OCC_TH_R" "PAR_TH_R" "TEMP_TH_R" "FRONT_TH_L" "INSUL_TH_L" "OCC_TH_L" "PAR_TH_L" "TEMP_TH_L" >> $DATA_DIR/results.csv
	fi 
	
# loop through subjects
for i in sub-*

	do
	echo $i
	
	# check if this patient's MPRAGE has already been processed 
	if [ -d "$DATA_DIR/$i/anat/proc" ]
	then 
		continue
	fi 
	
	# create directory to store processed files
	mkdir $i/anat/proc
		
	# reduce FOV in z-plane (i.e. get rid of neck slices) so that brain extraction works 
	 robustfov -i $DATA_DIR/$i/anat/${i}_T1w.nii.gz -r $DATA_DIR/$i/anat/proc/t1_redfov.nii.gz -m $DATA_DIR/$i/anat/proc/roi2full.mat
	
	# perform cortical thickness processing (includes brain extraction and segmentation)
	antsCorticalThickness.sh -d 3   -a $DATA_DIR/$i/anat/proc/t1_redfov.nii.gz   -e $OASIS_TEMP   -t $OASIS_TEMP_BRAIN   -m $OASIS_TEMP_PRIOR   -f $OASIS_MASK_2   -p $TEMPLATES_DIR/OASIS/Priors2/priors%d.nii.gz   -q 1   -o $DATA_DIR/$i/anat/proc/CortThick/ -n 32
	
	mkdir $DATA_DIR/$i/anat/proc/brain_ext
	mv $DATA_DIR/$i/anat/proc/CortThick/ExtractedBrain0N4.nii.gz $DATA_DIR/$i/anat/proc/brain_ext/ExtractedBrain0N4.nii.gz
	
		
	# perform registration
		mkdir $DATA_DIR/$i/anat/proc/reg 
		# T1 to MNI space (linear then nonlinear)
		antsRegistrationSyN.sh -d 3 -f $MNI_1mm_TEMP -m $DATA_DIR/$i/anat/proc/brain_ext/ExtractedBrain0N4.nii.gz -o $DATA_DIR/$i/anat/proc/reg/T1_mni -n 32
		
		# brain extract the FLAIR
		mri_synthstrip -i $DATA_DIR/$i/anat/${i}_FLAIR.nii.gz -o $DATA_DIR/$i/anat/proc/${i}_FLAIR_brain.nii.gz
		
		# register FLAIR to T1 space 
		$TEMPLATES_DIR/antsIntermodalityIntrasubject.sh -d 3 -i $DATA_DIR/$i/anat/proc/${i}_FLAIR_brain.nii.gz -r $DATA_DIR/$i/anat/proc/t1_redfov.nii.gz -x $DATA_DIR/$i/anat/proc/CortThick/BrainExtractionMask.nii.gz -w $DATA_DIR/$i/anat/proc/reg/T1_mni -t 2 -o $DATA_DIR/$i/anat/proc/reg/flair_T1

		# register FLAIR to MNI space
		antsApplyTransforms -d 3 -i $DATA_DIR/$i/anat/proc/${i}_FLAIR_brain.nii.gz -r $MNI_1mm_TEMP  -t $DATA_DIR/$i/anat/proc/reg/T1_mni1Warp.nii.gz $DATA_DIR/$i/anat/proc/reg/T1_mni0GenericAffine.mat  -t $DATA_DIR/$i/anat/proc/reg/flair_T11Warp.nii.gz -t $DATA_DIR/$i/anat/proc/reg/flair_T10GenericAffine.mat -o $DATA_DIR/$i/anat/proc/reg/flair2mni.nii.gz
		
		# atlases (in MNI space) to native space (inverse matrix) using inverse transform of prior step
		antsApplyTransforms -d 3 -i $HAMMERSMITH_ATLAS -r $DATA_DIR/$i/anat/proc/brain_ext/ExtractedBrain0N4.nii.gz -n NearestNeighbor -t [$DATA_DIR/$i/anat/proc/reg/T1_mni0GenericAffine.mat,1] -t $DATA_DIR/$i/anat/proc/reg/T1_mni1InverseWarp.nii.gz -o $DATA_DIR/$i/anat/proc/reg/hammersmith_atlas_native.nii.gz
		antsApplyTransforms -d 3 -i $HARVARD_ATLAS -r $DATA_DIR/$i/anat/proc/brain_ext/ExtractedBrain0N4.nii.gz -n NearestNeighbor -t [$DATA_DIR/$i/anat/proc/reg/T1_mni0GenericAffine.mat,1] -t $DATA_DIR/$i/anat/proc/reg/T1_mni1InverseWarp.nii.gz -o $DATA_DIR/$i/anat/proc/reg/harvard_atlas_native.nii.gz
		antsApplyTransforms -d 3 -i $HAMMERSMITH_LOBES -r $DATA_DIR/$i/anat/proc/brain_ext/ExtractedBrain0N4.nii.gz -n NearestNeighbor -t [$DATA_DIR/$i/anat/proc/reg/T1_mni0GenericAffine.mat,1] -t $DATA_DIR/$i/anat/proc/reg/T1_mni1InverseWarp.nii.gz -o $DATA_DIR/$i/anat/proc/reg/hammersmith_lobes_native.nii.gz

		# register reduced MNI mask to native space
		antsApplyTransforms -d 3 -i $MNI_1mm_MASK_reduced -r $DATA_DIR/$i/anat/proc/brain_ext/ExtractedBrain0N4.nii.gz -n NearestNeighbor -t [$DATA_DIR/$i/anat/proc/reg/T1_mni0GenericAffine.mat,1] -t $DATA_DIR/$i/anat/proc/reg/T1_mni1InverseWarp.nii.gz -o $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native.nii.gz

		# register MNI hemisphere masks to native space
		antsApplyTransforms -d 3 -i $MNI_1mm_MASK_RH -r $DATA_DIR/$i/anat/proc/brain_ext/ExtractedBrain0N4.nii.gz -n NearestNeighbor -t [$DATA_DIR/$i/anat/proc/reg/T1_mni0GenericAffine.mat,1] -t $DATA_DIR/$i/anat/proc/reg/T1_mni1InverseWarp.nii.gz -o $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_RH.nii.gz
		antsApplyTransforms -d 3 -i $MNI_1mm_MASK_LH -r $DATA_DIR/$i/anat/proc/brain_ext/ExtractedBrain0N4.nii.gz -n NearestNeighbor -t [$DATA_DIR/$i/anat/proc/reg/T1_mni0GenericAffine.mat,1] -t $DATA_DIR/$i/anat/proc/reg/T1_mni1InverseWarp.nii.gz -o $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_LH.nii.gz
		
		# threshold and binarize ANTs segmentation outputs
		for b in {1..6}
			do
			fslmaths $DATA_DIR/$i/anat/proc/CortThick/BrainSegmentationPosteriors${b}.nii.gz -thr 0.8 -bin $DATA_DIR/$i/anat/proc/CortThick/BrainSegmentationPosteriors${b}_bin.nii.gz
		done
		
		# add all binarized ANTs GM segmentations (cortical, subcortical, infratentorial)
		fslmaths $DATA_DIR/$i/anat/proc/CortThick/BrainSegmentationPosteriors2_bin.nii.gz -add $DATA_DIR/$i/anat/proc/CortThick/BrainSegmentationPosteriors4_bin.nii.gz -add $DATA_DIR/$i/anat/proc/CortThick/BrainSegmentationPosteriors5_bin.nii.gz -add $DATA_DIR/$i/anat/proc/CortThick/BrainSegmentationPosteriors6_bin.nii.gz $DATA_DIR/$i/anat/proc/CortThick/BrainSegmentationPosteriors_totalgm_bin.nii.gz

		# use reduced MNI mask to mask segmentation + brain extraction files (for calculating TIV, GM, etc)
		mkdir $DATA_DIR/$i/anat/proc/output
		 fslmaths $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native.nii.gz -mul $DATA_DIR/$i/anat/proc/brain_ext/ExtractedBrain0N4.nii.gz $DATA_DIR/$i/anat/proc/output/t1_wholebrain.nii.gz
		 fslmaths $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native.nii.gz -mul $DATA_DIR/$i/anat/proc/CortThick/BrainSegmentationPosteriors1_bin.nii.gz $DATA_DIR/$i/anat/proc/output/t1_csf.nii.gz
		 fslmaths $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native.nii.gz -mul $DATA_DIR/$i/anat/proc/CortThick/BrainSegmentationPosteriors_totalgm_bin.nii.gz $DATA_DIR/$i/anat/proc/output/t1_gm.nii.gz
		 fslmaths $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native.nii.gz -mul $DATA_DIR/$i/anat/proc/CortThick/BrainSegmentationPosteriors3_bin.nii.gz $DATA_DIR/$i/anat/proc/output/t1_wm.nii.gz
		 fslmaths $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native.nii.gz -mul $DATA_DIR/$i/anat/proc/reg/harvard_atlas_native.nii.gz $DATA_DIR/$i/anat/proc/output/t1_regions.nii.gz
		 fslmaths $DATA_DIR/$i/anat/proc/output/t1_gm.nii.gz -mul $DATA_DIR/$i/anat/proc/output/t1_regions.nii.gz $DATA_DIR/$i/anat/proc/output/t1_regions_gm.nii.gz
		rm $DATA_DIR/$i/anat/proc/output/t1_regions.nii.gz
		
		# get individual parts of atlas in native space (only cortical regions)
		 fslmaths $DATA_DIR/$i/anat/proc/reg/harvard_atlas_native.nii.gz -thr 1 -uthr 1 -bin $DATA_DIR/$i/anat/proc/reg/caudate.nii.gz
		 fslmaths $DATA_DIR/$i/anat/proc/reg/harvard_atlas_native.nii.gz -thr 3 -uthr 3 -bin $DATA_DIR/$i/anat/proc/reg/frontal.nii.gz
		 fslmaths $DATA_DIR/$i/anat/proc/reg/harvard_atlas_native.nii.gz -thr 4 -uthr 4 -bin $DATA_DIR/$i/anat/proc/reg/insula.nii.gz
		 fslmaths $DATA_DIR/$i/anat/proc/reg/harvard_atlas_native.nii.gz -thr 5 -uthr 5 -bin $DATA_DIR/$i/anat/proc/reg/occipital.nii.gz
		 fslmaths $DATA_DIR/$i/anat/proc/reg/harvard_atlas_native.nii.gz -thr 6 -uthr 6 -bin $DATA_DIR/$i/anat/proc/reg/parietal.nii.gz
		 fslmaths $DATA_DIR/$i/anat/proc/reg/harvard_atlas_native.nii.gz -thr 8 -uthr 8 -bin $DATA_DIR/$i/anat/proc/reg/temporal.nii.gz
		
		# ******** QUALITY CONTROL *********
		mkdir $DATA_DIR/$i/anat/proc/QC
		# calculate SNR
				# register SNR mask to native T1 space
				 antsApplyTransforms -d 3 -i $MNI_1mm_SNR_MASK -r $DATA_DIR/$i/anat/proc/brain_ext/ExtractedBrain0N4.nii.gz -t [$DATA_DIR/$i/anat/proc/reg/T1_mni0GenericAffine.mat,1] -t $DATA_DIR/$i/anat/proc/reg/T1_mni1InverseWarp.nii.gz -o $DATA_DIR/$i/anat/proc/QC/SNR_mask_native.nii.gz -n NearestNeighbor
				
				# get mean GM intensity and SD of air intensity
				 fslstats $DATA_DIR/$i/anat/proc/t1_redfov.nii.gz -k $DATA_DIR/$i/anat/proc/output/t1_gm.nii.gz -m >> $DATA_DIR/$i/anat/proc/QC/snr.txt
				
				 fslstats $DATA_DIR/$i/anat/proc/t1_redfov.nii.gz -k $DATA_DIR/$i/anat/proc/QC/SNR_mask_native.nii.gz -s >> $DATA_DIR/$i/anat/proc/QC/snr.txt
		
		# calculate FWHM
		3dFWHMx -automask -ShowMeClassicFWHM $DATA_DIR/$i/anat/proc/t1_redfov.nii.gz -out >> $DATA_DIR/$i/anat/proc/QC/fwhm_gaussian.txt
				
		
		# output cortical thickness values
		BLV=$i
		echo "Region, Thickness" > $DATA_DIR/$i/${BLV}_cortical_thickness.csv
		FRONT_TH_R=`fslstats $DATA_DIR/$i/anat/proc/CortThick/CorticalThickness.nii.gz -k $DATA_DIR/$i/anat/proc/reg/frontal.nii.gz -k $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_RH.nii.gz -M`
		INSUL_TH_R=`fslstats $DATA_DIR/$i/anat/proc/CortThick/CorticalThickness.nii.gz -k $DATA_DIR/$i/anat/proc/reg/insula.nii.gz -k $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_RH.nii.gz -M`
		OCC_TH_R=`fslstats $DATA_DIR/$i/anat/proc/CortThick/CorticalThickness.nii.gz -k $DATA_DIR/$i/anat/proc/reg/occipital.nii.gz -k $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_RH.nii.gz -M`
		PAR_TH_R=`fslstats $DATA_DIR/$i/anat/proc/CortThick/CorticalThickness.nii.gz -k $DATA_DIR/$i/anat/proc/reg/parietal.nii.gz -k $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_RH.nii.gz -M`
		TEMP_TH_R=`fslstats $DATA_DIR/$i/anat/proc/CortThick/CorticalThickness.nii.gz -k $DATA_DIR/$i/anat/proc/reg/temporal.nii.gz -k $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_RH.nii.gz -M`

		FRONT_TH_L=`fslstats $DATA_DIR/$i/anat/proc/CortThick/CorticalThickness.nii.gz -k $DATA_DIR/$i/anat/proc/reg/frontal.nii.gz -k $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_LH.nii.gz -M`
		INSUL_TH_L=`fslstats $DATA_DIR/$i/anat/proc/CortThick/CorticalThickness.nii.gz -k $DATA_DIR/$i/anat/proc/reg/insula.nii.gz -k $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_LH.nii.gz -M`
		OCC_TH_L=`fslstats $DATA_DIR/$i/anat/proc/CortThick/CorticalThickness.nii.gz -k $DATA_DIR/$i/anat/proc/reg/occipital.nii.gz -k $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_LH.nii.gz -M`
		PAR_TH_L=`fslstats $DATA_DIR/$i/anat/proc/CortThick/CorticalThickness.nii.gz -k $DATA_DIR/$i/anat/proc/reg/parietal.nii.gz -k $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_LH.nii.gz -M`
		TEMP_TH_L=`fslstats $DATA_DIR/$i/anat/proc/CortThick/CorticalThickness.nii.gz -k $DATA_DIR/$i/anat/proc/reg/temporal.nii.gz -k $DATA_DIR/$i/anat/proc/reg/mni_mask_reduced_native_LH.nii.gz -M`
		
		for ct in FRONT_TH_R INSUL_TH_R OCC_TH_R PAR_TH_R TEMP_TH_R FRONT_TH_L INSUL_TH_L OCC_TH_L PAR_TH_L TEMP_TH_L
		do
		echo "$ct, ${!ct}" >> $DATA_DIR/$i/${BLV}_cortical_thickness.csv
		done
		
		# output volumetry values

		echo "Region, Volume" > $DATA_DIR/$i/${BLV}_volumes.csv
		 TIV=$(fslstats $DATA_DIR/$i/anat/proc/output/t1_wholebrain.nii.gz  -V | awk '{print $2}')
		 GM=$(fslstats $DATA_DIR/$i/anat/proc/output/t1_gm.nii.gz  -V | awk '{print $2}')
		 WM=$(fslstats $DATA_DIR/$i/anat/proc/output/t1_wm.nii.gz  -V | awk '{print $2}')
		 CSF=$(fslstats $DATA_DIR/$i/anat/proc/output/t1_csf.nii.gz  -V | awk '{print $2}')
		echo "TIV, $TIV" >> $DATA_DIR/$i/${BLV}_volumes.csv
		echo "GM, $GM" >> $DATA_DIR/$i/${BLV}_volumes.csv
		echo "WM, $WM" >> $DATA_DIR/$i/${BLV}_volumes.csv
		echo "CSF, $CSF" >> $DATA_DIR/$i/${BLV}_volumes.csv

		for value in {1..83}
			do 
			volume=$(fslstats $DATA_DIR/$i/anat/proc/reg/hammersmith_atlas_native.nii.gz -l $(echo "$value - 0.5" | bc) -u $(echo "$value + 0.5" | bc) -V | awk '{print $2}')
			
			echo "$value, $volume" >> $DATA_DIR/$i/${BLV}_${DATE}volumes.csv; 
			done

	done
	