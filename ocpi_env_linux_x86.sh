# Build from Linux for Linux
export ORB=OMNI
export PPP_LIB=
export PPP_INC=
export CPIDIR=/home/mpepe/projects/jcrew/i2wd/opencpi
export SYSTEM=linux
export ARCH=x86
export SHAREDLIBFLAGS=-m32
export BUILDSHAREDLIBRARIES=1
export DEBUG=1
export ASSERT=1
export USE_CPIP_SIMULATION=0
export HAVE_CORBA=1
export ACE_ROOT=/opt/TAO/5.6.6/linux-x86-gcc/ACE_wrappers
export HOST_ROOT=/opt/TAO/5.6.6/linux-x86-gcc/ACE_wrappers
export LD_LIBRARY_PATH=/opt/local/TAO/5.6.6/linux-x86-gcc/ACE_wrappers/lib:$LD_LIBRARY_PATH
export OUTDIR=$SYSTEM-$ARCH-bin
export OMNIDIR=/usr/local
export OMNI_IDL_DIR=/usr/local/omniORB/idl