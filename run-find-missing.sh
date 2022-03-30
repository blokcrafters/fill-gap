#!/bin/bash

usage()
{
  printf "Usage: $0 -n {main|test}\n" 1>&2
  printf '  Run the find-missing-blocks.py python script once.\n' 1>&2
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


connjson=$(cat ../../connections.json)
es_proto=$(printf "${connjson}" | jq -r '.elasticsearch.protocol')
es_user=$(printf "${connjson}" | jq -r '.elasticsearch.user')
es_pass=$(printf "${connjson}" | jq -r '.elasticsearch.pass')
es_host=$(printf "${connjson}" | jq -r '.elasticsearch.host')
chain=$(cat "../../chains/wax${net}.config.json" | jq -r '.settings.chain')

source pyvenv/bin/activate
python3 ./find-missing-blocks.py "${chain}" "${es_proto}://${es_user}:${es_pass}@${es_host}" || exit 1

exit 0
