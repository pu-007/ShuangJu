# ShuangJu - 爽剧 开发计划

**项目目标**: 开发一款名为 "ShuangJu - 爽剧" 的 Flutter 应用，用于收藏梁爽同学喜欢的电视剧剧照与台词，支持追剧日历、跳转播放、台词相册、进度记录以及个人想法记录。

**核心技术**: Flutter (版本 3.29.2)

**开发计划**:

1. **项目初始化与环境配置 (Setup)**
    * 编辑 `pubspec.yaml`: 添加依赖 (`provider`/`riverpod`, `json_serializable`/`build_runner`, `path_provider`, `url_launcher`, `audioplayers`, `flutter_staggered_grid_view`, `photo_view`, `intl`, `video_player`) 并声明 `assets`。
    * 运行 `flutter pub get`。
    * 配置 `build_runner`。

2. **数据模型定义 (Data Models)**
    * 创建 `TvShow`, `Progress`, `PlaySource` 类。
    * 使用 `@JsonSerializable()` 生成解析代码。

3. **数据处理与持久化 (Data Handling & Persistence)**
    * 实现首次启动时复制 `assets` 数据到可写目录。
    * 创建 `DataService` 用于加载和保存 `TvShow` 和 `PlaySource` 数据到可写目录。

4. **状态管理 (State Management)**
    * 配置 `Provider` 或 `Riverpod`。
    * 创建 `Notifier` 类管理应用状态 (电视剧列表、主页状态、播放器、设置)。

5. **UI 界面实现 (UI Implementation)**
    * **基础结构**: `main.dart` 设置 `MaterialApp` 和底部导航栏 (`BottomNavigationBar`)。
    * **主页 (`HomeScreen`)**: 日历视图、随机背景/台词、折叠菜单 (切换、相册、音乐、播放、进度、想法)。
    * **管理页 (`ManageScreen`)**: 瀑布流布局 (`flutter_staggered_grid_view`) 显示电视剧卡片 (封面、名称、按钮、进度)、剧照、台词卡片，支持图片叠加文字和点击查看大图 (`photo_view`)。
    * **设置页 (`SettingsScreen`)**: 编辑数据源条目 (导航到 `EditSourcesScreen`)、播放生日祝福条目 (使用 `video_player`)。

6. **功能模块实现 (Feature Implementation)**
    * 图片加载 (`Image.asset`)。
    * 音乐播放 (`audioplayers`)。
    * 跳转播放 (`url_launcher`)。
    * 想法记录 (文本列表)。

7. **UI/UX 优化 (UI/UX Polish)**
    * 统一 `ThemeData`。
    * 添加动画和加载指示器。
    * 适配目标设备。
    * 测试和 Bug 修复。

**Mermaid 图示 (简化流程)**

```mermaid
graph TD
    A[启动应用] --> B{检查可写目录数据?};
    B -- 存在 --> C[加载可写目录数据];
    B -- 不存在 --> D[复制 Assets 数据到可写目录];
    D --> C;
    C --> E[初始化状态管理];
    E --> F[显示主界面 (底部导航)];

    subgraph 主页 (Home)
        F --> G[显示日历/背景/台词];
        G --> H{折叠菜单操作};
        H -- 切换 --> G;
        H -- 相册 --> I[显示图片];
        H -- 音乐 --> J[播放/暂停音乐];
        H -- 播放 --> K[显示播放源列表];
        K --> L[打开外部链接];
        H -- 进度/想法 --> M[修改数据];
        M --> N[保存数据到可写目录];
    end

    subgraph 管理页 (Manage)
        F --> O[显示电视剧瀑布流];
        O --> P{卡片操作};
        P -- 音乐 --> J;
        P -- 播放 --> K;
        P -- 进度/想法 --> M;
        P -- 查看图片/台词 --> Q[显示详情/大图];
    end

    subgraph 设置页 (Settings)
        F --> R[显示设置项];
        R -- 编辑数据源 --> S[编辑 Source 页面];
        S --> T[保存 Source 到可写目录];
        R -- 播放生日视频 --> U[播放 birthday_mv.mp4];
    end

    N --> E;
    T --> E;
```
