#!/bin/bash

usage()
{
  printf "Usage: $0 -n {main|test} -c count\n" 1>&2
  printf '  Run the fill-gap.sh script *count* number of times.\n' 1>&2
  printf '  exit code 0: success\n' 1>&2
  printf '  exit code 1: failure\n' 1>&2
  printf '  exit code 2: usage error\n' 1>&2
  printf '\n' 1>&2
  printf '  -h    Print the usage message\n' 1>&2
  printf '  -n network\n' 1>&2
  printf "        The allowed choices for network are 'main' or 'test'\n" 1>&2
  printf '  -c count\n' 1>&2
  printf "        The number of times to run the fill-gap.sh script.\n" 1>&2
  printf '\n' 1>&2
  exit 2
}

net=""
count=""

while getopts "c:hn:" o; do
  case "${o}" in
    c) count="$OPTARG" ;;
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
if [ -z "${count}" ]; then
  printf "A '-c count' option is required.\n" 1>&2
  exit 2
fi
if [[ "${count}" =~ [^[:digit:]] ]]; then
  printf "The count value must contain only digits.\n" 1>&2
  exit 2
fi


for n in $(seq 1 "${count}")
do
  ./fill-gap.sh -n "${net}" || exit 1
done

exit 0
