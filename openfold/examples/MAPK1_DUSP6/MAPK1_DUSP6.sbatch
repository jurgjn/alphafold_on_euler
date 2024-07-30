#!/usr/bin/env bash
#SBATCH --job-name=openfold-eu-MAPK1_DUSP6
#SBATCH --ntasks=8
#SBATCH --mem-per-cpu=10G
#SBATCH --gpus=rtx_4090:1
#SBATCH --gres=gpumem:16g
#SBATCH --tmp=16834
#SBATCH --time=0-12:00:00
#SBATCH --output=examples/MAPK1_DUSP6/MAPK1_DUSP6.stdout.txt
source $HOME/.bashrc
module load eth_proxy
module load cuda/12.2.1
cd -P $HOME/openfold
conda activate af2genomics-envA
./openfold-eu --config sequences='examples/MAPK1_DUSP6/MAPK1_DUSP6.txt'
