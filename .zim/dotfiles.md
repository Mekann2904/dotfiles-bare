# zimfwで管理しているpluginに関する情報をまとめる

## zsh-abbr

### 使用方法


登録

```
abbr -g git

```

使用

```
g status 

```

exp

```
abbr -g g    git
abbr -g gs   'git status -sb'
abbr -g gd   'git diff'
abbr -g gdc  'git diff --cached'
abbr -g gc   'git commit'
abbr -g gp   'git push'
abbr -g d    docker
abbr -g dc   'docker compose'
```

### 補足

abbr永続化のための設定ファイルの場所を調べる。

```
echo $ABBR_USER_ABBREVIATIONS_FILE
```

自分の環境macの場合は

```
/Users/mekann/.config/zsh-abbr/user-abbreviations

```
