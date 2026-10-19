#!/usr/bin/env python3
##
## AgentsArtifactHtml.py -- the HTML side of --intern-artifact-publish
## (AgentsTools.InternArtifact.include): one HTML document and the files given beside it,
## rewritten for the backend it is published to.
##
## WHY PYTHON: rewriting references and closing what HTML leaves open needs a real
## tokeniser, and Confluence takes only well-formed XHTML. The stdlib html.parser does
## the tokenising, so no dependency is added.
##
## Usage: AgentsArtifactHtml.py <mode> <arguments>
##   scan <google|confluence> <html-file>  one line per given file: "<name> TAB img|link|both|none".
##                                       Refuses a document the backend cannot carry whole.
##   google <html-file>                  a whole HTML document for the Drive import: images
##                                       inline as data: URIs, links to given files pointed at
##                                       their uploads (ARTIFACT_LINKS).
##   confluence <html-file>              a storage-format (XHTML) body: images and links to
##                                       given files as attachments of the page.
##   confluence-file <file>              the storage body of a page holding one plain file.
##   confluence-index <title>            the index page body on stdin, with a link to the
##                                       child page <title> listed once.
## Environment: ARTIFACT_FILES  the given files, one absolute path per line.
##              ARTIFACT_LINKS  google only: "<name> TAB <url>" per uploaded file.
## A local reference is matched to a given file by its base name. A link to a local file
## that was not given keeps its text, followed by the reference in brackets.
## Exit: 0 written; 1 usage; 2 refused, the reason on stderr.
##

import base64
import html
import mimetypes
import os
import sys
import urllib.parse
from html.parser import HTMLParser

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}
DROPPED_VOID = {"base", "link", "meta"}
DROPPED_CONTENT = {"script", "style", "title", "template"}
UNWRAPPED = {"html", "head", "body"}
CLOSES_P = {"address", "article", "aside", "blockquote", "details", "div", "dl", "fieldset", "figcaption",
            "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr", "main", "nav",
            "ol", "p", "pre", "section", "table", "ul"}
P_BARRIERS = {"blockquote", "dd", "div", "dt", "li", "td", "th", "table", "ul", "ol", "section", "article",
              "figure", "button", "object"}


def refuse(message):
    sys.stderr.write("🙋 WARNING: AgentsArtifactHtml.py: %s\n" % message)
    sys.exit(2)


def usage(message):
    sys.stderr.write("⛔ ERROR: AgentsArtifactHtml.py: %s\n" % message)
    sys.exit(1)


def attr_escape(value):
    return html.escape(value, quote=True)


def given_files():
    files = {}
    for line in os.environ.get("ARTIFACT_FILES", "").split("\n"):
        if line:
            files[os.path.basename(line)] = line
    return files


def given_links():
    links = {}
    for line in os.environ.get("ARTIFACT_LINKS", "").split("\n"):
        if "\t" in line:
            name, url = line.split("\t", 1)
            links[name] = url
    return links


def is_image(name):
    kind = mimetypes.guess_type(name)[0] or ""
    return kind.startswith("image/")


def reference_kind(value):
    """external, anchor, data, empty or local -- and the local base name."""
    value = (value or "").strip()
    if not value:
        return "empty", ""
    if value.startswith("#"):
        return "anchor", ""
    parts = urllib.parse.urlsplit(value)
    if parts.scheme == "data":
        return "data", ""
    if parts.scheme or parts.netloc:
        return "external", ""
    return "local", os.path.basename(urllib.parse.unquote(parts.path))


def read_text(path):
    try:
        with open(path, "rb") as handle:
            return handle.read().decode("utf-8", errors="replace")
    except OSError as error:
        usage("cannot read %s: %s" % (path, error))


class ArtifactWriter(HTMLParser):
    """One pass over the document; with emit off it only records what is referenced."""

    def __init__(self, mode, files, links):
        HTMLParser.__init__(self, convert_charrefs=True)
        self.mode = mode
        self.files = files
        self.links = links
        self.out = []
        self.stack = []
        self.drop = 0
        self.uses = {}
        self.missing_images = []
        self.missing_links = []
        self.data_images = 0

    def note(self, name, use):
        before = self.uses.get(name, "none")
        self.uses[name] = use if before in ("none", use) else "both"

    def close_to(self, tag):
        while self.stack:
            entry = self.stack.pop()
            self.out.append(entry[1])
            if entry[0] == tag:
                return

    def open_above(self, tag, barriers):
        for entry in reversed(self.stack):
            if entry[0] == tag:
                return True
            if entry[0] in barriers:
                return False
        return False

    def implied_closes(self, tag):
        if tag == "li" and self.open_above("li", {"ul", "ol"}):
            self.close_to("li")
        elif tag in ("dt", "dd"):
            for other in ("dt", "dd"):
                if self.open_above(other, {"dl"}):
                    self.close_to(other)
        elif tag == "tr" and self.open_above("tr", {"table", "thead", "tbody", "tfoot"}):
            self.close_to("tr")
        elif tag in ("td", "th"):
            for other in ("td", "th"):
                if self.open_above(other, {"tr", "table"}):
                    self.close_to(other)
        elif tag in ("thead", "tbody", "tfoot"):
            for other in ("thead", "tbody", "tfoot"):
                if self.open_above(other, {"table"}):
                    self.close_to(other)
        if tag in CLOSES_P and self.open_above("p", P_BARRIERS):
            self.close_to("p")

    def attributes(self, attrs, skip):
        text = ""
        for name, value in attrs:
            if name in skip or name.startswith("on") or not name.replace("-", "").replace("_", "").isalnum():
                continue
            text += ' %s="%s"' % (name, attr_escape(name if value is None else value))
        return text

    def image(self, attrs):
        values = dict(attrs)
        kind, name = reference_kind(values.get("src"))
        if kind == "local":
            if name not in self.files:
                self.missing_images.append(values.get("src") or "")
                return
            self.note(name, "img")
        elif kind == "data":
            self.data_images += 1
        if self.mode == "confluence":
            extra = ""
            for source, target in (("alt", "ac:alt"), ("title", "ac:title"), ("width", "ac:width"), ("height", "ac:height")):
                if values.get(source):
                    extra += ' %s="%s"' % (target, attr_escape(values[source]))
            if kind == "local":
                self.out.append('<ac:image%s><ri:attachment ri:filename="%s"/></ac:image>' % (extra, attr_escape(name)))
            elif kind == "external":
                self.out.append('<ac:image%s><ri:url ri:value="%s"/></ac:image>' % (extra, attr_escape(values["src"].strip())))
        elif self.mode == "google":
            if kind == "local":
                with open(self.files[name], "rb") as handle:
                    encoded = base64.b64encode(handle.read()).decode("ascii")
                source = "data:%s;base64,%s" % (mimetypes.guess_type(name)[0] or "application/octet-stream", encoded)
                self.out.append('<img src="%s"%s/>' % (source, self.attributes(attrs, {"src"})))
            elif kind in ("external", "data"):
                self.out.append("<img%s/>" % self.attributes(attrs, set()))

    def anchor(self, attrs):
        values = dict(attrs)
        kind, name = reference_kind(values.get("href"))
        if kind == "local":
            if name in self.files:
                self.note(name, "link")
                if self.mode == "confluence":
                    self.out.append('<ac:link><ri:attachment ri:filename="%s"/><ac:link-body>' % attr_escape(name))
                    self.stack.append(("a", "</ac:link-body></ac:link>"))
                    return
                if self.mode == "google" and name in self.links:
                    self.out.append('<a href="%s"%s>' % (attr_escape(self.links[name]), self.attributes(attrs, {"href"})))
                    self.stack.append(("a", "</a>"))
                    return
            else:
                self.missing_links.append(values.get("href") or "")
            ## Not published beside it: the text stays, and says where it pointed.
            self.stack.append(("a", " (%s)" % html.escape(values.get("href") or "", quote=False)))
            return
        self.out.append("<a%s>" % self.attributes(attrs, set()))
        self.stack.append(("a", "</a>"))

    def handle_starttag(self, tag, attrs):
        if self.drop:
            if tag in DROPPED_CONTENT:
                self.drop += 1
            return
        if tag in DROPPED_CONTENT:
            self.drop = 1
            return
        if tag in UNWRAPPED or tag in DROPPED_VOID:
            return
        self.implied_closes(tag)
        if tag == "img":
            self.image(attrs)
            return
        if tag == "a":
            if self.open_above("a", set()):
                self.close_to("a")
            self.anchor(attrs)
            return
        if tag in VOID:
            self.out.append("<%s%s/>" % (tag, self.attributes(attrs, set())))
            return
        self.out.append("<%s%s>" % (tag, self.attributes(attrs, set())))
        self.stack.append((tag, "</%s>" % tag))

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID and tag not in DROPPED_CONTENT and tag not in UNWRAPPED:
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        if self.drop:
            if tag in DROPPED_CONTENT:
                self.drop -= 1
            return
        if tag in UNWRAPPED or tag in VOID:
            return
        if any(entry[0] == tag for entry in self.stack):
            self.close_to(tag)

    def handle_data(self, data):
        if not self.drop:
            self.out.append(html.escape(data, quote=False))

    def finish(self):
        self.close()
        while self.stack:
            self.out.append(self.stack.pop()[1])
        return "".join(self.out)


def run_document(mode, path):
    writer = ArtifactWriter(mode, given_files(), given_links())
    writer.feed(read_text(path))
    return writer, writer.finish()


def main():
    if len(sys.argv) < 3:
        usage("syntax is <mode> <arguments> -- see this file's header")
    mode = sys.argv[1]
    if mode == "scan":
        if len(sys.argv) != 4 or sys.argv[2] not in ("google", "confluence"):
            usage("syntax is scan <google|confluence> <html-file>")
        writer, _ = run_document("scan", sys.argv[3])
        if writer.missing_images:
            refuse("the document shows images that are not among the given files: %s -- give each one in files, "
                   "or point it at an http or https URL. Nothing was published" % ", ".join(writer.missing_images))
        if sys.argv[2] == "confluence" and writer.data_images:
            refuse("the document holds %d image(s) written inline as data: URIs, which a Confluence page cannot "
                   "carry -- give each image as a file instead. Nothing was published" % writer.data_images)
        for name in writer.missing_links:
            sys.stderr.write("# AgentsArtifactHtml.py: a link to %s, which is not among the given files, is "
                             "published as its text followed by the reference\n" % name)
        for name in given_files():
            sys.stdout.write("%s\t%s\n" % (name, writer.uses.get(name, "none")))
        return
    if mode == "google":
        _, body = run_document("google", sys.argv[2])
        sys.stdout.write('<!DOCTYPE html>\n<html><head><meta charset="utf-8"/></head><body>%s</body></html>\n' % body)
        return
    if mode == "confluence":
        _, body = run_document("confluence", sys.argv[2])
        sys.stdout.write(body)
        return
    if mode == "confluence-file":
        name = os.path.basename(sys.argv[2])
        if is_image(name):
            sys.stdout.write('<p><ac:image><ri:attachment ri:filename="%s"/></ac:image></p>' % attr_escape(name))
        else:
            sys.stdout.write('<p><ac:link><ri:attachment ri:filename="%s"/></ac:link></p>' % attr_escape(name))
        return
    if mode == "confluence-index":
        body = sys.stdin.read()
        entry = '<li><ac:link><ri:page ri:content-title="%s"/></ac:link></li>' % attr_escape(sys.argv[2])
        if ('ri:content-title="%s"' % attr_escape(sys.argv[2])) in body:
            sys.stdout.write(body)
        elif "</ul>" in body:
            cut = body.rindex("</ul>")
            sys.stdout.write(body[:cut] + entry + body[cut:])
        else:
            sys.stdout.write(body + "<ul>" + entry + "</ul>")
        return
    usage("unknown mode: %s" % mode)


if __name__ == "__main__":
    main()
