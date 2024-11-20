"""
Colabfold adapted to euler:
- `colabfold_search` is sufficient to query e.g. 2k multimer MSAs in ~1d
- `colabfold_batch` can do ~hundred to a handful of multimer models a ~1d
- `colabfold_splits` divide into groups where sequences are weighted by length squared to equalise running times

[YoshitakaMo/localcolabfold](https://github.com/YoshitakaMo/localcolabfold)
[How to set up and use local MMseqs2 server with ColabFold Docker sokrypton/ColabFold](https://github.com/sokrypton/ColabFold/issues/636)
[Dockerized Colabfold for large-scale batch predictions | Oxford Protein Informatics Group](https://www.blopig.com/blog/2024/04/dockerized-colabfold-for-large-scale-batch-predictions/)
[Running ColabFold in Docker](https://github.com/sokrypton/ColabFold/wiki/Running-ColabFold-in-Docker)
"""

#localrules: colabfold_docker
#rule colabfold_docker:
#    """
#    Download colabfold docker image & convert to Singularity:
#        https://github.com/sokrypton/ColabFold/wiki/Running-ColabFold-in-Docker
#    """
#    output: software_path('colabfold/colabfold_1.5.5-cuda11.8.0.sif')
#    shell: """
#        cd software/colabfold
#        singularity pull docker://ghcr.io/sokrypton/colabfold:1.5.5-cuda11.8.0
#    """

localrules: colabfold_cache
rule colabfold_cache:
    """
    Download colabfold cache directory used to store AF2 model weights
    """
    output: directory(software_path('colabfold/cache'))
    shell: """
        mkdir -p {output}
        singularity run -B {output}:/cache \
            colabfold.sif  \
            python -m colabfold.download
    """

rule colabfold_setup_databases:
    """
    Set up colabfold sequence databases:
    - start with example from [here](https://colabfold.mmseqs.com)
    - disable indexing with `MMSEQS_NO_INDEX=1` as in [here](https://github.com/sokrypton/ColabFold/blob/main/README.md)
    - match to mmseqs version used later by running the indexing inside the [Singularity/Apptainer image](https://github.com/sokrypton/ColabFold/wiki/Running-ColabFold-in-Docker)

    Last step (PDB_MMCIF_READY) will fail as image does not have rsync; work around by running commands separately outside Singularity
    """
    output:
        dir = directory(software_path('colabfold/database/')),
        uniref30_ready = software_path('colabfold/database/UNIREF30_READY'),
        colabdb_ready = software_path('colabfold/database/COLABDB_READY'),
        pdb_ready = software_path('colabfold/database/PDB_READY'),
        pdb100_ready = software_path('colabfold/database/PDB100_READY'),
        pdb_mmcif_ready = software_path('colabfold/database/PDB_MMCIF_READY'),
    shell: """
        module load eth_proxy
        cd software/colabfold
        #wget https://raw.githubusercontent.com/sokrypton/ColabFold/main/setup_databases.sh
        #chmod +x setup_databases.sh
        mkdir -p database
        singularity exec -B $(pwd):/work --env MMSEQS_NO_INDEX=1 colabfold.sif ./setup_databases.sh database/
        myjobs -j $SLURM_JOB_ID
    """

rule colabfold_msas:
    """
    Run the MSA search for the whole input (~2k sequences/day)

    Could make use of local scratch (if enough available on a typical node):
    $ time du -hs colabfold_msas
    53G     colabfold_msas
    real    2m28.374s
    """
    input:
        csv = 'colabfold_input.csv',
        docker = ancient(software_path('test_dockerfile/colabfold.sif')),
        databases = ancient(rules.colabfold_setup_databases.output.dir),
    output:
        msas = directory('colabfold_msas'),
    shell: """
        echo {rule}: Creating output directory {output.msas}
        mkdir -p {output.msas}
        echo {rule}: Running colabfold_search
        singularity run -B $(pwd):/work -B {input.databases}:/databases {input.docker} \
            colabfold_search --use-templates 1 --db2 pdb100_230517 --threads {threads} /work/{input.csv} /databases /work/{output.msas}
        myjobs -j $SLURM_JOB_ID
    """

@functools.cache
def colabfold_stats(max_nbatches=200):
    fp_ = 'colabfold_input.csv'
    df_ = pd.read_csv(fp_)
    df_['sequence_len'] = df_['sequence'].str.len()
    df_ = df_.sort_values(['sequence_len']).reset_index(drop=True)
    df_['sequence_len_check'] = (16 < df_['sequence_len']) & (df_['sequence_len'] <= 2500)

    df_['a3m'] = df_['id'].map(lambda id: f'colabfold_msas/{id}.a3m')
    df_['pdb'] = df_['id'].map(lambda id: f'colabfold_predictions/{id}_unrelaxed_rank_001_alphafold2_multimer_v3_model_1_seed_000.pdb')
    df_['json'] = df_['id'].map(lambda id: f'colabfold_predictions/{id}_scores_rank_001_alphafold2_multimer_v3_model_1_seed_000.json')
    df_['done'] = df_['id'].map(lambda id: f'colabfold_predictions/{id}.done.txt')

    #a3m_files = glob.glob('colabfold_msas/*.a3m')
    #print(a3m_files)
    df_['a3m_isfile'] = df_['a3m'].map(lambda file: os.path.isfile(file))
    #df_['pdb_isfile'] = df_['pdb'].map(lambda file: os.path.isfile(file))
    #df_['json_isfile'] = df_['json'].map(lambda file: os.path.isfile(file))
    df_['done_isfile'] = df_['done'].map(lambda file: os.path.isfile(file))

    printlenq(df_, 'sequence_len_check', 'with sequence size between 16 and 3000')
    printlenq(df_, 'sequence_len_check & a3m_isfile', 'alignments finished')
    printlenq(df_, 'sequence_len_check & done_isfile', 'structures finished')

    #df_['weight'] = df_['sequence_len'] ** 2
    #df_['weight'] = df_['weight'] / df_['weight'].sum()
    #df_['batch_id'] = pd.cut(df_['weight'].cumsum(), bins=max_nbatches, labels=False).rank().astype(int)
    #print('Number of sequences per batch:', df_['batch_id'].value_counts())
    #print('Effort per batch:', df_.groupby('batch_id')['weight'].sum())
    return df_

localrules: colabfold_predictions_todo
checkpoint colabfold_predictions_todo:
    """
    Generate splits for colabfold predictions
    https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#data-dependent-conditional-execution
    """
    input:
        csv = 'colabfold_input.csv',
    output:
        dir = directory('colabfold_predictions_todo'),
    params:
        nrows_max = None,
    run:
        df_ = colabfold_stats()
        os.makedirs(output.dir, exist_ok=True)
        for i, r in df_.iterrows():
            pair = r["id"]
            fp_ = os.path.join(output.dir, f'{pair}.txt')
            #df_pair = r.to_frame().T
            #df_pair['a3m'].to_csv(fp_, index=False)
            a3m_file = r['a3m'] # colabfold_msas/FGFR1_FGFR2.a3m
            m8_file = f'colabfold_msas/{pair}_pdb100_230517.m8'
            with open(fp_, 'w') as f:
                f.write(f'{a3m_file}\n{m8_file}')


rule colabfold_predictions:
    """
    Predict structure based on splits generated by colabfold_splits
    """
    input:
        msas = 'colabfold_msas',
        todo = 'colabfold_predictions_todo/{pair_id}.txt', # CHANGED
        docker = ancient(software_path('test_dockerfile/colabfold.sif')),
        cache = ancient(rules.colabfold_cache.output),
        database_dir = ancient(rules.colabfold_setup_databases.output.dir), # CHANGED
    output:
        done = 'colabfold_predictions_done/{pair_id}.txt', # CHANGED
    params:
        nvidia_smi = f'{workflow.basedir}/scripts/nvidia-smi-log',
    envmodules:
        'stack/.2024-04-silent', 'gcc/8.5.0', 'cuda/11.8.0',
    shell: """
        echo {rule}: Copying MSAs to "$TMPDIR":
        rsync -av --files-from {input.todo} ./ $TMPDIR
        echo {rule}: Logging GPU usage:
        stdbuf -i0 -o0 -e0 {params.nvidia_smi} &
        PID_NVIDIA_SMI=$!
        echo {rule}: Running colabfold_batch under singularity:
        singularity run --nv -B {input.database_dir}:/databases -B {input.cache}:/cache -B $TMPDIR:/work {input.docker} \
            colabfold_batch --num-recycle {config[num_recycle]} --num-models {config[num_models]} --num-seeds {config[num_seeds]} --random-seed {config[random_seed]} --templates --pdb-hit-file /work/colabfold_msas/{wildcards.pair_id}_pdb100_230517.m8 --local-pdb-path /databases/pdb/divided /work/colabfold_msas/{wildcards.pair_id}.a3m /work/colabfold_predictions/{wildcards.pair_id}
        COLABFOLD_EXIT=$?
        echo {rule}: colabfold_batch finished with exit code "$COLABFOLD_EXIT"
        echo {rule}: Killing nvidia_smi with pid "$PID_NVIDIA_SMI":
        kill $PID_NVIDIA_SMI
        echo {rule}: Scratch usage: 
        du -hs $TMPDIR
        echo {rule}: Job stats:
        myjobs -j $SLURM_JOB_ID
        if [[ $COLABFOLD_EXIT -eq 0 ]]
        then
            echo {rule}: Success, copying results back from "$TMPDIR/colabfold_predictions/": 
            rsync -av $TMPDIR/colabfold_predictions/ colabfold_predictions/
            touch {output.done}
        fi
    """

def colabfold_all_input(wildcards):
    # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#data-dependent-conditional-execution
    checkpoint_output = checkpoints.colabfold_predictions_todo.get(**wildcards).output.dir
    return expand('colabfold_predictions_done/{pair_id}.txt', pair_id=glob_wildcards('colabfold_predictions_todo/{pair_id}.txt').pair_id)

localrules: colabfold_all
rule colabfold_all:
    # snakemake colabfold_all --profile smk-simple-slurm-eu --directory results/interactions_allProteomics --rerun-triggers input --dry-run
    input:
        colabfold_all_input #https://github.com/snakemake/snakemake/issues/2957
        #'colabfold_splits',
        #expand('colabfold_splits/split{batch_id}.done.txt', batch_id=[0, 1]),
        #expand('colabfold_splits_todo/split{batch_id}.done.txt', batch_id=colabfold_stats()['batch_id'].unique()),
'''
    run:
        df_ = colabfold_stats()

        def scores_(r):
            with open(results_prefix_path(r.json), 'r') as fh:
                js = json.load(fh)
                for col_ in ['iptm', 'ptm',]:
                    r[col_] = js[col_]
            return r
        cols_ = ['id', 'iptm', 'ptm']
        df_done_ = df_.query('done_isfile').apply(scores_, axis=1)
        df_done_['model_confidence'] = .8*df_done_['iptm'] + .2*df_done_['ptm']
        pprint(df_done_)
'''
