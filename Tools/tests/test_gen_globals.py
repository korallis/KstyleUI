"""Tests for Tools/build/gen_globals.py."""

import contextlib
import io
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "Tools" / "build"))

import gen_globals  # noqa: E402

ADDONS = Path("Interface") / "AddOns"
DOCS = ADDONS / "Blizzard_APIDocumentationGenerated"


def doc_table(name, kind, functions, namespace=None, environment="All", function_environments=None):
    """Return the text of one generated documentation file, in Blizzard's layout."""
    function_environments = function_environments or {}
    entries = ""
    for fn in functions:
        env = function_environments.get(fn)
        env_line = f'\t\t\tEnvironment = "{env}",\n' if env else ""
        entries += (
            f'\t\t{{\n\t\t\tName = "{fn}",\n\t\t\tType = "Function",\n{env_line}\n'
            f'\t\t\tArguments =\n\t\t\t{{\n\t\t\t\t{{ Name = "value", Type = "number", Nilable = false }},\n\t\t\t}},\n'
            "\t\t},\n"
        )
    namespace_line = f'\tNamespace = "{namespace}",\n' if namespace else ""
    return (
        f'local {name} =\n{{\n\tName = "{name}",\n\tType = "{kind}",\n{namespace_line}'
        f'\tEnvironment = "{environment}",\n\n'
        f"\tFunctions =\n\t{{\n{entries}\t}},\n\n\tEvents =\n\t{{\n\t}},\n\n\tTables =\n\t{{\n\t}},\n}};\n\n"
        f"APIDocumentation:AddDocumentationTable({name});\n"
    )


ENUM_DOC = textwrap.dedent(
    """\
    local SpellBookConstants =
    {
    \tTables =
    \t{
    \t\t{
    \t\t\tName = "SpellBookSpellBank",
    \t\t\tType = "Enumeration",
    \t\t\tFields =
    \t\t\t{
    \t\t\t\t{ Name = "Player", Type = "SpellBookSpellBank", EnumValue = 0 },
    \t\t\t},
    \t\t},
    \t\t{
    \t\t\tName = "SpellBookSpellIDs",
    \t\t\tType = "Constants",
    \t\t\tValues =
    \t\t\t{
    \t\t\t\t{ Name = "SPELL_ID_DISMISS_PET", Type = "number", Value = 2641 },
    \t\t\t},
    \t\t},
    \t},
    };

    APIDocumentation:AddDocumentationTable(SpellBookConstants);
    """
)


class GenGlobalsTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.source = Path(self._tmp.name) / "wow-ui-source"
        (self.source / DOCS).mkdir(parents=True)
        self.out = Path(self._tmp.name) / "forever_globals.lua"

    def tearDown(self):
        self._tmp.cleanup()

    # Helpers

    def write(self, rel, text):
        path = self.source / ADDONS / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(textwrap.dedent(text), encoding="utf-8")

    def write_doc(self, file, *args, **kwargs):
        (self.source / DOCS / file).write_text(doc_table(*args, **kwargs), encoding="utf-8")

    def addon(self, name, toc, files=None):
        """Write <name>/<name>.toc and each file in files (relative to the addon folder)."""
        self.write(f"{name}/{name}.toc", toc)
        for rel, text in (files or {}).items():
            self.write(f"{name}/{rel}", text)

    def collect(self):
        return gen_globals.collect(self.source)

    def read(self):
        return set(self.collect().read)

    def deprecated(self):
        return set(self.collect().deprecated)

    def commit_source(self, subject):
        git = ["git", "-C", str(self.source), "-c", "user.name=t", "-c", "user.email=t@example.com"]
        subprocess.run(git + ["init", "-q"], check=True)
        subprocess.run(git + ["add", "-A"], check=True)
        subprocess.run(git + ["commit", "-q", "-m", subject], check=True)
        return subprocess.run(
            git + ["log", "-1", "--format=%h"], check=True, capture_output=True, text=True
        ).stdout.strip()

    def generate(self):
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr), contextlib.redirect_stdout(io.StringIO()):
            code = gen_globals.main(["--source", str(self.source), "--out", str(self.out)])
        return code, stderr.getvalue()

    # The plan's contract

    def test_reads_api_namespace(self):
        self.write_doc("SecretsDocumentation.lua", "Secrets", "System", ["ShouldAurasBeSecret"], namespace="C_Secrets")
        read = self.read()
        self.assertIn("C_Secrets", read)
        self.assertNotIn("ShouldAurasBeSecret", read)

    def test_reads_global_api_functions(self):
        self.write_doc("UnitDocumentation.lua", "Unit", "System", ["UnitHealthPercent", "UnitHealth"])
        self.assertLessEqual({"UnitHealthPercent", "UnitHealth"}, self.read())

    def test_reads_framexml_function(self):
        self.addon(
            "Blizzard_SharedXMLBase",
            "## Title: Base\nPixelUtil.lua\n",
            {"PixelUtil.lua": "PixelUtil = {};\n\nfunction PixelUtil.GetPixelToUIUnitFactor()\nend\n\nfunction Round(value)\n\treturn value;\nend\n"},
        )
        self.assertLessEqual({"PixelUtil", "Round"}, self.read())

    def test_excludes_deprecated(self):
        self.addon(
            "Blizzard_DeprecatedSpellBook",
            "## Title: Deprecated\nDeprecated_SpellBook.lua\n",
            {
                "Deprecated_SpellBook.lua": """\
                    if not GetCVarBool("loadDeprecationFallbacks") then
                    \treturn;
                    end

                    do
                    \tfunction IsPlayerSpell(spellID)
                    \t\treturn C_SpellBook.IsSpellKnown(spellID);
                    \tend

                    \tGetSchoolString = C_Spell.GetSchoolString;
                    end
                    """
            },
        )
        collected = self.collect()
        self.assertLessEqual({"IsPlayerSpell", "GetSchoolString"}, set(collected.deprecated))
        self.assertNotIn("IsPlayerSpell", collected.read)
        self.assertNotIn("GetSchoolString", collected.read)

    def test_output_is_sorted_lua(self):
        self.write_doc("UnitDocumentation.lua", "Unit", "System", ["UnitHealth", "AbbreviateNumbers"])
        self.write_doc("SpellDocumentation.lua", "Spell", "System", ["GetSpellName"], namespace="C_Spell")
        self.addon(
            "Blizzard_DeprecatedSpellBook",
            "## Title: Deprecated\nDeprecated_SpellBook.lua\n",
            {"Deprecated_SpellBook.lua": "function IsSpellKnown()\nend\nfunction IsPlayerSpell()\nend\n"},
        )
        commit = self.commit_source("1.60.1 (70840)")
        code, err = self.generate()
        self.assertEqual(code, 0, err)
        lines = self.out.read_text(encoding="utf-8").splitlines()
        self.assertTrue(lines[0].startswith("-- forever_globals.lua: "), lines[0])
        self.assertIn(f"{commit} 1.60.1 (70840)", lines[0])
        self.assertEqual(
            lines[1:],
            [
                "return {",
                "\tread = {",
                '\t\t"AbbreviateNumbers",',
                '\t\t"C_Spell",',
                '\t\t"UnitHealth",',
                "\t},",
                "\tdeprecated = {",
                '\t\t"IsPlayerSpell",',
                '\t\t"IsSpellKnown",',
                "\t},",
                "}",
            ],
        )

    # API documentation

    def test_skips_widget_methods(self):
        self.write_doc("SimpleFrameAPIDocumentation.lua", "SimpleFrameAPI", "ScriptObject", ["SetScript", "Show"])
        self.assertFalse({"SetScript", "Show"} & self.read())

    def test_skips_secure_only_namespaces_and_functions(self):
        self.write_doc(
            "CombatLogSecureDocumentation.lua", "CombatLogSecure", "System", ["AddEventFilter"],
            namespace="C_CombatLogSecure", environment="SecureOnly",
        )
        self.write_doc(
            "FrameScriptDocumentation.lua", "FrameScript", "System", ["issecretvalue", "securecopy"],
            function_environments={"securecopy": "SecureOnly"},
        )
        read = self.read()
        self.assertIn("issecretvalue", read)
        self.assertNotIn("C_CombatLogSecure", read)
        self.assertNotIn("securecopy", read)

    def test_reads_enum_and_constants_tables(self):
        (self.source / DOCS / "SpellBookConstantsDocumentation.lua").write_text(ENUM_DOC, encoding="utf-8")
        self.assertLessEqual({"Enum", "Constants"}, self.read())

    # TOC rules for the camelot game type

    def test_follows_game_type_directives(self):
        self.addon(
            "Blizzard_ProjectConstants",
            """\
            ## Title: Project constants
            Shared\\ProjectConstants.lua
            Camelot\\ProjectConstants.lua [AllowLoadGameType camelot]
            Classic\\ProjectConstants.lua [AllowLoadGameType classic]
            Standard\\ProjectConstants.lua [AllowLoadGameType standard, mists]
            Mainline\\Shared.lua [AllowLoadGameType wrath, mainline]
            Mainline\\NotForever.lua [AllowLoadGameType mainline] [ExcludeLoadGameType camelot]
            """,
            {
                "Shared/ProjectConstants.lua": "WOW_PROJECT_MAINLINE = 1;\n",
                "Camelot/ProjectConstants.lua": "WOW_PROJECT_CAMELOT = 18;\n",
                "Classic/ProjectConstants.lua": "WOW_PROJECT_CLASSIC = 2;\n",
                "Standard/ProjectConstants.lua": "WOW_PROJECT_STANDARD_ONLY = 3;\n",
                "Mainline/Shared.lua": "MAINLINE_FAMILY = 1;\n",
                "Mainline/NotForever.lua": "EXCLUDED_ON_FOREVER = 1;\n",
            },
        )
        read = self.read()
        self.assertLessEqual({"WOW_PROJECT_MAINLINE", "WOW_PROJECT_CAMELOT", "MAINLINE_FAMILY"}, read)
        self.assertFalse({"WOW_PROJECT_CLASSIC", "WOW_PROJECT_STANDARD_ONLY", "EXCLUDED_ON_FOREVER"} & read)

    def test_resolves_family_and_game_folders(self):
        self.addon(
            "Blizzard_Minimap",
            "## Title: Minimap\n[Family]\\Minimap.lua\n[Game]\\Minimap.lua [AllowLoadGameType camelot]\n",
            {"Mainline/Minimap.lua": "MinimapMixin = {};\n", "Camelot/Minimap.lua": "MinimapCamelotMixin = {};\n"},
        )
        self.assertLessEqual({"MinimapMixin", "MinimapCamelotMixin"}, self.read())

    def test_skips_addons_gated_away_from_camelot(self):
        self.addon("Blizzard_HousingDashboard", "## AllowLoadGameType: standard\nHousing.lua\n", {"Housing.lua": "HousingMixin = {};\n"})
        self.addon("Blizzard_PVPUI", "## ExcludeLoadGameType: camelot\nPVPUI.lua\n", {"PVPUI.lua": "PVPUIFrameMixin = {};\n"})
        self.addon("Blizzard_GlueParent", "## AllowLoad: Glue\nGlueParent.lua\n", {"GlueParent.lua": "GlueParentMixin = {};\n"})
        self.addon("Blizzard_Beta", "## OnlyBetaAndPTR: 1\nBeta.lua\n", {"Beta.lua": "BetaOnlyMixin = {};\n"})
        self.addon(
            "Blizzard_SwingTimer", "## AllowLoadGameType: standard, camelot\n## AllowLoad: both\nSwingTimer.lua\n",
            {"SwingTimer.lua": "SwingTimerMixin = {};\n"},
        )
        read = self.read()
        self.assertIn("SwingTimerMixin", read)
        self.assertFalse({"HousingMixin", "PVPUIFrameMixin", "GlueParentMixin", "BetaOnlyMixin"} & read)

    def test_applies_metadata_only_when_its_directive_matches(self):
        self.addon(
            "Blizzard_Mixed",
            "## AllowLoad: glue [AllowLoadGameType classic]\n## AllowLoad: both [AllowLoadGameType mainline]\nMixed.lua\n",
            {"Mixed.lua": "MixedMixin = {};\n"},
        )
        self.assertIn("MixedMixin", self.read())

    def test_skips_glue_only_files(self):
        self.addon(
            "Blizzard_TextSize",
            "## AllowLoad: both\nGame.lua [AllowLoad game]\nGlue.lua [AllowLoad glue]\n",
            {"Game.lua": "TextSizeGame = {};\n", "Glue.lua": "TextSizeGlue = {};\n"},
        )
        read = self.read()
        self.assertIn("TextSizeGame", read)
        self.assertNotIn("TextSizeGlue", read)

    def test_reads_directives_on_either_side_of_the_path(self):
        self.addon(
            "Blizzard_FullscreenBrowser",
            """\
            [AllowLoadTextLocale: zhCN] Spinner.lua
            [AllowLoadTextLocale: enUS] English.lua
            Declension.lua [AllowLoadTextLocale ruRU] [AllowLoad game]
            Tabbed.lua\t\t[AllowLoadGameType camelot]
            """,
            {
                "Spinner.lua": "BrowserSpinner = {};\n",
                "English.lua": "BrowserEnglish = {};\n",
                "Declension.lua": "DeclensionFrame = {};\n",
                "Tabbed.lua": "TabbedLine = {};\n",
            },
        )
        collected = self.collect()
        self.assertEqual(collected.missing, [])
        self.assertLessEqual({"BrowserEnglish", "TabbedLine"}, set(collected.read))
        self.assertFalse({"BrowserSpinner", "DeclensionFrame"} & set(collected.read))

    def test_prefers_game_then_family_toc(self):
        self.write("Blizzard_WorldMap/Blizzard_WorldMap.toc", "Plain.lua\n")
        self.write("Blizzard_WorldMap/Blizzard_WorldMap_Mainline.toc", "Mainline.lua\n")
        self.write("Blizzard_WorldMap/Blizzard_WorldMap_Vanilla.toc", "Vanilla.lua\n")
        self.write("Blizzard_WorldMap/Plain.lua", "WorldMapPlain = {};\n")
        self.write("Blizzard_WorldMap/Mainline.lua", "WorldMapMainline = {};\n")
        self.write("Blizzard_WorldMap/Vanilla.lua", "WorldMapVanilla = {};\n")
        self.write("Blizzard_Bags/Blizzard_Bags_Mainline.toc", "Mainline.lua\n")
        self.write("Blizzard_Bags/Blizzard_Bags_Camelot.toc", "Camelot.lua\n")
        self.write("Blizzard_Bags/Mainline.lua", "BagsMainline = {};\n")
        self.write("Blizzard_Bags/Camelot.lua", "BagsCamelot = {};\n")
        read = self.read()
        self.assertLessEqual({"WorldMapMainline", "BagsCamelot"}, read)
        self.assertFalse({"WorldMapPlain", "WorldMapVanilla", "BagsMainline"} & read)

    def test_skips_files_loaded_into_the_secure_environment(self):
        self.addon(
            "Blizzard_AuraContainer",
            "## UseSecureEnvironment: 1\nSecure.lua\nInbound.lua [LoadIntoEnvironment global]\n",
            {"Secure.lua": "AuraContainerSecureMixin = {};\n", "Inbound.lua": "AuraContainerInbound = {};\n"},
        )
        self.addon(
            "Blizzard_CooldownViewer",
            "CooldownViewer.lua\nCooldownViewerSecure.lua [LoadIntoEnvironment secure]\n",
            {"CooldownViewer.lua": "CooldownViewerMixin = {};\n", "CooldownViewerSecure.lua": "CooldownViewerSecureMixin = {};\n"},
        )
        read = self.read()
        self.assertLessEqual({"AuraContainerInbound", "CooldownViewerMixin"}, read)
        self.assertFalse({"AuraContainerSecureMixin", "CooldownViewerSecureMixin"} & read)

    def test_reads_exports_that_secure_files_write_to_the_global_environment(self):
        self.addon(
            "Blizzard_AuraContainer",
            "## UseSecureEnvironment: 1\nShared.lua\n",
            {
                "Shared.lua": """\
                    CustomAuraContainerLayoutDefaults = { spacing = 2 };
                    SecureOnlyHelper = {};

                    local _G = GetGlobalEnvironment();
                    _G.CustomAuraContainerLayoutDefaults = securecopy(CustomAuraContainerLayoutDefaults);
                    _G["AuraContainerSortMethod"] = securecopy(AuraContainerSortMethod);
                    local copy = _G.rtable.copytable;
                    """
            },
        )
        read = self.read()
        self.assertLessEqual({"CustomAuraContainerLayoutDefaults", "AuraContainerSortMethod", "rtable"}, read)
        self.assertFalse({"SecureOnlyHelper", "securecopy", "GetGlobalEnvironment", "copytable"} & read)

    def test_reads_literal_writes_into_the_global_table(self):
        self.addon(
            "Blizzard_ChatFrameBase",
            "SlashCommands.lua\n",
            {
                "SlashCommands.lua": """\
                    _G.SlashCmdList = {};
                    _G["SLASH_EVENT1"] = "/event";
                    local name = "Dynamic";
                    _G[name] = true;
                    local frame = _G.ChatFrameEditBox;
                    """
            },
        )
        read = self.read()
        self.assertLessEqual({"SlashCmdList", "SLASH_EVENT1", "ChatFrameEditBox"}, read)
        self.assertFalse({"Dynamic", "name", "frame"} & read)

    def test_secure_only_apis_stay_out_even_when_blizzard_code_names_them(self):
        self.write_doc(
            "CombatLogSecureDocumentation.lua", "CombatLogSecure", "System", ["AddEventFilter"],
            namespace="C_CombatLogSecure", environment="SecureOnly",
        )
        self.write_doc(
            "FrameScriptDocumentation.lua", "FrameScript", "System", ["issecretvalue", "GetForbiddenObjectTable"],
            function_environments={"GetForbiddenObjectTable": "SecureOnly"},
        )
        self.addon(
            "Blizzard_CombatLog",
            "CombatLog.lua\n",
            {"CombatLog.lua": "local owner = GetForbiddenObjectTable(UIParent);\nC_CombatLogSecure.AddEventFilter();\n"},
        )
        read = self.read()
        self.assertIn("UIParent", read)
        self.assertFalse({"GetForbiddenObjectTable", "C_CombatLogSecure"} & read)

    # XML files

    def test_follows_xml_scripts_and_includes_relative_to_each_file(self):
        self.addon(
            "Blizzard_UnitFrame",
            "## Title: Unit frames\nMainline\\UnitFrame.xml\n",
            {
                "Mainline/UnitFrame.xml": """\
                    <Ui xmlns="http://www.blizzard.com/wow/ui/">
                    \t<Script file="UnitFrame.lua"/>
                    \t<Include file="Sub\\Sub.xml"/>
                    </Ui>
                    """,
                "Mainline/UnitFrame.lua": "function UnitFrame_OnLoad(self)\nend\n",
                "Mainline/Sub/Sub.xml": '<Ui>\n\t<Script file="Nested.lua"/>\n</Ui>\n',
                "Mainline/Sub/Nested.lua": "NestedMixin = {};\n",
            },
        )
        self.assertLessEqual({"UnitFrame_OnLoad", "NestedMixin"}, self.read())

    def test_falls_back_to_the_addon_folder_for_xml_scripts(self):
        self.addon(
            "Blizzard_SettingsDefinitions_Frame",
            "[Family]\\Colorblind.xml\n",
            {
                "Mainline/Colorblind.xml": '<Ui>\n\t<Script file="Colorblind.lua"/>\n</Ui>\n',
                "Colorblind.lua": "ColorblindSettings = {};\n",
            },
        )
        collected = self.collect()
        self.assertEqual(collected.missing, [])
        self.assertIn("ColorblindSettings", collected.read)

    def test_reports_files_that_are_listed_but_missing(self):
        self.addon("Blizzard_Broken", "Gone.lua\nBroken.xml\n", {"Broken.xml": '<Ui>\n\t<Script file="Absent.lua"/>\n</Ui>\n'})
        missing = self.collect().missing
        self.assertEqual(len(missing), 2, missing)
        self.assertTrue(any("Gone.lua" in entry for entry in missing), missing)
        self.assertTrue(any("Absent.lua" in entry for entry in missing), missing)

    def test_reads_named_xml_objects(self):
        self.addon(
            "Blizzard_UnitFrame",
            "PlayerFrame.xml\n",
            {
                "PlayerFrame.xml": """\
                    <Ui xmlns="http://www.blizzard.com/wow/ui/">
                    \t<Font name="GameFontNormal" virtual="true"/>
                    \t<Frame name="UnitFrameTemplate" virtual="true">
                    \t\t<Frames>
                    \t\t\t<StatusBar name="$parentHealthBar"/>
                    \t\t\t<Frame name="TemplateChildGlobal"/>
                    \t\t</Frames>
                    \t</Frame>
                    \t<Button name="PlayerFrame" inherits="UnitFrameTemplate">
                    \t\t<Frames>
                    \t\t\t<StatusBar name="$parentManaBar" parentKey="ManaBar"/>
                    \t\t\t<Frame parentKey="NoName"/>
                    \t\t</Frames>
                    \t\t<Layers>
                    \t\t\t<Layer level="ARTWORK">
                    \t\t\t\t<FontString name="PlayerName" inherits="GameFontNormal"/>
                    \t\t\t</Layer>
                    \t\t</Layers>
                    \t</Button>
                    \t<Frame name="ScrollingFrameIntrinsic" intrinsic="true"/>
                    </Ui>
                    """
            },
        )
        read = self.read()
        self.assertLessEqual({"GameFontNormal", "PlayerFrame", "PlayerFrameManaBar", "PlayerName"}, read)
        self.assertFalse({"UnitFrameTemplate", "TemplateChildGlobal", "ScrollingFrameIntrinsic"} & read)
        self.assertFalse({name for name in read if "$" in name})

    # Lua scanning

    def test_reads_engine_globals_that_blizzard_code_uses(self):
        self.addon(
            "Blizzard_ActionBar",
            "ActionBar.lua\n",
            {
                "ActionBar.lua": """\
                    local helper = CreateFromMixins(ActionBarMixin);
                    local function Setup(frame, ...)
                    \tif InCombatLockdown() then
                    \t\treturn;
                    \tend
                    \tframe:SetParent(UIParent);
                    \thooksecurefunc(frame, "Show", helper.Show);
                    \tlocal list = { Width = 10, ["Height"] = 2 };
                    \tfor index, value in ipairs(list) do
                    \t\tprint(index, value, frame.NotAGlobal, select("#", ...));
                    \tend
                    \treturn strsplit(",", "a,b");
                    end
                    -- CommentedGlobal()
                    --[[ BlockCommentGlobal() ]]
                    local text = "StringGlobal()" .. [[LongStringGlobal]] .. 'Single';
                    """
            },
        )
        read = self.read()
        self.assertLessEqual({"CreateFromMixins", "ActionBarMixin", "InCombatLockdown", "UIParent", "hooksecurefunc", "strsplit"}, read)
        unwanted = {
            "helper", "Setup", "frame", "list", "Width", "Height", "index", "value", "NotAGlobal", "text",
            "CommentedGlobal", "BlockCommentGlobal", "StringGlobal", "LongStringGlobal", "Single",
        }
        self.assertFalse(unwanted & read)

    def test_reads_globals_cached_in_a_local_of_the_same_name(self):
        self.addon(
            "Blizzard_PrintHandler",
            "PrintHandler.lua\n",
            {
                "PrintHandler.lua": """\
                    local forceinsecure = forceinsecure;
                    local GetTargetTradeMoney = GetTargetTradeMoney or nil;

                    function tostringall(...)
                    \treturn ...;
                    end

                    local tostringall = tostringall;
                    local cached = 1;
                    local function Use()
                    \treturn cached, forceinsecure(), tostringall();
                    end
                    """
            },
        )
        read = self.read()
        self.assertLessEqual({"forceinsecure", "GetTargetTradeMoney", "tostringall"}, read)
        self.assertFalse({"cached", "Use"} & read)

    def test_leaves_lua_standard_globals_to_luacheck(self):
        self.addon("Blizzard_Util", "Util.lua\n", {"Util.lua": "UtilGlobal = string.format(\"%d\", math.floor(tonumber(\"1\")));\n"})
        read = self.read()
        self.assertIn("UtilGlobal", read)
        self.assertFalse({"string", "math", "tonumber"} & read)

    def test_keeps_a_name_that_real_code_also_defines(self):
        self.addon("Blizzard_DeprecatedSpellBook", "Deprecated.lua\n", {"Deprecated.lua": "function FindBaseSpellByID(id)\nend\n"})
        self.addon("Blizzard_SpellBook", "SpellBook.lua\n", {"SpellBook.lua": "function FindBaseSpellByID(id)\nend\n"})
        collected = self.collect()
        self.assertIn("FindBaseSpellByID", collected.read)
        self.assertNotIn("FindBaseSpellByID", collected.deprecated)

    def test_drops_a_shim_that_camelot_code_still_calls(self):
        self.addon("Blizzard_DeprecatedSpellBook", "Deprecated.lua\n", {"Deprecated.lua": "function IsPlayerSpell(id)\nend\n"})
        self.addon("Blizzard_Talents", "Talents.lua\n", {"Talents.lua": "local known = IsPlayerSpell(1);\n"})
        collected = self.collect()
        self.assertIn("IsPlayerSpell", collected.deprecated)
        self.assertNotIn("IsPlayerSpell", collected.read)

    def test_ignores_deprecated_shims_for_other_game_types(self):
        self.addon(
            "Blizzard_Deprecated",
            "Classic\\Deprecated.lua [AllowLoadGameType classic]\nShared\\Deprecated.lua\n",
            {"Classic/Deprecated.lua": "function ClassicOnlyShim()\nend\n", "Shared/Deprecated.lua": "function SharedShim()\nend\n"},
        )
        deprecated = self.deprecated()
        self.assertIn("SharedShim", deprecated)
        self.assertNotIn("ClassicOnlyShim", deprecated)

    # Command line

    def test_fails_without_writing_when_the_docs_are_missing(self):
        (self.source / DOCS).rmdir()
        code, err = self.generate()
        self.assertEqual(code, 1)
        self.assertIn("Blizzard_APIDocumentationGenerated", err)
        self.assertFalse(self.out.exists())

    def test_fails_without_writing_when_the_source_is_not_a_git_checkout(self):
        self.write_doc("UnitDocumentation.lua", "Unit", "System", ["UnitHealth"])
        code, err = self.generate()
        self.assertEqual(code, 1)
        self.assertIn("not a git checkout", err)
        self.assertFalse(self.out.exists())


if __name__ == "__main__":
    unittest.main()
