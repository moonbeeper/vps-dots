{ pkgs, ... }:
let
  makeService = import ./make_service.nix;
  pack = makeService {
    name = "hi_world";
    flake = pkgs.hello;
    postgres = {
      enable = true;
      databases = [ "meow" ];
    };
  };
in
{
  imports = [ pack ]; # wtf, what a workaround
}
