#!/usr/bin/env node
/**
 * elk-to-svg.mjs — Render an ELK JSON graph to SVG.
 *
 * Usage:
 *   node elk-to-svg.mjs input.json [output.svg]
 *   cat input.json | node elk-to-svg.mjs > output.svg
 *
 * Requires: npm install -g elkjs  (or install locally where you run this)
 */

import { readFileSync, writeFileSync, existsSync } from "fs";
import { createRequire } from "module";
import { execSync } from "child_process";
import { join } from "path";

// Resolve elkjs: try local, then common global locations
let ELK;
const require = createRequire(import.meta.url);
try {
  ELK = require("elkjs");
} catch {
  // Probe common global node_modules paths
  const candidates = [
    "/opt/homebrew/lib/node_modules",          // macOS Homebrew ARM
    "/usr/local/lib/node_modules",             // macOS Homebrew Intel / Linux
    join(process.env.HOME || "", ".bun/install/global/node_modules"),
    join(process.env.HOME || "", ".npm-global/lib/node_modules"),
    join(process.env.HOME || "", ".local/lib/node_modules"),
  ];
  let found = false;
  for (const dir of candidates) {
    if (existsSync(join(dir, "elkjs"))) {
      try {
        ELK = createRequire(join(dir, "_"))("elkjs");
        found = true;
        break;
      } catch { /* continue */ }
    }
  }
  if (!found) {
    console.error("Error: elkjs not found. Install it globally (e.g. npm install -g elkjs)");
    process.exit(1);
  }
}

const elk = new ELK();

// --- Read input ---
let inputJson;
if (process.argv[2] && process.argv[2] !== "-") {
  inputJson = readFileSync(process.argv[2], "utf-8");
} else {
  inputJson = readFileSync(0, "utf-8"); // stdin
}

const graph = JSON.parse(inputJson);

// --- Layout ---
const laid = await elk.layout(graph);

// --- Render SVG ---
const PAD = 40;
const FONT_SIZE = 13;
const LABEL_FONT_SIZE = 11;
const NODE_RX = 6;
const EDGE_COLOR = "#555";
const NODE_FILL = "#f0f4ff";
const NODE_STROKE = "#3b5998";
const GROUP_FILL = "#fafafa";
const GROUP_STROKE = "#bbb";

function escapeXml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

let svgBody = "";

function renderNodes(nodes, offsetX = 0, offsetY = 0) {
  for (const node of nodes || []) {
    const x = (node.x || 0) + offsetX;
    const y = (node.y || 0) + offsetY;
    const w = node.width || 120;
    const h = node.height || 50;
    const label = node.labels?.[0]?.text || node.id;
    const isGroup = node.children && node.children.length > 0;

    svgBody += `  <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${NODE_RX}" `;
    svgBody += `fill="${isGroup ? GROUP_FILL : NODE_FILL}" stroke="${isGroup ? GROUP_STROKE : NODE_STROKE}" stroke-width="1.5"/>\n`;

    const labelY = isGroup ? y + 18 : y + h / 2 + FONT_SIZE / 3;
    const labelX = x + w / 2;
    svgBody += `  <text x="${labelX}" y="${labelY}" text-anchor="middle" `;
    svgBody += `font-family="Inter, system-ui, sans-serif" font-size="${FONT_SIZE}" `;
    svgBody += `font-weight="${isGroup ? 600 : 500}" fill="#222">${escapeXml(label)}</text>\n`;

    if (isGroup) {
      renderNodes(node.children, x, y);
    }
  }
}

function renderEdges(edges, nodes, offsetX = 0, offsetY = 0) {
  for (const edge of edges || []) {
    const sections = edge.sections || [];
    for (const sec of sections) {
      const points = [sec.startPoint, ...(sec.bendPoints || []), sec.endPoint];
      const d = points
        .map((p, i) => `${i === 0 ? "M" : "L"}${(p.x || 0) + offsetX} ${(p.y || 0) + offsetY}`)
        .join(" ");
      svgBody += `  <path d="${d}" fill="none" stroke="${EDGE_COLOR}" stroke-width="1.5" marker-end="url(#arrow)"/>\n`;

      if (edge.labels?.[0]?.text) {
        const mid = points[Math.floor(points.length / 2)];
        svgBody += `  <text x="${(mid.x || 0) + offsetX}" y="${(mid.y || 0) + offsetY - 5}" `;
        svgBody += `text-anchor="middle" font-family="Inter, system-ui, sans-serif" `;
        svgBody += `font-size="${LABEL_FONT_SIZE}" fill="#777">${escapeXml(edge.labels[0].text)}</text>\n`;
      }
    }
  }

  for (const node of nodes || []) {
    if (node.children) {
      renderEdges(
        node.edges,
        node.children,
        (node.x || 0) + offsetX,
        (node.y || 0) + offsetY
      );
    }
  }
}

renderNodes(laid.children);
renderEdges(laid.edges, laid.children);

const totalW = (laid.width || 600) + PAD * 2;
const totalH = (laid.height || 400) + PAD * 2;

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${totalW}" height="${totalH}" viewBox="${-PAD} ${-PAD} ${totalW} ${totalH}">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="${EDGE_COLOR}"/>
    </marker>
  </defs>
${svgBody}</svg>`;

if (process.argv[3]) {
  writeFileSync(process.argv[3], svg);
  console.error(`Wrote ${process.argv[3]}`);
} else {
  process.stdout.write(svg);
}
