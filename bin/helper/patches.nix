{ super }:
{
  systemd = super.systemd.overrideAttrs (drv: {
    # https://github.com/lxc/lxc/issues/2226
    patches = if super.systemd ? patches then super.systemd.patches ++ [ ./8447.patch ]
      else [ ./8447.patch ];
  });
}
