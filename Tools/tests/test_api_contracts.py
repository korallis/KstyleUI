"""Tests for Tools/build/gen_api_contracts.py and Tools/hooks/check_api_contracts.py."""

import contextlib
import io
import json
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "Tools" / "build"))
sys.path.insert(0, str(REPO / "Tools" / "hooks"))

import check_api_contracts  # noqa: E402
import gen_api_contracts  # noqa: E402
import gen_globals  # noqa: E402

ADDONS = Path("Interface") / "AddOns"
DOCS = ADDONS / "Blizzard_APIDocumentationGenerated"

FIXTURE = {
    "schema": 1,
    "source": {"commit": "abc1234", "subject": "fixture"},
    "files": ["Blizzard_Fixture/Docs.lua", "Blizzard_Fixture/Fixture.xml"],
    "namespaces": {
        "C_Spell": {"at": "0:3", "system": "Spell"},
        "C_CVar": {"at": "0:40", "system": "CVarScripts"},
        "C_Secure": {"at": "0:5", "system": "Secure", "secure": True},
        "C_Lua": {"at": "0:90", "system": None, "open": True},
        "C_Sub.Part": {"at": "0:95", "system": "Sub"},
    },
    "functions": {
        "C_Spell.GetSpellInfo": {"at": "0:10", "args": "spellIdentifier:SpellIdentifier", "meta": {"SecretArguments": "AllowedWhenUntainted"}},
        "C_Spell.GetSpellName": {"at": "0:20"},
        "C_CVar.GetCVar": {"at": "0:41"},
        "C_CVar.SetCVar": {"at": "0:42"},
        "C_Sub.Part.Run": {"at": "0:96"},
    },
    "secure_only": {"C_Secure.Do": "0:5"},
    "removed": {"C_Store": "1:1", "Enum.Gone": "1:2", "C_Spell.Old": "1:3"},
    "events": {
        "PLAYER_LOGIN": {"at": "0:50", "system": "Player"},
        "UNIT_AURA": {"at": "0:60", "system": "UnitAuras"},
        "BAG_UPDATE": {"at": "0:61", "system": "Bag"},
    },
    "cvars": {
        "showtimestamps": {"name": "showTimestamps", "at": "1:10", "via": "GetCVar"},
        "clientonly": {"name": "clientOnly", "offset": 4096, "via": "client binary"},
    },
    "templates": {
        "BackdropTemplate": {"at": "1:20", "tag": "Frame"},
        "SecureHandlerBaseTemplate": {"at": "1:21", "tag": "Frame"},
        "GameFontNormal": {"at": "1:22", "tag": "Font"},
    },
    "enums": {
        "ItemClass": {"at": "0:70", "fields": ["Armor", "Weapon"]},
        "GameRule": {"at": "1:30", "fields": ["Alpha"], "via": "use"},
    },
    "constants": {"EditModeConsts": {"at": "0:80", "values": ["Width"]}},
    "mixins": {"BackdropTemplateMixin": {"at": "1:40"}},
    "addons": {"Blizzard_Fixture": "loaded", "Blizzard_Old": "deprecated", "Blizzard_Later": "not loaded"},
    "client": {"build": "1.0.0.1", "sha256": "ab" * 32, "file": "client"},
}
GLOBALS = textwrap.dedent(
    """\
    return {
    \tread = {
    \t\t"UIParent",
    \t\t"ContainerFrame1",
    \t\t"PlayerFrame",
    \t},
    \tdeprecated = {
    \t\t"GetInventorySlotInfo",
    \t},
    }
    """
)


def contracts():
    data = json.loads(json.dumps(FIXTURE))
    result = check_api_contracts.Contracts(data, GLOBALS)
    return result


class AddonCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def check(self, lua="", xml=None, extra=None):
        """Write an addon with one Lua file (and optional XML) and return every Result."""
        entries = ["Main.lua"]
        (self.root / "Main.lua").write_text(textwrap.dedent(lua), encoding="utf-8")
        if xml is not None:
            (self.root / "Main.xml").write_text(textwrap.dedent(xml), encoding="utf-8")
            entries.append("Main.xml")
        for name, text in (extra or {}).items():
            (self.root / name).write_text(textwrap.dedent(text), encoding="utf-8")
            entries.append(name)
        (self.root / "Test.toc").write_text("\n".join(entries) + "\n", encoding="utf-8")
        return check_api_contracts.check(self.root, contracts())

    def problems(self, lua="", xml=None, extra=None):
        return [(r.use.category, r.message) for r in self.check(lua, xml, extra) if r.status == "problem"]

    def names(self, lua="", status="ok", category=None):
        return sorted(r.use.name for r in self.check(lua) if r.status == status and r.use.name and (category is None or r.use.category == category))


class TokenizeTest(unittest.TestCase):
    def test_matches_gen_globals_tokens(self):
        text = '-- c\nlocal a = "x" .. [[long\nstring]] --[[block\ncomment]] f(1, 0x10)\nreturn a.b:c{}'
        tokens, lines = gen_api_contracts.tokenize(text)
        self.assertEqual(tokens, gen_globals.lua_tokens(text))
        self.assertEqual(len(tokens), len(lines))
        self.assertEqual(lines[tokens.index(("keyword", "return"))], 5)


class CApiTest(AddonCase):
    def test_documented_members_pass(self):
        self.assertEqual(self.problems("local i = C_Spell.GetSpellInfo(1)\nlocal n = C_Spell['GetSpellName']\nC_Sub.Part.Run()"), [])

    def test_absent_member_fails_with_suggestion(self):
        found = self.problems("C_Spell.GetSpellInf(1)")
        self.assertEqual(len(found), 1)
        self.assertIn("C_Spell has no member GetSpellInf", found[0][1])
        self.assertIn("did you mean GetSpellInfo", found[0][1])

    def test_absent_namespace_fails(self):
        self.assertIn("namespace C_Nope", self.problems("C_Nope.Thing()")[0][1])

    def test_secure_only_and_removed_fail(self):
        self.assertIn("secure environment", self.problems("C_Secure.Do()")[0][1])
        self.assertIn("secure environment", self.problems("local x = C_Secure")[0][1])
        self.assertIn("not available", self.problems("C_Store.Buy()")[0][1])
        self.assertIn("removes C_Spell.Old", self.problems("C_Spell.Old()")[0][1])

    def test_open_lua_namespace_accepts_members(self):
        self.assertEqual(self.problems("C_Lua.Anything()"), [])

    def test_open_namespace_member_is_not_certified(self):
        found = self.check("C_Lua.Anything()")
        self.assertEqual([r.status for r in found], ["dynamic"])

    def test_reassigned_member_key_stays_dynamic(self):
        found = self.check('local key = "GetSpellInfo"\nkey = chooseKey()\nlocal x = C_Spell[key]')
        self.assertEqual([r.status for r in found if r.use.category == "api"], ["dynamic"])

    def test_reassigned_field_key_stays_dynamic(self):
        found = self.check('local settings = { key = "BackdropTemplate" }\nsettings.key = chooseKey()\nCreateFrame("Frame", nil, p, settings.key)')
        self.assertEqual([r.status for r in found if r.use.category == "template"], ["dynamic"])

    def test_multiple_assignment_does_not_certify_a_member_key(self):
        found = self.check('local key = "GetSpellInfo"\nkey, other = chooseKey()\nlocal x = C_Spell[key]')
        self.assertEqual([r.status for r in found if r.use.category == "api"], ["dynamic"])

    def test_multiple_assignment_does_not_certify_a_template_field(self):
        found = self.check('local settings = { key = "BackdropTemplate" }\nsettings.key, settings.other = chooseKey()\nCreateFrame("Frame", nil, p, settings.key)')
        self.assertEqual([r.status for r in found if r.use.category == "template"], ["dynamic"])

    def test_alias_declared_once_is_followed(self):
        self.assertEqual(self.problems("local Spell = C_Spell\nSpell.GetSpellInfo(1)"), [])
        self.assertEqual(len(self.problems("local Spell = C_Spell\nSpell.Nope(1)")), 1)

    def test_alias_declared_twice_is_not_trusted(self):
        self.assertEqual(self.problems("local Spell = C_Spell\nlocal function f()\n local Spell = {}\n Spell.Nope()\nend"), [])

    def test_literal_key_and_pcall(self):
        self.assertEqual(self.names('local f = C_CVar["GetCVar"]\npcall(C_CVar.SetCVar, "a", "1")', category="api"), ["C_CVar.GetCVar", "C_CVar.SetCVar"])

    def test_computed_member_is_dynamic(self):
        results = self.check("local name = pick()\nlocal fn = C_CVar[name]")
        dynamic = [r for r in results if r.status == "dynamic"]
        self.assertEqual([r.use.name for r in dynamic], ["C_CVar"])
        self.assertEqual(dynamic[0].use.operand, "name")

    def test_getter_function_names_the_member(self):
        lua = """
            local function Api(name)
                local fn = C_CVar and C_CVar[name]
                return type(fn) == "function" and fn or nil
            end
            Api("GetCVar")
            Api("GetCVarX")
        """
        found = self.problems(lua)
        self.assertEqual(len(found), 1)
        self.assertIn("C_CVar has no member GetCVarX", found[0][1])

    def test_getter_with_namespace_parameter(self):
        lua = """
            local function Fn(api, name) return api and api[name] end
            Fn(C_Spell, "GetSpellName")
            Fn(C_Spell, "Missing")
        """
        self.assertEqual(len(self.problems(lua)), 1)

    def test_hooksecurefunc_on_a_namespace(self):
        self.assertEqual(len(self.problems('hooksecurefunc(C_Spell, "Missing", function() end)')), 1)

    def test_comments_and_strings_are_ignored(self):
        lua = """
            -- C_Nope.Thing() and RegisterEvent("FAKE_EVENT")
            local s = "C_Nope.Thing(); GetCVar('nope')"
            local long = [[ C_Nope.Other() frame:RegisterEvent("FAKE_EVENT") ]]
            --[[ Enum.Nope.X ]]
        """
        self.assertEqual(self.problems(lua), [])

    def test_local_shadowing_a_namespace_is_not_checked(self):
        self.assertEqual(self.problems("local C_Nope = {}\nC_Nope.Thing()"), [])


class EventTest(AddonCase):
    def test_known_events_pass_in_every_registration_form(self):
        lua = """
            frame:RegisterEvent("PLAYER_LOGIN")
            frame:RegisterUnitEvent("UNIT_AURA", "player")
            K.Events.Register("Mod", "BAG_UPDATE", fn)
            ns.Events.RegisterUnit("Mod", "UNIT_AURA", fn, "player")
            Events.Register("Mod", "PLAYER_LOGIN", fn)
            pcall(K.Events.Register, "Mod", "UNIT_AURA", fn)
            pcall(frame.RegisterEvent, frame, "BAG_UPDATE")
            FrameUtil.RegisterFrameForEvents(frame, { "PLAYER_LOGIN", "UNIT_AURA" })
            EventRegistry:RegisterFrameEventAndCallback("BAG_UPDATE", fn, owner)
        """
        self.assertEqual(self.problems(lua), [])
        self.assertEqual(len(self.names(lua, category="event")), 10)

    def test_absent_event_fails_in_every_form(self):
        lua = """
            frame:RegisterEvent("NOT_AN_EVENT")
            frame:RegisterUnitEvent("UNIT_AURAS", "player")
            K.Events.Register("Mod", "PLAYER_LOGON", fn)
            ns.Events.RegisterUnit("Mod", "UNIT_AURS", fn, "player")
            pcall(K.Events.Register, "Mod", "BAG_UPDATES", fn)
            FrameUtil.RegisterFrameForEvents(frame, { "PLAYER_LOGIN", "FAKE_ONE" })
        """
        self.assertEqual(len(self.problems(lua)), 6)

    def test_event_table_iterated_into_registration(self):
        lua = """
            local EVENTS = { "PLAYER_LOGIN", "UNIT_AURAZ" }
            for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
        """
        found = self.problems(lua)
        self.assertEqual(len(found), 1)
        self.assertIn("UNIT_AURAZ", found[0][1])

    def test_event_table_with_bracket_and_dict_keys(self):
        lua = """
            local unitEvents = { UNIT_AURA = true, UNIT_FAKE = true }
            for event in pairs(unitEvents) do frame:RegisterEvent(event) end
        """
        self.assertEqual(len(self.problems(lua)), 1)

    def test_dict_named_events_without_registration_is_not_an_event_list(self):
        self.assertEqual(self.problems("local WORD_EVENTS = { MISS = true, DODGE = true }\nlocal x = WORD_EVENTS.MISS"), [])

    def test_lowercase_or_unrelated_uppercase_strings_are_not_events(self):
        lua = """
            local label = "SOME_CONSTANT"
            local events = { "ThemeChanged", "Other" }
            Callbacks.Fire("THEME_CHANGED")
        """
        self.assertEqual(self.problems(lua), [])

    def test_function_that_takes_an_event_is_followed_across_files(self):
        extra = {"Other.lua": 'ns.On("PLAYER_LOGIN", f)\nns.On("PLAYER_LOGOUT_NOPE", f)\n'}
        found = self.problems("function ns.On(event, fn) frame:RegisterEvent(event) end", extra=extra)
        self.assertEqual(len(found), 1)
        self.assertIn("PLAYER_LOGOUT_NOPE", found[0][1])

    def test_variable_event_is_dynamic_not_a_problem(self):
        results = self.check("local e = fn()\nframe:RegisterEvent(e)")
        self.assertEqual([(r.status, r.use.operand) for r in results], [("dynamic", "e")])

    def test_local_literal_constant_resolves(self):
        results = self.check('local EVT = "NO_SUCH_EVENT"\nframe:RegisterEvent(EVT)')
        self.assertEqual([r.status for r in results], ["problem"])
        self.assertIn("via EVT", results[0].use.detail)


class TemplateTest(AddonCase):
    def test_known_templates_pass(self):
        lua = """
            CreateFrame("Frame", nil, parent, "BackdropTemplate")
            CreateFrame("Button", "Name", parent, "SecureHandlerBaseTemplate, BackdropTemplate")
            frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            pcall(CreateFrame, "Frame", nil, parent, "BackdropTemplate")
        """
        self.assertEqual(self.problems(lua), [])

    def test_absent_template_fails(self):
        lua = """
            CreateFrame("Frame", nil, parent, "NoSuchTemplate")
            CreateFrame("Frame", nil, parent, "BackdropTemplate, AlsoMissing")
            frame:CreateFontString(nil, "OVERLAY", "GameFontMissing")
            CreateFramePool("Button", parent, "PoolMissing")
        """
        self.assertEqual(len(self.problems(lua)), 4)

    def test_template_in_a_local_constant_is_checked(self):
        found = self.problems('local TEMPLATE = "MissingTemplate"\nCreateFrame("Frame", nil, parent, TEMPLATE)')
        self.assertEqual(len(found), 1)

    def test_template_held_in_a_field_is_checked_across_files(self):
        extra = {"Other.lua": "CreateFrame('Frame', nil, parent, Slot.TEMPLATE)\n"}
        self.assertEqual(len(self.problems("local T = 'MissingTemplate'\nSlot.TEMPLATE = T", extra=extra)), 1)

    def test_computed_template_is_dynamic(self):
        results = self.check("CreateFrame('Frame', nil, parent, opts.template)")
        self.assertEqual([(r.status, r.use.operand) for r in results], [("dynamic", "opts . template")])

    def test_xml_inherits_and_mixin(self):
        xml = """
            <Ui>
              <Frame name="KstyleUI_Mine" virtual="true" inherits="BackdropTemplate"/>
              <Frame name="Uses" inherits="KstyleUI_Mine" mixin="BackdropTemplateMixin"/>
              <Frame name="Bad" inherits="NoSuchTemplate, BackdropTemplate" mixin="NoSuchMixin"/>
            </Ui>
        """
        found = self.problems(xml=xml)
        self.assertEqual(sorted(c for c, _ in found), ["mixin", "template"])
        self.assertTrue(any("NoSuchTemplate" in m for _, m in found))

    def test_template_the_addon_defines_in_xml_is_known_to_lua(self):
        xml = '<Ui><Button name="KstyleUI_Row" virtual="true"/></Ui>'
        self.assertEqual(self.problems("CreateFrame('Button', nil, parent, 'KstyleUI_Row')", xml=xml), [])

    def test_xml_that_does_not_parse_is_a_problem(self):
        self.assertIn("does not parse", self.problems(xml="<Ui><Frame></Ui>")[0][1])


class CVarTest(AddonCase):
    def test_known_cvars_pass_case_insensitively(self):
        lua = """
            GetCVar("showTimestamps")
            C_CVar.SetCVar("showtimestamps", "1")
            GetCVarBool("clientOnly")
            Settings.SetupCVarCheckbox(category, "showTimestamps", setting, label)
        """
        self.assertEqual(self.problems(lua), [])

    def test_absent_cvar_fails(self):
        found = self.problems('GetCVar("showTimestamp")\nSetCVar("nope", 1)\nC_CVar.GetCVar("alsoNope")')
        self.assertEqual(len(found), 3)
        self.assertIn("did you mean showtimestamps", found[0][1])

    def test_cvar_variable_and_field_names(self):
        lua = """
            local CVAR = "missingCVar"
            local CVARS = { { name = "showTimestamps" }, { name = "otherMissing" } }
            local ENTRY = { cvar = "thirdMissing", key = "x" }
            pcall(GetCVar, CVAR)
        """
        self.assertEqual(len(self.problems(lua)), 3)

    def test_cvar_held_in_a_variable_is_dynamic(self):
        results = self.check("GetCVar(name)")
        self.assertEqual([r.status for r in results], ["dynamic"])

    def test_cvar_named_field_assignments_are_checked(self):
        found = self.problems('Logic.MOTION_CVAR = "missingCVar"\nLogic.STACKING_CVAR = "showTimestamps"')
        self.assertEqual(len(found), 1)
        self.assertIn("missingCVar", found[0][1])

    def test_cvar_label_field_is_not_a_registry_name(self):
        self.assertEqual(self.check('frame.cvarLabel = "STATUS_TEXT_PET"'), [])

    def test_core_cvar_wrapper_literals_are_checked(self):
        for method in ("Exists", "Get", "Default", "Set", "SetBitfield"):
            with self.subTest(method=method):
                found = self.problems('K.CVars.' + method + '("missingCVar", 1, true)')
                self.assertEqual(len(found), 1)
                self.assertIn("missingCVar", found[0][1])


class EnumTest(AddonCase):
    def test_known_members_pass(self):
        lua = "local a = Enum.ItemClass.Weapon\nlocal b = Enum.ItemClass\nlocal c = Constants.EditModeConsts.Width\nlocal d = Enum.GameRule.Alpha"
        self.assertEqual(self.problems(lua), [])

    def test_absent_enum_or_member_fails(self):
        found = self.problems("a = Enum.ItemClass.Shield\nb = Enum.NoSuch\nc = Constants.EditModeConsts.Height\nd = Constants.Nope.X\ne = Enum.Gone.X")
        self.assertEqual(len(found), 5)

    def test_member_the_source_only_uses_is_reported_with_that_limit(self):
        self.assertIn("only the members loaded Blizzard code reads", self.problems("x = Enum.GameRule.Beta")[0][1])

    def test_alias_of_an_enum(self):
        self.assertEqual(self.problems("local Class = Enum.ItemClass\nx = Class.Weapon"), [])
        self.assertEqual(len(self.problems("local Class = Enum.ItemClass\nx = Class.Shield")), 1)
        self.assertEqual(self.problems("local rules, enum = C_Spell, Enum and Enum.GameRule\nx = enum.Alpha"), [])

    def test_computed_member_is_dynamic(self):
        results = self.check("x = Enum.ItemClass[name]")
        self.assertEqual([r.status for r in results], ["dynamic"])


class GlobalTest(AddonCase):
    def test_known_globals_pass(self):
        lua = '_G.UIParent:Hide()\nlocal f = _G["PlayerFrame"]\nhooksecurefunc("PlayerFrame", fn)\nlocal g = _G.string'
        self.assertEqual(self.problems(lua), [])

    def test_absent_global_fails(self):
        found = self.problems('local a = _G["NoSuchFrame"]\nlocal b = _G.AlsoNone\nhooksecurefunc("MissingFn", fn)')
        self.assertEqual(len(found), 3)

    def test_deprecated_global_fails(self):
        self.assertIn("deprecated shim", self.problems('local f = _G["GetInventorySlotInfo"]')[0][1])

    def test_global_the_addon_creates_is_not_blizzards(self):
        self.assertEqual(self.problems('_G["KstyleUI_Thing"] = {}\nlocal x = _G.KstyleUI_Thing\nCreateFrame("Frame", "KstyleUI_Frame")\nlocal y = _G["KstyleUI_Frame"]'), [])

    def test_prefix_is_checked_and_listed_as_dynamic(self):
        results = self.check('local a = _G["ContainerFrame" .. i]\nlocal b = _G["NoPrefix" .. i]')
        self.assertEqual([r.status for r in results], ["dynamic", "problem"])

    def test_constant_key_is_resolved(self):
        self.assertEqual(len(self.problems('local FRAME = "MissingFrame"\nlocal f = _G[FRAME]')), 1)
        self.assertEqual(self.problems('local FRAME = "PlayerFrame"\nlocal f = _G[FRAME]'), [])


class AddonNameAndMixinTest(AddonCase):
    def test_addon_folders(self):
        found = self.problems('C_Spell.GetSpellName("Blizzard_Fixture")\nLoad("Blizzard_Old")\nLoad("Blizzard_Later")\nLoad("Blizzard_Missing")')
        self.assertEqual(len(found), 3)

    def test_mixin_identifiers(self):
        self.assertEqual(self.problems("Mixin(f, BackdropTemplateMixin)"), [])
        self.assertEqual(len(self.problems("Mixin(f, NoSuchMixin)")), 1)
        self.assertEqual(self.problems("MyMixin = {}\nMixin(f, MyMixin)"), [])


class ReportTest(AddonCase):
    def run_main(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = check_api_contracts.main(list(args))
        return code, out.getvalue()

    def write_contracts(self):
        path = self.root / "contracts.json"
        path.write_text(json.dumps(FIXTURE), encoding="utf-8")
        glob = self.root / "globals.lua"
        glob.write_text(GLOBALS, encoding="utf-8")
        return ["--contracts", str(path), "--globals", str(glob), "--root", str(self.root)]

    def test_exit_code_and_problem_lines(self):
        (self.root / "A.lua").write_text("C_Spell.Nope()\nC_Spell.GetSpellInfo(1)\n", encoding="utf-8")
        (self.root / "Test.toc").write_text("A.lua\n", encoding="utf-8")
        code, out = self.run_main(*self.write_contracts())
        self.assertEqual(code, 1)
        self.assertEqual(out.splitlines(), ["A.lua:1: api: C_Spell has no member Nope"])

    def test_clean_run_prints_nothing(self):
        (self.root / "A.lua").write_text("C_Spell.GetSpellInfo(1)\n", encoding="utf-8")
        (self.root / "Test.toc").write_text("A.lua\n", encoding="utf-8")
        self.assertEqual(self.run_main(*self.write_contracts()), (0, ""))

    def test_inventory_lists_every_occurrence_with_proof_and_dynamic_operands(self):
        (self.root / "A.lua").write_text(
            "C_Spell.GetSpellInfo(1)\nlocal e = x()\nframe:RegisterEvent(e)\nframe:RegisterEvent('PLAYER_LOGIN')\nGetCVar('clientOnly')\nC_Spell.Nope()\n",
            encoding="utf-8",
        )
        (self.root / "Test.toc").write_text("A.lua\n", encoding="utf-8")
        code, out = self.run_main(*self.write_contracts(), "--inventory")
        rows = [line.split("\t") for line in out.splitlines()]
        self.assertEqual(code, 1)
        self.assertEqual(rows[0][:3], ["category", "status", "location"])
        by_location = {row[2]: row for row in rows[1:-1]}
        self.assertEqual(by_location["A.lua:1"][3:6:2], ["C_Spell.GetSpellInfo", "Blizzard_Fixture/Docs.lua:10"])
        self.assertEqual(by_location["A.lua:3"][1], "dynamic")
        self.assertEqual(by_location["A.lua:3"][3], "<dynamic> e")
        self.assertEqual(by_location["A.lua:4"][5], "Blizzard_Fixture/Docs.lua:50")
        self.assertIn("client 1.0.0.1 sha256 abababababab offset 0x1000", by_location["A.lua:5"][5])
        self.assertEqual(by_location["A.lua:6"][1], "problem")
        self.assertTrue(rows[-1][0].startswith("# source abc1234"))

    def test_paths_argument_checks_only_those_files(self):
        (self.root / "A.lua").write_text("C_Spell.Nope()\n", encoding="utf-8")
        (self.root / "B.lua").write_text("C_Spell.Nope2()\n", encoding="utf-8")
        code, out = self.run_main(*self.write_contracts(), "B.lua")
        self.assertEqual(out.splitlines(), ["B.lua:1: api: C_Spell has no member Nope2"])


DOC_SPELL = textwrap.dedent(
    """\
    local Spell =
    {
    \tName = "Spell",
    \tType = "System",
    \tNamespace = "C_Spell",
    \tEnvironment = "All",

    \tFunctions =
    \t{
    \t\t{
    \t\t\tName = "GetSpellInfo",
    \t\t\tType = "Function",
    \t\t\tSecretArguments = "AllowedWhenUntainted",
    \t\t\tHasRestrictions = true,
    \t\t\tSecretReturnsForAspect = { Enum.SecretAspect.ObjectSecurity },

    \t\t\tArguments =
    \t\t\t{
    \t\t\t\t{ Name = "spellIdentifier", Type = "SpellIdentifier", Nilable = false },
    \t\t\t\t{ Name = "extra", Type = "table", InnerType = "number", Nilable = true },
    \t\t\t},

    \t\t\tReturns =
    \t\t\t{
    \t\t\t\t{ Name = "info", Type = "SpellInfo", Nilable = true, NeverSecret = true },
    \t\t\t},
    \t\t},
    \t\t{
    \t\t\tName = "Hidden",
    \t\t\tType = "Function",
    \t\t\tEnvironment = "SecureOnly",
    \t\t},
    \t},

    \tEvents =
    \t{
    \t\t{
    \t\t\tName = "SpellDataLoadResult",
    \t\t\tType = "Event",
    \t\t\tLiteralName = "SPELL_DATA_LOAD_RESULT",
    \t\t\tSynchronousEvent = true,
    \t\t\tPayload =
    \t\t\t{
    \t\t\t\t{ Name = "spellID", Type = "number", Nilable = false },
    \t\t\t},
    \t\t},
    \t},

    \tTables =
    \t{
    \t\t{
    \t\t\tName = "SpellBank",
    \t\t\tType = "Enumeration",
    \t\t\tFields =
    \t\t\t{
    \t\t\t\t{ Name = "Player", Type = "SpellBank", EnumValue = 0 },
    \t\t\t\t{ Name = "Pet", Type = "SpellBank", EnumValue = 1 },
    \t\t\t},
    \t\t},
    \t\t{
    \t\t\tName = "SpellIDs",
    \t\t\tType = "Constants",
    \t\t\tValues =
    \t\t\t{
    \t\t\t\t{ Name = "DISMISS", Type = "number", Value = 2641 },
    \t\t\t},
    \t\t},
    \t},
    };

    APIDocumentation:AddDocumentationTable(Spell);
    """
)
DOC_SECURE = textwrap.dedent(
    """\
    local Secure =
    {
    \tName = "Secure",
    \tType = "System",
    \tNamespace = "C_Secure",
    \tEnvironment = "SecureOnly",
    \tFunctions =
    \t{
    \t\t{
    \t\t\tName = "Do",
    \t\t\tType = "Function",
    \t\t},
    \t},
    \tEvents = {},
    \tTables = {},
    };
    """
)


class GeneratorTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.source = Path(self._tmp.name) / "wow-ui-source"
        (self.source / DOCS).mkdir(parents=True)
        self.addon("Blizzard_APIDocumentationGenerated", ["SpellDocumentation.lua", "SecureDocumentation.lua"], {})
        (self.source / DOCS / "SpellDocumentation.lua").write_text(DOC_SPELL, encoding="utf-8")
        (self.source / DOCS / "SecureDocumentation.lua").write_text(DOC_SECURE, encoding="utf-8")

    def tearDown(self):
        self._tmp.cleanup()

    def addon(self, name, toc_lines, files, header=""):
        folder = self.source / ADDONS / name
        folder.mkdir(parents=True, exist_ok=True)
        (folder / f"{name}.toc").write_text(header + "\n".join(toc_lines) + "\n", encoding="utf-8")
        for rel, text in files.items():
            (folder / rel).parent.mkdir(parents=True, exist_ok=True)
            (folder / rel).write_text(textwrap.dedent(text), encoding="utf-8")

    def collect(self):
        return gen_api_contracts.collect(self.source)

    def test_documentation_gives_signatures_metadata_events_and_tables(self):
        data = self.collect()
        info = data["functions"]["C_Spell.GetSpellInfo"]
        self.assertEqual(info["args"], "spellIdentifier:SpellIdentifier, extra?:table<number>")
        self.assertEqual(info["returns"], "info?:SpellInfo!NeverSecret")
        self.assertEqual(info["meta"], {"SecretArguments": "AllowedWhenUntainted", "HasRestrictions": True, "SecretReturnsForAspect": ["Enum.SecretAspect.ObjectSecurity"]})
        self.assertEqual(info["at"], "Blizzard_APIDocumentationGenerated/SpellDocumentation.lua:10")
        self.assertNotIn("C_Spell.Hidden", data["functions"])
        self.assertEqual(data["secure_only"]["C_Spell.Hidden"], "Blizzard_APIDocumentationGenerated/SpellDocumentation.lua:28")
        self.assertIn("C_Secure.Do", data["secure_only"])
        self.assertNotIn("C_Secure", data["namespaces"] and {k for k in data["namespaces"] if k == "C_Secure" and "C_Secure.Do" in data["functions"]})
        self.assertEqual(data["events"]["SPELL_DATA_LOAD_RESULT"]["payload"], "spellID:number")
        self.assertEqual(data["enums"]["SpellBank"]["fields"], ["Player", "Pet"])
        self.assertEqual(data["constants"]["SpellIDs"]["values"], ["DISMISS"])

    def test_loaded_lua_adds_registrations_cvars_members_and_removals(self):
        self.addon(
            "Blizzard_Fixture",
            ["Fixture.lua", "Fixture.xml"],
            {
                "Fixture.lua": """
                    frame:RegisterEvent("FIXTURE_EVENT")
                    FrameUtil.RegisterFrameForEvents(frame, { "FIXTURE_LIST_A", "FIXTURE_LIST_B" })
                    local FIXTURE_EVENTS = { "FIXTURE_TABLE_EVENT" }
                    local ok = GetCVar("fixtureCVar")
                    Settings.SetupCVarCheckbox(category, "fixtureSetting", setting, label)
                    Enum.Fixture = { Alpha = 1, Beta = 2 }
                    Enum.Fixture.Gamma = 3
                    Enum.StoreError = nil
                    C_Fixture = { Run = function() end }
                    function C_Fixture.Walk() end
                    C_Fixture.Skip = nil
                    FixtureMixin = CreateFromMixins(Other)
                    function FixtureMixin:OnLoad() end
                    local LocalMixin = {}
                    local x = Enum.Seen.Member
                """,
                "Fixture.xml": """
                    <Ui>
                      <Frame name="FixtureTemplate" virtual="true"/>
                      <Frame name="FixtureFrame" inherits="FixtureTemplate"/>
                      <Font name="FixtureFont" virtual="true"/>
                      <Texture name="FixtureIntrinsic" intrinsic="true"/>
                    </Ui>
                """,
            },
        )
        data = self.collect()
        for name in ("FIXTURE_EVENT", "FIXTURE_LIST_A", "FIXTURE_LIST_B"):
            self.assertIn(name, data["events"])
        self.assertEqual(data["events"]["FIXTURE_EVENT"]["at"], "Blizzard_Fixture/Fixture.lua:2")
        self.assertEqual(data["cvars"]["fixturecvar"]["name"], "fixtureCVar")
        self.assertIn("fixturesetting", data["cvars"])
        self.assertEqual(data["enums"]["Fixture"]["fields"], ["Alpha", "Beta", "Gamma"])
        self.assertEqual(data["enums"]["Seen"], {"at": data["enums"]["Seen"]["at"], "fields": ["Member"], "via": "use"})
        self.assertIn("Enum.StoreError", data["removed"])
        self.assertEqual(sorted(k for k in data["functions"] if k.startswith("C_Fixture")), ["C_Fixture.Run", "C_Fixture.Walk"])
        self.assertIn("C_Fixture.Skip", data["removed"])
        self.assertEqual(sorted(data["templates"]), ["FixtureFont", "FixtureIntrinsic", "FixtureTemplate"])
        self.assertEqual(data["mixins"]["FixtureMixin"]["at"], "Blizzard_Fixture/Fixture.lua:13")
        self.assertNotIn("LocalMixin", data["mixins"])

    def test_secure_environment_files_define_nothing_addons_can_reach(self):
        lua = "C_Hidden = { Run = function() end }\nC_Spell.Extra = function() end\nHiddenMixin = {}\nframe:RegisterEvent('SECURE_ONLY_EVENT')\nGetCVar('secureCVar')\n"
        self.addon("Blizzard_Secure", ["Secure.lua"], {"Secure.lua": lua}, header="## UseSecureEnvironment: 1\n")
        data = self.collect()
        self.assertNotIn("C_Hidden", data["namespaces"])
        self.assertNotIn("C_Spell.Extra", data["functions"])
        self.assertNotIn("HiddenMixin", data["mixins"])
        self.assertIn("SECURE_ONLY_EVENT", data["events"])
        self.assertIn("securecvar", data["cvars"])

    def test_secure_environment_reads_do_not_prove_addon_api_visibility(self):
        lua = "C_Hidden = { Run = function() end }\nC_Hidden.Run()\nEnum.Hidden = { Value = 1 }\nlocal value = Enum.Hidden.Value\n"
        self.addon("Blizzard_Secure", ["Secure.lua"], {"Secure.lua": lua}, header="## UseSecureEnvironment: 1\n")
        data = self.collect()
        self.assertNotIn("C_Hidden", data["namespaces"])
        self.assertNotIn("C_Hidden.Run", data["functions"])
        self.assertNotIn("Hidden", data["enums"])

    def test_source_lua_cannot_bring_back_a_secure_only_member(self):
        self.addon("Blizzard_Fixture", ["Fixture.lua"], {"Fixture.lua": "function C_Spell.Hidden() end\nlocal x = C_Spell.Hidden\nC_Secure.Back = 1\n"})
        data = self.collect()
        self.assertNotIn("C_Spell.Hidden", data["functions"])
        self.assertNotIn("C_Secure.Back", data["functions"])
        self.assertTrue(data["namespaces"]["C_Secure"]["secure"])

    def test_guard_rejects_a_secure_only_member_even_if_a_function_entry_exists(self):
        data = json.loads(json.dumps(FIXTURE))
        data["functions"]["C_Secure.Do"] = {"at": "0:1"}
        data["namespaces"]["C_Open"] = {"at": "0:1", "system": "Open"}
        data["secure_only"]["C_Open.Do"] = "0:2"
        data["functions"]["C_Open.Do"] = {"at": "0:3"}
        addon = Path(self._tmp.name) / "addon2"
        addon.mkdir()
        (addon / "A.lua").write_text("C_Open.Do()\n", encoding="utf-8")
        (addon / "Test.toc").write_text("A.lua\n", encoding="utf-8")
        found = check_api_contracts.check(addon, check_api_contracts.Contracts(data, GLOBALS))
        self.assertEqual([r.status for r in found], ["problem"])

    def test_event_named_tables_that_are_lookups_are_not_events(self):
        self.addon("Blizzard_Fixture", ["Fixture.lua"], {"Fixture.lua": "local WORD_EVENTS = { MISS = true }\nlocal LIST_EVENTS = { 'REAL_LIST_EVENT' }\n"})
        data = self.collect()
        self.assertNotIn("MISS", data["events"])
        self.assertIn("REAL_LIST_EVENT", data["events"])

    def test_deprecated_and_not_loaded_code_is_not_trusted(self):
        shim = {"Shim.lua": 'frame:RegisterEvent("SHIM_EVENT")\nGetCVar("shimCVar")\nC_Shim.Thing()\n'}
        self.addon("Blizzard_DeprecatedThing", ["Shim.lua"], shim)
        self.addon("Deprecated_PaperDoll", ["Shim.lua"], shim)
        self.addon("Blizzard_Classic", ["Shim.lua"], shim, header="## AllowLoadGameType: classic\n")
        self.addon("Blizzard_Mixed", ["Main.lua", "Other.lua [AllowLoadGameType classic]"], {"Main.lua": "x = 1\n", "Other.lua": 'frame:RegisterEvent("OTHER_EVENT")\n'})
        data = self.collect()
        for name in ("SHIM_EVENT", "OTHER_EVENT"):
            self.assertNotIn(name, data["events"])
        self.assertNotIn("shimcvar", data["cvars"])
        self.assertNotIn("C_Shim", data["namespaces"])
        self.assertEqual(data["addons"]["Blizzard_DeprecatedThing"], "deprecated")
        self.assertEqual(data["addons"]["Deprecated_PaperDoll"], "deprecated")
        self.assertEqual(data["addons"]["Blizzard_Classic"], "not loaded")
        self.assertEqual(data["addons"]["Blizzard_Mixed"], "loaded")

    def test_render_is_stable_one_entry_per_line_and_indexes_files(self):
        data = self.collect()
        text = gen_api_contracts.render(data, "abc1234", "subject")
        self.assertEqual(text, gen_api_contracts.render(self.collect(), "abc1234", "subject"))
        parsed = json.loads(text)
        self.assertEqual(parsed["source"]["commit"], "abc1234")
        self.assertEqual(parsed["counts"]["functions"], len(data["functions"]))
        contracts_ = check_api_contracts.Contracts(parsed)
        self.assertEqual(contracts_.where(parsed["functions"]["C_Spell.GetSpellInfo"]), "Blizzard_APIDocumentationGenerated/SpellDocumentation.lua:10")
        self.assertIn('\n"C_Spell.GetSpellInfo": {', text)

    def test_end_to_end_guard_on_generated_contracts(self):
        text = gen_api_contracts.render(self.collect(), "abc1234", "subject")
        addon = Path(self._tmp.name) / "addon"
        addon.mkdir()
        (addon / "Test.toc").write_text("Main.lua\n", encoding="utf-8")
        (addon / "Main.lua").write_text("C_Spell.GetSpellInfo(1)\nC_Spell.Nope()\nframe:RegisterEvent('SPELL_DATA_LOAD_RESULT')\nframe:RegisterEvent('NOPE')\nlocal b = Enum.SpellBank.Pet\nlocal c = Enum.SpellBank.Nope\n", encoding="utf-8")
        contracts_path = Path(self._tmp.name) / "contracts.json"
        contracts_path.write_text(text, encoding="utf-8")
        found = check_api_contracts.check(addon, check_api_contracts.load_contracts(contracts_path, Path(self._tmp.name) / "none.lua"))
        self.assertEqual(sorted(r.use.line for r in found if r.status == "problem"), [2, 4, 6])

    def test_client_binary_proves_only_cvars_the_addon_names_and_source_lacks(self):
        (self.source / "version.txt").write_text("1.0.0.7\n", encoding="utf-8")
        self.addon("Blizzard_Fixture", ["Fixture.lua"], {"Fixture.lua": "GetCVar('fromSource')\n"})
        addon = Path(self._tmp.name) / "addon"
        addon.mkdir()
        (addon / "Test.toc").write_text("Main.lua\n", encoding="utf-8")
        (addon / "Main.lua").write_text("GetCVar('fromSource')\nGetCVar('inBinary')\nGetCVar('absent')\nGetCVar('inbinary2')\n", encoding="utf-8")
        binary = Path(self._tmp.name) / "client"
        binary.write_bytes(b"\0inBinary\0prefixabsent\0unrelatedInBinary2\0fromSource\0")
        data = self.collect()
        client = gen_api_contracts.prove_cvars_in_client(data, binary, "1.0.0.7", self.source, addon)
        self.assertEqual(client["build"], "1.0.0.7")
        self.assertEqual(len(client["sha256"]), 64)
        self.assertEqual(data["cvars"]["inbinary"], {"name": "inBinary", "offset": 1, "via": "client binary"})
        self.assertEqual(data["cvars"]["fromsource"]["via"], "GetCVar")
        self.assertNotIn("absent", data["cvars"])
        self.assertNotIn("inbinary2", data["cvars"])
        with self.assertRaises(ValueError):
            gen_api_contracts.prove_cvars_in_client(data, binary, "1.0.0.8", self.source, addon)

    def test_main_requires_matching_client_options(self):
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            code = gen_api_contracts.main(["--source", str(self.source), "--client-binary", "x"])
        self.assertEqual(code, 1)
        self.assertIn("go together", err.getvalue())


class CommittedContractsTest(unittest.TestCase):
    def test_header_and_size(self):
        path = REPO / "Tools" / "data" / "forever_api_contracts.json"
        self.assertLess(path.stat().st_size, 2 * 1024 * 1024)
        data = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(data["schema"], gen_api_contracts.SCHEMA)
        self.assertRegex(data["source"]["commit"], r"^[0-9a-f]{7,}$")
        for section in ("functions", "events", "cvars", "templates", "enums", "constants", "mixins", "addons", "namespaces"):
            self.assertGreater(len(data[section]), 0, section)
        self.assertEqual(data["counts"]["functions"], len(data["functions"]))
        for entry in list(data["functions"].values())[:50]:
            self.assertLess(int(entry["at"].split(":")[0]), len(data["files"]))

    def test_addon_code_conforms(self):
        results = check_api_contracts.check(REPO, check_api_contracts.load_contracts())
        problems = [f"{r.path}:{r.use.line}: {r.message}" for r in results if r.status == "problem"]
        self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
