# local-profiles

Machine-specific local profiles live here.

Symlink from `~/.profile-local` to one of these, and the main .profile will
source it.

(TODO: maybe name them by hostname, and just have the main profile check if
`~/dotfiles/local-profiles/$hostname` exists, and source it if so?


