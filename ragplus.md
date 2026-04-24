### 2-1. RabbitMQ (주 통신 채널)

BackendServer(Spring)와 RAG 서버는 **직접 HTTP 호출 없이 RabbitMQ를 통해 비동기 통신**한다.

```
BackendServer ──publish──▶ EXCHANGE (x.app2rag.direct) ──route──▶ RAG inbound queue
BackendServer ◀──consume── EXCHANGE (x.rag2app.direct) ◀──publish── RAG outbound queue
```

**Inbound (BackendServer → RAG가 소비)**

| Queue | Routing Key | 용도 |
|---|---|---|
| `q.2rag.knowledge.ingest` | `2rag.knowledge.ingest` | FAQ/매뉴얼 문서 벡터 인덱싱 요청 |
| `q.2rag.templates.index` | `2rag.templates.index` | 템플릿 벡터 인덱싱 요청 |
| `q.2rag.templates.match` | `2rag.templates.match` | 이메일에 맞는 템플릿 검색 요청 |
| `q.2rag.draft` | `2rag.draft` | 이메일 초안 생성 요청 |

**Outbound (RAG가 발행 → BackendServer가 소비)**

| Queue | Routing Key | 용도 |
|---|---|---|
| `q.2app.knowledge.ingest` | `2app.knowledge.ingest` | 인덱싱 완료/실패 결과 |
| `q.2app.templates.index` | `2app.templates.index` | 템플릿 인덱싱 완료/실패 결과 |
| `q.2app.templates.match` | `2app.templates.match` | 템플릿 매칭 결과 |
| `q.2app.rag.draft` | `2app.rag.draft` | 이메일 초안 생성 결과 |
| `q.2app.rag.progress` | `2app.rag.progress` | 실시간 진행 상태 이벤트 |
| `q.dlx.failed` | — | 재시도 3회 초과 실패 메시지 DLQ |

**메시지 공통 필드**: `job_id`, `request_id`, `user_id`, `payload`

**재시도 로직**: `x-death` 헤더 기반 3회 재시도(기존 메인큐들의 방식인 retry_queue 방식 유지) → 실패 시 `q.dlx.failed` 라우팅

2rag.draft, 2app.rag.draft 가 기존 2ai.draft 2app.draft 대체(이것 외에 기존 리소스 절대건들지 않음)
