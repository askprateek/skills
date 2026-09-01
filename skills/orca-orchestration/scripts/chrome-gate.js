/**
 * Chrome gate harness — Main-owned per-ticket rendered-surface verification.
 *
 * Usage: inside the `browser` tool's `run` code field:
 *
 *   const gate = eval(fs.readFileSync(
 *     '<skill-root>/scripts/chrome-gate.js', // resolve relative to the
 *     'utf8'));                              // installed skill location
 *   return await gate(tab, {
 *     origin: 'http://localhost:3002',
 *     routes: [
 *       { path: '/',                tier: 'full' },
 *       { path: '/private-banking', tier: 'header-only' },
 *       { path: '/style-guide',     tier: 'bare' },
 *       { path: '/nonexistent-xyz', tier: 'bare', expectStatus: 404 },
 *     ],
 *     megaMenu: true,          // click-open Products menu + z-order probe
 *     // per-route expected copy: one substring, or an array of them. Matched
 *     // against the FULL rendered body text, so below-the-fold copy counts.
 *     expectText: { '/company': 'Company', '/products': ['Trading and Markets'] },
 *   });
 *
 * Tier contract (frames: Legal 1:192 / footer 1:411 / CTA 1:4290, PB 1:2633, 404 2015:3546):
 *   full        -> header 1, main 1, footer 1, cta 1   (from (marketing)/layout.tsx)
 *   header-only -> header 1,          footer 0, cta 0   (page renders Header itself)
 *   bare        -> header 0,          footer 0, cta 0
 *
 * Counts >1 are FAILures, not passes: they mean the page re-added chrome the
 * layout already provides. That is the predicted wave-3 defect class.
 *
 * Known-benign console noise (does not fail a gate):
 *   - /favicon.ico 404
 *   - Canvas2D willReadFrequently warning (hero globe getImageData)
 * Payload /admin + /api/* 500s are ENVIRONMENTAL (no local Postgres, gitignored
 * .env) and are never probed here.
 */
(async function gate(tab, spec) {
  const origin = spec.origin || 'http://localhost:3002'
  const BENIGN = [/favicon\.ico/i, /willReadFrequently/i]
  const TIERS = {
    full: { headers: 1, footers: 1, ctaPanels: 1, mains: 1 },
    'header-only': { headers: 1, footers: 0, ctaPanels: 0 },
    bare: { headers: 0, footers: 0, ctaPanels: 0 },
  }

  const msgs = []
  const bad = []
  // Handlers are kept in named refs so they can be DETACHED at the end of the
  // run. The tab is persistent across `browser` run blocks, so anonymous
  // listeners accumulate: every past gate() call keeps listening and reporting
  // into its own dead arrays, and stale pages (e.g. an HMR websocket for a
  // server that has since been stopped) surface as phantom failures on the
  // FIRST route of the next run. Symptom that caught this: a gate on :3007
  // reporting "ws://localhost:3005 ... failed".
  const onConsole = (m) => msgs.push(m.type() + ': ' + m.text().slice(0, 140))
  const onPageError = (e) => msgs.push('pageerror: ' + String(e).slice(0, 180))
  const onResponse = (r) => {
    const s = r.status()
    if (s >= 400) bad.push(s + ' ' + r.url().replace(origin, ''))
  }
  tab.page.on('console', onConsole)
  tab.page.on('pageerror', onPageError)
  tab.page.on('response', onResponse)

  const countChrome = () =>
    tab.evaluate(() => {
      const q = (s) => document.querySelectorAll(s).length
      const cta = [...document.querySelectorAll('div')].filter(
        (d) =>
          typeof d.className === 'string' &&
          d.className.includes('bg-dark') &&
          d.className.includes('min-h-[590px]'),
      )
      return {
        headers: q('header'),
        mains: q('main'),
        footers: q('footer'),
        ctaPanels: cta.length,
        h1: document.querySelector('h1')?.innerText || null,
        title: document.title,
        htmlClass: document.documentElement.className,
        bodyStart: document.body.innerText.trim().slice(0, 70),
        // Full text, for expectText. bodyStart is a 70-char REPORT field only:
        // matching expected copy against it silently fails for anything below
        // the fold, which is most of the page.
        bodyText: document.body.innerText,
      }
    })

  const results = []
  for (const route of spec.routes) {
    // Park on about:blank and let the previous document's in-flight requests
    // settle BEFORE clearing the buffers. Clearing then navigating is not
    // enough: a failing subresource from the prior page (e.g. a missing raster
    // on an intentional-404 route) resolves AFTER the reset and is then
    // mis-attributed to the next route. That produced a GATE FAIL on `/` and
    // `/style-guide` for a 404-page asset those routes never request.
    await tab.goto('about:blank', { waitUntil: 'load' })
    await new Promise((r) => setTimeout(r, 350))
    msgs.length = 0
    bad.length = 0
    const url = origin + route.path
    // Probe status from Node, NOT in-page. An in-page fetch() is subject to CORS:
    // when a gate run targets a different origin than the tab's current document,
    // the first route's probe is blocked (net::ERR_FAILED) and reports a bogus
    // 'ERR' even though the page itself navigates and renders correctly.
    const status = await fetch(url, { redirect: 'manual' })
      .then((r) => r.status)
      .catch(() => 'ERR')
    await tab.goto(url, { waitUntil: 'networkidle2' })
    const seen = await countChrome()

    const want = TIERS[route.tier]
    const fails = []
    for (const [k, v] of Object.entries(want)) {
      if (seen[k] !== v) {
        fails.push(
          `${k}: expected ${v}, got ${seen[k]}` +
            (seen[k] > v ? ' (chrome re-added — layout already provides it)' : ''),
        )
      }
    }
    const wantStatus = route.expectStatus ?? 200
    if (status !== wantStatus) fails.push(`HTTP ${status}, expected ${wantStatus}`)

    // expectText accepts a string OR an array of strings. Passing an array to a
    // bare `.includes()` coerces it to "a,b,c" and always fails, which reads as
    // a page defect when it is a harness defect. Each entry is reported by name.
    const wantText = spec.expectText?.[route.path]
    const wants = wantText == null ? [] : Array.isArray(wantText) ? wantText : [wantText]
    const haystack = `${seen.bodyText || ''}\n${seen.h1 || ''}`
    const missing = wants.filter((w) => !haystack.includes(w))
    if (missing.length) fails.push(`missing expected text: ${missing.map((m) => `"${m}"`).join(', ')}`)
    if (route.tier !== 'bare' && !seen.htmlClass.includes('aeonik')) {
      fails.push('Aeonik font variable absent from <html>')
    }

    // A route we EXPECT to 404 must not fail on its own 404 document response or
    // the console error the browser logs for it. Only foreign failures count.
    const selfNoise =
      wantStatus >= 400
        ? [new RegExp(route.path.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '$'), /Failed to load resource/i]
        : []
    const noise = [...BENIGN, ...selfNoise]
    const realMsgs = msgs.filter((m) => !noise.some((b) => b.test(m)))
    const realBad = bad.filter((b) => !noise.some((x) => x.test(b)))
    if (realMsgs.length) fails.push(`console: ${realMsgs.slice(0, 4).join(' | ')}`)
    if (realBad.length) fails.push(`failed requests: ${realBad.slice(0, 4).join(' | ')}`)

    results.push({
      route: route.path,
      tier: route.tier,
      status,
      counts: `header=${seen.headers} main=${seen.mains} footer=${seen.footers} cta=${seen.ctaPanels}`,
      h1: seen.h1,
      benignNoise: msgs.length - realMsgs.length + (bad.length - realBad.length),
      verdict: fails.length ? 'FAIL' : 'PASS',
      fails,
    })
  }

  // Mega-menu: CLICK-triggered, not hover. Hovering leaves it closed and every
  // assertion silently "passes" — that is a false pass. Assert it actually opened
  // by requiring panel content, then probe paint order via hit-testing.
  let mega = null
  if (spec.megaMenu) {
    await tab.goto(origin + '/', { waitUntil: 'networkidle2' })
    // Do NOT use puppeteer ElementHandle.click(): it waits for actionability and
    // hangs (Runtime.callFunctionOn protocol timeout) on this header. Native
    // HTMLElement.click() dispatches a real bubbling event that React handles.
    const before = await tab.evaluate(
      () => getComputedStyle(document.querySelector('header')).backgroundColor,
    )
    const clicked = await tab.evaluate(() => {
      const hdr = document.querySelector('header')
      if (!hdr) return 'no header'
      const el = [...hdr.querySelectorAll('a,button,span,div')].find(
         (e) => (e.innerText || '').trim() === 'Products',
      )
      if (!el) return 'no trigger'
      el.click()
      return 'ok'
    })
    if (clicked !== 'ok') {
      mega = { verdict: 'FAIL', fails: ['Products trigger not clickable: ' + clicked] }
    } else {
      await new Promise((r) => setTimeout(r, 800))
      mega = await tab.evaluate(() => {
        const hdr = document.querySelector('header')
        const items = [...document.querySelectorAll('a,div,li,h3')].filter((e) => {
          const t = (e.innerText || '').trim()
          return (
            t === 'Bank Accounts' || t === 'Digital Asset Management' || t === 'Treasury Management'
          )
        })
        const visible = items.filter((e) => {
          const r = e.getBoundingClientRect()
          const cs = getComputedStyle(e)
          return r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && +cs.opacity > 0.01
        })
        const probes = ['PAVEBANK', 'Products', 'Open Account', 'Client Login'].map((t) => {
          const el = [...hdr.querySelectorAll('a,button,span')].find(
            (e) => e.innerText.trim() === t,
          )
          if (!el) return { label: t, ok: false, detail: 'control missing' }
          const r = el.getBoundingClientRect()
          const hit = document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2)
          return { label: t, ok: !!hit && hdr.contains(hit), detail: hit ? hit.tagName : 'none' }
        })
        return {
          opened: visible.length,
          openHeaderBg: getComputedStyle(hdr).backgroundColor,
          headerClass: hdr.className.slice(0, 120),
          misspelled: [...document.querySelectorAll('a,div,li,h3')].some((e) =>
            /Tresury/.test(e.innerText || ''),
          ),
          probes,
        }
      })
      const f = []
      if (mega.opened < 3) f.push(`menu did not open (${mega.opened}/3 items visible) — FALSE PASS RISK`)
      if (mega.openHeaderBg === before) f.push(`header bg unchanged on open (${before})`)
      const behind = mega.probes.filter((p) => !p.ok).map((p) => p.label + '(' + p.detail + ')')
      if (behind.length) f.push(`panel paints over chrome: ${behind.join(', ')}`)
      if (mega.misspelled) f.push('design misspelling "Tresury" transcribed instead of corrected')
      mega.verdict = f.length ? 'FAIL' : 'PASS'
      mega.fails = f
    }
  }

  // Detach: the tab outlives this call. Leaving these attached makes every
  // later gate() run inherit phantom failures from stopped servers.
  tab.page.off('console', onConsole)
  tab.page.off('pageerror', onPageError)
  tab.page.off('response', onResponse)

  const failed = results.filter((r) => r.verdict === 'FAIL')
  return {
    head: spec.head || null,
    verdict: failed.length === 0 && (!mega || mega.verdict === 'PASS') ? 'GATE PASS' : 'GATE FAIL',
    routes: results,
    megaMenu: mega,
    failedRoutes: failed.map((r) => r.route),
  }
})
