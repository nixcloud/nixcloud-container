{
  #starts this container automatically if the host ist started
  autostart = true;

  #system configuration for the server
  #ip is the ip for the container
  #name is the name of the container
  #those can be used even if not set above
  configuration = {pkgs, ip, name, ...}:
  {
    services.openssh.enable = true;
    services.openssh.ports = [ 22 ];
    networking.hostName = ip;
    environment.systemPackages = [ pkgs.dfc pkgs.vim ];
  };
}
