#!/usr/bin/bash
# Written by: cyberknight777
# YAKB v1.0
# Copyright (c) 2022-2023 Cyber Knight <cyberknight755@gmail.com>
#
#			GNU GENERAL PUBLIC LICENSE
#			 Version 3, 29 June 2007
#
# Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.

# Some Placeholders: [!] [*] [✓] [✗]

# Default defconfig to use for builds.
export CONFIG=vendor/xiaomi/miatoll_defconfig

# Default directory where kernel is located in.
KDIR=$(pwd)
export KDIR

# Default linker to use for builds.
export LINKER="ld.lld"

# Device name.
export DEVICE="Xiaomi SD720G Family"

# Date of build.
DATE=$(date +"%Y-%m-%d")
export DATE

# Device codename.
export CODENAME="miatoll"

# Builder name.
export BUILDER="LeddaZ"

# Kernel repository URL.
export REPO_URL="https://github.com/LeddaZ/android_kernel_xiaomi_sm6250"

# Commit hash of HEAD.
COMMIT_HASH=$(git rev-parse --short HEAD)
export COMMIT_HASH

# Number of jobs to run.
PROCS=$(nproc --all)
export PROCS

# Compiler to use for builds.
export COMPILER=gcc

# Requirements
if [[ "${COMPILER}" = gcc ]]; then
    if [ ! -d "${KDIR}/gcc64" ]; then
        echo "Downloading arm64 gcc..."
        curl -sL https://github.com/mvaisakh/gcc-arm64/archive/refs/heads/gcc-master.tar.gz | tar -xzf -
        mv "${KDIR}"/gcc-arm64-gcc-master "${KDIR}"/gcc64
    fi

    if [ ! -d "${KDIR}/gcc32" ]; then
        echo "Downloading arm gcc..."
        curl -sL https://github.com/mvaisakh/gcc-arm/archive/refs/heads/gcc-master.tar.gz | tar -xzf -
        mv "${KDIR}"/gcc-arm-gcc-master "${KDIR}"/gcc32
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/gcc64/bin/aarch64-elf-gcc --version | head -n 1)
    export KBUILD_COMPILER_STRING
    export PATH="${KDIR}"/gcc32/bin:"${KDIR}"/gcc64/bin:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O=out
        CROSS_COMPILE=aarch64-elf-
        CROSS_COMPILE_ARM32=arm-eabi-
        LD="${KDIR}"/gcc64/bin/aarch64-elf-"${LINKER}"
        AR=llvm-ar
        NM=llvm-nm
        OBJDUMP=llvm-objdump
        OBJCOPY=llvm-objcopy
        OBJSIZE=llvm-objsize
        STRIP=llvm-strip
        HOSTAR=llvm-ar
        HOSTCC=gcc
        HOSTCXX=aarch64-elf-g++
        CC=aarch64-elf-gcc
    )

elif [[ "${COMPILER}" = clang ]]; then
    if [ ! -d "${KDIR}/proton-clang" ]; then
        wget https://github.com/kdrag0n/proton-clang/archive/refs/heads/master.zip
        unzip "${KDIR}"/master.zip
        mv "${KDIR}"/proton-clang-master "${KDIR}"/proton-clang
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/proton-clang/bin/clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')
    export KBUILD_COMPILER_STRING
    export PATH=$KDIR/proton-clang/bin/:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O=out
        CROSS_COMPILE=aarch64-linux-gnu-
        CROSS_COMPILE_ARM32=arm-linux-gnueabi-
        LD="${LINKER}"
        AR=llvm-ar
        AS=llvm-as
        NM=llvm-nm
        OBJDUMP=llvm-objdump
        STRIP=llvm-strip
        CC=clang
    )
fi

if [ ! -d "${KDIR}/anykernel3/" ]; then
    echo "Cloning AnyKernel3..."
    git clone --depth=1 https://github.com/LeddaZ/AnyKernel3 -b miatoll-miui anykernel3
fi

# A function to exit on SIGINT.
exit_on_signal_SIGINT() {
    echo -e "\n\n\e[1;31m[✗] Received INTR call - Exiting...\e[0m"
    exit 0
}
trap exit_on_signal_SIGINT SIGINT

# A function to clean kernel source prior building.
clean() {
    echo -e "\n\e[1;93m[*] Cleaning source and out/ directory! \e[0m"
    make clean && make mrproper && rm -rf "${KDIR}"/out
    echo -e "\n\e[1;32m[✓] Source cleaned and out/ removed! \e[0m"
}

# A function to regenerate defconfig.
rgn() {
    echo -e "\n\e[1;93m[*] Regenerating defconfig! \e[0m"
    make "${MAKE[@]}" $CONFIG
    cp -rf "${KDIR}"/out/.config "${KDIR}"/arch/arm64/configs/$CONFIG
    echo -e "\n\e[1;32m[✓] Defconfig regenerated! \e[0m"
}

# A function to open a menu based program to update current config.
mcfg() {
    rgn
    echo -e "\n\e[1;93m[*] Making Menuconfig! \e[0m"
    make "${MAKE[@]}" menuconfig
    cp -rf "${KDIR}"/out/.config "${KDIR}"/arch/arm64/configs/$CONFIG
    echo -e "\n\e[1;32m[✓] Saved Modifications! \e[0m"
}

# A function to build the kernel.
img() {
    rgn
    echo -e "\n\e[1;93m[*] Building Kernel! \e[0m"
    BUILD_START=$(date +"%s")
    time make -j"$PROCS" "${MAKE[@]}" Image dtbo.img dtb.img 2>&1 | tee log.txt
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    if [ -f "${KDIR}/out/arch/arm64/boot/Image" ]; then
        echo -e "\n\e[1;32m[✓] Kernel built after $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! \e[0m"
    else
        echo -e "\n\e[1;31m[✗] Build Failed! \e[0m"
        exit 1
    fi
}

# A function to build DTBs.
dtb() {
    rgn
    echo -e "\n\e[1;93m[*] Building DTBS! \e[0m"
    time make -j"$PROCS" "${MAKE[@]}" dtbs dtbo.img dtb.img
    echo -e "\n\e[1;32m[✓] Built DTBS! \e[0m"
}

# A function to build out-of-tree modules.
mod() {
    rgn
    echo -e "\n\e[1;93m[*] Building Modules! \e[0m"
    mkdir -p "${KDIR}"/out/modules
    make "${MAKE[@]}" modules_prepare
    make -j"$PROCS" "${MAKE[@]}" modules INSTALL_MOD_PATH="${KDIR}"/out/modules
    make "${MAKE[@]}" modules_install INSTALL_MOD_PATH="${KDIR}"/out/modules
    find "${KDIR}"/out/modules -type f -iname '*.ko' -exec cp {} "${KDIR}"/anykernel3/modules/system/lib/modules/ \;
    echo -e "\n\e[1;32m[✓] Built Modules! \e[0m"
}

zipn="Kiki-MIUI-miatoll-$(date '+%Y%m%d-%H%M').zip"
if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
        zipn="${zipn::-4}-$(echo $head | cut -c1-8).zip"
fi

# A function to build an AnyKernel3 zip.
mkzip() {
    echo -e "\n\e[1;93m[*] Building zip! \e[0m"
    mkdir -p "${KDIR}"/anykernel3/dtbs
    mv "${KDIR}"/out/arch/arm64/boot/dtbo.img "${KDIR}"/anykernel3
    mv "${KDIR}"/out/arch/arm64/boot/dtb.img "${KDIR}"/anykernel3
    mv "${KDIR}"/out/arch/arm64/boot/Image "${KDIR}"/anykernel3
    cd "${KDIR}"/anykernel3 || exit 1
    zip -r9 "$zipn" . -x ".git*" -x "README.md" -x "LICENSE" -x "*.zip"
    echo -e "\n\e[1;32m[✓] Built zip! \e[0m"
}

# A function to build specific objects.
obj() {
    rgn
    echo -e "\n\e[1;93m[*] Building ${1}! \e[0m"
    time make -j"$PROCS" "${MAKE[@]}" "$1"
    echo -e "\n\e[1;32m[✓] Built ${1}! \e[0m"
}

# A function to showcase the options provided for args-based usage.
helpmenu() {
    echo -e "\n\e[1m
usage: $0 <arg>

example: $0 mcfg
example: $0 mcfg img
example: $0 mcfg img mkzip
example: $0 --obj=drivers/android/binder.o
example: $0 --obj=kernel/sched/

	 mcfg   Runs make menuconfig
	 img    Builds Kernel
	 dtb    Builds dtb(o).img
	 mod    Builds out-of-tree modules
	 mkzip  Builds anykernel3 zip
	 --obj  Builds specific driver/subsystem
	 rgn    Regenerates defconfig"
}

# A function to setup menu-based usage.
ndialog() {
    HEIGHT=16
    WIDTH=40
    CHOICE_HEIGHT=30
    BACKTITLE="Yet Another Kernel Builder"
    TITLE="YAKB v1.0"
    MENU="Choose one of the following options: "
    OPTIONS=(1 "Build kernel"
        2 "Build DTBs"
        3 "Build modules"
        4 "Open menuconfig"
        5 "Regenerate defconfig"
        6 "Build AnyKernel3 zip"
        7 "Build a specific object"
        8 "Clean"
        9 "Exit"
    )
    CHOICE=$(dialog --clear \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --menu "$MENU" \
        $HEIGHT $WIDTH $CHOICE_HEIGHT \
        "${OPTIONS[@]}" \
        2>&1 >/dev/tty)
    clear
    case "$CHOICE" in
    1)
        clear
        img
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    2)
        clear
        dtb
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    3)
        clear
        mod
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    4)
        clear
        mcfg
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    5)
        clear
        rgn
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    6)
        dialog --inputbox --stdout "Enter version number: " 15 50 | tee .t
        ver=$(cat .t)
        clear
        rm .t
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    7)
        mkzip
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    8)
        dialog --inputbox --stdout "Enter object path: " 15 50 | tee .f
        ob=$(cat .f)
        if [ -z "$ob" ]; then
            dialog --inputbox --stdout "Enter object path: " 15 50 | tee .f
        fi
        clear
        obj "$ob"
        rm .f
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    9)
        clear
        clean
        img
        echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            ndialog
        fi
        ;;
    10)
        echo -e "\n\e[1m Exiting YAKB...\e[0m"
        sleep 3
        exit 0
        ;;
    esac
}

if [[ -z $* ]]; then
    ndialog
fi

for arg in "$@"; do
    case "${arg}" in
    "mcfg")
        mcfg
        ;;
    "img")
        img
        ;;
    "dtb")
        dtb
        ;;
    "mod")
        mod
        ;;
    "mkzip")
        mkzip
        ;;
    "--obj="*)
        object="${arg#*=}"
        if [[ -z "$object" ]]; then
            echo "Use --obj=filename.o"
            exit 1
        else
            obj "$object"
        fi
        ;;
    "rgn")
        rgn
        ;;
    "clean")
        clean
        ;;
    "help")
        helpmenu
        exit 1
        ;;
    *)
        helpmenu
        exit 1
        ;;
    esac
done
