library("dplyr")
library("tidyr")
library("purrr")
library("ggplot2")
library("devtools")
library("SummarizedExperiment")
load_all("../seqUtils/")

#Helper functions
testInteractionWrapper <- function(qtl_df, trait_matrix, sample_meta, ...){
  testMultipleInteractions(qtl_df, trait_matrix, sample_meta, ...) %>%
    postProcessInteractionPvalues(id_field_separator = "-")
}


#Import all QTL calls
qtls = readRDS("results/trQTLs/salmonella_trQTL_min_pvalues.rds")

#Import genotypes
vcf_file = readRDS("results/genotypes/salmonella/imputed.86_samples.sorted.filtered.named.rds")

#Define formulas for interaction testing
formula_qtl = as.formula("expression ~ genotype + condition_name + (1|donor)")
formula_interaction = as.formula("expression ~ genotype + condition_name + condition_name:genotype + (1|donor)")

#Define condition pairs
condition_list = list(IFNg = c("naive", "IFNg"), SL1344 = c("naive", "SL1344"), IFNg_SL1344 = c("naive", "IFNg_SL1344"))



##### Leafcutter #####
se_leafcutter = readRDS("results/SummarizedExperiments/salmonella_leafcutter_counts.rds")
leafcutter_by_cond = purrr::map(condition_list, ~extractConditionFromSummarizedExperiment(.,se_leafcutter))

#Extract feature matrices
leafcutter_mat_list = purrr::map(leafcutter_by_cond, ~assays(.)$tpm_ratios %>%
                                   replaceNAsWithRowMeans() %>%
                                   quantileNormaliseRows())
leafcutter_sample_meta = purrr::map(leafcutter_by_cond, ~colData(.) %>% tbl_df2())
leafcutter_gene_meta = rowData(se_leafcutter) %>% tbl_df2()
leafcutter_qtl_list = purrr::map(qtls$leafcutter[c("IFNg", "SL1344", "IFNg_SL1344")], ~dplyr::filter(.,p_fdr < 0.1))

#Test for interactions using fixed effects for genotype but allowing for random effect for paired samples
leafcutter_interaction_res = purrr::pmap(list(leafcutter_qtl_list, leafcutter_mat_list, leafcutter_sample_meta),
                                         testInteractionWrapper,
                                         vcf_file, formula_qtl, formula_interaction, id_field_separator = "-", lme4 = TRUE)
saveRDS(leafcutter_interaction_res, "results/trQTLs/variance_explained/salmonella_leafcutter_interaction_test.rds")


###### reviseAnnotations #####
se_reviseAnnotations = readRDS("results/SummarizedExperiments/salmonella_salmon_reviseAnnotations.rds")
revised_by_cond = purrr::map(condition_list, ~extractConditionFromSummarizedExperiment(.,se_reviseAnnotations))
revised_gene_meta = rowData(se_reviseAnnotations) %>% tbl_df2()
rm(se_reviseAnnotations)
gc()

#Extract feature matrices
revised_mat_list = purrr::map(revised_by_cond, ~assays(.)$tpm_ratios %>%
                                replaceNAsWithRowMeans() %>%
                                quantileNormaliseRows())
revised_sample_meta = purrr::map(revised_by_cond, ~colData(.) %>% tbl_df2())
revised_qtl_list = purrr::map(qtls$reviseAnnotations[c("IFNg", "SL1344", "IFNg_SL1344")], ~dplyr::filter(.,p_fdr < 0.1))

#Test for interactions using fixed effects for genotype but allowing for random effect for paired samples
revised_interaction_res = purrr::pmap(list(revised_qtl_list, revised_mat_list, revised_sample_meta),
                                      testInteractionWrapper,
                                      vcf_file, formula_qtl, formula_interaction, id_field_separator = "-", lme4 = TRUE)
saveRDS(revised_interaction_res, "results/trQTLs/variance_explained/salmonella_reviseAnnotations_interaction_test.rds")



###### Ensembl_87 #####
se_ensembl = readRDS("results/SummarizedExperiments/salmonella_salmon_Ensembl_87.rds")
ensembl_by_cond = purrr::map(condition_list, ~extractConditionFromSummarizedExperiment(.,se_ensembl))

#Extract feature matrices
ensembl_mat_list = purrr::map(ensembl_by_cond, ~assays(.)$tpm_ratios %>%
                                replaceNAsWithRowMeans() %>%
                                quantileNormaliseRows())
ensembl_sample_meta = purrr::map(ensembl_by_cond, ~colData(.) %>% tbl_df2())
ensembl_gene_meta = rowData(se_ensembl) %>% tbl_df2()
ensembl_qtl_list = purrr::map(qtls$Ensembl_87[c("IFNg", "SL1344", "IFNg_SL1344")], ~dplyr::filter(.,p_fdr < 0.1))

#Test for interactions using fixed effects for genotype but allowing for random effect for paired samples
ensembl_interaction_res = purrr::pmap(list(ensembl_qtl_list, ensembl_mat_list, ensembl_sample_meta),
                                      testInteractionWrapper,
                                      vcf_file, formula_qtl, formula_interaction, id_field_separator = "-", lme4 = TRUE)
saveRDS(ensembl_interaction_res, "results/trQTLs/variance_explained/salmonella_Ensembl_87_interaction_test.rds")


###### featureCounts ######
se_featureCounts = readRDS("results/SummarizedExperiments/salmonella_featureCounts.rds")
fc_by_cond = purrr::map(condition_list, ~extractConditionFromSummarizedExperiment(.,se_featureCounts))

#Extract feature matrices
fc_mat_list = purrr::map(fc_by_cond, ~assays(.)$cqn)
fc_sample_meta = purrr::map(fc_by_cond, ~colData(.) %>% tbl_df2())
fc_gene_meta = rowData(se_featureCounts) %>% tbl_df2()
fc_qtl_list = purrr::map(qtls$featureCounts[c("IFNg", "SL1344", "IFNg_SL1344")], ~dplyr::filter(.,p_fdr < 0.1))

#Estimate variance explained for all QTLs detected in stimulated conditons
fc_interaction_res = purrr::pmap(list(fc_qtl_list, fc_mat_list, fc_sample_meta),
                                 testInteractionWrapper,
                                 vcf_file, formula_qtl, formula_interaction, id_field_separator = "-", lme4 = TRUE)
saveRDS(fc_interaction_res, "results/trQTLs/variance_explained/salmonella_featureCounts_interaction_test.rds")

###### txrevise promoters #####
se_reviseAnnotations = readRDS("results/SummarizedExperiments/salmonella_salmon_txrevise_promoters.rds")
revised_by_cond = purrr::map(condition_list, ~extractConditionFromSummarizedExperiment(.,se_reviseAnnotations))
revised_gene_meta = rowData(se_reviseAnnotations) %>% tbl_df2()
rm(se_reviseAnnotations)
gc()

#Extract feature matrices
revised_mat_list = purrr::map(revised_by_cond, ~assays(.)$tpm_ratios %>%
                                replaceNAsWithRowMeans() %>%
                                quantileNormaliseRows())
revised_sample_meta = purrr::map(revised_by_cond, ~colData(.) %>% tbl_df2())
revised_qtl_list = purrr::map(qtls$txrevise_promoters[c("IFNg", "SL1344", "IFNg_SL1344")], ~dplyr::filter(.,p_fdr < 0.1))

#Test for interactions using fixed effects for genotype but allowing for random effect for paired samples
revised_interaction_res = purrr::pmap(list(revised_qtl_list, revised_mat_list, revised_sample_meta),
                                      testInteractionWrapper,
                                      vcf_file, formula_qtl, formula_interaction, id_field_separator = "-", lme4 = TRUE)
saveRDS(revised_interaction_res, "results/trQTLs/variance_explained/salmonella_txrevise_promoters_interaction_test.rds")



###### txrevise ends #####
se_reviseAnnotations = readRDS("results/SummarizedExperiments/salmonella_salmon_txrevise_ends.rds")
revised_by_cond = purrr::map(condition_list, ~extractConditionFromSummarizedExperiment(.,se_reviseAnnotations))
revised_gene_meta = rowData(se_reviseAnnotations) %>% tbl_df2()
rm(se_reviseAnnotations)
gc()

#Extract feature matrices
revised_mat_list = purrr::map(revised_by_cond, ~assays(.)$tpm_ratios %>%
                                replaceNAsWithRowMeans() %>%
                                quantileNormaliseRows())
revised_sample_meta = purrr::map(revised_by_cond, ~colData(.) %>% tbl_df2())
revised_qtl_list = purrr::map(qtls$txrevise_ends[c("IFNg", "SL1344", "IFNg_SL1344")], ~dplyr::filter(.,p_fdr < 0.1))

#Test for interactions using fixed effects for genotype but allowing for random effect for paired samples
revised_interaction_res = purrr::pmap(list(revised_qtl_list, revised_mat_list, revised_sample_meta),
                                      testInteractionWrapper,
                                      vcf_file, formula_qtl, formula_interaction, id_field_separator = "-", lme4 = TRUE)
saveRDS(revised_interaction_res, "results/trQTLs/variance_explained/salmonella_txrevise_ends_interaction_test.rds")




