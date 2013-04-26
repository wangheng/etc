if ( -x /usr/bin/id ) then
    if ( "`/usr/bin/id -u`" > 100 ) then
        alias vi vim
    endif
endif
