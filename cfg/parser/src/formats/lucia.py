"""LUCIA coupling report (``lucia_lite_results/table.csv``)."""


def load(entry, case: str, component: str) -> dict:
    """Parse the LUCIA coupling table of one case.

    The ``Coupled`` row becomes the case-level values (``sypd``, ``SYPD`` and the
    coupling costs), while every other row is a component of the case.

    Args:
        entry (src.mapping.Input): Mapping entry with the matched files.
        case (str): Case the files belong to.
        component (str): Unused, LUCIA describes every component at once.

    Returns:
        dict: Case-level payload including the ``components`` section.
    """
    import pandas as pd

    case_data = {"components": {}}
    for filename in entry.files:
        lucia_df = pd.read_csv(filename)
        for _, row in lucia_df.iterrows():
            component_name = row["component_name"]
            if component_name == "oceanx":
                component_name = "nemo"
            elif component_name == "OpenIFS":
                component_name = "oifs"

            if component_name == "Coupled":
                case_data.update(row[1:].to_dict())
                case_data["SYPD"] = case_data["sypd"]
            else:
                case_data["components"][component_name] = row[1:].to_dict()
                case_data["components"][component_name]["SYPD"] = (
                    case_data["components"][component_name]["sypd"]
                )

    return {case: case_data}
