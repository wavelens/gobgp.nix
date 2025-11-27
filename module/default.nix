/*
 * SPDX-FileCopyrightText: 2025 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

{ config, lib, pkgs, ... }@inputs: let
  cfg = config.services.gobgpd;
  generateToml = import ./generate-toml.nix inputs;
in {
  disabledModules = [ "services/networking/gobgpd.nix" ];
  imports = [
    ./config
    ./zebra.nix
  ];

  options.services.gobgpd = {
    enable = lib.mkEnableOption "Enable the GoBGP routing daemon.";
    configFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writers.writeTOML "gobgpd.conf" (generateToml cfg.config);
      readOnly = true;
      internal = true;
      description = "Path to an existing GoBGP configuration file. If set, this will override the 'config' option.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.gobgp ];
    users = {
      groups.gobgpd = { };
      users.gobgpd = {
        description = "GoBGP Daemon User";
        isSystemUser = true;
        group = "gobgpd";
      };
    };

    systemd.services.gobgpd = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "GoBGP Routing Daemon";
      serviceConfig = {
        Type = "notify";
        User = "gobgpd";
        Group = "gobgpd";
        ExecStartPre = "${pkgs.gobgpd}/bin/gobgpd -f ${cfg.configFile} -d";
        ExecStart = "${pkgs.gobgpd}/bin/gobgpd -f ${cfg.configFile} --sdnotify";
        ExecReload = "${pkgs.gobgpd}/bin/gobgpd -r";
        AmbientCapabilities = "cap_net_bind_service";
      };
    };
  };
}
