import os
import sys
import yaml
import argparse
import re
from pathlib import Path

def validate_okf(bundle_dir, strict=False):
    errors = []
    warnings = []
    
    bundle_path = Path(bundle_dir)
    if not bundle_path.exists():
        print(f"Error: Directory {bundle_dir} does not exist.")
        sys.exit(1)

    for root, dirs, files in os.walk(bundle_dir):
        for file in files:
            if not file.endswith(".md"):
                continue
                
            file_path = Path(root) / file
            rel_path = file_path.relative_to(bundle_path)
            
            with open(file_path, "r") as f:
                content = f.read()
                
            # Reserved files check
            if file == "index.md":
                if rel_path == Path("index.md"):
                    # Root index
                    try:
                        if content.startswith("---"):
                            fm_match = re.search(r"^---\n(.*?)\n---", content, re.DOTALL)
                            if fm_match:
                                fm = yaml.safe_load(fm_match.group(1))
                                if not all(k == "okf_version" for k in fm.keys()):
                                    warnings.append(f"{rel_path}: Root index frontmatter should only contain 'okf_version'")
                    except Exception as e:
                        errors.append(f"{rel_path}: Failed to parse frontmatter: {e}")
                else:
                    # Non-root index should not have frontmatter
                    if content.startswith("---"):
                        warnings.append(f"{rel_path}: Non-root index should not have frontmatter")
                continue

            if file == "log.md":
                if content.startswith("---"):
                    warnings.append(f"{rel_path}: log.md should not have frontmatter")
                # Check date headings
                dates = re.findall(r"^## (\d{4}-\d{2}-\d{2})", content, re.MULTILINE)
                if not dates and "##" in content:
                    warnings.append(f"{rel_path}: log.md headings should be ISO dates (YYYY-MM-DD)")
                continue

            # Concept files check
            if not content.startswith("---"):
                errors.append(f"{rel_path}: Missing YAML frontmatter")
                continue
                
            try:
                fm_match = re.search(r"^---\n(.*?)\n---", content, re.DOTALL)
                if not fm_match:
                    errors.append(f"{rel_path}: Malformed frontmatter block")
                    continue
                    
                fm = yaml.safe_load(fm_match.group(1))
                if not fm or "type" not in fm or not fm["type"]:
                    errors.append(f"{rel_path}: Missing or empty 'type' field in frontmatter")
                
                # Recommended fields
                for field in ["title", "description", "timestamp"]:
                    if field not in fm:
                        warnings.append(f"{rel_path}: Missing recommended field '{field}'")
                
            except Exception as e:
                errors.append(f"{rel_path}: Failed to parse frontmatter: {e}")

    # Print results
    if errors:
        print("\nERRORS:")
        for e in errors:
            print(f"  [!] {e}")
    
    if warnings:
        print("\nWARNINGS:")
        for w in warnings:
            print(f"  [-] {w}")
            
    if not errors and not warnings:
        print("\nBundle is valid!")
    elif not errors:
        print("\nBundle is valid (with warnings).")
    
    if errors or (strict and warnings):
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OKF Validation Tool")
    parser.add_argument("directory", help="Path to the OKF bundle directory")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as errors")
    args = parser.parse_args()
    
    validate_okf(args.directory, args.strict)
