variable "environment" {
    default = "dev"
    type = string
}

variable "db_password" {
    description = "DB master password"
    type = string
    sensitive = true
}

variable "db_sg" {
    default = "db_sg"
    type = string
}

variable "db_config" {
    description = "Database configuration"
    type = object({
        allocated_storage = number
        max_allocated_storage = number
        storage_type = string
        engine = string
        engine_version = string
        instance_class = string
        db_name = string
        username = string
    })

    default = {
        allocated_storage = 20
        max_allocated_storage = 20
        storage_type = "gp2"
        engine = "mysql"
        engine_version = "8.0"
        instance_class = "db.t3.micro"
        db_name = "appdb"
        username = "admin"
    }
}