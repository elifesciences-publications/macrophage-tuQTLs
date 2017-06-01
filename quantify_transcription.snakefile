#Quantify gene expression using full Ensembl annotations
rule ensembl_quant_salmon:
	input:
		fq1 = "processed/{study}/fastq/{sample}.1.fastq.gz",
		fq2 = "processed/{study}/fastq/{sample}.2.fastq.gz"
	output:
		"processed/{study}/salmon/ensembl_87/{sample}/quant.sf"
	params:
		out_prefix = "processed/{study}/salmon/ensembl_87/{sample}"
	resources:
		mem = 10000
	threads: 8	
	shell:
		"salmon --no-version-check quant --seqBias --gcBias --libType {config[libType]} "
		"--index {config[salmon_ensembl_index]} -1 {input.fq1} -2 {input.fq2} -p {threads} "
		"--geneMap {config[ensembl_gtf]} -o {params.out_prefix}"

#Align reads to the reference genome using STAR
rule star_align:
	input:
		fq1 = "processed/{study}/fastq/{sample}.1.fastq.gz",
		fq2 = "processed/{study}/fastq/{sample}.2.fastq.gz"
	output:
		bam = "processed/{study}/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam"
	params:
		prefix = "processed/{study}/STAR/{sample}/{sample}.",
		rg = "ID:1\tLB:1\tPL:Illumina\tSM:{sample}\tPU:1"
	resources:
		mem = 42000
	threads: 8
	shell:
		"STAR --runThreadN {threads} --outSAMtype BAM SortedByCoordinate --outWigType bedGraph "
		"--outWigNorm None --outWigStrand Stranded --outSAMattrRGline \"{params.rg}\" "
		"--readFilesCommand zcat --genomeDir {config[star_index]} --limitBAMsortRAM 10000000000 "
		"--outFileNamePrefix {params.prefix} --readFilesIn {input.fq1} {input.fq2} "

#Index sorted bams
rule index_bams:
	input:
		"processed/{study}/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam"
	output:
		"processed/{study}/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam.bai"
	resources:
		mem = 50
	threads: 1
	shell:
		"samtools index {input}"

#Check genotype concordance between RNA-seq and VCF
rule check_genotype_concordance:
	input:
		"processed/{study}/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam",
		"processed/{study}/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam.bai"
	output:
		"processed/{study}/verifyBamID/{sample}.verifyBamID.bestSM"
	params:
		out_prefix = "processed/{study}/verifyBamID/{sample}.verifyBamID"
	resources:
		mem = 1500
	threads: 1
	shell:
		"verifyBamID.1.1.2 --vcf {config[vcf_file]} --bam {input} --out {params.out_prefix} --best --ignoreRG"

#Convert bedgraph to bigwig
rule bedgraph_to_bigwig:
	input:
		"processed/{study}/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam"
	output:
		bw1 = "processed/{study}/bigwig/{sample}.str1.bw",
		bw2 = "processed/{study}/bigwig/{sample}.str2.bw"
	params:
		bg1 = "processed/{study}/STAR/{sample}/{sample}.Signal.Unique.str1.out.bg",
		bg2 = "processed/{study}/STAR/{sample}/{sample}.Signal.Unique.str2.out.bg",
		bg3 = "processed/{study}/STAR/{sample}/{sample}.Signal.UniqueMultiple.str1.out.bg",
		bg4 = "processed/{study}/STAR/{sample}/{sample}.Signal.UniqueMultiple.str2.out.bg"
	resources:
		mem = 1000
	threads: 1
	shell:
		"bedGraphToBigWig {params.bg1} {config[chromosome_lengths]} {output.bw1} && "
		"bedGraphToBigWig {params.bg2} {config[chromosome_lengths]} {output.bw2} && "
		"rm {params.bg1} && rm {params.bg2} && rm {params.bg3} && rm {params.bg4}"


#Convert gff3 files generated by reviseAnnotations into fasta sequence
rule convert_gff3_to_fasta:
	input:
		"processed/acLDL/annotations/gff/{annotation}.gff3"
	output:
		"processed/acLDL/annotations/fasta/{annotation}.fa"
	resources:
		mem = 1000
	threads: 1
	shell:
		"/software/team82/cufflinks/2.2.1/bin/gffread -w {output} -g {config[reference_genome]} {input}"

#Build salmon indexes for fasta files
rule construct_salmon_index:
	input:
		"processed/acLDL/annotations/fasta/{annotation}.fa"
	output:
		"processed/acLDL/annotations/salmon_index/{annotation}"
	resources:
		mem = 10000
	threads: 1
	shell:
		"salmon -no-version-check index -t {input} -i {output}"

#Quantify gene expression using full Ensembl annotations
rule reviseAnnotation_quant_salmon:
	input:
		fq1 = "processed/{study}/fastq/{sample}.1.fastq.gz",
		fq2 = "processed/{study}/fastq/{sample}.2.fastq.gz",
		salmon_index = "processed/acLDL/annotations/salmon_index/{annotation}"
	output:
		"processed/{study}/reviseAnnotations/{annotation}/{sample}/quant.sf"
	params:
		out_prefix = "processed/{study}/reviseAnnotations/{annotation}/{sample}"
	resources:
		mem = 10000
	threads: 8	
	shell:
		"salmon --no-version-check quant --seqBias --gcBias --libType {config[libType]} "
		"--index {input.salmon_index} -1 {input.fq1} -2 {input.fq2} -p {threads} "
		"-o {params.out_prefix}"

#Convert BAMs to bed for leafcutter
rule leafcutter_bam_to_bed:
	input:
		"processed/{study}/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam"
	output:
		temp("processed/{study}/leafcutter/bed/{sample}.bed")
	threads: 3
	resources:
		mem = 1000
	shell:
		"samtools view {input} | python {config[leafcutter_root]}/scripts/filter_cs.py | {config[leafcutter_root]}/scripts/sam2bed.pl --use-RNA-strand - {output}"

#Convert bed file to junctions
rule leadcutter_bed_to_junc:
	input:
		"processed/{study}/leafcutter/bed/{sample}.bed"
	output:
		"processed/{study}/leafcutter/junc/{sample}.junc"
	threads: 1
	resources:
		mem = 1000
	shell:
		"{config[leafcutter_root]}/scripts/bed2junc.pl {input} {output}"

#Cluster junctions with LeafCutter
rule leafcutter_cluster_junctions:
	input:
		expand("processed/{study}/leafcutter/junc/{sample}.junc", study = config["study"], sample = config["samples"])
	output:
		"processed/{study}/leafcutter/leafcutter_perind.counts.gz"
	params:
		junc_files = "processed/{study}/leafcutter/junction_files.txt",
		out_prefix = "processed/{study}/leafcutter/"
	threads: 1
	resources:
		mem = 1000
	shell:
		"ls --color=never processed/{study}/leafcutter/junc/*.junc | cat > {params.junc_files} && "
		"python {config[leafcutter_root]}/clustering/leafcutter_cluster.py -j {params.junc_files} -r {params.out_prefix} -m 50 -l 500000"


#Make sure that all final output files get created
rule make_all:
	input:
		expand("processed/{study}/verifyBamID/{sample}.verifyBamID.bestSM", study = config["study"], sample=config["samples"]),
		expand("processed/{study}/salmon/ensembl_87/{sample}/quant.sf", study = config["study"], sample=config["samples"]),
		expand("processed/{study}/bigwig/{sample}.str1.bw", study = config["study"], sample=config["samples"]),
		expand("processed/{study}/reviseAnnotations/{annotation}/{sample}/quant.sf", study = config["study"], annotation=config["annotations"], sample=config["samples"])
	output:
		"processed/{study}/out.txt"
	resources:
		mem = 100
	threads: 1
	shell:
		"echo 'Done' > {output}"


#Make sure that all final output files get created
rule make_macroMap:
	input:
		expand("processed/{study}/salmon/ensembl_87/{sample}/quant.sf", study = config["study"], sample=config["samples"]),
		expand("processed/{study}/bigwig/{sample}.str1.bw", study = config["study"], sample=config["samples"]),
	output:
		"processed/macroMap/out.txt"
	resources:
		mem = 100
	threads: 1
	shell:
		"echo 'Done' > {output}"




