

import gzip, json

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

def write_multimer_json_(file, fileB, fileC):
    json_B = load_json_(fileB)
    json_C = load_json_(fileC)

    seq_B = load_seq_(fileB, chain='B')
    seq_C = load_seq_(fileC, chain='C')

    with gzip.open(file, 'wt') as fh:
        fh.write("""{
  "dialect": "alphafold3",
  "version": 2,
  "name": "%s_%s",
  "sequences": [
%s
%s
  ],
  "modelSeeds": [
    1
  ],
  "bondedAtomPairs": null,
  "userCCD": null
}""" % (json_B['name'], json_C['name'], ''.join(seq_B).rstrip('\n') + ',', ''.join(seq_C).rstrip('\n')))

def alphafold3_msasm_input(wildcards):
    print([ f'alphafold3_msas/{id_i}_data.json.gz' for id_i in wildcards.id.split('_') ]  )
    return [ f'alphafold3_msas/{id_i}_data.json.gz' for id_i in wildcards.id.split('_') ]    

rule alphafold3_msasm:
    """
    # Writes an alphafold3 multimer .json file based on monomer .jsons
    alphafold3_msa_mm aac71393_aac72486 projects/af3_human/alphafold3_msas
        | gunzip -c > $TMPDIR/alphafold3_msas/{id}_data.gz
    # Bash for loop based on snakemake identifiers?
    """
    input:
        json = alphafold3_msasm_input,
    output:
        json = 'alphafold3_msasm/{id}_data.json.gz',
    run:
        write_multimer_json_(file=output.json, fileB=input.json[0], fileC=input.json[1],)
