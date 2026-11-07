# JobPilot — исправление сборки (7 ноября 2026)

## Причина ошибки

В `catch { ... }` в Swift имя `error` по умолчанию обозначает перехваченную ошибку, а не `@State private var error: ErrorNotice?` из SwiftUI View. Строка `error = ErrorNotice(error)` пытается присвоить значение неизменяемому объекту ошибки и не проходит компиляцию.

Исправление — `self.error = ErrorNotice(error)`: `self.error` — состояние представления, а параметр конструктора `ErrorNotice(error)` — перехваченная ошибка.

## Изменённые файлы

- `JobPilot/Views/Vacancies/VacancyFormView.swift` — 1 место (строка 118 исходного файла)
- `JobPilot/Views/Vacancies/VacancyDetailView.swift` — 7 мест
- `JobPilot/Views/Events/EventForms.swift` — 3 места

**Всего 11 исправлений.** Бизнес-логика и настройки GitHub Actions не менялись.

## Установка патча

Содержимое папки `JobPilot/` из ZIP патча положить в корень репозитория, заменив соответствующие три файла. Сделать commit в `main` и запустить Actions заново. Если используете полный архив, в корень репозитория нужно загрузить *содержимое* `JobPilot-build-fix`, а не саму внешнюю папку.

## Проверка

Все `.swift` файлы успешно прошли `swiftc -frontend -parse` на Linux. Такая проверка не заменяет сборку через Xcode с iOS SDK. Успешный `xcodebuild archive`/IPA пока не подтверждён; при новом падении смотреть самую первую строку `error:`.
