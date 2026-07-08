import { apiInitializer } from "discourse/lib/api";

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
      title: "random_highlights.mark_button_title",
      condition: currentUserAllowedForComposer,
      perform: (event) =>
        event.applySurround("<mark>", "</mark>", "random_highlight_text", {
          multiline: false
        })
    });
  });
});
