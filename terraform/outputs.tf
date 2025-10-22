output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "argocd_url" {
  value = helm_release.argocd.status
  description = "ArgoCD LoadBalancer URL (check once created)"
}

output "s3_bucket" {
  value = aws_s3_bucket.pipeline_data.bucket
}

output "rds_endpoint" {
  value = aws_db_instance.rds.endpoint
}
