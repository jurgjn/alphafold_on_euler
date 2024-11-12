
rule alphafold3_msa:
    '''
    """
    Predict structure for single-input
    """
    input:
        csv = config['colabfold_input_csv'],
        a3m = 'colabfold_msas/{id}.a3m'
    output:
        done = 'colabfold_predictions/{id}.result.zip',
    '''
    params:
        docker = root_path(config['alphafold3_docker']),
        af_input = '--bind af_input:/root/af_input',
        af_output = '--bind af_output:/root/af_output',
        models = '--bind /cluster/work/beltrao/jjaenes/24.11.11_af3_models:/root/models',
        databases = '--bind /cluster/work/beltrao/jjaenes/24.11.11_af3_databases:/root/public_databases',
        json_path ='--json_path=/root/af_input/example_2PV7.json',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        output_dir = '--output_dir=/root/af_output',
    envmodules:
        'stack/2024-05', 'gcc/13.2.0', 'cuda/12.2.1',
    shell: """
        singularity exec --nv {params.af_input} {params.af_output} {params.models} {params.databases} {params.docker} sh -c 'python3 /app/alphafold/run_alphafold.py {params.json_path} {params.model_dir} {params.db_dir} {params.output_dir} --norun_inference'
    """

rule alphafold3_imgtest:
    params:
        docker = root_path(config['alphafold3_docker']),
    envmodules:
        'stack/2024-05', 'gcc/13.2.0', 'cuda/12.2.1',
    shell: """
        singularity exec --nv {params.docker} sh -c 'nvidia-smi'
        singularity exec --nv {params.docker} sh -c 'python3 /app/alphafold/run_alphafold.py --help'
    """