"""Discord release and roadmap formatting and webhook operations, without network access."""

import contextlib
import datetime
import io
import json
import re
import unittest
from unittest.mock import patch

from Tools.release import discord_post as discord

HEAD = '# Roadmap\n\nIntro.\n\n'
SECTION = '## v1.0.0 — first\n\nEstimated: soon.\n\nSummary.\n\nHighlights:\n\n- One\n- Two\n\n'
LATER = '## Later\n\n- Maybe\n\nBye.\n'


class RoadmapTests(unittest.TestCase):
    text = (discord.ROOT / 'docs/ROADMAP.md').read_text(encoding='utf-8')

    def test_roadmap_is_one_branded_message_within_discord_limits(self):
        payload = discord.roadmap_payload(self.text, '2026-11-20')
        embeds = payload['embeds']
        releases = re.findall(r'^## (v[\d.]+ — .+)$', self.text, re.M)
        self.assertTrue(releases)
        self.assertEqual([e['title'] for e in embeds], ['KstyleUI ' + name for name in releases] + ['Later'])
        self.assertLessEqual(len(embeds), 10)
        self.assertLessEqual(discord.character_totals(payload)['total'], 6000)
        self.assertEqual((payload['flags'], payload['allowed_mentions']), (4096, {'parse': []}))
        logo = f'{discord.RAW}/main/Media/Logo/Logo256.png'
        for embed in embeds:
            self.assertEqual(embed['color'], int('d3b574', 16))
            self.assertEqual(embed['author'], {'name': 'KstyleUI roadmap', 'url': discord.GITHUB, 'icon_url': logo})
            self.assertNotIn('url', embed, 'Discord merges embeds that share a URL')
            self.assertLessEqual(discord.characters(embed['description']), 4096)
        intro = self.text.split('\n\n')[1]
        first = embeds[0]['description']
        self.assertTrue(first.startswith(intro + '\n\n**Estimated:** '), first)
        for description in [first.removeprefix(intro + '\n\n')] + [e['description'] for e in embeds[1:-1]]:
            self.assertRegex(description, r'^\*\*Estimated:\*\* .+\n\n.+\n\n\*\*Highlights\*\*\n(- .+\n)*- .+$')
        self.assertEqual([('image' in e, 'footer' in e) for e in embeds], [(False, False)] * len(releases) + [(True, True)])
        self.assertEqual(embeds[-1]['image']['url'], f'{discord.RAW}/main/docs/media/marketing/banner.jpg')
        self.assertTrue((discord.ROOT / 'docs/media/marketing/banner.jpg').is_file())
        self.assertEqual(embeds[-1]['footer']['text'], 'KstyleUI for WoW Forever · Roadmap · 2026-11-20')
        self.assertTrue(embeds[-1]['description'].endswith('\n\n' + self.text.strip().splitlines()[-1]))

    def test_roadmap_highlights_are_short_and_whole(self):
        for line in re.findall(r'^- (.+)$', self.text, re.M):
            self.assertLessEqual(discord.characters(line), 120, 'shorten this roadmap highlight: ' + line)
            self.assertNotIn('…', line)
        discord.roadmap_payload(HEAD + SECTION.replace('- One', '- ' + 'x' * 120) + LATER, 'D')
        for line in ('x' * 121, 'A cut-off highlight…', 'Wait...'):
            for text in (HEAD + SECTION.replace('- One', '- ' + line) + LATER, HEAD + SECTION + LATER.replace('Maybe', line)):
                with self.assertRaisesRegex(ValueError, '120 characters or fewer, without an ellipsis'):
                    discord.roadmap_payload(text, 'D')

    def test_roadmap_sections_parse_or_fail_loudly(self):
        embeds = discord.roadmap_payload(HEAD + SECTION + LATER, 'D')['embeds']
        self.assertEqual([(e['title'], e['description']) for e in embeds], [
            ('KstyleUI v1.0.0 — first', 'Intro.\n\n**Estimated:** soon.\n\nSummary.\n\n**Highlights**\n- One\n- Two'),
            ('Later', '- Maybe\n\nBye.')])
        self.assertEqual(discord.roadmap_payload(HEAD + LATER, 'D')['embeds'][0]['description'], 'Intro.\n\n- Maybe\n\nBye.')
        for text in (HEAD + SECTION.replace('Estimated: ', 'ETA: ') + LATER, HEAD + SECTION.replace('Highlights:\n\n', '') + LATER,
                     HEAD + SECTION + LATER.replace('Later', 'Someday'), HEAD + SECTION, HEAD, SECTION + LATER,
                     HEAD + SECTION.replace('v1.0.0', 'v...') + LATER, HEAD + SECTION.replace('v1.0.0', 'v1.0') + LATER,
                     HEAD + SECTION + LATER.replace('\n\nBye.', '\n- Bye.'), HEAD + SECTION + LATER.replace('Bye.', '- Bye.')):
            with self.assertRaisesRegex(ValueError, 'Unexpected roadmap section'):
                discord.roadmap_payload(text, 'D')

    def test_each_discord_limit_fails_on_its_own(self):
        self.assertEqual(len(discord.roadmap_payload(HEAD + SECTION * 9 + LATER, 'D')['embeds']), 10)
        first = discord.roadmap_payload(HEAD + SECTION + LATER, 'D')['embeds'][0]
        for name, text in {'11 embeds': HEAD + SECTION * 10 + LATER,
                           'total over 6000': HEAD + SECTION.replace('Summary.', 'x' * 3000) * 2 + LATER,
                           '4097-character description': HEAD + SECTION.replace('Summary.', 'x' * (4105 - len(first['description']))) + LATER,
                           '257-character title': HEAD + SECTION.replace('first', 'x' * (262 - len(first['title']))) + LATER,
                           '257-character author': HEAD.replace('Roadmap', 'A' * 257) + SECTION + LATER}.items():
            with self.subTest(name), self.assertRaisesRegex(ValueError, 'Discord message limits'):
                discord.roadmap_payload(text, 'D')

    @patch('Tools.release.discord_post.urllib.request.urlopen')
    def test_roadmap_posts_edits_in_place_and_dry_runs(self, opener):
        expected = discord.roadmap_payload(self.text, datetime.date.today().isoformat())
        with patch.dict('os.environ', {'DISCORD_RELEASE_WEBHOOK': 'https://discord.com/api/webhooks/1/token'}):
            for argv in (['--roadmap'], ['--roadmap', '--edit', '123']):
                opener.reset_mock()
                with patch('sys.argv', ['discord_post.py'] + argv):
                    discord.main()
                request = opener.call_args.args[0]
                self.assertEqual(opener.call_count, 1)
                if '--edit' in argv:
                    self.assertEqual((request.method, request.full_url), ('PATCH', 'https://discord.com/api/webhooks/1/token/messages/123'))
                    self.assertEqual(json.loads(request.data), dict(expected, content='', flags=0))
                else:
                    self.assertEqual((request.method, json.loads(request.data)), ('POST', expected))
            opener.reset_mock()
            with patch('sys.argv', ['discord_post.py', '--roadmap', '--edit', '123', '--dry-run']), contextlib.redirect_stdout(io.StringIO()) as output:
                discord.main()
            self.assertEqual(json.loads(output.getvalue().split('Character totals: ')[0]), json.loads(request.data))
            for argv in (['--roadmap', 'v0.2.8', '123'], ['--roadmap', '--notes'], ['--roadmap', '123'], ['--edit', '--dry-run'],
                         ['--roadmap', '--edit', '123,456']):
                with patch('sys.argv', ['discord_post.py'] + argv), contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit, msg=argv):
                        discord.main()
        opener.assert_not_called()


class DiscordPostTests(unittest.TestCase):
    def payload(self, tag):
        return discord.release_payload((discord.ROOT / 'CHANGELOG.md').read_text(encoding='utf-8'), tag,
                                       (discord.ROOT / 'docs/RELEASE_NOTES.md').read_text(encoding='utf-8'),
                                       (discord.ROOT / 'README.md').read_text(encoding='utf-8'))

    def assert_valid(self, payload):
        self.assertEqual(len(payload['embeds']), 1)
        self.assertEqual(payload.get('content', ''), '')
        self.assertEqual(payload['allowed_mentions'], {'parse': []})
        self.assertIn(payload['flags'], (0, 4096))
        self.assertFalse(payload['flags'] & 4)
        embed = payload['embeds'][0]
        self.assertLessEqual(len(embed['title']), 256)
        self.assertLessEqual(len(embed['description']), 4096)
        self.assertLessEqual(discord.character_totals(payload)['total'], 6000)
        for field in embed['fields']:
            self.assertLessEqual(discord.characters(field['value']), 1024)
        return embed

    def test_real_releases_limits_counts_branding_and_links(self):
        for tag, counts in [('v0.2.8', '15 added · 2 changed · 11 fixed'),
                            ('v0.2.8.1', '2 fixed')]:
            with self.subTest(tag=tag):
                embed = self.assert_valid(self.payload(tag))
                url = f'{discord.GITHUB}/releases/tag/{tag}'
                self.assertEqual(embed['url'], url)
                self.assertIn(counts, embed['description'])
                self.assertNotRegex(embed['description'], r'\b0 (added|changed|fixed)\b')
                self.assertEqual(embed['color'], int('d3b574', 16))
                logo = f'{discord.RAW}/{tag}/Media/Logo/Logo256.png'
                self.assertEqual(embed['author'], {'name': 'KstyleUI', 'url': discord.GITHUB, 'icon_url': logo})
                self.assertNotIn('thumbnail', embed)
                self.assertEqual(embed['image']['url'], f'{discord.RAW}/{tag}/docs/media/marketing/banner.jpg')
                fields = {f['name']: f['value'] for f in embed['fields']}
                self.assertEqual(fields['Download'], '[CurseForge](https://www.curseforge.com/wow/addons/kstyleui) · '
                                 f'[Wago](https://addons.wago.io/addons/kstyleui) · [GitHub]({url})')
                self.assertEqual(fields['Full notes'], f'[Read the release notes]({url})')
                self.assertEqual(embed['footer']['text'], 'KstyleUI for WoW Forever · 2026-11-20')
                self.assertEqual('Upgrading' in fields, tag == 'v0.2.8')
        self.assertEqual(self.payload('v0.2.8')['embeds'][0]['title'],
                         'KstyleUI v0.2.8 — the map and bars release')
        self.assertEqual(self.payload('v0.2.8.1')['embeds'][0]['title'], 'KstyleUI v0.2.8.1 — fixes')
        self.assertIn('Options pages switch', self.payload('v0.2.8.1')['embeds'][0]['description'])

    def test_only_requested_section_and_fallback_highlights(self):
        text = ('## v2.0.0 (2026-11-20)\n\nNewer\n\n### Added\n\n- Unrelated\n'
                '## v1.2.3 (2026-11-18)\n\nSummary.\n\n### Added\n\n- One. More detail.\n'
                '\n### Changed\n\n- Two\n\n### Fixed\n\n- Three\n\n## How to install\nInstructions')
        embed = self.assert_valid(discord.release_payload(text, 'v1.2.3'))
        self.assertEqual(embed['description'], 'Summary.\n\n**Highlights**\n- One.\n- Three\n\n1 added · 1 changed · 1 fixed')
        self.assertNotIn('image', embed)
        with self.assertRaisesRegex(ValueError, 'Missing release section'):
            discord.release_payload(text, 'v1.2.30')

    def test_empty_counts_are_omitted(self):
        payload = discord.release_payload('## v1.2.3 (2026-11-18)\n\nSummary.\n\nHighlights:\n\n- News.', 'v1.2.3')
        self.assertEqual(payload['embeds'][0]['description'], 'Summary.\n\n**Highlights**\n- News.')

    def test_large_inputs_remain_within_limits(self):
        text = ('## v1.2.3 (2026-11-18)\n\n' + '\U0001f600 ' * 3000 + '\n\nHighlights:\n\n'
                + '- ' + 'long highlight ' * 1000 + '\n- other\n' * 10
                + '\n### Fixed\n\n- Fix\n\n### Upgrading\n\n' + '- ' + '\U0001f600 ' * 100 + '\n- step\n' * 100)
        notes = '## 1.2.3: ' + '\U0001f600 ' * 3000
        embed = self.assert_valid(discord.release_payload(text, 'v1.2.3', notes))
        highlights = embed['description'].split('**Highlights**\n')[1].split('\n\n')[0].splitlines()
        self.assertEqual(len(highlights), 6)
        self.assertTrue(all(len(line) <= 122 for line in highlights))

    def test_oversized_link_fails_instead_of_sending_an_invalid_field(self):
        tag = 'v' + '1' * 1000
        with self.assertRaisesRegex(ValueError, 'Discord embed limits'):
            discord.release_payload('## ' + tag + ' (2026-11-18)\n\nSummary.\n\n### Fixed\n\n- Fix.', tag)

    def test_shortening_preserves_whole_markdown_and_words(self):
        atoms = ['**a bold phrase**', '`/kstyle setup`', '[a link](https://example.com/a_(b))',
                 '*an italic phrase*', '__underlined phrase__', '~~a removed phrase~~', '("**bold words**")']
        for atom in atoms:
            for limit in range(2, len(atom) + 25):
                result = discord.shorten('Read ' + atom + ' and keep going for a while', limit)
                self.assertLessEqual(len(result), limit)
                self.assertTrue(atom in result or not any(c in result for c in '*`[~_'), result)
        self.assertEqual(discord.shorten('First sentence. Second sentence.'), 'First sentence.')
        self.assertEqual(discord.shorten('Use **this setting.** More detail.'), 'Use **this setting.**')
        self.assertEqual(discord.shorten('word ' * 100), 'word ' * 23 + 'word…')

    @patch('Tools.release.discord_post.urllib.request.urlopen')
    def test_post_is_one_request(self, opener):
        payload = self.payload('v0.2.8')
        discord.send('https://discord.com/api/webhooks/1/token', payload)
        request = opener.call_args.args[0]
        self.assertEqual(request.method, 'POST')
        self.assertEqual(request.get_header('User-agent'), 'KstyleUI-release')
        self.assertEqual(json.loads(request.data), payload)
        self.assertEqual(opener.call_count, 1)
        self.assertEqual(json.loads(request.data)['flags'], 4096)

    @patch('Tools.release.discord_post.urllib.request.urlopen')
    def test_edit_first_then_delete_only_the_remaining_webhook_messages(self, opener):
        payload = self.payload('v0.2.8')
        discord.send('https://discord.com/api/webhooks/1/token?thread_id=9', payload, '123,456,789')
        requests = [call.args[0] for call in opener.call_args_list]
        self.assertEqual([r.method for r in requests], ['PATCH', 'DELETE', 'DELETE'])
        for request in requests:
            self.assertEqual(request.get_header('User-agent'), 'KstyleUI-release', request.method)
        self.assertEqual([r.full_url for r in requests],
                         [f'https://discord.com/api/webhooks/1/token/messages/{mid}?thread_id=9'
                          for mid in ('123', '456', '789')])
        self.assertEqual(json.loads(requests[0].data), payload)

    @patch('Tools.release.discord_post.urllib.request.urlopen')
    def test_failed_edit_never_deletes_and_bad_ids_never_send(self, opener):
        opener.side_effect = OSError('not owned by this webhook')
        with self.assertRaises(OSError):
            discord.send('https://discord.com/api/webhooks/1/token', {}, '123,456')
        self.assertEqual(opener.call_count, 1)
        opener.reset_mock()
        for ids in ('123,123', '123,', '../456', '123, 456'):
            with self.assertRaises(ValueError):
                discord.send('https://discord.com/api/webhooks/1/token', {}, ids)
        opener.assert_not_called()

    @patch('Tools.release.discord_post.urllib.request.urlopen')
    def test_dry_run_prints_payload_and_totals_without_sending(self, opener):
        with patch('sys.argv', ['discord_post.py', '--edit', 'v0.2.8.1', '123,456', '--dry-run']):
            with contextlib.redirect_stdout(io.StringIO()) as output:
                discord.main()
        payload, totals = output.getvalue().split('Character totals: ')
        self.assertEqual((json.loads(payload)['flags'], json.loads(payload)['content']), (0, ''))
        self.assert_valid(json.loads(payload))
        self.assertEqual(json.loads(totals), discord.character_totals(json.loads(payload)))
        opener.assert_not_called()


if __name__ == '__main__':
    unittest.main()
