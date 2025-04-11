

include: '../rules/common.smk'
include: '../rules/alphafold3_msasm.smk'

ids = ['mapk1_dusp6',]
#ids = ['example_atox1']
#ids, = glob_wildcards('alphafold3_jsons/{id}.json')
#ids, = glob_wildcards('alphafold3_msas/{id}_data.json')
#print(ids)

rule alphafold3_predmulti:
    input:
        expand('alphafold3_msasm/{id}_data.json.gz', id=ids),
        #expand('alphafold3_predmulti/{id}/{id}_model.cif', id=ids),
