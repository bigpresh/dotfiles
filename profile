
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
if [[ "$TERM" == xterm* ]]; then
    if [ -f ~/banner ]; then cat ~/banner; fi;
    # show at a glance how the box is performing as we log in
    LOAD=$(cat /proc/loadavg | cut -d ' ' -f 1,2,3)
    PROCS=$(ps aux | wc -l)
    echo " $HOSTNAME : LOAD: $LOAD PROCS: $PROCS"

    # If we have fortune installed, show one (use boxes, if that's available)
    if [ $(which fortune 2>/dev/null) ]; then
        if [ $(which boxes 2>/dev/null) ]; then
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

# If we have a ripgrep config, set the env var to use it
if [ -f "$HOME/.ripgreprc" ]; then
    export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc
fi

if [ -x "/bin/grep" ]; then
    alias grep="/bin/grep --binary-files=without-match"
fi


# Some Bash-specific stuff
if [[ "$SHELL" = *bash* ]]; then
    # bash history settings:
    export HISTCONTROL=ignoreboth
    export HISTSIZE=1000
    export HISTFILESIZE=10000
    export HISTTIMEFORMAT="%F %T "
    export HISTIGNORE='*PASS*:*KEY*:*TOKEN*:*private*:youtube-dl *:'
    shopt -s histappend
    shopt -s histverify

    # Automatically update the history file immediately, so
    # different sessions don't clobber each other's history.
    # TODO: this *might* cause some latency, disable if so
    if [[ ! "$PROMPT_COMMAND" =~ "history" ]]; then
        export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
    fi

    # Notice if the window size changed:
    shopt -s checkwinsize

    # Disable session suspend/resume - it's too easy to hit Ctrl-S by accident
    # and freeze the terminal; I have no use for that, so disable it.
    if [ -t 0 ]; then
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
alias gb='git rev-parse --abbrev-ref HEAD'
alias gpr='git pull --rebase'
alias ss="svnstatus"
alias cm="sudo su codemonkey"
alias tailf='less +F'
alias puppettest='sudo puppet apply --modulepath=/etc/puppet/forge-modules:/etc/puppetlabs/code/environments/production/modules:/etc/puppet/modules --verbose /etc/puppet/manifests/site.pp --debug'
alias jfdi='sudo "$BASH" -c "$(history -p !!)"'

# convenient alias to see first & last line of a file:
alias toptail="sed -e 1b -e '\$!d'"


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

# Add ~/dotfiles/bin to my $PATH so my convenient utility scripts just work
export PATH="$PATH:$HOME/dotfiles/bin"

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
else
    export PERL_CPANM_OPT="--sudo"
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
        *dev*)
            hostnamecolor=32
        ;;

        # live boxes get red prompts
        *live*)
            hostnamecolor='1;31'
        ;;

        # standby boxes are "live at any moment", so get darker red prompts
        *standby*)
            hostnamecolor='31'
        ;;


        # supernova gets teal:
        supernova.preshweb.co.uk)
            hostnamecolor=36
        ;;

        # Lyla gets purple
        lyla.preshweb.co.uk)
            hostnamecolor=35
        ;;

        # Headshrinker gets blue
        headshrinker.preshweb.co.uk)
            hostnamecolor=34
        ;;

        # slideaway gets bold purple
        slideaway.preshweb.co.uk)
            hostnamecolor='35;1'
        ;;

        # columbia (Xeon workstation) gets green
        columbia.preshweb.co.uk)
            hostnamecolor='32'
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

    # Most of the time these days, I'm using Git.  If we're in a Git repo,
    # find out what branch we're on, and if I can find a GitHub issue number
    # in the branch name, prepend it to the template for the message that
    # will be opened in my editor
    git_status=$(git status)
    if [[ "$git_status" != "" ]]; then
        template_file=/tmp/commit-message-template
        echo -n > $template_file
        gh_num=$(echo $git_status | perlgrep 'On branch.+(?:gh|GH)[_-]?(\d+)')
        if [[ "$gh_num" != "" ]]; then
            echo " #$gh_num" >> $template_file
        fi

        echo -e "\n## Commit summary follows:\n" >> $template_file

        git diff --stat "$@" | sed 's/^/# /' | cat >> $template_file

        # If I'm adding a FIXME, warn me that I probably should have fixed
        # it; don't complain about already-existing ones or ones I'm removing
        # though.
        FIXME=$(git diff "$@" | grep -E '^\+.*FIXME')
        if [[ "$FIXME" != "" ]]; then
            cecho RED "WARNING: One or more FIXMEs detected:"
            echo $FIXME
            echo "You should probably fix those, rather than commit them?"
            echo "Enter to commit anyway, otherwise interrupt... ?>"
            read
        fi

        # Likewise, watch for potty mouth... maybe make this configurable
        # by box/repo type, so work stuff gets checked but not personal...
        FUCKINGRUDE=$(git diff "$@" | grep -E '^\+.*(fuck|shit|cunt|wank)')
        if [[ "$FUCKINGRUDE" != "" ]]; then
            cecho RED "Oi, careful with the swearing:"
            echo "$FUCKINGRUDE"
            echo "Enter to commit anyway, otherwise interrupt... ?>";
            read
        fi


        # If we have vim, then run "a" to go into visual mode at the end
        # of the first line (i.e. after the GH-xx prefix, if we added one).
        # (If we don't have vim, what kind of batshit box *is* this?!)
        vim_path=$(which vim)
        if [[ "vim_path" != "" ]]; then
            export GIT_EDITOR="$vim_path -c 'startinsert'"
        fi
        git commit -t $template_file -v "$@"
        return
    fi

    # Alright, not a Git repo.  Assume Subversion from now on (should really
    # check, and if I end up using other VCSes, support them too)
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
    perl -M$MODNAME -E "\$MODPATH = '$MODNAME'; \$MODPATH=~s{::}{/}; \$MODPATH .= '.pm'; say qq{$MODNAME = \$$MODNAME::VERSION in \$INC{\$MODPATH}};" 2>/dev/null
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


# Convenience wrapper for puppet-master-less boxes to pull new changes from git
# then run a puppet-apply
function puppetapply {
    pwd=`pwd`
    if [ -d /etc/puppet_secure ]; then
        echo "git pull in /etc/puppet_secure..."
        cd /etc/puppet_secure
        git pull
    fi
    echo "cd to /etc/puppet and git pull"
    cd /etc/puppet
    git pull
    echo "Begin puppet run"
    perl /etc/puppet/modules/puppet_node/files/puppet-lock-apply
    echo "Leaving you back in $pwd"
    cd $pwd
}

# Convenient retry wrapper for retrying ssh connections after a box is
# restarted until it is reachable again.
function sshretry {
    host=$1
    ping=$2

    echo "OK, fingers crossed and wait for $host to be back up..."
    echo "Started waiting at `date +'%F %H:%M:%S'`"
    start_timestamp=`date +%s`

    # Resolve any SSH aliases by parsing `ssh -G` output.
    # e.g. if .ssh/config had an entry like:
    #   Host myalias
    #     Hostname real.example.com
    # then if we're called with sshretry myalias, we want to know to ping
    # real.example.com.
    ping_hostname=$(ssh -G $host | awk '$1 == "hostname" { print $2 }')


    # Normally, try pinging first, and report when it starts pinging,
    # so you get an idea when it's sort-of booting; normally it will start
    # responding to pings well before SSH is ready for use.  If it's
    # firewalled, though, then we want to be able to skip that
    if [[ "$ping" != "noping" ]]; then
        while [ 1 ]; do
            if ping -c1 $ping_hostname > /dev/null ; then
                let waited=expr $(date +%s)-$start_timestamp
                echo "OK, $host is pingable at `date +'%F %H:%M:%S'` after $waited seconds"
                break;
            else
                sleep 1;
            fi
        done
        echo "Pingable, so try to ssh..."
    fi

    # Now wait for ssh to succeed
    while [ 1 ]; do
        let waited=expr $(date +%s)-$start_timestamp
        # Sometimes ssh will hang for a long time trying to connect
        # if sshd is not yet up & ready; set a short timeout ready
        # for us to try again.  Also, just so we can log the time
        # we were able to reconnect in case we want to see how long
        # it was down by scrollback, do a test first
        if ssh -o 'ConnectTimeout=2' $host exit; then
            echo "Looks like SSH is available at `date +'%F %H:%M:%S'` after $waited seconds"
            ssh $host
            break
        else
            echo "Waiting (waited $waited secs so far for $host)"
            sleep 2;
        fi
    done
}

# Open the most recent Puppet apply log
# May need to be more clever in future, but this works for our KT boxes.
function puppetlog_latest {
    if [[ -d /var/log/puppet ]]; then
        sudo less /var/log/puppet/$(sudo ls -1t /var/log/puppet/ | grep puppet-apply | head -1)
    else
        echo "No /var/log/puppet on this box"
    fi
}

function cdreporoot {
    ORIGDIR=$PWD
    while [[ ! -d '.git' ]]; do
        cd ..
        if [[ "$PWD" == "/" ]]; then
            echo "No .git dir found anywhere above this one"
            cd $ORIGDIR
            return
        fi
    done
}


# Convenient function to report/change selected profile for aws-cli
# - a little nicer than manually setting $AWS_PROFILE - particularly
# when combined with tab-completion of profiles.
# (I might change the "no arguments just shows the current value" behaviour
# to instead present a menu to pick from, maybe)
function aws_profile {
    new_profile=$1

    if [[ "$new_profile" == "" ]]; then
        echo "Current AWS_PROFILE is $AWS_PROFILE"
        return
    fi

    # Set AWS_PROFILE env var to the desired profile name.
    # TODO: verify that it exists - although if you're tab-completing,
    # which is the main reason I wrote this, then it'll be alright.
    export AWS_PROFILE=$new_profile
    echo "OK, AWS_PROFILE now $AWS_PROFILE"
}

# If we have aws-cli configured, then set up tab-completion for
# AWS profiles using our aws_profile() function above
if [ -f ~/.aws/config ]; then
    profiles=( $(/usr/local/bin/aws configure list-profiles) )
    complete -W "${profiles[*]}" aws_profile
fi

# Convenient CDK stack diff/deploy shorthand, with our BUILD_STACK env
# var set to only compile the code for that stack...
function cdk_stack {
    full_stack_name=$1
    operation=$2
    if [[ "$full_stack_name" == "" || "$operation" == "" ]]; then
        echo "Usage: cdk_stack stack_name operation"
        echo "  (e.g. cdk_stack kt/dev/foostack deploy)"
        return;
    fi

    if [[ "$operation" != "diff" && "$operation" != "deploy" ]]; then
        echo "I only understand operations 'diff' and 'deploy'"
        return;
    fi

    # Make sure we remembered to set $AWS_PROFILE, it's very rare that we'd
    # have not needed to
    if [[ "$AWS_PROFILE" == "" ]]; then
        echo "You haven't set env var \$AWS_PROFILE, that's probably a mistake"
        return;
    else
        echo -n "Running cdk $operation $stack_name as profile "
        if [[ "$AWS_PROFILE" =~ "live" ]]; then
            cecho RED $AWS_PROFILE;
        else
            cecho GREEN $AWS_PROFILE;
        fi
    fi

    # We used to try to work out the stack ID to use in the BUILD_STACK
    # env var to speed things up by only building the stack being deployed,
    # but most of our stacks have a different stack ID vs stackName, so that
    # won't work in a simple fashion.  D'oh.

    npx cdk $operation $full_stack_name
}

# Simple coloured text output, e.g. `cecho RED Bad Things Happened!`
cecho(){
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    # ... ADD MORE COLORS
    NC="\033[0m" # No Color
    printf "${!1}${2} ${NC}\n"
}


# Show command execution times (and success) after each command
# script from https://github.com/jichu4n/bash-command-timer
source ~/dotfiles/bash_command_timer.sh

