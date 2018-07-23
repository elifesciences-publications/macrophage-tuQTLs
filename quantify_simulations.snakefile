#Convert gff3 files generated by reviseAnnotations into fasta sequence
rule convert_gff3_to_fasta:
	input:
		"processed/annotations/gff/{annotation}.gff3"
	output:
		"processed/annotations/fasta/{annotation}.fa"
	resources:
		mem = 1000
	threads: 1
	shell:
		"""
		module load cufflinks2.2
		module load python-2.7.13
		gffread -w {output} -g {config[reference_genome]} {input}
		"""


#Build salmon indexes for fasta files
rule construct_salmon_index:
	input:
		"processed/annotations/fasta/{annotation}.fa"
	output:
		"processed/annotations/salmon_index/{annotation}"
	resources:
		mem = 10000
	threads: 1
	shell:
		"salmon -no-version-check index -t {input} -i {output}"

#Quantify gene expression using full Ensembl annotations
rule reviseAnnotation_quant_salmon:
	input:
		fq1 = "processed/{study}/fastq/{sample}_1.fasta.gz",
		fq2 = "processed/{study}/fastq/{sample}_2.fasta.gz",
		salmon_index = "processed/annotations/salmon_index/{annotation}"
	output:
		"processed/{study}/salmon/{annotation}/{sample}/quant.sf"
	params:
		out_prefix = "processed/{study}/salmon/{annotation}/{sample}"
	resources:
		mem = 10000
	threads: 8	
	shell:
		"salmon --no-version-check quant --validateMappings --minScoreFraction 0.9 --noLengthCorrection --noFragLengthDist --noEffectiveLengthCorrection --libType {config[libType]} "
		"--index {input.salmon_index} -1 {input.fq1} -2 {input.fq2} -p {threads} "
		"-o {params.out_prefix}"

#Merge Salmon results
rule merge_salmon:
	input:
		expand("processed/{{study}}/salmon/{{annotation}}/{sample}/quant.sf", sample=config["samples"])
	output:
		"processed/{study}/matrices/{annotation}.salmon_txrevise.rds"
	params:
		sample_ids = ','.join(config["samples"]),
		dir = "processed/{study}/salmon/{annotation}"
	threads: 1
	resources:
		mem = 12000
	shell:
		"""
		module load R-3.4.1
		Rscript scripts/merge_Salmon.R -s {params.sample_ids} -d {params.dir} -o {output}
		"""

rule make_fastq:
	input:
		fa1 = "processed/{study}/fastq/{sample}_1.fasta.gz",
		fa2 = "processed/{study}/fastq/{sample}_2.fasta.gz"
	output:
		fq1 = "processed/{study}/fq/{sample}_1.fq.gz",
		fq2 = "processed/{study}/fq/{sample}_2.fq.gz"
	resources:
		mem = 100
	threads: 1
	shell:
		"""
		module load perl-5.22.0
		perl scripts/fasta_to_fastq.pl {input.fa1} | gzip > {output.fq1}
		perl scripts/fasta_to_fastq.pl {input.fa2} | gzip > {output.fq2}
		"""

rule quantify_whippet:
	input:
		fq1 = "processed/{study}/fq/{sample}_1.fq.gz",
		fq2 = "processed/{study}/fq/{sample}_2.fq.gz"
	output:
		"processed/{study}/whippet/{sample}.psi.gz"
	params:
		out = "processed/{study}/whippet/{sample}"
	resources:
		mem = 1000
	threads: 1
	shell:
		"""
		module load julia-0.6.0
		julia ~/.julia/v0.6/Whippet/bin/whippet-quant.jl {input.fq1} {input.fq2} -o {params.out} -x {config[whippet_index]}
		"""

#Make sure that all final output files get created
rule make_all:
	input:
		expand("processed/{{study}}/matrices/{annotation}.salmon_txrevise.rds", annotation=config["annotations"]),
		expand("processed/{{study}}/whippet/{sample}.psi.gz", sample=config["samples"])
	output:
		"processed/{study}/out.txt"
	resources:
		mem = 100
	threads: 1
	shell:
		"echo 'Done' > {output}"