# nix/module.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ipmi-fan-control;

  # Service user and group
  serviceUser = "ipmi-fan-control";
  serviceGroup = "ipmi-fan-control";

  # Convert the Nix attribute set to TOML
  configFile = pkgs.writeTextFile {
    name = "ipmi-fan-control-config.toml";
    text = generators.toTOML {} cfg.settings;
    destination = "/etc/ipmi-fan-control.toml";
  };

  # Runtime dependencies
  runtimeDeps = with pkgs; [
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
          ipmi = {
            username = "ADMIN";
            password = "ADMIN";
            host = "localhost";
          };
          fans = [
            {
              id = 0;
              name = "CPU1";
              min_speed = 10;
              max_speed = 100;
            }
            {
              id = 1;
              name = "CPU2";
              min_speed = 10;
              max_speed = 100;
            }
          ];
          temperature_sensors = [
            {
              id = "CPU1";
              thresholds = [
                { temperature = 60; speed = 20; }
                { temperature = 70; speed = 50; }
                { temperature = 80; speed = 100; }
              ];
            }
          ];
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
    environment.systemPackages = [ cfg.package ];

    # Ensure the IPMI kernel modules are loaded
    boot.kernelModules = [ "ipmi_devintf" "ipmi_si" "ipmi_msghandler" ];

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
      extraGroups = [
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

    systemd.services.ipmi-fan-control = {
      description = "IPMI Fan Control Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

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

    environment.etc."ipmi-fan-control.toml" = {
      source = configFile;
      mode = "0600"; # Restrict access as it might contain credentials
      user = serviceUser;
      group = serviceGroup;
    };
  };
}
