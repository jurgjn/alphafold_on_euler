
include: '../rules/common.smk'

def est_tokens_(file):
    with open(file) as fh:
        sequences = json.load(fh)['sequences']
        n_tokens = 0
        for seq in sequences:
            #print(seq)
            n_tokens += len(seq['protein']['sequence'])
    return n_tokens

def alphafold3_stats():
    #ids = ['example_atox1']
    ids, = glob_wildcards('alphafold3_jsons/{id}.json')
    #ids, = glob_wildcards('alphafold3_msas/{id}_data.json')
    ids_blacklist = {
        '8bc6-1',
        '4yv8-1',
        '6byz-1',
        '4kx8-1',
        '5x54-1',
        '2jbu-1',
        '7ndf-1',
    }
    #ids = set(ids) - ids_blacklist
    #print(ids)
    #ids = [
    #    'a0a0a0mt49_p14079',
    #    'a0a0a0mtl5_q69027',
    #]
    df_ = pd.DataFrame({'id': ids})
    df_['json'] = df_['id'].map(lambda id: f'alphafold3_jsons/{id}.json')
    df_['data'] = df_['id'].map(lambda id: f'alphafold3_msas/{id}_data.json.gz')
    df_['pred'] = df_['id'].map(lambda id: f'alphafold3_predictions/{id}/{id}_model.cif.gz')

    df_['json_isfile'] = df_['json'].map(os.path.isfile)
    df_['data_isfile'] = df_['data'].map(os.path.isfile)
    df_['pred_isfile'] = df_['pred'].map(os.path.isfile)

    df_['tokens'] = df_['json'].map(est_tokens_)
    df_['tokens_check'] = (16 < df_['tokens']) & (df_['tokens'] <= 2000)

    printlenq(df_, 'json_isfile', 'input files')
    printlenq(df_, 'data_isfile', 'alignments finished')
    printlenq(df_, 'data_isfile & tokens_check', 'alignments finished with number of tokens')
    printlenq(df_, 'pred_isfile', 'predictions finished')

    return df_.query('data_isfile & tokens_check')

ids = alphafold3_stats()['id'].tolist()

include: '../rules/alphafold3.smk'

rule alphafold3:
    input:
        expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
