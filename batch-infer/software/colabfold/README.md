
Docker images:
````
cd software/colabfold
singularity pull docker://ghcr.io/sokrypton/colabfold:1.5.3-cuda11.8.0
singularity pull docker://ghcr.io/sokrypton/colabfold:1.5.5-cuda11.8.0
```

Set up colabfold sequence databases:
- start with example from [here](https://colabfold.mmseqs.com)
- disable indexing with `MMSEQS_NO_INDEX=1` as in [here](https://github.com/sokrypton/ColabFold/blob/main/README.md)
- run in colabfold image to exactly match mmseqs versions

```
eu-login-34 $
wget https://raw.githubusercontent.com/sokrypton/ColabFold/main/setup_databases.sh
chmod +x setup_databases.sh
conda activate colabfold-env
MMSEQS_NO_INDEX=1 ./setup_databases.sh database/ >>setup-databases.txt 2>&1
```

pdb download fails as Singularity image does not have rsync; run manually:
```
PDB_SERVER="rsync.wwpdb.org::ftp"
PDB_PORT="33444"
mkdir -p pdb/divided
mkdir -p pdb/obsolete
rsync -rlpt -v -z --delete --port=${PDB_PORT} ${PDB_SERVER}/data/structures/divided/mmCIF/ pdb/divided
rsync -rlpt -v -z --delete --port=${PDB_PORT} ${PDB_SERVER}/data/structures/obsolete/mmCIF/ pdb/obsolete

PDB_AWS_SNAPSHOT="20240101"
aws s3 cp --no-sign-request --recursive s3://pdbsnapshots/${PDB_AWS_SNAPSHOT}/pub/pdb/data/structures/divided/mmCIF/ pdb/divided/
aws s3 cp --no-sign-request --recursive s3://pdbsnapshots/${PDB_AWS_SNAPSHOT}/pub/pdb/data/structures/obsolete/mmCIF/ pdb/obsolete/
  
touch PDB_MMCIF_READY
```