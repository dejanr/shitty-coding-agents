# Agent Loop

```
                         ┌─────────────────────────────────────────┐
                         │                                         │
                         ▼                                         │
┌─────────────┐    ┌───────────┐    ┌─────────────┐    ┌──────────┴──┐
│    User     │───▶│   Agent   │───▶│    Tool     │───▶│   Result    │
│   Prompt    │    │  (LLM)    │    │  Execution  │    │             │
└─────────────┘    └───────────┘    └─────────────┘    └─────────────┘
                         │
                         │ Done?
                         ▼
                   ┌───────────┐
                   │  Response │
                   │  to User  │
                   └───────────┘
```

- User prompt
- Agent plans and calls tool(s)
- Tool results return to context
- Loop continues until done
