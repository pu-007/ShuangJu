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
import logging
from datetime import datetime

# --- 日志配置 ---
LOG_FILE = 'tmdb_script.log'
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler(sys.stdout) # 同时输出到控制台
    ]
)

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

def _search_endpoint(api_key, query, endpoint_type):
    """Helper function to search a specific TMDB endpoint (tv or movie)."""
    if endpoint_type not in ['tv', 'movie']:
        logging.error(f"无效的搜索端点类型: {endpoint_type}")
        return [] # Return empty list on error

    search_url = f"{TMDB_API_BASE_URL}/search/{endpoint_type}"
    params = {
        'api_key': api_key,
        'query': query,
        'language': 'zh-CN'
    }
    logging.info(f"开始搜索 {endpoint_type.upper()}: '{query}'")
    try:
        logging.info(f"请求搜索 URL: {search_url}，参数: {params}")
        response = requests.get(search_url, params=params, timeout=15) # 添加超时
        response.raise_for_status()
        results = response.json().get('results', [])
        logging.info(f"搜索 {endpoint_type.upper()} '{query}' 找到 {len(results)} 个结果。")
        # Add media_type to each result
        for result in results:
            result['media_type'] = endpoint_type
        return results
    except requests.exceptions.Timeout:
        logging.error(f"搜索 {endpoint_type.upper()} '{query}' 时发生超时错误。", exc_info=True)
        return []
    except requests.exceptions.RequestException as e:
        logging.error(f"搜索 {endpoint_type.upper()} '{query}' 时发生网络错误: {e}", exc_info=True)
        return [] # Return empty list on error
    except json.JSONDecodeError as e:
        logging.error(f"解析 {endpoint_type.upper()} 搜索结果 '{query}' 时发生错误: {e}", exc_info=True)
        return [] # Return empty list on error

def search_media(api_key, query):
    """使用 TMDB API 搜索电视剧，如果找不到则搜索电影，并处理用户多选"""
    logging.info(f"开始媒体搜索: '{query}'")

    # 1. 搜索电视剧
    tv_results = _search_endpoint(api_key, query, 'tv')

    # 2. 如果电视剧无结果，则搜索电影
    movie_results = []
    if not tv_results:
        logging.info(f"未找到电视剧 '{query}'，尝试搜索电影。")
        movie_results = _search_endpoint(api_key, query, 'movie')

    # 3. 合并结果
    all_results = tv_results + movie_results

    # 4. 处理结果和用户选择
    if not all_results:
        logging.warning(f"未找到与 '{query}' 相关的电视剧或电影。")
        # 询问是否重试 (仅在 TV 和 Movie 都搜索失败后)
        retry = input(f"未找到与 '{query}' 相关的任何内容。是否尝试使用其他名称搜索? (y/n): ").lower()
        if retry == 'y':
            new_query = input("请输入新的媒体名称: ")
            if new_query:
                logging.info(f"用户选择使用新名称 '{new_query}' 重试搜索。")
                return search_media(api_key, new_query) # 递归调用进行重试
            else:
                logging.warning("用户未输入新名称，放弃重试。")
                return [] # 返回空列表表示最终未找到
        else:
            logging.info(f"用户放弃为 '{query}' 重试搜索。")
            return [] # 返回空列表表示未找到

    # 自动选择唯一结果 (现在需要检查总数)
    if len(all_results) == 1:
        selected_media = all_results[0]
        media_type = selected_media.get('media_type', '未知类型').upper()
        name_field = 'name' if selected_media.get('media_type') == 'tv' else 'title'
        media_name = selected_media.get(name_field, '未知名称')
        logging.info(f"自动选择唯一结果 [{media_type}]: '{media_name}' (ID: {selected_media.get('id')})")
        return [selected_media] # 返回包含单个结果的列表

    # 处理多个结果 (TV 和 Movie)
    print(f"\n找到多个与 '{query}' 相关的结果:")
    for i, media in enumerate(all_results):
        media_type = media.get('media_type', '未知类型').upper()
        name_field = 'name' if media.get('media_type') == 'tv' else 'title'
        date_field = 'first_air_date' if media.get('media_type') == 'tv' else 'release_date'
        name = media.get(name_field, '未知名称')
        date = media.get(date_field, '未知日期')
        overview = media.get('overview', '无简介')
        print(f"  {i + 1}. [{media_type}] {name} ({date}) - {overview[:50]}...")

    while True:
        try:
            prompt = (f"请输入选项编号 (1-{len(all_results)})，多个用逗号隔开，"
                      f"输入 'a' 选择全部，或输入 's' 跳过 '{query}': ")
            choice_str = input(prompt).strip()

            if choice_str.lower() == 's':
                logging.info(f"用户选择跳过 '{query}' 的所有结果。")
                return [] # 用户选择跳过，返回空列表

            if choice_str.lower() == 'a':
                logging.info(f"用户选择处理 '{query}' 的全部 {len(all_results)} 个结果。")
                return all_results # 返回所有结果

            selected_indices = []
            parts = choice_str.split(',')
            valid_selection = True
            for part in parts:
                part = part.strip()
                if not part.isdigit():
                    print(f"错误：输入 '{part}' 不是有效的数字。")
                    valid_selection = False
                    break
                index = int(part) - 1
                if 0 <= index < len(all_results):
                    if index not in selected_indices:
                         selected_indices.append(index)
                else:
                    print(f"错误：选项 '{part}' 超出范围 (应为 1-{len(all_results)})。")
                    valid_selection = False
                    break

            if valid_selection and selected_indices:
                selected_media_list = [all_results[i] for i in selected_indices]
                selected_names_types = [
                    f"[{m.get('media_type','?').upper()}] {m.get('name' if m.get('media_type') == 'tv' else 'title', '未知')}"
                    for m in selected_media_list
                ]
                logging.info(f"用户为 '{query}' 选择了 {len(selected_media_list)} 个结果: {selected_names_types}")
                return selected_media_list
            elif not valid_selection:
                 print("请重新输入有效的选项。")
            else: # 输入为空或无效但未触发错误
                 print("错误：未选择任何有效选项。")

        except ValueError:
            print("错误：输入格式无效，请输入数字、逗号、'a' 或 's'。")
        except EOFError:
             logging.error("输入中断。", exc_info=True)
             return [] # 输入中断，返回空列表

def get_tv_show_details(api_key, tv_id):
    """获取电视剧详细信息，包括修正后的图片请求"""
    details_url = f"{TMDB_API_BASE_URL}/tv/{tv_id}"
    # 添加 include_image_language=en,null 以尝试获取剧照
    # 'null' 用于获取无特定语言的图片 (通常是 backdrops)
    # 'en' 用于获取英文相关图片 (可能包含一些海报或带文字的图片)
    # 'zh' 也可以加入，但可能导致 backdrops 变少，如果需要中文海报可以考虑 'zh,en,null'
    params = {
        'api_key': api_key,
        'language': 'zh-CN', # 主要信息语言
        'append_to_response': 'images',
        'include_image_language': 'en,null' # 关键参数：获取英文和无语言图片
    }
    logging.info(f"请求电视剧详情 (ID: {tv_id})，URL: {details_url}，参数: {params}")
    try:
        response = requests.get(details_url, params=params)
        response.raise_for_status()
        details_data = response.json()
        logging.info(f"成功获取电视剧详情 (ID: {tv_id})")
        # 记录获取到的图片数量，方便调试
        images_info = details_data.get('images', {})
        backdrop_count = len(images_info.get('backdrops', []))
        poster_count = len(images_info.get('posters', []))
        logo_count = len(images_info.get('logos', [])) # TMDB API v3 可能不直接返回 logos，但以防万一
        logging.info(f"  - 图片信息: Backdrops={backdrop_count}, Posters={poster_count}, Logos={logo_count}")
        return details_data
    except requests.exceptions.RequestException as e:
        logging.error(f"获取电视剧详情 (ID: {tv_id}) 时发生网络错误: {e}", exc_info=True)
        return None
    except json.JSONDecodeError as e:
        logging.error(f"解析电视剧详情 (ID: {tv_id}) 时发生错误: {e}", exc_info=True)
        return None

def get_movie_details(api_key, movie_id):
    """获取电影详细信息，包括修正后的图片请求"""
    details_url = f"{TMDB_API_BASE_URL}/movie/{movie_id}"
    params = {
        'api_key': api_key,
        'language': 'zh-CN',
        'append_to_response': 'images',
        'include_image_language': 'en,null' # 与 TV 保持一致
    }
    logging.info(f"请求电影详情 (ID: {movie_id})，URL: {details_url}，参数: {params}")
    try:
        response = requests.get(details_url, params=params, timeout=15) # 添加超时
        response.raise_for_status()
        details_data = response.json()
        logging.info(f"成功获取电影详情 (ID: {movie_id})")
        # 记录获取到的图片数量
        images_info = details_data.get('images', {})
        backdrop_count = len(images_info.get('backdrops', []))
        poster_count = len(images_info.get('posters', []))
        logo_count = len(images_info.get('logos', []))
        logging.info(f"  - 图片信息: Backdrops={backdrop_count}, Posters={poster_count}, Logos={logo_count}")
        return details_data
    except requests.exceptions.Timeout:
        logging.error(f"获取电影详情 (ID: {movie_id}) 时发生超时错误。", exc_info=True)
        return None
    except requests.exceptions.RequestException as e:
        logging.error(f"获取电影详情 (ID: {movie_id}) 时发生网络错误: {e}", exc_info=True)
        return None
    except json.JSONDecodeError as e:
        logging.error(f"解析电影详情 (ID: {movie_id}) 时发生错误: {e}", exc_info=True)
        return None

def download_image(url, save_path):
    """下载图片并保存，添加日志记录"""
    logging.info(f"尝试下载图片从 {url} 到 {save_path}")
    try:
        response = requests.get(url, stream=True, timeout=30) # 添加超时
        response.raise_for_status()
        with open(save_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        logging.info(f"图片成功下载并保存到: {save_path}")
        return True
    except requests.exceptions.Timeout:
        logging.error(f"下载图片 {url} 时发生超时错误。", exc_info=True)
        return False
    except requests.exceptions.RequestException as e:
        logging.error(f"下载图片 {url} 时发生网络错误: {e}", exc_info=True)
        return False
    except IOError as e:
        logging.error(f"保存图片到 {save_path} 时发生 IO 错误: {e}", exc_info=True)
        return False
    except Exception as e: # 捕获其他潜在错误
        logging.error(f"下载或保存图片 {url} 时发生未知错误: {e}", exc_info=True)
        return False

# --- 文件和目录操作 ---

def create_tv_show_folder(show_name):
    """创建电视剧文件夹"""
    # 清理名称，避免创建无效的文件夹名 (移除不安全字符)
    safe_show_name = "".join(c for c in show_name if c.isalnum() or c in (' ', '-', '_')).rstrip()
    folder_path = os.path.join(TV_SHOWS_BASE_PATH, safe_show_name)
    os.makedirs(folder_path, exist_ok=True) # exist_ok=True 表示如果文件夹已存在则不报错
    return folder_path, safe_show_name

def update_init_json(folder_path, media_name, media_id, media_type, total_eps, overview):
    """创建或更新 init.json 文件，包含媒体类型、TMDB ID 和简介。仅 TV 类型包含 progress。"""
    init_file_path = os.path.join(folder_path, "init.json")

    # 构建基础结构
    new_data_structure = {
        "name": media_name,
        "tmdb_id": media_id,
        "media_type": media_type, # 添加媒体类型
        "overview": overview if overview else "",
        "favorite": False,
        "lines": []
    }

    # 仅当是电视剧时添加 progress 字段
    if media_type == 'tv':
        new_data_structure["progress"] = {
            "current": 0,
            "total": total_eps if total_eps is not None else 0
        }

    data_to_write = new_data_structure

    if os.path.exists(init_file_path):
        try:
            logging.info(f"尝试读取现有的 init.json: {init_file_path}")
            with open(init_file_path, 'r', encoding='utf-8') as f:
                existing_data = json.load(f)
            logging.info(f"成功读取现有的 init.json")

            # 更新字段，保留其他可能存在的自定义字段
            existing_data["name"] = media_name
            existing_data["tmdb_id"] = media_id
            existing_data["media_type"] = media_type # 更新或添加媒体类型
            existing_data["overview"] = overview if overview else existing_data.get("overview", "")

            # 处理 progress 字段 (仅 TV)
            if media_type == 'tv':
                if "progress" in existing_data and isinstance(existing_data["progress"], dict):
                    existing_data["progress"]["total"] = total_eps if total_eps is not None else existing_data["progress"].get("total", 0)
                    existing_data["progress"]["current"] = existing_data["progress"].get("current", 0)
                else:
                    # 如果现有数据没有 progress 或格式不对，则添加新的
                    existing_data["progress"] = new_data_structure["progress"]
            elif "progress" in existing_data:
                # 如果之前是 TV 现在变成 Movie，或者错误地包含了 progress，则移除它
                del existing_data["progress"]
                logging.info(f"媒体类型不是 TV，已从现有 init.json 中移除 progress 字段。")


            # 保留现有的 favorite 和 lines
            existing_data["favorite"] = existing_data.get("favorite", False)
            existing_data["lines"] = existing_data.get("lines", [])

            data_to_write = existing_data # 使用更新后的现有数据
            logging.info(f"准备更新 '{media_name}' (ID: {media_id}, Type: {media_type}) 的 init.json")

        except (json.JSONDecodeError, IOError) as e:
            logging.warning(f"读取或解析现有的 init.json ({init_file_path}) 失败: {e}。将创建新的文件。", exc_info=True)
            # 如果读取失败，则使用全新的结构 (已包含 media_type 和可能的 progress)

    try:
        logging.info(f"写入 init.json 到: {init_file_path}")
        with open(init_file_path, 'w', encoding='utf-8') as f:
            # 为了确保 name, tmdb_id, media_type 在前面，可以手动构建字典顺序
            # 但标准 json 不保证顺序，这里仅为可读性尝试
            ordered_data = {}
            key_order = ["name", "tmdb_id", "media_type", "overview", "progress", "favorite", "lines"]
            for key in key_order:
                if key in data_to_write:
                    ordered_data[key] = data_to_write[key]
            # 添加其他可能存在的自定义字段
            for key, value in data_to_write.items():
                if key not in ordered_data:
                    ordered_data[key] = value

            json.dump(ordered_data, f, ensure_ascii=False, indent=4)
        logging.info(f"成功创建/更新 '{media_name}' (ID: {media_id}, Type: {media_type}) 的 init.json。")
    except IOError as e:
        logging.error(f"写入 init.json ({init_file_path}) 失败: {e}", exc_info=True)


# --- 主处理逻辑 ---

def process_single_media_data(media_data):
    """根据已获取的媒体数据字典 (TV或Movie) 进行处理：获取详情、创建文件、下载图片"""
    media_type = media_data.get('media_type')
    media_id = media_data.get('id')

    if not media_type or not media_id:
        logging.error(f"媒体数据缺少类型或 ID: {media_data}")
        return

    # 统一获取名称 (TV用name, Movie用title)
    name_field = 'name' if media_type == 'tv' else 'title'
    original_name_field = 'original_name' if media_type == 'tv' else 'original_title'
    found_name = media_data.get(name_field, media_data.get(original_name_field, ''))

    if not found_name:
         logging.error(f"媒体数据 (ID: {media_id}, Type: {media_type}) 缺少名称。")
         return

    logging.info(f"\n--- 开始处理已选定媒体 [{media_type.upper()}]: '{found_name}' (ID: {media_id}) ---")

    # 1. 获取详细信息 (根据类型调用不同函数)
    logging.info(f"获取 '{found_name}' (ID: {media_id}, Type: {media_type}) 的详细信息...")
    details = None
    if media_type == 'tv':
        details = get_tv_show_details(TMDB_API_KEY, media_id)
    elif media_type == 'movie':
        details = get_movie_details(TMDB_API_KEY, media_id)
    else:
        logging.error(f"未知的媒体类型: {media_type} for ID: {media_id}")
        return

    if not details:
        logging.error(f"无法获取 '{found_name}' (ID: {media_id}, Type: {media_type}) 的详细信息，跳过处理。")
        return

    # 统一提取信息
    overview = details.get('overview', '')
    poster_path = details.get('poster_path')
    images_data = details.get('images', {})
    backdrops = images_data.get('backdrops', []) if isinstance(images_data, dict) else []

    # 特定类型信息
    total_eps = None
    if media_type == 'tv':
        total_eps = details.get('number_of_episodes')
        logging.info(f"'{found_name}' (TV, ID: {media_id}) 信息: 总集数={total_eps if total_eps is not None else '未知'}, "
                     f"简介='{overview[:50]}...'")
    else: # Movie
         logging.info(f"'{found_name}' (Movie, ID: {media_id}) 信息: 简介='{overview[:50]}...'")


    # 2. 创建文件夹 (使用统一的名称)
    # 注意：如果电影和电视剧重名，它们会存入同一个文件夹，这可能是期望行为，也可能不是。
    # 如果需要区分，可以在文件夹名称中加入类型，例如 create_folder(f"{found_name} [{media_type.upper()}]")
    folder_path, safe_media_name = create_tv_show_folder(found_name) # 复用现有函数，但变量名改为 media
    logging.info(f"确保文件夹存在/已创建: {folder_path}")

    # 3. 创建/更新 init.json (传递 media_type)
    update_init_json(folder_path, found_name, media_id, media_type, total_eps, overview)

    # 4. 下载海报
    if poster_path:
        poster_url = f"{TMDB_IMAGE_BASE_URL}{poster_path}"
        cover_save_path = os.path.join(folder_path, "cover.jpg") # 仍然叫 cover.jpg
        logging.info(f"开始下载海报 '{poster_path}' 到 {cover_save_path}")
        if download_image(poster_url, cover_save_path):
             logging.info(f"海报成功下载到 {cover_save_path}")
    else:
        logging.warning(f"未找到 '{found_name}' (ID: {media_id}, Type: {media_type}) 的海报 (poster_path)。")

    # 5. 下载剧照 (最多5张)
    if backdrops:
        logging.info(f"开始下载 '{found_name}' (ID: {media_id}, Type: {media_type}) 的剧照 (最多 5 张)...")
        download_count = 0
        for i, backdrop in enumerate(backdrops):
            if download_count >= 5:
                logging.info("已达到剧照下载数量上限 (5 张)。")
                break
            backdrop_path = backdrop.get('file_path')
            if backdrop_path:
                backdrop_url = f"{TMDB_IMAGE_BASE_URL}{backdrop_path}"
                timestamp = datetime.now().strftime("%Y%m%d%H%M%S%f")
                # 文件名保持一致格式，但基于 safe_media_name
                backdrop_filename = f"{safe_media_name}-{timestamp}-{i+1}.jpg"
                backdrop_save_path = os.path.join(folder_path, backdrop_filename)
                logging.info(f"  下载剧照 {i+1}: '{backdrop_path}' 到 {backdrop_filename}")
                if download_image(backdrop_url, backdrop_save_path):
                    download_count += 1
            else:
                 logging.warning(f"  剧照 {i+1} 数据中缺少 'file_path': {backdrop}")
        logging.info(f"为 '{found_name}' (ID: {media_id}, Type: {media_type}) 共成功下载 {download_count} 张剧照。")
    else:
        logging.warning(f"未找到 '{found_name}' (ID: {media_id}, Type: {media_type}) 的剧照 (backdrops)。")

    logging.info(f"--- 完成处理媒体 [{media_type.upper()}]: '{found_name}' (ID: {media_id}) ---")


if __name__ == "__main__":
    logging.info("脚本开始运行。")
    # 确保 TV_SHOWS_BASE_PATH 存在
    try:
        os.makedirs(TV_SHOWS_BASE_PATH, exist_ok=True)
        logging.info(f"确保基础目录存在: {TV_SHOWS_BASE_PATH}")
    except OSError as e:
        logging.critical(f"无法创建基础目录 {TV_SHOWS_BASE_PATH}: {e}", exc_info=True)
        sys.exit(1) # 无法继续

    # 从命令行参数获取电视剧名称 (忽略脚本名称本身)
    initial_tv_show_names = sys.argv[1:]

    if not initial_tv_show_names:
        print("\n用法: python create_and_fetch_tvshows.py \"电视剧名称1\" \"电视剧名称2\" ...")
        logging.warning("没有提供命令行参数。")
        sys.exit(1)

    # 检查 API Key
    if not TMDB_API_KEY or TMDB_API_KEY == "YOUR_TMDB_API_KEY":
        logging.critical("错误：未设置有效的 TMDB_API_KEY。请在脚本顶部或环境变量中设置。")
        sys.exit(1)
    else:
        logging.info("TMDB API Key 已配置。")

    logging.info(f"开始处理命令行输入的名称: {initial_tv_show_names}")

    processed_count = 0
    failed_count = 0

    for name in initial_tv_show_names:
        logging.info(f"\n===== 开始处理命令行参数: '{name}' =====")
        try:
            # 调用新的搜索函数 search_media
            selected_media_list = search_media(TMDB_API_KEY, name)

            if not selected_media_list:
                logging.warning(f"对于命令行参数 '{name}'，未找到或未选择任何结果，跳过。")
                failed_count +=1 # 计入失败/跳过
                continue # 处理下一个命令行参数

            logging.info(f"对于 '{name}'，将处理 {len(selected_media_list)} 个选定的媒体条目。")
            for media_data in selected_media_list:
                try:
                    # 调用新的处理函数 process_single_media_data
                    process_single_media_data(media_data)
                    processed_count += 1
                except Exception as inner_e: # 捕获处理单个条目时的意外错误
                    failed_count += 1
                    media_id = media_data.get('id', '未知ID')
                    media_type = media_data.get('media_type', '?').upper()
                    name_field = 'name' if media_type == 'TV' else 'title'
                    media_name_proc = media_data.get(name_field, '未知名称')
                    logging.error(f"处理媒体 [{media_type}] '{media_name_proc}' (ID: {media_id}) 时发生意外错误: {inner_e}", exc_info=True)

        except Exception as outer_e: # 捕获搜索或选择过程中的意外错误
             failed_count += 1
             logging.error(f"处理命令行参数 '{name}' 的搜索或选择时发生意外错误: {outer_e}", exc_info=True)
        logging.info(f"===== 完成处理命令行参数: '{name}' =====")


    logging.info("\n--- 处理总结 ---")
    logging.info(f"命令行参数总数: {len(initial_tv_show_names)}")
    logging.info(f"成功处理的媒体条目数: {processed_count}") # 更新描述
    logging.info(f"处理失败或跳过的媒体条目数: {failed_count}") # 更新描述
    logging.info(f"详细日志请查看: {LOG_FILE}")
    logging.info("脚本运行结束。")