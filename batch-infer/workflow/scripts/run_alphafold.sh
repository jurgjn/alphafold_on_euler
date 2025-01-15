#!/usr/bin/env bash
# Adjust environment to run AF3 based on available hardware
# Run inside the AF3 container replacing `python3 run_alphafold.py`
cd /app/alphafold

GPU_MEMAVAIL=`nvidia-smi --query-gpu=memory.total --format=csv,noheader | cut -d ' ' -f 1`
GPU_CAPABILITY=`nvidia-smi --query-gpu=compute_cap --format=csv,noheader | cut -d '.' -f 1`

echo Total GPU memory: "$GPU_MEMAVAIL"
echo GPU capability: "$GPU_CAPABILITY"

# https://github.com/google-deepmind/alphafold3/issues/59
if [[ "$GPU_CAPABILITY" == 7 ]]
then
    echo GPU capability is 7.x, adjusting XLA_FLAGS to --xla_disable_hlo_passes=custom-kernel-fusion-rewriter
    XLA_FLAGS="--xla_disable_hlo_passes=custom-kernel-fusion-rewriter"
fi

# https://github.com/google-deepmind/alphafold3/blob/main/docs/performance.md
if [ "$GPU_MEMAVAIL" -lt 50000 ]
then
    echo Significantly less than 80 GB GPU RAM available

    echo Enabling unified memory
    XLA_PYTHON_CLIENT_PREALLOCATE=false
    TF_FORCE_UNIFIED_MEMORY=true
    XLA_CLIENT_MEM_FRACTION=3.2

    echo Adjusting pair_transition_shard_spec in model_config.py
    git apply <<EOF
diff --git a/src/alphafold3/model/model_config.py b/src/alphafold3/model/model_config.py
index 2040d8f..54d13fc 100644
--- a/src/alphafold3/model/model_config.py
+++ b/src/alphafold3/model/model_config.py
@@ -26,7 +26,8 @@ class GlobalConfig(base_config.BaseConfig):
   pair_attention_chunk_size: Sequence[_Shape2DType] = ((1536, 128), (None, 32))
   pair_transition_shard_spec: Sequence[_Shape2DType] = (
       (2048, None),
-      (None, 1024),
+      (3072, 1024),
+      (None, 512),
   )
   # Note: flash_attention_implementation = 'xla' means no flash attention.
   flash_attention_implementation: attention.Implementation = 'triton'
EOF
fi

echo Starting run_alphafold.py
python3 run_alphafold.py $@
