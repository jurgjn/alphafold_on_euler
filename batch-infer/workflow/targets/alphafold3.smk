
ids, = glob_wildcards('alphafold3_jsons/{id}.json')

include: '../rules/common.smk'
include: '../rules/alphafold3_msas.smk'
include: '../rules/alphafold3_predictions.smk'

rule alphafold3:
    input:
        #expand('alphafold3_msas/{id}_data.json.gz', id=ids),
        expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
