nextflow.enable.dsl=2

params.reads = null     // Input FASTQ files    
params.outdir = "$baseDir/results"      // Output directory
params.cpus = 2 // Number of CPUs for each process

// Define the process containers for workflow 
workflow {

    if (!params.reads) {
        error "Please provide input FASTQ files using --reads 'path/*_{R1,R2}.fastq.gz'"
    }

    reads_ch = Channel.fromFilePairs(params.reads, flat: true)

    trimmed_reads = fastp(reads_ch)

    megahit(trimmed_reads)
    seqkit(trimmed_reads)
}

process fastp {
    tag "$sample_id"
    publishDir "${params.outdir}/fastp", mode: 'copy'

    input:
    tuple val(sample_id), file(read1), file(read2)

    output:
    tuple val(sample_id), file("${sample_id}_trimmed_R1.fastq.gz"), file("${sample_id}_trimmed_R2.fastq.gz")

    script:
    """
    fastp -i $read1 -I $read2 \
          -o ${sample_id}_trimmed_R1.fastq.gz \
          -O ${sample_id}_trimmed_R2.fastq.gz \
          -j ${sample_id}_fastp.json -h ${sample_id}_fastp.html
    """
}

process megahit {
    tag "$sample_id"
    publishDir "${params.outdir}/assembly", mode: 'copy'

    input:
    tuple val(sample_id), file(trimmed1), file(trimmed2)

    output:
    file("${sample_id}_megahit_contigs.fasta")

    script:
    """
    megahit \
        -1 $trimmed1 \
        -2 $trimmed2 \
        -o ${sample_id}_megahit_output \
        --num-cpu-threads ${task.cpus}

    cp ${sample_id}_megahit_output/final.contigs.fa ${sample_id}_megahit_contigs.fasta
    """
}

process seqkit {
    tag "$sample_id"
    publishDir "${params.outdir}/stats", mode: 'copy'

    input:
    tuple val(sample_id), file(trimmed1), file(trimmed2)

    output:
    file("${sample_id}_read_stats.txt")

    script:
    """
    seqkit stats $trimmed1 $trimmed2 > ${sample_id}_read_stats.txt
    """
}
