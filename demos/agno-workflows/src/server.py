import logging

logging.basicConfig(level=logging.DEBUG)

from agno.os import AgentOS
from workflow import build_all_agents, workflow

agent_os = AgentOS(agents=build_all_agents(), workflows=[workflow], tracing=True)
app = agent_os.get_app()
