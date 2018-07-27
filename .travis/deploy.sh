#!/bin/bash -ex

docker_org="${1}"
tag="${2}"

for c in $(< commands.txt); do
  arr_c=(${c//:/ })
  arr_v=(${arr_c//=/ })
  if [ "x${tag}" = "xlatest" ]; then
    docker push ${docker_org}/${arr_v}:${tag}
  else
    docker push ${docker_org}/${arr_v}:${arr_v[1]}-${tag}
  fi
done