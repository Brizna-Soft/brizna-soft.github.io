// Para cada programa con data-repo: pone su última versión y hace que «Descargar» baje su .zip directamente.
// Si GitHub no responde, quedan el texto y el enlace de siempre (la página de la última versión).
document.querySelectorAll('[data-repo]').forEach(async (tarjeta) => {
  try {
    const respuesta = await fetch(`https://api.github.com/repos/${tarjeta.dataset.repo}/releases/latest`, {
      headers: { Accept: 'application/vnd.github+json' }
    });
    if (!respuesta.ok) { return; }

    const version = await respuesta.json();
    const numero = String(version.tag_name || '').replace(/^v/, '');
    const patron = new RegExp(tarjeta.dataset.zip);
    const zip = (version.assets || []).find((a) => patron.test(a.name));
    const boton = tarjeta.querySelector('[data-descargar]');
    if (zip && boton && /^https:\/\/github\.com\//.test(zip.browser_download_url)) {
      boton.href = zip.browser_download_url;
    }

    const texto = tarjeta.querySelector('[data-version]');
    if (texto && /^\d+\.\d+\.\d+$/.test(numero)) {
      const fecha = version.published_at
        ? new Date(version.published_at).toLocaleDateString('es', { day: 'numeric', month: 'long', year: 'numeric' })
        : '';
      const tipo = texto.dataset.tipo ? `${texto.dataset.tipo} · ` : '';
      texto.textContent = `${tipo}Versión ${numero}${fecha ? ` · ${fecha}` : ''}`;
    }
  } catch {
    // Sin conexión con GitHub: no pasa nada
  }
});
