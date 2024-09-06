# Extracts relevant clinical data for subjects whose MRI data was successfully processed and creates FSL randomise matrix 
# Written by Ahmed Khalil in 08/2024 for the "Vascular risk factors and cerebral hemodynamics" substudy of BeLOVE

# Load required libraries
library(readxl)  # For reading Excel files

# read in the text files with successfully processed subjects (output of BLV_glm)

# Step 1: Read file paths and extract "sub-xxx"
file_paths <- readLines("//sc-data.sc-store.charite.de/sc-project-cc15-csb-neuroimaging/SC_Stroke_MRI/khalila/BLV/DATA_PILOT_20240717/glm/paths_to_bd2mni.txt")
subs <- gsub(".*(sub-[0-9]+).*", "\\1", file_paths)

# Step 2: Read Excel sheet, match "sub-xxx", and extract relevant data
excel_data <- read_excel("S:/AG/AG-CSB_NeuroRad2/khalila/PROJECTS/BeLOVE/clinical_data/simulated_data_pilot/sim_data_all.xlsx")
matched_data <- excel_data[excel_data$bids_id %in% subs, ]

# Step 3: Convert "Male" to 0, "Female" to 1, "Ja" to 1, "Nein" to 0
matched_data$scr_sex_cp <- ifelse(matched_data$scr_sex_cp == "Male", 0, 1)
matched_data$alkohol2 <- ifelse(matched_data$alkohol2 == "Ja", 1, 0)

# Step 4: Create the design matrix with an intercept
# Adding intercept column
design_matrix <- cbind(Intercept = rep(1, nrow(matched_data)), 
                       matched_data[, c("frs", "scr_age", "scr_sex_cp", "addition_schul_und_bildung", "alkohol2", "sport2", "lab_gfr_cystatin", "moca")])

# Demean the continuous variables
cols_to_demean <- c("frs", "scr_age", "addition_schul_und_bildung", "sport2", "lab_gfr_cystatin", "moca")
design_matrix[cols_to_demean] <- lapply(design_matrix[cols_to_demean], function(x) x - mean(x, na.rm = TRUE))

# Step 5: Write the design matrix to a text file
write.table(design_matrix, file = "//sc-data.sc-store.charite.de/sc-project-cc15-csb-neuroimaging/SC_Stroke_MRI/khalila/BLV/DATA_PILOT_20240717/glm/design.txt", row.names = FALSE, col.names = FALSE)