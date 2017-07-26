FROM ubuntu:14.04

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

ENV JQ_VERSION 1.5

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    make \
    python-pip \
    realpath \
    vim \
    wget && \
    pip install --upgrade pip && \
    apt-get clean
RUN pip install setuptools \
    awscli

# Import stedolan PGP key (jq)
RUN wget -nv https://raw.githubusercontent.com/stedolan/jq/master/sig/jq-release.key && \
    gpg --import jq-release.key && \
    gpg --fingerprint 0x71523402 | grep 'Key fingerprint = 4FD7 01D6 FA9B 3D2D F5AC  935D AF19 040C 7152 3402' && \
    if [ "$?" != "0" ]; then echo "Invalid PGP key!"; exit 1; fi

# Install jq
RUN cd /tmp && \
    wget -nv https://github.com/stedolan/jq/releases/download/jq-$JQ_VERSION/jq-linux64 && \
    wget -nv https://raw.githubusercontent.com/stedolan/jq/master/sig/v$JQ_VERSION/jq-linux64.asc && \
    gpg --verify jq-linux64.asc jq-linux64 && \
    chmod +x jq-linux64 && \
    mv jq-linux64 /usr/local/bin/jq
