/*
 * SPDX-FileCopyrightText: 2025 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

{ lib, ... }: let
  isList = validate: ((builtins.typeOf validate) == "list") && ((builtins.length validate) > 0) && (builtins.all (kv: (builtins.typeOf kv) == "set") validate);

  clearEmptyLists = let
    filterEmpty = lib.filterAttrs (k: kv: (kv != null) && (kv != [ ]) && (kv != { }));
  in attrs: filterEmpty (builtins.mapAttrs (n: v:
    if (builtins.typeOf v) == "set" then
      clearEmptyLists v
    else if isList v then
      builtins.filter (v: v != { }) (map clearEmptyLists v)
    else
      v
  ) attrs);

  insertConfigAttrs = builtins.mapAttrs (n: v_unknown: let
    validateToNull = validate: if (builtins.tryEval validate).success then validate else null;
    validateSetToNull = validate: builtins.mapAttrs (k: validateToNull) validate;
    v = validateSetToNull v_unknown;
    filterConfig = isSet: lib.filterAttrs (k: kv: ((builtins.typeOf kv) == "set") == isSet) v;
    filterSet = filterConfig true;
    filterNonSet = filterConfig false;
    filterConfigValues = builtins.attrValues (insertConfigAttrs filterSet);
    isListSet = isList (builtins.attrValues v);
    wrapNonSet = if builtins.any (kv: kv == "config") (builtins.attrNames filterNonSet) then
      { config = filterNonSet; }
    else
      filterNonSet;
  in
    if (builtins.typeOf v) != "set" then
      v
    else if !isListSet then
      wrapNonSet // (insertConfigAttrs filterSet)
    else
      filterConfigValues
  );
in attrs: clearEmptyLists (insertConfigAttrs attrs)
