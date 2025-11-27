/*
 * SPDX-FileCopyrightText: 2025 Wavelens GmbH <info@wavelens.io>
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

{ lib, config, ... }: let
  # cfg = config.services.gobgpd;
  # checkList = f: v: builtins.all f v;
  # checkPolicy = v: builtins.hasAttr v cfg.config.policy-definitions;
  # checkPeerGroup = v: builtins.hasAttr v cfg.config.peer-groups;

  ipRegex = rec {
    # ipv4 = "(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3}";
    # ipv4Cider = "${ipv4}/(3[0-2]|[12]?[0-9])";
    # ipv6 = "([0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}";
    # ipv6Cider = "${ipv6}/(12[0-8]|1[01][0-9]|[1-9]?[0-9])";

    # Temporary accept all regex until proper ones are found
    ipv4 = ".*";
    ipv4Cider = ".*";
    ipv6 = ".*";
    ipv6Cider = ".*";
  };

  ipType = let
    ipTypeMapped = builtins.mapAttrs (n: v: lib.types.strMatching "^${v}$") ipRegex;
  in {
    any = lib.types.oneOf [ ipTypeMapped.ipv4 ipTypeMapped.ipv6 ];
    anyCidr = lib.types.oneOf [ ipTypeMapped.ipv4Cider ipTypeMapped.ipv6Cider ];
  } // ipTypeMapped;

  opt = attrs: { options = attrs; };

  mkPrefixName = nameList: builtins.concatStringsSep "-" (builtins.filter (v: v != "") nameList);

  mkNameOption = name: description: lib.mkOption {
    inherit description;
    type = lib.types.str;
    default = name;
    internal = true;
    readOnly = true;
  };

  listTypeOf = inputType: description: lib.mkOption {
    inherit description;
    type = lib.types.attrsOf (lib.types.submodule inputType);
    default = { };
  };

  attrsTypeOf = inputType: description: lib.mkOption {
    inherit description;
    type = lib.types.submodule inputType;
    default = { };
  };

  nestedEnableType = enableOptionName: description: {
    ${enableOptionName} = lib.mkOption {
      inherit description;
      type = lib.types.bool;
    };
  };

  dummyType = lib.mkOption {
    type = lib.types.nullOr lib.types.bool;
    default = null;
    internal = true;
    readOnly = true;
    description = "Dummy option.";
  };

  routePolicyEnumType = lib.types.enum [ "accept-route" "reject-route" ];

  applyPolicyType = opt {
    config = dummyType;
    default-import-policy = lib.mkOption {
      type = routePolicyEnumType;
      description = "Default import policy.";
    };

    default-export-policy = lib.mkOption {
      type = routePolicyEnumType;
      description = "Default export policy.";
    };

    import-policy-list = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      # check = checkList checkPolicy;
      description = "List of import policies to apply.";
    };

    export-policy-list = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      # check = checkList checkPolicy;
      description = "List of export policies to apply.";
    };
  };

  globalType = opt {
    config = dummyType;
    as = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "AS number";
    };

    router-id = lib.mkOption {
      type = ipType.any;
      description = "Router ID (IPv4 or IPv6)";
    };

    local-address-list = lib.mkOption {
      type = lib.types.listOf ipType.any;
      description = "List of local addresses to bind to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port number for BGP sessions.";
    };

    apply-policy = attrsTypeOf applyPolicyType "Global apply policy settings.";
  };

  rpkiServerType = opt {
    config = dummyType;
    address = lib.mkOption {
      type = ipType.any;
      description = "RPKI server address (IPv4 or IPv6).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "RPKI server port.";
    };
  };

  bmpServerType = opt {
    config = dummyType;
    address = lib.mkOption {
      type = ipType.any;
      description = "BMP server address (IPv4 or IPv6).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "BMP server port.";
    };

    route-monitoring-policy = lib.mkOption {
      type = lib.types.enum [ "pre-policy" "post-policy" "local-rib" "all" ];
      description = "Route monitoring policy for BMP server.";
    };

    statistics-timeout = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Statistics timeout in seconds for BMP server.";
    };
  };

  vrfType = { name, ... }: (opt {
    config = dummyType;
    name = mkNameOption name "VRF Name.";

    id = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "VRF Identifier.";
    };

    rd = lib.mkOption {
      type = lib.types.str;
      description = "Route Distinguisher for the VRF.";
    };

    import-rt-list = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of import rt for the VRF.";
    };

    export-rt-list = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of export rt for the VRF.";
    };

    both-rt-list = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of both rt for the VRF.";
    };
  });

  mtrDumpType = opt {
    config = dummyType;
    dump-type = lib.mkOption {
      type = lib.types.str;
      description = "Type of MRT dump.";
    };

    file-name = lib.mkOption {
      type = lib.types.str;
      description = "File path for MRT dump.";
    };

    dump-interval = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Interval in seconds for MRT dump.";
    };
  };

  zebraType = opt {
    config = dummyType;
    enabled = lib.mkEnableOption "Enable Zebra integration.";
    software-name = lib.mkOption {
      type = lib.types.str;
      description = "Software name to present to Zebra.";
    };

    version = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Zebra protocol version.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      description = "Zebra connection URL.";
    };

    redistribute-route-type-list = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [
        "kernel"
        "directly-connected"
        "static"
        "rip"
        "ripng"
        "ospf"
        "ospf3"
        "isis"
        "bgp"
        "pim"
        "eigrp"
        "nhrp"
        "hsls"
        "olsr"
        "table"
        "ldp"
        "vnc"
        "vnc-direct"
        "vnc-rn"
        "bgp-direct"
        "bgp-direct-to-nve-groups"
        "babel"
        "sharp"
        "pbr"
        "bfd"
        "openfabric"
        "vrrp"
        "nhg"
        "srte"
      ]);
      default = [ ];
      description = "List of route types to redistribute into BGP.";
    };

    mpls-label-range-size = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Size of MPLS label range to request from Zebra.";
    };
  };

  neighborAsPathOptionType = opt {
    config = dummyType;
    allow-own-as = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Number of times to allow own AS in the AS path.";
    };

    replace-peer-as = lib.mkOption {
      type = lib.types.bool;
      description = "Replace peer AS number in the AS path.";
    };
  };

  neighborTimersType = opt {
    config = dummyType;
    connect-retry = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Connect retry time in seconds.";
    };

    hold-time = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Hold time in seconds.";
    };

    keepalive-interval = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Keepalive interval in seconds.";
    };
  };

  neighborTransportType = opt {
    config = dummyType;
    passive-mode = lib.mkOption {
      type = lib.types.bool;
      description = "Enable passive mode for the neighbor.";
    };

    local-address = lib.mkOption {
      type = ipType.any;
      description = "Local address to bind for the neighbor.";
    };

    remote-port = lib.mkOption {
      type = lib.types.port;
      description = "Remote port for the neighbor.";
    };
  };

  neighborEbgpMultihopType = opt {
    config = dummyType;
    enabled = lib.mkOption {
      type = lib.types.bool;
      description = "Enable eBGP multihop for the neighbor.";
    };

    multihop-ttl = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "TTL for eBGP multihop.";
    };
  };

  neighborRouteReflectorType = opt {
    config = dummyType;
    route-reflector-client = lib.mkOption {
      type = lib.types.bool;
      description = "Enable route reflector client for the neighbor.";
    };

    route-reflector-cluster-id = lib.mkOption {
      type = ipType.any;
      description = "Cluster ID for the route reflector.";
    };
  };

  neighborGracefulRestartType = opt {
    config = dummyType;
    enabled = lib.mkOption {
      type = lib.types.bool;
      description = "Enable graceful restart for the neighbor.";
    };

    notification-enabled = lib.mkOption {
      type = lib.types.bool;
      description = "Enable graceful restart notification for the neighbor.";
    };

    long-lived-enabled = lib.mkOption {
      type = lib.types.bool;
      description = "Enable long-lived graceful restart for the neighbor.";
    };

    restart-time = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Graceful restart time in seconds.";
    };
  };

  afiSafiPrefixLimitType = opt {
    config = dummyType;
    max-prefixes = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Maximum number of prefixes allowed.";
    };

    shutdown-threshold-pct = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Percentage threshold to trigger prefix limit action.";
    };
  };

  afiSafiLongLivedGracefulRestartType = opt {
    config = dummyType;
    enabled = lib.mkOption {
      type = lib.types.bool;
      description = "Enable Long-Lived Graceful Restart for the AFI-SAFI.";
    };

    restart-time = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Long-Lived Graceful Restart time in seconds.";
    };
  };

  addPathsType = opt {
    config = dummyType;
    send-max = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Maximum number of paths to send for the AFI-SAFI.";
    };

    receive = lib.mkOption {
      type = lib.types.bool;
      description = "Enable receiving multiple paths for the AFI-SAFI.";
    };
  };

  afiSafisTtlSecurityType = opt {
    config = dummyType;
    enabled = lib.mkOption {
      type = lib.types.bool;
      description = "Enable TTL Security for the AFI-SAFI.";
    };

    ttl-min = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Minimum TTL value to accept for the AFI-SAFI.";
    };
  };

  afiSafisType = { name, ... }: (opt {
    config = dummyType;
    afi-safi-name = lib.mkOption {
      type = lib.types.enum [
        "ipv4-unicast"
        "ipv6-unicast"
        "ipv4-labelled-unicast"
        "ipv6-labelled-unicast"
        "l3vpn-ipv4-unicast"
        "l3vpn-ipv6-unicast"
        "l2vpn-evpn"
        "l2vpn-vpls"
        "rtc"
        "ipv4-encap"
        "ipv6-encap"
        "ipv4-flowspec"
        "ipv6-flowspec"
        "ipv4-mup"
        "ipv6-mup"
        "opaque"
      ];
      default = name;
      description = "AFI-SAFI name.";
      readOnly = true;
      internal = true;
    };

    prefix-limit = attrsTypeOf afiSafiPrefixLimitType "Prefix limit settings for the AFI-SAFI.";
    mp-graceful-restart = nestedEnableType "enabled" "Enable MP Graceful Restart for the AFI-SAFI.";
    long-lived-graceful-restart = attrsTypeOf afiSafiLongLivedGracefulRestartType "Long-Lived Graceful Restart settings for the AFI-SAFI.";
    add-paths = attrsTypeOf addPathsType "Add-Paths settings for the AFI-SAFI.";
  });


  baseNeighborPeerGroupType = { name, ... }: (opt {
    peer-group-name = mkNameOption name "Peer Group Name.";
  });

  baseNeighborNeighborType = opt {
    peer-group = lib.mkOption {
      type = lib.types.str;
      # check = checkPeerGroup;
      description = "Peer group name for the neighbor.";
    };
  };

  baseNeighborType = specification: {
    imports = lib.optional (specification == "peer-group") baseNeighborPeerGroupType
    ++ lib.optional (specification == "neighbor") baseNeighborNeighborType;
    options = {
      config = dummyType;
      peer-as = lib.mkOption {
        type = lib.types.ints.unsigned;
        description = "Neighbor AS number.";
      };

      neighbor-address = lib.mkOption {
        type = ipType.any;
        description = "Neighbor IP address (IPv4 or IPv6).";
      };

      local-as = lib.mkOption {
        type = lib.types.ints.unsigned;
        description = "Local AS number for the neighbor.";
      };

      auth-password = lib.mkOption {
        type = lib.types.str;
        description = "Authentication password for the neighbor.";
      };

      remove-private-as = lib.mkOption {
        type = lib.types.str;
        description = "Remove private AS numbers from routes received from this neighbor.";
      };

      send-software-version = lib.mkOption {
        type = lib.types.bool;
        description = "Send software version to the neighbor.";
      };

      as-path-options = attrsTypeOf neighborAsPathOptionType "AS path options for the neighbor.";
      timer = attrsTypeOf neighborTimersType "Timer settings for the neighbor.";
      transport = attrsTypeOf neighborTransportType "Transport settings for the neighbor.";
      ebgp-multihop = attrsTypeOf neighborEbgpMultihopType "eBGP multihop settings for the neighbor.";
      route-reflector = attrsTypeOf neighborRouteReflectorType "Route reflector settings for the neighbor.";
      add-paths = attrsTypeOf addPathsType "Add-Paths settings for the neighbor.";
      graceful-restart = attrsTypeOf neighborGracefulRestartType "Graceful restart settings for the neighbor.";
      afi-safis = listTypeOf afiSafisType "AFI-SAFI configurations for the neighbor.";
      apply-policy = attrsTypeOf applyPolicyType "Apply policy settings for the neighbor.";
      route-server = nestedEnableType "route-server-client" "Enable Route Server Client for the AFI-SAFI.";
      ttl-security = attrsTypeOf afiSafisTtlSecurityType "TTL Security settings for the neighbor.";
    };
  };

  neighborType = baseNeighborType "neighbor";
  peerGroupType = baseNeighborType "peer-group";
  dynamicNeighborType = opt {
    config = dummyType;
    prefix = lib.mkOption {
      type = ipType.anyCidr;
      description = "Dynamic neighbor prefix (CIDR).";
    };

    peer-group = lib.mkOption {
      type = lib.types.str;
      # check = checkPeerGroup;
      description = "Peer group name for the dynamic neighbors.";
    };
  };

  definedSetsPrefixSetPrefixListType = opt {
    ip-prefix = lib.mkOption {
      type = ipType.anyCidr;
      description = "Prefix (CIDR) to include in the prefix set.";
    };

    masklength-range = lib.mkOption {
      type = lib.types.str;
      description = "Optional mask length range for the prefix.";
    };
  };

  definedSetsPrefixSetType = { name, ... }: (opt {
    prefix-set-name = mkNameOption name "Prefix Set Name.";
    prefix-list = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule definedSetsPrefixSetPrefixListType);
      description = "List of prefixes in the prefix set.";
      default = [ ];
    };
  });

  definedSetsNeighborSetType = { name, ... }: (opt {
    neighbor-set-name = mkNameOption name "Neighbor Set Name.";
    neighbor-info-list = lib.mkOption {
      type = lib.types.listOf ipType.anyCidr;
      description = "List of neighbor IP addresses or prefixes (CIDR).";
    };
  });

  definedSetsBgpDefinedSetsSetBaseType = prefixName: ({ name, ... }: (opt {
    "${mkPrefixName [ prefixName "set-name" ]}" = mkNameOption name "${prefixName} set name.";
    "${mkPrefixName [ prefixName "list" ]}" = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of BGP communities.";
    };
  }));

  definedSetsBgpDefinedSetsType = opt {
    dummy = dummyType;
    community-sets = listTypeOf (definedSetsBgpDefinedSetsSetBaseType "community") "BGP community sets.";
    large-community-sets = listTypeOf (definedSetsBgpDefinedSetsSetBaseType "large-community") "BGP large community sets.";
    ext-community-sets = listTypeOf (definedSetsBgpDefinedSetsSetBaseType "ext-community") "BGP extended community sets.";
    as-path-sets = listTypeOf (definedSetsBgpDefinedSetsSetBaseType "as-path") "BGP AS path sets.";
  };


  definedSetsType = opt {
    dummy = dummyType;
    prefix-sets = listTypeOf definedSetsPrefixSetType "Prefix sets.";
    neighbor-sets = listTypeOf definedSetsNeighborSetType "Neighbor sets.";
    bgp-defined-sets = attrsTypeOf definedSetsBgpDefinedSetsType "BGP defined sets.";
  };

  policyDefinitionStatmentActionsBgpActionsSetAsPathPrependType = opt {
    as = lib.mkOption {
      type = lib.types.oneOf [ lib.types.ints.unsigned lib.types.str ];
      description = "AS number to prepend or 'last-as' to use the last AS in the AS path.";
    };

    repeat-n = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "Number of times to prepend the AS.";
    };
  };

  policyDefinitionStatmentActionsBgpActionsSetCommunityMethodType = opt {
    communities-list = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of BGP communities.";
    };
  };

  policyDefinitionStatmentActionsBgpActionsBaseType = prefixName: (opt {
    options = lib.mkOption {
      type = lib.types.enum [ "add" "remove" "replace" ];
      description = "Set community options.";
    };

    ${mkPrefixName [ "set" prefixName "community-method" ]} = attrsTypeOf policyDefinitionStatmentActionsBgpActionsSetCommunityMethodType "Method to set the ${prefixName} community.";
  });

  policyDefinitionStatmentActionsBgpActionsType = opt {
    dummy = dummyType;
    set-community = attrsTypeOf (policyDefinitionStatmentActionsBgpActionsBaseType "") "Set community action.";
    set-ext-community = attrsTypeOf (policyDefinitionStatmentActionsBgpActionsBaseType "ext") "Set extended community action.";
    set-large-community = attrsTypeOf (policyDefinitionStatmentActionsBgpActionsBaseType "large") "Set large community action.";
    set-as-path-prepend = attrsTypeOf policyDefinitionStatmentActionsBgpActionsSetAsPathPrependType "Set AS path prepend action.";
  };

  policyDefinitionStatmentConditionsBgpConditionsMatchCommunitySetBaseType = prefixName: (opt {
    ${mkPrefixName [ prefixName "community-set" ]} = lib.mkOption {
      type = lib.types.str;
      description = "${prefixName} community set name to match.";
    };

    match-set-options = lib.mkOption {
      type = lib.types.enum [ "any" "all" "invert" ];
      description = "Match set options.";
    };
  });

  policyDefinitionStatmentConditionsBgpConditionsType = opt {
    match-community-set = attrsTypeOf (policyDefinitionStatmentConditionsBgpConditionsMatchCommunitySetBaseType "") "Community set to match.";
    match-large-community-set = attrsTypeOf (policyDefinitionStatmentConditionsBgpConditionsMatchCommunitySetBaseType "large") "Large community set to match.";
    match-ext-community-set = attrsTypeOf (policyDefinitionStatmentConditionsBgpConditionsMatchCommunitySetBaseType "ext") "Extended community set to match.";

    next-hop-in-list = lib.mkOption {
      type = lib.types.listOf ipType.any;
      default = [ ];
      description = "List of next-hop IP addresses to match.";
    };

    route-type = lib.mkOption {
      type = lib.types.enum [ "internal" "external" "local" ];
      description = "Route type to match.";
    };
  };

  policyDefinitionStatmentConditionsMatchNeighborSetType = opt {
    neighbor-set = lib.mkOption {
      type = lib.types.str;
      description = "Neighbor set name to match.";
    };

    match-set-options = lib.mkOption {
      type = lib.types.enum [ "any" "all" "invert" ];
      description = "Match set options.";
    };
  };

  policyDefinitionStatmentConditionsMatchPrefixSetType = opt {
    prefix-set = lib.mkOption {
      type = lib.types.str;
      description = "Prefix set name to match.";
    };

    match-set-options = lib.mkOption {
      type = lib.types.enum [ "any" "all" "invert" ];
      description = "Match set options.";
    };
  };

  policyDefinitionStatmentConditionsType = opt {
    dummy = dummyType;
    match-prefix-set = attrsTypeOf policyDefinitionStatmentConditionsMatchPrefixSetType "Prefix set to match.";
    match-neighbor-set = attrsTypeOf policyDefinitionStatmentConditionsMatchNeighborSetType "Neighbor set to match.";
    bgp-conditions = attrsTypeOf policyDefinitionStatmentConditionsBgpConditionsType "BGP specific conditions.";
  };

  policyDefinitionStatmentActionsType = opt {
    bgp-actions = attrsTypeOf policyDefinitionStatmentActionsBgpActionsType "BGP specific actions.";
    route-disposition = lib.mkOption {
      type = routePolicyEnumType;
      description = "Route disposition action.";
    };
  };

  policyDefinitionStatmentType = opt {
    dummy = dummyType;
    conditions = attrsTypeOf policyDefinitionStatmentConditionsType "Policy statement conditions.";
    actions = attrsTypeOf policyDefinitionStatmentActionsType "Policy statement actions.";
  };

  policyDefinitionType = { name, ... }: (opt {
    name = mkNameOption name "Policy definition name.";
    statements = listTypeOf policyDefinitionStatmentType "List of policy statements.";
  });

  configType = lib.types.submodule (opt {
    global = attrsTypeOf globalType "Global BGP configuration.";
    rpki-servers = listTypeOf rpkiServerType "RPKI servers to connect to.";
    bmp-servers = listTypeOf bmpServerType "BMP servers to connect to.";
    vrfs = listTypeOf vrfType "VRF configurations.";
    mtr-dump = listTypeOf mtrDumpType "MRT dump configurations.";
    zebra = attrsTypeOf zebraType "Zebra integration settings.";
    neighbors = listTypeOf neighborType "BGP neighbors.";
    peer-groups = listTypeOf peerGroupType "BGP peer groups.";
    dynamic-neighbors = listTypeOf dynamicNeighborType "Dynamic BGP neighbors.";
    defined-sets = attrsTypeOf definedSetsType "Defined sets for policies.";
    policy-definitions = listTypeOf policyDefinitionType "BGP policy definitions.";
  });
in configType
