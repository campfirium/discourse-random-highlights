#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const root = process.cwd();
const failures = [];

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
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

function trackedText(files) {
  return files
    .filter((file) => /\.(md|json|ya?ml|scss|html|gjs|js|mjs|txt)$/.test(file))
    .map((file) => read(file))
    .join("\n");
}

const files = trackedFiles();
const about = parseJson("about.json");
const readme = read("README.md");
const changelog = read("CHANGELOG.md");
const settings = parseSettingsYaml("settings.yml");
const settingNames = [...settings.keys()];
const settingSet = new Set(settingNames);
const localeKeys = parseLocaleKeys("locales/en.yml");
const gjs = read("javascripts/discourse/connectors/before-topic-list-body/random-highlights.gjs");
const headTag = read("common/head_tag.html");
const scss = read("common/common.scss");
const componentText = [gjs, headTag, scss].join("\n");
const publicText = trackedText(files);

if (about?.component !== true) fail('about.json: expected "component": true');
if (!about?.theme_version) fail("about.json: missing theme_version");
if (about?.theme_version && !changelog.includes(`## ${about.theme_version}`)) {
  fail(`CHANGELOG.md: missing section for theme_version ${about.theme_version}`);
}
if (about?.about_url && !readme.includes(about.about_url)) {
  fail(`README.md: missing about_url ${about.about_url}`);
}

if (settings.size !== 18) {
  fail(`settings.yml: expected 18 public settings, found ${settings.size}`);
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

for (const className of ["random-highlight", "random-highlights-body", "random-highlight--custom"]) {
  if (!gjs.includes(className)) fail(`GJS: missing class ${className}`);
  if (!scss.includes(className)) fail(`SCSS: missing class ${className}`);
}

for (const setting of [
  "highlight_style_mode",
  "random_item_author_mode",
  "highlight_light_background",
  "highlight_dark_background"
]) {
  if (!publicText.includes(setting)) fail(`Public files: missing setting reference ${setting}`);
}

for (const colorSetting of [
  "highlight_light_background",
  "highlight_light_text",
  "highlight_light_border",
  "highlight_dark_background",
  "highlight_dark_text",
  "highlight_dark_border"
]) {
  const defaultValue = settings.get(colorSetting)?.fields.get("default") || "";
  if (!/^"#[0-9A-Fa-f]{6}"$/.test(defaultValue)) {
    fail(`settings.yml: ${colorSetting} default should be a quoted 6-digit hex color`);
  }
}

if (!gjs.includes('<tbody class="random-highlights-body">')) {
  fail("GJS: before-topic-list-body connector should keep its tbody wrapper unless runtime validation proves otherwise");
}
if (!headTag.includes('icon: "pencil-alt"')) {
  fail('common/head_tag.html: expected composer toolbar icon "pencil-alt"');
}
if (headTag.includes('icon: "highlighter"')) {
  fail('common/head_tag.html: avoid unproven "highlighter" icon');
}

for (const file of files) {
  if (file.startsWith(".lab/") || file.startsWith(".agents/") || file.startsWith(".tmp/")) {
    fail(`Tracked local-only file: ${file}`);
  }
}

if (failures.length) {
  console.error("Component validation failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(`Component validation passed (${settings.size} settings, ${files.length} tracked files checked).`);
