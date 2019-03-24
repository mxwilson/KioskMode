#!/bin/bash

#KioskMode.sh - transform CentOS or Ubuntu into Internet kiosk. 
#copyright 2019 mwilson <http://github.com/mxwilson>

echo "Welcome to KioskMode!" 

if [ "$EUID" -ne 0 ] ; then 
	echo "Must be run as sudo ${0}"
	echo "Exiting."
	exit 1
fi

#quick check on gnome
if [ ! -e "/usr/bin/gnome-shell" ] ; then
	echo "Gnome does not appear to be installed. Exiting."
	exit 1
fi

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
	cat /etc/os-release | head -n 1 | grep Ubuntu &> /dev/null

	if [ $? != 0 ] ; then 
		echo "Error: Ubuntu or CentOS not detected. Exiting."
		exit 1
	fi
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
		
	for ((i = 0; i < ${len}; i++)) ; do
		FINALCOMMAND="$COMMAND1 ${SETLIST[$i]}"
	 	set -x
		$FINALCOMMAND
		{ set +x; } 2>/dev/null
	done
else
	for ((i = 0; i < ${len}; i++)) ; do
		FINALCOMMAND="${SETLIST[$i]}"
		set -x
	 	$FINALCOMMAND
		{ set +x; } 2>/dev/null
	done
fi

#launch browser on boot
while [ -z "$browserq" ] ; do
	read -p "Launch Firefox automatically upon booting? (y/n): " browserq

	if [ ! -z "$browserq" ] ; then
		if [[ "$browserq" == "y" || "$browserq" == "yes" ]] ; then
			echo "OK let's use firefox."
			firefoxuse=1;
			default_url="https://radar.weather.gov/Conus/full_loop.php";
			#ask for URL
			read -p "URL for Firefox to visit (default) [$default_url]: " urlq
			urlq=${urlq:-$default_url}	
			echo "Using $urlq"
		else	
			echo "OK nevermind!"
			echo "Done"
			exit 0
		fi
	fi
done

outputfile_autostart_script=$( cat << EOF 
#!/bin/bash
firefox --url \"$urlq\" &
sleep 3;\n
EOF
)

outputfile_autostart_dotdesktop=$( cat << EOF 
[Desktop Entry]
Type=Application
Name=kiosk-autostart
Exec=/home/$response/browser-autostart.sh\n
EOF
)

MYSCRIPT="/home/$response/browser-autostart.sh"
MYDESKTOPFILE="/home/$response/.config/autostart/kiosk-autostart.desktop"

if [ "$firefoxuse" == "1" ] ; then
	printf "$outputfile_autostart_script" > $MYSCRIPT

	if [ $? != 0 ] ; then 
		echo "Error: unable to write $MYSCRIPT. Exiting."	
		exit 1
	fi

	echo "Placing script at: $MYSCRIPT"	
	chmod +x  $MYSCRIPT
	chown $response:$response $MYSCRIPT

	if [ ! -e "/home/$response/.config/autostart" ] ; then 
		mkdir -pv /home/$response/.config/autostart
	fi

	printf "$outputfile_autostart_dotdesktop" > $MYDESKTOPFILE

	if [ $? != 0 ] ; then 
		echo "Error: unable to write $MYDESKTOPFILE. Exiting."	
		exit 1
	fi

	echo "Placing desktop file at: $MYDESKTOPFILE"	
	chown $response:$response -R /home/$response/.config/autostart/

	#install xdo tool
	while [ -z "$xdoq" ] ; do
		read -p "Install \"xdotool\" to simulate \"F11\" key press (for fullscreen browser)? (y/n):" xdoq

		if [ ! -z "$xdoq" ] ; then
			if [[ "$xdoq" == "y" || "$xdoq" == "yes" ]] ; then
				if [ "$DISTRO" == "ubuntu" ] ; then
					apt install xdotool
				else
					yum -y install epel-release && rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
					yum -y install xdotool
				fi
			echo "xdotool key \"F11\"" >> $MYSCRIPT
			else	
				echo "OK nevermind!"
				break;
			fi
		fi
	done
fi

echo "KioskMode is installed."
echo "Done."
exit 0
