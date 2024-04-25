import generate_singularity_cmd
import argparse
from datetime import datetime
import re

CONTAINER_IMAGE = 'AlphaFold-2.3.2.sif'


def main():
    args = parse_arguments()
    FASTAFILE = args.fasta_paths[0]
    PROTEIN_NAME = FASTAFILE.split('.f')[0]
    if "/" in PROTEIN_NAME :
        PROTEIN_NAME = PROTEIN_NAME.split('/')[-1]
    ###########--PROTEIN CHARACTERISTICS--############

    with open(FASTAFILE, 'r') as f:
        lines = f.readlines()
        nb_lines = len(lines)

        cpt_AA = 0
        for line in lines:

            if not has_numbers(line) and not ('>' in line):
                cpt_AA += len(line)

    if args.model_preset == '' and nb_lines <= 2:
        args.model_preset = 'monomer'
    elif args.model_preset == '' and nb_lines > 2:
        args.model_preset = 'multimer'

    ###########--APPROPRIATE RESSOURCES--############

    NCPUS = 8
    NGPUS = 1
    CPUMEM_PER_CPU = '30g'
    TOTAL_SCRATCH = '120g'

    GPUMEM = -1
    RUNTIME = ''

    if args.model_preset[0:4] == 'mono':

        if cpt_AA <= 500:
            GPUMEM = '11g'
            RUNTIME = '04:00:00'
        elif 500 < cpt_AA <= 2500:
            GPUMEM = '24g'
            RUNTIME = '24:00:00'
        elif cpt_AA > 2500:
            GPUMEM = '40g'
            RUNTIME = '48:00:00'

    if args.model_preset[0:4] == 'mult':
        if 1000 <= cpt_AA <= 2500:
            GPUMEM = '24g'
            RUNTIME = '48:00:00'
        elif cpt_AA > 2500:
            GPUMEM = '80g'
            RUNTIME = '120:00:00'

    print(f"\nEstimate required resources, please adjust as needed in the final script:")
    print(f"Run time:            {RUNTIME:s} (hh:mm:ss)")
    print(f"Number of CPUs:      {NCPUS}")
    print(f"CPU memory per CPU:  {CPUMEM_PER_CPU[:-1]} (GB)")
    print(f"Number of GPUs:      {NGPUS}")
    print(f"Total GPU memory:    {GPUMEM[:-1]} (GB)")
    print(f"Total scratch space: {TOTAL_SCRATCH[:-1]} (GB)\n")
    print(f"Output directory of the script : {args.output_dir}\n")

    ###########--GENERATING THE SLURM SCRIPT--############

    CMD = generate_singularity_cmd.main_singularity_cmd(args)

    with open(args.output_dir + '/' + PROTEIN_NAME + '.sbatch', 'w') as output_f:
        print(args.output_dir + '/' + PROTEIN_NAME + '.sbatch')
        output_f.write(f'#!/usr/bin/bash\n')
        output_f.write(f'#SBATCH -n {NCPUS}\n')
        output_f.write(f'#SBATCH --nodes 1\n')
        output_f.write(f'#SBATCH --mem-per-cpu {CPUMEM_PER_CPU}\n')
        output_f.write(f'#SBATCH --time {RUNTIME}\n')
        output_f.write(f'#SBATCH -G {NGPUS}\n')
        output_f.write(f'#SBATCH --gres=gpumem:{GPUMEM}\n')
        output_f.write(f'#SBATCH --tmp {TOTAL_SCRATCH}\n')

        if args.shareholder != '':
            output_f.write(f'#SBATCH -A {args.shareholder}\n')

        output_f.write(f'#SBATCH -J {PROTEIN_NAME}_prediction\n')
        output_f.write(f'#SBATCH -e {args.output_dir}/{PROTEIN_NAME}_%j_err.txt\n')
        output_f.write(f'#SBATCH -o {args.output_dir}/{PROTEIN_NAME}_%j_out.txt\n')
        output_f.write(f'\n')
        output_f.write(f'{CMD}')

    return 0


def has_numbers(inputString):
    return bool(re.search(r'\d', inputString))


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Generates a SLURM script for running Alphafold v2.3.2 with Singularity/Apptainer in a batch job"
    )

    parser.add_argument(
        "--fasta-paths",
        "-f",
        nargs="+",
        required=True,
        help="Paths to a FASTA file",
    )

    parser.add_argument(
        "--shareholder",
        "-s",
        default='',
        help="If you are using GPUs, please specify your shareholder group. "
             "You can see all shareholder groups you are a part of on Euler"
             "with the my_share_info command."
    )

    parser.add_argument(
        "--max-template-date",
        "-t",
        default=datetime.today().strftime("%Y-%m-%d"),
        help="Maximum template release date to consider "
             "(ISO-8601 format - i.e. YYYY-MM-DD). "
             "Important if folding historical test sets.",
    )
    parser.add_argument(
        "--db-preset",
        choices=["reduced_dbs", "full_dbs"],
        default="full_dbs",
        help="Choose preset model configuration - no ensembling with "
             "uniref90 + bfd + uniclust30 (full_dbs), or "
             "8 model ensemblings with uniref90 + bfd + uniclust30 (casp14).",
    )
    parser.add_argument(
        "--model-preset",
        choices=["monomer", "monomer_casp14", "monomer_ptm", "multimer"],
        default='',
        help="Choose preset model configuration - the monomer model, the monomer model "
             "with extra ensembling, monomer model with pTM head, or multimer model",
    )
    parser.add_argument(
        "--num-multimer-predictions-per-model",
        default=5,
        type=int,
        help="How many "
             "predictions (each with a different random seed) will be "
             "generated per model. E.g. if this is 2 and there are 5 "
             "models then there will be 10 predictions per input. "
             "Note: this FLAG only applies if model_preset=multimer",
    )
    parser.add_argument(
        "--benchmark",
        "-b",
        default=False,
        action="store_true",
        help="Run multiple JAX model evaluations to obtain a timing "
             "that excludes the compilation time, which should be more indicative "
             "of the time required for inferencing many proteins.",
    )
    parser.add_argument(
        "--use-precomputed-msas",
        default=False,
        action="store_true",
        help="Whether to read MSAs that have been written to disk instead of running "
             "the MSA tools. The MSA files are looked up in the output directory, so it "
             "must stay the same between multiple runs that are to reuse the MSAs. "
             "WARNING: This will not check if the sequence, database or configuration "
             "have changed.",
    )
    parser.add_argument(
        "--data-dir",
        "-d",
        default="/cluster/project/alphafold",
        help="Path to directory with supporting data: AlphaFold parameters and genetic "
             "and template databases. Set to the target of download_all_databases.sh.",
    )
    parser.add_argument(
        "--docker-image", default=CONTAINER_IMAGE, help="Alphafold docker image."
    )
    parser.add_argument(
        "--output-dir", "-o", default=".", help="Output directory for results."
    )
    parser.add_argument(
        "--use-gpu",
        default=True,
        action="store_true",
        help="Enable NVIDIA runtime to run with GPUs.",
    )
    parser.add_argument(
        "--run-relax",
        default=True,
        action="store_true",
        help="Whether to run the final relaxation step on the predicted models. Turning "
             "relax off might result in predictions with distracting stereochemical "
             "violations but might help in case you are having issues with the "
             "relaxation stage.",
    )
    parser.add_argument(
        "--enable-gpu-relax",
        default=True,
        action="store_true",
        help="Run relax on GPU if GPU is enabled.",
    )
    parser.add_argument(
        "--gpu-devices",
        default="all",
        help="Comma separated list of devices to pass to NVIDIA_VISIBLE_DEVICES.",
    )
    parser.add_argument(
        "--cpus", "-c", type=int, default=8, help="Number of CPUs to use."
    )

    return parser.parse_args()


if __name__ == "__main__":
    main()


# cat << EOF > $RUNSCRIPT
# # !/usr/bin/bash
# # SBATCH -n $NCPUS
# # SBATCH --time=$RUNTIME
# # SBATCH --mem-per-cpu=$((TOTAL_CPU_MEM_MB/NCPUS))
# # SBATCH --nodes=1
# # SBATCH -G $NGPUS
# # SBATCH --gres=gpumem:$GPU_MEM_MB
# # SBATCH --tmp=$TOTAL_SCRATCH_MB
# # SBATCH -A $SHAREHOLDER_GROUP
# # SBATCH -J af2_$PROTEIN
# # SBATCH -e $WORKDIR/$PROTEIN.%j.err.txt
# # SBATCH -o $WORKDIR/$PROTEIN.%j.out.txt
#
# source / cluster / apps / local / env2lmod.sh
# module
# load
# gcc / 6.3
# .0
# openmpi / 4.0
# .2
# alphafold / 2.3
# .1
# module
# load
# alphafold - postprocessing
# source / cluster / apps / nss / alphafold / venv_alphafold_2
# .3
# .1 / bin / activate
#
# # Define paths to databases and output directory
# DATA_DIR = / cluster / project / alphafold
# OUTPUT_DIR =\${TMPDIR} / output
#
# # Activate unified memory
# export
# TF_FORCE_UNIFIED_MEMORY =$ENABLE_UNIFIED_MEMORY
# export
# XLA_PYTHON_CLIENT_MEM_FRACTION =${MEM_FRACTION}
# .0
#
# python / cluster / apps / nss / alphafold / alphafold - 2.3
# .1 / run_alphafold.py \ \
#     --data_dir =\$DATA_DIR \ \
#     --output_dir =\$OUTPUT_DIR \ \
#     --max_template_date = "$MAX_TEMPLATE_DATE" \ \
#     --uniref90_database_path =\$DATA_DIR / uniref90 / uniref90.fasta \ \
#     --mgnify_database_path =\$DATA_DIR / mgnify / mgy_clusters_2018_12.fa \ \
#     --template_mmcif_dir =\$DATA_DIR / pdb_mmcif / mmcif_files \ \
#     --obsolete_pdbs_path =\$DATA_DIR / pdb_mmcif / obsolete.dat \ \
#     $OPTIONS - -fasta_paths =$FASTAFILE
#
# # Produce some plots using the postprocessing script from
# # https://gitlab.ethz.ch/sis/alphafold-postprocessing
# # :
#
# python - u / cluster / apps / nss / alphafold / alphafold - postprocessing / 1.0
# .0 / bin / postprocessing.py - o \$OUTPUT_DIR /$PROTEIN / plots \$OUTPUT_DIR /$PROTEIN
#
# rsync - av $RSYNC_OPTIONS \$TMPDIR / output /$PROTEIN $WORKDIR
#
# touch $WORKDIR /$PROTEIN.done
#
# EOF
