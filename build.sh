#!/bin/bash

green="\033[01;32m"
nocol="\033[0m"

DEVICE=RMX2001
KERNEL_DIR="$PWD"
KERNEL_IMAGE="$KERNEL_DIR/out/arch/arm64/boot/Image.gz"
DTB="$KERNEL_DIR/out/arch/arm64/boot/mtk.dtb"
AK3_DIR="$HOME/tools/AnyKernel/$DEVICE"
TELEGRAM_API="https://api.telegram.org/bot$TELEGRAM_TOKEN"
TELEGRAM_CHAT="-1001473502998"

[ -e "$HOME/toolchains/clang" ] || git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-5484270 "$HOME/toolchains/clang"
[ -e "$HOME/toolchains/arm64-gcc-4.9" ] || git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 "$HOME/toolchains/arm64-gcc-4.9"
[ -e "$HOME/toolchains/arm32-gcc-4.9" ] || git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 "$HOME/toolchains/arm32-gcc-4.9"
[ -e "$AK3_DIR" ] || git clone --depth=1 https://github.com/SamarV-121/AnyKernel3 -b "$DEVICE" "$AK3_DIR"

export PATH="$HOME/toolchains/clang/bin:$PATH"
export PATH="$HOME/toolchains/arm64-gcc-4.9/bin:$PATH"
export PATH="$HOME/toolchains/arm32-gcc-4.9/bin:$PATH"

make "${DEVICE}_defconfig" O=out

function TGsendMsg {
	MESSAGE_ID=$(curl -s "$TELEGRAM_API/sendMessage" -d "chat_id=$TELEGRAM_CHAT" -d "parse_mode=HTML" -d "disable_web_page_preview=true" -d "text=$*" | jq -r '.result.message_id')
}

rm -f "$KERNEL_IMAGE"

TGsendMsg "Compiling kernel for <a href=\"$(git remote get-url origin)\">$DEVICE</a>"
ZIPNAME="FuseKernel-test-$(git rev-parse --short HEAD)-$(date -u +%Y%m%d_%H%M)-$DEVICE.zip"
make -j $(nproc) O=out CC=clang \
	CLANG_TRIPLE=aarch64-linux-gnu- \
	CROSS_COMPILE=aarch64-linux-android- \
	CROSS_COMPILE_ARM32=arm-linux-androideabi- 2>&1 | tee build_"$DEVICE".log

if [ -e "$KERNEL_IMAGE" ]; then
	cp -f "$KERNEL_IMAGE" "$AK3_DIR"
	cp -f "$DTB" "$AK3_DIR/dtb"
	cd "$AK3_DIR"
	zip -r "$ZIPNAME" * -x "*.zip"
	echo -e "${green}$PWD/$ZIPNAME${nocol}"
	curl -s "$TELEGRAM_API/sendDocument" -F "reply_to_message_id=$MESSAGE_ID" -F "chat_id=$TELEGRAM_CHAT" -F "document=@$ZIPNAME"
else
	curl -s "$TELEGRAM_API/sendDocument" -F "reply_to_message_id=$MESSAGE_ID" -F "chat_id=$TELEGRAM_CHAT" -F "document=@build_$DEVICE.log" -F "caption=Build failed"
	return 69
fi

curl -s "$TELEGRAM_API/sendSticker" -d "chat_id=$TELEGRAM_CHAT" -d "sticker=CAADBQAD8gADLG6EE1T3chaNrvilFgQ"
