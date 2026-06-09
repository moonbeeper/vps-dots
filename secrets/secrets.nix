let
  moon = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEIw+Y54mCylt14Braappuzgich5F01P4te+uMI8aeRI hetzner";
  stargaze = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHK2AbMQLkqE/NE77pKGkpUP5KBx4/r57wxnwX5lsfGK";

  users = [
    # god its weird not having to put a comma.
    moon
    stargaze
  ];
in
{
  "caddy_cloudflare.age".publicKeys = users;
}
