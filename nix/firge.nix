{ lib, stdenvNoCC, fetchzip }:

stdenvNoCC.mkDerivation rec {
  pname = "firge";
  version = "0.3.0";

  # Nerd Fonts のアイコンを含まない素の Firge。
  # Console / 非 Console、通常幅 / 3:5 幅の 4 ファミリーが入る
  src = fetchzip {
    url = "https://github.com/yuru7/Firge/releases/download/v${version}/Firge_v${version}.zip";
    hash = "sha256-zPAeOits3FxIwerGCY8L3eDZtBi3qU19p3XOhtcMV64=";
  };

  installPhase = ''
    runHook preInstall
    install -Dm644 *.ttf -t $out/share/fonts/firge
    runHook postInstall
  '';

  meta = {
    description = "Fira Mono と源真ゴシックを合成したプログラミングフォント";
    homepage = "https://github.com/yuru7/Firge";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
