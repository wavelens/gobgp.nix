/*
 * SPDX-FileCopyrightText: 2025 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: GPL-3.0-only
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
