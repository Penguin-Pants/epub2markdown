#!/bin/bash
# Build script: assembles index.html with inlined libraries
set -e

JSZIP=$(cat node_modules/jszip/dist/jszip.min.js)
TURNDOWN=$(cat node_modules/turndown/dist/turndown.js)
TURNDOWN_GFM=$(cat node_modules/turndown-plugin-gfm/dist/turndown-plugin-gfm.js)

cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>EPUB → Markdown</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  background: #fafafa; color: #333; line-height: 1.6;
  min-height: 100vh;
}
.container { max-width: 800px; margin: 0 auto; padding: 2rem 1.5rem; }
header { text-align: center; margin-bottom: 2rem; }
header h1 { font-size: 1.75rem; font-weight: 700; color: #111; }
header p { color: #666; font-size: 0.95rem; margin-top: 0.25rem; }

.drop-zone {
  border: 2px dashed #ccc; border-radius: 12px; padding: 3rem 2rem;
  text-align: center; cursor: pointer; transition: all 0.2s;
  background: #fff; position: relative;
}
.drop-zone:hover { border-color: #999; background: #f5f5f5; }
.drop-zone.drag-over { border-style: solid; border-color: #4a90d9; background: #eef4fb; }
.drop-zone p { color: #888; font-size: 1rem; pointer-events: none; }
.drop-zone input { display: none; }

.file-list { margin-top: 1.5rem; }
.file-item {
  background: #fff; border: 1px solid #e5e5e5; border-radius: 8px;
  padding: 0.75rem 1rem; margin-bottom: 0.5rem;
  display: flex; align-items: center; gap: 0.75rem; flex-wrap: wrap;
}
.file-info { flex: 1; min-width: 0; }
.file-title { font-weight: 600; font-size: 0.95rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.file-author { color: #888; font-size: 0.85rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.file-error { color: #c0392b; font-size: 0.8rem; margin-top: 0.25rem; }

.badge {
  font-size: 0.75rem; padding: 0.2rem 0.6rem; border-radius: 999px;
  font-weight: 600; white-space: nowrap; flex-shrink: 0;
}
.badge-queued { background: #eee; color: #888; }
.badge-converting { background: #fff3cd; color: #856404; }
.badge-done { background: #d4edda; color: #155724; }
.badge-saved { background: #cce5ff; color: #004085; }
.badge-error { background: #f8d7da; color: #721c24; }

.btn {
  display: inline-flex; align-items: center; gap: 0.4rem;
  padding: 0.4rem 0.9rem; border-radius: 6px; border: none;
  font-size: 0.85rem; font-weight: 600; cursor: pointer; transition: background 0.15s;
  text-decoration: none; white-space: nowrap; flex-shrink: 0;
}
.btn-primary { background: #4a90d9; color: #fff; }
.btn-primary:hover { background: #357abd; }
.btn-secondary { background: #e9ecef; color: #495057; }
.btn-secondary:hover { background: #dee2e6; }
.btn-danger { background: #e9ecef; color: #c0392b; }
.btn-danger:hover { background: #f8d7da; }
.btn:disabled { opacity: 0.5; cursor: not-allowed; }

.batch-bar {
  display: none; margin-top: 1rem; padding: 1rem;
  background: #fff; border: 1px solid #e5e5e5; border-radius: 8px;
  gap: 0.5rem; align-items: center; flex-wrap: wrap;
}
.batch-bar.visible { display: flex; }
.batch-bar .spacer { flex: 1; }

.dir-bar {
  display: none; margin-top: 0.75rem; padding: 0.75rem 1rem;
  background: #f0f7ff; border: 1px solid #b8d4f0; border-radius: 8px;
  align-items: center; gap: 0.5rem; font-size: 0.85rem;
}
.dir-bar.visible { display: flex; }
.dir-bar .dir-name { font-weight: 600; color: #004085; flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

.toast-container { position: fixed; bottom: 1.5rem; right: 1.5rem; z-index: 1000; display: flex; flex-direction: column; gap: 0.5rem; }
.toast {
  background: #333; color: #fff; padding: 0.6rem 1rem; border-radius: 8px;
  font-size: 0.85rem; opacity: 0; transform: translateY(10px);
  animation: toastIn 0.3s forwards;
  max-width: 350px;
}
.toast.error { background: #c0392b; }
.toast.warning { background: #e67e22; }
@keyframes toastIn { to { opacity: 1; transform: translateY(0); } }

.size-warning {
  background: #fff3cd; border: 1px solid #ffc107; border-radius: 8px;
  padding: 0.75rem 1rem; margin-bottom: 0.5rem; font-size: 0.85rem;
  display: flex; align-items: center; gap: 0.75rem;
}
.size-warning .btn { flex-shrink: 0; }
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>EPUB → Markdown</h1>
    <p>Convert EPUB files to Markdown entirely in your browser. No upload, no server.</p>
  </header>

  <div class="drop-zone" id="dropZone">
    <p>Drag &amp; drop .epub files here, or click to browse</p>
    <input type="file" id="fileInput" accept=".epub" multiple>
  </div>

  <div class="dir-bar" id="dirBar">
    <span>Saving to:</span>
    <span class="dir-name" id="dirName"></span>
    <button class="btn btn-secondary" id="changeDirBtn" style="font-size:0.8rem;padding:0.3rem 0.6rem;">Change</button>
    <button class="btn btn-danger" id="clearDirBtn" style="font-size:0.8rem;padding:0.3rem 0.6rem;">Stop</button>
  </div>

  <div class="file-list" id="fileList"></div>

  <div class="batch-bar" id="batchBar">
    <button class="btn btn-primary" id="downloadAllBtn">Download All as ZIP</button>
    <button class="btn btn-secondary" id="saveFolderBtn" style="display:none;">Save to folder…</button>
    <span class="spacer"></span>
    <button class="btn btn-danger" id="clearAllBtn">Clear All</button>
  </div>
</div>
<div class="toast-container" id="toastContainer"></div>

HTMLEOF

# Inline libraries
echo '<script>' >> index.html
echo "/* JSZip v3.10.1 */" >> index.html
cat node_modules/jszip/dist/jszip.min.js >> index.html
echo '' >> index.html
echo '</script>' >> index.html

echo '<script>' >> index.html
echo "/* Turndown v7.2.0 */" >> index.html
cat node_modules/turndown/dist/turndown.js >> index.html
echo '' >> index.html
echo '</script>' >> index.html

echo '<script>' >> index.html
echo "/* turndown-plugin-gfm v1.0.2 */" >> index.html
cat node_modules/turndown-plugin-gfm/dist/turndown-plugin-gfm.js >> index.html
echo '' >> index.html
echo '</script>' >> index.html

cat >> index.html << 'APPEOF'
<script>
(function() {
  'use strict';

  const dropZone = document.getElementById('dropZone');
  const fileInput = document.getElementById('fileInput');
  const fileList = document.getElementById('fileList');
  const batchBar = document.getElementById('batchBar');
  const downloadAllBtn = document.getElementById('downloadAllBtn');
  const clearAllBtn = document.getElementById('clearAllBtn');
  const saveFolderBtn = document.getElementById('saveFolderBtn');
  const dirBar = document.getElementById('dirBar');
  const dirName = document.getElementById('dirName');
  const changeDirBtn = document.getElementById('changeDirBtn');
  const clearDirBtn = document.getElementById('clearDirBtn');
  const toastContainer = document.getElementById('toastContainer');

  let files = [];
  let processing = false;
  let directoryHandle = null;
  const hasFileSystemAccess = 'showDirectoryPicker' in window;

  if (hasFileSystemAccess) {
    saveFolderBtn.style.display = '';
  }

  // Toast
  function showToast(msg, type) {
    const t = document.createElement('div');
    t.className = 'toast' + (type ? ' ' + type : '');
    t.textContent = msg;
    toastContainer.appendChild(t);
    setTimeout(() => { t.style.opacity = '0'; t.style.transform = 'translateY(10px)'; setTimeout(() => t.remove(), 300); }, 3500);
  }

  // File naming
  function sanitizeFilename(title) {
    let s = title.replace(/[^\w\s\-]/g, '').trim().replace(/\s+/g, '-').toLowerCase();
    return s || 'untitled';
  }

  function deduplicateFilename(name, existing) {
    if (!existing.has(name)) return name;
    let i = 2;
    while (existing.has(name + '-' + i)) i++;
    return name + '-' + i;
  }

  // Drop zone
  dropZone.addEventListener('click', () => fileInput.click());
  dropZone.addEventListener('dragover', e => { e.preventDefault(); dropZone.classList.add('drag-over'); });
  dropZone.addEventListener('dragleave', () => dropZone.classList.remove('drag-over'));
  dropZone.addEventListener('drop', e => {
    e.preventDefault();
    dropZone.classList.remove('drag-over');
    handleFiles(e.dataTransfer.files);
  });
  fileInput.addEventListener('change', e => { handleFiles(e.target.files); fileInput.value = ''; });

  function handleFiles(fileObjs) {
    let added = 0;
    for (const f of fileObjs) {
      if (!f.name.toLowerCase().endsWith('.epub')) {
        showToast(`"${f.name}" is not an .epub file`, 'error');
        continue;
      }
      const entry = {
        id: Date.now() + '-' + Math.random().toString(36).slice(2),
        file: f,
        name: f.name,
        title: f.name.replace(/\.epub$/i, ''),
        author: '',
        status: 'queued',
        error: null,
        markdown: null,
        outputName: null,
        sizeWarningDismissed: f.size <= 100 * 1024 * 1024,
      };
      files.push(entry);
      added++;
    }
    if (added > 0) {
      renderList();
      processQueue();
    }
  }

  // Render
  function renderList() {
    fileList.innerHTML = '';
    const usedNames = new Set();

    for (const f of files) {
      if (f.outputName) usedNames.add(f.outputName.replace(/\.md$/, ''));
    }

    for (const f of files) {
      const row = document.createElement('div');
      row.className = 'file-item';
      row.id = 'file-' + f.id;

      const info = document.createElement('div');
      info.className = 'file-info';
      const titleEl = document.createElement('div');
      titleEl.className = 'file-title';
      titleEl.textContent = f.title;
      info.appendChild(titleEl);
      if (f.author) {
        const authorEl = document.createElement('div');
        authorEl.className = 'file-author';
        authorEl.textContent = f.author;
        info.appendChild(authorEl);
      }
      if (f.status === 'error' && f.error) {
        const errEl = document.createElement('div');
        errEl.className = 'file-error';
        errEl.textContent = f.error;
        info.appendChild(errEl);
      }
      row.appendChild(info);

      const badgeClass = { queued: 'badge-queued', converting: 'badge-converting', done: 'badge-done', saved: 'badge-saved', error: 'badge-error' };
      const badgeText = { queued: 'Queued', converting: 'Converting…', done: 'Done', saved: 'Saved', error: 'Error' };
      const badge = document.createElement('span');
      badge.className = 'badge ' + (badgeClass[f.status] || 'badge-queued');
      badge.textContent = badgeText[f.status] || f.status;
      row.appendChild(badge);

      if (f.status === 'done' && f.markdown) {
        const dlBtn = document.createElement('button');
        dlBtn.className = 'btn btn-primary';
        dlBtn.textContent = 'Download .md';
        dlBtn.addEventListener('click', () => downloadSingle(f));
        row.appendChild(dlBtn);
      }

      fileList.appendChild(row);

      if (!f.sizeWarningDismissed && f.status === 'queued') {
        const warn = document.createElement('div');
        warn.className = 'size-warning';
        warn.innerHTML = `<span>⚠ "${f.name}" is over 100 MB. Processing may be slow.</span>`;
        const procBtn = document.createElement('button');
        procBtn.className = 'btn btn-primary';
        procBtn.textContent = 'Continue';
        procBtn.addEventListener('click', () => { f.sizeWarningDismissed = true; renderList(); processQueue(); });
        warn.appendChild(procBtn);
        fileList.appendChild(warn);
      }
    }

    const doneCount = files.filter(f => f.status === 'done' || f.status === 'saved').length;
    if (doneCount > 0) {
      batchBar.classList.add('visible');
    } else {
      batchBar.classList.remove('visible');
    }

    dirBar.classList.toggle('visible', !!directoryHandle);
  }

  // EPUB parsing
  async function parseEpub(file) {
    const buf = await file.arrayBuffer();
    let zip;
    try {
      zip = await JSZip.loadAsync(buf);
    } catch {
      throw new Error('Not a valid EPUB file');
    }

    const containerFile = zip.file('META-INF/container.xml');
    if (!containerFile) throw new Error('Could not read EPUB structure');
    const containerXml = await containerFile.async('string');
    const containerDoc = new DOMParser().parseFromString(containerXml, 'application/xml');
    const rootfileEl = containerDoc.querySelector('rootfile');
    if (!rootfileEl) throw new Error('Could not read EPUB structure');
    const opfPath = rootfileEl.getAttribute('full-path');
    if (!opfPath) throw new Error('Could not read EPUB structure');

    const opfFile = zip.file(opfPath);
    if (!opfFile) throw new Error('Could not read EPUB structure');
    const opfXml = await opfFile.async('string');
    const opfDoc = new DOMParser().parseFromString(opfXml, 'application/xml');

    const opfDir = opfPath.includes('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';

    // Metadata
    const meta = {};
    const getMetaText = (tag) => {
      const el = opfDoc.querySelector('metadata ' + tag) ||
                 opfDoc.getElementsByTagNameNS('http://purl.org/dc/elements/1.1/', tag)[0];
      return el ? el.textContent.trim() : '';
    };
    meta.title = getMetaText('title') || file.name.replace(/\.epub$/i, '');
    meta.author = getMetaText('creator') || '';
    meta.language = getMetaText('language') || '';
    meta.publisher = getMetaText('publisher') || '';
    meta.date = getMetaText('date') || '';
    meta.description = getMetaText('description') || '';

    const subjectEls = opfDoc.querySelectorAll('metadata subject');
    const subjectNS = opfDoc.getElementsByTagNameNS('http://purl.org/dc/elements/1.1/', 'subject');
    const subjects = new Set();
    subjectEls.forEach(el => { if (el.textContent.trim()) subjects.add(el.textContent.trim()); });
    for (let i = 0; i < subjectNS.length; i++) { if (subjectNS[i].textContent.trim()) subjects.add(subjectNS[i].textContent.trim()); }
    meta.tags = [...subjects];

    // Spine + manifest
    const manifestItems = {};
    opfDoc.querySelectorAll('manifest item').forEach(item => {
      manifestItems[item.getAttribute('id')] = item.getAttribute('href');
    });
    const spineRefs = [];
    opfDoc.querySelectorAll('spine itemref').forEach(ref => {
      spineRefs.push(ref.getAttribute('idref'));
    });

    function isExternalLink(href) {
      return /^https?:\/\//i.test(href) || /^mailto:/i.test(href);
    }

    function findFootnoteElements(body) {
      const results = [];
      const asides = body.querySelectorAll('aside');
      for (const el of asides) {
        const epubType = el.getAttribute('epub:type') || el.getAttributeNS('http://www.idpf.org/2007/ops', 'type') || '';
        if (/footnote|rearnote|endnote/.test(epubType)) {
          results.push(el);
          continue;
        }
        if (el.classList.contains('footnote') || el.classList.contains('endnote')) {
          results.push(el);
        }
      }
      const divs = body.querySelectorAll('div[id], p[id], section[id], span[id]');
      for (const el of divs) {
        const epubType = el.getAttribute('epub:type') || el.getAttributeNS('http://www.idpf.org/2007/ops', 'type') || '';
        if (/footnote|rearnote|endnote/.test(epubType)) {
          results.push(el);
        }
      }
      return results;
    }

    // Pass 1: scan all chapters for footnote definitions
    const footnoteMap = new Map();
    let footnoteCounter = 0;

    for (let i = 0; i < spineRefs.length; i++) {
      const idref = spineRefs[i];
      const href = manifestItems[idref];
      if (!href) continue;
      const filePath = opfDir + decodeURIComponent(href);
      const chapterFile = zip.file(filePath);
      if (!chapterFile) continue;
      try {
        const html = await chapterFile.async('string');
        const doc = new DOMParser().parseFromString(html, 'application/xhtml+xml');
        const body = doc.body || doc.querySelector('body') || doc.documentElement;
        for (const el of findFootnoteElements(body)) {
          const id = el.getAttribute('id');
          if (id && !footnoteMap.has(id)) {
            footnoteCounter++;
            const text = el.textContent.trim().replace(/^\d+[\.\)]\s*/, '');
            footnoteMap.set(id, { num: footnoteCounter, text: text });
          }
        }
      } catch { /* skip */ }
    }

    // Setup Turndown
    const td = new TurndownService({ headingStyle: 'atx', hr: '---', bulletListMarker: '-', codeBlockStyle: 'fenced', emDelimiter: '*' });
    td.use(turndownPluginGfm.gfm);

    // Convert internal EPUB links to plain text (added first = lower priority)
    td.addRule('internalLinks', {
      filter: function(node) {
        return node.nodeName === 'A' && node.getAttribute('href') && !isExternalLink(node.getAttribute('href'));
      },
      replacement: function(content) {
        return content;
      }
    });

    // Footnote reference links → [^n] (added last = highest priority)
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

    // Pass 2: convert each spine item
    const chapters = [];

    for (let i = 0; i < spineRefs.length; i++) {
      const idref = spineRefs[i];
      const href = manifestItems[idref];
      if (!href) continue;

      const filePath = opfDir + decodeURIComponent(href);
      const chapterFile = zip.file(filePath);
      if (!chapterFile) {
        chapters.push('<!-- Chapter ' + (i + 1) + ' could not be converted -->');
        continue;
      }

      try {
        const html = await chapterFile.async('string');

        const doc = new DOMParser().parseFromString(html, 'application/xhtml+xml');
        const body = doc.body || doc.querySelector('body') || doc.documentElement;

        body.querySelectorAll('style, script, link').forEach(el => el.remove());
        body.querySelectorAll('img, svg, figure, picture').forEach(el => el.remove());

        for (const el of findFootnoteElements(body)) {
          el.remove();
        }

        const cleanedHtml = body.innerHTML;
        let md = td.turndown(cleanedHtml);

        chapters.push(md);
      } catch {
        chapters.push('<!-- Chapter ' + (i + 1) + ' could not be converted -->');
      }
    }

    let fullMarkdown = chapters.join('\n\n---\n\n');

    // Append footnote definitions
    if (footnoteMap.size > 0) {
      fullMarkdown += '\n\n';
      const sortedFootnotes = [...footnoteMap.values()].sort((a, b) => a.num - b.num);
      for (const fn of sortedFootnotes) {
        fullMarkdown += '[^' + fn.num + ']: ' + fn.text + '\n';
      }
    }

    // Collapse 3+ consecutive blank lines to 2
    fullMarkdown = fullMarkdown.replace(/\n{3,}/g, '\n\n');

    // Build YAML front matter
    let frontMatter = '---\n';
    frontMatter += 'title: "' + escapeYaml(meta.title) + '"\n';
    if (meta.author) frontMatter += 'author: "' + escapeYaml(meta.author) + '"\n';
    if (meta.language) frontMatter += 'language: "' + escapeYaml(meta.language) + '"\n';
    if (meta.publisher) frontMatter += 'publisher: "' + escapeYaml(meta.publisher) + '"\n';
    if (meta.date) frontMatter += 'date: "' + escapeYaml(meta.date) + '"\n';
    if (meta.description) frontMatter += 'description: "' + escapeYaml(meta.description) + '"\n';
    if (meta.tags.length > 0) frontMatter += 'tags: [' + meta.tags.map(t => '"' + escapeYaml(t) + '"').join(', ') + ']\n';
    frontMatter += '---\n\n';

    return { markdown: frontMatter + fullMarkdown, meta };
  }

  function escapeYaml(s) {
    return s.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  }

  // Process queue
  async function processQueue() {
    if (processing) return;
    processing = true;

    const usedNames = new Set();
    for (const f of files) {
      if (f.outputName) usedNames.add(f.outputName.replace(/\.md$/, ''));
    }

    for (const f of files) {
      if (f.status !== 'queued') continue;
      if (!f.sizeWarningDismissed) continue;

      f.status = 'converting';
      renderList();

      // Yield to UI
      await new Promise(r => setTimeout(r, 0));

      try {
        const result = await parseEpub(f.file);
        f.markdown = result.markdown;
        f.title = result.meta.title || f.title;
        f.author = result.meta.author || '';

        const baseName = sanitizeFilename(f.title) || f.name.replace(/\.epub$/i, '').toLowerCase().replace(/[^\w\s\-]/g, '').replace(/\s+/g, '-') || 'untitled';
        const uniqueName = deduplicateFilename(baseName, usedNames);
        usedNames.add(uniqueName);
        f.outputName = uniqueName + '.md';

        if (directoryHandle) {
          try {
            await saveToDirectory(f);
            f.status = 'saved';
          } catch {
            f.status = 'done';
          }
        } else {
          f.status = 'done';
        }
      } catch (err) {
        f.status = 'error';
        f.error = err.message || 'Unknown error';
      }

      renderList();
      await new Promise(r => setTimeout(r, 0));
    }

    processing = false;
  }

  // Download single file
  function downloadSingle(f) {
    const blob = new Blob([f.markdown], { type: 'text/markdown;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = f.outputName;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  // Download all as ZIP
  downloadAllBtn.addEventListener('click', async () => {
    const doneFiles = files.filter(f => (f.status === 'done' || f.status === 'saved') && f.markdown);
    if (doneFiles.length === 0) return;

    downloadAllBtn.disabled = true;
    downloadAllBtn.textContent = 'Creating ZIP…';

    const zip = new JSZip();
    for (const f of doneFiles) {
      zip.file(f.outputName, f.markdown);
    }

    const blob = await zip.generateAsync({ type: 'blob' });
    const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'epub-to-markdown-' + ts + '.zip';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    downloadAllBtn.disabled = false;
    downloadAllBtn.textContent = 'Download All as ZIP';
  });

  // Clear all
  clearAllBtn.addEventListener('click', () => {
    files = [];
    renderList();
  });

  // File System Access API - save to folder
  async function pickDirectory() {
    try {
      directoryHandle = await window.showDirectoryPicker({ mode: 'readwrite' });
      dirName.textContent = directoryHandle.name;
      renderList();
      // Re-save any already-done files
      for (const f of files) {
        if (f.status === 'done' && f.markdown) {
          try {
            await saveToDirectory(f);
            f.status = 'saved';
          } catch { /* ignore */ }
        }
      }
      renderList();
    } catch {
      // User cancelled
    }
  }

  async function saveToDirectory(f) {
    if (!directoryHandle) return;
    const fileHandle = await directoryHandle.getFileHandle(f.outputName, { create: true });
    const writable = await fileHandle.createWritable();
    await writable.write(f.markdown);
    await writable.close();
  }

  saveFolderBtn.addEventListener('click', pickDirectory);
  changeDirBtn.addEventListener('click', pickDirectory);
  clearDirBtn.addEventListener('click', () => {
    directoryHandle = null;
    renderList();
  });
})();
</script>
</body>
</html>
APPEOF

echo "Build complete: index.html ($(wc -c < index.html) bytes)"
