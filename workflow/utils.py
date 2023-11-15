from pathlib import Path
from collections import defaultdict
from dataclasses import dataclass

import yaml
from snakemake.io import glob_wildcards


@dataclass
class RunList:
    """Store information about runs as a structure of arrays"""

    subjects: list[str]
    sessions: list[str]
    entities: list[str]

    def append(self, subject: str, session: str, entity: str):
        self.subjects.append(subject)
        self.sessions.append(session)
        self.entities.append(entity)


def is_functional(entry: str) -> bool:
    """identify if an entry of the QC file is a functional run"""
    return entry.endswith("_bold") or entry.endswith("_dwi")


def list_valid_runs(resultsdir: str) -> RunList:
    """list all valid functional runs from every subjects, based on QC status files"""

    qc_file_pattern = (
        f"{resultsdir}/bids/derivatives/mriqc/sub-{{subject}}_ses-{{session}}_qc.yaml"
    )
    subjects, sessions = glob_wildcards(qc_file_pattern)

    runs = RunList([], [], [])
    templates = defaultdict(dict)

    for subject, session in zip(subjects, sessions):
        qc_file = Path(qc_file_pattern.format(subject=subject, session=session))
        qc_data = yaml.safe_load(qc_file.read_text())

        # skip if there is no anatomical template
        if "anat_template" not in qc_data:
            continue

        # check that anatomy is valid, if from the same subject/session
        anat_template = qc_data["anat_template"]
        if anat_template.startswith(f"sub-{subject}_ses-{session}"):
            anat_entry = anat_template.removeprefix(f"sub-{subject}_ses-{session}_")
            if not qc_data[anat_entry + "_T1w"]:
                continue

        templates[subject][session] = anat_template

        # list all valid functional runs
        for entry in qc_data:
            if not is_functional(entry) or not qc_data[entry]:
                continue

            entity, _ = entry.rsplit("_", maxsplit=1)
            runs.append(subject, session, entity)

    return runs, templates
