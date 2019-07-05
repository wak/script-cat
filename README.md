# Script Cat

## 概要
ターミナルエミュレータのログに含まれる制御コードを削除します。

対象とするログは、以下の2種類です。
  - TeraTermのバイナリログ
  - scriptコマンドで取得したログ


## 使い方
- 標準入力から読み込み、標準出力に結果を出力する。
  - `./script-cat.rb < a.log`
  
- ファイルから読み込み、標準出力に結果を出力する。
  - `./script-cat.rb a.log`

- ファイルから読み込み、ファイル名に追加の拡張子をつけたパスに出力する。
  - `./script-cat.rb -i.txt a.log`


## 補足
TeraTermのバイナリログの整形は、
基本的には、ログの再生機能がいいと思います。

```
start C:\apps\teraterm\ttermpro.exe /R=%1 /NOLOG
```
