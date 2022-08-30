#!/bin/bash

# Allow the user to read in a token from the command line
# If the token does not exist in the command line, ask for
# the required token. The token is a personal access token
# from github
while getopts t: flag
do
    case "${flag}" in
        t) TOKEN=${OPTARG};;
    esac
done

if [ -z "${TOKEN}" ]; then
    read -p "Enter your github oath token: " TOKEN
fi

# Build a Docker/Podman image that contains the data for development
# in the predictor project
set -eux

# Print with extra color
function LOG() {
    echo -e "\033[0;34m${1}\033[0m"
}

# Variables used throughout the course of the program
EMAIL="barbacbd@dukes.jmu.edu"
FULLNAME="Brent Barbachem"
IMAGE="predictor-dev"
DockerFileCreated="False"
ImageBuilt="False"
DockerFileName="DockerfileDev"


# Determine if an image already exists ...
#FoundImages=$(podman image ls | grep "${IMAGE}")
#LOG "${FoundImages}"
#IMAGE="golang"
FoundImages=$(podman image ls | grep "${IMAGE}" | wc -l)
LOG "${FoundImages}"

if [ $FoundImages -gt 0 ]; then
    LOG "delete or update image before proceeding: ${IMAGE}"
else
    # Build the dockerfle specifically for development
    if [ ! -f "${DockerFileName}" ]; then
	LOG "creating Dockerfile ..."
	cat <<EOF >${DockerFileName}
from fedora:latest
MAINTAINER "${FULLNAME}"

# Update all packages
RUN dnf update -y

# R is a dependency to this package and must be installed
# prior to installing the R-python pacakge.
RUN dnf install -y \
    R \
    python3-devel \
    python3-pip \
    git \
    openssh \
    openssh-clients \
    emacs \
    vim \
    gcc \
    gcc-c++

# Grab the lastest package source.
RUN git clone https://${TOKEN}@github.com/barbacbd/predictor.git

# Grab my specific source code for the FEAST project
# I forked this project (do NOT own it) and have made my modifications
# so that there is an extensive python extension.
# Pull that data here and build the source on this vm
RUN git clone https://${TOKEN}@github.com/barbacbd/FEAST.git
RUN cd FEAST && git checkout py_update_setup_for_future_pys
RUN cd FEAST/python && bash -c "./build.sh"

# upgrade pip
RUN python3 -m pip install pip --upgrade

# install the project requirements
RUN python3 -m pip install -r predictor/requirements.txt

RUN git config --global user.email "${EMAIL}"
RUN git config --global user.name "${FULLNAME}"

EOF

	# Set that the dockerfile was created so we can clean it up later
	DockerFileCreated="True"
    fi

    LOG "building image ..."
    podman build -f ./${DockerFileName} -t ${IMAGE}:latest
    ImageBuilt="True"

    # Cleanup any Dockerfile that may have been created
    if [[ "${DockerFileCreated}" == "True" ]]; then
	LOG "destroying dockerfile ..."
	rm DockerfileDev
    else
	LOG "no dockerfile created, skipping destruction ..."
    fi

fi


# Provide final feedback to the user
if [[ "${ImageBuilt}" == "True" ]]; then
    LOG "podman run -it ${IMAGE}:latest /bin/bash"
else
    LOG "no image built ..."
fi
