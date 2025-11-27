/*
 * SPDX-FileCopyrightText: 2025 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

{
  self,
  inputs,
  pkgs,
  interactive ? false,
  ...
}: let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;

  tests = lib.pipe ./. [
    builtins.readDir
    (lib.filterAttrs (name: type: type == "directory" && !lib.hasPrefix "_" name))
    builtins.attrNames
  ];
in builtins.listToAttrs (map (name: {
  inherit name;
  value = let
    test = import ./${name} {
      inherit inputs lib pkgs;
    };

    driver = pkgs.testers.runNixOSTest (
      lib.recursiveUpdate {
        defaults = {
          imports = [
            self.nixosModules.gobgp
            (nixpkgs + "/nixos/modules/profiles/minimal.nix")
            (nixpkgs + "/nixos/modules/profiles/perlless.nix")
          ];

          nix.enable = lib.mkDefault false;
          services.lvm.enable = lib.mkDefault false;
          security.sudo.enable = lib.mkDefault false;
        };

        interactive = {
          sshBackdoor.enable = true;
          nodes = lib.listToAttrs (
            map (name: {
              inherit name;
              value.virtualisation.graphics = false;
            }) (builtins.attrNames test.nodes)
          );
        };
      } test
    );
  in
    if interactive then {
      type = "app";
      program = "${driver.driverInteractive}/bin/nixos-test-driver";
      meta.description = test.name;
    } else
      driver;
}) tests)
