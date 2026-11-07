# JobPilot — исправление ошибок сборки №2

Из лога `xcodebuild archive` исправлены две ошибки компиляции:

1. `JobPilot/Services/DataTransferService.swift`, `exportCSV`: слишком сложное выражение `fetch(...).map { [17 значений] }` вынесено в `csvRow(for:formatter:)`. Столбцы, порядок и формат CSV не изменены.
2. `JobPilot/Views/Events/EventsView.swift`, `dayContent`: `.month(.wide())` исправлено на `.month(.wide)`.

Основа: предыдущая исправленная версия `JobPilot-fixed-full-project.zip`, включая исправления `self.error` в трёх файлах.

## Как обновить

Скопируйте два файла из архива `JobPilot-compile-fix-v2-patch.zip` в соответствующие пути репозитория. Выполните commit в `main`, затем запустите **новый** workflow (не повтор старого commit). 

## Проверка

Все Swift-файлы прошли синтаксический разбор `swiftc -frontend -parse` в Linux. Сборка iOS и типизация с SwiftData/SwiftUI требуют macOS + Xcode и в этой среде не подтверждены. Возможны другие ошибки в следующем логе.
