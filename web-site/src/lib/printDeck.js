// Imprimir o deck (ou salvar em PDF): as cartas no tamanho real (63 × 88 mm),
// 9 por folha A4, como o PDF do app (pdf_service.dart). Abre uma janela com
// as imagens e chama a impressão do navegador ("Salvar como PDF" também).

const escape = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`)

/** urls: uma por cópia (4 Forests = 4 imagens). Volta false se o navegador bloqueou a janela. */
export function printDeck(name, urls) {
  const list = urls.filter(Boolean)
  const win = window.open('', '_blank')
  if (!win) return false
  win.document.write(`<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>${escape(name)} — LifeLink</title>
<style>
  @page { size: A4; margin: 5mm; }
  * { box-sizing: border-box; }
  body { margin: 0; font-family: system-ui, sans-serif; }
  .info { padding: 12px; text-align: center; color: #555; font-size: 14px; }
  .sheet { display: grid; grid-template-columns: repeat(3, 63mm); gap: 1mm; justify-content: center; }
  .sheet img { width: 63mm; height: 88mm; display: block; object-fit: fill; break-inside: avoid; }
  .sheet img:nth-child(9n) { break-after: page; }
  @media print { .info { display: none; } }
</style></head><body>
<p class="info">Carregando ${list.length} cartas... a impressão abre sozinha (escolha "Salvar como PDF" para o arquivo).</p>
<div class="sheet">${list.map((u) => `<img src="${escape(u)}" alt="">`).join('')}</div>
<script>
  const imgs = [...document.images];
  let left = imgs.length;
  const done = () => { if (--left <= 0) setTimeout(() => window.print(), 300); };
  if (!left) window.print();
  imgs.forEach((i) => (i.complete ? done() : (i.onload = i.onerror = done)));
</script></body></html>`)
  win.document.close()
  return true
}
