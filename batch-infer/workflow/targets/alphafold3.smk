
#ids = ['example_atox1']
ids, = glob_wildcards('alphafold3_jsons/{id}.json')
#ids, = glob_wildcards('alphafold3_msas/{id}_data.json')
print(ids)

include: '../rules/alphafold3.smk'

rule alphafold3:
    input:
        expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
