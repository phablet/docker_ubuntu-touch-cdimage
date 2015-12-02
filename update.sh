#!/bin/bash

cd $(dirname $0)
set -e

SHA1SUM=${SHA1SUM:-$(which sha1sum)}
IMAGE_SUITE=$1
IMAGE_REVISION=$2
[ -z "${IMAGE_REVISION}" -o -z "${IMAGE_SUITE}" ] && (echo "Missing arguments" >&2; exit 1)

IMAGE_BASE_URL_vivid=http://cdimage.ubuntu.com/ubuntu-touch/vivid/daily-preinstalled/${IMAGE_REVISION}
IMAGE_BASE_URL_xenial=http://cdimage.ubuntu.com/ubuntu-touch/daily-preinstalled/${IMAGE_REVISION}
eval "IMAGE_BASE_URL=\${IMAGE_BASE_URL_${IMAGE_SUITE}}"
[ -z "${IMAGE_BASE_URL}" ] && (echo "Unsupported suite: ${IMAGE_SUITE}" >&2; exit 1)

CUT_DIRS=$(echo ${IMAGE_BASE_URL} | tr / ' ' | wc -w)
CUT_DIRS=$((${CUT_DIRS} - 2))

function do_build() {
  local arch=$1
  local qemu_arch=$2
  qemu_arch=${qemu_arch:-${arch}}

  local rootfs_dir=${IMAGE_SUITE}/rootfs
  local custom_dir=${IMAGE_SUITE}/custom
  local rootfs_tar_name=${IMAGE_SUITE}-preinstalled-touch-${arch}
  local custom_tar_name=${IMAGE_SUITE}-preinstalled-touch-${arch}.custom
  mkdir -p ${rootfs_dir} ${custom_dir}
  (cd ${rootfs_dir}; wget --timestamping --continue ${IMAGE_BASE_URL}/${rootfs_tar_name}.tar.gz)
  (cd ${custom_dir}; wget --timestamping --continue ${IMAGE_BASE_URL}/${custom_tar_name}.tar.gz)

  local image_repo=phablet/ubuntu-touch-cdimage
  local image_id_rootfs=${image_repo}:${rootfs_tar_name}
  local image_id_custom=${image_repo}:${custom_tar_name}

  local IMAGE_SHA1SUM=$(${SHA1SUM} ${rootfs_dir}/${rootfs_tar_name}.tar.gz | awk '{print $1}')
  cat Dockerfile.template | \
      sed -e "s,@IMAGE_REVISION@,${IMAGE_REVISION},g" \
        -e "s,@IMAGE_SHA1SUM@,${IMAGE_SHA1SUM},g" \
        -e "s,@IMAGE_BASE_URL@,${IMAGE_BASE_URL},g" \
        -e "s,@IMAGE_SUITE@,${IMAGE_SUITE},g" \
        -e "s,@IMAGE_ARCH@,${arch},g" \
        -e "s,@IMAGE_QEMU_ARCH@,${qemu_arch},g" \
      > ${rootfs_dir}/Dockerfile \
    && docker build -t ${image_id_rootfs} ${rootfs_dir} \
    && docker tag -f ${image_id_rootfs} ${image_id_rootfs}.${IMAGE_REVISION} \
    && docker tag -f ${image_id_rootfs} ${image_id_rootfs}.${IMAGE_SHA1SUM}

  local IMAGE_SHA1SUM=$(${SHA1SUM} ${custom_dir}/${custom_tar_name}.tar.gz | awk '{print $1}')
  cat Dockerfile.custom.template | \
      sed -e "s,@IMAGE_REVISION@,${IMAGE_REVISION},g" \
        -e "s,@IMAGE_SHA1SUM@,${IMAGE_SHA1SUM},g" \
        -e "s,@IMAGE_BASE_URL@,${IMAGE_BASE_URL},g" \
        -e "s,@IMAGE_SUITE@,${IMAGE_SUITE},g" \
        -e "s,@IMAGE_ARCH@,${arch},g" \
      > ${custom_dir}/Dockerfile \
    && docker build -t ${image_id_custom} ${custom_dir} \
    && docker tag -f ${image_id_custom} ${image_id_custom}.${IMAGE_REVISION} \
    && docker tag -f ${image_id_custom} ${image_id_custom}.${IMAGE_SHA1SUM}
}

do_build i386
do_build armhf arm
