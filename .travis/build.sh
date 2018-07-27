#!/bin/bash -ex

docker_org="${1}"
tag="${2}"

for c in $(< commands.txt); do
  arr_c=(${c//:/ })
  arr_v=(${arr_c//=/ })
  arr_p=(${arr_c[1]//;/ })
  echo -e "#!/usr/bin/env bash\nset -Eeuo pipefail\nexec ${arr_v} \"\$@\"" > entrypoint.sh
  if [ "x${tag}" = "xlatest" ]; then
    docker build --build-arg REQUIRED_PACKAGES="$(echo ${arr_p[@]})" -t ${docker_org}/${arr_v}:${tag} .
  else
    docker build --build-arg REQUIRED_PACKAGES="$(echo ${arr_p[@]})" -t ${docker_org}/${arr_v}:${arr_v[1]}-${tag} .
  fi
done