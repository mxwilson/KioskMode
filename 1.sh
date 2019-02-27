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

cp -v "$GDMFILE" "$GDMFILE".bak

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

#disable screensaver and some power settings
sudo -u $response gsettings set org.gnome.desktop.screensaver idle-activation-enabled false 
sudo -u $response gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
sudo -u $response gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
sudo -u $response gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
sudo -u $response gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
sudo -u $response gsettings set org.gnome.desktop.session idle-delay 0
sudo -u $response gsettings set org.gnome.desktop.screensaver lock-enabled false

#which browser
#.config/autostart/desktopfile
# ustom.conf
#xdo?

#which browser
#custom.conf
#xdotool

echo "Done"
exit 0
