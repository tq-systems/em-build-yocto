#
# Yocto base image which includes dependencies for yocto builds
#

ARG BASE_REGISTRY
ARG BASE_DOCKER_TAG
FROM ${BASE_REGISTRY}/ubuntu:${BASE_DOCKER_TAG}

# Main part of the dependencies are copied from:
# - https://docs.yoctoproject.org/5.0.19/ref-manual/system-requirements.html#supported-linux-distributions
# Added:
# - jq and pigz are needed for further artifacts processing

RUN apt-get update && apt-get --yes upgrade && apt-get install --yes \
	build-essential chrpath cpio debianutils diffstat file gawk gcc git iputils-ping libacl1 liblz4-tool locales python3 python3-git python3-jinja2 python3-pexpect python3-pip python3-subunit socat texinfo unzip wget xz-utils zstd \
	jq \
	pigz \
&& apt-get autoremove --yes && apt-get clean --yes

RUN locale-gen "en_US.UTF-8"

# install the TQ-EM shell library
ENV LIB_SHELL_VERSION=2.1.0
RUN git clone https://github.com/tq-systems/em-lib-shell /tmp/libshell \
	&& git -C /tmp/libshell checkout v${LIB_SHELL_VERSION} \
	&& make -C /tmp/libshell install && rm -rf /tmp/libshell
