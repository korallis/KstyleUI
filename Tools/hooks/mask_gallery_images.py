"""Mask committed gallery image payloads in added diff lines before scanning them."""

import re
import subprocess
import sys
from html.parser import HTMLParser

GALLERIES = {b'docs/renders/index.html', b'docs/renders/phone.html'}
ATTRIBUTE = re.compile(r'''([^\s"'<>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''')
IMAGE = re.compile(r'data:image/png;base64,[a-zA-Z0-9+/=]+\Z')
HUNK = re.compile(rb'\+(\d+)')


def lf_lines(text):
    pieces = text.split('\n')
    return [piece + '\n' for piece in pieces[:-1]] + ([pieces[-1]] if pieces[-1] else [])


class Images(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=False)
        self.text = text
        self.lines = lf_lines(text)
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
        return lf_lines(text)


def gallery(path):
    result = subprocess.run(['git', 'show', 'HEAD:' + path.decode('ascii')], capture_output=True, check=True)
    text = result.stdout.decode('utf-8')
    return ([line.encode('utf-8') for line in lf_lines(text)],
            [line.encode('utf-8') for line in Images(text).masked_lines()])


def main():
    cache = {}
    path = None
    line = 0
    for row in sys.stdin.buffer:
        if row.startswith(b'+++ b/'):
            path = row[6:].rstrip(b'\n')
        elif row.startswith(b'@@'):
            match = HUNK.search(row)
            if match:
                line = int(match.group(1)) - 1
        elif row.startswith(b'+') and not row.startswith(b'+++ '):
            line += 1
            if path in GALLERIES:
                if path not in cache:
                    cache[path] = gallery(path)
                original, masked = cache[path]
                if line <= len(original):
                    source = original[line - 1]
                    if not source.endswith(b'\n'):
                        source += b'\n'
                    if row[1:] == source:
                        replacement = masked[line - 1]
                        row = b'+' + replacement + (b'' if replacement.endswith(b'\n') else b'\n')
        sys.stdout.buffer.write(row)


if __name__ == '__main__':
    main()
