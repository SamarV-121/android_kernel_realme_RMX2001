#!/bin/bash

green="\033[01;32m"
nocol="\033[0m"

DEVICE=RMX2001
KERNEL_DIR="$PWD"
KERNEL_IMAGE="$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb"
AK3_DIR="$HOME/tools/AnyKernel"
TELEGRAM_API="https://api.telegram.org/bot$TELEGRAM_TOKEN"
TELEGRAM_CHAT="-1001473502998"

[ -e "$HOME/toolchains/clang" ] || git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-5484270 "$HOME/toolchains/clang"
[ -e "$HOME/toolchains/arm64-gcc" ] || git clone --depth=1 https://github.com/arter97/arm64-gcc "$HOME/toolchains/arm64-gcc"
[ -e "$HOME/toolchains/arm32-gcc" ] || git clone --depth=1 https://github.com/arter97/arm32-gcc "$HOME/toolchains/arm32-gcc"
[ -e "$AK3_DIR" ] || git clone --depth=1 https://github.com/osm0sis/AnyKernel3 "$AK3_DIR"

curl -s https://gist.githubusercontent.com/SamarV-121/7f502fbbc7e6f1954546e2d89dc7fbb8/raw >"$AK3_DIR/anykernel.sh"

export CLANG_TRIPLE="$HOME/toolchains/clang/bin/aarch64-linux-gnu-"
export CROSS_COMPILE="$HOME/toolchains/arm64-gcc/bin/aarch64-elf-"
export CROSS_COMPILE_ARM32="$HOME/toolchains/arm32-gcc/bin/arm-eabi-"

make "${DEVICE}_defconfig" O=out

curl -s "$TELEGRAM_API/sendMessage" -d "chat_id=$TELEGRAM_CHAT" -d "parse_mode=HTML" -d "disable_web_page_preview=true" -d "text=Compiling kernel for <a href=\"$GITHUB_REPOSITORY\">$DEVICE</a>" >/dev/null

case $1 in
clang)
  echo -e "${green}Compiling with clang 9.0.3${nocol}"
  make -j$(nproc) CC=clang O=out 2>&1 | tee build_"$DEVICE".log
  ;;
*)
  echo -e "${green}Compiling with GCC 10.2.0${nocol}"
  make -j$(nproc) O=out 2>&1 | tee build_"$DEVICE".log
  ;;
esac

if [ -e "$KERNEL_IMAGE" ]; then
  cp -f "$KERNEL_IMAGE" "$AK3_DIR"
  cd "$AK3_DIR"
  rm *.zip
  zip -r "$DEVICE-kernel-$(git rev-parse --short HEAD)-$(date -u +%Y%m%d_%H%M).zip" *
  curl -s "$TELEGRAM_API/sendDocument" -F "chat_id=$TELEGRAM_CHAT" -F "document=@$(find *.zip)"
else
  curl -s "$TELEGRAM_API/sendDocument" -F "chat_id=$TELEGRAM_CHAT" -F "document=@build_$DEVICE.log" -F "caption=Build failed"
fi
