# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "requests",
# ]
# ///
import requests
import os
import json
import sys
from datetime import datetime

# --- 配置 ---
# 在这里替换为你的 TMDB API Key
TMDB_API_KEY = os.getenv("TMDB_API_KEY", "YOUR_TMDB_API_KEY")
# TMDB API 端点
TMDB_API_BASE_URL = "https://api.themoviedb.org/3"
# 图片基础 URL
TMDB_IMAGE_BASE_URL = "https://image.tmdb.org/t/p/original"
# 电视剧信息保存的基础路径 (相对于脚本运行位置)
TV_SHOWS_BASE_PATH = "./assets/tv_shows" # 假设脚本在 scripts/ 目录下运行

# --- TMDB API 函数 ---

def search_tv_show(api_key, query):
    """使用 TMDB API 搜索电视剧，并处理用户选择"""
    search_url = f"{TMDB_API_BASE_URL}/search/tv"
    params = {
        'api_key': api_key,
        'query': query,
        'language': 'zh-CN' # 优先获取中文信息
    }
    try:
        print(f"信息：正在搜索 '{query}'...")
        response = requests.get(search_url, params=params)
        response.raise_for_status() # 如果请求失败则抛出异常
        results = response.json().get('results', [])

        if not results:
            print(f"警告：未找到与 '{query}' 相关的电视剧。")
            return [] # 返回空列表表示未找到

        if len(results) == 1:
            print(f"信息：自动选择唯一结果 '{results[0].get('name', '未知名称')}'")
            return results[0] # 直接返回唯一结果

        # 处理多个结果
        print(f"\n找到多个与 '{query}'相关的结果，请选择:")
        for i, show in enumerate(results):
            name = show.get('name', '未知名称')
            air_date = show.get('first_air_date', '未知日期')
            overview = show.get('overview', '无简介')
            print(f"  {i + 1}. {name} ({air_date}) - {overview[:50]}...") # 显示部分简介

        while True:
            try:
                choice = input(f"请输入选项编号 (1-{len(results)})，或输入 's' 跳过此剧集: ")
                if choice.lower() == 's':
                    print("信息：已跳过此剧集。")
                    return None # 用户选择跳过
                selected_index = int(choice) - 1
                if 0 <= selected_index < len(results):
                    return results[selected_index]
                else:
                    print(f"错误：无效的选项，请输入 1 到 {len(results)} 之间的数字或 's'。")
            except ValueError:
                print("错误：请输入有效的数字或 's'。")
            except EOFError: # 处理管道输入结束等情况
                 print("\n错误：输入中断。")
                 return None

    except requests.exceptions.RequestException as e:
        print(f"错误：搜索电视剧 '{query}' 时发生网络错误: {e}")
        return None # 返回 None 表示搜索出错
    except json.JSONDecodeError:
        print(f"错误：解析搜索结果 '{query}' 时发生错误")
        return None # 返回 None 表示解析出错

def get_tv_show_details(api_key, tv_id):
    """获取电视剧详细信息"""
    details_url = f"{TMDB_API_BASE_URL}/tv/{tv_id}"
    params = {
        'api_key': api_key,
        'language': 'zh-CN',
        'append_to_response': 'images' # 同时获取图片信息
    }
    try:
        response = requests.get(details_url, params=params)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"错误：获取电视剧详情 (ID: {tv_id}) 时发生网络错误: {e}")
        return None
    except json.JSONDecodeError:
        print(f"错误：解析电视剧详情 (ID: {tv_id}) 时发生错误")
        return None

def download_image(url, save_path):
    """下载图片并保存"""
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        with open(save_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        # print(f"图片已保存到: {save_path}")
        return True
    except requests.exceptions.RequestException as e:
        print(f"错误：下载图片 {url} 时发生网络错误: {e}")
        return False
    except IOError as e:
        print(f"错误：保存图片到 {save_path} 时发生错误: {e}")
        return False

# --- 文件和目录操作 ---

def create_tv_show_folder(show_name):
    """创建电视剧文件夹"""
    # 清理名称，避免创建无效的文件夹名 (移除不安全字符)
    safe_show_name = "".join(c for c in show_name if c.isalnum() or c in (' ', '-', '_')).rstrip()
    folder_path = os.path.join(TV_SHOWS_BASE_PATH, safe_show_name)
    os.makedirs(folder_path, exist_ok=True) # exist_ok=True 表示如果文件夹已存在则不报错
    return folder_path, safe_show_name

def update_init_json(folder_path, show_name, total_eps, overview):
    """创建或更新 init.json 文件，包含简介"""
    init_file_path = os.path.join(folder_path, "init.json")
    data = {
        "name": show_name,
        "overview": overview if overview else "", # 添加简介字段
        "progress": {
            "current": 0,
            "total": total_eps if total_eps is not None else 0 # 处理 None 的情况
        },
        "favorite": False,
        "lines": {}
    }

    if os.path.exists(init_file_path):
        try:
            with open(init_file_path, 'r', encoding='utf-8') as f:
                existing_data = json.load(f)
            # 更新 name, total eps 和 overview，保留其他字段
            existing_data["name"] = show_name
            existing_data["overview"] = overview if overview else existing_data.get("overview", "") # 更新或保留现有简介
            if "progress" in existing_data and isinstance(existing_data["progress"], dict):
                 existing_data["progress"]["total"] = total_eps if total_eps is not None else existing_data["progress"].get("total", 0)
            else:
                 existing_data["progress"] = data["progress"] # 如果 progress 不存在或格式不对，则覆盖
            # 保留现有的 favorite 和 lines (如果存在)
            existing_data["favorite"] = existing_data.get("favorite", False)
            existing_data["lines"] = existing_data.get("lines", {})

            data = existing_data # 使用更新后的现有数据
            print(f"信息：更新 '{show_name}' 的 init.json")
        except (json.JSONDecodeError, IOError) as e:
            print(f"警告：读取现有的 init.json ({init_file_path}) 失败: {e}。将创建新的文件。")
            # 如果读取失败，则使用默认新数据 (包含新的 overview)

    try:
        with open(init_file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=4)
        print(f"成功：'{show_name}' 的 init.json 已创建/更新。")
    except IOError as e:
        print(f"错误：写入 init.json ({init_file_path}) 失败: {e}")


# --- 主逻辑 ---

def process_tv_show(initial_show_name):
    """处理单个电视剧，包括搜索、选择、获取详情和下载资源"""
    current_show_name = initial_show_name
    print(f"\n--- 开始处理电视剧: {current_show_name} ---")

    if not TMDB_API_KEY or TMDB_API_KEY == "YOUR_TMDB_API_KEY":
        print("错误：请在脚本中设置你的 TMDB_API_KEY。")
        return

    search_result = None
    while True: # 循环直到成功选择或用户放弃
        # 1. 搜索电视剧并让用户选择
        search_result = search_tv_show(TMDB_API_KEY, current_show_name)

        if isinstance(search_result, dict): # 搜索成功且用户已选择
            break
        elif isinstance(search_result, list) and not search_result: # 未找到结果
            retry = input(f"未找到 '{current_show_name}'。是否尝试使用其他名称搜索? (y/n): ").lower()
            if retry == 'y':
                current_show_name = input("请输入新的电视剧名称: ")
                if not current_show_name:
                    print("错误：名称不能为空。")
                    return # 放弃处理此剧集
                continue # 继续循环，使用新名称搜索
            else:
                print(f"信息：放弃处理 '{initial_show_name}'。")
                return # 用户放弃
        else: # 搜索出错或用户跳过(search_result is None)
            print(f"信息：未能完成 '{initial_show_name}' 的搜索或选择。")
            return # 放弃处理此剧集

    # --- 已成功选择电视剧 ---
    tv_id = search_result.get('id')
    found_name = search_result.get('name', current_show_name) # 使用 TMDB 返回的官方名称
    print(f"信息：已选择电视剧 '{found_name}' (ID: {tv_id})")

    # 2. 获取电视剧详细信息
    print(f"信息：正在获取 '{found_name}' 的详细信息...")
    details = get_tv_show_details(TMDB_API_KEY, tv_id)
    if not details:
        print(f"错误：无法获取 '{found_name}' 的详细信息。")
        return # 获取详情失败

    total_eps = details.get('number_of_episodes')
    overview = details.get('overview', '') # 获取简介
    poster_path = details.get('poster_path')
    # 获取剧照列表 (backdrops) - 确保 images 键存在
    images_data = details.get('images', {})
    backdrops = images_data.get('backdrops', []) if isinstance(images_data, dict) else []


    print(f"信息：'{found_name}' 总集数: {total_eps if total_eps is not None else '未知'}")
    print(f"信息：简介: {overview[:100]}..." if overview else "无简介") # 显示部分简介

    # 3. 创建文件夹
    folder_path, safe_show_name = create_tv_show_folder(found_name)
    print(f"信息：确保文件夹存在/已创建: {folder_path}")

    # 4. 创建/更新 init.json (包含简介)
    update_init_json(folder_path, found_name, total_eps, overview)

    # 5. 下载海报
    if poster_path:
        poster_url = f"{TMDB_IMAGE_BASE_URL}{poster_path}"
        cover_save_path = os.path.join(folder_path, "cover.jpg")
        print(f"信息：开始下载海报 '{poster_path}' 到 {cover_save_path}...")
        if download_image(poster_url, cover_save_path):
            print(f"成功：海报已下载到 {cover_save_path}")
        else:
            print(f"失败：下载海报 '{poster_url}' 失败。") # 明确指出失败
    else:
        print(f"警告：未找到 '{found_name}' 的海报。")

    # 6. 下载剧照 (最多5张)
    if backdrops:
        print(f"信息：开始下载剧照 (最多 5 张)...")
        download_count = 0
        for i, backdrop in enumerate(backdrops):
            if download_count >= 5:
                print("信息：已达到剧照下载数量上限 (5 张)。")
                break
            backdrop_path = backdrop.get('file_path')
            if backdrop_path:
                backdrop_url = f"{TMDB_IMAGE_BASE_URL}{backdrop_path}"
                # 生成文件名: 名称-日期时间-索引.jpg
                timestamp = datetime.now().strftime("%Y%m%d%H%M%S%f") # 添加微秒以增加唯一性
                backdrop_filename = f"{safe_show_name}-{timestamp}-{i+1}.jpg"
                backdrop_save_path = os.path.join(folder_path, backdrop_filename)
                print(f"  下载剧照 {i+1}: '{backdrop_path}' 到 {backdrop_filename}...")
                if download_image(backdrop_url, backdrop_save_path):
                    download_count += 1
                    print(f"  成功：剧照 {i+1} 已下载。")
                else:
                    print(f"  失败：下载剧照 {i+1} ({backdrop_url}) 失败。") # 明确指出失败
            else:
                 print(f"  警告：剧照 {i+1} 数据中缺少 'file_path'。")
        print(f"信息：共成功下载 {download_count} 张剧照。")
    else:
        print(f"警告：未找到 '{found_name}' 的剧照 (backdrops)。")

    print(f"--- 完成处理电视剧: {found_name} ---")


if __name__ == "__main__":
    # 确保 TV_SHOWS_BASE_PATH 存在
    os.makedirs(TV_SHOWS_BASE_PATH, exist_ok=True)

    # 从命令行参数获取电视剧名称 (忽略脚本名称本身)
    tv_show_names = sys.argv[1:]

    if not tv_show_names:
        print("用法: python create_and_fetch_tvshows.py \"电视剧名称1\" \"电视剧名称2\" ...")
        sys.exit(1)

    if not TMDB_API_KEY or TMDB_API_KEY == "YOUR_TMDB_API_KEY":
        print("错误：请在脚本顶部设置你的 TMDB_API_KEY。")
        sys.exit(1)

    print("开始处理...")
    for name in tv_show_names:
        process_tv_show(name)

    print("\n所有处理完成。")