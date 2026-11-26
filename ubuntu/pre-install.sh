#!/bin/sh

# Set non-interactive mode for apt-get
export DEBIAN_FRONTEND=noninteractive

#upgrade the packages
apt-get update && apt-get upgrade -y

#install packages
apt-get install -y git lsb-release autoconf libtool

# Ubuntu 26 pre-installation steps
export UBUNTU_VERSION="$(lsb_release -rs)"
if [ "$UBUNTU_VERSION" = "26.04" ]; then
    # curl -fsSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
    # dpkg -i /tmp/debsuryorg-archive-keyring.deb
    # echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
    # apt-get update

    # # gcc-15 does not work, old gcc 13 required
    # apt-get install -y gcc-13 g++-13
    # update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-15 15
    # update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 150 \
    # --slave /usr/bin/g++ g++ /usr/bin/g++-13 \
    # --slave /usr/bin/gcov gcov /usr/bin/gcov-13 \
    # --slave /usr/bin/gcc-ar gcc-ar /usr/bin/gcc-ar-13 \
    # --slave /usr/bin/gcc-nm gcc-nm /usr/bin/gcc-nm-13 \
    # --slave /usr/bin/gcc-ranlib gcc-ranlib /usr/bin/gcc-ranlib-13

    #verify mawk version to be 2024XXXXX like Ubuntu 24 version
    mawk_version=$(mawk -W version | awk '{print $3}')
    if [ "${mawk_version:0:4}" != "2024" ]; then
        echo "Warning: mawk version is not 2024XXXXX, it is $mawk_version"
        exit 1
    fi
fi

#get the install script
cd /usr/src && git clone -b "fix-install-ubuntu" https://github.com/alexiionescu/fusionpbx-install.sh.git


#change the working directory
cd /usr/src/fusionpbx-install.sh/ubuntu

