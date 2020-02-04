
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
# The whole dotfiles repo should be checked out at ~/dotfiles, then symlink
# ~/.profile (or ~/.bashrc ) to ~/dotfiles/profile, and same for whatever
# other config files you want to apply to that box.
# The `updateprofile` command can be used to update from the repo.

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



# pick visual editor to use, in order of preference:
if [ -x /usr/bin/vim ]; then
    export VISUAL=/usr/bin/vim
    export EDITOR=/usr/bin/vim
elif [ -x /usr/bin/nano ]; then
    export VISUAL=/usr/bin/nano
    export EDITOR=/usr/bin/nano
elif [ -x /usr/bin/mcedit ]; then
    export VISUAL=/usr/bin/mcedit
    export EDITOR=/usr/bin/mcedit
fi

export GZIP="-9"

if [ -x "/bin/grep" ]; then
    alias grep="/bin/grep --binary-files=without-match"
fi


# Some Bash-specific stuff
if [[ "$SHELL" = *bash* ]]; then
    # bash history settings:
    export HISTCONTROL=ignoreboth
    export HISTSIZE=1000
    export HISTFILESIZE=10000
    shopt -s histappend

    # Automatically update the history file immediately, so
    # different sessions don't clobber each other's history.
    # TODO: this *might* cause some latency, disable if so
    if [[ ! "$PROMPT_COMMAND" =~ "history" ]]; then
        export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
    fi

    # Notice if the window size changed:
    shopt -s checkwinsize

    # Disable session suspend/resume
    if [[ "$TERM" != "" ]]; then
        stty -ixon
    fi

    # Ignore .svn dirs when tab-completing:
    export FIGNORE=".svn"

    # If this box has bash-completion available, source it:
    if [[ -r '/etc/bash_completion' && ! -f "$HOME/.bash_completion_broken" ]]; then
        . /etc/bash_completion
    fi
fi

# If we have an environment-specific profile symlinked into a private repo for
# stuff specific to an environment which can't be publicly released, let it
# do its stuff now
if [ -f ~/.profile-env ]; then
    echo "Sourcing ~/.profile-env for env-specific tweaks"
    . ~/.profile-env
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
alias 'gl'='git log --name-status'
alias gd='git diff'
alias ss="svnstatus"
alias cm="sudo su codemonkey"
alias tailf='less +F'

# Make the MySQL client tell me if I'm about to do something stupid, have it
# show me warnings if it just did something stupid, and automatically use
# vertical output if the result would be too wide to display sensibly.
alias mysql="mysql --safe-updates --show-warnings --select_limit=9999999999999 --auto-vertical-output"
alias mysqllog="/usr/bin/mysql --defaults-group-suffix=logger"

# If on a Debian box where ack is ack-grep, alias it:
if [ -x /usr/bin/ack-grep ]; then
    alias ack="/usr/bin/ack-grep"
fi

# If synclient is installed and we have an X display, set sensible settings
# for palm detection
if [[ "$DISPLAY" != "" && -x /usr/bin/synclient ]]; then
    synclient PalmDetect=1 PalmMinWidth=4
	
    # On my little Lenovo Yoga laptop with a shitty no-buttons trackpad, add
    # middle-click emulation
    if [[ "$HOSTNAME" == "rollitover" ]]; then
        synclient ClickFinger3=2
        synclient TapButton3=2
    fi
fi

# A few variables for easy quick access to common paths (some of these may
# be overridden in the machine-specific stuff below)
export PERL5OPT="-M5.010"

# For Test2-powered test suites, I want to see the output as it comes, not
# all at the end
export REALTIME_TEST_OUTPUT=1


# machine-specific stuff:
case $(hostname --fqdn) in
    supernova.preshweb.co.uk)
        export MPD_HOST=supernova
    ;;
    cloudburst|supersonic)
        export MPD_HOST=supernova
    ;;
esac


# this can get set by the prependtitle() function
# and is prepended to the xterm window title
export PREPENDTITLE=''

# If I have a ~/perl5, then attempt to use local::lib to install my stuff
# locally; otherwise, configure cpanm to use --sudo.
if [[ -d ~/perl5 && "$PS1" != "" ]]; then
    echo "~/perl5 found, configuring local::lib";
    eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"
    export PERL_CPANM_OPT="--mirror http://cpan.mirrors.uk2.net/ --mirror-only"
else
    export PERL_CPANM_OPT="--sudo --mirror http://cpan.mirrors.uk2.net/ --mirror-only"
fi


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
    if perl -c $SOURCEPATH ; then
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
    if [[ ! -d ~/dotfiles ]]; then
        echo "My dotfiles repo should be checked out at ~/dotfiles"
        exit
    fi

    CWDBEFORE=$(pwd)
    cd ~/dotfiles
    echo "Updating dotfiles repo..."
    git pull
    if [ $? != 0 ]; then
        echo "Git pull failed - look above and fix it"
    else
        source profile
        echo "All done"
    fi
    cd $CWDBEFORE
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
        *.staging.*)
            hostnamecolor=93
        ;;

        # UAT boxes are half-way between staging and live, so get yellow prompts
        # on a red background (pretty!)
        *.uat.*)
            hostnamecolor='1;33;41'
        ;;

        # dev boxes get green prompts
        *dev.)
            hostnamecolor=32
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

    # If we sourced an env-specific profile extension earlier, it may
    # have declared that it has its own hostname colourisation support
    # (knowing more about the types of boxes that it applies to), so
    # if so, ask it
    if [[ "$EXTENDED_HOSTNAME_COLOR" != "" ]]; then
        extended_hostname_color $(hostname -f)

    fi

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








# Quick perl module version
function perlmodversion {
    MODNAME=$1;
    perl -M$MODNAME -e "say qq{$MODNAME = \$$MODNAME::VERSION};" 2>/dev/null
    if [ $? != 0 ]; then
        echo "$MODNAME not installed (or failed to find/load it)"
    fi
}

# Wrap vim, and understand e.g. Foo::Bar -> lib/Foo/Bar.pm
function vim {
    # If more than one arg was given, just pass them all on to vim,
    # don't start trying to work out what to do
    # TODO: maybe iterate over them, replacing any that make sense?
    vimpath=$(which vim)
    if [[ "$vimpath" == "" ]]; then
        # No vim?  WTF?  Maybe it's a box that has vim.tiny?
        vimpath=$(which vim.tiny)
        if [[ "$vimpath" == "" ]]; then
            echo "No vim installed?  What kind of braindead box is this?"
            return
        fi
    fi
    if [ "$#" -ne 1 ]; then
        $vimpath $*
    else
        if [[ "$1" =~ "::" ]]; then
            # First try locally, in the lib/ subdir of where we are - I'll often
            # be in a project directory
            filename=$1
            filename=${filename//:://}
            filename="lib/$filename.pm"

            # If that didn't result in a filename that exists, though, maybe we
            # meant an installed Perl module (presumably to view, rather than
            # edit, one would hope)
            if [ ! -f "$filename" ]; then
                perlmodpath=$( perldoc -l $1 )
                if [ -f "$perlmodpath" ]; then
                    filename=$perlmodpath
                else
                    # Nope - abandon the magic!
                    $filename=$1
                fi
            fi
        else
            filename=$1
        fi
        $vimpath "$filename"
    fi
}


# Handy "cherry-pick all the commits that are on $feature_branch but not
# $master branch" helper.  Handy when raising a PR branched from a release
# branch for a hotfix, where you want only the 
function cherry_pick_from_branch {
    feature_branch=$1
    master_branch=$2

    if [[ "$feature_branch" == "" ]]; then
        cat <<ENDHELP
Cherry-picks unmerged commits from branch 1 that aren't on branch 2.
Usage: cherry_pick_from_branch feature_branch master

You can omit the second, master is default.
ENDHELP
        return
    fi
    
    if [[ "$master_branch" == "" ]]; then
        master_branch="master";
    fi

    current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo "Cherry-picking anything new on $feature_branch that isn't in $master_branch to $current_branch"
    echo "Hit enter to confirm, interrupt to bail"
    read confirm

    while read commit; do
        echo "## $commit"
        sha=$( echo $commit | cut -d ' ' -f 1)
        git cherry-pick $sha;
        if [ $? -ne 0 ]; then
            echo "FAILED to cherry-pick $sha, aborting";
            return
        fi
    done < <(git log $feature_branch ^$master_branch ^$current_branch --oneline | tac)
}

# Dead simple journal/note taking alias; simply takes the argument and writes it
# to ~/journal.txt with a timestamp for real simple brain-dumping.
function jrnl {
    touch ~/journal.txt

    if [[ "$1" != "" ]]; then
        # We were called with a message directly
        JOURNALMSG="$*"
    else
        # Fire up the editor to edit a message to then use
        $EDITOR ~/journal.txt.edit
        JOURNALMSG=$(cat ~/journal.txt.edit)
        rm ~/journal.txt.edit
    fi
    
    echo "OK, write to journal.txt";
    date +'%Y-%m-%d %T (%A)' >> ~/journal.txt.new
    echo "# CWD: $(pwd)" >> ~/journal.txt.new

    # If we're in a git repo at the moment, note which branch we were on for
    # easy later reference
    BRANCH=$(git status 2>/dev/null | grep 'On branch')
    if [[ "$BRANCH" != "" ]]; then
        echo "# $BRANCH" >> ~/journal.txt.new
    fi

    echo >> ~/journal.txt.new
    echo "$JOURNALMSG" >> ~/journal.txt.new
    echo -e "\n********************************************************\n" >> ~/journal.txt.new

    mv ~/journal.txt ~/journal.txt.orig
    cat ~/journal.txt.new ~/journal.txt.orig > ~/journal.txt
    rm ~/journal.txt.orig
    rm ~/journal.txt.new
}




