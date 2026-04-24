output "exchanges" {
  description = "생성된 Exchange 이름 목록"
  value = [
    rabbitmq_exchange.app2ai_direct.name,
    rabbitmq_exchange.ai2app_direct.name,
    rabbitmq_exchange.retry_direct.name,
    rabbitmq_exchange.app2rag_direct.name,
    rabbitmq_exchange.rag2app_direct.name,
  ]
}

output "main_queues" {
  description = "생성된 메인 Queue 이름 목록"
  value = [
    rabbitmq_queue.q_2ai_classify.name,
    rabbitmq_queue.q_2app_classify.name,
    rabbitmq_queue.q_2rag_knowledge_ingest.name,
    rabbitmq_queue.q_2rag_templates_index.name,
    rabbitmq_queue.q_2rag_templates_match.name,
    rabbitmq_queue.q_2rag_draft.name,
    rabbitmq_queue.q_2app_knowledge_ingest.name,
    rabbitmq_queue.q_2app_templates_index.name,
    rabbitmq_queue.q_2app_templates_match.name,
    rabbitmq_queue.q_2app_rag_draft.name,
    rabbitmq_queue.q_2app_rag_progress.name,
  ]
}

output "retry_queues" {
  description = "생성된 Retry Queue 이름 목록"
  value = [
    rabbitmq_queue.q_2ai_classify_retry.name,
    rabbitmq_queue.q_2app_classify_retry.name,
    rabbitmq_queue.q_2rag_knowledge_ingest_retry.name,
    rabbitmq_queue.q_2rag_templates_index_retry.name,
    rabbitmq_queue.q_2rag_templates_match_retry.name,
    rabbitmq_queue.q_2rag_draft_retry.name,
    rabbitmq_queue.q_2app_knowledge_ingest_retry.name,
    rabbitmq_queue.q_2app_templates_index_retry.name,
    rabbitmq_queue.q_2app_templates_match_retry.name,
    rabbitmq_queue.q_2app_rag_draft_retry.name,
    rabbitmq_queue.q_2app_rag_progress_retry.name,
  ]
}

output "dlx_queue" {
  description = "최종 실패 DLQ"
  value       = rabbitmq_queue.q_dlx_failed.name
}
