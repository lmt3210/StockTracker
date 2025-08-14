#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $(basename $0) [package <version> | notarize <version> | "
    echo "       log <submit_id> | staple <version>]" > /dev/stderr
    exit 1
fi

if ! [ -n "${DEV_ID_APP}" ] || ! [ -n "${DEV_ID_INST}" ]; then
    echo "Please set these variables in your environment for code signing:"
    echo "    DEV_ID_APP"
    echo "    DEV_ID_INST"
    echo "Examples:"
    echo '    DEV_ID_APP="Developer ID Application: Your Name (12345678)"'
    echo '    DEV_ID_INST="Developer ID Installer: Your Name (12345678)"'
    exit 1
fi

ACTION=$1
SUBMIT_ID=$2
VERSION=$2

APP_ENTITLEMENTS="StockTracker/StockTracker.entitlements"
APP=./StockTracker.xcarchive/Products/Applications/StockTracker.app

if [ "${ACTION}" == "package" ]; then
    # Remove previous artifacts
    rm -f *.pkg
    rm -rf tmp_*
    rm -f log.json

    # Copy components
    mkdir tmp_app
    cp -r ${APP} tmp_app

    # Sign app
    codesign -s "${DEV_ID_APP}" -f --timestamp -o runtime \
        --entitlements "${APP_ENTITLEMENTS}" tmp_app/StockTracker.app

    # Build component package
    pkgbuild --root tmp_app --identifier com.larrymtaylor.StockTracker \
        --version ${VERSION} --install-location /Applications \
        --min-os-version 10.11 --component-plist app.plist app.pkg

    # Build installer package
    cat distribution.plist | sed 's/VERSION/${VERSION}/' > dist.plist
    productbuild --sign "${DEV_ID_INST}" --distribution dist.plist \
        --product requirements.plist StockTracker.pkg
elif [ "${ACTION}" == "notarize" ]; then
    # If you are using nested containers, only notarize the outermost 
    # container.  For example, if you have an app inside an installer 
    # package on a disk image, sign the app, sign the installer package,
    # and sign the disk image, but only notarize the disk image.

    # Upload for notarization
    xcrun notarytool submit StockTracker.pkg --keychain-profile \
        "LT_PASSWORD" --wait
elif [ "${ACTION}" == "log" ]; then
    # Download notarization log file
    xcrun notarytool log ${SUBMIT_ID} --keychain-profile "LT_PASSWORD" log.json
elif [ "${ACTION}" == "staple" ]; then
    # Staple notary ticket to product
    xcrun stapler staple StockTracker.pkg
else
    echo "Invalid action ${ACTION}"
    exit 1
fi

exit 0
