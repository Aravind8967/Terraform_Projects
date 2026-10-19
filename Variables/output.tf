output "s3_id" {
    description = "S3 bucket value"
    value = aws_s3_bucket.bucket1.id
}