import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

const HIGHLIGHT_BUTTON_TITLE_KEY = "random_highlights.mark_button_title";
const HIGHLIGHT_BUTTON_TITLE_FALLBACK = "Mark highlight";
const HIGHLIGHT_WRAP_NAME = "random-highlight";
const HIGHLIGHT_WRAP_HEAD = `[wrap=${HIGHLIGHT_WRAP_NAME}]`;
const HIGHLIGHT_WRAP_TAIL = "[/wrap]";
const HIGHLIGHT_WRAP_SELECTOR = `[data-wrap="${HIGHLIGHT_WRAP_NAME}"]`;
const HIGHLIGHT_DECORATED_CLASS = "random-highlight-group--decorated";
const HIGHLIGHT_MARK_CLASS = "random-highlight-group-mark";
const HIGHLIGHT_DECORATION_EXCLUSIONS = "mark, pre, code, script, style, textarea, svg, math, button";
const MARKDOWN_BLOCK_PREFIX = /^(?: {0,3}#{1,6}(?:\s|$)| {0,3}(?:[-+*]|\d+[.)])\s+| {0,3}>\s?| {0,3}(?:```|~~~)| {0,3}(?:[-*_]\s*){3,})/;

function parseIdList(value) {
  return String(value || "")
    .split(/[,|\s]+/)
    .map((item) => Number(String(item).trim()))
    .filter((item) => Number.isFinite(item) && item > 0);
}

function numberSetting(value, fallback, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, number));
}

function booleanSetting(value, fallback) {
  if (value === true || value === false) return value;
  const normalized = String(value ?? "").trim().toLowerCase();
  if (["true", "1", "yes", "on"].includes(normalized)) return true;
  if (["false", "0", "no", "off"].includes(normalized)) return false;
  return fallback;
}

const SHOW_COMPOSER_BUTTON = booleanSetting(settings.show_composer_button, true);
const COMPOSER_MIN_TRUST_LEVEL = numberSetting(settings.composer_min_trust_level, 0, 0, 4);

function blockSelection(selected) {
  const value = String(selected?.value || "");
  if (value.includes("\n")) return true;

  const startsAtLineBoundary = !selected?.pre || selected.pre.endsWith("\n");
  const endsAtLineBoundary = !selected?.post || selected.post.startsWith("\n");
  return startsAtLineBoundary && endsAtLineBoundary && MARKDOWN_BLOCK_PREFIX.test(value);
}

function applyHighlightWrap(event) {
  const value = String(event.selected?.value || "");
  if (blockSelection(event.selected)) {
    const head = HIGHLIGHT_WRAP_HEAD + (value.startsWith("\n") ? "" : "\n");
    const tail = (value.endsWith("\n") ? "" : "\n") + HIGHLIGHT_WRAP_TAIL;
    event.applySurround(head, tail, "random_highlight_text", {
      multiline: false
    });
    return;
  }

  event.applySurround(HIGHLIGHT_WRAP_HEAD, HIGHLIGHT_WRAP_TAIL, "random_highlight_text", {
    multiline: false
  });
}

function decorateHighlightGroup(group) {
  if (group.classList.contains(HIGHLIGHT_DECORATED_CLASS)) return;
  group.classList.add(HIGHLIGHT_DECORATED_CLASS);

  const ownerDocument = group.ownerDocument;
  const textNodes = [];
  const walker = ownerDocument.createTreeWalker(group, NodeFilter.SHOW_TEXT);
  let node = walker.nextNode();

  while (node) {
    const parent = node.parentElement;
    if (
      node.textContent?.trim() &&
      parent &&
      !parent.closest(HIGHLIGHT_DECORATION_EXCLUSIONS)
    ) {
      textNodes.push(node);
    }
    node = walker.nextNode();
  }

  textNodes.forEach((textNode) => {
    const mark = ownerDocument.createElement("mark");
    mark.className = HIGHLIGHT_MARK_CLASS;
    textNode.replaceWith(mark);
    mark.appendChild(textNode);
  });
}

export default apiInitializer((api) => {
  function currentUserAllowedForComposer() {
    if (!SHOW_COMPOSER_BUTTON) return false;
    const currentUser = api.getCurrentUser();
    if (!currentUser) return false;
    const allowedIds = parseIdList(settings.composer_allowed_user_ids);
    if (allowedIds.length && !allowedIds.includes(Number(currentUser.id))) return false;
    return Number(currentUser.trust_level || 0) >= COMPOSER_MIN_TRUST_LEVEL;
  }

  api.onToolbarCreate((toolbar) => {
    toolbar.addButton({
      id: "random-highlight-mark",
      group: "fontStyles",
      icon: "highlighter",
      title: HIGHLIGHT_BUTTON_TITLE_KEY,
      condition: currentUserAllowedForComposer,
      perform: applyHighlightWrap
    });

    const markButton = toolbar.groups
      .find((item) => item.group === "fontStyles")
      ?.buttons.find((button) => button.id === "random-highlight-mark");
    if (markButton) {
      markButton.title = i18n(HIGHLIGHT_BUTTON_TITLE_KEY, {
        defaultValue: HIGHLIGHT_BUTTON_TITLE_FALLBACK
      });
    }
  });

  api.decorateCookedElement((element) => {
    element.querySelectorAll(HIGHLIGHT_WRAP_SELECTOR).forEach(decorateHighlightGroup);
  });
});
