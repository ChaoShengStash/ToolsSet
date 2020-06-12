#!/bin/bash

function echo_usage() 
{
    echo -e "\033[31mERROR:Plaese use the following format!!!!!! \033[0m"
    echo "Usage:"
    echo "========================================"
    echo "$1"
    echo "========================================"
    exit 1
}

function exit_if_error()
{
	if [ $1 -ne 0 ];then
	    echo -e "\033[31m=========================================\033[0m"
    	echo -e "\033[31m ERROR: code $1, message $2 \033[0m"
		echo -e "\033[31m=========================================\033[0m"
		exit $1
	fi
}

function make_standalone_toolchain()
{
	if [ $# -ne 4 ];then
		exit_if_error 1 "$0 <arch> <platform>  <toolchain_prefix> <install-dir>"
	fi

	if [ ! -d $4 ];then
    	$ANDROID_NDK/build/tools/make-standalone-toolchain.sh \
		    --force	\
			--arch="$1" \
			--platform="$2" \
			--toolchain="$3" \
			--install-dir="$4"
				
		exit_if_error $? "make_standalone_toolchain faild"
	fi
}

function print_all_arguments()
{
    echo -e "\033[31m=========================================\033[0m"
    echo "website_url       =$1"
    echo "zip_new_name      =$2"
    echo "source_dir        =$3"
    echo "tar_command       =$4"
    echo -e "\033[31m=========================================\033[0m"
}

function prepare_working()
{
	DIR=$3
    if [ $# -lt 4 ];then    #check input parameter num
		exit_if_error 1 "$0 parameters are wrong"
    fi

    print_all_arguments $@  #print all input parameters

    if [ ! -d $3 ];then  #create directory if not existed
        mkdir -p $3
    fi

	workspace=${DIR%/*}
    cd $workspace    #enter workspace

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

function build_libiconv()
{
	prepare_working $1 "libiconv.tar.gz" $2 "-zxvf"
	exit_if_error $? "get libiconv failed"

	if [ "$3" == "arm-linux-androideabi" ];then
		export CFLAGS="-DANDROID -mandroid -fomit-frame-pointer -mfloat-abi=softfp -mfpu=vfp -mthumb"
	elif [ "$3" == "aarch64-linux-android" ];then
		export CFLAGS="-DANDROID"
	fi

	cd $2
	./configure --prefix=$4 \
				--host=$3 \
				--enable-static
	exit_if_error $? "configure libiconv failed"

	make && make install
	exit_if_error $? "build libiconv failed"

	export LDFLAGS="-L$4/lib -liconv -lcharset $LDFLAGS"
	export CPPFLAGS="-I$4/include $CPPFLAGS"
}

function build_libxml2()
{
	prepare_working $1 "libxml2.tar.gz" $2 "-zxvf"
	exit_if_error $? "get libxml2 failed"

	if [ "$3" == "arm-linux-androideabi" ];then
		export CFLAGS="-DANDROID -mandroid -fomit-frame-pointer -mfloat-abi=softfp -mfpu=vfp -mthumb"
	elif [ "$3" == "aarch64-linux-android" ];then
		export CFLAGS="-DANDROID"
	fi

	cd $2
    ./configure --prefix=$4 \
				--host=$3 \
				--target=$3 \
				--enable-static \
				--disable-shared \
				--without-lzma \
				--without-python
	exit_if_error $? "configure libxml2 failed"

	make && make install
	exit_if_error $? "build libxml2 failed"

	LDFLAGS=""
	CPPFLAGS=""
}

function export_compiler_tools()
{
	echo "toolchain_dir: $1"
	echo "ndk_toolchain_prefix:$2"
	export PATH=$1/bin:$PATH
	export CC=$1/bin/$2-gcc
	export LD=$1/bin/$2-ld
	export AR=$1/bin/$2-ar
	export SYSROOT=$1/sysroot
	export STRIP=$1/bin/$2-strip
}

################################################ start run #######################################
SOURCE_WORKSPACE=`pwd`/workspace
BUILD_WORKSPACE=$SOURCE_WORKSPACE/build

if [ -z $ANDROID_NDK ];then
	echo -e "\033[31mERROR:NO NDK PATH \033[0m"
    echo "========================================"
    echo "export ANDROID_NDK=<ndk_dir>"
    echo "========================================"
	exit 1
fi

if [ $# -le 0 ];then
    exit_if_error 1 "$0 <[armv5] [armv7a] [arm64] [x86] [x86_64]>"
fi

while [ $# != 0 ];do
	TARGET_ARCH=$1
    case $1 in
		armv7a|arm64)
			if [ "$TARGET_ARCH" == "armv7a" ];then
				NDK_ARCH="arm"
				NDK_ANDROID_API="android-9"
				NDK_TOOLCHAIN_PREFIX="arm-linux-androideabi"
			elif [ "$TARGET_ARCH" == "arm64" ];then
				NDK_ARCH="arm64"
				NDK_ANDROID_API="android-21"
				NDK_TOOLCHAIN_PREFIX="aarch64-linux-android"
			fi

			OUTPUT_DIR="$BUILD_WORKSPACE/output/$TARGET_ARCH"
			NDK_TOOLCHAIN="$NDK_TOOLCHAIN_PREFIX-4.9"
			TOOLCHAIN_DIR="$BUILD_WORKSPACE/toolchain/$TARGET_ARCH"
			make_standalone_toolchain $NDK_ARCH $NDK_ANDROID_API $NDK_TOOLCHAIN $TOOLCHAIN_DIR

			export_compiler_tools $TOOLCHAIN_DIR $NDK_TOOLCHAIN_PREFIX
			build_libiconv "http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.16.tar.gz" 	"$SOURCE_WORKSPACE/iconv" $NDK_TOOLCHAIN_PREFIX  $OUTPUT_DIR
			build_libxml2 "http://xmlsoft.org/sources/libxml2-2.9.9.tar.gz" 			"$SOURCE_WORKSPACE/xml2"  $NDK_TOOLCHAIN_PREFIX  $OUTPUT_DIR
		;;
        -h|-H|--help|-help) #help
            echo_usage "$0 [-c|-C] <[armv5] [armv7a] [arm64] [x86] [x86_64]>" 
        ;;
    esac
    shift
done






