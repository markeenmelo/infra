variable "state_directory" {
  type        = string
  nullable    = false
  description = "Absolute private directory outside the checkout for this tailnet's local state and plans."
  validation {
    condition     = startswith(var.state_directory, "/") && abspath(var.state_directory) != abspath(path.root) && !startswith(abspath(var.state_directory), "${abspath(path.root)}/")
    error_message = "State must be in an absolute directory outside the OpenTofu configuration; use the repository wrapper for the stricter checkout boundary."
  }
}

variable "state_passphrase" {
  type        = string
  sensitive   = true
  ephemeral   = true
  nullable    = false
  description = "High-entropy recovery passphrase supplied privately at runtime; never committed or stored in a plan."
  validation {
    condition     = length(var.state_passphrase) >= 32
    error_message = "Use a securely generated passphrase of at least 32 characters, with independently tested recovery."
  }
}

terraform {
  backend "local" {
    path          = "${var.state_directory}/terraform.tfstate"
    workspace_dir = "${var.state_directory}/workspaces"
  }
  encryption {
    key_provider "pbkdf2" "tailnet" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "tailnet" {
      keys = key_provider.pbkdf2.tailnet
    }
    state {
      method   = method.aes_gcm.tailnet
      enforced = true
    }
    plan {
      method   = method.aes_gcm.tailnet
      enforced = true
    }
  }
}
