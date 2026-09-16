import yaml
import shutil
import argparse
import os
import re
import subprocess
from typing import Any, Hashable, cast


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Copy experiment configuration and source code for a specific model."
    )
    parser.add_argument(
        "--src-expid",
        "-s",
        type=str,
        required=True,
        help="The source experiment ID to copy from.",
    )
    parser.add_argument(
        "--current-expid",
        "-c",
        type=str,
        required=True,
        help="The current experiment ID to copy to.",
    )
    parser.add_argument(
        "--no-copy-source",
        action="store_true",
        help="Do not copy the source code from the source experiment.",
    )
    args = parser.parse_args()
    return args


class UppercaseKeyLoader(yaml.SafeLoader):
    def construct_mapping(
        self, node: yaml.Node, deep: bool = False
    ) -> dict[Hashable, Any]:
        pairs = self.construct_pairs(node, deep=deep)

        upper_data = {str(k).upper(): v for k, v in pairs}

        return cast(dict[Hashable, Any], upper_data)


def dictionary_pointer(dictionary, address, create_missing_sections=True):
    for step in address:
        if step in dictionary:
            dictionary = dictionary[step]
        elif step not in dictionary:
            if create_missing_sections:
                dictionary[step] = {}
            else:
                raise KeyError(f"Key '{step}' not found in the dictionary.")
    return dictionary


def deep_update_dict(target: dict, updates: dict) -> dict:
    for key, value in updates.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            deep_update_dict(target[key], value)
        else:
            target[key] = value
    return target


def apply_templates_patches(
    jobs_config: dict, proj_dir: str, patches_file: str = "templates_changes.yml"
) -> dict:
    with open(patches_file) as f:
        patches = yaml.safe_load(f)

    general_patches = patches.get("TEMPLATES", {}).get("ALL", [])

    for job_name in jobs_config.get("JOBS", {}):
        if not job_name in jobs_config["JOBS"]:
            continue
        job_patches = patches.get("TEMPLATES", {}).get(job_name, [])
        all_patches = general_patches + job_patches
        if not all_patches:
            continue

        used_job_patch = dict.fromkeys([patch["MATCH"] for patch in job_patches], False)

        job_file_path = f"{proj_dir}/{jobs_config['JOBS'][job_name]['FILE']}"
        with open(job_file_path, "r+") as f:
            modified_lines = ""
            for line in f:
                modified_line = line
                for patch in all_patches:
                    if (
                        not patch.get("FULL_MATCH", False)
                        and patch["MATCH"] in modified_line
                    ) or (
                        patch.get("FULL_MATCH", False)
                        and modified_line.strip() == patch["MATCH"]
                    ):
                        if patch.get("APPEND", False):
                            modified_line = line + patch["REPLACE"]
                        elif patch.get("REPLACE_ONLY_MATCH", False):
                            match_idx = modified_line.find(patch["MATCH"])
                            if match_idx != -1:
                                modified_line = (
                                    modified_line[:match_idx]
                                    + patch["REPLACE"]
                                    + modified_line[match_idx + len(patch["MATCH"]) :]
                                )
                        else:
                            modified_line = patch["REPLACE"] + "\n"
                        used_job_patch[patch["MATCH"]] = True
                modified_lines += modified_line
            f.seek(0)
            f.write(modified_lines)
            f.truncate()

        for patch, used in used_job_patch.items():
            if not used:
                print(f"[WARNING] Patch {patch} was not applied for job {job_name} in file {job_file_path}, check if the match string is correct or if the job file has changed.")

    return jobs_config


def apply_config_changes(
    jobs_config: dict, config_changes_file: str = "config_changes.yml"
) -> dict:
    with open(config_changes_file) as f:
        config_changes = yaml.load(f, Loader=UppercaseKeyLoader) or {}

    jobs_changes = config_changes.get("JOBS", {})
    for job_name, job_changes in jobs_changes.items():
        if job_name in jobs_config.get("JOBS", {}):
            deep_update_dict(jobs_config["JOBS"][job_name], job_changes)

    return jobs_config


def get_dependant_jobs(job_name, jobs_config):
    dependant_jobs = set()
    for job in jobs_config["JOBS"]:
        if "DEPENDENCIES" in jobs_config["JOBS"][job]:
            dependencies = jobs_config["JOBS"][job]["DEPENDENCIES"]
            if type(dependencies) == str:
                dependencies = dependencies.split(" ")
            if job_name in dependencies:
                dependant_jobs.update(get_dependant_jobs(job, jobs_config))
                dependant_jobs.add(job)

    return dependant_jobs


def copy_experiment(src_expid, current_expid, copy_source_code=True):
    src_experiment_dir = f"/esarchive/autosubmit/{src_expid}"
    current_experiment_dir = f"/esarchive/autosubmit/{current_expid}"

    # Copy Auto Monarch source code
    if copy_source_code:
        print(
            f"[INFO] Copying Auto Monarch source code from {src_experiment_dir} to {current_experiment_dir}..."
        )
        subprocess.run(
            [
                "rsync",
                "-rv",
                f"{src_experiment_dir}/proj/auto-monarch/",
                f"{current_experiment_dir}/proj/auto-monarch/",
            ],
            check=True,
        )
        print(f"[INFO] Source code copied successfully.")
    else:
        subprocess.run(
            [
                "rsync",
                "-rv",
                f"{src_experiment_dir}/proj/auto-monarch/templates/",
                f"{current_experiment_dir}/proj/auto-monarch/templates/",
            ],
            check=True,
        )

    src_proj_yml = f"{src_experiment_dir}/conf/proj_{src_expid}.yml"
    src_expdef_yml = f"{src_experiment_dir}/conf/expdef_{src_expid}.yml"
    src_jobs_yml = f"{src_experiment_dir}/conf/jobs_{src_expid}.yml"
    src_platforms_yml = f"{src_experiment_dir}/conf/platforms_{src_expid}.yml"

    current_src_dir = f"{current_experiment_dir}/proj/auto-monarch"
    current_proj_yml = f"{current_src_dir}/autosubmit/configuration/user/model/monarch/proj_monarch.yml"
    current_jobs_yml = (
        f"{current_src_dir}/autosubmit/configuration/core/jobs/model/monarch/jobs.yml"
    )
    current_platforms_yml = (
        f"{current_src_dir}/autosubmit/configuration/user/platforms_monarch.yml"
    )

    with open(f"{current_experiment_dir}/conf/minimal.yml") as minimal_f:
        minimal_dict = yaml.load(minimal_f, Loader=UppercaseKeyLoader)

    with open(
        f"{current_experiment_dir}/conf/minimal.yml", "w", encoding="utf8"
    ) as minimal_f:
        app_project_destination = minimal_dict["PROJECT"]["PROJECT_DESTINATION"]
        if app_project_destination == "auto-monarch":
            app_project_destination = minimal_dict["PROJECT"].get("APP_PROJECT_DESTINATION", "git_project")
        app_project_dir = f"{current_experiment_dir}/proj/{app_project_destination}"
        minimal_dict["PROJECT"]["PROJECT_DESTINATION"] = "auto-monarch"
        minimal_dict["PROJECT"]["APP_PROJECT_DESTINATION"] = app_project_destination
        yaml.dump(minimal_dict, minimal_f)

    if not os.path.exists(f"{current_experiment_dir}/proj/auto-monarch/autosubmit"):
        os.symlink(
            f"{app_project_dir}/autosubmit/",
            f"{current_experiment_dir}/proj/auto-monarch/autosubmit",
        )

    if not os.path.exists(f"{current_experiment_dir}/proj/auto-monarch/cfg"):
        os.symlink(
            f"{app_project_dir}/cfg/",
            f"{current_experiment_dir}/proj/auto-monarch/cfg",
        )

    # Comment out the jobs-execution.yml and jobs-weakscaling.yml lines in the experiment's bootstrap.yml.
    # The standard APP workflow jobs (REMOTE_SETUP, REMOTE_INIDATA, REMOTE_COMPILATION,
    # PREPARE_TESTS, FUNCTIONS_DIR) are not used by the Monarch workflow, which reuses
    # the Auto-Monarch job graph. Standard models keep the line uncommented (default).
    bootstrap_yml = f"{current_src_dir}/autosubmit/configuration/bootstrap.yml"
    with open(bootstrap_yml, "r") as f:
        bootstrap_lines = f.readlines()
    with open(bootstrap_yml, "w") as f:
        for line in bootstrap_lines:
            if ("jobs-execution.yml" in line or "jobs-weakscaling.yml" in line) and not line.strip().startswith("#"):
                f.write(f"    # {line.strip()}\n")
            else:
                f.write(line)

    # Copy Monarch configuration
    shutil.copy(src_proj_yml, current_proj_yml)
    shutil.copy(src_platforms_yml, current_platforms_yml)

    # Modify src expid jobs to app needs

    # Jobs that need to be modified to include FOR loop for ARCH_NAMES
    ARCH_DEPENDANT_JOBS = ["REMOTE_COMPILE", "PREPROCFIX", "PREPROCVAR"]
    # Non-FOR synchronization jobs that aggregate every arch variant of a FOR job,
    # so a FOR job can depend on all of them without nesting FOR sections.
    ARCH_GATE_JOBS = {
        "REMOTE_COMPILE": {"name": "COMPILE_READY", "running": "once"},
        "PREPROCFIX": {"name": "PREPROCFIX_READY", "running": "once"},
        "PREPROCVAR": {"name": "PREPROCVAR_READY", "running": "once"},
    }

    # Variables that need to be modified to have 5 repetitions of the same value to be able to run 5 members with the same configuration
    PER_MEMBER_VARIABLES = [
        ("MONARCH", "BCMETEO"),
        ("MONARCH", "DUSCHEME"),
        ("MONARCH", "SMCCOEF"),
        ("MONARCH", "SMCCOR"),
        ("MONARCH", "DCAL"),
        ("HERMES", "GR", "CONF"),
        ("HERMES", "GR", "EI_CONF"),
    ]

    with open(src_expdef_yml) as f:
        expdef_config = yaml.load(f, Loader=UppercaseKeyLoader)
        datelist = expdef_config["EXPERIMENT"]["DATELIST"]
        chunksizeunit = expdef_config["EXPERIMENT"]["CHUNKSIZEUNIT"]
        chunksize = expdef_config["EXPERIMENT"]["CHUNKSIZE"]

    with open(current_proj_yml) as f:
        proj_config = yaml.load(f, Loader=UppercaseKeyLoader)
        for per_member_variable in PER_MEMBER_VARIABLES:
            a = dictionary_pointer(proj_config, per_member_variable[:-1])
            current_variable_value = a[per_member_variable[-1]]
            current_variable_value = current_variable_value.split(" ")[0]
            current_variable_value = (current_variable_value + " ") * 5
            a[per_member_variable[-1]] = current_variable_value

        proj_config["EXPERIMENT"] = {"DATELIST": datelist}
        proj_config["EXPERIMENT"]["CHUNKSIZEUNIT"] = chunksizeunit
        proj_config["EXPERIMENT"]["CHUNKSIZE"] = chunksize
        proj_config["EXPERIMENT"]["NUMCHUNKS"] = 1
        proj_config["EXPERIMENT"]["MEMBERS"] = "000"

    with open(current_proj_yml, "w") as f:
        yaml.dump(proj_config, f)

    # Modify jobs configuration to add FOR loops for ARCH_NAMES and MEMBERS_FROM for the jobs that need it
    with open(src_jobs_yml) as f:
        src_jobs_config = yaml.load(f, Loader=UppercaseKeyLoader)
        for job in src_jobs_config["JOBS"]:
            if job == "LOCAL_SETUP":
                with open(
                    f"{current_src_dir}/{src_jobs_config['JOBS'][job]['FILE']}", "w"
                ) as f:
                    f.write("print('hello')")

            if "DEPENDENCIES" in src_jobs_config["JOBS"][job]:
                if type(src_jobs_config["JOBS"][job]["DEPENDENCIES"]) == str:
                    dependencies = src_jobs_config["JOBS"][job]["DEPENDENCIES"].split(
                        " "
                    )
                new_dependencies = {}
                modified_dependencies = False
                for dependency in dependencies:
                    if dependency in ARCH_DEPENDANT_JOBS:
                        if job in ARCH_DEPENDANT_JOBS:
                            # The dependent job is itself FOR-expanded, so adding a
                            # FOR dependency here would nest a FOR inside another FOR
                            # section, which Autosubmit's config loader cannot process
                            # reliably. Route through the non-FOR gate job instead.
                            new_dependencies[ARCH_GATE_JOBS[dependency]["name"]] = {}
                        else:
                            new_dependencies[dependency] = {
                                "FOR": {"NAME": "%MODEL.ARCH_NAMES%"}
                            }
                        modified_dependencies = True
                    else:
                        new_dependencies[dependency] = {}
                if modified_dependencies:
                    src_jobs_config["JOBS"][job]["DEPENDENCIES"] = new_dependencies

        # Add non-FOR gate jobs that aggregate every arch variant of a FOR job.
        # Other FOR jobs (e.g. PREPROCFIX, PREPROCVAR) depend on these gates instead
        # of using a FOR dependency, avoiding nested FOR sections.
        for gate_name, gate_config in ARCH_GATE_JOBS.items():
            src_jobs_config["JOBS"][gate_config["name"]] = {
                "DEPENDENCIES": {
                    gate_name: {"FOR": {"NAME": "%MODEL.ARCH_NAMES%"}}
                },
                "FILE": "autosubmit/templates/noop.sh",
                "PLATFORM": "%DEFAULT.LOGIN_PLATFORM%",
                "RUNNING": gate_config["running"],
            }

        script_dir = os.path.dirname(os.path.abspath(__file__))

        # Apply job configuration changes from file
        src_jobs_config = apply_config_changes(
            src_jobs_config, f"{script_dir}/config_changes.yml"
        )

        # Apply templates patches to jobs configuration
        src_jobs_config = apply_templates_patches(
            src_jobs_config,
            f"{current_experiment_dir}/proj/auto-monarch",
            f"{script_dir}/templates_changes.yml",
        )

        # Remove SIM job and its dependant jobs as we don't want to run SIM in the new experiment, and it has a lot of dependant jobs which will also be removed
        dependant_jobs = get_dependant_jobs("SIM", src_jobs_config)
        for job in dependant_jobs:
            del src_jobs_config["JOBS"][job]
        del src_jobs_config["JOBS"]["SIM"]

    with open(current_jobs_yml, "w") as f:
        yaml.dump(src_jobs_config, f)

    print(f"[INFO] Remember to update the platforms configuration with your user:")
    print(f"  - {current_platforms_yml}")


if __name__ == "__main__":
    args = parse_arguments()
    SRC_EXPID = args.src_expid
    CURRENT_EXPID = args.current_expid
    COPY_SOURCE = not args.no_copy_source

    UppercaseKeyLoader.add_constructor(
        "tag:yaml.org,2002:map", UppercaseKeyLoader.construct_mapping
    )

    copy_experiment(SRC_EXPID, CURRENT_EXPID, COPY_SOURCE)
