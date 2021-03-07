#!/bin/bash

green="\033[01;32m"
nocol="\033[0m"

DEVICE=RMX2001
KERNEL_DIR="$PWD"
KERNEL_IMAGE="$KERNEL_DIR/out/arch/arm64/boot/Image.gz"
DTB="$KERNEL_DIR/out/arch/arm64/boot/mtk.dtb"
AK3_DIR="$HOME/tools/AnyKernel"
TELEGRAM_API="https://api.telegram.org/bot$TELEGRAM_TOKEN"
TELEGRAM_CHAT="-1001473502998"

[ -e "$HOME/toolchains/clang" ] || git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-5484270 "$HOME/toolchains/clang"
[ -e "$HOME/toolchains/arm64-gcc-10" ] || git clone --depth=1 https://github.com/arter97/arm64-gcc "$HOME/toolchains/arm64-gcc-10"
[ -e "$HOME/toolchains/arm32-gcc-10" ] || git clone --depth=1 https://github.com/arter97/arm32-gcc "$HOME/toolchains/arm32-gcc-10"
[ -e "$HOME/toolchains/arm64-gcc-4.9" ] || git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 "$HOME/toolchains/arm64-gcc-4.9"
[ -e "$HOME/toolchains/arm32-gcc-4.9" ] || git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 "$HOME/toolchains/arm32-gcc-4.9"
[ -e "$AK3_DIR" ] || git clone --depth=1 https://github.com/osm0sis/AnyKernel3 "$AK3_DIR"

curl -s https://gist.githubusercontent.com/SamarV-121/7f502fbbc7e6f1954546e2d89dc7fbb8/raw >"$AK3_DIR/anykernel.sh"

export PATH="$HOME/toolchains/clang/bin:$PATH"
export PATH="$HOME/toolchains/arm64-gcc-10/bin:$PATH"
export PATH="$HOME/toolchains/arm32-gcc-10/bin:$PATH"
export PATH="$HOME/toolchains/arm64-gcc-4.9/bin:$PATH"
export PATH="$HOME/toolchains/arm32-gcc-4.9/bin:$PATH"

make "${DEVICE}_defconfig" O=out

function TGsendMsg {
	MESSAGE_ID=$(curl -s "$TELEGRAM_API/sendMessage" -d "chat_id=$TELEGRAM_CHAT" -d "parse_mode=HTML" -d "disable_web_page_preview=true" -d "text=$*" | jq -r '.result.message_id')
}

case "$1" in
clang)
	echo -e "${green}Compiling with Clang-9.0.3${nocol}"
	TGsendMsg "Compiling kernel for <a href=\"$(git remote get-url origin)\">$DEVICE</a> with clang-9.0.3"
	ZIPNAME="$DEVICE-kernel-clang-9.0.3-$(git rev-parse --short HEAD)-$(date -u +%Y%m%d_%H%M).zip"
	make -j$(nproc) O=out CC=clang \
		CLANG_TRIPLE=aarch64-linux-gnu- \
		CROSS_COMPILE=aarch64-linux-android- \
		CROSS_COMPILE_ARM32=arm-linux-androideabi- 2>&1 | tee build_"$DEVICE".log
	;;
*)
	echo -e "${green}Compiling with GCC-10.2.0${nocol}"
	TGsendMsg "Compiling kernel for <a href=\"$(git remote get-url origin)\">$DEVICE</a> with gcc-10.2.0"
	ZIPNAME="$DEVICE-kernel-gcc-10-$(git rev-parse --short HEAD)-$(date -u +%Y%m%d_%H%M).zip"
	make -j$(nproc) O=out \
		CROSS_COMPILE=aarch64-elf- \
		CROSS_COMPILE_ARM32=arm-eabi- 2>&1 | tee build_"$DEVICE".log
	;;
esac

if [ -e "$KERNEL_IMAGE" ]; then
	cp -f "$KERNEL_IMAGE" "$AK3_DIR"
	cp -f "$DTB" "$AK3_DIR/dtb"
	cd "$AK3_DIR"
	rm *.zip
	zip -r "$ZIPNAME" *
	curl -s "$TELEGRAM_API/sendDocument" -F "reply_to_message_id=$MESSAGE_ID" -F "chat_id=$TELEGRAM_CHAT" -F "document=@$ZIPNAME"
else
	curl -s "$TELEGRAM_API/sendDocument" -F "reply_to_message_id=$MESSAGE_ID" -F "chat_id=$TELEGRAM_CHAT" -F "document=@build_$DEVICE.log" -F "caption=Build failed"
	exit 1
fi
