# nix/module.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.ipmi-fan-control;

  # Service user and group
  serviceUser = "ipmi-fan-control";
  serviceGroup = "ipmi-fan-control";

  # Use pkgs.formats.toml to handle the conversion
  format = pkgs.formats.toml {};
  configFile = format.generate "ipmi-fan-control-config.toml" cfg.settings;

  # Runtime dependencies
  runtimeDeps = with pkgs;
    [
      freeipmi
    ]
    ++ optional cfg.enableSmartMonTools smartmontools
    ++ optional cfg.enableHdparm hdparm;

  # Path with all runtime dependencies
  runtimePath = lib.makeBinPath runtimeDeps;
in {
  options.services.ipmi-fan-control = {
    enable = mkEnableOption "IPMI fan control service";

    package = mkOption {
      type = types.package;
      default = pkgs.ipmi-fan-control;
      defaultText = literalExpression "pkgs.ipmi-fan-control";
      description = "The ipmi-fan-control package to use";
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Configuration for IPMI fan control";
      example = literalExpression ''
        {
          log_level = "info";
          zones = [
            {
              session = "default";
              ipmi_zones = [0 1];
              interval = 10;
              sources = [
                {
                  type = "ipmi";
                  sensor = "CPU Temp";
                }
              ];
              steps = [
                {
                  temp = 40;
                  dcycle = 40;
                }
                {
                  temp = 80;
                  dcycle = 100;
                }
              ];
            }
          ];
          sessions = {
            default = {
              type = "local";
            };
          };
        }
      '';
    };

    enableSmartMonTools = mkOption {
      type = types.bool;
      default = false;
      description = "Enable support for querying drive temperatures via smartmontools";
    };

    enableHdparm = mkOption {
      type = types.bool;
      default = false;
      description = "Enable support for querying Hitachi/HGST/WD drive temperatures while spun down";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    # Ensure the IPMI kernel modules are loaded
    boot.kernelModules = ["ipmi_devintf" "ipmi_si" "ipmi_msghandler"];

    # Create the necessary groups
    users.groups = {
      # Main service group
      "${serviceGroup}" = {};

      # Ensure ipmi group exists
      "ipmi" = {};

      # If smartmontools is enabled, ensure disk group exists
      "disk" = mkIf cfg.enableSmartMonTools {};
    };

    # Create the service user with appropriate groups
    users.users."${serviceUser}" = {
      isSystemUser = true;
      group = serviceGroup;
      description = "IPMI Fan Control service user";
      home = "/var/empty";
      extraGroups =
        [
          "ipmi"
        ]
        ++ optional cfg.enableSmartMonTools "disk"
        ++ optional cfg.enableHdparm "disk";
    };

    # Set up udev rules to ensure correct permissions for IPMI devices
    services.udev.extraRules = ''
      # Give the ipmi group access to the IPMI device
      KERNEL=="ipmi*", GROUP="ipmi", MODE="0660"
      KERNEL=="ipmidev/*", GROUP="ipmi", MODE="0660"
    '';

    environment.etc."ipmi-fan-control.toml" = {
      source = configFile;
      mode = "0600"; # Restrict access as it might contain credentials
      user = serviceUser;
      group = serviceGroup;
    };

    systemd.paths.ipmi-fan-control-config-watcher = {
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathChanged = "/etc/ipmi-fan-control.toml";
        Unit = "ipmi-fan-control.service";
      };
    };

    systemd.services.ipmi-fan-control = {
      description = "IPMI Fan Control Service";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      path = runtimeDeps;

      serviceConfig = {
        Type = "simple";
        User = serviceUser;
        Group = serviceGroup;
        ExecStart = "${cfg.package}/bin/ipmi-fan-control --config /etc/ipmi-fan-control.toml";
        Restart = "on-failure";
        RestartSec = "10s";
        # Ensure the binary can find all runtime dependencies
        Environment = "PATH=${runtimePath}:$PATH";
      };
    };
  };
}
