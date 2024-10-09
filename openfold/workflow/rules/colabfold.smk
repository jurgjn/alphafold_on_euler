"""
[YoshitakaMo/localcolabfold](https://github.com/YoshitakaMo/localcolabfold)
[How to set up and use local MMseqs2 server with ColabFold Docker sokrypton/ColabFold](https://github.com/sokrypton/ColabFold/issues/636)
[Dockerized Colabfold for large-scale batch predictions | Oxford Protein Informatics Group](https://www.blopig.com/blog/2024/04/dockerized-colabfold-for-large-scale-batch-predictions/)
[Running ColabFold in Docker](https://github.com/sokrypton/ColabFold/wiki/Running-ColabFold-in-Docker)
"""

localrules: colabfold_docker
rule colabfold_docker:
    """
    date; time snakemake --profile smk-simple-slurm-eu colabfold_docker
    Download colabfold docker image & convert to Singularity
    https://github.com/sokrypton/ColabFold/wiki/Running-ColabFold-in-Docker
    """
    output: 'software/colabfold/colabfold_1.5.5-cuda11.8.0.sif'
    shell: """
        cd software/colabfold
        singularity pull docker://ghcr.io/sokrypton/colabfold:1.5.5-cuda11.8.0
    """

localrules: colabfold_cache
rule colabfold_cache:
    """
    date; time snakemake --profile smk-simple-slurm-eu colabfold_cache --dry-run

    Set up colabfold sequence databases using the colabfold Singularity image to exactly match mmseqs etc versions:
        date; time snakemake --profile smk-simple-slurm-eu colabfold_multimer_setup_databases
    
    Output will be under software/colabfold/database
    """
    output: directory('software/colabfold/cache')
    shell: """
        mkdir -p {output}
        singularity run -B {output}:/cache \
            {rules.colabfold_docker.output} \
            python -m colabfold.download
    """

rule colabfold_setup_databases:
    """
    Set up colabfold sequence databases:
    - start with example from [here](https://colabfold.mmseqs.com)
    - disable indexing with `MMSEQS_NO_INDEX=1` as in [here](https://github.com/sokrypton/ColabFold/blob/main/README.md)
    - match to mmseqs versions used later by running on the [Singularity/Apptainer image](https://github.com/sokrypton/ColabFold/wiki/Running-ColabFold-in-Docker)

    Run with:
        date; time snakemake --profile smk-simple-slurm-eu colabfold_setup_databases --dry-run
    
    Output will be under software/colabfold/database

    Last step (PDB_MMCIF_READY) will fail as image does not have rsync; run locally
    """
    #output:
    #    dir = directory('software/colabfold/database/')
    #    #'software/colabfold/database/UNIREF30_READY',
    #    #'software/colabfold/database/COLABDB_READY',
    #    #'software/colabfold/database/PDB_READY',
    #    #'software/colabfold/database/PDB100_READY',
    #    #'software/colabfold/database/PDB_MMCIF_READY',
    shell: """
        module load eth_proxy
        cd software/colabfold
        #wget https://raw.githubusercontent.com/sokrypton/ColabFold/main/setup_databases.sh
        #chmod +x setup_databases.sh
        mkdir -p database
        singularity exec -B $(pwd):/work --env MMSEQS_NO_INDEX=1 colabfold_1.5.5-cuda11.8.0.sif ./setup_databases.sh database/
        myjobs -j $SLURM_JOB_ID
    """

#localrules: colabfold_search
rule colabfold_search:
    """
    Test locally with: 
        $ srun --ntasks=16 --mem-per-cpu=4G --time=1-0 --pty bash -l
        $ date; time snakemake --profile smk-simple-slurm-eu colabfold_search --dry-run

    Add `--prefilter-mode 1` for faster small queries (https://github.com/sokrypton/ColabFold/wiki)
    """
    input:
        csv = 'results/missing_pairs/colabfold_input.csv',
        #output:
        #dir = 'results/example_colabfold/colabfold_search_msas/',
    shell: """
        singularity run -B {rules.colabfold_cache.output}:/cache -B $(pwd):/work -B $WORK {rules.colabfold_docker.output} \
            colabfold_search --threads {threads} results/missing_pairs/colabfold_input.csv software/colabfold/database results/missing_pairs/colabfold_msas
        myjobs -j $SLURM_JOB_ID
    """

rule colabfold_batch:
    """
    Test locally with:
        srun --ntasks=1 --mem-per-cpu=16G --time=1-0 --gpus=1 --gres=gpumem:11g --pty bash -l
    colabfold_batch --num-models 1 /work/{input.msas} /work/{output.predictions}
    """
    input:
        msas = 'results/missing_pairs/colabfold_msas',
    #output:
    #    predictions = 'results/missing_pairs/colabfold_predictions'
    envmodules:
        'stack/.2024-04-silent', 'gcc/8.5.0', 'cuda/11.8.0',
    shell: """
        singularity run --nv -B {rules.colabfold_cache.output}:/cache -B $(pwd):/work -B $WORK {rules.colabfold_docker.output} \
            colabfold_batch --num-models 1 /work/{input.msas} /work/results/missing_pairs/colabfold_predictions
        myjobs -j $SLURM_JOB_ID
    """
