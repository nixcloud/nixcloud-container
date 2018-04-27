let
  # XXX: This is needed so that hybrid cgroup layouts are properly working in
  # containers. Remove this as soon as lxc >= 2.0.9 has landed in <nixpkgs>.
  overlays = [
    (self: super: (import ./patches.nix { inherit super;}))
  ];
in

{ system ? builtins.currentSystem
, pkgs ? import <nixpkgs> { inherit system overlays; }
, lib ? pkgs.stdenv.lib
, lxcExtraConfig ? ""
, name ? ""
, ip ? ""
, container
}:

with pkgs;
with lib;

#assert ip != "" && container_ ? network && container.network ? ip;

let

  container_ = if container ? configuration then container else { configuration = container; };

  configuration = container_.configuration;
  containerName = if name == "" then container.name else name;

  containerIp = if container ? network && container.network ? ip then container.network.ip else ip;
  gateway = if container_ ? network && container.network ? gateway then
    container.network.gateway else "10.101.0.1";
  bridge = if container_ ? network && container.network ? bridge then
    container.network.bridge else "brNC-hostonly";

  addBridgeInet = (container ? network && container.network ? enableNat && container.network.enableNat);
  bridgeInet = "brNC-internet";

  autostart = if container_ ? autostart && container.autostart then "1" else "0";

  containerConfig = (import <nixpkgs/nixos/lib/eval-config.nix> {
    modules =
      let
      extraConfig = {
        nixpkgs.system = system;
        boot.isContainer = true;
        environment.systemPackages = with pkgs; [ dfc htop iptables ];
        networking = {
          hostName = mkDefault containerName;
          interfaces.hostonly = {
            useDHCP = false;
            ipv4.addresses = [ { address = ip; prefixLength = 16; } ];
          };

        };
        nixpkgs.overlays = overlays;
        services.mingetty.autologinUser = mkDefault "root";
      };
      networkInetBridge = if addBridgeInet then {
        networking = {
          dhcpcd = {
            allowInterfaces = [ "internet" ];
            extraConfig = ''
              ipv6
              noipv4ll
              # we are using radvd, so we disable router solicitation in dhcpd6
              noipv6rs
              waitip 4
              interface internet
                # request a normal (IA_NA) IPv6 address with IAID 1
                ia_na 1
                waitip 4
                waitip 6
            '';
          };
          interfaces = {
            internet.useDHCP = true;
          };
        };
      } else {};
      in [ extraConfig networkInetBridge configuration ];
    prefix = [ "systemd" "containers" containerName ];
    extraArgs = { inherit ip; name = containerName; };
  }).config.system.build.toplevel;

  lxcConfigWrapper = pkgs.writeText "configWrapper" ''
    lxc.include = /nix/var/nix/profiles/nixcloud-container/${containerName}/profile/config
  '';

  lxcConfig = pkgs.writeText "config" ''
    lxc.uts.name = ${containerName}

    # Fixme also support other architectures?
    lxc.arch = ${if system == "x86_64-linux" then "x86_64" else "i686"}
    # Not needed, just makes spares a few cpu cycles as LXC doesn't have
    # to detect the backend.
    #lxc.rootfs.backend = dir
    lxc.rootfs.path = /var/lib/lxc/${containerName}/rootfs
    lxc.init.cmd = /init/profile/container/init
    #lxc.rootfs = /var/lib/lxc/${containerName}/rootfs

    # Ensures correct functionality with user namespaces. Since mknod is not possible stuff like
    # /dev/console, /dev/tty, /dev/urandom, etc. need to be bind mounted. Note the order
    # of the file inclusion here is important.
    lxc.include = ${pkgs.lxc}/share/lxc/config/common.conf
    lxc.include = ${pkgs.lxc}/share/lxc/config/userns.conf

    ## Network
    # see also https://wiki.archlinux.org/index.php/Linux_Containers
    lxc.net.0.type = veth
    lxc.net.0.name = hostonly
    #lxc.net.0.ipv4.address = ${containerIp} (we assign this using nix, not from lxc)
    lxc.net.0.flags = up
    lxc.net.0.link = ${bridge}

    ${optionalString addBridgeInet ''
    lxc.net.1.type = veth
    lxc.net.1.name = internet
    lxc.net.1.flags = up
    lxc.net.1.link = ${bridgeInet}
    ''
    }

    # Specifiy {u,g}id mapping.
    lxc.idmap = u 0 100000 65536
    lxc.idmap = g 0 100000 65536

    # FIXME apparmor support
    # Nixos does not provide AppArmor support.
    #lxc.aa_profile = unconfined
    #lxc.aa_allow_incomplete = 1
    lxc.apparmor.profile = unconfined
    lxc.apparmor.allow_incomplete = 1

    # Tweaks for systemd.
    lxc.autodev = 1

    # Additional mount entries.
    lxc.mount.entry = /nix/store nix/store none defaults,bind.ro 0.0
    lxc.mount.entry = /nix/var/nix/profiles/nixcloud-container/${containerName}/ init none defaults,bind.ro 0 0

    # Mount entries that lead to a cleaner boot experience.
    lxc.mount.entry = /sys/kernel/debug sys/kernel/debug none bind,optional 0 0
    lxc.mount.entry = /sys/kernel/security sys/kernel/security none bind,optional 0 0
    lxc.mount.entry = /sys/fs/pstore sys/fs/pstore none bind,optional 0 0
    lxc.mount.entry = mqueue dev/mqueue mqueue rw,relatime,create=dir,optional 0 0

    # LXC autostart
    lxc.start.auto = ${autostart}

    ${lxcExtraConfig}
    '';

in pkgs.stdenv.mkDerivation {
  name = "nixcloudContainer-${name}";
  phases = "installPhase";
  installPhase = ''
    mkdir $out
    ln -s ${containerConfig} $out/container
    ln -s ${lxcConfig} $out/config
    ln -s ${lxcConfigWrapper} $out/configWrapper
    '';
}
