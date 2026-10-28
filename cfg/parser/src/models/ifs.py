"""IFS timestep statistics (``*-ifs.stat``)."""


def parse_ifs_file(file):
    """Compute the timesteps per second from an IFS statistics file.

    Args:
        file (str): Path to the IFS statistics file.

    Returns:
        dict: ``ts_per_second`` averaged over the timesteps in the file.
    """
    data = {"ts_per_second": 0}
    with open(file, encoding="utf8") as f:
        total_time = 0
        total_ts = 1
        for line in f:
            cols = [s for s in line.split(" ") if s]
            ts_time = float(cols[6])
            total_time += ts_time
            total_ts = int(cols[3])
        data["ts_per_second"] = total_time / total_ts

    return data


def load(entry, case: str, component: str) -> dict:
    """Parse the IFS statistics files of one component.

    Args:
        entry (src.mapping.Input): Mapping entry with the matched files.
        case (str): Case the files belong to.
        component (str): Component the files belong to.

    Returns:
        dict: Component payload merged into the case by the caller.
    """
    payload = {}
    for filename in entry.files:
        if payload:
            print(f"[WARNING] {component}/{case}: several ifs.stat files, using {filename} only")
        payload = parse_ifs_file(filename)
    return payload
