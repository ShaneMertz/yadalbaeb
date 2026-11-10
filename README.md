# Kanban CRM (прототип)

Простой канбан на Flutter: три колонки, карточки, перетаскивание, сохранение (shared_preferences: на Mac — файл настроек, в вебе — localStorage).
Сборка DMG под macOS — `.github/workflows/macos-dmg.yml`; веб — `.github/workflows/web.yml` → https://shanemertz.github.io/yadalbaeb/kanban/ (папка kanban/ в main).

Платформенные папки (`macos/`) генерируются в CI через `flutter create`, в репо лежит только код.

Локально: `flutter create --platforms=macos,linux . && flutter run -d macos`.
