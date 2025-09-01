#!/usr/bin/bash

sudo cp ./systemd/battery-threshold.service /etc/systemd/system/battery-threshold.service
sudo cp ./scripts/battery-threshold-service.py /usr/local/sbin

sudo chmod 700 /usr/local/sbin/battery-threshold-service.py

sudo mkdir /etc/dbus-1/system.d

# 실제로 sudo로 실행하는 경우 SUDO_USER 변수에 원래 사용자 정보가 저장되어 있음
if [ "$SUDO_USER" ]; then
  current_user="$SUDO_USER"
else
  current_user=$(whoami)
fi

cat <<EOF | sudo tee /etc/dbus-1/system.d/battery-threshold.conf >/dev/null
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy user="$current_user">
    <allow own="org.minsoft1115.BatteryThreshold"/>
    <allow send_destination="org.minsoft1115.BatteryThreshold"/>
  </policy>

  <policy context="default">
    <deny send_destination="org.minsoft1115.BatteryThreshold"/>
    <deny own="org.minsoft1115.BatteryThreshold"/>
  </policy>
</busconfig>
EOF

echo "/etc/dbus-1/system.d/battery-threshold.conf has been created for user: $current_user"
