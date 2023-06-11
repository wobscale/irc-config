# This is a module which is based on this inspircd module:
# https://github.com/euank/nixek-overlay/blob/f5ab50942c6c6003062ce7587a2157e3ac78dd4c/modules/inspircd/default.nix
# This module effectively just takes a config of stuff we want to tweak for the
# wobscale irc server and then configures the aforementioned inspircd module
# appropriately for the wobscale network.

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.wobscale-irc;
  defaultMOTD = pkgs.writeText "default-motd" ''
    Welcome to the Wobscale IRC Network!
  '';
  defaultRules = pkgs.writeText "default-rules" ''
    Use of the Wobscale IRC Network is subject to the Wobscale Code of Conduct.
    https://wobscale.website/conduct.html
  '';
in
{
  options = {
    services.wobscale-irc = {
      enable = mkEnableOption "wobscale irc network via inspircd";

      server = mkOption {
        type = types.attrs;
        default = {
          description = "Wobscale IRC";
          network = "WobscaleIRC";
        };
        description = ''
          Server block, such as:
          {
            name = "foo.irc.wobscale.website";
            description = "Wobscale IRC";
            network = "WobscaleIRC";
          }
          Note: inspircd doesn't enforce that 'name' is the dns name of the
          server, but for this module, it _must_ be because it's used in an
          acme challenge.
        '';
      };

      extraDNSNames = mkOption {
        type = types.listOf types.str;
        default = [ "irc.wobscale.website" ];
        description = "extra DNS names in addition to server.name";
      };

      route53Environment = mkOption {
        type = types.path;
        description = ''
          Path to aws credentials used as a systemd EnvironmentFile for lego.
          see https://go-acme.github.io/lego/dns/route53/
          Example:
            pkgs.writeText "aws-dns-creds" ''''''
              AWS_ACCESS_KEY_ID=akidexample
              AWS_SECRET_ACCESS_KEY=secret
            ''''''
        '';
      };

      acmeEmail = mkOption {
        type = types.str;
        description = "ACME email address for your tls certs";
      };

      admin = mkOption {
        type = types.attrs;
        default = { };
        description = ''
          Admin block, such as:
          {
            name = "name";
            nick = "nick";
            email = "email";
          }
        '';
      };

      operbot = {
        nick = mkOption {
          type = types.str;
          description = "nickname to use for the ssl rehash bot";
        };
        password = mkOption {
          type = types.str;
          description = "oper password to use for the ssl rehash bot";
        };
      };

      diepass = mkOption {
        type = types.str;
        description = ''
          The sha256 hash of a password that may be used with /DIE and /RESTART.
          Opers still need the associated permission.
          Leaving blank _does not_ disable its use.
        '';
      };

      operClasses = mkOption {
        type = types.attrs;
        default = { };
        description = ''
          Oper classes, such as:
          {
            className = { commands = "CONNECT"; usermodes = "*"; };
            className2 = { ... };
          }
        '';
      };

      operTypes = mkOption {
        type = types.attrs;
        default = { };
        description = ''
          Oper types, such as:
          {
            typeName = { classes = "className className2"; vhost = "foo.irc.wobscale.website"; };
            ...
          }
        '';
      };
      opers = mkOption {
        type = types.attrs;
        default = { };
        description = ''
          Opers, such as:
          {
            operName = { hash = "sha256"; password = "123...567"; host="*@1.2.3.4/32" type="typeName"; };
            ...
          }
          Note, the operbot will automatically be created.
        '';
      };

      links = mkOption {
        type = types.attrs;
        default = { };
        description = ''
          Links, such as:
          {
            "foo.irc.wobscale.website" = {
              port = "7005";
              ssl = "gnutls";
              ipaddr = "$ip";
              allowmask = "$ip";
              sendpass = "$password";
              recvpass = "$password";
            };
          }
        '';
      };
      autoconnect = mkOption {
        type = types.str;
        default = "";
        description = ''
          List of link names to reconnect to, space separated.
        '';
      };

      ulines = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          List of servers to silently uline
        '';
      };

      motd = mkOption {
        type = types.path;
        default = defaultMOTD;
        description = "MOTD file";
      };

      rules = mkOption {
        type = types.path;
        default = defaultRules;
        description = "Rules file";
      };

      cloaksecret = mkOption {
        type = types.str;
        description = ''
          Secret for hostname cloaking. Should be the same for all servers.
        '';
      };

      dnsbls = mkOption {
        type = types.attrs;
        default = { };
        description = ''
          DNSBLs to use such as:
          {
            DroneBL = {
              type = "record";
              domain = "dnsbl.dronebl.org";
              action = "ZLINE";
              reason = "You are listed in DroneBL. Please email admin@wobscale.website and include this link: https://dronebl.org/lookup.do?ip=%ip%";
              duration = "72h";
              records="3,5,6,7,8,9,10,11,13,14,15,16,17";
            };
            Spamhaus = { ... };
          }
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.inspircd = {
      enable = true;
      # Wobscale's on inspircd2 for now, eventually we'll update
      package = pkgs.inspircd2;
      flags = ""; # --nopid doesn't exist on inspircd2
      logFile = "/var/log/inspircd/inspircd-startup.log";
      config = {
        server = [ cfg.server ];
        # meh, --nopid doesn't exist, we have to write it somewhere
        pid = [{ file = "/tmp/inspircd.pid"; }];
        admin = [ cfg.admin ];
        bind = [
          {
            port = "6697-7001,5999,8501,13001";
            type = "clients";
            ssl = "gnutls";
          }
          {
            port = "6665-6669,4080";
            type = "clients";
          }
          {
            port = "7005";
            type = "servers";
            ssl = "gnutls";
          }
        ];
        power = [{
          hash = "sha256";
          diepass = cfg.diepass;
          restartpass = cfg.diepass;
        }];

        connect = {
          main = {
            allow = "*";
            timeout = "10";
            pingfreq = "120";
            hardsendq = "1048576";
            softsendq = "81920";
            recvq = "81920";
            threshold = "9999";
            commandrate = "1000";
            fakelag = "off";
            localmax = "5000";
            globalmax = "5000";
            useident = "no";
            limit = "5000";
            modes = "+x";
          };
        };

        cidr = [{
          ipv4clone = "32";
          ipv6clone = "128";
        }];

        class = {
          Oper = {
            commands = "*";
            privs = "*";
            usermodes = "*";
            chanmodes = "*";
          };
          ServerLink = {
            commands = "CONNECT SQUIT MKPASSWD ALLTIME SWHOIS CLOSE JUMPSERVER LOCKSERV";
            usermodes = "*";
            chanmodes = "*";
            privs = "servers/auspex";
          };
          BanControl = {
            commands = "KILL GLINE KLINE ZLINE QLINE ELINE TLINE RLINE CHECK NICKLOCK SHUN CLONES CBAN";
            usermodes = "*";
            chanmodes = "*";
          };
          HostCloak = {
            commands = "SETHOST SETIDENT SETNAME CHGHOST CHGIDENT";
            usermodes = "*";
            chanmodes = "*";
            privs = "users/auspex";
          };
          OperBot = {
            commands = "REHASH";
          };
        } // cfg.operClasses;
        type = {
          Oper = {
            classes = "Oper";
            vhost = "irc.wobscale.website";
            modes = "+s +cCqQ";
          };
          Helper = {
            classes = "HostCloak";
            vhost = "helper.irc.wobscale.website";
          };
          Bot = {
            classes = "OperBot";
            vhost = "operbot.irc.wobscale.website";
          };
        } // cfg.operTypes;

        oper = {
          rehash = {
            hash = "sha256";
            password = builtins.hashString "sha256" cfg.operbot.password;
            host = "*@127.0.0.1";
            type = "Bot";
          };
        } // cfg.opers;

        link = cfg.links;
        autoconnect =
          if cfg.autoconnect != "" then [{
            period = "20";
            server = cfg.autoconnect;
          }] else [ ];

        files = [{
          motd = cfg.motd;
          rules = cfg.rules;
        }];

        uline = builtins.map (n: { server = n; silent = "yes"; }) cfg.ulines;

        channels = [{
          uses = "30";
          opers = "100";
        }];

        dns = [{ timeout = "3"; }];
        banlist = [{ chan = "*"; limit = "300"; }];

        options = [{
          prefixquit = "Quit: ";
          suffixquit = "";
          prefixpart = "&quot;";
          suffixpart = "&quot;";
          syntaxhints = "no";
          cyclehosts = "yes";
          cyclehostsfromuser = "yes";
          ircumsgprefix = "no";
          announcets = "yes";
          allowmismatch = "no";
          defaultbind = "auto";
          hostintopic = "no";
          pingwarning = "15";
          serverpingfreq = "60";
          defaultmodes = "nt";
          moronbanner = "You're banned, sorry...";
          exemptchanops = "nonick:v flood:o";
          invitebypassmodes = "yes";
          nosnoticestack = "no";
          welcomenotice = "yes";
        }];

        performance = [{
          netbuffersize = "10240";
          maxwho = "4096";
          somaxconn = "128";
          softlimit = "12800";
          quietbursts = "yes";
          nouserdns = "no";
        }];

        security = [{
          announceinvites = "dynamic";
          hidemodes = "eI";
          hideulines = "no";
          flatlinks = "no";
          hidewhois = "";
          hidebans = "no";
          hidekills = "";
          hidesplits = "no";
          maxtargets = "20";
          customversion = "0";
          operspywhois = "yes";
          restrictbannedusers = "yes";
          genericoper = "no";
          userstats = "Pu";
        }];

        limits = [{
          maxnick = "22";
          maxchan = "64";
          maxmodes = "20";
          maxident = "11";
          maxquit = "255";
          maxtopic = "307";
          maxkick = "255";
          maxgecos = "128";
          maxaway = "200";
        }];

        log = [{
          method = "file";
          type = "BANCACHE RESOLVER m_ssl_gnutls CONFIG m_operlog";
          level = "default";
          target = "/var/log/inspircd/inspircd.log";
        }];

        whowas = [{
          groupsize = "10";
          maxgroups = "100000";
          maxkeep = "3d";
        }];

        badnick = (
          builtins.map
            (n: { nick = n; reason = "Reserved for Service"; })
            [ "ChanServ" "NickServ" "OperServ" "MemoServ" ]
        );

        exception = [
          {
            host = "*@localhost";
            reason = "Opers hostname";
          }
          {
            host = "*@127.0.0.1";
            reason = "Opers hostname";
          }
        ];

        insane = [{ hostmasks = "no"; ipmasks = "no"; nickmasks = "no"; trigger = "51.1"; }];

        module =
          genAttrs [
            "m_md5.so"
            "m_sha256.so"
            "m_abbreviation.so"
            "m_alias.so"
            "m_banexception.so"
            "m_botmode.so"
            "m_cap.so"
            "m_cban.so"
            "m_censor.so"
            "m_chanfilter.so"
            "m_channames.so"
            "m_chanprotect.so"
            "m_autoop.so"
            "m_check.so"
            "m_chghost.so"
            "m_chgident.so"
            "m_chgname.so"
            "m_cloaking.so"
            "m_clones.so"
            "m_commonchans.so"
            "m_conn_umodes.so"
            "m_cycle.so"
            "m_customprefix.so"
            "m_denychans.so"
            "m_devoice.so"
            "m_devoice.so"
            "m_dnsbl.so"
            "m_exemptchanops.so"
            "m_filter.so"
            "m_globalload.so"
            "m_halfop.so"
            "m_hideoper.so"
            "m_inviteexception.so"
            "m_kicknorejoin.so"
            "m_knock.so"
            "m_namedmodes.so"
            "m_nicklock.so"
            "m_nokicks.so"
            "m_nonicks.so"
            "m_operlog.so"
            "m_opermodes.so"
            "m_passforward.so"
            "m_password_hash.so"
            "m_muteban.so"
            "m_regex_posix.so"
            "m_sajoin.so"
            "m_sakick.so"
            "m_samode.so"
            "m_sanick.so"
            "m_sapart.so"
            "m_saquit.so"
            "m_satopic.so"
            "m_services_account.so"
            "m_deaf.so"
            "m_svshold.so"
            "m_sethost.so"
            "m_ssl_gnutls.so"
            "m_sslinfo.so"
            "m_sslmodes.so"
            "m_timedbans.so"
            "m_tline.so"
            "m_uhnames.so"
            "m_uninvite.so"
            "m_vhost.so"
            "m_xline_db.so"
            "m_sasl.so"
            "m_redirect.so"
            "m_spanningtree.so"
            "m_permchannels.so"
            "m_channelban.so"
            "m_securelist.so"
          ]
            (key: { });

        # Module configuration
        chanfilter = [{ hidemask = "yes"; }];
        channames = [{ denyrange = "2,3,15,22,31"; allowrange = ""; }];
        chanprotect = [{
          noservices = "no";
          qprefix = "~";
          aprefix = "&amp;";
          deprotectself = "no";
          deprotectothers = "yes";
        }];
        cloak = [{
          mode = "full";
          key = cfg.cloaksecret;
          prefix = "no-";
        }];
        customprefix = {
          halfvoice = {
            letter = "V";
            prefix = "$";
            rank = "1";
            ranktoset = "0";
          };
        };
        filteropts = [{ engine = "posix"; }];
        passforward = [{
          nick = "NickServ";
          forwardmsg = "NOTICE $nick :*** Forwarding PASS to $nickrequired";
          cmd = "PRIVMSG $nickrequired :IDENTIFY $pass";
        }];
        securelist = [{ waittime = "60"; }];
        xlinedb = [{ filename = "/var/lib/inspircd/xline.db"; }];

        alias = [
          { text = "NICKSERV"; replace = "PRIVMSG NickServ :$2-"; requires = "NickServ"; uline = "yes"; }
          { text = "CHANSERV"; replace = "PRIVMSG ChanServ :$2-"; requires = "ChanServ"; uline = "yes"; }
          { text = "OPERSERV"; replace = "PRIVMSG OperServ :$2-"; requires = "OperServ"; uline = "yes"; operonly = "yes"; }
          { text = "BOTSERV"; replace = "PRIVMSG BotServ :$2-"; requires = "BotServ"; uline = "yes"; }
          { text = "HOSTSERV"; replace = "PRIVMSG HostServ :$2-"; requires = "HostServ"; uline = "yes"; }
          { text = "MEMOSERV"; replace = "PRIVMSG MemoServ :$2-"; requires = "MemoServ"; uline = "yes"; }
          { text = "NS"; replace = "PRIVMSG NickServ :$2-"; requires = "NickServ"; uline = "yes"; }
          { text = "CS"; replace = "PRIVMSG ChanServ :$2-"; requires = "ChanServ"; uline = "yes"; }
          { text = "OS"; replace = "PRIVMSG OperServ :$2-"; requires = "OperServ"; uline = "yes"; operonly = "yes"; }
          { text = "BS"; replace = "PRIVMSG BotServ :$2-"; requires = "BotServ"; uline = "yes"; }
          { text = "HS"; replace = "PRIVMSG HostServ :$2-"; requires = "HostServ"; uline = "yes"; }
          { text = "MS"; replace = "PRIVMSG MemoServ :$2-"; requires = "MemoServ"; uline = "yes"; }
        ];

        # TLS module configuration
        gnutls = [{
          certfile = "/var/lib/acme/${cfg.server.name}/full.pem";
          keyfile = "/var/lib/acme/${cfg.server.name}/key.pem";
          dhfile = config.security.dhparams.params.inspircd.path;
          dhbits = "2048";
          priority = "NORMAL:-MD5";
          hash = "sha1";
        }];

        dnsbl = cfg.dnsbls;
      };
    };
    systemd.tmpfiles.rules = [
      "d /var/log/inspircd 1750 inspircd root - -"
      "d /var/lib/inspircd 1750 inspircd root - -"
    ];
    security.dhparams = {
      enable = true;
      # Save some CPU cycles by not regenning when openssl changes
      stateful = true;
      params = {
        inspircd = { bits = 2048; };
      };
    };
    security.acme.acceptTerms = true;
    security.acme.certs."${cfg.server.name}" = {
      email = cfg.acmeEmail;
      extraDomains = genAttrs cfg.extraDNSNames (n: null);
      dnsProvider = "route53";
      credentialsFile = cfg.route53Environment;
      user = "inspircd";
      postRun = ''
        (
          echo "OPER rehash ${cfg.operbot.password}"
          sleep 10
          echo "REHASH -ssl"
          sleep 2
          echo "PRIVMSG ${cfg.admin.nick} :ssl rehashed"
          sleep 2
          echo "QUIT :#|"
        ) | ${pkgs.hashpipe}/bin/hashpipe -s 127.0.0.1 -n ${cfg.operbot.nick} -div
      '';
    };
  };
}
