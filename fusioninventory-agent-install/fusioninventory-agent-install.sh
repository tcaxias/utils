#!/bin/bash

# install fusioninventory agent in Arch given that AUR pkg didn't work at april 7 2016

cpan FusionInventory::Agent
[ -x /usr/local/bin/fusioninventory-agent ] || exit 1
echo 'server = https://support.ri.lan/plugins/fusioninventory' >> /usr/local/etc/fusioninventory/agent.cfg
sed -i -e 's|no-httpd = 0|no-httpd = 1|' /usr/local/etc/fusioninventory/agent.cfg

cat <<EOF >> /etc/systemd/system/fusioninventory-agent.service
[Unit]
Description=Fusion Inventory Agent
After=syslog.target

[Service]
ExecStart=/usr/local/bin/fusioninventory-agent

[Install]
WantedBy=multi-user.target
EOF

systemctl enable fusioninventory-agent
systemctl start fusioninventory-agent
