
wildcard_constraints:
    rule = r'[^\W0-9]\w*', # https://stackoverflow.com/questions/49100678/regex-matching-unicode-variable-names
    id = r'[^\W0-9]\w*',

include: 'common.smk'

ids, = glob_wildcards('alphafold3_jsons/{id}.json')
print(ids)

rule alphafold3_msas:
    """
    Predict structure for single-input
    """
    input:
        json = 'alphafold3_jsons/{id}.json',
    output:
        json = 'alphafold3_msas/{id}_data.json',
    params:
        # bind paths
        af_input = '--bind alphafold3_jsons:/root/af_input',
        af_output = '--bind alphafold3_msas:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        docker = root_path(config['alphafold3_docker']),
        # run_alphafold.py
        json_path = lambda wc: f'--json_path=/root/af_input/{wc.id}.json',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        xtra_args = '--norun_inference',
    envmodules:
        'stack/2024-05', 'gcc/13.2.0',
    shell: """
        echo 'pwd:' `pwd`
        pwd
        echo {input.json}
        echo {output.json}
        singularity exec {params.af_input} {params.af_output} {params.models} {params.databases} {params.docker} \
            sh -c 'python3 /app/alphafold/run_alphafold.py \
                {params.json_path} \
                {params.output_dir} \
                {params.model_dir} \
                {params.db_dir} \
                {params.xtra_args}'
        mv alphafold3_msas/{wildcards.id}/{wildcards.id}_data.json alphafold3_msas/{wildcards.id}_data.json
        rm -rf alphafold3_msas/{wildcards.id}
    """


rule alphafold3_predictions:
    input:
        json = expand('alphafold3_msas/{id}_data.json', id=ids),
    output:
        cifs = expand('alphafold3_predictions/{id}/{id}_model.cif', id=ids),
    params:
        # bind paths
        af_input = '--bind alphafold3_msas:/root/af_input',
        af_output = '--bind alphafold3_predictions:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
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
        singularity exec --nv {params.docker} sh -c 'nvidia-smi'
        singularity exec --nv {params.af_input} {params.af_output} {params.models} {params.databases} {params.docker} \
            sh -c 'python3 /app/alphafold/run_alphafold.py \
                {params.input_dir} \
                {params.output_dir} \
                {params.model_dir} \
                {params.db_dir} \
                {params.xtra_args}'
    """

rule alphafold3:
    input:
        expand('alphafold3_predictions/{id}/{id}_model.cif', id=ids),
