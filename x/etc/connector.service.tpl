# For systemd, place this script in /lib/systemd/system/satconnect.service

[Unit]
Description=Banyan Satellite Connector
After=network.target network-online.target

[Service]
WorkingDirectory=/opt/banyan
Environment=BANYAN_DIR=/var/log/banyan
Environment=com_banyanops_app=banyan-platform
Environment=com_banyanops_servicename=connector
Environment=com_banyanops_servicetype=visibility
LimitNOFILE=65536

Type=simple
Restart=on-failure
ExecStart=/opt/banyan/connector
ExecStopPost=/opt/banyan/connector stop-net
StandardOutput=null
# StandardError=null
Nice=10

[Install]
WantedBy=multi-user.target
