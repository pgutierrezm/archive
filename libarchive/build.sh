#!/bin/bash

############################################
##										  ##
##	        Configuration values          ##
##										  ##
############################################

# These are the architectures to build for iOS and iOS Simulator
iosArchs=(armv7 armv7s arm64)
iosSimulatorArchs=(i386 x86_64)
min_iOSversion=7.0
clang=`which clang`

############################################
##										  ##
##                 Script                 ##
##										  ##
############################################

tagOrCommit=`git --git-dir=./module/.git describe --always`
echo "Building libarchive ($tagOrCommit)"

# Delete the old output
rm ./output/*.a
rm ./output/*.h

# Create the configuration and make files
# Note: while we don't know if it makes a difference for a static library we disable the use of libraries that are private (lzma) or don't exist in iOS (nettle, expat, etc.)
cd ./module
./build/clean.sh 
./build/autogen.sh
./configure CC=$clang --without-lz4 --without-lzma --without-lzo2  --without-nettle --without-expat

# We have not found a way to do cross-compilation. We tried with issuing these commands
#      clang=`xcrun -sdk iphoneos --find clang`
#      osxHost=`.module/build/autoconf/config.guess`
#      .module/configure CC=$clang --host=$osxHost
# This configuration process works, and it seems to generate a config.h file that is tailored for iOS, but then the make process fails
#
# Without a process to cross-compile we adjust the config.h file manually
sed -i bak 's/HAVE_LOCALE_CHARSET/HAVE_LOCALE_CHARSET_DISABLED/' config.h
sed -i bak 's/HAVE_LOCALCHARSET_H/HAVE_LOCALCHARSET_H_DISABLED/' config.h

# For compilation we use the latest iOS SDK
sysroot=`xcrun -sdk iphoneos --show-sdk-path`

for arch in "${iosArchs[@]}"
do
	echo "Building for iOS $arch"
	
	# -g0 to avoid debug symbols, -Wno-sign-compare to avoid an error (-Wall is set by default)
	make CFLAGS="-g0 -arch $arch -isysroot $sysroot -miphoneos-version-min=$min_iOSversion -Wno-sign-compare"
	if [ -e .libs/libarchive.a ]
	then
		cp .libs/libarchive.a ./../output/libarchive_ios_$arch.a
	else
		echo "ERROR: could not create ./module/.libs/libarchive.a for $arch"
		exit 1
	fi
	
	make clean
done

sysroot=`xcrun -sdk iphonesimulator --show-sdk-path`
for arch in "${iosSimulatorArchs[@]}"
do
	echo "Building for iOS Simulato) $arch"
	
	# -g0 to avoid debug symbols, -Wno-sign-compare to avoid an error (-Wall is set by default)
	make CFLAGS="-g0 -arch $arch -isysroot $sysroot -miphoneos-version-min=$min_iOSversion -Wno-sign-compare"
	if [ -e .libs/libarchive.a ]
	then
		cp .libs/libarchive.a ./../output/libarchive_simulator_$arch.a
	else
		echo "ERROR: could not create ./module/.libs/libarchive.a for $arch"
		exit 1
	fi
	
	make clean
done

# create the fat binaries and copy the headers
version=`awk '/LIBARCHIVE_VERSION_STRING/{gsub("\"","");print $3}' config.h`
cd ./../
lipo -create ./output/libarchive_ios_*.a -o ./output/libarchive.$version.a
lipo -create ./output/libarchive_simulator_*.a -o ./output/libarchive_simulator.$version.a
rm ./output/libarchive_ios_*.a
rm ./output/libarchive_simulator_*.a

cp ./module/libarchive/archive.h ./output/
cp ./module/libarchive/archive_entry.h ./output/

# cleanup
cd ./module
./build/clean.sh
