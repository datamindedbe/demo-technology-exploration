"""Agno Workflows tech demo — standalone, no Portal dependency.

Steps:
  1. identify_agent  — Agent with FileTools reads YAML configs, returns AgentSelection
  Condition: check_access — evaluator reads access.yml; if denied →
    2. request_access — requires_confirmation; on_reject=cancel
  3. answer_question  — executor picks the agent from session_state and streams its response
"""

from __future__ import annotations

from pathlib import Path

import yaml
from agno.agent import Agent
from agno.db.sqlite import SqliteDb
from agno.models.anthropic import Claude
from agno.tools.file import FileTools
from agno.tools.postgres import PostgresTools
from agno.workflow import Condition, OnReject, Step, StepInput, StepOutput, Workflow
from pydantic import BaseModel, Field

# ---------------------------------------------------------------------------
# Paths (resolved relative to this file so the demo works from any cwd)
# ---------------------------------------------------------------------------

_DEMO_ROOT = Path(__file__).parent.parent
_AGENTS_DIR = _DEMO_ROOT / "config" / "agents"
_ACCESS_FILE = _DEMO_ROOT / "config" / "access.yml"
_PRODUCTS_DIR = _DEMO_ROOT / "products"

HARDCODED_USER = "demo_user"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _load_yaml(path: Path) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def _save_yaml(path: Path, data: dict) -> None:
    with open(path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)


def _build_instructions(config: dict, agent_slug: str) -> str:
    """Port of demo/agents data_agents/server.py:build_instructions."""
    name = config["name"]
    description = config.get("description", "")
    product_context = config.get("instructions", "")
    osi_files = config.get("osi_files", [])
    osi_file_list = "\n".join(f"  - {f}" for f in osi_files)

    allowed_schemas = config.get("allowed_schemas", [])
    if allowed_schemas:
        schema_list = ", ".join(f"`{s}`" for s in allowed_schemas)
        schema_restriction = (
            f"\n## Database Access\n\n"
            f"You have direct database access to **only** these PostgreSQL schemas: {schema_list}. "
            f"You cannot query any other schema — not even to list tables or check existence.\n\n"
            f"**Important:** your OSI semantic model files may reference other schemas as cross-domain "
            f"relationships. Those references are documentation metadata only. Do not describe those "
            f"schemas as ones you 'can see', 'have access to', or 'can query'. If asked what schemas "
            f"or tables you can query, list only the schemas above.\n"
        )
    else:
        schema_restriction = ""

    return f"""You are {name}, a data expert for the {description} product.

## Access Control

Before answering any data question, read config/access.yml and check whether `{HARDCODED_USER}` \
is listed under `accessible_agents` for agent `{agent_slug}`. \
If not, respond: "You don't have access to {name}. Please request access through the portal." \
Do not query the database or read any semantic model files in that case.

## Semantic Models
{osi_file_list or "  (none)"}

{product_context}
{schema_restriction}## Protocol (every data question)
1. Read all relevant semantic model files first.
2. Extract field expressions, metric formulas, domain instructions, and join conditions.
3. Query the database using only what the models define — never guess column names.
4. Cite which semantic rule or metric you applied.
5. If a user assumption contradicts the data, correct it with the actual figure.

Lead with the answer, then show SQL and results.
"""


def _list_agent_names() -> list[str]:
    return [p.stem for p in _AGENTS_DIR.glob("*.yml")]


def _fix_tool_schemas(agent: Agent) -> None:
    """Patch agno tool schemas missing a 'type' field (Claude API requirement)."""
    for toolkit in getattr(agent, "tools", []) or []:
        for fn in (getattr(toolkit, "functions", None) or {}).values():
            props = (getattr(fn, "parameters", None) or {}).get("properties", {})
            for prop in props.values():
                if isinstance(prop, dict) and "type" not in prop:
                    prop["type"] = "string"


def _build_agent(agent_name: str) -> Agent:
    """Build a single Agent from its YAML config file."""
    config = _load_yaml(_AGENTS_DIR / f"{agent_name}.yml")
    pg = config["postgres"]
    osi_files = list(config.get("osi_files", []))
    config_for_instructions = {**config, "osi_files": osi_files}
    agent = Agent(
        name=config["name"],
        description=config.get("description", ""),
        instructions=_build_instructions(config_for_instructions, agent_name),
        tools=[
            PostgresTools(
                host=pg.get("host", "localhost"),
                port=int(pg.get("port", 5432)),
                db_name=pg["database"],
                user=pg["user"],
                password=pg["password"],
                table_schema=config["allowed_schemas"][0],
            ),
            FileTools(_DEMO_ROOT),
        ],
        model=Claude(id="claude-sonnet-4-5"),
        markdown=True,
    )
    _fix_tool_schemas(agent)
    return agent


# Build all agents once at module load — shared between AgentOS and the workflow
_agents: dict[str, Agent] = {name: _build_agent(name) for name in _list_agent_names()}


def build_all_agents() -> list[Agent]:
    """Return all agents — used by AgentOS."""
    return list(_agents.values())




# ---------------------------------------------------------------------------
# Step 1: identify_agent
# ---------------------------------------------------------------------------


class AgentSelection(BaseModel):
    agent_slug: str = Field(description="The filename stem of the chosen agent YAML, e.g. 'sales-transaction-ledger'")
    reason: str = Field(description="One sentence explaining why this agent was chosen")


identify_agent = Agent(
    name="Agent Selector",
    description="Reads available agent configs and picks the best one for a question.",
    instructions=(
        f"You are a routing agent. The agent config files are in {_AGENTS_DIR}. "
        "List the YAML files there, read each one, then pick the single most relevant agent "
        "for the user's question. Return the filename stem (without .yml) as agent_slug."
    ),
    # tools=[FileTools(_AGENTS_DIR)],
    output_schema=AgentSelection,
    model=Claude(id="claude-sonnet-4-5"),
)
_fix_tool_schemas(identify_agent)


# ---------------------------------------------------------------------------
# Condition: check_access
# ---------------------------------------------------------------------------


def check_access_evaluator(step_input: StepInput, session_state: dict) -> bool:
    content = step_input.previous_step_content
    if isinstance(content, str):
        selection = AgentSelection.model_validate_json(content)
    else:
        selection = AgentSelection.model_validate(content)
    agent_name = selection.agent_slug.strip().lower()
    session_state["selected_agent"] = agent_name  # needed by downstream steps
    access_data = _load_yaml(_ACCESS_FILE)
    accessible = (
        access_data.get("users", {})
        .get(HARDCODED_USER, {})
        .get("accessible_agents", [])
    )
    return agent_name not in accessible


# ---------------------------------------------------------------------------
# Step 3 (conditional): request_access
# ---------------------------------------------------------------------------


def grant_access_executor(step_input: StepInput, session_state: dict) -> StepOutput:
    agent_name = session_state.get("selected_agent", "")
    access_data = _load_yaml(_ACCESS_FILE)
    accessible = (
        access_data.setdefault("users", {})
        .setdefault(HARDCODED_USER, {})
        .setdefault("accessible_agents", [])
    )
    if agent_name not in accessible:
        accessible.append(agent_name)
    _save_yaml(_ACCESS_FILE, access_data)
    return StepOutput(content=f"Access granted to `{agent_name}`. Proceeding.", success=True)


# ---------------------------------------------------------------------------
# Step 4: answer_question — executor picks agent from session_state
# ---------------------------------------------------------------------------


async def answer_question_executor(step_input: StepInput, session_state: dict) -> StepOutput:
    agent_name = session_state.get("selected_agent")
    agent = _agents.get(agent_name)
    if agent is None:
        return StepOutput(content=f"No agent found for '{agent_name}'", success=False)

    response = await agent.arun(step_input.input)

    answer: str = ""
    if response is not None:
        content = getattr(response, "content", None)
        if isinstance(content, str) and content.strip():
            answer = content
        elif isinstance(content, list):
            parts = [str(item) for item in content if item]
            answer = "\n".join(parts).strip()
        if not answer:
            messages = getattr(response, "messages", None) or []
            for msg in reversed(messages):
                if getattr(msg, "role", None) == "assistant" and getattr(msg, "content", None):
                    answer = str(msg.content).strip()
                    break

    if not answer:
        answer = "The agent did not return an answer."

    return StepOutput(content=answer, success=True)


# ---------------------------------------------------------------------------
# Workflow assembly
# ---------------------------------------------------------------------------

workflow = Workflow(
    id="data-access",
    name="Data Access Workflow",
    description=(
        "Identifies the best data agent for a question, checks access, "
        "optionally requests it, then answers using a dynamically built Team."
    ),
    steps=[
        Step(name="identify_agent", agent=identify_agent),
        Condition(
            name="check_access",
            evaluator=check_access_evaluator,
            steps=[
                Step(name="grant_access", executor=grant_access_executor),
            ],
        ),
        Step(name="answer_question", executor=answer_question_executor),
    ],
    session_state={},
    db=SqliteDb(db_file=str(_DEMO_ROOT / "data" / "workflow_state.db")),
)
