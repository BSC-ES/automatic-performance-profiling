#!/bin/bash
#####################################################################################################################
# populate_store.sh
# Brief: Pre-populates the shared HPCW ExternalData object cache with the model inputs referenced by a HPCW source
#        tree. The compilation jobs stage the inputs with CMake's ExternalData, which downloads them from the DKRZ
#        Swift store declared in the HPCW cmake/fetch*.cmake scripts. The ICON inputs are several tens of GB, so
#        downloading them inside the login node compilation job is slow and prone to network failures. Downloaded
#        once into the shared cache (MODEL.STORE of the hpcw proj.yml) they are reused by every arch and experiment.
#        Downloads are parallel, resumable (curl -C -) and validated against the hash of the .md5/.sha256 descriptor.
#####################################################################################################################

set -u -o pipefail

self=$(basename "$0")
store=${HPCW_STORE:-}
jobs=4
dry_run=false
source_dir=

#####################################################################################################################
# Brief: Prints the script usage
# Param: None
#####################################################################################################################
function usage()
{
    cat << USAGE
Usage: ${self} [-s STORE] [-j JOBS] [-n] HPCW_SOURCE_DIR

Pre-populates the shared ExternalData object cache of the HPCW model (ICON/NEMO
inputs) so the compilation jobs do not have to download them again.

Arguments:
  HPCW_SOURCE_DIR  HPCW checkout used by the compilation, e.g.
                   <experiment>/compilation/<ARCH> (\${HPCW_SOURCE_DIR})

Options:
  -s STORE         Object cache directory (default: \${HPCW_STORE}, or MODEL.STORE of the hpcw proj.yml)
  -j JOBS          Number of parallel downloads (default: ${jobs})
  -n               Dry-run, only report the missing objects
  -h               Show this help

Example:
  ${self} -s /gpfs/scratch/bsc032333/hpcw-store -j 4 /esarchive/autosubmit/<expid>/compilation/O3_prod
USAGE
}

#####################################################################################################################
# Brief: Parses the script arguments
# Param: $@: command line arguments
#####################################################################################################################
function parse_args()
{
    local opt

    while getopts "s:j:nh" opt; do
        case "${opt}" in
            s) store=${OPTARG} ;;
            j) jobs=${OPTARG} ;;
            n) dry_run=true ;;
            h) usage; exit 0 ;;
            *) usage; exit 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    source_dir=${1:-}
    if [ -z "${source_dir}" ] || [ ! -d "${source_dir}" ]; then
        echo "[ERROR] HPCW_SOURCE_DIR is not a directory: '${source_dir}'" >&2
        usage
        exit 1
    fi
    if [ -z "${store}" ]; then
        echo "[ERROR] no object cache given, use -s STORE or export HPCW_STORE" >&2
        exit 1
    fi
}

#####################################################################################################################
# Brief: Downloads one object from the DKRZ Swift store into the shared cache, resuming and validating the hash when
#        a partial or complete file is already there
# Global:
#   - Paths: store
# Param:
#   - $1: hash algorithm (MD5, SHA256, ...)
#   - $2: object hash
#   - $3: object URL
#####################################################################################################################
function fetch_object()
{
    local algo=$1
    local hash=$2
    local url=$3
    local obj=${store}/${algo}/${hash}
    local partial=${obj}.part
    local computed
    local attempt
    local max_attempts=3
    local downloaded=false

    if [ -s "${obj}" ]; then
        echo "[SKIP] ${algo}/${hash} already cached"
        return 0
    fi

    mkdir -p "$(dirname "${obj}")"
    echo "[GET ] ${algo}/${hash} -> ${obj}"
    for attempt in $(seq 1 "${max_attempts}"); do
        # The DKRZ Swift endpoint occasionally fails to resolve or times out, so retry both
        # inside curl and with an outer loop, resuming from the partial file when possible
        if curl -fSL --retry 5 --retry-delay 10 --retry-all-errors --connect-timeout 30 \
            -C - -o "${partial}" "${url}"; then
            downloaded=true
            break
        fi
        echo "[WARN] ${algo}/${hash} download error (attempt ${attempt}/${max_attempts}), retrying" >&2
        sleep 30
    done
    if ! ${downloaded}; then
        echo "[FAIL] ${algo}/${hash} download error, left in ${partial} (rerun to resume)" >&2
        return 1
    fi

    case "${algo}" in
        MD5) computed=$(md5sum "${partial}" | cut -d' ' -f1) ;;
        SHA1) computed=$(sha1sum "${partial}" | cut -d' ' -f1) ;;
        *) computed=$(sha256sum "${partial}" | cut -d' ' -f1) ;;
    esac
    if [ "${computed,,}" != "${hash,,}" ]; then
        echo "[FAIL] ${algo}/${hash} hash mismatch (got ${computed}), removing partial file" >&2
        rm -f "${partial}"
        return 1
    fi

    mv "${partial}" "${obj}"
    echo "[OK  ] ${algo}/${hash} cached"
    return 0
}

#####################################################################################################################
# Brief: Builds the hash -> URL map from the custom fetch scripts of the HPCW source tree
# Param:
#   - $1: HPCW source directory
#   - $2: output file to fill with "<algo> <hash> <url>" entries
#####################################################################################################################
function build_url_map()
{
    local source_dir=$1
    local out_file=$2

    grep -h -oE "(MD5|SHA1|SHA256)/[0-9a-f]{32,64} +https?://[^ ]+" \
        "${source_dir}"/cmake/fetch*.cmake 2>/dev/null \
        | sed 's|/| |' | sort -u > "${out_file}"
}

#####################################################################################################################
# Brief: Main function, resolves the object descriptors and downloads the missing ones in parallel
# Param: None
#####################################################################################################################
function main()
{
    local url_map
    local -a entries=()
    local -a unresolved=()
    local descriptor hash algo url
    local -a missing=()
    local running=0
    local failures=0
    local pending=0

    url_map=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '${url_map}'" EXIT
    build_url_map "${source_dir}" "${url_map}"
    echo "[INFO] ${self}: $(wc -l < "${url_map}") known object URLs"

    # HPCW globs the whole source tree for hash descriptors (inputs/, downloads/, ...);
    # skip the build directory (staged data) and the cache itself when it is linked
    while IFS= read -r descriptor; do
        hash=$(awk 'NR == 1 { print $1 }' "${descriptor}")
        [ -n "${hash}" ] || continue
        case "${descriptor}" in
            *.sha256) algo=SHA256 ;;
            *) algo=MD5 ;;
        esac
        [ -s "${store}/${algo}/${hash}" ] && continue
        url=$(awk -v h="${hash}" '$2 == h { print $3; exit }' "${url_map}")
        if [ -z "${url}" ]; then
            # Third-party sources (downloads/CMakeLists.txt) are fetched by the HPCW build
            # itself and are not part of the inputs staged by the compilation data target
            unresolved+=("${algo}/${hash} (${descriptor#"${source_dir}"/})")
            continue
        fi
        entries+=("${algo} ${hash} ${url}")
    done < <(find "${source_dir}" \( -name build -o -name hpcw-store \) -prune -o \
        \( -name '*.md5' -o -name '*.sha256' \) -print)

    if [ "${#unresolved[@]}" -gt 0 ]; then
        echo "[WARN] ${self}: ${#unresolved[@]} descriptors have no URL in the HPCW fetch scripts (third-party packages):" >&2
        printf '  %s\n' "${unresolved[@]}" >&2
    fi

    # Remove duplicated inputs (same object referenced by several packages)
    if [ "${#entries[@]}" -gt 0 ]; then
        mapfile -t missing < <(printf '%s\n' "${entries[@]}" | sort -u)
    fi
    echo "[INFO] ${self}: ${#missing[@]} objects missing from ${store}"

    if ${dry_run}; then
        if [ "${#missing[@]}" -gt 0 ]; then
            printf '  %s\n' "${missing[@]}"
        fi
        return 0
    fi

    if [ "${#missing[@]}" -eq 0 ]; then
        return 0
    fi

    for entry in "${missing[@]}"; do
        while [ "${running}" -ge "${jobs}" ]; do
            wait -n || failures=$((failures + 1))
            running=$((running - 1))
            pending=$((pending - 1))
        done
        # shellcheck disable=SC2086
        fetch_object ${entry} &
        running=$((running + 1))
        pending=$((pending + 1))
    done
    while [ "${pending}" -gt 0 ]; do
        wait -n || failures=$((failures + 1))
        pending=$((pending - 1))
    done

    if [ "${failures}" -gt 0 ]; then
        echo "[INFO] ${self}: finished with ${failures} incomplete objects, rerun to retry them" >&2
        return 1
    fi
    echo "[INFO] ${self}: shared object cache ${store} is complete"
    return 0
}

parse_args "$@"
main
