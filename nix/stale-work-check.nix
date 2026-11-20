{ config, pkgs, ... }:

let
  stale-work-check = pkgs.writeShellApplication {
    name = "stale-work-check";
    # launchd から起動すると PATH が /usr/bin:/bin:/usr/sbin:/sbin だけになるため、
    # 使うコマンドをここで固定する。通知の osascript は /usr/bin にある
    runtimeInputs = with pkgs; [
      gh
      jq
      coreutils
    ];
    text = builtins.readFile ./stale-work-check.sh;
  };
in
{
  home.packages = [ stale-work-check ];

  # 平日の朝と夕方に走らせる。スリープ中に過ぎた回は、起床時にまとめて 1 回走る。
  # 対象のリポジトリは ~/.config/stale-work-check/config に書く（書式は stale-work-check.sh の先頭）
  launchd.agents.stale-work-check = {
    enable = true;
    config = {
      ProgramArguments = [
        "${stale-work-check}/bin/stale-work-check"
        "--notify"
      ];
      StartCalendarInterval = builtins.concatMap (
        Weekday:
        map (Hour: {
          inherit Weekday Hour;
          Minute = 3;
        }) [ 9 18 ]
      ) [ 1 2 3 4 5 ];
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/stale-work-check.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/stale-work-check.log";
    };
  };
}
