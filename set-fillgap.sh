#!/bin/bash

usage()
{
  printf "Usage: $0 -n {main|test} -b begin_block_number -e end_block_number\n" 1>&2
  printf '  Set the hyperion begin_block and end_block for a fillgap configuration.\n' 1>&2
  printf '  exit code 0: successfully set the hyperion fillgap configuration\n' 1>&2
  printf '  exit code 1: did not set the fillgap configuration for the hyperion indexer\n' 1>&2
  printf '  exit code 2: usage error\n' 1>&2
  printf '\n' 1>&2
  printf '  -h    Print the usage message\n' 1>&2
  printf '  -n network\n' 1>&2
  printf "        The allowed choices for network are 'main' or 'test'\n" 1>&2
  printf '  -b begin_block_number\n' 1>&2
  printf "        Set the beginning block number for re-indexing blocks to 'begin_block_number'.\n" 1>&2
  printf "        'begin_block_number' is a required option and must contain only digits.\n" 1>&2
  printf '  -e end_block_number\n' 1>&2
  printf "        Set the ending block number for re-indexing blocks to 'end_block_number'.\n" 1>&2
  printf "        'end_block_number' is a required option and must contain only digits.\n" 1>&2
  printf '\n' 1>&2
  exit 2
}

net=""
begin_block=""
end_block=""

while getopts "b:e:hn:" o; do
  case "${o}" in
    b) begin_block="$OPTARG" ;;
    e) end_block="$OPTARG" ;;
    h) usage ;;
    n) net="$OPTARG" ;;
    ?) usage ;;
  esac
done
shift $((OPTIND-1))
if [ -n "$*" ]; then
  printf 'There are unexpected arguments.\n' 1>&2
  usage
fi
if [ -z "${net}" ]; then
  printf "A '-n network' option is required.\n" 1>&2
  exit 2
elif [ "${net}" != 'main' -a "${net}" != 'test' ]; then
  printf "The '-n network' option MUST be 'main' or 'test'\n" 1>&2
  exit 2
fi
if [ -z "${begin_block}" ]; then
  printf "A '-b begin_block_number' option is required.\n" 1>&2
  exit 2
fi
if [[ "${begin_block}" =~ [^[:digit:]] ]]; then
  printf "The begin_block_number value must contain only digits.\n" 1>&2
  exit 2
fi
if [ -z "${end_block}" ]; then
  printf "A '-e end_block_number' option is required.\n" 1>&2
  exit 2
fi
if [[ "${end_block}" =~ [^[:digit:]] ]]; then
  printf "The end_block_number value must contain only digits.\n" 1>&2
  exit 2
fi


fillgap_filename="./wax${net}-fillgap.config.json.tmpl"

if ! sed -i "${fillgap_filename}" -e "/start_on/s/: [[:digit:]]*,/: ${begin_block},/" -e "/stop_on/s/: [[:digit:]]*,/: ${end_block},/"; then
  printf "Failed to set the block numbers in the file '${fillgap_filename}'\n" 1>&2
  exit 1
fi


exit 0
