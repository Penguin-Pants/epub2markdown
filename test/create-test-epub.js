const JSZip = require('jszip');
const fs = require('fs');

async function createTestEpub() {
  const zip = new JSZip();

  zip.file('mimetype', 'application/epub+zip');

  zip.file('META-INF/container.xml', `<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>`);

  zip.file('OEBPS/content.opf', `<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Test Book Title</dc:title>
    <dc:creator>Jane Author</dc:creator>
    <dc:language>en</dc:language>
    <dc:publisher>Test Press</dc:publisher>
    <dc:date>2024-03-15</dc:date>
    <dc:description>A test book for the converter.</dc:description>
    <dc:subject>testing</dc:subject>
    <dc:subject>epub</dc:subject>
  </metadata>
  <manifest>
    <item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch3" href="chapter3.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
    <itemref idref="ch3"/>
  </spine>
</package>`);

  zip.file('OEBPS/chapter1.xhtml', `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Chapter 1</title><style>body { font-family: serif; }</style></head>
<body>
<h1>The Beginning</h1>
<p>This is the <strong>first</strong> chapter with <em>italic</em> and <a href="https://example.com">a link</a>.</p>
<p>Here is a list:</p>
<ul>
  <li>Item one</li>
  <li>Item two</li>
  <li>Item <strong>three</strong></li>
</ul>
<blockquote><p>A wise quote from someone.</p></blockquote>
<p>Some text with a footnote reference<a href="#note-1" id="ref-1">[1]</a>.</p>
<img src="image.jpg" alt="test image"/>
<p>Text after image.</p>
<script>alert('bad');</script>
</body>
</html>`);

  zip.file('OEBPS/chapter2.xhtml', `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Chapter 2</title></head>
<body>
<h1>Tables and Code</h1>
<table>
  <thead><tr><th>Name</th><th>Value</th></tr></thead>
  <tbody>
    <tr><td>Alpha</td><td>100</td></tr>
    <tr><td>Beta</td><td>200</td></tr>
  </tbody>
</table>
<pre><code>function hello() {
  console.log("world");
}</code></pre>
<p>Some ~~strikethrough~~ text.</p>
<h2>A Subsection</h2>
<p>With an <a href="chapter1.xhtml">internal link</a> and an <a href="https://example.org">external link</a>.</p>
<ol>
  <li>First</li>
  <li>Second</li>
  <li>Third</li>
</ol>
</body>
</html>`);

  zip.file('OEBPS/chapter3.xhtml', `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Notes</title></head>
<body>
<h1>Endnotes</h1>
<aside epub:type="footnote" id="note-1"><p>1. This is the footnote text for note one.</p></aside>
<hr/>
<p>End of the book.</p>
<figure><img src="cover.jpg"/><figcaption>Cover image</figcaption></figure>
<svg xmlns="http://www.w3.org/2000/svg"><rect width="100" height="100"/></svg>
</body>
</html>`);

  const content = await zip.generateAsync({ type: 'nodebuffer' });
  fs.writeFileSync('test/test-book.epub', content);
  console.log('Created test/test-book.epub (' + content.length + ' bytes)');
}

createTestEpub().catch(console.error);
