# Arma las publicaciones de la pagina a partir de contenido/publicaciones/*.json (las escribe el panel):
#   - publicaciones/index.html con todas;
#   - la seccion "Publicaciones" de la portada (index.html) con las 6 mas nuevas;
#   - la direccion /publicaciones/ en sitemap.xml.
# Solo salen las que tienen "publicada" y "legal" marcados. Si un dato esta mal, se detiene sin cambiar nada.
# Uso: powershell -File .github\publicaciones\generar.ps1 [-Revisar]   (-Revisar solo comprueba los datos)
param(
    [string]$Raiz = (Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\..')).Path,
    [switch]$Revisar
)
$ErrorActionPreference = 'Stop'
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object Text.UTF8Encoding $false
$es = [Globalization.CultureInfo]::GetCultureInfo('es-ES')
$sitio = 'https://brizna-soft.github.io'
Add-Type -AssemblyName System.Drawing

function Html([string]$t) { [Net.WebUtility]::HtmlEncode($t) }

$carpeta = Join-Path $Raiz 'contenido\publicaciones'
$errores = New-Object Collections.Generic.List[string]
$lista = @()
if (Test-Path $carpeta) {
    foreach ($f in Get-ChildItem $carpeta -Filter *.json) {
        try { $p = [IO.File]::ReadAllText($f.FullName, $utf8) | ConvertFrom-Json }
        catch { $errores.Add("$($f.Name): no se puede leer"); continue }
        if (-not $p.publicada) { continue }
        if ($p.legal -ne $true) { $errores.Add("$($f.Name): falta marcar que es tuyo o que tienes permiso para compartirlo"); continue }
        foreach ($campo in 'titulo', 'descripcion', 'foto', 'enlace', 'fecha') { if (-not $p.$campo) { $errores.Add("$($f.Name): falta $campo") } }
        if ($p.enlace -and $p.enlace -notmatch '^https://[^\s"''<>]+$') { $errores.Add("$($f.Name): el enlace tiene que empezar con https://") }
        $foto = $null
        if ($p.foto) {
            if ($p.foto -notmatch '^/img/publicaciones/[A-Za-z0-9._-]+\.(jpe?g|png|webp|gif)$') {
                $errores.Add("$($f.Name): la foto tiene que estar en img/publicaciones y ser JPG, PNG, WEBP o GIF")
            }
            else {
                $foto = Join-Path $Raiz ($p.foto.TrimStart('/') -replace '/', '\')
                if (-not (Test-Path -LiteralPath $foto)) { $errores.Add("$($f.Name): no encuentro la foto $($p.foto)"); $foto = $null }
                elseif ((Get-Item -LiteralPath $foto).Length -gt 5MB) { $errores.Add("$($f.Name): la foto pesa mas de 5 MB") }
            }
        }
        $fecha = [datetime]::MinValue
        if ($p.fecha -and -not [datetime]::TryParse([string]$p.fecha, [ref]$fecha)) { $errores.Add("$($f.Name): la fecha no es valida") }
        $lista += [pscustomobject]@{ Datos = $p; Fecha = $fecha; Foto = $foto }
    }
}
if ($errores.Count) { $errores | ForEach-Object { "ERROR: $_" }; exit 1 }
if ($Revisar) { "Todo bien: $(@($lista).Count) publicacion(es) para mostrar"; exit 0 }

$lista = @($lista | Sort-Object Fecha -Descending)

function Tarjeta($x, [string]$prefijo) {
    $p = $x.Datos
    $ancho = 0; $alto = 0
    try { $img = [Drawing.Image]::FromFile($x.Foto); $ancho = $img.Width; $alto = $img.Height; $img.Dispose() } catch { }
    $medidas = if ($ancho -gt 0) { " width=`"$ancho`" height=`"$alto`"" } else { '' }
    $boton = if ($p.texto_boton) { [string]$p.texto_boton } else { 'Ver' }
    $descripcion = (Html ([string]$p.descripcion)) -replace "`r?`n", '<br>'
    @(
        '          <article class="publicacion">'
        "            <img src=`"$prefijo$($p.foto.TrimStart('/'))`" alt=`"$(Html $p.titulo)`"$medidas loading=`"lazy`">"
        '            <div class="publicacion-texto">'
        "              <p class=`"version`">$($x.Fecha.ToString("d 'de' MMMM 'de' yyyy", $es))</p>"
        "              <h3>$(Html $p.titulo)</h3>"
        "              <p>$descripcion</p>"
        "              <a class=`"boton principal`" href=`"$(Html $p.enlace)`" rel=`"noopener`">$(Html $boton)</a>"
        '            </div>'
        '          </article>'
    ) -join "`n"
}

# Primero se arma todo en memoria; solo al final se escribe. Si algo falla antes, no cambia ningun archivo.
function Leer([string]$ruta) { if (Test-Path -LiteralPath $ruta) { [IO.File]::ReadAllText($ruta, $utf8) -replace "`r`n", "`n" } else { $null } }

# Pagina con todas
$pagina = Join-Path $Raiz 'publicaciones\index.html'
$antesPagina = Leer $pagina
$nuevaPagina = $null
if ($lista.Count) {
    $tarjetas = ($lista | ForEach-Object { Tarjeta $_ '../' }) -join "`n"
    $nuevaPagina = [IO.File]::ReadAllText((Join-Path $aqui 'pagina.plantilla'), $utf8).Replace('{{TARJETAS}}', $tarjetas) -replace "`r`n", "`n"
}
$cambioPagina = $nuevaPagina -cne $antesPagina

# Seccion de la portada, entre <!--PUBLICACIONES--> y <!--/PUBLICACIONES-->
$portada = Join-Path $Raiz 'index.html'
$antesPortada = Leer $portada
if ($null -eq $antesPortada) { throw 'No encuentro index.html' }
$html = $antesPortada
if ($html -notmatch '<!--PUBLICACIONES-->') {
    $ancla = '    <section id="recomendados"'
    if (-not $html.Contains($ancla)) { throw 'No encuentro donde poner la seccion de publicaciones en index.html' }
    $html = $html.Replace($ancla, "    <!--PUBLICACIONES-->`n    <!--/PUBLICACIONES-->`n`n$ancla")
}
$seccion = ''
if ($lista.Count) {
    $tarjetas = ($lista | Select-Object -First 6 | ForEach-Object { Tarjeta $_ '' }) -join "`n"
    $seccion = ([IO.File]::ReadAllText((Join-Path $aqui 'seccion.plantilla'), $utf8).Replace('{{TARJETAS}}', $tarjetas) -replace "`r`n", "`n").TrimEnd() + "`n"
}
$html = [regex]::Replace($html, '(?s)<!--PUBLICACIONES-->.*?<!--/PUBLICACIONES-->', { param($m) "<!--PUBLICACIONES-->`n$seccion    <!--/PUBLICACIONES-->" })
$cambioPortada = $html -cne $antesPortada

# Mapa del sitio: /publicaciones/ solo si hay publicaciones; la fecha cambia solo si cambio la pagina
$mapa = Join-Path $Raiz 'sitemap.xml'
$antesMapa = Leer $mapa
if ($null -eq $antesMapa) { throw 'No encuentro sitemap.xml' }
$xml = $antesMapa
$hoy = (Get-Date).ToString('yyyy-MM-dd')
$patron = "(?s)  <url>\s*<loc>$([regex]::Escape("$sitio/publicaciones/"))</loc>\s*<lastmod>([^<]*)</lastmod>\s*</url>\s*"
$previa = [regex]::Match($xml, $patron)
$xml = [regex]::Replace($xml, $patron, '')
if ($lista.Count) {
    $fecha = if ($previa.Success -and -not $cambioPagina) { $previa.Groups[1].Value } else { $hoy }
    $xml = $xml.Replace('</urlset>', "  <url>`n    <loc>$sitio/publicaciones/</loc>`n    <lastmod>$fecha</lastmod>`n  </url>`n</urlset>")
}
if ($cambioPortada) { $xml = [regex]::Replace($xml, "(<loc>$([regex]::Escape("$sitio/"))</loc>\s*<lastmod>)[^<]*(</lastmod>)", "`${1}$hoy`${2}") }

# Ahora si: escribir lo que cambio. Cada archivo se escribe aparte y despues reemplaza al original, para que
# nunca quede uno a medio escribir (si algo falla aqui, el panel deja los tres como estan en GitHub).
function Reemplazar([string]$ruta, [string]$texto) {
    $temporal = "$ruta.nuevo"
    [IO.File]::WriteAllText($temporal, $texto, $utf8)
    Move-Item -LiteralPath $temporal -Destination $ruta -Force
}
if ($cambioPagina) {
    if ($null -ne $nuevaPagina) {
        New-Item -ItemType Directory -Force (Split-Path $pagina) | Out-Null
        Reemplazar $pagina $nuevaPagina
    }
    else { Remove-Item -LiteralPath $pagina }
}
if ($cambioPortada) { Reemplazar $portada $html }
if ($xml -cne $antesMapa) { Reemplazar $mapa $xml }
"Listo: $($lista.Count) publicacion(es) en la pagina"
