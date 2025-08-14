#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $(basename $0) <version>" > /dev/stderr
    exit 1
fi

VERSION=$1
ARCHIVE_DIR=/Users/Larry/Library/Developer/Xcode/Archives/CommandLine

rm -f make.log
touch make.log
rm -rf build

echo "Building StockTracker" 2>&1 | tee -a make.log

xcodebuild -project StockTracker.xcodeproj clean 2>&1 | tee -a make.log
xcodebuild -project StockTracker.xcodeproj \
    -scheme "StockTracker Release" -archivePath StockTracker.xcarchive \
    archive 2>&1 | tee -a make.log

rm-rf ${ARCHIVE_DIR}/StockTracker-v${VERSION}.xcarchive
cp -rf StockTracker.xcarchive \
    ${ARCHIVE_DIR}/StockTracker-v${VERSION}.xcarchive

