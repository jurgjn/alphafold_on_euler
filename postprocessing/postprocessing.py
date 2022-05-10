#!/usr/bin/env python3

"""postprocessing of an alphafold2 run"""

from __future__ import annotations

from typing import Any, Optional, TypedDict, cast
from collections.abc import Iterable, Sequence
import pickle
import os
import glob
from pathlib import Path
from string import ascii_uppercase, ascii_lowercase

import matplotlib.pyplot as plt
from matplotlib.figure import Figure
import numpy

__version__ = "0.1.0"


class PredictionResult(TypedDict):
    """Prediction result data structure generated by alphafold."""

    plddt: Any
    distogram: dict[str, Any]
    predicted_aligned_error: Any


def main(
    data: Iterable[tuple[str, PredictionResult]],
    features: Optional[dict[str, Any]],
    out_dir: Optional[Path],
) -> None:
    """Main function"""

    data = list(data)
    seq_length: Optional[int] = (
        features.get("seq_length") if features is not None else None
    )
    figs: tuple[tuple[str, Figure], ...] = (
        ("pLDDT", plot_plddt(data)),
        ("distogram", plot_distogram(data)),
        ("paes", plot_paes(data, seq_length) if seq_length is not None else None),
    )

    if out_dir is not None:
        os.makedirs(out_dir, exist_ok=True)
        for label, fig in figs:
            if fig is not None:
                fig.savefig(out_dir / (label + ".svg"))
    else:
        plt.show()


def load_pkl(path: Path) -> dict[str, Any]:
    """Load a single pkl file"""
    with open(path, "rb") as stream:
        data: dict[str, Any] = pickle.load(stream)
        return data


def load_optional_pkl(path: Path) -> Optional[dict[str, Any]]:
    """Load a single pkl file if it exists, otherwise return None"""
    try:
        return load_pkl(path)
    except FileNotFoundError:
        return None


def load_prediction_result(path: Path) -> PredictionResult:
    """Load a single pkl file as a PredictionResult"""
    return cast(PredictionResult, load_pkl(path))


def load_prediction_results(path: Path) -> Iterable[tuple[str, PredictionResult]]:
    """Load output pkls from a folder"""

    for pkl_path in sorted(glob.glob(os.path.join(path, "result_*.pkl"))):
        yield (
            os.path.basename(pkl_path).removeprefix("result_").removesuffix(".pkl"),
            load_prediction_result(Path(pkl_path)),
        )


def plot_plddt(models: Iterable[tuple[str, PredictionResult]]) -> Figure:
    """Generate svg outputs for pLDDT"""
    fig = plt.figure(figsize=(10, 6), dpi=100)

    for label, model in models:
        plt.plot(model["plddt"], label=label)

    plt.xlabel("residue nr.")
    plt.ylabel("pLDDT score")
    plt.legend()
    return fig


def plot_distogram(models: Sequence[tuple[str, PredictionResult]]) -> Figure:
    """Generate svg distogram"""
    fig = plt.figure(figsize=(3 * len(models), 2))
    for n, (label, model) in enumerate(models, start=1):
        plt.subplot(1, len(models), n)
        plt.title(label)
        dist_bins = numpy.argmax(expit(model["distogram"]["logits"]), axis=-1)
        # bins to Å (63 bins from 2 Å to 22 Å):
        dist = 2.0 + dist_bins / 63.0 * 20.0
        plt.imshow(dist)
        cbar = plt.colorbar()
    # Label only the last one:
    cbar.ax.set_ylabel("Distance [Å]")

    return fig


def expit(x: Any) -> Any:
    """expit function"""
    out = numpy.empty_like(x)
    x_negative = x < 0.0
    out[~x_negative] = 1.0 / (1.0 + numpy.exp(-x[~x_negative]))
    e_x = numpy.exp(x[x_negative])
    out[x_negative] = e_x / (1.0 + e_x)
    return out


def plot_paes(
    models: Iterable[tuple[str, PredictionResult]],
    seq_len: int,
    Ls: Optional[list[int]] = None,
) -> Optional[Figure]:
    """Plot predicted aligned error"""
    models = [(m_name, m) for m_name, m in models if "predicted_aligned_error" in m]
    if not models:
        return None
    num_models = len(models)
    fig = plt.figure(figsize=(3 * num_models, 2))
    paes = (model["predicted_aligned_error"][:seq_len][:seq_len] for _, model in models)
    for n, pae in enumerate(paes):
        plt.subplot(1, num_models, n + 1)
        plt.title(f"rank_{n+1}")
        Ln = pae.shape[0]
        plt.imshow(pae, cmap="bwr", vmin=0, vmax=30, extent=(0, Ln, Ln, 0))
        if Ls is not None and len(Ls) > 1:
            plot_ticks(Ls)
        plt.colorbar()
    return fig


def plot_ticks(Ls: list[int]) -> None:
    """Plot ticks in a paes plot"""
    alphabet_list = list(ascii_uppercase + ascii_lowercase)
    Ln = sum(Ls)
    L_prev = 0
    for L_i in Ls[:-1]:
        L = L_prev + L_i
        L_prev += L_i
        plt.plot([0, Ln], [L, L], color="black")
        plt.plot([L, L], [0, Ln], color="black")
    ticks = numpy.cumsum([0] + Ls)
    ticks = (ticks[1:] + ticks[:-1]) / 2
    plt.yticks(ticks, alphabet_list[: len(ticks)])


if __name__ == "__main__":
    import argparse

    _parser = argparse.ArgumentParser(description=os.path.basename(__file__))
    _parser.add_argument(
        "-o",
        dest="out_dir",
        default=None,
        type=Path,
        help="Output folder (none - plot directly to the screen)",
    )
    _parser.add_argument(
        "data",
        type=Path,
        help="Input folder containing alphafold2 output",
    )
    _cmd_args = _parser.parse_args()

    main(
        data=load_prediction_results(_cmd_args.data),
        features=load_optional_pkl(_cmd_args.data / "features.pkl"),
        out_dir=_cmd_args.out_dir,
    )
