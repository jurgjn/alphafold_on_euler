
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
ids = set(ids) - ids_blacklist
print(ids)

include: '../rules/alphafold3.smk'

rule alphafold3:
    input:
        expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
