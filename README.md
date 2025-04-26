# ShuangJu - Enjoy TV Dramas 🎬

[English] [[简体中文](https://github.com/pu-007/ShuangJu/blob/main/README.zh.md)]

A personalized management app designed for TV drama enthusiasts. Easily collect your favorite TV drama stills, classic lines, track viewing progress, and record your unique thoughts.

## 📸 **Screenshots**

<table style="margin: 0 auto;">
  <tr>
    <td style="text-align: center;">
      <img src="docs/img-1.jpg" alt="Home" width="200">
      <p>Home</p>
    </td>
    <td style="text-align: center;">
      <img src="docs/img-2.jpg" alt="Management" width="200">
      <p>Management</p>
    </td>
    <td style="text-align: center;">
      <img src="docs/img-3.jpg" alt="Details" width="200">
      <p>Details</p>
    </td>
  </tr>
</table>

## ✨ **Key Features**

- **Series Management:** Centrally manage your TV drama collection.
- **Stills and Lines:** Save and browse beautiful stills and touching lines.
- **Drama Calendar:** Intuitively display drama viewing plans and progress.
- **Online Playback:** Quickly jump to configured online playback sources.
- **Lines Album:** Review classic lines and related stills in card or album form.
- **Progress Tracking:** Record viewing progress for each drama.
- **Personal Thoughts:** Record your thoughts and reflections on the drama at any time.
- **TMDB Integration:** Automatically retrieve information from The Movie Database (TMDB) when adding new dramas.
- **Data Management:** Conveniently add, edit, and manage TV drama data.
- **Birthday Surprise:** Built-in special birthday greeting video playback feature.

## 👨‍💻 **Tech Stack**

- **Framework:** Flutter
- **Language:** Dart

## 📋 **Graph**

```mermaid
graph TD
    A[启动应用] --> B{检查可写目录数据?};
    B -- 存在 --> C[加载可写目录数据];
    B -- 不存在 --> D[复制 Assets 数据到可写目录];
    D --> C;
    C --> E[初始化状态管理];
    E --> F[显示主界面 底部导航 ];

    subgraph 主页 Home
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

    subgraph 管理页 Manage
        F --> O[显示电视剧瀑布流];
        O --> P{卡片操作};
        P -- 音乐 --> J;
        P -- 播放 --> K;
        P -- 进度/想法 --> M;
        P -- 查看图片/台词 --> Q[显示详情/大图];
    end

    subgraph 设置页 Settings
        F --> R[显示设置项];
        R -- 编辑数据源 --> S[编辑 Source 页面];
        S --> T[保存 Source 到可写目录];
        R -- 播放生日视频 --> U[播放 birthday_mv.mp4];
    end

    N --> E;
    T --> E;
```
