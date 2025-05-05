

import glob, gzip, functools, json, os, os.path, string
from pprint import pprint

import pandas as pd

def uf(x):
    return '{:,}'.format(x)

def ul(x):
    return uf(len(x))

def printsrc(*args, **kwargs):
    """
        https://stackoverflow.com/questions/3056048/filename-and-line-number-of-python-script
        https://stackoverflow.com/questions/3711184/how-to-use-inspect-to-get-the-callers-info-from-callee-in-python
        https://github.com/snakemake/snakemake/blob/main/snakemake/exceptions.py#L17
    """
    #pprint(dir(inspect.currentframe().f_back))
    #pprint(dir(inspect.getframeinfo(inspect.currentframe().f_back)))
    frameinfo_ = inspect.getframeinfo(inspect.currentframe().f_back)
    #pprint(frameinfo_)
    #pprint(dir(frameinfo_))
    filename = frameinfo_.filename
    lineno = frameinfo_.lineno
    #lineno = workflow.linemaps[filename][ frameinfo_.lineno ]
    print(f'{os.path.basename(filename)}:{lineno}', *args, **kwargs)

def printlen(x, *args, **kwargs):
    name_ = inspect.stack()[1][3] #https://stackoverflow.com/questions/5067604/determine-function-name-from-within-that-function-without-using-traceback
    if name_ != '<module>':
        print(f'{name_}:', uf(len(x)), *args, **kwargs)
    else:
        print(uf(len(x)), *args, **kwargs)

def workpath(path):
    dir_ = os.path.dirname(os.path.abspath(config['sequences']))
    return os.path.join(dir_, path)

def scratchpath(path):
    # https://scicomp.ethz.ch/wiki/Storage_systems#Local_scratch_.28on_each_compute_node.29
    #dir_ = os.environ['TMPDIR']
    #return os.path.join(dir_, path)
    return f'$TMPDIR/{path}' # Use value of $TMPDIR from the compute node (vs submission node)

def runtime_eu(wildcards, attempt):
    return ['4h', '1d', '3d', '1w'][attempt - 1]

def format_pct(x):
    return '({:.2f}%)'.format(x)

def printlenq(frame, q, *args, **kwargs):
    n_q = len(frame.query(q))
    n = len(frame)
    f = n_q / n
    print(uf(n_q), 'of', uf(n), format_pct(100*f),  *args, **kwargs)

#def slurm_extra_eu(wildcards, attempt):
#    # https://scicomp.ethz.ch/wiki/Getting_started_with_GPUs#Available_GPU_node_types
#    return [
#        "'--gpus=1 --gres=gpumem%3A11g'",
#        "'--gpus=1 --gres=gpumem%3A24g'",
#        "'--gpus=1 --gres=gpumem%3A32g'",
#        "'--gpus=1 --gres=gpumem%3A40g'",
#    ][attempt - 1]

def root_path(path):
    """
    https://snakemake.readthedocs.io/en/stable/project_info/faq.html#how-does-snakemake-interpret-relative-paths
    https://github.com/snakemake/snakemake/issues/1805
    #https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#accessing-auxiliary-source-files
    > This can be achieved by accessing their path via the workflow.source_path, which (a) computes the correct path relative to the current Snakefile such that the file can be accessed from any working directory
    """
    return os.path.join(os.path.abspath(f'{workflow.basedir}/../..'), path)

@functools.cache
def est_tokens_(file):
    with gzip.open(file, 'rt') as fh:
        sequences = json.load(fh)['sequences']
        n_tokens = 0
        for seq in sequences:
            #print(seq)
            n_tokens += len(seq['protein']['sequence'])
    return n_tokens

def msasm_tokens_(ids):
    df_ = pd.DataFrame({'id': ids.split('_')})
    df_['data'] = df_['id'].map(lambda id: f'alphafold3_msas/{id}_data.json.gz')
    df_['data_isfile'] = df_['data'].map(os.path.isfile)
    df_['tokens'] = df_['data'].map(est_tokens_)
    return df_['tokens'].sum()

def alphafold3_predmultb(ids, batch_runtime_hrs=3, c_or_r=[ 1.44451398e-04, -1.18261348e-01,  5.38503478e+01]):
    #ids, = glob_wildcards('alphafold3_jsons/{id}.json')
    df_ = pd.DataFrame({'id': ids})
    df_['tokens'] = df_['id'].map(msasm_tokens_)
    df_['pred'] = df_['id'].map(lambda id: f'alphafold3_predictions/{id}/{id}_model.cif.gz')

    df_['tokens_check'] = (16 < df_['tokens']) & (df_['tokens'] <= 6000)
    df_['pred_isfile'] = df_['pred'].map(os.path.isfile)

    q_ = 'tokens_check & ~pred_isfile'
    printlenq(df_, q_, 'sequences where predictions can be run:')

    df_ = df_.query(q_).sort_values('tokens').reset_index(drop=True)
    predict_runtime = np.poly1d(c_or_r) / (60 * 60)
    df_['weight'] = df_['tokens'].map(predict_runtime)
    df_['weight_cumsum'] = df_['weight'].cumsum()
    df_['batch_id'] = df_['weight_cumsum'].astype(int) // batch_runtime_hrs
    print(df_.groupby('batch_id').agg(no_of_sequences=('id', len), predicted_runtime=('weight', 'sum')))
    return df_
