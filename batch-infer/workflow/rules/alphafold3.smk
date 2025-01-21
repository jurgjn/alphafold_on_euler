
wildcard_constraints:
    rule = r'[^\W0-9](\w|_)*', # https://stackoverflow.com/questions/49100678/regex-matching-unicode-variable-names
    id = r'(\w|\-|_|\.)*', # https://github.com/google-deepmind/alphafold3/blob/d7758637f3a682c99ddb325869eab9f19361ebcd/src/alphafold3/common/folding_input.py#L1001-L1005

include: 'common.smk'

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

rule alphafold3_predictions:
    # Run AF3 structure prediction on all .json-s
    input:
        json = expand('alphafold3_msas/{id}_data.json.gz', id=ids),
    output:
        cifs = expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
        # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#defining-retries-for-fallible-rules
        # retries: 3
    params:
        # bind paths
        af_input = '--bind alphafold3_msas:/root/af_input',
        af_output = lambda wildcards: '--bind alphafold3_predictions:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        scripts = f'--bind {root_path("workflow/scripts")}:/app/scripts',
        docker = root_path(config['alphafold3_docker']),
        # run_alphafold.py
        #json_path = lambda wc: f'--json_path=/root/af_input/{wc.id}/{wc.id}_data.json',
        input_dir = '--input_dir=/root/af_input',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        # https://github.com/google-deepmind/alphafold3/blob/main/docs/performance.md
        xtra_args = '--norun_data_pipeline',# --flash_attention_implementation=xla',
        # Add --jax_compilation_cache_dir <YOUR_DIRECTORY>
    envmodules:
        'stack/2024-05', 'gcc/13.2.0', 'cuda/12.2.1',
    shell: """
        SMKDIR=`pwd`
        echo Running rsync from $SMKDIR to $TMPDIR
        rsync -auv $SMKDIR/ $TMPDIR --include='alphafold3_msas' --include='alphafold3_msas/*_data.json.gz' --exclude='*'
        gunzip -r $TMPDIR/alphafold3_msas/
        mkdir -p $TMPDIR/{rule}
        cd $TMPDIR
        echo Contents of $TMPDIR
        ls -l $TMPDIR
        singularity exec --nv {params.docker} sh -c 'nvidia-smi'
        singularity exec --nv --writable-tmpfs {params.af_input} {params.af_output} {params.models} {params.databases} {params.scripts} {params.docker} \
            sh -c '/app/scripts/run_alphafold.sh \
                {params.input_dir} \
                {params.output_dir} \
                {params.model_dir} \
                {params.db_dir} \
                {params.xtra_args}'
        cd -
        gzip -r $TMPDIR/{rule}/
        echo Running rsync from $TMPDIR to $SMKDIR
        rsync -auv $TMPDIR/{rule} $SMKDIR/
    """
