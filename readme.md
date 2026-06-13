# moonbeeper's stupid vps dots

> wok in progress :D

hi, this is my vps nix config. Its literally just so I can have a reproducible environment for my *pretty and beautiful* 5€ vps, instead of setting up manually a bunch of docker containers and services manually every single time I want to redeploy on another provider.

Practically, the vps config is at... the [nixos/configuration.nix](nixos/configuration.nix) file, who would have guessed. It IS based on [Misterio77's Nix starter configs](https://github.com/Misterio77/nix-starter-configs/) minimal setup but at least modified to my needs.. like programs and services (wowie).

## what the hell is each file for?

ah, young.. guy, that's a good question that my self didnt know and that I still dont know. But I will try to explain it as best as I can. **Secrets and Services** *(and disk and home config, but we don't talk about it :3)*. boom, that's it.

## secrets

You can see on the left (or right) the [secrets](secrets/) folder and the [nixos/secret_paths.nix](nixos/secret_paths.nix) file.

The [secrets](secrets/) directory has the encrypted files .age and *also* a `secrets.nix` that maps each encrypted file to the SSH keys that can decrypt it. In this case, just my own key (moon) and the vps host key (stargaze). I use [agenix](https://github.com/ryantm/agenix) for this (if you didnt tell already), so the encrypted files sit comfortably on some guy's basement server that for some reason is called github and is publicly accessible, but only I (and the vps) can decrypt them. Pretty neat, right? I know, i know >:3.

> If you want to add your own secrets OR really want to know how this works and why its setup like this, just checkout the [agenix](https://github.com/ryantm/agenix) repo... this is quite literally the product of following a well made tutorial from them.

The [nixos/secret_paths.nix](nixos/secret_paths.nix) is where I tell the system "HEY, this key should end up here. oh and also its on the 'age' namespace". I keep it separate from the [nixos/configuration.nix](nixos/configuration.nix) to not clutter it with secrets in the future.

Each secrets works like .env file, familiar to pratically all devs and space birbs (like me, i think...). Here, systemd's `EnvironmentFile` takes the secret path and loads it into the service's environment.

Right now the only secret is the `caddy_cloudflare.age` which holds the Cloudflare API token used by Caddy to get TLS certs via orange cloud magic. You can see it being used in the [Caddy config](services/caddy.nix) on the systemd section.

If you're forking this, you **should** follow [agenix's](https://github.com/ryantm/agenix) tutorial, but... you'll want to (with skipped steps):
1. Replace my SSH keys in [secrets/secrets.nix](secrets/secrets.nix) with your own
2. Run `nix develop` to get `agenix`
3. Run `cd secrets` to get into the secrets folder (duh)
4. `EDITOR=nvim agenix -e my_secret.age` to create your secret or edit an existing one. YOU must set the EDITOR= to any editor that you want, like `nvim`, `vim`, `nano`... or at least it how it works for me.

## services

You can see on the ceiling (or the floor) the [services](services/) folder and the [nixos/services.nix](nixos/services.nix) file.

The [services](services/) hole is where you can find all the services that will be exposed or directly used in the [nixos/configuration.nix](nixos/configuration.nix) file.
Each service is a `.nix` file that contains the service's configuration, like Caddy, Postgres or [hi_world](services/hi_world.nix). 

> You can see how services like Caddy or Postgres arent using the Factory (talked under here :T) because the Factory is for app services that sit *behind* Caddy and optionally use Postgres. You don't proxy Caddy through itself or create a postgres user for postgres lol.

The main chocolate star of the services is the [factory](services/make_service.nix), where ACTuAL services that will be proxied via Caddy will be created. The factory is practically a function that takes a service name, a nix package (flake), an optional port + domain (for caddy), and optional postgres databases, then spits out a *NixOS* module that creates the following:

- A systemd service with [hardening](https://gist.github.com/ageis/f5595e59b1cddb1513d1b425a323db04), `DynamicUser`, etc..
  - The service also has a `EnvironmentFile` that points to the secret path of the service, if its provided.
- A Caddy reverse proxy entry if a domain is set (Obviously, going through the Cloudflare highway)
- A postgres user + database if requested (both suffixed with `_svc`, with `-` replaced by `_` and not lowercased).
- An entry to `moonix.services.SERVICE_NAME`

Soo instead of writing the same boilerplate for every single service, I just call the factory (via phone). You can see it in action with a preeeeety simple example in [hi_world](services/hi_world.nix), which is literally just `pkgs.hello` wrapped up with postgres bits to test the functionality (wont remove it, c;).

The [nixos/services.nix](nixos/services.nix) file just imports everything and enables whatever I want running. That's where you'd toggle things on/off and maybe configure a bit more the created stuff.

Also there's a rare [nixos/home.nix](nixos/home.nix) floating around. AH! Its just the home-manager config for the `moon` user with some fish aliases and some packages. It's imported in [configuration.nix](nixos/configuration.nix) like everything else.

## how can i deploy this?

Ah, you want to deploy this? oh god, please dont get me accountable for the crimes or vps fires that this *could* make.

First of all, follow the [Secrets](#secrets) section and the [agenix](https://github.com/ryantm/agenix) tutorial (I know I really repeat it, but it really does explain how to use it correctly).

Second, let's get our hands again dirty:

1. Get onto `nix develop`
2. Delete `facter.json`, it will be regenerated when installing NixOS onto the VPS (Its the practically the hardware map, a big one)
3. If using Hetzner as a VPS provider, enable Rescue Mode (Under the Rescue tab) on the VPS Control panel.
4. If, not installed yet, run nixos-anywhere to install NixOS onto the bare VPS: 
```bash
nixos-anywhere -- --flake .#stargaze --generate-hardware-config nixos-facter ./facter.json root@<VPS_IP>
```
This installs NixOS, generated the hardware map, and reboots the VPS into its new life, nixos i guess.

5. If the VPS is **already running NixOS**, you don't need all that spaghetti. We just use `deploy-rs` to update it!
```bash
deploy-rs -- .
```

6. If you want to check for errors before deploying even though `deploy-rs` already does that but this is great for when you are trying to make a new thing. (gasp, god i almost ran out of air): 
```bash
nix build .#nixosConfigurations.stargaze.config.system.build.toplevel
```

7. AAAAND boom you are all set!
