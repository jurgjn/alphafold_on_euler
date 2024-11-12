# Batch inference of protein structure

Batch prediction of protein structure by running colabfold ([Mirdita2022](https://doi.org/10.1038/s41592-022-01488-1); [Kim2024](https://doi.org/10.1038/s41596-024-01060-5)) on Euler:
* thousands of MSAs per day on a single bigmem node (24CPUs, 256GB RAM)
* tens to hundreds of structures per day on a single GPU

The sequence search runs offline without setting up or querying a separate MSA server. For folding, the input is grouped into batches of similar sequence length to minimise model recompilation.

Usage:
```
$ ./sbatch-infer colabfold results/example_multimere | sbatch
```

This reads sequences from `results/example_multimere/colabfold_input.csv` (as described in Box 3 of [Kim2024](https://doi.org/10.1038/s41596-024-01060-5)), and submits separate batch jobs both for MSA prediction and folding.

```
colabfold_input.csv
colabfold_msas/
    A1L020_P48634.a3m
colabfold_predictions/
```

Table to keep track of AlphaFold3 and related co-folding methods
| Name       | Repo    | Comments
| ---------- | ------- | --------------------------------------
| AlphaFold3 | [google-deepmind/alphafold3](https://github.com/google-deepmind/alphafold3) |
| Chai-1   | [chaidiscovery/chai-lab](https://github.com/chaidiscovery/chai-lab)
| HelixFold | [PaddlePaddle/PaddleHelix](https://github.com/PaddlePaddle/PaddleHelix/tree/dev/apps/protein_folding/helixfold)
| Protenix | [bytedance/Protenix](https://github.com/bytedance/Protenix) |
