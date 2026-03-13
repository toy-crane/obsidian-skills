/**
 * Unified content extraction using Defuddle.
 *
 * Usage:
 *   bun .claude/skills/save/scripts/defuddle.ts <url>
 *
 * Env:
 *   SAVE_CTX - output directory (default: .context)
 *
 * Output:
 *   $SAVE_CTX/extracted.txt  - extracted content (markdown or transcript)
 *   $SAVE_CTX/meta.json      - metadata (type, title, url, language, ...)
 *
 * Exit codes:
 *   0 = success
 *   1 = failure
 *   2 = content too short (<200 chars) — caller should try Firecrawl fallback
 */

import { Defuddle } from "defuddle/node";
import { JSDOM } from "jsdom";
import { writeFile, mkdir } from "fs/promises";
import { join } from "path";

const url = Bun.argv[2];
if (!url) {
  console.error("Usage: defuddle.ts <url>");
  process.exit(1);
}

const outDir = process.env.SAVE_CTX || ".context";

function detectType(url: string, domain: string, hasTranscript: boolean): string {
  if (domain.includes("youtube.com") || domain.includes("youtu.be")) return "youtube";
  if (domain.includes("x.com") || domain.includes("twitter.com")) {
    // X articles have /article/ in the URL
    if (url.includes("/article/")) return "x-article";
    return "x-post";
  }
  // Fallback: if has transcript variables, likely YouTube (after redirect)
  if (hasTranscript) return "youtube";
  return "webpage";
}

try {
  // Fetch page with JSDOM
  const dom = await JSDOM.fromURL(url, {
    userAgent:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  });

  // Extract with Defuddle
  const result = await Defuddle(dom, url, {
    separateMarkdown: true,
    useAsync: true,
  });

  const type = detectType(url, result.domain || "", Boolean(result.variables?.transcript));

  // Select content based on type
  let content: string;
  if (type === "youtube" && result.variables?.transcript) {
    content = result.variables.transcript;
  } else {
    content = result.contentMarkdown || result.content || "";
  }

  // Ensure output directory exists
  await mkdir(outDir, { recursive: true });

  // Write extracted content
  const extractedPath = join(outDir, "extracted.txt");
  await writeFile(extractedPath, content, "utf-8");

  // Compute content stats
  const contentLines = content.split("\n").length;
  const contentChars = content.length;

  // Build metadata
  const meta: Record<string, unknown> = {
    type,
    title: result.title || "",
    url,
    language: result.variables?.language || result.language || "unknown",
    content_lines: contentLines,
    content_chars: contentChars,
  };

  // Type-specific fields
  if (type === "youtube") {
    meta.channel = result.variables?.author || result.author || "";
    meta.duration = 0; // Defuddle doesn't provide duration
  }

  if (type === "x-post" || type === "x-article") {
    const author = result.author || "";
    meta.author = author;
    meta.timestamp = result.published || "";
    // Compose title as "author: content_preview" for X posts
    if (type === "x-post" && author) {
      meta.title = `${author}: ${(result.title || content.slice(0, 60)).replace(/\n/g, " ")}`;
    }
  }

  // Write meta.json
  const metaPath = join(outDir, "meta.json");
  await writeFile(metaPath, JSON.stringify(meta, null, 2), "utf-8");

  // Check content length for fallback signal
  if (contentChars < 200) {
    console.error(
      `Content too short (${contentChars} chars), fallback recommended`
    );
    process.exit(2);
  }

  console.error(
    `Extracted ${type} to ${extractedPath} (${contentLines} lines, ${contentChars} chars)`
  );
  process.exit(0);
} catch (err: any) {
  console.error(`Error: ${err.message}`);
  process.exit(1);
}
