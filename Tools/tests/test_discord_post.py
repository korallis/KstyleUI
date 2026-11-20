"""Discord release formatting and webhook operations, without network access."""

import contextlib
import io
import json
import unittest
from unittest.mock import patch

from Tools.release import discord_post as discord


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
                self.assertEqual(embed['color'], int('d3b574', 16))
                logo = f'{discord.RAW}/{tag}/Media/Logo/Logo256.png'
                self.assertEqual(embed['author'], {'name': 'KstyleUI', 'url': discord.GITHUB, 'icon_url': logo})
                self.assertEqual(embed['thumbnail']['url'], logo)
                self.assertEqual(embed['image']['url'], f'{discord.RAW}/{tag}/docs/media/marketing/banner.jpg')
                fields = {f['name']: f['value'] for f in embed['fields']}
                self.assertEqual(fields['Download'], '[CurseForge](https://www.curseforge.com/wow/addons/kstyleui) · '
                                 f'[Wago](https://addons.wago.io/addons/kstyleui) · [GitHub]({url})')
                self.assertEqual(fields['Full notes'], f'[Read the release notes]({url})')
                self.assertEqual(embed['footer']['text'], 'KstyleUI for WoW Forever · 2026-11-20')
                self.assertEqual('Upgrading' in fields, tag == 'v0.2.8')
        self.assertEqual(self.payload('v0.2.8')['embeds'][0]['title'],
                         'KstyleUI v0.2.8 — the map and bars release')
        self.assertEqual(self.payload('v0.2.8.1')['embeds'][0]['title'], 'KstyleUI v0.2.8.1')
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
        self.assertEqual(json.loads(request.data), payload)
        self.assertEqual(opener.call_count, 1)
        self.assertEqual(json.loads(request.data)['flags'], 4096)

    @patch('Tools.release.discord_post.urllib.request.urlopen')
    def test_edit_first_then_delete_only_the_remaining_webhook_messages(self, opener):
        payload = self.payload('v0.2.8')
        discord.send('https://discord.com/api/webhooks/1/token?thread_id=9', payload, '123,456,789')
        requests = [call.args[0] for call in opener.call_args_list]
        self.assertEqual([r.method for r in requests], ['PATCH', 'DELETE', 'DELETE'])
        self.assertEqual([r.full_url for r in requests],
                         [f'https://discord.com/api/webhooks/1/token/messages/{mid}?thread_id=9'
                          for mid in ('123', '456', '789')])
        self.assertEqual(json.loads(requests[0].data), dict(payload, content="", flags=0))

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
        self.assertEqual(json.loads(payload)['flags'], 0)
        self.assert_valid(json.loads(payload))
        self.assertEqual(json.loads(totals), discord.character_totals(json.loads(payload)))
        opener.assert_not_called()


if __name__ == '__main__':
    unittest.main()
