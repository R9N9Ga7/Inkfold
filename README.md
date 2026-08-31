# Inkfold

Inkfold is a local-first book reader built with Flutter for Android and the web.
The default build supports plain-text books. Format support is provided through
versioned, data-oriented plugins under `packages/`.

## Run

```powershell
flutter pub get
flutter pub run build_runner build
flutter run -d chrome
```

Imported books, progress, bookmarks, and appearance settings stay on the local
device in a Drift database.

## Add a format plugin

Implement `BookFormatPlugin` from `inkfold_reader_api`, expose a versioned
`PluginManifest`, and register the implementation in `pluginCatalogProvider`.
Plugins identify and decode source bytes; the host owns storage, navigation,
reader chrome, and presentation.
