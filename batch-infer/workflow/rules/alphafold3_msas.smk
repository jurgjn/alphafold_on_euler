
rule alphafold3_msas:
    """
    Run AF3 data pipeline for one input .json
    """
    input:
        json = 'alphafold3_jsons/{id}.json',
    output:
        json = 'alphafold3_msas/{id}_data.json.gz',
    params:
        # bind paths
        af_input = '--bind alphafold3_jsons:/root/af_input',
        af_output = '--bind alphafold3_msas:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        #databases_fallback = f'--bind {config["alphafold3_databases_fallback"]}:/root/public_databases_fallback',
        docker = root_path(config['alphafold3_docker']),
        # run_alphafold.py
        json_path = lambda wc: f'--json_path=/root/af_input/{wc.id}.json',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        #db_dir_fallback = '--db_dir=/root/public_databases_fallback',
        xtra_args = '--norun_inference',
    envmodules:
        'stack/2024-05', 'gcc/13.2.0',
    # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#defining-retries-for-fallible-rules
    # Re-attempt (failed) MSAs with increasing runtimes (4h, 1d, 3d)
    retries: 3
    shell: """
        SMKDIR=`pwd`
        rsync -auq $SMKDIR/ $TMPDIR --include='alphafold3_jsons' --include='{input.json}' --exclude='*'
        mkdir -p $TMPDIR/alphafold3_msas
        cd $TMPDIR
        singularity exec {params.af_input} {params.af_output} {params.models} {params.databases} {params.docker} \
            sh -c 'python3 /app/alphafold/run_alphafold.py \
                {params.json_path} \
                {params.output_dir} \
                {params.model_dir} \
                {params.db_dir} \
                {params.xtra_args}'
        cd -
        gzip $TMPDIR/alphafold3_msas/{wildcards.id}/{wildcards.id}_data.json
        cp $TMPDIR/alphafold3_msas/{wildcards.id}/{wildcards.id}_data.json.gz $SMKDIR/alphafold3_msas/{wildcards.id}_data.json.gz
    """
