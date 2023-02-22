#! /bin/bash

verbose=False
upload=None
token=None

while getopts vu:t: flag
do
    case "${flag}" in
	v) verbose=True;;
	u) upload=${OPTARG};;
        t) token=${OPTARG};;
    esac
done


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
OFILE=$SCRIPT_DIR/qmi-info_$(cat /etc/salt/minion_id)_$(date +"%d-%m-%Y_%H-%M-%S_%3N").out.txt

echo "Working dir: $SCRIPT_DIR"
echo "Output file: $OFILE"

download_mtu_autodetect_if_not_exist_and_run () {
	if [ ! -f $SCRIPT_DIR/mtu_autodetect.sh ]; then
		wget -nv -c https://raw.githubusercontent.com/autopi-io/scripts/master/mtu_autodetect.sh -O $SCRIPT_DIR/mtu_autodetect.sh
	fi

	chmod +x $SCRIPT_DIR/mtu_autodetect.sh
	$SCRIPT_DIR/mtu_autodetect.sh my.autopi.io
}

datetime() {
	date +"%D %T.%3N"
}

# $1 - modname
# $2 - command
runmod () {
	echo "Running mod $1, with command $2"
	echo -e "\n---[ START $1 ]---[ $2 ]---[ $(datetime) ]---" >> $OFILE
	eval $2 >> $OFILE 2>&1
	echo -e "\n---[ END $1 ]---[ $(datetime) ]---\n" >> $OFILE
}


echo "---[ START SCRIPT ]---[ $(datetime) ]---" > $OFILE

runmod "ping google domain" "ping -c 1 -q google.com -I wwan0"
runmod "ping google ip" "ping -c 1 -q 8.8.8.8 -I wwan0"
runmod "ping autopi" "ping -c 1 -q my.autopi.io -I wwan0"

runmod "qmi-manager status" "qmi-manager status"
runmod "qmi-manager service status" "systemctl status qmi-manager"

runmod "firmware state" 'autopi modem.connection execute "AT#FWSWITCH?"'
runmod "enabled contexts" 'autopi modem.connection execute "AT+CGDCONT?"'
runmod "active context status" 'autopi modem.connection execute "AT+CGCONTRDP=1"'
runmod "signal strength" 'autopi qmi.signal_strength'

runmod "mtu autodetect" "download_mtu_autodetect_if_not_exist_and_run"

runmod "SPM sys_pins" "autopi spm.query sys_pins"
runmod "list devices" "ls /dev/tty* && ls /dev/cdc*"
runmod "USB devices" "lsusb"

runmod "qmi-manager.conf" "cat /etc/qmi-manager.conf"
runmod "qmi-network.conf" "cat /etc/qmi-network.conf"
runmod "qmi-sim.conf" "cat /etc/qmi-sim.conf"
runmod "grains" "cat /etc/salt/grains"

runmod "network interfaces" "ip addr show"

runmod "down->up" "echo ---[ STATUS systemctl stop qmi-manager ]--- && systemctl stop qmi-manager && echo '---[ STATUS qmi-manager down ]---' && qmi-manager down && echo '---[ STATUS qmi-manager up ]---' && qmi-manager up && echo '---[ STATUS qmi-manager down ]---' && qmi-manager down && echo ---[ STATUS systemctl start qmi-manager ]--- && systemctl start qmi-manager"
runmod "last logs" "cat /var/log/syslog | grep qmi-manager | tail -n 300 -"
runmod "dmesg logs" "dmesg | grep qmi-manager | tail -n 50 -"

echo "---[ END SCRIPT ]---[ $(datetime) ]---" >> $OFILE


upload_dropbox () {
	if [ $token == "None" ] ; then
		echo "Token required when uploading to dropbox"
	else
		echo $token
		autopi fileutil.upload $OFILE gzip=False service=dropbox token=$token
	fi
}



case $upload in
	dropbox) upload_dropbox;;
	None) ;;
	*) echo "Unsupported upload type: $upload";;
esac
