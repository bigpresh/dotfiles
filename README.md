# David P's dotfiles

This repository contains my dotfiles - config files for various tools I use,
customising things to the way I like to work.

It also contains some handy scripts in the [`bin/` dir](./bin).

I've also described my commonly used [tool stack](./tool-stack) - the tools
I use and why - for easy "install all the things I need" on a new box.

It's a repository here on GitHub so I can just clone it on a box when I start
using it:

  git clone https://github.com/bigpresh/dotfiles.git

Then cd into `~/dotfiles` and run `./setup` to configure - creating appropriate
symlinks etc, and also setting the fetch URL to use the https:// URL so it can
be updated via the cronjob which the setup script automatically adds.

It's a public repository partly so that I can access it without authentication,
so the cron job to auto-update works without authentication complexity, but 
mostly in case anything in here is useful to others.

If you do find anything here useful, feel free to use it!  Feel free also to
drop me a mail and let me know that it was helpful to you - it'd be lovely
to hear if any of it has helped anyone else.

Everything here in this repository, unless noted otherwise, can be considered
to be released under the terms of the WTFPL.

David Precious <davidp@preshweb.co.uk>

