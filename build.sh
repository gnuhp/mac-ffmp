#!/bin/sh

PLATFORMBASE=$(xcode-select -print-path)"/Platforms"
IOSSDKVERSION=6.0

set -e

SCRIPT_DIR=$( (cd -P $(dirname $0) && pwd) )
DIST_DIR_BASE=${DIST_DIR_BASE:="$SCRIPT_DIR/dist"}

if [ ! -d ffmpeg ]
then
  echo "ffmpeg source directory does not exist, run sync.sh"
fi

#ARCHS=${ARCHS:-"armv6 armv7 i386"}
ARCHS=${ARCHS:-"armv7 i386 "}

GAS=${SCRIPT_DIR}/gas-preprocessor 
DISABLED_COMPONENTS="--disable-everything"

ENABLED_COMPONENTS=" --enable-demuxer=h264 \
    --enable-demuxer=flv \
    --enable-demuxer=mpegps \
    --enable-demuxer=mpegts \
    --enable-demuxer=mpegvideo \
    --enable-demuxer=mpegtsraw \
    --enable-demuxer=pcm_s16le \
    --enable-muxer=flv \
    --enable-muxer=pcm_s16le \
    --enable-protocol=file \
    --enable-protocol=applehttp \
    --enable-protocol=http \
    --enable-protocol=rtmp \
    --enable-protocol=rtmpt \
    --enable-protocol=rtmpe \
    --enable-protocol=rtmpte \
    --enable-protocol=rtmps \
    --enable-protocol=rtp \
    --enable-protocol=tcp \
    --enable-protocol=udp \
    --enable-avformat \
    --enable-avcodec \
    --enable-decoder=imc \
    --enable-decoder=mpeg4 \
    --enable-decoder=mpeg \
    --enable-encoder=h264 \
    --enable-decoder=h264 \
    --enable-encoder=flv \
    --enable-decoder=flv \
    --enable-decoder=adpcm_swf \
    --enable-decoder=adpcm_ms \
    --enable-decoder=adpcm_ima_wav \
    --enable-decoder=adpcm_ima_qt \
    --enable-decoder=adpcm_yamaha \
    --enable-encoder=adpcm_swf \
    --enable-encoder=adpcm_ms \
    --enable-encoder=adpcm_ima_wav \
    --enable-encoder=adpcm_ima_qt \
    --enable-encoder=adpcm_yamaha \
    --enable-encoder=pcm_s16le \
    --enable-decoder=pcm_s16le \
    --enable-decoder=pcm_s16le_planar \
    --enable-parser=h264 \
    --enable-parser=mpeg4video \
    --enable-parser=mpegaudio \
    --enable-parser=mpegvideo \
    --enable-muxer=ffm --enable-demuxer=ffm --enable-muxer=rtp --enable-demuxer=rtp \
    --enable-decoder=rtp --enable-muxer=rtsp --enable-demuxer=rtsp \
    --enable-libx264 \
    --enable-encoder=libx264 "

CONFIGURE_FLAGS=" --enable-gpl --enable-asm   --disable-shared --enable-static --enable-runtime-cpudetect \
                 ${DISABLED_COMPONENTS}  ${ENABLED_COMPONENTS}"


for ARCH in $ARCHS
do
    FFMPEG_DIR=ffmpeg-$ARCH
    if [ ! -d $FFMPEG_DIR ]
    then
      echo "Directory $FFMPEG_DIR does not exist, run sync.sh"
      exit 1
    fi
    echo "Compiling source for $ARCH in directory $FFMPEG_DIR"

    cd $FFMPEG_DIR

    DIST_DIR=$DIST_DIR_BASE-$ARCH
    mkdir -p $DIST_DIR

    case $ARCH in
        armv6)
            EXTRA_FLAGS="--cpu=arm1176jzf-s"
            EXTRA_CFLAGS=""
            PLATFORM="${PLATFORMBASE}/iPhoneOS.platform"
            IOSSDK=iPhoneOS${IOSSDKVERSION}
            ;;
        armv7)
            EXTRA_FLAGS="--cpu=cortex-a8 --enable-pic"
            EXTRA_CFLAGS="-mfpu=neon"
            PLATFORM="${PLATFORMBASE}/iPhoneOS.platform"
            IOSSDK=iPhoneOS${IOSSDKVERSION}
            ;;
        i386)
            EXTRA_FLAGS="--enable-pic"
            EXTRA_CFLAGS=""
            PLATFORM="${PLATFORMBASE}/iPhoneSimulator.platform"
            IOSSDK=iPhoneSimulator${IOSSDKVERSION}
            ;;
        *)
            echo "Unsupported architecture ${ARCH}"
            exit 1
            ;;
    esac

    echo "Configuring ffmpeg for $ARCH..."

    echo "Dist dir : $DIST_DIR"

    X264_PREFIX=${SCRIPT_DIR}/../x264-ios-build/dist-${ARCH}

    ./configure \
    --prefix="$DIST_DIR" \
    --enable-cross-compile --target-os=darwin --arch=$ARCH \
    --cross-prefix="${PLATFORM}/Developer/usr/bin/" \
    --sysroot="${PLATFORM}/Developer/SDKs/${IOSSDK}.sdk" \
    --extra-ldflags="-L${PLATFORM}/Developer/SDKs/${IOSSDK}.sdk/usr/lib/system -L$X264_PREFIX/lib"\
    --disable-bzlib \
    --disable-doc \
    --disable-ffmpeg \
    --disable-ffplay \
    --disable-ffserver \
    --disable-ffprobe \
    --disable-yasm \
    --as="${GAS}\gas-preprocessor.pl ${PLATFORM}/Developer/usr/bin/as" \
    --extra-ldflags="-arch $ARCH" \
    --extra-cflags="-arch $ARCH $EXTRA_CFLAGS -I$X264_PREFIX/include" \
    --extra-cxxflags="-arch $ARCH" \
    $EXTRA_FLAGS \
    $CONFIGURE_FLAGS  || exit 1

    echo "Installing ffmpeg for $ARCH..."
    make clean
    make -j8 V=1
    make install

    cd $SCRIPT_DIR

    if [ -d $DIST_DIR/bin ]
    then
      rm -rf $DIST_DIR/bin
    fi
    if [ -d $DIST_DIR/share ]
    then
      rm -rf $DIST_DIR/share
    fi
done
