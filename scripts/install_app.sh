#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
DERIVED_DATA="$PROJECT_DIR/build/DerivedData"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/TokenBar.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/TokenBar.app"

cd "$PROJECT_DIR"
xcodegen generate
xcodebuild \
  -project TokenBar.xcodeproj \
  -scheme TokenBar \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

codesign --force --deep --sign - "$BUILT_APP"
mkdir -p "$INSTALL_DIR"

if [[ -d "$INSTALLED_APP" ]]; then
  BACKUP_APP="$INSTALL_DIR/TokenBar.backup-$(date +%Y%m%d-%H%M%S).app"
  mv "$INSTALLED_APP" "$BACKUP_APP"
  print "기존 앱 백업: $BACKUP_APP"
fi

ditto "$BUILT_APP" "$INSTALLED_APP"
print "설치 완료: $INSTALLED_APP"
print "실행: open '$INSTALLED_APP'"

