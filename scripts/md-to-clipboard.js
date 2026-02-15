#!/usr/bin/env node
// Convert markdown article to HTML and copy to clipboard for Medium pasting
// Usage: node md-to-clipboard.js <article-file.md> [--skip-title]

const fs = require('fs');
const { execSync } = require('child_process');

const filePath = process.argv[2];
const skipTitle = process.argv.includes('--skip-title');

if (!filePath) {
  console.error('Usage: node md-to-clipboard.js <article-file.md> [--skip-title]');
  process.exit(1);
}

let md = fs.readFileSync(filePath, 'utf-8');

// Remove title (first # line) if --skip-title
if (skipTitle) {
  md = md.replace(/^# .+\n\n?/, '');
}

// Remove image placeholder lines
md = md.replace(/!\[.*?\]\(https:\/\/via\.placeholder\.com[^)]*\)\n?\n?/g, '');

// Process code blocks first (protect them from other transformations)
const codeBlocks = [];
md = md.replace(/```(\w*)\n([\s\S]*?)```/g, (match, lang, code) => {
  const idx = codeBlocks.length;
  // Escape HTML in code blocks
  const escaped = code
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  codeBlocks.push(`<pre><code>${escaped}</code></pre>`);
  return `%%CODEBLOCK_${idx}%%`;
});

// Process inline code (protect from other transformations)
const inlineCodes = [];
md = md.replace(/`([^`]+)`/g, (match, code) => {
  const idx = inlineCodes.length;
  const escaped = code.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  inlineCodes.push(`<code>${escaped}</code>`);
  return `%%INLINE_${idx}%%`;
});

// Convert headers
md = md.replace(/^#### (.+)$/gm, '<h4>$1</h4>');
md = md.replace(/^### (.+)$/gm, '<h3>$1</h3>');
md = md.replace(/^## (.+)$/gm, '<h2>$1</h2>');

// Convert bold+italic
md = md.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>');
// Convert bold
md = md.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
// Convert italic (but not within URLs or already processed tags)
md = md.replace(/(?<![\\/<])\*([^*\n]+)\*(?![>])/g, '<em>$1</em>');

// Convert links
md = md.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');

// Convert blockquotes (multi-line)
md = md.replace(/^> (.+)$/gm, '<blockquote>$1</blockquote>');
// Merge consecutive blockquotes
md = md.replace(/<\/blockquote>\n<blockquote>/g, '<br>');

// Convert horizontal rules
md = md.replace(/^---$/gm, '<hr>');

// Convert ordered lists
md = md.replace(/^\d+\. (.+)$/gm, '<oli>$1</oli>');

// Convert unordered lists (handle nested with spaces/tabs)
md = md.replace(/^  - (.+)$/gm, '<sli>$1</sli>');
md = md.replace(/^- (.+)$/gm, '<uli>$1</uli>');

// Now process line by line to build proper HTML
const lines = md.split('\n');
const result = [];
let inUl = false;
let inOl = false;
let inSubUl = false;

for (let i = 0; i < lines.length; i++) {
  let line = lines[i].trim();

  if (line === '') {
    if (inSubUl) { result.push('</ul>'); inSubUl = false; }
    if (inUl) { result.push('</ul>'); inUl = false; }
    if (inOl) { result.push('</ol>'); inOl = false; }
    continue;
  }

  if (line.startsWith('<uli>')) {
    if (!inUl) { result.push('<ul>'); inUl = true; }
    if (inSubUl) { result.push('</ul>'); inSubUl = false; }
    result.push('<li>' + line.slice(5, -6) + '</li>');
    continue;
  }

  if (line.startsWith('<sli>')) {
    if (!inSubUl) { result.push('<ul>'); inSubUl = true; }
    result.push('<li>' + line.slice(5, -6) + '</li>');
    continue;
  }

  if (line.startsWith('<oli>')) {
    if (!inOl) { result.push('<ol>'); inOl = true; }
    result.push('<li>' + line.slice(5, -6) + '</li>');
    continue;
  }

  // Close any open lists
  if (inSubUl) { result.push('</ul>'); inSubUl = false; }
  if (inUl) { result.push('</ul>'); inUl = false; }
  if (inOl) { result.push('</ol>'); inOl = false; }

  // Already-tagged lines
  if (line.startsWith('<h') || line.startsWith('<hr') || line.startsWith('<blockquote') ||
      line.startsWith('<pre') || line.startsWith('%%CODEBLOCK')) {
    result.push(line);
    continue;
  }

  // Everything else is a paragraph
  if (line.length > 0) {
    result.push('<p>' + line + '</p>');
  }
}

// Close any remaining open lists
if (inSubUl) result.push('</ul>');
if (inUl) result.push('</ul>');
if (inOl) result.push('</ol>');

let html = result.join('\n');

// Restore code blocks
html = html.replace(/%%CODEBLOCK_(\d+)%%/g, (m, idx) => codeBlocks[parseInt(idx)]);
// Unwrap code blocks from paragraphs
html = html.replace(/<p>(%%CODEBLOCK_\d+%%)<\/p>/g, '$1');

// Restore inline code
html = html.replace(/%%INLINE_(\d+)%%/g, (m, idx) => inlineCodes[parseInt(idx)]);

// Clean up: remove empty paragraphs
html = html.replace(/<p><\/p>/g, '');

// Escape ampersands in text (not in tags)
html = html.replace(/&(?!amp;|lt;|gt;|#\d+;|[a-zA-Z]+;)/g, '&amp;');

// Copy to clipboard as HTML using AppleScript (macOS)
// pbcopy only supports plain text, so we use osascript with temp file for HTML clipboard
const os = require('os');
const path = require('path');
const hexData = Buffer.from(html, 'utf-8').toString('hex');
const script = `set the clipboard to {«class HTML»:«data HTML${hexData}»}`;
const tmpFile = path.join(os.tmpdir(), `md-clipboard-${Date.now()}.scpt`);
try {
  fs.writeFileSync(tmpFile, script, 'utf-8');
  execSync(`osascript "${tmpFile}"`);
  fs.unlinkSync(tmpFile);
  console.log(`Copied ${html.length} chars of HTML to clipboard (hex: ${hexData.length} chars)`);
} catch (e) {
  try { fs.unlinkSync(tmpFile); } catch (_) {}
  // Fallback: use pbcopy with plain text
  execSync('pbcopy', { input: html });
  console.log(`Copied ${html.length} chars as plain text to clipboard (HTML clipboard failed: ${e.message})`);
}
