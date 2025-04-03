
ids, = glob_wildcards('alphafold3_jsons/{id}.json')

include: '../rules/common.smk'
include: '../rules/alphafold3_msas.smk'

rule alphafold3_msas_only:
    input:
        expand('alphafold3_msas/{id}_data.json.gz', id=ids),
