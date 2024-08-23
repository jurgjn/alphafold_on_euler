#!/usr/bin/env bash
#SBATCH --job-name=openfold-eu-MAPK1_DUSP6
#SBATCH --ntasks=8
#SBATCH --mem-per-cpu=10G
#SBATCH --tmp=16834
#SBATCH --time=0-12:00:00
#SBATCH --output=results/example_MAPK1_DUSP6/MAPK1_DUSP6_stdout.txt
source $HOME/.bashrc
module load eth_proxy
module load stack/2024-05 gcc/13.2.0 cuda/12.2.1
cd /cluster/project/beltrao/jjaenes/22.05.30_alphafold_on_euler/openfold
conda activate af2genomics-envA
./openfold-eu --config sequences='results/example_MAPK1_DUSP6/MAPK1_DUSP6.txt' --rerun-triggers input
