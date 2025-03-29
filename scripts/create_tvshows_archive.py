import zipfile
import os


def zip_directory(src_dir, dst_zip):
    """
    将源目录递归压缩到ZIP文件，确保中文文件名使用UTF-8编码
    """
    with zipfile.ZipFile(dst_zip, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # 遍历目录树
        for root, dirs, files in os.walk(src_dir):
            for file in files:
                file_path = os.path.join(root, file)
                
                # 计算相对于源目录的路径（保证压缩包内路径正确）
                rel_path = os.path.relpath(file_path, src_dir)
                
                # 将文件添加到ZIP（自动处理UTF-8编码）
                zipf.write(file_path, rel_path)

if __name__ == "__main__":
    # 若压缩文件存在则删除
    if os.path.exists('assets/tv_shows_archive.zip'):
        os.remove('assets/tv_shows_archive.zip')
    # 定义路径（使用os.path保证跨平台兼容性）
    src_dir = os.path.join('assets', 'tv_shows')
    dst_zip = os.path.join('assets', 'tv_shows_archive.zip')

    # 检查源目录是否存在
    if not os.path.exists(src_dir):
        raise FileNotFoundError(f"源目录 '{src_dir}' 不存在")

    # 执行压缩操作
    zip_directory(src_dir, dst_zip)
    print(f"压缩包已创建：{os.path.abspath(dst_zip)}")
