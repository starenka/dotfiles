zmodload zsh/zprof
zmodload zsh/complist

# Force a reload of completion system if nothing matched; this fixes installing
# a program and then trying to tab-complete its name
_force_rehash() {
    (( CURRENT == 1 )) && rehash
    return 1    # Because we didn't really complete anything
}

# pip zsh completion start
function _pip_completion {
  local words cword
  read -Ac words
  read -cn cword
  reply=( $( COMP_WORDS="$words[*]" \
             COMP_CWORD=$(( cword-1 )) \
             PIP_AUTO_COMPLETE=1 $words[1] ) )
}
compctl -K _pip_completion pip

rsync-on-change () {
    if [ $# -lt 2 ]; then
        echo -e 1>&2 "USAGE:\n\t$0 SRC TAR (without trailing slashes)"
    else
        while inotifywait -r $1/; do
            rsync -avz $1/ $2/
        done
    fi
}

tunnel () {
    tunnel-list () {
        tunnels=$(pgrep autossh -a | sort | sed 's/.* //g' | cut -d' ' -f10 | cat -n)
        if [[ $tunnels ]]; then echo $tunnels; else echo 'no tunnels (⊙_⊙)'; fi
    }

    if [ -z "$1" ]; then
        tunnel-list
    elif [ "$1" = "--kill" ]; then
        pkill -f "(/usr/bin/ssh|/usr/lib/autossh/autossh)\s.*$2"
        tunnel-list
    elif [ "$1" = "--list" ]; then
        tunnel-list
    else
        for host in "$@"; do
            autossh -M 0 -f -q -N -o "ServerAliveInterval 60" -o "ServerAliveCountMax 3" "$host"
        done
        tunnel-list
    fi
}
alias tunel=tunnel

geolocate () {
    curl -s "https://location.services.mozilla.com/v1/geolocate?key=geoclue" | jq -r '"\(.location.lat):\(.location.lng)"' || echo '50.1113:14.4063'
}

# https://github.com/akermu/emacs-libvterm
vterm_printf(){
    if [ -n "$TMUX" ] && ([ "${TERM%%-*}" = "tmux" ] || [ "${TERM%%-*}" = "screen" ] ); then
        # Tell tmux to pass the escape sequences through
        printf "\ePtmux;\e\e]%s\007\e\\" "$1"
    elif [ "${TERM%%-*}" = "screen" ]; then
        # GNU screen (screen, screen-256color, screen-256color-bce)
        printf "\eP\e]%s\007\e\\" "$1"
    else
        printf "\e]%s\e\\" "$1"
    fi
}

if [[ -n "$INSIDE_EMACS" ]]; then
     RPROMPT=""
     alias mc='mc --nocolor'
     alias htop='htop --no-colour'
fi

[[ "$INSIDE_EMACS" = 'vterm' ]] && alias clear='vterm_printf "51;Evterm-clear-scrollback";tput clear'    

### Git prompt
ZSH_THEME_GIT_PROMPT_PREFIX=' '
ZSH_THEME_GIT_PROMPT_SUFFIX=''
ZSH_THEME_GIT_PROMPT_DIRTY='!'
ZSH_THEME_GIT_PROMPT_UNTRACKED='?'
ZSH_THEME_GIT_PROMPT_CLEAN=''
ZSH_THEME_GIT_PROMPT_SHA_BEFORE=' at '

source ~/.zsh.d/git.zsh

function git_prompt {
    echo "%{$fg[green]%}$(git_prompt_info)%{$reset_color%}%{$fg[yellow]%}$(git_prompt_short_sha)%{$reset_color%}%{$fg[green]%}$(parse_git_dirty)$(git_prompt_status)%{$reset_color%}"
}


### settings
autoload -Uz compinit
for dump in ~/.zcompdump(N.mh+24); do
  compinit
done
compinit -C

setopt EXTENDED_HISTORY HIST_NO_STORE HIST_IGNORE_DUPS HIST_EXPIRE_DUPS_FIRST HIST_FIND_NO_DUPS HIST_IGNORE_ALL_DUPS INC_APPEND_HISTORY SHARE_HISTORY HIST_REDUCE_BLANKS HIST_IGNORE_SPACE
HISTFILE=~/.histfile
HISTSIZE=10000000
SAVEHIST=20000000
HISTORY_IGNORE="(wo# *|workon# *|don|doff|djsh|djs|wifi on|su \-|ls \-al|ipython|python)"

unsetopt autocd
setopt prompt_subst
autoload -U colors && colors
bindkey -e

bindkey ';5D' emacs-backward-word
bindkey ';5C' emacs-forward-word

### Tab completion

# Always use menu completion, and make the colors pretty!
zstyle ':completion:*' menu select yes
zstyle ':completion:*:default' list-colors ''

zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' list-suffixes true
zstyle ':completion:*' file-sort name

# Completers to use: rehash, general completion, then various magic stuff and
# spell-checking.  Only allow two errors when correcting
zstyle ':completion:*' completer _force_rehash _complete _ignored _match _correct _approximate _prefix
zstyle ':completion:*' max-errors 1


# When looking for matches, first try exact matches, then case-insensiive, then
# partial word completion
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'r:|[._-]=** r:|=**'

# Turn on caching, which helps with e.g. apt
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $HOME/.zsh/cache

# Show titles for completion types and group by type
zstyle ':completion:*:descriptions' format "$fg_bold[black]» %d$reset_color"
zstyle ':completion:*' group-name ''

# Ignore some common useless files
zstyle ':completion:*' ignored-patterns '*?.pyc' '__pycache__' 'parent' 'pwd'
zstyle ':completion:*:*:rm:*:*' ignored-patterns

zstyle :compinstall filename '$HOME/.zshrc'
compinit

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

bindkey -M menuselect '/' history-incremental-search-forward 

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# prompt: machine (if running screen, show window #) path
if [ x$WINDOW != x ]; then
    export PS1="%{%F{yellow}%}%n%{%f%}@%m[$WINDOW] %~%# "
else
    export PS1='%{%F{blue}%}%n%{%f%} %~$(git_prompt) %# '
fi

### Aliases + exports

autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line

export EDITOR="emacsclient -t"

[ -f "$HOME/.aliases" ] && source ~/.aliases

# set PATH so it includes user's private bin if it exists
[ -d "$HOME/bin" ] && PATH="$HOME/bin:$PATH"

# pip --user stuff f.e.
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"

#colored less (aptitude install source-highlight)
#export LESSOPEN="| /usr/share/source-highlight/src-hilite-lesspipe.sh %s"
#export LESS=' -R '

#virtualenvwrapper
export WORKON_HOME=/data/.envs
export PROJECT_HOME=/prac/python
export VIRTUALENVWRAPPER_SCRIPT=~/.local/bin/virtualenvwrapper.sh
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
source ~/.local/bin/virtualenvwrapper_lazy.sh

#shell syntax highliting on cli
[ -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#nodenv
#export PATH="/home/starenka/.nodenv/bin:/home/starenka/.nodenv/shims:$PATH"
#eval "$(nodenv init -)"

export GOPATH="/home/starenka/.go/"
export PATH="/home/starenka/.cargo/bin:/home/starenka/.go/bin:$PATH"
export PATH=$PATH:$HOME/.pulumi/bin

#pythonz
[[ -s $HOME/.pythonz/etc/bashrc ]] && source $HOME/.pythonz/etc/bashrc

#fzf
[ -f "/usr/share/doc/fzf/examples/key-bindings.zsh" ] && source /usr/share/doc/fzf/examples/key-bindings.zsh

#export PAGER=eless

#prej to chci, rika krab
export DOCKER_BUILDKIT=1

cd /tmp

# https://github.com/ipython/ipython/issues/13472#issuecomment-1025216803
echo -en "\x1b[0 q"

