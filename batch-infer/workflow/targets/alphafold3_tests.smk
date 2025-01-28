
ids = ['example_2pv7',]

include: '../rules/alphafold3.smk'

use rule alphafold3_predictions as alphafold3_predictions_rtx_2080_ti with:
    output:
        cifs = expand('alphafold3_predictions_rtx_2080_ti/{id}/{id}_model.cif', id=ids), # Possible snakemake bug where {rule} does not get updated
    params:
        af_input = '--bind alphafold3_msas:/root/af_input',
        af_output = '--bind alphafold3_predictions_rtx_2080_ti:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        scripts = f'--bind {root_path("workflow/scripts")}:/app/scripts',
        docker = root_path(config['alphafold3_docker']),
        input_dir = '--input_dir=/root/af_input',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        xtra_args = '--norun_data_pipeline --flash_attention_implementation=xla --buckets=596',

use rule alphafold3_predictions as alphafold3_predictions_rtx_3090 with:
    output:
        cifs = expand('alphafold3_predictions_rtx_3090/{id}/{id}_model.cif', id=ids),
    params:
        af_input = '--bind alphafold3_msas:/root/af_input',
        af_output = '--bind alphafold3_predictions_rtx_3090:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        scripts = f'--bind {root_path("workflow/scripts")}:/app/scripts',
        docker = root_path(config['alphafold3_docker']),
        input_dir = '--input_dir=/root/af_input',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        xtra_args = '--norun_data_pipeline',

use rule alphafold3_predictions as alphafold3_predictions_rtx_4090 with:
    output:
        cifs = expand('alphafold3_predictions_rtx_4090/{id}/{id}_model.cif', id=ids),
    params:
        af_input = '--bind alphafold3_msas:/root/af_input',
        af_output = '--bind alphafold3_predictions_rtx_4090:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        scripts = f'--bind {root_path("workflow/scripts")}:/app/scripts',
        docker = root_path(config['alphafold3_docker']),
        input_dir = '--input_dir=/root/af_input',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        xtra_args = '--norun_data_pipeline',

use rule alphafold3_predictions as alphafold3_predictions_titan_rtx with:
    output:
        cifs = expand('alphafold3_predictions_titan_rtx/{id}/{id}_model.cif', id=ids),
    params:
        af_input = '--bind alphafold3_msas:/root/af_input',
        af_output = '--bind alphafold3_predictions_titan_rtx:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        scripts = f'--bind {root_path("workflow/scripts")}:/app/scripts',
        docker = root_path(config['alphafold3_docker']),
        input_dir = '--input_dir=/root/af_input',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        xtra_args = '--norun_data_pipeline --flash_attention_implementation=xla',

use rule alphafold3_predictions as alphafold3_predictions_quadro_rtx_6000 with:
    output:
        cifs = expand('alphafold3_predictions_quadro_rtx_6000/{id}/{id}_model.cif', id=ids),
    params:
        af_input = '--bind alphafold3_msas:/root/af_input',
        af_output = '--bind alphafold3_predictions_quadro_rtx_6000:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        scripts = f'--bind {root_path("workflow/scripts")}:/app/scripts',
        docker = root_path(config['alphafold3_docker']),
        input_dir = '--input_dir=/root/af_input',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        xtra_args = '--norun_data_pipeline --flash_attention_implementation=xla',

use rule alphafold3_predictions as alphafold3_predictions_v100 with:
    output:
        cifs = expand('alphafold3_predictions_v100/{id}/{id}_model.cif', id=ids),
    params:
        af_input = '--bind alphafold3_msas:/root/af_input',
        af_output = '--bind alphafold3_predictions_v100:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        scripts = f'--bind {root_path("workflow/scripts")}:/app/scripts',
        docker = root_path(config['alphafold3_docker']),
        input_dir = '--input_dir=/root/af_input',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        xtra_args = '--norun_data_pipeline --flash_attention_implementation=xla',

use rule alphafold3_predictions as alphafold3_predictions_a100_pcie_40gb with:
    output:
        cifs = expand('alphafold3_predictions_a100_pcie_40gb/{id}/{id}_model.cif', id=ids),
    params:
        af_input = '--bind alphafold3_msas:/root/af_input',
        af_output = '--bind alphafold3_predictions_a100_pcie_40gb:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        scripts = f'--bind {root_path("workflow/scripts")}:/app/scripts',
        docker = root_path(config['alphafold3_docker']),
        input_dir = '--input_dir=/root/af_input',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        xtra_args = '--norun_data_pipeline',

use rule alphafold3_predictions as alphafold3_predictions_a100_80gb with:
    output:
        cifs = expand('alphafold3_predictions_a100_80gb/{id}/{id}_model.cif', id=ids),
    params:
        af_input = '--bind alphafold3_msas:/root/af_input',
        af_output = '--bind alphafold3_predictions_a100_80gb:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        scripts = f'--bind {root_path("workflow/scripts")}:/app/scripts',
        docker = root_path(config['alphafold3_docker']),
        input_dir = '--input_dir=/root/af_input',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        xtra_args = '--norun_data_pipeline',

rule alphafold3_tests:
    input:
        expand('alphafold3_predictions_rtx_2080_ti/{id}/{id}_model.cif', id=ids),
        expand('alphafold3_predictions_rtx_3090/{id}/{id}_model.cif', id=ids),
        expand('alphafold3_predictions_rtx_4090/{id}/{id}_model.cif', id=ids),
        expand('alphafold3_predictions_titan_rtx/{id}/{id}_model.cif', id=ids),
        expand('alphafold3_predictions_quadro_rtx_6000/{id}/{id}_model.cif', id=ids),
        expand('alphafold3_predictions_v100/{id}/{id}_model.cif', id=ids),
        expand('alphafold3_predictions_a100_pcie_40gb/{id}/{id}_model.cif', id=ids),
        expand('alphafold3_predictions_a100_80gb/{id}/{id}_model.cif', id=ids),
