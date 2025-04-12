import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsInfoScreen extends StatefulWidget {
  const PermissionsInfoScreen({super.key});

  @override
  State<PermissionsInfoScreen> createState() => _PermissionsInfoScreenState();
}

class _PermissionsInfoScreenState extends State<PermissionsInfoScreen> {
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
    });

    final statuses = {
      Permission.storage: await Permission.storage.status,
      Permission.manageExternalStorage:
          await Permission.manageExternalStorage.status,
    };

    if (mounted) {
      setState(() {
        _permissionStatuses = statuses;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();

    if (mounted) {
      setState(() {
        _permissionStatuses[permission] = status;
      });
    }
  }

  String _getStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '已授权';
      case PermissionStatus.denied:
        return '已拒绝';
      case PermissionStatus.permanentlyDenied:
        return '永久拒绝';
      case PermissionStatus.restricted:
        return '受限制';
      case PermissionStatus.limited:
        return '有限制';
      default:
        return '未知状态';
    }
  }

  Color _getStatusColor(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
      case PermissionStatus.permanentlyDenied:
        return Colors.red;
      case PermissionStatus.restricted:
      case PermissionStatus.limited:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('权限说明')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  const Text(
                    '应用权限说明',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '爽剧应用需要以下权限才能正常运行。这些权限用于保存和管理电视剧数据，包括图片、音乐和台词。',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),

                  // 存储权限
                  _buildPermissionCard(
                    icon: Icons.sd_storage,
                    title: '存储权限',
                    description:
                        '用于保存和读取电视剧图片、主题曲和其他数据。当您添加新的电视剧、上传图片或选择音乐时需要此权限。',
                    permission: Permission.storage,
                    status: _permissionStatuses[Permission.storage],
                  ),

                  const SizedBox(height: 16),

                  // 管理外部存储权限
                  _buildPermissionCard(
                    icon: Icons.folder_special,
                    title: '管理外部存储权限',
                    description:
                        '在Android 11及以上版本，需要此权限来管理应用外部的文件，例如从相册选择图片或从文件管理器选择音乐文件。',
                    permission: Permission.manageExternalStorage,
                    status:
                        _permissionStatuses[Permission.manageExternalStorage],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    '权限使用场景',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  _buildUsageScenario(
                    icon: Icons.add_photo_alternate,
                    title: '添加图片',
                    description: '当您添加新的电视剧或编辑现有电视剧的图片时，应用需要访问您的相册或文件系统来选择图片。',
                  ),

                  const SizedBox(height: 12),

                  _buildUsageScenario(
                    icon: Icons.music_note,
                    title: '选择主题曲',
                    description: '当您为电视剧设置主题曲时，应用需要访问您的音乐文件或文件系统来选择音频文件。',
                  ),

                  const SizedBox(height: 12),

                  _buildUsageScenario(
                    icon: Icons.save,
                    title: '保存数据',
                    description: '应用需要将电视剧数据保存到设备存储中，包括图片、音乐和台词信息。',
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () => _checkPermissions(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('刷新权限状态'),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('打开应用设置'),
                  ),
                ],
              ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required Permission permission,
    PermissionStatus? status,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(status)),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            if (status != null && status != PermissionStatus.granted)
              ElevatedButton(
                onPressed: () => _requestPermission(permission),
                child: const Text('请求权限'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageScenario({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
