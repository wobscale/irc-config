{ config, pkgs, ... }:

let
  # The nixek overlay contains the inspircd and hashpipe packages, and the
  # inspircd nixos module
  nixek-overlay = import (builtins.fetchGit {
    url = "https://github.com/euank/nixek-overlay.git";
    # Bump the commit to a newer one if you like
    rev = "30beee8a2193030301f40d8a546fe6a0f2bed78e";
  });
  hashpipe-overlay = (self: super: {
    # Are we being hacked? Nope, the sha256 changed because nixek overlay uses
    # the 'nixos unstable' channel hash, but we're on 20.03
    # See https://github.com/NixOS/nixpkgs/issues/79975 for the upstream
    # discussion about it changing.
    # If you're on nixos unstable or the cargoSha256 complains, you can probably delete this.
    hashpipe = super.hashpipe.overrideAttrs (old: {
      cargoDeps = old.cargoDeps.overrideAttrs (_: {
        outputHash = "1swv1cyr06jag7ky6aj6ykbirnf0scvp5c5z3pviv08mdffnrras";
      });
    });
  });
  wobscale-irc-overlay = builtins.fetchGit {
    url = "https://github.com/wobscale/irc-config.git";
    ref = "refs/pull/12/head";
    rev = "1204d1e79075261c1eb29e6ca81f858b70fba82f";
  };
  # This probably shouldn't be necessary, but it's the way I coudl get a
  # reference to the module in that overlay.
  nixek = import <nixos> {
    overlays = [
      nixek-overlay
    ];
    config = {};
  };
in
{
  nixpkgs.overlays = [
    nixek-overlay
    hashpipe-overlay
  ];
  imports = [
    <nixpkgs/nixos/modules/virtualisation/amazon-image.nix>
    nixek.modules.inspircd
    "${wobscale-irc-overlay}/modules/wobscale-irc.nix"
  ];
  ec2.hvm = true;
  # Either disable the firewall, or let through every irc port.
  networking.firewall.enable = false;

  # This block configures everything to do with the server
  # Everything that needs to be filled in for a server is marked with XXX to
  # aid in grepping.
  # Note as well that 'modules/wobscale-irc.nix' contains documentation for
  # each option.
  services.wobscale-irc = {
    enable = true;
    server = {
      name = "XXX.irc.wobscale.website";
    };

    motd = pkgs.writeText "motd" ''
      XXX: motd
    '';

    extraDNSNames = [ "irc.wobscale.website" ];

    route53Environment = pkgs.writeText "acme-creds" ''
      AWS_ACCESS_KEY_ID=<XXX: required>
      AWS_SECRET_ACCESS_KEY=<XXX: required>
    '';

    acmeEmail = "XXX: required";

    operbot = {
      nick = "XXX: rehash bot name should be unique per server";
      password = "XXX: arbitrary string password";
    };

    admin = {
      name = "XXX";
      nick = "XXX";
      email = "XXX";
    };

    diepass = "<XXX: logn string password>";

    opers = {
      ek = {
        hash = "sha256";
        password = "XXX: your oper password hash";
        host = "*@localhost *@127.0.0.1 <XXX: probably fill in your ip too>";
        type = "Oper";
      };
    };

    links = {
      "XXX: upstream server" = {
        port = "7005";
        ssl = "gnutls";
        ipaddr = "XXX: upstream server iop";
        allowmask = "XXX: same as ipaddr";
        sendpass = "XXX: password configured in upstream server recvpass";
        recvpass = "XXX: password we give to the upstream server oper";
      };
      # And possibly more links depending on the server
    };

    autoconnect = "XXX: link name or names";

    cloaksecret = "XXX: same for all servers, but secret";

    dnsbls = {
      DroneBL = {
        type = "record";
        domain = "dnsbl.dronebl.org";
        action = "ZLINE";
        reason = "You are listed in DroneBL. Please email admin@wobscale.website and include this link: https://dronebl.org/lookup.do?ip=%ip%";
        duration = "72h";
        records = "3,5,6,7,8,9,10,11,13,14,15,16,17";
      };

      ## http://rbl.efnetrbl.org/
      ## Blacklist-type: record
      EFnet-RBL = {
        type = "record";
        domain = "rbl.efnetrbl.org";
        action = "ZLINE";
        reason = "You are listed in the EFnet RBL. Please email admin@wobscale.website and include this link: http://rbl.efnetrbl.org/?i=%ip%";
        duration = "72h";
        records = "1,2,3,5";
      };

      ## https://www.spamhaus.org/zen/
      Spamhaus = {
        type = "record";
        domain = "zen.spamhaus.org";
        action = "ZLINE";
        reason = "You are listed in the Spamhaus Blocklist. Please email admin@wobscale.website and include this link: https://www.spamhaus.org/query/ip/%ip%";
        duration = "6h";
        records = "2,3,9,4,5,6,7"; # SBL and CSS (2,3,9); XBL (4-7); no PBL
      };
    };
  };

  # harden openssh a little
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    extraConfig = ''
      # based on https://infosec.mozilla.org/guidelines/openssh.html
      # Password based logins are disabled - only public key based logins are allowed.
      AuthenticationMethods publickey
      # LogLevel VERBOSE logs user's key fingerprint on login. Needed to have a clear audit track of which key was using to log in.
      LogLevel VERBOSE
    '';
  };
  security.sudo.wheelNeedsPassword = false;

  # And add a regular user if you want
  users.users.foo = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # keys
    ];
  };

  environment.systemPackages = with pkgs; [ neovim htop ];
}
