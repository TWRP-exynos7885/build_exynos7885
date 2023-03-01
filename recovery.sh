#!/bin/bash

TG_TOKEN=$1
TG_CHAT=$2

if [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT" ]; then
    echo "Vars are not setup properly!"
    exit 1
fi

vbmeta=$(pwd)/vbmeta/vbmeta.img
dev_list="a10 a20 a20e a30 a30s a40"
cd ~
mkdir recovery; cd recovery
git config --global color.ui true
git config --global user.name Gabriel2392
git config --global user.email gabriel824m@gmail.com
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-11
repo sync --force-sync -j$(($(nproc --all) + 1)) &>/dev/null || repo sync --force-sync -j$(($(nproc --all) + 1)) &>/dev/null
rm -rf .repo
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-11

export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
ccache -M 15G

function tg_sendFile() {
		curl -s "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
		-F parse_mode=markdown \
		-F chat_id=$TG_CHAT \
		-F document=@${1} \
		-F "caption=${2}"
}

function tg_sendText() {
	curl -s "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
		-d "parse_mode=html" \
		-d text="${1}" \
		-d chat_id=$TG_CHAT \
		-d "disable_web_page_preview=true"
}

n='
'

tg_sendText "(Automated message)${n}Starting Builds for exynos7885;${n}Today is $(date '+%Y-%m-%d %H:%M:%S').${n}${n}Changelog: https://github.com/TeamWin/android_bootable_recovery/commits/android-11"
today=$(date +%y%m%d)
version="$(cat bootable/recovery/variables.h | grep TW_MAIN_VERSION_STR | head -n1 | sed 's:.*STR::' | tr -d '"' | tr -d ' ')"
cp -f $vbmeta vbmeta.img

for dev in $dev_list; do
    rm -rf out
    git clone https://github.com/TWRP-exynos7885/android_device_samsung_${dev} device/samsung/${dev} --depth=1
    . build/envsetup.sh
    lunch twrp_${dev}-eng
    m recoveryimage
    if [ "$?" != "0" ]; then
        echo "Build for ${dev^} has failed!"
	exit 1
    fi
    img="$(pwd)/out/target/product/${dev}/recovery.img"
    img_md5=($(md5sum $img))
    new_img="twrp-${version}-${dev}-${today}.img"
    new_tar="twrp-${version}-${dev}-${today}.tar"
    cp -f $img $new_img
    cp -f $img recovery.img
    tar -cf $new_tar vbmeta.img recovery.img
    rm -f recovery.img
    tar_md5=($(md5sum $new_tar))
    tg_sendFile $new_tar "Device: Galaxy ${dev^}${n}Type: Odin Flashable tar${n}${n}MD5: ${tar_md5}"
    tg_sendFile $new_img "Device: Galaxy ${dev^}${n}Type: Flashable Image${n}${n}MD5: ${img_md5}"
done
