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

def results_prefix_path(file):
    return os.path.join(config['results_prefix'], file)

localrules: colabfold_docker
rule colabfold_docker:
    """
    Download colabfold docker image & convert to Singularity:
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
    Download colabfold cache directory used to store AF2 model weights
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
    - match to mmseqs version used later by running the indexing inside the [Singularity/Apptainer image](https://github.com/sokrypton/ColabFold/wiki/Running-ColabFold-in-Docker)

    Last step (PDB_MMCIF_READY) will fail as image does not have rsync; work around by running commands separately outside Singularity
    """
    output:
        dir = directory('software/colabfold/database/'),
        uniref30_ready = 'software/colabfold/database/UNIREF30_READY',
        colabdb_ready = 'software/colabfold/database/COLABDB_READY',
        pdb_ready = 'software/colabfold/database/PDB_READY',
        pdb100_ready = 'software/colabfold/database/PDB100_READY',
        pdb_mmcif_ready = 'software/colabfold/database/PDB_MMCIF_READY',
    shell: """
        module load eth_proxy
        cd software/colabfold
        #wget https://raw.githubusercontent.com/sokrypton/ColabFold/main/setup_databases.sh
        #chmod +x setup_databases.sh
        mkdir -p database
        singularity exec -B $(pwd):/work --env MMSEQS_NO_INDEX=1 colabfold_1.5.5-cuda11.8.0.sif ./setup_databases.sh database/
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
        csv = results_prefix_path('colabfold_input.csv'),
        docker = ancient(rules.colabfold_docker.output),
        cache = ancient(rules.colabfold_cache.output),
        databases = ancient(rules.colabfold_setup_databases.output.dir),
    output:
        msas = directory(results_prefix_path('colabfold_msas')),
    shell: """
        mkdir -p {output.msas}
        singularity run -B {input.cache}:/cache -B $(pwd):/work -B {output.msas} {input.docker} \
            colabfold_search --threads {threads} {input.csv} {input.databases} {output.msas}
        myjobs -j $SLURM_JOB_ID
    """

@functools.cache
def colabfold_stats():
    fp_ = os.path.join(config['results_prefix'], 'colabfold_input.csv')
    df_ = pd.read_csv(fp_)
    df_['sequence_len'] = df_['sequence'].str.len()
    df_ = df_.sort_values(['sequence_len']).reset_index(drop=True)
    df_['sequence_len_check'] = (16 < df_['sequence_len']) & (df_['sequence_len'] <= 3000)

    df_['a3m'] = df_['id'].map(lambda id: f'colabfold_msas/{id}.a3m')
    df_['pdb'] = df_['id'].map(lambda id: f'colabfold_predictions/{id}_unrelaxed_rank_001_alphafold2_multimer_v3_model_1_seed_000.pdb')
    df_['json'] = df_['id'].map(lambda id: f'colabfold_predictions/{id}_scores_rank_001_alphafold2_multimer_v3_model_1_seed_000.json')
    df_['done'] = df_['id'].map(lambda id: f'colabfold_predictions/{id}.done.txt')

    #a3m_files = glob.glob(results_prefix_path('colabfold_msas/*.a3m'))
    #print(a3m_files)
    df_['a3m_isfile'] = df_['a3m'].map(lambda file: os.path.isfile(results_prefix_path(file)))
    #df_['pdb_isfile'] = df_['pdb'].map(lambda file: os.path.isfile(results_prefix_path(file)))
    #df_['json_isfile'] = df_['json'].map(lambda file: os.path.isfile(results_prefix_path(file)))
    df_['done_isfile'] = df_['done'].map(lambda file: os.path.isfile(results_prefix_path(file)))

    printlenq(df_, 'sequence_len_check', 'with sequence size between 16 and 3000')
    printlenq(df_, 'sequence_len_check & a3m_isfile', 'alignments finished')
    printlenq(df_, 'sequence_len_check & done_isfile', 'structures finished')
    return df_

localrules: colabfold_splits
checkpoint colabfold_splits:
    """
    Generate splits for colabfold predictions
    https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#data-dependent-conditional-execution
    """
    input:
        csv = results_prefix_path('colabfold_input.csv'),
    output:
        dir = directory(results_prefix_path('colabfold_splits/')),
    params:
        nbatches = 200,
        batch_id_max = None,
        nrows_max = None,
    run:
        df_ = colabfold_stats().query('sequence_len_check').copy()
        # Group into batches of approx equal size by weighing individual sequences by square of the weight
        df_['weight'] = df_['sequence_len'] ** 2
        df_['weight'] = df_['weight'] / df_['weight'].sum()
        df_['batch_id'] = pd.cut(df_['weight'].cumsum(), bins=params.nbatches, labels=False)
        print('Number of sequences per batch:', df_['batch_id'].value_counts())
        print('Effort per batch:', df_.groupby('batch_id')['weight'].sum())
        os.makedirs(output.dir, exist_ok=True)
        for batch_id, df_batch in df_.groupby('batch_id'):
            #if (params.batch_id_max is None) or (batch_id < params.batch_id_max):
            fp_ = os.path.join(output.dir, f'split{batch_id}.todo.txt')
            df_batch['a3m'].head(params.nrows_max).to_csv(fp_, index=False, header=False)

rule colabfold_predictions:
    """
    Predict structure based on splits generated by colabfold_splits
    """
    input:
        msas = results_prefix_path('colabfold_msas'),
        todo = results_prefix_path('colabfold_splits/split{batch_id}.todo.txt'),
        docker = ancient(rules.colabfold_docker.output),
        cache = ancient(rules.colabfold_cache.output),
    output:
        done = results_prefix_path('colabfold_splits/split{batch_id}.done.txt'),
    envmodules:
        'stack/.2024-04-silent', 'gcc/8.5.0', 'cuda/11.8.0',
    shell: """
        echo {rule}: Copying MSAs to "$TMPDIR":
        rsync -av --files-from {input.todo} {config[results_prefix]} $TMPDIR
        echo {rule}: Running colabfold_batch under singularity:
        singularity run --nv -B {input.cache}:/cache -B $TMPDIR:/work {input.docker} \
            colabfold_batch --num-models 1 /work/colabfold_msas /work/colabfold_predictions
        echo {rule}: Copying results back from "$TMPDIR/colabfold_predictions/": 
        rsync -av $TMPDIR/colabfold_predictions/ {config[results_prefix]}/colabfold_predictions/
        echo {rule}: Scratch usage: 
        du -hs $TMPDIR
        echo {rule}: Finished, stats:
        myjobs -j $SLURM_JOB_ID
        touch {output.done}
    """

def colabfold_all_input(wildcards):
    # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#data-dependent-conditional-execution
    checkpoint_output = checkpoints.colabfold_splits.get(**wildcards).output.dir
    return expand(results_prefix_path('colabfold_splits/split{batch_id}.done.txt'), batch_id=glob_wildcards(results_prefix_path('colabfold_splits/split{batch_id}.done.txt')).batch_id)

localrules: colabfold_all
rule colabfold_all:
    # snakemake colabfold_all --profile smk-simple-slurm-eu --config results_prefix=results/interactions_allProteomics --rerun-triggers input --dry-run
    input:
        #colabfold_all_input #https://github.com/snakemake/snakemake/issues/2957
        #results_prefix_path('colabfold_splits'),
        expand(results_prefix_path('colabfold_splits/split{batch_id}.done.txt'), batch_id=range(rules.colabfold_splits.params.nbatches)),
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