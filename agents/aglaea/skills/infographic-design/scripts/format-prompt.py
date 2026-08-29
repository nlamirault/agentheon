#!/usr/bin/env python3
"""
format-prompt.py - Formats infographic prompts for Gemini API usage

Usage: format-prompt.py <input-file> [--output <output-file>] [--api-format]

Modes:
  Default: Pretty-prints and validates the prompt
  --api-format: Formats for direct API usage (single line, escaped)

Options:
  --output FILE: Write formatted prompt to file instead of stdout
  --minify: Removes extra whitespace for token efficiency
  --validate: Run validation checks before formatting
  --stats: Show prompt statistics (word count, character count)
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class PromptFormatter:
    """Format and optimize prompts for AI generation."""

    def __init__(self, prompt_text: str):
        self.prompt_text = prompt_text
        self.word_count = len(prompt_text.split())
        self.char_count = len(prompt_text)
        self.line_count = len(prompt_text.splitlines())

    def validate(self) -> Tuple[bool, List[str]]:
        """Validate prompt has required sections."""
        required_sections = [
            "Topic",
            "Audience",
            "Visual Style",
            "Layout",
            "Dimensions",
        ]
        missing = []

        for section in required_sections:
            pattern = rf"^{re.escape(section)}:"
            if not re.search(pattern, self.prompt_text, re.MULTILINE | re.IGNORECASE):
                missing.append(section)

        is_valid = len(missing) == 0
        return is_valid, missing

    def format_for_api(self) -> str:
        """Format prompt for API usage (escaped, single-line)."""
        # Remove excessive whitespace
        formatted = re.sub(r'\n{3,}', '\n\n', self.prompt_text)

        # Escape special characters for JSON
        escaped = json.dumps(formatted)

        return escaped

    def minify(self) -> str:
        """Remove unnecessary whitespace for token efficiency."""
        # Remove leading/trailing whitespace from each line
        lines = [line.strip() for line in self.prompt_text.splitlines()]

        # Remove empty lines
        lines = [line for line in lines if line]

        # Join with single newline
        minified = '\n'.join(lines)

        return minified

    def pretty_print(self) -> str:
        """Format for human readability."""
        # Ensure consistent line breaks
        formatted = re.sub(r'\n{3,}', '\n\n', self.prompt_text)

        # Add spacing around section headers
        formatted = re.sub(
            r'^([A-Z][a-z]+(?: [A-Z][a-z]+)*:)',
            r'\n\1',
            formatted,
            flags=re.MULTILINE
        )

        return formatted.strip()

    def get_statistics(self) -> Dict[str, int]:
        """Get prompt statistics."""
        return {
            'words': self.word_count,
            'characters': self.char_count,
            'lines': self.line_count,
            'sections': len(re.findall(r'^[A-Z][a-zA-Z ]+:', self.prompt_text, re.MULTILINE)),
        }

    def extract_colors(self) -> List[str]:
        """Extract hex color codes from prompt."""
        colors = re.findall(r'#[0-9A-Fa-f]{6}', self.prompt_text)
        return list(set(colors))  # Remove duplicates

    def extract_dimensions(self) -> Optional[str]:
        """Extract dimensions specification."""
        match = re.search(r'(\d+)\s*x\s*(\d+)', self.prompt_text, re.IGNORECASE)
        if match:
            width, height = match.groups()
            return f"{width}x{height}"
        return None


def print_validation_errors(missing_sections: List[str]) -> None:
    """Print validation errors in a user-friendly format."""
    print("❌ Validation Failed", file=sys.stderr)
    print("\nMissing required sections:", file=sys.stderr)
    for section in missing_sections:
        print(f"  - {section}", file=sys.stderr)
    print("\nPlease add these sections to your prompt.", file=sys.stderr)


def print_statistics(formatter: PromptFormatter) -> None:
    """Print prompt statistics."""
    stats = formatter.get_statistics()
    colors = formatter.extract_colors()
    dimensions = formatter.extract_dimensions()

    print("📊 Prompt Statistics", file=sys.stderr)
    print(f"  Words:      {stats['words']}", file=sys.stderr)
    print(f"  Characters: {stats['characters']}", file=sys.stderr)
    print(f"  Lines:      {stats['lines']}", file=sys.stderr)
    print(f"  Sections:   {stats['sections']}", file=sys.stderr)

    if colors:
        print(f"\n🎨 Colors found: {len(colors)}", file=sys.stderr)
        for color in colors:
            print(f"  - {color}", file=sys.stderr)

    if dimensions:
        print(f"\n📐 Dimensions: {dimensions}", file=sys.stderr)

    print(file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Format infographic prompts for Gemini API",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "input_file",
        type=Path,
        help="Input prompt file"
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        help="Output file (default: stdout)"
    )
    parser.add_argument(
        "--api-format",
        action="store_true",
        help="Format for API usage (escaped JSON string)"
    )
    parser.add_argument(
        "--minify",
        action="store_true",
        help="Remove extra whitespace for token efficiency"
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        help="Validate prompt before formatting"
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Show prompt statistics"
    )

    args = parser.parse_args()

    # Read input file
    try:
        prompt_text = args.input_file.read_text()
    except FileNotFoundError:
        print(f"❌ Error: File '{args.input_file}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error reading file: {e}", file=sys.stderr)
        sys.exit(1)

    # Create formatter
    formatter = PromptFormatter(prompt_text)

    # Validate if requested
    if args.validate:
        is_valid, missing = formatter.validate()
        if not is_valid:
            print_validation_errors(missing)
            sys.exit(2)
        print("✅ Validation passed", file=sys.stderr)
        print(file=sys.stderr)

    # Show statistics if requested
    if args.stats:
        print_statistics(formatter)

    # Format prompt based on mode
    if args.api_format:
        formatted = formatter.format_for_api()
    elif args.minify:
        formatted = formatter.minify()
    else:
        formatted = formatter.pretty_print()

    # Write output
    if args.output:
        try:
            args.output.write_text(formatted)
            print(f"✅ Formatted prompt written to {args.output}", file=sys.stderr)
        except Exception as e:
            print(f"❌ Error writing file: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(formatted)


if __name__ == "__main__":
    main()
