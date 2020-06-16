#!/bin/bash

function print_all_arguments()
{
    echo -e "\033[31m=========================================\033[0m"
    echo "website_url       =$1"
    echo "zip_new_name      =$2"
    echo "source_dir        =$3"
    echo "tar_command       =$4"
    echo -e "\033[31m=========================================\033[0m"
}

function echo_usage() 
{
    echo -e "\033[31mERROR:Plaese use the following format!!!!!! \033[0m"
    echo "Usage:"
    echo "========================================"
    echo "$1 <website_url> <zip_file_name> <source_dir>"
    echo "========================================"
    exit 1
}

function get_dist_name()
{
    if grep -Eqii "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        PM='yum'
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        DISTRO='RHEL'
        PM='yum'
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun" /etc/*-release; then
        DISTRO='Aliyun'
        PM='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        DISTRO='Fedora'
        PM='yum'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
        PM='apt-get'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        PM='apt-get'
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        DISTRO='Raspbian'
        PM='apt-get'
    else
        DISTRO='unknown'
    fi
    echo $DISTRO $PM;
}

function prepare_working()
{
    if [ $# -lt 4 ];then    #check input parameter num
        echo_usage $0
        exit 1;
    fi

    print_all_arguments $@  #print all input parameters

    if [ ! -d $SOURCE_WORKSPACE ];then  #create directory if not existed
        mkdir -p $SOURCE_WORKSPACE
    fi

    cd $SOURCE_WORKSPACE    #enter workspace

    if [ ! -f $2 ];then # wget file if not existed 
        wget $1 -O $2
    fi

    tar -tvf $2  #check it completable
    if [ $? -ne 0 ];then    # retry get it if error occured
        echo "--------------re-download $2 ----------------"
        rm -f $2 && wget $1 -O $2
    fi

    if [ ! -d $3 ];then #create directory to store unzip file
        mkdir -p $3
    else
        rm -rf $3/*
    fi

    tar $4 $2 -C $3 --strip-components 1    #uzip zip file to given directory, $4:tar command options
}

# yasm
function build_yasm()
{
    prepare_working $@ "-zxvf"

    cd $3
    ./configure --prefix="$BUILD_WORKSPACE/out" --bindir="$BUILD_WORKSPACE/bin" && make -j4 install

    if [ $? -ne 0 ];then
        echo "install yasm failed"
        exit $?
    fi
}

#nasm
function build_nasm()
{
    prepare_working $@ "-xjvf"

    cd $3
    ./autogen.sh
    ./configure --prefix="$BUILD_WORKSPACE/out" --bindir="$BUILD_WORKSPACE/bin" && make -j4 install

    if [ $? -ne 0 ];then
        echo "install nasm failed"
        exit $?
    fi
}

#x264
function build_x264()
{
    prepare_working $@ "-xjf"

    cd $3
    PKG_CONFIG_PATH="$BUILD_WORKSPACE/out/lib/pkgconfig" \
    ./configure --prefix="$BUILD_WORKSPACE/out" --bindir="$BUILD_WORKSPACE/bin" --enable-static --disable-asm --disable-opencl && make -j4 install

    if [ $? -ne 0 ];then
        echo "install x264 failed"
        exit $?
    fi
}

#x265
function build_x265()
{
    prepare_working $@ "-zxvf"

    cd $3/build/linux/
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$BUILD_WORKSPACE/out" -DEXECUTABLE_OUTPUT_PATH="$BUILD_WORKSPACE/bin" -DENABLE_SHARED:bool=off ../../source
    make -j4 install

    if [ $? -ne 0 ];then
        echo "install x265 failed"
        exit $?
    fi

}

#libvpx
function build_vpx()
{
    prepare_working $@ "-zxvf"

    cd $3
    sed -i 's/cp -p/cp/' build/make/Makefile
    ./configure --prefix="$BUILD_WORKSPACE/out" --disable-examples --disable-shared --disable-unit-tests --enable-vp9-highbitdepth --as=yasm && make -j4 install

    if [ $? -ne 0 ];then
        echo "install libvpx failed"
        exit $?
    fi
}

#xml2
function build_xml2()
{
    prepare_working $@ "-zxvf"

    cd $3
    ./configure --prefix="$BUILD_WORKSPACE/out" --bindir="$BUILD_WORKSPACE/bin" --enable-static --disable-shared && make -j4 install

    if [ $? -ne 0 ];then
        echo "install xml2 failed"
        exit $?
    fi
}

#fdk-aac
function build_fdkaac()
{
    prepare_working $@ "-zxvf"

    cd $3
    autoreconf -fiv && ./configure --prefix="$BUILD_WORKSPACE/out" --disable-shared && make -j4 install

    if [ $? -ne 0 ];then
        echo "install fdk-aac failed"
        exit $?
    fi
}

#opus
function build_opus()
{
    prepare_working $@ "-zxvf"

    cd $3
    ./configure --prefix="$BUILD_WORKSPACE/out" --disable-shared && make -j4 install

    if [ $? -ne 0 ];then
        echo "install opus failed"
        exit $?
    fi
}

#opus
function build_mp3lame()
{
    prepare_working $@ "-zxvf"

    cd $3
    ./configure --prefix="$BUILD_WORKSPACE/out" --bindir="$BUILD_WORKSPACE/bin" --disable-shared --enable-nasm && make -j4 install

    if [ $? -ne 0 ];then
        echo "install mp3lame failed"
        exit $?
    fi
}

#openssl
function build_openssl()
{
    prepare_working $@ "-zxvf"

    cd $3
    ./config no-shared --prefix="$BUILD_WORKSPACE/out" && make && make install

    if [ $? -ne 0 ];then
        echo "install openssl failed"
        exit $?
    fi
}

#ffmpeg
function build_ffmpeg()
{
    prepare_working $@ "-xjf"

    INCLUDE_DIR="$BUILD_WORKSPACE/out/include"
    LIB_OPTS="-L$BUILD_WORKSPACE/out/lib -lopus -lmp3lame -lfdk-aac -lxml2 -lvpx -lx265 -lx264 -lssl -lcrypto"
    INC_OPTS="-I$INCLUDE_DIR -I$INCLUDE_DIR/libxml2 -I$INCLUDE_DIR/opus -I$INCLUDE_DIR/lame -I$INCLUDE_DIR/vpx -I$INCLUDE_DIR/fdk-aac -I$INCLUDE_DIR/openssl"
    ENABLE_OPTS="--enable-libopus --enable-libmp3lame --enable-libfdk-aac --enable-libxml2 --enable-libvpx --enable-libx265 --enable-libx264 --enable-protocol=crypto --enable-openssl"

    cd $3
    ./configure \
    --prefix="$BUILD_WORKSPACE/out" \
    --pkg-config-flags="--static" \
    --extra-cflags="${INC_OPTS}" \
    --extra-ldflags="${LIB_OPTS}" \
    --bindir="$BUILD_WORKSPACE/bin" \
    --extra-libs=-lpthread \
    --extra-libs=-lm \
    --enable-gpl \
    --enable-nonfree \
    --enable-version3 \
    --enable-static \
    --disable-debug \
    --disable-ffplay \
    --enable-cross-compile  \
    --enable-yasm \
    ${ENABLE_OPTS} && make -j4 install

    if [ $? -ne 0 ];then
        echo "install ffmpeg failed"
        exit $?
    fi
}

function build_all()
{
    # build_yasm      "https://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz"                                      "yasm.tar.gz"       "yasm"
    # build_nasm      "https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2"                               "nasm.tar.bz2"      "nasm"
    # build_x264      "http://download.videolan.org/pub/videolan/x264/snapshots/x264-snapshot-20191217-2245-stable.tar.bz2"   "x264.tar.bz2"      "x264"
    # build_x265      "http://ftp.videolan.org/pub/videolan/x265/x265_3.1.1.tar.gz"                                           "x265.tar.gz"       "x265"
    # build_vpx       "https://github.com/webmproject/libvpx/archive/v1.8.1/libvpx-1.8.1.tar.gz"                              "libvpx.tar.gz"     "vpx"
    # build_xml2      "http://xmlsoft.org/sources/libxml2-2.9.9.tar.gz"                                                       "libxml2.tar.gz"    "xml2"
    # build_fdkaac    "https://nchc.dl.sourceforge.net/project/opencore-amr/fdk-aac/fdk-aac-2.0.0.tar.gz"                     "fdk-aac.tar.gz"    "fdk-aac"
    # build_mp3lame   "https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz"                           "mp3lame.tar.gz"    "mp3lame"
    # build_opus      "https://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.1.tar.gz"                                         "opus.tar.gz"       "opus"
    # build_openssl   "https://www.openssl.org/source/openssl-1.1.1c.tar.gz"                                                  "openssl.tar.gz"    "openssl"
    build_ffmpeg    "https://ffmpeg.org/releases/ffmpeg-4.2.1.tar.bz2"                                                      "ffmpeg.tar.bz2"    "ffmpeg"   #call this function finally
}

######################################## start running #############################################
# prepare tools
get_dist_name   #call function
SOURCE_WORKSPACE=`pwd`/sources
BUILD_WORKSPACE=`pwd`/build

# mkdir -p $SOURCE_WORKSPACE   #create directory
# mkdir -p $BUILD_WORKSPACE   #create directory

${PM} update -y
${PM} install -y autoconf \
                automake \
                bzip2 bzip2-devel \
                cmake \
                freetype-devel \
                gcc gcc-c++ \
                git \
                libtool \
                make \
                mercurial \
                pkgconfig \
                zlib-devel \
                python-devel \
                python3-devel

# export private tools
export PATH="${BUILD_WORKSPACE}/bin:${PATH}"
export PKG_CONFIG_PATH="${BUILD_WORKSPACE}/out/lib/pkgconfig"

build_all    #call function
