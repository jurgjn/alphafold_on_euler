
Stable
- alphafold3 - data pipeline/MSAs as individual jobs, predictions on all input as a single GPU job
- alphafold3_msas_only - only run MSAs, one per node

Work-in-progress:
- alphafold3_predictions_batches: partition AF3 prediction across multiple GPU nodes
- alphafold3_multimer: run interactions at scale by auto-generating multimer MSAs from monomer MSAs on-the-fly
- alphafold3_tests: run prediction on all GPU models available on Euler
