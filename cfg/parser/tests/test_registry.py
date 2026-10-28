from src.registry import ALL_FORMATS, COMPONENT_FORMATS, MODEL_DEFAULT_FORMAT


def test_every_default_format_exists():
    for component, file_format in MODEL_DEFAULT_FORMAT.items():
        assert file_format in ALL_FORMATS, f"{component} points at an unknown format"


def test_component_and_case_formats_are_disjoint():
    assert set(COMPONENT_FORMATS).isdisjoint(ALL_FORMATS.keys() - COMPONENT_FORMATS.keys())


def test_loaders_are_callable():
    assert all(callable(loader) for loader in ALL_FORMATS.values())
