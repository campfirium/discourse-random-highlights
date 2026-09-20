import { service } from "@ember/service";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dNumber from "discourse/ui-kit/helpers/d-number";

const SHORT_TOPIC_TAG = String(settings.short_topic_tag || "").trim();
const EXCERPT_TOPIC_TAG = String(settings.excerpt_topic_tag || "").trim();
const LEGACY_HIGHLIGHT_SELECTOR = "mark";
const HIGHLIGHT_SELECTOR = String(settings.highlight_selector || "mark").trim() || "mark";
const HIGHLIGHT_WRAP_SELECTOR = '[data-wrap="random-highlight"]';
const HIGHLIGHT_TEXT_BOUNDARY_TAGS = new Set([
  "ADDRESS", "ARTICLE", "ASIDE", "BLOCKQUOTE", "BR", "DD", "DIV", "DL", "DT",
  "FIGCAPTION", "FIGURE", "FOOTER", "H1", "H2", "H3", "H4", "H5", "H6",
  "HEADER", "HR", "LI", "MAIN", "NAV", "OL", "P", "PRE", "SECTION", "TABLE",
  "TBODY", "TD", "TFOOT", "TH", "THEAD", "TR", "UL"
]);
const MAX_EXCERPT_LENGTH = numberSetting(settings.max_excerpt_length, 220, 40, 1000);
const CACHE_MS = numberSetting(settings.topic_cache_minutes, 10080, 1, 10080) * 60 * 1000;
const AUTHOR_MIN_TRUST_LEVEL = numberSetting(settings.allowed_author_min_trust_level, 0, 0, 4);
const SOURCE_SIGNATURE = [SHORT_TOPIC_TAG, EXCERPT_TOPIC_TAG].join("|");
const QUEUE_KEY = "randomHighlightsDisplayQueueV2:" + SOURCE_SIGNATURE;
const RANDOM_ITEM_AUTHOR_MODE = String(settings.random_item_author_mode || "original_author").trim();
const SHOW_ORIGINAL_AUTHOR = RANDOM_ITEM_AUTHOR_MODE !== "system";
const MAX_TOPIC_REQUESTS = 5;
const LOAD_TIMEOUT_MS = 10000;
const IN_FLIGHT = new Map();
const TOPIC_CACHES = new Map();

function numberSetting(value, fallback, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, number));
}

function parseIdList(value) {
  return String(value || "")
    .split(/[,|\s]+/)
    .map((item) => Number(String(item).trim()))
    .filter((item) => Number.isFinite(item) && item > 0);
}

function sourceConfigs() {
  const shortTag = SHORT_TOPIC_TAG;
  const excerptTag = EXCERPT_TOPIC_TAG;
  if (shortTag && excerptTag && shortTag === excerptTag) return [{ tag: shortTag, mode: "both" }];
  return [
    shortTag ? { tag: shortTag, mode: "short" } : null,
    excerptTag ? { tag: excerptTag, mode: "excerpt" } : null
  ].filter(Boolean);
}

function randomKey(topic) {
  return topic && topic._randomHighlightsKey ? topic._randomHighlightsKey : "";
}

function normalizeText(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

function truncateText(value, maxLength) {
  const text = normalizeText(value);
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength).replace(/[，。,.!?！？；;：:\s]+$/g, "") + "...";
}

function shuffle(items) {
  const array = items.slice();
  for (let index = array.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    [array[index], array[swapIndex]] = [array[swapIndex], array[index]];
  }
  return array;
}

function topicUrl(topic) {
  return "/t/" + encodeURIComponent(topic.slug || "topic") + "/" + topic.id;
}

function clearLegacyEntryCaches() {
  try {
    const storage = window.localStorage;
    for (let index = storage.length - 1; index >= 0; index -= 1) {
      const key = storage.key(index);
      if (key?.startsWith("randomHighlightsEntryCacheV2:")) storage.removeItem(key);
    }
  } catch (_error) {}
}

function readSessionJSON(key) {
  try {
    const value = window.sessionStorage && window.sessionStorage.getItem(key);
    return value ? JSON.parse(value) : null;
  } catch (_error) {
    return null;
  }
}

function writeSessionJSON(key, value) {
  try {
    if (window.sessionStorage) window.sessionStorage.setItem(key, JSON.stringify(value));
  } catch (_error) {}
}

function htmlToText(html) {
  const element = document.createElement("div");
  element.innerHTML = html || "";
  element.querySelectorAll("script, style, pre, code, aside").forEach((node) => node.remove());
  return normalizeText(element.textContent || "");
}

function queryHighlightNodes(root) {
  const groupedNodes = Array.from(root.querySelectorAll(HIGHLIGHT_WRAP_SELECTOR));
  const legacyNodes = Array.from(root.querySelectorAll(LEGACY_HIGHLIGHT_SELECTOR));
  let selectedNodes = [];

  try {
    selectedNodes = Array.from(root.querySelectorAll(HIGHLIGHT_SELECTOR));
  } catch (error) {
    // Invalid admin-provided selectors should not break the topic list.
    // eslint-disable-next-line no-console
    console.warn("random highlights selector failed", error);
  }

  const candidates = new Set([...groupedNodes, ...legacyNodes, ...selectedNodes]);
  return Array.from(root.querySelectorAll("*")).filter((node) => {
    if (!candidates.has(node)) return false;

    if (node.matches(HIGHLIGHT_WRAP_SELECTOR)) {
      return !node.parentElement?.closest(HIGHLIGHT_WRAP_SELECTOR);
    }
    return !node.closest(HIGHLIGHT_WRAP_SELECTOR);
  });
}

function highlightNodeText(node) {
  const parts = [];

  function appendNodeText(current) {
    if (current.nodeType === 3) {
      parts.push(current.textContent || "");
      return;
    }

    const separatesText = current !== node && HIGHLIGHT_TEXT_BOUNDARY_TAGS.has(current.tagName);
    if (separatesText) parts.push(" ");
    current.childNodes.forEach(appendNodeText);
    if (separatesText) parts.push(" ");
  }

  appendNodeText(node);
  return parts.join("");
}

function firstPost(payload) {
  const posts = payload && payload.post_stream && payload.post_stream.posts;
  return posts && posts.length ? posts[0] : null;
}

function authorUser(topic, post) {
  const userId = Number(post && post.user_id);
  return userId && topic?._randomHighlightsUsersById ? topic._randomHighlightsUsersById[userId] : null;
}

function rememberPostUser(topic, post) {
  if (!topic || !post || !post.user_id) return;
  topic._randomHighlightsUsersById = topic._randomHighlightsUsersById || {};
  const user = Object.assign({}, topic._randomHighlightsUsersById[post.user_id], { id: post.user_id });
  ["username", "name", "avatar_template", "trust_level"].forEach((key) => {
    if (post[key] !== undefined && post[key] !== null) user[key] = post[key];
  });
  topic._randomHighlightsUsersById[post.user_id] = user;
}

function authorAllowed(topic, post) {
  const allowedIds = parseIdList(settings.allowed_author_user_ids);
  if (allowedIds.length && !allowedIds.includes(Number(post && post.user_id))) return false;
  const user = authorUser(topic, post);
  const trustLevel = Number((post && post.trust_level) ?? (user && user.trust_level) ?? 0);
  return trustLevel >= AUTHOR_MIN_TRUST_LEVEL;
}

function avatarUrl(user, size) {
  if (!user || !user.avatar_template) return "";
  return user.avatar_template.replace("{size}", String(size || 48));
}

function originalPoster(topic) {
  const posters = topic && topic.posters;
  if (!posters || !posters.length) return null;
  return posters.find((poster) => String(poster.extras || "").includes("original")) || posters[0];
}

function getCachedTopics(identity) {
  const cache = TOPIC_CACHES.get(identity);
  if (!cache || Date.now() - cache.fetchedAt > CACHE_MS) return null;
  return cache.topics;
}

function setCachedTopics(identity, topics) {
  TOPIC_CACHES.set(identity, { fetchedAt: Date.now(), topics });
}

function applyTopicMetadata(topic, payload) {
  if (!topic || !payload) return topic;
  [
    "title",
    "fancy_title",
    "slug",
    "posts_count",
    "views",
    "bumped_at",
    "last_posted_at",
    "created_at"
  ].forEach((key) => {
    if (payload[key] !== undefined && payload[key] !== null) topic[key] = payload[key];
  });
  return topic;
}

async function fetchTaggedTopics(identity, signal) {
  const cached = getCachedTopics(identity);
  if (cached) return cached;

  const configs = sourceConfigs();
  const topics = [];
  let failed = false;

  for (const config of configs) {
    if (signal.aborted) throw new Error("highlight load timed out");
    try {
      const response = await fetch("/tag/" + encodeURIComponent(config.tag) + ".json", { credentials: "same-origin", cache: "no-store", signal });
      if (!response.ok) {
        failed = true;
        continue;
      }

      const payload = await response.json();
      const usersById = {};
      (payload.users || []).forEach((user) => {
        usersById[user.id] = user;
      });

      ((payload.topic_list && payload.topic_list.topics) || [])
        .filter((topic) => topic && topic.id && !topic.deleted && !topic.archived)
        .forEach((topic) => {
          topics.push(Object.assign({}, topic, {
            _randomHighlightsUsersById: usersById,
            _randomHighlightsMode: config.mode,
            _randomHighlightsKey: config.mode + ":" + topic.id
          }));
        });
    } catch (error) {
      failed = true;
      // One unavailable tag source should not block the other configured source.
      // eslint-disable-next-line no-console
      console.warn("random highlights tag failed", error);
    }
  }

  if (!failed) setCachedTopics(identity, topics);
  return topics;
}

async function fetchEntriesForTopic(topic, signal) {
  const response = await fetch(topicUrl(topic) + ".json", { credentials: "same-origin", cache: "no-store", signal });
  if (!response.ok) throw new Error("topic request failed: " + response.status);

  const payload = await response.json();
  applyTopicMetadata(topic, payload);
  const post = firstPost(payload);
  rememberPostUser(topic, post);
  if (!post || !authorAllowed(topic, post)) return [];
  return extractHighlights(topic, post);
}

function extractHighlights(topic, post) {
  const root = document.createElement("div");
  root.innerHTML = post.cooked || "";

  const mode = topic._randomHighlightsMode || "excerpt";
  const entries = queryHighlightNodes(root)
    .map((node, index) => entryFromTopic(topic, "highlight:" + topic.id + ":" + index, highlightNodeText(node)))
    .filter((entry) => entry.text);

  if (entries.length) return entries;
  if (mode === "excerpt") return [];

  const fallback = truncateText(htmlToText(post.cooked || ""), MAX_EXCERPT_LENGTH);
  return fallback ? [entryFromTopic(topic, "topic:" + topic.id, fallback)] : [];
}

function entryFromTopic(topic, id, text) {
  return {
    id,
    href: topicUrl(topic),
    title: topic.title || topic.fancy_title || "",
    text: truncateText(text || "", MAX_EXCERPT_LENGTH),
    topic
  };
}

async function fetchNextHighlight(identity, signal) {
  const topics = await fetchTaggedTopics(identity, signal);
  const queueKey = QUEUE_KEY + ":" + identity;
  const storedQueue = readSessionJSON(queueKey);
  let queue = (Array.isArray(storedQueue) ? storedQueue : []).filter((key) =>
    topics.some((topic) => randomKey(topic) === key)
  );
  if (!queue.length) queue = shuffle(topics.map((topic) => randomKey(topic)).filter(Boolean));

  let requests = 0;
  while (queue.length && requests < MAX_TOPIC_REQUESTS && !signal.aborted) {
    const key = queue.shift();
    writeSessionJSON(queueKey, queue);

    const topic = topics.find((item) => randomKey(item) === key);
    if (!topic) continue;
    const allowedIds = parseIdList(settings.allowed_author_user_ids);
    const poster = originalPoster(topic);
    if (allowedIds.length && poster && !allowedIds.includes(Number(poster.user_id))) continue;

    try {
      requests += 1;
      const entries = await fetchEntriesForTopic(topic, signal);
      const entry = shuffle(entries)[0];
      if (entry) {
        return entry;
      }
    } catch (error) {
      // A private or deleted topic should not prevent other sources from rendering.
      // eslint-disable-next-line no-console
      console.warn("random highlights topic failed", error);
    }
  }

  return null;
}

function loadEntry(identity) {
  if (IN_FLIGHT.has(identity)) return IN_FLIGHT.get(identity);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), LOAD_TIMEOUT_MS);
  const promise = fetchNextHighlight(identity, controller.signal).finally(() => {
    clearTimeout(timeout);
    IN_FLIGHT.delete(identity);
  });
  IN_FLIGHT.set(identity, promise);
  return promise;
}

export default class RandomHighlights extends Component {
  @service router;
  @service currentUser;

  @tracked entry = null;
  loadGeneration = 0;
  latestActive = false;

  constructor() {
    super(...arguments);
    clearLegacyEntryCaches();
    this.handleRouteChange = () => this.load();
    this.router.on("routeDidChange", this.handleRouteChange);
    this.load();
  }

  willDestroy() {
    this.router.off("routeDidChange", this.handleRouteChange);
    this.loadGeneration += 1;
    super.willDestroy(...arguments);
  }

  get isDesktop() {
    return window.innerWidth > 1024;
  }

  get bulkSelectEnabled() {
    return Boolean(this.args.outletArgs?.bulkSelectEnabled);
  }

  get displayEntry() {
    return this.router.currentRouteName === "discovery.latest"
      ? this.entry
      : null;
  }

  get rowClass() {
    return "random-highlight topic-list-item";
  }

  get displayTitle() {
    return this.entry?.title || this.entry?.text || "";
  }

  get displayExcerpt() {
    return this.entry?.text || "";
  }

  get showAuthor() {
    return SHOW_ORIGINAL_AUTHOR;
  }

  get user() {
    if (!this.showAuthor) return null;
    const topic = this.entry?.topic;
    const poster = originalPoster(topic);
    return poster && topic?._randomHighlightsUsersById ? topic._randomHighlightsUsersById[poster.user_id] : null;
  }

  get avatar() {
    return avatarUrl(this.user, 48);
  }

  get mobileAvatar() {
    return avatarUrl(this.user, 96);
  }

  get showAvatar() {
    return this.showAuthor && this.avatar;
  }

  get username() {
    return this.user?.username || this.user?.name || "";
  }

  get userPath() {
    return this.username ? "/u/" + encodeURIComponent(this.username) : "";
  }

  get mobileMetadataClass() {
    return this.showAvatar ? "topic-item-metadata right" : "topic-item-metadata";
  }

  get replyCount() {
    return Math.max(0, Number(this.entry?.topic?.posts_count || 0) - 1);
  }

  get activityDate() {
    const topic = this.entry?.topic || {};
    return topic.bumped_at || topic.last_posted_at || topic.created_at || "";
  }

  async load() {
    if (this.router.currentRouteName !== "discovery.latest") {
      this.latestActive = false;
      this.loadGeneration += 1;
      this.entry = null;
      return;
    }
    if (this.latestActive) return;
    this.latestActive = true;
    const generation = ++this.loadGeneration;
    const identity = String(this.currentUser?.id ?? "anonymous");
    this.entry = null;
    try {
      const entry = await loadEntry(identity);
      if (!this.isDestroying && !this.isDestroyed && generation === this.loadGeneration &&
          identity === String(this.currentUser?.id ?? "anonymous")) {
        this.entry = entry;
      }
    } catch (error) {
      // A failed request must never restore previously visible content.
      // eslint-disable-next-line no-console
      console.warn("random highlights failed", error);
    }
  }

  <template>
    {{#if this.displayEntry}}
      <tbody class="random-highlights-body">
        <tr class={{this.rowClass}} data-topic-id={{this.entry.topic.id}}>
          {{#if this.isDesktop}}
            {{#if this.bulkSelectEnabled}}
              <td class="bulk-select topic-list-data"></td>
            {{/if}}
            <td class="main-link clearfix topic-list-data" colspan="1">
              <span class="link-top-line" role="heading" aria-level="2">
                <a href={{this.entry.href}} data-topic-id={{this.entry.topic.id}} class="title raw-link raw-topic-link">
                  {{this.displayExcerpt}}
                </a>
              </span>
              {{#if this.displayTitle}}
                <div class="link-bottom-line random-highlight-source">
                  <span class="random-highlight-prefix" aria-hidden="true"></span><a href={{this.entry.href}} class="raw-link">{{this.displayTitle}}</a>
                </div>
              {{/if}}
            </td>
            <td class="posters topic-list-data theme-avatar-small">
              {{#if this.showAvatar}}
                <a href={{this.userPath}} data-user-card={{this.username}} class="latest single">
                  <img alt="" width="24" height="24" src={{this.avatar}} class="avatar latest single" title={{this.username}}>
                </a>
              {{/if}}
            </td>
            <td class="num posts-map posts topic-list-data">
              <a href={{this.entry.href}} class="badge-posts">{{dNumber this.replyCount noTitle="true"}}</a>
            </td>
            <td class="num views topic-list-data">{{dNumber this.entry.topic.views numberKey="views_long"}}</td>
            <td class="activity num topic-list-data age">
              <a href={{this.entry.href}} class="post-activity">
                {{dFormatDate this.activityDate format="tiny" noTitle="true"}}
              </a>
            </td>
          {{else}}
            <td class="topic-list-data">
              {{#if this.showAvatar}}
                <div class="pull-left">
                  <a href={{this.entry.href}} data-user-card={{this.username}}>
                    <img alt="" width="48" height="48" src={{this.mobileAvatar}} class="avatar" title={{this.username}}>
                  </a>
                </div>
              {{/if}}

              <div class={{this.mobileMetadataClass}}>
                <div class="main-link" role="heading" aria-level="2">
                  <a href={{this.entry.href}} data-topic-id={{this.entry.topic.id}} class="title raw-link raw-topic-link">
                    {{this.displayExcerpt}}
                  </a>
                </div>

                <div class="pull-right">
                  <div class="num posts-map posts topic-list-data">
                    <a href={{this.entry.href}} class="badge-posts">
                      {{dNumber this.replyCount noTitle="true"}}
                    </a>
                  </div>
                </div>

                <div class="topic-item-stats clearfix">
                  <span class="topic-item-stats__category-tags">
                    {{#if this.displayTitle}}
                      <span class="random-highlight-source">
                        <span class="random-highlight-prefix" aria-hidden="true"></span><a href={{this.entry.href}} class="raw-link">{{this.displayTitle}}</a>
                      </span>
                    {{/if}}
                  </span>
                  <div class="num activity last">
                    <span class="age activity">
                      <a href={{this.entry.href}}>
                        {{dFormatDate this.activityDate format="tiny" noTitle="true"}}
                      </a>
                    </span>
                  </div>
                </div>
              </div>
            </td>
          {{/if}}
        </tr>
      </tbody>
    {{/if}}
  </template>
}
