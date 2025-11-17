# Slack Knowledge Base Setup for MindsDB

This guide shows how to create a Slack-powered knowledge base and chatbot using MindsDB.

## Prerequisites

1. **Slack Bot Token**: `xoxb-your-token-here`
2. **OpenAI API Key**: Set in environment variables
3. **MindsDB**: Running locally (http://localhost:47334)

## Quick Start (Automated)

### Option 1: Python Script (Recommended)

```bash
# Set environment variables
export SLACK_BOT_TOKEN="xoxb-your-token-here"
export OPENAI_API_KEY="sk-..."
export SLACK_CHANNEL="general"  # optional, defaults to 'general'
export SLACK_MESSAGE_LIMIT="1000"  # optional, defaults to 1000

# Run the setup script
python src/setup_slack_kb.py
```

**What it does:**
1. ✅ Creates Slack database connection
2. ✅ Lists available channels
3. ✅ Previews messages
4. ✅ Creates Knowledge Base with embeddings
5. ✅ Populates KB with messages
6. ✅ Creates SlackBot agent
7. ✅ Tests the agent

### Option 2: Manual SQL (Step-by-step)

Connect to MindsDB:
```bash
mysql -h 127.0.0.1 -P 47335 -u mindsdb
# or visit http://localhost:47334
```

Then run the SQL from `mindsdb_queries/slack_setup`:

```sql
-- 1. Create Slack connection
CREATE DATABASE slack_learning
WITH ENGINE = 'slack', 
PARAMETERS = {
   "token": "xoxb-your-token-here"
};

-- 2. List available channels
SELECT channel_id, channel_name, is_member
FROM slack_learning.channels
WHERE is_member = true
LIMIT 10;

-- 3. Create Knowledge Base
CREATE KNOWLEDGE_BASE slack_kb
USING
    embedding_model = {
        "provider": "openai",
        "model_name": "text-embedding-3-small"
    },
    metadata_columns = ['user', 'channel', 'ts'],
    content_columns = ['text'],
    id_column = 'ts';

-- 4. Populate with messages
INSERT INTO slack_kb
SELECT ts, user, channel, text
FROM slack_learning.messages
WHERE channel = 'general'
  AND text IS NOT NULL
ORDER BY ts DESC
LIMIT 1000;

-- 5. Create agent
CREATE AGENT slack_assistant
USING
    model = 'gpt-4o',
    data = {
        'knowledge_bases': ['slack_kb']
    },
    prompt_template = '
### Role
You are **SlackBot**, a helpful assistant that answers questions 
about Slack conversations.

### Instructions
1. Answer ONLY using information from slack_kb
2. Include user and timestamp when quoting
3. Provide context about when conversations happened
4. Summarize multiple perspectives

### Format
Answer: <helpful answer>

Sources:
- {ts} — @{user} in #{channel}
';

-- 6. Query the agent
SELECT slack_assistant('What are people discussing?') AS answer;
```

## Usage Examples

### Ask Questions

```sql
-- General overview
SELECT slack_assistant('What have people been discussing recently?') AS answer;

-- Find specific information
SELECT slack_assistant('What questions were asked about data engineering?') AS answer;

-- Summarize topics
SELECT slack_assistant('Summarize the main topics from this week') AS answer;

-- Find participants
SELECT slack_assistant('Who are the most active participants?') AS answer;

-- Search by topic
SELECT slack_assistant('What was said about MindsDB or Airbyte?') AS answer;
```

### Direct Slack Queries

```sql
-- View recent messages
SELECT ts, user, text, channel
FROM slack_learning.messages
WHERE channel = 'general'
ORDER BY ts DESC
LIMIT 20;

-- Search messages
SELECT user, text, ts
FROM slack_learning.messages
WHERE channel = 'general'
  AND text LIKE '%data%'
LIMIT 10;

-- Get channel info
SELECT * FROM slack_learning.channels;

-- Get user info
SELECT * FROM slack_learning.users LIMIT 10;
```

## Multi-Channel Setup

To include multiple channels in your knowledge base:

```sql
INSERT INTO slack_kb
SELECT ts, user, channel, text
FROM slack_learning.messages
WHERE channel IN ('general', 'data-engineering', 'random', 'announcements')
  AND text IS NOT NULL
  AND text != ''
ORDER BY ts DESC
LIMIT 5000;
```

## Maintenance

### Add New Messages (Incremental Update)

```sql
-- Add messages since last update
INSERT INTO slack_kb
SELECT ts, user, channel, text
FROM slack_learning.messages
WHERE channel = 'general'
  AND text IS NOT NULL
  AND ts > (SELECT MAX(ts) FROM slack_kb)
LIMIT 100;
```

### Schedule Updates

Add to cron:
```bash
# Update every hour
0 * * * * python /path/to/update_slack_kb.py
```

## Architecture

```
[Slack Workspace]
    ↓ (Slack API with bot token)
[MindsDB Slack Connector] ← Fetches messages
    ↓
[Knowledge Base] ← Creates embeddings via OpenAI
    ↓
[SlackBot Agent] ← Answers questions using GPT-4o
```

## Troubleshooting

### "Channel not found"
- Check channel name (use `SELECT * FROM slack_learning.channels`)
- Ensure bot is added to the channel in Slack
- Try using channel_id instead of channel name

### "Token invalid"
- Verify token: `echo $SLACK_BOT_TOKEN`
- Check token has correct scopes in Slack API dashboard
- Required scopes: `channels:history`, `channels:read`, `users:read`

### "No messages returned"
- Ensure bot is member of channel
- Check if channel has messages: `SELECT COUNT(*) FROM slack_learning.messages WHERE channel = 'general'`
- Verify date range and filters

### "Embedding failed"
- Check OpenAI API key: `echo $OPENAI_API_KEY`
- Verify API quota and billing
- Try smaller message limit first (e.g., 100 messages)

## Cost Estimation

**For 1,000 Slack messages:**
- **Embedding creation**: ~$0.10 (one-time)
- **Per query**: ~$0.01-0.05 (depends on context size)
- **Monthly (100 queries)**: ~$1-5

**Tips to reduce cost:**
- Use `text-embedding-3-small` (50% cheaper than `-large`)
- Use GPT-3.5-turbo for simple queries
- Limit message history (e.g., last 30 days only)
- Cache frequent questions

## Next Steps

1. **Add more data sources**: Combine with Google Drive KB for unified search
2. **Create specialized agents**: Different agents for different channels
3. **Build a UI**: Connect via REST API for web interface
4. **Automate updates**: Schedule regular syncs
5. **Add analytics**: Track common questions and topics

## Files Created

- `mindsdb_queries/slack_setup` - SQL commands
- `src/setup_slack_kb.py` - Automated setup script
- `SLACK_SETUP.md` - This documentation

## Support

- MindsDB Docs: https://docs.mindsdb.com/integrations/app-integrations/slack
- Slack API: https://api.slack.com/docs
- OpenAI Embeddings: https://platform.openai.com/docs/guides/embeddings

