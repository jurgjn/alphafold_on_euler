
def workpath(path):
    dir_ = os.path.dirname(config['sequences'])
    return os.path.join(dir_, path)

def scratchpath(path):
    # https://scicomp.ethz.ch/wiki/Storage_systems#Local_scratch_.28on_each_compute_node.29
    dir_ = os.environ['TMPDIR']
    return os.path.join(dir_, path)

localrules: fasta_file

rule fasta_file:
    """Download sequence from UniProt, fix header to only include uniprot id
    """
    output:
        fasta = workpath('fasta_dir/{sequence}.fasta'),
    shell: """
        wget -O - https://rest.uniprot.org/uniprotkb/{wildcards.sequence}.fasta \
        | awk '{{if ($0 ~ /^>/) {{split($0,a,"|"); print ">"a[2]}} else {{ print;}}}}' - \
        > {output.fasta}
    """

rule precompute_alignments:
    # $ rm -rf results/openfold/precompute_alignments
    # $ conda activate openfold_env
    # $ smk_local precompute_alignments --snakefile workflow/targets/openfold.smk --dry-run
    # $ smk slurm precompute_alignments --snakefile workflow/targets/openfold.smk --dry-run
    input:
        fasta = 'results/openfold/fasta/{uniprot_id}.fasta',
    output:
        bfd_uniref_hits = 'results/openfold/precompute_alignments/{uniprot_id}/bfd_uniref_hits.a3m',
        hmm_output = 'results/openfold/precompute_alignments/{uniprot_id}/hmm_output.sto',
        mgnify_hits = 'results/openfold/precompute_alignments/{uniprot_id}/mgnify_hits.sto',
        uniprot_hits = 'results/openfold/precompute_alignments/{uniprot_id}/uniprot_hits.sto',
        uniref90_hits = 'results/openfold/precompute_alignments/{uniprot_id}/uniref90_hits.sto',
        sstat = 'results/openfold/precompute_alignments/{uniprot_id}/stat.tsv',
    conda: 'openfold_env'
    resources:
        runtime = lambda wildcards, attempt: ['4h', '1d', '3d', '1w'][attempt - 1]
    params:
        openfold_dir = '/cluster/work/beltrao/jjaenes/24.06.10_af2genomics/software/openfold',
        fasta_dir_scratch = lambda wc: scratchpath(f'fasta_{wc.uniprot_id}'),
        output_dir = lambda wc: f'results/openfold/precompute_alignments',
        output_dir_scratch = lambda wc: scratchpath(f'precompute_alignments_{wc.uniprot_id}'),
        workdir = '/cluster/work/beltrao/jjaenes/24.06.10_af2genomics',
    shell: """
        echo {params.openfold_dir}
        echo {params.fasta_dir_scratch}
        echo {params.output_dir}
        echo {params.output_dir_scratch}
        echo {params.workdir}
        # Set up input directory on scratch
        mkdir -p {params.fasta_dir_scratch}
        cp {input.fasta} {params.fasta_dir_scratch}/
        ls -l {params.fasta_dir_scratch}/
        # Make output directory on scratch
        mkdir -p {params.output_dir_scratch}
        # Run OpenFold on input on scratch
        cd {params.openfold_dir}
        # Turn off templates --max_template_date '1950-01-01' from: https://harvardmed.atlassian.net/wiki/spaces/O2/pages/1995177985/Using+AlphaFold+on+O2
        export BASE_DATA_DIR='/cluster/project/alphafold'
        export TEMPLATE_MMCIF_DIR=$BASE_DATA_DIR/pdb_mmcif/mmcif_files/
        date; time python3 scripts/precompute_alignments.py \
            --uniref90_database_path $BASE_DATA_DIR/uniref90/uniref90.fasta \
            --mgnify_database_path $BASE_DATA_DIR/mgnify/mgy_clusters_2018_12.fa \
            --pdb_seqres_database_path $BASE_DATA_DIR/pdb_seqres/pdb_seqres.txt \
            --uniref30_database_path $BASE_DATA_DIR/uniref30/UniRef30_2021_03 \
            --uniprot_database_path $BASE_DATA_DIR/uniprot/uniprot.fasta \
            --bfd_database_path $BASE_DATA_DIR/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
            --jackhmmer_binary_path jackhmmer \
            --hhblits_binary_path hhblits \
            --hmmsearch_binary_path hmmsearch \
            --hmmbuild_binary_path hmmbuild \
            --kalign_binary_path kalign \
            --max_template_date '1950-01-01' \
            --cpus_per_task {threads} \
            {params.fasta_dir_scratch} {params.output_dir_scratch}
        # Dummy output for testing
        #mkdir -p {params.output_dir_scratch}/{wildcards.uniprot_id}
        #touch {params.output_dir_scratch}/{wildcards.uniprot_id}/bfd_uniref_hits.a3m
        #touch {params.output_dir_scratch}/{wildcards.uniprot_id}/hmm_output.sto
        #touch {params.output_dir_scratch}/{wildcards.uniprot_id}/mgnify_hits.sto
        #touch {params.output_dir_scratch}/{wildcards.uniprot_id}/uniprot_hits.sto
        #touch {params.output_dir_scratch}/{wildcards.uniprot_id}/uniref90_hits.sto
        #sleep 10
        cd -
        # Copy output from scratch to work
        rsync -av {params.output_dir_scratch}/{wildcards.uniprot_id} {params.output_dir}
        # Log resources used
        workflow/scripts/sstat_eu > {output.sstat}
    """
'''
rule precompute_alignments_all:
    # $ rm -rf results/openfold/precompute_alignments
    # $ conda activate openfold_env
    # $ smk_local precompute_alignments_ --snakefile workflow/targets/openfold.smk --dry-run
    # date; time snakemake precompute_alignments_all --snakefile workflow/targets/openfold.smk --unlock
    input:
        expand('results/openfold/precompute_alignments/{uniprot_id}/stat.tsv', uniprot_id=fasta_input()),
'''
rule run_pretrained_openfold_multimer:
    # mkdir -p fasta_dir_multimer
    # cat fasta_dir/O43663.fasta fasta_dir/P07437.fasta fasta_dir/Q71U36.fasta > fasta_dir_multimer/O43663_P07437_Q71U36.fasta
    # profile_euler/run_local run_pretrained_openfold_multimer --snakefile workflow/targets/openfold.smk --dry-run
    # https://openfold.readthedocs.io/en/latest/Inference.html#advanced-options-for-increasing-efficiency
    input:
        fasta_dir = 'results/openfold/fasta_dir_multimer',
        use_precomputed_alignments = 'results/openfold/fasta_msas',
    output:
        dir = directory('results/openfold/run_multimer'),
        sstat = 'results/openfold/run_multimer/.sstat.tsv',
    threads: 8
    params:
        openfold_dir = '/cluster/work/beltrao/jjaenes/24.06.10_af2genomics/software/openfold',
        workdir = '/cluster/work/beltrao/jjaenes/24.06.10_af2genomics',
    shell: """
        mkdir -p {output.dir}
        module list
        cd {params.openfold_dir}
        # Turn off templates --max_template_date '1950-01-01' from: https://harvardmed.atlassian.net/wiki/spaces/O2/pages/1995177985/Using+AlphaFold+on+O2
        export BASE_DATA_DIR='/cluster/project/alphafold'
        export TEMPLATE_MMCIF_DIR=$BASE_DATA_DIR/pdb_mmcif/mmcif_files
        date; time python3 run_pretrained_openfold.py {params.workdir}/{input.fasta_dir} $TEMPLATE_MMCIF_DIR \
            --output_dir {params.workdir}/{output.dir} \
            --use_precomputed_alignments {params.workdir}/{input.use_precomputed_alignments} \
            --uniref90_database_path $BASE_DATA_DIR/uniref90/uniref90.fasta \
            --mgnify_database_path $BASE_DATA_DIR/mgnify/mgy_clusters_2018_12.fa \
            --pdb_seqres_database_path $BASE_DATA_DIR/pdb_seqres/pdb_seqres.txt \
            --uniref30_database_path $BASE_DATA_DIR/uniref30/UniRef30_2021_03 \
            --uniprot_database_path $BASE_DATA_DIR/uniprot/uniprot.fasta \
            --bfd_database_path $BASE_DATA_DIR/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
            --jackhmmer_binary_path jackhmmer \
            --hhblits_binary_path hhblits \
            --hmmsearch_binary_path hmmsearch \
            --hmmbuild_binary_path hmmbuild \
            --kalign_binary_path kalign \
            --config_preset model_1_multimer_v3 \
            --max_template_date '1950-01-01' \
            --cpus {threads} \
            --skip_relaxation \
            --use_deepspeed_evoformer_attention \
            --trace_model \
            --model_device 'cuda:0'
        cd -
        workflow/scripts/sstat_eu > {output.sstat}
    """

rule run_pretrained_openfold_help:
    # profile_euler/run_local run_pretrained_openfold_help --snakefile workflow/targets/openfold.smk --dry-run
    params:
        openfold_dir = '/cluster/work/beltrao/jjaenes/24.06.10_af2genomics/software/openfold',
        workdir = '/cluster/work/beltrao/jjaenes/24.06.10_af2genomics',
    shell: """
        cd {params.openfold_dir}
        date; time python3 run_pretrained_openfold.py --help
    """

rule run_unit_tests:
    """
    openfold rules need snakemake started in openfold_env
        $ module load stack/2024-05 gcc/13.2.0 cuda/12.2.1
        $ conda activate openfold_env
        $ profile_euler/run_local run_unit_tests --snakefile workflow/targets/openfold.smk --dry-run
    """
    params:
        openfold_dir = '/cluster/work/beltrao/jjaenes/24.06.10_af2genomics/software/openfold',
    shell: """
        module list
        cd {params.openfold_dir}
        date; time scripts/run_unit_tests.sh
    """
