{ lib, ... }:
{
  modeKeys' =
    mode:
    lib.mapAttrsToList (
      key:
      { action, ... }@attrs:
      {
        inherit mode action key;
        options = attrs.options or { };
      }
    );
  modeKeys = (
    mode:
    lib.mapAttrsToList (
      key:
      {
        action,
        options ? { },
      }:
      {
        inherit
          mode
          action
          key
          options
          ;
      }
    )
  );
}
