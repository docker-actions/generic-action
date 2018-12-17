#!/bin/bash -e

docker_org="${1}"
tag="${2}"

declare -A build_pids

echo "Worker: ${WORKER}. Max workers: ${MAX_WORKERS}"

from_i=$(($(($WORKER-1))*$MAX_WORKERS))
to_i=$(($WORKER*$MAX_WORKERS))
i=0
echo "From: ${from_i}; to: ${to_i}"

OLDIFS=$IFS
IFS=$'\n'
for c in $(< commands.txt); do
  i=$(($i+1))
  if [ $i -gt $from_i -a $i -le $to_i ]; then
    # IMAGE_NAME, IMAGE_TAG, REQUIRED_PACKAGES
    eval $c
    echo -e "#!/usr/bin/env bash\nset -Eeuo pipefail\nexec ${IMAGE_NAME} \"\$@\"" > ${IMAGE_NAME}.entrypoint.sh
    if [ "x${tag}" = "xlatest" ]; then
      image_tag=${tag}
    else
      image_tag=${IMAGE_TAG}-${tag}
    fi
    echo Building ${IMAGE_NAME}:${image_tag}
    docker build --build-arg REQUIRED_PACKAGES --build-arg IMAGE_NAME -t ${docker_org}/${IMAGE_NAME}:${image_tag} . >${IMAGE_NAME}.log 2>&1 &
    build_pids[${IMAGE_NAME}]=$!
  else
    echo "Index: ${i} does not belong to worker ${WORKER}"
  fi

  if [ $i -eq $to_i ]; then
    from_i=$(($from_i+$(($MAX_WORKERS*$MAX_WORKERS))))
    to_i=$(($from_i+$MAX_WORKERS))
    echo "New from: ${from_i}; to: ${to_i}"
  fi
done
IFS=$OLDIFS

for n in "${!build_pids[@]}"; do
  echo Waiting for $n to build
  until tail --pid=${build_pids[$n]} -f ${n}.log; do
    echo "Failed tailing ${n}.log. Retrying in 1 second..."
    sleep 1
  done
  wait ${build_pids[$n]} && echo "Build complete for ${n}" || (echo "Failed building ${n}. Log output:" && cat ${n}.log && false)
done