
import glob, functools, json, os, os.path, pandas as pd
from pprint import pprint

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
    """
    return os.path.join(os.path.abspath(f'{workflow.basedir}/../..'), path)
