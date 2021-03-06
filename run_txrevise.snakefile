#Run reviseannotations for a single batch
rule run_reviseAnnotations:
	input:
		txdb = config["txdb"],
		transcript_metadata = config["transcript_metadata"]
	output:
		gff1 = "processed/annotations/reviseAnnotations/reviseAnnotations.grp_1.batch_{batch}_{n_batches}.gff3",
		gff2 = "processed/annotations/reviseAnnotations/reviseAnnotations.grp_2.batch_{batch}_{n_batches}.gff3"
	params:
		out_prefix = "processed/annotations/reviseAnnotations/",
		chunk = "'{batch} {n_batches}'"
	threads: 1
	resources:
		mem = 2000
	shell:
		"/software/R-3.4.0/bin/Rscript analysis/revise_annotations/constructTranscriptionEvents.R -t {input.txdb} "
		"-m {input.transcript_metadata} -b {params[chunk]} -o {params[out_prefix]}"

#Iterate over batches
rule merge_reviseAnnotations_batches:
	input:
		gff1 = expand("processed/annotations/reviseAnnotations/reviseAnnotations.grp_1.batch_{batch}_{n_batches}.gff3", 
			batch=[i for i in range(1, config["n_batches"] + 1)],
			n_batches = config["n_batches"]),
		gff2 = expand("processed/annotations/reviseAnnotations/reviseAnnotations.grp_2.batch_{batch}_{n_batches}.gff3", 
			batch=[i for i in range(1, config["n_batches"] + 1)],
			n_batches = config["n_batches"])
	output:
		gff1 = "processed/annotations/reviseAnnotations/merged/reviseAnnotations.grp_1.gff3",
		gff2 = "processed/annotations/reviseAnnotations/merged/reviseAnnotations.grp_2.gff3"
	resources:
		mem = 100
	threads: 1
	shell:
		'cat {input.gff1} | grep -v "^#" > {output.gff1} && '
		'cat {input.gff2} | grep -v "^#" > {output.gff2}'

rule split_gff_to_events:
	input:
		gff1 = "processed/annotations/reviseAnnotations/merged/reviseAnnotations.grp_1.gff3",
		gff2 = "processed/annotations/reviseAnnotations/merged/reviseAnnotations.grp_2.gff3"
	output:
		meta = "processed/annotations/reviseAnnotations/events/reviseAnnotations.transcript_metadata.txt"
	params:
		out_folder = "processed/annotations/reviseAnnotations/events/"
	threads: 1
	resources:
		mem = 3000
	shell:
		"/software/R-3.4.0/bin/Rscript analysis/revise_annotations/splitEventGFFs.R "
		"-a {input.gff1} -b {input.gff2} -o {params.out_folder}"
