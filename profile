
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
# Latest copy of this profile can be found at:
# http://www.preshweb.co.uk/downloads/profile
# Use the 'updateprofile' command to auto-fetch it.
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
LOAD=$(cat /proc/loadavg | cut -d ' ' -f 1,2,3)
PROCS=$(ps aux | wc -l)

# print pretty banner and loadavg etc only if we're 
# logging in with an xterm (doing it without checking 
# can be bad, it can fuck up sshfs / scp etc)
if [ "$TERM" == "xterm" ]; then
    if [ -f ~/banner ]; then cat ~/banner; fi;
    echo " $HOSTNAME : LOAD: $LOAD PROCS: $PROCS"
    echo '.profile : $Id$'

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
alias svnci="svncommit"
alias ci="svncommit"

# A few variables for easy quick access to common paths (some of these may
# be overridden in the machine-specific stuff below)
export cgi=/usr/local/uk2net/cgi
export lib=/usr/local/uk2net/lib
export log=/usr/local/uk2net/log
export PERL5LIB=/usr/local/uk2net/lib

# machine-specific stuff:
case $(hostname --fqdn) in
    cyborg.uk2net.com)
        export CGI=/usr/local/apache_1.1/cgi-bin
        export cgi=/usr/local/apache_1.1/cgi-bin/
        export PATH=/usr/local/openssh/bin:$PATH
        alias codemonkey='sudo -H -u codemonkey ssh-agent $SHELL'
        alias uk2perl='sudo perl -d ~/uk2perl'

        # Cyborg has some DB connection aliases (e.g. "atmaildb") which contain
        # the passwords; obviously don't want those here, so load them from
        # that file:
        source ~/.dbaliases
    ;;
    depardieu.uk2.net)
        alias codemonkey='sudo -H -u codemonkey ssh-agent $SHELL && ssh-add'
    ;;
    rasputin.uk2.net)
        alias codemonkey='sudo su codemonkey'
    ;;
    alchemist.uk2.net)
    ;;
    shop1.uk2.net)
        export carts=/usr/local/apache/carts
    ;;
esac

# If this box has bash-completion available, source it:
if [ -r '/etc/bash_completion' ]; then
    . /etc/bash_completion
fi




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

    # Set custom prompt:
    PS1="${PROMPTSET}[\u@\h:\w]\\$ "
}


# set the prompt:
setprompt


# Write out a more usable vim config:
writevimconfig() {
    cat <<VIMCONFIG > ~/.vimrc
" vimrc written from .profile
" $Id$

set number

syntax on
set nowrap
set textwidth=80
set shiftwidth=4
set shiftround
set expandtab
set tabstop=4
set autoindent
set smarttab     "Backspace at start of line outdents"
set ruler        "Show current position in file at bottom"

" More normal backspace behaviour:
set backspace=indent,eol,start

" for Perl programming, have things in braces indenting themselves:
autocmd FileType perl set smartindent

" have the h and l cursor keys wrap between lines (like <Space> and <BkSpc> do
" by default), and ~ covert case over line breaks; also have the cursor keys
" wrap in insert mode:
set whichwrap=h,l,~,[,]

" Don't make noise:
set visualbell

" I always use terminals with dark backgrounds:
set background=dark

" make the completion menus readable
highlight Pmenu ctermfg=0 ctermbg=3
highlight PmenuSel ctermfg=0 ctermbg=7

"The following should be done automatically for the default colour scheme
"at least, but it is not in Vim 7.0.17.
if &bg == "dark"
  highlight MatchParen ctermbg=darkblue guibg=blue
endif
  
" Incremental search as you type (don't use on slow terminals)
set incsearch

VIMCONFIG
}

# Do an svn commit, with diffs included in the commit message
svncommit() {

    # Start preparing the commit message which we'll then edit
    COMMITMSG=/tmp/$USER-commitmsg
    echo > $COMMITMSG
    echo "--This line, and those below, will be ignored--" >> $COMMITMSG
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
    $VISUAL $COMMITMSG

    if [[ "$(md5sum $COMMITMSG)" == "$ORIGMD5" ]]; then
        echo "Commit message unchanged, commit aborted";
    else
        svn commit "$@" -F $COMMITMSG
    fi

    rm $COMMITMSG
    rm /tmp/$USER-svndiff
}
