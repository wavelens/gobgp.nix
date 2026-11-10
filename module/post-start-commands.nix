/*
 * SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: MIT
 */

{ pkgs, lib, ... }: let
  optionValueIfEvaluatesOtherwiseFallback = fallback: value: let
    result = builtins.tryEval value;
  in if result.success then result.value else fallback;

  addressFamilyForCidrPrefix = prefix: if lib.hasInfix ":" prefix then "ipv6" else "ipv4";

  staticPathIdentifierCommandArguments = path: let
    identifier = optionValueIfEvaluatesOtherwiseFallback null path.identifier;
  in lib.optionals (identifier != null) [ "identifier" (toString identifier) ];

  staticPathBgpAttributesToGobgpArguments = path: lib.concatLists (lib.mapAttrsToList (name: render: let
    value = optionValueIfEvaluatesOtherwiseFallback null path.${name};
  in lib.optionals (value != null && value != [ ]) (render value)) {
    origin = value: [ "origin" value ];
    as-path = value: [ "aspath" (toString value) ];
    nexthop = value: [ "nexthop" value ];
    med = value: [ "med" (toString value) ];
    local-pref = value: [ "local-pref" (toString value) ];
    community = value: [ "community" (lib.concatStringsSep "," value) ];
    large-community = value: [ "large-community" (lib.concatStringsSep "," value) ];
    aigp-metric = value: [ "aigp" "metric" (toString value) ];
    aggregator = value: [ "aggregator" value ];
  });

in config: map (path: lib.escapeShellArgs (
  [ (lib.getExe pkgs.gobgp) "global" "rib" "-a" (addressFamilyForCidrPrefix path.prefix) "add" path.prefix ]
  # gobgp can only parse the identifier right after the prefix, before the path attributes.
  ++ staticPathIdentifierCommandArguments path
  ++ staticPathBgpAttributesToGobgpArguments path
)) (builtins.attrValues (config.static-paths or { }))
