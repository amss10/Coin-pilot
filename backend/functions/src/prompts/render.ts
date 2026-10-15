/**
 * Rendering of user-turn data blocks. Untrusted text (merchant names, payee strings, category
 * names, the user's own words) is always placed inside data tags and XML-escaped, so it can
 * never close a tag or pose as an instruction. Blocks are ordered stable → volatile:
 * categories → corrections/accounts → <context> → items.
 */

import type { Account, Category } from "../schemas/common.js";
import type { RequestContext } from "../schemas/envelope.js";
import type { BetaContentBlockParam } from "../llm/port.js";

export function escapeXml(text: string): string {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

export function escapeAttr(text: string): string {
  return escapeXml(text).replace(/"/g, "&quot;");
}

/** JSON for embedding inside a data tag: `<`, `>` and `&` are unicode-escaped. */
export function jsonForPrompt(value: unknown): string {
  return JSON.stringify(value)
    .replace(/</g, "\\u003c")
    .replace(/>/g, "\\u003e")
    .replace(/&/g, "\\u0026");
}

export function textBlock(text: string): BetaContentBlockParam {
  return { type: "text", text };
}

export function categoriesBlock(categories: readonly Category[]): BetaContentBlockParam {
  const lines = categories.map((c) => {
    const parent = c.parent === null ? "" : ` parent="${escapeAttr(c.parent)}"`;
    return `<category id="${escapeAttr(c.id)}" kind="${c.kind}"${parent}>${escapeXml(c.name)}</category>`;
  });
  return textBlock(`<categories>\n${lines.join("\n")}\n</categories>`);
}

export function accountsBlock(accounts: readonly Account[]): BetaContentBlockParam {
  const lines = accounts.map(
    (a) =>
      `<account id="${escapeAttr(a.id)}" type="${a.type}" currency="${a.currency}">${escapeXml(a.name)}</account>`,
  );
  return textBlock(`<accounts>\n${lines.join("\n")}\n</accounts>`);
}

export function contextBlock(ctx: RequestContext): BetaContentBlockParam {
  return textBlock(
    `<context today="${ctx.today}" locale="${escapeAttr(ctx.locale)}" timezone="${escapeAttr(ctx.timezone)}" currency="${ctx.currency}"/>`,
  );
}
