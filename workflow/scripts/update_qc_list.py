import argparse
from pathlib import Path

import pandas as pd

parser = argparse.ArgumentParser(description="Update a subject session in QC file")
parser.add_argument(
    "qc_file", help=".csv file listing entries (subject/session) for QC"
)
parser.add_argument("subject", help="subject to add/reset in QC")
parser.add_argument("session", help="session to add/reset in QC")
args = parser.parse_args()

qc_file = Path(args.qc_file)
if not qc_file.is_file():
    dset = pd.DataFrame(
        columns=["subject", "session", "func_qc", "anat_qc", "anat_template"]
    )
else:
    dset = pd.read_csv(qc_file)

dset = dset.set_index(["subject", "session"])
dset.loc[(args.subject, args.session), "func_qc"] = False
dset.loc[(args.subject, args.session), "anat_qc"] = False
dset.loc[(args.subject, args.session), "anat_template"] = args.session

dset.to_csv(qc_file)
