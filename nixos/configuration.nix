# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  # You can import other NixOS modules here
  imports = [
    ./disk.nix
    ./secret_paths.nix
    ./services.nix
  ];

  nixpkgs = {
    hostPlatform = lib.mkDefault "x86_64-linux";
    # Configure your nixpkgs instance
    config = {
      allowUnfree = true;
    };
  };

  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      flake-registry = "";
      trusted-users = [ "moon" ];
    };
    channel.enable = false;
    optimise.automatic = true;
  };

  boot.loader.grub.enable = true;
  zramSwap.enable = true;

  networking.hostName = "stargaze";
  time.timeZone = "Europe/Madrid";

  users.users = {
    moon = {
      # TODO: You can set an initial password for your user.
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      # Be sure to change it (using passwd) after rebooting!
      initialPassword = "mrawr";
      isNormalUser = true;
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEIw+Y54mCylt14Braappuzgich5F01P4te+uMI8aeRI hetzner"
      ];
      # TODO: Be sure to add any other groups you need (such as networkmanager, audio, docker, etc)
      extraGroups = [ "wheel" ];
    };
  };
  security.sudo.wheelNeedsPassword = false; # right, i am using a ssh keys. thanks warning of interactive sudo in deployrs

  home-manager = {
    users.moon = ./home.nix;
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.fish.enable = true;
  programs.starship.enable = true;
  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    wget
    curl
    git
    htop
    btop
    unzip
  ];

  services.openssh = {
    enable = true;
    settings = {
      # Opinionated: forbid root login through SSH.
      PermitRootLogin = "no";
      # Opinionated: use keys only.
      # Remove if you want to SSH using passwords
      PasswordAuthentication = false;
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "26.05";
}
