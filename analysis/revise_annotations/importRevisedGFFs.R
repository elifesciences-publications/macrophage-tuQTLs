library("purrr")
library("dplyr")
library("devtools")
library("rtracklayer")
load_all("../txrevise/")

#Import revised GFF files
gff_list = list(up1 = rtracklayer::import.gff3("processed/annotations/gff/reviseAnnotations.grp_1_upstream.gff3"),
                up2 = rtracklayer::import.gff3("processed/annotations/gff/reviseAnnotations.grp_2_upstream.gff3"),
                contained1 = rtracklayer::import.gff3("processed/annotations/gff/reviseAnnotations.grp_1_contained.gff3"),
                contained2 = rtracklayer::import.gff3("processed/annotations/gff/reviseAnnotations.grp_2_contained.gff3"),
                down1 = rtracklayer::import.gff3("processed/annotations/gff/reviseAnnotations.grp_1_downstream.gff3"),
                down2 = rtracklayer::import.gff3("processed/annotations/gff/reviseAnnotations.grp_2_downstream.gff3"))

#Convert the GFF files into GRanges lists
granges_lists = purrr::map(gff_list, ~txrevise::revisedGffToGrangesList(.)) %>% 
  purrr::flatten() %>% 
  GRangesList()
saveRDS(granges_lists, "results/annotations/reviseAnnotations.GRangesList.rds")

#Import revised GFF files
gff_list = list(up1 = rtracklayer::import.gff3("processed/annotations/gff/txrevise.grp_1_promoters.gff3"),
                up2 = rtracklayer::import.gff3("processed/annotations/gff/txrevise.grp_2_promoters.gff3"))

#Convert the GFF files into GRanges lists
granges_lists = purrr::map(gff_list, ~txrevise::revisedGffToGrangesList(.)) %>% 
  purrr::flatten() %>% 
  GRangesList()
saveRDS(granges_lists, "results/annotations/txrevise_promoters.GRangesList.rds")