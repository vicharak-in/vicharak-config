FROM --platform=linux/arm64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update

RUN apt-get build-dep -y --no-install-recommends | apt-get install -y git-buildpackage debhelper pandoc shellcheck

WORKDIR /vicharak-config

COPY . /vicharak-config/

RUN make deb -j$(nproc --all)

# Copy the *.deb files to the host
VOLUME ["/vicharak-config"]

# Specify the command to run when the container starts
CMD ["/bin/bash"]
