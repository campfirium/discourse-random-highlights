import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

const SHORT_TOPIC_TAG = settings.short_topic_tag || "";
const EXCERPT_TOPIC_TAG = settings.excerpt_topic_tag || "";
const HIGHLIGHT_SELECTOR = settings.highlight_selector || "mark";
const MAX_EXCERPT_LENGTH = Number(settings.max_excerpt_length || 220);
const CACHE_MS = Number(settings.topic_cache_minutes || 5) * 60 * 1000;
const SOURCE_SIGNATURE = [SHORT_TOPIC_TAG, EXCERPT_TOPIC_TAG].join("|");
const QUEUE_KEY = "randomHighlightsDisplayQueueV2:" + SOURCE_SIGNATURE;
const USE_CUSTOM_STYLE = settings.highlight_style_mode !== "native";
const SHOW_ORIGINAL_AUTHOR = settings.random_item_author_mode !== "system";

function parseIdList(value) {
  return String(value || "")
    .split(/[,|\s]+/)
    .map((item) => Number(String(item).trim()))
    .filter((item) => Number.isFinite(item) && item > 0);
}

function sourceConfigs() {
  const shortTag = String(SHORT_TOPIC_TAG || "").trim();
  const excerptTag = String(EXCERPT_TOPIC_TAG || "").trim();
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

function readJSON(key) {
  try {
    const value = window.sessionStorage && window.sessionStorage.getItem(key);
    return value ? JSON.parse(value) : null;
  } catch (_error) {
    return null;
  }
}

function writeJSON(key, value) {
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
  try {
    return Array.from(root.querySelectorAll(HIGHLIGHT_SELECTOR));
  } catch (error) {
    // Invalid admin-provided selectors should not break the topic list.
    // eslint-disable-next-line no-console
    console.warn("random highlights selector failed", error);
    return [];
  }
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
  return trustLevel >= Number(settings.allowed_author_min_trust_level || 0);
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

function formatCount(value) {
  const number = Number(value || 0);
  if (number >= 1000000) return Math.round(number / 100000) / 10 + "m";
  if (number >= 1000) return Math.round(number / 100) / 10 + "k";
  return String(number);
}

function relativeDateLabel(value) {
  const time = Date.parse(value || "");
  if (!Number.isFinite(time)) return "";
  const seconds = Math.max(0, Math.floor((Date.now() - time) / 1000));
  if (seconds < 60) return "now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return minutes + "m";
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return hours + "h";
  const days = Math.floor(hours / 24);
  if (days < 30) return days + "d";
  const months = Math.floor(days / 30);
  if (months < 12) return months + "mo";
  return Math.floor(months / 12) + "y";
}

export default class RandomHighlights extends Component {
  @tracked entry = null;

  constructor() {
    super(...arguments);
    this.load();
  }

  get isDesktop() {
    return window.innerWidth > 1024;
  }

  get rowClass() {
    return USE_CUSTOM_STYLE ? "random-highlight topic-list-item random-highlight--custom" : "random-highlight topic-list-item";
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

  get showAvatar() {
    return this.showAuthor && this.avatar;
  }

  get username() {
    return this.user?.username || this.user?.name || "";
  }

  get userPath() {
    return this.username ? "/u/" + encodeURIComponent(this.username) : "";
  }

  get postCount() {
    return formatCount(this.entry?.topic?.posts_count || 0);
  }

  get viewCount() {
    return formatCount(this.entry?.topic?.views || 0);
  }

  get activityLabel() {
    const topic = this.entry?.topic || {};
    return relativeDateLabel(topic.bumped_at || topic.last_posted_at || topic.created_at);
  }

  get activityTime() {
    const topic = this.entry?.topic || {};
    const value = topic.bumped_at || topic.last_posted_at || topic.created_at;
    const time = Date.parse(value || "");
    return Number.isFinite(time) ? time : "";
  }

  async load() {
    try {
      this.entry = await this.fetchNextHighlight();
    } catch (error) {
      // Keep the topic list usable if the source tag is missing or private.
      // eslint-disable-next-line no-console
      console.warn("random highlights failed", error);
    }
  }

  getCachedTopics() {
    const cache = window._randomHighlightsTopicCache;
    if (!cache || cache.signature !== SOURCE_SIGNATURE || !cache.fetchedAt || !cache.topics) return null;
    if (Date.now() - cache.fetchedAt > CACHE_MS) return null;
    return cache.topics;
  }

  setCachedTopics(topics) {
    window._randomHighlightsTopicCache = { signature: SOURCE_SIGNATURE, fetchedAt: Date.now(), topics };
  }

  async fetchTaggedTopics() {
    const cached = this.getCachedTopics();
    if (cached) return cached;

    const configs = sourceConfigs();
    const topics = [];

    for (const config of configs) {
      try {
        const response = await fetch("/tag/" + encodeURIComponent(config.tag) + ".json", { credentials: "same-origin" });
        if (!response.ok) continue;

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
        // One unavailable tag source should not block the other configured source.
        // eslint-disable-next-line no-console
        console.warn("random highlights tag failed", error);
      }
    }

    this.setCachedTopics(topics);
    return topics;
  }

  async fetchEntriesForTopic(topic) {
    const response = await fetch(topicUrl(topic) + ".json", { credentials: "same-origin" });
    if (!response.ok) throw new Error("topic request failed: " + response.status);

    const payload = await response.json();
    const post = firstPost(payload);
    rememberPostUser(topic, post);
    if (!post || !authorAllowed(topic, post)) return [];
    return this.extractHighlights(topic, post);
  }

  extractHighlights(topic, post) {
    const root = document.createElement("div");
    root.innerHTML = post.cooked || "";

    const mode = topic._randomHighlightsMode || "excerpt";
    const entries = queryHighlightNodes(root)
      .map((node, index) => this.entryFromTopic(topic, "highlight:" + topic.id + ":" + index, node.textContent || ""))
      .filter((entry) => entry.text);

    if (entries.length) return entries;
    if (mode === "excerpt") return [];

    const fallback = truncateText(htmlToText(post.cooked || topic.excerpt || ""), MAX_EXCERPT_LENGTH);
    return fallback ? [this.entryFromTopic(topic, "topic:" + topic.id, fallback)] : [];
  }

  entryFromTopic(topic, id, text) {
    return {
      id,
      href: topicUrl(topic),
      title: topic.title || topic.fancy_title || "",
      text: truncateText(text || "", MAX_EXCERPT_LENGTH),
      topic
    };
  }

  async fetchNextHighlight() {
    const topics = await this.fetchTaggedTopics();
    let queue = (readJSON(QUEUE_KEY) || []).filter((key) => topics.some((topic) => randomKey(topic) === key));
    if (!queue.length) queue = shuffle(topics.map((topic) => randomKey(topic)).filter(Boolean));

    while (queue.length) {
      const key = queue.shift();
      writeJSON(QUEUE_KEY, queue);

      const topic = topics.find((item) => randomKey(item) === key);
      if (!topic) continue;

      try {
        const entries = await this.fetchEntriesForTopic(topic);
        const entry = shuffle(entries)[0];
        if (entry) return entry;
      } catch (error) {
        // A private or deleted topic should not prevent other sources from rendering.
        // eslint-disable-next-line no-console
        console.warn("random highlights topic failed", error);
      }
    }

    return null;
  }

  <template>
    {{#if this.entry}}
      <tbody class="random-highlights-body">
        <tr class={{this.rowClass}}>
          <td class="main-link clearfix topic-list-data" colspan="1">
            <span class="link-top-line" role="heading" aria-level="2">
              <a href={{this.entry.href}} class="title raw-link raw-topic-link">
                {{this.entry.text}}
                {{#if this.entry.title}}
                  <br><small>{{this.entry.title}}</small>
                {{/if}}
              </a>
            </span>
          </td>

          {{#if this.isDesktop}}
            <td class="posters topic-list-data theme-avatar-small">
              {{#if this.showAvatar}}
                <a href={{this.userPath}} data-user-card={{this.username}} class="latest single">
                  <img alt="" width="24" height="24" src={{this.avatar}} class="avatar latest single" title={{this.username}}>
                </a>
              {{/if}}
            </td>
            <td class="num posts-map posts topic-list-data">
              <a href={{this.entry.href}} class="badge-posts"><span class="number">{{this.postCount}}</span></a>
            </td>
            <td class="num views topic-list-data"><span class="number">{{this.viewCount}}</span></td>
            <td class="activity num topic-list-data age">
              <a href={{this.entry.href}} class="post-activity">
                <span class="relative-date" data-time={{this.activityTime}} data-format="tiny">{{this.activityLabel}}</span>
              </a>
            </td>
          {{/if}}
        </tr>
      </tbody>
    {{/if}}
  </template>
}




