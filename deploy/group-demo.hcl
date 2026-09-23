    task "seed" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image        = [[ var "image" . | quote ]]
        command      = "froment-backoffice"
        args         = ["demo-reset"]
        network_mode = "services"
      }

      env {
        APP_ENV            = "staging"
        DEMO_MODE          = "true"
        DATABASE_PATH      = "/var/lib/backoffice-demo/froment.sqlite"
        BUSINESS_TIME_ZONE = "Europe/Paris"
        ENTERPRISE_NAME    = "ACME"
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
        change_mode          = "restart"
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
