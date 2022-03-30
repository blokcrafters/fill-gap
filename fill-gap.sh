#!/bin/bash

usage()
{
  printf "Usage: $0 -n {main|test}\n" 1>&2
  printf '  Find the first gap and run the indexer script to fill it.\n' 1>&2
  printf '  exit code 0: success\n' 1>&2
  printf '  exit code 1: failure\n' 1>&2
  printf '  exit code 2: usage error\n' 1>&2
  printf '\n' 1>&2
  printf '  -h    Print the usage message\n' 1>&2
  printf '  -n network\n' 1>&2
  printf "        The allowed choices for network are 'main' or 'test'\n" 1>&2
  printf '\n' 1>&2
  exit 2
}

net=""

while getopts "hn:" o; do
  case "${o}" in
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


printf "Finding the first gap...\n"
gap=$(./run-find-missing.sh -n "${net}")
if [[ "$gap" != Gap:* ]]; then
  printf 'run-find-missing.sh output was malformed.\n'
  exit 1
fi
IFS=':' read -ra gaparray <<< "$gap"
gapword="${gaparray[0]}"
gapstart="${gaparray[1]}"
gapend="${gaparray[2]}"

if [ "${gapstart}" == 'None' -o "${gapend}" == 'None' ]; then
  printf "Gap start is '${gapstart}'\n"
  printf "Gap end is '${gapend}'\n"
  printf 'Gap start or end or both are None.\n'
  exit 1
fi

printf "Gap starts at block ${gapstart} and ends at ${gapend}\n"

./set-fillgap.sh -n "${net}" -b "${gapstart}" -e "${gapend}" || exit 1
if [ ! -f ./indexer-start.sh ]; then
  printf 'You need to copy indexer-start.sh.example to indexer-start.sh and change the lines\n'
  printf 'in it that will cause a Hyperion indexer to start using the indicated config file\n'
  exit 1
fi
if [ ! -x ./indexer-start.sh ]; then
  printf 'Please make indexer-start.sh executable.\n'
  exit 1
fi
./indexer-start.sh -n "${net}" || exit 1

while true; do
  indexer_name="wax${net}-indexer"
  indexer_status=$(pm2 jlist | jq -r '.[]|select(.name == "'${indexer_name}'")|.pm2_env.status')
  if [ "${indexer_status}" == "stopped" ]; then
    break
  fi
  second=$(date '+%S')
  second="$((10#${second}))"
  if [ "$((${second} % 5))" == "0" ]; then
    printf "The Indexer is running at $(date).\n"
  fi
  sleep 1
done
printf "The Indexer has stopped at $(date).\n"

exit 0
