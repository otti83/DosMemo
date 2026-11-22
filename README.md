# DosMemo

macOS 13以降向けの軽量テキストエディタ。日本語・英語UI、検索・置換、フォント・折り返し設定、文字コードと改行コードの保持に対応します。

- 対応形式: テキスト / Markdown / JSON / YAML / XML / plist（バイナリ plist は XML として編集し、バイナリで保存）/ HTML / CSS / JavaScript / シェル / Python / CSV / TSV / TOML / INI / conf / ログ / ソースコード
- Dock アイコンの右クリックメニューから「新規作成」「開く…」

## インストール

GitHub ReleasesのDMGを開き、DosMemo.appをApplicationsへドラッグしてください。
配布ビルドは開発者証明書で署名されていますが、Appleによる公証はありません。初回起動がブロックされた場合の手順は同梱のINSTALL.txtを参照してください。

## ビルド

XcodeまたはSwift 5.9以降のツールチェーンが必要です。

```sh
bash test.sh            # ユニットテスト
bash build.sh release   # DosMemo.app を作成
bash release.sh         # dist/ に DMG と SHA-256 を作成
```

- ビルド成果物はローカルの `~/Library/Caches/com.dosmemo.build`（`DOSMEMO_BUILD_DIR` で変更可）に置きます。ネットワークドライブ上ではSwiftPMのビルドとコード署名が失敗するためです。
- 署名は `Developer ID Application` → `Apple Development` → アドホックの順に自動選択します。`DOSMEMO_SIGN_IDENTITY` で明示指定できます（`-` でアドホック）。Gatekeeper を通すには Developer ID 証明書での署名と公証が必要です。
- 翻訳は `Resources/*.lproj` にあり、`build.sh` がアプリの `Contents/Resources` にコピーします。SwiftPM のリソースバンドル（`Bundle.module`）は使いません。ビルドマシンの絶対パスを参照し、他のMacで起動時にクラッシュするためです。

## GitHubへの公開

通常のターミナルで次を実行してください。セットアップはGitHub公式のCLIをプロジェクト内の`.tools/bin`に導入し、ブラウザ経由で認証します。

```sh
bash setup-github.sh
bash publish.sh otti83/DosMemo
```

リポジトリが存在しない場合は公開リポジトリとして作成し、ソースとバージョンタグをpushして、DMGをGitHub Releaseに添付します。
