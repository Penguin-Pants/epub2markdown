const JSZip = require('jszip');
const TurndownService = require('turndown');
const turndownPluginGfm = require('turndown-plugin-gfm');
const fs = require('fs');
const { JSDOM } = require('jsdom');

// Simulate the browser parseEpub logic using jsdom
async function parseEpub(buffer) {
  const zip = await JSZip.loadAsync(buffer);

  const containerXml = await zip.file('META-INF/container.xml').async('string');
  const containerDoc = new JSDOM(containerXml, { contentType: 'application/xml' }).window.document;
  const opfPath = containerDoc.querySelector('rootfile').getAttribute('full-path');
  const opfDir = opfPath.includes('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';

  const opfXml = await zip.file(opfPath).async('string');
  const opfDoc = new JSDOM(opfXml, { contentType: 'application/xml' }).window.document;

  // Metadata
  const getMetaText = (tag) => {
    const el = opfDoc.getElementsByTagNameNS('http://purl.org/dc/elements/1.1/', tag)[0];
    return el ? el.textContent.trim() : '';
  };
  const meta = {
    title: getMetaText('title'),
    author: getMetaText('creator'),
    language: getMetaText('language'),
    publisher: getMetaText('publisher'),
    date: getMetaText('date'),
    description: getMetaText('description'),
  };
  const subjectEls = opfDoc.getElementsByTagNameNS('http://purl.org/dc/elements/1.1/', 'subject');
  meta.tags = [];
  for (let i = 0; i < subjectEls.length; i++) {
    if (subjectEls[i].textContent.trim()) meta.tags.push(subjectEls[i].textContent.trim());
  }

  // Spine
  const manifestItems = {};
  opfDoc.querySelectorAll('manifest item').forEach(item => {
    manifestItems[item.getAttribute('id')] = item.getAttribute('href');
  });
  const spineRefs = [];
  opfDoc.querySelectorAll('spine itemref').forEach(ref => {
    spineRefs.push(ref.getAttribute('idref'));
  });

  function findFootnoteElements(body) {
    const results = [];
    const asides = body.querySelectorAll('aside');
    for (const el of asides) {
      const epubType = el.getAttribute('epub:type') || '';
      if (/footnote|rearnote|endnote/.test(epubType)) { results.push(el); continue; }
      if (el.classList.contains('footnote') || el.classList.contains('endnote')) results.push(el);
    }
    const divs = body.querySelectorAll('div[id], p[id], section[id], span[id]');
    for (const el of divs) {
      const epubType = el.getAttribute('epub:type') || '';
      if (/footnote|rearnote|endnote/.test(epubType)) results.push(el);
    }
    return results;
  }

  // Pass 1: scan all chapters for footnote definitions
  const footnoteMap = new Map();
  let footnoteCounter = 0;

  for (let i = 0; i < spineRefs.length; i++) {
    const href = manifestItems[spineRefs[i]];
    if (!href) continue;
    const filePath = opfDir + decodeURIComponent(href);
    const chapterFile = zip.file(filePath);
    if (!chapterFile) continue;
    try {
      const html = await chapterFile.async('string');
      const doc = new JSDOM(html, { contentType: 'application/xhtml+xml' }).window.document;
      const body = doc.body || doc.documentElement;
      for (const el of findFootnoteElements(body)) {
        const id = el.getAttribute('id');
        if (id && !footnoteMap.has(id)) {
          footnoteCounter++;
          const text = el.textContent.trim().replace(/^\d+[\.\)]\s*/, '');
          footnoteMap.set(id, { num: footnoteCounter, text });
        }
      }
    } catch { /* skip */ }
  }

  // Turndown
  const td = new TurndownService({ headingStyle: 'atx', hr: '---', bulletListMarker: '-', codeBlockStyle: 'fenced', emDelimiter: '*' });
  td.use(turndownPluginGfm.gfm);

  td.addRule('internalLinks', {
    filter: function(node) {
      return node.nodeName === 'A' && node.getAttribute('href') && !/^https?:\/\//i.test(node.getAttribute('href')) && !/^mailto:/i.test(node.getAttribute('href'));
    },
    replacement: function(content) { return content; }
  });

  td.addRule('footnoteRef', {
    filter: function(node) {
      if (node.nodeName !== 'A') return false;
      const href = node.getAttribute('href');
      if (!href) return false;
      const match = href.match(/#(.+)$/);
      return match && footnoteMap.has(match[1]);
    },
    replacement: function(content, node) {
      const href = node.getAttribute('href');
      const id = href.match(/#(.+)$/)[1];
      return '[^' + footnoteMap.get(id).num + ']';
    }
  });

  // Pass 2: convert chapters
  const chapters = [];

  for (let i = 0; i < spineRefs.length; i++) {
    const href = manifestItems[spineRefs[i]];
    if (!href) continue;
    const filePath = opfDir + decodeURIComponent(href);
    const chapterFile = zip.file(filePath);
    if (!chapterFile) { chapters.push('<!-- Chapter ' + (i+1) + ' could not be converted -->'); continue; }

    try {
      const html = await chapterFile.async('string');
      const doc = new JSDOM(html, { contentType: 'application/xhtml+xml' }).window.document;
      const body = doc.body || doc.documentElement;

      body.querySelectorAll('style, script, link').forEach(el => el.remove());
      body.querySelectorAll('img, svg, figure, picture').forEach(el => el.remove());
      for (const el of findFootnoteElements(body)) el.remove();

      const md = td.turndown(body.innerHTML);
      chapters.push(md);
    } catch (e) {
      chapters.push('<!-- Chapter ' + (i+1) + ' could not be converted -->');
    }
  }

  let fullMarkdown = chapters.join('\n\n---\n\n');

  if (footnoteMap.size > 0) {
    fullMarkdown += '\n\n';
    const sortedFn = [...footnoteMap.values()].sort((a, b) => a.num - b.num);
    for (const fn of sortedFn) {
      fullMarkdown += '[^' + fn.num + ']: ' + fn.text + '\n';
    }
  }

  fullMarkdown = fullMarkdown.replace(/\n{3,}/g, '\n\n');

  let frontMatter = '---\n';
  frontMatter += 'title: "' + meta.title + '"\n';
  if (meta.author) frontMatter += 'author: "' + meta.author + '"\n';
  if (meta.language) frontMatter += 'language: "' + meta.language + '"\n';
  if (meta.publisher) frontMatter += 'publisher: "' + meta.publisher + '"\n';
  if (meta.date) frontMatter += 'date: "' + meta.date + '"\n';
  if (meta.description) frontMatter += 'description: "' + meta.description + '"\n';
  if (meta.tags.length > 0) frontMatter += 'tags: [' + meta.tags.map(t => '"' + t + '"').join(', ') + ']\n';
  frontMatter += '---\n\n';

  return frontMatter + fullMarkdown;
}

async function runTests() {
  let passed = 0, failed = 0;

  function assert(condition, msg) {
    if (condition) { passed++; console.log('  ✓ ' + msg); }
    else { failed++; console.log('  ✗ ' + msg); }
  }

  console.log('Testing EPUB converter...\n');

  const buf = fs.readFileSync('test/test-book.epub');
  const md = await parseEpub(buf);

  console.log('--- Output ---');
  console.log(md);
  console.log('--- Tests ---');

  // Front matter
  assert(md.startsWith('---\n'), 'Starts with YAML front matter');
  assert(md.includes('title: "Test Book Title"'), 'Has title');
  assert(md.includes('author: "Jane Author"'), 'Has author');
  assert(md.includes('language: "en"'), 'Has language');
  assert(md.includes('publisher: "Test Press"'), 'Has publisher');
  assert(md.includes('date: "2024-03-15"'), 'Has date');
  assert(md.includes('description: "A test book for the converter."'), 'Has description');
  assert(md.includes('tags: ["testing", "epub"]'), 'Has tags');

  // Chapter content
  assert(md.includes('# The Beginning'), 'Has h1 heading');
  assert(md.includes('**first**'), 'Bold preserved');
  assert(md.includes('*italic*') || md.includes('_italic_'), 'Italic preserved');
  assert(md.includes('[a link](https://example.com)'), 'External link preserved');
  assert(md.includes('Item one') && md.includes('-'), 'Unordered list');
  assert(md.includes('> A wise quote'), 'Blockquote');

  // Chapter 2
  assert(md.includes('# Tables and Code'), 'Chapter 2 heading');
  assert(md.includes('| Name'), 'Table present');
  assert(md.includes('Alpha'), 'Table data');
  assert(md.includes('function hello()'), 'Code block');
  assert(md.includes('~~strikethrough~~'), 'Strikethrough');
  assert(md.includes('[external link](https://example.org)'), 'External link in ch2');
  assert(!md.includes('[internal link](chapter1.xhtml)'), 'Internal link converted to plain text');
  assert(md.includes('## A Subsection'), 'H2 preserved');

  // Images stripped
  assert(!md.includes('image.jpg'), 'Images stripped');
  assert(!md.includes('<img'), 'No img tags');
  assert(!md.includes('<svg'), 'No svg tags');
  assert(!md.includes('<figure'), 'No figure tags');

  // Script/style stripped
  assert(!md.includes('alert'), 'Script stripped');
  assert(!md.includes('font-family'), 'Style stripped');

  // Separators
  assert(md.includes('\n\n---\n\n'), 'Chapter separator');

  // Footnotes
  assert(md.includes('[^1]'), 'Footnote reference');
  assert(md.includes('[^1]:'), 'Footnote definition');

  console.log(`\nResults: ${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

runTests().catch(e => { console.error(e); process.exit(1); });
