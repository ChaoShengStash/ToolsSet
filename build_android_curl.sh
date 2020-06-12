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
	    echo -e "\033[31m||=========================================\033[0m"
    	echo -e "\033[31m||FATAL: error code $1 \033[0m"
		echo -e "\033[31m||FATAL: error message $2 \033[0m"
		echo -e "\033[31m||=========================================\033[0m"
		exit $1
	fi
}

function getOptions()
{
    while [ $# != 0 ];do
        case $1 in
            -SSL|-ssl)
                WITH_SSL="yes"
            ;;
            -C|-c)
                CLEAR_CACHE="yes"
            ;;
        esac
        shift
    done
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

function export_compiler_tools()
{
	export PATH=$1/bin:$PATH
	export CC=$1/bin/$2-gcc
	export LD=$1/bin/$2-ld
	export AR=$1/bin/$2-ar
	export SYSROOT=$1/sysroot
	export STRIP=$1/bin/$2-strip
	export CFLAGS="-DANDROID -pie -fPIE"
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

function build_ssl()
{
	prepare_working $1 "openssl.tar.gz" $2 "-zxvf"
	exit_if_error $? "get openssl failed"

	export ANDROID_NDK_HOME=$ANDROID_NDK

	cd $2	
	./Configure $3 \
		--prefix=$5 \
		-D__ANDROID_API__=$4 \
		no-shared \
		no-asm no-cast no-idea \
		no-camellia no-zlib no-sse2 \
		no-dso no-hw no-zlib-dynamic \
		no-err no-capieng

	echo "PATH=$PATH"
	exit_if_error $? "configure openssl failed"
	
	#build it
	make && make install
	exit_if_error $? "build openssl failed"
}

function build_curl()
{
	prepare_working $1 "curl.tar.gz" $2 "-zxvf"
	exit_if_error $? "get curl failed"

	cd $2

	if [ ! -d $5 ];then
		OPTIONS="--with-ssl=$5"
	fi

	./configure --host=$3 \
    	--prefix=$4 \
    	--enable-static \
    	--enable-shared \
		--without-zlib	\
		$OPTIONS
	exit_if_error $? "configure curl failed"

	make && make install
	exit_if_error $? "build curl failed"
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

getOptions $@

while [ $# != 0 ];do
	TARGET_ARCH=$1
    case $1 in
		armv7a|arm64)
			if [ "$TARGET_ARCH" == "armv7a" ];then
				NDK_ARCH="arm"
				NDK_ANDROID_API="android-9"
				SSL_COMPILER_OS="android-arm"
				NDK_TOOLCHAIN_PREFIX="arm-linux-androideabi"
			elif [ "$TARGET_ARCH" == "arm64" ];then
				NDK_ARCH="arm64"
				NDK_ANDROID_API="android-21"
				SSL_COMPILER_OS="android64-aarch64"
				NDK_TOOLCHAIN_PREFIX="aarch64-linux-android"
			fi

			SSL_ANDROID_API=23
			NDK_TOOLCHAIN="$NDK_TOOLCHAIN_PREFIX-4.9"
			OUTPUT_DIR="$BUILD_WORKSPACE/output/$TARGET_ARCH"
			TOOLCHAIN_DIR="$BUILD_WORKSPACE/toolchain/$TARGET_ARCH"
			make_standalone_toolchain $NDK_ARCH $NDK_ANDROID_API $NDK_TOOLCHAIN $TOOLCHAIN_DIR
			export_compiler_tools $TOOLCHAIN_DIR $NDK_TOOLCHAIN_PREFIX

			# about ssl 
			if [ "$WITH_SSL" == "yes" ];then
				SSL_DIR="$SOURCE_WORKSPACE/openssl"
				build_ssl "https://www.openssl.org/source/openssl-1.1.1f.tar.gz" "$SOURCE_WORKSPACE/openssl" $SSL_COMPILER_OS $SSL_ANDROID_API $OUTPUT_DIR
			fi

			# about curl
			build_curl "https://curl.haxx.se/download/curl-7.70.0.tar.gz" "$SOURCE_WORKSPACE/curl" $NDK_TOOLCHAIN_PREFIX $OUTPUT_DIR $SSL_DIR
		;;
        -h|-H|--help|-help) #help
            echo_usage $0
        ;;
    esac
    shift
done






