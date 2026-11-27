"""Mask committed gallery image payloads in added diff lines before scanning them."""

import re
import subprocess
import sys
from html.parser import HTMLParser

GALLERIES = {'docs/renders/index.html', 'docs/renders/phone.html'}
ATTRIBUTE = re.compile(r'''([^\s"'<>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''')
IMAGE = re.compile(r'data:image/png;base64,[a-zA-Z0-9+/=]+\Z')
HUNK = re.compile(r'\+(\d+)')


class Images(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=False)
        self.text = text
        self.lines = text.splitlines(keepends=True)
        self.offsets = []
        offset = 0
        for line in self.lines:
            self.offsets.append(offset)
            offset += len(line)
        self.spans = []

    def handle_starttag(self, tag, attrs):
        if tag != 'img':
            return
        line, column = self.getpos()
        start = self.offsets[line - 1] + column
        raw = self.get_starttag_text()
        for attribute in ATTRIBUTE.finditer(raw, len('<img')):
            if attribute.group(1).lower() == 'src':
                if attribute.group(2) and IMAGE.fullmatch(attribute.group(2)):
                    self.spans.append((start + attribute.start(2), start + attribute.end(2)))
                break

    handle_startendtag = handle_starttag

    def masked_lines(self):
        self.feed(self.text)
        text = self.text
        for start, end in reversed(self.spans):
            text = text[:start] + '[image]' + text[end:]
        return text.splitlines(keepends=True)


def gallery(path):
    result = subprocess.run(['git', 'show', 'HEAD:' + path], capture_output=True, check=True)
    text = result.stdout.decode('utf-8')
    return text.splitlines(keepends=True), Images(text).masked_lines()


def main():
    cache = {}
    path = None
    line = 0
    for row in sys.stdin:
        if row.startswith('+++ b/'):
            path = row[6:].rstrip('\n')
        elif row.startswith('@@'):
            match = HUNK.search(row)
            if match:
                line = int(match.group(1)) - 1
        elif row.startswith('+') and not row.startswith('+++ '):
            line += 1
            if path in GALLERIES:
                if path not in cache:
                    cache[path] = gallery(path)
                original, masked = cache[path]
                if line <= len(original):
                    source = original[line - 1]
                    if not source.endswith('\n'):
                        source += '\n'
                    if row[1:] == source:
                        replacement = masked[line - 1]
                        row = '+' + replacement + ('' if replacement.endswith('\n') else '\n')
        sys.stdout.write(row)


if __name__ == '__main__':
    main()
