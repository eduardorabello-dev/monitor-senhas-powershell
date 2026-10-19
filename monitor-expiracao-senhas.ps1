<#
.SYNOPSIS
    Monitora a expiração de senhas de usuários de domínio a partir de um CSV.

.DESCRIPTION
    Lê uma planilha (CSV com separador ";") com a lista de usuários, consulta
    a data de expiração da senha de cada um com "net user <usuario> /domain",
    atualiza o próprio CSV e exibe um relatório colorido no terminal, com cada
    usuário classificado como EXPIRADA, CRITICA, ATENCAO ou OK.

    Antes de alterar o CSV, o script cria uma cópia de segurança.

.PARAMETER Arquivo
    Caminho do CSV de entrada. Padrão: .\usuarios.csv

.PARAMETER PastaBackup
    Pasta onde as cópias de segurança são salvas. Padrão: .\Backup

.PARAMETER ColunaUsuario
    Nome da coluna do CSV que contém o login do usuário. Padrão: USUARIO

.EXAMPLE
    .\monitor-expiracao-senhas.ps1 -Arquivo .\usuarios.csv
#>

param(
    [string]$Arquivo       = ".\usuarios.csv",
    [string]$PastaBackup   = ".\Backup",
    [string]$ColunaUsuario = "USUARIO"
)


$LimiteCritico = 7
$LimiteAtencao = 15

Clear-Host

function Obter-ExpiracaoSenha {
    param([string]$Usuario)

    try {
        $Consulta = net user $Usuario /domain 2>$null

        if ($LASTEXITCODE -ne 0) { return $null }

        
        $Linha = $Consulta | Where-Object {
            $_ -match "A senha expira" -or $_ -match "Password expires"
        }

        if (-not $Linha) { return $null }

        $DataTexto = ($Linha -replace "A senha expira", "" -replace "Password expires", "").Trim()

        return (Get-Date $DataTexto)
    }
    catch {
        return $null
    }
}

function Obter-Status {
    param([int]$DiasRestantes)

    if     ($DiasRestantes -lt 0)              { return "EXPIRADA" }
    elseif ($DiasRestantes -le $LimiteCritico) { return "CRITICA"  }
    elseif ($DiasRestantes -le $LimiteAtencao) { return "ATENCAO"  }
    else                                       { return "OK"       }
}


if (-not (Test-Path $Arquivo)) {
    Write-Host "`nArquivo nao encontrado: $Arquivo" -ForegroundColor Red
    Pause
    Exit
}

if (-not (Test-Path $PastaBackup)) {
    New-Item -Path $PastaBackup -ItemType Directory -Force | Out-Null
}

$Backup = Join-Path $PastaBackup ("Backup_{0}.csv" -f (Get-Date -Format "dd-MM-yy-HH-mm"))
Copy-Item -Path $Arquivo -Destination $Backup -Force



$Usuarios = Import-Csv $Arquivo -Delimiter ";" | Where-Object {
    $_.$ColunaUsuario -and $_.$ColunaUsuario.Trim() -ne ""
}



$Resultado  = @()
$Consultados = 0
$Atualizados = 0
$Erros       = 0

foreach ($Item in $Usuarios) {
    $Usuario = $Item.$ColunaUsuario.Trim()
    $Consultados++

    Write-Host "Consultando $Usuario..." -ForegroundColor Cyan

    $DataExpiracao = Obter-ExpiracaoSenha -Usuario $Usuario

    if ($null -eq $DataExpiracao) {
        $Erros++
        $Resultado += [PSCustomObject]@{
            Usuario = $Usuario; Expiracao = "-"; Dias = "-"; Status = "ERRO"
        }
        continue
    }

    $NovaData      = $DataExpiracao.ToString("dd/MM/yyyy")
    $DiasRestantes = ($DataExpiracao.Date - (Get-Date).Date).Days

    
    $Item | Add-Member -NotePropertyName "DATA DE EXPIRACAO" -NotePropertyValue $NovaData -Force
    $Item | Add-Member -NotePropertyName "UltimaConsulta" -NotePropertyValue (Get-Date -Format "dd/MM/yyyy HH:mm") -Force

    $Atualizados++

    $Resultado += [PSCustomObject]@{
        Usuario   = $Usuario
        Expiracao = $NovaData
        Dias      = $DiasRestantes
        Status    = Obter-Status -DiasRestantes $DiasRestantes
    }
}


$TempFile = "$Arquivo.tmp"

try {
    $Usuarios | Export-Csv -Path $TempFile -Delimiter ";" -NoTypeInformation -Encoding UTF8
    Move-Item -Path $TempFile -Destination $Arquivo -Force
}
catch {
    Write-Host "`nFalha ao atualizar o CSV." -ForegroundColor Red
    Write-Host "Verifique se o arquivo esta aberto no Excel." -ForegroundColor Yellow
    Pause
    Exit
}



$Resultado = $Resultado | Sort-Object Dias

Clear-Host

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "                RELATORIO DE EXPIRACAO DE SENHAS                 " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green
Write-Host ""

$Formato = "{0,-30} {1,-12} {2,-8} {3}"

Write-Host ($Formato -f "USUARIO", "EXPIRACAO", "DIAS", "STATUS")
Write-Host ($Formato -f ("-" * 30), ("-" * 12), ("-" * 8), ("-" * 10)) -ForegroundColor DarkGray

$Cores = @{
    "EXPIRADA" = "Red"
    "CRITICA"  = "DarkYellow"
    "ATENCAO"  = "Yellow"
    "OK"       = "Cyan"
}

foreach ($Linha in $Resultado) {
    $Texto = $Formato -f $Linha.Usuario, $Linha.Expiracao, $Linha.Dias, $Linha.Status
    $Cor   = if ($Cores.ContainsKey($Linha.Status)) { $Cores[$Linha.Status] } else { "White" }

    Write-Host $Texto -ForegroundColor $Cor
}

$Total = @{}
foreach ($Status in $Cores.Keys) {
    $Total[$Status] = @($Resultado | Where-Object { $_.Status -eq $Status }).Count
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "RESUMO" -ForegroundColor White
Write-Host "------" -ForegroundColor White
Write-Host ""
Write-Host "CONSULTADOS : $Consultados" -ForegroundColor White
Write-Host "ATUALIZADOS : $Atualizados" -ForegroundColor Green
Write-Host "ERROS       : $Erros"       -ForegroundColor Red
Write-Host ""
Write-Host "EXPIRADAS   : $($Total['EXPIRADA'])" -ForegroundColor Red
Write-Host "CRITICAS    : $($Total['CRITICA'])"  -ForegroundColor DarkYellow
Write-Host "ATENCAO     : $($Total['ATENCAO'])"  -ForegroundColor Yellow
Write-Host "OK          : $($Total['OK'])"       -ForegroundColor Cyan
Write-Host ""
Write-Host "CSV atualizado com sucesso." -ForegroundColor Green
Write-Host "Backup criado em:" -ForegroundColor Cyan
Write-Host $Backup -ForegroundColor Cyan
Write-Host ""

Pause
