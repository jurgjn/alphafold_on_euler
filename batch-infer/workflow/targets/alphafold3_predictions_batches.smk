
include: '../rules/common.smk'

def est_tokens_(file):
    with open(file) as fh:
        sequences = json.load(fh)['sequences']
        n_tokens = 0
        for seq in sequences:
            #print(seq)
            n_tokens += len(seq['protein']['sequence'])
    return n_tokens

if not os.path.isfile('alphafold3_predictions_batches.tsv'):
    print('Re-generating batches:')
    #ids = ['example_atox1']
    ids, = glob_wildcards('alphafold3_jsons/{id}.json')
    #ids, = glob_wildcards('alphafold3_msas/{id}_data.json')
    #ids_blacklist = {'8bc6-1', '4yv8-1', '6byz-1', '4kx8-1', '5x54-1', '2jbu-1', '7ndf-1',}
    #ids = set(ids) - ids_blacklist
    #print(ids)
    #ids = ['a0a0a0mt49_p14079', 'a0a0a0mtl5_q69027',]
    df_ = pd.DataFrame({'id': ids})
    df_['json'] = df_['id'].map(lambda id: f'alphafold3_jsons/{id}.json')
    df_['data'] = df_['id'].map(lambda id: f'alphafold3_msas/{id}_data.json.gz')
    df_['pred'] = df_['id'].map(lambda id: f'alphafold3_predictions/{id}/{id}_model.cif.gz')

    df_['json_isfile'] = df_['json'].map(os.path.isfile)
    df_['data_isfile'] = df_['data'].map(os.path.isfile)
    df_['pred_isfile'] = df_['pred'].map(os.path.isfile)

    df_['tokens'] = df_['json'].map(est_tokens_)
    #df_['tokens_check'] = (16 < df_['tokens']) & (df_['tokens'] <= 2000)
    #df_['tokens_check'] = (2000 <= df_['tokens']) & (df_['tokens'] <= 2050)
    df_['tokens_check'] = True

    printlenq(df_, 'json_isfile', 'input files')
    printlenq(df_, 'data_isfile', 'alignments finished')
    printlenq(df_, 'data_isfile & tokens_check', 'alignments finished with number of tokens')
    printlenq(df_, 'pred_isfile', 'predictions finished')

    df_ = df_.query('data_isfile & tokens_check & ~pred_isfile').sort_values('tokens').reset_index(drop=True)
    #df_['batch_id'] = pd.cut(df_['weight'].cumsum(), bins=max_nbatches, labels=False).rank().astype(int)
    df_['batch_id'] = (df_.index.values / 2).astype(int)

    #print(df_)
    #return df_
    df_.to_csv('alphafold3_predictions_batches.tsv', index=False, header=True, sep='\t')

#ids = []
#ids = alphafold3_stats().id.tolist()
ids = pd.read_csv('alphafold3_predictions_batches.tsv', sep='\t').id.tolist()
#pprint(ids)

# alphafold3_ids() - return all
# alphafold3_ids_grouped() - return [['a', 'b', 'c'], ['e', 'f', 'g']]

include: '../rules/alphafold3.smk'

rule alphafold3_predictions_batches:
    input:
        expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
        #expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
