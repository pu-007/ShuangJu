# ShuangJu - 爽剧 🎬

[[English](https://github.com/pu-007/ShuangJu/blob/main/README.md)] [简体中文]

一款专为电视剧爱好者设计的个性化管理应用，轻松收藏您喜爱的电视剧剧照、经典台词，追踪观看进度，并记录您的独特想法。

## 📸 **截图**

<table style="margin: 0 auto;">
  <tr>
    <td style="text-align: center;">
      <img src="docs/img-1.jpg" alt="主页" width="200">
      <p>主页</p>
    </td>
    <td style="text-align: center;">
      <img src="docs/img-2.jpg" alt="管理" width="200">
      <p>管理</p>
    </td>
    <td style="text-align: center;">
      <img src="docs/img-3.jpg" alt="详情" width="200">
      <p>详情</p>
    </td>
  </tr>
</table>

## ✨ **主要功能**

- **剧集管理:** 集中管理您的电视剧收藏。
- **剧照与台词:** 保存和浏览精美的剧照以及触动人心的台词。
- **追剧日历:** 直观展示追剧计划和进度。
- **在线播放:** 快速跳转到配置好的在线播放源。
- **台词相册:** 以卡片或相册形式回顾经典台词和相关剧照。
- **进度追踪:** 记录每部剧的观看进度。
- **个人想法:** 随时记录您对剧集的感想和思考。
- **TMDB 集成:** 添加新剧集时自动从 The Movie Database (TMDB) 获取信息。
- **数据管理:** 方便地添加、编辑和管理电视剧数据。
- **生日惊喜:** 内置特别的生日祝福视频播放功能。

## 👨‍💻 技术栈

- **框架:** Flutter
- **语言:** Dart

## 📋 **图示**

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
