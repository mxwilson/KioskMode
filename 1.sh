#!/bin/bash

#KioskMode - transform CentOS or Ubuntu into Internet kiosk. 
#copyright 2019 mwilson <http://github.com/mxwilson>

if [ -e "/etc/gdm/custom.conf" ] ; then 
	GDMFILE="/etc/gdm/custom.conf"
else 
	if [ -e "/etc/gdm3/custom.conf" ] ; then
		GDMFILE="/etc/gdm3/custom.conf"
	else
		echo "No /etc/gdm or /etc/gdm3 directories. Exiting."
		exit 1
	fi
fi

echo "My gdm file is $GDMFILE"

if [ -e "/etc/centos-release" ] ; then
	DISTRO="centos"
else
	DISTRO="ubuntu"
fi


while [ -z "$response" ] ; do
	read -p "Automatic login username (ie:kioskuser)?: " response
	
	if [ ! -z "$response" ] ; then
		usersearch=$(id $response &> /dev/null)

		if [ $? == 1 ] ; then
			echo "User $response does not exist."
			response="";
		else
			echo "OK using $response as automatic login user."
		fi
	fi
done

echo "Modifying and backing-up $GDMFILE"

cp -v "$GDMFILE" "$GDMFILE".$(date +%H%M-%d-%m-%Y).bak

if [ $? != 0 ] ; then 
	echo "Error: unable to modify custom.conf. Exiting."	
	exit 1
fi

outputfile=$( cat << EOF 
# GDM configuration storage
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$response
[security]
[xdmcp]
[chooser]
[debug]\n
EOF
)

printf "$outputfile" > $GDMFILE

if [ $? != 0 ] ; then 
	echo "Error: unable to modify custom.conf. Exiting."	
	exit 1
fi


#disable screensaver, adjust some power settings, remove desktop icons

#set -x
declare -a SETLIST

SETLIST=(
"gsettings set org.gnome.desktop.screensaver idle-activation-enabled false"
"gsettings set org.gnome.settings-daemon.plugins.power idle-dim false"
"gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0"
"gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0"
"gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing"
"gsettings set org.gnome.desktop.session idle-delay 0"
"gsettings set org.gnome.desktop.screensaver lock-enabled false"
"gsettings set org.gnome.nautilus.desktop home-icon-visible false"
"gsettings set org.gnome.nautilus.desktop network-icon-visible false"
"gsettings set org.gnome.nautilus.desktop trash-icon-visible false"
"gsettings set org.gnome.nautilus.desktop volumes-visible false"
	)
len=${#SETLIST[*]} 

if [ "$DISTRO" == "centos" ] ; then
	COMMAND1="sudo -u $response"
		
	for ((i=0; i<${len}; i++)); do
		FINALCOMMAND="$COMMAND1 ${SETLIST[$i]}"
	 	$FINALCOMMAND
	done
else
	for ((i=0; i<${len}; i++)); do
		FINALCOMMAND="${SETLIST[$i]}"
	 	$FINALCOMMAND
	done

fi

#set -x		
#{ set +x; } 2>/dev/null

#which browser
#.config/autostart/desktopfile
#custom.conf
#xdo?

echo "Done"
exit 0
