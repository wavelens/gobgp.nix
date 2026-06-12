/*
 * SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: MIT
 */

{ pkgs, lib, ... }: let
  # global rib -a ipv4 add <PREFIX> [identifier <VALUE>] [origin { igp | egp | incomplete }] [aspath <ASPATH>] [nexthop <ADDRESS>] [med <NUM>] [local-pref <NUM>] [community <COMMUNITY>] [aigp metric <NUM>] [large-community <LARGE_COMMUNITY>] [aggregator <AGGREGATOR>]
  staticPathsValues = attrs: builtins.attrValues (lib.optionalAttrs (builtins.hasAttr "static-paths" attrs) attrs.static-paths);
  setStaticPathsAttribute = attrs: name: attrs-name: if (builtins.hasAttr attrs-name attrs) then
    "${name} ${toString attrs.${attrs-name}}"
  else
    "";

  containsColon = str: builtins.any (v: v == ":") (lib.stringToCharacters str);
  family = v: if (containsColon v.prefix) then "ipv6" else "ipv4";

  setStaticPathsAttributes = attrs: attrsMap: builtins.concatStringsSep " " (lib.filter (s: s != "") (lib.mapAttrsToList (k: kv: setStaticPathsAttribute attrs k kv) attrsMap));

  # gobgp global aggregate add <PREFIX> [flags]
  #     --policy string   policy name to filter contributing routes
  # -s, --summary-only    suppress more specific routes
  aggregateAddressesValues = attrs: builtins.attrValues (lib.optionalAttrs (builtins.hasAttr "aggregate-addresses" attrs) attrs.aggregate-addresses);

in attrs: (map (v: "${lib.getExe pkgs.gobgp} global rib -a ${family v} add ${v.prefix} ${setStaticPathsAttributes attrs {
  "identifier" = "identifier";
  "origin" = "origin";
  "aspath" = "aspath";
  "nexthop" = "nexthop";
  "med" = "med";
  "local-pref" = "local-pref";
  "community" = "community";
  "aigp-metric" = "aigp metric";
  "large-community" = "large-community";
  "aggregator" = "aggregator";
}}") (staticPathsValues attrs))
++ (map (v: let
  flags = lib.filter (s: s != "") [
    (lib.optionalString (builtins.hasAttr "policy" v) "--policy ${v.policy}")
    (lib.optionalString (builtins.hasAttr "summary-only" v && v."summary-only") "--summary-only")
  ];
in "${lib.getExe pkgs.gobgp} global aggregate add ${v.prefix} ${lib.concatStringsSep " " flags}") (aggregateAddressesValues attrs))
