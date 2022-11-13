#!/usr/bin/env bash

set -euo pipefail

# Allows running in debug mode by setting the TRACE environment variable.
# e.g. <TRACE=1 ./yt-album.sh>
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

COLOR=1
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

log_succ() {
    printf "${GREEN}%s${RESET}\n" "${*}"
}

log_warn() {
    printf "${YELLOW}%s${RESET}\n" "${*}" 1>&2
}

log_err() {
    printf "${RED}%s${RESET}\n" "${*}" 1>&2
}

log_success_msg() {
    local path="$1"
    log_succ "Done. Your sections are in $path."
}

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
        COLOR=0
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

# Placeholder for the URL.
URL="https://www.youtube.com/watch?v=lmvUFhjZdFc"

count="$(find tests/* -maxdepth 1 -type d | wc -l)"
# See <https://testanything.org/>.
printf "%s\n" "TAP version 14"
printf "%s\n" "1..$count"
i=1
ret=0
for folder in tests/*; do
    [[ -f "$folder" ]] && continue
    dir_name="$(basename "$folder")"
    if [[ -f "$folder"/sections.txt ]]; then
        set +e
        diff=$(diff --color=${COLOR:+"always"} <(./yt-album.sh --no-color --sections "$folder/sections.txt" -- "$URL" 2>&1) "$folder/expected.txt")
        set -e
        if [[ -z "$diff" ]]; then
            log_succ "ok $i - $dir_name"
        else
            ret=1
            log_err "not ok $i - $dir_name"
            [[ -n "${VERBOSE-}" ]] && printf "  ---\n" && printf "%s\n" "$diff" | sed 's/^/  /'
        fi
        ((i++))
    fi

    if [[ -f "$folder"/url.txt ]]; then
        url=$(cat "$folder"/url.txt)
        set +e
        output_diff=$(diff --color=${COLOR:+"always"} <(./yt-album.sh --no-color -- "$url" 2>&1) "$folder/expected.txt")
        ls_diff=$(diff --color=${COLOR:+"always"} <(ls ./sections) "$folder/ls.txt")
        set -e
        if [[ -z "$output_diff" && -z "$ls_diff" ]]; then
            log_succ "ok $i - $dir_name"
        else
            ret=1
            log_err "not ok $i - $dir_name"

            if [[ -n "${VERBOSE-}" && -n $output_diff ]]; then
                printf "  ---\n"
                printf "  %s\n" "$folder/expected.txt"
                printf "%s\n" "$output_diff" | sed 's/^/  /'
            fi

            if [[ -n "${VERBOSE-}" && -n $ls_diff ]]; then
                printf "  ---\n"
                printf "  %s\n" "$folder/ls.txt"
                printf "%s\n" "$ls_diff" | sed 's/^/  /'
            fi
        fi
        ((i++))
    fi
done

exit $ret
