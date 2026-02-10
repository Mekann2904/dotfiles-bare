# ==============================================================================
# ┌────────────────────────────────────────────────────────────────────────────┐
# │                                                                            │
# │   ███████╗ ███████╗ ██╗  ██╗      Z  S  H   C  O  N  F  I  G               │
# │   ╚══███╔╝ ██╔════╝ ██║  ██║      ──────────────────────────               │
# │     ███╔╝  ███████╗ ███████║      The Advanced Shell                       │
# │    ███╔╝   ╚════██║ ██╔══██║      Maintained by Mekann                     │
# │   ███████╗ ███████║ ██║  ██║                                               │
# │   ╚══════╝ ╚══════╝ ╚═╝  ╚═╝                                               │
# │                                                                            │
# └────────────────────────────────────────────────────────────────────────────┘
# ==============================================================================


# === 0. 基本設定 & パス設定 (Basic Settings & Path) ===
typeset -U path PATH

# 計測
#zmodload zsh/zprof

if [ ~/.zshrc -nt ~/.zshrc.zwc ]; then
  zcompile ~/.zshrc
fi

# --- Homebrew shellenv キャッシュ ---
#brew_cache=${HOME}/.cache/brew-shellenv.zsh

#if command -v brew >/dev/null 2>&1; then
#  # キャッシュが無い、もしくは brew 本体がキャッシュより新しければ再生成
#  if [[ ! -r $brew_cache || $(command -v brew) -nt $brew_cache ]]; then
#    mkdir -p "${HOME}/.cache"
#    brew shellenv >! "$brew_cache"
#  fi
#  source "$brew_cache"
#fi

# === Homebrew: Static Configuration (Fastest) ===
# No checks, just set variables.
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
export MANPATH="/opt/homebrew/share/man:$MANPATH"
export INFOPATH="/opt/homebrew/share/info:$INFOPATH"

# Hardcode the library paths (Derived from your previous script)
export LDFLAGS="-L/opt/homebrew/opt/libassuan/lib -L/opt/homebrew/opt/libgpg-error/lib"
export CPPFLAGS="-I/opt/homebrew/opt/libassuan/include -I/opt/homebrew/opt/libgpg-error/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/libassuan/lib/pkgconfig:/opt/homebrew/opt/libgpg-error/lib/pkgconfig:/opt/homebrew/lib/pkgconfig"

# PATH設定 (配列定義・重複排除・存在チェックなしで高速に追加)
# Homebrew 側が設定した PATH に対して「足すだけ」にする
path=(
    "$HOME/opt/homebrew/bin/Python3"
    "$HOME/go/bin"
    "$HOME/Desktop/Automation-Code"
    "$HOME/Library/Python/3.9/bin"
    "/usr/local/bin"
    "/opt/homebrew/opt/php@8.2/bin"
    "/opt/homebrew/opt/php@8.2/sbin"
    "/opt/homebrew/opt/mysql@8.0/bin"
    "/opt/homebrew/opt/httpd/bin"
    "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    "/Library/TeX/texbin"
    "$HOME/.codeium/windsurf/bin"
    "$HOME/.cargo/bin"
    "$HOME/.spicetify"
    "$path[@]"
)

# stty設定
stty susp '^z'

# 外部env読み込み (存在確認を[[ ]]で行い高速化)
[[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"

# === 1. 環境変数 (Environment Variables) ===
export LANG=ja_JP.UTF-8
export GH_BROWSER="open -a 'Vivaldi Snapshot'"
export MANPATH=$MANPATH:/usr/share/man:/usr/local/share/man:/usr/local/man:/usr/local/news/man
export GPG_TTY=$(tty)

# 文字エンコーディング (EUID変数を使用し外部コマンド削減)
__CF_USER_TEXT_ENCODING=0x`printf "%X" ${EUID:-$(id -u)}`:0x8000100:0x8000100
export __CF_USER_TEXT_ENCODING

# PAGER
export PAGER=less
export LESS=eR

# mdcat
export MDCAT_PAGER=""

# --- [高速化] Homebrew / SDK パス設定 ---
if [[ -d /opt/homebrew ]]; then
  _brew_prefix="/opt/homebrew"
elif [[ -d /usr/local ]]; then
  _brew_prefix="/usr/local"
elif command -v brew >/dev/null 2>&1; then
  _brew_prefix="$(brew --prefix)"
fi

if [[ -n "$_brew_prefix" ]]; then
  export LDFLAGS="-L${_brew_prefix}/opt/libassuan/lib -L${_brew_prefix}/opt/libgpg-error/lib"
  export CPPFLAGS="-I${_brew_prefix}/opt/libassuan/include -I${_brew_prefix}/opt/libgpg-error/include"
  export PKG_CONFIG_PATH="${_brew_prefix}/opt/libassuan/lib/pkgconfig:${_brew_prefix}/opt/libgpg-error/lib/pkgconfig:${_brew_prefix}/lib/pkgconfig"
fi
unset _brew_prefix

# macOS SDK (存在チェックのみで高速化)
if [[ -x /usr/bin/xcrun ]]; then
    # export SDKROOT="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)"
    :
fi

# === Zimfw (Zsh フレームワーク) ===
# 補完初期化の警告を防ぐため、GitHub CLI等の前に配置することを推奨

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim

# Install missing modules and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]]; then
  source /opt/homebrew/opt/zimfw/share/zimfw.zsh init
fi

# Initialize modules.
source ${ZIM_HOME}/init.zsh

# === GitHub CLI 補完 ===
# Zimfw読み込み後に配置 (fpathの順序制御のため)
_zsh_compdir="$HOME/.zsh/completions"
if [[ ! -d "$_zsh_compdir" ]]; then
  mkdir -p "$_zsh_compdir"
fi
fpath=("$_zsh_compdir" $fpath)

if (( $+commands[gh] )); then
  # 補完ファイルがない場合のみ生成 (compinitはZimfwに任せるためここでは実行しない)
  [[ -f "$_zsh_compdir/_gh" ]] || gh completion -s zsh > "$_zsh_compdir/_gh"
fi
unset _zsh_compdir


# === 2. 遅延読み込み設定 (Lazy Loading) - 最重要高速化ポイント ===

# --- Conda Lazy Load ---
#function conda() {
#    unfunction conda
#    # パスが正しいか確認してください
#    __conda_setup="$('/Users/mekann/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
#    if [ $? -eq 0 ]; then
#        eval "$__conda_setup"
#    else
#        if [ -f "/Users/mekann/miniconda3/etc/profile.d/conda.sh" ]; then
#            . "/Users/mekann/miniconda3/etc/profile.d/conda.sh"
#        else
#            export PATH="/Users/mekann/miniconda3/bin:$PATH"
#        fi
#    fi
#    unset __conda_setup
#    conda "$@"
#}

# --- NVM Lazy Load ---
export NVM_DIR="$HOME/.config/nvm"
function _load_nvm() {
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        . "$NVM_DIR/nvm.sh"
    fi
}
for cmd in nvm node npm pnpm yarn pi; do
    eval "function $cmd() { unset -f nvm node npm pnpm yarn pi; _load_nvm; $cmd \"\$@\"; }"
done

# --- Pyenv Lazy Load ---
export PYENV_ROOT="$HOME/.pyenv"
if [[ -d "$PYENV_ROOT/bin" ]]; then
    path=("$PYENV_ROOT/bin" $path)
    function pyenv() {
        unset -f pyenv
        eval "$(pyenv init -)"
        pyenv "$@"
    }
fi

# --- Deno Lazy Load ---
function deno() {
    unset -f deno
    [[ -f "$HOME/.deno/env" ]] && . "$HOME/.deno/env"
    deno "$@"
}


# === 3. シェルオプション (Shell Options) ===
setopt NO_BEEP
setopt printeightbit
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt list_packed

limit datasize unlimited
limit stacksize 60M
DIRSTACKSIZE=6

## === バインドキー ===
# Control-x Control-r で redo
bindkey '^X^R' redo

## === zsh固有のヘルプ機能 ===
unalias run-help 2>/dev/null
autoload -Uz run-help

# === 4. 履歴ファイル (History) ===
if [[ -w $HOME ]]; then
  HISTFILE=$HOME/.zsh_history
  HISTSIZE=10000
  SAVEHIST=$HISTSIZE
fi

# === 5. プロンプト (Prompt) ===
prompt='%n@%m %2d $ '
if [[ -f /singularity ]]; then
  prompt="%S+%s%m%S+%s$SINGULARITY_NAME:r%S+%s%n "
fi

# === 6. エイリアス (Aliases) ===

# 設定再読み込み (sourceではなくexec zshを使う)
alias reload='exec zsh'

alias h="fc -l -d -20"
alias history="fc -l -d -$HISTSIZE"
alias j=jobs
alias re='(setopt +o nomatch; rm -f .*~ *~ *.dvi *.log *.blg *.bak *.swp *.agdai)'
alias nslookup="nslookup -sil"
alias emacs="emacs -nw"
if [[ -f ~/bin/jless ]]; then
  alias more=jless
else
  alias more=less
fi
alias rless="unset LESSOPEN; less"
[[ -f /usr/local/bin/nvim ]] && alias vi=nvim
alias kitty='kitty --single-instance'
spotify() { spicetify auto; }
alias pu=pushd
alias po=popd
alias pu2="pu ~2"
alias pu3="pu ~1"
alias half="echo -n '\033(H\033(J\033(B\033\$)B'"
alias rtty="rtty run zsh -p 8080 --font-size 11"
alias codex='/Users/mekann/.config/nvm/versions/node/v22.12.0/bin/codex'
alias python='/usr/bin/python3'
alias kilocode='/Users/mekann/.config/nvm/versions/node/v22.12.0/bin/kilocode'
alias cline='/Users/mekann/.config/nvm/versions/node/v22.12.0/bin/cline'

# === 7. 関数 (Functions) ===
function fixname {
  foreach name ( "$@" )
    new=$(echo $name | nkf -w )
    mv ${==name} ${==new}
  end
}
function fixname1 {
  foreach name ( "$@" )
    new=$(perl -e print\ \"$name\\n\"\; | nkf -w )
    mv ${==name} ${==new}
  end
}
function java_home {
  export JAVA_HOME=`/usr/libexec/java_home $@`
  echo "JAVA_HOME:" $JAVA_HOME; java -version
}
function whois { ldapsearch -LLL "(uid=$@)"; }
function sshow { printenv | grep SSH | sed -e 's/^/export /'; }

# === 8. ディレクトリ記憶 (Last Dir) ===
LAST_DIR_FILE="$HOME/.last_dir"
function save_last_dir { echo $PWD >! $LAST_DIR_FILE; }
function load_last_dir { [[ -f $LAST_DIR_FILE ]] && builtin cd "$(cat $LAST_DIR_FILE)"; }
autoload -U add-zsh-hook
add-zsh-hook chpwd save_last_dir
# 最後に呼び出す (定義順序依存を避けるため)

# === 9. 補完設定 (Completion) - fzf-tab用に強化 ===
# ※ compinit は zimfw の completion モジュールに任せる

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' ignore-parents parent pwd ..
zstyle ':completion:*:default' menu select=1
zstyle ':completion:*:cd:*' ignore-parents parent pwd

# fzf-tab設定
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' group-name ''

# カラー設定
autoload -U colors && colors
export LSCOLORS=Exfxcxdxbxegedabagacad
export LS_COLORS='di=01;34:ln=01;35:so=01;32:ex=01;31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*' list-colors "${LS_COLORS}"

zmodload -i zsh/complist
bindkey -e

# === 10. ツール別設定 (その他) ===

# SSH Agent
#if [[ -o login ]] && [[ -z "$SSH_AUTH_SOCK" ]]; then
#  eval $(ssh-agent) >/dev/null
#  ssh-add ~/.ssh/id_rsa 2>/dev/null
#fi
#alias start-ssh='eval $(ssh-agent) && ssh-add ~/.ssh/id_rsa'

alias start-ssh='eval $(ssh-agent) >/dev/null && ssh-add ~/.ssh/id_rsa 2>/dev/null'

#glow
GLAMOUR_STYLE="tokyo-night"

# kiro
[[ "$TERM_PROGRAM" == "kiro" && (( $+commands[kiro] )) ]] && . "$(kiro --locate-shell-integration-path zsh)"

# zoxide
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# TERM
if [[ $TERM == "xterm" ]]; then export TERM=xterm-color; fi

# uv
_uv_compdir="$HOME/.zsh/completions"
[[ -d "$_uv_compdir" ]] || mkdir -p "$_uv_compdir"
fpath=("$_uv_compdir" $fpath)

if command -v uv >/dev/null 2>&1; then
  [[ -f "$_uv_compdir/_uv" ]] || uv generate-shell-completion zsh >"$_uv_compdir/_uv"
fi
unset _uv_compdir


# === 11. ターミナルタイトル ===
function xtitle { print -Pn "\e]2;%~\a"; }
add-zsh-hook precmd xtitle
xtitle


# === 12. 独自ツール ===========================================
# zimfwに全て以降しました


# === 13. 補完の高度な設定 (fzf-tab & Git) =====================

# --- 1. fzf-tab 基本設定 ---
zstyle ':fzf-tab:*' fzf-command fzf
zstyle ':fzf-tab:*' fzf-min-height 20
zstyle ':fzf-tab:*' fzf-bindings 'ctrl-/:toggle-preview'

# --- 2. Git 補完のソート無効化 (時系列維持) ---
zstyle ':completion:*:git-*' sort false
zstyle ':completion:*:git-*' rehash true
zstyle ':fzf-tab:complete:git-*' fzf-flags --no-sort

# --- 3. プレビュー設定 (Preview) ---
zstyle ':fzf-tab:complete:git-(checkout|switch|restore):*' fzf-preview \
	'git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %s" {1} | head -20'

zstyle ':fzf-tab:complete:git-(diff|add|reset):*' fzf-preview \
	'git show --color=always $word | head -20'

zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview \
  '[[ $group == "[process ID]" ]] && ps --pid=$word -o cmd --no-headers -w -w'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:3:wrap

# === 14. Ctrl-J: ripgrep + fzf 検索 ===
if (( $+commands[rg] )) && (( $+commands[fzf] )); then
  fzf-ripgrep-widget() {
    emulate -L zsh
    local query selected file line
    query="$LBUFFER$RBUFFER"
    [[ -z $query ]] && return 0
    zle -I
    selected=$(
      rg --line-number --no-heading --color=always "$query" 2>/dev/null |
      fzf --ansi --delimiter : --nth 3.. \
            --preview 'bat --style=numbers --color=always --line-range :200 {1} 2>/dev/null || head -n 200 {1}' \
            --preview-window='right:60%:border-rounded:wrap'
    )
    zle redisplay
    [[ -z $selected ]] && return 0
    file=${selected%%:*}
    line=${${selected#*:}%%:*}
    BUFFER="vim +${line} ${(q)file}"
    CURSOR=${#BUFFER}
    zle accept-line
  }
  zle -N fzf-ripgrep-widget
  bindkey '^J' fzf-ripgrep-widget
fi

alias dot='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias lazydot='lazygit --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# === 起動時のディレクトリ復元 (Load Last Dir) ===
# すべての設定読み込みが終わった後に実行して、chpwdフックのエラーを防ぐ
load_last_dir
#eval "$(starship init zsh)"



# opencode
export PATH=/Users/mekann/.opencode/bin:$PATH

# Composio CLI
export COMPOSIO_INSTALL_DIR=/Users/mekann/.composio
export PATH="/Users/mekann/.composio:$PATH"

# Composio CLI
export COMPOSIO_INSTALL_DIR=/Users/mekann/.composio
export PATH="/Users/mekann/.composio:$PATH"

# Composio CLI
export COMPOSIO_INSTALL_DIR=/Users/mekann/.composio
export PATH="/Users/mekann/.composio:$PATH"

# Composio CLI
export COMPOSIO_INSTALL_DIR=/Users/mekann/.composio
export PATH="/Users/mekann/.composio:$PATH"
