#!/usr/local/bin/zsh

export JAVA_HOME=/Applications/Android\ Studio.app/Contents/jre/jdk/Contents/Home
# export JAVA_OPTS='-XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee'

# ANDROID_HOME is deprecated (in Android Studio)
# use ANDROID_SDK_ROOT instead
export ANDROID_SDK_HOME=/Volumes/extssd/Android
export ANDROID_SDK_ROOT=/Volumes/extssd/Android/sdk
export ANDROID_EMULATOR_HOME=/Volumes/extssd/Android/Emulator
export ANDROID_AVD_HOME=/Volumes/extssd/Android/Emulator/avd
export path=(
  $JAVA_HOME/bin(N-/)
  $ANDROID_SDK_ROOT/platform-tools(N-/)
  $ANDROID_SDK_ROOT/tools/bin(N-/)
  $path
)
