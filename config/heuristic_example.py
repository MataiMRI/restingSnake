def create_key(template, outtype=("nii.gz",), annotation_classes=None):
    if template is None or not template:
        raise ValueError("Template must be a valid format string")
    return template, outtype, annotation_classes


def infotodict(seqinfo):
    """Heuristic evaluator for determining which runs belong where
    allowed template fields - follow python string module:
    item: index within category
    subject: participant id
    seqitem: run number during scanning
    subindex: sub index within group
    """
    t1w = create_key(
        "sub-{subject}/{session}/anat/sub-{subject}_{session}_run-00{item:01d}_T1w"
    )
    func_rest = create_key(
        "sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_run-00{item:01d}_bold"
    )

    info = {t1w: [], func_rest: []}

    for idx, s in enumerate(seqinfo):
        if (s.dim1 == 512) and (s.dim2 == 512) and ("BRAVO" in s.sequence_name):
            info[t1w].append(s.series_id)
        if (s.dim1 == 64) and (s.dim2 == 64) and ("epiRT" in s.sequence_name):
            info[func_rest].append(s.series_id)

    return info
