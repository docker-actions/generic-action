ARG ROOTFS=/build/rootfs

FROM ubuntu:jammy as build

ARG REQUIRED_PACKAGES=""
ARG IMAGE_NAME=""
ARG ROOTFS
ARG NODE_MAJOR=20

ENV BUILD_DEBS /build/debs
ENV DEBIAN_FRONTEND noninteractive
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE true

RUN : "${IMAGE_NAME:?Build argument needs to be set and non-empty.}"
RUN : "${ROOTFS:?Build argument needs to be set and non-empty.}"

SHELL ["bash", "-Eeuc"]

# Build pre-requisites
RUN mkdir -p ${BUILD_DEBS} ${ROOTFS}/{sbin,usr/bin,usr/local/bin,opt}

# Node pre-requisites
RUN [ "x${IMAGE_NAME}" = "xnode" ] || [ "x${IMAGE_NAME}" = "xnodejs" ] \
      && apt-get update \
      && apt-get install -y ca-certificates curl gnupg \
      && mkdir -p /etc/apt/keyrings \
      && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
      && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
      || echo Skipping node setup

# Fix permissions
RUN chown -Rv 100:root $BUILD_DEBS

# Unpack required packges to rootfs
RUN set -Eeuo pipefail; \
    apt-get update; \
    cd ${BUILD_DEBS}; \
    for pkg in $REQUIRED_PACKAGES; do \
      apt-get download $pkg; \
      apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --no-pre-depends -i $pkg | grep '^[a-zA-Z0-9]' | xargs apt-get download ; \
    done; \
    if [ "x$(ls ${BUILD_DEBS}/)" = "x" ]; then \
      echo No required packages specified; \
    else \
      for pkg in ${BUILD_DEBS}/*.deb; do \
        echo Unpacking $pkg; \
        dpkg-deb -x $pkg ${ROOTFS}; \
      done; \
    fi

# Move /sbin out of the way
RUN set -Eeuo pipefail; \
    mv ${ROOTFS}/sbin ${ROOTFS}/sbin.orig; \
    mkdir -p ${ROOTFS}/sbin; \
    for b in ${ROOTFS}/sbin.orig/*; do \
      echo 'cmd=$(basename ${BASH_SOURCE[0]}); exec /sbin.orig/$cmd "$@"' > ${ROOTFS}/sbin/$(basename $b); \
      chmod +x ${ROOTFS}/sbin/$(basename $b); \
    done

COPY ${IMAGE_NAME}.entrypoint.sh ${ROOTFS}/usr/local/bin/entrypoint.sh
RUN chmod +x ${ROOTFS}/usr/local/bin/entrypoint.sh

FROM actions/bash:5.1.16-1-jammy
LABEL maintainer = "ilja+docker@bobkevic.com"

ARG ROOTFS

RUN : "${ROOTFS:?Build argument needs to be set and non-empty.}"

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

COPY --from=build ${ROOTFS} /

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]