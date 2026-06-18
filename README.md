# GoOS Constellation Repository

Este diretório é o **servidor de repositório** do Constellation.
Serve um `index.json` e os pacotes `.sdst` para o GoOS.

## Estrutura

```
repo/
├── index.json          ← índice do repositório (gerado pelo build-repo.sh)
├── build-repo.sh       ← script que empacota todos os apps e gera o index
└── packages/
    ├── inkscape-1.3.2.sdst
    └── ...
```

## Como funciona

O Constellation faz `GET {repo-url}/index.json` e lê a lista de pacotes.
Cada pacote tem uma `url` que aponta para o arquivo `.sdst` a ser baixado.

Um arquivo `.sdst` é um **tar.zst** contendo:
```
orbit.json          ← manifesto do pacote (OrbitManifest)
payload/            ← arquivos do app (scripts, binários, dados)
```

## Registrar este repositório no GoOS

```bash
constellation repo add http://meu-servidor/repo --name oficial
```

Ou via API (Goos.DE faz isso automaticamente no futuro):
```
POST /api/apps/install { "appId": "inkscape" }
```
