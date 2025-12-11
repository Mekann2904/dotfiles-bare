# ==============================================================================
#
# Zsh Configuration File (.zshrc) - Performance Optimized & Fully Integrated
#
# ==============================================================================

# === 0. 基本設定 & パス設定 (Basic Settings & Path) ===
typeset -U path PATH

# PATH設定 (配列定義・重複排除・存在チェックなしで高速に追加)
path=(
    "/opt/homebrew/bin"
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
# 毎回 brew --prefix や xcrun を叩くと遅いため、標準パスを優先チェックする
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
    # 開発時以外は不要な場合が多いため、必要な場合のみコメントアウトを外す
    # export SDKROOT="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)"
    :
fi

# === GitHub CLI 補完 (zimfw / completion より前に置く) ===
_zsh_compdir="$HOME/.zsh/completions"
if [[ ! -d "$_zsh_compdir" ]]; then
  mkdir -p "$_zsh_compdir"
fi
fpath=("$_zsh_compdir" $fpath)
if (( $+commands[gh] )); then
  [[ -f "$_zsh_compdir/_gh" ]] || gh completion -s zsh > "$_zsh_compdir/_gh"
fi
unset _zsh_compdir

# === Zimfw (Zsh フレームワーク) ===

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim

# Install missing modules and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]]; then
  source /opt/homebrew/opt/zimfw/share/zimfw.zsh init
fi

# Initialize modules.
source ${ZIM_HOME}/init.zsh

# === 2. 遅延読み込み設定 (Lazy Loading) - 最重要高速化ポイント ===

# --- Conda Lazy Load ---
function conda() {
    unfunction conda
    __conda_setup="$('/Users/mekann/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "/Users/mekann/miniconda3/etc/profile.d/conda.sh" ]; then
            . "/Users/mekann/miniconda3/etc/profile.d/conda.sh"
        else
            export PATH="/Users/mekann/miniconda3/bin:$PATH"
        fi
    fi
    unset __conda_setup
    conda "$@"
}

# --- NVM Lazy Load ---
export NVM_DIR="$HOME/.config/nvm"
function _load_nvm() {
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        . "$NVM_DIR/nvm.sh"
    fi
}
for cmd in nvm node npm pnpm yarn; do
    eval "function $cmd() { unset -f nvm node npm pnpm yarn; _load_nvm; $cmd \"\$@\"; }"
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

# === Ctrl-H で run-help を全文 clipcopy に送る ===
autoload -Uz run-help

run-help-copy-widget() {
  emulate -L zsh

  # 現在の行をシェル単語に分解して先頭のコマンド名を取得
  local cmd
  set -- ${(z)BUFFER}
  cmd="$1"

  if [[ -z "$cmd" ]]; then
    zle -M "no command to lookup"
    return
  fi

  # 出力先コマンドを決定（clipcopy 前提、なければエラー表示）
  local copy_cmd
  if command -v clipcopy >/dev/null 2>&1; then
    copy_cmd=clipcopy
  else
    zle -M "clipcopy not found"
    return 1
  fi

  # pager を殺して run-help の出力をそのまま clipcopy へ
  if PAGER=cat MANPAGER=cat run-help "$cmd" 2>/dev/null | $copy_cmd; then
    zle -M "help copied (clipcopy): $cmd"
  else
    zle -M "no help for: $cmd"
  fi
}

# ZLE に登録して Ctrl-H に割り当て
zle -N run-help-copy-widget
bindkey -r '^H' 2>/dev/null
bindkey '^H' run-help-copy-widget


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
if [[ -f /usr/local/bin/gnuls ]]; then
  alias ls="gnuls --show-control-chars --color=none -F"
elif [[ $OSTYPE == linux* ]]; then
  alias ls="ls --show-control-chars --color=none -F"
else
  alias ls="ls -F -G"
fi

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
load_last_dir

# === 9. 補完設定 (Completion) - fzf-tab用に強化 ===
# ※ compinit は zimfw の completion モジュールに任せる

# 補完オプション
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' ignore-parents parent pwd ..
zstyle ':completion:*:default' menu select=1
zstyle ':completion:*:cd:*' ignore-parents parent pwd

# ★重要: fzf-tab には descriptions (グループ名表示) が必須
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
if [[ -o login ]] && [[ -z "$SSH_AUTH_SOCK" ]]; then
  eval $(ssh-agent) >/dev/null
  ssh-add ~/.ssh/id_rsa 2>/dev/null
fi
alias start-ssh='eval $(ssh-agent) && ssh-add ~/.ssh/id_rsa'

# kiro
[[ "$TERM_PROGRAM" == "kiro" && (( $+commands[kiro] )) ]] && . "$(kiro --locate-shell-integration-path zsh)"

# zoxide
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# TERM
if [[ $TERM == "xterm" ]]; then export TERM=xterm-color; fi

# uv
if command -v uv >/dev/null 2>&1; then
  eval "$(uv generate-shell-completion zsh)"
fi

# === 11. ターミナルタイトル ===
function xtitle { print -Pn "\e]2;%~\a"; }
add-zsh-hook precmd xtitle
xtitle


# === 12. 独自ツール ===========================================

## === fgit (高速リポジトリ移動) ===
fgit() {
  emulate -L zsh
  local base=${1:-$HOME}
  local cmd_repos cmd_grep

  if command -v fd >/dev/null 2>&1; then
    cmd_repos="fd -H -I -t d --max-depth 5 '^.git$' '$base' -x echo {//}"
  else
    cmd_repos="find '$base' -maxdepth 5 -name .git -type d 2>/dev/null | sed 's|/\.git$||'"
  fi

  if command -v rg >/dev/null 2>&1; then
    cmd_grep="rg --files-with-matches --glob 'README*' --smart-case {q} '$base' | sed 's|/[^/]*$||'"
  else
    cmd_grep="grep -rl --include='README*' {q} '$base' 2>/dev/null | sed 's|/[^/]*$||'"
  fi

  local preview_cmd='
    target={}
    if [ -d "$target" ]; then
      readme=$(find "$target" -maxdepth 1 -iname "readme*" -print-quit 2>/dev/null)
      if [ -n "$readme" ]; then
        if command -v bat >/dev/null 2>&1; then
          bat --style=numbers --color=always --line-range :100 "$readme"
        else
          head -n 100 "$readme"
        fi
      else
        echo "\x1b[33m[No README found]\x1b[0m"
        if command -v eza >/dev/null 2>&1; then
          eza --tree --level=1 --color=always "$target"
        else
          ls -F --color=always "$target" | head -n 20
        fi
      fi
    else
      echo "Not a directory: $target"
    fi
  '

  local selected
  selected=$(fzf --ansi \
    --layout=reverse --border --prompt='Repos> ' \
    --header='ENTER:Go | CTRL-G:Switch Mode (Repos <-> Grep)' \
    --preview="$preview_cmd" \
    --preview-window='right:60%:border-rounded:wrap' \
    --bind "start:reload:$cmd_repos" \
    --bind "ctrl-g:transform:
      if [[ \"{fzf:prompt}\" == \"Repos> \" ]]; then
        echo 'change-prompt(Grep> )+clear-query+rebind(change)+reload($cmd_grep)'
      else
        echo 'change-prompt(Repos> )+unbind(change)+reload($cmd_repos)'
      fi" \
    --bind "change:transform:
      if [[ \"{fzf:prompt}\" == \"Grep> \" ]]; then
        echo 'reload($cmd_grep)'
      fi"
  )

  if [[ -n "$selected" && -d "$selected" ]]; then
    cd "$selected" || return 1
    echo "Moved to \033[32m$selected\033[0m"
  fi
}

## === tt (タイマー) ===
tt() {
  if [ -z "$1" ]; then
    echo "Usage: tt <time> [label] (e.g., tt 5, tt 1h30m)"
    return 1
  fi

  local input="$1"
  shift
  local duration=""

  if [[ "$input" =~ ^[0-9]+$ ]]; then
    duration="00:${input}:00"
  else
    local h=$(echo "$input" | grep -oE '[0-9]+h' | tr -d 'h')
    local m=$(echo "$input" | grep -oE '[0-9]+m' | tr -d 'm')
    local s=$(echo "$input" | grep -oE '[0-9]+s' | tr -d 's')
    h=${h:-0}; m=${m:-0}; s=${s:-0}
    duration=$(printf "%02d:%02d:%02d" $h $m $s)
  fi

  echo "⏱️  Starting timer: $duration ($input)"
  timr-tui -c "$duration" -m countdown "$@"

  if [ $? -eq 0 ]; then
    echo -e "\a"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      osascript -e "display notification \"Finished: $input\" with title \"Timer Done\" sound name \"Glass\""
    fi
  fi
}

## === fcp (FZF フルパスコピー) ===
fcp() {
  local selected
  selected=$(fzf --height 40% --layout=reverse --border)

  if [[ -n "$selected" ]]; then
    local abs_path="${selected:A}"
    local result="\"${abs_path}\""

    if [[ "$OSTYPE" == darwin* ]]; then
      echo -n "$result" | pbcopy
    elif [[ -n "$WSL_DISTRO_NAME" ]]; then
      echo -n "$result" | clip.exe
    elif command -v wl-copy >/dev/null; then
      echo -n "$result" | wl-copy
    elif command -v xclip >/dev/null; then
      echo -n "$result" | xclip -selection clipboard
    elif command -v xsel >/dev/null; then
      echo -n "$result" | xsel -b
    else
      echo "クリップボードコマンドが見つかりませんでした。"
      echo "パス: $result"
      return 1
    fi
    echo "Copied: $result"
  fi
}

## === eza スマート設定 ===
# 既存エイリアス解除
for a in t tg g gg l ll la ee; do unalias "$a" 2>/dev/null; done

_eza_supports() { command eza --help 2>&1 | grep -q -- "$1"; }
typeset -a EZA_BASE_OPTS EZA_TREE_OPTS EZA_GRID_OPTS EZA_COLOR_ALWAYS
EZA_BASE_OPTS=()

_eza_supports --group-directories-first && EZA_BASE_OPTS+=(--group-directories-first)
_eza_supports --icons                   && EZA_BASE_OPTS+=(--icons)

EZA_TREE_OPTS=(-T -L 2 -l -h)
_eza_supports --git         && EZA_TREE_OPTS+=(--git)
_eza_supports --header      && EZA_TREE_OPTS+=(--header)
_eza_supports --quoting     && EZA_TREE_OPTS+=(--quoting=auto)
_eza_supports --time-style  && EZA_TREE_OPTS+=(--time-style=long-iso)

EZA_GRID_OPTS=()
: ${EZA_IGNORE_GLOB:="node_modules|.git|dist|build|.next|target|venv|.venv"}
: ${EZA_MAX_LINES:=80}

if command eza --help 2>&1 | grep -q -- '--color'; then
  EZA_COLOR_ALWAYS=(--color=always)
elif command eza --help 2>&1 | grep -q -- '--colour'; then
  EZA_COLOR_ALWAYS=(--colour=always)
else
  EZA_COLOR_ALWAYS=()
fi

ee() { command eza "${EZA_BASE_OPTS[@]}" "$@"; }

_eza_smart() {
  [[ -t 1 ]] || return 0
  local tmp; tmp=$(mktemp -t eza_out.XXXXXX)

  if _eza_supports --ignore-glob; then
    ee "${EZA_COLOR_ALWAYS[@]}" "${EZA_TREE_OPTS[@]}" --ignore-glob "$EZA_IGNORE_GLOB" >"$tmp" 2>/dev/null
  else
    ee "${EZA_COLOR_ALWAYS[@]}" "${EZA_TREE_OPTS[@]}" >"$tmp" 2>/dev/null
  fi

  local lines; lines=$(wc -l <"$tmp" | tr -d ' ')
  if (( ${lines:-0} <= EZA_MAX_LINES )); then
    cat "$tmp"
  else
    ee "${EZA_GRID_OPTS[@]}"
  fi
  rm -f "$tmp"
}

chpwd() { _eza_smart }

# eza ショートカット
t()  {
  if _eza_supports --ignore-glob; then
    ee "${EZA_TREE_OPTS[@]}" --ignore-glob "$EZA_IGNORE_GLOB" "$@"
  else
    ee "${EZA_TREE_OPTS[@]}" "$@"
  fi
}
tg() {
  local opts=(-T -L 3 -l -h)
  _eza_supports --git         && opts+=(--git)
  _eza_supports --header      && opts+=(--header)
  _eza_supports --quoting     && opts+=(--quoting=auto)
  _eza_supports --time-style && opts+=(--time-style=long-iso)
  if _eza_supports --ignore-glob; then
    ee "${opts[@]}" --ignore-glob "$EZA_IGNORE_GLOB" "$@"
  else
    ee "${opts[@]}" "$@"
  fi
}
g()  { ee "${EZA_GRID_OPTS[@]}" "$@"; }
gg() { _eza_supports --git && ee --git "$@" || ee "$@"; }
l()  { ee -1 "$@"; }
ll() {
  local opts=(-l -h)
  _eza_supports --header && opts+=(--header)
  _eza_supports --git    && opts+=(--git)
  _eza_supports --quoting && opts+=(--quoting=auto)
  _eza_supports --time-style && opts+=(--time-style=long-iso)
  ee "${opts[@]}" "$@"
}
la() {
  local opts=(-la -h)
  _eza_supports --header && opts+=(--header)
  _eza_supports --git    && opts+=(--git)
  _eza_supports --quoting && opts+=(--quoting=auto)
  _eza_supports --time-style && opts+=(--time-style=long-iso)
  ee "${opts[@]}" "$@"
}

## === ls オーバーライド ===
unalias ls 2>/dev/null
ls() {
  if [[ $# -eq 0 ]]; then
    _eza_smart
  else
    command ls "$@"
  fi
}

# === 13. 補完の高度な設定 (fzf-tab & Git) =====================

# --- 1. fzf-tab 基本設定 ---
# プレビュー表示の有無やキーバインド
zstyle ':fzf-tab:*' fzf-command fzf
zstyle ':fzf-tab:*' fzf-min-height 20
zstyle ':fzf-tab:*' fzf-bindings 'ctrl-/:toggle-preview'

# --- 2. Git 補完のソート無効化 (時系列維持) ---
# Zsh側のソートを無効化 (Git系コマンド全体に適用)
zstyle ':completion:*:git-*' sort false
zstyle ':completion:*:git-*' rehash true

# fzf側のソートも無効化 (入ってきた順序=日付順で表示)
zstyle ':fzf-tab:complete:git-*' fzf-flags --no-sort

# --- 3. プレビュー設定 (Preview) ---
# git checkout / switch / restore: コミットグラフと情報を表示
# {1} は対象の単語(ブランチ名やハッシュ)に置換される
zstyle ':fzf-tab:complete:git-(checkout|switch|restore):*' fzf-preview \
	'git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %s" {1} | head -20'

# git diff / add / reset: 変更内容を表示
zstyle ':fzf-tab:complete:git-(diff|add|reset):*' fzf-preview \
	'git show --color=always $word | head -20'

# kill コマンドのプロセスID補完時に ps の結果をプレビュー
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview \
  '[[ $group == "[process ID]" ]] && ps --pid=$word -o cmd --no-headers -w -w'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:3:wrap

# === 14. FZF key bindings (Ctrl-R / Ctrl-T / Alt-C など) ===
# すべての bindkey / プラグイン読み込みが終わったあとで読む
if [[ -f ~/.fzf.zsh ]]; then
  source ~/.fzf.zsh
fi

# === 15. Ctrl-J: ripgrep + fzf 検索 ===
# rg と fzf が入っているときだけ有効にする
if (( $+commands[rg] )) && (( $+commands[fzf] )); then
  fzf-ripgrep-widget() {
    emulate -L zsh

    local query selected file line

    # いまのコマンドライン全体をクエリとして使う
    query="$LBUFFER$RBUFFER"
    [[ -z $query ]] && return 0

    # 画面をいったん解放（fzf に画面を使わせる）
    zle -I

    # ripgrep の結果を fzf に流し込む
    selected=$(
      rg --line-number --no-heading --color=always "$query" 2>/dev/null |
        fzf --ansi --delimiter : --nth 3.. \
            --preview 'bat --style=numbers --color=always --line-range :200 {1} 2>/dev/null || head -n 200 {1}' \
            --preview-window='right:60%:border-rounded:wrap'
    )

    # fzf を抜けたら ZLE を再描画
    zle redisplay

    # キャンセルされたら何もしない
    [[ -z $selected ]] && return 0

    # "file:line:..." から file / line を取り出す
    file=${selected%%:*}
    line=${${selected#*:}%%:*}

    # エディタで開くコマンドをバッファに詰めて実行
    BUFFER="vim +${line} ${(q)file}"
    CURSOR=${#BUFFER}
    zle accept-line
  }

  zle -N fzf-ripgrep-widget
  bindkey '^J' fzf-ripgrep-widget
fi

alias dot='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias lazydot='lazygit --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

