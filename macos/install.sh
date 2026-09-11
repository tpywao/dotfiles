#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# macOS のシステム設定。defaults の書き込み先はユーザーのドメインなので sudo は要らない
is_mac || exit 0

# 型は実機から読み取ったものをそのまま使う。macOS は同じ意味のキーでも
# ドメインごとに型を変えて書いており（トラックパッドの Dragging は内蔵が integer、
# Bluetooth が boolean）、揃えると元の状態を再現できない。
changed=0

# write_default <ドメイン> <キー> <型> <値>
# 値は `defaults read` が返す表記で渡す。比較にそのまま使う
write_default() {
  domain=$1
  key=$2
  type=$3
  value=$4

  # 差分が無くても defaults write は成功してしまう。何件動いたかを出すために
  # 現在値と比べ、違うときだけ書く
  if [ "$(defaults read "$domain" "$key" 2> /dev/null)" = "$value" ]; then
    return 0
  fi
  if ! defaults write "$domain" "$key" "$type" "$value"; then
    log_tag "$LOG_FAILED" "[failed]" "$domain $key"
    return 1
  fi
  changed=$((changed + 1))
}

# write_bool <ドメイン> <キー> <true|false>
# bool だけは書き込みと読み出しで表記が違うため write_default と分ける。
# `defaults write -bool` が受け付けるのは true/false/yes/no だけで、1 を渡すと
# usage を出して何も書かない。一方 `defaults read` は 1/0 を返す
write_bool() {
  domain=$1
  key=$2
  value=$3

  case $value in
    true) expected=1 ;;
    *) expected=0 ;;
  esac
  if [ "$(defaults read "$domain" "$key" 2> /dev/null)" = "$expected" ]; then
    return 0
  fi
  if ! defaults write "$domain" "$key" -bool "$value"; then
    log_tag "$LOG_FAILED" "[failed]" "$domain $key"
    return 1
  fi
  changed=$((changed + 1))
}

# report_domain <ドメイン>
# キーは 1 ドメインあたり 10〜26 件あり、1 行ずつ出すと画面が流れる。
# 対象ごとの結果はドメイン単位でまとめる
report_domain() {
  if [ "$changed" -eq 0 ]; then
    log_tag "$LOG_UNCHANGED" "[current]" "$1"
  else
    log_tag "$LOG_CHANGED" "[applied]" "$1 ($changed 件)"
  fi
  changed=0
}

# import_defaults <ドメイン> <plist>
# 値が入れ子の dict / array で `defaults write` に平文で書けないものを plist から入れる。
# import は plist に載っているキーだけを上書きし、dst にしか無いキーは残す
import_defaults() {
  if defaults import "$1" "$2"; then
    log_tag "$LOG_CHANGED" "[imported]" "$1"
  else
    log_tag "$LOG_FAILED" "[failed]" "$1 ($2)"
  fi
}

# ---- Dock ----
write_bool com.apple.dock autohide true
write_default com.apple.dock orientation -string left
write_default com.apple.dock tilesize -float 46
write_bool com.apple.dock magnification false
write_bool com.apple.dock minimize-to-application true
write_bool com.apple.dock show-recents false
write_bool com.apple.dock mru-spaces false
write_bool com.apple.dock expose-group-apps true
write_bool com.apple.dock showAppExposeGestureEnabled true
write_bool com.apple.dock showMissionControlGestureEnabled true
# 右下のホットコーナー。corner が動作、modifier が併用する修飾キー
write_default com.apple.dock wvous-br-corner -int 1
write_default com.apple.dock wvous-br-modifier -int 0
report_domain com.apple.dock

# ---- Finder ----
# ShowSidebar は入れない。サイドバーの表示/非表示を切り替えるたびに Finder が
# 書き換えるため、インストール時点の状態を焼き付けるだけになる
write_default com.apple.finder FXPreferredViewStyle -string Nlsv
write_default com.apple.finder NewWindowTarget -string PfHm
write_bool com.apple.finder ShowPathbar true
write_bool com.apple.finder FK_AppCentricShowSidebar true
write_bool com.apple.finder ShowHardDrivesOnDesktop false
write_bool com.apple.finder ShowExternalHardDrivesOnDesktop true
write_bool com.apple.finder ShowRemovableMediaOnDesktop true
write_default com.apple.finder FXArrangeGroupViewBy -string Name
write_default com.apple.finder FXPreferredGroupBy -string None
report_domain com.apple.finder

# ---- 外観・キーボード・トラックパッドの共通設定 ----
write_default NSGlobalDomain AppleInterfaceStyle -string Dark
write_default NSGlobalDomain AppleIconAppearanceTheme -string RegularDark
write_default NSGlobalDomain AppleIconAppearanceTintColor -string Other
write_default NSGlobalDomain AppleIconAppearanceCustomTintColor -string "1.000000 0.562494 0.475000 0.932450"
write_default NSGlobalDomain AppleAquaColorVariant -int 1
write_bool NSGlobalDomain AppleReduceDesktopTinting true
write_default NSGlobalDomain AppleShowScrollBars -string Always
write_bool NSGlobalDomain NSGlassDiffusionSetting false
write_bool NSGlobalDomain AppleMiniaturizeOnDoubleClick false
write_bool NSGlobalDomain AppleMenuBarVisibleInFullscreen true
write_bool NSGlobalDomain _HIHideMenuBar false
write_default NSGlobalDomain AppleAntiAliasingThreshold -int 4
write_bool NSGlobalDomain AppleShowAllExtensions true
write_default NSGlobalDomain AppleKeyboardUIMode -int 2
write_bool NSGlobalDomain NSAutomaticSpellingCorrectionEnabled false
write_bool NSGlobalDomain WebAutomaticSpellingCorrectionEnabled false
write_bool NSGlobalDomain com.apple.keyboard.fnState true
write_default NSGlobalDomain com.apple.trackpad.scaling -float 0.875
write_bool NSGlobalDomain com.apple.trackpad.forceClick true
write_bool NSGlobalDomain com.apple.swipescrolldirection true
write_bool NSGlobalDomain com.apple.springing.enabled true
write_default NSGlobalDomain com.apple.springing.delay -float 0.5
write_default NSGlobalDomain com.apple.sound.beep.flash -int 0
report_domain NSGlobalDomain

# ---- トラックパッド (内蔵) ----
write_bool com.apple.AppleMultitouchTrackpad Clicking true
write_default com.apple.AppleMultitouchTrackpad Dragging -int 0
write_default com.apple.AppleMultitouchTrackpad DragLock -int 0
write_default com.apple.AppleMultitouchTrackpad ActuateDetents -int 1
write_bool com.apple.AppleMultitouchTrackpad ForceSuppressed false
write_default com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0
write_default com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 0
write_bool com.apple.AppleMultitouchTrackpad TrackpadRightClick true
write_default com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 0
write_bool com.apple.AppleMultitouchTrackpad TrackpadScroll true
write_default com.apple.AppleMultitouchTrackpad TrackpadHorizScroll -int 1
write_bool com.apple.AppleMultitouchTrackpad TrackpadMomentumScroll true
write_bool com.apple.AppleMultitouchTrackpad TrackpadHandResting true
write_default com.apple.AppleMultitouchTrackpad TrackpadPinch -int 1
write_default com.apple.AppleMultitouchTrackpad TrackpadRotate -int 1
write_bool com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag false
write_default com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0
write_default com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 2
write_default com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 2
write_default com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 2
write_default com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2
write_default com.apple.AppleMultitouchTrackpad TrackpadFourFingerPinchGesture -int 2
write_default com.apple.AppleMultitouchTrackpad TrackpadFiveFingerPinchGesture -int 2
write_default com.apple.AppleMultitouchTrackpad TrackpadTwoFingerDoubleTapGesture -int 1
write_default com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
write_default com.apple.AppleMultitouchTrackpad USBMouseStopsTrackpad -int 0
report_domain com.apple.AppleMultitouchTrackpad

# ---- トラックパッド (Magic Trackpad) ----
# 内蔵と同じ設定を別ドメインが持つ。外付けを繋いだときに設定が戻らないよう両方へ書く
write_bool com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking true
write_bool com.apple.driver.AppleBluetoothMultitouch.trackpad Dragging false
write_bool com.apple.driver.AppleBluetoothMultitouch.trackpad DragLock false
write_bool com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick true
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 0
write_bool com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadScroll true
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadHorizScroll -int 1
write_bool com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadMomentumScroll true
write_bool com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadHandResting true
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadPinch -int 1
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRotate -int 1
write_bool com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag false
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 0
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 2
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture -int 2
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture -int 2
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerPinchGesture -int 2
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFiveFingerPinchGesture -int 2
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerDoubleTapGesture -int 1
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
write_default com.apple.driver.AppleBluetoothMultitouch.trackpad USBMouseStopsTrackpad -int 0
report_domain com.apple.driver.AppleBluetoothMultitouch.trackpad

# ---- アクセシビリティ ----
write_bool com.apple.universalaccess reduceMotion true
write_bool com.apple.universalaccess differentiateWithoutColor true
write_bool com.apple.universalaccess showToolbarButtonShapes false
write_bool com.apple.universalaccess showWindowTitlebarIcons false
write_bool com.apple.universalaccess closeViewHotkeysEnabled false
report_domain com.apple.universalaccess

# ---- 入力 ----
write_default com.apple.HIToolbox AppleFnUsageType -int 0
write_default com.apple.HIToolbox AppleDictationAutoEnable -int 0
report_domain com.apple.HIToolbox

# 入力ソースとキーボードショートカットは値が入れ子の dict / array で、平文では書けない。
# ショートカットはキーが数値 ID で Apple が意味を公開していないため、平文化しても読めない。
# 生成手順は macos/README.md
import_defaults com.apple.HIToolbox "$DOTFILES/macos/input-sources.plist"
import_defaults com.apple.symbolichotkeys "$DOTFILES/macos/symbolichotkeys.plist"

# 書き込んだ値は、対象のプロセスを再起動するまで画面に出ない
echo "-----> Restarting Dock and Finder to apply"
killall Dock Finder SystemUIServer 2> /dev/null

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
