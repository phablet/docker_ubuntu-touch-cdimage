#!/bin/bash

cd $(dirname $0)
set -e

IMAGE_REPO=phablet/ubuntu-touch-daily-preinstalled

IMAGE_BASE_URL_vivid=http://cdimage.ubuntu.com/ubuntu-touch/vivid/daily-preinstalled/current
IMAGE_BASE_URL_xenial=http://cdimage.ubuntu.com/ubuntu-touch/daily-preinstalled/current

QEMU_ARCH_armhf=arm
QEMU_ARCH_i386=i386

do_update() {
  local suite=$1
  local arch=$2

  local rootfs_dir=${suite}/${arch}
  local custom_dir=${rootfs_dir}/custom
  local rootfs_tar_name=${suite}-preinstalled-touch-${arch}
  local custom_tar_name=${suite}-preinstalled-touch-${arch}.custom
  local image_id_rootfs=${IMAGE_REPO}:${rootfs_tar_name}
  local image_id_custom=${IMAGE_REPO}:${custom_tar_name}

  eval "local qemu_arch=\${QEMU_ARCH_${arch}}"
  [ -z "${qemu_arch}" ] && (echo "Unsupported arch: ${arch}" >&2; exit 1)

  eval "local base_url=\${IMAGE_BASE_URL_${suite}}"
  [ -z "${base_url}" ] && (echo "Unsupported suite: ${suite}" >&2; exit 1)

  (cd ${rootfs_dir}; wget --timestamping --continue ${base_url}/${rootfs_tar_name}.tar.gz)
  (cd ${custom_dir}; wget --timestamping --continue ${base_url}/${custom_tar_name}.tar.gz)

  cat Dockerfile.template | \
      sed -e "s,@IMAGE_BASE_URL@,${base_url},g" \
        -e "s,@IMAGE_SUITE@,${suite},g" \
        -e "s,@IMAGE_ARCH@,${arch},g" \
        -e "s,@IMAGE_QEMU_ARCH@,${qemu_arch},g" \
      > ${rootfs_dir}/Dockerfile \
    && docker build -t ${image_id_rootfs} ${rootfs_dir}

  cat Dockerfile.custom.template | \
      sed -e "s,@IMAGE_BASE_URL@,${base_url},g" \
        -e "s,@IMAGE_SUITE@,${suite},g" \
        -e "s,@IMAGE_ARCH@,${arch},g" \
      > ${custom_dir}/Dockerfile \
    && docker build -t ${image_id_custom} ${custom_dir}
}

for target in $(find . -maxdepth 2 -mindepth 2 -type d | grep -v git);
do
  suite=$(echo $target | cut -d/ -f2)
  arch=$(echo $target | cut -d/ -f3)
  do_update $suite $arch
done
