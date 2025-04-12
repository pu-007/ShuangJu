# ShuangJu Flutter 项目代码结构说明 (lib 目录)

本文档旨在说明 `lib` 目录下的代码结构、主要组件及其职责，以便于理解、维护和后续开发。

## 整体结构

项目遵循一种类似于 MVVM (Model-View-ViewModel) 或 Provider 架构的模式，利用 `provider` 包进行状态管理。主要分为以下几个部分：

* **Models**: 定义应用程序的核心数据结构。
* **Services**: 处理数据获取、存储和外部交互。
* **Providers (ViewModels)**: 管理应用程序状态，连接 Models 和 Services，并通知 UI 更新。
* **Screens (Views)**: 构建用户界面，展示数据并响应用户交互。

## 目录结构详解

### `lib/` (根目录)

* **`main.dart`**:
  * **作用**: 应用程序的入口点。
  * **职责**:
    * 初始化 Flutter 绑定 (`WidgetsFlutterBinding.ensureInitialized()`)。
    * 创建并初始化 `DataService`。
    * 调用 `DataService.initializeDataIfNeeded()` 确保数据（如 `sources.json` 和 `tv_shows` 目录）已从 `assets` 复制/解压到可写目录。
    * 设置 `MultiProvider`，提供全局可用的状态管理器 (`TvShowNotifier`, `PlaySourceNotifier`)。
    * 运行 `MyApp` Widget。
  * **`MyApp` Widget**:
    * 根 Widget，是一个 `StatelessWidget`。
    * 配置 `MaterialApp`，包括主题 (`ThemeData`)、标题和初始路由 (`home: MainScreen()`)。

### `lib/models/`

* **作用**: 存放应用程序的数据模型类。这些类定义了数据的结构。
* **主要文件**:
  * **`tv_show.dart`**: 定义核心的 `TvShow` 模型，包含电视剧的各种属性（名称、简介、进度、台词、图片信息等）。使用了 `json_annotation` 进行 JSON 序列化/反序列化。
  * **`progress.dart`**: 定义 `Progress` 模型，用于表示观看进度（当前/总计）。
  * **`play_source.dart`**: 定义 `PlaySource` 模型，表示一个播放源（名称和 URL 模板）。
  * **`*.g.dart`**: 由 `build_runner` 根据 `*.dart` 文件中的 `@JsonSerializable` 注解自动生成，包含 JSON 序列化/反序列化的辅助代码 (`fromJson`, `toJson`)。**不应手动编辑这些文件。**

### `lib/providers/`

* **作用**: 存放基于 `ChangeNotifier` 的状态管理类。这些类负责管理特定领域的状态，处理业务逻辑，并在状态变化时通知监听者（通常是 UI）。
* **主要文件**:
  * **`tv_show_notifier.dart`**:
    * 管理 `TvShow` 列表的状态（加载、错误、数据）。
    * 提供加载 (`loadTvShows`)、更新 (`updateTvShow`, `toggleFavorite`, `updateProgress`, `addThought` 等) 电视剧数据的方法，通过 `DataService` 与持久化层交互。
    * 管理当前主页显示的电视剧 (`currentHomeScreenShow`, `currentHomeScreenQuote`) 及其选择逻辑 (`selectRandomHomeScreenShow`)，包含初始选择标志 (`initialHomeScreenShowSelected`)。
    * 提供 `notifySettingsChanged` 方法以允许其他部分（如设置页面）触发监听器更新。
  * **`play_source_notifier.dart`**:
    * 管理 `PlaySource` 列表的状态。
    * 提供加载 (`loadPlaySources`)、保存 (`saveSources`) 和重新加载 (`reloadPlaySources`) 播放源数据的方法，通过 `DataService` 操作。

### `lib/screens/`

* **作用**: 包含构成应用程序用户界面的各个屏幕 Widget。
* **主要文件**:
  * **`main_screen.dart`**:
    * 应用程序的主框架，包含底部导航栏 (`BottomNavigationBar`)。
    * 使用 `IndexedStack` 来管理和切换不同的主页面 (`HomeScreen`, `ManageScreen`, `SettingsScreen`)，以保持它们的状态。
  * **`home_screen.dart`**:
    * 主页屏幕，显示随机选择的电视剧背景、日期时间和引言。依赖 `TvShowNotifier` 获取当前显示的电视剧信息。
    * 包含一个可展开的菜单，提供切换背景、相册、音乐、播放、进度编辑和想法查看/添加等快捷操作。
    * 使用 `Timer` 和 `WidgetsBindingObserver` 实现根据设置的时间间隔自动更新背景，并在应用恢复时重新加载间隔。手动刷新会重置计时器。
    * 依赖 `PlaySourceNotifier` 获取播放源。
    * 包含音乐播放器控件。
  * **`manage_screen.dart`**:
    * 电视剧管理页面，使用瀑布流 (`MasonryGridView`) 显示所有电视剧的封面和名称。
    * 提供点击封面导航到详情页的功能。
    * 包含快速访问播放源的功能。
    * 依赖 `TvShowNotifier` 获取电视剧列表。
  * **`tv_show_detail_screen.dart`**:
    * 电视剧详情页面，显示单个电视剧的详细信息。
    * 包含封面、简介、操作按钮（主题曲、播放源、想法）、音乐播放器控件、观看进度（带 +/- 按钮）、剧照相册（`GridView`）、台词列表（`Card`）。
    * 依赖 `TvShowNotifier` 和 `PlaySourceNotifier`。
  * **`settings_screen.dart`**:
    * 设置页面，提供编辑数据源、设置主页更新频率（使用自定义对话框）、播放生日视频和查看应用信息的功能。
    * 使用 `SharedPreferences` 存储更新频率。
    * 导航到 `EditSourcesScreen`。
    * 保存频率设置后会调用 `TvShowNotifier.notifySettingsChanged()`。
  * **`edit_sources_screen.dart`**:
    * 用于添加、编辑和删除播放源 (`PlaySource`) 的页面。
    * 使用 `ListView` 展示源列表，`AlertDialog` 和 `Form` 进行编辑/添加。
    * 直接使用 `DataService` 加载和保存播放源数据，并在保存后通过 `Provider` 调用 `PlaySourceNotifier.reloadPlaySources()`。
  * **`gallery_screen.dart`**:
    * 显示指定电视剧的所有剧照图片（非封面）的页面。
    * 使用 `GridView` 展示图片。

### `lib/services/`

* **作用**: 包含负责数据持久化、网络请求或其他外部交互的服务类。
* **主要文件**:
  * **`data_service.dart`**:
    * 核心数据服务类。
    * **职责**:
      * 管理数据存储路径（应用内部存储用于 `sources.json`，应用专属外部存储用于 `tv_shows` 数据）。
      * 处理首次运行或数据丢失时的初始化：从 `assets` 复制 `sources.json`，解压 `assets/tv_shows_archive.zip` 到可写目录。
      * 加载 (`loadTvShows`, `loadPlaySources`) 和保存 (`saveTvShow`, `savePlaySources`) 电视剧和播放源数据到对应的 JSON 文件。
      * 提供获取电视剧图片路径列表的方法 (`getImagePathsForShow`)。
    * **关键逻辑**: 使用 `path_provider` 获取可写目录，使用 `dart:io` 进行文件读写，使用 `archive` 包处理 ZIP 解压，使用 `dart:convert` 处理 JSON。

## 总结

该项目结构清晰，职责分离明确。通过 `Provider` 进行状态管理，使得 UI 和业务逻辑解耦。`DataService` 封装了所有文件系统操作，简化了 `Notifier` 和 UI 的实现。理解各个部分的职责有助于快速定位代码和进行修改。
