
rule helixfold3_run_infer:
    input:
        json = workpath('input_json/{sequences}.json'),
    output:
        cif = workpath('run_infer/{sequences}/{sequences}-rank1/predicted_structure.cif'),
        pdb = workpath('run_infer/{sequences}/{sequences}-rank1/predicted_structure.pdb'),
        pkl = workpath('run_infer/{sequences}/final_features.pkl'),
        sstat = workpath('run_infer/{sequences}/sstat.tsv'),
        nvidia_smi = workpath('run_infer/{sequences}/nvidia-smi.csv'),
    envmodules:
        'stack/2024-06',
        'gcc/12.2.0',
        'cuda/12.1.1',
        'cudnn/8.8.1.3-12',
    conda:
        'helixfold',
    params:
        helixfold_dir = '/cluster/project/beltrao/jjaenes/22.05.30_alphafold_on_euler/openfold/software/PaddleHelix/apps/protein_folding/helixfold3',
        output_dir = workpath('run_infer/'),
    shell: """
        PYTHON_BIN="/cluster/project/beltrao/jjaenes/software/miniconda3/envs/helixfold/bin/python"
        ENV_BIN="/cluster/project/beltrao/jjaenes/software/miniconda3/envs/helixfold/bin"
        MAXIT_SRC="/cluster/project/beltrao/jjaenes/22.05.30_alphafold_on_euler/openfold/software/maxit-v11.100-prod-src"
        export OBABEL_BIN="/cluster/project/beltrao/jjaenes/software/miniconda3/envs/helixfold/bin/obabel"
        DATA_DIR="/cluster/work/beltrao/jjaenes/24.09.03_helixfold3/data_reduced_dbs"
        export PATH="/cluster/project/beltrao/jjaenes/22.05.30_alphafold_on_euler/openfold/software/maxit-v11.100-prod-src/bin:$PATH"
        export RCSBROOT='/cluster/project/beltrao/jjaenes/22.05.30_alphafold_on_euler/openfold/software/maxit-v11.100-prod-src'

        echo 'Logging GPU usage to: {output.nvidia_smi}'
        stdbuf -i0 -o0 -e0 workflow/scripts/nvidia-smi-log {output.nvidia_smi} &

        echo 'Running HelixFold3 inference.py:'
        cd {params.helixfold_dir}
        CUDA_VISIBLE_DEVICES=0 "$PYTHON_BIN" inference.py \
            --maxit_binary "$MAXIT_SRC/bin/maxit" \
            --jackhmmer_binary_path "$ENV_BIN/jackhmmer" \
	        --hhblits_binary_path "$ENV_BIN/hhblits" \
	        --hhsearch_binary_path "$ENV_BIN/hhsearch" \
	        --kalign_binary_path "$ENV_BIN/kalign" \
	        --hmmsearch_binary_path "$ENV_BIN/hmmsearch" \
	        --hmmbuild_binary_path "$ENV_BIN/hmmbuild" \
            --nhmmer_binary_path "$ENV_BIN/nhmmer" \
            --preset='reduced_dbs' \
            --bfd_database_path "$DATA_DIR/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt" \
            --small_bfd_database_path "$DATA_DIR/small_bfd/bfd-first_non_consensus_sequences.fasta" \
            --bfd_database_path "$DATA_DIR/small_bfd/bfd-first_non_consensus_sequences.fasta" \
            --uniclust30_database_path "$DATA_DIR/uniclust30/uniclust30_2018_08/uniclust30_2018_08" \
            --uniprot_database_path "$DATA_DIR/uniprot/uniprot.fasta" \
            --pdb_seqres_database_path "$DATA_DIR/pdb_seqres/pdb_seqres.txt" \
            --uniref90_database_path "$DATA_DIR/uniref90/uniref90.fasta" \
            --mgnify_database_path "$DATA_DIR/mgnify/mgy_clusters_2018_12.fa" \
            --template_mmcif_dir "$DATA_DIR/pdb_mmcif/mmcif_files" \
            --obsolete_pdbs_path "$DATA_DIR/pdb_mmcif/obsolete.dat" \
            --ccd_preprocessed_path "$DATA_DIR/ccd_preprocessed_etkdg.pkl.gz" \
            --rfam_database_path "$DATA_DIR/Rfam-14.9_rep_seq.fasta" \
            --max_template_date=2020-05-14 \
            --input_json {input.json} \
            --output_dir {params.output_dir} \
            --model_name allatom_demo \
            --init_model /cluster/work/beltrao/jjaenes/24.09.03_helixfold3/HelixFold3-params-240814/HelixFold3-240814.pdparams \
            --infer_times 1 \
            --diff_batch_size 1 \
            --precision "fp32"
        cd -

        echo "Logging resources to: {output.sstat}"
        workflow/scripts/sstat-log > {output.sstat}
        myjobs -j $SLURM_JOB_ID
    """
