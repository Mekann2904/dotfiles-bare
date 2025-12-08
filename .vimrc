"========================================
" 基本設定
"========================================

set background=dark          " ダーク背景を前提にする

set encoding=utf-8           " 内部エンコーディング
set fileencoding=utf-8       " 保存時エンコーディング

if has('termguicolors')
  set termguicolors          " True Color を使う環境なら有効化
endif

" カラースキーム
colorscheme molokai

"========================================
" 透過設定（ColorScheme 変更時にも再適用）
"========================================
augroup TransparentBackground
  autocmd!
  autocmd ColorScheme * highlight Normal         ctermbg=NONE guibg=NONE |
        \ highlight NormalNC       ctermbg=NONE guibg=NONE |
        \ highlight NonText        ctermbg=NONE guibg=NONE |
        \ highlight LineNr         ctermbg=NONE guibg=NONE |
        \ highlight Folded         ctermbg=NONE guibg=NONE |
        \ highlight EndOfBuffer    ctermbg=NONE guibg=NONE |
        \ highlight SignColumn     ctermbg=NONE guibg=NONE |
        \ highlight VertSplit      ctermbg=NONE guibg=NONE |
        \ highlight StatusLine     ctermbg=NONE guibg=NONE |
        \ highlight StatusLineNC   ctermbg=NONE guibg=NONE |
        \ highlight TabLine        ctermbg=NONE guibg=NONE |
        \ highlight TabLineFill    ctermbg=NONE guibg=NONE
augroup END

" 起動直後にも反映しておく
doautocmd ColorScheme

"========================================
" カーソル形状
"========================================
if has('vim_starting')
    " 挿入モード時に非点滅の縦棒タイプのカーソル
    let &t_SI .= "\e[6 q"
    " ノーマルモード時に非点滅のブロックタイプのカーソル
    let &t_EI .= "\e[2 q"
    " 置換モード時に非点滅の下線タイプのカーソル
    let &t_SR .= "\e[4 q"
endif

"========================================
" 表示系
"========================================

" 現在の行を強調表示
set cursorline
" 現在の列を強調表示（必要なら有効化）
"set cursorcolumn

" システムクリップボードと共有
set clipboard=unnamed,unnamedplus

" 行番号を表示
set number

"========================================
" 検索
"========================================

" 検索するときに大文字小文字を区別しない
set ignorecase

" 小文字で検索すると大文字と小文字を無視して検索
set smartcase

" 検索がファイル末尾まで進んだら、ファイル先頭から再び検索
set wrapscan

" インクリメンタル検索 (検索ワードの最初の文字を入力した時点で検索が開始)
set incsearch

" 検索結果をハイライト表示
set hlsearch

" 対応する括弧を強調表示
set showmatch

" シンタックスハイライト
syntax on

" バックスペースを有効化
set backspace=indent,eol,start

" 行末の1文字分超えてカーソルを動かせるようにする
set virtualedit=onemore

" 縦の強調を全部オフ
set nocursorcolumn
set colorcolumn=

"========================================
" タブ / インデント
"========================================

" タブ設定（必要に応じてコメントアウトを外す）
"set expandtab           " タブをスペースに変換
"set tabstop=4           " タブ幅を4に設定
"set shiftwidth=4        " 自動インデントの幅を4に設定

" 自動インデント
set autoindent
set smartindent          " オートインデント

"========================================
" マウス
"========================================

" マウス操作を有効化
set mouse=a
"set ttymouse=xterm2

"========================================
" キーマッピング
"========================================

" <ESC> と同じ役割を追加
inoremap <silent> jjj <ESC>
inoremap <silent> っっｊ <ESC>


set relativenumber
