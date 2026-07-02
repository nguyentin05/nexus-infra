output "node_pool_name" {
  value = var.create_node_pool ? kubernetes_manifest.node_pool[0].manifest.metadata.name : null
}