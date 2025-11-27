/*
 * SPDX-FileCopyrightText: 2025 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

{
  description = "gobgp nix module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    search = {
      url = "github:NuschtOS/search";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, search, ... }@inputs: flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs { inherit system; };
  in {
    packages = {
      search = search.packages.${system}.mkSearch {
        title = "GoBGP Modules Search";
        baseHref = "/gobgp.nix/";
        urlPrefix = "https://github.com/wavelens/gobgp.nix/blob/main/";
        modules = [
          self.nixosModules.default
          { _module.args = { inherit pkgs; }; }
        ];
      };
    };

    checks = import ./tests { inherit self inputs system pkgs; };
    apps = import ./tests {
      inherit self inputs system pkgs;
      interactive = true;
    };
  }) // {
    overlays = {
      gobgp = final: super: let
        version = "4.0.0";
        vendorHash = "sha256-y8nhrKQnTXfnDDyr/xZd5b9ccXaM85rd8RKHtoDBuwI=";
        src = final.fetchFromGitHub {
          owner = "osrg";
          repo = "gobgp";
          rev = "v4.0.0";
          sha256 = "sha256-hXpNNDGiiJ0m8TjZe4ZOFhwma7KG7bm5iud1F0lcRzg=";
        };

      in {
        gobgpd = super.gobgpd.overrideAttrs (old: { inherit src version vendorHash; });
        gobgp = super.gobgp.overrideAttrs (old: {
          inherit src version vendorHash;
          nativeBuildInputs = old.nativeBuildInputs ++ [ final.installShellFiles ];
          postInstall = let
            inherit (nixpkgs) lib;
          in (old.postInstall or "") + (lib.optionalString (final.stdenv.buildPlatform.canExecute final.stdenv.hostPlatform) ''
            installShellCompletion --cmd gobgp \
              --bash <($out/bin/gobgp completion bash) \
              --fish <($out/bin/gobgp completion fish) \
              --zsh <($out/bin/gobgp completion zsh)
          '');
        });
      };

      # issue: https://github.com/osrg/gobgp/issues/3251
      frr = final: super: {
        frr = super.frr.overrideAttrs (old: rec {
          version = "9.0.5";
          src = final.fetchFromGitHub {
            owner = "FRRouting";
            repo = "frr";
            rev = "frr-${version}";
            hash = "sha256-2Wi4LE7FIbodeSYKB0ZnXcjFkpOogsilNtshSNVp0kM=";
          };

          configureFlags = let
            inherit (nixpkgs) lib;
            isLocalstatedirFlag = lib.hasPrefix "--localstatedir=";
            isSysconfdirFlag = lib.hasPrefix "--sysconfdir=";
          in map (flag: if (isLocalstatedirFlag flag) then
              "--localstatedir=/var/run/frr"
            else if (isSysconfdirFlag flag) then
              "--sysconfdir=/etc/frr"
            else
              flag
          ) (old.configureFlags or [ ]);

          patches = (old.patches or [ ]) ++ [
            ./utils/frr.patch
          ];

          clippy-helper = old.clippy-helper.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./utils/frr.patch
            ];
          });
        });
      };
    };

    nixosModules = rec {
      gobgp = { config, lib, ... }: {
        imports = [ ./module ];
        nixpkgs.overlays = (lib.optional config.services.gobgpd.enable self.overlays.gobgp)
        ++ (lib.optional (config.services.gobgpd.enable && config.services.gobgpd.zebra) self.overlays.frr);
      };

      default = gobgp;
    };
  };
}
