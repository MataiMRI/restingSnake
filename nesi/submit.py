#!/usr/bin/env python3

import sys
import signal
from subprocess import Popen, run, PIPE

proc = Popen(["sbatch", "--parsable", "--wait"] + sys.argv[1:], stdout=PIPE)


def signal_handler(sig, frame):
    jobid = proc.stdout.read().strip().decode()
    print(f"cancelling job {jobid}")
    if ";" in jobid:
        jobid, cluster = jobid.split(";", maxsplit=1)
        run(["scancel", jobid, "--clusters", cluster])
    else:
        run(["scancel", jobid])
    proc.terminate()
    sys.exit(1)


signal.signal(signal.SIGINT, signal_handler)
proc.wait()
sys.exit(proc.returncode)
