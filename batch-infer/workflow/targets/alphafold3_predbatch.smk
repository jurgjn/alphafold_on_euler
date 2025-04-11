
include: '../rules/common.smk'
include: '../rules/alphafold3_msas.smk'

#ids = []
#ids = alphafold3_stats().id.tolist()
ids = pd.read_csv('alphafold3_predbatch.tsv', sep='\t').id.tolist()
#pprint(ids)

# alphafold3_ids() - return all
# alphafold3_ids_grouped() - return [['a', 'b', 'c'], ['e', 'f', 'g']]

for batch_id, df_batch in pd.read_csv('alphafold3_predbatch.tsv', sep='\t').groupby('batch_id'):
    #print(batch_id)
    #print(df_batch)

    rule: # Run AF3 structure prediction on a subset of .json-s (as implied by id-s)
        name:
            f'alphafold3_predictions_batch{batch_id}_{len(df_batch)}'
        input:
            json = expand('alphafold3_msas/{id}_data.json.gz', id=df_batch.id.tolist()),
        output:
            cifs = expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=df_batch.id.tolist()),
            # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#defining-retries-for-fallible-rules
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
            'stack/2024-06', 'gcc/12.2.0', 'cuda/12.8.0',
        resources:
            runtime = '4h',
            mem_mb = 98304,
            disk_mb = 98304,
            slurm_extra = "'--gpus=1 --gres=gpumem%80g'",
        shell: """
            TODO_JSONS=$TMPDIR/alphafold_predictions_todo.txt
            echo "{input.json}" | tr ' ' '\\n' > $TODO_JSONS
            echo Contents of $TODO_JSONS
            cat $TODO_JSONS
            SMKDIR=`pwd`
            echo Running rsync from $SMKDIR to $TMPDIR
            rsync -av --files-from $TODO_JSONS ./ $TMPDIR
            #rsync -auv $SMKDIR/ $TMPDIR --include='alphafold3_msas' --include='alphafold3_msas/*_data.json.gz' --exclude='*'
            gunzip -r $TMPDIR/alphafold3_msas/
            mkdir -p $TMPDIR/alphafold3_predictions
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
            gzip -r $TMPDIR/alphafold3_predictions/
            echo Running rsync from $TMPDIR to $SMKDIR
            rsync -auv $TMPDIR/alphafold3_predictions $SMKDIR/
        """

rule alphafold3_predbatch:
    input:
        expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
