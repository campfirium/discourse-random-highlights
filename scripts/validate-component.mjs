#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const root = process.cwd();
const failures = [];
const readCache = new Map();
const SUPPORTED_THEME_SETTING_TYPES = new Set([
  "integer",
  "float",
  "string",
  "bool",
  "list",
  "enum",
  "upload",
  "objects"
]);
const EXPECTED_REPOSITORY_URL = "https://github.com/campfirium/discourse-random-highlights";
const EXPECTED_LICENSE_URL = `${EXPECTED_REPOSITORY_URL}/blob/main/LICENSE`;
const EXPECTED_ISSUES_URL = `${EXPECTED_REPOSITORY_URL}/issues`;
const EXPECTED_ABOUT_KEYS = new Set(["name", "component", "license_url", "about_url", "authors", "theme_version"]);
const SITE_SPECIFIC_TAG_NAMES = ["twig", "twigs"];
const EXPECTED_TRACKED_FILES = [
  ".editorconfig",
  ".gitattributes",
  ".github/ISSUE_TEMPLATE/bug_report.yml",
  ".github/ISSUE_TEMPLATE/config.yml",
  ".github/workflows/validate.yml",
  ".gitignore",
  "CHANGELOG.md",
  "CONTRIBUTING.md",
  "LICENSE",
  "README.md",
  "SECURITY.md",
  "about.json",
  "common/common.scss",
  "common/head_tag.html",
  "docs/release-checklist.md",
  "javascripts/discourse/connectors/before-topic-list-body/random-highlights.gjs",
  "locales/en.yml",
  "scripts/validate-component.mjs",
  "settings.yml"
];

function read(relativePath) {
  if (readCache.has(relativePath)) return readCache.get(relativePath);
  try {
    const text = fs.readFileSync(path.join(root, relativePath), "utf8");
    readCache.set(relativePath, text);
    return text;
  } catch (error) {
    fail(`${relativePath}: failed to read: ${error.message}`);
    readCache.set(relativePath, "");
    return "";
  }
}

function fail(message) {
  failures.push(message);
}

function parseJson(relativePath) {
  try {
    return JSON.parse(read(relativePath));
  } catch (error) {
    fail(`${relativePath}: JSON parse failed: ${error.message}`);
    return null;
  }
}

function parseSettingsYaml(relativePath) {
  const text = read(relativePath);
  const settings = new Map();
  let current = null;

  for (const line of text.split(/\r?\n/)) {
    if (!line.trim() || line.trim().startsWith("#")) continue;

    const topLevel = /^([A-Za-z0-9_]+):\s*$/.exec(line);
    if (topLevel) {
      current = { key: topLevel[1], fields: new Map(), choices: [] };
      settings.set(current.key, current);
      continue;
    }

    if (!current) continue;

    const field = /^\s{2}([A-Za-z0-9_]+):(?:\s*(.*))?$/.exec(line);
    if (field) {
      const [, key, rawValue = ""] = field;
      current.fields.set(key, rawValue.trim());
      continue;
    }

    const choice = /^\s{4}-\s*(.+?)\s*$/.exec(line);
    if (choice && current.fields.has("choices")) {
      current.choices.push(choice[1]);
    }
  }

  if (!settings.size) fail(`${relativePath}: no top-level settings found`);

  for (const [key, setting] of settings) {
    if (!setting.fields.has("default")) fail(`${relativePath}: ${key} missing default`);
    if (!setting.fields.has("description")) fail(`${relativePath}: ${key} missing description`);
    if (setting.fields.has("type") && !SUPPORTED_THEME_SETTING_TYPES.has(setting.fields.get("type"))) {
      fail(`${relativePath}: ${key} uses unsupported theme setting type ${setting.fields.get("type")}`);
    }
    if (setting.fields.get("type") === "enum" && !setting.choices.length) {
      fail(`${relativePath}: ${key} enum setting missing choices`);
    }
    if (setting.fields.has("min") && setting.fields.has("max")) {
      const min = Number(setting.fields.get("min"));
      const max = Number(setting.fields.get("max"));
      if (!Number.isFinite(min) || !Number.isFinite(max) || min > max) {
        fail(`${relativePath}: ${key} has invalid min/max`);
      }
    }
  }

  return settings;
}

function parseLocaleKeys(relativePath) {
  const text = read(relativePath);
  const keys = new Set();
  const stack = [];

  for (const line of text.split(/\r?\n/)) {
    if (!line.trim() || line.trim().startsWith("#")) continue;
    const match = /^(\s*)([A-Za-z0-9_]+):/.exec(line);
    if (!match) continue;

    const indent = match[1].length;
    const key = match[2];
    while (stack.length && stack[stack.length - 1].indent >= indent) stack.pop();
    stack.push({ indent, key });
    keys.add(stack.map((item) => item.key).join("."));
  }

  return keys;
}

function trackedFiles() {
  return execFileSync("git", ["ls-files"], { encoding: "utf8" })
    .split(/\r?\n/)
    .filter(Boolean);
}

function trackedEolRows() {
  return execFileSync("git", ["ls-files", "--eol"], { encoding: "utf8" })
    .split(/\r?\n/)
    .filter(Boolean);
}

function gitTags(pattern) {
  return execFileSync("git", ["tag", "--list", pattern], { encoding: "utf8" })
    .split(/\r?\n/)
    .filter(Boolean);
}

function gitConfig(key) {
  try {
    return execFileSync("git", ["config", "--get", key], { encoding: "utf8" }).trim();
  } catch (error) {
    fail(`git config ${key}: failed to read`);
    return "";
  }
}

function normalizeRepositoryUrl(url) {
  const value = String(url || "").trim();
  const sshMatch = /^git@github\.com:([^/]+\/[^/]+?)(?:\.git)?$/.exec(value);
  if (sshMatch) return `https://github.com/${sshMatch[1]}`;

  return value.replace(/\.git$/, "").replace(/\/$/, "");
}

function trackedText(files) {
  return files
    .filter((file) => /\.(md|json|ya?ml|scss|html|gjs|js|mjs|txt)$/.test(file))
    .map((file) => read(file))
    .join("\n");
}

const files = trackedFiles();
const expectedFileSet = new Set(EXPECTED_TRACKED_FILES);
const actualFileSet = new Set(files);
const eolRows = trackedEolRows();
const originUrl = gitConfig("remote.origin.url");
const about = parseJson("about.json");
const editorconfig = read(".editorconfig");
const gitattributes = read(".gitattributes");
const contributing = read("CONTRIBUTING.md");
const readme = read("README.md");
const changelog = read("CHANGELOG.md");
const security = read("SECURITY.md");
const license = read("LICENSE");
const bugReportTemplate = read(".github/ISSUE_TEMPLATE/bug_report.yml");
const issueTemplateConfig = read(".github/ISSUE_TEMPLATE/config.yml");
const releaseChecklist = read("docs/release-checklist.md");
const settings = parseSettingsYaml("settings.yml");
const settingNames = [...settings.keys()];
const settingSet = new Set(settingNames);
const localeKeys = parseLocaleKeys("locales/en.yml");
const gjs = read("javascripts/discourse/connectors/before-topic-list-body/random-highlights.gjs");
const headTag = read("common/head_tag.html");
const scss = read("common/common.scss");
const componentText = [gjs, headTag, scss].join("\n");
const publicText = trackedText(files);
const publicDistributionText = trackedText(files.filter((file) => file !== "scripts/validate-component.mjs"));

if (about?.name !== "Random Highlights") fail('about.json: expected name "Random Highlights"');
if (about?.authors !== "Campfirium") fail('about.json: expected authors "Campfirium"');
if (about?.component !== true) fail('about.json: expected "component": true');
if (about) {
  for (const key of Object.keys(about)) {
    if (!EXPECTED_ABOUT_KEYS.has(key) && !["minimum_discourse_version", "maximum_discourse_version", "screenshots"].includes(key)) {
      fail(`about.json: unexpected field ${key}`);
    }
  }
}
if (normalizeRepositoryUrl(originUrl) !== EXPECTED_REPOSITORY_URL) {
  fail(`git remote origin: expected ${EXPECTED_REPOSITORY_URL}, found ${originUrl || "(missing)"}`);
}
if (about?.about_url !== EXPECTED_REPOSITORY_URL) {
  fail(`about.json: expected about_url ${EXPECTED_REPOSITORY_URL}`);
}
if (about?.license_url !== EXPECTED_LICENSE_URL) {
  fail(`about.json: expected license_url ${EXPECTED_LICENSE_URL}`);
}
if (!license.startsWith("MIT License")) {
  fail("LICENSE: expected MIT License");
}
if (!license.includes("Copyright (c) 2026 Campfirium")) {
  fail("LICENSE: expected Campfirium copyright notice");
}
if (!about?.theme_version) fail("about.json: missing theme_version");
if (about?.theme_version && !/^\d+\.\d+\.\d+$/.test(about.theme_version)) {
  fail(`about.json: theme_version should use x.y.z semver, found ${about.theme_version}`);
}
if (about?.theme_version && !changelog.includes(`## ${about.theme_version}`)) {
  fail(`CHANGELOG.md: missing section for theme_version ${about.theme_version}`);
}
const versionIsUnreleased = about?.theme_version && changelog.includes(`## ${about.theme_version} - Unreleased`);
if (versionIsUnreleased) {
  const releaseTag = `v${about.theme_version}`;
  if (gitTags(releaseTag).includes(releaseTag)) {
    fail(`git tag ${releaseTag}: remove this tag until runtime release validation passes`);
  }
  for (const blockedMetadata of ["minimum_discourse_version", "maximum_discourse_version", "screenshots"]) {
    if (Object.hasOwn(about, blockedMetadata)) {
      fail(`about.json: ${blockedMetadata} must wait for runtime release validation`);
    }
  }
  for (const requiredReadmeReleaseStatus of [
    "## Release Status",
    "`v0.1.0` is not tagged yet",
    "install, Git update, topic-list rendering, composer behavior, and styling",
    "non-production Discourse theme"
  ]) {
    if (!readme.includes(requiredReadmeReleaseStatus)) {
      fail(`README.md: missing unreleased status text: ${requiredReadmeReleaseStatus}`);
    }
  }
}
if (about?.about_url && !readme.includes(about.about_url)) {
  fail(`README.md: missing about_url ${about.about_url}`);
}
if (!readme.includes(`\`${EXPECTED_REPOSITORY_URL}\``)) {
  fail(`README.md: missing install URL ${EXPECTED_REPOSITORY_URL}`);
}
if (!readme.includes(EXPECTED_ISSUES_URL)) {
  fail(`README.md: missing support URL ${EXPECTED_ISSUES_URL}`);
}
if (!releaseChecklist.includes(`Install from \`${EXPECTED_REPOSITORY_URL}\``)) {
  fail(`docs/release-checklist.md: missing install URL ${EXPECTED_REPOSITORY_URL}`);
}

if (!gitattributes.includes("eol=lf")) fail(".gitattributes: missing LF line-ending rule");
if (!files.includes(".editorconfig")) fail(".editorconfig: missing from tracked files");
for (const requiredEditorconfigRule of [
  "root = true",
  "charset = utf-8",
  "end_of_line = lf",
  "insert_final_newline = true",
  "indent_style = space",
  "indent_size = 2"
]) {
  if (!editorconfig.includes(requiredEditorconfigRule)) {
    fail(`.editorconfig: missing rule ${requiredEditorconfigRule}`);
  }
}
for (const row of eolRows) {
  const pathMatch = /\t(.+)$/.exec(row);
  const worktreeMatch = /\bw\/(\S+)/.exec(row);
  if (!pathMatch || !worktreeMatch) continue;
  if (worktreeMatch[1] !== "lf") {
    fail(`${pathMatch[1]}: expected LF worktree line endings, found ${worktreeMatch[1]}`);
  }
}

if (!files.includes("SECURITY.md")) fail("SECURITY.md: missing from tracked files");
if (!files.includes("CONTRIBUTING.md")) fail("CONTRIBUTING.md: missing from tracked files");
if (!files.includes("docs/release-checklist.md")) fail("docs/release-checklist.md: missing from tracked files");
if (!files.includes(".github/ISSUE_TEMPLATE/bug_report.yml")) {
  fail(".github/ISSUE_TEMPLATE/bug_report.yml: missing from tracked files");
}
if (!files.includes(".github/ISSUE_TEMPLATE/config.yml")) {
  fail(".github/ISSUE_TEMPLATE/config.yml: missing from tracked files");
}
if (!readme.includes("SECURITY.md")) fail("README.md: missing SECURITY.md reference");
if (!readme.includes("[MIT License](LICENSE)")) fail("README.md: missing MIT License link");
if (!readme.includes("docs/release-checklist.md")) fail("README.md: missing release checklist link");
for (const requiredReadmeText of [
  "## Configuration",
  "Create public source topics",
  "`short_topic_tag` and `excerpt_topic_tag` to the same tag",
  "composer preview",
  "same topic"
]) {
  if (!readme.includes(requiredReadmeText)) {
    fail(`README.md: missing configuration guidance: ${requiredReadmeText}`);
  }
}
if (readme.includes("same items immediately")) {
  fail("README.md: queue wording should not over-promise per-item de-duplication");
}
if (!security.includes("not treated as security boundaries")) {
  fail("SECURITY.md: missing client-side filtering boundary statement");
}
for (const requiredReadmeSecurityText of [
  "rendered as escaped text",
  "does not render source post HTML"
]) {
  if (!readme.includes(requiredReadmeSecurityText)) {
    fail(`README.md: missing source HTML rendering boundary: ${requiredReadmeSecurityText}`);
  }
}
for (const requiredContributingText of [
  "node scripts/validate-component.mjs",
  "CHANGELOG.md",
  "docs/release-checklist.md",
  "client-side user ID or trust-level settings as security boundaries",
  "minimum_discourse_version",
  "Campfirium migration scripts"
]) {
  if (!contributing.includes(requiredContributingText)) {
    fail(`CONTRIBUTING.md: missing guidance: ${requiredContributingText}`);
  }
}
for (const setting of [
  "composer_allowed_user_ids",
  "composer_min_trust_level",
  "allowed_author_user_ids",
  "allowed_author_min_trust_level"
]) {
  if (!security.includes(setting)) fail(`SECURITY.md: missing setting ${setting}`);
}
for (const requiredIssueField of [
  "discourse-version",
  "component-commit",
  "settings",
  "reproduction",
  "evidence"
]) {
  if (!bugReportTemplate.includes(`id: ${requiredIssueField}`)) {
    fail(`bug_report.yml: missing field ${requiredIssueField}`);
  }
}
for (const requiredIssueConfigText of [
  "blank_issues_enabled: false",
  "SECURITY.md",
  "Security policy"
]) {
  if (!issueTemplateConfig.includes(requiredIssueConfigText)) {
    fail(`config.yml: missing issue template config ${requiredIssueConfigText}`);
  }
}
for (const requiredReleaseGate of [
  "Install from",
  "updated from Git",
  "Source Modes",
  "Rendering",
  "Composer",
  "Styling",
  "Tag `v0.1.0`"
]) {
  if (!releaseChecklist.includes(requiredReleaseGate)) {
    fail(`docs/release-checklist.md: missing release gate ${requiredReleaseGate}`);
  }
}

if (settings.size !== 17) {
  fail(`settings.yml: expected 17 public settings, found ${settings.size}`);
}
for (const sourceTagSetting of ["short_topic_tag", "excerpt_topic_tag"]) {
  if (settings.get(sourceTagSetting)?.fields.get("default") !== '""') {
    fail(`settings.yml: ${sourceTagSetting} default must stay empty for public distribution`);
  }
}
for (const tagName of SITE_SPECIFIC_TAG_NAMES) {
  if (new RegExp(`\\b${tagName}\\b`, "i").test(publicDistributionText)) {
    fail(`Public files: remove site-specific tag name "${tagName}"`);
  }
}

for (const setting of settingNames) {
  if (!readme.includes(`\`${setting}\``)) {
    fail(`README.md: missing setting documentation for ${setting}`);
  }
}

const settingRefs = [...componentText.matchAll(/settings\.([A-Za-z0-9_]+)/g)].map((match) => match[1]);
for (const ref of new Set(settingRefs)) {
  if (!settingSet.has(ref)) fail(`Code references missing setting: ${ref}`);
}

const titleKeys = [...componentText.matchAll(/title:\s*["']([A-Za-z0-9_.]+)["']/g)].map((match) => `en.js.${match[1]}`);
const composerExampleKeys = [...componentText.matchAll(/applySurround\([^)]*["']([A-Za-z0-9_]+)["']/g)].map(
  (match) => `en.js.composer.${match[1]}`
);
for (const key of [...titleKeys, ...composerExampleKeys]) {
  if (!localeKeys.has(key)) fail(`locales/en.yml: missing locale key ${key}`);
}

if (!localeKeys.has("en.theme_metadata.description")) {
  fail("locales/en.yml: missing theme_metadata.description");
}
for (const setting of settingNames) {
  const key = `en.theme_metadata.settings.${setting}`;
  if (!localeKeys.has(key)) fail(`locales/en.yml: missing locale key ${key}`);
}
for (const [settingName, setting] of settings) {
  if (setting.fields.get("type") !== "enum") continue;
  const descriptionKey = `en.theme_metadata.settings.${settingName}.description`;
  if (!localeKeys.has(descriptionKey)) fail(`locales/en.yml: missing locale key ${descriptionKey}`);
  for (const choice of setting.choices) {
    const key = `en.theme_metadata.settings.${settingName}.choices.${choice}`;
    if (!localeKeys.has(key)) fail(`locales/en.yml: missing locale key ${key}`);
  }
}

for (const className of ["random-highlight", "random-highlights-body", "random-highlight-source", "random-highlight-prefix"]) {
  if (!gjs.includes(className)) fail(`GJS: missing class ${className}`);
  if (!scss.includes(className)) fail(`SCSS: missing class ${className}`);
}

for (const setting of [
  "random_item_author_mode",
  "topic_cache_minutes",
  "highlight_light_background",
  "highlight_light_text",
  "highlight_light_opacity",
  "highlight_dark_background",
  "highlight_dark_text",
  "highlight_dark_opacity"
]) {
  if (!publicText.includes(setting)) fail(`Public files: missing setting reference ${setting}`);
}

for (const colorSetting of ["highlight_light_background", "highlight_dark_background"]) {
  const defaultValue = settings.get(colorSetting)?.fields.get("default") || "";
  if (defaultValue !== '""') {
    fail(`settings.yml: ${colorSetting} default should stay empty to preserve native mark styling`);
  }
}

for (const textColorSetting of ["highlight_light_text", "highlight_dark_text"]) {
  const defaultValue = settings.get(textColorSetting)?.fields.get("default") || "";
  if (defaultValue !== '""') {
    fail(`settings.yml: ${textColorSetting} default should stay empty to preserve native mark styling`);
  }
}

for (const opacitySetting of ["highlight_light_opacity", "highlight_dark_opacity"]) {
  const setting = settings.get(opacitySetting);
  const defaultValue = setting?.fields.get("default") || "";
  if (defaultValue !== '""') {
    fail(`settings.yml: ${opacitySetting} default should stay empty to preserve native mark styling`);
  }
  if (setting?.fields.get("min") !== "0" || setting?.fields.get("max") !== "1") {
    fail(`settings.yml: ${opacitySetting} should use min 0 and max 1`);
  }
}

if (settings.get("topic_cache_minutes")?.fields.get("default") !== "10080") {
  fail("settings.yml: topic_cache_minutes should default to 10080 minutes");
}
if (settings.get("topic_cache_minutes")?.fields.get("max") !== "10080") {
  fail("settings.yml: topic_cache_minutes max should allow 7 days");
}

if (!gjs.includes('<tbody class="random-highlights-body">')) {
  fail("GJS: before-topic-list-body connector should keep its tbody wrapper unless runtime validation proves otherwise");
}
if (!gjs.includes('return "random-highlight topic-list-item"')) {
  fail("GJS: random row should keep native topic-list row styling");
}
if (!gjs.includes("preloadedEntryPromise()")) {
  fail("GJS: missing preload path for the next random highlight");
}
if (!gjs.includes("readCachedEntry()")) {
  fail("GJS: missing synchronous cached-entry display path");
}
if (!gjs.includes(">✨</span>")) {
  fail("GJS: missing sparkle prefix for source topic title line");
}
if (!gjs.includes("{{this.displayExcerpt}}")) {
  fail("GJS: random body text should render as the primary row text");
}
if (!gjs.includes("{{this.displayTitle}}")) {
  fail("GJS: source topic title should render as secondary row text");
}
if (!scss.includes("opacity: 0.68")) {
  fail("SCSS: source topic title line should be semi-transparent");
}
if (!scss.includes("font-size: var(--font-down-1)")) {
  fail("SCSS: source topic title line should use Discourse's smaller metadata scale");
}
if (scss.includes("margin-right:")) {
  fail("SCSS: sparkle prefix should not add hard-coded spacing before the source title");
}
if (scss.includes("border-bottom:")) {
  fail("SCSS: random row should not add its own divider over Discourse topic-list borders");
}
if (!scss.includes(".random-highlights-body + .topic-list-body")) {
  fail("SCSS: adjacent topic-list body should not add an extra section divider after the random row");
}
if (!scss.includes(".random-highlight .title") || !scss.includes("opacity: 0.5")) {
  fail("SCSS: random body text should use the original dimmed title treatment");
}
if (!scss.includes("mark::before")) {
  fail("SCSS: marked text highlight should use a background pseudo-element");
}
if (!scss.includes('@if $highlight_light_background != ""')) {
  fail("SCSS: mark background settings should be optional");
}
if (scss.includes("border:") || scss.includes("box-shadow:")) {
  fail("SCSS: marked text highlight should not use borders or row-style shadows");
}
if (!headTag.includes('icon: "pencil-alt"')) {
  fail('common/head_tag.html: expected composer toolbar icon "pencil-alt"');
}
if (headTag.includes('icon: "highlighter"')) {
  fail('common/head_tag.html: avoid unproven "highlighter" icon');
}
if (!headTag.includes("function booleanSetting")) {
  fail("common/head_tag.html: missing composer boolean setting normalization");
}
if (!headTag.includes("COMPOSER_MIN_TRUST_LEVEL")) {
  fail("common/head_tag.html: missing composer trust-level normalization");
}
if (!gjs.includes("AUTHOR_MIN_TRUST_LEVEL")) {
  fail("GJS: missing author trust-level normalization");
}
if (!gjs.includes("RANDOM_ITEM_AUTHOR_MODE")) {
  fail("GJS: missing random item author mode normalization");
}
if (!gjs.includes("{{this.activityLabel}}")) {
  fail("GJS: activity column should render a stable text label");
}
if (gjs.includes("{{format-date")) {
  fail("GJS: avoid format-date helper in the connector template until runtime compatibility is proven");
}
if (!gjs.includes('String(settings.short_topic_tag || "").trim()')) {
  fail("GJS: source tags should be trimmed before cache/signature use");
}
if (!gjs.includes("Array.isArray(cache.topics)")) {
  fail("GJS: cached topics should be ignored unless they are an array");
}
if (!gjs.includes("Array.isArray(storedQueue)")) {
  fail("GJS: session display queue should be ignored unless it is an array");
}
if (!gjs.includes("node.textContent ||")) {
  fail("GJS: marked excerpts should be extracted as textContent");
}
if (gjs.includes("htmlSafe") || gjs.includes("{{{")) {
  fail("GJS: source post HTML must not be rendered into the topic list row");
}

for (const file of files) {
  if (!expectedFileSet.has(file)) {
    fail(`Tracked unexpected public file: ${file}`);
  }
  if (file.startsWith(".lab/") || file.startsWith(".agents/") || file.startsWith(".tmp/")) {
    fail(`Tracked local-only file: ${file}`);
  }
  if (/(^|\/)\.env(\.|$)/.test(file) || /(^|\/)env\.local$/.test(file)) {
    fail(`Tracked environment file: ${file}`);
  }
  if (/\.(log|pem|key|p12|pfx)$/i.test(file)) {
    fail(`Tracked sensitive or local artifact file: ${file}`);
  }
  if (/(^|\/)(migration|backup|repair|audit)[^/]*\.(mjs|js|json|md)$/i.test(file)) {
    fail(`Tracked local maintenance artifact: ${file}`);
  }
}
for (const file of EXPECTED_TRACKED_FILES) {
  if (!actualFileSet.has(file)) {
    fail(`Missing expected public file: ${file}`);
  }
}

if (failures.length) {
  console.error("Component validation failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(`Component validation passed (${settings.size} settings, ${files.length} tracked files checked).`);
