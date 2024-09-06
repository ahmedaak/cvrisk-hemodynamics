#!/usr/bin/env bash

# Performs  GLM analysis on BeLOVE data
# Written by Ahmed Khalil in 05/2024 for the "Vascular risk factors and cerebral hemodynamics" substudy of BeLOVE

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
	MNI_1mm_TEMP=$TEMPLATES_DIR/MNI/MNI152_T1_1mm_brain.nii.gz
	MNI_2mm_TEMP=$TEMPLATES_DIR/MNI/MNI152_T1_2mm_brain.nii.gz
	MNI_1mm_MASK_reduced=$TEMPLATES_DIR/MNI/MNI152_T1_1mm_brain_mask_red.nii.gz # this is a mask of the MNI brain with the mask "reduced" so the first slice from the bottom is the first with cerebellar tissue 
	MNI_1mm_MASK=$TEMPLATES_DIR/MNI/MNI152_T1_1mm_brain_mask.nii.gz
	MNI_2mm_MASK=$TEMPLATES_DIR/MNI/MNI152_T1_2mm_brain_mask.nii.gz
	STRUCT_ATLAS=$TEMPLATES_DIR/MNI/MNI-maxprob-thr25-1mm.nii.gz
	VENOUS_SINUS_TEMP=$TEMPLATES_DIR/venous_sinus_template.nii.gz

	cd $DATA_DIR/
	
	
	# Create GLM folder 
	mkdir $DATA_DIR/glm 

# loop through subjects
for i in sub-*

	do
	  echo $i
		
	SUBJECT_DIR_FUNC=$DATA_DIR/$i/func
	SUBJECT_DIR_STRUCT=$DATA_DIR/$i/anat
	

# Register BOLD delay and CoV maps to MNI
		# Apply RS to T1 transformation
		flirt -in $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/rt_desc-maxtime_map.nii.gz -ref $SUBJECT_DIR_STRUCT/proc/t1_redfov.nii.gz -out $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/bd2t1.nii.gz -init $SUBJECT_DIR_FUNC/proc/reg/rs2anat.mat -applyxfm
		flirt -in $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/cov.nii.gz -ref $SUBJECT_DIR_STRUCT/proc/t1_redfov.nii.gz -out $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/cov2t1.nii.gz -init $SUBJECT_DIR_FUNC/proc/reg/rs2anat.mat -applyxfm

		# Apply RS (in T1 space) to MNI transformation 
		 antsApplyTransforms -d 3 -i $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/bd2t1.nii.gz -r $MNI_2mm_TEMP -t $SUBJECT_DIR_STRUCT/proc/reg/T1_mni1Warp.nii.gz -t $SUBJECT_DIR_STRUCT/proc/reg/T1_mni0GenericAffine.mat -o $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/bd2mni.nii.gz
		 antsApplyTransforms -d 3 -i $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/cov2t1.nii.gz -r $MNI_2mm_TEMP -t $SUBJECT_DIR_STRUCT/proc/reg/T1_mni1Warp.nii.gz -t $SUBJECT_DIR_STRUCT/proc/reg/T1_mni0GenericAffine.mat -o $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/cov2mni.nii.gz

# Append registered BOLD delay and CoV map file paths to a text file
[[ -f "${SUBJECT_DIR_FUNC}/proc/BOLD_DELAY/bd2mni.nii.gz" ]] && echo "${SUBJECT_DIR_FUNC}/proc/BOLD_DELAY/bd2mni.nii.gz" >> $DATA_DIR/glm/paths_to_bd2mni.txt || echo "File bd2mni.nii.gz does not exist"
[[ -f "${SUBJECT_DIR_FUNC}/proc/BOLD_DELAY/cov2mni.nii.gz" ]] && echo "${SUBJECT_DIR_FUNC}/proc/BOLD_DELAY/cov2mni.nii.gz" >> $DATA_DIR/glm/paths_to_cov2mni.txt || echo "File cov2mni.nii.gz does not exist"


# Extract BOLD delay and CoV from deep and cortical grey matter regions defined by the Harvard-Oxford atlas (9 regions per hemisphere)
fslmeants -i $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/bd2t1.nii.gz -o $SUBJECT_DIR_FUNC/proc/bd_gm_vals_rh.txt -m $SUBJECT_DIR_STRUCT/proc/reg/mni_mask_reduced_native_RH.nii.gz --label=$SUBJECT_DIR_STRUCT/proc/output/t1_regions_gm.nii.gz --transpose
fslmeants -i $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/bd2t1.nii.gz -o $SUBJECT_DIR_FUNC/proc/bd_gm_vals_lh.txt -m $SUBJECT_DIR_STRUCT/proc/reg/mni_mask_reduced_native_LH.nii.gz --label=$SUBJECT_DIR_STRUCT/proc/output/t1_regions_gm.nii.gz --transpose
fslmeants -i $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/cov2t1.nii.gz -o $SUBJECT_DIR_FUNC/proc/cov_gm_vals_rh.txt -m $SUBJECT_DIR_STRUCT/proc/reg/mni_mask_reduced_native_RH.nii.gz --label=$SUBJECT_DIR_STRUCT/proc/output/t1_regions_gm.nii.gz --transpose
fslmeants -i $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/cov2t1.nii.gz -o $SUBJECT_DIR_FUNC/proc/cov_gm_vals_lh.txt -m $SUBJECT_DIR_STRUCT/proc/reg/mni_mask_reduced_native_LH.nii.gz --label=$SUBJECT_DIR_STRUCT/proc/output/t1_regions_gm.nii.gz --transpose

# Extract BOLD delay and CoV from white matter regions defined by Hammersmith atlas - EXCLUDING areas of WMHs
fslmeants -i $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/bd2t1.nii.gz -o $SUBJECT_DIR_FUNC/proc/bd_wm_vals_rh.txt -m $SUBJECT_DIR_STRUCT/proc/output/t1_wm.nii.gz -m $SUBJECT_DIR_STRUCT/proc/reg/mni_mask_reduced_native_RH.nii.gz --label=$SUBJECT_DIR_STRUCT/proc/reg/hammersmith_lobes_native.nii.gz --transpose
fslmeants -i $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/bd2t1.nii.gz -o $SUBJECT_DIR_FUNC/proc/bd_wm_vals_lh.txt -m $SUBJECT_DIR_STRUCT/proc/output/t1_wm.nii.gz -m $SUBJECT_DIR_STRUCT/proc/reg/mni_mask_reduced_native_LH.nii.gz --label=$SUBJECT_DIR_STRUCT/proc/reg/hammersmith_lobes_native.nii.gz --transpose
fslmeants -i $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/cov2t1.nii.gz -o $SUBJECT_DIR_FUNC/proc/cov_wm_vals_rh.txt -m $SUBJECT_DIR_STRUCT/proc/output/t1_wm.nii.gz -m $SUBJECT_DIR_STRUCT/proc/reg/mni_mask_reduced_native_RH.nii.gz --label=$SUBJECT_DIR_STRUCT/proc/reg/hammersmith_lobes_native.nii.gz --transpose
fslmeants -i $SUBJECT_DIR_FUNC/proc/BOLD_DELAY/cov2t1.nii.gz -o $SUBJECT_DIR_FUNC/proc/cov_wm_vals_lh.txt -m $SUBJECT_DIR_STRUCT/proc/output/t1_wm.nii.gz -m $SUBJECT_DIR_STRUCT/proc/reg/mni_mask_reduced_native_LH.nii.gz --label=$SUBJECT_DIR_STRUCT/proc/reg/hammersmith_lobes_native.nii.gz --transpose
done 

# Concatenate all BD and CoV maps
fslmerge -t $DATA_DIR/glm/merge_bd2mni.nii.gz $(cat ${DATA_DIR}/glm/paths_to_bd2mni.txt)
fslmerge -t $DATA_DIR/glm/merge_cov2mni.nii.gz $(cat ${DATA_DIR}/glm/paths_to_cov2mni.txt)

# Convert design matrix text file to .mat
Text2Vest $DATA_DIR/glm/design.txt $DATA_DIR/glm/design.mat

# run randomise (make sure design.con has already been created)
randomise_parallel -i $DATA_DIR/glm/merge_bd2mni.nii.gz -o $DATA_DIR/glm/glm_bd_ -d $DATA_DIR/glm/design.mat -t $DATA_DIR/glm/design.con -T -n 5000
randomise_parallel -i $DATA_DIR/glm/merge_cov2mni.nii.gz -o $DATA_DIR/glm/glm_cov_ -d $DATA_DIR/glm/design.mat -t $DATA_DIR/glm/design.con -T -n 5000

