#!/bin/bash -e

docker_org="${1}"
tag="${2}"

declare -A build_pids

echo "Worker: ${WORKER}. Max workers: ${MAX_WORKERS}"

from_i=$(($(($WORKER-1))*$MAX_WORKERS))
to_i=$(($WORKER*$MAX_WORKERS))
i=0
echo "From: ${from_i}; to: ${to_i}"
for c in $(< commands.txt); do
  i=$(($i+1))
  if [ $i -gt $from_i -a $i -le $to_i ]; then
    arr_c=(${c//:/ })
    arr_v=(${arr_c//=/ })
    if [ "x${tag}" = "xlatest" ]; then
      image_tag=${tag}
    else
      image_tag=${arr_v[1]}-${tag}
    fi
    echo Building ${arr_v}:${image_tag}
    docker push ${docker_org}/${arr_v}:${image_tag} >${arr_v}.log 2>&1 &
    build_pids[${arr_v}]=$!
  else
    echo "Index: ${i} does not belong to worker ${WORKER}"
  fi

  if [ $i -eq $to_i ]; then
    from_i=$(($from_i+$(($MAX_WORKERS*$MAX_WORKERS))))
    to_i=$(($from_i+$MAX_WORKERS))
    echo "New from: ${from_i}; to: ${to_i}"
  fi
done

for n in "${!build_pids[@]}"; do
  echo Waiting for $n to build
  until tail --pid=${build_pids[$n]} -f ${n}.log; do
    echo "Failed tailing ${n}.log. Retrying in 1 second..."
    sleep 1
  done
  wait ${build_pids[$n]} && echo "Build complete for ${n}" || (echo "Failed building ${n}. Log output:" && cat ${n}.log && false)
done