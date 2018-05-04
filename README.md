![nixcloud-container](logo/nixcloud.container.png)

# What is nixcloud-container?

`nixcloud-container` is a Nix based wrapper around LXC, mainly to manage unprivileged LXC containers within NixOS. The implementation shares the /nix/store between host and guest. 

`nixcloud-container` is inspired by [nixos-container](https://nixos.org/nixos/manual/#ch-containers) which are based on systemd-nspawn. We chose LXC over systemd-nspawn because of unprivileged users support among other security features. One day systemd-nspawn might be as good as LXC but until that day we'll support LXC.

# Requirements

It requires NixOS as OS and nixpkgs in version:

* 18.03 
* or newer

The systemd of the LXC guest requires a patch, so all software in the container requires to be deployed from source. We might bring the patch into https://github.com/nixos/systemd but after the release of `nixcloud-container`.

# nixcloud-container features

* Easy to install

    To set up your NixOS to run LXC-containers using `nixcloud-container` you simply have to set integrate 'nixcloud-containers' and configure it by adding `nixcloud.container.enable = true;`

* Shared /nix/store

    To speed up the generation of new containers the /nix/store is shared with the host.

* Dropping privileges

    This abstraction automatically configures your root user as well as LXC in a way that container will drop privileges and will be run with the user 100000+.

* Easy networking

    We support `hostonly` networking, so you can access the guest from the host and `internet` networking with IPv4 NAT and IPv6 via routable prefix.
        
# Installation

The easiest way to install `nixcloud-container` is by:

1. including the `nixcloud-webservices` repository https://github.com/nixcloud/nixcloud-webservices. Follow the README.md of `nixcloud-webservices` on how to include `nixcloud-webservices` into your configuration.nix.

2. After you added `nixcloud-webservices` you can add the following line to your configuration.nix and rebuild your system.

        nixcloud.container.enable = true;

    This will automatically prepare your users for unprivileged LXC containers. It will add a subGid and a subUid range for a `root` that will be used for the unprivileged container. It will also create two additional bridges for the container networks to be used.



## Commands

`nixcloud-container` uses LXC tools and Nix tools internaly. You can pass parameters from the nixcloud-container abstraction to those wrapped commands individually.

    nixcloud-container create <container-name> <config-path> [-n <nix parameters>] [-l <lxc parameters>]                                                                        
    nixcloud-container update <container-name> <config-path> [-n <nix parameters>] [-l <lxc parameters>]                                                                        
    nixcloud-container destroy <container-name> [-l <lxc parameters>]                                                                                                           

    nixcloud-container list-generations <container-name>                                                                                                                        
    nixcloud-container delete-generations <container-name> <generations>                                                                                                        
    nixcloud-container switch-generation <container-name> <generation id>                                                                                                       
    nixcloud-container rollback <container-name>                                                                                                                                

    nixcloud-container start <container-name> [-l <lxc parameters>]                                                                                                             
    nixcloud-container login <container-name> [-l <lxc parameters>]                                                                                                             
    nixcloud-container stop <container-name> [-l <lxc parameters>]                                                                                                              
    nixcloud-container terminate <container-name> [-l <lxc parameters>]                                                                                                         

    nixcloud-container list [-l <lxc parameters>]                                                                                                                               
    nixcloud-container show-ip <container-name>                                                                                                                                 
    nixcloud-container exists <container-name>                                                                                                                                  
    nixcloud-container state <container-name>                                                                                                                                   
    nixcloud-container help   


A more in detailed description can be found via `nixcloud-container help`.

# Examples on usage

## Creating a LXC container

1. First create a simple configuration `example.nix`:

    ```
    $ cat example.nix
    {pkgs, ip, name, ...}:
    {
      environment.systemPackages = [ pkgs.vim ];
    }
    ```
    This configuration creates a container with `vim` installed.

    **Note:** Run all following command(s) on the host as root!

2. to create a container with the above configuration:

    nixcloud-container create example example.nix

3. start the newly created container:

    nixcloud-container start example

4. log into the container:

    nixcloud-container login example

## Updating a LXC container

To update the container, simply run:

    nixcloud-container update example example.nix
    
**Note:** The container can either be stopped or running. If it was running during the update, it will change the state as it would with 'nixos-rebuild switch' on the host system.

## LXC container with custom nixpkgs

Creating a LXC container from scratch:

    nixcloud-container create test ./containerConfig.nix -n "-I nixpkgs=/nixpkgs"

Updating an existing LXC container:

    nixcloud-container update test ./containerConfig.nix -n "-I nixpkgs=/nixpkgs"

## Start an LXC container with shell

If you want to see the boot process in detail:

    nixcloud-container start test -l "-F"

## Starting LXC container(s) automatically

You can start/stop your containers manually. But if you want to start them after the host system has booted, you can add `autostart = true;` in your container configuration. Afterwards either update or create the container with that configuration.

    $ cat autostartExample.nix
    {
      autostart = true; # starts this container after host has booted

      configuration = {pkgs, ip, name, ...}:
      {
        services.openssh.enable = true;
        services.openssh.ports = [ 22 ];
        networking.hostName = "autostartExample";
        environment.systemPackages = [ pkgs.dfc pkgs.vim ];
      };
    }                                   

**Note:** This is implemented using a lxc-autostart.service systemd job which starts after `network.target` is reached.

## Host/Client implementation

The host system and the guest system can be modified using these files:

* The container is defined from [bin/helper/lxc-container.nix](bin/helper/lxc-container.nix)
* The host extension can be found in [./modules/virtualisation/container.nix](https://github.com/nixcloud/nixcloud-webservices/blob/master/modules/virtualisation/container.nix)

## Declarative vs. imperative container(s)

`nixcloud.container` as of now only supports stateful container management (no declarative interface). 

Our main use-case is to be able to rebuild individual deployments without having to run a global nixos-rebuild switch so these systems can fail individually without interference.

We might implement a declarative interface later on.

## LXC container networking

The following configuration generates a container with a separate bridge and a fixed IPv4 address.

**Note:** You can also use fixed IPv4 addresses with the standard bridge interface, but better don't mix interfaces with static and dynamically (automatically) generated IPv4 addresses.

`nixcloud-container` does not protect from collisions between automatically generated IPv4 addresses and static ones.

    $ cat networkExample.nix
    {
      network = {
        #replaces brNC with your own bridge
        bridge = "myOwnBridge";
        #sets an ip
        ip = "10.10.1.2";
        #disables the additional NAT interface (default)
        enableNat = false;
      };
      configuration = {pkgs, ip, name, ...}:
      {
        services.openssh.enable = true;
        services.openssh.ports = [ 22 ];
        networking.hostName = ip;
        users.extraUsers.root.openssh.authorizedKeys.keys = [ (builtins.readFile ./id_rsa.pub) ];
      };
    }

**Note:** The above container configuration needs a bridge setup in the host system, which can be done like this:

    networking.interfaces.myOwnBridge = {
      ipv4.addresses = [ { address = "10.10.0.1"; prefixLength = 16; } ];
      useDHCP = false;
    };

More example configurations can be found in the `/examples` folder.

# Networking
`nixcloud-container` creates two network interfaces for the communication with the containers: `brNC-hostonly` and `brNC-internet`.

## brNC-hostonly
This bridge is using the IPv4 network `10.101.0.0/16`. IPv4(s) are generated idiomatically by `nixcloud-container` and are fixed during the lifetime of the container.
As the name `brNC-hostonly` implies, this bridge is not forwarded to the internet (no NAT). Instead it is intended to be used for bringing webservices into the internet using `nixcloud.reverse-proxy` on the host.

By setting `network.bridge` in the container config, the container will no longer be connected to `brNC-hostonly` but instead to the new bridge specified. See also `networkExample.nix`.

## brNC-internet

If you want to have IPv4 NATed internet in the container, then:

1. Add this to your host configuration

        nixcloud.container = {
          enable = true;
          internetInterface = "enp0s3";
        };

2. Set `network.enableNat = true;` in the container config, then the container will be connected to the `brNC-internet` interface (default is false). Inside the container the interface will be called 'internet' and it will get an IPv4 address by `dhcpcd`.

    As said, by default containers are not connected to this bridge and there won't be a `internet` interface. 

3. If you want an IPv6 address for your container, then use the ipv6 attribute set as below:

        nixcloud.container = {
          enable = true;
          internetInterface = "enp0s3";
          ipv6 = {
            enable = true;
            ipv6InternetInterfaceAddress = "2a01:4f8:221:3744:4000::1";
            ipv6Prefix = "2a01:4f8:221:3744:4000::";
            ipv6PrefixLength = 66;
            ipv6NameServers = [ "2a01:4f8:0:1::add:1010" "2a01:4f8:0:1::add:9999" "2a01:4f8:0:1::add:9898" ];
          };
        };

**Note:** The `ipv6InternetInterfaceAddress` is assigned to the DHCPD6 interface and must be contained in the `ipv6Prefix` as DHCPD6 wouldn't work otherwise.
    
**Note:** You have to fill in your own IPv6 addresses, prefix and nameservers and make sure that the host can actually be reached so the subnet correctly arrives at the host. Use `ping -6 youripv6address` and `tcpdump enp0s3 ip6 -n` to verify.

# Security considerations

* Apparmor LXC profiles are currently not supported
* LXC Containers must be started on the host with the root user but they drop privileges to user 100000

    **Note:** Starting LXC containers as a non root user is currently not supported but would be nice to have but the most important thing is that this probably is not a security issue.

* The host and all LXC containers share the same /nix/store so every container can read the whole store. This is a problem for https://github.com/NixOS/nixpkgs/issues/24288 related services!
* The hostonly interface is shared among all containers, so using IPv4 each container can connect each other container!
* The NixOS firewall inside the LXC containers work and is configured but you might have to check if it suits your needs
* Currently there are no cgroup limitations on LXC containers or single processes, so you have to trust your users to not exceed the machine performance or implement them yourself

# Tests

The test implementation can be found in the [test.nix](test.nix) file.
