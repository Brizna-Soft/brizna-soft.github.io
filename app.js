// Pone la última versión de HNTorrent y hace que "Descargar para Windows" baje su .zip directamente.
// Si GitHub no responde, quedan el texto y el enlace de siempre (la página de la última versión).
(async () => {
  try {
    const respuesta = await fetch('https://api.github.com/repos/Brizna-Soft/hntorrent-descargas/releases/latest', {
      headers: { Accept: 'application/vnd.github+json' }
    });
    if (!respuesta.ok) { return; }

    const version = await respuesta.json();
    const numero = String(version.tag_name || '').replace(/^v/, '');
    const zip = (version.assets || []).find((a) => /^HNTorrent-\d+\.\d+\.\d+-x64\.zip$/.test(a.name));

    if (zip) {
      document.getElementById('hnt-descargar').href = zip.browser_download_url;
    }

    if (/^\d+\.\d+\.\d+$/.test(numero)) {
      const fecha = version.published_at
        ? new Date(version.published_at).toLocaleDateString('es', { day: 'numeric', month: 'long', year: 'numeric' })
        : '';
      document.getElementById('hnt-version').textContent =
        `Versión ${numero}${fecha ? ` · ${fecha}` : ''} · Windows 10 y 11 (64 bits)`;
    }
  } catch {
    // Sin conexión con GitHub: no pasa nada
  }
})();
