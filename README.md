# Scripts

## mtu_autodetect.sh

Automatically detect the largest MTU that propogates through the network to the specified URL/IP.

**Does not actually make the change!**


## gather_qmi_info.sh
Gathers QMI related information and outputs to file. Optionally uploads to dropbox when given -u and -t arguments.

## mtu_tracker.sh
Continuously pings a URL with an MTU <= 1500. Once a working ping is found, it's rechecked every 30 seconds. Once the connection is lost, gather_qmi_info.sh is run and a new working MTU value is searched for.

## mtu_tracker.sh
Service file for setting up the mtu_tracker as a service. Uses the hub specified in /boot/host.aliases file. Outputs logs to /var/log/mtu.log.

	cp mtu_tracker.service /etc/systemd/system/mtu_tracker.service
	systemctl daemon-reload
	systemctl enable mtu_tracker.service
	systemctl start mtu_tracker.service
