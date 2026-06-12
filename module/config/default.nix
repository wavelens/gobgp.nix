/*
 * SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: MIT
 */

{ lib, ... }@inputs: let
  configType = import ./types.nix inputs;
in {
  options.services.gobgpd = {
    config = lib.mkOption {
      type = configType;
      default = { };
    };
  };
}
