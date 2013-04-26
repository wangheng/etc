#!/bin/bash

SERVERFILE=$SAVEDIR/chrony.servers.$interface

chrony_config() {
	rm -f $SERVERFILE
	if [ "$PEERNTP" != "no" ]; then
		for server in $new_ntp_servers; do
			echo "$server $NTPSERVERARGS" >> $SERVERFILE
		done
		/usr/libexec/chrony-helper is-running &&
			/usr/libexec/chrony-helper add-dhclient-servers &&
			/usr/libexec/chrony-helper remove-dhclient-servers || :
	fi
}

chrony_restore() {
	if [ -f $SERVERFILE ]; then
		rm -f $SERVERFILE
		/usr/libexec/chrony-helper is-running &&
			/usr/libexec/chrony-helper remove-dhclient-servers || :
	fi
}
