
include: '../rules/common.smk'

ids, = glob_wildcards('alphafold3_jsons/{id}.json')

include: '../rules/alphafold3.smk'

rule alphafold3_msas_only:
    input:
        expand('alphafold3_msas/{id}_data.json.gz', id=ids),
