@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ==========================================
:: [Marca] PortoMicro-Solucoes em websistemas
:: [Link] https://portomicro.com.br
::
:: setup-github.bat - Commit + push do projeto PortoZaaP Connect
:: Repositorio: https://github.com/portomicro/portozzap-connect
:: Pasta local: C:\Users\X99\Documents\Antigravity\PortoZaaP-Connect
:: Uso: duplo clique neste arquivo (ele fica na raiz do projeto)
:: ==========================================

title PortoMicro PortoZaaP Connect - Enviar para o GitHub

:: ----------------------------------------------------------
:: Configuracao do projeto
:: ----------------------------------------------------------
set "NOME=PortoZaaP Connect"
set "REPO=portomicro/portozzap-connect"
set "BRANCH=main"
set "URL=https://github.com/portomicro/portozzap-connect"
set "ARQ_ENV=.env"
set "SOBRA=*.env / *.key / *.pem / arquivos de configuracao e secrets"

:: ----------------------------------------------------------
:: 1. Entrar na RAIZ do projeto (pasta deste .bat)
:: ----------------------------------------------------------
set "RAIZ=%~dp0"
pushd "%RAIZ%" 2>nul
if not exist "." goto erro_pasta

echo ========================================
echo   %NOME% - Enviar para o GitHub
echo ========================================
echo   Pasta:       %CD%
echo   Repositorio: %URL%
echo   Branch:      %BRANCH%
echo.

:: ----------------------------------------------------------
:: 2. Pre-requisitos (git) e GitHub CLI
:: ----------------------------------------------------------
where git >nul 2>&1
if errorlevel 1 goto erro_git

set "GH="
for %%P in (
    "%ProgramFiles%\GitHub CLI\gh.exe"
    "%ProgramFiles%\GitHub CLI\h.exe"
    "%LOCALAPPDATA%\Programs\GitHub CLI\gh.exe"
    "%LOCALAPPDATA%\Programs\GitHub CLI\h.exe"
) do if not defined GH if exist "%%~P" set "GH=%%~P"
if not defined GH for /f "delims=" %%G in ('where gh 2^>nul') do if not defined GH set "GH=%%G"

:: ----------------------------------------------------------
:: 3. Inicializar repositorio local, se ainda nao existir
:: ----------------------------------------------------------
echo [1/5] Verificando repositorio local...
if exist ".git" (
    echo   Repositorio local ja existe.
) else (
    echo   Nenhum .git encontrado. Inicializando em "%CD%"...
    git init -b %BRANCH% >nul 2>&1
    if errorlevel 1 (
        git init >nul 2>&1
        git symbolic-ref HEAD refs/heads/%BRANCH% >nul 2>&1
    )
    if not exist ".git" goto erro_init
    echo   Repositorio local criado ^(branch %BRANCH%^).
)

:: ----------------------------------------------------------
:: 4. Protecao de dados sensiveis (.gitignore)
::    Nunca versionar .env, tokens, chaves privadas ou credenciais.
:: ----------------------------------------------------------
set "NAO_PROTEGIDOS="
for %%F in (".env" "*.env" "*.key" "*.pem" "config.yaml" "config.yml") do if exist "%%~F" (
    git check-ignore --no-index -q "%%~F"
    if errorlevel 1 set "NAO_PROTEGIDOS=!NAO_PROTEGIDOS! %%~F"
)
if exist "logs" (
    git check-ignore --no-index -q "logs/"
    if errorlevel 1 set "NAO_PROTEGIDOS=!NAO_PROTEGIDOS! logs/"
)

if defined NAO_PROTEGIDOS (
    echo.
    echo   ERRO: o .gitignore NAO esta protegendo dados sensiveis:
    echo    !NAO_PROTEGIDOS!
    goto erro_gitignore
)
echo   Dados sensiveis fora do commit: ok

:: ----------------------------------------------------------
:: 5. Apontar o remote origin para o repositorio do GitHub
:: ----------------------------------------------------------
set "REMOTE=!URL!"
if /i not "!REMOTE:~-4!"==".git" set "REMOTE=!URL!.git"
git remote remove origin >nul 2>&1
git remote add origin "!REMOTE!"
if errorlevel 1 goto erro_remote
echo   Remote origin: !REMOTE!

:: ----------------------------------------------------------
:: 6. Autenticacao no GitHub
:: ----------------------------------------------------------
echo.
echo [2/5] Verificando autenticacao no GitHub...
if not defined GH (
    echo   AVISO: GitHub CLI nao encontrado.
    echo   Vou tentar usar as credenciais ja salvas do Git.
    echo   Se o push falhar, instale em: https://cli.github.com
    goto mensagem
)

"!GH!" auth status >nul 2>&1
if errorlevel 1 goto fazer_login
echo   Ja autenticado.
goto checar_repo

:fazer_login
echo   Nao autenticado. Abrindo o login no navegador...
"!GH!" auth login --git-protocol https --web
if errorlevel 1 goto erro_auth
echo   Login concluido.

:checar_repo
"!GH!" repo view %REPO% >nul 2>&1
if errorlevel 1 (
    echo   Repositorio %REPO% nao existe. Criando ^(privado^)...
    "!GH!" repo create %REPO% --private --description "Conector WhatsApp multi-dispositivo da PortoMicro baseado em Go, whatsmeow e Redis Streams." >nul 2>&1
    if errorlevel 1 goto erro_repo_create
    echo   Repositorio criado: %URL%
) else (
    echo   Repositorio remoto encontrado.
)

:: ----------------------------------------------------------
:: 7. Mensagem do commit
:: ----------------------------------------------------------
:mensagem
echo.
echo [3/5] Mensagem do commit

:: Data e hora no formato DD-MM-AAAA HH-MM
set "STAMP="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Get-Date -Format 'dd-MM-yyyy HH-mm'" 2^>nul`) do set "STAMP=%%I"
if not defined STAMP (
    set "D=%DATE:~0,2%"
    set "M=%DATE:~3,2%"
    set "A=%DATE:~6,4%"
    set "H=%TIME:~0,2%"
    set "H=!H: =0!"
    set "N=%TIME:~3,2%"
    set "STAMP=!D!-!M!-!A! !H!-!N!"
)
set "PADRAO=Atualizacao PortoZaaP Connect !STAMP!"

echo        Enter para usar: "!PADRAO!"
set "MSG="
set /p "MSG=>> "
:trim_msg
if "!MSG:~-1!"==" " (
    set "MSG=!MSG:~0,-1!"
    goto trim_msg
)
if not defined MSG set "MSG=!PADRAO!"
echo   Commit: "!MSG!"

:: ----------------------------------------------------------
:: 8. Sincronizar com o remoto (evita "non-fast-forward")
:: ----------------------------------------------------------
echo.
echo [4/5] Sincronizando com o remoto...
git fetch origin >nul 2>&1

git rev-parse --verify --quiet refs/remotes/origin/%BRANCH% >nul 2>&1
if errorlevel 1 (
    echo   Repositorio remoto vazio. Primeiro envio.
) else (
    git rev-parse --verify --quiet HEAD >nul 2>&1
    if errorlevel 1 (
        rem Sem commits locais. Se o remoto ja tem historico
        rem (ex.: README criado no site), alinha o HEAD sobre ele.
        echo   Remoto ja tem commits. Alinhando sobre origin/%BRANCH%...
        git reset --soft origin/%BRANCH%
        if errorlevel 1 goto erro_sync
    ) else (
        git pull --rebase --autostash origin %BRANCH% >nul 2>&1
        if errorlevel 1 (
            echo   AVISO: nao foi possivel sincronizar automaticamente.
            git rebase --abort >nul 2>&1
        )
    )
)
echo   Sincronizacao concluida.

:: ----------------------------------------------------------
:: 9. Commit
:: ----------------------------------------------------------
echo.
echo [5/5] Commit e envio...
git add -A

:: Ultima barreira: nada sensivel pode estar na area de commit
set "LISTA=%TEMP%\portozzap-connect-staged.txt"
set "SUSPEITOS="
git diff --cached --name-only > "!LISTA!" 2>nul
if exist "!LISTA!" (
    for /f "usebackq delims=" %%L in ("!LISTA!") do (
        set "ARQ=%%L"
        set "MARCAR="
        if /i "!ARQ!"==".env" set "MARCAR=1"
        if /i "!ARQ!"==".env" set "MARCAR=1"
        if /i "!ARQ:~0,4!"==".env" set "MARCAR=1"
        if /i "!ARQ:~0,5!"=="logs/" set "MARCAR=1"
        if /i "!ARQ:~-4!"==".env" set "MARCAR=1"
        if /i "!ARQ:~-4!"==".key" set "MARCAR=1"
        if /i "!ARQ:~-4!"==".pem" set "MARCAR=1"
        if /i "!ARQ:~-4!"==".p12" set "MARCAR=1"
        if /i "!ARQ:~-4!"==".pfx" set "MARCAR=1"
        if /i "!ARQ:~-7!"==".secret" set "MARCAR=1"
        if defined MARCAR set "SUSPEITOS=!SUSPEITOS! !ARQ!"
    )
    del "!LISTA!" >nul 2>&1
)
if defined SUSPEITOS echo   Sensivel na area de commit:!SUSPEITOS!
if defined SUSPEITOS goto erro_segredo

git diff --cached --quiet
if errorlevel 1 goto criar_commit
echo   Nenhuma alteracao nova para commitar.
set "FEZ_COMMIT=0"
goto enviar

:criar_commit
git commit -m "!MSG!" >nul
if errorlevel 1 goto erro_commit
echo   Commit criado: "!MSG!"
set "FEZ_COMMIT=1"

:: ----------------------------------------------------------
:: 10. Push
:: ----------------------------------------------------------
:enviar
echo.
echo   Enviando para o GitHub...
git push -u origin %BRANCH%
if errorlevel 1 goto erro_push

echo.
echo ========================================
echo   SUCESSO - projeto enviado para:
echo   %URL%
if "!FEZ_COMMIT!"=="1" (
    echo   Commit: "!MSG!"
) else (
    echo   Nenhuma alteracao nova ^(repositorio ja sincronizado^).
)
echo.
echo   Lembrete: arquivos .env, chaves e configuracoes sensiveis NAO foram
echo   versionados. Mantenha apenas modelos de exemplo sem credenciais.

echo ========================================
echo.
popd
pause
exit /b 0

:: ----------------------------------------------------------
:: Erros
:: ----------------------------------------------------------
:erro_git
echo.
echo ERRO: git nao encontrado no PATH.
echo Instale em: https://git-scm.com/download/win
echo.
pause
exit /b 1

:erro_gitignore
echo.
echo ERRO: .gitignore ausente ou incompleto.
echo Um ou mais arquivos sensiveis NAO estao protegidos:
echo   - .env / *.env ^(senhas, tokens e credenciais^)
echo   - *.key / *.pem e arquivos de configuracao com segredos
echo   - %SOBRA%
echo   - logs\              ^(logs e metricas locais^)
echo.
echo Corrija o .gitignore antes de enviar. Nada foi publicado.
echo.
popd
pause
exit /b 3

:erro_segredo
echo.
echo ERRO: arquivo SENSIVEL na area de commit ^(lista acima^).
echo O envio foi abortado antes do push. Nada foi publicado.
echo.
echo Para desfazer sem perder o trabalho:
echo   git reset
echo Depois confira o .gitignore e rode novamente.
echo.
popd
pause
exit /b 4

:erro_repo_create
echo.
echo ERRO: falha ao criar o repositorio %REPO% no GitHub.
echo Verifique:
echo   1. Permissao/organizacao correta da conta autenticada
echo   2. Se o nome ja existe: gh repo view %REPO%
echo.
popd
pause
exit /b 1

:erro_pasta
echo.
echo ERRO: nao consegui acessar a pasta do projeto.
echo Procurado em: %RAIZ%
echo.
pause
exit /b 1

:erro_init
echo.
echo ERRO: falha ao inicializar o repositorio local ^(git init^).
echo.
popd
pause
exit /b 1

:erro_remote
echo.
echo ERRO: falha ao configurar o remote 'origin'.
echo Verifique o remoto atual com: git remote -v
echo.
popd
pause
exit /b 1

:erro_auth
echo.
echo ERRO: autenticacao no GitHub falhou.
echo.
popd
pause
exit /b 1

:erro_sync
echo.
echo ERRO: falha ao alinhar com o remoto.
echo Rode manualmente: git fetch origin ^&^& git log --oneline origin/%BRANCH%
echo.
popd
pause
exit /b 1

:erro_commit
echo.
echo ERRO: falha ao criar o commit.
echo Confira se git user.name e user.email estao configurados:
echo   git config --global user.name  "Seu Nome"
echo   git config --global user.email "seu@email.com"
echo.
popd
pause
exit /b 1

:erro_push
echo.
echo ERRO: falha ao enviar para o GitHub.
echo Verifique:
echo   1. Conexao com a internet
echo   2. Permissao de escrita no repositorio
echo   3. Se o commit foi criado ^(git log^)
echo   4. Se o remoto existe: %URL%
echo.
echo Se o erro foi "non-fast-forward" ou "unrelated histories", o remoto ja tem
echo commits proprios ^(ex.: README criado no site^). Se puder descartar esse
echo conteudo, envie o seu por cima com:
echo      git push -f origin %BRANCH%
echo.
popd
pause
exit /b 1
