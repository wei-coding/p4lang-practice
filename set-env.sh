#!/bin/bash

set -xe

BMV2_COMMIT="b447ac4c0cfd83e5e72a3cc6120251c1e91128ab"  # August 10, 2019
PI_COMMIT="41358da0ff32c94fa13179b9cee0ab597c9ccbcc"    # August 10, 2019
P4C_COMMIT="69e132d0d663e3408d740aaf8ed534ecefc88810"   # August 10, 2019
PROTOBUF_COMMIT="v3.2.0"
GRPC_COMMIT="v1.3.2"

NUM_CORES=`grep -c ^processor /proc/cpuinfo`

sudo apt update

sudo apt-get install automake cmake libjudy-dev libpcap-dev libboost-dev libboost-test-dev libboost-program-options-dev libboost-system-dev libboost-filesystem-dev libboost-thread-dev libevent-dev libtool flex bison pkg-config g++ libssl-dev  -y

sudo apt-get install cmake g++ git automake libtool libgc-dev bison flex libfl-dev libgmp-dev libboost-dev libboost-iostreams-dev libboost-graph-dev llvm pkg-config python3 python3-scapy python3-ipaddr python3-ply tcpdump curl python3-pip python-dev xterm -y

mkdir ~/P4
cd ~/P4
echo "P4_HOME=$(pwd)" >> ~/.bashrc
source ~/.bashrc

wget https://bootstrap.pypa.io/pip/2.7/get-pip.py
sudo python2.7 get-pip.py

sudo pip2.7 install setuptools psutil crcmod scapy ipaddr ply grpcio google-api-python-client

# --- Mininet --- #
sudo apt install mininet

# --- Protobuf --- #
git clone https://github.com/google/protobuf.git
cd protobuf
git checkout ${PROTOBUF_COMMIT}
export CFLAGS="-Os"
export CXXFLAGS="-Os"
export LDFLAGS="-Wl,-s"
./autogen.sh
./configure --prefix=/usr
make -j${NUM_CORES}
sudo make install
sudo ldconfig
unset CFLAGS CXXFLAGS LDFLAGS
# Force install python module
cd python
sudo python2.7 setup.py build
sudo python2.7 setup.py install
cd ../..
sudo cp -r /usr/local/lib/python2.7/dist-packages/protobuf-3.17.3-py2.7.egg/google /usr/local/lib/python2.7/dist-packages/google/protobuf

# --- gRPC --- #
git clone https://github.com/grpc/grpc.git
cd grpc
git checkout ${GRPC_COMMIT}
git submodule update --init --recursive
export LDFLAGS="-Wl,-s"
make -j${NUM_CORES}
cmake -DgRPC_INSTALL=ON -- -j${NUM_CORES}
sudo make install
sudo ldconfig
unset LDFLAGS
cd ..
# Install gRPC Python Package
sudo pip install grpcio

# --- BMv2 deps (needed by PI) --- #
git clone https://github.com/p4lang/behavioral-model.git
cd behavioral-model
git checkout ${BMV2_COMMIT}
# From bmv2's install_deps.sh, we can skip apt-get install.
# Nanomsg is required by p4runtime, p4runtime is needed by BMv2...
tmpdir=`mktemp -d -p .`
cd ${tmpdir}
bash ../travis/install-thrift.sh
bash ../travis/install-nanomsg.sh
sudo ldconfig
bash ../travis/install-nnpy.sh
cd ..
sudo rm -rf $tmpdir
cd ..

# --- PI/P4Runtime --- #
git clone https://github.com/p4lang/PI.git
cd PI
git checkout ${PI_COMMIT}
git submodule update --init --recursive
./autogen.sh
./configure --with-proto
make -j${NUM_CORES}
sudo make install
sudo ldconfig
cd ..

# --- Bmv2 --- #
cd behavioral-model
./autogen.sh
./configure --enable-debugger --with-pi
make -j${NUM_CORES}
sudo make install
sudo ldconfig
# Simple_switch_grpc target
cd targets/simple_switch_grpc
./autogen.sh
./configure --with-thrift
make -j${NUM_CORES}
sudo make install
sudo ldconfig
cd ../../..

# --- P4C --- #
git clone https://github.com/p4lang/p4c
cd p4c
git checkout ${P4C_COMMIT}
git submodule update --init --recursive
mkdir -p build
cd build
cmake ..
# The command 'make -j${NUM_CORES}' works fine for the others, but
# with 2 GB of RAM for the VM, there are parts of the p4c build where
# running 2 simultaneous C++ compiler runs requires more than that
# much memory.  Things work better by running at most one C++ compilation
# process at a time.
make -j1
sudo make install
sudo ldconfig

# --- Tutorials --- #
cd ~/P4
git clone https://github.com/p4lang/tutorials
echo "*************************"
echo 'Install finished! Tutorial documents placed at ~/P4/tutorials'
echo '*************************'
