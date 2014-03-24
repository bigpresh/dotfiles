
#  ___________________________________________________________
# /\                                                          \
# \_| David P's .profile                                      |
#   | Some commands and env vars to customise my Bash shell   |
#   | exactly the way I like it, with some useful tweaks etc  |
#   | and a custom prompt (PS1) which updates the xterm title |
#   | with where I am.  The same file can be copied to many   |
#   | machines, hence the machine-specific tweaks in it.      |
#   |                                                         |
#   | David Precious, http://www.preshweb.co.uk/              |
#   |   ______________________________________________________|_
#   \_/________________________________________________________/
# 
#
# Latest copy of this profile is on GitHub:
# https://github.com/bigpresh/dotfiles

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
#
# ci(files)
# Shorthand to commit; auto-detects whether it's Subversion or Git checkout and
# calls either git commit -v or my custom svncommit() function which prepares a
# commit message showing the diff as well (like git commit -v does), and
# automatically adds an "Impact:" line for PCI compliance where required.
#
# pastesshkey(username)
# Opens $VISUAL to paste in an SSH public key, then sets it up for the given
# user (appends it to /home/$username/.ssh/authorized_keys, setting permissions
# appropriately.
#
# sysinfo()
# Returns basic system specs (CPU, RAM, HDD space)
#
# sshpermsfix(username)
# Fixes up the permissions for a user's ~/.ssh/authorized_keys
#
###################################################################

# disable mail notifications
if [ -x /usr/bin/biff ]; then biff n; fi

# print pretty banner and loadavg etc only if we're 
# logging in with an xterm (doing it without checking 
# can be bad, it can fuck up sshfs / scp etc)
if [ "$TERM" == "xterm" ]; then
    if [ -f ~/banner ]; then cat ~/banner; fi;
    # show at a glance how the box is performing as we log in
    LOAD=$(cat /proc/loadavg | cut -d ' ' -f 1,2,3)
    PROCS=$(ps aux | wc -l)
    echo " $HOSTNAME : LOAD: $LOAD PROCS: $PROCS"
    echo '.profile : $Id$'

    # If we have fortune installed, show one (use boxes, if that's available)
    if [ $(which fortune) ]; then
        if [ $(which boxes) ]; then
            fortune | boxes -d shell
        else
            fortune
        fi
    fi
fi


# set some environment vars

# pick visual editor to use, in order of preference:
if [ -x /usr/bin/vim ]; then
    export VISUAL=/usr/bin/vim
elif [ -x /usr/bin/nano ]; then
    export VISUAL=/usr/bin/nano
elif [ -x /usr/bin/mcedit ]; then
    export VISUAL=/usr/bin/mcedit
fi

export GZIP="-9"
export GREP_OPTIONS='--binary-files=without-match'

# Some Bash-specific stuff
if [[ "$SHELL" = *bash* ]]; then
    # bash history settings:
    export HISTCONTROL=ignoreboth
    shopt -s histappend

    # Notice if the window size changed:
    shopt -s checkwinsize

    # Ignore .svn dirs when tab-completing:
    export FIGNORE=".svn"

    # If this box has bash-completion available, source it:
    if [[ -r '/etc/bash_completion' && ! -f "$HOME/.bash_completion_broken" ]]; then
        . /etc/bash_completion
    fi
fi

# some useful command aliases
alias cdback='cd $OLDPWD'
alias cb='cd $OLDPWD'
alias cd='cd -P'  # follow symlinks 
alias hg="history | grep"
alias kilall="killall"
alias fuck="killall"
alias svnci="svncommit"
alias ci="svncommit"
alias ss="svnstatus"
alias uk2do="todo.pl --group UK2"
alias cm="sudo su codemonkey"
alias cdlogs='cd /usr/local/uk2net/log/$(date +%Y/%b/%-d)'
alias cdchimeralogs='cd /var/log/chimera/$(date +%Y/%b/%-d)'

# Make the MySQL client tell me if I'm about to do something stupid, and have it
# show me warnings if it just did something stupid.
alias mysql="mysql --safe-updates --show-warnings --select_limit=9999999999999"

# If on a Debian box where ack is ack-grep, alias it:
if [ -x /usr/bin/ack-grep ]; then
    alias ack="/usr/bin/ack-grep"
fi



# A few variables for easy quick access to common paths (some of these may
# be overridden in the machine-specific stuff below)
export cgi=/usr/local/uk2net/cgi
export lib=/usr/local/uk2net/lib
export log=/usr/local/uk2net/log
export PERL5LIB=/usr/local/uk2net/lib
export PERL5OPT="-M5.010"
export PERL_CPANM_OPT="--sudo --mirror http://cpan.mirrors.uk2.net/"
export IMPALA_BOXES="buscemi clooney coen depardieu fleming knox rasputin vault"
export CHIMERA_BOXES="api1 api2 api3 gen db1 db2 lb1 lb2 eco"
export todaylogs="/usr/local/uk2net/log/$(date +%Y/%b/%-d)"

# machine-specific stuff:
case $(hostname --fqdn) in
    supernova.preshweb.co.uk)
        export MPD_HOST=supernova
    ;;
    alchemist.uk2.net)
        # Alchemist's mysql client doesn't support --safe-updates
        unalias mysql
    ;;
    *chimera.*)
        # Chimera boxes use perlbrew, so switch to the right perl
        export PERLBREW_ROOT=/opt/perlbrew
        source $PERLBREW_ROOT/etc/bashrc
        perlbrew switch 5.14.2
        export PERL5LIB=/usr/local/chimera/lib
        alias cdlogs='cd /var/log/chimera/$(date +%Y/%b/%-d)'
    ;;
esac


# this can get set by the prependtitle() function
# and is prepended to the xterm window title
export PREPENDTITLE=''


# Finally, look for machine-specific stuff in ~/.profile-local, and source it if
# it's there.
if [ -f "$HOME/.profile-local" ]; then
    source "$HOME/.profile-local";
fi

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
function psmatch () {
    ps aux | grep -E "$1" | grep -v grep
}


# kill any process matching the given regexp (so be careful what the regexp
# will match!!)
# second param, if given, is the signal to use.
function killmatching() {

    if [ "$1" = "" ]; then
        echo "Usage: killmatching <pattern> [<signal>]"
        echo "e.g. killmatching xterm"
        return
    fi

    if [ "$2" != '' ]; then
        local SIG=$2
    else
        local SIG='TERM'
    fi
    # Find all processes matching the regexp given, get the PIDs, and kill.
    ps aux | grep -E "$1" | grep -v grep \
        | awk '{print $2'} | sudo xargs kill -s $SIG
}

# return total disc space used by given file or dir (including subdirs + files)
function usage() {
    du -ch $1 | grep total
}

# Make a new directory, and immediately change in to it.
function mcd() {
    mkdir -p "$*" && cd "$*" && pwd
}

# self-update :)
function updateprofile() {
    echo "Fetching new copy of profile"
    wget -q -O ~/.profile http://www.preshweb.co.uk/downloads/profile && \
    echo "Sourcing updated profile" && \
    source ~/.profile && \
    echo ".profile updated".
}

# sets a string that will be prepended to the xterm title by the prompt (PS1)
prependtitle() {
    PREPENDTITLE={$1}:
    setprompt
}

# sets terminal title.  If given a title to use, it's appended to the
# default prompt.
setprompt() {
    local title="$1"
    local fullhost=`hostname -f`
    case $TERM in
        screen)
            PROMPTSET="\[\033];${PREPENDTITLE} screen \u@${fullhost}t:\w\007\]"
            ;;
        xterm*)
            PROMPTSET="\[\033];${PREPENDTITLE}\u@${fullhost}:\w\007\]"
            ;;
        *)
            PROMPTSET=''
            ;;
    esac

    # Coloured hostnames for certain boxes
    hostnamecolor=''
    case $(hostname -f) in
        # Staging boxes get yellow prompts
        *.staging.private.uk2.net|*.staging.chimera.uk2group.com)
            hostnamecolor=93
        ;;

        # Live boxes get a red prompt (Danger, Will Robinson!)
        *.private.uk2.net|*.us.chimera.uk2group.com)
            hostnamecolor=31
        ;;

        # My own dev VPSes get green prompts
        *.dave.dev.uk2.net)
            hostnamecolor=32
        ;;

        # Other developer's VPSes get brown prompts
        *.dev.uk2.net)
            hostnamecolor=33
        ;;

        # supernova gets teal:
        supernova.preshweb.co.uk)
            hostnamecolor=36
        ;;

        # Lyla gets purple
        lyla.preshweb.co.uk)
            hostnamecolor=35
        ;;
    esac

    if [ "$hostnamecolor" != "" ]; then
        prehost='\[\e[${hostnamecolor}m\]'
        posthost='\[\e[0m\]';
    fi                   

    # Now, for colorising the username:
    preuser=''
    postuser=''
    usercolor=''
    case "$USER" in
        root)
            usercolor="31"
        ;;
        codemonkey)
            usercolor="30;42"
        ;;
    esac
    if [ "$usercolor" != "" ]; then
        preuser='\[\e[${usercolor}m\]'
        postuser='\[\e[0m\]'
    fi
        
    # Set custom prompt: 
    PS1="${PROMPTSET}[${preuser}\u${postuser}@${prehost}\h${posthost}:\w]\\$ "
}


# set the prompt:
setprompt


# Do an svn commit, with diffs included in the commit message
svncommit() {

    # Firstly, take a look at the first argument, and see if the directory it's
    # in contains a .svn dir.  If not, it'll be me mistakenly using this command
    # for a Git repo - it may as well try to DWIM:
    if [[ ! -d "$( dirname $1 )/.svn" ]]; then
        git commit -v "$@"
        return
    fi

    # Start preparing the commit message which we'll then edit
    COMMITMSG=/tmp/$USER-commitmsg
    echo > $COMMITMSG

    # Add an Impact: line, if it's a UK2 box, possibly guessing at a suitable
    # value too
    if [[ "${HOSTNAME: -7}" == "uk2.net" ]]; then
        IMPACTVAL='1'

        # Guesses based on machine name in file paths, first:
        if [[ $* == *fleming* ]]; then
            IMPACTVAL="1 - staff-only admin script"
        fi
        if [[ $* == *phone-monitor* ]]; then
            IMPACTVAL="1 - staff-only phone reporting"
        fi
        if [[ $* == *nagios* ]]; then
            IMPACTVAL="1 - internal Nagios monitoring only"
        fi
        if [[ $* == *dev* ]]; then
            IMPACTVAL="1 - just internal dev tools"
        fi

        # TODO: find out why this stopped working.
        ## If the changes are whitespace-only, then the Impact: line can say so
        #if [[ $(svn diff -x -w "$@" ) != '' ]]; then
        #    IMPACTVAL="1 - whitespace changes only, and we don't do Python :)"
        #fi
        echo "Impact: $IMPACTVAL" >> $COMMITMSG
    fi


    echo "--This line, and those below, will be ignored--" >> $COMMITMSG
    echo "Cwd: $(pwd)" >> $COMMITMSG
    svn status "$@" >> $COMMITMSG
    echo >> $COMMITMSG

    # Now do a diff; work out stats on lines added/removed by looking at
    # the diff, add that info, then the diff itself
    svn diff "$@"   > /tmp/$USER-svndiff
    LINESADDED=$(  grep '^+[^+]' /tmp/$USER-svndiff | wc -l)
    LINESREMOVED=$(grep '^-[^-]' /tmp/$USER-svndiff | wc -l)
    echo "Added $LINESADDED lines, removed $LINESREMOVED lines" >> $COMMITMSG
    echo >> $COMMITMSG
    cat /tmp/$USER-svndiff >> $COMMITMSG
    echo >> $COMMITMSG

    ORIGMD5=$(md5sum $COMMITMSG)

     # Now, edit (and retry editing) until we're happy
    MESSAGEOK=0
    while [ $MESSAGEOK == "0" ]; do
        
        # TODO: make sure it's vim/vi before using -c
        $VISUAL -c 'startinsert' $COMMITMSG
        
        # Initially assume it's OK, then find out if not
        MESSAGEOK=1

        # Check the message was edited
        if [[ "$(md5sum $COMMITMSG)" == "$ORIGMD5" ]]; then
            echo "Commit message unchanged - try again or interrupt to abort"
            MESSAGEOK=0
            sleep 10
        fi

        # If we're on a UK2 box and forgot to add the stupid Impact: line for
        # PCI-compliance reasons, complain:
        if [[ "${HOSTNAME: -7}" == "uk2.net" ]] && 
           ! grep -q 'Impact:' $COMMITMSG ; then
           MESSAGEOK=0
           echo "You must supply an Impact: line in the commit message"
           echo "This is needed for UK2 PCI compliance."
           sleep 5
        fi
    done

    # When we get here, the message must be acceptable so commit:
    if svn commit "$@" -F $COMMITMSG ; then
        echo "Committed, removing message file $COMMITMSG"
        echo "Added $LINESADDED lines, removed $LINESREMOVED lines"
        rm $COMMITMSG
        rm /tmp/$USER-svndiff
    else
        echo "Commit failed, message left in $COMMITMSG"
        echo "Diff left in /tmp/$USER-svndiff"
    fi
}


# Safe SVN update; display a diff of what's about to happen first.
function up {
    echo "Showing diff..."
    svn diff -r BASE:HEAD "$@"
    echo
    echo "Differences above will be applied if you continue."
    echo "Enter to accept and update, interrupt to bail."
    read
    echo "OK, updating..."
    svn up "$@"
}

# SVN status without all the fucking externals
function svnstatus {
    svn status --ignore-externals "$@" | grep -v '^X'
}



# Handle SSH agent authentication socket changes for screen sessions

# If we have a ~/.ssh_auth_sock file, and SSH_AUTH_SOCK isn't set,
# source that file.  This allows new windows within an old screen session to
# continue to use SSH agent auth.
SSH_SOCK_FILE=$HOME/.ssh_auth_sock
function update_ssh_auth_sock() {

    if [[ -f $SSH_SOCK_FILE && ! -S "$SSH_AUTH_SOCK" ]]; then
        echo "Attempting to use SSH auth socket details from $SSH_SOCK_FILE"
        source $SSH_SOCK_FILE
        # Now make sure that the socket referred to still exists:
        if [ ! -S "$SSH_AUTH_SOCK" ]; then
            echo "Socket $SSH_AUTH_SOCK went away, deleting $SSH_SOCK_FILE"
            rm $SSH_SOCK_FILE;
            unset SSH_AUTH_SOCK;
        fi
    fi
}

# Automatically try to use the socket, if we can:
update_ssh_auth_sock



# If we have an SSH auth agent socket, write it to .ssh_auth_sock, then reattach
# a screen session.  update_ssh_auth_sock()  will use the .ssh_auth_sock file to set
# $SSH_AUTH_SOCK appropriately, allowing new sessions within the old screen
# session to use the new auth socket for key-based auth.
function screen_reattach {

    if [[ "$SSH_AUTH_SOCK" != "" ]]; then
        echo "Writing $SSH_SOCK_FILE pointing to SSH_AUTH_SOCK"
        echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > $SSH_SOCK_FILE
    fi

    # Now, re-attach a screen; if we had no arguments, just call screen with
    # sensible re-attaching defaults, otherwise, pass on the arguments
    # unmolested
    if [ "$*" == "" ]; then
        screen -dr
    else
        screen "$@"
    fi
}


# Quick way to find out about the basic hardware specs of a box
function sysinfo {
    # CPU info
    grep -m2 -E '(name|MHz)' /proc/cpuinfo
    echo -en 'num CPUs\t: ' && grep -c 'model name' /proc/cpuinfo
    
    # Total memory
    grep MemTotal /proc/meminfo

    # space used/remaining on real filesystems
    # (Get header from df output first, then all filesystems that are worth
    # seeing)
    df -mh | grep Filesystem
    df -mh | grep -E '/dev' | grep -Ev '(tmpfs|udev)'

    uptime
}


# Fix up the permissions on someone's ~/.ssh dir for key-based auth.
# Assumes user is in their own group (e.g. user bob, group bob)
function sshpermsfix {
    WHO=$1
    sudo chown -R $WHO:$WHO /home/$WHO/.ssh
    sudo chmod 700 /home/$WHO/.ssh
    sudo chmod 600 /home/$WHO/.ssh/authorized_keys
    echo "Fixed up ownership and permissions on /home/$WHO/.ssh"
}

# Add an SSH key for a user.  Fires up $VISUAL on a tmp file so you can paste in
# the key then replaces any newlines with a single space (where it wrapped
# because you forgot to disable wrapping, or copied it from an email), then 
# moves it into place, and uses sshpermsfix() to fix up permissions.
function pastesshkey {
    WHO=$1
    $VISUAL /tmp/sshkey-$WHO
    perl -pi -e 's/\s+/ /mg' /tmp/sshkey-$WHO
    sudo mkdir /home/$WHO/.ssh
    sudo tee -a /home/$WHO/.ssh/authorized_keys < /tmp/sshkey-$WHO 1>/dev/null
    rm /tmp/sshkey-$WHO
    echo "Pasted key added to /home/$WHO/.ssh/authorized_keys"
    sshpermsfix $WHO
}


# Convenient aliaes to SSH to UK2 boxes
function _connect_box_type() {
    type=$1
    name=$2
    fullhostname=''

    if [ "$type" = ""  -o "$name" = "" ]; then
        echo "Usage: (live|staging|uat|dev) boxname"
    fi

    if [[ $IMPALA_BOXES = *$name* ]]; then
        case $type in
            live)
                fullhostname="$name.uk2.net"
            ;;
            staging)
                fullhostname="$name.staging.uk2.net"
            ;;
            dev)
                fullhostname="$name.dave.dev.uk2.net"
            ;;
        esac
    elif [[ "$CHIMERA_BOXES chimera" = *$name* ]]; then
        location=$3
        if [ $type = "live" -a "$location" = "" ]; then
            # This defaulting will be a little less useful when the UK live
            # env is in use; at that point, I might make specifying the location
            # required.
            echo "No Chimera location supplied, defaulting to US"
            location="us"
        fi
        case $type in
            live)
                fullhostname="$name.$location.chimera.uk2group.com"
            ;;
            staging)
                fullhostname="$name.staging.chimera.uk2group.com"
            ;;
            uat)
                fullhostname="$name.uat.chimera.uk2group.com"
            ;;
            dev)
                fullhostname="chimera.dave.dev.uk2.net"
            ;;
        esac
    else
        echo "No idea what box you're talking about."
        return
    fi
    echo "Connecting to $fullhostname..."
    ssh $fullhostname
}
function live()    {
    _connect_box_type 'live'    $* 
}
function staging() { 
    _connect_box_type 'staging' $*
}
function dev()     { 
    _connect_box_type 'dev'     $*
}
function uat()     { 
    _connect_box_type 'uat'     $*
}

# TODO: retire this
function uschimeralive {
    echo "Say 'live $1 us' now instead"
    ssh $1.us.chimera.uk2group.com;
}



# with auto-complete for box names:
complete -W "$IMPALA_BOXES $CHIMERA_BOXES" live
complete -W "$IMPALA_BOXES $CHIMERA_BOXES" staging
complete -W "$IMPALA_BOXES $CHIMERA_BOXES chimera" dev
complete -W "$CHIMERA_BOXES" uschimeralive
complete -W "$CHIMERA_BOXES" uat


# Quick & dirty Chimera API backend deployment
function chimeradeployapi {
    CHIMERAENV=$1
    BRANCH=$2

    if [ "$CHIMERAENV" == "staging" ]; then
        echo "Deploying to staging boxes"
        HOSTSUFFIX="staging.chimera.uk2group.com"
    elif [ "$CHIMERAENV" == "uat" ]; then
        echo "Deploying to UAT boxes"
        HOSTSUFFIX="uat.chimera.uk2group.com"
    elif [ "$CHIMERAENV" == "us" ]; then
        echo "Deploying to $CHIMERAENV live platform"
        HOSTSUFFIX="$CHIMERAENV.chimera.uk2group.com"
    else
        echo "Usage: chimeradeployapi staging|uat|us [branch]"
        return
    fi

    if [ "$BRANCH" == "" ]; then
        BRANCHSWITCH="no branch change"
    else
        BRANCHSWITCH="changing to branch $BRANCH"
    fi
    MSG="$USER beginning deployment to $CHIMERAENV environment ($BRANCHSWITCH)"
    wget -O /dev/null "http://irc.uk2.net:6500/?channel=devs|cpdevs|qa&message=$MSG"

    for box in api1 api2 api3 gen; do
        echo "$box.$HOSTSUFFIX..."
        echo -e "\tgit pull..."
        ssh $box.$HOSTSUFFIX \
            "cd /usr/local/chimera && sudo -u codemonkey bash -li -c 'git pull'"
        if [ "$BRANCH" != "" ]; then
            echo -e "\tSwitch to $BRANCH..."
            ssh $box.$HOSTSUFFIX \
                "cd /usr/local/chimera && sudo -u codemonkey bash -li -c 'git checkout $BRANCH'"
            echo -e "\tgit pull again..."
            ssh $box.$HOSTSUFFIX \
                "cd /usr/local/chimera && sudo -u codemonkey bash -li -c 'git pull'"
        fi
        if [ "$box" != "gen" ]; then
            echo -e "\tRestart app..."
            ssh $box.$HOSTSUFFIX "sudo /etc/init.d/dancer restart"
            echo -e "\tKill domain_lookup..."
            ssh $box.$HOSTSUFFIX "sudo pkill -f domain_lookup"
        fi
        echo "Deployment to $box.$HOSTSUFFIX complete."
    done

    # Now check whether we need DB updates:
    DB_TEST="prove /usr/local/chimera/t/database_structure.t > /dev/null 2>&1"
    if ssh -q -t gen.$HOSTSUFFIX "/bin/bash -l -c '$DB_TEST'" >/dev/null ; then
        echo "No DB update required"
    else 
        echo "*****************************************"
        echo "***** DB schema update required *********"
        echo "*****************************************"
    fi

    echo "Deployment complete."

    MSG="$USER deployed to $CHIMERAENV environment ($BRANCHSWITCH)"
    wget -q -O /dev/null "http://irc.uk2.net:6500/?channel=devs|cpdevs|qa&message=$MSG"
}



# Run a command on all boxes in a given Chimera environmentt
function chimerarun {
    CHIMERAENV=$1
    COMMAND=${*:2} # All params from 2nd onwards

    if [ "$CHIMERAENV" == "staging" ]; then
        echo "Running '$COMMAND' on staging boxes"
        HOSTSUFFIX="staging.chimera.uk2group.com"
    elif [ "$CHIMERAENV" == "uat" ]; then
        echo "Running '$COMMAND' on UAT boxes"
        HOSTSUFFIX="uat.chimera.uk2group.com"
    elif [ "$CHIMERAENV" == "us" ]; then
        echo "Running '$COMMAND' on $CHIMERAENV live platform"
        HOSTSUFFIX="$CHIMERAENV.chimera.uk2group.com"
    else
        echo "Usage: chimerarun staging|us|uat command"
        return
    fi

    for box in api1 api2 api3 gen; do
        echo "$box.$HOSTSUFFIX..."
        ssh -t $box.$HOSTSUFFIX "/bin/bash -l -c '$COMMAND'"
    done
}

# Quick & dirty Chimera API log greppage.
# First arg is pattern to grep for
# Second (optional) arg is appended to /var/log/chimera
# e.g. 'foo', '2012/Aug/*/*'
function uschimeragreplogs {
    PATTERN=$1
    FILES=$2

    # A bit of DWIMery RE: Filespec:
    case "$FILES" in
    "")  # No FILES spec, then wild card everything
        FILES=*/*/*/*
        ;;
 
    */*) # A path was supplied. so let it alone.
        ;;
 
    *)   # If a bare filename was specified, prepend "today" dir structure.
        FILES=`date "+%Y/%b/%-d"`/$FILES
        ;;
    esac

    FILES="/var/log/chimera/$FILES"
    for boxnum in $(seq 1 3); do
        echo "Grepping for $PATTERN in $FILES on api$boxnum..."
        ssh api$boxnum.us.chimera.uk2group.com \
            "~/dotfiles/chimeraloggrep '$PATTERN' $FILES"
    done
}

# Quick perl module version
function perlmodversion {
    MODNAME=$1;
    perl -M$MODNAME -e "say qq{$MODNAME = \$$MODNAME::VERSION};" 2>/dev/null
    if [ $? != 0 ]; then
        echo "$MODNAME not installed (or failed to find/load it)"
    fi
}

