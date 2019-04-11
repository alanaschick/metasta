# **********************************
# * Snakefile for metqc pipeline *
# **********************************

# **** Variables ****

configfile: "config.yaml"

import pandas as pd
SAMPLES = pd.read_csv(config["list_files"], header = None)
SAMPLES = SAMPLES[0].tolist()

# **** Rules ****

rule all:
    input:
        expand("data/bbmap/{sample}_unmapped_1.fastq", sample=SAMPLES),
        expand("data/bbmap/{sample}_unmapped_2.fastq", sample=SAMPLES),
        "results/multiqc_report_raw.html",
        "results/multiqc_report_filtered.html"

rule fastqc_raw:
    input:
        r1 = "data/rawdata/{sample}_1.fastq.gz",
        r2 = "data/rawdata/{sample}_2.fastq.gz"
    output:
        r1 = "data/rawdata/fastqc/{sample}_1_fastqc.html",
        r2 = "data/rawdata/fastqc/{sample}_2_fastqc.html"
    conda: "envs/fastqc_env.yaml"
    shell: "fastqc -o data/rawdata/fastqc {input.r1} {input.r2}"

rule multiqc_raw:
    input:
        r1 = expand("data/rawdata/fastqc/{sample}_1_fastqc.html", sample=SAMPLES),
        r2 = expand("data/rawdata/fastqc/{sample}_2_fastqc.html", sample=SAMPLES)
    output: "results/multiqc_report_raw.html"
    conda: "envs/multiqc_env.yaml"
    shell: "multiqc -f data/rawdata/fastqc -o results -n multiqc_report_raw.html"

rule cutadapt:
    input:
        r1 = "data/rawdata/{sample}_1.fastq.gz",
        r2 = "data/rawdata/{sample}_2.fastq.gz"
    output:
        r1 = "data/trimdata/{sample}_r1_trim.fastq.gz",
        r2 = "data/trimdata/{sample}_r2_trim.fastq.gz"
    conda: "envs/cutadapt_env.yaml"
    shell:
            "cutadapt -m 60 -a {config[fwd_adapter]} "
            "-A {config[rev_adapter]} -o {output.r1} -p {output.r2} "
            "{input.r1} {input.r2}"

rule decompress:
    input:
        r1 = "data/trimdata/{sample}_r1_trim.fastq.gz",
        r2 = "data/trimdata/{sample}_r2_trim.fastq.gz"
    output:
        r1 = "data/trimdata/{sample}_r1_trim.fastq",
        r2 = "data/trimdata/{sample}_r2_trim.fastq"
    shell:
            "gunzip -c {input.r1} > {output.r1}; gunzip -c {input.r2} > {output.r2}"

rule prinseq:
    input:
        r1 = "data/trimdata/{sample}_r1_trim.fastq",
        r2 = "data/trimdata/{sample}_r2_trim.fastq"
    params:
        prefix = "data/filtdata/{sample}_filtered"
    output:
        r1 = "data/filtdata/{sample}_filtered_1.fastq",
        r2 = "data/filtdata/{sample}_filtered_2.fastq"
    conda: "envs/prinseq_env.yaml"
    shell:
            "perl scripts/prinseq-lite.pl -fastq {input.r1} -fastq2 {input.r2} "
            "-out_good {params.prefix} -out_bad null -lc_method dust -lc_threshold 7 "
            "-derep 1"

rule fastqc_filt:
    input:
        r1 = "data/filtdata/{sample}_filtered_1.fastq",
        r2 = "data/filtdata/{sample}_filtered_2.fastq"
    output:
        r1 = "data/filtdata/fastqc/{sample}_filtered_1_fastqc.html",
        r2 = "data/filtdata/fastqc/{sample}_filtered_2_fastqc.html"
    conda: "envs/fastqc_env.yaml"
    shell: "fastqc -o data/filtdata/fastqc {input.r1} {input.r2}"

rule multiqc_filt:
    input:
        r1 = expand("data/filtdata/fastqc/{sample}_filtered_1_fastqc.html", sample=SAMPLES),
        r2 = expand("data/filtdata/fastqc/{sample}_filtered_2_fastqc.html", sample=SAMPLES)
    output: "results/multiqc_report_filtered.html"
    conda: "envs/multiqc_env.yaml"
    shell: "multiqc -f data/filtdata/fastqc -o results -n multiqc_report_filtered.html"

rule bmtagger:
    input:
        r1 = "data/filtdata/{sample}_filtered_1.fastq",
        r2 = "data/filtdata/{sample}_filtered_2.fastq"
    output: "data/bmtagger/{sample}_nohuman"
    conda: "envs/bmtagger_env.yaml"
    shell:
        "bmtagger.sh -b ref_files/hg19/hg19_rRNA_mito_Hsapiens_rna_reference.bitmask "
        "-x ref_files/hg19/hg19_rRNA_mito_Hsapiens_rna_reference.srprism -q 1 -1 {input.r1} "
        "-2 {input.r2} -o {output} -X"

rule bbmap:
    input: "data/bmtagger/{sample}_nohuman"
    output:
        ur1 = "data/bbmap/{sample}_unmapped_1.fastq",
        ur2 = "data/bbmap/{sample}_unmapped_2.fastq",
        mr1 = "data/bbmap/{sample}_mapped_1.fastq",
        mr2 = "data/bbmap/{sample}_mapped_2.fastq"
    params:
        u = "data/bbmap/{sample}_unmapped_#.fastq",
        m = "data/bbmap/{sample}_mapped_#.fastq"
    conda: "envs/bbmap_env.yaml"
    shell:
        "bbmap.sh in={input}_#.fastq outu={params.u} outm={params.m} ref={config[bbmap_ref]} nodisk bhist=results/bbmap_bhist.txt scafstats=results/bbmap_scafstats.txt"
