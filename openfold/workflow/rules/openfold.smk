
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
    input:
        fasta = workpath('fasta_dir/{sequence}.fasta'),
    output:
        bfd_uniref_hits = workpath('precompute_alignments/{sequence}/bfd_uniref_hits.a3m'),
        hmm_output = workpath('precompute_alignments/{sequence}/hmm_output.sto'),
        mgnify_hits = workpath('precompute_alignments/{sequence}/mgnify_hits.sto'),
        uniprot_hits = workpath('precompute_alignments/{sequence}/uniprot_hits.sto'),
        uniref90_hits = workpath('precompute_alignments/{sequence}/uniref90_hits.sto'),
        sstat = workpath('precompute_alignments/{sequence}/sstat.tsv'),
    conda: 'openfold_env'
    resources: runtime = runtime_eu
    params:
        fasta_dir_scratch = lambda wc: scratchpath(f'fasta_{wc.sequence}'),
        output_dir = lambda wc: workpath('precompute_alignments'),
        output_dir_scratch = lambda wc: scratchpath(f'precompute_alignments_{wc.sequence}'),
    shell: """
        echo {params.fasta_dir_scratch}
        echo {params.output_dir}
        echo {params.output_dir_scratch}

        # Set up input directory on scratch
        mkdir -p {params.fasta_dir_scratch}
        cp {input.fasta} {params.fasta_dir_scratch}/
        echo "Set up fasta_dir on scratch: {params.fasta_dir_scratch}"
        ls -l {params.fasta_dir_scratch}/

        # Make output directory on scratch
        mkdir -p {params.output_dir_scratch}
        echo "Set up output_dir on scratch: {params.output_dir_scratch}"
        ls -l {params.output_dir_scratch}/

        # Run OpenFold
        echo "Running OpenFold"
        cd {config[openfold_dir]}
        date; time python3 scripts/precompute_alignments.py {params.fasta_dir_scratch} {params.output_dir_scratch} \
            {config[uniref90_database_path]} \
            {config[mgnify_database_path]} \
            {config[pdb_seqres_database_path]} \
            {config[uniref30_database_path]} \
            {config[uniprot_database_path]} \
            {config[bfd_database_path]} \
            {config[binary_paths]} \
            {config[max_template_date][no_templates]} \
            --cpus_per_task {threads}

        # Dummy output for testing
        #mkdir -p {params.output_dir_scratch}/{wildcards.sequence}
        #touch {params.output_dir_scratch}/{wildcards.sequence}/bfd_uniref_hits.a3m
        #touch {params.output_dir_scratch}/{wildcards.sequence}/hmm_output.sto
        #touch {params.output_dir_scratch}/{wildcards.sequence}/mgnify_hits.sto
        #touch {params.output_dir_scratch}/{wildcards.sequence}/uniprot_hits.sto
        #touch {params.output_dir_scratch}/{wildcards.sequence}/uniref90_hits.sto
        #sleep 10

        echo "Logging resources to: {params.output_dir_scratch}/{wildcards.sequence}/sstat.tsv" 
        sstat --all --parsable2 --job $SLURM_JOB_ID | tr '|' '\\t' > {params.output_dir_scratch}/{wildcards.sequence}/sstat.tsv

        # Copy output from scratch to work
        rsync -av {params.output_dir_scratch}/{wildcards.sequence} {params.output_dir}
        myjobs -j $SLURM_JOB_ID
    """

def run_multimer_input(wildcards):
    return {
        'fasta': [ workpath(f'fasta_dir/{sequence}.fasta') for sequence in wildcards.sequences.split('+') ],
        'precompute_alignments': [ workpath(f'precompute_alignments/{sequence}/sstat.tsv') for sequence in wildcards.sequences.split('+') ],
    }

rule run_multimer:
    # rm -rf /scratch/tmp.3327534.jjaenes/*; rm examples/two_small_proteins/run_multimer_fasta_dir/O00244,O00244.fasta
    # ./openfold-eu --config sequences='examples/two_small_proteins/two_small_proteins.txt' --rerun-triggers input
    # ./openfold-eu --config sequences='examples/two_small_proteins/two_small_proteins.txt' --rerun-triggers input
    input:
        unpack(run_multimer_input)
    output:
        fasta = workpath('run_multimer_fasta_dir/{sequences}.fasta'),
        sstat = workpath('run_multimer_output_dir/{sequences}/sstat.tsv'),
        nvidia_smi = workpath('run_multimer_output_dir/{sequences}/nvidia-smi.csv'),
        # Add output: unrelaxed model, pkl?
    envmodules:
        'stack/2024-04',
        'gcc/8.5.0',
        'cuda/11.8.0',
    conda:
        'openfold_env',
    resources:
        runtime = runtime_eu,
        #slurm_extra = slurm_extra_eu,
    params:
        fasta_dir_scratch = lambda wc: scratchpath(f'run_multimer_fasta_dir'),
        output_dir_scratch = lambda wc: scratchpath(f'run_multimer_output_dir/{wc.sequences}'),
        precompute_alignments_dir = lambda wc: workpath('precompute_alignments'),
        src_dir = lambda wc: scratchpath(''),
        dest_dir = lambda wc: workpath(''),
        xdg_cache_home = lambda wc: scratchpath('_xdg_cache'),
    shell: """
        export XDG_CACHE_HOME={params.xdg_cache_home}
        mkdir -p $XDG_CACHE_HOME {params.fasta_dir_scratch} {params.output_dir_scratch}

        # Set up input directory on scratch
        cat {input.fasta} > {params.fasta_dir_scratch}/{wildcards.sequences}.fasta

        echo 'Logging GPU usage to: {params.output_dir_scratch}/nvidia-smi.csv'
        stdbuf -i0 -o0 -e0 workflow/scripts/nvidia-smi-log {params.output_dir_scratch}/nvidia-smi.csv &

        echo "Running OpenFold"
        cd {config[openfold_dir]}
        date; time python3 run_pretrained_openfold.py {params.fasta_dir_scratch} {config[template_mmcif_dir]} \
            --output_dir {params.output_dir_scratch} \
            --use_precomputed_alignments {params.precompute_alignments_dir} \
            {config[uniref90_database_path]} \
            {config[mgnify_database_path]} \
            {config[pdb_seqres_database_path]} \
            {config[uniref30_database_path]} \
            {config[uniprot_database_path]} \
            {config[bfd_database_path]} \
            {config[binary_paths]} \
            {config[max_template_date][no_templates]} \
            --config_preset model_1_multimer_v3 \
            --save_outputs \
            --cpus {threads} \
            --skip_relaxation \
            --long_sequence_inference \
            --model_device 'cuda:0'
        cd -

        echo "Logging resources to: {params.output_dir_scratch}/sstat.tsv"
        workflow/scripts/sstat-log > {params.output_dir_scratch}/sstat.tsv

        echo "Syncing back {params.src_dir} {params.dest_dir}"
        rsync -auq {params.src_dir} {params.dest_dir} --include='run_multimer_fasta_dir/***' --include='run_multimer_output_dir/***' --exclude='*'
        myjobs -j $SLURM_JOB_ID
    """

rule openfold_setup:
    # Refactor into localrules - openfold_setup_clean
    # rm -rf $XDG_CACHE_HOME
    # mamba env remove -n openfold_env -y; rm -rf software/openfold
    # ./openfold-eu openfold_setup --use-conda --use-envmodules --restart-times=0
    envmodules:
        'eth_proxy',
        'stack/2024-04',
        'gcc/8.5.0',
        'cuda/11.8.0',
    params:
        xdg_cache_home = lambda wc: scratchpath('_xdg_cache')
    shell: """
        export XDG_CACHE_HOME={params.xdg_cache_home}
        time jupyter nbconvert --to notebook --inplace --execute software/openfold-setup.ipynb
    """

rule run_unit_tests:
    # ./openfold-eu run_unit_tests --use-conda --use-envmodules --restart-times=0
    envmodules:
        'stack/2024-04',
        'gcc/8.5.0',
        'cuda/11.8.0',
    conda:
        'openfold_env',
    params:
        xdg_cache_home = lambda wc: scratchpath('_xdg_cache'),
    shell: """
        module load stack/2024-04 gcc/8.5.0 cuda/11.8.0
        export XDG_CACHE_HOME={params.xdg_cache_home}
        cd software/openfold
        time scripts/run_unit_tests.sh
    """

localrules: run_pretrained_openfold_help

rule run_pretrained_openfold_help:
    conda: 'openfold_env'
    shell: """
        cd software/openfold
        date; time python3 run_pretrained_openfold.py --help
    """