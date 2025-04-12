# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "Pillow", # For image processing
# ]
# ///
from datetime import datetime
import os
import json
import argparse
import logging
import sys
from pathlib import Path
from PIL import Image

# --- Constants ---
# Assuming this script is in the 'scripts' directory
# Adjust the path if necessary to point to the parent of 'assets/tv_shows'
PROJECT_ROOT = Path(__file__).parent.parent
TV_SHOWS_BASE_PATH = PROJECT_ROOT / "assets" / "tv_shows"
LOG_FILE = 'manage_tv_shows.log'
SUPPORTED_IMAGE_EXTENSIONS = ['.png', '.webp', '.jpeg', '.bmp', '.gif', '.tiff'] # Add more if needed

# --- Logging Setup ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)

# --- Helper Functions ---

def get_target_shows(base_path, specified_names=None, exclude=False):
    """
    Determines the target show directories based on specified names and exclude flag.
    Returns a list of Path objects for the target directories.
    """
    if not base_path.is_dir():
        logging.error(f"Base directory not found: {base_path}")
        return []

    all_show_dirs = [d for d in base_path.iterdir() if d.is_dir()]
    all_show_names = [d.name for d in all_show_dirs]

    if not specified_names:
        if exclude:
            logging.warning("Using --exclude without specifying names has no effect. Processing all shows.")
            return all_show_dirs
        else:
            logging.info("No specific shows named. Processing all shows.")
            return all_show_dirs
    else:
        target_dirs = []
        specified_set = set(specified_names)
        if exclude:
            logging.info(f"Excluding specified shows: {specified_names}")
            for show_dir in all_show_dirs:
                if show_dir.name not in specified_set:
                    target_dirs.append(show_dir)
                else:
                     logging.debug(f"Excluding '{show_dir.name}'")
        else:
            logging.info(f"Processing only specified shows: {specified_names}")
            name_to_path = {d.name: d for d in all_show_dirs}
            for name in specified_set:
                if name in name_to_path:
                    target_dirs.append(name_to_path[name])
                else:
                    logging.warning(f"Specified show directory not found: '{name}'")

        return target_dirs

def sanitize_filename(name):
    """Removes or replaces characters unsafe for filenames, preserving Unicode."""
    # Replace potentially problematic separators first
    name = name.replace(':', ' - ').replace('/', '_').replace('\\', '_')

    # Define characters explicitly forbidden in Windows filenames
    # (excluding / and \ which were already replaced)
    # Also remove control characters (ASCII 0-31)
    forbidden_chars = set('<>"|?*') | set(chr(i) for i in range(32))

    # Remove forbidden characters
    sanitized = "".join(c for c in name if c not in forbidden_chars)

    # Replace multiple spaces/hyphens with single ones (optional, for tidiness)
    sanitized = ' '.join(sanitized.split())
    sanitized = '-'.join(filter(None, sanitized.split('-'))) # Filter removes empty strings from split

    # Remove leading/trailing whitespace/dots/hyphens
    sanitized = sanitized.strip(' .-')

    # Ensure the name is not empty after sanitization
    if not sanitized:
        logging.warning(f"Sanitization resulted in an empty filename for original name: '{name}'. Using 'default_name'.")
        return "default_name" # Provide a fallback

    return sanitized


# --- Core Functions ---

def modify_json_field(show_dir_path, action, key, value=None):
    """Adds or deletes a field in the init.json file."""
    json_path = show_dir_path / "init.json"
    if not json_path.is_file():
        logging.warning(f"init.json not found in {show_dir_path}, skipping JSON modification.")
        return False

    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        logging.error(f"Failed to read or parse {json_path}: {e}", exc_info=True)
        return False

    modified = False
    if action == 'add':
        if key not in data or data[key] != value:
            logging.info(f"[{show_dir_path.name}] Adding/Updating field: '{key}' = '{value}'")
            data[key] = value
            modified = True
        else:
            logging.debug(f"[{show_dir_path.name}] Field '{key}' already exists with the correct value.")
    elif action == 'delete':
        if key in data:
            logging.info(f"[{show_dir_path.name}] Deleting field: '{key}'")
            del data[key]
            modified = True
        else:
            logging.debug(f"[{show_dir_path.name}] Field '{key}' not found, nothing to delete.")
    else:
        logging.error(f"Invalid action specified: {action}")
        return False

    if modified:
        try:
            with open(json_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=4)
            logging.info(f"Successfully updated {json_path}")
            return True
        except IOError as e:
            logging.error(f"Failed to write updated {json_path}: {e}", exc_info=True)
            return False
    else:
        return True # No changes needed is considered success

def rename_and_convert_images(show_dir_path):
    """Renames images to a standard format and converts non-JPGs."""
    logging.info(f"--- Processing images in: {show_dir_path} ---")
    json_path = show_dir_path / "init.json"
    show_name_from_json = show_dir_path.name # Default to folder name

    if json_path.is_file():
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            show_name_from_json = data.get("name", show_dir_path.name) # Use name from JSON if available
        except (json.JSONDecodeError, IOError) as e:
            logging.warning(f"Could not read name from {json_path}, using folder name '{show_dir_path.name}'. Error: {e}")
    else:
        logging.warning(f"init.json not found in {show_dir_path}, using folder name '{show_dir_path.name}' for renaming.")

    safe_show_name = sanitize_filename(show_name_from_json)
    if not safe_show_name:
        logging.error(f"Could not generate a safe filename base for '{show_name_from_json}', skipping image processing for {show_dir_path}")
        return False

    image_files = []
    for item in show_dir_path.iterdir():
        # Check if it's a file, not cover.jpg, and has a supported image extension (case-insensitive)
        if item.is_file() and item.name.lower() != 'cover.jpg':
            ext = item.suffix.lower()
            if ext == '.jpg' or ext in SUPPORTED_IMAGE_EXTENSIONS:
                image_files.append(item)

    if not image_files:
        logging.info(f"No images (excluding cover.jpg) found to process in {show_dir_path}.")
        return True

    # Sort files to ensure consistent numbering (e.g., by name)
    image_files.sort()

    logging.info(f"Found {len(image_files)} images to potentially rename/convert.")
    success_count = 0
    fail_count = 0
    skipped_count = 0

    for index, old_path in enumerate(image_files):
        new_filename = f"{safe_show_name}-{index + 1}.jpg"
        new_path = show_dir_path / new_filename
        old_ext = old_path.suffix.lower()

        if old_path == new_path:
            logging.debug(f"Skipping '{old_path.name}', already correctly named and formatted.")
            skipped_count += 1
            success_count += 1 # Already correct counts as success
            continue

        logging.info(f"Processing '{old_path.name}' -> '{new_filename}'")

        try:
            if old_ext == '.jpg':
                # Just rename
                logging.debug(f"Renaming '{old_path.name}' to '{new_filename}'")
                old_path.rename(new_path)
                success_count += 1
            else:
                # Convert and save, then delete old
                logging.debug(f"Converting '{old_path.name}' ({old_ext}) to JPG: '{new_filename}'")
                with Image.open(old_path) as img:
                    # Convert to RGB if it has alpha channel (e.g., PNG) or is palette-based (e.g., GIF)
                    if img.mode in ('RGBA', 'LA', 'P'):
                        logging.debug(f"Converting image mode from {img.mode} to RGB.")
                        # Create a white background image
                        bg = Image.new("RGB", img.size, (255, 255, 255))
                        # Paste the image onto the background using the alpha channel as mask
                        try:
                           bg.paste(img, (0, 0), img.split()[-1] if img.mode in ('RGBA', 'LA') else None)
                           img_to_save = bg
                        except Exception as paste_err:
                           logging.warning(f"Error during alpha compositing for {old_path.name}, saving as plain RGB. Error: {paste_err}")
                           img_to_save = img.convert('RGB')

                    elif img.mode != 'RGB':
                         logging.debug(f"Converting image mode from {img.mode} to RGB.")
                         img_to_save = img.convert('RGB')
                    else:
                         img_to_save = img

                    img_to_save.save(new_path, "JPEG", quality=90) # Save as JPG with decent quality
                logging.info(f"Successfully converted and saved '{new_filename}'")
                # Delete original file after successful conversion
                try:
                    old_path.unlink()
                    logging.debug(f"Deleted original file: '{old_path.name}'")
                except OSError as del_err:
                    logging.warning(f"Could not delete original file '{old_path.name}' after conversion: {del_err}")
                success_count += 1

        except FileNotFoundError:
             logging.error(f"File not found during processing: {old_path}")
             fail_count += 1
        except UnidentifiedImageError:
             logging.error(f"Cannot identify image file (possibly corrupt or unsupported format): {old_path}")
             fail_count += 1
        except (IOError, OSError, Exception) as e:
            logging.error(f"Failed to process image {old_path.name}: {e}", exc_info=True)
            fail_count += 1
            # Attempt to clean up partially created new file if rename/save failed
            if new_path.exists() and old_path != new_path:
                try:
                    new_path.unlink()
                except OSError:
                    pass # Ignore cleanup error

    logging.info(f"Image processing summary for {show_dir_path.name}: "
                 f"Success={success_count}, Failed={fail_count}, Skipped/Already OK={skipped_count}")
    return fail_count == 0


# --- Main Execution ---

def main():
    parser = argparse.ArgumentParser(description="Manage TV show data (JSON fields and images).")
    subparsers = parser.add_subparsers(dest='command', required=True, help='Sub-command help')

    # --- JSON Sub-command ---
    parser_json = subparsers.add_parser('json', help='Modify init.json files.')
    parser_json.add_argument('--action', required=True, choices=['add', 'delete'], help='Action to perform on the JSON field.')
    parser_json.add_argument('--key', required=True, help='The JSON field key to modify.')
    parser_json.add_argument('--value', help='The value to set for the field (required for "add" action).')
    parser_json.add_argument('--exclude', action='store_true', help='Process all shows EXCEPT the ones specified.')
    parser_json.add_argument('show_names', nargs='*', help='Specific show names (folder names) to process. If empty, process all (unless --exclude is used).')

    # --- Rename Images Sub-command ---
    parser_rename = subparsers.add_parser('rename-images', help='Rename and convert images in show folders.')
    parser_rename.add_argument('--exclude', action='store_true', help='Process all shows EXCEPT the ones specified.')
    parser_rename.add_argument('show_names', nargs='*', help='Specific show names (folder names) to process. If empty, process all.')

    args = parser.parse_args()

    logging.info(f"Script started with command: {args.command}")

    # Validate arguments
    if args.command == 'json' and args.action == 'add' and args.value is None:
        parser.error("--value is required when action is 'add'")

    # Determine target shows
    target_shows = get_target_shows(TV_SHOWS_BASE_PATH, args.show_names, args.exclude)

    if not target_shows:
        logging.warning("No target show directories found or selected. Exiting.")
        sys.exit(0)

    logging.info(f"Found {len(target_shows)} target show directories to process.")

    overall_success = True
    processed_count = 0

    # Execute command
    if args.command == 'json':
        logging.info(f"Executing JSON command: action='{args.action}', key='{args.key}'" + (f", value='{args.value}'" if args.action == 'add' else ""))
        for show_dir in target_shows:
            if modify_json_field(show_dir, args.action, args.key, args.value):
                processed_count += 1
            else:
                overall_success = False
        logging.info(f"JSON modification attempted on {len(target_shows)} directories.")

    elif args.command == 'rename-images':
        logging.info("Executing Rename Images command...")
        print("\nWARNING: This operation will rename and potentially convert image files.")
        print("It's recommended to back up your assets/tv_shows directory before proceeding.")
        confirm = input("Do you want to continue? (y/n): ").lower()

        if confirm == 'y':
            logging.info("User confirmed image processing.")
            for show_dir in target_shows:
                 if rename_and_convert_images(show_dir):
                     processed_count += 1
                 else:
                     overall_success = False # Mark overall as failed if any show had image errors
            logging.info(f"Image renaming/conversion attempted on {len(target_shows)} directories.")
        else:
            logging.info("User cancelled image processing.")
            print("Operation cancelled.")
            sys.exit(0)


    logging.info("\n--- Script Summary ---")
    logging.info(f"Command executed: {args.command}")
    logging.info(f"Total target directories: {len(target_shows)}")
    logging.info(f"Directories processed successfully (may include skips): {processed_count}")
    logging.info(f"Overall success status: {'Success' if overall_success else 'Failed (check logs)'}")
    logging.info(f"Detailed logs available in: {LOG_FILE}")
    logging.info("Script finished.")

if __name__ == "__main__":
    main()