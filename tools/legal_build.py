#!/usr/bin/env python3
"""Render legal/*.md (+ legal/placeholders.json) into
  assets/legal/<doc>.<lang>.md          bundled in the APK, read offline in-app
  docs/legal/privacy.html, terms.html   GitHub Pages, ES/EN switch
  docs/delete-account.html              = {{URL_ELIMINAR_CUENTA}}
Fails when a {{PLACEHOLDER}} has no value or a [[VERIFICAR/VERIFY/DECIDIR/DECIDE: ...]]
marker is left, unless --draft (then it renders anyway; never publish a draft).
`hub.py check` calls build(write=False). Spanish controls; English is a courtesy copy.
"""
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "legal"
OUT_MD = ROOT / "assets" / "legal"
OUT_DOCS = ROOT / "docs"
LANGS = ("es", "en")
DOCS = {"privacy": "privacy_policy", "terms": "terms_eula"}
TITLES = {
    "privacy": "Política de Privacidad / Privacy Policy",
    "terms": "Términos y EULA / Terms and EULA",
}
TEAM_NOTE = re.compile(r"^>\s*(NOTA PARA EL EQUIPO|TEAM NOTE)")
PLACEHOLDER = re.compile(r"\{\{([A-Z_]+)\}\}")
MARKER = re.compile(r"\[\[(VERIFICAR|VERIFY|DECIDIR|DECIDE)[^\]]*\]\]")


def strip_team_notes(text: str) -> str:
    out = []
    for line in text.split("\n"):
        if TEAM_NOTE.match(line):
            while out and out[-1].strip() == ">":
                out.pop()
            continue
        out.append(line)
    return "\n".join(out)


def load_values(lang: str) -> dict:
    data = json.loads((SRC / "placeholders.json").read_text(encoding="utf-8"))
    values = dict(data["common"])
    values.update(data.get(lang, {}))
    return values


def problems(doc: str, lang: str, text: str, values: dict) -> list[str]:
    errs = []
    for name in sorted(set(PLACEHOLDER.findall(text))):
        if not str(values.get(name, "")).strip():
            errs.append("%s.%s: {{%s}} has no value in legal/placeholders.json" % (doc, lang, name))
    for m in MARKER.finditer(text):
        errs.append("%s.%s: unresolved %s" % (doc, lang, m.group(0)[:100]))
    return errs


def fill(text: str, values: dict) -> str:
    return PLACEHOLDER.sub(lambda m: str(values.get(m.group(1), m.group(0))), text)


def inline(s: str) -> str:
    s = html.escape(s, quote=False)
    s = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", r'<a href="\2">\1</a>', s)
    s = re.sub(r"(?<![\"=>])(https?://[^\s<)]+)", r'<a href="\1">\1</a>', s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)", r"<em>\1</em>", s)
    return s


def md_to_html(md: str) -> str:
    out = []
    state = {"para": [], "items": [], "quote": []}

    def flush():
        if state["para"]:
            out.append("<p>" + inline(" ".join(state["para"])) + "</p>")
        if state["items"]:
            tag = state["items"][0][0]
            out.append("<%s>%s</%s>" % (tag, "".join("<li>%s</li>" % inline(t) for _, t in state["items"]), tag))
        if state["quote"]:
            out.append("<blockquote>" + inline(" ".join(state["quote"])) + "</blockquote>")
        state["para"], state["items"], state["quote"] = [], [], []

    for line in md.split("\n"):
        s = line.rstrip()
        if not s.strip():
            flush()
        elif s.startswith("#"):
            flush()
            n = len(s) - len(s.lstrip("#"))
            out.append("<h%d>%s</h%d>" % (n, inline(s[n:].strip()), n))
        elif re.match(r"^\s*[-*]\s+", s) or re.match(r"^\s*\d+\.\s+", s):
            tag = "ul" if re.match(r"^\s*[-*]\s+", s) else "ol"
            if state["para"] or state["quote"] or (state["items"] and state["items"][0][0] != tag):
                flush()
            state["items"].append((tag, re.sub(r"^\s*([-*]|\d+\.)\s+", "", s)))
        elif s.startswith(">"):
            if state["para"] or state["items"]:
                flush()
            state["quote"].append(s[1:].strip())
        else:
            if state["items"] or state["quote"]:
                flush()
            state["para"].append(s.strip())
    flush()
    return "\n".join(out)


PAGE = """<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>__TITLE__ - Viral Game Hub</title>
<style>
:root{--bg:#0b0f1a;--fg:#e8ecf5;--mut:#9aa6c0;--acc:#4da3ff;--line:#243049}
@media (prefers-color-scheme:light){:root{--bg:#fff;--fg:#14202e;--mut:#4a5870;--acc:#0b5fc0;--line:#d6deea}}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.6 system-ui,sans-serif}
main{max-width:760px;margin:0 auto;padding:16px}
a{color:var(--acc)} h1{font-size:1.6rem} h2{margin-top:1.8em;font-size:1.2rem}
blockquote{margin:1em 0;padding:.2em 1em;border-left:3px solid var(--acc);color:var(--mut)}
nav{display:flex;gap:12px;justify-content:flex-end}
footer{margin-top:3em;padding-top:1em;border-top:1px solid var(--line);color:var(--mut);font-size:.9rem}
.lang{display:none} .lang.on{display:block}
</style></head><body><main>
<nav><a href="#es" onclick="L('es')">Español</a><a href="#en" onclick="L('en')">English</a></nav>
__SECTIONS__
<script>
function L(l){document.querySelectorAll('.lang').forEach(function(e){e.classList.toggle('on',e.id===l)});document.documentElement.lang=l}
var h=location.hash.slice(1);L(h==='en'?'en':(h==='es'?'es':((navigator.language||'es').slice(0,2)==='en'?'en':'es')));
</script></main></body></html>
"""


def footer(values: dict, lang: str) -> str:
    mail = '<a href="mailto:%s">%s</a>' % (values["EMAIL_CONTACTO"], values["EMAIL_CONTACTO"])
    gov = values["URL_DEFENSA_CONSUMIDOR"]
    delete = values["URL_ELIMINAR_CUENTA"]
    if lang == "es":
        return '<footer>Contacto: %s · <a href="%s">Defensa del Consumidor</a> · <a href="%s">Eliminar mi cuenta</a></footer>' % (mail, gov, delete)
    return '<footer>Contact: %s · <a href="%s">Consumer protection (Argentina)</a> · <a href="%s">Delete my account</a></footer>' % (mail, gov, delete)


DELETE_BODY = {
    "es": """# Eliminar mi cuenta de Viral Game Hub

## Dentro de la app
1. Abrí Viral Game Hub e iniciá sesión.
2. Tocá 👤 Perfil y bajá hasta "Zona de riesgo".
3. Tocá "Eliminar mi cuenta" y confirmá.

Se borran tu perfil, amigos, puntajes, logros, tiempo de juego y consentimientos, y tu usuario de acceso. La eliminación es inmediata y no se puede deshacer.

## Por correo
Si no podés entrar a la app, escribinos a %(EMAIL_PRIVACIDAD)s desde el correo de tu cuenta con el asunto "Eliminar mi cuenta". Eliminamos tus datos personales dentro de los %(DIAS_BORRADO)s días.

## Qué conservamos
Solo los registros de compras que debamos guardar por obligaciones contables o fiscales, y copias de seguridad que se sobrescriben en su ciclo normal. Más detalle en la [Política de Privacidad](legal/privacy.html#es).
""",
    "en": """# Delete my Viral Game Hub account

## In the app
1. Open Viral Game Hub and sign in.
2. Tap 👤 Profile and scroll to "Danger zone".
3. Tap "Delete my account" and confirm.

Your profile, friends, scores, achievements, play time, consents and sign-in user are deleted. Deletion is immediate and cannot be undone.

## By email
If you cannot open the app, write to %(EMAIL_PRIVACIDAD)s from your account's email address with the subject "Delete my account". We delete your personal data within %(DIAS_BORRADO)s days.

## What we keep
Only purchase records we must keep for accounting or tax obligations, and backups that are overwritten in their normal cycle. More detail in the [Privacy Policy](legal/privacy.html#en).
""",
}


def page(title: str, sections: str) -> str:
    return PAGE.replace("__TITLE__", title).replace("__SECTIONS__", sections)


def build(draft: bool = False, write: bool = True) -> list[str]:
    errors = []
    rendered = {}
    for key, stem in DOCS.items():
        for lang in LANGS:
            src = SRC / ("%s.%s.md" % (stem, lang))
            if not src.is_file():
                errors.append("missing " + str(src.relative_to(ROOT)))
                continue
            text = strip_team_notes(src.read_text(encoding="utf-8"))
            values = load_values(lang)
            errors += problems(key, lang, text, values)
            rendered[(key, lang)] = fill(text, values)
    if (errors and not draft) or not write:
        return errors
    OUT_MD.mkdir(parents=True, exist_ok=True)
    (OUT_DOCS / "legal").mkdir(parents=True, exist_ok=True)
    for (key, lang), text in rendered.items():
        (OUT_MD / ("%s.%s.md" % (DOCS[key], lang))).write_text(text, encoding="utf-8", newline="\n")
    for key in DOCS:
        secs = "".join(
            '<section class="lang" id="%s">%s%s</section>' % (lang, md_to_html(rendered[(key, lang)]), footer(load_values(lang), lang))
            for lang in LANGS if (key, lang) in rendered)
        (OUT_DOCS / "legal" / (key + ".html")).write_text(page(TITLES[key], secs), encoding="utf-8", newline="\n")
    secs = ""
    for lang in LANGS:
        v = load_values(lang)
        secs += '<section class="lang" id="%s">%s%s</section>' % (lang, md_to_html(DELETE_BODY[lang] % v), footer(v, lang))
    (OUT_DOCS / "delete-account.html").write_text(
        page("Eliminar cuenta / Delete account", secs), encoding="utf-8", newline="\n")
    return errors


def main() -> int:
    draft = "--draft" in sys.argv
    errors = build(draft=draft)
    for e in errors:
        print(("WARN: " if draft else "ERROR: ") + e)
    if errors and not draft:
        print("%d problem(s): fix them (or --draft to render anyway; never publish a draft)." % len(errors))
        return 1
    print("legal rendered" + (" (DRAFT: not publishable)" if errors else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
