# alphafold_on_euler

This project creates SLURM scripts helping users to estimate the computing resources required for AlphaFold jobs, and automatically outputs a run script ready to be submitted.
The repository currently contains two SLURM script generators :
- one for AlphaFold 2.3.1 written in bash
- one for Alphafold 2.3.2 written in python

If in doubt, please use the most recent version of Alphafold.
Up to and including AF2.3.1, all AlphaFold version has been installed manually on the cluster. Starting AF2.3.2, due to package incompatibilities, we now provide this software in a container. 

We made a benchmark study to better understand how AlphaFold uses the HPC resources. 
All of our recommendations are already included in this script. However, based on your particular case, these resources would potentially need to be adjusted: please don't hesitate to do so.

## Usage:

### AlphaFold 2.3.2 : setup_run_script_AF2.3.2 folder
This script should allow you to start alphafold jobs on CentOS and Ubuntu partitions on the cluster. Please note that the CentOS partition will be soon removed from the cluster. 

This script uses a containerised version of Alphafold 2.3.2. If older versions of alphafold are needed, please contact cluster support and we will provide them for you.

```commandline
git clone https://gitlab.ethz.ch/sis/alphafold_on_euler
cd ./alphafold_on_euler/setup_run_script_AF2.3.2
module load  stack/2024-06  gcc/12.2.0 python/3.11.6 #any reasonably recent version of python 3 would do
```
To display the full list of options :

```commandline
python generate_SLURM_script.py --help
```
General usage :
```commandline
python generate_SLURM_script.py -f [path ot fastafile] -o [output/working directory] -s [your share for GPU usage] --model-preset=[monomer/multimer]
```
A simple example :
```commandline
[nmarounina@eu-login-43 setup_run_script_container]$ python generate_SLURM_script.py -f ../fastafiles/Ubiquitin.fasta -o /cluster/scratch/nmarounina -s es_hpc -c 8 -model-preset=monomer

Estimate required resources, please adjust as needed in the final script:
Run time:            04:00:00 (hh:mm:ss)
Number of CPUs:      8
CPU memory per CPU:  30 (GB)
Number of GPUs:      1
Total GPU memory:    11 (GB)
Total scratch space: 120 (GB)

Output directory of the script : /cluster/scratch/nmarounina

/cluster/scratch/nmarounina/Ubiquitin.sbatch
```
Then submit the resulting script from the working directory as :

```commandline
sbatch Ubiquitin.sbatch
```
### AlphaFold 2.3.1 : setup_run_script_AF2.3.1 folder
This script works only on the centOS partition on Euler, and this partition is not available on the custer anymore. A legacy system is available by running the `run-centos7` command on the cluster. Unless you know exactly what you are doing, please avoid using this scipt.
If older versions of alphafold are needed, please contact cluster support and we will provide them for you.

```commandline
git clone https://gitlab.ethz.ch/sis/alphafold_on_euler
cd ./alphafold_on_euler/setup_run_script_AF2.3.1
./setup_alphafold_run_script.sh -f [path to your fastafile] -w [path to the working directory] -s [your share]
```

All possible option for this script can be displayed with :

```commandline
./setup_alphafold_run_script.sh --help
```

 Example:

```commandline
[nmarounina@eu-login-43 setup_run_script_AF2.3.1]$ ./setup_alphafold_run_script.sh -f ../fastafiles/Ubiquitin.fasta -w . -s es_hpc
  Reading /cluster/home/nmarounina/ALL_FOLDS/alphafold_on_euler/fastafiles/Ubiquitin.fasta
  Protein name:              Ubiquitin
  Number of sequences:       1
  Protein type:              monomer
  Number of amino acids:
                    sum:     76
                    max:     76

    Estimate required resources, please do not hesitate to adjust if required: 
    Run time:             04:00
    Number of CPUs:       8
    Total CPU memory:     240000
    Number of GPUs:       1
    Total GPU memory:     10240
    Total scratch space:  120000

  Output a SLURM run script for AlphaFold2: ./Ubiquitin.sbatch
```

Then submit the resulting script from the working directory as :
```commandline
sbatch Ubiquitin.sbatch
```

## Postprocessing

This script includes a postprocessing step using
[gitlab.ethz.ch/sis/alphafold-postprocessing](https://gitlab.ethz.ch/sis/alphafold-postprocessing).
It will generate a `plot` directory with some plots.
