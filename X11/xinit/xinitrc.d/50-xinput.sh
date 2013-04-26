#!/bin/bash
# Copyright (C) 1999-2004,2007-2011 Red Hat, Inc. All rights reserved. This
# copyrighted material is made available to anyone wishing to use, modify,
# copy, or redistribute it subject to the terms and conditions of the
# GNU General Public License version 2.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth
# Floor, Boston, MA  02110-1301  USA
#
# X Input method setup script

function log_init() {
    if [ ! -n "$DRY_RUN" ]; then
	if [ -f $HOME/.imsettings.log ]; then
	    mv $HOME/.imsettings.log $LOGFILE.bak
	fi
	[ -f $LOGFILE ] && mv $LOGFILE $LOGFILE.bak
	touch $LOGFILE
    fi
}

function log() {
    echo "$@" >> $LOGFILE
}

function is_dbus_enabled() {
    /usr/libexec/imsettings-check --check-dbus
    [ $? -eq 0 ]
}

function is_imsettings_enabled() {
    [ -z "$DISABLE_IMSETTINGS" ] && is_dbus_enabled
}

function check_imsettings_capability() {
    mod=$1
    /usr/libexec/imsettings-check --check-modules >/dev/null
    ret=$?
    if [ $ret -eq 0 ]; then
	/usr/libexec/imsettings-check --check-modulesettings -d | grep $mod >/dev/null
	ret=$?
    fi
    return $ret
}

function lookup_desktop() {
    ret=$(cat $1)
    case $ret in
	gnome*)
	    echo "gnome"
	    ;;
	kde*)
	    echo "kde"
	    ;;
	lxsession*)
	    echo "LXDE"
	    ;;
	mate*)
	    echo "mate"
	    ;;
	xfce*)
	    echo "xfce"
	    ;;
	*)
	    echo "unknown"
	    ;;
    esac
}

function get_desktop() {
    if [ -n "$GDMSESSION" ]; then
	GUESS_DESKTOP="\$GDMSESSION"
	echo "$GDMSESSION"
    elif [ -n "$DESKTOP_SESSION" ]; then
	GUESS_DESKTOP="\$DESKTOP_SESSION"
	if [ "$DESKTOP_SESSION" == "default" ]; then
	    if [ -x "$HOME/.xsession" ]; then
		GUESS_DESKTOP="$HOME/.xsession"
	    elif [ -x "$HOME/.Xclients" ]; then
		GUESS_DESKTOP="$HOME/.Xclients"
	    elif [ -f "/etc/sysconfig/desktop" ]; then
		GUESS_DESKTOP=" /etc/sysconfig/desktop"
		. /etc/sysconfig/desktop
		echo $DESKTOP
	    else
		echo "unknown"
	    fi
	else
	    echo "$DESKTOP_SESSION"
	fi
	[ "`echo \"$GUESS_DESKTOP\"|sed -e 's/\(.\).*/\1/'`" == "/" ] && lookup_desktop $GUESS_DESKTOP
    else
	echo "unknown"
    fi
}

function is_gtk_supported() {
    [ -n "$IMSETTINGS_DISABLE_DESKTOP_CHECK" ] && return 0
    case "$(get_desktop|tr '[A-Z]' '[a-z]')" in
	*gnome|openbox)
	    if check_imsettings_capability gconf || check_imsettings_capability gsettings; then
		return 0
	    fi
	    ;;
	lxde)
	    if check_imsettings_capability lxde; then
		return 0
	    fi
	    ;;
	mate)
	    if check_imsettings_capability mateconf; then
		return 0
	    fi
	    ;;
	xfce*)
	    if check_imsettings_capability xfce; then
		return 0
	    fi
	    ;;
	*)
	    ;;
    esac

    return 1
}

function is_qt_supported() {
    [ -n "$IMSETTINGS_DISABLE_DESKTOP_CHECK" ] && return 0
    case "$(get_desktop|tr '[A-Z]' '[a-z]')" in
	*)
	    if check_imsettings_capability qt; then
		return 0
	    fi
	    ;;
    esac

    return 1
}

function is_xim_supported() {
# XXX: Disable XIM support so far
#    [ -n "$IMSETTINGS_DISABLE_DESKTOP_CHECK" ] && return 0
#    if check_imsettings_capability xim; then
#	return 0
#    fi

    return 1
}

function setup_gtk_immodule() {
    if is_imsettings_enabled && is_gtk_supported; then
	# Ensure GTK_IM_MODULE is empty. otherwise GTK+ doesn't pick up immodule through XSETTINGS
	unset GTK_IM_MODULE
	export GTK_IM_MODULE
    else
	[ -n "$GTK_IM_MODULE" ] && export GTK_IM_MODULE
    fi
}

function setup_qt_immodule() {
    if is_imsettings_enabled && is_qt_supported; then
	# FIXME: Qt doesn't support XSETTINGS for immodule yet.
	#        We still need to go with the older way.
	[ -n "$QT_IM_MODULE" ] && export QT_IM_MODULE
    else
	[ -n "$QT_IM_MODULE" ] && export QT_IM_MODULE
    fi
}

function setup_xim() {
    if is_imsettings_enabled && is_xim_supported; then
	# setup XMODIFIERS
	XMODIFIERS="@im=imsettings"
	export XMODIFIERS
    else
	[ -z "$XMODIFIERS" -a -n "$XIM" ] && XMODIFIERS="@im=$XIM"
	[ -n "$XMODIFIERS" ] && export XMODIFIERS
    fi
}

function run_imsettings() {
    print_info
    if [ -n "$DRY_RUN" ]; then
	log "*** DRY RUN MODE: running IM through imsettings"
    else
	if [ -n "$IMSETTINGS_INTEGRATE_DESKTOP" -a "x$IMSETTINGS_INTEGRATE_DESKTOP" = "xno" ]; then
	    which imsettings-switch > /dev/null 2>&1 && LANG="$tmplang" imsettings-switch -n "$IMSETTINGS_MODULE" || :
	    # NOTE: We don't bring up imsettings-xim nor imsettings-applet here to support XIM.
	    #       imsettings-applet will starts through XDG autostart mechanism.
	    #       If the desktop doesn't support that, this function shouldn't be invoked.
	    #       but run_xim() instead.
	fi
    fi
}

function run_xim() {
    print_info
    if [ -n "$DRY_RUN" ]; then
	log "*** DRY RUN MODE: running IM without imsettings"
    else
	DISABLE_IMSETTINGS=true
	export DISABLE_IMSETTINGS

	# execute XIM_PROGRAM
	[ -n "$XIM_PROGRAM" ] && which "$XIM_PROGRAM" > /dev/null 2>&1 && LANG="$tmplang" "$XIM_PROGRAM" $XIM_ARGS > $LOGFILE 2>&1 &
    fi
}

function print_result() {
    $1
    if [ $? -eq 0 ]; then
	log yes
    else
	log no
    fi
}

function print_info() {
    log "imsettings information"
    log "=========================="
    log "XINPUTRC: $READ_XINPUTRC"
    if [ "x$READ_XINPUTRC" != "xN/A" ]; then
	log "`stat $READ_XINPUTRC|sed -e 's/\(.*\)/\t\1/g'`"
    fi
    log -n "Is DBus enabled: "
    print_result is_dbus_enabled
    log -n "Is imsettings enabled: "
    print_result is_imsettings_enabled
    log -n "Is GTK+ supported: "
    print_result is_gtk_supported
    log -n "Is Qt supported: "
    print_result is_qt_supported
    log "DESKTOP: $(get_desktop)"
    get_desktop > /dev/null
    log "GUESS_DESKTOP: $GUESS_DESKTOP"
    log "DISABLE_IMSETTINGS: $DISABLE_IMSETTINGS"
    log "IMSETTINGS_DISABLE_DESKTOP_CHECK: $IMSETTINGS_DISABLE_DESKTOP_CHECK"
    log "DBUS_SESSION_BUS_ADDRESS: $DBUS_SESSION_BUS_ADDRESS"
    log "GTK_IM_MODULE: $GTK_IM_MODULE"
    log "QT_IM_MODULE: $QT_IM_MODULE"
    log "XMODIFIERS: $XMODIFIERS"
    log "IMSETTINGS_MODULE: $IMSETTINGS_MODULE"
    log "IMSETTINGS_INTEGRATE_DESKTOP: $IMSETTINGS_INTEGRATE_DESKTOP"
    log ""
}

LOGDIR="${XDG_CACHE_HOME:-$HOME/.cache}/imsettings"
LOGFILE="$LOGDIR/log"
CONFIGDIR="${XDG_CONFIG_HOME:-$HOME/.config}/imsettings"
USER_XINPUTRC="$CONFIGDIR/xinputrc"
SYS_XINPUTRC="/etc/X11/xinit//xinputrc"
READ_XINPUTRC="N/A"

# Load up the user and system locale settings
oldterm=$TERM
unset TERM
if [ -r /etc/profile.d/lang.sh ]; then
    # for Fedora etc
    source /etc/profile.d/lang.sh
elif [ -r /etc/default/locale ]; then
    # for Debian
    source /etc/default/locale
elif [ -r /etc/env.d/02locale ]; then
    # for Gentoo
    source /etc/env.d/02locale
fi
[ -n "$oldterm" ] && export TERM=$oldterm

tmplang=${LC_CTYPE:-${LANG:-"en_US.UTF-8"}}

# unset env vars to be safe
unset AUXILIARY_PROGRAM AUXILIARY_ARGS GTK_IM_MODULE ICON IMSETTINGS_IGNORE_ME LONG_DESC NOT_RUN PREFERENCE_PROGRAM PREFERENCE_ARGS QT_IM_MODULE SHORT_DESC XIM XIM_PROGRAM XIM_ARGS XMODIFIERS

[ -z "$IMSETTINGS_DISABLE_USER_XINPUTRC" ] && IMSETTINGS_DISABLE_USER_XINPUTRC=no

# migrate old configuration file
[ ! -d $CONFIGDIR ] && mkdir -p $CONFIGDIR || :
[ -f "$HOME/.xinputrc" ] && mv $HOME/.xinputrc $CONFIGDIR/xinputrc
[ -f "$HOME/.xinputrc.bak" ] && mv $HOME/.xinputrc.bak $CONFIGDIR/xinputrc.bak

if [ -r "$USER_XINPUTRC" -a "x$IMSETTINGS_DISABLE_USER_XINPUTRC" = "xno" ]; then
    source "$USER_XINPUTRC"
    READ_XINPUTRC=$USER_XINPUTRC
    if [ ! -h "$USER_XINPUTRC" ]; then
	SHORT_DESC="User Specific"
    fi
elif [ -r "$SYS_XINPUTRC" ]; then
    # FIXME: This hardcoded list has to be gone in the future.
    # Locales that normally use input-method for native input
    _im_language_list="as bn gu hi ja kn ko mai ml mr ne or pa si ta te th ur vi zh"
    _sourced_xinputrc=0
    for i in $_im_language_list; do
        if echo $tmplang | grep -q -E "^$i"; then
            source "$SYS_XINPUTRC"
            READ_XINPUTRC=$SYS_XINPUTRC
            _sourced_xinputrc=1
            break
        fi
    done
    # Locales that usually use X locale compose
    # FIXME: which other locales should be included here?
    if [ $_sourced_xinputrc -eq 0 ]; then
        _xcompose_language_list="am_ET el_GR fi_FI pt_BR ru_RU"
        for i in $_xcompose_language_list; do
            if echo $tmplang | grep -q -E "^$i"; then
                source /etc/X11/xinit/xinput.d//xcompose.conf
                READ_XINPUTRC=/etc/X11/xinit/xinput.d//xcompose.conf
                _sourced_xinputrc=1
                break
            fi
        done
    fi
    if [ $_sourced_xinputrc -eq 0 ]; then
        # Read none.conf to set up properly for locales not listed the above.
        source /etc/X11/xinit/xinput.d//none.conf
        READ_XINPUTRC=/etc/X11/xinit/xinput.d//none.conf
    fi
fi

[ -z "$IMSETTINGS_INTEGRATE_DESKTOP" ] && IMSETTINGS_INTEGRATE_DESKTOP=yes
export IMSETTINGS_INTEGRATE_DESKTOP

[ -z "$XIM" ] && XIM=none

# start IM via imsettings
IMSETTINGS_MODULE=${SHORT_DESC:-${XIM}}
[ -z "$IMSETTINGS_MODULE" ] && IMSETTINGS_MODULE="none"
export IMSETTINGS_MODULE

##
log_init
setup_gtk_immodule
setup_qt_immodule
setup_xim

# NOTE: Please make sure the session bus is established before running this script.
if ! is_dbus_enabled; then
    log "***"
    log "*** No DBus session hasn't been established yet. giving up to deal with Input Method with imsettings."
    log "***"

    run_xim
elif ! is_imsettings_enabled; then
    log "***"
    log "*** imsettings is explicitly disabled."
    log "***"

    run_xim
else
    # Yes, we are in the dbus session
    run_imsettings
fi
