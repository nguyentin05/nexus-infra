output "node_pool_name" {
  value = kubernetes_manifest.node_pool.manifest.metadata.name
}