{lib}: let
  canonicalPrefix = "platform.jorisjonkers.dev";
  transitionPrefix = "personal-stack";

  boolLabel = name: {
    name = name;
    value = "true";
  };

  prefixedBoolLabels = prefix: kind: values:
    map (value: boolLabel "${prefix}/${kind}-${value}") values;

  optionalLabel = name: value:
    lib.optional (value != null && value != "") {
      inherit name value;
    };

  labelsFromList = labels: builtins.listToAttrs labels;
in rec {
  inherit canonicalPrefix transitionPrefix;

  mkRoleLabels = roles:
    labelsFromList (
      prefixedBoolLabels canonicalPrefix "role" roles
      ++ prefixedBoolLabels transitionPrefix "role" roles
    );

  mkCapabilityLabels = capabilities:
    labelsFromList (
      prefixedBoolLabels canonicalPrefix "capability" capabilities
      ++ prefixedBoolLabels transitionPrefix "capability" capabilities
    );

  mkGpuLabels = gpuVendors:
    labelsFromList (
      prefixedBoolLabels canonicalPrefix "gpu" gpuVendors
      ++ prefixedBoolLabels transitionPrefix "gpu" gpuVendors
    );

  mkNodeLabels = {
    nodeName ? null,
    site ? null,
    zone ? null,
    roles ? [],
    capabilities ? [],
    gpuVendors ? [],
    extraLabels ? {},
  }:
    labelsFromList (
      optionalLabel "${canonicalPrefix}/node" nodeName
      ++ optionalLabel "${transitionPrefix}/node" nodeName
      ++ optionalLabel "${canonicalPrefix}/site" site
      ++ optionalLabel "${transitionPrefix}/site" site
      ++ optionalLabel "topology.kubernetes.io/region" site
      ++ optionalLabel "topology.kubernetes.io/zone" zone
    )
    // mkRoleLabels roles
    // mkCapabilityLabels capabilities
    // mkGpuLabels gpuVendors
    // extraLabels;

  labelArgs = labels: lib.mapAttrsToList (name: value: "${name}=${value}") labels;
}
