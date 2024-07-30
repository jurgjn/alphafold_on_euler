
Run multimer models on Euler, e.g.:
```
./openfold-eu --config sequences='examples/MAPK1_DUSP6/MAPK1_DUSP6.txt'
```

- By default, assumed input file contains uniprot_id-s which will be downloaded automatically
- Alternatively, define sequences with fastas with identifiers in `fasta_dir/identifier.fasta` (can mix both approaches)
- Can adjust re-run triggers: `--rerun-triggers code input mtime`
