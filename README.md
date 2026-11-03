# DosMemo

macOS 13以降向けの軽量テキストエディタ。日本語・英語UI、検索・置換、フォント・折り返し設定、文字コードと改行コードの保持に対応します。

## インストール

GitHub ReleasesのDMGを開き、DosMemo.appをApplicationsへドラッグしてください。
配布ビルドはアドホック署名で、Appleによる公証はありません。初回起動がブロックされた場合の手順は同梱のINSTALL.txtを参照してください。

## ビルド

XcodeまたはSwift 5.9以降のツールチェーンが必要です。

```sh
bash build.sh release
bash release.sh
```

`release.sh` はホストのCPU向けにReleaseビルドし、`dist/` にDMGとSHA-256チェックサムを出力します。

## GitHubへの公開

通常のターミナルで次を実行してください。セットアップはGitHub公式のCLIをプロジェクト内の`.tools/bin`に導入し、ブラウザ経由で認証します。

```sh
bash setup-github.sh
bash publish.sh otti83/DosMemo
```

リポジトリが存在しない場合は公開リポジトリとして作成し、ソースとバージョンタグをpushして、DMGをGitHub Releaseに添付します。
