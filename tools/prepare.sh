#!/bin/bash
C_NONE="\033[0;00m"
C_GREEN="\033[1;32m"
C_RED_BK="\033[1;41m"
C_YELLOW="\033[1;93m"

WITH_SUDO=""
if [[ $(which sudo) ]]; then 
    echo -e "${C_GREEN}You are going to install SOFA with sudo${C_NONE}"
    WITH_SUDO="sudo -E" 
fi

# Detect OS distribution
# Try source all the release files
for file in /etc/*-release; do
    source $file 
done

if [[ "$NAME" != ""  ]]; then
    OS="$NAME"
    VERSION="$VERSION_ID"
elif [[ -f /etc/debian_version ]]; then
    # Older Debian/Ubuntu/etc.
    OS="Debian"
    VERSION="$(cat /etc/debian_version)"
elif [[ "$(uname)" == "Darwin" ]]; then
    OS="MacOS"
    VERSION="$(uname)"
else
    OS="$(lsb_release -si)"
    VERSION="$(lsb_release -sr)"
fi

function inform_sudo()
{
    if [[ $(which sudo) ]]; then 
        [[ ! -z "$1" ]] && echo "$1"
        # Exit without printing messages if password is still in the cache.
        sudo -n true 2> /dev/null
        [[ $? == 0 ]] && return 0;
        sudo >&2 echo -e "\033[1;33mRunning with root privilege now...\033[0;00m";
        [[ $? != 0 ]] && >&2 echo -e "\033[1;31mAbort\033[0m" && exit 1;
    fi
}

function install_python_packages()
{
    # Install Python packages
    echo -e "${C_GREEN}Installing python packages...${C_NONE}"
    source ~/.bashrc
    
    if [[ $(which zypper) ]] ; then
        echo "zypper detected"
        $WITH_SUDO zypper -n install python3 python3-pip python3-devel
    elif [[ $(which yum) ]] ; then
        echo "yum detected"
        $WITH_SUDO yum install -y python3 python3-pip python3-devel python3-wheel
    elif [[ $(which apt-get) ]] ; then	
        $WITH_SUDO apt install -y python3 python3-pip python3-dev
    elif [[ "${OS}" == "MacOS" ]] ; then
        echo -e "${C_YELLOW}Please install python3 python3-pip python3-dev${C_NONE}" 
    else
	    file_pytar="Python-3.6.0.tar.xz"
	    wget https://www.python.org/ftp/python/3.6.0/$file_pytar
	    tar xJf $file_pytar
	    cd Python-3.6.0
	    ./configure --with-ssl
	    make -j
	    $WITH_SUDO make install
	    # Install for Python3
	    cd - 
	    rm -r Python-3.6.0*
    fi
    [[ $? != 0 ]] && echo -e "${C_RED_BK}Failed... :(${C_NONE}" && exit 1
    echo "Install via pip"
    PIP_PACKAGES="numpy pandas matplotlib scipy networkx cxxfilt fuzzywuzzy sqlalchemy sklearn python-Levenshtein grpcio grpcio-tools matplotlib"
    $WITH_SUDO python3 -m pip install --upgrade pip
    $WITH_SUDO python3 -m pip install --no-cache-dir ${PIP_PACKAGES}
    [[ $? != 0 ]] && echo -e "${C_RED_BK}Failed... :(${C_NONE}" && exit 1
    
    echo "Install python3 packages without sudo"
    python3 -m pip install --upgrade pip
    python3 -m pip install --no-cache-dir ${PIP_PACKAGES}
    [[ $? != 0 ]] && echo -e "${C_YELLOW}[warninig] Failed to install required package for conda python3! Skip it if you don't need conda.${C_NONE}" 
 
    if [[ $(which conda) ]] ; then 
    	echo "Install via conda python"
    	CONDA_PY3=$(dirname $(which conda))/python3
    	$WITH_SUDO ${CONDA_PY3} -m pip install --upgrade pip
    	$WITH_SUDO ${CONDA_PY3} -m pip install --no-cache-dir ${PIP_PACKAGES}
    	[[ $? != 0 ]] && echo -e "${C_YELLOW}[warninig] Failed to install required package for conda python3! Skip it if you don't need conda.${C_NONE}" 
    fi
}

function install_packages()
{
    echo -e "${C_GREEN}Installing other packages...${C_NONE}"

    #inform_$WITH_SUDO "Running $WITH_SUDO for installing packages"
    if [[ $(which zypper) ]] ; then
        $WITH_SUDO zypper -n update
        $WITH_SUDO zypper -n install perf curl wget make gcc gcc-c++ cmake \
                   blktrace tcpdump sysstat strace time
        [[ $? != 0 ]] && echo -e "${C_RED_BK}Failed... :(${C_NONE}" && exit 1
    elif [[ $(which apt-get) ]] ; then
        $WITH_SUDO apt-add-repository -y ppa:trevorjay/pyflame 
        $WITH_SUDO apt update 
        $WITH_SUDO apt update --fix-missing
	    $WITH_SUDO apt install -y software-properties-common
        $WITH_SUDO apt install -y pyflame
	    $WITH_SUDO apt install -y curl wget build-essential cmake tcpdump sysstat strace time libcap2-bin
 	    [[ $? != 0 ]] && echo -e "${C_RED_BK}Failed... :(${C_NONE}" && exit 1
        $WITH_SUDO apt install -y linux-tools-common \
                                    linux-tools-$(uname -r) linux-cloud-tools-$(uname -r) \
	                                linux-tools-generic linux-cloud-tools-generic 
    elif [[ $(which yum) ]]  ; then
        $WITH_SUDO yum install -y epel-release 
        $WITH_SUDO yum install -y curl wget make gcc gcc-c++ cmake \
                                  tcpdump sysstat strace time 
        [[ $? != 0 ]] && echo -e "${C_RED_BK}Failed... :(${C_NONE}" && exit 1
        $WITH_SUDO yum install -y perf 
    elif [[ "${OS}" == "MacOS" ]]  ; then
        echo -e "${C_YELLOW} please use brew to install curl wget make gcc gcc-c++ cmake tcpdump sysstat strace time ${C_NONE}" 
        [[ $? != 0 ]] && echo -e "${C_RED_BK}Failed... :(${C_NONE}" && exit 1
    else
        echo -e "${C_RED_BK}This script does not support your OS distribution, '$OS'. Please install the required packages by yourself. :(${C_NONE}"
    fi
}

# main
echo -e "${C_GREEN}OS Distribution:${C_NONE} '$OS'"
echo -e "${C_GREEN}Version:${C_NONE} '$VERSION'"
printf "\n\n"

FILEPATH="$( cd "$(dirname "$0")" ; pwd -P )"
install_packages
install_python_packages

echo -e "${C_GREEN}Complete!!${C_NONE}"
