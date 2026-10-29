# Arma una pagina por programa (programas/<nombre>/index.html) desde programa.html y programas.json.
# Uso: powershell -File .github\paginas-programas\generar.ps1 (desde la carpeta del sitio)
param([string]$Raiz = (Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\..')).Path)
$ErrorActionPreference = 'Stop'
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object Text.UTF8Encoding $false
$plantilla = [IO.File]::ReadAllText((Join-Path $aqui 'programa.plantilla'), $utf8)
$programas = [IO.File]::ReadAllText((Join-Path $aqui 'programas.json'), $utf8) | ConvertFrom-Json
$sitio = 'https://brizna-soft.github.io'

foreach ($p in $programas) {
    $url = "$sitio/programas/$($p.slug)/"
    $datos = [ordered]@{
        '@context'            = 'https://schema.org'
        '@type'               = 'SoftwareApplication'
        'name'                = $p.nombre
        'description'         = $p.descripcion
        'url'                 = $url
        'image'               = "$sitio/img/$($p.captura)"
        'screenshot'          = "$sitio/img/$($p.captura)"
        'applicationCategory' = $p.categoria
        'operatingSystem'     = $p.so
        'downloadUrl'         = $p.descarga
        'license'             = 'https://opensource.org/licenses/MIT'
        'isAccessibleForFree' = $true
        'inLanguage'          = 'es'
        'offers'              = [ordered]@{ '@type' = 'Offer'; 'price' = '0'; 'priceCurrency' = 'USD' }
        'author'              = [ordered]@{ '@type' = 'Organization'; 'name' = 'Brizna Soft'; 'url' = "$sitio/" }
    }
    $jsonld = "  <script type=`"application/ld+json`">" + ($datos | ConvertTo-Json -Depth 5 -Compress) + "</script>"

    # Seccion opcional despues de "Como instalarlo" (por ejemplo, el aviso de VB-CABLE en Chachalaca)
    $extra = ''; $claseOriginal = 'seccion alterna'
    if ($p.extra_html) {
        $extra = "`n`n    <section id=`"$($p.extra_id)`" class=`"seccion alterna`">`n      <div class=`"contenedor estrecho`">`n        <h2>$($p.extra_titulo)</h2>`n        $($p.extra_html)`n      </div>`n    </section>"
        $claseOriginal = 'seccion'
    }
    $items = ($p.items | ForEach-Object { "          <li>$_</li>" }) -join "`n"
    $pasos = ($p.pasos | ForEach-Object { "          <li>$_</li>" }) -join "`n"
    $html = $plantilla
    $valores = [ordered]@{
        'SLUG' = $p.slug; 'TITULO' = $p.titulo; 'OG_TITULO' = $p.og_titulo; 'DESCRIPCION' = $p.descripcion
        'TIPO' = $p.tipo; 'PLATAFORMA' = $p.plataforma; 'H1' = $p.h1; 'ENTRADA' = $p.entrada; 'ICONO' = $p.icono
        'CAPTURA' = $p.captura; 'CAPTURA_ANCHO' = [string]$p.captura_ancho; 'CAPTURA_ALTO' = [string]$p.captura_alto
        'CAPTURA_ALT' = $p.captura_alt; 'REPO' = $p.repo; 'ZIP' = $p.zip; 'DESCARGA' = $p.descarga
        'TEXTO_BOTON' = $p.texto_boton; 'CODIGO' = $p.codigo; 'REPORTAR' = $p.reportar; 'ITEMS' = $items
        'PASOS' = $pasos; 'ORIGINAL' = $p.original; 'CREDITOS' = $p.creditos; 'JSONLD' = $jsonld
        'EXTRA' = $extra; 'CLASE_ORIGINAL' = $claseOriginal
    }
    foreach ($k in $valores.Keys) { $html = $html.Replace("{{$k}}", $valores[$k]) }
    if ($html -match '\{\{[A-Z_]+\}\}') { throw "Quedo un hueco sin llenar en $($p.slug): $($Matches[0])" }
    $carpeta = Join-Path $Raiz "programas\$($p.slug)"
    New-Item -ItemType Directory -Force $carpeta | Out-Null
    [IO.File]::WriteAllText((Join-Path $carpeta 'index.html'), ($html -replace "`r`n", "`n"), $utf8)
    "pagina: programas/$($p.slug)/"
}
