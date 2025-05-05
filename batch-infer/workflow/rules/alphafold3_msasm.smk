
def load_json_(file):
    with gzip.open(file, 'rt') as fh:
        return json.load(fh)

def load_seq_(file, chain=None):
    with gzip.open(file, 'rt') as fh:
        lines_ = fh.readlines()
        l_ = None
        r_ = None
        for i, l in enumerate(lines_):
            if l == '    {\n':
                l_ = i
            elif l == '    }\n':
                r_ = i + 1
        lines_ = lines_[l_:r_]
        if not(chain is None):
            assert lines_[2].startswith('        "id": "')
            lines_[2] = '        "id": "%s",\n' % (chain,)
        return lines_

def write_multimer_json_(file_out, *files_in, seeds='1'):
    jsons = [ load_json_(file) for file in files_in ]
    seqs = [ load_seq_(file, chain) for file, chain in zip(files_in, string.ascii_uppercase[1:])]
    name_ = '_'.join([json['name'] for json in jsons])
    sequences_ = ',\n'.join([''.join(seq).rstrip('\n') for seq in seqs])

    with gzip.open(file_out, 'wt') as fh:
        fh.write("""{
  "dialect": "alphafold3",
  "version": 2,
  "name": "%s",
  "sequences": [
%s
  ],
  "modelSeeds": [
    %s
  ],
  "bondedAtomPairs": null,
  "userCCD": null
}""" % (name_, sequences_, seeds))

def alphafold3_msasm_input(wildcards):
    return [ f'alphafold3_msas/{id_i}_data.json.gz' for id_i in wildcards.id.split('_') ]    

localrules: alphafold3_msasm

rule alphafold3_msasm:
    """
    Write an alphafold3 multimer .json based on monomer .jsons (assumes amino acids only)
        $ gunzip -c alphafold3_msasm/mapk1_dusp6_data.json.gz | less -S
    """
    input:
        json = alphafold3_msasm_input,
    output:
        json = 'alphafold3_msasm/{id}_data.json.gz',
    run:
        write_multimer_json_(output.json, *input.json)
