# bitcoin-local-explorer

Node `bitcoind` em **regtest** com auto-mining (incluindo transações internas simuladas) + [btc-rpc-explorer](https://github.com/janoside/btc-rpc-explorer) como explorer

## Estrutura

```text
docker-compose.yml         # stack completa: bitcoin-node, electrs, explorer, proxy
docker-compose.local.yml   # override: publica o proxy em :9001, sem HTTPS
Makefile                    # atalhos pro uso local (make up, make logs, ...)
.env.example                # variáveis pro Coolify
local.env                   # variáveis fixas pro uso local
bitcoin-node/                # Dockerfile: baixa o binário oficial do Bitcoin Core, roda em regtest com auto-mining
btc-rpc-explorer/            # fork do janoside/btc-rpc-explorer
proxy/                        # nginx: roteia / (explorer) e /rpc (token) pro bitcoin-node
```

`electrs` usa a imagem oficial (`mempool/electrs`). `bitcoin-node`, `explorer` e `proxy` têm Dockerfile próprio.

## Arquitetura

```text
                        ┌──────────────────────────────────┐
   navegador ─────────▶ │   proxy (nginx)                    │
   apps externas ─────▶ │   /rpc (token) · /                  │
                        └───┬──────────────────────┬──────────┘
                             │                      │
                  ┌──────────▼─────┐                │ /rpc
                  │ explorer        │                │
                  │ (btc-rpc-explorer)               │
                  └───┬─────────┬──┘                │
                      │         │                    │
              ┌───────▼──┐  ┌───▼──────────┐         │
              │ electrs   │  │ bitcoin-node  │◀───────┘
              │ (index)   │──│ (bitcoind)    │
              └───────────┘  └───────────────┘
                                 auto-mining
                          (bloco + tx interna a cada N seg)
```

`proxy` é o único serviço exposto. `explorer` consulta o `bitcoin-node` via RPC e resolve endereços via `electrs` (que indexa a chain do `bitcoin-node`). O `bitcoin-node` sozinho, num loop interno, minera blocos e manda transações internas simuladas — sempre tem atividade real de chain pra explorar.

A porta RPC do `bitcoin-node` (18443) nunca é publicada diretamente — só é alcançável via `proxy` em `/rpc` (autenticado por header) ou de dentro da rede docker.

## Rodando local

Requer Docker + Docker Compose v2 e `make`.

```bash
make up
```

Isso builda as imagens (`bitcoin-node`, `explorer`, `proxy`) e sobe tudo com `docker-compose.local.yml` (sem HTTPS, variáveis fixas de [local.env](local.env)):

- **Explorer**: <http://localhost:9001>
- **RPC autenticado**: `http://localhost:9001/rpc`, header `X-RPC-Token: local`

```bash
curl -X POST http://localhost:9001/rpc \
  -H "X-RPC-Token: local" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getblockchaininfo","params":[],"id":1}'
```

> Logo depois de um `make up` do zero (chain nova), a recompensa de mineração (coinbase) só fica gastável depois de 100 confirmações — regra do próprio Bitcoin, vale em regtest também. Nos primeiros ~15-17 minutos (100 blocos × 10s) só tem blocos vazios; depois disso as transações internas simuladas começam a aparecer sozinhas.

Outros comandos (`make help` lista todos):

| Comando | O que faz |
|---|---|
| `make up` | Builda e sobe a stack |
| `make down` | Para e remove os containers, **preservando** os volumes (chain + índice) |
| `make stop` | Só para os containers, sem remover nada |
| `make logs` | Segue os logs de todos os serviços |
| `make ps` | Status dos containers |
| `make restart-node` | Recria só o `bitcoin-node` (depois de mudar `MINING_INTERVAL`/`TX_*`) |
| `make config` | Valida o compose (`docker compose config`) |
| `make reset` | **Apaga tudo**, containers e volumes — chain e índice perdidos, sem volta (pede confirmação) |

Não rode `docker compose down -v` direto — use `make reset`, que existe justamente pra deixar claro que essa ação é destrutiva.

## Rodando no Coolify

1. Crie um recurso **Docker Compose** apontando pra este repo (base directory `/`).
2. Preencha as variáveis de [.env.example](.env.example): `DOMAIN`, `RPC_PASSWORD`, `RPC_TOKEN` (`RPC_USER` e as variáveis de mining têm default).
3. Atribua o domínio ao serviço `proxy` (porta 80). O Coolify cuida do HTTPS.

Explorer em `https://<DOMAIN>/`. O RPC do `bitcoin-node` fica em `https://<DOMAIN>/rpc`, exige o header `X-RPC-Token` (401 sem ele) — é assim que outras apps se conectam à chain. Trate o token como segredo, igual à senha RPC.

```bash
curl -X POST https://<DOMAIN>/rpc \
  -H "X-RPC-Token: $RPC_TOKEN" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getblockchaininfo","params":[],"id":1}'
```

O Makefile é só pro uso local — o Coolify sobe o `docker-compose.yml` direto, sem override e sem `make`.

## Configuração

### Auto-mining

O `bitcoin-node`, a cada ciclo (`MINING_INTERVAL` segundos, default 10s), manda uma transação interna (autoenvio dentro da própria wallet, com valor e taxa aleatórios) e minera um bloco incluindo ela:

```text
MINING_INTERVAL=10        # segundos entre blocos
TX_MIN_AMOUNT=0.0001      # BTC
TX_MAX_AMOUNT=0.01        # BTC
TX_MIN_FEE_RATE=1         # sat/vB
TX_MAX_FEE_RATE=20        # sat/vB
TX_MIN_BALANCE=0.01       # saldo mínimo pra tentar enviar — abaixo disso só mina bloco vazio
```

Depois de mudar algum valor, recrie só o serviço `bitcoin-node`:

```bash
make restart-node
```

## Persistência

- **bitcoin-node**: chain completa no volume nomeado `bitcoin-data` (`txindex=1` habilitado, pra qualquer transação poder ser consultada pelo explorer).
- **electrs**: índice de endereços no volume nomeado `electrs-data`.

**Importante**: nunca resete um sem o outro. Se resetar o `bitcoin-node` (chain nova do zero), o índice do `electrs` fica de uma chain que não existe mais. Pra reset completo, use `make reset` (local) ou `docker compose down -v` (Coolify).
