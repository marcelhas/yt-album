#!/usr/bin/env bash

set -euo pipefail

# Allows running in debug mode by setting the TRACE environment variable.
# e.g. <TRACE=1 ./yt-album.sh>
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

# Placeholder for an empty URL.
URL="https://www.youtube.com/watch?v=lmvUFhjZdFc"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

usage() {
    cat <<USAGE
Usage: ./test.sh URL
Run tests for yt-album.

Options:
  -h, --help
    Show this help message and exit.
  --no-color
    Disable colored output.
  --verbose
    Enable verbose output.

Examples:
  ./test.sh
# Debug mode
TRACE=1 ./test.sh
USAGE
}

die() {
    log_err "${*}"
    usage
    exit 1
}

while :; do
    case ${1-} in
    # Two hyphens ends the options parsing
    --)
        shift
        break
        ;;
    -h | --help | help)
        usage
        exit
        ;;
    --verbose)
        VERBOSE=1
        ;;
    --no-color)
        GREEN=""
        YELLOW=""
        RED=""
        RESET=""
        ;;
    # Anything remaining that starts with a dash triggers a fatal error
    -?*)
        die "The command line option is unknown: $1"
        ;;
    # Anything remaining is treated as content not a parseable option
    *)
        break
        ;;
    esac
    shift
done

main() {
    clean
    log_header
    local test_number=1
    local exit_code=0
    for folder in tests/*; do
        [[ -f "$folder" ]] && continue

        test "$test_number" "$folder" || exit_code=$?

        ((test_number++))
    done

    exit $exit_code
}

clean() {
    rm -rf "${SCRIPT_DIR}/.cache"
    rm -rf "${SCRIPT_DIR}/sections"
}

test() {
    local test_number="$1"
    local folder="$2"

    local sections_file
    local url
    [[ -f "$folder/sections.txt" ]] && sections_file="$folder/sections.txt"
    [[ -f "$folder/url.txt" ]] && url=$(cat "$folder/url.txt")

    local expected
    expected=$(cat "$folder/expected.txt")
    local actual
    actual="$(yt-album "${sections_file-}" "${url-}")"

    local expected_ls
    local actual_ls
    if [[ -f "$folder/ls.txt" ]]; then
        expected_ls="$(cat "$folder/ls.txt")"
        actual_ls="$(ls sections)"
    fi

    if ! is_ok "$expected" "$actual"; then
        log_not_ok "$test_number" "$folder" "$expected" "$actual"
        (exit 1)
    elif ! is_ok "${expected_ls-}" "${actual_ls-}"; then
        log_not_ok "$test_number" "$folder" "${expected_ls-}" "${actual_ls-}"
        (exit 2)
    else
        log_ok "$test_number" "$folder"
        (exit 0)
    fi
}

yt-album() {
    local sections_file="$1"
    local url="$2"
    if [[ -n "${sections_file-}" ]]; then
        ./yt-album.sh --no-color --no-progress --sections "$sections_file" -- "$URL" 2>&1
    else
        ./yt-album.sh --no-color --no-progress -- "$url" 2>&1
    fi
}

is_ok() {
    local expected="$1"
    local actual="$2"
    [[ "$actual" == "$expected" ]]
}

log_ok() {
    local test_number="$1"
    local test_name="$2"
    printf "${GREEN}ok %s:${RESET} %s\n" "$test_number" "$test_name"
}

log_not_ok() {
    local test_number="$1"
    local test_name="$2"
    local expected="$3"
    local actual="$4"

    printf "${RED}not ok %s:${RESET} %s\n" "$test_number" "$test_name"
    if [[ -n "${VERBOSE-}" ]]; then
        log_err "---"
        log_warn "Expected:"
        log_succ "$expected"
        log_warn "Actual:"
        log_err "$actual"
    fi
}

log_header() {
    count="$(find tests/* -maxdepth 1 -type d | wc -l)"
    # See <https://testanything.org/>.
    printf "%s\n" "TAP version 14"
    printf "%s\n" "1..$count"
}

log_succ() {
    printf "${GREEN}%s${RESET}\n" "${*}"
}

log_warn() {
    printf "${YELLOW}%s${RESET}\n" "${*}" 1>&2
}

log_err() {
    printf "${RED}%s${RESET}\n" "${*}" 1>&2
}

main
