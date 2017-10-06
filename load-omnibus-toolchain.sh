#!/bin/sh

detected_os()
{
    platform="unknown"
    unamestr=`uname`
    if [ "$unamestr" = "AIX" ]; then
	platform="aix"
    elif [ "$unamestr" = "Darwin" ]; then
	platform="mac"
    elif [ "$unamestr" = "FreeBSD" ]; then
	platform="freebsd"
    elif [ "$unamestr" = "Linux" ]; then
	platform="linux"
    elif [ "$unamestr" = "SunOS" ]; then
	platform="solaris"
    fi
    echo $platform
}

os=`detected_os`

###################################################################
# Load the base Omnibus environment
###################################################################

if [ "$os" = "aix" ]; then
    PATH="/opt/IBM/xlC/13.1.0/bin:/opt/IBM/xlC/13.1.0/bin:$PATH"
    export PATH
#elif [ "$os" = "solaris" && version = 10 ]; then
#     export PATH="/usr/sfw/bin:/usr/ccs/bin:$PATH"
fi

PATH="/opt/omnibus-toolchain/bin:/usr/local/bin:$PATH"
export PATH

echo ""
echo "========================================"
echo "= Environment"
echo "========================================"
echo ""

env -0 | sort -z | tr '\\0' '\\n'

###################################################################
# Query tool versions
###################################################################

echo ""
echo ""
echo "========================================"
echo "= Tool Versions"
echo "========================================"
echo ""

echo "Bash.........$(bash --version | head -1)"
echo "Bundler......$(bundle --version | head -1)"

if [ "$os" = "aix" ]; then
    echo "XLC..........$(xlc -qversion | head -1)"
#elif [ $os = "freebsd" ] && platform_version <= 9
#    echo "GCC..........$(gcc49 --version | head -1)"
else
    echo "GCC..........$(gcc --version | head -1)"
fi

echo "Git..........$(git --version | head -1)"
echo "Make.........$(make --version | head -1)"
echo "Ruby.........$(ruby --version | head -1)"
echo "RubyGems.....$(gem --version | head -1)"

echo ""
echo "========================================"
