
include: 'common.py'

wildcard_constraints:
    rule = r'[^\W0-9](\w|_)*', # https://stackoverflow.com/questions/49100678/regex-matching-unicode-variable-names
    id = r'(\w|\-|_|\.)*', # https://github.com/google-deepmind/alphafold3/blob/d7758637f3a682c99ddb325869eab9f19361ebcd/src/alphafold3/common/folding_input.py#L1001-L1005
