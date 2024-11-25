# Batch inference of protein structure
## Current workflow
- Like AF2, AF3 has a (CPU/RAM-heavy) MSA step, and a (GPU-heavy) structure prediction step; these can be run individually by specifying `--norun_inference`/`--norun_data_pipeline`
- Rule `alphafold3_msas` executes the MSA step using 8 CPUs (seems to be hard-coded from looking at the output) and no GPU
- Rule `alphafold3_predictions` executes the structure predition step using one CPU and one GPU; the GPU is currently set to an A100 by [asking for at least 40GB GPU memory](workflow/profiles/default/config.yaml)
- The MSA step seems to be much longer than the structure prediction step (hour vs minutes); therefore, MSA predictions are run as separate jobs for each structure, and then batched together and run as one prediction job for all structures
- Building the Singularity image:
    - software/alphafold3/alphafold3-build.ipynb builds image on a Macbook Pro & rsyncs to the cluster (latest checkout + enable unified memory)
    - software/alphafold3/alphafold3-eu.ipynb converts docker .tar to a singularity image (on the cluster)
- Installation instructions in [INSTALL.ipynb](INSTALL.ipynb)
- Example run described in [EXAMPLE.ipynb](EXAMPLE.ipynb)

## Potential optimisations/issues:
- Mount `/tmp/` on the Docker image to local scratch (used during the MSA step for temporary storage)
- Set up persistent compilation cache (on global scratch?) with `--jax_compilation_cache_dir`; this may have to depend on the GPU model?
- Use local scratch for input/output (instead of current directory)
- Some non-A100 GPUs requiring `--flash_attention_implementation=xla` [produce noise as output](https://github.com/google-deepmind/alphafold3/issues/59#issuecomment-2482720962)
- There are warnings about a CUDA version mismatch (12.6 vs 12.2) although AF3 still finishes with a reasonable structure (at least on an A100?)..

---
Table to keep track of AlphaFold3 and related co-folding methods
| Name       | Repo    | Comments |
| ---------- | ------- | --------------------------------------
| AlphaFold3 | [google-deepmind/alphafold3](https://github.com/google-deepmind/alphafold3) |
| Boltz-1 | [jwohlwend/boltz](https://github.com/jwohlwend/boltz) |
| Chai-1   | [chaidiscovery/chai-lab](https://github.com/chaidiscovery/chai-lab) |
| HelixFold | [PaddlePaddle/PaddleHelix](https://github.com/PaddlePaddle/PaddleHelix/tree/dev/apps/protein_folding/helixfold) |
| OpenFold3 | [(TBD)](https://bsky.app/profile/moalquraishi.bsky.social/post/3lbeqspkunc2w) | 
| Protenix | [bytedance/Protenix](https://github.com/bytedance/Protenix) |
