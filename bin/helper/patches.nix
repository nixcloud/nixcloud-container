{ super }:
{
  systemd = super.systemd.overrideAttrs (drv: {
    # https://github.com/lxc/lxc/issues/2226
    patches = [ ./8447.patch ];
  });
}
