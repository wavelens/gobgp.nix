/*
 * SPDX-FileCopyrightText: 2025 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

{ lib, pkgs, config, ... }: let
  cfg = config.services.gobgpd;
in {
  options = {
    services.gobgpd.zebra = lib.mkEnableOption "Enable GoBGP Zebra integration for FRR.";
  };

  config = lib.mkIf (cfg.enable && cfg.zebra) {
    systemd.services = {
      frr.postStart = "${pkgs.acl}/bin/setfacl -m u:gobgpd:rwx /run/frr/zserv.api";
      gobgpd.after = [ "frr.service" ];
    };

    services = {
      frr.config = "!";
      gobgpd.config.zebra = {
        enabled = true;
        software-name = lib.mkDefault "frr${lib.versions.majorMinor pkgs.frr.version}";
        version = lib.mkDefault 6;
        url = lib.mkDefault "unix:/run/frr/zserv.api";
      };
    };
  };
}
