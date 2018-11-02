{ super }:
let
    lib = super.stdenv.lib;
in
{
  systemd = if ((builtins.compareVersions super.systemd.version "239") == -1) then
    super.systemd.overrideAttrs (drv: {
    # https://github.com/lxc/lxc/issues/2226
    patches = if super.systemd ? patches then super.systemd.patches ++ [ ./8447.patch ]
      else [ ./8447.patch ];
  }) else super.systemd;
}
