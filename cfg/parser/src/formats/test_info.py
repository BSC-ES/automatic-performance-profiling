"""``test_info`` files written by the post-processing of every test."""

import csv


def load_csv(filename: str, case: str) -> dict:
    """Parse a ``<case>-test_info.csv`` into the case section of the JSON.

    Each row describes one component, except the ``model`` row, which describes the
    whole model, and the ``experiment`` row, which describes the experiment.

    Args:
        filename (str): Path to the CSV file.
        case (str): Case the file belongs to.

    Returns:
        dict: ``{case: {...}}`` with the per-component and model values.
    """
    case_data = {"components": {}}
    with open(filename, mode="r", encoding="utf8") as test_info_f:
        reader = csv.DictReader(test_info_f)
        for dict_line in reader:
            component_name = dict_line.pop("component")
            # csv.DictReader returns all values as strings; convert known numeric fields
            for numeric_key in ("nproc", "sypd", "grid_points"):
                if numeric_key in dict_line and dict_line[numeric_key] not in (None, ""):
                    try:
                        dict_line[numeric_key] = (
                            int(dict_line[numeric_key])
                            if numeric_key == "nproc"
                            else float(dict_line[numeric_key])
                        )
                    except ValueError:
                        pass  # leave as-is if conversion fails
            if component_name == "experiment":
                case_data.update(dict_line)
            elif component_name == "model":
                case_data.update(dict_line)
            else:
                case_data["components"].setdefault(component_name, {})
                case_data["components"][component_name].update(dict_line)

    return {case: case_data}


def load_yaml(filename: str) -> dict:
    """Load a ``<case>-test_info.yaml``, which already carries the case as its key.

    Args:
        filename (str): Path to the YAML file.

    Returns:
        dict: The parsed document, keyed by case.
    """
    import yaml

    with open(filename, mode="r", encoding="utf8") as test_info_yaml_f:
        return yaml.safe_load(test_info_yaml_f)
