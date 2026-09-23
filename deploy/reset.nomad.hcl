variable "image" {
  type = string
}

job "backoffice-demo-reset" {
  namespace   = "demo"
  datacenters = ["homelab"]
  type        = "batch"

  periodic {
    crons            = ["0 4 * * *"]
    time_zone        = "UTC"
    prohibit_overlap = true
  }

  constraint {
    attribute = "${node.class}"
    value     = "general"
  }

  group "reset" {
    volume "data" {
      type            = "host"
      source          = "backoffice-demo-demo-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "reset" {
      driver = "docker"

      config {
        image        = var.image
        command      = "froment-backoffice"
        args         = ["demo-reset"]
        network_mode = "services"
      }

      env {
        APP_ENV            = "staging"
        DEMO_MODE          = "true"
        DATABASE_PATH      = "/var/lib/backoffice-demo/froment.sqlite"
        BUSINESS_TIME_ZONE = "Europe/Paris"
      }

      template {
        data = <<EOH
{{ with nomadVar "nomad/jobs/backoffice-demo" }}
{{ range $key, $value := . }}{{ $key }}={{ $value | toJSON }}
{{ end }}{{ end }}
EOH
        destination          = "secrets/runtime.env"
        env                  = true
        error_on_missing_key = true
      }

      volume_mount {
        volume      = "data"
        destination = "/var/lib/backoffice-demo"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
