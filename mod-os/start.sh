#!/bin/bash

set -e

cd $(dirname ${0})

SOUNDCARD=${1}
SAMPLERATE=${2}
BUFFERSIZE=${3}

# verify CLI arguments
if [ -z "${SOUNDCARD}" ]; then
    echo "usage: ${0} <soundcard> [samplerate] [buffersize]"
    exit 1
fi

# allow soundcard id instead of index
if [ -e /proc/asound/${SOUNDCARD} ]; then
    SOUNDCARD=$(readlink /proc/asound/${SOUNDCARD} | awk 'sub("card","")')
fi

# verify soundcard is valid
if [ ! -e /proc/asound/card${SOUNDCARD} ]; then
    echo "error: can't find soundcard ${SOUNDCARD}"
    exit 1
fi

# fallback soundcard values
if [ -z "${SAMPLERATE}" ]; then
    SAMPLERATE=48000
fi
if [ -z "${BUFFERSIZE}" ]; then
    BUFFERSIZE=128
fi

if [ -e /proc/asound/card${SOUNDCARD}/usbid ]; then
    NPERIODS=3
else
    NPERIODS=2
fi

# pass soundcard setup into container
echo "# mod-live-usb soundcard setup
SOUNDCARD=${SOUNDCARD}
SAMPLERATE=${SAMPLERATE}
BUFFERSIZE=${BUFFERSIZE}
NPERIODS=${NPERIODS}
CAPTUREARGS=
PLAYBACKARGS=
EXTRAARGS=
" > $(pwd)/config/soundcard.sh

# no security, yay?
export SYSTEMD_SECCOMP=0

# optional nspawn options (everything must be valid)
NSPAWN_OPTS=""
if [ -e /dev/snd/pcmC${SOUNDCARD}D0c ]; then
NSPAWN_OPTS+=" --bind=/dev/snd/pcmC${SOUNDCARD}D0c"
fi
if [ -e /dev/snd/pcmC${SOUNDCARD}D0p ]; then
NSPAWN_OPTS+=" --bind=/dev/snd/pcmC${SOUNDCARD}D0p"
fi
if [ -e /mnt/pedalboards ]; then
NSPAWN_OPTS+=" --bind-ro=/mnt/pedalboards"
fi
if [ -e /mnt/plugins ]; then
NSPAWN_OPTS+=" --bind-ro=/mnt/plugins"
fi

# ready!
sudo systemd-nspawn \
--boot \
--capability=all \
--private-users=false \
--resolv-conf=bind-host \
--machine="mod-live-usb" \
--image=$(pwd)/rootfs.ext2 \
--bind=/dev/snd/controlC${SOUNDCARD} \
--bind=/dev/snd/seq \
--bind=/dev/snd/timer \
--bind-ro=/etc/hostname \
--bind-ro=/etc/hosts \
--bind-ro=$(pwd)/config:/mnt/config \
--bind-ro=$(pwd)/overlay-files/etc/group:/etc/group \
--bind-ro=$(pwd)/overlay-files/etc/passwd:/etc/passwd \
--bind-ro=$(pwd)/overlay-files/etc/shadow:/etc/shadow \
--bind-ro=$(pwd)/overlay-files/system:/etc/systemd/system \
--tmpfs=/run \
--tmpfs=/tmp \
--tmpfs=/var ${NSPAWN_OPTS}
