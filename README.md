# Kanban CRM (прототип)

Простой канбан на Flutter: три колонки, карточки, перетаскивание, сохранение на диск.
Сборка DMG под macOS — GitHub Actions (`.github/workflows/macos-dmg.yml`), артефакт `KanbanCRM.dmg`.

Платформенные папки (`macos/`) генерируются в CI через `flutter create`, в репо лежит только код.

Локально: `flutter create --platforms=macos,linux . && flutter run -d macos`.
