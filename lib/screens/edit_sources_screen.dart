import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../models/play_source.dart';
import '../providers/play_source_notifier.dart'; // Import Notifier
import '../services/data_service.dart'; // Import DataService

class EditSourcesScreen extends StatefulWidget {
  const EditSourcesScreen({super.key});

  @override
  State<EditSourcesScreen> createState() => _EditSourcesScreenState();
}

class _EditSourcesScreenState extends State<EditSourcesScreen> {
  final DataService _dataService = DataService(); // Instantiate DataService
  List<PlaySource> _sources = [];
  bool _isLoading = true;
  String? _error;

  final _formKey = GlobalKey<FormState>(); // For add/edit dialog form
  final _nameController = TextEditingController();
  final _urlTemplateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlTemplateController.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Ensure data is initialized (might not be strictly necessary here if main did it)
      // await _dataService.initializeDataIfNeeded();
      final loadedSources = await _dataService.loadPlaySources();
      if (!mounted) return; // Add mounted check
      setState(() {
        _sources = loadedSources;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return; // Add mounted check
      setState(() {
        _error = "加载数据源失败: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSources() async {
    // Show loading indicator maybe?
    try {
      await _dataService.savePlaySources(_sources);
      if (!mounted) return; // Add mounted check
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据源已保存')),
      );
      // --- Trigger reload in notifier ---
      if (!mounted) return; // Add mounted check
      Provider.of<PlaySourceNotifier>(context, listen: false).reloadPlaySources();
    } catch (e) {
       if (!mounted) return; // Add mounted check
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存数据源失败: $e')),
      );
    }
  }

  void _showEditDialog({PlaySource? sourceToEdit}) {
    bool isEditing = sourceToEdit != null;
    _nameController.text = isEditing ? sourceToEdit.name : '';
    _urlTemplateController.text = isEditing ? sourceToEdit.urlTemplate : '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? '编辑数据源' : '添加数据源'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称 (例如: [在线]爱壹帆)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '名称不能为空';
                  }
                  // Check for duplicate names if adding
                  if (!isEditing && _sources.any((s) => s.name == value)) {
                     return '名称已存在';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _urlTemplateController,
                 decoration: const InputDecoration(
                    labelText: 'URL 模板',
                    hintText: '使用 {name}, {tmdb_id}, {media_type}'
                 ),
                 maxLines: null, // Allow multiple lines
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'URL 模板不能为空';
                  }
                   if (!value.contains('{name}') && !value.contains('{tmdb_id}')) {
                     return '模板至少需要 {name} 或 {tmdb_id}';
                   }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text(isEditing ? '保存' : '添加'),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final newSource = PlaySource(
                  name: _nameController.text,
                  urlTemplate: _urlTemplateController.text,
                );
                setState(() {
                  if (isEditing) {
                    final index = _sources.indexWhere((s) => s.name == sourceToEdit.name);
                    if (index != -1) {
                      _sources[index] = newSource;
                    }
                  } else {
                    _sources.add(newSource);
                  }
                   // Sort maybe?
                   _sources.sort((a, b) => a.name.compareTo(b.name));
                });
                _saveSources(); // Save changes immediately
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

   void _deleteSource(PlaySource sourceToDelete) {
      setState(() {
         _sources.removeWhere((s) => s.name == sourceToDelete.name);
      });
      _saveSources(); // Save changes immediately
   }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑数据源'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: '保存更改',
            onPressed: _sources.isEmpty ? null : _saveSources, // Disable if no sources
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _sources.isEmpty
                  ? const Center(child: Text('没有数据源，请添加。'))
                  : ListView.separated(
                      itemCount: _sources.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final source = _sources[index];
                        return ListTile(
                          title: Text(source.name),
                          subtitle: Text(source.urlTemplate, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                                IconButton(
                                   icon: const Icon(Icons.edit_outlined, size: 20),
                                   tooltip: '编辑',
                                   onPressed: () => _showEditDialog(sourceToEdit: source),
                                ),
                                IconButton(
                                   icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                   tooltip: '删除',
                                   onPressed: () => _deleteSource(source),
                                ),
                             ],
                          ),
                          // Optional: Long press to edit/delete?
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        tooltip: '添加数据源',
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}