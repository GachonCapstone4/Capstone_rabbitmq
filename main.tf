

# ============================================================
# EXCHANGES
# ============================================================

resource "rabbitmq_exchange" "app2ai_direct" {
  name  = "x.app2ai.direct"
  vhost = var.vhost

  settings {
    type        = "direct"
    durable     = true
    auto_delete = false
  }
}

resource "rabbitmq_exchange" "ai2app_direct" {
  name  = "x.ai2app.direct"
  vhost = var.vhost

  settings {
    type        = "direct"
    durable     = true
    auto_delete = false
  }
}

resource "rabbitmq_exchange" "retry_direct" {
  name  = "x.retry.direct"
  vhost = var.vhost

  settings {
    type        = "direct"
    durable     = true
    auto_delete = false
  }
}

resource "rabbitmq_exchange" "sse_fanout" {
  name  = "x.sse.fanout"
  vhost = var.vhost

  settings {
    type        = "fanout"
    durable     = true
    auto_delete = false
  }
}

resource "rabbitmq_exchange" "app2rag_direct" {
  name  = "x.app2rag.direct"
  vhost = var.vhost

  settings {
    type        = "direct"
    durable     = true
    auto_delete = false
  }
}

resource "rabbitmq_exchange" "rag2app_direct" {
  name  = "x.rag2app.direct"
  vhost = var.vhost

  settings {
    type        = "direct"
    durable     = true
    auto_delete = false
  }
}



# ============================================================
# MAIN QUEUES  (App ↔ AI)
# ============================================================

resource "rabbitmq_queue" "q_2ai_classify" {
  name  = "q.2ai.classify"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments = {
      "x-dead-letter-exchange"    = rabbitmq_exchange.retry_direct.name
      "x-dead-letter-routing-key" = "2ai.classify.retry"
    }
  }

  depends_on = [rabbitmq_exchange.retry_direct]
}

resource "rabbitmq_queue" "q_2app_classify" {
  name  = "q.2app.classify"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments = {
      "x-dead-letter-exchange"    = rabbitmq_exchange.retry_direct.name
      "x-dead-letter-routing-key" = "2app.classify.retry"
    }
  }

  depends_on = [rabbitmq_exchange.retry_direct]
}



# ============================================================
# RETRY QUEUES  (TTL 30s → 원래 Exchange로 재전달)
# ============================================================

resource "rabbitmq_queue" "q_2ai_classify_retry" {
  name  = "q.2ai.classify.retry"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    # arguments는 map(string)이라 정수형 전달 불가 → arguments_json 사용
    arguments_json = jsonencode({
      "x-message-ttl"             = 30000
      "x-dead-letter-exchange"    = rabbitmq_exchange.app2ai_direct.name
      "x-dead-letter-routing-key" = "2ai.classify"
    })
  }

  depends_on = [rabbitmq_exchange.app2ai_direct]
}

resource "rabbitmq_queue" "q_2app_classify_retry" {
  name  = "q.2app.classify.retry"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments_json = jsonencode({
      "x-message-ttl"             = 30000
      "x-dead-letter-exchange"    = rabbitmq_exchange.ai2app_direct.name
      "x-dead-letter-routing-key" = "2app.classify"
    })
  }

  depends_on = [rabbitmq_exchange.ai2app_direct]
}

# ============================================================
# DEAD LETTER (최종 실패 쓰레기통)
# default exchange 사용 → 별도 binding 불필요
# ============================================================

resource "rabbitmq_queue" "q_dlx_failed" {
  name  = "q.dlx.failed"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false
    arguments   = {}
  }
}

# ============================================================
# BINDINGS — Main queues
# ============================================================

resource "rabbitmq_binding" "bind_2ai_classify" {
  source           = rabbitmq_exchange.app2ai_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2ai_classify.name
  destination_type = "queue"
  routing_key      = "2ai.classify"

  depends_on = [
    rabbitmq_exchange.app2ai_direct,
    rabbitmq_queue.q_2ai_classify,
  ]
}

resource "rabbitmq_binding" "bind_2app_classify" {
  source           = rabbitmq_exchange.ai2app_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_classify.name
  destination_type = "queue"
  routing_key      = "2app.classify"

  depends_on = [
    rabbitmq_exchange.ai2app_direct,
    rabbitmq_queue.q_2app_classify,
  ]
}

# ============================================================
# BINDINGS — Retry queues → x.retry.direct
# ============================================================

resource "rabbitmq_binding" "bind_retry_2ai_classify" {
  source           = rabbitmq_exchange.retry_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2ai_classify_retry.name
  destination_type = "queue"
  routing_key      = "2ai.classify.retry"

  depends_on = [
    rabbitmq_exchange.retry_direct,
    rabbitmq_queue.q_2ai_classify_retry,
  ]
}

resource "rabbitmq_binding" "bind_retry_2app_classify" {
  source           = rabbitmq_exchange.retry_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_classify_retry.name
  destination_type = "queue"
  routing_key      = "2app.classify.retry"

  depends_on = [
    rabbitmq_exchange.retry_direct,
    rabbitmq_queue.q_2app_classify_retry,
  ]
}



# ============================================================
# RAG INBOUND MAIN QUEUES  (BackendServer → RAG)
# ============================================================

resource "rabbitmq_queue" "q_2rag_knowledge_ingest" {
  name  = "q.2rag.knowledge.ingest"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments = {
      "x-dead-letter-exchange"    = rabbitmq_exchange.retry_direct.name
      "x-dead-letter-routing-key" = "2rag.knowledge.ingest.retry"
    }
  }

  depends_on = [rabbitmq_exchange.retry_direct]
}

resource "rabbitmq_queue" "q_2rag_templates_index" {
  name  = "q.2rag.templates.index"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments = {
      "x-dead-letter-exchange"    = rabbitmq_exchange.retry_direct.name
      "x-dead-letter-routing-key" = "2rag.templates.index.retry"
    }
  }

  depends_on = [rabbitmq_exchange.retry_direct]
}

resource "rabbitmq_queue" "q_2rag_templates_match" {
  name  = "q.2rag.templates.match"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments = {
      "x-dead-letter-exchange"    = rabbitmq_exchange.retry_direct.name
      "x-dead-letter-routing-key" = "2rag.templates.match.retry"
    }
  }

  depends_on = [rabbitmq_exchange.retry_direct]
}

resource "rabbitmq_queue" "q_2rag_draft" {
  name  = "q.2rag.draft"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments = {
      "x-dead-letter-exchange"    = rabbitmq_exchange.retry_direct.name
      "x-dead-letter-routing-key" = "2rag.draft.retry"
    }
  }

  depends_on = [rabbitmq_exchange.retry_direct]
}



# ============================================================
# RAG OUTBOUND MAIN QUEUES  (RAG → BackendServer)
# ============================================================

resource "rabbitmq_queue" "q_2app_knowledge_ingest" {
  name  = "q.2app.knowledge.ingest"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments = {
      "x-dead-letter-exchange"    = rabbitmq_exchange.retry_direct.name
      "x-dead-letter-routing-key" = "2app.knowledge.ingest.retry"
    }
  }

  depends_on = [rabbitmq_exchange.retry_direct]
}

resource "rabbitmq_queue" "q_2app_templates_index" {
  name  = "q.2app.templates.index"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments = {
      "x-dead-letter-exchange"    = rabbitmq_exchange.retry_direct.name
      "x-dead-letter-routing-key" = "2app.templates.index.retry"
    }
  }

  depends_on = [rabbitmq_exchange.retry_direct]
}

resource "rabbitmq_queue" "q_2app_templates_match" {
  name  = "q.2app.templates.match"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments = {
      "x-dead-letter-exchange"    = rabbitmq_exchange.retry_direct.name
      "x-dead-letter-routing-key" = "2app.templates.match.retry"
    }
  }

  depends_on = [rabbitmq_exchange.retry_direct]
}

resource "rabbitmq_queue" "q_2app_rag_draft" {
  name  = "q.2app.rag.draft"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments = {
      "x-dead-letter-exchange"    = rabbitmq_exchange.retry_direct.name
      "x-dead-letter-routing-key" = "2app.rag.draft.retry"
    }
  }

  depends_on = [rabbitmq_exchange.retry_direct]
}

resource "rabbitmq_queue" "q_2app_rag_progress" {
  name  = "q.2app.rag.progress"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments = {
      "x-dead-letter-exchange"    = rabbitmq_exchange.retry_direct.name
      "x-dead-letter-routing-key" = "2app.rag.progress.retry"
    }
  }

  depends_on = [rabbitmq_exchange.retry_direct]
}



# ============================================================
# RAG RETRY QUEUES  (TTL 30s → 원래 Exchange로 재전달)
# ============================================================

resource "rabbitmq_queue" "q_2rag_knowledge_ingest_retry" {
  name  = "q.2rag.knowledge.ingest.retry"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments_json = jsonencode({
      "x-message-ttl"             = 30000
      "x-dead-letter-exchange"    = rabbitmq_exchange.app2rag_direct.name
      "x-dead-letter-routing-key" = "2rag.knowledge.ingest"
    })
  }

  depends_on = [rabbitmq_exchange.app2rag_direct]
}

resource "rabbitmq_queue" "q_2rag_templates_index_retry" {
  name  = "q.2rag.templates.index.retry"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments_json = jsonencode({
      "x-message-ttl"             = 30000
      "x-dead-letter-exchange"    = rabbitmq_exchange.app2rag_direct.name
      "x-dead-letter-routing-key" = "2rag.templates.index"
    })
  }

  depends_on = [rabbitmq_exchange.app2rag_direct]
}

resource "rabbitmq_queue" "q_2rag_templates_match_retry" {
  name  = "q.2rag.templates.match.retry"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments_json = jsonencode({
      "x-message-ttl"             = 30000
      "x-dead-letter-exchange"    = rabbitmq_exchange.app2rag_direct.name
      "x-dead-letter-routing-key" = "2rag.templates.match"
    })
  }

  depends_on = [rabbitmq_exchange.app2rag_direct]
}

resource "rabbitmq_queue" "q_2rag_draft_retry" {
  name  = "q.2rag.draft.retry"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments_json = jsonencode({
      "x-message-ttl"             = 30000
      "x-dead-letter-exchange"    = rabbitmq_exchange.app2rag_direct.name
      "x-dead-letter-routing-key" = "2rag.draft"
    })
  }

  depends_on = [rabbitmq_exchange.app2rag_direct]
}

resource "rabbitmq_queue" "q_2app_knowledge_ingest_retry" {
  name  = "q.2app.knowledge.ingest.retry"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments_json = jsonencode({
      "x-message-ttl"             = 30000
      "x-dead-letter-exchange"    = rabbitmq_exchange.rag2app_direct.name
      "x-dead-letter-routing-key" = "2app.knowledge.ingest"
    })
  }

  depends_on = [rabbitmq_exchange.rag2app_direct]
}

resource "rabbitmq_queue" "q_2app_templates_index_retry" {
  name  = "q.2app.templates.index.retry"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments_json = jsonencode({
      "x-message-ttl"             = 30000
      "x-dead-letter-exchange"    = rabbitmq_exchange.rag2app_direct.name
      "x-dead-letter-routing-key" = "2app.templates.index"
    })
  }

  depends_on = [rabbitmq_exchange.rag2app_direct]
}

resource "rabbitmq_queue" "q_2app_templates_match_retry" {
  name  = "q.2app.templates.match.retry"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments_json = jsonencode({
      "x-message-ttl"             = 30000
      "x-dead-letter-exchange"    = rabbitmq_exchange.rag2app_direct.name
      "x-dead-letter-routing-key" = "2app.templates.match"
    })
  }

  depends_on = [rabbitmq_exchange.rag2app_direct]
}

resource "rabbitmq_queue" "q_2app_rag_draft_retry" {
  name  = "q.2app.rag.draft.retry"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments_json = jsonencode({
      "x-message-ttl"             = 30000
      "x-dead-letter-exchange"    = rabbitmq_exchange.rag2app_direct.name
      "x-dead-letter-routing-key" = "2app.rag.draft"
    })
  }

  depends_on = [rabbitmq_exchange.rag2app_direct]
}

resource "rabbitmq_queue" "q_2app_rag_progress_retry" {
  name  = "q.2app.rag.progress.retry"
  vhost = var.vhost

  settings {
    durable     = true
    auto_delete = false

    arguments_json = jsonencode({
      "x-message-ttl"             = 30000
      "x-dead-letter-exchange"    = rabbitmq_exchange.rag2app_direct.name
      "x-dead-letter-routing-key" = "2app.rag.progress"
    })
  }

  depends_on = [rabbitmq_exchange.rag2app_direct]
}



# ============================================================
# RAG BINDINGS — Inbound main queues → x.app2rag.direct
# ============================================================

resource "rabbitmq_binding" "bind_2rag_knowledge_ingest" {
  source           = rabbitmq_exchange.app2rag_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2rag_knowledge_ingest.name
  destination_type = "queue"
  routing_key      = "2rag.knowledge.ingest"

  depends_on = [
    rabbitmq_exchange.app2rag_direct,
    rabbitmq_queue.q_2rag_knowledge_ingest,
  ]
}

resource "rabbitmq_binding" "bind_2rag_templates_index" {
  source           = rabbitmq_exchange.app2rag_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2rag_templates_index.name
  destination_type = "queue"
  routing_key      = "2rag.templates.index"

  depends_on = [
    rabbitmq_exchange.app2rag_direct,
    rabbitmq_queue.q_2rag_templates_index,
  ]
}

resource "rabbitmq_binding" "bind_2rag_templates_match" {
  source           = rabbitmq_exchange.app2rag_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2rag_templates_match.name
  destination_type = "queue"
  routing_key      = "2rag.templates.match"

  depends_on = [
    rabbitmq_exchange.app2rag_direct,
    rabbitmq_queue.q_2rag_templates_match,
  ]
}

resource "rabbitmq_binding" "bind_2rag_draft" {
  source           = rabbitmq_exchange.app2rag_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2rag_draft.name
  destination_type = "queue"
  routing_key      = "2rag.draft"

  depends_on = [
    rabbitmq_exchange.app2rag_direct,
    rabbitmq_queue.q_2rag_draft,
  ]
}



# ============================================================
# RAG BINDINGS — Outbound main queues → x.rag2app.direct
# ============================================================

resource "rabbitmq_binding" "bind_2app_knowledge_ingest" {
  source           = rabbitmq_exchange.rag2app_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_knowledge_ingest.name
  destination_type = "queue"
  routing_key      = "2app.knowledge.ingest"

  depends_on = [
    rabbitmq_exchange.rag2app_direct,
    rabbitmq_queue.q_2app_knowledge_ingest,
  ]
}

resource "rabbitmq_binding" "bind_2app_templates_index" {
  source           = rabbitmq_exchange.rag2app_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_templates_index.name
  destination_type = "queue"
  routing_key      = "2app.templates.index"

  depends_on = [
    rabbitmq_exchange.rag2app_direct,
    rabbitmq_queue.q_2app_templates_index,
  ]
}

resource "rabbitmq_binding" "bind_2app_templates_match" {
  source           = rabbitmq_exchange.rag2app_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_templates_match.name
  destination_type = "queue"
  routing_key      = "2app.templates.match"

  depends_on = [
    rabbitmq_exchange.rag2app_direct,
    rabbitmq_queue.q_2app_templates_match,
  ]
}

resource "rabbitmq_binding" "bind_2app_rag_draft" {
  source           = rabbitmq_exchange.rag2app_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_rag_draft.name
  destination_type = "queue"
  routing_key      = "2app.rag.draft"

  depends_on = [
    rabbitmq_exchange.rag2app_direct,
    rabbitmq_queue.q_2app_rag_draft,
  ]
}

resource "rabbitmq_binding" "bind_2app_rag_progress" {
  source           = rabbitmq_exchange.rag2app_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_rag_progress.name
  destination_type = "queue"
  routing_key      = "2app.rag.progress"

  depends_on = [
    rabbitmq_exchange.rag2app_direct,
    rabbitmq_queue.q_2app_rag_progress,
  ]
}



# ============================================================
# RAG BINDINGS — Retry queues → x.retry.direct
# ============================================================

resource "rabbitmq_binding" "bind_retry_2rag_knowledge_ingest" {
  source           = rabbitmq_exchange.retry_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2rag_knowledge_ingest_retry.name
  destination_type = "queue"
  routing_key      = "2rag.knowledge.ingest.retry"

  depends_on = [
    rabbitmq_exchange.retry_direct,
    rabbitmq_queue.q_2rag_knowledge_ingest_retry,
  ]
}

resource "rabbitmq_binding" "bind_retry_2rag_templates_index" {
  source           = rabbitmq_exchange.retry_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2rag_templates_index_retry.name
  destination_type = "queue"
  routing_key      = "2rag.templates.index.retry"

  depends_on = [
    rabbitmq_exchange.retry_direct,
    rabbitmq_queue.q_2rag_templates_index_retry,
  ]
}

resource "rabbitmq_binding" "bind_retry_2rag_templates_match" {
  source           = rabbitmq_exchange.retry_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2rag_templates_match_retry.name
  destination_type = "queue"
  routing_key      = "2rag.templates.match.retry"

  depends_on = [
    rabbitmq_exchange.retry_direct,
    rabbitmq_queue.q_2rag_templates_match_retry,
  ]
}

resource "rabbitmq_binding" "bind_retry_2rag_draft" {
  source           = rabbitmq_exchange.retry_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2rag_draft_retry.name
  destination_type = "queue"
  routing_key      = "2rag.draft.retry"

  depends_on = [
    rabbitmq_exchange.retry_direct,
    rabbitmq_queue.q_2rag_draft_retry,
  ]
}

resource "rabbitmq_binding" "bind_retry_2app_knowledge_ingest" {
  source           = rabbitmq_exchange.retry_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_knowledge_ingest_retry.name
  destination_type = "queue"
  routing_key      = "2app.knowledge.ingest.retry"

  depends_on = [
    rabbitmq_exchange.retry_direct,
    rabbitmq_queue.q_2app_knowledge_ingest_retry,
  ]
}

resource "rabbitmq_binding" "bind_retry_2app_templates_index" {
  source           = rabbitmq_exchange.retry_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_templates_index_retry.name
  destination_type = "queue"
  routing_key      = "2app.templates.index.retry"

  depends_on = [
    rabbitmq_exchange.retry_direct,
    rabbitmq_queue.q_2app_templates_index_retry,
  ]
}

resource "rabbitmq_binding" "bind_retry_2app_templates_match" {
  source           = rabbitmq_exchange.retry_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_templates_match_retry.name
  destination_type = "queue"
  routing_key      = "2app.templates.match.retry"

  depends_on = [
    rabbitmq_exchange.retry_direct,
    rabbitmq_queue.q_2app_templates_match_retry,
  ]
}

resource "rabbitmq_binding" "bind_retry_2app_rag_draft" {
  source           = rabbitmq_exchange.retry_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_rag_draft_retry.name
  destination_type = "queue"
  routing_key      = "2app.rag.draft.retry"

  depends_on = [
    rabbitmq_exchange.retry_direct,
    rabbitmq_queue.q_2app_rag_draft_retry,
  ]
}

resource "rabbitmq_binding" "bind_retry_2app_rag_progress" {
  source           = rabbitmq_exchange.retry_direct.name
  vhost            = var.vhost
  destination      = rabbitmq_queue.q_2app_rag_progress_retry.name
  destination_type = "queue"
  routing_key      = "2app.rag.progress.retry"

  depends_on = [
    rabbitmq_exchange.retry_direct,
    rabbitmq_queue.q_2app_rag_progress_retry,
  ]
}
