#!/bin/bash
#
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=m20lte
VENDOR=samsung

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d ${MY_DIR} ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

SECTION=
KANG=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup {
	case "$1" in
	vendor/lib*/libhifills.so)
		grep -q libunwindstack.so "$2" || "$PATCHELF" --add-needed "libunwindstack.so" "$2"
		;;
	vendor/lib*/hw/camera.vendor.exynos7904.so)
		"$PATCHELF" --replace-needed "libcamera_client.so" "libcamera_metadata_helper.so" "$2"
		"$PATCHELF" --replace-needed "libgui.so" "libgui_vendor.so" "$2"
		;;
	vendor/lib*/libexynoscamera.so | vendor/lib*/libexynoscamera3.so)
		"$PATCHELF" --remove-needed "libcamera_client.so" "$2"
		"$PATCHELF" --remove-needed "libgui.so" "$2"
		;;
	vendor/lib*/libsensorlistener.so)
		grep -q libshim_sensorndkbridge.so "$2" || "$PATCHELF" --add-needed "libshim_sensorndkbridge.so" "$2"
		;;
	vendor/bin/hw/rild | vendor/lib*/libsec-ril*.so)
		"$PATCHELF" --replace-needed libril.so libril-samsung.so "$2"
		;;
	vendor/lib*/camera.device@*-impl.universal7904.so)
		"$PATCHELF" --set-soname "$(basename "$2")" "$2"
		;;
	vendor/lib/hw/audio.primary.exynos7904.so)
		grep -q libshim_audioparams.so "$2" || "$PATCHELF" --add-needed libshim_audioparams.so "$2"
		sed -i 's/str_parms_get_str/str_parms_get_mod/g' "$2"
		;;
	vendor/lib64/hw/hwcomposer.exynos7904.so)
		"$PATCHELF" --replace-needed "libutils.so" "libutils-v32.so" "$2"
		;;
	esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" \
        "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
