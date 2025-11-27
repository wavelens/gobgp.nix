/*
 * SPDX-FileCopyrightText: 2025 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

{ pkgs, ... }:
{
  name = "bgp-simple";
  node.pkgsReadOnly = false;
  defaults = {
    networking.firewall.allowedTCPPorts = [ 179 ];
  };

  nodes = {
    a = {
      networking.interfaces.eth1 = {
        ipv4.addresses = [{
          address = "192.0.2.1";
          prefixLength = 30;
        }];

        ipv6.addresses = [{
          address = "2001:db8::1";
          prefixLength = 64;
        }];
      };

      services.frr = {
        bgpd.enable = true;
        config = ''
          ip route 198.51.100.0/25 reject
          ipv6 route 2001:db8:beef::/48 reject
          router bgp 64496
            no bgp ebgp-requires-policy
            no bgp default ipv4-unicast
            bgp router-id 192.0.2.1

            neighbor 192.0.2.2 remote-as 64497
            neighbor 2001:db8::2 remote-as 64497

            address-family ipv4 unicast
              network 198.51.100.0/25
              neighbor 192.0.2.2 activate
            exit-address-family

            address-family ipv6 unicast
              network 2001:db8:beef::/48
              neighbor 2001:db8::2 activate
            exit-address-family
        '';
      };
    };

    b = {
      environment.systemPackages = with pkgs; [ gobgp ];
      networking.interfaces = {
        eth1 = {
          ipv4.addresses = [{
            address = "192.0.2.2";
            prefixLength = 30;
          }];

          ipv6.addresses = [{
            address = "2001:db8::2";
            prefixLength = 64;
          }];
        };

        lo = {
          ipv4.routes = [{
            address = "203.0.113.0";
            prefixLength = 24;
          }];

          ipv6.routes = [{
            address = "2001:db8:dead::";
            prefixLength = 48;
          }];
        };
      };

      services.gobgpd = {
        enable = true;
        zebra = true;
        config = {
          global = {
            as = 64497;
            router-id = "192.0.2.2";
            apply-policy = {
              default-import-policy = "accept-route";
              export-policy-list = [ "policy0" ];
              default-export-policy = "reject-route";
            };
          };

          zebra.redistribute-route-type-list = [
            "kernel"
            "directly-connected"
            "static"
          ];

          neighbors = {
            "node-a-ipv4" = {
              neighbor-address = "192.0.2.1";
              peer-as = 64496;
              afi-safis.ipv4-unicast = { };
            };

            "node-a-ipv6" = {
              neighbor-address = "2001:db8::1";
              peer-as = 64496;
              afi-safis.ipv6-unicast = { };
            };
          };

          defined-sets.prefix-sets = {
            "ps0".prefix-list."default" = {
              ip-prefix = "203.0.113.0/24";
              masklength-range = "24..32";
            };

            "ps1".prefix-list."default" = {
              ip-prefix = "2001:db8:dead::/48";
              masklength-range = "48..64";
            };
          };

          policy-definitions."policy0".statements = {
            "0" = {
              actions.route-disposition = "accept-route";
              conditions.match-prefix-set = {
                prefix-set = "ps0";
                match-set-options = "any";
              };
            };

            "1" = {
              actions.route-disposition = "accept-route";
              conditions.match-prefix-set = {
                prefix-set = "ps1";
                match-set-options = "any";
              };
            };
          };
        };
      };
    };
  };

  testScript = ''
    start_all()

    a.wait_for_unit("network.target")
    b.wait_for_unit("network.target")

    a.wait_for_unit("frr.service")
    b.wait_for_unit("gobgpd.service")

    with subtest("ensure bgp sessions are established"):
      a.wait_until_succeeds("vtysh -c 'show bgp ipv4 summary' | grep '192.0.2.2.*1\\s*2\\s*N/A'")
      b.wait_until_succeeds("gobgp neighbor -a 'ipv4' | grep '192.0.2.1.*Establ.*|.*2.*1'")

      a.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep '2001:db8::2.*1\\s*2\\s*N/A'")
      b.wait_until_succeeds("gobgp neighbor -a 'ipv6' | grep '2001:db8::1.*Establ.*|.*2.*1'")

    with subtest("ensure routes have been installed in fib"):
      b.succeed("ip route show | grep 198.51.100.0/25")
      a.succeed("ip route show | grep 203.0.113.0/24")

      b.succeed("ip -6 route show | grep 2001:db8:beef::/48")
      a.succeed("ip -6 route show | grep 2001:db8:dead::/48")
  '';
}
