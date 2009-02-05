
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
#
# fuck/kilall are aliases to killall (why do I find that hard to type?)
###################################################################

# disable mail notifications
if [ -x /usr/bin/biff ]; then biff n; fi

# show at a glance how the box is performing as we log in
LOAD=`cat /proc/loadavg | cut -d ' ' -f 1,2,3`
PROCS=$(ps aux | wc -l)

# print pretty banner and loadavg etc only if we're 
# logging in with an xterm (doing it without checking 
# can be bad, it can fuck up sshfs / scp etc)
if [ "$TERM" == "xterm" ]; then
    if [ -f ~/banner ]; then cat ~/banner; fi;
    echo " $HOSTNAME : LOAD: $LOAD PROCS: $PROCS"

    if [ "$HOSTNAME" == "cyborg.uk2net.com" ]; then
        grep dave /amail/admin/makeadmpwd.txt;
    fi
fi


# set some environment vars

# pick visual editor to use, in order of preference:
if [ -x /usr/bin/vim ]; then
    export VISUAL=/usr/bin/vim
elif [ -x nano ]; then
    export VISUAL=nano
elif [ -x /usr/bin/mcedit ]; then
    export VISUAL=/usr/bin/mcedit
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
alias fuck="killall"

# self-update :)
alias updateprofile='wget -O ~/.profile http://www.preshweb.co.uk/downloads/profile'


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
	alias codemonkey='sudo -H -u codemonkey ssh-agent $SHELL'
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
    SOURCEPATH=$1
    DESTPATH=$2
    # This is an evil little incantation:
    FILENAME=${SOURCEPATH##*/}

    # If we were given the directory name to deploy the file to rather than
    # the full new path, we wouldn't be able to do the diff, so infer
    # the new path:
    if [ -d "$DESTPATH" ]; then
        DESTPATH="$DESTPATH/$FILENAME"
    fi

    DESTDIR=$(dirname $DESTPATH)
    if [ -d "$DESTDIR/.svn" ]; then
        echo "$DESTDIR is a Subversion checkout, refusing to deploy there."
        return
    fi

    # TODO: determine if it's actually a Perl script/module
    if perl -I/usr/local/uk2net/lib -c $SOURCEPATH ; then
        echo "Compiled OK."
    else
        echo "It didn't compile!  Are you sure you want to deploy?"
        echo "Hit enter to deploy anyway, or interrupt to bail"
        read foo;
    fi

    # if the destination exists, do a diff
    if [ -f $DESTPATH ]; then
        echo "Diffing against $DESTPATH"
        diff -u $DESTPATH $SOURCEPATH | less
        echo "Happy with the diff?  Enter to deploy, interrupt to bail"
        read foo;
    fi

    if [ -w $DESTPATH ]; then
        cp -p $SOURCEPATH $DESTPATH && echo "Deployed $SOURCEPATH to $DESTPATH"
    else
        sudo cp -p $SOURCEPATH $DESTPATH && echo \
            "Deployed $SOURCEPATH to $DESTPATH (as root)"
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


