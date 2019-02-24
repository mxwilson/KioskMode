#!/bin/bash

#username="kioskuser"

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

#.config/autostart/desktopfile
#disable screensaver
#disable shutdown
#which browser
#custom.conf
#xdo?
echo "Done"
exit 0
