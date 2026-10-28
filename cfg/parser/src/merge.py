"""Helpers to build and navigate the nested dictionary stored in the JSON."""


def dictionary_pointer(dictionary, address):
    """Return the nested dictionary at ``address``, creating the missing sections.

    Args:
        dictionary (dict): The dictionary to traverse and modify.
        address (Iterable): Sequence of keys defining the path.

    Returns:
        dict: The section at ``address``.
    """

    def initialize_dictionary_section(d, section):
        try:
            d[section]
        except KeyError:
            d[section] = {}
        return d[section]

    for step in address:
        dictionary = initialize_dictionary_section(dictionary, step)
    return dictionary


def merge_dictionaries(dict_one, dict_two, path=None):
    """Merge ``dict_two`` into ``dict_one``, keeping the values already present.

    Args:
        dict_one (dict): Destination dictionary, modified in place.
        dict_two (dict): Source dictionary.
        path (list, optional): Current key path, only used in recursive calls.

    Returns:
        dict: ``dict_one`` with the missing keys of ``dict_two`` added.
    """
    path = [] if path is None else path

    if dict_one is None:
        return dict_two

    if dict_two is None:
        return dict_one

    for key in dict_two:
        if key in dict_one:
            if isinstance(dict_one[key], dict) and isinstance(dict_two[key], dict):
                merge_dictionaries(dict_one[key], dict_two[key], path + [str(key)])
            elif dict_one[key] != dict_two[key]:
                continue
        else:
            dict_one[key] = dict_two[key]
    return dict_one
