import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/tv_show.dart';
import '../models/progress.dart';
import '../providers/tv_show_notifier.dart';
import 'tmdb_search_dialog.dart';
import 'image_selection_dialog.dart';

// 定义编辑标签枚举
enum EditTvShowTab {
  basic, // 基本信息
  images, // 图片
  lines, // 台词
  themeSong, // 主题曲
}

class EditTvShowScreen extends StatefulWidget {
  final TvShow? tvShow; // 如果为null，则是添加新电视剧
  final bool isEditing;
  final EditTvShowTab initialTab; // 初始标签

  const EditTvShowScreen({
    super.key,
    this.tvShow,
    this.isEditing = false,
    this.initialTab = EditTvShowTab.basic,
  });

  @override
  State<EditTvShowScreen> createState() => _EditTvShowScreenState();
}

class _EditTvShowScreenState extends State<EditTvShowScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _overviewController = TextEditingController();
  String _mediaType = 'tv'; // 默认为电视剧
  final _currentProgressController = TextEditingController();
  final _totalProgressController = TextEditingController();
  final _aliasController = TextEditingController();

  List<String> _lines = [];
  Map<String, String> _inlineLines = {};

  File? _coverImage;
  File? _themeSong;
  List<File> _additionalImages = []; // 移除 final 关键字
  bool _isTMDBSearching = false;

  bool _isFavorite = false;
  bool _isLoading = false;
  String? _errorMessage;

  // 标签页控制器
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 初始化标签控制器
    _tabController = TabController(
      length: 4, // 四个标签页
      vsync: this,
      initialIndex: widget.initialTab.index, // 设置初始标签
    );
    _initializeFormData();

    // 如果是编辑模式，在初始化后加载电视剧的所有图片
    if (widget.isEditing && widget.tvShow != null) {
      _loadExistingImages();
    }
  }

  void _initializeFormData() {
    if (widget.tvShow != null) {
      final show = widget.tvShow!;
      _nameController.text = show.name;
      _overviewController.text = show.overview;
      _mediaType = show.media_type;
      _currentProgressController.text = show.progress.current.toString();
      _totalProgressController.text = show.progress.total.toString();
      _aliasController.text = show.alias ?? '';
      _lines = List.from(show.lines);
      _inlineLines = Map.from(show.inline_lines);
      _isFavorite = show.favorite;

      if (show.directoryPath != null) {
        final coverPath = show.coverImagePath;
        final themeSongPath = show.themeSongPath;

        if (File(coverPath).existsSync()) {
          _coverImage = File(coverPath);
        }

        if (File(themeSongPath).existsSync()) {
          _themeSong = File(themeSongPath);
        }
      }
    } else {
      // 默认值
      _mediaType = 'tv';
      _currentProgressController.text = '0';
      _totalProgressController.text = '1';
    }
  }

  // 加载现有电视剧的所有图片
  Future<void> _loadExistingImages() async {
    if (widget.tvShow == null || widget.tvShow!.directoryPath == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final directory = Directory(widget.tvShow!.directoryPath!);
      if (await directory.exists()) {
        List<File> imageFiles = [];

        await for (final entity in directory.list()) {
          if (entity is File) {
            final filename = p.basename(entity.path);
            final extension = p.extension(filename).toLowerCase();

            // 检查是否是图片文件，并且不是封面图片
            if ([
                  '.jpg',
                  '.jpeg',
                  '.png',
                  '.gif',
                  '.bmp',
                  '.webp',
                ].contains(extension) &&
                filename != 'cover.jpg' &&
                filename != 'themesong.mp3') {
              imageFiles.add(entity);
              print('加载现有图片: $filename');
            }
          }
        }

        if (mounted) {
          setState(() {
            _additionalImages = imageFiles;
            _isLoading = false;
          });
        }

        print('成功加载 ${_additionalImages.length} 张现有图片');
      }
    } catch (e) {
      print('加载现有图片时出错: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载图片失败: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _overviewController.dispose();
    _currentProgressController.dispose();
    _totalProgressController.dispose();
    _aliasController.dispose();
    _tabController.dispose(); // 释放标签控制器
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _coverImage = File(image.path);
        });
      }
    } else {
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _pickThemeSong() async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _themeSong = File(result.files.first.path!);
        });
      }
    } else {
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _pickAdditionalImages() async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        setState(() {
          _additionalImages.addAll(
            images.map((image) => File(image.path)).toList(),
          );
        });
      }
    } else {
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('权限被拒绝'),
            content: const Text('需要存储权限才能选择文件。请在设置中授予权限。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('打开设置'),
              ),
            ],
          ),
    );
  }

  // TMDB搜索功能
  Future<void> _searchTMDB() async {
    final query = _nameController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先输入名称')));
      return;
    }

    setState(() {
      _isTMDBSearching = true;
    });

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder:
            (context) =>
                TMDBSearchDialog(initialQuery: query, mediaType: _mediaType),
      );

      if (result != null) {
        final details = result['details'] as Map<String, dynamic>;
        final posterFile = result['posterFile'] as File?;
        final imageFiles = result['imageFiles'] as List<File>?;

        // 填充表单数据
        if (_mediaType == 'tv') {
          _nameController.text = details['name'] ?? '';
          _overviewController.text = details['overview'] ?? '';
          _totalProgressController.text =
              (details['number_of_episodes'] ?? 1).toString();
        } else {
          _nameController.text = details['title'] ?? '';
          _overviewController.text = details['overview'] ?? '';
          _totalProgressController.text = '1'; // 电影默认为1集
        }

        // 设置封面图片
        if (posterFile != null) {
          setState(() {
            _coverImage = posterFile;
          });
        }

        // 处理剧照
        if (imageFiles != null && imageFiles.isNotEmpty) {
          final selectedImages = await showDialog<List<File>>(
            context: context,
            builder: (context) => ImageSelectionDialog(images: imageFiles),
          );

          if (selectedImages != null && selectedImages.isNotEmpty) {
            setState(() {
              _additionalImages.addAll(selectedImages);
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('搜索出错: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isTMDBSearching = false;
        });
      }
    }
  }

  void _addLine() {
    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController();
        return AlertDialog(
          title: const Text('添加台词'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: '台词内容',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _lines.add(text);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  void _editLine(int index) {
    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController(text: _lines[index]);
        return AlertDialog(
          title: const Text('编辑台词'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: '台词内容',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _lines[index] = text;
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
    });
  }

  void _addInlineLine(File image) {
    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController();
        final imageName = p.basename(image.path);

        // 如果是从网络下载的图片（不在电视剧目录中），需要预先计算它将被保存的新文件名
        // 仅在添加新电视剧或编辑现有电视剧但图片不在电视剧目录中时执行此操作

        final existingText = _inlineLines[imageName];

        if (existingText != null) {
          textController.text = existingText;
        }

        return AlertDialog(
          title: Text(existingText != null ? '编辑图片台词' : '添加图片台词'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 150,
                child: Image.file(image, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: '台词内容',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            if (existingText != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    // 从两个可能的键中删除
                    _inlineLines.remove(imageName);
                  });
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('删除台词'),
              ),
            TextButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    // 使用有效名称保存台词
                    // 打印详细日志以便调试
                    _inlineLines[imageName] = text;
                    print('已添加图片台词: $imageName -> $text');
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_coverImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择封面图片')));
      return;
    }

    // 主题曲不再是必需的
    // if (_themeSong == null) {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(const SnackBar(content: Text('请选择主题曲')));
    //   return;
    // }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 通过 TvShowNotifier 获取所有需要的功能，不直接使用 DataService
      final tvShowNotifier = Provider.of<TvShowNotifier>(
        context,
        listen: false,
      );

      final name = _nameController.text.trim();
      final overview = _overviewController.text.trim();
      final mediaType = _mediaType;
      final currentProgress = num.parse(_currentProgressController.text);
      final totalProgress = num.parse(_totalProgressController.text);
      final alias =
          _aliasController.text.trim().isEmpty
              ? null
              : _aliasController.text.trim();

      final progress = Progress(current: currentProgress, total: totalProgress);

      // 如果是编辑现有电视剧
      if (widget.isEditing && widget.tvShow != null) {
        final updatedShow = widget.tvShow!.copyWith(
          name: name,
          overview: overview,
          media_type: mediaType,
          progress: progress,
          favorite: _isFavorite,
          lines: _lines,
          inline_lines: _inlineLines,
          alias: alias,
        );

        // 检查名称是否变更
        final bool nameChanged = widget.tvShow!.name != name;

        // 保存封面图片
        if (_coverImage != null && widget.tvShow!.directoryPath != null) {
          final coverPath = p.join(widget.tvShow!.directoryPath!, 'cover.jpg');
          if (_coverImage!.path != coverPath) {
            await File(
              coverPath,
            ).writeAsBytes(await _coverImage!.readAsBytes());
          }
        }

        // 保存主题曲（如果有）
        if (_themeSong != null && widget.tvShow!.directoryPath != null) {
          final themeSongPath = p.join(
            widget.tvShow!.directoryPath!,
            'themesong.mp3',
          );
          if (_themeSong!.path != themeSongPath) {
            await File(
              themeSongPath,
            ).writeAsBytes(await _themeSong!.readAsBytes());
          }
        }

        // 保存额外的图片
        if (_additionalImages.isNotEmpty &&
            widget.tvShow!.directoryPath != null) {
          for (var image in _additionalImages) {
            final originalImageName = p.basename(image.path);

            // 检查图片是否已经在电视剧目录中（已有图片的路径会包含电视剧目录路径）
            if (image.path.startsWith(widget.tvShow!.directoryPath!)) {
              // 这是一个已有的图片，不需要复制
              print('保留已有图片: $originalImageName');
              continue;
            }

            // 这是一个新添加的图片，需要复制到电视剧目录
            // 创建新的图片名
            final newImageName =
                '$name-${DateTime.now().millisecondsSinceEpoch}-${_additionalImages.indexOf(image)}.jpg';
            final imagePath = p.join(
              widget.tvShow!.directoryPath!,
              newImageName,
            );
            await File(imagePath).writeAsBytes(await image.readAsBytes());
            print('添加新图片: $originalImageName -> $newImageName');

            // 如果原始图片名在inline_lines中有对应的台词，更新键名为新的图片名
            if (_inlineLines.containsKey(originalImageName)) {
              final text = _inlineLines[originalImageName];
              _inlineLines.remove(originalImageName);
              _inlineLines[newImageName] = text!;
              print('更新图片台词键名: $originalImageName -> $newImageName');
            }
          }
        }

        // 如果名称变更，传递原始电视剧对象以便正确处理目录重命名
        if (nameChanged) {
          await tvShowNotifier.updateTvShow(
            updatedShow,
            originalShow: widget.tvShow,
            forceJsonSave: true,
          );
        } else {
          await tvShowNotifier.updateTvShow(updatedShow, forceJsonSave: true);
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('电视剧更新成功')));
          Navigator.pop(context);
        }
      }
      // 如果是添加新电视剧
      else {
        try {
          // 创建新的电视剧
          await tvShowNotifier.createNewTvShow(
            name: name,
            overview: overview,
            mediaType: mediaType,
            progress: progress,
            favorite: _isFavorite,
            lines: _lines,
            inlineLines: _inlineLines,
            alias: alias,
            coverImage: _coverImage!,
            themeSong: _themeSong,
            additionalImages: _additionalImages,
          );

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('电视剧添加成功')));
            Navigator.pop(context);
          }
        } catch (e) {
          setState(() {
            _errorMessage = '创建电视剧失败: $e';
          });
          print('Error creating TV show: $e');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '保存失败: $e';
      });
      print('Error saving TV show: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑电视剧' : '添加电视剧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveChanges,
            tooltip: '保存',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),

                      // 基本信息部分
                      Text(
                        '基本信息',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),

                      // 名称
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '电视剧名称',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入电视剧名称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 简介
                      TextFormField(
                        controller: _overviewController,
                        decoration: const InputDecoration(
                          labelText: '简介',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入简介';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 媒体类型选择器
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '媒体类型',
                                border: OutlineInputBorder(),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _mediaType,
                                  isDense: true,
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _mediaType = newValue;
                                      });
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem<String>(
                                      value: 'tv',
                                      child: Text('电视剧'),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: 'movie',
                                      child: Text('电影'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _isTMDBSearching
                              ? Container(
                                width: 48,
                                height: 48,
                                padding: const EdgeInsets.all(8),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : IconButton(
                                icon: const Icon(Icons.search),
                                tooltip: '从TMDB搜索',
                                onPressed: _searchTMDB,
                              ),
                        ],
                      ),
                      if (_isTMDBSearching)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            '正在搜索和下载数据，请稍候...',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // 观看进度
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _currentProgressController,
                              decoration: const InputDecoration(
                                labelText: '当前进度',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '请输入当前进度';
                                }
                                if (num.tryParse(value) == null) {
                                  return '请输入有效数字';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _totalProgressController,
                              decoration: const InputDecoration(
                                labelText: '总进度',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '请输入总进度';
                                }
                                if (num.tryParse(value) == null) {
                                  return '请输入有效数字';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 别名
                      TextFormField(
                        controller: _aliasController,
                        decoration: const InputDecoration(
                          labelText: '别名 (可选)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 收藏状态
                      SwitchListTile(
                        title: const Text('收藏'),
                        value: _isFavorite,
                        onChanged: (value) {
                          setState(() {
                            _isFavorite = value;
                          });
                        },
                      ),
                      const Divider(),

                      // 封面和主题曲部分
                      Text(
                        '封面和主题曲',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),

                      // 封面图片
                      Row(
                        children: [
                          Expanded(
                            child:
                                _coverImage != null
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _coverImage!,
                                        height: 150,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : Container(
                                      height: 150,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(child: Text('暂无封面')),
                                    ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickCoverImage,
                                icon: const Icon(Icons.photo),
                                label: const Text('选择封面'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 主题曲
                      Row(
                        children: [
                          Expanded(
                            child:
                                _themeSong != null
                                    ? Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.music_note),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              p.basename(_themeSong!.path),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    : Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Text('暂无主题曲 (可选)'),
                                      ),
                                    ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _pickThemeSong,
                            icon: const Icon(Icons.music_note),
                            label: const Text('选择主题曲'),
                          ),
                        ],
                      ),
                      const Divider(),

                      // 台词部分
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '台词列表',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addLine,
                            tooltip: '添加台词',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 台词列表
                      _lines.isEmpty
                          ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('暂无台词，点击右上角添加'),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _lines.length,
                            itemBuilder: (context, index) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(_lines[index]),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _editLine(index),
                                        tooltip: '编辑',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _removeLine(index),
                                        tooltip: '删除',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      const Divider(),

                      // 剧照部分
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '剧照相册',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_photo_alternate),
                            onPressed: _pickAdditionalImages,
                            tooltip: '添加剧照',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 剧照列表
                      _additionalImages.isEmpty
                          ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('暂无剧照，点击右上角添加'),
                            ),
                          )
                          : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 0.75,
                                ),
                            itemCount: _additionalImages.length,
                            itemBuilder: (context, index) {
                              final image = _additionalImages[index];
                              final imageName = p.basename(image.path);
                              final hasInlineText = _inlineLines.containsKey(
                                imageName,
                              );

                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      image,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                  if (hasInlineText)
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        color: Colors.black54,
                                        child: Text(
                                          _inlineLines[imageName]!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            hasInlineText
                                                ? Icons.edit
                                                : Icons.text_fields,
                                            color: Colors.white,
                                          ),
                                          onPressed:
                                              () => _addInlineLine(image),
                                          tooltip:
                                              hasInlineText ? '编辑台词' : '添加台词',
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _additionalImages.removeAt(index);
                                              // 如果有内联台词，也一并删除
                                              _inlineLines.remove(imageName);
                                            });
                                          },
                                          tooltip: '删除图片',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),
    );
  }
}
