/*
 * SPDX-FileCopyrightText: 2025 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

{ config, lib, pkgs, ... }@inputs: let
  cfg = config.services.gobgpd;
  generateToml = import ./generate-toml.nix inputs;
  postStartCommands = import ./post-start-commands.nix inputs;
  validateConfigFile = file: if cfg.validateConfig then
    pkgs.runCommand "validated-gobgp.conf" { } ''
      cat ${file} > gobgp.conf
      echo "Validating GoBGP configuration file: ${file}"
      ${lib.getExe cfg.package} -df gobgp.conf
      mv gobgp.conf $out
    ''
  else
    file;

in {
  disabledModules = [ "services/networking/gobgpd.nix" ];
  imports = [
    ./config
    ./zebra.nix
  ];

  options.services.gobgpd = {
    enable = lib.mkEnableOption "Enable the GoBGP routing daemon.";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gobgpd;
      description = "The GoBGP Daemon package to use.";
    };

    validateConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to validate the generated GoBGP configuration file before starting the daemon.";
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = validateConfigFile (pkgs.writers.writeTOML "gobgpd.conf" (generateToml cfg.config));
      # default = pkgs.writers.writeTOML "gobgpd.conf" (generateToml cfg.config);
      readOnly = true;
      internal = true;
      description = "Path to an existing GoBGP configuration file. If set, this will override the 'config' option.";
    };

    postStartCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = postStartCommands cfg.config;
      readOnly = true;
      internal = true;
      description = "A list of commands to run after the GoBGP daemon has started. These commands will be executed using 'gobgp' CLI tool.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optional (cfg.package == pkgs.gobgpd) pkgs.gobgp;
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
      postStart = builtins.concatStringsSep "\n" cfg.postStartCommands;
      serviceConfig = {
        Type = "notify";
        User = "gobgpd";
        Group = "gobgpd";
        ExecStartPre = "${lib.getExe cfg.package} -f ${cfg.configFile} -d";
        ExecStart = "${lib.getExe cfg.package} -f ${cfg.configFile} --sdnotify";
        ExecReload = "${lib.getExe cfg.package} -f ${cfg.configFile} -r";
        AmbientCapabilities = "cap_net_bind_service";
      };
    };
  };
}
