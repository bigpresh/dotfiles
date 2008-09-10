
#  ___________________________________________________________
# /\                                                          \
# \_| David P's .profile                                      |
#   | Some commands and env vars to customise my Bash shell   |
#   | exactly the way I like it, with some useful tweaks etc  |
#   | and a custom prompt (PS1) which updates the xterm title |
#   | with where I am.  The same file can be copied to many   |
#   | machines, hence the machine-specific tweaks in it.      |
#   |   ______________________________________________________|_
#   \_/________________________________________________________/
#
# $Id$
#
# useful functions added:
#
# prependtitle(title)
# prepends a string to the xterm window title set by the prompt
#
# psmatch(regexp)
# show a list of processes matching the given regexp
# eg psmatch bash
#
# killmatching(regexp [,signal])
# kill all processes matching the given regexp sending the optional 
# signal (be careful what the regexp will match!)
#
# usage(file)
# show the space used by the given file or dir
#
# mcd(dir)
# create a directory and immediately change into it
###################################################################

# disable mail notifications
if [ -x /usr/bin/biff ]; then biff n; fi

# show at a glance how the box is performing as we log in
LOAD=`cat /proc/loadavg | cut -d ' ' -f 1,2,3`


# print pretty banner and loadavg etc only if we're 
# logging in with an xterm (doing it without checking 
# can be bad, it can fuck up sshfs / scp etc)
if [ "$TERM" == "xterm" ]; then
    if [ -f ~/banner ]; then cat ~/banner; fi;
    echo " $HOSTNAME : LOAD: $LOAD"
fi


# set some environment vars

# pick visual editor to use, in order of preference:
if [ -x /usr/bin/mcedit ]; then
    export VISUAL=/usr/bin/mcedit
elif [ -x nano ]; then
    export VISUAL=nano
elif [ -x /usr/bin/vim ]; then
    export VISUAL=/usr/bin/vim
fi

export GZIP="-9"
export GREP_OPTIONS='--binary-files=without-match'

# bash history settings:
export HISTCONTROL=ignoreboth
shopt -s histappend



# some useful command aliases
alias cdback='cd $OLDPWD'
alias cb='cd $OLDPWD'
alias hg="history | grep"
alias kilall="killall"

# self-update :)
alias updateprofile='scp davidp@supernova.preshweb.co.uk:.profile $HOME'


# machine-specific stuff:
case $(hostname --fqdn) in
    cyborg.uk2net.com)
        export CGI=/usr/local/apache_1.1/cgi-bin
        export cgi=/usr/local/apache_1.1/cgi-bin/
        export lib=/usr/local/uk2net/lib
        export log=/usr/local/uk2net/log
        export PERL5LIB=/usr/local/uk2net/log
        export PATH=/usr/local/openssh/bin:$PATH

        alias pw='grep dave /amail/admin/makeadmpwd.txt'
        alias golddb='mysql -h 83.170.64.3 -u superultra --password=peon superultra'
        alias maxmaildb='mysql -h 10.0.0.123 -u cymaxmail --password=wn2wmh maxmail'
        alias atmaildb='mysql -h 83.170.81.130 -u root --password=gerbil atmail'
    ;;
    alchemist.uk2.net)
        export PERL5LIB=/usr/local/uk2net/lib
    ;;
    shop1.uk2.net)
        export carts=/usr/local/apache/carts
    ;;
esac




# this can get set by the prependtitle() function
# and is prepended to the xterm window title
export PREPENDTITLE=''

########## custom functions: ###############################

# copy a file from one place to another, first doing a diff to show what the
# changes are, and using sudo if we don't have permission to overwrite the
# destination otherwise.
# Usage: deploy from to
function deploy() {
    if perl -I/usr/local/uk2net/lib -c $1 ; then
        echo "Compiled OK."
    else
        echo "It didn't compile!  Are you sure you want to deploy?"
        echo "Hit enter to deploy anyway, or interrupt to bail"
        read foo;
    fi

    # if the destination exists, do a diff (FIXME: this will fail if you
    # just give the destination directory, and there's a file of this name
    # in that directory)
    if [ -f $2 ]; then
        echo "Diffing against $2"
        diff -u $2 $1 | less
        echo "Happy with the diff?  Enter to deploy, interrupt to bail"
        read foo;
    fi

    if [ -w $2 ]; then
        cp -p $1 $2 && echo "Deployed $1 to $2"
    else
        sudo cp -p $1 $2 && echo "Deployed $1 to $2 (as root)"
    fi
}


# look for processes matching the given regexp
psmatch () {
    ps aux | grep -P "$1" | grep -v grep
}


function killmatching() {
    # will kill any process matching the given 
    # regexp (so be careful what the regexp
    # will match!!)
    # second param, if given, is the signal to
    # use.

    if [ "$1" = "" ]; then
        echo "Usage: killmatching <pattern> [<signal>]"
        echo "e.g. killmatching xterm"
        return
    fi

    if [ "$2" != '' ]
    then
        local SIG=$2
    else
        local SIG='TERM'
    fi
    ps ax -eo pid,comm | grep -P "$1" | grep -v grep | sed -r 's/^\s+//' \
        | cut -d ' ' -f 1 | xargs kill -s $SIG
}

function usage() {
    # return total disc space used by given file
    # or dir (including sub dirs + files)

    du -ch $1 | grep total
}


function mcd() {
    mkdir -p "$*" && cd "$*" && pwd
}



prependtitle() {
    # sets a string that will be prepended to the xterm
    # title by the prompt (PS1) command
    PREPENDTITLE={$1}:
    setprompt
}

setprompt() {
    # sets terminal title.  If given a title to use, it's appended
    # to the default prompt.

    local title="$1"

    case $TERM in
        
        screen)
            PROMPTSET='\[\033];${PREPENDTITLE} screen \u@\h:\w\007\]'
            ;;
        xterm*)
            PROMPTSET='\[\033];${PREPENDTITLE}\u@\h:\w\007\]'
            ;;
        *)
            PROMPTSET=''
            ;;
    esac

    # custom prompt:
    PS1="${PROMPTSET}[\u@\h:\w]\\$ "
}


# set the prompt:
setprompt


