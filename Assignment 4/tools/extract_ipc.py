import glob, re, pathlib

num_rx = re.compile(r'[-+]?(?:\d+\.\d*|\d*\.\d+|\d+)(?:[eE][-+]?\d+)?')

def first_float(s: str):
    m = num_rx.search(s)
    return float(m.group(0)) if m else None

def get(fp, key_rx):
    rx = re.compile(key_rx)
    with open(fp) as f:
        for ln in f:
            if rx.search(ln):
                return first_float(ln)
    return None

print("file,ipc,sim_insts,sim_seconds")
for fp in sorted(glob.glob("results/*.txt")):
    name = pathlib.Path(fp).name
    ipc = get(fp, r"(?:^|\.)ipc\b")
    sim_insts = get(fp, r"\bsim_insts\b")
    sim_seconds = get(fp, r"\bsim_seconds\b")
    print(f"{name},{ipc},{sim_insts},{sim_seconds}")
