{ lib, stdenvNoCC, fetchzip }:

stdenvNoCC.mkDerivation rec {
  pname = "firge-nerd";
  version = "0.3.0";

  # 上流は Nerd Fonts 版として Console バリアントのみを配布している。
  # 非 Console の FirgeNerd はこの zip には含まれない
  src = fetchzip {
    url = "https://github.com/yuru7/Firge/releases/download/v${version}/FirgeNerd_v${version}.zip";
    hash = "sha256-Zb95RroGitkOetmLPa4r8EsIKnKiYw7pAlVg6j9lgoc=";
  };

  installPhase = ''
    runHook preInstall
    install -Dm644 *.ttf -t $out/share/fonts/firge-nerd
    runHook postInstall
  '';

  meta = {
    description = "Fira Mono と源真ゴシックを合成したプログラミングフォント (Nerd Fonts 版)";
    homepage = "https://github.com/yuru7/Firge";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
