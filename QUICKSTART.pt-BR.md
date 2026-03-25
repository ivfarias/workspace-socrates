# Quick Start (PT-BR)

Guia rapido para instalar e rodar o agente Socrates.

## 1) Clonar o workspace

```bash
git clone https://github.com/ivfarias/workspace-socrates.git ~/.openclaw/workspace-socrates
cd ~/.openclaw/workspace-socrates
```

## 2) Instalar/registrar o agente

```bash
./scripts/awaken-socrates.sh --agent-id socrates
```

## 3) Conectar contas e canais no OpenClaw

```bash
openclaw configure
```

## 4) Teste rapido

```bash
openclaw agents list --json | jq '.[] | select(.id=="socrates")'
openclaw agent --agent socrates --message "Olá, Socrates"
```

## 5) Fluxo diario (resumo)

- Gerar prompt/spec antes de implementar:
  - `/open_agora` (chat)
  - `./scripts/start-elenchus.sh --repo /path/to/repo --name feature-x` (script)
- Criar worktree + spawn da task:
  - `./scripts/bootstrap-task.sh --repo /path/to/repo --id feat-x --branch feat/x --agent codex --description "Implementar X" --prompt-file /path/to/prompt.md`
- Rodar monitoramento uma vez:
  - `./scripts/start-monitoring.sh --once`

## Observacoes

- O runtime usa `~/.openclaw/openclaw.json` como configuracao global.
- Por padrao, o instalador herda os modelos atuais do usuario.
- Para override explicito de modelo: `--model-primary` e `--fallback`.
