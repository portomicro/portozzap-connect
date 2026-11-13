# [Marca] PortoMicro-Solucoes em websistemas
# [Link] https://portomicro.com.br
#
# build-portozzap-connect.ps1 - Constroi a imagem propria do conector PortoZaaP Connect
# e, opcionalmente, publica no Docker Hub.
#
# Uso (na raiz do repositorio):
#   powershell -ExecutionPolicy Bypass -File deploy\build-portozzap-connect.ps1
#   powershell -ExecutionPolicy Bypass -File deploy\build-portozzap-connect.ps1 -Version 0.1.1
#   powershell -ExecutionPolicy Bypass -File deploy\build-portozzap-connect.ps1 -Version 0.1.1 -Push
#
# Depois do build, a stack do Portainer usa a imagem por WAC_IMAGE (variavel da stack).
# Ao publicar uma versao nova, atualize WAC_IMAGE e use "Recreate" no container.

param(
    [string]$Version = '0.1.0',
    [string]$Repository = 'portomicro/portozzap-connect',
    [switch]$Push,
    [string]$Dockerfile = 'Dockerfile',
    [string]$Context = '.'
)

$ErrorActionPreference = 'Stop'

$tagVersion = "$Repository`:$Version"
$tagLatest = "$Repository`:latest"

Write-Host "PortoZaaP Connect - build de imagem" -ForegroundColor Cyan
Write-Host "  contexto : $Context"
Write-Host "  dockerfile: $Dockerfile"
Write-Host "  tags     : $tagVersion , $tagLatest"
Write-Host "  VERSION  : $Version"
Write-Host ""

docker build `
    -f $Dockerfile `
    -t $tagVersion `
    -t $tagLatest `
    --build-arg VERSION=$Version `
    $Context
if ($LASTEXITCODE -ne 0) { Write-Host "FALHOU: docker build" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "Imagem construida:" -ForegroundColor Green
docker images --format '{{.Repository}}:{{.Tag}}  {{.Size}}  {{.CreatedSince}}' | Select-String ([regex]::Escape($Repository))

if (-not $Push) {
    Write-Host ""
    Write-Host "Build local apenas. Para publicar no Docker Hub:" -ForegroundColor Yellow
    Write-Host "  docker login"
    Write-Host "  powershell -ExecutionPolicy Bypass -File deploy\build-portozzap-connect.ps1 -Version $Version -Push"
    Write-Host ""
    Write-Host "Na stack do Portainer, mantenha WAC_IMAGE=$tagVersion e use 'Recreate' no servico."
    exit 0
}

Write-Host ""
Write-Host "Publicando no Docker Hub..." -ForegroundColor Cyan
docker push $tagVersion
if ($LASTEXITCODE -ne 0) { Write-Host "FALHOU: docker push $tagVersion (rode 'docker login')" -ForegroundColor Red; exit 1 }
docker push $tagLatest
if ($LASTEXITCODE -ne 0) { Write-Host "FALHOU: docker push $tagLatest" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "Publicado: https://hub.docker.com/r/$Repository" -ForegroundColor Green
Write-Host ""
Write-Host "Proximo passo no Portainer (Stacks > whatsapp-nativo > Environment variables):"
Write-Host "  WAC_IMAGE=$tagVersion"
Write-Host "depois 'Recreate' no servico portozzap-connect."
exit 0
