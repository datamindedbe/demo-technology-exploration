# Agno Workflows Demo

A self-contained demo showing [Agno](https://github.com/agno-agi/agno) **Workflow**, **Step**, **Condition**, `requires_confirmation`, and a **callable Team factory** — served via AgentOS over HTTP so it works directly with [AgnoUI](https://docs.agno.com/ui).

## What this demo shows

| Feature | Where |
|---------|-------|
| `Workflow` with named `Step`s | `src/workflow.py` |
| `Condition` that gates a step on `session_state` | `src/workflow.py` — `check_access` condition |
| `requires_confirmation` + `on_reject=OnReject.cancel` | `request_access` step in `src/workflow.py` |
| Callable Team factory (members resolved lazily from `session_state`) | `get_data_agent()` in `src/workflow.py` |
| Structured output from an Agent step (`output_schema`) | `identify_agent` step in `src/workflow.py` |
| AgentOS HTTP server | `src/server.py` |

### Workflow structure

```
[1] identify_agent   → Agent with FileTools reads YAML configs, returns AgentSelection
Condition: check_access → evaluator reads config/access.yml; if access denied →
      └─ [2] request_access  → requires_confirmation; on_reject=cancel
[3] answer_question  → Team with callable factory answers using PostgreSQL
```

## Video
📺 [Watch the demo](<YouTube link>)

## Author
- Name: Pascal Knapen

## Prerequisites

- [Docker](https://www.docker.com/) (with Compose v2)
- [Task](https://taskfile.dev/) (`brew install go-task`)
- An Anthropic API key

## Setup

```bash
cp .env.secret.example .env.secret
# Edit .env.secret and add your ANTHROPIC_API_KEY
task up
```

Both services (`postgresql-demo` and `workflow`) start. The workflow server is available at **http://localhost:7070**.

## Running the demo

Open **AgnoUI** (e.g. `npx @agno/agnoui`) and point it at `http://localhost:7070`, or use any HTTP client.

**Suggested first question:**
> What were the top 5 products by revenue last month?

**Expected flow (first run — no access):**
1. Step 1 (`identify_agent`) selects `sales-transaction-ledger`
2. Condition (`check_access`) detects no access → enters conditional branch
3. Step 2 (`request_access`) pauses: *"You don't have access to this data agent. Request access?"*
   - Reply `y` → access granted, workflow continues to step 3
   - Reply `n` → workflow is cancelled

**Second run (same question):**
- Step 1 runs, condition passes, step 2 is skipped, step 3 answers directly

## Key code concept — callable Team factory

```python
data_team = Team(
    members=get_data_agent,  # callable, not a list
    ...
)
```

`get_data_agent` is a plain function. Agno inspects its parameter names at runtime and injects recognised values (e.g. `session_state`) automatically, so the Team's member list is built lazily from whatever is in `session_state` at that moment — no need to pre-instantiate agents.

## Resetting

```bash
task reset-access   # clears config/access.yml so the demo can be repeated
task down           # stop all services
```

## Taskfile reference

| Command | Description |
|---------|-------------|
| `task up` | Build and start all services |
| `task down` | Stop all services |
| `task logs` | Follow workflow service logs |
| `task reset-access` | Reset access.yml to initial state |
