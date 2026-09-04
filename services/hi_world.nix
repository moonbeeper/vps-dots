{ pkgs, config, ... }:
let
  makeService = import ./make_service.nix;
  pack = makeService {
    name = "hi_world";
    flake = pkgs.writeShellScriptBin "hi-world" ''
      exec ${pkgs.http-server}/bin/http-server -p 8080
    '';
  };
in
{
  imports = [ pack ]; # wtf, what a workaround
  moonix.services.hi_world = {
    postgres = {
      databases = ["meow"];
    };
    tailscale = true;
  };
}
