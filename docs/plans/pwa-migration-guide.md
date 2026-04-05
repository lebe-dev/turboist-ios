# Turboist iOS — Руководство по реализации

## Содержание

1. [Обзор](#1-обзор)
2. [Архитектура и технологический стек](#2-архитектура-и-технологический-стек)
3. [Модели данных](#3-модели-данных)
4. [Сетевой слой (HTTP API)](#4-сетевой-слой-http-api)
5. [WebSocket-клиент и протокол](#5-websocket-клиент-и-протокол)
6. [Offline-first архитектура](#6-offline-first-архитектура)
7. [Полный реестр функций](#7-полный-реестр-функций)
8. [Логика по экранам/views](#8-логика-по-экранамviews)
9. [Фоновая работа и lifecycle](#9-фоновая-работа-и-lifecycle)
10. [Локализация](#10-локализация)
11. [Безопасность и аутентификация](#11-безопасность-и-аутентификация)
12. [Тестирование](#12-тестирование)
13. [Порядок реализации (фазы)](#13-порядок-реализации-фазы)
14. [API Reference](#14-api-reference)

---

## 1. Обзор

**Turboist** — однопользовательское приложение для управления задачами поверх Todoist. Работает через собственный Go-бэкенд (HTTP REST + WebSocket). iOS-приложение заменяет мобильную PWA-версию, сохраняя десктопную веб-версию.

### Существующий код приложения

Существующий код подмонтирован по пути `turboist-pwa/`.

- PWA - turboist-pwa/frontend
- Backend - turboist-pwa/

### Ключевые принципы

- **Offline-first**: приложение полностью функционально без сети; мутации ставятся в очередь и воспроизводятся при подключении
- **Оптимистичные обновления**: UI обновляется мгновенно, сервер получает изменения асинхронно
- **Реальное время**: WebSocket обеспечивает push-обновления (snapshot/delta) от бэкенда
- **Единый бэкенд**: iOS работает через Go-бэкенд, **без прямых вызовов Todoist API**
- **Синхронизация состояния**: UI-state (активный view, контекст, pinned tasks, collapsed IDs, фильтры) синхронизируется с сервером — веб и iOS работают с одним состоянием

---

## 2. Архитектура и технологический стек

### Рекомендуемый стек

| Компонент | Технология | Обоснование |
|-----------|-----------|-------------|
| UI | SwiftUI | Декларативный, нативный |
| Минимальная iOS | 17.0 | SwiftData, @Observable macro |
| Архитектура | MVVM + Clean Architecture | Тестируемость, разделение слоёв |
| Локальное хранение | SwiftData | Offline-first persistence, нативный для iOS 17 |
| Сеть (HTTP) | URLSession | Нативный, без зависимостей |
| WebSocket | URLSessionWebSocketTask | Нативный WebSocket |
| Keychain | Keychain Services | Хранение session token |
| Packages | Swift Package Manager | Стандарт |

### Слои

```
Presentation (SwiftUI Views + ViewModels @Observable)
        │
   Domain (Models, Use Cases, Repository Protocols)
        │
   Data (APIClient, WebSocketClient, LocalStore, ActionQueue, Repository Implementations)
```

**Ключевой принцип**: ViewModels читают данные из `@Observable` stores. Stores обновляются из двух источников: (1) WebSocket snapshots/deltas, (2) локальные optimistic updates. Stores персистят данные в SwiftData. При холодном старте — мгновенный показ из SwiftData, затем актуализация через WS.

---

## 3. Модели данных

### 3.1. Task (основная модель)

```swift
struct TaskItem: Identifiable, Codable {
    let id: String
    var content: String
    var description: String
    var projectId: String
    var sectionId: String?
    var parentId: String?
    var labels: [String]
    var priority: Int                    // 1 (низкий) — 4 (срочный)
    var due: Due?
    var subTaskCount: Int
    var completedSubTaskCount: Int
    var completedAt: String?             // ISO 8601
    var addedAt: String                  // ISO 8601
    var isProjectTask: Bool
    var postponeCount: Int
    var expiresAt: String?               // ISO 8601, время автоудаления
    var children: [TaskItem]             // Для древовидного представления (вложенность)
}

struct Due: Codable {
    let date: String                     // "YYYY-MM-DD"
    let recurring: Bool
}
```

### 3.2. FlatTask (для локального хранения)

Задачи приходят с бэкенда в древовидном виде (children), но хранятся локально **плоско** (без children, с parent_id). Дерево восстанавливается при чтении через `buildTree()`.

```swift
struct FlatTask: Identifiable, Codable {
    let id: String
    var content: String
    var description: String
    var projectId: String
    var sectionId: String?
    var parentId: String?
    var labels: [String]
    var priority: Int
    var dueDate: String?                 // "YYYY-MM-DD"
    var dueRecurring: Bool
    var subTaskCount: Int
    var completedSubTaskCount: Int
    var completedAt: String?
    var addedAt: String
    var isProjectTask: Bool
    var postponeCount: Int
    var expiresAt: String?
}
```

**Функции конвертации** (критичны для offline):

- `taskToFlat(task: TaskItem) -> FlatTask` — убирает children, разбивает due на dueDate + dueRecurring
- `flatToTask(flat: FlatTask, children: [TaskItem]) -> TaskItem` — собирает обратно
- `flattenTasks(tasks: [TaskItem]) -> [FlatTask]` — рекурсивно раскладывает дерево в плоский массив (depth-first)
- `buildTree(from flats: [FlatTask]) -> [TaskItem]` — группирует по parentId, собирает дерево

### 3.3. Вспомогательные модели

```swift
struct Project: Identifiable, Codable {
    let id: String
    let name: String
    let color: String
    var sections: [Section]
}

struct Section: Identifiable, Codable {
    let id: String
    let name: String
    let projectId: String
    let order: Int
}

struct Label: Identifiable, Codable {
    let id: String
    let name: String
    let color: String
    let order: Int
}

struct TaskContext: Identifiable, Codable {
    let id: String
    let displayName: String
    var color: String?
    var inheritLabels: Bool              // наследовать лейблы контекста при создании задач
    var filters: ContextFilters
}

struct ContextFilters: Codable {
    var projects: [String]               // названия проектов (OR)
    var sections: [String]               // названия секций (OR)
    var labels: [String]                 // названия лейблов (OR)
    // Между категориями — AND (задача должна попасть во все непустые)
}

struct TasksMeta: Codable {
    var context: String
    var weeklyLimit: Int
    var weeklyCount: Int
    var backlogLimit: Int
    var backlogCount: Int
    var inboxCount: Int?
    var lastSyncedAt: String?
}

enum TaskView: String, Codable, CaseIterable {
    case all, inbox, today, tomorrow, weekly, backlog, completed
}

struct PinnedTask: Codable, Identifiable {
    let id: String
    let content: String
}

struct DayPart: Codable {
    let label: String
    let start: Int                       // час 0-23
    let end: Int                         // час 0-23
}
```

### 3.4. UserState (синхронизируемое UI-состояние)

Это состояние UI, которое синхронизируется между веб- и iOS-клиентами через бэкенд.

```swift
struct UserState: Codable {
    var pinnedTasks: [PinnedTask]        // закреплённые задачи (до max_pinned)
    var activeContextId: String          // активный контекст
    var activeView: String               // "all", "inbox", "today", etc.
    var collapsedIds: [String]           // ID свёрнутых родительских задач
    var sidebarCollapsed: Bool           // состояние sidebar (для веба, iOS может игнорировать)
    var planningOpen: Bool               // открыт ли режим планирования
    var dayPartNotes: [String: String]   // dayPartLabel → заметка
    var locale: String                   // "" | "en" | "ru"
    var allFilters: AllFiltersState?     // фильтры для view "All Tasks"
}

struct AllFiltersState: Codable {
    var selectedPriorities: [Int]        // [1, 2, 3, 4]
    var selectedLabels: [String]
    var linksOnly: Bool                  // только задачи со ссылками
    var filtersExpanded: Bool            // развёрнута ли панель фильтров
}
```

### 3.5. AppConfig (полная конфигурация из GET /api/config)

```swift
struct AppConfig: Codable {
    let settings: Settings
    let contexts: [TaskContext]
    let projects: [Project]
    let labels: [Label]
    let labelConfigs: [LabelConfig]
    let autoLabels: [AutoLabelMapping]
    let quickCapture: QuickCaptureConfig?
    let projectTasks: [ProjectTask]
    let labelProjectMap: [LabelProjectMapping]
    let autoRemove: AutoRemoveStatus
    let state: UserState                 // начальное UI-состояние
}

struct Settings: Codable {
    let pollInterval: Int                // сек, интервал опроса бэкенда (информативно)
    let syncInterval: Int                // сек, интервал auto-flush очереди действий
    let timezone: String                 // IANA timezone ("Europe/Moscow")
    let weeklyLabel: String              // имя лейбла для weekly
    let backlogLabel: String             // имя лейбла для backlog
    let projectLabel: String
    let projectsLabel: String
    let weeklyLimit: Int                 // максимум задач weekly
    let backlogLimit: Int                // максимум задач backlog
    let completedDays: Int               // за сколько дней показывать completed
    let maxPinned: Int                   // максимум pinned (обычно 5)
    let lastSyncedAt: String?
    let dayParts: [DayPart]              // части дня для today/tomorrow
    let maxDayPartNoteLength: Int        // максимальная длина заметки для dayPart
    let inboxProjectId: String           // ID inbox-проекта
    let inboxLimit: Int                  // предупреждение при превышении
    let inboxOverflowTaskContent: String // текст задачи-предупреждения
}

struct LabelConfig: Codable {
    let name: String
    let inheritToSubtasks: Bool          // наследовать лейбл подзадачам (default true)
}

struct AutoLabelMapping: Codable {
    let mask: String                     // подстрока для поиска в заголовке
    let label: String                    // лейбл для автодобавления
    let ignoreCase: Bool                 // регистронезависимый поиск (default true)
}

struct QuickCaptureConfig: Codable {
    let title: String                    // название (информативно)
    // parentId определяется на бэкенде — задача создаётся с parent_id из конфига
}

struct ProjectTask: Codable, Identifiable {
    let id: String
    let content: String
}

struct LabelProjectMapping: Codable {
    let label: String
    let project: String
    let section: String?
}

struct AutoRemoveStatus: Codable {
    let rules: [AutoRemoveRule]
    let paused: Bool                     // приостановлено ли автоудаление
}

struct AutoRemoveRule: Codable {
    let label: String
    let ttl: Int                         // секунды до автоудаления
}
```

### 3.6. JSON Convention

Все ключи JSON в `snake_case`. Использовать:

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

let encoder = JSONEncoder()
encoder.keyEncodingStrategy = .convertToSnakeCase
```

---

## 4. Сетевой слой (HTTP API)

### 4.1. Аутентификация

- Cookie-based: `turboist_token` (HttpOnly, SameSite=Lax)
- `POST /api/auth/login { password }` → сервер устанавливает cookie
- `URLSession` с `HTTPCookieStorage.shared` автоматически управляет cookies
- При 401 → показать экран логина
- Session token дополнительно сохранять в Keychain для надёжности

### 4.2. Обработка ошибок

| Код | Поведение |
|-----|-----------|
| 200-204 | Успех |
| 401 | Сессия истекла → LoginView |
| 404 на мутации | Задача уже удалена → считать успехом (удалить из очереди) |
| 429 | Rate limit → exponential backoff: `2s × 2^retry` |
| 5xx | Серверная ошибка → exponential backoff: `1s × 2^retry` |
| Нет сети | Мутация → в ActionQueue; чтение → из локального кеша |

### 4.3. Request/Response типы

```swift
// --- Создание задачи ---
struct CreateTaskRequest: Codable {
    let content: String
    var description: String = ""
    var labels: [String] = []
    var priority: Int = 1
    var parentId: String?
    var dueDate: String?                 // "YYYY-MM-DD"
}
// Response: { ok: true, id: "task_id" }

// --- Обновление задачи ---
struct UpdateTaskRequest: Codable {
    var content: String?
    var description: String?
    var labels: [String]?
    var priority: Int?
    var dueDate: String?                 // "YYYY-MM-DD"
    var dueString: String?               // "every day", "every monday" (парсится бэкендом)
}
// Response: { ok: true }
// Примечание: dueString имеет приоритет над dueDate

// --- Декомпозиция ---
struct DecomposeRequest: Codable {
    let tasks: [String]                  // массив content-строк для новых подзадач
}
// Создаёт подзадачи с наследованием свойств, удаляет исходную задачу

// --- Batch update labels ---
struct BatchUpdateLabelsRequest: Codable {
    let updates: [String: [String]]      // taskId → [new_labels]
}
// Response: { ok: true, updated: count }

// --- Move task ---
struct MoveTaskRequest: Codable {
    let parentId: String                 // сделать подзадачей указанной задачи
}

// --- Tasks response (для всех GET /api/tasks/*) ---
struct TasksResponse: Codable {
    let tasks: [TaskItem]
    let meta: TasksMeta
}

// --- Completed subtasks ---
struct CompletedSubtasksResponse: Codable {
    let tasks: [TaskItem]
}
```

---

## 5. WebSocket-клиент и протокол

### 5.1. Подключение

WebSocket: `ws(s)://<host>/api/ws` с cookie `turboist_token`.

### 5.2. Сообщения Client → Server

```swift
// Подписка на канал
{
    "type": "subscribe",
    "channel": "tasks" | "planning",
    "view": "all" | "inbox" | "today" | "tomorrow" | "weekly" | "backlog",  // для tasks
    "context": "contextId",             // опционально
    "seq": 1                            // монотонный номер подписки
}

// Отписка
{ "type": "unsubscribe", "channel": "tasks" | "planning" }

// Ответ на ping
{ "type": "pong" }
```

### 5.3. Сообщения Server → Client

```swift
// Envelope
{
    "type": "snapshot" | "delta" | "ping" | "error",
    "channel": "tasks" | "planning",
    "data": { ... },                    // зависит от type + channel
    "message": "error text",            // для type=error
    "seq": 1                            // для сопоставления с подпиской
}
```

**Канал `tasks`:**

```swift
// Snapshot (полный список)
data: {
    "tasks": [TaskItem],                // древовидный формат
    "meta": TasksMeta
}

// Delta (инкрементальное обновление)
data: {
    "upserted": [TaskItem],             // изменённые/новые (древовидные)
    "removed": ["taskId1", "taskId2"],  // ID удалённых
    "meta": TasksMeta
}
```

**Канал `planning`:**

```swift
// Snapshot
data: {
    "backlog": [TaskItem],
    "weekly": [TaskItem],
    "meta": TasksMeta
}

// Delta
data: {
    "backlog_upserted": [TaskItem]?,
    "backlog_removed": ["id"]?,
    "weekly_upserted": [TaskItem]?,
    "weekly_removed": ["id"]?,
    "meta": TasksMeta
}
```

### 5.4. Поведение клиента

**Reconnect:**
- Exponential backoff: 1s → 2s → 4s → 8s → 16s → 30s (max)
- При успешном подключении → сброс delay на 1s
- При reconnect → автоматическая переподписка на все активные каналы
- При reconnect → flush ActionQueue

**Подписки:**
- Каждая подписка получает монотонный `seq`
- При смене view/context → отписка + новая подписка (новый seq)
- Сообщения с устаревшим `seq` игнорируются
- Сервер отправляет snapshot при каждой подписке

**Ping/Pong:**
- Сервер отправляет `ping` каждые 30 секунд
- Клиент отвечает `pong`
- Если нет ping 60 секунд → считать соединение разорванным

**Delta merge (критичная логика):**

```swift
// Merge upserted в существующий массив
func mergeUpserted(existing: [TaskItem], upserted: [TaskItem]) -> [TaskItem] {
    var result = existing
    for task in upserted {
        if let idx = result.firstIndex(where: { $0.id == task.id }) {
            result[idx] = task          // Заменить существующую
        } else {
            result.append(task)         // Добавить новую
        }
    }
    return result
}

// Удалить задачи по ID (рекурсивно — удалить и из children)
func filterByIds(tasks: [TaskItem], removeIds: Set<String>) -> [TaskItem] {
    tasks.compactMap { task in
        guard !removeIds.contains(task.id) else { return nil }
        var filtered = task
        filtered.children = filterByIds(tasks: task.children, removeIds: removeIds)
        return filtered
    }
}
```

---

## 6. Offline-first архитектура

Это **самая критичная часть** приложения. Архитектура реплицирует паттерны веб-версии, адаптированные под iOS.

### 6.1. Общая схема

```
┌───────────┐
│  SwiftUI  │  читает @Observable stores
│   Views   │
└─────┬─────┘
      │
┌─────▼──────┐
│ ViewModels  │  оптимистичные мутации + чтение
│(@Observable)│
└─────┬──────┘
      │
      ├──────────────────┬──────────────────┐
      │                  │                  │
┌─────▼─────┐    ┌───────▼──────┐   ┌──────▼───────┐
│ SwiftData  │    │  WebSocket   │   │ ActionQueue  │
│ (кеш задач │    │  Client      │   │ (очередь     │
│  + мета)   │    │              │   │  мутаций)    │
└─────┬──────┘    └──────┬───────┘   └──────┬───────┘
      │           snapshots/deltas     flush (HTTP)
      │                  │                  │
      └──────────────────┴──────────────────┘
                         │
                    Go Backend
```

### 6.2. Три слоя хранения данных

| Слой | Назначение | Технология |
|------|-----------|------------|
| **Reactive** | Источник правды для UI | `@Observable` stores (in-memory) |
| **Persistent** | Offline-кеш для мгновенного старта | SwiftData entities |
| **Queue** | Offline-мутации для replay | SwiftData QueuedActionEntity |

Аналог из веб-версии:
- `$state` → `@Observable`
- Y.Doc + y-indexeddb → SwiftData
- IndexedDB actionQueue → SwiftData QueuedActionEntity

### 6.3. SwiftData Entities

```swift
@Model
class TaskEntity {
    @Attribute(.unique) var id: String
    var content: String
    var taskDescription: String          // "description" — reserved keyword
    var projectId: String
    var sectionId: String?
    var parentId: String?
    var labels: [String]
    var priority: Int
    var dueDate: String?
    var dueRecurring: Bool
    var subTaskCount: Int
    var completedSubTaskCount: Int
    var completedAt: String?
    var addedAt: String
    var isProjectTask: Bool
    var postponeCount: Int
    var expiresAt: String?
    
    // Метаданные хранения
    var channel: String                  // "tasks", "backlog", "weekly", "completed"
    var updatedLocally: Date
}

@Model
class QueuedActionEntity {
    @Attribute(.unique) var id: UUID
    var type: String                     // "createTask", "updateTask", etc.
    var payload: Data                    // JSON-encoded
    var createdAt: Date
    var status: String                   // "pending", "processing", "failed"
    var retryCount: Int
    var errorMessage: String?
}

@Model
class CachedConfigEntity {
    @Attribute(.unique) var key: String  // "appConfig"
    var data: Data                       // JSON-encoded AppConfig
    var updatedAt: Date
}

@Model
class CachedMetaEntity {
    @Attribute(.unique) var channel: String
    var data: Data                       // JSON-encoded TasksMeta
    var updatedAt: Date
}
```

### 6.4. ActionQueue — очередь offline-мутаций

**Типы действий:**

```swift
enum ActionType: String, Codable {
    case createTask
    case updateTask
    case completeTask
    case deleteTask
    case duplicateTask
    case decomposeTask
    case moveTask
    case batchUpdateLabels
    case resetWeeklyLabel
    case patchState
}
```

**Payloads:**

| ActionType | Payload |
|------------|---------|
| `createTask` | `{ data: CreateTaskRequest, context?: String, tempId?: String }` |
| `updateTask` | `{ id: String, data: UpdateTaskRequest }` |
| `completeTask` | `{ id: String }` |
| `deleteTask` | `{ id: String }` |
| `duplicateTask` | `{ id: String }` |
| `decomposeTask` | `{ id: String, data: DecomposeRequest }` |
| `moveTask` | `{ id: String, parentId: String }` |
| `batchUpdateLabels` | `{ updates: [String: [String]] }` |
| `resetWeeklyLabel` | `{}` (пустой) |
| `patchState` | `{ update: Partial<UserState> }` |

**Coalescing (слияние):**

Если в очереди уже есть pending-действие того же типа для того же объекта, вместо создания нового — обновить существующее:

- **updateTask**: merge payload для того же task ID (последние значения каждого поля)
- **patchState**: merge state patches через dictionary merge

**Flush (воспроизведение):**

1. Выбрать все pending действия, отсортированные по `createdAt` ASC (FIFO)
2. Для каждого:
   - Установить status = "processing"
   - Выполнить HTTP-запрос
   - При успехе → удалить из базы
   - При ошибке:
     - 401 → **остановить flush** полностью (сессия невалидна)
     - 404 на мутации → считать успехом (задача удалена)
     - 429/5xx → increment retryCount, status = "pending"
     - retryCount >= 3 → status = "failed"
3. Обновить `pendingCount`

**Триггеры flush:**

- **Eager flush**: через 50ms после enqueue (debounce для coalescing)
- **Auto-flush**: каждые `syncInterval` секунд (из Settings, обычно 60s)
- **Reconnect flush**: при reconnect WebSocket
- **Manual flush**: при pull-to-refresh
- **Visibility flush**: при уходе в background (попытаться отправить pending)

### 6.5. Optimistic Updates (оптимистичные мутации)

**Паттерн** (идентичен веб-версии):

```
Мутация:
1. Обновить in-memory store мгновенно (пользователь видит результат)
2. Персистить в SwiftData
3. Enqueue в ActionQueue

Чтение (getter задач):
1. Взять flatTasks из store
2. Применить pendingRemovals (Set<String> с ID задач, ожидающих удаления)
3. Применить pendingUpdates (overlay из ActionQueue)
4. Собрать дерево через buildTree()
5. Вернуть
```

**Конкретные мутации:**

| Действие | Локальное обновление | Server action |
|----------|---------------------|---------------|
| Complete | Добавить id в `pendingRemovals` | `POST /api/tasks/:id/complete` |
| Delete | Добавить id в `pendingRemovals` | `DELETE /api/tasks/:id` |
| Update | Изменить FlatTask в массиве + persist | `PATCH /api/tasks/:id` |
| Create | Prepend FlatTask с tempId в массив | `POST /api/tasks` |
| Duplicate | Insert copy после оригинала с tempId | `POST /api/tasks/:id/duplicate` |
| Move | Изменить parentId в FlatTask | `POST /api/tasks/:id/move` |
| Add label | Изменить labels в FlatTask | `PATCH /api/tasks/:id` (labels) |
| Remove label | Изменить labels в FlatTask | `PATCH /api/tasks/:id` (labels) |

### 6.6. Temp Task ID Reconciliation

При создании задачи offline:

1. Сгенерировать `tempId` = `"temp-\(UUID().uuidString)"`
2. Добавить задачу в локальный массив с `tempId`
3. Enqueue `createTask` с `tempId` в payload
4. При flush → API возвращает реальный `id` в response
5. **Reconciliation:**
   - Заменить `tempId` на реальный `id` в flatTasks
   - Обновить все ссылки: `parentId` у подзадач, pinnedTasks, collapsedIds
   - Обновить SwiftData entity
6. Если до reconciliation придёт WS snapshot/delta с реальным `id` — удалить temp-запись, использовать серверную версию

### 6.7. Инициализация приложения

Последовательность при запуске (аналог `appStore.init()` в вебе):

```
1. Проверить аутентификацию (GET /api/auth/me)
   ├── 401 → LoginView
   └── OK ↓

2. Загрузить pending actions из SwiftData → обновить pendingCount

3. Загрузить кешированные задачи из SwiftData
   └── Показать мгновенно в UI (stale, но быстро)

4. Загрузить AppConfig:
   ├── GET /api/config
   ├── При ошибке → использовать кешированный из SwiftData
   └── При успехе → обновить кеш, раздать stores

5. Подключить WebSocket
   └── subscribe("tasks", currentView, currentContext)

6. При получении snapshot:
   ├── Заменить in-memory store
   ├── Persist в SwiftData
   └── Сбросить offline-флаг

7. Запустить auto-flush очереди (interval = syncInterval)

8. Выполнить flushNow() → воспроизвести pending мутации
```

### 6.8. Stale Data Detection

- Порог: **2 минуты** без обновления от WebSocket
- Если данные stale → показать индикатор
- **Offline grace period**: **5 секунд** после потери WS — не показывать offline-баннер сразу (краткие обрывы сети)

### 6.9. Конфликтные ситуации

Поскольку приложение однопользовательское, конфликты маловероятны, но возможны:

- **Задача удалена на вебе, но обновляется в offline-очереди iOS** → 404 при flush → считать успехом
- **Задача обновлена и на вебе, и в очереди iOS** → последний writer побеждает (WS delta обновит данные)
- **Snapshot приходит после локального optimistic update** → snapshot перезаписывает (серверная правда), pending overlay продолжает действовать до flush

---

## 7. Полный реестр функций

### 7.1. Управление задачами (CRUD)

- [x] **Создание задачи** — content (обязательно), description, priority, labels, due_date, parent_id
- [x] **Просмотр задачи** — все поля + подзадачи + завершённые подзадачи
- [x] **Редактирование задачи** — content, description, priority, labels, due_date, due_string
- [x] **Завершение задачи** — отметка checkbox, optimistic removal из списка
- [x] **Удаление задачи** — с подтверждением, удаляет и все подзадачи
- [x] **Дублирование задачи** — клон content, description, labels, priority, due_date, parent
- [x] **Декомпозиция задачи** — разбить на N подзадач (многострочный ввод), исходная удаляется
- [x] **Перемещение задачи** — сделать подзадачей другой задачи (move с parent_id)

### 7.2. Подзадачи

- [x] **Создание подзадачи** — через parent_id
- [x] **Древовидное отображение** — задачи с indent'ом по уровню вложенности
- [x] **Свёртывание/развёртывание** подзадач (collapsed_ids, персистится на сервер)
- [x] **Прогресс подзадач** — `completed_sub_task_count / sub_task_count`
- [x] **Загрузка завершённых подзадач** — по запросу (`GET /api/tasks/:id/completed-subtasks`)
- [x] **Навигация к родительской задаче** — из детального просмотра

### 7.3. Приоритеты

- [ ] **4 уровня**: P1 (срочный, красный), P2 (высокий, оранж), P3 (средний, синий), P4 (низкий, серый)
- [ ] **Визуальная индикация** цветом
- [ ] **Быстрая смена** приоритета из контекстного меню
- [ ] **Фильтрация по приоритету** (в view "All Tasks")

### 7.4. Даты и повторения

- [ ] **Установка даты** — date picker
- [ ] **Recurring tasks** — пресеты (every day, every weekday, every week, every month) + произвольный ввод через `due_string`
- [ ] **Визуальная индикация** даты:
  - Просроченные (overdue) — выделение красным
  - Сегодня — выделение оранжевым
  - Завтра — синим
  - Будущие — серым
  - Recurring — иконка повтора
- [ ] **Трекинг откладываний** — показ `postpone_count` (сколько раз дата менялась)
- [ ] **Быстрая установка даты** — "Сегодня", "Завтра", конкретные дни недели (в Weekly view)

### 7.5. Лейблы

- [ ] **Просмотр лейблов задачи** — бейджи в строке задачи
- [ ] **Добавление/удаление лейблов** — в детальном просмотре
- [ ] **Batch update labels** — для нескольких задач сразу
- [ ] **Label configs** — настройка `inherit_to_subtasks` (из AppConfig)
- [ ] **Список всех лейблов** с подсчётом задач

### 7.6. Авто-лейблы

- [ ] **Автоматическое добавление лейблов при создании** — по маске в заголовке:
  - `mask: "купить"` + `label: "покупки"` → задача с "Купить молоко" получает лейбл "покупки"
  - `ignoreCase: true` (default) — регистронезависимый поиск
- [ ] **Наследование лейблов контекста** — если `context.inheritLabels = true`, лейблы контекста добавляются к новой задаче

### 7.7. Контексты

- [ ] **Переключение контекста** — из бокового меню или переключателя
- [ ] **Фильтрация задач** по активному контексту:
  - Projects (OR): задачи в любом из проектов контекста
  - Sections (OR): задачи в любой из секций контекста
  - Labels (OR): задачи с любым из лейблов контекста
  - Между категориями AND: задача должна попасть во все непустые фильтры
- [ ] **Рекурсивное включение подзадач** — если родитель попадает в контекст, все подзадачи тоже
- [ ] **Персистенция** активного контекста (`activeContextId` через `PATCH /api/state`)

### 7.8. Views (представления)

- [ ] **All Tasks** — все задачи с фильтрами (priority, labels, links-only)
- [ ] **Inbox** — задачи в Inbox-проекте, с предупреждением при overflow
- [ ] **Today** — задачи на сегодня (+ overdue), группировка по частям дня
- [ ] **Tomorrow** — задачи на завтра, группировка по частям дня
- [ ] **Weekly** — задачи с weekly-лейблом, прогресс-бар лимита
- [ ] **Backlog** — задачи с backlog-лейблом, прогресс-бар лимита
- [ ] **Completed** — завершённые задачи за N дней

### 7.9. Части дня (Day Parts)

- [ ] **Группировка задач Today/Tomorrow** по частям дня (утро, день, вечер, без времени)
  - Конфигурируемые диапазоны часов из `config.dayParts`
  - Задачи без лейбла дня → секция "Без времени"
- [ ] **Заметки к частям дня** — текстовое поле у каждой секции (`dayPartNotes`)
  - Максимальная длина: `maxDayPartNoteLength`
  - Персистенция через `PATCH /api/state`

### 7.10. Планирование (Planning)

- [ ] **Режим планирования** — отдельный экран с двумя вкладками
- [ ] **Backlog tab** — задачи с backlog-лейблом, поиск
- [ ] **Weekly tab** — задачи с weekly-лейблом, прогресс (count/limit)
- [ ] **Перенос из Backlog в Weekly** — переключение лейблов
- [ ] **"Принять все"** (Accept All) — перенос всех задач из backlog в weekly
- [ ] **"Начать неделю"** (Start Week) — `POST /api/tasks/reset-weekly` → снимает weekly-лейбл со всех
- [ ] **Быстрые кнопки даты** в Weekly: Сегодня, Завтра, дни недели
- [ ] **Быстрая установка приоритета** в Weekly
- [ ] **WS переподписка**: при входе в Planning → unsubscribe("tasks") + subscribe("planning"); при выходе → обратно

### 7.11. Закреплённые задачи (Pinned Tasks)

- [ ] **Pin/unpin задачи** — через контекстное меню или детальный просмотр
- [ ] **Максимум** `max_pinned` (обычно 5)
- [ ] **Отображение** в навигации (sidebar / quick access)
- [ ] **Tap на pinned** → навигация к задаче
- [ ] **Персистенция** через `PATCH /api/state { pinnedTasks }`

### 7.12. Поиск

- [ ] **Полнотекстовый поиск** по content задач (case-insensitive substring)
- [ ] Работает в views: All, Backlog, Planning

### 7.13. Фильтрация (All Tasks view)

- [ ] **По приоритету** — мульти-выбор P1-P4
- [ ] **По лейблу** — мульти-выбор из доступных лейблов
- [ ] **Только со ссылками** (links_only) — regex `https?://\S+` в content
- [ ] **Состояние фильтров** персистится через `PATCH /api/state { allFilters }`

### 7.14. Quick Capture

- [ ] Быстрый ввод задачи с предустановленным родителем (из `config.quickCapture`)
- [ ] Минимальный UI: только content + опциональная дата
- [ ] Авто-фокус на клавиатуру

### 7.15. "Следующее действие" (Next Action)

- [ ] **Триггер**: после завершения задачи, если:
  - У задачи есть подзадачи → предложить создать следующую подзадачу
  - У задачи есть родитель → предложить создать follow-up
- [ ] **Предзаполнение**: лейблы наследуются от завершённой задачи

### 7.16. Индикатор соединения

- [ ] **Online** — скрыт (или минимальный зелёный индикатор)
- [ ] **Connecting** — оранжевый, "Подключение..."
- [ ] **Offline** — красный, "Оффлайн", badge с количеством pending actions
- [ ] **Offline grace period** — 5 секунд задержки перед показом offline-баннера

### 7.17. Auto-remove информация

- [ ] Показ `expires_at` на задачах (время до автоудаления)
- [ ] Информирование если auto-remove `paused`
- [ ] Автоудаление выполняется на бэкенде — iOS только отображает информацию

### 7.18. Markdown и ссылки

- [ ] **Рендеринг markdown** в description (bold, italic, strikethrough, code, links)
- [ ] **Очистка tracking-параметров** из URL: удалить `utm_*`, `gclid`, `fbclid`, `mc_*`, `ref` и т.д.

### 7.19. Прогресс-бары

- [ ] **Weekly**: `weekly_count / weekly_limit` (из meta)
- [ ] **Backlog**: `backlog_count / backlog_limit` (из meta)
- [ ] Цвет: зелёный (<80%), оранжевый (80-99%), красный (>=100%)

### 7.20. Inbox overflow

- [ ] Если `inbox_count > inbox_limit` → показать предупреждение
- [ ] Текст предупреждения: `inboxOverflowTaskContent` из Settings

---

## 8. Логика по экранам/views

### 8.1. Логика отображения задач по view

| View | Endpoint | Сортировка (бэкенд) | Особенности |
|------|----------|---------------------|-------------|
| All | `GET /api/tasks?context=` | По config.taskSort (priority/due_date/content/added_at) | Фильтры: priority, labels, links_only |
| Inbox | `GET /api/tasks/inbox` | По added_at DESC | Overflow warning при > inbox_limit |
| Today | `GET /api/tasks/today` | По config.taskSort | Группировка по DayParts, включает overdue если настроено |
| Tomorrow | `GET /api/tasks/tomorrow` | По config.taskSort | Группировка по DayParts |
| Weekly | `GET /api/tasks/weekly` | По config.taskSort | Прогресс-бар, quick date buttons |
| Backlog | `GET /api/tasks/backlog` | По backlog.taskSort | Прогресс-бар, поиск |
| Completed | `GET /api/tasks/completed` | По completed_at DESC | Только чтение, кешируется |

### 8.2. WebSocket-подписки по view

При смене view/context:
1. Отправить `unsubscribe` для текущего канала
2. Отправить `subscribe` для нового view + context

Для Planning:
1. Отправить `unsubscribe("tasks")`
2. Отправить `subscribe("planning")`
3. При выходе из Planning → обратно

### 8.3. DayPart группировка (Today/Tomorrow)

```
Для каждой задачи:
  1. Проверить лейблы задачи
  2. Найти DayPart, label которого есть в лейблах задачи
  3. Если найден → задача в эту группу
  4. Если нет → группа "Без времени"

Секции в UI:
  - [DayPart.label] (утро / день / вечер / etc.)
    - [заметка к секции (если есть)]
    - [список задач]
  - "Без времени"
    - [список задач]
```

---

## 9. Фоновая работа и lifecycle

### 9.1. App Lifecycle (ScenePhase)

```
Active:
  - Подключить WS если disconnected
  - Flush ActionQueue
  - Проверить stale данных (> 2 мин)

Background:
  - Отключить WS (экономия батареи)
  - Flush pending actions через background URLSession
  - Schedule BGAppRefreshTask
```

### 9.2. Background App Refresh

```swift
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.turboist.refresh",
    using: nil
) { task in ... }
```

Задачи:
- Flush pending actions из очереди
- Пометить данные как stale

### 9.3. Background URLSession

Для критических мутаций (create/complete/delete) использовать background URLSession, чтобы запросы завершились при уходе в background.

---

## 10. Локализация

### 10.1. Языки

- **English** (en) — базовый
- **Русский** (ru) — полная локализация

### 10.2. Реализация

String Catalogs (`.xcstrings`, iOS 17+). Язык синхронизируется с бэкендом через `PATCH /api/state { locale }`.

### 10.3. Форматирование дат

Используй Locale для форматирования дат в зависимости от `locale` из UserState.

### 10.4. Плюрализация

String Catalog поддерживает правила плюрализации для русского языка автоматически.

---

## 11. Безопасность и аутентификация

- **Пароль**: не хранится на устройстве (только вводится при логине)
- **Session token (cookie)**: хранить в **Keychain** (не UserDefaults)
- **Server URL**: UserDefaults
- Все запросы через **HTTPS** (исключение: dev-режим с allowArbitraryLoads)
- Опционально: **Face ID / Touch ID** при открытии приложения

---

## 12. Тестирование

### 12.1. Юнит-тесты (приоритетные)

- `buildTree()` / `flattenTasks()` / `taskToFlat()` — конвертация моделей
- `AutoLabelMatcher` — matching по маскам (case-sensitive и ignore-case)
- `ActionQueue` — enqueue, coalescing, flush, retry, max retries, 401 stop
- `ActionCoalescer` — merge updateTask, merge patchState
- `DeltaMerge` — mergeUpserted(), filterByIds()
- `URL cleaner` — удаление tracking-параметров
- `DayPart grouping` — распределение задач по частям дня

### 12.2. Integration-тесты

- Полный цикл: create → read → update → complete → delete (с реальным бэкендом)
- WebSocket: subscribe → snapshot → mutate → delta
- Offline: queue → reconnect → flush → verify state

### 12.3. Offline-тесты (критичные)

- Создание задачи offline → flush → задача появляется с реальным ID
- Несколько update к одной задаче offline → coalescing → один PATCH на сервер
- Complete + Delta приходит до flush → корректный merge
- 401 при flush → остановка очереди, показ LoginView
- Приложение убито в background → при следующем старте pending actions восстановлены
- Temp ID reconciliation → замена во всех ссылках

---

## 13. Порядок реализации (фазы)

### Фаза 1: Фундамент

- Xcode-проект, структура папок, SwiftData setup
- Доменные модели + JSON Codable
- `buildTree()` / `flattenTasks()` конвертация
- `APIClient` (HTTP + cookie auth)
- `LoginView` + аутентификация
- `GET /api/config` → загрузка и кеширование AppConfig
- Базовый список задач из HTTP API (один view)
- NavigationStack, базовая навигация

**Результат:** Логин, отображение задач из одного view.

### Фаза 2: WebSocket + Real-time

- `WebSocketClient` с reconnect и exponential backoff
- Subscribe/unsubscribe, ping/pong
- Обработка snapshot → замена данных
- Обработка delta → mergeUpserted + filterByIds
- Re-subscribe при смене view/context
- Индикатор соединения

**Результат:** Задачи обновляются в реальном времени через WS.

### Фаза 3: Offline-first

- SwiftData entities (TaskEntity, QueuedActionEntity, etc.)
- Сохранение snapshot'ов в SwiftData
- Загрузка из SwiftData при запуске (instant display)
- ActionQueue: enqueue, coalescing, flush, retry
- Optimistic updates (мгновенный UI)
- Temp ID reconciliation
- Pending overlay (applyPendingRemovals, applyPendingUpdates)
- Stale detection + offline grace period
- Background URL session для critical mutations

**Результат:** Полностью работает оффлайн.

### Фаза 4: Все мутации

- Create task (+ auto-label matching, + context label inheritance)
- Update task (content, description, priority, labels, due)
- Complete task (+ Next Action trigger)
- Delete task
- Duplicate task
- Decompose task
- Move task
- Pin/unpin
- Batch update labels
- Quick Capture
- RecurrencePicker (due_string)

**Результат:** Полное CRUD.

### Фаза 5: Все views и фичи

- Inbox (+ overflow warning)
- Today / Tomorrow (+ DayPart группировка + day_part_notes)
- Weekly (+ прогресс-бар + quick date buttons + Start Week)
- Backlog (+ прогресс-бар)
- All Tasks (+ фильтры: priority, labels, links_only)
- Completed
- Planning (full-screen, backlog/weekly tabs, WS channel switch)
- Contexts (переключение, фильтрация)
- Pinned tasks (навигация)
- Labels view
- Search
- Collapse/expand subtasks
- Settings

**Результат:** Feature parity с веб-версией.

### Фаза 6: Polish

- Локализация (en + ru)
- Темы (light/dark/system)
- Background App Refresh
- Тесты (unit + integration + offline)
- Performance оптимизация больших списков
- Accessibility (VoiceOver, Dynamic Type)

### Фаза 7: Расширения (опционально)

- Local notifications (due date reminders)
- Widgets (Today tasks, Weekly progress)
- Shortcuts / Siri integration
- Share extension (quick capture из других приложений)
- iPad layout (split view)
- Face ID / Touch ID
- Watch app (basic task completion)

---

## 14. API Reference

### HTTP Endpoints

| Method | Path | Описание |
|--------|------|----------|
| POST | `/api/auth/login` | Логин (`{password}` → Set-Cookie) |
| POST | `/api/auth/logout` | Логаут |
| GET | `/api/auth/me` | Проверка сессии (200/401) |
| GET | `/api/health` | Здоровье (`{cache_ready, last_synced_at}`) |
| GET | `/api/config` | Полная конфигурация (AppConfig) |
| GET | `/api/tasks` | Все задачи (`?context=id`) → `{tasks, meta}` |
| GET | `/api/tasks/inbox` | Inbox → `{tasks, meta}` |
| GET | `/api/tasks/today` | Сегодня → `{tasks, meta}` |
| GET | `/api/tasks/tomorrow` | Завтра → `{tasks, meta}` |
| GET | `/api/tasks/weekly` | Weekly → `{tasks, meta}` |
| GET | `/api/tasks/backlog` | Backlog → `{tasks, meta}` |
| GET | `/api/tasks/completed` | Завершённые → `{tasks, meta}` |
| GET | `/api/tasks/:id` | Задача по ID → `TaskItem` (дерево) |
| GET | `/api/tasks/:id/completed-subtasks` | Завершённые подзадачи → `{tasks}` |
| POST | `/api/tasks` | Создать → `{ok, id}` |
| PATCH | `/api/tasks/:id` | Обновить → `{ok}` |
| POST | `/api/tasks/:id/complete` | Завершить → `{ok}` |
| DELETE | `/api/tasks/:id` | Удалить → `{ok}` |
| POST | `/api/tasks/:id/duplicate` | Дублировать → `{ok, task_id}` |
| POST | `/api/tasks/:id/decompose` | Декомпозировать → `{ok}` |
| POST | `/api/tasks/:id/move` | Переместить → `{ok}` |
| POST | `/api/tasks/batch-update-labels` | Batch лейблы → `{ok, updated}` |
| POST | `/api/tasks/reset-weekly` | Сброс weekly → `{ok, updated}` |
| PATCH | `/api/state` | Обновить UI state → 204 |

### WebSocket Messages

| Направление | type | channel | Данные |
|-------------|------|---------|--------|
| Client → | `subscribe` | `tasks` / `planning` | `{view?, context?, seq?}` |
| Client → | `unsubscribe` | `tasks` / `planning` | — |
| Client → | `pong` | — | — |
| → Client | `snapshot` | `tasks` | `{tasks[], meta}` |
| → Client | `delta` | `tasks` | `{upserted[], removed[], meta}` |
| → Client | `snapshot` | `planning` | `{backlog[], weekly[], meta}` |
| → Client | `delta` | `planning` | `{backlog_upserted?, backlog_removed?, weekly_upserted?, weekly_removed?, meta}` |
| → Client | `ping` | — | — |
| → Client | `error` | — | `{message}` |

### PATCH /api/state — допустимые поля

Все поля опциональны, отправляйте только изменённые:

```json
{
    "pinned_tasks": [{"id": "...", "content": "..."}],
    "active_context_id": "work",
    "active_view": "today",
    "collapsed_ids": ["taskId1", "taskId2"],
    "sidebar_collapsed": false,
    "planning_open": false,
    "day_part_notes": {"утро": "Заметка"},
    "locale": "ru",
    "all_filters": {
        "selected_priorities": [1, 2],
        "selected_labels": ["покупки"],
        "links_only": false,
        "filters_expanded": true
    }
}
```

**Валидация на бэкенде:**
- `active_context_id` — должен существовать в contexts
- `active_view` — одно из: all, inbox, today, tomorrow, weekly, backlog, completed
- `pinned_tasks` — максимум `max_pinned` элементов
- `locale` — одно из: "", "en", "ru"
- `day_part_notes` — ключи должны быть валидными dayPart labels, длина ≤ `max_day_part_note_length`

---

*Документ создан на основе анализа кодовой базы Turboist v0.16.0 (Go backend + SvelteKit frontend).*
