ARG CUDA_VERSION=11.8.0
ARG COLABFOLD_VERSION=1.5.5
FROM nvidia/cuda:${CUDA_VERSION}-base-ubuntu22.04

COPY colabfold.yml ./

RUN apt-get update && apt-get install -y wget git libxau6 libxau-dev cuda-nvcc-$(echo $CUDA_VERSION | cut -d'.' -f1,2 | tr '.' '-') --no-install-recommends --no-install-suggests && rm -rf /var/lib/apt/lists/* && \
    wget -qnc https://github.com/conda-forge/miniforge/releases/download/23.11.0-0/Mambaforge-23.11.0-0-Linux-x86_64.sh && \
    bash Mambaforge-23.11.0-0-Linux-x86_64.sh -bfp /usr/local && \
    mamba config --set auto_update_conda false && \
    rm -f Mambaforge-23.11.0-0-Linux-x86_64.sh && \
    PIP_NO_DEPS=1 PIP_IGNORE_INSTALLED=1 CONDA_OVERRIDE_CUDA=$(echo $CUDA_VERSION | cut -d'.' -f1,2) mamba env create -f colabfold.yml && \
    mamba clean -afy

ENV PATH /usr/local/envs/colabfold/bin:$PATH
ENV MPLBACKEND Agg

VOLUME cache
ENV MPLCONFIGDIR /cache
ENV XDG_CACHE_HOME /cache
