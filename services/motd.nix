{ lib, pkgs, ... }: {
  programs.rust-motd = {
    enable = true;
    order = [
      "global" # how? whyyyy !??!?
      "banner"
      "filesystems"
      "memory"
      "uptime"
    ];
    settings = {
      banner = {
        color = "cyan";
        command = "${lib.getExe pkgs.figlet} -f ${./assets/cosmic.flf} -w 90 stargaze !";
      };
      uptime = {
        prefix = "Uptime: ";
      };
      filesystems = {
        root = "/";
      };
      memory = {
        swap_pos = "beside";
      };
    };
  };
}
