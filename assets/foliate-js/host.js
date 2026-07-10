// host.js — Origo Reader Flutter Foliate WebView Bridge
// Replaces the legacy book.js with an iOS-style origoFoliateHost architecture
// adapted for Flutter's flutter_inappwebview bridge.
//
// Architecture:
//   window.origoFoliateHost  →  Flutter-side callable methods
//   post(type, payload)      →  JS→Flutter event communication
//   CanonicalLocator         →  stable text-anchor truth source
//   RenderedLocator          →  current device/renderer display state
//   NavigationQueue          →  serialized async navigation to prevent conflicts

// ---------------------------------------------------------------------------
// §1  Flutter Bridge — JS→Flutter communication
// ---------------------------------------------------------------------------

const post = (type, payload = {}) => {
  const bridge = window.flutter_inappwebview
  if (!bridge || typeof bridge.callHandler !== 'function') {
    console.warn(`[OrigoFoliateHost] flutter_inappwebview not ready for: ${type}`)
    return Promise.resolve(null)
  }
  try {
    return bridge.callHandler('onHostEvent', { type, payload: sanitizeForFlutter(payload) })
  } catch (error) {
    console.warn(`[OrigoFoliateHost] callHandler failed for: ${type}`, error)
    return Promise.resolve(null)
  }
}

const sanitizeForFlutter = value => {
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : null
  }
  if (Array.isArray(value)) {
    return value.map(sanitizeForFlutter)
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, nested]) => [key, sanitizeForFlutter(nested)])
    )
  }
  return value
}

const serializeError = error => {
  if (!error) return { message: 'Unknown error' }
  if (typeof error === 'string') return { message: error }
  return {
    message: error.message ?? 'Unknown error',
    stack: error.stack ?? null,
    name: error.name ?? null,
  }
}

const safeJSONString = value => {
  if (value == null) return null
  try { return JSON.stringify(value) } catch { return String(value) }
}

const postError = (code, error, details = null) => {
  const serialized = serializeError(error)
  console.error(`[OrigoFoliateHost] ${code}`, error, details)
  post('error', {
    code,
    message: serialized.message,
    stack: serialized.stack,
    details: safeJSONString(details),
  })
}

// ---------------------------------------------------------------------------
// §2  Debug Trace
// ---------------------------------------------------------------------------

let traceEnabled = false

const postTrace = (message, details = null) => {
  if (!traceEnabled) return
  console.log(`[OrigoFoliateHost] ${message}`, details ?? '')
  post('trace', { message, details: safeJSONString(details) })
}

// ---------------------------------------------------------------------------
// §3  Module Loading
// ---------------------------------------------------------------------------

const loadFoliateViewModule = async () => {
  try {
    return await import('./foliate/view.js')
  } catch (primaryError) {
    try {
      return await import('./view.js')
    } catch (fallbackError) {
      postError('module-load', fallbackError, { primaryError, fallbackError })
      throw fallbackError
    }
  }
}

let foliateViewModulePromise = null

const ensureFoliateViewModule = () => {
  if (!foliateViewModulePromise) {
    foliateViewModulePromise = loadFoliateViewModule()
  }
  return foliateViewModulePromise
}

// ---------------------------------------------------------------------------
// §4  State
// ---------------------------------------------------------------------------

const readerElement = document.getElementById('reader')

let view = null
let currentPayload = null
let currentBook = null        // resolved book object (EPUB/PDF/etc. or synthetic)
let currentBookCleanup = null
let currentFormat = null      // 'txt' | 'epub' | 'mobi' | 'fb2' | 'pdf' | 'cbz'
let lastRelocate = null
let interactionCleanupCallbacks = []
let navigationQueue = Promise.resolve()
let initialOpenToken = 0
let relocateAnimationFrame = null
let observedChapterPageSpans = new Map()
let annotationsMap = new Map()
let annotationsByValue = new Map()
let searchIterator = null

// ---------------------------------------------------------------------------
// §5  Utility Functions
// ---------------------------------------------------------------------------

const normalizeHref = raw => {
  if (!raw) return ''
  return raw.split('#')[0].replace(/^\.?\//, '')
}

const splitHref = raw => {
  const [href, fragment] = (raw || '').split('#')
  return { href: normalizeHref(href), fragment: fragment || '' }
}

const parseJSON = value => {
  if (!value) return null
  if (typeof value === 'object') return value
  try { return JSON.parse(value) } catch { return null }
}

const clampPayloadText = (value, limit = 2400) => {
  const text = `${value ?? ''}`.trim()
  if (!text) return ''
  if (text.length <= limit) return text
  return `${text.slice(0, Math.max(limit - 1, 0))}…`
}

const runWithTimeout = async (label, work, timeoutMs = 2500) => {
  let timer = null
  try {
    return await Promise.race([
      Promise.resolve().then(work),
      new Promise(resolve => {
        timer = setTimeout(() => {
          postTrace(`${label} timeout`, { timeoutMs })
          resolve(false)
        }, timeoutMs)
      }),
    ])
  } finally {
    if (timer) clearTimeout(timer)
  }
}

// ---------------------------------------------------------------------------
// §6  Canonical Offset Resolution (from iOS host.js)
// ---------------------------------------------------------------------------

const resolveBlock = node => {
  if (!node) return null
  if (node.nodeType === Node.ELEMENT_NODE && node.dataset?.origoCanonicalStart) return node
  return node.parentElement?.closest?.('[data-origo-canonical-start]') ?? null
}

const leadingTextLength = (root, node, offset) => {
  let total = 0
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
  while (walker.nextNode()) {
    const current = walker.currentNode
    if (current === node) {
      return total + Math.min(Math.max(offset, 0), current.textContent?.length ?? 0)
    }
    total += current.textContent?.length ?? 0
  }
  return total
}

const resolveBoundaryOffset = (container, offset) => {
  const block = resolveBlock(container)
  if (!block) return null
  const start = Number(block.dataset.origoCanonicalStart ?? '')
  const end = Number(block.dataset.origoCanonicalEnd ?? '')
  if (Number.isNaN(start) || Number.isNaN(end)) return null

  if (container.nodeType === Node.TEXT_NODE) {
    return Math.min(start + offset, end)
  }

  const root = block
  const safeOffset = Math.min(Math.max(offset, 0), root.childNodes.length)
  let consumed = 0
  for (let i = 0; i < safeOffset; i += 1) {
    consumed += root.childNodes[i]?.textContent?.length ?? 0
  }
  return Math.min(start + consumed, end)
}

const rangeToCanonical = range => {
  if (!range) return null
  const start = resolveBoundaryOffset(range.startContainer, range.startOffset)
  const end = resolveBoundaryOffset(range.endContainer, range.endOffset)
  if (start == null || end == null) return null
  return { start: Math.max(0, start), end: Math.max(start, end) }
}

const rangeForCanonicalOffset = (doc, offset) => {
  const blocks = Array.from(doc.querySelectorAll('[data-origo-canonical-start]'))
    .map(block => {
      const start = Number(block.dataset.origoCanonicalStart ?? '')
      const end = Number(block.dataset.origoCanonicalEnd ?? '')
      if (Number.isNaN(start) || Number.isNaN(end)) return null
      return { block, start, end: Math.max(end, start) }
    })
    .filter(Boolean)
    .sort((lhs, rhs) => lhs.start - rhs.start)
  if (!blocks.length) return null

  const targetOffset = Number.isFinite(offset) ? offset : 0
  let target = blocks.find(entry =>
    targetOffset >= entry.start && targetOffset <= entry.end
  )

  if (!target) {
    if (targetOffset <= blocks[0].start) {
      target = blocks[0]
    } else if (targetOffset >= blocks[blocks.length - 1].end) {
      target = blocks[blocks.length - 1]
    } else {
      for (let i = 1; i < blocks.length; i += 1) {
        const prev = blocks[i - 1]
        const next = blocks[i]
        if (targetOffset <= next.start) {
          const prevDistance = Math.abs(targetOffset - prev.end)
          const nextDistance = Math.abs(next.start - targetOffset)
          target = prevDistance <= nextDistance ? prev : next
          break
        }
      }
    }
  }

  if (!target) return null

  const clampedOffset = Math.min(Math.max(targetOffset, target.start), target.end)
  const relative = Math.max(clampedOffset - target.start, 0)
  const textNode = doc.createTreeWalker(target.block, NodeFilter.SHOW_TEXT).nextNode()
  if (!textNode) return target.block
  const safeOffset = Math.min(relative, textNode.textContent?.length ?? 0)
  const range = doc.createRange()
  range.setStart(textNode, safeOffset)
  range.setEnd(textNode, safeOffset)
  return range
}

// ---------------------------------------------------------------------------
// §7  Canonical Href Builder
// ---------------------------------------------------------------------------

const buildCanonicalHref = ({ chapterID, offset, quote, fallbackHref = '' }) => {
  const normalizedChapterID = `${chapterID ?? ''}`.trim()
  const safeOffset = Number.isFinite(offset) ? Math.max(Math.floor(offset), 0) : null
  const normalizedQuote = `${quote ?? ''}`.trim()
  const encodedQuote = normalizedQuote
    ? encodeURIComponent(normalizedQuote.slice(0, 160))
    : null

  if (normalizedChapterID) {
    const encodedChapterID = encodeURIComponent(normalizedChapterID)
    if (safeOffset != null && encodedQuote) {
      return `text://chapter/${encodedChapterID}/offset/${safeOffset}/excerpt/${encodedQuote}`
    }
    if (safeOffset != null) {
      return `text://chapter/${encodedChapterID}/offset/${safeOffset}`
    }
    if (encodedQuote) {
      return `text://chapter/${encodedChapterID}/excerpt/${encodedQuote}`
    }
  }

  if (safeOffset != null && encodedQuote) {
    return `text://offset/${safeOffset}/excerpt/${encodedQuote}`
  }
  if (safeOffset != null) {
    return `text://offset/${safeOffset}`
  }
  if (encodedQuote) {
    return `text://excerpt/${encodedQuote}`
  }

  return fallbackHref
}

// ---------------------------------------------------------------------------
// §8  TXT Manifest Helpers
// ---------------------------------------------------------------------------

const chapterForIndex = index => currentPayload?.chapters?.[index] ?? null

const chapterByID = chapterID => currentPayload?.chapters?.find(chapter =>
  chapter.id === chapterID || chapter.sourceChapterID === chapterID
) ?? null

const hasChapterHref = href => {
  const normalized = normalizeHref(href)
  if (!normalized) return false
  return currentPayload?.chapters?.some(chapter => normalizeHref(chapter.href) === normalized) ?? false
}

const chapterCandidatesByCanonicalTarget = target => {
  const chapterID = `${target?.chapterID ?? target?.textAnchor?.chapterID ?? ''}`.trim()
  if (!chapterID) return []
  return (currentPayload?.chapters ?? [])
    .filter(chapter => chapter.id === chapterID || chapter.sourceChapterID === chapterID)
    .sort((lhs, rhs) => {
      const lhsStart = Number(lhs?.startUTF16Offset ?? Number.MAX_SAFE_INTEGER)
      const rhsStart = Number(rhs?.startUTF16Offset ?? Number.MAX_SAFE_INTEGER)
      if (lhsStart === rhsStart) {
        return normalizeHref(lhs?.href ?? '').localeCompare(normalizeHref(rhs?.href ?? ''))
      }
      return lhsStart - rhsStart
    })
}

const chapterForCanonicalTarget = target => {
  const candidates = chapterCandidatesByCanonicalTarget(target)
  if (!candidates.length) return null

  const requestedOffset = Number(target?.textAnchor?.offsetHint)
  if (!Number.isFinite(requestedOffset)) {
    return candidates[0]
  }

  const containing = candidates.find(chapter => {
    const start = Number(chapter?.startUTF16Offset)
    const end = Number(chapter?.endUTF16Offset)
    if (!Number.isFinite(start) || !Number.isFinite(end)) return false
    if (end <= start) return requestedOffset === start
    return requestedOffset >= start && requestedOffset < end
  })
  if (containing) return containing

  return candidates.reduce((best, candidate) => {
    const candidateStart = Number(candidate?.startUTF16Offset)
    const candidateEnd = Number(candidate?.endUTF16Offset)
    const candidateDistance = Number.isFinite(candidateStart) && Number.isFinite(candidateEnd)
      ? Math.min(
          Math.abs(requestedOffset - candidateStart),
          Math.abs(requestedOffset - candidateEnd)
        )
      : Number.MAX_SAFE_INTEGER
    if (!best) return candidate
    const bestStart = Number(best?.startUTF16Offset)
    const bestEnd = Number(best?.endUTF16Offset)
    const bestDistance = Number.isFinite(bestStart) && Number.isFinite(bestEnd)
      ? Math.min(
          Math.abs(requestedOffset - bestStart),
          Math.abs(requestedOffset - bestEnd)
        )
      : Number.MAX_SAFE_INTEGER
    return candidateDistance < bestDistance ? candidate : best
  }, null)
}

const totalUTF16LengthHint = () => {
  const maxEnd = Math.max(
    ...((currentPayload?.chapters ?? []).map(chapter => Number(chapter?.endUTF16Offset ?? 0))),
    0
  )
  return Math.max(maxEnd, 1)
}

// ---------------------------------------------------------------------------
// §9  Synthetic Book Builder (TXT Manifest Mode)
// ---------------------------------------------------------------------------

const buildSyntheticBook = payload => {
  const cache = new Map()
  const parser = new DOMParser()
  const chapters = payload.chapters
  const chapterURL = chapter => {
    if (!payload?.manifestURL || !chapter?.href) return chapter?.fileURL ?? ''
    return new URL(chapter.href, payload.manifestURL).toString()
  }

  const loadDocument = async chapter => {
    if (cache.has(chapter.href)) return cache.get(chapter.href)
    try {
      const resourceURL = chapterURL(chapter)
      postTrace('chapter fetch start', { href: chapter.href, resourceURL })
      const response = await fetch(resourceURL)
      if (!response.ok && response.status !== 0) {
        throw new Error(`Failed to fetch chapter ${chapter.href}: ${response.status} ${response.statusText}`)
      }
      const text = await response.text()
      const doc = parser.parseFromString(text, 'application/xhtml+xml')
      const parserError = doc.querySelector('parsererror')
      if (parserError) {
        throw new Error(`Invalid XHTML for ${chapter.href}: ${parserError.textContent ?? 'parsererror'}`)
      }
      cache.set(chapter.href, doc)
      postTrace('chapter fetch end', { href: chapter.href, bodyLength: doc.body?.innerText?.length ?? 0 })
      return doc
    } catch (error) {
      postError('chapter-load', error, { href: chapter.href, fileURL: chapterURL(chapter) })
      throw error
    }
  }

  const resolveHref = rawTarget => {
    const { href, fragment } = splitHref(rawTarget)
    const index = Math.max(chapters.findIndex(chapter => normalizeHref(chapter.href) === href), 0)
    const anchor = fragment
      ? doc => doc.getElementById(fragment) ?? doc.body
      : undefined
    return { index, anchor }
  }

  return {
    metadata: {
      title: payload.bookTitle,
      language: payload.language,
      identifier: payload.bookId,
    },
    dir: payload.direction ?? 'ltr',
    rendition: { layout: 'reflowable' },
    sections: chapters.map(chapter => ({
      id: chapter.id,
      href: chapter.href,
      linear: 'yes',
      cfi: null,
      size: Math.max((chapter.endUTF16Offset ?? 0) - (chapter.startUTF16Offset ?? 0), 1),
      resolveHref(target) {
        const parsed = splitHref(target)
        if (!parsed.href) {
          return `${chapter.href}${parsed.fragment ? `#${parsed.fragment}` : ''}`
        }
        return `${parsed.href}${parsed.fragment ? `#${parsed.fragment}` : ''}`
      },
      async load() {
        return chapterURL(chapter)
      },
      async createDocument() {
        return loadDocument(chapter)
      },
      unload() {},
    })),
    toc: chapters.map(chapter => ({
      label: chapter.title,
      href: chapter.href,
      subitems: [],
    })),
    pageList: [],
    splitTOCHref(target) {
      const { href, fragment } = splitHref(target)
      return [href, fragment]
    },
    getTOCFragment(doc, fragment) {
      return fragment ? doc.getElementById(fragment) ?? doc.body : doc.body
    },
    resolveHref,
    cleanup() {
      cache.clear()
    },
  }
}

// ---------------------------------------------------------------------------
// §10  Format Routing — Direct File Mode
// ---------------------------------------------------------------------------

const isZip = async blob => {
  const arr = new Uint8Array(await blob.slice(0, 4).arrayBuffer())
  return arr[0] === 0x50 && arr[1] === 0x4b && arr[2] === 0x03 && arr[3] === 0x04
}

const isPDF = async blob => {
  const arr = new Uint8Array(await blob.slice(0, 5).arrayBuffer())
  return arr[0] === 0x25 && arr[1] === 0x50 && arr[2] === 0x44 && arr[3] === 0x46 && arr[4] === 0x2d
}

const isCBZ = ({ name, type }) =>
  type === 'application/vnd.comicbook+zip' || (name && name.endsWith('.cbz'))

const isFB2 = ({ name, type }) =>
  type === 'application/x-fictionbook+xml' || (name && name.endsWith('.fb2'))

const isFBZ = ({ name, type }) =>
  type === 'application/x-zip-compressed-fb2'
  || (name && (name.endsWith('.fb2.zip') || name.endsWith('.fbz')))

const resolveBookFromDirectFile = async (payload) => {
  const { url, format } = payload
  if (!url) throw new Error('Missing url in direct-file payload')

  postTrace('fetch direct file start', { url, format })
  const response = await fetch(url)
  if (!response.ok && response.status !== 0) {
    throw new Error(`Failed to fetch book file: ${response.status} ${response.statusText}`)
  }
  const blob = await response.blob()
  const file = new File([blob], new URL(url, window.location.origin).pathname)
  postTrace('fetch direct file end', { size: blob.size, format })

  // Explicit format override from Flutter
  if (format === 'pdf') {
    const { makePDF } = await import('./pdf.js')
    currentFormat = 'pdf'
    return await makePDF(file)
  }

  if (format === 'mobi') {
    const { MOBI } = await import('./mobi.js')
    const fflate = await import('./vendor/fflate.js')
    currentFormat = 'mobi'
    return await new MOBI({ unzlib: fflate.unzlibSync }).open(file)
  }

  if (format === 'fb2') {
    const { makeFB2 } = await import('./fb2.js')
    currentFormat = 'fb2'
    return await makeFB2(blob)
  }

  if (format === 'cbz') {
    const { configure, ZipReader, BlobReader, TextWriter, BlobWriter } =
      await import('./vendor/zip.js')
    configure({ useWebWorkers: false })
    const zipLoader = { entries: null, loadText: null, loadBlob: null, getSize: null }
    const reader = new ZipReader(new BlobReader(blob))
    const entries = await reader.getEntries()
    const map = new Map(entries.map(entry => [entry.filename, entry]))
    const load = f => (name, ...args) =>
      map.has(name) ? f(map.get(name), ...args) : null
    zipLoader.entries = entries
    zipLoader.loadText = load(entry => entry.getData(new TextWriter()))
    zipLoader.loadBlob = load((entry, type) => entry.getData(new BlobWriter(type)))
    zipLoader.getSize = name => map.get(name)?.uncompressedSize ?? 0
    const { makeComicBook } = await import('./comic-book.js')
    currentFormat = 'cbz'
    return makeComicBook(zipLoader, file)
  }

  // Auto-detect when format is 'epub' or unspecified
  if (await isPDF(blob)) {
    const { makePDF } = await import('./pdf.js')
    currentFormat = 'pdf'
    return await makePDF(file)
  }

  if (await isZip(blob)) {
    const { configure, ZipReader, BlobReader, TextWriter, BlobWriter } =
      await import('./vendor/zip.js')
    configure({ useWebWorkers: false })
    const reader = new ZipReader(new BlobReader(blob))
    const entries = await reader.getEntries()
    const map = new Map(entries.map(entry => [entry.filename, entry]))
    const load = f => (name, ...args) =>
      map.has(name) ? f(map.get(name), ...args) : null
    const zipLoader = {
      entries,
      loadText: load(entry => entry.getData(new TextWriter())),
      loadBlob: load((entry, type) => entry.getData(new BlobWriter(type))),
      getSize: name => map.get(name)?.uncompressedSize ?? 0,
    }

    if (isCBZ(file)) {
      const { makeComicBook } = await import('./comic-book.js')
      currentFormat = 'cbz'
      return makeComicBook(zipLoader, file)
    }

    if (isFBZ(file)) {
      const { makeFB2 } = await import('./fb2.js')
      const entry = entries.find(entry => entry.filename.endsWith('.fb2'))
      const fb2Blob = await zipLoader.loadBlob((entry ?? entries[0]).filename)
      currentFormat = 'fb2'
      return await makeFB2(fb2Blob)
    }

    const { EPUB } = await import('./epub.js')
    currentFormat = 'epub'
    return await new EPUB(zipLoader).init()
  }

  // MOBI or plain FB2
  const { isMOBI, MOBI } = await import('./mobi.js')
  if (await isMOBI(blob)) {
    const fflate = await import('./vendor/fflate.js')
    currentFormat = 'mobi'
    return await new MOBI({ unzlib: fflate.unzlibSync }).open(file)
  }

  if (isFB2(file)) {
    const { makeFB2 } = await import('./fb2.js')
    currentFormat = 'fb2'
    return await makeFB2(blob)
  }

  throw new Error('Unsupported book format')
}

// ---------------------------------------------------------------------------
// §11  Relocate State Building
// ---------------------------------------------------------------------------

const isRendererInScrolledFlow = () => {
  const flow = view?.renderer?.getAttribute?.('flow')
  return typeof flow === 'string' && flow.toLowerCase() === 'scrolled'
}

const buildWindowPageMetrics = relocateDetail => {
  if (isRendererInScrolledFlow()) {
    return { currentPage: 0, totalPages: 1, source: 'scrolled', rawFraction: null, rawPageSize: null }
  }

  const rawFraction = Number(relocateDetail?.rendererFraction ?? relocateDetail?.fraction)
  const rawPageSize = Number(relocateDetail?.rendererPageSize)

  if (Number.isFinite(rawFraction) && Number.isFinite(rawPageSize) && rawPageSize > 0) {
    const totalPages = Math.max(Math.round(1 / rawPageSize), 1)
    const pageIndex = Math.floor((rawFraction / rawPageSize) + 0.000_001)
    return { currentPage: Math.min(Math.max(pageIndex, 0), totalPages - 1), totalPages, source: 'renderer', rawFraction, rawPageSize }
  }

  // For EPUB/PDF/etc. use foliate's location if available
  const locationCurrent = Number(relocateDetail?.location?.current ?? 0)
  const locationTotal = Number(relocateDetail?.location?.total ?? 0)
  if (Number.isFinite(locationCurrent) && Number.isFinite(locationTotal) && locationTotal > 0) {
    return {
      currentPage: Math.min(Math.max(Math.floor(locationCurrent), 0), Math.max(Math.ceil(locationTotal) - 1, 0)),
      totalPages: Math.max(Math.ceil(locationTotal), 1),
      source: 'location',
      rawFraction,
      rawPageSize: Number.isFinite(rawPageSize) ? rawPageSize : null,
    }
  }

  return { currentPage: 0, totalPages: 1, source: 'fallback', rawFraction: Number.isFinite(rawFraction) ? rawFraction : null, rawPageSize: Number.isFinite(rawPageSize) ? rawPageSize : null }
}

const estimatedTotalPageCount = () => Math.max(Number(currentPayload?.estimatedTotalPages ?? 1), 1)

const clampPageIndex = (pageIndex, totalPages) => {
  const safeTotalPages = Math.max(Number(totalPages ?? 1), 1)
  return Math.min(Math.max(Math.floor(Number(pageIndex ?? 0)), 0), safeTotalPages - 1)
}

const projectedPageIndexForProgression = (progression, totalPages) => {
  const safeTotalPages = Math.max(Number(totalPages ?? 1), 1)
  if (safeTotalPages <= 1) return 0
  const clampedProgression = Math.min(Math.max(Number(progression ?? 0), 0), 1)
  return clampPageIndex(Math.floor(clampedProgression * safeTotalPages), safeTotalPages)
}

const projectedChapterStartPageHint = (chapter, totalPages) => {
  const startProgression = Number(chapter?.startProgression)
  if (Number.isFinite(startProgression)) {
    return projectedPageIndexForProgression(startProgression, totalPages)
  }
  const startUTF16Offset = Number(chapter?.startUTF16Offset)
  const totalUTF16 = totalUTF16LengthHint()
  if (Number.isFinite(startUTF16Offset) && totalUTF16 > 1) {
    return projectedPageIndexForProgression(startUTF16Offset / Math.max(totalUTF16 - 1, 1), totalPages)
  }
  return 0
}

const resolvedChapterStartPage = (chapter, totalPages) => {
  const chapters = currentPayload?.chapters ?? []
  const chapterIndex = chapters.findIndex(item => item.id === chapter?.id)
  if (chapterIndex < 0) {
    return projectedChapterStartPageHint(chapter, totalPages)
  }
  let resolvedStart = projectedChapterStartPageHint(chapters[0], totalPages)
  if (chapterIndex === 0) return resolvedStart

  for (let index = 1; index <= chapterIndex; index += 1) {
    const previousChapter = chapters[index - 1]
    const currentChapter = chapters[index]
    const currentHint = projectedChapterStartPageHint(currentChapter, totalPages)
    const observedPreviousSpan = observedChapterPageSpans.get(previousChapter?.id)
    const fallbackPreviousSpan = Math.max(currentHint - resolvedStart, 1)
    const previousSpan = Math.max(observedPreviousSpan ?? fallbackPreviousSpan, 1)
    resolvedStart = Math.max(currentHint, resolvedStart + previousSpan)
  }
  return clampPageIndex(resolvedStart, totalPages)
}

const projectedChapterEndPageExclusive = (chapter, totalPages) => {
  const chapters = currentPayload?.chapters ?? []
  const chapterIndex = chapters.findIndex(item => item.id === chapter?.id)
  if (chapterIndex >= 0 && chapterIndex + 1 < chapters.length) {
    const nextStart = resolvedChapterStartPage(chapters[chapterIndex + 1], totalPages)
    return Math.min(Math.max(nextStart, resolvedChapterStartPage(chapter, totalPages) + 1), totalPages)
  }
  const startUTF16Offset = Number(chapter?.startUTF16Offset)
  const endUTF16Offset = Number(chapter?.endUTF16Offset)
  const totalUTF16 = totalUTF16LengthHint()
  if (Number.isFinite(startUTF16Offset) && Number.isFinite(endUTF16Offset) && endUTF16Offset > startUTF16Offset && totalUTF16 > 1) {
    const chapterEndProgression = Math.min(Math.max(endUTF16Offset / Math.max(totalUTF16 - 1, 1), 0), 1)
    const projectedEnd = projectedPageIndexForProgression(chapterEndProgression, totalPages) + 1
    return Math.min(Math.max(projectedEnd, resolvedChapterStartPage(chapter, totalPages) + 1), totalPages)
  }
  return totalPages
}

const buildRenderedLocator = () => {
  const index = view?.renderer?.primaryIndex ?? 0

  // TXT mode: build from chapter data + canonical offsets
  if (currentFormat === 'txt') {
    const chapter = chapterForIndex(index)
    if (!chapter) return null
    const visibleRange = rangeToCanonical(lastRelocate?.range ?? null)
    const visibleText = (lastRelocate?.range?.toString?.() ?? '').trim()
    const progression = Number(lastRelocate?.fraction ?? 0)
    const location = lastRelocate?.location ?? {}
    const locationTotal = Number(location.total)
    const fallbackTotalPositions = Number(currentPayload?.estimatedTotalPages ?? 1)
    const totalPositions = Number.isFinite(locationTotal) && locationTotal > 0
      ? Math.max(Math.ceil(locationTotal), 1)
      : Math.max(fallbackTotalPositions, 1)
    const locationCurrent = Number(location.current)
    const position = Number.isFinite(locationCurrent)
      ? Math.min(Math.max(Math.floor(locationCurrent) + 1, 1), totalPositions)
      : Math.round(progression * Math.max(totalPositions - 1, 0)) + 1
    return {
      version: 1,
      format: 'txt',
      renderer: 'foliate',
      href: chapter.href,
      progression,
      position: Math.max(position, 1),
      totalPositions: Math.max(totalPositions, 1),
      mediaType: 'application/xhtml+xml',
      title: chapter.title,
      resourceProgression: null,
      totalProgression: progression,
      fragments: [
        `origo-chapter:${chapter.id}`,
        `origo-start:${visibleRange?.start ?? chapter.startUTF16Offset}`,
        `origo-end:${visibleRange?.end ?? chapter.startUTF16Offset}`,
      ],
      textBefore: visibleText ? visibleText.slice(0, 96) : null,
      textAfter: visibleText ? visibleText.slice(-96) : null,
    }
  }

  // EPUB/PDF/etc. mode: use foliate's own relocation data
  const detail = lastRelocate ?? {}
  const cfi = detail.cfi ?? null
  const fraction = Number(detail.fraction ?? 0)
  const tocItem = detail.tocItem ?? null
  const location = detail.location ?? {}

  return {
    version: 1,
    format: currentFormat ?? 'epub',
    renderer: 'foliate',
    cfi,
    href: tocItem?.href ?? null,
    progression: fraction,
    position: Number.isFinite(location.current) ? Math.max(Math.floor(location.current) + 1, 1) : 1,
    totalPositions: Number.isFinite(location.total) ? Math.max(Math.ceil(location.total), 1) : 1,
    mediaType: 'application/xhtml+xml',
    title: tocItem?.label ?? null,
    resourceProgression: null,
    totalProgression: fraction,
    fragments: [],
    textBefore: (detail.range?.toString?.() ?? '').trim().slice(0, 96) || null,
    textAfter: (detail.range?.toString?.() ?? '').trim().slice(-96) || null,
  }
}

const buildCanonicalLocator = rendered => {
  if (!rendered) return null

  // TXT mode: canonical locator from chapter offsets
  if (currentFormat === 'txt') {
    const chapter = chapterByID(rendered.fragments?.find(fragment => fragment.startsWith('origo-chapter:'))?.replace('origo-chapter:', ''))
      ?? chapterForIndex(view?.renderer?.primaryIndex ?? 0)
    const start = Number(rendered.fragments?.find(fragment => fragment.startsWith('origo-start:'))?.replace('origo-start:', '') ?? chapter?.startUTF16Offset ?? 0)
    const quote = (lastRelocate?.range?.toString?.() ?? '').trim()
    const chapterID = chapter?.sourceChapterID ?? chapter?.id ?? null
    const offsetHint = Math.max(start, 0)
    const href = buildCanonicalHref({
      chapterID,
      offset: offsetHint,
      quote,
      fallbackHref: rendered.href ?? chapter?.href ?? '',
    })
    return {
      version: 1,
      format: 'txt',
      href,
      chapterID,
      progression: rendered.totalProgression ?? rendered.progression,
      positionHint: rendered.position,
      totalPositionsHint: rendered.totalPositions,
      fragments: rendered.fragments ?? [],
      textAnchor: {
        quote,
        prefix: null,
        suffix: null,
        chapterID,
        offsetHint,
      },
    }
  }

  // EPUB/PDF/etc. mode: canonical locator from CFI
  return {
    version: 1,
    format: currentFormat ?? 'epub',
    cfi: rendered.cfi ?? null,
    href: rendered.href ?? null,
    progression: rendered.totalProgression ?? rendered.progression ?? 0,
    positionHint: rendered.position ?? 1,
    totalPositionsHint: rendered.totalPositions ?? 1,
    textAnchor: {
      quote: (lastRelocate?.range?.toString?.() ?? '').trim() || null,
      cfi: rendered.cfi ?? null,
    },
  }
}

const renderedChapterStartOffset = renderedLocator => {
  const rawOffset = renderedLocator?.fragments?.find(fragment => fragment.startsWith('origo-start:'))?.replace('origo-start:', '')
  const offset = Number(rawOffset)
  return Number.isFinite(offset) ? Math.max(Math.floor(offset), 0) : null
}

const buildGlobalPageMetrics = (renderedLocator, windowPageMetrics) => {
  if (currentFormat === 'txt') {
    const estimatedTotalPages = estimatedTotalPageCount()
    const chapter = chapterByID(renderedLocator?.fragments?.find(fragment => fragment.startsWith('origo-chapter:'))?.replace('origo-chapter:', ''))
      ?? chapterForIndex(view?.renderer?.primaryIndex ?? 0)

    if (chapter) {
      const chapterStartPage = resolvedChapterStartPage(chapter, estimatedTotalPages)
      const chapterEndExclusive = projectedChapterEndPageExclusive(chapter, estimatedTotalPages)
      const chapterSpan = Math.max(
        chapterEndExclusive - chapterStartPage,
        Number(windowPageMetrics?.totalPages ?? 1),
        1
      )

      if (Number(windowPageMetrics?.totalPages ?? 1) > 1) {
        const chapterLocalPageIndex = Math.min(
          Math.max(Number(windowPageMetrics?.currentPage ?? 0), 0),
          Math.max(Number(windowPageMetrics?.totalPages ?? 1) - 1, 0)
        )
        return {
          pageIndex: clampPageIndex(chapterStartPage + chapterLocalPageIndex, estimatedTotalPages),
          totalPages: estimatedTotalPages,
          source: 'chapter-window',
        }
      }

      const chapterStartOffset = Number(chapter?.startUTF16Offset)
      const chapterEndOffset = Number(chapter?.endUTF16Offset)
      const visibleStartOffset = renderedChapterStartOffset(renderedLocator)
      if (Number.isFinite(chapterStartOffset) &&
          Number.isFinite(chapterEndOffset) &&
          chapterEndOffset > chapterStartOffset &&
          Number.isFinite(visibleStartOffset)) {
        const chapterProgression = Math.min(
          Math.max((visibleStartOffset - chapterStartOffset) / Math.max(chapterEndOffset - chapterStartOffset, 1), 0),
          1
        )
        const projectedWithinChapter = Math.round(chapterProgression * Math.max(chapterSpan - 1, 0))
        return {
          pageIndex: clampPageIndex(chapterStartPage + projectedWithinChapter, estimatedTotalPages),
          totalPages: estimatedTotalPages,
          source: 'chapter-offset',
        }
      }
    }

    const progression = Number(renderedLocator?.totalProgression ?? renderedLocator?.progression ?? 0)
    const clampedProgression = Math.min(Math.max(progression, 0), 1)
    const fallbackIndex = Math.round(clampedProgression * Math.max(estimatedTotalPages - 1, 0))
    return {
      pageIndex: Math.min(Math.max(fallbackIndex, 0), estimatedTotalPages - 1),
      totalPages: estimatedTotalPages,
      source: 'progression-fallback',
    }
  }

  // EPUB/PDF/etc.: use window page metrics directly
  return {
    pageIndex: windowPageMetrics.currentPage,
    totalPages: windowPageMetrics.totalPages,
    source: windowPageMetrics.source,
  }
}

const buildRelocateState = () => {
  const renderedLocator = buildRenderedLocator()
  const canonicalLocator = buildCanonicalLocator(renderedLocator)
  const index = view?.renderer?.primaryIndex ?? 0
  const windowPageMetrics = buildWindowPageMetrics(lastRelocate)

  if (currentFormat === 'txt') {
    const chapter = chapterForIndex(index)
    if (chapter?.id) {
      observedChapterPageSpans.set(chapter.id, Math.max(Number(windowPageMetrics.totalPages ?? 1), 1))
    }
    const globalPageMetrics = buildGlobalPageMetrics(renderedLocator, windowPageMetrics)
    const payload = {
      rendererType: 'foliate',
      format: 'txt',
      currentPage: windowPageMetrics.currentPage,
      totalPages: windowPageMetrics.totalPages,
      windowPageIndex: windowPageMetrics.currentPage,
      windowPageCount: windowPageMetrics.totalPages,
      globalPageIndex: globalPageMetrics.pageIndex,
      globalPageCount: globalPageMetrics.totalPages,
      href: chapter?.href ?? renderedLocator?.href ?? null,
      syntheticChapterIndex: Number.isFinite(index) ? index : null,
      syntheticChapterID: chapter?.id ?? null,
      sourceChapterIndex: Number.isFinite(chapter?.sourceChapterIndex) ? chapter.sourceChapterIndex : null,
      sourceChapterID: chapter?.sourceChapterID ?? chapter?.id ?? null,
      progression: Number(renderedLocator?.totalProgression ?? 0),
      cfi: lastRelocate?.cfi ?? null,
      renderedLocator,
      canonicalLocator,
      currentPageText: clampPayloadText(lastRelocate?.range?.toString?.() ?? ''),
    }

    return {
      payload,
      trace: {
        href: payload.href,
        currentPage: windowPageMetrics.currentPage,
        totalPages: windowPageMetrics.totalPages,
        windowPageIndex: windowPageMetrics.currentPage,
        windowPageCount: windowPageMetrics.totalPages,
        windowMetricSource: windowPageMetrics.source,
        globalPageIndex: globalPageMetrics.pageIndex,
        globalPageCount: globalPageMetrics.totalPages,
        globalMetricSource: globalPageMetrics.source,
        rendererFraction: windowPageMetrics.rawFraction,
        rendererPageSize: windowPageMetrics.rawPageSize,
      },
    }
  }

  // EPUB/PDF/etc. mode
  const detail = lastRelocate ?? {}
  const tocItem = detail.tocItem ?? {}
  const chapterTitle = tocItem.label ?? null
  const chapterHref = tocItem.href ?? null
  const chapterLocation = detail.chapterLocation ?? {}

  const payload = {
    rendererType: 'foliate',
    format: currentFormat ?? 'epub',
    currentPage: windowPageMetrics.currentPage,
    totalPages: windowPageMetrics.totalPages,
    cfi: detail.cfi ?? null,
    href: chapterHref,
    chapterTitle,
    chapterTotalPages: Number(chapterLocation.total ?? 1),
    chapterCurrentPage: Number(chapterLocation.current ?? 1),
    progression: Number(detail.fraction ?? 0),
    renderedLocator,
    canonicalLocator,
    currentPageText: clampPayloadText(detail.range?.toString?.() ?? ''),
  }

  return { payload, trace: {} }
}

// ---------------------------------------------------------------------------
// §12  Relocate Emission & Navigation Queue
// ---------------------------------------------------------------------------

const cancelScheduledRelocate = () => {
  if (relocateAnimationFrame != null) {
    cancelAnimationFrame(relocateAnimationFrame)
    relocateAnimationFrame = null
  }
}

const emitRelocate = () => {
  const relocateState = buildRelocateState()
  post('relocate', relocateState.payload)
  if (relocateState.trace && Object.keys(relocateState.trace).length) {
    postTrace('relocate', relocateState.trace)
  }
}

const scheduleRelocate = () => {
  if (relocateAnimationFrame != null) return
  relocateAnimationFrame = requestAnimationFrame(() => {
    relocateAnimationFrame = null
    emitRelocate()
  })
}

const enqueueNavigation = (label, context, work) => {
  navigationQueue = navigationQueue
    .catch(() => {})
    .then(async () => {
      postTrace(`${label} start`, context)
      await work()
      postTrace(`${label} end`, context)
    })
  return navigationQueue
}

const waitForFirstRelocate = (currentToken, timeoutMs = 3500) => new Promise(resolve => {
  if (currentToken !== initialOpenToken) { resolve(false); return }
  if (lastRelocate) { resolve(true); return }
  const currentView = view
  if (!currentView) { resolve(false); return }

  let settled = false
  let timer = null
  const finish = relocated => {
    if (settled) return
    settled = true
    if (timer) clearTimeout(timer)
    currentView.removeEventListener('relocate', handleRelocate)
    resolve(relocated)
  }
  const handleRelocate = () => finish(true)

  currentView.addEventListener('relocate', handleRelocate)
  timer = setTimeout(() => {
    postTrace('initial relocate timeout', { timeoutMs })
    finish(false)
  }, timeoutMs)
})

// ---------------------------------------------------------------------------
// §13  Selection Emission
// ---------------------------------------------------------------------------

const runInteractionCleanups = () => {
  for (const cleanup of interactionCleanupCallbacks.splice(0)) {
    try { cleanup() } catch (error) { console.warn('[OrigoFoliateHost] cleanup failed', error) }
  }
}

const attachDocumentSelectionHandlers = doc => {
  if (!doc || doc.documentElement?.dataset?.origoSelectionAttached === 'true') return
  doc.documentElement.dataset.origoSelectionAttached = 'true'

  let selectionTimer = null

  const handleSelectionChange = () => {
    clearTimeout(selectionTimer)
    selectionTimer = setTimeout(() => { emitSelection() }, 180)
  }

  doc.addEventListener('selectionchange', handleSelectionChange)

  interactionCleanupCallbacks.push(() => {
    clearTimeout(selectionTimer)
    doc.removeEventListener('selectionchange', handleSelectionChange)
    if (doc.documentElement?.dataset) {
      delete doc.documentElement.dataset.origoSelectionAttached
    }
  })
}

const emitSelection = () => {
  const content = view?.renderer?.getContents?.().find(item => item.index === (view?.renderer?.primaryIndex ?? 0))
  const selection = content?.doc?.defaultView?.getSelection?.()
  if (!selection || selection.isCollapsed || selection.rangeCount === 0) return
  const range = selection.getRangeAt(0)
  const selectedText = selection.toString().trim()
  if (!selectedText) return

  const windowPageMetrics = buildWindowPageMetrics(lastRelocate)

  if (currentFormat === 'txt') {
    const canonical = rangeToCanonical(range)
    const index = view?.renderer?.primaryIndex ?? 0
    const chapter = chapterForIndex(index)
    const renderedLocator = buildRenderedLocator()
    post('selection', {
      text: selectedText,
      chapterID: chapter?.sourceChapterID ?? chapter?.id ?? null,
      canonicalStart: canonical?.start ?? null,
      canonicalEnd: canonical?.end ?? null,
      pageIndex: windowPageMetrics.currentPage,
      renderedLocator,
      canonicalLocator: buildCanonicalLocator(renderedLocator),
    })
  } else {
    // EPUB/PDF/etc. mode: use CFI-based selection
    const cfi = view?.getCFI?.(view?.renderer?.primaryIndex ?? 0, range)
    post('selection', {
      text: selectedText,
      cfi,
      pageIndex: windowPageMetrics.currentPage,
      range: { startContainer: range.startContainer.nodeName, startOffset: range.startOffset, endContainer: range.endContainer.nodeName, endOffset: range.endOffset },
    })
  }
}

// ---------------------------------------------------------------------------
// §14  Annotation Emission
// ---------------------------------------------------------------------------

const emitAnnotationActivated = detail => {
  const value = `${detail?.value ?? ''}`.trim()
  if (!value) return
  const windowPageMetrics = buildWindowPageMetrics(lastRelocate)
  post('annotationActivated', {
    annotationId: value,
    pageIndex: windowPageMetrics.currentPage,
  })
}

// ---------------------------------------------------------------------------
// §15  Style & Preference Application
// ---------------------------------------------------------------------------

const generateCSS = preferences => {
  // Common base styles for all formats
  const fontFamily = preferences.fontFamily ?? 'system-ui'
  const fontSize = preferences.fontSize ?? 1.25
  const lineHeight = preferences.lineHeight ?? 1.5
  const textColor = preferences.textColor ?? '#111111'
  const backgroundColor = preferences.backgroundColor ?? '#ffffff'
  const selectionColor = preferences.selectionColor ?? 'rgba(167, 96, 52, 0.3)'
  const textIndent = preferences.textIndent ?? 0
  const paragraphSpacing = preferences.paragraphSpacing ?? 0
  const letterSpacing = preferences.letterSpacing ?? 0
  const textAlign = preferences.textAlign ?? (preferences.justify ? 'justify' : 'start')
  const hyphenate = preferences.hyphenate ?? true
  const writingMode = preferences.writingMode ?? 'horizontal-tb'
  const customCSS = preferences.customCSS ?? ''
  const customCSSEnabled = preferences.customCSSEnabled ?? false

  const fontFamilyCSS = fontFamily === 'book' ? '' :
    fontFamily === 'system' ? 'font-family: system-ui !important;' :
      `font-family: ${fontFamily} !important;`

  const writingModeCSS = writingMode === 'auto' ? '' : `writing-mode: ${writingMode} !important;`

  const backgroundImageCSS = !preferences.backgroundImage || preferences.backgroundImage === 'none'
    ? 'background: none !important;'
    : `background-image: url('${preferences.backgroundImage}') !important;
       background-size: 100% 100% !important;
       background-repeat: repeat !important;
       background-attachment: scroll !important;
       background-position: center center !important;
       background-clip: content-box !important;`

  const fontFaceCSS = preferences.fontPath
    ? `@font-face { font-family: ${fontFamily}; src: url('${preferences.fontPath}'); font-display: swap; }`
    : ''

  return `
    @namespace epub "http://www.idpf.org/2007/ops";
    ${fontFaceCSS}

    :root {
      color-scheme: ${preferences.isDark ? 'dark' : 'light'};
    }

    html {
      ${writingModeCSS}
      color: ${textColor} !important;
      ${backgroundImageCSS}
      background-color: transparent !important;
      letter-spacing: ${letterSpacing}px;
      font-size: ${fontSize}em;
      text-size-adjust: 100% !important;
      -webkit-text-size-adjust: 100% !important;
      overflow-wrap: anywhere !important;
      word-break: normal !important;
    }

    body {
      background: none !important;
      background-color: transparent;
      overflow-wrap: anywhere !important;
      word-break: normal !important;
      max-width: 100% !important;
      padding: ${preferences.topMargin ?? 0}px ${preferences.sideMargin ?? 0}px ${preferences.bottomMargin ?? 0}px;
    }

    img {
      max-width: 100% !important;
      object-fit: contain !important;
      break-inside: avoid !important;
      box-sizing: border-box !important;
    }

    a:link { color: rgb(167, 96, 52) !important; }

    * {
      line-height: ${lineHeight}em !important;
      ${fontFamilyCSS}
      box-sizing: border-box !important;
    }

    p, li, blockquote, dd, div, font {
      color: ${textColor} !important;
      font-weight: ${preferences.fontWeight ?? 400} !important;
      padding-bottom: ${paragraphSpacing}em !important;
      text-align: ${textAlign === 'auto' ? (preferences.justify ? 'justify' : 'start') : textAlign};
      -webkit-hyphens: ${hyphenate ? 'auto' : 'manual'};
      hyphens: ${hyphenate ? 'auto' : 'manual'};
      -webkit-hyphenate-limit-before: 3;
      -webkit-hyphenate-limit-after: 2;
      -webkit-hyphenate-limit-lines: 2;
      hanging-punctuation: none !important;
      overflow-wrap: anywhere !important;
      word-break: normal !important;
      margin-top: 0 !important;
      margin-bottom: 0 !important;
      orphans: 2;
      widows: 2;
    }

    ${textIndent >= 0 ? `
    p, li, blockquote, dd, font {
      text-indent: ${textIndent}em !important;
    }
    p img { margin-left: -${textIndent}em; }
    ` : ''}

    [align="left"] { text-align: left; }
    [align="right"] { text-align: right; }
    [align="center"] { text-align: center; }
    [align="justify"] { text-align: justify; }

    pre { white-space: pre-wrap !important; overflow-wrap: anywhere !important; word-break: break-word !important; }
    code, samp, kbd { overflow-wrap: anywhere !important; word-break: break-word !important; }
    table { width: 100% !important; max-width: 100% !important; table-layout: fixed !important; }
    td, th { overflow-wrap: anywhere !important; word-break: break-word !important; }

    ::selection { background: ${selectionColor}; }

    aside[epub|type~="endnote"],
    aside[epub|type~="footnote"],
    aside[epub|type~="note"],
    aside[epub|type~="rearnote"] { display: none; }

    ${customCSSEnabled && customCSS ? customCSS : ''}
  `
}

const applyPreferences = preferences => {
  if (!view?.renderer) return

  // Body background for all formats
  document.body.style.background = preferences.backgroundColor ?? 'transparent'
  document.documentElement.style.backgroundColor = preferences.backgroundColor ?? '#ffffff'

  const mode = preferences.verticalScroll ? 'scrolled' : 'paginated'
  view.renderer.setAttribute('flow', mode)
  view.renderer.setAttribute('max-column-count', preferences.maxColumnCount ?? 1)

  // Renderer margin attributes
  view.renderer.setAttribute('top-margin', `${preferences.topMargin ?? 0}px`)
  view.renderer.setAttribute('bottom-margin', `${preferences.bottomMargin ?? 0}px`)
  view.renderer.setAttribute('gap', `${preferences.sideMargin ?? 5}%`)
  view.renderer.setAttribute('background-color', preferences.backgroundColor ?? '#ffffff')

  if (preferences.maxInlineSize) {
    view.renderer.setAttribute('max-inline-size', `${Math.max(Number(preferences.maxInlineSize ?? 720), 280)}px`)
  }
  if (preferences.maxBlockSize) {
    view.renderer.setAttribute('max-block-size', `${Math.max(Number(preferences.maxBlockSize ?? 1200), 320)}px`)
  }

  // Animation
  if (preferences.animated) {
    view.renderer.setAttribute('animated', '')
  } else {
    view.renderer.removeAttribute('animated')
  }

  // Background image
  if (preferences.backgroundImage && preferences.backgroundImage !== 'none') {
    view.renderer.setAttribute('bgimg-url', preferences.backgroundImage)
  } else {
    view.renderer.removeAttribute('bgimg-url')
  }

  // CSS styles
  const css = generateCSS(preferences)
  view.renderer.setStyles?.(css)
}

// ---------------------------------------------------------------------------
// §16  Navigation Helpers
// ---------------------------------------------------------------------------

const navigateToCanonical = async locator => {
  const target = parseJSON(locator)
  if (!target) return false
  const chapter = chapterForCanonicalTarget(target)
  if (!chapter) {
    postTrace('navigate canonical skipped', { reason: 'chapter-missing', chapterID: target.chapterID ?? target.textAnchor?.chapterID ?? null })
    return false
  }
  const offset = Number(target.textAnchor?.offsetHint ?? 0)
  const index = currentPayload.chapters.findIndex(item => item.id === chapter.id)
  if (index < 0) {
    postTrace('navigate canonical skipped', { reason: 'chapter-index-missing', chapterID: chapter.id })
    return false
  }
  postTrace('navigate canonical start', { chapterID: chapter.id, offset, index })
  await view.renderer.goTo({
    index,
    anchor: doc => rangeForCanonicalOffset(doc, offset) ?? doc.body,
  })
  return true
}

const navigateToRendered = async locator => {
  const target = parseJSON(locator)
  if (!target) return false

  if (currentFormat === 'txt') {
    if (target.href && hasChapterHref(target.href)) {
      postTrace('navigate rendered start', { href: target.href })
      await view.goTo(target.href)
      return true
    }
    postTrace('navigate rendered skipped', { href: target.href ?? null, reason: 'href-missing-or-unknown' })
    return false
  }

  // EPUB/PDF/etc.: navigate by CFI or href
  if (target.cfi) {
    postTrace('navigate rendered start', { cfi: target.cfi })
    await view.goTo(target.cfi)
    return true
  }
  if (target.href) {
    postTrace('navigate rendered start', { href: target.href })
    await view.goTo(target.href)
    return true
  }
  postTrace('navigate rendered skipped', { reason: 'no-cfi-or-href' })
  return false
}

const restoreInitialLocation = async () => {
  if (!view || !currentPayload) return
  try {
    postTrace('restore initial location start', {
      hasCanonical: Boolean(currentPayload.initialCanonicalLocator),
      hasRendered: Boolean(currentPayload.initialRenderedLocator),
      hasCfi: Boolean(currentPayload.initialCfi),
      hasProgress: Boolean(currentPayload.initialProgress),
    })

    // TXT mode: try canonical → rendered → init fallback
    if (currentFormat === 'txt') {
      const restoredCanonical = await runWithTimeout('navigate canonical', () =>
        navigateToCanonical(currentPayload.initialCanonicalLocator))
      const restoredRendered = restoredCanonical
        ? false
        : await runWithTimeout('navigate rendered', () =>
          navigateToRendered(currentPayload.initialRenderedLocator))

      if (!restoredCanonical && !restoredRendered) {
        await runWithTimeout('view init fallback', () => view.init({ showTextStart: true }), 2500)
      }
      postTrace('restore initial location result', { restoredCanonical, restoredRendered })
      return
    }

    // EPUB/PDF/etc. mode: try CFI → fraction fallback
    if (currentPayload.initialCfi) {
      await runWithTimeout('navigate cfi', () => view.init({ lastLocation: currentPayload.initialCfi }), 3500)
    } else if (typeof currentPayload.initialProgress === 'number' && !Number.isNaN(currentPayload.initialProgress)) {
      await view.init()
      await runWithTimeout('navigate fraction', () =>
        view.goToFraction(Math.min(0.9999, Math.max(0, currentPayload.initialProgress))), 2500)
    } else {
      await view.init()
    }
    postTrace('restore initial location done')
  } catch (error) {
    postError('initial-location', error, {
      format: currentFormat,
      bookId: currentPayload?.bookId ?? null,
    })
  }
}

const withTemporaryRendererAnimation = async (animated, work) => {
  const renderer = view?.renderer
  if (!renderer) { await work(); return }

  const hadAnimatedAttribute = renderer.hasAttribute('animated')
  const resolvedAnimated = typeof animated === 'boolean' ? animated : hadAnimatedAttribute

  if (resolvedAnimated) { renderer.setAttribute('animated', '') }
  else { renderer.removeAttribute('animated') }

  try { await work() }
  finally {
    if (hadAnimatedAttribute) { renderer.setAttribute('animated', '') }
    else { renderer.removeAttribute('animated') }
  }
}

// ---------------------------------------------------------------------------
// §17  Annotation Support
// ---------------------------------------------------------------------------

const setupAnnotationViewHandlers = () => {
  if (!view) return

  view.addEventListener('create-overlay', event => {
    const { index } = event.detail ?? {}
    const list = annotationsMap.get(index)
    if (list) {
      for (const annotation of list) {
        view.addAnnotation(annotation)
      }
    }
  })

  view.addEventListener('draw-annotation', event => {
    const { draw, annotation } = event.detail ?? {}
    const { color, type } = annotation
    if (type === 'highlight') draw(Overlayer.highlight, { color })
    else if (type === 'underline') draw(Overlayer.underline, { color })
  })

  view.addEventListener('show-annotation', event => {
    emitAnnotationActivated(event.detail)
  })
}

// ---------------------------------------------------------------------------
// §18  The Public Host Object — window.origoFoliateHost
// ---------------------------------------------------------------------------

window.origoFoliateHost = {
  // ── open(payload, preferences) ──────────────────────────────────────────
  // Opens a book. Payload determines format:
  //   - manifest (TXT mode): chapters array + manifestURL
  //   - url + format: direct file (epub, mobi, fb2, pdf)
  async open(payload, preferences) {
    try {
      await ensureFoliateViewModule()

      initialOpenToken += 1
      const currentOpenToken = initialOpenToken

      // Parse payload if it comes as a JSON string
      const request = typeof payload === 'string' ? JSON.parse(payload) : payload

      // Resolve manifest URL if present (fetches manifest JSON from localhost)
      if (request?.manifestURL && !request?.chapters?.length) {
        postTrace('manifest fetch start', { manifestURL: request.manifestURL })
        try {
          const response = await fetch(request.manifestURL)
          if (!response.ok && response.status !== 0) {
            throw new Error(`Failed to load manifest: ${response.status} ${response.statusText}`)
          }
          const manifest = await response.json()
          postTrace('manifest fetch end', {
            chapterCount: manifest.chapters?.length ?? 0,
            title: manifest.title ?? request.bookTitle,
          })
          request.chapters = manifest.chapters ?? []
          request.bookTitle = manifest.title ?? request.bookTitle ?? manifest.bookTitle
          request.language = manifest.language ?? request.language ?? manifest.language
          request.bookId = manifest.bookId ?? request.bookId ?? manifest.bookId
          request.totalUTF16Length = manifest.totalUTF16Length ?? request.totalUTF16Length ?? manifest.totalUTF16Length
          request.manifestURL = request.manifestURL
        } catch (error) {
          postError('manifest-fetch', error, { manifestURL: request.manifestURL })
          throw error
        }
      }

      currentPayload = request
      traceEnabled = Boolean(currentPayload?.enableDebugTrace)
      postTrace('open start', { format: currentPayload.manifest ? 'txt' : currentPayload.format ?? 'auto' })

      // Reset state
      observedChapterPageSpans = new Map()
      lastRelocate = null
      cancelScheduledRelocate()
      navigationQueue = Promise.resolve()
      runInteractionCleanups()
      annotationsMap = new Map()
      annotationsByValue = new Map()
      searchIterator = null

      // Clean up previous view
      if (view) {
        currentBookCleanup?.()
        currentBookCleanup = null
        view.close?.()
        view.remove()
        view = null
      }
      currentBook = null
      currentFormat = null

      // ── Format routing ──
      let book

      if (currentPayload.manifest || currentPayload.chapters?.length) {
        // TXT mode: build synthetic book from manifest chapters
        currentFormat = 'txt'
        currentPayload.manifestURL = currentPayload.manifestURL ?? currentPayload.manifest
        book = buildSyntheticBook(currentPayload)
      } else if (currentPayload.url) {
        // Direct file mode: resolve book from URL + format
        book = await resolveBookFromDirectFile(currentPayload)
      } else {
        throw new Error('Payload must contain either manifest/chapters or url+format')
      }

      currentBook = book
      currentBookCleanup = typeof book.cleanup === 'function' ? book.cleanup.bind(book) : null

      // Create <foliate-view> and open book
      view = document.createElement('foliate-view')
      if (readerElement) {
        readerElement.replaceChildren(view)
      } else {
        document.body.append(view)
      }

      postTrace('view open start', {
        format: currentFormat,
        chapterCount: currentPayload.chapters?.length ?? 0,
      })

      await view.open(book)
      postTrace('view open end')

      // Attach event listeners
      view.addEventListener('load', event => {
        const detail = event.detail ?? {}
        postTrace('section load', { index: detail.index ?? null })
        attachDocumentSelectionHandlers(detail.doc)
      })

      view.addEventListener('relocate', event => {
        lastRelocate = event.detail ?? null
        scheduleRelocate()
      })

      // Annotation handlers (for all formats)
      setupAnnotationViewHandlers()

      // Footnote support for EPUB
      if (currentFormat === 'epub') {
        try {
          const { FootnoteHandler } = await import('./footnotes.js')
          const footnoteHandler = new FootnoteHandler()
          footnoteHandler.addEventListener('before-render', e => {
            const footnoteView = e.detail.view
            footnoteView.addEventListener('load', fnEvent => {
              const fnDoc = fnEvent.detail.doc
              attachDocumentSelectionHandlers(fnDoc)
            })
          })
          view.addEventListener('link', e => {
            footnoteHandler.handle(view.book, e)?.catch(err => {
              console.warn('[OrigoFoliateHost] footnote failed', err)
              view.goTo(e.detail.href)
            })
          })
        } catch (error) {
          console.warn('[OrigoFoliateHost] FootnoteHandler import failed', error)
        }
      }

      // Apply preferences
      applyPreferences(preferences ?? {})

      // Restore initial location
      const initialRelocatePromise = waitForFirstRelocate(currentOpenToken)
      await restoreInitialLocation()
      const initialRelocateReceived = await initialRelocatePromise

      postTrace('open ready', {
        initialRelocateReceived,
        format: currentFormat,
      })

      if (currentOpenToken !== initialOpenToken) {
        postTrace('open superseded', { currentOpenToken, initialOpenToken })
        return
      }

      // Send TOC data
      this.getToc()

      post('opened', {
        format: currentFormat,
        bookTitle: currentBook?.metadata?.title ?? currentPayload?.bookTitle ?? null,
      })
    } catch (error) {
      postError('open', error, { bookId: currentPayload?.bookId ?? null })
    }
  },

  // ── updatePreferences(pref) ─────────────────────────────────────────────
  updatePreferences(pref) {
    try {
      void ensureFoliateViewModule()
      applyPreferences(pref ?? {})
      scheduleRelocate()
    } catch (error) {
      postError('update-preferences', error)
    }
  },

  // ── step(delta) ─────────────────────────────────────────────────────────
  async step(delta) {
    try {
      await ensureFoliateViewModule()
      if (!view) return
      await enqueueNavigation('step', { delta }, async () => {
        if (delta < 0) await view.prev()
        if (delta > 0) await view.next()
        scheduleRelocate()
      })
    } catch (error) {
      postError('step', error, { delta })
    }
  },

  // ── goToCanonical(locator) ──────────────────────────────────────────────
  // Navigate by CanonicalLocator (chapterID + offset). TXT mode only.
  async goToCanonical(locator) {
    try {
      await ensureFoliateViewModule()
      await enqueueNavigation('go-to-canonical', { locator }, async () => {
        if (await navigateToCanonical(locator)) scheduleRelocate()
      })
    } catch (error) {
      postError('go-to-canonical', error, { locator })
    }
  },

  // ── goToRendered(locator) ───────────────────────────────────────────────
  // Navigate by RenderedLocator (href + progression). Works for all formats.
  async goToRendered(locator) {
    try {
      await ensureFoliateViewModule()
      await enqueueNavigation('go-to-rendered', { locator }, async () => {
        if (await navigateToRendered(locator)) scheduleRelocate()
      })
    } catch (error) {
      postError('go-to-rendered', error, { locator })
    }
  },

  // ── goToCfi(cfi) ────────────────────────────────────────────────────────
  // Navigate by EPUB CFI string. EPUB/PDF/etc. mode only.
  async goToCfi(cfi) {
    try {
      await ensureFoliateViewModule()
      if (!view) return
      await enqueueNavigation('go-to-cfi', { cfi }, async () => {
        await view.goTo(cfi)
        scheduleRelocate()
      })
    } catch (error) {
      postError('go-to-cfi', error, { cfi })
    }
  },

  // ── goToPercent(fraction) ───────────────────────────────────────────────
  // Navigate by fraction of total book (0..1). Works for all formats.
  async goToPercent(fraction) {
    try {
      await ensureFoliateViewModule()
      if (!view) return
      const clampedFraction = Math.min(Math.max(Number(fraction ?? 0), 0), 0.9999)
      await enqueueNavigation('go-to-percent', { fraction: clampedFraction }, async () => {
        await view.goToFraction(clampedFraction)
        scheduleRelocate()
      })
    } catch (error) {
      postError('go-to-percent', error, { fraction })
    }
  },

  // ── snapshot() ──────────────────────────────────────────────────────────
  // Returns current relocate state synchronously.
  snapshot() {
    try {
      return buildRelocateState().payload
    } catch (error) {
      postError('snapshot', error)
      return null
    }
  },

  // ── addAnnotation(annotation) ───────────────────────────────────────────
  // Adds highlight/underline overlay via Overlayer.
  addAnnotation(annotation) {
    try {
      if (!view) return

      const { value, type, color, note, id } = annotation

      // Calculate spine index for the annotation
      const spineCode = currentFormat === 'txt'
        ? (view?.renderer?.primaryIndex ?? 0)
        : value ? ((value.split('/')[2].split('!')[0] - 2) / 2) : (view?.renderer?.primaryIndex ?? 0)

      const storedAnnotation = { id, value, type, color, note }

      const list = annotationsMap.get(spineCode)
      if (list) list.push(storedAnnotation)
      else annotationsMap.set(spineCode, [storedAnnotation])

      annotationsByValue.set(value, storedAnnotation)

      if (type === 'bookmark') {
        // Bookmarks don't need visual overlay, just store
      } else {
        view.addAnnotation(storedAnnotation)
      }
    } catch (error) {
      postError('add-annotation', error, { annotation })
    }
  },

  // ── removeAnnotation(cfi) ───────────────────────────────────────────────
  // Removes annotation overlay by CFI/value.
  removeAnnotation(cfi) {
    try {
      if (!view) return

      const annotation = annotationsByValue.get(cfi)
      if (!annotation) return

      const { value } = annotation
      const spineCode = currentFormat === 'txt'
        ? (view?.renderer?.primaryIndex ?? 0)
        : (value.split('/')[2].split('!')[0] - 2) / 2

      const list = annotationsMap.get(spineCode)
      if (list) {
        const index = list.findIndex(a => a.id === annotation.id)
        if (index !== -1) list.splice(index, 1)
      }

      annotationsByValue.delete(value)

      if (annotation.type !== 'bookmark') {
        try { view.addAnnotation(annotation, true) } catch (_) {}
      }
    } catch (error) {
      postError('remove-annotation', error, { cfi })
    }
  },

  // ── renderAnnotations(annotations) ──────────────────────────────────────
  // Batch render all saved annotations for current section.
  renderAnnotations(annotations) {
    try {
      if (!view) return

      // Clear existing
      for (const annotation of annotationsByValue.values()) {
        if (annotation.type !== 'bookmark') {
          try { view.addAnnotation(annotation, true) } catch (_) {}
        }
      }
      annotationsMap.clear()
      annotationsByValue.clear()

      // Add new batch
      const annos = annotations ?? []
      for (const anno of annos) {
        this.addAnnotation(anno)
      }
    } catch (error) {
      postError('render-annotations', error)
    }
  },

  // ── search(config) ──────────────────────────────────────────────────────
  // Starts text search via foliate search / text-walker.
  async search(config) {
    try {
      if (!view) return

      const query = (config?.query ?? config?.text ?? '').trim()
      if (!query) return

      const opts = {
        query,
        scope: config?.scope ?? 'book',
        matchCase: config?.matchCase ?? false,
        matchDiacritics: config?.matchDiacritics ?? false,
        matchWholeWords: config?.matchWholeWords ?? false,
        index: config?.scope === 'section' ? (view?.renderer?.primaryIndex ?? 0) : null,
      }

      this.clearSearch()

      for await (const result of view.search(opts)) {
        if (result === 'done') {
          post('searchResult', { progress: 1.0, done: true })
        } else if ('progress' in result) {
          post('searchResult', { progress: result.progress })
        } else {
          post('searchResult', {
            cfi: result.cfi ?? null,
            text: result.text ?? result.excerpt ?? null,
            pre: result.pre ?? null,
            post: result.post ?? null,
            href: result.href ?? null,
            progress: result.progress ?? null,
          })
        }
      }
    } catch (error) {
      postError('search', error, { config })
    }
  },

  // ── clearSearch() ────────────────────────────────────────────────────────
  clearSearch() {
    try {
      if (!view) return
      view.clearSearch?.()
    } catch (error) {
      postError('clear-search', error)
    }
  },

  // ── initTTS() ────────────────────────────────────────────────────────────
  // Initializes TTS with sentence granularity.
  initTTS() {
    try {
      if (!view) return
      view.initTTS?.()
    } catch (error) {
      postError('init-tts', error)
    }
  },

  // ── ttsNext() ────────────────────────────────────────────────────────────
  // Advance TTS to next sentence. Returns utterance info.
  ttsNext() {
    try {
      if (!view || !view.tts) return null

      const result = view.tts.next(true)
      if (result) {
        const utterance = {
          text: result.text ?? '',
          lang: result.lang ?? null,
          range: result.range ?? null,
        }
        post('ttsUtterance', utterance)
        return utterance
      }

      // Try next section
      return null
    } catch (error) {
      postError('tts-next', error)
      return null
    }
  },

  // ── ttsStop() ────────────────────────────────────────────────────────────
  // Stop TTS overlay.
  ttsStop() {
    try {
      if (!view) return
      view.initTTS?.(true)
    } catch (error) {
      postError('tts-stop', error)
    }
  },

  // ── clearSelection() ────────────────────────────────────────────────────
  // Deselect text in the current view.
  clearSelection() {
    try {
      if (!view) return
      view.deselect?.()
    } catch (error) {
      postError('clear-selection', error)
    }
  },

  // ── getToc() ────────────────────────────────────────────────────────────
  // Return current TOC data.
  getToc() {
    try {
      if (!view || !currentBook) return

      const toc = currentBook.toc ?? []
      const sectionFractions = view.getSectionFractions?.() ?? []
      const lastLocation = view.lastLocation ?? {}
      const currentHref = (lastLocation?.tocItem?.href ?? '').split('#')[0]

      let currentChapterIndex = sectionFractions.findIndex(s => s.href === currentHref)
      if (currentChapterIndex === -1) currentChapterIndex = 0

      const currentSectionStart = sectionFractions[currentChapterIndex]?.fraction ?? 0
      const nextSectionStart = sectionFractions[currentChapterIndex + 1]?.fraction ?? 1
      const currentSectionPages = lastLocation?.chapterLocation?.total ?? 1
      const totalPages = currentSectionPages / Math.max(nextSectionStart - currentSectionStart, 0.01)

      const getFractionByHref = href => {
        href = href.split('#')[0]
        const section = sectionFractions.find(s => s.href === href)
        return section ? section.fraction : 0
      }

      const buildItems = (items, level) => {
        return (items ?? []).map(item => ({
          label: item.label,
          href: item.href,
          id: item.id ?? null,
          level,
          startPercentage: getFractionByHref(item.href),
          startPage: Math.ceil(getFractionByHref(item.href) * totalPages),
          subitems: buildItems(item.subitems, level + 1),
        }))
      }

      const tocData = buildItems(toc, 1)
      post('toc', tocData)
      return tocData
    } catch (error) {
      postError('get-toc', error)
      return null
    }
  },
}

// ---------------------------------------------------------------------------
// §19  Global Error Handlers
// ---------------------------------------------------------------------------

window.addEventListener('error', event => {
  postError('window-error', event.error ?? event.message, {
    filename: event.filename,
    lineno: event.lineno,
    colno: event.colno,
  })
})

window.addEventListener('unhandledrejection', event => {
  postError('unhandled-rejection', event.reason)
})

// ---------------------------------------------------------------------------
// §20  Ready Signal
// ---------------------------------------------------------------------------

post('ready', { version: 1, format: 'origo-foliate-host' })
