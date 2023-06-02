import argparse
from pathlib import Path

import pandas as pd

parser = argparse.ArgumentParser(
    description="Update QC file with sessions from a subject"
)
parser.add_argument(
    "qc_file", help=".csv file listing entries (subject/session) for QC"
)
parser.add_argument("subject_folder", help="subject folder to add/update in QC")
args = parser.parse_args()

qc_file = Path(args.qc_file)
if not qc_file.is_file():
    dset = pd.DataFrame(columns=["subject", "session", "anat_qc", "func_qc"])
else:
    dset = pd.read_csv(qc_file)

dset = dset.set_index(["subject", "session"])

subject_folder = Path(args.subject_folder)

# TODO remove all sessions from the subject first?

for folder in subject_folder.glob("ses-*"):
    _, subject = folder.parent.name.split("-", maxsplit=1)
    _, session = folder.name.split("-", maxsplit=1)
    dset.loc[(subject, session), "anat_qc"] = False
    dset.loc[(subject, session), "func_qc"] = False

dset.to_csv(qc_file)
