ipmitool -I lan -U ADMIN -H 10.20.5.33 sensor thresh FAN3 lower 150 250 300

NF-A14 PWM (+/- 10%)
1500 RPM
300 RPM


ipmitool -I lan -U mniehe -H 10.20.5.33 sensor thresh FAN3 lcr 400

ipmitool -I lan -U mniehe -H 10.20.5.33 sensor get "FAN3"

ipmitool -I lan -U mniehe -H 10.20.5.33 sdr type temperature

ipmitool -I lan -U mniehe -H 10.20.5.33 raw 0x30 0x45 0x00




# https://forums.servethehome.com/index.php?threads%2Ffan-speed-control-on-supermicro-x12.35146%2F
ipmitool -I lan -U mniehe -H 10.20.5.33 raw 0x30 0x45 0x01 0x01
ipmitool -I lan -U mniehe -H 10.20.5.33 raw 0x30 0x70 0x66 0x01 0x00 0x2D
ipmitool -I lan -U mniehe -H 10.20.5.33 raw 0x30 0x70 0x66 0x01 0x01 0x2D



sudo ipmitool raw 0x30 0x70 0x66 0x01 0x00 0x2D
sudo ipmitool raw 0x30 0x70 0x66 0x01 0x01 0x2D