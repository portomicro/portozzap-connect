# PortoZaaP Connect — deploy local

Instalação do conector WhatsApp (base [fazer-ai/whatsapp-connector](https://github.com/fazer-ai/whatsapp-connector))
com **imagem própria `portomicro/portozzap-connect`**, rodando junto do **Chatwoot fazer.ai**
em stack própria no Portainer (CE) deste host.

O conector não é um servidor HTTP de WhatsApp: ele troca eventos e comandos por
**Redis Streams** com o Chatwoot fazer.ai, e é o Chatwoot que mostra o QR code e as
conversas. Por isso a stack inclui os dois.

> O canal **“WhatsApp (nativo)”** só existe na imagem `ghcr.io/fazer-ai/chatwoot`.
> A imagem oficial `chatwoot/chatwoot` não tem esse canal e não conversa com o conector.

## Arquivos

| Arquivo | Para quê |
|---|---|
| `portainer-stack.yaml` | Stack `whatsapp-nativo` no Portainer (caminho principal) |
| `portainer-env.txt` | Variáveis de ambiente da stack (segredos gerados) — colar em *Environment variables* |
| `build-portozzap-connect.ps1` | Build (e push opcional) da imagem própria |
| `docker-compose.yaml` | Alternativa sem Portainer: só Redis + conector (sem Chatwoot) |
| `.env` | Segredos do compose alternativo |

## Imagem própria

```powershell
# build local (tags 0.1.0 e latest)
powershell -ExecutionPolicy Bypass -File deploy\build-portozzap-connect.ps1

# outra versão
powershell -ExecutionPolicy Bypass -File deploy\build-portozzap-connect.ps1 -Version 0.1.1

# build + Docker Hub (pede docker login antes)
powershell -ExecutionPolicy Bypass -File deploy\build-portozzap-connect.ps1 -Version 0.1.1 -Push
```

O Dockerfile é o do repositório (build multi-stage, runtime distroless `static:nonroot`,
~48 MB). A versão aparece em `GET /healthz` (`{"version":"0.1.0"}`) e em
`docker exec <container> /connector version`.

Publicar no Docker Hub é só `docker push portomicro/portozzap-connect:<tag>` — o script
faz as duas tags (`<versão>` e `latest`) de uma vez.

## Stack no Portainer (em uso)

Stack criada pela API do Portainer em `https://localhost:9443` → **Stacks → whatsapp-nativo**.

| Serviço | Imagem | Porta no host |
|---|---|---|
| `rails` / `sidekiq` | `ghcr.io/fazer-ai/chatwoot:latest` | **3001** → 3000 |
| `portozzap-connect` | `portomicro/portozzap-connect:0.1.0` (via `WAC_IMAGE`) | **8085** → 8080 (`/healthz`, `/readyz`, `/metrics`) |
| `postgres` | `pgvector/pgvector:pg16` | interna (sem publicação) |
| `redis` | `redis:8.0.3` | interna (sem publicação) |
| chamadas de voz | — | **40000/udp** publicada, recurso desligado |

Rede, volumes e banco são exclusivos desta stack: **nada é compartilhado** com
`chatwoot_app2`, `postgres`, `redis` ou a rede `minha_rede` da instalação antiga.

`WAC_ADVERTISE_URL=http://portozzap-connect:8080` é o endereço pelo qual o Chatwoot
baixa a mídia recebida (nome do serviço dentro da rede da stack).

`WAC_IMAGE` é variável da stack: para trocar de versão, mude o valor e use
**Recreate** no serviço `portozzap-connect`.

### Primeiro acesso

1. Abra `http://localhost:3001` e crie a conta de administrador
   (`ENABLE_ACCOUNT_SIGNUP=true` está ligado).
2. **Configurações → Caixas de entrada → Adicionar → WhatsApp → WhatsApp (nativo)**.
3. Pareie pelo QR code ou pelo código de 8 caracteres no celular.

### Operar pelo Portainer

- **Status/logs**: Stacks → whatsapp-nativo → cada container.
- **Atualizar o conector**: build com versão nova e `WAC_IMAGE` apontando para ela,
  depois *Recreate*.
- **Atualizar o Chatwoot**: *Recreate* com `CHATWOOT_TAG` fixado numa release.
- **Backup**: volumes `whatsapp-nativo_postgres` (conversas),
  `whatsapp-nativo_chatwoot_storage` (anexos) e `whatsapp-nativo_portozzap-connect`
  (pareamento SQLite + mídia).
- **Parar sem perder nada**: *Stop stack*. Para remover: *Delete stack* (volumes ficam).
- O volume `whatsapp-nativo_whatsapp-connector` é da primeira instalação (nome antigo do
  serviço) e está vazio; pode ser removido com `docker volume rm whatsapp-nativo_whatsapp-connector`.

### Chamadas de voz (opcional)

Descomente nas variáveis de ambiente da stack:

```yaml
WAC_CALLS_UDP_PORT: '40000'
WAC_CALLS_PUBLIC_IP: <ip pelo qual o navegador alcança este host>
```

Depois, na caixa do Chatwoot, aba **Chamadas** → *Ativar chamadas do WhatsApp*.

## Verificações úteis

```powershell
# conector
curl.exe -s http://localhost:8085/healthz
curl.exe -s http://localhost:8085/readyz

# imagem/versão em execução
docker inspect whatsapp-nativo-portozzap-connect-1 --format '{{.Config.Image}}'

# ping de ida e volta pelo contrato (comando -> resposta)
$pass = (docker exec whatsapp-nativo-redis-1 printenv REDIS_PASSWORD)
$ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
docker exec whatsapp-nativo-redis-1 redis-cli -a $pass XADD wa:control '*' v 1 id ping-1 `
  type admin.ping sid smoke ts $ts payload '{}' reply_to wa:reply:ping-1 deadline ($ts+15000)
docker exec whatsapp-nativo-redis-1 redis-cli -a $pass LRANGE wa:reply:ping-1 0 -1

# consumidores da frota (deve listar o conector e o chatwoot)
docker exec whatsapp-nativo-redis-1 redis-cli -a $pass XINFO GROUPS wa:events:0
```

## Alternativa sem Portainer (`docker-compose.yaml`)

Só Redis + conector, para testar o serviço isolado:

```powershell
docker compose -f deploy/docker-compose.yaml --env-file deploy/.env up -d
docker compose -f deploy/docker-compose.yaml --env-file deploy/.env down -v
```

Não rode os dois ao mesmo tempo: **dois conectores no mesmo Redis disputam as sessões**.

## Repositório próprio

O código é um clone de `fazer-ai/whatsapp-connector` (licença MIT, mantida no `LICENSE`).
Para publicar em `github.com/portomicro/portozzap-connect`:

```powershell
git remote set-url origin https://github.com/portomicro/portozzap-connect.git
git push -u origin main
```

O `setup-github-portozzap-connect.bat` que está na raiz faz isso (cria o repositório
privado se não existir, protege `.env`/`logs` e faz commit + push), mas aponta para a
pasta `C:\Users\X99\Documents\Antigravity\PortoZaaP-Connect` — rode-o a partir desta
pasta, ou copie o projeto para lá antes.
