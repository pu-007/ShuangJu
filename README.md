# ShuangJu - 爽剧

为梁爽同学十七岁生日定制的软件,收藏喜欢的电视剧剧照与台词,支持追剧日历,跳转播放,台词相册,进度记录以及个人想法.

## 最适配设备

1. 系统:LineageOS 18.1 (Android 11)
2. 设备:Lenovo Tab 4 8 Plus TB8804F/TF8704F
3. 屏幕: 1200 x 1920 LCD (8英寸)
4. CPU: 8x ARM Cortex-A53 @ 2016 MHz (arm64-v8a,armeabi-v7a,armeabi)
5. 内存: 3555MB
6. 存储空间:51.97 GB

## 技术栈

Flutter (Channel stable, 3.29.2, on Microsoft Windows [版本 10.0.26100.3476], locale zh-CN)
• Flutter version 3.29.2 on channel stable at C:\Users\zion\Apps\Flutter\flutter
• Dart version 3.7.2
• DevTools version 2.42.3

## 设计要求

### 数据

1. 本应用核心是实现电视剧管理,电视剧对象为存储在 ./assets/tv_shows/ 中的各个文件夹.每个文件夹的名称即为该电视剧名称
2. 电视剧对应的信息存储在 ./assets/tv_shows/{name}/init.json 中,封面存储在 ./assets/tv_shows/{name}/cover.jpg, 主题音乐存储在 ./assets/tv_shows/{name}/themesong.mp3

其余信息在 init.json 中,init.json 示例如下:

```json
{
  // 名称
  "name": "我要我们在一起", 
  // TMDB ID
  "tmdb_id": 830938, 
  // 简介
  "overview": "你有没有爱过一个人,曾经拼了命,只为和TA在一起.十年前,差生吕钦扬当众告白凌一尧,两人从校园步入社会,为了让她幸福,他不惜以命相搏.然而金钱,房子,婚姻等现实的考验,却将两人越推越远.十年长跑,他们能否还记得曾经刻在心底的约定:我要我们在一起.",
  // 观看进度
  "progress": {
    "current": 0,
    "total": 1
  },
  // 是否收藏,收藏应排列到前方
  "favorite": false,
  // 著名台词
  "lines": [
    "如果我死了,请不要告诉凌一尧.",
    "如果我活着,一定娶她为妻.",
    "你我终将相逢,就像山川河流,就像万河归海.",
    "我把对你的喜欢藏进云里,隐于风里,揉进眼里.",
    "我想你在我身边,就像我想你一样.",
    "人生中的太多身不由己,太多的意料之外,所有的遇见却都是有意义的.",
    "我们能够遇见,这世界那么多人,有这么幸运,多幸福.",
    "我要我们在一起."
  ],
  // 有内嵌台词的照片(剧照)
  "inline_lines": {
    "我要我们在一起-20250329091519489936-1.jpg": "这世界那么多人,多幸运,我有个我们"
  },
  // 类型
  "media_type": "moive",
  // 个人想法
  "thoughts": [],
  // 别名
  "alias": ""
}
```

3. 在每个电视剧目录中,可能有大量图片,为关于这部电视剧的剧照,回忆等,可以添加文字备注.格式为 `{name}-{datetime}-index.jpg`

4. 对于跳转播放功能,使用 init.json 中的数据,打开指定 url,定义为一个 json 文件,在 ./assets/sources.json 可以选择:

```json
{
  "[信息]TMDB": "https://www.themoviedb.org/{media_type}/{tmdb_id}",
  "[信息]豆瓣": "https://www.douban.com/search?q={name}",
  "[网盘]甜爱路": "https://www.tianail.cn/s/{name}.html",
  "[在线]爱壹帆": "https://www.yfsp.tv/search/{name}",
  "[在线]老王": "https://laowang.co/s.html?wd={name}",
  "[在线]大师兄": "https://dsxys.pro/sb/kemksmaksdl7nhZe3c1-.html?wd={name}",
  "[在线]网飞猫": "https://www.ncat21.com/search?os=pc&k={name}",
  "[在线]黑猫影视": "https://heimaotv.vip/vod/search.html?wd={name}",
  "[港台]追剧网": "https://ztv.tw/vodsearch/-------------.html?wd={name}&submit=",
  "[港台]脉脉": "https://momovod.app/search.html?wd={name}&submit="
}
```

4. 还有一个 birthday_video 视频,在软件设置界面有一个条目,点击可以播放 ./assets/birthday_mv.mp4

### 界面布局

1. 底栏:主页,管理,设置
2. 主页:日历界面,简洁美观的有电视剧背景的显示日期，背景图片为随机抽取一个 tv_shows 展示里面的电视剧的 cover.jpg,并在日期下且显示其中一句台词并附加出处电视剧.日历界面上有折叠菜单,按钮操作如下
   1. 切换电视剧,从 tv_shows 库中随机抽取一个电视剧装载
   2. 相册,显示这部电视剧目录中所有图片
   3. 音乐,播放这不电视剧目录中的音乐
   4. 播放,根据 sources,跳转到指定url播放
   5. 观看记录,显示 init.json 中的 progress,可以手动修改
   6. 想法 在对应电视剧的 init.json 中的 thoughts 列表中写入个人想法,纯文本记录,为的个人想法
3. 管理：电视剧数据管理界面，显示 tv_shows 中的所有电视剧，显示 cover.jpg 还有名称，瀑布流式界面，要疏密分明美观便于查看。功能要求如下
   1. 显示基本信息，读取 init.json，显示电视剧名称，主题曲按钮，跳转播放按钮，还有观看进度修改条，还有添加和查看想法的按钮
   2. 下面显示相册，为改电视剧目录下的所有图片，如果在 init.json 中有 `inline_lines` 就在图片上面显示对应的文字
   3. 将 lines 文字显示为卡片，与图片混排
4. 设置
   1. 数据源编辑 `sources.json`
   2. 可点击条目，点击会播放 ./assets/birthday_mv.mp4
   3. 其他条目暂定

请用现代化的美观的 UI 实现以上功能，保证功能的完备性，灵活组织布局，用各种美观高效的组件。