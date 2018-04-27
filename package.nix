{ pkgs, stdenv, makeWrapper, lxc, nix }:

stdenv.mkDerivation rec{
  name = "nixcloud-container-${version}";
  version = "0.0.1";

  nativeBuildInputs = [ makeWrapper ];

  buildCommand = ''
    mkdir -p $out/bin
    cp -r ${./bin}/* $out/bin

    # FIXME/HACK nixos-container should probably be run from a 'interactive shell' which already contains a valid
    #            NIX_PATH set (note: the NIX_PATH currently set points to a none-existing path, WTH?)
    #            or
    #            we should abstract over 'nix-channel' and for instance also push updates when they are avialbel ASAP
    wrapProgram $out/bin/nixcloud-container \
      --prefix PATH : "${stdenv.lib.makeBinPath [ lxc nix pkgs.eject ]}" # eject because of util-linux and flock
  '';
}
